-- The square combat skin is also its inventory/editor/reveal icon.
local Assets=require(script.Parent.BatchOneAssets)
local Prism=require(script.Parent.PrismVisuals)
local Skins={}
function Skins.apply(image,item)
    if type(item)~="table" or item.category~="skins" then return false end
    if Prism.apply(image,item) then return true end
    image.Image=""; image.ImageRectSize=Vector2.zero; image.ImageRectOffset=Vector2.zero
    image.BackgroundColor3=Color3.fromHex(item.color or "527eff")
    image.BackgroundTransparency=item.artIndex==nil and 0 or 1
    image:SetAttribute("SquareSkin",true)
    image:SetAttribute("SolidSkin",item.artIndex==nil)
    if item.artIndex~=nil then
        -- Each square in the gameplay atlas occupies 128px in an 8-column sheet.
        local index=item.artIndex
        image.Image=Assets["body-"..(math.floor(index/64)+1)]
        image.ImageRectSize=Vector2.new(128,128)
        image.ImageRectOffset=Vector2.new(index%8*128,math.floor(index%64/8)*128)
    end
    return true
end
return Skins
