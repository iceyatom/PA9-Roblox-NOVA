local W=require(script.Parent.Widgets)
local C=W.colors
local Cosmetics=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Preview=require(script.Parent.InventoryPreview)
local function equipment()
    local result={}
    for category in Cosmetics.defaults do result[category]=game.Players.LocalPlayer:GetAttribute("Cosmetic_"..category) end
    return result
end
local Batch=require(script.Parent.BatchOneVisuals)
local Tween=game:GetService("TweenService")
local PracticeHud={}
PracticeHud.__index=PracticeHud

function PracticeHud.new(playerGui,send)
    local self=setmetatable({send=send,pulses={}},PracticeHud)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVAPractice"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=11
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Enabled=false; gui.Parent=playerGui
    self.gui=gui
    local root=W.box(gui,"Backdrop",0,0,0,0,C.ink); root.Size=UDim2.fromScale(1,1)
    local origin=W.box(root,"Origin",0,0,0,0); origin.Position=UDim2.fromScale(.5,.5)
    local scale=Instance.new("UIScale"); scale.Parent=origin
    local function resize() scale.Scale=math.max(.01,math.min(root.AbsoluteSize.X/1440,root.AbsoluteSize.Y/810)) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
    local stage=W.box(origin,"Stage",-720,-405,1440,810,C.ink); self.stage=stage
    W.text(stage,"Kicker",70,36,650,24,"NOVA / SOLO CHALLENGE",17,C.mint)
    W.text(stage,"Title",68,66,750,52,"High Score Practice",43,C.white,Enum.Font.GothamBlack)
    W.text(stage,"Subtitle",70,126,800,24,"30 seconds to shoot as many times as possible!",19,C.muted)
    self.leave=W.button(stage,"Leave",1190,40,180,44,"Lobby",false)
    self.leave.Activated:Connect(function() send("leave") end)
    local field=W.box(stage,"PracticeMap",70,213,1300,380,W.rgb("0c1220")); self.field=field; field.ClipsDescendants=true
    W.stroke(field,C.line)
    for x=30,1280,40 do W.box(field,"Grid",x,20,1,300,W.rgb("172131")) end
    for y=20,300,40 do W.box(field,"Grid",20,y,1260,1,W.rgb("172131")) end
    W.box(field,"Floor",0,315,1300,65,W.rgb("182535"))
    W.box(field,"FloorEdge",0,315,1300,3,C.mint)
    local body=W.box(field,"Player",217,278,36,36,C.blue,5); self.body=body
    local playerLabel=W.text(field,"PlayerLabel",235,237,150,25,"YOU",17,C.blue)
    playerLabel.AnchorPoint=Vector2.new(.5,0)
    playerLabel.TextXAlignment=Enum.TextXAlignment.Center
    local target=W.box(field,"Target",1032,278,36,36,C.red,5); self.target=target
    local targetLabel=W.text(field,"TargetLabel",1050,237,210,25,"TARGET",17,C.red)
    targetLabel.AnchorPoint=Vector2.new(.5,0)
    targetLabel.TextXAlignment=Enum.TextXAlignment.Center
    W.text(stage,"TimeLabel",72,632,300,24,"TIME REMAINING",16,C.muted)
    self.timer=W.text(stage,"Timer",70,660,280,64,"30.00",54,C.white,Enum.Font.GothamBlack)
    W.text(stage,"ScoreLabel",535,632,300,24,"SHOTS ON TARGET",16,C.mint)
    self.score=W.text(stage,"Score",535,660,300,64,"0",54,C.white,Enum.Font.GothamBlack)
    self.hint=W.text(stage,"Hint",70,758,1000,24,"Press Fire once per shot. Movement is locked.",17,C.muted)
    self.fire=W.button(stage,"Fire",1080,657,290,62,"FIRE",true)
    self.fire.BackgroundColor3=C.mint; self.fire.TextColor3=C.ink
    self.fire.Activated:Connect(function() if self.snap and self.snap.phase=="Playing" then send("fire") end end)
    local track=W.box(stage,"TimeTrack",70,187,1300,5,C.line)
    self.progress=W.box(track,"Fill",0,0,1300,5,C.mint)
    local overlay=W.box(field,"Countdown",0,0,1300,380,C.ink,20); overlay.BackgroundTransparency=.16
    self.overlay=overlay
    local numeral=W.text(overlay,"Number",350,65,600,220,"3",170,C.white,Enum.Font.GothamBlack)
    numeral.TextXAlignment=Enum.TextXAlignment.Center; numeral.ZIndex=21; numeral.AnchorPoint=Vector2.new(.5,.5)
    numeral.Position=UDim2.fromOffset(650,170); self.numeral=numeral
    local pop=Instance.new("UIScale"); pop.Parent=numeral; self.pop=pop
    local ready=W.text(overlay,"Ready",350,290,600,35,"GET READY",24,C.mint)
    ready.TextXAlignment=Enum.TextXAlignment.Center; ready.ZIndex=21; self.ready=ready
    local result=W.box(stage,"Results",410,258,620,292,C.panel,30); self.result=result; result.Visible=false
    W.stroke(result,C.mint,2)
    local function resultText(name,y,value,size,color)
        local t=W.text(result,name,30,y,560,45,value,size,color,Enum.Font.GothamBold)
        t.ZIndex=31; t.TextXAlignment=Enum.TextXAlignment.Center; return t
    end
    resultText("Kicker",12,"TIME'S UP",18,C.mint)
    self.final=resultText("Final",54,"0 SHOTS",48,C.white)
    self.best=resultText("Best",108,"",20,C.muted)
    self.saved=resultText("Saved",151,"",16,C.muted)
    self.retry=W.button(result,"Retry",35,221,265,45,"Try again",true); self.retry.ZIndex=32
    local back=W.button(result,"Lobby",320,221,265,45,"Back to lobby",false); back.ZIndex=32
    self.retry.Activated:Connect(function() send("retry") end); back.Activated:Connect(function() send("leave") end)
    return self
