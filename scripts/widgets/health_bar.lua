local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local HealthBar = Class(Widget, function(self, target, show_num)
    Widget._ctor(self, "HealthBar")
    self.target = target
    self.show_num = show_num

    self:SetClickable(false)

    -- 背景
    self.bg = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.bg:SetSize(80, 10)
    self.bg:SetTint(0, 0, 0, 0.6)

    -- 血条
    self.bar = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.bar:SetSize(78, 8)
    self.bar:SetTint(0, 0.8, 0, 0.8)
    self.bar:SetPosition(0, 0)

    -- 文字
    if self.show_num then
        self.text = self:AddChild(Text(NUMBERFONT, 18))
        self.text:SetPosition(0, 12)
    end

    self:Hide()
    self:StartUpdating()
end)

function HealthBar:OnUpdate(dt)
    if not self.target or not self.target:IsValid() then
        self:Hide()
        return
    end

    local health = self.target.replica and self.target.replica.health
    if not health or health:IsDead() then
        self:Hide()
        return
    end

    -- 更新血量比例
    local percent = health:GetPercent() or 0
    percent = math.min(math.max(percent, 0), 1)
    self.bar:SetSize(78 * percent, 8)
    self.bar:SetPosition(-(78 * (1 - percent)) / 2, 0)

    -- 更新文字
    if self.show_num and self.text then
        local cur = math.ceil(health:GetCurrent() or 0)
        local max = math.ceil(health:Max() or 0)
        self.text:SetString(string.format("%d/%d", cur, max))
    end

    -- 动态颜色: 绿 -> 黄 -> 红
    if percent > 0.6 then
        self.bar:SetTint(0, 0.8, 0, 0.8)
    elseif percent > 0.3 then
        self.bar:SetTint(0.8, 0.8, 0, 0.8)
    else
        self.bar:SetTint(0.8, 0, 0, 0.8)
    end

    -- 更新位置 (参照 SimpleHealthBar 的做法)
    local pos = self.target:GetPosition()
    if pos then
        local x, y, z = pos:Get()
        local scr_x, scr_y = TheSim:GetScreenPos(x, y + 2.5, z)

        local screen_w, screen_h = TheSim:GetScreenSize()
        if scr_x > -100 and scr_x < screen_w + 100 and scr_y > -100 and scr_y < screen_h + 100 then
            self:SetPosition(scr_x, scr_y, 0)
            self:Show()
        else
            self:Hide()
        end
    end
end

return HealthBar
