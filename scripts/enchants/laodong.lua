-- 小月亮 附魔：劳动最光荣
-- 挖矿/砍树/采集作物/烹饪/制作各300 + 采集巨大作物50 获得
-- 效果：快采、快速制作、烹饪秒出锅、劳动中5%概率获得藏宝图
--
-- 实现原理：
--   秒采/秒交互 → HH框架 fast_act 效果（stategraph钩子）
--   秒砍挖 → 自建 stategraph 钩子 CHOP/MINE → doshortaction
--   秒制作 → builder.buildingtime = 0.001
--   秒出锅 → stewer.StartCooking 前 cooktimemult = 0.001
--   快敲击 → WorkedBy_Internal 100x 工作量
--   藏宝图 → finishedwork / picksomething 事件 5% 概率

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

-- =========================================================
-- 多维劳动保底计数（独立于 HH 框架，无条件注册）
-- 挖矿/砍树/采集作物/烹饪/制作各300 + 采集巨大作物50
-- =========================================================
local _LDG_TARGETS = { mine = 300, chop = 300, harvest = 300, cook = 15, build = 300, giant = 50 }
local _LDG_NAMES = { mine = "挖矿", chop = "砍树", harvest = "采集作物", cook = "烹饪种类", build = "制作", giant = "敲碎巨大作物" }

local function _ldg_init(inst)
    if not inst._ldg_counter then
        inst._ldg_counter = { mine = 0, chop = 0, harvest = 0, cook = {}, build = 0, giant = 0 }
    elseif type(inst._ldg_counter.cook) ~= "table" then
        -- 兼容旧存档（cook 之前是数字，现在改为表）
        inst._ldg_counter.cook = {}
    end
    return inst._ldg_counter
end

local function _ldg_check_all(inst)
    local c = inst._ldg_counter
    if not c then return end
    local cook_count = 0
    if type(c.cook) == "table" then for _ in pairs(c.cook) do cook_count = cook_count + 1 end end
    if (c.mine or 0) >= 300 and (c.chop or 0) >= 300
            and (c.harvest or 0) >= 300 and cook_count >= 15
            and (c.build or 0) >= 300 and (c.giant or 0) >= 50 then
        local success, stone = _G.pcall(_G.HHSpawnStoneById, "Legend_LDG")
        if success and stone and inst.components.inventory then
            inst.components.inventory:GiveItem(stone, nil, inst:GetPosition())
            if inst.components.talker then
                inst.components.talker:Say("劳动最光荣！六项劳动目标全部达成，获得劳动附魔石！")
            end
        end
        -- 重置所有进度
        inst._ldg_counter = { mine = 0, chop = 0, harvest = 0, cook = {}, build = 0, giant = 0 }
    end
end

local function _ldg_do_cook(inst, recipe)
    local c = _ldg_init(inst)
    if not c.cook then c.cook = {} end
    c.cook[recipe] = true
    _ldg_check_all(inst)
    -- 烹饪种类每新增5种播报一次
    local count = 0
    for _ in pairs(c.cook) do count = count + 1 end
    if count > 0 and count < _LDG_TARGETS.cook and count % 5 == 0 and inst.components.talker then
        local parts = {}
        for _, k in ipairs({ "mine", "chop", "harvest", "cook", "build", "giant" }) do
            local val
            if k == "cook" then
                val = 0
                if type(c.cook) == "table" then for _ in pairs(c.cook) do val = val + 1 end end
            else
                val = c[k] or 0
            end
            table.insert(parts, _LDG_NAMES[k] .. val .. "/" .. _LDG_TARGETS[k])
        end
        inst.components.talker:Say("劳动进度：\n" .. table.concat(parts, "\n"))
    end
end

