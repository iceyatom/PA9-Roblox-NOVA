local Movement = {}
local EPS = 1e-7

function Movement.body(center, cfg)
    return {x=center.X, y=center.Y, vy=0, axis=0, fast=false, jump=false,
        grounded=false, pad=false, hp=cfg.Health, lastShot=0}
end

-- Sweep one axis to the first contacting face. Parallel travel along a face stays clear.
local function moveAxis(body, other, map, cfg, axis, delta)
    local horizontal = axis == "x"
    local cross = horizontal and body.y or body.x
    local half = (horizontal and cfg.BodyWidth or cfg.BodyHeight)/2
    local side = (horizontal and cfg.BodyHeight or cfg.BodyWidth)/2
    local from = body[axis]
    local bound = horizontal and map.width or map.height
    local dest = math.clamp(from + delta, half, bound-half)
    local blocked = dest ~= from + delta
    local function clip(low,high,crossLow,crossHigh)
        if cross+side <= crossLow+EPS or cross-side >= crossHigh-EPS then return end
        if delta > 0 and from+half <= low+EPS and dest+half >= low then
            dest,blocked = math.min(dest,low-half),true
        elseif delta < 0 and from-half >= high-EPS and dest-half <= high then
            dest,blocked = math.max(dest,high+half),true
        end
    end
    for _,r in map.body do
        if horizontal then clip(r.x,r.x2,r.y,r.y2) else clip(r.y,r.y2,r.x,r.x2) end
    end
    if other then
        local center = other[axis]
        local mid = horizontal and other.y or other.x
        clip(center-half,center+half,mid-side,mid+side)
    end
    body[axis] = dest
    return blocked
end

function Movement.step(b, other, map, cfg, dt)
    if b.jump and b.grounded then b.vy = -cfg.Jump; b.grounded = false end
    b.jump = false
    moveAxis(b,other,map,cfg,"x",b.axis*cfg.Speed*dt)
    local accel = cfg.Gravity + (b.fast and not b.grounded and cfg.FastFall or 0)
    b.vy = math.min(cfg.MaxFall,b.vy + accel*dt)
    local falling = b.vy > 0
    local hit = moveAxis(b,other,map,cfg,"y",b.vy*dt)
    b.grounded = hit and falling
    if hit then b.vy = 0 end
    local contact = false
    for _,r in map.pads do
        if b.x+cfg.BodyWidth/2 > r.x and b.x-cfg.BodyWidth/2 < r.x2
            and b.y+cfg.BodyHeight/2 >= r.y and b.y-cfg.BodyHeight/2 < r.y2 then
            contact = true
            break
        end
    end
    if contact and not b.pad then b.vy = -cfg.Launch; b.grounded = false end
    b.pad = contact
end
return Movement
