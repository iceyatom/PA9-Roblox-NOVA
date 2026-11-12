-- Saved-reward celebration: tokens flip in on NOVA's lift/stamp motion (crates stamp directly).
-- Feedback only. The server has already saved the delivery before this plays.
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local shared=game.ReplicatedStorage.NOVA
local Shop=require(shared.ShopCatalog)
local Art=require(shared.ShopArt)
local Season=require(shared.SeasonOne)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local ItemUnlock=require(script.Parent.ItemUnlock)
local ReelAudio=require(script.Parent.ReelAudio)
local C=W.colors
local gold=Color3.fromRGB(255,222,91)
local impactAt=1.24 -- ItemUnlock's stamp moment
local halfTurns=3
local Reveal={}; Reveal.__index=Reveal
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function reduced() return game.Players.LocalPlayer:GetAttribute("ReducedEffects")==true end
local function centered(parent,name,y,width,height,value,size,color,font)
    local label=W.text(parent,name,24,y,width-48,height,value,size,color,font or Enum.Font.GothamBold)
    label.TextXAlignment=Enum.TextXAlignment.Center; label.TextWrapped=true; label.TextTruncate=Enum.TextTruncate.None
    label.ZIndex=48
    return label
end
function Reveal.still(product) return product.quantity and Season.icon or Art[product.section] end
function Reveal.new(panel,onDone,onViewCrates)
    local self=setmetatable({panel=panel,onDone=onDone,onViewCrates=onViewCrates,generation=0,active=false},Reveal)
    self.stamp=Instance.new("Sound")
    self.stamp.Name="PurchaseStamp"; self.stamp.SoundId=ReelAudio.SoundId; self.stamp.Volume=ReelAudio.Volume
    self.stamp.PlaybackSpeed=.72; self.stamp.Parent=panel
    return self
end
function Reveal:hide()
    self.generation+=1; self.active=false; self.receipt=nil; self.detail=nil
    if self.connection then self.connection:Disconnect(); self.connection=nil end
    if self.unlock then self.unlock:destroy(); self.unlock=nil end
    if self.overlay then self.overlay:Destroy(); self.overlay=nil end
    self.stamp:Stop()
    for object in self.restore or {} do if object.Parent then object.Selectable=true end end
    self.restore=nil
end
-- Token time keeps counting while the reveal is open.
function Reveal:tick(now)
    local receipt=self.receipt
    if not self.detail or not receipt or not receipt.expires then return end
    self.detail.Text=("Active now  /  %s remaining"):format(Shop.clock(receipt.expires-now))
