-- Blender sprite loops + continuously moving native UI VFX for NOVA's 2D arena.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local Assets=require(script.Parent.RiftglassAssets)
local V={};local entries={};local connection;local preloaded={}
local colors={Color3.fromHex("b389ff"),Color3.fromHex("7764b0"),Color3.fromHex("ded5ff")}
local white=Color3.fromHex("ecf7ff")
function V.preload(item)
    if not item or item.visual~="riftglass" then return end
    local id=item.category=="skins" and Assets.skin or item.category=="bullets" and Assets.bullet or item.category=="backgrounds" and Assets.background
    if not id or id=="" or preloaded[id] then return end
    preloaded[id]=true
    task.spawn(function()
        local loaded=false
        local ok=pcall(function() Content:PreloadAsync({id},function(_,status) if status==Enum.AssetFetchStatus.Success then loaded=true end end) end)
        if not ok or not loaded then preloaded[id]=nil end
    end)
end
local function visible(root)
    if not root.Parent or root.AbsoluteSize.X<=0 or root.AbsoluteSize.Y<=0 then return false end
    local node=root
    while node do
        if node:IsA("GuiObject") then
            if not node.Visible then return false end
            if node.ClipsDescendants then
                local a,b=root.AbsolutePosition,root.AbsoluteSize;local c,d=node.AbsolutePosition,node.AbsoluteSize
                if a.X+b.X<c.X or a.Y+b.Y<c.Y or a.X>c.X+d.X or a.Y>c.Y+d.Y then return false end
            end
        elseif (node:IsA("ScreenGui") or node:IsA("DockWidgetPluginGui")) and not node.Enabled then return false end
        node=node.Parent
    end
    return true
end
local function reduced(root)
    local p=Players.LocalPlayer
    return root:GetAttribute("ReducedPrism")==true or p and p:GetAttribute("ReducedEffects")==true
end
local function box(parent,name,color,alpha)
    local f=Instance.new("Frame");f.Name=name;f.BorderSizePixel=0;f.AnchorPoint=Vector2.new(.5,.5)
    f.BackgroundColor3=color;f.BackgroundTransparency=alpha or 0;f.ZIndex=parent.ZIndex;f.Parent=parent;return f
end
local function line(f,x1,y1,x2,y2,width)
    local dx,dy=x2-x1,y2-y1
    f.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2)
    f.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+.5,width);f.Rotation=math.deg(math.atan2(dy,dx))
end
local function update(e,t,simple)
    local root=e.root
    if e.kind=="skins" or e.kind=="bullets" then
        local f=simple and 0 or math.floor(t*8)%16
        if e.frame~=f then root.ImageRectOffset=Vector2.new(f%4*256,math.floor(f/4)*256);e.frame=f end
        return
    end
    t=(simple and 0 or t)+e.seed
    local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
    local bg=e.kind=="backgrounds"
    local spread=bg and math.min(h*.08,15) or math.min(w*.17,math.clamp(h*2,10,60))
    local n=simple and 6 or 12
    for r,segs in e.ribbons do
        for j,parts in segs do
            local enabled=j<=n and (bg or not simple or r==2)
            for _,f in parts do f.Visible=enabled end
            if enabled then
                local function point(u)
                    local wave=math.sin(u*31-t*4+r*1.7)*.65+math.sin(u*53+t*3+r)*.25
                    local base=bg and (r==1 and h*.12 or h*.88) or h/2
                    return u*w,base+wave*spread*(bg and 1 or 1-u)
                end
                local x1,y1=point((j-1)/n);local x2,y2=point(j/n)
                local thick=bg and 1 or math.max(.7,spread*.045*(.3+.7*j/n))
                line(parts[1],x1,y1,x2,y2,thick*5)
                line(parts[2],x1,y1,x2,y2,thick)
                parts[1].BackgroundTransparency=.93
                parts[2].BackgroundTransparency=bg and .45 or .1+.65*(1-j/n)
            end
        end
    end
    for i,branch in e.branches do
        branch.Visible=not simple
        local u=.12+(i*.137)% .72
        local y=h/2+math.sin(u*31-t*4+3.4)*spread*.65*(1-u)
        line(branch,w*u,y,w*(u-.07),y+math.sin(t*3+i)*spread*.9,math.max(.7,spread*.025))
        branch.BackgroundTransparency=.35+.5*(.5+.5*math.sin(t*6+i))
    end
    for i,shard in e.shards do
        shard.Visible=not simple or bg or i<=2
        local age=(t*.45+i*.173)%1
        local x,y,size
        if bg then
            x=w*((i%2==0 and .86 or .14)+.05*math.sin(t*.7+i))
            y=h*(.15+(i*.183)% .7)+math.min(h*.035,7)*math.cos(t+i)
            size=math.clamp(h*.06,3,15)
        else
            x=w*(1-age);y=h/2+math.sin(i*2.399+age*9)*spread*age
            size=(3+i%3)*math.clamp(w/180,.5,2)*math.sin(math.pi*age)
        end
        shard.Position=UDim2.fromOffset(x,y);shard.Size=UDim2.fromOffset(size*.6,size*1.5);shard.Rotation=30+math.sin(t+i)*80
        shard.BackgroundTransparency=bg and .2 or .15+age*.65
    end
    for i,spark in e.sparks do
        spark.Visible=not simple or i<=3
        local age=(t*.9+i*.137)%1
        spark.Position=bg and UDim2.fromScale(i%2==0 and .05+age*.16 or .79+age*.16,.16+(i*.137)% .68) or UDim2.fromOffset(w*(1-age),h/2+math.sin(i+age*7)*spread*age)
        local size=math.clamp(w/240,1,3);spark.Size=UDim2.fromOffset(size,size);spark.Rotation=45
        spark.BackgroundTransparency=.25+.6*(.5+.5*math.sin(t*4+i))
    end
    if e.sweep then e.sweep.Offset=Vector2.new(math.sin(t*.4)*.85,0) end
