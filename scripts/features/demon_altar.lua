-- 小月亮 恶魔祭坛制作配方
-- 虚空异界(泰拉)：emojitan + 世纪之花球茎

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_DEMON_ALTAR then return end

local function RegisterAltarRecipe()
    local Ingredient = _G.Ingredient
    local RECIPETABS = _G.RECIPETABS
    local TECH = _G.TECH

    -- 检查配方是否已存在，或预制体是否不存在
    if (_G.AllRecipes and _G.AllRecipes["emojitan"]) or not _G.PrefabExists("emojitan") then
        return
    end

    -- 补全基础字符串
    if not _G.STRINGS.NAMES.EMOJITAN then _G.STRINGS.NAMES.EMOJITAN = "恶魔祭坛" end
    if not _G.STRINGS.RECIPE_DESC.EMOJITAN then _G.STRINGS.RECIPE_DESC.EMOJITAN = "虚空异界的远古祭坛" end
    if not _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.EMOJITAN then _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.EMOJITAN = "散发着不详的气息。" end

    local ok, err = _G.pcall(function()
        AddRecipe("emojitan",
            {
                Ingredient("thulecite", 6),
                Ingredient("purplegem", 4),
                Ingredient("livinglog", 6),
                Ingredient("goldnugget", 10),
                Ingredient("nightmarefuel", 20),
            },
            RECIPETABS.MAGIC,
            TECH.MAGIC_TWO,
            {
                placer = "emojitan_placer",
                min_spacing = 2,
                nounlock = true,
            }
        )
    end)
    if ok then
        _G.print("[小月亮] emojitan 配方注册成功")
    end

    -- 世纪之花球茎
    if CFG.ENABLE_SHIJIZHIHUA_BULB then
        if not _G.STRINGS.NAMES.SHIJIZHIHUA_BULB then _G.STRINGS.NAMES.SHIJIZHIHUA_BULB = "世纪之花球茎" end
        if not _G.STRINGS.RECIPE_DESC.SHIJIZHIHUA_BULB then _G.STRINGS.RECIPE_DESC.SHIJIZHIHUA_BULB = "原地放置，召唤世纪之花" end
        if not _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHIJIZHIHUA_BULB then _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHIJIZHIHUA_BULB = "一颗散发着自然与机械气息的球茎。" end

        local ok2, err2 = _G.pcall(function()
            AddRecipe("shijizhihua_bulb",
                {
                    Ingredient("jixiemoyan", 3),
                    Ingredient("jixiexinbiao", 3),
                    Ingredient("laohuaxinhaofasheqi", 3),
                },
                RECIPETABS.MAGIC,
                TECH.NONE,
                {
                    nounlock = true,
                }
            )
        end)
        if ok2 then
            _G.print("[小月亮] shijizhihua_bulb 配方注册成功")
        end
    end
end

-- 延迟注册，确保所有 Mod 的 Prefab 都已加载完成
AddPrefabPostInit("world", function(inst)
    RegisterAltarRecipe()
end)
