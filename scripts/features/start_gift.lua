-- 小月亮 开局礼包（服务端）
-- 玩家进服后可自选领取一次开局礼包（方案数由配置决定，全服仅一次）
-- 配置格式: 物品,数量,角色|物品,数量,角色:::方案2...（角色 all=所有人 或 角色prefab）
-- 已领记录存 TheSim persistent string（存档级，地表/洞穴共享，跨世界有效）

local _G = GLOBAL
local CFG = _G.MOON_CFG

if not CFG.ENABLE_START_GIFT then return end

local AddModRPCHandler = AddModRPCHandler

-- 存档键（TheSim persistent string，位于存档目录，跨世界共享）
local SAVE_KEY = "dst_little_moon_start_gift"

-- 已领记录 userid -> plan
local claimed = {}

-- ------------------------------------------------------------------
-- 方案解析
-- ------------------------------------------------------------------
-- 单一配置项格式: 物品,数量,角色|物品,数量,角色:::方案2...
--   ::: 分隔多个方案，| 分隔同方案的多个物品，角色填 all 或角色 prefab
--   数量/角色可省略（默认 1 / all），如 "cutstone" 或 "cutstone,5"
local function ParseConfig(cfg_str)
    local plans = {}
    if type(cfg_str) ~= "string" then return plans end
    for plan_str in string.gmatch(cfg_str, "[^:]+") do
        local items = {}
        for entry in string.gmatch(plan_str, "[^|]+") do
            local prefab, count, role = entry:match("^%s*(.-)%s*,%s*(%d+)%s*,%s*(.-)%s*$")
            if not prefab then
                prefab, count = entry:match("^%s*(.-)%s*,%s*(%d+)%s*$")
                role = "all"
            end
            if not prefab then
                prefab = entry:match("^%s*(.-)%s*$")
                count, role = 1, "all"
            end
            if prefab and prefab ~= "" then
                local n = tonumber(count) or 1
                if n < 1 then n = 1 end
                if role == nil or role == "" then role = "all" end
                table.insert(items, { prefab = prefab, count = n, role = role })
            end
        end
        if #items > 0 then
            table.insert(plans, items)
        end
    end
    return plans
end

-- 方案标签自动生成: 礼包A / 礼包B / 礼包C ...（超过 26 个方案用 P27 等兜底）
local PLAN_LETTERS = { "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z" }
local PLANS_CFG = ParseConfig(CFG.START_GIFT_PLANS)
local PLAN_LIST   = {}              -- {"a","b"}
local PLAN_DATA   = {}              -- id -> 物品定义表
local PLAN_LABELS = {}              -- id -> "礼包A"
for i, items in ipairs(PLANS_CFG) do
    local id = PLAN_LETTERS[i] or ("p" .. i)
    table.insert(PLAN_LIST, id)
    PLAN_DATA[id] = items
    PLAN_LABELS[id] = "礼包" .. (PLAN_LETTERS[i] or i)
end

-- 角色匹配：all 或精确匹配玩家 prefab（忽略大小写）
local function RoleMatches(role, player_prefab)
    if not role or role == "" or role == "all" then return true end
    return string.lower(role) == string.lower(player_prefab or "")
end

-- ------------------------------------------------------------------
-- 存档读写
-- ------------------------------------------------------------------
local function SaveClaimed()
    if _G.TheSim and _G.TheSim.SetPersistentString and _G.json then
        _G.TheSim:SetPersistentString(SAVE_KEY, _G.json.encode(claimed), false)
    end
end

-- 加载完成标记（回调里置位；未完成前拒绝领取，防跨世界重复竞态）
local load_done = false
local function LoadClaimed()
    if load_done then return end
    if not (_G.TheSim and _G.TheSim.GetPersistentString and _G.json) then
        load_done = true
        return
    end
    _G.TheSim:GetPersistentString(SAVE_KEY, function(success, data)
        if success and data and data ~= "" then
            local ok, decoded = _G.pcall(_G.json.decode, data)
            if ok and type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    claimed[k] = v
                end
            end
        end
        load_done = true
    end)
end

-- AddPrefabPostInit("world") 在客户端不触发，正好只有服务端读档
AddPrefabPostInit("world", function(inst)
    if not _G.TheWorld or not _G.TheWorld.ismastersim then return end
    LoadClaimed()
end)

