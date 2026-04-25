local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")

local POSITION_FILE = "dst_ql_helper_position_v2"
local PANEL_HEIGHT = 110 -- 146 -> 110 压缩高度
local HANDLE_HEIGHT = 28 -- 36 -> 28 压缩手柄
local DEFAULT_X = 126
local DEFAULT_Y = -96
local GOLD = { 0.89, 0.76, 0.47, 1 }
local LIGHT = { 0.95, 0.92, 0.84, 1 }

local function Clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function ScreenYToTopOffset(y)
    local _, screen_h = TheSim:GetScreenSize()
    return y - screen_h
end

local QLCleanupPanel = Class(Widget, function(self, owner, panel_width)
    Widget._ctor(self, "QLCleanupPanel")

    self.owner = owner
    self.panel_width = panel_width or 300
    self.drag_move_handler = nil
    self.drag_button_handler = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0

    self:SetHAnchor(ANCHOR_LEFT)
    self:SetVAnchor(ANCHOR_TOP)
    self:SetPosition(DEFAULT_X, DEFAULT_Y, 0)

    self.background = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.background:SetSize(self.panel_width, PANEL_HEIGHT)
    self.background:SetTint(0.07, 0.07, 0.08, 0.72)
    self.background:SetClickable(false)

    self.header = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.header:SetSize(self.panel_width, HANDLE_HEIGHT)
    self.header:SetTint(0.17, 0.10, 0.07, 0.96)
    self.header:SetPosition(0, PANEL_HEIGHT / 2 - HANDLE_HEIGHT / 2, 0)
    self.header:SetClickable(false)

    self.border_top = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.border_top:SetSize(self.panel_width, 2)
    self.border_top:SetTint(unpack(GOLD))
    self.border_top:SetPosition(0, PANEL_HEIGHT / 2 - 1, 0)
    self.border_top:SetClickable(false)

    self.border_bottom = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.border_bottom:SetSize(self.panel_width, 2)
    self.border_bottom:SetTint(0.25, 0.20, 0.14, 0.85)
    self.border_bottom:SetPosition(0, -PANEL_HEIGHT / 2 + 1, 0)
    self.border_bottom:SetClickable(false)

    self.border_left = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.border_left:SetSize(2, PANEL_HEIGHT)
    self.border_left:SetTint(0.25, 0.20, 0.14, 0.85)
    self.border_left:SetPosition(-self.panel_width / 2 + 1, 0, 0)
    self.border_left:SetClickable(false)

    self.border_right = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.border_right:SetSize(2, PANEL_HEIGHT)
    self.border_right:SetTint(0.25, 0.20, 0.14, 0.85)
    self.border_right:SetPosition(self.panel_width / 2 - 1, 0, 0)
    self.border_right:SetClickable(false)

    self.handle = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.handle:SetSize(self.panel_width, HANDLE_HEIGHT)
    self.handle:SetTint(1, 1, 1, 0)
    self.handle:SetPosition(0, PANEL_HEIGHT / 2 - HANDLE_HEIGHT / 2, 0)
    self.handle:SetClickable(true)
    self.handle:SetHoverText("拖动以移动")
    self.handle.OnMouseButton = function(_, button, down)
        return self:OnHandleMouseButton(button, down)
    end

    self.handle_label = self.handle:AddChild(Text(CHATFONT, 24, "拖动")) -- 32 -> 24
    self.handle_label:SetColour(0.80, 0.67, 0.45, 0.95)
    self.handle_label:SetPosition(self.panel_width / 2 - 40, -1, 0)
    self.handle_label:SetClickable(false)

    self.drag_dots = self.handle:AddChild(Text(CHATFONT, 28, ":::")) -- 36 -> 28
    self.drag_dots:SetColour(unpack(GOLD))
    self.drag_dots:SetPosition(-self.panel_width / 2 + 30, -1, 0)
    self.drag_dots:SetClickable(false)

    self.title = self:AddChild(Text(CHATFONT, 32, "小月亮快捷指令")) -- 36 -> 32
    self.title:SetPosition(0, 32, 0) -- 24 -> 32 上移
    self.title:SetClickable(false)

    self.subtitle = self:AddChild(Text(CHATFONT, 22, "点击直接发送指令")) -- 28 -> 22
    self.subtitle:SetColour(0.78, 0.73, 0.63, 0.92)
    self.subtitle:SetPosition(0, 4, 0) -- -6 -> 4 上移
    self.subtitle:SetClickable(false)

    local button_spacing = 24 -- 32 -> 24
    local ql_w, cleanup_w = 80, 120 -- 100, 152 -> 80, 120
    local total_buttons_w = ql_w + cleanup_w + button_spacing
    local start_x = -total_buttons_w / 2

    self.ql_button = self:AddChild(self:MakeCommandButton("QL", { ql_w, 32 }, "#ql")) -- 高度 38 -> 32
    self.ql_button:SetPosition(start_x + ql_w / 2, -30, 0) -- -36 -> -30 上移
    self.ql_button:SetHoverText("#ql")

    self.cleanup_button = self:AddChild(self:MakeCommandButton("CLEANUP", { cleanup_w, 32 }, "#cleanup")) -- 高度 38 -> 32
    self.cleanup_button:SetPosition(start_x + ql_w + button_spacing + cleanup_w / 2, -30, 0) -- -36 -> -30 上移
    self.cleanup_button:SetHoverText("#cleanup")

    self:LoadPosition()
end)

