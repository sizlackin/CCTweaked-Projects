-- LabEnhanced clean-mining installer for Actually Useful Turtles.
-- Installs the patched classMiner with:
--   * cobbled-deepslate ore-vein backfill
--   * no-dig existing-path travel for home/refuel/offload returns
--
-- Safe to run on the main controller or directly on a turtle.

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/main/ActuallyUsefulTurtles/patches/classMiner.lua"

local function fetch()
    local response, err = http.get(url)
    if not response then error("Download failed: " .. tostring(err), 0) end
    local code = response.getResponseCode()
    if code ~= 200 then
        response.close()
        error("Download failed: HTTP " .. tostring(code), 0)
    end
    local data = response.readAll()
    response.close()
    if not data or #data < 10000 then
        error("Downloaded classMiner patch looks incomplete.", 0)
    end
    return data
end

local function writeFile(path, data)
    fs.makeDir(fs.getDir(path))
    local file = assert(fs.open(path, "w"))
    file.write(data)
    file.close()
    print("Patched " .. path)
end

local data = fetch()

if turtle then
    writeFile("runtime/classMiner.lua", data)
    if fs.isDir("turtle") then
        writeFile("turtle/classMiner.lua", data)
    end
    print("Clean mining installed on this turtle.")
    print("Reboot this turtle.")
elseif fs.isDir("turtle") then
    writeFile("turtle/classMiner.lua", data)
    print("Clean mining source installed on controller.")
    print("Reboot controller, then reboot each mining turtle once to sync.")
else
    error("Run this on the Actually Useful Turtles controller or a mining turtle.", 0)
end
