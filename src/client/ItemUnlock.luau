-- NOVA's prestige lift/stamp motion, adapted to an existing full-color inventory sprite.
local Run=game:GetService("RunService")
local Content=game:GetService("ContentProvider")
local W=require(script.Parent.Widgets)
local Art=require(game.ReplicatedStorage.NOVA.InventoryArt)
local Unlock={}; Unlock.__index=Unlock
local gold=Color3.fromRGB(255,222,91)
local pale=Color3.fromRGB(255,247,191)
local impactAt=1.24
local function phase(t,a,b) return math.clamp((t-a)/(b-a),0,1) end
local function ease(t) return 1-(1-t)^3 end
local function mix(a,b,t) return a+(b-a)*t end
local function centered(parent,name,w,h,color,z)
    local f=W.box(parent,name,290,290,w,h,color,z)
    f.AnchorPoint=Vector2.new(.5,.5); return f
end
local function ring(parent,name,size,thickness)
    local f=centered(parent,name,size,size,nil,4); W.round(f); W.stroke(f,gold,thickness)
    return {frame=f,stroke=f:FindFirstChildOfClass("UIStroke")}
end
function Unlock.new(parent,item,onReady,height)
    local self=setmetatable({onReady=onReady},Unlock)
    height=height or 650
    local root=W.box(parent,"ItemUnlock",0,0,parent.Size.X.Offset,height,nil,42); self.root=root
    root.Visible=false; root:SetAttribute("Phase","prepared"); root:SetAttribute("ItemId",item.id)
    local origin=W.box(root,"Origin",parent.Size.X.Offset/2,height<650 and height*.43 or 290,0,0)
    local fit=Instance.new("UIScale")
    fit.Scale=math.min(1,(parent.Size.X.Offset-24)/580,height<650 and (height-120)/580 or 1); fit.Parent=origin
    local stage=W.box(origin,"Stage",-290,-290,580,580)
    local glow=Instance.new("CanvasGroup")
    glow.Name="GoldenGlow"; glow.BackgroundTransparency=1; glow.Size=UDim2.fromOffset(580,580)
    glow.ZIndex=1; glow.Parent=stage; self.glow=glow
    for i=1,12 do
        local disk=centered(glow,"SoftAura"..i,580-(i-1)*30,580-(i-1)*30,gold,1)
        W.round(disk); disk.BackgroundTransparency=.97
    end
    self.rays=centered(glow,"RadialRays",580,580,nil,2)
    self.wideRays=centered(glow,"WideRays",520,520,nil,2)
    for i=1,14 do
        local ray=W.box(self.rays,"Ray"..i,290,290,18,570,gold,2)
        ray.AnchorPoint=Vector2.new(.5,.5); ray.Rotation=(i-1)*180/14
        local gradient=Instance.new("UIGradient"); gradient.Rotation=90
        gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,.96),
            NumberSequenceKeypoint.new(.42,.18),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.58,.18),
            NumberSequenceKeypoint.new(.82,.96),NumberSequenceKeypoint.new(1,1)}); gradient.Parent=ray
    end
    for i=1,6 do
        local ray=W.box(self.wideRays,"WideRay"..i,260,260,48,510,pale,2)
        ray.AnchorPoint=Vector2.new(.5,.5); ray.Rotation=(i-1)*180/6+10
        local gradient=Instance.new("UIGradient"); gradient.Rotation=90
        gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.35,.8),
            NumberSequenceKeypoint.new(.5,.35),NumberSequenceKeypoint.new(.65,.8),NumberSequenceKeypoint.new(1,1)}); gradient.Parent=ray
    end
    self.impact=ring(stage,"ImpactRing",260,5); self.echo=ring(stage,"EchoRing",220,2)
    self.sparks={}
    for i=1,10 do
        local spark=centered(stage,"Spark"..i,9,9,i%2==0 and pale or gold,4)
        spark.Rotation=45; self.sparks[i]=spark
    end
    self.shadow=W.box(stage,"StampShadow",290,446,220,24,Color3.new(0,0,0),2)
    self.shadow.AnchorPoint=Vector2.new(.5,.5); W.round(self.shadow)
    self.holder=centered(stage,"ReceivedItem",300,300,nil,5)
    self.icon=Instance.new("ImageLabel"); self.icon.Name="ColorIcon"; self.icon.BackgroundTransparency=1
    self.icon.Size=UDim2.fromScale(1,1); self.icon.ScaleType=Enum.ScaleType.Fit
    if not require(script.Parent.BatchOneVisuals).apply(self.icon,item) then self.icon.Image=Art[item.category] or "" end; self.icon.Parent=self.holder
    self.flash=W.box(root,"StampFlash",0,0,0,0,pale,10); self.flash.Size=UDim2.fromScale(1,1)
    self.flash.BackgroundTransparency=1; self.flash.Active=false
    -- Prepare the actual ImageLabel during the spin, including its first engine render.
    task.spawn(function() pcall(function() Content:PreloadAsync({self.icon}) end) end)
    self:render(0); root:SetAttribute("Phase","prepared")
    return self
