-- 小月亮商店：召唤群友
-- 商店配方 MoonShop_moon_qunyou_summon（100 水晶小人，猪皮图标）制作后，
-- 原地生成瞬发实体 moon_qunyou_summon → 在制作玩家身边召唤 1 只猪人群友：
--   每次兑换只出 1 只，玩家周边最多同时 3 只（上限 3）；
--   群友各有名字+登场对白（槽位与名字一一对应，保证不重名），跟随玩家打架，一直存活不消失；
--   不可被攻击（notarget + noattack + SetInvincible 三层）；每 60 秒补员 1 只（有空槽才补，天然限 3 只上限），玩家在线期间持续补员；
--   传送跟随：玩家传送（法杖/虫洞/雕像复活）后群友不会自动跟上（follower 的 GoToEntity 有距离上限），每 10 秒检查一次，超 40 码直接瞬移到玩家身边。
-- 附魔版 scripts/enchants/qunyou.lua 保持原 5 只设定，本文件为商店版独立参数。

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
    _G.STRINGS.RECIPE_DESC.MOONSHOP_MOON_QUNYOU_SUMMON = "100 水晶小人召唤 1 只猪人群友\n周边最多同时 3 只，各有名字，跟随打架\n一直存活+不可被攻击，每60秒补员1只"
end

-- ======== 群友配置 ========
local MAX_PIGS = 3            -- 同时存在的群友上限（周边最多 3 只）
local REFILL_INTERVAL = 60    -- 补员间隔（秒）
local FOLLOW_TELEPORT_DIST = 40 -- 群友距玩家超过该距离视为传送掉队，直接拉回身边（follower GoToEntity 上限约 40 码）
-- 群友一直存活：不设 PIG_LIFETIME 到期移除，死亡后由补员任务补回
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

    -- 群友不能被攻击（玩家/怪物/AoE 均无效）：
    --   notarget: 怪物不主动选为目标（hufei/yangmaoke/malatutou 同款）
    --   noattack: 一切攻击对其挥空 0 伤害（combat CanBeAttacked 检查）
    --   SetInvincible: 免疫所有伤害路径（含火烧/环境直伤，hufei.lua 同款）
    pig:AddTag("notarget")
    pig:AddTag("noattack")
    if pig.components.health and pig.components.health.SetInvincible then
        pig.components.health:SetInvincible(true)
    end

    -- 群友不睡觉（免得晚上集体掉线）
    -- 注意：sleeper 组件没有 SetSleepiness 方法（qunyou.lua 附魔版同款已修），
    -- 正确做法是把睡眠测试函数替换为恒 false
    if pig.components.sleeper and pig.components.sleeper.SetSleepTest then
        pig.components.sleeper:SetSleepTest(function() return false end)
    end

    -- 召唤的猪人不出掉落物（免得杀猪刷肉/猪皮）：
    -- SetLoot({}) 清固定掉落并重置 randomloot/numrandomloot，ClearRandomLoot 双保险
    if pig.components.lootdropper then
        pig.components.lootdropper:SetLoot({})
        if pig.components.lootdropper.ClearRandomLoot then
            pig.components.lootdropper:ClearRandomLoot()
        end
    end

    owner._moon_qunyou_pigs[slot] = pig

    -- 一直存活：不设到期移除；死亡/被移除时清槽位，由补员任务补回
    pig:ListenForEvent("onremove", function()
        clear_slot(owner, slot, pig)
    end)

    return true
end

-- 给 owner 召唤 1 只群友（兑换触发）：每次兑换只出 1 只 + 60 秒补员任务
-- 重复兑换 = 有空槽就再补 1 只（不清理已有群友）；满 3 只则提示不再出
-- 补员任务随玩家实体存活（玩家下线任务自动销毁，群友仍留在场上一直存活）
function _G.Moon_Qunyou_SummonGroup(owner)
    if not (owner and owner:IsValid() and owner.Transform) then return end
    if owner:HasTag("playerghost") then return end

    -- 首次调用初始化槽位表
    if not owner._moon_qunyou_pigs then
        owner._moon_qunyou_pigs = {}
    end

    -- 每次兑换只召唤 1 只（有空槽才补）
    local slot = get_empty_slot(owner)
    if not slot then
        if _G.Moon_Say then
            _G.Moon_Say(owner, "群友已满啦，周边最多 3 只")
        end
        return
    end
    spawn_qunyou(owner, slot)

    -- 每 60 秒补员 1 只（有空槽才补，天然限 3 只上限）；群友一直存活，补员持续到玩家下线
    -- 注意：DoPeriodicTask 第三参是 initialdelay 而非次数上限；任务挂在玩家实体上，下线自动销毁
    if owner._moon_qunyou_refill_task then
        owner._moon_qunyou_refill_task:Cancel()
        owner._moon_qunyou_refill_task = nil
    end
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
        local slot = get_empty_slot(owner)
        if slot then
            spawn_qunyou(owner, slot)
        end
    end)

    -- 传送跟随：玩家传送后群友留在原地（follower 的 GoToEntity 有距离上限，且远处群友可能不更新），
    -- 每 10 秒检查一次，超过 FOLLOW_TELEPORT_DIST 直接瞬移到玩家身边；任务只建一次（多次兑换不累积）
    if not owner._moon_qunyou_follow_task then
        owner._moon_qunyou_follow_task = owner:DoPeriodicTask(10, function()
            if not owner:IsValid() or owner:HasTag("playerghost") then return end
            local px, py, pz = owner.Transform:GetWorldPosition()
            local pigs = owner._moon_qunyou_pigs
            for i = 1, MAX_PIGS do
                local pig = pigs and pigs[i]
                if pig and pig:IsValid() and pig.Transform then
                    local x, _, z = pig.Transform:GetWorldPosition()
                    local dx, dz = px - x, pz - z
                    if dx * dx + dz * dz > FOLLOW_TELEPORT_DIST * FOLLOW_TELEPORT_DIST then
                        pig.Transform:SetPosition(px, py, pz)
                    end
                end
            end
        end)
    end
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
