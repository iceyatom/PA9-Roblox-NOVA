-- NOVA Level Editor: paint tile maps for NOVA duels and save them to ReplicatedStorage.NOVA.Maps.
-- Install by copying this file into Studio's local Plugins folder (see README).
local RunService=game:GetService("RunService")
if not RunService:IsEdit() then return end
local ChangeHistory=game:GetService("ChangeHistoryService")
local ScriptEditor=game:GetService("ScriptEditorService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
-- tools/map_bridge.py listens here and writes exported maps into src/shared/maps.
local BRIDGE="http://127.0.0.1:34872"

local rgb=Color3.fromHex
local C={ink=rgb("080b13"),panel=rgb("111621"),raised=rgb("1a2030"),line=rgb("303747"),muted=rgb("9ca8bc"),
    white=rgb("edf2ff"),lime=rgb("b9f770"),blue=rgb("527eff"),red=rgb("ff5859"),field=rgb("080911")}
local TILES={
    {id=".",name="Empty",info="Open space",color=C.field},
    {id="P",name="Solid wall",info="Blocks players and shots",color=rgb("793dff")},
    {id="D",name="Phase wall",info="Blocks players only",color=rgb("3228c7")},
    {id="L",name="Shot shield",info="Blocks shots only",color=rgb("248bff")},
    {id="G",name="Launch pad",info="Boosts upward",color=rgb("50e4ac")},
    {id="Y",name="Beacon",info="Decoration only",color=rgb("e7d342")},
    {id="M",name="Marker",info="Decoration only",color=rgb("398756")},
}
local tileColor={}
for _,t in TILES do tileColor[t.id]=t.color end
local MIN_W,MAX_W,MIN_H,MAX_H=8,80,6,60

-- Editor state. grid[row][col] holds one tile character; both indices start at 1.
local S={id=nil,name="New Map",code="02",width=38,height=29,mirrored=true,grid={},
    spawns={Vector2.new(6.5,27.5),Vector2.new(31.5,27.5)},tool="P",dirty=false,undo={},redo={},discardArmed=nil}

local function folders()
    local nova=RS:FindFirstChild("NOVA")
    return nova,nova and nova:FindFirstChild("Maps")
end
local function rowStrings(grid)
    local rows={}
    for r,row in grid do rows[r]=table.concat(row) end
    return rows
end
local function gridFrom(rows)
    local grid={}
    for r,row in rows do
        grid[r]={}
        for c=1,#row do grid[r][c]=row:sub(c,c) end
    end
    return grid
end
local function snapshot()
    return {rows=rowStrings(S.grid),spawns={S.spawns[1],S.spawns[2]},width=S.width,height=S.height,mirrored=S.mirrored}
end
local function restore(snap)
    S.grid=gridFrom(snap.rows)
    S.spawns={snap.spawns[1],snap.spawns[2]}
    S.width,S.height,S.mirrored=snap.width,snap.height,snap.mirrored
end
local function blankRows(w,h)
    -- Side walls and a floor give a new map something to stand on.
    local rows={}
    for r=1,h do
        rows[r]=r==h and string.rep("P",w) or "P"..string.rep(".",w-2).."P"
    end
    return rows
end
local function idFromName(name)
    local id=name:gsub("[^%w%s]",""):gsub("(%w)(%w*)",function(a,b) return a:upper()..b end):gsub("%s","")
    if id=="" or id:match("^%d") then id="Map"..id end
    return id
end

-- UI helpers.
local function make(class,props,parent)
    local o=Instance.new(class)
    for k,v in props do o[k]=v end
    o.Parent=parent
    return o
end
local function stroke(parent,color)
    return make("UIStroke",{Color=color or C.line,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent)
end
local function label(parent,name,pos,size,value,ts,color,font)
    return make("TextLabel",{Name=name,Position=pos,Size=size,BackgroundTransparency=1,Text=value,TextSize=ts,
        TextColor3=color or C.white,Font=font or Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd},parent)
end
local function button(parent,name,pos,size,value,primary)
    local b=make("TextButton",{Name=name,Position=pos,Size=size,BorderSizePixel=0,AutoButtonColor=true,
        BackgroundColor3=primary and C.lime or C.raised,TextColor3=primary and C.ink or C.white,
        Font=Enum.Font.GothamBold,TextSize=13,Text=value},parent)
    make("UICorner",{CornerRadius=UDim.new(0,4)},b)
    if not primary then stroke(b) end
    return b
end
local function field(parent,name,pos,size,value)
    local t=make("TextBox",{Name=name,Position=pos,Size=size,BorderSizePixel=0,BackgroundColor3=C.ink,
        TextColor3=C.white,PlaceholderColor3=C.muted,Font=Enum.Font.Code,TextSize=14,Text=value,
        ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left},parent)
    make("UIPadding",{PaddingLeft=UDim.new(0,6)},t)
    make("UICorner",{CornerRadius=UDim.new(0,4)},t)
    stroke(t)
    return t
end

local toolbar=plugin:CreateToolbar("NOVA")
local toggle=toolbar:CreateButton("NOVALevelEditor","Level Editor","Paint, check and save NOVA duel maps","")
toggle.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGui("NOVALevelEditor",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,1080,760,720,520))
widget.Title="NOVA Level Editor"
widget.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local root=make("Frame",{Name="Root",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BorderSizePixel=0},widget)

-- Sidebar: maps, tiles and spawn tools.
local side=make("ScrollingFrame",{Name="Sidebar",Size=UDim2.new(0,236,1,0),BackgroundColor3=C.panel,BorderSizePixel=0,
    ScrollBarThickness=4,ScrollBarImageColor3=C.line,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},root)
make("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,14)},side)
make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},side)
local order=0
local function nextOrder() order+=1; return order end
local function heading(value,color)
    local l=label(side,"Heading",UDim2.new(),UDim2.new(1,0,0,22),value,12,color or C.muted,Enum.Font.Code)
    l.LayoutOrder=nextOrder()
    return l
