--!strict
--!native

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Remote = script.Parent:WaitForChild("Remote")

--- writes signed 24-bit integer to buffer
--@native
local function writei24(b: buffer, offset: number, value: number)
	local bitoffset = offset * 8
	local sign = math.sign(value) < 0 and 1 or 0
	if sign == 1 then
		value += 1
	end
	
	buffer.writebits(b, bitoffset, 23, math.abs(value))
	buffer.writebits(b, bitoffset + 23, 1, sign)
end

--- reads signed 24-bit integer from buffer
--@native
local function readi24(b: buffer, offset: number)
	local bitoffset = offset * 8
	local value = buffer.readbits(b, bitoffset, 23)
	local sign = buffer.readbits(b, bitoffset + 23, 1)
	
	if sign == 1 then
		value *= -1
		value -= 1
	end
	
	return value
end

--- ### replication.luau
---
--- cc replication job & buffer constructors
local replication = {
	--- local replication buffer
	self = buffer.create(12);

	--- cached resync replication buffers
	resynccache = table.create(1 + Players.MaxPlayers) :: {buffer};

	--- u24 vector precision
	precision = 1/40;

	--- `client replication buffer -> server` send rate
	clientsendrate = 1/30;
	--- `server replication buffers -> clients`
	serversendrate = 1/15;

	--- replication states
	states = {
		--- not moving (0)
		"idle";
		--- moving (1)
		"walk";
		--- airborne (2)
		"fall";
		--- flying (3)
		"fly";
	};

	resyncreplicationoffset = 0;
	resyncuseridoffset = 12;
	resynctimeoffset = 20;

	--- unreliableremoteevent byte limit
	unreliablebytelimit = 1000;
}

--- creates a replication buffer
--- ```
--- key    position x   position y   position z   rotation x  rotation y  input & state
--- bytes  [000]        [000]        [000]        [0]         [0]         [0]
--- range  [0 .. 2]     [3 .. 5]     [6 .. 8]     [9]         [10]        [11]
--- value  [0, 2^23-1]  [0, 2^23-1]  [0, 2^23-1]  [0, 255]    [0, 255]    [...]
--- ```
--- input & state bit field
--- ```
--- key    input x   input y   input z   state
--- bits   [00]      [00]      [00]      [00]
--- range  [0 .. 1]  [2 .. 3]  [4 .. 5]  [6 .. 7]
--- value  [0, 3]    [0, 3]    [0, 3]    [0, 3]
--- ```
function replication.create()
	return buffer.create(12)
end

--- writes position to replication buffer
function replication.writeposition(r: buffer, position: Vector3)
	--- this uses division because writing position is only done once per frame
	--- whereas reading position is done for every replicated character
	position /= replication.precision

	writei24(r, 0, position.X)
	writei24(r, 3, position.Y)
	writei24(r, 6, position.Z)
end

--- reads position from replication buffer
function replication.readposition(r: buffer)
	return Vector3.new(
		readi24(r, 0),
		readi24(r, 3),
		readi24(r, 6)
	) * replication.precision
end

--- writes rotation axes to replication buffer
function replication.writerotation(r: buffer, rx: number?, ry: number?)
	if rx then
		buffer.writeu8(r, 9, math.map(rx, -math.pi, math.pi, 0, 255))
	end
	if ry then
		buffer.writeu8(r, 10, math.map(ry, -math.pi, math.pi, 0, 255))
	end
end

--- reads rotation from replication buffer (`CFrame.fromOrientation()`, YXZ)
function replication.readrotation(r: buffer)
	return CFrame.fromOrientation(
		math.map(buffer.readu8(r, 9), 0, 255, -math.pi, math.pi),
		math.map(buffer.readu8(r, 10), 0, 255, -math.pi, math.pi),
		0
	)
end

--- writes input x,y,z to replication buffer \
--- `0: 0 input` \
--- `1: + input` \
--- `2: - input` \
--- `3: +- input` (only applicable to y)
function replication.writeinput(r: buffer, x: number, y: number, z: number)
	buffer.writebits(r, 88, 2, x)
	buffer.writebits(r, 90, 2, y)
	buffer.writebits(r, 92, 2, z)
