local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local C=W.colors
local MobileLobby={}
local scale=.68
local width=158
local rowHeight=52

function MobileLobby.new(playerGui,left,right,chips)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVAMobileLobby"
    gui.ResetOnSpawn=false
    gui.DisplayOrder=9
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=playerGui
    local root=W.box(gui,"SafeArea",0,0,0,0)
    root.Size=UDim2.fromScale(1,1)
    local expanded
    local drawers={}

    local function update()
        for _,drawer in drawers do
            local open=drawer==expanded
            drawer.list.Visible=open
            drawer.toggle.Text=open and "Close" or drawer.label
            drawer.toggle.BackgroundColor3=open and C.purple or C.panel
        end
    end

    local function slot(parent,name,index,child,height)
        local row=W.box(parent,name,4,4+(index-1)*rowHeight,220,height)
        local fit=Instance.new("UIScale")
        fit.Scale=scale
        fit.Parent=row
        -- The menu still owns the launcher. The layout takes precedence over its desktop position.
        local layout=Instance.new("UIListLayout")
        layout.Parent=row
        child.AnchorPoint=Vector2.zero
        child.Parent=row
    end

    local function build(name,label,rightSide,menus,extra)
        local side=W.box(root,name,0,0,width,44)
        if rightSide then side.AnchorPoint=Vector2.new(1,0) end
        side.Position=UDim2.new(rightSide and 1 or 0,rightSide and -10 or 10,0,18)
        local toggle=W.button(side,"Toggle",0,0,84,44,label,false)
        if rightSide then toggle.Position=UDim2.fromOffset(width-84,0) end
        Style.surface(toggle,10)
        local ready=W.box(toggle,"RewardReady",0,0,8,8,C.mint,6)
        ready.Position=UDim2.new(1,-11,0,5)
        W.round(ready)
        local function refreshReady()
            ready.Visible=false
            for _,menu in menus do
                if menu.badge and menu.badge.Visible then ready.Visible=true; break end
            end
        end
        for _,menu in menus do
            if menu.badge then menu.badge:GetPropertyChangedSignal("Visible"):Connect(refreshReady) end
        end
        refreshReady()
        local list=Instance.new("ScrollingFrame")
        list.Name="Entries"
        list.BackgroundColor3=C.ink
        list.BackgroundTransparency=.18
        list.BorderSizePixel=0
        list.Position=UDim2.fromOffset(0,50)
        list.ScrollingDirection=Enum.ScrollingDirection.Y
        list.ScrollBarThickness=3
        list.ScrollBarImageColor3=C.muted
        list.Selectable=false
        list.Parent=side
        Style.surface(list,10)
        local height=#menus*rowHeight+(extra and 22 or 0)
        list.CanvasSize=UDim2.fromOffset(0,height)
        for i,menu in menus do
            slot(list,menu.launcher.Name.."Slot",i,menu.launcher,72)
        end
        if extra then slot(list,"BoostsSlot",#menus+1,extra,30) end
        local drawer={toggle=toggle,list=list,label=label,height=height}
        table.insert(drawers,drawer)
        toggle.Activated:Connect(function()
            if expanded==drawer then
                expanded=nil
            else
                expanded=drawer
                list.CanvasPosition=Vector2.zero
            end
            update()
        end)
    end

    build("Left","Menu  ›",false,left,chips)
    build("Right","‹  More",true,right)
    local function resize()
        local height=root.AbsoluteSize.Y
        local top=math.clamp(math.floor(height*.04),8,18)
        for _,drawer in drawers do
            local side=drawer.toggle.Parent
            side.Position=UDim2.new(side.Position.X.Scale,side.Position.X.Offset,0,top)
            drawer.list.Size=UDim2.fromOffset(width,math.min(drawer.height,math.max(44,height-top-137)))
        end
    end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not gui.Enabled then expanded=nil; update() end
    end)
    resize()
    update()
    return gui
end

return MobileLobby
