-- Vitality / Anime Dice / 1.0.0-LS
-- Based on the supplied Auto Roll Suite v17. The main loader owns the window.
return function(context)
    assert(type(context) == "table", "Anime Dice requires the Vitality module context")
    local Library = assert(context.Library or context.NovaField, "Vitality library missing")
    local Window = assert(context.Window, "Vitality window missing")
    assert(type(Window.CreateTabDropdown) == "function" and type(Window.AddCleanup) == "function",
        "Anime Dice requires the supplied Vitality library with dropdown tabs and cleanup")
    local KEY = "__VITALITY_ANIME_DICE_LS"
    local previous = rawget(_G, KEY)
    if previous and previous.Window == Window and previous.Alive and previous.Ready then return true end
    if previous and type(previous.Restore) == "function" then previous.Restore() end

    local scheduler = task
    local runtime = {Window = Window, Alive = true, Ready = false, Threads = {}, Connections = {}}
    local function disconnect(item)
        if type(item) == "function" then pcall(item)
        elseif item then
            pcall(function()
                if item.Disconnect then item:Disconnect()
                elseif item.Destroy then item:Destroy() end
            end)
        end
    end
    local function restore()
        if not runtime.Alive then return end
        runtime.Alive, runtime.Ready = false, false
        if runtime.State then
            for key in pairs(runtime.State) do
                if key:match("^auto") then runtime.State[key] = false end
            end
            runtime.State.skipCutscenes = false
        end
        pcall(function() game:GetService("ContextActionService"):UnbindAction("Vitality_AnimeDice_BlockShiftlock") end)
        for thread in pairs(runtime.Threads) do
            if thread ~= coroutine.running() then pcall(scheduler.cancel, thread) end
        end
        table.clear(runtime.Threads)
        for _, connection in ipairs(runtime.Connections) do disconnect(connection) end
        table.clear(runtime.Connections)
        if runtime.Group then pcall(function() runtime.Group:Destroy() end) end
        if rawget(_G, KEY) == runtime then rawset(_G, KEY, nil) end
    end
    runtime.Restore = restore
    rawset(_G, KEY, runtime)
    Window:AddCleanup(restore)

    -- A module-local scheduler owns loops and delayed work without changing global task.
    local task = {wait = scheduler.wait, cancel = scheduler.cancel}
    local function schedule(mode, delay, callback, ...)
        if not runtime.Alive then return nil end
        local args = table.pack(...)
        local thread = coroutine.create(function()
            if runtime.Alive then
                local ok, err = xpcall(function() callback(table.unpack(args, 1, args.n)) end, debug.traceback)
                if not ok and runtime.Alive then warn("[Vitality Anime Dice] " .. tostring(err)) end
            end
            runtime.Threads[coroutine.running()] = nil
        end)
        runtime.Threads[thread] = true
        if mode == "delay" then scheduler.delay(delay, thread)
        elseif mode == "defer" then scheduler.defer(thread)
        else scheduler.spawn(thread) end
        return thread
    end
    task.spawn = function(callback, ...) return schedule("spawn", 0, callback, ...) end
    task.defer = function(callback, ...) return schedule("defer", 0, callback, ...) end
    task.delay = function(delay, callback, ...) return schedule("delay", delay, callback, ...) end
    local function connect(signal, callback)
        local connection = signal:Connect(function(...)
            if runtime.Alive then task.spawn(callback, ...) end
        end)
        table.insert(runtime.Connections, connection)
        return connection
    end
    local function cancelLoop(field)
        local thread = runtime.State and runtime.State[field]
        if thread then
            pcall(scheduler.cancel, thread)
            runtime.Threads[thread] = nil
            runtime.State[field] = nil
        end
    end

    local function initialize()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================================
-- SHIFTLOCK KILLER
-- ============================================================================
local shiftlockEnabled = true
do
    ContextActionService:BindActionAtPriority(
        "Vitality_AnimeDice_BlockShiftlock",
        function(_, inputState, input)
            if not runtime.Alive or Window._capturingKeybind or UserInputService:GetFocusedTextBox()
                or (input and input.KeyCode == Window.ToggleKey) then return Enum.ContextActionResult.Pass end
            if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
            if not shiftlockEnabled then return Enum.ContextActionResult.Pass end
            return Enum.ContextActionResult.Sink
        end,
        false, Enum.ContextActionPriority.High.Value,
        Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift
    )
    task.spawn(function()
        while runtime.Alive do
            if shiftlockEnabled then
                pcall(function()
                    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    end
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.AutoRotate == false then hum.AutoRotate = true end
                    local mouse = LocalPlayer:GetMouse()
                    if mouse and mouse.Icon ~= "" then mouse.Icon = "" end
                    local fw = ReplicatedStorage:FindFirstChild("Framework")
                    local ctrl = fw and fw:FindFirstChild("Features") and fw.Features:FindFirstChild("Player")
                        and fw.Features.Player:FindFirstChild("ShiftlockController")
                    if ctrl then
                        local ok, inst = pcall(require, ctrl)
                        if ok and type(inst) == "table" and inst.Enabled then
                            inst.Enabled = false
                            if type(inst.ToggleShiftLock) == "function" then
                                pcall(function() inst:ToggleShiftLock(false) end)
                            end
                        end
                    end
                end)
            end
            task.wait(0.1)
        end
    end)
end

-- ============================================================================
-- FRAMEWORK WAIT
-- ============================================================================
local FrameworkModule = ReplicatedStorage:WaitForChild("Framework", 30)
assert(FrameworkModule, "Anime Dice Framework missing; open the Anime Dice experience before loading this module")
do
    local ok, res = pcall(function() return require(FrameworkModule) end)
    if ok and type(res) == "table" and res.Wait then
        if not res.IsLoaded() then res.Wait() end
    end
end
print("[AutoRoll] Framework ready.")

-- ============================================================================
-- NETWORK PACKAGE
-- ============================================================================
local Network = require(ReplicatedStorage.Packages.Network)

-- ============================================================================
-- REMOTES
-- ============================================================================
local RollEvent       = ReplicatedStorage.Network.RollService.RF.RollDice
local BuyEvent        = ReplicatedStorage:WaitForChild("Network"):WaitForChild("RE"):WaitForChild("BuyUpgrade")
local CollectEvent    = ReplicatedStorage:WaitForChild("Network"):WaitForChild("PlotService"):WaitForChild("RE"):WaitForChild("CollectBalance")
local EquipBestEvent  = ReplicatedStorage:WaitForChild("Network"):WaitForChild("PlotService"):WaitForChild("RE"):WaitForChild("EquipBest")
local LevelUpSlotEvent= ReplicatedStorage:WaitForChild("Network"):WaitForChild("PlotService"):WaitForChild("RE"):WaitForChild("LevelUpSlot")

local SpinEvent, GroupRewardEvent, TraitRollEvent, GradeRollEvent, SellEvent, DailyRewardEvent
local BuyDiceEvent, EquipDiceEvent, RebirthEvent
local QuestClaimEvent, QuestBuyEvent
do
    local n = ReplicatedStorage:FindFirstChild("Network")
    if n then
        local s = n:FindFirstChild("SpinService")
        SpinEvent = s and s:FindFirstChild("RE") and s.RE:FindFirstChild("Use")

        local g = n:FindFirstChild("GroupRewardService")
        GroupRewardEvent = g and g:FindFirstChild("RE") and g.RE:FindFirstChild("Claim")

        local t = n:FindFirstChild("TraitService")
        if t then
            TraitRollEvent = t:FindFirstChild("Roll")
                or (t:FindFirstChild("RE") and t.RE:FindFirstChild("Roll"))
                or (t:FindFirstChild("RF") and t.RF:FindFirstChild("Roll"))
        end

        local gr = n:FindFirstChild("GradeService")
        GradeRollEvent = gr and gr:FindFirstChild("RE") and gr.RE:FindFirstChild("Roll")

        local se = n:FindFirstChild("SellService")
        SellEvent = se and se:FindFirstChild("RF") and se.RF:FindFirstChild("SellInventory")

        local d = n:FindFirstChild("DailyRewardService")
        if d then
            DailyRewardEvent = d:FindFirstChild("Claim")
                or (d:FindFirstChild("RE") and d.RE:FindFirstChild("Claim"))
                or (d:FindFirstChild("RF") and d.RF:FindFirstChild("Claim"))
        end

        local ds = n:FindFirstChild("DiceShopService")
        if ds then
            BuyDiceEvent = (ds:FindFirstChild("RE") and ds.RE:FindFirstChild("BuyDice")) or ds:FindFirstChild("BuyDice")
            EquipDiceEvent = (ds:FindFirstChild("RE") and ds.RE:FindFirstChild("EquipDice")) or ds:FindFirstChild("EquipDice")
        end

        local rb = n:FindFirstChild("RebirthService")
        if rb then
            RebirthEvent = rb:FindFirstChild("Rebirth")
                or (rb:FindFirstChild("RE") and rb.RE:FindFirstChild("Rebirth"))
                or (rb:FindFirstChild("RF") and rb.RF:FindFirstChild("Rebirth"))
        end

        local q = n:FindFirstChild("QuestService")
        if q then
            QuestClaimEvent = q:FindFirstChild("Claim")
                or (q:FindFirstChild("RE") and q.RE:FindFirstChild("Claim"))
                or (q:FindFirstChild("RF") and q.RF:FindFirstChild("Claim"))
            QuestBuyEvent = q:FindFirstChild("Buy")
                or (q:FindFirstChild("RE") and q.RE:FindFirstChild("Buy"))
                or (q:FindFirstChild("RF") and q.RF:FindFirstChild("Buy"))
        end
    end
end

-- ============================================================================
-- TOWER REMOTES (via Network wrapper)
-- ============================================================================
local towersComm = Network.ClientComm.new(ReplicatedStorage.Network, false, "Towers")
local PlayTowerFn          = towersComm:GetFunction("PlayTower")
local CompleteTowerFloorFn = towersComm:GetFunction("CompleteTowerFloor")
local CancelTowerFn        = towersComm:GetFunction("CancelTower")
local EquipBestTowerTeamSig= towersComm:GetSignal("EquipBestTowerTeam")
local UpdateTowerTeamSig   = towersComm:GetSignal("UpdateTowerTeam")

print("[AutoRoll] Remotes:",
    "Spin", SpinEvent and "Y" or "N",
    "| Group", GroupRewardEvent and "Y" or "N",
    "| Trait", TraitRollEvent and "Y" or "N",
    "| Grade", GradeRollEvent and "Y" or "N",
    "| Sell", SellEvent and "Y" or "N",
    "| Daily", DailyRewardEvent and "Y" or "N",
    "| Level", LevelUpSlotEvent and "Y" or "N",
    "| BuyDice", BuyDiceEvent and "Y" or "N",
    "| Rebirth", RebirthEvent and "Y" or "N",
    "| Quest", QuestClaimEvent and "Y" or "N",
    "| Tower", PlayTowerFn and "Y" or "N")

