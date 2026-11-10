-- Shared validation/application for the Studio editor and runtime catalog.
local Model={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Model.copy(value)
    if type(value)~="table" then return value end
    local result={}; for k,v in value do result[k]=Model.copy(v) end; return result
end
function Model.validate(edits,base)
    if type(edits)~="table" or edits.version~=1 or type(edits.items)~="table" or type(edits.crates)~="table" then
        return false,"Invalid inventory edits format."
    end
    for id,edit in edits.items do
        local item=base.byId[id]
        if not item or type(edit)~="table" then return false,"Unknown item: "..tostring(id) end
        for key in edit do if key~="name" and key~="rarity" and key~="deleted" then return false,"Unsupported item field: "..tostring(key) end end
        if edit.name~=nil and (type(edit.name)~="string" or #edit.name>80 or not edit.name:match("%S") or edit.name:find("%c")) then return false,"Names need 1–80 characters, without control characters." end
        if edit.rarity~=nil and not table.find(base.rarities,edit.rarity) and not (item.category=="crates" and edit.rarity=="Chest") then return false,"Invalid rarity for "..id end
        if edit.deleted~=nil and type(edit.deleted)~="boolean" then return false,"Invalid deletion flag." end
        if edit.deleted and (item.default or id=="crate_batch1") then return false,"Defaults and the duel reward chest cannot be deleted." end
    end
    for id,rewards in edits.crates do
        local crate=base.byId[id]
        if not crate or crate.category~="crates" or type(rewards)~="table" or #rewards==0 then return false,"Crates need at least one reward: "..tostring(id) end
        local total,seen=0,{}
        for index,reward in rewards do
            if type(index)~="number" or index%1~=0 or index<1 or index>#rewards or type(reward)~="table" then return false,"Invalid reward list." end
            local item=base.byId[reward.id]
            if not item or item.default or item.category=="crates" or (edits.items[reward.id] or {}).deleted or seen[reward.id] then return false,"Invalid or repeated reward: "..tostring(reward.id) end
            if not finite(reward.weight) or reward.weight<=0 or reward.weight>100 then return false,"Reward percentages must be above 0 and at most 100." end
            total+=reward.weight; seen[reward.id]=true
        end
        if math.abs(total-100)>.0001 then return false,("%s chances total %.6g%%; they must total 100%%."):format(id,total) end
    end
    -- A deletion must never leave an available crate empty.
    for _,crate in base.items do if crate.rewards and not (edits.items[crate.id] or {}).deleted then
        local count=0
        for _,reward in edits.crates[crate.id] or crate.rewards do
            if not (edits.items[reward.id] or {}).deleted then count+=1 end
        end
        if count==0 then return false,"Deletion would empty "..crate.name..". Add a replacement reward first." end
    end end
    return true
end
function Model.apply(base,edits)
    local ok,message=Model.validate(edits,base); assert(ok,message)
    local result={items={},byId={},retired={},defaults=Model.copy(base.defaults),rarities=base.rarities,categories=base.categories}
    for _,original in base.items do
        local edit=edits.items[original.id] or {}
        if edit.deleted then
            result.retired[original.id]={id=original.id,name=edit.name or original.name,
                rarity=edit.rarity or original.rarity,category=original.category}
        else
            local item=Model.copy(original)
            item.name=edit.name or item.name; item.rarity=edit.rarity or item.rarity
            if item.rewards then
                item.rewards={}
                local total=0
                for _,reward in edits.crates[item.id] or original.rewards do
                    if not (edits.items[reward.id] or {}).deleted then
                        table.insert(item.rewards,Model.copy(reward)); total+=reward.weight
                    end
                end
                for _,reward in item.rewards do reward.weight=reward.weight*100/total end
            end
            table.insert(result.items,item); result.byId[item.id]=item
        end
    end
    return result
end
return Model
