return function(t)
    local C=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
    local I=require(game.ReplicatedStorage.NOVA.Inventory)
    local Store=require(game.ServerScriptService.NOVA.InventoryStore)
    local function retired(fn)
        local previous=C.retired
        C.retired={skin_mint={name="Mint Circuit",rarity="Rare",category="skins"},
            skin_ember={name="Ember Core",rarity="Epic",category="skins"},
            retired_crate_fixture={name="Test Crate",rarity="Epic",category="crates"}}
        local ok,err=pcall(fn); C.retired=previous; assert(ok,err)
    end
    t.test("retirement removes owned equipped and favorite items and credits duplicate values once",function() retired(function()
        local raw=I.new(); raw.shards=7; raw.owned={skin_mint=1,skin_ember=1,retired_crate_fixture=3,unknown_future_item=1}
        raw.equipped.skins="skin_mint"; raw.favorites.skin_mint=true
        local data=assert(I.validate(raw))
        assert(data.shards==7+25+60+180 and data.equipped.skins==C.defaults.skins)
        assert(not data.owned.skin_mint and not data.owned.retired_crate_fixture and not data.favorites.skin_mint)
        assert(data.owned.unknown_future_item==1 and data.retirementNotice.totalShards==265 and #data.retirementNotice.items==3)
        for i=1,20 do data=assert(I.validate(data)); assert(data.shards==272 and data.retirementSequence==1) end
        assert(raw.owned.skin_mint==1 and raw.shards==7)
    end) end)
    t.test("equipped-only deleted cosmetic is compensated once and favorite-only items are not",function() retired(function()
        local raw=I.new(); raw.equipped.skins="skin_mint"; raw.favorites.skin_ember=true
        local data=assert(I.validate(raw)); assert(data.shards==25 and #data.retirementNotice.items==1)
        assert(I.validate(data).shards==25)
    end) end)
    t.test("retirement notices persist until acknowledged and stale acknowledgments cannot clear new notices",function() retired(function()
        local raw=I.new(); raw.owned.skin_mint=1
        local data=assert(I.validate(raw)); local first=data.retirementNotice.sequence
        data.owned.skin_ember=1; data=assert(I.validate(data))
        assert(data.retirementNotice.sequence==first+1 and data.retirementNotice.totalShards==85)
        assert(not I.ackRetirements(data,tostring(first)))
        assert(I.ackRetirements(data,tostring(first+1)))
        data=assert(I.validate(data)); assert(data.shards==85 and not data.retirementNotice)
        local ok,_,replay=I.ackRetirements(data,tostring(first+1)); assert(ok and replay)
    end) end)
    t.test("retirement credit and notice commit atomically despite UpdateAsync callback retries",function() retired(function()
        local raw=I.new(); raw.owned.skin_mint=1; raw.equipped.skins="skin_mint"
        local saved={schema=1,data=raw}; local storage={}
        function storage:UpdateAsync(_,callback)
            local first=callback(saved); local second=callback(saved)
            if first then assert(first.data.shards==second.data.shards) end
            if second then saved=second end
            return second
        end
        local a=Store.new(storage,"a",function() return 1000 end)
        local profile=assert(a:load(5)); assert(saved.data.shards==25 and saved.data.retirementNotice.totalShards==25)
        assert(a:save(5,profile,true))
        local b=Store.new(storage,"b",function() return 1001 end)
        profile=assert(b:load(5)); assert(profile.data.shards==25 and profile.data.retirementNotice)
        assert(I.ackRetirements(profile.data,tostring(profile.data.retirementSequence)))
        assert(b:save(5,profile,true))
        assert(not a:load(5).data.retirementNotice and saved.data.shards==25)
    end) end)
    t.test("failed retirement loads leave original data for a later safe retry",function() retired(function()
        local raw=I.new(); raw.owned.skin_ember=1
        local saved={schema=1,data=raw}; local storage={fail=true}
        function storage:UpdateAsync(_,callback)
            local value=callback(saved)
            if self.fail then error("write failed") end
            if value then saved=value end; return value
        end
        local store=Store.new(storage,"a",function() return 1000 end)
        assert(not store:load(1) and saved.data.shards==0 and saved.data.owned.skin_ember==1)
        storage.fail=false; local data=assert(store:load(1)).data
        assert(data.shards==60 and not data.owned.skin_ember)
    end) end)
    t.test("retirement wallet cap reports the actual credit and malformed notices never load",function() retired(function()
        local raw=I.new(); raw.shards=999999990; raw.owned.skin_mint=1
        local data=assert(I.validate(raw)); assert(data.shards==1000000000 and data.retirementNotice.totalShards==10)
        data.retirementNotice.totalShards=25; assert(not I.validate(data))
        raw=I.new(); raw.retirementSequence=-1; assert(not I.validate(raw))
    end) end)
end
