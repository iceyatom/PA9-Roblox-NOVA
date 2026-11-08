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
            hp=stage.Vitals2.Text,seen=seen,round=latest and latest.round or 0,lobby=latest and latest.lobby,mapId=latest and latest.mapId,
            rollVisible=stage.MapShuffle.Visible,rollHeading=stage.MapShuffle.Heading.Text,
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
        task.wait(.2)
        return latest.players[1].y
    elseif cmd=="settings" then
        local panel=player.PlayerGui.NOVASettings.Root.Origin.Stage.Overlay.Panel
        local seat=stage.Seat1.Text:find("YOU",1,true) and 1 or 2
        local function press(key)
            virtual:SendKey(true,Enum.KeyCode[key],false); task.wait(.04)
            virtual:SendKey(false,Enum.KeyCode[key],false); task.wait(.25)
        end
        -- Opening settings must release the movement that was already held.
        virtual:SendKey(true,Enum.KeyCode.D,false); task.wait(.1)
        press("F2"); assert(panel.Parent.Visible)
        virtual:SendKey(false,Enum.KeyCode.D,false); task.wait(.15)
        local stopped=latest.players[seat].x
        task.wait(.2); assert(math.abs(latest.players[seat].x-stopped)<.001,"Movement continued inside settings")
        for action,key in {left="J",right="L",jump="I",fire="K"} do
            click(center(panel[action]))
            local deadline=os.clock()+2
            repeat task.wait(.03) until panel[action].Text=="Listening..." or os.clock()>deadline
            assert(panel[action].Text=="Listening...","Capture did not open for "..action..": "..panel.Status.Text)
            press(key)
            deadline=os.clock()+2
            repeat task.wait(.03) until panel[action].Text:find(key,1,true) or os.clock()>deadline
            assert(panel[action].Text:find(key,1,true),"Rebinding failed for "..action..": "..panel[action].Text)
        end
        assert(panel.left.Text:find("J") and panel.right.Text:find("L") and panel.jump.Text=="I" and panel.fire.Text=="K")
        click(center(panel.fire))
        local deadline=os.clock()+2
        repeat task.wait(.03) until panel.fire.Text=="Listening..." or os.clock()>deadline
        assert(panel.fire.Text=="Listening...","Conflict capture did not open: "..panel.Status.Text)
        press("I")
        deadline=os.clock()+2
        repeat task.wait(.03) until panel.Status.Text:find("Already used") or os.clock()>deadline
        assert(panel.Status.Text:find("Already used"),"Duplicate assignment was accepted: "..panel.Status.Text)
        press("F2"); assert(panel.Parent.Visible,"Cancel should leave settings open")
        click(center(panel.Done)); task.wait(.2)
        assert(not panel.Parent.Visible)
        local saved=shared.ControlPreferences:InvokeServer("get").bindings
        assert(saved.pc.jump=="I" and saved.pc.fire=="K" and saved.console.jump=="ButtonA")
        shared.StudioControls:FireServer("lane"); task.wait(.2)
        local y=latest.players[seat].y
        press("Space"); assert(math.abs(latest.players[seat].y-y)<.001,"Previous jump binding is still active")
        virtual:SendKey(true,Enum.KeyCode.I,false); task.wait(.12)
        assert(latest.players[seat].y<y,"New jump binding did not reach the server")
        virtual:SendKey(false,Enum.KeyCode.I,false)
        press("F2")
        click(center(panel.ResetDefaults)); task.wait(.1)
        click(center(panel.Done)); task.wait(.2)
        saved=shared.ControlPreferences:InvokeServer("get").bindings
        assert(saved.pc.jump=="Space" and saved.pc.fire=="MouseButton1" and saved.pc.left=="A")
        shared.StudioControls:FireServer("lane"); task.wait(.2)
        return true
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
