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

function Hud.new(playerGui)
    nameplates()
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVAProgression"; gui.ResetOnSpawn=false; gui.DisplayOrder=6; gui.Parent=playerGui
    local card=W.box(gui,"Card",16,16,340,182,C.panel)
    W.stroke(card,C.line)
    local icon=RankIcon.new(card,"RankIcon",12,7,56)
    local rank=W.text(card,"Rank",78,9,246,28,"Loading progression…",18,C.white,Enum.Font.GothamBold)
    local detail=W.text(card,"Progress",78,40,246,20,"",12,C.muted)
    local track=W.box(card,"XPTrack",16,69,308,6,C.line)
    local fill=W.box(track,"XPFill",0,0,0,6,C.purple)
    local button=W.button(card,"Prestige",16,88,308,32,"Reach level 55 to prestige",false)
    local hint=W.text(card,"Hint",16,124,308,20,"Win +300 XP / Complete +100 XP",12,C.muted)
    hint.Text=("Win +%d XP / Loss or draw +%d XP"):format(P.WinXP,P.PlayXP)
    local status=W.text(card,"SaveStatus",16,147,308,25,"",11,C.muted)
    status.TextWrapped=true
    local armed,busy=false,false
    local function data()
        if player:GetAttribute("Level")==nil or player:GetAttribute("Prestige")==nil
            or player:GetAttribute("PrestigeMaster")==nil then return nil end
        return {level=player:GetAttribute("Level"),prestige=player:GetAttribute("Prestige"),
            master=player:GetAttribute("PrestigeMaster"),xp=player:GetAttribute("XP") or 0}
    end
    local function refresh()
        local d=data()
        RankIcon.set(icon,d)
        local ready=player:GetAttribute("ProgressionReady")==true
        rank.Text=P.label(d)
        rank.TextColor3=d and d.master and C.mint or C.white
        status.Text=player:GetAttribute("ProgressionStatus") or "Loading progression…"
        local eligible=d~=nil and P.canPrestige(d) and ready
        button.Active=eligible and not busy
        button.Selectable=button.Active
        button.AutoButtonColor=button.Active
        button.BackgroundColor3=eligible and C.purple or C.line
        button.Text=busy and "Prestiging…" or not ready and "Waiting for progression…"
            or (d and d.master) and "Prestige Master" or eligible and (armed and "Confirm prestige" or d.prestige==P.MaxPrestige and "Become Prestige Master" or "Prestige → Level 1")
            or "Reach level 55 to prestige"
        if not d then return end
        local capped=d.level==P.cap(d)
        fill.Size=UDim2.new(capped and 1 or d.xp/P.cost(d.level),0,1,0)
        fill.BackgroundColor3=d.master and C.mint or C.purple
        detail.Text=armed and (d.prestige==P.MaxPrestige and "Keep level 55. Continue to level 1,000." or "Reset level and XP. Keep lifetime XP.")
            or capped and (d.master and "MAX LEVEL / 1,000" or "Level cap reached / Prestige available")
            or ("%d / %d XP → Level %d"):format(d.xp,P.cost(d.level),d.level+1)
    end
    button.Activated:Connect(function()
        local d=data()
        if busy or not d or not P.canPrestige(d) or not player:GetAttribute("ProgressionReady") then return end
        if not armed then armed=true; refresh(); return end
        busy=true; refresh()
        local ok,message=pcall(function() return shared:WaitForChild("Prestige"):InvokeServer() end)
        armed,busy=false,false
        refresh()
        status.Text=ok and message or "Prestige unavailable. Please try again."
    end)
    player.AttributeChanged:Connect(refresh)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function() armed=false; refresh() end)
    local scale=Instance.new("UIScale"); scale.Parent=card
    local function resize()
        local camera=workspace.CurrentCamera
        if camera then scale.Scale=math.min(1,math.max(.5,(camera.ViewportSize.X-32)/340)) end
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local camera=workspace.CurrentCamera
        if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
        resize()
    end)
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize(); refresh()
    return gui
end

return Hud
