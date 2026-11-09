local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local shared=game.ReplicatedStorage.NOVA
local Model=require(shared.Inventory)
local Catalog=require(shared.InventoryCatalog)
local Store=require(script.Parent.InventoryStore)
local Service={}; Service.__index=Service
function Service.new()
    local self=setmetatable({records={},closing=false,random=Random.new()},Service)
    if not Run:IsStudio() then self.storage=Store.new(game:GetService("DataStoreService"):GetDataStore("NOVA_Inventory_v1"),Http:GenerateGUID(false)) end
    self.changed=Instance.new("RemoteEvent"); self.changed.Name="InventoryState"; self.changed.Parent=shared
    local request=Instance.new("RemoteFunction"); request.Name="InventoryRequest"; request.Parent=shared
    request.OnServerInvoke=function(player,action,id,key) return self:request(player,action,id,key) end
    -- Server-only developer tool. No replicated grant remote, chat command, or client grant path.
    local grant=Instance.new("BindableFunction"); grant.Name="GrantInventory"
    grant.OnInvoke=function(player,id,amount)
        assert(typeof(player)=="Instance" and player:IsA("Player") and player.Parent==Players,"Pass a connected Player")
        assert(self:ready(player),"Wait for inventory to load")
        local r=self.records[player]
        if id=="samples" then
            for _,item in Catalog.items do if not item.default then Model.grant(r.data,item.id,item.category=="crates" and 10 or 1) end end
        else assert(Model.grant(r.data,id,amount or 1),"Invalid grant") end
        r.version+=1; self:publish(player)
        task.spawn(function() self:save(player,false) end)
        return self:snapshot(player)
    end
    grant.Parent=script.Parent
    task.spawn(function()
        while not self.closing do
            task.wait(30)
            for player,r in self.records do if not r.leaving then task.spawn(function()
                if r.data then self:save(player,false) else self:load(player) end
            end) end end
        end
    end)
    game:BindToClose(function()
        self.closing=true
        for player in self.records do task.spawn(function() self:remove(player) end) end
        local deadline=os.clock()+25
        while next(self.records) and os.clock()<deadline do task.wait(.1) end
    end)
    return self
end
function Service:ready(player)
    local r=self.records[player]
    return r~=nil and r.data~=nil and not r.leaving and (not self.storage or r.expires>os.time())
end
function Service:snapshot(player)
    local r=self.records[player]
    return {data=r and r.data and Model.validate(r.data),version=r and r.version or 0,
        ready=self:ready(player),status=r and r.status or "Loading inventory…"}
end
function Service:publish(player)
    local r=self.records[player]
    if not r or player.Parent~=Players then return end
    player:SetAttribute("InventoryReady",self:ready(player))
    if r.data then for category,id in r.data.equipped do player:SetAttribute("Cosmetic_"..category,id) end end
    self.changed:FireClient(player,self:snapshot(player))
end
function Service:view(player)
    local r=self.records[player]
    return r and r.data and table.clone(r.data.equipped) or table.clone(Catalog.defaults)
end
function Service:load(player)
    local r=self.records[player]
    if not r then r={version=0}; self.records[player]=r end
    if r.loading or r.data or r.leaving then return end
    r.loading=true; r.status="Loading inventory…"; self:publish(player)
    for attempt=1,3 do
        local profile=self.storage and self.storage:load(player.UserId) or nil
        if not self.storage then profile={data=Model.new(),expires=math.huge} end
        if profile then r.data=profile.data; r.expires=profile.expires; break end
        if r.leaving then break end
        if attempt<3 then task.wait(attempt*2) end
    end
    r.loading=false
    r.status=not r.data and "Inventory unavailable. Retrying automatically…" or self.storage and "Inventory saved." or "Studio / session inventory"
    self:publish(player)
end
function Service:save(player,release)
    local r=self.records[player]
    if not r or not r.data or not self.storage or r.saving then return end
    r.saving=true
    local ok=false
    -- A mutation can arrive while UpdateAsync yields. Flush the latest version before finishing.
    repeat
        local version=r.version
        for attempt=1,3 do
            ok=self.storage:save(player.UserId,r,release)
            if ok then break end
            if attempt<3 then task.wait(attempt*2) end
        end
        if not ok or release or version==r.version then break end
    until self.closing
    r.saving=false
    r.status=ok and "Inventory saved." or "Inventory save delayed. Retrying automatically…"
    self:publish(player)
end
function Service:remove(player)
    local r=self.records[player]
    if not r or r.leaving then return end
    r.leaving=true
    while r.loading or r.saving do task.wait() end
    self:save(player,true); self.records[player]=nil
end
function Service:request(player,action,id,key)
    local r=self.records[player]
    if not r or player.Parent~=Players then return {ok=false,message="Loading inventory…"} end
    local now=os.clock()
    if now-(r.lastRequest or -math.huge)<.15 then return {ok=false,message="Please wait."} end
    r.lastRequest=now
    if action=="read" then return {ok=true,profile=self:snapshot(player)} end
    if not self:ready(player) then return {ok=false,message="Inventory unavailable. Retrying…",profile=self:snapshot(player)} end
    if self.canUse and not self.canUse(player) then return {ok=false,message="Return to the lobby to manage your inventory."} end
    if type(id)~="string" or #id>64 then return {ok=false,message="Invalid item."} end
    local ok,result,replay
    if action=="equip" then ok,result=Model.equip(r.data,id)
    elseif action=="favorite" then ok,result=Model.favorite(r.data,id)
    elseif action=="open" then
        local cached=type(key)=="string" and r.data.receipts[key]
        if not cached and now-(r.lastOpen or -math.huge)<6 then return {ok=false,message="Finish the current crate reveal first."} end
        ok,result,replay=Model.open(r.data,id,key,self.random:NextNumber())
        if ok and not replay then r.lastOpen=now end
    else return {ok=false,message="Unknown inventory action."} end
    if not ok then return {ok=false,message=result} end
    if not replay then
        r.version+=1; r.status=self.storage and "Saving inventory…" or "Studio / session inventory"
        self:publish(player)
        task.spawn(function() self:save(player,false) end)
    end
    return {ok=true,profile=self:snapshot(player),receipt=action=="open" and result or nil}
end
return Service
