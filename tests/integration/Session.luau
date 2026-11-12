-- Real Studio server and two Player/PlayerGui instances, with hardware-equivalent input.
return function()
    local test=game:GetService("StudioTestService")
    local players=game:GetService("Players")
    local shared=game.ReplicatedStorage:WaitForChild("NOVA")
    local channel=Instance.new("RemoteEvent")
    channel.Name="AcceptanceProbe"; channel.Parent=shared
    local ready,results,log={}, {}, {}
    local id=0
    local function note(s) table.insert(log,s); print("[NOVA ACCEPTANCE]",s) end
    local function untilTrue(fn,timeout,label)
        local deadline=os.clock()+timeout
        repeat
            local value=fn()
            if value then return value end
            task.wait(.05)
        until os.clock()>=deadline
        error("Timed out: "..label)
    end
    channel.OnServerEvent:Connect(function(p,kind,n,ok,value)
        if kind=="probeReady" then ready[p]=true
        elseif kind=="reply" and results[n] and results[n].owner==p then
            results[n].answer={ok,value}
        end
    end)
    local function install(p)
        local gui=p:WaitForChild("PlayerGui",20)
        if not gui or gui:FindFirstChild("NOVAProbe") then return end
        -- Lobby respawns clear loose PlayerGui scripts, so the probe lives in a persistent ScreenGui.
        local host=Instance.new("ScreenGui"); host.Name="NOVAProbe"; host.ResetOnSpawn=false
        if test:GetTestArgs()=="NOVA/batch-stress" then script.Parent.BatchStress:Clone().Parent=host end
        local probe=script.Parent.Probe:Clone(); probe.Name="Probe"; probe.Parent=host
        host.Parent=gui
    end
    players.PlayerAdded:Connect(install)
    for _,p in players:GetPlayers() do task.spawn(install,p) end
    local function request(p,cmd,arg)
        id+=1; local n=id
        results[n]={owner=p}
        channel:FireClient(p,n,cmd,arg)
        local ans=untilTrue(function() return results[n].answer end,cmd=="batchStress" and 90 or cmd=="batchDelivery" and 65 or cmd=="settings" and 20 or 7,cmd.." from "..p.Name)
        results[n]=nil
        assert(ans[1],tostring(ans[2])); return ans[2]
    end
    local function read(p) return request(p,"read") end
    local function waitPhase(p,phase)
        return untilTrue(function() local r=read(p); return r.phase==phase and (phase~="Results" or r.resultsReady) and r end,phase=="Results" and 18 or 12,phase)
    end
    -- Clients spawn in the 3D lobby. Standing on the pad queues them for Map 1.
    local function queue(p)
        local root=untilTrue(function() return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end,20,"lobby character for "..p.Name)
        local pad=workspace.NOVALobby.QueuePad
        root.Parent:PivotTo(CFrame.new(pad.Position+Vector3.new(0,4,0)))
        untilTrue(function()
            local phase=read(p).phase
            return phase=="Waiting" or phase=="Selecting" or phase=="Countdown"
        end,6,"queue for "..p.Name)
        assert(p.Character==nil,"Queued player keeps no 3D character")
    end
    local function batch()
        -- Deterministic test-only draws exercise a miss, then an earned crate/open.
        local Service=require(game.ServerScriptService.NOVA.InventoryService)
        local originalAward=Service.awardMatch;local draws={.8,.1}
        Service.awardMatch=function(self,p,key,expires,outcome,report)
            if outcome~="win" then return originalAward(self,p,key,expires,outcome,report) end
            local random=self.random;local roll=table.remove(draws,1)
            assert(roll~=nil,"Unexpected extra win reward")
            self.random={NextNumber=function() return roll end}
            local ok,err=pcall(originalAward,self,p,key,expires,outcome,report)
            self.random=random;assert(ok,err)
        end
        local p1=untilTrue(function() return next(ready) end,45,"first client")
        untilTrue(function() return p1:GetAttribute("InventoryReady") end,15,"inventory")
        local grant=game.ServerScriptService.NOVA.GrantInventory
        for _,category in {"skins","bullets","tracers","backgrounds","sounds"} do
            grant:Invoke(p1,"b1_"..category.."_crimson_singularity",1)
        end
        local assets=0;for _ in require(shared.BatchOneAssets) do assets+=1 end
        assert(request(p1,"batchDelivery")==assets)
        note("All "..assets.." current cosmetic textures and audio assets loaded on a real client")
        assert(request(p1,"batchSetup"))
        queue(p1)
        test:AddPlayers(1)
        local p2=untilTrue(function() for p in ready do if p~=p1 then return p end end end,55,"second client")
        queue(p2)
        local wonCrates=0;local expectedChance=25
        for round=1,2 do
            waitPhase(p1,"Playing");waitPhase(p2,"Playing")
            request(p1,"batchFire");waitPhase(p1,"Results")
            local settled=untilTrue(function()
                local r=read(p1)
                return r.chest and r.chest.receipt and r.dropSettled and r
            end,25,"saved and animated crate chance")
            local receipt=settled.chest.receipt
            assert(receipt.chance==expectedChance)
            if receipt.awarded then wonCrates+=1 end
            expectedChance=receipt.nextChance
            local data=request(p1,"batchProfile")
            assert((data.owned.crate_season1 or 0)==wonCrates and data.crateChance==expectedChance)
            local loser=request(p2,"batchProfile")
            assert(not loser.owned.crate_season1 and math.abs(loser.crateChance-25*1.2^round)<.00001)
            untilTrue(function() local r=read(p2);return r.chest and r.chest.receipt and r.dropSettled end,25,"loser chance increase")
            request(p2,"batchSave")
            if round==2 and receipt.awarded then
                request(p1,"batchOpen")
                untilTrue(function() return request(p1,"batchReveal")=="settled" end,12,"crate reveal after lobby return")
                wonCrates-=1
                assert((request(p1,"batchProfile").owned.crate_season1 or 0)==wonCrates)
            else
                request(p1,"batchSave")
                if round==1 then request(p1,"vote");request(p2,"vote")
                else request(p1,"leave") end
            end
            note(("Round %d: %s at %.1f%%; next chance %.1f%%; loser boosted without a crate"):format(round,receipt.awarded and "crate earned/opened" or "miss",receipt.chance,receipt.nextChance))
        end
        note("Chance receipts, animated results, dismissal and conditional crate opening passed")
        queue(p1)
        waitPhase(p1,"Playing"); waitPhase(p2,"Playing")
        channel:FireClient(p1,-1,"disconnect")
        local left=waitPhase(p2,"Results")
        assert(left.title=="Victory" and not left.chest and not request(p2,"batchProfile").owned.crate_season1)
        note("A playing-phase disconnect produced Victory and zero chests")
    end
    local function exercise()
        local p1=untilTrue(function() return next(ready) end,35,"first client ready")
        assert(read(p1).phase=="","Clients start in the lobby without a duel")
        request(p1,"settings")
        note("Lobby Settings button opened the menu; F2 did not. PC rebinding, conflicts, session saves and reset defaults passed")
        untilTrue(function() return p1:GetAttribute("InventoryReady") end,15,"inventory profile")
        game.ServerScriptService.NOVA.GrantInventory:Invoke(p1,"samples")
        request(p1,"inventory")
        note("Inventory launcher, UI equip/favorite, developer grants, duplicate currency and idempotent crate retry passed; client grant rejected")
        queue(p1)
        untilTrue(function() local r=read(p1); return r.hud:find("LOBBY") and r.visible end,5,"waiting screen")
        note("One real client displayed Waiting")
        test:AddPlayers(1)
        local p2=untilTrue(function() for p in ready do if p~=p1 then return p end end end,40,"second client ready")
        queue(p2)
        local r1,r2=waitPhase(p1,"Playing"),waitPhase(p2,"Playing")
        assert(r1.seat==1 and r2.seat==2 and r1.round==r2.round)
        assert(r1.p[1].cosmetics.skins=="skin_mint" and r2.p[1].cosmetics.bullets=="bullet_solar")
        assert(r1.skinColor1=="50e4ac" and r2.skinColor1=="50e4ac" and r1.cardVisible1 and r2.cardVisible1)
        assert(not r1.inventoryVisible and not r2.inventoryVisible)
        note("Both real duel clients rendered the equipped skin and player-card background; inventory stayed hidden outside the lobby")
        assert(r1.seen.Countdown and r2.seen.Countdown,"Missing countdown on client")
        local firstMap=require(shared.Map1).load(r1.mapId)
        assert(r1.mapId==r2.mapId and r1.seen.Selecting and r2.seen.Selecting)
        assert(r1.p[1].x==firstMap.spawns[1].X and r2.p[2].x==firstMap.spawns[2].X and r1.p[1].hp==10 and r2.p[2].hp==10)
        note("Both clients saw the same countdown, seats, spawns and full health")
        test:AddPlayers(2)
        local extras=untilTrue(function()
            local found={}
            for p in ready do if p~=p1 and p~=p2 then table.insert(found,p) end end
            return #found==2 and found
        end,40,"second lobby clients")
        queue(extras[1]); queue(extras[2])
        local e1,e2=waitPhase(extras[1],"Playing"),waitPhase(extras[2],"Playing")
        assert(e1.lobby==e2.lobby and e1.lobby~=r1.lobby)
        assert(e1.p[1].uid~=r1.p[1].uid and e1.p[2].uid~=r1.p[2].uid)
        request(extras[1],"lane"); task.wait(.15)
        request(extras[1],"hold"); task.wait(.6)
        local otherSeat=3-e1.seat
        assert(read(extras[2]).p[otherSeat].hp==9)
        request(p1,"foreign",e1.lobby); task.wait(.2)
        assert(read(extras[1]).p[1].hp==read(extras[2]).p[1].hp)
        assert(read(p1).p[2].hp==10 and read(p2).p[1].hp==10)
        note("Four clients occupied two separate live lobbies; shots and foreign-lobby requests stayed isolated")
        request(p1,"keys","D"); request(p2,"keys","A"); task.wait(.12)
        r1,r2=read(p1),read(p2)
        assert(r1.p[1].x>firstMap.spawns[1].X and r2.p[2].x<firstMap.spawns[2].X,"A/D movement")
        local laneY=request(p1,"lane"); task.wait(.2)
        request(p1,"keys","Space"); assert(read(p1).p[1].y<laneY,"Blue Space jump")
        request(p2,"keys","Space"); assert(read(p2).p[2].y<laneY,"Red Space jump")
        note("Two clients drove movement through keyboard events")
        request(p1,"lane"); task.wait(.2)
        request(p1,"settingsUnavailable")
        note("Settings stayed hidden and unavailable during the duel, including when F2 was pressed")
        laneY=request(p1,"lane"); task.wait(.2)
        local held=request(p1,"holdJump")
        assert(held.takeoffs>=2,"Held Space must jump again on landing")
        assert(math.abs(held.settled-laneY)<.001 and math.abs(held.final-laneY)<.001,"Release must stop auto-jump")
        note("Holding Space repeated jumps on landing; releasing Space settled the player")
        request(p1,"lane"); task.wait(.2)
        request(p1,"forged"); task.wait(.15)
        assert(read(p2).p[2].hp==10)
        request(p1,"hold"); task.wait(.55)
        r1,r2=read(p1),read(p2)
        assert(r1.p[2].hp==9 and r2.p[2].hp==9,"hold must emit exactly one shot")
        for _,view in {r1,r2} do
            assert(view.cosmeticShot.bullet=="ffc857" and view.cosmeticShot.tracer=="50e4ec")
            assert(view.cosmeticShot.sound=="rbxasset://sounds/volume_slider.ogg")
        end
        note("Both clients rendered the equipped bullet, tracer and shot sound from real authoritative projectiles")
        local sharedSamples=0
        for tick,pos in r1.trail do
            if r2.trail[tick] then assert(r2.trail[tick]==pos); sharedSamples+=1 end
        end
        assert(sharedSamples>=2,"Both clients must see the same flight")
        note(("%d matching projectile positions across both clients"):format(sharedSamples))
        request(p1,"fire",8); task.wait(.7)
        assert(read(p1).p[2].hp==1 and read(p2).hp=="01 / 10 HP","nine hits")
        request(p1,"fire",1)
        r1,r2=waitPhase(p1,"Results"),waitPhase(p2,"Results")
        assert(r1.title=="Victory" and r2.title=="Defeat" and r1.visible and r2.visible and r2.bar==0)
        note("Held click fired once. Both clients saw one HP after nine hits and the correct result after ten")
        local location=request(p1,"vote")
        untilTrue(function()
            r1,r2=read(p1),read(p2)
            return r1.phase=="Results" and r2.vote=="Accept rematch"
        end,3,"first rematch vote "..location)
        request(p2,"vote")
        r1,r2=waitPhase(p1,"Countdown"),waitPhase(p2,"Countdown")
        local nextMap=require(shared.Map1).load(r1.mapId)
        assert(r1.mapId==r2.mapId and r1.mapId~=firstMap.id,"Rematch must select another map for both clients")
        assert(r1.round==2 and r2.round==2 and r1.p[2].hp==10 and r2.p[1].x==nextMap.spawns[1].X)
        waitPhase(p1,"Playing"); waitPhase(p2,"Playing")
        note("Both rematch buttons, new countdown and round-two reset verified")
        request(p2,"lane"); task.wait(.15)
        request(p2,"fire",10)
        r1,r2=waitPhase(p1,"Results"),waitPhase(p2,"Results")
        assert(r1.title=="Defeat" and r2.title=="Victory")
        channel:FireClient(p2,-1,"leave")
        waitPhase(p1,"Waiting")
        untilTrue(function() return read(p2).phase=="Lobby" and p2.Character and p2.Character:FindFirstChild("HumanoidRootPart") end,8,"Leave button returns red to the 3D lobby")
        assert(p2.Parent==players)
        note("Red won the second full duel. Leave respawned red in the 3D lobby and restored blue's Waiting room")
        test:AddPlayers(1)
        local replacement=untilTrue(function()
            for p in ready do
                if p~=p1 and p~=p2 and p~=extras[1] and p~=extras[2] and p.Parent==players then return p end
            end
        end,35,"replacement client")
        queue(replacement)
        waitPhase(p1,"Playing"); waitPhase(replacement,"Playing")
        channel:FireClient(replacement,-1,"disconnect")
        r1=waitPhase(p1,"Results")
        assert(r1.title=="Victory" and r1.vote=="Find new rival")
        request(p1,"vote"); waitPhase(p1,"Waiting")
        note("Active disconnect awarded victory; remaining player returned to Waiting")
        e1,e2=read(extras[1]),read(extras[2])
        assert(e1.phase=="Playing" and e2.phase=="Playing" and e1.round==1 and e2.round==1)
        assert(e1.p[otherSeat].hp==9 and e2.p[otherSeat].hp==9)
        note("The second lobby stayed live throughout the first lobby's rematch, Leave, replacement and disconnect")
    end
    local function stress()
        local p=untilTrue(function() return next(ready) end,45,"stress client")
        note(request(p,"batchStress"))
    end
    local driver=({["NOVA/batch1"]=batch,["NOVA/batch-stress"]=stress})[test:GetTestArgs()] or exercise
    local ok,err=xpcall(driver,debug.traceback)
    if not ok then note(tostring(err)) end
    test:EndTest({passed=ok,observations=log})
end
