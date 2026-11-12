return function(t)
    local Store=require(game.ServerScriptService.NOVA.InventoryStore)
    local I=require(game.ReplicatedStorage.NOVA.Inventory)
    local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
    local function fixture()
        local values={}; local storage={fail=false}; local time=1000
        function storage:UpdateAsync(key,callback)
            if self.fail then error("Storage unavailable") end
            local value=callback(values[key]); if value then values[key]=value end; return value
        end
        return values,storage,function() return time end,function(seconds) time+=seconds end
    end
    t.test("inventory equipment favorites crate receipts and shards survive release/rejoin",function()
        local _,storage,now=fixture(); local a,b=Store.new(storage,"a",now),Store.new(storage,"b",now)
        local r=assert(a:load(1)); I.grant(r.data,"crate_season1",3)
        I.open(r.data,"crate_season1","a",0); I.open(r.data,"crate_season1","b",0)
        I.equip(r.data,"skin_mint"); I.favorite(r.data,"skin_mint")
        assert(a:save(1,r,true))
        local d=assert(b:load(1)).data
        assert(d.equipped.skins=="skin_mint" and d.favorites.skin_mint and d.shards==Catalog.duplicateValues[Catalog.byId.skin_mint.rarity] and d.owned.crate_season1==1 and d.receipts.a)
    end)
    t.test("inventory session lease rejects concurrent sessions and stale saves",function()
        local values,storage,now,advance=fixture(); local a,b=Store.new(storage,"a",now),Store.new(storage,"b",now)
        local old=assert(a:load(1)); assert(not b:load(1))
        advance(181); assert(b:load(1)); I.grant(old.data,"crate_season1",5)
        assert(not a:save(1,old,false) and not a:save(1,old,true) and values["1"].owner=="b")
    end)
    t.test("inventory invalid saves and outages cannot overwrite stored profiles",function()
        local values,storage,now=fixture(); local a=Store.new(storage,"a",now)
        values["1"]={schema=2,data={future=true}}; assert(not a:load(1) and values["1"].schema==2)
        storage.fail=true; assert(not a:load(2) and not values["2"])
        storage.fail=false; local r=assert(a:load(2)); I.grant(r.data,"crate_season1",5)
        storage.fail=true; assert(not a:save(2,r,false) and r.data.owned.crate_season1==5)
        storage.fail=false; assert(a:save(2,r,false) and values["2"].data.owned.crate_season1==5)
    end)
    t.test("crate chance and match-drop receipts persist across lease release and rejoin",function()
        local _,storage,now=fixture();local a,b=Store.new(storage,"a",now),Store.new(storage,"b",now)
        local profile=assert(a:load(7))
        assert(I.matchReward(profile.data,"win/miss",os.time()+86400,"win",.8))
        assert(I.matchReward(profile.data,"loss/boost",os.time()+86400,"loss"))
        assert(profile.data.crateChance==45 and a:save(7,profile,true))
        local data=assert(b:load(7)).data
        assert(data.crateChance==45 and data.dropReceipts["win/miss"].landing==.8)
        local ok,_,replay=I.matchReward(data,"loss/boost",os.time()+86400,"loss")
        assert(ok and replay and data.crateChance==45)
        assert(I.matchReward(data,"next/win",os.time()+86400,"win",.44))
        assert(data.crateChance==25 and data.owned.crate_season1==1)
    end)

end
