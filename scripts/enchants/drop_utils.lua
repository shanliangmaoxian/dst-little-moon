-- 小月亮 附魔掉落工具
-- 精英/Boss 死亡时按概率掉落附魔石

local _G = GLOBAL

-- 精英/Boss 掉落附魔石通用逻辑
-- @param enchant_id: 附魔石 ID (如 "Legend_MX_HEALTH")
-- @param drop_chance: 掉落概率 (默认 3%)
function _G.Moon_RegisterEnchantDrop(enchant_id, drop_chance)
    local chance = drop_chance or 0.03
    AddPrefabPostInitAny(function(inst)
        if not GLOBAL.TheWorld.ismastersim then return end
        if not inst:HasTag("epic") then return end
        inst:ListenForEvent("death", function(inst, data)
            if math.random() > chance then return end
            local stone = GLOBAL.HHSpawnStoneById(enchant_id)
            if stone then
                local pt = inst:GetPosition()
                local killer = data and data.afflicter
                if killer and killer:IsValid() and killer.components.inventory then
                    killer.components.inventory:GiveItem(stone, nil, pt)
                else
                    stone.Transform:SetPosition(pt:Get())
                end
            end
        end)
    end)
end
