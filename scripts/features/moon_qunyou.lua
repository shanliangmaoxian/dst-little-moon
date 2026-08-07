-- 小月亮商店：召唤群友
-- 商店配方 MoonShop_moon_qunyou_summon（100 水晶小人，猪皮图标）制作后，
-- 原地生成瞬发实体 moon_qunyou_summon → 在制作玩家身边召唤 5 只猪人群友：
--   各有名字+登场对白（槽位与名字一一对应，保证不重名），跟随玩家打架，存活 5 分钟；
--   存活期间每 60 秒补员 1 只（有空槽才补，天然限 5 只上限），5 分钟后补员停止、群友各自散去。
-- 逻辑与附魔 scripts/enchants/qunyou.lua 保持一致（参数同源，改一处请同步另一处）。

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MOON_SHOP then return end
if not CFG.ENABLE_MOON_SHOP_BOSS_QUNYOU then return end

-- 配方显示名：crafting menu 用 STRINGS.NAMES[string.upper(recipe.name)] 或
-- STRINGS.NAMES[string.upper(recipe.product)] 查名字（craftingmenu_details.lua:253）。
-- product=moon_qunyou_summon 是全新 prefab 无原版名，须两端（mod 加载时）显式补名，
-- 否则商店配方名字显示为空。先例：moon_shop.lua 的 EMOJITAN / SHIJIZHIHUA_BULB。
if _G.STRINGS and _G.STRINGS.NAMES then
    _G.STRINGS.NAMES.MOONSHOP_MOON_QUNYOU_SUMMON = "召唤群友"
    _G.STRINGS.NAMES.MOON_QUNYOU_SUMMON = "召唤群友"
end
if _G.STRINGS and _G.STRINGS.RECIPE_DESC then
    _G.STRINGS.RECIPE_DESC.MOONSHOP_MOON_QUNYOU_SUMMON = "100 水晶小人召唤 5 只猪人群友\n各有名字，跟随打架，存活5分钟，每60秒补员1只"
end

-- ======== 群友配置（与 qunyou.lua 保持一致） ========
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

-- ======== 群友槽位管理（与 qunyou.lua 同构） ========
-- owner._moon_qunyou_pigs[slot] = pig，slot 与 PIG_NAMES[slot]/PIG_LINES[slot] 一一对应

local function get_empty_slot(owner)
    local pigs = owner._moon_qunyou_pigs
    for i = 1, MAX_PIGS do
        local pig = pigs[i]
        if not pig or not pig:IsValid() then
            return i
        end
    end
    return nil
end

-- 只清自己的引用：重复兑换时旧猪人的到期回调不能误清新一批同槽位猪人
local function clear_slot(owner, slot, pig)
    if owner and owner._moon_qunyou_pigs and owner._moon_qunyou_pigs[slot] == pig then
        owner._moon_qunyou_pigs[slot] = nil
    end
end

-- 在 owner 身边召唤 1 只群友（位置 1.5~3 码随机，避免叠在一起）
local function spawn_qunyou(owner, slot)
    local name = PIG_NAMES[slot]
    local line = PIG_LINES[slot]
    local x, y, z = owner.Transform:GetWorldPosition()

    local angle = math.random() * 2 * math.pi
    local dist = 1.5 + math.random() * 1.5

    local pig = _G.SpawnPrefab("pigman")
    if not pig then return false end
    pig.Transform:SetPosition(x + math.cos(angle) * dist, y, z + math.sin(angle) * dist)

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
    -- 注意：sleeper 组件没有 SetSleepiness 方法（qunyou.lua 附魔版同款已修），
    -- 正确做法是把睡眠测试函数替换为恒 false
    if pig.components.sleeper and pig.components.sleeper.SetSleepTest then
        pig.components.sleeper:SetSleepTest(function() return false end)
    end

    owner._moon_qunyou_pigs[slot] = pig

    -- 存活 5 分钟后各自散去
    pig:DoTaskInTime(PIG_LIFETIME, function()
        if pig:IsValid() then
            pig:Remove()
        end
        clear_slot(owner, slot, pig)
    end)

    return true
end