end
heading("NOVA   /   LEVEL EDITOR",C.lime).TextSize=13
heading("MAPS")
local mapList=make("Frame",{Name="MapList",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=nextOrder()},side)
make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},mapList)
local newButton=button(side,"NewMap",UDim2.new(),UDim2.new(1,0,0,30),"+  New map")
newButton.LayoutOrder=nextOrder()
heading("TILES")
local toolButtons={}
local function toolRow(id,name,info,color)
    local b=make("TextButton",{Name=name,Size=UDim2.new(1,0,0,40),BackgroundColor3=C.ink,BorderSizePixel=0,
        AutoButtonColor=true,Text="",LayoutOrder=nextOrder()},side)
    make("UICorner",{CornerRadius=UDim.new(0,4)},b)
    local outline=stroke(b)
    local sw=make("Frame",{Name="Swatch",Position=UDim2.fromOffset(10,11),Size=UDim2.fromOffset(18,18),BackgroundColor3=color,BorderSizePixel=0},b)
    if id=="." then stroke(sw) end
    label(b,"Name",UDim2.fromOffset(38,4),UDim2.new(1,-44,0,18),name,13,C.white,Enum.Font.GothamBold)
    label(b,"Info",UDim2.fromOffset(38,21),UDim2.new(1,-44,0,15),info,11,C.muted)
    toolButtons[id]={button=b,outline=outline}
    return b
end
for _,t in TILES do toolRow(t.id,t.name,t.info,t.color) end
heading("SPAWNS")
toolRow("spawn1","Spawn 1","Blue player start",C.blue)
toolRow("spawn2","Spawn 2","Red player start",C.red)
local help=label(side,"Help",UDim2.new(),UDim2.new(1,0,0,64),
    "Left-drag paints the selected tile.\nRight-drag erases.\nMirror paints both halves.",12,C.muted)
help.TextWrapped=true
help.TextYAlignment=Enum.TextYAlignment.Top
help.LayoutOrder=nextOrder()

