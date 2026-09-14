-- vitality's hub / main loader LS
-- Live Service game detection and remote status registry for Vitality Hub V2.11.0-LS+
-- Static fallback modules: The Tower, Apocalypse Rising 2, Murder Mystery 2, Flick, KAT. Cloudflare can add/remove live modules dynamically.
-- This is the ONE script/loadstring users execute.
-- Current hosted mainloader reference supplied by user: https://pastebin.com/raw/jDFLeUSy

local LIBRARY_URL = "https://vitalitys.lol/libraryLS.lua"

-- Paste the raw URL of the already-hosted The Tower module here.
local THE_TOWER_MODULE_URL = "https://vitalitys.lol/towermodLS.lua"

-- Murder Mystery 2 production module.
local MM2_MODULE_URL = "https://vitalitys.lol/mm2modLS.lua"

-- Apocalypse Rising 2 module.
-- Upload VitalityHub_ApocalypseRising2_Module_v1_02.txt to Pastebin, then
-- replace REPLACE_APOC2_RAW_ID below with that paste's raw ID.
local APOCALYPSE_RISING_2_MODULE_URL =
    "https://vitalitys.lol/ar2modLS.lua"

-- Flick production module.
-- Host the generated flickmod.lua at this URL.
local FLICK_MODULE_URL = "https://vitalitys.lol/flickmodLS.lua"

-- Upload katmodLS.lua to this URL before enabling the KAT registration.
local KAT_MODULE_URL = "https://vitalitys.lol/katmodLS.lua"

-- Generic Vitality component interface used when the current game is unsupported.
local FALLBACK_MODULE_URL = "https://vitalitys.lol/fallbackmodLS.lua"

-- Remote data-only manifest. This is decoded as JSON and is never executed.
local STATUS_MANIFEST_URL = "https://vitalitys.lol/statusLS.json"

-- Production Vitality Live control plane. The static JSON manifest remains a
-- fallback for executors that cannot keep a WebSocket connection alive.
local LIVE_SERVICE_URL = "https://vitality-live.vitalitydev.workers.dev"
local LIVE_WEBSOCKET_URL = "wss://vitality-live.vitalitydev.workers.dev/ws"

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

-- TODO KAT: fill in the verified universe ID (game.GameId), NOT a PlaceId.
-- The four supplied scripts do not identify it. Zero keeps KAT unregistered.
local KAT_GAME_ID = 254394801

local NovaField = loadstring(game:HttpGet(LIBRARY_URL, true))()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Owner matching is intentionally performed in the loader with immutable
-- numeric UserIds. The remote manifest may repeat these IDs for display, but
-- it cannot grant owner access by changing its JSON.
local OWNER_USER_IDS = {
    [69883038] = true,
    [4783899582] = true,
}

local OWNER_CONTEXT = {
    IsOwner = LocalPlayer ~= nil and OWNER_USER_IDS[LocalPlayer.UserId] == true,
    UserId = LocalPlayer and LocalPlayer.UserId or nil,
    Username = LocalPlayer and LocalPlayer.Name or "Owner",
    DisplayName = LocalPlayer and LocalPlayer.DisplayName or "Owner",
}

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
-- Static fallback registry. Cloudflare Live can add/remove modules dynamically at runtime.
-- ============================================================
local SupportedGames = {
    [THE_TOWER_GAME_ID] = {
        ModuleId = "the-tower",
        LiveModuleId = "tower",
        Name = "The Tower",
        Version = "1.9.14-LS",
        Module = THE_TOWER_MODULE_URL,
        Status = "green",
        State = "functional",
        Label = "Fully working",
    },

    [MM2_GAME_ID] = {
        ModuleId = "murder-mystery-2",
        LiveModuleId = "mm2",
        Name = "Murder Mystery 2",
        Version = "4.4-LS",
        Module = MM2_MODULE_URL,
        Status = "green",
        State = "functional",
        Label = "Fully working",
    },

    [APOCALYPSE_RISING_2_GAME_ID] = {
        ModuleId = "apocalypse-rising-2",
        LiveModuleId = "ar2",
        Name = "Apocalypse Rising 2",
        Version = "1.02-LS",
        Module = APOCALYPSE_RISING_2_MODULE_URL,

        -- Keep this yellow until the Vitality conversion is tested once in-game.
        Status = "yellow",
        State = "testing",
        Label = "Testing",
    },

    [FLICK_GAME_ID] = {
        ModuleId = "flick",
        LiveModuleId = "flick",
        Name = "Flick",
        Version = "2.9.0-LS",
        Module = FLICK_MODULE_URL,
        Status = "green",
        State = "functional",
        Label = "Fully working",
    },
}

-- KAT uses the same registration and status-manifest loops as every other game.
-- Deliberately do not infer an ID from whichever game happens to run this loader.
if KAT_GAME_ID > 0 and KAT_GAME_ID % 1 == 0 then
    assert(SupportedGames[KAT_GAME_ID] == nil, "KAT_GAME_ID conflicts with an existing game")
    SupportedGames[KAT_GAME_ID] = {
        ModuleId = "kat",
        LiveModuleId = "kat",
        Name = "KAT",
        Version = "1.0.0-LS",
        Module = KAT_MODULE_URL,
        Status = "yellow",
        State = "testing",
        Label = "Testing",
    }
end
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
        ModuleId = profile.ModuleId,
        Name = profile.Name,
        Version = profile.Version,
        ModuleURL = profile.Module,
        State = profile.State or profile.Status or "testing",
        Status = profile.Status or "yellow",
        Label = profile.Label or "Status unknown",
        Summary = profile.Name .. " is using the loader's local status fallback.",
        Detail = "The remote status manifest could not be reached. Module loading remains available.",
        Tooltip = "This entry will be replaced automatically when statusLS.json becomes reachable.",
    }
