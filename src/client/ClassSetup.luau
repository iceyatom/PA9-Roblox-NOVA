local Players=game:GetService("Players")
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local Preview=require(script.Parent.InventoryPreview)
local Batch=require(script.Parent.BatchOneVisuals)
local RankIcon=require(script.Parent.RankIcon)
local Tokens=require(script.Parent.ClassTokens)
local C=W.colors
local Setup={};Setup.__index=Setup
local function label(parent,name,text,size,color)
    local l=W.text(parent,name,0,0,0,24,text,size,color,Enum.Font.GothamBold)
    l.TextXAlignment=Enum.TextXAlignment.Center
    return l
end
local function rect(object,x,y,width,height)
    object.Position=UDim2.fromOffset(x,y);object.Size=UDim2.fromOffset(width,height)
end
function Setup.height(width) return (width<460 and 760 or 474)+16+Tokens.height(width) end
function Setup.new(panel,onUse)
    local self=setmetatable({slots={}},Setup)
    self.root=W.box(panel,"ClassSetup",24,152,992,474);self.root.Visible=false
    self.hero=W.box(self.root,"PlayerCard",0,0,640,138,C.ink);Style.round(self.hero,10)
    self.hero.ClipsDescendants=true
    local background=W.box(self.hero,"Background",0,0,640,138)
    local avatar=Instance.new("ImageLabel");avatar.Name="Portrait";avatar.BackgroundTransparency=1;avatar.ZIndex=3;avatar.Parent=self.hero
    require(script.Parent.Portrait).set(avatar,Players.LocalPlayer.UserId);self.avatar=avatar
    self.playerName=label(self.hero,"PlayerName",Players.LocalPlayer.DisplayName,24,C.white)
    self.playerName.TextXAlignment=Enum.TextXAlignment.Left
    self.playerName.TextScaled=true
    local limit=Instance.new("UITextSizeConstraint");limit.MinTextSize=12;limit.MaxTextSize=24;limit.Parent=self.playerName
    self.level=label(self.hero,"Level","",16,C.white);self.level.TextXAlignment=Enum.TextXAlignment.Left
    self.rank=RankIcon.new(self.hero,"PrestigeIcon",0,0,76)
    local backgroundName=label(self.root,"BackgroundName","",12,C.muted)
    table.insert(self.slots,{category="backgrounds",art=background,name=backgroundName})
    for _,entry in {{"skins","SKIN"},{"bullets","BULLET SKIN"},{"tracers","TRACER"},{"sounds","SOUND EFFECTS"}} do
        local group=W.box(self.root,entry[1],0,0,240,220)
        local art=W.box(group,"Preview",0,0,240,154)
        local title=label(group,"Type",entry[2],11,C.muted)
        local name=label(group,"ItemName","",16,C.white)
        local tier=label(group,"Rarity","",11,C.muted)
        table.insert(self.slots,{category=entry[1],card=group,art=art,title=title,name=name,tier=tier})
    end
    self.tokens=Tokens.new(self.root,onUse)
    return self
