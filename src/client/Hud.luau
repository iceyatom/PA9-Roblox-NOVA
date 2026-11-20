local Gui=game:GetService("GuiService")
local UIS=game:GetService("UserInputService")
local W=require(script.Parent.Widgets)
local C=W.colors
local P=require(game.ReplicatedStorage.NOVA.Progression)
local Portrait=require(script.Parent.Portrait)
local RankIcon=require(script.Parent.RankIcon)
local WinStreak=require(script.Parent.WinStreak)
local Cosmetics=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Bots=require(game.ReplicatedStorage.NOVA.Bots)
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
    self.resultBanner=require(script.Parent.ResultBanner).new(gui)
    local root=W.box(gui,"Backdrop",0,0,0,0,C.ink)
    root.Size=UDim2.fromScale(1,1)
    local origin=W.box(root,"Origin",0,0,0,0)
    origin.Position=UDim2.fromScale(0.5,0.5)
    local scale=Instance.new("UIScale")
    scale.Parent=origin
    self.stageScale=scale
    local function resize()
        scale.Scale=math.max(0.01,math.min(root.AbsoluteSize.X/1440,root.AbsoluteSize.Y/810))
        if self.noticeScale and self.snap then self:update(self.snap,self.seat) end
    end
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
    local mobile=UIS.TouchEnabled
    local identity=mobile and W.box(stage,"Identity",0,0,0,0) or stage
    W.text(identity,"Wordmark",x,161,230,63,"NOVA",59,C.white,heavy)
    W.text(identity,"Mode",x+3,225,225,25,"1v1",16,C.purple)
    W.box(identity,"RailRule",x,278,210,1,C.line)
    self.mobileIdentity=mobile and identity or nil
    self.seats={}
    for i=1,2 do
        local y=304+(i-1)*143
        local rail=mobile and W.box(stage,"SeatRail"..i,0,0,0,0) or stage
        local col=i==1 and C.blue or C.red
        local card=W.box(rail,"PlayerCard"..i,x-5,y-4,220,132,C.panel)
        card.BackgroundColor3=Color3.new(1,1,1)
        card.BackgroundTransparency=1
        local gradient=Instance.new("UIGradient"); gradient.Rotation=25; gradient.Parent=card
        W.box(rail,"SeatColor",x,y+4,5,17,col)
        local who=W.text(rail,"Seat"..i,x+16,y,195,26,"PLAYER 0"..i,16,C.muted)
        local streak=WinStreak.new(rail,"WinStreak"..i,x+143,y-1,66,28)
        local avatar=Instance.new("ImageLabel")
        avatar.Name="Portrait"..i; avatar.Position=UDim2.fromOffset(x,y+32); avatar.Size=UDim2.fromOffset(36,36)
        avatar.BackgroundColor3=C.panel; avatar.BorderSizePixel=0; avatar.ZIndex=3; avatar.Parent=rail
        W.round(avatar)
        local name=W.text(rail,"Callsign"..i,x+45,y+30,162,32,"Open seat",21,C.white,bold)
        local rankIcon=RankIcon.new(rail,"RankIcon"..i,x,y+66,30)
        local rank=W.text(rail,"Rank"..i,x+38,y+68,169,18,"",11,C.muted)
        local hp=W.text(rail,"Vitals"..i,x,y+94,207,18,"AWAITING PLAYER",12,C.muted)
        local cells={}
        for j=1,10 do cells[j]=W.box(rail,"HP",x+(j-1)*20.7,y+115,17,5,C.line) end
        self.seats[i]={who=who,name=name,rank=rank,rankIcon=rankIcon,avatar=avatar,hp=hp,cells=cells,color=col,card=card,gradient=gradient,streak=streak,mobileRail=mobile and rail or nil}
    end
    local session=W.box(stage,"SessionScore",x,609,220,158)
    self.sessionPanel=session
    W.text(session,"Heading",0,0,220,20,"SESSION SCORE",13,C.muted,bold)
    self.sessionWins={}
    for i=1,2 do
        local sx=(i-1)*114
        local score=W.text(session,"Wins"..i,sx,23,94,38,"0",32,i==1 and C.blue or C.red,heavy)
        score.TextXAlignment=Enum.TextXAlignment.Center
        self.sessionWins[i]=score
        local label=W.text(session,"Player"..i,sx,61,94,18,"PLAYER 0"..i,11,C.muted)
        label.TextXAlignment=Enum.TextXAlignment.Center
    end
    local versus=W.text(session,"Separator",95,27,18,32,"–",22,C.muted,bold)
    versus.TextXAlignment=Enum.TextXAlignment.Center
    self.sessionMatch=W.text(session,"MatchCount",0,85,220,22,"MATCH 1 / 11",15,C.white,bold)
    self.sessionDraws=W.text(session,"Draws",0,110,220,18,"",12,C.muted)
    self.sessionReturn=W.text(session,"Return",0,135,220,22,"",14,C.mint,bold)
    session.Visible=false
    -- Right rail: persistent legend for the four collision behaviors.
    local guide=mobile and W.box(stage,"GuideRail",0,0,0,0) or stage
    self.mobileGuide=mobile and guide or nil
    local rx=1195
    W.text(guide,"FieldGuide",rx,229,218,30,"Field guide",26,C.white,bold)
    W.box(guide,"LegendRule",rx,276,207,1,C.line)
    local keys={{"Solid wall","Blocks all",C.purple},{"Phase wall","Blocks players",C.dark},
        {"Shot shield","Blocks shots",C.light},{"Launch pad","Boosts upward",C.mint}}
    for i,row in keys do
        local y=301+(i-1)*67
        W.box(guide,"Swatch",rx,y+6,12,12,row[3])
        W.text(guide,"Tile",rx+24,y,184,25,row[1],19,C.white,bold)
        W.text(guide,"Mask",rx+24,y+25,184,21,row[2],15,C.muted)
    end
    self.notice=W.box(stage,"MatchNotice",520,389,400,111,C.panel,8)
    if mobile then
        self.noticeScale=Instance.new("UIScale")
        self.noticeScale.Parent=self.notice
    end
    W.stroke(self.notice,C.line)
    W.box(self.notice,"Signal",0,0,4,111,C.purple)
    self.kicker=W.text(self.notice,"Status",23,12,355,22,"DUEL LOBBY",15,C.purple)
    self.title=W.text(self.notice,"Title",22,35,362,38,"Waiting for a rival",29,C.white,heavy)
    self.note=W.text(self.notice,"Detail",23,77,360,23,"The duel starts with two players.",16,C.muted)
    if mobile then
        local scroll=Instance.new("ScrollingFrame")
        scroll.Name="RecapScroll";scroll.Position=UDim2.fromOffset(23,108)
        scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ZIndex=self.notice.ZIndex
        scroll.ScrollingDirection=Enum.ScrollingDirection.Y;scroll.ScrollBarThickness=4
        scroll.ScrollBarImageColor3=C.purple;scroll.Visible=false;scroll.Parent=self.notice
        self.recapScroll=scroll
    end
    self.xpRecap=require(script.Parent.XPRecap).new(self.recapScroll or self.notice)
    if self.recapScroll then self.xpRecap.frame.Position=UDim2.fromOffset(0,0) end
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not gui.Enabled then self.resultBanner:hide();self.xpRecap:hide();if self.chestRoll then self.chestRoll:hide() end end
    end)
    self.rematch=W.button(self.notice,"Rematch",23,109,209,37,"Rematch",true)
    self.leave=W.button(self.notice,"Leave",244,109,130,37,"Leave",false)
    -- Difficulty buttons: start a bot duel while waiting, or change the bot between duels.
    self.botPanel=W.box(self.notice,"BotPicker",23,109,354,94)
    self.botLabel=W.text(self.botPanel,"Label",0,0,354,18,"",12,C.muted)
    self.botButtons={}
    for i,level in Bots.order do
        local difficulty=Bots.levels[level]
        local format=mobile and "%s\n%d%% XP" or "%s · %d%% XP"
        local button=W.button(self.botPanel,"Bot_"..level,0,0,173,32,format:format(difficulty.name,difficulty.xpPercent),false)
        button.TextWrapped=mobile
        button.TextSize=14
        button.Activated:Connect(function() if self.onBot and button.Active then self.onBot(level) end end)
        -- Hidden buttons must be inactive themselves: the fire input skips clicks over active buttons.
        button.Visible=false;button.Active=false
        self.botButtons[i]={button=button,level=level}
    end
    self.botPanel.Visible=false
    self.chestRoll=require(script.Parent.ChestChance).new(gui,function()
        if UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" then Gui.SelectedObject=self.snap and self.snap.session and self.snap.session.complete and self.leave or self.rematch end
    end,stage)
    self.openChest=self.chestRoll.openButton
    self.saveChest=self.chestRoll.continueButton
    self.rematch.Visible=false
    self.leave.Visible=false
    return self
