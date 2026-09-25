package.path = table.concat({
	"/emu/?.lua","/src/patch/?.lua","/src/tunnelnav/?.lua","/src/general/?.lua",
	"/src/gui/?.lua","/src/host/?.lua","/src/storage/?.lua", package.path,
}, ";")
local log = fs.open("/test.log","w")
local function say(s) log.writeLine(s); log.flush() end
local fakes = require("fakes")
_G.global = fakes.buildGlobal()
_G.config = fakes.config
say("globals ready")
for _,m in ipairs{"classTurtleList","classMapDisplay","classTaskSelector","classChoiceSelector","classTaskGroupDetails"} do
	local ok, err = pcall(require, m)
	say(("%-24s %s %s"):format(m, tostring(ok), ok and "" or tostring(err):sub(1,90)))
end
say("done")
log.close()
os.shutdown()
