local Movement = require(script.Parent.Movement)
local Combat = require(script.Parent.Combat)
local Bot = require(script.Parent.Bot)
local Bots = require(game.ReplicatedStorage.NOVA.Bots)
local Match = {}
Match.__index = Match

function Match.new(map,cfg,chooseMap)
    local self = setmetatable({map=map,cfg=table.clone(cfg),chooseMap=chooseMap,seats={},round=0,stepNumber=0},Match)
    self:reset("Waiting")
    return self
end

function Match:startRound()
    if self.session.complete then return false end
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
    if phase=="Waiting" then self.session={wins={0,0},draws=0,played=0,complete=false} end
    self.chestResults={}
    self.bodies = {Movement.body(self.map.spawns[1],self.cfg),Movement.body(self.map.spawns[2],self.cfg)}
    self.phase,self.votes,self.bullets,self.serial,self.winner,self.reason = phase,{}, {},0,nil,nil
    self.rewards={}
    self.xpRecaps={}
    self.questRecaps={}
    self.count = phase == "Countdown" and self.cfg.Countdown or 0
    if phase == "Countdown" then self.round += 1 end
end

function Match:join(key)
    for i=1,2 do if self.seats[i] == key then return i end end
    if self.session.complete then return nil end
    local seat = not self.seats[1] and 1 or not self.seats[2] and 2 or nil
    if not seat then return nil end
    self.seats[seat]=key
    if self.seats[3-seat] then
        self.botDuel=false
        -- A new pairing always starts a fresh session; rematches use startRound directly.
        self.session={wins={0,0},draws=0,played=0,complete=false}
        self:startRound()
    else self:reset("Waiting") end
    return seat
end

function Match:finish(winner,reason)
    if self.phase ~= "Playing" then return end
    self.phase,self.winner,self.reason,self.bullets,self.votes = "Results",winner,reason,{},{}
    local session=self.session
    session.played+=1
    if winner==0 then session.draws+=1 else session.wins[winner]+=1 end
    -- Bot duels have no match limit.
    session.complete=not self.botDuel and session.played>=self.cfg.SessionMatchLimit
    if session.complete then session.remaining=self.cfg.SessionReturnDelay end
    if self.finished then self.finished(self) end
end

-- Snapshot only public session fields; never expose the mutable score table.
function Match:sessionView(now)
    local session=self.session
    return {wins=table.clone(session.wins),draws=session.draws,played=session.played,
        game=self.phase=="Results" and session.played or self.botDuel and session.played+1 or math.min(session.played+1,self.cfg.SessionMatchLimit),
        limit=self.botDuel and 0 or self.cfg.SessionMatchLimit,complete=session.complete,
        returnAt=session.complete and now+session.remaining or nil}
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

-- Seat a bot opposite a lone player, or change the bot between duels.
function Match:setBot(seat,level)
    if type(level)~="string" or not Bots.levels[level] or not self.seats[seat] then return false end
    local other=self.seats[3-seat]
    if other and not Bots.is(other) then return false end
    if (self.phase~="Waiting" and self.phase~="Results") or self.session.complete then return false end
    self.seats[3-seat]=Bots.key(level)
    if not other or not self.botDuel then self.session={wins={0,0},draws=0,played=0,complete=false} end
    self.botDuel=true
    self:startRound()
    return true
end

-- Remove the bot with no result, leaving the player waiting for a real opponent.
function Match:dropBot()
    if not self.botDuel then return false end
    for i=1,2 do if Bots.is(self.seats[i]) then self.seats[i]=nil end end
    self.botDuel=false
    self:reset("Waiting")
    return true
end

function Match:depart(seat)
    if not self.seats[seat] then return end
    self.seats[seat] = nil
    -- Keep the final result/timer for the remaining player; never reopen its seat.
    if self.phase=="Results" and self.session.complete then return end
    if self.phase == "Playing" and self.seats[3-seat] then self:finish(3-seat,"Disconnect")
    else self:reset("Waiting") end
end

function Match:intent(seat,round,kind,a,b)
    if not self.seats[seat] or self.round ~= round then return false end
    if kind == "bot" then return self:setBot(seat,a) end
    if kind == "rematch" and self.phase == "Results" then
        if self.session.complete then return false end
        if not self.seats[3-seat] then self:reset("Waiting"); return true end
        self.votes[seat] = true
        if self.votes[3-seat] or Bots.is(self.seats[3-seat]) then self:startRound() end
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
    if self.phase=="Results" and self.session.complete then
        self.session.remaining=math.max(0,self.session.remaining-dt)
    elseif self.phase == "Selecting" then
        self.count = math.max(0,self.count-dt)
        if self.count < 1e-7 then self.phase="Countdown"; self.count=self.cfg.Countdown end
    elseif self.phase == "Countdown" then
        self.count = math.max(0,self.count-dt)
        if self.count < 1e-7 then self.count=0; self.phase="Playing" end
    elseif self.phase == "Playing" then
        local old = {}
        for i=1,2 do local p=self.bodies[i]; old[i]=Vector2.new(p.x,p.y) end
        self.stepNumber += 1
        for i=1,2 do if Bots.is(self.seats[i]) then Bot.step(self,i,dt) end end
        local first = self.stepNumber%2+1
        Movement.step(self.bodies[first],self.bodies[3-first],self.map,self.cfg,dt)
        Movement.step(self.bodies[3-first],self.bodies[first],self.map,self.cfg,dt)
        Combat.step(self,dt,old)
        local dead1,dead2 = self.bodies[1].hp == 0,self.bodies[2].hp == 0
        if dead1 or dead2 then self:finish(dead1 and dead2 and 0 or dead1 and 2 or 1,"Elimination") end
    end
end

return Match
