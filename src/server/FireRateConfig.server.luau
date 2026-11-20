-- Live tuning via Studio File > Open Configs. No player-facing admin remote.
local ConfigService=game:GetService("ConfigService")
local Limiter=require(script.Parent.ShotLimiter)
local host=script.Parent
local snapshot,connection
local dirty=true
local lastAttempt=-math.huge
local function status(message)
    host:SetAttribute("MaxShotsPerSecond",Limiter.getRate())
    host:SetAttribute("FireRateConfigStatus",message)
end
status("Using default: 12 shots/sec")
local function refresh()
    if not snapshot then
        snapshot=ConfigService:GetConfigAsync()
        connection=snapshot.UpdateAvailable:Connect(function() dirty=true end)
    end
    snapshot:Refresh()
    local value=snapshot:GetValue(Limiter.Key)
    if value==nil then
        Limiter.setRate(Limiter.Default)
        status("Config missing; using default")
    elseif Limiter.setRate(value) then
        status("Config applied")
    else
        status("Invalid config; keeping last valid limit (whole number 1-60 required)")
        warn("[NOVA] Invalid "..Limiter.Key.."; keeping "..Limiter.getRate().." shots/sec")
    end
end
-- Loading or refreshing a config never blocks firing or removes the fallback cap.
while script.Parent do
    if dirty and os.clock()-lastAttempt>=1 then
        dirty=false
        lastAttempt=os.clock()
        local ok,err=pcall(refresh)
        if not ok then
            status("Config unavailable; keeping last valid limit")
            warn("[NOVA] Fire-rate config unavailable: "..tostring(err))
        end
    end
    task.wait(1)
    -- Retry unavailable loads/refreshes and periodically reconcile missed signals.
    if os.clock()-lastAttempt>=30 then dirty=true end
end
if connection then connection:Disconnect() end
