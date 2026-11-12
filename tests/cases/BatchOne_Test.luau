return function(t)
    local shared=game.ReplicatedStorage.NOVA
    local C=require(shared.InventoryCatalog)
    local I=require(shared.Inventory)
    local crate=C.byId.crate_season1
    t.test("crate odds summarize the actual weighted reward draw",function()
        local a=crate.rewards[1].id
        local b
        for _,reward in crate.rewards do if C.byId[reward.id].rarity~=C.byId[a].rarity then b=reward.id;break end end
        assert(b)
        local custom={rewards={{id=a,weight=9},{id=b,weight=1}}}
        local odds=C.crateOdds(custom)
        assert(odds.items==2 and odds.totalWeight==10 and not odds.equalItems and not odds.perItemPercent)
        assert(odds.rarities[1].rarity==C.byId[a].rarity and odds.rarities[1].percent==90 and odds.rarities[1].count==1)
        assert(odds.rarities[2].percent==10 and odds.rarities[2].count==1)
        assert(C.roll(custom,.899999)==a and C.roll(custom,.9)==b)
        local drawn={}
        for i=0,999 do local rarity=C.byId[C.roll(custom,(i+.5)/1000)].rarity;drawn[rarity]=(drawn[rarity] or 0)+1 end
        for _,row in odds.rarities do assert(drawn[row.rarity]==row.percent*10) end
    end)
    t.test("Season 1 reserves rarity totals and shares each tier equally",function()
        local chances=require(shared.SeasonOne).rarityChances
        local odds=C.crateOdds(crate)
        assert(crate.rarityWeighted and not odds.equalItems)
        local budget=0;for _,row in odds.rarities do budget+=chances[row.rarity] end
        local byRarity={};local total,count,previous=0,0,math.huge
        for _,row in odds.rarities do
            assert(math.abs(row.percent-100*chances[row.rarity]/budget)<1e-9 and row.percent<previous)
            byRarity[row.rarity]=row
            total+=row.percent;count+=row.count;previous=row.percent
        end
        for _,reward in crate.rewards do
            local row=byRarity[C.byId[reward.id].rarity]
            assert(math.abs(reward.weight-row.percent/row.count)<1e-9)
        end
        assert(count==#crate.rewards and math.abs(total-100)<1e-9)
        local draws={}
        for i=0,99999 do
            local rarity=C.byId[C.roll(crate,(i+.5)/100000)].rarity
            draws[rarity]=(draws[rarity] or 0)+1
        end
        for _,row in odds.rarities do assert(math.abs((draws[row.rarity] or 0)/1000-row.percent)<.05) end
    end)
    t.test("Season 1 replaces both legacy crates and every active cosmetic is reachable",function()
        assert(not C.byId.crate_dev and not C.byId.crate_batch1)
        assert(crate.name=="Season 1 Crate" and crate.image:match("^rbxassetid://%d+$"))
        local count,seen,total=0,{},0
        for _,item in C.items do if item.category=="crates" then count+=1 end end
        assert(count==1)
        for _,reward in crate.rewards do
            local item=C.byId[reward.id]
            assert(item and not item.default and item.category~="crates" and not seen[item.id])
            assert(C.roll(crate,(total+reward.weight/2)/100)==item.id)
            seen[item.id]=true;total+=reward.weight
        end
        for _,item in C.items do if not item.default and item.category~="crates" then assert(seen[item.id],item.id) end end
        assert(math.abs(total-100)<.000001)
    end)
    t.test("Season 1 duplicate receipts survive serialization and eviction",function()
        local d=I.new();I.grant(d,crate.id,35)
        local first=C.byId[crate.rewards[1].id]
        for i=1,30 do
            local ok,r=I.open(d,crate.id,"open:"..i,0)
            assert(ok and r.duplicate==(i>1) and r.shards==(i>1 and C.duplicateValues[first.rarity] or 0))
            d=assert(I.validate(d))
            local success,receipt,replay=I.open(d,crate.id,"open:"..i,nil)
            assert(success and replay and receipt.itemId==r.itemId)
        end
        assert(not I.open(d,crate.id,"open:1",nil))
        assert(d.owned.crate_season1==5 and d.openSequence==30)
    end)
    t.test("legacy crate balances favorites and receipts migrate once without spending twice",function()
        local d=I.new();d.owned={crate_dev=3,crate_batch1=4,crate_season1=2}
        d.favorites={crate_dev=true,crate_batch1=true}
        d.openSequence=2;d.receiptOrder={"open:1","open:2"};d.receipts={}
        for i,id in {"crate_dev","crate_batch1"} do
            d.receipts["open:"..i]={crateId=id,itemId=crate.rewards[1].id,duplicate=false,shards=0}
        end
        local migrated=assert(I.validate(d))
        assert(migrated.owned.crate_season1==9 and migrated.favorites.crate_season1 and migrated.shards==0)
        assert(not migrated.owned.crate_dev and not migrated.owned.crate_batch1 and not migrated.retirementNotice)
        for i,id in {"crate_dev","crate_batch1"} do
            local ok,r,replay=I.open(migrated,id,"open:"..i,nil)
            assert(ok and replay and r.crateId==crate.id and migrated.owned.crate_season1==9)
        end
        for _=1,5 do migrated=assert(I.validate(migrated));assert(migrated.owned.crate_season1==9) end
        assert(d.owned.crate_dev==3 and d.receipts["open:1"].crateId=="crate_dev")
        d=I.new();d.owned={crate_dev=1000000,crate_batch1=1000000,crate_season1=1000000}
        migrated=assert(I.validate(d));assert(migrated.owned.crate_season1==3000000)
        assert(I.grant(migrated,crate.id,1) and migrated.owned.crate_season1==3000000)
        assert(I.open(migrated,crate.id,"open:1",0) and migrated.owned.crate_season1==2999999)
        assert(I.validate(migrated))
    end)
    t.test("win replay awards Season 1 once until expiry",function()
        local d=I.new();local expires=os.time()+100
        assert(I.win(d,"session/1/1/10",expires));d=assert(I.validate(d))
        assert(I.win(d,"session/1/1/10",expires))
        assert(not I.win(d,"session/1/0/10",os.time()-1))
        assert(I.win(d,"session/1/2/10",expires))
        assert(d.owned.crate_season1==2 and d.shards==0)
    end)
end
