local Players=game:GetService("Players")
local Portrait={}
local cache={}

function Portrait.set(image,uid)
    if image:GetAttribute("UserId")==uid then return end
    image:SetAttribute("UserId",uid)
    image.Image=""
    image.Visible=uid~=nil
    if not uid then return end
    task.spawn(function()
        for attempt=1,3 do
            local url=cache[uid]
            if not url then
                local ok,content,ready=pcall(function()
                    return Players:GetUserThumbnailAsync(uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
                end)
                if ok and ready then url=content; cache[uid]=url end
            end
            if image:GetAttribute("UserId")~=uid or not image.Parent then return end
            if url then image.Image=url; return end
            task.wait(attempt)
        end
    end)
end

return Portrait
