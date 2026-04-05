--!strict

local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local localplayer = Players.LocalPlayer

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local UserInputService = game:GetService("UserInputService")

--- converts xy vector to udim2
@native
local function vectorxytoudim2(vec: Vector2|Vector3)
	return UDim2.fromOffset(vec.X, vec.Y)
end

--- converts xy vector to vector3
@native
local function vectorxytovector3(vec: Vector2|Vector3)
	return Vector3.new(vec.X, vec.Y, 0)
end

--- returns whether `inputobject.position` is within bounds of box defined by `absoluteposition` and `absolutesize`
@native
local function isinputinbounds(absoluteposition: Vector2, absolutesize: Vector2, inputobject: InputObject)
	local bottomright = absoluteposition + absolutesize
	local inputposition = inputobject.Position
	local px, py = inputposition.X, inputposition.Y

	return px >= absoluteposition.X
		and py >= absoluteposition.Y
		and px <= bottomright.X
		and py <= bottomright.Y
end

--- returns human-parsable string representation of vector \
--- 2 decimal places
@native
local function humanvector(v: Vector3)
	return string.format("%.2f %.2f %.2f", v.X, v.Y, v.Z)
end

--- ### inputcontroller.luau
---
--- input controller
local inputcontroller = {
	--- raw input value blob \
	--- `[01]`: keyboard forward \
	--- `[02]`: keyboard backward \
	--- `[03]`: keyboard left \
	--- `[04]`: keyboard right \
	--- `[05]`: keyboard camera pan left \
	--- `[06]`: keyboard camera pan right \
	--- `[07]`: keyboard camera zoom in \
	--- `[08]`: keyboard camera zoom out \
	--- `[09]`: mouse movement delta x \
	--- `[10]`: mouse movement delta y \
	--- `[11]`: pointer wheel (pointeraction) \
	--- `[12]`: pointer pinch (pointeraction) \
	--- `[13]`: pointer pan x \
	--- `[14]`: pointer pan y \
	--- `[15]`: touch pan x \
	--- `[16]`: touch pan y \
	--- `[17]`: touch pinch \
	--- `[18]`: touch thumbstick x \
	--- `[19]`: touch thumbstick y \
	--- `[20]`: gamepad left stick x \
	--- `[21]`: gamepad left stick y \
	--- `[22]`: gamepad left stick press
	--- `[23]`: gamepad right stick x \
	--- `[24]`: gamepad right stick y
	--- `[25]`: gamepad right stick press
	blob = table.create(25, 0);

	blobkeymap = {
		[Enum.UserInputType.MouseMovement] = { index = 0; value = 0; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		--- [Enum.KeyCode.TrackpadPan] = { index = 0; value = 0; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		--- [Enum.KeyCode.TrackpadPinch] = { index = 0; value = 0; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.W] = { index = 1; value = -1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.S] = { index = 2; value = 1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.A] = { index = 3; value = -1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.D] = { index = 4; value = 1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.Up] = { index = 1; value = -1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.Down] = { index = 2; value = 1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.Left] = { index = 5; value = -1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.Right] = { index = 6; value = 1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.I] = { index = 7; value = -1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };
		[Enum.KeyCode.O] = { index = 8; value = 1; preferredinput = Enum.PreferredInput.KeyboardAndMouse };

		[Enum.UserInputType.Touch] = { index = 0; value = 0; preferredinput = Enum.PreferredInput.Touch };

		[Enum.KeyCode.Thumbstick1] = { index = 0; value = 0; preferredinput = Enum.PreferredInput.Gamepad };
		[Enum.KeyCode.Thumbstick2] = { index = 0; value = 0; preferredinput = Enum.PreferredInput.Gamepad };
		--- [Enum.KeyCode.ButtonL3] = { index = 22; value = 0; preferredinput = Enum.PreferredInput.Gamepad };
		[Enum.KeyCode.ButtonR3] = { index = 25; value = 1; preferredinput = Enum.PreferredInput.Gamepad };
	} :: {[Enum.KeyCode|Enum.UserInputType]: {index: number, value: number, preferredinput: Enum.PreferredInput}};

	--- interally-resolved preferred input based on recency
	preferredinput = Enum.PreferredInput.KeyboardAndMouse;
	preferredinputflag = "cc_preferredinput";

	--- `Enum.UserInputType -> Enum.PreferredInput` conversion table \
	--- `Enum.UserInputType.TextInput` is omitted and should be accounted for externally
	preferredinputmap = {
		[Enum.UserInputType.None] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.Focus] = Enum.PreferredInput.KeyboardAndMouse;

		[Enum.UserInputType.MouseButton1] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseButton2] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseButton3] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseWheel] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.MouseMovement] = Enum.PreferredInput.KeyboardAndMouse;
		[Enum.UserInputType.Keyboard] = Enum.PreferredInput.KeyboardAndMouse;
		
		[Enum.UserInputType.Touch] = Enum.PreferredInput.Touch;
		[Enum.UserInputType.Accelerometer] = Enum.PreferredInput.Touch;
		[Enum.UserInputType.Gyro] = Enum.PreferredInput.Touch;

		[Enum.UserInputType.Gamepad1] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad2] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad3] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad4] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad5] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad6] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad7] = Enum.PreferredInput.Gamepad;
		[Enum.UserInputType.Gamepad8] = Enum.PreferredInput.Gamepad;
	};

	--- `Enum.PreferredInput -> Enum.ContextActionPriority.___.Value` conversion table
	actionpriorities = {
		[Enum.PreferredInput.Gamepad] = Enum.ContextActionPriority.Medium.Value;
		[Enum.PreferredInput.KeyboardAndMouse] = Enum.ContextActionPriority.Medium.Value;
		[Enum.PreferredInput.Touch] = Enum.ContextActionPriority.High.Value;
	};
	--- `Enum.PreferredInput -> touchgui visibility` conversion table
	preferredinputtouchguivisible = {
		[Enum.PreferredInput.Gamepad] = false;
		[Enum.PreferredInput.KeyboardAndMouse] = false;
		[Enum.PreferredInput.Touch] = true;
	};

	--- pointer action (trackpad) connection
	pointeractionconnection = nil :: RBXScriptConnection?;

	inputvectordeadzone = 0.1;
	inputrotationspeedconfig = {
		--- arrow key camera pan speed in radians/sec \
		--- ROTATION_SPEED_KEYS
		arrowkeyspeed = math.rad(120);
		--- gamepad pan speed in radians/sec \
		--- ROTATION_SPEED_GAMEPAD
		gamepadspeed = math.rad(7); --- Vector2.new(1, 0.77) * math.rad(7);
		--- mouse pan speed in radians/sec
		--- ROTATION_SPEED_MOUSE
		mousespeed = math.rad(0.5); --- Vector2.new(1, 0.77)*math.rad(0.5);
		--- pointer pan speed in radians/sec
		--- ROTATION_SPEED_POINTERACTION
		pointerspeed = math.rad(7); --- Vector2.new(1, 0.77)*math.rad(7);
		--- touch pan speed in radians/sec
		--- ROTATION_SPEED_TOUCH
		touchspeed = math.rad(1); --- Vector2.new(1, 0.66)*math.rad(1);
	};
	inputzoomspeedconfig = {
		--- (scaled studs/wheel click)
		--- ZOOM_SPEED_MOUSE
		mousezoomspeed = 1;
		--- (studs/s)
		--- ZOOM_SPEED_KEYS
		keyzoomspeed = 0.1;
		--- (scaled studs/DIP %)
		--- ZOOM_SPEED_TOUCH
		touchzoomspeed = 0.04;
	};
	
	--- "...Adjust the touch sensitivity so that sensitivity is reduced when swiping up \
	--- 25% sensitivity at 90°" \
	--- MIN_TOUCH_SENSITIVITY_FRACTION
	touchsensitivityfraction = 0.25;
	touchrotationusescurvedinput = true;

	--- gamepad L3 deadzone
	---- gamepaddeadzone = 0.1;

	--- array of non-thumbstick touchobjects
	--- 9 fingers (1 is using the thumbstick)
	nonthumbsticktouchobjects = table.create(9)::{InputObject};
	touchlastdistance = nil :: number?;

	--- current thumbstick inputobject
	touchobject = nil :: InputObject?;
	--- touch thumbstick start position
	touchstartposition = Vector3.zero;
	--- touch thumbstick current position
	touchcurrentposition = Vector3.zero;
	--- touch thumbstick (L3) deadzone
	touchdeadzone = 0.1;
	--- touch connections so thumbstick inputs can be read through the client gui (menu/chat button etc)
	touchmovedconnection = nil :: RBXScriptConnection?;
	touchendedconnection = nil :: RBXScriptConnection?;

	--- current touch gui \
	--- touchgui is always instantiated
	--- regardless of current input \
	--- for consistency
	touchgui = nil :: ScreenGui?;

	--- current virtual cursor gui \
	--- touchgui is always instantiated
	--- regardless of current input \
	--- for consistency
	virtualcursorgui = nil :: ScreenGui?;
	virtualcursorcanvasgroup = nil :: CanvasGroup?;
	virtualcursortransparency = 1/3; --- canvasgroup transparency
	virtualcursorappearance = {
		{ anchorpoint = Vector2.new(0.5, 0.5); size = UDim2.fromOffset(2, 24); position = UDim2.fromOffset(32, 32); rotation = 0; color = Color3.fromRGB(255, 255, 255); strokesize = 1; stroketransparency = 0.75; strokecolor = Color3.fromRGB(27, 42, 53); };
		{ anchorpoint = Vector2.new(0.5, 0.5); size = UDim2.fromOffset(2, 24); position = UDim2.fromOffset(32, 32); rotation = 90; color = Color3.fromRGB(255, 255, 255); strokesize = 1; stroketransparency = 0.75; strokecolor = Color3.fromRGB(27, 42, 53); };
	};

	--- virtualcursorcanvasgroup.absoluteposition + (virtualcursorcanvasgroup.absolutesize * 0.5)
	virtualcursorscreenposition = Vector2.zero;
	--- raycastresult from raycast from virtual cursor viewport position
	virtualcursorraycastresult = nil :: RaycastResult?;
	--- length of raycast from virtual cursor viewport position
	virtualcursorraycastlength = 2^16-1;
	--- raycastparams used for resolving virtualcursorraycastresult
	virtualcursorraycastparams = RaycastParams.new();

	--- show debug visuals for resolving virtual cursor raycast
	virtualcursordebugmode = false;

	--- `Enum.DisplaySize -> touch thumbstick config` conversion table
	displaysizethumbstickconfig = {
		[Enum.DisplaySize.Small] = {
			circlesize = UDim2.fromOffset(48, 48);
			ringsize = UDim2.fromOffset(96, 96);
			framesize = UDim2.new(0.400, 0, 0.667, 0);
			frameposition = UDim2.new(0, 0, 0.333, 0);
		};
		[Enum.DisplaySize.Medium] = {
			circlesize = UDim2.fromOffset(56, 56);
			ringsize = UDim2.fromOffset(112, 112);
			framesize = UDim2.new(0.400, 0, 0.667, 0);
			frameposition = UDim2.new(0, 0, 0.333, 0);
		};
		[Enum.DisplaySize.Large] = {
			circlesize = UDim2.fromOffset(64, 64);
			ringsize = UDim2.fromOffset(128, 128);
			framesize = UDim2.new(0.400, 0, 0.667, 0);
			frameposition = UDim2.new(0, 0, 0.333, 0);
		};
	};

	contextactionname = "cc_input";
}

