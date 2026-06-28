-- 小月亮 死亡统计
-- 追踪所有玩家的死亡次数，支持持久化存储和面板展示

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_DEATH_STATS then return end

_G._moon_death_data = nil

local death_stats = {}
local DEATH_SAVE_ID = "dst_little_moon_death_stats"
local stats_loaded = false

local function SaveStats()
    if _G.json ~= nil then
        _G.TheSim:SetPersistentString(DEATH_SAVE_ID, _G.json.encode(death_stats), false)
    end
end

AddPlayerPostInit(function(inst)
    if not _G.TheWorld.ismastersim then return end
    if not stats_loaded then
        _G.TheSim:GetPersistentString(DEATH_SAVE_ID, function(success, data)
            if success and data and data ~= "" then
                local ok, stats = _G.pcall(_G.json.decode, data)
                if ok and type(stats) == "table" then
                    death_stats = stats
                end
            end
            stats_loaded = true
        end)
    end
    inst:ListenForEvent("death", function(src)
        local userid = src.userid
        if not userid then return end
        if not death_stats[userid] then
            death_stats[userid] = { count = 0, name = src.name or userid }
        end
        death_stats[userid].count = death_stats[userid].count + 1
        if src.name then
            death_stats[userid].name = src.name
        end
        SaveStats()

        -- 死亡公告
        if CFG.ENABLE_DEATH_ANNOUNCE then
            local msg = "玩家 " .. (src.name or userid) .. " 死了，当前已累计死亡 " .. death_stats[userid].count .. " 次"
            _G.TheNet:Announce(msg)
        end
    end)
end)

-- 注册客户端 RPC（让服务端 CLIENT_MOD_RPC 表有入口）
AddClientModRPCHandler("LittleMoon", "DeathStatsResponse", function(json_data)
    if _G.json == nil then return end
    local ok, data = _G.pcall(_G.json.decode, json_data)
    if ok and type(data) == "table" then
        _G._moon_death_data = data
    end
end)

-- 请求时动态查找 RPC ID（避免 modimport 顶层表未就绪）
AddModRPCHandler("LittleMoon", "GetDeathStats", function(player)
    if not _G.TheWorld.ismastersim then return end

    local result = {}
    for userid, info in pairs(death_stats) do
        local name = info.name or userid
        for _, v in ipairs(_G.AllPlayers) do
            if v.userid == userid and v.name then
                name = v.name
                break
            end
        end
        table.insert(result, { name = name, count = info.count })
    end
    table.sort(result, function(a, b) return a.count > b.count end)

    -- 动态查找 CLIENT_MOD_RPC ID，确保表已就绪
    local rpc = _G.CLIENT_MOD_RPC
    if rpc and rpc["LittleMoon"] and rpc["LittleMoon"]["DeathStatsResponse"] then
        _G.SendModRPCToClient(rpc["LittleMoon"]["DeathStatsResponse"], player.userid, _G.json.encode(result))
    end
end)
