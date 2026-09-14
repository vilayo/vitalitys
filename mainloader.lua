-- vitality's hub / main loader
-- Production-style game detection registry for Vitality Hub V2.8.3.3+
-- Supported production modules: The Tower, Apocalypse Rising 2, Murder Mystery 2, Flick
-- This is the ONE script/loadstring users execute.
-- Current hosted mainloader reference supplied by user: https://pastebin.com/raw/jDFLeUSy

local LIBRARY_URL = "https://vitalitys.lol/library.lua"

-- Paste the raw URL of the already-hosted The Tower module here.
local THE_TOWER_MODULE_URL = "https://vitalitys.lol/towermod.lua"

-- Murder Mystery 2 production module.
local MM2_MODULE_URL = "https://vitalitys.lol/mm2mod.lua"

-- Apocalypse Rising 2 module.
-- Upload VitalityHub_ApocalypseRising2_Module_v1_02.txt to Pastebin, then
-- replace REPLACE_APOC2_RAW_ID below with that paste's raw ID.
local APOCALYPSE_RISING_2_MODULE_URL =
    "https://vitalitys.lol/ar2mod.lua"

-- Flick production module.
-- Host the generated flickmod.lua at this URL.
local FLICK_MODULE_URL = "https://vitalitys.lol/flickmod.lua"

-- Generic Vitality component interface used when the current game is unsupported.
local FALLBACK_MODULE_URL = "https://vitalitys.lol/fallbackmod.lua"

-- Roblox universe IDs (game.GameId), NOT the place ID shown in the /games/ URL.
-- The Tower by LegosAreGood05:
--   Universe/GameId: 6701101774
--   Root PlaceId:    108645141774564
local THE_TOWER_GAME_ID = 6701101774

-- Apocalypse Rising 2 by Dualpoint Interactive.
-- game.GameId / universe ID: 358276974
-- root PlaceId:              863266079
local APOCALYPSE_RISING_2_GAME_ID = 358276974

-- Murder Mystery 2 by Nikilis.
-- game.GameId / universe ID: 66654135
-- root PlaceId:              142823291
local MM2_GAME_ID = 66654135

-- [FPS] Flick by Groundwork.
-- game.GameId / universe ID: 8795154789
-- root PlaceId:              136801880565837
local FLICK_GAME_ID = 8795154789

local NovaField = loadstring(game:HttpGet(LIBRARY_URL, true))()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ============================================================
-- KEYAUTH REMOTE LICENSING
-- API v1.3 does not require the old application secret.
-- ============================================================
local KEYAUTH = {
    Endpoint = "https://keyauth.win/api/1.3/",
    Name = "Vitality Hub",
    OwnerId = "KIh5ceamAF",
    Version = "1.0",
    SessionId = nil,
}

local function urlEncode(value)
    return HttpService:UrlEncode(tostring(value or ""))
end

local function keyAuthRequest(parameters)
    local parts = {}
    for key, value in pairs(parameters) do
        if value ~= nil then
            table.insert(parts, urlEncode(key) .. "=" .. urlEncode(value))
        end
    end
    table.sort(parts)

    local url = KEYAUTH.Endpoint .. "?" .. table.concat(parts, "&")

    local ok, responseText = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not ok then
        return nil, "Could not contact KeyAuth: " .. tostring(responseText)
    end

    local decodeOk, response = pcall(HttpService.JSONDecode, HttpService, responseText)
    if not decodeOk or type(response) ~= "table" then
        return nil, "KeyAuth returned an unreadable response."
    end

    return response
end

local function initializeKeyAuth()
    if KEYAUTH.SessionId then
        return true
    end

    local response, requestError = keyAuthRequest({
        type = "init",
        ver = KEYAUTH.Version,
        name = KEYAUTH.Name,
        ownerid = KEYAUTH.OwnerId,
        hash = "undefined",
        token = "undefined",
        thash = "undefined",
    })

    if not response then
        return false, requestError
    end

    if response.success ~= true then
        return false, tostring(response.message or "KeyAuth initialization failed.")
    end

    local sessionId = tostring(response.sessionid or "")
    if sessionId == "" then
        return false, "KeyAuth initialized without returning a session."
    end

    KEYAUTH.SessionId = sessionId
    return true
end

