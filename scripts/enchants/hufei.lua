-- 小月亮 附魔：蝴蝶的小阿飞
-- 最多3只蝴蝶护体，受到伤害时消耗1只蝴蝶抵消伤害
-- 击杀回复15生命+10精神并恢复1只蝴蝶。移速+20%

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_HUFEI", {
        name = "蝴蝶的小阿飞",
        client_text = "蝶\n飞",
        desc = "最多3只光翼蝴蝶护体\n受到伤害时消耗1只光翼蝴蝶抗伤\n击杀回复15生命+10精神\n移速+20%",
        check_desc = "蝶翼护体，抗伤保命！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "hufei", "Legend_HUFEI", 1)
            if not owner._hufei_hooked then
                owner._hufei_hooked = true
                owner._hufei_butterflies = 3  -- 初始3只蝴蝶

                -- 永久移速+20%
                local hh = owner.components.hh_player
                if hh then
                    hh:AddEffectValueByKey("addSpeedPercent", 20)
                end

                -- 勾住 health:DoDelta 拦截伤害（蝴蝶抗伤）
                local health = owner.components.health
                if health and not health._hufei_hooked_dodelta then
                    local oldDoDelta = health.DoDelta
                    health._hufei_old_dodelta = oldDoDelta
                    health.DoDelta = function(self, delta, overtime, cause, ...)
                        -- 拦截伤害(负值)
                        if delta < 0 then
                            if _G.Moon_HasEffect(owner, "hufei") then
                                local butterflies = owner._hufei_butterflies or 0
                                if butterflies > 0 then
                                    owner._hufei_butterflies = butterflies - 1
                                    -- 蝶翼抗伤特效
                                    if GLOBAL.SpawnPrefab then
                                        local x, y, z = owner.Transform:GetWorldPosition()
                                        local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                                        if fx then
                                            fx.Transform:SetPosition(x, y, z)
                                        end
                                    end
                                    -- 抵消伤害，不调用原始 DoDelta
                                    return
                                end
                            end
                        end
                        return oldDoDelta(self, delta, overtime, cause, ...)
                    end
                end

                -- 蝴蝶自动恢复：每8秒恢复1只
                owner._hufei_regen_task = owner:DoPeriodicTask(8, function()
                    if not _G.Moon_HasEffect(owner, "hufei") then return end
                    owner._hufei_butterflies = math.min(3, (owner._hufei_butterflies or 0) + 1)
                end)

                -- 击杀回复
                owner._hufei_kill_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "hufei") then return end
                    if owner.components.health then
                        owner.components.health:DoDelta(15, false, nil)
                    end
                    if owner.components.sanity then
                        owner.components.sanity:DoDelta(10)
                    end
                    -- 击杀恢复1只蝴蝶（上限3只）
                    local current = owner._hufei_butterflies or 0
                    if current < 3 then
                        owner._hufei_butterflies = current + 1
                        -- 蝶翼恢复光效
                        if GLOBAL.SpawnPrefab then
                            local x, y, z = owner.Transform:GetWorldPosition()
                            local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                            if fx then
                                fx.Transform:SetPosition(x, y, z)
                            end
                        end
                    end
                end
                owner:ListenForEvent("killed", owner._hufei_kill_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "hufei", "Legend_HUFEI", 1)
            if not _G.Moon_HasEffect(owner, "hufei") then
                -- 还原移速
                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("addSpeedPercent", 20)
                end
                -- 还原 DoDelta
                local health = owner.components.health
                if health and health._hufei_old_dodelta then
                    health.DoDelta = health._hufei_old_dodelta
                    health._hufei_old_dodelta = nil
                end
                -- 停止恢复任务
                if owner._hufei_regen_task then
                    owner._hufei_regen_task:Cancel()
                    owner._hufei_regen_task = nil
                end
                -- 移除击杀回调
                if owner._hufei_kill_handler then
                    owner:RemoveEventCallback("killed", owner._hufei_kill_handler)
                    owner._hufei_kill_handler = nil
                end
                -- 清除蝴蝶计数
                owner._hufei_butterflies = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_HUFEI", 0.01)
end)
