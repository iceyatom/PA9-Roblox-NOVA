local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local Gamepad=game:GetService("GamepadService")
local W=require(script.Parent.Widgets)
local C=W.colors
local Menu={}
Menu.__index=Menu
local names={MouseButton1="Left mouse",MouseButton2="Right mouse",MouseButton3="Middle mouse",Thumbstick1="Left stick",Thumbstick2="Right stick",DPad="D-pad",ButtonA="A / Cross",ButtonB="B / Circle",ButtonX="X / Square",ButtonY="Y / Triangle",ButtonL1="LB / L1",ButtonR1="RB / R1",ButtonL2="LT / L2",ButtonR2="RT / R2",ButtonL3="Left stick click",ButtonR3="Right stick click",DPadLeft="D-pad left",DPadRight="D-pad right",DPadUp="D-pad up",DPadDown="D-pad down"}
local function label(name) return names[name] or name:gsub("(%l)(%u)","%1 %2") end
local function isGamepad(kind) return kind.Name:sub(1,7)=="Gamepad" end

function Menu.new(playerGui,settings,clear)
    local self=setmetatable({settings=settings,clear=clear,device="pc",buttons={},available=true},Menu)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVASettings"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=30
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=playerGui
    self.gui=gui
    -- Leave View/Touchpad and automatic navigation to Roblox's native cursor/GUI mode.
    Gui.AutoSelectGuiEnabled=true
    local root=W.box(gui,"Root",0,0,0,0)
    root.Size=UDim2.fromScale(1,1)
    local origin=W.box(root,"Origin",0,0,0,0); origin.Position=UDim2.fromScale(.5,.5)
    local scale=Instance.new("UIScale"); scale.Parent=origin
    local function resize() scale.Scale=math.max(.01,math.min(root.AbsoluteSize.X/1440,root.AbsoluteSize.Y/810)) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
    local stage=W.box(origin,"Stage",-720,-405,1440,810)
    self.launcher=W.button(stage,"OpenSettings",1235,96,170,40,"Settings",false)
    local overlay=W.box(stage,"Overlay",0,0,1440,810,C.ink,10)
    overlay.BackgroundTransparency=.16; overlay.Active=true; overlay.Visible=false
    self.overlay=overlay
    local panel=W.box(overlay,"Panel",300,143,840,524,C.panel)
    W.stroke(panel,C.line)
    W.box(panel,"Accent",0,0,4,524,C.purple)
    W.text(panel,"Title",28,18,580,43,"Settings",34,C.white,Enum.Font.GothamBlack)
    W.text(panel,"Subtitle",28,68,780,25,"Your duel controls. Set each device independently.",17,C.muted)
    self.done=W.button(panel,"Done",660,26,150,40,"Done",true)
    self.tabs={}
    for i,device in {"pc","console"} do
        local tab=W.button(panel,device.."Tab",28+(i-1)*404,111,380,40,i==1 and "Keyboard + mouse" or "Console controller",false)
        self.tabs[device]=tab
        tab.Activated:Connect(function()
            if not self:canActivate() then return end
            self.device=device; self:refresh()
        end)
    end
    local function binding(action,x,y,width)
        local b=W.button(panel,action,x,y,width,44,"",false)
        self.buttons[action]=b
        b.Activated:Connect(function() if self:canActivate() then self:startCapture(action,b) end end)
        return b
    end
    W.text(panel,"Move",28,185,200,27,"Move",23,C.white,Enum.Font.GothamBold)
    W.text(panel,"MoveHint",28,214,204,19,"Left / right",14,C.muted)
    binding("left",250,184,253); binding("right",519,184,261); binding("move",250,184,530)
    W.box(panel,"Rule1",28,252,752,1,C.line)
    W.text(panel,"Jump",28,278,200,28,"Jump",23,C.white,Enum.Font.GothamBold)
    binding("jump",250,270,530)
    W.box(panel,"Rule2",28,336,752,1,C.line)
    W.text(panel,"Fire",28,359,200,28,"Fire",23,C.white,Enum.Font.GothamBold)
    binding("fire",250,351,530)
    self.status=W.text(panel,"Status",28,413,752,39,"",15,C.muted)
    self.status.TextWrapped=true
    self.status.TextTruncate=Enum.TextTruncate.None
    self.reset=W.button(panel,"ResetDefaults",28,466,180,36,"Reset defaults",false)
    local effects=W.button(panel,"ReducedEffects",230,466,290,36,"",false)
    self.effects=effects
    local player=game.Players.LocalPlayer
    local function syncEffects()
        effects.Text="Reduced Effects  /  "..(player:GetAttribute("ReducedEffects") and "On" or "Off")
    end
    player:GetAttributeChangedSignal("ReducedEffects"):Connect(syncEffects); syncEffects()
    effects.Activated:Connect(function()
        if not self:canActivate() or self.effectsBusy then return end
        self.effectsBusy=true
        local ok,response=pcall(function()
            return game.ReplicatedStorage.NOVA.InventoryRequest:InvokeServer("effects",player:GetAttribute("ReducedEffects") and "off" or "on")
        end)
        self.effectsBusy=false
        self.message=not ok and "Could not save. Try again." or not response.ok and response.message or nil
        self:refresh()
    end)
    self.launcher.Activated:Connect(function() self:setOpen(not settings.opened) end)
    self.done.Activated:Connect(function() if self:canActivate() then self:setOpen(false) end end)
    self.reset.Activated:Connect(function() if self:canActivate() then settings:reset() end end)
    settings.changed.Event:Connect(function() self:refresh() end)
    CAS:BindActionAtPriority("NOVA_SettingsBack",function(_,state)
        if not settings.opened or self.capture then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self:setOpen(false) end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+25,Enum.KeyCode.ButtonB)
    -- Capture processed inputs too: clicks over the menu belong to its UI.
    local function captureInput(key)
        if self.captureInput then self.captureInput(key.UserInputState,key) end
    end
    UIS.InputBegan:Connect(captureInput)
    UIS.InputChanged:Connect(captureInput)
    UIS.InputEnded:Connect(captureInput)
    UIS.WindowFocusReleased:Connect(function() if self.capture then self:endCapture() end end)
    UIS.GamepadDisconnected:Connect(function() if self.capture then self:endCapture() end end)
    Gamepad:GetPropertyChangedSignal("GamepadCursorEnabled"):Connect(function()
        if Gamepad.GamepadCursorEnabled and self.capture then self:endCapture(false) end
    end)
    Gui.MenuOpened:Connect(function() if settings.opened then self:setOpen(false) end end)
    self:refresh()
    return self
