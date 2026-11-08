local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local shared=game.ReplicatedStorage:WaitForChild("NOVA")
local Bindings=require(shared.ControlBindings)
-- Studio uses session preferences and never touches players' live saved controls.
local store=not Run:IsStudio() and game:GetService("DataStoreService"):GetDataStore("NOVA_ControlPreferences_v1")
local records={}
local remote=Instance.new("RemoteFunction")
remote.Name="ControlPreferences"
remote.Parent=shared
local function load(player)
    local record=records[player]
    if record then
        while record.loading do task.wait() end
        return record
    end
    record={bindings=Bindings.copy(Bindings.defaults),loading=true,writable=store~=nil and store~=false,version=0,lastWrite=0}
    records[player]=record
    if store then
        local ok,value=pcall(function() return store:GetAsync(tostring(player.UserId)) end)
        if ok then record.bindings=Bindings.validate(value) or record.bindings
        else record.writable=false; warn("[NOVA] Could not load control preferences: "..tostring(value)) end
    end
    record.loading=false
    return record
end
local function persist(player,record)
    if not record.writable or record.saving then return false end
    record.saving=true
    local delay=2-(os.clock()-record.lastWrite)
    if delay>0 then task.wait(delay) end
    local version=record.version
    local value=Bindings.copy(record.bindings)
    local ok,err=pcall(function() store:SetAsync(tostring(player.UserId),value) end)
    record.lastWrite=os.clock()
    record.saving=false
    if ok then record.savedVersion=version
    else warn("[NOVA] Could not save control preferences: "..tostring(err)) end
    return ok and version==record.version
end
remote.OnServerInvoke=function(player,kind,value)
    if kind~="get" and kind~="save" then return nil end
    local clean=kind=="save" and Bindings.validate(value)
    if kind=="save" and not clean then return {message="Invalid bindings. Controls were not saved."} end
    local record=load(player)
    if kind=="get" then return {bindings=record.bindings,message=record.writable and "Controls loaded." or "Controls are saved for this session."} end
    record.bindings=clean
    record.version+=1
    local saved=persist(player,record)
    return {message=saved and "Controls saved to your profile." or "Controls are saved for this session."}
end
local function departing(player)
    local record=records[player]
    if record then
        while record.loading or record.saving do task.wait() end
        if record.version~=(record.savedVersion or 0) then persist(player,record) end
        records[player]=nil
    end
end
Players.PlayerRemoving:Connect(departing)
game:BindToClose(function()
    local pending=0
    for player in records do
        pending+=1
        task.spawn(function() departing(player); pending-=1 end)
    end
    while pending>0 do task.wait() end
end)
