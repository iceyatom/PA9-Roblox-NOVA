-- Quest definitions and pure progress/claim rules. Only the server changes saved
-- quest state; it shares the leased inventory profile with career stats.
local Quests={DaySeconds=86400,DailyCount=3,WeeklyCount=3,Limit=2^52,RecapRows=4}

-- metric: matches, wins, shots, hits, flawless, crates, maps (distinct maps this
-- period) or streak (best run of consecutive wins this period).
-- Rewards always carry xp. Add item="soon" (or a future cosmetic ID) for an item.
local function quest(id,metric,goal,xp,title,text)
    return {id=id,metric=metric,goal=goal,xp=xp,title=title,text=text}
end
Quests.daily={
    quest("d_play3","matches",3,250,"Warm-up","Play 3 duels"),
    quest("d_play5","matches",5,400,"Regular","Play 5 duels"),
    quest("d_win1","wins",1,250,"First blood","Win a duel"),
    quest("d_win2","wins",2,400,"Double down","Win 2 duels"),
    quest("d_hits25","hits",25,300,"On target","Land 25 shots"),
    quest("d_shots60","shots",60,250,"Trigger happy","Fire 60 shots"),
    quest("d_maps2","maps",2,300,"Tourist","Play on 2 different maps"),
    quest("d_streak2","streak",2,500,"Back to back","Win 2 duels in a row"),
}
Quests.weekly={
    quest("w_play20","matches",20,1500,"Dedicated","Play 20 duels"),
    quest("w_win10","wins",10,2500,"Contender","Win 10 duels"),
    quest("w_hits150","hits",150,2000,"Marksman","Land 150 shots"),
    quest("w_shots400","shots",400,1500,"Suppressing fire","Fire 400 shots"),
    quest("w_streak3","streak",3,2500,"Hat trick","Win 3 duels in a row"),
    quest("w_maps4","maps",4,2000,"World tour","Play on 4 different maps"),
    quest("w_flawless1","flawless",1,3000,"Untouched","Win a duel without taking a hit"),
    quest("w_crates3","crates",3,1500,"Unboxing","Open 3 crates"),
}
-- Career quests read lifetime career stats, so existing players keep their history.
-- single: wording for a goal of exactly one.
local function career(id,stat,title,text,goals,single)
    local xp={500,1000,2500,5000,10000}
    local tiers={}
    for i,goal in goals do tiers[i]={goal=goal,xp=xp[i]} end
    tiers[#tiers].item="soon"
    return {id=id,stat=stat,title=title,text=text,single=single,tiers=tiers}
end
Quests.career={
    career("c_matches","matchesPlayed","Veteran","Play %s duels",{10,50,150,500,1000}),
    career("c_wins","wins","Champion","Win %s duels",{5,25,100,250,500}),
    career("c_hits","shotsHit","Sharpshooter","Land %s shots",{100,500,2500,10000,25000}),
    career("c_streak","longestWinStreak","Unstoppable","Reach a %s-win streak",{2,3,5,8,12}),
    career("c_flawless","flawlessWins","Untouchable","Win %s duels without taking a hit",{1,5,15,40,100},"Win a duel without taking a hit"),
    career("c_crates","cratesOpened","Collector","Open %s crates",{5,25,100,250,500}),
}
local pools={daily=Quests.daily,weekly=Quests.weekly}
local counts={daily=Quests.DailyCount,weekly=Quests.WeeklyCount}
Quests.SetBonusCrates={daily=3,weekly=10}
local kinds={"daily","weekly"}
local byId,careerById={},{}
for _,kind in kinds do for _,def in pools[kind] do byId[def.id]=def end end
for _,def in Quests.career do careerById[def.id]=def end

local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=(max or Quests.Limit) and n%1==0 end
local function commas(n)
    local text=tostring(n)
    while true do
        local changed
        text,changed=text:gsub("^(%d+)(%d%d%d)","%1,%2")
        if changed==0 then return text end
    end
end
Quests.commas=commas

-- Daily periods are UTC days; weekly periods start Monday 00:00 UTC.
function Quests.period(kind,now)
    local day=math.floor(now/Quests.DaySeconds)
    return kind=="daily" and day or math.floor((day+3)/7)
end
function Quests.resetAt(kind,period)
    return kind=="daily" and (period+1)*Quests.DaySeconds or ((period+1)*7-3)*Quests.DaySeconds
end
-- Every server derives the same rotation from the period number. Small modular
-- arithmetic keeps the result exact in doubles and identical in tests.
function Quests.selection(kind,period)
    local pool=pools[kind]
    local order={}
    for i in pool do
        local x=((period%65521)*131+i*977+(kind=="weekly" and 7919 or 0))%65521
        for _=1,3 do x=(x*75+74)%65537 end
        order[i]={index=i,rank=x}
    end
    table.sort(order,function(a,b) return a.rank==b.rank and a.index<b.index or a.rank<b.rank end)
    local chosen,metrics={},{}
    for _,entry in order do
        local def=pool[entry.index]
        if #chosen<counts[kind] and not metrics[def.metric] then
            metrics[def.metric]=true
            table.insert(chosen,def.id)
        end
    end
    return chosen
end

local function slot(period) return {period=period,run=0,maps={},list={}} end
function Quests.new()
    return {claimedXP=0,autoXP=0,daily=slot(0),weekly=slot(0),career={}}
end
function Quests.validate(raw)
    if raw==nil then return Quests.new() end
    if type(raw)~="table" or not integer(raw.claimedXP) or not integer(raw.autoXP) or raw.autoXP>raw.claimedXP
        or type(raw.career)~="table" then return nil end
    local data=Quests.new()
    data.claimedXP=raw.claimedXP;data.autoXP=raw.autoXP
    for _,kind in kinds do
        local old=raw[kind]
        if type(old)~="table" or not integer(old.period) or not integer(old.run) or type(old.maps)~="table"
            or type(old.list)~="table" or #old.list>16 then return nil end
        local copy=slot(old.period);copy.run=old.run
        if old.bonusAwarded~=nil and type(old.bonusAwarded)~="boolean" then return nil end
        copy.bonusAwarded=old.bonusAwarded
        local mapCount=0
        for id,value in old.maps do
            mapCount+=1
            if mapCount>32 or type(id)~="string" or #id<1 or #id>80 or value~=true then return nil end
            copy.maps[id]=true
        end
        local seen={}
        for index,entry in old.list do
            if not integer(index) or type(entry)~="table" or type(entry.id)~="string" or #entry.id>32 or seen[entry.id]
                or not integer(entry.progress) or type(entry.claimed)~="boolean" then return nil end
            seen[entry.id]=true
            local def=byId[entry.id]
            -- A quest removed from the pool leaves the list; its slot refills next reset.
            if def then
                if entry.claimed and entry.progress<def.goal then return nil end
                table.insert(copy.list,{id=entry.id,progress=math.min(entry.progress,def.goal),claimed=entry.claimed})
            end
        end
        data[kind]=copy
    end
    local careerCount=0
    for id,tier in raw.career do
        careerCount+=1
        if careerCount>64 or type(id)~="string" or #id>32 or not integer(tier,64) then return nil end
        local def=careerById[id]
        if def then data.career[id]=math.min(tier,#def.tiers) end
    end
    return data
end

function Quests.stale(state,now)
    return Quests.period("daily",now)>state.daily.period or Quests.period("weekly",now)>state.weekly.period
end

function Quests.setBonusReady(state,kind)
    local current=state[kind]
    if current.bonusAwarded or #current.list~=counts[kind] then return false end
    for _,entry in current.list do
        if entry.progress<byId[entry.id].goal then return false end
    end
    return true
end
-- Move to the current period. Finished quests nobody claimed pay out here, so
-- earned rewards are never lost. Time never moves a period backwards.
function Quests.roll(state,now)
    for _,kind in kinds do
        local period=Quests.period(kind,now)
        if period>state[kind].period then
            for _,entry in state[kind].list do
                local def=byId[entry.id]
                if def and not entry.claimed and entry.progress>=def.goal then
                    local xp=math.min(def.xp,Quests.Limit-state.claimedXP)
                    state.claimedXP+=xp;state.autoXP+=xp
                end
            end
            local fresh=slot(period)
            for _,id in Quests.selection(kind,period) do table.insert(fresh.list,{id=id,progress=0,claimed=false}) end
            state[kind]=fresh
        end
    end
end

local function add(state,kind,metric,amount)
    for _,entry in state[kind].list do
        local def=byId[entry.id]
        if def.metric==metric then entry.progress=math.min(def.goal,entry.progress+amount) end
    end
end
-- event is the server's career stats event plus time, hits and flawless.
function Quests.record(state,event)
    local now=event.time or os.time()
    Quests.roll(state,now)
    local won=event.outcome=="win"
    for _,kind in kinds do
        local current=state[kind]
        -- A result saved after its period ended no longer counts for that period.
        if Quests.period(kind,now)==current.period then
            current.run=won and math.min(Quests.Limit,current.run+1) or 0
            local newMap=false
            if not current.maps[event.mapId] then
                local count=0
                for _ in current.maps do count+=1 end
                if count<32 then current.maps[event.mapId]=true;newMap=true end
            end
            add(state,kind,"matches",1)
            add(state,kind,"wins",won and 1 or 0)
            add(state,kind,"shots",event.shots or 0)
            add(state,kind,"hits",event.hits or 0)
            add(state,kind,"flawless",won and event.flawless==true and 1 or 0)
            add(state,kind,"maps",newMap and 1 or 0)
            for _,entry in current.list do
                local def=byId[entry.id]
                if def.metric=="streak" then entry.progress=math.min(def.goal,math.max(entry.progress,current.run)) end
            end
        end
    end
end
-- Progress outside a match result, such as crate openings.
function Quests.progress(state,metric,amount,now)
    Quests.roll(state,now or os.time())
    for _,kind in kinds do add(state,kind,metric,amount) end
end

local function careerTier(state,stats,def)
    local claimed=state.career[def.id] or 0
    local tier=def.tiers[claimed+1]
    return claimed,tier,stats and stats[def.stat] or 0
end
-- Keys name the exact period or tier, so a stale or repeated click cannot claim
-- a different reward than the one the player saw.
function Quests.claim(state,stats,key,now)
    if type(key)~="string" or #key>64 then return false,"Invalid quest." end
    Quests.roll(state,now or os.time())
    local kind,a,b=key:match("^(%a+):([%w_]+):([%w_]+)$")
    if kind=="career" then
        local def=careerById[a]
        if not def then return false,"Unknown quest." end
        local claimed,tier,value=careerTier(state,stats,def)
        if tostring(claimed+1)~=b then return false,"Reward already claimed." end
        if not tier or value<tier.goal then return false,"Quest not complete yet." end
        if state.claimedXP>Quests.Limit-tier.xp then return false,"Quest rewards unavailable." end
        state.career[def.id]=claimed+1
        state.claimedXP+=tier.xp
        return true,{xp=tier.xp,item=tier.item,title=def.title,tier=claimed+1}
    elseif kind=="daily" or kind=="weekly" then
        if a~=tostring(state[kind].period) then return false,"This quest has reset." end
        for _,entry in state[kind].list do
            if entry.id==b then
                local def=byId[entry.id]
                if entry.claimed then return false,"Reward already claimed." end
                if entry.progress<def.goal then return false,"Quest not complete yet." end
                if state.claimedXP>Quests.Limit-def.xp then return false,"Quest rewards unavailable." end
                entry.claimed=true
                state.claimedXP+=def.xp
                return true,{xp=def.xp,item=def.item,title=def.title}
            end
        end
    end
    return false,"Unknown quest."
end
function Quests.ack(state)
    state.autoXP=0
    return true
end

-- Display rows for the menu and match recap. Never changes the saved state.
function Quests.view(state,stats,now)
    local copy=assert(Quests.validate(state),"Invalid quest state")
    Quests.roll(copy,now or os.time())
    local view={autoXP=copy.autoXP,ready=0,daily={},weekly={},career={}}
    for _,kind in kinds do
        local current=copy[kind]
        view[kind]={period=current.period,resetAt=Quests.resetAt(kind,current.period),list={},bonusAwarded=current.bonusAwarded}
        for _,entry in current.list do
            local def=byId[entry.id]
            local complete=entry.progress>=def.goal
            if complete and not entry.claimed then view.ready+=1 end
            table.insert(view[kind].list,{key=("%s:%d:%s"):format(kind,current.period,def.id),kind=kind,title=def.title,text=def.text,
                progress=entry.progress,goal=def.goal,xp=def.xp,item=def.item,complete=complete,claimed=entry.claimed})
        end
        if Quests.setBonusReady(copy,kind) then
            view[kind].bonusKey=("%s:%d"):format(kind,current.period)
            view.ready+=1
        end
    end
    for _,def in Quests.career do
        local claimed,tier,value=careerTier(copy,stats,def)
        local shown=tier or def.tiers[#def.tiers]
        local complete=tier~=nil and value>=tier.goal
        if complete then view.ready+=1 end
        table.insert(view.career,{key=("career:%s:%d"):format(def.id,claimed+1),kind="career",title=def.title,
            text=shown.goal==1 and def.single or def.text:format(commas(shown.goal)),progress=math.min(value,shown.goal),goal=shown.goal,xp=shown.xp,item=shown.item,
            complete=complete,claimed=tier==nil,tier=math.min(claimed+1,#def.tiers),tiers=#def.tiers,
            finalItem=claimed+1<#def.tiers and def.tiers[#def.tiers].item~=nil})
    end
    return view
end
-- Rows worth showing after a match: daily and weekly quests that moved, plus
-- career tiers that just became claimable. Finished quests come first.
function Quests.changes(before,after)
    local old={}
    for _,kind in {"daily","weekly","career"} do
        for _,row in before[kind].list or before[kind] do old[row.key]=row end
    end
    local rows={}
    for _,kind in {"daily","weekly","career"} do
        for _,row in after[kind].list or after[kind] do
            local previous=old[row.key]
            local from=previous and previous.progress or 0
            local moved=kind=="career" and row.complete and not (previous and previous.complete)
                or kind~="career" and not row.claimed and row.progress>from
            if moved then
                table.insert(rows,{kind=kind,title=row.title,text=row.text,from=math.min(from,row.progress),to=row.progress,goal=row.goal,
                    xp=row.xp,complete=row.complete,order=#rows+1})
            end
        end
    end
    table.sort(rows,function(a,b)
        if a.complete~=b.complete then return a.complete end
        return a.order<b.order
    end)
    while #rows>Quests.RecapRows do table.remove(rows) end
    return rows
end
return Quests
