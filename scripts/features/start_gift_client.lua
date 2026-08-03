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
        rawset(_G, "_moon_start_gift_data", data)
        local h = rawget(_G, "_moon_gift_ui")
        if h and h.on_plans then h.on_plans() end
    end
end)

AddClientModRPCHandler("LittleMoon", "ClaimStartGiftResponse", function(json_data)
    if _G.json == nil then return end
    local ok, data = _G.pcall(_G.json.decode, json_data)
    if ok and type(data) == "table" then
        local h = rawget(_G, "_moon_gift_ui")
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

local function RefreshGiftPopup()
    if not popup then return end
    local data = rawget(_G, "_moon_start_gift_data")
    local claimed_plan = data and data.claimed or false

    -- 对号按钮：已领取则置灰禁用
    for i, row in ipairs(popup.rows or {}) do
        local check = popup.checks and popup.checks[i]
        if check then
            if claimed_plan then
                check:SetText("已领取")
                check:SetClickable(false)
            else
                check:SetText("领取")
                check:SetClickable(true)
            end
        end
    end

    -- 状态文字
    if popup.status_text then
        if claimed_plan then
            local label = data.labels and data.labels[claimed_plan] or claimed_plan
            popup.status_text:SetString("已领取：" .. tostring(label))
        else
            popup.status_text:SetString("点击对号领取对应礼包")
        end
    end
end

local function ClaimPlan(plan)
    local data = rawget(_G, "_moon_start_gift_data")
    if not data or data.claimed then return end
    if _G.MOD_RPC and _G.MOD_RPC["LittleMoon"] and _G.MOD_RPC["LittleMoon"]["ClaimStartGift"] then
        _G.SendModRPCToServer(_G.MOD_RPC["LittleMoon"]["ClaimStartGift"], plan)
        -- 乐观置灰，防连点；服务端拒绝时由 ClaimStartGiftResponse 回滚
        data.claimed = plan
        RefreshGiftPopup()
    end
end

local function OpenGiftPopup()
    local data = rawget(_G, "_moon_start_gift_data")
    if not data or type(data.plans) ~= "table" or #data.plans == 0 then return end
    if not (_G.ThePlayer and _G.ThePlayer.HUD and _G.ThePlayer.HUD.controls) then return end

    CloseGiftPopup()

    local controls = _G.ThePlayer.HUD.controls
    local root = controls:AddChild(Widget("moon_start_gift_popup"))
    -- 居中弹窗（面板风格），待办列表样式：每行方案名 + 内容简述 + 对号领取按钮
    root:SetHAnchor(_G.ANCHOR_MIDDLE)
    root:SetVAnchor(_G.ANCHOR_MIDDLE)

    -- 行数据
    local rows = {}
    for _, plan in ipairs(data.plans) do
        local label = data.labels and data.labels[plan] or plan
        local descs = {}
        local items = data.contents and data.contents[plan] or {}
        for _, it in ipairs(items) do
            local name = it.prefab
            if _G.STRINGS and _G.STRINGS.NAMES and _G.STRINGS.NAMES[string.upper(it.prefab)] then
                name = _G.STRINGS.NAMES[string.upper(it.prefab)]
            end
            local desc = string.format("%s x%d", name, it.count)
            if it.role and it.role ~= "all" then
                desc = desc .. "(" .. it.role .. ")"
            end
            table.insert(descs, desc)
        end
        table.insert(rows, { plan = plan, label = label, desc = table.concat(descs, "、") })
    end

    local W = 480
    local H = 96 + #rows * 44 + 46

    -- 背景
    local bg = root:AddChild(Image("images/ui.xml", "white.tex"))
    bg:SetSize(W, H)
    bg:SetTint(unpack(DARK_BG))
    bg:SetClickable(false)

    -- 四周边框（面板风格，金色顶线）
    local border_top = root:AddChild(Image("images/ui.xml", "white.tex"))
    border_top:SetSize(W, 1)
    border_top:SetTint(unpack(GOLD))
    border_top:SetPosition(0, H / 2, 0)
    border_top:SetClickable(false)

    local border_bottom = root:AddChild(Image("images/ui.xml", "white.tex"))
    border_bottom:SetSize(W, 1)
    border_bottom:SetTint(unpack({ 0.25, 0.20, 0.14, 0.85 }))
    border_bottom:SetPosition(0, -H / 2, 0)
    border_bottom:SetClickable(false)

    local border_left = root:AddChild(Image("images/ui.xml", "white.tex"))
    border_left:SetSize(1, H)
    border_left:SetTint(unpack({ 0.25, 0.20, 0.14, 0.85 }))
    border_left:SetPosition(-W / 2, 0, 0)
    border_left:SetClickable(false)

    local border_right = root:AddChild(Image("images/ui.xml", "white.tex"))
    border_right:SetSize(1, H)
    border_right:SetTint(unpack({ 0.25, 0.20, 0.14, 0.85 }))
    border_right:SetPosition(W / 2, 0, 0)
    border_right:SetClickable(false)

    -- 标题
    local title = root:AddChild(Text(_G.CHATFONT, 22, "开局礼包,只能领取一次！！！"))
    title:SetPosition(0, H / 2 - 24, 0)
    title:SetColour(unpack(GOLD))
    if title.EnableOutline then title:EnableOutline(true) end

    -- 状态文字
    local status = root:AddChild(Text(_G.CHATFONT, 16, ""))
    status:SetPosition(0, H / 2 - 52, 0)
    status:SetColour(1, 1, 1, 0.8)

    -- 方案行（待办列表样式）
    local checks = {}
    local y = H / 2 - 80
    for i, row in ipairs(rows) do
        -- 行分隔线（第一行上方不画）
        if i > 1 then
            local line = root:AddChild(Image("images/ui.xml", "white.tex"))
            line:SetSize(W - 40, 1)
            line:SetTint(unpack({ 0.25, 0.20, 0.14, 0.5 }))
            line:SetPosition(0, y + 24, 0)
            line:SetClickable(false)
        end

        -- 方案名
        local name = root:AddChild(Text(_G.CHATFONT, 20, row.label))
        name:SetPosition(-W / 2 + 72, y, 0)
        name:SetColour(unpack(GOLD))
        if name.EnableOutline then name:EnableOutline(true) end

        -- 内容简述（单行截断）
        local desc = root:AddChild(Text(_G.CHATFONT, 16, ""))
        desc:SetMultilineTruncatedString(row.desc ~= "" and row.desc or "（无物品）", 1, 240)
        desc:SetPosition(-W / 2 + 215, y, 0)
        desc:SetColour(1, 1, 1, 0.8)

        -- 领取按钮（未领取显示"领取"，领取后显示"已领取"并禁用）
        local check = root:AddChild(TEMPLATES.StandardButton(function() ClaimPlan(row.plan) end, "领取", { 90, 34 }))
        check:SetPosition(W / 2 - 55, y, 0)
        check:SetTextSize(18)
        check:SetHoverText("领取" .. row.label, { offset_y = 24 })
        table.insert(checks, check)

        y = y - 44
    end

    -- 关闭按钮
    local close_btn = root:AddChild(TEMPLATES.StandardButton(function() CloseGiftPopup() end, "关闭", { 100, 30 }))
    close_btn:SetPosition(0, -H / 2 + 22, 0)
    close_btn:SetTextSize(18)

    popup = root
    popup.rows = rows
    popup.checks = checks
    popup.status_text = status

    RefreshGiftPopup()
end

-- UI 回调接入（在响应 RPC 注册之后定义，闭包内可引用本文件局部函数）
rawset(_G, "_moon_gift_ui", {
    on_plans = function()
        OpenGiftPopup()
    end,
    on_claim_response = function(ok, plan)
        local data = rawget(_G, "_moon_start_gift_data")
        if data and not ok and data.claimed == plan then
            data.claimed = nil -- 回滚乐观置灰
            RefreshGiftPopup()
        end
    end,
})

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
