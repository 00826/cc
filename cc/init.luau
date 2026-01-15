--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")

local Remote = script:WaitForChild("Remote")

--- returns unit vector from input vector `i`, relative to viewport `lookvector, -upvector`
--- @native
local function movevector(i: Vector3, lookvector: Vector3, upvector: Vector3)
	local rightvector = (vector.cross(lookvector::any, upvector::any)::any)::Vector3
	local cos, sin

	--[[
	local r00, r01, r02 = rightvector.X, upvector.X, lookvector.X
	local   _,   _, r12 = rightvector.Y, upvector.Y, lookvector.Y
	local   _,   _, r22 = rightvector.Z, upvector.Z, lookvector.Z]]

	local r12 = lookvector.Y

	if r12 < 1 and r12 > -1 then
		cos = lookvector.Z
		sin = lookvector.X
	else
		cos = rightvector.X
		sin = -upvector.X*math.sign(lookvector.Y)
	end

	local length = (cos*cos + sin*sin)^0.5
	return Vector3.new(cos*i.X + sin*i.Z, 0, cos*i.Z - sin*i.X) / length
end

--- returns xyz movevector from input vector `i` and vertical input `v` relative to `cframe`
--- @native
function movevectorxyz(i: Vector3, v: number, cframe: CFrame)
	local vec = cframe.Rotation:VectorToWorldSpace(i) + (Vector3.yAxis * v)
	if vec == Vector3.zero then
		return Vector3.zero
	end

	return (vector.normalize(vec::any)::any)::Vector3 --- this is insane
end

--- writes signed 24-bit integer to buffer
--- @native
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
--- @native
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

