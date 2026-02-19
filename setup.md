# setup

## structure

implementing cc is fairly straightforward (see [default.project.json](default.project.json)). although a demo ([demo](demo)) is provided, client and server scripts are not provided ootb to give more control over how cc is require-d

a minimal file structure using cc would look like this:

```
DataModel
  ├ ReplicatedFirst
  │   └ ccclient.client.luau --- cc interfacing
  ├ ReplicatedStorage
  │   └ cc.luau --- cc module
  ├ ServerScriptService
  │   └ ccserver.server.luau --- requires cc.replication for replication process
  └ StarterPlayer
      └ StarterPlayerScripts
	      ├ PlayerModule.luau --- empty fork
          └ PlayerScriptsLoader.client.luau --- empty fork
```

## server

### 1. replication

[cc/replication.luau](cc/replication.luau) handles the replication process and is the only thing that needs to be required on the server.

```lua
--- ccserver.server.luau

require(game:GetService("ReplicatedStorage").cc.replication)
```

## client

blocks of code in each step are pulled directly from the demo ([demo](demo)) with more commentary to better-explain how cc works

### 0. navigation

[0. navigation](#0-navigation)<br/>
[1. interfacing](#1-interfacing)<br/>
[2. reading inputs](#2-reading-inputs)<br/>
[3. rebinding inputs](#3-rebinding-inputs)<br/>
[4. cc.step()](#4-ccstep)<br/>
[5. player-character instantiation](#5-player-character-instantiation)<br/>
[6. client replication cycle](#6-client-replication-cycle)<br/>
[7. interpolation & instantiation loops](#7-interpolation--instantiation-loops)<br/>

### 1. interfacing

<i>[▲ back to top](#0-navigation)</i>

cc is primarily interfaced with the `input` table, which is read from during `cc.step()`.

it should be noted however, that cc and its submodules have as-much-exposed-to-the-dev-as-possible. `input` is simply a container for fast-and-easy surface-level behavior changes

```lua
local cc = require(game:GetService("ReplicatedStorage").cc)

local cameracontroller = cc.cameracontroller
local inputcontroller = cc.inputcontroller

local ccinput = cc.input
local ccoutput = cc.output

local camera = workspace.CurrentCamera
```

writing values to cc is very straightforward:

```lua
ccinput.speed = 24 --- base movement speed
ccinput.jumppower = 50 --- jump power
ccinput.floatpower = 500 --- float power (upward y-velocity when holding jump input)

ccinput.floorcastextend = 1/8 --- extend floorcast by 1/8 studs
ccinput.radiusextend = -1/8 --- shrink floorcast radius by -1/8 studs 
```

### 2. reading inputs

<i>[▲ back to top](#0-navigation)</i>

reading jump and crouch inputs as simple as setting `ccinput.inputup/inputdown` to 1 or 0.<br/> movement inputs (wasd, gamepad thumbstick, virtual thumbstick) are handled internally by `cc.inputcontroller`.

```lua
local UserInputService = game:GetService("UserInputService")

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
	--- allow input release even if input was eaten by a contextactionservice-bound function
	--- if sunk then return end
	local keycode = inputobject.KeyCode

	if table.find(jumpkeys, keycode) then
		ccinput.inputup = 0
	elseif table.find(crouchkeys, keycode) then
		ccinput.inputdown = 0
	end
end
UserInputService.InputEnded:Connect(inputended)
```

### 3. rebinding inputs

<i>[▲ back to top](#0-navigation)</i>

`inputcontroller.preferredinput` is an internally-resolved `UserInputService.PreferredInput` that changes based on recency. because this behavior is different than the forced value of the ootb `UserInputService.PreferredInput`, rebinding is intended to be handled externally by the developer

```lua
local function preferredinputchanged()
	local pi = inputcontroller.preferredinput

	--- rebind inputcontroller's input-device-specific
	--- `ContextActionService:BindActionAtPriority()` functions wrt preferredinput
	inputcontroller.rebind(pi)
end

preferredinputchanged()
inputcontroller.preferredinputchanged():Connect(preferredinputchanged)
```

### 4. cc.step()

<i>[▲ back to top](#0-navigation)</i>

`cc.step()` reads from `cc.input` to update the bodymovers of the passed character. in this example it's wrapped in function `step()` to show how developer-prescribed behaviors can be applied prior to the actual `cc.step()` call; following this call, values from `cc.output` are written into the local replication buffer to eventually be sent to other networked peers.

```lua
--- more complex/bigger-picture cases are provided in the demo ccclient.luau script

local RunService = game:GetService("RunService")

local function step(dt: number)
	--- set inputvector from inputcontroller
	--- set cameracframe from currentcamera
	--- both are set externally for cases such as overriding the input vector
	--- or setting the camera to a preset/external cframe for something like a spectate mode
	ccinput.inputvector = inputcontroller.vector
	ccinput.cameracframe = camera.CFrame

	--- early return if character doesn't exist
	local character = localplayer.Character
	if not character then return end

	--- if crouched, scale speed by 0.5
	--- otherwise, scale speed by 1
	if ccinput.inputdown == 1 then
		ccinput.speedmodifier = 0.5
	else
		ccinput.speedmodifier = 1
	end

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
	--- write locomotion state
	replication.writestate(r, ccoutput.state)
end

RunService.Heartbeat:Connect(step)
```

### 5. player-character instantiation

<i>[▲ back to top](#0-navigation)</i>

because characters are instantiated on the client, (all the server does is emit buffers) player-characters aren't destroyed when a player leaves. this is because, from the perspective of the server, characters don't exist.

this process is intentionally not handled interally by cc to give more control over how player-characters are contained

---

```lua
local Players = game:GetService("Players")
local localplayer = Players.LocalPlayer

--- for applying a rig when a cc character is instantiated
local rig = cc.rig
local r8limbs = require(script.Parent.r8limbs)
```

function to uncache-and/or-destroy a cc character associated with the passed player

```lua
--- removes player-character associated with this player with option to destroy the instance
local function removeplayercharacter(player: Player)
	local stringuserid = tostring(player.UserId)

	player.Character = nil
	interpolation.targetdestroy(stringuserid)
end

--- connect removeplayercharacter to playerremoving signal
Players.PlayerRemoving:Connect(removeplayercharacter)
```

function to create a cc character for the passed player

although very closely related, decoupling `characters` and a `rigs` is important in the context of cc.

a cc `character` are simply a pill hitbox and bodymovers, while a `rig` is a developer-prescribed assembly/body is appended onto an instantiated character. 

as an aside, [cc/rig.luau](cc/rig.luau) (and by extension [demo/r8limbs.luau](demo/r8limbs.luau))'s raison d'être  is that it's objectively a waste of time and effort to complain against the avatar changes being pushed on the platform. it's much more proactive to fully switch lanes and produce something that isn't subject to undesired changes. as such, these modules are provided ootb, but are in no way required to use cc.

```lua

--- creates a player-character for this player
local function createplayercharacter(player: Player)
	local userid = player.UserId
	local stringuserid = tostring(userid)
	local islocal = player == localplayer
	
	local character = cc.create(islocal)
	assert(character)
	character.Name = player.Name
	character.Parent = cc.container
	player.Character = character

	--- cache and connect function to uncache when destroyed
	local preexisting = interpolation.targets[stringuserid]
	if preexisting then
		interpolation.targetdestroy(preexisting)
	end
	interpolation.targets[stringuserid] = interpolation.createtarget(character)

	character.Destroying:Once(function()
		removeplayercharacter(player)
	end)

	local characterrootpart = character:FindFirstChild("RootPart")
	assert(characterrootpart and characterrootpart:IsA("BasePart"))

	--- localcharacter case
	--- set camerasubject
	--- move to spawnlocation
	characterrootpart.Anchored = false

	if islocal then
		local head = character:WaitForChild("Head")
		camera.CameraSubject = head:IsA("BasePart") and head or nil
		camera.CameraType = Enum.CameraType.Custom

		cameracontroller.resetcameraangle = true

		character:MoveTo(spawnpoint())
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
```

### 6. replicated character interpolation

<i>[▲ back to top](#0-navigation)</i>

starts with setting up interpolation breakpoints. these exist to cull `PVInstance:GetPivot() & PVInstance:PivotTo()` calls for replicated characters that are far from the local player-character.

```lua
local interpolation = cc.interpolation

--- set interpolation breakpoints
interpolation.breakpointset({
	--- if interpolation target is within 400 studs, lerp pivot every frame
	interpolation.createbreakpoint(400, true, 1);
	--- if interpolation target is within 800 studs, pivot every 2 frames
	interpolation.createbreakpoint(800, false, 2);
	--- if interpolation target is within 1200 studs, pivot every 4 frames
	interpolation.createbreakpoint(1200, false, 4);
})
```

force-guarantee local replication for local player and create a cache for all player-characters. force-guaranteeing local replication is recommended so that on the first interpolation frame, the local player-character is guaranteed to be instantiated

```lua
local resynccache = replication.resynccache

do --- force guarantee local replication
	local resync = replication.createresyncbuffer()
	replication.resyncwriteuserid(resync, localplayer.UserId)

	table.insert(resynccache, resync)
end
```

### 7. interpolation & instantiation loops

<i>[▲ back to top](#0-navigation)</i>

in this example, the interpolation and instantiation loops are split into two separate functions for simplicity.

it should be worth noting however, that because they both iterate through `replication.resynccache`, the cost of these processes can be reduced from `2n` to `n` by instantiating-and-interpolating in the same loop (see [demo/client.client.luau](demo/client.client.luau))

instantiation function `instantiate()`:

```lua
--- iterates through resynced buffers and
--- handles instantiation and destruction cases for replicated player-characters

local function instantiate()
	for _, resync in resynccache do
		local userid = replication.resyncreaduserid(resync)
		local player = Players:GetPlayerByUserId(userid)
		if player then
			local islocal = player == localplayer
			if not interpolation.targets[stringuserid] then
				--- create character if dne
				createplayercharacter(player)
			else
				--- destroy if below fallenpartsdestroyheight then skip
				local character = player.Character
				if character then
					local pivot = character:GetPivot()
					local primarypart = character.PrimaryPart
					if pivot.Y <= workspace.FallenPartsDestroyHeight or primarypart == nil or not primarypart:IsDescendantOf(workspace) then
						removeplayercharacter(player)

						continue
					end
				end
			end
		else
			--- attempt to replicate non-player character `id == 0` \
			--- or player associated with this resync buffer does not exist `Players:GetPlayerByUserId(id) == nil`
		end
	end
end

RunService.Heartbeat:Connect(instantiate)
```

interpolation function `interpolate()`:

```lua
--- iterates through resynced buffers and
--- handles interpolation for replicated player-characters

local function interpolate(dt: number)
	--- resolve framerate-independent interpolant for this replication frame
	local t = interpolation.interpolant(dt)
	--- step interpolation frame
	local frame = interpolation.step()

	--- set focus to camera position
	local focus = camera.CFrame.Position

	for _, resync in resynccache do
		local userid = replication.resyncreaduserid(resync)
		local player = Players:GetPlayerByUserId(userid)
		if player then
			local islocal = player == localplayer

			if islocal then
				--- do nothing, local character is never pivoted
			else
				--- read replicated character position
				local position = replication.readposition(resync)

				--- resolve breakpoint
				local distancefromfocus = vector.magnitude(position::any - focus::any)
				local breakpoint = interpolation.breakpointresolve(distancefromfocus)

				--- set transform of pivot motor wrt breakpoint
				if frame % breakpoint.frame == 0 then
					local target = interpolation.targets[stringuserid]
					local motor = target.motor

					local cframe = CFrame.new(position)

					if breakpoint.interpolate == true then
						motor.Transform = motor.Transform:Lerp(cframe, t)
					else
						motor.Transform = cframe
					end
				end
			end
		else
			--- attempt to replicate non-player character `id == 0` \
			--- or player associated with this resync buffer does not exist `Players:GetPlayerByUserId(id) == nil`
		end
	end
end

RunService.Heartbeat:Connect(interpolate)
```

---

<i>[▲ back to top](#0-navigation)</i>