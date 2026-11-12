-- Robux item shop. Prices shown here are display copies; Roblox charges the developer product's own price.
-- productId is the Roblox developer product for each offer (0 = not created yet; see README "Item shop").
local Season=require(script.Parent.SeasonOne)
local Shop={CrateId=Season.id,LedgerLimit=64,MaxBoostSeconds=366*86400}
Shop.sections={
    {id="xp",name="Double XP",unit="Double XP",
        blurb="Every duel pays double XP while a token is active. Buying more adds time."},
    {id="crate",name="Double Crates",unit="Double Crates",
        blurb="Crates won from match wins are doubled while a token is active. Buying more adds time."},
    {id="crates",name=Season.name.."s",unit=Season.name,
        blurb="Each crate holds one collectible cosmetic. Duplicates pay Shards."},
}
Shop.products={
    {id="xp_15",section="xp",minutes=15,price=99,productId=3730608242},
    -- Product IDs and current prices match the Creator Dashboard configuration.
    {id="xp_30",section="xp",minutes=30,price=159,listPrice=198,productId=3730608283},
    {id="xp_60",section="xp",minutes=60,price=316,listPrice=396,productId=3730608303},
    {id="crate2x_15",section="crate",minutes=15,price=149,productId=3730608412},
    {id="crate2x_30",section="crate",minutes=30,price=238,listPrice=298,productId=3730608516},
    {id="crate2x_60",section="crate",minutes=60,price=476,listPrice=596,productId=3730608550},
    {id="crates_1",section="crates",quantity=1,price=49,productId=3730605879},
    {id="crates_5",section="crates",quantity=5,price=196,listPrice=245,productId=3730607863},
    {id="crates_10",section="crates",quantity=10,price=392,listPrice=490,productId=3730607934},
    {id="crates_50",section="crates",quantity=50,price=1960,listPrice=2450,productId=3730607984},
    {id="crates_100",section="crates",quantity=100,price=3200,listPrice=4900,productId=3730608105},
}
Shop.byId,Shop.byProductId,Shop.sectionById={},{},{}
for _,section in Shop.sections do Shop.sectionById[section.id]=section; section.products={} end
for _,product in Shop.products do
    assert(not Shop.byId[product.id],"Duplicate shop product "..product.id)
    Shop.byId[product.id]=product
    if product.productId~=0 then
        assert(not Shop.byProductId[product.productId],"Duplicate developer product for "..product.id)
        Shop.byProductId[product.productId]=product
    end
    table.insert(Shop.sectionById[product.section].products,product)
end
function Shop.title(product)
    if product.quantity then return ("%d CRATE%s"):format(product.quantity,product.quantity==1 and "" or "S") end
    return ("%d MINUTES"):format(product.minutes)
end
-- Whole percent saved against the struck-through list price.
function Shop.savings(product)
    if not product.listPrice or product.listPrice<=product.price then return 0 end
    return math.floor(100*(1-product.price/product.listPrice)+.5)
end
function Shop.commas(n)
    local text=tostring(n)
    while true do
        local replaced,count=text:gsub("^(%d+)(%d%d%d)","%1,%2")
        text=replaced
        if count==0 then return text end
    end
end
-- mm:ss under an hour, otherwise h:mm:ss.
function Shop.clock(seconds)
    seconds=math.max(0,math.ceil(seconds))
    local h,m,s=math.floor(seconds/3600),math.floor(seconds%3600/60),seconds%60
    return h>0 and ("%d:%02d:%02d"):format(h,m,s) or ("%d:%02d"):format(m,s)
end
return Shop
