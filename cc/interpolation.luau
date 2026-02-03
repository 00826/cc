--!strict
--!native

--- ### interpolation.luau
---
--- character interpolation interface \
--- for saving resources (expensive cframe pivot/lerps) when moving replicated characters \
--- breakpoint cycles are intended to divide evenly into `interpolation.maxcycle` otherwise may cause inconsistencies
local interpolation = {
	--- base value for resolving framerate-independent interpolant `1 - (base ^ dt)`
	base = 10e-11;
	cycle = 0;
	maxcycle = 60;
	--- breakpoints set by `interpolation.breakpointset()`
	breakpoints = {};

	--- directly pivot instead of lerping if distance between replicated character and replication focus is larger than this value
	maxdistance = math.huge;
}

--- creates an interpolation breakpoint instruction \
--- `number distance:` distance when this breakpoint will be applied \
--- `boolean interpolate:` will character be interpolated or directly pivoted \
--- `number cycle:` frame cycle when character model will actually be pivoted (for example 2 will pivot the character every 2 frames, 3 will pivot every 3 frames etc)
function interpolation.createbreakpoint(distance: number, interpolate: boolean, cycle: number)
	return {
		distance = distance;
		interpolate = interpolate;
		cycle = cycle;
	}
end

--- internal `table.sort()` function for `interpolation.breakpointset(...)` \
--- sorts by distance in ascending order
function interpolation.breakpointcomp(a: typeof(interpolation.createbreakpoint(...)), b: typeof(interpolation.createbreakpoint(...)))
	return a.distance < b.distance
end

--- sets interpolation breakpoints
function interpolation.breakpointset(t: { typeof(interpolation.createbreakpoint(...)) })
	table.sort(t, interpolation.breakpointcomp)

	table.clear(interpolation.breakpoints)
	table.move(t, 1, #t, 1, interpolation.breakpoints)
end

--- returns breakpoint wrt distance from interpolation target
function interpolation.breakpointresolve(distance: number)
	for i, breakpoint in ipairs(interpolation.breakpoints) do
		if distance < breakpoint.distance then
			return breakpoint
		end
	end

	return interpolation.breakpoints[#interpolation.breakpoints] or { distance = math.huge, interpolate = false, cycle = 1 }
end

--- returns framerate-independent interpolant
function interpolation.i(dt: number)
	return 1 - (interpolation.base ^ dt)
end

return interpolation