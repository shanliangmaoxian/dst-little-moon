local _G = GLOBAL
local Widget = _G.require("widgets/widget")
local ImageButton = _G.require("widgets/imagebutton")

-- 获取配置项 (Mod API 直接调用)
local ENABLE_TREASURE = GetModConfigData("ENABLE_TREASURE")
local PROXIMITY_LIMIT = GetModConfigData("PROXIMITY_LIMIT") or 50
local PLAYER_LIMIT = GetModConfigData("PLAYER_LIMIT") or 100
local GLOBAL_LIMIT = GetModConfigData("GLOBAL_LIMIT") or 500
local EXPIRY_TIME = GetModConfigData("EXPIRY_TIME") or 480
local ENABLE_QL_HELPER = GetModConfigData("ENABLE_QL_HELPER")
local LITTLE_MOON_SCALE = GetModConfigData("LITTLE_MOON_SCALE") or 1.0
local ENABLE_AUTO_PICKUP = GetModConfigData("ENABLE_AUTO_PICKUP")
local DISABLE_KRAMPUS_PACK = GetModConfigData("DISABLE_KRAMPUS_PACK")
local AUTO_PICKUP_RANGE = GetModConfigData("AUTO_PICKUP_RANGE") or 5
local ENABLE_DEMON_ALTAR = GetModConfigData("ENABLE_DEMON_ALTAR")
local ENABLE_DISABLE_RESELECT = GetModConfigData("ENABLE_DISABLE_RESELECT")
local ENABLE_SUICIDE = GetModConfigData("ENABLE_SUICIDE")
local ENABLE_LOOT_LIMITER = GetModConfigData("ENABLE_LOOT_LIMITER")
local MAX_NON_STACKABLE = GetModConfigData("MAX_NON_STACKABLE") or 5
local ENABLE_SHIJIZHIHUA_BULB = GetModConfigData("ENABLE_SHIJIZHIHUA_BULB")
local DIG_TREASURE_MODE = GetModConfigData("DIG_TREASURE_MODE") or 0
local MAX_NEARBY_MONSTERS = GetModConfigData("MAX_NEARBY_MONSTERS") or 20
local ENABLE_MORE_ENCHANTS = GetModConfigData("ENABLE_MORE_ENCHANTS")

-- 强化版防打包拦截逻辑
local function ApplyAntiPacking(inst)
    -- 1. 基础标签协议
    inst:AddTag("nopack")
    inst:AddTag("nonpackable")
    inst:AddTag("backpack")
    inst:AddTag("irreplaceable")
    inst:AddTag("questitem")
    
    -- 2. 移除常见的打包组件 (延迟执行以覆盖其他 Mod 的注入)
    if _G.TheWorld.ismastersim then
        inst:DoTaskInTime(0, function()
            -- 移除 "Architect" 或 "Pack Everything" 等 Mod 可能添加的组件
            if inst.components.packable then
                inst:RemoveComponent("packable")
            end
            
            -- 针对特定 Mod 的属性设置
            inst.not_packable = true
            
            if inst.components.inventoryitem then
                inst.components.inventoryitem.cangoincontainer = false
            end
        end)
    end
end

if DISABLE_KRAMPUS_PACK then
    AddPrefabPostInit("krampus", ApplyAntiPacking)
end

-- 掉落物优化限流逻辑 (最高优先级拦截)
if ENABLE_LOOT_LIMITER then
    local _SpawnPrefab = _G.SpawnPrefab
    local last_tick = -1
    local tick_counts = {}

    -- 判定是否为“高频垃圾掉落物”
    local function IsJunkLoot(prefab)
        if not prefab then return false end
        local name = _G.tostring(prefab):lower()
        if name == "minimap" then return false end
        return name:find("blueprint") 
            or name:find("recipe") 
            or name:find("schematic")
            or name:find("tally") 
            or name:find("scroll")
            or name:find("treasure_map")
    end

    -- 全局拦截器 (瞬时返回 nil，确保宣告 Mod 拿不到多余信号)
    _G.SpawnPrefab = function(name, ...)
        if _G.TheWorld and _G.TheWorld.ismastersim then
            local tick = _G.TheSim:GetTick()
            if tick ~= last_tick then
                last_tick = tick
                tick_counts = {}
            end

            -- 针对不可堆叠物或垃圾物品进行瞬时限流
            -- 注意：这里使用较宽松的 2 倍限制，主要靠下方的 DropLoot 精确限流
            if IsJunkLoot(name) then
                local count = (tick_counts[name] or 0) + 1
                tick_counts[name] = count
                if count > (MAX_NON_STACKABLE * 2) then
                    return nil
                end
            end
        end
        
        local inst = _SpawnPrefab(name, ...)
        
        -- 辅助限流：针对所有非堆叠物品的空间密度检查 (双重保险)
        if inst and _G.TheWorld and _G.TheWorld.ismastersim then
            inst:DoTaskInTime(0, function(i)
                if not i:IsValid() or not i.Transform then return end
                if (i.components.inventoryitem and not i.components.stackable) or IsJunkLoot(i.prefab) then
                    local x, y, z = i.Transform:GetWorldPosition()
                    local ents = _G.TheSim:FindEntities(x, y, z, 6)
                    local count = 0
                    for _, ent in _G.ipairs(ents) do
                        if ent.prefab == i.prefab then count = count + 1 end
                    end
                    if count > MAX_NON_STACKABLE then i:Remove() end
                end
            end)
        end
        return inst
    end

    -- 组件级精确限流：同步修正“宣告 Mod”的统计数值
    AddComponentPostInit("lootdropper", function(self)
        local old_DropLoot = self.DropLoot
        self.DropLoot = function(self, pt, attacker)
            local prefabs = self:GenerateLoot()
            if not prefabs or #prefabs == 0 then
                return old_DropLoot(self, pt, attacker)
            end

            local counts = {}
            for _, v in _G.ipairs(prefabs) do
                counts[v] = (counts[v] or 0) + 1
            end

            if _G.TheWorld.components.lootreplicator ~= nil then
                _G.TheWorld.components.lootreplicator:OnDropLoot(self.inst, prefabs, pt)
            end

            for prefab, total_count in _G.pairs(counts) do
                if total_count > 0 then
                    -- 预判：如果是不可堆叠物品，直接在源头截断循环
                    local test_loot = self:SpawnLootPrefab(prefab, pt)
                    if test_loot then
                        local is_stackable_test = test_loot.components.stackable ~= nil
                        self.inst:PushEvent("onlootdropped", { loot = test_loot, attacker = attacker })

                        if is_stackable_test then
                            -- 【可堆叠】逻辑：合并
                            local max_size = test_loot.components.stackable.maxsize or 40
                            local current_count = _G.math.min(total_count, max_size)
                            test_loot.components.stackable:SetStackSize(current_count)
                            local remaining = total_count - current_count
                            while remaining > 0 do
                                local next_loot = self:SpawnLootPrefab(prefab, pt)
                                if next_loot then
                                    self.inst:PushEvent("onlootdropped", { loot = next_loot, attacker = attacker })
                                    local drop_count = _G.math.min(remaining, max_size)
                                    next_loot.components.stackable:SetStackSize(drop_count)
                                    remaining = remaining - drop_count
                                else break end
                            end
                        else
                            -- 【不可堆叠】核心修复：强制截断循环次数
                            -- 这样 PushEvent 只会触发 MAX_NON_STACKABLE 次，宣告 Mod 就会变准确
                            local actual_to_drop = _G.math.min(total_count, MAX_NON_STACKABLE)
                            for i = 1, actual_to_drop - 1 do
                                local extra_loot = self:SpawnLootPrefab(prefab, pt)
                                if extra_loot then
                                    self.inst:PushEvent("onlootdropped", { loot = extra_loot, attacker = attacker })
                                else break end
                            end
                        end
                    else
                        -- SpawnLootPrefab 返回 nil：说明被其他 Mod（如 1.5.4 金币系统）拦截处理
                        -- 需要为全部数量调用 SpawnLootPrefab，确保拦截方能正确处理每一份掉落
                        for i = 2, total_count do
                            self:SpawnLootPrefab(prefab, pt)
                        end
                    end
                end
            end
        end
    end)
