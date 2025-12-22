--!strict

--- ### rig.luau
--- 
--- minimal r6+2(hands) rig \
--- visual geometry, uv texturing, and hat placement is consistent with a humanoid r6 rig
local rig = {
	limbs = {
		--- root
		RootPart = {
			humanoiddescriptionclothingproperties = {  };
			humanoiddescriptioncolorproperty = "";

			size = Vector3.new(2, 2, 1);
			transparency = 1;

			attachments = {
				RootAttachment = CFrame.new(0, 0, 0);
			};
			motors = {
				RootJoint = { ragdolls = false; part1 = "Torso"; c0 = CFrame.new() * CFrame.fromOrientation(-math.pi/2, -math.pi, 0); c1 = CFrame.new() * CFrame.fromOrientation(-math.pi/2, -math.pi, 0); };
			};
			ragdollcollision = false;
		};

		--- head
		Head = {
			meshid = "rbxassetid://15606744638";
			scale = Vector3.new(0.999, 0.999, 0.999);
			HasFace = true;

			humanoiddescriptionclothingproperties = {  };
			humanoiddescriptioncolorproperty = "HeadColor";

			size = Vector3.new(1, 1, 1);
			transparency = 0;

			attachments = {
				FaceCenterAttachment = CFrame.new(0, 0, 0);
				FaceFrontAttachment = CFrame.new(0, 0, -0.65);
				HairAttachment = CFrame.new(0, 0.6, 0);
				HatAttachment = CFrame.new(0, 0.6, 0);
			};
			motors = {

			};
			ragdollcollision = true;
		};
		--- torso
		Torso = {
			meshid = "rbxassetid://17580060252";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = { "Shirt"; "Pants"; };
			humanoiddescriptioncolorproperty = "TorsoColor";

			size = Vector3.new(2, 2, 1);
			transparency = 0;

			attachments = {
				BodyBackAttachment = CFrame.new(0, 0, 0.5);
				BodyFrontAttachment = CFrame.new(0, 0, -0.5);
				LeftCollarAttachment = CFrame.new(-1, 1, 0);
				NeckAttachment = CFrame.new(0, 1, 0);
				RightCollarAttachment = CFrame.new(1, 1, 0);
				WaistBackAttachment = CFrame.new(0, -1, 0.5);
				WaistCenterAttachment = CFrame.new(0, -1, 0);
				WaistFrontAttachment = CFrame.new(0, -1, -0.5);
			};
			motors = {
				LeftHip = { ragdolls = true; part1 = "LeftLeg"; c0 = CFrame.new(-1, -1, 0) * CFrame.fromOrientation(0, -math.pi/2, 0); c1 = CFrame.new(-0.5, 1, 0) * CFrame.fromOrientation(0, -math.pi/2, 0); };
				LeftShoulder = { ragdolls = true; part1 = "LeftArm"; c0 = CFrame.new(-1, 0.5, 0) * CFrame.fromOrientation(0, -math.pi/2, 0); c1 = CFrame.new(0.5, 0.5, 0) * CFrame.fromOrientation(0, -math.pi/2, 0); };
				Neck = { ragdolls = true; part1 = "Head"; c0 = CFrame.new(0, 1, 0) * CFrame.fromOrientation(-math.pi/2, -math.pi, 0); c1 = CFrame.new(0, -0.5, 0) * CFrame.fromOrientation(-math.pi/2, -math.pi, 0); };
				RightHip = { ragdolls = true; part1 = "RightLeg"; c0 = CFrame.new(1, -1, 0) * CFrame.fromOrientation(0, math.pi/2, 0); c1 = CFrame.new(0.5, 1, 0) * CFrame.fromOrientation(0, math.pi/2, 0); };
				RightShoulder = { ragdolls = true; part1 = "RightArm"; c0 = CFrame.new(1, 0.5, 0) * CFrame.fromOrientation(0, math.pi/2, 0); c1 = CFrame.new(-0.5, 0.5, 0) * CFrame.fromOrientation(0, math.pi/2, 0); };
			};
			ragdollcollision = true;
		};
		--- left
		LeftArm = {
			meshid = "rbxassetid://17580119910";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = { "Shirt" };
			humanoiddescriptioncolorproperty = "LeftArmColor";

			size = Vector3.new(1, 2, 1);
			transparency = 0;

			attachments = {
				LeftGripAttachment = CFrame.new(0, -1, 0);
				LeftShoulderAttachment = CFrame.new(0, 1, 0);
			};
			motors = {
				LeftWrist = { ragdolls = false; part1 = "LeftHand"; c0 = CFrame.new(0, -1, 0) * CFrame.fromOrientation(-math.pi/2, 0, 0); c1 = CFrame.new() * CFrame.fromOrientation(0, 0, 0); };
			};
			ragdollcollision = true;
		};
		LeftHand = {
			meshid = "";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = {  };
			humanoiddescriptioncolorproperty = "";

			size = Vector3.new(1, 1, 1);
			transparency = 1;

			attachments = {
				LeftHandAttachment = CFrame.new(0, 0, 0);
			};
			motors = {

			};
			ragdollcollision = false;
		};
		LeftLeg = {
			meshid = "rbxassetid://17580119910";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = { "Pants" };
			humanoiddescriptioncolorproperty = "LeftLegColor";

			size = Vector3.new(1, 2, 1);
			transparency = 0;

			attachments = {
				LeftFootAttachment = CFrame.new(0, -1, 0);
			};
			motors = {

			};
			ragdollcollision = true;
		};
		--- right
		RightArm = {
			meshid = "rbxassetid://17580118235";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = { "Shirt" };
			humanoiddescriptioncolorproperty = "RightArmColor";

			size = Vector3.new(1, 2, 1);
			transparency = 0;

			attachments = {
				RightGripAttachment = CFrame.new(0, -1, 0);
				RightShoulderAttachment = CFrame.new(0, 1, 0);
			};
			motors = {
				RightWrist = { ragdolls = false; part1 = "RightHand"; c0 = CFrame.new(0, -1, 0) * CFrame.fromOrientation(-math.pi/2, 0, 0); c1 = CFrame.new() * CFrame.fromOrientation(0, 0, 0); };
			};
			ragdollcollision = true;
		};
		RightHand = {
			meshid = "";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = {  };
			humanoiddescriptioncolorproperty = "";

			size = Vector3.new(1, 1, 1);
			transparency = 1;

			attachments = {
				RightHandAttachment = CFrame.new(0, 0, 0);
			};
			motors = {

			};
			ragdollcollision = false;
		};
		RightLeg = {
			meshid = "rbxassetid://17580118235";
			scale = Vector3.new(1, 1, 1);

			humanoiddescriptionclothingproperties = { "Pants" };
			humanoiddescriptioncolorproperty = "RightLegColor";

			size = Vector3.new(1, 2, 1);
			transparency = 0;

			attachments = {
				RightFootAttachment = CFrame.new(0, -1, 0);
			};
			motors = {

			};
			ragdollcollision = true;
		};
	};

	motorangleflag = "cc_aangle";

	swaptabler6 = {
		["HumanoidRootPart"] = "RootPart";
		["Head"] = "Head";
		["Torso"] = "Torso";
		["Right Arm"] = "RightArm";
		["Left Arm"] = "LeftArm";
		["Right Hand"] = "RightHand";
		["Left Hand"] = "LeftHand";
		["Right Leg"] = "RightLeg";
		["Left Leg"] = "LeftLeg";
	};

	boytorso = "rbxassetid://17580060252";
	girltorso = "rbxassetid://70841440477204";
}

