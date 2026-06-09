name = "小月亮 (Little Moon)"
description = "提取自特定Mod的召唤功能：小月亮按钮及召唤面板"
author = "九月"
version = "1.10.0"
api_version = 10
priority = 1000
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
dependencies = {
    {workshop = "2526778484"},
}
icon_atlas = "modicon.xml"
icon = "modicon.tex"

-- 定义标题函数
local function AddTitle(title)
    return { 
        name = " ", 
        label = title, 
        options = { { description = "", data = 0 } }, 
        default = 0 
    }
end

configuration_options = {

    AddTitle("通用配置"),
    {
        name = "LITTLE_MOON_SCALE",
        label = "助手面板缩放",
        hover = "设置小月亮助手面板的整体大小",
        options = {
            { description = "缩小 (0.8x)", data = 0.8 },
            { description = "标准 (1.0x)", data = 1.0 },
            { description = "放大 (1.2x)", data = 1.2 },
            { description = "特大 (1.5x)", data = 1.5 },
        },
        default = 1.0,
    },
    AddTitle("附魔强化挖宝组件"),
    {
        name = "ENABLE_TREASURE",
        label = "开启挖宝组件",
        hover = "是否开启小月亮按钮及召唤功能",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "PROXIMITY_LIMIT",
        label = "局部密度限制(20码)",
        hover = "规定范围内最多存在的宝藏点数量",
        options = {
            { description = "10个", data = 10 },
            { description = "20个", data = 20 },
            { description = "50个", data = 50 },
            { description = "100个", data = 100 },
            { description = "不限制", data = 999 },
        },
        default = 50,
    },
    {
        name = "PLAYER_LIMIT",
        label = "个人全图上限",
        hover = "单个玩家在全图范围内最多拥有的宝藏点数量",
        options = {
            { description = "20个", data = 20 },
            { description = "50个", data = 50 },
            { description = "100个", data = 100 },
            { description = "200个", data = 200 },
            { description = "不限制", data = 9999 },
        },
        default = 100,
    },
    {
        name = "GLOBAL_LIMIT",
        label = "全图总数上限",
        hover = "整个服务器范围内最多允许存在的宝藏点总数",
        options = {
            { description = "200个", data = 200 },
            { description = "500个", data = 500 },
            { description = "1000个", data = 1000 },
            { description = "不限制", data = 99999 },
        },
        default = 500,
    },
    {
        name = "EXPIRY_TIME",
        label = "自动过期消失",
        hover = "未被开启的宝藏点多久后会自动消失",
        options = {
            { description = "0.5天", data = 240 },
            { description = "1天", data = 480 },
            { description = "3天", data = 1440 },
            { description = "永不消失", data = -1 },
        },
        default = 480,
    },

    AddTitle("欧皇模拟器清理组件"),
    {
        name = "ENABLE_QL_HELPER",
        label = "开启快捷指令面板",
        hover = "是否开启包含 #ql 和 #cleanup 的快捷指令面板",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    AddTitle("禁止打包"),
    {
        name = "DISABLE_KRAMPUS_PACK",
        label = "坎普斯",
        hover = "是否禁止坎普斯被打包",
        options = {
            { description = "禁止", data = true },
            { description = "不禁止", data = false },
        },
        default = false,
    },

    AddTitle("物品自动吸入"),
    {
        name = "ENABLE_AUTO_PICKUP",
        label = "开启自动吸入",
        hover = "是否开启周围物品自动吸入背包功能",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    {
        name = "AUTO_PICKUP_RANGE",
        label = "吸入范围",
        hover = "设置自动吸入物品的距离",
        options = {
            { description = "较近 (3码)", data = 3 },
            { description = "标准 (5码)", data = 5 },
            { description = "较远 (8码)", data = 8 },
            { description = "超远 (12码)", data = 12 },
        },
        default = 5,
    },

    AddTitle("虚空异界(泰拉)"),
    {
        name = "ENABLE_DEMON_ALTAR",
        label = "恶魔祭坛可制作",
        hover = "是否允许在暗影操控器（魔法二本）制作 emojitan",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "ENABLE_SHIJIZHIHUA_BULB",
        label = "世纪之花球茎可制作",
        hover = "是否允许在恶魔祭坛制作世纪之花球茎",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    AddTitle("客户端换人控制"),
    {
        name = "ENABLE_DISABLE_RESELECT",
        label = "禁用客户端换人",
        hover = "是否禁用换人指令",
        options = {
            { description = "禁用", data = true },
            { description = "允许", data = false },
        },
        default = true,
    },

    AddTitle("快捷自杀组件"),
    {
        name = "ENABLE_SUICIDE",
        label = "开启快捷自杀",
        hover = "是否开启聊天指令（#zs, #kill, #自杀）及面板按钮",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    AddTitle("掉落优化 (防卡顿)"),
    {
        name = "ENABLE_LOOT_LIMITER",
        label = "开启掉落限流",
        hover = "合并可堆叠物品，限制不可堆叠物品数量",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "MAX_NON_STACKABLE",
        label = "不可堆叠上限",
        hover = "同种不可堆叠物品单次掉落的最大数量",
        options = {
            { description = "3个", data = 3 },
            { description = "5个", data = 5 },
            { description = "10个", data = 10 },
            { description = "20个", data = 20 },
            { description = "50个", data = 50 },
            { description = "100个", data = 100 },
            { description = "200个", data = 200 },
            { description = "500个", data = 500 },
            { description = "不限制", data = 9999 },
        },
        default = 5,
    },
}