-- ============================================================================
-- MODULES
-- ============================================================================
local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
local TreeStructure  = require(ReplicatedStorage.Framework.Features.Upgrades.TreeStructure)
local Upgrades       = require(ReplicatedStorage.Framework.Features.Upgrades.Upgrades)
local PlotConfig     = require(ReplicatedStorage.Framework.Features.Plot.PlotConfig)
local Traits         = require(ReplicatedStorage.Framework.Features.Traits.Traits)
local Grades         = require(ReplicatedStorage.Framework.Features.Grades.Grades)
local EntryRegistry  = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry)
local DailyRewardConfig = require(ReplicatedStorage.Framework.Features.Rewards.DailyRewardConfig)
local Dice           = require(ReplicatedStorage.Framework.Features.Rolling.Dice)
local Rebirths       = require(ReplicatedStorage.Framework.Features.Rebirth.Rebirths)
local QuestConfig    = require(ReplicatedStorage.Framework.Features.Quests.QuestConfig)
local Towers         = require(ReplicatedStorage.Framework.Features.Towers.Towers)
local TowerRefs      = require(ReplicatedStorage.Framework.Features.Towers.TowerRefs)

-- ============================================================================
-- LISTS
-- ============================================================================
local UPGRADES = {}
for name, data in pairs(Upgrades) do
    table.insert(UPGRADES, { name = name, price = data.price or 0 })
end
table.sort(UPGRADES, function(a, b) return a.price < b.price end)

local TRAIT_LIST = {}
for name, data in pairs(Traits) do
    table.insert(TRAIT_LIST, { name = name, weight = data.weight, order = data.order })
end
table.sort(TRAIT_LIST, function(a, b) return a.order > b.order end)

local GRADE_LIST = {}
for name, data in pairs(Grades) do
    table.insert(GRADE_LIST, { name = name, weight = data.weight, order = data.order })
end
table.sort(GRADE_LIST, function(a, b) return a.order > b.order end)

local DICE_LIST = {}
for name, data in pairs(Dice.GetAll()) do
    if data.price then
        table.insert(DICE_LIST, { name = name, price = data.price, luck = data.luck or 0 })
    end
end
table.sort(DICE_LIST, function(a, b) return a.price < b.price end)

local TOWER_LIST = {}
for name, data in pairs(Towers.GetAll()) do
    table.insert(TOWER_LIST, { name = name, order = data.order or 0 })
end
table.sort(TOWER_LIST, function(a, b) return a.order < b.order end)

-- ============================================================================
-- STATE
-- ============================================================================
local state = {
    autoRoll = false, delay = 1, totalRolls = 0, startTime = os.clock(), loopThread = nil,
    autoUpgrade = true, upgradeThread = nil, ownedUpgrades = {},
    autoCollect = true, collectInterval = 5, collectThread = nil, totalCollects = 0,
    autoEquipBest = true, equipBestInterval = 30, equipBestThread = nil, totalEquipBests = 0,
    autoGroupReward = false, groupRewardInterval = 60, groupRewardThread = nil, totalGroupClaims = 0,
    autoLuckySpin = false, luckySpinInterval = 5, luckySpinThread = nil, totalLuckySpins = 0,
    autoSell = false, sellInterval = 30, sellThread = nil, totalSells = 0,
    autoDaily = true, dailyCheckInterval = 30, dailyThread = nil, totalDailyClaims = 0,
    autoTrait = false, traitRollDelay = 0.3, traitThread = nil, totalTraitRolls = 0,
    selectedUnitKey = nil, desiredTraits = {},
    autoGrade = false, gradeRollDelay = 0.3, gradeThread = nil, totalGradeRolls = 0,
    selectedGradeUnitKey = nil, desiredGrades = {},
    autoLevel = false, levelTarget = 25, levelCheckInterval = 1, levelThread = nil, totalLevelUps = 0,
    autoRebirth = true, rebirthCheckInterval = 3, rebirthThread = nil, totalRebirths = 0,
    autoBuyDice = false, buyDiceInterval = 2, buyDiceThread = nil, totalDiceBought = 0,
    autoQuestClaim = true, questClaimInterval = 5, questClaimThread = nil, totalQuestsClaimed = 0,
    autoTower = false, towerName = "Dragon Tower", towerThread = nil,
    totalTowersCompleted = 0, totalTowerFloors = 0, towerInProgress = false,
    skipCutscenes = true, totalCutscenesSkipped = 0,
}

runtime.State = state

-- ============================================================================
-- HELPERS
-- ============================================================================
local function fmt(n)
    if n >= 1e15 then return string.format("%.2fQ", n/1e15) end
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.2fK", n/1e3) end
    return tostring(math.floor(n))
end
local function getMoney()
    local ok, m = pcall(function() return DataController.Money() end)
    return (ok and type(m) == "number") and m or 0
end
local function getRebirth()
    local ok, r = pcall(function() return DataController.Rebirth() end)
    return (ok and type(r) == "number") and r or 0
end
local function getLuckySpinCount()
    local ok, entry = pcall(function()
        return DataController.Inventory["Lucky Spin"] and DataController.Inventory["Lucky Spin"]()
    end)
    if ok and type(entry) == "table" then return entry.amount or 0 end
    return 0
end
local function getGemCount()
    local ok, entry = pcall(function()
        return DataController.Inventory["Gems"] and DataController.Inventory["Gems"]()
    end)
    if ok and type(entry) == "table" then return entry.amount or 0 end
    return 0
end
local function getTicketCount()
    local ok, entry = pcall(function()
        return DataController.Inventory.Tickets and DataController.Inventory.Tickets()
    end)
    if ok and type(entry) == "table" then return entry.amount or 0 end
    return 0
end
local function isOwned(name)
    local g = DataController.Upgrades and DataController.Upgrades[name]
    if not g then return false end
    local ok, v = pcall(g); return ok and v == true
end
local function refreshOwned()
    state.ownedUpgrades = {}
    for _, up in ipairs(UPGRADES) do
        if isOwned(up.name) then state.ownedUpgrades[up.name] = true end
    end
    state.ownedUpgrades["Start"] = true
end
local function canBuy(name)
    local p = TreeStructure.GetParent(name)
    if not p or p == "Start" then return true end
    return isOwned(p)
end
local function getUnitTrait(key)
    if not key then return nil end
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then return nil end
    local e = inv[key]
    if not e or not e.attributes then return nil end
    local t = e.attributes.trait
    if type(t) == "function" then local ok2, v = pcall(t); return ok2 and v or nil end
    return t
end
local function getUnitGrade(key)
    if not key then return nil end
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then return nil end
    local e = inv[key]
    if not e or not e.attributes then return nil end
    local g = e.attributes.grade
    if type(g) == "function" then local ok2, v = pcall(g); return ok2 and v or nil end
    return g
end
local function listOwnedUnits()
    local out = {}
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then return out end
    for key, e in pairs(inv) do
        if type(e) == "table" and e.name and (e.amount or 0) > 0 then
            local cfg = EntryRegistry.getEntryConfig(e.name)
            if cfg and cfg.kind == "Unit" then
                local tv, gv
                if e.attributes then
                    if e.attributes.trait then
                        local t = e.attributes.trait
                        if type(t) == "function" then local ok2, v = pcall(t); if ok2 then tv = v end else tv = t end
                    end
                    if e.attributes.grade then
                        local g = e.attributes.grade
                        if type(g) == "function" then local ok2, v = pcall(g); if ok2 then gv = v end else gv = g end
                    end
                end
                table.insert(out, { key=key, name=e.name, amount=e.amount, trait=tv, grade=gv })
            end
        end
    end
    return out
end
local function getEquippedSlotMap()
    local map = {}
    local ok, slots = pcall(function() return DataController.Slots() end)
    if not ok or type(slots) ~= "table" then return map end
    for slotIdx, slotData in pairs(slots) do
        if type(slotData) == "table" and slotData.unitId then
            map[slotData.unitId] = tonumber(slotIdx) or slotIdx
        end
    end
    return map
end
local function getEquippedSlots()
    local out = {}
    local ok, slots = pcall(function() return DataController.Slots() end)
    if not ok or type(slots) ~= "table" then return out end
    for slotIdx, slotData in pairs(slots) do
        if type(slotData) == "table" and slotData.unitId then
            local level = 1
            local inv = DataController.Inventory
            local entry = inv and inv[slotData.unitId] and inv[slotData.unitId]()
            if entry and entry.attributes then level = entry.attributes.level or 1 end
            table.insert(out, { slot=tonumber(slotIdx) or slotIdx, unitId=slotData.unitId, level=level })
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end
local function getRarityScore(unitName)
    local cfg = EntryRegistry.getEntryConfig(unitName)
    if not cfg then return 0 end
    local r = cfg.rarity or cfg.Rarity or cfg.rarityName
    if type(r) == "number" then return r end
    if type(r) == "string" then
        local map = { common=1, uncommon=2, rare=3, epic=4, legendary=5, mythical=6, secret=7, godly=8, exclusive=9, event=10 }
        return map[r:lower()] or 0
    end
    return cfg.weight or cfg.rarityWeight or cfg.tier or 0
end
local function ownsDice(name)
    local g = DataController.OwnedDice and DataController.OwnedDice[name]
    if not g then return false end
    local ok, v = pcall(g); return ok and v == true
end
local function getEquippedDice()
    local ok, v = pcall(function() return DataController.Dice() end)
    return ok and v or nil
end
local function getNextLockedDice()
    for _, d in ipairs(DICE_LIST) do
        if not ownsDice(d.name) then return d end
    end
    return nil
end
local function getRebirthCost()
    local nextRb = Rebirths.GetNext(getRebirth())
    return nextRb and nextRb.cost or nil
end
local function getTowerTeam()
    local out = {}
    local ok, team = pcall(function() return DataController.TowerTeam() end)
    if not ok or type(team) ~= "table" then return out end
    for i = 1, TowerRefs.MAX_TEAM_SIZE do
        local key = team[i]
        if key and key ~= "" then table.insert(out, key) end
    end
    return out
end

