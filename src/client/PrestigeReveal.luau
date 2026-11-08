local Run=game:GetService("RunService")
local Content=game:GetService("ContentProvider")
local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local shared=game.ReplicatedStorage.NOVA
local Catalog=require(shared.RankIcons)
local Gray=require(shared.PrestigeRevealArt)
local Info=require(shared.ProgressionInfo)
local W=require(script.Parent.Widgets)
local C=W.colors
local Reveal={}
Reveal.__index=Reveal
local gold=Color3.fromRGB(255,222,91)
local pale=Color3.fromRGB(255,247,191)
local impactAt=1.24
local duration=5.1

local function phase(t,a,b) return math.clamp((t-a)/(b-a),0,1) end
local function ease(t) return 1-(1-t)^3 end
local function mix(a,b,t) return a+(b-a)*t end
local function centered(parent,name,w,h,color,z)
    local frame=W.box(parent,name,0,0,w,h,color,z)
    frame.AnchorPoint=Vector2.new(.5,.5)
    frame.Position=UDim2.fromScale(.5,.5)
    return frame
end
local function ring(parent,name,size,thickness)
    local frame=centered(parent,name,size,size,nil,4)
    W.round(frame); W.stroke(frame,gold,thickness)
    return frame,frame:FindFirstChildOfClass("UIStroke")
end

function Reveal.new(gui,onFinished)
    local self=setmetatable({onFinished=onFinished,prepared={}},Reveal)
    local root=W.box(gui,"PrestigeReveal",0,0,0,0,C.ink,40)
    root.Size=UDim2.fromScale(1,1); root.Active=true; root.Visible=false
    self.root=root
    local origin=W.box(root,"Origin",0,0,0,0)
    origin.Position=UDim2.fromScale(.5,.5)
    local fit=Instance.new("UIScale"); fit.Parent=origin
    local function resize() fit.Scale=math.max(.01,math.min(1.25,(root.AbsoluteSize.X-32)/940,(root.AbsoluteSize.Y-32)/650)) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
    local stage=W.box(origin,"Stage",-470,-325,940,650)
    self.stage=stage
    self.glow=Instance.new("CanvasGroup")
    self.glow.Name="GoldenGlow"; self.glow.BackgroundTransparency=1
    self.glow.Size=UDim2.fromOffset(580,580); self.glow.AnchorPoint=Vector2.new(.5,.5)
    self.glow.Position=UDim2.fromOffset(470,280); self.glow.ZIndex=1; self.glow.Parent=stage
    for i=1,12 do
        local size=580-(i-1)*30
        local disk=centered(self.glow,"SoftAura"..i,size,size,gold,1)
        W.round(disk); disk.BackgroundTransparency=.97
    end
    self.rays=centered(self.glow,"RadialRays",580,580,nil,2)
    self.wideRays=centered(self.glow,"WideRays",520,520,nil,2)
    for i=1,14 do
        local ray=centered(self.rays,"Ray"..i,18,570,gold,2)
        ray.Rotation=(i-1)*180/14
        local gradient=Instance.new("UIGradient")
        gradient.Rotation=90
        gradient.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,.96),
            NumberSequenceKeypoint.new(.42,.18),NumberSequenceKeypoint.new(.5,0),
            NumberSequenceKeypoint.new(.58,.18),NumberSequenceKeypoint.new(.82,.96),NumberSequenceKeypoint.new(1,1)})
        gradient.Parent=ray
    end
    for i=1,6 do
        local ray=centered(self.wideRays,"WideRay"..i,48,510,pale,2)
        ray.Rotation=(i-1)*180/6+10
        local gradient=Instance.new("UIGradient"); gradient.Rotation=90
        gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
            NumberSequenceKeypoint.new(.35,.8),NumberSequenceKeypoint.new(.5,.35),
            NumberSequenceKeypoint.new(.65,.8),NumberSequenceKeypoint.new(1,1)})
        gradient.Parent=ray
    end
    local impact=W.box(stage,"Impact",470,280,0,0)
    self.impact,self.impactStroke=ring(impact,"ImpactRing",260,5)
    self.echo,self.echoStroke=ring(impact,"EchoRing",220,2)
    self.sparkles={}
    for i=1,10 do
        local spark=W.box(stage,"Spark"..i,470,280,9,9,i%2==0 and pale or gold,4)
        spark.AnchorPoint=Vector2.new(.5,.5); spark.Rotation=45
        self.sparkles[i]=spark
    end
    self.shadow=W.box(stage,"StampShadow",470,436,220,24,Color3.new(0,0,0),2)
    self.shadow.AnchorPoint=Vector2.new(.5,.5); W.round(self.shadow)
    self.holder=W.box(stage,"Icon",470,280,300,300,nil,5)
    self.holder.AnchorPoint=Vector2.new(.5,.5)
    for _,name in {"GrayIcon","ColorIcon"} do
        local image=Instance.new("ImageLabel")
        image.Name=name; image.BackgroundTransparency=1; image.Size=UDim2.fromScale(1,1)
        image.ScaleType=Enum.ScaleType.Fit; image.ZIndex=name=="GrayIcon" and 1 or 2; image.Parent=self.holder
        self[name]=image
    end
    self.heading=W.text(stage,"Heading",90,18,760,32,"PRESTIGE UNLOCKED",21,gold,Enum.Font.GothamBold)
    self.title=W.text(stage,"Rank",70,478,800,52,"",40,C.white,Enum.Font.GothamBlack)
    self.item=W.text(stage,"Item",70,538,800,30,"",18,pale,Enum.Font.GothamBold)
    self.loading=W.text(stage,"Loading",170,264,600,32,"Revealing your new rank…",18,pale,Enum.Font.GothamBold)
    self.loading.TextXAlignment=Enum.TextXAlignment.Center
    for _,label in {self.heading,self.title,self.item} do label.TextXAlignment=Enum.TextXAlignment.Center end
    self.continue=W.button(stage,"Continue",382,594,176,40,"Continue",true)
    self.continue.BackgroundColor3=gold; self.continue.TextColor3=C.ink
    self.continue.Activated:Connect(function() self:hide(true) end)
    self.flash=W.box(root,"StampFlash",0,0,0,0,pale,10)
    self.flash.Size=UDim2.fromScale(1,1); self.flash.Active=false
    return self
