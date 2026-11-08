-- Server-owned clock and shot count. A client never submits a score or a hit.
local Practice={}
Practice.__index=Practice
Practice.Countdown=3
Practice.Duration=30
-- Far above human tapping speed; bounds remote spam and cosmetic projectile work.
Practice.MinShotInterval=1/50

function Practice.new()
    return setmetatable({sessions={},serial=0},Practice)
end

function Practice:start(player,now)
    local old=self.sessions[player]
    if old and old.phase~="Results" then return nil end
    self.serial+=1
    local session={id=self.serial,phase="Countdown",starts=now+self.Countdown,
        ends=now+self.Countdown+self.Duration,score=0,sequence=0,lastShot=-math.huge}
    self.sessions[player]=session
    return session
end

function Practice:fire(player,id,sequence,now)
    local s=self.sessions[player]
    if not s or s.id~=id or s.phase~="Playing" or now<s.starts or now>=s.ends then return false end
    if type(sequence)~="number" or sequence%1~=0 or sequence<=s.sequence or sequence>2147483647 then return false end
    s.sequence=sequence
    if now-s.lastShot<self.MinShotInterval then return false end
    s.lastShot=now
    s.score+=1
    return true
end

function Practice:step(now,changed,finished)
    for player,s in self.sessions do
        if s.phase~="Results" and now>=s.ends then
            s.phase="Results"
            finished(player,s)
        elseif s.phase=="Countdown" and now>=s.starts then
            s.phase="Playing"
            changed(player,s)
        end
    end
end

function Practice:remove(player)
    self.sessions[player]=nil
end
return Practice