-- ============================================================================
-- CUTSCENE SKIPPER
-- ============================================================================
do
    local function skip()
        if not runtime.Alive or not state.skipCutscenes then return end
        local fade = PlayerGui:FindFirstChild("CutsceneBlackFade")
        if fade then fade:Destroy() end
        local cam = workspace.CurrentCamera
        if cam then
            if cam.CameraType == Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Custom end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum end
            cam.FieldOfView = 70
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                    part.LocalTransparencyModifier = 0
                    part.Transparency = 0
                elseif part:IsA("Decal") then part.Transparency = 0
                elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("Beam") then part.Enabled = true
                end
            end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == "CameraModel" or obj.Name == "lines" then obj:Destroy() end
        end
        state.totalCutscenesSkipped = state.totalCutscenesSkipped + 1
    end
    connect(PlayerGui.ChildAdded, function(c)
        if not state.skipCutscenes then return end
        if c.Name == "CutsceneBlackFade" then
            task.defer(skip); task.delay(0.05, skip); task.delay(0.2, skip)
        end
    end)
    task.spawn(function()
        while runtime.Alive do
            if state.skipCutscenes and PlayerGui:FindFirstChild("CutsceneBlackFade") then skip() end
            task.wait(0.1)
        end
    end)
end

-- ============================================================================
-- LOOPS
-- ============================================================================
local function rollDice()
    if pcall(function() RollEvent:InvokeServer() end) then state.totalRolls = state.totalRolls + 1 end
end
local function startRollLoop()
    if state.loopThread then return end
    state.autoRoll = true
    state.loopThread = task.spawn(function()
        while runtime.Alive and state.autoRoll do rollDice(); task.wait(state.delay) end
        state.loopThread = nil
    end)
end
local function stopRollLoop() cancelLoop("loopThread") state.autoRoll = false end

local function runUpgradeLoop()
    refreshOwned()
    local recent = {}
    while runtime.Alive and state.autoUpgrade do
        local money = getMoney(); local now = os.clock(); local boughtAny = false
        for _, up in ipairs(UPGRADES) do
            local deb = recent[up.name] and (now - recent[up.name] < 4)
            if not state.ownedUpgrades[up.name] and not deb and canBuy(up.name) and money >= up.price then
                if pcall(function() BuyEvent:FireServer(up.name) end) then
                    recent[up.name] = now; boughtAny = true
                    task.wait(0.4); refreshOwned()
                end
            end
        end
        task.wait(boughtAny and 0.5 or 1)
    end
    state.upgradeThread = nil
end
local function startUpgradeLoop()
    if state.upgradeThread then return end
    state.autoUpgrade = true
    state.upgradeThread = task.spawn(runUpgradeLoop)
end
local function stopUpgradeLoop() cancelLoop("upgradeThread") state.autoUpgrade = false end

local function collectAll()
    local rb = getRebirth(); local fired = 0
    for slot = 1, PlotConfig.GetMaxSlots() do
        if rb >= PlotConfig.GetSlotRebirthRequirement(slot) then
            if pcall(function() CollectEvent:FireServer(slot) end) then fired = fired + 1 end
            task.wait(0.08)
        end
    end
    state.totalCollects = state.totalCollects + fired
    return fired
end
local function runCollectLoop()
    while runtime.Alive and state.autoCollect do collectAll(); task.wait(state.collectInterval) end
    state.collectThread = nil
end
local function startCollectLoop()
    if state.collectThread then return end
    state.autoCollect = true
    state.collectThread = task.spawn(runCollectLoop)
end
local function stopCollectLoop() cancelLoop("collectThread") state.autoCollect = false end

local function equipBest()
    local ok = pcall(function() EquipBestEvent:FireServer() end)
    if ok then state.totalEquipBests = state.totalEquipBests + 1 end
    return ok
end
local function runEquipBestLoop()
    equipBest()
    while runtime.Alive and state.autoEquipBest do
        task.wait(state.equipBestInterval)
        if state.autoEquipBest then equipBest() end
    end
    state.equipBestThread = nil
end
local function startEquipBestLoop()
    if state.equipBestThread then return end
    state.autoEquipBest = true
    state.equipBestThread = task.spawn(runEquipBestLoop)
end
local function stopEquipBestLoop() cancelLoop("equipBestThread") state.autoEquipBest = false end

local function claimGroupReward()
    if not GroupRewardEvent then return false end
    local ok = pcall(function() GroupRewardEvent:FireServer() end)
    if ok then state.totalGroupClaims = state.totalGroupClaims + 1 end
    return ok
end
local function runGroupRewardLoop()
    while runtime.Alive and state.autoGroupReward do claimGroupReward(); task.wait(state.groupRewardInterval) end
    state.groupRewardThread = nil
end
local function startGroupRewardLoop()
    if state.groupRewardThread or not GroupRewardEvent then return end
    state.autoGroupReward = true
    state.groupRewardThread = task.spawn(runGroupRewardLoop)
end
local function stopGroupRewardLoop() cancelLoop("groupRewardThread") state.autoGroupReward = false end

local function useLuckySpin()
    if not SpinEvent then return false end
    if getLuckySpinCount() <= 0 then return false end
    local ok = pcall(function() SpinEvent:FireServer("Lucky Spin") end)
    if ok then state.totalLuckySpins = state.totalLuckySpins + 1 end
    return ok
end
local function runLuckySpinLoop()
    while runtime.Alive and state.autoLuckySpin do
        if getLuckySpinCount() > 0 then useLuckySpin() end
        task.wait(state.luckySpinInterval)
    end
    state.luckySpinThread = nil
end
local function startLuckySpinLoop()
    if state.luckySpinThread or not SpinEvent then return end
    state.autoLuckySpin = true
    state.luckySpinThread = task.spawn(runLuckySpinLoop)
end
local function stopLuckySpinLoop() cancelLoop("luckySpinThread") state.autoLuckySpin = false end

local function gatherSellableKeys()
    local keys = {}
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then return keys end
    for key, entry in pairs(inv) do
        if type(entry) == "table" and entry.name and (entry.amount or 0) > 0 then
            local cfg = EntryRegistry.getEntryConfig(entry.name)
            if cfg and cfg.kind == "Unit" then table.insert(keys, key) end
        end
    end
    return keys
end
local function sellInventory()
    if not SellEvent then return false, 0 end
    local keys = gatherSellableKeys()
    if #keys == 0 then return false, 0 end
    local ok = pcall(function() SellEvent:InvokeServer(keys) end)
    if ok then state.totalSells = state.totalSells + #keys end
    return ok, #keys
end
local function runSellLoop()
    while runtime.Alive and state.autoSell do sellInventory(); task.wait(state.sellInterval) end
    state.sellThread = nil
end
local function startSellLoop()
    if state.sellThread or not SellEvent then return end
    state.autoSell = true
    state.sellThread = task.spawn(runSellLoop)
end
local function stopSellLoop() cancelLoop("sellThread") state.autoSell = false end

local function isDailyReady()
    local ok, last = pcall(function() return DataController.LastDailyRewardClaim() end)
    if not ok or type(last) ~= "number" then return false end
    if last == 0 then return true end
    return (os.time() - last) >= DailyRewardConfig.Cooldown
end
local function claimDaily()
    if not DailyRewardEvent then return false end
    if not isDailyReady() then return false end
    local ok = pcall(function() DailyRewardEvent:FireServer() end)
    if ok then state.totalDailyClaims = state.totalDailyClaims + 1 end
    return ok
end
local function runDailyLoop()
    while runtime.Alive and state.autoDaily do
        if isDailyReady() then claimDaily() end
        task.wait(state.dailyCheckInterval)
    end
    state.dailyThread = nil
end
local function startDailyLoop()
    if state.dailyThread or not DailyRewardEvent then return end
    state.autoDaily = true
    state.dailyThread = task.spawn(runDailyLoop)
end
local function stopDailyLoop() cancelLoop("dailyThread") state.autoDaily = false end

local function fireTraitRoll(k)
    if not TraitRollEvent then return false end
    return pcall(function() TraitRollEvent:FireServer(k) end)
end
local function currentTraitMatches()
    local t = getUnitTrait(state.selectedUnitKey)
    return t and state.desiredTraits[t] == true
end
local function runTraitLoop()
    while runtime.Alive and state.autoTrait do
        if not state.selectedUnitKey or next(state.desiredTraits) == nil then
            task.wait(0.5)
        elseif currentTraitMatches() then
            print(("[TraitRoll] Got %s"):format(getUnitTrait(state.selectedUnitKey)))
            state.autoTrait = false; break
        else
            if fireTraitRoll(state.selectedUnitKey) then state.totalTraitRolls = state.totalTraitRolls + 1 end
            task.wait(state.traitRollDelay)
        end
    end
    state.traitThread = nil
end
local function startTraitLoop()
    if state.autoTrait then return false, "already running" end
    if not state.selectedUnitKey then return false, "no unit" end
    if next(state.desiredTraits) == nil then return false, "no traits" end
    state.autoTrait = true
    state.traitThread = task.spawn(runTraitLoop)
    return true
end
local function stopTraitLoop() cancelLoop("traitThread") state.autoTrait = false; state.traitThread = nil end

local function fireGradeRoll(k)
    if not GradeRollEvent then return false end
    return pcall(function() GradeRollEvent:FireServer(k) end)
end
local function currentGradeMatches()
    local g = getUnitGrade(state.selectedGradeUnitKey)
    return g and state.desiredGrades[g] == true
end
local function runGradeLoop()
    while runtime.Alive and state.autoGrade do
        if not state.selectedGradeUnitKey or next(state.desiredGrades) == nil then
            task.wait(0.5)
        elseif getGemCount() <= 0 then
            state.autoGrade = false; break
        elseif currentGradeMatches() then
            print(("[GradeRoll] Got %s"):format(getUnitGrade(state.selectedGradeUnitKey)))
            state.autoGrade = false; break
        else
            if fireGradeRoll(state.selectedGradeUnitKey) then state.totalGradeRolls = state.totalGradeRolls + 1 end
            task.wait(state.gradeRollDelay)
        end
    end
    state.gradeThread = nil
end
local function startGradeLoop()
    if state.autoGrade then return false, "already running" end
    if not state.selectedGradeUnitKey then return false, "no unit" end
    if next(state.desiredGrades) == nil then return false, "no grades" end
    state.autoGrade = true
    state.gradeThread = task.spawn(runGradeLoop)
    return true
end
local function stopGradeLoop() cancelLoop("gradeThread") state.autoGrade = false; state.gradeThread = nil end

local function levelUpSlot(slotIndex)
    if not LevelUpSlotEvent then return false end
    return pcall(function() LevelUpSlotEvent:FireServer(slotIndex) end)
