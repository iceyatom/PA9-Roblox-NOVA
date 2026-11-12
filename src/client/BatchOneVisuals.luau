local Assets=require(game.ReplicatedStorage.NOVA.BatchOneAssets)
local Skins=require(game.ReplicatedStorage.NOVA.SkinVisuals)
local Prism=require(game.ReplicatedStorage.NOVA.PrismVisuals)
local Visuals={}
function Visuals.reduced()
    return game.Players.LocalPlayer:GetAttribute("ReducedEffects")==true
end
function Visuals.apply(label,item,kind,frame)
    if Prism.apply(label,item,kind) then return true end
    Prism.clear(label)
    if item.category=="skins" and (kind==nil or kind=="skins" or kind=="body") then return Skins.apply(label,item) end
    local index=item.artIndex
    if item.image then label.Image=item.image;label.ImageRectSize=Vector2.zero;label.ImageRectOffset=Vector2.zero;label.ImageColor3=Color3.new(1,1,1);return true end
    if index==nil then return false end
    kind=kind or item.category
    local w,h=256,256
    if kind=="body" then w,h=128,128 end
    if kind=="card" then w,h=512,256 end
    if kind=="wakes" then w,h=512,512 end
    local cols=1024/w
    local count=cols*(1024/h)
    local x,y=(index%cols)*w,math.floor(index%count/cols)*h
    label.Image=Assets[kind.."-"..(math.floor(index/count)+1)]
    if kind=="wakes" then
        frame=frame or 0
        x+=frame%4*128+14; y+=math.floor(frame/4)*128+49; w,h=98,30
    end
    label.ImageRectSize=Vector2.new(w,h)
    label.ImageRectOffset=Vector2.new(x,y)
    return true
end
function Visuals.overlay(parent,item,kind)
    local image=parent:FindFirstChild("BatchArt")
    if not item.setId and item.visual~="prism_veil" and item.visual~="dragonforge" and item.visual~="riftglass" and item.visual~="cipher" and item.visual~="supernova" and item.visual~="starfade" and item.visual~="armory" then
        if image then image:Destroy() end
        return
    end
    if image and image:GetAttribute("Item")==item.id then return image end
    if not image then
        image=Instance.new("ImageLabel"); image.Name="BatchArt"
        image.BackgroundTransparency=1; image.Size=UDim2.fromScale(1,1)
        image.ZIndex=parent.ZIndex; image.Parent=parent
    end
    image:SetAttribute("Item",item.id)
    Visuals.apply(image,item,kind=="skins" and "body" or kind)
    if kind=="bullets" and item.setId then
        image.ImageRectOffset+=Vector2.new(35,35);image.ImageRectSize=Vector2.new(186,186)
    end
    return image
end
-- Motion is confined to an image in a lobby/detail card. Destroying the
-- image also cancels its local tween when the preview changes.
function Visuals.card(parent,item)
    local image=Visuals.overlay(parent,item,"card")
    if not image then return end
    image.ZIndex=1
    if (item.visual=="prism_veil" or item.visual=="dragonforge" or item.visual=="riftglass" or item.visual=="cipher" or item.visual=="supernova" or item.visual=="starfade" or item.visual=="armory") then return end
    if Visuals.reduced() or (item.rarity~="Epic" and item.rarity~="Legendary" and item.rarity~="Cosmic") then return end
    local sweep=Instance.new("UIGradient")
    local tint=Color3.fromRGB(160,170,190)
    sweep.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,tint),ColorSequenceKeypoint.new(.5,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,tint)})
    sweep.Offset=Vector2.new(-.5,0); sweep.Rotation=15; sweep.Parent=image
    local tween=game:GetService("TweenService"):Create(sweep,TweenInfo.new(5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Offset=Vector2.new(.5,0)})
    tween:Play()
    image.Destroying:Once(function() tween:Cancel() end)
end
Visuals.clear=Prism.clear
Visuals.preload=Prism.preload
return Visuals