end

function Hud:layoutMobileNotice(phase,pick,complete,recapHeight)
    local waiting=phase=="Waiting"
    local interactive=waiting or phase=="Results"
    local panelScale=(waiting or phase=="Countdown") and 1.18 or 1
    self.noticeScale.Scale=panelScale
    if not interactive then
        self.recapScroll.Visible=false
        self.notice.Position=UDim2.fromOffset(720-200*panelScale,389)
        return
    end

    local screenScale=self.stageScale.Scale*panelScale
    local buttonHeight=math.clamp(math.ceil(44/screenScale),80,150)
    local textSize=math.clamp(math.ceil(14/screenScale),24,38)
    local pickerHeight=pick and (48+2*buttonHeight) or 0
    local recapSpace=740-108-pickerHeight-buttonHeight-34
    local visibleRecap=math.min(recapHeight,recapSpace)
    local scroll=self.recapScroll
    scroll.Visible=recapHeight>0
    scroll.Size=UDim2.fromOffset(454,visibleRecap)
    scroll.CanvasSize=UDim2.fromOffset(0,recapHeight)
    scroll.ScrollingEnabled=recapHeight>visibleRecap
    scroll.ScrollBarThickness=scroll.ScrollingEnabled and 4 or 0
    local pickerY=108+visibleRecap+(recapHeight>0 and 8 or 0)
    local actionsY=pickerY+pickerHeight
    local height=actionsY+buttonHeight+18
    self.notice.Size=UDim2.fromOffset(500,height)
    self.notice.Position=UDim2.fromOffset(720-250*panelScale,405-height*panelScale/2)
    self.note.Size=UDim2.fromOffset(454,23)

    self.rematch.Position=UDim2.fromOffset(23,actionsY)
    self.rematch.Size=UDim2.fromOffset(264,buttonHeight)
    self.rematch.TextSize=textSize
    self.rematch.TextWrapped=true
    local singleAction=waiting or complete
    self.leave.Position=UDim2.fromOffset(singleAction and 23 or 299,actionsY)
    self.leave.Size=UDim2.fromOffset(singleAction and 454 or 178,buttonHeight)
    self.leave.TextSize=textSize
    if pick then
        self.botPanel.Position=UDim2.fromOffset(23,pickerY)
        self.botPanel.Size=UDim2.fromOffset(454,pickerHeight-10)
        self.botLabel.Size=UDim2.fromOffset(454,22)
        self.botLabel.TextSize=16
        for i,entry in self.botButtons do
            entry.button.Position=UDim2.fromOffset((i-1)%2*233,26+math.floor((i-1)/2)*(buttonHeight+10))
            entry.button.Size=UDim2.fromOffset(221,buttonHeight)
            entry.button.TextSize=textSize
        end
    end
