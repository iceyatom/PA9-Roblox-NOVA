local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local Catalog=require(shared.InventoryCatalog)
local Model=require(shared.Inventory)
local W=require(script.Parent.Widgets)
local Preview=require(script.Parent.InventoryPreview)
local Style=require(script.Parent.InventoryStyle)
local C=W.colors
local Menu={}; Menu.__index=Menu
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function wrapped(parent,name,x,y,w,h,text,size,color)
    local label=W.text(parent,name,x,y,w,h,text,size,color)
    label.TextWrapped=true; label.TextTruncate=Enum.TextTruncate.None
    return label
end
function Menu.new(playerGui,clear,beforeOpen)
    local self=setmetatable({clear=clear,beforeOpen=beforeOpen,category=1,rarity=0,sort=1,onlyFavorites=false,
        available=true,cards={},query="",opened=false},Menu)
    self.remote=shared:WaitForChild("InventoryRequest")
    local gui=Instance.new("ScreenGui"); gui.Name="NOVAInventory"; gui.ResetOnSpawn=false; gui.DisplayOrder=8
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=playerGui; self.gui=gui
    local launcher=W.button(gui,"InventoryButton",16,96,220,72,"",false); self.launcher=launcher
    launcher.BackgroundColor3=C.panel; W.stroke(launcher,C.line)
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,10); corner.Parent=launcher
    Preview.icon(launcher,"crates",8,8,56)
    W.text(launcher,"Label",76,0,136,72,"Inventory",26,C.white,Enum.Font.GothamBlack)
    local launcherScale=Instance.new("UIScale"); launcherScale.Parent=launcher
    local overlay=Instance.new("ScrollingFrame"); overlay.Name="InventoryOverlay"; overlay.ZIndex=20
    overlay.Size=UDim2.fromScale(1,1); overlay.BackgroundColor3=C.ink; overlay.BackgroundTransparency=.12
    overlay.BorderSizePixel=0; overlay.ScrollBarThickness=4; overlay.ScrollBarImageColor3=C.purple
    overlay.CanvasSize=UDim2.fromOffset(0,0); overlay.ScrollingDirection=Enum.ScrollingDirection.Y
    overlay.Active=true; overlay.Visible=false; overlay.Parent=gui; self.overlay=overlay
    local origin=W.box(overlay,"Origin",0,0,0,0); origin.Position=UDim2.fromScale(.5,.5)
    local fit=Instance.new("UIScale"); fit.Parent=origin
    local panel=W.box(origin,"Panel",-520,-325,1040,650,C.panel); self.panel=panel; panel.Active=true
    self.pop=Instance.new("UIScale"); self.pop.Parent=panel
    Style.surface(panel,12)
    self.origin=origin; self.fit=fit; self.launcherScale=launcherScale
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
    Preview.icon(panel,"crates",18,10,62)
    W.text(panel,"Title",94,21,510,39,"Your inventory",29,C.white,Enum.Font.GothamBlack)
    self.currency=W.text(panel,"Shards",660,26,270,32,"0 Shards",18,C.mint,Enum.Font.GothamBold)
    self.currency.TextXAlignment=Enum.TextXAlignment.Right
    self.close=Style.button(panel,"Close",954,24,62,40,"×",false); self.close.TextSize=26
    self.tabs={}
    for i,category in Catalog.categories do
        local tab=Style.button(panel,"Tab_"..category.id,24+(i-1)*166,92,162,44,"",false)
        Preview.icon(tab,category.id,4,6,32)
        W.text(tab,"Label",42,0,116,44,category.name,18,C.white,Enum.Font.GothamBold)
        tab.Activated:Connect(function() self:setCategory(i) end); self.tabs[i]=tab
    end
    local search=Instance.new("TextBox"); search.Name="Search"; search.Position=UDim2.fromOffset(24,152)
    search.Size=UDim2.fromOffset(350,38); search.BackgroundColor3=C.ink; search.TextColor3=C.white
    search.PlaceholderText="Search your items…"; search.PlaceholderColor3=C.muted; search.Text=""
    search.ClearTextOnFocus=false; search.TextSize=18; search.Font=Enum.Font.Gotham; search.ZIndex=5; search.Parent=panel
    Style.surface(search,8)
    self.search=search
    search:GetPropertyChangedSignal("Text"):Connect(function() self.query=search.Text:lower(); self:refresh() end)
    self.rarityButton=Style.button(panel,"RarityFilter",386,152,174,44,"All rarities",false)
    self.sortButton=Style.button(panel,"Sort",572,152,222,44,"Sort: Equipped",false)
    self.favoriteFilter=Style.button(panel,"FavoritesFilter",806,152,210,44,"Favorites: All",false)
    self.rarityButton.Activated:Connect(function() self.rarity=(self.rarity+1)%5; self:refresh() end)
    self.sortButton.Activated:Connect(function() self.sort=self.sort%3+1; self:refresh() end)
    self.favoriteFilter.Activated:Connect(function() self.onlyFavorites=not self.onlyFavorites; self:refresh() end)
    local scroll=Instance.new("ScrollingFrame"); scroll.Name="Items"; scroll.Position=UDim2.fromOffset(24,210)
    scroll.Size=UDim2.fromOffset(628,382); scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=C.purple; scroll.ScrollingDirection=Enum.ScrollingDirection.Y
    scroll.CanvasSize=UDim2.fromOffset(0,0); scroll.Active=true; scroll.Parent=panel; self.scroll=scroll
    self.empty=wrapped(panel,"Empty",48,300,570,92,"Loading inventory…",18,C.muted); self.empty.TextXAlignment=Enum.TextXAlignment.Center
    self.count=W.text(panel,"Count",24,594,628,22,"",14,C.muted,Enum.Font.GothamBold)
    local details=W.box(panel,"Details",676,210,340,402,C.ink); self.details=details
    Style.surface(details,10)
    self.preview=W.box(details,"Preview",14,4,312,142)
    self.itemName=W.text(details,"ItemName",18,154,304,30,"Select an item",24,C.white,Enum.Font.GothamBold)
    self.itemRarity=W.text(details,"Rarity",18,190,304,20,"",16,C.muted,Enum.Font.GothamBold)
    self.description=wrapped(details,"Description",18,222,304,74,"",18,C.muted)
    self.description.Font=Enum.Font.Gotham
    self.previewButton=Style.button(details,"PreviewSound",18,300,304,40,"Play sound preview",false)
    self.previewButton.Activated:Connect(function()
        local item=Catalog.byId[self.selected]; if item and item.category=="sounds" then Preview.sound(self.gui,item) end
    end)
    self.action=Style.button(details,"EquipOrOpen",18,344,196,44,"Equip",true)
    self.favorite=Style.button(details,"Favorite",226,344,96,44,"Favorite",false); self.favorite.TextSize=16
    self.action.Activated:Connect(function()
        local item=Catalog.byId[self.selected]
        if item then self:request(item.category=="crates" and "open" or "equip",item.id) end
    end)
    self.favorite.Activated:Connect(function() if self.selected then self:request("favorite",self.selected) end end)
    self.status=W.text(panel,"Status",24,622,992,20,"Loading inventory…",14,C.muted,Enum.Font.Gotham)
    self.reveal=require(script.Parent.CrateReveal).new(panel,function()
        self:refresh(); Gui.SelectedObject=gamepad() and self.action or nil
    end)
    self.reveal.onReady=function()
        if self.compact then
            local height=self.reveal.overlay:GetAttribute("ContentHeight") or 650
            self.overlay.CanvasPosition=Vector2.new(0,math.max(0,height*self.fit.Scale-self.overlay.AbsoluteSize.Y+24))
        end
    end
    launcher.Activated:Connect(function() self:setOpen(not self.opened) end)
    self.close.Activated:Connect(function() self:setOpen(false) end)
    Gui.MenuOpened:Connect(function() self:setOpen(false) end)
    Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        if not self.opened or not Gui.SelectedObject then return end
        local boundary=self.reveal.active and self.reveal.overlay or self.overlay
        if boundary and not Gui.SelectedObject:IsDescendantOf(boundary) then
            local done=self.reveal.active and boundary:FindFirstChild("Continue")
            if self.reveal.active then Gui.SelectedObject=done and done.Visible and done or nil
            else Gui.SelectedObject=self.close end
        end
    end)
    shared:WaitForChild("InventoryState").OnClientEvent:Connect(function(profile) self:accept(profile) end)
    CAS:BindActionAtPriority("NOVA_InventoryClose",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            if self.reveal.active then self.reveal:hide(); self:refresh(); Gui.SelectedObject=gamepad() and self.action or nil
            else self:setOpen(false) end
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
    CAS:BindActionAtPriority("NOVA_InventoryTabs",function(_,state,input)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin and not self.reveal.active then
            self:setCategory((self.category-1+(input.KeyCode==Enum.KeyCode.ButtonR1 and 1 or -1))%6+1)
            Gui.SelectedObject=self.tabs[self.category]
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
    CAS:BindActionAtPriority("NOVA_InventoryOpen",function(_,state)
        if not self.available or UIS:GetFocusedTextBox() or Gui.MenuIsOpen then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self:setOpen(not self.opened) end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+40,Enum.KeyCode.ButtonX)
    self:resize(); self:refresh()
    task.spawn(function()
        local ok,response=pcall(function() return self.remote:InvokeServer("read") end)
        if ok and response.profile then self:accept(response.profile) else self.message="Could not load inventory. Reopen to retry."; self:refresh() end
    end)
    return self
end
function Menu:accept(profile)
    if not profile or self.profile and profile.version<self.profile.version then return end
    self.profile=profile; self.data=profile.data; self:refresh()
end
function Menu:resize()
    if not self.status then return end
    local width,height=self.overlay.AbsoluteSize.X,self.overlay.AbsoluteSize.Y
    if width<1 or height<1 then return end
    if self.lastWidth and math.abs(width-self.lastWidth)>1 and self.reveal.active then self.reveal:hide() end
    self.lastWidth=width
    self.launcherScale.Scale=math.min(1,math.max(.5,(self.gui.AbsoluteSize.X-32)/220))
    local compact=width<1000 or height<560
    local panelWidth=compact and math.min(720,math.max(340,width-24)) or 1040
    local function rect(object,x,y,w,h) object.Position=UDim2.fromOffset(x,y); object.Size=UDim2.fromOffset(w,h) end
    self.compact=compact; self.columns=compact and (panelWidth<580 and 2 or 3) or 3
    self.cardWidth=compact and math.floor((panelWidth-48-(self.columns-1)*10)/self.columns) or 196
    self.panel.Title.TextSize=compact and 24 or 29
    rect(self.panel.Title,compact and 78 or 94,compact and 18 or 21,compact and panelWidth-154 or 510,39)
    rect(self.currency,compact and 78 or 660,compact and 54 or 26,compact and panelWidth-156 or 270,compact and 22 or 32)
    self.currency.TextSize=compact and 14 or 18; self.currency.TextXAlignment=compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
    rect(self.close,panelWidth-86,24,62,40)
    local tabColumns=compact and (panelWidth<580 and 3 or 6) or 6
    local tabWidth=(panelWidth-48-(tabColumns-1)*4)/tabColumns
    for i,tab in self.tabs do
        rect(tab,24+((i-1)%tabColumns)*(tabWidth+4),92+math.floor((i-1)/tabColumns)*48,tabWidth,44)
        tab.Sprite.Visible=not compact
        rect(tab.Label,compact and 3 or 42,0,compact and tabWidth-6 or 116,44)
        tab.Label.TextSize=compact and (panelWidth<580 and 14 or 16) or 18
        tab.Label.TextXAlignment=compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    end
    local filterY=92+math.ceil(6/tabColumns)*48+12
    if compact then
        rect(self.search,24,filterY,panelWidth-48,44)
        local fw=(panelWidth-64)/3
        rect(self.rarityButton,24,filterY+54,fw,44); rect(self.sortButton,32+fw,filterY+54,fw,44)
        rect(self.favoriteFilter,40+fw*2,filterY+54,fw,44)
        self.rarityButton.TextSize=14; self.sortButton.TextSize=14; self.favoriteFilter.TextSize=14
        self.gridY=filterY+112; self.detailsY=self.gridY+344
        rect(self.scroll,24,self.gridY,panelWidth-48,312)
        rect(self.empty,40,self.gridY+72,panelWidth-80,92)
        rect(self.count,24,self.gridY+316,panelWidth-48,22)
        rect(self.details,24,self.detailsY,panelWidth-48,402)
        rect(self.status,24,self.detailsY+416,panelWidth-48,24)
    else
        rect(self.search,24,152,350,44); rect(self.rarityButton,386,152,174,44)
        rect(self.sortButton,572,152,222,44); rect(self.favoriteFilter,806,152,210,44)
        self.rarityButton.TextSize=18; self.sortButton.TextSize=18; self.favoriteFilter.TextSize=18
        rect(self.scroll,24,210,628,382); rect(self.empty,48,300,570,92)
        rect(self.count,24,594,628,22); rect(self.details,676,210,340,402); rect(self.status,24,622,992,20)
    end
    local dw=self.details.Size.X.Offset
    rect(self.preview,14,4,dw-28,142); rect(self.itemName,18,154,dw-36,30)
    rect(self.itemRarity,18,190,dw-36,20); rect(self.description,18,222,dw-36,74)
    rect(self.previewButton,18,298,dw-36,40); rect(self.action,18,348,dw-144,40); rect(self.favorite,dw-114,348,96,40)
    local panelHeight=compact and self.detailsY+460 or 650
    self.panel.Size=UDim2.fromOffset(panelWidth,panelHeight)
    self.fit.Scale=compact and math.min(1,(width-24)/panelWidth) or math.max(.01,math.min(1.3,(width-48)/1040,(height-48)/650))
    self.overlay.ScrollingEnabled=compact
    self.overlay.CanvasSize=compact and UDim2.fromOffset(0,panelHeight*self.fit.Scale+24) or UDim2.fromOffset(0,0)
    self.origin.Position=compact and UDim2.new(.5,0,0,12) or UDim2.fromScale(.5,.5)
    self.panel.Position=UDim2.fromOffset(-panelWidth/2,compact and 0 or -325)
    self:refresh()
end
function Menu:setCategory(index)
    if self.reveal.active then return end
    self.category=index; self.selected=nil; self.scroll.CanvasPosition=Vector2.zero
    if self.compact then self.overlay.CanvasPosition=Vector2.zero end
    self.message=nil; self:refresh()
end
function Menu:refresh()
    if not self.status then return end
    local data=self.data
    local category=Catalog.categories[self.category].id
    self.currency.Text=("%d Shards"):format(data and data.shards or 0)
    self.rarityButton.Text=self.rarity==0 and "All rarities" or Catalog.rarities[self.rarity]
    self.sortButton.Text="Sort: "..({"Equipped","Rarity","Name"})[self.sort]
    self.favoriteFilter.Text=self.onlyFavorites and "Favorites: Only" or "Favorites: All"
    if self.compact then
        self.sortButton.Text=({"Equipped","Rarity","Name"})[self.sort]
        self.favoriteFilter.Text=self.onlyFavorites and "Favorites" or "All items"
    end
    self.favoriteFilter.BackgroundColor3=self.onlyFavorites and C.purple or C.line
    for i,tab in self.tabs do tab.BackgroundColor3=i==self.category and C.purple or C.line end
    local focusId=Gui.SelectedObject and Gui.SelectedObject:GetAttribute("ItemId")
    for _,card in self.cards do card:Destroy() end; self.cards={}
    local items={}
    if data then for _,item in Catalog.items do
        if item.category==category and Model.owns(data,item.id)
            and (self.rarity==0 or item.rarity==Catalog.rarities[self.rarity])
            and (not self.onlyFavorites or data.favorites[item.id])
            and (self.query=="" or item.name:lower():find(self.query,1,true)) then table.insert(items,item) end
    end end
    table.sort(items,function(a,b)
        if self.sort==1 then
            local ae,be=data.equipped[category]==a.id,data.equipped[category]==b.id
            if ae~=be then return ae end
        elseif self.sort==2 then
            local ar,br=Catalog.rarityIndex(a.rarity),Catalog.rarityIndex(b.rarity)
            if ar~=br then return ar>br end
        end
        return a.name<b.name
    end)
    if not table.find(items,Catalog.byId[self.selected]) then self.selected=items[1] and items[1].id or nil end
    local focused
    for i,item in items do
        local cw,columns=self.cardWidth or 196,self.columns or 3
        local card=Style.button(self.scroll,item.id,2+((i-1)%columns)*(cw+10),2+math.floor((i-1)/columns)*156,cw,144,"",false)
        card:SetAttribute("ItemId",item.id); card:SetAttribute("InventoryCard",true); card.BackgroundColor3=C.ink
        local border=card:FindFirstChildOfClass("UIStroke")
        border.Color=self.selected==item.id and C.mint or C.line; border.Transparency=0; border.Thickness=2
        Preview.icon(card,category,7,1,84)
        local accent=W.box(card,"Rarity",10,137,cw-20,3,W.rgb(Catalog.rarityColors[item.rarity])); Style.round(accent,2)
        W.text(card,"Name",10,87,cw-20,25,item.name,self.compact and 17 or 18,C.white,Enum.Font.GothamBold)
        local badge=category=="crates" and ("×%d"):format(data.owned[item.id] or 0)
            or data.equipped[category]==item.id and "EQUIPPED" or item.default and "DEFAULT" or "OWNED"
        W.text(card,"State",92,17,cw-98,22,badge,cw<170 and 11 or 12,C.mint,Enum.Font.GothamBold)
        if data.favorites[item.id] then W.text(card,"Favorite",cw-39,47,30,24,"★",22,W.rgb("ffc857")) end
        W.text(card,"RarityLabel",10,114,cw-20,20,item.rarity,14,W.rgb(Catalog.rarityColors[item.rarity]),Enum.Font.Gotham)
        card.Activated:Connect(function()
            self.selected=item.id; self:refresh()
            if self.compact then self.overlay.CanvasPosition=Vector2.new(0,(self.detailsY-12)*self.fit.Scale) end
        end)
        self.cards[i]=card; if focusId==item.id then focused=card end
    end
    if focusId then Gui.SelectedObject=focused or (gamepad() and self.tabs[self.category] or nil) end
    self.scroll.CanvasSize=UDim2.fromOffset(0,4+math.ceil(#items/(self.columns or 3))*156)
    self.empty.Visible=#items==0
    self.empty.Text=not data and (self.profile and self.profile.status or "Loading inventory…")
        or (self.query~="" or self.rarity~=0 or self.onlyFavorites) and "No items match these filters."
        or category=="crates" and "No crates yet. Owned crates will appear here." or "No items in this category yet."
    self.count.Text=("%d ITEM%s"):format(#items,#items==1 and "" or "S")
    local item=Catalog.byId[self.selected]
    self.details.Visible=item~=nil
    if item then
        Preview.draw(self.preview,item,data.equipped)
        self.itemName.Text=item.name; self.itemRarity.Text=item.rarity..(item.default and "  /  DEFAULT" or "")
        self.itemRarity.TextColor3=W.rgb(Catalog.rarityColors[item.rarity]); self.description.Text=item.description
        if item.rewards then
            local total=0; for _,r in item.rewards do total+=r.weight end
            local tiers={}; for _,r in item.rewards do local rarity=Catalog.byId[r.id].rarity; tiers[rarity]=(tiers[rarity] or 0)+r.weight end
            local odds={}; for _,rarity in Catalog.rarities do if tiers[rarity] then table.insert(odds,("%s %.1f%%"):format(rarity,100*tiers[rarity]/total)) end end
            self.description.Text="One test cosmetic. Duplicates become Shards.\n"..table.concat(odds," · ")
        end
        self.previewButton.Visible=category=="sounds"; self.previewButton.Active=not self.reveal.active
        self.action.Text=self.busy and "Working…" or category=="crates" and (self.pendingOpen and "Retry opening" or "Open crate")
            or data.equipped[category]==item.id and (item.default and "Default equipped" or "Unequip") or "Equip"
        local active=self.profile.ready and not self.busy and not self.reveal.active and not (item.default and data.equipped[category]==item.id)
        self.action.Active=active; self.action.Selectable=active; self.action.AutoButtonColor=active
        self.action.BackgroundColor3=active and C.purple or C.line
        self.favorite.Text=data.favorites[item.id] and "★ Saved" or "☆ Favorite"
        self.favorite.Active=self.profile.ready and not self.busy and not self.reveal.active
    end
    self.status.Text=self.message or self.profile and self.profile.status or "Loading inventory…"
end
function Menu:request(action,id)
    if self.busy or self.reveal.active or not self.data or not self.profile.ready then return end
    if action=="open" and self.pendingOpen and self.pendingOpen.id~=id then self.message="Retry the previous crate opening first."; self:refresh(); return end
    self.busy=true; self.message=nil
    local key
    if action=="open" then
        self.pendingOpen=self.pendingOpen or {id=id,key=game:GetService("HttpService"):GenerateGUID(false)}
        key=self.pendingOpen.key
    end
    self:refresh()
    task.spawn(function()
        local ok,response=pcall(function() return self.remote:InvokeServer(action,id,key) end)
        self.busy=false
        if not ok then self.message=action=="open" and "Connection interrupted. Retry opening to check your reward." or "Connection interrupted. Please try again."
        else
            if response.profile then self:accept(response.profile) end
            if action=="open" and (response.ok or response.message=="You do not own this crate."
                or response.message=="Invalid item." or response.message=="Invalid request." or response.message=="Request already used.") then
                self.pendingOpen=nil
            end
            self.message=response.ok and nil or response.message
            if response.ok and response.receipt then
                local item=Catalog.byId[response.receipt.itemId]
                self.message=response.receipt.duplicate and ("%s duplicate → +%d Shards"):format(item.name,response.receipt.shards) or "Received "..item.name
                if self.opened and self.available then self.overlay.CanvasPosition=Vector2.zero; self.reveal:show(response.receipt) end
            end
        end
        self:refresh()
    end)
end
function Menu:setAvailable(available)
    self.available=available; self.gui.Enabled=available
    if not available then self:setOpen(false) end
end
function Menu:setOpen(open)
    if open and (not self.available or Gui.MenuIsOpen) then return end
    if self.opened==open then return end
    if open and self.beforeOpen then self.beforeOpen() end
    if self.clear then self.clear() end
    self.opened=open; self.overlay.Visible=open
    self.gui:SetAttribute("MenuOpen",open)
    if not self.controls then
        local module=player.PlayerScripts:FindFirstChild("PlayerModule")
        if module then local ok,value=pcall(function() return require(module):GetControls() end); if ok then self.controls=value end end
    end
    if open then
        self.playerListWasEnabled=game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
        if self.controls then self.controls:Disable() end
        CAS:BindActionAtPriority("NOVA_InventoryMovement",function() return Enum.ContextActionResult.Sink end,false,
            Enum.ContextActionPriority.High.Value+35,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
            Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D)
        Run:BindToRenderStep("NOVA_InventoryMovement",Enum.RenderPriority.Last.Value+1,function()
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:Move(Vector3.zero,false); humanoid.Jump=false end
        end)
        Gui.SelectedObject=gamepad() and self.tabs[self.category] or nil
        if self.popTween then self.popTween:Cancel() end
        self.pop.Scale=.94
        self.popTween=Tween:Create(self.pop,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
        self.popTween:Play()
        if not self.data then task.spawn(function()
            local ok,response=pcall(function() return self.remote:InvokeServer("read") end)
            if ok and response.profile then self:accept(response.profile) end
        end) end
    else
        self.reveal:hide(); self.search:ReleaseFocus()
        if self.playerListWasEnabled~=nil then game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,self.playerListWasEnabled) end
        CAS:UnbindAction("NOVA_InventoryMovement"); Run:UnbindFromRenderStep("NOVA_InventoryMovement")
        if self.controls then self.controls:Enable() end
        Gui.SelectedObject=gamepad() and self.available and self.launcher or nil
    end
    self:refresh()
end
return Menu
