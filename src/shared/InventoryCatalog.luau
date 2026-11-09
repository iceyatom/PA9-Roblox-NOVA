-- Temporary cosmetic catalog. IDs are stable save keys; replace artwork without changing IDs.
local Catalog={}
Catalog.categories={
    {id="skins",name="Skins"},{id="bullets",name="Bullet Skins"},{id="tracers",name="Tracers"},
    {id="backgrounds",name="Backgrounds"},{id="sounds",name="Sound Effects"},{id="crates",name="Crates"},
}
Catalog.rarities={"Common","Rare","Epic","Legendary"}
Catalog.rarityColors={Common="9ca8bc",Rare="527eff",Epic="b56dff",Legendary="ffc857"}
Catalog.duplicateValues={Common=10,Rare=25,Epic=60,Legendary=150}
Catalog.items={}; Catalog.byId={}; Catalog.defaults={}
local function add(id,category,name,rarity,color,default,extra)
    local item={id=id,category=category,name=name,rarity=rarity,color=color,default=default==true,
        description=default and "The original NOVA look. Always available." or "Development cosmetic. Final collectible artwork will come later."}
    for k,v in extra or {} do item[k]=v end
    table.insert(Catalog.items,item); Catalog.byId[id]=item
    if default then Catalog.defaults[category]=id end
end
add("skin_default","skins","NOVA Classic","Common","527eff",true)
add("skin_mint","skins","Mint Circuit","Rare","50e4ac")
add("skin_ember","skins","Ember Core","Epic","ff974f")
add("bullet_default","bullets","Classic Pulse","Common","edf2ff",true)
add("bullet_ion","bullets","Ion Pulse","Rare","50e4ac")
add("bullet_solar","bullets","Solar Pulse","Legendary","ffc857")
add("tracer_default","tracers","No Tracer","Common","793dff",true,{length=0})
add("tracer_violet","tracers","Violet Wake","Rare","b56dff",false,{length=1.3})
add("tracer_comet","tracers","Comet Tail","Epic","50e4ec",false,{length=2})
add("card_default","backgrounds","Midnight","Common","111621",true)
add("card_nebula","backgrounds","Nebula","Epic","563098")
add("card_aurora","backgrounds","Aurora","Rare","176f70")
-- Existing Roblox built-in audio: development sounds, no external/audio uploads required.
add("sound_default","sounds","Classic / Silent","Common","9ca8bc",true,{sound="",pitch=1})
add("sound_arcade","sounds","Arcade Click","Rare","50e4ac",false,{sound="rbxasset://sounds/volume_slider.ogg",pitch=1.3})
add("sound_low","sounds","Low Pulse","Epic","b56dff",false,{sound="rbxasset://sounds/volume_slider.ogg",pitch=.7})
add("crate_dev","crates","NOVA Test Crate","Epic","793dff",false,
    {description="Contains one test cosmetic. Duplicates turn into Shards, a placeholder currency with no spending yet.",
    rewards={{id="skin_mint",weight=20},{id="skin_ember",weight=8},{id="bullet_ion",weight=20},
        {id="bullet_solar",weight=2},{id="tracer_violet",weight=20},{id="tracer_comet",weight=8},
        {id="card_nebula",weight=8},{id="card_aurora",weight=20},{id="sound_arcade",weight=20},{id="sound_low",weight=8}}})
function Catalog.get(equipped,category)
    local item=Catalog.byId[equipped and equipped[category]]
    return item and item.category==category and item or Catalog.byId[Catalog.defaults[category]]
end
function Catalog.rarityIndex(rarity) return table.find(Catalog.rarities,rarity) or 1 end
return Catalog
