local Geometry=require(script.Parent.CosmeticGeometry)
-- Armory: five Blender sprite sets (item.theme) sharing one native 2D VFX engine.
-- Skins/bullets play 16-frame atlases; tracers and backgrounds are live geometry + theme sprites.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local Assets=require(script.Parent.ArmoryAssets)
local V={};local entries={};local connection;local preloaded={}
-- style picks how a theme's sprite travels along a trail.
local themes={
    aetherwing={colors={"35f2ff","ffab2e","e4f8ff"},hot="f2fdff",dim={150,205,215},style="drift",lanes=3,wave=.10,freq=9,flow=2,count=9},
    hexwyrm={colors={"2bffc1","0c9f8c","8fb0c8"},hot="e6fff8",dim={140,200,190},style="grid",lanes=2,wave=.05,freq=14,flow=3,count=10},
    pawpop={colors={"ff6fb5","c7a4ff","ffe23d"},hot="fff3fa",dim={255,205,228},style="steps",lanes=2,wave=.12,freq=6,flow=1.5,count=6},
    goldcoil={colors={"ffd61f","ff9d0a","fff6c2"},hot="fffbe0",dim={215,190,130},style="march",lanes=3,wave=0,freq=0,flow=0,count=6},
    shardbound={colors={"9638ff","dcb4ff","a9b4cc"},hot="f6ecff",dim={185,160,215},style="chain",lanes=1,wave=.03,freq=5,flow=1,count=9},
}
for _,th in themes do
    for i,c in th.colors do th.colors[i]=Color3.fromHex(c) end
    th.hot=Color3.fromHex(th.hot);th.dim=Color3.fromRGB(th.dim[1],th.dim[2],th.dim[3])
end
V.themes=themes
local function art(item)
    local set=Assets[item.theme]
    return set and (item.category=="skins" and set.skin or item.category=="bullets" and set.bullet or item.category=="backgrounds" and set.background)
end
function V.preload(item)
    if not item or item.visual~="armory" then return end
    local id=art(item)
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
local function image(parent,name,id,color,alpha)
    local f=Instance.new("ImageLabel");f.Name=name;f.Image=id;f.ImageColor3=color;f.ImageTransparency=alpha or 0
    f.BackgroundTransparency=1;f.AnchorPoint=Vector2.new(.5,.5);f.ZIndex=parent.ZIndex;f.Parent=parent;return f
end
local function line(f,x1,y1,x2,y2,width)
    local dx,dy=x2-x1,y2-y1
    f.Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2)
    f.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+.5,width);f.Rotation=math.deg(math.atan2(dy,dx))
end
-- Returns x,y,fade,rotation,width scale,height scale for trail sprite i of n.
local function travel(style,i,n,t,w,h,spread)
    if style=="drift" then
        local age=(t*.6+i*.137)%1
        return w*(1-age),h/2+math.sin(i*2.399+age*8)*spread*age,math.sin(age*math.pi),180+math.sin(t*2+i)*30,1.5,1.5
    elseif style=="grid" then
        local age=(t*.5+i*.173)%1
        return w*(1-age),h/2+(i%3-1)*spread*.6*math.sqrt(age),math.sin(age*math.pi)*(.65+.35*math.sin(t*6+i*2)),0,1,1
    elseif style=="steps" then
        local u=(i/n+t*.35)%1;local side=i%2*2-1
        return w*(1-u),h/2+side*spread*.38,math.sin(u*math.pi),90+side*18,1.25,1.25
    elseif style=="march" then
        local u=(i/n+t*.9)%1
        return w*u,h/2,math.sin(u*math.pi),0,.7+.6*u,.7+.6*u
    end
    local u=(i/n+t*.25)%1
    return w*u,h/2+math.sin(u*5-t)*spread*.08*(1-u),math.sqrt(math.sin(u*math.pi)),0,1.5,i%2==0 and 1.5 or .55
