local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local core=game:GetService("StarterGui")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage:WaitForChild("NOVA")
local input=shared:WaitForChild("Input")
local state=shared:WaitForChild("State")
local hud=require(script.Parent.Hud).new(player:WaitForChild("PlayerGui"))
local arena=require(script.Parent.Arena).new(hud.stage)
local snapshot,seat,sequence
local function fire(kind,a,b)
    if not snapshot or not seat then return end
    if kind=="fire" then sequence+=1; a=sequence end
    input:FireServer(kind,snapshot.lobby,snapshot.round,a,b)
end
local clear=require(script.Parent.Input).connect(fire,function() return snapshot and snapshot.phase=="Playing" end)
hud.rematch.Activated:Connect(function() fire("rematch") end)
hud.leave.Activated:Connect(function() fire("leave") end)
local record
if Run:IsStudio() then record=require(script.Parent.Diagnostics).attach(hud,arena,shared:WaitForChild("StudioControls")) end
state.OnClientEvent:Connect(function(nextState)
    local previous=snapshot
    snapshot=nextState
    seat=nil
    for i,p in snapshot.players do if p.uid==player.UserId then seat=i end end
    if not seat then return end
    local newDuel=not previous or previous.lobby~=snapshot.lobby or previous.round~=snapshot.round
    if newDuel then sequence=0 end
    if newDuel or previous.phase~=snapshot.phase then
        clear()
        if record then record(("Round %d / %s"):format(snapshot.round,snapshot.phase)) end
    end
    if record and previous and not newDuel then
        for i,p in snapshot.players do
            if p.hp<previous.players[i].hp then record(("P%d hit / %d HP"):format(i,p.hp)) end
        end
    end
    hud:update(snapshot,seat)
    arena:update(snapshot,os.clock())
end)
Run.RenderStepped:Connect(function() arena:draw(os.clock()); hud:tick() end)
if workspace.CurrentCamera then workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable end
pcall(function() core:SetCoreGuiEnabled(Enum.CoreGuiType.All,false) end)
input:FireServer("ready")
