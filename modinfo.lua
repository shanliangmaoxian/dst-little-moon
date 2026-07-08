name = "小月亮 (Little Moon)"
description = "提取自特定Mod的召唤功能：小月亮按钮及召唤面板"
author = "九月"
version = "1.15.4"
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
    {
        name = "DIG_TREASURE_MODE",
        label = "一键挖宝",
        hover = "跳过宝藏点和铲子挖掘，消耗卷轴直接出怪。选择每次挖宝数量。",
        options = {
            { description = "关闭", data = 0 },
            { description = "1个", data = 1 },
            { description = "3个", data = 3 },
            { description = "5个", data = 5 },
            { description = "10个", data = 10 },
        },
        default = 0,
    },
    {
        name = "MAX_NEARBY_MONSTERS",
        label = "周边怪物上限",
        hover = "一键挖宝时玩家周边20码内怪物超过此数量则禁止使用，防止服务器卡顿",
        options = {
            { description = "10只", data = 10 },
            { description = "20只", data = 20 },
            { description = "30只", data = 30 },
            { description = "50只", data = 50 },
        },
        default = 20,
    },

    AddTitle("更多附魔"),
    {
        name = "ENABLE_MORE_ENCHANTS",
        label = "开启更多附魔",
        hover = "是否开启额外的附魔词条 毛旭/灵尾印记",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    {
        name = "remove_enchant",
        label = "禁用指定附魔石,在remove_enchant表中添加",
        hover = "在此表中添加要禁用的附魔石ID或名称。\n格式: {'id1','id2','id3'}\n支持所有HH框架附魔石，留空表则不禁用任何附魔石",
        options = { {description = "在服务器mod配置中添加", data = {}} },
        default = {},
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

    AddTitle("掉落自动堆叠"),

    {
        name = "ENABLE_AUTO_STACK",
        label = "开启掉落自动堆叠",
        hover = "物品掉落时自动与周围同类物品合并堆叠，请勿同时开启多个堆叠上限模组",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    {
        name = "ENABLE_MORE_STACKING",
        label = "更多堆叠",
        hover = "需要开启堆叠上限。让鸟、小动物、牛角、鱼等生物和物品也能堆叠，请勿同时开启多个堆叠上限模组",
        options = {
            { description = "关闭", data = false },
            { description = "开启", data = true },
            { description = "开启+丢出自动分离", data = 2, hover = "小动物等丢地上会自动分离开" },
        },
        default = false,
    },
    {
        name = "STACK_SIZE_MULTIPLIER",
        label = "堆叠上限",
        hover = "修改物品堆叠上限，请勿同时开启多个堆叠上限模组",
        options = {
            { description = "关闭", data = false },
            { description = "60", data = 60 },
            { description = "99", data = 99 },
            { description = "128", data = 128 },
            { description = "200", data = 200 },
            { description = "500", data = 500 },
            { description = "999", data = 999 },
            { description = "9999", data = 9999 },
        },
        default = 200,
    },

    AddTitle("客户端反作弊"),
    {
        name = "LOCK_RUN_SPEED",
        label = "锁定跑速",
        hover = "禁止客户端通过 mod 修改跑速（如 Fast moving 等加速 mod）",
        options = {
            { description = "锁定 (默认6)", data = true },
            { description = "不锁定", data = false },
        },
        default = true,
    },
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
        hover = "是否开启自杀面板按钮",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    AddTitle("死亡统计"),
    {
        name = "ENABLE_DEATH_STATS",
        label = "开启死亡统计",
        hover = "统计所有玩家的死亡次数，在助手面板中显示排行榜",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    {
        name = "ENABLE_DEATH_ANNOUNCE",
        label = "死亡公告",
        hover = "当玩家死亡时在聊天框公告死亡信息",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    {
        name = "DEATH_STATS_RESET_ON_SWITCH",
        label = "换人重置计数",
        hover = "换人（切换角色）后是否将死亡次数清零",
        options = {
            { description = "清零", data = true },
            { description = "不清零", data = false },
        },
        default = false,
    },

    AddTitle("快捷发言"),
    {
        name = "ENABLE_QUICK_CHAT",
        label = "开启快捷发言",
        hover = "是否在助手面板中显示快捷发言输入框",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },

    -- AddTitle("掉落优化 (防卡顿)"),
    -- {
    --     name = "ENABLE_LOOT_LIMITER",
    --     label = "开启掉落限流",
    --     hover = "合并可堆叠物品，限制不可堆叠物品数量",
    --     options = {
    --         { description = "开启", data = true },
    --         { description = "关闭", data = false },
    --     },
    --     default = false,
    -- },
    -- {
    --     name = "MAX_NON_STACKABLE",
    --     label = "不可堆叠上限",
    --     hover = "同种不可堆叠物品单次掉落的最大数量",
    --     options = {
    --         { description = "3个", data = 3 },
    --         { description = "5个", data = 5 },
    --         { description = "10个", data = 10 },
    --         { description = "20个", data = 20 },
    --         { description = "50个", data = 50 },
    --         { description = "100个", data = 100 },
    --         { description = "200个", data = 200 },
    --         { description = "500个", data = 500 },
    --         { description = "不限制", data = 9999 },
    --     },
    --     default = 5,
    -- },

    AddTitle("物品禁用"),
    {
        name = "BAN_ITEMS",
        label = "禁用物品列表,在BAN_ITEMS表中添加",
        hover = "在此表中添加要禁用的物品 prefab 名称，支持原版及 mod 物品。\n格式: {'prefab1','prefab2','prefab3'}\n被禁用的物品无法制作，现有的也会被移除并退还材料。\n留空表则不禁用任何物品。",
        options = { {description = "在服务器mod配置中添加", data = {}} },
        default = {},
    },

    AddTitle("便捷功能"),

    {
        name = "ENABLE_WARDROBE_ANYWHERE",
        label = "随身换装",
        hover = "物品栏上方显示\"换装\"按钮，随时随地打开更衣室",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    -- {
    --     name = "ENABLE_SKIN_SHARING",
    --     label = "皮肤通用化",
    --     hover = "允许玩家跨角色套用皮肤，更衣室显示全部在场角色的皮肤选项",
    --     options = {
    --         { description = "开启", data = true },
    --         { description = "关闭", data = false },
    --     },
    --     default = false,
    -- },

    AddTitle("小月亮商店"),
    {
        name = "ENABLE_MOON_SHOP",
        label = "开启小月亮商店",
        hover = "在制作栏中添加小月亮商店标签，可购买部分物品",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = false,
    },
    {
        name = "ENABLE_MOON_SHOP_BATCH",
        label = "精炼材料批量兑换",
        hover = "小月亮商店中显示原版精炼材料 x10 批量兑换配方和彩虹宝石兑换",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "ENABLE_MOON_SHOP_BOSS",
        label = "BOSS兑换",
        hover = "小月亮商店中显示用 100 水晶小人兑换 BOSS 掉落物（需 HH 附魔模组）",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "ENABLE_MOON_SHOP_SOUL",
        label = "灵魂互换",
        hover = "小月亮商店中显示 3:1 暗影/光明之魂互换配方（需泰拉模组）",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "ENABLE_MOON_SHOP_TRAVEL_TRACES",
        label = "遍历之迹兑换",
        hover = "小月亮商店中显示用 500 水晶小人兑换遍历之迹（需 HH 附魔 + 小鸟模组）",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "ENABLE_DEMON_ALTAR",
        label = "恶魔祭坛可制作",
        hover = "小月亮商店中显示恶魔祭坛购买配方",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "ENABLE_SHIJIZHIHUA_BULB",
        label = "世纪之花球茎可制作",
        hover = "小月亮商店中显示世纪之花球茎购买配方",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
}
