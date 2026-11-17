return function(t)
    local shared=game.ReplicatedStorage.NOVA
    local Q=require(shared.Quests)
    local S=require(shared.Stats)
    local I=require(shared.Inventory)
    local day=20000
    local now=day*Q.DaySeconds+3600
    local function event(key,outcome,extra)
        local e={key=key,outcome=outcome,mapId="SplitCircuit",mapName="Split Circuit",shots=10,hits=5,time=now}
        for name,value in extra or {} do e[name]=value end
        return e
    end
    -- Deal a known hand so cases do not depend on the day's rotation.
    local function hand(daily,weekly)
        local state=Q.new();Q.roll(state,now)
        state.daily.list={};state.weekly.list={}
        for _,id in daily or {} do table.insert(state.daily.list,{id=id,progress=0,claimed=false}) end
        for _,id in weekly or {} do table.insert(state.weekly.list,{id=id,progress=0,claimed=false}) end
        return state
    end
    local function row(list,title) for _,entry in list do if entry.title==title then return entry end end end
    t.test("quest rotation is the same on every server and mixes quest types",function()
        local changed=false
        for offset=0,60 do
            for _,kind in {"daily","weekly"} do
                local a,b=Q.selection(kind,day+offset),Q.selection(kind,day+offset)
                assert(#a==3 and table.concat(a,",")==table.concat(b,","))
                local metrics={}
                for _,id in a do
                    local prefix=id:match("^._(%a+)")
                    assert(not metrics[prefix],"two quests of one type on the same reset");metrics[prefix]=true
                end
            end
            if table.concat(Q.selection("daily",day+offset),",")~=table.concat(Q.selection("daily",day),",") then changed=true end
        end
        assert(changed,"daily quests never rotate")
    end)
    t.test("daily and weekly periods reset at UTC midnight and Monday",function()
        assert(Q.period("daily",86399)==0 and Q.period("daily",86400)==1)
        -- 1 Jan 1970 was a Thursday, so the first Monday is day 4.
        assert(Q.period("weekly",4*86400-1)==0 and Q.period("weekly",4*86400)==1 and Q.period("weekly",11*86400)==2)
        assert(Q.resetAt("daily",1)==2*86400 and Q.resetAt("weekly",1)==11*86400)
    end)
    t.test("match results advance matching quests and cap at the goal",function()
        local state=hand({"d_play3","d_win2","d_hits25"},{"w_play20","w_streak3","w_flawless1"})
        Q.record(state,event("1","win",{flawless=true}));Q.record(state,event("2","loss",{hits=30}))
        local view=Q.view(state,S.new(),now)
        assert(row(view.daily.list,"Warm-up").progress==2 and row(view.daily.list,"Double down").progress==1)
        assert(row(view.daily.list,"On target").progress==25 and row(view.daily.list,"On target").complete)
        assert(row(view.weekly.list,"Dedicated").progress==2 and row(view.weekly.list,"Untouched").complete)
        assert(row(view.weekly.list,"Hat trick").progress==1 and view.ready==2)
    end)
    t.test("streak quests need consecutive wins and map quests count distinct maps",function()
        local state=hand({"d_streak2","d_maps2"})
        Q.record(state,event("1","win"));Q.record(state,event("2","draw"));Q.record(state,event("3","win"))
        assert(state.daily.list[1].progress==1 and state.daily.list[2].progress==1)
        Q.record(state,event("4","win",{mapId="Nexus"}))
        assert(state.daily.list[1].progress==2 and state.daily.list[2].progress==2)
        Q.record(state,event("5","loss",{mapId="Nexus"}))
        assert(state.daily.list[1].progress==2 and state.daily.list[2].progress==2)
    end)
    t.test("claims pay once and reject unfinished repeated and stale requests",function()
        local state=hand({"d_win1","d_play3"})
        local key=("daily:%d:d_win1"):format(day)
        assert(not Q.claim(state,S.new(),key,now) and state.claimedXP==0)
        Q.record(state,event("1","win"))
        local ok,reward=Q.claim(state,S.new(),key,now)
        assert(ok and reward.xp==250 and state.claimedXP==250)
        assert(not Q.claim(state,S.new(),key,now) and state.claimedXP==250)
        assert(not Q.claim(state,S.new(),("daily:%d:d_win1"):format(day-1),now))
        assert(not Q.claim(state,S.new(),("daily:%d:d_missing"):format(day),now))
        assert(not Q.claim(state,S.new(),"daily",now) and not Q.claim(state,S.new(),12,now))
        state=assert(Q.validate(state));assert(state.daily.list[1].claimed and state.claimedXP==250)
    end)
    t.test("unclaimed finished quests pay out automatically when they reset",function()
        local state=hand({"d_win1","d_play3"},{"w_play20"})
        Q.record(state,event("1","win"))
        assert(Q.claim(state,S.new(),("daily:%d:d_win1"):format(day),now))
        Q.record(state,event("2","win"));Q.record(state,event("3","win"))
        assert(state.daily.list[2].progress==3 and state.claimedXP==250 and not Q.stale(state,now))
        local tomorrow=now+Q.DaySeconds
        assert(Q.stale(state,tomorrow))
        -- Viewing never changes the saved state.
        assert(Q.view(state,S.new(),tomorrow).autoXP==250 and state.claimedXP==250)
        Q.roll(state,tomorrow)
        assert(state.claimedXP==500 and state.autoXP==250 and state.daily.period==day+1 and #state.daily.list==3)
        for _,entry in state.daily.list do assert(entry.progress==0 and not entry.claimed) end
        Q.roll(state,tomorrow);Q.roll(state,now)
        assert(state.claimedXP==500 and state.daily.period==day+1)
        assert(Q.ack(state) and state.autoXP==0 and state.claimedXP==500)
    end)
    t.test("results from a finished period do not count toward the new one",function()
        local state=hand({"d_play3"})
        Q.roll(state,now+Q.DaySeconds)
        local before=state.daily.list[1].progress
        Q.record(state,event("late","win"))
        assert(state.daily.period==day+1 and state.daily.list[1].progress==before and state.daily.run==0)
    end)
    t.test("career quests use lifetime stats and climb five scaled tiers",function()
        local state=Q.new();local stats=S.new()
        for i=1,5 do assert(S.record(stats,event(tostring(i),"win",{flawless=i==1}))) end
        local view=Q.view(state,stats,now)
        local champion=row(view.career,"Champion")
        assert(champion.tier==1 and champion.tiers==5 and champion.goal==5 and champion.complete and champion.xp==500)
        assert(row(view.career,"Untouchable").complete and row(view.career,"Sharpshooter").progress==25)
        assert(not Q.claim(state,stats,"career:c_wins:2",now))
        assert(Q.claim(state,stats,"career:c_wins:1",now) and state.claimedXP==500)
        assert(not Q.claim(state,stats,"career:c_wins:1",now) and not Q.claim(state,stats,"career:c_wins:2",now))
        champion=row(Q.view(state,stats,now).career,"Champion")
        assert(champion.tier==2 and champion.goal==25 and champion.xp==1000 and not champion.complete)
        local last
        for _,def in Q.career do
            assert(#def.tiers==5)
            for i=2,5 do assert(def.tiers[i].goal>def.tiers[i-1].goal and def.tiers[i].xp>def.tiers[i-1].xp) end
            assert(def.tiers[5].item=="soon" and not def.tiers[4].item)
            last=def
        end
        state.career[last.id]=5
        local done=row(Q.view(state,stats,now).career,last.title)
        assert(done.claimed and not done.complete and not Q.claim(state,stats,("career:%s:6"):format(last.id),now))
    end)
    t.test("match recap lists moved quests with finished ones first",function()
        local state=hand({"d_play3","d_win1","d_shots60"},{"w_play20"})
        local stats=S.new()
        for i=1,4 do S.record(stats,event("old"..i,"win")) end
        local before=Q.view(state,stats,now)
        local e=event("new","win");S.record(stats,e);Q.record(state,e)
        local rows=Q.changes(before,Q.view(state,stats,now))
        assert(#rows==Q.RecapRows and rows[1].complete and rows[1].title=="First blood" and rows[1].from==0 and rows[1].to==1)
        local champion=false
        for _,entry in rows do if entry.kind=="career" then champion=entry.title=="Champion" end end
        assert(champion,"a newly finished career tier is reported")
        assert(#Q.changes(Q.view(state,stats,now),Q.view(state,stats,now))==0)
    end)
    t.test("crate openings count toward quests in the same inventory transaction",function()
        local d=I.new();I.grant(d,"crate_season1",5)
        Q.roll(d.quests,os.time());d.quests.weekly.list={{id="w_crates3",progress=0,claimed=false}}
        assert(I.open(d,"crate_season1","open:1",0));assert(d.quests.weekly.list[1].progress==1)
        assert(I.open(d,"crate_season1","open:1",0));assert(d.quests.weekly.list[1].progress==1)
        assert(I.openMany(d,"crate_season1","open:2",3,{0,0,0}));assert(d.quests.weekly.list[1].progress==3)
        d=assert(I.validate(d));assert(d.quests.weekly.list[1].progress==3)
    end)
    t.test("older profiles gain quests and hit stats without losing saved data",function()
        local raw=I.new();raw.quests=nil;raw.stats.shotsHit=nil;raw.stats.flawlessWins=nil;raw.shards=77
        local d=assert(I.validate(raw))
        assert(d.shards==77 and d.quests.claimedXP==0 and d.stats.shotsHit==0 and d.stats.flawlessWins==0)
        assert(#Q.view(d.quests,d.stats,now).daily.list==3)
    end)
    t.test("malformed quest saves are rejected instead of replacing a profile",function()
        local function broken(change) local s=hand({"d_win1"});change(s);return Q.validate(s)==nil end
        assert(broken(function(s) s.claimedXP=-1 end))
        assert(broken(function(s) s.autoXP=5 end))
        assert(broken(function(s) s.daily.list[1].progress=0.5 end))
        assert(broken(function(s) s.daily.list[1].claimed=true end))
        assert(broken(function(s) s.daily.maps[1]=true end))
        assert(broken(function(s) s.weekly=nil end))
        assert(broken(function(s) s.career.c_wins=-1 end))
        local raw=I.new();raw.quests={};assert(not I.validate(raw))
        local s=hand({"d_win1"});table.insert(s.daily.list,{id="d_retired",progress=9,claimed=false});s.career.c_retired=2
        s=assert(Q.validate(s));assert(#s.daily.list==1 and not s.career.c_retired)
        local e=event("x","win");e.hits=-1;assert(not S.record(S.new(),e))
        e=event("x","win");e.flawless="yes";assert(not S.record(S.new(),e))
    end)
end
