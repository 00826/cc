--!strict

--- ### ccclient.luau
---
--- cc client script

local Players = game:GetService("Players")
local localplayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local replicatedstorage = game:GetService("ReplicatedStorage")
local cc = require(replicatedstorage:WaitForChild("cc"))
local r8limbs = require(script.Parent:WaitForChild("r8limbs"))

local cameracontroller = cc.cameracontroller
local inputcontroller = cc.inputcontroller
local interpolation = cc.interpolation
local replication = cc.replication
local rig = cc.rig
local viewport = cc.viewport

assert(cameracontroller and inputcontroller and rig and viewport) --- type solver

local ccinput = cc.input
local ccoutput = cc.output

local camera = workspace.CurrentCamera

--- set interpolation breakpoints
--- interfacing should be a "set once and forget about it"
interpolation.breakpointset({
	interpolation.createbreakpoint(400, true, 1); --- if interpolation target is within 400 studs, lerp pivot every frame
	interpolation.createbreakpoint(800, false, 2); --- if interpolation target is within 800 studs, pivot every 2 frames
	interpolation.createbreakpoint(1200, false, 4); --- if interpolation target is within 1200 studs, pivot every 4 frames. this is also the fallback if target is beyond the range of all breakpoints
})

--- set base movement values
ccinput.speed = 24
ccinput.jumppower = 50
ccinput.floatpower = 500

--- manip floorcast length/radius
--- so that character can more easily traverse
--- slopes/wedges
ccinput.floorcastextend = 1/8
ccinput.radiusextend = -1/8

--- set cameracontroller zoom behavior
cameracontroller.zoombehavior = "snap"

--- set cameracontroller touch device pan use raw (non-curved) input
--- for responsiveness
cameracontroller.touchpanuserawinput = true

--- set camera fov
camera.FieldOfView = 90

--- if grounded/airborne, apply associated
--- customphysicalproperties to cc sphere (collision/physics geometry)
--- for this case, less friction is applied while airborne
--- to produce sliding/frictionless movement
local airbornecustomphysicalproperties = PhysicalProperties.new(0.7, 0.04, 0.00, 100, 100)
local groundedcustomphysicalproperties = PhysicalProperties.new(0.7, 0.20, 0.00, 100, 100)
local groundstate = false

--- userinputservice reading
--- jump/crouch inputs, although it would make sense if handled internally,
--- is handled externally for easy developer-prescribed behaviors such as
--- jump floating, jump fatigue, etc as well as developer-prescribed button layouts for jumping
--- preferredinputs are set based on recency instead of the roblox-prescribed behavior
--- because for some reason they think it's a good idea to lock inputs to a gamepad if a gamepad
--- is plugged in despite the most recent input coming from a keyboard

local jumpkeys = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }
local crouchkeys = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonB }

local lastjumpinput = 0
local flyactivatetimems = 200

local function inputbegan(inputobject: InputObject, sunk: boolean)
	if sunk then return end
	local keycode = inputobject.KeyCode

	if table.find(jumpkeys, keycode) then
		ccinput.inputup = 1
		
		--- simple double-tap detect
		local now = os.clock()
		if (now - lastjumpinput) * 1000 < flyactivatetimems then
			ccinput.flying = not ccinput.flying
			lastjumpinput = 0
		end

		lastjumpinput = os.clock()
	elseif table.find(crouchkeys, keycode) then
		ccinput.inputdown = 1
	end
end
UserInputService.InputBegan:Connect(inputbegan)

local function inputended(inputobject: InputObject, sunk: boolean)
	if sunk then return end
	local keycode = inputobject.KeyCode

	if table.find(jumpkeys, keycode) then
		ccinput.inputup = 0
	elseif table.find(crouchkeys, keycode) then
		ccinput.inputdown = 0
	end
end
UserInputService.InputEnded:Connect(inputended)

local function preferredinputchanged()
	local pi = inputcontroller.preferredinput
	if pi == Enum.PreferredInput.KeyboardAndMouse and UserInputService.TouchEnabled then
		pi = pi == Enum.PreferredInput.Gamepad and pi or Enum.PreferredInput.Touch	
	end

	inputcontroller.rebind(pi)
end

preferredinputchanged()
inputcontroller.preferredinputchanged():Connect(preferredinputchanged)

