-- 小月亮 附魔：紫蝶
-- 身化蝶影，以假乱真！
-- 攻击20%几率召唤蝶影分身（继承50%属性，持续8秒，最多2个）
-- 分身自动攻击附近敌人。分身存在时本体伤害+30%
-- 移速永久+20%，分身移速+40%

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_MORE_ENCHANTS then return end

-- ======== 分身辅助函数 ========

-- 清理已消亡的分身
local function cleanup_clones(owner)
    if not owner._zidie_clones then
        owner._zidie_clones = {}
        return
    end
    local alive = {}
    for _, data in ipairs(owner._zidie_clones) do
        if data.entity and data.entity:IsValid() then
            table.insert(alive, data)
        end
    end
    owner._zidie_clones = alive
end

-- 检查是否有存活分身
local function has_alive_clones(owner)
    cleanup_clones(owner)
    return #(owner._zidie_clones or {}) > 0
end

-- 召唤一个蝶影分身（本人外观）
local function spawn_clone(owner, target)
    local x, y, z = owner.Transform:GetWorldPosition()

    -- 直接用玩家本人的预制体，保留组件防止残留回调崩溃
    local clone = _G.SpawnPrefab(owner.prefab)
    if not clone then return nil end

    -- 定位：玩家和目标的中间偏目标方向，加随机偏移
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local sx = x + (tx - x) * 0.4 + math.random(-2, 2)
    local sz = z + (tz - z) * 0.4 + math.random(-2, 2)
    clone.Transform:SetPosition(sx, y, sz)

    -- 召唤特效（蝴蝶光效）
    local fx = _G.SpawnPrefab("statue_transition_2")
    if fx then fx.Transform:SetPosition(sx, y + 0.5, sz) end

    -- 瘫痪危险组件（不能Remove，保留组件防止残留回调崩溃）
    if clone.components.playervision then
        local nop = function() end
        clone.components.playervision.OnEquipChanged = nop
        clone.components.playervision.OnTick = nop
        clone.components.playervision.ForceNightVision = nop
        clone.components.playervision.ForceGoggleVision = nop
    end
    if clone.components.playerlight then
        clone.components.playerlight.OnTick = function(self, dt) end
    end
    if clone.components.playercontroller then
        clone.components.playercontroller.OnControl = function(self, ...) end
        clone.components.playercontroller.OnUpdate = function(self, dt) end
    end

    -- 清空背包（pcall包裹，兼容不同角色）
    if clone.components.inventory then
        _G.pcall(function()
            for i = 1, 20 do
                local item = clone.components.inventory:GetItemInSlot(i)
                if item and item:IsValid() then
                    _G.pcall(function() clone.components.inventory:DropItem(item, true, true) end)
                    if item:IsValid() then _G.pcall(function() item:Remove() end) end
                end
            end
            for _, slot in ipairs({ _G.EQUIPSLOTS.HANDS, _G.EQUIPSLOTS.HEAD, _G.EQUIPSLOTS.BODY }) do
                local eq = clone.components.inventory:GetEquippedItem(slot)
                if eq and eq:IsValid() then _G.pcall(function() eq:Remove() end) end
            end
        end)
    end

    -- builder/techtree/ghostlybond：没有残留回调，直接移除
    if clone.components.builder then clone:RemoveComponent("builder") end
    if clone.components.techtree then clone:RemoveComponent("techtree") end
    if clone.components.ghostlybond then clone:RemoveComponent("ghostlybond") end

    -- 添加战斗组件
    if not clone.components.combat then
        clone:AddComponent("combat")
    end
    if target:IsValid() then
        clone.components.combat:SetTarget(target)
    end

    -- 继承50%攻击力
    local player_dmg = (owner.components.combat and owner.components.combat.defaultdamage) or 10
    clone.components.combat.defaultdamage = player_dmg * 0.5
    clone.components.combat.attackperiod = owner.components.combat and owner.components.combat.attackperiod or 0.5

    -- 添加跟随组件
    if not clone.components.follower then
        clone:AddComponent("follower")
    end
    clone.components.follower:SetLeader(owner)

    -- 分身移速+40%
    if clone.components.locomotor then
        clone.components.locomotor.walkspeed = 4 * 1.4
        clone.components.locomotor.runspeed = 7 * 1.4
    end

    -- 友军标签（保留"player"标签防止其他逻辑出错）
    if not clone:HasTag("companion") then clone:AddTag("companion") end
    if not clone:HasTag("friendly") then clone:AddTag("friendly") end

    -- 半透明视觉效果
    if clone.AnimState then
        clone.AnimState:SetMultColour(1, 1, 1, 0.75)
    end

    -- 战斗驱动：每1秒自动追击+攻击（不通过DoAttack，直接扣血，避免走动画/状态机导致刷日志）
    clone._zidie_brain_task = clone:DoPeriodicTask(1, function()
        if not clone:IsValid() or not owner:IsValid() then return end

        local ct = clone.components.combat and clone.components.combat.target
        if not ct or not ct:IsValid() or (ct.components.health and ct.components.health:IsDead()) then
            -- 找附近15码内最近的敌人
            local cx, cy, cz = clone.Transform:GetWorldPosition()
            local enemies = _G.TheSim:FindEntities(cx, cy, cz, 15, { "_combat" })
            local nearest, ndist = nil, 999999
            for _, e in ipairs(enemies) do
                if e ~= owner and e ~= clone and e:IsValid() and e.components.health and not e.components.health:IsDead() then
                    local ex, ey, ez = e.Transform:GetWorldPosition()
                    local d = (cx - ex) ^ 2 + (cz - ez) ^ 2
                    if d < ndist then ndist = d; nearest = e end
                end
            end
            ct = nearest
            if ct then
                clone.components.combat:SetTarget(ct)
            else
                clone.components.follower:SetLeader(owner)
                return
            end
        end

        -- 追击+攻击
        if ct and ct:IsValid() then
            local cx, cy, cz = clone.Transform:GetWorldPosition()
            local tx, ty, tz = ct.Transform:GetWorldPosition()
            local dist = math.sqrt((cx - tx) ^ 2 + (cz - tz) ^ 2)

            if dist <= 3 then
                -- 直接扣血，不走DoAttack/动画，避免无限刷日志
                local now = _G.GetTime and _G.GetTime() or 0
                local last = clone._zidie_last_attack_time or 0
                if now - last >= 1 then
                    clone._zidie_last_attack_time = now
                    local dmg = clone.components.combat and clone.components.combat.defaultdamage or 5
                    if ct.components.health and not ct.components.health:IsDead() then
                        ct.components.health:DoDelta(-dmg, false, "zidie_clone")
                    end
                end
            elseif clone.components.locomotor then
                clone.components.locomotor:GoToEntity(ct)
            end
        end
    end)

    -- 8秒后消失
    clone:DoTaskInTime(8, function()
        if clone:IsValid() then
            local cx, cy, cz = clone.Transform:GetWorldPosition()
            local fx2 = _G.SpawnPrefab("statue_transition_2")
            if fx2 then fx2.Transform:SetPosition(cx, cy + 0.5, cz) end
            if clone._zidie_brain_task then
                clone._zidie_brain_task:Cancel()
                clone._zidie_brain_task = nil
            end
            clone:Remove()
        end
    end)

    return clone
