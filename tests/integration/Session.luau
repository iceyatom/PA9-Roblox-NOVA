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
        local probe=script.Parent.Probe:Clone(); probe.Name="NOVAProbe"; probe.Parent=gui
    end
    players.PlayerAdded:Connect(install)
    for _,p in players:GetPlayers() do task.spawn(install,p) end
    local function request(p,cmd,arg)
        id+=1; local n=id
        results[n]={owner=p}
        channel:FireClient(p,n,cmd,arg)
        local ans=untilTrue(function() return results[n].answer end,7,cmd.." from "..p.Name)
        results[n]=nil
        assert(ans[1],tostring(ans[2])); return ans[2]
    end
    local function read(p) return request(p,"read") end
    local function waitPhase(p,phase)
        return untilTrue(function() local r=read(p); return r.phase==phase and r end,12,phase)
    end
    local function exercise()
        local p1=untilTrue(function() return next(ready) end,35,"first client ready")
        untilTrue(function() local r=read(p1); return r.hud:find("LOBBY") and r.visible end,5,"waiting screen")
        note("One real client displayed Waiting")
        test:AddPlayers(1)
        local p2=untilTrue(function() for p in ready do if p~=p1 then return p end end end,40,"second client ready")
        local r1,r2=waitPhase(p1,"Playing"),waitPhase(p2,"Playing")
        assert(r1.seat==1 and r2.seat==2 and r1.round==r2.round)
        assert(r1.seen.Countdown and r2.seen.Countdown,"Missing countdown on client")
        assert(r1.p[1].x==6.5 and r2.p[2].x==31.5 and r1.p[1].hp==10 and r2.p[2].hp==10)
        note("Both clients saw the same countdown, seats, spawns and full health")
        request(p1,"keys","D"); request(p2,"keys","A"); task.wait(.12)
        r1,r2=read(p1),read(p2)
        assert(r1.p[1].x>6.5 and r2.p[2].x<31.5,"WASD movement")
        request(p1,"keys","W"); request(p2,"keys","W"); request(p1,"keys","S"); request(p2,"keys","S")
        note("Two clients drove movement through keyboard events")
        request(p1,"lane"); task.wait(.2)
        request(p1,"forged"); task.wait(.15)
        assert(read(p2).p[2].hp==10)
        request(p1,"hold"); task.wait(.55)
        assert(read(p1).p[2].hp==9 and read(p2).p[2].hp==9,"hold must emit exactly one shot")
        request(p1,"fire",8); task.wait(.7)
        assert(read(p1).p[2].hp==1 and read(p2).hp=="01 / 10 HP","nine hits")
        request(p1,"fire",1)
        r1,r2=waitPhase(p1,"Results"),waitPhase(p2,"Results")
        assert(r1.title=="Victory" and r2.title=="Defeat" and r1.visible and r2.visible and r2.bar==0)
        note("Held click fired once. Both clients saw one HP after nine hits and the correct result after ten")
        request(p1,"vote"); task.wait(.15)
        assert(read(p1).phase=="Results" and read(p2).vote=="Accept rematch")
        request(p2,"vote")
        r1,r2=waitPhase(p1,"Countdown"),waitPhase(p2,"Countdown")
        assert(r1.round==2 and r2.round==2 and r1.p[2].hp==10 and r2.p[1].x==6.5)
        waitPhase(p1,"Playing"); waitPhase(p2,"Playing")
        note("Both rematch buttons, new countdown and round-two reset verified")
        channel:FireClient(p2,-1,"disconnect")
        r1=waitPhase(p1,"Results")
        assert(r1.title=="Victory" and r1.vote=="Return to lobby")
        request(p1,"vote"); waitPhase(p1,"Waiting")
        note("Active disconnect awarded victory; remaining player returned to Waiting")
    end
    local ok,err=xpcall(exercise,debug.traceback)
    if not ok then note(tostring(err)) end
    test:EndTest({passed=ok,observations=log})
end