end

for placeId, profile in pairs(SupportedPlaces) do
    StatusPlaces[placeId] = {
        ModuleId = profile.ModuleId,
        Name = profile.Name,
        Version = profile.Version,
        ModuleURL = profile.Module,
        State = profile.State or profile.Status or "testing",
        Status = profile.Status or "yellow",
        Label = profile.Label or "Status unknown",
    }
end

local LOCAL_STATUS_DEFINITIONS = {
    functional = {
        Label = "Fully Working",
        Color = "#42E88A",
        GlowColor = "#35F58B",
        LegacyLevel = "green",
    },
    testing = {
        Label = "In Testing",
        Color = "#FFD84A",
        GlowColor = "#FFE46B",
        LegacyLevel = "yellow",
    },
    limited = {
        Label = "Limited Functionality",
        Color = "#FF963D",
        GlowColor = "#FFAA55",
        LegacyLevel = "yellow",
    },
    broken = {
        Label = "Not Working",
        Color = "#FF4D5E",
        GlowColor = "#FF4055",
        LegacyLevel = "red",
    },
    maintenance = {
        Label = "Maintenance",
        Color = "#F1F5F9",
        GlowColor = "#FFFFFF",
        LegacyLevel = "yellow",
    },
    updating = {
        Label = "Updating",
        Color = "#35D9FF",
        GlowColor = "#44E5FF",
        LegacyLevel = "yellow",
    },
}



-- ============================================================
-- VITALITY LIVE / CLOUDFLARE CLIENT
-- ============================================================
-- Security model:
--   * Roblox UserId controls whether the Owner UI/commands are exposed locally.
--   * Cloudflare still requires a short-lived owner session before any write.
--   * The production master secret is NEVER stored in this hosted loader.
--     Owners provide it through getgenv().VITALITY_OWNER_KEY or a local
--     VitalityHub/owner.key file on their own executor/device.

local LIVE_MODULE_ALIASES = {
    ["tower"] = "tower",
    ["the-tower"] = "tower",
    ["thetower"] = "tower",
    ["kat"] = "kat",
    ["flick"] = "flick",
    ["mm2"] = "mm2",
    ["murder-mystery-2"] = "mm2",
    ["murdermystery2"] = "mm2",
    ["ar2"] = "ar2",
    ["apocalypse-rising-2"] = "ar2",
    ["apocalypserising2"] = "ar2",
}

local VALID_LIVE_MODULES = {
    tower = true,
    kat = true,
    flick = true,
    mm2 = true,
    ar2 = true,
}

local VALID_LIVE_STATUSES = {
    functional = true,
    testing = true,
    limited = true,
    broken = true,
    maintenance = true,
    updating = true,
}

local VitalityLive = {
    Window = nil,
    Detection = nil,
    LiveModuleId = nil,
    State = nil,

    Socket = nil,
    Connected = false,
    Transport = "offline",
    ConnectedClients = nil,
    ServerRecognizedOwner = false,

    OwnerToken = nil,
    OwnerTokenExpiresAt = nil,

    _connectionToken = 0,
    _pollToken = 0,
    _cleanupRegistered = false,
}

NovaField.LiveService = VitalityLive

local function normalizeLiveModuleId(value)
    value = tostring(value or "")
        :lower()
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub("%s+", "")
        :gsub("_", "-")

    return LIVE_MODULE_ALIASES[value] or value
end

local function resolveCurrentLiveModuleId(detection)
    local profile = detection and detection.Profile
    if type(profile) == "table" then
        local resolved = normalizeLiveModuleId(profile.LiveModuleId or profile.ModuleId)
        if resolved ~= "" then return resolved end
    end

    profile = SupportedPlaces[game.PlaceId] or SupportedGames[game.GameId]
    if type(profile) == "table" then
        local resolved = normalizeLiveModuleId(profile.LiveModuleId or profile.ModuleId)
        if resolved ~= "" then return resolved end
    end

    return "unsupported"
end

local function resolveRequestFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    return nil
end

local HTTP_REQUEST = resolveRequestFunction()

local function decodeJson(text)
    if type(text) ~= "string" or text == "" then return nil end
    local ok, value = pcall(HttpService.JSONDecode, HttpService, text)
    return ok and value or nil
end

local function liveRequest(method, path, body, headers)
    method = tostring(method or "GET"):upper()
    path = tostring(path or "")
    headers = type(headers) == "table" and headers or {}
    headers["Content-Type"] = headers["Content-Type"] or "application/json"

    -- Public reads can still work on executors that only expose game:HttpGet.
    if not HTTP_REQUEST and method == "GET" then
        local ok, raw = pcall(function()
            return game:HttpGet(LIVE_SERVICE_URL .. path, true)
        end)
        if not ok then return false, nil, tostring(raw) end
        local decoded = decodeJson(raw)
        if type(decoded) ~= "table" then return false, nil, "Vitality Live returned unreadable JSON." end
        return true, decoded, nil
    end

    if not HTTP_REQUEST then
        return false, nil, "This executor does not expose an HTTP request function required for owner actions."
    end

    local options = {
        Url = LIVE_SERVICE_URL .. path,
        Method = method,
        Headers = headers,
    }
    if body ~= nil then
        options.Body = HttpService:JSONEncode(body)
    end

    local ok, response = pcall(HTTP_REQUEST, options)
    if not ok then return false, nil, tostring(response) end
    if type(response) ~= "table" then return false, nil, "Invalid HTTP response from executor." end

    local statusCode = tonumber(response.StatusCode or response.Status or response.status)
    if not statusCode and response.Success == true then statusCode = 200 end
    statusCode = statusCode or 0

    local raw = response.Body or response.body or ""
    local decoded = decodeJson(raw)
    if statusCode < 200 or statusCode >= 300 then
        local detail = type(decoded) == "table" and (decoded.error or decoded.message) or raw
        return false, decoded, tostring(detail ~= "" and detail or ("HTTP " .. statusCode))
    end

    return true, decoded, nil
