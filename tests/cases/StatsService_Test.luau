-- Studio-only service fixtures: no live players or DataStores are touched.
return function(t)
    local Service=require(game.ServerScriptService.NOVA.InventoryService)
    local I=require(game.ReplicatedStorage.NOVA.Inventory)
    local function fixture(count)
        local player={UserId=4321};local r={data=I.new(),version=0,expires=math.huge,statsQueue={}}
        for i=1,count do table.insert(r.statsQueue,{key="stats/"..i,mapId="test",mapName="Test Map",outcome="win",shots=2}) end
        local service=setmetatable({records={[player]=r},publish=function() end},Service)
        return service,player,r
    end
    t.test("stats queue drains bounded batches and removal saves the remaining events",function()
        local service,player,r=fixture(150)
        service:maintain(player,r);assert(r.data.stats.matchesPlayed==64 and #r.statsQueue==86)
        service:maintain(player,r);assert(r.data.stats.matchesPlayed==128 and #r.statsQueue==22)
        service:remove(player);assert(r.data.stats.matchesPlayed==150 and r.data.stats.shotsFired==300 and #r.statsQueue==0)
        assert(not service.records[player])
    end)
    t.test("stats events survive an ambiguous candidate without merging into it twice",function()
        local service,player,r=fixture(1)
        r.pending=I.validate(r.data);service:mergeStats(r,r.pending)
        -- Simulate a save whose candidate committed but was not acknowledged.
        local committed=I.validate(r.pending)
        table.insert(r.statsQueue,{key="stats/2",mapId="test",mapName="Test Map",outcome="loss",shots=3})
        assert(committed.stats.matchesPlayed==1 and r.pending.stats.matchesPlayed==1)
        service:maintain(player,r)
        assert(r.data.stats.matchesPlayed==2 and r.data.stats.shotsFired==5 and #r.statsQueue==0)
        assert(r.data.stats.currentWinStreak==0 and r.data.stats.longestWinStreak==1)
    end)
    t.test("crate transactions merge queued match stats into the same committed profile",function()
        local service,player,r=fixture(1);I.grant(r.data,"crate_season1",1)
        local ok=service:mutate(player,function(data) return I.open(data,"crate_season1","open:1",0) end)
        assert(ok and r.data.stats.matchesPlayed==1 and r.data.stats.cratesOpened==1 and #r.statsQueue==0)
    end)
end
