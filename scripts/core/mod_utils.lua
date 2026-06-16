-- 小月亮 Mod 检测工具
-- 全局函数前缀: Moon_

local _G = GLOBAL

-- 检测指定 Mod 是否启用
function _G.Moon_IsModEnabled(id)
    if not GLOBAL.KnownModIndex then return false end
    return GLOBAL.KnownModIndex:IsModEnabledAny(id)
end

-- 检测 HH 附魔框架是否启用
function _G.Moon_IsHHEnabled()
    return _G.Moon_IsModEnabled("workshop-3096210166")
        or _G.Moon_IsModEnabled("workshop-3709314660")
end

-- 检测璇儿 Mod 是否启用
function _G.Moon_IsMYXLEnabled()
    return _G.Moon_IsModEnabled("workshop-3014076942")
end