local iswindowfocused = false
UserInputService.WindowFocused:Connect(function()
	iswindowfocused = true
end)
UserInputService.WindowFocusReleased:Connect(function()
	iswindowfocused = false
end)
UserInputService.InputChanged:Once(function()
	iswindowfocused = true
end)

--- function to hide limbs when in first-person
--- ideally this would be handled by a transparencycontroller
--- which isn't included in this demo for the sake of simplicity
local hiddenlimbs = {
	"Head";
	"Torso";
	"RightArm";
	"LeftArm";
	"RightLeg";
	"LeftLeg";
	"Sphere";
}

local function updatelimbtransparency(visible: boolean)
	local character = localplayer.Character
	if character then
		for _, thing in character:QueryDescendants("BasePart") do
			assert(thing:IsA("BasePart"))
			if table.find(hiddenlimbs, thing.Name) then
				thing.LocalTransparencyModifier = visible and 0 or 1
			end
		end
	end
end

--- cc step
local function step(dt: number)
	debug.profilebegin("cc_step")

	--- set inputvector from inputcontroller
	--- set cameracframe from currentcamera
	--- both are set externally for cases such as overriding the input vector
	--- or setting the camera to a preset/external cframe for something like a spectate mode
	ccinput.inputvector = inputcontroller.vector
	ccinput.cameracframe = camera.CFrame

	--- interpolate camera shake vectors toward zero using some arbitrary interpolant
	local i = 1 - (10e-5 ^ dt)
	cameracontroller.camerashakeoffset = vector.lerp(cameracontroller.camerashakeoffset::any, Vector3.zero::any, i)::any
	cameracontroller.camerashakerotation = vector.lerp(cameracontroller.camerashakerotation::any, Vector3.zero::any, i)::any

	--- interpolate bodyvelocityimpulse toward zero using some arbitrary interpolant
	--- for this demo, bodyvelocityimpulse is used to produce artificial momentum
	local j = 1 - (10e-7 ^ dt)
	ccinput.bodyvelocityimpulse = vector.lerp(ccinput.bodyvelocityimpulse::any, Vector3.zero::any, j)::any

	--- early return if character doesn't exist
	local character = localplayer.Character
	if not character then return end
	
	if ccinput.flying == true then
		--- if flying, scale speed by 2
		ccinput.speedmodifier = 2
	else
		if ccinput.inputdown == 1 then
			--- if crouched, scale speed by 0.5
			ccinput.speedmodifier = 0.5

			--- if zero input vector or airborne, zero-out xz components of body velocity
			--- otherwise keep normal
			if inputcontroller.vector == Vector3.zero or ccoutput.floor == nil then
				ccinput.bodyvelocitymaxforcemodifier = Vector3.yAxis
			else
				ccinput.bodyvelocitymaxforcemodifier = Vector3.one
			end
		else
			--- if not crouched, scale speed by 1
			ccinput.speedmodifier = 1

			ccinput.bodyvelocitymaxforcemodifier = Vector3.one
		end
	end

	--- commented-out for flying input
	--- if character is below y -2, enter "flying" state
	--- in this case is a pseudo-swimming state
	--- when exiting y -2, apply linear velocity as a free jump/emerge-from-water impulse
	--- local pivot = character:GetPivot()
	--- if pivot.Y < -2 then
	--- 	ccinput.flying = true
	--- 	ccinput.bodyvelocitymaxforcemodifier = 1
	--- 	lastflystate = 1
	--- else
	--- 	ccinput.flying = false
	--- 	ccinput.bodyvelocitymaxforcemodifier = 1
	--- 	if lastflystate ~= 0 then
	--- 		lastflystate = 0
	--- 		local lv = character.PrimaryPart.AssemblyLinearVelocity
	--- 		character.PrimaryPart.AssemblyLinearVelocity = Vector3.new(lv.X, 60, lv.Z)
	--- 	end
	--- end

	local limbsvisible = true

	--- resolve mousebehavior
	local mousebehavior = Enum.MouseBehavior.Default
	if cameracontroller.cameratype == Enum.CameraType.Scriptable then
		--- scriptable/non-controllable
		mousebehavior = Enum.MouseBehavior.Default
		cameracontroller.cameraoffset = Vector3.zero
		ccinput.rotationtype = Enum.RotationType.MovementRelative
	elseif cameracontroller.currentzoomdistance <= cameracontroller.firstpersondistanceminzoom then
		--- first-person
		mousebehavior = Enum.MouseBehavior.LockCenter
		cameracontroller.cameraoffset = Vector3.zero
		ccinput.rotationtype = Enum.RotationType.CameraRelative
		UserInputService.MouseIcon = "rbxasset://textures/cursors/CrossMouseIcon.png"
		limbsvisible = false
	else
		--- third-person
		mousebehavior = Enum.MouseBehavior.LockCenter
		cameracontroller.cameraoffset = Vector3.new(0, 0, 0)
		ccinput.rotationtype = Enum.RotationType.MovementRelative
		UserInputService.MouseIcon = "rbxasset://textures/cursors/CrossMouseIcon.png"
		limbsvisible = true
	end

	updatelimbtransparency(limbsvisible)

	--- extra mousebehavior cases
	if UserInputService.TouchEnabled then
		--- issue where emulating a touch device locks pc cursor to center
		mousebehavior = Enum.MouseBehavior.Default
	elseif iswindowfocused == false then
		--- unlock mouse when window isnt focused
		mousebehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIcon = ""
	end

	--- disable mouse icon in case of custom cursor
	local mouseiconenabled = UserInputService.MouseIconEnabled
	if mouseiconenabled then
		UserInputService.MouseIconEnabled = false
	end

	UserInputService.MouseBehavior = mousebehavior

	--- usually a case exists here to set the inputup/down/vectors to their zero equivalent
	--- if the player-character is dead or the client is in a state where
	--- it shouldnt be allowed to apply movement inputs

	--- step character
	cc.step(character)

	--- write values to local replication buffer after stepping character
	local r = replication.self
	--- write cframe
	replication.writeposition(r, ccoutput.position)
	replication.writerotation(r, ccoutput.rotationx, ccoutput.rotationy)
	--- write movevector
	--- special case exists for up/down inputs as jumping and crouching are 2 separate inputs
	--- with their own independent behaviors
	local movevector = inputcontroller.vector
	replication.writeinput(
		r,
		replication.signedtobits(movevector.X),
		replication.updowntobits(ccinput.inputup, ccinput.inputdown),
		replication.signedtobits(movevector.Z)
	)
	--- write state
	replication.writestate(r, ccoutput.state)

	local grounded = ccoutput.floor ~= nil
	--- if flying and floor is not nil, set flying to false
	if ccinput.flying == true and grounded == true then
		ccinput.flying = false
	end

	--- apply momentum if any movement input is being held
	--- otherwise immediately set impulse to zero
	--- this is so the player-character doesn't slide around
	--- should movement inputs be fully-ceased
	if (ccoutput.truevector ~= Vector3.zero)
	or (ccinput.inputup == 1)
	or (ccinput.inputdown == 1)
	then
		ccinput.bodyvelocityimpulse += ccoutput.truevector
	else
		ccinput.bodyvelocityimpulse = Vector3.zero
	end

	--- apply customphysicalproperties
	if groundstate ~= grounded then
		groundstate = grounded

		local sphere = character:FindFirstChild("Sphere")
		if sphere and sphere:IsA("BasePart") then
			if groundstate == true then
				sphere.CustomPhysicalProperties = groundedcustomphysicalproperties
			else
				sphere.CustomPhysicalProperties = airbornecustomphysicalproperties
			end
		end
	end

	debug.profileend()