end

local function resolveWebSocketConnect()
    if WebSocket and type(WebSocket.connect) == "function" then
        return function(url) return WebSocket.connect(url) end
    end
    if websocket and type(websocket.connect) == "function" then
        return function(url) return websocket.connect(url) end
    end
    if syn and syn.websocket and type(syn.websocket.connect) == "function" then
        return function(url) return syn.websocket.connect(url) end
    end
    return nil
end

local WEBSOCKET_CONNECT = resolveWebSocketConnect()

local function socketSend(socket, payload)
    if not socket then return false end
    if type(socket.Send) == "function" then
        return pcall(socket.Send, socket, payload)
    end
    if type(socket.send) == "function" then
        return pcall(socket.send, socket, payload)
    end
    return false
end

local function socketClose(socket)
    if not socket then return end
    pcall(function()
        if type(socket.Close) == "function" then
            socket:Close()
        elseif type(socket.close) == "function" then
            socket:close()
        end
    end)
end

local function connectSocketEvent(socket, eventName, callback)
    if not socket then return false end
    local event = socket[eventName]
    if event and type(event.Connect) == "function" then
        local ok = pcall(function() event:Connect(callback) end)
        return ok
    end

    -- A few executor implementations expose callback properties instead of
    -- RBXScriptSignal-like objects. Assignment is harmlessly attempted last.
    local ok = pcall(function() socket[eventName] = callback end)
    return ok
end

local function updateOwnerLiveInfo(extra)
    local window = VitalityLive.Window
    if not window or type(window.SetOwnerLiveServiceInfo) ~= "function" then return end

    local info = {
        Connected = VitalityLive.Connected,
        Transport = VitalityLive.Transport,
        ConnectedClients = VitalityLive.ConnectedClients,
        Module = VitalityLive.LiveModuleId,
        ServerRecognizedOwner = VitalityLive.ServerRecognizedOwner,
    }
    for key, value in pairs(type(extra) == "table" and extra or {}) do
        info[key] = value
    end
    pcall(function() window:SetOwnerLiveServiceInfo(info) end)
end

local function liveModuleExists(moduleId)
    moduleId = normalizeLiveModuleId(moduleId)
    local modules = VitalityLive.State and VitalityLive.State.modules
    if type(modules) == "table" and type(modules[moduleId]) == "table" then
        return true
    end
    return VALID_LIVE_MODULES[moduleId] == true
end

local function liveStatusProfile(liveId, live, existing)
    if type(live) ~= "table" then return nil end
    local gameId = tonumber(live.gameId)
    local url = tostring(live.url or "")
    if not gameId or gameId <= 0 or gameId % 1 ~= 0 or not url:match("^https?://") then
        return nil
    end

    local statusName = tostring(live.status or "testing"):lower()
    local definition = LOCAL_STATUS_DEFINITIONS[statusName] or LOCAL_STATUS_DEFINITIONS.testing
    local profile = {
        ModuleId = (type(existing) == "table" and existing.ModuleId) or liveId,
        LiveModuleId = liveId,
        Name = tostring(live.name or (type(existing) == "table" and existing.Name) or liveId),
        Version = tostring(live.version or (type(existing) == "table" and existing.Version) or "1.0.0-LS"),
        Module = url,
        Status = definition.LegacyLevel,
        State = statusName,
        Label = definition.Label,
        Enabled = live.enabled ~= false,
        LiveManaged = true,
    }
    return profile, gameId, definition
end

local function syncLiveRegistry(state, pruneMissing)
    if type(state) ~= "table" then return false end
    local modules = type(state.modules) == "table" and state.modules or {}
    local liveGameIds = {}
    local livePlaceIds = {}

    -- Rebuild the live-module lookup from authoritative Cloudflare state.
    for key in pairs(VALID_LIVE_MODULES) do
        VALID_LIVE_MODULES[key] = nil
    end

    -- Remove place routes that were created by a previous live snapshot. Static
    -- manual place overrides remain untouched.
    for placeId, profile in pairs(SupportedPlaces) do
        if type(profile) == "table" and profile.LiveManaged == true then
            SupportedPlaces[placeId] = nil
            StatusPlaces[placeId] = nil
            if NovaField.Router and NovaField.Router.Places then
                NovaField.Router.Places[placeId] = nil
            end
        end
    end

    for rawId, live in pairs(modules) do
        local liveId = normalizeLiveModuleId(rawId)
        if liveId ~= "" and type(live) == "table" then
            VALID_LIVE_MODULES[liveId] = true
            local existing
            local candidateGameId = tonumber(live.gameId)
            if candidateGameId then existing = SupportedGames[candidateGameId] end
            local profile, gameId, definition = liveStatusProfile(liveId, live, existing)
            if profile and gameId then
                liveGameIds[gameId] = true
                SupportedGames[gameId] = profile
                NovaField:RegisterGame(gameId, profile)

                local reason = tostring(live.reason or "")
                StatusGames[gameId] = {
                    ModuleId = profile.ModuleId,
                    LiveModuleId = liveId,
                    Name = profile.Name,
                    Version = profile.Version,
                    ModuleURL = profile.Module,
                    State = profile.State,
                    Status = profile.Status,
                    Label = profile.Label,
                    Summary = reason,
                    Detail = reason,
                    Tooltip = reason ~= "" and reason or profile.Label,
                    Enabled = profile.Enabled,
                }

                if type(live.placeIds) == "table" then
                    for _, rawPlaceId in ipairs(live.placeIds) do
                        local placeId = tonumber(rawPlaceId)
                        if placeId and placeId > 0 and placeId % 1 == 0 then
                            livePlaceIds[placeId] = true
                            local placeProfile = {
                                ModuleId = profile.ModuleId,
                                LiveModuleId = liveId,
                                Name = profile.Name,
                                Version = profile.Version,
                                Module = profile.Module,
                                Status = profile.Status,
                                State = profile.State,
                                Label = profile.Label,
                                Enabled = profile.Enabled,
                                LiveManaged = true,
                            }
                            SupportedPlaces[placeId] = placeProfile
                            NovaField:RegisterPlace(placeId, placeProfile)
                            StatusPlaces[placeId] = {
                                ModuleId = profile.ModuleId,
                                LiveModuleId = liveId,
                                Name = profile.Name,
                                Version = profile.Version,
                                ModuleURL = profile.Module,
                                State = profile.State,
                                Status = profile.Status,
                                Label = profile.Label,
                                Summary = reason,
                                Detail = reason,
                                Tooltip = reason ~= "" and reason or profile.Label,
                                Enabled = profile.Enabled,
                            }
                        end
                    end
                end
            end
        end
    end

    if pruneMissing then
        local removeGames = {}
        for gameId in pairs(SupportedGames) do
            if not liveGameIds[gameId] then
                table.insert(removeGames, gameId)
            end
        end
        for _, gameId in ipairs(removeGames) do
            SupportedGames[gameId] = nil
            StatusGames[gameId] = nil
            if NovaField.Router and NovaField.Router.Games then
                NovaField.Router.Games[gameId] = nil
            end
        end
    end

    return true
