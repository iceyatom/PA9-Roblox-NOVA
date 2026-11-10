-- Blender sprite loops + continuously moving native UI VFX for NOVA's 2D arena.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local Assets=require(script.Parent.SupernovaAssets)
local V={};local entries={};local connection;local preloaded={}
local colors={Color3.fromHex("ff219e"),Color3.fromHex("bb24ff"),Color3.fromHex("ff3355")}
local white=Color3.fromHex("ecf7ff")
function V.preload(item)
    if not item or item.visual~="supernova" then return end
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
local pink=Color3.fromHex("ff219e");local violet=Color3.fromHex("b924ff");local hot=Color3.fromHex("fff4ff")
local function halo(parent,name,color,alpha)
    local f=Instance.new("ImageLabel");f.Name=name;f.Image=Assets.halo;f.ImageColor3=color;f.ImageTransparency=alpha or 0
    f.BackgroundTransparency=1;f.AnchorPoint=Vector2.new(.5,.5);f.ZIndex=parent.ZIndex;f.Parent=parent;return f
end
local function update(e,t,simple)
    local root=e.root;local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
    t=(simple and 0 or t)+e.seed
    local pulse=.5+.5*math.sin(t*3)
    if e.kind=="skins" or e.kind=="bullets" then
        local frame=simple and 0 or math.floor((t-e.seed)*8)%16
        if e.frame~=frame then root.ImageRectOffset=Vector2.new(frame%4*256,math.floor(frame/4)*256);e.frame=frame end
        for i,f in e.aura do
            local scale=i==1 and 2.5 or i==2 and 1.7 or .7
            f.Position=UDim2.fromScale(.5,.5);f.Size=UDim2.fromScale(scale*(1+.07*pulse),scale*(1+.07*pulse))
            f.ImageTransparency=(i==1 and .42 or i==2 and .38 or .22)+.12*(1-pulse)
        end
    elseif e.kind=="backgrounds" then
        for i,f in e.aura do
            f.Position=UDim2.fromScale(i==1 and .10 or .90,.5);f.Size=UDim2.fromScale(.55,2.2)
            f.ImageTransparency=.35+.15*(1-pulse)
        end
        e.sweep.Offset=Vector2.new(math.sin(t*.55)*.85,0)
    end
    local bg=e.kind=="backgrounds";local trail=e.kind=="tracers"
    local spread=bg and h*.03 or math.min(w*.18,math.clamp(h*1.8,12,65))
    local n=simple and 4 or 8
    for r,segs in e.ribbons do
        for j,parts in segs do
            local on=j<=n and (bg or not simple or r==2)
            for _,f in parts do f.Visible=on end
            if on then
                local function point(u)
                    local y=bg and (r==1 and h*.12 or h*.88) or h/2
                    return u*w,y+math.sin(u*8-t*4+r*2)*spread*(bg and 1 or 1-u)
                end
                local x1,y1=point((j-1)/n);local x2,y2=point(j/n)
                local thick=bg and math.max(1,h*.014) or math.max(1.1,spread*.12*(.3+.7*j/n))
                for k=1,3 do line(parts[k],x1,y1,x2,y2,thick*({14,6,2.4})[k]);parts[k].ImageTransparency=({.72,.48,.34})[k]+.12*(1-j/n) end
                line(parts[4],x1,y1,x2,y2,math.max(.8,thick*.55));parts[4].BackgroundTransparency=.1+.5*(1-j/n)
            end
        end
    end
    for i,p in e.particles do
        local angle=t*.8+i*2.399
        local function point(lag)
            local tt=t-lag
            if trail then
                local age=(tt*.65+i*.137)%1
                return w*(1-age),h/2+math.sin(i*2.399+age*8)*spread*age,math.sin(age*math.pi)
            elseif bg then return w*(i%2==0 and .12 or .88)+math.sin(tt+i)*w*.025,h*(.15+(i*.173)% .7)+math.cos(tt+i)*h*.04,1
            else return w/2+math.cos(tt*.8+i*2.399)*w*.42,h/2+math.sin(tt*.8+i*2.399)*h*.42,1 end
        end
        local x,y,fade=point(0);local size=math.clamp((trail and w or math.min(w,h))*.025,2,8)*fade
        p.core.Visible=not simple or i<=2;p.glow.Visible=p.core.Visible
        p.core.Position=UDim2.fromOffset(x,y);p.core.Size=UDim2.fromOffset(size,size);p.core.Rotation=45+math.sin(angle)*25
        p.glow.Position=p.core.Position;p.glow.Size=UDim2.fromOffset(size*8,size*8);p.glow.ImageTransparency=.40+.18*(1-fade)
        for j,f in p.ghosts do
            f.Visible=not simple;local gx,gy=point(j*.09);f.Position=UDim2.fromOffset(gx,gy);f.Size=UDim2.fromOffset(size*5,size*5);f.ImageTransparency=.65+j*.08
        end
        if p.star then
            local flash=math.max(0,math.sin(t*2+i)^16);local length=size*(1+flash*5)
            p.star[1].Position=p.core.Position;p.star[2].Position=p.core.Position
            p.star[1].Size=UDim2.fromOffset(length,1);p.star[2].Size=UDim2.fromOffset(1,length)
            p.star[1].BackgroundTransparency=1-flash;p.star[2].BackgroundTransparency=1-flash
        end
    end
