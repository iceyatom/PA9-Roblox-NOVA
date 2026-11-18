local UIS=game:GetService("UserInputService")
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local C=W.colors
local MobileControls={}

function MobileControls.new(playerGui,handle,active)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVAMobileControls"
    gui.ResetOnSpawn=false
    gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
    gui.DisplayOrder=12
    gui.Enabled=false
    gui.Parent=playerGui

    local root=W.box(gui,"SafeArea",0,0,0,0)
    root.Size=UDim2.fromScale(1,1)
    local contacts,counts={},{}
    local buttons={}
    local function paint(action,pressed)
        local button=buttons[action]
        button.BackgroundColor3=pressed and C.purple or C.panel
        button.BackgroundTransparency=pressed and .05 or .23
    end
    local function make(action,label)
        local button=W.button(root,action,0,0,0,0,label,false)
        button.Selectable=false
        button.AutoButtonColor=false
        button.AnchorPoint=Vector2.new(action=="Fire" and 1 or 0,1)
        Style.round(button,12)
        W.stroke(button,action=="Fire" and C.mint or C.purple,2)
        buttons[action]=button
        paint(action,false)
        button.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.Touch or contacts[input]
                or not gui.Enabled or not button.Visible or not active() then return end
            contacts[input]=action
            counts[action]=(counts[action] or 0)+1
            if counts[action]==1 then
                paint(action,true)
                handle(action,true)
            end
        end)
        return button
    end
    local left=make("Left","←")
    local right=make("Right","→")
    local jump=make("Jump","JUMP")
    local fire=make("Fire","FIRE")
    UIS.TouchEnded:Connect(function(input)
        local action=contacts[input]
        if not action then return end
        contacts[input]=nil
        counts[action]-=1
        if counts[action]==0 then
            paint(action,false)
            handle(action,false)
        end
    end)

    local function resize()
        local size=math.clamp(math.floor(math.min(root.AbsoluteSize.Y*.16,root.AbsoluteSize.X*.14)),46,68)
        local edge,gap=12,8
        left.Position=UDim2.new(0,edge,1,-edge)
        right.Position=UDim2.new(0,edge+size+gap,1,-edge)
        jump.Position=UDim2.new(0,edge,1,-edge-size-gap)
        fire.Position=UDim2.new(1,-edge,1,-edge)
        for _,button in {left,right} do
            button.Size=UDim2.fromOffset(size,size)
            button.TextSize=math.floor(size*.53)
        end
        jump.Size=UDim2.fromOffset(size*2+gap,size)
        fire.Size=UDim2.fromOffset(math.floor(size*1.42),size)
        jump.TextSize=math.floor(size*.30)
        fire.TextSize=jump.TextSize
    end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()

    return function(playing,practice)
        gui.Enabled=playing
        left.Visible=not practice
        right.Visible=not practice
        jump.Visible=not practice
    end,function()
        for action in counts do paint(action,false) end
        table.clear(contacts)
        table.clear(counts)
    end
end

return MobileControls
