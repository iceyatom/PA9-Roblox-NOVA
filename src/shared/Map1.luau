local Catalog = require(script.Parent.TileCatalog)
local Map = {}

-- Map data lives in the Maps folder. Split Circuit stays the default and the test reference.
local Maps = script.Parent:WaitForChild("Maps")
local DEFAULT = "SplitCircuit"
local data = require(Maps:WaitForChild(DEFAULT))
Map.rows = data.Rows
Map.spawns = data.Spawns

function Map.compile(rows, spawns, mirrored)
    assert(type(rows) == "table" and #rows > 0 and type(rows[1]) == "string" and #rows[1] > 0, "Empty map")
    local map = {width=#rows[1], height=#rows, rows=rows, spawns=spawns, rects={}, body={}, shot={}, pads={}}
    local above = {}
    for index,row in ipairs(rows) do
        assert(type(row) == "string" and #row == map.width, "Invalid width in row "..index)
        assert(not mirrored or row == row:reverse(), "Asymmetric row "..index)
        local nextAbove = {}
        local x = 0
        while x < map.width do
            local id = row:sub(x+1,x+1)
            local style = assert(Catalog[id], "Unknown tile "..id)
            local right = x + 1
            while right < map.width and row:sub(right+1,right+1) == id do right += 1 end
            if id ~= "." then
                local rect = above[x]
                if rect and rect.id == id and rect.x2 == right and not style.top then
                    rect.y2 = index
                else
                    rect = {id=id, x=x, y=index-1+(style.top or 0), x2=right, y2=index}
                    table.insert(map.rects,rect)
                    if style.body then table.insert(map.body,rect) end
                    if style.shot then table.insert(map.shot,rect) end
                    if style.launch then table.insert(map.pads,rect) end
                end
                nextAbove[x] = rect
            end
            x = right
        end
        above = nextAbove
    end
    assert(type(spawns) == "table" and #spawns == 2, "Two spawns required")
    for _,p in spawns do
        assert(typeof(p) == "Vector2" and p.X >= 0.5 and p.X <= map.width-0.5 and p.Y >= 0.5 and p.Y <= map.height-0.5, "Spawn outside map")
        for _,r in map.body do
            assert(p.X+0.47 <= r.x or p.X-0.47 >= r.x2 or p.Y+0.5 <= r.y or p.Y-0.5 >= r.y2, "Spawn inside wall")
        end
    end
    if mirrored then assert(spawns[1].X + spawns[2].X == map.width and spawns[1].Y == spawns[2].Y, "Unpaired spawns") end
    return map
end
Map.arena = Map.compile(Map.rows, Map.spawns, true)
Map.arena.title, Map.arena.code, Map.arena.id = data.Name, data.Code, DEFAULT

-- Compile one map module from the Maps folder.
function Map.load(id)
    local module = Maps:FindFirstChild(id)
    assert(module and module:IsA("ModuleScript"), "No map named "..tostring(id))
    local source = require(module)
    local arena = Map.compile(source.Rows, source.Spawns, source.Mirrored)
    arena.title, arena.code, arena.id = source.Name or id, source.Code or "--", id
    return arena
end

-- The map chosen with "Set active" in the level editor, or Split Circuit.
function Map.active()
    local id = script.Parent:GetAttribute("ActiveMap")
    if not id or id == DEFAULT then return Map.arena end
    local ok, arena = pcall(Map.load, id)
    if ok then return arena end
    warn("[NOVA] Active map "..id.." is invalid, using Split Circuit: "..tostring(arena))
    return Map.arena
end

-- Compile the rotation once per process; editor maps join the rotation on the next Play.
local rotation
function Map.pool()
    if rotation then return rotation end
    rotation = {}
    for _, module in Maps:GetChildren() do
        if module:IsA("ModuleScript") then
            local ok, arena = pcall(Map.load, module.Name)
            if ok then table.insert(rotation, arena)
            else warn("[NOVA] Skipping invalid map "..module.Name..": "..tostring(arena)) end
        end
    end
    table.sort(rotation, function(a,b) return a.code == b.code and a.id < b.id or a.code < b.code end)
    assert(#rotation > 0, "No playable maps")
    return rotation
end

local random = Random.new()
function Map.choose(previous)
    local candidates = {}
    for _, arena in Map.pool() do
        if arena.id ~= previous then table.insert(candidates, arena) end
    end
    if #candidates == 0 then return Map.pool()[1] end
    return candidates[random:NextInteger(1,#candidates)]
end
return Map
