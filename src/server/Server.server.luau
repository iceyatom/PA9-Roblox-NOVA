local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local shared = game.ReplicatedStorage:WaitForChild("NOVA")
local Config = require(shared.Config)
local sim = require(script.Parent.Match).new(require(shared.Map1).arena,Config)
Players.CharacterAutoLoads = false

local function remote(name)
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = shared
    return event
end
local state = remote("State")
local input = remote("Input")
local seatOf = {}
local lastPhase
local function broadcast()
    local snap = {phase=sim.phase,round=sim.round,tick=sim.stepNumber,ends=workspace:GetServerTimeNow()+sim.count,
        winner=sim.winner,reason=sim.reason,players={},shots={},maxHP=sim.cfg.Health}
    for i=1,2 do
        local p,b = sim.seats[i],sim.bodies[i]
        snap.players[i] = {uid=p and p.UserId,name=p and p.DisplayName,x=b.x,y=b.y,hp=b.hp,vote=sim.votes[i] == true}
    end
    for i,b in sim.bullets do snap.shots[i]={b.id,b.x,b.y,b.seat,b.vx,b.vy} end
    for p in seatOf do state:FireClient(p,snap) end
    if Run:IsStudio() and sim.phase ~= lastPhase then
        lastPhase = sim.phase
        print(("[NOVA] Round %d / %s"):format(sim.round,sim.phase))
    end
end

local function remove(p)
    local seat=seatOf[p]
    if seat then
        seatOf[p]=nil
        sim:depart(seat)
        broadcast()
    end
end
Players.PlayerRemoving:Connect(remove)
input.OnServerEvent:Connect(function(p,kind,round,a,b)
    if kind == "ready" then
        if seatOf[p] then return end
        local seat=sim:join(p)
        if not seat then p:Kick("Both NOVA seats are occupied."); return end
        seatOf[p]=seat
        broadcast()
        return
    end
    local seat = seatOf[p]
    if not seat or round ~= sim.round then return end
    if kind == "leave" and sim.phase == "Results" then
        remove(p)
        p:Kick("You left the NOVA duel.")
    elseif sim:intent(seat,round,kind,a,b) and kind == "rematch" then
        broadcast()
    end
end)

if Run:IsStudio() then
    local controls = remote("StudioControls")
    local ranges = {Speed={2,22},Jump={8,42},Gravity={14,85},Launch={15,55},BulletSpeed={5,65}}
    controls.OnServerEvent:Connect(function(p,action,key,value)
        if not seatOf[p] then return end
        if action == "set" and ranges[key] and type(value)=="number" and value==value then
            sim.cfg[key]=math.clamp(value,unpack(ranges[key]))
            controls:FireAllClients("tuned",key,sim.cfg[key])
        elseif action == "lane" and sim.phase == "Playing" then
            table.clear(sim.bullets)
            for i,b in sim.bodies do
                b.x,b.y,b.vy,b.axis,b.jump,b.pad,b.grounded = i==1 and 15 or 23,11.5,0,0,false,false,true
            end
            controls:FireAllClients("lane")
            broadcast()
        end
    end)
end

local accumulator,sendElapsed=0,0
Run.Heartbeat:Connect(function(dt)
    accumulator += math.min(dt,0.25)
    sendElapsed += dt
    local oldPhase=sim.phase
    while accumulator >= Config.Step do
        sim:step(Config.Step)
        accumulator -= Config.Step
    end
    if oldPhase ~= sim.phase or (sendElapsed >= 1/Config.SnapshotRate and sim.phase=="Playing") then
        sendElapsed = 0
        broadcast()
    end
end)
