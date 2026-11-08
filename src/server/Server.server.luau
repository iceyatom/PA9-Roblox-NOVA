local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local shared = game.ReplicatedStorage:WaitForChild("NOVA")
local Config = require(shared.Config)
local lobbies = require(script.Parent.Lobbies).new(require(shared.Map1).arena,Config)
Players.CharacterAutoLoads = false

local function remote(name)
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = shared
    return event
end
local state = remote("State")
local input = remote("Input")
local function broadcast(room)
    local sim=room.sim
    local snap = {lobby=room.id,phase=sim.phase,round=sim.round,tick=sim.stepNumber,ends=workspace:GetServerTimeNow()+sim.count,
        winner=sim.winner,reason=sim.reason,players={},shots={},maxHP=sim.cfg.Health}
    for i=1,2 do
        local p,b = sim.seats[i],sim.bodies[i]
        snap.players[i] = {uid=p and p.UserId,name=p and p.DisplayName,x=b.x,y=b.y,hp=b.hp,vote=sim.votes[i] == true}
    end
    for i,b in sim.bullets do snap.shots[i]={b.id,b.x,b.y,b.seat,b.vx,b.vy} end
    for _,p in sim.seats do
        if p.Parent==Players then state:FireClient(p,snap) end
    end
    if Run:IsStudio() and sim.phase ~= room.lastPhase then
        room.lastPhase = sim.phase
        print(("[NOVA] Lobby %d / Round %d / %s"):format(room.id,sim.round,sim.phase))
    end
end

local function flush()
    for id in lobbies.dirty do
        local room=lobbies.rooms[id]
        if room then broadcast(room) end
    end
    table.clear(lobbies.dirty)
end

Players.PlayerRemoving:Connect(function(p)
    lobbies:remove(p)
    flush()
end)
input.OnServerEvent:Connect(function(p,kind,lobbyId,round,a,b)
    if p.Parent~=Players then return end
    if kind == "ready" then
        if lobbies.membership[p] then return end
        lobbies:join(p)
        flush()
        return
    end
    local entry=lobbies.membership[p]
    if not entry or entry.room.id~=lobbyId or entry.room.sim.round~=round then return end
    if kind == "leave" and entry.room.sim.phase == "Results" then
        lobbies:remove(p)
        flush()
        p:Kick("You left the NOVA duel.")
    else
        lobbies:intent(p,lobbyId,round,kind,a,b)
        flush()
    end
end)

if Run:IsStudio() then
    local controls = remote("StudioControls")
    local ranges = {Speed={2,22},Jump={8,42},Gravity={14,85},Launch={15,55},BulletSpeed={5,65}}
    controls.OnServerEvent:Connect(function(p,action,key,value)
        local entry=lobbies.membership[p]
        if not entry then return end
        local room=entry.room
        local sim=room.sim
        local function notify(...)
            for _,other in sim.seats do controls:FireClient(other,...) end
        end
        if action == "set" and ranges[key] and type(value)=="number" and value==value then
            sim.cfg[key]=math.clamp(value,unpack(ranges[key]))
            notify("tuned",key,sim.cfg[key])
        elseif action == "lane" and sim.phase == "Playing" then
            table.clear(sim.bullets)
            for i,b in sim.bodies do
                b.x,b.y,b.vy,b.axis,b.jump,b.pad,b.grounded = i==1 and 15 or 23,11.5,0,0,false,false,true
            end
            notify("lane")
            broadcast(room)
        end
    end)
end

local accumulator,sendElapsed=0,0
Run.Heartbeat:Connect(function(dt)
    accumulator += math.min(dt,0.25)
    sendElapsed += dt
    while accumulator >= Config.Step do
        lobbies:step(Config.Step)
        accumulator -= Config.Step
    end
    if sendElapsed>=1/Config.SnapshotRate then
        sendElapsed=0
        for id,room in lobbies.rooms do
            if room.sim.phase=="Playing" then lobbies.dirty[id]=true end
        end
    end
    flush()
end)