end
local function runLevelLoop()
    while runtime.Alive and state.autoLevel do
        local slots = getEquippedSlots()
        local fired = 0
        for _, info in ipairs(slots) do
            if state.autoLevel and info.level < state.levelTarget then
                if levelUpSlot(info.slot) then
                    fired = fired + 1
                    state.totalLevelUps = state.totalLevelUps + 1
                end
                task.wait(0.15)
            end
        end
        task.wait(fired > 0 and 0.2 or state.levelCheckInterval)
    end
    state.levelThread = nil
end
local function startLevelLoop()
    if state.levelThread or not LevelUpSlotEvent then return end
    state.autoLevel = true
    state.levelThread = task.spawn(runLevelLoop)
end
local function stopLevelLoop() cancelLoop("levelThread") state.autoLevel = false; state.levelThread = nil end

local function fireRebirth()
    if not RebirthEvent then return false end
    local ok = pcall(function() RebirthEvent:FireServer() end)
    if ok then state.totalRebirths = state.totalRebirths + 1 end
    return ok
end
local function runRebirthLoop()
    while runtime.Alive and state.autoRebirth do
        local cost = getRebirthCost()
        if cost and getMoney() >= cost then
            print(("[AutoRebirth] Firing (cost %s)"):format(fmt(cost)))
            fireRebirth()
            task.wait(1.5)
        else
            task.wait(state.rebirthCheckInterval)
        end
    end
    state.rebirthThread = nil
end
local function startRebirthLoop()
    if state.rebirthThread or not RebirthEvent then return end
    state.autoRebirth = true
    state.rebirthThread = task.spawn(runRebirthLoop)
end
local function stopRebirthLoop() cancelLoop("rebirthThread") state.autoRebirth = false; state.rebirthThread = nil end

local function buyDice(name)
    if not BuyDiceEvent then return false end
    local ok = pcall(function() BuyDiceEvent:FireServer(name) end)
    if ok then state.totalDiceBought = state.totalDiceBought + 1 end
    return ok
end
local function equipDice(name)
    if not EquipDiceEvent then return false end
    return pcall(function() EquipDiceEvent:FireServer(name) end)
end
local function runBuyDiceLoop()
    while runtime.Alive and state.autoBuyDice do
        local money = getMoney()
        local boughtAny = false
        for _, d in ipairs(DICE_LIST) do
            if not state.autoBuyDice then break end
            if not ownsDice(d.name) and money >= d.price then
                if buyDice(d.name) then
                    boughtAny = true
                    task.wait(0.4)
                    money = getMoney()
                end
            end
        end
        task.wait(boughtAny and 0.5 or state.buyDiceInterval)
    end
    state.buyDiceThread = nil
end
local function startBuyDiceLoop()
    if state.buyDiceThread or not BuyDiceEvent then return end
    state.autoBuyDice = true
    state.buyDiceThread = task.spawn(runBuyDiceLoop)
end
local function stopBuyDiceLoop() cancelLoop("buyDiceThread") state.autoBuyDice = false; state.buyDiceThread = nil end

-- ============================================================================
-- QUEST HELPERS + LOOP
-- ============================================================================
local function getQuestPeriodData(period)
    local ok, data = pcall(function() return DataController.Quests[period]() end)
    if ok and type(data) == "table" then return data end
    return nil
end
local function getAllQuestStatus()
    local out = {}
    local serverNow = math.floor(workspace:GetServerTimeNow())
    for period, cfg in pairs(QuestConfig.Periods) do
        local data = getQuestPeriodData(period)
        if data then
            local expired = data.expiresAt > 0 and data.expiresAt <= serverNow
            for _, quest in ipairs(cfg.quests) do
                local progress = data.progress[quest.id] or 0
                local claimed = data.claimed[quest.id] == true
                local ready = (not expired) and (not claimed) and progress >= quest.target
                table.insert(out, {
                    period = period, id = quest.id, title = quest.title,
                    tickets = quest.tickets, progress = math.min(progress, quest.target),
                    target = quest.target, claimed = claimed, ready = ready,
                    expiresAt = data.expiresAt, expired = expired,
                })
            end
        end
    end
    return out
end
local function claimQuest(period, questId, expiresAt)
    if not QuestClaimEvent then return false end
    return pcall(function() QuestClaimEvent:FireServer(period, questId, expiresAt) end)
end
local function runQuestClaimLoop()
    while runtime.Alive and state.autoQuestClaim do
        local all = getAllQuestStatus()
        local claimedAny = false
        for _, q in ipairs(all) do
            if not state.autoQuestClaim then break end
            if q.ready then
                if claimQuest(q.period, q.id, q.expiresAt) then
                    state.totalQuestsClaimed = state.totalQuestsClaimed + 1
                    claimedAny = true
                    print(("[AutoQuest] Claimed %s/%s (+%d tickets)"):format(q.period, q.id, q.tickets))
                    task.wait(0.4)
                end
            end
        end
        task.wait(claimedAny and 0.5 or state.questClaimInterval)
    end
    state.questClaimThread = nil
end
local function startQuestClaimLoop()
    if state.questClaimThread or not QuestClaimEvent then return end
    state.autoQuestClaim = true
    state.questClaimThread = task.spawn(runQuestClaimLoop)
end
local function stopQuestClaimLoop() cancelLoop("questClaimThread") state.autoQuestClaim = false; state.questClaimThread = nil end

-- ============================================================================
-- TOWER LOOP (uses Network wrapper)
-- ============================================================================
local function getSequenceDuration(seq)
    if type(seq) ~= "table" then return 0 end
    local total = 0
    for i, a in ipairs(seq) do
        if a.action == TowerRefs.Actions.floorStarted then
            local prev = seq[i - 1]
            if i == 1 then
                total = total + (a.floor == 1 and TowerRefs.FloorStartedWaitTime.initial or TowerRefs.FloorStartedWaitTime.transition)
            elseif prev and prev.action == TowerRefs.Actions.memberDefeated then
                total = total + TowerRefs.FloorStartedWaitTime.transition
            else
                total = total + TowerRefs.FloorStartedWaitTime.repeated
            end
        else
            total = total + (TowerRefs.ActionWaitTime[a.action] or 0)
        end
    end
    return total
end
local function startTower(name)
    if not PlayTowerFn then return false end
    local ok, result = pcall(function() return PlayTowerFn(name) end)
    if ok and result == true then
        state.towerInProgress = true
        return true
    end
    return false
end
local function completeFloor()
    if not CompleteTowerFloorFn then return nil end
    local ok, result = pcall(function() return CompleteTowerFloorFn() end)
    if ok and type(result) == "table" and #result > 0 then
        return result
    end
    return nil
end
local function cancelTower()
    if not CancelTowerFn then return end
    pcall(function() CancelTowerFn() end)
    state.towerInProgress = false
end
local function equipBestTowerTeam()
    if not EquipBestTowerTeamSig then return false end
    return pcall(function() EquipBestTowerTeamSig:Fire() end)
end
local function runTowerLoop()
    while runtime.Alive and state.autoTower do
        local team = getTowerTeam()
        if #team == 0 then
            print("[AutoTower] Empty team — equipping best")
            equipBestTowerTeam()
            task.wait(1.5)
        end
        if not state.towerInProgress then
            if not startTower(state.towerName) then
                print("[AutoTower] Failed to start — retrying in 3s")
                task.wait(3)
            else
                print(("[AutoTower] Started %s"):format(state.towerName))
            end
        end
        if state.towerInProgress then
            local loops = 0
            while runtime.Alive and state.autoTower and state.towerInProgress do
                loops = loops + 1
                if loops > 500 then
                    warn("[AutoTower] Too many loops — cancelling")
                    cancelTower()
                    break
                end
                local seq = completeFloor()
                if not seq then
                    state.towerInProgress = false
                    state.totalTowersCompleted = state.totalTowersCompleted + 1
                    print(("[AutoTower] Completed %s (%d total)"):format(state.towerName, state.totalTowersCompleted))
                    break
                end
                state.totalTowerFloors = state.totalTowerFloors + 1
                local waitTime = getSequenceDuration(seq)
                waitTime = math.min(waitTime, 15)
                task.wait(waitTime + 0.05)
            end
        end
        if state.autoTower then task.wait(1) end
    end
    state.towerThread = nil
end
local function startTowerLoop()
    if state.towerThread or not PlayTowerFn then return end
    state.autoTower = true
    state.towerThread = task.spawn(runTowerLoop)
end
local function stopTowerLoop() cancelLoop("towerThread")
    state.autoTower = false
    if state.towerInProgress then cancelTower() end
    state.towerThread = nil
end


local COLORS = {red = Color3.fromRGB(200,70,70), green = Color3.fromRGB(60,170,90), textDim = Color3.fromRGB(160,160,175)}
local function setOnOff(button, on, onText, offText)
    if button then button.Text = on and onText or offText end
end

-- Native Vitality controls. Small adapters retain the original event handlers
-- and status updates while the library owns layout, search, tinting and focus.
local gui = {sg = Window.Gui}
local sections, toggles = {}, {}
assert(runtime.Alive, "Anime Dice initialization cancelled")
local group = Window:CreateTabDropdown({Name = "Anime Dice", Icon = "dice", Expanded = true})
runtime.Group = group
local tabSpecs = {
    {"Progression", "dice"}, {"Plot & Units", "players"}, {"Rerolls", "trait"},
    {"Rewards", "award"}, {"Tower", "tower"}, {"Options", "settings"},
}
local tabs = {}
for _, spec in ipairs(tabSpecs) do tabs[spec[1]] = group:CreateTab(spec[1], spec[2]) end
local function section(key, tab, title, icon, side, description)
    sections[key] = tabs[tab]:CreateSection({Name = title, Icon = icon, Side = side, Description = description})
    return sections[key]
end
section("Roll", "Progression", "Rolling", "dice", "Left")
section("Upgrades", "Progression", "Upgrades", "upgrade", "Right")
section("Rebirth", "Progression", "Rebirth", "repeat", "Right")
section("Dice", "Progression", "Dice Collection", "inventory", "Left")
section("Collect", "Plot & Units", "Collect & Equip", "collect", "Left")
section("Level", "Plot & Units", "Unit Levels", "level", "Right")
section("Equipped", "Plot & Units", "Equipped Units", "players", "Left")
section("Sell", "Plot & Units", "Inventory Selling", "cash", "Right", "Sends every owned unit key to the game's sell handler, matching the original script.")
section("Traits", "Rerolls", "Traits", "trait", "Left", "Choose an unequipped unit and the traits to stop on.")
section("Grade", "Rerolls", "Grades", "rank", "Right", "Choose an unequipped unit and the grades to stop on.")
section("Daily", "Rewards", "Daily Rewards", "daily", "Left")
section("Group", "Rewards", "Group Rewards", "group", "Left")
section("Spins", "Rewards", "Lucky Spins", "sparkles", "Left")
section("Quests", "Rewards", "Daily & Weekly Quests", "quest", "Right")
section("Tower", "Tower", "Tower Runner", "tower", "Left")
section("Team", "Tower", "Team & Manual Controls", "team", "Right")
section("Settings", "Options", "Game Options", "settings", "Left")
section("Session", "Options", "Session", "session", "Right")

