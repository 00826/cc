--!strict

local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

--- converts vector3 to udim2
@native
local function touchvectortoudim2(vec: Vector3)
	return UDim2.fromOffset(vec.X, vec.Y)
end

--- converts vector2 to vector3
@native
local function vector2tovector3(vec: Vector2)
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

--- ### inputcontroller.luau
---
--- input controller
local inputcontroller = {
	--- input vector
	vector = Vector3.zero;

	--- interally-resolved preferred input based on recency
	preferredinput = Enum.PreferredInput.KeyboardAndMouse;
	preferredinputflag = "cc_preferredinput";

	--- `Enum.UserInputType -> Enum.PreferredInput` conversion table \
	--- `Enum.UserInputType.TextInput` is omitted and should be accounted for externally
	inputtypestopreferredinputs = {
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

	--- `inputvector = Vector3.new(t[1] + t[2], 0, t[3] + t[4])`
	keyboardsigns = table.create(4, 0);
	--- `Enum.KeyCode -> { offset: number; sign: number; }` conversion table
	keyboardmap = {
		[Enum.KeyCode.W] = { offset = 1; sign = -1; };
		[Enum.KeyCode.S] = { offset = 2; sign = 1; };
		[Enum.KeyCode.A] = { offset = 3; sign = -1; };
		[Enum.KeyCode.D] = { offset = 4; sign = 1; };

		[Enum.KeyCode.Up] = { offset = 1; sign = -1; };
		[Enum.KeyCode.Down] = { offset = 2; sign = 1; };
	};

	--- gamepad L3 deadzone
	gamepaddeadzone = 0.1;

	--- current touch inputobject
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
		{ anchorpoint = Vector2.new(1, 0.5); size = UDim2.fromOffset(2, 24); position = UDim2.fromOffset(32, 32); rotation = 0; color = Color3.fromRGB(255, 255, 255); strokesize = 1; stroketransparency = 0.75; strokecolor = Color3.fromRGB(27, 42, 53); };
		{ anchorpoint = Vector2.new(1, 0.5); size = UDim2.fromOffset(2, 24); position = UDim2.fromOffset(32, 32); rotation = 90; color = Color3.fromRGB(255, 255, 255); strokesize = 1; stroketransparency = 0.75; strokecolor = Color3.fromRGB(27, 42, 53); };
	};

	--- `Enum.DisplaySize -> touch thumbstick ring size` conversion table
	thumbstickringmap = {
		[Enum.DisplaySize.Small] = UDim2.fromOffset(72, 72);
		[Enum.DisplaySize.Medium] = UDim2.fromOffset(96, 96);
		[Enum.DisplaySize.Large] = UDim2.fromOffset(128, 128);
	};
	--- `Enum.DisplaySize -> touch thumbstick circle size` conversion table
	thumbstickcirclemap = {
		[Enum.DisplaySize.Small] = UDim2.fromOffset(36, 36);
		[Enum.DisplaySize.Medium] = UDim2.fromOffset(48, 48);
		[Enum.DisplaySize.Large] = UDim2.fromOffset(64, 64);
	};
	--- `Enum.DisplaySize -> touch thumbstickframe size` conversion table
	thumbsticksizemap = {
		[Enum.DisplaySize.Small] = UDim2.new(0.4, 0, 0.667, 0);
		[Enum.DisplaySize.Medium] = UDim2.new(0.4, 0, 0.667, 0);
		[Enum.DisplaySize.Large] = UDim2.new(0.4, 0, 0.667, 0);
	};
	--- `Enum.DisplaySize -> touch thumbstickframe position` conversion table
	thumbstickpositionmap = {
		[Enum.DisplaySize.Small] = UDim2.new(0, 0, 0.333, 0);
		[Enum.DisplaySize.Medium] = UDim2.new(0, 0, 0.333, 0);
		[Enum.DisplaySize.Large] = UDim2.new(0, 0, 0.333, 0);
	};
	--- `Enum.PreferredInput -> touchgui visibility` conversion table
	touchguivisibility = {
		[Enum.PreferredInput.Gamepad] = false;
		[Enum.PreferredInput.KeyboardAndMouse] = false;
		[Enum.PreferredInput.Touch] = true;
	};

	contextactionname = "cc_input";
}

