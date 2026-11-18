-- Server-run duel opponent. Each simulation step it sets the same move, jump and
-- fire inputs a player can send, so it obeys the same movement and fire-rate rules.
local Combat=require(script.Parent.Combat)
local Bots=require(game.ReplicatedStorage.NOVA.Bots)
local Bot={}

local function brainFor(body,level)
    if body.brain then return body.brain end
    local random=Random.new()
    local brain={random=random,clock=0,axis=0,moveIn=0,noSight=0,lastX=body.x,seen={},seekIn=0,avoid=0,seekTime=0}
    brain.fireIn=level.react+level.fire*(0.5+random:NextNumber())
    body.brain=brain
    return brain
end

-- Nearest open spot around the bot with a clear shot at the target, as an offset.
-- Jumps reach about six tiles, so spots above count; walls on the way are handled
-- by the caller backing off and trying again.
function Bot.vantage(sim,body,target)
    local map,cfg=sim.map,sim.cfg
    local best,bestCost
    for dy=0,-6,-1 do
        for dx=-10,10 do
            local x,y=body.x+dx,body.y+dy
            local cost=math.abs(dx)+0.6*math.abs(dy)
            if (not bestCost or cost<bestCost) and x>0.5 and x<map.width-0.5 and y>0.5 then
                local open=true
                for _,r in map.body do
                    if x+0.45>r.x and x-0.45<r.x2 and y+0.45>r.y and y-0.45<r.y2 then open=false;break end
                end
                if open and Combat.sight(map,cfg,x,y,target.x,target.y) then best,bestCost={dx=dx,dy=dy},cost end
            end
        end
    end
    return best
end

function Bot.step(sim,seat,dt)
    local level=Bots.levels[sim.seats[seat].level]
    local body,target=sim.bodies[seat],sim.bodies[3-seat]
    local brain=brainFor(body,level)
    local random=brain.random
    brain.clock+=dt
    local sight=Combat.sight(sim.map,sim.cfg,body.x,body.y,target.x,target.y)
    brain.noSight=sight and 0 or brain.noSight+dt

    -- Movement: short strafes, reversing at walls and closing in when the shot is blocked.
    brain.moveIn-=dt
    local blocked=brain.axis~=0 and math.abs(body.x-brain.lastX)<1e-4
    brain.lastX=body.x
    local chasing=brain.noSight>level.chase
    if brain.moveIn<=0 or blocked then
        brain.moveIn=0.4+1.1*random:NextNumber()
        if blocked then
            brain.axis=-brain.axis
            body.jump=true
            brain.avoid=0.9
        elseif brain.avoid<=0 and random:NextNumber()<level.pause then brain.axis=0
        elseif chasing and math.abs(target.x-body.x)>1 then brain.axis=target.x>body.x and 1 or -1
        else brain.axis=random:NextNumber()<0.5 and -1 or 1 end
    end
    local axis=brain.axis
    -- With no clear shot for a while, head for the nearest spot that has one.
    brain.avoid-=dt;brain.seekIn-=dt
    if chasing then
        if brain.seekIn<=0 then
            brain.seekIn=0.3
            brain.seek=Bot.vantage(sim,body,target)
        end
        local seek=brain.seek
        if seek and brain.avoid<=0 then
            axis=math.abs(seek.dx)>0.3 and (seek.dx>0 and 1 or -1) or 0
            brain.axis=axis
            if seek.dy<-0.5 and body.grounded then body.jump=true end
            -- A spot it cannot actually reach: roam for a few seconds, then look again.
            brain.seekTime+=dt
            if brain.seekTime>4 then brain.seekTime=0;brain.avoid=3 end
        elseif body.grounded and random:NextNumber()<1.5*dt then body.jump=true end
    else brain.seek=nil;brain.seekTime=0 end
    if body.grounded and (random:NextNumber()<level.hop*dt or chasing and target.y<body.y-1.5 and random:NextNumber()<2*dt) then
        body.jump=true
    end

    -- Dodging: each incoming shot is noticed once, by chance, after a reaction delay.
    local seen={}
    for _,bullet in sim.bullets do
        if bullet.seat~=seat then
            local note=brain.seen[bullet.id] or {at=brain.clock+level.react,aware=random:NextNumber()<level.dodge}
            seen[bullet.id]=note
            if note.aware and brain.clock>=note.at then
                local speed=bullet.vx*bullet.vx+bullet.vy*bullet.vy
                local t=speed>0 and ((body.x-bullet.x)*bullet.vx+(body.y-bullet.y)*bullet.vy)/speed or -1
                if t>0 and t<0.9 then
                    local cx,cy=bullet.x+bullet.vx*t,bullet.y+bullet.vy*t
                    if math.abs(cx-body.x)<0.9 and math.abs(cy-body.y)<0.95 then
                        -- Jump over flat shots; step out from under steep ones.
                        if math.abs(bullet.vy)<math.abs(bullet.vx)*0.7 and body.grounded then body.jump=true
                        else axis=body.x>=cx and 1 or -1 end
                    end
                end
            end
        end
    end
    brain.seen=seen
    body.axis=axis

    brain.fireIn-=dt
    if brain.fireIn<=0 then
        if sight or random:NextNumber()>=level.patience then
            brain.fireIn=level.fire*(0.7+0.6*random:NextNumber())
            Combat.fire(sim,seat,body.lastShot+1,math.rad(level.spread)*(2*random:NextNumber()-1))
        else brain.fireIn=0.25 end
    end
end

return Bot
