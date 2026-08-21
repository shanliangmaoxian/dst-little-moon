-- 小月亮 附魔：梨花雪
-- 提高魔女的锻体属性增幅 20%~100%（附魔时随机确定），仅可附魔胸针，唯一
-- 依赖魔女之旅 Mod (workshop-2578692071)
-- 实现：附魔生效期间临时提升 elaina_dt.zf（锻体增幅），使全 mod 所有读 zf 的
--       乘算点（攻击/暴击/穿甲/吸血/财富/生命等）统一吃到增幅。
--       核心：把 mod 的 ClearSx / AddSxAll 包装为「幂等版本」——每次应用前按
--       上次生效倍率精确清除累加型属性（mod 原 ClearSx 用未增幅值 -v 清除，
--       zf>0 时每轮净增 v*zf/100 导致穿脱/重进叠加），覆盖型由 SetModifier
--       天然覆盖。无论 mod 内部何时调用（OnLoad 延迟 0.5s、增幅碎片、玩家
--       操作）都幂等。存档仍写基准增幅，不污染存档。

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- 依赖 Mod 未开启时不注册（魔女之旅）
if not _G.Moon_IsModEnabled("workshop-2578692071") then return end

-- 累加型锻体属性（GetSx 内部为 += 累加，重算时需精确清除）
-- 移速/攻击加成/防御加成/饱食下降为覆盖型（SetModifier），由 AddSxAll 直接覆盖，无需清除
local ADD_SX_MAP = {
    fq = "法强",
    health = "生命",
    san = "san",
    hunger = "饱食度",
    magic = "最大魔法值",
    magic_sf = "多重施法概率",
    wmfy = "位面防御",
    wmsh = "位面伤害",
    magic_hf = "魔法恢复速度",
}

-- 按上次生效倍率精确清除累加型属性
local function clear_applied(dt)
    if not dt or not dt._moon_lhx_applied then return end
    local prev_zf = dt._moon_lhx_prev_zf
    if prev_zf == nil then prev_zf = dt.zf or 0 end
    local prev_mult = 1 + prev_zf / 100
    local sx_tab = dt.sx_tab
    if sx_tab then
        for value, sx_name in pairs(ADD_SX_MAP) do
            local v = sx_tab[value]
            if v and v ~= 0 then
                dt:GetSx(sx_name, -v * prev_mult)
            end
        end
    end
    dt._moon_lhx_applied = false
end

-- 精确重算：设置新 zf 后走包装版 AddSxAll（先清旧再应用，幂等）
local function reapply(dt, new_zf)
    if not dt then return end
    dt.zf = new_zf
    dt:AddSxAll()
    -- 同步客户端面板显示的增幅值
    if dt.inst and dt.inst.replica and dt.inst.replica.elaina_dt
        and dt.inst.replica.elaina_dt.zf then
        dt.inst.replica.elaina_dt.zf:set(new_zf)
    end
end

