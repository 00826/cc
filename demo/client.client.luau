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
	else
		--- third-person
		mousebehavior = Enum.MouseBehavior.LockCenter
		cameracontroller.cameraoffset = Vector3.new(0, 0, 0)
		--- cameracontroller.cameraoffset = Vector3.new(1.75 * shiftlockvectorsign, 0.25, 0)
		ccinput.rotationtype = Enum.RotationType.MovementRelative
		UserInputService.MouseIcon = "rbxasset://textures/cursors/CrossMouseIcon.png"
	end

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

	cc.step(character, dt)

	debug.profileend()
end

RunService.Heartbeat:Connect(step)

--- cc replication cycle

local frame = 0
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
	frame += 1

	local iszeroframe = frame % interpolation.maxcycle == 0
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
			local character = player.Character::typeof(rig.create())
			if not character then
				--- create empty character
				character = cc.create()
				assert(character)
				character.Name = player.Name
				character.Parent = cc.container
				player.Character = character

				local sphere = character.Sphere
				local rootpart = character.RootPart

				--- localcharacter case
				if islocal then
					rootpart.Anchored = false
					camera.CameraSubject = character:WaitForChild("Head")
					camera.CameraType = Enum.CameraType.Custom

					cameracontroller.resetcameraangle = true

					local s, e = pcall(function()
						character:MoveTo(spawnpoint())
					end)
					if not s then warn(e) end
				else
					rootpart.Anchored = true
				end

				sphere.Transparency = 1
				rootpart.Transparency = 1
			else
				local pivot = character:GetPivot()
				if pivot.Y <= workspace.FallenPartsDestroyHeight or character.PrimaryPart == nil or not character.PrimaryPart:IsDescendantOf(workspace) then
					player.Character = nil
					character:Destroy()

					continue
				end
			end

			if islocal then --- if not islocal but keeping this notation for readability
				continue
			else
				local position = replication.readposition(resync)

				local distancefromfocus = vector.magnitude(position::any - replicationfocus::any)
				local breakpoint = interpolation.breakpointresolve(distancefromfocus)

				if frame % breakpoint.cycle == 0 then

					local rotation = replication.readrotation(resync)
					local cframe = CFrame.new(position) * rotation

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
			--- out of scope for this test case
			continue
		end
	end
	
	if iszeroframe then
		frame = 0
	end

	debug.profileend()
end

RunService.Heartbeat:Connect(replicate)

return true