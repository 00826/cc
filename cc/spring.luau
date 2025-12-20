--!strict
--!native

--- ### spring.luau
---
--- de-ooped spring module \
--- pulled from `PlayerModule/CameraModule/ZoomController/init.luau`
local spring = {}

--- creates a spring
function spring.create(frequency: number, distance: number, mindistance: number, maxdistance: number)
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
function spring.step(s: typeof(spring.create(...)), dt: number)
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

return spring