# AGENTS.md — 小月亮 (Little Moon) DST Mod

## Repository Structure

DST mod `小月亮 v1.15.3` — 纯 Lua, 无构建/测试/lint 基础设施.

```
modmain.lua              # 入口: modimport() 串联各模块 (顺序不可乱)
modinfo.lua              # 配置选项定义 + 元信息
scripts/
  core/                  # 核心工具层 (最先加载, 无外部依赖)
    config.lua           # 读取 modinfo 配置 → _G.MOON_CFG
    effect_manager.lua   # 附魔效果管理器
    mod_utils.lua        # 通用工具函数
    treasure_utils.lua   # 挖宝组件工具
  features/              # 功能模块 (各文件内部根据配置决定启用)
  enchants/              # 附魔石模块 (每个文件一个附魔)
  ui/                    # UI 注入 (条件加载, 见 modmain.lua:85-94)
  components/            # 自注册 DST 组件
  widgets/               # 屏幕控件
docs/
  MODDING_PITFALLS.md    # DST 沙箱踩坑记录 (必读)
  bugs.md                # 漏洞报告 (mod 3273001012)
  CHANGELOG.md           # 修改记录
demo/                    # workspace 同脚本 (demo/rsync.sh)
```

## 关键约定

- **全部 RPC 命名空间**: `"LittleMoon"` (AddModRPCHandler 第一参数)
- **配置读取**: `modinfo.lua` 定义选项 → `scripts/core/config.lua` 中 `GetModConfigData()` → `_G.MOON_CFG` 全局表
- **加载顺序**: core(4文件) → features(16文件) → enchants(38文件) → ui(条件加载) → security_patch
- **附魔注册守卫**: 每个附魔文件内部检查 `CFG.ENABLE_MORE_ENCHANTS`
- **依赖**: workshop `2526778484` (泰拉模组)
- **禁用功能**: `loot_limiter` 已在 config 中写死为 false; `skin_ownership` 和部分附魔已注释

## DST 沙箱注意事项 (详见 docs/MODDING_PITFALLS.md)

- `AddModRPCHandler`, `AddPrefabPostInit`, `modimport` 等是沙箱函数, 直接可用
- `TheNet` 在 mod 加载阶段不存在 → 需延迟到 `DownloadMods` 回调
- `Action`/`ActionHandler` 在 modimport 阶段不存在 → 需在 `AddPrefabPostInit("world")` 回调中访问 `GLOBAL.Action`
- `setfenv(1, GLOBAL)` 前必须先把沙箱函数捕获为局部变量
- `AddClassPostConstruct` 立即 `require` → 若目标类来自其他 mod 且后加载, 会报错 → 需包在 `AddPrefabPostInit("world")` 里
- `AddPrefabPostInit("world")` 在客户端不触发 → 客户端用 `AddComponentPostInit("playercontroller")`
- HH 框架附魔攻速不读 `TUNING`, 走 `hh_player.atk_speed` 组件 (上限 2x)

## 模组兼容性

- `security_patch.lua` 拦截 mod `3273001012` (幸运模拟器) 的未授权 RPC 购买
- `ban_items.lua` 支持禁用任意 prefab (含其他 mod 物品)

## 部署

`demo/rsync.sh` 同步到 Steam workshop 目录 (`/Users/maoxian/Library/Application Support/Steam/steamapps/workshop/content/322330/`).
