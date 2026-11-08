-- Builds the walkable 3D lobby and its night lighting. An existing Workspace.NOVALobby is reused,
-- so the version placed in Studio can be edited by hand without the server rebuilding it.
local Lighting=game:GetService("Lighting")
local LobbyWorld={}

local rgb=Color3.fromHex
local C={ink=rgb("080b13"),floor=rgb("1a2130"),panel=rgb("232b3d"),wall=rgb("1e2536"),line=rgb("303747"),muted=rgb("9ca8bc"),
    white=rgb("edf2ff"),lime=rgb("b9f770"),purple=rgb("793dff"),blue=rgb("527eff"),red=rgb("ff5859"),padCore=rgb("162210")}
LobbyWorld.colors=C
LobbyWorld.PadRadius=11

local function part(parent,name,size,cframe,color,material,shape)
    local p=Instance.new("Part")
    p.Name=name
    p.Anchored=true
    p.Size=size
    p.CFrame=cframe
    p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic
    p.TopSurface=Enum.SurfaceType.Smooth
    p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    p.Parent=parent
    return p
end
local function neon(parent,name,size,cframe,color)
    local p=part(parent,name,size,cframe,color,Enum.Material.Neon)
    p.CanCollide=false
    p.CastShadow=false
    -- Partly transparent neon reads as a soft strip instead of a hard glow.
    p.Transparency=0.45
    return p
end
local function light(parent,color,range,brightness)
    local l=Instance.new("PointLight")
    l.Color=color
    l.Range=range
    l.Brightness=brightness*0.5
    l.Shadows=false
    l.Parent=parent
end
-- Cylinders lie along X, so turn them upright.
local function disc(parent,name,diameter,height,y,z,color,material)
    return part(parent,name,Vector3.new(height,diameter,diameter),CFrame.new(0,y,z)*CFrame.Angles(0,0,math.rad(90)),color,material,Enum.PartType.Cylinder)
end
local function label(parent,name,text,y,h,size,color,font)
    local t=Instance.new("TextLabel")
    t.Name=name
    t.BackgroundTransparency=1
    t.Position=UDim2.fromScale(0,y)
    t.Size=UDim2.fromScale(1,h)
    t.Text=text
    t.TextScaled=true
    t.Font=font or Enum.Font.GothamBold
    t.TextColor3=color
    t.Parent=parent
    local limit=Instance.new("UITextSizeConstraint")
    limit.MaxTextSize=size
    limit.Parent=t
    return t
end

local function lighting()
    Lighting.ClockTime=0
    Lighting.Brightness=2
    Lighting.Ambient=Color3.fromRGB(62,66,96)
    Lighting.OutdoorAmbient=Color3.fromRGB(78,82,118)
    Lighting.EnvironmentDiffuseScale=0.25
    Lighting.EnvironmentSpecularScale=0.6
    local function effect(class,name,props)
        local e=Lighting:FindFirstChild(name)
        if not e then
            e=Instance.new(class)
            e.Name=name
            e:SetAttribute("NOVAOwned",true)
            e.Parent=Lighting
        end
        if e:GetAttribute("NOVAOwned") then
            for k,v in props do e[k]=v end
        end
    end
    effect("Atmosphere","NOVAAtmosphere",{Density=0.22,Offset=0,Color=rgb("231c40"),Decay=rgb("0c0f1c"),Glare=0,Haze=0.4})
    effect("BloomEffect","NOVABloom",{Intensity=0.15,Size=12,Threshold=2.2})
    effect("ColorCorrectionEffect","NOVAGrade",{Contrast=0.08,Saturation=0.08,TintColor=rgb("eef0ff")})
end

