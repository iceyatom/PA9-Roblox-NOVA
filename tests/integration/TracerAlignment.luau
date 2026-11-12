-- Run on a Studio client. No live inventory, combat state or saved data is changed.
return function(playerGui)
    local player=game.Players.LocalPlayer
    local shared=game.ReplicatedStorage.NOVA
    local Geometry=require(shared.CosmeticGeometry)
    local Catalog=require(shared.InventoryCatalog)
    local Batch=require(player.PlayerScripts.NOVA.BatchOneVisuals)
    local host=Instance.new("ScreenGui");host.Name="TracerAlignmentTest";host.IgnoreGuiInset=true
    host.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;host.Parent=playerGui
    local canvas=Instance.new("Frame");canvas.Size=UDim2.fromOffset(800,500);canvas.BackgroundTransparency=1;canvas.Parent=host
    local outer=Instance.new("UIScale");outer.Parent=canvas
    local nested=Instance.new("Frame");nested.Size=UDim2.fromScale(1,1);nested.BackgroundTransparency=1;nested.Parent=canvas
    local inner=Instance.new("UIScale");inner.Scale=.75;inner.Parent=nested
    local names={WhiteHotCore=true,LightningFracture=true,WhiteHotEnergy=true,DataRail=true}
    local items={};local seen={}
    for _,item in Catalog.items do
        local key=item.theme or item.visual
        if item.category=="tracers" and key and not seen[key] then seen[key]=true;table.insert(items,item) end
    end
    local cases=0
    local ok,message=pcall(function()
        for _,scale in {.6,1,1.8} do
            outer.Scale=scale
            for _,item in items do
                local root=Instance.new("ImageLabel");root.Name=item.id;root.BackgroundTransparency=1
                root.Size=UDim2.fromOffset(240,12);root.Position=UDim2.fromOffset(180,100);root.Parent=nested
                task.wait()
                assert(Batch.apply(root,item,"wakes"),"Effect did not apply: "..item.id)
                for _,angle in {0,37,90,180,-90} do
                    root.Rotation=angle;task.wait()
                    local size=Geometry.size(root)
                    assert((size-Vector2.new(240,12)).Magnitude<.05,"Incorrect local size: "..item.id)
                    local nearest=math.huge
                    for _,line in root:GetDescendants() do
                        if line:IsA("GuiObject") and line.Visible and names[line.Name] then
                            local radians=math.rad(line.Rotation)
                            local endpoint=Vector2.new(line.Position.X.Offset,line.Position.Y.Offset)
                                +Vector2.new(math.cos(radians),math.sin(radians))*line.Size.X.Offset/2
                            nearest=math.min(nearest,(endpoint-Vector2.new(240,6)).Magnitude)
                        end
                    end
                    assert(nearest<3,("Trail tip misses projectile: %s scale %.1f angle %d distance %.2f"):format(item.id,scale,angle,nearest))
                    cases+=1
                end
                Batch.clear(root);root:Destroy()
            end
        end
    end)
    host:Destroy()
    assert(ok,message)
    return {cases=cases,themes=#items,passed=true}
end
