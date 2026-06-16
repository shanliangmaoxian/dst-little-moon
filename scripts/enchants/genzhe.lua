-- 小月亮 附魔：我就跟着混
-- 周围15码内有队友：+20%伤害、+15%移速、减伤+30%
-- 队友击杀敌人时30%几率你也获得额外掉落

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_GENZHE", {
        name = "我就跟着混",
        client_text = "跟\n着",
        desc = "周围15码内有队友时：\n+20%伤害、+15%移速、减伤+30%\n队友击杀敌人时30%几率你也获得掉落",
        check_desc = "混子也是技术活！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "genzhe", "Legend_GENZHE", 1)
            if not owner._genzhe_hooked then
                owner._genzhe_hooked = true
                owner._genzhe_near_teammate = false
                owner._genzhe_applied = false

                -- 检测附近是否有队友
                local function hasNearbyTeammate()
                    local x, y, z = owner.Transform:GetWorldPosition()
                    for _, v in ipairs(GLOBAL.AllPlayers) do
                        if v ~= owner and v:IsValid() and v:GetDistanceSqToPoint(x, y, z) < 225 then
                            return true
                        end
                    end
                    return false
                end

                -- 应用队友buff
                local function applyTeammateBuffs()
                    if owner._genzhe_applied then return end
                    owner._genzhe_applied = true
                    local hh = owner.components.hh_player
                    if hh then
                        hh:AddEffectValueByKey("addComDamagePercent", 20)
                        hh:AddEffectValueByKey("addSpeedPercent", 15)
                        hh:AddEffectValueByKey("absorbDamage", 30)
                    end
                end

                -- 移除队友buff
                owner._genzhe_removeBuffs = function()
                    if not owner._genzhe_applied then return end
                    owner._genzhe_applied = false
                    local hh = owner.components.hh_player
                    if hh then
                        hh:ReduceEffectValueByKey("addComDamagePercent", 20)
                        hh:ReduceEffectValueByKey("addSpeedPercent", 15)
                        hh:ReduceEffectValueByKey("absorbDamage", 30)
                    end
                end

                -- 每3秒检测队友距离
                owner._genzhe_check_task = owner:DoPeriodicTask(3, function()
                    if not _G.Moon_HasEffect(owner, "genzhe") then return end
                    if hasNearbyTeammate() then
                        applyTeammateBuffs()
                    else
                        owner._genzhe_removeBuffs()
                    end
                end)

                -- 队友击杀掉落：监听周围实体的死亡
                owner._genzhe_kill_task = owner:DoPeriodicTask(2, function()
                    if not _G.Moon_HasEffect(owner, "genzhe") then return end
                    if not owner._genzhe_applied then return end
                    if math.random() > 0.3 then return end

                    -- 扫描周围刚死的实体
                    local x, y, z = owner.Transform:GetWorldPosition()
                    local ents = GLOBAL.TheSim:FindEntities(x, y, z, 20)
                    for _, ent in ipairs(ents) do
                        if ent:IsValid() and ent ~= owner
                            and ent.components.health and ent.components.health:IsDead() then
                            -- 检查击杀者是否是附近队友
                            local killer = nil
                            if ent.components.combat and ent.components.combat.lastattacker then
                                killer = ent.components.combat.lastattacker
                            end
                            if killer and killer:IsValid() and killer:HasTag("player")
                                and killer ~= owner and killer:GetDistanceSqToPoint(x, y, z) < 225 then
                                -- 队友击杀，掉落一件物品
                                if ent.components.lootdropper and not ent._genzhe_looted then
                                    ent.components.lootdropper:DropLoot(ent.Transform:GetWorldPosition())
                                    ent._genzhe_looted = true
                                    break
                                end
                            end
                        end
                    end
                end)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "genzhe", "Legend_GENZHE", 1)
            if not _G.Moon_HasEffect(owner, "genzhe") then
                if owner._genzhe_check_task then
                    owner._genzhe_check_task:Cancel()
                    owner._genzhe_check_task = nil
                end
                if owner._genzhe_kill_task then
                    owner._genzhe_kill_task:Cancel()
                    owner._genzhe_kill_task = nil
                end
                if owner._genzhe_removeBuffs then
                    owner._genzhe_removeBuffs()
                end
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_GENZHE", 0.01)
end)