function inputcontroller.rebind(preferredinput: Enum.PreferredInput)
	ContextActionService:UnbindAction(inputcontroller.contextactionname)

	if preferredinput == Enum.PreferredInput.KeyboardAndMouse then
		local list = table.create(8)
		for k in inputcontroller.keyboardmap do
			table.insert(list, k)
		end

		ContextActionService:BindActionAtPriority(inputcontroller.contextactionname, inputcontroller.keyboard, false, inputcontroller.actionpriorities[preferredinput], unpack(list))
	elseif preferredinput == Enum.PreferredInput.Gamepad then
		ContextActionService:BindActionAtPriority(inputcontroller.contextactionname, inputcontroller.gamepad, false, inputcontroller.actionpriorities[preferredinput], Enum.KeyCode.Thumbstick1)
	elseif preferredinput == Enum.PreferredInput.Touch then
		ContextActionService:BindActionAtPriority(inputcontroller.contextactionname, inputcontroller.touch, false, inputcontroller.actionpriorities[preferredinput], Enum.UserInputType.Touch)

		if inputcontroller.touchmovedconnection then
			inputcontroller.touchmovedconnection:Disconnect()
			inputcontroller.touchmovedconnection = nil
		end
		inputcontroller.touchmovedconnection = UserInputService.TouchMoved:Connect(function(inputobject: InputObject)
			inputcontroller.touch(inputcontroller.contextactionname, Enum.UserInputState.Change, inputobject)
		end)

		if inputcontroller.touchendedconnection then
			inputcontroller.touchendedconnection:Disconnect()
			inputcontroller.touchendedconnection = nil
		end
		inputcontroller.touchendedconnection = UserInputService.TouchEnded:Connect(function(inputobject: InputObject)
			inputcontroller.touch(inputcontroller.contextactionname, Enum.UserInputState.End, inputobject)
		end)
	else
		warn("unaccounted preferredinput:", preferredinput.Name)
	end
end

