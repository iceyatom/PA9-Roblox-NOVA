local W=require(script.Parent.Widgets)
local C=W.colors
local Defaults=require(game.ReplicatedStorage.NOVA.Config)
local Diagnostics={}
function Diagnostics.attach(hud,arena,remote)
    local panel=W.box(hud.stage,"StudioPanel",981,82,448,285,C.panel,10)
    W.stroke(panel,C.purple)
    W.text(panel,"Heading",16,9,410,33,"Studio diagnostics",24,C.white,Enum.Font.GothamBold)
    local mask=W.button(panel,"Masks",16,53,200,35,"Show masks",false)
    mask.Activated:Connect(function()
        arena.diagnostics.Visible=not arena.diagnostics.Visible
        mask.Text=arena.diagnostics.Visible and "Hide masks" or "Show masks"
    end)
    local lane=W.button(panel,"Lane",226,53,203,35,"Set duel lane",false)
    lane.Activated:Connect(function() remote:FireServer("lane") end)
    local keys={"Speed","Jump","Gravity","Launch","BulletSpeed"}
    local index=1
    local values=table.clone(Defaults)
    local key=W.button(panel,"Parameter",16,105,245,35,"",false)
    local function refresh() key.Text=("%s   %.1f"):format(keys[index],values[keys[index]]) end
    key.Activated:Connect(function() index=index%#keys+1; refresh() end)
    for i,delta in {-1,1} do
        local adjust=W.button(panel,"Adjust",271+(i-1)*81,105,75,35,delta==1 and "+" or "−",false)
        adjust.Activated:Connect(function() remote:FireServer("set",keys[index],values[keys[index]]+delta) end)
    end
    refresh()
    local log=W.text(panel,"Log",16,152,416,107,"",15,C.muted)
    log.TextYAlignment=Enum.TextYAlignment.Top
    local lines={}
    local function record(s)
        table.insert(lines,1,s)
        if #lines>4 then table.remove(lines) end
        log.Text=table.concat(lines,"\n")
    end
    remote.OnClientEvent:Connect(function(action,keyName,value)
        if action=="tuned" then values[keyName]=value; refresh(); record(keyName.." = "..value)
        else record("Duel lane loaded") end
    end)
    panel.Visible=false
    game:GetService("UserInputService").InputBegan:Connect(function(key,processed)
        if not processed and key.KeyCode==Enum.KeyCode.F4 then panel.Visible=not panel.Visible end
    end)
    return record
end
return Diagnostics