--- returns an xz movement vector as a sum of select index-value pairs in `inputcontroller.blob` \
@native
function inputcontroller.blobreadinputvector()
	local blob = inputcontroller.blob

	return Vector3.new(
		blob[3] + blob[4] + blob[18] + blob[20],
		0,
		blob[1] + blob[2] + blob[19] - blob[21]
	)
end

--- resets select index-value pairs in `inputcontroller.blob` that are used to solve the `inputcontroller.blobreadinputvector()`
@native
function inputcontroller.blobresetinputvector()
	local blob = inputcontroller.blob

	blob[1] = 0
	blob[2] = 0
	blob[3] = 0
	blob[4] = 0

	blob[18] = 0
	blob[19] = 0

	blob[20] = 0
	blob[21] = 0
end

--- returns an xy rotation vector (in radians/sec) as a sum of select index-value pairs in `inputcontroller.blob` \
--- accounts for game settings
@native
function inputcontroller.blobreadrotationvector(dt: number)
	local blob = inputcontroller.blob
	local inputrotationspeedconfig = inputcontroller.inputrotationspeedconfig		 
	
	local mousesensitivity = UserGameSettings.MouseSensitivity

	local arrowkeyspeed = inputrotationspeedconfig.arrowkeyspeed * dt
	local mousespeed = inputrotationspeedconfig.mousespeed
	local pointerspeed = inputrotationspeedconfig.pointerspeed
	local touchspeed = inputrotationspeedconfig.touchspeed
	local gamepadspeed = inputrotationspeedconfig.gamepadspeed * mousesensitivity

	local touchdeltax, touchdeltay = blob[15], blob[16]
	if (inputcontroller.touchrotationusescurvedinput == true) and (inputcontroller.preferredinput == Enum.PreferredInput.Touch) then
		touchdeltax, touchdeltay = inputcontroller.solvetouchpitchsensitivity(Vector3.new(touchdeltax, touchdeltay, 0))
	end

	local ysign = UserGameSettings:GetCameraYInvertValue()

	return Vector3.new(
		--- x
 		  ((blob[5] + blob[6]) * arrowkeyspeed
		+ blob[9] * mousespeed
		+ blob[13] * pointerspeed
		+ touchdeltax * touchspeed
		+ blob[23] * gamepadspeed),
		--- y
		  (blob[10] * mousespeed
		+ blob[14] * pointerspeed
		+ touchdeltay * touchspeed
 		+ -blob[24] * gamepadspeed) * ysign,
		0
	)
