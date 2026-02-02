--!strict

local RunService = game:GetService("RunService")

type extrapolatestepresult = {
	extrapolate: (number) -> CFrame;
	translationvelocity: Vector3;
	rotationvelocity: Vector3;
}

--- ### viewport.luau
---
--- viewport query functions
local viewport = {
	--- camera object used by this module
	camera = workspace.CurrentCamera;

	fieldofviewconnection = nil :: RBXScriptConnection?;
	viewportsizeconnection = nil :: RBXScriptConnection?;
	nearplanezconnection = nil :: RBXScriptConnection?;

	--- viewport projection x
	projectionx = 0;
	--- viewport projection y
	projectiony = 0;
	--- near plane z
	nearplanez = -0.1;

	--- raycast limit when querying collision points
	querypointcastlimit = 64;
	--- offsets used to test for soft limits
	querysampleoffsets = {
		Vector2.new(0.4, 0.0),
		Vector2.new(-0.4, 0.0),
		Vector2.new(0.0, -0.4),
		Vector2.new(0.0, 0.4),
		Vector2.new(0.0, 0.2),
	};

	--- clip through baseparts with a transparency below this value
	transparencylimit = 0.25;

	--- whitelist raycast params
	whitelistparams = RaycastParams.new();
	--- raycastparam whitelist
	whitelist = table.create(16);

	--- whitelist raycast params
	blacklistparams = RaycastParams.new();
	--- raycastparam blacklist
	blacklist = table.create(16);
}

function viewport.cast(focus: CFrame, targetdistance: number, extrapolatorresult: extrapolatestepresult)
	local realdistance = targetdistance

	local softlimit, hardlimit = viewport.queryviewport(focus, targetdistance)
	if hardlimit < realdistance then
		realdistance = hardlimit
	end
	if softlimit < realdistance and viewport.testpromotion(focus, targetdistance, extrapolatorresult) then
		realdistance = softlimit
	end

	return realdistance
end

function viewport.getcollisionpoint(origin: Vector3, direction: Vector3)
	viewport.blacklistparams.FilterDescendantsInstances = viewport.blacklist
	repeat
		local result = workspace:Raycast(origin, direction, viewport.blacklistparams)

		if result then
			if result.Instance.CanCollide then
				return result.Position, true
			end
			viewport.blacklistparams:AddToFilter(result.Instance)
		end
	until not result

	return origin + direction, false
end

function viewport.querypoint(origin: Vector3, unit: Vector3, dist: number, lastposition: Vector3?)
	debug.profilebegin("cc_querypoint")

	local blacklistparams = viewport.blacklistparams
	local whitelistparams = viewport.whitelistparams

	local nearplanez = viewport.nearplanez

	dist += nearplanez
	local target = origin + unit*dist

	local softlimit = math.huge
	local hardlimit = math.huge
	local movingorigin = origin

	local piercecount = 0
	
	blacklistparams.FilterDescendantsInstances = viewport.blacklist
	repeat
		local entryresult = workspace:Raycast(movingorigin, target - movingorigin, blacklistparams)

		if not entryresult then
			break
		end

		piercecount += 1

		local entryinstance, entryposition = entryresult.Instance, entryresult.Position
		local lim = (entryposition - origin).Magnitude

		if piercecount >= viewport.querypointcastlimit then
			hardlimit = lim
		elseif viewport.canocclude(entryinstance) then
			whitelistparams.FilterDescendantsInstances = { entryinstance }

			local exitresult = workspace:Raycast(target, entryposition - target, whitelistparams)
			if exitresult then
				local promote = if lastposition then
					(workspace:Raycast(lastposition, target - lastposition, whitelistparams) or
						workspace:Raycast(target, lastposition - target, whitelistparams)) else false

				if promote then
					--- Ostensibly a soft limit, but the camera has passed through it in the last frame, so promote to a hard limit.
					hardlimit = lim
				elseif dist < softlimit then
					--- Trivial soft limit
					softlimit = lim
				end
			else
				--- Trivial hard limit
				hardlimit = lim
			end
		end

		blacklistparams:AddToFilter(entryinstance)
		movingorigin = entryposition - unit*1e-3
	until hardlimit < math.huge or not entryinstance

	debug.profileend()
	return softlimit - nearplanez, hardlimit - nearplanez
end

