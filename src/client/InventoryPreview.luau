local W=require(script.Parent.Widgets)
local C=W.colors
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Art=require(game.ReplicatedStorage.NOVA.InventoryArt)
local Preview={}
local colors={}
function Preview.icon(parent,category,x,y,size)
    local image=Instance.new("ImageLabel")
    image.Name="Sprite"; image.BackgroundTransparency=1; image.Size=UDim2.fromOffset(size,size)
    image.Position=UDim2.fromOffset(x,y); image.Image=Art[category] or ""; image.ScaleType=Enum.ScaleType.Fit
    image.ZIndex=3; image.Parent=parent
    return image
end
function Preview.color(item)
    local hex=item and item.color or "527eff"
    if not colors[hex] then colors[hex]=W.rgb(hex) end
    return colors[hex]
end
function Preview.sound(parent,item)
    if not item.sound or item.sound=="" then return end
    local sound=Instance.new("Sound"); sound.Name="CosmeticShot"; sound.SoundId=item.sound
    sound.PlaybackSpeed=item.pitch or 1; sound.Volume=.22; sound.Parent=parent
    sound.Ended:Once(function() sound:Destroy() end)
    game:GetService("Debris"):AddItem(sound,3); sound:Play()
end
function Preview.draw(parent,item,equipped)
    for _,child in parent:GetChildren() do child:Destroy() end
    if not item then return end
    local w,h=parent.Size.X.Offset,parent.Size.Y.Offset
    local color=Preview.color(item)
    if item.category=="skins" then
        local body=W.box(parent,"BodyPreview",w/2-25,h/2-25,50,50,color); W.stroke(body,C.white,2)
        W.box(body,"Highlight",6,6,38,5,C.white).BackgroundTransparency=.65
    elseif item.category=="bullets" or item.category=="tracers" then
        local bullet=Catalog.get(equipped,"bullets")
        local tracer=item.category=="tracers" and item or Catalog.get(equipped,"tracers")
        local line=W.box(parent,"TracerPreview",w/2-95,h/2-3,90,6,Preview.color(tracer)); line.Visible=(tracer.length or 0)>0
        local core=W.box(parent,"BulletPreview",w/2-8,h/2-8,16,16,item.category=="bullets" and color or Preview.color(bullet)); W.round(core)
    elseif item.category=="backgrounds" then
        local card=W.box(parent,"PlayerCardPreview",20,h/2-40,w-40,80,color)
        card.BackgroundColor3=Color3.new(1,1,1)
        local grad=Instance.new("UIGradient"); grad.Color=ColorSequence.new(color,C.ink); grad.Rotation=25; grad.Parent=card
        local avatar=Instance.new("ImageLabel"); avatar.BackgroundTransparency=1; avatar.Size=UDim2.fromOffset(52,52); avatar.Position=UDim2.fromOffset(12,14); avatar.Parent=card
        require(script.Parent.Portrait).set(avatar,game.Players.LocalPlayer.UserId)
        W.text(card,"Name",76,15,w-126,25,game.Players.LocalPlayer.DisplayName,16,C.white,Enum.Font.GothamBold)
        W.text(card,"Label",76,42,w-126,20,"PLAYER CARD",11,C.white)
    else Preview.icon(parent,item.category,w/2-60,h/2-60,120) end
end
return Preview