local function getKeyAuthIdentity()
    -- Roblox executors do not expose one universal HWID API. For now Vitality
    -- binds a license to the Roblox account, which is stable and predictable.
    -- We can swap this for an executor HWID later if you specifically want that.
    local player = Players.LocalPlayer
    return player and ("roblox-user-" .. tostring(player.UserId)) or "roblox-user-unknown"
end

local function validateKeyAuthLicense(licenseKey)
    local initialized, initError = initializeKeyAuth()
    if not initialized then
        return false, {
            Provider = "KeyAuth",
            Message = initError or "KeyAuth could not initialize.",
        }
    end

    local response, requestError = keyAuthRequest({
        type = "license",
        key = licenseKey,
        sessionid = KEYAUTH.SessionId,
        name = KEYAUTH.Name,
        ownerid = KEYAUTH.OwnerId,
        hwid = getKeyAuthIdentity(),
    })

    if not response then
        return false, {
            Provider = "KeyAuth",
            Message = requestError or "Could not validate license.",
        }
    end

    if response.success ~= true then
        local message = tostring(response.message or "Invalid license.")
        local lower = message:lower()

        return false, {
            Provider = "KeyAuth",
            Message = lower:find("expir", 1, true)
                and "this key has expired and is not usable!"
                or message,
            Expired = lower:find("expir", 1, true) ~= nil,
        }
    end

    local info = type(response.info) == "table" and response.info or {}
    local subscription
    if type(info.subscriptions) == "table" then
        subscription = info.subscriptions[1]
    end

    local expiresAt = subscription and tonumber(subscription.expiry) or nil
    local timeLeft = subscription and tonumber(subscription.timeleft) or nil

    -- KeyAuth returns both an absolute expiry and a live timeleft value.
    -- Prefer timeleft when present so dashboard edits immediately become the
    -- in-game countdown source on the next validation/poll.
    if timeLeft and timeLeft >= 0 then
        expiresAt = os.time() + timeLeft
    end

    local permanent =
        (expiresAt == nil or expiresAt <= 0)
        and not (timeLeft and timeLeft > 0)

    return true, {
        Provider = "KeyAuth",
        Message = tostring(response.message or "Logged in"),
        Username = info.username,
        Subscription = subscription and subscription.subscription or nil,
        ExpiresAt = expiresAt,
        TimeLeft = timeLeft,
        Permanent = permanent,
    }
end


-- ============================================================
-- SUPPORTED GAME REGISTRY
-- Add future games here. Nothing is registered dynamically from game.GameId.
-- ============================================================
local SupportedGames = {
    [THE_TOWER_GAME_ID] = {
        Name = "The Tower",
        Version = "1.9.14",
        Module = THE_TOWER_MODULE_URL,
        Status = "green",
        Label = "Fully working",
    },

    [MM2_GAME_ID] = {
        Name = "Murder Mystery 2",
        Version = "4.4",
        Module = MM2_MODULE_URL,
        Status = "green",
        Label = "Fully working",
    },

    [APOCALYPSE_RISING_2_GAME_ID] = {
        Name = "Apocalypse Rising 2",
        Version = "1.02",
        Module = APOCALYPSE_RISING_2_MODULE_URL,

        -- Keep this yellow until the Vitality conversion is tested once in-game.
        Status = "yellow",
        Label = "Testing",
    },

    [FLICK_GAME_ID] = {
        Name = "Flick",
        Version = "2.9.0",
        Module = FLICK_MODULE_URL,
        Status = "green",
        Label = "Fully working",
    },
}

-- Optional exact-place overrides can be added later. These take priority over
-- the universe/game registration when Vitality performs detection.
local SupportedPlaces = {
    -- [PLACE_ID] = {
    --     Name = "Specific place name",
    --     Module = "https://pastebin.com/raw/...",
    --     Status = "green",
    --     Label = "Fully working",
    -- },
}

-- Register only the explicit IDs above.
for gameId, profile in pairs(SupportedGames) do
    NovaField:RegisterGame(gameId, profile)
end

for placeId, profile in pairs(SupportedPlaces) do
    NovaField:RegisterPlace(placeId, profile)
end

-- Build the local status manifest from the SAME registry so detection and
-- the status chip cannot accidentally disagree about which games are supported.
local StatusGames = {}
local StatusPlaces = {}

