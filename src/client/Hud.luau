local W=require(script.Parent.Widgets)
local C=W.colors
local P=require(game.ReplicatedStorage.NOVA.Progression)
local Portrait=require(script.Parent.Portrait)
local RankIcon=require(script.Parent.RankIcon)
local Cosmetics=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
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
    self.gui=gui
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
    self.mapCode=W.text(stage,"ArenaNumber",283,16,175,22,"MAP   /   01",15,C.purple)
    self.mapTitle=W.text(stage,"ArenaTitle",283,34,420,34,"Split Circuit",31,C.white,heavy)
    self.phaseLabel=W.text(stage,"Phase",865,32,292,30,"CONNECTING",17,C.muted)
    self.phaseLabel.TextXAlignment=Enum.TextXAlignment.Right
    -- Left rail: identity and player seats.
    local x=35
    W.text(stage,"Wordmark",x,161,230,63,"NOVA",59,C.white,heavy)
    W.text(stage,"Mode",x+3,225,225,25,"1v1",16,C.purple)
    W.box(stage,"RailRule",x,278,210,1,C.line)
    self.seats={}
    for i=1,2 do
        local y=304+(i-1)*143
        local col=i==1 and C.blue or C.red
        local card=W.box(stage,"PlayerCard"..i,x-5,y-4,220,132,C.panel)
        card.BackgroundColor3=Color3.new(1,1,1)
        card.BackgroundTransparency=1
        local gradient=Instance.new("UIGradient"); gradient.Rotation=25; gradient.Parent=card
        W.box(stage,"SeatColor",x,y+4,5,17,col)
        local who=W.text(stage,"Seat"..i,x+16,y,195,26,"PLAYER 0"..i,16,C.muted)
        local avatar=Instance.new("ImageLabel")
        avatar.Name="Portrait"..i; avatar.Position=UDim2.fromOffset(x,y+32); avatar.Size=UDim2.fromOffset(36,36)
        avatar.BackgroundColor3=C.panel; avatar.BorderSizePixel=0; avatar.ZIndex=3; avatar.Parent=stage
        W.round(avatar)
        local name=W.text(stage,"Callsign"..i,x+45,y+30,162,32,"Open seat",21,C.white,bold)
        local rankIcon=RankIcon.new(stage,"RankIcon"..i,x,y+66,30)
        local rank=W.text(stage,"Rank"..i,x+38,y+68,169,18,"",11,C.muted)
        local hp=W.text(stage,"Vitals"..i,x,y+94,207,18,"AWAITING PLAYER",12,C.muted)
        local cells={}
        for j=1,10 do cells[j]=W.box(stage,"HP",x+(j-1)*20.7,y+115,17,5,C.line) end
        self.seats[i]={who=who,name=name,rank=rank,rankIcon=rankIcon,avatar=avatar,hp=hp,cells=cells,color=col,card=card,gradient=gradient}
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
    W.box(self.notice,"Signal",0,0,4,111,C.purple)
    self.kicker=W.text(self.notice,"Status",23,12,355,22,"DUEL LOBBY",15,C.purple)
    self.title=W.text(self.notice,"Title",22,35,362,38,"Waiting for a rival",29,C.white,heavy)
    self.note=W.text(self.notice,"Detail",23,77,360,23,"The duel starts with two players.",16,C.muted)
    self.xpRecap=require(script.Parent.XPRecap).new(self.notice)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not gui.Enabled then self.xpRecap:hide() end
    end)
    self.rematch=W.button(self.notice,"Rematch",23,109,209,37,"Rematch",true)
    self.leave=W.button(self.notice,"Leave",244,109,130,37,"Leave",false)
    self.chest=W.box(self.notice,"VictoryChest",12,164,376,128,C.ink)
    self.chestStatus=W.text(self.chest,"Status",9,2,360,24,"Reward saving",16,C.mint,Enum.Font.GothamBold)
    local odds=W.text(self.chest,"Odds",9,27,358,52,
        "1 item · No pity · Duplicate Shards by tier\nUncommon 60% / 10  ·  Rare 25% / 25  ·  Epic 10% / 60\nLegendary 4% / 150  ·  Cosmic 1% / 500",13,C.muted,Enum.Font.Gotham)
    odds.TextWrapped=true; odds.TextTruncate=Enum.TextTruncate.None
    self.openChest=W.button(self.chest,"OpenNow",9,84,173,36,"Open now",true)
    self.saveChest=W.button(self.chest,"SaveLater",190,84,175,36,"Save for later",false)
    self.saveChest.Activated:Connect(function()
        if self.snap.chest then self.dismissed=self.snap.chest.key; self:update(self.snap,self.seat) end
    end)
    self.chest.Visible=false
    self.rematch.Visible=false
    self.leave.Visible=false
    return self
end