end

--- reads input x,y,z from replication buffer
function replication.readinput(r: buffer)
	return
		buffer.readbits(r, 88, 2),
		buffer.readbits(r, 90, 2),
		buffer.readbits(r, 92, 2)
end

--- writes state to replication buffer \
--- `0: idle (input vector xz magnitude == 0)` \
--- `1: walk (input vector xz magnitude ~= 0)` \
--- `2: fall (input vector y > 0)` \
--- `3: fly (custom state)`
function replication.writestate(r: buffer, state: number)
	buffer.writebits(r, 94, 2, state)
end

--- reads state from replication buffer
function replication.readstate(r: buffer, state: number)
	return buffer.readbits(r, 94, 2)
end

--- returns zero-indexed state as its equivalent string representation (`replication.states[state + 1]`)
function replication.statetostring(state: number)
	return replication.states[state + 1]
end

function replication.statefromstring(s: string)
	local index = table.find(replication.states, s)
	if index then
		return index - 1
	else
		return 0
	end
end

--- creates a resync buffer
--- ```
--- key    replication buffer  player userid  resync time
--- bytes  [00000000 0000]     [00000000]     [00000000] 
--- range  [0 .. 11]           [12 .. 19]     [20 .. 27] 
--- value  [...]               [f64]          [f64]      
--- ```
function replication.createresyncbuffer()
	return buffer.create(28) --- replication.resyncreplicationoffset + replication.resyncuseridoffset + replication.resynctimeoffset
end

--- writes replication to resync buffer
function replication.resyncwritereplication(resync: buffer, r: buffer)
	buffer.copy(resync, 0, r, 0, replication.resyncuseridoffset)
end

--- reads replication from resync buffer
function replication.resyncreadreplication(resync: buffer)
	local r = replication.create()
	buffer.copy(r, 0, resync, 0, replication.resyncuseridoffset)

	return r
end

--- writes userid to resync buffer
function replication.resyncwriteuserid(resync: buffer, userid: number)
	buffer.writef64(resync, replication.resyncuseridoffset, userid)
end

--- reads userid from resync buffer
function replication.resyncreaduserid(resync: buffer)
	return buffer.readf64(resync, replication.resyncuseridoffset)
end

--- writes time to resync buffer
function replication.resyncwritetime(resync: buffer, time: number)
	buffer.writef64(resync, replication.resynctimeoffset, time)
end

--- increments time of resync buffer
function replication.resyncincrtime(resync: buffer, value: number)
	buffer.writef64(resync, replication.resynctimeoffset, buffer.readf64(resync, replication.resynctimeoffset) + value)
end

--- reads time from resync buffer
function replication.resyncreadtime(resync: buffer)
	return buffer.readf64(resync, replication.resynctimeoffset)
end

--- internal `table.sort()` function for `replication.resyncstep(...)` \
--- sorts by time in descending order
function replication.resynccomp(a: buffer, b: buffer)
	return buffer.readf64(a, replication.resynctimeoffset) > buffer.readf64(b, replication.resynctimeoffset)
end

--- advances cached resync buffers by `dt`, then sorts in descending order \
--- this is so every resync buffer will eventually get resynced \
--- as the `server -> client` packet iterates backward so it will \
--- always start with the most non-recent
function replication.resyncstep(dt: number)
	local resynccache = replication.resynccache

	for _, resync in ipairs(resynccache) do
		replication.resyncincrtime(resync, dt)
	end

	table.sort(resynccache, replication.resynccomp)
end

--- creates a `server -> client` bigbuffer and the # of allocatable resync buffers
function replication.createbigbuffer()
	local resynccache = replication.resynccache
	local len = #resynccache

	--- basically everything leading up to the resync time since that's irrelevant to the cliients
	local size = replication.resynctimeoffset

	--- unreliable remote limit
	--- 9 bytes overhead, 2 bytes data type
	local truebudget = replication.unreliablebytelimit - (9 + 2)
	local maxentries = truebudget // size

	local allocate = math.min(len, maxentries)

	return buffer.create(allocate * size), allocate
