local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local Gamepad=game:GetService("GamepadService")
local Core=game:GetService("StarterGui")
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local MobilePanel=require(script.Parent.MobilePanel)
local mobile=UIS.TouchEnabled
local C=W.colors
local Menu={}
Menu.__index=Menu
local names={MouseButton1="Left mouse",MouseButton2="Right mouse",MouseButton3="Middle mouse",Thumbstick1="Left stick",Thumbstick2="Right stick",DPad="D-pad",ButtonA="A / Cross",ButtonB="B / Circle",ButtonX="X / Square",ButtonY="Y / Triangle",ButtonL1="LB / L1",ButtonR1="RB / R1",ButtonL2="LT / L2",ButtonR2="RT / R2",ButtonL3="Left stick click",ButtonR3="Right stick click",DPadLeft="D-pad left",DPadRight="D-pad right",DPadUp="D-pad up",DPadDown="D-pad down"}
local function label(name) return names[name] or name:gsub("(%l)(%u)","%1 %2") end
local function isGamepad(kind) return kind.Name:sub(1,7)=="Gamepad" end
local function rect(object,x,y,width,height)
    object.Position=UDim2.fromOffset(x,y)
    object.Size=UDim2.fromOffset(width,height)
end

local function settingsIcon(parent)
    local icon=W.box(parent,"SettingsIcon",8,8,56,56,C.ink,2)
    Style.surface(icon,10)
    local positions={20,33,25}
    for i,x in positions do
        local y=14+(i-1)*14
        local rail=W.box(icon,"Rail"..i,11,y,34,2,C.muted,3)
        Style.round(rail,2)
        local knob=W.box(icon,"Knob"..i,x-4,y-3,8,8,C.purple,4)
        Style.round(knob,3)
    end
    return icon
end

function Menu.new(playerGui,settings,clear)
    local self=setmetatable({settings=settings,clear=clear,device="pc",buttons={},available=true},Menu)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVASettings"; gui.ResetOnSpawn=false; gui.DisplayOrder=10
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=playerGui
    self.gui=gui
    -- Leave View/Touchpad and automatic navigation to Roblox's native cursor/GUI mode.
    Gui.AutoSelectGuiEnabled=true
    local launcher=W.button(gui,"OpenSettings",0,0,220,72,"Settings",false)
    launcher.AnchorPoint=Vector2.new(1,0)
    launcher.Position=UDim2.new(1,-16,0,16)
    launcher.BackgroundColor3=C.panel
    launcher.Font=Enum.Font.GothamBlack
    Style.surface(launcher,10)
    self.launcher=launcher
    local stroke=launcher:FindFirstChildOfClass("UIStroke")
    launcher.MouseEnter:Connect(function() stroke.Color=C.purple end)
    launcher.MouseLeave:Connect(function() stroke.Color=C.line end)

    local overlay=Instance.new("ScrollingFrame")
    overlay.Name="Overlay";overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=20
    overlay.BackgroundColor3=C.ink;overlay.BackgroundTransparency=.12;overlay.BorderSizePixel=0
    overlay.ScrollBarThickness=4;overlay.ScrollBarImageColor3=C.purple;overlay.ScrollingDirection=Enum.ScrollingDirection.Y
    overlay.Active=true;overlay.Visible=false;overlay.Parent=gui
    self.overlay=overlay
    local panel=W.box(overlay,"Panel",0,0,0,0,C.panel)
    panel.Active=true;Style.surface(panel,12);self.panel=panel
    if mobile then
        MobilePanel.disableScroll(overlay)
        MobilePanel.attach(overlay,panel)
    end
    local icon=settingsIcon(panel)
    icon.Position=UDim2.fromOffset(24,16)
    self.title=W.text(panel,"Title",94,22,0,44,"Settings",29,C.white,Enum.Font.GothamBlack)
    self.close=Style.button(panel,"Close",0,0,0,0,"×",false);self.close.TextSize=26
    self.done=Style.button(panel,"Done",0,0,0,0,"Done",true)
    self.tabs={}
    for i,device in {"pc","console"} do
        local tab=Style.button(panel,device.."Tab",0,0,0,0,i==1 and "Keyboard + mouse" or "Console controller",false)
        tab.TextWrapped=true
        self.tabs[device]=tab
        tab.Activated:Connect(function()
            if not self:canActivate() then return end
            self.device=device; self:refresh()
        end)
    end
    self.rows={}
    for i,section in {{"Move","left","right","move"},{"Jump","jump"},{"Fire","fire"}} do
        local row=W.box(panel,section[1].."Card",0,0,0,0,C.ink)
        Style.surface(row,10)
        self.rows[i]=row
        W.text(row,"Label",16,0,0,0,section[1],22,C.white,Enum.Font.GothamBold)
        for index=2,#section do
            local action=section[index]
            local button=Style.button(row,action,0,0,0,0,"",false)
            button.TextWrapped=true
            self.buttons[action]=button
            button.Activated:Connect(function() if self:canActivate() then self:startCapture(action,button) end end)
        end
    end
    self.status=W.text(panel,"Status",24,0,0,0,"",16,C.muted,Enum.Font.GothamMedium)
    self.status.TextWrapped=true
    self.status.TextTruncate=Enum.TextTruncate.None
    self.reset=Style.button(panel,"ResetDefaults",0,0,0,0,"Reset defaults",false)
    local effects=Style.button(panel,"ReducedEffects",0,0,0,0,"",false)
    self.effects=effects
    local player=game.Players.LocalPlayer
    local function syncEffects()
        local enabled=player:GetAttribute("ReducedEffects")==true
        effects.Text=enabled and "Reduced Effects · On" or "Reduced Effects · Off"
        effects.BackgroundColor3=enabled and C.purple or C.line
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
    self.close.Activated:Connect(function() if self:canActivate() then self:setOpen(false) end end)
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
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
    launcher:GetPropertyChangedSignal("Visible"):Connect(function()
        if launcher.Visible then task.defer(function() self:layout() end) end
    end)
    self:layout()
    self:refresh()
    return self