for gameId, profile in pairs(SupportedGames) do
    StatusGames[gameId] = {
        Status = profile.Status or "yellow",
        Label = profile.Label or "Status unknown",
    }
end

for placeId, profile in pairs(SupportedPlaces) do
    StatusPlaces[placeId] = {
        Status = profile.Status or "yellow",
        Label = profile.Label or "Status unknown",
    }
end

-- ============================================================
-- UNSUPPORTED-GAME FALLBACK LOADER
-- This is deliberately separate from the supported-game registry:
-- unsupported games remain unsupported, but still receive the generic UI.
-- ============================================================
local function loadFallbackInterface(context)
    context.Window:SetScriptStatus("yellow", "Game not supported")

    local okDownload, source = pcall(function()
        return game:HttpGet(FALLBACK_MODULE_URL, true)
    end)

    if not okDownload or type(source) ~= "string" or source == "" then
        return false, "fallback_download_failed", source
    end

    local chunk, compileError = loadstring(source)
    if not chunk then
        return false, "fallback_compile_failed", compileError
    end

    local okChunk, moduleResult = pcall(chunk)
    if not okChunk then
        return false, "fallback_runtime_failed", moduleResult
    end

    if type(moduleResult) == "function" then
        local okRun, runError = pcall(moduleResult, context)
        if not okRun then
            return false, "fallback_loader_failed", runError
        end
        return true
    end

    if type(moduleResult) == "table" then
        if type(moduleResult.Load) == "function" then
            local okRun, runError = pcall(moduleResult.Load, moduleResult, context)
            if not okRun then
                return false, "fallback_loader_failed", runError
            end
            return true
        elseif type(moduleResult.Init) == "function" then
            local okRun, runError = pcall(moduleResult.Init, moduleResult, context)
            if not okRun then
                return false, "fallback_loader_failed", runError
            end
            return true
        end
    end

    return false, "fallback_invalid_module", "Fallback module did not return a function or Load/Init table."
end

