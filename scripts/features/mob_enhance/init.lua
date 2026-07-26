-- 小月亮 怪物强化模块 — 入口
-- 加载附魔池 + 注册所有强化怪物
-- 与现有附魔体系完全解耦，独立运作
--
-- 加载条件: ENABLE_MOB_ENHANCE = true
-- 防御层直接影响怪物血量机制，注意不要与其他修改类模组冲突

local _G = GLOBAL
local CFG = _G.MOON_CFG

-- =====================================================================
-- 0. 配置检查
-- =====================================================================
if not CFG.ENABLE_MOB_ENHANCE then return end

local SpawnPrefab = _G.SpawnPrefab
local TheSim = _G.TheSim
local math = _G.math
local GetTime = _G.GetTime

-- 加载附魔池定义
modimport("scripts/features/mob_enhance/enchants_pool")
local MOON_MOB_ENCHANTS = _G.MOON_MOB_ENCHANTS or {}

-- =====================================================================
-- 1. 难度配置
-- =====================================================================
local DIFFICULTY = {
    easy    = { mult = 0.6, extra_enchants = 0 },
    normal  = { mult = 1.0, extra_enchants = 0 },
    hard    = { mult = 3.0, extra_enchants = 3 },
    nightmare = { mult = 5.0, extra_enchants = 5 },
}

local diff_cfg = DIFFICULTY[CFG.MOB_ENHANCE_LEVEL] or DIFFICULTY.normal

-- =====================================================================
-- 2. 怪物分类表
-- =====================================================================

local MOON_MOB_TABLE = {}

-- Boss
local boss_list = {
    "deerclops", "bearger", "moose", "dragonfly", "antlion",
    "beequeen", "klaus", "malbatross", "toadstool", "toadstool_dark",
    "crabking", "stalker", "stalker_atrium", "stalker_forest",
    "alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3",
    "minotaur", "spiderqueen", "warg",
    "eyeofterror", "twinofterror1", "twinofterror2",
}
for _, name in ipairs(boss_list) do
    MOON_MOB_TABLE[name] = { tier = "boss" }
end

-- 普通战斗怪物
local normal_list = {
    "leif", "leif_sparse",
    "hound", "firehound", "icehound", "moonhound", "mutatedhound", "clayhound",
    "spider", "spider_warrior", "spider_hider", "spider_spitter", "spider_mutated", "spider_water",
    "pigman", "pigguard", "bunnyman", "merm", "mermguard",
    "tentacle", "tentacle_pillar", "tentacle_pillar_arm",
    "frog", "mosquito", "bat",
    "cookiecutter", "shark", "gnarwail",
    "lavae",
    "nightmarebeak", "crawlingnightmare", "crawlinghorror", "terrorbeak",
    "slurper", "worm", "krampus",
    "walrus",
    "beefalo", "koalefant_summer", "koalefant_winter", "lightninggoat",
    "penguin", "tallbird", "teenbird",
    "mossling", "birchnutdrake",
    "knight", "knight_nightmare", "bishop", "bishop_nightmare", "rook", "rook_nightmare",
    "eyeplant",
    "stalker_minion1", "stalker_minion2",
    "eyeofterror_mini", "eyeofterror_mini_grounded",
}
for _, name in ipairs(normal_list) do
    MOON_MOB_TABLE[name] = { tier = "normal" }
end

-- =====================================================================
-- 3. 附魔池（定义在 enchants_pool.lua 中）
-- =====================================================================
-- 已通过 modimport 加载到 _G.MOON_MOB_ENCHANTS

-- =====================================================================
-- 4. 抽取逻辑
-- =====================================================================
local function RollEnchants(tier)
    local pool = {}
    for eid, cfg in pairs(MOON_MOB_ENCHANTS) do
        if cfg.boss_only and tier ~= "boss" then
            -- skip: boss-only 不掉给普通怪
        else
            table.insert(pool, { id = eid, weight = cfg.weight or 1 })
        end
    end

    -- 确定抽取数量
    local count
    if tier == "boss" then
        count = 3 + diff_cfg.extra_enchants  -- Boss 3~5 个
    else
        count = 2 + diff_cfg.extra_enchants  -- 普通怪 2~N 个
    end
    count = math.min(count, #pool)

    if count <= 0 then return {} end

    -- 加权不放回抽取
    local result = {}
    local remaining = {}
    for _, v in ipairs(pool) do
        table.insert(remaining, { id = v.id, weight = v.weight })
    end

    for _ = 1, count do
        if #remaining == 0 then break end

        local total_weight = 0
        for _, v in ipairs(remaining) do
            total_weight = total_weight + v.weight
        end

        local roll = math.random() * total_weight
        local accum = 0
        for i, v in ipairs(remaining) do
            accum = accum + v.weight
            if roll <= accum then
                table.insert(result, v.id)
                table.remove(remaining, i)
                break
            end
        end
    end

    return result
end

-- =====================================================================
-- 5. 注册到所有目标怪物
-- =====================================================================
for prefab_name, info in pairs(MOON_MOB_TABLE) do
    -- 按类型过滤
    if info.tier == "boss" and not CFG.MOB_ENHANCE_BOSS then
        -- 不强化
    elseif info.tier == "normal" and not CFG.MOB_ENHANCE_NORMAL then
        -- 不强化
    else
        AddPrefabPostInit(prefab_name, function(inst)
        -- 等待组件就绪
        inst:DoTaskInTime(0, function()
            if not inst:IsValid() then return end
            if inst.components.moon_mob_enhance then return end  -- 防重复

            local tier = info.tier or "normal"

            -- 添加组件
            local comp = inst:AddComponent("moon_mob_enhance")

            -- 抽取附魔
            local enchant_ids = RollEnchants(tier)

            -- 启动（运行时检测 HH 框架）
            local runtime_hh = _G.Moon_IsHHEnabled and _G.Moon_IsHHEnabled() or false
            comp:OnStart(tier, diff_cfg.mult, enchant_ids, MOON_MOB_ENCHANTS, runtime_hh)
        end)
    end)
    end
end
