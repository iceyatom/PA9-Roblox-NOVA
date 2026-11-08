return function(t)
    local Maps=require(game.ReplicatedStorage.NOVA.Map1)
    local cfg=require(game.ReplicatedStorage.NOVA.Config)
    local Match=require(game.ServerScriptService.NOVA.Match)
    local Lobbies=require(game.ServerScriptService.NOVA.Lobbies)
    t.test("reference maps compile with correct dimensions and spawns",function()
        local expected={Crossfire={2.5,16.5},Skyline={7.5,28.5},Hourglass={4.5,28.5},Nexus={7.5,28.5}}
        for id,spawn in expected do
            local map=Maps.load(id)
            assert(map.width==40 and map.height==30 and #map.body>0 and #map.shot>0 and #map.pads>0)
            assert(map.spawns[1]==Vector2.new(spawn[1],spawn[2]))
            assert(map.spawns[2]==Vector2.new(40-spawn[1],spawn[2]))
            local s=Match.new(map,cfg)
            assert(s:duelLane(),"Missing diagnostic lane in "..id)
        end
        assert(#Maps.pool()>=5)
    end)
    t.test("random rotation excludes the last map",function()
        for _,map in Maps.pool() do
            for _=1,20 do assert(Maps.choose(map.id).id~=map.id) end
        end
    end)
    t.test("shuffle locks gameplay, counts down, and resets on mutual rematch",function()
        local s=Match.new(Maps.arena,cfg,Maps.choose)
        s:join(1); assert(s.phase=="Waiting")
        s:join(2)
        local first=s.map.id
        assert(s.phase=="Selecting" and s.round==1)
        assert(not s:intent(1,1,"fire",1) and not s:intent(1,1,"move",1))
        assert(s.bodies[1].x==s.map.spawns[1].X)
        s:step(cfg.MapRollDuration-cfg.Step); assert(s.phase=="Selecting")
        s:step(cfg.Step); assert(s.phase=="Countdown" and s.round==1)
        s:step(cfg.Countdown); assert(s.phase=="Playing")
        s:finish(1,"Elimination")
        s:intent(1,1,"rematch"); s:intent(1,1,"rematch")
        assert(s.phase=="Results" and s.map.id==first)
        s:intent(2,1,"rematch")
        assert(s.phase=="Selecting" and s.round==2 and s.map.id~=first)
        assert(s.bodies[1].hp==cfg.Health and #s.bullets==0 and not next(s.votes))
        assert(not s:intent(1,1,"rematch"))
    end)
    t.test("departures cancel selection and other lobbies keep their own map",function()
        local service=Lobbies.new(Maps.arena,cfg,Maps.choose)
        for i=1,4 do service:join(i) end
        local a,b=service.membership[1].room.sim,service.membership[3].room.sim
        local map=b.map.id
        service:remove(2)
        assert(a.phase=="Waiting" and b.phase=="Selecting" and b.map.id==map)
        service:step(cfg.MapRollDuration)
        assert(a.phase=="Waiting" and b.phase=="Countdown")
        service:remove(1)
        assert(service.membership[3].room.sim==b)
    end)
end
