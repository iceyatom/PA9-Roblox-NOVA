local W=require(script.Parent.Widgets)
local Streak={Minimum=3,Image="rbxassetid://115388877650112"}

-- Shared by duel cards and lobby nameplates: one threshold and one original sprite.
function Streak.new(parent,name,x,y,width,height)
    local row=W.box(parent,name,x,y,width,height)
    row.Visible=false
    row.ZIndex=3
    local layout=Instance.new("UIListLayout")
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Padding=UDim.new(0,3)
    layout.Parent=row
    local fire=Instance.new("ImageLabel")
    fire.Name="Fire"
    fire.BackgroundTransparency=1
    fire.Size=UDim2.fromOffset(height,height)
    fire.ScaleType=Enum.ScaleType.Fit
    fire.Image=Streak.Image
    fire.ZIndex=3
    fire.LayoutOrder=1
    fire.Parent=row
    local count=W.text(row,"Count",0,0,0,height,"",18,Color3.fromHex("ffcd65"),Enum.Font.GothamBold)
    count.LayoutOrder=2
    count.AutomaticSize=Enum.AutomaticSize.X
    count.TextStrokeColor3=W.colors.ink
    count.TextStrokeTransparency=.25
    return row
end

function Streak.set(row,count)
    local visible=type(count)=="number" and count==count and count>=Streak.Minimum and count<math.huge
    row.Visible=visible
    row.Count.Text=visible and tostring(math.floor(count)) or ""
    row:SetAttribute("WinStreak",visible and count or nil)
end

return Streak