end

--- resets select index-value pairs in `inputcontroller.blob` that are used to solve the `inputcontroller.blobreadrotationvector()` \
--- preserves non-delta inputs (keyboard camera pan, gamepad right stick)
@native
function inputcontroller.blobresetrotationvector()
	local blob = inputcontroller.blob

	--- blob[5] = 0
	--- blob[6] = 0
	blob[9] = 0
	blob[10] = 0
	blob[13] = 0
	blob[14] = 0
	blob[15] = 0
	blob[16] = 0
	--- blob[23] = 0
	--- blob[24] = 0
end

--- "...adjusts the touch sensitivity delta so that sensitivity is reduced when swiping up \
--- or down, but stays the same when swiping towards the middle of the screen"
function inputcontroller.solvetouchpitchsensitivity(delta: Vector3)
	local camera = workspace.CurrentCamera

	if not camera then
		return delta.X, delta.Y
	end
	
	--- get the camera pitch in world space
	local pitch = camera.CFrame:ToEulerAnglesYXZ()
	
	if delta.Y*pitch >= 0 then
		--- do not reduce sensitivity when pitching towards the horizon
		return delta.X, delta.Y
	end
	
	--- set up a line to fit: \
	--- 1 = f(0) \
	--- 0 = f(±pi/2)
	local curveY = 1 - (2*math.abs(pitch)/math.pi)^0.75

	--- remap curveY from [0, 1] -> [MIN_TOUCH_SENSITIVITY_FRACTION, 1]
	local sensitivity = math.map(curveY, 0, 1, inputcontroller.touchsensitivityfraction, 1)

	return delta.X, sensitivity * delta.Y
