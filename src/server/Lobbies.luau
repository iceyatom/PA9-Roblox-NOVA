local Match=require(script.Parent.Match)
local Bots=require(game.ReplicatedStorage.NOVA.Bots)
local Lobbies={}
Lobbies.__index=Lobbies

function Lobbies.new(map,cfg,chooseMap,finished)
    return setmetatable({map=map,cfg=cfg,chooseMap=chooseMap,finished=finished,rooms={},membership={},nextId=0,dirty={}},Lobbies)
end

local function humans(sim)
    local count,who=0,nil
    for i=1,2 do
        local key=sim.seats[i]
        if key and not Bots.is(key) then count+=1;who=key end
    end
    return count,who
end
-- A room a real opponent can take: one player waiting alone, or fighting a bot
-- while still in the queue. Private bot-practice rooms never match.
local function loneWaiting(room)
    local sim=room.sim
    return not room.private and humans(sim)==1 and (sim.botDuel==true or sim.phase=="Waiting")
end

function Lobbies:join(player)
    if self.membership[player] then return self.membership[player] end
    local target
    for _,room in self.rooms do
        if loneWaiting(room) and (not target or room.id<target.id) then target=room end
    end
    if not target then target=self:create() end
    -- A real opponent ends a queue bot duel at once, with no result.
    target.sim:dropBot()
    local entry={room=target,seat=assert(target.sim:join(player))}
    self.membership[player]=entry
    self.dirty[target.id]=true
    return entry
end

function Lobbies:create(private)
    self.nextId+=1
    local room={id=self.nextId,private=private or nil,sim=Match.new(self.map,self.cfg,self.chooseMap)}
    room.sim.roomId=room.id
    room.sim.finished=self.finished
    self.rooms[room.id]=room
    return room
end

-- Bot practice from the lobby pad: a room outside matchmaking.
function Lobbies:joinPrivate(player)
    if self.membership[player] then return self.membership[player] end
    local room=self:create(true)
    local entry={room=room,seat=assert(room.sim:join(player))}
    self.membership[player]=entry
    self.dirty[room.id]=true
    return entry
end

function Lobbies:remove(player)
    local entry=self.membership[player]
    if not entry then return end
    self.membership[player]=nil
    local room=entry.room
    room.sim:depart(entry.seat)
    if humans(room.sim)==0 then
        table.clear(room.sim.seats)
        self.rooms[room.id]=nil
        self.dirty[room.id]=nil
    else
        self.dirty[room.id]=true
    end
    self:pairWaiting()
end

-- Keep completed duels reserved for their rematch decisions. Only Waiting rooms pair.
function Lobbies:pairWaiting()
    local waiting={}
    for _,room in self.rooms do
        if loneWaiting(room) then table.insert(waiting,room) end
    end
    table.sort(waiting,function(a,b) return a.id<b.id end)
    for i=1,#waiting-1,2 do
        local destination,source=waiting[i],waiting[i+1]
        destination.sim:dropBot();source.sim:dropBot()
        local player=source.sim.seats[1] or source.sim.seats[2]
        local entry=self.membership[player]
        source.sim:depart(entry.seat)
        entry.room=destination
        entry.seat=assert(destination.sim:join(player))
        self.rooms[source.id]=nil
        self.dirty[source.id]=nil
        self.dirty[destination.id]=true
    end
end

function Lobbies:intent(player,roomId,round,kind,a,b)
    local entry=self.membership[player]
    if not entry or entry.room.id~=roomId then return false end
    local room=entry.room
    local accepted=room.sim:intent(entry.seat,round,kind,a,b)
    if accepted and (kind=="rematch" or kind=="bot") then
        self.dirty[room.id]=true
        self:pairWaiting()
    end
    return accepted
end

-- Detach both seats before callbacks so neither can pair into another duel here.
function Lobbies:closeSession(room)
    if self.rooms[room.id]~=room or not room.sim.session.complete or room.sim.session.remaining>0 then return false end
    local players={}
    for _,player in room.sim.seats do
        local entry=self.membership[player]
        if entry and entry.room==room then
            self.membership[player]=nil
            table.insert(players,player)
        end
    end
    self.rooms[room.id]=nil
    self.dirty[room.id]=nil
    table.clear(room.sim.seats)
    for _,player in players do
        if self.sessionEnded then self.sessionEnded(player) end
    end
    return true
end

function Lobbies:step(dt)
    local expired={}
    for _,room in self.rooms do
        local old=room.sim.phase
        room.sim:step(dt)
        if room.sim.phase~=old then self.dirty[room.id]=true end
        if room.sim.session.complete and room.sim.session.remaining<=0 then table.insert(expired,room) end
    end
    for _,room in expired do self:closeSession(room) end
end
return Lobbies
