-- 小月亮 附魔：新史低 (#Legend_XSD)
-- 获取：精英/Boss 概率掉落（低权重）
-- 效果：装备时，在「欧皇模拟器」(workshop-3273001012) 的商店购物打 5~9 折
--       附魔石属性值 50~90 → 折扣 = 属性值/100（附魔石生成时随机，两端天然一致）
-- 前置：需同时开启 3273001012（幸运模拟器/欧皇模拟器）mod 才生效
--
-- 双端注册说明：
--   * AddPrefabPostInit("world") 仅服务端触发（小月亮惯例）
--   * AddPlayerPostInit 两端都触发；客户端靠它补注册词条 + 折扣 hook，
--     否则客户端商店 UI 显示原价（且余额判断会按原价置灰按钮，误伤打折购买）

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- =========================================================
-- Part 1: 组件钩子（编译期注册，运行期检测附魔是否存在）
-- =========================================================

-- 1a. 包装 MoneyManager:OnBuy，提供"当前购买买家"上下文
--     供 getShopItemFinalPrice 判断是否打折（getShopItemFinalPrice 无玩家参数）
AddComponentPostInit("moneymanager", function(self)
    if not _G.TheWorld or not _G.TheWorld.ismastersim then
        return
    end
    local _old_OnBuy = self.OnBuy
    self.OnBuy = function(self, itemName, number, lastskin)
        -- rawset/rawget 绕过 strict.lua 的全局未声明检查（字段仅在购买期间临时存在）
        _G.rawset(_G, "_Moon_ShopBuyer", self.inst)
        local results = { _G.pcall(_old_OnBuy, self, itemName, number, lastskin) }
        _G.rawset(_G, "_Moon_ShopBuyer", nil)
        if results[1] then
            return results[2], results[3]
        end
        _G.print("[小月亮] 新史低: 购买处理异常 " .. _G.tostring(results[2]))
        return false, 0
    end
end)

-- =========================================================
-- Part 2: 词条配置（服务端/客户端共用，保证两端行为一致）
-- =========================================================
local XSD_CONFIG = {
    name = "新史低",
    client_text = "新\n史低",
    desc = "「欧皇模拟器」商店购物折扣！\n装备后商店物品 5~9 折",
    check_desc = "需同时开启「欧皇模拟器」mod（workshop-3273001012）",
    ui_from_desc = "精英/Boss 概率掉落（低权重）",
    can_add = false,
    only_one = true,
    is_special = false,
    client_color = { 0.8, 0, 0.8, 1 },
    value_range = { min = 50, max = 90 },
    check_equip_can_add = function(inst)
        return true, "满足条件"
    end,
    on_equip_fn = function(inst, owner, value)
        _G.Moon_AddEffect(owner, "xinshidi", "Legend_XSD", 1)
        -- 按装备记录折扣，多件同词条取最优惠
        owner._xsd_discounts = owner._xsd_discounts or {}
        owner._xsd_discounts[inst] = (value or 90) / 100
        local best = 1
        for _, d in pairs(owner._xsd_discounts) do
            if d < best then best = d end
        end
        owner._xsd_discount = best
        if _G.TheWorld and _G.TheWorld.ismastersim and owner.components.talker then
            owner.components.talker:Say(string.format("新史低！商店购物 %.0f 折！", best * 10))
        end
    end,
    un_equip_fn = function(inst, owner, value)
        if owner._xsd_discounts then owner._xsd_discounts[inst] = nil end
        _G.Moon_ReduceEffect(owner, "xinshidi", "Legend_XSD", 1)
        if _G.Moon_HasEffect(owner, "xinshidi") then
            -- 还有其他件，重算最优惠折扣
            local best = 1
            for _, d in pairs(owner._xsd_discounts or {}) do
                if d < best then best = d end
            end
            owner._xsd_discount = best
        else
            owner._xsd_discount = nil
            owner._xsd_discounts = nil
        end
    end,
}

-- =========================================================
-- Part 3: 安装（两端共用；各自时机触发一次）
-- =========================================================
local installed = false
local function XSD_Install()
    if installed then return end
    -- 仅当同时开启 HH 附魔框架 + 3273001012（欧皇模拟器）且其运行时数据存在时生效
    if not _G.Moon_IsHHEnabled() then return end
    if not _G.Moon_IsModEnabled("workshop-3273001012") then return end
    local utils = _G.TUNING and _G.TUNING.slotmachineutils
    if not utils or not utils.getShopItemFinalPrice then return end

    installed = true

    -- 3a. 折扣 hook：getShopItemFinalPrice 是商店 UI（shopTab）与服务端扣款
    --     （MoneyManager:OnBuy）的唯一定价出口，hook 一处两端价格一致
    if not utils._moon_xsd_hooked then
        utils._moon_xsd_hooked = true
        local _old_getShopItemFinalPrice = utils.getShopItemFinalPrice
        utils.getShopItemFinalPrice = function(itemName)
            local price = _old_getShopItemFinalPrice(itemName)
            -- 服务端：购买流程中的买家（由 1a 的 OnBuy 包装临时设置）
            -- rawget 读取：该全局字段并非永久存在，直接读会触发 strict.lua 未声明报错
            local owner = _G.rawget(_G, "_Moon_ShopBuyer")
            -- 客户端：本地玩家（商店 UI 显示价格 / 余额判断）
            if not owner then
                owner = _G.rawget(_G, "ThePlayer")
                if owner and not owner:IsValid() then owner = nil end
            end
            if owner and owner._xsd_discount and _G.Moon_HasEffect(owner, "xinshidi") then
                return price * owner._xsd_discount
            end
            return price
        end
    end

    -- 3b. 附魔注册
    _G.AddSpecialEquipEffect("Legend_XSD", XSD_CONFIG)

    -- 3c. 掉落注册（仅服务端；低权重）
    if _G.TheWorld and _G.TheWorld.ismastersim then
        _G.Moon_RegisterEnchantDrop("Legend_XSD", 0.005)
    end
end

-- 服务端：世界创建时安装（客户端 world 回调不触发，由 AddPlayerPostInit 补装）
AddPrefabPostInit("world", function(inst)
    XSD_Install()
end)

-- 客户端：本地玩家创建时补装（两端都会触发；服务端已被 installed 标记跳过）
AddPlayerPostInit(function(inst)
    XSD_Install()
end)