local function _ldg_do_inc(inst, key)
    local c = _ldg_init(inst)
    local target = _LDG_TARGETS[key]
    c[key] = math.min((c[key] or 0) + 1, target)
    _ldg_check_all(inst)
    -- 全维度进度播报（每50/巨大作物10的倍数时触发）
    local count = c[key] or 0
    if count > 0 and count < target then
        local interval = (key == "giant") and 10 or 50
        if count % interval == 0 and inst.components.talker then
            local parts = {}
            for _, k in ipairs({ "mine", "chop", "harvest", "cook", "build", "giant" }) do
                local val
                if k == "cook" then
                    val = 0
                    if type(c.cook) == "table" then for _ in pairs(c.cook) do val = val + 1 end end
                else
                    val = c[k] or 0
                end
                table.insert(parts, _LDG_NAMES[k] .. val .. "/" .. _LDG_TARGETS[k])
            end
            inst.components.talker:Say("劳动进度：\n" .. table.concat(parts, "\n"))
        end
    end
end

AddPrefabPostInitAny(function(inst2)
    if not _G.TheWorld.ismastersim then return end
    if not inst2:HasTag("player") then return end

    -- 持久化：从存档恢复进度
    _ldg_init(inst2)
    local _old_OnSave = inst2.OnSave
    inst2.OnSave = function(inst, data)
        if _old_OnSave then _old_OnSave(inst, data) end
        if inst._ldg_counter then
            local t = {}
            for k, v in pairs(inst._ldg_counter) do t[k] = v end
            data._ldg_counter = t
        end
    end
    local _old_OnLoad = inst2.OnLoad
    inst2.OnLoad = function(inst, data)
        if _old_OnLoad then _old_OnLoad(inst, data) end
        if data and data._ldg_counter then
            inst._ldg_counter = {}
            for k, v in pairs(data._ldg_counter) do inst._ldg_counter[k] = v end
            -- 兼容旧存档（cook 之前是数字，现在改为表）
            if type(inst._ldg_counter.cook) ~= "table" then
                inst._ldg_counter.cook = {}
            end
        end
    end

    -- 挖矿 / 砍树 / 制作 / 敲击巨大作物
    inst2:ListenForEvent("finishedwork", function(_, data)
        if not data or not data.target then return end
        local action = data.action
        if not action then return end

        local key = nil
        if action == _G.ACTIONS.MINE then
            key = "mine"
        elseif action == _G.ACTIONS.CHOP then
            key = "chop"
        elseif action == _G.ACTIONS.BUILD then
            key = "build"
        elseif action == _G.ACTIONS.HAMMER and data.target.prefab
                and string.find(data.target.prefab, "farm_plant") then
            key = "giant"
        end

        if key then
            _ldg_do_inc(inst2, key)
        end
    end)

    -- 采集作物 / 普通采集（草/树枝/浆果/农场作物）
    inst2:ListenForEvent("picksomething", function(_, data)
        if not data or not data.loot then return end
        local loot = data.loot
        if loot == nil then return end
        if type(loot) == "userdata" and not loot:IsValid() then return end

        local pickable = data.pickable
        if pickable and pickable.inst and pickable.inst:IsValid() then
            local prefab = pickable.inst.prefab or ""
            if string.find(prefab, "farm_plant") then
                if not string.find(prefab, "giant") then
                    _ldg_do_inc(inst2, "harvest")
                end
                -- 巨大化走得是 finishedwork(HAMMER)，这里跳过
            else
                -- 普通采集（草/树枝/浆果/花朵等）
                _ldg_do_inc(inst2, "harvest")
            end
        else
            -- 没有 pickable 字段或无效时，也视为普通采集
            _ldg_do_inc(inst2, "harvest")
        end
    end)
end)

-- =========================================================
-- stewer 组件钩子：烹饪计数 + 秒出锅（合并，避免HH检测顺序问题）
-- =========================================================
AddComponentPostInit("stewer", function(self)
    -- 1. Harvest 计数（无条件注册）
    local _old_Harvest = self.Harvest
    self.Harvest = function(self, harvester, ...)
        if harvester and harvester:IsValid() and harvester:HasTag("player") then
            local recipe = tostring(self.product or "unknown")
            _ldg_do_cook(harvester, recipe)
        end
        return _old_Harvest(self, harvester, ...)
    end

    -- 2. StartCooking 秒出锅（需要 HH 附魔框架）
    if CFG.ENABLE_MORE_ENCHANTS then
        local _old_StartCooking = self.StartCooking
        self.StartCooking = function(self, doer)
            if doer and doer:IsValid() and doer:HasTag("player")
                    and _G.Moon_HasEffect(doer, "laodong") then
                self.cooktimemult = 0.001
            end
            return _old_StartCooking(self, doer)
        end
    end
end)

