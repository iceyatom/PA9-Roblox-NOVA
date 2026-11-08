local shared=game.ReplicatedStorage.NOVA
local map=require(shared.Map1).arena
local cfg=require(shared.Config)
local catalog=require(shared.TileCatalog)
local W=require(script.Parent.Widgets)
local C=W.colors
local Arena={}
Arena.__index=Arena

function Arena.new(stage)
    local self=setmetatable({},Arena)
    local unit=math.min(cfg.TilePixels,890/map.width,667/map.height)
    self.unit=unit
    local width,height=unit*map.width,unit*map.height
    local field=W.box(stage,"Map1",(1440-width)/2,76+(667-height)/2,width,height,W.rgb("080911"))
    self.field=field
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
        rect(self.diagnostics,"Spawn"..i,spawn.X-0.4,spawn.Y-0.05,0.8,0.1,C.lime)
        rect(self.diagnostics,"Spawn"..i,spawn.X-0.05,spawn.Y-0.4,0.1,0.8,C.lime)
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
        W.stroke(box,C.lime,2)
        box.Visible=false
        self.actors[i]={body=body,label=label,bar=bar,box=box,color=color,hp=cfg.Health,flash=0}
        body.Visible=false
    end
    return self
end

function Arena:update(snap,time)
    local unit=self.unit
    local changed=self.round~=snap.round
    self.round=snap.round
    self.received=time
    for i,p in snap.players do
        local actor=self.actors[i]
        actor.body.Visible=p.uid~=nil
        actor.label.Text=p.name or ""
        if not changed and p.hp<actor.hp then actor.flash=time+0.13 end
        actor.hp=p.hp
        actor.bar.Size=UDim2.fromScale(p.hp/snap.maxHP,1)
        actor.target=Vector2.new(p.x,p.y)
        actor.start=(not changed and actor.draw) or actor.target
    end
    local seen={}
    for _,b in snap.shots do
        local id=b[1]
        local shot=self.shots[id]
        if not shot then
            local color=b[4]==1 and C.blue or C.red
            local diameter=2*cfg.BulletRadius*unit
            local glow=W.box(self.field,"Pulse",0,0,diameter*2.6,diameter*2.6,color,4)
            glow.AnchorPoint=Vector2.new(0.5,0.5)
            glow.BackgroundTransparency=0.62
            W.round(glow)
            local core=W.box(glow,"Core",diameter*0.8,diameter*0.8,diameter,diameter,C.white,5)
            W.round(core)
            local trace=W.box(self.field,"Sweep",0,0,1,1,C.lime,6)
            trace.AnchorPoint=Vector2.new(0.5,0.5)
            shot={frame=glow,trace=trace}
            self.shots[id]=shot
        end
        seen[id]=true
        shot.target=Vector2.new(b[2],b[3])
        local velocity=Vector2.new(b[5],b[6])
        shot.start=shot.draw or shot.target
        local segment=velocity*cfg.Step
        local mid=(shot.target-segment/2)*unit
        shot.trace.Position=UDim2.fromOffset(mid.X,mid.Y)
        shot.trace.Size=UDim2.fromOffset(segment.Magnitude*unit,2)
        shot.trace.Rotation=math.deg(math.atan2(segment.Y,segment.X))
    end
    for id,shot in self.shots do
        if not seen[id] then shot.frame:Destroy(); shot.trace:Destroy(); self.shots[id]=nil end
    end
end

function Arena:draw(time)
    if not self.received then return end
    local alpha=math.clamp((time-self.received)*cfg.SnapshotRate,0,1)
    for _,actor in self.actors do
        actor.draw=actor.start:Lerp(actor.target,alpha)
        actor.body.Position=UDim2.fromOffset(actor.draw.X*self.unit,actor.draw.Y*self.unit)
        actor.body.BackgroundColor3=time<actor.flash and C.white or actor.color
        actor.box.Visible=self.diagnostics.Visible
    end
    for _,shot in self.shots do
        shot.draw=shot.start:Lerp(shot.target,alpha)
        shot.frame.Position=UDim2.fromOffset(shot.draw.X*self.unit,shot.draw.Y*self.unit)
        shot.trace.Visible=self.diagnostics.Visible
    end
end
return Arena
