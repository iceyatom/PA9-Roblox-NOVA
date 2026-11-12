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
Catalog.batchTiers={
    {name="Uncommon",limit=6000,layers=1,frames=4,tail=.18},
    {name="Rare",limit=8500,layers=2,frames=8,tail=.24},
    {name="Epic",limit=9500,layers=3,frames=12,tail=.30},
    {name="Legendary",limit=9900,layers=3,frames=16,tail=.36},
    {name="Cosmic",limit=10000,layers=4,frames=16,tail=.40},
}
for index,set in require(script.Parent.BatchOneSets) do
    local tier=Catalog.batchTiers[table.find(Catalog.rarities,set.rarity)-1]
    for slot,piece in set.pieces do
        local category=Catalog.categories[slot].id
        local extra={setId=set.id,setName=set.name,artIndex=index-1,accent=set.accent,description=piece[3]}
        if category=="tracers" then
            extra.frames=tier.frames; extra.lifetime=tier.tail; extra.length=tier.tail*10; extra.layers=tier.layers
        end
        add(piece[1],category,piece[2],set.rarity,set.color,false,extra)
    end
end
local EditorModel=require(script.Parent.InventoryEditorModel)
local prismAssets=require(script.Parent.PrismAssets)
if prismAssets.skin~="" and prismAssets.bullet~="" and prismAssets.background~="" then
    for _,item in require(script.Parent.PrismPack) do
        add(item.id,item.category,item.name,item.rarity,item.color,false,item)
    end
end
local dragonAssets=require(script.Parent.DragonforgeAssets)
if dragonAssets.skin~="" and dragonAssets.bullet~="" then
    for _,item in require(script.Parent.DragonforgePack) do
        if item.category=="backgrounds" and (not dragonAssets.background or dragonAssets.background=="") then continue end
        add(item.id,item.category,item.name,item.rarity,item.color,false,item)
    end
end
local riftAssets=require(script.Parent.RiftglassAssets)
if riftAssets.skin~="" and riftAssets.bullet~="" and riftAssets.background~="" then
    for _,item in require(script.Parent.RiftglassPack) do
        add(item.id,item.category,item.name,item.rarity,item.color,false,item)
    end
end
local cipherAssets=require(script.Parent.CipherAssets)
if cipherAssets.skin~="" and cipherAssets.bullet~="" and cipherAssets.background~="" then
    for _,item in require(script.Parent.CipherPack) do add(item.id,item.category,item.name,item.rarity,item.color,false,item) end
end
local novaAssets=require(script.Parent.SupernovaAssets)
if novaAssets.skin~="" and novaAssets.bullet~="" and novaAssets.background~="" and novaAssets.halo~="" then
    for _,item in require(script.Parent.SupernovaPack) do add(item.id,item.category,item.name,item.rarity,item.color,false,item) end
end
local starAssets=require(script.Parent.StarfadeAssets)
if starAssets.skin~="" and starAssets.bullet~="" and starAssets.background~="" and starAssets.star~="" then
    for _,item in require(script.Parent.StarfadePack) do add(item.id,item.category,item.name,item.rarity,item.color,false,item) end
end
local armoryAssets=require(script.Parent.ArmoryAssets)
if armoryAssets.halo~="" then
    for _,item in require(script.Parent.ArmoryPack) do
        local set=armoryAssets[item.theme]
        if set and set.skin~="" and set.bullet~="" and set.background~="" and set.sprite~="" then add(item.id,item.category,item.name,item.rarity,item.color,false,item) end
    end
end
local Season=require(script.Parent.SeasonOne)
Catalog.rewardCrateId=Season.id;Catalog.crateAliases=Season.aliases
local allRewards={}
for _,item in Catalog.items do if not item.default and item.category~="crates" then table.insert(allRewards,{id=item.id,weight=1}) end end
allRewards=EditorModel.rarityRewards(allRewards,Catalog.byId,Season.rarityChances)
add(Season.id,"crates",Season.name,"Chest","59e0aa",false,{rewards=allRewards,image=Season.icon,rarityChances=Season.rarityChances,
    description="Contains one current collectible cosmetic. Rarity chances split equally among items in that rarity. Duplicates pay Shards."})
Catalog.editorBase=EditorModel.copy({items=Catalog.items,byId=Catalog.byId,defaults=Catalog.defaults,
    rarities=Catalog.rarities,categories=Catalog.categories})
local edits=EditorModel.copy(require(script.Parent.InventoryEdits))
-- Old crate configuration is retired, while unrelated item and collection edits survive.
for old in Season.aliases do edits.items[old]=nil;edits.crates[old]=nil end
Catalog.editorEdits=edits
local effective=EditorModel.apply(Catalog.editorBase,edits)
Catalog.items,Catalog.byId,Catalog.defaults=effective.items,effective.byId,effective.defaults
Catalog.retired=effective.retired
Catalog.collections=effective.collections
local season=Catalog.byId[Season.id]
season.description=("1 item from %d current cosmetics. %s Duplicates pay Shards."):format(#season.rewards,
    edits.crates[Season.id] and "Custom item chances." or "Fixed rarity chances, equal chance within each rarity.")
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
-- Aggregate the same item weights consumed by roll; rarity labels do not change a draw.
function Catalog.crateOdds(crate)
    local result={items=#crate.rewards,totalWeight=0,equalItems=true,rarities={}}
    local byRarity={}
    local firstWeight=crate.rewards[1].weight
    for _,reward in crate.rewards do
        local rarity=Catalog.byId[reward.id].rarity
        local row=byRarity[rarity]
        if not row then
            row={rarity=rarity,count=0,weight=0};byRarity[rarity]=row
            table.insert(result.rarities,row)
        end
        row.count+=1;row.weight+=reward.weight;result.totalWeight+=reward.weight
        if math.abs(reward.weight-firstWeight)>math.abs(firstWeight)*1e-9 then result.equalItems=false end
    end
    for _,row in result.rarities do row.percent=100*row.weight/result.totalWeight end
    table.sort(result.rarities,function(a,b)
        if a.weight==b.weight then return Catalog.rarityIndex(a.rarity)<Catalog.rarityIndex(b.rarity) end
        return a.weight>b.weight
    end)
    if result.equalItems then result.perItemPercent=100/result.items end
    return result
end
function Catalog.get(equipped,category)
    local item=Catalog.byId[equipped and equipped[category]]
    return item and item.category==category and item or Catalog.byId[Catalog.defaults[category]]
end
function Catalog.rarityIndex(rarity) return table.find(Catalog.rarities,rarity) or 1 end
return Catalog
