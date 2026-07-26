-- 小月亮 怪物强化组件
-- 挂在每个被强化的怪物身上，管理防御层、附魔效果和清理
-- PoC: 仅作用于 树精守卫 (leif/leif_sparse)
-- 注意: 组件通过 require 加载，GLOBAL 不可用，全局函数直接使用

local MoonMobEnhance = Class(function(self, inst)
    self.inst = inst
    self.tier = "normal"            -- "normal" | "boss"
    self.enchants = {}              -- { [enchant_id] = { state = {...} } }
    self.difficulty_mult = 1.0      -- 难度倍率
    self.extra_enchant_count = 0    -- 额外附魔数量

    -- 防御层状态
    self._defense_hooked = false
    self._origin_DoDelta = nil
end)

---------------------------------------------------------------------
-- 初始化：由 init.lua 在 AddPrefabPostInit 中调用
---------------------------------------------------------------------
function MoonMobEnhance:OnStart(tier, diff_mult, enchant_ids, enchants_config, hh_enabled)
    self.tier = tier or "normal"
    self.difficulty_mult = diff_mult or 1.0
    self.hh_enabled = hh_enabled or false

    -- 1. 应用防御层（所有强化怪物都有）
    self:_ApplyDefense()

    -- 2. 应用抽到的附魔
    if enchant_ids and enchants_config then
        for _, eid in ipairs(enchant_ids) do
            local cfg = enchants_config[eid]
            if cfg then
                self:_ApplyEnchant(eid, cfg)
            end
        end
    end

    -- 3. 视觉效果
    self:_ApplyVisuals()

    -- 4. 死亡清理
    self.inst:ListenForEvent("death", function()
        self:OnDeath()
    end)
    self.inst:ListenForEvent("onremove", function()
        self:OnDeath()
    end)
end

