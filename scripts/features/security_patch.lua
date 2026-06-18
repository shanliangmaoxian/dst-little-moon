-- 小月亮 安全补丁
-- 拦截 3273001012（幸运模拟器）MoneyBuy RPC 漏洞
-- 对方 OnBuy 不校验物品是否在商店中，攻击者可绕过商店直接购买任意 prefab

local _G = GLOBAL

AddComponentPostInit("moneymanager", function(self)
    if not GLOBAL.TheWorld or not GLOBAL.TheWorld.ismastersim then
        return
    end
    local _oldOnBuy = self.OnBuy
    self.OnBuy = function(self, itemName, number, lastskin)
        if _G.TUNING.slotmachineutils and _G.TUNING.slotmachineutils.findItemInShopMap then
            if not _G.TUNING.slotmachineutils.findItemInShopMap(itemName) then
                print("[小月亮] 拦截非法购买: " .. GLOBAL.tostring(itemName))
                return false, 0
            end
        end
        return _oldOnBuy(self, itemName, number, lastskin)
    end
end)
