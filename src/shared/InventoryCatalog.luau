-- Temporary cosmetic catalog. IDs are stable save keys; replace artwork without changing IDs.
local Catalog={}
Catalog.categories={
    {id="skins",name="Skins"},{id="bullets",name="Bullet Skins"},{id="tracers",name="Tracers"},
    {id="backgrounds",name="Backgrounds"},{id="sounds",name="Sound Effects"},{id="crates",name="Crates"},
}
Catalog.rarities={"Common","Uncommon","Rare","Epic","Legendary","Cosmic"}
Catalog.rarityColors={Chest="59e0aa",Uncommon="49c976",Cosmic="f05252",Common="9ca8bc",Rare="527eff",Epic="b56dff",Legendary="ffc857"}
Catalog.duplicateValues={Uncommon=10,Cosmic=500,Common=10,Rare=25,Epic=60,Legendary=150,Chest=60}
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
Catalog.batchTiers={
    {name="Uncommon",limit=6000,layers=1,frames=4,tail=.18},
    {name="Rare",limit=8500,layers=2,frames=8,tail=.24},
    {name="Epic",limit=9500,layers=3,frames=12,tail=.30},
    {name="Legendary",limit=9900,layers=3,frames=16,tail=.36},
    {name="Cosmic",limit=10000,layers=4,frames=16,tail=.40},
}
local pools={}
local rewards={}
for _,tier in Catalog.batchTiers do pools[tier.name]={} end
for index,set in require(script.Parent.BatchOneSets) do
    local tier=Catalog.batchTiers[table.find(Catalog.rarities,set.rarity)-1]
    for slot,piece in set.pieces do
        local category=Catalog.categories[slot].id
        local extra={setId=set.id,setName=set.name,artIndex=index-1,accent=set.accent,description=piece[3]}
        if category=="tracers" then
            extra.frames=tier.frames; extra.lifetime=tier.tail; extra.length=tier.tail*10; extra.layers=tier.layers
        end
        add(piece[1],category,piece[2],set.rarity,set.color,false,extra)
        local tierIndex=table.find(Catalog.batchTiers,tier)
        local previous=tierIndex>1 and Catalog.batchTiers[tierIndex-1].limit or 0
        table.insert(rewards,{id=piece[1],weight=(tier.limit-previous)/100})
    end
    table.insert(pools[set.rarity],set)
end
add("crate_batch1","crates","Items Batch 1 Chest","Chest","59e0aa",false,{
    rewards=rewards,
    description="1 item · No pity. Duplicates pay Shards.\nUncommon 60% / 10 · Rare 25% / 25\nEpic 10% / 60 · Legendary 4% / 150\nCosmic 1% / 500",
})
-- Expand the original tier/set/category draw into equivalent per-item percentages.
for _,reward in rewards do
    local item=Catalog.byId[reward.id]
    reward.weight/= (#pools[item.rarity]*5)
end
local EditorModel=require(script.Parent.InventoryEditorModel)
local prismAssets=require(script.Parent.PrismAssets)
if prismAssets.skin~="" and prismAssets.bullet~="" and prismAssets.background~="" then
    for _,item in require(script.Parent.PrismPack) do
        add(item.id,item.category,item.name,item.rarity,item.color,false,item)
    end
end
Catalog.editorBase=EditorModel.copy({items=Catalog.items,byId=Catalog.byId,defaults=Catalog.defaults,
    rarities=Catalog.rarities,categories=Catalog.categories})
local edits=require(script.Parent.InventoryEdits)
local effective=EditorModel.apply(Catalog.editorBase,edits)
Catalog.items,Catalog.byId,Catalog.defaults=effective.items,effective.byId,effective.defaults
Catalog.retired=effective.retired
local editedBatch=edits.crates.crate_batch1~=nil
for id,edit in edits.items do
    if edit.deleted and Catalog.editorBase.byId[id].category~="crates" then editedBatch=true end
end
function Catalog.roll(crate,value)
    local total=0
    for _,reward in crate.rewards do total+=reward.weight end
    value=math.clamp(value,0,.999999999)*total
    for _,reward in crate.rewards do
        value-=reward.weight
        if value<0 then return reward.id end
    end
    return crate.rewards[#crate.rewards].id
end
function Catalog.batchTier(draw)
    for _,tier in Catalog.batchTiers do if draw<=tier.limit then return tier.name end end
    error("Invalid rarity draw")
end
function Catalog.rollBatch(random)
    if editedBatch then return Catalog.roll(Catalog.byId.crate_batch1,random:NextNumber()) end
    local pool=pools[Catalog.batchTier(random:NextInteger(1,10000))]
    local category=random:NextInteger(1,5)
    return pool[random:NextInteger(1,#pool)].pieces[category][1]
end
function Catalog.get(equipped,category)
    local item=Catalog.byId[equipped and equipped[category]]
    return item and item.category==category and item or Catalog.byId[Catalog.defaults[category]]
end
function Catalog.rarityIndex(rarity) return table.find(Catalog.rarities,rarity) or 1 end
return Catalog
