-- 小月亮 附魔：胖虎
-- 攻击有15%几率释放「魔音贯耳」：对周围敌人造成200点伤害。周围小动物会被吓跑。

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_PANGHU", {
        name = "胖虎",
        client_text = "胖\n虎",
        desc = "攻击有15%几率释放「魔音贯耳」\n对周围敌人造成200点伤害\n震撼威压：释放时周围小动物惊恐逃跑",
        check_desc = "我是胖虎，我是孩子王！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "panghu", "Legend_PANGHU", 1)
            if not owner._panghu_hooked then
                owner._panghu_hooked = true

                -- 攻击触发魔音贯耳
                owner._panghu_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "panghu") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end

                    if math.random() <= 0.15 then
                        local x, y, z = target.Transform:GetWorldPosition()
                        
                        -- 大范围敌人 (8码)
                        local nearby = _G.TheSim:FindEntities(x, y, z, 8, { "_combat" })
                        for _, victim in ipairs(nearby) do
                            if victim ~= owner and victim.components.health and not victim.components.health:IsDead() then
                                -- 造成200点物理伤害
                                victim.components.health:DoDelta(-200, false, owner)
                                if victim.components.talker then
                                    _G.pcall(function() victim.components.talker:Say("好难听啊！") end)
                                end
                            end
                        end

                        -- 吓跑周围小动物
                        local animals = _G.TheSim:FindEntities(x, y, z, 12, nil, { "rabbit", "butterfly", "bird", "mole", "perd", "penguin" })
                        for _, animal in ipairs(animals) do
                            if animal:IsValid() then
                                animal:PushEvent("panic")
                            end
                        end

                        -- 魔音贯耳特效 (大范围爆炸或崩溃特效)
                        if _G.SpawnPrefab then
                            local fx = _G.SpawnPrefab("sonicresonate_fx") or _G.SpawnPrefab("collapse_small")
                            if fx then
                                fx.Transform:SetPosition(x, y, z)
                                fx.Transform:SetScale(2, 2, 2)
                            end
                        end

                        if owner.components.talker then
                            owner.components.talker:Say("【魔音贯耳】我是胖虎，我是孩子王！🎵~")
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._panghu_attack_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "panghu", "Legend_PANGHU", 1)
            if not _G.Moon_HasEffect(owner, "panghu") then
                if owner._panghu_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._panghu_attack_handler)
                    owner._panghu_attack_handler = nil
                end
                owner._panghu_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_PANGHU", 0.01)
end)
