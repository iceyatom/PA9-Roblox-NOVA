-- Server-owned fire-rate policy, shared by duel and practice shot acceptance.
-- ConfigService updates the limit; clients cannot set it or supply the clock.
local Limiter={Key="NOVA_MaxShotsPerSecond",Default=12,Minimum=1,Maximum=60}
local rate=Limiter.Default

function Limiter.valid(value)
    return type(value)=="number" and value==value and value%1==0
        and value>=Limiter.Minimum and value<=Limiter.Maximum
end
function Limiter.setRate(value)
    if not Limiter.valid(value) then return false end
    rate=value
    return true
end
function Limiter.getRate() return rate end
function Limiter.allow(state,now)
    if type(now)~="number" or now~=now or math.abs(now)==math.huge then return false end
    -- One shot per interval, with no banked shots or catch-up burst after idling.
    -- Tiny tolerance avoids losing an exact boundary to floating-point rounding.
    if state.lastAcceptedShot and now+1e-9<state.lastAcceptedShot+1/rate then return false end
    state.lastAcceptedShot=now
    return true
end
return Limiter
