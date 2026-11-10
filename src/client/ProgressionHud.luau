local Players=game:GetService("Players")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage.NOVA
local P=require(shared.Progression)
local W=require(script.Parent.Widgets)
local C=W.colors
local RankIcon=require(script.Parent.RankIcon)
local Hud={}

local function nameplates()
    local function track(other)
        local connections={}
        local label,icon
        local function rank()
            if label then
                label.Text=other:GetAttribute("RankLabel") or "Loading rank…"
                label.TextColor3=other:GetAttribute("PrestigeMaster") and C.mint or C.purple
                local prestige=other:GetAttribute("Prestige")
                RankIcon.set(icon,prestige~=nil and {prestige=prestige,master=other:GetAttribute("PrestigeMaster")} or nil)
            end
        end
        local function character(model)
            local head=model:WaitForChild("Head",10)
            local humanoid=model:FindFirstChildOfClass("Humanoid")
            if not head or not model.Parent then return end
            if humanoid then humanoid.NameDisplayDistance=0 end
            local gui=Instance.new("BillboardGui")
            gui.Name="NOVARank"; gui.Adornee=head; gui.Size=UDim2.fromOffset(304,80)
            gui.StudsOffsetWorldSpace=Vector3.new(0,3,0)
            gui.MaxDistance=80; gui.AlwaysOnTop=false; gui.Parent=head
            local name=W.text(gui,"Name",0,0,304,26,other.DisplayName,18,C.white,Enum.Font.GothamBold)
            name.TextXAlignment=Enum.TextXAlignment.Center
            name.TextStrokeTransparency=.5
            local row=W.box(gui,"RankRow",0,27,304,48)
            local layout=Instance.new("UIListLayout")
            layout.FillDirection=Enum.FillDirection.Horizontal
            layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
            layout.VerticalAlignment=Enum.VerticalAlignment.Center
            layout.SortOrder=Enum.SortOrder.LayoutOrder
            layout.Padding=UDim.new(0,6)
            layout.Parent=row
            icon=RankIcon.new(row,"RankIcon",0,0,48)
            icon.LayoutOrder=1
            label=W.text(row,"Rank",0,0,0,24,"",13,C.purple,Enum.Font.GothamBold)
            label.LayoutOrder=2
            label.AutomaticSize=Enum.AutomaticSize.X
            label.TextStrokeTransparency=.4
            rank()
        end
        table.insert(connections,other.CharacterAdded:Connect(character))
        table.insert(connections,other:GetAttributeChangedSignal("RankLabel"):Connect(rank))
        table.insert(connections,other.AncestryChanged:Connect(function(_,parent)
            if not parent then for _,c in connections do c:Disconnect() end end
        end))
        if other.Character then task.spawn(character,other.Character) end
    end
    Players.PlayerAdded:Connect(track)
    for _,other in Players:GetPlayers() do track(other) end
end

function Hud.new(playerGui,clear,beforeOpen)
    nameplates()
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVAProgression"; gui.ResetOnSpawn=false; gui.DisplayOrder=6
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=playerGui
    local card=W.button(gui,"Card",16,16,220,72,"",false)
    card.BackgroundColor3=C.panel
    W.stroke(card,C.line)
    local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,10); corner.Parent=card
    local batch=require(script.Parent.BatchOneVisuals)
    local catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
    local function drawCard()
        local old=card:FindFirstChild("BatchArt")
        if old then old:Destroy() end
        local key=game.Players.LocalPlayer:GetAttribute("Cosmetic_backgrounds")
        batch.card(card,catalog.get({backgrounds=key},"backgrounds"))
    end
    game.Players.LocalPlayer:GetAttributeChangedSignal("Cosmetic_backgrounds"):Connect(drawCard)
    game.Players.LocalPlayer:GetAttributeChangedSignal("ReducedEffects"):Connect(drawCard)
    drawCard()
    local icon=RankIcon.new(card,"RankIcon",8,8,56)
    local number=W.text(card,"LevelNumber",76,6,128,34,"—",26,C.white,Enum.Font.GothamBlack)
    local track=W.box(card,"XPTrack",76,49,128,8,C.line)
    track.ZIndex=2
    local fill=W.box(track,"XPFill",0,0,0,8,C.purple)
    local Menu=require(script.Parent.ProgressionMenu)
    local menu=Menu.new(gui,card,clear,beforeOpen)
    local function refresh()
        local d=Menu.read()
        RankIcon.set(icon,d)
        number.Text=d and tostring(d.level) or "—"
        number.TextColor3=d and d.master and C.mint or C.white
        fill.Size=UDim2.fromScale(d and (d.level==P.cap(d) and 1 or d.xp/P.cost(d.level)) or 0,1)
        fill.BackgroundColor3=d and d.master and C.mint or C.purple
    end
    player.AttributeChanged:Connect(refresh)
    local stroke=card:FindFirstChildOfClass("UIStroke")
    card.MouseEnter:Connect(function() stroke.Color=C.purple end)
    card.MouseLeave:Connect(function() stroke.Color=C.line end)
    local scale=Instance.new("UIScale"); scale.Parent=card
    local function resize()
        local camera=workspace.CurrentCamera
        if camera then scale.Scale=math.min(1,math.max(.5,(camera.ViewportSize.X-32)/220)) end
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local camera=workspace.CurrentCamera
        if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
        resize()
    end)
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize(); refresh()
    return gui,menu
end

return Hud
