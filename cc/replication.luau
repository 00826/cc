--!strict
--!native

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local isserver = RunService:IsServer()

local Remote = script.Parent:WaitForChild("Remote")

--- writes signed 24-bit integer to buffer
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
	self = buffer.create(13);

	--- cached resync replication buffers
	resynccache = table.create(1 + Players.MaxPlayers) :: {buffer};

	--- replication buffer snapshots
	snapshots = {} :: {[string]: {buffer}};
	snapshotlifetime = 1000;

	--- u24 vector precision
	precision = 1/40;

	--- `client replication buffer -> server` send rate
	clientsendrate = 1/30;
	--- `server replication buffers -> clients`
	serversendrate = 1/20;

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
	resyncuseridoffset = 13;
	resynctimeoffset = 21;

	snapshottimestampoffset = 13;

	--- unreliableremoteevent byte limit
	unreliablebytelimit = 1000;
	
	--- default breakpoint reset frame
	breakpointresetframe = 60;

	--- interpolation settings

	--- base value for resolving framerate-independent interpolant `1 - (base ^ dt)`
	interpolationbase = 10e-11;
	--- interpolation motor6d part0
	interpolationmotorpart0 = workspace.Terrain;
	--- table of interpolation targets \
	--- written-to and read-from externally
	interpolationtargets = {} :: {[string]: { character: Model, motor: Motor6D, adornment: HandleAdornment? }};
	interpolationadornmentsenabled = false;
	interpolationmotorflag = "_interpolationmotor";
	interpolationadornmentflag = "_interpolationadornment";
}

--- creates a replication buffer
--- ```
--- key    position x   position y   position z   rotation x  rotation y  input & state
--- bytes  [000]        [000]        [000]        [0]         [0]         [00]
--- range  [0 .. 2]     [3 .. 5]     [6 .. 8]     [9]         [10]        [11 .. 12]
--- value  [0, 2^23-1]  [0, 2^23-1]  [0, 2^23-1]  [0, 255]    [0, 255]    [...]
--- ```
--- input & state bit field
--- ```
--- key    input x     input y   input z      state
--- bits   [000000]    [00]      [000000]    [00]
--- offset [88+6]      [94+2]    [96+6]      [102+2]
--- range  [0 .. 5]    [6 .. 7]  [8 .. 13]   [14 .. 15]
--- value  [0, 2^6-1]  [0, 3]    [0, 2^6-1]  [0, 3]
--- ```
function replication.create()
	return buffer.create(13)
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

--- reads rotation x,y from replication buffer
function replication.readrotation(r: buffer)
	return
		math.map(buffer.readu8(r, 9), 0, 255, -math.pi, math.pi),
		math.map(buffer.readu8(r, 10), 0, 255, -math.pi, math.pi)
end

--- writes input values to replication buffer
function replication.writeinput(r: buffer, x: number, yup: number, ydown: number, z: number)
	buffer.writebits(r, 88, 6, math.map(x, -1, 1, 0, 63))
	buffer.writebits(r, 94, 2, replication.updowntobits(yup, ydown))
	buffer.writebits(r, 96, 6, math.map(z, -1, 1, 0, 63))
end

--- reads input from replication buffer
function replication.readinput(r: buffer)
	return
		math.map(buffer.readbits(r, 88, 6), 0, 63, -1, 1),
		buffer.readbits(r, 94, 2),
		math.map(buffer.readbits(r, 96, 6), 0, 63, -1, 1)
end

--- writes state to replication buffer \
--- `0: idle (input vector xz magnitude == 0)` \
--- `1: walk (input vector xz magnitude ~= 0)` \
--- `2: fall (input vector y > 0)` \
--- `3: fly (custom state)`
function replication.writestate(r: buffer, state: number)
	buffer.writebits(r, 102, 2, state)
end

--- reads state from replication buffer
function replication.readstate(r: buffer)
	return buffer.readbits(r, 102, 2)
end

--- returns zero-indexed state as its equivalent string representation (`replication.states[state + 1]`)
function replication.statetostring(state: number)
	return replication.states[state + 1]
end

--- returns zero-indexed state from its equivalent string representation (`table.find(replication.states, s) - 1`)
function replication.statefromstring(s: string)
	local index = table.find(replication.states, s)
	if index then
		return index - 1
	else
		return 0
	end
end