end

function Hud:update(snap,seat)
    self.snap=snap; self.seat=seat
    local phase=snap.phase
    if self.mobileIdentity and phase~=self.layoutPhase then
        self.layoutPhase=phase
        local playing=phase=="Playing"
        self.mobileIdentity.Visible=not playing
        self.mobileGuide.Visible=phase~="Selecting"
        self.seats[1].mobileRail.Position=UDim2.fromOffset(0,playing and -170 or 0)
        self.seats[2].mobileRail.Position=UDim2.fromOffset(0,playing and -185 or 0)
        self.sessionPanel.Position=UDim2.fromOffset(35,playing and 390 or 609)
    end
    local session=snap.session
    local complete=session and session.complete
    self.sessionPanel.Visible=session~=nil and (phase~="Waiting" or session.played>0)
    if session then
        for i=1,2 do self.sessionWins[i].Text=tostring(session.wins[i]) end
        -- A limit of 0 means no limit (bot duels).
        self.sessionMatch.Text=complete and "SESSION COMPLETE" or session.limit==0 and ("MATCH %d"):format(session.game)
            or ("MATCH %d / %d"):format(session.game,session.limit)
        self.sessionDraws.Text=(session.limit==0 and "%d played%s" or "%d / "..session.limit.." played%s"):format(session.played,
            session.draws>0 and (" · %d %s"):format(session.draws,session.draws==1 and "draw" or "draws") or "")
        self.sessionReturn.Visible=complete==true
    end
    local resultKey=tostring(snap.lobby)..":"..snap.round
    if phase=="Results" then self.resultBanner:start(resultKey,snap.winner==0 and "draw" or snap.winner==seat and "win" or "loss")
    elseif phase~="Waiting" or not self.resultBanner.blocked then self.resultBanner:hide() end
    local blocked=self.resultBanner.blocked or phase=="Results" and not self.resultBanner:ready(resultKey)
    local status=({Waiting="1 OF 2",Selecting="MAP SHUFFLE",Countdown="COUNTDOWN",Playing="LIVE",Results="FINAL"})[phase]
    self.phaseLabel.Text=snap.private and ("BOT PRACTICE / %s"):format(phase=="Waiting" and "SETUP" or status)
        or ("LOBBY %02d / %s%s"):format(snap.lobby,status,snap.botDuel and " / IN QUEUE" or "")
    local rival=snap.players[3-seat]
    -- Offered to a lone player, and after a bot duel to change difficulty.
    local pick=not blocked and not complete and (phase=="Waiting" or phase=="Results" and (rival.bot~=nil or not rival.uid))
    local pickHeight=pick and 102 or 0
    for i,p in snap.players do
        local side=self.seats[i]
        local background=Cosmetics.get(p.cosmetics,"backgrounds")
        side.card.BackgroundTransparency=p.uid and not background.default and 0 or 1
        if side.backgroundId~=background.id then
            require(script.Parent.BatchOneVisuals).overlay(side.card,background,"card")
            side.backgroundId=background.id; side.gradient.Color=ColorSequence.new(W.rgb(background.color),C.ink)
        end
        side.who.Text=("PLAYER 0%d%s"):format(i,i==seat and " / YOU" or "")
        WinStreak.set(side.streak,p.uid and p.winStreak)
        side.who.TextSize=side.streak.Visible and 12 or 16
        side.who.Size=UDim2.fromOffset(side.streak.Visible and 122 or 195,26)
        side.name.Text=p.name or "Open seat"
        side.rank.Text=p.bot and Bots.levels[p.bot].name.." bot" or p.uid and P.label(p.progression) or ""
        RankIcon.set(side.rankIcon,p.uid and not p.bot and p.progression or nil)
        side.rank.TextColor3=p.progression and p.progression.master and C.mint or C.muted
        Portrait.set(side.avatar,not p.bot and p.uid or nil)
        side.hp.Text=p.uid and ("%02d / %02d HP"):format(p.hp,snap.maxHP) or "AWAITING PLAYER"
        for j,cell in side.cells do cell.BackgroundColor3=p.uid and j/10 <= p.hp/snap.maxHP and side.color or C.line end
    end
    self.notice.Visible=phase~="Playing" and phase~="Selecting" and not blocked
    self.notice.Size=UDim2.fromOffset(400,((phase=="Results" or phase=="Waiting") and 160 or 111)+pickHeight)
    self.notice.Position=UDim2.fromOffset(520,389)
    self.note.Size=UDim2.fromOffset(360,23)
    local receipt=phase=="Results" and not blocked and snap.players[seat].xpRecap
    if receipt and receipt.total<=0 then receipt=nil end
    local recapHeight=0
    if receipt then
        local newRecap=self.xpRecap.key~=resultKey
        recapHeight=self.xpRecap:start(resultKey,receipt,snap.players[seat].questRecap)
        if self.recapScroll and newRecap then self.recapScroll.CanvasPosition=Vector2.zero end
        local height=108+recapHeight+65+pickHeight
        self.notice.Size=UDim2.fromOffset(500,height)
        self.notice.Position=UDim2.fromOffset(470,405-height/2)
        self.note.Size=UDim2.fromOffset(454,23)
    else
        self.xpRecap:hide()
    end
    self.rematch.Visible=phase=="Results" and not blocked and not complete
    self.leave.Visible=(phase=="Results" or phase=="Waiting") and not blocked
    self.rematch.Active=not blocked and not complete;self.rematch.Selectable=not blocked and not complete
    self.leave.Active=not blocked;self.leave.Selectable=not blocked
    self.leave.Position=UDim2.fromOffset(phase=="Waiting" and 23 or 244,109+pickHeight)
    self.leave.Size=UDim2.fromOffset(phase=="Waiting" and 160 or 130,37)
    self.rematch.Size=UDim2.fromOffset(receipt and 280 or 209,37)
    if receipt then
        local y=self.notice.Size.Y.Offset-51
        self.rematch.Position=UDim2.fromOffset(23,y)
        self.leave.Position=UDim2.fromOffset(347,y)
    else
        self.rematch.Position=UDim2.fromOffset(23,109+pickHeight)
    end
    self.botPanel.Visible=pick
    for _,entry in self.botButtons do entry.button.Visible=pick;entry.button.Active=pick;entry.button.Selectable=pick end
    if pick then
        local inner=self.notice.Size.X.Offset-46
        local cell=(inner-8)/2
        self.botPanel.Position=UDim2.fromOffset(23,self.rematch.Position.Y.Offset-pickHeight)
        self.botPanel.Size=UDim2.fromOffset(inner,pickHeight-8)
        self.botLabel.Size=UDim2.fromOffset(inner,18)
        self.botLabel.Text=phase=="Results" and (rival.bot and "CHANGE DIFFICULTY" or "OR DUEL A BOT")
            or snap.private and "CHOOSE A DIFFICULTY" or "PLAY A BOT WHILE YOU WAIT"
        for i,entry in self.botButtons do
            entry.button.Position=UDim2.fromOffset((i-1)%2*(cell+8),22+math.floor((i-1)/2)*36)
            entry.button.Size=UDim2.fromOffset(cell,32)
            entry.button.BackgroundColor3=rival.bot==entry.level and C.purple or C.line
        end
    end
    if complete then
        self.leave.Size=UDim2.fromOffset(160,37)
        self.leave.Position=UDim2.fromOffset((self.notice.Size.X.Offset-160)/2,self.leave.Position.Y.Offset)
    end
    if self.noticeScale then self:layoutMobileNotice(phase,pick,complete,recapHeight) end
    self.noticeHome=self.notice.Position
    self.chestRoll:update(phase=="Results" and not blocked and snap.chest or nil,not blocked)
    self:layoutResults()
    self.leave.Text=phase=="Waiting" and not snap.private and "Leave queue" or "Lobby"
    if phase=="Waiting" and snap.private then
        self.kicker.Text,self.title.Text,self.note.Text="BOT PRACTICE","Choose your opponent","Bot duels do not count for stats or quests."
    elseif phase=="Waiting" then
        self.kicker.Text,self.title.Text,self.note.Text="IN QUEUE","Waiting for a rival","The duel starts with two players."
    elseif phase=="Countdown" then
        self.kicker.Text,self.note.Text="BOTH PLAYERS READY","Movement and fire unlock together."
        self:tick()
    elseif phase=="Results" then
        self.kicker.Text=complete and ("SESSION COMPLETE / %d MATCHES"):format(session.limit) or "ROUND COMPLETE"
        self.title.Text=snap.winner==0 and "Draw" or snap.winner==seat and "Victory" or "Defeat"
        self.note.Text=snap.reason=="Disconnect" and "Your rival disconnected." or snap.winner==0 and "Both players landed the final hit." or "Ten hits. Duel complete."
        local reward=snap.players[seat].xpAward
        if reward and reward>0 and not receipt then self.note.Text=("+%d XP / %s"):format(reward,snap.reason=="Disconnect" and "Rival disconnected" or snap.winner==seat and "Victory bonus" or "Duel completed") end
        self.rematch.Text=not rival.uid and "Find new rival" or snap.players[seat].vote and "Waiting for rival…" or rival.vote and "Accept rematch" or "Rematch"
    end
