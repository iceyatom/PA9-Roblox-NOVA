return function(t)
    local F=require(script.Parent.Parent.Fixture)
    local Movement=require(game.ServerScriptService.NOVA.Movement)
    local Map=require(game.ReplicatedStorage.NOVA.Map1)
    local cfg=require(game.ReplicatedStorage.NOVA.Config)
    t.test("map symmetry, masks and spawns",function()
        local a=Map.arena
        assert(a.width==38 and a.height==29 and #a.pads==2)
        for _,row in a.rows do assert(row==row:reverse()) end
        assert(a.spawns[1].X+a.spawns[2].X==38)
    end)
    t.test("malformed map data fails during compilation",function()
        for _,rows in {{{}},{"....","..."},{"..X."},{".P.."}} do
            assert(not pcall(Map.compile,rows,Map.spawns,true))
        end
    end)
    for _,tile in {"P","D","L"} do
        for _,v in {Vector2.xAxis,-Vector2.xAxis,Vector2.yAxis,-Vector2.yAxis} do
            t.test(tile.." player mask from "..tostring(v),function()
                local map=Map.compile({".....",".....",".."..tile.."..",".....","....."},{Vector2.new(.5,.5),Vector2.new(4.5,.5)})
                local b=Movement.body(Vector2.new(2.5,2.5)-v*1.4,cfg)
                b.axis=v.X; b.vy=v.Y*20
                local c=table.clone(cfg); c.Gravity=0
                Movement.step(b,nil,map,c,.12)
                local extent=v.X~=0 and cfg.BodyWidth/2 or cfg.BodyHeight/2
                local distance=(Vector2.new(2.5,2.5)-Vector2.new(b.x,b.y)):Dot(v)
                if tile=="L" then assert(distance<.5+extent) else F.near(distance,.5+extent) end
            end)
        end
    end
    t.test("ground jump, no double jump, airborne fast-fall",function()
        local s=F.duel(); local b=s.bodies[1]
        s:intent(1,s.round,"jump"); s:step(cfg.Step); assert(b.vy<0)
        local initial=b.vy
        s:intent(1,s.round,"jump"); s:step(cfg.Step); F.near(b.vy-initial,cfg.Gravity*cfg.Step)
        initial=b.vy; s:intent(1,s.round,"move",0,true); s:step(cfg.Step)
        F.near(b.vy-initial,(cfg.Gravity+cfg.FastFall)*cfg.Step)
        F.advance(s,180); F.near(b.y,11.5); F.near(b.vy,0)
    end)
    t.test("green pads require exit before recontact",function()
        local b=Movement.body(Vector2.new(8.5,27.5),cfg)
        Movement.step(b,nil,Map.arena,cfg,cfg.Step); F.near(b.vy,-cfg.Launch)
        b.vy=0; Movement.step(b,nil,Map.arena,cfg,cfg.Step); F.near(b.vy,0)
        b.x=7; Movement.step(b,nil,Map.arena,cfg,cfg.Step)
        b.x=8.5; Movement.step(b,nil,Map.arena,cfg,cfg.Step); F.near(b.vy,-cfg.Launch)
    end)
    t.test("opposing players stop at contact and stay inside bounds",function()
        local s=F.duel()
        s:intent(1,s.round,"move",1,false); s:intent(2,s.round,"move",-1,false)
        F.advance(s,160); F.near(s.bodies[2].x-s.bodies[1].x,cfg.BodyWidth)
        s:intent(1,s.round,"move",-1,false); s:intent(2,s.round,"move",1,false)
        F.advance(s,240); F.near(s.bodies[1].x,cfg.BodyWidth/2); F.near(s.bodies[2].x,20-cfg.BodyWidth/2)
    end)
end