local function signal()
    local callbacks = {}
    return {
        Connect = function(_, callback) table.insert(callbacks, callback) end,
        Fire = function(_, ...)
            for _, callback in ipairs(callbacks) do task.spawn(callback, ...) end
        end,
    }
end
local function adapter(control, kind, initial)
    local values = {Text = tostring(initial or ""), Control = control}
    return setmetatable({}, {
        __index = values,
        __newindex = function(_, key, value)
            if values[key] == value then return end
            values[key] = value
            if key == "Text" then
                if kind == "paragraph" then control:Set({Content = tostring(value)})
                elseif kind == "button" then control:Set(tostring(value))
                elseif kind == "input" then control:Set(tostring(value), false) end
            end
            -- Old per-widget colors are intentionally replaced by Vitality theme roles.
        end,
    })
end
local function paragraph(key, parent, title, initial)
    local control = sections[parent]:CreateParagraph({Title = title, Content = initial or "Loading..."})
    gui[key] = adapter(control, "paragraph", initial)
end
local function button(key, parent, name, info)
    local click = signal()
    local control = sections[parent]:CreateButton({Name = name, Info = info, Callback = function() click:Fire() end})
    gui[key] = adapter(control, "button", name)
    gui[key].MouseButton1Click = click
end
local function toggle(key, parent, name, getter, available)
    local click = signal()
    local function effectiveValue() return available ~= false and getter() == true end
    local control = sections[parent]:CreateToggle({Name = name, CurrentValue = effectiveValue(),
        Callback = function(value)
            if runtime.Alive and available ~= false and value ~= (getter() == true) then click:Fire() end
        end})
    gui[key] = adapter(control, "toggle", name)
    gui[key].MouseButton1Click = click
    table.insert(toggles, {Control = control, Get = effectiveValue})
    if available == false then control:SetDisabled(true, "Required game remote is unavailable") end
end
local function input(key, parent, name, initial)
    local changed = signal()
    local control = sections[parent]:CreateInput({Name = name, CurrentValue = tostring(initial),
        Callback = function(value)
            gui[key].Text = tostring(value)
            changed:Fire()
        end})
    gui[key] = adapter(control, "input", initial)
    gui[key].FocusLost = changed
end
local function syncToggles()
    for _, item in ipairs(toggles) do
        local value = item.Get() == true
        if item.Control:Get() ~= value then item.Control:Set(value, false) end
    end
end

toggle("rollToggleBtn", "Roll", "Auto roll", function() return state.autoRoll end)
input("delayBox", "Roll", "Roll delay (seconds)", state.delay)
button("rollOnceBtn", "Roll", "Roll once")
paragraph("rollStats", "Roll", "Roll status")
paragraph("moneyLabel", "Roll", "Money")
toggle("upToggleBtn", "Upgrades", "Auto upgrade", function() return state.autoUpgrade end)
button("upRescanBtn", "Upgrades", "Rescan owned upgrades")
paragraph("upNextLbl", "Upgrades", "Next upgrade")
paragraph("upOwnedLbl", "Upgrades", "Owned upgrades")
toggle("rebirthToggleBtn", "Rebirth", "Auto rebirth", function() return state.autoRebirth end, RebirthEvent ~= nil)
paragraph("rebirthInfoLbl", "Rebirth", "Rebirth requirement")
paragraph("rebirthStatsLbl", "Rebirth", "Rebirth count")
toggle("diceToggleBtn", "Dice", "Auto buy dice", function() return state.autoBuyDice end, BuyDiceEvent ~= nil)
input("buyDiceIntBox", "Dice", "Purchase interval (seconds)", state.buyDiceInterval)
button("diceNowBtn", "Dice", "Buy affordable dice")
button("diceEquipBestBtn", "Dice", "Equip best owned dice")
paragraph("diceInfoLbl", "Dice", "Dice status")
paragraph("diceInventory", "Dice", "Owned & Available Dice")

toggle("colToggleBtn", "Collect", "Auto collect", function() return state.autoCollect end)
input("colIntBox", "Collect", "Collection interval (seconds)", state.collectInterval)
button("colNowBtn", "Collect", "Collect now")
paragraph("colStats", "Collect", "Collection status")
toggle("eqToggleBtn", "Collect", "Auto equip best", function() return state.autoEquipBest end)
input("eqIntBox", "Collect", "Equip interval (seconds)", state.equipBestInterval)
paragraph("eqStats", "Collect", "Equip count")
toggle("lvToggleBtn", "Level", "Auto level units", function() return state.autoLevel end, LevelUpSlotEvent ~= nil)
input("lvTargetBox", "Level", "Target level", state.levelTarget)
button("lvNowBtn", "Level", "Level equipped slots once")
paragraph("lvStats", "Level", "Leveling status")
paragraph("levelInventory", "Level", "Slot levels")
button("eqPageRefreshBtn", "Equipped", "Refresh equipped units")
paragraph("eqPageInfoLbl", "Equipped", "Equipped count")
paragraph("equippedInventory", "Equipped", "Equipped slots")
toggle("sellToggleBtn", "Sell", "Auto sell inventory", function() return state.autoSell end, SellEvent ~= nil)
input("sellIntBox", "Sell", "Sell interval (seconds)", state.sellInterval)
button("sellNowBtn", "Sell", "Sell unit inventory now")
paragraph("sellStats", "Sell", "Selling status")

local unitSelectors, unitOptions = {}, {trait = {}, grade = {}}
local function addReroll(mode, parent, items, prefix, stateKey, desiredKey)
    local select = sections[parent]:CreateDropdown({Name = "Unit to reroll", Options = {},
        Placeholder = "Refresh inventory, then select...", Callback = function(label)
            local unit = unitOptions[mode][label]
            if not runtime.Alive or not unit then return end
            if getEquippedSlotMap()[unit.key] then
                gui[prefix .. "UnitLbl"].Text = "This unit is equipped. Unequip it and refresh the list."
                return
            end
            state[stateKey] = unit.key
            gui[prefix .. "UnitLbl"].Text = ("Selected: %s x%d\n%s: %s"):format(
                unit.name, unit.amount, parent, tostring(unit[mode] or "None"))
        end})
    unitSelectors[mode] = select
    button(prefix .. "PickBtn", parent, "Refresh unit inventory")
    paragraph(prefix .. "UnitLbl", parent, "Selected unit", "No unit selected")
    local options, labels = {}, {}
    for _, item in ipairs(items) do
        local label = item.name .. " (weight " .. tostring(item.weight) .. ")"
        table.insert(options, label); labels[label] = item.name
    end
    sections[parent]:CreateDropdown({Name = "Stop on", Options = options, MultiSelection = true, CurrentOption = {},
        Callback = function(values)
            if not runtime.Alive then return end
            local desired = {}
            for _, label in ipairs(values) do if labels[label] then desired[labels[label]] = true end end
            state[desiredKey] = desired
        end})
end
addReroll("trait", "Traits", TRAIT_LIST, "tr", "selectedUnitKey", "desiredTraits")
input("trDelayBox", "Traits", "Trait roll delay (seconds)", state.traitRollDelay)
toggle("traitToggleBtn", "Traits", "Auto trait roll", function() return state.autoTrait end, TraitRollEvent ~= nil)
button("trNowBtn", "Traits", "Force single trait roll")
paragraph("trStats", "Traits", "Trait status")
addReroll("grade", "Grade", GRADE_LIST, "gr2", "selectedGradeUnitKey", "desiredGrades")
input("gr2DelayBox", "Grade", "Grade roll delay (seconds)", state.gradeRollDelay)
toggle("gradeToggleBtn", "Grade", "Auto grade roll", function() return state.autoGrade end, GradeRollEvent ~= nil)
button("gr2NowBtn", "Grade", "Force single grade roll")
paragraph("gr2Stats", "Grade", "Grade status")

toggle("dailyToggleBtn", "Daily", "Auto daily reward", function() return state.autoDaily end, DailyRewardEvent ~= nil)
button("dailyNowBtn", "Daily", "Claim daily reward now")
paragraph("dailyStats", "Daily", "Daily reward status")
toggle("grToggleBtn", "Group", "Auto group reward", function() return state.autoGroupReward end, GroupRewardEvent ~= nil)
input("grIntBox", "Group", "Group claim interval (seconds)", state.groupRewardInterval)
button("grNowBtn", "Group", "Claim group reward now")
paragraph("grStats", "Group", "Group claim count")
toggle("spinToggleBtn", "Spins", "Auto lucky spins", function() return state.autoLuckySpin end, SpinEvent ~= nil)
input("spinIntBox", "Spins", "Spin interval (seconds)", state.luckySpinInterval)
button("spinNowBtn", "Spins", "Use one lucky spin")
paragraph("spinStats", "Spins", "Lucky spin status")
toggle("questToggleBtn", "Quests", "Auto claim quests", function() return state.autoQuestClaim end, QuestClaimEvent ~= nil)
input("questIntBox", "Quests", "Quest claim interval (seconds)", state.questClaimInterval)
button("questClaimNowBtn", "Quests", "Claim all ready quests")
paragraph("questStatsLbl", "Quests", "Quest status")
local questRows = {}

local towerNames = {}
for _, tower in ipairs(TOWER_LIST) do table.insert(towerNames, tower.name) end
sections.Tower:CreateDropdown({Name = "Selected tower", Options = towerNames, CurrentOption = state.towerName,
    Callback = function(value)
        if not runtime.Alive then return end
        state.towerName = value
        gui.towerInfoLbl.Text = "Selected: " .. tostring(value)
    end})
toggle("towerToggleBtn", "Tower", "Auto tower", function() return state.autoTower end, PlayTowerFn ~= nil)
paragraph("towerInfoLbl", "Tower", "Tower status", "Selected: " .. state.towerName)
paragraph("towerStatsLbl", "Tower", "Tower results")
button("towerEquipBestBtn", "Team", "Equip best tower team")
paragraph("towerTeamLbl", "Team", "Tower team")
button("towerStartBtn", "Team", "Start selected tower")
button("towerCompleteBtn", "Team", "Complete next floor")
button("towerCancelBtn", "Team", "Cancel current tower")

