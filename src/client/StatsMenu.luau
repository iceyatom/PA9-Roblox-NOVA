local Players=game:GetService("Players")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local Text=game:GetService("TextService")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local Stats=require(shared.Stats)
local Shop=require(shared.ShopCatalog)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local C=W.colors
local Menu={};Menu.__index=Menu
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function label(parent,name,value,size,color)
    local text=W.text(parent,name,0,0,0,0,value,size,color,Enum.Font.GothamBold)
    text.TextWrapped=true;text.TextTruncate=Enum.TextTruncate.None
    return text
end
local function rect(object,x,y,w,h) object.Position=UDim2.fromOffset(x,y);object.Size=UDim2.fromOffset(w,h) end
function Menu.new(playerGui,clear,beforeOpen,getProfile)
    local self=setmetatable({available=true,opened=false,clear=clear,beforeOpen=beforeOpen,getProfile=getProfile,cards={}},Menu)
    local gui=Instance.new("ScreenGui");gui.Name="NOVAStats";gui.ResetOnSpawn=false;gui.DisplayOrder=5
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui;self.gui=gui
    self.launcher=W.button(gui,"StatsButton",16,336,220,72,"Career stats",false)
    self.launcher.BackgroundColor3=C.panel;self.launcher.Font=Enum.Font.GothamBlack;self.launcher.TextSize=26
    Style.surface(self.launcher,10)
    self.launcherScale=Instance.new("UIScale");self.launcherScale.Parent=self.launcher
    local overlay=Instance.new("ScrollingFrame");overlay.Name="StatsOverlay";overlay.Size=UDim2.fromScale(1,1)
    overlay.ZIndex=20;overlay.BackgroundColor3=C.ink;overlay.BackgroundTransparency=.08;overlay.BorderSizePixel=0
    overlay.ScrollBarThickness=4;overlay.ScrollBarImageColor3=C.purple;overlay.ScrollingDirection=Enum.ScrollingDirection.Y
    overlay.Active=true;overlay.Visible=false;overlay.Parent=gui;self.overlay=overlay
    self.panel=W.box(overlay,"Panel",0,0,1080,700,C.panel);self.panel.Active=true;Style.surface(self.panel,12)
    self.title=label(self.panel,"Title","Career stats",36,C.white);self.title.Font=Enum.Font.GothamBlack
    self.close=Style.button(self.panel,"Close",0,0,56,44,"×",false);self.close.TextSize=28
    self.summary=label(self.panel,"Summary","",20,C.mint)
    self.tabs={}
    for i,name in {"Overview","By map"} do
        local button=Style.button(self.panel,"Tab"..i,0,0,0,48,name,false);button.TextSize=22
        button.Activated:Connect(function() self.byMap=i==2;self:refresh() end);self.tabs[i]=button
    end
    self.content=W.box(self.panel,"Content",24,200,1032,320)
    for _,entry in {{"matchesPlayed","Matches played"},{"wins","Wins"},{"losses","Losses"},{"ratio","Win / loss ratio"},
        {"longestWinStreak","Longest win streak"},{"currentWinStreak","Current win streak"},{"shotsFired","Duel shots fired"},{"cratesOpened","Crates opened"}} do
        local root=W.box(self.content,entry[1],0,0,200,118,C.ink);Style.surface(root,10)
        local heading=label(root,"Label",entry[2],20,C.muted)
        local value=label(root,"Value","—",34,C.white);value.Font=Enum.Font.GothamBlack
        table.insert(self.cards,{root=root,heading=heading,value=value,id=entry[1]})
    end
    self.best=W.box(self.panel,"BestMap",24,200,1032,96,C.ink);Style.surface(self.best,10)
    self.bestTitle=label(self.best,"Label","BEST MAP",18,C.mint)
    self.bestName=label(self.best,"Value","No wins yet",28,C.white)
    self.bestDetail=label(self.best,"Detail","",18,C.muted)
    self.mapList=W.box(self.content,"MapList",0,0,1032,300)
    self.note=label(self.panel,"Note","",18,C.muted)
    self.launcher.Activated:Connect(function() self:setOpen(not self.opened) end)
    self.close.Activated:Connect(function() self:setOpen(false) end)
    Gui.MenuOpened:Connect(function() self:setOpen(false) end)
    Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        if self.opened and Gui.SelectedObject and not Gui.SelectedObject:IsDescendantOf(self.overlay) then Gui.SelectedObject=self.close end
    end)
    CAS:BindActionAtPriority("NOVA_StatsClose",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self:setOpen(false) end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
    CAS:BindActionAtPriority("NOVA_StatsTabs",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self.byMap=not self.byMap;self:refresh();Gui.SelectedObject=self.tabs[self.byMap and 2 or 1] end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
    shared:WaitForChild("InventoryState").OnClientEvent:Connect(function(profile)
        if not self.latest or profile.version>=self.latest.version then self.latest=profile end;self:refresh()
    end)
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:refresh() end)
    self:refresh()
    return self
end
function Menu:profile()
    local profile=self.getProfile and self.getProfile()
    return profile and (not self.latest or profile.version>self.latest.version) and profile or self.latest or profile
end
function Menu:refresh()
    if not self.note then return end
    self.launcherScale.Scale=math.min(1,math.max(.5,(self.gui.AbsoluteSize.X-32)/220))
    self.launcher.Position=self.gui.AbsoluteSize.Y<420 and UDim2.new(1,-236,1,-168) or UDim2.fromOffset(16,336)
    if not self.opened then return end
    local profile=self:profile();local data=profile and profile.data and profile.data.stats
    local ready=profile and profile.ready and data
    local width=math.min(1080,math.max(300,self.overlay.AbsoluteSize.X-24));local inner=width-48
    local columns=width>=920 and 4 or width>=650 and 3 or 2
    rect(self.title,24,20,width-110,48);self.title.TextSize=width<500 and 30 or 36
    rect(self.close,width-80,22,56,44)
    self.summary.Text=ready and ("%s wins  ·  %s losses  ·  %s draws"):format(Shop.commas(data.wins),Shop.commas(data.losses),Shop.commas(data.draws))
        or profile and profile.status or "Loading career stats…"
    local summaryHeight=math.max(32,Text:GetTextSize(self.summary.Text,20,self.summary.Font,Vector2.new(inner,10000)).Y+8)
    rect(self.summary,24,80,inner,summaryHeight)
    local tabY=92+summaryHeight
    for i,tab in self.tabs do rect(tab,24+(i-1)*(inner+12)/2,tabY,(inner-12)/2,48);tab.BackgroundColor3=(self.byMap and i==2 or not self.byMap and i==1) and C.purple or C.line end
    local top=tabY+68;local height
    self.best.Visible=not self.byMap;self.mapList.Visible=self.byMap==true
    for _,card in self.cards do card.root.Visible=not self.byMap end
    if not self.byMap then
        local best=data and Stats.bestMap(data)
        self.bestName.Text=best and best.name or ready and "No wins yet" or "Loading…"
        self.bestDetail.Text=best and ("%s wins / %s played  ·  %d%% win rate"):format(Shop.commas(best.wins),Shop.commas(best.matches),math.floor(best.wins/best.matches*100+.5))
            or "Most wins; win rate breaks ties."
        local nameHeight=math.max(36,Text:GetTextSize(self.bestName.Text,28,self.bestName.Font,Vector2.new(inner-32,10000)).Y+4)
        local detailHeight=math.max(28,Text:GetTextSize(self.bestDetail.Text,18,self.bestDetail.Font,Vector2.new(inner-32,10000)).Y+4)
        local bestHeight=48+nameHeight+detailHeight
        rect(self.best,24,top,inner,bestHeight);rect(self.bestTitle,16,10,inner-32,26)
        rect(self.bestName,16,38,inner-32,nameHeight);rect(self.bestDetail,16,38+nameHeight,inner-32,detailHeight)
        top+=bestHeight+16
        local cell=(inner-(columns-1)*12)/columns
        for i,card in self.cards do
            rect(card.root,(i-1)%columns*(cell+12),math.floor((i-1)/columns)*136,cell,124)
            rect(card.heading,14,8,cell-28,50);rect(card.value,14,64,cell-28,44)
            card.heading.TextSize=width<500 and 18 or 20
            card.value.Text=not ready and "—" or card.id=="ratio" and Stats.ratio(data) or Shop.commas(data[card.id])
        end
        height=math.ceil(#self.cards/columns)*136
    else
        for _,child in self.mapList:GetChildren() do child:Destroy() end
        local rows={}
        for id,row in data and data.maps or {} do table.insert(rows,{id=id,data=row}) end
        table.sort(rows,function(a,b) return a.data.wins==b.data.wins and a.id<b.id or a.data.wins>b.data.wins end)
        local rowHeight=width<600 and 110 or 76
        if #rows==0 then
            local empty=label(self.mapList,"Empty",ready and "Finish a duel to start your map stats." or "Loading map stats…",22,C.muted)
            rect(empty,16,12,inner-32,80)
        end
        for i,entry in rows do
            local row=W.box(self.mapList,"Map"..i,0,(i-1)*(rowHeight+12),inner,rowHeight,C.ink);Style.surface(row,10)
            local title=label(row,"Name",entry.data.name,24,C.white);rect(title,16,8,inner-32,34)
            local values=label(row,"Results",("%s played   ·   %s W / %s L / %s D"):format(Shop.commas(entry.data.matches),Shop.commas(entry.data.wins),Shop.commas(entry.data.losses),Shop.commas(entry.data.draws)),18,C.mint)
            rect(values,16,44,inner-32,rowHeight-48)
        end
        height=math.max(110,#rows*(rowHeight+12));rect(self.mapList,0,0,inner,height)
    end
    rect(self.content,24,top,inner,height)
    self.note.Text=ready and "Completed duels count once. Combat disconnects are forfeits; draws break a win streak. Shots count accepted duel shots at the end of each match. Practice is excluded."
        or "Career stats will appear when your saved profile is available."
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
        self.overlay.CanvasPosition=Vector2.zero
        self.playerListWasEnabled=core:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList);core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
        if self.controls then self.controls:Disable() end
        CAS:BindActionAtPriority("NOVA_StatsMovement",function() return Enum.ContextActionResult.Sink end,false,
            Enum.ContextActionPriority.High.Value+35,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D)
        Run:BindToRenderStep("NOVA_StatsMovement",Enum.RenderPriority.Last.Value+1,function()
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid:Move(Vector3.zero,false);humanoid.Jump=false end
        end)
        task.spawn(function()
            task.wait(.2)
            local ok,response=pcall(function() return shared.InventoryRequest:InvokeServer("read") end)
            if ok and response.profile and (not self.latest or response.profile.version>=self.latest.version) then self.latest=response.profile;self:refresh() end
        end)
    else
        CAS:UnbindAction("NOVA_StatsMovement");Run:UnbindFromRenderStep("NOVA_StatsMovement")
        if self.controls then self.controls:Enable() end
        if self.playerListWasEnabled~=nil then core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,self.playerListWasEnabled) end
    end
    self:refresh();Gui.SelectedObject=gamepad() and (open and self.close or self.available and self.launcher) or nil
end
return Menu
