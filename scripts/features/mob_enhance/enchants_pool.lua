-- 小月亮 怪物强化 — 附魔池
-- 所有从现有附魔适配的「怪物版」效果表
-- 由 init.lua 通过 modimport 加载后存入全局 _G.MOON_MOB_ENCHANTS

local _G = GLOBAL
local SpawnPrefab = _G.SpawnPrefab
local TheSim = _G.TheSim
local math = _G.math
local GetTime = _G.GetTime

-- =====================================================================
-- 工具函数
-- =====================================================================
local function FindEnemies(inst, radius, filter)
    filter = filter or { "_combat" }
    local x, y, z = inst.Transform:GetWorldPosition()
    return TheSim:FindEntities(x, y, z, radius, filter)
end

local function IsValidTarget(inst, target)
    return target and target:IsValid()
        and target ~= inst
        and target.components.health
        and not target.components.health:IsDead()
end

local function DealDamage(source, target, damage, cause)
    if IsValidTarget(source, target) and target.components.health then
        target.components.health:DoDelta(-damage, false, cause or "mob_enchant")
    end
end

-- 是否免疫反伤/受击反击（HH 玄武/神龟守御 immuneBramble 等）
local function IsImmuneReflect(target)
    if not target then return false end
    local hh = target.components and target.components.hh_player
    return (hh and hh.HasSpecialEffect and hh:HasSpecialEffect("immuneBramble")) or false
end

-- SpawnFX(prefab, pos_or_x, y_or_scale, z)
-- pos_or_x: Vector3 或 x 坐标；y_or_scale: y 坐标或缩放；z: z 坐标
-- 支持: SpawnFX("fx", posVector3, scale) 或 SpawnFX("fx", x, y, z, scale)
local function SpawnFX(prefab, pos_or_x, y_or_scale, z, scale)
    local fx = SpawnPrefab(prefab)
    if fx then
        -- 判断第一个位置参数是否是 Vector3 (userdata)
        if type(pos_or_x) == "userdata" then
            -- Vector3 模式: SpawnFX(prefab, pos, scale)
            fx.Transform:SetPosition(pos_or_x)
            if y_or_scale then
                fx.Transform:SetScale(y_or_scale, y_or_scale, y_or_scale)
            end
        else
            -- 坐标模式: SpawnFX(prefab, x, y, z, scale)
            if z ~= nil then
                fx.Transform:SetPosition(pos_or_x, y_or_scale, z)
            else
                fx.Transform:SetPosition(pos_or_x, y_or_scale, 0)
            end
            if scale then
                fx.Transform:SetScale(scale, scale, scale)
            end
        end
    end
    return fx
end

