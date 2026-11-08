return function(t)
    local Lobbies=require(game.ServerScriptService.NOVA.Lobbies)
    local map=require(game.ReplicatedStorage.NOVA.Map1).arena
    local cfg=require(game.ReplicatedStorage.NOVA.Config)
    local function make() return Lobbies.new(map,cfg) end
    local function size(items) local n=0 for _ in items do n+=1 end return n end
    t.test("seven players form three duels and one waiting lobby",function()
        local service=make()
        for i=1,7 do service:join(i) end
        assert(size(service.rooms)==4)
        for i=1,6,2 do
            local a,b=service.membership[i],service.membership[i+1]
            assert(a.room==b.room and a.seat~=b.seat and a.room.sim.phase=="Countdown")
        end
        assert(service.membership[7].room.sim.phase=="Waiting")
        assert(service:join(7)==service.membership[7] and size(service.rooms)==4)
    end)
    t.test("foreign lobby packets and stale rematch rounds are rejected",function()
        local service=make()
        for i=1,4 do service:join(i) end
        service:step(3)
        local a,b=service.membership[1].room,service.membership[3].room
        assert(not service:intent(1,b.id,1,"fire",1))
        assert(#a.sim.bullets==0 and #b.sim.bullets==0)
        assert(service:intent(1,a.id,1,"fire",1))
        assert(#a.sim.bullets==1 and #b.sim.bullets==0)
        a.sim:finish(1,"Elimination")
        service:intent(1,a.id,1,"rematch")
        assert(a.sim.phase=="Results" and b.sim.phase=="Playing")
        service:intent(2,a.id,1,"rematch")
        assert(a.sim.round==2 and b.sim.round==1)
        assert(not service:intent(1,a.id,1,"fire",2))
    end)
    t.test("waiting survivors merge and old lobby requests cannot follow them",function()
        local service=make()
        for i=1,3 do service:join(i) end
        local old=service.membership[3].room.id
        service:remove(2)
        assert(size(service.rooms)==1)
        local room=service.membership[1].room
        assert(service.membership[3].room==room and room.sim.phase=="Countdown")
        assert(not service:intent(3,old,1,"jump"))
        service:remove(1); service:remove(3)
        assert(not next(service.rooms) and not next(service.membership))
    end)
    t.test("disconnect, return to lobby and tuning stay isolated",function()
        local service=make()
        for i=1,5 do service:join(i) end
        service:step(3)
        local a,b=service.membership[1].room,service.membership[3].room
        a.sim.cfg.Speed=15
        assert(b.sim.cfg.Speed==cfg.Speed)
        service:remove(2)
        assert(a.sim.phase=="Results" and a.sim.winner==1 and b.sim.phase=="Playing")
        service:intent(1,a.id,a.sim.round,"rematch")
        assert(service.membership[1].room==service.membership[5].room)
        assert(service.membership[1].room.sim.phase=="Countdown" and b.sim.phase=="Playing")
    end)
end
