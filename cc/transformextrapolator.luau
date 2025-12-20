--!strict

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

--- ### transformextrapolator.luau
---
--- cframe transform extrapolator
local transformextrapolator = {}

--- creates a transform extrapolator
function transformextrapolator.create()
	return {
		lastcframe = nil :: CFrame?;
	}
end

--- advances transform extrapolator `t` by `dt` wrt `cframe`, returning a table with translation/rotation velocities and an extrapolator function
function transformextrapolator.step(t: typeof(transformextrapolator.create()), dt: number, cframe: CFrame)
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
function transformextrapolator.reset(t: typeof(transformextrapolator.create()))
	t.lastcframe = nil
end

return transformextrapolator