end

local function buildManifestFromLiveState(state)
    if type(state) ~= "table" then return nil end
    local modules = type(state.modules) == "table" and state.modules or {}
    local games = {}
    local places = {}

    for rawId, live in pairs(modules) do
        local liveId = normalizeLiveModuleId(rawId)
        if type(live) == "table" then
            local gameId = tonumber(live.gameId)
            local statusName = tostring(live.status or "testing"):lower()
            local definition = LOCAL_STATUS_DEFINITIONS[statusName] or LOCAL_STATUS_DEFINITIONS.testing
            local reason = tostring(live.reason or "")
            local url = tostring(live.url or "")
            if gameId and gameId > 0 and gameId % 1 == 0 then
                local entry = {
                    ModuleId = liveId,
                    LiveModuleId = liveId,
                    Name = tostring(live.name or liveId),
                    Version = tostring(live.version or "1.0.0-LS"),
                    ModuleURL = url,
                    State = statusName,
                    Status = definition.LegacyLevel,
                    Label = definition.Label,
                    Summary = reason,
                    Detail = reason,
                    Tooltip = reason ~= "" and reason or definition.Label,
                    Enabled = live.enabled ~= false,
                }
                games[gameId] = entry

                if type(live.placeIds) == "table" then
                    for _, rawPlaceId in ipairs(live.placeIds) do
                        local placeId = tonumber(rawPlaceId)
                        if placeId and placeId > 0 and placeId % 1 == 0 then
                            places[placeId] = entry
                        end
                    end
                end
            end
        end
    end

    return {
        SchemaVersion = 1,
        UpdatedAt = state.updatedAt or state.UpdatedAt,
        Owners = {69883038, 4783899582},
        Library = {LatestVersion = state.libraryVersion or "2.11.0-LS"},
        StatusDefinitions = LOCAL_STATUS_DEFINITIONS,
        Default = {
            State = "maintenance",
            Status = "yellow",
            Label = "Game Not Supported",
            Summary = "No dedicated Vitality module is currently available.",
        },
        Games = games,
        Places = places,
    }
end

local function applyLiveState(state, transport)
    if type(state) ~= "table" then return false end
    VitalityLive.State = state
    syncLiveRegistry(state, true)
    if transport then VitalityLive.Transport = transport end

    local window = VitalityLive.Window
    if not window then return true end

    local manifest = buildManifestFromLiveState(state)
    if not manifest then return false end

    local ok, reason = window:ApplyStatusManifest(manifest, "cloudflare-live")
    if not ok then
        warn("[VitalityLive] Failed to apply Cloudflare state: " .. tostring(reason))
        return false
    end

    -- Cloudflare becomes authoritative while reachable. statusLS.json stays
    -- available as a fallback and is restarted whenever live connectivity fails.
    pcall(function() window:StopStatusControl() end)
    updateOwnerLiveInfo()
    return true
end

local function notifyLiveBroadcast(packet)
    local window = VitalityLive.Window
    if not window then return end

    local style = tostring(packet.style or "owner"):lower()
    local notificationType = "Info"
    if style == "success" then notificationType = "Success"
    elseif style == "warning" then notificationType = "Warning"
    elseif style == "error" then notificationType = "Error"
    end

    window:Notify({
        Title = style == "owner" and "Vitality Owner Broadcast" or "Vitality Broadcast",
        Content = tostring(packet.message or ""),
        Type = notificationType,
        Duration = 8,
    })
end