end

--- returns an xy rotation vector (in radians/sec) as a sum of select index-value pairs in `inputcontroller.blob` \
@native
function inputcontroller.blobreadzoominput(dt: number)
	local blob = inputcontroller.blob
	local inputzoomspeedconfig = inputcontroller.inputzoomspeedconfig		 
	
	return
		  ((blob[7] + blob[8]) * inputzoomspeedconfig.keyzoomspeed)
		+ ((-blob[11] - blob[12]) * inputzoomspeedconfig.mousezoomspeed)
		+ ((blob[17]) * inputzoomspeedconfig.touchzoomspeed)
end

--- pops value in `inputcontroller.blob[25]` (gamepad right thumbstick), then sets value to 0
@native
function inputcontroller.blobpopgamepadzoom()
	local blob = inputcontroller.blob
	local delta = blob[25]
	blob[25] = 0

	return delta
end

--- resets select index-value pairs in `inputcontroller.blob` that are used to solve the `inputcontroller.blobreadzoominput()` \
--- preserves non-delta inputs (keyboard camera zoom)
@native
function inputcontroller.blobresetzoominput()
	local blob = inputcontroller.blob

	--- blob[7] = 0
	--- blob[8] = 0
	blob[11] = 0
	blob[12] = 0
	blob[17] = 0
end

--- sets delta-based index-value pairs in `inputcontroller.blob` to 0
@native
function inputcontroller.blobresetdeltas()
	local blob = inputcontroller.blob

	--- pan
	blob[9] = 0
	blob[10] = 0
	blob[13] = 0
	blob[14] = 0
	blob[15] = 0
	blob[16] = 0

	--- zoom
	blob[11] = 0
	blob[12] = 0
	blob[17] = 0
end

--- sets all index-value pairs in `inputcontroller.blob` to 0
@native
function inputcontroller.blobreset()
	local blob = inputcontroller.blob
	for index = 1, #blob do
		blob[index] = 0
	end
end

--- sets select range of index-value pairs in `inputcontroller.blob` to 0
@native
function inputcontroller.blobresetrange(i: number, j: number)
	local blob = inputcontroller.blob
	for index = i, j, 1 do
		blob[index] = 0
	end
end

--- returns array of keycodes & userinputtypes to be passed into an internally-called `contextactionservice:bindactionatpriority()`
function inputcontroller.listkeys(preferredinput: Enum.PreferredInput)
	local result = {}
	for k, v  in inputcontroller.blobkeymap do
		if v.preferredinput == preferredinput then
			table.insert(result, k)
		end
	end

	return result
end

