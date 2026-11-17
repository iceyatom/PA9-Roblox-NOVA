-- Lobby quest board. Rows are built from Quests.view; the server decides every claim.
local Players=game:GetService("Players")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local Text=game:GetService("TextService")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local Quests=require(shared.Quests)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local C=W.colors
local Menu={};Menu.__index=Menu
local tabs={{id="daily",name="Daily"},{id="weekly",name="Weekly"},{id="career",name="Career"}}
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function label(parent,name,value,size,color)
    local text=W.text(parent,name,0,0,0,0,value,size,color,Enum.Font.GothamBold)
    text.TextWrapped=true;text.TextTruncate=Enum.TextTruncate.None
    return text
end
local function rect(object,x,y,w,h) object.Position=UDim2.fromOffset(x,y);object.Size=UDim2.fromOffset(w,h) end
local function duration(seconds)
    seconds=math.max(0,seconds)
    local days,hours,minutes=math.floor(seconds/86400),math.floor(seconds%86400/3600),math.floor(seconds%3600/60)
    if days>0 then return ("%dd %dh"):format(days,hours) end
    if hours>0 then return ("%dh %dm"):format(hours,minutes) end
    return ("%dm %ds"):format(minutes,seconds%60)
end
local function rewardText(row)
    return ("%s XP"):format(Quests.commas(row.xp))..(row.item and "\n+ Item: Coming soon"
        or row.finalItem and ("\nTier %d item: Coming soon"):format(row.tiers) or "")
