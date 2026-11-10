-- Blender sprite loops + continuously moving native UI VFX for NOVA's 2D arena.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local Assets=require(script.Parent.DragonforgeAssets)
local V={};local entries={};local connection;local preloaded={}
local colors={Color3.fromHex("ff3044"),Color3.fromHex("368fff"),Color3.fromHex("ffc900")}
local white=Color3.fromHex("ecf7ff")
function V.preload(item)
    if not item or item.visual~="dragonforge" then return end
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
    if e.kind=="backgrounds" then
        if simple then t=0 end
        local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
        -- Match the native decoration to the same 2:1 source rectangle as Crop.
        local iw=math.max(w,h*2);local ih=iw/2;local ox,oy=(w-iw)/2,(h-ih)/2
        local function point(u,v) return ox+u*iw,oy+v*ih end
        for r,segments in e.ribbons do
            local band=r>3 and .83 or .17;local phase=(r-1)%3*math.pi*2/3
            for j,parts in segments do
                local function wave(u)
                    local x=ox+(.25+.5*u)*iw
                    local y=math.clamp(oy+band*ih,h*.1,h*.9)
                    return x,y+math.min(ih*.012,h*.025)*math.sin(u*10-t*3.14+phase)
                end
                local x1,y1=wave((j-1)/8);local x2,y2=wave(j/8)
                line(parts[1],x1,y1,x2,y2,math.max(1,ih*.008))
                line(parts[2],x1,y1,x2,y2,math.max(.6,ih*.002))
            end
        end
        for i,shard in e.shards do
            local u=i<=4 and .035+(i-1)*.055 or .80+(i-5)*.055
            local v=i%2==0 and .82 or .18
            local x=w*u+math.min(8,w*.025)*math.sin(t*.9+i)
            local y=h*v+math.min(5,h*.06)*math.cos(t*.9+i)
            shard.Position=UDim2.fromOffset(x,y);shard.Rotation=45+math.sin(t+i)*18
            local size=math.clamp(ih*.024,2,14);shard.Size=UDim2.fromOffset(size,size)
            shard.BackgroundTransparency=.2+.25*(.5+.5*math.sin(t*2+i))
        end
        for i,spark in e.sparks do
            local u=i%2==0 and .03+(i%5)*.038 or .80+(i%5)*.038
            local x,y=point(u+.007*math.sin(t+i),.12+((i*.173)% .76)+.025*math.cos(t+i*2.4))
            spark.Position=UDim2.fromOffset(x,y);spark.Rotation=45+t*12
            local size=math.clamp(ih*.006,1,3);spark.Size=UDim2.fromOffset(size,size)
            spark.BackgroundTransparency=.25+.5*(.5+.5*math.sin(t*2+i))
        end
        e.sweep.Offset=Vector2.new(math.sin(t*.55)*.85,0)
        return
    end
    if e.kind~="tracers" then
        local frame=simple and 0 or math.floor(t*8)%16
        if frame~=e.frame then root.ImageRectOffset=Vector2.new(frame%4*256,math.floor(frame/4)*256);e.frame=frame end
        return
    end
    t+=e.seed
    local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
    local spread=math.min(w*.2,math.clamp(math.max(h*1.6,w*.075),8,50))
    local unit=math.clamp(w/160,.6,2)
    local n=simple and 4 or 8
    for r,segments in e.ribbons do
        for j,parts in segments do
            local on=j<=n and (not simple or r==3)
            for _,f in parts do f.Visible=on end
            if on then
                local function point(u)
                    return u*w,h/2+math.sin(u*11-t*6.283+r*math.pi*2/3)*spread*(1-u)
                end
                local x1,y1=point((j-1)/n);local x2,y2=point(j/n)
                local thick=math.max(.8,spread*(.015+.085*j/n))
                line(parts[1],x1,y1,x2,y2,thick*4)
                line(parts[2],x1,y1,x2,y2,thick)
                line(parts[3],x1,y1,x2,y2,math.max(.6,thick*.24))
                parts[1].BackgroundTransparency=.92+.06*(1-j/n)
                parts[2].BackgroundTransparency=.08+.62*(1-j/n)
                parts[3].BackgroundTransparency=.18+.7*(1-j/n)
            end
        end
    end
    for i,shard in e.shards do
        shard.Visible=not simple or i<=2
        local age=(t*.8+i*.173)%1
        shard.Position=UDim2.fromOffset(w*(1-age),h/2+math.sin(age*7+i*2.399)*spread*age)
        local size=(3+i%3)*unit*math.sin(age*math.pi)
        shard.Size=UDim2.fromOffset(size,size*.7);shard.Rotation=t*140+i*57;shard.BackgroundTransparency=.1+age*.7
    end
    for i,spark in e.sparks do
        spark.Visible=not simple or i<=3
        local age=(t*1.3+i*.117)%1
        spark.Position=UDim2.fromOffset(w*(1-age),h/2+math.sin(i*2.4+age*4)*spread*age*1.2)
        local size=(1.3+i%2)*unit*math.sin(math.pi*age)
        spark.Size=UDim2.fromOffset(size*2,size);spark.Rotation=t*90+i*31;spark.BackgroundTransparency=age*.85
    end
    for i,hoop in e.hoops do
        hoop.frame.Visible=not simple or i==1
        local age=(t*.65+i*.24)%1
        hoop.frame.Position=UDim2.fromOffset(w*(1-age),h/2)
        hoop.frame.Size=UDim2.fromOffset(math.max(2,spread*.15),math.max(4,spread*(.35+age*.9)))
        hoop.stroke.Transparency=.25+age*.7
    end
