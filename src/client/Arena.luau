local shared=game.ReplicatedStorage.NOVA
local Maps=require(shared.Map1)
local cfg=require(shared.Config)
local catalog=require(shared.TileCatalog)
local W=require(script.Parent.Widgets)
local C=W.colors
local Cosmetics=require(shared.InventoryCatalog)
local Preview=require(script.Parent.InventoryPreview)
local Batch=require(script.Parent.BatchOneVisuals)
local Arena={}
Arena.__index=Arena

function Arena.new(stage,selectedMap)
    local map=selectedMap or Maps.active()
    local self=setmetatable({map=map,stage=stage},Arena)
    local unit=math.min(cfg.TilePixels,890/map.width,667/map.height)
    self.unit=unit
    local width,height=unit*map.width,unit*map.height
    local field=W.box(stage,"Map1",(1440-width)/2,76+(667-height)/2,width,height,W.rgb("080911"))
    field.ClipsDescendants=true
    self.field=field
    self.tailPool={}; self.tailCount=0
    self.mobile=game:GetService("UserInputService").TouchEnabled
    self.low=self.mobile; self.windowSeconds=0; self.windowFrames=0; self.slowFrames=0; self.headroom=0
    W.stroke(field,C.line,1)
    local function rect(parent,name,x,y,w,h,color,z)
        return W.box(parent,name,x*unit,y*unit,w*unit,h*unit,color,z)
    end
    -- Subtle grid intersections remain visible in open space.
    for x=2,map.width-1,2 do
        for y=2,map.height-1,2 do rect(field,"GridPoint",x,y,0.055,0.055,W.rgb("303044")) end
    end
    local styles={wall=W.rgb("21133d"),platform=C.dark,shield=C.light,launch=C.mint,beacon=W.rgb("e7d342"),marker=W.rgb("398756")}
    for _,r in map.rects do
        local style=catalog[r.id].style
        rect(field,style,r.x,r.y,r.x2-r.x,r.y2-r.y,styles[style],2)
    end
    -- Draw only exposed tile faces to retain the continuous purple contours.
    local function wall(x,y)
        local row=map.rows[y+1]
        return x>=0 and row and row:sub(x+1,x+1)=="P"
    end
    local edge=0.22
    for y=0,map.height-1 do
        for x=0,map.width-1 do
            if wall(x,y) then
                if not wall(x-1,y) then rect(field,"Edge",x,y,edge,1,C.purple,3) end
                if not wall(x+1,y) then rect(field,"Edge",x+1-edge,y,edge,1,C.purple,3) end
                if not wall(x,y-1) then rect(field,"Edge",x,y,1,edge,C.purple,3) end
                if not wall(x,y+1) then rect(field,"Edge",x,y+1-edge,1,edge,C.purple,3) end
                for _,dx in {-1,1} do
                    for _,dy in {-1,1} do
                        if wall(x+dx,y) and wall(x,y+dy) and not wall(x+dx,y+dy) then
                            rect(field,"Corner",x+(dx==1 and 1-edge or 0),y+(dy==1 and 1-edge or 0),edge,edge,C.purple,3)
                        end
                    end
                end
            end
        end
    end
    self.diagnostics=W.box(field,"CollisionMasks",0,0,width,height,nil,6)
    self.diagnostics.Visible=false
    for _,r in map.rects do
        local tile=catalog[r.id]
        if tile.body or tile.shot or tile.launch then
            local outline=rect(self.diagnostics,r.id,r.x,r.y,r.x2-r.x,r.y2-r.y)
            W.stroke(outline,tile.launch and C.mint or tile.body and tile.shot and C.white or tile.body and C.red or C.light,1)
        end
    end
    for i,spawn in map.spawns do
        rect(self.diagnostics,"Spawn"..i,spawn.X-0.4,spawn.Y-0.05,0.8,0.1,C.purple)
        rect(self.diagnostics,"Spawn"..i,spawn.X-0.05,spawn.Y-0.4,0.1,0.8,C.purple)
    end
    self.actors={}
    self.shots={}
    for i=1,2 do
        local color=i==1 and C.blue or C.red
        local body=rect(field,"Player"..i,0,0,cfg.BodyWidth,cfg.BodyHeight,color,5)
        body.AnchorPoint=Vector2.new(0.5,0.5)
        local label=W.text(body,"Name",-55,-27,unit*cfg.BodyWidth+110,17,"",14,C.white,Enum.Font.GothamBold)
        label.TextXAlignment=Enum.TextXAlignment.Center
        local track=W.box(body,"Health",0,-7,unit*cfg.BodyWidth,3,C.line,5)
        local bar=W.box(track,"Fill",0,0,0,3,C.mint,6)
        local box=rect(body,"BodyMask",0,0,cfg.BodyWidth,cfg.BodyHeight)
        W.stroke(box,C.purple,2)
        box.Visible=false
        self.actors[i]={body=body,label=label,bar=bar,box=box,color=color,hp=cfg.Health,flash=0}
        body.Visible=false
    end
    return self
