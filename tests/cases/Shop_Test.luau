return function(t)
    local shared=game.ReplicatedStorage.NOVA
    local I=require(shared.Inventory)
    local Shop=require(shared.ShopCatalog)
    local Rewards=require(shared.XPRewards)
    local now=1800000000
    local function price(id) local p=Shop.byId[id];return p.price,p.listPrice end
    t.test("shop offers match the published prices and markdowns",function()
        local expected={xp_15={99},xp_30={178,198},xp_60={317,396},
            crate2x_15={149},crate2x_30={268,298},crate2x_60={477,596},
            crates_1={49},crates_5={221,245},crates_10={392,490},crates_50={1715,2450},crates_100={2940,4900}}
        local count=0
        for id,row in expected do
            local sale,list=price(id);count+=1
            assert(sale==row[1] and list==row[2],id)
        end
        assert(count==#Shop.products)
        assert(Shop.savings(Shop.byId.xp_15)==0 and Shop.savings(Shop.byId.xp_30)==10 and Shop.savings(Shop.byId.xp_60)==20
            and Shop.savings(Shop.byId.crates_5)==10 and Shop.savings(Shop.byId.crates_50)==30 and Shop.savings(Shop.byId.crates_100)==40)
        for _,product in Shop.products do
            assert((product.minutes~=nil)~=(product.quantity~=nil) and Shop.sectionById[product.section])
            if product.quantity and product.listPrice then assert(product.listPrice==49*product.quantity) end
        end
        assert(Shop.commas(1960)=="1,960" and Shop.commas(99)=="99" and Shop.clock(905)=="15:05" and Shop.clock(3725)=="1:02:05")
    end)
    t.test("token purchases start now, stack remaining time and replay without regranting",function()
        local data=I.new()
        assert(not I.boostActive(data,"xp",now))
        local ok,receipt=I.purchase(data,"xp_15","r1",now)
        assert(ok and receipt.boost=="xp" and receipt.expires==now+900 and data.boosts.xp==now+900)
        assert(I.boostActive(data,"xp",now+899) and not I.boostActive(data,"xp",now+900) and not I.boostActive(data,"crate",now))
        local again,none,replay=I.purchase(data,"xp_15","r1",now+10)
        assert(again and none==nil and replay and data.boosts.xp==now+900)
        assert(I.purchase(data,"xp_60","r2",now+300));assert(data.boosts.xp==now+900+3600)
        -- An expired token restarts from the purchase time instead of extending the past.
        assert(I.purchase(data,"crate2x_30","r3",now));assert(I.purchase(data,"crate2x_15","r4",now+5000))
        assert(data.boosts.crate==now+5000+900)
    end)
    t.test("crate bundles add their exact quantity and survive a profile round trip",function()
        local data=I.new()
        for index,id in {"crates_1","crates_5","crates_10","crates_50","crates_100"} do
            local ok,receipt=I.purchase(data,id,"c"..index,now);assert(ok and receipt.quantity==Shop.byId[id].quantity)
        end
        assert(data.owned.crate_season1==166)
        assert(I.purchase(data,"xp_30","x",os.time()))
        local saved=assert(I.validate(data))
        assert(saved.owned.crate_season1==166 and saved.boosts.xp==data.boosts.xp and saved.purchases.c3 and #saved.purchaseOrder==6)
        local ok,_,replay=I.purchase(saved,"crates_100","c5",now);assert(ok and replay and saved.owned.crate_season1==166)
    end)
    t.test("invalid purchases change nothing and the receipt ledger is bounded",function()
        local data=I.new()
        assert(not I.purchase(data,"crates_2","a",now) and not I.purchase(data,"xp_15","",now)
            and not I.purchase(data,"xp_15",5,now) and not I.purchase(data,"xp_15",string.rep("x",129),now))
        assert(not next(data.purchases) and data.boosts.xp==0 and not data.owned.crate_season1)
        data.owned.crate_season1=2999950
        assert(not I.purchase(data,"crates_100","full",now) and data.owned.crate_season1==2999950)
        data.owned.crate_season1=nil
        for index=1,Shop.LedgerLimit+5 do assert(I.purchase(data,"crates_1","p"..index,now)) end
        assert(#data.purchaseOrder==Shop.LedgerLimit and not data.purchases.p5 and data.purchases.p6 and data.owned.crate_season1==Shop.LedgerLimit+5)
        for _,bad in {{boosts={xp=-1}},{boosts={xp=.5}},{boosts="x"},{purchases={a=true},purchaseOrder={}},{purchases={},purchaseOrder={"a"}}} do
            local raw=I.new();for key,value in bad do raw[key]=value end
            assert(not I.validate(raw))
        end
    end)
    t.test("an active Double Crates token doubles a crate won from a match",function()
        local expires=os.time()+86400
        local data=I.new()
        local ok,receipt=I.matchReward(data,"plain",expires,"win",0,now)
        assert(ok and receipt.awarded and receipt.crates==nil and data.owned.crate_season1==1)
        assert(I.purchase(data,"crate2x_15","boost",now))
        ok,receipt=I.matchReward(data,"double",expires,"win",0,now+60)
        assert(ok and receipt.awarded and receipt.crates==2 and data.owned.crate_season1==3)
        local _,replayed,replay=I.matchReward(data,"double",expires,"win",0,now+60)
        assert(replay and replayed.crates==2 and data.owned.crate_season1==3)
        -- Misses and losses stay crate-free, and an expired token pays one crate.
        ok,receipt=I.matchReward(data,"miss",expires,"win",.99,now+60);assert(ok and not receipt.awarded and receipt.crates==nil)
        data.crateChance=100
        ok,receipt=I.matchReward(data,"late",expires,"win",.5,now+900);assert(ok and receipt.awarded and receipt.crates==nil and data.owned.crate_season1==4)
        local saved=assert(I.validate(data));assert(saved.dropReceipts.double.crates==2)
        saved.dropReceipts.miss.crates=2;assert(not I.validate(saved))
    end)
    t.test("a Double XP token adds one itemized row equal to the duel's XP",function()
        local function total(items) local sum=0;for _,item in items do sum+=item.amount end;return sum end
        assert(total(Rewards.items(true))==300 and total(Rewards.items(false))==100)
        local win=Rewards.items(true,true)
        assert(total(win)==600 and #win==3 and win[3].label=="Double XP token" and win[3].amount==300)
        assert(total(Rewards.items(false,true))==200)
    end)
end
