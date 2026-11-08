-- Shared rank rules. Only the server changes a player's progression.
local P={MaxPrestige=10,PrestigeLevel=55,MasterLevel=1000,WinXP=300,PlayXP=100}

local function integer(n,min,max)
    return type(n)=="number" and n==n and n>=min and n<=max and n%1==0
end

function P.new()
    return {level=1,prestige=0,master=false,xp=0,totalXP=0}
end

function P.cost(level)
    -- Master levels keep the level-55 cost instead of growing without bound.
    return 100+25*(math.min(level,P.PrestigeLevel)-1)
end

function P.cap(data) return data.master and P.MasterLevel or P.PrestigeLevel end

function P.validate(data)
    if type(data)~="table" or not integer(data.prestige,0,P.MaxPrestige)
        or type(data.master)~="boolean" or (data.master and data.prestige~=P.MaxPrestige)
        or not integer(data.level,data.master and P.PrestigeLevel or 1,P.cap(data))
        or not integer(data.xp,0,P.cost(data.level)-1)
        or not integer(data.totalXP,0,9007199254740991)
        or (data.level==P.cap(data) and data.xp~=0) then return nil end
    return {level=data.level,prestige=data.prestige,master=data.master,xp=data.xp,totalXP=data.totalXP}
end

function P.award(data,amount)
    assert(integer(amount,0,1000000000),"Invalid XP award")
    local before=data.level
    data.totalXP=math.min(9007199254740991,data.totalXP+amount)
    data.xp+=amount
    while data.level<P.cap(data) and data.xp>=P.cost(data.level) do
        data.xp-=P.cost(data.level)
        data.level+=1
    end
    -- No banked XP bypasses a prestige or the final cap.
    if data.level==P.cap(data) then data.xp=0 end
    return data.level-before
end

function P.canPrestige(data) return not data.master and data.level==P.PrestigeLevel end

function P.prestige(data)
    if not P.canPrestige(data) then return false end
    if data.prestige==P.MaxPrestige then
        data.master=true -- Keep level 55; the next earned level is Master 56.
    else
        data.prestige+=1
        data.level=1
    end
    data.xp=0
    return true
end

function P.label(data)
    if not data then return "Loading rank…" end
    if data.master then return ("Prestige Master · Lv. %d"):format(data.level) end
    if data.prestige>0 then return ("Prestige %d · Lv. %d"):format(data.prestige,data.level) end
    return ("Level %d"):format(data.level)
end

return table.freeze(P)
