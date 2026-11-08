-- Additive so existing hand-edited lobby scenery is preserved.
local PracticeWorld={}
local mint=Color3.fromHex("50e4ac")
local white=Color3.fromHex("edf2ff")
local muted=Color3.fromHex("9ca8bc")
local function part(parent,name,size,cf,color,material)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.CFrame=cf; p.Color=color
    p.Anchored=true; p.Material=material or Enum.Material.Metal
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=parent
    return p
end
local function text(parent,name,value,y,height,color,maxSize)
    local t=Instance.new("TextLabel")
    t.Name=name; t.Text=value; t.Size=UDim2.fromScale(.9,height); t.Position=UDim2.fromScale(.05,y)
    t.BackgroundTransparency=1; t.TextColor3=color; t.Font=Enum.Font.Code; t.TextScaled=true
    t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=parent
    local limit=Instance.new("UITextSizeConstraint"); limit.MaxTextSize=maxSize or 42; limit.Parent=t
    return t
end
function PracticeWorld.ensure(lobby)
    local existing=lobby:FindFirstChild("HighScorePractice")
    if existing then return existing end
    local model=Instance.new("Model"); model.Name="HighScorePractice"; model:SetAttribute("NOVAOwned",true)
    local cf=CFrame.new(44,0,-22)
    local function disc(name,diameter,height,y,color,material)
        local p=part(model,name,Vector3.new(height,diameter,diameter),cf*CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2),color,material)
        p.Shape=Enum.PartType.Cylinder
        return p
    end
    disc("Base",23,1,.5,Color3.fromHex("232b3d"))
    disc("Rim",20,1.08,.54,mint,Enum.Material.Neon).CanCollide=false
    disc("PracticePad",18,1.16,.58,Color3.fromHex("102c29"),Enum.Material.SmoothPlastic)
    local core=disc("Beacon",4,1.22,.61,mint,Enum.Material.Neon)
    core.CanCollide=false
    local glow=Instance.new("PointLight"); glow.Color=mint; glow.Brightness=1; glow.Range=24; glow.Parent=core
    for _,x in {-12,12} do
        part(model,"Pylon",Vector3.new(1.8,12,1.8),cf*CFrame.new(x,6,0),Color3.fromHex("232b3d"))
        local strip=part(model,"Signal",Vector3.new(.25,10,1.9),cf*CFrame.new(x-math.sign(x)*.8,6.5,0),mint,Enum.Material.Neon)
        strip.CanCollide=false; strip.Transparency=.4
    end
    local anchor=part(model,"PracticeSign",Vector3.one,cf*CFrame.new(0,12,0),mint)
    anchor.Transparency=1; anchor.CanCollide=false; anchor.CanQuery=false
    local sign=Instance.new("BillboardGui"); sign.Name="Sign"; sign.Size=UDim2.fromScale(25,6); sign.MaxDistance=200
    sign.LightInfluence=0; sign.Parent=anchor
    local card=Instance.new("Frame"); card.Size=UDim2.fromScale(1,1); card.BackgroundColor3=Color3.fromHex("111621")
    card.BackgroundTransparency=.08; card.BorderSizePixel=0; card.Parent=sign
    text(card,"Kicker","SOLO / 30 SECOND CHALLENGE",.08,.2,mint,28)
    local title=text(card,"Title","High Score Practice",.31,.35,white,64); title.Font=Enum.Font.GothamBlack
    text(card,"Hint","STEP INTO THE BEACON TO PLAY",.73,.17,muted,26)
    local board=part(model,"Leaderboard",Vector3.new(36,14,.5),CFrame.new(68.6,8,-22)*CFrame.Angles(0,-math.pi/2,0),Color3.fromHex("111621"))
    board.CanCollide=false
    local rankings=Instance.new("SurfaceGui"); rankings.Name="Rankings"; rankings.Face=Enum.NormalId.Back
    rankings.CanvasSize=Vector2.new(1200,700); rankings.LightInfluence=0; rankings.Parent=board
    text(rankings,"Kicker","NOVA / HIGH SCORE PRACTICE",.035,.045,mint,30)
    local heading=text(rankings,"Title","GLOBAL TOP 10",.09,.09,white,60); heading.Font=Enum.Font.GothamBlack
    text(rankings,"Columns","RANK   PLAYER                 SHOTS / 30s",.21,.04,muted,27)
    for i=1,10 do text(rankings,"Row"..i,("%02d   —"):format(i),.28+(i-1)*.057,.048,i<=3 and mint or white,32) end
    text(rankings,"Status","LOADING GLOBAL SCORES…",.89,.04,muted,24)
    text(rankings,"Rule","BEST COMPLETED RUN PER PLAYER",.945,.03,mint,21)
    model.Parent=lobby
    return model
end
return PracticeWorld