end

function Reveal:prepare(data)
    local entry=Catalog.get(data)
    if not entry or not Gray[entry.key] or self.prepared[entry.key] then return end
    self.prepared[entry.key]=true
    task.spawn(function() pcall(function() Content:PreloadAsync({entry.image,Gray[entry.key]}) end) end)
end

function Reveal:play(data)
    local entry=Catalog.get(data)
    if not entry or not Gray[entry.key] or self.lastKey==entry.key then return false end
    self:hide(false)
    self:prepare(data)
    self.lastKey=entry.key
    self.active=true; self.ready=false
    self.root.Visible=true
    self.root:SetAttribute("RankKey",entry.key)
    self.root:SetAttribute("Phase","loading")
    self.GrayIcon.Image=Gray[entry.key]; self.ColorIcon.Image=entry.image
    self.title.Text=Info.title(Info.current(data)); self.item.Text=entry.name
    Gui.SelectedObject=nil
    self.waitStart=os.clock(); self.started=nil
    self:render(0)
    self.loading.Visible=true
    self.root:SetAttribute("Phase","loading")
    self.connection=Run.RenderStepped:Connect(function()
        if not self.started then
            if not (self.GrayIcon.IsLoaded and self.ColorIcon.IsLoaded) and os.clock()-self.waitStart<4 then return end
            self.loading.Visible=false
            self.started=os.clock()
        end
        local elapsed=os.clock()-self.started
        self:render(elapsed)
        if elapsed>=duration then self:hide(true) end
    end)
    return true
end