-- =====================================================================
-- 附魔池
-- =====================================================================
_G.MOON_MOB_ENCHANTS = {

    -----------------------------------------------------------------
    -- 毛旭 — 血量提升
    -----------------------------------------------------------------
    MOB_MX_HEALTH = {
        name = "毛旭", weight = 3, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            local health = inst.components.health
            if not health then return end
            local old_pct = health:GetPercent()
            if tier == "boss" then
                local bonus = health.maxhealth * 0.3 * mult
                health.maxhealth = math.min(health.maxhealth + bonus, 100000)
            else
                local bonus = 500 * mult
                health.maxhealth = health.maxhealth + bonus
            end
            health:SetPercent(old_pct)
        end,
    },

    -----------------------------------------------------------------
    -- 月半 — HP 附加伤害 + 受击 AoE
    -----------------------------------------------------------------
    MOB_YUEBAN = {
        name = "月半", weight = 2, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            state._cooldown = 0
        end,
        on_attack = function(inst, target, tier, mult, state)
            if not IsValidTarget(inst, target) then return end
            local health = inst.components.health
            if not health then return end
            local bonus = health.currenthealth * 0.05 * mult
            if bonus > 0 then
                DealDamage(inst, target, bonus, "mob_yueban")
            end
        end,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            if not attacker or not attacker:IsValid() then return end
            local now = GetTime()
            if now - state._cooldown < 3 then return end
            if math.random() > 0.2 then return end
            state._cooldown = now
            local base_dmg = 100 * mult
            if tier == "boss" and inst.components.health then
                base_dmg = inst.components.health.maxhealth * 0.05 * mult
            end
            for _, target in ipairs(FindEnemies(inst, 4)) do
                if not IsImmuneReflect(target) then
                    DealDamage(inst, target, base_dmg, "mob_yueban")
                end
            end
            SpawnFX("collapse_small", inst.Transform:GetWorldPosition())
        end,
    },

    -----------------------------------------------------------------
    -- 山竹的捏 — 护盾吸收 + 破盾 AoE
    -----------------------------------------------------------------
    MOB_SHANZHU = {
        name = "山竹的捏", weight = 2, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            local health = inst.components.health
            if not health then return end
            state._shield = tier == "boss" and health.maxhealth * 0.1 * mult or 200 * mult
            state._shield_max = state._shield
            state._shield_broken = false
            state._shield_task = inst:DoPeriodicTask(10, function()
                if not inst:IsValid() then return end
                if state._shield_broken then state._shield = 0; return end
                state._shield = math.min((state._shield or 0) + state._shield_max * 0.2, state._shield_max)
            end)
        end,
        on_remove = function(inst, state)
            if state._shield_task then state._shield_task:Cancel(); state._shield_task = nil end
        end,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            if not inst:IsValid() then return end
            if state._shield_broken then return end
            if not state._shield or state._shield <= 0 then
                state._shield_broken = true
                local heal_pct = tier == "boss" and 0.1 or 0.15
                local aoe_dmg = tier == "boss" and (inst.components.health and inst.components.health.maxhealth * 0.05 * mult or 150 * mult) or 150 * mult
                for _, target in ipairs(FindEnemies(inst, 5)) do
                    DealDamage(inst, target, aoe_dmg, "mob_shanzhu")
                end
                if inst.components.health then
                    inst.components.health:DoDelta(inst.components.health.maxhealth * heal_pct * mult, false, "mob_shanzhu_shield")
                end
                SpawnFX("groundpoundring_fx", inst.Transform:GetWorldPosition(), 1.5)
            else
                state._shield = state._shield - math.min(state._shield, damage * 0.6)
                if state._shield <= 0 then state._shield = 0; state._shield_broken = true end
            end
        end,
    },

    -----------------------------------------------------------------
    -- 哎哟 — 受击回血 + 反伤 + 击杀冲击波
    -----------------------------------------------------------------
    MOB_AIYO = {
        name = "哎哟", weight = 2, boss_only = false,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            if not inst.components.health then return end
            -- 60% 概率回血
            if math.random() < 0.6 then
                local heal_ratio = tier == "boss" and 0.3 or 0.6
                inst.components.health:DoDelta(damage * heal_ratio, false, "mob_aiyo_heal")
            end
            -- 反伤（攻击者免疫反伤如 HH 玄武/神龟守御 immuneBramble 则不反弹）
            if attacker and attacker:IsValid() and attacker.components.health then
                local hh_attacker = attacker.components.hh_player
                if not (hh_attacker and hh_attacker.HasSpecialEffect
                    and hh_attacker:HasSpecialEffect("immuneBramble")) then
                    local reflect_ratio = tier == "boss" and 0.5 or 1.0
                    attacker.components.health:DoDelta(-damage * reflect_ratio, false, "mob_aiyo_reflect")
                end
            end
        end,
        on_kill = function(inst, target, tier, mult, state)
            local dmg = tier == "boss" and (inst.components.combat and inst.components.combat.defaultdamage * 3 or 300) or 200
            dmg = dmg * mult
            for _, target in ipairs(FindEnemies(inst, 5)) do
                DealDamage(inst, target, dmg, "mob_aiyo_blast")
            end
            SpawnFX("groundpoundring_fx", inst.Transform:GetWorldPosition(), 2)
        end,
    },

    -----------------------------------------------------------------
    -- 胖虎 — 攻击概率 AoE 音波
    -----------------------------------------------------------------
    MOB_PANGHU = {
        name = "胖虎", weight = 2, boss_only = false,
        on_attack = function(inst, target, tier, mult, state)
            if math.random() > 0.15 then return end
            local dmg = tier == "boss" and (inst.components.health and inst.components.health.maxhealth * 0.05 * mult or 500) or 200 * mult
            for _, t in ipairs(FindEnemies(inst, 6)) do
                DealDamage(inst, t, dmg, "mob_panghu")
            end
            SpawnFX("statue_transition_1", inst.Transform:GetWorldPosition(), 1.5)
        end,
    },

    -----------------------------------------------------------------
    -- 急冻冻 — 冰冻 + 冰爆
    -----------------------------------------------------------------
    MOB_WJBD = {
        name = "急冻冻", weight = 2, boss_only = false,
        on_attack = function(inst, target, tier, mult, state)
            if not IsValidTarget(inst, target) then return end
            local chance = tier == "boss" and 0.15 or 0.2
            if math.random() > chance then return end
            -- 冰冻
            if target.components.freezable then
                target.components.freezable:AddColdness(1)
                target.components.freezable:SpawnShatterFX()
            end
            -- 冰爆 AoE
            local dmg = tier == "boss" and (inst.components.health and inst.components.health.maxhealth * 0.05 * mult or 300) or 300 * mult
            for _, t in ipairs(FindEnemies(inst, 4)) do
                DealDamage(inst, t, dmg, "mob_wjbd")
            end
            SpawnFX("icespall_spawn_fx", inst.Transform:GetWorldPosition())
        end,
    },

    -----------------------------------------------------------------
    -- 草莓奶昔 — 周期性回血 + 减速攻击者
    -----------------------------------------------------------------
    MOB_STRAWBERRY = {
        name = "草莓奶昔", weight = 3, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            state._heal_amount = tier == "boss" and 0.03 or 0.05
        end,
        on_update = function(inst, tier, mult, state)
            if inst.components.health then
                local heal = inst.components.health.maxhealth * state._heal_amount * mult
                inst.components.health:DoDelta(heal, false, "mob_strawberry")
            end
        end,
        update_period = 3,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            if attacker and attacker:IsValid() and attacker.components.locomotor then
                attacker.components.locomotor:SetExternalSpeedMultiplier(attacker, "mob_strawberry_slow", 0.6)
                attacker:DoTaskInTime(2, function()
                    if attacker:IsValid() and attacker.components.locomotor then
                        attacker.components.locomotor:RemoveExternalSpeedMultiplier(attacker, "mob_strawberry_slow")
                    end
                end)
            end
        end,
    },

    -----------------------------------------------------------------
    -- 萝的守护 — 免伤 + 叠层减伤
    -----------------------------------------------------------------
    MOB_LUO = {
        name = "萝的守护", weight = 2, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            state._stacks = 0
            if inst.components.combat then
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.5, "mob_luo_base")
            end
        end,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            state._stacks = math.min((state._stacks or 0) + 1, 5)
            local reduction = state._stacks * 0.05 -- up to 25%
            if inst.components.combat then
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.5 - reduction, "mob_luo_base")
            end
        end,
    },

    -----------------------------------------------------------------
    -- 等秋零 — 攻击力 + 移速 + 受击免疫
    -----------------------------------------------------------------
    MOB_DENGQIUHING = {
        name = "等秋零", weight = 3, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            if inst.components.combat then
                local base = inst.components.combat.defaultdamage or 10
                local bonus_ratio = tier == "boss" and 0.5 or 0.25
                inst.components.combat.defaultdamage = base * (1 + bonus_ratio * mult)
            end
            if inst.components.locomotor then
                inst.components.locomotor:SetExternalSpeedMultiplier(inst, "mob_dengqiuling_speed", 1.15)
            end
        end,
        on_remove = function(inst, state)
            if inst.components.locomotor then
                inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "mob_dengqiuling_speed")
            end
        end,
    },

    -----------------------------------------------------------------
    -- 妖精庇护 — % 已损失生命真伤
    -----------------------------------------------------------------
    MOB_FAY = {
        name = "妖精庇护", weight = 2, boss_only = false,
        on_attack = function(inst, target, tier, mult, state)
            if not IsValidTarget(inst, target) then return end
            local target_health = target.components.health
            if not target_health then return end
            local missing = target_health.maxhealth - target_health.currenthealth
            local bonus = missing * 0.08 * mult
            if bonus > 0 then
                DealDamage(inst, target, bonus, "mob_fay")
            end
        end,
    },

    -----------------------------------------------------------------
    -- 篮球 — 连击同一目标增伤
    -----------------------------------------------------------------
    MOB_LANQIU = {
        name = "篮球", weight = 1, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            state._target = nil
            state._combo = 0
            state._combo_reset_task = nil
        end,
        on_attack = function(inst, target, tier, mult, state)
            if not target or not target:IsValid() then return end
            local guid = target.GUID
            if state._target == guid then
                state._combo = math.min((state._combo or 0) + 1, 10)
            else
                state._target = guid
                state._combo = 1
            end
            -- 重置计时器
            if state._combo_reset_task then state._combo_reset_task:Cancel() end
            state._combo_reset_task = inst:DoTaskInTime(5, function()
                if not inst:IsValid() then return end
                state._target = nil; state._combo = 0
            end)
            -- 每层 +10% 伤害
            if state._combo >= 10 and inst.components.combat then
                local extra = inst.components.combat.defaultdamage * 0.5 * mult
                DealDamage(inst, target, extra, "mob_lanqiu")
                SpawnFX("statue_transition_1", target.Transform:GetWorldPosition())
            end
        end,
    },

    -----------------------------------------------------------------
    -- 空白 — 清除目标增益
    -----------------------------------------------------------------
    MOB_KONGBAI = {
        name = "空白", weight = 1, boss_only = false,
        on_attack = function(inst, target, tier, mult, state)
            if not IsValidTarget(inst, target) then return end
            if math.random() > 0.6 then return end
            -- 清除常见 buff 标签
            local cleared = 0
            local buffs = {"buff", "buff_player", "spider_heal", "electricity", "wet", "cold"}
            for _, tag in ipairs(buffs) do
                if target:HasTag(tag) then
                    target:RemoveTag(tag)
                    cleared = cleared + 1
                end
            end
            if cleared > 0 then
                local bonus = cleared * 0.6 * inst.components.combat.defaultdamage * mult
                DealDamage(inst, target, bonus, "mob_kongbai")
                SpawnFX("statue_transition_1", target.Transform:GetWorldPosition())
            end
        end,
    },

    -----------------------------------------------------------------
    -- 是萌新喵 — 免死 + 高血量增伤
    -----------------------------------------------------------------
    MOB_MXM = {
        name = "是萌新喵", weight = 1, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            if tier == "boss" then
                state._death_defiance_left = 3
            else
                state._death_defiance_left = 1
            end
        end,
        on_attack = function(inst, target, tier, mult, state)
            if not IsValidTarget(inst, target) then return end
            local target_health = target.components.health
            if not target_health then return end
            if target_health:GetPercent() > 0.7 then
                local bonus = inst.components.combat and inst.components.combat.defaultdamage * 0.6 * mult or 30
                DealDamage(inst, target, bonus, "mob_mxm")
            end
        end,
    },

    -----------------------------------------------------------------
    -- 酸酸草 — 酸蚀叠层减防
    -----------------------------------------------------------------
    MOB_SUANSUANCAO = {
        name = "酸酸草", weight = 2, boss_only = false,
        on_attack = function(inst, target, tier, mult, state)
            if not IsValidTarget(inst, target) then return end
            if not target.components.combat then return end
            if not target._mob_suansuan_stacks then target._mob_suansuan_stacks = 0 end
            target._mob_suansuan_stacks = math.min(target._mob_suansuan_stacks + 1, 8)
            local reduction = target._mob_suansuan_stacks * 0.05
            target.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1 - reduction, "mob_suansuan")
            -- 真伤
            local bonus = 10 * mult
            DealDamage(inst, target, bonus, "mob_suansuan")
        end,
    },

    -----------------------------------------------------------------
    -- 七步之外 — 攻击距离增加
    -----------------------------------------------------------------
    MOB_CHANGPI = {
        name = "七步之外", weight = 3, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            if inst.components.combat then
                local range_bonus = tier == "boss" and 4 or 2
                inst.components.combat.hitrange = (inst.components.combat.hitrange or 3) + range_bonus
            end
        end,
    },

    -----------------------------------------------------------------
    -- 良弓藏 — 自动远程攻击（Boss 专用）
    -----------------------------------------------------------------
    MOB_LIANGGONGCANG = {
        name = "良弓藏", weight = 1, boss_only = true,
        on_update = function(inst, tier, mult, state)
            -- 找最近的敌人射箭
            local nearest = nil
            local min_dist = 9999
            for _, v in ipairs(FindEnemies(inst, 20)) do
                if v:HasTag("player") or v:HasTag("companion") then
                    local dist = inst:GetDistanceSqToInst(v)
                    if dist < min_dist then
                        min_dist = dist; nearest = v
                    end
                end
            end
            if not IsImmuneReflect(target) and nearest and nearest:IsValid()  and nearest.components.health then
                local dmg = inst.components.combat and inst.components.combat.defaultdamage * 3 * mult or 100
                DealDamage(inst, nearest, dmg, "mob_liang")
                SpawnFX("moonglass_glow", nearest.Transform:GetWorldPosition())
            end
        end,
        update_period = 30,
    },

    -----------------------------------------------------------------
    -- 养猫客 — 召唤小怪（Boss 专用）
    -----------------------------------------------------------------
    MOB_YANGMAOKE = {
        name = "养猫客", weight = 1, boss_only = true,
        on_update = function(inst, tier, mult, state)
            -- 限制召唤数量
            local spawned = 0
            for _, v in ipairs(FindEnemies(inst, 30)) do
                if v.prefab == "catcoon" and v.components.health then
                    spawned = spawned + 1
                end
            end
            local max_spawn = tier == "boss" and 4 or 2
            if spawned >= max_spawn then return end
            local x, y, z = inst.Transform:GetWorldPosition()
            local cat = SpawnPrefab("catcoon")
            if cat then
                cat.Transform:SetPosition(x + math.random(-3, 3), y, z + math.random(-3, 3))
                if cat.components.combat then
                    cat.components.combat:SuggestTarget(inst.components.combat and inst.components.combat.target)
                end
            end
        end,
        update_period = 60,
    },

    -----------------------------------------------------------------
    -- 蝴蝶的小阿飞 — 减伤 + 击杀回血
    -----------------------------------------------------------------
    MOB_HUFEI = {
        name = "蝴蝶的小阿飞", weight = 2, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            if inst.components.combat then
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.8, "mob_hufei")
            end
        end,
        on_kill = function(inst, target, tier, mult, state)
            if inst.components.health then
                local heal = inst.components.health.maxhealth * 0.1 * mult
                inst.components.health:DoDelta(heal, false, "mob_hufei_heal")
            end
        end,
    },

    -----------------------------------------------------------------
    -- 咕咕咕 — 闪避反击
    -----------------------------------------------------------------
    MOB_GUGUGU = {
        name = "咕咕咕", weight = 1, boss_only = false,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            if not attacker or not attacker:IsValid() then return end
            -- 42% 概率触发：反击（攻击者免疫反伤则不反击）
            if math.random() < 0.42 and not IsImmuneReflect(attacker) then
                local counter = (inst.components.combat and inst.components.combat.defaultdamage * 2 or 100) * mult
                DealDamage(inst, attacker, counter, "mob_gugugu")
                SpawnFX("statue_transition_1", attacker.Transform:GetWorldPosition())
            end
        end,
    },

    -----------------------------------------------------------------
    -- 云中雀 — 周期性爆发
    -----------------------------------------------------------------
    MOB_YZQ = {
        name = "云中雀", weight = 1, boss_only = false,
        on_update = function(inst, tier, mult, state)
            -- 每 8 秒爆发一次
            local dmg = (inst.components.combat and inst.components.combat.defaultdamage * 3.5 or 100) * mult
            for _, target in ipairs(FindEnemies(inst, 6)) do
                DealDamage(inst, target, dmg, "mob_yzq")
            end
            SpawnFX("groundpoundring_fx", inst.Transform:GetWorldPosition(), 1.5)
        end,
        update_period = 8,
    },

    -----------------------------------------------------------------
    -- 紫蝶分身 — 攻击召唤分身
    -----------------------------------------------------------------
    MOB_ZIDIE = {
        name = "紫蝶分身", weight = 1, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            state._clone_count = 0
        end,
        on_attack = function(inst, target, tier, mult, state)
            if math.random() > 0.05 then return end
            if state._clone_count >= 2 then return end  -- 上限 2 个分身
            local x, y, z = inst.Transform:GetWorldPosition()
            local clone = SpawnPrefab(inst.prefab)
            if clone then
                clone.Transform:SetPosition(x + math.random(-2, 2), y, z + math.random(-2, 2))
                state._clone_count = state._clone_count + 1
                -- 弱化版：50% 属性
                if clone.components.health and inst.components.health then
                    clone.components.health:SetMaxHealth(inst.components.health.maxhealth * 0.5)
                end
                if clone.components.combat and inst.components.combat then
                    clone.components.combat.defaultdamage = (inst.components.combat.defaultdamage or 10) * 0.5
                end
                -- 分身自己会死亡
                clone:ListenForEvent("death", function()
                    state._clone_count = math.max((state._clone_count or 1) - 1, 0)
                end)
                SpawnFX("statue_transition_2", clone.Transform:GetWorldPosition())
            end
        end,
    },

    -----------------------------------------------------------------
    -- 君可知 — 限伤 + 反击（与防御层互补）
    -----------------------------------------------------------------
    MOB_JUNJUN = {
        name = "君可知", weight = 1, boss_only = false,
        on_apply = function(inst, tier, mult, state)
            state._last_roar = 0
        end,
        on_attacked = function(inst, attacker, damage, tier, mult, state)
            if not attacker or not attacker:IsValid() then return end
            -- 受击时反击
            local now = GetTime()
            if now - state._last_roar < 5 then return end
            state._last_roar = now
            local dmg = (inst.components.combat and inst.components.combat.defaultdamage * 2 or 100) * mult
            for _, target in ipairs(FindEnemies(inst, 6)) do
                if not IsImmuneReflect(target) then
                    DealDamage(inst, target, dmg, "mob_junjun")
                end
            end
            SpawnFX("groundpoundring_fx", inst.Transform:GetWorldPosition(), 2)
        end,
    },
}