end

RunService.Heartbeat:Connect(step)

--- cc replication cycle
local resynccache = replication.resynccache

do --- force guarantee local replication
	local resync = replication.createresyncbuffer()
	replication.resyncwriteuserid(resync, localplayer.UserId)

	table.insert(resynccache, resync)
end

--- small function to find spawnlocation
local function spawnpoint()
	local spawnlocations = workspace:QueryDescendants("SpawnLocation")::{SpawnLocation}
	Random.new():Shuffle(spawnlocations)

	return spawnlocations[1] and spawnlocations[1].Position or Vector3.yAxis * 100
end

--- cache of player-character models;
--- because characters are instantiated on the client, (all the server does is emit buffers)
--- player-characters aren't destroyed when a player leaves
--- because, from the perspective of the server, characters don't exist

--- `{[string stringuserid]: typeof(cc.create())}`
local playercharacters = {} :: {[string]: typeof(cc.create())}

--- removes player-character associated with this player with option to destroy the instance
local function removeplayercharacter(player: Player, destroy: boolean)
	local stringuserid = tostring(player.UserId)

	player.Character = nil
	if destroy == true then
		local character = playercharacters[stringuserid]
		if character then
			character:Destroy()
		end
	end
	playercharacters[stringuserid] = nil
end

--- connect removeplayercharacter to playerremoving signal
Players.PlayerRemoving:Connect(function(player: Player)
	removeplayercharacter(player, true)
end)