end

local treasure_points = {}

local function Say(player, message)
    if player.components.talker then
        player.components.talker:Say(message)
    end
end

local function RegisterTreasurePoint(inst)
    treasure_points[inst] = true
end

local function UnregisterTreasurePoint(inst)
    treasure_points[inst] = nil
end

local function GetTreasureCounts(userid)
    local total_count = 0
    local player_count = 0

    for inst in _G.pairs(treasure_points) do
        if inst:IsValid() then
            total_count = total_count + 1
            if userid ~= nil and inst.moon_owner == userid then
                player_count = player_count + 1
            end
        else
            treasure_points[inst] = nil
        end
    end

    return total_count, player_count
end

local function CountInventoryItems(inv, prefab)
    local count = 0

    local function CountItem(item)
        if item and item.prefab == prefab then
            count = count + (item.components.stackable and item.components.stackable:StackSize() or 1)
        end
    end

    if inv.itemslots then
        for _, item in _G.pairs(inv.itemslots) do
            CountItem(item)
        end
    end

    if inv.equipslots then
        for _, item in _G.pairs(inv.equipslots) do
            CountItem(item)
        end
    end

    CountItem(inv.activeitem)

    local overflow = inv:GetOverflowContainer()
    if overflow and overflow.slots then
        for _, item in _G.pairs(overflow.slots) do
            CountItem(item)
        end
    end

    return count
end

-- 【核心修复：直接使用 AddPrefabPostInit】
AddPrefabPostInit("hh_treasure_build", function(inst)
    inst:AddTag("hh_treasure_build")
    RegisterTreasurePoint(inst)
    inst:ListenForEvent("onremove", UnregisterTreasurePoint)
    
    if _G.TheWorld.ismastersim then
        -- 处理存档保存与读取
        local old_OnSave = inst.OnSave
        inst.OnSave = function(inst, data)
            if old_OnSave then old_OnSave(inst, data) end
            data.moon_owner = inst.moon_owner
        end
        
        local old_OnLoad = inst.OnLoad
        inst.OnLoad = function(inst, data)
            if old_OnLoad then old_OnLoad(inst, data) end
            if data and data.moon_owner then
                inst.moon_owner = data.moon_owner
                inst:AddTag("moon_owner_".._G.tostring(data.moon_owner))
            end
        end

        -- 过期清理计时
        if EXPIRY_TIME > 0 then
            inst:DoTaskInTime(EXPIRY_TIME, function(i)
                if i:IsValid() then
                    local fx = _G.SpawnPrefab("small_puff")
                    if fx then fx.Transform:SetPosition(i.Transform:GetWorldPosition()) end
                    i:Remove()
                end
            end)
        end
    end
end)