end
-- Optional presentation lets other saved rewards reuse the exact shop effect.
function Reveal:show(receipt,presentation)
    local product=presentation and presentation.product or Shop.byId[receipt.productId]
    if not product then return end
    self:hide(); self.active=true; self.receipt=receipt
    local generation=self.generation
    self.restore={}
    for _,object in self.panel:GetDescendants() do
        if object:IsA("GuiObject") and object.Selectable then self.restore[object]=true; object.Selectable=false end
    end
    Gui.SelectedObject=nil
    local section=Shop.sectionById[product.section]
    local width=self.panel.Size.X.Offset
    local screen=self.panel:FindFirstAncestorWhichIsA("ScreenGui")
    local short=screen~=nil and screen.AbsoluteSize.Y<560
    local height=short and math.max(300,screen.AbsoluteSize.Y-24) or 650
    local root=W.box(self.panel,"ShopReveal",0,0,width,math.max(650,self.panel.Size.Y.Offset),C.ink,40)
    root.Active=true; Style.round(root,12); self.overlay=root
    root:SetAttribute("ContentHeight",height); root:SetAttribute("ProductId",product.id)
    local headline=presentation and presentation.headline or product.quantity and ("%d %s%s"):format(product.quantity,section.unit:upper(),product.quantity==1 and "" or "S")
        or ("%d MINUTES OF %s"):format(product.minutes,section.unit:upper())
    local note=presentation and presentation.note or product.quantity and ("Added to your inventory  /  You now own %s"):format(Shop.commas(receipt.owned or product.quantity)) or ""
    local still=(presentation and presentation.image or Reveal.still(product)) or ""
    local flat=reduced()
    local title=centered(root,"Title",short and 4 or 22,width,short and 28 or 36,presentation and presentation.title or "PURCHASE COMPLETE",presentation and 24 or short and 18 or 21,gold,Enum.Font.GothamBlack)
    local result=centered(root,"Result",short and height-(presentation and 146 or 122) or presentation and 450 or 478,width,presentation and 64 or 40,headline,width<600 and 22 or 28,C.white,Enum.Font.GothamBlack)
    local detail=centered(root,"Detail",short and height-83 or 530,width,40,note,presentation and 19 or width<600 and 14 or 17,C.mint)
    self.detail=detail
    self:tick(workspace:GetServerTimeNow())
    local buttonY,buttonHeight=short and height-40 or 590,short and 36 or 44
    local crates=product.quantity~=nil and self.onViewCrates~=nil
    local buttonWidth=crates and (width-60)/2 or width-48
    local done=Style.button(root,"Continue",crates and 36+buttonWidth or 24,buttonY,buttonWidth,buttonHeight,"Continue",true)
    done.ZIndex=49
    done.Activated:Connect(function() self:hide(); if self.onDone then self.onDone() end end)
    local view
    if crates then
        view=Style.button(root,"ViewCrates",24,buttonY,buttonWidth,buttonHeight,"View crates",false)
        view.ZIndex=49
        view.Activated:Connect(function() self:hide(); self.onViewCrates() end)
        view.NextSelectionRight=done; done.NextSelectionLeft=view
    end
    local function ready()
        if self.generation~=generation or not self.active then return end
        root:SetAttribute("Phase","settled"); done.Visible=true
        if view then view.Visible=true end
        if gamepad() then Gui.SelectedObject=done end
    end
    if flat then
        -- Reduced Effects: the same result without motion.
        local size=math.min(220,height*.38)
        local icon=Instance.new("ImageLabel")
        icon.Name="ReceivedItem"; icon.BackgroundTransparency=1; icon.ScaleType=Enum.ScaleType.Fit; icon.Image=still
        icon.Size=UDim2.fromOffset(size,size); icon.Position=UDim2.fromOffset((width-size)/2,(short and 30 or 110)); icon.ZIndex=45; icon.Parent=root
        if presentation and presentation.item then require(script.Parent.BatchOneVisuals).apply(icon,presentation.item) end
        if not short then
            result.Position=UDim2.fromOffset(24,presentation and 344 or 360); detail.Position=UDim2.fromOffset(24,presentation and 420 or 408)
            done.Position=UDim2.fromOffset(done.Position.X.Offset,474)
            if view then view.Position=UDim2.fromOffset(24,474) end
        end
        title.Visible=true
        ready()
        return
    end
    done.Visible=false
    if view then view.Visible=false end
    root:SetAttribute("Phase","reveal")
    local unlock=ItemUnlock.new(root,presentation and presentation.item or {id=product.id,category="shop",image=still},ready,height)
    self.unlock=unlock
    local sheet=not product.quantity and Art[product.section.."Flip"]
    if sheet then
        local icon=unlock.icon
        local size=Art.flipFrameSize
        icon.Image=sheet; icon.ImageRectSize=Vector2.new(size,size)
        local stamped=false
        -- Three decelerating half turns land face-on exactly as the stamp hits.
        self.connection=Run.RenderStepped:Connect(function()
            local t=os.clock()-unlock.started
            if t>=impactAt then
                icon.Image=still; icon.ImageRectSize=Vector2.zero; icon.ImageRectOffset=Vector2.zero
                self.connection:Disconnect(); self.connection=nil
                if not stamped then stamped=true; self.stamp:Play() end
                return
            end
            local progress=1-(1-math.clamp(t/impactAt,0,1))^1.5
            local frame=math.floor(Art.flipFrames*halfTurns*progress)%Art.flipFrames
            icon.ImageRectOffset=Vector2.new(frame%Art.flipColumns*size,math.floor(frame/Art.flipColumns)*size)
        end)
    else
        task.delay(impactAt,function() if self.generation==generation and self.active then self.stamp:Play() end end)
    end
    unlock:play()
end
-- Daily tokens are stored units, so the reveal must not say their timer is active.
function Reveal:showDaily(reward,data)
    local crates=reward.kind=="crates"
    local pack=reward.kind=="pack"
    local kind=reward.kind
    local name=kind=="xp" and "DOUBLE XP" or "DOUBLE CRATES"
    local headline=pack and "EXCLUSIVE SKIN PACK" or crates and ("%d CRATE%s"):format(reward.quantity,reward.quantity==1 and "" or "S")
        or ("%d × %d MINUTES\n%s"):format(reward.quantity,reward.minutes,name)
    local note=pack and (data.daily.packDelivered and "Your skin pack is in your inventory." or "Pack reserved. Delivered when it releases.")
        or crates and "Added to your inventory." or "Tokens saved. Activate from Class setup."
    local item
    if pack then
        local ids=require(shared.DailyRewards).PackItems
        item=require(shared.InventoryCatalog).byId[ids[1]] or {id="daily_pack_reserved",category="skins",color="b56dff"}
    end
    self:show({dailyDay=reward.day},{product={id="daily:"..reward.day,section=pack and "pack" or kind,
        quantity=crates and reward.quantity or nil,minutes=reward.minutes},
        title=("DAY %d CLAIMED"):format(reward.day),headline=headline,note=note,
        image=crates and Season.icon or Art[kind],item=item})
    if self.overlay then self.overlay:SetAttribute("DailyDay",reward.day) end
end
return Reveal