--- creates a player-character for this player
local function createplayercharacter(player: Player)
	local userid = player.UserId
	
	local character = cc.create()
	assert(character)
	character.Name = player.Name
	character.Parent = cc.container
	player.Character = character

	--- cache and connect function to uncache when destroyed
	playercharacters[tostring(userid)] = character
	character.Destroying:Once(function()
		removeplayercharacter(player, false)
	end)

	local characterrootpart = character:FindFirstChild("RootPart")
	assert(characterrootpart and characterrootpart:IsA("BasePart"))

	--- localcharacter case
	--- set camerasubject
	--- move to spawnlocation
	if player == localplayer then
		characterrootpart.Anchored = false
		local head = character:WaitForChild("Head")
		camera.CameraSubject = head:IsA("BasePart") and head or nil
		camera.CameraType = Enum.CameraType.Custom

		cameracontroller.resetcameraangle = true

		character:MoveTo(spawnpoint())
	else
		characterrootpart.Anchored = true
	end

	--- create rig and attach
	--- ideally this would be a developer-prescribed rig
	--- but this is just a minimal example
	local newrig = rig.create(r8limbs::any)
	newrig.Parent = character

	local rigroot = newrig:FindFirstChild("RootPart")
	assert(rigroot and rigroot:IsA("BasePart"))
	local rootattachment = rigroot:FindFirstChild("RootAttachment")
	assert(rootattachment and rootattachment:IsA("Attachment"))
	
	local rigjoint = characterrootpart:FindFirstChild("RigJoint")
	assert(rigjoint and rigjoint:IsA("AnimationConstraint"))

	rigjoint.Attachment1 = rootattachment

	return character
end

local function instantiateandreplicate(dt: number)
	debug.profilebegin("cc_instantiateandreplicate")

	--- resolve framerate-independent interpolant for this replication frame
	local t = interpolation.interpolant(dt)
	--- step interpolation frame
	local frame = interpolation.step()

	--- set focus to camera position
	local focus = camera.CFrame.Position

	--- iterate over resynced (`server -> client`) resync buffers
	--- find associated player, apply character or destroy character
	--- resolve breakpoint wrt distance from focus
	--- pivot character to resync buffer position
	for _, resync in resynccache do
		local userid = replication.resyncreaduserid(resync)
		local player = Players:GetPlayerByUserId(userid)
		if player then
			local islocal = player == localplayer
			--- create character if dne
			if not playercharacters[tostring(userid)] then
				createplayercharacter(player)
			else
				--- destroy if below fallenpartsdestroyheight then skip
				local character = player.Character
				if character then
					local pivot = character:GetPivot()
					local primarypart = character.PrimaryPart
					if pivot.Y <= workspace.FallenPartsDestroyHeight or primarypart == nil or not primarypart:IsDescendantOf(workspace) then
						removeplayercharacter(player, true)

						continue
					end
				end
			end

			if islocal then
				--- do nothing, local character is never pivoted
			else
				--- read replicated character position
				local position = replication.readposition(resync)

				--- resolve breakpoint
				local distancefromfocus = vector.magnitude(position::any - focus::any)
				local breakpoint = interpolation.breakpointresolve(distancefromfocus)

				--- pivot/lerp replicated character wrt breakpoint frame
				if frame % breakpoint.frame == 0 then
					local character = player.Character

					if character then
						local cframe = CFrame.new(position)
						if breakpoint.interpolate == true then
							local pivot = character:GetPivot()

							character:PivotTo(pivot:Lerp(cframe, t))
						else
							character:PivotTo(cframe)
						end
					end
				end
			end
		else
			--- attempt to replicate non-player character `id == 0` \
			--- or player associated with this resync buffer does not exist `Players:GetPlayerByUserId(id) == nil`
		end
	end

	debug.profileend()
end

RunService.Heartbeat:Connect(instantiateandreplicate)

--- basic animation pattern
--- always applies strafing/rotations
--- but limb transforms are set every framerate