--- rebinds cc inputs wrt preferredinput
function inputcontroller.rebind(preferredinput: Enum.PreferredInput)
	ContextActionService:UnbindAction(inputcontroller.contextactionname)

	if preferredinput == Enum.PreferredInput.KeyboardAndMouse then
		ContextActionService:BindActionAtPriority(
			inputcontroller.contextactionname,
			inputcontroller.keyboard,
			false,
			inputcontroller.actionpriorities[preferredinput],
			unpack(inputcontroller.listkeys(preferredinput))
		)

		if inputcontroller.pointeractionconnection then
			inputcontroller.pointeractionconnection:Disconnect()
			inputcontroller.pointeractionconnection = nil
		end
		inputcontroller.pointeractionconnection = UserInputService.PointerAction:Connect(function(wheel: number, pan: Vector2, pinch: number, sunkinput: boolean)
			if sunkinput then return end

			local blob = inputcontroller.blob
			blob[11] = wheel
			blob[12] = pinch
			blob[13] = pan.X
			blob[14] = pan.Y
		end)
	elseif preferredinput == Enum.PreferredInput.Gamepad then
		ContextActionService:BindActionAtPriority(
			inputcontroller.contextactionname,
			inputcontroller.gamepad,
			false,
			inputcontroller.actionpriorities[preferredinput],
			unpack(inputcontroller.listkeys(preferredinput))
		)
	elseif preferredinput == Enum.PreferredInput.Touch then
		ContextActionService:BindActionAtPriority(
			inputcontroller.contextactionname,
			inputcontroller.touch,
			false,
			inputcontroller.actionpriorities[preferredinput],
			unpack(inputcontroller.listkeys(preferredinput))
		)

		--- touchmoved for movement against sink-able gui elements \
		--- that don't get read by the contextactionservice bind
		if inputcontroller.touchmovedconnection then
			inputcontroller.touchmovedconnection:Disconnect()
			inputcontroller.touchmovedconnection = nil
		end
		inputcontroller.touchmovedconnection = UserInputService.TouchMoved:Connect(function(inputobject: InputObject)
			inputcontroller.touch(inputcontroller.contextactionname, Enum.UserInputState.Change, inputobject)
		end)

		--- touchended for reading touch ended events against sink-able gui elements \
		--- that don't get read by the contextactionservice bind
		if inputcontroller.touchendedconnection then
			inputcontroller.touchendedconnection:Disconnect()
			inputcontroller.touchendedconnection = nil
		end
		inputcontroller.touchendedconnection = UserInputService.TouchEnded:Connect(function(inputobject: InputObject)
			inputcontroller.touch(inputcontroller.contextactionname, Enum.UserInputState.End, inputobject)
		end)
		
		table.clear(inputcontroller.nonthumbsticktouchobjects)
	else
		warn("unaccounted preferredinput:", preferredinput.Name)
	end
end

