local Tween=game:GetService("TweenService")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Players=game:GetService("Players")
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Preview=require(script.Parent.InventoryPreview)
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Policy=require(game.ReplicatedStorage.NOVA.CrateDrop)
local C=W.colors
local Chance={};Chance.__index=Chance
local function percent(n) return ("%.2f"):format(n):gsub("0+$",""):gsub("%.$","").."%" end
local function gamepad() return UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" end
local function reduced() return Players.LocalPlayer:GetAttribute("ReducedEffects")==true end
local function centerText(parent,name,y,w,h,value,size,color)
    local text=W.text(parent,name,(560-w)/2,y,w,h,value,size,color,Enum.Font.GothamBold)
    text.TextXAlignment=Enum.TextXAlignment.Center;text.TextWrapped=true;text.TextTruncate=Enum.TextTruncate.None
    return text
end
function Chance.new(gui,onDismiss,stage)
    local self=setmetatable({tweens={},segments={},generation=0,onDismiss=onDismiss,docked=stage~=nil},Chance)
    local root=W.box(stage or gui,"CrateChance",0,0,0,0,C.ink,60);root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=stage and 1 or .12;root.Active=not stage;root.Visible=false;self.root=root
    local origin=W.box(root,"Origin",0,0,0,0);origin.Position=UDim2.fromScale(.5,.5)
    self.origin=origin
    local fit=Instance.new("UIScale");fit.Parent=origin;self.fit=fit
    local panel=W.box(origin,"Panel",0,0,560,620,C.panel);panel.AnchorPoint=Vector2.new(.5,.5);Style.surface(panel,16);self.panel=panel
    self.pop=Instance.new("UIScale");self.pop.Parent=panel
    local function resize() fit.Scale=stage and .72 or math.max(.01,math.min(1.1,(root.AbsoluteSize.X-24)/560,(root.AbsoluteSize.Y-24)/620)) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
    centerText(panel,"Title",20,424,38,"Season 1 Crate",29,C.white).Font=Enum.Font.GothamBlack
    self.kicker=centerText(panel,"Kicker",65,480,26,"VICTORY ROLL",17,C.mint)
    local close=Style.button(panel,"Close",500,14,44,40,"×",false);self.closeButton=close
    close.Activated:Connect(function() self:dismiss() end)
    local halo=W.box(panel,"Halo",280,265,286,286,C.mint);halo.AnchorPoint=Vector2.new(.5,.5);halo.BackgroundTransparency=.96;W.round(halo);self.halo=halo
    local outline=W.box(panel,"Outline",280,265,284,284,nil);outline.AnchorPoint=Vector2.new(.5,.5);W.round(outline);W.stroke(outline,C.line,1)
    for i=1,180 do
        local angle=(i-.5)*2;local rad=math.rad(angle)
        local track=W.box(panel,"Track"..i,280+128*math.sin(rad),265-128*math.cos(rad),5.6,12,C.line)
        track.AnchorPoint=Vector2.new(.5,.5);track.Rotation=angle;Style.round(track,2)
        local fill=W.box(panel,"Fill"..i,0,0,5.6,12,C.mint,3);fill.AnchorPoint=Vector2.new(.5,.5);Style.round(fill,2)
        self.segments[i]=fill
    end
    self.icon=Preview.icon(panel,Catalog.byId.crate_season1,200,185,160)
    local rotor=W.box(panel,"ArrowRotor",280,265,296,296,nil,5);rotor.AnchorPoint=Vector2.new(.5,.5);self.rotor=rotor
    self.arrow=W.text(rotor,"Arrow",135,-20,26,30,"▼",28,C.white,Enum.Font.GothamBlack);self.arrow.TextXAlignment=Enum.TextXAlignment.Center;self.arrow.ZIndex=5
    self.amount=centerText(panel,"Chance",416,480,48,"25%",40,C.white)
    self.caption=centerText(panel,"Caption",466,488,24,"CHANCE ON THIS WIN",16,C.muted)
    self.detail=centerText(panel,"Detail",497,480,43,"Waiting for your saved result…",16,C.muted)
    self.openButton=Style.button(panel,"OpenNow",36,556,238,44,"Open now",true)
    self.continueButton=Style.button(panel,"SaveLater",286,556,238,44,"Save for later",false)
    self.continueButton.Activated:Connect(function() self:dismiss() end)
    self.fill=Instance.new("NumberValue");self.fill.Name="DisplayedChance";self.fill.Parent=root
    self.fill.Changed:Connect(function(value)
        for i,segment in self.segments do
            local fraction=math.clamp(value/100*180-i+1,0,1)
            segment.Visible=fraction>0
            local angle=(i-1+fraction/2)*2;local rad=math.rad(angle)
            segment.Position=UDim2.fromOffset(280+128*math.sin(rad),265-128*math.cos(rad))
            segment.Size=UDim2.fromOffset(4.47*fraction+.6,12);segment.Rotation=angle
        end
        if self.showPercent then self.amount.Text=percent(value) end
    end)
    CAS:BindActionAtPriority("NOVA_CrateChanceClose",function(_,state)
        if not root.Visible or not gui.Enabled then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then self:dismiss() end
        return Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+55,Enum.KeyCode.ButtonB)
    Gui:GetPropertyChangedSignal("SelectedObject"):Connect(function()
        local selected=Gui.SelectedObject
        if not self.docked and root.Visible and gui.Enabled and not Gui.MenuIsOpen and selected and not selected:IsDescendantOf(root) then
            Gui.SelectedObject=self.settled and self.continueButton or close
        end
    end)
    return self