-- 1. 服务器端召唤逻辑 (RPC)
if ENABLE_TREASURE then
    AddModRPCHandler("LittleMoon", "Summon", function(player, count)
        local inv = player.components.inventory
        if not inv or not player.userid then return end
        
        local count_num = _G.math.floor(_G.tonumber(count) or 1)
        if count_num < 1 then
            Say(player, "召唤数量无效。")
            return
        end

        local player_pos = player:GetPosition()
        local cost_prefab = "hh_treasure_tally"
        local total_points, my_points_count = GetTreasureCounts(player.userid)

        -- (2) 全图总数校验
        if total_points >= GLOBAL_LIMIT then
            Say(player, "全服宝藏点已达上限("..GLOBAL_LIMIT..")")
            return
        end

        -- (3) 个人上限校验
        if my_points_count >= PLAYER_LIMIT then
            Say(player, "你的宝藏点已达个人上限("..PLAYER_LIMIT..")")
            return
        end

        -- (4) 局部密度校验
        local near_ents = _G.TheSim:FindEntities(player_pos.x, player_pos.y, player_pos.z, 20, {"hh_treasure_build"})
        local allowed_by_density = _G.math.max(0, PROXIMITY_LIMIT - #near_ents)
        
        if allowed_by_density <= 0 then
            Say(player, "这里太挤了(局部上限"..PROXIMITY_LIMIT.."个)")
            return
        end

        -- (5) 背包卷轴校验
        local current_scrolls = CountInventoryItems(inv, cost_prefab)

        -- 执行召唤
        local summon_count = _G.math.min(count_num, current_scrolls)
        summon_count = _G.math.min(summon_count, allowed_by_density)
        summon_count = _G.math.min(summon_count, PLAYER_LIMIT - my_points_count)
        summon_count = _G.math.min(summon_count, GLOBAL_LIMIT - total_points)

        if summon_count > 0 then
            local radius = _G.math.max(3, summon_count / 4) 
            local spawned_actual = 0
            
            for i = 1, summon_count do
                local angle = i * (2 * _G.math.pi / summon_count)
                local offset = _G.Vector3(_G.math.cos(angle) * radius, 0, _G.math.sin(angle) * radius)
                local spawn_pos = player_pos + offset
                
                -- 地皮检测：必须是陆地地皮，且不是海洋
                if _G.TheWorld.Map:IsVisualGroundAtPoint(spawn_pos.x, spawn_pos.y, spawn_pos.z)
                    and #_G.TheSim:FindEntities(spawn_pos.x, spawn_pos.y, spawn_pos.z, 1.5, nil, {"INLIMBO"}, {"structure", "wall"}) == 0 then
                    local treasure = _G.SpawnPrefab("hh_treasure_build") 
                    if treasure then
                        treasure.Transform:SetPosition(spawn_pos:Get())
                        treasure.moon_owner = player.userid
                        treasure:AddTag("moon_owner_".._G.tostring(player.userid))
                        RegisterTreasurePoint(treasure)
                        
                        local fx = _G.SpawnPrefab("small_puff")
                        if fx then fx.Transform:SetPosition(spawn_pos:Get()) end
                        spawned_actual = spawned_actual + 1
                    end
                end
            end
            
            if spawned_actual > 0 then
                inv:ConsumeByName(cost_prefab, spawned_actual)
                Say(player, _G.string.format("成功开启 %d 个宝藏点！", spawned_actual))
            else
                Say(player, "这里没有足够的陆地空间。")
            end
        else
            Say(player, "无法召唤：卷轴不足或已达上限。")
        end
    end)
end

-- 一键挖宝 RPC：跳过宝藏点放置，直接出怪
if DIG_TREASURE_MODE > 0 then
    AddModRPCHandler("LittleMoon", "QuickDig", function(player, count)
        local inv = player.components.inventory
        if not inv or not player.userid then return end

        -- 防止回调重入
        if player._quick_dig_in_progress then
            return
        end
        player._quick_dig_in_progress = true

        local count_num = _G.math.floor(_G.tonumber(count) or 0)
        if count_num < 1 then
            Say(player, "请选择挖宝数量。")
            player._quick_dig_in_progress = nil
            return
        end

        local player_pos = player:GetPosition()

        -- 怪物数量检查（控制机制）
        -- 使用组件检测代替标签，兼容不同 Mod 生成的怪物
        local nearby_ents = _G.TheSim:FindEntities(
            player_pos.x, player_pos.y, player_pos.z, 20,
            nil, {"INLIMBO", "player", "FX", "NOCLICK", "DECOR", "INVALID"}
        )
        local monster_count = 0
        for _, ent in _G.ipairs(nearby_ents) do
            if ent.components.combat and ent.components.health and not ent:HasTag("player") then
                monster_count = monster_count + 1
            end
        end
        if monster_count > MAX_NEARBY_MONSTERS then
            Say(player, _G.string.format("周边怪物太多了(%d只)，先清理一下", monster_count))
            player._quick_dig_in_progress = nil
            return
        end

        -- 卷轴检查
        local cost_prefab = "hh_treasure_tally"
        local current_scrolls = CountInventoryItems(inv, cost_prefab)
        if current_scrolls <= 0 then
            Say(player, "背包里没有寻宝图卷轴。")
            player._quick_dig_in_progress = nil
            return
        end

        -- 计算实际可挖数量
        local actual_count = _G.math.min(count_num, current_scrolls)

        -- 执行挖宝：创建宝藏点 + 立即挖掉触发怪物
        local radius = _G.math.max(3, actual_count / 4)
        local spawned = 0
        for i = 1, actual_count do
            local angle = i * (2 * _G.math.pi / actual_count)
            local offset = _G.Vector3(_G.math.cos(angle) * radius, 0, _G.math.sin(angle) * radius)
            local spawn_pos = player_pos + offset

            -- 地皮检测：必须是陆地地皮，且不是海洋
            if _G.TheWorld.Map:IsVisualGroundAtPoint(spawn_pos.x, spawn_pos.y, spawn_pos.z)
                and #_G.TheSim:FindEntities(spawn_pos.x, spawn_pos.y, spawn_pos.z, 1.5, nil, {"INLIMBO"}, {"structure", "wall"}) == 0 then
                local treasure = _G.SpawnPrefab("hh_treasure_build")
                if treasure then
                    treasure.Transform:SetPosition(spawn_pos:Get())
                    treasure.moon_owner = player.userid
                    treasure:AddTag("moon_owner_" .. _G.tostring(player.userid))
                    RegisterTreasurePoint(treasure)

                    -- 立刻挖掉：调用 workable:Destroy 跳过动画直接出怪
                    if treasure.components.workable then
                        treasure.components.workable:Destroy(player)
                        spawned = spawned + 1
                    else
                        -- 安全回退：如果没有 workable 组件，直接移除
                        treasure:Remove()
                    end
                end
            end
        end

        if spawned > 0 then
            inv:ConsumeByName(cost_prefab, spawned)
            Say(player, _G.string.format("一键挖宝完成！挖了 %d 个宝藏", spawned))
        else
            Say(player, "挖宝失败，请重试。")
        end
        player._quick_dig_in_progress = nil
    end)
end

if ENABLE_AUTO_PICKUP then
    AddModRPCHandler("LittleMoon", "SetAutoPickup", function(player, enabled)
        if player.auto_pickup_enabled ~= nil then
            player.auto_pickup_enabled:set(enabled == true)
        end
    end)
end

local function DoSuicide(player)
    if player and not player:HasTag("playerghost") and player.components.health then
        if player.components.talker then
            player.components.talker:Say("我杀死了我", 2)
        end
        player.components.health:Kill()
    elseif player and player:HasTag("playerghost") then
        if player.components.talker then
            player.components.talker:Say("死的不能再死了", 2)
        end
    end
end

if ENABLE_SUICIDE then
    AddModRPCHandler("LittleMoon", "Suicide", function(player)
        DoSuicide(player)
    end)

    -- 聊天指令监听实现
    local Old_Networking_Say = _G.Networking_Say
    _G.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, is_repeat, ...)
        if Old_Networking_Say then
            Old_Networking_Say(guid, userid, name, prefab, message, colour, whisper, is_repeat, ...)
        end

        if _G.TheWorld and _G.TheWorld.ismastersim and message and message:sub(1, 1) == "#" then
            local cmd = message:sub(2):lower()
            if cmd == "zs" or cmd == "kill" or cmd == "自杀" then
                local player = _G.UserToPlayer(userid)
                if player then
                    DoSuicide(player)
                end
            end
        end
    end
