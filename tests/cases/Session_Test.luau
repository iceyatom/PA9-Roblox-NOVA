return function(t)
    local F=require(script.Parent.Parent.Fixture)
    local Lobbies=require(game.ServerScriptService.NOVA.Lobbies)
    local map=require(game.ReplicatedStorage.NOVA.Map1).arena
    local cfg=require(game.ReplicatedStorage.NOVA.Config)
    local function rematch(s)
        assert(s:intent(1,s.round,"rematch") and s:intent(2,s.round,"rematch"))
        s:step(s.cfg.Countdown)
    end
    local function finalRoom()
        local service=Lobbies.new(map,cfg)
        service:join("a");service:join("b");service:step(cfg.Countdown)
        local room=service.membership.a.room
        for game=1,11 do
            room.sim:finish(game%2+1,"Elimination")
            if game<11 then rematch(room.sim) end
        end
        return service,room
    end
    t.test("session tally includes the first game and carries wins and draws over rematches",function()
        local s=F.duel()
        assert(s:sessionView(100).game==1 and s.session.played==0)
        for game,winner in {1,2,0,1} do
            s:finish(winner,"Elimination");s:finish(winner,"Elimination")
            assert(s.session.played==game)
            local view=s:sessionView(100);assert(view.game==game and not view.complete)
            s:intent(1,s.round,"rematch");s:intent(1,s.round,"rematch")
            assert(s.session.played==game and s.phase=="Results")
            s:intent(2,s.round,"rematch");s:step(cfg.Countdown)
            assert(s:sessionView(100).game==game+1)
        end
        assert(s.session.wins[1]==2 and s.session.wins[2]==1 and s.session.draws==1)
        local view=s:sessionView(100);view.wins[1]=999
        assert(s.session.wins[1]==2)
    end)
    t.test("eleven total games end the session even when some games are draws",function()
        local s=F.duel();local rounds=0
        s.finished=function() rounds+=1 end
        for game=1,11 do
            s:finish(game%3,"Elimination")
            assert(s.session.played==game and s.session.complete==(game==11))
            if game<11 then rematch(s) end
        end
        assert(rounds==11 and s.session.wins[1]+s.session.wins[2]+s.session.draws==11)
        local round=s.round
        for _=1,5 do
            assert(not s:intent(1,round,"rematch") and not s:intent(2,round,"rematch"))
            assert(s:startRound()==false)
        end
        assert(s.round==round and s.phase=="Results" and s.session.played==11)
        assert(s:sessionView(100).returnAt==100+cfg.SessionReturnDelay)
    end)
    t.test("changing opponents resets the score without reusing round receipt IDs",function()
        local s=F.duel();s:finish(1,"Elimination");rematch(s);s:finish(1,"Elimination")
        local round=s.round;s:depart(2);assert(s.phase=="Waiting")
        s:join("new rival")
        assert(s.round>round and s.session.played==0 and s.session.wins[1]==0 and s:sessionView(100).game==1)
    end)
    t.test("an early departure adds no game and a combat disconnect adds one",function()
        local s=F.duel();s:finish(1,"Elimination");rematch(s);s:depart(2)
        assert(s.session.played==2 and s.session.wins[1]==2)
        assert(s:intent(1,s.round,"rematch") and s.session.played==0)
        s:join("new rival");s:depart(2)
        assert(s.phase=="Waiting" and s.session.played==0)
    end)
    t.test("session limit automatically releases both seats without pairing them into waiting rooms",function()
        local service,room=finalRoom();local returned={}
        service:join("waiting")
        service.sessionEnded=function(player)
            assert(not service.membership.a and not service.membership.b)
            returned[player]=(returned[player] or 0)+1
        end
        assert(not service:closeSession(room))
        service:step(cfg.SessionReturnDelay-1);assert(service.membership.a and not returned.a)
        service:step(1)
        assert(returned.a==1 and returned.b==1 and not service.membership.a and not service.membership.b)
        assert(not service.rooms[room.id] and not service.dirty[room.id])
        assert(service.membership.waiting.room.sim.phase=="Waiting")
        service:step(10);assert(returned.a==1 and returned.b==1)
        local fresh=service:join("a");assert(fresh.room.sim.session.played==0)
        assert(not service:intent("a",room.id,11,"rematch"))
    end)
    t.test("leaving the final result cannot reopen a seat or cancel the other player's return",function()
        local service,room=finalRoom();local returned={}
        service.sessionEnded=function(player) table.insert(returned,player) end
        service:remove("a");assert(room.sim.phase=="Results" and room.sim.session.complete)
        assert(not room.sim:join("replacement"))
        assert(not service:intent("b",room.id,room.sim.round,"rematch"))
        service:join("a");local fresh=service.membership.a.room
        assert(fresh~=room and fresh.sim.phase=="Waiting")
        service:step(cfg.SessionReturnDelay)
        assert(#returned==1 and returned[1]=="b" and service.membership.a.room==fresh)
    end)
    t.test("session scores and forced returns stay isolated across simultaneous duels",function()
        local service,room=finalRoom()
        service:join("c");service:join("d");service:step(cfg.Countdown)
        local other=service.membership.c.room
        service:step(cfg.SessionReturnDelay)
        assert(not service.rooms[room.id] and service.membership.c.room==other and other.sim.phase=="Playing")
        assert(other.sim.session.played==0 and other.sim.session.wins[1]==0)
    end)
end
