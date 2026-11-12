local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Model=require(game.ReplicatedStorage.NOVA.Inventory)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Preview=require(script.Parent.InventoryPreview)
local Batch=require(script.Parent.BatchOneVisuals)
local C=W.colors
local Contents={};Contents.__index=Contents
local categoryNames={}
for _,category in Catalog.categories do categoryNames[category.id]=category.name end
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function chance(percent)
    if percent<.000001 then return "<0.000001%" end
    return ("%.6f"):format(percent):gsub("0+$",""):gsub("%.$","").."%"
end
local function text(parent,name,x,y,w,h,value,size,color)
    return W.text(parent,name,x,y,w,h,value,size,color,Enum.Font.Gotham)
end
function Contents.new(gui,onClose,onPreview,onOpen)
    return setmetatable({gui=gui,onClose=onClose,onPreview=onPreview,onOpen=onOpen,slots={}},Contents)
end
function Contents:hide()
    if self.sizeConnection then self.sizeConnection:Disconnect();self.sizeConnection=nil end
    if self.scrollConnection then self.scrollConnection:Disconnect();self.scrollConnection=nil end
    if self.gridConnection then self.gridConnection:Disconnect();self.gridConnection=nil end
    for _,slot in self.slots do if slot.art then Batch.clear(slot.art);slot.art:Destroy() end end
    self.slots={};self.selectedCard=nil
    if self.root then self.root:Destroy();self.root=nil end
end
function Contents:close()
    self:hide();if self.onClose then self.onClose() end
end
-- Only visible rows and one neighboring row instantiate cosmetic VFX.
function Contents:updateThumbnails()
    if not self.root or not self.columns then return end
    local step=224+12
    local first=math.max(0,math.floor(self.scroll.CanvasPosition.Y/step)-1)
    local last=math.ceil((self.scroll.CanvasPosition.Y+self.scroll.AbsoluteSize.Y)/step)+1
    local size=math.min(108,self.cellWidth-36)
    for index,slot in self.slots do
        local row=math.floor((index-1)/self.columns)
        if row>=first and row<=last then
            if not slot.art then slot.art=Preview.icon(slot.card,slot.entry.item,0,34,size) end
            slot.art.Position=UDim2.fromOffset((self.cellWidth-size)/2,34)
            slot.art.Size=UDim2.fromOffset(size,size)
        elseif slot.art then
            Batch.clear(slot.art);slot.art:Destroy();slot.art=nil
        end
    end