-- =========================================================
-- 以下内容需要 HH 附魔框架
-- =========================================================
if not CFG.ENABLE_MORE_ENCHANTS then return end

-- =========================================================
-- 1. workable 组件钩子 — 敲击 100x（保持原版砍树/挖矿动画）
-- =========================================================
AddComponentPostInit("workable", function(self)
    local old_fn = self["WorkedBy_Internal"]
    self["WorkedBy_Internal"] = function(self, worker, numworks, ...)
        if worker and worker:IsValid() and worker:HasTag("player")
                and _G.Moon_HasEffect(worker, "laodong")
                and self["action"] ~= _G.ACTIONS["HAMMER"] then
            numworks = (numworks or 1) * 100
        end
        return old_fn(self, worker, numworks, ...)
    end
end)

-- =========================================================
-- 2. 附魔注册（world 初始化后）
-- =========================================================
AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_LDG", {
        name = "劳动最光荣",
        client_text = "劳动\n光荣",
        desc = "劳动最光荣！\n● 秒采：采集/收获/交易瞬间完成\n● 秒砍挖：砍树/挖矿瞬间完成\n● 秒制作：建筑/制作瞬间完成\n● 秒出锅：放入食材即出锅\n● 劳动有喜：劳动中5%概率获得藏宝图\n获得：挖矿/砍树/采集/制作各300 + 烹饪15种不同料理 + 敲碎巨大作物50",
        check_desc = "挖矿/砍树/采集/制作各300 + 烹饪15种不同料理 + 敲碎巨大作物50，劳动最光荣！",
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

                -- fast_act — HH框架 stategraph 钩子（加速 PICK/COOK/BUILD/HARVEST）
                if hh then
                    hh:AddEffectValueByKey("fast_act", 1)
                end

                -- 同步 fast_act 到客户端（wilson_client 侧 stategraph 需要）
                _G.pcall(function()
                    if owner.userid then
                        _G.SendModRPCToClient(_G.CLIENT_MOD_RPC["hh_rpc"]["hh_client_value"], owner.userid, "hh_fast_act", true)
                    end
                end)

                -- 秒制作
                if owner.components.builder then
                    owner._ldg_old_buildtime = owner.components.builder.buildingtime or 1
                    owner.components.builder.buildingtime = 0.001
                end

                -- 劳动中20%概率获得藏宝图（完成工作）
                owner._ldg_work_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "laodong") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end
                    if math.random() > 0.05 then return end

                    local tally = _G.SpawnPrefab("hh_treasure_tally")
                    if tally and owner.components.inventory then
                        owner.components.inventory:GiveItem(tally, nil, owner:GetPosition())
                        if owner.components.talker then
                            owner.components.talker:Say("劳动最光荣！挖到一张藏宝图！")
                        end
                    end
                end
                owner:ListenForEvent("finishedwork", owner._ldg_work_handler)

                -- 采摘也有概率获得藏宝图
                owner._ldg_pick_handler = function(inst, data)
                    if not _G.Moon_HasEffect(owner, "laodong") then return end
                    if not data or not data.loot then return end
                    if math.random() > 0.05 then return end

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
                    hh:ReduceEffectValueByKey("fast_act", 1)
                end

                -- 同步客户端 fast_act：有其他来源（如传武快速交互）时仍为 true
                _G.pcall(function()
                    if owner.userid then
                        local still_active = hh and hh:HasSpecialEffect("fast_act")
                        _G.SendModRPCToClient(_G.CLIENT_MOD_RPC["hh_rpc"]["hh_client_value"], owner.userid, "hh_fast_act", still_active)
                    end
                end)

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
