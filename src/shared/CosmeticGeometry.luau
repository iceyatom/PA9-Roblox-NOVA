-- AbsoluteSize is in screen pixels. Child offsets are local GUI units, before UIScale.
-- Remove the inherited scale once so a tracer's right-hand tip stays at its projectile.
local Geometry={}
function Geometry.size(root)
    local scale=1
    local node=root
    while node do
        if node:IsA("GuiObject") then
            local uiScale=node:FindFirstChildOfClass("UIScale")
            if uiScale then scale*=uiScale.Scale end
        end
        node=node.Parent
    end
    if scale<=0 then return Vector2.zero end
    return root.AbsoluteSize/scale
end
return Geometry