end
local function start()
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local t=os.clock();local trails=0
        for root,e in entries do
            if visible(root) then
                local simple=reduced(root) or e.compact
                if e.kind=="tracers" then trails+=1;simple=simple or trails>10 end
                update(e,t,simple)
            end
        end
        if not next(entries) then connection:Disconnect();connection=nil end
    end)
end
function V.clear(root)
    if not root:GetAttribute("Dragonforge") then return end
    local e=entries[root];if e and e.destroyConnection then e.destroyConnection:Disconnect() end
    entries[root]=nil
    local old=root:FindFirstChild("DragonforgeEffects");if old then old:Destroy() end
    local sweep=root:FindFirstChild("DragonforgeSweep");if sweep then sweep:Destroy() end
    root:SetAttribute("Dragonforge",nil)
end
function V.apply(root,item)
    if type(item)~="table" or item.visual~="dragonforge" then return false end
    if root:GetAttribute("Dragonforge")==item.category then return true end
    V.clear(root);root:SetAttribute("Dragonforge",item.category)
    root.BackgroundTransparency=1;root.ImageColor3=Color3.new(1,1,1);root.ScaleType=Enum.ScaleType.Fit
    root.Image="";root.ImageRectSize=Vector2.zero;root.ImageRectOffset=Vector2.zero;root.Rotation=0
    local e={root=root,kind=item.category,seed=math.random()*6.283,ribbons={},shards={},sparks={},hoops={}}
    if item.category=="skins" or item.category=="bullets" then
        root.Image=item.category=="skins" and Assets.skin or Assets.bullet;root.ImageRectSize=Vector2.new(256,256)
        if item.category=="skins" then root:SetAttribute("SquareSkin",true);root:SetAttribute("SolidSkin",false) end
    elseif item.category=="backgrounds" then
        root.Image=Assets.background;root.ScaleType=Enum.ScaleType.Crop
        local effects=box(root,"DragonforgeEffects",white,1);effects.AnchorPoint=Vector2.zero;effects.Size=UDim2.fromScale(1,1);effects.ClipsDescendants=true
        for r=1,6 do
            e.ribbons[r]={}
            for j=1,8 do
                e.ribbons[r][j]={box(effects,"BorderPlasmaGlow",colors[(r-1)%3+1],.93),box(effects,"BorderPlasma",colors[(r-1)%3+1],.15)}
            end
        end
        for i=1,8 do
            local shard=box(effects,"DominionGoldCrystal",colors[3],.3)
            local facet=box(shard,"CrystalGlint",white,.25);facet.Position=UDim2.fromScale(.25,.5);facet.Size=UDim2.fromScale(.5,1);e.shards[i]=shard
        end
        for i=1,12 do e.sparks[i]=box(effects,"DominionIon",i%3==0 and white or colors[3],.3) end
        local sweep=Instance.new("UIGradient");sweep.Name="DragonforgeSweep";sweep.Rotation=18
        local shade=Color3.fromRGB(185,195,220)
        sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,shade),ColorSequenceKeypoint.new(.42,shade),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.58,shade),ColorSequenceKeypoint.new(1,shade)})
        sweep.Parent=root;e.sweep=sweep
    else
        local count=0;for other,entry in entries do if entry.kind=="tracers" and visible(other) then count+=1 end end
        e.compact=reduced(root) or count>=10
        local effects=box(root,"DragonforgeEffects",white,1);effects.AnchorPoint=Vector2.zero;effects.Size=UDim2.fromScale(1,1)
        for _,r in e.compact and {3} or {1,2,3} do
            e.ribbons[r]={}
            for j=1,e.compact and 4 or 8 do
                local parts={box(effects,"PlasmaGlow",colors[r]),box(effects,"BraidedRibbon",colors[r]),box(effects,"WhiteHotCore",white)}
                e.ribbons[r][j]=parts
                for _,f in parts do local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=f end
            end
        end
        for i=1,e.compact and 2 or 6 do
            local q=box(effects,"TravellingGoldShard",colors[3]);local facet=box(q,"CrystalFacet",white,.25)
            facet.Size=UDim2.fromScale(.4,1);facet.Position=UDim2.fromScale(.3,.5);e.shards[i]=q
        end
        for i=1,e.compact and 3 or 12 do e.sparks[i]=box(effects,"IonSpark",i%2==0 and white or colors[2]) end
        for i=1,e.compact and 1 or 4 do
            local f=box(effects,"EnergyHoop",white,1);local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=f
            local stroke=Instance.new("UIStroke");stroke.Color=colors[(i-1)%2+1];stroke.Thickness=1;stroke.Parent=f
            e.hoops[i]={frame=f,stroke=stroke}
        end
    end
    entries[root]=e;e.destroyConnection=root.Destroying:Once(function() entries[root]=nil end)
    update(e,os.clock(),reduced(root) or e.compact);start();return true
end
return V