--- returns a character rig
--- ```lua
--- r: typeof(rig.create())
--- ├ RootPart: BasePart
--- ├ Head: BasePart
--- ├ Torso: BasePart
--- ├ LeftArm: BasePart
--- ├ LeftHand: BasePart
--- ├ LeftLeg: BasePart
--- ├ RightArm: BasePart
--- ├ RightHand: BasePart
--- ├ RightLeg: BasePart
--- └ AnimationController: AnimationController
--- 	└ Animator: Animator
--- ```
function rig.create(lt: typeof(rig.limbs)?)
	local r = Instance.new("Model")
	r.Name = "rig"

	--- animationcontroller
	local animationcontroller = Instance.new("AnimationController")
	local animator = Instance.new("Animator")
	animator.Parent = animationcontroller
	animationcontroller.Parent = r

	--- resolve limbs
	local limbs = {}

	for name, entry in (lt or rig.limbs)::any do
		local limb = Instance.new("Part")
		limb.Name = name

		--- general limb case
		limb.CanQuery = false
		limb.CanTouch = false
		limb.Anchored = false
		limb.Massless = true
		limb.EnableFluidForces = false
		
		limb.Size = entry.size
		limb.Transparency = entry.transparency

		--- special cases
		if name == "RootPart" then
			limb.CastShadow = false
			limb.CanCollide = false
		elseif limb.Name == "Head" then
			limb.CastShadow = true
			limb.CanCollide = true
		elseif limb.Name == "Torso" then
			limb.CastShadow = true
			limb.CanCollide = true
		else
			limb.CastShadow = true
			limb.CanCollide = false
		end

		--- attachments
		for k, cframe in entry.attachments do
			local attachment = Instance.new("Attachment")
			attachment.Name = k
			attachment.CFrame = cframe
			attachment.Parent = limb
		end

		--- limb mesh
		if entry.meshid ~= nil then
			local specialmesh = Instance.new("SpecialMesh")
			specialmesh.Name = "LimbMesh"
			specialmesh.Parent = limb

			specialmesh.MeshType = Enum.MeshType.FileMesh
			specialmesh.MeshId = entry.meshid
			specialmesh.Scale = entry.scale
		end

		--- clothing/face layer
		for i, property in ipairs(entry.humanoiddescriptionclothingproperties) do
			local decal = Instance.new("Decal")
			decal.Name = property
			decal.Face = Enum.NormalId.Front
			decal.Parent = limb
			decal.ZIndex = #entry.humanoiddescriptionclothingproperties - i
		end
		if entry.HasFace == true then
			local decal = Instance.new("Decal")
			decal.Name = "face"
			decal.Face = Enum.NormalId.Front
			decal.Parent = limb
		end

		limb.Parent = r

		limbs[name] = limb
	end

	--- resolve motors
	for name, entry: any in rig.limbs do
		local limb = limbs[name]
		for motorname, properties in entry.motors do
			local motor6d = Instance.new("Motor6D")
			motor6d.Name = motorname
			motor6d.Parent = limb

			motor6d.Part0 = limb
			motor6d.Part1 = limbs[properties.part1]
			motor6d.C0 = properties.c0
			motor6d.C1 = properties.c1
		end
	end

	r.PrimaryPart = limbs.RootPart
	assert(r.PrimaryPart, "error resolving rootpart")
	
	return r
