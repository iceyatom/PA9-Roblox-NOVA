return function(t)
    local Info=require(game.ReplicatedStorage.NOVA.ProgressionInfo)
    local P=require(game.ReplicatedStorage.NOVA.Progression)
    t.test("new players can inspect every rank but cannot claim a prestige",function()
        local d=P.new()
        assert(Info.current(d)==1 and Info.next(d)==2 and Info.status(d,1)=="Current")
        assert(Info.status(d,2)=="Next" and Info.status(d,12)=="Locked" and Info.fraction(d,2)==0)
        for i=1,12 do assert(not Info.canClaim(d,i)) end
        assert(Info.requirement(2)=="Prestige 0 · Level 55")
    end)
    t.test("every numbered prestige unlocks only from its previous level cap",function()
        local d=P.new()
        for i=2,11 do
            d.level=54
            assert(not Info.canClaim(d,i) and Info.fraction(d,i)<1)
            d.level=55
            assert(Info.canClaim(d,i) and Info.status(d,i)=="Ready" and Info.fraction(d,i)==1)
            assert(not Info.canClaim(d,i+1))
            P.prestige(d)
            assert(Info.current(d)==i and Info.status(d,i)=="Current")
        end
    end)
    t.test("Master requires Prestige 10 level 55 and remains the final rank",function()
        local d={level=55,prestige=10,master=false,xp=0,totalXP=10000}
        assert(Info.next(d)==12 and Info.canClaim(d,12))
        assert(Info.requirement(12)=="Prestige 10 · Level 55")
        P.prestige(d)
        assert(Info.current(d)==12 and Info.next(d)==nil and not Info.canClaim(d,12))
        assert(Info.status(d,11)=="Unlocked" and Info.status(d,12)=="Current")
    end)
    t.test("unloaded progression cannot unlock cards or actions",function()
        assert(Info.current(nil)==0 and Info.next(nil)==nil and Info.fraction(nil,1)==0)
        assert(Info.status(nil,1)=="Locked" and not Info.canClaim(nil,2))
    end)
end
