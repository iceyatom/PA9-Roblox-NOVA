-- Small hint card shown while walking around the 3D lobby.
local W=require(script.Parent.Widgets)
local C=W.colors
local LobbyHud={}
function LobbyHud.new(playerGui)
    local gui=Instance.new("ScreenGui")
    gui.Name="NOVALobby"
    gui.ResetOnSpawn=false
    gui.DisplayOrder=5
    gui.Parent=playerGui
    local card=W.box(gui,"Card",0,0,360,86,C.panel)
    card.AnchorPoint=Vector2.new(0.5,1)
    card.Position=UDim2.new(0.5,0,1,-24)
    card.BackgroundTransparency=0.08
    W.stroke(card,C.line)
    W.box(card,"Signal",0,0,4,86,C.purple)
    W.text(card,"Kicker",20,10,320,20,"NOVA   /   LOBBY",14,C.purple)
    W.text(card,"Title",20,30,320,30,"Step onto the purple pad",24,C.white,Enum.Font.GothamBlack)
    W.text(card,"Detail",20,60,320,18,"Queue for a 1v1 duel / random map",14,C.muted)
    return gui
end
return LobbyHud
