local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local core=game:GetService("StarterGui")
local UIS=game:GetService("UserInputService")
local mobile=UIS.TouchEnabled
-- Cursor opt-in is exposed on some engine channels; otherwise CoreScripts own the default.
pcall(function() core.VirtualCursorMode=Enum.VirtualCursorMode.Enabled end)
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage:WaitForChild("NOVA")
local input=shared:WaitForChild("Input")
local state=shared:WaitForChild("State")
local practiceInput=shared:WaitForChild("PracticeInput")
local practiceState=shared:WaitForChild("PracticeState")
local hud=require(script.Parent.Hud).new(player:WaitForChild("PlayerGui"))
local arena=require(script.Parent.Arena).new(hud.stage)
local roller=require(script.Parent.MapRoller).new(hud.stage,mobile)
hud.mapCode.Text=("MAP   /   %s"):format(arena.map.code)
hud.mapTitle.Text=arena.map.title
local lobbyCard=require(script.Parent.LobbyHud).new(player.PlayerGui,mobile)
local lobbyMusic=require(script.Parent.LobbyMusic).new()
local snapshot,seat,sequence
local practice,practiceSnapshot,practiceSequence
local function fire(kind,a,b)
    if practiceSnapshot then
        if kind=="move" or kind=="jump" then return end
        if kind=="fire" then practiceSequence+=1; a=practiceSequence end
        practiceInput:FireServer(kind,practiceSnapshot.id,a)
        return
    end
    if not snapshot or not seat then return end
    if kind=="fire" then sequence+=1; a=sequence end
    input:FireServer(kind,snapshot.lobby,snapshot.round,a,b)
end
local settings=require(script.Parent.ControlSettings).new()
hud.resultBanner.getBindings=function() return settings.bindings end
practice=require(script.Parent.PracticeHud).new(player.PlayerGui,fire,mobile)
local clear,showTouch=require(script.Parent.Input).connect(fire,function()
    return not settings.opened and ((practiceSnapshot and practiceSnapshot.phase=="Playing") or (seat and snapshot.phase=="Playing"))
end,settings,player.PlayerGui)
local settingsMenu=require(script.Parent.SettingsMenu).new(player.PlayerGui,settings,clear)
local progressionHud,progressionMenu=require(script.Parent.ProgressionHud).new(player.PlayerGui,clear)
local inventory=require(script.Parent.InventoryMenu).new(player.PlayerGui,clear)
local shop
shop=require(script.Parent.ShopMenu).new(player.PlayerGui,clear,nil,{
    profile=function() return inventory.profile end,
    crates=function() shop:setOpen(false); inventory:showCrates() end,
    contents=function() shop:setOpen(false); inventory:showCrateContents() end,
})
local function inventoryProfile() return inventory.profile end
local daily=require(script.Parent.DailyRewardsMenu).new(player.PlayerGui,clear,nil,inventoryProfile)
local stats=require(script.Parent.StatsMenu).new(player.PlayerGui,clear,nil,inventoryProfile)
local quests=require(script.Parent.QuestsMenu).new(player.PlayerGui,clear,nil,inventoryProfile)
local menus={progressionMenu,inventory,shop,daily,stats,quests,settingsMenu}
local mobileLobby
if mobile then
    mobileLobby=require(script.Parent.MobileLobby).new(player.PlayerGui,
        {progressionMenu,inventory,shop,daily},{settingsMenu,quests,stats},shop.chipRow)
end
local function openMenu()
    for _,menu in menus do
        if menu.gui:GetAttribute("MenuOpen") then return menu end
    end
end
local function canOpenMenu() return openMenu()==nil end
daily.canAutoOpen=canOpenMenu
local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local launchers={}
for _,menu in menus do
    menu.beforeOpen=canOpenMenu
    local gui,launcher=menu.gui,menu.launcher
    local shade=W.box(launcher,"MenuLocked",0,0,0,0,W.colors.ink,50)
    shade.Size=UDim2.fromScale(1,1);shade.BackgroundTransparency=.30
    Style.round(shade,10)
    launchers[menu]={shade=shade,closedOrder=gui.DisplayOrder}
end
local function syncMenus()
    local current=openMenu()
    for menu,appearance in launchers do
        local launcher=menu.launcher
        local blocked=current~=nil and current~=menu
        launcher.Interactable=not blocked
        launcher.Active=not blocked
        launcher.Selectable=not blocked
        launcher.AutoButtonColor=not blocked
        appearance.shade.Visible=blocked
        menu.gui.DisplayOrder=menu==current and 20 or appearance.closedOrder
    end
    if not current then settingsMenu:layout() end
end
for _,menu in menus do menu.gui:GetAttributeChangedSignal("MenuOpen"):Connect(syncMenus) end
syncMenus()
settingsMenu.selectionOnClose=function()
    if practiceSnapshot then return practiceSnapshot.phase=="Results" and practice.retry or practice.leave end
    if not snapshot then return nil end
    return snapshot.phase=="Results" and hud:resultsReady() and (snapshot.session and snapshot.session.complete and hud.leave or hud.rematch) or snapshot.phase=="Waiting" and not hud.resultBanner.blocked and hud.leave or nil