-- Main area: settings, actions, canvas and status.
local main=make("Frame",{Name="Main",Position=UDim2.fromOffset(236,0),Size=UDim2.new(1,-236,1,0),BackgroundTransparency=1},root)
label(main,"NameLabel",UDim2.fromOffset(16,12),UDim2.fromOffset(44,28),"Name",12,C.muted,Enum.Font.Code)
local nameBox=field(main,"Name",UDim2.fromOffset(58,12),UDim2.fromOffset(190,28),S.name)
label(main,"CodeLabel",UDim2.fromOffset(260,12),UDim2.fromOffset(40,28),"Code",12,C.muted,Enum.Font.Code)
local codeBox=field(main,"Code",UDim2.fromOffset(298,12),UDim2.fromOffset(48,28),S.code)
label(main,"SizeLabel",UDim2.fromOffset(360,12),UDim2.fromOffset(36,28),"Size",12,C.muted,Enum.Font.Code)
local widthBox=field(main,"Width",UDim2.fromOffset(396,12),UDim2.fromOffset(44,28),tostring(S.width))
label(main,"By",UDim2.fromOffset(446,12),UDim2.fromOffset(12,28),"×",13,C.muted)
local heightBox=field(main,"Height",UDim2.fromOffset(460,12),UDim2.fromOffset(44,28),tostring(S.height))
local resizeButton=button(main,"Resize",UDim2.fromOffset(512,12),UDim2.fromOffset(70,28),"Resize")
local mirrorButton=button(main,"Mirror",UDim2.fromOffset(592,12),UDim2.fromOffset(110,28),"")
local undoButton=button(main,"Undo",UDim2.fromOffset(16,50),UDim2.fromOffset(64,28),"Undo")
local redoButton=button(main,"Redo",UDim2.fromOffset(86,50),UDim2.fromOffset(64,28),"Redo")
local clearButton=button(main,"Clear",UDim2.fromOffset(156,50),UDim2.fromOffset(64,28),"Clear")
local checkButton=button(main,"Check",UDim2.fromOffset(240,50),UDim2.fromOffset(90,28),"Check map")
local saveButton=button(main,"Save",UDim2.fromOffset(336,50),UDim2.fromOffset(90,28),"Save",true)
local activeButton=button(main,"SetActive",UDim2.fromOffset(432,50),UDim2.fromOffset(130,28),"Set active map")
local exportButton=button(main,"Export",UDim2.fromOffset(568,50),UDim2.fromOffset(130,28),"Export to repo")
local deleteButton=button(main,"Delete",UDim2.fromOffset(704,50),UDim2.fromOffset(110,28),"Delete map")
deleteButton.TextColor3=C.red
local holder=make("Frame",{Name="CanvasHolder",Position=UDim2.fromOffset(16,92),Size=UDim2.new(1,-32,1,-130),BackgroundTransparency=1},main)
local canvas=make("Frame",{Name="Canvas",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
    BackgroundColor3=C.line,BorderSizePixel=0,Active=true},holder)
local axis=make("Frame",{Name="MirrorAxis",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(0.5,0),
    Size=UDim2.new(0,2,1,0),BackgroundColor3=C.lime,BackgroundTransparency=0.4,BorderSizePixel=0,ZIndex=4},canvas)
local markers={}
for i=1,2 do
    markers[i]=make("TextLabel",{Name="Spawn"..i,AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=i==1 and C.blue or C.red,
        BorderSizePixel=0,Text=tostring(i),TextColor3=C.white,Font=Enum.Font.GothamBlack,TextScaled=true,ZIndex=5},canvas)
    make("UICorner",{CornerRadius=UDim.new(1,0)},markers[i])
    stroke(markers[i],C.white)
end
local hoverLabel=label(main,"Hover",UDim2.new(0,16,1,-32),UDim2.new(0,190,0,24),"",12,C.muted,Enum.Font.Code)
local statusLabel=label(main,"Status",UDim2.new(0,210,1,-32),UDim2.new(1,-226,0,24),"",13,C.muted,Enum.Font.GothamBold)

local function status(text,color)
    statusLabel.Text=text
    statusLabel.TextColor3=color or C.muted
end

-- Canvas drawing.
local cells,cellSize,builtW,builtH={},0,0,0
local function colorCell(r,c)
    local cell=cells[r] and cells[r][c]
    if cell then cell.BackgroundColor3=tileColor[S.grid[r][c]] or C.white end
end
local function placeMarkers()
    for i,m in markers do
        local p=S.spawns[i]
        m.Visible=p~=nil
        if p then
            m.Position=UDim2.fromOffset(p.X*cellSize,p.Y*cellSize)
            m.Size=UDim2.fromOffset(math.max(10,cellSize*0.9),math.max(10,cellSize*0.9))
        end
    end
    axis.Visible=S.mirrored
