-- NOVA Item Editor. Install beside NOVALevelEditor.lua in Studio's Plugins folder.
if not game:GetService("RunService"):IsEdit() then return end
local RS=game:GetService("ReplicatedStorage")
local Editor=game:GetService("ScriptEditorService")
local History=game:GetService("ChangeHistoryService")
local Http=game:GetService("HttpService")
local Content=game:GetService("ContentProvider")
local C={ink=Color3.fromHex("080b13"),panel=Color3.fromHex("111621"),raised=Color3.fromHex("1a2030"),
    line=Color3.fromHex("303747"),muted=Color3.fromHex("9ca8bc"),white=Color3.fromHex("edf2ff"),purple=Color3.fromHex("a47aff"),red=Color3.fromHex("ff5859")}
local toolbar=plugin:CreateToolbar("NOVA")
local toggle=toolbar:CreateButton("NOVAItemEditor","Manage NOVA items and crate chances","","Item Editor")
toggle.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGui("NOVAItemEditor",DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,1440,960,1040,720))
widget.Title="NOVA Item Editor"; widget.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local function make(class,props,parent)
    local object=Instance.new(class); for k,v in props do object[k]=v end; object.Parent=parent; return object
end
local function label(parent,name,text,height)
    return make("TextLabel",{Name=name,Size=UDim2.new(1,0,0,height or 28),BackgroundTransparency=1,Text=text,
        TextColor3=C.muted,TextSize=18,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},parent)
end
local function button(parent,name,text,width)
    local b=make("TextButton",{Name=name,Size=UDim2.new(width and 0 or 1,width or 0,0,40),BackgroundColor3=C.raised,BorderSizePixel=0,
        Text=text,TextColor3=C.white,TextSize=18,Font=Enum.Font.GothamBold,AutoButtonColor=true},parent)
    make("UICorner",{CornerRadius=UDim.new(0,4)},b); return b
end
local function field(parent,name,text)
    local b=make("TextBox",{Name=name,Size=UDim2.new(1,0,0,40),BackgroundColor3=C.ink,BorderSizePixel=0,ClearTextOnFocus=false,
        Text=text,TextColor3=C.white,PlaceholderColor3=C.muted,TextSize=18,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left},parent)
    make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},b); return b
end
local function stack(parent,name,width)
    local frame=make("ScrollingFrame",{Name=name,Size=UDim2.new(width and 0 or 1,width or 0,1,-96),Position=UDim2.fromOffset(0,56),
        BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},parent)
    make("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,16)},frame)
    make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},frame); return frame
end
local function clear(frame) for _,o in frame:GetChildren() do if o:IsA("GuiObject") then o:Destroy() end end end
local root=make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BorderSizePixel=0},widget)
local title=label(root,"Title","NOVA  /  ITEM EDITOR"); title.Position=UDim2.fromOffset(16,8); title.Size=UDim2.new(1,-32,0,36); title.TextColor3=C.purple; title.TextSize=26; title.Font=Enum.Font.GothamBold
local actions=make("Frame",{Name="Actions",Position=UDim2.fromOffset(16,52),Size=UDim2.new(1,-32,0,40),BackgroundTransparency=1},root)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},actions)
local save=button(actions,"Save","Save to place",154)
local export=button(actions,"Export","Export to repo",158)
local reload=button(actions,"Reload","Reload / discard",178)
local check=button(actions,"Check","Check changes",158)
local undo=button(actions,"Undo","Undo",76)
local redo=button(actions,"Redo","Redo",76)
for i,b in {save,export,reload,check,undo,redo} do b.LayoutOrder=i end
local tabs=make("Frame",{Name="TypeTabs",Position=UDim2.fromOffset(16,104),Size=UDim2.new(1,-32,0,60),BackgroundTransparency=1},root)
make("UIGridLayout",{CellSize=UDim2.new(1/7,-7,1,0),CellPadding=UDim2.fromOffset(8,0),SortOrder=Enum.SortOrder.LayoutOrder},tabs)
local search=field(root,"Search",""); search.Position=UDim2.fromOffset(16,176); search.Size=UDim2.new(.52,-24,0,40); search.PlaceholderText="Search this type by name or ID"
local rarityFilter=button(root,"RarityFilter","Rarity: All   ›"); rarityFilter.Position=UDim2.new(.52,8,0,176); rarityFilter.Size=UDim2.new(.24,-16,0,40)
local deleted=button(root,"Deleted","Show deleted: off"); deleted.Position=UDim2.new(.76,0,0,176); deleted.Size=UDim2.new(.24,-16,0,40)
local bulkBar=make("Frame",{Name="BulkActions",Position=UDim2.fromOffset(16,230),Size=UDim2.new(1,-32,0,40),BackgroundTransparency=1},root)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},bulkBar)
local multiSelect=button(bulkBar,"MultiSelect","Multi-select: off",184); multiSelect.LayoutOrder=1
local selectVisible=button(bulkBar,"SelectVisible","Select visible",156); selectVisible.LayoutOrder=2
local clearSelection=button(bulkBar,"ClearSelection","Clear selection",168); clearSelection.LayoutOrder=3
local deleteSelected=button(bulkBar,"DeleteSelected","Delete selected (0)",230); deleteSelected.LayoutOrder=4; deleteSelected.TextColor3=C.red
local selectionCount=label(bulkBar,"Count","",28); selectionCount.Size=UDim2.fromOffset(200,40); selectionCount.LayoutOrder=5; selectionCount.TextSize=16
local newCollection=button(bulkBar,"NewCollection","New collection",184); newCollection.LayoutOrder=1; newCollection.Visible=false
local browser=make("Frame",{Name="Browser",Position=UDim2.fromOffset(16,284),Size=UDim2.new(.52,-24,1,-340),BackgroundColor3=C.panel,BorderSizePixel=0},root)
local groupTitle=label(browser,"GroupTitle","Skins"); groupTitle.Position=UDim2.fromOffset(12,6); groupTitle.Size=UDim2.new(1,-24,0,32); groupTitle.TextColor3=C.white; groupTitle.TextSize=22; groupTitle.Font=Enum.Font.GothamBold
local list=make("ScrollingFrame",{Name="Items",Position=UDim2.fromOffset(12,46),Size=UDim2.new(1,-24,1,-58),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,ScrollBarImageColor3=C.purple,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},browser)
local grid=make("UIGridLayout",{CellSize=UDim2.fromOffset(210,198),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder},list)
local function layoutGrid()
    local width=math.max(1,list.AbsoluteSize.X-10)
    local columns=math.max(1,math.floor((width+12)/210))
    grid.CellSize=UDim2.fromOffset(math.floor((width-(columns-1)*12)/columns),198)
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
local detail=stack(root,"Details"); detail.Position=UDim2.new(.52,8,0,284); detail.Size=UDim2.new(.48,-24,1,-340)
local statusLabel=label(root,"Status","Open this editor in a NOVA place.",44); statusLabel.Position=UDim2.new(0,16,1,-48); statusLabel.Size=UDim2.new(1,-32,0,44)
local function status(text,error) statusLabel.Text=text; statusLabel.TextColor3=error and C.red or C.muted end
local S={dirty=false,selected=nil,filter=1,rarity=0,showDeleted=false,undo={},redo={},multi=false,selectedIds={},collections=false,selectedCollection=nil,collectionMode="members"}
local base,model,edits,module,loadedSource,art,assets,rarityColors,skinVisuals,prismVisuals
local renderList,renderDetail
local renderCollections,renderCollectionDetail
-- Share the square combat skins; other item types use inventory sprite cells.
local function itemIcon(parent,item,x,y,size)
    local image=make("ImageLabel",{Name="Sprite",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,Image=art and art[type(item)=="table" and item.category or item] or ""},parent)
    if type(item)=="table" and prismVisuals and prismVisuals.apply(image,item) then return image end
    if skinVisuals and skinVisuals.apply(image,item=="skins" and {category="skins",color="527eff"} or item) then return image end
    if type(item)=="table" and assets then
        if item.image then image.Image=item.image
        elseif item.artIndex~=nil then
            local index=item.artIndex
            image.Image=assets[item.category.."-"..(math.floor(index/16)+1)] or image.Image
            image.ImageRectSize=Vector2.new(256,256)
            image.ImageRectOffset=Vector2.new(index%4*256,math.floor(index%16/4)*256)
        end
    end
    return image
