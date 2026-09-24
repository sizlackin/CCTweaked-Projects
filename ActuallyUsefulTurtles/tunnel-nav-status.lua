-- Prints persistent shared tunnel-road graph statistics.
local fileName = "runtime/tunnelMap.txt"
if not fs.exists(fileName) then
	print("No tunnel graph saved yet.")
	print("Run start-tunnel-remap-large after installing tunnel navigation.")
	return
end
local f = assert(fs.open(fileName,"r"))
local data = textutils.unserialize(f.readAll())
f.close()
if type(data) ~= "table" or type(data.nodes) ~= "table" then
	print("Tunnel graph file is invalid.")
	return
end

local nodes,open,frontiers,temp = 0,0,0,0
for _,node in pairs(data.nodes) do
	nodes = nodes + 1
	for _,conn in pairs(node.connections or {}) do
		if conn.state == "open" then open = open + 1
		elseif conn.state == "unmapped" then frontiers = frontiers + 1
		elseif conn.state == "temporarily_blocked" then temp = temp + 1 end
	end
end

print("Tunnel road graph")
print("nodes:",nodes)
print("open edges:",math.floor(open/2))
print("unmapped frontiers:",frontiers)
print("temporary blocks:",math.floor(temp/2))
print("revision:",data.revision or 0)