-- ------------------------------------------------------------------
-- 发放
-- ------------------------------------------------------------------
local function GivePlan(player, plan)
    local defs = PLAN_DATA[plan]
    if not defs or #defs == 0 then return false end

    local player_prefab = player.prefab or ""
    local items = {}
    for _, def in ipairs(defs) do
        if RoleMatches(def.role, player_prefab) then
            local item = _G.SpawnPrefab(def.prefab)
            if item then
                if def.count and def.count > 1 and item.components.stackable then
                    local max = item.components.stackable.maxsize or def.count
                    item.components.stackable:SetStackSize(math.min(def.count, max))
                end
                table.insert(items, item)
            else
                print(string.format("[小月亮] 开局礼包物品不存在，已跳过: %s", tostring(def.prefab)))
            end
        end
    end
    if #items == 0 then return false end

    local pos = player.Transform and player.Transform:GetWorldPosition() or nil

    -- 打包成礼盒
    local gift = _G.SpawnPrefab("gift")
    local ok = false
    if gift and gift.components and gift.components.unwrappable then
        gift.components.unwrappable:WrapItems(items, player)
        for _, item in ipairs(items) do
            if item and item:IsValid() then item:Remove() end
        end
        if gift.components.named then
            gift.components.named:SetName("开局" .. (PLAN_LABELS[plan] or plan))
        end
        -- 先定位到玩家脚下，背包满时 GiveItem 失败也能留在原地而非世界原点
        if pos then
            gift.Transform:SetPosition(pos.x, pos.y, pos.z)
        end
        if player.components and player.components.inventory then
            player.components.inventory:GiveItem(gift)
        end
        ok = true
    else
        -- 礼盒不可用时降级直接给物品
        if gift then gift:Remove() end
        for _, item in ipairs(items) do
            if item and item:IsValid() then
                if player.components and player.components.inventory then
                    player.components.inventory:GiveItem(item)
                elseif pos then
                    item.Transform:SetPosition(pos.x, pos.y, pos.z)
                end
            end
        end
        ok = true
    end
    return ok
end

-- ------------------------------------------------------------------
-- RPC（命名空间 LittleMoon）
-- ------------------------------------------------------------------
-- 查询可用方案与领取状态（客户端打开弹窗时调用）
AddModRPCHandler("LittleMoon", "GetStartGiftPlans", function(player)
    if not player or not _G.TheWorld or not _G.TheWorld.ismastersim then return end
    local result = {
        plans = PLAN_LIST,
        labels = PLAN_LABELS,
        claimed = claimed[player.userid] or false,
    }
    local rpc = _G.CLIENT_MOD_RPC
    if rpc and rpc["LittleMoon"] and rpc["LittleMoon"]["StartGiftPlansResponse"] and _G.json then
        _G.SendModRPCToClient(rpc["LittleMoon"]["StartGiftPlansResponse"], player.userid, _G.json.encode(result))
    end
end)

-- 回执给客户端（成功/失败），用于回滚乐观置灰
local function SendClaimResponse(player, ok, plan)
    local rpc = _G.CLIENT_MOD_RPC
    if rpc and rpc["LittleMoon"] and rpc["LittleMoon"]["ClaimStartGiftResponse"] and _G.json then
        _G.SendModRPCToClient(rpc["LittleMoon"]["ClaimStartGiftResponse"], player.userid, _G.json.encode({ ok = ok, plan = plan }))
    end
end

-- 领取指定方案
AddModRPCHandler("LittleMoon", "ClaimStartGift", function(player, plan)
    if not player or not _G.TheWorld or not _G.TheWorld.ismastersim then return end
    local userid = player.userid
    if not userid then return end

    if not load_done then
        _G.Moon_Say(player, "礼包数据加载中，请稍后再试")
        return
    end
    if claimed[userid] then
        _G.Moon_Say(player, "你已经领取过开局礼包了")
        SendClaimResponse(player, false, plan)
        return
    end
    if type(plan) ~= "string" or not PLAN_DATA[plan] then
        _G.Moon_Say(player, "无效的礼包方案")
        SendClaimResponse(player, false, plan)
        return
    end

    if not GivePlan(player, plan) then
        _G.Moon_Say(player, "礼包发放失败，请联系管理员检查礼包配置")
        SendClaimResponse(player, false, plan)
        return
    end

    claimed[userid] = plan
    SaveClaimed()
    _G.Moon_Say(player, "已领取" .. (PLAN_LABELS[plan] or plan) .. "！")
    SendClaimResponse(player, true, plan)
end)
