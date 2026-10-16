-- SOLAR CORE wireless sender for CC:Tweaked / ATM10
-- Computer 1: Ender Modem on bottom.
--
-- Sends honest telemetry on the existing SOLARCORE protocol:
--   solar =         configured solar array count (NOT proof of production)
--   wind =          configured wind turbine count (NOT proof of production)
--   solarPowered =  true/false: does solar GENUINELY produce right now?
--   telemetry =     which peripheral the state came from (nil = none available)
--
-- Power-state detection, in priority order:
--   1. Advanced Peripherals "energyDetector" wired through the solar output.
--      getTransferRate() is real flow (FE/t); > 0 means genuine production.
--      This is the recommended setup: route ONLY the solar cable run through
--      the Energy Detector so wind output never crosses it.
--   2. Any peripheral exposing a direct production flag such as
--      isProducing() (mod-dependent; probed generically below).
--   3. NOTHING. The configured count is NOT a substitute: solarPowered is
--      sent as false and telemetry as nil, and the billboard shows the
--      dormant core while telling the user exactly what it is waiting for.
--
-- Safety note: if wind output shares the cable run through the Energy
-- Detector, its flow will read as solar. Dedicate the detector to solar.

if not peripheral.isPresent("bottom")
    or peripheral.getType("bottom") ~= "modem" then
  error("No modem found on bottom. Attach the Ender Modem underneath this computer.")
end
rednet.open("bottom")

-- Configured fleet (informational readouts on the billboard)
local SOLAR_COUNT = 4
local WIND_COUNT = 4

-- Seconds between broadcasts
local POLL = 1.0

-- Set to true ONLY if a connected energyStorage-style peripheral meters a
-- buffer fed exclusively by solar (no wind, machines or battery discharge
-- can fool a shared buffer; that is why this is opt-in).
local SOLAR_ONLY_GRID = false

-- ---------------------------------------------------------------------------
-- Honest detection
-- ---------------------------------------------------------------------------

-- Each probe returns (answered, producing, label). "answered" must only be
-- true when a real peripheral returned a real reading, so the display never
-- animates on an invented signal.

local function probeDirectFlag(name, method)
  return function()
    local found = peripheral.find(name, function(_, p)
      return type(p[method]) == "function" or nil
    end)
    if not found then return false end
    local ok, val = pcall(found[method], found)
    if ok and type(val) == "boolean" then
      return true, val, name .. "." .. method
    end
    return false
  end
end

local function probeEnergyDetector()
  local detector = peripheral.find("energyDetector", function(_, p)
    return type(p.getTransferRate) == "function" or nil
  end)
  if not detector then return false end
  local ok, rate = pcall(detector.getTransferRate, detector)
  if not ok or type(rate) ~= "number" then return false end
  return true, rate > 0,
    "energyDetector=" .. tostring(math.floor(rate + 0.5)) .. "FE/t"
end

-- Opt-in weak signal; answers only when SOLAR_ONLY_GRID is set, because a
-- shared buffer cannot distinguish solar from wind or battery discharge.
local function probeEnergyStorage()
  if not SOLAR_ONLY_GRID then return false end
  local storage = peripheral.find("energyStorage", function(_, p)
    return type(p.getEnergyPerTick) == "function" or nil
  end)
  if not storage then return false end
  local ok, rate = pcall(storage.getEnergyPerTick, storage)
  if not ok or type(rate) ~= "number" then return false end
  return true, rate > 0, "energyStorage=" .. tostring(math.floor(rate + 0.5)) .. "FE/t"
end

local probes = {
  probeDirectFlag("solarPanel", "isProducing"),
  probeDirectFlag("solar_panel", "isProducing"),
  probeEnergyDetector,
  probeEnergyStorage,
}

local function detectSolar()
  for _, probe in ipairs(probes) do
    local ok, answered, producing, label = pcall(probe)
    if ok and answered then
      return producing == true, label
    end
    -- probe errored or answered nothing: fall through to the next signal
  end
  return false, nil
end

-- ---------------------------------------------------------------------------
-- Send loop
-- ---------------------------------------------------------------------------

while true do
  local powered, via = detectSolar()
  rednet.broadcast({
    solar        = SOLAR_COUNT,     -- configured count, informational only
    wind         = WIND_COUNT,
    solarPowered = powered == true, -- honest flag; false without a real signal
    telemetry    = via,             -- nil when nothing real was measurable
  }, "SOLARCORE")
  sleep(POLL)
end
