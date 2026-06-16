-- 小月亮 附魔：烷基八氮
-- 攻击20%几率冰冻目标2秒。冰冻破碎时引发冰爆(300%范围伤害)
-- 减速周围敌人50%持续3秒。对被冰冻目标伤害+50%

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_WJBD", {
        name = "烷基八氮",
        client_text = "烷基\n八氮",
        desc = "攻击20%几率冰冻目标2秒\n冰冻破碎时引发冰爆(300%范围伤害)\n对冰冻目标伤害+50%",
        check_desc = "冰冻结界，化学之力！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "wjbd", "Legend_WJBD", 1)
            if not owner._wjbd_hooked then
                owner._wjbd_hooked = true

                -- 攻击时触发
                owner._wjbd_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "wjbd") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end

                    -- 20% 冰冻几率
                    if math.random() <= 0.2 then
                        if target.components.freezable then
                            target.components.freezable:AddColdness(2)
                            -- 记录冰冻来源，用于冰爆检测
                            target._wjbd_frozen_by = owner

                            -- 生成冰霜特效
                            if GLOBAL.SpawnPrefab then
                                local fx = GLOBAL.SpawnPrefab("deerclops_icespike_fx")
                                if fx then
                                    local x, y, z = target.Transform:GetWorldPosition()
                                    fx.Transform:SetPosition(x, y, z)
                                    fx.Transform:SetScale(1.2, 1.2, 1.2)
                                end
                            end
                        end
                    end

                    -- 对冰冻目标伤害+50%
                    if target.components.freezable and target.components.freezable:IsFrozen() then
                        if owner.components.combat then
                            -- 通过临时增加伤害实现
                            local hh = owner.components.hh_player
                            if hh then
                                hh:AddEffectValueByKey("addComDamagePercent", 50)
                                -- 下一帧移除(仅当前攻击生效)
                                owner:DoTaskInTime(0.1, function()
                                    if owner:IsValid() and owner.components.hh_player then
                                        owner.components.hh_player:ReduceEffectValueByKey("addComDamagePercent", 50)
                                    end
                                end)
                            end
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._wjbd_attack_handler)

                -- 监听冰冻破碎 (目标解冻时触发冰爆)
                owner._wjbd_freeze_handler = function(inst)
                    -- 在玩家身上挂一个周期性检测
                end

                -- 用周期性检测来实现冰冻破碎冰爆
                owner._wjbd_monitor_task = owner:DoPeriodicTask(0.5, function()
                    if not _G.Moon_HasEffect(owner, "wjbd") then return end
                    -- 扫描附近被自己冰冻的敌人
                    local x, y, z = owner.Transform:GetWorldPosition()
                    local ents = GLOBAL.TheSim:FindEntities(x, y, z, 15, { "_combat" })
                    for _, ent in ipairs(ents) do
                        if ent._wjbd_frozen_by == owner and ent.components.freezable then
                            if not ent.components.freezable:IsFrozen() then
                                -- 冰冻刚破碎，触发冰爆
                                if ent._wjbd_was_frozen then
                                    ent._wjbd_was_frozen = nil
                                    ent._wjbd_frozen_by = nil

                                    -- 冰爆AoE 300%伤害
                                    local fx_x, fx_y, fx_z = ent.Transform:GetWorldPosition()
                                    if GLOBAL.SpawnPrefab then
                                        local boom = GLOBAL.SpawnPrefab("deerclops_icespike_fx")
                                        if boom then
                                            boom.Transform:SetPosition(fx_x, fx_y, fx_z)
                                            boom.Transform:SetScale(2, 2, 2)
                                        end
                                    end

                                    -- 范围伤害
                                    local nearby = GLOBAL.TheSim:FindEntities(fx_x, fx_y, fx_z, 4, { "_combat" })
                                    for _, victim in ipairs(nearby) do
                                        if victim ~= owner and victim.components.health and not victim.components.health:IsDead() then
                                            if owner.components.combat then
                                                local dmg = owner.components.combat.defaultdamage or 34
                                                victim.components.health:DoDelta(-dmg * 3, false, nil)
                                            end
                                        end
                                    end
                                end
                            else
                                ent._wjbd_was_frozen = true
                            end
                        end
                    end
                end)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "wjbd", "Legend_WJBD", 1)
            if not _G.Moon_HasEffect(owner, "wjbd") then
                if owner._wjbd_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._wjbd_attack_handler)
                    owner._wjbd_attack_handler = nil
                end
                if owner._wjbd_monitor_task then
                    owner._wjbd_monitor_task:Cancel()
                    owner._wjbd_monitor_task = nil
                end
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_WJBD", 0.01)
end)
