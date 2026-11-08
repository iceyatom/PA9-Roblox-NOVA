return function(t)
    local F=require(script.Parent.Parent.Fixture)
    t.test("completed rounds issue rewards once even after repeated finish and departure",function()
        local sim=F.duel()
        local calls=0
        sim.finished=function(s) calls+=1; assert(s.phase=="Results" and s.winner==1) end
        sim:finish(1,"Elimination")
        sim:finish(2,"Elimination")
        sim:depart(2)
        assert(calls==1)
    end)
    t.test("a real rematch can issue its own reward",function()
        local sim=F.duel()
        local calls=0
        sim.finished=function(s) calls+=1; s.rewards[1]=300; s.xpRecaps[1]={total=300} end
        sim:finish(1,"Elimination")
        sim:intent(1,sim.round,"rematch"); sim:intent(2,sim.round,"rematch")
        assert(not next(sim.rewards) and not next(sim.xpRecaps))
        sim:step(sim.cfg.Countdown)
        sim:finish(1,"Elimination")
        assert(calls==2 and sim.rewards[1]==300)
    end)
    t.test("disconnect rewards only the survivor and early departures give no rewards",function()
        local sim=F.duel()
        local calls=0
        sim.finished=function(s)
            calls+=1
            assert(s.winner==1 and s.reason=="Disconnect" and s.seats[1] and not s.seats[2])
        end
        sim:depart(2)
        assert(calls==1)
        sim=F.duel(); sim:reset("Countdown")
        sim.finished=function() error("No reward before combat") end
        sim:depart(2)
    end)
    t.test("draws finish once with no winning seat",function()
        local sim=F.duel()
        local calls=0
        sim.finished=function(s) calls+=1; assert(s.winner==0) end
        sim:finish(0,"Elimination"); sim:finish(0,"Elimination")
        assert(calls==1)
    end)
end