-- =========================================================
-- elaina_dt 组件增强（一次性包装原型方法）
-- =========================================================
AddComponentPostInit("elaina_dt", function(inst, self)
    if not self then return end

    -- 每个实例初始化
    if self._moon_lhx_base == nil then
        self._moon_lhx_base = self.zf or 0
    end
    if self._moon_lhx_prev_zf == nil then
        self._moon_lhx_prev_zf = self.zf or 0
    end
    if self._moon_lhx_applied == nil then
        self._moon_lhx_applied = false -- 属性尚未应用（首次 AddSxAll 前）
    end

    local proto = getmetatable(self).__index
    if proto and not proto._moon_lhx_patched then
        proto._moon_lhx_patched = true

        local origOnSave = proto.OnSave
        local origOnLoad = proto.OnLoad
        local origAddSx = proto.AddSx
        local origClearSx = proto.ClearSx
        local origAddSxAll = proto.AddSxAll

        -- 读取玩家身上的梨花雪附魔增量
        local function get_extra(player)
            if not player or not _G.Moon_GetTotalEffectValue then return 0 end
            return _G.Moon_GetTotalEffectValue(player, "lhx") or 0
        end

        -- ClearSx：改为按当前生效值精确清除（幂等，修复 mod 残留 bug）
        proto.ClearSx = function(self2)
            clear_applied(self2)
        end

        -- AddSxAll：应用前先精确清除旧值，再按当前 zf 应用（幂等）
        proto.AddSxAll = function(self2)
            clear_applied(self2)
            local r = origAddSxAll and origAddSxAll(self2)
            self2._moon_lhx_prev_zf = self2.zf or 0
            self2._moon_lhx_applied = true
            return r
        end

        -- OnSave：存档写基准增幅，防止附魔增量入档（仅玩家，小礼物等实体不干预）
        proto.OnSave = function(self2)
            local data = origOnSave and origOnSave(self2)
            if data and self2._moon_lhx_base ~= nil
                and self2.inst and self2.inst:HasTag("player") then
                data.zf = self2._moon_lhx_base
            end
            return data
        end

        -- OnLoad：同步基准；附魔在身则提升 zf 字段。属性由 mod 原 OnLoad 延迟
        -- 0.5s 的 AddSxAll（包装版，幂等）统一应用，此处只动字段不动属性
        proto.OnLoad = function(self2, data)
            if origOnLoad then origOnLoad(self2, data) end
            self2.zf = self2.zf or 0
            self2._moon_lhx_base = self2.zf
            if self2.inst and self2.inst:HasTag("player") then
                local extra = get_extra(self2.inst)
                if extra > 0 then
                    self2.zf = self2.zf + extra
                end
            end
        end

        -- AddSx（获得/选择锻体词条）：先把状态精确还原到干净状态再让 mod 原
        -- 流程执行（其 ClearSx/AddSxAll 已是包装版，全链路幂等），跑完后同步
        -- 基准并重新应用附魔增量（新词条同样吃到增幅）
        proto.AddSx = function(self2, id, token)
            -- 仅玩家选词条时介入，其余实体（如小礼物）直接走原逻辑
            if not self2.inst or not self2.inst:HasTag("player") then
                return origAddSx and origAddSx(self2, id, token)
            end
            self2.zf = self2.zf or 0
            local extra = get_extra(self2.inst)
            local orig_base = self2._moon_lhx_base
            if orig_base == nil then orig_base = self2.zf end
            reapply(self2, 0) -- 干净状态（zf=0，属性按原值）
            local r = origAddSx and origAddSx(self2, id, token)
            if r == false then
                reapply(self2, orig_base + extra) -- 选择失败，恢复原状态
                return r
            end
            -- mod 跑完后：若更新了 zf（获得增幅碎片，sx>=20 永不为 0）则新基准
            -- 为 self2.zf；否则（普通词条，zf 仍为 reapply(0) 的 0）基准不变
            local new_base = self2.zf
            if new_base == nil or new_base == 0 then
                new_base = orig_base
            end
            self2._moon_lhx_base = new_base
            reapply(self2, new_base + extra)
            return r
        end
    end
end)

-- =========================================================
-- 应用/还原附魔增量（on_equip / un_equip 共用）
-- =========================================================
local function apply_extra(owner)
    local dt = owner and owner.components and owner.components.elaina_dt
    if not dt then return end
    local extra = _G.Moon_GetTotalEffectValue(owner, "lhx") or 0
    local base = dt._moon_lhx_base
    if base == nil then base = dt.zf or 0 end
    local target = base + extra
    if dt.zf ~= target then
        reapply(dt, target)
    end
end

-- =========================================================
-- 附魔注册（需要 HH 框架）
-- =========================================================
AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    GLOBAL.AddSpecialEquipEffect("Legend_LHX", {
        name = "梨花雪",
        client_text = "梨花\n雪",
        desc = "提高魔女的锻体属性增幅+%s%%\n仅可附魔胸针，唯一",
        check_desc = "需开启魔女之旅Mod\n仅限胸针附魔",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        ui_from_desc = "击败精英/Boss概率掉落",
        value_range = { min = 20, max = 100 },
        check_equip_can_add = function(inst)
            if inst and inst.prefab and string.find(inst.prefab, "brooch") then
                return true, "满足条件"
            end
            return false, "只能附魔在胸针上"
        end,
        on_equip_fn = function(inst, owner, value)
            -- 装备实例标记：重进世界若框架重放 on_equip 也不重复累加效果值
            if not inst._lhx_applied then
                inst._lhx_applied = true
                _G.Moon_AddEffect(owner, "lhx", "Legend_LHX", value or 20)
                apply_extra(owner)
            end
        end,
        un_equip_fn = function(inst, owner, value)
            if inst._lhx_applied then
                inst._lhx_applied = nil
                _G.Moon_ReduceEffect(owner, "lhx", "Legend_LHX", value or 20)
                apply_extra(owner)
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_LHX", 0.01)
end)
