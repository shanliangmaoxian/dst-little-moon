-- 小月亮 附魔：召唤群友 (Legend_QUNYOU)
-- 装备时召唤 5 只猪人群友（每只都有名字+登场对白，名字/对白见下方配置表），
-- 每 60 秒补员 1 只（上限 5），每只群友存活 5 分钟后各自散去。
-- 群友会跟随玩家并帮忙打架。

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- ======== 群友配置（名字/对白从附魔配置来，改这里即可） ========
local MAX_PIGS = 5            -- 同时存在的群友上限
local PIG_LIFETIME = 300      -- 每只群友存活秒数（5 分钟）
local REFILL_INTERVAL = 60    -- 补员间隔（秒）
local PIG_NAMES = { "萝猪", "球猪", "菜猪", "兔猪", "E猪", "挂白" }
local PIG_LINES = {
    "九月九月，你在哪？不想上班想回家",
    "灌篮！可是我的球框呢？",
    "哎呀 你干嘛～",
    "看看腹肌~~",
    "噜噜噜, 我是 E 猪！",
    "V我50，给你开挂~",
}

-- ======== 群友槽位管理 ========
-- 槽位 i 与 PIG_NAMES[i]/PIG_LINES[i] 一一对应，保证名字不重复

local function get_empty_slot(owner)
    local pigs = owner._qunyou_pigs
    for i = 1, MAX_PIGS do
        local pig = pigs[i]
        if not pig or not pig:IsValid() then
            return i
        end
    end
    return nil
end

local function remove_pig(owner, pig, slot)
    if pig and pig:IsValid() then
        local x, y, z = pig.Transform:GetWorldPosition()
        local fx = _G.SpawnPrefab("statue_transition_2")
        if fx then
            fx.Transform:SetPosition(x, y + 1, z)
        end
        pig:Remove()
    end
    if owner and owner:IsValid() then
        owner._qunyou_pigs[slot] = nil
    end
end

local function spawn_qunyou(owner, slot)
    local name = PIG_NAMES[slot]
    local line = PIG_LINES[slot]
    local x, y, z = owner.Transform:GetWorldPosition()

    -- 玩家周围 1.5~3 码随机位置，避免叠在一起
    local angle = math.random() * 2 * math.pi
    local dist = 1.5 + math.random() * 1.5
    local px = x + math.cos(angle) * dist
    local pz = z + math.sin(angle) * dist

    local pig = _G.SpawnPrefab("pigman")
    if not pig then return end
    pig.Transform:SetPosition(px, y, pz)

    -- 名字（挂在 named 组件上；缺失则补挂，保证有名字）
    local named = pig.components.named
    if not named then
        pig:AddComponent("named")
        named = pig.components.named
    end
    if named then
        named:SetName(name)
    end

    -- 登场对白
    if pig.components.talker then
        pig.components.talker:Say(line)
    end

    -- 跟随玩家打架
    if pig.components.follower then
        pig.components.follower:SetLeader(owner)
    end

    -- 群友不睡觉（免得晚上集体掉线）
    if pig.components.sleeper then
        pig.components.sleeper:SetSleepiness(0)
    end

    owner._qunyou_pigs[slot] = pig

    -- 5 分钟后各自散去
    pig:DoTaskInTime(PIG_LIFETIME, function()
        if not pig:IsValid() then return end
        remove_pig(owner, pig, slot)
    end)
end

-- 补员：有空槽就补 1 只（每 60 秒检查一次）
local function refill(owner)
    if not owner:IsValid() then return end
    if not _G.Moon_HasEffect(owner, "qunyou") then return end
    local slot = get_empty_slot(owner)
    if slot then
        spawn_qunyou(owner, slot)
    end
end

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_QUNYOU", {
        name = "召唤群友",
        client_text = "召唤\n群友",
        desc = "群友已就位 — 装备时召唤5只猪人群友(各有名字)\n群友存活5分钟，每60秒补员1只\n群友帮你打架，随叫随到！",
        check_desc = "群友已就位，开冲！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.9, 0.7, 0.2, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,
        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "qunyou", "Legend_QUNYOU", 1)
            if not owner._qunyou_hooked then
                owner._qunyou_hooked = true
                owner._qunyou_pigs = {}

                -- 首批召唤
                for i = 1, MAX_PIGS do
                    spawn_qunyou(owner, i)
                end

                -- 每 60 秒补员
                owner._qunyou_refill_task = owner:DoPeriodicTask(REFILL_INTERVAL, function()
                    refill(owner)
                end)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "qunyou", "Legend_QUNYOU", 1)
            if not _G.Moon_HasEffect(owner, "qunyou") then
                if owner._qunyou_refill_task then
                    owner._qunyou_refill_task:Cancel()
                    owner._qunyou_refill_task = nil
                end
                -- 群友各回各家
                if owner._qunyou_pigs then
                    for i = 1, MAX_PIGS do
                        remove_pig(owner, owner._qunyou_pigs[i], i)
                    end
                    owner._qunyou_pigs = nil
                end
                owner._qunyou_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_QUNYOU", 0.01)
end)
