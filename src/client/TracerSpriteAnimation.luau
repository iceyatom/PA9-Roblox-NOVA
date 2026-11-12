-- Animate sprite-sheet tracer previews with the same frame selection used in gameplay.
-- Procedural and single-image tracers never enter this scheduler.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Animation={}
local entries={};local connection
local function visible(root)
    local node=root
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if (node:IsA("ScreenGui") or node:IsA("DockWidgetPluginGui")) and not node.Enabled then return false end
        node=node.Parent
    end
    return root.Parent~=nil
end
function Animation.stop(root)
    local entry=entries[root]
    if entry then entry.destroy:Disconnect();entries[root]=nil end
    if not next(entries) and connection then connection:Disconnect();connection=nil end
end
function Animation.start(root,item,draw)
    Animation.stop(root)
    local entry={draw=draw,frames=item.frames}
    entries[root]=entry
    entry.destroy=root.Destroying:Once(function() Animation.stop(root) end)
    if connection then return end
    connection=Run.Heartbeat:Connect(function()
        local reduced=Players.LocalPlayer:GetAttribute("ReducedEffects")==true
        for image,e in entries do if visible(image) then
            local frame=reduced and 0 or math.floor(os.clock()*18)%e.frames
            if frame~=e.frame then e.frame=frame;e.draw(frame) end
        end end
    end)
end
return Animation
