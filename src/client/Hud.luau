local W=require(script.Parent.Widgets)
local C=W.colors
local Hud={}
Hud.__index=Hud
local bold=Enum.Font.GothamBold
local heavy=Enum.Font.GothamBlack

function Hud.new(playerGui)
    local self=setmetatable({},Hud)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVA"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.DisplayOrder=10
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=playerGui
    local root=W.box(gui,"Backdrop",0,0,0,0,C.ink)
    root.Size=UDim2.fromScale(1,1)
    local origin=W.box(root,"Origin",0,0,0,0)
    origin.Position=UDim2.fromScale(0.5,0.5)
    local scale=Instance.new("UIScale")
    scale.Parent=origin
    local function resize() scale.Scale=math.max(0.01,math.min(root.AbsoluteSize.X/1440,root.AbsoluteSize.Y/810)) end
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
    resize()
    local stage=W.box(origin,"Stage",-720,-405,1440,810,C.ink)
    self.stage=stage
    W.text(stage,"ArenaNumber",283,16,175,22,"MAP   /   01",15,C.lime)
    W.text(stage,"ArenaTitle",283,34,420,34,"Split Circuit",31,C.white,heavy)
    self.phaseLabel=W.text(stage,"Phase",865,32,292,30,"CONNECTING",17,C.muted)
    self.phaseLabel.TextXAlignment=Enum.TextXAlignment.Right
    -- Left rail: identity and player seats.
    local x=35
    W.box(stage,"LogoStem",x,128,7,26,C.lime).Rotation=30
    W.box(stage,"LogoStem",x+13,117,7,37,C.lime).Rotation=30
    W.text(stage,"Wordmark",x,161,230,63,"NOVA",59,C.white,heavy)
    W.text(stage,"Mode",x+3,225,225,25,"PLATFORM DUEL",16,C.lime)
    W.box(stage,"RailRule",x,278,210,1,C.line)
    self.seats={}
    for i=1,2 do
        local y=304+(i-1)*143
        local col=i==1 and C.blue or C.red
        W.box(stage,"SeatColor",x,y+4,5,17,col)
        local who=W.text(stage,"Seat"..i,x+16,y,195,26,"PLAYER 0"..i,16,C.muted)
        local name=W.text(stage,"Callsign"..i,x,y+32,207,37,"Open seat",25,C.white,bold)
        local hp=W.text(stage,"Vitals"..i,x,y+72,207,22,"AWAITING PLAYER",14,C.muted)
        local cells={}
        for j=1,10 do cells[j]=W.box(stage,"HP",x+(j-1)*20.7,y+103,17,5,C.line) end
        self.seats[i]={who=who,name=name,hp=hp,cells=cells,color=col}
    end
    -- Right rail: persistent legend for the four collision behaviors.
    local rx=1195
    W.text(stage,"FieldGuide",rx,229,218,30,"Field guide",26,C.white,bold)
    W.box(stage,"LegendRule",rx,276,207,1,C.line)
    local keys={{"Solid wall","Blocks all",C.purple},{"Phase wall","Blocks players",C.dark},
        {"Shot shield","Blocks shots",C.light},{"Launch pad","Boosts upward",C.mint}}
    for i,row in keys do
        local y=301+(i-1)*67
        W.box(stage,"Swatch",rx,y+6,12,12,row[3])
        W.text(stage,"Tile",rx+24,y,184,25,row[1],19,C.white,bold)
        W.text(stage,"Mask",rx+24,y+25,184,21,row[2],15,C.muted)
    end
    self.notice=W.box(stage,"MatchNotice",520,389,400,111,C.panel,8)
    W.stroke(self.notice,C.line)
    W.box(self.notice,"Signal",0,0,4,111,C.lime)
    self.kicker=W.text(self.notice,"Status",23,12,355,22,"DUEL LOBBY",15,C.lime)
    self.title=W.text(self.notice,"Title",22,35,362,38,"Waiting for a rival",29,C.white,heavy)
    self.note=W.text(self.notice,"Detail",23,77,360,23,"The duel starts with two players.",16,C.muted)
    self.rematch=W.button(self.notice,"Rematch",23,109,209,37,"Rematch",true)
    self.leave=W.button(self.notice,"Leave",244,109,130,37,"Leave",false)
    self.rematch.Visible=false
    self.leave.Visible=false
    return self
end

function Hud:update(snap,seat)
    self.snap=snap
    local phase=snap.phase
    local status=({Waiting="1 OF 2",Countdown="COUNTDOWN",Playing="LIVE",Results="FINAL"})[phase]
    self.phaseLabel.Text=("LOBBY %02d / %s"):format(snap.lobby,status)
    for i,p in snap.players do
        local side=self.seats[i]
        side.who.Text=("PLAYER 0%d%s"):format(i,i==seat and "   /   YOU" or "")
        side.name.Text=p.name or "Open seat"
        side.hp.Text=p.uid and ("%02d / %02d HP"):format(p.hp,snap.maxHP) or "AWAITING PLAYER"
        for j,cell in side.cells do cell.BackgroundColor3=p.uid and j/10 <= p.hp/snap.maxHP and side.color or C.line end
    end
    self.notice.Visible=phase~="Playing"
    self.notice.Size=UDim2.fromOffset(400,phase=="Results" and 160 or 111)
    self.rematch.Visible=phase=="Results"
    self.leave.Visible=phase=="Results"
    if phase=="Waiting" then
        self.kicker.Text,self.title.Text,self.note.Text="DUEL LOBBY","Waiting for a rival","The duel starts with two players."
    elseif phase=="Countdown" then
        self.kicker.Text,self.note.Text="BOTH PLAYERS READY","Movement and fire unlock together."
        self:tick()
    elseif phase=="Results" then
        self.kicker.Text="ROUND COMPLETE"
        self.title.Text=snap.winner==0 and "Draw" or snap.winner==seat and "Victory" or "Defeat"
        self.note.Text=snap.reason=="Disconnect" and "Your rival disconnected." or snap.winner==0 and "Both players landed the final hit." or "Ten hits. Duel complete."
        local rival=snap.players[3-seat]
        self.rematch.Text=not rival.uid and "Return to lobby" or snap.players[seat].vote and "Waiting for rival…" or rival.vote and "Accept rematch" or "Rematch"
    end
end
function Hud:tick()
    if self.snap and self.snap.phase=="Countdown" then
        self.title.Text="Duel in "..math.clamp(math.ceil(self.snap.ends-workspace:GetServerTimeNow()),1,3)
    end
end
return Hud
