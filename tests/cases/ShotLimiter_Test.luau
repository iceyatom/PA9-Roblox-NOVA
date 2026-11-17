return function(t)
    local L=require(game.ServerScriptService.NOVA.ShotLimiter)
    local function test(name,fn)
        t.test(name,function()
            local original=L.getRate()
            L.setRate(12)
            local ok,err=pcall(fn)
            L.setRate(original)
            assert(ok,err)
        end)
    end
    test("fire cap accepts exactly twelve evenly spaced shots in a second",function()
        local state={};local accepted=0
        for tick=0,119 do if L.allow(state,tick/120) then accepted+=1 end end
        assert(accepted==12)
        assert(L.allow(state,1))
    end)
    test("fire cap drops simultaneous bursts and cannot bank shots while idle",function()
        local state={}
        assert(L.allow(state,0))
        for _=1,1000 do assert(not L.allow(state,0)) end
        assert(not L.allow(state,1/12-.000001))
        assert(L.allow(state,1/12))
        assert(L.allow(state,100))
        assert(not L.allow(state,100))
        assert(L.allow({},100))
    end)
    test("live rate changes apply to existing limiter state",function()
        local state={};assert(L.allow(state,0))
        assert(L.setRate(6) and not L.allow(state,1/12))
        assert(L.allow(state,1/6))
        assert(L.setRate(24) and L.allow(state,1/6+1/24))
    end)
    test("malformed rates never disable the firing cap",function()
        for _,value in {0,-1,1.5,61,math.huge,-math.huge,0/0,"12",{},false} do
            assert(not L.setRate(value) and L.getRate()==12)
        end
        assert(not L.setRate(nil))
        assert(L.setRate(1) and L.setRate(60))
        for _,now in {math.huge,-math.huge,0/0,"1"} do assert(not L.allow({},now)) end
    end)
end
