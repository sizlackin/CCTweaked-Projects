-- SOLAR CORE wireless sender for CC:Tweaked (ATM10: To the Sky)
-- Computer 1: Ender Modem on bottom.
--
-- Message (SOLARCORE protocol, unchanged):
--   solar, wind          configured counts (informational only)
--   solarPowered         solar genuinely receiving energy right now?
--   windPowered          wind genuinely receiving energy right now?
--   telemetry            how solarPowered was measured (nil = no signal)
--   telemetryWind        how windPowered was measured (nil = no signal)
--
-- Detection priority for solarPowered (wind identical, own cube):
--   1. Inline flow meter on the solar-only cable run, if the pack has one
--      (Advanced Peripherals "energy_detector"/"energyDetector").
--   2. A direct production flag (isProducing) on any wrapped peripheral.
--   3. A DEDICATED energy cube that only the solar arrays feed:
--      a per-tick input method if the cube exposes one, otherwise the
--      level rising between polls. Level must RISE to count as producing
--      because a shared/discharging buffer cannot prove production.
--   4. NOTHING. Counts are never used as proof.
--
-- This file is per-source: the solar cube may fill while the wind cube
-- drains; each source is measured on its own device only.

if not peripheral.isPresent("bottom")
    or peripheral.getType("bottom") ~= "modem" then
  error("No modem found on bottom. Attach the Ender Modem underneath this computer.")
end
rednet.open("bottom")

-- ============================ CONFIG =====================================
local SOLAR_COUNT = 4
local WIND_COUNT  = 4
local POLL        = 1.0     -- seconds between broadcasts

-- Peripheral names (from peripheral.getNames()) of the cubes dedicated to
-- each source. Leave nil to auto-detect: auto-detection only trusts itself
-- when exactly ONE energy-reading peripheral is visible; with two or more
-- visible the sender prints their names at startup and waits for you to
-- set these two values.
local SOLAR_CUBE_NAME = nil
local WIND_CUBE_NAME  = nil
-- =========================================================================

local LEVEL_METHODS = {
  "getEnergy", "getEnergyStored", "getStoredEnergy",
  "getEnergyLevel", "getStored",
}
local CAP_METHODS = {
  "getMaxEnergy", "getEnergyCapacity", "getMaxEnergyStored",
  "getCapacity", "getMaxStored",
}
local RATE_IN_METHODS = {
  "getInputPerTick", "getInputRate", "getEnergyInput", "getRateIn",
}

-- ---------------------------------------------------------------------------
-- Device discovery
-- ---------------------------------------------------------------------------

local function methodOf(dev, list)
  for _, m in ipairs(list) do
    if type(dev[m]) == "function" then return m end
  end
  return nil
end

local function scanEnergyDevices()
  local found = {}
  local ok, names = pcall(peripheral.getNames)
  if not ok or type(names) ~= "table" then return found end
  for _, name in ipairs(names) do
    local okW, dev = pcall(peripheral.wrap, name)
    if okW and type(dev) == "table" then
      local getLevel = methodOf(dev, LEVEL_METHODS)
      if getLevel then
        found[#found + 1] = {
          name = name,
          dev = dev,
          getLevel = getLevel,
          getCap = methodOf(dev, CAP_METHODS),
          getRateIn = methodOf(dev, RATE_IN_METHODS),
        }
      end
    end
  end
  return found
end

local function resolveCube(configuredName, purpose, candidates)
  if configuredName then
    local ok, dev = pcall(peripheral.wrap, configuredName)
    if ok and type(dev) == "table" then
      local getLevel = methodOf(dev, LEVEL_METHODS)
      if getLevel then
        return { name = configuredName, dev = dev,
          getLevel = getLevel, getCap = methodOf(dev, CAP_METHODS),
          getRateIn = methodOf(dev, RATE_IN_METHODS) }
      end
    end
    print("SOLAR CORE: " .. configuredName .. " is not an energy-reader; " ..
      purpose .. " telemetry unavailable")
    return nil
  end
  if #candidates == 1 then
    return candidates[1]
  end
  return nil
end

-- Startup information and honest auto-detect limits
local candidates = scanEnergyDevices()
if #candidates == 0 then
  print("SOLAR CORE: no energy-reading peripherals visible on the network.")
  print("  (Mekanism machines do not speak to CC:Tweaked by themselves.)")
elseif #candidates == 1 then
  print("SOLAR CORE: using '" .. candidates[1].name .. "' for solar telemetry.")
  print("  If that cube is WIND-fed, set SOLAR_CUBE_NAME/WIND_CUBE_NAME below.")
