-- 小月亮 附魔：劳动最光荣
-- 吃烤土豆获得（135保底）
-- 效果：快采、快速制作、烹饪秒出锅、劳动中20%概率获得藏宝图

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

-- =========================================================
-- 135烤土豆保底计数（独立于 HH 框架，无条件注册）
-- 避免在部署环境中 Moon_IsHHEnabled() 返回 false 导致计数器不生效
-- =========================================================
local _ldg_potato_counter = {}

AddPrefabPostInitAny(function(inst2)
    if not _G.TheWorld.ismastersim then return end
    if not inst2:HasTag("player") then return end

    inst2:ListenForEvent("oneat", function(_, data)
        local food = data and data.food
        if not food or not food:IsValid() then return end
        if food.prefab ~= "potato_cooked" then return end

        local userid = inst2.userid
        if not userid then return end

        _ldg_potato_counter[userid] = (_ldg_potato_counter[userid] or 0) + 1
        local count = _ldg_potato_counter[userid]

        if count >= 135 then
            -- HHSpawnStoneById 可能不存在（HH框架未启用），用 pcall 兜一下
            local success, stone = _G.pcall(_G.HHSpawnStoneById, "Legend_LDG")
            if success and stone and inst2.components.inventory then
                inst2.components.inventory:GiveItem(stone, nil, inst2:GetPosition())
                if inst2.components.talker then
                    inst2.components.talker:Say("劳动最光荣！吃了135个烤土豆，获得劳动附魔石！")
                end
            end
            _ldg_potato_counter[userid] = 0
        elseif count % 15 == 0 and inst2.components.talker then
            inst2.components.talker:Say("吃了" .. count .. "个烤土豆，再吃" .. (135 - count) .. "个保底劳动附魔石！")
        end
    end)
end)

-- =========================================================
-- 以下内容需要 HH 附魔框架
-- =========================================================
if not CFG.ENABLE_MORE_ENCHANTS then return end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    -- 烹饪秒出锅：hook StartCooking，调用完原始函数强制 cooktime=0（下一帧自动触发完成）
    local _ldg_cook_hooked = false
    if not _ldg_cook_hooked then
        _ldg_cook_hooked = true

        local function hookCookPot(cookpot)
            if not _G.TheWorld.ismastersim then return end
            if not cookpot.components.stewer then return end

            local old_start = cookpot.components.stewer.StartCooking
            cookpot.components.stewer.StartCooking = function(self, doer)
                local result = old_start(self, doer)
                if self:IsCooking() and doer and doer:IsValid() and doer:HasTag("player")
                    and _G.Moon_HasEffect(doer, "laodong") then
                    self.cooktime = 0
                end
                return result
            end
        end

        AddPrefabPostInit("cookpot", hookCookPot)
        AddPrefabPostInit("portablecookpot", hookCookPot)
    end

    -- 附魔注册
    GLOBAL.AddSpecialEquipEffect("Legend_LDG", {
        name = "劳动最光荣",
        client_text = "劳动\n光荣",
        desc = "劳动最光荣！\n● 秒采：采集/砍伐/挖掘瞬间完成\n● 秒制作：建筑/制作瞬间完成\n● 秒出锅：放入食材即出锅\n● 劳动有喜：劳动中20%概率获得藏宝图",
        check_desc = "吃烤土豆获得（135保底），劳动最光荣！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "laodong", "Legend_LDG", 1)
            if not owner._ldg_hooked then
                owner._ldg_hooked = true
                local hh = owner.components.hh_player

                -- 1) 快采：工作效率+100倍（真正的秒完成）
                if hh then
                    hh:AddEffectValueByKey("workAddSpeed", 100)
                end

                -- 2) 秒制作
                if owner.components.builder then
                    owner._ldg_old_buildtime = owner.components.builder.buildingtime or 1
                    owner.components.builder.buildingtime = 0.001
                end

                -- 3) 劳动中20%获得藏宝图（完成工作）
                owner._ldg_work_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "laodong") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end
                    if math.random() > 0.2 then return end

                    local tally = _G.SpawnPrefab("hh_treasure_tally")
                    if tally and owner.components.inventory then
                        owner.components.inventory:GiveItem(tally, nil, owner:GetPosition())
                        if owner.components.talker then
                            owner.components.talker:Say("劳动最光荣！挖到一张藏宝图！")
                        end
                    end
                end
                owner:ListenForEvent("finishedwork", owner._ldg_work_handler)

                -- 3b) 采摘也有概率获得藏宝图
                owner._ldg_pick_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "laodong") then return end
                    if not data or not data.loot then return end
                    if math.random() > 0.2 then return end

                    local tally = _G.SpawnPrefab("hh_treasure_tally")
                    if tally and owner.components.inventory then
                        owner.components.inventory:GiveItem(tally, nil, owner:GetPosition())
                        if owner.components.talker then
                            owner.components.talker:Say("劳动最光荣！采到一张藏宝图！")
                        end
                    end
                end
                owner:ListenForEvent("picksomething", owner._ldg_pick_handler)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "laodong", "Legend_LDG", 1)
            if not _G.Moon_HasEffect(owner, "laodong") then
                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("workAddSpeed", 100)
                end

                -- 恢复制作速度
                if owner.components.builder and owner._ldg_old_buildtime then
                    owner.components.builder.buildingtime = owner._ldg_old_buildtime
                    owner._ldg_old_buildtime = nil
                end

                -- 移除事件
                if owner._ldg_work_handler then
                    owner:RemoveEventCallback("finishedwork", owner._ldg_work_handler)
                    owner._ldg_work_handler = nil
                end
                if owner._ldg_pick_handler then
                    owner:RemoveEventCallback("picksomething", owner._ldg_pick_handler)
                    owner._ldg_pick_handler = nil
                end

                owner._ldg_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_LDG", 0.01)
end)