end

-- ======== 注册附魔 ========

AddPrefabPostInit("world", function(inst)
    if not _G.Moon_IsHHEnabled() then return end

    _G.AddSpecialEquipEffect("Legend_ZIDIE", {
        name = "紫蝶",
        client_text = "紫\n蝶",
        desc = "攻击20%几率召唤蝶影分身(50%属性,8秒,最多2个)\n分身存在时本体伤害+30%\n移速永久+20%,分身移速+40%",
        check_desc = "身化蝶影，以假乱真！",
        can_add = false,
        only_one = true,
        is_special = false,
        client_color = { 0.8, 0, 0.8, 1 },
        check_equip_can_add = function(inst)
            return true, "满足条件"
        end,

        on_equip_fn = function(inst, owner, value)
            _G.Moon_AddEffect(owner, "zidie", "Legend_ZIDIE", 1)
            if not owner._zidie_hooked then
                owner._zidie_hooked = true
                owner._zidie_clones = {}

                -- 永久移速+20%
                local hh = owner.components.hh_player
                if hh then
                    hh:AddEffectValueByKey("addSpeedPercent", 20)
                end

                -- 监听攻击事件：20%几率召唤分身
                owner._zidie_attack_handler = function(attacker, data)
                    if not _G.Moon_HasEffect(owner, "zidie") then return end
                    local target = data and data.target
                    if not target or not target:IsValid() then return end
                    if target == owner then return end
                    if math.random() > 0.2 then return end

                    local had_clones = has_alive_clones(owner)
                    if #owner._zidie_clones >= 2 then return end

                    local clone = spawn_clone(owner, target)
                    if clone then
                        table.insert(owner._zidie_clones, { entity = clone })
                        if not had_clones and hh then
                            hh:AddEffectValueByKey("addComDamagePercent", 30)
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._zidie_attack_handler)

                -- 每2秒检查分身状态
                owner._zidie_check_task = owner:DoPeriodicTask(2, function()
                    if not _G.Moon_HasEffect(owner, "zidie") then return end
                    if not owner:IsValid() then return end
                    local had_clones = #(owner._zidie_clones or {})
                    cleanup_clones(owner)
                    local now_clones = #(owner._zidie_clones or {})
                    if had_clones > 0 and now_clones == 0 then
                        local hhp = owner.components.hh_player
                        if hhp then
                            hhp:ReduceEffectValueByKey("addComDamagePercent", 30)
                        end
                    end
                end)
            end
        end,

        un_equip_fn = function(inst, owner, value)
            _G.Moon_ReduceEffect(owner, "zidie", "Legend_ZIDIE", 1)
            if not _G.Moon_HasEffect(owner, "zidie") then
                if owner._zidie_check_task then
                    owner._zidie_check_task:Cancel()
                    owner._zidie_check_task = nil
                end
                if owner._zidie_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._zidie_attack_handler)
                    owner._zidie_attack_handler = nil
                end

                cleanup_clones(owner)
                for _, data in ipairs(owner._zidie_clones or {}) do
                    if data.entity and data.entity:IsValid() then
                        data.entity:Remove()
                    end
                end
                owner._zidie_clones = nil

                local hh = owner.components.hh_player
                if hh then
                    hh:ReduceEffectValueByKey("addSpeedPercent", 20)
                    hh:ReduceEffectValueByKey("addComDamagePercent", 30)
                end
                owner._zidie_hooked = nil
            end
        end,
    })

    _G.Moon_RegisterEnchantDrop("Legend_ZIDIE", 0.01)
end)
