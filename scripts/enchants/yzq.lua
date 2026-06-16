-- 小月亮 附魔：云中雀
-- 移动速度+35%，每8秒获得「翱翔」buff：下一次攻击造成350%范围伤害并击退
-- 翱翔期间免疫伤害（持续1.5秒）

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_YZQ", {
        name = "云中雀",
        client_text = "云中\n雀",
        desc = "如雀翔空，云中翱翔\n移速+35%\n每8秒获得「翱翔」buff\n下一次攻击350%范围伤害+击退\n翱翔期间免疫伤害",
        check_desc = "云中雀，自由翱翔！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "yzq", "Legend_YZQ", 1)
            if not owner._yzq_hooked then
                owner._yzq_hooked = true
                owner._yzq_soaring = false
                owner._yzq_soar_ready = false

                local hh = owner.components.hh_player

                -- 永久移速+35%
                if hh then
                    hh:AddEffectValueByKey("addSpeedPercent", 35)
                end

                -- 每8秒获得翱翔充能
                owner._yzq_soar_task = owner:DoPeriodicTask(8, function()
                    if not _G.Moon_HasEffect(owner, "yzq") then return end
                    owner._yzq_soar_ready = true
                    if owner.components.talker then
                        owner.components.talker:Say("翱翔！")
                    end
                    -- 视觉提示特效
                    if GLOBAL.SpawnPrefab then
                        local x, y, z = owner.Transform:GetWorldPosition()
                        local fx = GLOBAL.SpawnPrefab("statue_transition_2")
                        if fx then
                            fx.Transform:SetPosition(x, y + 1, z)
                        end
                    end
                end)

                -- 翱翔buff：免疫伤害 (通过 intercept 实现)
                local function activateSoaring()
                    owner._yzq_soaring = true
                    owner._yzq_soar_ready = false
                    -- 免疫伤害
                    if owner.components.health then
                        if not owner._yzq_old_dodelta and owner.components.health.DoDelta then
                            local oldDoDelta = owner.components.health.DoDelta
                            owner._yzq_old_dodelta = oldDoDelta
                            owner.components.health.DoDelta = function(self, delta, ...)
                                if owner._yzq_soaring and delta < 0 then
                                    return -- 免疫伤害
                                end
                                return oldDoDelta(self, delta, ...)
                            end
                        end
                    end
                    -- 1.5秒后结束
                    owner:DoTaskInTime(1.5, function()
                        if owner:IsValid() then
                            owner._yzq_soaring = false
                        end
                    end)
                end

                -- 攻击时检查翱翔
                owner._yzq_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "yzq") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end

                    if owner._yzq_soar_ready then
                        activateSoaring()

                        -- 350% 范围伤害
                        local tx, ty, tz = target.Transform:GetWorldPosition()
                        local nearby = GLOBAL.TheSim:FindEntities(tx, ty, tz, 4, { "_combat" })
                        for _, victim in ipairs(nearby) do
                            if victim ~= owner and victim.components.health and not victim.components.health:IsDead() then
                                local dmg = (owner.components.combat and owner.components.combat.defaultdamage) or 34
                                victim.components.health:DoDelta(-dmg * 3.5, false, nil)
                                -- 击退
                                if victim.components.locomotor and victim ~= target then
                                    local vx, vy, vz = victim.Transform:GetWorldPosition()
                                    local dx, dz = vx - tx, vz - tz
                                    local dist = math.sqrt(dx * dx + dz * dz) or 1
                                    local knock = 4
                                    victim.Transform:SetPosition(vx + dx / dist * knock, vy, vz + dz / dist * knock)
                                end
                            end
                        end

                        -- 特效
                        if GLOBAL.SpawnPrefab then
                            local fx = GLOBAL.SpawnPrefab("collapse_small")
                            if fx then
                                fx.Transform:SetPosition(tx, ty, tz)
                                fx.Transform:SetScale(1.5, 1.5, 1.5)
                            end
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._yzq_attack_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "yzq", "Legend_YZQ", 1)
            if not _G.Moon_HasEffect(owner, "yzq") then
                -- 恢复 speed
                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("addSpeedPercent", 35)
                end
                -- 恢复 DoDelta
                if owner._yzq_old_dodelta and owner.components.health then
                    owner.components.health.DoDelta = owner._yzq_old_dodelta
                    owner._yzq_old_dodelta = nil
                end
                if owner._yzq_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._yzq_attack_handler)
                    owner._yzq_attack_handler = nil
                end
                if owner._yzq_soar_task then
                    owner._yzq_soar_task:Cancel()
                    owner._yzq_soar_task = nil
                end
                owner._yzq_soaring = nil
                owner._yzq_soar_ready = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_YZQ", 0.01)
end)
