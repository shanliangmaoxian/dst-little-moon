-- 小月亮商店 — 原版精炼材料 x10 批量兑换

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

-- 精炼材料批量兑换: { product, { {原料, 数量}, ... } }
local shop_items = {
    { "cutstone",       { { "rocks",      30 } } },  -- 3x10
    { "boards",         { { "log",        40 } } },  -- 4x10
    { "rope",           { { "cutgrass",   30 } } },  -- 3x10
    { "papyrus",        { { "cutreeds",   40 } } },  -- 4x10
}

local function InitMoonShop()
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
                TECH.NONE,
                { product = item[1], nounlock = false, numtogive = 10 },
                filter_list
            )
            count = count + 1
        end
    end
    print("[小月亮商店] 注册完成，共 " .. count .. " 件批量精炼配方")
end

AddPrefabPostInit("world", function(inst)
    InitMoonShop()
end)
