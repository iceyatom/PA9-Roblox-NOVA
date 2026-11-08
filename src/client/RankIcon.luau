local Catalog=require(game.ReplicatedStorage.NOVA.RankIcons)
local RankIcon={}

function RankIcon.new(parent,name,x,y,size)
    local image=Instance.new("ImageLabel")
    image.Name=name
    image.BackgroundTransparency=1
    image.BorderSizePixel=0
    image.Position=UDim2.fromOffset(x,y)
    image.Size=UDim2.fromOffset(size,size)
    image.ScaleType=Enum.ScaleType.Fit
    image.ZIndex=3
    image.Visible=false
    image.Parent=parent
    return image
end

function RankIcon.set(image,data)
    local entry=Catalog.get(data)
    image.Visible=entry~=nil
    -- Roblox loads and caches only the ranks currently displayed.
    local asset=entry and entry.image or ""
    if image.Image~=asset then
        image.Image=asset
        image:SetAttribute("RankKey",entry and entry.key or nil)
        image:SetAttribute("RankName",entry and entry.name or nil)
    end
end

return RankIcon
