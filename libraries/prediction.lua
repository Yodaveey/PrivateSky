--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
--[[
	Prediction Library
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]
local module = {}
local eps = 1e-9
local cloneref = cloneref or function(ref) return ref end
local tweenService = cloneref(game:GetService('TweenService'))
local statsService = cloneref(game:GetService('Stats'))

-- Acceleration tracking: stores {velocity, timestamp} per target rootpart reference
local velocityHistory = setmetatable({}, { __mode = 'k' })

local function isZero(d)
	return (d > -eps and d < eps)
end

-- Returns the local player's network ping in seconds
local function getPing()
	local ok, ping = pcall(function()
		return statsService.Network.ServerStatsItem['Data Ping']:GetValue()
	end)
	return (ok and ping or 0) / 1000
end

-- Returns the current acceleration vector for a target part, and stores history
local function getAcceleration(rootPart, currentVelocity)
	local now = os.clock()
	local history = velocityHistory[rootPart]
	local accel = Vector3.zero
	if history then
		local dt = now - history.t
		if dt > 0 and dt < 0.5 then
			accel = (currentVelocity - history.v) / dt
		end
	end
	velocityHistory[rootPart] = { v = currentVelocity, t = now }
	return accel
end

local tracer = Instance.new('Part')
tracer.Anchored = true
tracer.CanCollide = false
tracer.CanQuery = false
tracer.CanTouch = false
tracer.CastShadow = false

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local s0, s1

	local p, q, D

	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q

	if isZero(D) then
		s0 = -p
		return s0
	elseif (D < 0) then
		return
	else -- if (D > 0)
		local sqrt_D = math.sqrt(D)

		s0 = sqrt_D - p
		s1 = -sqrt_D - p
		return s0, s1
	end
end

local function solveCubic(c0, c1, c2, c3)
	local s0, s1, s2

	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0

	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

	cb_p = p * p * p
	D = q * q + cb_p

	if isZero(D) then
		if isZero(q) then -- one triple solution
			s0 = 0
			num = 1
		else -- one single and one double solution
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then -- Casus irreducibilis: three real solutions
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)

		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else -- one real solution
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)

		s0 = u + v
		num = 1
	end

	sub = (1 / 3) * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	local s0, s1, s2, s3

	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0

	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	if isZero(r) then
		coeffs[3] = q
		coeffs[2] = p
		coeffs[1] = 0
		coeffs[0] = 1

		local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0

		u = z * z - r
		v = 2 * z - p

		if isZero(u) then
			u = 0
		elseif (u > 0) then
			u = math.sqrt(u)
		else
			return
		end
		if isZero(v) then
			v = 0
		elseif (v > 0) then
			v = math.sqrt(v)
		else
			return
		end

		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1

		do
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = #results
			s0, s1 = results[1], results[2]
		end

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1

		if (num == 0) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s0, s1 = results[1], results[2]
		end
		if (num == 1) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s1, s2 = results[1], results[2]
		end
		if (num == 2) then
			local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
			num = num + #results
			s2, s3 = results[1], results[2]
		end
	end

	sub = 0.25 * A

	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end
	if (num > 3) then s3 = s3 - sub end

	return {s3, s2, s1, s0}
end

function module.SpawnTracer(from, to, custom)
    local distance = (to - from).Magnitude
    if distance < 0.01 then return end

    local t = tracer:Clone()
    t.Color = custom.Color
    t.Size = vector.create(custom.Thick, custom.Thick, distance)
    t.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
    t.Material = custom.Material
	t.Transparency = custom.Opacity or 0

   	if custom.Fade then
		tweenService:Create(t, TweenInfo.new(custom.Lifetime), {
			Transparency = 1
		}):Play()
	end
    return t
end

function module.SpawnArcTracer(origin, aimDirection, projectileSpeed, gravity, travelTime, steps, custom)
    steps = steps or 20
    local stepTime = travelTime / steps
    local g = Vector3.new(0, -gravity, 0)
    local velocity = aimDirection * projectileSpeed

    local prevPos = origin
    local model = Instance.new('Model')
    model.Parent = workspace.Terrain
	if custom.Material == Enum.Material.Glass then
		Instance.new('Highlight', model).Enabled = false
	end
    for i = 1, steps do
        local t = i * stepTime
        local nextPos = origin + velocity * t + 0.5 * g * t * t
        local l = module.SpawnTracer(prevPos, nextPos, custom)
        l.Parent = model
        prevPos = nextPos
    end
	task.delay(custom.Lifetime, model.Destroy, model)