local Window = NovaField:CreateWindow({
    Name = "vitality's hub",
    Icon = "vitality",
    Footer = "vitality",
    ToggleKey = Enum.KeyCode.RightShift,
    Theme = "Dark",

    NotificationsEnabled = true,
    SoundsEnabled = true,
    SoundVolume = 0.55,

    Motion = {
        Enabled = true,
        ReducedMotion = false,
        Speed = 1,
    },

    LoadingScreen = {
        Enabled = true,
        Title = "vitality's hub",
        Status = "Loading components...",
        CompleteStatus = "Components ready",
        Duration = 1.35,
        Icon = "vitality",
    },

    GameLoader = {
        Enabled = true,
        ShowLoading = true,
        LoadingTitle = "vitality's hub",
        DetectingText = "Detecting game...",
        DetectedPrefix = "Detected: ",
        ModuleLoadingText = "Loading game interface...",
        BuildingText = "Building game interface...",
        ReadyText = "Game interface ready",
        StageDuration = 0.55,

        UnsupportedLabel = "Game not supported",
        UnsupportedText = "Game not supported",
        UnsupportedReadyText = "Fallback interface ready",

        OnUnsupported = function(context)
            -- Important: this does NOT register the current game or turn it into
            -- a universal match. Detection remains unsupported; we simply build
            -- the generic Vitality component interface into the existing window.
            context.Window:SetScriptStatus("yellow", "Game not supported")

            local ok, reason, detail = loadFallbackInterface(context)
            if ok then
                context.Window:SetScriptStatus("yellow", "Game not supported")
                return
            end

            -- Emergency UI only if the fallback Pastebin itself cannot be loaded.
            local Unsupported = context.Window:CreateTab("Unsupported", "info")
            local Section = Unsupported:CreateSection({
                Name = "Game not supported",
                Description = "No dedicated module is registered, and the fallback interface failed to load.",
                Side = "Left",
            })

            Section:CreateParagraph({
                Title = "Detection details",
                Content = "GameId: " .. tostring(context.GameId)
                    .. "  â€¢  PlaceId: " .. tostring(context.PlaceId),
            })

            Section:CreateParagraph({
                Title = "Fallback diagnostics",
                Content = "Reason: " .. tostring(reason or "unknown")
                    .. "\n\nDetails:\n" .. tostring(detail or "No additional details.")
                    .. "\n\nFallback URL:\n" .. tostring(FALLBACK_MODULE_URL),
            })

            context.Window:SetScriptStatus("yellow", "Game not supported")
        end,

        OnLoadError = function(info)
            -- Suppress only a stale duplicate Tower error if this exact Window
            -- already completed the Tower module successfully.
            local completedBuild = rawget(_G, "__VITALITY_TOWER_MODULE_BUILD_STATE")
            if type(completedBuild) == "table"
                and completedBuild.Ready == true
                and completedBuild.Window == info.Window
                and info.Detection
                and tostring(info.Detection.Name) == "The Tower" then

                warn(
                    "[VitalityHub] Ignored duplicate Tower load error after the interface was already ready: "
                    .. tostring(info.Error or info.Reason or "unknown")
                )
                return
            end

            local completedApocBuild =
                rawget(
                    _G,
                    "__VITALITY_APOC2_MODULE_BUILD_STATE"
                )

            if type(completedApocBuild) == "table"
                and completedApocBuild.Ready == true
                and completedApocBuild.Window == info.Window
                and info.Detection
                and tostring(info.Detection.Name) == "Apocalypse Rising 2" then

                warn(
                    "[VitalityHub] Ignored duplicate Apocalypse Rising 2 load error after the interface was already ready: "
                    .. tostring(info.Error or info.Reason or "unknown")
                )
                return
            end

            local completedFlickBuild =
                rawget(
                    _G,
                    "__VITALITY_FLICK_MODULE_BUILD_STATE"
                )

            if type(completedFlickBuild) == "table"
                and completedFlickBuild.Ready == true
                and completedFlickBuild.Window == info.Window
                and info.Detection
                and tostring(info.Detection.Name) == "Flick" then

                warn(
                    "[VitalityHub] Ignored duplicate Flick load error after the interface was already ready: "
                    .. tostring(info.Error or info.Reason or "unknown")
                )
                return
            end

            local detectedName = info.Detection and info.Detection.Name or "Detected game"
            local ErrorTab = info.Window:CreateTab("Load Error", "info")
            local Section = ErrorTab:CreateSection({
                Name = detectedName .. " failed to load",
                Description = "The game was registered, but its module could not be initialized.",
                Side = "Left",
            })

            Section:CreateParagraph({
                Title = "Load diagnostics",
                Content = "Reason: " .. tostring(info.Reason or "unknown")
                    .. "\n\nCompiler / runtime details:\n"
                    .. tostring(info.Error or "No additional error details were returned.")
                    .. "\n\nModule URL:\n"
                    .. tostring(
                        info.Detection
                        and info.Detection.Profile
                        and info.Detection.Profile.Module
                        or "unknown"
                    ),
            })
        end,
    },

    BorderStroke = {
        Enabled = true,
        UseAccent = true,
        Thickness = 1,
        Transparency = 0.32,
    },

    -- Local for now. Later this manifest can be replaced by the Discord-controlled
    -- remote status backend without changing game/module detection.
    StatusControl = {
        Enabled = true,
        PollInterval = 5,
        URL = "",
        LocalManifest = {
            Library = {LatestVersion = "2.8.3.3"},
            Default = {Status = "yellow", Label = "Game not supported"},
            Games = StatusGames,
            Places = StatusPlaces,
        },
        FailureStatus = {Status = "yellow", Label = "Status unavailable"},
    },

    -- Keep each game's saved settings isolated from every other game's module.
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "VitalityHub",
        FileName = "Game_" .. tostring(game.GameId),
    },

    KeySystem = true,
    KeySettings = {
        Title = "Access key",
        Subtitle = "Remote license verification",
        Note = "Enter your Vitality license to continue.",
        Footer = "Validated securely through KeyAuth.",
        FolderName = "VitalityHubKeys",
        FileName = "VitalityHubKey",
        SaveKey = true,

        -- Revalidate the currently active license against KeyAuth every 10s.
        -- Re-executing the loader also forces an immediate fresh validation.
        RemoteRefreshInterval = 10,

        Provider = "KeyAuth",
        PlaceholderText = "Enter license key",
        VerifyText = "Authenticate",
        CheckingText = "Checking...",

        -- Vitality owns the UI; KeyAuth owns validity, revocation and expiry.
        RemoteValidator = validateKeyAuthLicense,
    },
})
