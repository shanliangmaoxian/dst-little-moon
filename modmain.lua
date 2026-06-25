-- ================================================================================
-- 小月亮 (Little Moon) — 主入口
-- 功能模块拆分到 scripts/ 目录，此处仅做串联导入
-- ================================================================================

local _G = GLOBAL

-- 骰子 RPC 在最顶部注册（确保客户端 MOD_RPC 表正确填充）
AddModRPCHandler("LittleMoon", "RollDice", function(player)
    if _G.Moon_DoDiceRoll then _G.Moon_DoDiceRoll(player) end
end)

-- ------------------------------------------------------------------
-- 1. 核心工具层 (无依赖，最先加载)
-- ------------------------------------------------------------------
modimport("scripts/core/config")
modimport("scripts/core/effect_manager")
modimport("scripts/core/mod_utils")
modimport("scripts/core/treasure_utils")

-- ------------------------------------------------------------------
-- 2. 功能模块 (各文件内部根据配置决定是否启用)
-- ------------------------------------------------------------------
modimport("scripts/features/anti_packing")
modimport("scripts/features/loot_limiter")
modimport("scripts/features/treasure")
modimport("scripts/features/quick_dig")
modimport("scripts/features/auto_pickup")
modimport("scripts/features/suicide")
modimport("scripts/features/demon_altar")
modimport("scripts/features/disable_reselect")
modimport("scripts/features/enchant_remover")
-- modimport("scripts/features/skin_ownership")
modimport("scripts/features/wardrobe_anywhere")

-- ------------------------------------------------------------------
-- 3. 附魔模块
-- ------------------------------------------------------------------
modimport("scripts/enchants/drop_utils")
modimport("scripts/enchants/mx_health")
modimport("scripts/enchants/zd_butterfly")
modimport("scripts/enchants/fqcd_sanity")
modimport("scripts/enchants/myxl_level")
modimport("scripts/enchants/yzdx")
modimport("scripts/enchants/wywq")
-- modimport("scripts/enchants/wjbd")   烷基八氮去掉
modimport("scripts/enchants/lanqiu")
modimport("scripts/enchants/aiyo")
modimport("scripts/enchants/fay")
-- modimport("scripts/enchants/yzq")  -- 云中雀已注释
modimport("scripts/enchants/mgcy")
modimport("scripts/enchants/kongbai")
modimport("scripts/enchants/strawberry")
-- modimport("scripts/enchants/mxm")  -- 萌新已注释
modimport("scripts/enchants/gugugu")
modimport("scripts/enchants/ganfan")
modimport("scripts/enchants/hufei")
modimport("scripts/enchants/qianyue")
modimport("scripts/enchants/xping")
-- modimport("scripts/enchants/jiuyue") -- 九月已注释，后续可能重做
modimport("scripts/enchants/genzhe")
modimport("scripts/enchants/suansuancao")
modimport("scripts/enchants/panghu")
modimport("scripts/enchants/dagongren")
modimport("scripts/enchants/dengqiuling")
modimport("scripts/enchants/junjun")
modimport("scripts/enchants/luo")
modimport("scripts/enchants/lianggongcang")
modimport("scripts/enchants/huaimin")
modimport("scripts/enchants/laodong")
modimport("scripts/enchants/changpi")
modimport("scripts/enchants/xiaoguai")
modimport("scripts/enchants/shanzhu")
modimport("scripts/enchants/xingyunchengzhi")

-- ------------------------------------------------------------------
-- 4. UI 界面 (仅当任一相关功能启用时加载)
-- ------------------------------------------------------------------
local CFG = GLOBAL.MOON_CFG
if CFG.ENABLE_TREASURE or CFG.ENABLE_QL_HELPER or CFG.ENABLE_AUTO_PICKUP or CFG.ENABLE_SUICIDE or CFG.ENABLE_MORE_ENCHANTS then
    modimport("scripts/ui/moon_button")
    modimport("scripts/ui/moon_panel")
end

-- ------------------------------------------------------------------
-- 5. 安全补丁 (始终加载)
-- ------------------------------------------------------------------
modimport("scripts/features/security_patch")
