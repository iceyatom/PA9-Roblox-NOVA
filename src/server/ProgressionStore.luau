-- Atomic, leased profiles prevent an old server from overwriting a new session.
local P=require(game.ReplicatedStorage.NOVA.Progression)
local Store={LeaseSeconds=180}
Store.__index=Store

function Store.new(dataStore,token,now)
    return setmetatable({store=dataStore,token=token,now=now or os.time},Store)
end

function Store:load(uid)
    local now=self.now()
    local ok,value=pcall(function()
        return self.store:UpdateAsync(tostring(uid),function(old)
            if old~=nil then
                if type(old)~="table" or old.schema~=1 or not P.validate(old.data) then return nil end
                if old.owner and old.owner~=self.token and (old.expires or math.huge)>now then return nil end
            end
            return {schema=1,data=old and P.validate(old.data) or P.new(),owner=self.token,expires=now+Store.LeaseSeconds}
        end)
    end)
    if not ok or not value or value.owner~=self.token then return nil end
    return {data=P.validate(value.data),expires=value.expires}
end

function Store:save(uid,profile,release)
    local now=self.now()
    local data=assert(P.validate(profile.data),"Invalid progression profile")
    local ok,value=pcall(function()
        return self.store:UpdateAsync(tostring(uid),function(old)
            if type(old)~="table" or old.schema~=1 or old.owner~=self.token then return nil end
            return {schema=1,data=data,owner=not release and self.token or nil,
                expires=not release and now+Store.LeaseSeconds or nil}
        end)
    end)
    if not ok or not value then return false end
    if not release then profile.expires=value.expires end
    return true
end

return Store