end
local function name(item) return (edits.items[item.id] or {}).name or item.name end
local function rarity(item) return (edits.items[item.id] or {}).rarity or item.rarity end
local function rarityColor(item) return Color3.fromHex((rarityColors or {})[rarity(item)] or "9ca8bc") end
local function isDeleted(id) return (edits.items[id] or {}).deleted==true end
local function deletable(item) return not item.default and item.id~="crate_season1" and not isDeleted(item.id) end
local function matches(item)
    local query=search.Text:lower()
    return item.category==base.categories[S.filter].id and (S.showDeleted or not isDeleted(item.id))
        and (S.rarity==0 or rarity(item)==(S.rarity==7 and "Chest" or base.rarities[S.rarity]))
        and (name(item):lower():find(query,1,true)~=nil or item.id:lower():find(query,1,true)~=nil)
end
local activeSoundPreview
local function stopSoundPreview()
    local preview=activeSoundPreview
    if not preview then return end
    activeSoundPreview=nil
    preview.sound:Stop(); preview.sound:Destroy()
    if preview.button.Parent then preview.button.Text="▶  Play sound preview" end
end
local function playSoundPreview(item,control)
    if activeSoundPreview and activeSoundPreview.button==control then
        stopSoundPreview(); status("Sound preview stopped."); return
    end
    stopSoundPreview()
    local sound=Instance.new("Sound")
    sound.Name="NOVAItemSoundPreview"; sound.SoundId=item.setId and assets.audio or item.sound
    sound.PlaybackSpeed=item.pitch or 1; sound.Volume=.22
    -- The widget is outside the saved place; previews never become game assets.
    sound.Parent=widget
    local preview={sound=sound,button=control,loading=true}
    activeSoundPreview=preview; control.Text="■  Cancel loading"
    status("Loading preview for "..name(item).."…")
    task.delay(10,function()
        if activeSoundPreview==preview and preview.loading then
            stopSoundPreview(); status("Audio could not load. Check the asset's availability and try again.",true)
        end
    end)
    task.spawn(function()
        local ok=pcall(function() Content:PreloadAsync({sound}) end)
        if activeSoundPreview~=preview then return end
        if not ok or not sound.IsLoaded then
            stopSoundPreview(); status("Audio could not load. Check the asset's availability and try again.",true); return
        end
        preview.loading=false
        local start=item.setId and item.artIndex or 0
        local finish=item.setId and start+.39 or sound.TimeLength
        if finish>sound.TimeLength or finish<=start then
            stopSoundPreview(); status("This sound clip is unavailable in the audio asset.",true); return
        end
        sound.PlaybackRegionsEnabled=true; sound.PlaybackRegion=NumberRange.new(start,finish)
        sound.Ended:Once(function()
            if activeSoundPreview==preview then stopSoundPreview(); status("Preview finished: "..name(item)) end
        end)
        control.Text="■  Stop sound preview"; status("Playing "..name(item))
        sound:Play()
        -- Bound playback even if an asset fails to report its Ended event.
        task.delay((finish-start)/sound.PlaybackSpeed+1,function()
            if activeSoundPreview==preview then stopSoundPreview(); status("Preview finished: "..name(item)) end
        end)
    end)
