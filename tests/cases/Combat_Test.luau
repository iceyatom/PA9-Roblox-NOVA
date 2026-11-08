return function(t)
    local F=require(script.Parent.Parent.Fixture)
    local Combat=require(game.ServerScriptService.NOVA.Combat)
    local cfg=require(game.ReplicatedStorage.NOVA.Config)
    local map=require(game.ReplicatedStorage.NOVA.Map1)
    local function shoot(s,i,n) assert(s:intent(i,s.round,"fire",n)) end
    t.test("one sequence per shot, rapid distinct IDs accepted",function()
        local s=F.duel()
        for i=1,64 do shoot(s,1,i); assert(not s:intent(1,s.round,"fire",i)) end
        assert(#s.bullets==64 and s.bodies[1].hp==10)
    end)
    t.test("shot starts at center and retains velocity after target moves",function()
        local s=F.duel(); shoot(s,1,1)
        local b=s.bullets[1]; local x,y=b.x,b.y
        F.near(x,s.bodies[1].x); F.near(y,s.bodies[1].y)
        s.bodies[2].y=2; Combat.step(s,.1)
        F.near(b.x-x,cfg.BulletSpeed*.1); F.near(b.y,y)
    end)
    t.test("zero-length vector and invalid fire IDs are safe",function()
        local s=F.duel()
        for _,id in {-1,0,0.5,math.huge,0/0,"1",{}} do assert(not s:intent(1,s.round,"fire",id)) end
        s.bodies[2].x=s.bodies[1].x
        assert(not s:intent(1,s.round,"fire",1) and #s.bullets==0)
    end)
    for _,tile in {"P","D","L","G"} do
        for _,direction in {Vector2.xAxis,-Vector2.xAxis,Vector2.yAxis,-Vector2.yAxis} do
            t.test(tile.." swept shot from "..tostring(direction),function()
                local s=F.duel()
                s.map=map.compile({".....",".....",".."..tile.."..",".....","....."},{Vector2.new(.5,.5),Vector2.new(4.5,.5)})
                local center=Vector2.new(2.5,2.5)
                for i,sign in {-1,1} do
                    local p=center+direction*sign*2
                    s.bodies[i].x,s.bodies[i].y=p.X,p.Y
                end
                shoot(s,1,1); Combat.step(s,1)
                assert(#s.bullets==0 and s.bodies[1].hp==10)
                assert(s.bodies[2].hp==((tile=="P" or tile=="L") and 10 or 9))
            end)
        end
    end
    t.test("misses expire at boundary and cannot damage owner",function()
        local s=F.duel(); shoot(s,1,1); s.bodies[2].y=2
        Combat.step(s,2); assert(#s.bullets==0 and s.bodies[1].hp==10 and s.bodies[2].hp==10)
    end)
    t.test("nine hits leave one, tenth locks result, late fire ignored",function()
        local s=F.duel()
        for i=1,9 do shoot(s,1,i) end
        F.advance(s,60); assert(s.bodies[2].hp==1 and s.phase=="Playing" and #s.bullets==0)
        shoot(s,1,10); F.advance(s,60)
        assert(s.bodies[2].hp==0 and s.winner==1 and s.phase=="Results")
        assert(not s:intent(2,s.round,"fire",11))
    end)
    t.test("simultaneous lethal hits draw, crossing bullets pass",function()
        local s=F.duel()
        for i=1,10 do shoot(s,1,i); shoot(s,2,i) end
        F.advance(s,60); assert(s.phase=="Results" and s.winner==0 and s.bodies[1].hp==0 and s.bodies[2].hp==0)
    end)
end