---------------------------------------------------------------------
-- 防御层（移植自 3700206644 的生物加强）
---------------------------------------------------------------------
function MoonMobEnhance:_ApplyDefense()
    if self._defense_hooked then return end
    local health = self.inst.components.health
    if not health then return end

    self._origin_DoDelta = health.DoDelta
    local enhance = self

    health.DoDelta = function(self, delta, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        if not self.inst or not self.inst:IsValid() then
            return enhance._origin_DoDelta(self, delta, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        end

        local comp = self.inst.components.moon_mob_enhance
        if not comp then
            return enhance._origin_DoDelta(self, delta, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        end

        -- 只拦截伤害（负值）
        if delta >= 0 then
            return enhance._origin_DoDelta(self, delta, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        end

        local damage = -delta
        local mult = comp.difficulty_mult

        ---- 1. 动态减伤：血量越低减伤越高 ----
        local hp_pct = self:GetPercent()
        if comp.tier == "boss" then
            -- Boss: 30%~90% 减伤
            local reduction = 0.3 + (1 - hp_pct) * 0.6
            damage = damage * (1 - reduction)
        else
            -- 普通: 10%~70% 减伤
            local reduction = 0.1 + (1 - hp_pct) * 0.6
            damage = damage * (1 - reduction)
        end

        ---- 2. 单次伤害上限 ----
        local max_hp = self.maxhealth or 1
        local cap_pct = comp.tier == "boss" and 0.05 or 0.15
        local cap = max_hp * cap_pct * mult
        if damage > cap then
            damage = cap
            -- 限伤特效（延迟一帧避免重入）
            if afflicter and afflicter:IsValid() then
                local px, py, pz = comp.inst.Transform:GetWorldPosition()
                afflicter:DoTaskInTime(0, function()
                    if not comp.inst:IsValid() then return end
                    local fx = SpawnPrefab("statue_transition_2")
                    if fx then
                        fx.Transform:SetPosition(px, py, pz)
                    end
                end)
            end
        end

        ---- 3. 频率限制 ----
        local now = GetTime()
        if afflicter and afflicter.GUID then
            local src_key = "mob_defense_freq_" .. afflicter.GUID
            local last_time = comp[src_key] or 0
            local min_interval = comp.tier == "boss" and 0.5 or 0.3
            if now - last_time < min_interval and damage > max_hp * 0.01 then
                return enhance._origin_DoDelta(self, 0, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
            end
            comp[src_key] = now
        end

        return enhance._origin_DoDelta(self, -damage, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end

    self._defense_hooked = true
end

---------------------------------------------------------------------
-- 应用单个附魔
---------------------------------------------------------------------
function MoonMobEnhance:_ApplyEnchant(eid, cfg)
    if self.enchants[eid] then return end  -- 防重复

    self.enchants[eid] = { state = {}, cfg = cfg }
    local state = self.enchants[eid].state

    -- 调用附魔的 on_apply（附魔的初始化逻辑）
    if cfg.on_apply then
        cfg.on_apply(self.inst, self.tier, self.difficulty_mult, state)
    end

    -- 注册攻击事件
    if cfg.on_attack then
        local fn = function(attacker, data)
            if not self.inst:IsValid() then return end
            if not self.enchants[eid] then return end
            cfg.on_attack(self.inst, data and data.target, self.tier, self.difficulty_mult, state)
        end
        state._attack_handler = fn
        self.inst:ListenForEvent("onhitother", fn)
    end

    -- 注册受击事件
    if cfg.on_attacked then
        local fn = function(victim, data)
            if not self.inst:IsValid() then return end
            if not self.enchants[eid] then return end
            local attacker = data and data.attacker
            local damage = data and data.damage or 0
            cfg.on_attacked(self.inst, attacker, damage, self.tier, self.difficulty_mult, state)
        end
        state._attacked_handler = fn
        self.inst:ListenForEvent("attacked", fn)
    end

    -- 注册击杀事件
    if cfg.on_kill then
        local fn = function(attacker, data)
            if not self.inst:IsValid() then return end
            if not self.enchants[eid] then return end
            cfg.on_kill(self.inst, data and data.target, self.tier, self.difficulty_mult, state)
        end
        state._kill_handler = fn
        self.inst:ListenForEvent("onkillother", fn)
    end

    -- 周期更新
    if cfg.on_update then
        local period = cfg.update_period or 3
        state._update_task = self.inst:DoPeriodicTask(period, function()
            if not self.inst:IsValid() then
                if state._update_task then
                    state._update_task:Cancel()
                end
                return
            end
            if not self.enchants[eid] then
                if state._update_task then
                    state._update_task:Cancel()
                end
                return
            end
            cfg.on_update(self.inst, self.tier, self.difficulty_mult, state)
        end)
    end
end

---------------------------------------------------------------------
-- 视觉效果
---------------------------------------------------------------------
function MoonMobEnhance:_ApplyVisuals()
    local inst = self.inst

    -- 构建附魔名字列表
    local enchant_names = {}
    for eid, data in pairs(self.enchants) do
        if data.cfg and data.cfg.name then
            table.insert(enchant_names, data.cfg.name)
        end
    end
    local suffix = #enchant_names > 0 and " [" .. table.concat(enchant_names, "+") .. "]" or ""

    if self.hh_enabled then
        -- HH 面板激活时：通过 GetHHSpDesc01 扩展点注入
        inst.GetHHSpDesc01 = function(ent, player)
            local comp = ent.components.moon_mob_enhance
            if not comp then return nil end
            local names = {}
            for eid, data in pairs(comp.enchants) do
                if data.cfg and data.cfg.name then
                    table.insert(names, data.cfg.name)
                end
            end
            if #names == 0 then return nil end
            local title = comp.tier == "boss" and "[月之首领]" or "[月之强化]"
            local color = comp.tier == "boss" and {255, 200, 100, 255} or {180, 120, 255, 255}
            return {
                desc = table.concat(names, " + "),
                title = title,
                color = color,
            }
        end
    else
        -- HH 未启用：覆盖检查文本
        if inst.components.inspectable then
            local old_desc = inst.components.inspectable.getdescriptionfn
            local tier_label = self.tier == "boss" and "[月之首领]" or "[月之强化]"
            inst.components.inspectable.getdescriptionfn = function(inst, viewer)
                local base = (old_desc and old_desc(inst, viewer)) or ""
                return "[月]" .. base .. "\n" .. tier_label .. suffix
            end
        end
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("statue_transition_2")
    if fx then
        fx.Transform:SetPosition(x, y, z)
        fx.Transform:SetScale(1.5, 1.5, 1.5)
    end
    local fx2 = SpawnPrefab("moonglass_glow")
    if fx2 then
        fx2.Transform:SetPosition(x, y, z)
        fx2.Transform:SetScale(2, 2, 2)
    end
end

---------------------------------------------------------------------
-- 清理
---------------------------------------------------------------------
function MoonMobEnhance:OnDeath()
    -- 清理各附魔的 handler 和 task
    for eid, data in pairs(self.enchants) do
        local st = data.state
        if st._attack_handler then
            self.inst:RemoveEventCallback("onhitother", st._attack_handler)
        end
        if st._attacked_handler then
            self.inst:RemoveEventCallback("attacked", st._attacked_handler)
        end
        if st._kill_handler then
            self.inst:RemoveEventCallback("onkillother", st._kill_handler)
        end
        if st._update_task then
            st._update_task:Cancel()
        end

        -- 调用附魔的 on_remove 清理
        if data.cfg and data.cfg.on_remove then
            data.cfg.on_remove(self.inst, st)
        end
    end
    self.enchants = {}

    -- 还原 DoDelta
    if self._defense_hooked and self._origin_DoDelta then
        local health = self.inst.components.health
        if health then
            health.DoDelta = self._origin_DoDelta
        end
    end
    self._defense_hooked = false
    self._origin_DoDelta = nil
end

---------------------------------------------------------------------
-- 注册组件
---------------------------------------------------------------------
return MoonMobEnhance
