local Tween=game:GetService("TweenService")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local W=require(script.Parent.Widgets)
local C=W.colors
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Preview=require(script.Parent.InventoryPreview)
local Style=require(script.Parent.InventoryStyle)
local ReelAudio=require(script.Parent.ReelAudio)
local ItemUnlock=require(script.Parent.ItemUnlock)
local itemTypes={skins="Skin",bullets="Bullet Skin",tracers="Tracer",backgrounds="Player Background",sounds="Sound Effect"}
local Reveal={}; Reveal.__index=Reveal
function Reveal.new(panel,onDone)
    return setmetatable({panel=panel,onDone=onDone,generation=0,audio=ReelAudio.new(panel,"CrateCycleClick")},Reveal)
end
function Reveal:hide()
    self.generation+=1; self.active=false
    if self.rollConnection then self.rollConnection:Disconnect(); self.rollConnection=nil end
    if self.unlock then self.unlock:destroy(); self.unlock=nil end
    self.audio:stop()
    if self.tween then self.tween:Cancel(); self.tween=nil end
    if self.overlay then self.overlay:Destroy(); self.overlay=nil end
    for object in self.restore or {} do if object.Parent then object.Selectable=true end end
    self.restore=nil
end
function Reveal:show(receipt)
    self:hide(); self.active=true
    local generation=self.generation
    self.restore={}
    for _,object in self.panel:GetDescendants() do
        if object:IsA("GuiObject") and object.Selectable then self.restore[object]=true; object.Selectable=false end
    end
    Gui.SelectedObject=nil
    local item=Catalog.byId[receipt.itemId]; local crate=Catalog.byId[receipt.crateId]
    local identity=(itemTypes[item.category] or "Item").."  /  "..item.rarity
    local width=self.panel.Size.X.Offset
    local screen=self.panel:FindFirstAncestorWhichIsA("ScreenGui")
    local short=screen and screen.AbsoluteSize.Y<560
    local height=short and math.max(300,screen.AbsoluteSize.Y-24) or 650
    local root=W.box(self.panel,"CrateReveal",0,0,width,math.max(650,self.panel.Size.Y.Offset),C.ink,40); root.Active=true; self.overlay=root
    root:SetAttribute("ContentHeight",height)
    root:SetAttribute("Phase","rolling"); root:SetAttribute("ReceiptId",receipt.requestId)
    Style.round(root,12)
    if require(script.Parent.BatchOneVisuals).reduced() then
        root:SetAttribute("Phase","settled")
        local center=math.min(155,height*.3)
        Preview.icon(root,item,(width-center)/2,20,center)
        local y=center+26
        local title=W.text(root,"Result",16,y,width-32,34,item.name,24,C.white,Enum.Font.GothamBold)
        title.TextXAlignment=Enum.TextXAlignment.Center
        local detail=W.text(root,"Detail",12,y+38,width-24,44,identity.."  /  "..(receipt.duplicate and ("+"..receipt.shards.." Shards") or "Added to inventory"),16,W.rgb(Catalog.rarityColors[item.rarity]))
        detail.TextXAlignment=Enum.TextXAlignment.Center
        detail.TextWrapped=true;detail.TextTruncate=Enum.TextTruncate.None
        local done=Style.button(root,"Continue",24,y+96,width-48,42,"Continue",true)
        done.Activated:Connect(function() self:hide(); if self.onDone then self.onDone() end end)
        if UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=done end
        return
    end
    local crateIcon=Preview.icon(root,crate,width/2-52,27,104)
    local title=W.text(root,"Title",24,140,width-48,42,"Opening "..crate.name, width<600 and 21 or 29,C.white,Enum.Font.GothamBlack)
    title.TextXAlignment=Enum.TextXAlignment.Center
    local viewport=W.box(root,"ReelViewport",24,220,width-48,178,C.panel,41); viewport.ClipsDescendants=true
    if short then
        crateIcon.Position=UDim2.fromOffset(width/2-42,12); crateIcon.Size=UDim2.fromOffset(84,84)
        title.Position=UDim2.fromOffset(24,102); title.TextSize=22
        viewport.Position=UDim2.fromOffset(24,156)
    end
    Style.round(viewport,10)
    local strip=W.box(viewport,"Reel",0,0,6500,178,nil,42)
    local random=Random.new(); local winner=36; local stride=142
    for i=1,43 do
        local entry=Catalog.byId[Catalog.roll(crate,random:NextNumber())]
        if i==winner then entry=item end
        local card=W.box(strip,"Reward"..i,(i-1)*stride,8,132,162,C.ink,43)
        Style.round(card,8)
        W.box(card,"Rarity",0,156,132,6,W.rgb(Catalog.rarityColors[entry.rarity]),44)
        Preview.icon(card,entry,25,8,82)
        local name=W.text(card,"Name",7,98,118,42,entry.name,16,C.white,Enum.Font.GothamBold)
        name.TextWrapped=true; name.TextTruncate=Enum.TextTruncate.None; name.TextXAlignment=Enum.TextXAlignment.Center
        W.text(card,"RarityName",8,140,116,16,entry.rarity,13,W.rgb(Catalog.rarityColors[entry.rarity]),Enum.Font.GothamBold)
    end
    local topPin=W.box(root,"SelectionPinTop",width/2-3,207,6,18,C.mint,45)
    local bottomPin=W.box(root,"SelectionPinBottom",width/2-3,393,6,18,C.mint,45)
    if short then topPin.Position=UDim2.fromOffset(width/2-3,143); bottomPin.Position=UDim2.fromOffset(width/2-3,329) end
    local result=W.text(root,"Result",24,443,width-48,44,"",width<600 and 24 or 28,C.white,Enum.Font.GothamBlack); result.TextXAlignment=Enum.TextXAlignment.Center
    local detail=W.text(root,"Detail",24,492,width-48,42,"",width<600 and 14 or 17,C.muted); detail.TextXAlignment=Enum.TextXAlignment.Center
    detail.TextWrapped=true; detail.TextTruncate=Enum.TextTruncate.None
    local done=Style.button(root,"Continue",24,554,width-48,50,"Continue",true); done.ZIndex=46; done.Visible=false
    done.Activated:Connect(function() self:hide(); if self.onDone then self.onDone() end end)
    -- Prepare the exact awarded sprite while the reel is still rolling.
    self.unlock=ItemUnlock.new(root,item,function()
        if self.generation~=generation or not self.active then return end
        root:SetAttribute("Phase","settled"); done.Visible=true
        if self.onReady then self.onReady() end
        if UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=done end
    end,height)
    local target=(width-48)/2-((winner-1)*stride+66)
    local function tickAudio()
        self.audio:advance(math.floor(((width-48)/2-strip.Position.X.Offset-66)/stride+.000001))
    end
    tickAudio()
    self.rollConnection=Run.RenderStepped:Connect(tickAudio)
    self.tween=Tween:Create(strip,TweenInfo.new(5.8,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
        {Position=UDim2.fromOffset(target,0)})
    self.tween.Completed:Once(function(state)
        if state~=Enum.PlaybackState.Completed or self.generation~=generation or not self.active then return end
        tickAudio()
        self.rollConnection:Disconnect(); self.rollConnection=nil
        root:SetAttribute("Phase","itemReveal")
        crateIcon.Visible=false; viewport.Visible=false; topPin.Visible=false; bottomPin.Visible=false
        title.Text="ITEM RECEIVED"; title.Position=UDim2.fromOffset(24,short and 4 or 22); title.TextSize=short and 18 or 21
        title.TextColor3=Color3.fromRGB(255,222,91); title.ZIndex=48
        result.Text=item.name; result.TextColor3=W.rgb(Catalog.rarityColors[item.rarity])
        result.Position=UDim2.fromOffset(24,short and height-122 or 478); result.ZIndex=48
        if short then result.TextSize=24 end
        detail.Text=identity.."  /  "..(receipt.duplicate and ("Duplicate converted into +%d Shards"):format(receipt.shards) or "Added to your inventory")
        detail.Position=UDim2.fromOffset(24,short and height-83 or 530); detail.ZIndex=48
        if short then detail.TextSize=14 end
        done.Position=UDim2.fromOffset(24,short and height-40 or 590); done.Size=UDim2.fromOffset(width-48,short and 36 or 44)
        self.unlock:play()
    end)
    self.tween:Play()
end
return Reveal