end
local function layout()
    local area=holder.AbsoluteSize
    local size=math.max(4,math.floor(math.min(area.X/S.width,area.Y/S.height)))
    canvas.Size=UDim2.fromOffset(size*S.width,size*S.height)
    if size~=cellSize or builtW~=S.width or builtH~=S.height then
        cellSize,builtW,builtH=size,S.width,S.height
        for _,row in cells do for _,cell in row do cell:Destroy() end end
        cells={}
        for r=1,S.height do
            cells[r]={}
            for c=1,S.width do
                cells[r][c]=make("Frame",{Name="Cell",BorderSizePixel=0,Position=UDim2.fromOffset((c-1)*size,(r-1)*size),
                    Size=UDim2.fromOffset(size-1,size-1)},canvas)
            end
        end
    end
    for r=1,S.height do for c=1,S.width do colorCell(r,c) end end
    placeMarkers()
end
holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

local function refreshFields()
    nameBox.Text,codeBox.Text=S.name,S.code
    widthBox.Text,heightBox.Text=tostring(S.width),tostring(S.height)
    mirrorButton.Text=S.mirrored and "Mirror: on" or "Mirror: off"
    mirrorButton.TextColor3=S.mirrored and C.lime or C.muted
    for id,t in toolButtons do
        t.outline.Color=id==S.tool and C.lime or C.line
        t.outline.Thickness=id==S.tool and 2 or 1
    end
end
local refreshMaps
local function markDirty()
    S.dirty=true
    S.discardArmed=nil
end
local function pushUndo()
    table.insert(S.undo,snapshot())
    if #S.undo>60 then table.remove(S.undo,1) end
    table.clear(S.redo)
end

-- Painting.
local function mirrorCol(c) return S.width+1-c end
local function setTile(r,c,id)
    if S.grid[r][c]~=id then
        S.grid[r][c]=id
        colorCell(r,c)
        markDirty()
    end
end
local function placeSpawn(i,r,c)
    local p=Vector2.new(c-0.5,r-0.5)
    S.spawns[i]=p
    if S.mirrored then S.spawns[3-i]=Vector2.new(S.width-p.X,p.Y) end
    markDirty()
    placeMarkers()
end
local function applyAt(r,c,erase)
    if r<1 or r>S.height or c<1 or c>S.width then return end
    local tool=erase and "." or S.tool
    if tool=="spawn1" or tool=="spawn2" then
        placeSpawn(tool=="spawn1" and 1 or 2,r,c)
        return
    end
    setTile(r,c,tool)
    if S.mirrored then setTile(r,mirrorCol(c),tool) end
end
local function cellUnderMouse()
    local m=widget:GetRelativeMousePosition()-canvas.AbsolutePosition
    if cellSize<=0 then return end
    return math.floor(m.Y/cellSize)+1,math.floor(m.X/cellSize)+1
end
local stroke_
canvas.InputBegan:Connect(function(input)
    local t=input.UserInputType
    if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.MouseButton2 then
        pushUndo()
        stroke_={erase=t==Enum.UserInputType.MouseButton2}
        local r,c=cellUnderMouse()
        if r then applyAt(r,c,stroke_.erase) end
    end
end)
canvas.InputChanged:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local r,c=cellUnderMouse()
    if r and r>=1 and r<=S.height and c>=1 and c<=S.width then
        local id=S.grid[r][c]
        local name=id
        for _,t in TILES do if t.id==id then name=t.name end end
        hoverLabel.Text=("x %d  y %d  /  %s"):format(c-1,r-1,name)
        if stroke_ then applyAt(r,c,stroke_.erase) end
    end
end)
canvas.InputEnded:Connect(function(input)
    local t=input.UserInputType
    if t==Enum.UserInputType.MouseButton1 or t==Enum.UserInputType.MouseButton2 then stroke_=nil end
end)
canvas.MouseLeave:Connect(function() stroke_=nil; hoverLabel.Text="" end)

for id,t in toolButtons do
    t.button.Activated:Connect(function()
        S.tool=id
        refreshFields()
    end)