end

-- 物品自动吸入逻辑
AddPlayerPostInit(function(inst)
    inst.auto_pickup_enabled = _G.net_bool(inst.GUID, "little_moon.auto_pickup_enabled", "autopickupdirty")
    
    if not _G.TheWorld.ismastersim or not ENABLE_AUTO_PICKUP then return end

    inst.auto_pickup_enabled:set(ENABLE_AUTO_PICKUP)

    -- 多人优化：错峰执行，避免所有玩家在同一帧处理逻辑
    inst:DoTaskInTime(_G.math.random() * 1, function()
        inst:DoPeriodicTask(1, function()
            if inst.auto_pickup_enabled:value() and inst.components.inventory and not inst:HasTag("playerghost") then
                local x, y, z = inst.Transform:GetWorldPosition()
                -- 保持高性能标签过滤
                local ents = _G.TheSim:FindEntities(x, y, z, AUTO_PICKUP_RANGE, {"_inventoryitem"}, {"INLIMBO", "catchable", "fire", "minespicup", "spider"})
                local backpack = inst.components.inventory:GetOverflowContainer()
                if not backpack or backpack:IsFull() then return end
                
                local pickup_count = 0
                local MAX_PICKUP_PER_TICK = 10 -- 每秒最多吸10个，防止极端情况下掉落物过多导致卡顿
                
                for _, item in _G.ipairs(ents) do
                    if pickup_count >= MAX_PICKUP_PER_TICK then break end
                    if item:IsValid() and item.components.inventoryitem and not item.components.inventoryitem:IsHeld() 
                       and item.components.inventoryitem.canbepickedup 
                       and not (item.components.burnable and item.components.burnable:IsBurning()) then
                        -- 只有背包里已经有这个东西了，且是可堆叠物品，才吸
                        if backpack:Has(item.prefab, 1) and item.components.stackable then
                            backpack:GiveItem(item, nil, inst:GetPosition())
                            pickup_count = pickup_count + 1
                        end
                    end

                end
            end
        end)
    end)
end)

local POSITION_FILE = "dst_little_moon_position"

local function ScreenYToTopOffset(y)
    local _, screen_h = _G.TheSim:GetScreenSize()
    return y - screen_h
end

local function Clamp(value, min_value, max_value)
    return _G.math.max(min_value, _G.math.min(max_value, value))
end

local function SetClampedButtonPosition(widget, x, y)
    local screen_w, screen_h = _G.TheSim:GetScreenSize()
    local size = 64 * 1.4
    widget:SetPosition(
        Clamp(x, size / 2, screen_w - size / 2),
        Clamp(y, -screen_h + size / 2, -size / 2),
        0
    )
end

