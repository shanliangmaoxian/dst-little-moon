-- 小月亮商店 — 原版精炼材料 x10 批量兑换 + Boss 兑换

GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MOON_SHOP then return end

-- 商店标签文字
if STRINGS and STRINGS.UI and STRINGS.UI.CRAFTING_FILTERS then
    STRINGS.UI.CRAFTING_FILTERS.MOON_SHOP = "小月亮商店"
end

-- 注册商店标签
local has_filter = false
if AddRecipeFilter ~= nil then
    local tex = "lunar_seed.tex"
    local atlas = GetInventoryItemAtlas(tex) or "images/inventoryimages.xml"
    AddRecipeFilter({
        name = "MOON_SHOP",
        atlas = atlas,
        image = tex,
    })
    has_filter = true
    print("[小月亮商店] 独立标签注册成功")
end

local filter_list = has_filter and { "MOON_SHOP" } or nil

local hh_enabled = _G.Moon_IsModEnabled("workshop-3096210166")
local soul_exchange_enabled = _G.Moon_IsModEnabled("workshop-2526778484")

-- 织影者地上防自毁（模块加载时注册，确保在第一个实例出生前生效）
if hh_enabled then
    AddPrefabPostInit("stalker_atrium", function(inst)
        local _IsNearAtrium = inst.IsNearAtrium
        inst.IsNearAtrium = function() return true end
        local _OnEntitySleep = inst.OnEntitySleep
        inst.OnEntitySleep = function() return true end
    end)
    print("[小月亮商店] 织影者防自毁补丁已注册")
end

-- 精炼材料批量兑换: { product, { {原料, 数量}, ... } }
local shop_items = {
    { "cutstone",       { { "rocks",      30 } } },  -- 3x10
    { "boards",         { { "log",        40 } } },  -- 4x10
    { "rope",           { { "cutgrass",   30 } } },  -- 3x10
    { "papyrus",        { { "cutreeds",   40 } } },  -- 4x10
}