local angleflag = "rig_angle"
local maxvelocityflag = "rig_maxvelocity"

--- solves motor6d.desiredangle
local function solveanimationconstraintdesiredangle(motor: AnimationConstraint, desiredangle: number)
	local currentangle = (motor:GetAttribute(angleflag) or 0) :: number
	local maxvelocity = (motor:GetAttribute(maxvelocityflag) or 0) :: number

	if desiredangle > currentangle then
		currentangle += maxvelocity * 1
		if currentangle > desiredangle then
			currentangle = desiredangle
		end
	elseif desiredangle < currentangle then
		currentangle += maxvelocity * -1
		if currentangle < desiredangle then
			currentangle = desiredangle
		end
	else
		currentangle = desiredangle
	end

	motor:SetAttribute(angleflag, currentangle)
	return currentangle
end

--- advances rig animation constraint transforms wrt elapsed time
local function stepanimationconstraints(
	r: typeof(rig.create(...)),
	state: "idle" | "walk" | "fall" | "seat" | "fly",
	crouched: boolean,
	toolpose: "none" | "left" | "right" | "both",
	elapsed: number,
	freq: number?
)
	local root = r:FindFirstChild("RootPart") :: BasePart
	local rootjoint = root:FindFirstChild("RootJoint") :: AnimationConstraint

	local torso = r:FindFirstChild("Torso") :: BasePart
	local neck = torso:FindFirstChild("Neck") :: AnimationConstraint
	local rightshoulder = torso:FindFirstChild("RightShoulder") :: AnimationConstraint
	local righthip = torso:FindFirstChild("RightHip") :: AnimationConstraint
	local leftshoulder = torso:FindFirstChild("LeftShoulder") :: AnimationConstraint
	local lefthip = torso:FindFirstChild("LeftHip") :: AnimationConstraint

	if (not neck)
	or (not rightshoulder)
	or (not righthip)
	or (not leftshoulder)
	or (not lefthip)
	then
		return
	end

	if state == "seat" then
		rightshoulder:SetAttribute(maxvelocityflag, 0.15)
		leftshoulder:SetAttribute(maxvelocityflag, 0.15)
		--- rightshoulder.DesiredAngle = math.pi/2
		--- leftshoulder.DesiredAngle = -math.pi/2
		--- righthip.DesiredAngle = math.pi/2
		--- lefthip.DesiredAngle = -math.pi/2
		rightshoulder.Transform = CFrame.fromOrientation(0, 0, math.pi/2)
		leftshoulder.Transform = CFrame.fromOrientation(0, 0, -math.pi/2)
		righthip.Transform = CFrame.fromOrientation(0, 0, math.pi/2)
		lefthip.Transform = CFrame.fromOrientation(0, 0, -math.pi/2)

		return
	end
	
	local addhipangle = 0

	if (crouched)
	then
		neck:SetAttribute(maxvelocityflag, 0.5)
		rootjoint:SetAttribute(maxvelocityflag, 0.5)
		addhipangle = math.pi/4
		neck.Transform = CFrame.fromOrientation(solveanimationconstraintdesiredangle(neck, -math.pi/4), 0, 0)
		rootjoint.Transform = CFrame.new(0, 0, -0.25) * CFrame.fromOrientation(solveanimationconstraintdesiredangle(rootjoint, math.pi/4), 0, 0)
	else
		neck:SetAttribute(maxvelocityflag, 0.5)
		rootjoint:SetAttribute(maxvelocityflag, 0.5)
		addhipangle = 0
		neck.Transform = CFrame.fromOrientation(solveanimationconstraintdesiredangle(neck, 0), 0, 0)
		rootjoint.Transform = CFrame.fromOrientation(solveanimationconstraintdesiredangle(rootjoint, 0), 0, 0)
	end
  
	if (state == "fall") then
		rightshoulder:SetAttribute(maxvelocityflag, 0.5)
		leftshoulder:SetAttribute(maxvelocityflag, 0.5)

		if (crouched) then
			local approxangle = 0.1 * math.sin(elapsed * 1)
			rightshoulder.Transform = CFrame.fromOrientation(0, 0, approxangle)
			leftshoulder.Transform = CFrame.fromOrientation(0, 0, approxangle)
		else
			rightshoulder.Transform = CFrame.fromOrientation(0, 0, math.pi)
			leftshoulder.Transform = CFrame.fromOrientation(0, 0, -math.pi)
		end
		righthip.Transform = CFrame.fromOrientation(0, 0, addhipangle)
		lefthip.Transform = CFrame.fromOrientation(0, 0, -addhipangle)

		return
	end

	local amplitude, frequency
	
	if state == "idle" then
		amplitude = 0.1
		frequency = 1
	else
		rightshoulder:SetAttribute(maxvelocityflag, 0.15)
		leftshoulder:SetAttribute(maxvelocityflag, 0.15)
		amplitude = 1 * (crouched and 0.5 or 1)
		frequency = (freq and freq or 9) * (crouched and 0.5 or 1) --- [6, 9, 12]
	end

	local desiredangle = amplitude * math.sin(elapsed * frequency)

	rightshoulder.Transform = CFrame.fromOrientation(0, 0, desiredangle)
	leftshoulder.Transform = CFrame.fromOrientation(0, 0, desiredangle)
	righthip.Transform = CFrame.fromOrientation(0, 0, -(desiredangle - addhipangle))
	lefthip.Transform = CFrame.fromOrientation(0, 0, -(desiredangle + addhipangle))

	if toolpose == "none" then

	elseif toolpose == "right" then
		rightshoulder.Transform = CFrame.fromOrientation(0, 0, math.pi/2)
	elseif toolpose == "left" then
		leftshoulder.Transform = CFrame.fromOrientation(0, 0, -math.pi/2)
	elseif toolpose == "both" then
		rightshoulder.Transform = CFrame.fromOrientation(0, 0, math.pi/2)
		leftshoulder.Transform = CFrame.fromOrientation(0, 0, -math.pi/2)
	end