end
local function update(e,t,simple)
    local guiSize=Geometry.size(e.root)
    local root,th=e.root,e.theme;local w,h=guiSize.X,guiSize.Y
    t=(reduced(root) and 0 or t)+e.seed
    local pulse=.5+.5*math.sin(t*2)
    local bg=e.kind=="backgrounds";local trail=e.kind=="tracers"
    if e.kind=="skins" or e.kind=="bullets" then
        local frame=reduced(root) and 0 or math.floor((t-e.seed)*8)%16
        if e.frame~=frame then root.ImageRectOffset=Vector2.new(frame%4*256,math.floor(frame/4)*256);e.frame=frame end
        for i,f in e.aura do
            local scale=(i==1 and 2.3 or 1.6)*(1+.07*pulse)
            f.Position=UDim2.fromScale(.5,.5);f.Size=UDim2.fromScale(scale,scale)
            f.ImageTransparency=(i==1 and .70 or .72)+.12*(1-pulse)
        end
    elseif bg then
        for i,f in e.aura do
            f.Position=UDim2.fromScale(i==1 and .10 or .90,.5);f.Size=UDim2.fromScale(.55,2.2)
            f.ImageTransparency=.62+.15*(1-pulse)
        end
        e.sweep.Offset=Vector2.new(math.sin(t*.55)*.85,0)
    end
    local spread=bg and h*.03 or math.min(w*.18,math.clamp(h*1.8,12,65))
    local n=simple and 4 or 8
    for r,segs in e.ribbons do
        for j,parts in segs do
            local on=j<=n and (bg or not simple or r==1)
            for _,f in parts do f.Visible=on end
            if on then
                local lane=trail and (r-(e.lanes+1)/2)*.30 or 0
                local function point(u)
                    local y=bg and (r==1 and h*.10 or h*.90) or h/2
                    local taper=bg and .5 or th.style=="march" and 1 or 1-u
                    return u*w,y+(lane+th.wave*math.sin(u*th.freq-t*th.flow+r*2.1))*spread*taper
                end
                local x1,y1=point((j-1)/n);local x2,y2=point(j/n)
                local thick=bg and math.max(1,h*.014) or math.max(1.1,spread*.12*(.3+.7*j/n))
                line(parts[1],x1,y1,x2,y2,thick*10);parts[1].ImageTransparency=.74+.12*(1-j/n)
                line(parts[2],x1,y1,x2,y2,thick*4);parts[2].ImageTransparency=.48+.14*(1-j/n)
                line(parts[3],x1,y1,x2,y2,math.max(.8,thick*.55));parts[3].BackgroundTransparency=.1+.5*(1-j/n)
            end
        end
    end
    local count=#e.particles
    for i,p in e.particles do
        local x,y,fade,rot,sx,sy,size
        if trail then
            x,y,fade,rot,sx,sy=travel(th.style,i,count,t,w,h,spread)
            size=math.min(spread*.55,th.style=="chain" and w/count*.9 or spread)
        elseif bg then
            local left=i%2==0
            x=w*(left and .12 or .88)+math.sin(t*.6+i)*w*.02;y=h*(.14+(i*.173)%.72)+math.cos(t*.5+i)*h*.04
            fade=.75+.25*math.sin(t*1.3+i);rot=math.sin(t*.7+i)*15+(th.style=="drift" and not left and 180 or 0);sx,sy=1,1;size=h*.17
        else
            local angle=t*.8+i*math.pi*2/count
            x=w/2+math.cos(angle)*w*.58;y=h/2+math.sin(angle)*h*.58
            fade=.7+.3*math.sin(t*2+i);rot=math.deg(angle)+90;sx,sy=1,1;size=math.clamp(math.min(w,h)*.2,4,40)
        end
        local on=not simple or i<=3
        p.core.Visible=on;p.glow.Visible=on
        if on then
            p.core.Position=UDim2.fromOffset(x,y);p.core.Size=UDim2.fromOffset(size*sx,size*sy);p.core.Rotation=rot
            p.core.ImageTransparency=1-fade*.92
            p.glow.Position=p.core.Position;p.glow.Size=UDim2.fromOffset(size*2.6,size*2.6);p.glow.ImageTransparency=1-fade*.42
        end
    end
