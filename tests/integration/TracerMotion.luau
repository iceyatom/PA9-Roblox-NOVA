-- Studio client regression: compact/low-performance rendering must retain trail motion.
return function(playerGui)
    local player=game.Players.LocalPlayer
    local shared=game.ReplicatedStorage.NOVA
    local Batch=require(player.PlayerScripts.NOVA.BatchOneVisuals)
    local Catalog=require(shared.InventoryCatalog)
    local old=player:GetAttribute("ReducedEffects");player:SetAttribute("ReducedEffects",false)
    local host=Instance.new("ScreenGui");host.Name="TracerMotionTest";host.Parent=playerGui
    local function root()
        local image=Instance.new("ImageLabel");image.Size=UDim2.fromOffset(240,12)
        image.Position=UDim2.fromOffset(40,100);image.BackgroundTransparency=1;image.Parent=host
        return image
    end
    local function pose(image)
        local values={}
        for _,node in image:GetDescendants() do if node:IsA("GuiObject") then
            table.insert(values,tostring(node.Position)..tostring(node.Size)..tostring(node.Rotation))
        end end
        return table.concat(values,"|")
    end
    local count=0
    local ok,message=pcall(function()
        assert(Batch.tracerMode({image="static"})=="static")
        assert(Batch.tracerMode({setId="one",frames=1})=="static")
        assert(Batch.tracerMode({})=="line")
        local seen={};local effects={}
        for _,item in Catalog.items do
            local key=item.theme or item.visual
            if item.category=="tracers" and key and not seen[key] then
                seen[key]=true
                local image=root();image:SetAttribute("CompactPrism",true)
                assert(Batch.tracerMode(item)=="dynamic" and Batch.apply(image,item,"wakes"))
                table.insert(effects,{root=image,before=pose(image),id=item.id})
            end
        end
        task.wait(.2)
        for _,effect in effects do
            assert(pose(effect.root)~=effect.before,"Compact trail froze: "..effect.id)
            Batch.clear(effect.root);effect.root:Destroy();count+=1
        end
        local sprite=Catalog.byId.b1_tracers_mint_circuit
        assert(Batch.tracerMode(sprite)=="sprite")
        local parent=Instance.new("Frame");parent.Size=UDim2.fromOffset(240,12);parent.Parent=host
        local image=Batch.overlay(parent,sprite,"wakes");task.wait()
        local first=image.ImageRectOffset;task.wait(.08)
        assert(image.ImageRectOffset~=first,"Inventory sprite preview froze")
        player:SetAttribute("ReducedEffects",true);task.wait(.1)
        local stopped=image.ImageRectOffset;task.wait(.1)
        assert(image.ImageRectOffset==stopped,"Explicit Reduced Effects must stop sprite motion")
        parent:Destroy()
    end)
    host:Destroy();player:SetAttribute("ReducedEffects",old)
    assert(ok,message)
    return {dynamicThemes=count,previewAnimation=true,passed=true}
end