else
  print("SOLAR CORE: multiple energy peripherals visible:")
  for _, c in ipairs(candidates) do
    print("  " .. c.name .. "  level:" .. c.getLevel ..
      (c.getCap and ("  cap:" .. c.getCap) or "") ..
      (c.getRateIn and ("  rateIn:" .. c.getRateIn) or ""))
  end
  print("  Set SOLAR_CUBE_NAME and WIND_CUBE_NAME in this file, then re-wget/run.")
end

local solarCube = resolveCube(SOLAR_CUBE_NAME, "solar", candidates)
local windCube = resolveCube(WIND_CUBE_NAME, "wind",
  (SOLAR_CUBE_NAME == nil and solarCube ~= nil) and {} or candidates)

-- ---------------------------------------------------------------------------
-- Probes: each returns (answered, producing, label)
-- ---------------------------------------------------------------------------

local function probeDirectFlag(name, methodName)
  return function()
    local found = peripheral.find(name, function(_, p)
      return type(p[methodName]) == "function" or nil
    end)
    if not found then return false end
    local ok, val = pcall(found[methodName], found)
    if ok and type(val) == "boolean" then
      return true, val, name .. "." .. methodName
    end
    return false
  end
end

local function probeFlowMeter()
  local detector = nil
  for _, pname in ipairs({ "energy_detector", "energyDetector" }) do
    detector = peripheral.find(pname, function(_, p)
      return type(p.getTransferRate) == "function" or nil
    end)
    if detector then break end
  end
  if not detector then return false end
  local ok, rate = pcall(detector.getTransferRate, detector)
  if not ok or type(rate) ~= "number" then return false end
  return true, rate > 0,
    "flow=" .. tostring(math.floor(rate + 0.5)) .. "FE/t"
end

-- Cube probes -------------------------------------------------------------

local function callMethod(cube, method)
  local ok, val = pcall(cube.dev[method], cube.dev)
  if ok and type(val) == "number" then return val end
  return nil
end

local function cubeRateIn(cube)
  if not cube or not cube.getRateIn then return false end
  local rate = callMethod(cube, cube.getRateIn)
  if rate == nil then return false end
  return true, rate > 0,
    "cube:" .. cube.name .. "=" .. math.floor(rate + 0.5) .. "/t-in"
end

local cubeStates = {}

local function cubeDelta(cube, key)
  if not cube then return false end
  local state = cubeStates[key] or { prev = nil }
  cubeStates[key] = state

  local level = callMethod(cube, cube.getLevel)
  if level == nil then return false end

  if state.prev == nil then
    state.prev = level
    return true, false, "cube:" .. cube.name .. "=wait"
  end

  local delta = level - state.prev
  state.prev = level

  local cap = cube.getCap and callMethod(cube, cube.getCap) or nil
  local nearFull = cap ~= nil and (cap - level) <= math.max(1, cap * 0.001)

  if delta > 0 then
    return true, true, "cube:" .. cube.name .. "=+" .. math.floor(delta)
  elseif delta < 0 then
    return true, false,
      "cube:" .. cube.name .. "=" .. math.floor(delta)
  elseif nearFull then
    -- Full and static: production may be blocked by nowhere to put RF.
    -- Conservative and honest: report standby, note the ambiguity.
    return true, false, "cube:" .. cube.name .. "=full?"
  else
    return true, false, "cube:" .. cube.name .. "=+0"
  end
end

-- ---------------------------------------------------------------------------
-- Per-source detection: flow meter > direct flag > cube rate-in > cube delta
-- ---------------------------------------------------------------------------

local function detectSource(key)
  local okF, answered, producing, label = pcall(probeFlowMeter)
  if okF and answered then return producing == true, label, "flow meter" end

  for _, name in ipairs({ "solarPanel", "solar_panel" }) do
    local okD, a2, p2, l2 = pcall(probeDirectFlag(name, "isProducing"))
    if okD and a2 then return p2 == true, l2, "flag" end
  end

  local cube = (key == "solar") and solarCube or windCube
  local okR, a3, p3, l3 = pcall(cubeRateIn, cube)
  if okR and a3 then return p3 == true, l3, "cube input" end

  local okL, a4, p4, l4 = pcall(cubeDelta, cube, key)
  if okL and a4 then return p4 == true, l4, "cube level" end

  return false, nil, nil
end

-- ---------------------------------------------------------------------------
-- Send loop
-- ---------------------------------------------------------------------------

while true do
  local solarPowered, via = detectSource("solar")
  local windPowered, viaWind = detectSource("wind")

  rednet.broadcast({
    solar         = SOLAR_COUNT,
    wind          = WIND_COUNT,
    solarPowered  = solarPowered == true,
    windPowered   = windPowered == true,
    telemetry     = via,
    telemetryWind = viaWind,
  }, "SOLARCORE")
  sleep(POLL)
end
