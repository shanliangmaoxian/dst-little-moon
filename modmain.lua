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

-- 【核心修复：直接使用 AddPrefabPostInit】
AddPrefabPostInit("hh_treasure_build", function(inst)
    inst:AddTag("hh_treasure_build")
    
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
        
        local count_num = _G.tonumber(count) or 1
        local player_pos = player:GetPosition()
        local cost_prefab = "hh_treasure_tally"

        -- (1) 获取全图所有宝藏点
        local all_points = {}
        for _, v in _G.pairs(_G.Ents) do
            if v:HasTag("hh_treasure_build") then
                _G.table.insert(all_points, v)
            end
        end

        -- (2) 全图总数校验
        if #all_points >= GLOBAL_LIMIT then
            if player.components.talker then player.components.talker:Say("全服宝藏点已达上限("..GLOBAL_LIMIT..")") end
            return
        end

        -- (3) 个人上限校验
        local my_points_count = 0
        for _, v in _G.ipairs(all_points) do
            if v.moon_owner == player.userid then
                my_points_count = my_points_count + 1
            end
        end
        
        if my_points_count >= PLAYER_LIMIT then
            if player.components.talker then player.components.talker:Say("你的宝藏点已达个人上限("..PLAYER_LIMIT..")") end
            return
        end

        -- (4) 局部密度校验
        local near_ents = _G.TheSim:FindEntities(player_pos.x, player_pos.y, player_pos.z, 20, {"hh_treasure_build"})
        local allowed_by_density = _G.math.max(0, PROXIMITY_LIMIT - #near_ents)
        
        if allowed_by_density <= 0 then
            if player.components.talker then player.components.talker:Say("这里太挤了(局部上限"..PROXIMITY_LIMIT.."个)") end
            return
        end

        -- (5) 背包卷轴校验
        local current_scrolls = 0
        if inv.itemslots then
            for _, v in _G.pairs(inv.itemslots) do
                if v and v.prefab == cost_prefab then
                    current_scrolls = current_scrolls + (v.components.stackable and v.components.stackable:StackSize() or 1)
                end
            end
        end

        -- 执行召唤
        local summon_count = _G.math.min(count_num, current_scrolls)
        summon_count = _G.math.min(summon_count, allowed_by_density)
        summon_count = _G.math.min(summon_count, PLAYER_LIMIT - my_points_count)
        summon_count = _G.math.min(summon_count, GLOBAL_LIMIT - #all_points)

        if summon_count > 0 then
            local radius = _G.math.max(3, summon_count / 4) 
            local spawned_actual = 0
            
            for i = 1, summon_count do
                local angle = i * (2 * _G.math.pi / summon_count)
                local offset = _G.Vector3(_G.math.cos(angle) * radius, 0, _G.math.sin(angle) * radius)
                local spawn_pos = player_pos + offset
                
                -- 地皮检测：必须是陆地地皮，且不是海洋
                if _G.TheWorld.Map:IsVisualGroundAtPoint(spawn_pos.x, spawn_pos.y, spawn_pos.z) then
                    local treasure = _G.SpawnPrefab("hh_treasure_build") 
                    if treasure then
                        treasure.Transform:SetPosition(spawn_pos:Get())
                        treasure.moon_owner = player.userid
                        treasure:AddTag("moon_owner_".._G.tostring(player.userid))
                        
                        local fx = _G.SpawnPrefab("small_puff")
                        if fx then fx.Transform:SetPosition(spawn_pos:Get()) end
                        spawned_actual = spawned_actual + 1
                    end
                end
            end
            
            if spawned_actual > 0 then
                inv:ConsumeByName(cost_prefab, spawned_actual)
                if player.components.talker then
                    player.components.talker:Say(_G.string.format("成功开启 %d 个宝藏点！", spawned_actual))
                end
            else
                if player.components.talker then player.components.talker:Say("这里没有足够的陆地空间。") end
            end
        else
            if player.components.talker then player.components.talker:Say("无法召唤：卷轴不足或已达上限。") end
        end
    end)
end

local POSITION_FILE = "dst_little_moon_position"

local function ScreenYToTopOffset(y)
    local _, screen_h = _G.TheSim:GetScreenSize()
    return y - screen_h
end

-- 2. 在左上角添加图标按钮
if ENABLE_TREASURE or ENABLE_QL_HELPER then
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
                widget:SetPosition(x + widget.drag_offset_x, ScreenYToTopOffset(y) + widget.drag_offset_y)
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
            local x, y = widget:GetPositionXYZ()
            _G.TheSim:SetPersistentString(POSITION_FILE, _G.json.encode({x = x, y = y}), false)
        end

        self.moon_btn.LoadPosition = function(widget)
            _G.TheSim:GetPersistentString(POSITION_FILE, function(success, data)
                if success and data and data ~= "" then
                    local ok, pos = _G.pcall(_G.json.decode, data)
                    if ok and pos and pos.x and pos.y then
                        widget:SetPosition(pos.x, pos.y)
                    end
                end
            end)
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
    if ENABLE_TREASURE or ENABLE_QL_HELPER then
        local LittleMoonPanel = _G.require("widgets/little_moon_panel")
        self.little_moon_panel = self:AddChild(LittleMoonPanel(self.owner, PROXIMITY_LIMIT, LITTLE_MOON_SCALE, ENABLE_TREASURE, ENABLE_QL_HELPER))
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
                -- 性能优化：按距离排序，最多显示前 15 个
                _G.table.sort(ents, function(a, b)
                    return a:GetDistanceSqToInst(_G.ThePlayer) < b:GetDistanceSqToInst(_G.ThePlayer)
                end)
                for i = 1, _G.math.min(15, #ents) do
                    table.insert(target_ents, ents[i])
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