--- ### cc.luauㅤ/character controller/
---
--- humanoidless player controller and replicator \
--- [*view cc on github*](https://github.com/00826/cc)
local cc = {
	rig = require(script:WaitForChild("rig"));
	cameracontroller = not IsServer and require(script:WaitForChild("cameracontroller")) or nil;
	inputcontroller = not IsServer and require(script:WaitForChild("inputcontroller")) or nil;

	input = {
		--- empty raycastparams
		raycastparams = RaycastParams.new();

		--- empty inputvector
		--- `ControlScript:GetMoveVector()`
		inputvector = Vector3.zero;
		--- binary integer [0|1] describing upward input (jump)
		inputup = 0;
		--- binary integer [0|1] describing downward input (slide)
		inputdown = 0;

		--- empty camera cframe
		cameracframe = CFrame.identity;

		--- character rotation type
		rotationtype = Enum.RotationType.MovementRelative;

		--- is in flying state
		flying = false;
		--- if flying, rotate x axis?
		flyingrotatex = true;

		--- extend floorcast length by this many studs
		floorcastextend = 0;
		--- extend floorcast radius by this many studs
		radiusextend = 0;

		--- if slope of floorcast hit against vector3.yaxis is greater than this value, floor is ignored
		floorcastslopelimit = math.rad(89);

		--- truespeed = speed * speedmodifier
		speed = 16;
		speedmodifier = 1;

		--- truejumppower = jumppower * jumpmodifier
		jumppower = 50;
		jumpmodifier = 1;

		--- truefloatpower = floatpower * floatmodifier
		floatpower = 0;
		floatmodifier = 1;

		bodyvelocitymaxforce = Vector3.new(10000, 10000, 10000);
		bodyvelocitymaxforcemodifier = 1;
		bodyvelocityp = 100;

		bodygyrod = 500;
		bodygyromaxtorque = Vector3.new(400000, 400000, 400000);
		bodygyrop = 500;
	};
	output = {
		--- floor, if found, of character stepped by `cc.step()`
		floor = nil :: RaycastResult?;
		--- cframe of character stepped by `cc.step()`
		cframe = CFrame.identity;
		--- locomotion state
		locomotion = 0;
		--- world-relative move vector
		truevector = Vector3.zero;
	};
	locomotionstates = {
		"idle";
		"walk";
		"fall";
		"fly";
	};
	replication = {
		self = buffer.create(12);
		cache = table.create(1 + Players.MaxPlayers) :: {buffer};

		readwriteprecision = 50;

		clientsendrate = 1/45;
		serversendrate = 1/15;

		unreliablebytelimit = 1000;
	};
	interpolation = {
		base = 10e-11;
		maxcycle = 1;
		breakpoints = table.create(8);
	};

	--- cc character container instance
	container = workspace;
	--- cc character collision group
	collisiongroup = "Default";

	sphere = script:WaitForChild("Sphere");
	spheremeshid = "rbxassetid://122701517143775"; --- break glass in case of rojo
	spherecollisionfidelity = Enum.CollisionFidelity.Hull --- break glass in case of rojo
}

--- creates new character
function cc.create()
	local character = Instance.new("Model")
	--- sphere
	local sphere = cc.sphere:Clone()
	sphere.Name = "Sphere"
	sphere.Parent = character

	--- rootpart
	local rootpart = Instance.new("Part")
	rootpart.Name = "RootPart"
	rootpart.CastShadow = false
	rootpart.Transparency = 1
	rootpart.Anchored = false
	rootpart.CanCollide = false
	rootpart.CanQuery = false
	rootpart.CanTouch = false
	rootpart.Massless = false
	rootpart.Size = Vector3.new(2, 2, 2)
	rootpart.Parent = character

	character.PrimaryPart = rootpart

	--- head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CastShadow = false
	head.Transparency = 1
	head.Anchored = false
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.Size = Vector3.new(1, 1, 1)
	head.Parent = character
	
	do --- top/bottom attachments
		local ta = Instance.new("Attachment")
		ta.Name = "TopAttachment"
		ta.Position = Vector3.yAxis * 4
		ta.Parent = rootpart

		local ba = Instance.new("Attachment")
		ba.Name = "BottomAttachment"
		ba.Position = Vector3.yAxis * -1
		ba.Parent = rootpart
	end

	do --- motors
		local hj = Instance.new("Motor6D")
		hj.Name = "HeadJoint"
		hj.C0 = CFrame.new(Vector3.yAxis * 3.5)
		hj.Part0 = rootpart
		hj.Part1 = head
		hj.Parent = rootpart

		local rj = Instance.new("Motor6D")
		rj.Name = "RigJoint"
		rj.C0 = CFrame.new(Vector3.yAxis * 2)
		rj.Part0 = rootpart
		rj.Part1 = nil
		rj.Parent = rootpart

		local sj = Instance.new("Motor6D")
		sj.Name = "SphereJoint"
		sj.C0 = CFrame.new(Vector3.yAxis * 1.55)
		sj.Part0 = rootpart
		sj.Part1 = sphere
		sj.Parent = rootpart
	end

	do --- movers
		local input = cc.input
		local bg = Instance.new("BodyGyro")
		bg.CFrame = CFrame.identity
		bg.D = input.bodygyrod
		bg.MaxTorque = input.bodygyromaxtorque
		bg.P = input.bodygyrop
		bg.Parent = rootpart

		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.zero
		bv.MaxForce = input.bodyvelocitymaxforce
		bv.P = input.bodyvelocityp
		bv.Parent = rootpart
	end

	do --- hitbox
		local hb = Instance.new("SphereHandleAdornment")
		hb.Name = "Hitbox"
		hb.CFrame = CFrame.new(Vector3.yAxis * 2)
		hb.Color3 = Color3.fromRGB(163, 162, 165)
		hb.Transparency = 0
		hb.AdornCullingMode = Enum.AdornCullingMode.Never
		hb.AlwaysOnTop = true
		hb.Radius = 0.125
		hb.Visible = false
		hb.ZIndex = 1
		hb.Adornee = rootpart
		hb.Parent = rootpart
	end
	
	for _, thing in character:QueryDescendants("BasePart") do
		if thing:IsA("BasePart") then
			thing.CollisionGroup = cc.collisiongroup
		end
	end
	
	return character
end

--- returns interpolation breakpoint wrt distance
function cc.interpolationbreakpoint(distance: number)
	for i, b in ipairs(cc.interpolation.breakpoints) do
		if distance < b.distance then
			return b
		end
	end

	return { distance = math.huge, interpolate = false, cycle = 1 }
end

--- applies interpolation breakpoints \
--- auto-sorts `b` by distance, ascending
function cc.applybreakpoints(b: { {distance: number, interpolate: boolean, cycle: number} })
	table.sort(b, function(j, k)
		return j.distance < k.distance
	end)

	table.clear(cc.interpolation.breakpoints)
	table.move(b, 1, #b, 1, cc.interpolation.breakpoints)

	local maxcycle = 1
	for _, breakpoint in ipairs(b) do
		local cycle = breakpoint.cycle
		if maxcycle < cycle then
			maxcycle = cycle
		end
	end

	cc.interpolation.MaxCycle = maxcycle
end

--- packs cframe, locomotion state, and signed vertical input into 12-wide replication
function cc.pack(cframe: CFrame, locomotionstate: number, inputup: number, inputdown: number, r: buffer?)
	if not r then
		r = buffer.create(12)
	end
	assert(r)

	local position = cframe.Position * cc.replication.readwriteprecision
	writei24(r, 0, position.X)
	writei24(r, 3, position.Y)
	writei24(r, 6, position.Z)

	local rx, ry = cframe:ToOrientation()
	buffer.writeu8(r, 9, math.map(rx, -math.pi, math.pi, 0, 255))
	buffer.writeu8(r, 10, math.map(ry, -math.pi, math.pi, 0, 255))

	local bitoffset = 11 * 8
	buffer.writebits(r, bitoffset + 0, 6, locomotionstate)
	buffer.writebits(r, bitoffset + 6, 1, inputup)
	buffer.writebits(r, bitoffset + 7, 1, inputdown)

	return r
end

--- unpacks cframe, locomotion state, and vertical inputs from 12-wide replication
function cc.unpack(r: buffer)
	local position = Vector3.new(
		readi24(r, 0),
		readi24(r, 3),
		readi24(r, 6)
	) / cc.replication.readwriteprecision

	local rx = math.map(buffer.readu8(r, 9), 0, 255, -math.pi, math.pi)
	local ry = math.map(buffer.readu8(r, 10), 0, 255, -math.pi, math.pi)
	
	local bitoffset = 11 * 8
	local locomotionstate = buffer.readbits(r, bitoffset + 0, 6)
	local inputup = buffer.readbits(r, bitoffset + 6, 1)
	local inputdown = buffer.readbits(r, bitoffset + 7, 1)

	return CFrame.new(position) * CFrame.fromOrientation(rx, ry, 0), locomotionstate, inputup, inputdown
end

--- unpacks cframe from 12-wide replication
function cc.unpackcframe(r: buffer)
	local position = Vector3.new(
		readi24(r, 0),
		readi24(r, 3),
		readi24(r, 6)
	) / cc.replication.readwriteprecision

	local rx = math.map(buffer.readu8(r, 9), 0, 255, -math.pi, math.pi)
	local ry = math.map(buffer.readu8(r, 10), 0, 255, -math.pi, math.pi)

	return CFrame.new(position) * CFrame.fromOrientation(rx, ry, 0)
end

--- returns floor of character
function cc.floorcast(character: typeof(cc.create()), radius: number, heightextend: number?)
	local rootpart = character.PrimaryPart::any

	local topattachment = rootpart.TopAttachment
	local bottomattachment = rootpart.BottomAttachment

	local upvector = topattachment.WorldCFrame.UpVector
	local topposition = topattachment.WorldCFrame.Position
	local bottomposition = bottomattachment.WorldCFrame.Position

	--- radius crunch
	topposition -= upvector * radius
	bottomposition += upvector * radius

	local height = vector.magnitude(topposition - bottomposition)
	height += heightextend or 1/8

	return workspace:Spherecast(topposition, radius, -upvector * height, cc.input.raycastparams)
end

--- advances character by `dt`
function cc.step(character: typeof(cc.create()), dt: number)
	local input = cc.input
	local output = cc.output

	local sphere = character:FindFirstChild("Sphere")
	if not sphere then return end
	if not sphere:IsA("BasePart") then return end

	local rootpart = character.PrimaryPart::any
	if not rootpart then return end
	if not rootpart:IsA("BasePart") then return end

	local cframe = rootpart.CFrame

	local bodygyro = rootpart.BodyGyro
	local bodyvelocity = rootpart.BodyVelocity

	local floor = cc.floorcast(character, (sphere.Size.X * 0.5) + input.radiusextend, input.floorcastextend)
	if floor then
		if vector.angle(floor.Normal, Vector3.yAxis::any) > input.floorcastslopelimit then
			floor = nil
		end
	end

	local isflying = input.flying
	local vertical = input.inputup - input.inputdown

	--- jump
	if input.inputup == 1 then
		local lv = rootpart.AssemblyLinearVelocity
		if floor then
			rootpart.AssemblyLinearVelocity = Vector3.new(lv.X, input.jumppower * input.jumpmodifier, lv.Z)
		else
			rootpart:ApplyImpulse(Vector3.yAxis * input.floatpower * input.floatmodifier * dt)
		end
	end
	
	--- true input vector
	local truevector = Vector3.zero
	local cameracframe = input.cameracframe
	if isflying then
		truevector = movevectorxyz(input.inputvector, vertical, cameracframe)
	else
		truevector = movevector(input.inputvector, -cameracframe.LookVector, cameracframe.UpVector)
	end
	local len = vector.magnitude(truevector::any)::any
	local ismoving = len > 0
	if ismoving then
		truevector = vector.normalize(truevector::any)::any
	end

	--- resolve bodygyro
	bodygyro.MaxTorque = input.bodygyromaxtorque
	bodygyro.D = input.bodygyrod
	bodygyro.P = input.bodygyrop
	bodygyro.CFrame = CFrame.identity

	--- forcing rootpart cframe resolves camera jitter for some reason likely some conflict with movers
	local rootcframe = CFrame.new(cframe.Position)
	rootpart.CFrame = rootcframe
	rootpart.AssemblyAngularVelocity = Vector3.zero

	--- resolve bodyvelocity
	local velocity = truevector * input.speed * input.speedmodifier * math.clamp(len, 0, 1)
	if isflying then
		bodyvelocity.MaxForce = input.bodyvelocitymaxforce * input.bodyvelocitymaxforcemodifier
	else
		bodyvelocity.MaxForce = input.bodyvelocitymaxforce * Vector3.new(1, 0, 1) * input.bodyvelocitymaxforcemodifier
	end

	--- bodyvelocity.P = input.bodyvelocityp
	bodyvelocity.Velocity = velocity

	--- resolve locomotion
	local locomotion = nil
	if isflying then
		locomotion = table.find(cc.locomotionstates, "fly")
	else
		if floor == nil then
			locomotion = table.find(cc.locomotionstates, "fall")
		else
			if ismoving then
				locomotion = table.find(cc.locomotionstates, "walk")
			else
				locomotion = table.find(cc.locomotionstates, "idle")
			end
		end
	end

	--- update output
	output.cframe = rootcframe * cameracframe.Rotation
	output.floor = floor
	output.locomotion = locomotion or 0
	output.truevector = truevector
end

local replicationlen = buffer.len(cc.pack(CFrame.identity, 0, 0, 0))
local idoffset = replicationlen + 0
local resyncoffset = replicationlen + 8

--- returns replication id byte offset \
--- for external use
function cc.replicationidoffset()
	return idoffset
end

--- returns replication resync byte offset \
--- for external use
function cc.replicationresyncoffset()
	return resyncoffset
end

--- clears userid from replication cache
function cc.clear(userid: number)
	local cache = cc.replication.cache
	for i = #cache, 1, -1 do
		local b = cache[i]
		if buffer.readf64(b, idoffset) == userid then
			table.remove(cache, i)
		end
	end
end

if IsServer then
	local cache = cc.replication.cache

	local truebudget = cc.replication.unreliablebytelimit - (9 + 2) --- unreliable remote limit - (9 bytes overhead, 2 bytes data type)
	local maxentries = truebudget // (replicationlen + 8) --- [replicationlen bytes replication pack, 8 bytes userid]

	local recent = os.clock() - cc.replication.serversendrate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > cc.replication.serversendrate then
			recent = now - (dt - cc.replication.serversendrate)

			--- advance all buffers by deltatime
			--- then sort by latest resync time
			--- so that resyncing is an eventuality
			for _, replication in cache do
				local resynctime = buffer.readf64(replication, resyncoffset)
				buffer.writef64(replication, resyncoffset, resynctime + dt)
			end

			table.sort(cache, function(a, b)
				return buffer.readf64(a, resyncoffset) > buffer.readf64(b, resyncoffset)
			end)
			
			--- create big buffer to send over network
			local cachelen = #cache
			local bigbuffer = buffer.create(resyncoffset * math.min(cachelen, maxentries))
			for i = cachelen, 1, -1 do
				local replication = cache[i]
				if replication then
					local offset = (i - 1) * resyncoffset
					buffer.copy(bigbuffer, offset, replication, 0, resyncoffset)

					table.remove(cache, i)
				end
			end

			--- only send if worth sending over
			if buffer.len(bigbuffer) > 0 then
				Remote:FireAllClients(bigbuffer)
			end
		end
	end)

	Remote.OnServerEvent:Connect(function(player: Player, challenge: buffer)
		assert(type(challenge) == "buffer", "cc replication buffer type mismatch")
		assert(buffer.len(challenge) == replicationlen, "cc replication buffer len mismatch")

		--- if preexisting replication, copy to preexisting
		local userid = player.UserId
		local preexisting = false
		for _, replication in cache do
			if buffer.readf64(replication, idoffset) == userid then
				buffer.copy(replication, 0, challenge, 0, replicationlen) --- copy replication portion
				preexisting = true

				break
			end
		end

		--- if no preexisting replication, insert new replication
		if not preexisting then
			local replication = buffer.create(replicationlen + 16) --- [replicationlen bytes replication pack, 8 bytes userid, 8 bytes resynctime]
			buffer.copy(replication, 0, challenge, 0, replicationlen) --- copy replication + userid portion
			buffer.writef64(replication, idoffset, userid)
			--- buffer.writef64(replication, resyncoffset, 0)

			table.insert(cache, replication)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		cc.clear(player.UserId)
	end)
else
	local cache = cc.replication.cache

	local recent = os.clock() - cc.replication.clientsendrate
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - recent
		if dt > cc.replication.clientsendrate then
			recent = now - (dt - cc.replication.clientsendrate)

			Remote:FireServer(cc.replication.self)
		end
	end)

	local function resync(bigbuffer: buffer)
		local len = buffer.len(bigbuffer)
		for i = 1, len, resyncoffset do
			local offset = (i - 1)
			local challenge = buffer.create(resyncoffset)
			buffer.copy(challenge, 0, bigbuffer, offset, resyncoffset)
			
			--- if preexisting replication, copy to preexisting
			local userid = buffer.readf64(challenge, idoffset)
			local preexisting = false
			for _, replication in cache do
				if buffer.readf64(replication, idoffset) == userid then
					buffer.copy(replication, 0, challenge, 0)
					preexisting = true

					break
				end
			end

			--- if no preexisting replication, insert new replication
			if not preexisting then
				table.insert(cache, challenge)
			end
		end
	end

	Remote.OnClientEvent:Connect(resync)

	Players.PlayerRemoving:Connect(function(player: Player)
		cc.clear(player.UserId)
	end)
end

return cc