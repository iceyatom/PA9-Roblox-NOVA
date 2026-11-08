local UIS=game:GetService("UserInputService")
local actions=game:GetService("ContextActionService")
local gui=game:GetService("GuiService")
local Input={}

function Input.gamepad(move,jump,fire)
    local held={}
    local function reset()
        table.clear(held)
    end
    local function handle(state,key,position)
        local released=state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel
        if key==Enum.KeyCode.ButtonR2 or key==Enum.KeyCode.ButtonA or key==Enum.KeyCode.Space then
            if released then held[key]=nil
            elseif state==Enum.UserInputState.Begin and not held[key] then
                held[key]=true
                if key==Enum.KeyCode.ButtonR2 then fire() else jump() end
            end
        elseif key==Enum.KeyCode.Thumbstick1 then
            local x=released and 0 or position.X
            -- Remove center drift, then quantize to limit movement traffic.
            local magnitude=math.clamp((math.abs(x)-0.18)/0.82,0,1)
            move(math.sign(x)*math.round(magnitude*32)/32)
        end
    end
    return handle,reset
end

function Input.connect(send,active)
    local down={}
    local stickX=0
    local lastX=0
    local function movement()
        local x=stickX
        if down.A or down.D then x=(down.D and 1 or 0)-(down.A and 1 or 0) end
        if x~=lastX then
            lastX=x
            send("move",x)
        end
    end
    local handle,reset=Input.gamepad(function(x)
        stickX=x
        movement()
    end,function() send("jump") end,function() send("fire") end)
    local function clear()
        table.clear(down)
        reset()
        stickX=0
        if active() then movement() end
        lastX=0
    end
    actions:BindActionAtPriority("NOVA_DuelControls",function(_,state,key)
        if not active() or gui.MenuIsOpen or UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
        handle(state,key.KeyCode,key.Position)
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.Thumbstick1,Enum.KeyCode.ButtonR2,Enum.KeyCode.ButtonA,Enum.KeyCode.Space)
    UIS.GamepadDisconnected:Connect(clear)
    gui.MenuOpened:Connect(clear)
    UIS.InputBegan:Connect(function(key,processed)
        if processed or not active() or UIS:GetFocusedTextBox() then return end
        if key.UserInputType==Enum.UserInputType.MouseButton1 then send("fire"); return end
        local name=key.KeyCode.Name
        if down[name] then return end
        if name=="A" or name=="D" then down[name]=true; movement() end
    end)
    UIS.InputEnded:Connect(function(key)
        local name=key.KeyCode.Name
        if down[name] then
            down[name]=nil
            if active() then movement() end
        end
    end)
    UIS.WindowFocusReleased:Connect(clear)
    UIS.TextBoxFocused:Connect(clear)
    return clear
end
return Input
