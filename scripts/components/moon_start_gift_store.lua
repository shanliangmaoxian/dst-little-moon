-- 小月亮 开局礼包 已领记录组件
-- 挂在 TheWorld 上，通过 OnSave/OnLoad 随世界存档持久化
-- 世界重新生成（实体重建）时 OnLoad 无数据，已领记录自动清零

local MoonStartGiftStore = Class(function(self, inst)
    self.inst = inst
    self.claimed = {}
end)

function MoonStartGiftStore:OnSave()
    local save = {}
    for k, v in pairs(self.claimed) do
        save[k] = v
    end
    return next(save) and { claimed = save } or nil
end

function MoonStartGiftStore:OnLoad(data)
    if data and type(data.claimed) == "table" then
        for k, v in pairs(data.claimed) do
            self.claimed[k] = v
        end
    end
end

function MoonStartGiftStore:GetClaimed()
    return self.claimed
end

function MoonStartGiftStore:SetClaimed(userid, plan)
    self.claimed[userid] = plan
end

return MoonStartGiftStore
