local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local shared = game.ReplicatedStorage:WaitForChild("NOVA")
local Config = require(shared.Config)
local Maps = require(shared.Map1)
local map = Maps.active()
local lobbies = require(script.Parent.Lobbies).new(map,Config,Maps.choose)
local LobbyWorld = require(script.Parent.LobbyWorld)
local world = LobbyWorld.ensure()
local signKicker = world:FindFirstChild("Kicker",true)
if signKicker then signKicker.Text = ("%d MAPS  /  RANDOM ROTATION"):format(#Maps.pool()) end
if Run:IsStudio() then print(("[NOVA] Map rotation: %d maps"):format(#Maps.pool())) end
-- Characters exist only in the 3D lobby. Queued and dueling players use the 2D stage.
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
    local snap = {lobby=room.id,phase=sim.phase,round=sim.round,mapId=sim.map.id,tick=sim.stepNumber,ends=workspace:GetServerTimeNow()+sim.count,
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

local function spawnInLobby(p)
    if p.Parent==Players and not lobbies.membership[p] then p:LoadCharacter() end
end
local function track(p)
    p.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid").Died:Connect(function()
            task.wait(3)
            if p.Character==character then spawnInLobby(p) end
        end)
    end)
    spawnInLobby(p)
end
Players.PlayerAdded:Connect(track)
for _,p in Players:GetPlayers() do task.spawn(track,p) end

local function enterQueue(p)
    if lobbies.membership[p] then return end
    lobbies:join(p)
    local character=p.Character
    p.Character=nil
    if character then character:Destroy() end
    flush()
end
local function returnToLobby(p)
    lobbies:remove(p)
    state:FireClient(p,{phase="Lobby"})
    flush()
    spawnInLobby(p)
end

-- Queue anyone standing on the pad and keep the sign's counts current.
local status=world:FindFirstChild("Status",true)
local scanElapsed=0
Run.Heartbeat:Connect(function(dt)
    scanElapsed+=dt
    if scanElapsed<0.1 then return end
    scanElapsed=0
    for _,p in Players:GetPlayers() do
        if not lobbies.membership[p] and LobbyWorld.onPad(world,p.Character) then enterQueue(p) end
    end
    if status then
        local queued,live=0,0
        for _,room in lobbies.rooms do
            local seats=room.sim.seats
            if seats[1] and seats[2] then live+=1 elseif room.sim.phase=="Waiting" then queued+=1 end
        end
        status.Text=("%d IN QUEUE   /   %d LIVE DUEL%s"):format(queued,live,live==1 and "" or "S")
    end
end)

Players.PlayerRemoving:Connect(function(p)
    lobbies:remove(p)
    flush()
end)
input.OnServerEvent:Connect(function(p,kind,lobbyId,round,a,b)
    if p.Parent~=Players then return end
    local entry=lobbies.membership[p]
    if not entry or entry.room.id~=lobbyId or entry.room.sim.round~=round then return end
    local phase=entry.room.sim.phase
    if kind == "leave" and (phase == "Results" or phase == "Waiting") then
        returnToLobby(p)
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
            local left,right,y=sim:duelLane()
            if not left then return end
            table.clear(sim.bullets)
            for i,b in sim.bodies do
                b.x,b.y,b.vy,b.axis,b.jump,b.pad,b.grounded,b.jumpHeld = i==1 and left or right,y,0,0,false,false,true,false
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