end

--- applies bodycolors to rig
function rig.applybodycolors(r: typeof(rig.create()), bodycolors: { [string]: Color3 } & { [string]: any })
	for name, entry in rig.limbs::any do
		local limbcolorproperty = entry.humanoiddescriptioncolorproperty
		if not limbcolorproperty then continue end
		if limbcolorproperty == "" then continue end

		local targetcolor = bodycolors[limbcolorproperty]
		if not targetcolor then continue end
		if type(targetcolor) == "string" then targetcolor = Color3.fromHex(targetcolor) end
		if typeof(targetcolor) ~= "Color3" then warn(string.format("expected Color3, got %s", typeof(targetcolor))); continue end

		for _, limb in r:QueryDescendants(string.format(">[ClassName = Part][Name = %s]", name)) do
			if limb and limb:IsA("BasePart") then
				limb.Color = targetcolor
			end
		end
	end
end

--- applies clothing textures to rig
function rig.applyclothing(r: typeof(rig.create()), clothing: { Shirt: string?; Pants: string?; ShirtColor: Color3?; PantsColor: Color3?; } & { [string]: any })
	for name, entry in rig.limbs::any do
		local clothingproperties = entry.humanoiddescriptionclothingproperties
		for _, property in clothingproperties do
			local targetassetid = clothing[property]
			if type(targetassetid) == "nil" then continue end
			if type(targetassetid) ~= "string" then warn(string.format("expected string, got %s", typeof(targetassetid))); continue end
			local targetcolor = Color3.fromRGB(255, 255, 255)

			if property == "Shirt" then
				targetcolor = clothing.ShirtColor or targetcolor
			elseif property == "Pants" then
				targetcolor = clothing.ShirtColor or targetcolor
			else
				warn(string.format("expected Shirt or Pants, got unknown property %s", property))
			end

			for _, limb in r:QueryDescendants(string.format(">[ClassName = Part][Name = %s]", name)) do
				for _, layer in limb:QueryDescendants(string.format(">[ClassName = Decal][Name = %s]", property)) do
					if layer and layer:IsA("Decal") then
						layer.ColorMapContent = Content.fromUri(targetassetid)
						layer.Color3 = targetcolor
					end
				end
			end
		end
	end
