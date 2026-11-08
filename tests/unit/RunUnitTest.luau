-- Execute on a Studio Play server: require(game.ServerStorage.NOVAUnitTest.RunUnitTest)()
return function(filter)
    assert(game:GetService("RunService"):IsStudio(),"Studio tests only")
    local totals={run=0,passed=0,failed=0,errors={}}
    local function test(name,fn)
        totals.run+=1
        local ok,message=pcall(fn)
        if ok then totals.passed+=1
        else totals.failed+=1; table.insert(totals.errors,name..": "..tostring(message)); warn("[NOVA TEST]",name,message) end
    end
    for _,module in script.Parent.Cases:GetChildren() do
        if module:IsA("ModuleScript") and (not filter or module.Name:find(filter,1,true)) then
            require(module)({test=test})
        end
    end
    print(("[NOVA TEST] %d/%d passed"):format(totals.passed,totals.run))
    return totals
end
