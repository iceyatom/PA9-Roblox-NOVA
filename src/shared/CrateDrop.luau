-- One saved chance per player; only completed elimination wins consume a roll.
local Drop={BaseChance=25,WinMultiplier=1.5,LossMultiplier=1.2,ReceiptLimit=64}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Drop.validChance(n) return finite(n) and n>=Drop.BaseChance and n<=100 end
function Drop.outcome(winner,reason,seat)
    if reason~="Elimination" or (winner~=1 and winner~=2) or (seat~=1 and seat~=2) then return nil end
    return winner==seat and "win" or "loss"
end
function Drop.resolve(chance,outcome,roll)
    assert(Drop.validChance(chance),"Invalid crate chance")
    assert(outcome=="win" or outcome=="loss","Invalid match outcome")
    local awarded=false
    if outcome=="win" then
        assert(finite(roll) and roll>=0 and roll<=1,"Invalid crate roll")
        roll=math.min(roll,.999999999)
        awarded=roll<chance/100
    else roll=nil end
    return {outcome=outcome,chance=chance,landing=roll,awarded=awarded,
        nextChance=awarded and Drop.BaseChance or math.min(100,chance*(outcome=="win" and Drop.WinMultiplier or Drop.LossMultiplier))}
end
return Drop