end

--- applies meshid to rig limb
function rig.applybodypartappearance(r: typeof(rig.create()), bodypart: string, meshid: string?, color: Color3?, clothingtexture: string?)
	local limb = r:FindFirstChild(bodypart)
	if limb and limb:IsA("BasePart") then
		if meshid then
			local specialmesh = limb:FindFirstChildOfClass("SpecialMesh")
			if specialmesh then
				specialmesh.MeshId = meshid
			end
		end
		if color then
			limb.Color = color
		end
		if clothingtexture then
			local clothinglayer = limb:FindFirstChild("ClothingLayer")
			if clothinglayer and clothinglayer:IsA("Decal") then
				clothinglayer.ColorMapContent = Content.fromUri(clothingtexture)
			end
		end
	end
end

function rig.ragdollmotors()
	local result = {}
	for _, entry: any in rig.limbs do
		for motor: string, m in entry.motors do
			if m.ragdolls == true then
				table.insert(result, motor)
			end
		end
	end

	return result
end

function rig.ragdolllimbs()
	local result = {}
	for limbname: string, entry: any in rig.limbs::any do
		if entry.ragdollcollision == true then
			table.insert(result, limbname)
		end
	end

	return result
end

--- solves motor6d.desiredangle
function rig.solvemotordesiredangle(motor: Motor6D, desiredangle: number): number
	local current = (motor:GetAttribute(rig.motorangleflag) or 0) :: number

	if desiredangle > current then
		current += motor.MaxVelocity * 1
		if current > desiredangle then
			current = desiredangle
		end
	elseif desiredangle < current then
		current += motor.MaxVelocity * -1
		if current < desiredangle then
			current = desiredangle
		end
	else
		current = desiredangle
	end

	motor:SetAttribute(rig.motorangleflag, current)
	return current
end

--- resets motor transforms \
--- call before playing a non-procedural animation
function rig.resetmotortransforms(r: typeof(rig.create()))
	local root = r:FindFirstChild("RootPart")
	assert(root and root:IsA("BasePart"))
	local torso = r:FindFirstChild("Torso")
	assert(torso and torso:IsA("BasePart"))

	for _, motor in {
		root:FindFirstChild("RootJoint"),
		torso:FindFirstChild("Neck"),
		torso:FindFirstChild("RightShoulder"),
		torso:FindFirstChild("RightHip"),
		torso:FindFirstChild("LeftShoulder"),
		torso:FindFirstChild("LeftHip")
	} do
		if motor and motor:IsA("Motor6D") then
			motor.Transform = CFrame.identity
		end
	end
end