end

--- allocates resync buffers from resynccache to bigbuffer
function replication.bigbufferalloc(b: buffer, allocate: number)
	if allocate > 0 then
		local len = replication.resynctimeoffset
		local offset = (allocate - 1) *len
		local resync = table.remove(replication.resynccache, 1)
		if resync then
			buffer.copy(b, offset, resync, 0, len)

			replication.bigbufferalloc(b, allocate - 1)
		else
			return
		end
	else
		return
	end
end

--- resyncs replication buffer from client
function replication.bigbufferserverresync(player: Player, challengereplication: buffer)
	assert(type(challengereplication) == "buffer", "cc replication buffer type mismatch")
	assert(buffer.len(challengereplication) == replication.resyncuseridoffset, "cc replication buffer len mismatch")

	local userid = player.UserId
	local index, resync = replication.findbyuserid(userid)
	if index and resync then
		replication.resyncwritereplication(resync, challengereplication)
	else
		resync = replication.createresyncbuffer()
		assert(resync) --- ts ts

		replication.resyncwritereplication(resync, challengereplication)
		replication.resyncwriteuserid(resync, userid)
		--- replication.resyncwritetime(resync, 0) --- unnecessary

		table.insert(replication.resynccache, resync)
	end
end

--- resyncs bigbuffer from server
function replication.bigbufferclientresync(b: buffer)
	local resynccache = replication.resynccache
	local size = replication.resynctimeoffset

	local len = buffer.len(b)
	for i = 1, len, size do --- for i = 0 ... requires a `i == buffer.len()` read to stop loop
		local offset = (i - 1)
		local challenge = buffer.create(size)
		buffer.copy(challenge, 0, b, offset, size)
		
		--- if preexisting replication, copy to preexisting
		local userid = replication.resyncreaduserid(challenge)
		local preexisting = false
		for _, resync in resynccache do
			if replication.resyncreaduserid(resync) == userid then
				buffer.copy(resync, 0, challenge, 0)
				preexisting = true

				break
			end
		end

		--- if no preexisting replication, insert new replication
		if not preexisting then
			table.insert(resynccache, challenge)
		end
	end
end

--- returns index-value pair of userid replication buffer
function replication.findbyuserid(userid: number): (number?, buffer?)
	for i, resync in ipairs(replication.resynccache) do
		if replication.resyncreaduserid(resync) == userid then
			return i, resync
		end
	end

	return nil, nil
end

--- removes all occurrences of resync buffers whose `userid == userid`
function replication.resyncremovebyuserid(userid: number)
	local resynccache = replication.resynccache
	for i = #resynccache, 1, -1 do
		local resyncbuffer = resynccache[i]
		if replication.resyncreaduserid(resyncbuffer) == userid then
			table.remove(resynccache, i)
		end
	end
end

--- replication
if IsServer then
	local recent = os.clock() - replication.serversendrate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > replication.serversendrate then
			recent = now - (dt - replication.serversendrate)

			--- increment by dt and sort
			replication.resyncstep(dt)
			
			--- create bigbuffer and allocate
			local bigbuffer, allocate = replication.createbigbuffer()
			replication.bigbufferalloc(bigbuffer, allocate)

			if allocate > 0 then
				Remote:FireAllClients(bigbuffer)
			end
		end
	end)

	Remote.OnServerEvent:Connect(replication.bigbufferserverresync)

	Players.PlayerRemoving:Connect(function(player: Player)
		replication.resyncremovebyuserid(player.UserId)
	end)
else
	local recent = os.clock() - replication.clientsendrate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > replication.clientsendrate then
			recent = now - (dt - replication.clientsendrate)

			Remote:FireServer(replication.self)
		end
	end)

	Remote.OnClientEvent:Connect(replication.bigbufferclientresync)

	Players.PlayerRemoving:Connect(function(player: Player)
		replication.resyncremovebyuserid(player.UserId)
	end)
end

return replication