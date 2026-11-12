local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Preview=require(script.Parent.InventoryPreview)
local Batch=require(script.Parent.BatchOneVisuals)
local Audio=require(script.Parent.ReelAudio)
local C=W.colors
local Multi={};Multi.__index=Multi
local types={skins="Skin",bullets="Bullet skin",tracers="Tracer",backgrounds="Player background",sounds="Sound effect"}
function Multi.new(panel,receipts,equipment,onDone,onReady)
    local width=panel.Size.X.Offset
    local root=W.box(panel,"CrateReveal",0,0,width,math.max(650,panel.Size.Y.Offset),C.ink,40)
    root.Active=true;Style.round(root,12)
    root:SetAttribute("ContentHeight",650);root:SetAttribute("Phase","rolling");root:SetAttribute("RowCount",#receipts)
    return setmetatable({root=root,width=width,receipts=receipts,equipment=equipment,onDone=onDone,onReady=onReady,rows={},finished=0},Multi)
end
function Multi:refreshEquipment()
    for _,row in self.rows do if row.equip then
        local equipped=self.equipment.isEquipped(row.item)
        row.equip.Text=equipped and "Equipped" or "Equip"
        row.equip.Active=not equipped and not self.equipping;row.equip.Selectable=row.equip.Active
    end end
end
function Multi:complete(row)
    if self.closed then return end
    if row.connection then row.connection:Disconnect();row.connection=nil end
    row.audio:stop();Batch.clear(row.viewport);row.viewport:Destroy()
    row.frame:SetAttribute("Phase","settled")
    local receipt,item=row.receipt,row.item
    local height=row.frame.Size.Y.Offset
    local compact=self.width<600
    local three=#self.receipts==3
    local size=compact and 56 or math.min(96,height-20)
    Preview.icon(row.frame,item,12,(height-size)/2,size)
    local x=size+24
    local buttonWidth=compact and 76 or 120
    local textWidth=row.frame.Size.X.Offset-x-buttonWidth-36
    local nameHeight=three and 44 or 36
    local detailHeight=three and 56 or 40
    local gap=three and 4 or 2
    local textY=(height-nameHeight-detailHeight-gap)/2
    local nameSize=compact and (three and 22 or 19) or (three and 34 or 28)
    local name=W.text(row.frame,"Result",x,textY,textWidth,nameHeight,item.name,nameSize,W.rgb(Catalog.rarityColors[item.rarity]),Enum.Font.GothamBlack)
    name.TextWrapped=true;name.TextScaled=true;name.TextTruncate=Enum.TextTruncate.None
    local limit=Instance.new("UITextSizeConstraint");limit.MinTextSize=compact and 10 or 20;limit.MaxTextSize=nameSize;limit.Parent=name
    local detail=W.text(row.frame,"Detail",x,textY+nameHeight+gap,textWidth,detailHeight,
        types[item.category].." / "..item.rarity..(receipt.duplicate and (" / +"..receipt.shards.." Shards") or " / Added to inventory"),compact and (three and 14 or 12) or (three and 22 or 18),C.muted)
    detail.TextWrapped=true;detail.TextTruncate=Enum.TextTruncate.None
    if compact then
        detail.TextScaled=true
        local detailLimit=Instance.new("UITextSizeConstraint");detailLimit.MinTextSize=10;detailLimit.MaxTextSize=three and 14 or 12;detailLimit.Parent=detail
    end
    if self.equipment then
        local buttonHeight=compact and 36 or (three and 48 or 44)
        local equip=Style.button(row.frame,"EquipNow",row.frame.Size.X.Offset-buttonWidth-12,(height-buttonHeight)/2,buttonWidth,buttonHeight,"Equip",false)
        equip.TextSize=compact and 13 or (three and 22 or 20);row.equip=equip
        equip.Activated:Connect(function()
            if not equip.Active or self.equipping then return end
            self.equipping=true;self:refreshEquipment();equip.Text="Equipping…"
            task.spawn(function()
                local ok,message=self.equipment.equip(item)
                if self.closed then return end
                self.equipping=false;self:refreshEquipment()
                if not ok then detail.Text=message or "Please try again." end
            end)
        end)
        self:refreshEquipment()
    end
    self.finished+=1
    if self.finished==#self.receipts then self:finish() end
end
function Multi:finish()
    self.root:SetAttribute("Phase","settled");self.done.Visible=true
    self.title.Text="ITEMS RECEIVED"
    if self.equipment and self.equipment.open then
        local crateId=self.receipts[1].crateId
        local remaining=self.equipment.remaining(crateId)
        local choices={}
        for _,count in {1,3,5} do if remaining>=count then table.insert(choices,count) end end
        local width=(self.width-48-8*#choices)/(#choices+1)
        for index,count in choices do
            local button=Style.button(self.root,"OpenAgain"..count,24+(index-1)*(width+8),590,width,44,count==1 and "Open again" or "Open "..count,false)
            button.ZIndex=49;button.TextSize=self.width<600 and 12 or 16
            button.Activated:Connect(function() if not self.equipping then self.equipment.open(crateId,count) end end)
        end
        self.done.Position=UDim2.fromOffset(24+#choices*(width+8),590);self.done.Size=UDim2.fromOffset(width,44)
    end
    if self.onReady then self.onReady() end
    if UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=self.done end
end
function Multi:play()
    local width=self.width
    local title=W.text(self.root,"Title",24,10,width-48,34,"OPENING "..#self.receipts.." CRATES",23,C.white,Enum.Font.GothamBlack)
    title.TextXAlignment=Enum.TextXAlignment.Center;self.title=title
    self.done=Style.button(self.root,"Continue",24,590,width-48,44,"Continue",true);self.done.ZIndex=49;self.done.Visible=false
    self.done.Activated:Connect(self.onDone)
    local rowHeight=#self.receipts==5 and 100 or 166
    local reduced=Batch.reduced()
    local random=Random.new()
    for index,receipt in self.receipts do
        local frame=W.box(self.root,"Opening"..index,12,54+(index-1)*(rowHeight+6),width-24,rowHeight,C.panel,41)
        Style.round(frame,8);frame:SetAttribute("Phase","waiting");frame:SetAttribute("StartDelay",(index-1)*.24)
        local viewport=W.box(frame,"Viewport",0,0,width-24,rowHeight,nil,42);viewport.ClipsDescendants=true
        local row={frame=frame,viewport=viewport,item=Catalog.byId[receipt.itemId],receipt=receipt,audio=Audio.new(frame,"Reel"..index.."Click")}
        table.insert(self.rows,row)
        if not reduced then
            local stride,cardWidth=128,118
            local strip=W.box(viewport,"Reel",0,0,5500,rowHeight,nil,43)
            local winner=32+index
            local crate=Catalog.byId[receipt.crateId]
            for i=1,40 do
                local item=i==winner and row.item or Catalog.byId[Catalog.roll(crate,random:NextNumber())]
                local card=W.box(strip,"Reward"..i,(i-1)*stride,5,cardWidth,rowHeight-10,C.ink,44)
                Style.round(card,6)
                local iconSize=math.min(92,rowHeight-44)
                Preview.icon(card,item,(cardWidth-iconSize)/2,2,iconSize)
                local label=W.text(card,"Name",5,rowHeight-38,cardWidth-10,22,item.name,12,C.white,Enum.Font.GothamBold)
                label.TextXAlignment=Enum.TextXAlignment.Center
                W.box(card,"Rarity",0,rowHeight-14,cardWidth,4,W.rgb(Catalog.rarityColors[item.rarity]),45)
            end
            local pin=W.box(viewport,"Pin",(width-24)/2-2,0,4,rowHeight,C.mint,46);pin.BackgroundTransparency=.35
            local center=(width-24)/2
            local target=center-((winner-1)*stride+cardWidth/2)+random:NextNumber(-12,12)
            task.delay((index-1)*.24,function()
                if self.closed then return end
                frame:SetAttribute("Phase","spinning")
                row.connection=Run.RenderStepped:Connect(function() row.audio:advance(math.floor((center-strip.Position.X.Offset-cardWidth/2)/stride)) end)
                row.tween=Tween:Create(strip,TweenInfo.new(5.8+index*.13,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(target,0)})
                row.tween.Completed:Once(function(state) if state==Enum.PlaybackState.Completed then self:complete(row) end end)
                row.tween:Play()
            end)
        end
    end
    -- Finish after constructing all rows so reduced-effects mode has the same result controls.
    if reduced then for _,row in self.rows do self:complete(row) end end
end
function Multi:destroy()
    self.closed=true
    for _,row in self.rows do
        if row.connection then row.connection:Disconnect() end
        if row.tween then row.tween:Cancel() end
        row.audio:stop();Batch.clear(row.frame)
    end
end
return Multi
