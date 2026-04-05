local replicatedstorage = game:GetService("ReplicatedStorage")
local cc = require(replicatedstorage.cc)
local rig = cc.rig

local r8limbs = require(script.Parent.r8limbs)

local basetransforms = rig.readmotor6dtransforms(r8limbs::any)

local angleflag = "rig_angle"
local maxvelocityflag = "rig_maxvelocity"

--- solves motor6d.desiredangle
local function solvedesiredangle(motor: AnimationConstraint|Motor6D, desiredangle: number)
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

return function(
	r: Model,
	state: "idle" | "walk" | "fall" | "seat" | "fly",
	crouched: boolean,
	toolpose: "none" | "left" | "right" | "both",
	elapsed: number,
	freq: number,
	ry: number,
	rx: number,
	xreal: number,
	yreal: number,
	zreal: number
)
	--- query motor6ds
	local motors: {[string]: Motor6D} = {}
	for _, motor6d in ipairs(r:QueryDescendants("Motor6D")) do
		motors[motor6d.Name] = motor6d
	end

	--- motors
	local rootjoint = motors.RootJoint
	local neck = motors.Neck
	local rightshoulder = motors.RightShoulder
	local righthip = motors.RightHip
	local leftshoulder = motors.LeftShoulder
	local lefthip = motors.LeftHip
	
	--- base c0's
	local rootjointc0 = basetransforms.RootJoint and basetransforms.RootJoint.c0 or CFrame.identity
	local neckc0 = basetransforms.Neck and basetransforms.Neck.c0 or CFrame.identity
	--- local rightshoulderc0 = basetransforms.RightShoulder and basetransforms.RightShoulder.c0 or CFrame.identity
	--- local righthipc0 = basetransforms.RightHip and basetransforms.RightHip.c0 or CFrame.identity
	--- local leftshoulderc0 = basetransforms.LeftShoulder and basetransforms.LeftShoulder.c0 or CFrame.identity
	--- local lefthipc0 = basetransforms.LeftHip and basetransforms.LeftHip.c0 or CFrame.identity

	--- early return if transforms dont exist
	if (not neck)
	or (not rightshoulder)
	or (not righthip)
	or (not leftshoulder)
	or (not lefthip)
	then
		return
	end

	--- if seated then set c0 and early return
	if state == "seat" then
		rightshoulder.MaxVelocity = 0.25
		leftshoulder.MaxVelocity = 0.25

		rightshoulder.DesiredAngle = math.pi/2
		leftshoulder.DesiredAngle = -math.pi/2
		righthip.DesiredAngle = math.pi/2
		lefthip.DesiredAngle = -math.pi/2

		--- rightshoulder:SetAttribute(maxvelocityflag, 0.15)
		--- leftshoulder:SetAttribute(maxvelocityflag, 0.15)

		--- rightshoulder.C0 = rightshoulderc0 * CFrame.fromOrientation(0, 0, math.pi/2)
		--- leftshoulder.C0 = leftshoulderc0 * CFrame.fromOrientation(0, 0, -math.pi/2)
		--- righthip.C0 = righthipc0 * CFrame.fromOrientation(0, 0, math.pi/2)
		--- lefthip.C0 = lefthipc0 * CFrame.fromOrientation(0, 0, -math.pi/2)

		return
	end

	local addhipangle = 0

	--- rotate neck/rootjoint to match camera angle
	if (crouched)
	then
		neck.MaxVelocity = 0.5
		rootjoint.MaxVelocity = 0.5

		neck:SetAttribute(maxvelocityflag, 0.5)
		rootjoint:SetAttribute(maxvelocityflag, 0.5)

		addhipangle = math.pi/4
		neck.C0 =
			neckc0
			* CFrame.fromOrientation(solvedesiredangle(neck, -math.pi/4), 0, 0)
			--- * CFrame.fromOrientation(-math.pi/4, 0, 0)
			* CFrame.fromOrientation(0, 0, xreal)
			* CFrame.fromOrientation(rx, 0, 0)
		rootjoint.C0 =
			rootjointc0
			* CFrame.fromOrientation(0, 0, ry - xreal)
			* CFrame.new(0, 0, -0.25)
			* CFrame.fromOrientation(solvedesiredangle(rootjoint, math.pi/4), 0, 0)
			--- * CFrame.fromOrientation(math.pi/4, 0, 0)
			* CFrame.fromOrientation(zreal, 0, 0)
			* CFrame.fromOrientation(0, -yreal, 0)
	else
		neck:SetAttribute(maxvelocityflag, 0.5)
		rootjoint:SetAttribute(maxvelocityflag, 0.5)
		addhipangle = 0
		neck.C0 = 
			neckc0
			* CFrame.fromOrientation(solvedesiredangle(neck, 0), 0, 0)
			--- * CFrame.fromOrientation(0, 0, 0)
			* CFrame.fromOrientation(0, 0, xreal)
			* CFrame.fromOrientation(rx, 0, 0)
		rootjoint.C0 =
			rootjointc0
			* CFrame.fromOrientation(0, 0, ry - xreal)
			* CFrame.fromOrientation(solvedesiredangle(rootjoint, 0), 0, 0)
			--- * CFrame.fromOrientation(0, 0, 0)
			* CFrame.fromOrientation(zreal, 0, 0)
			* CFrame.fromOrientation(0, -yreal, 0)
	end

	--- arms straight up if falling
	if (state == "fall") then
		rightshoulder.MaxVelocity = 0.5
		leftshoulder.MaxVelocity = 0.5

		--- rightshoulder:SetAttribute(maxvelocityflag, 0.5)
		--- leftshoulder:SetAttribute(maxvelocityflag, 0.5)

		if (crouched) then
			local approxangle = 0.1 * math.sin(elapsed * 1)

			rightshoulder.DesiredAngle = approxangle
			leftshoulder.DesiredAngle = approxangle

			--- rightshoulder.C0 = rightshoulderc0 * CFrame.fromOrientation(0, 0, approxangle)
			--- leftshoulder.C0 = leftshoulderc0 * CFrame.fromOrientation(0, 0, approxangle)
		else

			rightshoulder.DesiredAngle = math.pi
			leftshoulder.DesiredAngle = -math.pi

			--- rightshoulder.C0 = rightshoulderc0 * CFrame.fromOrientation(0, 0, math.pi)
			--- leftshoulder.C0 = leftshoulderc0 * CFrame.fromOrientation(0, 0, -math.pi)
		end
		righthip.DesiredAngle = addhipangle
		lefthip.DesiredAngle = addhipangle

		--- righthip.C0 = lefthipc0 * CFrame.fromOrientation(0, 0, addhipangle)
		--- lefthip.C0 = righthipc0 * CFrame.fromOrientation(0, 0, -addhipangle)

		return
	end

	--- walk cycle
	local amplitude, frequency
	
	if state == "idle" then
		amplitude = 0.1
		frequency = 1
	else
		rightshoulder.MaxVelocity = 0.25
		leftshoulder.MaxVelocity = 0.25

		--- rightshoulder:SetAttribute(maxvelocityflag, 0.15)
		--- leftshoulder:SetAttribute(maxvelocityflag, 0.15)

		amplitude = 1 * (crouched and 0.5 or 1)
		frequency = freq * (crouched and 0.5 or 1) --- [6, 9, 12]
	end

	local desiredangle = amplitude * math.sin(elapsed * frequency)

	local crouchpadding = 1
	local crouchswing = 0
	if crouched then
		rightshoulder.MaxVelocity = 0.333
		leftshoulder.MaxVelocity = 0.333

		crouchpadding = 0.050
		crouchswing = 1 * math.pi/2
	end

	rightshoulder.DesiredAngle = (crouchpadding * desiredangle) - crouchswing
	leftshoulder.DesiredAngle = (crouchpadding * desiredangle) + crouchswing
	righthip.DesiredAngle = -(desiredangle - addhipangle)
	lefthip.DesiredAngle = -(desiredangle + addhipangle)

	--- rightshoulder.C0 = rightshoulderc0 * CFrame.fromOrientation(0, 0, crouchpadding * desiredangle)
	--- leftshoulder.C0 = leftshoulderc0 * CFrame.fromOrientation(0, 0, crouchpadding * desiredangle)
	--- righthip.C0 = lefthipc0 * CFrame.fromOrientation(0, 0, -(desiredangle - addhipangle))
	--- lefthip.C0 = righthipc0 * CFrame.fromOrientation(0, 0, -(desiredangle + addhipangle))

	--[[
	if toolpose == "none" then

	elseif toolpose == "right" then
		rightshoulder.Transform = CFrame.fromOrientation(0, 0, math.pi/2)
	elseif toolpose == "left" then
		leftshoulder.Transform = CFrame.fromOrientation(0, 0, -math.pi/2)
	elseif toolpose == "both" then
		rightshoulder.Transform = CFrame.fromOrientation(0, 0, math.pi/2)
		leftshoulder.Transform = CFrame.fromOrientation(0, 0, -math.pi/2)
	end]]
end
