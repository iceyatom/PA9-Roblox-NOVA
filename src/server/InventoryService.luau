local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local shared=game.ReplicatedStorage.NOVA
local Model=require(shared.Inventory)
local Catalog=require(shared.InventoryCatalog)
local Store=require(script.Parent.InventoryStore)
local Service={}
Service.__index=Service

function Service.new()
    local self=setmetatable({records={},closing=false,random=Random.new(),session=Http:GenerateGUID(false)},Service)
    if not Run:IsStudio() then
        self.storage=Store.new(game:GetService("DataStoreService"):GetDataStore("NOVA_Inventory_v1"),self.session)
    end
    self.changed=Instance.new("RemoteEvent")
    self.changed.Name="InventoryState"; self.changed.Parent=shared
    local request=Instance.new("RemoteFunction")
    request.Name="InventoryRequest"; request.Parent=shared
    request.OnServerInvoke=function(player,action,id,key,...)
        if select("#",...)~=0 then return {ok=false,message="Invalid request."} end
        return self:request(player,action,id,key)
    end
    local grant=Instance.new("BindableFunction")
    grant.Name="GrantInventory"; grant.Parent=script.Parent
    grant.OnInvoke=function(player,id,amount)
        assert(typeof(player)=="Instance" and player.Parent==Players and self:ready(player),"Inventory unavailable")
        local ok,message=self:mutate(player,function(data)
            if id~="samples" then return Model.grant(data,id,amount or 1) end
            for _,item in Catalog.items do
                if not item.default then Model.grant(data,item.id,item.category=="crates" and 10 or 1) end
            end
            return true
        end)
        assert(ok,message)
        return self:snapshot(player)
    end
    task.spawn(function()
        while not self.closing do
            task.wait(25)
            for player,r in self.records do
                if not r.leaving and not r.busy then task.spawn(function() self:maintain(player,r) end) end
            end
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
    return r~=nil and r.data~=nil and not r.leaving and not r.pending and (not self.storage or r.expires>os.time())
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
    if r.data then
        player:SetAttribute("ReducedEffects",r.data.reducedEffects)
        for category,id in r.data.equipped do player:SetAttribute("Cosmetic_"..category,id) end
    end
    self.changed:FireClient(player,self:snapshot(player))
end
function Service:view(player)
    local r=self.records[player]
    return r and r.data and table.clone(r.data.equipped) or table.clone(Catalog.defaults)
end
function Service:load(player)
    if self.records[player] then return end
    local r={version=0,status="Loading inventory…"}
    self.records[player]=r
    self:maintain(player,r)
end
-- A timed-out write has an unknown outcome. Keep its exact candidate (including
-- the roll/receipt) until acknowledged or until a fresh leased load reconciles it.
function Service:flush(player,r)
    local candidate=r.pending
    local profile={data=candidate or r.data,expires=r.expires}
    for attempt=1,3 do
        if not self.storage or self.storage:save(player.UserId,profile,false) then
            r.data=profile.data; r.expires=profile.expires; r.pending=nil
            if candidate then r.version+=1 end
            r.status=self.storage and "Inventory saved." or "Studio / session inventory"
            return true
        end
        if r.expires<=os.time() then break end
        if attempt<3 then task.wait(2^(attempt-1)) end
    end
    r.status="Inventory save delayed. Retrying automatically…"
    return false
end
function Service:maintain(player,r)
    if r.busy or r.leaving then return end
    r.busy=true
    if not r.data or self.storage and r.expires<=os.time() then
        local profile
        for attempt=1,3 do
            if self.storage then profile=self.storage:load(player.UserId)
            else profile={data=Model.new(),expires=math.huge} end
            if profile or r.leaving then break end
            if attempt<3 then task.wait(2^(attempt-1)) end
        end
        if profile then
            r.data=profile.data; r.expires=profile.expires; r.pending=nil; r.version+=1
            r.status=self.storage and "Inventory saved." or "Studio / session inventory"
        else r.status="Inventory unavailable. Retrying automatically…" end
    elseif self.storage then self:flush(player,r) end
    r.busy=false; self:publish(player)
end
function Service:mutate(player,change)
    local r=self.records[player]
    while r and r.busy and not r.leaving do task.wait() end
    if not self:ready(player) then return false,"Inventory unavailable. Retrying…" end
    r.busy=true
    local data=Model.validate(r.data)
    local ok,result,replay=change(data)
    if ok and not replay then
        r.pending=data
        ok=self:flush(player,r)
        if not ok then result="Reward saving. Retry to check the result." end
    end
    r.busy=false; self:publish(player)
    return ok,result,replay
end
function Service:crateChance(player)
    local r=self.records[player]
    return r and r.data and r.data.crateChance or require(shared.CrateDrop).BaseChance
end
function Service:awardMatch(player,result,expires,outcome,report)
    -- Sample once per match delivery, never once per save/retry attempt.
    local roll=outcome=="win" and self.random:NextNumber() or nil
    task.spawn(function()
        local delaySeconds=1
        while self.records[player] and not self.records[player].leaving and os.time()<expires do
            local ok,receipt=self:mutate(player,function(data) return Model.matchReward(data,result,expires,outcome,roll) end)
            if ok then
                report(not receipt and "Reward recorded" or receipt.awarded and "Chest earned" or outcome=="loss" and "Chance increased" or "No crate this time",receipt)
                return
            end
            report("Reward unavailable")
            task.wait(delaySeconds)
            delaySeconds=math.min(delaySeconds*2,25)
        end
    end)
end
function Service:remove(player)
    local r=self.records[player]
    if not r or r.leaving then return end
    r.leaving=true
    while r.busy do task.wait() end
    if self.storage and r.data and r.expires>os.time() then
        if not r.pending or self:flush(player,r) then self.storage:save(player.UserId,r,true) end
    end
    self.records[player]=nil
end
function Service:request(player,action,id,key)
    local r=self.records[player]
    if not r or player.Parent~=Players then return {ok=false,message="Loading inventory…"} end
    local openCount=({open=1,open3=3,open5=5})[action]
    local now=os.clock()
    if now-(r.lastRequest or -math.huge)<.15 then return {ok=false,message="Please wait."} end
    r.lastRequest=now
    if action=="read" and id==nil and key==nil then return {ok=true,profile=self:snapshot(player)} end
    if type(id)~="string" or #id>64 or (not openCount and key~=nil) then return {ok=false,message="Invalid request."} end
    local ok,result=self:mutate(player,function(data)
        if action=="ackRetirements" then return Model.ackRetirements(data,id) end
        if self.canUse and not self.canUse(player) then return false,"Return to the lobby to manage your inventory." end
        if action=="equip" then return Model.equip(data,id)
        elseif action=="favorite" then return Model.favorite(data,id)
        elseif action=="effects" and (id=="on" or id=="off") then
            data.reducedEffects=id=="on"; return true
        elseif openCount then
            if type(key)~="string" or #key>64 then return false,"Invalid request." end
            if not data.receipts[key] then
                if key~="open:"..(data.openSequence+1) then return false,"Opening expired." end
                if now-(r.lastOpen or -math.huge)<.15 then return false,"Please wait." end
            end
            local success,receipt,replay
            if openCount==1 then success,receipt,replay=Model.open(data,id,key,self.random:NextNumber())
            else
                local rolls={};for _=1,openCount do table.insert(rolls,self.random:NextNumber()) end
                success,receipt,replay=Model.openMany(data,id,key,openCount,rolls)
            end
            if success and not replay then r.lastOpen=now end
            return success,receipt,replay
        end
        return false,"Unknown inventory action."
    end)
    return {ok=ok,message=not ok and result or nil,profile=self:snapshot(player),receipt=ok and openCount==1 and result or nil,receipts=ok and openCount and openCount>1 and result or nil}
end
return Service
