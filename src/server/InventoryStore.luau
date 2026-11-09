-- Separate leased inventory profile; unknown/corrupt saves never become defaults.
local Inventory=require(game.ReplicatedStorage.NOVA.Inventory)
local Store={LeaseSeconds=180}; Store.__index=Store
function Store.new(storage,token,now) return setmetatable({store=storage,token=token,now=now or os.time},Store) end
function Store:load(uid)
    local now=self.now()
    local ok,value=pcall(function()
        return self.store:UpdateAsync(tostring(uid),function(old)
            if old~=nil then
                if type(old)~="table" or old.schema~=1 or not Inventory.validate(old.data) then return nil end
                if old.owner and old.owner~=self.token and (old.expires or math.huge)>now then return nil end
            end
            return {schema=1,data=old and Inventory.validate(old.data) or Inventory.new(),owner=self.token,expires=now+Store.LeaseSeconds}
        end)
    end)
    if not ok or not value or value.owner~=self.token then return nil end
    return {data=Inventory.validate(value.data),expires=value.expires}
end
function Store:save(uid,profile,release)
    local now=self.now(); local data=assert(Inventory.validate(profile.data),"Invalid inventory profile")
    local ok,value=pcall(function()
        return self.store:UpdateAsync(tostring(uid),function(old)
            if type(old)~="table" or old.schema~=1 or old.owner~=self.token then return nil end
            return {schema=1,data=data,owner=not release and self.token or nil,expires=not release and now+Store.LeaseSeconds or nil}
        end)
    end)
    if not ok or not value then return false end
    if not release then profile.expires=value.expires end
    return true
end
return Store
