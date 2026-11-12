local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Text=game:GetService("TextService")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local Daily=require(shared.DailyRewards)
local Shop=require(shared.ShopCatalog)
local Catalog=require(shared.InventoryCatalog)
local Preview=require(script.Parent.InventoryPreview)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Reveal=require(script.Parent.ShopReveal)
local C=W.colors
local Menu={};Menu.__index=Menu
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function wrapped(parent,name,x,y,w,h,text,size,color)
    local label=W.text(parent,name,x,y,w,h,text,size,color,Enum.Font.Gotham)
    label.TextWrapped=true;label.TextTruncate=Enum.TextTruncate.None
    return label
end
function Menu.new(playerGui,clear,beforeOpen,profile)
    local self=setmetatable({available=true,opened=false,clear=clear,beforeOpen=beforeOpen,getProfile=profile,page=1,cards={}},Menu)
    self.remote=shared:WaitForChild("InventoryRequest")
    local gui=Instance.new("ScreenGui");gui.Name="NOVADailyRewards";gui.ResetOnSpawn=false;gui.DisplayOrder=9
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui;self.gui=gui
    self.launcher=Style.button(gui,"DailyButton",16,296,220,64,"Daily check-in",true)
    self.launcher.TextSize=24
    self.launcherScale=Instance.new("UIScale");self.launcherScale.Parent=self.launcher
    local overlay=Instance.new("ScrollingFrame");overlay.Name="DailyOverlay";overlay.ZIndex=20
    overlay.Size=UDim2.fromScale(1,1);overlay.BackgroundColor3=C.ink;overlay.BackgroundTransparency=.08
    overlay.BorderSizePixel=0;overlay.ScrollBarThickness=4;overlay.ScrollBarImageColor3=C.purple
    overlay.CanvasSize=UDim2.fromOffset(0,0);overlay.ScrollingDirection=Enum.ScrollingDirection.Y
    overlay.Active=true;overlay.Visible=false;overlay.Parent=gui;self.overlay=overlay
    self.panel=W.box(overlay,"Panel",0,0,1040,580,C.panel);self.panel.Active=true;Style.surface(self.panel,12)
    self.title=W.text(self.panel,"Title",24,20,850,48,"Daily check-in",36,C.white,Enum.Font.GothamBlack)
    self.close=Style.button(self.panel,"Close",950,22,56,40,"×",false);self.close.TextSize=26
    self.streak=wrapped(self.panel,"Streak",24,68,990,36,"",24,C.mint);self.streak.Font=Enum.Font.GothamBold
    self.rules=wrapped(self.panel,"Rules",24,108,990,56,"Check in once per UTC day. Miss a full UTC day and your streak resets to day 1.",20,C.white)
    self.tabs={}
    for i,label in {"Week 1","Week 2","Week 3","Week 4","Day 29+"} do
        local tab=Style.button(self.panel,"Week"..i,0,168,180,40,label,false)
        tab.Activated:Connect(function() self.page=i;self:refresh() end);self.tabs[i]=tab
    end
    self.forecast=wrapped(self.panel,"Forecast",24,224,990,32,"",22,C.white);self.forecast.Font=Enum.Font.GothamBold
    self.grid=W.box(self.panel,"Rewards",24,266,990,180)
    self.note=wrapped(self.panel,"Note",24,458,990,56,"",20,C.white)
    self.claim=Style.button(self.panel,"Claim",24,516,420,56,"Claim reward",true);self.claim.TextSize=25
    self.status=wrapped(self.panel,"Status",460,516,550,48,"",18,C.muted)
    -- Keep the celebration outside the scrolling forecast, including on phones.
    self.revealLayer=W.box(gui,"DailyCelebration",0,0,0,0,C.ink,40)
    self.revealLayer.Size=UDim2.fromScale(1,1);self.revealLayer.BackgroundTransparency=.08
    self.revealLayer.Active=true;self.revealLayer.Visible=false
    self.revealPanel=W.box(self.revealLayer,"Panel",0,0,900,650,C.ink)
    self.revealPanel.AnchorPoint=Vector2.new(.5,.5);self.revealPanel.Position=UDim2.fromScale(.5,.5)
    self.revealPanel.ClipsDescendants=true;Style.surface(self.revealPanel,12)
    self.reveal=Reveal.new(self.revealPanel,function() self:hideReveal() end)
    self.launcher.Activated:Connect(function() self:setOpen(not self.opened) end)
    self.close.Activated:Connect(function() self:setOpen(false) end)
    self.claim.Activated:Connect(function() self:checkIn() end)
    Gui.MenuOpened:Connect(function() self:setOpen(false) end)
    Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        if not self.opened or not Gui.SelectedObject then return end
        if self.reveal.active then
            if not Gui.SelectedObject:IsDescendantOf(self.revealPanel) then
                local done=self.reveal.overlay and self.reveal.overlay:FindFirstChild("Continue")
                Gui.SelectedObject=done and done.Visible and done or nil
            end
        elseif not Gui.SelectedObject:IsDescendantOf(self.overlay) then Gui.SelectedObject=self.close end
    end)
    CAS:BindActionAtPriority("NOVA_DailyClose",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            if self.reveal.active then self:hideReveal() else self:setOpen(false) end
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
    CAS:BindActionAtPriority("NOVA_DailyTabs",function(_,state,input)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin and not self.reveal.active then
            self.page=(self.page-1+(input.KeyCode==Enum.KeyCode.ButtonR1 and 1 or -1))%5+1
            self:refresh();Gui.SelectedObject=self.tabs[self.page]
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
    shared:WaitForChild("InventoryState").OnClientEvent:Connect(function(value) self:accept(value) end)
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if self.reveal.active then self:hideReveal() else self:refresh() end
    end)
    local elapsed=0
    local connection=Run.Heartbeat:Connect(function(dt)
        elapsed+=dt;if elapsed<1 then return end;elapsed=0
        self:refresh()
        local p=self:profile()
        if not self.autoShown and self.available and p and p.ready and p.data
            and (not self.canAutoOpen or self.canAutoOpen()) then
            self.autoShown=true
            if Daily.status(p.data,workspace:GetServerTimeNow()).claimable then self:setOpen(true) end
        end
    end)
    gui.Destroying:Once(function() connection:Disconnect();self.reveal:hide() end)
    self:refresh()
    return self
end
function Menu:profile()
    local value=self.getProfile and self.getProfile()
    if value and (not self.latest or value.version>self.latest.version) then return value end
    return self.latest or value
end
function Menu:accept(profile)
    if profile and (not self.latest or profile.version>=self.latest.version) then self.latest=profile end
    self:refresh()
end
function Menu:refresh()
    if not self.status then return end
    local profile=self:profile();local data=profile and profile.data
    local state=data and Daily.status(data,workspace:GetServerTimeNow())
    local ready=profile and profile.ready and state
    self.launcher.Text=ready and state.claimable and "Reward ready!" or "Daily check-in"
    self.launcherScale.Scale=math.min(1,math.max(.5,(self.gui.AbsoluteSize.X-32)/220))
    self.launcher.Position=self.gui.AbsoluteSize.Y<380 and UDim2.new(1,-236,1,-80) or UDim2.fromOffset(16,296)
    if not self.opened or self.reveal.active then return end
    local width=math.min(1240,math.max(300,self.overlay.AbsoluteSize.X-24))
    local columns=width>=1180 and 7 or width>=680 and 4 or width>=480 and 3 or width>=350 and 2 or 1
    local days={}
    if self.page<5 then for day=(self.page-1)*7+1,self.page*7 do table.insert(days,day) end
    elseif state and state.day>30 then
        local start=31+math.floor((state.day-31)/7)*7
        for day=start,start+6 do table.insert(days,day) end
    else days={29,30,31} end
    local rows=math.ceil(#days/columns);local gridHeight=rows*244-12
    self.title.Size=UDim2.fromOffset(width-110,48);self.title.TextSize=width<500 and 30 or 36
    self.close.Position=UDim2.fromOffset(width-80,22)
    self.streak.TextSize=width<500 and 22 or 24
    local tabColumns=width<600 and 3 or 5
    local tabWidth=(width-48-(tabColumns-1)*8)/tabColumns
    local function layout(label,top,minimum)
        local height=math.max(minimum,Text:GetTextSize(label.Text,label.TextSize,label.Font,Vector2.new(width-48,10000)).Y+8)
        label.Position=UDim2.fromOffset(24,top);label.Size=UDim2.fromOffset(width-48,height)
        return top+height
    end
    local claimed=data and data.daily.day or 0
    self.streak.Text=not state and "Loading your streak…" or state.reset and "Streak reset · Start again at day 1"
        or ("%d consecutive day%s · %s"):format(claimed,claimed==1 and "" or "s",claimed>=30 and "10 crates every day" or "30-day rewards")
    local tabsTop=layout(self.rules,layout(self.streak,78,36)+12,52)+20
    for i,tab in self.tabs do
        tab.Position=UDim2.fromOffset(24+(i-1)%tabColumns*(tabWidth+8),tabsTop+math.floor((i-1)/tabColumns)*56);tab.Size=UDim2.fromOffset(tabWidth,48)
        tab.TextSize=20;tab.BackgroundColor3=i==self.page and C.purple or C.line
    end
    self.forecast.Text=self.page<5 and ("WEEK %d  /  DAYS %d–%d"):format(self.page,days[1],days[#days]) or "DAY 30 & BEYOND  /  KEEP YOUR STREAK"
    local gridTop=layout(self.forecast,tabsTop+math.ceil(5/tabColumns)*56+12,32)+16
    self.grid.Position=UDim2.fromOffset(24,gridTop)
    self.grid.Size=UDim2.fromOffset(width-48,gridHeight)
    -- Keep existing cards between timer ticks so controller focus is stable.
    local key=table.concat(days,",")..":"..width
    if self.cardKey~=key then
        self.cardKey=key;for _,card in self.cards do card.root:Destroy() end;self.cards={}
        local cell=(width-48-(columns-1)*12)/columns
        for i,day in days do
            local reward=Daily.reward(day)
            local root=W.box(self.grid,"Day"..day,(i-1)%columns*(cell+12),math.floor((i-1)/columns)*244,cell,232,C.ink);Style.surface(root,10)
            local label=W.text(root,"Day",10,12,cell-20,30,"DAY "..day,22,C.white,Enum.Font.GothamBold)
            label.TextXAlignment=Enum.TextXAlignment.Center
            Preview.icon(root,reward.id and Catalog.byId[reward.id] or "skins",(cell-64)/2,50,64)
            local title=wrapped(root,"Reward",10,120,cell-20,68,Daily.title(reward),22,C.white);title.Font=Enum.Font.GothamBold;title.TextXAlignment=Enum.TextXAlignment.Center
            local status=wrapped(root,"State",8,190,cell-16,36,"",16,C.muted);status.Font=Enum.Font.GothamBold;status.TextXAlignment=Enum.TextXAlignment.Center
            table.insert(self.cards,{root=root,status=status,day=day})
        end
    end
    for _,card in self.cards do
        local earned=state and not state.reset and card.day<=claimed
        local current=state and card.day==state.day
        card.root:FindFirstChildOfClass("UIStroke").Color=earned and C.mint or current and C.purple or C.line
        card.status.Text=earned and "CLAIMED" or current and state.claimable and "READY TO CLAIM" or card.day==30 and "COMING SOON" or "UPCOMING"
        card.status.TextColor3=earned and C.mint or current and C.white or C.muted
    end
    self.note.Text=data and data.daily.packEarned and (data.daily.packDelivered and "Your day 30 skin pack has been delivered."
        or "Your day 30 skin pack is reserved. It will be delivered when the pack releases.")
        or "Day 30 reserves the coming skin pack. Day 31 onward gives 10 crates per day. Tokens stay in Class setup until activated."
    local claimTop=layout(self.note,gridTop+gridHeight+20,56)+16
    self.claim.Position=UDim2.fromOffset(24,claimTop);self.claim.Size=UDim2.fromOffset(width-48,56)
    self.claim.TextSize=width<500 and 23 or 25
    local active=ready and state.claimable and not self.pending
    self.claim.Active=active==true;self.claim.Selectable=active==true;self.claim.AutoButtonColor=active==true
    self.claim.BackgroundColor3=active and C.purple or C.line
    self.claim.Text=self.pending and "Saving check-in…" or active and ("Claim day %d reward"):format(state.day)
        or state and not state.claimable and "Checked in today" or "Loading check-in…"
    self.status.Text=self.message or not ready and (profile and profile.status or "Loading inventory…")
        or state.claimable and "Check in before 00:00 UTC to keep your streak."
        or "Next reward in "..Shop.clock(state.unlockAt-workspace:GetServerTimeNow()).." · Resets at 00:00 UTC"
    local height=layout(self.status,claimTop+68,36)+20
    self.panel.Position=UDim2.fromOffset(math.max(12,(self.overlay.AbsoluteSize.X-width)/2),math.max(12,(self.overlay.AbsoluteSize.Y-height)/2))
    self.panel.Size=UDim2.fromOffset(width,height)
    self.overlay.CanvasSize=UDim2.fromOffset(0,height+24)
end
function Menu:hideReveal()
    self.reveal:hide();self.revealLayer.Visible=false
    self:refresh()
    if self.opened and gamepad() then Gui.SelectedObject=self.close end
end
function Menu:showReward(reward,data)
    if not self.opened or not self.available then return end
    local screen=self.gui.AbsoluteSize
    self.revealPanel.Size=UDim2.fromOffset(math.min(900,math.max(300,screen.X-24)),screen.Y<560 and math.max(300,screen.Y-24) or 650)
    self.revealLayer.Visible=true
    self.reveal:showDaily(reward,data)
end
function Menu:checkIn()
    if self.pending or self.reveal.active then return end
    local profile=self:profile()
    if not profile or not profile.ready or not profile.data then return end
    local state=Daily.status(profile.data,workspace:GetServerTimeNow())
    if not state.claimable then return end
    self.pending=true;self.message=nil;self:refresh()
    task.spawn(function()
        local ok,result=pcall(function() return self.remote:InvokeServer("checkIn","daily:"..(state.sequence+1)) end)
        self.pending=false
        if ok and result then
            self.message=result.ok and (result.dailyReward.kind=="pack" and (result.profile.data.daily.packDelivered
                and "Day 30 complete! Your exclusive skin pack has been delivered." or "Day 30 complete! Your exclusive skin pack is reserved.")
                or "Reward saved to your inventory.") or result.message
            self:accept(result.profile)
            if result.ok and result.dailyReward then self:showReward(result.dailyReward,result.profile.data) end
        else self.message="Could not confirm the check-in. Reopen to check your saved progress.";self:refresh() end
        if self.opened and not self.reveal.active and gamepad() then Gui.SelectedObject=self.close end
    end)
end
function Menu:setAvailable(available)
    self.available=available;self.gui.Enabled=available
    if not available then self:setOpen(false) end
end
function Menu:setOpen(open)
    if open and (not self.available or Gui.MenuIsOpen) then return end
    if self.opened==open then return end
    if open and self.beforeOpen then self.beforeOpen() end
    if self.clear then self.clear() end
    self.opened=open;self.overlay.Visible=open;self.gui:SetAttribute("MenuOpen",open)
    if not self.controls then
        local module=player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then local ok,value=pcall(function() return require(module):GetControls() end);if ok then self.controls=value end end
    end
    local core=game:GetService("StarterGui")
    if open then
        self.message=nil
        local profile=self:profile();local state=profile and profile.data and Daily.status(profile.data,workspace:GetServerTimeNow())
        self.page=state and math.min(5,math.ceil(state.day/7)) or 1
        self.playerListWasEnabled=core:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList);core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
        if self.controls then self.controls:Disable() end
        CAS:BindActionAtPriority("NOVA_DailyMovement",function() return Enum.ContextActionResult.Sink end,false,
            Enum.ContextActionPriority.High.Value+35,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D)
        Run:BindToRenderStep("NOVA_DailyMovement",Enum.RenderPriority.Last.Value+1,function()
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:Move(Vector3.zero,false);humanoid.Jump=false end
        end)
        task.spawn(function()
            task.wait(.2)
            local ok,result=pcall(function() return self.remote:InvokeServer("read") end)
            if ok and result then self:accept(result.profile) end
        end)
    else
        self.reveal:hide();self.revealLayer.Visible=false
        CAS:UnbindAction("NOVA_DailyMovement");Run:UnbindFromRenderStep("NOVA_DailyMovement")
        if self.controls then self.controls:Enable() end
        if self.playerListWasEnabled~=nil then core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,self.playerListWasEnabled) end
    end
    self.launcherScale.Scale=math.min(1,math.max(.5,(self.gui.AbsoluteSize.X-32)/220))
    self:refresh()
    Gui.SelectedObject=gamepad() and (open and (self.claim.Selectable and self.claim or self.close) or self.available and self.launcher) or nil
end
return Menu
