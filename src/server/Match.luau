local Movement = require(script.Parent.Movement)
local Combat = require(script.Parent.Combat)
local Match = {}
Match.__index = Match

function Match.new(map,cfg,chooseMap)
    local self = setmetatable({map=map,cfg=table.clone(cfg),chooseMap=chooseMap,seats={},round=0,stepNumber=0},Match)
    self:reset("Waiting")
    return self
end

function Match:startRound()
    if self.chooseMap then
        self.map = self.chooseMap(self.round > 0 and self.map.id or nil)
        self:reset("Selecting")
        self.round += 1
        self.count = self.cfg.MapRollDuration
    else
        self:reset("Countdown")
    end
end

function Match:reset(phase)
    self.bodies = {Movement.body(self.map.spawns[1],self.cfg),Movement.body(self.map.spawns[2],self.cfg)}
    self.phase,self.votes,self.bullets,self.serial,self.winner,self.reason = phase,{}, {},0,nil,nil
    self.count = phase == "Countdown" and self.cfg.Countdown or 0
    if phase == "Countdown" then self.round += 1 end
end

function Match:join(key)
    for i=1,2 do if self.seats[i] == key then return i end end
    local seat = not self.seats[1] and 1 or not self.seats[2] and 2 or nil
    if not seat then return nil end
    self.seats[seat]=key
    if self.seats[3-seat] then self:startRound() else self:reset("Waiting") end
    return seat
end

function Match:finish(winner,reason)
    if self.phase ~= "Playing" then return end
    self.phase,self.winner,self.reason,self.bullets,self.votes = "Results",winner,reason,{},{}
end

-- Find a flat, unobstructed shooting lane for Studio diagnostics.
function Match:duelLane()
    for distance=8,4,-1 do
        for y=1,self.map.height-1 do
            for x=1,self.map.width-distance-2 do
                local clear,left,right=true,false,false
                for _,r in self.map.body do
                    if r.x<x+distance+0.97 and r.x2>x+0.03 and r.y<y and r.y2>y-1 then clear=false end
                    if r.y==y then
                        if r.x<=x+0.5 and r.x2>=x+0.5 then left=true end
                        if r.x<=x+distance+0.5 and r.x2>=x+distance+0.5 then right=true end
                    end
                end
                for _,r in self.map.shot do
                    if r.x<x+distance+0.97 and r.x2>x+0.03 and r.y<y and r.y2>y-1 then clear=false end
                end
                if clear and left and right then return x+0.5,x+distance+0.5,y-0.5 end
            end
        end
    end
end

function Match:depart(seat)
    if not self.seats[seat] then return end
    self.seats[seat] = nil
    if self.phase == "Playing" and self.seats[3-seat] then self:finish(3-seat,"Disconnect")
    else self:reset("Waiting") end
end

function Match:intent(seat,round,kind,a,b)
    if not self.seats[seat] or self.round ~= round then return false end
    if kind == "rematch" and self.phase == "Results" then
        if not self.seats[3-seat] then self:reset("Waiting"); return true end
        self.votes[seat] = true
        if self.votes[3-seat] then self:startRound() end
        return true
    end
    if self.phase ~= "Playing" then return false end
    local body = self.bodies[seat]
    if kind == "fire" then return Combat.fire(self,seat,a) end
    if kind == "jump" then
        if a==nil then
            body.jump=true
        elseif typeof(a)=="boolean" then
            body.jumpHeld=a
            if a then body.jump=true end
        else
            return false
        end
        return true
    end
    if kind == "move" and typeof(a) == "number" and a >= -1 and a <= 1 and (b == nil or typeof(b) == "boolean") then
        body.axis = math.sign(a)
        return true
    end
    return false
end

function Match:step(dt)
    if self.phase == "Selecting" then
        self.count = math.max(0,self.count-dt)
        if self.count < 1e-7 then self.phase="Countdown"; self.count=self.cfg.Countdown end
    elseif self.phase == "Countdown" then
        self.count = math.max(0,self.count-dt)
        if self.count < 1e-7 then self.count=0; self.phase="Playing" end
    elseif self.phase == "Playing" then
        local old = {}
        for i=1,2 do local p=self.bodies[i]; old[i]=Vector2.new(p.x,p.y) end
        self.stepNumber += 1
        local first = self.stepNumber%2+1
        Movement.step(self.bodies[first],self.bodies[3-first],self.map,self.cfg,dt)
        Movement.step(self.bodies[3-first],self.bodies[first],self.map,self.cfg,dt)
        Combat.step(self,dt,old)
        local dead1,dead2 = self.bodies[1].hp == 0,self.bodies[2].hp == 0
        if dead1 or dead2 then self:finish(dead1 and dead2 and 0 or dead1 and 2 or 1,"Elimination") end
    end
end

return Match