--- procedurally-animates rig motors
function rig.stepmotors(
	r: typeof(rig.create()),
	locomotion: "idle" | "walk" | "fall" | "seat" | "fly",
	crouched: boolean,
	toolpose: "none" | "left" | "right" | "both",
	elapsed: number,
	freq: number?
)
	local root = r:FindFirstChild("RootPart") :: BasePart
	local rootjoint = root:FindFirstChild("RootJoint") :: Motor6D

	local torso = r:FindFirstChild("Torso") :: BasePart
	local neck = torso:FindFirstChild("Neck") :: Motor6D
	local rightshoulder = torso:FindFirstChild("RightShoulder") :: Motor6D
	local righthip = torso:FindFirstChild("RightHip") :: Motor6D
	local leftshoulder = torso:FindFirstChild("LeftShoulder") :: Motor6D
	local lefthip = torso:FindFirstChild("LeftHip") :: Motor6D

	if (not neck)
	or (not rightshoulder)
	or (not righthip)
	or (not leftshoulder)
	or (not lefthip)
	then
		return
	end

	if locomotion == "seat" then
		rightshoulder.MaxVelocity = 0.15
		leftshoulder.MaxVelocity = 0.15
		--- rightshoulder.DesiredAngle = math.pi/2
		--- leftshoulder.DesiredAngle = -math.pi/2
		--- righthip.DesiredAngle = math.pi/2
		--- lefthip.DesiredAngle = -math.pi/2
		rightshoulder.Transform = CFrame.Angles(0, 0, math.pi/2)
		leftshoulder.Transform = CFrame.Angles(0, 0, -math.pi/2)
		righthip.Transform = CFrame.Angles(0, 0, math.pi/2)
		lefthip.Transform = CFrame.Angles(0, 0, -math.pi/2)
		return
	end
	
	local addhipangle = 0

	if (crouched)
	then
		neck.MaxVelocity = 0.5
		rootjoint.MaxVelocity = 0.5
		addhipangle = math.pi/4
		neck.Transform = CFrame.Angles(rig.solvemotordesiredangle(neck, -math.pi/4), 0, 0)
		rootjoint.Transform = CFrame.new(0, 0, -0.25) * CFrame.Angles(rig.solvemotordesiredangle(rootjoint, math.pi/4), 0, 0)
	else
		neck.MaxVelocity = 0.5
		rootjoint.MaxVelocity = 0.5
		addhipangle = 0
		neck.Transform = CFrame.Angles(rig.solvemotordesiredangle(neck, 0), 0, 0)
		rootjoint.Transform = CFrame.Angles(rig.solvemotordesiredangle(rootjoint, 0), 0, 0)
	end
  
	if (locomotion == "fall") then
		rightshoulder.MaxVelocity = 0.5
		leftshoulder.MaxVelocity = 0.5

		if (crouched) then
			local approxangle = 0.1 * math.sin(elapsed * 1)
			rightshoulder.Transform = CFrame.Angles(0, 0, approxangle)
			leftshoulder.Transform = CFrame.Angles(0, 0, approxangle)
		else
			rightshoulder.Transform = CFrame.Angles(0, 0, math.pi)
			leftshoulder.Transform = CFrame.Angles(0, 0, -math.pi)
		end
		righthip.Transform = CFrame.Angles(0, 0, addhipangle)
		lefthip.Transform = CFrame.Angles(0, 0, -addhipangle)

		return
	end

	local amplitude, frequency
	
	if locomotion == "idle" then
		amplitude = 0.1
		frequency = 1
	else
		rightshoulder.MaxVelocity = 0.15
		leftshoulder.MaxVelocity = 0.15
		amplitude = 1 * (crouched and 0.5 or 1)
		frequency = (freq and freq or 9) * (crouched and 0.5 or 1) --- [6, 9, 12]
	end

	local desiredangle = amplitude * math.sin(elapsed * frequency)

	rightshoulder.Transform = CFrame.Angles(0, 0, desiredangle)
	leftshoulder.Transform = CFrame.Angles(0, 0, desiredangle)
	righthip.Transform = CFrame.Angles(0, 0, -(desiredangle - addhipangle))
	lefthip.Transform = CFrame.Angles(0, 0, -(desiredangle + addhipangle))

	if toolpose == "none" then

	elseif toolpose == "right" then
		rightshoulder.Transform = CFrame.Angles(0, 0, math.pi/2)
	elseif toolpose == "left" then
		leftshoulder.Transform = CFrame.Angles(0, 0, -math.pi/2)
	elseif toolpose == "both" then
		rightshoulder.Transform = CFrame.Angles(0, 0, math.pi/2)
		leftshoulder.Transform = CFrame.Angles(0, 0, -math.pi/2)
	end
end

return rig