end
local function start()
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local t=os.clock();local count=0
        for root,e in entries do if visible(root) then
            if e.kind=="tracers" then count+=1 end
            update(e,t,reduced(root) or e.compact or e.kind=="tracers" and count>8)
        end end
        if not next(entries) then connection:Disconnect();connection=nil end
    end)
end
function V.clear(root)
    if not root:GetAttribute("Supernova") then return end
    local e=entries[root];if e and e.destroyConnection then e.destroyConnection:Disconnect() end;entries[root]=nil
    for _,name in {"SupernovaEffects","SupernovaSweep"} do local f=root:FindFirstChild(name);if f then f:Destroy() end end
    root:SetAttribute("Supernova",nil)
end
function V.apply(root,item)
    if type(item)~="table" or item.visual~="supernova" then return false end
    if root:GetAttribute("Supernova")==item.id then return true end
    V.clear(root);root:SetAttribute("Supernova",item.id)
    root.Image="";root.ImageColor3=Color3.new(1,1,1);root.ImageRectSize=Vector2.zero;root.ImageRectOffset=Vector2.zero;root.Rotation=0;root.BackgroundTransparency=1;root.ScaleType=Enum.ScaleType.Fit
    local e={root=root,kind=item.category,seed=math.random()*6.283,aura={},ribbons={},particles={}}
    local bg=item.category=="backgrounds";local trail=item.category=="tracers"
    if not trail then
        root.Image=bg and Assets.background or item.category=="skins" and Assets.skin or Assets.bullet
        if bg then root.ScaleType=Enum.ScaleType.Crop else root.ImageRectSize=Vector2.new(256,256) end
        if item.category=="skins" then root:SetAttribute("SquareSkin",true);root:SetAttribute("SolidSkin",false) end
    end
    local fx=box(root,"SupernovaEffects",hot,1);fx.AnchorPoint=Vector2.zero;fx.Size=UDim2.fromScale(1,1);fx.ClipsDescendants=bg
    local count=0;for other,old in entries do if old.kind=="tracers" and visible(other) then count+=1 end end
    e.compact=trail and (reduced(root) or count>=8)
    if not trail then
        for i=1,bg and 2 or 3 do e.aura[i]=halo(fx,"PulsingRadiance",i==2 and violet or i==3 and hot or pink,.5) end
    end
    if bg or trail then
        for _,r in bg and {1,2} or e.compact and {2} or {1,2,3} do
            e.ribbons[r]={}
            for j=1,e.compact and 4 or 8 do
                e.ribbons[r][j]={halo(fx,"BroadSoftBloom",pink,.75),halo(fx,"SaturatedGlow",violet,.5),halo(fx,"HotInnerHalo",pink,.35),box(fx,"WhiteHotEnergy",hot,.1)}
            end
        end
    end
    for i=1,e.compact and 3 or trail and 10 or bg and 8 or 4 do
        local p={core=box(fx,"CrystalCore",i%2==0 and hot or pink),glow=halo(fx,"ParticleRadiance",pink,.5),ghosts={}}
        for j=1,e.compact and 0 or 3 do p.ghosts[j]=halo(fx,"LingeringAfterimage",j%2==0 and violet or pink,.8) end
        if i%3==0 then p.star={box(fx,"StarGlintX",hot,1),box(fx,"StarGlintY",hot,1)} end
        e.particles[i]=p
    end
    if bg then
        local sweep=Instance.new("UIGradient");sweep.Name="SupernovaSweep";sweep.Rotation=20
        local dim=Color3.fromRGB(185,140,200);sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,dim),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,dim)});sweep.Parent=root;e.sweep=sweep
    end
    entries[root]=e;e.destroyConnection=root.Destroying:Once(function()entries[root]=nil end)
    update(e,os.clock(),reduced(root) or e.compact);start();return true
end
return V