function QLCleanupPanel:MakeCommandButton(label, size, command)
    local button = TEMPLATES.StandardButton(function()
        self:SendChatCommand(command)
    end, label, size)
    button:SetTextSize(18) -- 20 -> 18
    return button
end

function QLCleanupPanel:SendChatCommand(command)
    if command == nil or command == "" then
        return
    end

    TheNet:Say(command, false)
end

function QLCleanupPanel:OnHandleMouseButton(button, down)
    if button ~= MOUSEBUTTON_LEFT then
        return false
    end

    if down then
        self:StartDragging()
    else
        self:StopDragging()
    end

    return true
end

function QLCleanupPanel:StartDragging()
    if self.drag_move_handler ~= nil then
        return
    end

    local mouse_pos = TheInput:GetScreenPosition()
    local panel_x, panel_y = self:GetPositionXYZ()

    self.drag_offset_x = panel_x - mouse_pos.x
    self.drag_offset_y = panel_y - ScreenYToTopOffset(mouse_pos.y)

    self:MoveToFront()
    self.drag_move_handler = TheInput:AddMoveHandler(function(x, y)
        self:UpdateDragPosition(x, y)
    end)
    self.drag_button_handler = TheInput:AddMouseButtonHandler(function(button_id, is_down)
        if button_id == MOUSEBUTTON_LEFT and not is_down then
            self:StopDragging()
        end
    end)

    self:UpdateDragPosition(mouse_pos.x, mouse_pos.y)
end

function QLCleanupPanel:UpdateDragPosition(mouse_x, mouse_y)
    self:SetClampedPosition(
        mouse_x + self.drag_offset_x,
        ScreenYToTopOffset(mouse_y) + self.drag_offset_y
    )
end

function QLCleanupPanel:SetClampedPosition(x, y)
    local screen_w, screen_h = TheSim:GetScreenSize()
    local min_x = self.panel_width / 2
    local max_x = screen_w - self.panel_width / 2
    local min_y = -screen_h + PANEL_HEIGHT / 2
    local max_y = -PANEL_HEIGHT / 2

    self:SetPosition(
        Clamp(x, min_x, max_x),
        Clamp(y, min_y, max_y),
        0
    )
end

function QLCleanupPanel:StopDragging()
    if self.drag_move_handler ~= nil then
        self.drag_move_handler:Remove()
        self.drag_move_handler = nil
    end

    if self.drag_button_handler ~= nil then
        self.drag_button_handler:Remove()
        self.drag_button_handler = nil
    end

    local x, y = self:GetPositionXYZ()
    if json ~= nil then
        TheSim:SetPersistentString(POSITION_FILE, json.encode({
            x = x,
            y = y,
        }), false)
    end
end

function QLCleanupPanel:LoadPosition()
    if json == nil then
        return
    end

    TheSim:GetPersistentString(POSITION_FILE, function(success, data)
        if not success or data == nil or data == "" then
            return
        end

        local ok, pos = pcall(json.decode, data)
        if ok and pos ~= nil and pos.x ~= nil and pos.y ~= nil then
            self:SetClampedPosition(pos.x, pos.y)
        else
            self:SetClampedPosition(DEFAULT_X, DEFAULT_Y)
        end
    end)
end

function QLCleanupPanel:OnRemoveEntity()
    self:StopDragging()
end

return QLCleanupPanel
