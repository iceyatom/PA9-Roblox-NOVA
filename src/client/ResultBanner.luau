local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local W=require(script.Parent.Widgets)
local C=W.colors
local Banner={};Banner.__index=Banner
local duration,quietTime,fadeTime=3,.25,.35
local function systemKey(key)
    return key==Enum.KeyCode.ButtonSelect or key==Enum.KeyCode.ButtonStart or key==Enum.KeyCode.Escape or key==Enum.KeyCode.BackSlash
end
local function inputId(input)
    return input.UserInputType==Enum.UserInputType.Touch and input or input.UserInputType.Name..":"..input.KeyCode.Name
end
function Banner.new(gui)
    local self=setmetatable({held={}},Banner)
    local root=W.box(gui,"ResultBanner",0,0,0,0,C.ink,80)
    root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Active=true;root.Visible=false;self.root=root;self.gui=gui
    local origin=W.box(root,"Origin",0,0,0,0);origin.Position=UDim2.fromScale(.5,.5)
    local fit=Instance.new("UIScale");fit.Parent=origin
    local function resize() fit.Scale=math.max(.01,math.min(1.2,(root.AbsoluteSize.X-24)/900,(root.AbsoluteSize.Y-24)/400)) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
    local group=Instance.new("CanvasGroup");group.Name="Banner";group.BackgroundTransparency=1;group.Size=UDim2.fromOffset(900,360)
    group.AnchorPoint=Vector2.new(.5,.5);group.Position=UDim2.fromOffset(0,20);group.Parent=origin;self.group=group
    self.scale=Instance.new("UIScale");self.scale.Parent=group
    local function text(name,y,h,value,size,color,font)
        local label=W.text(group,name,20,y,860,h,value,size,color,font)
        label.TextXAlignment=Enum.TextXAlignment.Center;return label
    end
    self.kicker=text("Kicker",60,28,"ROUND COMPLETE",18,C.mint,Enum.Font.GothamBold)
    self.title=text("Title",98,130,"VICTORY",108,C.white,Enum.Font.GothamBlack)
    self.title.TextScaled=true
    local limit=Instance.new("UITextSizeConstraint");limit.MinTextSize=64;limit.MaxTextSize=108;limit.Parent=self.title
    local track=W.box(group,"Track",330,251,240,3,C.line)
    self.progress=W.box(track,"Progress",0,0,0,3,C.mint)
    self.hint=text("Hint",274,28,"Results in a moment…",16,C.muted,Enum.Font.Gotham)
    local function began(input)
        self.held[inputId(input)]=input
        if self.blocked and self:activation(input) then self.lastActivity=os.clock() end
    end
    UIS.InputBegan:Connect(began)
    UIS.InputEnded:Connect(function(input)
        self.held[inputId(input)]=nil
        if self.blocked and self:activation(input) then self.lastActivity=os.clock() end
    end)
    UIS.WindowFocusReleased:Connect(function() table.clear(self.held);self.lastActivity=os.clock() end)
    UIS.GamepadDisconnected:Connect(function(pad)
        for id,input in self.held do if input.UserInputType==pad then self.held[id]=nil end end
        self.lastActivity=os.clock()
    end)
    -- Seed inputs that were pressed before the banner was constructed.
    for _,input in UIS:GetMouseButtonsPressed() do began(input) end
    for _,input in UIS:GetKeysPressed() do began(input) end
    for _,pad in UIS:GetConnectedGamepads() do
        for _,input in UIS:GetGamepadState(pad) do
            if input.UserInputState==Enum.UserInputState.Begin or input.UserInputState==Enum.UserInputState.Change and input.Position.Magnitude>.18 then began(input) end
        end
    end
    CAS:BindActionAtPriority("NOVA_ResultTransition",function(_,_,input)
        if not self.blocked or not gui.Enabled or Gui.MenuIsOpen or systemKey(input.KeyCode) then return Enum.ContextActionResult.Pass end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+100,Enum.UserInputType.Keyboard,Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3,Enum.UserInputType.Touch,
        Enum.UserInputType.Gamepad1,Enum.UserInputType.Gamepad2,Enum.UserInputType.Gamepad3,Enum.UserInputType.Gamepad4,Enum.UserInputType.Gamepad5,Enum.UserInputType.Gamepad6,Enum.UserInputType.Gamepad7,Enum.UserInputType.Gamepad8)
    return self
end
function Banner:activation(input)
    local kind,key=input.UserInputType.Name,input.KeyCode.Name
    if kind:sub(1,11)=="MouseButton" or kind=="Touch" then return true end
    local bindings=self.getBindings and self.getBindings()
    if kind=="Keyboard" then
        return key=="Space" or key=="Return" or key=="KeypadEnter" or bindings and key==bindings.pc.fire
    end
    if kind:sub(1,7)=="Gamepad" then return key=="ButtonA" or bindings and key==bindings.console.fire end
    return false
end
function Banner:start(key,outcome)
    if self.key==key then return end
    self.key=key;self.blocked=true;self.complete=false;self.started=os.clock();self.lastActivity=self.started;self.exitStarted=nil
    self.root.Visible=true;self.root:SetAttribute("RoundKey",key);self.root:SetAttribute("AnimationComplete",false)
    self.title.Text=outcome=="win" and "VICTORY" or outcome=="loss" and "DEFEAT" or "DRAW"
    local color=outcome=="win" and C.mint or outcome=="loss" and C.red or C.purple
    self.kicker.TextColor3=color;self.progress.BackgroundColor3=color
    self.group.GroupTransparency=1;self.scale.Scale=.9
    self.progress.Size=UDim2.fromScale(0,1)
    self.hint.Text="Results in a moment…"
    if Gui.SelectedObject and Gui.SelectedObject:IsDescendantOf(self.gui) then Gui.SelectedObject=nil end
end
function Banner:hide()
    self.blocked=false;self.complete=false;self.key=nil;self.root.Visible=false;self.exitStarted=nil
    self.root:SetAttribute("AnimationComplete",false)
end
function Banner:ready(key) return self.key==key and self.complete end
function Banner:tick()
    if not self.blocked then return false end
    if not self.gui.Enabled then self:hide();return false end
    local now=os.clock();local elapsed=now-self.started
    local intro=math.clamp(elapsed/.65,0,1);local ease=1-(1-intro)^3
    local held=false
    for _,input in self.held do if self:activation(input) then held=true;break end end
    if Gui.MenuIsOpen then self.lastActivity=now;held=true end
    local canExit=elapsed>=duration and not held and now-self.lastActivity>=quietTime
    if canExit then self.exitStarted=self.exitStarted or now else self.exitStarted=nil end
    local fade=self.exitStarted and math.clamp((now-self.exitStarted)/fadeTime,0,1) or 0
    local reduced=game.Players.LocalPlayer:GetAttribute("ReducedEffects")==true
    self.group.GroupTransparency=(1-ease)+fade*ease
    self.scale.Scale=reduced and 1 or .9+.1*ease+.025*fade
    self.group.Position=UDim2.fromOffset(0,reduced and 0 or 20*(1-ease)-10*fade)
    self.root.BackgroundTransparency=1-.75*ease*(1-fade)
    self.progress.Size=UDim2.fromScale(math.clamp(elapsed/duration,0,1),1)
    self.hint.Text=elapsed>=duration and (held or now-self.lastActivity<quietTime) and "Release fire to continue" or "Results in a moment…"
    if fade>=1 then
        self.blocked=false;self.complete=true;self.root.Visible=false
        self.root:SetAttribute("AnimationComplete",true);return true
    end
    return false
end
return Banner
