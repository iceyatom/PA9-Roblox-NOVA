local UIS=game:GetService("UserInputService")
local actions=game:GetService("ContextActionService")
local gui=game:GetService("GuiService")
local Bindings=require(game.ReplicatedStorage.NOVA.ControlBindings)
local Input={}

-- Both devices can hold jump at the same time; fire responds to a new press only.
function Input.driver(send,getBindings)
    local held,sticks={},{}
    local lastX,lastJump=0,false
    local function update()
        local b=getBindings()
        local x=b.console.move=="DPad" and ((held.DPadRight and 1 or 0)-(held.DPadLeft and 1 or 0)) or (sticks[b.console.move] or 0)
        if held[b.pc.left] or held[b.pc.right] then x=(held[b.pc.right] and 1 or 0)-(held[b.pc.left] and 1 or 0) end
        local jump=held[b.pc.jump]==true or held[b.console.jump]==true
        if x~=lastX then lastX=x; send("move",x) end
        if jump~=lastJump then lastJump=jump; send("jump",jump) end
    end
    local function handle(state,key,position)
        local name=key.Name
        local released=state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel
        if name=="Thumbstick1" or name=="Thumbstick2" then
            local x=not released and position and position.X or 0
            sticks[name]=math.abs(x)>0.18 and math.sign(x) or 0
        elseif released then held[name]=nil
        elseif state==Enum.UserInputState.Begin and not held[name] then
            held[name]=true
            local b=getBindings()
            if name==b.pc.fire or name==b.console.fire then send("fire") end
        end
        update()
    end
    local function clear()
        table.clear(held); table.clear(sticks)
        update()
    end
    return handle,clear
end

function Input.connect(send,active,settings)
    local handle,reset=Input.driver(send,function() return settings.bindings end)
    local function clear() reset() end
    local function bind()
        clear()
        actions:UnbindAction("NOVA_DuelControls")
        local inputs,seen={},{}
        local function add(name)
            if seen[name] then return end
            seen[name]=true
            table.insert(inputs,Bindings.enum(name))
        end
        for _,device in settings.bindings do
            for _,name in device do
                if name=="DPad" then add("DPadLeft"); add("DPadRight") else add(name) end
            end
        end
        actions:BindActionAtPriority("NOVA_DuelControls",function(_,state,key)
            if not active() or gui.MenuIsOpen or UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            if state==Enum.UserInputState.Begin and key.UserInputType.Name:sub(1,11)=="MouseButton" then
                local position=UIS:GetMouseLocation()-gui:GetGuiInset()
                for _,object in game.Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(position.X,position.Y) do
                    if object:IsA("GuiButton") and object.Active then return Enum.ContextActionResult.Pass end
                end
            end
            local code=key.UserInputType.Name:sub(1,11)=="MouseButton" and key.UserInputType or key.KeyCode
            handle(state,code,key.Position)
            return Enum.ContextActionResult.Sink
        end,false,Enum.ContextActionPriority.High.Value+1,table.unpack(inputs))
    end
    local revision=-1
    settings.changed.Event:Connect(function()
        if revision~=settings.revision then revision=settings.revision; bind() end
    end)
    bind()
    UIS.GamepadDisconnected:Connect(clear)
    gui.MenuOpened:Connect(clear)
    UIS.WindowFocusReleased:Connect(clear)
    UIS.TextBoxFocused:Connect(clear)
    return clear
end
return Input