--- internally-bound by `inputcontroller.rebind(Enum.PreferredInput.KeyboardAndMouse)`
function inputcontroller.keyboard(action: string, state: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
	local entry = inputcontroller.keyboardmap[inputobject.KeyCode]
	if not entry then return end

	--[[{
		[1] = forward
		[2] = backward
		[3] = left
		[4] = right
	}]]
	local keysigns = inputcontroller.keyboardsigns
	keysigns[entry.offset] = (state == Enum.UserInputState.Begin) and entry.sign or 0

	if state == Enum.UserInputState.Cancel then
		inputcontroller.vector = Vector3.zero
	else
		inputcontroller.vector = Vector3.new(keysigns[3] + keysigns[4], 0, keysigns[1] + keysigns[2])
	end
	
	return Enum.ContextActionResult.Pass
end

--- zeroes-out input vector and keyboard inputs 
function inputcontroller.reset()
	inputcontroller.vector = Vector3.zero

	local len = #inputcontroller.keyboardsigns
	table.move(table.create(len, 0), 1, len, 1, inputcontroller.keyboardsigns)
end

--- internally-bound by `inputcontroller.rebind(Enum.PreferredInput.Gamepad)`
function inputcontroller.gamepad(action: string, state: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
	if state == Enum.UserInputState.Cancel then
		inputcontroller.vector = Vector3.zero
		return Enum.ContextActionResult.Sink
	end

	if inputobject.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end

	local inputposition = inputobject.Position
	local distance = vector.magnitude(inputposition::any)
	if distance > inputcontroller.gamepaddeadzone then
		local a = math.map(math.clamp(distance, 0, 1), inputcontroller.gamepaddeadzone, 1, 0, 1)
		inputcontroller.vector = Vector3.new(inputposition.X * a, 0, -inputposition.Y * a)
	else
		inputcontroller.vector = Vector3.zero
	end

	return Enum.ContextActionResult.Sink
end

--- internally-bound by `inputcontroller.rebind(Enum.PreferredInput.Touch)`
function inputcontroller.touch(action: string, state: Enum.UserInputState, inputobject: InputObject): Enum.ContextActionResult?
	local touchgui = inputcontroller.touchgui
	if not touchgui then return end

	local thumbstickframe = (touchgui::any).ThumbstickFrame::Frame
	local thumbstickframeapos = thumbstickframe.AbsolutePosition
	local thumbstickframeasize = thumbstickframe.AbsoluteSize

	local netinset = vector2tovector3(thumbstickframeapos - touchgui.AbsolutePosition)
	local inputposition = inputobject.Position - netinset

	local ring = (thumbstickframe::any).Ring::Frame
	local circle = (thumbstickframe::any).Circle::Frame

	if state == Enum.UserInputState.Begin then
		if inputcontroller.touchobject then
			return Enum.ContextActionResult.Pass
		end

		if isinputinbounds(thumbstickframeapos, thumbstickframeasize, inputobject) then
			inputcontroller.touchobject = inputobject

			inputcontroller.touchcurrentposition = inputposition
			inputcontroller.touchstartposition = inputposition

			local inputudim2 = touchvectortoudim2(inputposition)
			ring.Position = inputudim2
			circle.Position = inputudim2
		else
			return Enum.ContextActionResult.Pass
		end
	elseif state == Enum.UserInputState.Change then
		if inputcontroller.touchobject == inputobject then
			inputcontroller.touchcurrentposition = inputposition

			local delta = inputcontroller.touchcurrentposition - inputcontroller.touchstartposition
			local direction = (vector.normalize(delta::any)::any)::Vector3
			local distance = vector.magnitude(delta::any)
			local radius = ring.AbsoluteSize.X * 0.5
			local innerradius = inputcontroller.touchdeadzone * radius
			if distance > radius then
				local dragpos = inputcontroller.touchstartposition + (direction * (distance - radius))
				ring.Position = touchvectortoudim2(dragpos)
				inputcontroller.touchstartposition = dragpos
			end

			if distance > innerradius then
				local a = math.map(math.clamp(distance, 0, radius), innerradius, radius, 0, 1)
				inputcontroller.vector = Vector3.new(direction.X * a, 0, direction.Y * a)
			else
				inputcontroller.vector = Vector3.zero
			end

			local inputudim2 = touchvectortoudim2(inputposition)
			circle.Position = inputudim2
			
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	elseif state == Enum.UserInputState.End then
		if inputcontroller.touchobject == inputobject then
			inputcontroller.touchobject = nil
			inputcontroller.vector = Vector3.zero

			ring.Position = UDim2.fromScale(0.5, 0.5)
			circle.Position = UDim2.fromScale(0.5, 0.5)

			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	elseif state == Enum.UserInputState.Cancel then
		inputcontroller.touchobject = nil
		inputcontroller.vector = Vector3.zero

		ring.Position = UDim2.fromScale(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
	end

	return
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

	--- bottom-left thumbstick frame
	local thumbstickframe = Instance.new("Frame")
	thumbstickframe.Name = "ThumbstickFrame"
	thumbstickframe.AnchorPoint = Vector2.zero
	thumbstickframe.Size = inputcontroller.thumbsticksizemap[Enum.DisplaySize.Medium]
	thumbstickframe.Position = inputcontroller.thumbstickpositionmap[Enum.DisplaySize.Medium]
	thumbstickframe.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	thumbstickframe.BackgroundTransparency = 1
	thumbstickframe.Parent = touchgui

	--- ring around circle
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.one * 0.5
	ring.Size = inputcontroller.thumbstickringmap[Enum.DisplaySize.Medium]
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
	circle.Size = inputcontroller.thumbstickcirclemap[Enum.DisplaySize.Medium]
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
			local playergui = LocalPlayer:WaitForChild("PlayerGui")
			local touchgui = inputcontroller.createtouchgui(playergui)
			
			inputcontroller.touchgui = touchgui

			--- resize/repositions touchgui wrt displaysize enum
			local function adjust(touchgui: typeof(inputcontroller.createtouchgui(playergui)), displaysize: Enum.DisplaySize)
				local thumbstickframe = (touchgui::any).ThumbstickFrame::Frame

				thumbstickframe.Size = inputcontroller.thumbsticksizemap[displaysize]
				thumbstickframe.Position = inputcontroller.thumbstickpositionmap[displaysize]

				local ring = (thumbstickframe::any).Ring::Frame
				ring.Size = inputcontroller.thumbstickringmap[displaysize]
				
				local circle = (thumbstickframe::any).Circle::Frame
				circle.Size = inputcontroller.thumbstickcirclemap[displaysize]
			end

			local function adjusttouchgui()
				adjust(touchgui, GuiService.ViewportDisplaySize)
			end

			adjusttouchgui()
			GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(adjusttouchgui)

			touchgui.Enabled = inputcontroller.touchguivisibility[inputcontroller.preferredinput]
			inputcontroller.preferredinputchanged():Connect(function()
				touchgui.Enabled = inputcontroller.touchguivisibility[inputcontroller.preferredinput]
			end)
		end)
		if not s then warn(e) end
	end
	do --- resolve virtual cursor
		local s, e = pcall(function()
			local playergui = LocalPlayer:WaitForChild("PlayerGui")
			local virtualcursor = inputcontroller.createvirtualcursor(playergui)
			
			inputcontroller.virtualcursor = virtualcursor
			inputcontroller.virtualcursorcanvasgroup = virtualcursor:FindFirstChild("Cursor") :: CanvasGroup?

			if inputcontroller.virtualcursorcanvasgroup then
				inputcontroller.applyvirtualcursorfromappearance(inputcontroller.virtualcursorappearance, inputcontroller.virtualcursorcanvasgroup)
			end
		end)
		if not s then warn(e) end
	end
	do --- resolve internal preferred input
		local s, e = pcall(function()
			local function updatepreferredinput(userinputtype: Enum.UserInputType)
				local thispreferredinput = inputcontroller.inputtypestopreferredinputs[userinputtype]
				if thispreferredinput == nil then return end
				if inputcontroller.preferredinput ~= thispreferredinput then
					inputcontroller.preferredinput = thispreferredinput

					script:SetAttribute(inputcontroller.preferredinputflag, inputcontroller.preferredinput.Value)
				end
			end

			UserInputService.LastInputTypeChanged:Connect(updatepreferredinput)
			updatepreferredinput(UserInputService:GetLastInputType())
		end)
		if not s then warn(e) end
	end
	do --- reset inputs on changes
		UserInputService.TextBoxFocused:Connect(inputcontroller.reset)
		UserInputService.TextBoxFocusReleased:Connect(inputcontroller.reset)
		UserInputService.WindowFocusReleased:Connect(inputcontroller.reset)
		GuiService.MenuOpened:Connect(inputcontroller.reset)
	end
end

return inputcontroller