function Hud:update(snap,seat)
    self.snap=snap; self.seat=seat
    local phase=snap.phase
    local status=({Waiting="1 OF 2",Selecting="MAP SHUFFLE",Countdown="COUNTDOWN",Playing="LIVE",Results="FINAL"})[phase]
    self.phaseLabel.Text=("LOBBY %02d / %s"):format(snap.lobby,status)
    for i,p in snap.players do
        local side=self.seats[i]
        local background=Cosmetics.get(p.cosmetics,"backgrounds")
        side.card.BackgroundTransparency=p.uid and not background.default and 0 or 1
        if side.backgroundId~=background.id then
            require(script.Parent.BatchOneVisuals).overlay(side.card,background,"card")
            side.backgroundId=background.id; side.gradient.Color=ColorSequence.new(W.rgb(background.color),C.ink)
        end
        side.who.Text=("PLAYER 0%d%s"):format(i,i==seat and "   /   YOU" or "")
        side.name.Text=p.name or "Open seat"
        side.rank.Text=p.uid and P.label(p.progression) or ""
        RankIcon.set(side.rankIcon,p.uid and p.progression or nil)
        side.rank.TextColor3=p.progression and p.progression.master and C.mint or C.muted
        Portrait.set(side.avatar,p.uid)
        side.hp.Text=p.uid and ("%02d / %02d HP"):format(p.hp,snap.maxHP) or "AWAITING PLAYER"
        for j,cell in side.cells do cell.BackgroundColor3=p.uid and j/10 <= p.hp/snap.maxHP and side.color or C.line end
    end
    self.notice.Visible=phase~="Playing" and phase~="Selecting"
    self.notice.Size=UDim2.fromOffset(400,(phase=="Results" or phase=="Waiting") and 160 or 111)
    self.notice.Position=UDim2.fromOffset(520,389)
    self.note.Size=UDim2.fromOffset(360,23)
    local receipt=phase=="Results" and snap.players[seat].xpRecap
    if receipt and receipt.total<=0 then receipt=nil end
    if receipt then
        local height=108+self.xpRecap:start(tostring(snap.lobby)..":"..snap.round,receipt)+65
        self.notice.Size=UDim2.fromOffset(500,height)
        self.notice.Position=UDim2.fromOffset(470,405-height/2)
        self.note.Size=UDim2.fromOffset(454,23)
    else
        self.xpRecap:hide()
    end
    self.rematch.Visible=phase=="Results"
    self.leave.Visible=phase=="Results" or phase=="Waiting"
    self.leave.Position=UDim2.fromOffset(phase=="Waiting" and 23 or 244,109)
    self.leave.Size=UDim2.fromOffset(phase=="Waiting" and 160 or 130,37)
    self.rematch.Size=UDim2.fromOffset(receipt and 280 or 209,37)
    if receipt then
        local y=self.notice.Size.Y.Offset-51
        self.rematch.Position=UDim2.fromOffset(23,y)
        self.leave.Position=UDim2.fromOffset(347,y)
    else
        self.rematch.Position=UDim2.fromOffset(23,109)
    end
    local chest=phase=="Results" and snap.winner==seat and snap.chest
    self.chest.Visible=chest and self.dismissed~=chest.key or false
    if self.chest.Visible then
        local size=self.notice.Size
        self.chest.Position=UDim2.fromOffset((size.X.Offset-376)/2,size.Y.Offset)
        self.notice.Size=UDim2.fromOffset(size.X.Offset,size.Y.Offset+133)
        self.notice.Position-=UDim2.fromOffset(0,66)
        self.chestStatus.Text="Items Batch 1 Chest  /  "..chest.status
        self.openChest.Visible=chest.status=="Chest earned"
        self.saveChest.Visible=self.openChest.Visible
    end
    self.leave.Text=phase=="Waiting" and "Leave queue" or "Lobby"
    if phase=="Waiting" then
        self.kicker.Text,self.title.Text,self.note.Text="IN QUEUE","Waiting for a rival","The duel starts with two players."
    elseif phase=="Countdown" then
        self.kicker.Text,self.note.Text="BOTH PLAYERS READY","Movement and fire unlock together."
        self:tick()
    elseif phase=="Results" then
        self.kicker.Text="ROUND COMPLETE"
        self.title.Text=snap.winner==0 and "Draw" or snap.winner==seat and "Victory" or "Defeat"
        self.note.Text=snap.reason=="Disconnect" and "Your rival disconnected." or snap.winner==0 and "Both players landed the final hit." or "Ten hits. Duel complete."
        local reward=snap.players[seat].xpAward
        if reward and reward>0 and not receipt then self.note.Text=("+%d XP / %s"):format(reward,snap.reason=="Disconnect" and "Rival disconnected" or snap.winner==seat and "Victory bonus" or "Duel completed") end
        local rival=snap.players[3-seat]
        self.rematch.Text=not rival.uid and "Find new rival" or snap.players[seat].vote and "Waiting for rival…" or rival.vote and "Accept rematch" or "Rematch"
    end
end
function Hud:tick()
    self.xpRecap:tick()
    if self.snap and self.snap.phase=="Countdown" then
        self.title.Text="Duel in "..math.clamp(math.ceil(self.snap.ends-workspace:GetServerTimeNow()),1,3)
    end
end
return Hud
