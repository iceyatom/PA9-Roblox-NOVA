-- Cloned only into StudioTestService clients for the named integration run.
local run=game:GetService("RunService")
if not run:IsStudio() then return end
-- Core player-list placement varies with the Studio client window size and can cover Settings.
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
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
local cosmeticShot={}
gui.DescendantAdded:Connect(function(object)
    if object.Name=="Core" and object.Parent and object.Parent.Name=="Pulse" then cosmeticShot.bullet=object.BackgroundColor3:ToHex()
    elseif object.Name=="CosmeticTracer" then cosmeticShot.tracer=object.BackgroundColor3:ToHex()
    elseif object:IsA("Sound") and object.Name=="CosmeticShot" then cosmeticShot.sound=object.SoundId end
end)
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
    if cmd=="inventory" then
        local inv=player.PlayerGui:WaitForChild("NOVAInventory")
        local panel=inv.InventoryOverlay.Origin.Panel
        local remote=shared.InventoryRequest
        click(center(inv.InventoryButton)); task.wait(.25)
        assert(inv.InventoryOverlay.Visible,"Inventory launcher did not open")
        click(center(panel.Items.skin_mint)); task.wait(.1)
        click(center(panel.Details.EquipOrOpen)); task.wait(.25)
        click(center(panel.Details.Favorite)); task.wait(.25)
        for _,itemId in {"bullet_solar","tracer_comet","card_nebula","sound_arcade"} do
            assert(remote:InvokeServer("equip",itemId).ok); task.wait(.2)
        end
        local profile=remote:InvokeServer("read").profile; task.wait(.2)
        assert(profile.data.equipped.skins=="skin_mint" and profile.data.favorites.skin_mint)
        local denied=remote:InvokeServer("grant","crate_dev"); task.wait(.2)
        assert(not denied.ok,"Client grant action was accepted")
        local key=game:GetService("HttpService"):GenerateGUID(false)
        local award=remote:InvokeServer("open","crate_dev",key); task.wait(.2)
        assert(award.ok and award.receipt.duplicate and award.receipt.shards>0)
        local retry=remote:InvokeServer("open","crate_dev",key); task.wait(.2)
        assert(retry.ok and retry.receipt.itemId==award.receipt.itemId and retry.profile.data.owned.crate_dev==9)
        assert(retry.profile.data.shards==award.profile.data.shards,"Replay awarded duplicate currency twice")
        click(center(panel.Close)); task.wait(.2)
        assert(not inv.InventoryOverlay.Visible)
        return true
    elseif cmd=="read" then
        local seat=stage.Seat1.Text:find("YOU",1,true) and 1 or 2
        return {seat=seat,title=notice.Title.Text,phase=latest and latest.phase or "",hud=stage.Phase.Text,
            hp=stage.Vitals2.Text,seen=seen,round=latest and latest.round or 0,lobby=latest and latest.lobby,mapId=latest and latest.mapId,
            rollVisible=stage.MapShuffle.Visible,rollHeading=stage.MapShuffle.Heading.Text,
            p=latest and latest.players or {},vote=notice.Rematch.Text,
            visible=notice.Visible,bar=stage.Map1.Player2.Health.Fill.Size.X.Scale,trail=trail,
            skinColor1=stage.Map1.Player1.BackgroundColor3:ToHex(),cardVisible1=stage.PlayerCard1.BackgroundTransparency==0,
            inventoryVisible=player.PlayerGui.NOVAInventory.Enabled,cosmeticShot=table.clone(cosmeticShot)}
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
        local settingsStage=player.PlayerGui.NOVASettings.Root.Origin.Stage
        local panel=player.PlayerGui.NOVASettings.Root.Origin.Stage.Overlay.Panel
        local function press(key)
            virtual:SendKey(true,Enum.KeyCode[key],false); task.wait(.04)
            virtual:SendKey(false,Enum.KeyCode[key],false); task.wait(.25)
        end
        assert(settingsStage.OpenSettings.Visible and settingsStage.OpenSettings.Text=="Settings")
        press("F2"); assert(not panel.Parent.Visible,"F2 still opens settings")
        click(center(settingsStage.OpenSettings)); task.wait(.15)
        assert(panel.Parent.Visible,"Lobby Settings button did not open settings")
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
        press("K"); assert(panel.Parent.Visible,"Completing binding should leave settings open")
        click(center(panel.Done)); task.wait(.2)
        assert(not panel.Parent.Visible)
        local saved=shared.ControlPreferences:InvokeServer("get").bindings
        assert(saved.pc.jump=="I" and saved.pc.fire=="K" and saved.console.jump=="ButtonA")
        click(center(settingsStage.OpenSettings)); task.wait(.15)
        click(center(panel.ResetDefaults)); task.wait(.1)
        click(center(panel.Done)); task.wait(.2)
        saved=shared.ControlPreferences:InvokeServer("get").bindings
        assert(saved.pc.jump=="Space" and saved.pc.fire=="MouseButton1" and saved.pc.left=="A")
        return true
    elseif cmd=="settingsUnavailable" then
        assert(not shared.InventoryRequest:InvokeServer("equip","skin_ember").ok,"Equipment changed outside lobby")
        local settingsGui=player.PlayerGui.NOVASettings
        local settingsStage=settingsGui.Root.Origin.Stage
        assert(not settingsGui.Enabled and not settingsStage.OpenSettings.Visible,"Settings are visible outside the main lobby")
        virtual:SendKey(true,Enum.KeyCode.F2,false); task.wait(.04)
        virtual:SendKey(false,Enum.KeyCode.F2,false); task.wait(.15)
        assert(not settingsStage.Overlay.Visible,"Settings opened outside the main lobby")
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
