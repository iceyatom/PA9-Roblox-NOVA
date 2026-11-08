local Shared = game.ReplicatedStorage.NOVA
local Movement = require(script.Parent.Movement)
local Combat = require(script.Parent.Combat)
local Match = {}
Match.__index = Match

function Match.new(map,cfg)
    local self = setmetatable({map=map,cfg=table.clone(cfg),seats={},round=0,stepNumber=0},Match)
    self:reset("Waiting")
    return self
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
    if self.seats[3-seat] then self:reset("Countdown") else self:reset("Waiting") end
    return seat
end

function Match:finish(winner,reason)
    if self.phase ~= "Playing" then return end
    self.phase,self.winner,self.reason,self.bullets,self.votes = "Results",winner,reason,{},{}
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
        if self.votes[3-seat] then self:reset("Countdown") end
        return true
    end
    if self.phase ~= "Playing" then return false end
    local body = self.bodies[seat]
    if kind == "fire" then return Combat.fire(self,seat,a) end
    if kind == "jump" then body.jump = true; return true end
    if kind == "move" and (a == -1 or a == 0 or a == 1) and typeof(b) == "boolean" then
        body.axis,body.fast = a,b
        return true
    end
    return false
end

function Match:step(dt)
    if self.phase == "Countdown" then
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