end
-- SolveTrajectory: upgraded with ping compensation, kinematic gravity, and acceleration tracking
-- rootPart (optional) - pass the target's RootPart instance to enable acceleration tracking
function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params, rootPart, pingOverride)
	-- ── 1. PING COMPENSATION ──────────────────────────────────────────────────
	-- Extrapolate the target's position forward by our latency so the server
	-- sees them where we're aiming, not where we saw them on our client.
	local ping = pingOverride or getPing()

	-- ── 2. ACCELERATION / CURVE TRACKING ─────────────────────────────────────
	-- If we have the actual RootPart, we can compute how fast velocity is
	-- changing (i.e. they're turning or juking) and account for the curve.
	local accel = Vector3.zero
	if rootPart then
		accel = getAcceleration(rootPart, targetVelocity)
		-- Clamp acceleration magnitude so extreme jank doesn't throw us off
		local accelMag = accel.Magnitude
		if accelMag > 150 then
			accel = accel * (150 / accelMag)
		end
	end

	-- Apply ping extrapolation + half-acceleration nudge for curved paths.
	-- pos(t) = p₀ + v₀t + ½at²  — evaluated at t=ping for the initial nudge
	local pingPos = targetPos
		+ targetVelocity * ping
		+ 0.5 * accel * (ping * ping)

	-- ── 3. FLOOR / GROUNDED CHECK ─────────────────────────────────────────────
	-- If the target is on the ground (and not jumping), zero out vertical vel
	-- so we don't shoot under the floor.
	local adjustedVelocity = targetVelocity
	local floorRay = workspace:Raycast(pingPos, Vector3.new(0, -(playerHeight or 2) - 0.5, 0), params)
	if floorRay and adjustedVelocity.Y <= 0.1 then
		adjustedVelocity = Vector3.new(adjustedVelocity.X, 0, adjustedVelocity.Z)
		pingPos = Vector3.new(pingPos.X, floorRay.Position.Y + (playerHeight or 2), pingPos.Z)
	end

	-- ── 4. KINEMATIC GRAVITY PREDICTION ─────────────────────────────────────
	-- Replaces the old broken loop. If the target is airborne (Y velocity != 0
	-- and playerGravity is set), we iteratively refine the intercept point
	-- by solving where the target will be when the projectile arrives.
	-- We do 3 passes which converges fast enough for any realistic scenario.
	if math.abs(adjustedVelocity.Y) > 0.1 and playerGravity and playerGravity > 0 then
		-- Rough initial time estimate: straight-line distance over speed
		local estimatedTime = (pingPos - origin).Magnitude / projectileSpeed

		for _ = 1, 3 do
			-- Kinematic: target's predicted Y pos at estimatedTime
			-- posY = startY + vy*t - ½*g*t²
			local predictedY = pingPos.Y
				+ adjustedVelocity.Y * estimatedTime
				- 0.5 * playerGravity * (estimatedTime * estimatedTime)

			local predictedPos = Vector3.new(
				pingPos.X + adjustedVelocity.X * estimatedTime + 0.5 * accel.X * (estimatedTime * estimatedTime),
				predictedY,
				pingPos.Z + adjustedVelocity.Z * estimatedTime + 0.5 * accel.Z * (estimatedTime * estimatedTime)
			)

			-- Floor clamp — don't predict them below the ground
			local floorCheck = workspace:Raycast(
				predictedPos + Vector3.new(0, 2, 0),
				Vector3.new(0, -(playerHeight or 2) - 4, 0),
				params
			)
			if floorCheck then
				predictedPos = Vector3.new(
					predictedPos.X,
					floorCheck.Position.Y + (playerHeight or 2),
					predictedPos.Z
				)
			end

			-- Refine the time estimate using the new predicted distance
			estimatedTime = (predictedPos - origin).Magnitude / projectileSpeed

			-- On the last pass, commit the predicted position as our new target
			if _ == 3 then
				pingPos = predictedPos
				-- zero out Y velocity since we've baked it into the position
				adjustedVelocity = Vector3.new(adjustedVelocity.X, 0, adjustedVelocity.Z)
			end
		end
	end

	-- ── 5. SOLVE THE QUARTIC ──────────────────────────────────────────────────
	-- Now solve for the exact intercept time using the projectile physics equation.
	-- We factor in the remaining (horizontal) velocity of the target and gravity
	-- drop of the projectile simultaneously.
	local disp = pingPos - origin
	local p = adjustedVelocity.X + accel.X * 0.016
	local q = adjustedVelocity.Y
	local r = adjustedVelocity.Z + accel.Z * 0.016
	local h, j, k = disp.X, disp.Y, disp.Z
	local l = -0.5 * gravity

	local solutions = module.solveQuartic(
		l * l,
		-2 * q * l,
		q * q - 2 * j * l - projectileSpeed * projectileSpeed + p * p + r * r,
		2 * j * q + 2 * h * p + 2 * k * r,
		j * j + h * h + k * k
	)

	if solutions then
		local bestT = math.huge
		for _, v in solutions do
			if v > 0 and v < bestT then
				bestT = v
			end
		end

		if bestT < math.huge then
			local t = bestT
			local d = (h + p * t) / t
			local e = (j + q * t - l * t * t) / t
			local f = (k + r * t) / t
			local aimDir = Vector3.new(d, e, f).Unit
			return origin + Vector3.new(d, e, f), aimDir, t
		end
	elseif gravity == 0 then
		local t = disp.Magnitude / projectileSpeed
		local d = (h + p * t) / t
		local e = (j + q * t - l * t * t) / t
		local f = (k + r * t) / t
		return origin + Vector3.new(d, e, f)
	end
end

-- Expose the velocity history table so callers can flush stale entries if needed
module.VelocityHistory = velocityHistory

return module

