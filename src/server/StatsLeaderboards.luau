local Metrics=require(game.ReplicatedStorage.NOVA.Stats).boards
local Leaderboard=require(script.Parent.PracticeLeaderboard)
local Service={};Service.__index=Service
function Service.new(boards)
    local self=setmetatable({boards={}},Service)
    for _,metric in Metrics do
        self.boards[metric.id]=Leaderboard.new(boards[metric.id],{storeName=metric.store,deferredWrites=true})
    end
    return self
end
function Service:submit(player,stats)
    for _,metric in Metrics do
        local board=self.boards[metric.id];local value=stats[metric.id]
        if value>0 and value>(board.best[player.UserId] or 0) then board:submit(player,value) end
    end
end
return Service
