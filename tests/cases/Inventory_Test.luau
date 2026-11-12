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
        I.open(d,"crate_season1","first",0)
        local ok,r=I.open(d,"crate_season1","second",0)
        assert(ok and r.duplicate and r.shards==25 and d.shards==25 and d.owned.skin_mint==1 and not d.owned.crate_season1)
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