end

function PracticeHud:pulse()
    local equipped=equipment()
    local bullet=Cosmetics.get(equipped,"bullets")
    local tracer=Cosmetics.get(equipped,"tracers")
    local pulse=W.box(self.field,"Shot",253,293,20,6,bullet.default and C.mint or Preview.color(bullet),8)
    if bullet.setId or (bullet.visual=="prism_veil" or bullet.visual=="dragonforge" or bullet.visual=="riftglass" or bullet.visual=="cipher" or bullet.visual=="supernova" or bullet.visual=="starfade" or bullet.visual=="armory") then pulse.Size=UDim2.fromOffset(9,9); W.round(pulse); Batch.overlay(pulse,bullet,"bullets") end
    local trail
    if tracer.length and tracer.length>0 then
        trail=W.box(pulse,"Tracer",0,0,0,4,Preview.color(tracer))
        if (tracer.setId or (tracer.visual=="prism_veil" or tracer.visual=="dragonforge" or tracer.visual=="riftglass" or tracer.visual=="cipher" or tracer.visual=="supernova" or tracer.visual=="starfade" or tracer.visual=="armory")) and not Batch.reduced() then
            trail.Size=UDim2.fromOffset(0,11); trail.BackgroundTransparency=1; Batch.overlay(trail,tracer,"wakes")
        end
    end
    Preview.sound(self.field,Cosmetics.get(equipped,"sounds"))
    table.insert(self.pulses,{frame=pulse,at=os.clock(),trail=trail,tracer=tracer})
end
function PracticeHud:update(snap)
    Batch.overlay(self.body,Cosmetics.get(equipment(),"skins"),"skins")
    self.body.BackgroundColor3=Preview.color(Cosmetics.get(equipment(),"skins"))
    local old=self.snap
    if not old or old.id~=snap.id then
        self.lastNumber=nil
        for _,p in self.pulses do p.frame:Destroy() end
        table.clear(self.pulses)
    elseif snap.score>old.score then
        for _=1,math.min(snap.score-old.score,10) do self:pulse() end
    end
    self.snap=snap; self.gui.Enabled=true
    self.score.Text=tostring(snap.score)
    self.fire.Visible=snap.phase=="Playing"
    self.result.Visible=snap.phase=="Results"
    self.final.Text=("%d SHOTS"):format(snap.score)
    self.best.Text=("PERSONAL BEST / %d"):format(snap.best or snap.score)
    self.saved.Text=({SessionOnly="Studio preview / score saved for this session",Saving="Saving your best to the global leaderboard…",
        Saved="Best score saved to the global leaderboard",Retrying="Save delayed / automatically retrying"})[snap.saveStatus] or ""
    self:tick()
end
function PracticeHud:hide()
    if self.snap then Preview.stopSounds(self.field) end
    self.gui.Enabled=false; self.snap=nil
    for _,p in self.pulses do p.frame:Destroy() end
    table.clear(self.pulses)
end
function PracticeHud:tick()
    local snap=self.snap
    if not snap or not self.gui.Enabled then return end
    local now=workspace:GetServerTimeNow()
    local left=snap.phase=="Countdown" and 30 or snap.phase=="Results" and 0 or math.clamp(snap.ends-now,0,30)
    self.timer.Text=("%05.2f"):format(left)
    self.timer.TextColor3=left<=5 and C.red or C.white
    self.progress.Size=UDim2.fromOffset(1300*left/30,5)
    local count=math.ceil(snap.starts-now)
    local go=snap.phase=="Playing" and now-snap.starts<.6
    self.overlay.Visible=snap.phase=="Countdown" or go
    if self.overlay.Visible then
        local value=go and "GO!" or tostring(math.clamp(count,1,3))
        if value~=self.lastNumber then
            self.lastNumber=value; self.numeral.Text=value
            self.numeral.TextColor3=go and C.mint or C.white
            self.ready.Text=go and "FIRE AS FAST AS YOU CAN" or "GET READY / FIRE UNLOCKS AT GO"
            if self.countTween then self.countTween:Cancel() end
            self.pop.Scale=1.45
            self.countTween=Tween:Create(self.pop,TweenInfo.new(.48,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
            self.countTween:Play()
        end
    end
    local clock=os.clock()
    for i=#self.pulses,1,-1 do
        local p=self.pulses[i]; local alpha=(clock-p.at)/.24
        if alpha>=1 then p.frame:Destroy(); table.remove(self.pulses,i)
        else
            p.frame.Position=UDim2.fromOffset(253+779*alpha,293)
            if p.trail then
                local length=math.min(alpha*779,p.tracer.length*24)
                p.trail.Position=UDim2.fromOffset(-length,0); p.trail.Size=UDim2.fromOffset(length,p.trail.Size.Y.Offset)
                local art=p.trail:FindFirstChild("BatchArt")
                if art then Batch.apply(art,p.tracer,"wakes",math.floor(clock*18)%p.tracer.frames) end
            end
        end
    end
end
return PracticeHud
