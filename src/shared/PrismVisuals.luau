-- Prism Veil: Blender skin loop + live 2D ribbon/shard/spark geometry.
-- Tracers are updated continuously; no trail animation images are sampled.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Assets=require(script.Parent.PrismAssets)
local Content=game:GetService("ContentProvider")
local Dragon=require(script.Parent.DragonforgeVisuals)
local Rift=require(script.Parent.RiftglassVisuals)
local Cipher=require(script.Parent.CipherVisuals)
local Supernova=require(script.Parent.SupernovaVisuals)
local Starfade=require(script.Parent.StarfadeVisuals)
local V={}
local preloaded={}
function V.preload(item)
    Starfade.preload(item)
    Supernova.preload(item)
    Cipher.preload(item)
    Rift.preload(item)
    Dragon.preload(item)
    if not item or item.visual~="prism_veil" then return end
    local id=item.category=="skins" and Assets.skin or item.category=="bullets" and Assets.bullet or item.category=="backgrounds" and Assets.background
    if not id or id=="" or preloaded[id] then return end
    preloaded[id]=true
    task.spawn(function()
        local loaded=false
        local ok=pcall(function()
            Content:PreloadAsync({id},function(_,status) if status==Enum.AssetFetchStatus.Success then loaded=true end end)
        end)
        if not ok or not loaded then preloaded[id]=nil end
    end)
end
local entries={}; local connection
local palette={Color3.fromHex("f36bea"),Color3.fromHex("5ee9ed"),Color3.fromHex("67f6c0")}
local white=Color3.fromHex("f4f4ff")
local function box(parent,name,color,alpha)
    local f=Instance.new("Frame"); f.Name=name; f.BackgroundColor3=color; f.BackgroundTransparency=alpha or 0
    f.BorderSizePixel=0; f.AnchorPoint=Vector2.new(.5,.5); f.ZIndex=parent.ZIndex; f.Parent=parent; return f
end
local function visible(root)
    local node=root
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("GuiObject") and node.ClipsDescendants then
            local a,b=root.AbsolutePosition,root.AbsoluteSize;local c,d=node.AbsolutePosition,node.AbsoluteSize
            if a.X+b.X<c.X or a.Y+b.Y<c.Y or a.X>c.X+d.X or a.Y>c.Y+d.Y then return false end
        end
        if (node:IsA("ScreenGui") or node:IsA("DockWidgetPluginGui")) and not node.Enabled then return false end
        node=node.Parent
    end
    return root.Parent~=nil and root.AbsoluteSize.X>0 and root.AbsoluteSize.Y>0
end
local function reduced(root)
    local player=Players.LocalPlayer
    return root:GetAttribute("ReducedPrism")==true or player and player:GetAttribute("ReducedEffects")==true
end
local function line(f,x1,y1,x2,y2,width)
    local dx,dy=x2-x1,y2-y1
    f.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2)
    f.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+1,width)
    f.Rotation=math.deg(math.atan2(dy,dx))
