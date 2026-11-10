local Combat = {}

-- Parametric entry time along a segment into an expanded rectangle (slab method).
local function interval(pos, delta, low, high)
    if math.abs(delta) < 1e-10 then
        if pos < low or pos > high then return math.huge,-math.huge end
        return -math.huge,math.huge
    end
    local a,b = (low-pos)/delta,(high-pos)/delta
    return math.min(a,b),math.max(a,b)
end

local function entry(x,y,dx,dy,x0,y0,x1,y1)
    local a,b = interval(x,dx,x0,x1)
    local c,d = interval(y,dy,y0,y1)
    local t = math.max(a,c,0)
    return t <= math.min(b,d,1) and t or math.huge
end

function Combat.fire(sim, seat, sequence)
    local owner,target = sim.bodies[seat],sim.bodies[3-seat]
    if typeof(sequence) ~= "number" or sequence%1 ~= 0 or sequence <= owner.lastShot or sequence > 2147483647 then return false end
    owner.lastShot = sequence
    local dx,dy = target.x-owner.x,target.y-owner.y
    local length = math.sqrt(dx*dx+dy*dy)
    if length < 1e-7 or length ~= length then return false end
    owner.acceptedShots=(owner.acceptedShots or 0)+1
    sim.serial += 1
    local speed = sim.cfg.BulletSpeed
    table.insert(sim.bullets,{id=sim.serial,seat=seat,x=owner.x,y=owner.y,vx=dx/length*speed,vy=dy/length*speed})
    return true
end

function Combat.step(sim,dt,previous)
    local map,cfg = sim.map,sim.cfg
    local radius = cfg.BulletRadius
    local damage = {0,0}
    local keep = 0
    for _,b in sim.bullets do
        local dx,dy = b.vx*dt,b.vy*dt
        local x,y = b.x+dx,b.y+dy
        local targetSeat = 3-b.seat
        local target = sim.bodies[targetSeat]
        local old = previous and previous[targetSeat]
        local ox,oy = old and old.X or target.x,old and old.Y or target.y
        local tx,ty = cfg.BodyWidth/2+radius,cfg.BodyHeight/2+radius
        local hit = entry(b.x,b.y,dx-(target.x-ox),dy-(target.y-oy),ox-tx,oy-ty,ox+tx,oy+ty)
        local wall = math.huge
        for _,r in map.shot do
            wall = math.min(wall,entry(b.x,b.y,dx,dy,r.x-radius,r.y-radius,r.x2+radius,r.y2+radius))
        end
        if hit < wall then
            damage[targetSeat] += 1
        elseif wall == math.huge and x >= 0 and y >= 0 and x <= map.width and y <= map.height then
            keep += 1
            b.x,b.y = x,y
            sim.bullets[keep] = b
        elseif x ~= x or y ~= y then
            warn("NOVA discarded an invalid projectile",b.id)
        end
    end
    for i=#sim.bullets,keep+1,-1 do sim.bullets[i]=nil end
    for i=1,2 do sim.bodies[i].hp=math.max(0,sim.bodies[i].hp-damage[i]) end
end
return Combat
