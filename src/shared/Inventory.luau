-- Pure ownership/equipment/reward transactions. No client-provided rewards or quantities.
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Drop=require(script.Parent.CrateDrop)
local Inventory={}
local function integer(n,max) return type(n)=="number" and n==n and n>=0 and n<=max and n%1==0 end
function Inventory.new()
    return {owned={},equipped=table.clone(Catalog.defaults),favorites={},shards=0,receipts={},receiptOrder={},wins={},openSequence=0,reducedEffects=false,retirementSequence=0,
        crateChance=Drop.BaseChance,dropReceipts={},dropOrder={}}
end
function Inventory.owns(data,id)
    local item=Catalog.byId[id]
    return item~=nil and (item.default or (data.owned[id] or 0)>0)
end
function Inventory.validate(raw)
    if type(raw)~="table" or type(raw.owned)~="table" or type(raw.equipped)~="table"
        or type(raw.favorites)~="table" or not integer(raw.shards,1000000000) then return nil end
    local data=Inventory.new(); data.shards=raw.shards
    if raw.retirementSequence~=nil and not integer(raw.retirementSequence,2^52) then return nil end
    data.retirementSequence=raw.retirementSequence or 0
    if raw.retirementNotice~=nil then
        local notice=raw.retirementNotice
        if type(notice)~="table" or not integer(notice.sequence,2^52) or notice.sequence<1
            or notice.sequence~=data.retirementSequence or type(notice.items)~="table" or #notice.items<1 or #notice.items>1000
            or not integer(notice.totalShards,2^52) then return nil end
        local rows,total,seen={},0,{}
        for index,row in notice.items do
            if type(index)~="number" or index%1~=0 or index<1 or index>#notice.items or type(row)~="table"
                or type(row.id)~="string" or #row.id>64 or seen[row.id]
                or type(row.name)~="string" or #row.name>80 or type(row.rarity)~="string" or #row.rarity>32
                or not integer(row.quantity,2^52) or row.quantity<1 or not integer(row.shards,2^52) then return nil end
            seen[row.id]=true; total+=row.shards
            table.insert(rows,{id=row.id,name=row.name,rarity=row.rarity,quantity=row.quantity,shards=row.shards})
        end
        if total~=notice.totalShards then return nil end
        data.retirementNotice={sequence=notice.sequence,items=rows,totalShards=total}
    end
    if raw.openSequence~=nil and not integer(raw.openSequence,2^52) then return nil end
    data.openSequence=raw.openSequence or 0
    data.reducedEffects=raw.reducedEffects==true
    if raw.wins~=nil and type(raw.wins)~="table" then return nil end
    for key,expires in raw.wins or {} do
        if type(key)~="string" or not integer(expires,2^52) then return nil end
        if expires>os.time() then data.wins[key]=expires end
    end
    if raw.crateChance~=nil then
        if not Drop.validChance(raw.crateChance) then return nil end
        data.crateChance=raw.crateChance
    end
    if raw.dropReceipts~=nil or raw.dropOrder~=nil then
        if type(raw.dropReceipts)~="table" or type(raw.dropOrder)~="table" or #raw.dropOrder>Drop.ReceiptLimit then return nil end
        local seen={}
        for index,key in raw.dropOrder do
            if not integer(index,#raw.dropOrder) or index<1 or type(key)~="string" or #key<1 or #key>160 or seen[key] then return nil end
            seen[key]=true;local r=raw.dropReceipts[key]
            if type(r)~="table" or r.key~=key or not integer(r.expires,2^52)
                or (r.outcome~="win" and r.outcome~="loss") or not Drop.validChance(r.chance) or not Drop.validChance(r.nextChance)
                or type(r.awarded)~="boolean" then return nil end
            if r.outcome=="win" then
                if type(r.landing)~="number" or r.landing~=r.landing or r.landing<0 or r.landing>=1
                    or r.awarded~=(r.landing<r.chance/100) then return nil end
            elseif r.landing~=nil or r.awarded then return nil end
            if r.expires>os.time() then
                if data.wins[key]~=r.expires then return nil end
                data.dropReceipts[key]=table.clone(r);table.insert(data.dropOrder,key)
            end
        end
        for key in raw.dropReceipts do if not seen[key] then return nil end end
    end
    for id,count in raw.owned do
        if type(id)~="string" or not integer(count,id=="crate_season1" and 3000000 or 1000000) then return nil end
        -- Preserve unknown IDs for saves written by a newer catalog/server.
        if not Catalog.retired[id] and count>0 then
            local target=(Catalog.crateAliases or {})[id] or id
            data.owned[target]=(data.owned[target] or 0)+count
        end
    end
    if (data.owned.crate_season1 or 0)>3000000 then return nil end
    for category,id in raw.equipped do
        local item=Catalog.byId[id]
        if item and item.category==category and category~="crates" and Inventory.owns(data,id) then data.equipped[category]=id end
    end
    for id,value in raw.favorites do local target=(Catalog.crateAliases or {})[id] or id;if value==true and Inventory.owns(data,target) then data.favorites[target]=true end end
    if type(raw.receiptOrder)=="table" and type(raw.receipts)=="table" then
        for _,key in raw.receiptOrder do
            local r=raw.receipts[key]
            local crateId=type(r)=="table" and ((Catalog.crateAliases or {})[r.crateId] or r.crateId)
            if #data.receiptOrder<24 and type(key)=="string" and #key<=64 and type(r)=="table"
                and Catalog.byId[r.itemId] and Catalog.byId[crateId] and integer(r.shards,1000000000)
                and type(r.duplicate)=="boolean" then
                data.receipts[key]={itemId=r.itemId,crateId=crateId,shards=r.shards,duplicate=r.duplicate,requestId=key}
                if r.batchCount==3 or r.batchCount==5 then data.receipts[key].batchCount=r.batchCount end
                table.insert(data.receiptOrder,key)
            end
        end
    end
    -- Reconciliation is pure and deterministic so UpdateAsync can retry safely.
    -- Removed ownership and the credit/notice are saved in the same leased write.
    local removals={}
    for id,item in Catalog.retired do
        local count=raw.owned[id] or 0
        if count>0 then removals[id]=item.category=="crates" and count or 1 end
    end
    for category,id in raw.equipped do
        local item=Catalog.retired[id]
        if item and item.category==category and not removals[id] then removals[id]=1 end
    end
    if next(removals) then
        if data.retirementSequence>=2^52 then return nil end
        data.retirementSequence+=1
        local notice=data.retirementNotice or {items={},totalShards=0}
        notice.sequence=data.retirementSequence
        local ids={}; for id in removals do table.insert(ids,id) end; table.sort(ids)
        for _,id in ids do
            local item=Catalog.retired[id]; local quantity=removals[id]
            local credit=math.min(1000000000-data.shards,(Catalog.duplicateValues[item.rarity] or Catalog.duplicateValues.Common)*quantity)
            data.shards+=credit; notice.totalShards+=credit
            local entry
            for _,row in notice.items do if row.id==id then entry=row; break end end
            if entry then
                entry.quantity+=quantity; entry.shards+=credit
            else table.insert(notice.items,{id=id,name=item.name,rarity=item.rarity,quantity=quantity,shards=credit}) end
        end
        data.retirementNotice=notice
    end
    return data
end
function Inventory.ackRetirements(data,sequence)
    local notice=data.retirementNotice
    if not notice and sequence==tostring(data.retirementSequence) then return true,nil,true end
    if not notice or sequence~=tostring(notice.sequence) then return false,"The item notice changed. Please review the latest list." end
    data.retirementNotice=nil
    return true
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
    if item.category=="crates" then data.owned[id]=math.max(data.owned[id] or 0,math.min(1000000,(data.owned[id] or 0)+amount))
    elseif not item.default then data.owned[id]=1 end
    return true
end
function Inventory.matchReward(data,key,expires,outcome,roll)
    if type(key)~="string" or #key<1 or #key>160 or not integer(expires,2^52) then return false,"Invalid match reward." end
    if expires<=os.time() then return false,"Reward expired." end
    if outcome~="win" and outcome~="loss" then return false,"Invalid match outcome." end
    -- Retain the legacy expiry ledger even after the bounded display receipt is evicted.
    if data.wins[key] then
        local receipt=data.dropReceipts[key]
        if receipt and receipt.outcome~=outcome then return false,"Match result already recorded." end
        return true,receipt and table.clone(receipt),true
    end
    if outcome=="win" and (type(roll)~="number" or roll~=roll or roll<0 or roll>1) then return false,"Invalid crate roll." end
    local receipt=Drop.resolve(data.crateChance,outcome,roll)
    if receipt.awarded and (data.owned.crate_season1 or 0)>=1000000 then return false,"Chest inventory full." end
    receipt.key=key;receipt.expires=expires
    data.wins[key]=expires
    data.crateChance=receipt.nextChance
    if receipt.awarded then Inventory.grant(data,"crate_season1",1) end
    data.dropReceipts[key]=receipt;table.insert(data.dropOrder,key)
    if #data.dropOrder>Drop.ReceiptLimit then data.dropReceipts[table.remove(data.dropOrder,1)]=nil end
    return true,table.clone(receipt)
end
function Inventory.open(data,id,key,roll)
    id=(Catalog.crateAliases or {})[id] or id
    if type(key)~="string" or #key<1 or #key>64 then return false,"Invalid request." end
    if data.receipts[key] then
        if data.receipts[key].crateId~=id or data.receipts[key].batchCount then return false,"Request already used." end
        return true,data.receipts[key],true
    end
    local crate=Catalog.byId[id]
    if not crate or not crate.rewards or (data.owned[id] or 0)<1 then return false,"You do not own this crate." end
    local sequence=tonumber(key:match("^open:(%d+)$"))
    if sequence and sequence~=data.openSequence+1 then return false,"Opening expired." end
    local value=type(roll)=="number" and roll or roll:NextNumber()
    local selected=Catalog.roll(crate,value)
    if sequence then data.openSequence=sequence end
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
-- A batch uses consecutive durable opening keys and commits in the same inventory mutation.
function Inventory.openMany(data,id,key,count,rolls)
    if count~=3 and count~=5 then return false,"Invalid crate count." end
    id=(Catalog.crateAliases or {})[id] or id
    if type(key)~="string" then return false,"Invalid request." end
    local first=tonumber(key:match("^open:(%d+)$"))
    if not first then return false,"Invalid request." end
    local previous=data.receipts[key]
    if previous then
        if previous.crateId~=id or previous.batchCount~=count then return false,"Request already used." end
        local results={}
        for i=1,count do
            local receipt=data.receipts["open:"..(first+i-1)]
            if not receipt or receipt.crateId~=id then return false,"Opening expired." end
            table.insert(results,receipt)
        end
        return true,results,true
    end
    if first~=data.openSequence+1 then return false,"Opening expired." end
    if not Catalog.byId[id] or not Catalog.byId[id].rewards or (data.owned[id] or 0)<count then return false,"Not enough crates." end
    if type(rolls)~="table" or #rolls~=count then return false,"Invalid rolls." end
    for _,roll in rolls do if type(roll)~="number" or roll~=roll or roll<0 or roll>1 then return false,"Invalid rolls." end end
    local results={}
    for i=1,count do
        local ok,receipt=Inventory.open(data,id,"open:"..(first+i-1),rolls[i])
        assert(ok,receipt);table.insert(results,receipt)
    end
    results[1].batchCount=count
    return true,results
end
return Inventory