end

function Menu:canActivate()
    return not self.capture and os.clock()>(self.suppressUntil or 0)
end

function Menu:buttonsActive(active)
    for _,button in self.buttons do button.Active=active end
    for _,button in self.tabs do button.Active=active end
    self.done.Active=active
    self.effects.Active=active
    self.reset.Active=active
end

function Menu:refresh()
    local b=self.settings.bindings[self.device]
    for action,button in self.buttons do
        button.Visible=b[action]~=nil
        if b[action] then button.Text=(action=="left" and "Left   /   " or action=="right" and "Right   /   " or "")..label(b[action]) end
    end
    for device,tab in self.tabs do
        tab.BackgroundColor3=device==self.device and C.purple or C.line
        tab.TextColor3=C.white
    end
    self.status.Text=self.message or self.settings.status
    self.status.TextColor3=self.message and C.purple or C.muted
    -- Explicit selection paths keep every control reachable using a gamepad.
    local rows=self.device=="pc" and {self.buttons.left,self.buttons.right,self.buttons.jump,self.buttons.fire} or {self.buttons.move,self.buttons.jump,self.buttons.fire}
    local chain={self.tabs.pc,self.tabs.console}
    for _,button in rows do table.insert(chain,button) end
    table.insert(chain,self.effects); table.insert(chain,self.reset); table.insert(chain,self.done)
    for i,button in chain do
        button.NextSelectionUp=chain[i==1 and #chain or i-1]
        button.NextSelectionDown=chain[i==#chain and 1 or i+1]
        button.NextSelectionLeft=button.NextSelectionUp
        button.NextSelectionRight=button.NextSelectionDown
    end
end

function Menu:setAvailable(available)
    self.available=available
    if not available then self:setOpen(false) end
    self.gui.Enabled=available
    self.launcher.Visible=available and not self.settings.opened
end

function Menu:setOpen(open)
    if open and not self.available then return end
    if self.settings.opened==open then return end
    if open and self.beforeOpen then self.beforeOpen() end
    self.clear()
    if self.capture then self:endCapture() end
    self.settings.opened=open
    self.overlay.Visible=open
    self.launcher.Visible=self.available and not open
    self.message=nil
    local player=game.Players.LocalPlayer
    if not self.controls then
        local module=player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then local ok,controls=pcall(function() return require(module):GetControls() end); if ok then self.controls=controls end end
    end
    if open then
        if self.controls then self.controls:Disable() end
        if isGamepad(UIS:GetLastInputType()) then self.device="console" end
        Gui.SelectedObject=self.tabs[self.device]
    else
        if self.controls then self.controls:Enable() end
        Gui.SelectedObject=isGamepad(UIS:GetLastInputType()) and self.selectionOnClose and self.selectionOnClose() or nil
        self.settings:save()
    end
    self:refresh()
end

function Menu:endCapture(restoreCursor)
    if not self.capture then return end
    local capture=self.capture
    local button=capture.button
    self.capture=nil
    self.captureInput=nil
    CAS:UnbindAction("NOVA_RebindCapture")
    Gui.GuiNavigationEnabled=capture.navigation
    local activates=capture.key=="MouseButton1" or capture.key=="ButtonA" or capture.key=="Space"
    self.suppressUntil=activates and os.clock()+.15 or 0
    self.message=nil
    -- Let the captured release finish before buttons can activate again.
    task.defer(function()
        game:GetService("RunService").Heartbeat:Wait()
        if self.capture then return end
        self:buttonsActive(true)
        if self.settings.opened then
            if capture.cursor and restoreCursor~=false and not Gui.MenuIsOpen and not Gamepad.GamepadCursorEnabled then
                Gamepad:EnableGamepadCursor(button)
            end
            if not Gamepad.GamepadCursorEnabled then Gui.SelectedObject=button end
        end
    end)
    self:refresh()
end

function Menu:startCapture(action,button)
    if not self.settings.opened or self.capture then return end
    self.clear()
    local capture={action=action,device=self.device,button=button,navigation=Gui.GuiNavigationEnabled,cursor=Gamepad.GamepadCursorEnabled}
    self.capture=capture
    self:buttonsActive(false)
    if capture.cursor then Gamepad:DisableGamepadCursor() end
    Gui.GuiNavigationEnabled=false
    Gui.SelectedObject=nil
    self.message=action=="move" and "Tilt either stick, or press the D-pad. Touchpad / View returns to Roblox navigation." or self.device=="pc" and "Press a key or mouse button. Esc closes settings." or "Press a controller button. Touchpad / View returns to Roblox navigation."
    self:refresh()
    button.Text="Listening..."
    self.captureInput=function(state,key)
        if key.KeyCode==Enum.KeyCode.ButtonSelect or key.KeyCode==Enum.KeyCode.ButtonStart or key.KeyCode==Enum.KeyCode.BackSlash or key.KeyCode==Enum.KeyCode.Escape then
            if state==Enum.UserInputState.Begin then self:endCapture(false) end
            return Enum.ContextActionResult.Pass
        end
        local ended=state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel
        if capture.completed then
            local name=key.UserInputType.Name:sub(1,11)=="MouseButton" and key.UserInputType.Name or key.KeyCode.Name
            if name==capture.key and (ended or key.Position.Magnitude<.18 and state==Enum.UserInputState.Change) then self:endCapture() end
            return Enum.ContextActionResult.Sink
        end
        if state~=Enum.UserInputState.Begin and state~=Enum.UserInputState.Change then return Enum.ContextActionResult.Sink end
        local name
        if capture.device=="pc" then
            if key.UserInputType==Enum.UserInputType.Keyboard then name=key.KeyCode.Name
            elseif key.UserInputType.Name:sub(1,11)=="MouseButton" then name=key.UserInputType.Name end
        elseif isGamepad(key.UserInputType) then
            name=key.KeyCode.Name
            if action=="move" then
                if name:sub(1,4)=="DPad" then name="DPad"
                elseif (name~="Thumbstick1" and name~="Thumbstick2") or math.abs(key.Position.X)<.6 then name=nil end
            end
        end
        if name then
            local ok,message=self.settings:set(capture.device,action,name)
            self.message=ok and "Release the input to finish binding." or message
            self:refresh()
            if ok then
                capture.completed=true
                capture.key=key.UserInputType.Name:sub(1,11)=="MouseButton" and key.UserInputType.Name or key.KeyCode.Name
            else button.Text="Listening..." end
        end
        return Enum.ContextActionResult.Sink
    end
    CAS:BindActionAtPriority("NOVA_RebindCapture",function(_,state,key)
        if key.KeyCode==Enum.KeyCode.ButtonSelect or key.KeyCode==Enum.KeyCode.ButtonStart or key.KeyCode==Enum.KeyCode.BackSlash or key.KeyCode==Enum.KeyCode.Escape then
            if state==Enum.UserInputState.Begin then self:endCapture(false) end
            return Enum.ContextActionResult.Pass
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+20,Enum.UserInputType.Keyboard,Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3,
        Enum.UserInputType.Gamepad1,Enum.UserInputType.Gamepad2,Enum.UserInputType.Gamepad3,Enum.UserInputType.Gamepad4,Enum.UserInputType.Gamepad5,Enum.UserInputType.Gamepad6,Enum.UserInputType.Gamepad7,Enum.UserInputType.Gamepad8)
    task.delay(15,function() if self.capture==capture then self:endCapture() end end)
end
return Menu