end
function Contents:resize()
    if not self.root then return end
    local size=self.root.AbsoluteSize
    local width=math.min(1380,math.max(240,size.X-24))
    local height=math.min(890,math.max(240,size.Y-24))
    self.panel.Size=UDim2.fromOffset(width,height)
    local compact=width<600
    self.icon.Position=UDim2.fromOffset(18,14);self.icon.Size=UDim2.fromOffset(compact and 48 or 68,compact and 48 or 68)
    self.title.Position=UDim2.fromOffset(compact and 80 or 100,14)
    self.title.Size=UDim2.fromOffset(width-(compact and 190 or 238),44)
    self.closeButton.Position=UDim2.fromOffset(width-102,20);self.closeButton.Size=UDim2.fromOffset(84,40)
    self.subtitle.Position=UDim2.fromOffset(compact and 18 or 100,compact and 72 or 58)
    self.subtitle.Size=UDim2.fromOffset(width-(compact and 36 or 124),24)
    self.note.Position=UDim2.fromOffset(18,compact and 100 or 92)
    self.note.Size=UDim2.fromOffset(width-36,compact and 34 or 24)
    local top=compact and 144 or 126
    self.scroll.Position=UDim2.fromOffset(18,top);self.scroll.Size=UDim2.fromOffset(width-36,math.max(36,height-top-82))
    self.owned.Position=UDim2.fromOffset(22,height-64);self.owned.Size=UDim2.fromOffset(width-240,24)
    self.hint.Position=UDim2.fromOffset(22,height-38);self.hint.Size=UDim2.fromOffset(width-240,20)
    local quantity=self.data and self.data.owned[self.crate.id] or 0
    local choices={self.openButton}
    for _,count in {3,5} do
        local button=self.batchButtons[count];button.Visible=quantity>=count
        if button.Visible then table.insert(choices,button) end
    end
    local area=compact and width-36 or math.min(420,width-260)
    local buttonWidth=(area-(#choices-1)*8)/#choices
    for index,button in choices do
        button.Position=UDim2.fromOffset(width-18-area+(index-1)*(buttonWidth+8),height-62)
        button.Size=UDim2.fromOffset(buttonWidth,44);button.TextSize=compact and 13 or 16
    end
    if compact then
        self.owned.Position=UDim2.fromOffset(22,height-114);self.hint.Position=UDim2.fromOffset(22,height-90)
        self.owned.Size=UDim2.fromOffset(width-44,24);self.hint.Size=UDim2.fromOffset(width-44,20)
        self.scroll.Size=UDim2.fromOffset(width-36,math.max(36,height-top-130))
    else
        self.owned.Size=UDim2.fromOffset(width-area-54,24);self.hint.Size=UDim2.fromOffset(width-area-54,20)
    end
    if compact then
        self.owned.TextSize=14;self.hint.TextSize=11
    else self.owned.TextSize=18;self.hint.TextSize=13 end
    local available=width-54
    self.columns=math.max(1,math.floor((available+12)/180))
    if self.columns==1 and available>=260 then self.columns=2 end
    self.cellWidth=math.floor((available-(self.columns-1)*12)/self.columns)
    self.grid.CellSize=UDim2.fromOffset(self.cellWidth,224)
    self.scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(#self.slots/self.columns)*236+4)
    self:updateThumbnails()
end
function Contents:update(data,canOpen)
    self.data=data;self.canOpen=canOpen
    if not self.root then return end
    local quantity=data and data.owned[self.crate.id] or 0
    self.owned.Text=("Owned crates: %d"):format(quantity)
    self.openButton.Text=quantity>0 and "Open crate" or "No crates owned"
    local enabled=quantity>0 and canOpen==true
    self.openButton.Active=enabled;self.openButton.Selectable=enabled;self.openButton.AutoButtonColor=enabled
    self.openButton.BackgroundColor3=enabled and C.purple or C.line
    for count,button in self.batchButtons do
        local active=quantity>=count and canOpen==true
        button.Active=active;button.Selectable=active;button.AutoButtonColor=active;button.BackgroundColor3=active and C.purple or C.line
    end
    self:resize()
    for _,slot in self.slots do slot.owned.Visible=data~=nil and Model.owns(data,slot.entry.item.id) end
end
function Contents:show(crate,data,canOpen)
    self:hide();self.crate=crate
    local root=W.box(self.gui,"CrateContents",0,0,0,0,C.ink,50)
    root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=.04;root.Active=true;self.root=root
    local panel=W.box(root,"Panel",0,0,0,0,C.panel)
    panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Active=true;self.panel=panel
    Style.surface(panel,14)
    self.icon=Preview.icon(panel,crate,18,14,68)
    self.title=text(panel,"Title",100,14,600,44,crate.name,30,C.white)
    self.title.Font=Enum.Font.GothamBlack;self.title.TextScaled=true
    local limits=Instance.new("UITextSizeConstraint");limits.MinTextSize=14;limits.MaxTextSize=30;limits.Parent=self.title
    local entries=Catalog.crateContents(crate)
    root:SetAttribute("CrateId",crate.id);root:SetAttribute("ItemCount",#entries)
    self.subtitle=text(panel,"Subtitle",100,58,600,24,("%d items · Rarity ↓ · Collection A–Z"):format(#entries),15,C.muted)
    self.note=text(panel,"Rounding",18,92,900,24,"Drop chance per opening. Rounded percentages may not total exactly 100%.",13,C.muted)
    self.note.TextWrapped=true;self.note.TextTruncate=Enum.TextTruncate.None
    self.closeButton=Style.button(panel,"CloseContents",0,20,84,40,"Back",false)
    self.closeButton.Activated:Connect(function() self:close() end)
    local scroll=Instance.new("ScrollingFrame");scroll.Name="Items";scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=6;scroll.ScrollBarImageColor3=C.purple;scroll.ScrollingDirection=Enum.ScrollingDirection.Y
    scroll.ClipsDescendants=true;scroll.Active=true;scroll.Parent=panel;self.scroll=scroll
    local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(0,2);padding.PaddingTop=UDim.new(0,2);padding.PaddingRight=UDim.new(0,14);padding.Parent=scroll
    local grid=Instance.new("UIGridLayout");grid.CellPadding=UDim2.fromOffset(12,12);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=scroll;self.grid=grid
    for index,entry in entries do
        local item=entry.item;local color=W.rgb(Catalog.rarityColors[item.rarity])
        local card=W.button(scroll,item.id,0,0,170,224,"",false);card.LayoutOrder=index
        card.BackgroundColor3=C.ink:Lerp(color,.10);card.ClipsDescendants=true;Style.round(card,9)
        W.stroke(card,color,1.5);card:SetAttribute("ContentItemId",item.id);card:SetAttribute("Rarity",item.rarity);card:SetAttribute("DropPercent",entry.percent)
        local accent=W.box(card,"Accent",0,0,0,4,color);accent.Size=UDim2.new(1,0,0,4)
        local probability=text(card,"Chance",10,8,150,24,chance(entry.percent),19,C.white)
        probability.Size=UDim2.new(1,-20,0,24);probability.Font=Enum.Font.GothamBold;probability.TextXAlignment=Enum.TextXAlignment.Center
        probability.TextScaled=true
        local limit=Instance.new("UITextSizeConstraint");limit.MinTextSize=12;limit.MaxTextSize=19;limit.Parent=probability
        local name=text(card,"Name",10,144,150,40,item.name,16,C.white)
        name.Size=UDim2.new(1,-20,0,40);name.Font=Enum.Font.GothamBold;name.TextWrapped=true;name.TextScaled=true;name.TextTruncate=Enum.TextTruncate.None
        local nameLimit=Instance.new("UITextSizeConstraint");nameLimit.MinTextSize=11;nameLimit.MaxTextSize=16;nameLimit.Parent=name
        local rarity=text(card,"RarityName",10,187,90,20,item.rarity,13,color)
        rarity.Size=UDim2.new(1,-58,0,20)
        local owned=text(card,"Owned",0,189,40,18,"OWNED",9,C.mint);owned.Position=UDim2.new(1,-49,0,189)
        local category=text(card,"Category",10,208,150,14,categoryNames[item.category] or "2× token",11,C.muted);category.Size=UDim2.new(1,-20,0,14)
        local slot={card=card,entry=entry,owned=owned};table.insert(self.slots,slot)
        card.Activated:Connect(function()
            self.selectedCard=card
            if self.onPreview then self.onPreview(item) end
        end)
        card.SelectionGained:Connect(function()
            self.selectedCard=card
            local y=math.floor((index-1)/(self.columns or 1))*236
            local top=scroll.CanvasPosition.Y
            if y<top then scroll.CanvasPosition=Vector2.new(0,y)
            elseif y+224>top+scroll.AbsoluteSize.Y then scroll.CanvasPosition=Vector2.new(0,y+224-scroll.AbsoluteSize.Y) end
        end)
    end
    self.owned=text(panel,"OwnedCrates",22,0,400,24,"",18,C.mint);self.owned.Font=Enum.Font.GothamBold
    self.hint=text(panel,"Hint",22,0,400,20,"Select an item to preview",13,C.muted)
    self.openButton=Style.button(panel,"OpenCrate",0,0,208,44,"Open crate",true)
    self.openButton.Activated:Connect(function()
        if not self.openButton.Active then return end
        self:hide();if self.onOpen then self.onOpen(crate,1) end
    end)
    self.batchButtons={}
    for _,count in {3,5} do
        local button=Style.button(panel,"Open"..count,0,0,100,44,"Open "..count,true);self.batchButtons[count]=button
        button.Activated:Connect(function()
            if not button.Active then return end
            self:hide();if self.onOpen then self.onOpen(crate,count) end
        end)
    end
    self.sizeConnection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
    self.scrollConnection=scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:updateThumbnails() end)
    self.gridConnection=grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if self.root then scroll.CanvasSize=UDim2.fromOffset(0,grid.AbsoluteContentSize.Y+8) end
    end)
    self:resize();self:update(data,canOpen)
    task.defer(function() if self.root==root then self:updateThumbnails() end end)
    if gamepad() then Gui.SelectedObject=self.slots[1] and self.slots[1].card or self.closeButton end
end
return Contents
