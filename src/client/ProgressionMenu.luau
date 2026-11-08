local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local P=require(shared.Progression)
local Info=require(shared.ProgressionInfo)
local Catalog=require(shared.RankIcons)
local Art=require(shared.ProgressionArt)
local RankIcon=require(script.Parent.RankIcon)
local W=require(script.Parent.Widgets)
local C=W.colors
local Menu={}
Menu.__index=Menu
local bold=Enum.Font.GothamBold
local heavy=Enum.Font.GothamBlack

local function picture(parent,name,key,x,y,size)
    local image=RankIcon.new(parent,name,x,y,size)
    image.Image=Art[key]; image.Visible=true
    return image
end
local function wrapped(parent,name,x,y,w,h,value,size,color)
    local label=W.text(parent,name,x,y,w,h,value,size,color)
    label.TextWrapped=true
    label.TextTruncate=Enum.TextTruncate.None
    return label
end
local function rankData(index)
    return {prestige=math.min(index-1,10),master=index==12}
end
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end

function Menu.read()
    local level,prestige,master=player:GetAttribute("Level"),player:GetAttribute("Prestige"),player:GetAttribute("PrestigeMaster")
    if level==nil or prestige==nil or master==nil then return nil end
    return {level=level,prestige=prestige,master=master,xp=player:GetAttribute("XP") or 0,totalXP=player:GetAttribute("TotalXP") or 0}
end

