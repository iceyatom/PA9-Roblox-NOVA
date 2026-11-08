return function(t)
    local Store=require(game.ServerScriptService.NOVA.ProgressionStore)
    local P=require(game.ReplicatedStorage.NOVA.Progression)
    local function fixture()
        local values={}
        local store={fail=false}
        function store:UpdateAsync(key,fn)
            if self.fail then error("Storage unavailable") end
            local value=fn(values[key])
            if value~=nil then values[key]=value end
            return value
        end
        local time=1000
        return values,store,function() return time end,function(n) time+=n end
    end
    t.test("saved progression survives rejoining and releasing a session",function()
        local _,store,now=fixture()
        local a,b=Store.new(store,"a",now),Store.new(store,"b",now)
        local profile=assert(a:load(1))
        P.award(profile.data,777)
        assert(a:save(1,profile,true))
        local loaded=assert(b:load(1))
        assert(loaded.data.level==profile.data.level and loaded.data.xp==profile.data.xp and loaded.data.totalXP==777)
    end)
    t.test("active session locks block overlapping loads",function()
        local _,store,now=fixture()
        local a,b=Store.new(store,"a",now),Store.new(store,"b",now)
        assert(a:load(1) and not b:load(1))
        assert(b:load(2))
    end)
    t.test("expired sessions can transfer and stale servers cannot save",function()
        local values,store,now,advance=fixture()
        local a,b=Store.new(store,"a",now),Store.new(store,"b",now)
        local old=assert(a:load(1))
        advance(Store.LeaseSeconds+1)
        local current=assert(b:load(1))
        P.award(old.data,999)
        assert(not a:save(1,old,false) and not a:save(1,old,true))
        assert(values["1"].owner=="b" and current.data.totalXP==0)
    end)
    t.test("autosaves renew the lease",function()
        local _,store,now,advance=fixture()
        local a,b=Store.new(store,"a",now),Store.new(store,"b",now)
        local profile=assert(a:load(1))
        advance(150)
        assert(a:save(1,profile,false))
        advance(40)
        assert(not b:load(1) and profile.expires>now())
    end)
    t.test("failed or invalid loads never overwrite existing data",function()
        local values,store,now=fixture()
        values["1"]={schema=2,data={future=true}}
        local a=Store.new(store,"a",now)
        assert(not a:load(1) and values["1"].schema==2)
        values["2"]={schema=1,data={level=1000}}
        assert(not a:load(2) and values["2"].data.level==1000)
        store.fail=true
        assert(not a:load(3) and values["3"]==nil)
    end)
    t.test("failed saves preserve local XP for a later retry",function()
        local values,store,now=fixture()
        local a=Store.new(store,"a",now)
        local profile=assert(a:load(1))
        P.award(profile.data,300)
        store.fail=true
        assert(not a:save(1,profile,false) and profile.data.totalXP==300)
        store.fail=false
        assert(a:save(1,profile,false) and values["1"].data.totalXP==300)
    end)
end
