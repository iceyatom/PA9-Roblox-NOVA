local UIS=game:GetService("UserInputService")
local Input={}
function Input.connect(send,active)
    local down={}
    local function movement()
        send("move",(down.D and 1 or 0)-(down.A and 1 or 0),down.S==true)
    end
    local function clear()
        table.clear(down)
        if active() then movement() end
    end
    UIS.InputBegan:Connect(function(key,processed)
        if processed or not active() or UIS:GetFocusedTextBox() then return end
        if key.UserInputType==Enum.UserInputType.MouseButton1 then send("fire"); return end
        local name=key.KeyCode.Name
        if down[name] then return end
        if name=="W" then down.W=true; send("jump")
        elseif name=="A" or name=="D" or name=="S" then down[name]=true; movement() end
    end)
    UIS.InputEnded:Connect(function(key)
        local name=key.KeyCode.Name
        if down[name] then
            down[name]=nil
            if name~="W" and active() then movement() end
        end
    end)
    UIS.WindowFocusReleased:Connect(clear)
    UIS.TextBoxFocused:Connect(clear)
    return clear
end
return Input
