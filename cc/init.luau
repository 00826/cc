--!strict

local RunService = game:GetService("RunService")
local isserver = RunService:IsServer()

--- returns unit vector from input vector `i`, relative to viewport `lookvector, -upvector`
@native
local function movevector(i: Vector3, lookvector: Vector3, upvector: Vector3)
	local rightvector = (vector.cross(lookvector::any, upvector::any)::any)::Vector3
	local cos, sin

	--- local r00, r01, r02 = rightvector.X, upvector.X, lookvector.X
	--- local   _,   _, r12 = rightvector.Y, upvector.Y, lookvector.Y
	--- local   _,   _, r22 = rightvector.Z, upvector.Z, lookvector.Z

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
@native
function movevectorxyz(i: Vector3, v: number, cframe: CFrame)
	local vec = cframe.Rotation:VectorToWorldSpace(i) + (Vector3.yAxis * v)
	if vec == Vector3.zero then
		return Vector3.zero
	end

	return (vector.normalize(vec::any)::any)::Vector3 --- this is insane
end

--- ### cc.luauㅤ/character controller/
---
--- humanoidless player controller and replicator \
--- [*view cc on github*](https://github.com/00826/cc)
local cc = {
	replication = require(script:WaitForChild("replication"));
	interpolation = require(script:WaitForChild("interpolation"));

	rig = not isserver and require(script:WaitForChild("rig")) or nil;
	cameracontroller = not isserver and require(script:WaitForChild("cameracontroller")) or nil;
	inputcontroller = not isserver and require(script:WaitForChild("inputcontroller")) or nil;
	viewport = not isserver and require(script:WaitForChild("viewport")) or nil;

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

		--- character rotation type, read externally
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
		bodyvelocitymaxforcemodifier = Vector3.one;
		bodyvelocityp = 100;
		--- written externally, similar to cameracontroller shake vectors
		bodyvelocityimpulse = Vector3.zero;

		bodygyrod = 50;
		bodygyromaxtorque = Vector3.new(math.huge, math.huge, math.huge);
		bodygyrop = 100000;
	};
	output = {
		--- position of character stepped by `cc.step()`
		position = Vector3.zero;
		--- camera rotation x/y
		rotationx = 0;
		rotationy = 0;
		--- floor, if found, of character stepped by `cc.step()`
		floor = nil :: RaycastResult?;
		--- state
		state = 0;
		--- world-relative move vector
		truevector = Vector3.zero;
	};

	--- cc character container instance
	container = workspace;
	--- cc character collision group
	collisiongroup = "Default";

	sphere = script:WaitForChild("Sphere");
	--- sphere mesh properties \
	--- break glass in case of rojo; none of these can be set during runtime
	sphereconfig = {
		spheremeshid = "rbxassetid://124869439513703";
		spherecollisionfidelity = Enum.CollisionFidelity.Hull;
		sphererenderfidenlity = Enum.RenderFidelity.Performance;
	};

	spheretransparency = 2/3; --- 1
	roottransparency = 1; --- 1
}

