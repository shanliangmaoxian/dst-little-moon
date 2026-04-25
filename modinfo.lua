name = "小月亮 (Little Moon)"
description = "提取自特定Mod的召唤功能：小月亮按钮及召唤面板"
author = "九月"
version = "1.2.0"
api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options = {
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
    {
        name = "QL_WINDOW_WIDTH",
        label = "指令面板宽度",
        hover = "设置快捷指令面板的宽度",
        options = {
            { description = "小", data = 300 },
            { description = "中", data = 360 },
            { description = "大", data = 420 },
        },
        default = 300,
    },
}
