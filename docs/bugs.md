# 安全漏洞报告：Mod 3273001012（幸运模拟器/老虎机）

## 概述

Mod 3273001012 的 `MoneyBuy` RPC 处理器**缺少物品合法性校验**，攻击者可以绕过商店界面，直接通过 RPC 购买任意 prefab（包括其他 mod 的物品），无需管理员权限。

---

## 漏洞详情

### 受影响文件

| 文件 | 作用 |
|------|------|
| `main/ohmnqRpc.lua:55-61` | `MoneyBuy` RPC 服务端处理器 — **缺少校验** |
| `scripts/components/moneymanager.lua:37-71` | `OnBuy` 函数 — 未校验物品是否在商店中 |
| `scripts/components/moneymanager_replica.lua:29-38` | 客户端发起购买 — 可被绕过 |

### 漏洞链路

```
攻击者客户端
  │
  │  SendModRPCToServer(MOD_RPC["ohmnq"]["MoneyBuy"], "任意prefab", 1, nil)
  │  （绕过商店UI，直接发包）
  ▼
ohmnqRpc.lua:55  MoneyBuy RPC Handler
  │  只检查: number > 0
  │  ❌ 没有检查: itemName 是否在商店配置中
  ▼
moneymanager.lua:37  OnBuy(itemName, number)
  │  getShopItemBasePrice(itemName)
  │  ├─ 物品在商店中 → 返回正常价格
  │  └─ 物品不在商店中 → 返回默认价 9999
  │
  │  if 余额 >= 总价:
  │    → SpawnPrefab(itemName)  ← 直接生成，不管是什么！
  ▼
  攻击者获得物品
```

### 关键代码

**ohmnqRpc.lua:55-61** — 缺少 `findItemInShopMap` 校验：
```lua
AddModRPCHandler("ohmnq", "MoneyBuy", function(player, itemName, number, lastskin)
    if not TheWorld.ismastersim then return end
    if type(number) ~= "number" or number <= 0 then return end
    -- ❌ 缺少: if not slotmachineutils.findItemInShopMap(itemName) then return end
    player.components.moneymanager:OnBuy(itemName, number, lastskin)
end)
```

**moneymanager.lua:50** — 直接生成任意 prefab：
```lua
local item = SpawnPrefab(itemName, lastskin, nil, player.userid)
```

**moneymanager.lua:889-898** — 未知物品默认价格 9999（不是拒绝）：
```lua
function slotmachineutils.getShopItemBasePrice(itemName, type)
    local baseBuyPrice = 9999  -- 不在商店的物品默认价格
    local item = slotmachineutils.findItemInShopMap(itemName)
    if item and item.price then
        price = item.price  -- 只有找到才用真实价格
    end
    return price  -- 找不到就返回 9999
end
```

---

## 攻击命令

在游戏内控制台（或注入脚本）执行：

```lua
SendModRPCToServer(MOD_RPC["ohmnq"]["MoneyBuy"], "hh_treasure_kps", 1, nil)
```

- `"hh_treasure_kps"` 替换为任意 prefab 名即可购买其他物品
- 数量参数 `1` 可改为任意正整数批量购买
- **只对执行者自己生效**，不影响服务器其他玩家

## 攻击条件

| 条件 | 说明 |
|------|------|
| 权限 | **无需管理员**，任何玩家都可以发 RPC |
| 余额 | 不在商店的物品 = 9999 dubloon/个 |
| 工具 | 修改客户端或注入脚本，一行 RPC 即可 |

---

## 已确认的攻击案例

攻击者通过上述漏洞购买了 Mod 3096210166（附魔强化）中的 `hh_treasure_kps`（宝藏点-超级坎普斯）。

3096210166 中可利用的部分 prefab：

| prefab | 名称 |
|--------|------|
| `hh_treasure_kps` | 宝藏点-超级坎普斯 |
| `hh_treasure_jl` | 宝藏点-月后巨鹿 |
| `hh_treasure_xd` | 宝藏点-月后熊大 |
| `hh_treasure_sy` | 宝藏点-月后霜鲨 |
| `hh_treasure_warg` | 宝藏点-附身座狼 |
| `hh_treasure_zf` | 宝藏点-甲虫猪 |
| `hh_treasure_lz` | 宝藏点-双持猪 |

---

## 修复方案

在 `ohmnqRpc.lua` 的 `MoneyBuy` handler 中增加物品校验：

```lua
AddModRPCHandler("ohmnq", "MoneyBuy", function(player, itemName, number, lastskin)
    if not TheWorld.ismastersim then return end
    if type(number) ~= "number" or number <= 0 then return end
    -- ✅ 新增：拒绝不在商店配置中的物品
    if not slotmachineutils.findItemInShopMap(itemName) then
        return
    end
    player.components.moneymanager:OnBuy(itemName, number, lastskin)
end)
```

同样建议在 `moneymanager.lua` 的 `OnBuy` 中也加入二次校验作为纵深防御。
