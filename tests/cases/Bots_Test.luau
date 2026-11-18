return function(t)
    local shared=game.ReplicatedStorage.NOVA
    local server=game.ServerScriptService.NOVA
    local Bots=require(shared.Bots)
    local Lobbies=require(server.Lobbies)
    local Match=require(server.Match)
    local Map=require(shared.Map1)
    local Config=require(shared.Config)
    local Rewards=require(shared.XPRewards)
    local Drop=require(shared.CrateDrop)
    local I=require(shared.Inventory)
    local function make()
        local finished={}
        local service=Lobbies.new(Map.arena,Config,nil,function(sim) table.insert(finished,sim) end)
        return service,finished
    end
    local function size(items) local n=0 for _ in items do n+=1 end return n end
    -- Two bots on an open floor, with a simulated clock for the shared fire limit.
    local function botDuel(a,b,seconds)
        local rows=table.create(12,string.rep(".",20))
        local sim=Match.new(Map.compile(rows,{Vector2.new(3.5,11.5),Vector2.new(16.5,11.5)},true),Config)
        local clock=0
        sim.fireClock=function() return clock end
        sim.seats[1],sim.seats[2]=Bots.key(a),Bots.key(b)
        sim:reset("Countdown");sim:step(Config.Countdown)
        for _=1,seconds/Config.Step do
            if sim.phase~="Playing" then break end
            clock+=Config.Step;sim:step(Config.Step)
        end
        return sim
    end
    t.test("a queued player can start a bot duel and stays open to a real opponent",function()
        local service,finished=make()
        local room=service:join("ann").room
        assert(not service:intent("ann",room.id,0,"bot","expert") and not service:intent("ann",room.id,0,"bot",nil))
        assert(service:intent("ann",room.id,0,"bot","veteran"))
        assert(room.sim.botDuel and room.sim.phase=="Countdown" and Bots.is(room.sim.seats[2]) and room.sim.seats[2].level=="veteran")
        service:step(Config.Countdown);service:step(Config.Step)
        assert(room.sim.phase=="Playing")
        assert(service:intent("ann",room.id,1,"fire",1) and not service:intent("ann",room.id,1,"bot","beginner"))
        -- A real player arrives: the bot duel ends at once with no result.
        local entry=service:join("bob")
        assert(entry.room==room and size(service.rooms)==1 and #finished==0)
        assert(not room.sim.botDuel and room.sim.seats[1]=="ann" and room.sim.seats[2]=="bob")
        assert(room.sim.phase=="Countdown" and room.sim.session.played==0 and #room.sim.bullets==0)
        assert(not service:intent("ann",room.id,room.sim.round,"bot","beginner"))
    end)
    t.test("waiting survivors also replace a queue bot",function()
        local service,finished=make()
        for _,name in {"ann","bob","cat"} do service:join(name) end
        local solo=service.membership.cat.room
        assert(service:intent("cat",solo.id,0,"bot","beginner"))
        -- Ann's rival leaves mid-countdown; Ann is waiting again and takes the bot's place.
        service:remove("bob")
        assert(service.membership.ann.room==service.membership.cat.room and size(service.rooms)==1)
        local sim=service.membership.ann.room.sim
        assert(not sim.botDuel and not Bots.is(sim.seats[1]) and not Bots.is(sim.seats[2]) and #finished==0)
    end)
    t.test("bot practice rooms stay out of matchmaking and close when the player leaves",function()
        local service=make()
        local private=service:joinPrivate("ann").room
        assert(private.private and private.sim.phase=="Waiting")
        local other=service:join("bob").room
        assert(other~=private and other.sim.phase=="Waiting")
        assert(service:intent("ann",private.id,0,"bot","intermediate"))
        assert(service:join("cat").room==other and private.sim.botDuel)
        service:step(Config.Countdown);service:step(Config.Step)
        service:remove("ann")
        assert(not service.rooms[private.id] and not service.membership.ann and size(service.rooms)==1)
    end)
    t.test("bot duels rematch at once change difficulty and have no match limit",function()
        local service,finished=make()
        local room=service:joinPrivate("ann").room
        local sim=room.sim
        assert(service:intent("ann",room.id,0,"bot","beginner"))
        for round=1,Config.SessionMatchLimit+2 do
            service:step(Config.Countdown);service:step(Config.Step)
            assert(sim.phase=="Playing" and sim.round==round)
            sim:finish(1,"Elimination")
            assert(not sim.session.complete and sim:sessionView(0).limit==0 and sim:sessionView(0).game==round)
            if round%2==0 then assert(service:intent("ann",room.id,round,"bot","veteran") and sim.seats[2].level=="veteran")
            else assert(service:intent("ann",room.id,round,"rematch")) end
            assert(sim.phase=="Countdown" and sim.session.wins[1]==round)
        end
        assert(#finished==Config.SessionMatchLimit+2)
    end)
    t.test("bots cannot replace a real opponent or reopen a finished session",function()
        local service=make()
        service:join("ann");local room=service:join("bob").room
        service:step(Config.Countdown);service:step(Config.Step)
        room.sim:finish(1,"Elimination")
        assert(not service:intent("ann",room.id,1,"bot","beginner") and not room.sim.botDuel)
        -- After the rival leaves, the survivor may pick a bot instead of waiting.
        service:remove("bob")
        assert(service:intent("ann",room.id,1,"bot","beginner") and room.sim.botDuel and room.sim.session.played==0)
        local sim=Match.new(Map.arena,Config);sim:join("a");sim:join("b")
        sim.session.complete=true;sim.session.remaining=30;sim.phase="Results";sim.seats[2]=nil
        assert(not sim:setBot(1,"beginner"))
    end)
    t.test("bot duels pay XP by difficulty and Double XP doubles each payout",function()
        local function total(items) local n=0 for _,item in items do n+=item.amount end return n end
        assert(total(Rewards.items(false,false))==100 and total(Rewards.items(true,false))==300)
        local completion={beginner=40,intermediate=60,experienced=80,veteran=100}
        for level,xp in completion do
            local win=Rewards.items(true,false,level)
            assert(win[1].label=="Bot duel completed" and win[1].amount==xp and win[2].amount==2*xp)
            assert(total(Rewards.items(false,false,level))==xp and total(win)==3*xp)
            assert(total(Rewards.items(false,true,level))==2*xp and total(Rewards.items(true,true,level))==6*xp)
        end
    end)
    t.test("bot wins roll at half the crate chance and never change it",function()
        local d=I.new();d.crateChance=60;local expires=os.time()+1000
        local ok,miss=I.matchReward(d,"bot/1",expires,"win",0.3,nil,true)
        assert(ok and miss.bot and miss.chance==30 and not miss.awarded and d.crateChance==60 and not d.owned.crate_season1)
        local _,hit=I.matchReward(d,"bot/2",expires,"win",0.299,nil,true)
        assert(hit.awarded and hit.nextChance==60 and d.crateChance==60 and d.owned.crate_season1==1)
        assert(not I.matchReward(d,"bot/3",expires,"loss",nil,nil,true) and d.crateChance==60 and not d.wins["bot/3"])
        -- Receipts survive a save and a retry cannot roll again.
        d=assert(I.validate(d))
        local again,replayed,replay=I.matchReward(d,"bot/1",expires,"win",0,nil,true)
        assert(again and replay and not replayed.awarded and d.owned.crate_season1==1)
        -- The same roll against a real player would have won and reset the chance.
        local _,online=I.matchReward(d,"online/1",expires,"win",0.3)
        assert(online.awarded and online.chance==60 and d.crateChance==Drop.BaseChance)
        d.dropReceipts["bot/1"].chance=10;assert(not I.validate(d))
        d.dropReceipts["bot/1"].chance=30;d.dropReceipts["bot/1"].bot="yes";assert(not I.validate(d))
    end)
    t.test("bots fire within the shared rate limit and finish their duels",function()
        local sim=botDuel("veteran","veteran",120)
        assert(sim.phase=="Results",sim.phase)
        for seat=1,2 do
            local body=sim.bodies[seat]
            assert((body.acceptedShots or 0)>0 and body.acceptedShots<=120*12)
        end
    end)
    t.test("a veteran bot hunts down a player who stands still on every map",function()
        for _,map in Map.pool() do
            local wins=0
            for _=1,3 do
                local sim=Match.new(map,Config)
                local clock=0
                sim.fireClock=function() return clock end
                sim.seats[1],sim.seats[2]="idle",Bots.key("veteran")
                sim:reset("Countdown");sim:step(Config.Countdown)
                for _=1,150/Config.Step do
                    if sim.phase~="Playing" then break end
                    clock+=Config.Step;sim:step(Config.Step)
                end
                if sim.winner==2 then wins+=1 end
            end
            assert(wins>=2,("veteran beat an idle player only %d of 3 times on %s"):format(wins,map.id))
        end
    end)
    t.test("each difficulty beats the one below it more often than not",function()
        local order=Bots.order
        for i=2,#order do
            local wins=0
            for _=1,15 do
                local sim=botDuel(order[i],order[i-1],240)
                if sim.winner==1 then wins+=1 end
            end
            assert(wins>=9,("%s won only %d of 15 against %s"):format(order[i],wins,order[i-1]))
        end
    end)
end
