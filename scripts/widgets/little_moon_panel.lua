local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local TextEdit = require("widgets/textedit")
local Spinner = require("widgets/spinner")
local TEMPLATES = require("widgets/redux/templates")

local POSITION_FILE = "dst_little_moon_merged_position"
local PANEL_WIDTH = 300
local HANDLE_HEIGHT = 30
local DEFAULT_X = 126
local DEFAULT_Y = -150

local GOLD = { 0.89, 0.76, 0.47, 1 }
local WHITE = { 1, 1, 1, 1 }

local function Clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function ScreenYToTopOffset(y)
    local _, screen_h = TheSim:GetScreenSize()
    return y - screen_h
end

local LittleMoonPanel = Class(Widget, function(self, owner, max_summon, scale, enable_treasure, enable_ql_helper, enable_auto_pickup, enable_suicide, dig_treasure_mode, enable_quick_chat)
    Widget._ctor(self, "LittleMoonPanel")

    self.owner = owner
    self.max_summon = max_summon or 50
    self.enable_treasure = enable_treasure ~= false
    self.enable_ql_helper = enable_ql_helper ~= false
    self.enable_auto_pickup = enable_auto_pickup ~= false
    self.enable_suicide = enable_suicide ~= false
    self.dig_treasure_mode = dig_treasure_mode or 0
    self.enable_quick_chat = enable_quick_chat ~= false

    self.drag_move_handler = nil
    self.drag_button_handler = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0

    -- 1. 动态计算面板总高度
    local panel_height = HANDLE_HEIGHT + 10 -- 基础高度 (页眉 + 边距)
    if self.enable_ql_helper then panel_height = panel_height + 80 end
    if self.enable_treasure then
        panel_height = panel_height + 85
        if self.dig_treasure_mode > 0 then
            panel_height = panel_height + 45
        end
    end
    if self.enable_auto_pickup then panel_height = panel_height + 45 end
    if self.enable_suicide then panel_height = panel_height + 45 end
    if self.enable_quick_chat then panel_height = panel_height + 85 end
    self.panel_height = panel_height

    self:SetScale(scale or 1.0)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetVAnchor(ANCHOR_TOP)
    self:SetPosition(DEFAULT_X, DEFAULT_Y, 0)

    -- 背景
    self.background = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.background:SetSize(PANEL_WIDTH, panel_height)
    self.background:SetTint(0.05, 0.05, 0.06, 0.95)
    self.background:SetClickable(false)

    -- 页眉
    self.header = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.header:SetSize(PANEL_WIDTH, HANDLE_HEIGHT)
    self.header:SetTint(0.15, 0.08, 0.05, 0.98)
    self.header:SetPosition(0, panel_height / 2 - HANDLE_HEIGHT / 2, 0)

    -- 边框绘制函数
    local function AddBorder(w, h, x, y, tint)
        local b = self:AddChild(Image("images/ui.xml", "white.tex"))
        b:SetSize(w, h)
        b:SetTint(unpack(tint))
        b:SetPosition(x, y, 0)
        b:SetClickable(false)
        return b
    end
    AddBorder(PANEL_WIDTH, 2, 0, panel_height / 2 - 1, GOLD) -- Top
    AddBorder(PANEL_WIDTH, 2, 0, -panel_height / 2 + 1, {0.25, 0.20, 0.14, 0.85}) -- Bottom
    AddBorder(2, panel_height, -PANEL_WIDTH / 2 + 1, 0, {0.25, 0.20, 0.14, 0.85}) -- Left
    AddBorder(2, panel_height, PANEL_WIDTH / 2 - 1, 0, {0.25, 0.20, 0.14, 0.85}) -- Right

    -- 拖动手柄
    self.handle = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.handle:SetSize(PANEL_WIDTH, HANDLE_HEIGHT)
    self.handle:SetTint(1, 1, 1, 0)
    self.handle:SetPosition(0, panel_height / 2 - HANDLE_HEIGHT / 2, 0)
    self.handle:SetClickable(true)
    self.handle:SetHoverText("拖动面板")
    self.handle.OnMouseButton = function(_, button, down) return self:OnHandleMouseButton(button, down) end

    self.drag_dots = self.handle:AddChild(Text(CHATFONT, 24, "::: 小月亮助手 :::"))
    self.drag_dots:SetColour(unpack(GOLD))
    self.drag_dots:SetPosition(0, -1, 0)

    -- 2. 堆叠式布局：计算每个部分的起始 Y 坐标
    local current_y = panel_height / 2 - HANDLE_HEIGHT - 20 

    -------------------------------------------------------
    -- 第一部分：快捷指令
    -------------------------------------------------------
    if self.enable_ql_helper then
        self.section1_title = self:AddChild(Text(CHATFONT, 24, "快捷指令"))
        self.section1_title:SetPosition(0, current_y, 0)
        self.section1_title:SetColour(unpack(GOLD))
        if self.section1_title.EnableOutline then self.section1_title:EnableOutline(true) end

        self.ql_button = self:AddChild(TEMPLATES.StandardButton(function() TheNet:Say("#ql", true) end, "清理返钱 (#ql)", { 120, 36 }))
        self.ql_button:SetPosition(-70, current_y - 38, 0)
        self.ql_button:SetTextSize(20)

        self.cleanup_button = self:AddChild(TEMPLATES.StandardButton(function() TheNet:Say("#cleanup", true) end, "清理掉落 (#cleanup)", { 120, 36 }))
        self.cleanup_button:SetPosition(70, current_y - 38, 0)
        self.cleanup_button:SetTextSize(20)

        current_y = current_y - 80 -- 减去该块高度
        
        if self.enable_suicide or self.enable_treasure or self.enable_auto_pickup then
            AddBorder(PANEL_WIDTH - 40, 1, 0, current_y + 15, {0.4, 0.4, 0.4, 0.6}) -- 分割线
        end
    end

    -------------------------------------------------------
    -- 自杀功能
    -------------------------------------------------------
    if self.enable_suicide then
        local suicide_y = current_y - 5
        self.suicide_button = self:AddChild(TEMPLATES.StandardButton(function()
            if MOD_RPC["LittleMoon"] and MOD_RPC["LittleMoon"]["Suicide"] then
                SendModRPCToServer(MOD_RPC["LittleMoon"]["Suicide"])
            end
        end, "快捷自杀", { 120, 36 }))
        self.suicide_button:SetPosition(0, suicide_y, 0)
        self.suicide_button:SetTextSize(20)
        
        current_y = current_y - 45
        
        if self.enable_treasure or self.enable_auto_pickup then
            AddBorder(PANEL_WIDTH - 40, 1, 0, current_y + 15, {0.4, 0.4, 0.4, 0.6})
        end
    end

    -------------------------------------------------------
    -- 第二部分：宝藏召唤
    -------------------------------------------------------
    if self.enable_treasure then
        self.section2_title = self:AddChild(Text(CHATFONT, 24, "宝藏点召唤"))
        self.section2_title:SetPosition(0, current_y, 0)
        self.section2_title:SetColour(unpack(GOLD))
        if self.section2_title.EnableOutline then self.section2_title:EnableOutline(true) end

        local summon_y = current_y - 40
        self.selected_count = 1
        local spinner_data = {}
        for _, count in ipairs({1, 5, 10, 20, 50}) do
            if count <= self.max_summon then
                table.insert(spinner_data, { text = tostring(count), data = count })
            end
        end
        if #spinner_data == 0 then table.insert(spinner_data, { text = "1", data = 1 }) end

        self.spinner_root = self:AddChild(Widget("spinner_root"))
        self.spinner_root:SetPosition(-75, summon_y)
        
        self.spinner_label = self.spinner_root:AddChild(Text(CHATFONT, 22, "数量:"))
        self.spinner_label:SetPosition(-50, 0)
        self.spinner_label:SetColour(unpack(WHITE))

        self.spinner = self.spinner_root:AddChild(Spinner(spinner_data, 85, 32, {font = CHATFONT, size = 22}, nil, nil, nil, true))
        self.spinner:SetTextColour(unpack(WHITE))
        self.spinner:SetOnChangedFn(function(data) self.selected_count = data end)
        self.spinner:SetPosition(20, 0)

        self.btn_summon = self:AddChild(TEMPLATES.StandardButton(function()
            if MOD_RPC["LittleMoon"] and MOD_RPC["LittleMoon"]["Summon"] then
                SendModRPCToServer(MOD_RPC["LittleMoon"]["Summon"], self.selected_count)
            end
        end, "立即召唤", { 110, 36 }))
        self.btn_summon:SetPosition(75, summon_y)
        self.btn_summon:SetTextSize(20)

        current_y = current_y - 85

        -- 一键挖宝子区域
        if self.dig_treasure_mode > 0 then
            local dig_y = current_y + 5

            -- 初始化 dig 数量选择
            self.dig_count = self.dig_treasure_mode
            local dig_spinner_data = {}
            for _, dcount in ipairs({0, 1, 3, 5, 10}) do
                if dcount == 0 then
                    table.insert(dig_spinner_data, { text = "关闭", data = 0 })
                elseif dcount <= self.dig_treasure_mode then
                    table.insert(dig_spinner_data, { text = tostring(dcount), data = dcount })
                end
            end
            if #dig_spinner_data == 0 then
                table.insert(dig_spinner_data, { text = "关闭", data = 0 })
            end

            self.dig_spinner_root = self:AddChild(Widget("dig_spinner_root"))
            self.dig_spinner_root:SetPosition(-75, dig_y)

            self.dig_spinner_label = self.dig_spinner_root:AddChild(Text(CHATFONT, 22, "一键:"))
            self.dig_spinner_label:SetPosition(-50, 0)
            self.dig_spinner_label:SetColour(unpack(WHITE))

            self.dig_spinner = self.dig_spinner_root:AddChild(Spinner(dig_spinner_data, 85, 32, {font = CHATFONT, size = 22}, nil, nil, nil, true))
            self.dig_spinner:SetTextColour(unpack(WHITE))
            self.dig_spinner:SetOnChangedFn(function(data) self.dig_count = data end)
            self.dig_spinner:SetPosition(20, 0)

            -- 根据 dig_treasure_mode 设置 spinner 默认选中项
            for _, item in ipairs(dig_spinner_data) do
                if item.data == self.dig_treasure_mode then
                    self.dig_spinner:SetSelected(item)
                    break
                end
            end

            self.btn_quick_dig = self:AddChild(TEMPLATES.StandardButton(function()
                if self.dig_count > 0 and MOD_RPC["LittleMoon"] and MOD_RPC["LittleMoon"]["QuickDig"] then
                    SendModRPCToServer(MOD_RPC["LittleMoon"]["QuickDig"], self.dig_count)
                end
            end, "一键挖宝", { 110, 36 }))
            self.btn_quick_dig:SetPosition(75, dig_y)
            self.btn_quick_dig:SetTextSize(20)

            current_y = current_y - 45
        end

        if self.enable_auto_pickup then
            AddBorder(PANEL_WIDTH - 40, 1, 0, current_y + 15, {0.4, 0.4, 0.4, 0.6})
        end
    end

    -------------------------------------------------------
    -- 第三部分：助手功能 (自动吸入)
    -------------------------------------------------------
    if self.enable_auto_pickup then
        local assistant_y = current_y - 5
        local real_owner = self.owner or ThePlayer
        
        local initial_checked = false
        if real_owner and real_owner.auto_pickup_enabled then
            initial_checked = real_owner.auto_pickup_enabled:value()
        end

        self.auto_pickup_cb = self:AddChild(TEMPLATES.LabelCheckbox(function(v) 
            local p = self.owner or ThePlayer
            if p and MOD_RPC["LittleMoon"] and MOD_RPC["LittleMoon"]["SetAutoPickup"] then
                SendModRPCToServer(MOD_RPC["LittleMoon"]["SetAutoPickup"], v)
            end
        end, initial_checked, "开启自动吸入物品", CHATFONT, 22, WHITE))
        
        self.auto_pickup_cb:SetPosition(0, assistant_y, 0)
        
        if self.auto_pickup_cb.label then
            self.auto_pickup_cb.label:SetColour(unpack(WHITE))
            self.auto_pickup_cb.label:SetSize(22)
        end

        if real_owner then
            self.inst:ListenForEvent("autopickupdirty", function()
                if real_owner.auto_pickup_enabled and self.auto_pickup_cb then
                    local val = real_owner.auto_pickup_enabled:value()
                    if self.auto_pickup_cb.SetChecked then
                        self.auto_pickup_cb:SetChecked(val)
                    elseif self.auto_pickup_cb.cb and self.auto_pickup_cb.cb.SetChecked then
                        self.auto_pickup_cb.cb:SetChecked(val)
                    end
                end
            end, real_owner)
        end
    end

    -------------------------------------------------------
    -- 快捷发送
    -------------------------------------------------------
    if self.enable_quick_chat then
        -- 分割线
        if self.enable_ql_helper or self.enable_suicide or self.enable_treasure or self.enable_auto_pickup then
            AddBorder(PANEL_WIDTH - 40, 1, 0, current_y + 15, {0.4, 0.4, 0.4, 0.6})
        end

        self.chat_title = self:AddChild(Text(CHATFONT, 24, "快捷发送"))
        self.chat_title:SetPosition(0, current_y, 0)
        self.chat_title:SetColour(unpack(GOLD))
        if self.chat_title.EnableOutline then self.chat_title:EnableOutline(true) end

        local chat_y = current_y - 38

        self.chat_input_bg = self:AddChild(Image("images/ui.xml", "white.tex"))
        self.chat_input_bg:SetSize(175, 30)
        self.chat_input_bg:SetTint(0.9, 0.9, 0.9, 1)
        self.chat_input_bg:SetPosition(-50, chat_y, 0)

        self.chat_input = self:AddChild(TextEdit(CHATFONT, 22))
        self.chat_input:SetPosition(-50, chat_y + 0.5, 0)
        self.chat_input:SetColour(0, 0, 0, 255)
        self.chat_input:SetEditTextColour(0, 0, 0, 255)
        self.chat_input:SetIdleTextColour(0, 0, 0, 255)
        self.chat_input:SetRegionSize(170, 28)
        self.chat_input:SetVAlign(ANCHOR_MIDDLE)
        self.chat_input:SetHAlign(ANCHOR_LEFT)

        self.chat_send_btn = self:AddChild(TEMPLATES.StandardButton(function()
            local msg = self.chat_input:GetString()
            if msg and msg ~= "" then
                TheNet:Say(msg, true)
            end
        end, "发送", { 65, 30 }))
        self.chat_send_btn:SetPosition(105, chat_y, 0)
        self.chat_send_btn:SetTextSize(18)

        current_y = current_y - 50
    end

    self:LoadPosition()
    self:Hide()
end)

