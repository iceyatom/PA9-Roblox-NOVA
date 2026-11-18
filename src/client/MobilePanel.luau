local W=require(script.Parent.Widgets)
local Style=require(script.Parent.InventoryStyle)
local MobilePanel={}

function MobilePanel.fit(viewport,width,height)
    return math.max(.01,math.min(1.3,(viewport.X-28)/width,(viewport.Y-28)/height))
end

function MobilePanel.attach(container,panel)
    panel.AnchorPoint=Vector2.new(.5,.5)
    panel.Position=UDim2.fromScale(.5,.5)
    local scale=Instance.new("UIScale")
    scale.Parent=panel
    local function update()
        local size=panel.Size
        scale.Scale=MobilePanel.fit(container.AbsoluteSize,math.max(1,size.X.Offset),math.max(1,size.Y.Offset))
    end
    container:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
    panel:GetPropertyChangedSignal("Size"):Connect(update)
    update()
end

function MobilePanel.disableScroll(frame)
    frame.ScrollingEnabled=false
    frame.ScrollBarThickness=0
    frame.CanvasSize=UDim2.new()
    frame.CanvasPosition=Vector2.zero
end

function MobilePanel.pager(parent,onChange)
    local root=W.box(parent,"Pages",0,0,300,44)
    root.Visible=false
    local previous=Style.button(root,"Previous",0,0,90,44,"‹ Prev",false)
    local nextButton=Style.button(root,"Next",210,0,90,44,"Next ›",false)
    local label=W.text(root,"PageNumber",90,0,120,44,"",18,W.colors.white,Enum.Font.GothamBold)
    label.TextXAlignment=Enum.TextXAlignment.Center
    local pager={root=root,page=1}
    previous.Activated:Connect(function()
        if previous.Active then pager.page-=1; onChange() end
    end)
    nextButton.Activated:Connect(function()
        if nextButton.Active then pager.page+=1; onChange() end
    end)
    function pager:range(count,perPage)
        local pages=math.max(1,math.ceil(count/perPage))
        self.page=math.clamp(self.page,1,pages)
        root.Visible=pages>1
        label.Text=("%d / %d"):format(self.page,pages)
        previous.Active=self.page>1
        previous.Selectable=previous.Active
        previous.TextTransparency=previous.Active and 0 or .45
        nextButton.Active=self.page<pages
        nextButton.Selectable=nextButton.Active
        nextButton.TextTransparency=nextButton.Active and 0 or .45
        return (self.page-1)*perPage+1,math.min(count,self.page*perPage)
    end
    return pager
end

return MobilePanel
