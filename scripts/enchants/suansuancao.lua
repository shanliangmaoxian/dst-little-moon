-- 小月亮 附魔：酸酸草
-- 攻击使目标防御降低20%持续5秒。食用酸味食物回复量翻倍且10秒加速

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_SUANSUANCAO", {
        name = "酸酸草",
        client_text = "酸酸\n草",
        desc = "攻击使目标「牙酸」：防御降低20% (持续5秒)\n食用浆果/酸性食物回复量翻倍\n并获得10秒加速效果",
        check_desc = "这草，够劲儿！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "suansuancao", "Legend_SUANSUANCAO", 1)
            if not owner._suansuancao_hooked then
                owner._suansuancao_hooked = true

                -- 攻击降低防御
                owner._suansuancao_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "suansuancao") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() or not target.components.combat then return end

                    -- 防御降低20% -> 受到伤害1.25倍 (1/0.8 = 1.25)
                    if target.components.combat.externaldamagetakenmultipliers then
                        target.components.combat.externaldamagetakenmultipliers:SetModifier("suansuancao", 1.25)
                        
                        -- 5秒后恢复
                        if target._suansuancao_task then
                            target._suansuancao_task:Cancel()
                        end
                        target._suansuancao_task = target:DoTaskInTime(5, function()
                            if target:IsValid() and target.components.combat and target.components.combat.externaldamagetakenmultipliers then
                                target.components.combat.externaldamagetakenmultipliers:RemoveModifier("suansuancao")
                            end
                            target._suansuancao_task = nil
                        end)
                        
                        -- 牙酸特效 (使用冰冻破碎或类似特效)
                        if GLOBAL.SpawnPrefab then
                            local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                            if fx then
                                local x, y, z = target.Transform:GetWorldPosition()
                                fx.Transform:SetPosition(x, y, z)
                                fx.Transform:SetScale(0.7, 0.7, 0.7)
                            end
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._suansuancao_attack_handler)

                -- 食用酸味食物
                owner._suansuancao_eat_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "suansuancao") then return end
                    local food = data and data.food
                    if not food then return end
                    local prefab = food.prefab or ""
                    
                    -- 判断酸味食物：浆果、石榴、西红柿、柠檬汁等
                    if prefab:find("berry") or prefab:find("berries") or prefab:find("pomegranate") 
                        or prefab:find("tomato") or prefab:find("citrus") or prefab:find("lemon") then
                        
                        -- 回复量翻倍
                        if food.components.edible then
                            local h = food.components.edible:GetHealth(owner) or 0
                            local s = food.components.edible:GetSanity(owner) or 0
                            local hu = food.components.edible:GetHunger(owner) or 0
                            if h > 0 and owner.components.health then owner.components.health:DoDelta(h, false, "suansuancao") end
                            if s > 0 and owner.components.sanity then owner.components.sanity:DoDelta(s, false, "suansuancao") end
                            if hu > 0 and owner.components.hunger then owner.components.hunger:DoDelta(hu, false, "suansuancao") end
                        end

                        -- 10秒加速
                        local hh = owner.components.hh_player
                        if hh then
                            if not owner._suansuancao_speed_active then
                                owner._suansuancao_speed_active = true
                                hh:AddEffectValueByKey("addSpeedPercent", 15)
                            end
                            if owner._suansuancao_speed_task then
                                owner._suansuancao_speed_task:Cancel()
                            end
                            owner._suansuancao_speed_task = owner:DoTaskInTime(10, function()
                                if owner:IsValid() then
                                    owner._suansuancao_speed_active = nil
                                    owner._suansuancao_speed_task = nil
                                    if owner.components.hh_player then
                                        owner.components.hh_player:ReduceEffectValueByKey("addSpeedPercent", 15)
                                    end
                                end
                            end)
                        end

                        if owner.components.talker then
                            owner.components.talker:Say("好酸！但是更有劲了！")
                        end
                    end
                end
                owner:ListenForEvent("oneat", owner._suansuancao_eat_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "suansuancao", "Legend_SUANSUANCAO", 1)
            if not _G.Moon_HasEffect(owner, "suansuancao") then
                if owner._suansuancao_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._suansuancao_attack_handler)
                    owner._suansuancao_attack_handler = nil
                end
                if owner._suansuancao_eat_handler then
                    owner:RemoveEventCallback("oneat", owner._suansuancao_eat_handler)
                    owner._suansuancao_eat_handler = nil
                end
                if owner._suansuancao_speed_task then
                    owner._suansuancao_speed_task:Cancel()
                    owner._suansuancao_speed_task = nil
                end
                if owner._suansuancao_speed_active then
                    local hh = owner.components.hh_player
                    if hh then
                        hh:ReduceEffectValueByKey("addSpeedPercent", 15)
                    end
                    owner._suansuancao_speed_active = nil
                end
                owner._suansuancao_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_SUANSUANCAO", 0.01)
end)
