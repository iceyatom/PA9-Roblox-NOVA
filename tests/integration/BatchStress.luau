-- Studio-only, synthetic rendering fixture. It never changes live match firing rules.
return function(playerGui)
    local player=game.Players.LocalPlayer
    local arenaModule=require(player.PlayerScripts.NOVA.Arena)
    local cfg=require(game.ReplicatedStorage.NOVA.Config)
    local render=game:GetService("RunService").RenderStepped
    local host=Instance.new("ScreenGui"); host.Name="BatchStress"; host.DisplayOrder=20; host.IgnoreGuiInset=true
    host.Parent=playerGui
    local stage=Instance.new("Frame"); stage.Size=UDim2.fromOffset(1440,810); stage.Parent=host
    local scale=Instance.new("UIScale")
    scale.Scale=math.min(host.AbsoluteSize.X/1440,host.AbsoluteSize.Y/810); scale.Parent=stage
    local arena=arenaModule.new(stage)
    local cosmetics={}
    for _,category in {"skins","bullets","tracers","backgrounds","sounds"} do cosmetics[category]="b1_"..category.."_crimson_singularity" end
    local snap={lobby=1,round=1,players={},phase="Playing",shots={},maxHP=10}
    for i=1,2 do snap.players[i]={x=5+12*i,y=8,hp=10,uid=i,name="Test "..i,cosmetics=cosmetics} end
    local shots={}
    for i=1,200 do shots[i]={i,4+i%20,3+math.floor((i-1)/20),i%2+1,10,0} end
    snap.shots=shots
    local frames,costs={},{}
    local start=os.clock()
    local snapshotClock=0
    local viewport=workspace.CurrentCamera.ViewportSize
    local peakTails=0
    while os.clock()-start<60 do
        local dt=render:Wait()
        local now=os.clock()
        local elapsed=now-start
        snap.round=math.min(20,1+math.floor(elapsed/3))
        local before=os.clock()
        snapshotClock+=dt
        if snapshotClock>=1/cfg.SnapshotRate or not arena.received then
            snapshotClock=0
            for i,b in shots do b[2]=3+i%20+(elapsed%3)*2 end
            arena:update(snap,now)
        end
        arena:draw(now,dt)
        table.insert(costs,(os.clock()-before)*1000)
        table.insert(frames,dt*1000)
        peakTails=math.max(peakTails,arena.tailCount)
    end
    local cores=0
    for _,s in arena.shots do assert(s.frame.Parent); cores+=1 end
    assert(cores==200 and peakTails<=128)
    arena:clearShots()
    assert(not next(arena.shots) and #arena.tailPool==arena.tailCount)
    for _,node in arena.tailPool do assert(not node.Visible) end
    table.sort(costs); table.sort(frames)
    local n=math.ceil(#costs*.95)
    local result=("Studio %dx%d, 60 s, 200 cores, 20 rounds, %d pooled trails, p95 frame %.2f ms, p95 renderer %.2f ms, cleanup passed"):format(
        viewport.X,viewport.Y,peakTails,frames[n],costs[n])
    host:Destroy()
    return result
end
