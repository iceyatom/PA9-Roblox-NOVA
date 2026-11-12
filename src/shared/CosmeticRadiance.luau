-- Soft Gaussian bloom that follows an existing cosmetic's geometry and motion.
-- No extra Heartbeat: the owning renderer updates and clears this layer.
local Halo=require(script.Parent.SupernovaAssets).halo
local R={}
local hot=Color3.fromRGB(255,249,255)
local themes={
    dragonforge={Color3.fromHex("ff243d"),Color3.fromHex("287aff"),Color3.fromHex("ffd326")},
    riftglass={Color3.fromHex("a14dff"),Color3.fromHex("5d38ff"),Color3.fromHex("ded1ff")},
}
local function box(parent,name,color,alpha)
    local f=Instance.new("Frame");f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.BorderSizePixel=0
    f.BackgroundColor3=color;f.BackgroundTransparency=alpha or 0;f.ZIndex=parent.ZIndex;f.Parent=parent;return f
end
local function glow(parent,name,color,alpha)
    local f=Instance.new("ImageLabel");f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.BackgroundTransparency=1
    f.Image=Halo;f.ImageColor3=color;f.ImageTransparency=alpha or .5;f.ZIndex=parent.ZIndex;f.Parent=parent;return f
end
local function fit(f,source,width)
    f.Position=source.Position;f.Rotation=source.Rotation
    f.Size=UDim2.fromOffset(math.max(1,source.Size.X.Offset*1.18),width)