function LittleMoonPanel:Toggle()
    if self:IsVisible() then self:Hide() else self:Show(); self:MoveToFront() end
end

function LittleMoonPanel:OnHandleMouseButton(button, down)
    if button ~= MOUSEBUTTON_LEFT then return false end
    if down then self:StartDragging() else self:StopDragging() end
    return true
end

function LittleMoonPanel:StartDragging()
    if self.drag_move_handler ~= nil then return end
    local mouse_pos = TheInput:GetScreenPosition()
    local panel_x, panel_y = self:GetPositionXYZ()
    self.drag_offset_x = panel_x - mouse_pos.x
    self.drag_offset_y = panel_y - ScreenYToTopOffset(mouse_pos.y)
    self:MoveToFront()
    self.drag_move_handler = TheInput:AddMoveHandler(function(x, y) self:UpdateDragPosition(x, y) end)
    self.drag_button_handler = TheInput:AddMouseButtonHandler(function(button_id, is_down)
        if button_id == MOUSEBUTTON_LEFT and not is_down then self:StopDragging() end
    end)
    self:UpdateDragPosition(mouse_pos.x, mouse_pos.y)
end

function LittleMoonPanel:UpdateDragPosition(mouse_x, mouse_y)
    self:SetClampedPosition(mouse_x + self.drag_offset_x, ScreenYToTopOffset(mouse_y) + self.drag_offset_y)
