local Bindings=require(game.ReplicatedStorage.NOVA.ControlBindings)
local Settings={}
Settings.__index=Settings
function Settings.new()
    return setmetatable({bindings=Bindings.copy(Bindings.defaults),changed=Instance.new("BindableEvent"),opened=false,revision=0,status="Loading saved controls..."},Settings)
end
function Settings:set(device,action,name)
    if not Bindings.allowed(device,action,name) then return false,"That input is reserved or unsupported." end
    local conflict=Bindings.conflict(self.bindings,device,action,name)
    if conflict then return false,"Already used for "..conflict..". Choose another input." end
    local value=Bindings.copy(self.bindings)
    value[device][action]=name
    self.bindings=value
    self.revision+=1
    self.status="Controls applied. Done saves your changes."
    self.changed:Fire()
    return true
end
function Settings:reset()
    self.bindings=Bindings.copy(Bindings.defaults)
    self.revision+=1
    self.status="Defaults restored. Done saves your changes."
    self.changed:Fire()
end
function Settings:load()
    local remote=game.ReplicatedStorage.NOVA:WaitForChild("ControlPreferences",15)
    self.remote=remote
    if not remote then self.status="Controls are saved for this session."; self.changed:Fire(); return end
    local ok,result=pcall(function() return remote:InvokeServer("get") end)
    if ok and type(result)=="table" then
        local saved=Bindings.validate(result.bindings)
        if self.revision==0 then
            if saved then self.bindings=saved; self.revision+=1 end
            self.status=result.message
        end
    elseif self.revision==0 then self.status="Controls are saved for this session." end
    self.changed:Fire()
    if self.pendingSave then self.pendingSave=nil; self:save() end
end
function Settings:save()
    if not self.remote then
        self.pendingSave=true
        self.status="Controls are saved for this session."
        self.changed:Fire()
        return
    end
    local revision=self.revision
    local value=Bindings.copy(self.bindings)
    self.status="Saving controls..."
    self.changed:Fire()
    task.spawn(function()
        local ok,result=pcall(function() return self.remote and self.remote:InvokeServer("save",value) end)
        if self.revision==revision then
            self.status=ok and type(result)=="table" and result.message or "Controls are saved for this session."
            self.changed:Fire()
        end
    end)
end
return Settings
