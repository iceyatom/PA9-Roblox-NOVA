return function(t)
    local C=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
    local M=require(game.ReplicatedStorage.NOVA.InventoryEditorModel)
    local function empty() return {version=1,items={},crates={}} end
    t.test("collections infer existing sets and retain empty custom collections",function()
        local edits=empty();edits.collections={custom={name="My Collection"}}
        local groups,byId,unassigned=M.collectionGroups(C.editorBase,edits)
        assert(#groups>1 and byId.custom.name=="My Collection" and #byId.custom.items==0 and #unassigned>0)
        local sample
        for _,item in C.editorBase.items do if item.setName then sample=item;break end end
        assert(sample and byId["set:"..sample.setName])
        for _,member in byId["set:"..sample.setName].items do assert(member.setName==sample.setName) end
        assert(M.validate(edits,C.editorBase))
    end)
    t.test("collection assignment moves items once and preserves visual metadata and crate odds",function()
        local edits=empty();edits.collections={custom={name="Mixed Collection"},other={name="Other Collection"}}
        local sample
        for _,item in C.editorBase.items do if item.setName then sample=item;break end end
        edits.items[sample.id]={collectionId="custom"};edits.items.skin_default={collectionId="custom"}
        local applied=M.apply(C.editorBase,edits)
        assert(applied.byId[sample.id].collectionId=="custom" and applied.byId[sample.id].collectionName=="Mixed Collection")
        assert(applied.byId[sample.id].setId==sample.setId and applied.byId[sample.id].setName==sample.setName and applied.byId[sample.id].artIndex==sample.artIndex)
        assert(applied.defaults.skins=="skin_default")
        local stock=M.apply(C.editorBase,empty()).byId.crate_season1.rewards
        for i,r in applied.byId.crate_season1.rewards do assert(r.id==stock[i].id and r.weight==stock[i].weight) end
        edits.items[sample.id].collectionId="other"
        local _,byId=M.collectionGroups(C.editorBase,edits)
        assert(#byId.custom.items==1 and #byId.other.items==1 and byId.other.items[1].id==sample.id)
    end)
    t.test("unassigning inherited items and dissolving collections never deletes items",function()
        local sample
        for _,item in C.editorBase.items do if item.setName then sample=item;break end end
        local edits=empty();edits.items[sample.id]={collectionId=false}
        local applied=M.apply(C.editorBase,edits);assert(applied.byId[sample.id] and applied.byId[sample.id].collectionId==nil)
        assert(applied.byId[sample.id].setName==sample.setName and next(applied.retired)==nil)
        edits.collections={["set:"..sample.setName]={deleted=true}}
        applied=M.apply(C.editorBase,edits)
        for _,item in C.editorBase.items do if item.setName==sample.setName then assert(applied.byId[item.id] and applied.byId[item.id].collectionId==nil) end end
    end)
    t.test("collection renames persist through copied edits and groups omit deleted items",function()
        local edits=empty();edits.collections={custom={name="Renamed Collection"}}
        edits.items.skin_mint={collectionId="custom"};edits.items.skin_ember={collectionId="custom",deleted=true}
        local copy=M.copy(edits);local applied=M.apply(C.editorBase,copy)
        assert(applied.byId.skin_mint.collectionName=="Renamed Collection" and applied.retired.skin_ember)
        local _,byId=M.collectionGroups(C.editorBase,copy);assert(#byId.custom.items==1)
        local _,all=M.collectionGroups(C.editorBase,copy,true);assert(#all.custom.items==2)
        assert(edits.items.skin_mint.collectionId=="custom")
    end)
    t.test("collection validation rejects missing targets malformed definitions and duplicate names",function()
        for _,value in {true,12,"missing"} do local e=empty();e.items.skin_mint={collectionId=value};assert(not M.validate(e,C.editorBase)) end
        for _,groups in {{bad={}}, {bad={name=""}}, {bad={name="bad\nname"}}, {bad={name="Good",unknown=true}}, {a={name="Same"},b={name="same"}}} do
            local e=empty();e.collections=groups;assert(not M.validate(e,C.editorBase))
        end
        local e=empty();e.collections={bad={name="Removed",deleted=true}};e.items.skin_mint={collectionId="bad"};assert(not M.validate(e,C.editorBase))
        e.items.skin_mint.collectionId=false;assert(M.validate(e,C.editorBase))
    end)
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
        local edits=empty(); edits.crates.crate_season1={{id="skin_mint",weight=25},{id="skin_ember",weight=75}}
        local catalog=M.apply(C.editorBase,edits); local crate=catalog.byId.crate_season1
        assert(#crate.rewards==2)
        assert(C.roll(crate,0)=="skin_mint" and C.roll(crate,.249999)=="skin_mint")
        assert(C.roll(crate,.25)=="skin_ember" and C.roll(crate,1)=="skin_ember")
    end)
    t.test("editor rejects empty, duplicate, deleted, default and nested crate rewards and invalid totals",function()
        for _,rows in {
            {},{{id="skin_mint",weight=99}},{{id="skin_mint",weight=0/0}},
            {{id="skin_mint",weight=50},{id="skin_mint",weight=50}},
            {{id="skin_default",weight=100}},{{id="crate_season1",weight=100}},{{id="missing",weight=100}},
        } do local edits=empty(); edits.crates.crate_season1=rows; assert(not M.validate(edits,C.editorBase)) end
        local edits=empty(); edits.crates.crate_season1={{id="skin_mint",weight=100}}; edits.items.skin_mint={deleted=true}
        assert(not M.validate(edits,C.editorBase))
    end)
    t.test("editor protects required items and rejects invalid fields and empty crates after deletion",function()
        for _,id in {"skin_default","crate_season1"} do local edits=empty(); edits.items[id]={deleted=true}; assert(not M.validate(edits,C.editorBase)) end
        for _,edit in {{rarity="Chest"},{name=""},{name="bad\nname"},{category="crates"},{rarity="Unknown"}} do
            local edits=empty(); edits.items.skin_mint=edit; assert(not M.validate(edits,C.editorBase))
        end
        local edits=empty()
        for _,r in C.editorBase.byId.crate_season1.rewards do edits.items[r.id]={deleted=true} end
        assert(not M.validate(edits,C.editorBase))
    end)
    t.test("rarity edits and deletion preserve automatic tier budgets",function()
        local edits=empty();edits.items.skin_mint={rarity="Common"};edits.items.bullet_ion={deleted=true}
        local catalog=M.apply(C.editorBase,edits);local crate=catalog.byId.crate_season1
        assert(crate.rarityWeighted)
        local counts,weights={},{}
        for _,r in crate.rewards do
            local tier=catalog.byId[r.id].rarity
            counts[tier]=(counts[tier] or 0)+1;weights[tier]=(weights[tier] or 0)+r.weight
            assert(r.id~="bullet_ion")
        end
        local chances=crate.rarityChances;local available=0
        for tier in counts do available+=chances[tier] end
        assert(math.abs(weights.Common-45)<1e-9)
        for tier,value in weights do assert(math.abs(value-100*chances[tier]/available)<1e-9) end
        for _,r in crate.rewards do local tier=catalog.byId[r.id].rarity;assert(math.abs(r.weight-weights[tier]/counts[tier])<1e-9) end
        edits.crates.crate_season1={{id="skin_mint",weight=25},{id="skin_ember",weight=75}}
        crate=M.apply(C.editorBase,edits).byId.crate_season1
        assert(not crate.rarityWeighted and crate.rewards[1].weight==25 and crate.rewards[2].weight==75)
    end)
    t.test("missing rarities redistribute only their budget without invalid rewards",function()
        local rewards={{id="a"},{id="b"},{id="c"}}
        local items={a={rarity="Common"},b={rarity="Common"},c={rarity="Cosmic"}}
        local chances={Common=45,Uncommon=30,Rare=15,Epic=7,Legendary=2.5,Cosmic=.5}
        local rows=M.rarityRewards(rewards,items,chances)
        assert(#rows==3 and math.abs(rows[1].weight-100*45/45.5/2)<1e-9)
        assert(rows[1].weight==rows[2].weight and math.abs(rows[3].weight-100*.5/45.5)<1e-9)
        local edits=empty();edits.items.a={deleted=true};edits.items.b={rarity="Cosmic"}
        rows=M.rarityRewards(rewards,items,chances,edits)
        assert(#rows==2 and rows[1].weight==50 and rows[2].weight==50)
    end)
    t.test("Season 1 pool covers active items with equal probabilities within rarities",function()
        local crate=C.byId.crate_season1
        local seen,total,within={},0,{}
        for _,reward in crate.rewards do
            local item=C.byId[reward.id]
            assert(item and not item.default and item.category~="crates" and not seen[item.id])
            if within[item.rarity] then assert(math.abs(reward.weight-within[item.rarity])<1e-9) end
            within[item.rarity]=reward.weight
            seen[item.id]=true;total+=reward.weight
        end
        for _,item in C.items do if not item.default and item.category~="crates" then assert(seen[item.id],item.id) end end
        assert(math.abs(total-100)<.000001)
    end)
end
