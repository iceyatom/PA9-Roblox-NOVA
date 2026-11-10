return function(t)
    local shared=game.ReplicatedStorage.NOVA
    local C=require(shared.InventoryCatalog)
    local I=require(shared.Inventory)
    local tiers={"Uncommon","Rare","Epic","Legendary","Cosmic"}
    local counts={10,7,4,3,1}
    local ends={6000,8500,9500,9900,10000}
    t.test("Batch One exact integer intervals and all 125 reachable item selections",function()
        local previous=0
        local seen={}
        for i,limit in ends do
            for draw=previous+1,limit do assert(C.batchTier(draw)==tiers[i]) end
            for category=1,5 do
                for slot=1,counts[i] do
                    local args={limit,category,slot}
                    local expectedMax={10000,5,counts[i]}
                    local fake={NextInteger=function(_,lo,hi)
                        assert(lo==1 and hi==table.remove(expectedMax,1))
                        return table.remove(args,1)
                    end}
                    local id=C.rollBatch(fake)
                    local item=C.byId[id]
                    assert(item.category==C.categories[category].id and item.rarity==tiers[i] and not seen[id])
                    seen[id]=true
                end
            end
            previous=limit
        end
        local count=0
        for _,item in C.items do
            if item.setId then count+=1; assert(seen[item.id]) end
        end
        assert(count==125 and #C.byId.crate_dev.rewards==10)
    end)
    t.test("all Batch One duplicates and sequence receipts survive serialization and eviction",function()
        local d=I.new()
        I.grant(d,"crate_batch1",35)
        for i=1,30 do
            local tier=(i-1)%5+1
            local draws={ends[tier],1,1}
            local ok,r=I.open(d,"crate_batch1","open:"..i,{NextInteger=function() return table.remove(draws,1) end})
            assert(ok and r.duplicate==(i>5) and r.shards==(i>5 and C.duplicateValues[tiers[tier]] or 0))
            d=assert(I.validate(d))
            local success,receipt,replay=I.open(d,"crate_batch1","open:"..i,nil)
            assert(success and replay and receipt.itemId==r.itemId)
        end
        assert(not I.open(d,"crate_batch1","open:1",nil))
        assert(d.owned.crate_batch1==5 and d.openSequence==30)
    end)
    t.test("win replay is idempotent until expiry and expired grants cannot be recreated",function()
        local d=I.new()
        local expires=os.time()+100
        assert(I.win(d,"session/1/1/10",expires))
        d=assert(I.validate(d))
        assert(I.win(d,"session/1/1/10",expires))
        assert(not I.win(d,"session/1/0/10",os.time()-1))
        assert(I.win(d,"session/1/2/10",expires))
        assert(d.owned.crate_batch1==2 and d.shards==0)
    end)
    t.test("seeded million-roll smoke agrees with specified rarity and category probabilities",function()
        local random=Random.new(7281)
        local byTier,byType={},{}
        for i=1,1000000 do
            local item=C.byId[C.rollBatch(random)]
            byTier[item.rarity]=(byTier[item.rarity] or 0)+1
            byType[item.category]=(byType[item.category] or 0)+1
        end
        local previous=0
        for i,limit in ends do
            local expected=(limit-previous)*100
            assert(math.abs(byTier[tiers[i]]-expected)<6*math.sqrt(expected))
            previous=limit
        end
        for _,n in byType do assert(math.abs(n-200000)<2500) end
    end)
end
