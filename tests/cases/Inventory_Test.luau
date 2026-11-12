return function(t)
    local I=require(game.ReplicatedStorage.NOVA.Inventory)
    local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
    t.test("crate contents sort by descending rarity then collection before chance",function()
        local original=Catalog.byId
        Catalog.byId={
            cosmic={id="cosmic",name="Cosmic",rarity="Cosmic"},
            alpha={id="alpha",name="Alpha",rarity="Epic",collectionId="z-id",collectionName="Alpha"},
            alphaRare={id="alphaRare",name="Alpha rare",rarity="Epic",collectionId="z-id",collectionName="Alpha"},
            beta={id="beta",name="Beta",rarity="Epic",collectionId="a-id",collectionName="Beta"},
            loose={id="loose",name="Loose",rarity="Epic"},
            common={id="common",name="Common",rarity="Common",collectionId="z-id",collectionName="Alpha"},
        }
        local ok,entries=pcall(Catalog.crateContents,{rewards={
            {id="common",weight=1},{id="loose",weight=1},{id="beta",weight=1},
            {id="alpha",weight=30},{id="cosmic",weight=50},{id="alphaRare",weight=17},
        }})
        Catalog.byId=original
        assert(ok,entries)
        for index,id in {"cosmic","alphaRare","alpha","beta","loose","common"} do
            assert(entries[index].item.id==id,"Unexpected collection/rarity order")
        end
        assert(entries[3].percent==30,"Sorting must preserve drop chances")
    end)
    t.test("multi crate opening validates balances and replays after reload without spending twice",function()
        for _,count in {3,5} do
            local d=I.new();I.grant(d,"crate_season1",count)
            local rolls={};for _=1,count do table.insert(rolls,0) end
            local ok,receipts=I.openMany(d,"crate_season1","open:1",count,rolls)
            assert(ok and #receipts==count and d.openSequence==count and not d.owned.crate_season1)
            assert(not receipts[1].duplicate and receipts[2].duplicate)
            local shards=d.shards;d=assert(I.validate(d))
            local replay,results,cached=I.openMany(d,"crate_season1","open:1",count,{})
            assert(replay and cached and #results==count and d.shards==shards and d.openSequence==count)
            assert(not I.open(d,"crate_season1","open:1",0))
            assert(not I.openMany(d,"crate_season1","open:1",count==3 and 5 or 3,rolls))
        end
    end)
    t.test("invalid multi crate requests do not partially spend inventory",function()
        local d=I.new();I.grant(d,"crate_season1",3)
        assert(not I.openMany(d,"crate_season1","open:1",5,{0,0,0,0,0}))
        assert(not I.openMany(d,"crate_season1","open:1",2,{0,0}))
        assert(not I.openMany(d,"crate_season1","open:2",3,{0,0,0}))
        assert(not I.openMany(d,"crate_season1","open:1",3,{0,0,math.huge}))
        assert(d.owned.crate_season1==3 and d.openSequence==0 and next(d.receipts)==nil)
    end)
    t.test("tokens stack as rewards, persist and activate exactly one stored unit",function()
        local d=I.new();local id="token_xp_15"
        assert(Catalog.byId[id].rarity=="Uncommon" and Catalog.byId.token_xp_30.rarity=="Rare" and Catalog.byId.token_xp_60.rarity=="Epic")
        I.grant(d,id,3);assert(d.owned[id]==3)
        assert(not I.equip(d,id))
        assert(I.useToken(d,id,1000) and d.owned[id]==2 and d.boosts.xp==1900)
        assert(I.useToken(d,id,1100) and d.owned[id]==1 and d.boosts.xp==2800)
        d=assert(I.validate(d));assert(d.owned[id]==1 and d.boosts.xp==2800)
        assert(I.useToken(d,id,1200) and not d.owned[id])
        assert(not I.useToken(d,id,1200))
        assert(I.grant(d,"token_crate_60",1) and I.useToken(d,"token_crate_60",1000) and d.boosts.crate==4600)
    end)
    t.test("season crate includes every duration of both token kinds",function()
        local seen={};for _,reward in Catalog.byId.crate_season1.rewards do seen[reward.id]=true end
        for _,id in Catalog.tokens do assert(seen[id],id.." missing from Season 1") end
        local d=I.new();I.grant(d,"crate_season1",2)
        local crate=Catalog.byId.crate_season1
        local total,prior,roll=0,0
        for _,reward in crate.rewards do total+=reward.weight end
        for _,reward in crate.rewards do
            if reward.id=="token_xp_15" then roll=(prior+reward.weight/2)/total;break end
            prior+=reward.weight
        end
        local ok,a=I.open(d,crate.id,"token-a",roll);local yes,b=I.open(d,crate.id,"token-b",roll)
        assert(ok and yes and not a.duplicate and not b.duplicate and d.owned.token_xp_15==2 and d.shards==0)
    end)
    t.test("inventory starts with defaults and no free crates or sample collectibles",function()
        local d=I.new()
        assert(next(d.owned)==nil and d.shards==0 and not I.owns(d,"crate_season1"))
        for category,id in Catalog.defaults do assert(I.owns(d,id) and d.equipped[category]==id) end
    end)
    t.test("unowned items and crates cannot be equipped",function()
        local d=I.new()
        assert(not I.equip(d,"skin_mint") and not I.equip(d,"crate_season1") and not I.equip(d,"unknown"))
        assert(d.equipped.skins=="skin_default")
    end)
    t.test("equipping and unequipping affect only the intended category",function()
        local d=I.new(); assert(I.grant(d,"skin_mint",1)); assert(I.equip(d,"skin_mint"))
        assert(d.equipped.skins=="skin_mint" and d.equipped.bullets=="bullet_default")
        assert(I.equip(d,"skin_mint") and d.equipped.skins=="skin_default")
    end)
    t.test("favorites require ownership and toggle off",function()
        local d=I.new(); assert(not I.favorite(d,"skin_mint"))
        assert(I.favorite(d,"skin_default") and d.favorites.skin_default)
        assert(I.favorite(d,"skin_default") and not d.favorites.skin_default)
    end)
    t.test("crate award consumes one crate and only grants a catalog reward",function()
        local d=I.new(); I.grant(d,"crate_season1",2)
        local ok,r=I.open(d,"crate_season1","first",0)
        assert(ok and r.itemId=="skin_mint" and not r.duplicate and d.owned.crate_season1==1 and d.owned.skin_mint==1)
        assert(not I.open(d,"skin_mint","bad",0))
    end)
    t.test("duplicate rewards become shards without duplicate cosmetic copies",function()
        local d=I.new(); I.grant(d,"crate_season1",2)
        local _,first=I.open(d,"crate_season1","first",0)
        local ok,r=I.open(d,"crate_season1","second",0)
        -- Saved Item Editor edits may change the rolled item's rarity, so price the duplicate from the live catalog.
        local value=Catalog.duplicateValues[Catalog.byId[first.itemId].rarity]
        assert(ok and r.itemId==first.itemId and r.duplicate and r.shards==value and d.shards==value
            and d.owned[first.itemId]==1 and not d.owned.crate_season1)
        assert(not I.open(d,"crate_season1","empty",0))
    end)
    t.test("retrying a crate request survives profile serialization and cannot spend twice",function()
        local d=I.new(); I.grant(d,"crate_season1",2); I.open(d,"crate_season1","request",0)
        d=assert(I.validate(d))
        local ok,r,replay=I.open(d,"crate_season1","request",.99)
        assert(ok and replay and r.itemId=="skin_mint" and d.owned.crate_season1==1 and d.shards==0)
        assert(not I.open(d,"unknown","request",0))
    end)
    t.test("all weighted crate boundaries yield valid rewards",function()
        local total=0; for _,r in Catalog.byId.crate_season1.rewards do total+=r.weight end
        for sample=0,total do
            local d=I.new(); I.grant(d,"crate_season1",1)
            local ok,r=I.open(d,"crate_season1","sample",sample/total)
            assert(ok and Catalog.byId[r.itemId] and Catalog.byId[r.itemId].category~="crates")
        end
    end)
    t.test("invalid profiles never load and unowned equipment falls back to default",function()
        assert(not I.validate({}) and not I.validate({owned={},equipped={},favorites={},shards=0/0}))
        local d=I.new(); d.owned.crate_season1=-1; assert(not I.validate(d))
        d=I.new(); d.equipped.skins="skin_mint"; assert(I.validate(d).equipped.skins=="skin_default")
    end)
    t.test("crate request and grant inputs are bounded and receipt history is capped",function()
        local d=I.new()
        assert(not I.grant(d,"crate_season1",-1) and not I.grant(d,"crate_season1",math.huge) and not I.grant(d,"unknown",1))
        I.grant(d,"crate_season1",50)
        assert(not I.open(d,"crate_season1",string.rep("x",65),0))
        for i=1,40 do assert(I.open(d,"crate_season1",tostring(i),0)) end
        assert(#d.receiptOrder==24 and d.receipts["1"]==nil and d.owned.crate_season1==10)
    end)
end
