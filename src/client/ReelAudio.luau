-- Shared map/crate reel sample and voice pool. Crossing events follow visible motion.
local Content=game:GetService("ContentProvider")
local Audio={SoundId="rbxassetid://92334355914521",Volume=.5}; Audio.__index=Audio
function Audio.new(parent,prefix)
    local self=setmetatable({sounds={},voice=0},Audio)
    for i=1,24 do
        local sound=Instance.new("Sound")
        sound.Name=(prefix or "ReelClick")..i; sound.SoundId=Audio.SoundId; sound.Volume=Audio.Volume
        sound.Parent=parent; table.insert(self.sounds,sound)
    end
    task.spawn(function() pcall(function() Content:PreloadAsync(self.sounds) end) end)
    return self
end
function Audio:click()
    self.voice=self.voice%#self.sounds+1
    local sound=self.sounds[self.voice]
    if not sound.IsLoaded then return end
    sound:Stop(); sound.TimePosition=0; sound:Play()
end
function Audio:advance(pin)
    -- At most one click per rendered frame; never burst through skipped cards after a stall.
    if self.lastPin and pin>self.lastPin then self:click() end
    self.lastPin=pin
end
function Audio:stop()
    self.lastPin=nil
    for _,sound in self.sounds do sound:Stop() end
end
return Audio
