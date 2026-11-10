-- Normal Play and published servers skip the integration driver.
if game:GetService("RunService"):IsStudio() then
    local test=game:GetService("StudioTestService")
    if test:GetTestArgs()=="NOVA/acceptance" or test:GetTestArgs()=="NOVA/batch1" or test:GetTestArgs()=="NOVA/batch-stress" then
        require(game.ServerStorage.NOVATesting.Session)()
    end
end
