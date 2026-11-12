local Run=game:GetService("RunService")
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Shop=require(game.ReplicatedStorage.NOVA.ShopCatalog)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Preview=require(script.Parent.InventoryPreview)
local C=W.colors
local Tokens={};Tokens.__index=Tokens
function Tokens.height(width)
    local columns=width>=850 and 6 or width>=460 and 3 or 2
    return 84+math.ceil(6/columns)*118
end
function Tokens.new(parent,onUse)
    local self=setmetatable({cards={}},Tokens)
    self.root=W.box(parent,"Tokens",0,0,0,0)
    self.heading=W.text(self.root,"Title",0,0,500,26,"YOUR 2× TOKENS",22,C.white,Enum.Font.GothamBlack)
    self.timers=W.text(self.root,"Timers",0,30,800,24,"",16,C.mint,Enum.Font.Gotham)
    self.status=W.text(self.root,"Status",0,56,800,20,"Activate a token to start its timer. Extra tokens add time.",14,C.muted,Enum.Font.Gotham)
    for _,id in Catalog.tokens do
        local item=Catalog.byId[id]
        local card=W.box(self.root,id,0,0,150,110,C.ink);Style.surface(card,8)
        local art=Preview.icon(card,item,8,10,40)
        local name=W.text(card,"Name",54,8,90,26,item.tokenKind=="xp" and "2× XP" or "2× Crates",18,C.white,Enum.Font.GothamBold)
        local count=W.text(card,"Count",54,36,90,24,"",16,W.rgb(Catalog.rarityColors[item.rarity]),Enum.Font.Gotham)
        for _,entry in {{name,18,13},{count,16,12}} do
            entry[1].TextScaled=true
            local limit=Instance.new("UITextSizeConstraint");limit.MaxTextSize=entry[2];limit.MinTextSize=entry[3];limit.Parent=entry[1]
        end
        local use=Style.button(card,"Use",8,66,134,36,"Use token",false);use.TextSize=17
        use.Activated:Connect(function()
            if self.pending or not use.Active then return end
            self.pending=true;self:refresh()
            onUse(id,function(ok,message)
                if not self.root.Parent then return end
                self.pending=false;self.status.Text=ok and "Token activated. Time is added to your active boost." or message or "Please try again."
                self:refresh()
            end)
        end)
        table.insert(self.cards,{item=item,root=card,art=art,name=name,count=count,use=use})
    end
    local elapsed=0
    local connection=Run.Heartbeat:Connect(function(dt)
        elapsed+=dt;if elapsed<1 or not self.root.Visible then return end
        elapsed=0;self:tick()
    end)
    self.root.Destroying:Once(function() connection:Disconnect() end)
    return self
end
function Tokens:tick()
    local now=workspace:GetServerTimeNow()
    local boosts=self.data and self.data.boosts or {}
    local function timer(kind) local left=(boosts[kind] or 0)-now;return left>0 and Shop.clock(left) or "Inactive" end
    self.timers.Text="2× XP: "..timer("xp").."   /   2× Crates: "..timer("crate")
end
function Tokens:refresh()
    for _,card in self.cards do
        local count=self.data and self.data.owned[card.item.id] or 0
        card.count.Text=card.item.minutes.." min  ·  ×"..count
        local owned=count>0
        card.name.TextColor3=owned and C.white or C.muted
        card.count.TextColor3=owned and W.rgb(Catalog.rarityColors[card.item.rarity]) or C.muted
        card.art.ImageColor3=owned and Color3.new(1,1,1) or C.muted
        card.art.ImageTransparency=owned and 0 or .65
        card.root.BackgroundColor3=owned and C.ink or C.ink:Lerp(C.panel,.5)
        card.root:FindFirstChildOfClass("UIStroke").Color=owned and W.rgb(Catalog.rarityColors[card.item.rarity]) or C.line
        card.use.TextColor3=owned and C.white or C.muted
        card.root:SetAttribute("Owned",owned)
        local active=owned and self.ready and not self.pending
        card.use.Active=active;card.use.Selectable=active;card.use.AutoButtonColor=active
        card.use.BackgroundColor3=active and C.purple or C.line
    end
    self:tick()
end
function Tokens:update(data,width,top,visible,ready)
    self.data=data;self.ready=ready;self.root.Visible=visible
    if not visible then return end
    self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(width,Tokens.height(width))
    for _,text in {self.heading,self.timers,self.status} do text.Size=UDim2.fromOffset(width,text.Size.Y.Offset) end
    self.timers.TextSize=width<460 and 13 or 16;self.status.TextSize=width<460 and 11 or 14
    local columns=width>=850 and 6 or width>=460 and 3 or 2
    local cell=(width-(columns-1)*8)/columns
    for index,card in self.cards do
        card.root.Position=UDim2.fromOffset(((index-1)%columns)*(cell+8),84+math.floor((index-1)/columns)*118)
        card.root.Size=UDim2.fromOffset(cell,110)
        card.name.Size=UDim2.fromOffset(cell-60,26)
        card.count.Size=UDim2.fromOffset(cell-60,24)
        card.use.Size=UDim2.fromOffset(cell-16,36)
    end
    self:refresh()
end
return Tokens
