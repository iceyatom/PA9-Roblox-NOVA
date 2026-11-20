-- AI opponent difficulties. Shared so the client can name them; only the server runs a bot.
local Bots={CrateChanceScale=0.5,Name="NOVA Bot",order={"beginner","intermediate","experienced","veteran"}}
-- fire: average seconds between shots.        spread: largest aim error in degrees.
-- patience: chance to hold fire with no clear shot.
-- dodge: chance to notice each incoming shot. react: seconds before acting on it.
-- pause: share of movement choices spent standing still.
-- hop: unprompted jumps per second.           chase: seconds without a clear shot before closing in.
Bots.levels={
    beginner={name="Beginner",xpPercent=40,fire=1.1,spread=16,patience=0.3,dodge=0.1,react=0.45,pause=0.45,hop=0.15,chase=4},
    intermediate={name="Intermediate",xpPercent=60,fire=0.6,spread=9,patience=0.6,dodge=0.4,react=0.3,pause=0.25,hop=0.3,chase=2.5},
    experienced={name="Experienced",xpPercent=80,fire=0.33,spread=4.5,patience=0.85,dodge=0.7,react=0.18,pause=0.1,hop=0.5,chase=1.2},
    veteran={name="Veteran",xpPercent=100,fire=0.17,spread=1.5,patience=1,dodge=0.92,react=0.08,pause=0,hop=0.7,chase=0.6},
}
-- A bot fills a duel seat with this key instead of a Player.
function Bots.key(level)
    assert(Bots.levels[level],"Unknown bot level")
    return {bot=true,level=level,UserId=-table.find(Bots.order,level),DisplayName=Bots.Name}
end
function Bots.is(key) return type(key)=="table" and key.bot==true end
return Bots
