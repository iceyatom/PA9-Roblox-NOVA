local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Leaderboard={}
Leaderboard.__index=Leaderboard

function Leaderboard.new(board)
    local self=setmetatable({board=board,best={},names={},pending={},saving={},global={},ready=false},Leaderboard)
    -- Studio deliberately never reads or changes the live rankings.
    self.store=not Run:IsStudio() and game:GetService("DataStoreService"):GetOrderedDataStore("NOVA_HighScorePractice_v1") or nil
    self:render()
    task.spawn(function()
        while true do
            self:refresh()
            for uid in self.pending do task.spawn(function() self:persist(uid) end) end
            task.wait(60)
        end
    end)
    game:BindToClose(function()
        for uid in self.pending do task.spawn(function() self:persist(uid) end) end
        local deadline=os.clock()+25
        while (next(self.pending) or next(self.saving)) and os.clock()<deadline do task.wait(.1) end
    end)
    return self
end

function Leaderboard:render()
    local entries={}
    for _,entry in self.global do entries[entry.uid]={uid=entry.uid,score=entry.score} end
    for uid,score in self.best do
        local old=entries[uid]
        entries[uid]={uid=uid,score=math.max(score,old and old.score or 0)}
    end
    local sorted={}
    for _,entry in entries do table.insert(sorted,entry) end
    table.sort(sorted,function(a,b) return a.score==b.score and a.uid<b.uid or a.score>b.score end)
    local sign=self.board:FindFirstChild("Rankings")
    if not sign then return end
    for i=1,10 do
        local row=sign:FindFirstChild("Row"..i)
        local entry=sorted[i]
        if row then row.Text=entry and ("%02d   %-20s   %d"):format(i,self.names[entry.uid] or ("User "..entry.uid),entry.score)
            or ("%02d   —"):format(i) end
    end
    sign.Status.Text=not self.store and "STUDIO PREVIEW / SESSION SCORES"
        or self.readFailed and "GLOBAL BOARD OFFLINE / RETRYING"
        or not self.ready and "LOADING GLOBAL SCORES…"
        or next(self.pending) and "SCORES SAVING / RETRYING"
        or "ALL TIME / UPDATES EVERY 60 SECONDS"
end

function Leaderboard:refresh()
    if not self.store then return end
    local ok,page=pcall(function() return self.store:GetSortedAsync(false,10):GetCurrentPage() end)
    self.readFailed=not ok
    if ok then
        local entries={}
        for _,entry in page do
            local uid=tonumber(entry.key)
            if uid then
                table.insert(entries,{uid=uid,score=entry.value})
                if not self.names[uid] then
                    local named,name=pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
                    if named then self.names[uid]=name end
                end
            end
        end
        self.global=entries
        self.ready=true
    else warn("[NOVA] Practice leaderboard could not refresh: "..tostring(page)) end
    self:render()
end

function Leaderboard:persist(uid)
    if not self.store or self.saving[uid] or self.pending[uid]==nil then return end
    self.saving[uid]=true
    local score=self.pending[uid]
    local ok,value
    for attempt=1,3 do
        ok,value=pcall(function()
            return self.store:UpdateAsync(tostring(uid),function(old) return math.max(old or 0,score) end)
        end)
        if ok then break end
        task.wait(attempt*2)
    end
    if ok then
        self.best[uid]=math.max(self.best[uid] or 0,value)
        if self.pending[uid]==score then self.pending[uid]=nil end
    else warn("[NOVA] Practice score save will retry: "..tostring(value)) end
    self.saving[uid]=nil
    self:render()
    if self.updated then self.updated(uid,not ok and "Retrying" or self.pending[uid]~=nil and "Saving" or "Saved") end
    if ok and self.pending[uid]~=nil then task.defer(function() self:persist(uid) end) end
end

function Leaderboard:submit(player,score)
    local uid=player.UserId
    self.names[uid]=player.Name
    self.best[uid]=math.max(self.best[uid] or 0,score)
    if self.store then
        self.pending[uid]=math.max(self.pending[uid] or 0,score)
        task.defer(function() self:persist(uid) end)
    end
    self:render()
    return self.store and "Saving" or "SessionOnly"
end
return Leaderboard