local function InitMoonShop()

    -- 批量材料兑换: 精炼材料 x10 + 彩虹宝石
    if CFG.ENABLE_MOON_SHOP_BATCH then
        local count = 0
        for _, item in ipairs(shop_items) do
            local recipe_id = "MoonShop_" .. item[1]
            if not (AllRecipes and AllRecipes[recipe_id]) then
                local ingredients = {}
                for _, ing in ipairs(item[2]) do
                    table.insert(ingredients, Ingredient(ing[1], ing[2]))
                end
                AddRecipe2(
                    recipe_id,
                    ingredients,
                    TECH.SCIENCE_ONE,
                    { product = item[1], nounlock = false, numtogive = 10 },
                    filter_list
                )
                count = count + 1
            end
        end
        print("[小月亮商店] 批量精炼配方注册完成，共 " .. count .. " 件")

        -- 彩虹宝石批量兑换: 各色宝石 xN → 彩虹宝石 xN
        local gem_count = 0
        local gem_colors = { "redgem", "bluegem", "purplegem", "orangegem", "yellowgem", "greengem" }
        for _, batch in ipairs({ 10, 100 }) do
            local recipe_id = "MoonShop_opalpreciousgem_" .. batch
            if not (AllRecipes and AllRecipes[recipe_id]) then
                local ingredients = {}
                for _, gem in ipairs(gem_colors) do
                    table.insert(ingredients, Ingredient(gem, batch))
                end
                AddRecipe2(
                    recipe_id,
                    ingredients,
                    TECH.NONE,
                    { product = "opalpreciousgem", nounlock = true, numtogive = batch },
                    filter_list
                )
                gem_count = gem_count + 1
            end
        end
        print("[小月亮商店] 彩虹宝石兑换注册完成，共 " .. gem_count .. " 件")
    end

    -- HH附魔强化 Boss 兑换 (100 水晶小人)
    if CFG.ENABLE_MOON_SHOP_BOSS and hh_enabled then
        local boss_items = {
            { "alterguardian_phase4_lunarrift", "天体后裔" },
            { "stalker_atrium",       "织影者" },
        }
        local boss_atlas = {
            alterguardian_phase4_lunarrift = { atlas = "images/inventoryimages/alterguardian_phase4_lunarrift.xml", image = "alterguardian_phase4_lunarrift.tex" },
            stalker_atrium = { atlas = "images/inventoryimages/stalker_atrium.xml", image = "stalker_atrium.tex" },
        }
        local boss_count = 0
        for _, item in ipairs(boss_items) do
            local recipe_id = "MoonShop_" .. item[1]
            if not (AllRecipes and AllRecipes[recipe_id]) then
                local recipe = AddRecipe2(
                    recipe_id,
                    { Ingredient("hh_essence", 100) },
                    TECH.NONE,
                    { product = item[1], nounlock = true, numtogive = 1 },
                    filter_list
                )
                if recipe and boss_atlas[item[1]] then
                    recipe.atlas = boss_atlas[item[1]].atlas
                    recipe.image = boss_atlas[item[1]].image
                end
                boss_count = boss_count + 1
            end
        end
        print("[小月亮商店] Boss兑换注册完成，共 " .. boss_count .. " 件")
    end

    -- 灵魂兑换 (需要模组 2526778484)
    if CFG.ENABLE_MOON_SHOP_SOUL and soul_exchange_enabled then
        local soul_atlas = {
            white_soul = { atlas = "images/inventoryimages/white_soul.xml", image = "white_soul.tex" },
            black_soul = { atlas = "images/inventoryimages/black_soul.xml", image = "black_soul.tex" },
        }
        local soul_exchanges = {
            { "white_soul", "black_soul" },
            { "black_soul", "white_soul" },
        }
        local soul_count = 0
        for _, ex in ipairs(soul_exchanges) do
            local recipe_id = "MoonShop_" .. ex[1] .. "_from_" .. ex[2]
            if not (AllRecipes and AllRecipes[recipe_id]) then
                local ing = soul_atlas[ex[2]]
                local prod = soul_atlas[ex[1]]
                local recipe = AddRecipe2(
                    recipe_id,
                    { Ingredient(ex[2], 3, ing.atlas, ing.image) },
                    TECH.NONE,
                    { product = ex[1], nounlock = true, numtogive = 1 },
                    filter_list
                )
                if recipe then
                    recipe.atlas = prod.atlas
                    recipe.image = prod.image
                end
                soul_count = soul_count + 1
            end
        end
        print("[小月亮商店] 灵魂兑换注册完成，共 " .. soul_count .. " 件")
    end

    -- 虚空异界(泰拉): emojitan + 世纪之花球茎
    if CFG.ENABLE_DEMON_ALTAR then
        if not _G.STRINGS.NAMES.EMOJITAN then _G.STRINGS.NAMES.EMOJITAN = "恶魔祭坛" end
        if not _G.STRINGS.RECIPE_DESC.EMOJITAN then _G.STRINGS.RECIPE_DESC.EMOJITAN = "虚空异界的远古祭坛" end
        if not _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.EMOJITAN then _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.EMOJITAN = "散发着不详的气息。" end

        local altar_recipe_id = "MoonShop_emojitan"
        if not (AllRecipes and AllRecipes[altar_recipe_id]) then
            local recipe = AddRecipe2(
                altar_recipe_id,
                {
                    Ingredient("thulecite", 6),
                    Ingredient("purplegem", 4),
                    Ingredient("livinglog", 6),
                    Ingredient("goldnugget", 10),
                    Ingredient("nightmarefuel", 20),
                },
                TECH.NONE,
                { product = "emojitan", nounlock = true, placer = "emojitan_placer", min_spacing = 2, numtogive = 1 },
                filter_list
            )
            if recipe then
                recipe.atlas = "images/inventoryimages/emojitan.xml"
                recipe.image = "emojitan.tex"
            end
            print("[小月亮商店] emojitan 配方注册成功")
        end

        if CFG.ENABLE_SHIJIZHIHUA_BULB then
            if not _G.STRINGS.NAMES.SHIJIZHIHUA_BULB then _G.STRINGS.NAMES.SHIJIZHIHUA_BULB = "世纪之花球茎" end
            if not _G.STRINGS.RECIPE_DESC.SHIJIZHIHUA_BULB then _G.STRINGS.RECIPE_DESC.SHIJIZHIHUA_BULB = "原地放置，召唤世纪之花" end
            if not _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHIJIZHIHUA_BULB then _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHIJIZHIHUA_BULB = "一颗散发着自然与机械气息的球茎。" end

            local bulb_recipe_id = "MoonShop_shijizhihua_bulb"
            if not (AllRecipes and AllRecipes[bulb_recipe_id]) then
                local recipe = AddRecipe2(
                    bulb_recipe_id,
                    {
                        Ingredient("jixiemoyan", 3),
                        Ingredient("jixiexinbiao", 3),
                        Ingredient("laohuaxinhaofasheqi", 3),
                    },
                    TECH.NONE,
                    { product = "shijizhihua_bulb", nounlock = true, numtogive = 1 },
                    filter_list
                )
                if recipe then
                    recipe.atlas = "images/inventoryimages/shijizhihua.xml"
                    recipe.image = "shijizhihua.tex"
                end
                print("[小月亮商店] shijizhihua_bulb 配方注册成功")
            end
        end
    end
end

AddPrefabPostInit("world", function(inst)
    InitMoonShop()
end)