end
function Menu.new(playerGui,clear,beforeOpen,getProfile)
    local self=setmetatable({available=true,opened=false,clear=clear,beforeOpen=beforeOpen,getProfile=getProfile,tab=1,message=""},Menu)
    local gui=Instance.new("ScreenGui");gui.Name="NOVAQuests";gui.ResetOnSpawn=false;gui.DisplayOrder=5
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui;self.gui=gui
    self.launcher=W.button(gui,"QuestsButton",16,416,220,72,"Quests",false)
    self.launcher.BackgroundColor3=C.panel;self.launcher.Font=Enum.Font.GothamBlack;self.launcher.TextSize=26
    Style.surface(self.launcher,10)
    self.launcherScale=Instance.new("UIScale");self.launcherScale.Parent=self.launcher
    -- Count of rewards waiting to be claimed.
    self.badge=W.text(self.launcher,"Ready",178,20,32,32,"",18,C.ink,Enum.Font.GothamBlack)
    self.badge.BackgroundTransparency=0;self.badge.BackgroundColor3=C.mint;self.badge.TextXAlignment=Enum.TextXAlignment.Center
    self.badge.ZIndex=6;self.badge.Visible=false;W.round(self.badge)
    local overlay=Instance.new("ScrollingFrame");overlay.Name="QuestsOverlay";overlay.Size=UDim2.fromScale(1,1)
    overlay.ZIndex=20;overlay.BackgroundColor3=C.ink;overlay.BackgroundTransparency=.08;overlay.BorderSizePixel=0
    overlay.ScrollBarThickness=4;overlay.ScrollBarImageColor3=C.purple;overlay.ScrollingDirection=Enum.ScrollingDirection.Y
    overlay.Active=true;overlay.Visible=false;overlay.Parent=gui;self.overlay=overlay
    self.panel=W.box(overlay,"Panel",0,0,1080,700,C.panel);self.panel.Active=true;Style.surface(self.panel,12)
    self.title=label(self.panel,"Title","Quests",36,C.white);self.title.Font=Enum.Font.GothamBlack
    self.close=Style.button(self.panel,"Close",0,0,56,44,"×",false);self.close.TextSize=28
    self.summary=label(self.panel,"Summary","",20,C.mint)
    self.tabs={}
    for i,tab in tabs do
        local button=Style.button(self.panel,"Tab"..i,0,0,0,48,tab.name,false);button.TextSize=22
        button.Activated:Connect(function() self.tab=i;self.message="";self:refresh() end);self.tabs[i]=button
    end
    self.reset=label(self.panel,"Reset","",18,C.muted)
    self.list=W.box(self.panel,"List",24,200,1032,300)
    self.note=label(self.panel,"Note","",18,C.muted)
    self.launcher.Activated:Connect(function() self:setOpen(not self.opened) end)
    self.close.Activated:Connect(function() self:setOpen(false) end)
    Gui.MenuOpened:Connect(function() self:setOpen(false) end)
    Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        if self.opened and Gui.SelectedObject and not Gui.SelectedObject:IsDescendantOf(self.overlay) then Gui.SelectedObject=self.close end
    end)
    CAS:BindActionAtPriority("NOVA_QuestsClose",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self:setOpen(false) end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
    CAS:BindActionAtPriority("NOVA_QuestsTabs",function(_,state,input)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            self.tab=(self.tab-1+(input.KeyCode==Enum.KeyCode.ButtonL1 and -1 or 1))%#tabs+1
            self.message="";self:refresh();Gui.SelectedObject=self.tabs[self.tab]
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
    shared:WaitForChild("InventoryState").OnClientEvent:Connect(function(profile)
        if not self.latest or profile.version>=self.latest.version then self.latest=profile end;self:refresh()
    end)
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:refresh() end)
    -- Countdown text ticks every second; rows rebuild only when a reset passes.
    task.spawn(function()
        while gui.Parent do
            task.wait(1)
            local view=self:view()
            if view and (view.daily.period~=self.shownDaily or view.weekly.period~=self.shownWeekly) then self:refresh()
            elseif self.opened then self:countdown(view) end
        end
    end)
    self:refresh()
    return self
end
function Menu:profile()
    local profile=self.getProfile and self.getProfile()
    return profile and (not self.latest or profile.version>self.latest.version) and profile or self.latest or profile
end
function Menu:view()
    local profile=self:profile()
    local data=profile and profile.ready and profile.data
    return data and data.quests and Quests.view(data.quests,data.stats,os.time()) or nil
end
function Menu:countdown(view)
    local tab=tabs[self.tab].id
    self.reset.Text=not view and "" or tab=="career" and "Career quests never reset. Each one has five tiers with bigger rewards."
        or ("New %s quests in %s. Finished quests you have not claimed pay out automatically."):format(tab,duration(view[tab].resetAt-os.time()))
end
function Menu:claim(row)
    if self.busy or not row.complete or row.claimed then return end
    self.busy=true;self.message="Claiming…";self:refresh()
    task.spawn(function()
        local ok,response=pcall(function() return shared.InventoryRequest:InvokeServer("claimQuest",row.key) end)
        self.busy=false
        if ok and response.profile and (not self.latest or response.profile.version>=self.latest.version) then self.latest=response.profile end
        if ok and response.ok and response.quest then
            self.message=("Claimed +%s XP from %s.%s"):format(Quests.commas(response.quest.xp),response.quest.title,
                response.quest.item and " Its item reward is coming soon." or "")
        else self.message=ok and response.message or "Could not reach the server. Try again." end
        self:refresh()
        if gamepad() and self.opened then Gui.SelectedObject=self.firstRow or self.close end
    end)
end
function Menu:refresh()
    if not self.note then return end
    local view=self:view()
    self.launcherScale.Scale=math.min(1,math.max(.5,(self.gui.AbsoluteSize.X-32)/220))
    self.launcher.Position=self.gui.AbsoluteSize.Y<500 and UDim2.new(1,-236,1,-248) or UDim2.fromOffset(16,416)
    self.badge.Visible=view~=nil and view.ready>0
    self.badge.Text=view and tostring(math.min(view.ready,99)) or ""
    self.shownDaily=view and view.daily.period;self.shownWeekly=view and view.weekly.period
    if not self.opened then return end
    local profile=self:profile()
    local width=math.min(1080,math.max(300,self.overlay.AbsoluteSize.X-24));local inner=width-48
    local narrow=width<700
    rect(self.title,24,20,width-110,48);self.title.TextSize=width<500 and 30 or 36
    rect(self.close,width-80,22,56,44)
    self.summary.Text=not view and (profile and profile.status or "Loading quests…")
        or view.ready>0 and ("%d reward%s ready to claim. Click a finished quest to claim it."):format(view.ready,view.ready==1 and "" or "s")
        or "Finish quests to earn XP. Click a finished quest to claim it."
    if view and view.autoXP>0 then
        self.summary.Text=("+%s XP was claimed for you from quests that reset.  %s"):format(Quests.commas(view.autoXP),self.summary.Text)
    end
    local summaryHeight=math.max(32,Text:GetTextSize(self.summary.Text,20,self.summary.Font,Vector2.new(inner,10000)).Y+8)
    rect(self.summary,24,80,inner,summaryHeight)
    local tabY=92+summaryHeight
    local tabWidth=(inner-24)/3
    for i,tab in self.tabs do
        local rows=view and (view[tabs[i].id].list or view[tabs[i].id]) or {}
        local ready=0
        for _,row in rows do if row.complete and not row.claimed then ready+=1 end end
        tab.Text=ready>0 and ("%s (%d)"):format(tabs[i].name,ready) or tabs[i].name
        tab.TextSize=narrow and 18 or 22
        rect(tab,24+(i-1)*(tabWidth+12),tabY,tabWidth,48);tab.BackgroundColor3=self.tab==i and C.purple or C.line
    end
    self:countdown(view)
    local resetHeight=math.max(28,Text:GetTextSize(self.reset.Text,18,self.reset.Font,Vector2.new(inner,10000)).Y+8)
    rect(self.reset,24,tabY+60,inner,resetHeight)
    local top=tabY+68+resetHeight
    for _,child in self.list:GetChildren() do child:Destroy() end
    self.firstRow=nil
    local id=tabs[self.tab].id
    local rows=view and (view[id].list or view[id]) or {}
    local rowHeight=narrow and 176 or 112
    if #rows==0 then
        local empty=label(self.list,"Empty",view and "No quests right now. Check back after the next reset." or "Loading quests…",22,C.muted)
        rect(empty,16,12,inner-32,80)
    end
    for i,row in rows do
        local claimable=row.complete and not row.claimed
        local card=W.button(self.list,"Quest"..i,0,(i-1)*(rowHeight+12),inner,rowHeight,"",false)
        card.BackgroundColor3=C.ink;card.AutoButtonColor=claimable;card.Active=claimable;card.Selectable=claimable
        card:SetAttribute("QuestKey",row.key);card:SetAttribute("Claimable",claimable)
        Style.round(card,10);W.stroke(card,claimable and C.mint or C.line,claimable and 2 or 1)
        if claimable then
            self.firstRow=self.firstRow or card
            card.Activated:Connect(function() self:claim(row) end)
        end
        local side=narrow and inner-32 or 230
        local main=narrow and inner-32 or inner-side-48
        local heading=row.kind=="career" and ("%s  ·  Tier %d / %d"):format(row.title,row.tier,row.tiers) or row.title
        local title=label(card,"Title",heading,narrow and 22 or 24,row.claimed and C.muted or C.white);rect(title,16,10,main,30)
        title.TextWrapped=false;title.TextTruncate=Enum.TextTruncate.AtEnd
        local detail=label(card,"Detail",row.text,18,C.muted);rect(detail,16,42,main,24)
        local track=W.box(card,"Track",16,76,main-110,12,C.line);Style.round(track,6);track.ZIndex=6
        local fill=W.box(track,"Fill",0,0,0,12,row.complete and C.mint or C.purple);Style.round(fill,6);fill.ZIndex=7
        fill.Size=UDim2.new(math.clamp(row.progress/row.goal,0,1),0,1,0);fill.Visible=row.progress>0
        local amount=label(card,"Progress",("%s / %s"):format(Quests.commas(row.progress),Quests.commas(row.goal)),18,row.complete and C.mint or C.white)
        rect(amount,main-84,68,100,28);amount.TextXAlignment=Enum.TextXAlignment.Right
        local sideX,sideY=narrow and 16 or inner-side-16,narrow and 104 or 10
        local reward=label(card,"Reward",rewardText(row),(row.item or row.finalItem) and 18 or 22,row.claimed and C.muted or C.mint)
        rect(reward,sideX,sideY,narrow and main-150 or side,narrow and 60 or 48)
        reward.TextXAlignment=narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
        local state=label(card,"State",row.claimed and (row.kind=="career" and "ALL TIERS CLAIMED" or "CLAIMED")
            or claimable and (self.busy and "CLAIMING…" or "CLAIM REWARD") or "IN PROGRESS",16,claimable and C.white or C.muted)
        state.TextXAlignment=Enum.TextXAlignment.Center;state.TextWrapped=false
        state.BackgroundTransparency=0;state.BackgroundColor3=claimable and C.purple or C.panel;Style.round(state,8)
        if narrow then rect(state,inner-16-140,116,140,40) else rect(state,inner-16-190,62,190,38) end
    end
    local height=math.max(110,#rows*(rowHeight+12));rect(self.list,24,top,inner,height)
    self.note.Text=self.message~="" and self.message
        or "Duels count when they finish. Practice does not count. Quest XP is not doubled by Double XP tokens."
    self.note.TextColor3=self.message~="" and C.white or C.muted
    local noteHeight=math.max(52,Text:GetTextSize(self.note.Text,18,self.note.Font,Vector2.new(inner,10000)).Y+8)
    rect(self.note,24,top+height+12,inner,noteHeight)
    local panelHeight=top+height+noteHeight+44
    rect(self.panel,math.max(12,(self.overlay.AbsoluteSize.X-width)/2),math.max(12,(self.overlay.AbsoluteSize.Y-panelHeight)/2),width,panelHeight)
    self.overlay.CanvasSize=UDim2.fromOffset(0,panelHeight+24)
end
function Menu:setAvailable(available)
    self.available=available;self.gui.Enabled=available;if not available then self:setOpen(false) end
end
function Menu:setOpen(open)
    if open and (not self.available or Gui.MenuIsOpen) or self.opened==open then return end
    if open and self.beforeOpen then self.beforeOpen() end
    if self.clear then self.clear() end
    self.opened=open;self.overlay.Visible=open;self.gui:SetAttribute("MenuOpen",open)
    if not self.controls then
        local module=player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then local ok,value=pcall(function() return require(module):GetControls() end);if ok then self.controls=value end end
    end
    local core=game:GetService("StarterGui")
    if open then
        self.overlay.CanvasPosition=Vector2.zero;self.message=""
        -- Open on the first tab that has something to claim.
        local view=self:view()
        for i,tab in tabs do
            local ready=false
            for _,row in view and (view[tab.id].list or view[tab.id]) or {} do ready=ready or row.complete and not row.claimed end
            if ready then self.tab=i;break end
        end
        self.playerListWasEnabled=core:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList);core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
        if self.controls then self.controls:Disable() end
        CAS:BindActionAtPriority("NOVA_QuestsMovement",function() return Enum.ContextActionResult.Sink end,false,
            Enum.ContextActionPriority.High.Value+35,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D)
        Run:BindToRenderStep("NOVA_QuestsMovement",Enum.RenderPriority.Last.Value+1,function()
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid:Move(Vector3.zero,false);humanoid.Jump=false end
        end)
        task.spawn(function()
            task.wait(.2)
            local ok,response=pcall(function() return shared.InventoryRequest:InvokeServer("read") end)
            if ok and response.profile and (not self.latest or response.profile.version>=self.latest.version) then self.latest=response.profile;self:refresh() end
        end)
    else
        CAS:UnbindAction("NOVA_QuestsMovement");Run:UnbindFromRenderStep("NOVA_QuestsMovement")
        if self.controls then self.controls:Enable() end
        if self.playerListWasEnabled~=nil then core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,self.playerListWasEnabled) end
        -- The automatic-claim notice has been seen once; clear it for next time.
        local view=self:view()
        if view and view.autoXP>0 then
            task.spawn(function() pcall(function() shared.InventoryRequest:InvokeServer("ackQuests","auto") end) end)
        end
    end
    self:refresh();Gui.SelectedObject=gamepad() and (open and (self.firstRow or self.close) or self.available and self.launcher) or nil
end
return Menu
