-- Serialized names keep preferences portable between keyboard and controller devices.
local Bindings={}
Bindings.defaults={pc={left="A",right="D",jump="Space",fire="MouseButton1"},console={move="Thumbstick1",jump="ButtonA",fire="ButtonR2"}}
local reserved={Unknown=true,Escape=true,F2=true,F4=true,F9=true,F10=true,F11=true,F12=true,BackSlash=true,Return=true,KeypadEnter=true}
local buttons={ButtonA=true,ButtonB=true,ButtonX=true,ButtonY=true,ButtonL1=true,ButtonR1=true,ButtonL2=true,ButtonR2=true,ButtonL3=true,ButtonR3=true,DPadLeft=true,DPadRight=true,DPadUp=true,DPadDown=true}
local mouse={MouseButton1=true,MouseButton2=true,MouseButton3=true}
local moves={Thumbstick1=true,Thumbstick2=true,DPad=true}
local labels={left="Move left",right="Move right",move="Move",jump="Jump",fire="Fire"}
function Bindings.copy(value)
    return {pc=table.clone(value.pc),console=table.clone(value.console)}
end
function Bindings.enum(name)
    if mouse[name] then return Enum.UserInputType[name] end
    return Enum.KeyCode[name]
end
function Bindings.allowed(device,action,name)
    if type(name)~="string" or #name>32 then return false end
    if device=="console" then return action=="move" and moves[name]==true or action~="move" and buttons[name]==true end
    if device~="pc" then return false end
    if mouse[name] then return action=="jump" or action=="fire" end
    if reserved[name] then return false end
    local ok,key=pcall(function() return Enum.KeyCode[name] end)
    return ok and key.Value>0 and key.Value<1000
end
function Bindings.conflict(value,device,action,name)
    for other,bound in value[device] do
        if other~=action and (bound==name or device=="console" and bound=="DPad" and name:sub(1,4)=="DPad"
            or device=="console" and name=="DPad" and type(bound)=="string" and bound:sub(1,4)=="DPad") then return labels[other] or other end
    end
end
function Bindings.validate(value)
    if type(value)~="table" then return nil end
    local clean=Bindings.copy(Bindings.defaults)
    for device,defaults in Bindings.defaults do
        if type(value[device])~="table" then return nil end
        for action in defaults do
            local name=value[device][action]
            if not Bindings.allowed(device,action,name) or Bindings.conflict(value,device,action,name) then return nil end
            clean[device][action]=name
        end
    end
    return clean
end
return Bindings