-- 给 owner 部署一批群友（兑换触发）：首发 5 只 + 60 秒补员任务
-- 重复兑换 = 清掉旧一批再召新一批（槽位表不叠加）
-- 补员任务随玩家实体存活（玩家下线任务自动销毁，群友仍在场上自行存活 5 分钟）
function _G.Moon_Qunyou_SummonGroup(owner)
    if not (owner and owner:IsValid() and owner.Transform) then return end
    if owner:HasTag("playerghost") then return end

    -- 清理旧一批群友（若有）
    if owner._moon_qunyou_pigs then
        for i = 1, MAX_PIGS do
            local pig = owner._moon_qunyou_pigs[i]
            if pig and pig:IsValid() then
                pig:Remove()
            end
        end
    else
        owner._moon_qunyou_pigs = {}
    end

    for i = 1, MAX_PIGS do
        spawn_qunyou(owner, i)
    end

    -- 每 60 秒补员 1 只（有空槽才补，天然限 5 只上限），最多补 ceil(300/60)=5 次覆盖整个存活窗口
    -- 注意：DoPeriodicTask 第三参是 initialdelay 而非次数上限，须手动计数 Cancel
    if owner._moon_qunyou_refill_task then
        owner._moon_qunyou_refill_task:Cancel()
        owner._moon_qunyou_refill_task = nil
    end
    local refill_left = math.ceil(PIG_LIFETIME / REFILL_INTERVAL)
    owner._moon_qunyou_refill_task = owner:DoPeriodicTask(REFILL_INTERVAL, function()
        if not owner:IsValid() then
            if owner._moon_qunyou_refill_task then
                owner._moon_qunyou_refill_task:Cancel()
                owner._moon_qunyou_refill_task = nil
            end
            return
        end
        -- 玩家死亡期间暂停补员（复活后继续）
        if owner:HasTag("playerghost") then return end
        if refill_left <= 0 then
            if owner._moon_qunyou_refill_task then
                owner._moon_qunyou_refill_task:Cancel()
                owner._moon_qunyou_refill_task = nil
            end
            return
        end
        refill_left = refill_left - 1
        local slot = get_empty_slot(owner)
        if slot then
            spawn_qunyou(owner, slot)
        end
    end)
end

-- ======== 瞬发召唤实体（商店配方 product） ========
-- 制作时 builder.lua 对无 inventoryitem 的 product 会 SetPosition 到制作位置并
-- 同步推送 "onbuilt" 事件（data.builder = 制作玩家），据此直接部署群友后自毁；
-- 若经其他途径生成（无 onbuilt），0 帧后兜底找最近存活玩家。

local function find_nearest_player(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local owner
    local best = math.huge
    if _G.TheSim and _G.TheSim.FindEntities then
        local candidates = _G.TheSim:FindEntities(x, y, z, 12, { "player" })
        for _, p in ipairs(candidates) do
            if p and p:IsValid() and p.Transform and not p:HasTag("playerghost") then
                local px, _, pz = p.Transform:GetWorldPosition()
                local d = (px - x) * (px - x) + (pz - z) * (pz - z)
                if d < best then
                    best = d
                    owner = p
                end
            end
        end
    end
    return owner
end

local function do_summon(inst, owner)
    if inst._moon_qunyou_done then return end
    inst._moon_qunyou_done = true
    if owner and owner:IsValid() then
        _G.Moon_Qunyou_SummonGroup(owner)
    end
    inst:Remove()
end

local function moon_qunyou_summon_fn()
    local inst = _G.CreateEntity()
    inst:AddTag("FX")
    inst.entity:AddTransform()

    -- 制作流程同步推送 onbuilt（data.builder = 制作玩家）
    inst:ListenForEvent("onbuilt", function(_, data)
        do_summon(inst, data and data.builder)
    end)

    -- 兜底：无 onbuilt 途径生成时，0 帧后按最近玩家执行
    inst:DoTaskInTime(0, function()
        if not inst:IsValid() then return end
        do_summon(inst, find_nearest_player(inst))
    end)

    return inst
end

-- 注意：RegisterPrefabs 不在 mod 沙箱 env 显式提供，需经 GLOBAL 访问
-- 注意：RegisterPrefabs 是可变参数（每个 prefab 一个参数），不能包在表里传
_G.RegisterPrefabs(
    _G.Prefab("moon_qunyou_summon", moon_qunyou_summon_fn)
)