toggle("csToggleBtn", "Settings", "Skip cutscenes", function() return state.skipCutscenes end)
paragraph("csStats", "Settings", "Skipped cutscenes")
toggle("slToggleBtn", "Settings", "Disable game shiftlock", function() return shiftlockEnabled end)
sections.Settings:CreateParagraph({Title = "Hub controls", Content = "Use the hub Settings page to change the menu key. Anime Dice shares the existing window, theme and interface controls."})
paragraph("statusLabel", "Session", "Session status", "Ready")
sections.Session:CreateButton({Name = "Stop all Anime Dice automation", Callback = function()
    if not runtime.Alive then return end
    for key in pairs(state) do if key:match("^auto") then state[key] = false end end
    state.skipCutscenes = false
    shiftlockEnabled = false
    for key in pairs(state) do
        if key:match("Thread$") then cancelLoop(key) end
    end
    syncToggles()
    gui.statusLabel.Text = "Anime Dice automation stopped. Controls remain available."
end})

local function openUnitPicker(mode)
    mode = mode or "trait"
    local units, equipped = listOwnedUnits(), getEquippedSlotMap()
    table.sort(units, function(a, b)
        local ar, br = getRarityScore(a.name), getRarityScore(b.name)
        if ar ~= br then return ar > br end
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.key) < tostring(b.key)
    end)
    local options, byLabel, current = {}, {}, nil
    local selected = mode == "grade" and state.selectedGradeUnitKey or state.selectedUnitKey
    for _, unit in ipairs(units) do
        if not equipped[unit.key] then
            local label = ("%s x%d | %s | %s | %s"):format(unit.name, unit.amount,
                tostring(unit.trait or "No trait"), tostring(unit.grade or "No grade"), tostring(unit.key))
            table.insert(options, label); byLabel[label] = unit
            if unit.key == selected then current = label end
        end
    end
    unitOptions[mode] = byLabel
    unitSelectors[mode]:Refresh(options, false)
    unitSelectors[mode]:Set(current, false)
    if not current then
        if mode == "grade" then state.selectedGradeUnitKey = nil else state.selectedUnitKey = nil end
        gui[mode == "grade" and "gr2UnitLbl" or "trUnitLbl"].Text = #options == 0
            and "No unequipped units available." or "Choose a unit from the dropdown."
    end
end

local function rebuildEquippedTab()
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then inv = {} end
    local equipped, bySlot, lines = getEquippedSlotMap(), {}, {}
    local equippedCount = 0
    for key, slot in pairs(equipped) do bySlot[tonumber(slot) or slot] = key; equippedCount = equippedCount + 1 end
    gui.eqPageInfoLbl.Text = ("%d units equipped"):format(equippedCount)
    local function attribute(value)
        if type(value) == "function" then local success, result = pcall(value); return success and result or "?" end
        return value or "-"
    end
    for slot = 1, PlotConfig.GetMaxSlots() do
        local required = PlotConfig.GetSlotRebirthRequirement(slot)
        local key = bySlot[slot]
        if getRebirth() < required then table.insert(lines, ("Slot %d: requires rebirth %d"):format(slot, required))
        elseif key then
            local unit = inv[key] or {}; local attrs = unit.attributes or {}
            table.insert(lines, ("Slot %d: %s | Lv.%s | %s | %s\nKey: %s"):format(slot, unit.name or "Unknown",
                tostring(attribute(attrs.level)), tostring(attribute(attrs.trait)), tostring(attribute(attrs.grade)), tostring(key)))
        else table.insert(lines, ("Slot %d: empty"):format(slot)) end
    end
    gui.equippedInventory.Text = table.concat(lines, "\n\n")
end
local function rebuildLevelTab()
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then inv = {} end
    local lines = {}
    for _, info in ipairs(getEquippedSlots()) do
        local unit = inv[info.unitId] or {}
        table.insert(lines, ("Slot %d: %s | Lv.%d / %d"):format(info.slot, unit.name or "Unknown", info.level, state.levelTarget))
    end
    gui.levelInventory.Text = #lines > 0 and table.concat(lines, "\n") or "No units equipped."
end
local function rebuildDiceTab()
    local money, equipped, owned, lines = getMoney(), getEquippedDice(), 0, {}
    for _, dice in ipairs(DICE_LIST) do
        local has = ownsDice(dice.name)
        if has then owned = owned + 1 end
        local status = equipped == dice.name and "Equipped" or (has and "Owned" or (money >= dice.price and "Affordable" or "Locked"))
        table.insert(lines, ("%s — %s\nLuck %s | $%s"):format(dice.name, status, tostring(dice.luck), fmt(dice.price)))
    end
    local nextDice = getNextLockedDice()
    gui.diceInfoLbl.Text = nextDice and ("%d/%d owned | Next: %s ($%s) | Can afford: %s"):format(
        owned, #DICE_LIST, nextDice.name, fmt(nextDice.price), money >= nextDice.price and "YES" or "NO")
        or ("%d/%d owned | All dice unlocked!"):format(owned, #DICE_LIST)
    gui.diceInventory.Text = #lines > 0 and table.concat(lines, "\n\n") or "No dice data available."
end
local function rebuildQuestsTab()
    local quests, ready = getAllQuestStatus(), 0
    local order = {Daily = 1, Weekly = 2}
    table.sort(quests, function(a, b)
        if a.ready ~= b.ready then return a.ready end
        if (order[a.period] or 99) ~= (order[b.period] or 99) then return (order[a.period] or 99) < (order[b.period] or 99) end
        return a.target < b.target
    end)
    for index, quest in ipairs(quests) do
        if quest.ready then ready = ready + 1 end
        local entry = questRows[index]
        if not entry then
            entry = {}; questRows[index] = entry
            entry.Info = sections.Quests:CreateParagraph({Title = "Quest", Content = ""})
            entry.Claim = sections.Quests:CreateButton({Name = "Claim quest", Callback = function()
                local q = entry.Quest
                if not runtime.Alive or not q or not q.ready or not QuestClaimEvent then return end
                task.spawn(function()
                    claimQuest(q.period, q.id, q.expiresAt)
                    task.wait(0.2)
                    rebuildQuestsTab()
                end)
            end})
        end
        entry.Quest = quest
        local status = quest.ready and "READY" or (quest.claimed and "CLAIMED" or (quest.expired and "EXPIRED" or "IN PROGRESS"))
        local progress = quest.id == "Playtime" and ("%s / %s"):format(os.date("!%H:%M:%S", quest.progress), os.date("!%H:%M:%S", quest.target))
            or ("%s / %s"):format(fmt(quest.progress), fmt(quest.target))
        entry.Info:Set({Title = quest.period .. " — " .. quest.title, Content = status .. "\n" .. progress .. "\nReward: " .. tostring(quest.tickets) .. " tickets"})
        entry.Info.Instance.Visible = true
        entry.Claim:Set("Claim " .. quest.title)
        entry.Claim:SetVisible(quest.ready and QuestClaimEvent ~= nil)
    end
    for index = #quests + 1, #questRows do
        questRows[index].Quest = nil
        questRows[index].Info.Instance.Visible = false
        questRows[index].Claim:SetVisible(false)
    end
    gui.questStatsLbl.Text = ("Tickets: %s | Claimed: %d | Ready: %d"):format(fmt(getTicketCount()), state.totalQuestsClaimed, ready)
        .. (#quests == 0 and "\nNo quest data available." or "")
end

local function rebuildTowerTeam()
    local ok, inv = pcall(function() return DataController.Inventory() end)
    if not ok or type(inv) ~= "table" then inv = {} end
    local team = getTowerTeam()
    if #team == 0 then
        gui.towerTeamLbl.Text = "Team: EMPTY (auto-equips when you start)"
        gui.towerTeamLbl.TextColor3 = Color3.fromRGB(230, 130, 130)
        return
    end
    local lines = {}
    for i, key in ipairs(team) do
        local entry = inv[key]
        local name = entry and entry.name or "?"
        table.insert(lines, ("%d. %s"):format(i, name))
    end
    gui.towerTeamLbl.Text = "Team: " .. table.concat(lines, " | ")
    gui.towerTeamLbl.TextColor3 = Color3.fromRGB(180, 255, 200)
end

-- ============================================================================

gui.delayBox.FocusLost:Connect(function()
    local n = tonumber(gui.delayBox.Text)
    if n then state.delay = math.clamp(n, 0.05, 10); gui.delayBox.Text = tostring(state.delay) end
end)
gui.rollToggleBtn.MouseButton1Click:Connect(function()
    if state.autoRoll then stopRollLoop(); setOnOff(gui.rollToggleBtn, false, "Stop Auto Roll", "Start Auto Roll")
    else startRollLoop(); setOnOff(gui.rollToggleBtn, true, "Stop Auto Roll", "Start Auto Roll") end
end)
gui.rollOnceBtn.MouseButton1Click:Connect(rollDice)

gui.upToggleBtn.MouseButton1Click:Connect(function()
    if state.autoUpgrade then stopUpgradeLoop(); setOnOff(gui.upToggleBtn, false, "Disable", "Disable Auto Upgrade")
    else startUpgradeLoop(); setOnOff(gui.upToggleBtn, true, "Disable Auto Upgrade", "Disable Auto Upgrade") end
end)
gui.upRescanBtn.MouseButton1Click:Connect(refreshOwned)

gui.rebirthToggleBtn.MouseButton1Click:Connect(function()
    if not RebirthEvent then return end
    if state.autoRebirth then stopRebirthLoop(); setOnOff(gui.rebirthToggleBtn, false, "Enable", "Disable Auto Rebirth")
    else startRebirthLoop(); setOnOff(gui.rebirthToggleBtn, true, "Disable Auto Rebirth", "Disable Auto Rebirth") end
end)

gui.towerToggleBtn.MouseButton1Click:Connect(function()
    if not PlayTowerFn then return end
    if state.autoTower then
        stopTowerLoop()
        gui.towerToggleBtn.Text = "Enable Auto Tower"
        gui.towerToggleBtn.BackgroundColor3 = COLORS.green
    else
        startTowerLoop()
        gui.towerToggleBtn.Text = "Disable Auto Tower"
        gui.towerToggleBtn.BackgroundColor3 = COLORS.red
    end
end)
gui.towerEquipBestBtn.MouseButton1Click:Connect(function()
    if equipBestTowerTeam() then
        task.wait(0.5)
        rebuildTowerTeam()
    end
end)
gui.towerStartBtn.MouseButton1Click:Connect(function()
    startTower(state.towerName)
end)
gui.towerCompleteBtn.MouseButton1Click:Connect(function()
    local seq = completeFloor()
    if not seq then
        gui.towerInfoLbl.Text = "Tower not in progress (or finished)"
        gui.towerInfoLbl.TextColor3 = COLORS.red
    else
        gui.towerInfoLbl.Text = ("Completed floor (%d actions)"):format(#seq)
        gui.towerInfoLbl.TextColor3 = Color3.fromRGB(180,255,180)
    end
end)
gui.towerCancelBtn.MouseButton1Click:Connect(function()
    cancelTower()
    gui.towerInfoLbl.Text = "Cancelled"
    gui.towerInfoLbl.TextColor3 = COLORS.textDim
end)

gui.colToggleBtn.MouseButton1Click:Connect(function()
    if state.autoCollect then stopCollectLoop(); setOnOff(gui.colToggleBtn, false, "Enable", "Disable Auto Collect")
    else startCollectLoop(); setOnOff(gui.colToggleBtn, true, "Disable Auto Collect", "Disable Auto Collect") end
end)
gui.colNowBtn.MouseButton1Click:Connect(collectAll)
gui.colIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.colIntBox.Text)
    if n then state.collectInterval = math.clamp(n, 0.5, 60); gui.colIntBox.Text = tostring(state.collectInterval) end
end)

gui.eqToggleBtn.MouseButton1Click:Connect(function()
    if state.autoEquipBest then stopEquipBestLoop(); setOnOff(gui.eqToggleBtn, false, "Enable", "Disable Auto Equip Best")
    else startEquipBestLoop(); setOnOff(gui.eqToggleBtn, true, "Disable Auto Equip Best", "Disable Auto Equip Best") end
end)
gui.eqIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.eqIntBox.Text)
    if n then state.equipBestInterval = math.clamp(n, 3, 600); gui.eqIntBox.Text = tostring(state.equipBestInterval) end
end)

