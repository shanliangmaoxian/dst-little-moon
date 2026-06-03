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
local ENABLE_HEALTH = GetModConfigData("ENABLE_HEALTH")
local HEALTH_RANGE = GetModConfigData("HEALTH_RANGE") or "nearest"
local SHOW_HEALTH_NUM = GetModConfigData("SHOW_HEALTH_NUM")
local ENABLE_AUTO_PICKUP = GetModConfigData("ENABLE_AUTO_PICKUP")
local AUTO_PICKUP_RANGE = GetModConfigData("AUTO_PICKUP_RANGE") or 5
local ENABLE_DEMON_ALTAR = GetModConfigData("ENABLE_DEMON_ALTAR")

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

if ENABLE_AUTO_PICKUP then
    AddModRPCHandler("LittleMoon", "SetAutoPickup", function(player, enabled)
        if player.auto_pickup_enabled ~= nil then
            player.auto_pickup_enabled:set(enabled == true)
        end
    end)
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
if ENABLE_TREASURE or ENABLE_QL_HELPER or ENABLE_AUTO_PICKUP then
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
    if ENABLE_TREASURE or ENABLE_QL_HELPER or ENABLE_AUTO_PICKUP then
        local LittleMoonPanel = _G.require("widgets/little_moon_panel")
        self.little_moon_panel = self:AddChild(LittleMoonPanel(self.owner, PROXIMITY_LIMIT, LITTLE_MOON_SCALE, ENABLE_TREASURE, ENABLE_QL_HELPER, ENABLE_AUTO_PICKUP))
        self.little_moon_panel:MoveToFront()
    end

    -- 血量显示逻辑
    if ENABLE_HEALTH then
        local HealthBar = _G.require("widgets/health_bar")
        self.health_bars = {}

        self.inst:DoPeriodicTask(0.25, function() -- 降低寻找频率
            if not _G.ThePlayer then return end
            
            local x, y, z = _G.ThePlayer.Transform:GetWorldPosition()
            local ents = _G.TheSim:FindEntities(x, y, z, 25, {"_health"}, {"player", "FX", "DECOR", "INLIMBO"})
            
            local target_ents = {}
            if HEALTH_RANGE == "target" then
                local combat = _G.ThePlayer.replica.combat
                local target = combat and combat:GetTarget()
                if target and target:IsValid() and target.replica.health and not target.replica.health:IsDead() then
                    table.insert(target_ents, target)
                end
            elseif HEALTH_RANGE == "nearest" then
                local nearest = nil
                local min_dist = 9999
                for _, ent in _G.ipairs(ents) do
                    if ent:IsValid() and ent.replica.health and not ent.replica.health:IsDead() then
                        local dist = ent:GetDistanceSqToInst(_G.ThePlayer)
                        if dist < min_dist then
                            min_dist = dist
                            nearest = ent
                        end
                    end
                end
                if nearest then table.insert(target_ents, nearest) end
            else -- "all"
                local alive_ents = {}
                for _, ent in _G.ipairs(ents) do
                    if ent:IsValid() and ent.replica.health and not ent.replica.health:IsDead() then
                        _G.table.insert(alive_ents, ent)
                    end
                end

                -- 性能优化：按距离排序，最多显示前 15 个
                _G.table.sort(alive_ents, function(a, b)
                    return a:GetDistanceSqToInst(_G.ThePlayer) < b:GetDistanceSqToInst(_G.ThePlayer)
                end)
                for i = 1, _G.math.min(15, #alive_ents) do
                    table.insert(target_ents, alive_ents[i])
                end
            end

            local current_frame_ents = {}
            for _, ent in _G.ipairs(target_ents) do
                if ent:IsValid() and ent.replica.health and not ent.replica.health:IsDead() then
                    current_frame_ents[ent] = true
                    if not self.health_bars[ent] then
                        self.health_bars[ent] = self:AddChild(HealthBar(ent, SHOW_HEALTH_NUM))
                    end
                    -- position and show/hide now handled by bar:OnUpdate()
                end
            end

            for ent, bar in _G.pairs(self.health_bars) do
                if not current_frame_ents[ent] then
                    bar:Kill()
                    self.health_bars[ent] = nil
                end
            end
        end)
    end
end)

-- 虚空异界(泰拉)：恶魔祭坛制作配方
if ENABLE_DEMON_ALTAR then
    local Ingredient = GLOBAL.Ingredient
    local RECIPETABS = GLOBAL.RECIPETABS
    local TECH = GLOBAL.TECH

    local ok, err = GLOBAL.pcall(AddRecipe, "emojitan",
        {
            Ingredient("thulecite", 6),          -- 铥矿 ×6
            Ingredient("purplegem", 4),          -- 紫宝石 ×4
            Ingredient("livinglog", 6),          -- 活木 ×6
            Ingredient("goldnugget", 10),        -- 金块 ×10
            Ingredient("nightmarefuel", 20),     -- 噩梦燃料 ×20
        },
        RECIPETABS.MAGIC,       -- 魔法分类
        TECH.MAGIC_TWO,         -- 暗影操控器（魔法二本）
        {
            placer = "emojitan_placer",    -- 进入摆放模式
            min_spacing = 2,               -- 最小间距
            nounlock = true,               -- 不需要原型解锁
        },
        nil,                    -- 不需要角色过滤
        nil,                    -- product 默认就是 emojitan
        1                       -- 每次制作数量
    )
    if not ok then
        GLOBAL.print("[小月亮] emojitan 配方注册失败: " .. GLOBAL.tostring(err))
    end
end
