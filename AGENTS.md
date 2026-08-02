# AGENTS.md — 小月亮 (Little Moon) DST Mod

## Repository Structure

DST mod `小月亮 v1.16.1` (modinfo.lua, author 九月) — 纯 Lua, 无构建/测试/lint 基础设施.

```
modmain.lua              # 入口: Assets 声明 + RollDice RPC + modimport() 串联 (顺序不可乱)
modinfo.lua              # 配置选项定义 + 元信息; 依赖 workshop 2526778484
scripts/
  core/                  # 核心工具层 (最先加载, 无外部依赖)
    config.lua           # GetModConfigData() → _G.MOON_CFG 全局表
    effect_manager.lua   # 附魔效果管理器
    mod_utils.lua        # 通用工具函数
    treasure_utils.lua   # 挖宝组件工具
  features/              # 功能模块 (各文件内部按配置决定启用)
    mob_enhance/         # 怪物强化子模块 (init.lua + enchants_pool.lua)
  enchants/              # 附魔模块 (47 文件, 每个附魔一个; drop_utils.lua 是公共工具)
  ui/                    # UI 注入 (条件加载, 见 modmain.lua:112-120)
  components/            # 自注册 DST 组件 (moon_death_counter, moon_mob_enhance)
  widgets/               # 屏幕控件 (little_moon_panel, death_stats_panel)
  prefabs/               # 空目录
docs/
  CHANGELOG.md           # 修改记录 (当前到 1.16.1)
  enchants.md            # 附魔列表 (36 个, #1~#34 + #97~#98)
  git.md                 # 提交规范 (Angular 简化版)
  bugs.md                # 漏洞报告 (mod 3273001012)
  MODDING_PITFALLS.md    # ⚠️ 悬空指针, 见下
demo/                    # 其他 mod 参考副本 (被 .gitignore 忽略, 非部署脚本)
.claude/skills/          # bump-version skill
```

## 关键约定

- **全部 RPC 命名空间**: `"LittleMoon"` (AddModRPCHandler 第一参数; modmain RollDice + 6 个 feature 文件)
- **配置读取**: modinfo.lua → `scripts/core/config.lua` 中 `GetModConfigData()` → `_G.MOON_CFG` 全局表
- **加载顺序** (modmain.lua): core(4) → features(15 个导入; `skin_ownership` 注释、`demon_altar` 存在但未导入) → enchants(42 加载; 注释: `zd_butterfly`/`wjbd`/`yzq`/`mxm`/`jiuyue`) → ui(条件加载) → security_patch → 蓝图本地化兜底 (`AddPrefabPostInit("world")` 补 MoonShop_ 配方缺失的 STRINGS.NAMES)
- **附魔注册守卫**: 每个附魔文件内部检查 `CFG.ENABLE_MORE_ENCHANTS` 才注册 (drop_utils.lua 例外)
- **写死禁用**: `CFG.ENABLE_LOOT_LIMITER = false`, `CFG.ENABLE_AUTO_PICKUP = false` (config.lua 内注释: modinfo 已移除配置项, 写死防旧档残留, 下个版本清理)
- **提交规范**: 遵循 docs/git.md — `fix:/feat:/docs:/style:/refactor: + 中文描述`, 版本号打 git tag 不写进 commit 消息
- **版本递增**: 用 bump-version skill (递增 modinfo.lua + 写 docs/CHANGELOG.md)

## DST 沙箱注意事项 (详见 docs/MODDING_PITFALLS.md)

- `AddModRPCHandler`, `AddPrefabPostInit`, `modimport` 等是沙箱函数, 直接可用
- `TheNet` 在 mod 加载阶段不存在 → 需延迟到 `DownloadMods` 回调
- `Action`/`ActionHandler` 在 modimport 阶段不存在 → 需在 `AddPrefabPostInit("world")` 回调中访问 `GLOBAL.Action`
- `setfenv(1, GLOBAL)` 前必须先把沙箱函数捕获为局部变量
- `AddClassPostConstruct` 立即 `require` → 若目标类来自其他 mod 且后加载, 会报错 → 需包在 `AddPrefabPostInit("world")` 里
- `AddPrefabPostInit("world")` 在客户端不触发 → 客户端用 `AddComponentPostInit("playercontroller")`
- HH 框架附魔攻速不读 `TUNING`, 走 `hh_player.atk_speed` 组件 (上限 2x)

> ⚠️ `docs/MODDING_PITFALLS.md` 目前只含一行指向 `../../dst-little-star/.claude/MODDING_PITFALLS.md` 的引用, 但该文件不存在 (悬空指针, 坑位记录已丢失). 新踩坑请直接在 docs/MODDING_PITFALLS.md 重建内容.

## 模组兼容性

- `security_patch.lua` 拦截 mod `3273001012` (幸运模拟器) 未授权 RPC 购买 (v1: MoneyBuy; v2: metatable `__concat/__div` 走私检测, 默认关闭 `ENABLE_V2 = false`)
- `ban_items.lua` 支持禁用任意 prefab (含其他 mod 物品)
- `demo/` 存放兼容/依赖 mod 的参考副本: `3096210166_附魔强化` (HH 框架), `3672431769_更多附魔石`, `3700206644_让我瞧瞧`, `dst-little-star` (同作者姊妹 mod) — 跨 mod 开发时对照用

## 部署

无自动部署脚本 (demo/ 不是部署工具). 手动拷贝到 Steam workshop 目录: `steamapps/workshop/content/322330/`.

## Notes

(快速补充区)
