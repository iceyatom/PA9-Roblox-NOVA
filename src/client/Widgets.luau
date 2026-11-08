local W = {}
W.rgb = Color3.fromHex
W.colors = {ink=W.rgb("080b13"), panel=W.rgb("111621"), line=W.rgb("303747"), muted=W.rgb("9ca8bc"),
    white=W.rgb("edf2ff"), lime=W.rgb("b9f770"), purple=W.rgb("793dff"),blue=W.rgb("527eff"),red=W.rgb("ff5859"),
    dark=W.rgb("3228c7"), light=W.rgb("248bff"), mint=W.rgb("50e4ac")}
function W.box(parent,name,x,y,w,h,color,z)
    local f=Instance.new("Frame")
    f.Name=name
    f.BorderSizePixel=0
    f.Position=UDim2.fromOffset(x,y)
    f.Size=UDim2.fromOffset(w,h)
    f.BackgroundColor3=color or W.colors.ink
    f.BackgroundTransparency=color and 0 or 1
    f.ZIndex=z or 1
    f.Parent=parent
    return f
end
function W.text(parent,name,x,y,w,h,value,size,color,font)
    local l=Instance.new("TextLabel")
    l.Name=name
    l.BackgroundTransparency=1
    l.Position=UDim2.fromOffset(x,y)
    l.Size=UDim2.fromOffset(w,h)
    l.Text=value
    l.Font=font or Enum.Font.Code
    l.TextSize=size
    l.TextColor3=color or W.colors.white
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd
    l.ZIndex=3
    l.Parent=parent
    return l
end
function W.button(parent,name,x,y,w,h,value,primary)
    local b=Instance.new("TextButton")
    b.Name=name
    b.Position=UDim2.fromOffset(x,y)
    b.Size=UDim2.fromOffset(w,h)
    b.BorderSizePixel=0
    b.BackgroundColor3=primary and W.colors.lime or W.colors.line
    b.TextColor3=primary and W.colors.ink or W.colors.white
    b.Font=Enum.Font.GothamBold
    b.TextSize=16
    b.Text=value
    b.ZIndex=5
    b.Parent=parent
    return b
end
function W.stroke(parent,color,width)
    local s=Instance.new("UIStroke")
    s.Color=color
    s.Thickness=width or 1
    s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    s.Parent=parent
end
function W.round(f)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(1,0)
    c.Parent=f
end
return W
