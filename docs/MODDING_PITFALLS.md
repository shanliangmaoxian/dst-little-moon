# DST Mod 开发踩坑记录

## 1. 函数归属：沙箱 vs GLOBAL

`modimport` 加载的文件运行在**沙箱环境**中。函数分两类：

| 始终在 GLOBAL 中 | 仅在沙箱中（GLOBAL 没有） | 两者都没有（延迟就绪） |
|---|---|---|
| `TheNet` | `AddAction` | `Action` |[MODDING_PITFALLS.md](MODDING_PITFALLS.md)
| `InventoryProxy` | `AddComponentAction` | `ActionHandler` |
| `TUNING` | `AddClassPostConstruct` | `AddSimPostInit` |
| `STRINGS` | `AddStategraphActionHandler` | |
| `EQUIPSLOTS` | `GLOBAL.Action` = nil | |
| `PREFAB_SKINS` | `GLOBAL.ActionHandler` = nil | |
| `ACTIONS` | | |
| `ThePlayer`/`TheWorld` | | |
| `deepcopy`/`shallowcopy` | | |
| `ValidateSpawnPrefabRequest` | | |
| `GetActiveCharacterList` | | |
| `GetCharacterSkinBases` | | |
| `GetAffinityFilterForHero` | | |
| `SetSkinsOnAnim` | | |
| `Ents`/`TheInput`/`TheFrontEnd` | | |
| `SendModRPCToServer` | | |
| `MOD_RPC`/`CLIENT_MOD_RPC` | | |

**可用的沙箱函数（已验证）：**
- `AddPrefabPostInit` — 直接用
- `AddModRPCHandler` — 直接用
- `AddPlayerPostInit` — 直接用
- `AddComponentPostInit` — 直接用
- `modimport` — 直接用

## 2. setfenv 陷阱

```lua
-- ❌ 错误：setfenv 之后沙箱函数全部丢失
GLOBAL.setfenv(1, GLOBAL)
AddAction(...)  -- nil!

-- ✅ 正确：setfenv 之前把沙箱函数捕获为局部变量
local AddAction = AddAction
local AddComponentAction = AddComponentAction
GLOBAL.setfenv(1, GLOBAL)
AddAction(...)  -- OK，用的局部变量
```

## 3. 不用 setfenv 也踩坑

即使用了局部变量捕获，`Action` 和 `ActionHandler` 在 modimport 阶段**根本不存在**（沙箱和 GLOBAL 都没有）。必须延迟到 `AddPrefabPostInit("world")` 回调里通过 `GLOBAL.Action` 访问。

```lua
-- ❌ modimport 时 Action 不存在
local Action = Action  -- nil

-- ✅ 延迟到 world 初始化后
AddPrefabPostInit("world", function()
    local Action = GLOBAL.Action  -- 此时可用
end)
```

## 4. HH 框架攻速限制

HH 框架用自己的 `hh_player` 组件管理攻速，不读 `TUNING.WILSON_ATTACK_PERIOD`。

```
原版: TUNING.WILSON_ATTACK_PERIOD → combat 组件 → 生效
HH:   hh_player.atk_speed → 内置 2x 上限 → TUNING 无效
```

攻速上限由 HH 框架硬编码，只能通过 `hh:AddEffectValueByKey("atk_speed", N)` 调整（N≤100）。

## 5. 随身换装实现

不需要 spawn 实体。直接给 player 加 `wardrobe` 组件：

```lua
if not player.components.wardrobe then
    player:AddComponent("wardrobe")
end
player.components.wardrobe:BeginChanging(player)
```

## 6. RPC 命名空间

`AddModRPCHandler` 的第一个参数（命名空间）必须与 `MOD_RPC[命名空间]` 一致。本项目统一用 `"LittleMoon"`。

## 7. 已放弃的功能

| 功能 | 原因 |
|------|------|
| 物品栏换肤 | `Action`/`ActionHandler` 在 modimport 和 PrefabPostInit 中均不可用 |
| 解除攻速限制 | HH 框架无视 `TUNING.WILSON_ATTACK_PERIOD`，有独立的 2x 攻速上限 |
| 包裹内容预览 | 用户自行移除 |

## 8. 检查清单（加新功能前过一遍）

1. 用了哪些 DST API 函数？查上表确认归属
2. 如果用 setfenv → 沙箱函数必须先捕获为 local
3. 如果不用 setfenv → 沙箱函数直接用不加前缀，GLOBAL 的函数用 `_G.xxx`
4. `Action`/`ActionHandler` → 必须在 `AddPrefabPostInit("world")` 回调里用
5. 新 RPC → 命名空间统一用 `"LittleMoon"`
6. 涉及 HH 框架属性 → 走 `hh_player` 组件，不要改 TUNING
7. Config → modinfo.lua + config.lua + modmain.lua 三处同步