end
-- Both panels share the stage scale, keeping the wheel beside XP on every viewport.
function Hud:layoutResults()
    if self.chestRoll.root.Visible and self.notice.Visible then
        local wheelWidth=560*self.chestRoll.fit.Scale
        local left=(1440-self.notice.Size.X.Offset-24-wheelWidth)/2
        -- The mobile Roblox controls sit over the upper-left of the arena.
        if self.noticeScale then left=math.max(left,300) end
        self.notice.Position=UDim2.fromOffset(left,405-self.notice.Size.Y.Offset/2)
        self.chestRoll.origin.Position=UDim2.fromOffset(left+self.notice.Size.X.Offset+24+wheelWidth/2,405)
    elseif self.noticeHome then self.notice.Position=self.noticeHome end
end
function Hud:resultsReady()
    return self.gui.Enabled and self.snap and self.snap.phase=="Results" and self.resultBanner:ready(tostring(self.snap.lobby)..":"..self.snap.round)
end
function Hud:tick()
    if not self.gui.Enabled then return end
    if self.resultBanner:tick() then
        self:update(self.snap,self.seat)
        if UIS:GetLastInputType().Name:sub(1,7)=="Gamepad" and not Gui.MenuIsOpen then Gui.SelectedObject=(self.snap.phase=="Waiting" or self.snap.session and self.snap.session.complete) and self.leave or self.rematch end
    end
    local session=self.snap and self.snap.session
    if session and session.complete then
        self.sessionReturn.Text=("Lobby in %ds"):format(math.max(0,math.ceil(session.returnAt-workspace:GetServerTimeNow())))
    end
    self.xpRecap:tick()
    self.chestRoll:update(self.snap and self.snap.phase=="Results" and self:resultsReady() and self.snap.chest or nil,not self.resultBanner.blocked)
    self:layoutResults()
    if self.snap and self.snap.phase=="Countdown" then
        self.title.Text="Duel in "..math.clamp(math.ceil(self.snap.ends-workspace:GetServerTimeNow()),1,3)
    end
end
return Hud
