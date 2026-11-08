return function(t)
    local B=require(game.ReplicatedStorage.NOVA.ControlBindings)
    t.test("control preferences survive serialization with independent device bindings",function()
        local prefs=B.copy(B.defaults)
        prefs.pc.left,prefs.pc.right,prefs.pc.jump,prefs.pc.fire="J","L","I","MouseButton2"
        prefs.console.move,prefs.console.jump,prefs.console.fire="Thumbstick2","ButtonX","ButtonR1"
        local http=game:GetService("HttpService")
        local loaded=assert(B.validate(http:JSONDecode(http:JSONEncode(prefs))))
        assert(loaded.pc.left=="J" and loaded.pc.fire=="MouseButton2" and loaded.console.move=="Thumbstick2")
        assert(B.defaults.pc.left=="A" and B.defaults.console.move=="Thumbstick1")
    end)
    t.test("conflicting and reserved control assignments are rejected",function()
        local prefs=B.copy(B.defaults)
        prefs.pc.fire="Space"; assert(not B.validate(prefs))
        prefs=B.copy(B.defaults); prefs.console.jump="ButtonSelect"; assert(not B.validate(prefs))
        prefs=B.copy(B.defaults); prefs.pc.jump="F2"; assert(not B.validate(prefs))
        prefs=B.copy(B.defaults); prefs.console.move="DPad"; prefs.console.fire="DPadRight"; assert(not B.validate(prefs))
        prefs.console.fire="ButtonR2"; assert(B.validate(prefs))
    end)
    t.test("corrupt preferences fail safely and unknown fields are discarded",function()
        for _,value in {false,12,"bad",{}, {pc=false,console={}}, {pc={},console={}}} do assert(not B.validate(value)) end
        local prefs=B.copy(B.defaults)
        prefs.console.jump={}; assert(not B.validate(prefs))
        prefs=B.copy(B.defaults); prefs.pc.left="not a key"; assert(not B.validate(prefs))
        prefs=B.copy(B.defaults); prefs.health=999; prefs.pc.position={}
        local clean=assert(B.validate(prefs)); assert(clean.health==nil and clean.pc.position==nil)
    end)
end