gui.lvTargetBox.FocusLost:Connect(function()
    local n = tonumber(gui.lvTargetBox.Text)
    if n then state.levelTarget = math.clamp(math.floor(n), 1, 1000); gui.lvTargetBox.Text = tostring(state.levelTarget) end
end)
gui.lvToggleBtn.MouseButton1Click:Connect(function()
    if not LevelUpSlotEvent then return end
    if state.autoLevel then stopLevelLoop(); setOnOff(gui.lvToggleBtn, false, "Enable", "Enable Auto Level")
    else startLevelLoop(); setOnOff(gui.lvToggleBtn, true, "Disable Auto Level", "Enable Auto Level") end
end)
gui.lvNowBtn.MouseButton1Click:Connect(function()
    if not LevelUpSlotEvent then return end
    for _, info in ipairs(getEquippedSlots()) do levelUpSlot(info.slot) end
end)

gui.eqPageRefreshBtn.MouseButton1Click:Connect(rebuildEquippedTab)

gui.trPickBtn.MouseButton1Click:Connect(function() openUnitPicker("trait") end)
gui.trDelayBox.FocusLost:Connect(function()
    local n = tonumber(gui.trDelayBox.Text)
    if n then state.traitRollDelay = math.clamp(n, 0.1, 5); gui.trDelayBox.Text = tostring(state.traitRollDelay) end
end)
gui.traitToggleBtn.MouseButton1Click:Connect(function()
    if not TraitRollEvent then return end
    if state.autoTrait then
        stopTraitLoop()
        gui.traitToggleBtn.Text = "Enable Auto Trait"
        gui.traitToggleBtn.BackgroundColor3 = COLORS.green
    else
        local ok, err = startTraitLoop()
        if not ok then
            gui.trStats.Text = err == "no unit" and "Pick a unit first" or "Pick at least one trait"
            gui.trStats.TextColor3 = COLORS.red
            return
        end
        gui.traitToggleBtn.Text = "Disable Auto Trait"
        gui.traitToggleBtn.BackgroundColor3 = COLORS.red
    end
end)
gui.trNowBtn.MouseButton1Click:Connect(function()
    if not TraitRollEvent or not state.selectedUnitKey then return end
    if fireTraitRoll(state.selectedUnitKey) then state.totalTraitRolls = state.totalTraitRolls + 1 end
end)

gui.gr2PickBtn.MouseButton1Click:Connect(function() openUnitPicker("grade") end)
gui.gr2DelayBox.FocusLost:Connect(function()
    local n = tonumber(gui.gr2DelayBox.Text)
    if n then state.gradeRollDelay = math.clamp(n, 0.1, 5); gui.gr2DelayBox.Text = tostring(state.gradeRollDelay) end
end)
gui.gradeToggleBtn.MouseButton1Click:Connect(function()
    if not GradeRollEvent then return end
    if state.autoGrade then
        stopGradeLoop()
        gui.gradeToggleBtn.Text = "Enable Auto Grade"
        gui.gradeToggleBtn.BackgroundColor3 = COLORS.green
    else
        local ok, err = startGradeLoop()
        if not ok then
            gui.gr2Stats.Text = err == "no unit" and "Pick a unit first" or "Pick at least one grade"
            gui.gr2Stats.TextColor3 = COLORS.red
            return
        end
        gui.gradeToggleBtn.Text = "Disable Auto Grade"
        gui.gradeToggleBtn.BackgroundColor3 = COLORS.red
    end
end)
gui.gr2NowBtn.MouseButton1Click:Connect(function()
    if not GradeRollEvent or not state.selectedGradeUnitKey then return end
    if fireGradeRoll(state.selectedGradeUnitKey) then state.totalGradeRolls = state.totalGradeRolls + 1 end
end)

gui.diceToggleBtn.MouseButton1Click:Connect(function()
    if not BuyDiceEvent then return end
    if state.autoBuyDice then stopBuyDiceLoop(); setOnOff(gui.diceToggleBtn, false, "Enable", "Enable Auto Buy Dice")
    else startBuyDiceLoop(); setOnOff(gui.diceToggleBtn, true, "Disable Auto Buy Dice", "Enable Auto Buy Dice") end
end)
gui.buyDiceIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.buyDiceIntBox.Text)
    if n then state.buyDiceInterval = math.clamp(n, 0.5, 600); gui.buyDiceIntBox.Text = tostring(state.buyDiceInterval) end
end)
gui.diceNowBtn.MouseButton1Click:Connect(function()
    if not BuyDiceEvent then return end
    local money = getMoney()
    local bought = 0
    for _, d in ipairs(DICE_LIST) do
        if not ownsDice(d.name) and money >= d.price then
            if buyDice(d.name) then bought = bought + 1; task.wait(0.3); money = getMoney() end
        end
    end
    gui.diceInfoLbl.Text = ("Bought %d dice"):format(bought)
end)
gui.diceEquipBestBtn.MouseButton1Click:Connect(function()
    if not EquipDiceEvent then return end
    local best = nil
    for _, d in ipairs(DICE_LIST) do
        if ownsDice(d.name) and (not best or d.luck > best.luck) then best = d end
    end
    if best then
        equipDice(best.name)
        gui.diceInfoLbl.Text = ("Equipped: %s (luck %s)"):format(best.name, tostring(best.luck))
    else
        gui.diceInfoLbl.Text = "No dice owned"
    end
end)

gui.dailyToggleBtn.MouseButton1Click:Connect(function()
    if not DailyRewardEvent then return end
    if state.autoDaily then stopDailyLoop(); setOnOff(gui.dailyToggleBtn, false, "Enable", "Disable Auto Daily")
    else startDailyLoop(); setOnOff(gui.dailyToggleBtn, true, "Disable Auto Daily", "Disable Auto Daily") end
end)
gui.dailyNowBtn.MouseButton1Click:Connect(function()
    if not DailyRewardEvent then return end
    if claimDaily() then
        gui.dailyStats.Text = "Claimed!"; gui.dailyStats.TextColor3 = COLORS.green
    else
        gui.dailyStats.Text = isDailyReady() and "Claim failed" or "Not ready"
        gui.dailyStats.TextColor3 = COLORS.red
    end
end)

gui.questToggleBtn.MouseButton1Click:Connect(function()
    if not QuestClaimEvent then return end
    if state.autoQuestClaim then stopQuestClaimLoop(); setOnOff(gui.questToggleBtn, false, "Enable", "Disable Auto Claim")
    else startQuestClaimLoop(); setOnOff(gui.questToggleBtn, true, "Disable Auto Claim", "Disable Auto Claim") end
end)
gui.questIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.questIntBox.Text)
    if n then state.questClaimInterval = math.clamp(n, 1, 300); gui.questIntBox.Text = tostring(state.questClaimInterval) end
end)
gui.questClaimNowBtn.MouseButton1Click:Connect(function()
    if not QuestClaimEvent then return end
    local all = getAllQuestStatus()
    local claimed = 0
    for _, q in ipairs(all) do
        if q.ready then
            if claimQuest(q.period, q.id, q.expiresAt) then
                claimed = claimed + 1
                state.totalQuestsClaimed = state.totalQuestsClaimed + 1
                task.wait(0.3)
            end
        end
    end
    gui.questStatsLbl.Text = ("Claimed %d quests"):format(claimed)
    task.wait(0.5)
    rebuildQuestsTab()
end)

gui.spinToggleBtn.MouseButton1Click:Connect(function()
    if not SpinEvent then return end
    if state.autoLuckySpin then stopLuckySpinLoop(); setOnOff(gui.spinToggleBtn, false, "Enable", "Enable Auto Lucky Spin")
    else startLuckySpinLoop(); setOnOff(gui.spinToggleBtn, true, "Disable Auto Lucky Spin", "Enable Auto Lucky Spin") end
end)
gui.spinIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.spinIntBox.Text)
    if n then state.luckySpinInterval = math.clamp(n, 0.5, 600); gui.spinIntBox.Text = tostring(state.luckySpinInterval) end
end)
gui.spinNowBtn.MouseButton1Click:Connect(function()
    if getLuckySpinCount() <= 0 then
        gui.spinStats.Text = "No spins"; gui.spinStats.TextColor3 = COLORS.red
        return
    end
    useLuckySpin()
end)

gui.grToggleBtn.MouseButton1Click:Connect(function()
    if not GroupRewardEvent then return end
    if state.autoGroupReward then stopGroupRewardLoop(); setOnOff(gui.grToggleBtn, false, "Enable", "Enable Auto Group Claim")
    else startGroupRewardLoop(); setOnOff(gui.grToggleBtn, true, "Disable Auto Group Claim", "Enable Auto Group Claim") end
end)
gui.grIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.grIntBox.Text)
    if n then state.groupRewardInterval = math.clamp(n, 5, 600); gui.grIntBox.Text = tostring(state.groupRewardInterval) end
end)
gui.grNowBtn.MouseButton1Click:Connect(claimGroupReward)