--- creates new character
function cc.create()
	local character = Instance.new("Model")
	--- sphere & associated attachment
	local sphere = cc.sphere:Clone()
	sphere.Name = "Sphere"
	sphere.Transparency = cc.spheretransparency
	sphere.Anchored = false
	sphere.Parent = character
	local sphereattachment = Instance.new("Attachment")
	sphereattachment.Name = "SphereAttachment1"
	sphereattachment.CFrame = CFrame.identity
	sphereattachment.Parent = sphere

	--- rootpart & associated attachment
	local rootpart = Instance.new("Part")
	rootpart.Name = "RootPart"
	rootpart.CastShadow = false
	rootpart.Transparency = cc.roottransparency
	rootpart.Anchored = false
	rootpart.CanCollide = false
	rootpart.CanQuery = false
	rootpart.CanTouch = false
	rootpart.Massless = false
	rootpart.Size = Vector3.new(2, 2, 2)
	rootpart.Parent = character
	--- local rootattachment = Instance.new("Attachment")
	--- rootattachment.Name = "RootAttachment1"
	--- rootattachment.CFrame = CFrame.identity
	--- rootattachment.Parent = rootpart

	character.PrimaryPart = rootpart

	--- head & associated attachment
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
	local headattachment = Instance.new("Attachment")
	headattachment.Name = "HeadAttachment1"
	headattachment.CFrame = CFrame.identity
	headattachment.Parent = head
	
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

	do --- head animationconstraint
		local a0 = Instance.new("Attachment")
		a0.Name = "HeadAttachment0"
		a0.CFrame = CFrame.new(Vector3.yAxis * 3.5)
		a0.Parent = rootpart
		local ac = Instance.new("AnimationConstraint")
		ac.Name = "HeadJoint"
		ac.IsKinematic = true
		ac.Attachment0 = a0
		ac.Attachment1 = headattachment
		ac.Parent = rootpart
	end

	do --- rig animationconstraint
		local a0 = Instance.new("Attachment")
		a0.Name = "RigAttachment0"
		a0.CFrame = CFrame.new(Vector3.yAxis * 2)
		a0.Parent = rootpart
		local ac = Instance.new("AnimationConstraint")
		ac.Name = "RigJoint"
		ac.IsKinematic = true
		ac.Attachment0 = a0
		ac.Attachment1 = nil --- empty to be set by developer
		ac.Parent = rootpart
	end

	do --- rig animationconstraint
		local a0 = Instance.new("Attachment")
		a0.Name = "SphereAttachment0"
		a0.CFrame = CFrame.new(Vector3.yAxis * 1.55)
		a0.Parent = rootpart
		local ac = Instance.new("AnimationConstraint")
		ac.Name = "SphereJoint"
		ac.IsKinematic = true
		ac.Attachment0 = a0
		ac.Attachment1 = sphereattachment
		ac.Parent = rootpart
	end

	do --- movers
		--- keep upright, rotations are applied directly to the rigjoint motor
		local input = cc.input
		local bg = Instance.new("BodyGyro")
		bg.CFrame = CFrame.identity
		bg.D = input.bodygyrod
		bg.MaxTorque = input.bodygyromaxtorque
		bg.P = input.bodygyrop
		bg.Parent = rootpart

		--- xyz movement of sphere
		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.zero
		bv.MaxForce = input.bodyvelocitymaxforce
		bv.P = input.bodyvelocityp
		bv.Parent = rootpart
	end

	do --- hitbox
		--- dot/sphere approximately where rigjoint motor c0 is
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

--- advances character
function cc.step(character: typeof(cc.create()))
	local input = cc.input
	local output = cc.output

	local sphere = character:FindFirstChild("Sphere")
	if not sphere then return end
	if not sphere:IsA("BasePart") then return end

	local rootpart = character.PrimaryPart::any
	if not rootpart then return end
	if not rootpart:IsA("BasePart") then return end

	local bodygyro = rootpart.BodyGyro
	local bodyvelocity = rootpart.BodyVelocity

	local floor = cc.floorcast(character, (sphere.Size.X * 0.5) + input.radiusextend, input.floorcastextend)
	if floor then
		if vector.angle(floor.Normal::any, Vector3.yAxis::any) > input.floorcastslopelimit then
			floor = nil
		end
	end

	local isflying = input.flying
	local vertical = input.inputup - input.inputdown

	--- jump
	local floatvector = Vector3.zero
	if input.inputup == 1 then
		local lv = rootpart.AssemblyLinearVelocity
		if floor then
			rootpart.AssemblyLinearVelocity = Vector3.new(lv.X, input.jumppower * input.jumpmodifier, lv.Z)
		else
			floatvector = Vector3.yAxis * input.floatpower * input.floatmodifier
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

	rootpart.AssemblyAngularVelocity = Vector3.zero

	--- resolve bodyvelocity
	local velocity = (truevector * input.speed * input.speedmodifier * math.clamp(len, 0, 1)) + input.bodyvelocityimpulse
	if isflying then
		bodyvelocity.MaxForce = input.bodyvelocitymaxforce * input.bodyvelocitymaxforcemodifier
		bodyvelocity.Velocity = velocity
	else
		local maxforce = input.bodyvelocitymaxforce * Vector3.new(1, 0, 1) * input.bodyvelocitymaxforcemodifier
		if floatvector ~= Vector3.zero then 
			maxforce += floatvector
		end
		
		bodyvelocity.MaxForce = maxforce
		bodyvelocity.Velocity = velocity + floatvector
	end

	--- resolve state
	local state = 0
	if isflying then
		state = 3 --- fly
	else
		if floor == nil then
			state = 2 --- fall
		else
			if ismoving then
				state = 1 --- walk
			else
				state = 0 --- idle
			end
		end
	end

	--- update output

	local x, y = cameracframe:ToOrientation()

	output.position = rootpart.Position
	output.rotationx = x
	output.rotationy = y
	output.floor = floor
	output.state = state
	output.truevector = truevector
end

return cc