end
function Chance:tween(object,duration,properties,style)
    local tween=Tween:Create(object,TweenInfo.new(duration,style or Enum.EasingStyle.Quint,Enum.EasingDirection.Out),properties)
    table.insert(self.tweens,tween);tween:Play();return tween
end
function Chance:hide()
    self.generation+=1
    for _,tween in self.tweens do tween:Cancel() end
    self.tweens={};self.root.Visible=false;self.settled=false
    self.root:SetAttribute("AnimationComplete",false)
end
function Chance:dismiss()
    self.dismissed=self.key;self:hide();if self.onDismiss then self.onDismiss() end
end
function Chance:finish(receipt,generation)
    if generation~=self.generation or not self.root.Visible then return end
    local won=receipt.awarded
    self.root:SetAttribute("Outcome",won and "earned" or receipt.outcome=="win" and "miss" or "boost")
    self.arrow.TextColor3=won and C.mint or C.red
    self.showPercent=not won
    if won then
        -- A Double Crates token active at the win pays two crates (receipt.crates==2).
        local doubled=receipt.crates==2
        self.kicker.Text=doubled and "DOUBLE CRATES UNLOCKED!" or "CRATE UNLOCKED!";self.kicker.TextColor3=C.mint
        self.amount.Text=doubled and "+2 CRATES" or "+1 CRATE"
        self.caption.Text=doubled and "DOUBLE CRATES TOKEN APPLIED" or "ADDED TO YOUR INVENTORY"
        self.detail.Text="Next win starts at "..percent(receipt.nextChance).."."
        self:tween(self.fill,reduced() and 0 or .45,{Value=100})
        self:tween(self.icon,reduced() and 0 or .45,{Size=UDim2.fromOffset(184,184),Position=UDim2.fromOffset(188,173)},Enum.EasingStyle.Back)
        self:tween(self.halo,reduced() and 0 or .35,{BackgroundTransparency=.86})
    else
        self.kicker.Text=receipt.outcome=="loss" and "CHANCE INCREASED" or "NO CRATE THIS TIME"
        self.kicker.TextColor3=receipt.outcome=="loss" and C.mint or C.red
        self.caption.Text="CHANCE ON YOUR NEXT WIN"
        local multiplier=receipt.outcome=="loss" and Policy.LossMultiplier or Policy.WinMultiplier
        self.detail.Text=percent(receipt.chance).." × "..multiplier.." → "..percent(receipt.nextChance)
        if receipt.chance==100 then self.detail.Text="Your next win is guaranteed a crate." end
        self.arrow.TextTransparency=.65
        self:tween(self.fill,reduced() and 0 or .8,{Value=receipt.nextChance})
    end
    self.settled=true;self.root:SetAttribute("AnimationComplete",true);self.root:SetAttribute("Phase","settled")
    self.openButton.Visible=won;self.openButton.Active=won;self.openButton.Selectable=won
    self.continueButton.Visible=true;self.continueButton.Text=won and "Save for later" or "Continue"
    self.continueButton.Position=UDim2.fromOffset(won and 286 or 36,556)
    self.continueButton.Size=UDim2.fromOffset(won and 238 or 488,44)
    if gamepad() and not self.docked then Gui.SelectedObject=self.continueButton end
end
function Chance:update(result,ready)
    if not result or self.dismissed==result.key then if self.root.Visible then self:hide() end;return end
    if not ready then return end
    if self.key~=result.key then
        self:hide();self.key=result.key;self.started=false;self.settled=false;self.showPercent=true
        self.root:SetAttribute("AnimationComplete",false);self.root:SetAttribute("Phase","saving");self.root:SetAttribute("ResultKey",result.key)
        self.root:SetAttribute("Outcome",nil)
        self.icon.Size=UDim2.fromOffset(160,160);self.icon.Position=UDim2.fromOffset(200,185)
        self.halo.BackgroundTransparency=.96;self.arrow.TextTransparency=0;self.arrow.TextColor3=C.white
        self.rotor.Rotation=0;self.rotor.Visible=result.outcome=="win"
        self.kicker.Text=result.outcome=="win" and "VICTORY ROLL" or "DEFEAT BONUS";self.kicker.TextColor3=C.mint
        self.caption.Text=result.outcome=="win" and "CHANCE ON THIS WIN" or "SAVED CRATE CHANCE"
        self.detail.Text="Saving your match reward…";self.amount.Text=percent(result.chance or Policy.BaseChance)
        self.fill.Value=-1;self.fill.Value=result.chance or Policy.BaseChance
        self.openButton.Visible=false;self.openButton.Active=false;self.openButton.Selectable=false;self.continueButton.Visible=false
        self.root.Visible=true;self.pop.Scale=reduced() and 1 or .88
        self:tween(self.pop,reduced() and 0 or .28,{Scale=1},Enum.EasingStyle.Back)
        if gamepad() and not self.docked then Gui.SelectedObject=self.closeButton end
    end
    local receipt=result.receipt
    if receipt and not self.started then
        self.started=true;self.fill.Value=receipt.chance;self.amount.Text=percent(receipt.chance)
        local generation=self.generation
        if receipt.outcome=="win" then
            self.root:SetAttribute("Phase","spinning");self.detail.Text="Land on the lit arc to unlock a crate."
            local target=4*360+receipt.landing*360
            if reduced() then self.rotor.Rotation=target;self:finish(receipt,generation)
            else
                self:tween(self.rotor,4.2,{Rotation=target}).Completed:Once(function(state)
                    if state==Enum.PlaybackState.Completed then self:finish(receipt,generation) end
                end)
            end
        else self.rotor.Visible=false;self:finish(receipt,generation) end
    elseif not receipt then self.detail.Text=result.status..". Your reward will update when saved." end
end
return Chance
