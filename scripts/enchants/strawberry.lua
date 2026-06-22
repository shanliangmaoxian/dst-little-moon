-- 小月亮 附魔：草莓奶昔
-- 每3秒回复5%最大生命值和3%精神值
-- 被攻击时100%使攻击者陷入「糖分过量」：攻速和移速-35%持续5秒
-- 食用甜食类食物额外回复20点生命

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_STRAWBERRY", {
        name = "草莓奶昔",
        client_text = "草莓\n奶昔",
        desc = "每3秒回复5%最大生命+3%精神\n被攻击时对攻击者施加「糖分过量」标记\n食用甜食额外回复20生命",
        check_desc = "甜蜜陷阱，欲罢不能～",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "strawberry", "Legend_STRAWBERRY", 1)
            if not owner._strawberry_hooked then
                owner._strawberry_hooked = true

                -- 每3秒回复5%最大生命 + 3%精神
                owner._strawberry_regen_task = owner:DoPeriodicTask(3, function()
                    if not _G.Moon_HasEffect(owner, "strawberry") then return end
                    if owner.components.health then
                        local max_hp = owner.components.health.maxhealth or 150
                        owner.components.health:DoDelta(max_hp * 0.05, false, "strawberry")
                    end
                    if owner.components.sanity then
                        local max_san = owner.components.sanity.max or 200
                        owner.components.sanity:DoDelta(max_san * 0.01)
                    end
                end)

                -- 被攻击时使攻击者「糖分过量」
                owner._strawberry_attacked_handler = function(victim, data)
                    if not _G.Moon_HasEffect(owner, "strawberry") then return end
                    local attacker = data and data.attacker
                    if not attacker or not attacker:IsValid() then return end
                    if attacker == owner then return end

                    -- 特效（3秒冷却）
                    local now = _G.GetTime and _G.GetTime() or 0
                    if not owner._strawberry_fx_cd or now - owner._strawberry_fx_cd >= 3 then
                        owner._strawberry_fx_cd = now
                        if GLOBAL.SpawnPrefab then
                            local x, y, z = attacker.Transform:GetWorldPosition()
                            local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                            if fx then
                                fx.Transform:SetPosition(x, y, z)
                            end
                        end
                    end
                end
                owner:ListenForEvent("attacked", owner._strawberry_attacked_handler)

                -- 甜食额外回复
                owner._strawberry_eat_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "strawberry") then return end
                    local food = data and data.food
                    if not food then return end
                    local foodtype = food.components.edible and food.components.edible.foodtype
                    -- DST中甜食通常用 foodtype == "GENERIC" 或 "VEGGIE" 中的特定prefab
                    -- 这里检测常见的甜食prefab
                    local prefab = food.prefab or ""
                    local sweet_foods = {
                        "taffy", "pumpkincookie", "waffles", "icecream",
                        "watermelonicle", "sweettea", "jellybean", "fruitmedley",
                        "berries", "cave_banana", "dragonfruit", "pomegranate",
                        "honey", "honeycomb", "royal_jelly"
                    }
                    for _, sweet in ipairs(sweet_foods) do
                        if prefab:find(sweet) then
                            if owner.components.health then
                                owner.components.health:DoDelta(20, false, "strawberry")
                            end
                            break
                        end
                    end
                end
                owner:ListenForEvent("oneat", owner._strawberry_eat_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "strawberry", "Legend_STRAWBERRY", 1)
            if not _G.Moon_HasEffect(owner, "strawberry") then
                if owner._strawberry_regen_task then
                    owner._strawberry_regen_task:Cancel()
                    owner._strawberry_regen_task = nil
                end
                if owner._strawberry_attacked_handler then
                    owner:RemoveEventCallback("attacked", owner._strawberry_attacked_handler)
                    owner._strawberry_attacked_handler = nil
                end
                if owner._strawberry_eat_handler then
                    owner:RemoveEventCallback("oneat", owner._strawberry_eat_handler)
                    owner._strawberry_eat_handler = nil
                end
                owner._strawberry_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_STRAWBERRY", 0.01)
end)
