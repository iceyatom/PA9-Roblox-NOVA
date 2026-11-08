local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local shared=game.ReplicatedStorage.NOVA
local P=require(shared.Progression)
local Store=require(script.Parent.ProgressionStore)
local Service={}
Service.__index=Service

function Service.new()
    local self=setmetatable({records={},closing=false},Service)
    if not Run:IsStudio() then
        self.storage=Store.new(game:GetService("DataStoreService"):GetDataStore("NOVA_Progression_v1"),
            game:GetService("HttpService"):GenerateGUID(false))
    end
    self.remote=Instance.new("RemoteFunction")
    self.remote.Name="Prestige"
    self.remote.Parent=shared
    -- This remote accepts no XP, level, target player, or saved profile from clients.
    self.remote.OnServerInvoke=function(player)
        local r=self.records[player]
        if not r or os.clock()-(r.lastRequest or -math.huge)<1 then return "Please wait." end
        r.lastRequest=os.clock()
        if not self:ready(player) then return "Your progression is unavailable. Retrying…" end
        if self.canPrestige and not self.canPrestige(player) then return "Return to the lobby to prestige." end
        if not P.prestige(r.data) then return "Reach level 55 to prestige." end
        r.version+=1
        self:publish(player)
        task.spawn(function() self:save(player,false) end)
        return r.data.master and "Prestige Master unlocked!" or ("Prestige %d unlocked!"):format(r.data.prestige)
    end
    task.spawn(function()
        while not self.closing do
            task.wait(30)
            for player,r in self.records do
                if not r.leaving then task.spawn(function()
                    if r.data then self:save(player,false) else self:load(player) end
                end) end
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
    return r~=nil and r.data~=nil and not r.leaving and (not self.storage or r.expires>os.time())
end

function Service:publish(player)
    local r=self.records[player]
    if not r or not r.data then return end
    player:SetAttribute("Level",r.data.level)
    player:SetAttribute("Prestige",r.data.prestige)
    player:SetAttribute("PrestigeMaster",r.data.master)
    player:SetAttribute("XP",r.data.xp)
    player:SetAttribute("TotalXP",r.data.totalXP)
    player:SetAttribute("RankLabel",P.label(r.data))
    player:SetAttribute("ProgressionReady",self:ready(player))
    local stats=player:FindFirstChild("leaderstats")
    if not stats then stats=Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=player end
    for name,value in {Level=r.data.level,Prestige=r.data.prestige} do
        local stat=stats:FindFirstChild(name)
        if not stat then stat=Instance.new("IntValue"); stat.Name=name; stat.Parent=stats end
        stat.Value=value
    end
end

function Service:load(player)
    local r=self.records[player]
    if not r then r={version=0}; self.records[player]=r end
    if r.loading or r.data or r.leaving then return end
    r.loading=true
    player:SetAttribute("ProgressionStatus","Loading progression…")
    for attempt=1,3 do
        local profile=self.storage and self.storage:load(player.UserId) or nil
        if not self.storage then profile={data=P.new(),expires=math.huge} end
        if profile then r.data=profile.data; r.expires=profile.expires; break end
        if r.leaving then break end
        if attempt<3 then task.wait(attempt*2) end
    end
    r.loading=false
    player:SetAttribute("ProgressionStatus",not r.data and "Progression unavailable / retrying. Challenges unlock when loaded."
        or self.storage and "Progression saved." or "Studio preview / session progression")
    self:publish(player)
end

function Service:save(player,release)
    local r=self.records[player]
    if not r or not r.data or not self.storage or r.saving then return end
    r.saving=true
    local version=r.version
    local ok
    for attempt=1,3 do
        ok=self.storage:save(player.UserId,r,release)
        if ok then break end
        if attempt<3 then task.wait(attempt*2) end
    end
    r.saving=false
    player:SetAttribute("ProgressionStatus",ok and (version==r.version and "Progression saved." or "Saving progression…")
        or "Progression save delayed / retrying")
    self:publish(player)
end

function Service:remove(player)
    local r=self.records[player]
    if not r or r.leaving then return end
    r.leaving=true
    while r.loading or r.saving do task.wait() end
    self:save(player,true)
    self.records[player]=nil
end

function Service:award(player,won)
    if not self:ready(player) then return 0 end
    local r=self.records[player]
    local amount=won and P.WinXP or P.PlayXP
    P.award(r.data,amount)
    r.version+=1
    player:SetAttribute("ProgressionStatus",self.storage and "Saving progression…" or "Studio preview / session progression")
    self:publish(player)
    return amount
end

function Service:view(player)
    local r=self.records[player]
    return r and r.data and table.clone(r.data) or nil
end

return Service
