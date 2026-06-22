-- 小月亮 附魔：心平气和
-- 娱乐属性：花瓣羽毛特效，小动物亲近，5%让敌人发呆2秒，佛系台词

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_XPING", {
        name = "心平气和",
        client_text = "心平\n气和",
        desc = "每15秒飘落花瓣和羽毛特效\n小动物不会逃跑 主动靠近你\n被攻击时5%让敌人发呆2秒\n被攻击时随机说佛系台词～",
        check_desc = "佛了佛了～",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "xping", "Legend_XPING", 1)
            if not owner._xping_hooked then
                owner._xping_hooked = true

                -- 持续飘落花瓣/羽毛特效
                owner._xping_petal_task = owner:DoPeriodicTask(15, function()
                    if not _G.Moon_HasEffect(owner, "xping") then return end
                    if GLOBAL.SpawnPrefab then
                        local x, y, z = owner.Transform:GetWorldPosition()
                        local petals = { "petals", "feather_robin", "feather_crow" }
                        local petal = GLOBAL.SpawnPrefab(petals[math.random(#petals)])
                        if petal then
                            petal.Transform:SetPosition(
                                x + math.random() * 3 - 1.5,
                                y + 2 + math.random() * 2,
                                z + math.random() * 3 - 1.5
                            )
                            -- 缓慢下落
                            if petal.Physics then
                                petal.Physics:SetVel(
                                    math.random() * 0.5 - 0.25,
                                    -0.3 - math.random() * 0.5,
                                    math.random() * 0.5 - 0.25
                                )
                            end
                            petal:DoTaskInTime(4, function()
                                if petal:IsValid() then petal:Remove() end
                            end)
                        end
                    end
                end)

                -- 小动物不逃跑 + 主动靠近
                owner._xping_animal_task = owner:DoPeriodicTask(5, function()
                    if not _G.Moon_HasEffect(owner, "xping") then return end
                    local x, y, z = owner.Transform:GetWorldPosition()
                    local critters = GLOBAL.TheSim:FindEntities(x, y, z, 6,
                        { "rabbit", "butterfly", "perd", "bee", "mole" })
                    for _, critter in ipairs(critters) do
                        if critter.components.follower and not critter.components.follower.leader then
                            critter.components.follower:SetLeader(owner)
                            critter:DoTaskInTime(4, function()
                                if critter:IsValid() and critter.components.follower then
                                    critter.components.follower:SetLeader(nil)
                                end
                            end)
                        end
                    end
                end)

                -- 被攻击时5%让敌人发呆 + 佛系台词
                owner._xping_attacked_handler = function(victim, data)
                    if not _G.Moon_HasEffect(owner, "xping") then return end
                    local attacker = data and data.attacker
                    if not attacker or not attacker:IsValid() then return end
                    if attacker == owner then return end

                    -- 佛系台词
                    if owner.components.talker then
                        local quotes = {
                            "算了算了～",
                            "不跟他计较",
                            "心平气和",
                            "阿弥陀佛",
                            "一切随缘～",
                            "淡定淡定",
                        }
                        owner.components.talker:Say(quotes[math.random(#quotes)])
                    end

                    -- 5%让敌人发呆2秒
                    if math.random() <= 0.05 and attacker.components.combat then
                        local old_target = attacker.components.combat.target
                        attacker.components.combat:SetTarget(nil)
                        -- 暂停攻击2秒
                        attacker:DoTaskInTime(2, function()
                            if attacker:IsValid() and attacker.components.combat
                                and old_target and old_target:IsValid() then
                                attacker.components.combat:SetTarget(old_target)
                            end
                        end)
                        -- 发呆特效
                        if GLOBAL.SpawnPrefab then
                            local ax, ay, az = attacker.Transform:GetWorldPosition()
                            local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                            if fx then
                                fx.Transform:SetPosition(ax, ay, az)
                            end
                        end
                        if attacker.components.talker then
                            attacker.components.talker:Say("...？")
                        end
                    end
                end
                owner:ListenForEvent("attacked", owner._xping_attacked_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "xping", "Legend_XPING", 1)
            if not _G.Moon_HasEffect(owner, "xping") then
                if owner._xping_petal_task then
                    owner._xping_petal_task:Cancel()
                    owner._xping_petal_task = nil
                end
                if owner._xping_animal_task then
                    owner._xping_animal_task:Cancel()
                    owner._xping_animal_task = nil
                end
                if owner._xping_attacked_handler then
                    owner:RemoveEventCallback("attacked", owner._xping_attacked_handler)
                    owner._xping_attacked_handler = nil
                end
                owner._xping_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_XPING", 0.01)
end)
