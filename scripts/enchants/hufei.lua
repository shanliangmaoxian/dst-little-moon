-- 小月亮 附魔：蝴蝶的小阿飞
-- 攻击25%几率释放3只蝶翼飞刃追踪目标，每只120%伤害
-- 击杀回复15生命+10精神。移速+20%

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_HUFEI", {
        name = "蝴蝶的小阿飞",
        client_text = "蝶\n飞",
        desc = "攻击25%几率释放3只蝶翼飞刃\n每只造成120%伤害追踪目标\n击杀回复15生命+10精神\n移速+20%",
        check_desc = "蝴蝶之舞，飞刃追魂！",
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

                -- 永久移速+20%
                local hh = owner.components.hh_player
                if hh then
                    hh:AddEffectValueByKey("addSpeedPercent", 20)
                end

                -- 攻击时触发蝶翼飞刃
                owner._hufei_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "hufei") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end

                    if math.random() <= 0.25 then
                        -- 释放3只蝶翼飞刃
                        for i = 1, 3 do
                            owner:DoTaskInTime(i * 0.2, function()
                                if not owner:IsValid() then return end
                                if not target:IsValid() then return end

                                -- 造成120%伤害
                                if target.components.health and not target.components.health:IsDead() then
                                    local dmg = (owner.components.combat and owner.components.combat.defaultdamage) or 34
                                    target.components.health:DoDelta(-dmg * 1.2, false, nil)
                                end

                                -- 蝴蝶特效
                                if GLOBAL.SpawnPrefab then
                                    local butterfly = GLOBAL.SpawnPrefab("butterfly")
                                    if butterfly then
                                        local ox, oy, oz = owner.Transform:GetWorldPosition()
                                        local tx, ty, tz = target.Transform:GetWorldPosition()
                                        butterfly.Transform:SetPosition(ox, oy + 1, oz)
                                        -- 飞向目标
                                        if butterfly.Physics then
                                            local dx, dz = tx - ox, tz - oz
                                            local dist = math.sqrt(dx * dx + dz * dz) or 1
                                            local speed = 15
                                            butterfly.Physics:SetVel(dx / dist * speed, 2, dz / dist * speed)
                                        end
                                        -- 到达后移除
                                        butterfly:DoTaskInTime(0.6, function()
                                            if butterfly:IsValid() then
                                                -- 到达特效
                                                if GLOBAL.SpawnPrefab then
                                                    local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                                                    if fx then
                                                        local bx, by, bz = butterfly.Transform:GetWorldPosition()
                                                        fx.Transform:SetPosition(bx, by, bz)
                                                    end
                                                end
                                                butterfly:Remove()
                                            end
                                        end)
                                    end
                                end
                            end)
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._hufei_attack_handler)

                -- 击杀回复
                owner._hufei_kill_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "hufei") then return end
                    if owner.components.health then
                        owner.components.health:DoDelta(15, false, nil)
                    end
                    if owner.components.sanity then
                        owner.components.sanity:DoDelta(10)
                    end
                    -- 蝴蝶群特效
                    if GLOBAL.SpawnPrefab then
                        local x, y, z = owner.Transform:GetWorldPosition()
                        for _ = 1, 3 do
                            local bf = GLOBAL.SpawnPrefab("butterfly")
                            if bf then
                                bf.Transform:SetPosition(x + math.random() * 2 - 1, y + 1, z + math.random() * 2 - 1)
                                bf:DoTaskInTime(2, function()
                                    if bf:IsValid() then bf:Remove() end
                                end)
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
                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("addSpeedPercent", 20)
                end
                if owner._hufei_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._hufei_attack_handler)
                    owner._hufei_attack_handler = nil
                end
                if owner._hufei_kill_handler then
                    owner:RemoveEventCallback("killed", owner._hufei_kill_handler)
                    owner._hufei_kill_handler = nil
                end
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_HUFEI", 0.01)
end)
