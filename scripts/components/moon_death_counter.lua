-- 小月亮 死亡计数组件
-- 数据挂在玩家实体上，通过 OnSave/OnLoad 随世界存档自动持久化
-- 世界再生时实体重建，OnLoad 无数据，计数自动归零

local MoonDeathCounter = Class(function(self, inst)
    self.inst = inst
    self.count = 0

    inst:ListenForEvent("death", function(src)
        self.count = self.count + 1

        -- 死亡公告
        if MOON_CFG and MOON_CFG.ENABLE_DEATH_ANNOUNCE then
            local name = src.name or src.userid or "?"
            TheNet:Announce("玩家 " .. name .. " 死了，当前已累计死亡 " .. self.count .. " 次")
        end
    end)
end)

function MoonDeathCounter:OnSave()
    return self.count > 0 and { count = self.count } or nil
end

function MoonDeathCounter:OnLoad(data)
    if data and data.count then
        self.count = data.count
    end
end

function MoonDeathCounter:GetCount()
    return self.count
end

return MoonDeathCounter
