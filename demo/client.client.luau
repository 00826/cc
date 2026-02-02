--!strict

--- ### ccclient.client.luau
---
--- cc demo client script \
--- includes play by play commentary hopefully for clarity

local Players = game:GetService("Players")
local localplayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local cc = require(ReplicatedStorage:WaitForChild("cc"))
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

local lastflystate = 0
local lastfloor = nil

--- set interpolation breakpoints \
--- interfacing should be a "set once and forget about it"
interpolation.breakpointset({
	interpolation.createbreakpoint(400, true, 1); --- if interpolation target is within 400 studs, lerp pivot every frame
	interpolation.createbreakpoint(800, false, 2); --- if interpolation target is within 800 studs, pivot every 2 frames
	interpolation.createbreakpoint(1200, false, 4); --- if interpolation target is within 1200 studs, pivot every 4 frames. this is also the fallback if target is beyond the range of all breakpoints
})

--- set base movement values
ccinput.speed = 32
ccinput.jumppower = 50
ccinput.floatpower = 500

--- manip floorcast length/radius
--- so that character can more easily traverse
--- slopes/wedges
ccinput.floorcastextend = 1/8
ccinput.radiusextend = -1/8

--- set cameracontroller zoom behavior
cameracontroller.zoombehavior = "snap"

--- set camera fov
camera.FieldOfView = 90

--- userinputservice reading
--- jump/crouch inputs, although it would make sense if handled internally,
--- is handled externally for easy developer-prescribed behaviors such as
--- jump floating, jump fatigue, etc as well as developer-prescribed button layouts for jumping
--- preferredinputs are set based on recency instead of the roblox-prescribed behavior
--- because for some reason they think it's a good idea to lock inputs to a gamepad if a gamepad
--- is plugged in despite the most recent input coming from a keyboard

local jumpkeys = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }
local crouchkeys = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonB }

local function inputbegan(inputobject: InputObject, sunk: boolean)
	if sunk then return end
	local keycode = inputobject.KeyCode

	if table.find(jumpkeys, keycode) then
		ccinput.inputup = 1
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
	vector.lerp(cameracontroller.camerashakeoffset::any, Vector3.zero::any, i)
	vector.lerp(cameracontroller.camerashakerotation::any, Vector3.zero::any, i)

	--- if crouching (and not flying), scale speed by 0.5
	if ccinput.inputdown == 1 then
		if ccinput.flying then
			ccinput.speedmodifier = 1
		else
			ccinput.speedmodifier = 0.5
		end
	else
		ccinput.speedmodifier = 1
	end

	--- early return if character doesn't exist
	local character = localplayer.Character
	if not character then return end

	--- if character is below y -2, enter "flying" state
	--- in this case is a pseudo-swimming state
	--- when exiting y -2, apply linear velocity as a free jump/emerge-from-water impulse
	local pivot = character:GetPivot()
	if pivot.Y < -2 then
		ccinput.flying = true
		ccinput.bodyvelocitymaxforcemodifier = 1
		lastflystate = 1
	else
		ccinput.flying = false
		ccinput.bodyvelocitymaxforcemodifier = 1
		if lastflystate ~= 0 then
			lastflystate = 0
			local lv = character.PrimaryPart.AssemblyLinearVelocity
			character.PrimaryPart.AssemblyLinearVelocity = Vector3.new(lv.X, 60, lv.Z)
		end
	end

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

	--- step character by dt
	cc.step(character, dt)

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

