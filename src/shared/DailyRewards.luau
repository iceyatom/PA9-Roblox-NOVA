-- Shared schedule and server-clock eligibility. All grants commit with Inventory.
local Daily={DaySeconds=86400,Days=30,PackItems={}}
-- Populate PackItems with the coming skin pack's cosmetic IDs when it releases.
-- Earned entitlements survive missed streaks and deliver on the next profile load.
function Daily.new()
    return {day=0,lastClaim=0,sequence=0,packEarned=false,packDelivered=false}
end
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end
function Daily.validate(raw)
    if raw==nil then return Daily.new() end
    if type(raw)~="table" or not integer(raw.day,2^52) or not integer(raw.lastClaim,2^52)
        or not integer(raw.sequence,2^52) or type(raw.packEarned)~="boolean" or type(raw.packDelivered)~="boolean"
        or raw.packDelivered and not raw.packEarned then return nil end
    if raw.day==0 then
        if raw.lastClaim~=0 or raw.sequence~=0 or raw.packEarned then return nil end
    elseif raw.lastClaim==0 or raw.sequence<raw.day or raw.day>=30 and not raw.packEarned then return nil end
    return {day=raw.day,lastClaim=raw.lastClaim,sequence=raw.sequence,packEarned=raw.packEarned,packDelivered=raw.packDelivered}
end
function Daily.reward(day)
    if not integer(day,2^52) or day<1 then return nil end
    if day==30 then return {day=day,kind="pack",quantity=1} end
    if day>=28 then return {day=day,kind="crates",id="crate_season1",quantity=10} end
    local week=math.floor((day-1)/7)+1
    local weekday=(day-1)%7+1
    if weekday==1 or weekday==4 or weekday==7 then
        return {day=day,kind="crates",id="crate_season1",quantity=2^(week-1)}
    end
    local kind=(weekday==2 or weekday==5) and "xp" or "crate"
    local minutes=({15,30,60,60})[week]
    return {day=day,kind=kind,id=("token_%s_%d"):format(kind,minutes),minutes=minutes,
        quantity=(weekday==6 and 2 or 1)*(week==4 and 2 or 1)}
end
function Daily.title(reward)
    if reward.kind=="pack" then return "Exclusive skin pack" end
    if reward.kind=="crates" then return ("%d crate%s"):format(reward.quantity,reward.quantity==1 and "" or "s") end
    return ("%d × %d min\n2× %s"):format(reward.quantity,reward.minutes,reward.kind=="xp" and "XP" or "Crates")
end
function Daily.status(data,now)
    local state=data.daily or Daily.new()
    now=now or os.time()
    local today=math.floor(now/Daily.DaySeconds)
    local previous=math.floor(state.lastClaim/Daily.DaySeconds)
    local reset=state.day>0 and today-previous>=2
    local day=(state.day==0 or reset) and 1 or state.day+1
    local unlock=state.day==0 and 0 or (previous+1)*Daily.DaySeconds
    return {day=day,claimable=state.day==0 or today>previous,reset=reset,sequence=state.sequence,
        unlockAt=unlock,resetAt=state.day>0 and (previous+2)*Daily.DaySeconds or 0}
end
return Daily
