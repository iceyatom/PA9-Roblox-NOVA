-- Robux item shop for the 3D lobby. Offers and prices come from ShopCatalog; Roblox's purchase prompt
-- charges the player and the server delivers through ShopService. Nothing here can grant an item.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Gui=game:GetService("GuiService")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Market=game:GetService("MarketplaceService")
local Content=game:GetService("ContentProvider")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local Shop=require(shared.ShopCatalog)
local Art=require(shared.ShopArt)
local Season=require(shared.SeasonOne)
local Catalog=require(shared.InventoryCatalog)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Reveal=require(script.Parent.ShopReveal)
local C=W.colors
local robux=utf8.char(0xE002) -- Roblox's built-in Robux glyph
local Menu={}; Menu.__index=Menu
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function rect(object,x,y,w,h) object.Position=UDim2.fromOffset(x,y); object.Size=UDim2.fromOffset(w,h) end
local function icon(parent,image,x,y,size,z)
    local sprite=Instance.new("ImageLabel")
    sprite.Name="Sprite"; sprite.BackgroundTransparency=1; sprite.Image=image; sprite.ScaleType=Enum.ScaleType.Fit
    sprite.Position=UDim2.fromOffset(x,y); sprite.Size=UDim2.fromOffset(size,size); sprite.ZIndex=z or 3; sprite.Parent=parent
    return sprite
end
local function wrapped(parent,name,x,y,w,h,text,size,color,font)
    local label=W.text(parent,name,x,y,w,h,text,size,color,font or Enum.Font.Gotham)
    label.TextWrapped=true; label.TextTruncate=Enum.TextTruncate.None
    return label
end
local function sectionArt(section) return section.id=="crates" and Season.icon or Art[section.id] end
local function oddsLine()
    local crate=Catalog.byId[Shop.CrateId]
    if not crate or not crate.rewards then return "" end
    local parts={}
    for _,row in Catalog.crateOdds(crate).rarities do
        local percent=("%.2f"):format(row.percent):gsub("0+$",""):gsub("%.$","")
        table.insert(parts,("%s %s%%"):format(row.rarity,percent))
    end
    return "Drop chances: "..table.concat(parts," · ")
end

