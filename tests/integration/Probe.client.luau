-- Cloned only into StudioTestService clients for the named integration run.
local run=game:GetService("RunService")
if not run:IsStudio() then return end
local player=game.Players.LocalPlayer
local shared=game.ReplicatedStorage:WaitForChild("NOVA")
local qa=shared:WaitForChild("AcceptanceProbe")
local gui=player.PlayerGui:WaitForChild("NOVA")
local stage=gui.Backdrop.Origin:WaitForChild("Stage")
local notice=stage:WaitForChild("MatchNotice")
local virtual=assert(game:GetService("UserInputService"):CreateVirtualInput(),"Virtual input unavailable")
local latest
local seen={}
shared.State.OnClientEvent:Connect(function(s)
    latest=s; seen[s.phase]=true
end)
local mouse=Enum.UserInputType.MouseButton1
local function click(pos,hold)
    virtual:SendMouseButton(pos,mouse,true); task.wait(hold or .025)
    virtual:SendMouseButton(pos,mouse,false); task.wait(.025)
end
local function center(f) return f.AbsolutePosition+f.AbsoluteSize/2 end
local function handle(cmd,arg)
    if cmd=="read" then
        local seat=stage.Seat1.Text:find("YOU",1,true) and 1 or 2
        return {seat=seat,title=notice.Title.Text,phase=latest and latest.phase or "",hud=stage.Phase.Text,
            hp=stage.Vitals2.Text,seen=seen,round=latest and latest.round or 0,
            p=latest and latest.players or {},vote=notice.Rematch.Text,
            visible=notice.Visible,bar=stage.Map1.Player2.Health.Fill.Size.X.Scale}
    elseif cmd=="keys" then
        virtual:SendKey(true,Enum.KeyCode[arg],false)
        task.wait(.19)
        virtual:SendKey(false,Enum.KeyCode[arg],false)
    elseif cmd=="lane" then
        shared.StudioControls:FireServer("lane")
    elseif cmd=="fire" then
        for i=1,arg do click(center(stage.Map1)) end
    elseif cmd=="hold" then
        click(center(stage.Map1),.55)
    elseif cmd=="vote" then
        click(center(notice.Rematch))
    elseif cmd=="disconnect" then
        task.defer(function() game:GetService("StudioTestService"):LeaveTest() end)
    elseif cmd=="forged" then
        local round=latest.round
        for _,k in {"hit","health","winner","position"} do shared.Input:FireServer(k,round,999) end
        shared.Input:FireServer("fire",round,0/0)
        shared.Input:FireServer("move",round,{},true)
    end
    return true
end
qa.OnClientEvent:Connect(function(id,cmd,arg)
    local ok,value=pcall(handle,cmd,arg)
    qa:FireServer("reply",id,ok,ok and value or tostring(value))
end)
qa:FireServer("probeReady")
