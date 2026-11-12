local Geometry=require(script.Parent.CosmeticGeometry)
-- Blender sprite loops + continuously moving native UI VFX for NOVA's 2D arena.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Content=game:GetService("ContentProvider")
local Assets=require(script.Parent.CipherAssets)
local V={};local entries={};local connection;local preloaded={}
local colors={Color3.fromHex("ff3044"),Color3.fromHex("368fff"),Color3.fromHex("ffc900")}
local white=Color3.fromHex("ecf7ff")
function V.preload(item)
    if not item or item.visual~="cipher" then return end
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
    local guiSize=Geometry.size(e.root)
    local root=e.root
    if e.kind=="skins" or e.kind=="bullets" then
        local frame=reduced(root) and 0 or math.floor(t*8)%16
        if frame~=e.frame then root.ImageRectOffset=Vector2.new(frame%4*256,math.floor(frame/4)*256);e.frame=frame end
        return
    end
    t=(reduced(root) and 0 or t)+e.seed
    local w,h=guiSize.X,guiSize.Y;local bg=e.kind=="backgrounds"
    local spread=bg and h*.10 or math.min(w*.08,math.max(4,h*.9))
    for i,rail in e.rails do
        rail.Visible=bg or not simple or i==2
        local y=bg and (i==1 and h*.12 or h*.88) or h/2
        line(rail,0,y+(bg and 0 or (i-2)*spread),w,y,bg and 1 or 1.2)
    end
    for i,packet in e.packets do
        packet.frame.Visible=not simple or bg or i<=2
        local age=(t*.7+i*.173)%1
        local x,y
        if bg then x=w*(i%2==0 and .08+.10*age or .82+.10*age);y=h*(.18+(i*.137)% .63)
        else x=w*(1-age);y=h/2+((i%3)-1)*spread*age end
        packet.frame.Position=UDim2.fromOffset(x,y)
        local size=bg and math.clamp(h*.07,3,12) or math.clamp(w*.035,3,12)
        packet.frame.Size=UDim2.fromOffset(size,size*.8)
        packet.stroke.Transparency=.15+.65*(.5+.5*math.sin(t*4+i))
    end
    for i,b in e.bits do
        b.Visible=not simple or bg or i<=3
        local age=(t*.9+i*.127)%1
        b.Position=bg and UDim2.fromScale(i%2==0 and .10+(i%3)*.045 or .80+(i%3)*.045,.1+.8*age) or UDim2.fromOffset(w*(1-age),h/2+((i%2)*2-1)*spread*age)
        b.BackgroundTransparency=.2+age*.65
    end
    if e.sweep then e.sweep.Offset=Vector2.new(0,math.sin(t*.65)*.85) end
end
local function start()
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local t=os.clock();local trails=0
        for root,e in entries do
            if visible(root) then
                if e.kind=="tracers" then trails+=1 end
                update(e,t,reduced(root) or root:GetAttribute("CompactPrism")==true or e.compact or e.kind=="tracers" and trails>12)
            end
        end
        if not next(entries) then connection:Disconnect();connection=nil end
    end)
end
function V.clear(root)
    if not root:GetAttribute("Cipher") then return end
    local e=entries[root];if e and e.destroyConnection then e.destroyConnection:Disconnect() end;entries[root]=nil
    for _,name in {"CipherEffects","CipherSweep"} do local obj=root:FindFirstChild(name);if obj then obj:Destroy() end end
    root:SetAttribute("Cipher",nil);root.ImageColor3=Color3.new(1,1,1)
end
function V.apply(root,item)
    if type(item)~="table" or item.visual~="cipher" then return false end
    if root:GetAttribute("Cipher")==item.id then return true end
    V.clear(root);root:SetAttribute("Cipher",item.id)
    local tint=Color3.fromHex(item.color)
    root.Image="";root.ImageColor3=tint;root.BackgroundTransparency=1;root.ImageRectSize=Vector2.zero;root.ImageRectOffset=Vector2.zero;root.Rotation=0;root.ScaleType=Enum.ScaleType.Fit
    local e={root=root,kind=item.category,seed=math.random()*6.283,rails={},packets={},bits={}}
    if item.category=="skins" or item.category=="bullets" then
        root.Image=item.category=="skins" and Assets.skin or Assets.bullet;root.ImageRectSize=Vector2.new(256,256)
        if item.category=="skins" then root:SetAttribute("SquareSkin",true);root:SetAttribute("SolidSkin",false) end
    else
        local bg=item.category=="backgrounds"
        if bg then root.Image=Assets.background;root.ScaleType=Enum.ScaleType.Crop end
        local count=0;for other,old in entries do if old.kind=="tracers" and visible(other) then count+=1 end end
        e.compact=not bg and (reduced(root) or root:GetAttribute("CompactPrism")==true or count>=12)
        local fx=box(root,"CipherEffects",tint,1);fx.AnchorPoint=Vector2.zero;fx.Size=UDim2.fromScale(1,1);fx.ClipsDescendants=bg
        for i=1,bg and 2 or 3 do e.rails[i]=box(fx,"DataRail",tint,.45) end
        for i=1,e.compact and 2 or bg and 8 or 9 do
            local packet=box(fx,"SignalPacket",tint,1)
            local stroke=Instance.new("UIStroke");stroke.Color=tint;stroke.Thickness=1;stroke.Parent=packet
            e.packets[i]={frame=packet,stroke=stroke}
        end
        for i=1,e.compact and 3 or 12 do
            local bit=box(fx,"BinaryBit",tint,.2);bit.Size=UDim2.fromOffset(i%2==0 and 2 or 4,3);e.bits[i]=bit
        end
        if bg then
            local sweep=Instance.new("UIGradient");sweep.Name="CipherSweep";sweep.Rotation=90
            sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(120,120,120)),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,120,120))});sweep.Parent=root;e.sweep=sweep
        end
    end
    entries[root]=e;e.destroyConnection=root.Destroying:Once(function()entries[root]=nil end)
    update(e,os.clock(),reduced(root) or root:GetAttribute("CompactPrism")==true or e.compact);start();return true
end
return V
