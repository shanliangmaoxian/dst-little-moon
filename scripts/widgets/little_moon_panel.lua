local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local Spinner = require("widgets/spinner")
local TEMPLATES = require("widgets/redux/templates")

local POSITION_FILE = "dst_little_moon_merged_position"
local PANEL_WIDTH = 300
local PANEL_HEIGHT = 180
local HANDLE_HEIGHT = 30
local DEFAULT_X = 126
local DEFAULT_Y = -150

local GOLD = { 0.89, 0.76, 0.47, 1 }
local LIGHT = { 0.95, 0.92, 0.84, 1 }
local DARK_TEXT = { 0.78, 0.73, 0.63, 0.92 }

local function Clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function ScreenYToTopOffset(y)
    local _, screen_h = TheSim:GetScreenSize()
    return y - screen_h
end

local LittleMoonPanel = Class(Widget, function(self, owner, max_summon, scale)
    Widget._ctor(self, "LittleMoonPanel")

    self.owner = owner
    self.max_summon = max_summon or 50
    self.drag_move_handler = nil
    self.drag_button_handler = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0

    self:SetScale(scale or 1.0)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetVAnchor(ANCHOR_TOP)
    self:SetPosition(DEFAULT_X, DEFAULT_Y, 0)

    -- 背景
    self.background = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.background:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    self.background:SetTint(0.05, 0.05, 0.06, 0.85)
    self.background:SetClickable(false)

    -- 页眉
    self.header = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.header:SetSize(PANEL_WIDTH, HANDLE_HEIGHT)
    self.header:SetTint(0.15, 0.08, 0.05, 0.98)
    self.header:SetPosition(0, PANEL_HEIGHT / 2 - HANDLE_HEIGHT / 2, 0)

    -- 边框
    local function AddBorder(w, h, x, y, tint)
        local b = self:AddChild(Image("images/ui.xml", "white.tex"))
        b:SetSize(w, h)
        b:SetTint(unpack(tint))
        b:SetPosition(x, y, 0)
        b:SetClickable(false)
        return b
    end
    AddBorder(PANEL_WIDTH, 2, 0, PANEL_HEIGHT / 2 - 1, GOLD) -- Top
    AddBorder(PANEL_WIDTH, 2, 0, -PANEL_HEIGHT / 2 + 1, {0.25, 0.20, 0.14, 0.85}) -- Bottom
    AddBorder(2, PANEL_HEIGHT, -PANEL_WIDTH / 2 + 1, 0, {0.25, 0.20, 0.14, 0.85}) -- Left
    AddBorder(2, PANEL_HEIGHT, PANEL_WIDTH / 2 - 1, 0, {0.25, 0.20, 0.14, 0.85}) -- Right

    -- 拖动手柄
    self.handle = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.handle:SetSize(PANEL_WIDTH, HANDLE_HEIGHT)
    self.handle:SetTint(1, 1, 1, 0)
    self.handle:SetPosition(0, PANEL_HEIGHT / 2 - HANDLE_HEIGHT / 2, 0)
    self.handle:SetClickable(true)
    self.handle:SetHoverText("拖动面板")
    self.handle.OnMouseButton = function(_, button, down) return self:OnHandleMouseButton(button, down) end

    self.drag_dots = self.handle:AddChild(Text(CHATFONT, 24, "::: 小月亮助手 :::"))
    self.drag_dots:SetColour(unpack(GOLD))
    self.drag_dots:SetPosition(0, -1, 0)

    -------------------------------------------------------
    -- 第一部分：快捷指令
    -------------------------------------------------------
    self.section1_title = self:AddChild(Text(CHATFONT, 22, "快捷指令"))
    self.section1_title:SetPosition(0, 45, 0)
    self.section1_title:SetColour(unpack(GOLD))

    local btn_w, btn_h = 110, 30
    self.ql_button = self:AddChild(TEMPLATES.StandardButton(function() TheNet:Say("#ql", true) end, "查看宝藏 (#ql)", { btn_w, btn_h }))
    self.ql_button:SetPosition(-65, 10, 0)
    self.ql_button:SetTextSize(16)

    self.cleanup_button = self:AddChild(TEMPLATES.StandardButton(function() TheNet:Say("#cleanup", true) end, "清理掉落 (#clean)", { btn_w, btn_h }))
    self.cleanup_button:SetPosition(65, 10, 0)
    self.cleanup_button:SetTextSize(16)

    -- 分割线
    AddBorder(PANEL_WIDTH - 40, 1, 0, -15, {0.3, 0.3, 0.3, 0.5})

    -------------------------------------------------------
    -- 第二部分：宝藏召唤
    -------------------------------------------------------
    self.section2_title = self:AddChild(Text(CHATFONT, 22, "宝藏点召唤"))
    self.section2_title:SetPosition(0, -35, 0)
    self.section2_title:SetColour(unpack(GOLD))

    -- 数量选择 + 召唤按钮 (同一行)
    local summon_y = -65
    self.selected_count = 1
    local spinner_data = {}
    for _, count in ipairs({1, 5, 10, 20, 50}) do
        if count <= self.max_summon then
            table.insert(spinner_data, { text = tostring(count), data = count })
        end
    end
    if #spinner_data == 0 then table.insert(spinner_data, { text = "1", data = 1 }) end

    self.spinner_root = self:AddChild(Widget("spinner_root"))
    self.spinner_root:SetPosition(-70, summon_y)
    
    self.spinner_label = self.spinner_root:AddChild(Text(CHATFONT, 20, "数量:"))
    self.spinner_label:SetPosition(-45, 0)
    self.spinner_label:SetColour(unpack(LIGHT))

    self.spinner = self.spinner_root:AddChild(Spinner(spinner_data, 75, 28, {font = CHATFONT, size = 20}, nil, nil, nil, true))
    self.spinner:SetTextColour(unpack(LIGHT))
    self.spinner:SetOnChangedFn(function(data) self.selected_count = data end)
    self.spinner:SetPosition(15, 0)

    -- 召唤按钮
    self.btn_summon = self:AddChild(TEMPLATES.StandardButton(function()
        if MOD_RPC["LittleMoon"] and MOD_RPC["LittleMoon"]["Summon"] then
            SendModRPCToServer(MOD_RPC["LittleMoon"]["Summon"], self.selected_count)
        end
    end, "立即召唤", { 100, 32 }))
    self.btn_summon:SetPosition(70, summon_y)
    self.btn_summon:SetTextSize(16)

    self:LoadPosition()
    self:Hide()
end)

function LittleMoonPanel:Toggle()
    if self:IsVisible() then self:Hide() else self:Show(); self:MoveToFront() end
end

-- 拖动逻辑
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
    local min_y = -screen_h + PANEL_HEIGHT / 2
    local max_y = -PANEL_HEIGHT / 2
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
        end
    end)
end

function LittleMoonPanel:OnRemoveEntity()
    self:StopDragging()
end

return LittleMoonPanel
