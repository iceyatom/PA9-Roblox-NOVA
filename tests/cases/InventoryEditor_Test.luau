return function(t)
    local C=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
    local M=require(game.ReplicatedStorage.NOVA.InventoryEditorModel)
    local function empty() return {version=1,items={},crates={}} end
    t.test("editor keeps stable IDs, defaults and cosmetic metadata after renaming and rarity changes",function()
        local edits=empty(); edits.items.skin_mint={name="Mint Plus",rarity="Cosmic"}
        local catalog=M.apply(C.editorBase,edits)
        assert(catalog.byId.skin_mint.name=="Mint Plus" and catalog.byId.skin_mint.rarity=="Cosmic")
        assert(catalog.defaults.skins=="skin_default" and catalog.byId.skin_mint.color==C.byId.skin_mint.color)
        assert(C.editorBase.byId.skin_mint.name=="Mint Circuit")
    end)
    t.test("editor deletes a cosmetic from all crate pools and rescales remaining percentages",function()
        local edits=empty(); edits.items.skin_mint={deleted=true}
        local catalog=M.apply(C.editorBase,edits)
        assert(not catalog.byId.skin_mint)
        assert(catalog.retired.skin_mint.name=="Mint Circuit" and catalog.retired.skin_mint.rarity=="Rare")
        for _,item in catalog.items do if item.rewards then
            local total=0
            for _,reward in item.rewards do assert(reward.id~="skin_mint"); total+=reward.weight end
            assert(math.abs(total-100)<.000001)
        end end
    end)
    t.test("editor custom pools replace chest contents and weighted draw uses exact boundaries",function()
        local edits=empty(); edits.crates.crate_batch1={{id="skin_mint",weight=25},{id="skin_ember",weight=75}}
        local catalog=M.apply(C.editorBase,edits); local crate=catalog.byId.crate_batch1
        assert(#crate.rewards==2)
        assert(C.roll(crate,0)=="skin_mint" and C.roll(crate,.249999)=="skin_mint")
        assert(C.roll(crate,.25)=="skin_ember" and C.roll(crate,1)=="skin_ember")
    end)
    t.test("editor rejects empty, duplicate, deleted, default and nested crate rewards and invalid totals",function()
        for _,rows in {
            {},{{id="skin_mint",weight=99}},{{id="skin_mint",weight=0/0}},
            {{id="skin_mint",weight=50},{id="skin_mint",weight=50}},
            {{id="skin_default",weight=100}},{{id="crate_dev",weight=100}},{{id="missing",weight=100}},
        } do local edits=empty(); edits.crates.crate_batch1=rows; assert(not M.validate(edits,C.editorBase)) end
        local edits=empty(); edits.crates.crate_dev={{id="skin_mint",weight=100}}; edits.items.skin_mint={deleted=true}
        assert(not M.validate(edits,C.editorBase))
    end)
    t.test("editor protects required items and rejects invalid fields and empty crates after deletion",function()
        for _,id in {"skin_default","crate_batch1"} do local edits=empty(); edits.items[id]={deleted=true}; assert(not M.validate(edits,C.editorBase)) end
        for _,edit in {{rarity="Chest"},{name=""},{name="bad\nname"},{category="crates"},{rarity="Unknown"}} do
            local edits=empty(); edits.items.skin_mint=edit; assert(not M.validate(edits,C.editorBase))
        end
        local edits=empty()
        for _,r in C.editorBase.byId.crate_dev.rewards do edits.items[r.id]={deleted=true} end
        assert(not M.validate(edits,C.editorBase))
    end)
    t.test("expanded batch pool matches original rarity odds",function()
        local totals={}
        for _,reward in C.byId.crate_batch1.rewards do local tier=C.byId[reward.id].rarity; totals[tier]=(totals[tier] or 0)+reward.weight end
        for tier,expected in {Uncommon=60,Rare=25,Epic=10,Legendary=4,Cosmic=1} do assert(math.abs(totals[tier]-expected)<.000001) end
    end)
end