end
function R.new(root,source,theme)
    local palette=assert(themes[theme],theme)
    local fx=box(root,"RadianceGlow",hot,1);fx.AnchorPoint=Vector2.zero;fx.Size=UDim2.fromScale(1,1)
    local bg=source.kind=="backgrounds";local sprite=source.kind=="skins" or source.kind=="bullets"
    fx.ClipsDescendants=bg
    local e={root=root,fx=fx,bg=bg,sprite=sprite,palette=palette,beams={},particles={},aura={},glints={},theme=theme,compact=source.compact}
    if bg or sprite then
        for i=1,bg and 2 or 3 do e.aura[i]=glow(fx,"PulsingSoftRadiance",palette[(i-1)%3+1],.55) end
    end
    for r,segments in source.ribbons or {} do
        for j,parts in segments do
            local main=parts[2]
            if main then
                local color=theme=="dragonforge" and palette[(r-1)%3+1] or palette[1]
                e.beams[#e.beams+1]={source=main,broad=glow(fx,"BroadSoftBloom",color,.66),inner=glow(fx,"SaturatedRadiance",color,.42),core=box(fx,"RadiantWhiteCore",hot,.2),index=j}
            end
        end
    end
    local function particle(sourceObj,index)
        local c=palette[(index-1)%3+1]
        local p={source=sourceObj,halo=glow(fx,"ParticleLightSpill",c,.4),ghosts={},history={}}
        if not e.compact then for j=1,3 do p.ghosts[j]=glow(fx,"LingeringAfterimage",c,.7+j*.06) end end
        if index%3==0 then p.star={box(fx,"SharpGlintX",hot,1),box(fx,"SharpGlintY",hot,1)} end
        e.particles[#e.particles+1]=p
    end
    local count=0
    for _,list in {source.shards or {},source.sparks or {}} do
        for _,obj in list do
            if count>=12 then break end
            count+=1;particle(obj,count)
        end
    end
    if sprite then
        for i=1,4 do
            local glint=box(fx,"TravellingHighlight",hot,.1)
            e.glints[i]=glint;particle(glint,count+i)
        end
    end
    return e
end
function R.update(e,t,simple)
    if not e or not e.root.Parent then return end
    if simple then t=0 end
    local pulse=.5+.5*math.sin(t*2.6)
    local root=e.root;local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
    for i,f in e.aura do
        if e.bg then
            f.Position=UDim2.fromScale(i==1 and .1 or .9,.5)
            f.Size=UDim2.fromScale(.48*(1+.06*pulse),2.1)
            f.ImageTransparency=.50+.12*(1-pulse)
        else
            local scale=i==1 and 2.45 or i==2 and 1.65 or .65
            f.Position=UDim2.fromScale(.5,.5);f.Size=UDim2.fromScale(scale*(1+.06*pulse),scale*(1+.06*pulse))
            f.ImageTransparency=(i==1 and .48 or i==2 and .52 or .62)+.12*(1-pulse)
        end
    end
    for _,b in e.beams do
        local on=b.source.Visible
        b.broad.Visible=on and not simple;b.inner.Visible=on;b.core.Visible=on
        if on then
            local width=math.max(1,b.source.Size.Y.Offset)
            fit(b.broad,b.source,math.max(e.bg and 12 or 16,width*18))
            fit(b.inner,b.source,math.max(5,width*7))
            fit(b.core,b.source,math.max(.7,width*.38))
            b.broad.ImageTransparency=.64+.10*(1-pulse)
            b.inner.ImageTransparency=(simple and .68 or .40)+.10*(1-pulse)
            b.core.BackgroundTransparency=.12+.16*(.5+.5*math.sin(t*4-b.index*.6))
        end
    end
    for i,f in e.glints do
        local phase=t*.7+i*math.pi/2
        local x,y
        if e.root:GetAttribute("SquareSkin") then
            -- Move around a square path; keep the visible highlight inside its rim.
            local u=(phase/math.pi/2)%4
            if u<1 then x=.12+.76*u;y=.12 elseif u<2 then x=.88;y=.12+.76*(u-1)
            elseif u<3 then x=.88-.76*(u-2);y=.88 else x=.12;y=.88-.76*(u-3) end
        else x=.5+.34*math.cos(phase);y=.5+.34*math.sin(phase) end
        f.Position=UDim2.fromScale(x,y);f.Size=UDim2.fromOffset(math.clamp(math.min(w,h)*.025,1.5,5),math.clamp(math.min(w,h)*.025,1.5,5));f.Rotation=45
    end
    for i,p in e.particles do
        local s=p.source
        local x=s.Position.X.Scale*w+s.Position.X.Offset;local y=s.Position.Y.Scale*h+s.Position.Y.Offset
        local width=math.max(1,s.Size.X.Offset+s.Size.X.Scale*w);local height=math.max(1,s.Size.Y.Offset+s.Size.Y.Scale*h)
        local size=math.clamp(math.max(width,height),1.5,12)
        p.halo.Visible=s.Visible;p.halo.Position=s.Position;p.halo.Size=UDim2.fromOffset(size*8,size*8)
        p.halo.ImageTransparency=.40+.14*(1-pulse)
        local history=p.history
        if e.last and t-e.last>.3 then table.clear(history) end
        if not simple and (not history[#history] or t-history[#history].t>=.035) then history[#history+1]={t=t,x=x,y=y,size=size} end
        while #history>1 and t-history[1].t>.45 do table.remove(history,1) end
        for j,f in p.ghosts do
            local sample
            for k=#history,1,-1 do if history[k].t<=t-j*.07 then sample=history[k];break end end
            f.Visible=not simple and s.Visible and sample~=nil
            if sample then
                f.Position=UDim2.fromOffset(sample.x,sample.y);f.Size=UDim2.fromOffset(sample.size*(6-j*.5),sample.size*(6-j*.5))
            end
        end
        if p.star then
            local flash=simple and 0 or math.max(0,math.sin(t*2+i)^18)
            for k,f in p.star do
                f.Visible=s.Visible and not simple;f.Position=s.Position
                f.Size=UDim2.fromOffset(k==1 and size*(2+flash*5) or 1,k==2 and size*(2+flash*5) or 1)
                f.BackgroundTransparency=1-flash
            end
        end
    end
    e.last=t
end
function R.clear(e)
    if not e then return end
    e.fx:Destroy();table.clear(e.particles)
end
return R