end

-- Map files.
local function loadSnapshot(source,id)
    S.id=id
    S.name=source.Name or id or "New Map"
    S.code=source.Code or "--"
    S.mirrored=source.Mirrored==true
    S.width,S.height=#source.Rows[1],#source.Rows
    S.grid=gridFrom(source.Rows)
    S.spawns={source.Spawns[1],source.Spawns[2]}
    S.dirty,S.undo,S.redo,S.discardArmed=false,{},{},nil
    refreshFields()
    layout()
end
local function guardUnsaved(key)
    if S.dirty and S.discardArmed~=key then
        S.discardArmed=key
        status("Unsaved changes. Click again to discard them.",C.red)
        return false
    end
    return true
end
local function openMap(module)
    if not guardUnsaved(module) then return end
    -- Require a copy so edits saved earlier in this session are read fresh.
    local copy=module:Clone()
    local ok,source=pcall(require,copy)
    copy:Destroy()
    if not ok or type(source)~="table" or type(source.Rows)~="table" or type(source.Spawns)~="table" then
        status("Could not read "..module.Name..": "..tostring(source),C.red)
        return
    end
    loadSnapshot(source,module.Name)
    status("Opened "..S.name,C.muted)
    refreshMaps()
end
local function newMap()
    if not guardUnsaved("new") then return end
    local w,h=38,29
    loadSnapshot({Name="New Map",Code="--",Mirrored=true,Rows=blankRows(w,h),
        Spawns={Vector2.new(3.5,h-1.5),Vector2.new(w-3.5,h-1.5)}},nil)
    S.dirty=true
    status("New map. Paint it, then Save.",C.muted)
    refreshMaps()
end
refreshMaps=function()
    for _,b in mapList:GetChildren() do if b:IsA("GuiObject") then b:Destroy() end end
    local nova,maps=folders()
    if not maps then
        label(mapList,"Missing",UDim2.new(),UDim2.new(1,0,0,36),"No ReplicatedStorage.NOVA.Maps folder.",12,C.red).TextWrapped=true
        return
    end
    local active=nova:GetAttribute("ActiveMap") or "SplitCircuit"
    local list=maps:GetChildren()
    table.sort(list,function(a,b) return a.Name<b.Name end)
    for i,module in list do
        if module:IsA("ModuleScript") then
            local b=button(mapList,module.Name,UDim2.new(),UDim2.new(1,0,0,30),"")
            b.LayoutOrder=i
            b.TextXAlignment=Enum.TextXAlignment.Left
            b.Text="   "..module.Name..(module.Name==active and "   ·  ACTIVE" or "")
            b.TextColor3=module.Name==S.id and C.lime or C.white
            b.Activated:Connect(function() openMap(module) end)
        end
    end
end

local compiler
local function check()
    if not compiler then
        local nova=folders()
        local ok,m=pcall(function() return require(nova.Map1) end)
        if not ok then status("Cannot load NOVA Map1 compiler: "..tostring(m),C.red); return false end
        compiler=m
    end
    if not (S.spawns[1] and S.spawns[2]) then status("Place both spawns.",C.red); return false end
    local ok,err=pcall(compiler.compile,rowStrings(S.grid),S.spawns,S.mirrored)
    if not ok then
        status(tostring(err):gsub("^.-:%d+: ",""),C.red)
        return false
    end
    status(("Map is valid  /  %d × %d"):format(S.width,S.height),C.lime)
    return true
end
local function num(v) return (("%.2f"):format(v):gsub("%.?0+$","")) end
local function source()
    local lines={"-- Map data written by the NOVA Level Editor plugin. One character per tile; see TileCatalog.",
        "-- Spawns are tile-unit centers, counted from the upper-left corner.","return {",
        ("    Name = %q,"):format(S.name),("    Code = %q,"):format(S.code),("    Mirrored = %s,"):format(tostring(S.mirrored)),
        ("    Spawns = {Vector2.new(%s,%s), Vector2.new(%s,%s)},"):format(num(S.spawns[1].X),num(S.spawns[1].Y),num(S.spawns[2].X),num(S.spawns[2].Y)),
        "    Rows = {"}
    for _,row in rowStrings(S.grid) do table.insert(lines,('    "%s",'):format(row)) end
    table.insert(lines,"    },")
    table.insert(lines,"}")
    return table.concat(lines,"\n").."\n"