-- links: profile() returns the inventory menu's latest profile; crates() and contents() open the inventory.
function Menu.new(playerGui,clear,beforeOpen,links)
    local self=setmetatable({clear=clear,beforeOpen=beforeOpen,links=links or {},section=1,available=true,opened=false,
        cards={},buttons={},chips={}},Menu)
    local gui=Instance.new("ScreenGui"); gui.Name="NOVAShop"; gui.ResetOnSpawn=false; gui.DisplayOrder=8
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=playerGui; self.gui=gui
    local launcher=W.button(gui,"ShopButton",16,176,220,72,"",false); self.launcher=launcher
    launcher.BackgroundColor3=C.panel; W.stroke(launcher,C.line)
    Style.round(launcher,10)
    icon(launcher,Art.shop,8,8,56)
    W.text(launcher,"Label",76,0,136,72,"Shop",26,C.white,Enum.Font.GothamBlack)
    self.launcherScale=Instance.new("UIScale"); self.launcherScale.Parent=launcher
    local launcherStroke=launcher:FindFirstChildOfClass("UIStroke")
    launcher.MouseEnter:Connect(function() launcherStroke.Color=C.purple end)
    launcher.MouseLeave:Connect(function() launcherStroke.Color=C.line end)
    -- Running token timers stay visible in the lobby while the shop is closed.
    local chipRow=W.box(gui,"ActiveTokens",16,256,220,30); self.chipRow=chipRow
    self.chipScale=Instance.new("UIScale"); self.chipScale.Parent=chipRow
    for index,kind in {"xp","crate"} do
        local chip=W.box(chipRow,"Token_"..kind,(index-1)*112,0,108,30,C.panel)
        Style.surface(chip,8); chip.Visible=false
        icon(chip,Art[kind],5,3,24)
        local label=W.text(chip,"Remaining",34,0,70,30,"",14,C.mint,Enum.Font.GothamBold)
        self.chips[kind]={frame=chip,label=label}
    end
    local overlay=Instance.new("ScrollingFrame"); overlay.Name="ShopOverlay"; overlay.ZIndex=20
    overlay.Size=UDim2.fromScale(1,1); overlay.BackgroundColor3=C.ink; overlay.BackgroundTransparency=.12
    overlay.BorderSizePixel=0; overlay.ScrollBarThickness=4; overlay.ScrollBarImageColor3=C.purple
    overlay.CanvasSize=UDim2.fromOffset(0,0); overlay.ScrollingDirection=Enum.ScrollingDirection.Y
    overlay.Active=true; overlay.Visible=false; overlay.Parent=gui; self.overlay=overlay
    local origin=W.box(overlay,"Origin",0,0,0,0); origin.Position=UDim2.fromScale(.5,.5); self.origin=origin
    self.fit=Instance.new("UIScale"); self.fit.Parent=origin
    local panel=W.box(origin,"Panel",-520,-325,1040,650,C.panel); self.panel=panel; panel.Active=true
    self.pop=Instance.new("UIScale"); self.pop.Parent=panel
    Style.surface(panel,12)
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
    self.headerIcon=icon(panel,Art.shop,18,10,62)
    self.title=W.text(panel,"Title",94,21,510,39,"Item shop",29,C.white,Enum.Font.GothamBlack)
    self.close=Style.button(panel,"Close",954,24,62,40,"×",false); self.close.TextSize=26
    self.tabs={}
    for i,section in Shop.sections do
        local tab=Style.button(panel,"Tab_"..section.id,24+(i-1)*333,92,325,44,"",false)
        icon(tab,sectionArt(section),8,6,32)
        local label=W.text(tab,"Label",48,0,270,44,section.name,18,C.white,Enum.Font.GothamBold)
        label.TextScaled=true
        local limit=Instance.new("UITextSizeConstraint"); limit.MinTextSize=11; limit.MaxTextSize=18; limit.Parent=label
        tab.Activated:Connect(function() self:setSection(i) end); self.tabs[i]=tab
    end
    local info=W.box(panel,"Info",24,152,992,58,C.ink); self.info=info
    Style.surface(info,10)
    self.blurb=wrapped(info,"Blurb",16,6,620,46,"",14,C.muted)
    self.state=W.text(info,"State",660,0,316,58,"",16,C.muted,Enum.Font.GothamBold)
    self.state.TextXAlignment=Enum.TextXAlignment.Right
    self.contentsButton=Style.button(info,"ViewContents",806,9,170,40,"View contents",false)
    self.contentsButton.TextSize=15
    self.contentsButton.Activated:Connect(function()
        if not self.reveal.active and self.links.contents then self.links.contents() end
    end)
    self.offers=W.box(panel,"Offers",24,224,992,372)
    self.status=W.text(panel,"Status",24,622,992,20,"",14,C.muted,Enum.Font.Gotham)
    self.reveal=Reveal.new(panel,function()
        self:refresh(); Gui.SelectedObject=gamepad() and self.close or nil
    end,self.links.crates and function() self.links.crates() end or nil)
    launcher.Activated:Connect(function() self:setOpen(not self.opened) end)
    self.close.Activated:Connect(function() self:setOpen(false) end)
    Gui.MenuOpened:Connect(function() self:setOpen(false) end)
    Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        if not self.opened or not Gui.SelectedObject then return end
        local boundary=self.confirmation or (self.reveal.active and self.reveal.overlay or self.overlay)
        if boundary and not Gui.SelectedObject:IsDescendantOf(boundary) then
            if self.confirmation then Gui.SelectedObject=self.confirmation.Panel.Cancel;return end
            local done=self.reveal.active and boundary:FindFirstChild("Continue")
            if self.reveal.active then Gui.SelectedObject=done and done.Visible and done or nil
            else Gui.SelectedObject=self.close end
        end
    end)
    shared:WaitForChild("InventoryState").OnClientEvent:Connect(function(profile)
        if not self.latest or profile.version>=self.latest.version then self.latest=profile end
        self:refresh()
    end)
    shared:WaitForChild("ShopDelivered").OnClientEvent:Connect(function(receipt) self:delivered(receipt) end)
    Market.PromptProductPurchaseFinished:Connect(function(userId,productId,purchased)
        local pending=self.pending
        if userId~=player.UserId or not pending or Shop.byId[pending.id].productId~=productId then return end
        if purchased then pending.state="delivering"; pending.started=os.clock() else self.pending=nil end
        self:refresh()
    end)
    CAS:BindActionAtPriority("NOVA_ShopClose",function(_,state)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            if self.confirmation then self:cancelConfirmation()
            elseif self.reveal.active then
                -- The celebration can be skipped once its buttons are showing.
                local done=self.reveal.overlay and self.reveal.overlay:FindFirstChild("Continue")
                if done and done.Visible then self.reveal:hide(); self:refresh(); Gui.SelectedObject=gamepad() and self.close or nil end
            else self:setOpen(false) end
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
    CAS:BindActionAtPriority("NOVA_ShopTabs",function(_,state,input)
        if not self.opened then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin and not self.reveal.active and not self.confirmation then
            self:setSection((self.section-1+(input.KeyCode==Enum.KeyCode.ButtonR1 and 1 or -1))%#self.tabs+1)
            Gui.SelectedObject=self.tabs[self.section]
        end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+45,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
    local elapsed=0
    Run.Heartbeat:Connect(function(dt)
        elapsed+=dt
        if elapsed>=.25 then elapsed=0; self:tick() end
    end)
    task.spawn(function() self:checkPolicy() end)
    self:resize()
    return self
end

-- The freshest profile either this menu or the inventory menu has received.
function Menu:profile()
    local mine,theirs=self.latest,self.links.profile and self.links.profile() or nil
    local profile=mine and theirs and (mine.version>=theirs.version and mine or theirs) or mine or theirs
    return profile and profile.data,profile
end

-- Paid random items (crates) must be hidden where local rules restrict them.
function Menu:checkPolicy()
    if self.checkingPolicy or self.restricted==false then return end
    self.checkingPolicy=true
    local ok,policy=pcall(function() return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player) end)
    self.checkingPolicy=false
    self.policyFailed=not ok
    self.restricted=not ok or policy.ArePaidRandomItemsRestricted==true
    self:refresh()
end

function Menu:offerState(product,profile)
    local pending=self.pending
    if pending and pending.id==product.id then return pending.state=="delivering" and "Delivering…" or "Purchasing…",false end
    if product.quantity and self.restricted~=false then
        return self.restricted==nil and "Checking…" or "Unavailable",false
    end
    local test=product.productId==0
    if test and not (Run:IsStudio() and shared:FindFirstChild("ShopStudioPurchase")) then return "Coming soon",false end
    if not profile or not profile.ready then return "Loading…",false end
    return test and "Buy  /  Studio test" or "Buy",pending==nil and not self.reveal.active and not self.confirmation
end

function Menu:closeConfirmation()
    local root=self.confirmation
    self.confirmation=nil;self.confirmProduct=nil
    if root then root:Destroy() end
end
function Menu:cancelConfirmation()
    local product=self.confirmProduct
    self:closeConfirmation();self:refresh()
    if gamepad() then
        local target=self.close
        for _,button in self.buttons do if button:GetAttribute("ProductId")==product and button.Selectable then target=button;break end end
        Gui.SelectedObject=target
    end
end
function Menu:buy(product)
    if not self.opened or not self.available or self.confirmation then return end
    local _,profile=self:profile()
    local _,active=self:offerState(product,profile)
    if not active then return end
    local root=W.box(self.gui,"PurchaseConfirmation",0,0,0,0,C.ink,40)
    root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=.18;root.Active=true
    self.confirmation=root;self.confirmProduct=product.id
    local panel=W.box(root,"Panel",0,0,580,420,C.panel)
    panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Active=true;Style.surface(panel,14)
    local scale=Instance.new("UIScale");scale.Parent=panel
    local function resize() scale.Scale=math.max(.01,math.min(1.15,(root.AbsoluteSize.X-24)/580,(root.AbsoluteSize.Y-24)/420)) end
    local connection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    root.Destroying:Once(function() connection:Disconnect() end);resize()
    local title=W.text(panel,"Title",24,18,532,34,"CONFIRM PURCHASE",25,C.white,Enum.Font.GothamBlack);title.TextXAlignment=Enum.TextXAlignment.Center
    icon(panel,sectionArt(Shop.sectionById[product.section]),246,65,88)
    local description=product.quantity and (Shop.commas(product.quantity).." "..Season.name..(product.quantity==1 and "" or "s"))
        or (product.minutes.." minutes of "..Shop.sectionById[product.section].name)
    local summary=wrapped(panel,"Summary",24,163,532,56,description,26,C.white,Enum.Font.GothamBold);summary.TextXAlignment=Enum.TextXAlignment.Center
    local price=W.text(panel,"Price",24,223,532,38,robux.." "..Shop.commas(product.price).." Robux",26,C.mint,Enum.Font.GothamBlack);price.TextXAlignment=Enum.TextXAlignment.Center
    local note=product.productId==0 and "Studio test purchase — no Robux will be charged." or "Confirm to continue to Roblox’s purchase prompt."
    if product.minutes then note..=" Boost time starts immediately and adds to any active time." end
    local detail=wrapped(panel,"Detail",28,272,524,64,note,16,C.muted);detail.TextXAlignment=Enum.TextXAlignment.Center
    local cancel=Style.button(panel,"Cancel",24,354,260,44,"Cancel",false)
    local confirm=Style.button(panel,"Confirm",296,354,260,44,"Confirm",true)
    cancel.Activated:Connect(function() if self.confirmation==root then self:cancelConfirmation() end end)
    confirm.Activated:Connect(function()
        if self.confirmation~=root then return end
        confirm.Active=false;self:closeConfirmation();self:purchase(product)
    end)
    cancel.NextSelectionRight=confirm;confirm.NextSelectionLeft=cancel
    self:refresh()
    if gamepad() then Gui.SelectedObject=cancel end
end
function Menu:purchase(product)
    if not self.opened or not self.available then return end
    local _,profile=self:profile()
    local _,active=self:offerState(product,profile)
    if not active then return end
    self.pending={id=product.id,state="prompt",started=os.clock()}; self.message=nil
    self:refresh()
    if product.productId~=0 then
        local ok=pcall(function() Market:PromptProductPurchase(player,product.productId) end)
        if not ok then self.pending=nil; self.message="Could not open the purchase prompt. Please try again."; self:refresh() end
        return
    end
    task.spawn(function()
        local ok,response=pcall(function() return shared.ShopStudioPurchase:InvokeServer(product.id) end)
        if ok and response.ok then return end -- ShopDelivered already cleared the pending purchase
        if self.pending and self.pending.id==product.id then self.pending=nil end
        self.message=ok and response.message or "Connection interrupted. Please try again."
        self:refresh()
    end)
end

function Menu:delivered(receipt)
    if type(receipt)~="table" or not Shop.byId[receipt.productId] then return end
    self:closeConfirmation()
    self.pending=nil; self.message=nil
    if self.available then
        if not self.opened then self:setOpen(true) end
        if self.opened then
            self.overlay.CanvasPosition=Vector2.zero
            local section=table.find(Shop.sections,Shop.sectionById[Shop.byId[receipt.productId].section])
            if section and section~=self.section then self.section=section; self:resize() end
            self.reveal:show(receipt)
        end
    end
    self:refresh()
end

function Menu:tick()
    local now=workspace:GetServerTimeNow()
    local data=self:profile()
    local pending=self.pending
    if pending and os.clock()-pending.started>(pending.state=="delivering" and 45 or 300) then
        self.message=pending.state=="delivering" and "Roblox is still confirming your purchase. It will be delivered automatically." or nil
        self.pending=nil; self:refresh()
    end
    local shown=0
    for _,kind in {"xp","crate"} do
        local chip=self.chips[kind]
        local left=data and data.boosts and (data.boosts[kind] or 0)-now or 0
        chip.frame.Visible=left>0
        if left>0 then
            chip.frame.Position=UDim2.fromOffset(shown*112,0); shown+=1
            chip.label.Text=Shop.clock(left)
        end
    end
    if not self.opened then return end
    self.reveal:tick(now)
    local section=Shop.sections[self.section]
    if section.id=="crates" then
        self.state.Text=("OWNED  ×%s"):format(Shop.commas(data and data.owned[Shop.CrateId] or 0))
        self.state.TextColor3=C.white
    else
        local left=data and data.boosts and (data.boosts[section.id] or 0)-now or 0
        self.state.Text=left>0 and ("ACTIVE  /  %s LEFT"):format(Shop.clock(left)) or "NO TOKEN ACTIVE"
        self.state.TextColor3=left>0 and C.mint or C.muted
    end
end

function Menu:resize()
    if not self.status then return end
    local width,height=self.overlay.AbsoluteSize.X,self.overlay.AbsoluteSize.Y
    if width<1 or height<1 then return end
    if self.lastWidth and math.abs(width-self.lastWidth)>1 and self.reveal.active then self.reveal:hide() end
    self.lastWidth=width
    local launcherScale=math.min(1,math.max(.5,(self.gui.AbsoluteSize.X-32)/220))
    self.launcherScale.Scale=launcherScale; self.chipScale.Scale=launcherScale
    local compact=width<1000 or height<560
    local panelWidth=compact and math.min(720,math.max(340,width-24)) or 1040
    local inner=panelWidth-48
    self.compact=compact; self.inner=inner
    self.title.TextSize=compact and 24 or 29
    rect(self.title,compact and 78 or 94,compact and 22 or 21,compact and panelWidth-170 or 510,39)
    rect(self.headerIcon,compact and 20 or 18,compact and 16 or 10,compact and 48 or 62,compact and 48 or 62)
    rect(self.close,panelWidth-86,24,62,40)
    local tabWidth=(inner-(#self.tabs-1)*8)/#self.tabs
    for i,tab in self.tabs do
        rect(tab,24+(i-1)*(tabWidth+8),92,tabWidth,44)
        local narrow=tabWidth<190
        tab.Sprite.Visible=not narrow
        rect(tab.Label,narrow and 4 or 48,0,narrow and tabWidth-8 or tabWidth-56,44)
        tab.Label.TextXAlignment=narrow and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    end
    local crates=Shop.sections[self.section].id=="crates"
    local infoHeight=compact and (crates and 132 or 96) or 58
    rect(self.info,24,152,inner,infoHeight)
    if compact then
        rect(self.blurb,14,8,inner-28,crates and 76 or 52)
        rect(self.state,14,infoHeight-36,inner-(crates and 190 or 28),28)
        rect(self.contentsButton,inner-170,infoHeight-42,156,34)
        self.blurb.TextSize=13; self.state.TextSize=15
        self.state.TextXAlignment=Enum.TextXAlignment.Left
    else
        rect(self.blurb,16,6,crates and 560 or 640,46)
        rect(self.state,crates and 590 or 660,0,crates and 200 or 316,58)
        rect(self.contentsButton,806,9,170,40)
        self.blurb.TextSize=crates and 13 or 14; self.state.TextSize=16
        self.state.TextXAlignment=Enum.TextXAlignment.Right
    end
    local count=#Shop.sections[self.section].products
    local offersY=152+infoHeight+(compact and 12 or 14)
    local offersHeight=compact and count*110-10 or 372
    rect(self.offers,24,offersY,inner,offersHeight)
    local statusY=compact and offersY+offersHeight+12 or 622
    rect(self.status,24,statusY,inner,compact and 34 or 20)
    self.status.TextWrapped=compact; self.status.TextYAlignment=compact and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    local panelHeight=compact and statusY+48 or 650
    self.panel.Size=UDim2.fromOffset(panelWidth,panelHeight)
    self.fit.Scale=compact and math.min(1,(width-24)/panelWidth) or math.max(.01,math.min(1.3,(width-48)/1040,(height-48)/650))
    self.overlay.ScrollingEnabled=compact
    self.overlay.CanvasSize=compact and UDim2.fromOffset(0,panelHeight*self.fit.Scale+24) or UDim2.fromOffset(0,0)
    self.origin.Position=compact and UDim2.new(.5,0,0,12) or UDim2.fromScale(.5,.5)
    self.panel.Position=UDim2.fromOffset(-panelWidth/2,compact and 0 or -325)
    self:refresh()
end

function Menu:setSection(index)
    if self.confirmation or self.reveal.active or index==self.section then return end
    self.section=index; self.message=nil
    if self.compact then self.overlay.CanvasPosition=Vector2.zero end
    self:resize()
end

-- Old price struck through beside the sale price, grouped so both stay centred or right-aligned.
-- only: "sale" or "list" draws just that price (narrow rows split them across two lines).
local function priceRow(card,product,x,y,w,h,alignment,large,only)
    local row=W.box(card,only=="list" and "ListPriceRow" or "Price",x,y,w,h)
    local layout=Instance.new("UIListLayout")
    layout.FillDirection=Enum.FillDirection.Horizontal; layout.HorizontalAlignment=alignment
    layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Padding=UDim.new(0,large and 12 or 8); layout.Parent=row
    local function price(name,amount,size,color,font,order)
        local label=W.text(row,name,0,0,0,h,robux.." "..Shop.commas(amount),size,color,font)
        label.AutomaticSize=Enum.AutomaticSize.X; label.TextTruncate=Enum.TextTruncate.None; label.LayoutOrder=order
        return label
    end
    if product.listPrice and only~="sale" then
        local old=price("ListPrice",product.listPrice,large and 17 or 14,C.muted,Enum.Font.GothamBold,1)
        local strike=W.box(old,"Strike",0,0,0,2,C.red,4)
        strike.AnchorPoint=Vector2.new(0,.5); strike.Position=UDim2.new(0,-2,.5,0); strike.Size=UDim2.new(1,4,0,2)
    end
    if only~="list" then price("SalePrice",product.price,large and 28 or 20,C.white,Enum.Font.GothamBlack,2) end
    return row
end
local function savingsBadge(card,product,x,y,small)
    local savings=Shop.savings(product)
    if savings<=0 then return end
    local width=small and 54 or 96
    local badge=W.box(card,"Savings",x,y,width,24,C.mint,4); Style.round(badge,6)
    local label=W.text(badge,"Label",0,0,width,24,(small and "-%d%%" or "SAVE %d%%"):format(savings),13,C.ink,Enum.Font.GothamBlack)
    label.TextXAlignment=Enum.TextXAlignment.Center
end
-- Bundles read as a pile: more crates behind the front one, with the count on a tag.
local function offerArt(card,product,x,y,size)
    local holder=W.box(card,"Art",x,y,size,size)
    if not product.quantity then icon(holder,Art[product.section],0,0,size); return holder end
    local behind=product.quantity>=10 and 2 or product.quantity>=5 and 1 or 0
    local front=behind>0 and size*.82 or size
    if behind==2 then
        icon(holder,Season.icon,-size*.06,size*.02,size*.6,2).ImageTransparency=.15
        icon(holder,Season.icon,size*.46,size*.02,size*.6,2).ImageTransparency=.15
    elseif behind==1 then
        icon(holder,Season.icon,size*.36,0,size*.64,2).ImageTransparency=.15
    end
    icon(holder,Season.icon,(size-front)/2-(behind==1 and size*.1 or 0),size-front,front,3)
    if product.quantity==1 then return holder end
    local tagWidth=math.max(46,size*.42)
    local tag=W.box(holder,"Quantity",size-tagWidth+6,size-30,tagWidth,28,C.purple,5); Style.round(tag,8)
    local label=W.text(tag,"Label",0,0,tagWidth,28,"×"..product.quantity,size<100 and 14 or 17,C.white,Enum.Font.GothamBlack)
    label.TextXAlignment=Enum.TextXAlignment.Center; label.ZIndex=6
    return holder
end

function Menu:refresh()
    if not self.status then return end
    local data,profile=self:profile()
    local section=Shop.sections[self.section]
    local crates=section.id=="crates"
    for i,tab in self.tabs do tab.BackgroundColor3=i==self.section and C.purple or C.line end
    self.blurb.Text=crates and section.blurb.."\n"..oddsLine() or section.blurb
    self.contentsButton.Visible=crates and self.links.contents~=nil
    self.contentsButton.Active=not self.reveal.active and not self.confirmation; self.contentsButton.Selectable=self.contentsButton.Visible and self.contentsButton.Active
    local focusId=Gui.SelectedObject and Gui.SelectedObject:GetAttribute("ProductId")
    for _,card in self.cards do card:Destroy() end
    self.cards={}; self.buttons={}
    local products=section.products
    local inner=self.inner or 992
    local gap=#products>3 and 12 or 16
    local cardWidth=(inner-(#products-1)*gap)/#products
    local focused
    for i,product in products do
        local card,button
        local title=Shop.title(product)
        local text,active=self:offerState(product,profile)
        if self.compact then
            -- Phone-width rows: art, name and markdown on the left; sale price over the button on the right.
            local narrow=inner<420
            local side=narrow and 124 or 160
            local art=narrow and 60 or 72
            local left=art+(narrow and 20 or 26)
            local textWidth=inner-left-side-20
            card=W.box(self.offers,product.id,0,(i-1)*110,inner,100,C.ink)
            offerArt(card,product,narrow and 10 or 12,(100-art)/2,art)
            if narrow and product.minutes then title=("%d MIN"):format(product.minutes) end
            local name=W.text(card,"Title",left,product.listPrice and 10 or 24,textWidth,26,title,narrow and 17 or 20,C.white,Enum.Font.GothamBlack)
            name.TextScaled=true
            local limit=Instance.new("UITextSizeConstraint"); limit.MinTextSize=11; limit.MaxTextSize=narrow and 17 or 20; limit.Parent=name
            W.text(card,"Kind",left,product.listPrice and 36 or 50,textWidth,20,section.unit,narrow and 13 or 14,C.muted,Enum.Font.GothamBold)
            savingsBadge(card,product,left,64,narrow)
            if narrow then
                priceRow(card,product,left+60,64,textWidth-52,24,Enum.HorizontalAlignment.Left,false,"list")
                priceRow(card,product,inner-side-12,8,side,30,Enum.HorizontalAlignment.Right,false,"sale")
            else
                priceRow(card,product,inner-side-12,8,side,30,Enum.HorizontalAlignment.Right,false)
            end
            button=Style.button(card,"Buy",inner-side-12,44,side,42,text,true)
        else
            card=W.box(self.offers,product.id,(i-1)*(cardWidth+gap),0,cardWidth,372,C.ink)
            local art=math.min(150,cardWidth-44)
            offerArt(card,product,(cardWidth-art)/2,30+(150-art)/2,art)
            savingsBadge(card,product,12,12)
            local name=W.text(card,"Title",8,196,cardWidth-16,32,title,cardWidth<240 and 22 or 26,C.white,Enum.Font.GothamBlack)
            name.TextXAlignment=Enum.TextXAlignment.Center
            local kind=W.text(card,"Kind",8,228,cardWidth-16,20,section.unit,15,C.muted,Enum.Font.GothamBold)
            kind.TextXAlignment=Enum.TextXAlignment.Center
            priceRow(card,product,8,258,cardWidth-16,36,Enum.HorizontalAlignment.Center,cardWidth>=240)
            button=Style.button(card,"Buy",16,310,cardWidth-32,46,text,true)
        end
        Style.surface(card,10)
        card:SetAttribute("ShopOffer",product.id)
        button:SetAttribute("ProductId",product.id)
        button.TextSize=#text>12 and 14 or 18
        button.Active=active; button.Selectable=active; button.AutoButtonColor=active
        button.BackgroundColor3=active and C.purple or C.line
        button.Activated:Connect(function() self:buy(product) end)
        if active then
            local border=card:FindFirstChildOfClass("UIStroke")
            card.MouseEnter:Connect(function() border.Color=C.purple end)
            card.MouseLeave:Connect(function() border.Color=C.line end)
        end
        self.cards[i]=card; self.buttons[i]=button
        if focusId==product.id then focused=button end
    end
    if focusId then Gui.SelectedObject=focused and focused.Selectable and focused or (gamepad() and self.tabs[self.section] or nil) end
    local restricted=crates and self.restricted and (self.policyFailed and "Could not confirm crate availability for your region. Reopen the shop to retry."
        or "Crates are not available for purchase in your region.")
    self.status.Text=self.message or restricted or profile and not profile.ready and profile.status
        or not profile and "Loading inventory…" or "Purchases are saved to your inventory as soon as Roblox confirms them."
    self.status.TextColor3=self.message and C.white or C.muted
    self:tick()
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
    local core=game:GetService("StarterGui")
    if open then
        self.playerListWasEnabled=core:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
        core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
        if self.controls then self.controls:Disable() end
        CAS:BindActionAtPriority("NOVA_ShopMovement",function() return Enum.ContextActionResult.Sink end,false,
            Enum.ContextActionPriority.High.Value+35,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump,
            Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D)
        Run:BindToRenderStep("NOVA_ShopMovement",Enum.RenderPriority.Last.Value+1,function()
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:Move(Vector3.zero,false); humanoid.Jump=false end
        end)
        Gui.SelectedObject=gamepad() and self.tabs[self.section] or nil
        if self.popTween then self.popTween:Cancel() end
        self.pop.Scale=.94
        self.popTween=Tween:Create(self.pop,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
        self.popTween:Play()
        if self.policyFailed then task.spawn(function() self:checkPolicy() end) end
        if not self.preloaded then
            self.preloaded=true
            task.spawn(function() pcall(function() Content:PreloadAsync({Art.xp,Art.crate,Art.xpFlip,Art.crateFlip,Season.icon}) end) end)
        end
    else
        self:closeConfirmation();self.reveal:hide()
        if self.playerListWasEnabled~=nil then core:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,self.playerListWasEnabled) end
        CAS:UnbindAction("NOVA_ShopMovement"); Run:UnbindFromRenderStep("NOVA_ShopMovement")
        if self.controls then self.controls:Enable() end
        Gui.SelectedObject=gamepad() and self.available and self.launcher or nil
    end
    self:refresh()
end
return Menu
