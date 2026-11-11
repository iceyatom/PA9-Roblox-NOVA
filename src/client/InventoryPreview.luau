local W=require(script.Parent.Widgets)
local C=W.colors
local Catalog=require(game.ReplicatedStorage.NOVA.InventoryCatalog)
local Art=require(game.ReplicatedStorage.NOVA.InventoryArt)
local Batch=require(script.Parent.BatchOneVisuals)
local Assets=require(game.ReplicatedStorage.NOVA.BatchOneAssets)
local Skins=require(game.ReplicatedStorage.NOVA.SkinVisuals)
local voices={}
local Preview={}
local colors={}
function Preview.icon(parent,category,x,y,size)
    local image=Instance.new("ImageLabel")
    image.Name="Sprite"; image.BackgroundTransparency=1; image.Size=UDim2.fromOffset(size,size)
    image.Position=UDim2.fromOffset(x,y)
    if type(category)=="table" then
        if not Batch.apply(image,category) then image.Image=Art[category.category] or "" end
    elseif category=="skins" then Skins.apply(image,{category="skins",color="527eff"})
    else image.Image=Art[category] or "" end
    image.ScaleType=Enum.ScaleType.Fit
    image.ZIndex=3; image.Parent=parent
    return image
end
function Preview.color(item)
    local hex=item and item.color or "527eff"
    if not colors[hex] then colors[hex]=W.rgb(hex) end
    return colors[hex]
end
function Preview.stopSounds(parent)
    for i=#voices,1,-1 do
        local voice=voices[i]
        if not voice.Parent or voice.Parent==parent then
            voice:Destroy()
            table.remove(voices,i)
        end
    end
end
function Preview.sound(parent,item)
    if not item.setId and (not item.sound or item.sound=="") then return end
    for i=#voices,1,-1 do if not voices[i].Parent then table.remove(voices,i) end end
    if #voices>=8 then table.remove(voices,1):Destroy() end
    local sound=Instance.new("Sound"); sound.Name="CosmeticShot"; sound.SoundId=item.setId and Assets.audio or item.sound
    if item.setId then
        sound.PlaybackRegionsEnabled=true; sound.PlaybackRegion=NumberRange.new(item.artIndex,item.artIndex+.39)
        sound.TimePosition=item.artIndex
    end
    table.insert(voices,sound)
    sound.PlaybackSpeed=item.pitch or 1; sound.Volume=.22; sound.Parent=parent
    sound.Ended:Once(function() sound:Destroy() end)
    game:GetService("Debris"):AddItem(sound,3); sound:Play()
end
function Preview.draw(parent,item,equipped,focused)
    for _,child in parent:GetChildren() do child:Destroy() end
    if not item then return end
    local w,h=parent.Size.X.Offset,parent.Size.Y.Offset
    local color=Preview.color(item)
    if item.category=="skins" then
        local body=W.box(parent,"BodyPreview",w/2-(focused and 62 or 25),h/2-(focused and 62 or 25),focused and 124 or 50,focused and 124 or 50,color)
        Batch.overlay(body,item,"skins")
    elseif item.category=="bullets" or item.category=="tracers" then
        local tracer=item.category=="tracers" and item or Catalog.get(equipped,"tracers")
        local diameter=focused and 40 or 16
        local hasTrail=(tracer.length or 0)>0
        local length=hasTrail and math.min(focused and 300 or 90,w*.58) or 0
        local tracerOnly=item.category=="tracers"
        -- Tracer previews show just the centered effect, without a projectile.
        local headX=tracerOnly and (w+length)/2 or hasTrail and (w+length-diameter/2)/2 or w/2
        local thickness=focused and 24 or 6
        local line=W.box(parent,"TracerPreview",headX-length,h/2-thickness/2,length,thickness,Preview.color(tracer),1); line.Visible=hasTrail
        if not tracerOnly then
            local core=W.box(parent,"BulletPreview",headX-diameter/2,h/2-diameter/2,diameter,diameter,color,3); W.round(core)
            Batch.overlay(core,item,"bullets")
        end
        if (tracer.setId or (tracer.visual=="prism_veil" or tracer.visual=="dragonforge" or tracer.visual=="riftglass" or tracer.visual=="cipher" or tracer.visual=="supernova" or tracer.visual=="starfade" or tracer.visual=="armory")) and not Batch.reduced() then line.BackgroundTransparency=1;Batch.overlay(line,tracer,"wakes") end
    elseif item.category=="backgrounds" then
        local card=W.box(parent,"PlayerCardPreview",20,h/2-40,w-40,80,color)
        card.BackgroundColor3=Color3.new(1,1,1)
        local grad=Instance.new("UIGradient"); grad.Color=ColorSequence.new(color,C.ink); grad.Rotation=25; grad.Parent=card
        Batch.card(card,item)
        local avatar=Instance.new("ImageLabel"); avatar.BackgroundTransparency=1; avatar.Size=UDim2.fromOffset(52,52); avatar.Position=UDim2.fromOffset(12,14); avatar.Parent=card
        require(script.Parent.Portrait).set(avatar,game.Players.LocalPlayer.UserId)
        W.text(card,"Name",76,15,w-126,25,game.Players.LocalPlayer.DisplayName,16,C.white,Enum.Font.GothamBold)
        W.text(card,"Label",76,42,w-126,20,"PLAYER CARD",11,C.white)
    else Preview.icon(parent,item,w/2-60,h/2-60,120) end
end
return Preview
