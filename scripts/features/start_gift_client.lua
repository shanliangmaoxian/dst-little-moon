-- 小月亮 开局礼包（客户端 UI）
-- 物品栏上方"开局礼包"按钮 → 弹窗自选方案（按钮数量随服务端下发的方案列表动态渲染）

local _G = GLOBAL
local CFG = _G.MOON_CFG

if not CFG.ENABLE_START_GIFT then return end

-- ------------------------------------------------------------------
-- 响应 RPC 注册（须在 IsDedicated 判断之前：
-- 专用服务器也要注册，才能填充服务端 CLIENT_MOD_RPC 表用于下发）
-- UI 就绪后通过 _G._moon_gift_ui 回调接入
-- ------------------------------------------------------------------
AddClientModRPCHandler("LittleMoon", "StartGiftPlansResponse", function(json_data)
    if _G.json == nil then return end
    local ok, data = _G.pcall(_G.json.decode, json_data)
    if ok and type(data) == "table" then
        _G._moon_start_gift_data = data
        local h = _G._moon_gift_ui
        if h and h.on_plans then h.on_plans() end
    end
end)

AddClientModRPCHandler("LittleMoon", "ClaimStartGiftResponse", function(json_data)
    if _G.json == nil then return end
    local ok, data = _G.pcall(_G.json.decode, json_data)
    if ok and type(data) == "table" then
        local h = _G._moon_gift_ui
        if h and h.on_claim_response then h.on_claim_response(data.ok, data.plan) end
    end
end)

-- 专用服务器不执行 UI
if _G.TheNet:IsDedicated() then return end

local AddClassPostConstruct = AddClassPostConstruct
local Widget   = _G.require("widgets/widget")
local Image    = _G.require("widgets/image")
local Text     = _G.require("widgets/text")
local TEMPLATES = _G.require("widgets/redux/templates")

local GOLD    = { 0.89, 0.76, 0.47, 1 }
local DARK_BG = { 0.05, 0.05, 0.06, 0.95 }

local popup = nil

-- ------------------------------------------------------------------
-- 弹窗
-- ------------------------------------------------------------------
local function CloseGiftPopup()
    if popup then
        local p = popup
        popup = nil
        _G.pcall(function() p:Kill() end)
    end
end

local function ClaimPlan(plan)
    local data = _G._moon_start_gift_data
    if not data or data.claimed then return end
    if _G.MOD_RPC and _G.MOD_RPC["LittleMoon"] and _G.MOD_RPC["LittleMoon"]["ClaimStartGift"] then
        _G.SendModRPCToServer(_G.MOD_RPC["LittleMoon"]["ClaimStartGift"], plan)
        -- 乐观置灰，防连点；服务端拒绝时由 ClaimStartGiftResponse 回滚
        data.claimed = plan
        RefreshGiftPopup()
    end
end

local function RefreshGiftPopup()
    if not popup then return end
    local data = _G._moon_start_gift_data
    local claimed_plan = data and data.claimed or false
    for _, btn in ipairs(popup.plan_buttons or {}) do
        btn:SetClickable(not claimed_plan)
    end
    if popup.status_text then
        if claimed_plan then
            local label = data.labels and data.labels[claimed_plan] or claimed_plan
            popup.status_text:SetString("已领取：" .. tostring(label))
        else
            popup.status_text:SetString("选择你要的开局礼包：")
        end
    end
end

local function OpenGiftPopup()
    local data = _G._moon_start_gift_data
    if not data or type(data.plans) ~= "table" or #data.plans == 0 then return end
    if not (_G.ThePlayer and _G.ThePlayer.HUD and _G.ThePlayer.HUD.controls) then return end

    CloseGiftPopup()

    local controls = _G.ThePlayer.HUD.controls
    local root = controls:AddChild(Widget("moon_start_gift_popup"))
    root:SetHAnchor(_G.ANCHOR_MIDDLE)
    root:SetVAnchor(_G.ANCHOR_MIDDLE)

    local W = 340
    local H = 120 + #data.plans * 46

    -- 背景
    local bg = root:AddChild(Image("images/ui.xml", "white.tex"))
    bg:SetSize(W, H)
    bg:SetTint(unpack(DARK_BG))
    bg:SetClickable(false)

    -- 标题
    local title = root:AddChild(Text(_G.CHATFONT, 22, "开局礼包"))
    title:SetPosition(0, H / 2 - 24, 0)
    title:SetColour(unpack(GOLD))
    if title.EnableOutline then title:EnableOutline(true) end

    -- 状态文字
    local status = root:AddChild(Text(_G.CHATFONT, 18, ""))
    status:SetPosition(0, H / 2 - 54, 0)
    status:SetColour(1, 1, 1, 1)

    -- 方案按钮
    local plan_buttons = {}
    local y = H / 2 - 86
    for _, plan in ipairs(data.plans) do
        local label = data.labels and data.labels[plan] or plan
        local btn = root:AddChild(TEMPLATES.StandardButton(function() ClaimPlan(plan) end, label, { 200, 40 }))
        btn:SetPosition(0, y, 0)
        btn:SetTextSize(20)
        table.insert(plan_buttons, btn)
        y = y - 46
    end

    -- 关闭按钮
    local close_btn = root:AddChild(TEMPLATES.StandardButton(function() CloseGiftPopup() end, "关闭", { 100, 30 }))
    close_btn:SetPosition(0, -H / 2 + 22, 0)
    close_btn:SetTextSize(18)

    popup = root
    popup.plan_buttons = plan_buttons
    popup.status_text = status

    RefreshGiftPopup()
end

-- UI 回调接入（在响应 RPC 注册之后定义，闭包内可引用本文件局部函数）
_G._moon_gift_ui = {
    on_plans = function()
        OpenGiftPopup()
    end,
    on_claim_response = function(ok, plan)
        local data = _G._moon_start_gift_data
        if data and not ok and data.claimed == plan then
            data.claimed = nil -- 回滚乐观置灰
            RefreshGiftPopup()
        end
    end,
}

-- ------------------------------------------------------------------
-- 物品栏上方"开局礼包"按钮（与"快捷换装" y=210 错开）
-- ------------------------------------------------------------------
AddClassPostConstruct("widgets/inventorybar", function(self)
    if not self.owner then return end

    local TextButton = _G.require("widgets/textbutton")
    local btn = self:AddChild(TextButton())
    btn:SetFont(_G.BODYTEXTFONT)
    btn:SetTextSize(32)
    btn:SetTextColour({ 254 / 255, 255 / 255, 0 / 255, 1 })
    btn:SetTextFocusColour({ 254 / 255, 255 / 255, 0 / 255, 1 })
    btn:SetText("开局礼包")
    btn:SetTooltip("自选领取一次开局礼包")
    btn:SetPosition(0, 250, 0)
    btn:MoveToFront()

    btn:SetOnClick(function()
        if _G.MOD_RPC and _G.MOD_RPC["LittleMoon"] and _G.MOD_RPC["LittleMoon"]["GetStartGiftPlans"] then
            _G.SendModRPCToServer(_G.MOD_RPC["LittleMoon"]["GetStartGiftPlans"])
        end
    end)

    self._moon_start_gift_btn = btn
end)
