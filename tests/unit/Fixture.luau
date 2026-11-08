local Shared=game.ReplicatedStorage.NOVA
local Match=require(game.ServerScriptService.NOVA.Match)
local Map=require(Shared.Map1)
local Config=require(Shared.Config)
local Fixture={}
function Fixture.duel()
    local rows=table.create(12,string.rep(".",20))
    local map=Map.compile(rows,{Vector2.new(3.5,11.5),Vector2.new(16.5,11.5)},true)
    local sim=Match.new(map,Config)
    sim:join("blue")
    sim:join("red")
    sim:step(Config.Countdown)
    sim:step(Config.Step)
    return sim
end
function Fixture.advance(sim,n)
    for _=1,n do sim:step(Config.Step) end
end
function Fixture.near(a,b)
    assert(math.abs(a-b)<1e-5,("expected %s, got %s"):format(b,a))
end
return Fixture
