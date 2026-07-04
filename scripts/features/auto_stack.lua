-- 小月亮 掉落自动堆叠 + 堆叠上限 + 更多堆叠
-- 参考 3253273657_下划线

local _G = GLOBAL
local CFG = GLOBAL.MOON_CFG

if not CFG.ENABLE_AUTO_STACK and not CFG.STACK_SIZE_MULTIPLIER then return end

-- 冲突检测：如果下划线(3253273657)或其他堆叠模组已加载，跳过避免双重生效
if GLOBAL.KnownModIndex and GLOBAL.KnownModIndex:IsModEnabled("workshop-3253273657") then return end

-- ============================================================
-- 1. 堆叠上限修改 (TUNING)
-- ============================================================
if CFG.STACK_SIZE_MULTIPLIER and type(CFG.STACK_SIZE_MULTIPLIER) == "number" then
    local new_size = CFG.STACK_SIZE_MULTIPLIER
    local keys = {
        "STACK_SIZE_MEDITEM",
        "STACK_SIZE_SMALLITEM",
        "STACK_SIZE_LARGEITEM",
        "STACK_SIZE_TINYITEM",
        "STACK_SIZE_PELLET",
    }
    for _, key in ipairs(keys) do
        if TUNING[key] then
            TUNING[key] = new_size
        end
    end

    -- ============================================================
    -- 2. Client: stackable_replica 显示修正
    -- ============================================================
    local stackable_replica = _G.require("components/stackable_replica")

    stackable_replica.MaxSize = function(self)
        return new_size
    end

    stackable_replica.SetMaxSize = function(self, maxsize)
        self._maxsize:set(new_size)
    end

    -- ponytail: guard nil net_var during LIMBO state
    local _old_IsOverStacked = stackable_replica.IsOverStacked
    stackable_replica.IsOverStacked = function(self)
        local stacksize = self._stacksize:value()
        if stacksize == nil then return false end
        return stacksize > self:MaxSize()
    end
end

-- ============================================================
-- 3. 更多堆叠 (服务端)
-- ============================================================
if CFG.ENABLE_MORE_STACKING and CFG.STACK_SIZE_MULTIPLIER then
    local STACKABLE_CREATURES = {
        shadowheart = true,
        shadowheart_infused = true,
        eyeturret_item = true,
        glommerwings = true,
        horn = true,
        tallbirdegg = true,
        tallbirdegg_cracked = true,
        lavae_egg = true,
        lavae_egg_cracked = true,
        gelblob_storage_kit = true,
        reviver = true,
    }

    local STACKABLE_TAGS = {
        bird = true,
        smallcreature = true,
    }

    local function OnDropped(inst)
        if inst.brain then
            inst.brain:Start()
        end

        local core_stack = inst.components.stackable
        if core_stack and core_stack:IsStack() then
            local x, y, z = inst.Transform:GetWorldPosition()
            while core_stack:IsStack() do
                local item = core_stack:Get()
                if item then
                    if item.components.inventoryitem then
                        item.components.inventoryitem:OnDropped()
                    end
                    if item.Physics then
                        item.Physics:Teleport(x, y, z)
                    end
                end
            end
        end
    end

    local function AddStackableIfNeeded(inst)
        if not _G.TheWorld.ismastersim then return end
        if not inst.components.inventoryitem or inst.components.equippable then return end

        local should_add = false
        local needs_special_drop = false

        if STACKABLE_CREATURES[inst.prefab] then
            should_add = true
        else
            for tag in pairs(STACKABLE_TAGS) do
                if inst:HasTag(tag) then
                    should_add = true
                    needs_special_drop = true
                    break
                end
            end
        end

        if should_add and not inst.components.stackable then
            inst:AddComponent("stackable")
            inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM
        end

        if CFG.ENABLE_MORE_STACKING == 2 and needs_special_drop and inst.components.inventoryitem then
            local original_ondrop = inst.components.inventoryitem.ondropfn
            inst.components.inventoryitem.ondropfn = function(inst)
                if original_ondrop then original_ondrop(inst) end
                OnDropped(inst)
            end
        end
    end

    AddPrefabPostInitAny(AddStackableIfNeeded)
end

-- ============================================================
-- 4. 掉落自动堆叠 (服务端)
-- ============================================================
if not CFG.ENABLE_AUTO_STACK then return end

local STACK_RADIUS = 20
local FILTER_TAGS = { "smallcreature", "heavy", "trap", "NET_workable" }
local EXCLUDE_TAGS = { "INLIMBO", "NOCLICK", "lootpump_oncatch", "lootpump_onflight" }
local SPECIAL_FILTER = {
    poop = { tags = { "beefalo", "koalefant" }, radius = 30 },
    bird_egg = { tags = { "penguin" }, radius = 12 },
}

-- 周边可堆叠物品查找
local function FindStackables(x, y, z)
    return TheSim:FindEntities(x, y, z, STACK_RADIUS, { "_stackable" }, EXCLUDE_TAGS)
end

-- 物品状态校验
local function IsInvalid(inst)
    return not inst:IsValid() or not inst.components.stackable or inst:IsInLimbo() or inst:HasTag("NOCLICK")
end

-- 特殊场景过滤
local function ShouldSkipScene(inst, x, y, z)
    local cfg = SPECIAL_FILTER[inst.prefab]
    if not cfg then return false end
    return TheSim:CountEntities(x, y, z, cfg.radius, cfg.tags) > 0
end

-- 执行堆叠
local function DoStack(inst, item, source_pos)
    if IsInvalid(inst) or IsInvalid(item) then return end
    if item ~= inst and item.prefab == inst.prefab and item.skinname == inst.skinname then
        inst.components.stackable:Put(item, source_pos)
    end
end

-- 自动堆叠主逻辑
local function StackMainLogic(inst)
    if IsInvalid(inst) then return end

    local x, y, z = inst.Transform:GetWorldPosition()
    local source_pos = { x = x, y = y, z = z }

    if ShouldSkipScene(inst, x, y, z) then return end

    local stackable = inst.components.stackable
    if stackable:IsFull() then return end

    inst.I_stack_locking = true
    local nearby = FindStackables(x, y, z)
    if not next(nearby) then
        inst.I_stack_locking = nil
        return
    end

    for _, item in ipairs(nearby) do
        if item ~= inst
            and not rawget(item, "I_stack_locking")
            and not IsInvalid(item)
            and not item.components.stackable:IsFull() then

            DoStack(inst, item, source_pos)
            if stackable:IsFull() or not inst:IsValid() then
                break
            end
        end
    end

    inst.I_stack_locking = nil
end

-- 清理 task（物品被捡起时取消待执行的堆叠任务）
AddComponentPostInit("stackable", function(Stackable)
    local _Get = Stackable.Get
    Stackable.Get = function(self, ...)
        local item = _Get(self, ...)
        if rawget(item, "I_stack_task") then
            item.I_stack_task:Cancel()
            item.I_stack_task = nil
        end
        return item
    end
end)

-- 物品生成时触发自动堆叠
AddPrefabPostInitAny(function(inst)
    if not _G.TheWorld.ismastersim then return end

    for _, tag in ipairs(FILTER_TAGS) do
        if inst:HasTag(tag) then return end
    end

    if IsInvalid(inst) then return end

    inst.I_stack_task = inst:DoTaskInTime(0, function()
        StackMainLogic(inst)
    end)
end)
