-- 小月亮 附魔：梨花雪
-- 提高魔女的锻体属性增幅 20%~100%（附魔时随机确定），仅可附魔胸针，唯一
-- 依赖魔女之旅 Mod (workshop-2578692071)
-- 实现：包装 elaina_dt 组件的 OnSave/OnLoad/AddSx —— 附魔生效期间临时提升
--       elaina_dt.zf（锻体增幅），使全 mod 所有读 zf 的乘算点（攻击/暴击/穿甲/
--       吸血/财富/生命等）统一吃到增幅，同时保证存档写入的是基准增幅、不污染存档

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- 依赖 Mod 未开启时不注册（魔女之旅）
if not _G.Moon_IsModEnabled("workshop-2578692071") then return end

-- =========================================================
-- elaina_dt 组件增强（一次性包装原型方法）
-- =========================================================
AddComponentPostInit("elaina_dt", function(inst, self)
    if not self then return end

    -- 每个实例初始化基准增幅
    if self._moon_lhx_base == nil then
        self._moon_lhx_base = self.zf or 0
    end

    local proto = getmetatable(self).__index
    if proto and not proto._moon_lhx_patched then
        proto._moon_lhx_patched = true

        local origOnSave = proto.OnSave
        local origOnLoad = proto.OnLoad
        local origAddSx = proto.AddSx

        -- 读取玩家身上的梨花雪附魔增量
        local function get_extra(player)
            if not player or not _G.Moon_GetTotalEffectValue then return 0 end
            return _G.Moon_GetTotalEffectValue(player, "lhx") or 0
        end

        -- OnSave：存档写基准增幅，防止附魔增量入档
        proto.OnSave = function(self2)
            local data = origOnSave and origOnSave(self2)
            if data and self2._moon_lhx_base ~= nil then
                data.zf = self2._moon_lhx_base
            end
            return data
        end

        -- OnLoad：读档后同步基准；附魔已在身则补回增量
        -- （mod 原 OnLoad 延迟 0.5s 调 AddSxAll，届时会读到补回后的 zf）
        proto.OnLoad = function(self2, data)
            if origOnLoad then origOnLoad(self2, data) end
            self2._moon_lhx_base = self2.zf or 0
            local extra = get_extra(self2.inst)
            if extra > 0 then
                self2.zf = self2.zf + extra
            end
        end

        -- AddSx：mod 更新 zf（获得增幅碎片）后同步基准，并补回附魔增量
        proto.AddSx = function(self2, id, token)
            local old_zf = self2.zf
            local r = origAddSx and origAddSx(self2, id, token)
            if old_zf ~= self2.zf then
                local extra = get_extra(self2.inst)
                self2._moon_lhx_base = self2.zf
                if extra > 0 then
                    self2.zf = self2.zf + extra
                    self2:ClearSx()
                    self2:AddSxAll()
                end
            end
            return r
        end
    end
end)

-- =========================================================
-- 应用/还原附魔增量（on_equip / un_equip 共用）
-- 通过全量 ClearSx + AddSxAll 让所有已获词条按新增幅重算
-- =========================================================
local function apply_extra(owner)
    local dt = owner and owner.components and owner.components.elaina_dt
    if not dt then return end

    local extra = _G.Moon_GetTotalEffectValue(owner, "lhx") or 0
    local base = dt._moon_lhx_base
    if base == nil then base = dt.zf or 0 end
    local target = base + extra
    if dt.zf ~= target then
        dt.zf = target
        dt:ClearSx()
        dt:AddSxAll()
        -- 同步客户端面板显示的增幅值
        if dt.inst and dt.inst.replica and dt.inst.replica.elaina_dt
            and dt.inst.replica.elaina_dt.zf then
            dt.inst.replica.elaina_dt.zf:set(dt.zf)
        end
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
        check_desc = "梨花雪附魔生效中，锻体增幅提升！",
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
            _G.Moon_AddEffect(owner, "lhx", "Legend_LHX", value or 20)
            apply_extra(owner)
        end,
        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "lhx", "Legend_LHX", value or 20)
            apply_extra(owner)
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_LHX", 0.01)
end)