end
local function dirty()
    S.dirty=true; S.armed=nil; widget.Title="NOVA Item Editor • Unsaved"
end
local function push()
    table.insert(S.undo,model.copy(edits)); if #S.undo>60 then table.remove(S.undo,1) end; S.redo={}; dirty()
end
local function itemEdit(id) edits.items[id]=edits.items[id] or {}; return edits.items[id] end
local function cycleRarity(item)
    if isDeleted(item.id) then status("Restore this item before changing its rarity.",true);return end
    local options=table.clone(base.rarities)
    if item.category=="crates" then table.insert(options,"Chest") end
    local index=table.find(options,rarity(item)) or 0
    push();itemEdit(item.id).rarity=options[index%#options+1]
    renderList();renderDetail()
end
local function rewardsFor(crate)
    if crate.rarityChances and not edits.crates[crate.id] then
        return model.rarityRewards(crate.rewards,base.byId,crate.rarityChances,edits)
    end
    local result={}; local total=0
    for _,r in edits.crates[crate.id] or crate.rewards do
        if not isDeleted(r.id) then table.insert(result,{id=r.id,weight=r.weight}); total+=r.weight end
    end
    if not edits.crates[crate.id] then for _,r in result do r.weight=r.weight*100/total end end
    return result
end
local function normalize(rewards)
    local total=0; for _,r in rewards do total+=r.weight end
    if total<=0 then return false end
    for _,r in rewards do r.weight=r.weight*100/total end; return true
end
local function stageDelete(ids)
    local candidate=model.copy(edits); local count=0
    for id in ids do
        local item=base.byId[id]
        if item and deletable(item) then
            candidate.items[id]=candidate.items[id] or {}; candidate.items[id].deleted=true; count+=1
        end
    end
    if count==0 then status("Select deletable items first. Defaults and the duel chest are protected.",true); return end
    for crateId,rows in candidate.crates do
        if (candidate.items[crateId] or {}).deleted then candidate.crates[crateId]=nil
        else
            for i=#rows,1,-1 do if (candidate.items[rows[i].id] or {}).deleted then table.remove(rows,i) end end
            normalize(rows)
        end
    end
    local ok,message=model.validate(candidate,base)
    if not ok then status("Nothing deleted: "..message,true); return end
    push(); edits=candidate; S.selectedIds={}
    renderList(); renderDetail()
    status(("Marked %d item(s) for deletion. Save applies changes; owners receive duplicate-value Shards on their next login."):format(count))
end
local function updateCrate(id,fn)
    local rewards=rewardsFor(base.byId[id]); push(); fn(rewards); edits.crates[id]=rewards; renderDetail()
end
local function collectionData()
    local groups,byId,unassigned=model.collectionGroups(base,edits,S.showDeleted)
    local group={id="__unassigned",name="Unassigned items",items=unassigned,unassigned=true}
    table.insert(groups,group);byId[group.id]=group
    return groups,byId
end
local function updateCollections(fn,message)
    local candidate=model.copy(edits);candidate.collections=candidate.collections or {}
    fn(candidate)
    local ok,err=model.validate(candidate,base)
    if not ok then status(err,true);return false end
    push();edits=candidate;renderList();renderDetail();status(message or "Collection changes staged. Save to place to keep them.");return true
end
local function assignCollection(id,collectionId)
    return updateCollections(function(candidate)
        candidate.items[id]=candidate.items[id] or {};candidate.items[id].collectionId=collectionId
    end)
end
renderCollections=function()
    local groups=collectionData();local count=0;local query=search.Text:lower()
    for _,group in groups do
        local found=group.name:lower():find(query,1,true)~=nil
        local tier=S.rarity==0
        for _,item in group.items do
            found=found or (name(item).." "..item.id):lower():find(query,1,true)~=nil
            tier=tier or rarity(item)==(S.rarity==7 and "Chest" or base.rarities[S.rarity])
        end
        if found and tier then
            count+=1
            local b=button(list,"Collection_"..group.id,"");b.LayoutOrder=count;b.BackgroundColor3=C.ink
            make("UIStroke",{Color=S.selectedCollection==group.id and C.purple or C.line,Thickness=S.selectedCollection==group.id and 2 or 1},b)
            for i=1,math.min(4,#group.items) do itemIcon(b,group.items[i],12+(i-1)%2*48,8+math.floor((i-1)/2)*44,40) end
            local n=label(b,"Count",#group.items.." items");n.Position=UDim2.new(0,108,0,14);n.Size=UDim2.new(1,-116,0,60);n.TextSize=16
            local caption=label(b,"Name",group.name,70);caption.Position=UDim2.fromOffset(12,100);caption.Size=UDim2.new(1,-24,0,70);caption.TextColor3=C.white;caption.Font=Enum.Font.GothamBold
            b.Activated:Connect(function()S.selectedCollection=group.id;S.collectionMode="members";S.collectionQuery="";S.armed=nil;detail.CanvasPosition=Vector2.zero;renderList();renderDetail()end)
        end
    end
    groupTitle.Text="Collections  ·  "..count.." groups";layoutGrid()
    if count==0 then label(list,"Empty","No matching collections. Create one with New collection.",80) end
end
renderCollectionDetail=function()
    local _,byId=collectionData();local group=byId[S.selectedCollection]
    local order=0
    local function add(o)order+=1;o.LayoutOrder=order;return o end
    if not group then
        add(label(detail,"CreateTitle","CREATE COLLECTION",36)).TextColor3=C.purple
        add(label(detail,"CreateHelp","Create a collection, then add individual items from any type. Existing themed sets are grouped automatically.",84))
        local input=add(field(detail,"CollectionName",""));input.PlaceholderText="Collection name"
        local create=add(button(detail,"CreateCollection","Create collection"))
        create.Activated:Connect(function()
            local value=input.Text:match("^%s*(.-)%s*$");local id="collection_"..Http:GenerateGUID(false):gsub("-","")
            local previous=S.selectedCollection;S.selectedCollection=id;S.collectionMode="add";S.collectionQuery=""
            if not updateCollections(function(candidate)candidate.collections[id]={name=value}end,"Collection created. Choose items below, then Save to place.") then S.selectedCollection=previous end
        end)
        return
    end
    add(label(detail,"CollectionTitle",group.name,48)).TextColor3=C.white
    add(label(detail,"CollectionCount",#group.items.." items across all types",32))
    if not group.unassigned then
        local input=add(field(detail,"RenameCollection",group.name))
        input.FocusLost:Connect(function()
            local value=input.Text:match("^%s*(.-)%s*$");if value==group.name then return end
            if not updateCollections(function(candidate)
                candidate.collections[group.id]=candidate.collections[group.id] or {};candidate.collections[group.id].name=value
            end) then input.Text=group.name end
        end)
        local mode=add(button(detail,"CollectionMode",S.collectionMode=="add" and "Show members" or "Add / move individual items"))
        mode.Activated:Connect(function()S.collectionMode=S.collectionMode=="add" and "members" or "add";S.collectionQuery="";renderDetail()end)
        add(label(detail,"CollectionHelp",S.collectionMode=="add" and "Add unassigned items or move items from another collection. Item IDs, crate chances and artwork stay the same." or "Remove items to leave them unassigned, or open an item to edit its details.",76))
    else
        add(label(detail,"CollectionHelp","These items are not in a collection. Create or select a collection, then choose Add / move individual items.",76))
    end
    local query=add(field(detail,"CollectionItemSearch",S.collectionQuery or ""));query.PlaceholderText="Search items by name, ID, type or rarity"
    local rows=add(make("Frame",{Name="CollectionItems",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},detail))
    make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},rows)
    local function drawRows()
        clear(rows);local count=0;local definitions=model.collectionDefinitions(base,edits)
        local candidates=table.clone((not group.unassigned and S.collectionMode=="add") and base.items or group.items)
        table.sort(candidates,function(a,b)if a.category~=b.category then return a.category<b.category end;return name(a)<name(b)end)
        for _,item in candidates do
            local assigned=model.collectionFor(item,edits,definitions)
            local adding=not group.unassigned and S.collectionMode=="add"
            if (not adding or assigned~=group.id) and not (adding and isDeleted(item.id))
                and (name(item).." "..item.id.." "..item.category.." "..rarity(item)):lower():find((S.collectionQuery or ""):lower(),1,true) then
                count+=1;local row=make("Frame",{Name=item.id,LayoutOrder=count,Size=UDim2.new(1,0,0,136),BackgroundColor3=C.ink,BorderSizePixel=0},rows)
                itemIcon(row,item,6,12,56)
                local title=label(row,"Name",name(item),42);title.Position=UDim2.fromOffset(72,4);title.Size=UDim2.new(1,-190,0,42);title.TextColor3=C.white;title.TextSize=17
                local from=assigned and definitions[assigned].name or "Unassigned"
                local sub=label(row,"Type",item.category.." / "..rarity(item)..(adding and (" / "..from) or ""),42);sub.Position=UDim2.fromOffset(72,46);sub.Size=UDim2.new(1,-190,0,42);sub.TextSize=14
                local tier=button(row,"ItemRarity","Rarity: "..rarity(item).."   ›");tier.Position=UDim2.fromOffset(72,94);tier.Size=UDim2.new(1,-84,0,32);tier.TextSize=16
                tier.TextColor3=isDeleted(item.id) and C.muted or rarityColor(item)
                tier.Active=not isDeleted(item.id);tier.AutoButtonColor=tier.Active
                tier.Activated:Connect(function()cycleRarity(item)end)
                local action=button(row,"Membership",adding and (assigned and "Move here" or "Add") or "Edit item",104);action.Position=UDim2.new(1,-110,0,4);action.TextSize=15
                action.Activated:Connect(function()
                    if adding then assignCollection(item.id,group.id)
                    else
                        S.collections=false;S.selected=item.id
                        for i,kind in base.categories do if kind.id==item.category then S.filter=i;break end end
                        search.Text="";renderList();renderDetail()
                    end
                end)
                if not adding and not group.unassigned then
                    local remove=button(row,"RemoveMember","Remove",104);remove.Position=UDim2.new(1,-110,0,48);remove.TextSize=15
                    remove.Activated:Connect(function()assignCollection(item.id,false)end)
                end
            end
        end
        if count==0 then label(rows,"Empty","No matching items. Use Add / move individual items to build this collection.",80) end
    end
    query:GetPropertyChangedSignal("Text"):Connect(function()S.collectionQuery=query.Text;drawRows()end);drawRows()
    if not group.unassigned then
        local dissolve=add(button(detail,"DissolveCollection","Remove collection / keep its items"));dissolve.TextColor3=C.red
        dissolve.Activated:Connect(function()
            if S.armed~="collection:"..group.id or os.clock()-(S.armedAt or 0)>5 then S.armed="collection:"..group.id;S.armedAt=os.clock();status("Click again within five seconds to remove this collection. Its items will remain available and become unassigned.",true);return end
            updateCollections(function(candidate)
                local definitions=model.collectionDefinitions(base,candidate)
                for _,item in base.items do if model.collectionFor(item,candidate,definitions)==group.id then
                    candidate.items[item.id]=candidate.items[item.id] or {};candidate.items[item.id].collectionId=false
                end end
                candidate.collections[group.id]=candidate.collections[group.id] or {};candidate.collections[group.id].deleted=true
            end,"Collection removed; all items were kept. Save to place to keep this change.")
        end)
    end
end
renderList=function()
    clear(list); if not base then return end
    clear(tabs)
    for index,kind in base.categories do
        local tab=button(tabs,"Tab_"..kind.id,""); tab.LayoutOrder=index
        tab.BackgroundColor3=not S.collections and S.filter==index and Color3.fromHex("563098") or C.raised
        itemIcon(tab,kind.id,8,12,36)
        local text=label(tab,"Label",kind.name); text.Position=UDim2.fromOffset(50,0); text.Size=UDim2.new(1,-54,1,0); text.TextColor3=C.white; text.Font=Enum.Font.GothamBold
        tab.Activated:Connect(function()
            S.collections=false;S.filter=index; S.armed=nil; list.CanvasPosition=Vector2.zero
            local selected=base.byId[S.selected]
            if not selected or selected.category~=kind.id then
                S.selected=nil
                for _,item in base.items do if item.category==kind.id and (S.showDeleted or not isDeleted(item.id)) then S.selected=item.id; break end end
            end
            detail.CanvasPosition=Vector2.zero; renderList(); renderDetail()
        end)
    end
    local collectionTab=button(tabs,"Tab_collections","Collections");collectionTab.LayoutOrder=#base.categories+1;collectionTab.TextSize=17
    collectionTab.BackgroundColor3=S.collections and Color3.fromHex("563098") or C.raised
    collectionTab.Activated:Connect(function()S.collections=true;S.armed=nil;list.CanvasPosition=Vector2.zero;search.Text="";detail.CanvasPosition=Vector2.zero;renderList();renderDetail()end)
    newCollection.Visible=S.collections;multiSelect.Visible=not S.collections
    search.PlaceholderText=S.collections and "Search collections or their items" or "Search this type by name or ID"
    if S.collections then
        for _,control in {selectVisible,clearSelection,deleteSelected,selectionCount} do control.Visible=false end
        renderCollections();return
    end
    selectionCount.Visible=true
    local selectedCount,hiddenCount=0,0
    for id in S.selectedIds do
        local item=base.byId[id]
        if not item or not deletable(item) then S.selectedIds[id]=nil
        else selectedCount+=1; if not matches(item) then hiddenCount+=1 end end
    end
    deleteSelected.Text=("Delete selected (%d)"):format(selectedCount)
    selectionCount.Text=hiddenCount>0 and ("%d hidden by filters"):format(hiddenCount) or ""
    for _,control in {selectVisible,clearSelection,deleteSelected} do control.Visible=S.multi end
    local count=0
    for _,item in base.items do
        if matches(item) then
            count+=1
            local b=button(list,item.id,""); b.LayoutOrder=count; b.BackgroundColor3=C.ink
            local highlighted=S.multi and S.selectedIds[item.id] or not S.multi and item.id==S.selected
            make("UIStroke",{Color=highlighted and C.purple or C.line,Thickness=highlighted and 2 or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
            local icon=itemIcon(b,item,12,8,84); icon.ImageTransparency=isDeleted(item.id) and .55 or 0
            local badge=S.multi and (not deletable(item) and "PROTECTED" or S.selectedIds[item.id] and "✓ SELECTED" or "□ SELECT") or isDeleted(item.id) and "DELETED" or item.default and "DEFAULT" or item.category=="crates" and "CRATE" or ""
            local state=label(b,"State",badge); state.Position=UDim2.new(0,102,0,14); state.Size=UDim2.new(1,-112,0,52); state.TextSize=16; state.TextColor3=isDeleted(item.id) and C.red or C.muted
            local caption=label(b,"Name",name(item),52); caption.Position=UDim2.fromOffset(12,94); caption.Size=UDim2.new(1,-24,0,52); caption.TextSize=20; caption.TextColor3=C.white; caption.Font=Enum.Font.GothamBold; caption.TextTruncate=Enum.TextTruncate.AtEnd
            local tier=label(b,"Rarity",rarity(item)); tier.Position=UDim2.fromOffset(12,152); tier.Size=UDim2.new(1,-24,0,28); tier.TextColor3=rarityColor(item)
            make("Frame",{Name="RarityAccent",Position=UDim2.new(0,12,1,-8),Size=UDim2.new(1,-24,0,4),BackgroundColor3=rarityColor(item),BorderSizePixel=0},b)
            b.Activated:Connect(function()
                if S.multi and deletable(item) then S.selectedIds[item.id]=not S.selectedIds[item.id] or nil end
                S.selected=item.id; S.armed=nil; detail.CanvasPosition=Vector2.zero; renderList(); renderDetail()
            end)
        end
    end
    groupTitle.Text=base.categories[S.filter].name.."  ·  "..count.." items"
    layoutGrid()
    if count==0 then label(list,"Empty","No matching items.") end
end
renderDetail=function()
    stopSoundPreview()
    clear(detail)
    if S.collections and base then renderCollectionDetail();return end
    local item=base and base.byId[S.selected]; if not item then label(detail,"Empty","Select an item card to edit it."); return end
    local order=0
    local function add(object) order+=1; object.LayoutOrder=order; return object end
    local preview=add(make("Frame",{Name="ItemPreview",Size=UDim2.new(1,0,0,110),BackgroundColor3=C.ink,BorderSizePixel=0},detail))
    itemIcon(preview,item,8,7,96)
    local heading=label(preview,"Heading",name(item),66); heading.Position=UDim2.fromOffset(116,8); heading.Size=UDim2.new(1,-128,0,66); heading.TextColor3=C.white; heading.TextSize=26; heading.Font=Enum.Font.GothamBold; heading.TextTruncate=Enum.TextTruncate.AtEnd
    local previewRarity=label(preview,"Rarity",rarity(item)); previewRarity.Position=UDim2.fromOffset(116,76); previewRarity.Size=UDim2.new(1,-128,0,28); previewRarity.TextColor3=rarityColor(item)
    if item.category=="sounds" and not isDeleted(item.id) then
        local audible=item.setId~=nil or (item.sound~=nil and item.sound~="")
        local soundButton=add(button(detail,"SoundPreview",audible and "▶  Play sound preview" or "Silent / no sound"))
        soundButton.Active=audible; soundButton.AutoButtonColor=audible
        soundButton.TextColor3=audible and C.white or C.muted
        if audible then soundButton.Activated:Connect(function() playSoundPreview(item,soundButton) end) end
    end
    add(label(detail,"StableId",item.id.."  /  "..item.category..(item.default and "  /  DEFAULT" or ""),48))
    add(label(detail,"IdHelp","Stable IDs preserve player ownership when names change.",52))
    if isDeleted(item.id) then
        add(label(detail,"DeletedHelp","Deleted items are hidden from the catalog and all crate pools. Restore before changing details.",76))
        local restore=add(button(detail,"Restore","Restore item"))
        restore.Activated:Connect(function() push(); itemEdit(item.id).deleted=nil; renderList(); renderDetail() end)
        return
    end
    add(label(detail,"NameLabel","DISPLAY NAME"))
    local nameBox=add(field(detail,"DisplayName",name(item)))
    nameBox.FocusLost:Connect(function()
        local value=nameBox.Text:match("^%s*(.-)%s*$")
        if value=="" or #value>80 or value:find("%c") then nameBox.Text=name(item); status("Names need 1–80 characters, without control characters.",true); return end
        if value~=name(item) then push(); itemEdit(item.id).name=value; heading.Text=value; renderList() end
    end)
    local rarityButton=add(button(detail,"Rarity","Rarity: "..rarity(item).."   ›"))
    rarityButton.Activated:Connect(function()cycleRarity(item)end)
    local definitions=model.collectionDefinitions(base,edits);local collectionId=model.collectionFor(item,edits,definitions)
    local collection=add(button(detail,"ItemCollection","Collection: "..(collectionId and definitions[collectionId].name or "Unassigned").."   ›"))
    collection.TextTruncate=Enum.TextTruncate.AtEnd
    collection.Activated:Connect(function()S.collections=true;S.selectedCollection=collectionId or "__unassigned";S.collectionMode="members";search.Text="";renderList();renderDetail()end)
    if item.rewards then
        add(label(detail,"PoolHeading","CRATE CONTENTS / ITEM CHANCES",52)).TextColor3=C.purple
        add(label(detail,"PoolHelp",item.rarityChances and not edits.crates[item.id]
            and "Automatic rarity chances split equally among each rarity's items. Editing percentages switches to custom chances. Save, then start a new Play session."
            or "Include items and edit their %. Normalize scales chances to 100%. Save, then start a new Play session to use changes.",76))
        if item.rarityChances and edits.crates[item.id] then
            local reset=add(button(detail,"ResetRarityChances","Reset to rarity-based chances"))
            reset.Activated:Connect(function() push();edits.crates[item.id]=nil;renderDetail() end)
        end
        local rewards=rewardsFor(item); local lookup={}; local total=0; local tiers={}
        for _,r in rewards do lookup[r.id]=r; total+=r.weight; local tier=rarity(base.byId[r.id]); tiers[tier]=(tiers[tier] or 0)+r.weight end
        local totalLabel=add(label(detail,"Total",("%d included  /  Total %.6g%%"):format(#rewards,total),32))
        totalLabel.TextColor3=math.abs(total-100)<.0001 and C.purple or C.red
        local normalizeButton=add(button(detail,"Normalize","Normalize chances to 100%"))
        normalizeButton.Activated:Connect(function()
            if #rewards==0 then status("Include at least one item first.",true); return end
            updateCrate(item.id,normalize)
        end)
        add(label(detail,"TierHelp","Rarity % splits that chance among included items; 0 excludes that tier. Other tiers keep their chances. Total must reach 100%.",76))
        for _,tier in base.rarities do
            local row=add(make("Frame",{Name=tier.."Odds",Size=UDim2.new(1,0,0,40),BackgroundTransparency=1},detail))
            local text=label(row,"Tier",tier.." total"); text.Size=UDim2.new(1,-124,1,0)
            local box=field(row,"Percent",("%.8g"):format(tiers[tier] or 0)); box.Position=UDim2.new(1,-124,0,0); box.Size=UDim2.fromOffset(98,40)
            local suffix=label(row,"Unit","%"); suffix.Position=UDim2.new(1,-20,0,0); suffix.Size=UDim2.fromOffset(20,40)
            box.FocusLost:Connect(function()
                local value=tonumber(box.Text); local members={}
                for _,r in rewards do if rarity(base.byId[r.id])==tier then table.insert(members,r) end end
                if value==tonumber(("%.8g"):format(tiers[tier] or 0)) then return end
                if not value or value~=value or value<0 or value>100 or #members==0 then box.Text=("%.8g"):format(tiers[tier] or 0); status("Include items in this rarity first; enter a percentage from 0 to 100.",true); return end
                updateCrate(item.id,function(rows)
                    for i=#rows,1,-1 do local r=rows[i]; if rarity(base.byId[r.id])==tier then
                        if value==0 then table.remove(rows,i) else r.weight=value*r.weight/tiers[tier] end
                    end end
                end)
            end)
        end
        local poolSearch=add(field(detail,"RewardSearch",S.poolQuery or "")); poolSearch.PlaceholderText="Filter rewards by name, ID or rarity"
        local pool=add(make("Frame",{Name="RewardList",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},detail))
        make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},pool)
        local function drawPool()
            clear(pool); local index=0; local query=(S.poolQuery or ""):lower()
            local candidates=table.clone(base.items); local typeOrder={}; local previousType
            for i,kind in base.categories do typeOrder[kind.id]=i end
            table.sort(candidates,function(a,b)
                if a.category~=b.category then return typeOrder[a.category]<typeOrder[b.category] end
                return name(a)<name(b)
            end)
            for _,candidate in candidates do
                if candidate.category~="crates" and not candidate.default and not isDeleted(candidate.id)
                    and (name(candidate).." "..candidate.id.." "..rarity(candidate)):lower():find(query,1,true) then
                    index+=1
                    if candidate.category~=previousType then
                        local section=make("Frame",{Name="Group_"..candidate.category,Size=UDim2.new(1,0,0,52),BackgroundTransparency=1,LayoutOrder=index},pool)
                        itemIcon(section,candidate.category,0,8,36)
                        local heading=label(section,"Title",base.categories[typeOrder[candidate.category]].name); heading.Position=UDim2.fromOffset(48,0); heading.Size=UDim2.new(1,-48,1,0); heading.TextColor3=C.purple; heading.Font=Enum.Font.GothamBold
                        previousType=candidate.category; index+=1
                    end
                    local row=make("Frame",{Name=candidate.id,Size=UDim2.new(1,0,0,80),BackgroundColor3=C.ink,BorderSizePixel=0,LayoutOrder=index},pool)
                    local included=lookup[candidate.id]
                    local include=button(row,"Include",included and "✓" or "+",36); include.Position=UDim2.fromOffset(4,20)
                    itemIcon(row,candidate,46,12,56)
                    local caption=label(row,"Name",name(candidate)); caption.Position=UDim2.fromOffset(110,6); caption.Size=UDim2.new(1,-240,0,42); caption.TextColor3=C.white; caption.TextTruncate=Enum.TextTruncate.AtEnd
                    local sub=label(row,"Rarity",rarity(candidate)); sub.Position=UDim2.fromOffset(110,50); sub.Size=UDim2.new(1,-240,0,24); sub.TextSize=16; sub.TextColor3=rarityColor(candidate); sub.TextTruncate=Enum.TextTruncate.AtEnd
                    local percent=field(row,"Percent",included and ("%.8g"):format(included.weight) or "—"); percent.Position=UDim2.new(1,-124,0,20); percent.Size=UDim2.fromOffset(98,40); percent.TextEditable=included~=nil
                    local suffix=label(row,"Unit","%"); suffix.Position=UDim2.new(1,-20,0,20); suffix.Size=UDim2.fromOffset(20,40)
                    include.Activated:Connect(function() updateCrate(item.id,function(rows)
                        if included then for i,r in rows do if r.id==candidate.id then table.remove(rows,i); break end end
                        else table.insert(rows,{id=candidate.id,weight=1}) end
                    end) end)
                    percent.FocusLost:Connect(function()
                        local value=tonumber(percent.Text)
                        if not included or not value or value~=value or value<=0 or value>100 then percent.Text=included and ("%.8g"):format(included.weight) or "—"; status("Enter a percentage above 0 and at most 100, or exclude the item.",true); return end
                        if value==tonumber(("%.8g"):format(included.weight)) then return end
                        updateCrate(item.id,function(rows) for _,r in rows do if r.id==candidate.id then r.weight=value end end end)
                    end)
                end
            end
        end
        poolSearch:GetPropertyChangedSignal("Text"):Connect(function() S.poolQuery=poolSearch.Text; drawPool() end); drawPool()
    end
    if item.default or item.id=="crate_season1" then
        add(label(detail,"Protected","This item is required by the game and cannot be deleted.",56))
    else
        local remove=add(button(detail,"Delete","Delete item")); remove.TextColor3=C.red
        remove.Activated:Connect(function()
            if S.armed~=item.id or os.clock()-(S.armedAt or 0)>5 then S.armed=item.id; S.armedAt=os.clock(); status("Click Delete item again within five seconds. It will also leave all crate pools.",true); return end
            stageDelete({[item.id]=true})
        end)
    end
end
local function load()
    local nova=RS:FindFirstChild("NOVA"); if not nova then status("Missing ReplicatedStorage.NOVA.",true); return end
    local copy=nova:Clone()
    local ok,result=pcall(function()
        local catalog=require(copy.InventoryCatalog)
        return {catalog.editorBase,require(copy.InventoryEditorModel),catalog.editorEdits,require(copy.InventoryArt),require(copy.BatchOneAssets),catalog.rarityColors,require(copy.SkinVisuals),require(copy.PrismVisuals)}
    end)
    copy:Destroy()
    if not ok then status("Cannot load inventory: "..tostring(result),true); return end
    base,model,edits=result[1],result[2],result[3]; edits=model.copy(edits);edits.collections=edits.collections or {}
    art,assets,rarityColors=result[4],result[5],result[6]
    skinVisuals=result[7]
    prismVisuals=result[8]
    module=nova.InventoryEdits; loadedSource=Editor:GetEditorSource(module)
    S.dirty=false; S.undo={}; S.redo={}; S.armed=nil; S.selectedIds={}
    if not S.selected then
        for _,item in base.items do if item.category==base.categories[S.filter].id and not isDeleted(item.id) then S.selected=item.id; break end end
    end
    widget.Title="NOVA Item Editor"; renderList(); renderDetail(); status("Loaded catalog. Changes are staged until Save to place.")
end
local function validate()
    if not model then status("Load a NOVA place first.",true); return false end
    local ok,message=model.validate(edits,base); if not ok then status(message,true); return false end
    status("Valid: collection membership and crate percentages are consistent."); return true
end
local function serialize(value,indent)
    if type(value)=="string" then return string.format("%q",value) end
    if type(value)~="table" then return tostring(value) end
    indent=indent or ""; local lines={"{"}; local keys={}
    for key in value do table.insert(keys,key) end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end; return type(a)<type(b) end)
    for _,key in keys do table.insert(lines,indent.."    ["..serialize(key).."] = "..serialize(value[key],indent.."    ")..",") end
    table.insert(lines,indent.."}"); return table.concat(lines,"\n")
end
save.Activated:Connect(function()
    if not validate() then return end
    if Editor:GetEditorSource(module)~=loadedSource then status("InventoryEdits changed outside this editor. Reload before saving.",true); return end
    local source="-- Data saved by the NOVA Item Editor. Stable item IDs remain unchanged.\nreturn "..serialize(edits).."\n"
    local recording=History:TryBeginRecording("NOVA save inventory")
    local ok,err=pcall(function() Editor:UpdateSourceAsync(module,function(current)
        assert(current==loadedSource,"InventoryEdits changed while saving; reload first."); return source
    end) end)
    if recording then History:FinishRecording(recording,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
    if not ok then status("Save failed: "..tostring(err),true); return end
    loadedSource=source; S.dirty=false; widget.Title="NOVA Item Editor"
    status("Saved to place. Start a new Play session to use changes. Export to repo keeps future builds in sync.")
end)
export.Activated:Connect(function()
    if not model or S.dirty then status("Save to place before exporting.",true); return end
    if Editor:GetEditorSource(module)~=loadedSource then status("InventoryEdits changed outside this editor. Reload before exporting.",true); return end
    local ok,result=pcall(function() return Http:RequestAsync({Url="http://127.0.0.1:34873/inventory",Method="POST",Headers={["Content-Type"]="application/json"},Body=Http:JSONEncode(edits)}) end)
    if not ok then status("Repo bridge unavailable. Run: python tools/item_bridge.py",true); return end
    local decoded,body=pcall(Http.JSONDecode,Http,result.Body)
    if result.Success and decoded and body.ok then status("Exported to src/shared/InventoryEdits.luau.")
    else status("Export failed: "..tostring(decoded and body.error or result.StatusMessage),true) end
end)
reload.Activated:Connect(function()
    if S.dirty and (S.armed~="reload" or os.clock()-(S.armedAt or 0)>5) then S.armed="reload"; S.armedAt=os.clock(); status("Click Reload again within five seconds to discard unsaved changes.",true); return end
    load()
end)
check.Activated:Connect(validate)
undo.Activated:Connect(function() if not model then return end; local previous=table.remove(S.undo); if previous then table.insert(S.redo,model.copy(edits)); edits=previous; dirty(); renderList(); renderDetail() end end)
redo.Activated:Connect(function() if not model then return end; local nextEdit=table.remove(S.redo); if nextEdit then table.insert(S.undo,model.copy(edits)); edits=nextEdit; dirty(); renderList(); renderDetail() end end)
search:GetPropertyChangedSignal("Text"):Connect(renderList)
deleted.Activated:Connect(function() S.showDeleted=not S.showDeleted; deleted.Text="Show deleted: "..(S.showDeleted and "on" or "off"); renderList();if S.collections then renderDetail() end end)
rarityFilter.Activated:Connect(function()
    if not base then return end
    S.rarity=(S.rarity+1)%8; S.armed=nil; list.CanvasPosition=Vector2.zero
    rarityFilter.Text="Rarity: "..(S.rarity==0 and "All" or S.rarity==7 and "Chest" or base.rarities[S.rarity]).."   ›"
    renderList()
end)
multiSelect.Activated:Connect(function()
    S.multi=not S.multi; S.armed=nil
    if not S.multi then S.selectedIds={} end
    multiSelect.Text="Multi-select: "..(S.multi and "on" or "off"); renderList()
end)
selectVisible.Activated:Connect(function()
    if not base then return end
    for _,item in base.items do if matches(item) and deletable(item) then S.selectedIds[item.id]=true end end
    S.armed=nil; renderList()
end)
clearSelection.Activated:Connect(function() S.selectedIds={}; S.armed=nil; renderList() end)
deleteSelected.Activated:Connect(function()
    if not model then return end
    local count=0; for _ in S.selectedIds do count+=1 end
    if count==0 then status("Select at least one deletable item.",true); return end
    if S.armed~="bulk" or os.clock()-(S.armedAt or 0)>5 then
        S.armed="bulk"; S.armedAt=os.clock()
        status(("Click Delete selected again within five seconds to delete all %d selected items, including hidden selections."):format(count),true); return
    end
    stageDelete(S.selectedIds)
end)
toggle.Click:Connect(function() widget.Enabled=not widget.Enabled end)
newCollection.Activated:Connect(function()S.selectedCollection=nil;S.collectionMode="members";S.armed=nil;detail.CanvasPosition=Vector2.zero;renderDetail()end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    toggle:SetActive(widget.Enabled)
    if not widget.Enabled then stopSoundPreview() elseif not base then load() end
end)
widget.Destroying:Connect(stopSoundPreview)
plugin.Unloading:Connect(function() stopSoundPreview(); widget:Destroy() end)
if widget.Enabled then load() end