gui.sellToggleBtn.MouseButton1Click:Connect(function()
    if not SellEvent then return end
    if state.autoSell then stopSellLoop(); setOnOff(gui.sellToggleBtn, false, "Enable", "Enable Auto Sell")
    else startSellLoop(); setOnOff(gui.sellToggleBtn, true, "Disable Auto Sell", "Enable Auto Sell") end
end)
gui.sellIntBox.FocusLost:Connect(function()
    local n = tonumber(gui.sellIntBox.Text)
    if n then state.sellInterval = math.clamp(n, 3, 600); gui.sellIntBox.Text = tostring(state.sellInterval) end
end)
gui.sellNowBtn.MouseButton1Click:Connect(function()
    if not SellEvent then return end
    local ok, n = sellInventory()
    gui.sellStats.Text = ok and ("Sold %d units"):format(n) or "Sell failed"
end)

gui.csToggleBtn.MouseButton1Click:Connect(function()
    state.skipCutscenes = not state.skipCutscenes
    setOnOff(gui.csToggleBtn, state.skipCutscenes, "Disable", "Disable Cutscene Skip")
end)

gui.slToggleBtn.MouseButton1Click:Connect(function()
    shiftlockEnabled = not shiftlockEnabled
    if shiftlockEnabled then
        gui.slToggleBtn.Text = "Shiftlock Disabled"; gui.slToggleBtn.BackgroundColor3 = COLORS.red
    else
        gui.slToggleBtn.Text = "Shiftlock Enabled"; gui.slToggleBtn.BackgroundColor3 = COLORS.green
    end
end)


local _eqTick = 0
local _lvTick = 0
local _diceTick = 0
local _questTick = 0
local _towerTick = 0
task.spawn(function()
    while runtime.Alive and gui.sg and gui.sg.Parent do
        syncToggles()
        local money = getMoney()
        gui.moneyLabel.Text = "$" .. fmt(money)

        local elapsed = os.clock() - state.startTime
        gui.rollStats.Text = ("Rolls: %d | per sec: %.2f\nStatus: %s"):format(
            state.totalRolls, state.totalRolls / math.max(elapsed, 1),
            state.autoRoll and "Rolling" or "Idle")

        local ownedCount = 0
        for _ in pairs(state.ownedUpgrades) do ownedCount = ownedCount + 1 end
        gui.upOwnedLbl.Text = ("Owned: %d / %d"):format(ownedCount, #UPGRADES)
        local nextTarget
        for _, up in ipairs(UPGRADES) do
            if not state.ownedUpgrades[up.name] and canBuy(up.name) then nextTarget = up; break end
        end
        if nextTarget then
            gui.upNextLbl.Text = ("Next: %s (%s)"):format(nextTarget.name, fmt(nextTarget.price))
        else
            gui.upNextLbl.Text = "All reachable owned!"
        end

        do
            local rb = getRebirth()
            local cost = getRebirthCost()
            if cost then
                local afford = money >= cost and "YES" or "NO"
                gui.rebirthInfoLbl.Text = ("Rebirth: %d | Next: %s\nCan afford: %s"):format(rb, fmt(cost), afford)
                gui.rebirthInfoLbl.TextColor3 = money >= cost
                    and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(180, 200, 230)
            else
                gui.rebirthInfoLbl.Text = ("Rebirth: %d | MAX"):format(rb)
                gui.rebirthInfoLbl.TextColor3 = Color3.fromRGB(120, 255, 120)
            end
            gui.rebirthStatsLbl.Text = ("Rebirths fired: %d"):format(state.totalRebirths)
        end

        do
            local rb = getRebirth()
            local unlocked = 0
            for i = 1, PlotConfig.GetMaxSlots() do
                if rb >= PlotConfig.GetSlotRebirthRequirement(i) then unlocked = unlocked + 1 end
            end
            gui.colStats.Text = ("Collected: %d total\nRebirth: %d | Slots: %d/%d"):format(
                state.totalCollects, rb, unlocked, PlotConfig.GetMaxSlots())
            gui.eqStats.Text = ("Equips: %d"):format(state.totalEquipBests)
        end

        if os.clock() - _lvTick > 2 then _lvTick = os.clock(); pcall(rebuildLevelTab) end
        gui.lvStats.Text = ("Levels: %d | Target: Lv.%d"):format(state.totalLevelUps, state.levelTarget)

        if state.selectedUnitKey then
            local t = getUnitTrait(state.selectedUnitKey)
            gui.trStats.Text = ("Rolls: %d | Current: %s"):format(state.totalTraitRolls, tostring(t or "None"))
            gui.trStats.TextColor3 = (t and state.desiredTraits[t]) and COLORS.green or Color3.fromRGB(180,255,180)
        else
            gui.trStats.Text = ("Rolls: %d | No unit"):format(state.totalTraitRolls)
            gui.trStats.TextColor3 = Color3.fromRGB(180,255,180)
        end

        if state.selectedGradeUnitKey then
            local g = getUnitGrade(state.selectedGradeUnitKey)
            gui.gr2Stats.Text = ("Rolls: %d | Current: %s\nGems: %d"):format(
                state.totalGradeRolls, tostring(g or "None"), getGemCount())
            gui.gr2Stats.TextColor3 = (g and state.desiredGrades[g]) and COLORS.green or Color3.fromRGB(180,255,180)
        else
            gui.gr2Stats.Text = ("Rolls: %d | No unit\nGems: %d"):format(state.totalGradeRolls, getGemCount())
            gui.gr2Stats.TextColor3 = Color3.fromRGB(180,255,180)
        end

        if os.clock() - _eqTick > 2 then _eqTick = os.clock(); pcall(rebuildEquippedTab) end
        if os.clock() - _diceTick > 2 then _diceTick = os.clock(); pcall(rebuildDiceTab) end
        if os.clock() - _questTick > 3 then _questTick = os.clock(); pcall(rebuildQuestsTab) end
        if os.clock() - _towerTick > 2 then _towerTick = os.clock(); pcall(rebuildTowerTeam) end

        do
            local mode = "Idle"
            if state.autoTower then mode = state.towerInProgress and "Running" or "Starting" end
            gui.towerStatsLbl.Text = ("Towers completed: %d | Floors: %d\nMode: %s"):format(
                state.totalTowersCompleted, state.totalTowerFloors, mode)
        end

        if DailyRewardEvent then
            if isDailyReady() then
                gui.dailyStats.Text = ("Ready | Claims: %d"):format(state.totalDailyClaims)
                gui.dailyStats.TextColor3 = Color3.fromRGB(120,255,120)
            else
                local ok, last = pcall(function() return DataController.LastDailyRewardClaim() end)
                local remaining = 0
                if ok and type(last) == "number" and last > 0 then
                    remaining = math.max(0, DailyRewardConfig.Cooldown - (os.time() - last))
                end
                local h = math.floor(remaining / 3600)
                local m = math.floor((remaining % 3600) / 60)
                local s = remaining % 60
                gui.dailyStats.Text = ("%02dh%02dm%02ds | Claims: %d"):format(h, m, s, state.totalDailyClaims)
                gui.dailyStats.TextColor3 = COLORS.textDim
            end
        end

        if SpinEvent then
            local avail = getLuckySpinCount()
            gui.spinStats.Text = ("Used: %d | Available: %d"):format(state.totalLuckySpins, avail)
            gui.spinStats.TextColor3 = avail > 0 and Color3.fromRGB(180,255,180) or COLORS.textDim
        end
        if GroupRewardEvent then gui.grStats.Text = ("Claims: %d"):format(state.totalGroupClaims) end
        if SellEvent then gui.sellStats.Text = ("Sold: %d units"):format(state.totalSells) end
        gui.csStats.Text = ("Skipped: %d cutscenes"):format(state.totalCutscenesSkipped)

        task.wait(0.5)
    end
end)



setOnOff(gui.rollToggleBtn, false, "Stop", "Start Auto Roll")
setOnOff(gui.upToggleBtn, true, "Disable Auto Upgrade", "Disable Auto Upgrade")
setOnOff(gui.colToggleBtn, true, "Disable Auto Collect", "Disable Auto Collect")
setOnOff(gui.eqToggleBtn, true, "Disable Auto Equip Best", "Disable Auto Equip Best")
setOnOff(gui.csToggleBtn, true, "Disable", "Disable Cutscene Skip")
gui.slToggleBtn.Text = "Shiftlock Disabled"
gui.slToggleBtn.BackgroundColor3 = COLORS.red

startUpgradeLoop()
startCollectLoop()
startEquipBestLoop()

if RebirthEvent then startRebirthLoop(); setOnOff(gui.rebirthToggleBtn, true, "Disable Auto Rebirth", "Disable Auto Rebirth") end
if GroupRewardEvent then setOnOff(gui.grToggleBtn, false, "Enable", "Enable Auto Group Claim") end
if SpinEvent then setOnOff(gui.spinToggleBtn, false, "Enable", "Enable Auto Lucky Spin") end
if SellEvent then setOnOff(gui.sellToggleBtn, false, "Enable", "Enable Auto Sell") end
if LevelUpSlotEvent then setOnOff(gui.lvToggleBtn, false, "Enable", "Enable Auto Level") end
if BuyDiceEvent then setOnOff(gui.diceToggleBtn, false, "Enable", "Enable Auto Buy Dice") end
if PlayTowerFn then
    gui.towerToggleBtn.Text = "Enable Auto Tower"
    gui.towerToggleBtn.BackgroundColor3 = COLORS.green
end
if DailyRewardEvent then
    startDailyLoop()
    setOnOff(gui.dailyToggleBtn, true, "Disable Auto Daily", "Disable Auto Daily")
end
if QuestClaimEvent then
    startQuestClaimLoop()
    setOnOff(gui.questToggleBtn, true, "Disable Auto Claim", "Disable Auto Claim")
end

print("[AutoRoll] All systems initialized.")

openUnitPicker("trait")
openUnitPicker("grade")
syncToggles()
pcall(rebuildEquippedTab)
pcall(rebuildLevelTab)
pcall(rebuildDiceTab)
pcall(rebuildQuestsTab)
pcall(rebuildTowerTeam)
pcall(function()
    local observer = DataController.Upgrades.Observe(function()
        if runtime.Alive then refreshOwned() end
    end)
    if observer then table.insert(runtime.Connections, observer) end
end)
    end -- initialize
    local ok, failure = xpcall(initialize, debug.traceback)
    if not ok then restore(); error("Anime Dice initialization failed: " .. tostring(failure), 0) end
    if not runtime.Alive then return false end
    runtime.Ready = true
    return true
end
