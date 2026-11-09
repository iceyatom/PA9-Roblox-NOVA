-- Inventory surfaces share NOVA's progression palette and use a restrained raised face.
local W=require(script.Parent.Widgets)
local Gui=game:GetService("GuiService")
local Style={}
function Style.round(object,radius)
    local corner=object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,radius or 10); corner.Parent=object
    return corner
end
function Style.surface(object,radius)
    Style.round(object,radius)
    if not object:FindFirstChildOfClass("UIStroke") then W.stroke(object,W.colors.line) end
    return object
end
function Style.button(parent,name,x,y,width,height,text,primary)
    local button=W.button(parent,name,x,y,width,height,text,primary)
    button.TextSize=18
    Style.round(button,8)
    W.stroke(button,W.colors.white,1)
    local stroke=button:FindFirstChildOfClass("UIStroke"); stroke.Transparency=.88
    local face=Instance.new("UIGradient")
    face.Name="RaisedFace"; face.Rotation=90
    face.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(202,207,225)); face.Parent=button
    local shadow=W.box(parent,name.."Depth",x,y+4,width,height,W.rgb("05070d"),button.ZIndex-1)
    Style.round(shadow,8); shadow.Active=false
    local function sync()
        shadow.Size=button.Size; shadow.AnchorPoint=button.AnchorPoint
        shadow.Position=button.Position+UDim2.fromOffset(0,4)
        shadow.Visible=button.Visible; shadow.ZIndex=button.ZIndex-1
    end
    button:GetPropertyChangedSignal("Position"):Connect(sync)
    button:GetPropertyChangedSignal("Size"):Connect(sync)
    button:GetPropertyChangedSignal("Visible"):Connect(sync)
    button:GetPropertyChangedSignal("ZIndex"):Connect(sync)
    button.Destroying:Once(function() shadow:Destroy() end)
    local function highlight(on)
        stroke.Transparency=button:GetAttribute("InventoryCard") and 0 or (on and .45 or .88)
        shadow.BackgroundColor3=on and W.rgb("111025") or W.rgb("05070d")
    end
    button.MouseEnter:Connect(function() highlight(true) end)
    button.MouseLeave:Connect(function() highlight(Gui.SelectedObject==button) end)
    button.SelectionGained:Connect(function() highlight(true) end)
    button.SelectionLost:Connect(function() highlight(false) end)
    return button
end
return Style
