-- 小月亮商店

GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MOON_SHOP then return end

-- 商店标签文字
if STRINGS and STRINGS.UI and STRINGS.UI.CRAFTING_FILTERS then
    STRINGS.UI.CRAFTING_FILTERS.MOON_SHOP = "小月亮商店"
end

-- 注册商店标签（modinit 时 AddRecipeFilter 才可用）
local has_filter = false
if AddRecipeFilter ~= nil then
    AddRecipeFilter({
        name = "MOON_SHOP",
        atlas = "images/inventoryimages.xml",
        image = "goldnugget.tex",
    })
    has_filter = true
    print("[小月亮商店] 独立标签注册成功")
else
    print("[小月亮商店] AddRecipeFilter 不可用，配方将显示在全部标签")
end

local currency = CFG.MOON_SHOP_CURRENCY or "goldnugget"

local shop_items = {
    { "redgem",         "redgem",          "moon_shop_cost_redgem",          20 },
    { "bluegem",        "bluegem",         "moon_shop_cost_bluegem",         20 },
    { "purplegem",      "purplegem",       "moon_shop_cost_purplegem",       50 },
    { "yellowgem",      "yellowgem",       "moon_shop_cost_yellowgem",       50 },
    { "greengem",       "greengem",        "moon_shop_cost_greengem",        50 },
    { "orangegem",      "orangegem",       "moon_shop_cost_orangegem",       100 },
    { "thulecite",      "thulecite",       "moon_shop_cost_thulecite",       10 },
    { "livinglog",      "livinglog",       "moon_shop_cost_livinglog",       20 },
    { "nightmarefuel",  "nightmarefuel",   "moon_shop_cost_nightmarefuel",   10 },
    { "gears",          "gears",           "moon_shop_cost_gears",           20 },
    { "mandrake",       "mandrake",        "moon_shop_cost_mandrake",        100 },
    { "fireflies",      "fireflies",       "moon_shop_cost_fireflies",       20 },
    { "opalpreciousgem","opalpreciousgem", "moon_shop_cost_opalpreciousgem", 200 },
}

local filter_list = has_filter and { "MOON_SHOP" } or nil

local function InitMoonShop()
    local count = 0
    for _, item in ipairs(shop_items) do
        local cost = GetModConfigData(item[3])
        if cost == nil or cost == false then
            cost = item[4]
        end
        if cost > 0 then
            local recipe_id = "MoonShop_" .. item[1]
            if not (AllRecipes and AllRecipes[recipe_id]) then
                AddRecipe2(
                    recipe_id,
                    { Ingredient(currency, cost) },
                    TECH.NONE,
                    { product = item[2], nounlock = false },
                    filter_list
                )
                count = count + 1
            end
        end
    end
    print("[小月亮商店] 注册完成，共 " .. count .. " 件商品")
end

AddPrefabPostInit("world", function(inst)
    InitMoonShop()
end)
