return function(t)
    local Leaderboard=require(game.ServerScriptService.NOVA.PracticeLeaderboard)
    local function make()
        local board=Instance.new("Part")
        local gui=Instance.new("SurfaceGui"); gui.Name="Rankings"; gui.Parent=board
        for i=1,10 do local row=Instance.new("TextLabel"); row.Name="Row"..i; row.Parent=gui end
        local status=Instance.new("TextLabel"); status.Name="Status"; status.Parent=gui
        return setmetatable({board=board,best={},names={},global={},pending={},saving={},ready=true},Leaderboard),gui
    end
    t.test("practice leaderboard shows ten descending unique personal bests",function()
        local service,gui=make()
        for uid=1,12 do
            table.insert(service.global,{uid=uid,score=uid*10})
            service.names[uid]="Player"..uid
        end
        service.best[1]=125; service.best[12]=1
        service:render()
        assert(gui.Row1.Text:find("Player1 ",1,true) and gui.Row1.Text:find("125",1,true))
        assert(gui.Row2.Text:find("Player12",1,true) and gui.Row2.Text:find("120",1,true))
        assert(gui.Row10.Text:find("Player4 ",1,true))
        service.board:Destroy()
    end)
    t.test("practice persistence preserves higher existing scores and clears saved pending work",function()
        local service=make()
        local saved=90
        service.store={UpdateAsync=function(_,key,transform)
            assert(key=="42")
            saved=transform(saved)
            return saved
        end}
        service.best[42]=12; service.pending[42]=12
        local notified
        service.updated=function(uid,status) assert(uid==42); notified=status end
        service:persist(42)
        assert(saved==90 and service.best[42]==90 and service.pending[42]==nil and notified=="Saved")
        service.pending[42]=100; service:persist(42)
        assert(saved==100 and service.best[42]==100)
        service.board:Destroy()
    end)
end