--- converts up/down input to unsigned bits
--- `0, 0 -> 0` \
--- `1, 0 -> 1` \
--- `0, 1 -> 2` \
--- `1, 1 -> 3`
function replication.updowntobits(up: number, down: number)
	return up == 0 and down == 0 and 0
		or up == 1 and down == 0 and 1
		or up == 0 and down == 1 and 2
		or up == 1 and down == 1 and 3
		or 0
end

--- converts unsigned bits to signed integers
function replication.bitstoupdown(x: number)
	if x == 3 then
		return 1, 1
	elseif x == 2 then
		return 0, 1
	elseif x == 1 then
		return 1, 0
	else
		return 0, 0
	end
end

--- creates a resync buffer
--- ```
--- key    replication buffer  player userid  resync time
--- bytes  [00000000 00000]    [0000 0000]    [0000 0000] 
--- range  [0 .. 12]           [13 .. 20]     [21 .. 28] 
--- value  [...]               [f64]          [f64]      
--- ```
function replication.createresyncbuffer()
	return buffer.create(29) --- replication.resyncreplicationoffset + replication.resyncuseridoffset + replication.resynctimeoffset
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
function replication.bigbufferalloc(b: buffer, allocate: number, timestamp: number)
	local len = replication.resynctimeoffset
	for i = 1, allocate do
		local resync = replication.resynccache[i]
		if resync then
			local offset = (i - 1) * len
			--- copy into bigbuffer
			buffer.copy(b, offset, resync, 0, len)
			--- create-and-insert snapshot
			local snapshot = replication.createsnapshotbuffer(resync, timestamp)
			local userid = replication.resyncreaduserid(resync)
			replication.snapshotinsert(userid, snapshot)
		else
			break
		end
	end
	--[[if allocate > 0 then
		local len = replication.resynctimeoffset
		local offset = (allocate - 1) * len
		local resync = table.remove(replication.resynccache, 1)
		if resync then
			--- copy into bigbuffer
			buffer.copy(b, offset, resync, 0, len)
			--- create-and-insert snapshot
			local snapshot = replication.createsnapshotbuffer(resync, timestamp)
			local userid = replication.resyncreaduserid(resync)
			replication.snapshotinsert(userid, snapshot)

			replication.bigbufferalloc(b, allocate - 1, timestamp)
		else
			return
		end
	else
		return
	end]]
end

--- resyncs replication buffer from client
function replication.bigbufferserverresync(player: Player, challengereplication: buffer)
	assert(type(challengereplication) == "buffer", "cc replication buffer type mismatch")
	assert(buffer.len(challengereplication) == replication.resyncuseridoffset, "cc replication buffer len mismatch")

	local userid = player.UserId
	local stringuserid = tostring(userid)
	--- create snapshot if not created by playeradded
	if not replication.snapshots[stringuserid] then
		replication.snapshots[stringuserid] = replication.createsnapshotalloc()
	end

	--- resync replication
	local _, resync = replication.findbyuserid(userid)
	if resync then
		replication.resyncwritereplication(resync, challengereplication)
	else
		resync = replication.createresyncbuffer()
		if type(resync) == "buffer" then --- ts ts
			replication.resyncwritereplication(resync, challengereplication)
			replication.resyncwriteuserid(resync, userid)
			--- replication.resyncwritetime(resync, 0) --- unnecessary

			table.insert(replication.resynccache, resync)
		end
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

--- creates a snapshot buffer
--- ```
--- key    replication buffer  timestamp
--- bytes  [00000000 0000 0]   [00000000]   
--- range  [0 .. 12]           [13 .. 20]   
--- value  [...]               [f64]        
--- ```
function replication.createsnapshotbuffer(r: buffer?, timestamp: number?)
	local s = buffer.create(21)

	if r then
		replication.snapshotwritereplication(s, r)
	end
	if timestamp then
		replication.snapshotwritetimestamp(s, timestamp)
	end

	return s
end

