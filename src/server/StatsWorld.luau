-- Position relative to the existing practice board so hand-moved lobbies work.
local Stats=require(game.ReplicatedStorage.NOVA.Stats)
local World={}
local function text(parent,name,value,x,y,w,h,color,size,font)
    local label=Instance.new("TextLabel");label.Name=name;label.Text=value
    label.Position=UDim2.fromScale(x,y);label.Size=UDim2.fromScale(w,h);label.BackgroundTransparency=1
    label.Font=font or Enum.Font.GothamBold;label.TextColor3=color;label.TextScaled=true
    label.TextXAlignment=Enum.TextXAlignment.Left;label.TextTruncate=Enum.TextTruncate.AtEnd;label.Parent=parent
    local limit=Instance.new("UITextSizeConstraint");limit.MaxTextSize=size;limit.Parent=label
    return label
end
function World.ensure(lobby,practiceBoard)
    local folder=lobby:FindFirstChild("StatsLeaderboards")
    if not folder then folder=Instance.new("Model");folder.Name="StatsLeaderboards";folder:SetAttribute("NOVAOwned",true);folder.Parent=lobby end
    local migrate=folder:GetAttribute("WallLayoutVersion")~=1
    if practiceBoard:GetAttribute("WallLayoutVersion")~=1 then
        -- Move the trimmed practice board toward the corner, leaving room for
        -- Matches Played on its right. The marker prevents movement on rejoin.
        practiceBoard.CFrame*=CFrame.new(-16,0,0)
        practiceBoard.Size=Vector3.new(20,practiceBoard.Size.Y,practiceBoard.Size.Z)
        practiceBoard.Rankings.CanvasSize=Vector2.new(900,700)
        practiceBoard:SetAttribute("WallLayoutVersion",1)
        migrate=true
    end
    local boards={}
    for _,metric in Stats.boards do
        local board=folder:FindFirstChild(metric.id)
        if not board then
            local accent=Color3.fromHex(metric.color);local white=Color3.fromHex("edf2ff");local muted=Color3.fromHex("aab6ca")
            board=Instance.new("Part");board.Name=metric.id;board.Anchored=true;board.CanCollide=false
            board.Size=Vector3.new(20,14,.5);board.CFrame=practiceBoard.CFrame*CFrame.new(metric.offset,0,0)
            board.Color=Color3.fromHex("111621");board.Material=Enum.Material.SmoothPlastic;board:SetAttribute("NOVAOwned",true)
            local gui=Instance.new("SurfaceGui");gui.Name="Rankings";gui.Face=Enum.NormalId.Back
            gui.CanvasSize=Vector2.new(900,700);gui.LightInfluence=0;gui.Parent=board
            text(gui,"Kicker","NOVA / CAREER LEADERBOARD",.05,.035,.9,.045,accent,28)
            text(gui,"Title",metric.name:upper(),.05,.095,.9,.09,white,52,Enum.Font.GothamBlack)
            text(gui,"Columns","RANK       PLAYER                          TOTAL",.05,.21,.9,.04,muted,24)
            for i=1,10 do
                local row=Instance.new("Frame");row.Name="Row"..i;row.BackgroundTransparency=1
                row.Position=UDim2.fromScale(.04,.28+(i-1)*.057);row.Size=UDim2.fromScale(.92,.048);row.Parent=gui
                local color=i<=3 and accent or white
                text(row,"Rank",("%02d"):format(i),0,0,.12,1,color,30)
                text(row,"PlayerName","—",.14,0,.57,1,color,30)
                local score=text(row,"Score","—",.72,0,.28,1,color,30);score.TextXAlignment=Enum.TextXAlignment.Right
            end
            text(gui,"Status","LOADING GLOBAL SCORES…",.05,.89,.9,.04,muted,22)
            text(gui,"Rule","ALL TIME / VERIFIED CAREER TOTALS",.05,.945,.9,.03,accent,20)
            board.Parent=folder
        elseif migrate and board:GetAttribute("NOVAOwned") then
            board.CFrame=practiceBoard.CFrame*CFrame.new(metric.offset,0,0)
        end
        boards[metric.id]=board
    end
    folder:SetAttribute("WallLayoutVersion",1)
    return boards
end
return World
