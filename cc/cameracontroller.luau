--!strict

local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ContextActionService = game:GetService("ContextActionService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local UserInputService = game:GetService("UserInputService")

local viewport = require(script.Parent.viewport)

--- creates a spring
-- @native
function createspring(frequency: number, distance: number, mindistance: number, maxdistance: number)
	distance = math.clamp(distance, mindistance, maxdistance)
	return {
		frequency = frequency;
		
		velocity = 0;

		distance = distance;
		goal = distance;

		mindistance = mindistance;
		maxdistance = maxdistance;
	}
end

--- advances spring by `dt`
-- @native
function springstep(s: typeof(createspring(...)), dt: number)
	local freq = s.frequency * 2 * math.pi --- Convert from Hz to rad/s
	local distance = s.distance
	local velocity = s.velocity
	local mindistance = s.mindistance
	local maxdistance = s.maxdistance
	local goal = s.goal

	--- Solve the spring ODE for position x and velocity after time t, assuming critical damping:
	--- 2*f*x'[t] + x''[t] = f^2*(g - x[t])
	--- Knowns are x[0] and x'[0].
	--- Solve for x[t] and x'[t].

	local offset = goal - distance
	local step = freq*dt
	local decay = math.exp(-step)

	local x1 = goal + (velocity*dt - offset*(step + 1))*decay
	local v1 = ((offset*freq - velocity)*step + velocity)*decay

	--- Constrain
	if x1 < mindistance then
		x1 = mindistance
		v1 = 0
	elseif x1 > maxdistance then
		x1 = maxdistance
		v1 = 0
	end

	s.distance = x1
	s.velocity = v1

	return x1
end

local function cframetoaxis(cframe: CFrame)
	local axis, angle = cframe:ToAxisAngle()

	return axis * angle
end

local function axistocframe(axis: Vector3)
	local angle = vector.magnitude(axis::any)
	if angle > 1e-5 then
		return CFrame.fromAxisAngle(axis, angle)
	end

	return CFrame.identity
end

--- creates a transform extrapolator
function createtransformextrapolator()
	return {
		lastcframe = nil :: CFrame?;
	}
end

--- advances transform extrapolator `t` by `dt` wrt `cframe`, returning a table with translation/rotation velocities and an extrapolator function
function transformextrapolatorstep(t: typeof(createtransformextrapolator()), dt: number, cframe: CFrame)
	local lastcframe = t.lastcframe or cframe
	t.lastcframe = cframe

	local position = cframe.Position
	local rotation = cframe.Rotation

	local lastposition = lastcframe.Position
	local lastrotation = lastcframe.Rotation

	--- Estimate velocities from the delta between now and the last frame
	--- This estimation can be a little noisy.
	local translationvelocity = (position - lastposition)/dt
	local rotationvelocity = cframetoaxis(rotation*lastrotation:Inverse())/dt

	local function extrapolate(t: number)
		local thisposition = translationvelocity*t + position
		local thisrotation = axistocframe(rotationvelocity*t)*rotation

		return thisrotation + thisposition
	end

	return {
		extrapolate = extrapolate,
		translationvelocity = translationvelocity,
		rotationvelocity = rotationvelocity,
	}
end

--- resets transform extrapolator
function transformextrapolatorreset(t: typeof(createtransformextrapolator()))
	t.lastcframe = nil
end

--- ### cameracontroller.luau
---
--- camera controller
local cameracontroller = {
	--- camera object: \
	--- `CameraMode` and `CameraType` \
	--- are read-from internally \
	--- and written-to externally
	camera = workspace.CurrentCamera;

	--- internal cameramode \
	--- this overwrites `cameracontroller.camera.CameraMode`
	cameramode = Enum.CameraMode.Classic;
	--- internal lockfirstperson \
	--- this overwrites `cameracontroller.camera.CameraType` \
	--- \
	--- this should be either custom or scriptable \
	--- as all other cameratypes behaviors are best handled externally
	cameratype = Enum.CameraType.Custom;
	
	--- shiftlock value \
	--- original value: `Vector3.new(1.75, 0, 0)`
	cameraoffset = Vector3.new(0, 0, 0);

	--- shake values, written externally
	--- shake offset
	camerashakeoffset = Vector3.zero;
	--- shake rotation, components are in radians. is a vector for speed
	--- is converted to `CFrame.fromOrientation(...)` when cameracontroller is stepped
	camerashakerotation = Vector3.zero;

	--- camera distance extrapolator
	extrapolator = createtransformextrapolator();
	--- camera distance focus rotation
	focusrotation = CFrame.new(
		0, 0, 0,
		-1, 0, 0,
		0, 1, 0,
		0, 0, -1
	);

	--- initial camera angle
	initialcameraangle = CFrame.fromOrientation(math.rad(-15), 0, 0);
	--- reset camera angle on next step
	resetcameraangle = true;

	--- input priority
	inputpriority = Enum.ContextActionPriority.Medium.Value;
	--- render priority
	renderpriority = Enum.RenderPriority.Camera.Value - 1;

	--- arrow key camera pan speed in radians/sec \
	--- ROTATION_SPEED_KEYS
	arrowkeyspeed = math.rad(120);
	--- gamepad pan speed in radians/sec \
	--- ROTATION_SPEED_GAMEPAD
	gamepadspeed = Vector2.new(1, 0.77) * math.rad(7);

	--- mouse pan speed in radians/sec
	--- ROTATION_SPEED_MOUSE
	mousespeed = Vector2.new(1, 0.77)*math.rad(0.5);
	--- pointer pan speed in radians/sec
	--- ROTATION_SPEED_POINTERACTION
	pointerspeed = Vector2.new(1, 0.77)*math.rad(7);
	--- touch pan speed in radians/sec
	--- ROTATION_SPEED_TOUCH
	touchspeed = Vector2.new(1, 0.66)*math.rad(1);

	--- (scaled studs/wheel click)
	--- ZOOM_SPEED_MOUSE
	mousezoomspeed = 1;
	--- (studs/s)
	--- ZOOM_SPEED_KEYS
	keyzoomspeed = 0.1;
	--- (scaled studs/DIP %)
	--- ZOOM_SPEED_TOUCH
	touchzoomspeed = 0.04;

	--- "...Adjust the touch sensitivity so that sensitivity is reduced when swiping up \
	--- 25% sensitivity at 90°" \
	--- MIN_TOUCH_SENSITIVITY_FRACTION
	touhchsensitivityfraction = 0.25;

	--- gamepad pan deadzone
	gamepaddeadzone = 0.1;

	--- pan inputs as a single table \
	--- constructing a vector2 is expensive !! \
	--- `[1,  2]` gamepad x, y \
	--- `[3,  4]` keyboard arrow l, r \
	--- `[5,  6]` mouse delta x, y \
	--- `[7,  8]` pointer pan delta x, y \
	--- `[9, 10]` touch pan delta x, y
	paninputs = table.create(10, 0);
	--- `[1]` keyboard i
	--- `[2]` keyboard o
	--- `[3]` mouse wheel (pointeraction)
	--- `[4]` mouse pinch (pointeraction)
	--- `[5]` touch pinch
	zoominputs = table.create(5, 0);

	gamepadzoomkeycode = Enum.KeyCode.ButtonR3;
	gamepadzoomsteps = 3;
	currentgamepadzoomstep = 2;

	--- `Enum.UserInputType -> is pan-held` readwrite table
	paninputmap = {
		[Enum.UserInputType.MouseButton2] = false;
		[Enum.UserInputType.Touch] = false;
	};

	--- boolean describing whether a pan input is being held
	holdpan = false;

	--- internally-written time elapsed since last step
	laststep = 0;

	--- default distance away from subject
	defaultzoomdistance = game:GetService("StarterPlayer").CameraMaxZoomDistance; --- 12.5
	--- current zoom distance from subject
	currentzoomdistance = 0;

	--- zoom spring frequency
	zoomspringfrequency = 4.5;
	--- zoom spring acceleration
	zoomspringacceleration = 0.0375;

	--- internal camera spring
	zoomspring = createspring(0, 0, 0, 0);

	--- zoom sensitivity curve
	zoomsensitivitycurve = 0.5;
	--- min zoom when in first person
	firstpersondistanceminzoom = 0.5;
	--- if zoom < this value, snaps to first-person
	firstpersondistancesnap = 1;
	--- internally-set boolean describing whether camera is in first person
	infirstperson = false;

	--- "...Note: DotProduct check in CoordinateFrame::lookAt() prevents using values within about \
	--- 8.11 degrees of the +/- Y axis, that's why these limits are currently 80 degrees" \
	--- \
	--- camera min pitch
	cameraminpitch = math.rad(-80);
	--- camera max pitch
	cameramaxpitch = math.rad(80);

	--- camera min zoom distance \
	--- written to @ lowermost block
	cameraminzoomdistance = 0;
	--- camera max zoom distance \
	--- written to @ lowermost block
	cameramaxzoomdistance = 0;

	--- runservice bindtorenderstep(cameracontroller.renderstepfunctionname, ..., cameracontroller.step)
	renderstepfunctionname = "camerastep";
}

--- advances cameracontroller by `dt`
function cameracontroller.step(dt: number)
	debug.profilebegin("cc_cameracontrollerstep")
	
	local now = os.clock()
	local realtime = now - cameracontroller.laststep

	local camera = cameracontroller.camera

	--- early exit if scriptable
	if cameracontroller.cameratype == Enum.CameraType.Scriptable then
		cameracontroller.reset()
		return
	end

	local cameracframe = camera.CFrame
	local camerasubject = camera.CameraSubject

	--- resolve camera subject cframe
	local camerasubjectcframe = CFrame.identity
	if camerasubject and camerasubject:IsA("BasePart") then
		camerasubjectcframe = camerasubject:GetPivot()
	end

	--- resolve camera reset angle
	local cameralookvector = cameracframe.LookVector
	if cameracontroller.resetcameraangle then
		if camerasubject and camerasubject:IsA("BasePart") then
			cameralookvector = (camerasubject:GetPivot() * cameracontroller.initialcameraangle).LookVector
		else
			cameralookvector = cameracontroller.initialcameraangle.LookVector
		end

		cameracontroller.resetcameraangle = false
	end

	--- resolve zoom
	local zoominput = cameracontroller.getzoominput()
	cameracontroller.stepzoom(zoominput)

	--- resolve spring
	local zoomspring = cameracontroller.zoomspring
	zoomspring.goal = cameracontroller.currentzoomdistance

	--- instant snap
	--- if zoominput ~= 0 then
	--- 	if zoominput < 0 then
	--- 		cameracontroller.currentzoomdistance = cameracontroller.cameraminzoomdistance
	--- 		zoomspring.goal = cameracontroller.cameraminzoomdistance
	--- 	else
	--- 		cameracontroller.currentzoomdistance = cameracontroller.cameramaxzoomdistance
	--- 		zoomspring.goal = cameracontroller.cameramaxzoomdistance
	--- 	end
	--- end

	--- poppercam here to set maxvalue
	
	local zoomdistance = springstep(zoomspring, realtime)

	--- resolve rotations
	local rotateinput = cameracontroller.getrotationinput(realtime)
	local camerafocusposition = camerasubjectcframe.Position
	local newlookvector = cameracontroller.rotatelookvector(cameralookvector, rotateinput)

	--- resolve camera cframes
	local realcframe = CFrame.lookAlong(camerafocusposition - (zoomdistance * newlookvector), newlookvector)
	local realfocus = CFrame.lookAlong(camerafocusposition, newlookvector)
	
	--- apply camera offset (shiftlock) if not first person
	local cameraoffset = cameracontroller.cameraoffset
	if cameracontroller.currentzoomdistance <= cameracontroller.firstpersondistanceminzoom then
		cameraoffset = Vector3.zero
	end
	if cameraoffset ~= Vector3.zero then
		local relativeoffset = cameraoffset.X * realcframe.RightVector + cameraoffset.Y * realcframe.UpVector + cameraoffset.Z * realcframe.LookVector

		realcframe += relativeoffset
		realfocus += relativeoffset
	end

	--- resolve zoom limit
	local limitedcframe do
		local limitedzoom = cameracontroller.cameramaxzoomdistance

		local minpossiblezoom = cameracontroller.firstpersondistanceminzoom
		local maxpossiblezoom = math.max(cameracontroller.cameramaxzoomdistance, zoomdistance)

		if zoomspring.goal > 1 then
			local extrapolator = cameracontroller.extrapolator
			local rotatedfocus = CFrame.lookAlong(realfocus.Position, -realcframe.LookVector) * cameracontroller.focusrotation

			local extrapolationresult = transformextrapolatorstep(extrapolator, realtime, rotatedfocus)
			limitedzoom = viewport.cast(realfocus * CFrame.new(0, 0, minpossiblezoom), maxpossiblezoom - minpossiblezoom, extrapolationresult) + minpossiblezoom
			
			limitedcframe = rotatedfocus * CFrame.new(0, 0, limitedzoom)
		end

		zoomspring.mindistance = minpossiblezoom
		zoomspring.maxdistance = math.min(cameracontroller.cameramaxzoomdistance, limitedzoom)

		limitedcframe = realcframe
	end

	--- finalize camera cframe
	local shakerotation = cameracontroller.camerashakerotation
	local shakerotationcframe = CFrame.fromOrientation(shakerotation.X, shakerotation.Y, shakerotation.Z)
	
	realcframe = (limitedcframe + cameracontroller.camerashakeoffset) * shakerotationcframe

	--- apply camera cframes
	camera.CFrame = realcframe
	camera.Focus = realfocus

	--- reset delta-based inputs
	cameracontroller.resetinputs()

	cameracontroller.laststep = now

	debug.profileend()
end

function cameracontroller.gamepadzoomstep(delta: number)
	local maxsteps = cameracontroller.gamepadzoomsteps
	local currentstep = (cameracontroller.currentgamepadzoomstep + delta) % maxsteps
	if currentstep < 1 then
		currentstep = maxsteps
	end

	cameracontroller.currentgamepadzoomstep = currentstep
	cameracontroller.currentzoomdistance = math.map(currentstep, 1, maxsteps, cameracontroller.cameraminzoomdistance, cameracontroller.cameramaxzoomdistance)
	
	--- if cameracontroller.currentzoomdistance <= cameracontroller.cameraminzoomdistance then
	--- 	cameracontroller.currentzoomdistance = cameracontroller.cameramaxzoomdistance
	--- 	cameracontroller.zoomspring.goal = cameracontroller.cameramaxzoomdistance
	--- else
	--- 	cameracontroller.currentzoomdistance = cameracontroller.cameraminzoomdistance
	--- 	cameracontroller.zoomspring.goal = cameracontroller.cameraminzoomdistance
	--- end
end

--- advances internal currentzoomdistance by zoominput
function cameracontroller.stepzoom(zoominput: number)
	local zoom = cameracontroller.currentzoomdistance

	if math.abs(zoominput) > 0 then
		local newzoom

		if zoominput > 0 then
			newzoom = zoom + zoominput*(1 + zoom*cameracontroller.zoomsensitivitycurve)
			newzoom = math.max(newzoom, cameracontroller.firstpersondistancesnap)
		else
			newzoom = (zoom + zoominput)/(1 - zoominput*cameracontroller.zoomsensitivitycurve)
			newzoom = math.max(newzoom, cameracontroller.firstpersondistanceminzoom)
		end

		if newzoom < cameracontroller.firstpersondistancesnap then
			newzoom = cameracontroller.firstpersondistanceminzoom
		end

		--- cameracontroller.resolvecurrentzoomdistance(newzoom) \
		--- "...by default, camera modules will respect LockFirstPerson and override the currentzoomdistance with 0 \
		--- regardless of what Player.cameraminzoomdistance is set to, so that first person can be made \
		--- available by the developer without needing to allow players to mousewheel dolly into first person. \
		--- Some modules will override this function to remove or change first-person capability."
		if cameracontroller.cameramode == Enum.CameraMode.LockFirstPerson then
			cameracontroller.currentzoomdistance = cameracontroller.firstpersondistanceminzoom
			if not cameracontroller.infirstperson then
				cameracontroller.infirstperson = true
			end
		else
			local clampedsubjectdistance = math.clamp(newzoom, cameracontroller.cameraminzoomdistance, cameracontroller.cameramaxzoomdistance)
			if clampedsubjectdistance < cameracontroller.firstpersondistancesnap then
				cameracontroller.currentzoomdistance = cameracontroller.firstpersondistanceminzoom
				if not cameracontroller.infirstperson then
					cameracontroller.infirstperson = true
				end
			else
				cameracontroller.currentzoomdistance = clampedsubjectdistance
				if cameracontroller.infirstperson then
					cameracontroller.infirstperson = false
				end
			end
		end
	end

	return cameracontroller.currentzoomdistance
end

--- returns lookvector rotated by input rotation
function cameracontroller.rotatelookvector(lookvector: Vector3, rotation: Vector2)
	local pitchangle = math.asin(lookvector.Y)
	local ry = math.clamp(rotation.Y, -cameracontroller.cameramaxpitch + pitchangle, -cameracontroller.cameraminpitch + pitchangle)
	local constrainedrotateinput = Vector2.new(rotation.X, ry)
	local cframe = CFrame.Angles(0, -constrainedrotateinput.X, 0) * CFrame.lookAlong(Vector3.zero, lookvector) * CFrame.Angles(-constrainedrotateinput.Y, 0, 0)

	return cframe.LookVector
end

--- resets all camera inputs
function cameracontroller.reset()
	table.move(table.create(#cameracontroller.paninputs, 0), 1, #cameracontroller.paninputs, 1, cameracontroller.paninputs)
	local zlen = #cameracontroller.zoominputs - 2
	table.move(table.create(zlen, 0), 1, zlen, 3, cameracontroller.zoominputs)
end

--- resets delta-based inputs \
--- interally-called at the end of cameracontroller step
function cameracontroller.resetinputs()
	--- preserve non-delta inputs, stored in first 4 (gamepad pan, keyboard pan)
	local plen = #cameracontroller.paninputs - 4
	table.move(table.create(plen, 0), 1, plen, 5, cameracontroller.paninputs)
	local zlen = #cameracontroller.zoominputs - 2
	table.move(table.create(zlen, 0), 1, zlen, 3, cameracontroller.zoominputs)
end

--- "...adjusts the touch sensitivity delta so that sensitivity is reduced when swiping up \
--- or down, but stays the same when swiping towards the middle of the screen"
function cameracontroller.resolvetouchpitchsensitivity(delta: Vector2): Vector2
	local camera = cameracontroller.camera

	if not camera then
		return delta
	end
	
	--- get the camera pitch in world space
	local pitch = camera.CFrame:ToEulerAnglesYXZ()
	
	if delta.Y*pitch >= 0 then
		--- do not reduce sensitivity when pitching towards the horizon
		return delta
	end
	
	--- set up a line to fit: \
	--- 1 = f(0) \
	--- 0 = f(±pi/2)
	local curveY = 1 - (2*math.abs(pitch)/math.pi)^0.75

	--- remap curveY from [0, 1] -> [MIN_TOUCH_SENSITIVITY_FRACTION, 1]
	local sensitivity = math.map(curveY, 0, 1, cameracontroller.touhchsensitivityfraction, 1)

	return Vector2.new(1, sensitivity)*delta
end

function cameracontroller.mapsignedvaluetodeadzone(value: number, deadzone: number)
	local abs = math.abs(value)
	if abs > deadzone then
		return math.map(abs, deadzone, 1, 0, 1) * math.sign(value)
	else
		return 0
	end
end

--- returns rotation input as a sum of all device inputs
function cameracontroller.getrotationinput(dt: number, disablekeyboardrotation: boolean?)
	--- `[1,  2]` gamepad x, y \
	--- `[3,  4]` keyboard arrow l, r \
	--- `[5,  6]` mouse delta x, y \
	--- `[7,  8]` pointer pan delta x, y \
	--- `[9, 10]` touch pan delta x, y
	local paninputs = cameracontroller.paninputs

	local gamepaddeadzone = cameracontroller.gamepaddeadzone
	local gamepadx = cameracontroller.mapsignedvaluetodeadzone(paninputs[1], gamepaddeadzone)
	local gamepady = cameracontroller.mapsignedvaluetodeadzone(paninputs[2], gamepaddeadzone)

	local gamepadrotationvector = cameracontroller.gamepadspeed * Vector2.new(gamepadx, gamepady) * UserGameSettings.GamepadCameraSensitivity
	local keyboardrotationvector = cameracontroller.arrowkeyspeed * Vector2.new(paninputs[3] + paninputs[4], 0) * dt
	local mousemovevector = cameracontroller.mousespeed * Vector2.new(paninputs[5], paninputs[6])
	local pointerpanvector = cameracontroller.pointerspeed * Vector2.new(paninputs[7], paninputs[8])
	local touchpanvector = cameracontroller.touchspeed * cameracontroller.resolvetouchpitchsensitivity(Vector2.new(paninputs[9], paninputs[10]))

	local camerayinvertvector = Vector2.new(1, UserGameSettings:GetCameraYInvertValue())

	if disablekeyboardrotation then
		keyboardrotationvector *= Vector2.zero
	end

	return (
		keyboardrotationvector
		+ gamepadrotationvector
		+ mousemovevector
		+ pointerpanvector
		+ touchpanvector
	) * camerayinvertvector
end

--- returns zoom input as a sum of all device inputs
function cameracontroller.getzoominput()
	local zoom = cameracontroller.zoominputs
	local keyboardzoom = cameracontroller.keyzoomspeed * (zoom[1] + zoom[2])
	local mousezoom = cameracontroller.mousezoomspeed * (-zoom[3] + zoom[4])
	local touchzoom = cameracontroller.touchzoomspeed * (-zoom[5])

	return keyboardzoom + mousezoom + touchzoom
end

function cameracontroller.touchguithumbstickframe(): Frame?
	local playergui = LocalPlayer:FindFirstChildOfClass("PlayerGui")::PlayerGui?
	local touchgui = playergui and playergui:FindFirstChild("cc_touchgui")::ScreenGui?
	local thumbstickframe = touchgui and touchgui:FindFirstChild("ThumbstickFrame")::Frame?

	return thumbstickframe
end

function cameracontroller.ispointinbounds(point: Vector2, topleft: Vector2, bottomright: Vector2)
	local cx, cy = point.X, point.Y

	return 
		cx >= topleft.X and
		cy >= topleft.Y and
		cx <= bottomright.X and
		cy <= bottomright.Y
end

function cameracontroller.filterpoints(array: {Vector2}, topleft, bottomright)
	for i = #array, 1, -1 do
		local vec = array[i]
		if cameracontroller.ispointinbounds(vec, topleft, bottomright) then
			table.remove(array, i)
		end
	end
end

if RunService:IsClient() then
	--- internal functions

	--- `[1,  2]` gamepad x, y \
	--- `[3,  4]` keyboard arrow l, r \
	--- `[5,  6]` mouse delta x, y \
	--- `[7,  8]` pointer pan delta x, y \
	--- `[9, 10]` touch pan delta x, y
	local paninputs = cameracontroller.paninputs

	--- interally-called by contextaction "cc_camerathumbstick"
	local function thumbstick(action: string, state: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
		if inputobject.KeyCode == Enum.KeyCode.Thumbstick2 then
			local position = inputobject.Position
			
			paninputs[1] = position.X
			paninputs[2] = -position.Y
		end

		return Enum.ContextActionResult.Pass
	end

	--- interally-called by userinputservice.inputbegan
	local function mousemovement(inputobject: InputObject)
		local delta = inputobject.Delta
		paninputs[5] = delta.X
		paninputs[6] = delta.Y
	end

	--- interally-called by contextaction "cc_camerakeypress"
	local function keypress(action: string, state: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
		local keycode = inputobject.KeyCode
		local value = state == Enum.UserInputState.Begin and 1 or 0
		if keycode == Enum.KeyCode.I then
			cameracontroller.zoominputs[1] = -value
		elseif keycode == Enum.KeyCode.O then
			cameracontroller.zoominputs[2] = value
		elseif keycode == Enum.KeyCode.Left then
			paninputs[3] = -value
		elseif keycode == Enum.KeyCode.Right then
			paninputs[4] = value
		end

		return
	end

	--- interally-called by userinputservice.pointeraction
	local function pointeraction(wheel: number, pan: Vector2, pinch: number, sunkinput: boolean)
		if sunkinput then return end

		cameracontroller.zoominputs[3] = wheel
		cameracontroller.zoominputs[4] = -pinch
		paninputs[7] = pan.X
		paninputs[8] = pan.Y
	end

	local lasttranslation = Vector2.zero

	local function resettouchpan()
		lasttranslation = Vector2.zero
		paninputs[9] = 0
		paninputs[10] = 0
	end

	--- interally-called by userinputservice.touchpan
	local ispanvalid = false
	local function touchpan(touchpositions: {Vector2}, totaltranslation: Vector2, velocity: Vector2, state: Enum.UserInputState, sunkinput: boolean)
		if state ~= Enum.UserInputState.Change then
			if state == Enum.UserInputState.Begin then
				--- pan is only valid if initial touch was not within bounds of the touchgui thumbstick
				local thumbstickframe = cameracontroller.touchguithumbstickframe()
				if thumbstickframe then
					local apos, asize = thumbstickframe.AbsolutePosition, thumbstickframe.AbsoluteSize
					cameracontroller.filterpoints(touchpositions, apos, apos + asize)
				end

				ispanvalid = #touchpositions > 0
			else
				ispanvalid = false
			end

			resettouchpan()

			return
		end

		if #touchpositions == 1 and ispanvalid then
			local delta = totaltranslation - lasttranslation
			lasttranslation = totaltranslation
			paninputs[9] += delta.X
			paninputs[10] += delta.Y

			cameracontroller.paninputmap[Enum.UserInputType.Touch] = true
		else
			resettouchpan()
			cameracontroller.paninputmap[Enum.UserInputType.Touch] = false
		end
	end

	--- interally-called by userinputservice.touchpinch
	local function touchpinch(touchpositions: {Vector2}, scale: number, velocity: number, state: Enum.UserInputState, sunkinput: boolean)
		if state ~= Enum.UserInputState.Change then return end

		local thumbstickframe = cameracontroller.touchguithumbstickframe()
		if thumbstickframe then
			local apos, asize = thumbstickframe.AbsolutePosition, thumbstickframe.AbsoluteSize
			cameracontroller.filterpoints(touchpositions, apos, apos + asize)
		end

		if #touchpositions == 2 then
			cameracontroller.zoominputs[5] = scale
		end
	end

	--- interally-called by userinputservice.inputbegan
	local function inputbegan(inputobject: InputObject, sunkinput: boolean)
		if inputobject.UserInputType == Enum.UserInputType.MouseButton2 and not sunkinput then
			cameracontroller.paninputmap[Enum.UserInputType.MouseButton2] = true
			cameracontroller.holdpan = true
		end
		if inputobject.KeyCode == cameracontroller.gamepadzoomkeycode and not sunkinput then
			cameracontroller.gamepadzoomstep(1)
		end
	end

	--- interally-called by userinputservice.inputchanged
	local function inputchanged(inputobject: InputObject, sunkinput: boolean)
		if inputobject.UserInputType == Enum.UserInputType.MouseMovement then
			mousemovement(inputobject)
		end
	end

	--- interally-called by userinputservice.inputended
	local function inputended(inputobject: InputObject, sunkinput: boolean)
		if inputobject.UserInputType == Enum.UserInputType.MouseButton2 then
			cameracontroller.paninputmap[Enum.UserInputType.MouseButton2] = false
			cameracontroller.holdpan = false
		elseif inputobject.UserInputType == Enum.UserInputType.Touch then
			resettouchpan()
		end
	end

	do
		--- write player zoom to camera zoom
		cameracontroller.cameraminzoomdistance = LocalPlayer.CameraMinZoomDistance
		cameracontroller.cameramaxzoomdistance = LocalPlayer.CameraMaxZoomDistance

		--- write defaults to distance
		local mindistance = cameracontroller.cameraminzoomdistance
		local maxdistance = cameracontroller.cameramaxzoomdistance
		local defaultzoomdistance = math.clamp(cameracontroller.defaultzoomdistance, mindistance, maxdistance)
		cameracontroller.currentzoomdistance = defaultzoomdistance

		--- rotate camera
		cameracontroller.camera.CFrame = CFrame.Angles(math.rad(15), 0, 0)

		--- write defaults to spring
		local s = cameracontroller.zoomspring
		s.distance = defaultzoomdistance
		s.frequency = cameracontroller.zoomspringfrequency
		s.goal = defaultzoomdistance
		s.mindistance = mindistance
		s.maxdistance = maxdistance
	end

	--- thumbstick
	ContextActionService:BindActionAtPriority(
		"cc_camerathumbstick",
		thumbstick,
		false,
		cameracontroller.inputpriority,
		Enum.KeyCode.Thumbstick2
	)
	--- keyboard
	ContextActionService:BindActionAtPriority(
		"cc_camerakeypress",
		keypress,
		false,
		cameracontroller.inputpriority,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.I,
		Enum.KeyCode.O
	)
	--- pointer
	UserInputService.PointerAction:Connect(pointeraction)
	--- touch pan, pinch
	UserInputService.TouchPan:Connect(touchpan)
	UserInputService.TouchPinch:Connect(touchpinch)
	--- mouse/inputbeganchangedended
	UserInputService.InputBegan:Connect(inputbegan)
	UserInputService.InputChanged:Connect(inputchanged)
	UserInputService.InputEnded:Connect(inputended)

	--- camera step
	RunService:BindToRenderStep(cameracontroller.renderstepfunctionname, cameracontroller.renderpriority, cameracontroller.step)

	--- updates zoom distance and spring wrt min/maxzoomdistance
	local function zoomdistancemodified()
		local mindistance = cameracontroller.cameraminzoomdistance
		local maxdistance = cameracontroller.cameramaxzoomdistance
		local currentzoomdistance = math.clamp(cameracontroller.currentzoomdistance, mindistance, maxdistance)
		
		cameracontroller.currentzoomdistance = currentzoomdistance

		local s = cameracontroller.zoomspring
		s.distance = currentzoomdistance
		s.mindistance = mindistance
		s.maxdistance = maxdistance

		springstep(s, 1/60)
	end

	--- min/max zoom distance change
	LocalPlayer:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function()
		cameracontroller.cameraminzoomdistance = LocalPlayer.CameraMinZoomDistance
		zoomdistancemodified()
	end)
	LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
		cameracontroller.cameramaxzoomdistance = LocalPlayer.CameraMaxZoomDistance
		zoomdistancemodified()
	end)
end

return cameracontroller