local function handleLivePacket(rawMessage)
    if type(rawMessage) ~= "string" then return end
    if rawMessage == "pong" then return end

    local packet = decodeJson(rawMessage)
    if type(packet) ~= "table" then return end

    if packet.type == "state.snapshot" then
        if tonumber(packet.connectedClients) then
            VitalityLive.ConnectedClients = tonumber(packet.connectedClients)
        end
        if type(packet.state) == "table" then
            applyLiveState(packet.state, "websocket")
        end
        return
    end

    if packet.type == "module.updated" or packet.type == "module.added" then
        VitalityLive.State = type(VitalityLive.State) == "table" and VitalityLive.State or {modules = {}}
        VitalityLive.State.modules = type(VitalityLive.State.modules) == "table" and VitalityLive.State.modules or {}
        if packet.module and type(packet.moduleState) == "table" then
            VitalityLive.State.modules[normalizeLiveModuleId(packet.module)] = packet.moduleState
        end
        applyLiveState(VitalityLive.State, "websocket")
        return
    end

    if packet.type == "module.removed" then
        VitalityLive.State = type(VitalityLive.State) == "table" and VitalityLive.State or {modules = {}}
        VitalityLive.State.modules = type(VitalityLive.State.modules) == "table" and VitalityLive.State.modules or {}
        if packet.module then
            VitalityLive.State.modules[normalizeLiveModuleId(packet.module)] = nil
        end
        applyLiveState(VitalityLive.State, "websocket")
        return
    end

    if packet.type == "broadcast" then
        notifyLiveBroadcast(packet)
        return
    end

    if packet.type == "identify.ok" then
        VitalityLive.ServerRecognizedOwner = packet.owner == true
        if tonumber(packet.connectedClients) then
            VitalityLive.ConnectedClients = tonumber(packet.connectedClients)
        end
        updateOwnerLiveInfo()
        return
    end
end

local function beginLiveHttpPolling(window)
    VitalityLive._pollToken = VitalityLive._pollToken + 1
    local token = VitalityLive._pollToken

    task.spawn(function()
        while window and window.Gui and window.Gui.Parent and VitalityLive._pollToken == token do
            local delaySeconds = VitalityLive.Connected and 60 or 15
            if not VitalityLive.Connected then
                local ok, response = liveRequest("GET", "/state")
                if ok and type(response) == "table" then
                    if tonumber(response.connectedClients) then
                        VitalityLive.ConnectedClients = tonumber(response.connectedClients)
                    end
                    if type(response.state) == "table" then
                        VitalityLive.Transport = "http-poll"
                        applyLiveState(response.state, "http-poll")
                    end
                else
                    pcall(function() window:StartStatusControl() end)
                    updateOwnerLiveInfo({Transport = "statusLS-fallback"})
                end
            end
            task.wait(delaySeconds)
        end
    end)
end

local function connectVitalityLive(window, detection)
    VitalityLive.Window = window
    VitalityLive.Detection = detection
    VitalityLive.LiveModuleId = resolveCurrentLiveModuleId(detection)
    VitalityLive._connectionToken = VitalityLive._connectionToken + 1
    local token = VitalityLive._connectionToken

    if not VitalityLive._cleanupRegistered then
        VitalityLive._cleanupRegistered = true
        window:AddCleanup(function()
            VitalityLive._connectionToken = VitalityLive._connectionToken + 1
            VitalityLive._pollToken = VitalityLive._pollToken + 1
            VitalityLive.Connected = false
            VitalityLive.Transport = "offline"
            socketClose(VitalityLive.Socket)
            VitalityLive.Socket = nil
        end)
    end

    beginLiveHttpPolling(window)

    if not WEBSOCKET_CONNECT then
        VitalityLive.Transport = "http-poll"
        updateOwnerLiveInfo()
        warn("[VitalityLive] WebSocket API unavailable; using HTTP live-state polling with statusLS.json fallback.")
        return false
    end

    local attemptConnection

    local function scheduleReconnect(attempt)
        attempt = math.max(1, tonumber(attempt) or 1)
        local waitSeconds = math.min(3 * attempt, 30)
        task.delay(waitSeconds, function()
            if VitalityLive._connectionToken ~= token then return end
            if not window.Gui or not window.Gui.Parent then return end
            attemptConnection(attempt + 1)
        end)
    end

    attemptConnection = function(attempt)
        if VitalityLive._connectionToken ~= token then return end
        if not window.Gui or not window.Gui.Parent then return end

        local ok, socket = pcall(WEBSOCKET_CONNECT, LIVE_WEBSOCKET_URL)
        if not ok or not socket then
            VitalityLive.Connected = false
            VitalityLive.Transport = "http-poll"
            updateOwnerLiveInfo()
            scheduleReconnect(attempt)
            return
        end

        socketClose(VitalityLive.Socket)
        VitalityLive.Socket = socket
        VitalityLive.Connected = true
        VitalityLive.Transport = "websocket"
        pcall(function() window:StopStatusControl() end)
        updateOwnerLiveInfo()

        connectSocketEvent(socket, "OnMessage", function(message)
            handleLivePacket(message)
        end)

        connectSocketEvent(socket, "OnClose", function()
            if VitalityLive.Socket == socket then
                VitalityLive.Socket = nil
                VitalityLive.Connected = false
                VitalityLive.Transport = "http-poll"
                pcall(function() window:StartStatusControl() end)
                updateOwnerLiveInfo()
                scheduleReconnect(1)
            end
        end)

        local identify = {
            type = "identify",
            userId = LocalPlayer and LocalPlayer.UserId or 0,
            module = VitalityLive.LiveModuleId,
            placeId = game.PlaceId,
            libraryVersion = NovaField.Version or "2.11.0-LS",
        }
        socketSend(socket, HttpService:JSONEncode(identify))
    end

    attemptConnection(1)
    return true
end

local function readLocalOwnerSecret()
    if not OWNER_CONTEXT.IsOwner then return nil end

    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            local value = rawget(env, "VITALITY_OWNER_KEY")
            if type(value) == "string" and value ~= "" then return value end
        end
    end

    if type(isfile) == "function" and type(readfile) == "function" then
        local path = "VitalityHub/owner.key"
        if isfile(path) then
            local ok, value = pcall(readfile, path)
            if ok and type(value) == "string" then
                value = value:gsub("^%s+", ""):gsub("%s+$", "")
                if value ~= "" then return value end
            end
        end
    end

    return nil
end

