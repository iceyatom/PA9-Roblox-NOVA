local Content=game:GetService("ContentProvider")
local Players=game:GetService("Players")

local riseId="rbxassetid://96820933477701"
local impactId="rbxassetid://125539321398091"
local Audio={RiseTime=1.24}
Audio.__index=Audio

-- Cache both cues when the menus load, without holding up the lobby or a reveal.
task.spawn(function() pcall(function() Content:PreloadAsync({riseId,impactId}) end) end)

local function sound(parent,name,id,volume)
    local cue=Instance.new("Sound")
    cue.Name=name;cue.SoundId=id;cue.Volume=volume;cue.Parent=parent
    return cue
end

local function reduced()
    return Players.LocalPlayer:GetAttribute("ReducedEffects")==true
end

function Audio.new(parent)
    return setmetatable({
        rising=sound(parent,"RevealRise",riseId,.28),
        impact=sound(parent,"RevealImpact",impactId,.55),
    },Audio)
end

function Audio:rise()
    if not reduced() then self.rising:Play() end
end

function Audio:land(soft)
    self.rising:Stop()
    self.impact:Stop()
    self.impact.Volume=reduced() and .18 or soft and .30 or .55
    self.impact:Play()
end

function Audio:stop()
    self.rising:Stop()
    self.impact:Stop()
end

return Audio
