-- Fixes black/unpainted gaps when the shared mapper traverses already-known
-- road nodes. Run on the MAIN controller.

if turtle then error("Run this on the main controller.",0) end

local url = "https://raw.githubusercontent.com/sizlackin/CCTweaked-Projects/7412a637457f2f48b16ee68fa35b4ec9c12bc56f/ActuallyUsefulTurtles/tunnelnav/classTunnelMapper.lua"
local r,e = http.get(url)
if not r then error("Download failed: "..tostring(e),0) end
local code = r.getResponseCode()
if code ~= 200 then r.close(); error("HTTP "..tostring(code),0) end
local data = r.readAll(); r.close()

if not data:find("LABENHANCED_MAPPER_REFRESH_KNOWN",1,true) then
	error("Downloaded mapper is missing the black-gap fix.",0)
end

local target = "turtle/classTunnelMapper.lua"
fs.makeDir(fs.getDir(target))
local f = assert(fs.open(target,"w"))
f.write(data)
f.close()

print("Mapper black-gap fix installed on controller.")
print("Reboot DTX-001 so it receives the new mapper.")