end

function LittleMoonPanel:SetClampedPosition(x, y)
    local screen_w, screen_h = TheSim:GetScreenSize()
    local min_x = PANEL_WIDTH / 2
    local max_x = screen_w - PANEL_WIDTH / 2
    local min_y = -screen_h + self.panel_height / 2
    local max_y = -self.panel_height / 2
    self:SetPosition(Clamp(x, min_x, max_x), Clamp(y, min_y, max_y), 0)
end

function LittleMoonPanel:StopDragging()
    if self.drag_move_handler ~= nil then self.drag_move_handler:Remove(); self.drag_move_handler = nil end
    if self.drag_button_handler ~= nil then self.drag_button_handler:Remove(); self.drag_button_handler = nil end
    local x, y = self:GetPositionXYZ()
    if json ~= nil then
        TheSim:SetPersistentString(POSITION_FILE, json.encode({x = x, y = y}), false)
    end
end

function LittleMoonPanel:LoadPosition()
    if json == nil then return end
    TheSim:GetPersistentString(POSITION_FILE, function(success, data)
        if success and data and data ~= "" then
            local ok, pos = pcall(json.decode, data)
            if ok and pos and pos.x and pos.y then
                self:SetClampedPosition(pos.x, pos.y)
            else
                self:SetClampedPosition(DEFAULT_X, DEFAULT_Y)
            end
        else
            self:SetClampedPosition(DEFAULT_X, DEFAULT_Y)
        end
    end)
end

function LittleMoonPanel:OnRemoveEntity()
    self:StopDragging()
end

return LittleMoonPanel
