-- Server-recorded career totals. Crate openings share the inventory transaction.
local Stats={Limit=2^52,ReceiptLimit=128}
Stats.boards={
    {id="matchesPlayed",name="Matches Played",store="NOVA_Stats_Matches_v1",color="527eff",offset=24},
    {id="longestWinStreak",name="Longest Win Streak",store="NOVA_Stats_Streak_v1",color="ffde5b",offset=46},
    {id="wins",name="Wins",store="NOVA_Stats_Wins_v1",color="50e4ac",offset=68},
    {id="cratesOpened",name="Crates Opened",store="NOVA_Stats_Crates_v1",color="b56dff",offset=90},
}
local fields={"matchesPlayed","wins","losses","draws","currentWinStreak","longestWinStreak","shotsFired","cratesOpened"}
local function integer(n) return type(n)=="number" and n==n and n>=0 and n<=Stats.Limit and n%1==0 end
function Stats.new()
    local data={maps={},receipts={},receiptOrder={}}
    for _,field in fields do data[field]=0 end
    return data
end
function Stats.validate(raw)
    if raw==nil then return Stats.new() end
    if type(raw)~="table" then return nil end
    local data=Stats.new()
    for _,field in fields do if not integer(raw[field]) then return nil end;data[field]=raw[field] end
    if data.matchesPlayed~=data.wins+data.losses+data.draws or data.currentWinStreak>data.longestWinStreak
        or data.longestWinStreak>data.wins or type(raw.maps)~="table" or type(raw.receipts)~="table"
        or type(raw.receiptOrder)~="table" or #raw.receiptOrder>Stats.ReceiptLimit then return nil end
    local count,total,wins,losses,draws=0,0,0,0,0
    for id,row in raw.maps do
        count+=1
        if count>256 or type(id)~="string" or #id<1 or #id>80 or type(row)~="table"
            or type(row.name)~="string" or #row.name>100 or not integer(row.wins) or not integer(row.losses)
            or not integer(row.draws) or not integer(row.matches) or row.matches~=row.wins+row.losses+row.draws then return nil end
        data.maps[id]={name=row.name,wins=row.wins,losses=row.losses,draws=row.draws,matches=row.matches};total+=row.matches
        wins+=row.wins;losses+=row.losses;draws+=row.draws
    end
    if total~=data.matchesPlayed or wins~=data.wins or losses~=data.losses or draws~=data.draws then return nil end
    for index,key in raw.receiptOrder do
        if not integer(index) or index<1 or index>#raw.receiptOrder or type(key)~="string" or #key<1 or #key>160
            or raw.receipts[key]~=true or data.receipts[key] then return nil end
        data.receipts[key]=true;table.insert(data.receiptOrder,key)
    end
    for key in raw.receipts do if not data.receipts[key] then return nil end end
    return data
end
function Stats.record(data,event)
    if type(event)~="table" or type(event.key)~="string" or #event.key<1 or #event.key>160
        or type(event.mapId)~="string" or #event.mapId<1 or #event.mapId>80
        or type(event.mapName)~="string" or #event.mapName>100 or not integer(event.shots)
        or (event.outcome~="win" and event.outcome~="loss" and event.outcome~="draw") then return false end
    if data.receipts[event.key] then return true,true end
    if data.matchesPlayed>=Stats.Limit or data.shotsFired>Stats.Limit-event.shots then return false end
    local row=data.maps[event.mapId]
    if not row then
        local count=0;for _ in data.maps do count+=1 end
        if count>=256 then return false end
        row={name=event.mapName,wins=0,losses=0,draws=0,matches=0};data.maps[event.mapId]=row
    end
    local field=({win="wins",loss="losses",draw="draws"})[event.outcome]
    data.matchesPlayed+=1;data[field]+=1;data.shotsFired+=event.shots
    row.matches+=1;row[field]+=1;row.name=event.mapName
    data.currentWinStreak=event.outcome=="win" and data.currentWinStreak+1 or 0
    data.longestWinStreak=math.max(data.longestWinStreak,data.currentWinStreak)
    data.receipts[event.key]=true;table.insert(data.receiptOrder,event.key)
    if #data.receiptOrder>Stats.ReceiptLimit then data.receipts[table.remove(data.receiptOrder,1)]=nil end
    return true,false
end
function Stats.bestMap(data)
    local best
    for id,row in data.maps do
        if row.wins>0 and (not best or row.wins>best.wins or row.wins==best.wins and
            (row.wins/row.matches>best.wins/best.matches or row.wins/row.matches==best.wins/best.matches and id<best.id)) then
            best={id=id,name=row.name,wins=row.wins,matches=row.matches}
        end
    end
    return best
end
function Stats.ratio(data)
    return data.losses==0 and (data.wins>0 and "∞" or "—") or ("%.2f"):format(data.wins/data.losses)
end
return Stats
