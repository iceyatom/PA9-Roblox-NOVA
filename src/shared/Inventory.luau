-- Pure ownership/equipment/reward transactions. No client-provided rewards or quantities.
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Inventory={}
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end
function Inventory.new()
    return {owned={},equipped=table.clone(Catalog.defaults),favorites={},shards=0,receipts={},receiptOrder={}}
end
function Inventory.owns(data,id)
    local item=Catalog.byId[id]
    return item~=nil and (item.default or (data.owned[id] or 0)>0)
end
function Inventory.validate(raw)
    if type(raw)~="table" or type(raw.owned)~="table" or type(raw.equipped)~="table"
        or type(raw.favorites)~="table" or not integer(raw.shards,1000000000) then return nil end
    local data=Inventory.new(); data.shards=raw.shards
    for id,count in raw.owned do
        if type(id)~="string" or not integer(count,1000000) then return nil end
        if Catalog.byId[id] and count>0 then data.owned[id]=count end
    end
    for category,id in raw.equipped do
        local item=Catalog.byId[id]
        if item and item.category==category and category~="crates" and Inventory.owns(data,id) then data.equipped[category]=id end
    end
    for id,value in raw.favorites do if value==true and Inventory.owns(data,id) then data.favorites[id]=true end end
    if type(raw.receiptOrder)=="table" and type(raw.receipts)=="table" then
        for _,key in raw.receiptOrder do
            local r=raw.receipts[key]
            if #data.receiptOrder<24 and type(key)=="string" and #key<=64 and type(r)=="table"
                and Catalog.byId[r.itemId] and Catalog.byId[r.crateId] and integer(r.shards,1000000000)
                and type(r.duplicate)=="boolean" then
                data.receipts[key]={itemId=r.itemId,crateId=r.crateId,shards=r.shards,duplicate=r.duplicate,requestId=key}
                table.insert(data.receiptOrder,key)
            end
        end
    end
    return data
end
function Inventory.equip(data,id)
    local item=Catalog.byId[id]
    if not item or item.category=="crates" or not Inventory.owns(data,id) then return false,"You do not own this cosmetic." end
    data.equipped[item.category]=data.equipped[item.category]==id and Catalog.defaults[item.category] or id
    return true
end
function Inventory.favorite(data,id)
    if not Inventory.owns(data,id) then return false,"You do not own this item." end
    data.favorites[id]=not data.favorites[id] or nil
    return true
end
function Inventory.grant(data,id,amount)
    local item=Catalog.byId[id]
    if not item or not integer(amount,1000) or amount<1 then return false,"Invalid grant." end
    if item.category=="crates" then data.owned[id]=math.min(1000000,(data.owned[id] or 0)+amount)
    elseif not item.default then data.owned[id]=1 end
    return true
end
function Inventory.open(data,id,key,roll)
    if type(key)~="string" or #key<1 or #key>64 then return false,"Invalid request." end
    if data.receipts[key] then
        if data.receipts[key].crateId~=id then return false,"Request already used." end
        return true,data.receipts[key],true
    end
    local crate=Catalog.byId[id]
    if not crate or not crate.rewards or (data.owned[id] or 0)<1 then return false,"You do not own this crate." end
    local total=0
    for _,reward in crate.rewards do total+=reward.weight end
    local value=math.clamp(roll,0,.999999999)*total
    local selected=crate.rewards[#crate.rewards].id
    for _,reward in crate.rewards do value-=reward.weight; if value<0 then selected=reward.id; break end end
    local item=Catalog.byId[selected]
    local duplicate=Inventory.owns(data,selected)
    local shards=duplicate and Catalog.duplicateValues[item.rarity] or 0
    data.owned[id]-=1
    if data.owned[id]==0 then data.owned[id]=nil; data.favorites[id]=nil end
    if duplicate then data.shards=math.min(1000000000,data.shards+shards) else data.owned[selected]=1 end
    local receipt={itemId=selected,crateId=id,duplicate=duplicate,shards=shards,requestId=key}
    data.receipts[key]=receipt; table.insert(data.receiptOrder,key)
    if #data.receiptOrder>24 then data.receipts[table.remove(data.receiptOrder,1)]=nil end
    return true,receipt
end
return Inventory
