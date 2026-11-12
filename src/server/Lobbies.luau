local Match=require(script.Parent.Match)
local Lobbies={}
Lobbies.__index=Lobbies

function Lobbies.new(map,cfg,chooseMap,finished)
    return setmetatable({map=map,cfg=cfg,chooseMap=chooseMap,finished=finished,rooms={},membership={},nextId=0,dirty={}},Lobbies)
end

local function loneWaiting(room)
    local sim=room.sim
    return sim.phase=="Waiting" and ((sim.seats[1] and not sim.seats[2]) or (sim.seats[2] and not sim.seats[1]))
end

function Lobbies:join(player)
    if self.membership[player] then return self.membership[player] end
    local target
    for _,room in self.rooms do
        if loneWaiting(room) and (not target or room.id<target.id) then target=room end
    end
    if not target then
        self.nextId+=1
        target={id=self.nextId,sim=Match.new(self.map,self.cfg,self.chooseMap)}
        target.sim.roomId=target.id
        target.sim.finished=self.finished
        self.rooms[target.id]=target
    end
    local entry={room=target,seat=assert(target.sim:join(player))}
    self.membership[player]=entry
    self.dirty[target.id]=true
    return entry
end

function Lobbies:remove(player)
    local entry=self.membership[player]
    if not entry then return end
    self.membership[player]=nil
    local room=entry.room
    room.sim:depart(entry.seat)
    if not room.sim.seats[1] and not room.sim.seats[2] then
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
    if accepted and kind=="rematch" then
        self.dirty[room.id]=true
        self:pairWaiting()
    end
    return accepted
end

function Lobbies:step(dt)
    for _,room in self.rooms do
        local old=room.sim.phase
        room.sim:step(dt)
        if room.sim.phase~=old then self.dirty[room.id]=true end
    end
end
return Lobbies
