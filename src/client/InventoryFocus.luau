local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Preview=require(script.Parent.InventoryPreview)
local Batch=require(script.Parent.BatchOneVisuals)
local Run=game:GetService("RunService")
local Gui=game:GetService("GuiService")
local Focus={}
Focus.__index=Focus
function Focus.new(gui,onClose)
    return setmetatable({gui=gui,onClose=onClose},Focus)
end
function Focus:hide()
    if self.connection then self.connection:Disconnect(); self.connection=nil end
    if self.sizeConnection then self.sizeConnection:Disconnect(); self.sizeConnection=nil end
    if self.root then
        local root=self.root; self.root=nil
        Preview.stopSounds(root); root:Destroy()
    end
end
function Focus:show(item,equipped,owned)
    self:hide()
    local root=W.box(self.gui,"FocusedPreview",0,0,0,0,W.colors.ink,60)
    root.Size=UDim2.fromScale(1,1); root.BackgroundTransparency=.08; root.Active=true
    self.root=root
    local panel=W.box(root,"Panel",0,0,680,540,W.colors.panel)
    panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5)
    Style.surface(panel,12)
    local scale=Instance.new("UIScale"); scale.Parent=panel
    local function resize() scale.Scale=math.min(1.2,(root.AbsoluteSize.X-24)/680,(root.AbsoluteSize.Y-24)/540) end
    self.sizeConnection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
    local name=W.text(panel,"Name",24,20,536,40,item.name,28,W.colors.white,Enum.Font.GothamBold)
    name.TextScaled=true
    local limit=Instance.new("UITextSizeConstraint"); limit.MaxTextSize=28; limit.MinTextSize=14; limit.Parent=name
    W.text(panel,"Ownership",24,65,620,24,(owned and "Unlocked" or "Locked").."  /  "..item.rarity..(item.setName and "  /  "..item.setName or ""),16,W.colors.muted)
    local trailPreview=item.category=="tracers"
    if not trailPreview then Preview.icon(panel,item,24,110,224) end
    local context=W.box(panel,"Context",trailPreview and 24 or 264,110,trailPreview and 632 or 392,224,W.colors.ink)
    context.ClipsDescendants=true
    Style.round(context,10)
    Preview.draw(context,item,equipped,true)
    local description=W.text(panel,"Description",24,356,632,88,item.description,19,W.colors.white)
    description.TextWrapped=true; description.TextTruncate=Enum.TextTruncate.None
    if item.category=="sounds" then
        local audition=Style.button(panel,"Audition",24,462,400,48,"Play sound",true)
        audition.Activated:Connect(function() Preview.sound(root,item) end)
    end
    local close=Style.button(panel,"ClosePreview",448,462,208,48,"Back",false)
    close.Activated:Connect(function() self:hide(); self.onClose() end)
    if game:GetService("UserInputService"):GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=close end
    self.connection=Run.RenderStepped:Connect(function()
        if Batch.reduced() then return end
        local tracer=context:FindFirstChild("TracerPreview")
        local art=tracer and tracer:FindFirstChild("BatchArt")
        if art and item.category=="tracers" then Batch.apply(art,item,"wakes",math.floor(os.clock()*18)%item.frames) end
    end)
end
return Focus