-- 2. 在左上角添加图标按钮
if ENABLE_TREASURE or ENABLE_QL_HELPER or ENABLE_AUTO_PICKUP or ENABLE_SUICIDE then
    AddClassPostConstruct("widgets/controls", function(self)
        self.moon_root = self:AddChild(Widget("moon_root"))
        self.moon_root:SetHAnchor(_G.ANCHOR_LEFT)
        self.moon_root:SetVAnchor(_G.ANCHOR_TOP)
        
        local tex = "lunar_seed.tex"
        local atlas = _G.GetInventoryItemAtlas(tex) or "images/inventoryimages.xml"
        self.moon_btn = self.moon_root:AddChild(ImageButton(atlas, tex))
        self.moon_btn:SetScale(1.4)
        
        -- 默认位置
        local default_x, default_y = 80, -100
        self.moon_btn:SetPosition(default_x, default_y)
        
        -- 拖动相关变量
        self.moon_btn.drag_move_handler = nil
        self.moon_btn.drag_button_handler = nil

        self.moon_btn.StartDragging = function(widget)
            if widget.drag_move_handler ~= nil then return end

            local mouse_pos = _G.TheInput:GetScreenPosition()
            local pos_x, pos_y = widget:GetPositionXYZ()

            widget.drag_offset_x = pos_x - mouse_pos.x
            widget.drag_offset_y = pos_y - ScreenYToTopOffset(mouse_pos.y)

            widget.drag_move_handler = _G.TheInput:AddMoveHandler(function(x, y)
                SetClampedButtonPosition(widget, x + widget.drag_offset_x, ScreenYToTopOffset(y) + widget.drag_offset_y)
            end)

            widget.drag_button_handler = _G.TheInput:AddMouseButtonHandler(function(button_id, is_down)
                if button_id == _G.MOUSEBUTTON_RIGHT and not is_down then
                    widget:StopDragging()
                end
            end)
        end

        self.moon_btn.StopDragging = function(widget)
            if widget.drag_move_handler ~= nil then
                widget.drag_move_handler:Remove()
                widget.drag_move_handler = nil
            end
            if widget.drag_button_handler ~= nil then
                widget.drag_button_handler:Remove()
                widget.drag_button_handler = nil
            end
            
            -- 保存位置
            if _G.json ~= nil then
                local x, y = widget:GetPositionXYZ()
                _G.TheSim:SetPersistentString(POSITION_FILE, _G.json.encode({x = x, y = y}), false)
            end
        end

        self.moon_btn.LoadPosition = function(widget)
            if _G.json == nil then
                SetClampedButtonPosition(widget, default_x, default_y)
                return
            end

            _G.TheSim:GetPersistentString(POSITION_FILE, function(success, data)
                if success and data and data ~= "" then
                    local ok, pos = _G.pcall(_G.json.decode, data)
                    if ok and pos and pos.x and pos.y then
                        SetClampedButtonPosition(widget, pos.x, pos.y)
                    else
                        SetClampedButtonPosition(widget, default_x, default_y)
                    end
                else
                    SetClampedButtonPosition(widget, default_x, default_y)
                end
            end)
        end

        self.moon_btn.OnRemoveEntity = function(widget)
            widget:StopDragging()
        end

        -- 右键触发拖动
        local old_OnControl = self.moon_btn.OnControl
        self.moon_btn.OnControl = function(widget, control, down)
            if control == _G.CONTROL_SECONDARY then
                if down then
                    widget:StartDragging()
                end
                return true
            end
            if old_OnControl then
                return old_OnControl(widget, control, down)
            end
            return ImageButton.OnControl(widget, control, down)
        end

        -- 加载保存的位置
        self.moon_btn:LoadPosition()

        self.moon_btn:SetOnClick(function()
            if _G.ThePlayer and _G.ThePlayer.HUD and _G.ThePlayer.HUD.little_moon_panel then
                _G.ThePlayer.HUD.little_moon_panel:Toggle()
            end
        end)
        self.moon_btn:SetHoverText("小月亮助手 (右键拖动)", { offset_y = 40 })
    end)
end

-- 3. 注入 UI 界面
AddClassPostConstruct("screens/playerhud", function(self)
    if ENABLE_TREASURE or ENABLE_QL_HELPER or ENABLE_AUTO_PICKUP or ENABLE_SUICIDE then
        local LittleMoonPanel = _G.require("widgets/little_moon_panel")
        self.little_moon_panel = self:AddChild(LittleMoonPanel(self.owner, PROXIMITY_LIMIT, LITTLE_MOON_SCALE, ENABLE_TREASURE, ENABLE_QL_HELPER, ENABLE_AUTO_PICKUP, ENABLE_SUICIDE, DIG_TREASURE_MODE))
        self.little_moon_panel:MoveToFront()
    end

end)

-- 虚空异界(泰拉)：恶魔祭坛制作配方
if ENABLE_DEMON_ALTAR then
    -- 只有当欧皇模拟器 Mod 开启（存在 emojitan 预制体）时才注册配方
    -- 我们在后期检查，或者使用 PrefabExists
    local function RegisterAltarRecipe()
        local Ingredient = _G.Ingredient
        local RECIPETABS = _G.RECIPETABS
        local TECH = _G.TECH

        -- 检查配方是否已存在，或预制体是否【不存在】
        if (_G.AllRecipes and _G.AllRecipes["emojitan"]) or not _G.PrefabExists("emojitan") then
            return 
        end

        -- 补全基础字符串，防止蓝图加载崩溃
        if not _G.STRINGS.NAMES.EMOJITAN then _G.STRINGS.NAMES.EMOJITAN = "恶魔祭坛" end
        if not _G.STRINGS.RECIPE_DESC.EMOJITAN then _G.STRINGS.RECIPE_DESC.EMOJITAN = "虚空异界的远古祭坛" end
        if not _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.EMOJITAN then _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.EMOJITAN = "散发着不详的气息。" end

        local ok, err = _G.pcall(function()
            AddRecipe("emojitan",
                {
                    Ingredient("thulecite", 6),
                    Ingredient("purplegem", 4),
                    Ingredient("livinglog", 6),
                    Ingredient("goldnugget", 10),
                    Ingredient("nightmarefuel", 20),
                },
                RECIPETABS.MAGIC,
                TECH.MAGIC_TWO,
                {
                    placer = "emojitan_placer",
                    min_spacing = 2,
                    nounlock = true,
                }
            )
        end)
        if ok then
            _G.print("[小月亮] emojitan 配方注册成功")
        end

        -- 世纪之花球茎
        if ENABLE_SHIJIZHIHUA_BULB then
            if not _G.STRINGS.NAMES.SHIJIZHIHUA_BULB then _G.STRINGS.NAMES.SHIJIZHIHUA_BULB = "世纪之花球茎" end
            if not _G.STRINGS.RECIPE_DESC.SHIJIZHIHUA_BULB then _G.STRINGS.RECIPE_DESC.SHIJIZHIHUA_BULB = "原地放置，召唤世纪之花" end
            if not _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHIJIZHIHUA_BULB then _G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHIJIZHIHUA_BULB = "一颗散发着自然与机械气息的球茎。" end

            local ok2, err2 = _G.pcall(function()
                AddRecipe("shijizhihua_bulb",
                    {
                        Ingredient("jixiemoyan", 3),
                        Ingredient("jixiexinbiao", 3),
                        Ingredient("laohuaxinhaofasheqi", 3),
                    },
                    RECIPETABS.MAGIC,
                    TECH.NONE,
                    {
                        nounlock = true,
                    }
                )
            end)
            if ok2 then
                _G.print("[小月亮] shijizhihua_bulb 配方注册成功")
            end
        end
    end

    -- 延迟注册，确保所有 Mod 的 Prefab 都已加载完成
    AddPrefabPostInit("world", function(inst)
        RegisterAltarRecipe()
    end)
