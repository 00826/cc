--!strict
--!native

--- ### interpolation.luau
---
--- character interpolation interface \
--- for saving resources (expensive cframe pivot/lerps) when moving replicated characters
local interpolation = {
	--- base value for resolving framerate-independent interpolant `1 - (base ^ dt)`
	base = 10e-11;
	frame = 0;
	maxframe = 0;
	--- breakpoints set by `interpolation.breakpointset()`
	breakpoints = {} :: {{ distance: number, interpolate: boolean, frame: number }};

	--- interpolation target pivot motor6d part0
	targetmotorpart0 = workspace.Terrain;
	--- table of interpolation targets \
	--- keyed by `tostring(userid)`
	targets = {} :: {[string]: { character: Model, motor: Motor6D }};
}

--- creates an interpolation target with a `Motor6D` for applying transforms (`character:PivotTo()`)
function interpolation.createtarget(character: Model)
	local motor6d = Instance.new("Motor6D")
	motor6d.Name = "PivotMotor"
	motor6d.Part0 = interpolation.targetmotorpart0
	motor6d.Part1 = character.PrimaryPart
	motor6d.Parent = character.PrimaryPart

	return {
		character = character;
		motor = motor6d;
	}
end

--- destroys `t.character` and calls `table.clear(t)`
function interpolation.targetdestroy(key: keyof<typeof(interpolation.targets)>)
	local t = interpolation.targets[key]
	if t then
		t.character:Destroy()
		table.clear(t)
		interpolation.targets[key] = nil
	end
end

--- creates an interpolation breakpoint instruction \
--- `number distance:` distance when this breakpoint will be applied \
--- `boolean interpolate:` will character be interpolated or directly pivoted \
--- `number frame:` frame frame when character model will actually be pivoted (for example 2 will pivot the character every 2 frames, 3 will pivot every 3 frames etc)
function interpolation.createbreakpoint(distance: number, interpolate: boolean, frame: number)
	return {
		distance = distance;
		interpolate = interpolate;
		frame = frame;
	}
end

--- internal `table.sort()` function for `interpolation.breakpointset(...)` \
--- sorts by distance in ascending order
function interpolation.breakpointcomp(a: typeof(interpolation.createbreakpoint(...)), b: typeof(interpolation.createbreakpoint(...)))
	return a.distance < b.distance
end

--- advances interpolation forward by 1, resetting if it exceeds the maximum
function interpolation.step()
	interpolation.frame += 1
	
	local frame = interpolation.frame
	if frame % interpolation.maxframe == 0 then
		interpolation.frame = 0
	end

	return frame
end

--- sets interpolation breakpoints and maxframe \
--- breakpoint frames are intended to divide evenly into the highest maximum replication frame and otherwise may cause inconsistencies
function interpolation.breakpointset(t: { typeof(interpolation.createbreakpoint(...)) })
	table.sort(t, interpolation.breakpointcomp)

	table.clear(interpolation.breakpoints)
	table.move(t, 1, #t, 1, interpolation.breakpoints)

	interpolation.maxframe = 0
	for _, breakpoint in ipairs(interpolation.breakpoints) do
		if interpolation.maxframe < breakpoint.frame then
			interpolation.maxframe = breakpoint.frame
		end
	end
end

--- returns breakpoint wrt distance from interpolation target
function interpolation.breakpointresolve(distance: number)
	for i, breakpoint in ipairs(interpolation.breakpoints) do
		if distance < breakpoint.distance then
			return breakpoint
		end
	end

	return interpolation.breakpoints[#interpolation.breakpoints] or { distance = math.huge, interpolate = false, frame = 1 }
end

--- returns framerate-independent interpolant
function interpolation.interpolant(dt: number)
	return 1 - (interpolation.base ^ dt)
end

return interpolation