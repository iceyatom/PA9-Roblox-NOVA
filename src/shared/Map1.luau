local Catalog = require(script.Parent.TileCatalog)
local Map = {}

-- A complete logical cell per character. Origins and spawns use zero-based tile units.
Map.rows = {
    "P....................................P",
    "P....................................P",
    "P...P........DDD......DDD........P...P",
    "P...PPP.....L...D....D...L.....PPP...P",
    "P...P..P....L...D....D...L....P..P...P",
    "PP..P..P....L...D....D...L....P..P..PP",
    "P...P...P...L...D....D...L...P...P...P",
    "P...P...P...L...D....D...L...P...P...P",
    "P..PP...P....DDD......DDD....P...PP..P",
    "P...P............................P...P",
    "P...P.....D................D.....P...P",
    "PP..P.....DD..............DD.....P..PP",
    "P...P.......DDDDDDDDDDDDDD.......P...P",
    "P...P............................P...P",
    "P..PP............................PP..P",
    "P...P............................P...P",
    "P...P............................P...P",
    "PP..P............................P..PP",
    "P...P............................P...P",
    "P...P............................P...P",
    "P..PP.........PPPPPPPPPP.........PP..P",
    "P...P.......PP..........PP.......P...P",
    "P...P............................P...P",
    "PP..P.....P................P.....P..PP",
    "P.........P......PPPP......P.........P",
    "P.........P.....P....P.....P.........P",
    ".PP.......PLLLLP......PLLLLP.......PP.",
    "...P....G.........PP.........G....P...",
    "...PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP...",
}
Map.spawns = {Vector2.new(6.5,27.5), Vector2.new(31.5,27.5)}

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
return Map