end

function Arena:releaseShot(id,shot)
    shot.frame:Destroy(); shot.trace:Destroy()
    if shot.tail then
        shot.tail.Visible=false
        table.insert(self.tailPool,shot.tail)
    end
    self.shots[id]=nil
end
function Arena:clearShots()
    Preview.stopSounds(self.field)
    for id,shot in self.shots do self:releaseShot(id,shot) end
    self.received=nil; self.round=nil
end
function Arena:tail(tracer)
    if not tracer.length or tracer.length<=0 then return nil end
    local limit=(self.low or Batch.reduced()) and 64 or 128
    if self.tailCount-#self.tailPool>=limit then return nil end
    local node=table.remove(self.tailPool)
    if not node then
        node=Instance.new("ImageLabel"); self.tailCount+=1
        node.Name="CosmeticTracer"; node.AnchorPoint=Vector2.new(.5,.5)
        node.BorderSizePixel=0; node.ZIndex=4
    end
    node.BackgroundColor3=Preview.color(tracer); node.BackgroundTransparency=.2
    Batch.clear(node)
    node.Image=""; node.Visible=false; node.Parent=self.field
    return node
end
function Arena:setMap(id)
    if self.map.id==id then return end
    local masks=self.diagnostics.Visible
    self.field:Destroy()
    local replacement=Arena.new(self.stage,Maps.load(id))
    for key in self do self[key]=nil end
    for key,value in replacement do self[key]=value end
    self.diagnostics.Visible=masks
end

function Arena:update(snap,time)
    local unit=self.unit
    local changed=self.round~=snap.round or self.lobby~=snap.lobby
    self.lobby=snap.lobby
    self.round=snap.round
    if changed then
        Preview.stopSounds(self.field)
        for id,shot in self.shots do self:releaseShot(id,shot) end
    end
    self.received=time
    for i,p in snap.players do
        local actor=self.actors[i]
        actor.body.Visible=p.uid~=nil
        actor.label.Text=p.name or ""
        Batch.overlay(actor.body,Cosmetics.get(p.cosmetics,"skins"),"skins")
        local accepted=p.acceptedShots or 0
        if not changed and actor.accepted and accepted>actor.accepted then
            for _=1,math.min(8,accepted-actor.accepted) do Preview.sound(self.field,Cosmetics.get(p.cosmetics,"sounds")) end
        end
        actor.accepted=accepted
        actor.color=p.uid and Preview.color(Cosmetics.get(p.cosmetics,"skins")) or (i==1 and C.blue or C.red)
        if Cosmetics.get(p.cosmetics,"skins").default then actor.color=i==1 and C.blue or C.red end
        if not changed and p.hp<actor.hp then actor.flash=time+0.13 end
        actor.hp=p.hp
        actor.bar.Size=UDim2.fromScale(p.hp/snap.maxHP,1)
        actor.target=Vector2.new(p.x,p.y)
    end
    local seen={}
    for _,b in snap.shots do
        local id=b[1]
        local shot=self.shots[id]
        if not shot then
            local equipped=snap.players[b[4]].cosmetics
            local bullet=Cosmetics.get(equipped,"bullets")
            local tracer=Cosmetics.get(equipped,"tracers")
            local color=bullet.default and (b[4]==1 and C.blue or C.red) or Preview.color(bullet)
            local diameter=2*cfg.BulletRadius*unit
            local glow=W.box(self.field,"Pulse",0,0,diameter*2.6,diameter*2.6,color,4)
            glow.AnchorPoint=Vector2.new(0.5,0.5)
            glow.BackgroundTransparency=0.62
            W.round(glow)
            local core=Instance.new("ImageLabel")
            core.Name="Core"; core.Position=UDim2.fromOffset(diameter*.8,diameter*.8)
            core.Size=UDim2.fromOffset(diameter,diameter); core.BackgroundColor3=Preview.color(bullet)
            core.BorderSizePixel=0; core.ZIndex=5
            if bullet.setId or bullet.visual=="prism_veil" then
                Batch.apply(core,bullet,"bullets")
                if bullet.setId then
                    core.ImageRectOffset+=Vector2.new(35,35); core.ImageRectSize=Vector2.new(186,186)
                    glow.BackgroundColor3=b[4]==1 and C.blue or C.red
                end
                core.BackgroundTransparency=1
            end
            W.round(core); core.Parent=glow
            local trace=W.box(self.field,"Sweep",0,0,1,1,C.purple,6)
            trace.AnchorPoint=Vector2.new(0.5,0.5)
            shot={frame=glow,trace=trace,tail=self:tail(tracer),tracer=tracer,
                origin=Vector2.new(b[2],b[3]),tailLength=tracer.length or 0}
            self.shots[id]=shot

        end
        seen[id]=true
        shot.target=Vector2.new(b[2],b[3])
        local velocity=Vector2.new(b[5],b[6])
        shot.direction=velocity.Magnitude>0 and velocity.Unit or Vector2.xAxis
        shot.start=shot.draw or shot.target
        local segment=velocity*cfg.Step
        local mid=(shot.target-segment/2)*unit
        shot.trace.Position=UDim2.fromOffset(mid.X,mid.Y)
        shot.trace.Size=UDim2.fromOffset(segment.Magnitude*unit,2)
        shot.trace.Rotation=math.deg(math.atan2(segment.Y,segment.X))
    end
    for id,shot in self.shots do
        if not seen[id] then self:releaseShot(id,shot) end
    end