function Menu.new(gui,launcher,clear,beforeOpen)
    local self=setmetatable({gui=gui,launcher=launcher,clear=clear,beforeOpen=beforeOpen,tab=1,selected=2},Menu)
    self.reveal=require(script.Parent.PrestigeReveal).new(gui,function()
        if self.opened then
            self.tab=1; self.selected=Info.next(Menu.read()) or 12; self:refresh()
            Gui.SelectedObject=gamepad() and self.tabs[1] or nil
        end
    end)
    local overlay=W.box(gui,"ProgressionOverlay",0,0,0,0,C.ink,20)
    overlay.Size=UDim2.fromScale(1,1); overlay.BackgroundTransparency=.16; overlay.Active=true; overlay.Visible=false
    self.overlay=overlay
    local origin=W.box(overlay,"Origin",0,0,0,0)
    origin.Position=UDim2.fromScale(.5,.5)
    local fit=Instance.new("UIScale"); fit.Parent=origin
    local function resize() fit.Scale=math.max(.01,math.min(1.3,(overlay.AbsoluteSize.X-48)/940,(overlay.AbsoluteSize.Y-48)/550)) end
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
    local panel=W.box(origin,"Panel",0,0,940,550,C.panel)
    panel.AnchorPoint=Vector2.new(.5,.5); panel.Active=true
    W.stroke(panel,C.line)
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,12); corner.Parent=panel
    self.pop=Instance.new("UIScale"); self.pop.Parent=panel
    picture(panel,"HeaderSprite","prestiges",20,12,62)
    W.text(panel,"Title",94,26,680,36,"Your progression",29,C.white,heavy)
    self.close=W.button(panel,"Close",854,24,62,40,"×",false)
    self.close.TextSize=26
    self.tabs={}; self.pages={}
    for i,spec in {{"Progress","progress"},{"Prestiges","prestiges"},{"Requirements","requirements"}} do
        local button=W.button(panel,"Tab"..i,24+(i-1)*304,100,284,46,"",false)
        picture(button,"Sprite",spec[2],16,5,36)
        W.text(button,"Label",64,0,204,46,spec[1],18,C.white,bold)
        self.tabs[i]=button
        local page=W.box(panel,spec[1],24,162,892,364)
        page.Visible=i==1; self.pages[i]=page
        button.Activated:Connect(function() self:setTab(i) end)
    end
    self:buildProgress(self.pages[1])
    self:buildCollection(self.pages[2])
    self:buildRequirements(self.pages[3])
    launcher.Activated:Connect(function() self:setOpen(not self.opened) end)
    self.close.Activated:Connect(function() self:setOpen(false) end)
    player.AttributeChanged:Connect(function() self:refresh() end)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function() if not gui.Enabled then self:setOpen(false) end end)
    Gui.MenuOpened:Connect(function() self:setOpen(false) end)
    CAS:BindActionAtPriority("NOVA_ProgressionBack",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            if self.reveal.active then self.reveal:hide(true) else self:setOpen(false) end
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+40,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
    CAS:BindActionAtPriority("NOVA_ProgressionTabs",function(_,state,input)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if self.reveal.active then return Enum.ContextActionResult.Sink end
        if state==Enum.UserInputState.Begin then
            self:setTab((self.tab-1+(input.KeyCode==Enum.KeyCode.ButtonR1 and 1 or -1))%3+1)
            Gui.SelectedObject=self.tabs[self.tab]
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+40,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
    CAS:BindActionAtPriority("NOVA_ProgressionOpen",function(_,state)
        if not gui.Enabled or UIS:GetFocusedTextBox() or Gui.MenuIsOpen then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self:setOpen(not self.opened) end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+40,Enum.KeyCode.ButtonY)
    self:refresh()
    return self
end

function Menu:buildProgress(page)
    local hero=W.box(page,"CurrentRank",0,0,264,364,C.ink)
    self.currentIcon=RankIcon.new(hero,"RankIcon",44,8,176)
    self.currentTitle=W.text(hero,"RankTitle",12,197,240,30,"",23,C.white,heavy)
    self.currentTitle.TextXAlignment=Enum.TextXAlignment.Center
    self.currentLevel=W.text(hero,"Level",12,233,240,28,"",18,C.muted)
    self.currentLevel.TextXAlignment=Enum.TextXAlignment.Center
    self.currentItem=W.text(hero,"Item",12,274,240,24,"",14,C.muted)
    self.currentItem.TextXAlignment=Enum.TextXAlignment.Center
    picture(hero,"Unlocked","unlocked",82,318,26)
    W.text(hero,"Current",114,320,128,24,"CURRENT RANK",11,C.mint)
    picture(page,"ProgressSprite","progress",284,0,52)
    W.text(page,"Heading",350,8,542,38,"Your progress",28,C.white,heavy)
    self.journey=wrapped(page,"Journey",284,64,608,42,"",17,C.muted)
    local track=W.box(page,"XPTrack",284,119,608,14,C.line)
    self.xpFill=W.box(track,"Fill",0,0,0,14,C.purple)
    self.xpText=W.text(page,"XP",284,143,608,24,"",15,C.muted)
    local function stat(name,x,title)
        local card=W.box(page,name,x,194,608,76,C.ink)
        W.text(card,"Label",16,9,576,20,title,12,C.muted)
        return W.text(card,"Value",16,32,576,32,"",24,C.white,bold)
    end
    self.lifetime=stat("LifetimeXP",284,"LIFETIME XP")
    self.nextRank=W.text(page,"NextRank",284,284,608,25,"",16,C.white,bold)
    self.viewRequirements=W.button(page,"ViewRequirements",284,320,608,40,"View prestige requirements",true)
    self.viewRequirements.Activated:Connect(function()
        self.selected=Info.next(Menu.read()) or 12; self:setTab(3)
    end)
end

function Menu:buildCollection(page)
    local scroll=Instance.new("ScrollingFrame")
    scroll.Name="Collection"; scroll.Size=UDim2.fromScale(1,1); scroll.BackgroundTransparency=1
    scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=C.purple
    scroll.CanvasSize=UDim2.fromOffset(0,510); scroll.ScrollingDirection=Enum.ScrollingDirection.Y
    scroll.Active=true; scroll.Parent=page
    self.collection=scroll; self.cards={}
    for i,entry in Catalog.entries do
        local card=W.button(scroll,"Prestige"..i,((i-1)%3)*298,math.floor((i-1)/3)*128,282,116,"",false)
        card.BackgroundColor3=C.ink; W.stroke(card,C.line)
        local icon=RankIcon.new(card,"RankIcon",8,6,68); RankIcon.set(icon,rankData(i))
        W.text(card,"Title",84,9,186,25,Info.title(i),17,C.white,bold)
        W.text(card,"Item",84,36,186,21,entry.name,13,C.muted)
        local badge=picture(card,"StateSprite","locked",84,59,22)
        local status=W.text(card,"State",112,59,158,22,"",12,C.muted)
        local requirement=Info.requirement(i)
        W.text(card,"Requirement",12,88,258,18,requirement,11,C.muted)
        self.cards[i]={button=card,badge=badge,status=status,stroke=card:FindFirstChildOfClass("UIStroke")}
        card.Activated:Connect(function() self.selected=i; self:setTab(3) end)
    end
end

function Menu:buildRequirements(page)
    local hero=W.box(page,"TargetRank",0,0,264,364,C.ink)
    self.targetIcon=RankIcon.new(hero,"RankIcon",56,0,152)
    self.targetTitle=W.text(hero,"Title",12,163,240,30,"",22,C.white,heavy)
    self.targetTitle.TextXAlignment=Enum.TextXAlignment.Center
    self.previous=W.button(hero,"Previous",12,210,112,34,"< Previous",false)
    self.forward=W.button(hero,"Next",140,210,112,34,"Next >",false)
    self.targetItem=W.text(hero,"Item",12,261,240,24,"",14,C.muted)
    self.targetItem.TextXAlignment=Enum.TextXAlignment.Center
    self.targetRange=W.text(hero,"Range",12,291,240,23,"",13,C.muted)
    self.targetRange.TextXAlignment=Enum.TextXAlignment.Center
    self.targetStateSprite=picture(hero,"StateSprite","locked",76,326,26)
    self.targetState=W.text(hero,"State",110,327,144,24,"",12,C.muted)
    self.previous.Activated:Connect(function() self.selected=math.max(1,self.selected-1); self.armed=false; self:refresh() end)
    self.forward.Activated:Connect(function() self.selected=math.min(12,self.selected+1); self.armed=false; self:refresh() end)
    picture(page,"RequirementsSprite","requirements",284,0,52)
    W.text(page,"Heading",350,8,542,38,"Prestige requirements",27,C.white,heavy)
    self.requirementSprite=picture(page,"LevelState","locked",284,70,34)
    self.requirement=wrapped(page,"Requirement",332,67,560,42,"",18,C.white)
    picture(page,"LobbyState","unlocked",284,119,34)
    W.text(page,"LobbyRequirement",332,123,560,26,"Choose prestige from the lobby.",16,C.muted)
    self.after=wrapped(page,"After",284,166,608,28,"",16,C.white)
    self.kept=wrapped(page,"Kept",284,196,608,26,"",13,C.muted)
    local track=W.box(page,"RequirementTrack",284,235,608,8,C.line)
    self.requirementFill=W.box(track,"Fill",0,0,0,8,C.purple)
    self.requirementProgress=W.text(page,"RequirementProgress",284,252,608,22,"",13,C.muted)
    self.claim=W.button(page,"PrestigeAction",284,289,608,42,"",true)
    self.claimHint=W.text(page,"Confirmation",284,337,608,24,"",12,C.muted)
    self.claim.Activated:Connect(function() self:activatePrestige() end)
end

function Menu:setTab(index)
    self.tab=index; self.armed=false; self:refresh()
    if gamepad() then Gui.SelectedObject=self.tabs[index] end
end

function Menu:refresh()
    local d=Menu.read()
    local ready=d~=nil and player:GetAttribute("ProgressionReady")==true
    RankIcon.set(self.currentIcon,d)
    self.currentTitle.Text=d and Info.title(Info.current(d)) or "Loading rank…"
    self.currentLevel.Text=d and ("Level %d / %d"):format(d.level,P.cap(d)) or ""
    local entry=Catalog.get(d)
    self.currentItem.Text=entry and entry.name or ""
    self.journey.Text=not d and "Your progression is loading."
        or d.master and (d.level==P.MasterLevel and "Prestige Master complete. You reached the final level." or "Your Master journey continues toward level 1,000.")
        or d.level==P.PrestigeLevel and "Level cap reached. Your next prestige is ready."
        or ("Reach level %d to unlock your next prestige."):format(P.PrestigeLevel)
    local capped=d and d.level==P.cap(d)
    self.xpFill.Size=UDim2.fromScale(d and (capped and 1 or d.xp/P.cost(d.level)) or 0,1)
    self.xpFill.BackgroundColor3=d and d.master and C.mint or C.purple
    self.xpText.Text=not d and "" or capped and (d.master and "MAX LEVEL / 1,000" or "LEVEL 55 / PRESTIGE AVAILABLE")
        or ("%d / %d XP → Level %d"):format(d.xp,P.cost(d.level),d.level+1)
    self.lifetime.Text=d and ("%d"):format(d.totalXP) or "—"
    self.nextRank.Text=d and (Info.next(d) and "Next: "..Info.title(Info.next(d)) or "Every prestige unlocked") or ""
    for i,card in self.cards do
        local status=Info.status(d,i)
        local unlocked=status=="Current" or status=="Unlocked" or status=="Ready"
        card.status.Text=status:upper()
        card.status.TextColor3=unlocked and C.mint or C.muted
        card.badge.Image=unlocked and Art.unlocked or Art.locked
        card.stroke.Color=status=="Current" and C.purple or status=="Ready" and C.mint or C.line
    end
    local index=self.selected
    local state=Info.status(d,index)
    RankIcon.set(self.targetIcon,rankData(index))
    self.targetTitle.Text=Info.title(index)
    self.targetItem.Text=Catalog.entries[index].name
    if self.opened then self.reveal:prepare(rankData(index)) end
    self.targetRange.Text=index==12 and "MASTER LEVELS 55–1,000" or "LEVELS 1–55"
    self.targetState.Text=state:upper()
    local met=Info.fraction(d,index)==1
    self.targetStateSprite.Image=met and Art.unlocked or Art.locked
    local _,requirement=Info.requirement(index)
    self.requirement.Text=requirement
    self.requirementSprite.Image=met and Art.unlocked or Art.locked
    self.after.Text,self.kept.Text=Info.after(index)
    self.requirementFill.Size=UDim2.fromScale(Info.fraction(d,index),1)
    self.requirementFill.BackgroundColor3=met and C.mint or C.purple
    self.requirementProgress.Text=met and "Requirement completed"
        or d and index==Info.next(d) and ("Level %d / %d"):format(d.level,P.PrestigeLevel)
        or "Complete the previous prestige first."
    local nextIndex=Info.next(d)
    local eligible=Info.canClaim(d,index) and ready
    local canRedirect=nextIndex~=nil and index>nextIndex
    self.claim.Active=not self.busy and ready and (eligible or canRedirect)
    self.claim.Selectable=self.claim.Active
    self.claim.AutoButtonColor=self.claim.Active
    self.claim.BackgroundColor3=self.claim.Active and C.purple or C.line
    self.claim.Text=self.busy and "Prestiging…" or not ready and "Waiting for progression…"
        or index<=Info.current(d) and "Already unlocked"
        or canRedirect and "View your next prestige"
        or not eligible and ("Reach level %d to prestige"):format(P.PrestigeLevel)
        or self.armed and "Confirm "..Info.title(index)
        or index==12 and "Become Prestige Master" or "Unlock "..Info.title(index)
    self.claimHint.Text=self.message or (not ready and player:GetAttribute("ProgressionStatus"))
        or self.armed and (index==12 and "Confirm to keep level 55 and unlock Master levels." or "Confirm to reset your level and current XP.")
        or "Select any prestige in the collection to view its requirements."
    self.previous.Active=index>1; self.previous.Selectable=index>1
    self.forward.Active=index<12; self.forward.Selectable=index<12
    for i,page in self.pages do page.Visible=i==self.tab; self.tabs[i].BackgroundColor3=i==self.tab and C.purple or C.line end
    self:navigation()
end

function Menu:navigation()
    local chain={self.tabs[1],self.tabs[2],self.tabs[3]}
    if self.tab==1 then table.insert(chain,self.viewRequirements)
    elseif self.tab==2 then for _,card in self.cards do table.insert(chain,card.button) end
    else
        if self.previous.Selectable then table.insert(chain,self.previous) end
        if self.forward.Selectable then table.insert(chain,self.forward) end
        if self.claim.Selectable then table.insert(chain,self.claim) end
    end
    table.insert(chain,self.close)
    for i,button in chain do
        button.NextSelectionUp=chain[i==1 and #chain or i-1]
        button.NextSelectionDown=chain[i==#chain and 1 or i+1]
        button.NextSelectionLeft=button.NextSelectionUp
        button.NextSelectionRight=button.NextSelectionDown
    end
end

function Menu:activatePrestige()
    if self.busy or self.reveal.active then return end
    local d=Menu.read()
    if self.selected~=(Info.next(d) or 12) and Info.next(d) then self.selected=Info.next(d); self.armed=false; self:refresh(); return end
    if not Info.canClaim(d,self.selected) or not player:GetAttribute("ProgressionReady") then return end
    if not self.armed then self.armed=true; self:refresh(); return end
    self.busy=true; self:refresh()
    local ok,message,unlocked=pcall(function() return shared:WaitForChild("Prestige"):InvokeServer() end)
    self.busy=false; self.armed=false
    self.message=ok and message or "Prestige unavailable. Please try again."
    self:refresh()
    if ok and type(unlocked)=="table" and Info.current(unlocked)==Info.current(d)+1 and self.opened and self.gui.Enabled then
        self.reveal:play(unlocked)
    end
end

function Menu:setOpen(open)
    if not open then self.reveal:hide(false) end
    if open and (not self.gui.Enabled or Gui.MenuIsOpen) then return end
    if (self.opened==true)==open then return end
    if open and self.beforeOpen then self.beforeOpen() end
    if self.clear then self.clear() end
    self.opened=open; self.armed=false; self.message=nil
    self.overlay.Visible=open
    self.gui:SetAttribute("MenuOpen",open)
    if not self.controls then
        local module=player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then local ok,value=pcall(function() return require(module):GetControls() end); if ok then self.controls=value end end
    end
    if open then
        self.selected=Info.next(Menu.read()) or 12
        self.tab=1
        if self.controls then self.controls:Disable() end
        CAS:BindActionAtPriority("NOVA_ProgressionMovement",function() return Enum.ContextActionResult.Sink end,
            false,Enum.ContextActionPriority.High.Value+35,
            Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
            Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D)
        -- Some Roblox clients manage default controls without a PlayerModule.
        -- Clear touch/thumbstick movement after the default controller updates.
        Run:BindToRenderStep("NOVA_ProgressionMovement",Enum.RenderPriority.Last.Value+1,function()
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:Move(Vector3.zero,false); humanoid.Jump=false end
        end)
        self.pop.Scale=.94
        Tween:Create(self.pop,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        Gui.SelectedObject=gamepad() and self.tabs[1] or nil
    else
        CAS:UnbindAction("NOVA_ProgressionMovement")
        Run:UnbindFromRenderStep("NOVA_ProgressionMovement")
        if self.controls then self.controls:Enable() end
        Gui.SelectedObject=gamepad() and self.gui.Enabled and self.launcher or nil
    end
    self:refresh()
end

return Menu