function viewport.queryviewport(focus: CFrame, distance: number)
	debug.profilebegin("cc_queryviewport")

	local focusposition = focus.Position
	local focusrightvector = focus.RightVector
	local focusupvector = focus.UpVector
	local focuslookvector = -focus.LookVector

	local projectionx = viewport.projectionx
	local nearplanez = viewport.nearplanez
	
	local camera = viewport.camera
	local viewportsize = camera.ViewportSize

	local hardboxlimit = math.huge
	local softboxlimit = math.huge

	--- Center the viewport on the PoI, sweep points on the edge towards the target, and take the minimum limits
	for viewX = 0, 1 do
		local worldX = focusrightvector*((viewX - 0.5)*projectionx)

		for viewY = 0, 1 do
			local worldY = focusupvector*((viewY - 0.5)*projectionx)

			local origin = focusposition + nearplanez*(worldX + worldY)
			local lastpos = camera:ViewportPointToRay(
				viewportsize.X*viewX,
				viewportsize.Y*viewY
			).Origin

			local softpointlimit, hardpointlimit = viewport.querypoint(origin, focuslookvector, distance, lastpos)

			if hardpointlimit < hardboxlimit then
				hardboxlimit = hardpointlimit
			end
			if softpointlimit < softboxlimit then
				softboxlimit = softpointlimit
			end
		end
	end
	debug.profileend()

	return softboxlimit, hardboxlimit
end

function viewport.testpromotion(focus: CFrame, distance: number, extrapolatestepresult: extrapolatestepresult)
	debug.profilebegin("cc_testpromotion")

	local focusposition = focus.Position
	local focusrightvector = focus.RightVector
	local focusupvector = focus.UpVector
	local focuslookvector = -focus.LookVector

	do
		--- Dead reckoning the camera rotation and focus
		debug.profilebegin("cc_extrapolate")

		local sampledeltatime = 0.0625
		local samplemaxtime = 1.25

		local translationvelocity = extrapolatestepresult.translationvelocity
		local rotationvelocity = extrapolatestepresult.rotationvelocity

		local maxdistance = (viewport.getcollisionpoint(focusposition, translationvelocity*samplemaxtime) - focusposition).Magnitude
		--- Metric that decides how many samples to take
		local combinedspeed = vector.magnitude(translationvelocity::any)

		for dt = 0, math.min(samplemaxtime, vector.magnitude(rotationvelocity::any) + maxdistance/combinedspeed), sampledeltatime do
			local extrapolatedcframewrtdt = extrapolatestepresult.extrapolate(dt) --- Extrapolated CFrame at time dt

			if viewport.querypoint(extrapolatedcframewrtdt.Position, -extrapolatedcframewrtdt.LookVector, distance) >= distance then
				return false
			end
		end

		debug.profileend()
	end

	do
		--- Test screen-space offsets from the focus for the presence of soft limits
		debug.profilebegin("cc_testoffsets")

		for _, offset in ipairs(viewport.querysampleoffsets) do
			local pos = viewport.getcollisionpoint(focusposition, focusrightvector*offset.X + focusupvector*offset.Y)
			if viewport.querypoint(pos, vector.normalize(focusposition::any + focuslookvector*distance - pos)::any, distance) == math.huge then
				return false
			end
		end

		debug.profileend()
	end

	debug.profileend()
	return true
end

function viewport.setcamera(camera: Camera)
	viewport.camera = camera

	viewport.projectionchanged(camera)

	if viewport.fieldofviewconnection then
		viewport.fieldofviewconnection:Disconnect()
		viewport.fieldofviewconnection = nil
	end
	viewport.fieldofviewconnection = camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
		viewport.projectionchanged(camera)
	end)

	if viewport.viewportsizeconnection then
		viewport.viewportsizeconnection:Disconnect()
		viewport.viewportsizeconnection = nil
	end
	viewport.viewportsizeconnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		viewport.projectionchanged(camera)
	end)

	if viewport.nearplanezconnection then
		viewport.nearplanezconnection:Disconnect()
		viewport.nearplanezconnection = nil
	end
	viewport.fieldofviewconnection = camera:GetPropertyChangedSignal("NearPlaneZ"):Connect(function()
		viewport.nearplanez = camera.NearPlaneZ
	end)
end

function viewport.projectionchanged(camera: Camera)
	local fieldofviewradians = math.rad(camera.FieldOfView)
	local viewportsize = camera.ViewportSize
	local ar = viewportsize.X / viewportsize.Y

	local y = 2 * math.tan(fieldofviewradians * 0.5)
	local x = ar * y

	viewport.projectiony = y
	viewport.projectionx = x
end

function viewport.gettotaltransparency(part: BasePart)
	return 1 - (1 - part.Transparency) * (1 - part.LocalTransparencyModifier)
end

function viewport.canocclude(part: BasePart)
	-- Occluders must be:
	-- 1. Opaque
	-- 2. Interactable
	-- 3(x). Not in the same assembly as the subject

	return
		viewport.gettotaltransparency(part) < viewport.transparencylimit and
		part.CanCollide and
		--- subjectRoot ~= (part:GetRootPart() or part) and
		not part:IsA("TrussPart")
end

if RunService:IsClient() then
	local whitelistparams = viewport.whitelistparams
	whitelistparams.FilterType = Enum.RaycastFilterType.Include
	whitelistparams.FilterDescendantsInstances = viewport.whitelist
	
	local blacklistparams = viewport.blacklistparams
	blacklistparams.FilterType = Enum.RaycastFilterType.Exclude
	blacklistparams.FilterDescendantsInstances = viewport.blacklist

	viewport.setcamera(viewport.camera)
end

return viewport