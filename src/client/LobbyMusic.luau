local SoundService=game:GetService("SoundService")

local tracks={
    {name="Afterimage",id="rbxassetid://100375693825606"},
    {name="Night Current",id="rbxassetid://101375319366720"},
}
local loadTimeout=12
local retryDelay=30

local Music={}
Music.__index=Music

function Music.new()
    local folder=Instance.new("Folder")
    folder.Name="NOVALobbyMusic"
    local self=setmetatable({sounds={},index=1,generation=0,active=false,paused=false},Music)
    for index,track in tracks do
        local sound=Instance.new("Sound")
        sound.Name=track.name
        sound.SoundId=track.id
        sound.Volume=.2
        sound.Parent=folder
        self.sounds[index]=sound
        sound.Ended:Connect(function()
            if not self.active or self.index~=index then return end
            self:advance()
            self:playTrack(0)
        end)
    end
    folder.Parent=SoundService
    return self
end

function Music:advance()
    self.index=self.index%#tracks+1
end

function Music:playTrack(failed)
    self.generation+=1
    local generation=self.generation
    local sound=self.sounds[self.index]
    sound.TimePosition=0
    sound:Play()
    task.delay(loadTimeout,function()
        if self.generation~=generation or sound.IsLoaded then return end
        sound:Stop()
        self:advance()
        if failed+1<#tracks then
            self:playTrack(failed+1)
        else
            task.delay(retryDelay,function()
                if self.generation==generation then self:playTrack(0) end
            end)
        end
    end)
end

function Music:setActive(active)
    if self.active==active then return end
    self.active=active
    local sound=self.sounds[self.index]
    if active then
        if self.paused then sound:Resume() else self:playTrack(0) end
        self.paused=false
    else
        self.generation+=1
        self.paused=sound.IsLoaded and sound.IsPlaying
        if self.paused then sound:Pause() else sound:Stop() end
    end
end

return Music
