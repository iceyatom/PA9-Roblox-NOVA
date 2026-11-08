-- Budget: p95 below 12 ms for one 60 Hz server step with 120 live shots.
return function()
    assert(game:GetService("RunService"):IsStudio())
    local shared=game.ReplicatedStorage.NOVA
    local Match=require(game.ServerScriptService.NOVA.Match)
    local map=require(shared.Map1).arena
    local cfg=require(shared.Config)
    local times={}
    for sample=1,90 do
        local s=Match.new(map,cfg)
        s:join(1); s:join(2); s:step(3)
        s.bodies[1].x,s.bodies[1].y=14,11.5
        s.bodies[2].x,s.bodies[2].y=24,11.5
        for i=1,60 do s:intent(1,s.round,"fire",i); s:intent(2,s.round,"fire",i) end
        local start=os.clock()
        s:step(cfg.Step)
        times[sample]=(os.clock()-start)*1000
        if sample%10==0 then task.wait() end
    end
    table.sort(times)
    return {samples=#times,shots=120,medianMs=times[45],p95Ms=times[86],maxMs=times[90],passed=times[86]<12}
end