end
local function start()
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local t=os.clock();local count=0
        for root,e in entries do if visible(root) then
            if e.kind=="tracers" then count+=1 end
            update(e,t,reduced(root) or root:GetAttribute("CompactPrism")==true or e.compact or e.kind=="tracers" and count>8)
        end end
        if not next(entries) then connection:Disconnect();connection=nil end
    end)
end
function V.clear(root)
    if not root:GetAttribute("Armory") then return end
    local e=entries[root];if e and e.destroyConnection then e.destroyConnection:Disconnect() end;entries[root]=nil
    for _,name in {"ArmoryEffects","ArmorySweep"} do local f=root:FindFirstChild(name);if f then f:Destroy() end end
    root:SetAttribute("Armory",nil)
end
function V.apply(root,item)
    if type(item)~="table" or item.visual~="armory" then return false end
    local th=themes[item.theme];local set=Assets[item.theme]
    if not th or not set then return false end
    if root:GetAttribute("Armory")==item.id then return true end
    V.clear(root);root:SetAttribute("Armory",item.id)
    root.Image="";root.ImageColor3=Color3.new(1,1,1);root.ImageRectSize=Vector2.zero;root.ImageRectOffset=Vector2.zero;root.Rotation=0;root.BackgroundTransparency=1;root.ScaleType=Enum.ScaleType.Fit
    local e={root=root,theme=th,kind=item.category,seed=math.random()*6.283,aura={},ribbons={},particles={},lanes=th.lanes}
    local bg=item.category=="backgrounds";local trail=item.category=="tracers"
    if not trail then
        root.Image=art(item)
        if bg then root.ScaleType=Enum.ScaleType.Crop else root.ImageRectSize=Vector2.new(256,256) end
        if item.category=="skins" then root:SetAttribute("SquareSkin",true);root:SetAttribute("SolidSkin",false) end
    end
    local fx=box(root,"ArmoryEffects",th.hot,1);fx.AnchorPoint=Vector2.zero;fx.Size=UDim2.fromScale(1,1);fx.ClipsDescendants=bg
    local count=0;for other,old in entries do if old.kind=="tracers" and visible(other) then count+=1 end end
    e.compact=trail and (reduced(root) or root:GetAttribute("CompactPrism")==true or count>=8)
    if e.compact then e.lanes=1 end
    if not trail then
        for i=1,2 do e.aura[i]=image(fx,"PulsingRadiance",Assets.halo,th.colors[i],.7) end
    end
    if bg or trail then
        for r=1,bg and 2 or e.lanes do
            e.ribbons[r]={}
            for j=1,e.compact and 4 or 8 do
                local color=th.colors[(r-1)%3+1]
                e.ribbons[r][j]={image(fx,"BroadSoftBloom",Assets.halo,color,.75),image(fx,"SaturatedGlow",Assets.halo,color,.5),box(fx,"WhiteHotEnergy",th.hot,.1)}
            end
        end
    end
    for i=1,e.compact and 3 or trail and th.count or bg and 10 or 3 do
        e.particles[i]={glow=image(fx,"SpriteRadiance",Assets.halo,th.colors[i%3+1],.6),core=image(fx,"ThemeSprite",set.sprite,Color3.new(1,1,1),.1)}
    end
    if bg then
        local sweep=Instance.new("UIGradient");sweep.Name="ArmorySweep";sweep.Rotation=20
        sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,th.dim),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,th.dim)});sweep.Parent=root;e.sweep=sweep
    end
    entries[root]=e;e.destroyConnection=root.Destroying:Once(function()entries[root]=nil end)
    update(e,os.clock(),reduced(root) or root:GetAttribute("CompactPrism")==true or e.compact);start();return true
end
return V
