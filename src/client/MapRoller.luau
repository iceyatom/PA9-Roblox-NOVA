local W=require(script.Parent.Widgets)
local C=W.colors
local Maps=require(game.ReplicatedStorage.NOVA.Map1)
local cfg=require(game.ReplicatedStorage.NOVA.Config)
local Roller={}
Roller.__index=Roller
local pitch,cardWidth,landing=280,260,23

local function card(parent,arena,index)
    local frame=W.box(parent,"MapCard"..index,(index-1)*pitch,0,cardWidth,256,C.panel)
    W.stroke(frame,C.line)
    local preview=W.box(frame,"Preview",10,10,240,180,C.ink)
    local unit=math.min(240/arena.width,180/arena.height)
    local ox,oy=(240-arena.width*unit)/2,(180-arena.height*unit)/2
    local colors={P=C.purple,D=C.dark,L=C.light,G=C.mint,Y=W.rgb("e7d342"),M=W.rgb("398756")}
    for _,r in arena.rects do
        W.box(preview,"Tile",ox+r.x*unit,oy+r.y*unit,(r.x2-r.x)*unit,(r.y2-r.y)*unit,colors[r.id])
    end
    W.text(frame,"Code",14,199,230,17,"MAP / "..arena.code,12,C.purple)
    W.text(frame,"Title",14,222,230,26,arena.title,22,C.white,Enum.Font.GothamBold)
    return frame
end

function Roller.new(stage)
    local self=setmetatable({},Roller)
    local overlay=W.box(stage,"MapShuffle",273,220,894,366,C.ink,9)
    W.stroke(overlay,C.line)
    overlay.Active=true
    self.overlay=overlay
    self.heading=W.text(overlay,"Heading",24,14,846,30,"SHUFFLING MAPS",22,C.white,Enum.Font.GothamBold)
    self.heading.TextXAlignment=Enum.TextXAlignment.Center
    local window=W.box(overlay,"ReelWindow",12,58,870,258)
    window.ClipsDescendants=true
    self.window=window
    W.box(overlay,"SelectionTop",445,48,4,10,C.purple,4)
    W.box(overlay,"SelectionBottom",445,316,4,10,C.purple,4)
    self.detail=W.text(overlay,"Detail",24,333,846,22,"The next arena is on its way.",14,C.muted)
    self.detail.TextXAlignment=Enum.TextXAlignment.Center
    overlay.Visible=false
    return self
end

function Roller:hide()
    self.overlay.Visible=false
    self.key=nil
end

function Roller:update(snap)
    if snap.phase~="Selecting" then self:hide(); return end
    local key=snap.lobby..":"..snap.round
    if self.key==key then return end
    self.key=key
    self.ends=snap.ends
    self.selected=Maps.load(snap.mapId)
    if self.strip then self.strip:Destroy() end
    self.strip=W.box(self.window,"Strip",0,0,(landing+2)*pitch,256)
    local pool=Maps.pool()
    local selectedIndex
    for i,arena in pool do
        if arena.id==self.selected.id then selectedIndex=i; break end
    end
    assert(selectedIndex,"Selected map is missing from the rotation")
    -- Align the whole cycle with the winning slot instead of replacing one card.
    -- Every map appears once per cycle, including the cards around the winner.
    for i=1,landing+2 do
        local arena=pool[(i-landing+selectedIndex-1)%#pool+1]
        local frame=card(self.strip,arena,i)
        if i==landing then self.winner=frame end
    end
    self.overlay.Visible=true
    self:tick()
end

function Roller:tick()
    if not self.overlay.Visible then return end
    local elapsed=cfg.MapRollDuration-(self.ends-workspace:GetServerTimeNow())
    local progress=math.clamp(elapsed/(cfg.MapRollDuration-0.65),0,1)
    local distance=(1+(landing-2)*(1-(1-progress)^4))*pitch
    self.strip.Position=UDim2.fromOffset((870-cardWidth)/2-distance,0)
    local landed=progress>=1
    self.heading.Text=landed and "ARENA SELECTED" or "SHUFFLING MAPS"
    self.detail.Text=landed and (self.selected.title.."  /  Get ready") or "The next arena is on its way."
    self.winner.BackgroundColor3=landed and W.rgb("2a1b43") or C.panel
end
return Roller