end

function Arena:draw(time,dt)
    if not self.received then return end
    dt=dt or 1/60
    local target=self.mobile and 1/30 or 1/60
    self.windowSeconds+=dt
    self.windowFrames+=1
    if dt>target*1.04 then self.slowFrames+=1 end
    if self.windowSeconds>=2 then
        if self.slowFrames>self.windowFrames*.05 then
            self.low=true; self.headroom=0
        else
            self.headroom+=self.windowSeconds
            if self.headroom>=10 then self.low=false end
        end
        self.windowSeconds=0; self.windowFrames=0; self.slowFrames=0
    end
    local simple=Batch.reduced() or self.low
    local active=0
    local alpha=math.clamp((time-self.received)*cfg.SnapshotRate,0,1)
    for _,actor in self.actors do
        actor.body.Position=UDim2.fromOffset(actor.target.X*self.unit,actor.target.Y*self.unit)
        actor.body.BackgroundColor3=time<actor.flash and C.white or actor.color
        local art=actor.body:FindFirstChild("BatchArt")
        if art then art.Visible=time>=actor.flash end
        actor.box.Visible=self.diagnostics.Visible
    end
    for _,shot in self.shots do
        shot.draw=shot.start:Lerp(shot.target,alpha)
        shot.frame.Position=UDim2.fromOffset(shot.draw.X*self.unit,shot.draw.Y*self.unit)
        if shot.tail then
            active+=1
            local length=math.min(shot.tailLength*(simple and .65 or 1),(shot.draw-shot.origin).Magnitude)
            local mid=shot.draw-shot.direction*length/2
            local dynamic=shot.tracer.visual=="prism_veil"
            local animated=dynamic or not simple and shot.tracer.setId~=nil
            shot.tail.Visible=length>0 and active<=(simple and 64 or 128)
            shot.tail.Position=UDim2.fromOffset(mid.X*self.unit,mid.Y*self.unit)
            shot.tail.Size=UDim2.fromOffset(length*self.unit,animated and 3*cfg.BulletRadius*self.unit or 3)
            shot.tail.Rotation=math.deg(math.atan2(shot.direction.Y,shot.direction.X))
            shot.tail:SetAttribute("ReducedPrism",simple)
            local frame=dynamic and -2 or animated and math.floor(time*18)%shot.tracer.frames or -1
            if shot.frameIndex~=frame then
                shot.frameIndex=frame
                shot.tail.BackgroundTransparency=animated and 1 or .2
                if animated then Batch.apply(shot.tail,shot.tracer,"wakes",frame) else shot.tail.Image="" end
            end
        end
        shot.trace.Visible=self.diagnostics.Visible
    end
end
return Arena
