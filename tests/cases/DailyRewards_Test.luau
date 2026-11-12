return function(t)
    local shared=game.ReplicatedStorage.NOVA
    local Daily=require(shared.DailyRewards)
    local I=require(shared.Inventory)
    local Store=require(game.ServerScriptService.NOVA.InventoryStore)
    local midnight=20000*86400
    local function claim(data,now) return I.checkIn(data,"daily:"..(data.daily.sequence+1),now) end
    t.test("daily schedule matches all 30 rewards and the ongoing 10-crate reward",function()
        local expected={
            {"crate_season1",1},{"token_xp_15",1},{"token_crate_15",1},{"crate_season1",1},{"token_xp_15",1},{"token_crate_15",2},{"crate_season1",1},
            {"crate_season1",2},{"token_xp_30",1},{"token_crate_30",1},{"crate_season1",2},{"token_xp_30",1},{"token_crate_30",2},{"crate_season1",2},
            {"crate_season1",4},{"token_xp_60",1},{"token_crate_60",1},{"crate_season1",4},{"token_xp_60",1},{"token_crate_60",2},{"crate_season1",4},
            {"crate_season1",8},{"token_xp_60",2},{"token_crate_60",2},{"crate_season1",8},{"token_xp_60",2},{"token_crate_60",4},{"crate_season1",10},
            {"crate_season1",10},
        }
        for day,row in expected do
            local reward=assert(Daily.reward(day));assert(reward.id==row[1] and reward.quantity==row[2],"Day "..day)
        end
        assert(Daily.reward(30).kind=="pack")
        for _,day in {31,32,60,365,10000} do assert(Daily.reward(day).id=="crate_season1" and Daily.reward(day).quantity==10) end
        assert(not Daily.reward(0) and not Daily.reward(1.5) and not Daily.reward(0/0))
    end)
    t.test("UTC check-ins allow midnight and reject multiple claims in one date",function()
        local data=I.new()
        assert(claim(data,midnight+86399))
        assert(not claim(data,midnight+86399))
        assert(claim(data,midnight+86400))
        assert(data.daily.day==2 and data.owned.token_xp_15==1 and data.boosts.xp==0)
        assert(not claim(data,midnight+86400*2-1))
        assert(Daily.status(data,midnight+86400*2-1).unlockAt==midnight+86400*2)
    end)
    t.test("a full missed UTC day resets the streak exactly at midnight",function()
        local data=I.new();assert(claim(data,midnight+1))
        assert(Daily.status(data,midnight+2*86400-1).day==2)
        local status=Daily.status(data,midnight+2*86400)
        assert(status.reset and status.claimable and status.day==1)
        assert(claim(data,midnight+2*86400))
        assert(data.daily.day==1 and data.daily.sequence==2 and data.owned.crate_season1==2)
        assert(not claim(data,midnight-86400)) -- server clock rollback cannot unlock a reward
    end)
    t.test("daily request keys reject replay and stale requests even on another UTC day",function()
        local data=I.new();assert(I.checkIn(data,"daily:1",midnight+1))
        assert(not I.checkIn(data,"daily:1",midnight+86400))
        assert(not I.checkIn(data,"daily:3",midnight+86400))
        assert(not I.checkIn(data,{},midnight+86400))
        assert(not I.checkIn(data,"daily:2",0/0))
        assert(data.daily.day==1 and data.daily.sequence==1 and data.owned.crate_season1==1)
    end)
    t.test("full month grants stored tokens and continues with ten crates per day",function()
        local data=I.new()
        for day=1,32 do
            local ok,reward=claim(data,midnight+(day-1)*86400+1)
            assert(ok and reward.day==day);data=assert(I.validate(data))
        end
        assert(data.daily.day==32 and data.daily.packEarned and not data.daily.packDelivered)
        assert(data.owned.crate_season1==77)
        assert(data.owned.token_xp_15==2 and data.owned.token_xp_30==2 and data.owned.token_xp_60==6)
        assert(data.owned.token_crate_15==3 and data.owned.token_crate_30==3 and data.owned.token_crate_60==9)
        assert(data.boosts.xp==0 and data.boosts.crate==0)
        assert(I.useToken(data,"token_xp_60",midnight+32*86400))
        assert(data.boosts.xp==midnight+32*86400+3600)
        assert(claim(data,midnight+34*86400))
        assert(data.daily.day==1 and data.daily.packEarned and data.owned.crate_season1==78)
    end)
    t.test("daily migration and validation preserve progress and reject corrupt streaks",function()
        local data=I.new();data.daily=nil
        assert(I.validate(data).daily.day==0)
        for _,bad in {false,{}, {day=1,lastClaim=0,sequence=1,packEarned=false,packDelivered=false},
            {day=30,lastClaim=midnight,sequence=30,packEarned=false,packDelivered=false},
            {day=1,lastClaim=midnight,sequence=1,packEarned=false,packDelivered=true}} do
            data.daily=bad;assert(not I.validate(data))
        end
        data=I.new();assert(claim(data,midnight));local copy=assert(I.validate(data))
        copy.daily.day=2;assert(data.daily.day==1)
    end)
    t.test("inventory capacity failures leave the reward and streak unmodified",function()
        local data=I.new();data.owned.crate_season1=3000000
        assert(not claim(data,midnight) and data.daily.sequence==0)
        data.owned.crate_season1=0;assert(claim(data,midnight))
        data.owned.token_xp_15=1000000
        assert(not claim(data,midnight+86400) and data.daily.day==1 and data.owned.token_xp_15==1000000)
    end)
    t.test("day 30 pack entitlement survives reset and delivers all cosmetics once on release",function()
        local data=I.new()
        for day=1,30 do assert(claim(data,midnight+(day-1)*86400)) end
        assert(claim(data,midnight+40*86400))
        local previous=Daily.PackItems
        local ok,message=pcall(function()
            Daily.PackItems={"skin_mint","missing_daily_pack_item"}
            local held=assert(I.validate(data));assert(not held.daily.packDelivered and not held.owned.skin_mint)
            Daily.PackItems={"skin_mint"}
            local delivered=assert(I.validate(held));assert(delivered.daily.packDelivered and delivered.owned.skin_mint==1)
            assert(I.validate(delivered).owned.skin_mint==1)
        end)
        Daily.PackItems=previous;assert(ok,message)
    end)
    t.test("daily grant and streak persist together through reconnect and an ambiguous save",function()
        local values={};local storage={};local failAfter=false
        function storage:UpdateAsync(key,callback)
            local value=callback(values[key]);if value then values[key]=value end
            if failAfter then error("Response lost after committing") end
            return value
        end
        local a=Store.new(storage,"a",function() return midnight end)
        local profile=assert(a:load(1));assert(claim(profile.data,midnight))
        failAfter=true;assert(not a:save(1,profile,false))
        failAfter=false;assert(a:save(1,profile,true))
        local b=Store.new(storage,"b",function() return midnight+1 end)
        local loaded=assert(b:load(1));assert(loaded.data.daily.day==1 and loaded.data.owned.crate_season1==1)
        assert(not I.checkIn(loaded.data,"daily:1",midnight+86400))
        assert(claim(loaded.data,midnight+86400));assert(loaded.data.owned.token_xp_15==1)
    end)
end
