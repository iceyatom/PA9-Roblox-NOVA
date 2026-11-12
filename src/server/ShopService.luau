-- Robux deliveries commit through the leased inventory profile before a receipt is acknowledged.
-- Clients never name a reward: Roblox reports the developer product and the catalog decides the grant.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Market=game:GetService("MarketplaceService")
local Http=game:GetService("HttpService")
local shared=game.ReplicatedStorage.NOVA
local Shop=require(shared.ShopCatalog)
local Model=require(shared.Inventory)
local Service={}
Service.__index=Service

function Service.new(inventory)
    local self=setmetatable({inventory=inventory},Service)
    self.delivered=Instance.new("RemoteEvent")
    self.delivered.Name="ShopDelivered"; self.delivered.Parent=shared
    Market.ProcessReceipt=function(info) return self:process(info) end
    if Run:IsStudio() then
        -- Studio preview only: exercises offers before their developer products exist.
        -- Never created in live servers, where only ProcessReceipt can deliver.
        local test=Instance.new("RemoteFunction")
        test.Name="ShopStudioPurchase"; test.Parent=shared
        test.OnServerInvoke=function(player,id,...)
            if select("#",...)~=0 or type(id)~="string" or not Shop.byId[id] then return {ok=false,message="Invalid request."} end
            local ok,message=self:deliver(player,Shop.byId[id],"studio:"..Http:GenerateGUID(false))
            return {ok=ok,message=not ok and message or nil}
        end
    end
    return self
end

-- Returns true only once the grant (or its earlier copy) is durably saved.
function Service:deliver(player,product,purchaseId)
    local deadline=os.clock()+20
    while player.Parent==Players and not self.inventory:ready(player) and os.clock()<deadline do task.wait(.25) end
    if player.Parent~=Players then return false,"Player left." end
    local ok,receipt,replay=self.inventory:mutate(player,function(data)
        return Model.purchase(data,product.id,purchaseId,os.time())
    end)
    if ok and not replay and player.Parent==Players then self.delivered:FireClient(player,receipt) end
    return ok,receipt
end

function Service:process(info)
    local player=Players:GetPlayerByUserId(info.PlayerId)
    local product=Shop.byProductId[info.ProductId]
    if not product and Run:IsStudio() then warn(("[NOVA] Receipt for unknown developer product %s"):format(tostring(info.ProductId))) end
    -- Unsaved or unknown receipts stay pending; Roblox retries them and refunds if never granted.
    if not player or not product then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local ok=self:deliver(player,product,tostring(info.PurchaseId))
    return ok and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
end

return Service
