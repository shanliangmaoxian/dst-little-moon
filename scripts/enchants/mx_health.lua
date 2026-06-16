-- 小月亮 附魔：毛旭
-- 血量上限+200 (可叠加)

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_MX_HEALTH", {
        name = "毛旭",
        client_text = "毛\n旭",
        desc = "geigei,带我吃鸭蛋",
        check_desc = "人物血量上限+200",
        can_add = false,
        only_one = false,           -- 可叠加
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            if not owner._mx_health_base then
                owner._mx_health_base = owner.components.health.maxhealth
            end
            _G.Moon_AddEffect(owner, "mx_health", "Legend_MX_HEALTH", 200)
            local total_bonus = _G.Moon_GetTotalEffectValue(owner, "mx_health")
            local new_max = owner._mx_health_base + total_bonus
            owner.components.health:SetMaxHealth(new_max)
            if owner._mx_health_saved_hp ~= nil then
                owner.components.health:SetCurrentHealth(math.min(owner._mx_health_saved_hp, new_max))
                owner._mx_health_saved_hp = nil
            else
                owner.components.health:DoDelta(200)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            owner._mx_health_saved_hp = owner.components.health.currenthealth
            _G.Moon_ReduceEffect(owner, "mx_health", "Legend_MX_HEALTH", 200)
            local total_bonus = _G.Moon_GetTotalEffectValue(owner, "mx_health")
            if owner._mx_health_base then
                owner.components.health:SetMaxHealth(owner._mx_health_base + total_bonus)
            end
        end,
    })

    -- 精英/Boss 掉落 (3%)
    _G.Moon_RegisterEnchantDrop("Legend_MX_HEALTH", 0.01)
end)