end
function Setup:update(data,width,top,visible,ready)
    self.root.Visible=visible
    self.tokens:update(data,width,(width<460 and 760 or 474)+16,visible,ready)
    if not visible then
        for _,slot in self.slots do
            Batch.clear(slot.art)
            for _,child in slot.art:GetChildren() do child:Destroy() end
            slot.key=nil
        end
        return
    end
    local player=Players.LocalPlayer
    local level,prestige,master=player:GetAttribute("Level"),player:GetAttribute("Prestige"),player:GetAttribute("PrestigeMaster")
    local rankName=master and "Prestige Master" or prestige and ("Prestige "..prestige) or ""
    self.level.Text=(level and ("Level "..level) or "Loading level…")..(rankName~="" and ("  ·  "..rankName) or "")
    self.playerName.Text=player.DisplayName
    RankIcon.set(self.rank,prestige~=nil and {prestige=prestige,master=master} or nil)
    self.root.Position=UDim2.fromOffset(24,top)
    self.root.Size=UDim2.fromOffset(width,Setup.height(width))
    local heroWidth=math.min(640,width)
    rect(self.hero,(width-heroWidth)/2,0,heroWidth,138)
    local narrow=width<460
    local avatarSize=narrow and 48 or 72
    rect(self.avatar,18,narrow and 22 or 33,avatarSize,avatarSize)
    local nameX=narrow and 78 or 108
    rect(self.playerName,nameX,30,heroWidth-nameX-90,34)
    rect(self.level,narrow and 18 or nameX,narrow and 94 or 74,heroWidth-(narrow and 36 or nameX+90),26)
    self.level.TextSize=narrow and 13 or 16
    rect(self.rank,heroWidth-82,28,68,68)
    local frames
    if narrow then
        frames={skins={0,184,width/2-8,216},bullets={width/2+8,184,width/2-8,216},tracers={0,410,width,216},sounds={0,654,width,88}}
    else
        local left=math.floor(width*.23);local middle=math.floor(width*.22)
        frames={skins={0,184,left,224},bullets={left+16,184,middle,224},tracers={left+middle+32,184,width-left-middle-32,224},sounds={(width-math.min(520,width))/2,426,math.min(520,width),44}}
    end
    for _,slot in self.slots do
        local item=Catalog.get(data and data.equipped,slot.category)
        local color=W.rgb(Catalog.rarityColors[item.rarity])
        local artWidth,artHeight
        if slot.category=="backgrounds" then
            rect(slot.art,0,0,heroWidth,138)
            rect(slot.name,0,146,width,22)
            slot.name.Text="PLAYER BACKGROUND  /  "..(data and item.name or "Loading…")
            slot.name.TextColor3=color
            artWidth,artHeight=heroWidth,138
        else
            local f=frames[slot.category];rect(slot.card,unpack(f))
            local sound=slot.category=="sounds"
            artWidth,artHeight=sound and 44 or f[3],sound and 44 or 154
            rect(slot.art,0,0,artWidth,artHeight)
            rect(slot.title,sound and 58 or 0,sound and 0 or 158,sound and f[3]-58 or f[3],18)
            rect(slot.name,sound and 58 or 0,sound and 20 or 180,sound and f[3]-58 or f[3],24)
            rect(slot.tier,0,204,f[3],18);slot.tier.Visible=not sound
            slot.name.Text=data and item.name or "Loading equipment…"
            slot.tier.Text=data and item.rarity or "";slot.tier.TextColor3=color
            if sound then slot.name.TextXAlignment=Enum.TextXAlignment.Left;slot.title.TextXAlignment=Enum.TextXAlignment.Left end
        end
        local key=item.id..":"..artWidth..":"..artHeight..":"..tostring(player:GetAttribute("ReducedEffects"))
        if slot.key~=key then
            Batch.clear(slot.art)
            for _,child in slot.art:GetChildren() do child:Destroy() end
            if slot.category=="backgrounds" then
                slot.art.BackgroundColor3=Preview.color(item);slot.art.BackgroundTransparency=0
                local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new(Preview.color(item),C.ink);gradient.Rotation=25;gradient.Parent=slot.art
                Batch.card(slot.art,item)
                local shade=W.box(slot.art,"Readability",0,0,artWidth,artHeight,C.ink,2);shade.BackgroundTransparency=.55
            elseif slot.category=="skins" or slot.category=="bullets" then
                local size=math.min(slot.category=="skins" and 136 or 88,artWidth*.8)
                local core=W.box(slot.art,"EquippedVisual",(artWidth-size)/2,(artHeight-size)/2,size,size,Preview.color(item))
                if slot.category=="bullets" then W.round(core) end
                Batch.overlay(core,item,slot.category)
            elseif slot.category=="sounds" then Preview.icon(slot.art,item,0,0,44)
            else Preview.draw(slot.art,item,data and data.equipped,true) end
            slot.key=key
        end
    end
end
return Setup
