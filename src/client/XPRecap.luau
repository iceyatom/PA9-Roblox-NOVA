local W=require(script.Parent.Widgets)
local C=W.colors
local P=require(game.ReplicatedStorage.NOVA.Progression)
local Rewards=require(game.ReplicatedStorage.NOVA.XPRewards)
local Recap={}
Recap.__index=Recap

local function ease(t) return 1-(1-t)^3 end
local function pop(t) return 1+2.70158*(t-1)^3+1.70158*(t-1)^2 end

function Recap.new(parent)
    local self=setmetatable({},Recap)
    self.frame=W.box(parent,"XPRecap",23,108,454,0)
    self.frame.Visible=false
    return self
end

function Recap:hide()
    self.key=nil
    self.events=nil
    self.frame.Visible=false
end

function Recap:rank(level,xp,full)
    local data=self.receipt.before
    local d={level=level,prestige=data.prestige,master=data.master}
    local capped=level==P.cap(d)
    self.rankLabel.Text=P.label(d)
    self.fill.Size=UDim2.fromScale(capped and 1 or (full and 1 or xp/P.cost(level)),1)
    self.progress.Text=capped and (d.master and "MAX LEVEL / 1,000" or "LEVEL 55 / PRESTIGE AVAILABLE")
        or ("%d / %d XP  →  Level %d"):format(math.floor(xp),P.cost(level),level+1)
    self.fill.BackgroundColor3=data.master and C.mint or C.purple
end

function Recap:start(key,receipt)
    if self.key==key then return self.height end
    self:hide()
    self.key=key
    self.receipt=receipt
    self.frame:ClearAllChildren()
    self.frame.Visible=true
    self.height=166+#receipt.items*34
    self.frame.Size=UDim2.fromOffset(454,self.height)
    W.text(self.frame,"Heading",0,0,454,20,"XP EARNED",12,C.muted)
    self.rows={}
    self.events={}
    local running=table.clone(receipt.before)
    local subtotal=0
    for i,item in receipt.items do
        local row=W.box(self.frame,"Item"..i,0,26+(i-1)*34,454,30,C.ink)
        row.Visible=false
        local name=W.text(row,"Label",12,0,310,30,item.label,15,C.white,Enum.Font.GothamBold)
        local amount=W.text(row,"Amount",330,0,112,30,"",17,C.mint,Enum.Font.GothamBold)
        amount.TextXAlignment=Enum.TextXAlignment.Right
        local scale=Instance.new("UIScale"); scale.Parent=row
        self.rows[i]={frame=row,label=name,amount=amount,scale=scale,y=row.Position.Y.Offset}
        table.insert(self.events,{kind="item",index=i,subtotal=subtotal,duration=.38})
        for _,segment in Rewards.segments(running,item.amount) do
            table.insert(self.events,{kind="fill",segment=segment,duration=.8})
            if segment.levelUp then
                table.insert(self.events,{kind="level",level=segment.level+1,duration=.55})
            end
        end
        P.award(running,item.amount)
        subtotal+=item.amount
    end
    local totalY=30+#receipt.items*34
    W.box(self.frame,"Rule",0,totalY+4,454,1,C.line)
    W.text(self.frame,"TotalLabel",0,totalY+13,300,26,"TOTAL XP",14,C.white,Enum.Font.GothamBold)
    self.total=W.text(self.frame,"Total",300,totalY+13,154,26,"+0 XP",22,C.mint,Enum.Font.GothamBold)
    self.total.TextXAlignment=Enum.TextXAlignment.Right
    self.rankLabel=W.text(self.frame,"Rank",0,totalY+53,270,24,"",16,C.white,Enum.Font.GothamBold)
    self.levelUp=W.text(self.frame,"LevelUp",275,totalY+53,179,24,"",15,C.mint,Enum.Font.GothamBold)
    self.levelUp.TextXAlignment=Enum.TextXAlignment.Right
    local track=W.box(self.frame,"XPTrack",0,totalY+86,454,10,C.line)
    self.fill=W.box(track,"Fill",0,0,0,10,C.purple)
    self.progress=W.text(self.frame,"Progress",0,totalY+102,454,22,"",13,C.muted)
    self:rank(receipt.before.level,receipt.before.xp)
    self.index=1
    self.started=os.clock()+.2
    self.frame:SetAttribute("AnimationComplete",false)
    return self.height
end

function Recap:render(event,t)
    if event.kind=="item" then
        local row=self.rows[event.index]
        local item=self.receipt.items[event.index]
        row.frame.Visible=true
        row.frame.Position=UDim2.fromOffset(0,row.y+8*(1-ease(t)))
        row.scale.Scale=.9+.1*pop(t)
        row.label.TextTransparency=1-ease(t)
        row.amount.TextTransparency=1-ease(t)
        row.amount.Text=("+%d XP"):format(math.floor(item.amount*ease(t)))
        self.total.Text=("+%d XP"):format(event.subtotal+math.floor(item.amount*ease(t)))
        self.levelUp.Text=""
    elseif event.kind=="fill" then
        local s=event.segment
        self:rank(s.level,s.fromXP+(s.toXP-s.fromXP)*ease(t),s.capped)
        self.levelUp.Text=""
    elseif event.kind=="level" then
        self:rank(event.level,0)
        self.levelUp.Text="LEVEL UP!  "..event.level
        self.levelUp.TextSize=15+math.floor(5*(1-t))
        self.fill.BackgroundColor3=C.mint
    end
end

function Recap:tick()
    if not self.events or not self.frame.Visible then return end
    local now=os.clock()
    if now<self.started then return end
    while self.index<=#self.events do
        local event=self.events[self.index]
        local t=math.clamp((now-self.started)/event.duration,0,1)
        self:render(event,t)
        if t<1 then return end
        self.started+=event.duration
        self.index+=1
    end
    self.events=nil
    self:rank(self.receipt.after.level,self.receipt.after.xp)
    self.total.Text=("+%d XP"):format(self.receipt.total)
    local gained=self.receipt.after.level-self.receipt.before.level
    self.levelUp.TextSize=15
    self.levelUp.Text=gained>0 and ("+%d LEVEL%s"):format(gained,gained==1 and "" or "S") or ""
    self.frame:SetAttribute("AnimationComplete",true)
end

return Recap
