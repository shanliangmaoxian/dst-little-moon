-- 小月亮 附魔：良弓藏
-- 飞鸟尽，良弓藏 — 自身伤害-100%，每3秒自动射箭攻击最近敌人
-- 每箭造成300%攻击力伤害，遵循"藏弓待发"之意

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_LIANGGONG", {
        name = "良弓藏",
        client_text = "良弓\n藏",
        desc = "自身伤害-100%\n每3秒自动射箭攻击最近敌人(300%伤害)\n飞鸟尽，良弓藏…",
        check_desc = "弓藏箭犹发，万物皆可杀！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "lianggongcang", "Legend_LIANGGONG", 1)
            if not owner._lianggong_hooked then
                owner._lianggong_hooked = true

                -- 自身伤害-100%
                local hh = owner.components.hh_player
                if hh then
                    hh:AddEffectValueByKey("addComDamagePercent", -100)
                end

                -- 每3秒自动射箭
                owner._lianggong_auto_task = owner:DoPeriodicTask(3, function()
                    if not _G.Moon_HasEffect(owner, "lianggongcang") then return end
                    if not owner:IsValid() then return end

                    local x, y, z = owner.Transform:GetWorldPosition()
                    -- 找最近的敌人
                    local enemies = _G.TheSim:FindEntities(x, y, z, 15, { "_combat" })
                    local nearest = nil
                    local nearest_dist = 999999

                    for _, e in ipairs(enemies) do
                        if e ~= owner and e:IsValid() and e.components.health and not e.components.health:IsDead() then
                            local ex, ey, ez = e.Transform:GetWorldPosition()
                            local dx, dz = x - ex, z - ez
                            local dist = dx * dx + dz * dz
                            if dist < nearest_dist then
                                nearest_dist = dist
                                nearest = e
                            end
                        end
                    end

                    if nearest then
                        -- 造成300%攻击力伤害
                        local dmg = (owner.components.combat and owner.components.combat.defaultdamage) or 34
                        if nearest.components.health then
                            -- 使用HH真实伤害（如果有）
                            if nearest.components.health.DoHHDelta then
                                nearest.components.health:DoHHDelta(-dmg * 3, owner, "良弓_自动箭")
                            else
                                nearest.components.health:DoDelta(-dmg * 3, false, "良弓_自动箭")
                            end
                        end

                        -- 箭矢特效
                        if _G.SpawnPrefab then
                            local fx = _G.SpawnPrefab("spear_projectile") or _G.SpawnPrefab("statue_transition")
                            if fx then
                                local tx, ty, tz = nearest.Transform:GetWorldPosition()
                                fx.Transform:SetPosition(x, y + 1.5, z)
                                -- 飞向目标
                                if fx.Physics then
                                    local dx, dz = tx - x, tz - z
                                    local dist = math.sqrt(dx * dx + dz * dz) or 1
                                    local speed = 25
                                    fx.Physics:SetVel(dx / dist * speed, 2, dz / dist * speed)
                                end
                                fx:DoTaskInTime(1, function()
                                    if fx:IsValid() then fx:Remove() end
                                end)
                            end
                        end

                        -- 飘字
                        if owner.components.talker and math.random() <= 0.3 then
                            owner.components.talker:Say("藏弓一发！")
                        end
                    end
                end)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "lianggongcang", "Legend_LIANGGONG", 1)
            if not _G.Moon_HasEffect(owner, "lianggongcang") then
                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("addComDamagePercent", -100)
                end

                if owner._lianggong_auto_task then
                    owner._lianggong_auto_task:Cancel()
                    owner._lianggong_auto_task = nil
                end

                owner._lianggong_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_LIANGGONG", 0.008)
end)