end

function Menu:layout()
    local viewport=self.overlay.AbsoluteSize
    local compactLauncher=false
    if self.launcher.Parent==self.gui then
        -- Leave space for Roblox's player list and its Level and Prestige columns.
        local playerListSpace=viewport.X>=680 and Core:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) and 336 or 0
        compactLauncher=viewport.X-playerListSpace<480
        self.launcher.Position=UDim2.new(1,-16-playerListSpace,0,16)
    end
    self.launcher.Size=UDim2.fromOffset(compactLauncher and 68 or 220,72)
    self.launcher.TextSize=compactLauncher and 15 or 26

    local width=mobile and 880 or math.clamp(viewport.X-24,280,940)
    local narrow=width<600
    local margin=narrow and 16 or 24
    local inner=width-2*margin
    local tabWidth=(inner-12)/2
    local rowHeight=narrow and 100 or 70
    local rowTop=narrow and 214 or mobile and 174 or 188
    local footer=rowTop+3*(rowHeight+12)+4
    local height=footer+(narrow and 120 or 72)

    if mobile then
        self.panel.Size=UDim2.fromOffset(width,height)
    else
        rect(self.panel,math.max(12,(viewport.X-width)/2),math.max(12,(viewport.Y-height)/2),width,height)
        self.overlay.CanvasSize=UDim2.fromOffset(0,height+24)
    end
    rect(self.title,94,22,width-174,44)
    self.title.TextSize=narrow and 25 or 29
    rect(self.close,width-margin-52,24,52,40)
    rect(self.tabs.pc,margin,90,tabWidth,44)
    rect(self.tabs.console,margin+tabWidth+12,90,tabWidth,44)
    self.tabs.pc.TextSize=narrow and 16 or 18
    self.tabs.console.TextSize=self.tabs.pc.TextSize
    rect(self.status,margin,140,inner,rowTop-144)

    for i,row in self.rows do
        rect(row,margin,rowTop+(i-1)*(rowHeight+12),inner,rowHeight)
        rect(row.Label,16,narrow and 8 or 0,narrow and inner-32 or 160,narrow and 30 or rowHeight)
    end
    local bindingX,bindingY=narrow and 16 or 184,narrow and 46 or 12
    local bindingWidth=inner-bindingX-16
    local pairWidth=(bindingWidth-10)/2
    for _,action in {"move","jump","fire"} do rect(self.buttons[action],bindingX,bindingY,bindingWidth,44) end
    rect(self.buttons.left,bindingX,bindingY,pairWidth,44)
    rect(self.buttons.right,bindingX+pairWidth+10,bindingY,pairWidth,44)
    for _,button in self.buttons do button.TextSize=narrow and 16 or 18 end

    rect(self.effects,margin,footer,narrow and inner or 228,44)
    rect(self.reset,narrow and margin or margin+240,narrow and footer+54 or footer,narrow and tabWidth or 156,44)
    rect(self.done,width-margin-(narrow and tabWidth or 132),narrow and footer+54 or footer,narrow and tabWidth or 132,44)
    self.reset.TextSize=narrow and 15 or 18
end

function Menu:canActivate()
    return not self.capture and os.clock()>(self.suppressUntil or 0)
end

function Menu:buttonsActive(active)
    for _,button in self.buttons do button.Active=active end
    for _,button in self.tabs do button.Active=active end
    self.done.Active=active
    self.close.Active=active
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
    self.status.TextColor3=self.capture and C.mint or self.message and C.white or C.muted
    -- Explicit selection paths keep every control reachable using a gamepad.
    local rows=self.device=="pc" and {self.buttons.left,self.buttons.right,self.buttons.jump,self.buttons.fire} or {self.buttons.move,self.buttons.jump,self.buttons.fire}
    local chain={self.tabs.pc,self.tabs.console}
    for _,button in rows do table.insert(chain,button) end
    table.insert(chain,self.effects); table.insert(chain,self.reset); table.insert(chain,self.done);table.insert(chain,self.close)
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
    if open and self.beforeOpen and self.beforeOpen()==false then return end
    self.clear()
    if self.capture then self:endCapture() end
    self.settings.opened=open
    self.overlay.Visible=open
    self.gui:SetAttribute("MenuOpen",open)
    self.launcher.Visible=self.available and not open
    self.message=nil
    local player=game.Players.LocalPlayer
    if not self.controls then
        local module=player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then local ok,controls=pcall(function() return require(module):GetControls() end); if ok then self.controls=controls end end
    end
    if open then
        self.overlay.CanvasPosition=Vector2.zero
        self.playerListWasEnabled=Core:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
        Core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
        if self.controls then self.controls:Disable() end
        local usingGamepad=isGamepad(UIS:GetLastInputType())
        if usingGamepad then self.device="console" end
        Gui.SelectedObject=(not mobile or usingGamepad) and self.tabs[self.device] or nil
    else
        if self.playerListWasEnabled~=nil then Core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,self.playerListWasEnabled) end
        if self.controls then self.controls:Enable() end
        Gui.SelectedObject=isGamepad(UIS:GetLastInputType()) and self.selectionOnClose and self.selectionOnClose() or nil
        self.settings:save()
    end
    self:layout()
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