end
local function update(e,t,simple)
    local root=e.root
    if e.kind=="skin" then
        local frame=simple and 0 or math.floor(t*8)%16
        if frame~=e.frame then root.ImageRectOffset=Vector2.new(frame%4*256,math.floor(frame/4)*256);e.frame=frame end
    elseif e.kind=="bullet" then
        root.Rotation=simple and 0 or t*180%360
    elseif e.kind=="background" then
        if simple then t=0 end
        local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
        for i,shard in e.shards do
            local phase=t*.24+i*2.4
            shard.Position=UDim2.fromScale((i*.173+.08)%1+.025*math.sin(phase),.15+(i*.137)% .7+.05*math.cos(phase*.8))
            local size=math.clamp(h*(.05+(i%3)*.025),3,22)
            shard.Size=UDim2.fromOffset(size,size);shard.Rotation=45+(simple and 0 or math.sin(phase)*20)
            shard.BackgroundTransparency=.4+.2*math.sin(phase)
        end
        e.sweep.Offset=Vector2.new(simple and 0 or math.sin(t*.45)*.8,0)
    else
        t+=e.seed or 0
        local w=root.AbsoluteSize.X
        local h=math.min(w*.3,math.clamp(math.max(root.AbsoluteSize.Y*1.8,w*.06),12,72))
        local particleScale=math.clamp(w/140,.7,2.5)
        local n=simple and 4 or 8
        for ribbon,segments in e.ribbons do
            for j,parts in segments do
                local enabled=j<=n and (not simple or ribbon==2)
                for _,f in parts do f.Visible=enabled end
                if enabled then
                    local function point(u)
                        return u*w,root.AbsoluteSize.Y/2+math.sin(u*7-t*7+ribbon*2.1)*h*.6*(1-u)+((ribbon-2)*h*.22)*(1-u)
                    end
                    local u=(j-1)/n; local x1,y1=point(u);local x2,y2=point(j/n)
                    local thickness=math.max(1,h*.12*(.2+.8*j/n))
                    line(parts[1],x1,y1,x2,y2,thickness*3.5)
                    line(parts[2],x1,y1,x2,y2,thickness)
                    line(parts[3],x1,y1,x2,y2,math.max(1,thickness*.3))
                    parts[1].BackgroundTransparency=.87+.10*(1-j/n)
                    parts[2].BackgroundTransparency=.08+.7*(1-j/n)
                    parts[3].BackgroundTransparency=.35+.6*(1-j/n)
                end
            end
        end
        for i,shard in e.shards do
            shard.Visible=not simple or i<=2
            local age=(t*(.7+i*.023)+i*.157)%1; local u=1-age
            shard.Position=UDim2.fromOffset(w*u,root.AbsoluteSize.Y/2+math.sin(age*5+i)*h*.7*age)
            local size=(2+(i%3)*1.4)*particleScale*math.sin(math.pi*age)
            shard.Size=UDim2.fromOffset(size,size);shard.Rotation=45+t*(35+i*9)
            shard.BackgroundTransparency=.15+age*.7
        end
        for i,spark in e.sparks do
            spark.Visible=not simple or i<=3
            local age=(t*(1.1+i*.019)+i*.093)%1
            spark.Position=UDim2.fromOffset(w*(1-age),root.AbsoluteSize.Y/2+math.sin(i*1.9+age*4)*h*.85*age)
            local size=math.max(1,(3+i%2)*particleScale*math.sin(math.pi*age))
            spark.Size=UDim2.fromOffset(size,size);spark.Rotation=t*50+i*30
            spark.BackgroundTransparency=age*.85
        end
    end
end
local function start()
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local t=os.clock();local trails=0
        for root,e in entries do
            if not root.Parent then entries[root]=nil
            elseif visible(root) then
                local simple=reduced(root) or e.compact
                if e.kind=="tracer" then trails+=1; simple=simple or trails>12 end
                update(e,t,simple)
            end
        end
        if not next(entries) then connection:Disconnect();connection=nil end
    end)
end
function V.clear(root)
    Starfade.clear(root)
    Supernova.clear(root)
    Cipher.clear(root)
    Rift.clear(root)
    Dragon.clear(root)
    if not root:GetAttribute("PrismVeil") then return end
    local old=entries[root]
    if old and old.destroyConnection then old.destroyConnection:Disconnect() end
    if old and old.kind=="bullet" then root.Rotation=0 end
    entries[root]=nil
    local effects=root:FindFirstChild("PrismEffects"); if effects then effects:Destroy() end
    local sweep=root:FindFirstChild("PrismSweep");if sweep then sweep:Destroy() end
    root:SetAttribute("PrismVeil",nil)
