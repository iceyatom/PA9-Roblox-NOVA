local UIS=game:GetService("UserInputService")
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local C=W.colors
local MobileControls={}

local moveThreshold=.22
local jumpThreshold=.40
local jumpRelease=.28

function MobileControls.new(playerGui,setStick,fireShot,active)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVAMobileControls"
    gui.ResetOnSpawn=false
    gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
    gui.DisplayOrder=12
    gui.Enabled=false
    gui.Parent=playerGui

    local root=W.box(gui,"SafeArea",0,0,0,0)
    root.Size=UDim2.fromScale(1,1)
    local joystick=W.button(root,"Joystick",0,0,0,0,"",false)
    joystick.Selectable=false
    joystick.AutoButtonColor=false
    joystick.AnchorPoint=Vector2.new(0,1)
    joystick.Position=UDim2.new(0,12,1,-12)
    joystick.BackgroundColor3=C.panel
    joystick.BackgroundTransparency=.23
    W.round(joystick)
    W.stroke(joystick,C.purple,2)

    local thumb=W.box(joystick,"Thumb",0,0,0,0,C.line,6)
    thumb.AnchorPoint=Vector2.new(.5,.5)
    thumb.Position=UDim2.fromScale(.5,.5)
    W.round(thumb)
    W.stroke(thumb,C.purple)
    local arrow=W.text(thumb,"JumpHint",0,0,0,0,"↑",22,C.white,Enum.Font.GothamBold)
    arrow.Size=UDim2.fromScale(1,1)
    arrow.TextXAlignment=Enum.TextXAlignment.Center
    arrow.ZIndex=7

    local fire=W.button(root,"Fire",0,0,0,0,"FIRE",false)
    fire.Selectable=false
    fire.AutoButtonColor=false
    fire.AnchorPoint=Vector2.new(1,1)
    fire.Position=UDim2.new(1,-12,1,-12)
    Style.round(fire,12)
    W.stroke(fire,C.mint,2)

    local stickTouch,fireTouch,origin
    local radius=1
    local jumpHeld=false
    local function paintFire()
        fire.BackgroundColor3=fireTouch and C.purple or C.panel
        fire.BackgroundTransparency=fireTouch and .05 or .23
    end
    paintFire()

    local function updateStick(position)
        local travel=(position-origin)/radius
        if travel.Magnitude>1 then travel=travel.Unit end
        thumb.Position=UDim2.new(.5,travel.X*radius,.5,travel.Y*radius)
        -- Roblox touch coordinates grow downward. Stick up holds Jump until the lower threshold.
        local up=-travel.Y
        jumpHeld=up>=(jumpHeld and jumpRelease or jumpThreshold)
        thumb.BackgroundColor3=jumpHeld and C.purple or C.line
        local axis=math.abs(travel.X)>=moveThreshold and math.sign(travel.X) or 0
        setStick(axis,jumpHeld)
    end

    local function releaseStick()
        stickTouch,origin=nil,nil
        jumpHeld=false
        thumb.Position=UDim2.fromScale(.5,.5)
        thumb.BackgroundColor3=C.line
        setStick(0,false)
    end

    joystick.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.Touch or not gui.Enabled or not joystick.Visible
            or stickTouch or input==fireTouch or not active() then return end
        stickTouch=input
        origin=Vector2.new(input.Position.X,input.Position.Y)
    end)
    fire.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.Touch or not gui.Enabled
            or fireTouch or input==stickTouch or not active() then return end
        fireTouch=input
        paintFire()
        fireShot()
    end)
    UIS.TouchMoved:Connect(function(input)
        if input==stickTouch then updateStick(Vector2.new(input.Position.X,input.Position.Y)) end
    end)
    UIS.TouchEnded:Connect(function(input)
        if input==stickTouch then releaseStick() end
        if input==fireTouch then
            fireTouch=nil
            paintFire()
        end
    end)

    local function resize()
        local size=math.clamp(math.floor(math.min(root.AbsoluteSize.Y*.16,root.AbsoluteSize.X*.14)),46,68)
        local diameter=size*2+4
        local thumbSize=math.floor(diameter*.42)
        radius=(diameter-thumbSize)/2-3
        joystick.Size=UDim2.fromOffset(diameter,diameter)
        thumb.Size=UDim2.fromOffset(thumbSize,thumbSize)
        arrow.TextSize=math.floor(thumbSize*.52)
        fire.Size=UDim2.fromOffset(math.floor(size*1.42),size)
        fire.TextSize=math.floor(size*.30)
        if stickTouch then updateStick(Vector2.new(stickTouch.Position.X,stickTouch.Position.Y)) end
    end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()

    local function reset()
        releaseStick()
        fireTouch=nil
        paintFire()
    end
    return function(playing,practice)
        if not playing and gui.Enabled then reset()
        elseif practice and stickTouch then releaseStick() end
        joystick.Visible=not practice
        gui.Enabled=playing
    end,reset
end

return MobileControls
