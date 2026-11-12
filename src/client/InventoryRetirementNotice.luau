-- A persisted server notice: dismissing acknowledges it, never grants currency.
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local Notice={}; Notice.__index=Notice
function Notice.new(gui,dismiss)
    local self=setmetatable({dismiss=dismiss},Notice)
    local root=W.box(gui,"RetiredItemsNotice",0,0,0,0,W.colors.ink,80)
    root.Size=UDim2.fromScale(1,1); root.BackgroundTransparency=.08; root.Active=true; root.Visible=false
    self.root=root
    local panel=W.box(root,"Panel",0,0,660,540,W.colors.panel)
    panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); Style.surface(panel,12)
    local scale=Instance.new("UIScale"); scale.Parent=panel
    local function resize() scale.Scale=math.min(1,(root.AbsoluteSize.X-24)/660,(root.AbsoluteSize.Y-24)/540) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
    W.text(panel,"Title",24,20,612,40,"Inventory updated",28,W.colors.white,Enum.Font.GothamBold)
    local help=W.text(panel,"Message",24,70,612,68,
        "These items are no longer available. They were removed from your inventory and exchanged for Shards. Equipped items return to defaults.",18,W.colors.muted,Enum.Font.Gotham)
    help.TextWrapped=true; help.TextTruncate=Enum.TextTruncate.None
    self.total=W.text(panel,"Total",24,144,612,34,"",23,W.colors.mint,Enum.Font.GothamBold)
    local rows=Instance.new("ScrollingFrame"); rows.Name="RemovedItems"; rows.BackgroundColor3=W.colors.ink
    rows.BorderSizePixel=0; rows.Position=UDim2.fromOffset(24,190); rows.Size=UDim2.fromOffset(612,230)
    rows.CanvasSize=UDim2.new(); rows.AutomaticCanvasSize=Enum.AutomaticSize.Y; rows.ScrollBarThickness=6
    rows.ScrollBarImageColor3=W.colors.purple; rows.ScrollingDirection=Enum.ScrollingDirection.Y; rows.Parent=panel
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,6); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=rows
    self.rows=rows
    self.message=W.text(panel,"Status",24,430,612,28,"",16,W.colors.red,Enum.Font.Gotham)
    self.button=Style.button(panel,"Dismiss",24,472,612,44,"Got it",true)
    self.button.Activated:Connect(function()
        if self.busy or not self.data then return end
        self.busy=true; self.button.Text="Saving…"; self.button.Active=false
        local sequence=self.data.sequence
        self.dismiss(sequence,function(ok,message)
            if not self.data or self.data.sequence~=sequence then return end
            self.busy=false; self.button.Text="Got it"; self.button.Active=true
            self.message.Text=ok and "" or message or "Could not save. Please try again."
        end)
    end)
    return self
end
function Notice:update(data,visible)
    if not data then self.data=nil; self.root.Visible=false; return end
    if not self.data or data.sequence~=self.data.sequence then
        for _,row in self.rows:GetChildren() do if row:IsA("GuiObject") then row:Destroy() end end
        for i,item in data.items do
            local row=W.box(self.rows,item.id,0,0,600,66,W.colors.panel); row.LayoutOrder=i
            local name=W.text(row,"Name",12,4,410,34,item.name,19,W.colors.white,Enum.Font.GothamBold)
            name.TextWrapped=true
            W.text(row,"Rarity",12,40,410,22,("%s  ×%d"):format(item.rarity,item.quantity),16,W.colors.muted,Enum.Font.Gotham)
            local shards=W.text(row,"Shards",430,0,156,66,("+%d Shards"):format(item.shards),18,W.colors.mint,Enum.Font.GothamBold)
            shards.TextXAlignment=Enum.TextXAlignment.Right; shards.TextWrapped=true
        end
        self.rows.CanvasPosition=Vector2.zero; self.busy=false; self.button.Active=true; self.button.Text="Got it"; self.message.Text=""
        self.total.Text=("%d Shards credited to your inventory"):format(data.totalShards)
    end
    self.data=data
    local showing=visible and not self.root.Visible
    self.root.Visible=visible
    if showing and UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=self.button end
end
return Notice