local function build()
    local lobby=Instance.new("Model")
    lobby.Name="NOVALobby"
    lobby:SetAttribute("NOVAOwned",true)
    local size,height=140,14
    -- Floor top sits just above y=0 so a default baseplate below never z-fights.
    part(lobby,"Floor",Vector3.new(size,2,size),CFrame.new(0,-0.95,0),C.floor,Enum.Material.Concrete)
    local grid=Instance.new("Folder")
    grid.Name="Grid"
    grid.Parent=lobby
    for i=-4,4 do
        local o=i*14
        part(grid,"GridX",Vector3.new(size,0.04,0.18),CFrame.new(0,0.07,o),C.line).CanCollide=false
        part(grid,"GridZ",Vector3.new(0.18,0.04,size),CFrame.new(o,0.07,0),C.line).CanCollide=false
    end
    -- Perimeter walls with a purple light strip on the inner face.
    local walls=Instance.new("Folder")
    walls.Name="Walls"
    walls.Parent=lobby
    local half=size/2
    for _,w in {{0,-half,size,2},{0,half,size,2},{-half,0,2,size},{half,0,2,size}} do
        part(walls,"Wall",Vector3.new(w[3],height,w[4]),CFrame.new(w[1],height/2,w[2]),C.wall,Enum.Material.Metal)
        local inset=Vector3.new(w[1]==0 and 0 or -math.sign(w[1])*1.05,0,w[2]==0 and 0 or -math.sign(w[2])*1.05)
        neon(walls,"Trim",Vector3.new(w[3]==2 and 0.2 or size-4,0.35,w[4]==2 and 0.2 or size-4),CFrame.new(Vector3.new(w[1],height-1.2,w[2])+inset),C.purple)
        neon(walls,"Baseboard",Vector3.new(w[3]==2 and 0.2 or size-4,0.15,w[4]==2 and 0.2 or size-4),CFrame.new(Vector3.new(w[1],0.6,w[2])+inset),C.line)
    end
    -- Corner pylons.
    for _,x in {-1,1} do
        for _,z in {-1,1} do
            local base=CFrame.new(x*(half-6),0,z*(half-6))
            part(lobby,"Pylon",Vector3.new(3,18,3),base*CFrame.new(0,9,0),C.panel,Enum.Material.Metal)
            local cap=neon(lobby,"PylonCap",Vector3.new(3.4,0.6,3.4),base*CFrame.new(0,17,0),C.purple)
            light(cap,C.purple,28,1.6)
        end
    end
    -- Spawn deck.
    local deckZ=44
    part(lobby,"SpawnDeck",Vector3.new(26,1,18),CFrame.new(0,0.5,deckZ),C.panel,Enum.Material.Metal)
    for _,s in {-1,1} do
        neon(lobby,"DeckEdge",Vector3.new(26.2,0.2,0.3),CFrame.new(0,1.02,deckZ+s*9),C.lime)
        neon(lobby,"DeckEdge",Vector3.new(0.3,0.2,18.2),CFrame.new(s*13,1.02,deckZ),C.lime)
    end
    local spawn=Instance.new("SpawnLocation")
    spawn.Name="LobbySpawn"
    spawn.Anchored=true
    spawn.Size=Vector3.new(10,0.4,10)
    spawn.CFrame=CFrame.new(0,1.2,deckZ)*CFrame.Angles(0,0,0)
    spawn.Color=C.ink
    spawn.Material=Enum.Material.SmoothPlastic
    spawn.TopSurface=Enum.SurfaceType.Smooth
    spawn.Neutral=true
    spawn.Duration=0
    spawn.Parent=lobby
    neon(lobby,"SpawnRing",Vector3.new(10.4,0.1,10.4),CFrame.new(0,1.05,deckZ),C.line)
    -- Lime chevrons lead from the deck to the queue pad.
    for i=0,4 do
        local z=deckZ-14-i*5.5
        for _,s in {-1,1} do
            neon(lobby,"Chevron",Vector3.new(3.2,0.08,0.5),CFrame.new(s*1.05,0.1,z)*CFrame.Angles(0,s*math.rad(-40),0),C.lime).Transparency=0.45+i*0.08
        end
    end
    -- Queue pad.
    local padZ=-22
    disc(lobby,"PadBase",28,1,0.5,padZ,C.panel,Enum.Material.Metal)
    disc(lobby,"PadRing",LobbyWorld.PadRadius*2+1.2,1.08,0.54,padZ,C.lime,Enum.Material.Neon).CanCollide=false
    local pad=disc(lobby,"QueuePad",LobbyWorld.PadRadius*2,1.16,0.58,padZ,C.padCore,Enum.Material.SmoothPlastic)
    disc(lobby,"PadCore",6,1.2,0.6,padZ,C.lime,Enum.Material.Neon).CanCollide=false
    light(pad,C.lime,26,2.2)
    -- Rival pylons: blue for player one, red for player two.
    for i,x in {-17,17} do
        local col=i==1 and C.blue or C.red
        part(lobby,"RivalPylon",Vector3.new(2.4,16,2.4),CFrame.new(x,8,padZ),C.panel,Enum.Material.Metal)
        local strip=neon(lobby,"RivalStrip",Vector3.new(0.4,13,2.5),CFrame.new(x-math.sign(x)*1.05,8.5,padZ),col)
        light(strip,col,24,2)
    end
    -- Floating sign above the pad.
    local anchor=part(lobby,"QueueSign",Vector3.new(1,1,1),CFrame.new(0,13,padZ),C.ink)
    anchor.Transparency=1
    anchor.CanCollide=false
    anchor.CanQuery=false
    local board=Instance.new("BillboardGui")
    board.Name="Billboard"
    board.Size=UDim2.fromScale(22,8)
    board.LightInfluence=0
    board.MaxDistance=220
    board.Parent=anchor
    local card=Instance.new("Frame")
    card.Name="Card"
    card.Size=UDim2.fromScale(1,1)
    card.BackgroundColor3=C.panel
    card.BackgroundTransparency=0.12
    card.BorderSizePixel=0
    card.Parent=board
    local stroke=Instance.new("UIStroke")
    stroke.Color=C.line
    stroke.Thickness=2
    stroke.Parent=card
    local accent=Instance.new("Frame")
    accent.Name="Signal"
    accent.Size=UDim2.new(0,6,1,0)
    accent.BackgroundColor3=C.lime
    accent.BorderSizePixel=0
    accent.Parent=card
    label(card,"Kicker","MAP 01  /  SPLIT CIRCUIT",0.08,0.18,28,C.lime,Enum.Font.Code)
    label(card,"Title","1V1 DUEL",0.26,0.38,80,C.white,Enum.Font.GothamBlack)
    label(card,"Status","STEP ON THE PAD TO QUEUE",0.68,0.2,30,C.muted)
    -- Back-wall wordmark.
    local plate=part(lobby,"Wordmark",Vector3.new(48,10,0.4),CFrame.new(0,8,-half+1.25),C.ink)
    plate.CanCollide=false
    local surface=Instance.new("SurfaceGui")
    surface.Name="Sign"
    surface.Face=Enum.NormalId.Back
    surface.LightInfluence=0
    surface.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud=40
    surface.Parent=plate
    label(surface,"Wordmark","NOVA",0.04,0.66,400,C.white,Enum.Font.GothamBlack)
    label(surface,"Mode","PLATFORM DUEL",0.72,0.22,110,C.lime,Enum.Font.Code)
    neon(lobby,"WordmarkRule",Vector3.new(40,0.25,0.2),CFrame.new(0,2.6,-half+1.05),C.lime)
    return lobby
end

function LobbyWorld.ensure()
    lighting()
    local lobby=workspace:FindFirstChild("NOVALobby")
    if not lobby then
        lobby=build()
        lobby.Parent=workspace
    end
    return lobby
end

-- True when a character's root stands over the queue pad.
function LobbyWorld.onPad(lobby,character)
    local pad=lobby:FindFirstChild("QueuePad")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not (pad and root and humanoid and humanoid.Health>0) then return false end
    local offset=root.Position-pad.Position
    return Vector2.new(offset.X,offset.Z).Magnitude<=LobbyWorld.PadRadius and offset.Y>-1 and offset.Y<10
end
return LobbyWorld
