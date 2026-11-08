-- Original transparent artwork and generation prompts live in assets/ranks.
-- Prestige 0..10 map to entries 1..11; Master has its own final crest.
local entries={
    {key="prestige-00",name="Bronze Chevron",image="rbxassetid://93994146507852"},
    {key="prestige-01",name="Silver Bullet",image="rbxassetid://109256343489090"},
    {key="prestige-02",name="Emerald Dagger",image="rbxassetid://139397342452082"},
    {key="prestige-03",name="Sapphire Shield",image="rbxassetid://112899663260254"},
    {key="prestige-04",name="Amethyst Axe",image="rbxassetid://79559141243707"},
    {key="prestige-05",name="Ruby Warhammer",image="rbxassetid://137411168497382"},
    {key="prestige-06",name="Lightning Trident",image="rbxassetid://72370392565704"},
    {key="prestige-07",name="Crystal Scepter",image="rbxassetid://98210023530949"},
    {key="prestige-08",name="Infernal Crown",image="rbxassetid://100820490419422"},
    {key="prestige-09",name="Void Phoenix",image="rbxassetid://124173369328925"},
    {key="prestige-10",name="Celestial Dragon",image="rbxassetid://77496303576573"},
    {key="prestige-master",name="Cosmic Star",image="rbxassetid://93791584889378"},
}
for _,entry in entries do table.freeze(entry) end
table.freeze(entries)
local Icons={entries=entries}

function Icons.get(data)
    if not data then return nil end
    if data.master then return entries[12] end
    local prestige=data.prestige
    if type(prestige)~="number" or prestige%1~=0 or prestige<0 or prestige>10 then return nil end
    return entries[prestige+1]
end

return table.freeze(Icons)
