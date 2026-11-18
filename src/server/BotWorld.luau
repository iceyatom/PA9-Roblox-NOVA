-- Bot practice pad. Additive and placed relative to the existing pads, so a
-- hand-edited lobby keeps its layout.
local BotWorld={}
local blue=Color3.fromHex("248bff")
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
function BotWorld.ensure(lobby)
    local existing=lobby:FindFirstChild("BotPractice")
    if existing then return existing end
    -- Mirror High Score Practice across the queue pad, at the same floor height.
    local queue=lobby:FindFirstChild("QueuePad")
    local practice=lobby:FindFirstChild("PracticePad",true)
    local center=queue and queue.Position or Vector3.new(0,.58,-22)
    local other=practice and practice.Position or center+Vector3.new(44,0,0)
    local cf=CFrame.new(2*center.X-other.X,other.Y-.58,center.Z)
    local model=Instance.new("Model"); model.Name="BotPractice"; model:SetAttribute("NOVAOwned",true)
    local function disc(name,diameter,height,y,color,material)
        local p=part(model,name,Vector3.new(height,diameter,diameter),cf*CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2),color,material)
        p.Shape=Enum.PartType.Cylinder
        return p
    end
    disc("Base",23,1,.5,Color3.fromHex("232b3d"))
    disc("Rim",20,1.08,.54,blue,Enum.Material.Neon).CanCollide=false
    disc("BotPad",18,1.16,.58,Color3.fromHex("10223c"),Enum.Material.SmoothPlastic)
    local core=disc("Beacon",4,1.22,.61,blue,Enum.Material.Neon)
    core.CanCollide=false
    local glow=Instance.new("PointLight"); glow.Color=blue; glow.Brightness=1; glow.Range=24; glow.Parent=core
    for _,x in {-12,12} do
        part(model,"Pylon",Vector3.new(1.8,12,1.8),cf*CFrame.new(x,6,0),Color3.fromHex("232b3d"))
        local strip=part(model,"Signal",Vector3.new(.25,10,1.9),cf*CFrame.new(x-math.sign(x)*.8,6.5,0),blue,Enum.Material.Neon)
        strip.CanCollide=false; strip.Transparency=.4
    end
    local anchor=part(model,"BotSign",Vector3.one,cf*CFrame.new(0,12,0),blue)
    anchor.Transparency=1; anchor.CanCollide=false; anchor.CanQuery=false
    local sign=Instance.new("BillboardGui"); sign.Name="Sign"; sign.Size=UDim2.fromScale(25,6); sign.MaxDistance=200
    sign.LightInfluence=0; sign.Parent=anchor
    local card=Instance.new("Frame"); card.Size=UDim2.fromScale(1,1); card.BackgroundColor3=Color3.fromHex("111621")
    card.BackgroundTransparency=.08; card.BorderSizePixel=0; card.Parent=sign
    text(card,"Kicker","SOLO / XP BY DIFFICULTY",.08,.2,blue,28)
    local title=text(card,"Title","Bot Practice",.31,.35,white,64); title.Font=Enum.Font.GothamBlack
    text(card,"Hint","STEP INTO THE BEACON TO DUEL A BOT",.73,.17,muted,26)
    model.Parent=lobby
    return model
end
return BotWorld
