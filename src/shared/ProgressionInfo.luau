local P=require(script.Parent.Progression)
local Info={}

function Info.current(data)
    return data and (data.master and 12 or data.prestige+1) or 0
end

function Info.next(data)
    local current=Info.current(data)
    return current>0 and current<12 and current+1 or nil
end

function Info.title(index)
    return index==12 and "Prestige Master" or ("Prestige %d"):format(index-1)
end

function Info.requirement(index)
    if index==1 then return "Starting rank", "Available when you first join." end
    local previous=index==12 and P.MaxPrestige or index-2
    return ("Prestige %d · Level %d"):format(previous,P.PrestigeLevel),
        ("Reach level %d in Prestige %d."):format(P.PrestigeLevel,previous)
end

function Info.status(data,index)
    local current=Info.current(data)
    if current==0 then return "Locked" end
    if index==current then return "Current" end
    if index<current then return "Unlocked" end
    if index==Info.next(data) then return P.canPrestige(data) and "Ready" or "Next" end
    return "Locked"
end

function Info.canClaim(data,index)
    return data~=nil and index==Info.next(data) and P.canPrestige(data)
end

function Info.fraction(data,index)
    if not data then return 0 end
    if index<=Info.current(data) then return 1 end
    if index==Info.next(data) then return math.clamp((data.level-1)/(P.PrestigeLevel-1),0,1) end
    return 0
end

function Info.after(index)
    if index==1 then return "Begin at level 1.","Earn XP and reach level 55 to unlock your first prestige." end
    if index==12 then return "Keep level 55. Unlock levels 56–1,000.","Current XP resets to zero. Lifetime XP is kept." end
    return "Reset to level 1 in your new prestige.","Current XP resets to zero. Lifetime XP is kept."
end

return table.freeze(Info)
