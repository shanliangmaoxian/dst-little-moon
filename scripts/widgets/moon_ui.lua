local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local Spinner = require "widgets/spinner" -- 引入选择器组件
local TEMPLATES = require "widgets/redux/templates"

local Moon_UI = Class(Widget, function(self)
    Widget._ctor(self, "Moon_UI")
    
    self.root = self:AddChild(Widget("root"))
    self.frame = self.root:AddChild(Widget("frame"))
    self.frame:SetPosition(TheSim:GetScreenSize() / 2, TheSim:GetScreenSize() / 2.5)

    -- 背景
    local bg = self.frame:AddChild(Image("images/quagmire_recipebook.xml", "quagmire_recipe_menu_bg.tex"))
    bg:ScaleToSize(550, 480)

    -- 标题
    self.title = self.frame:AddChild(Text(HEADERFONT, 45, "小月亮宝藏面板", UICOLOURS.BROWN_DARK))
    self.title:SetPosition(0, 180)

    -- 宝藏点图标
    self.icon = self.frame:AddChild(Image("images/inventoryimages.xml", "moonglass.tex"))
    self.icon:SetScale(1.8)
    self.icon:SetPosition(0, 60)

    -- 描述
    self.desc = self.frame:AddChild(Text(HEADERFONT, 28, "点击按钮开启宝藏点\n需要消耗：寻宝卷轴 x 1/个", UICOLOURS.BROWN_DARK))
    self.desc:SetPosition(0, -40)

    -- 数量选择器
    self.selected_count = 1
    local spinner_data = {
        { text = "1", data = 1 },
        { text = "5", data = 5 },
        { text = "10", data = 10 },
        { text = "20", data = 20 },
        { text = "50", data = 50 },
    }
    
    self.spinner = self.frame:AddChild(self:MakeSpinner("召唤数量:", spinner_data, function(data)
        self.selected_count = data
    end))
    self.spinner:SetPosition(0, -110)

    -- 召唤按钮
    self.btn_summon = self.frame:AddChild(TEMPLATES.StandardButton(function()
        if MOD_RPC["LittleMoon"]["Summon"] then
            SendModRPCToServer(MOD_RPC["LittleMoon"]["Summon"], self.selected_count)
        end
    end, "召唤宝藏点", { 200, 60 }))
    self.btn_summon:SetPosition(0, -180)

    -- 关闭按钮
    self.btn_close = self.frame:AddChild(TEMPLATES.StandardButton(function() self:Hide() end, "关闭", { 100, 50 }))
    self.btn_close:SetPosition(210, 210)

    self:Hide()
end)

-- 简单的 Spinner 构造方法
function Moon_UI:MakeSpinner(labeltext, spinnerdata, onchanged_fn)
    local wdg = Widget("labelspinner")
    wdg.label = wdg:AddChild(Text(HEADERFONT, 24, labeltext))
    wdg.label:SetPosition(-80, 0)
    wdg.label:SetColour(UICOLOURS.BROWN_DARK)

    wdg.spinner = wdg:AddChild(Spinner(spinnerdata, 120, 30, {font = HEADERFONT, size = 24}, nil, "images/quagmire_recipebook.xml", nil, true))
    wdg.spinner:SetTextColour(UICOLOURS.BROWN_DARK)
    wdg.spinner:SetOnChangedFn(onchanged_fn)
    wdg.spinner:SetPosition(40, 0)
    
    return wdg
end

function Moon_UI:Toggle()
    if self:IsVisible() then self:Hide() else self:Show() end
end

return Moon_UI
