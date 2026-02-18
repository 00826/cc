--!strict

--- export type limb = {
--- 	meshid: string;
--- 	scale: Vector3;
--- 	hasface: boolean;
--- 
--- 	humanoiddescriptionclothingproperties: { string };
--- 	humanoiddescriptioncolorproperty: string;
--- 
--- 	size: Vector3;
--- 	transparency: number;
--- 
--- 	attachments: { [string]: CFrame };
--- 	animationconstraints: { [string]: { attachment0: string, attachment1: string, iskinematic: boolean } };
--- 	ballsocketconstraints: { [string]: { attachment0: string, attachment1: string } };
--- 
--- 	ragdollcollision: boolean;
--- }

--- ### rig.luau
--- 
--- minimal r6+2(hands) rig \
--- visual geometry, uv texturing, and hat placement is consistent with a humanoid r6 rig
local rig = {
	ballsocketconstraintproperties = {
		LimitsEnabled = true;
		TwistLimitsEnabled = true;
		UpperAngle = 45;
		Restitution = 0;
		MaxFrictionTorque = 5;
		TwistLowerAngle = -25;
		TwistUpperAngle = 25;
	};

	boytorso = "rbxassetid://17580060252";
	girltorso = "rbxassetid://70841440477204";
}

--- creates a typed limbdescription
function rig.createlimbdescription()
	return {
		meshid = "";
		scale = Vector3.one;
		hasface = false;

		humanoiddescriptionclothingproperties = {} :: {string};
		humanoiddescriptioncolorproperty = "";

		size = Vector3.one;
		transparency = 0;

		attachments = {} :: { [string]: CFrame };
		animationconstraints = {} :: { [string]: { attachment0: string, attachment1: string, iskinematic: boolean } };
		ballsocketconstraints = {} :: { [string]: { attachment0: string, attachment1: string } };

		ragdollcollision = false;
	}
end

--- creates a character rig
function rig.create(limbmap: {[string]: typeof(rig.createlimbdescription())})
	local r = Instance.new("Model")
	r.Name = "rig"

	--- animationcontroller
	local animationcontroller = Instance.new("AnimationController")
	local animator = Instance.new("Animator")
	animator.Parent = animationcontroller
	animationcontroller.Parent = r

	--- resolve limbs, attachments, animationconstraints
	local limbs = {}
	local attachments = {}
	local animationconstraints = {}
	local ballsocketconstraints = {}

	for name, entry in limbmap do
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
			limb.CanCollide = false --- true
		elseif limb.Name == "Torso" then
			limb.CastShadow = true
			limb.CanCollide = false --- true
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

			if attachments[k] then
				print("duplicate attachment overwritten:", k)
			end
			attachments[k] = attachment
		end

		--- limb mesh
		if entry.meshid ~= nil and entry.meshid ~= "" then
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
		if entry.hasface == true then
			local decal = Instance.new("Decal")
			decal.Name = "face"
			decal.Face = Enum.NormalId.Front
			decal.Parent = limb
		end

		limb.Parent = r

		limbs[name] = limb
	end

	--- resolve animationconstraints and ballsocketconstraints
	for name, entry in limbmap do
		local limb = limbs[name]
		for acname, properties in pairs(entry.animationconstraints) do
			local animationconstraint = Instance.new("AnimationConstraint")
			animationconstraint.Name = acname
			animationconstraint.Parent = limb
			animationconstraint.Attachment0 = attachments[properties.attachment0]
			animationconstraint.Attachment1 = attachments[properties.attachment1]
			animationconstraint.IsKinematic = properties.iskinematic == true

			animationconstraints[acname] = animationconstraint
		end
		for bscname, properties in pairs(entry.ballsocketconstraints) do
			local ballsocketconstraint = Instance.new("BallSocketConstraint")
			ballsocketconstraint.Name = bscname
			ballsocketconstraint.Enabled = false
			ballsocketconstraint.Parent = limb
			ballsocketconstraint.Attachment0 = attachments[properties.attachment0]
			ballsocketconstraint.Attachment1 = attachments[properties.attachment1]

			for k, v in pairs(rig.ballsocketconstraintproperties) do
				(ballsocketconstraint::any)[k] = v
			end

			ballsocketconstraints[bscname] = ballsocketconstraint
		end
	end

	r.PrimaryPart = limbs.RootPart
	assert(r.PrimaryPart, "error resolving rootpart")
	
	return r
end

--- applies bodycolors to rig
function rig.applybodycolors(r: typeof(rig.create(...)), limbmap: {[string]: typeof(rig.createlimbdescription())}, bodycolors: { [string]: any })
	for name, entry in limbmap do
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
function rig.applyclothing(r: typeof(rig.create(...)), limbmap: {[string]: typeof(rig.createlimbdescription())}, clothing: { Shirt: string?; Pants: string?; ShirtColor: Color3?; PantsColor: Color3?; } & { [string]: any })
	for name, entry in limbmap do
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
function rig.applybodypartappearance(r: typeof(rig.create(...)), limbmap: {[string]: typeof(rig.createlimbdescription())}, bodypart: string, meshid: string?, color: Color3?, clothingtexture: string?)
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

--- toggles enabled property of constraints in rig and sets limb cancollide \
--- `"animationconstraint"` for non-ragdoll \
--- `"ballsocketconstraint"` for radgoll
function rig.setactiveconstraints(r: typeof(rig.create(...)), limbmap: {[string]: typeof(rig.createlimbdescription())}, activeconstraint: "animationconstraint"|"ballsocketconstraint", blacklist: {string}?)
	for name, entry in limbmap do
		local limb = r:FindFirstChild(name)
		--- cancollide
		if limb and limb:IsA("BasePart") and entry.ragdollcollision == true then
			if activeconstraint == "animationconstraint" then
				limb.CanCollide = false --- true
			elseif activeconstraint == "ballsocketconstraint" then
				limb.CanCollide = true
			end
		end
	end

	--- constraints
	for _, thing in r:QueryDescendants("AnimationConstraint, BallSocketConstraint") do
		if blacklist and table.find(blacklist, thing.Name) then continue end

		if thing:IsA("AnimationConstraint") then
			thing.Enabled = activeconstraint == "animationconstraint"
		elseif thing:IsA("BallSocketConstraint") then
			thing.Enabled = activeconstraint == "ballsocketconstraint"
		end
	end
end

--- resets motor transforms \
--- call before playing a non-procedural animation
function rig.resetanimationconstrainttransforms(r: typeof(rig.create(...)))
	for _, animationconstraint in r:QueryDescendants("AnimationConstraint") do
		assert(animationconstraint:IsA("AnimationConstraint"))
		animationconstraint.Transform = CFrame.identity
	end
end

return rig