end
local function save()
    if not check() then return end
    local nova,maps=folders()
    if not maps then status("Missing ReplicatedStorage.NOVA.Maps",C.red); return end
    local id=S.id
    if not id then
        local base=idFromName(S.name)
        id=base
        local n=2
        while maps:FindFirstChild(id) do id=base..n; n+=1 end
    end
    local module=maps:FindFirstChild(id)
    if module and not module:IsA("ModuleScript") then status(id.." is not a ModuleScript",C.red); return end
    local recording=ChangeHistory:TryBeginRecording("NOVA save map "..id)
    if not module then
        module=Instance.new("ModuleScript")
        module.Name=id
        module:SetAttribute("NOVAOwned",true)
        module.Parent=maps
    end
    local text=source()
    local ok,err=pcall(function() ScriptEditor:UpdateSourceAsync(module,function() return text end) end)
    if recording then ChangeHistory:FinishRecording(recording,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end
    if not ok then status("Save failed: "..tostring(err),C.red); return end
    S.id,S.dirty,S.discardArmed=id,false,nil
    status(("Saved %s to ReplicatedStorage.NOVA.Maps.%s"):format(S.name,id),C.lime)
    refreshMaps()
end

nameBox.FocusLost:Connect(function()
    local v=nameBox.Text:gsub("^%s+",""):gsub("%s+$","")
    if v~="" and v~=S.name then S.name=v; markDirty() end
    nameBox.Text=S.name
end)
codeBox.FocusLost:Connect(function()
    local v=codeBox.Text:gsub("%s",""):sub(1,4)
    if v~="" and v~=S.code then S.code=v; markDirty() end
    codeBox.Text=S.code
end)
resizeButton.Activated:Connect(function()
    local w=tonumber(widthBox.Text)
    local h=tonumber(heightBox.Text)
    if not (w and h) then status("Size must be two numbers.",C.red); return end
    w=math.clamp(math.floor(w),MIN_W,MAX_W)
    h=math.clamp(math.floor(h),MIN_H,MAX_H)
    if w==S.width and h==S.height then refreshFields(); return end
    pushUndo()
    -- Keep the bottom rows anchored so the floor stays under the spawns.
    local grid={}
    for r=1,h do
        grid[r]={}
        local from=S.height-(h-r)
        for c=1,w do grid[r][c]=S.grid[from] and S.grid[from][c] or "." end
    end
    for i,p in S.spawns do
        S.spawns[i]=Vector2.new(math.clamp(p.X,0.5,w-0.5),math.clamp(p.Y+(h-S.height),0.5,h-0.5))
    end
    S.grid,S.width,S.height=grid,w,h
    if S.mirrored then
        for r=1,h do for c=1,math.floor(w/2) do grid[r][w+1-c]=grid[r][c] end end
        S.spawns[2]=Vector2.new(w-S.spawns[1].X,S.spawns[1].Y)
    end
    markDirty()
    refreshFields()
    layout()
    status(("Resized to %d × %d"):format(w,h),C.muted)
end)
mirrorButton.Activated:Connect(function()
    pushUndo()
    S.mirrored=not S.mirrored
    if S.mirrored then
        -- Copy the left half onto the right so the map starts symmetric.
        for r=1,S.height do
            for c=1,math.floor(S.width/2) do S.grid[r][mirrorCol(c)]=S.grid[r][c] end
        end
        if S.spawns[1] then S.spawns[2]=Vector2.new(S.width-S.spawns[1].X,S.spawns[1].Y) end
        status("Mirror on: the left half was copied to the right.",C.muted)
    else
        status("Mirror off: each half can differ.",C.muted)
    end
    markDirty()
    refreshFields()
    layout()
end)
undoButton.Activated:Connect(function()
    local snap=table.remove(S.undo)
    if not snap then status("Nothing to undo.",C.muted); return end
    table.insert(S.redo,snapshot())
    restore(snap)
    markDirty()
    refreshFields()
    layout()
end)
redoButton.Activated:Connect(function()
    local snap=table.remove(S.redo)
    if not snap then status("Nothing to redo.",C.muted); return end
    table.insert(S.undo,snapshot())
    restore(snap)
    markDirty()
    refreshFields()
    layout()
end)
clearButton.Activated:Connect(function()
    pushUndo()
    for r=1,S.height do for c=1,S.width do S.grid[r][c]="." end end
    markDirty()
    layout()
    status("Cleared. Undo restores it.",C.muted)
end)
checkButton.Activated:Connect(check)
saveButton.Activated:Connect(save)
activeButton.Activated:Connect(function()
    if S.dirty or not S.id then status("Save the map before making it active.",C.red); return end
    if not check() then return end
    local nova=folders()
    local recording=ChangeHistory:TryBeginRecording("NOVA set active map")
    nova:SetAttribute("ActiveMap",S.id)
    if recording then ChangeHistory:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end
    status(S.name.." is now the active map. Press Play to try it.",C.lime)
    refreshMaps()
end)
newButton.Activated:Connect(newMap)
local function bridge(path,payload)
    local ok,result=pcall(function()
        return Http:RequestAsync({Url=BRIDGE..path,Method="POST",Headers={["Content-Type"]="application/json"},
            Body=Http:JSONEncode(payload)})
    end)
    if not ok then return false,"Repo bridge not reachable. Run: python tools/map_bridge.py" end
    local decoded,body=pcall(Http.JSONDecode,Http,result.Body)
    if result.Success and decoded and type(body)=="table" and body.ok then return true,body end
    return false,tostring(decoded and type(body)=="table" and body.error or result.StatusMessage)
end
-- Two clicks within five seconds delete the open map from Studio and from src/shared/maps.
local deleteArmed
deleteButton.Activated:Connect(function()
    local _,maps=folders()
    local module=S.id and maps and maps:FindFirstChild(S.id)
    if not module then status("Open a saved map to delete it.",C.red); return end
    if S.id=="SplitCircuit" then status("Split Circuit is the default map and cannot be deleted.",C.red); return end
    if not deleteArmed or deleteArmed.id~=S.id or os.clock()-deleteArmed.at>5 then
        deleteArmed={id=S.id,at=os.clock()}
        status(("Click Delete again to remove %s from Studio and the repo."):format(S.name),C.red)
        return
    end
    deleteArmed=nil
    -- Remove the repo copy first so a missing bridge never leaves the two out of step.
    status("Deleting...",C.muted)
    local ok,result=bridge("/maps/delete",{id=S.id})
    if not ok then status("Delete failed: "..result,C.red); return end
    local nova=folders()
    local recording=ChangeHistory:TryBeginRecording("NOVA delete map "..S.id)
    if nova:GetAttribute("ActiveMap")==S.id then nova:SetAttribute("ActiveMap",nil) end
    module:Destroy()
    if recording then ChangeHistory:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end
    local name=S.name
    S.dirty=false
    openMap(maps.SplitCircuit)
    status(("Deleted %s%s"):format(name,result.path and " and "..result.path or " (it was never exported)"),C.lime)
end)
exportButton.Activated:Connect(function()
    if S.dirty or not S.id then status("Save the map before exporting it.",C.red); return end
    local _,maps=folders()
    local module=maps and maps:FindFirstChild(S.id)
    if not module then status("Saved map module not found.",C.red); return end
    status("Exporting...",C.muted)
    local ok,result=bridge("/maps",{id=S.id,source=module.Source})
    if ok then status("Exported to "..result.path,C.lime) else status("Export failed: "..result,C.red) end
end)

toggle.Click:Connect(function() widget.Enabled=not widget.Enabled end)
local opened=false
local function onEnabled()
    toggle:SetActive(widget.Enabled)
    if not widget.Enabled then return end
    refreshMaps()
    if not opened then
        opened=true
        local nova,maps=folders()
        local start=maps and maps:FindFirstChild(nova:GetAttribute("ActiveMap") or "SplitCircuit")
        if start then openMap(start) else newMap() end
    end
end
widget:GetPropertyChangedSignal("Enabled"):Connect(onEnabled)
S.grid=gridFrom(blankRows(S.width,S.height))
refreshFields()
onEnabled()
print("[NOVA Level Editor] ready. Open it from the Plugins tab.")
