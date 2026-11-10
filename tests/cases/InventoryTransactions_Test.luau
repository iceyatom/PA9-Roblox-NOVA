-- Runs in Studio. Uses an isolated fake store, including an ambiguous write
-- that commits successfully but loses all three responses.
return function(t)
    local Service=require(game.ServerScriptService.NOVA.InventoryService)
    local Model=require(game.ReplicatedStorage.NOVA.Inventory)
    local function fixture()
        local player={UserId=41}
        local storage={available=true}
        function storage:save(_,profile)
            self.saved=Model.validate(profile.data)
            return self.available
        end
        function storage:load()
            if self.available then return {data=Model.validate(self.saved),expires=os.time()+180} end
        end
        local initial=Model.new()
        Model.grant(initial,"crate_batch1",1)
        local record={data=initial,version=1,expires=os.time()+180}
        local service=setmetatable({records={[player]=record},storage=storage},Service)
        local function open(data) return Model.open(data,"crate_batch1","open:1",Random.new(12)) end
        return service,player,record,storage,open
    end
    t.test("unacknowledged debit stays private; lease reload reconciles its receipt",function()
        local service,player,record,storage,open=fixture()
        storage.available=false
        assert(not service:mutate(player,open))
        assert(record.pending and record.data.owned.crate_batch1==1 and not service:ready(player))
        local saved=assert(storage.saved.receipts["open:1"])
        assert(not service:mutate(player,function(data) return Model.favorite(data,"skin_default") end))
        record.expires=os.time()-1; storage.available=true
        service:maintain(player,record)
        assert(service:ready(player) and not record.data.owned.crate_batch1)
        local ok,r,replay=service:mutate(player,open)
        assert(ok and replay and r.itemId==saved.itemId and record.data.shards==0)
    end)
    t.test("overlapping equipment and chest writes serialize on the last committed profile",function()
        local service,player,record,storage,open=fixture()
        local entered=false
        function storage:save(_,profile)
            entered=true; task.wait(.05)
            self.saved=Model.validate(profile.data); return true
        end
        local opened=false
        task.spawn(function() opened=service:mutate(player,open) end)
        repeat task.wait() until entered
        assert(service:mutate(player,function(data)
            return Model.equip(data,data.receipts["open:1"].itemId)
        end))
        assert(opened and not record.busy and not record.pending)
        local item=game.ReplicatedStorage.NOVA.InventoryCatalog
        local id=storage.saved.receipts["open:1"].itemId
        assert(storage.saved.equipped[require(item).byId[id].category]==id)
        assert(not storage.saved.owned.crate_batch1)
    end)
end