--- returns space-allocated table wrt `replication.snapshotlifetime` and `replication.serversendrate` \
function replication.createsnapshotalloc()
	return table.create(1 + (replication.snapshotlifetime / 1000) * (replication.serversendrate) // 1)::{buffer}
end

--- writes replication to snapshot buffer
function replication.snapshotwritereplication(snapshot: buffer, r: buffer)
	buffer.copy(snapshot, 0, r, 0, replication.snapshottimestampoffset)
end

--- reads replication from snapshot buffer
function replication.snapshotreadreplication(snapshot: buffer)
	local r = replication.create()
	buffer.copy(r, 0, snapshot, 0, replication.snapshottimestampoffset)

	return r
end

--- writes timestamp to snapshot buffer
function replication.snapshotwritetimestamp(snapshot: buffer, timestamp: number)
	buffer.writef64(snapshot, replication.snapshottimestampoffset, timestamp)
end

--- reads timestamp from snapshot buffer
function replication.snapshotreadtimestamp(snapshot: buffer)
	return buffer.readf64(snapshot, replication.snapshottimestampoffset)
end

--- adds snapshot buffer to array of snapshot buffers associated with userid
function replication.snapshotinsert(userid: number, snapshot: buffer)
	local stringuserid = tostring(userid)

	local snapshots = replication.snapshots[stringuserid]
	if snapshots then
		table.insert(snapshots, 1, snapshot)
	else
		--- shouldve been allocated in replication.bigbufferserverresync()
		--- isnt checked here bc the code calling this function runs hot
	end
end

--- removes expired snapshots from array
function replication.snapshotflush(snapshots: {buffer}, timestamp: number)
	for i = #snapshots, 1, -1 do
		local s = snapshots[i]
		local elapsed = timestamp - replication.snapshotreadtimestamp(s)
		if elapsed > replication.snapshotlifetime then
			table.remove(snapshots, i)
		else
			break
		end
	end
end

--- reads interpolated position between `a` and `b` wrt interpolant `t`
function replication.snapshotinterpolateposition(snapshots: {buffer}, timestamp: number)
	local a = snapshots[1]
	local b = snapshots[2]
	if a and b then
		local apos = replication.readposition(a)
		local atime = replication.resyncreadtime(a)
		local bpos = replication.readposition(b)
		local btime = replication.resyncreadtime(b)

		local t = math.clamp(math.map(timestamp, btime, atime, 0, 1), 0, 1)

		return (vector.lerp(bpos::any, apos::any, t)::any)::Vector3
	elseif a then
		return replication.readposition(a)
	else
		return Vector3.zero
	end
end

--- returns delta position
function replication.snapshotreaddeltaposition(snapshots: {buffer})
	local a = snapshots[1]
	local b = snapshots[2]
	if a and b then
		local apos = replication.readposition(a)
		local bpos = replication.readposition(b)

		return apos - bpos
	else
		return Vector3.zero
	end
end

--- performs binary search on snapshots, starting at `i (?=1)` and ending at `j (?=#t)` \
--- returns: \
--- index `a` of the snapshot that is closest to `timestamp` \
--- index `b` of the snapshot next-closest to `timestamp` \
--- interpolant `t` describing the position `[0, 1]` of `timestamp` between `a` and `b`
function replication.snapshotnearestbinarysearch(snapshots: {buffer}, timestamp: number, i: number?, j: number?)
	i = i or 1
	j = j or #snapshots
	
	if i > j then
		return nil::number?, nil::number?, nil::number?
	else
		local index = (i + j) // 2
		local snapshot = snapshots[index]
		local stimestamp = replication.snapshotreadtimestamp(snapshot)
		
		if stimestamp == timestamp then
			return index, index, 0
		elseif stimestamp < timestamp then
			i = index + 1

			local next = snapshots[i]
			if next ~= nil then
				local nexttimestamp = replication.snapshotreadtimestamp(next)
				if nexttimestamp > timestamp then
					local adelta = math.abs(stimestamp - timestamp)
					local bdelta = math.abs(nexttimestamp - timestamp)
					local time = math.map(timestamp, stimestamp, nexttimestamp, 0, 1)

					if adelta < bdelta then
						return index, i, time
					else
						return i, index, time
					end
				end
			end
		elseif stimestamp > timestamp then
			j = index - 1

			local prev = snapshots[j]
			if prev ~= nil then
				local prevtimestamp = replication.snapshotreadtimestamp(prev)
				if prevtimestamp < timestamp then
					local adelta = math.abs(stimestamp - timestamp)
					local bdelta = math.abs(prevtimestamp - timestamp)
					local time = math.map(timestamp, stimestamp, prevtimestamp, 0, 1)

					if adelta < bdelta then
						return index, j, time
					else
						return j, index, time
					end
				end
			end
		end
		
		return replication.snapshotnearestbinarysearch(snapshots, timestamp, i, j)
	end
end

--- creates an interpolation target
function replication.createinterpolationtarget(
	character: Model,
	adornmentconfig: {
		class: (
			| "BoxHandleAdornment"
			| "ConeHandleAdornment"
			| "CylinderHandleAdornment"
			| "ImageHandleAdornment"
			| "LineHandleAdornment"
			| "PyramidHandleAdornment"
			| "SphereHandleAdornment"
			| "WireframeHandleAdornment"
		),
		transparency: number,
		color: Color3
	}?
)
	local name = character.Name

	local motor6d = Instance.new("Motor6D")
	motor6d.Name = name .. replication.interpolationmotorflag
	motor6d.Part0 = replication.interpolationmotorpart0
	motor6d.Part1 = character.PrimaryPart
	motor6d.Parent = replication.interpolationmotorpart0
	
	local adornment
	if adornmentconfig ~= nil then
		adornment = Instance.new(adornmentconfig.class::any)::HandleAdornment
		adornment.Name = name .. replication.interpolationadornmentflag
		adornment.Visible = replication.interpolationadornmentsenabled
		adornment.Transparency = adornmentconfig.transparency
		adornment.Color3 = adornmentconfig.color
		adornment.Adornee = motor6d.Part1::any
		adornment.Parent = replication.interpolationmotorpart0
	end

	return {
		character = character;
		motor = motor6d;
		adornment = adornment;
	}
end

function replication.interpolationrefreshadornments(t: {[string]: typeof(replication.createinterpolationtarget(...))})
	for a, b in t do
		for k, v in pairs(b::any) do
			if typeof(v) == "Instance" then
				if v:IsA("HandleAdornment") then
					v.Visible = replication.interpolationadornmentsenabled
				end
			end
		end
	end
end

--- destroys interpolation target
function replication.interpolationtargetdestroy(t: typeof(replication.createinterpolationtarget(...)))
	for k, v in pairs(t::any) do
		if typeof(v) == "Instance" then
			if v:IsA("Motor6D") then
				v.Part0 = nil
				v.Part1 = nil
			elseif v:IsA("HandleAdornment") then
				v.Adornee = nil::any
			end

			v:Destroy()
		end
	end

	table.clear(t)
end

--- creates a breakpoint table \
--- frames should be divide evenly into `replication.breakpointresetframe` and sorted by distance in ascending order
function replication.createbreakpoints(values: {{ distance: number, interpolate: boolean, frame: number }})
	return {
		focus = Vector3.zero;
		frame = 0;
		resetframe = replication.breakpointresetframe;
		values = values;
	}
end

--- advances breakpoint frame forward by integer value \
--- resets frame to 0 if `frame >= 60`
function replication.breakpointstep(b: typeof(replication.createbreakpoints(...)), value: number)
	b.frame += value
	if b.frame >= b.resetframe then
		b.frame = 0
	end

	return b.frame
end

--- returns breakpoint value wrt distance between position and breakpoint focus
function replication.breakpointreadvalue(b: typeof(replication.createbreakpoints(...)), position: Vector3)
	local distance = vector.magnitude(b.focus - position::any)
	for i, breakpoint in ipairs(b.values) do
		if distance < breakpoint.distance then
			return i, breakpoint
		end
	end

	return #b.values + 1, b.values[#b.values] or { distance = math.huge, interpolate = false, frame = 1 }
end

--- returns framerate-independent interpolant
function replication.i(dt: number)
	return 1 - (replication.interpolationbase ^ dt)
end

--- replication
if isserver then
	local recent = os.clock() - replication.serversendrate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > replication.serversendrate then
			recent = now - (dt - replication.serversendrate)

			--- increment by dt and sort
			replication.resyncstep(dt)
			
			--- create bigbuffer and allocate
			local unixtimestampmillis = DateTime.now().UnixTimestampMillis
			local bigbuffer, allocate = replication.createbigbuffer()
			replication.bigbufferalloc(bigbuffer, allocate, unixtimestampmillis)

			--- resync bigbuffer
			if allocate > 0 then
				Remote:FireAllClients(bigbuffer)
			end
			
			--- flush expired
			for stringuserid, snapshots in replication.snapshots do
				replication.snapshotflush(snapshots, unixtimestampmillis)
			end
		end
	end)

	Remote.OnServerEvent:Connect(replication.bigbufferserverresync)

	Players.PlayerAdded:Connect(function(player: Player)
		local userid = player.UserId
		replication.snapshots[tostring(userid)] = replication.createsnapshotalloc()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local userid = player.UserId
		replication.resyncremovebyuserid(userid)
		replication.snapshots[tostring(userid)] = nil
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