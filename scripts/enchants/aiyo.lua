-- 小月亮 附魔：哎哟
-- 受到伤害时回复所受伤害50%的生命值，并反弹80%伤害给攻击者

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_AIYO", {
        name = "哎哟",
        client_text = "哎\n哟",
        desc = "受到伤害时回复所受伤害50%的生命值\n反弹80%伤害给攻击者",
        check_desc = "哎哟，打我你也疼！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "aiyo", "Legend_AIYO", 1)
            if not owner._aiyo_hooked then
                owner._aiyo_hooked = true

                -- 勾住 health:DoDelta 来拦截受到的伤害
                local health = owner.components.health
                if health and not health._aiyo_hooked_dodelta then
                    local oldDoDelta = health.DoDelta
                    health._aiyo_old_dodelta = oldDoDelta
                    health.DoDelta = function(self, delta, overtime, cause, ...)
                        -- 只拦截伤害(负值)和非无视来源
                        if delta < 0 and cause ~= "aiyo_reflect" then
                            if _G.Moon_HasEffect(owner, "aiyo") then
                                local damage = -delta
                                -- 回复50%所受伤害
                                local heal = damage * 0.5
                                owner:DoTaskInTime(0, function()
                                    if owner:IsValid() and owner.components.health then
                                        owner.components.health:DoDelta(heal, false, "aiyo_heal")
                                    end
                                end)

                                -- 反弹80%伤害给攻击者
                                local attacker = nil
                                if owner.components.combat and owner.components.combat.lastattacker then
                                    attacker = owner.components.combat.lastattacker
                                end
                                if attacker and attacker:IsValid() and attacker.components.health
                                    and not attacker.components.health:IsDead()
                                    and attacker ~= owner then
                                    local reflect = damage * 0.8
                                    attacker.components.health:DoDelta(-reflect, false, "aiyo_reflect")
                                    -- 反弹特效
                                    if attacker.components.talker then
                                        attacker.components.talker:Say("哎哟！")
                                    end
                                end
                            end
                        end
                        return oldDoDelta(self, delta, overtime, cause, ...)
                    end
                end
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "aiyo", "Legend_AIYO", 1)
            if not _G.Moon_HasEffect(owner, "aiyo") then
                local health = owner.components.health
                if health and health._aiyo_old_dodelta then
                    health.DoDelta = health._aiyo_old_dodelta
                    health._aiyo_old_dodelta = nil
                end
                owner._aiyo_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_AIYO", 0.01)
end)
