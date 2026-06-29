-- 小月亮 物品禁用
-- 被禁用的物品无法制作，已存在的会被移除并退还制作材料

local _G = GLOBAL
local ban_items = GetModConfigData("BAN_ITEMS")

-- 空表则跳过
if not ban_items or type(ban_items) ~= "table" or #ban_items == 0 then
    return
end

-- 构建快速查找集合
local ban_set = {}
for _, v in ipairs(ban_items) do
    if type(v) == "string" and v ~= "" then
        ban_set[v] = true
    end
end
if not next(ban_set) then return end

local function SpawnLootPrefab(owner, name, sum, pos)
    local sp = GLOBAL.SpawnPrefab(name)
    if not sp then return end
    if sp.components.stackable then
        local m = sp.components.stackable.maxsize
        local c = sum - m
        sp.components.stackable:SetStackSize(c > 0 and m or sum)
        if owner then
            if owner.components.inventory then
                owner.components.inventory:GiveItem(sp)
            end
        elseif pos then
            sp.Transform:SetPosition(pos.x, 0, pos.z)
        end
        while c > 0 do
            local loot = GLOBAL.SpawnPrefab(name)
            if c > m then
                loot.components.stackable:SetStackSize(m)
            else
                loot.components.stackable:SetStackSize(c)
            end
            if owner then
                if owner.components.inventory then
                    owner.components.inventory:GiveItem(loot)
                end
            elseif pos then
                loot.Transform:SetPosition(pos.x, 0, pos.z)
            end
            c = c - m
        end
    else
        if owner then
            if owner.components.inventory then
                owner.components.inventory:GiveItem(sp)
            end
        elseif pos then
            sp.Transform:SetPosition(pos.x, 0, pos.z)
        end
        for i = 2, sum do
            local extra = GLOBAL.SpawnPrefab(name)
            if owner then
                if owner.components.inventory then
                    owner.components.inventory:GiveItem(extra)
                end
            elseif pos then
                extra.Transform:SetPosition(pos.x, 0, pos.z)
            end
        end
    end
end

local function GetRecipeIngredients(prefab)
    for _, v in pairs(GLOBAL.AllRecipes) do
        if v.product == prefab then
            return v.ingredients, v.name
        end
    end
    return nil
end

local function RemoveAndRefund(inst)
    local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
    local pos = inst:GetPosition()
    local ingred = GetRecipeIngredients(inst.prefab)
    inst:Remove()
    if ingred then
        local ingredientmod = owner and owner.components and owner.components.builder
            and owner.components.builder.ingredientmod or 1
        for _, v in pairs(ingred) do
            SpawnLootPrefab(owner, v.type, math.ceil(v.amount * ingredientmod), pos)
        end
    end
end

-- 禁用的配方名称集合（用于UI提示）
local banned_recipe_names = {}

if GLOBAL.TheNet:GetIsServer() then
    -- 物品生成即移除
    for prefab in pairs(ban_set) do
        AddPrefabPostInit(prefab, function(inst)
            if inst.components and inst.components.container then
                if inst.components.container:IsEmpty() then
                    RemoveAndRefund(inst)
                else
                    inst.components.container:DropEverything()
                end
            else
                RemoveAndRefund(inst)
            end
        end)
    end

    -- 屏蔽配方
    AddPlayerPostInit(function(inst)
        if not GLOBAL.TheWorld then return end
        for prefab in pairs(ban_set) do
            local _, recipe_name = GetRecipeIngredients(prefab)
            if recipe_name then
                banned_recipe_names[recipe_name] = true
                local rec = GLOBAL.AllRecipes[recipe_name]
                if rec then
                    rec.canbuild = function() return false, "BANNEDITEM" end
                end
            end
        end
    end)
end

-- UI 提示
GLOBAL.STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.BUILD.BANNEDITEM = "此物品已被禁用"

AddClassPostConstruct("widgets/redux/craftingmenu_details", function(self)
    local oldUpdate = self.UpdateBuildButton
    function self:UpdateBuildButton(from_pin_slot)
        oldUpdate(self, from_pin_slot)
        if not self.data or not self.data.recipe then return end
        if banned_recipe_names[self.data.recipe.name] then
            local teaser = self.build_button_root.teaser
            teaser:SetSize(20)
            teaser:UpdateOriginalSize()
            teaser:SetMultilineTruncatedString("此物品已被禁用", 2, (self.panel_width / 2) * 0.8, nil, false, true)
            teaser:Show()
            self.build_button_root.button:Hide()
        end
    end
end)

print(string.format("[LittleMoon] 已加载物品禁用列表，共 %d 个物品", #ban_items))