end
local function start()
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local count=0;local t=os.clock()
        for root,e in entries do
            if visible(root) then
                if e.kind=="tracers" then count+=1 end
                update(e,t,reduced(root) or e.compact or e.kind=="tracers" and count>10)
            end
        end
        if not next(entries) then connection:Disconnect();connection=nil end
    end)
end
function V.clear(root)
    if not root:GetAttribute("Riftglass") then return end
    local e=entries[root];if e and e.destroyConnection then e.destroyConnection:Disconnect() end
    entries[root]=nil
    for _,name in {"RiftglassEffects","RiftglassSweep"} do local old=root:FindFirstChild(name);if old then old:Destroy() end end
    root:SetAttribute("Riftglass",nil)
end
function V.apply(root,item)
    if type(item)~="table" or item.visual~="riftglass" then return false end
    if root:GetAttribute("Riftglass")==item.category then return true end
    V.clear(root);root:SetAttribute("Riftglass",item.category)
    root.Image="";root.ImageRectSize=Vector2.zero;root.ImageRectOffset=Vector2.zero
    root.BackgroundTransparency=1;root.ImageColor3=Color3.new(1,1,1);root.Rotation=0;root.ScaleType=Enum.ScaleType.Fit
    local e={root=root,kind=item.category,seed=math.random()*6.283,ribbons={},branches={},shards={},sparks={}}
    if item.category=="skins" or item.category=="bullets" then
        root.Image=item.category=="skins" and Assets.skin or Assets.bullet;root.ImageRectSize=Vector2.new(256,256)
        if item.category=="skins" then root:SetAttribute("SquareSkin",true);root:SetAttribute("SolidSkin",false) end
    else
        local bg=item.category=="backgrounds"
        if bg then root.Image=Assets.background;root.ScaleType=Enum.ScaleType.Crop end
        local count=0;for other,old in entries do if old.kind=="tracers" and visible(other) then count+=1 end end
        e.compact=not bg and (reduced(root) or count>=10)
        local fx=box(root,"RiftglassEffects",white,1);fx.AnchorPoint=Vector2.zero;fx.Size=UDim2.fromScale(1,1);fx.ClipsDescendants=bg
        for _,r in bg and {1,2} or e.compact and {2} or {1,2,3} do
            e.ribbons[r]={}
            for j=1,e.compact and 6 or 12 do e.ribbons[r][j]={box(fx,"FractureGlow",colors[1],.93),box(fx,"LightningFracture",r==2 and white or colors[1],.2)} end
        end
        if not bg and not e.compact then for i=1,6 do e.branches[i]=box(fx,"ForkedLightning",white,.3) end end
        for i=1,e.compact and 2 or bg and 8 or 9 do
            local shard=box(fx,"MirrorFragment",Color3.fromHex("19182d"),.2)
            local facet=box(shard,"SilverFacet",Color3.fromHex("a8b1c8"),.1);facet.Size=UDim2.fromScale(.42,1);facet.Position=UDim2.fromScale(.25,.5)
            e.shards[i]=shard
        end
        for i=1,e.compact and 3 or 12 do e.sparks[i]=box(fx,"RiftIon",white,.2) end
        if bg then
            local sweep=Instance.new("UIGradient");sweep.Name="RiftglassSweep";sweep.Rotation=24
            local dim=Color3.fromRGB(165,150,195)
            sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,dim),ColorSequenceKeypoint.new(.4,dim),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.6,dim),ColorSequenceKeypoint.new(1,dim)})
            sweep.Parent=root;e.sweep=sweep
        end
    end
    entries[root]=e;e.destroyConnection=root.Destroying:Once(function()entries[root]=nil end)
    update(e,os.clock(),reduced(root) or e.compact);start();return true
end
return V