end
function Unlock:play()
    -- Loading never blocks motion, even if asset delivery is late.
    self.root.Visible=true; self.started=os.clock(); self:render(0)
    self.connection=Run.RenderStepped:Connect(function()
        self:render(os.clock()-self.started)
    end)
end
function Unlock:render(t)
    if self.ready and t>=2.2 then
        self.rays.Rotation=t*28; self.wideRays.Rotation=-t*17
        return
    end
    local enter=ease(phase(t,0,.25)); local age=t-impactAt
    local scale,y,rotation
    if t<.25 then scale=mix(.28,.78,enter); y=mix(350,290,enter); rotation=mix(-15,-5,enter)
    elseif t<1.08 then
        local up=ease(phase(t,.25,1.08)); scale=mix(.78,1.34,up); y=mix(290,204,up); rotation=mix(-5,9,up)
    elseif t<impactAt then
        local down=phase(t,1.08,impactAt)^3; scale=mix(1.34,.87,down); y=mix(204,290,down); rotation=mix(9,2.5,down)
    else
        scale=1-.13*math.exp(-10*age)*math.cos(24*age)
        y=290+6*math.exp(-15*age)*math.sin(38*age); rotation=2.5*math.exp(-12*age)*math.cos(32*age)
    end
    local squash=age>=0 and .13*math.exp(-15*age)*math.sin(math.min(age/.12,1)*math.pi) or 0
    self.holder.Size=UDim2.fromOffset(300*scale*(1+squash),300*scale*(1-squash))
    self.holder.Position=UDim2.fromOffset(290,y); self.holder.Rotation=rotation
    self.icon.ImageTransparency=1-enter
    self.glow.GroupTransparency=1-ease(phase(t,.2,1.3))*.96
    self.rays.Rotation=t*28; self.wideRays.Rotation=-t*17
    self.shadow.Size=UDim2.fromOffset(220*math.min(scale,1.15),24); self.shadow.BackgroundTransparency=1-.42*enter
    local pulse=phase(t,impactAt,impactAt+.65)
    self.impact.frame.Size=UDim2.fromOffset(260+330*pulse,260+330*pulse)
    self.impact.stroke.Transparency=age<0 and 1 or 1-(1-pulse)*.9
    local echo=phase(t,impactAt+.12,impactAt+.85)
    self.echo.frame.Size=UDim2.fromOffset(220+370*echo,220+370*echo)
    self.echo.stroke.Transparency=t<impactAt+.12 and 1 or 1-(1-echo)*.7
    for i,spark in self.sparks do
        local angle=(i-1)*math.pi*2/#self.sparks; local travel=phase(t,impactAt,impactAt+.9)
        local radius=130+165*ease(travel)
        spark.Position=UDim2.fromOffset(290+math.cos(angle)*radius,290+math.sin(angle)*radius)
        spark.Rotation=45+travel*120; spark.BackgroundTransparency=age<0 and 1 or travel
    end
    self.flash.BackgroundTransparency=age>=0 and 1-.14*(1-phase(t,impactAt,impactAt+.12)) or 1
    self.root:SetAttribute("Phase",t<1.08 and "lift" or t<impactAt and "stamp" or t<2 and "impact" or "settled")
    if t>=2 and not self.ready then self.ready=true; if self.onReady then self.onReady() end end
end
function Unlock:destroy()
    if self.connection then self.connection:Disconnect(); self.connection=nil end
    self.root:Destroy()
end
return Unlock
