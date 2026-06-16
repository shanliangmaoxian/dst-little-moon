-- 小月亮 附魔：紫蝶
-- 破茧成蝶：受到致命伤害时免疫死亡，满血复活，冷却1天

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_ZD_BUTTERFLY", {
        name = "紫蝶",
        client_text = "紫\n蝶",
        desc = "蝶破茧，人不灭",
        check_desc = "受到致命伤害时免疫死亡\n满血复活 冷却1天",
        can_add = false,
        only_one = true,                -- 唯一
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "zd_butterfly", "Legend_ZD_BUTTERFLY", 1)
            if not owner._zd_death_hook_installed then
                owner._zd_death_hook_installed = true
                owner._zd_revive_cooldown = false

                local oldPushEvent = owner.PushEvent
                owner.PushEvent = function(self, event, ...)
                    if _G.Moon_HasEffect(self, "zd_butterfly") and not self._zd_revive_cooldown then
                        if event == "death" then
                            local health = self.components.health
                            if health then
                                health:SetVal(health.maxhealth)
                                self:PushEvent("respawnfromghost")
                                self._zd_revive_cooldown = true
                                if self._zd_cooldown_task then
                                    self._zd_cooldown_task:Cancel()
                                end
                                -- 1天(480秒)冷却
                                self._zd_cooldown_task = self:DoTaskInTime(480, function()
                                    self._zd_revive_cooldown = false
                                end)
                                if self.components.talker then
                                    self.components.talker:Say("紫蝶护主，破茧重生！")
                                end
                                return
                            end
                        end
                        if event == "makeplayerghost" then
                            return
                        end
                    end
                    return oldPushEvent(self, event, ...)
                end
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "zd_butterfly", "Legend_ZD_BUTTERFLY", 1)
        end,
    })

    -- 精英/Boss 掉落 (3%)
    _G.Moon_RegisterEnchantDrop("Legend_ZD_BUTTERFLY", 0.03)
end)
