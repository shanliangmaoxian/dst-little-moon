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

    -- 直接用玩家本人的预制体，组件保留但瘫痪
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

    -- 必须保留所有组件！删除组件会导致残留的事件回调崩溃
    -- 替换危险函数为空函数，让它们"活着但不做事"
    if clone.components.playervision then
        local pv = clone.components.playervision
        local function nop() end
        pv.OnEquipChanged = nop
        pv.OnTick = nop
        pv.ForceNightVision = nop
        pv.ForceGoggleVision = nop
    end
    if clone.components.playerlight then
        clone.components.playerlight.OnTick = function(self, dt) end
    end
    if clone.components.playercontroller then
        clone.components.playercontroller.OnControl = function(self, ...) end
        clone.components.playercontroller.OnUpdate = function(self, dt) end
    end

    -- 清空背包（保留组件，防止残留回调崩溃）
    -- 不同角色的inventory API不同，用pcall包裹防止报错
    if clone.components.inventory then
        _G.pcall(function()
            -- 清空所有格子
            for i = 1, 20 do
                local item = clone.components.inventory:GetItemInSlot(i)
                if item and item:IsValid() then
                    _G.pcall(function() clone.components.inventory:DropItem(item, true, true) end)
                    _G.pcall(function() item:Remove() end)
                end
            end
            -- 也清空手部
            local held = clone.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HANDS)
            if held and held:IsValid() then
                _G.pcall(function() held:Remove() end)
            end
            local head = clone.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.HEAD)
            if head and head:IsValid() then
                _G.pcall(function() head:Remove() end)
            end
            local body = clone.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.BODY)
            if body and body:IsValid() then
                _G.pcall(function() body:Remove() end)
            end
        end)
    end

    -- builder/techtree/ghostlybond：直接移除也没问题，没有残留事件
    if clone.components.builder then clone:RemoveComponent("builder") end
    if clone.components.techtree then clone:RemoveComponent("techtree") end
    if clone.components.ghostlybond then clone:RemoveComponent("ghostlybond") end

    -- 添加战斗组件
    if not clone.components.combat then
        clone:AddComponent("combat")
    end

    -- 设置仇恨：攻击玩家正在攻击的目标
    if target:IsValid() then
        clone.components.combat:SetTarget(target)
    end

    -- 继承50%攻击力
    local player_dmg = (owner.components.combat and owner.components.combat.defaultdamage) or 10
    clone.components.combat.defaultdamage = player_dmg * 0.5
    -- 攻击间隔和玩家一致
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

    -- 让分身不可被玩家主动攻击（友军tag）
    -- 必须保留"player"标签，否则游戏逻辑会出问题
    if not clone:HasTag("companion") then
        clone:AddTag("companion")
    end
    if not clone:HasTag("friendly") then
        clone:AddTag("friendly")
    end

    -- 透明/虚幻视觉效果（紫蝶分身就该若隐若现）
    if clone.AnimState then
        clone.AnimState:SetMultColour(1, 1, 1, 0.75)
    end

    -- 自动索敌：每2秒找一次新目标
    clone._zidie_reacquire_task = clone:DoPeriodicTask(2, function()
        if not clone:IsValid() then return end
        local cur_target = clone.components.combat and clone.components.combat.target
        if (not cur_target or not cur_target:IsValid() or cur_target.components.health and cur_target.components.health:IsDead())
            and owner:IsValid() then
            local cx, cy, cz = clone.Transform:GetWorldPosition()
            local enemies = _G.TheSim:FindEntities(cx, cy, cz, 12, { "_combat" })
            local nearest = nil
            local nearest_dist = 999999
            for _, e in ipairs(enemies) do
                if e ~= owner and e ~= clone and e:IsValid() and e.components.health and not e.components.health:IsDead() then
                    local dx = cx - e.Transform:GetWorldPosition()
                    local dz = cz - e.Transform:GetWorldPosition()
                    local dist = dx * dx + dz * dz
                    if dist < nearest_dist then
                        nearest_dist = dist
                        nearest = e
                    end
                end
            end
            if nearest then
                clone.components.combat:SetTarget(nearest)
            end
        end
    end)

    -- 保证分身只存活8秒
    clone:DoTaskInTime(8, function()
        if clone:IsValid() then
            local cx, cy, cz = clone.Transform:GetWorldPosition()
            -- 消散特效
            local fx2 = _G.SpawnPrefab("statue_transition_2")
            if fx2 then fx2.Transform:SetPosition(cx, cy + 0.5, cz) end
            -- 清除分身自己的定时任务
            if clone._zidie_reacquire_task then
                clone._zidie_reacquire_task:Cancel()
                clone._zidie_reacquire_task = nil
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

                    -- 20%几率
                    if math.random() > 0.2 then return end

                    -- 清理已消失的分身，检查上限
                    local had_clones = has_alive_clones(owner)
                    if #owner._zidie_clones >= 2 then return end

                    -- 召唤分身
                    local clone = spawn_clone(owner, target)
                    if clone then
                        table.insert(owner._zidie_clones, { entity = clone })

                        -- 如果之前没有分身，现在有了 → 加30%伤害
                        if not had_clones and hh then
                            hh:AddEffectValueByKey("addComDamagePercent", 30)
                        end
                    end
                end
                owner:ListenForEvent("onattackother", owner._zidie_attack_handler)

                -- 每2秒检查分身状态：自动收回伤害buff
                owner._zidie_check_task = owner:DoPeriodicTask(2, function()
                    if not _G.Moon_HasEffect(owner, "zidie") then return end
                    if not owner:IsValid() then return end

                    local had_clones = #(owner._zidie_clones or {})
                    cleanup_clones(owner)
                    local now_clones = #(owner._zidie_clones or {})

                    if had_clones > 0 and now_clones == 0 then
                        -- 所有分身消失 → 移除伤害buff
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
                -- 先取消定时任务，避免冲突
                if owner._zidie_check_task then
                    owner._zidie_check_task:Cancel()
                    owner._zidie_check_task = nil
                end

                -- 移除事件监听
                if owner._zidie_attack_handler then
                    owner:RemoveEventCallback("onattackother", owner._zidie_attack_handler)
                    owner._zidie_attack_handler = nil
                end

                -- 移除所有存活的蝶影分身
                cleanup_clones(owner)
                for _, data in ipairs(owner._zidie_clones or {}) do
                    if data.entity and data.entity:IsValid() then
                        -- 先清除上面绑的定时任务再移除
                        data.entity:Remove()
                    end
                end
                owner._zidie_clones = nil

                -- 移除所有属性buff
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