end

-- 客户端换人控制：禁用 /reselect 和 /重选角色 指令
-- 策略：本 mod 优先级 -1，先于 3607443539 加载，保存原始函数后在游戏初始化时恢复
local _originalSendResumeRequest = nil
GLOBAL.pcall(function()
    _originalSendResumeRequest = GLOBAL.NetworkProxy.SendResumeRequestToServer
end)

if ENABLE_DISABLE_RESELECT then
    -- 1. 覆盖聊天指令（若能覆盖则提示已禁用）
    local function disabled_msg()
        if GLOBAL.TheFrontEnd then
            GLOBAL.TheFrontEnd:PopScreen()
        end
    end
    GLOBAL.pcall(GLOBAL.AddUserCommand, "reselect", {}, disabled_msg)
    GLOBAL.pcall(GLOBAL.AddUserCommand, "重选角色", {}, disabled_msg)

    -- 2. 拦截 mod 3607443539 的存档写入，阻止换人状态持久化
    GLOBAL.pcall(function()
        local oldSave = GLOBAL.SavePersistentString
        GLOBAL.SavePersistentString = function(filepath, data, ...)
            if filepath == "mod_config_data/resetplayer" then
                return 0, 0  -- 静默丢弃
            end
            return oldSave(filepath, data, ...)
        end
    end)

    -- 3. 游戏初始化后：恢复原始 SendResumeRequestToServer，剥离 3607443539 的换人 hook
    GLOBAL.pcall(function()
        GLOBAL.AddPrefabPostInit("world", function(inst)
            if _originalSendResumeRequest then
                GLOBAL.NetworkProxy.SendResumeRequestToServer = _originalSendResumeRequest
            end
            -- 清理残留存档
            GLOBAL.TheSim:SetPersistentString("mod_config_data/resetplayer", "", false)
        end)
    end)
end

-- ============================================================================================================== --
-- 附魔：灵尾印记 (每天灵尾+1,上限2)
-- 依赖：璇儿 Mod (workshop-3014076942)
-- ============================================================================================================== --

-- 效果管理工具函数
local function Moon_AddEffect(inst, Effect_type, source, value)
    if not inst then return end
    local Effect_table = Effect_type .. "_sources"
    if not inst[Effect_table] then
        inst[Effect_table] = {}
    end
    if value then
        local current_value = inst[Effect_table][source] or 0
        inst[Effect_table][source] = current_value + value
    else
        inst[Effect_table][source] = true
    end
end

local function Moon_ReduceEffect(inst, Effect_type, source, value)
    if not inst or not value then return end
    local Effect_table = Effect_type .. "_sources"
    if inst[Effect_table] and inst[Effect_table][source] then
        local current_value = inst[Effect_table][source]
        if type(current_value) == "number" then
            local new_value = current_value - value
            if new_value == 0 then
                inst[Effect_table][source] = nil
            else
                inst[Effect_table][source] = new_value
            end
        end
    end
end

local function Moon_GetTotalEffectValue(inst, Effect_type)
    if not inst then return 0 end
    local Effect_table = Effect_type .. "_sources"
    if not inst[Effect_table] then return 0 end
    local total = 0
    for k, v in pairs(inst[Effect_table]) do
        if type(v) == "number" then
            total = total + v
        end
    end
    return total
end

local function Moon_HasEffect(inst, Effect_type)
    if not inst then return false end
    local Effect_table = Effect_type .. "_sources"
    if not inst[Effect_table] then return false end
    for k, v in pairs(inst[Effect_table]) do
        if v == true or (type(v) == "number" and v ~= 0) then
            return true
        end
    end
    return false
end

-- 检测 Mod 是否启用（通过 GLOBAL 访问，兼容不同加载阶段）
local function IsModEnabled(id)
    if not GLOBAL.KnownModIndex then return false end
    return GLOBAL.KnownModIndex:IsModEnabledAny(id)
end

-- 检测 HH 附魔框架是否启用
local function IsHHEnabled()
    return IsModEnabled("workshop-3096210166")
        or IsModEnabled("workshop-3709314660")
end

-- 检测璇儿 Mod 是否启用
local function IsMYXLEnabled()
    return IsModEnabled("workshop-3014076942")
end