--- internally-bound by `inputcontroller.rebind(Enum.PreferredInput.KeyboardAndMouse)`
function inputcontroller.keyboard(action: string, inputstate: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
	if inputstate == Enum.UserInputState.Cancel then
		inputcontroller.blobreset()

		return Enum.ContextActionResult.Sink
	elseif inputobject.UserInputType == Enum.UserInputType.MouseMovement then
		--- x/y
		--- units are in multiples of mouse sensitivity setting
		local delta = inputobject.Delta
		local blob = inputcontroller.blob
		blob[9] = delta.X
		blob[10] = delta.Y
	else
		local keycode = inputobject.KeyCode
		local mapping = inputcontroller.blobkeymap[keycode]
		local value = if inputstate == Enum.UserInputState.Begin then mapping.value else 0

		inputcontroller.blob[mapping.index] = value
	end

	return Enum.ContextActionResult.Pass
end

--- internally-bound by `inputcontroller.rebind(Enum.PreferredInput.Gamepad)`
function inputcontroller.gamepad(action: string, inputstate: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
	if inputstate == Enum.UserInputState.Cancel then
		inputcontroller.blobreset()
		
		return Enum.ContextActionResult.Sink
	elseif inputobject.KeyCode == Enum.KeyCode.Thumbstick1 then
		--- x/y
		local position = inputobject.Position
		local blob = inputcontroller.blob
		blob[20] = position.X
		blob[21] = position.Y
	elseif inputobject.KeyCode == Enum.KeyCode.Thumbstick2 then
		--- x/y
		local position = inputobject.Position
		local blob = inputcontroller.blob
		blob[23] = position.X
		blob[24] = position.Y
	else
		local keycode = inputobject.KeyCode
		local mapping = inputcontroller.blobkeymap[keycode]
		local value = if inputstate == Enum.UserInputState.Begin then mapping.value else 0

		inputcontroller.blob[mapping.index] = value
	end

	return Enum.ContextActionResult.Pass
end

--- internally-bound by `inputcontroller.rebind(Enum.PreferredInput.Touch)`
function inputcontroller.touch(action: string, inputstate: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
	local touchgui = inputcontroller.touchgui
	if not touchgui then return nil end

	local thumbstickframe = (touchgui::any).ThumbstickFrame::Frame
	local thumbstickframeapos = thumbstickframe.AbsolutePosition
	local thumbstickframeasize = thumbstickframe.AbsoluteSize

	local netinset = vectorxytovector3(thumbstickframeapos - touchgui.AbsolutePosition)
	local inputposition = inputobject.Position - netinset

	local ring = (thumbstickframe::any).Ring::Frame
	local circle = (thumbstickframe::any).Circle::Frame

	if inputstate == Enum.UserInputState.Begin then
		if isinputinbounds(thumbstickframeapos, thumbstickframeasize, inputobject) then
			--- intent to use thumbstick
			if inputcontroller.touchobject == nil then
				--- no current touchobject
				inputcontroller.touchobject = inputobject

				inputcontroller.touchcurrentposition = inputposition
				inputcontroller.touchstartposition = inputposition
				
				local inputudim2 = vectorxytoudim2(inputposition)
				ring.Position = inputudim2
				circle.Position = inputudim2
			else
				--- touchobject is already using thumbstick
			end
		else
			--- intent to pan/pinch
			if not table.find(inputcontroller.nonthumbsticktouchobjects, inputobject) then
				table.insert(inputcontroller.nonthumbsticktouchobjects, inputobject)
				--- print(string.format("(began) touches on screen: [%d]", #inputcontroller.nonthumbsticktouchobjects))
			end
		end
	elseif inputstate == Enum.UserInputState.Change then
		if inputcontroller.touchobject == inputobject then
			--- intent to move
			inputcontroller.touchcurrentposition = inputposition

			local delta = inputcontroller.touchcurrentposition - inputcontroller.touchstartposition
			local direction = (vector.normalize(delta::any)::any)::Vector3
			local distance = vector.magnitude(delta::any)
			local radius = ring.AbsoluteSize.X * 0.5
			local innerradius = inputcontroller.touchdeadzone * radius
			if distance > radius then
				local dragpos = inputcontroller.touchstartposition + (direction * (distance - radius))
				ring.Position = vectorxytoudim2(dragpos)
				inputcontroller.touchstartposition = dragpos
			end

			if distance > innerradius then
				local blob = inputcontroller.blob
				local a = math.map(math.clamp(distance, 0, radius), innerradius, radius, 0, 1)

				blob[18] = direction.X * a
				blob[19] = direction.Y * a
			else
				inputcontroller.blobresetinputvector()
			end

			local inputudim2 = vectorxytoudim2(inputposition)
			circle.Position = inputudim2
			
			return Enum.ContextActionResult.Sink
		elseif table.find(inputcontroller.nonthumbsticktouchobjects, inputobject) then
			--- intent to pan/pinch
			local t = inputcontroller.nonthumbsticktouchobjects
			local len = #t
			if len == 1 then
				--- intent to pan
				local delta = t[1].Delta

				local blob = inputcontroller.blob
				blob[15] = delta.X
				blob[16] = delta.Y
			elseif len == 2 then
				--- intent to pinch
				local io1: InputObject, io2: InputObject = t[1], t[2]
				local position1, position2 = io1.Position, io2.Position
				local distance = vector.magnitude(position2::any - position1)

				if inputcontroller.touchlastdistance == nil then
					inputcontroller.touchlastdistance = distance
				else
					local deltadistance = inputcontroller.touchlastdistance - distance

					local blob = inputcontroller.blob
					blob[17] += deltadistance
				end
			end
		end
	elseif inputstate == Enum.UserInputState.End then
		if inputcontroller.touchobject == inputobject then
			inputcontroller.touchobject = nil
			inputcontroller.blobresetinputvector()

			ring.Position = UDim2.fromScale(0.5, 0.5)
			circle.Position = UDim2.fromScale(0.5, 0.5)

			return Enum.ContextActionResult.Sink
		elseif table.find(inputcontroller.nonthumbsticktouchobjects, inputobject) then
			table.remove(inputcontroller.nonthumbsticktouchobjects, table.find(inputcontroller.nonthumbsticktouchobjects, inputobject) or 0)
			--- print(string.format("(end) touches on screen: [%d]", #inputcontroller.nonthumbsticktouchobjects))
			if #inputcontroller.nonthumbsticktouchobjects < 2 then
				inputcontroller.touchlastdistance = nil
			end
		end
	elseif inputstate == Enum.UserInputState.Cancel then
		inputcontroller.touchobject = nil
		table.clear(inputcontroller.nonthumbsticktouchobjects)
		inputcontroller.touchlastdistance = nil
		inputcontroller.blobresetinputvector()

		ring.Position = UDim2.fromScale(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
	end

	return Enum.ContextActionResult.Pass
end

--- returns an empty touchgui
function inputcontroller.createtouchgui(playergui: PlayerGui)
	--- base touchgui
	local touchgui = Instance.new("ScreenGui")
	touchgui.Name = "cc_touchgui"
	touchgui.IgnoreGuiInset = false
	touchgui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
	touchgui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	touchgui.ResetOnSpawn = false

	local displaysizethumbstickconfig = inputcontroller.displaysizethumbstickconfig[Enum.DisplaySize.Medium]

	--- bottom-left thumbstick frame
	local thumbstickframe = Instance.new("Frame")
	thumbstickframe.Name = "ThumbstickFrame"
	thumbstickframe.AnchorPoint = Vector2.zero
	thumbstickframe.Size = displaysizethumbstickconfig.framesize
	thumbstickframe.Position = displaysizethumbstickconfig.frameposition
	thumbstickframe.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	thumbstickframe.BackgroundTransparency = 1
	thumbstickframe.Parent = touchgui

	--- ring around circle
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.one * 0.5
	ring.Size = displaysizethumbstickconfig.ringsize
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 0
	ring.Parent = thumbstickframe

	local ringstroke = Instance.new("UIStroke")
	ringstroke.Thickness = 2
	ringstroke.Transparency = 0.667
	ringstroke.Parent = ring

	local ringcorner = Instance.new("UICorner")
	ringcorner.CornerRadius = UDim.new(1, 0)
	ringcorner.Parent = ring

	--- circle
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.one * 0.5
	circle.Size = displaysizethumbstickconfig.circlesize
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	circle.BackgroundTransparency = 0.25
	circle.ZIndex = 1
	circle.Parent = thumbstickframe

	local circlestroke = Instance.new("UIStroke")
	circlestroke.Thickness = 2
	circlestroke.Transparency = 0.667
	circlestroke.Parent = circle

	local circlecorner = Instance.new("UICorner")
	circlecorner.CornerRadius = UDim.new(1, 0)
	circlecorner.Parent = circle
	
	touchgui.Parent = playergui

	return touchgui
end

--- returns an empty virtual cursor
function inputcontroller.createvirtualcursor(playergui: PlayerGui)
	--- base touchgui
	local virtualcursorgui = Instance.new("ScreenGui")
	virtualcursorgui.Name = "cc_virtualcursorgui"
	virtualcursorgui.IgnoreGuiInset = true
	virtualcursorgui.ScreenInsets = Enum.ScreenInsets.None
	virtualcursorgui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	virtualcursorgui.ResetOnSpawn = false
	virtualcursorgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local cursor = Instance.new("CanvasGroup")
	cursor.Name = "Cursor"
	cursor.AnchorPoint = Vector2.one * 0.5
	cursor.Size = UDim2.fromOffset(64, 64)
	cursor.Position = UDim2.fromScale(0.5, 0.5)
	cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	cursor.BackgroundTransparency = 1
	cursor.BorderSizePixel = 0
	cursor.ZIndex = 1
	cursor.Parent = virtualcursorgui

	virtualcursorgui.Parent = playergui

	return virtualcursorgui
end

--- applies cursor appearance `a` to virtual cursor canvas group `cursorcanvasgroup`
function inputcontroller.applyvirtualcursorfromappearance(a: typeof(inputcontroller.virtualcursorappearance), cursorcanvasgroup: CanvasGroup)
	cursorcanvasgroup:ClearAllChildren()
	cursorcanvasgroup.GroupTransparency = inputcontroller.virtualcursortransparency
	
	local frames = table.create(#a)
	for i, line in ipairs(a) do
		local frame = Instance.new("Frame")
		frame.Name = tostring(i)
		frame.AnchorPoint = line.anchorpoint
		frame.Size = line.size
		frame.Position = line.position
		frame.Rotation = line.rotation
		frame.BackgroundColor3 = line.color
		frame.BorderSizePixel = 0

		local uistroke = Instance.new("UIStroke")
		uistroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		uistroke.Color = line.strokecolor
		uistroke.LineJoinMode = Enum.LineJoinMode.Miter
		uistroke.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
		uistroke.Thickness = line.strokesize
		uistroke.Transparency = line.stroketransparency
		uistroke.Parent = frame

		table.insert(frames, frame)

		frame.Parent = cursorcanvasgroup
	end

	return frames
end

--- returns internally-resolved `UserInputService.PreferredInput` signal based on recency
function inputcontroller.preferredinputchanged()
	return script:GetAttributeChangedSignal(inputcontroller.preferredinputflag)
end

if RunService:IsClient() then
	do --- resolve touchgui
		local s, e = pcall(function()
			local playergui = localplayer:WaitForChild("PlayerGui")
			assert(playergui:IsA("PlayerGui"), string.format("expected playergui, got %s", playergui.ClassName))
			local touchgui = inputcontroller.createtouchgui(playergui)
			
			inputcontroller.touchgui = touchgui

			--- resize/repositions touchgui wrt displaysize enum
			local function adjust(touchgui: typeof(inputcontroller.createtouchgui(playergui)), displaysize: Enum.DisplaySize)
				local thumbstickframe = (touchgui::any).ThumbstickFrame::Frame

				local displaysizethumbstickconfig = inputcontroller.displaysizethumbstickconfig[displaysize]

				thumbstickframe.Size = displaysizethumbstickconfig.framesize
				thumbstickframe.Position = displaysizethumbstickconfig.frameposition

				local ring = (thumbstickframe::any).Ring::Frame
				ring.Size = displaysizethumbstickconfig.ringsize
				
				local circle = (thumbstickframe::any).Circle::Frame
				circle.Size = displaysizethumbstickconfig.circlesize
			end

			local function adjusttouchgui()
				adjust(touchgui, GuiService.ViewportDisplaySize)
			end

			adjusttouchgui()
			GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(adjusttouchgui)

			touchgui.Enabled = inputcontroller.preferredinputtouchguivisible[inputcontroller.preferredinput]
			inputcontroller.preferredinputchanged():Connect(function()
				touchgui.Enabled = inputcontroller.preferredinputtouchguivisible[inputcontroller.preferredinput]
			end)

			return true
		end)
		if not s then warn(e) end
	end
	do --- resolve virtual cursor
		local s, e = pcall(function()
			local playergui = localplayer:WaitForChild("PlayerGui")
			assert(playergui:IsA("PlayerGui"), string.format("expected playergui, got %s", playergui.ClassName))
			local virtualcursor = inputcontroller.createvirtualcursor(playergui)
			
			inputcontroller.virtualcursor = virtualcursor
			inputcontroller.virtualcursorcanvasgroup = virtualcursor:FindFirstChild("Cursor") :: CanvasGroup?

			if inputcontroller.virtualcursorcanvasgroup then
				inputcontroller.applyvirtualcursorfromappearance(inputcontroller.virtualcursorappearance, inputcontroller.virtualcursorcanvasgroup)
			end

			return true
		end)
		if not s then warn(e) end
	end
	do --- resolve internal preferred input
		local s, e = pcall(function()
			local function updatepreferredinput(userinputtype: Enum.UserInputType)
				local thispreferredinput = inputcontroller.preferredinputmap[userinputtype]
				if thispreferredinput == nil then return end
				if inputcontroller.preferredinput ~= thispreferredinput then
					inputcontroller.preferredinput = thispreferredinput

					script:SetAttribute(inputcontroller.preferredinputflag, inputcontroller.preferredinput.Value)
				end
			end

			UserInputService.LastInputTypeChanged:Connect(updatepreferredinput)
			updatepreferredinput(UserInputService:GetLastInputType())

			return true
		end)
		if not s then warn(e) end
	end
	do --- resolve virtual cursor screenposition & worldposition
		local debugsquare = Instance.new("Frame")
		debugsquare.Name = "cc_debugsquare"
		debugsquare.Size = UDim2.fromOffset(1, 1)
		debugsquare.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
		debugsquare.BorderSizePixel = 1
		debugsquare.AnchorPoint = Vector2.new(0.5, 0.5)
		debugsquare.Visible = false
		debugsquare.Parent = inputcontroller.virtualcursor

		local debugorigin = Instance.new("Part")
		debugorigin.Name = "cc_debugorigin"
		debugorigin.Size = Vector3.one
		debugorigin.Color = Color3.fromRGB(255, 0, 255)
		debugorigin.Transparency = 1
		debugorigin.CastShadow = false
		debugorigin.Anchored = true
		debugorigin.CanCollide = false
		debugorigin.CanQuery = false
		debugorigin.CanTouch = false
		debugorigin.Parent = workspace

		local debugcone = Instance.new("ConeHandleAdornment")
		debugcone.Name = "cc_debugcone"
		debugcone.Adornee = debugorigin
		debugcone.Height = 0.5
		debugcone.Radius = 0.25
		debugcone.Color3 = Color3.fromRGB(255, 0, 255)
		debugcone.Shading = Enum.AdornShading.XRay
		debugcone.Visible = false
		debugcone.Parent = debugorigin

		RunService.RenderStepped:Connect(function()
			local virtualcursorcanvasgroup = inputcontroller.virtualcursorcanvasgroup
			if not virtualcursorcanvasgroup then return end

			--- resolve cursor position
			local vcapos = virtualcursorcanvasgroup.AbsolutePosition
			local vcasize = virtualcursorcanvasgroup.AbsoluteSize

			vcapos += (vcasize * 0.5) + GuiService:GetGuiInset()

			local camera = workspace.CurrentCamera

			--- resolve raycastresult
			local unitray = camera:ViewportPointToRay(vcapos.X, vcapos.Y)
			local origin, direction = unitray.Origin, unitray.Direction
			local vec = direction * inputcontroller.virtualcursorraycastlength
			local raycastresult = workspace:Raycast(origin, vec, inputcontroller.virtualcursorraycastparams)

			--- resolve debugsquare/debugcone
			if inputcontroller.virtualcursordebugmode == true then
				if debugsquare.Visible == false then
					debugsquare.Visible = true
				end
				if debugcone.Visible == false then
					debugcone.Visible = true
				end

				debugsquare.Position = vectorxytoudim2(vcapos)
				if raycastresult then
					debugcone.CFrame = CFrame.lookAlong(raycastresult.Position, raycastresult.Normal)
				else
					debugcone.CFrame = CFrame.lookAlong(origin + vec, direction)
				end
			else
				if debugsquare.Visible == true then
					debugsquare.Visible = false
					debugsquare.Position = UDim2.fromOffset(0, 0)
				end
				if debugcone.Visible == true then
					debugcone.Visible = false
					debugcone.CFrame = CFrame.identity
				end
			end

			inputcontroller.virtualcursorscreenposition = vcapos
			inputcontroller.virtualcursorraycastresult = raycastresult
		end)
	end
	do --- reset inputs on changes
		UserInputService.TextBoxFocused:Connect(inputcontroller.blobreset)
		UserInputService.TextBoxFocusReleased:Connect(inputcontroller.blobreset)
		UserInputService.WindowFocused:Connect(inputcontroller.blobreset)
		UserInputService.WindowFocusReleased:Connect(inputcontroller.blobreset)
		GuiService.MenuOpened:Connect(inputcontroller.blobreset)
		GuiService.MenuClosed:Connect(inputcontroller.blobreset)
	end
end

return inputcontroller