end

local framerate = 1/24
local elapsed = 0
local function animate(dt: number)
	elapsed += dt
	local animatethisframe = false
	if elapsed > framerate then
		elapsed = 0
		animatethisframe = true
	end

	--- interpolation.i(dt)
	local i = 1 - (10e-8 ^ dt)

	for _, player in Players:GetPlayers() do
		local islocal = player == localplayer

		--- resolve resync buffer
		--- if player == localplayer then override with local replication
		local resync
		if islocal then
			resync = replication.self
		else
			local _, r = replication.findbyuserid(player.UserId)
			if r then
				resync = r
			end
		end
		if not resync then continue end

		--- soft asserts
		local character = player.Character
		if not character then continue end
		local playerrig = character:FindFirstChild("rig") :: typeof(rig.create(r8limbs::any))?
		if not playerrig then continue end

		--- resolve rotations
		local rx, ry
		if islocal then
			rx, ry = camera.CFrame:ToOrientation()
		else
			rx, ry = replication.readrotation(resync)
		end

		--- resolve rotations for strafing animation
		local ix, iy, iz = replication.readinput(resync)
		local xsign
		if islocal then
			xsign = inputcontroller.vector.X
		else
			xsign = replication.bitstosigned(ix)
		end
		xsign = math.map(xsign, -1, 1, -math.pi/4, math.pi/4)

		local xvalue = character:GetAttribute("xvalue")
		xvalue = type(xvalue) == "number" and xvalue or 0
		
		local xreal = math.lerp(xvalue, xsign, i)
		character:SetAttribute("xvalue", xreal)

		--- set attachment cframes
		for _, attachment in ipairs(character:QueryDescendants("Attachment")) do
			assert(attachment:IsA("Attachment"))
			if attachment.Name == "NeckAttachment1" then
				attachment.CFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(-math.pi/2, 0, math.pi) * CFrame.Angles(rx, 0, -xreal)
			elseif attachment.Name == "RootAttachment" then
				attachment.CFrame = CFrame.fromOrientation(0, -ry + xreal, 0)
			end
		end

		--- procedural animationconstraint animation wrt elapsed (os.clock())
		if animatethisframe then
			local statestring = replication.statetostring(replication.readstate(resync::buffer))
			if statestring == "fly" then
				if ix == 0 and iz == 0 then
					statestring = "idle"
				else
					statestring = "walk"
				end
			end

			task.defer(
				stepanimationconstraints,
				playerrig,
				statestring::any,
				iy == 2 or iy == 3 or false,
				"none"::any,
				os.clock()
			)
		end
	end
end

RunService.Heartbeat:Connect(animate)

return true