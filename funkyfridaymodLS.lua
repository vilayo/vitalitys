-- vitality's hub / Funky Friday / 1.0.0-LS
-- Production module built around the tested V21 exact-clock autoplay engine.
-- Universe/GameId: 2404080894 | Observed PlaceId: 6447798030

return function(context)
    assert(type(context) == "table", "Funky Friday requires a module context")

    local Library = assert(
        context.Library or context.NovaField,
        "Vitality library missing"
    )

    local Window = assert(
        context.Window,
        "Vitality window missing"
    )

    local Players = game:GetService("Players")
    local LocalPlayer = assert(Players.LocalPlayer, "Funky Friday requires a Roblox client")
    local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

    local BUILD_KEY = "__VITALITY_FUNKY_FRIDAY_MODULE_BUILD_STATE"
    local CONTROL_NAME = "__VITALITY_FF_MODULE_V1"

    local previous = rawget(_G, BUILD_KEY)
    if type(previous) == "table"
        and previous.Window == Window
        and previous.Ready == true
        and previous.Alive == true then
        return true
    end

    if type(previous) == "table" and type(previous.Restore) == "function" then
        pcall(previous.Restore)
    end

    local state = {
        Window = Window,
        Alive = true,
        Ready = false,
        Connections = {},
        Controls = {},
        StatusControls = {},
        Tab = nil,
        Controller = nil,
    }

    rawset(_G, BUILD_KEY, state)

    local function track(connection)
        if connection then
            table.insert(state.Connections, connection)
        end
        return connection
    end

    local function disconnectAll()
        for _, connection in ipairs(state.Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        state.Connections = {}
    end

    local function notify(title, content, notificationType, duration)
        pcall(function()
            Window:Notify({
                Title = title,
                Content = content,
                Type = notificationType,
                Duration = duration or 4,
            })
        end)
    end

    local function restore()
        if not state.Alive then
            return
        end

        state.Alive = false
        state.Ready = false

        disconnectAll()

        local controller = state.Controller
        if controller and controller.Parent then
            local enabled = controller:FindFirstChild("Enabled")
            if enabled and enabled:IsA("BoolValue") then
                enabled.Value = false
            end
            task.wait(0.05)
            pcall(function()
                controller:Destroy()
            end)
        end

        state.Controller = nil

        if rawget(_G, BUILD_KEY) == state then
            rawset(_G, BUILD_KEY, nil)
        end
    end

    state.Restore = restore
    Window:AddCleanup(restore)

    -- ============================================================
    -- SHARED CONTROLLER VALUES
    -- ============================================================

    local oldController = PlayerScripts:FindFirstChild(CONTROL_NAME)
    if oldController then
        oldController:Destroy()
    end

    local controller = Instance.new("Folder")
    controller.Name = CONTROL_NAME
    controller.Parent = PlayerScripts
    state.Controller = controller

    local function makeBool(name, value)
        local object = Instance.new("BoolValue")
        object.Name = name
        object.Value = value == true
        object.Parent = controller
        return object
    end

    local function makeNumber(name, value)
        local object = Instance.new("NumberValue")
        object.Name = name
        object.Value = tonumber(value) or 0
        object.Parent = controller
        return object
    end

    local function makeString(name, value)
        local object = Instance.new("StringValue")
        object.Name = name
        object.Value = tostring(value or "")
        object.Parent = controller
        return object
    end

    local EngineEnabled = makeBool("Enabled", false)
    local BackgroundAutoplay = makeBool("BackgroundAutoplay", true)
    local MenuAutoplay = makeBool("MenuAutoplay", true)
    local DebugLogging = makeBool("Debug", false)

    local HitOffsetMs = makeNumber("OffsetMs", 0)
    local TapDurationMs = makeNumber("TapDurationMs", 18)
    local HoldReleaseOffsetMs = makeNumber("HoldReleaseOffsetMs", 0)
    local CustomJitterMs = makeNumber("CustomJitterMs", 8)
    local AccuracyMode = makeString("AccuracyMode", "Perfect")

    local RuntimeStatus = makeString("RuntimeStatus", "Starting")
    local StatsAvailable = makeBool("StatsAvailable", false)
    local StatAccuracy = makeNumber("StatAccuracy", 0)
    local StatCombo = makeNumber("StatCombo", 0)
    local StatMisses = makeNumber("StatMisses", 0)
    local StatMeanMS = makeNumber("StatMeanMS", 0)
    local StatScore = makeNumber("StatScore", 0)

    -- ============================================================
    -- UI
    -- ============================================================

    local okUI, uiError = pcall(function()
        local tab = Window:CreateTab("Funky Friday", "funky-friday")
        state.Tab = tab

        local autoplay = tab:CreateSection({
            Name = "Autoplay",
            Description = "Exact chart timing through Funky Friday's real VSRG input path.",
            Icon = "automation",
            Side = "Left",
        })

        state.Controls.Autoplay = autoplay:CreateToggle({
            Name = "Autoplay",
            Info = "Uses the game's internal note times and normal player InputActions, so score and judgments register normally.",
            Flag = "FunkyFriday_Autoplay",
            CurrentValue = false,
            Callback = function(value)
                if state.Alive and EngineEnabled.Parent then
                    EngineEnabled.Value = value == true
                end
            end,
        })

        state.Controls.Background = autoplay:CreateToggle({
            Name = "Background Autoplay",
            Info = "Keeps autoplay active when the Roblox window loses focus or you tab into another application.",
            Flag = "FunkyFriday_BackgroundAutoplay",
            CurrentValue = true,
            Callback = function(value)
                if state.Alive and BackgroundAutoplay.Parent then
                    BackgroundAutoplay.Value = value == true
                end
            end,
        })

        state.Controls.Menu = autoplay:CreateToggle({
            Name = "Menu Autoplay",
            Info = "Keeps the VSRG input handler active while Roblox's Escape menu is open.",
            Flag = "FunkyFriday_MenuAutoplay",
            CurrentValue = true,
            Callback = function(value)
                if state.Alive and MenuAutoplay.Parent then
                    MenuAutoplay.Value = value == true
                end
            end,
        })

        autoplay:CreateParagraph({
            Title = "Engine",
            Content = "This module prewarms the current chart before StageAudio starts, then reacquires VSRG objects across song changes, resets, and settings rebuilds.",
        })

        local timing = tab:CreateSection({
            Name = "Accuracy & Timing",
            Description = "Control hit timing without changing Funky Friday's scoring path.",
            Icon = "timer",
            Side = "Left",
        })

        state.Controls.AccuracyMode = timing:CreateDropdown({
            Name = "Accuracy Mode",
            Info = "Perfect uses exact chart time. Humanized adds a small safe random offset. Custom uses the jitter range below.",
            Flag = "FunkyFriday_AccuracyMode",
            Options = {"Perfect", "Humanized", "Custom"},
            CurrentOption = "Perfect",
            Callback = function(value)
                if type(value) == "table" then
                    value = value[1]
                end
                value = tostring(value or "Perfect")
                if value ~= "Humanized" and value ~= "Custom" then
                    value = "Perfect"
                end
                if state.Alive and AccuracyMode.Parent then
                    AccuracyMode.Value = value
                end
            end,
        })

        state.Controls.HitOffset = timing:CreateSlider({
            Name = "Hit Offset",
            Info = "Adds a fixed offset to every note. Negative values hit earlier; positive values hit later.",
            Flag = "FunkyFriday_HitOffset",
            Range = {-75, 75},
            Increment = 1,
            Suffix = " ms",
            CurrentValue = 0,
            Callback = function(value)
                if state.Alive and HitOffsetMs.Parent then
                    HitOffsetMs.Value = math.clamp(tonumber(value) or 0, -75, 75)
                end
            end,
        })

        state.Controls.HoldOffset = timing:CreateSlider({
            Name = "Hold Release Offset",
            Info = "Adjusts only the release time of sustain notes.",
            Flag = "FunkyFriday_HoldReleaseOffset",
            Range = {-75, 75},
            Increment = 1,
            Suffix = " ms",
            CurrentValue = 0,
            Callback = function(value)
                if state.Alive and HoldReleaseOffsetMs.Parent then
                    HoldReleaseOffsetMs.Value = math.clamp(tonumber(value) or 0, -75, 75)
                end
            end,
        })

        state.Controls.CustomJitter = timing:CreateSlider({
            Name = "Custom Jitter",
            Info = "Used only by Custom accuracy mode. Each note receives one stable random offset inside this +/- range.",
            Flag = "FunkyFriday_CustomJitter",
            Range = {0, 20},
            Increment = 1,
            Suffix = " ms",
            CurrentValue = 8,
            Callback = function(value)
                if state.Alive and CustomJitterMs.Parent then
                    CustomJitterMs.Value = math.clamp(tonumber(value) or 8, 0, 20)
                end
            end,
        })

        timing:CreateParagraph({
            Title = "Humanized mode",
            Content = "Humanized currently uses a bounded +/-7 ms per-note jitter. Custom allows 0-20 ms. Hold release timing stays independent so sustains remain reliable.",
        })

        local stats = tab:CreateSection({
            Name = "Live Statistics",
            Description = "Read directly from the active VSRG HUD statistics object when available.",
            Icon = "dashboard",
            Side = "Right",
        })

        state.StatusControls.Engine = stats:CreateStatus({
            Name = "Engine",
            CurrentValue = "Starting",
        })

        state.StatusControls.Accuracy = stats:CreateStatus({
            Name = "Accuracy",
            CurrentValue = "--",
        })

        state.StatusControls.Combo = stats:CreateStatus({
            Name = "Combo",
            CurrentValue = "--",
        })

        state.StatusControls.Misses = stats:CreateStatus({
            Name = "Misses",
            CurrentValue = "--",
        })

        state.StatusControls.MeanMS = stats:CreateStatus({
            Name = "Mean MS",
            CurrentValue = "--",
        })

        state.StatusControls.Score = stats:CreateStatus({
            Name = "Score",
            CurrentValue = "--",
        })

        local developer = tab:CreateSection({
            Name = "Developer",
            Description = "Runtime diagnostics for testing new Funky Friday builds.",
            Icon = "logs",
            Side = "Right",
        })

        state.Controls.Debug = developer:CreateToggle({
            Name = "Debug Logging",
            Info = "Print chart acquisition, focus/menu bypass, and note timing diagnostics to the executor console.",
            Flag = "FunkyFriday_DebugLogging",
            CurrentValue = false,
            Callback = function(value)
                if state.Alive and DebugLogging.Parent then
                    DebugLogging.Value = value == true
                end
            end,
        })

        state.RuntimeParagraph = developer:CreateParagraph({
            Title = "Runtime",
            Content = "Waiting for the Actor controller to initialize.",
        })

        -- Constructors restore saved flags but do not invoke callbacks.
        EngineEnabled.Value = state.Controls.Autoplay:Get() == true
        BackgroundAutoplay.Value = state.Controls.Background:Get() == true
        MenuAutoplay.Value = state.Controls.Menu:Get() == true
        DebugLogging.Value = state.Controls.Debug:Get() == true

        local savedMode = state.Controls.AccuracyMode:Get()
        if type(savedMode) == "table" then
            savedMode = savedMode[1]
        end
        savedMode = tostring(savedMode or "Perfect")
        if savedMode ~= "Humanized" and savedMode ~= "Custom" then
            savedMode = "Perfect"
        end
        AccuracyMode.Value = savedMode

        HitOffsetMs.Value = math.clamp(tonumber(state.Controls.HitOffset:Get()) or 0, -75, 75)
        HoldReleaseOffsetMs.Value = math.clamp(tonumber(state.Controls.HoldOffset:Get()) or 0, -75, 75)
        CustomJitterMs.Value = math.clamp(tonumber(state.Controls.CustomJitter:Get()) or 8, 0, 20)
    end)

    if not okUI then
        restore()
        error("Funky Friday UI initialization failed: " .. tostring(uiError), 0)
    end

    -- ============================================================
    -- LIVE UI READOUTS
    -- ============================================================

    local function formatAccuracy(value)
        value = tonumber(value) or 0
        if math.abs(value) <= 1.0001 then
            value = value * 100
        end
        return string.format("%.2f%%", value)
    end

    local function refreshStats()
        if not state.Alive then
            return
        end

        if state.StatusControls.Engine then
            state.StatusControls.Engine:Set(RuntimeStatus.Value ~= "" and RuntimeStatus.Value or "Starting")
        end

        if StatsAvailable.Value then
            state.StatusControls.Accuracy:Set(formatAccuracy(StatAccuracy.Value))
            state.StatusControls.Combo:Set(tostring(math.floor(StatCombo.Value + 0.5)))
            state.StatusControls.Misses:Set(tostring(math.floor(StatMisses.Value + 0.5)))
            state.StatusControls.MeanMS:Set(string.format("%+.1f ms", StatMeanMS.Value))
            state.StatusControls.Score:Set(tostring(math.floor(StatScore.Value + 0.5)))
        else
            state.StatusControls.Accuracy:Set("--")
            state.StatusControls.Combo:Set("--")
            state.StatusControls.Misses:Set("--")
            state.StatusControls.MeanMS:Set("--")
            state.StatusControls.Score:Set("--")
        end

        if state.RuntimeParagraph then
            state.RuntimeParagraph:Set({
                Content = (
                    "Engine: %s\nAccuracy mode: %s\nHit offset: %d ms | Hold release: %d ms\nBackground: %s | Escape menu: %s"
                ):format(
                    tostring(RuntimeStatus.Value),
                    tostring(AccuracyMode.Value),
                    math.floor(HitOffsetMs.Value + (HitOffsetMs.Value >= 0 and 0.5 or -0.5)),
                    math.floor(HoldReleaseOffsetMs.Value + (HoldReleaseOffsetMs.Value >= 0 and 0.5 or -0.5)),
                    BackgroundAutoplay.Value and "On" or "Off",
                    MenuAutoplay.Value and "On" or "Off"
                )
            })
        end
    end

    track(RuntimeStatus.Changed:Connect(refreshStats))
    track(StatsAvailable.Changed:Connect(refreshStats))
    track(StatAccuracy.Changed:Connect(refreshStats))
    track(StatCombo.Changed:Connect(refreshStats))
    track(StatMisses.Changed:Connect(refreshStats))
    track(StatMeanMS.Changed:Connect(refreshStats))
    track(StatScore.Changed:Connect(refreshStats))
    track(AccuracyMode.Changed:Connect(refreshStats))
    track(HitOffsetMs.Changed:Connect(refreshStats))
    track(HoldReleaseOffsetMs.Changed:Connect(refreshStats))
    track(BackgroundAutoplay.Changed:Connect(refreshStats))
    track(MenuAutoplay.Changed:Connect(refreshStats))

    refreshStats()

    -- ============================================================
    -- V21 ACTOR ENGINE
    -- ============================================================

    local actor = PlayerScripts:FindFirstChild("ClientActor")
    local runActor =
        (type(run_on_actor) == "function" and run_on_actor)
        or
        (type(runonactor) == "function" and runonactor)

    if not actor or not runActor then
        RuntimeStatus.Value = "Executor unsupported"
        notify(
            "Funky Friday",
            "This executor does not expose ClientActor execution required by the autoplay engine.",
            "failed",
            6
        )
        state.Ready = true
        return true
    end

    local source = [==[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local player = assert(Players.LocalPlayer)
local playerScripts = player:WaitForChild("PlayerScripts")
local playerGui = player:WaitForChild("PlayerGui")
local control = playerScripts:WaitForChild("__VITALITY_FF_MODULE_V1")

local enabled = control:WaitForChild("Enabled")
local backgroundAutoplay = control:WaitForChild("BackgroundAutoplay")
local menuAutoplay = control:WaitForChild("MenuAutoplay")
local debugValue = control:WaitForChild("Debug")
local offsetValue = control:WaitForChild("OffsetMs")
local tapDurationValue = control:WaitForChild("TapDurationMs")
local holdReleaseOffsetValue = control:WaitForChild("HoldReleaseOffsetMs")
local customJitterValue = control:WaitForChild("CustomJitterMs")
local accuracyModeValue = control:WaitForChild("AccuracyMode")

local runtimeStatus = control:WaitForChild("RuntimeStatus")
local statsAvailable = control:WaitForChild("StatsAvailable")
local statAccuracy = control:WaitForChild("StatAccuracy")
local statCombo = control:WaitForChild("StatCombo")
local statMisses = control:WaitForChild("StatMisses")
local statMeanMS = control:WaitForChild("StatMeanMS")
local statScore = control:WaitForChild("StatScore")

assert(type(getgc) == "function", "Actor getgc unavailable")

local getConnections = type(getconnections) == "function" and getconnections or nil
local getConstants =
    (type(getconstants) == "function" and getconstants)
    or (debug and type(debug.getconstants) == "function" and debug.getconstants)
    or nil
local canFireSignal = type(firesignal) == "function"

local function log(...)
    if debugValue.Value then
        print("[Vitality FF]", ...)
    end
end

local function setRuntimeStatus(value)
    value = tostring(value or "")
    if runtimeStatus.Value ~= value then
        runtimeStatus.Value = value
    end
end

local connections = {}
local function track(connection)
    if connection then
        table.insert(connections, connection)
    end
    return connection
end

local vsrgContext = nil
local Actions = {nil, nil, nil, nil}
local inputGeneration = 0
local runtimeEpoch = 0

local field = nil
local inputHandler = nil
local suppressionReasons = nil
local updateContextEnabled = nil
local statsObject = nil

local songClock = nil
local songGeneration = 0
local lastSongClockTime = nil
local lastClockSearch = 0
local CLOCK_SEARCH_INTERVAL = 0.15

local focused = true
local menuOpen = false
local syntheticFocused = false
local focusSuppressions = {}
local menuSuppressions = {}
local menuFieldOriginals = {}
local menuStateHandler = nil

local handled = setmetatable({}, {__mode = "k"})
local noteJitter = setmetatable({}, {__mode = "k"})
local random = Random.new()

local laneDown = {false, false, false, false}
local laneHolding = {false, false, false, false}
local laneReleaseAt = {nil, nil, nil, nil}
local lanePressGeneration = {nil, nil, nil, nil}

local averageDt = 1 / 60
local totalHits = 0
local HOLD_THRESHOLD = 0.035

local scanRunning = false
local scanRequested = false
local scanReason = nil
local scanNotBefore = 0
local lastScan = -math.huge
local MIN_SCAN_GAP = 1.50
local FAILED_SCAN_RETRY = 1.50

local lastStatsUpdate = 0
local STATS_UPDATE_INTERVAL = 0.12

local function getMethod(object, name)
    if type(object) ~= "table" then
        return nil
    end

    local direct
    local okDirect = pcall(function()
        direct = rawget(object, name)
    end)
    if okDirect and type(direct) == "function" then
        return direct
    end

    local mt = nil
    if type(getrawmetatable) == "function" then
        local ok, value = pcall(getrawmetatable, object)
        if ok and type(value) == "table" then
            mt = value
        end
    end
    if not mt then
        local ok, value = pcall(getmetatable, object)
        if ok and type(value) == "table" then
            mt = value
        end
    end
    if type(mt) ~= "table" then
        return nil
    end

    local indexValue
    local okIndex = pcall(function()
        indexValue = rawget(mt, "__index")
    end)
    if not okIndex or type(indexValue) ~= "table" then
        return nil
    end

    local method
    local okMethod = pcall(function()
        method = rawget(indexValue, name)
    end)
    if okMethod and type(method) == "function" then
        return method
    end
    return nil
end

local function validField(candidate)
    return type(candidate) == "table"
        and rawget(candidate, "PlayingField") == true
        and rawget(candidate, "OwnedBotPlayerConfig") == nil
        and type(rawget(candidate, "NoteCache")) == "table"
        and type(rawget(candidate, "Game")) == "table"
end

local function fieldTime(candidate)
    if not validField(candidate) then
        return nil
    end
    local gameObject = rawget(candidate, "Game")
    local value = rawget(gameObject, "TimePosition")
    return type(value) == "number" and value or nil
end

local function countNotes(candidate)
    if not validField(candidate) then
        return 0
    end
    local cache = rawget(candidate, "NoteCache")
    local count = 0
    for _, note in pairs(cache) do
        if type(note) == "table"
            and type(rawget(note, "Time")) == "number"
            and type(rawget(note, "LaneIndex")) == "number" then
            count += 1
        end
    end
    return count
end

local function clearLaneState()
    for lane = 1, 4 do
        laneDown[lane] = false
        laneHolding[lane] = false
        laneReleaseAt[lane] = nil
        lanePressGeneration[lane] = nil
    end
end

local function clearChartState()
    table.clear(handled)
    table.clear(noteJitter)
    clearLaneState()
end

local function requestScan(reason, delayAmount)
    local requestedTime = os.clock() + (tonumber(delayAmount) or 0)
    if not scanRequested then
        scanRequested = true
        scanNotBefore = requestedTime
    else
        scanNotBefore = math.min(scanNotBefore, requestedTime)
    end
    scanReason = reason or scanReason or "runtime"
end

local lastInputCheck = 0
local INPUT_CHECK_INTERVAL = 0.08

local function resolveInputs(force)
    local now = os.clock()
    if not force and now - lastInputCheck < INPUT_CHECK_INTERVAL then
        return vsrgContext ~= nil
            and Actions[1] ~= nil
            and Actions[2] ~= nil
            and Actions[3] ~= nil
            and Actions[4] ~= nil
    end

    lastInputCheck = now
    local currentContext = playerGui:FindFirstChild("VSRGContext")

    if currentContext ~= vsrgContext then
        local previous = vsrgContext
        vsrgContext = currentContext
        inputGeneration += 1
        runtimeEpoch += 1
        for lane = 1, 4 do
            Actions[lane] = nil
        end
        clearChartState()
        field = nil
        statsObject = nil
        statsAvailable.Value = false
        log("VSRGContext", tostring(previous), "->", tostring(currentContext))
        if currentContext then
            setRuntimeStatus("Prewarming")
            requestScan("VSRG prewarm", 0.05)
        else
            setRuntimeStatus("Waiting for song")
        end
    end

    if not vsrgContext then
        return false
    end

    local changed = false
    for lane = 1, 4 do
        local current = vsrgContext:FindFirstChild("Lane" .. lane)
        if current ~= Actions[lane] then
            Actions[lane] = current
            inputGeneration += 1
            changed = true
            log("Lane" .. lane, "->", tostring(current))
        end
    end

    if changed then
        clearLaneState()
        requestScan("lane actions ready", 0.05)
    end

    return Actions[1] ~= nil
        and Actions[2] ~= nil
        and Actions[3] ~= nil
        and Actions[4] ~= nil
end

local function onSongBoundary(reason)
    songGeneration += 1
    clearChartState()
    statsObject = nil
    statsAvailable.Value = false
    log("song generation", songGeneration, reason)
end

local function resolveSongClock(force)
    local now = os.clock()
    if not force and now - lastClockSearch < CLOCK_SEARCH_INTERVAL then
        return songClock
    end
    lastClockSearch = now

    local best = nil
    local bestLength = 0
    for _, object in ipairs(SoundService:GetDescendants()) do
        if object:IsA("AudioPlayer") then
            local ok, playing, length = pcall(function()
                return object.IsPlaying, object.TimeLength
            end)
            if ok and playing and length > 5 then
                local objectName = tostring(object.Name)
                local parentName = tostring(object.Parent and object.Parent.Name or "")
                local stageLike = objectName:find("StageSound", 1, true)
                    or parentName:find("StageAudio", 1, true)
                if stageLike and length > bestLength then
                    best = object
                    bestLength = length
                end
            end
        end
    end

    if best ~= songClock then
        songClock = best
        lastSongClockTime = best and best.TimePosition or nil
        if best then
            log("new song clock", best:GetFullName())
            onSongBoundary("new StageAudio")
            requestScan("song clock", 0)
        else
            setRuntimeStatus(vsrgContext and "Prewarming" or "Waiting for song")
            log("song clock cleared")
        end
        return songClock
    end

    if best then
        local current = best.TimePosition
        if lastSongClockTime and current < lastSongClockTime - 1 then
            onSongBoundary("clock reset")
            requestScan("clock reset", 0)
        end
        lastSongClockTime = current
    end

    return songClock
end

local function handlerScore(candidate)
    if type(candidate) ~= "table" then
        return nil
    end
    local reasons = rawget(candidate, "SuppressionReasons")
    local actions = rawget(candidate, "Actions")
    if type(reasons) ~= "table" or type(actions) ~= "table" then
        return nil
    end
    local update = getMethod(candidate, "UpdateContextEnabled")
    if type(update) ~= "function" then
        return nil
    end

    local score = 100
    local playContext = rawget(candidate, "PlayContext")
    if typeof(playContext) == "Instance" then
        if playContext.Parent then score += 15 end
        if playContext == vsrgContext then score += 20 end
    end
    if validField(rawget(candidate, "Field")) then
        score += 50
    end
    return score
end

local function tryHandlerField()
    if type(inputHandler) ~= "table" then
        return false
    end
    local candidate = rawget(inputHandler, "Field")
    if not validField(candidate) then
        return false
    end
    if field ~= candidate then
        field = candidate
        clearChartState()
        log("PlayingField acquired from InputHandler.Field")
    end
    return true
end

local function scoreField(candidate, audioTime)
    if not validField(candidate) then
        return nil
    end
    local notes = countNotes(candidate)
    if notes <= 0 then
        return nil
    end

    local score = notes
    local gameTime = fieldTime(candidate)
    if audioTime and gameTime then
        local delta = math.abs(gameTime - audioTime)
        if delta > 3.0 then
            return nil
        end
        score += 3000 - delta * 1000
    else
        score += notes * 10
    end
    return score
end

local function numericField(candidate, key)
    if type(candidate) ~= "table" then
        return nil
    end
    local value = rawget(candidate, key)
    if type(value) == "number" then
        return value
    end
    if typeof(value) == "Instance" and value:IsA("ValueBase") then
        return tonumber(value.Value)
    end
    return nil
end

local function baseStatsScore(candidate)
    if type(candidate) ~= "table" then
        return nil
    end
    local keys = {"Accuracy", "Combo", "Misses", "MeanMS", "ScoreValue"}
    local present = 0
    for _, key in ipairs(keys) do
        if numericField(candidate, key) ~= nil then
            present += 1
        end
    end
    if present < 3 then
        return nil
    end
    return present * 10
end

local function chooseStatsCandidate(candidates, selectedField)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil
    end

    local fieldGuid = selectedField and (rawget(selectedField, "GUID") or rawget(selectedField, "FieldGUID")) or nil
    local best, bestScore = nil, -math.huge

    for _, entry in ipairs(candidates) do
        local score = entry.Score or 0
        local object = entry.Object
        if fieldGuid ~= nil then
            local candidateGuid = rawget(object, "FieldGUID") or rawget(object, "GUID")
            if candidateGuid == fieldGuid then
                score += 200
            end
        end
        if score > bestScore then
            best = object
            bestScore = score
        end
    end

    return best
end

local function runtimeScan()
    if scanRunning or not control.Parent then
        return
    end
    if not resolveInputs(true) then
        return
    end

    local now = os.clock()
    if now - lastScan < MIN_SCAN_GAP then
        return
    end

    scanRunning = true
    scanRequested = false
    local thisEpoch = runtimeEpoch
    local reason = scanReason or "runtime"
    scanReason = nil
    lastScan = now

    local clock = resolveSongClock(true)
    local audioTime = clock and clock.TimePosition or nil
    setRuntimeStatus(audioTime and "Acquiring chart" or "Prewarming")
    log("runtime scan start", reason, audioTime and string.format("audio=%.3f", audioTime) or "pre-song")

    local started = os.clock()
    local okScan, scanError = pcall(function()
        local objects = getgc(true)
        local bestField, bestFieldScore = nil, -math.huge
        local bestHandler, bestHandlerScore = nil, -math.huge
        local statsCandidates = {}

        for index, object in ipairs(objects) do
            if type(object) == "table" then
                local hs = handlerScore(object)
                if hs and hs > bestHandlerScore then
                    bestHandler = object
                    bestHandlerScore = hs
                end

                local fs = scoreField(object, audioTime)
                if fs and fs > bestFieldScore then
                    bestField = object
                    bestFieldScore = fs
                end

                local ss = baseStatsScore(object)
                if ss then
                    table.insert(statsCandidates, {Object = object, Score = ss})
                end
            end

            if index % 3500 == 0 then
                task.wait()
            end
        end

        if thisEpoch ~= runtimeEpoch then
            log("discarded stale runtime scan")
            requestScan("runtime changed during scan", 0.10)
            return
        end

        if bestHandler then
            if bestHandler ~= inputHandler and menuStateHandler then
                for key, value in pairs(menuFieldOriginals) do
                    pcall(function()
                        rawset(menuStateHandler, key, value)
                    end)
                end
                menuFieldOriginals = {}
                menuStateHandler = nil
            end

            inputHandler = bestHandler
            suppressionReasons = rawget(bestHandler, "SuppressionReasons")
            updateContextEnabled = getMethod(bestHandler, "UpdateContextEnabled")
            log("InputHandler acquired")
        end

        if not tryHandlerField() and bestField then
            if field ~= bestField then
                field = bestField
                clearChartState()
                log("PlayingField acquired from scan")
            end
        end

        statsObject = chooseStatsCandidate(statsCandidates, field)
        statsAvailable.Value = statsObject ~= nil
    end)

    scanRunning = false
    log(string.format("runtime scan finished %.0fms", (os.clock() - started) * 1000))

    if not okScan then
        warn("[Vitality FF] runtime scan error:", scanError)
        setRuntimeStatus("Scan retry")
        requestScan("scan retry", FAILED_SCAN_RETRY)
        return
    end

    if validField(field) then
        setRuntimeStatus(enabled.Value and "Playing" or "Ready")
    else
        setRuntimeStatus("Waiting for chart")
    end

    if not inputHandler or not validField(field) then
        requestScan("incomplete acquisition", FAILED_SCAN_RETRY)
    end
end

local function snapshotReasons()
    local result = {}
    if type(suppressionReasons) ~= "table" then
        return result
    end
    for key, value in pairs(suppressionReasons) do
        result[key] = value
    end
    return result
end

local function learnSuppression(before, destination, label)
    if type(suppressionReasons) ~= "table" then
        return
    end
    for key, value in pairs(suppressionReasons) do
        local previous = before[key]
        local added = previous == nil and value ~= nil and value ~= false
        local activated = previous == false and value == true
        local changed = previous ~= nil and previous ~= value
        if added or activated or changed then
            destination[key] = true
            log("learned " .. label .. " suppression", tostring(key))
        end
    end
end

local function clearLearned(learned)
    if type(suppressionReasons) ~= "table" then
        return false
    end
    local changed = false
    for key in pairs(learned) do
        if rawget(suppressionReasons, key) ~= nil then
            rawset(suppressionReasons, key, nil)
            changed = true
        end
    end
    if changed and inputHandler and type(updateContextEnabled) == "function" then
        pcall(updateContextEnabled, inputHandler)
    end
    return changed
end

local function enforceContext()
    resolveInputs(false)
    if vsrgContext then
        pcall(function()
            vsrgContext.Enabled = true
        end)
    end
    for lane = 1, 4 do
        local action = Actions[lane]
        if action then
            pcall(function()
                action.Enabled = true
            end)
        end
    end
    if inputHandler then
        local playContext = rawget(inputHandler, "PlayContext")
        if typeof(playContext) == "Instance" then
            pcall(function()
                playContext.Enabled = true
            end)
        end
        if type(updateContextEnabled) == "function" then
            pcall(updateContextEnabled, inputHandler)
        end
    end
end

local function tellGameFocused()
    if not canFireSignal then
        return false
    end
    syntheticFocused = true
    local ok = pcall(firesignal, UserInputService.WindowFocused)
    syntheticFocused = false
    return ok
end

local function functionSource(fn)
    if type(fn) ~= "function" then
        return ""
    end
    if debug and type(debug.info) == "function" then
        local ok, value = pcall(debug.info, fn, "s")
        if ok and type(value) == "string" then
            return value
        end
    end
    return ""
end

local function functionLooksLikeInputHandler(fn)
    local sourceName = functionSource(fn):lower()
    if sourceName:find("inputhandler", 1, true)
        and sourceName:find("vsrg", 1, true) then
        return true
    end

    if not getConstants then
        return false
    end

    local ok, constants = pcall(getConstants, fn)
    if not ok or type(constants) ~= "table" then
        return false
    end

    local score = 0
    for _, constant in pairs(constants) do
        if type(constant) == "string" then
            local lower = constant:lower()
            if lower:find("menuisopen", 1, true) then score += 3 end
            if lower:find("robloxmenu", 1, true) then score += 3 end
            if lower:find("updatecontextenabled", 1, true) then score += 4 end
            if lower:find("vsrg", 1, true) then score += 2 end
        end
    end
    return score >= 6
end

local function connectionCallback(connection)
    local callback = nil
    pcall(function() callback = connection.Function end)
    if type(callback) ~= "function" then
        pcall(function() callback = connection.Callback end)
    end
    if type(callback) ~= "function" then
        pcall(function() callback = connection.Func end)
    end
    return type(callback) == "function" and callback or nil
end

local function invokeTargetedMenuClosed()
    if not getConnections then
        return false
    end

    local ok, list = pcall(getConnections, GuiService.MenuClosed)
    if not ok or type(list) ~= "table" then
        return false
    end

    for _, connection in ipairs(list) do
        local callback = connectionCallback(connection)
        if callback and functionLooksLikeInputHandler(callback) then
            local called, err = pcall(callback)
            if called then
                log("invoked targeted InputHandler MenuClosed callback")
                return true
            end
            log("targeted MenuClosed callback failed", err)
        end
    end

    return false
end

local function applyMenuHandlerStateBypass()
    if type(inputHandler) ~= "table" then
        return false
    end

    if menuStateHandler and menuStateHandler ~= inputHandler then
        for key, value in pairs(menuFieldOriginals) do
            pcall(function()
                rawset(menuStateHandler, key, value)
            end)
        end
        menuFieldOriginals = {}
    end

    menuStateHandler = inputHandler
    local changed = false
    for _, key in ipairs({"MenuIsOpen", "RobloxMenu"}) do
        local ok, value = pcall(rawget, inputHandler, key)
        if ok and type(value) == "boolean" and value == true then
            if menuFieldOriginals[key] == nil then
                menuFieldOriginals[key] = value
            end
            pcall(rawset, inputHandler, key, false)
            changed = true
            log("bypassed handler field", key)
        end
    end
    return changed
end

local function restoreMenuHandlerState()
    if not menuStateHandler then
        return
    end
    for key, value in pairs(menuFieldOriginals) do
        pcall(function()
            rawset(menuStateHandler, key, value)
        end)
    end
    menuFieldOriginals = {}
    menuStateHandler = nil
end

track(UserInputService.WindowFocusReleased:Connect(function()
    focused = false
    local before = snapshotReasons()
    log("actual window unfocused")
    task.delay(0.04, function()
        if not control.Parent or focused or not backgroundAutoplay.Value then
            return
        end
        learnSuppression(before, focusSuppressions, "focus")
        tellGameFocused()
        clearLearned(focusSuppressions)
        enforceContext()
    end)
end))

track(UserInputService.WindowFocused:Connect(function()
    if syntheticFocused then
        return
    end
    focused = true
    log("actual window focused")
end))

local function onMenuOpened()
    if menuOpen then
        return
    end
    menuOpen = true
    local before = snapshotReasons()
    log("Roblox menu opened")
    task.delay(0.05, function()
        if not control.Parent or not menuOpen or not menuAutoplay.Value then
            return
        end
        learnSuppression(before, menuSuppressions, "menu")
        local targeted = invokeTargetedMenuClosed()
        applyMenuHandlerStateBypass()
        clearLearned(menuSuppressions)
        enforceContext()
        log("menu bypass applied", "targeted=", targeted)
    end)
end

local function onMenuClosed()
    if not menuOpen then
        return
    end
    menuOpen = false
    restoreMenuHandlerState()
    enforceContext()
    log("Roblox menu closed")
end

track(GuiService.MenuOpened:Connect(onMenuOpened))
track(GuiService.MenuClosed:Connect(onMenuClosed))

local lastObservedMenuState = false
pcall(function()
    lastObservedMenuState = GuiService.MenuIsOpen
end)
if lastObservedMenuState then
    menuOpen = true
end

local function updateMenuState()
    local ok, current = pcall(function()
        return GuiService.MenuIsOpen
    end)
    if not ok or current == lastObservedMenuState then
        return
    end
    lastObservedMenuState = current
    if current then
        onMenuOpened()
    else
        onMenuClosed()
    end
end

local function releaseLane(lane)
    if not laneDown[lane] then
        laneHolding[lane] = false
        laneReleaseAt[lane] = nil
        lanePressGeneration[lane] = nil
        return
    end

    resolveInputs(true)
    enforceContext()
    local action = Actions[lane]
    if action and lanePressGeneration[lane] == inputGeneration then
        pcall(function()
            action:Fire(false)
        end)
    end
    laneDown[lane] = false
    laneHolding[lane] = false
    laneReleaseAt[lane] = nil
    lanePressGeneration[lane] = nil
end

local function releaseAll()
    for lane = 1, 4 do
        releaseLane(lane)
    end
end

local function noteJitterSeconds(note)
    local cached = noteJitter[note]
    if cached ~= nil then
        return cached
    end

    local mode = tostring(accuracyModeValue.Value or "Perfect")
    local rangeMs = 0
    if mode == "Humanized" then
        rangeMs = 7
    elseif mode == "Custom" then
        rangeMs = math.clamp(tonumber(customJitterValue.Value) or 8, 0, 20)
    end

    local jitter = 0
    if rangeMs > 0 then
        -- Triangular distribution clusters most hits near the intended time while
        -- still producing a natural spread inside the selected +/- bound.
        jitter = ((random:NextNumber() + random:NextNumber()) - 1) * rangeMs / 1000
    end

    noteJitter[note] = jitter
    return jitter
end

local function pressLane(lane, releaseAt, isHold)
    if not resolveInputs(true) then
        return false
    end

    if not focused and backgroundAutoplay.Value then
        clearLearned(focusSuppressions)
        tellGameFocused()
        enforceContext()
    end

    if menuOpen and menuAutoplay.Value then
        applyMenuHandlerStateBypass()
        clearLearned(menuSuppressions)
        enforceContext()
    end

    local action = Actions[lane]
    if not action then
        return false
    end

    if laneDown[lane] and lanePressGeneration[lane] ~= inputGeneration then
        laneDown[lane] = false
        laneHolding[lane] = false
        laneReleaseAt[lane] = nil
        lanePressGeneration[lane] = nil
    end

    if laneDown[lane] and not laneHolding[lane] then
        pcall(function()
            action:Fire(false)
        end)
        laneDown[lane] = false
    end

    if laneDown[lane] and laneHolding[lane] then
        laneReleaseAt[lane] = math.max(laneReleaseAt[lane] or releaseAt, releaseAt)
        return true
    end

    local ok, err = pcall(function()
        action:Fire(true)
    end)
    if not ok then
        warn("[Vitality FF] InputAction press failed:", lane, err)
        return false
    end

    laneDown[lane] = true
    laneHolding[lane] = isHold == true
    laneReleaseAt[lane] = releaseAt
    lanePressGeneration[lane] = inputGeneration
    return true
end

local function characterLifecycle(reason)
    releaseAll()
    field = nil
    statsObject = nil
    statsAvailable.Value = false
    clearChartState()
    runtimeEpoch += 1
    scanRequested = false
    setRuntimeStatus("Waiting for song")
    log("character lifecycle", reason)
end

track(player.CharacterRemoving:Connect(function()
    characterLifecycle("removing")
end))

track(player.CharacterAdded:Connect(function()
    characterLifecycle("added")
end))

local function updateStats()
    if os.clock() - lastStatsUpdate < STATS_UPDATE_INTERVAL then
        return
    end
    lastStatsUpdate = os.clock()

    if type(statsObject) ~= "table" then
        statsAvailable.Value = false
        return
    end

    local accuracy = numericField(statsObject, "Accuracy")
    local combo = numericField(statsObject, "Combo")
    local misses = numericField(statsObject, "Misses")
    local meanMS = numericField(statsObject, "MeanMS")
    local score = numericField(statsObject, "ScoreValue")

    local present = 0
    if accuracy ~= nil then statAccuracy.Value = accuracy; present += 1 end
    if combo ~= nil then statCombo.Value = combo; present += 1 end
    if misses ~= nil then statMisses.Value = misses; present += 1 end
    if meanMS ~= nil then statMeanMS.Value = meanMS; present += 1 end
    if score ~= nil then statScore.Value = score; present += 1 end
    statsAvailable.Value = present >= 3
end

resolveInputs(true)
if vsrgContext then
    requestScan("initial prewarm", 0.05)
end
setRuntimeStatus(vsrgContext and "Prewarming" or "Waiting for song")

track(RunService.Heartbeat:Connect(function(dt)
    if not control.Parent then
        return
    end

    resolveInputs(false)
    updateMenuState()
    local clock = resolveSongClock(false)

    if not validField(field) then
        tryHandlerField()
    end

    if clock and validField(field) then
        local ft = fieldTime(field)
        local audioTime = clock.TimePosition
        if not ft or math.abs(ft - audioTime) > 3.0 then
            field = nil
            statsObject = nil
            statsAvailable.Value = false
            clearChartState()
            tryHandlerField()
            if not validField(field) then
                requestScan("stale field", 0)
            end
        end
    end

    if scanRequested
        and not scanRunning
        and os.clock() >= scanNotBefore
        and os.clock() - lastScan >= MIN_SCAN_GAP then
        task.spawn(runtimeScan)
    end

    if menuOpen and menuAutoplay.Value then
        applyMenuHandlerStateBypass()
        clearLearned(menuSuppressions)
        enforceContext()
    end

    if not focused and backgroundAutoplay.Value then
        clearLearned(focusSuppressions)
        enforceContext()
    end

    updateStats()

    if not enabled.Value then
        releaseAll()
        if validField(field) then
            setRuntimeStatus("Ready")
        end
        return
    end

    if not validField(field) then
        setRuntimeStatus(clock and "Waiting for chart" or "Prewarming")
        return
    end

    local gameObject = rawget(field, "Game")
    local songTime = rawget(gameObject, "TimePosition")
    if type(songTime) ~= "number" then
        field = nil
        requestScan("missing TimePosition", 0.10)
        return
    end

    setRuntimeStatus("Playing")

    averageDt += (math.clamp(dt, 0.001, 0.150) - averageDt) * 0.15

    for lane = 1, 4 do
        local releaseAt = laneReleaseAt[lane]
        if releaseAt and songTime >= releaseAt then
            releaseLane(lane)
        end
    end

    local schedulerLead = averageDt * 0.45
    if focused and not menuOpen then
        schedulerLead = math.clamp(schedulerLead, 0.001, 0.012)
    else
        schedulerLead = math.clamp(schedulerLead + 0.008, 0.004, 0.035)
    end

    local userOffset = offsetValue.Value / 1000
    local tapDuration = tapDurationValue.Value / 1000
    local holdOffset = holdReleaseOffsetValue.Value / 1000

    local cache = rawget(field, "NoteCache")
    if type(cache) ~= "table" then
        field = nil
        requestScan("missing NoteCache", 0.10)
        return
    end

    for _, note in pairs(cache) do
        if type(note) == "table" and not handled[note] then
            local noteTime = rawget(note, "Time")
            local lane = rawget(note, "LaneIndex")
            local length = tonumber(rawget(note, "Length")) or 0

            if type(noteTime) == "number"
                and type(lane) == "number"
                and lane >= 1
                and lane <= 4 then

                if noteTime < songTime - 0.075 then
                    handled[note] = true
                else
                    local jitter = noteJitterSeconds(note)
                    local fireAt = noteTime + userOffset + jitter - schedulerLead
                    if songTime >= fireAt then
                        handled[note] = true
                        totalHits += 1

                        local isHold = length > HOLD_THRESHOLD
                        local releaseAt
                        if isHold then
                            releaseAt = noteTime + length + holdOffset
                        else
                            releaseAt = songTime + tapDuration
                        end

                        local success = pressLane(lane, releaseAt, isHold)
                        log(string.format(
                            "%s #%d note=%s lane=%d target=%.4f now=%.4f err=%+.2fms jitter=%+.2fms len=%.3f success=%s",
                            isHold and "HOLD" or "TAP",
                            totalHits,
                            tostring(rawget(note, "Index") or "?"),
                            lane,
                            noteTime,
                            songTime,
                            (songTime - noteTime) * 1000,
                            jitter * 1000,
                            length,
                            tostring(success)
                        ))
                    end
                end
            end
        end
    end
end))

local cleaned = false
local function cleanup()
    if cleaned then
        return
    end
    cleaned = true
    pcall(releaseAll)
    pcall(restoreMenuHandlerState)
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
    setRuntimeStatus("Stopped")
    log("Actor cleanup complete")
end

track(control.AncestryChanged:Connect(function()
    if not control.Parent then
        cleanup()
    end
end))

setRuntimeStatus("Prewarming")
log("production engine loaded")
]==]

    RuntimeStatus.Value = "Starting Actor"

    local okActor, actorError = pcall(runActor, actor, source)
    if not okActor then
        RuntimeStatus.Value = "Engine failed"
        notify(
            "Funky Friday",
            "The Actor autoplay controller could not start: " .. tostring(actorError),
            "failed",
            6
        )
    else
        RuntimeStatus.Value = "Prewarming"
    end

    state.Ready = true
    refreshStats()

    notify(
        "Funky Friday",
        "Funky Friday controls loaded. Autoplay is ready to prewarm the next chart.",
        nil,
        3
    )

    return true
end