end
task.spawn(function() settings:load() end)
hud.onBot=function(level) if snapshot and seat and not hud.resultBanner.blocked and (snapshot.phase~="Results" or hud:resultsReady()) then fire("bot",level) end end
hud.rematch.Activated:Connect(function() if hud:resultsReady() and hud.rematch.Active then fire("rematch") end end)
hud.leave.Activated:Connect(function() if snapshot and not hud.resultBanner.blocked and (snapshot.phase~="Results" or hud:resultsReady()) then fire("leave") end end)
local openAfterLobby=false
hud.openChest.Activated:Connect(function()
    if snapshot and hud:resultsReady() and snapshot.winner==seat and snapshot.chest and snapshot.chest.status=="Chest earned" and snapshot.chest.receipt and snapshot.chest.receipt.awarded and hud.chestRoll.settled then
        hud.chestRoll:dismiss();openAfterLobby=true; fire("leave")
    end
end)
local record
if Run:IsStudio() then record=require(script.Parent.Diagnostics).attach(hud,arena,shared:WaitForChild("StudioControls")) end
-- The lobby uses the normal Roblox character, camera and core UI. The duel uses the 2D stage.
local inDuel
local function setMode(duel)
    if inDuel==duel then return end
    inDuel=duel
    lobbyMusic:setActive(not duel)
    settingsMenu:setAvailable(not duel)
    hud.gui.Enabled=duel
    lobbyCard.Enabled=not duel
    if mobileLobby then mobileLobby.Enabled=not duel end
    progressionHud.Enabled=not duel
    if duel then progressionMenu:setOpen(false) end
    inventory:setAvailable(not duel)
    shop:setAvailable(not duel)
    daily:setAvailable(not duel)
    stats:setAvailable(not duel)
    quests:setAvailable(not duel)
    local camera=workspace.CurrentCamera
    if camera then
        camera.CameraType=duel and Enum.CameraType.Scriptable or Enum.CameraType.Custom
        local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not duel and humanoid then camera.CameraSubject=humanoid end
    end
    pcall(function() core:SetCoreGuiEnabled(Enum.CoreGuiType.All,not duel) end)
    if not duel then pcall(function() core:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end) end
end
player.CharacterAdded:Connect(function(character)
    local camera=workspace.CurrentCamera
    if camera and not inDuel then
        camera.CameraType=Enum.CameraType.Custom
        camera.CameraSubject=character:WaitForChild("Humanoid")
    end
end)
state.OnClientEvent:Connect(function(nextState)
    practiceSnapshot=nil
    practice:hide()
    if nextState.phase=="Lobby" then
        snapshot,seat=nil,nil
        clear()
        roller:hide()
        setMode(false)
        if showTouch then showTouch(false,false) end
        arena:clearShots()
        if openAfterLobby then openAfterLobby=false; inventory:openVictoryChest() end
        return
    end
    local previous=snapshot
    snapshot=nextState
    seat=nil
    for i,p in snapshot.players do if p.uid==player.UserId then seat=i end end
    if not seat then return end
    setMode(true)
    arena:setMap(snapshot.mapId)
    arena.field.Visible=snapshot.phase~="Selecting"
    hud.mapCode.Text=snapshot.phase=="Selecting" and "MAP   /   --" or ("MAP   /   %s"):format(arena.map.code)
    hud.mapTitle.Text=snapshot.phase=="Selecting" and "Selecting arena…" or arena.map.title
    roller:update(snapshot)
    local newDuel=not previous or previous.lobby~=snapshot.lobby or previous.round~=snapshot.round
    if newDuel then sequence=0 end
    if newDuel or previous.phase~=snapshot.phase then
        clear()
        if record then record(("Round %d / %s"):format(snapshot.round,snapshot.phase)) end
    end
    if record and previous and not newDuel then
        for i,p in snapshot.players do
            if p.hp<previous.players[i].hp then record(("P%d hit / %d HP"):format(i,p.hp)) end
        end
    end
    hud:update(snapshot,seat)
    if showTouch then showTouch(snapshot.phase=="Playing",false) end
    if not settings.opened and (newDuel or previous.phase~=snapshot.phase)
        and game:GetService("UserInputService"):GetLastInputType().Name:sub(1,7)=="Gamepad" then
        game:GetService("GuiService").SelectedObject=settingsMenu.selectionOnClose()
    end
    arena:update(snapshot,os.clock())
end)
practiceState.OnClientEvent:Connect(function(nextState)
    local previous=practiceSnapshot
    if nextState.phase=="Lobby" then
        practiceSnapshot=nil; snapshot,seat=nil,nil
        clear(); practice:hide(); setMode(false)
        if showTouch then showTouch(false,false) end
        return
    end
    snapshot,seat=nil,nil
    practiceSnapshot=nextState
    if not previous or previous.id~=nextState.id then practiceSequence=0 end
    if not previous or previous.id~=nextState.id or previous.phase~=nextState.phase then clear() end
    setMode(true); hud.gui.Enabled=false; roller:hide()
    practice:update(nextState)
    if showTouch then showTouch(nextState.phase=="Playing",true) end
    if not settings.opened and (not previous or previous.phase~=nextState.phase)
        and game:GetService("UserInputService"):GetLastInputType().Name:sub(1,7)=="Gamepad" then
        game:GetService("GuiService").SelectedObject=settingsMenu.selectionOnClose()
    end
end)
Run.RenderStepped:Connect(function(dt) if snapshot then arena:draw(os.clock(),dt) end; hud:tick(); roller:tick(); practice:tick() end)
setMode(false)