end
function V.apply(root,item,kind)
    if type(item)=="table" and item.visual=="starfade" then
        if root:GetAttribute("PrismVeil") or root:GetAttribute("Dragonforge") or root:GetAttribute("Riftglass") or root:GetAttribute("Cipher") or root:GetAttribute("Supernova") then V.clear(root) end
        return Starfade.apply(root,item)
    end
    if root:GetAttribute("Starfade") then Starfade.clear(root) end
    if type(item)=="table" and item.visual=="supernova" then
        if root:GetAttribute("PrismVeil") or root:GetAttribute("Dragonforge") or root:GetAttribute("Riftglass") or root:GetAttribute("Cipher") then V.clear(root) end
        return Supernova.apply(root,item)
    end
    if root:GetAttribute("Supernova") then Supernova.clear(root) end
    if type(item)=="table" and item.visual=="cipher" then
        if root:GetAttribute("PrismVeil") or root:GetAttribute("Dragonforge") or root:GetAttribute("Riftglass") then V.clear(root) end
        return Cipher.apply(root,item)
    end
    if root:GetAttribute("Cipher") then Cipher.clear(root) end
    if type(item)=="table" and item.visual=="riftglass" then
        if root:GetAttribute("PrismVeil") or root:GetAttribute("Dragonforge") then V.clear(root) end
        return Rift.apply(root,item)
    end
    if type(item)=="table" and item.visual=="dragonforge" then
        if root:GetAttribute("PrismVeil") or root:GetAttribute("Riftglass") then V.clear(root) end
        return Dragon.apply(root,item)
    end
    if item.visual~="prism_veil" then return false end
    kind=kind or item.category
    if root:GetAttribute("PrismVeil")==kind then return true end
    V.clear(root);root:SetAttribute("PrismVeil",kind)
    root.ScaleType=item.category=="backgrounds" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
    root.Image="";root.ImageRectOffset=Vector2.zero;root.ImageRectSize=Vector2.zero;root.BackgroundTransparency=1
    local e={root=root,shards={},sparks={},ribbons={},seed=math.random()*6.283}
    if item.category=="skins" then
        root:SetAttribute("SquareSkin",true);root:SetAttribute("SolidSkin",false)
        root.Image=Assets.skin;root.ImageRectSize=Vector2.new(256,256);e.kind="skin"
    elseif item.category=="bullets" then root.Image=Assets.bullet;e.kind="bullet"
    elseif item.category=="backgrounds" then
        root.Image=Assets.background;e.kind="background"
        local sweep=Instance.new("UIGradient");sweep.Name="PrismSweep";sweep.Rotation=20
        sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(190,210,255)),ColorSequenceKeypoint.new(.5,white),ColorSequenceKeypoint.new(1,Color3.fromRGB(225,195,255))})
        sweep.Parent=root;e.sweep=sweep
    else e.kind="tracer" end
    if e.kind=="tracer" then
        local count=0
        for other,entry in entries do if entry.kind=="tracer" and visible(other) then count+=1 end end
        e.compact=reduced(root) or count>=12
    end
    if e.kind=="tracer" or e.kind=="background" then
        local effects=box(root,"PrismEffects",white,1);effects.AnchorPoint=Vector2.zero;effects.Size=UDim2.fromScale(1,1)
        effects.ClipsDescendants=e.kind=="background"
        if e.kind=="tracer" then
            for _,r in e.compact and {2} or {1,2,3} do e.ribbons[r]={}
                for j=1,e.compact and 4 or 8 do
                    e.ribbons[r][j]={box(effects,"RibbonGlow",palette[r],.9),box(effects,"FlowingRibbon",palette[r]),box(effects,"WhiteHotCore",white,.2)}
                    for _,f in e.ribbons[r][j] do local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=f end
                end
            end
            for i=1,e.compact and 3 or 10 do e.sparks[i]=box(effects,"DriftingSpark",white) end
        end
        for i=1,e.kind=="background" and 9 or e.compact and 2 or 7 do
            local shard=box(effects,"FlowingGlassShard",palette[(i-1)%3+1],.3)
            local facet=box(shard,"PearlFacet",white,.15);facet.AnchorPoint=Vector2.zero;facet.Size=UDim2.fromScale(.45,1)
            e.shards[i]=shard
        end
    end
    entries[root]=e
    e.destroyConnection=root.Destroying:Once(function() entries[root]=nil end)
    update(e,os.clock(),reduced(root) or e.compact);start()
    return true
end
return V
