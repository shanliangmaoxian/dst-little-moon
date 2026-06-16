-- 小月亮 附魔：千月野
-- 娱乐属性：夜晚星光萤火虫特效（微弱照明），小动物跟随，满月随机变身小动物外观

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_QIANYUE", {
        name = "千月野",
        client_text = "千\n月",
        desc = "夜晚身边环绕星光和萤火虫\n小动物靠近时自动跟随你\n满月之夜随机变身小动物外观15秒\n～",
        check_desc = "月夜奇趣～",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "qianyue", "Legend_QIANYUE", 1)
            if not owner._qianyue_hooked then
                owner._qianyue_hooked = true
                owner._qianyue_transformed = false

                -- 夜间粒子特效 + 微弱照明
                owner._qianyue_night_task = owner:DoPeriodicTask(2, function()
                    if not _G.Moon_HasEffect(owner, "qianyue") then return end
                    local is_night = GLOBAL.TheWorld.state.isnight

                    if is_night then
                        -- 星光粒子
                        if GLOBAL.SpawnPrefab then
                            local x, y, z = owner.Transform:GetWorldPosition()
                            for _ = 1, 2 do
                                local fx = GLOBAL.SpawnPrefab("fireflies")
                                if fx then
                                    fx.Transform:SetPosition(
                                        x + math.random() * 4 - 2,
                                        y + math.random() * 2,
                                        z + math.random() * 4 - 2
                                    )
                                    fx:DoTaskInTime(3, function()
                                        if fx:IsValid() then fx:Remove() end
                                    end)
                                end
                            end
                        end

                        -- 微弱照明
                        if not owner._qianyue_light then
                            if owner.components.playervision then
                                -- 给玩家一个小光晕
                                owner._qianyue_light = true
                                -- 通过添加一个光源来实现
                                local light = GLOBAL.SpawnPrefab("fireflies")
                                if light then
                                    light.Transform:SetPosition(0, 0, 0)
                                    if light.components.follower then
                                        light.components.follower:FollowSymbol(
                                            owner.GUID, "", 0, 0.5, 0
                                        )
                                    end
                                    owner._qianyue_light_ent = light
                                end
                            end
                        end
                    else
                        -- 白天移除照明
                        if owner._qianyue_light_ent and owner._qianyue_light_ent:IsValid() then
                            owner._qianyue_light_ent:Remove()
                            owner._qianyue_light_ent = nil
                        end
                        owner._qianyue_light = nil
                    end
                end)

                -- 小动物跟随
                owner._qianyue_animal_task = owner:DoPeriodicTask(3, function()
                    if not _G.Moon_HasEffect(owner, "qianyue") then return end
                    local x, y, z = owner.Transform:GetWorldPosition()
                    local small_animals = GLOBAL.TheSim:FindEntities(x, y, z, 8,
                        { "rabbit", "butterfly", "perd", "bee" })
                    for _, animal in ipairs(small_animals) do
                        if animal:GetDistanceSqToPoint(x, y, z) < 9 then
                            -- 让小动物靠近玩家（通过传送一小段距离）
                            if animal.components.follower and not animal.components.follower.leader then
                                -- 尝试让它跟随
                                animal.components.follower:SetLeader(owner)
                                -- 5秒后释放
                                animal:DoTaskInTime(5, function()
                                    if animal:IsValid() and animal.components.follower then
                                        animal.components.follower:SetLeader(nil)
                                    end
                                end)
                            end
                        end
                    end
                end)

                -- 满月变身小动物外观（纯娱乐）
                owner._qianyue_moon_task = owner:DoPeriodicTask(10, function()
                    if not _G.Moon_HasEffect(owner, "qianyue") then return end
                    if owner._qianyue_transformed then return end
                    local is_fullmoon = GLOBAL.TheWorld.state.isfullmoon
                    if not is_fullmoon then return end

                    -- 随机变身外观（仅改scale模拟）
                    owner._qianyue_transformed = true
                    local old_scale = owner.Transform:GetScale()
                    local animals = { 0.6, 0.8, 1.3, 1.6, 0.5, 1.8 }
                    local new_scale = animals[math.random(#animals)]
                    owner.Transform:SetScale(new_scale, new_scale, new_scale)

                    if owner.components.talker then
                        local msgs = { "变成小兔叽了！", "咦我怎么变大了？", "月野之力！", "呱！" }
                        owner.components.talker:Say(msgs[math.random(#msgs)])
                    end

                    -- 15秒后恢复
                    owner:DoTaskInTime(15, function()
                        if owner:IsValid() then
                            owner.Transform:SetScale(old_scale, old_scale, old_scale)
                            owner._qianyue_transformed = false
                        end
                    end)
                end)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "qianyue", "Legend_QIANYUE", 1)
            if not _G.Moon_HasEffect(owner, "qianyue") then
                if owner._qianyue_night_task then
                    owner._qianyue_night_task:Cancel()
                    owner._qianyue_night_task = nil
                end
                if owner._qianyue_animal_task then
                    owner._qianyue_animal_task:Cancel()
                    owner._qianyue_animal_task = nil
                end
                if owner._qianyue_moon_task then
                    owner._qianyue_moon_task:Cancel()
                    owner._qianyue_moon_task = nil
                end
                if owner._qianyue_light_ent and owner._qianyue_light_ent:IsValid() then
                    owner._qianyue_light_ent:Remove()
                    owner._qianyue_light_ent = nil
                end
                owner._qianyue_light = nil
                owner._qianyue_transformed = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_QIANYUE", 0.01)
end)
