local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local HealthBar = Class(Widget, function(self, target)
    Widget._ctor(self, "HealthBar")
    self.target = target

    self:SetClickable(false)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- 背景
    self.bg = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.bg:SetSize(80, 10)
    self.bg:SetTint(0, 0, 0, 0.6)

    -- 血条
    self.fill = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.fill:SetSize(78, 8)
    self.fill:SetTint(0, 0.8, 0, 0.8)
    self.fill:SetPosition(0, 0)

    -- 文字
    self.text = self:AddChild(Text(CHATFONT, 18))
    self.text:SetPosition(0, 15)
    self.text:SetScale(0.8)

    self:Hide()
    self:StartUpdating()
end)

function HealthBar:OnUpdate()
    if not self.target or not self.target:IsValid() then
        self:Kill()
        return
    end

    local health = self.target.replica.health
    if not health or health:IsDead() then
        self:Hide()
        return
    end

    -- 1. 更新血量数值和比例 (这个可以稍微降低频率，但这里为了逻辑清晰先放这)
    local percent = health:GetPercent()
    self.fill:SetSize(78 * percent, 8)
    self.fill:SetPosition(-(78 * (1 - percent)) / 2, 0)

    local cur = math.ceil(health:GetCurrent())
    local max = math.ceil(health:Max())
    self.text:SetString(string.format("%d / %d", cur, max))

    -- 动态颜色
    if percent > 0.6 then
        self.fill:SetTint(0, 0.8, 0, 0.8)
    elseif percent > 0.3 then
        self.fill:SetTint(0.8, 0.8, 0, 0.8)
    else
        self.fill:SetTint(0.8, 0, 0, 0.8)
    end

    -- 2. 平滑更新位置 (每帧执行)
    local x, y, z = self.target.Transform:GetWorldPosition()
    local scr_x, scr_y = TheSim:GetScreenPos(x, y + 2.5, z)
    
    -- 简单的视口裁剪：如果坐标在屏幕外太远则隐藏
    local screen_w, screen_h = TheSim:GetScreenSize()
    if scr_x < -100 or scr_x > screen_w + 100 or scr_y < -100 or scr_y > screen_h + 100 then
        self:Hide()
    else
        self:SetPosition(scr_x, scr_y)
        self:Show()
    end
end

return HealthBar