function Reveal:render(t)
    local enter=ease(phase(t,0,.25))
    local fade=1-phase(t,4.55,duration)
    local color=ease(phase(t,.55,1.08))
    local impactTime=t-impactAt
    local scale,y,rotation
    if t<.25 then
        scale=mix(.28,.78,enter); y=mix(340,280,enter); rotation=mix(-15,-5,enter)
    elseif t<1.08 then
        local up=ease(phase(t,.25,1.08))
        scale=mix(.78,1.34,up); y=mix(280,194,up); rotation=mix(-5,9,up)
    elseif t<impactAt then
        local down=phase(t,1.08,impactAt)^3
        scale=mix(1.34,.87,down); y=mix(194,280,down); rotation=mix(9,2.5,down)
    else
        scale=1-.13*math.exp(-10*impactTime)*math.cos(24*impactTime)
        y=280+6*math.exp(-15*impactTime)*math.sin(38*impactTime)
        rotation=2.5*math.exp(-12*impactTime)*math.cos(32*impactTime)
    end
    local squash=impactTime>=0 and .13*math.exp(-15*impactTime)*math.sin(math.min(impactTime/.12,1)*math.pi) or 0
    self.holder.Size=UDim2.fromOffset(300*scale*(1+squash),300*scale*(1-squash))
    self.holder.Position=UDim2.fromOffset(470,y); self.holder.Rotation=rotation
    self.GrayIcon.ImageTransparency=1-enter*(1-color)*fade
    self.ColorIcon.ImageTransparency=1-enter*color*fade
    self.root.BackgroundTransparency=1-.9*fade
    self.glow.GroupTransparency=1-ease(phase(t,.2,1.3))*.96*fade
    self.rays.Rotation=t*28; self.wideRays.Rotation=-t*17
    self.shadow.Size=UDim2.fromOffset(220*math.min(scale,1.15),24)
    self.shadow.BackgroundTransparency=1-.42*enter*fade
    local pulse=phase(t,impactAt,impactAt+.65)
    self.impact.Size=UDim2.fromOffset(260+330*pulse,260+330*pulse)
    self.impactStroke.Transparency=impactTime<0 and 1 or 1-(1-pulse)*.9*fade
    local echo=phase(t,impactAt+.12,impactAt+.85)
    self.echo.Size=UDim2.fromOffset(220+370*echo,220+370*echo)
    self.echoStroke.Transparency=t<impactAt+.12 and 1 or 1-(1-echo)*.7*fade
    for i,spark in self.sparkles do
        local angle=(i-1)*math.pi*2/#self.sparkles
        local travel=phase(t,impactAt,impactAt+.9)
        local radius=130+165*ease(travel)
        spark.Position=UDim2.fromOffset(470+math.cos(angle)*radius,280+math.sin(angle)*radius)
        spark.Rotation=45+travel*100
        spark.BackgroundTransparency=impactTime<0 and 1 or 1-(1-travel)*fade
    end
    self.flash.BackgroundTransparency=impactTime>=0 and 1-.28*math.exp(-20*impactTime)*fade or 1
    self.heading.TextTransparency=1-fade
    self.title.TextTransparency=1-ease(phase(t,impactAt,1.65))*fade
    self.item.TextTransparency=1-ease(phase(t,1.45,1.85))*fade
    self.continue.Visible=t>=2
    self.continue.Active=t>=2; self.continue.Selectable=t>=2
    self.continue.BackgroundTransparency=1-fade; self.continue.TextTransparency=1-fade
    if t>=2 and not self.ready then
        self.ready=true
        if UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=self.continue end
    end
    local state=t<.55 and "grayscale" or t<1.08 and "colorizing" or t<1.56 and "stamp" or "settled"
    if self.root:GetAttribute("Phase")~=state then self.root:SetAttribute("Phase",state) end
end

function Reveal:hide(notify)
    local wasActive=self.active
    self.active=false
    if self.connection then self.connection:Disconnect(); self.connection=nil end
    self.root.Visible=false
    if wasActive then
        self.root:SetAttribute("Phase","closed")
        if notify and self.onFinished then self.onFinished() end
    end
end

return Reveal