local function authenticateLiveOwner()
    if not OWNER_CONTEXT.IsOwner then return false, "Not a Vitality owner." end

    if VitalityLive.OwnerToken then
        local expiresAt = tonumber(VitalityLive.OwnerTokenExpiresAt)
        if not expiresAt or expiresAt > os.time() + 30 then return true end
    end

    local ownerSecret = readLocalOwnerSecret()
    if not ownerSecret then
        return false, "No local owner secret found. Set getgenv().VITALITY_OWNER_KEY or create VitalityHub/owner.key."
    end

    local ok, result, err = liveRequest("POST", "/owner/session", {
        userId = LocalPlayer.UserId,
    }, {
        ["X-Vitality-Key"] = ownerSecret,
    })

    if not ok or type(result) ~= "table" or result.ok ~= true or type(result.token) ~= "string" then
        return false, tostring((type(result) == "table" and (result.error or result.message)) or err or "Owner authentication failed.")
    end

    VitalityLive.OwnerToken = result.token
    local expiresAt = tonumber(result.expiresAt)
    if expiresAt then
        -- Worker Date.now() values are milliseconds.
        VitalityLive.OwnerTokenExpiresAt = expiresAt > 100000000000 and (expiresAt / 1000) or expiresAt
    else
        VitalityLive.OwnerTokenExpiresAt = nil
    end
    return true
end

local function liveOwnerRequest(method, path, body)
    local authenticated, authError = authenticateLiveOwner()
    if not authenticated then return false, nil, authError end

    local function issue()
        return liveRequest(method, path, body, {
            Authorization = "Bearer " .. tostring(VitalityLive.OwnerToken),
        })
    end

    local ok, result, err = issue()
    if ok then return ok, result, err end

    local lower = tostring((type(result) == "table" and (result.error or result.message)) or err or ""):lower()
    if lower:find("session", 1, true) or lower:find("unauthorized", 1, true) then
        VitalityLive.OwnerToken = nil
        VitalityLive.OwnerTokenExpiresAt = nil
        local reauth, reauthError = authenticateLiveOwner()
        if reauth then return issue() end
        return false, nil, reauthError
    end

    return ok, result, err
end

local function commandFailureText(result, err)
    return tostring((type(result) == "table" and (result.error or result.message)) or err or "Unknown live-service error.")
end