-- 延迟注册附魔（等 KnownModIndex 就绪）
if ENABLE_MORE_ENCHANTS then
    AddPrefabPostInit("world", function(inst)
        if not IsHHEnabled() then
            return
        end

        -- ========================================
        -- 毛旭：血量+200
        -- ========================================
        GLOBAL.AddSpecialEquipEffect("Legend_MX_HEALTH", {
            name = "毛旭",
            client_text = "毛\n旭",
            desc = "geigei,带我吃鸭蛋",
            check_desc = "人物血量上限+200",
            can_add = false,            -- 不可通过附魔卷轴附魔
            only_one = false,           -- 可叠加（多件装备效果累加）
            is_special = false,         -- 正常途径获取
            -- client_color = { 1, 0.5, 0, 1 }, -- 橙色
            client_color = { 1, 0, 0, 1 },    -- 猩红（稀有）
            check_equip_can_add = function(inst)
                return true, "满足条件"
            end,
            on_equip_fn = function(inst, owner, value)
                if not owner._mx_health_base then
                    owner._mx_health_base = owner.components.health.maxhealth
                end
                Moon_AddEffect(owner, "mx_health", "Legend_MX_HEALTH", 200)
                local total_bonus = Moon_GetTotalEffectValue(owner, "mx_health")
                local new_max = owner._mx_health_base + total_bonus
                owner.components.health:SetMaxHealth(new_max)
                -- 如果之前脱装备时保存了血量，恢复到保存值；否则（首次装备）填充新增血量
                if owner._mx_health_saved_hp ~= nil then
                    owner.components.health:SetCurrentHealth(math.min(owner._mx_health_saved_hp, new_max))
                    owner._mx_health_saved_hp = nil
                else
                    owner.components.health:DoDelta(200)
                end
            end,
            un_equip_fn = function(inst, owner, value)
                -- 脱下前保存当前血量，防止重新装备时通过 DoDelta 刷血
                owner._mx_health_saved_hp = owner.components.health.currenthealth
                Moon_ReduceEffect(owner, "mx_health", "Legend_MX_HEALTH", 200)
                local total_bonus = Moon_GetTotalEffectValue(owner, "mx_health")
                if owner._mx_health_base then
                    owner.components.health:SetMaxHealth(owner._mx_health_base + total_bonus)
                end
            end,
        })

        -- 精英/Boss 掉落 毛旭（3%概率）
        local DROP_CHANCE_MX = 0.03
        AddPrefabPostInitAny(function(inst)
            if not GLOBAL.TheWorld.ismastersim then return end
            if not inst:HasTag("epic") then return end
            inst:ListenForEvent("death", function(inst, data)
                if math.random() > DROP_CHANCE_MX then return end
                local stone = GLOBAL.HHSpawnStoneById("Legend_MX_HEALTH")
                if stone then
                    local pt = inst:GetPosition()
                    local killer = data and data.afflicter
                    if killer and killer:IsValid() and killer.components.inventory then
                        killer.components.inventory:GiveItem(stone, nil, pt)
                    else
                        stone.Transform:SetPosition(pt:Get())
                    end
                end
            end)
        end)

        -- ========================================
        -- 紫蝶：破茧成蝶，每天一次免死满血复活
        -- ========================================
        GLOBAL.AddSpecialEquipEffect("Legend_ZD_BUTTERFLY", {
            name = "紫蝶",
            client_text = "紫\n蝶",
            desc = "蝶破茧，人不灭",
            check_desc = "受到致命伤害时免疫死亡\n满血复活 冷却1天",
            can_add = false,                -- 不可通过附魔卷轴附魔
            only_one = true,                -- 唯一（多件也只生效一次免死）
            is_special = false,             -- 正常途径获取
            client_color = { 0.8, 0, 0.8, 1 }, -- 紫色
            check_equip_can_add = function(inst)
                return true, "满足条件"
            end,
            on_equip_fn = function(inst, owner, value)
                Moon_AddEffect(owner, "zd_butterfly", "Legend_ZD_BUTTERFLY", 1)
                -- 首次装备时安装死亡拦截钩子
                if not owner._zd_death_hook_installed then
                    owner._zd_death_hook_installed = true
                    owner._zd_revive_cooldown = false

                    local oldPushEvent = owner.PushEvent
                    owner.PushEvent = function(self, event, ...)
                        if Moon_HasEffect(self, "zd_butterfly") and not self._zd_revive_cooldown then
                            if event == "death" then
                                local health = self.components.health
                                if health then
                                    -- 满血复活
                                    health:SetVal(health.maxhealth)
                                    self:PushEvent("respawnfromghost")
                                    -- 触发冷却
                                    self._zd_revive_cooldown = true
                                    if self._zd_cooldown_task then
                                        self._zd_cooldown_task:Cancel()
                                    end
                                    -- 1天(480秒)冷却
                                    self._zd_cooldown_task = self:DoTaskInTime(480, function()
                                        self._zd_revive_cooldown = false
                                    end)
                                    if self.components.talker then
                                        self.components.talker:Say("紫蝶护主，破茧重生！")
                                    end
                                    return
                                end
                            end
                            if event == "makeplayerghost" then
                                return
                            end
                        end
                        return oldPushEvent(self, event, ...)
                    end
                end
            end,
            un_equip_fn = function(inst, owner, value)
                Moon_ReduceEffect(owner, "zd_butterfly", "Legend_ZD_BUTTERFLY", 1)
            end,
        })

        -- 精英/Boss 掉落 紫蝶（3%概率）
        AddPrefabPostInitAny(function(inst)
            if not GLOBAL.TheWorld.ismastersim then return end
            if not inst:HasTag("epic") then return end
            inst:ListenForEvent("death", function(inst, data)
                if math.random() > 0.03 then return end
                local stone = GLOBAL.HHSpawnStoneById("Legend_ZD_BUTTERFLY")
                if stone then
                    local pt = inst:GetPosition()
                    local killer = data and data.afflicter
                    if killer and killer:IsValid() and killer.components.inventory then
                        killer.components.inventory:GiveItem(stone, nil, pt)
                    else
                        stone.Transform:SetPosition(pt:Get())
                    end
                end
            end)
        end)

        -- ========================================
        -- 番茄炒蛋：san值恢复8倍，消耗减半，每秒回san
        -- ========================================
        GLOBAL.AddSpecialEquipEffect("Legend_FQCD_SANITY", {
            name = "番茄炒蛋",
            client_text = "番\n茄",
            desc = "san值恢复速度大幅提升,san值消耗减半,每5秒回复20点san",
            check_desc = "san恢复8倍\nsan消耗-50%\n每5秒+20san",
            can_add = false,                -- 不可通过附魔卷轴附魔
            only_one = true,                -- 唯一
            is_special = false,             -- 正常途径获取
            client_color = { 1, 0, 0, 1 },    -- 猩红（稀有）
            check_equip_can_add = function(inst)
                return true, "满足条件"
            end,
            on_equip_fn = function(inst, owner, value)
                Moon_AddEffect(owner, "fqcd_sanity", "Legend_FQCD_SANITY", 1)
                if not owner._fqcd_sanity_hooked then
                    owner._fqcd_sanity_hooked = true
                    local sanity = owner.components.sanity
                    if sanity then
                        -- san恢复 8倍速
                        sanity.externalmodifiers:SetModifier("番茄炒蛋", 8)
                        -- san消耗减半
                        if not sanity._fqcd_DoDelta then
                            local original_do_delta = sanity.DoDelta
                            sanity._fqcd_DoDelta = original_do_delta
                            sanity.DoDelta = function(self, delta, overtime, ...)
                                if delta < 0 then
                                    delta = delta * 0.5
                                end
                                return original_do_delta(self, delta, overtime, ...)
                            end
                        end
                        -- 每5秒回20san
                        if not owner._fqcd_regen_task then
                            owner._fqcd_regen_task = owner:DoPeriodicTask(5, function()
                                if Moon_HasEffect(owner, "fqcd_sanity") and owner.components.sanity then
                                    owner.components.sanity:DoDelta(20)
                                end
                            end)
                        end
                    end
                end
            end,
            un_equip_fn = function(inst, owner, value)
                Moon_ReduceEffect(owner, "fqcd_sanity", "Legend_FQCD_SANITY", 1)
                if not Moon_HasEffect(owner, "fqcd_sanity") then
                    local sanity = owner.components.sanity
                    if sanity then
                        sanity.externalmodifiers:RemoveModifier("番茄炒蛋")
                        if sanity._fqcd_DoDelta then
                            sanity.DoDelta = sanity._fqcd_DoDelta
                            sanity._fqcd_DoDelta = nil
                        end
                    end
                    if owner._fqcd_regen_task then
                        owner._fqcd_regen_task:Cancel()
                        owner._fqcd_regen_task = nil
                    end
                end
            end,
        })

        -- 精英/Boss 掉落 番茄炒蛋（3%概率）
        AddPrefabPostInitAny(function(inst)
            if not GLOBAL.TheWorld.ismastersim then return end
            if not inst:HasTag("epic") then return end
            inst:ListenForEvent("death", function(inst, data)
                if math.random() > 0.03 then return end
                local stone = GLOBAL.HHSpawnStoneById("Legend_FQCD_SANITY")
                if stone then
                    local pt = inst:GetPosition()
                    local killer = data and data.afflicter
                    if killer and killer:IsValid() and killer.components.inventory then
                        killer.components.inventory:GiveItem(stone, nil, pt)
                    else
                        stone.Transform:SetPosition(pt:Get())
                    end
                end
            end)
        end)

        -- ========================================
        -- 灵尾印记（依赖璇儿 Mod）
        -- ========================================
        if not IsMYXLEnabled() then
            return
        end

        GLOBAL.AddSpecialEquipEffect("Legend_MYXL_LEVEL", {
            name = "灵尾印记",
            client_text = "灵\n尾印",
            desc = "每天灵尾+1~5(上限5)",
            check_desc = "只对璇儿生效\n仅限背包类装备附魔",
            can_add = false,         -- 不可通过附魔卷轴附魔
            only_one = false,        -- 可叠加（多件装备效果累加）
            is_special = false,      -- 正常途径获取
            client_color = { 1, 0, 0, 1 },    -- 猩红（稀有）
            ui_from_desc = "击败精英/Boss概率掉落",
            check_equip_can_add = function(inst)
                if inst:HasTag("backpack") then
                    return true, "满足条件"
                end
                return false, "只允许附魔在背包上"
            end,
            on_equip_fn = function(inst, owner, value)
                Moon_AddEffect(owner, "myxl_level", "Legend_MYXL_LEVEL", 1)
            end,
            un_equip_fn = function(inst, owner, value)
                Moon_ReduceEffect(owner, "myxl_level", "Legend_MYXL_LEVEL", 1)
            end,
        })

        -- 每日周期：灵尾+1~5
        AddPrefabPostInitAny(function(inst)
            if not GLOBAL.TheWorld.ismastersim then return end
            if not inst:HasTag("player") then return end
            inst:WatchWorldState("cycles", function(inst, cycles)
                local level = Moon_GetTotalEffectValue(inst, "myxl_level")
                if level > 0 then
                    local myxl_level = inst.components.myxl_level
                    if myxl_level and myxl_level.LevelUp then
                        local daily_gain = math.random(1, 5)
                        myxl_level:LevelUp(false, math.min(level * daily_gain, 5))
                    end
                end
            end)
        end)

        -- 精英/Boss 掉落 灵尾印记（3%概率）
        local DROP_CHANCE = 0.03
        AddPrefabPostInitAny(function(inst)
            if not GLOBAL.TheWorld.ismastersim then return end
            if not inst:HasTag("epic") then return end
            inst:ListenForEvent("death", function(inst, data)
                if math.random() > DROP_CHANCE then return end
                local stone = GLOBAL.HHSpawnStoneById("Legend_MYXL_LEVEL")
                if stone then
                    local pt = inst:GetPosition()
                    local killer = data and data.afflicter
                    if killer and killer:IsValid() and killer.components.inventory then
                        killer.components.inventory:GiveItem(stone, nil, pt)
                    else
                        stone.Transform:SetPosition(pt:Get())
                    end
                end
            end)
        end)
    end)
end
