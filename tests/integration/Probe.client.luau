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
local trail={}
shared.State.OnClientEvent:Connect(function(s)
    latest=s; seen[s.phase]=true
    if s.round==1 then
        for _,shot in s.shots do
            if shot[1]==1 then trail[tostring(s.tick)]=Vector2.new(shot[2],shot[3]) end
        end
    end
end)
local mouse=Enum.UserInputType.MouseButton1
local function click(pos,hold)
    -- GuiObject.AbsolutePosition uses the inset-relative coordinate space.
    -- VirtualInput expects the physical viewport coordinate.
    pos+=game:GetService("GuiService"):GetGuiInset()
    virtual:SendMousePosition(pos)
    task.wait(.05)
    virtual:SendMouseButton(pos,mouse,true); task.wait(hold or .025)
    virtual:SendMouseButton(pos,mouse,false); task.wait(.025)
end
local function center(f) return f.AbsolutePosition+f.AbsoluteSize/2 end
local function handle(cmd,arg)
    if cmd=="read" then
        local seat=stage.Seat1.Text:find("YOU",1,true) and 1 or 2
        return {seat=seat,title=notice.Title.Text,phase=latest and latest.phase or "",hud=stage.Phase.Text,
            hp=stage.Vitals2.Text,seen=seen,round=latest and latest.round or 0,lobby=latest and latest.lobby,
            p=latest and latest.players or {},vote=notice.Rematch.Text,
            visible=notice.Visible,bar=stage.Map1.Player2.Health.Fill.Size.X.Scale,trail=trail}
    elseif cmd=="keys" then
        virtual:SendKey(true,Enum.KeyCode[arg],false)
        task.wait(.19)
        virtual:SendKey(false,Enum.KeyCode[arg],false)
    elseif cmd=="holdJump" then
        local seat=stage.Seat1.Text:find("YOU",1,true) and 1 or 2
        local function y() return latest.players[seat].y end
        local previous=y()
        local rising=false
        local takeoffs=0
        virtual:SendKey(true,Enum.KeyCode.Space,false)
        for _=1,100 do
            task.wait(.03)
            local current=y()
            local nowRising=current<previous-.001
            if nowRising and not rising then takeoffs+=1 end
            if math.abs(current-previous)>.001 then rising=nowRising end
            previous=current
        end
        virtual:SendKey(false,Enum.KeyCode.Space,false)
        task.wait(1.8)
        local settled=y()
        task.wait(.2)
        return {takeoffs=takeoffs,settled=settled,final=y()}
    elseif cmd=="lane" then
        shared.StudioControls:FireServer("lane")
    elseif cmd=="fire" then
        for i=1,arg do click(center(stage.Map1)) end
    elseif cmd=="hold" then
        click(center(stage.Map1),.55)
    elseif cmd=="vote" then
        local pos=center(notice.Rematch)
        local under={}
        for _,widget in player.PlayerGui:GetGuiObjectsAtPosition(pos.X,pos.Y) do table.insert(under,widget.Name) end
        click(pos,.1)
        return ("at %s over %s"):format(tostring(pos),table.concat(under,","))
    elseif cmd=="disconnect" then
        task.defer(function() game:GetService("StudioTestService"):LeaveTest() end)
    elseif cmd=="leave" then
        click(center(notice.Leave),.1)
    elseif cmd=="forged" then
        local round=latest.round
        for _,k in {"hit","health","winner","position"} do shared.Input:FireServer(k,latest.lobby,round,999) end
        shared.Input:FireServer("fire",latest.lobby,round,0/0)
        shared.Input:FireServer("move",latest.lobby,round,{},true)
    elseif cmd=="foreign" then
        shared.Input:FireServer("fire",arg,latest.round,1)
        shared.Input:FireServer("rematch",arg,latest.round)
    end
    return true
end
qa.OnClientEvent:Connect(function(id,cmd,arg)
    local ok,value=pcall(handle,cmd,arg)
    qa:FireServer("reply",id,ok,ok and value or tostring(value))
end)
qa:FireServer("probeReady")
