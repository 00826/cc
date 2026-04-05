--!strict

local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local localplayer = Players.LocalPlayer

local inputcontroller = require(script.Parent:WaitForChild("inputcontroller"))
local viewport = require(script.Parent:WaitForChild("viewport"))

--- creates a spring
@native
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
@native
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
--- function transformextrapolatorreset(t: typeof(createtransformextrapolator()))
--- 	t.lastcframe = nil
--- end

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

	--- render priority
	renderpriority = Enum.RenderPriority.Camera.Value;

	--- gamepad zoom setting
	gamepadzoomsteps = 3;
	currentgamepadzoomstep = 2;

	--- internally-written time elapsed since last step
	laststep = 0;

	--- default distance away from subject
	defaultzoomdistance = game:GetService("StarterPlayer").CameraMaxZoomDistance; --- 12.5
	--- current zoom distance from subject
	currentzoomdistance = 0;

	--- `snap`: zoom input instantly snaps between first and third-person perspective
	--- `step`: zoom input steps between first and third-person perspective
	zoombehavior = "step" :: "snap" | "step";

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
		inputcontroller.blobreset()
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
	--- pop queued gamepad zoom input (default rstick)
	local pop = inputcontroller.blobpopgamepadzoom()
	if pop ~= 0 then
		cameracontroller.gamepadzoomstep(pop)
	end

	local zoominput = inputcontroller.blobreadzoominput(dt)
	cameracontroller.stepzoom(zoominput)

	--- resolve spring
	local zoomspring = cameracontroller.zoomspring

	if cameracontroller.zoombehavior == "step" then
		zoomspring.goal = cameracontroller.currentzoomdistance
	elseif cameracontroller.zoombehavior == "snap" then
		if zoominput ~= 0 then
			if zoominput < 0 then
				cameracontroller.currentzoomdistance = cameracontroller.cameraminzoomdistance
				zoomspring.goal = cameracontroller.cameraminzoomdistance
			else
				cameracontroller.currentzoomdistance = cameracontroller.cameramaxzoomdistance
				zoomspring.goal = cameracontroller.cameramaxzoomdistance
			end
		end
	else
		warn(string.format("unknown zoombehavior '%s'", cameracontroller.zoombehavior))
	end

	--- poppercam here to set maxvalue
	
	local zoomdistance = springstep(zoomspring, realtime)

	--- resolve rotations
	local rotateinput = inputcontroller.blobreadrotationvector(realtime)
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
	inputcontroller.blobresetdeltas()

	cameracontroller.laststep = now

	debug.profileend()
end

--- advances gamepad zoom step by delta
function cameracontroller.gamepadzoomstep(delta: number)
	local maxsteps = cameracontroller.gamepadzoomsteps
	local currentstep = (cameracontroller.currentgamepadzoomstep + delta) % maxsteps
	if currentstep < 1 then
		currentstep = maxsteps
	end

	if cameracontroller.zoombehavior == "step" then
		cameracontroller.currentgamepadzoomstep = currentstep
		cameracontroller.currentzoomdistance = math.map(currentstep, 1, maxsteps, cameracontroller.cameraminzoomdistance, cameracontroller.cameramaxzoomdistance)
	elseif cameracontroller.zoombehavior == "snap" then
		if cameracontroller.currentzoomdistance <= cameracontroller.cameraminzoomdistance then
			cameracontroller.currentzoomdistance = cameracontroller.cameramaxzoomdistance
			cameracontroller.zoomspring.goal = cameracontroller.cameramaxzoomdistance
		else
			cameracontroller.currentzoomdistance = cameracontroller.cameraminzoomdistance
			cameracontroller.zoomspring.goal = cameracontroller.cameraminzoomdistance
		end
	else
		warn(string.format("unknown zoombehavior '%s'", cameracontroller.zoombehavior))
	end
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
function cameracontroller.rotatelookvector(lookvector: Vector3, rotation: Vector3)
	local pitchangle = math.asin(lookvector.Y)
	local ry = math.clamp(rotation.Y, -cameracontroller.cameramaxpitch + pitchangle, -cameracontroller.cameraminpitch + pitchangle)
	local constrainedrotateinput = Vector3.new(rotation.X, ry, 0)
	local cframe = CFrame.Angles(0, -constrainedrotateinput.X, 0) * CFrame.lookAlong(Vector3.zero, lookvector) * CFrame.Angles(-constrainedrotateinput.Y, 0, 0)

	return cframe.LookVector
end

if RunService:IsClient() then
	do
		--- write player zoom to camera zoom
		cameracontroller.cameraminzoomdistance = localplayer.CameraMinZoomDistance
		cameracontroller.cameramaxzoomdistance = localplayer.CameraMaxZoomDistance

		--- write defaults to distance
		local mindistance = cameracontroller.cameraminzoomdistance
		local maxdistance = cameracontroller.cameramaxzoomdistance
		local defaultzoomdistance = math.clamp(cameracontroller.defaultzoomdistance, mindistance, maxdistance)
		cameracontroller.currentzoomdistance = defaultzoomdistance

		--- rotate camera
		--- cameracontroller.camera.CFrame = CFrame.Angles(math.rad(15), 0, 0)

		--- write defaults to spring
		local s = cameracontroller.zoomspring
		s.distance = defaultzoomdistance
		s.frequency = cameracontroller.zoomspringfrequency
		s.goal = defaultzoomdistance
		s.mindistance = mindistance
		s.maxdistance = maxdistance
	end

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
	localplayer:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function()
		cameracontroller.cameraminzoomdistance = localplayer.CameraMinZoomDistance
		zoomdistancemodified()
	end)
	localplayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
		cameracontroller.cameramaxzoomdistance = localplayer.CameraMaxZoomDistance
		zoomdistancemodified()
	end)
end

return cameracontroller