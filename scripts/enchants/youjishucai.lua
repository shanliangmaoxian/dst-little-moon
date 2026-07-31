-- 小月亮 附魔：有机蔬菜
-- 有机蔬菜的盛宴 — 吃料理有几率获得双倍效果
-- 吃锅料理(preparedfood)20%几率:血量/饥饿/理智回复翻倍

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- 触发概率：20%
local TRIGGER_CHANCE = 0.2

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    _G.AddSpecialEquipEffect("Legend_YOUJISHUCAI", {
        name = "有机蔬菜",
        client_text = "有机\n蔬菜",
        desc = "吃料理20%几率双倍效果\n(血量/饥饿/理智回复×2)",
        check_desc = "有机蔬菜的盛宴！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.4, 0.9, 0.3, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "youjishucai", "Legend_YOUJISHUCAI", 1)
            if not owner._youjishucai_hooked then
                owner._youjishucai_hooked = true

                -- 吃料理：20%几率双倍效果（补一份三围收益）
                owner._youjishucai_eat_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "youjishucai") then return end
                    local food = data and data.food
                    if not food or not food:IsValid() then return end
                    -- 只对锅料理生效
                    if not food:HasTag("preparedfood") then return end
                    if math.random() > TRIGGER_CHANCE then return end

                    if food.components.edible then
                        local h = food.components.edible:GetHealth(owner) or 0
                        local s = food.components.edible:GetSanity(owner) or 0
                        local hu = food.components.edible:GetHunger(owner) or 0
                        -- 只补正收益，负面效果不翻倍
                        if h > 0 and owner.components.health then
                            owner.components.health:DoDelta(h, false, "youjishucai")
                        end
                        if s > 0 and owner.components.sanity then
                            owner.components.sanity:DoDelta(s, false, "youjishucai")
                        end
                        if hu > 0 and owner.components.hunger then
                            owner.components.hunger:DoDelta(hu, false, "youjishucai")
                        end
                    end

                    if owner.components.talker then
                        owner.components.talker:Say("有机蔬菜的盛宴！")
                    end
                end
                owner:ListenForEvent("oneat", owner._youjishucai_eat_handler)
            end
        end,

        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "youjishucai", "Legend_YOUJISHUCAI", 1)
            if not _G.Moon_HasEffect(owner, "youjishucai") then
                if owner._youjishucai_eat_handler then
                    owner:RemoveEventCallback("oneat", owner._youjishucai_eat_handler)
                    owner._youjishucai_eat_handler = nil
                end
                owner._youjishucai_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_YOUJISHUCAI", 0.01)
end)