local function registerLiveOwnerCommands(window)
    if not OWNER_CONTEXT.IsOwner then return false end

    window:RegisterCommand({
        Name = "live",
        Aliases = {"livestatus"},
        Description = "Show Vitality Live connection information.",
        Usage = "live",
        Category = "Owner",
        Callback = function()
            local text = "Transport: " .. tostring(VitalityLive.Transport)
                .. "\nConnected: " .. tostring(VitalityLive.Connected)
                .. "\nModule: " .. tostring(VitalityLive.LiveModuleId)
                .. "\nClients: " .. tostring(VitalityLive.ConnectedClients or "unknown")
            window:Notify({Title = "Vitality Live", Content = text, Type = VitalityLive.Connected and "Success" or "Info", Duration = 6})
        end,
    })

    window:RegisterCommand({
        Name = "messageall",
        Aliases = {"msgall", "broadcast"},
        Description = "Send a live message to every connected Vitality user.",
        Usage = "messageall <message>",
        Category = "Owner",
        Callback = function(args)
            if #args == 0 then return window:Notify({Title = "Message all", Content = "Usage: messageall <message>", Type = "Warning", Duration = 4}) end
            local ok, result, err = liveOwnerRequest("POST", "/owner/broadcast", {
                message = table.concat(args, " "), audience = "all", style = "owner",
            })
            window:Notify({
                Title = ok and "Broadcast sent" or "Broadcast failed",
                Content = ok and ("Delivered to " .. tostring(result and result.delivered or 0) .. " client(s).") or commandFailureText(result, err),
                Type = ok and "Success" or "Error", Duration = 5,
            })
        end,
    })

    window:RegisterCommand({
        Name = "messagegame",
        Aliases = {"msggame"},
        Description = "Send a live message to users connected to one module.",
        Usage = "messagegame <module> <message>",
        Category = "Owner",
        Callback = function(args)
            if #args < 2 then return window:Notify({Title = "Message game", Content = "Usage: messagegame <module> <message>", Type = "Warning", Duration = 4}) end
            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            if not liveModuleExists(moduleId) then return window:Notify({Title = "Message game", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
            local ok, result, err = liveOwnerRequest("POST", "/owner/broadcast", {
                message = table.concat(args, " "), audience = "game:" .. moduleId, style = "owner",
            })
            window:Notify({
                Title = ok and "Game broadcast sent" or "Broadcast failed",
                Content = ok and (moduleId .. " - " .. tostring(result and result.delivered or 0) .. " client(s).") or commandFailureText(result, err),
                Type = ok and "Success" or "Error", Duration = 5,
            })
        end,
    })

    window:RegisterCommand({
        Name = "messageowners",
        Aliases = {"msgowners"},
        Description = "Send a live message only to connected owners.",
        Usage = "messageowners <message>",
        Category = "Owner",
        Callback = function(args)
            if #args == 0 then return window:Notify({Title = "Message owners", Content = "Usage: messageowners <message>", Type = "Warning", Duration = 4}) end
            local ok, result, err = liveOwnerRequest("POST", "/owner/broadcast", {
                message = table.concat(args, " "), audience = "owners", style = "owner",
            })
            window:Notify({Title = ok and "Owner broadcast sent" or "Broadcast failed", Content = ok and ("Delivered to " .. tostring(result and result.delivered or 0) .. " owner client(s).") or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
        end,
    })

    window:RegisterCommand({
        Name = "messageuser",
        Aliases = {"msguser"},
        Description = "Send a live message to one Roblox UserId.",
        Usage = "messageuser <userid> <message>",
        Category = "Owner",
        Callback = function(args)
            if #args < 2 then return window:Notify({Title = "Message user", Content = "Usage: messageuser <userid> <message>", Type = "Warning", Duration = 4}) end
            local userId = tonumber(table.remove(args, 1))
            if not userId then return window:Notify({Title = "Message user", Content = "UserId must be numeric.", Type = "Error", Duration = 4}) end
            local ok, result, err = liveOwnerRequest("POST", "/owner/broadcast", {
                message = table.concat(args, " "), audience = "user:" .. tostring(math.floor(userId)), style = "owner",
            })
            window:Notify({Title = ok and "User message sent" or "Message failed", Content = ok and ("Delivered to " .. tostring(result and result.delivered or 0) .. " client(s).") or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
        end,
    })

    -- Owners receive an extended status command. Calling it without arguments
    -- preserves the library's original read-only status behavior.
    window:RegisterCommand({
        Name = "status",
        Aliases = {"setstatus"},
        Description = "Show the current status or update a module's live status.",
        Usage = "status [module] [functional/testing/limited/broken/maintenance/updating] [reason]",
        Category = "Owner",
        Callback = function(args)
            if #args == 0 then
                local status = window.ScriptStatus or {}
                local label = status.Label or status.State or "Unknown"
                return window:Notify({Title = "Module status", Content = tostring(label), Type = "Info", Duration = 4})
            end
            if #args < 2 then return window:Notify({Title = "Status", Content = "Usage: status <module> <state> [reason]", Type = "Warning", Duration = 5}) end

            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            local state = tostring(table.remove(args, 1)):lower()
            if not liveModuleExists(moduleId) then return window:Notify({Title = "Status", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
            if not VALID_LIVE_STATUSES[state] then return window:Notify({Title = "Status", Content = "Unknown state: " .. state, Type = "Error", Duration = 4}) end

            local payload = {status = state}
            if #args > 0 then payload.reason = table.concat(args, " ") end
            local ok, result, err = liveOwnerRequest("PATCH", "/owner/modules/" .. moduleId, payload)
            window:Notify({Title = ok and "Status updated" or "Status update failed", Content = ok and (moduleId .. " -> " .. state) or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
        end,
    })

    window:RegisterCommand({
        Name = "reason",
        Aliases = {"statusreason"},
        Description = "Change a module's live status reason.",
        Usage = "reason <module> <text>",
        Category = "Owner",
        Callback = function(args)
            if #args < 2 then return window:Notify({Title = "Reason", Content = "Usage: reason <module> <text>", Type = "Warning", Duration = 4}) end
            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            if not liveModuleExists(moduleId) then return window:Notify({Title = "Reason", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
            local ok, result, err = liveOwnerRequest("PATCH", "/owner/modules/" .. moduleId, {reason = table.concat(args, " ")})
            window:Notify({Title = ok and "Reason updated" or "Reason update failed", Content = ok and (moduleId .. " status reason updated.") or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
        end,
    })

    local function setEnabled(args, enabled)
        if #args < 1 then return window:Notify({Title = enabled and "Enable" or "Disable", Content = "Usage: " .. (enabled and "enable" or "disable") .. " <module>", Type = "Warning", Duration = 4}) end
        local moduleId = normalizeLiveModuleId(args[1])
        if not liveModuleExists(moduleId) then return window:Notify({Title = "Module control", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
        local ok, result, err = liveOwnerRequest("PATCH", "/owner/modules/" .. moduleId, {enabled = enabled})
        window:Notify({Title = ok and "Module updated" or "Module update failed", Content = ok and (moduleId .. (enabled and " enabled for future executions." or " disabled for future executions.")) or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
    end

    window:RegisterCommand({Name = "enable", Description = "Enable a live module.", Usage = "enable <module>", Category = "Owner", Callback = function(args) setEnabled(args, true) end})
    window:RegisterCommand({Name = "disable", Description = "Disable a live module.", Usage = "disable <module>", Category = "Owner", Callback = function(args) setEnabled(args, false) end})

    window:RegisterCommand({
        Name = "moduleversion",
        Aliases = {"setversion"},
        Description = "Update a module's live version metadata.",
        Usage = "moduleversion <module> <version>",
        Category = "Owner",
        Callback = function(args)
            if #args < 2 then return window:Notify({Title = "Module version", Content = "Usage: moduleversion <module> <version>", Type = "Warning", Duration = 4}) end
            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            if not liveModuleExists(moduleId) then return window:Notify({Title = "Module version", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
            local version = table.concat(args, " ")
            local ok, result, err = liveOwnerRequest("PATCH", "/owner/modules/" .. moduleId, {version = version})
            window:Notify({Title = ok and "Version updated" or "Version update failed", Content = ok and (moduleId .. " -> " .. version) or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
        end,
    })


    window:RegisterCommand({
        Name = "addmodule",
        Aliases = {"createmodule"},
        Description = "Add a new live module to Cloudflare and the dynamic game registry.",
        Usage = 'addmodule <id> <gameId> "<name>" <url> [status] [version]',
        Category = "Owner",
        Callback = function(args)
            if #args < 4 then
                return window:Notify({
                    Title = "Add module",
                    Content = 'Usage: addmodule <id> <gameId> "<name>" <url> [status] [version]',
                    Type = "Warning",
                    Duration = 6,
                })
            end

            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            local gameId = tonumber(table.remove(args, 1))
            local name = tostring(table.remove(args, 1) or "")
            local url = tostring(table.remove(args, 1) or "")
            local status = tostring(table.remove(args, 1) or "testing"):lower()
            local version = tostring(table.remove(args, 1) or "1.0.0-LS")

            if moduleId == "" then
                return window:Notify({Title = "Add module", Content = "Module id is required.", Type = "Error", Duration = 4})
            end
            if liveModuleExists(moduleId) then
                return window:Notify({Title = "Add module", Content = "Module already exists: " .. moduleId, Type = "Error", Duration = 4})
            end
            if not gameId or gameId <= 0 or gameId % 1 ~= 0 then
                return window:Notify({Title = "Add module", Content = "gameId must be a valid Roblox universe ID.", Type = "Error", Duration = 5})
            end
            if not url:match("^https?://") then
                return window:Notify({Title = "Add module", Content = "Module URL must begin with http:// or https://", Type = "Error", Duration = 5})
            end
            if not VALID_LIVE_STATUSES[status] then
                return window:Notify({Title = "Add module", Content = "Unknown state: " .. status, Type = "Error", Duration = 4})
            end

            local ok, result, err = liveOwnerRequest("POST", "/owner/modules", {
                id = moduleId,
                gameId = math.floor(gameId),
                name = name,
                url = url,
                status = status,
                version = version,
                reason = "Initial development.",
                enabled = true,
            })

            if ok and type(result) == "table" and type(result.moduleState) == "table" then
                VitalityLive.State = type(VitalityLive.State) == "table" and VitalityLive.State or {modules = {}}
                VitalityLive.State.modules = type(VitalityLive.State.modules) == "table" and VitalityLive.State.modules or {}
                VitalityLive.State.modules[moduleId] = result.moduleState
                applyLiveState(VitalityLive.State, VitalityLive.Transport)
            end

            window:Notify({
                Title = ok and "Module added" or "Add module failed",
                Content = ok
                    and (name .. " (" .. moduleId .. ") is now registered. Re-execute in that game to load it.")
                    or commandFailureText(result, err),
                Type = ok and "Success" or "Error",
                Duration = 7,
            })
        end,
    })

    window:RegisterCommand({
        Name = "removemodule",
        Aliases = {"deletemodule"},
        Description = "Remove a module from the live registry. Requires the word confirm.",
        Usage = "removemodule <id> confirm",
        Category = "Owner",
        Callback = function(args)
            if #args < 2 then
                return window:Notify({Title = "Remove module", Content = "Usage: removemodule <id> confirm", Type = "Warning", Duration = 5})
            end

            local moduleId = normalizeLiveModuleId(args[1])
            local confirmation = tostring(args[2] or ""):lower()
            if confirmation ~= "confirm" then
                return window:Notify({Title = "Remove module", Content = "Removal cancelled. Type: removemodule " .. moduleId .. " confirm", Type = "Warning", Duration = 6})
            end
            if not liveModuleExists(moduleId) then
                return window:Notify({Title = "Remove module", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4})
            end

            local ok, result, err = liveOwnerRequest("DELETE", "/owner/modules/" .. moduleId, {confirm = true})
            if ok then
                if type(VitalityLive.State) == "table" and type(VitalityLive.State.modules) == "table" then
                    VitalityLive.State.modules[moduleId] = nil
                    applyLiveState(VitalityLive.State, VitalityLive.Transport)
                end
            end

            window:Notify({
                Title = ok and "Module removed" or "Remove module failed",
                Content = ok
                    and (moduleId .. " was removed from the live registry. Re-execute affected clients to refresh game detection.")
                    or commandFailureText(result, err),
                Type = ok and "Success" or "Error",
                Duration = 7,
            })
        end,
    })

    return true
end

-- Pull public Cloudflare state once before the window/game loader starts. This
-- makes live enable/disable, module URL, version, and status metadata effective
-- on the NEXT execution instead of waiting until after the game module loads.
local function bootstrapLivePolicy()
    local ok, response = liveRequest("GET", "/state")
    if not ok or type(response) ~= "table" or type(response.state) ~= "table" then
        return false
    end

    VitalityLive.State = response.state
    if tonumber(response.connectedClients) then
        VitalityLive.ConnectedClients = tonumber(response.connectedClients)
    end

    -- Cloudflare is authoritative whenever it is reachable. Every module with a
    -- valid gameId + URL is registered dynamically, and modules removed from the
    -- Cloudflare registry are omitted from game detection on this execution.
    syncLiveRegistry(response.state, true)
    return true
end

bootstrapLivePolicy()

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

    Owner = OWNER_CONTEXT,

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
                    .. "  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢  PlaceId: " .. tostring(context.PlaceId),
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

    StatusControl = {
        Enabled = true,
        PollInterval = 30,
        URL = STATUS_MANIFEST_URL,
        MaximumBytes = 262144,
        CacheBust = true,
        NotifyOnUpdate = true,
        LocalManifest = {
            SchemaVersion = 1,
            Owners = {69883038, 4783899582},
            Library = {LatestVersion = "2.11.0-LS"},
            StatusDefinitions = LOCAL_STATUS_DEFINITIONS,
            Default = {
                State = "maintenance",
                Status = "yellow",
                Label = "Game Not Supported",
                Summary = "No dedicated Vitality module is currently available.",
            },
            Games = StatusGames,
            Places = StatusPlaces,
        },
        FailureStatus = {
            State = "limited",
            Status = "yellow",
            Label = "Status Unavailable",
        },
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

    OnReady = function(window, loaded, reason, detection)
        VitalityLive.Window = window
        VitalityLive.Detection = detection
        VitalityLive.LiveModuleId = resolveCurrentLiveModuleId(detection)

        connectVitalityLive(window, detection)

        if OWNER_CONTEXT.IsOwner then
            registerLiveOwnerCommands(window)

            task.spawn(function()
                local ok, authError = authenticateLiveOwner()
                if ok then
                    window:Notify({
                        Title = "Vitality Live",
                        Content = "Owner live-service access authenticated.",
                        Type = "Success",
                        Duration = 4,
                    })
                else
                    warn("[VitalityLive] Owner authentication unavailable: " .. tostring(authError))
                end
            end)
        end
    end,
})
