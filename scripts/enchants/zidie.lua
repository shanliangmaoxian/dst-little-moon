-- 小月亮 附魔：紫蝶
-- 身化蝶影，以假乱真！
-- 攻击5%几率召唤蝶影分身（固定为大虚影 gestalt_guard，继承50%属性，持续8秒，最多2个）
-- 分身自动攻击附近敌人。分身存在时本体伤害+30%
-- 移速永久+20%，分身移速+40%
-- 大虚影不会破坏建筑，也不会攻击玩家

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- ======== 分身辅助函数 ========

-- 清理已消亡的分身
local function cleanup_clones(owner)
    if not owner._zidie_clones then
        owner._zidie_clones = {}
        return
    end
    local alive = {}
    for _, data in ipairs(owner._zidie_clones) do
        if data.entity and data.entity:IsValid() then
            table.insert(alive, data)
        end
    end
    owner._zidie_clones = alive
end

-- 检查是否有存活分身
local function has_alive_clones(owner)
    cleanup_clones(owner)
    return #(owner._zidie_clones or {}) > 0
end

-- 蝶影固定召唤大虚影（gestalt_guard，月之守卫）
-- 原先随机生物池会召出熊獾/巨鹿/龙蝇等，践踏/吐息会破坏建筑，故改为大虚影
local function spawn_clone(owner, target)
    local x, y, z = owner.Transform:GetWorldPosition()

    -- 固定召唤大虚影
    local clone = _G.SpawnPrefab("gestalt_guard")
    if not clone then return nil end

    -- 定位：玩家和目标的中间偏目标方向，加随机偏移
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local sx = x + (tx - x) * 0.4 + math.random(-2, 2)
    local sz = z + (tz - z) * 0.4 + math.random(-2, 2)
    clone.Transform:SetPosition(sx, y, sz)

    -- 蝴蝶特效登场
    local fx = _G.SpawnPrefab("statue_transition_2")
    if fx then fx.Transform:SetPosition(sx, y + 0.5, sz) end

    -- 紫蝶化外观：紫色半透明！
    if clone.AnimState then
        clone.AnimState:SetMultColour(0.7, 0.3, 1, 0.75)
        clone.AnimState:SetAddColour(0.3, 0, 0.5, 0)
    end

    -- 配置战斗：继承50%攻击力
    if clone.components.combat then
        clone.components.combat.defaultdamage = (owner.components.combat and owner.components.combat.defaultdamage or 10) * 0.5
    end

    -- 设置初始目标
    if target:IsValid() then
        clone.components.combat:SetTarget(target)
    end

    -- 跟随玩家
    if clone.components.follower then
        clone.components.follower:SetLeader(owner)
    end

    -- 移速+40%
    if clone.components.locomotor then
        clone.components.locomotor.walkspeed = (clone.components.locomotor.walkspeed or 4) * 1.4
        clone.components.locomotor.runspeed = (clone.components.locomotor.runspeed or 7) * 1.4
    end

    -- 友军标签（防止玩家主动攻击 + AI无视）
    if not clone:HasTag("companion") then clone:AddTag("companion") end
    if not clone:HasTag("friendly") then clone:AddTag("friendly") end
    if not clone:HasTag("notarget") then clone:AddTag("notarget") end

    -- 玩家无法攻击它：钩住health.DoDelta，免疫玩家来源的伤害
    if clone.components.health then
        local oldDoDelta = clone.components.health.DoDelta
        clone.components.health.DoDelta = function(self, delta, overtime, cause, ...)
            if delta < 0 then
                -- 检查剩余参数中是否有玩家实体
                local args = { ... }
                for _, arg in ipairs(args) do
                    if type(arg) == "table" and arg.IsValid and arg:IsValid() and arg.HasTag and arg:HasTag("player") then
                        return -- 玩家造成的伤害全部免疫
                    end
                end
            end
            return oldDoDelta(self, delta, overtime, cause, ...)
        end
    end

    -- 分身也不攻击玩家：钩住SetTarget（大虚影原本会主动攻击低理智玩家，这里拦截）
    if clone.components.combat then
        local oldSetTarget = clone.components.combat.SetTarget
        clone.components.combat.SetTarget = function(self, target)
            if target and target:IsValid() and target:HasTag("player") then
                return
            end
            return oldSetTarget(self, target)
        end
    end

    -- 不睡觉
    if clone.components.sleepinguser then
        clone:RemoveComponent("sleepinguser")
    end

    -- 8秒后消失
    clone:DoTaskInTime(8, function()
        if clone:IsValid() then
            local cx, cy, cz = clone.Transform:GetWorldPosition()
            local fx2 = _G.SpawnPrefab("statue_transition_2")
            if fx2 then fx2.Transform:SetPosition(cx, cy + 0.5, cz) end
            clone:Remove()
        end
    end)

    return clone
end

-- ======== 注册附魔 ========

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    _G.AddSpecialEquipEffect("Legend_ZIDIE", {
        name = "紫蝶",
        client_text = "紫\n蝶",
        desc = "攻击5%几率召唤大虚影(8秒,最多2个)\n继承50%属性,自动追击,本体伤害+30%\n移速永久+20%,不可被玩家攻击",
        check_desc = "身化蝶影，以假乱真！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,

        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "zidie", "Legend_ZIDIE", 1)
            if not owner._zidie_hooked then
                owner._zidie_hooked = true
                owner._zidie_clones = {}

                -- 永久移速+20%
                local hh = owner.components.hh_player
                if hh then
                    hh:AddEffectValueByKey("addSpeedPercent", 20)
                end

                -- 监听攻击事件：5%几率召唤分身
                owner._zidie_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "zidie") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end
                    if target == owner then return end
                    if math.random() > 0.05 then return end

                    local had_clones = has_alive_clones(owner)
                    if #owner._zidie_clones >= 2 then return end

                    local clone = spawn_clone(owner, target)
                    if clone then
                        table.insert(owner._zidie_clones, { entity = clone })
                        if not had_clones and hh then
                            hh:AddEffectValueByKey("addComDamagePercent", 30)
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._zidie_attack_handler)

                -- 每2秒检查分身状态
                owner._zidie_check_task = owner:DoPeriodicTask(2, function()
                    if not _G.Moon_HasEffect(owner, "zidie") then return end
                    if not owner:IsValid() then return end
                    local had_clones = #(owner._zidie_clones or {})
                    cleanup_clones(owner)
                    local now_clones = #(owner._zidie_clones or {})
                    if had_clones > 0 and now_clones == 0 then
                        local hhp = owner.components.hh_player
                        if hhp then
                            hhp:ReduceEffectValueByKey("addComDamagePercent", 30)
                        end
                    end
                end)
            end
        end,

        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "zidie", "Legend_ZIDIE", 1)
            if not _G.Moon_HasEffect(owner, "zidie") then
                if owner._zidie_check_task then
                    owner._zidie_check_task:Cancel()
                    owner._zidie_check_task = nil
                end
                if owner._zidie_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._zidie_attack_handler)
                    owner._zidie_attack_handler = nil
                end

                cleanup_clones(owner)
                for _, data in ipairs(owner._zidie_clones or {}) do
                    if data.entity and data.entity:IsValid() then
                        data.entity:Remove()
                    end
                end
                owner._zidie_clones = nil

                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("addSpeedPercent", 20)
                    hh:ReduceEffectValueByKey("addComDamagePercent", 30)
                end
                owner._zidie_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_ZIDIE", 0.01)
end)