local function replicate(dt: number)
	debug.profilebegin("cc_replicate")
	interpolation.cycle += 1

	local resetcycle = interpolation.cycle % interpolation.maxcycle == 0
	local i = interpolation.i(dt)

	local replicationfocus = Vector3.zero
	if localplayer.Character then
		replicationfocus = localplayer.Character:GetPivot().Position
	end

	for _, resync in resynccache do
		local userid = replication.resyncreaduserid(resync)
		local player = Players:GetPlayerByUserId(userid)
		if player then
			local islocal = player == localplayer
			if not player.Character then
				--- create character if dne
				local character = cc.create()
				assert(character)
				character.Name = player.Name
				character.Parent = cc.container
				player.Character = character

				local characterrootpart = character:FindFirstChild("RootPart")
				assert(characterrootpart and characterrootpart:IsA("BasePart"))

				--- localcharacter case
				--- set camerasubject
				--- move to spawnlocation
				if islocal then
					characterrootpart.Anchored = false
					camera.CameraSubject = character:WaitForChild("Head")
					camera.CameraType = Enum.CameraType.Custom

					cameracontroller.resetcameraangle = true

					local s, e = pcall(function()
						character:MoveTo(spawnpoint())
					end)
					if not s then warn(e) end
				else
					characterrootpart.Anchored = true
				end

				--- create rig and attach
				local newrig = rig.create()
				newrig.Parent = character

				local rigroot = newrig:FindFirstChild("RootPart")
				assert(rigroot and rigroot:IsA("BasePart"))
				local rootattachment = rigroot:FindFirstChild("RootAttachment")
				assert(rootattachment and rootattachment:IsA("Attachment"))
				
				local rigjoint = characterrootpart:FindFirstChild("RigJoint")
				assert(rigjoint and rigjoint:IsA("AnimationConstraint"))

				rigjoint.Attachment1 = rootattachment
			else
				--- destroy if below fallenpartsdestroyheight
				local character = player.Character
				local pivot = character:GetPivot()
				if pivot.Y <= workspace.FallenPartsDestroyHeight or character.PrimaryPart == nil or not character.PrimaryPart:IsDescendantOf(workspace) then
					player.Character = nil
					character:Destroy()

					continue
				end
			end

			if islocal then
				--- early skip if islocal as local character is never pivoted
				continue
			else
				--- resolve pivot for replicated character
				local position = replication.readposition(resync)

				local distancefromfocus = vector.magnitude(position::any - replicationfocus::any)
				local breakpoint = interpolation.breakpointresolve(distancefromfocus)

				if interpolation.cycle % breakpoint.cycle == 0 then
					local cframe = CFrame.new(position)
					local character = player.Character

					if breakpoint.interpolate == true then
						local pivot = character:GetPivot()
						local distancefromtarget = vector.magnitude(position::any - pivot.Position::any)
						if distancefromtarget > 1000 then
							character:PivotTo(cframe)
						else
							character:PivotTo(pivot:Lerp(cframe, i))
						end
					else
						character:PivotTo(cframe)
					end
				end
			end
		else
			--- attempt to replicate non-player character
			--- out of scope for demo case
			continue
		end
	end
	
	if resetcycle then
		interpolation.cycle = 0
	end

	debug.profileend()
end

RunService.Heartbeat:Connect(replicate)

--- basic animation pattern
--- always applies strafing/rotations
--- but limb transforms are set every framerate

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
		local playerrig: typeof(rig.create())? = character:FindFirstChild("rig")
		if not playerrig then continue end

		--- resolve rotations
		local rx, ry
		if islocal then
			rx, ry = camera.CFrame:ToOrientation()
		else
			rx, ry = replication.readrotation(resync)
		end

		--- resolve rotations for strafing animation
		local ix, iy = replication.readinput(resync)
		local xsign
		if islocal then
			xsign = inputcontroller.vector.X
		else
			xsign = replication.bitstosigned(ix)
		end
		xsign = math.map(xsign, -1, 1, -math.pi/4, math.pi/4)

		local xvalue = character:GetAttribute("xvalue") or 0
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
			task.defer(
				rig.stepanimationconstraints,
				playerrig,
				replication.statetostring(replication.readstate(resync))::any,
				iy == 2 or iy == 3 or false,
				"none"::any,
				os.clock()
			)
		end
	end
end

RunService.Heartbeat:Connect(animate)

return true