local P=require(script.Parent.Progression)
local Bots=require(script.Parent.Bots)
local Rewards={}

-- doubled: the player's Double XP token was active when the duel finished.
-- botLevel is the opponent's difficulty ID for bot duels.
function Rewards.items(won,doubled,botLevel)
    local percent=botLevel and Bots.levels[botLevel].xpPercent or 100
    local items={{label=botLevel and "Bot duel completed" or "Duel completed",amount=math.floor(P.PlayXP*percent/100)}}
    if won and P.WinXP>P.PlayXP then
        table.insert(items,{label="Victory bonus",amount=math.floor((P.WinXP-P.PlayXP)*percent/100)})
    end
    if doubled then
        local total=0
        for _,item in items do total+=item.amount end
        table.insert(items,{label="Double XP token",amount=total})
    end
    return items
end

-- Capture the actual server award, including the state before it changed.
function Rewards.apply(data,items)
    local receipt={before=table.clone(data),items={},total=0}
    for _,item in items do
        assert(type(item.amount)=="number" and item.amount>=0 and item.amount%1==0,"Invalid reward item")
        table.insert(receipt.items,{label=item.label,amount=item.amount})
        receipt.total+=item.amount
    end
    P.award(data,receipt.total)
    receipt.after=table.clone(data)
    return receipt
end

-- Every segment ends at a threshold or the final XP value, so the client can
-- show each level-up without guessing from the replicated final rank.
function Rewards.segments(data,amount)
    local level,xp,cap=data.level,data.xp,P.cap(data)
    local segments={}
    while amount>0 and level<cap do
        local cost=P.cost(level)
        local used=math.min(amount,cost-xp)
        local levelUp=xp+used==cost
        table.insert(segments,{level=level,fromXP=xp,toXP=xp+used,cost=cost,levelUp=levelUp})
        amount-=used
        xp+=used
        if levelUp then level+=1; xp=0 end
    end
    if #segments==0 and level==cap then
        table.insert(segments,{level=level,fromXP=0,toXP=0,cost=P.cost(level),capped=true})
    end
    return segments
end

return Rewards
