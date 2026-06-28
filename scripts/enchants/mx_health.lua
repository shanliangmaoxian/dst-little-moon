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
            _G.Moon_AddEffect(owner, "mx_health", "Legend_MX_HEALTH", 200)
            if owner:IsValid() and owner.components.health then
                local old_percent = owner.components.health:GetPercent()
                owner.components.health.maxhealth = math.min(owner.components.health.maxhealth + 200, 60000)
                owner.components.health:SetPercent(old_percent)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "mx_health", "Legend_MX_HEALTH", 200)
            if owner:IsValid() and owner.components.health then
                local old_percent = owner.components.health:GetPercent()
                owner.components.health.maxhealth = math.max(owner.components.health.maxhealth - 200, 1)
                owner.components.health:SetPercent(old_percent)
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_MX_HEALTH", 0.01)
end)
