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

    -- Once Cloudflare state is available it is authoritative. A removed module
    -- must stay removed instead of being resurrected by the static fallback.
    if type(modules) == "table" then
        return type(modules[moduleId]) == "table"
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
    if window._refreshCommandSuggestions then
        pcall(function() window:_refreshCommandSuggestions() end)
    end
    return true
end

local function liveStatusLabel(status)
    local key = tostring(status or "testing"):lower()
    local definition = LOCAL_STATUS_DEFINITIONS[key]
    return definition and definition.Label or key
end

local function liveModuleDisplayName(moduleId, fallbackState)
    moduleId = normalizeLiveModuleId(moduleId)
    local modules = VitalityLive.State and VitalityLive.State.modules
    local state = type(modules) == "table" and modules[moduleId] or nil
    state = type(state) == "table" and state or fallbackState
    if type(state) == "table" and tostring(state.name or "") ~= "" then
        return tostring(state.name)
    end
    return moduleId ~= "" and moduleId or "Module"
end

local function showLiveBroadcast(data)
    local window = VitalityLive.Window
    if not window then return false end
    data = type(data) == "table" and data or {}

    if type(window.Broadcast) == "function" then
        local ok, result = pcall(function() return window:Broadcast(data) end)
        if ok then return result ~= false end
    end

    -- Compatibility fallback for an older library build.
    local fallbackType = "Info"
    local kind = tostring(data.Type or data.Style or ""):lower()
    if kind:find("success", 1, true) or kind:find("added", 1, true) then fallbackType = "Success"
    elseif kind:find("warning", 1, true) or kind:find("update", 1, true) then fallbackType = "Warning"
    elseif kind:find("error", 1, true) or kind:find("removed", 1, true) then fallbackType = "Error" end
    window:Notify({
        Title = tostring(data.Title or "Vitality Broadcast"),
        Content = tostring(data.Message or data.Content or ""),
        Type = fallbackType,
        Duration = tonumber(data.Duration) or 8,
    })
    return true
end

local function notifyLiveBroadcast(packet)
    local style = tostring(packet.style or "owner"):lower()
    local title = tostring(packet.title or (style == "owner" and "Vitality Broadcast" or "Vitality Announcement"))
    return showLiveBroadcast({
        Id = packet.id,
        Style = style,
        Title = title,
        Message = tostring(packet.message or ""),
        Duration = tonumber(packet.duration) or 10,
        Priority = tostring(packet.priority or (style == "error" and "critical" or style == "warning" and "high" or "normal")),
        Footer = packet.sentBy and "Vitality Staff" or nil,
    })
end

local function notifyModuleLiveEvent(packet)
    if type(packet) ~= "table" then return false end
    local eventType = tostring(packet.type or "")
    local moduleId = normalizeLiveModuleId(packet.module)
    local moduleState = type(packet.moduleState) == "table" and packet.moduleState or {}
    local name = liveModuleDisplayName(moduleId, moduleState)
    local status = liveStatusLabel(moduleState.status)
    local version = tostring(moduleState.version or "")
    local eventId = eventType .. ":" .. moduleId .. ":" .. tostring(packet.timestamp or os.clock())

    if eventType == "module.added" then
        return showLiveBroadcast({
            Id = eventId,
            Type = "ModuleAdded",
            Title = name .. " Added",
            Message = "A new Vitality module is now available.",
            Duration = 10,
            Priority = "normal",
            Module = moduleId,
            Status = status,
            Version = version,
        })
    end

    if eventType == "module.removed" then
        return showLiveBroadcast({
            Id = eventId,
            Type = "ModuleRemoved",
            Title = name .. " Removed",
            Message = "This Vitality module is no longer available.",
            Duration = 10,
            Priority = "critical",
            Module = moduleId,
            Status = status,
            Version = version,
        })
    end

    if eventType ~= "module.updated" then return false end
    local changes = type(packet.changes) == "table" and packet.changes or {}

    -- Reason-only edits are useful metadata but should not interrupt everyone
    -- with a large broadcast. Status/source/version/availability changes do.
    local meaningful = changes.version ~= nil
        or changes.url ~= nil
        or changes.enabled ~= nil
        or changes.status ~= nil
    if not meaningful then return false end

    local title = name .. " Updated"
    local message = "The module configuration has been updated."
    local priority = "high"
    local badge = nil

    if changes.enabled == false then
        title = name .. " Disabled"
        message = "This module has been disabled for future executions."
        priority = "critical"
        badge = "DISABLED"
    elseif changes.enabled == true then
        title = name .. " Enabled"
        message = "This module is available again."
        priority = "normal"
        badge = "ENABLED"
    elseif changes.version ~= nil then
        message = "Version " .. tostring(moduleState.version or changes.version) .. " is now available."
        badge = "UPDATE"
    elseif changes.url ~= nil then
        message = "The hosted module source has been updated."
        badge = "SOURCE UPDATE"
    elseif changes.status ~= nil then
        title = name .. " Status Changed"
        message = "Module status is now " .. status .. "."
        priority = (tostring(moduleState.status) == "broken" or tostring(moduleState.status) == "maintenance") and "high" or "normal"
        badge = "STATUS"
    end

    return showLiveBroadcast({
        Id = eventId,
        Type = "ModuleUpdate",
        Badge = badge,
        Title = title,
        Message = message,
        Duration = 10,
        Priority = priority,
        Module = moduleId,
        Status = status,
        Version = version,
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
        notifyModuleLiveEvent(packet)
        return
    end

    if packet.type == "module.removed" then
        VitalityLive.State = type(VitalityLive.State) == "table" and VitalityLive.State or {modules = {}}
        VitalityLive.State.modules = type(VitalityLive.State.modules) == "table" and VitalityLive.State.modules or {}
        notifyModuleLiveEvent(packet)
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

local LIVE_STATUS_ORDER = {
    "functional",
    "testing",
    "limited",
    "broken",
    "maintenance",
    "updating",
}

local function liveModuleAutocompleteSuggestions()
    local results = {}
    local seen = {}
    local modules = VitalityLive.State and VitalityLive.State.modules

    if type(modules) == "table" then
        for rawId, moduleState in pairs(modules) do
            local moduleId = normalizeLiveModuleId(rawId)
            if moduleId ~= "" and type(moduleState) == "table" then
                seen[moduleId] = true
                local statusName = tostring(moduleState.status or "testing"):lower()
                local definition = LOCAL_STATUS_DEFINITIONS[statusName] or LOCAL_STATUS_DEFINITIONS.testing
                local moduleName = tostring(moduleState.name or moduleId)
                local enabledText = moduleState.enabled == false and " - Disabled" or ""

                table.insert(results, {
                    Value = moduleId,
                    Name = moduleId,
                    Insert = moduleId,
                    Description = moduleName .. enabledText,
                    Meta = definition.Label,
                    Aliases = {moduleName},
                })
            end
        end
    else
        -- Static fallback is only used before Cloudflare state has been loaded.
        for _, profile in pairs(SupportedGames) do
            if type(profile) == "table" then
                local moduleId = normalizeLiveModuleId(profile.LiveModuleId or profile.ModuleId)
                if moduleId ~= "" and not seen[moduleId] then
                    seen[moduleId] = true
                    local stateName = tostring(profile.State or "testing"):lower()
                    local definition = LOCAL_STATUS_DEFINITIONS[stateName] or LOCAL_STATUS_DEFINITIONS.testing
                    table.insert(results, {
                        Value = moduleId,
                        Name = moduleId,
                        Insert = moduleId,
                        Description = tostring(profile.Name or moduleId),
                        Meta = definition.Label,
                        Aliases = {tostring(profile.Name or moduleId)},
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        local aName = tostring(a.Description or a.Name):lower()
        local bName = tostring(b.Description or b.Name):lower()
        if aName == bName then return tostring(a.Name) < tostring(b.Name) end
        return aName < bName
    end)
    return results
end

local function liveStatusAutocompleteSuggestions()
    local results = {}
    for _, statusName in ipairs(LIVE_STATUS_ORDER) do
        local definition = LOCAL_STATUS_DEFINITIONS[statusName] or {}
        table.insert(results, {
            Value = statusName,
            Name = statusName,
            Insert = statusName,
            Description = tostring(definition.Label or statusName),
            Meta = "status",
            Aliases = {tostring(definition.Label or statusName)},
        })
    end
    return results
end

local function moduleArgumentAutocomplete(context)
    if context.ArgIndex == 1 then
        return liveModuleAutocompleteSuggestions()
    end
    return {}
end

local function statusArgumentAutocomplete(context)
    if context.ArgIndex == 1 then
        return liveModuleAutocompleteSuggestions()
    elseif context.ArgIndex == 2 then
        return liveStatusAutocompleteSuggestions()
    elseif context.ArgIndex == 3 and tostring(context.Fragment or "") == "" then
        return {{
            Kind = "hint",
            Value = "<reason>",
            Name = "<reason>",
            Insert = "<reason>",
            Description = "Required: explain why the module has this status",
            Meta = "required",
        }}
    end
    return {}
end

local function removeModuleAutocomplete(context)
    if context.ArgIndex == 1 then
        return liveModuleAutocompleteSuggestions()
    elseif context.ArgIndex == 2 then
        return {{Value = "confirm", Name = "confirm", Insert = "confirm", Description = "Confirm permanent live-registry removal", Meta = "required"}}
    end
    return {}
end

local function addModuleAutocomplete(context)
    -- addmodule args: id, gameId, name, url|local, status, version
    if context.ArgIndex == 4 then
        return {{
            Value = "local",
            Name = "local",
            Insert = "local",
            Description = "Create a development draft with no hosted module URL yet",
            Meta = "development",
        }}
    elseif context.ArgIndex == 5 then
        return liveStatusAutocompleteSuggestions()
    end
    return {}
end

local function copyDeveloperValue(value)
    local text = tostring(value or "")
    local candidates = {}

    if type(setclipboard) == "function" then table.insert(candidates, setclipboard) end
    if type(toclipboard) == "function" then table.insert(candidates, toclipboard) end
    if syn and type(syn.write_clipboard) == "function" then table.insert(candidates, syn.write_clipboard) end
    if Clipboard and type(Clipboard.set) == "function" then
        table.insert(candidates, function(v) Clipboard.set(v) end)
    end

    for _, callback in ipairs(candidates) do
        local ok = pcall(callback, text)
        if ok then return true end
    end
    return false
end

local function currentLiveModuleForDeveloper()
    local moduleId = normalizeLiveModuleId(VitalityLive.LiveModuleId)
    local modules = VitalityLive.State and VitalityLive.State.modules

    if type(modules) == "table" then
        if moduleId ~= "" and moduleId ~= "unsupported" and type(modules[moduleId]) == "table" then
            return moduleId, modules[moduleId]
        end

        for candidateId, moduleState in pairs(modules) do
            if type(moduleState) == "table" and tonumber(moduleState.gameId) == tonumber(game.GameId) then
                return normalizeLiveModuleId(candidateId), moduleState
            end
        end
    end

    return moduleId ~= "" and moduleId or "unsupported", nil
end

local function notifyCopiedDeveloperValue(window, title, label, value)
    local text = tostring(value or "")
    local copied = copyDeveloperValue(text)
    window:Notify({
        Title = title,
        Content = label .. ": " .. text .. (copied and "\nCopied to clipboard." or "\nClipboard API unavailable; value shown above."),
        Type = copied and "Success" or "Info",
        Duration = 5,
    })
end


-- ============================================================
-- OWNER DEVELOPMENT WORKSPACE
-- ============================================================
-- `/executor`, `/loadmodule`, and `/reloadmodule` are intentionally local
-- development tools. Source is stored per game.GameId on the owner's executor
-- and is never uploaded to Cloudflare automatically.
local DevWorkspace = {
    Window = nil,
    PreviewWindow = nil,
    Gui = nil,
    Root = nil,
    Editor = nil,
    EditorScroll = nil,
    TabStrip = nil,
    TabLayout = nil,
    StatusLabel = nil,
    OutputLabel = nil,
    ModuleIdInput = nil,
    ModuleNameInput = nil,
    ModuleStateLabel = nil,
    Workspace = nil,
    Runtime = nil,
    ScratchRuntimes = {},
    OutputLines = {},
    LogEntries = {},
    SaveToken = 0,
    RemoveConfirmUntil = 0,

    -- Paged editor state. The full source remains in Workspace.Tabs[n].Code;
    -- the Roblox TextBox only ever renders one safe-sized page at a time.
    PageIndex = 1,
    PageMap = {},
    CurrentPage = nil,
    PageLabel = nil,
    JumpLineInput = nil,
    ImportPathInput = nil,
    _pageDirty = false,
    _suppressEditorChange = false,
    _editorLayoutToken = 0,
}

NovaField.DeveloperWorkspace = DevWorkspace

local DEV_ROOT_FOLDER = "VitalityHub"
local DEV_FOLDER = DEV_ROOT_FOLDER .. "/Developer"
local DEV_GAME_FOLDER = DEV_FOLDER .. "/" .. tostring(game.GameId)
local DEV_WORKSPACE_FILE = DEV_GAME_FOLDER .. "/workspace.json"

-- Roblox/executor TextBox implementations can truncate large text around the
-- ~16k-character range. Keep each visible page safely below that while storing
-- and executing the complete source independently of the TextBox.
local DEV_EDITOR_PAGE_MAX_LINES = 300
local DEV_EDITOR_PAGE_MAX_CHARS = 12000
local DEV_EDITOR_LINE_HEIGHT = 18
local DEV_EDITOR_CHAR_WIDTH = 8.4
local DEV_EDITOR_MAX_CANVAS_WIDTH = 120000
local DEV_LOG_MAX_ENTRIES = 5000
local DEV_LOG_VISIBLE_ENTRIES = 7
local DEV_LOG_FOLDER = DEV_GAME_FOLDER .. "/Logs"
local DEV_IMPORT_FOLDER = DEV_GAME_FOLDER .. "/Imports"
local DEV_LOG_FILE = DEV_LOG_FOLDER .. "/latest.log"

local function devEnsureFolder(path)
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
        return false
    end
    local ok, exists = pcall(isfolder, path)
    if ok and exists then return true end
    return pcall(makefolder, path)
end

local function devEnsureFolders()
    devEnsureFolder(DEV_ROOT_FOLDER)
    devEnsureFolder(DEV_FOLDER)
    devEnsureFolder(DEV_GAME_FOLDER)
    devEnsureFolder(DEV_LOG_FOLDER)
    devEnsureFolder(DEV_IMPORT_FOLDER)
end

local function devPersistenceAvailable()
    return type(readfile) == "function"
        and type(writefile) == "function"
        and type(isfile) == "function"
end

local function devSanitizeTabName(value)
    local name = tostring(value or "")
        :gsub("[%c/\\:*?\"<>|]", "_")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if name == "" then name = "script.lua" end
    if not name:lower():match("%.lua$") then name = name .. ".lua" end
    return name:sub(1, 64)
end

local function devCurrentModule()
    local moduleId, moduleState = currentLiveModuleForDeveloper()
    if moduleId == "" or moduleId == "unsupported" then
        moduleId = "dev-" .. tostring(game.GameId)
    end
    return moduleId, moduleState
end

local function devSuggestedModuleId()
    local base = tostring(game.Name or "game")
        :lower()
        :gsub("[^%w]+", "-")
        :gsub("^%-+", "")
        :gsub("%-+$", "")

    if base == "" then
        base = "game-" .. tostring(game.GameId)
    end

    return normalizeLiveModuleId(base)
end

local function devDefaultSource()
    return [[-- Vitality Development Module Base
-- ============================================================
-- KEEP THIS MODULE WRAPPER INTACT.
-- Add/test features inside Module:Start(Context).
-- /loadmodule opens a SEPARATE Vitality preview window.
-- /reloadmodule destroys that preview and rebuilds it from this file.
-- This file is local to the current game.GameId until you publish it.

local Module = {}

function Module:Start(Context)
    -- Context.Window is the isolated DEVELOPMENT PREVIEW window.
    -- It is NOT the currently running production/unsupported Vitality window.
    local Window = Context.Window

    local MainTab = Context:CreateTab("Main", "code")
    local Overview = MainTab:CreateSection({
        Name = Context.ModuleName or "Development Module",
        Description = "Isolated preview - GameId " .. tostring(Context.GameId),
        Side = "Left",
    })

    Overview:CreateParagraph({
        Title = "Development preview",
        Content = "This UI is a separate preview copy. Edit main.lua, save, then use /reloadmodule to rebuild it.",
    })

    local Info = MainTab:CreateSection({
        Name = "Module Base",
        Description = "Add controls and features here without changing the loader/library architecture.",
        Side = "Right",
    })

    Info:CreateParagraph({
        Title = "Ready for development",
        Content = "Ask AI to preserve this wrapper and only build your module features inside Module:Start(Context).",
    })

    Context:Log("Preview scaffold started for " .. tostring(Context.ModuleId))
end

function Module:Destroy(reason)
    -- Context-owned tabs, connections, instances, tasks and cleanup callbacks
    -- are cleaned automatically when /reloadmodule or /unloadmodule runs.
end

return Module
]]
end

local function devTimestamp()
    if os and type(os.date) == "function" then
        local ok, value = pcall(os.date, "%H:%M:%S")
        if ok and type(value) == "string" then return value end
    end
    return string.format("%.2f", os.clock())
end

local function devResolveClipboardReader()
    local env = type(getgenv) == "function" and getgenv() or _G

    for _, name in ipairs({"getclipboard", "readclipboard", "get_clipboard", "read_clipboard"}) do
        local candidate = rawget(env, name)
        if type(candidate) == "function" then
            return function()
                local ok, value = pcall(candidate)
                if ok and type(value) == "string" then return true, value end
                return false, value
            end
        end
    end

    local clipboard = rawget(env, "Clipboard") or rawget(env, "clipboard")
    if type(clipboard) == "table" then
        for _, name in ipairs({"get", "read", "Get", "Read"}) do
            local method = clipboard[name]
            if type(method) == "function" then
                return function()
                    local ok, value = pcall(method, clipboard)
                    if (not ok) or type(value) ~= "string" then
                        ok, value = pcall(method)
                    end
                    if ok and type(value) == "string" then return true, value end
                    return false, value
                end
            end
        end
    end

    return nil
end

local function devResolveClipboardWriter()
    local env = type(getgenv) == "function" and getgenv() or _G

    for _, name in ipairs({"setclipboard", "toclipboard", "set_clipboard"}) do
        local candidate = rawget(env, name)
        if type(candidate) == "function" then
            return function(value)
                local ok, err = pcall(candidate, tostring(value or ""))
                return ok, err
            end
        end
    end

    local clipboard = rawget(env, "Clipboard") or rawget(env, "clipboard")
    if type(clipboard) == "table" then
        for _, name in ipairs({"set", "write", "Set", "Write"}) do
            local method = clipboard[name]
            if type(method) == "function" then
                return function(value)
                    value = tostring(value or "")
                    local ok, err = pcall(method, clipboard, value)
                    if not ok then ok, err = pcall(method, value) end
                    return ok, err
                end
            end
        end
    end

    return nil
end

local function devBuildEditorPages(source)
    source = tostring(source or "")
    if source == "" then
        return {{StartChar = 1, EndChar = 0, StartLine = 1, EndLine = 1, Text = ""}}, 1
    end

    local pages = {}
    local sourceLength = #source
    local cursor = 1
    local currentLine = 1
    local pageStartChar = 1
    local pageStartLine = 1
    local pageChars = 0
    local pageLines = 0

    local function closePage(endChar, endLine)
        if endChar < pageStartChar then return end
        table.insert(pages, {
            StartChar = pageStartChar,
            EndChar = endChar,
            StartLine = pageStartLine,
            EndLine = math.max(pageStartLine, endLine),
            Text = source:sub(pageStartChar, endChar),
        })
    end

    while cursor <= sourceLength do
        local newline = string.find(source, "\n", cursor, true)
        local segmentEnd = newline or sourceLength
        local segmentLength = segmentEnd - cursor + 1

        -- Extremely long single lines are split by characters so no individual
        -- TextBox page can cross the safe character threshold.
        if segmentLength > DEV_EDITOR_PAGE_MAX_CHARS then
            if pageChars > 0 then
                closePage(cursor - 1, currentLine - 1)
                pageStartChar = cursor
                pageStartLine = currentLine
                pageChars = 0
                pageLines = 0
            end

            local longCursor = cursor
            while longCursor <= segmentEnd do
                local pieceEnd = math.min(segmentEnd, longCursor + DEV_EDITOR_PAGE_MAX_CHARS - 1)
                table.insert(pages, {
                    StartChar = longCursor,
                    EndChar = pieceEnd,
                    StartLine = currentLine,
                    EndLine = currentLine,
                    Text = source:sub(longCursor, pieceEnd),
                })
                longCursor = pieceEnd + 1
            end

            cursor = segmentEnd + 1
            if newline then currentLine = currentLine + 1 end
            pageStartChar = cursor
            pageStartLine = currentLine
            pageChars = 0
            pageLines = 0
        else
            local wouldOverflow = pageLines > 0 and (
                pageLines >= DEV_EDITOR_PAGE_MAX_LINES
                or pageChars + segmentLength > DEV_EDITOR_PAGE_MAX_CHARS
            )

            if wouldOverflow then
                closePage(cursor - 1, currentLine - 1)
                pageStartChar = cursor
                pageStartLine = currentLine
                pageChars = 0
                pageLines = 0
            end

            pageChars = pageChars + segmentLength
            pageLines = pageLines + 1
            cursor = segmentEnd + 1
            if newline then currentLine = currentLine + 1 end
        end
    end

    if pageChars > 0 and pageStartChar <= sourceLength then
        closePage(sourceLength, currentLine)
    end

    if #pages == 0 then
        table.insert(pages, {StartChar = 1, EndChar = sourceLength, StartLine = 1, EndLine = currentLine, Text = source})
    end

    local totalLines = 1
    for _ in source:gmatch("\n") do totalLines = totalLines + 1 end
    return pages, totalLines
end

local function devNormalizeWorkspace(data)
    data = type(data) == "table" and data or {}

    local normalized = {
        Version = 2,
        Active = tostring(data.Active or "main.lua"),
        Tabs = {},
    }

    local mainTab = nil
    local otherTabs = {}
    local seen = {}

    if type(data.Tabs) == "table" then
        for _, item in ipairs(data.Tabs) do
            if type(item) == "table" then
                local name = devSanitizeTabName(item.Name or item.name)
                local lowered = name:lower()

                if not seen[lowered] then
                    seen[lowered] = true
                    local normalizedItem = {
                        Name = lowered == "main.lua" and "main.lua" or name,
                        Code = tostring(item.Code or item.code or ""),
                    }

                    if lowered == "main.lua" then
                        mainTab = normalizedItem
                    else
                        table.insert(otherTabs, normalizedItem)
                    end
                end
            end
        end
    end

    -- main.lua is reserved and is ALWAYS the first tab. It is the only editor
    -- tab that represents the isolated DevelopmentPreview module entrypoint.
    mainTab = mainTab or {
        Name = "main.lua",
        Code = devDefaultSource(),
    }
    table.insert(normalized.Tabs, mainTab)

    for _, item in ipairs(otherTabs) do
        table.insert(normalized.Tabs, item)
    end

    local activeExists = false
    for _, item in ipairs(normalized.Tabs) do
        if item.Name == normalized.Active then
            activeExists = true
            break
        end
    end

    if not activeExists then
        normalized.Active = "main.lua"
    end

    return normalized
end

function DevWorkspace:_notify(options)
    local window = self.Window or VitalityLive.Window
    if window and type(window.Notify) == "function" then
        pcall(function() window:Notify(options) end)
    end
end

function DevWorkspace:_appendOutput(message, kind)
    kind = tostring(kind or "info"):lower()
    local prefix = kind == "error" and "[ERROR] "
        or kind == "success" and "[OK] "
        or kind == "warn" and "[WARN] "
        or "[INFO] "

    local entry = {
        Time = devTimestamp(),
        Kind = kind,
        Message = tostring(message or ""),
    }
    entry.Text = "[" .. entry.Time .. "] " .. prefix .. entry.Message

    self.LogEntries = type(self.LogEntries) == "table" and self.LogEntries or {}
    table.insert(self.LogEntries, entry)
    while #self.LogEntries > DEV_LOG_MAX_ENTRIES do table.remove(self.LogEntries, 1) end

    -- Kept for compatibility with older code that may inspect OutputLines.
    self.OutputLines = type(self.OutputLines) == "table" and self.OutputLines or {}
    table.insert(self.OutputLines, entry.Text)
    while #self.OutputLines > 100 do table.remove(self.OutputLines, 1) end

    if self.OutputLabel and self.OutputLabel.Parent then
        local startIndex = math.max(1, #self.LogEntries - DEV_LOG_VISIBLE_ENTRIES + 1)
        local visible = {}
        for index = startIndex, #self.LogEntries do
            table.insert(visible, self.LogEntries[index].Text)
        end
        self.OutputLabel.Text = table.concat(visible, "\n")
    end
end

function DevWorkspace:_logHeader()
    local moduleId, moduleState = devCurrentModule()
    local active = self.Workspace and self.Workspace.Active or "unknown"
    local moduleName = type(moduleState) == "table" and tostring(moduleState.name or moduleId) or tostring(moduleId)
    return table.concat({
        "Vitality Developer Logs",
        "GameId: " .. tostring(game.GameId),
        "PlaceId: " .. tostring(game.PlaceId),
        "Module: " .. tostring(moduleId) .. " (" .. moduleName .. ")",
        "Active Tab: " .. tostring(active),
        "Entries: " .. tostring(#(self.LogEntries or {})),
        string.rep("-", 64),
    }, "\n")
end

function DevWorkspace:_allLogsText()
    local lines = {self:_logHeader()}
    for _, entry in ipairs(self.LogEntries or {}) do
        table.insert(lines, entry.Text or tostring(entry.Message or ""))
    end
    return table.concat(lines, "\n")
end

function DevWorkspace:_lastErrorText()
    local entries = self.LogEntries or {}
    local errorIndex
    for index = #entries, 1, -1 do
        if entries[index].Kind == "error" then
            errorIndex = index
            break
        end
    end
    if not errorIndex then return nil end

    local lines = {self:_logHeader(), "Last error context:"}
    local first = math.max(1, errorIndex - 3)
    local last = math.min(#entries, errorIndex + 3)
    for index = first, last do
        table.insert(lines, entries[index].Text or tostring(entries[index].Message or ""))
    end
    return table.concat(lines, "\n")
end

function DevWorkspace:_copyOrSaveText(value, label)
    value = tostring(value or "")
    local writer = devResolveClipboardWriter()
    if writer then
        local ok, err = writer(value)
        if ok then
            self:_appendOutput(tostring(label or "Text") .. " copied to clipboard.", "success")
            return true
        end
        self:_appendOutput("Clipboard write failed: " .. tostring(err), "warn")
    end

    if type(writefile) == "function" then
        devEnsureFolders()
        local ok, err = pcall(writefile, DEV_LOG_FILE, value)
        if ok then
            self:_appendOutput("Clipboard unavailable; saved " .. tostring(label or "text") .. " to " .. DEV_LOG_FILE .. ".", "success")
            return true
        end
        self:_appendOutput("Could not save log fallback: " .. tostring(err), "error")
        return false
    end

    self:_appendOutput("Clipboard/file APIs are unavailable; cannot export " .. tostring(label or "text") .. ".", "error")
    return false
end

function DevWorkspace:CopyLogs()
    return self:_copyOrSaveText(self:_allLogsText(), "logs")
end

function DevWorkspace:CopyLastError()
    local value = self:_lastErrorText()
    if not value then
        self:_appendOutput("There is no error in the current developer log buffer.", "warn")
        return false
    end
    return self:_copyOrSaveText(value, "last error")
end

function DevWorkspace:ClearLogs()
    self.LogEntries = {}
    self.OutputLines = {}
    if self.OutputLabel and self.OutputLabel.Parent then self.OutputLabel.Text = "" end
    self:_appendOutput("Developer logs cleared.", "info")
    return true
end

function DevWorkspace:_loadWorkspace()
    if self.Workspace then return self.Workspace end

    local data
    if devPersistenceAvailable() then
        devEnsureFolders()
        local okExists, exists = pcall(isfile, DEV_WORKSPACE_FILE)
        if okExists and exists then
            local okRead, raw = pcall(readfile, DEV_WORKSPACE_FILE)
            if okRead and type(raw) == "string" then
                local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
                if okDecode and type(decoded) == "table" then data = decoded end
            end
        end
    end

    self.Workspace = devNormalizeWorkspace(data)
    self:_saveWorkspace(true)
    return self.Workspace
end

function DevWorkspace:_activeTab()
    local workspace = self:_loadWorkspace()
    for _, item in ipairs(workspace.Tabs) do
        if item.Name == workspace.Active then return item end
    end
    workspace.Active = workspace.Tabs[1].Name
    return workspace.Tabs[1]
end

function DevWorkspace:_syncEditorToWorkspace()
    if not self.Editor or not self.Editor.Parent or not self.Workspace then return end
    if self._suppressEditorChange or not self._pageDirty then return end

    local item = self:_activeTab()
    local page = self.CurrentPage
    if not item or not page then return end

    local source = tostring(item.Code or "")
    local prefix = source:sub(1, math.max(0, page.StartChar - 1))
    local suffix = source:sub(math.max(1, page.EndChar + 1))
    local pageText = tostring(self.Editor.Text or "")
    item.Code = prefix .. pageText .. suffix

    -- Keep the active slice coordinates valid after autosave. Without this, an
    -- edit that changes the current page length could make the next autosave
    -- splice at stale character offsets.
    page.EndChar = page.StartChar + #pageText - 1
    page.Text = pageText
    self._pageDirty = false
end

function DevWorkspace:_updatePageLabel(totalLines)
    if not self.PageLabel or not self.PageLabel.Parent then return end
    local pageCount = math.max(1, #(self.PageMap or {}))
    local pageIndex = math.clamp(tonumber(self.PageIndex) or 1, 1, pageCount)
    local page = self.PageMap and self.PageMap[pageIndex]
    if page then
        self.PageLabel.Text = string.format(
            "Page %d / %d   •   Lines %d-%d / %d",
            pageIndex,
            pageCount,
            page.StartLine,
            page.EndLine,
            tonumber(totalLines) or page.EndLine
        )
    else
        self.PageLabel.Text = "Page 1 / 1"
    end
end

function DevWorkspace:_loadEditorPage(index)
    local item = self:_activeTab()
    if not item then return false end

    local pages, totalLines = devBuildEditorPages(item.Code)
    self.PageMap = pages
    self.PageIndex = math.clamp(tonumber(index) or 1, 1, math.max(1, #pages))
    self.CurrentPage = pages[self.PageIndex]
    self._pageDirty = false

    if self.Editor and self.Editor.Parent then
        self._suppressEditorChange = true
        self.Editor.Text = self.CurrentPage and self.CurrentPage.Text or ""
        self.Editor.CursorPosition = #self.Editor.Text + 1
        self._suppressEditorChange = false
    end

    if self.EditorScroll and self.EditorScroll.Parent then
        self.EditorScroll.CanvasPosition = Vector2.new(0, 0)
    end

    self:_updatePageLabel(totalLines)
    self:_refreshEditorCanvas()
    return true
end

function DevWorkspace:_changeEditorPage(delta)
    self:_syncEditorToWorkspace()
    local item = self:_activeTab()
    if not item then return false end
    local pages = devBuildEditorPages(item.Code)
    local nextIndex = math.clamp((tonumber(self.PageIndex) or 1) + tonumber(delta or 0), 1, math.max(1, #pages))
    return self:_loadEditorPage(nextIndex)
end

function DevWorkspace:_jumpToLine(value)
    self:_syncEditorToWorkspace()
    local item = self:_activeTab()
    if not item then return false end

    local pages, totalLines = devBuildEditorPages(item.Code)
    local line = math.clamp(math.floor(tonumber(value) or 1), 1, math.max(1, totalLines))
    local target = 1
    for index, page in ipairs(pages) do
        if line >= page.StartLine and line <= page.EndLine then
            target = index
            break
        end
    end
    return self:_loadEditorPage(target)
end

function DevWorkspace:_replaceActiveSource(source, reason)
    local item = self:_activeTab()
    if not item then return false end
    item.Code = tostring(source or "")
    self._pageDirty = false
    self.PageIndex = 1
    self:_loadEditorPage(1)
    self:_saveWorkspace(true)
    if reason then self:_appendOutput(reason, "success") end
    return true
end

function DevWorkspace:PasteFullScript()
    local reader = devResolveClipboardReader()
    if not reader then
        self:_appendOutput(
            "This executor does not expose a readable clipboard API. Put the .lua file in the Imports folder and use Import File instead.",
            "error"
        )
        return false
    end

    local ok, value = reader()
    if not ok or type(value) ~= "string" then
        self:_appendOutput("Could not read clipboard: " .. tostring(value), "error")
        return false
    end

    local pages, totalLines = devBuildEditorPages(value)
    local item = self:_activeTab()
    local name = item and item.Name or "tab"
    self:_replaceActiveSource(value)
    self:_appendOutput(
        string.format("Imported full clipboard into %s: %d lines, %d chars, %d editor pages.", name, totalLines, #value, #pages),
        "success"
    )
    return true
end

function DevWorkspace:ImportFile(path)
    path = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if path == "" then
        self:_appendOutput("Enter a local .lua file path before using Import File.", "warn")
        return false
    end
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        self:_appendOutput("This executor does not expose readfile/isfile.", "error")
        return false
    end

    local okExists, exists = pcall(isfile, path)
    if not okExists or not exists then
        self:_appendOutput("Import file was not found: " .. path, "error")
        return false
    end

    local okRead, value = pcall(readfile, path)
    if not okRead or type(value) ~= "string" then
        self:_appendOutput("Could not read import file: " .. tostring(value), "error")
        return false
    end

    local pages, totalLines = devBuildEditorPages(value)
    local item = self:_activeTab()
    local name = item and item.Name or "tab"
    self:_replaceActiveSource(value)
    self:_appendOutput(
        string.format("Imported %s into %s: %d lines, %d chars, %d editor pages.", path, name, totalLines, #value, #pages),
        "success"
    )
    return true
end

function DevWorkspace:_saveWorkspace(silent)
    local workspace = self.Workspace
    if not workspace then return false end
    self:_syncEditorToWorkspace()

    if not devPersistenceAvailable() then
        if not silent then
            self:_appendOutput("File APIs unavailable; workspace is only saved for this session.", "warn")
        end
        return false
    end

    devEnsureFolders()
    local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, workspace)
    if not okEncode then
        if not silent then self:_appendOutput("Could not encode workspace: " .. tostring(encoded), "error") end
        return false
    end

    local okWrite, writeError = pcall(writefile, DEV_WORKSPACE_FILE, encoded)
    if not okWrite then
        if not silent then self:_appendOutput("Could not save workspace: " .. tostring(writeError), "error") end
        return false
    end

    if not silent then self:_appendOutput("Workspace saved.", "success") end
    return true
end

function DevWorkspace:_scheduleSave()
    self.SaveToken = self.SaveToken + 1
    local token = self.SaveToken
    task.delay(0.8, function()
        if token ~= self.SaveToken then return end
        self:_saveWorkspace(true)
    end)
end

local function devCleanupResource(resource)
    if resource == nil then return end
    local resourceType = typeof(resource)

    if resourceType == "RBXScriptConnection" then
        pcall(function() resource:Disconnect() end)
        return
    end

    if resourceType == "Instance" then
        pcall(function() resource:Destroy() end)
        return
    end

    if type(resource) == "thread" and task and type(task.cancel) == "function" then
        pcall(task.cancel, resource)
        return
    end

    if type(resource) == "function" then
        pcall(resource)
        return
    end

    for _, methodName in ipairs({"Destroy", "Cleanup", "Disconnect", "Cancel", "Remove"}) do
        local okMethod, method = pcall(function() return resource[methodName] end)
        if okMethod and type(method) == "function" then
            pcall(method, resource)
            return
        end
    end
end

local function devCreateContext(previewWindow)
    local moduleId, moduleState = devCurrentModule()
    local context = {
        Window = previewWindow,
        PreviewWindow = previewWindow,
        MainWindow = DevWorkspace.Window or VitalityLive.Window,
        Library = NovaField,
        ModuleId = moduleId,
        ModuleName = type(moduleState) == "table" and tostring(moduleState.name or moduleId) or tostring(game.Name),
        ModuleState = moduleState,
        GameId = game.GameId,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        IsDevelopmentPreview = true,
        Cancelled = false,
        Resources = {},
    }

    function context:Track(resource)
        if resource ~= nil then table.insert(self.Resources, resource) end
        return resource
    end

    context.Give = context.Track
    context.Add = context.Track
    context.Maid = context

    function context:AddCleanup(callback)
        if type(callback) == "function" then self:Track(callback) end
        return callback
    end

    function context:Connect(signal, callback)
        if not signal or type(signal.Connect) ~= "function" then
            error("Context:Connect expected an RBXScriptSignal-like object.", 2)
        end
        return self:Track(signal:Connect(callback))
    end

    function context:Create(className, properties)
        local instance = Instance.new(className)
        for key, value in pairs(type(properties) == "table" and properties or {}) do
            if key ~= "Parent" then instance[key] = value end
        end
        if type(properties) == "table" and properties.Parent ~= nil then
            instance.Parent = properties.Parent
        end
        return self:Track(instance)
    end

    function context:CreateTab(name, icon)
        if not self.Window or self.Window._destroyed then
            error("Development preview window is not available.", 2)
        end
        local tab = self.Window:CreateTab(name or "Development", icon or "code")
        if type(self.Window._setActiveTab) == "function" then
            pcall(function() self.Window:_setActiveTab(tab) end)
        end
        return tab
    end

    function context:Spawn(callback)
        if type(callback) ~= "function" then return nil end
        local owner = self
        local thread = task.spawn(function()
            local ok, err = pcall(callback, owner)
            if not ok and not owner.Cancelled then
                DevWorkspace:_appendOutput(err, "error")
            end
        end)
        self:Track(thread)
        return thread
    end

    function context:Delay(seconds, callback)
        if type(callback) ~= "function" then return nil end
        local owner = self
        local thread = task.delay(tonumber(seconds) or 0, function()
            if owner.Cancelled then return end
            local ok, err = pcall(callback, owner)
            if not ok and not owner.Cancelled then
                DevWorkspace:_appendOutput(err, "error")
            end
        end)
        self:Track(thread)
        return thread
    end

    function context:IsCancelled()
        return self.Cancelled == true
    end

    function context:Notify(data)
        if self.Window and type(self.Window.Notify) == "function" then
            self.Window:Notify(data)
        end
    end

    function context:Log(...)
        local parts = {}
        for index = 1, select("#", ...) do
            table.insert(parts, tostring(select(index, ...)))
        end
        DevWorkspace:_appendOutput(table.concat(parts, " "), "info")
    end

    function context:Destroy()
        if self.Cancelled then return end
        self.Cancelled = true
        for index = #self.Resources, 1, -1 do
            devCleanupResource(self.Resources[index])
        end
        table.clear(self.Resources)
    end

    return context
end

local function devCreateScratchContext()
    local context = devCreateContext(nil)
    context.Window = nil
    context.PreviewWindow = nil
    context.IsDevelopmentPreview = false
    context.IsScratchExecution = true

    -- Scratch tabs are deliberately UI-agnostic. They can execute arbitrary
    -- code, but they do not receive a base preview window automatically.
    function context:CreateTab()
        error("Scratch tabs do not own a DevelopmentPreview window. Put module UI in main.lua.", 2)
    end

    function context:Notify(data)
        local target = self.MainWindow
        if target and type(target.Notify) == "function" then
            target:Notify(data)
        end
    end

    return context
end

function DevWorkspace:_destroyScratchRuntime(name, reason)
    self.ScratchRuntimes = type(self.ScratchRuntimes) == "table" and self.ScratchRuntimes or {}
    local runtime = self.ScratchRuntimes[name]
    if not runtime then return false end
    self.ScratchRuntimes[name] = nil

    local returned = runtime.Returned
    if type(returned) == "table" then
        for _, methodName in ipairs({"Destroy", "Unload", "Stop", "Cleanup"}) do
            if type(returned[methodName]) == "function" then
                pcall(returned[methodName], returned, reason or "scratch rerun")
                break
            end
        end
    end

    if runtime.Context then
        runtime.Context:Destroy()
    end
    return true
end

function DevWorkspace:_destroyAllScratchRuntimes(reason)
    self.ScratchRuntimes = type(self.ScratchRuntimes) == "table" and self.ScratchRuntimes or {}
    local names = {}
    for name in pairs(self.ScratchRuntimes) do
        table.insert(names, name)
    end
    for _, name in ipairs(names) do
        self:_destroyScratchRuntime(name, reason or "workspace cleanup")
    end
end

local function devCompileSource(source, chunkName)
    local wrapped = "local Context = ...\n" .. tostring(source or "")
    local chunk, compileError
    local okNamed, namedResult, namedError = pcall(loadstring, wrapped, chunkName)
    if okNamed and type(namedResult) == "function" then
        chunk = namedResult
    else
        local okPlain, plainResult, plainError = pcall(loadstring, wrapped)
        if okPlain and type(plainResult) == "function" then
            chunk = plainResult
        else
            compileError = tostring(namedError or plainError or namedResult or plainResult or "Compilation failed.")
        end
    end
    return chunk, compileError
end

function DevWorkspace:_refreshModuleControls()
    local moduleId, moduleState = currentLiveModuleForDeveloper()
    local registered = type(moduleState) == "table"

    if self.ModuleIdInput and self.ModuleIdInput.Parent then
        self.ModuleIdInput.Text = registered and tostring(moduleId) or devSuggestedModuleId()
    end
    if self.ModuleNameInput and self.ModuleNameInput.Parent then
        self.ModuleNameInput.Text = registered and tostring(moduleState.name or game.Name) or tostring(game.Name)
    end
    if self.ModuleStateLabel and self.ModuleStateLabel.Parent then
        if registered then
            local sourceMode = tostring(moduleState.url or "") == "" and "LOCAL DRAFT" or "HOSTED"
            self.ModuleStateLabel.Text = tostring(moduleState.status or "testing"):upper() .. "  |  " .. sourceMode
            self.ModuleStateLabel.TextColor3 = Color3.fromRGB(173, 104, 220)
        else
            self.ModuleStateLabel.Text = "NOT REGISTERED"
            self.ModuleStateLabel.TextColor3 = Color3.fromRGB(214, 174, 87)
        end
    end
end

function DevWorkspace:RegisterCurrentGameDraft()
    local existingId, existingState = currentLiveModuleForDeveloper()
    if type(existingState) == "table" then
        self:_appendOutput("This GameId is already registered as " .. tostring(existingId) .. ".", "warn")
        self:_refreshModuleControls()
        return false
    end

    local moduleId = normalizeLiveModuleId(
        self.ModuleIdInput and self.ModuleIdInput.Text or devSuggestedModuleId()
    )
    local name = tostring(
        self.ModuleNameInput and self.ModuleNameInput.Text or game.Name
    ):gsub("^%s+", ""):gsub("%s+$", "")

    if moduleId == "" then
        self:_appendOutput("Enter a module id before registering the draft.", "error")
        return false
    end
    if name == "" then name = tostring(game.Name) end
    if liveModuleExists(moduleId) then
        self:_appendOutput("Module id already exists: " .. moduleId, "error")
        return false
    end

    local ok, result, err = liveOwnerRequest("POST", "/owner/modules", {
        id = moduleId,
        gameId = math.floor(tonumber(game.GameId) or 0),
        name = name,
        url = "",
        status = "testing",
        version = "0.1.0-dev",
        reason = "Local development draft.",
        enabled = true,
    })

    if ok and type(result) == "table" and type(result.moduleState) == "table" then
        VitalityLive.State = type(VitalityLive.State) == "table" and VitalityLive.State or {modules = {}}
        VitalityLive.State.modules = type(VitalityLive.State.modules) == "table" and VitalityLive.State.modules or {}
        VitalityLive.State.modules[moduleId] = result.moduleState
        VitalityLive.LiveModuleId = moduleId
        applyLiveState(VitalityLive.State, VitalityLive.Transport)
        updateOwnerLiveInfo()
        self:_appendOutput("Registered local draft: " .. name .. " (" .. moduleId .. ").", "success")
        self:_refreshModuleControls()
        return true
    end

    self:_appendOutput("Could not register module: " .. commandFailureText(result, err), "error")
    return false
end

function DevWorkspace:RemoveCurrentGameModule()
    local moduleId, moduleState = currentLiveModuleForDeveloper()
    if type(moduleState) ~= "table" or moduleId == "" or moduleId == "unsupported" then
        self:_appendOutput("This GameId does not have a live module to remove.", "warn")
        self:_refreshModuleControls()
        return false
    end

    local now = os.clock()
    if now > (tonumber(self.RemoveConfirmUntil) or 0) then
        self.RemoveConfirmUntil = now + 4
        self:_appendOutput("Click Remove Module again within 4 seconds to confirm removing " .. moduleId .. ".", "warn")
        return false
    end
    self.RemoveConfirmUntil = 0

    local ok, result, err = liveOwnerRequest("DELETE", "/owner/modules/" .. moduleId, {confirm = true})
    if ok then
        if type(VitalityLive.State) == "table" and type(VitalityLive.State.modules) == "table" then
            VitalityLive.State.modules[moduleId] = nil
            applyLiveState(VitalityLive.State, VitalityLive.Transport)
        end
        if normalizeLiveModuleId(VitalityLive.LiveModuleId) == moduleId then
            VitalityLive.LiveModuleId = nil
        end
        self:_appendOutput("Removed module from live registry: " .. moduleId .. ".", "success")
        self:_refreshModuleControls()
        return true
    end

    self:_appendOutput("Could not remove module: " .. commandFailureText(result, err), "error")
    return false
end

function DevWorkspace:_destroyPreviewWindow()
    local preview = self.PreviewWindow
    self.PreviewWindow = nil
    if preview and preview._destroyed ~= true and type(preview.Destroy) == "function" then
        pcall(function() preview:Destroy() end)
        return true
    end
    return false
end

function DevWorkspace:_createPreviewWindow()
    self:_destroyPreviewWindow()

    local moduleId, moduleState = devCurrentModule()
    local moduleName = type(moduleState) == "table" and tostring(moduleState.name or moduleId) or tostring(game.Name)
    local moduleVersion = type(moduleState) == "table" and tostring(moduleState.version or "0.1.0-dev") or "0.1.0-dev"

    local preview
    local ok, result = pcall(function()
        return NovaField:CreateWindow({
            Name = "vitality's hub",
            Icon = "vitality",
            WindowRole = "DeveloperPreview",

            -- The preview is intentionally independent from the production hub.
            -- ] / RightBracket is fixed and cannot be changed from Settings.
            ToggleKey = "RightBracket",
            FixedToggleKey = "RightBracket",

            CommandBar = {Enabled = false},
            CommandBarEnabled = false,
            KeySystem = false,
            Owner = {IsOwner = false},
            ConfigurationSaving = {Enabled = false},
            GameLoader = {Enabled = false},
            StatusControl = {Enabled = false},
            OnReady = function(window)
                pcall(function()
                    window:SetHeaderContext(moduleName .. " Preview", "DEV " .. moduleVersion)
                    window:SetScriptStatus("yellow", "Development Preview")
                end)
            end,
        })
    end)

    if not ok or type(result) ~= "table" then
        self:_appendOutput("Could not create isolated preview window: " .. tostring(result), "error")
        return nil
    end

    preview = result
    self.PreviewWindow = preview
    pcall(function()
        preview:SetHeaderContext(moduleName .. " Preview", "DEV " .. moduleVersion)
        preview:SetScriptStatus("yellow", "Development Preview")
    end)
    return preview
end

function DevWorkspace:_destroyRuntime(reason)
    local runtime = self.Runtime
    local hadPreview = self.PreviewWindow ~= nil
    if not runtime and not hadPreview then return false end
    self.Runtime = nil

    if runtime then
        local returned = runtime.Returned
        if type(returned) == "table" then
            for _, methodName in ipairs({"Destroy", "Unload", "Stop", "Cleanup"}) do
                if type(returned[methodName]) == "function" then
                    pcall(returned[methodName], returned, reason or "unload")
                    break
                end
            end
        end

        if runtime.Context then runtime.Context:Destroy() end
    end

    self:_destroyPreviewWindow()
    self:_appendOutput("Development preview stopped (" .. tostring(reason or "unload") .. ").", "warn")
    return true
end

function DevWorkspace:_executeModuleSource(window, source, sourceName)
    local chunk, compileError = devCompileSource(source, "@VitalityDev/" .. tostring(sourceName or "main.lua"))
    if not chunk then
        self:_appendOutput("Compile error: " .. tostring(compileError), "error")
        return false, compileError
    end

    local previewWindow = self:_createPreviewWindow()
    if not previewWindow then
        return false, "Could not create development preview window."
    end

    local context = devCreateContext(previewWindow)
    local okRun, returned = pcall(chunk, context)
    if not okRun then
        context:Destroy()
        self:_destroyPreviewWindow()
        self:_appendOutput("Runtime error: " .. tostring(returned), "error")
        return false, returned
    end

    if type(returned) == "function" then
        local okStart, result = pcall(returned, context)
        if not okStart then
            context:Destroy()
            self:_destroyPreviewWindow()
            self:_appendOutput("Module start failed: " .. tostring(result), "error")
            return false, result
        end
        returned = result
    elseif type(returned) == "table" then
        local startMethod = returned.Start or returned.Load or returned.Init
        if type(startMethod) == "function" then
            local okStart, startError = pcall(startMethod, returned, context)
            if not okStart then
                devCleanupResource(returned)
                context:Destroy()
                self:_destroyPreviewWindow()
                self:_appendOutput("Module start failed: " .. tostring(startError), "error")
                return false, startError
            end
        end
    end

    self.Runtime = {
        Context = context,
        Returned = returned,
        SourceName = sourceName,
        LoadedAt = os.clock(),
        PreviewWindow = previewWindow,
    }

    self:_appendOutput("Loaded isolated preview: " .. tostring(context.ModuleName), "success")
    return true
end

function DevWorkspace:LoadModule(window, reload)
    self.Window = window or self.Window or VitalityLive.Window
    if not self.Window then return false, "Vitality window is not ready." end

    self:_loadWorkspace()
    self:_syncEditorToWorkspace()
    self:_saveWorkspace(true)

    if self.Runtime and not reload then
        self:_notify({
            Title = "Development preview",
            Content = "A development preview is already running. Use /reloadmodule to rebuild the isolated preview.",
            Type = "Info",
            Duration = 5,
        })
        return false, "Development preview already running."
    end

    local main
    for _, item in ipairs(self.Workspace.Tabs) do
        if item.Name:lower() == "main.lua" then main = item break end
    end
    main = main or self.Workspace.Tabs[1]
    if not main then return false, "No development source exists." end

    if tostring(main.Code or ""):match("^%s*$") then
        main.Code = devDefaultSource()
        if self.Workspace.Active == main.Name and self.Editor and self.Editor.Parent then
            self.Editor.Text = main.Code
            self.Editor.CursorPosition = #self.Editor.Text + 1
            self:_refreshEditorCanvas()
        end
        self:_saveWorkspace(true)
        self:_appendOutput("main.lua was blank, so the Vitality preview base was restored.", "info")
    end

    -- Compile inside _executeModuleSource before replacing the current preview.
    -- On a valid reload, tear the old runtime down immediately before building
    -- the fresh isolated copy.
    if reload and self.Runtime then
        local testChunk, testError = devCompileSource(main.Code, "@VitalityDev/" .. tostring(main.Name))
        if not testChunk then
            self:_appendOutput("Compile error: " .. tostring(testError), "error")
            self:_notify({Title = "Development preview failed", Content = tostring(testError), Type = "Error", Duration = 8})
            return false, testError
        end
        self:_destroyRuntime("reload")
    elseif reload then
        self:_destroyPreviewWindow()
    end

    local ok, err = self:_executeModuleSource(self.Window, main.Code, main.Name)
    self:_notify({
        Title = ok and (reload and "Preview reloaded" or "Preview loaded") or "Development preview failed",
        Content = ok
            and ("Running " .. tostring(main.Name) .. " in a separate Vitality preview window for GameId " .. tostring(game.GameId) .. ".")
            or tostring(err),
        Type = ok and "Success" or "Error",
        Duration = ok and 5 or 8,
    })
    return ok, err
end

function DevWorkspace:RunActive(window)
    self.Window = window or self.Window or VitalityLive.Window
    self:_loadWorkspace()
    self:_syncEditorToWorkspace()

    local item = self:_activeTab()
    if not item then
        self:_appendOutput("No active editor tab exists.", "warn")
        return false
    end

    -- main.lua is reserved: Run Tab always means build/rebuild the isolated
    -- DevelopmentPreview module from main.lua.
    if item.Name:lower() == "main.lua" then
        return self:LoadModule(self.Window, self.Runtime ~= nil)
    end

    -- Every other editor tab is a pure scratch/execution tab. It never creates
    -- a preview window and never mutates main.lua or the module lifecycle.
    if tostring(item.Code or ""):match("^%s*$") then
        self:_appendOutput("Nothing to run in " .. tostring(item.Name) .. ".", "warn")
        return false
    end

    local chunk, compileError = devCompileSource(item.Code, "@VitalityScratch/" .. item.Name)
    if not chunk then
        self:_appendOutput("Compile error in " .. item.Name .. ": " .. tostring(compileError), "error")
        return false
    end

    -- Re-running the same scratch tab first cleans resources that were
    -- explicitly registered through Context, preventing easy duplicate loops.
    self:_destroyScratchRuntime(item.Name, "scratch rerun")

    local context = devCreateScratchContext()
    local ok, result = pcall(chunk, context)
    if not ok then
        context:Destroy()
        self:_appendOutput("Runtime error in " .. item.Name .. ": " .. tostring(result), "error")
        return false
    end

    self.ScratchRuntimes[item.Name] = {
        Context = context,
        Returned = result,
        SourceName = item.Name,
        LoadedAt = os.clock(),
    }

    if result ~= nil then
        self:_appendOutput("Result: " .. tostring(result), "info")
    end

    self:_appendOutput("Executed scratch tab " .. item.Name .. " (no preview base).", "success")
    return true
end

function DevWorkspace:_setActiveTab(name)
    local workspace = self:_loadWorkspace()
    self:_syncEditorToWorkspace()
    for _, item in ipairs(workspace.Tabs) do
        if item.Name == name then
            workspace.Active = item.Name
            self.PageIndex = 1
            self:_renderTabs()
            self:_loadEditorPage(1)
            self:_saveWorkspace(true)
            return true
        end
    end
    return false
end

function DevWorkspace:_addTab()
    local workspace = self:_loadWorkspace()
    self:_syncEditorToWorkspace()
    local index = 1
    local existing = {}
    for _, item in ipairs(workspace.Tabs) do existing[item.Name:lower()] = true end
    local name
    repeat
        index = index + 1
        name = "script" .. tostring(index) .. ".lua"
    until not existing[name:lower()]

    table.insert(workspace.Tabs, {Name = name, Code = "-- " .. name .. "\n"})
    workspace.Active = name
    self.PageIndex = 1
    self:_renderTabs()
    self:_loadEditorPage(1)
    self:_saveWorkspace(true)
end

function DevWorkspace:_deleteActiveTab()
    local workspace = self:_loadWorkspace()
    self:_syncEditorToWorkspace()
    local active = tostring(workspace.Active or "main.lua")

    if active:lower() == "main.lua" then
        self:_appendOutput("main.lua is reserved for the Development Preview and cannot be deleted.", "warn")
        return
    end

    self:_destroyScratchRuntime(active, "tab deleted")

    for index = #workspace.Tabs, 1, -1 do
        if workspace.Tabs[index].Name == active then
            table.remove(workspace.Tabs, index)
            break
        end
    end

    workspace.Active = "main.lua"
    self.PageIndex = 1
    self:_renderTabs()
    self:_loadEditorPage(1)
    self:_saveWorkspace(true)
end

local function devResolveGuiParent()
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and parent then return parent end
    end
    return game:GetService("CoreGui")
end

local function devMake(className, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    return object
end

function DevWorkspace:_renderTabs()
    if not self.TabStrip or not self.TabStrip.Parent then return end
    local workspace = self:_loadWorkspace()

    for _, child in ipairs(self.TabStrip:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for _, item in ipairs(workspace.Tabs) do
        local button = devMake("TextButton", {
            Parent = self.TabStrip,
            Size = UDim2.fromOffset(math.max(92, math.min(180, #item.Name * 8 + 28)), 28),
            BackgroundColor3 = item.Name == workspace.Active and Color3.fromRGB(73, 20, 122) or Color3.fromRGB(29, 29, 36),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = item.Name:lower() == "main.lua" and "main.lua  •  PREVIEW" or item.Name,
            TextColor3 = item.Name == workspace.Active and Color3.fromRGB(238, 220, 255) or Color3.fromRGB(186, 186, 198),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
        })
        devMake("UICorner", {Parent = button, CornerRadius = UDim.new(0, 7)})
        button.MouseButton1Click:Connect(function()
            self:_setActiveTab(item.Name)
        end)
    end

    local addButton = devMake("TextButton", {
        Parent = self.TabStrip,
        Size = UDim2.fromOffset(34, 28),
        BackgroundColor3 = Color3.fromRGB(31, 31, 39),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "+",
        TextColor3 = Color3.fromRGB(196, 78, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
    })
    devMake("UICorner", {Parent = addButton, CornerRadius = UDim.new(0, 7)})
    addButton.MouseButton1Click:Connect(function() self:_addTab() end)

    task.defer(function()
        if self.TabLayout and self.TabStrip and self.TabStrip.Parent then
            self.TabStrip.CanvasSize = UDim2.fromOffset(self.TabLayout.AbsoluteContentSize.X + 8, 0)
        end
    end)
end

local function devMeasureEditorText(text)
    text = tostring(text or "")
    local lines = 1
    local longest = 0
    local current = 0

    for index = 1, #text do
        local byte = string.byte(text, index)
        if byte == 10 then
            if current > longest then longest = current end
            current = 0
            lines = lines + 1
        elseif byte == 9 then
            current = current + 4
        else
            current = current + 1
        end
    end

    if current > longest then longest = current end
    return lines, longest
end

function DevWorkspace:_refreshEditorCanvas()
    if not self.Editor or not self.Editor.Parent or not self.EditorScroll or not self.EditorScroll.Parent then
        return
    end

    self._editorLayoutToken = (self._editorLayoutToken or 0) + 1
    local token = self._editorLayoutToken

    task.defer(function()
        if token ~= self._editorLayoutToken then return end
        if not self.Editor or not self.Editor.Parent or not self.EditorScroll or not self.EditorScroll.Parent then return end

        local lineCount, longestLine = devMeasureEditorText(self.Editor.Text or "")
        local viewportWidth = math.max(300, self.EditorScroll.AbsoluteSize.X - 24)
        local viewportHeight = math.max(180, self.EditorScroll.AbsoluteSize.Y - 24)
        local measuredWidth = math.max(
            viewportWidth,
            math.min(DEV_EDITOR_MAX_CANVAS_WIDTH, math.ceil(longestLine * DEV_EDITOR_CHAR_WIDTH + 44))
        )
        local measuredHeight = math.max(viewportHeight, math.ceil(lineCount * DEV_EDITOR_LINE_HEIGHT + 32))

        self.Editor.Size = UDim2.fromOffset(measuredWidth, measuredHeight)
        self.EditorScroll.CanvasSize = UDim2.fromOffset(measuredWidth + 24, measuredHeight + 24)
    end)
end

function DevWorkspace:_buildGui(window)
    if self.Gui and self.Gui.Parent then return self.Gui end
    self.Window = window or self.Window

    local env = type(getgenv) == "function" and getgenv() or _G
    local old = rawget(env, "__VITALITY_DEVELOPER_GUI")
    if typeof(old) == "Instance" then pcall(function() old:Destroy() end) end

    local gui = devMake("ScreenGui", {
        Name = "VitalityDeveloperWorkspace",
        Parent = devResolveGuiParent(),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    if syn and type(syn.protect_gui) == "function" then pcall(syn.protect_gui, gui) end
    rawset(env, "__VITALITY_DEVELOPER_GUI", gui)

    local root = devMake("Frame", {
        Parent = gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(860, 660),
        BackgroundColor3 = Color3.fromRGB(16, 16, 21),
        BorderSizePixel = 0,
    })
    devMake("UICorner", {Parent = root, CornerRadius = UDim.new(0, 13)})
    devMake("UIStroke", {Parent = root, Color = Color3.fromRGB(88, 46, 118), Transparency = 0.25, Thickness = 1})

    local top = devMake("Frame", {
        Parent = root,
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Color3.fromRGB(20, 20, 27),
        BorderSizePixel = 0,
        Active = true,
    })
    devMake("UICorner", {Parent = top, CornerRadius = UDim.new(0, 13)})
    devMake("Frame", {
        Parent = top,
        Position = UDim2.new(0, 0, 1, -13),
        Size = UDim2.new(1, 0, 0, 13),
        BackgroundColor3 = top.BackgroundColor3,
        BorderSizePixel = 0,
    })

    devMake("TextLabel", {
        Parent = top,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -120, 1, 0),
        BackgroundTransparency = 1,
        Text = "Vitality Developer",
        TextColor3 = Color3.fromRGB(240, 240, 246),
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local close = devMake("TextButton", {
        Parent = top,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = Color3.fromRGB(31, 31, 39),
        BorderSizePixel = 0,
        Text = "X",
        TextColor3 = Color3.fromRGB(210, 210, 220),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    })
    devMake("UICorner", {Parent = close, CornerRadius = UDim.new(0, 7)})
    close.MouseButton1Click:Connect(function() root.Visible = false end)

    local dragging, dragStart, startPosition
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
        end
    end)
    top.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end)

    local moduleBar = devMake("Frame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 54),
        Size = UDim2.new(1, -24, 0, 38),
        BackgroundColor3 = Color3.fromRGB(13, 13, 18),
        BorderSizePixel = 0,
    })
    devMake("UICorner", {Parent = moduleBar, CornerRadius = UDim.new(0, 8)})
    devMake("UIStroke", {Parent = moduleBar, Color = Color3.fromRGB(54, 54, 66), Transparency = 0.45, Thickness = 1})

    local moduleIdInput = devMake("TextBox", {
        Parent = moduleBar,
        Position = UDim2.fromOffset(8, 5),
        Size = UDim2.fromOffset(146, 28),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = devSuggestedModuleId(),
        PlaceholderText = "module-id",
        TextColor3 = Color3.fromRGB(226, 226, 234),
        PlaceholderColor3 = Color3.fromRGB(106, 106, 120),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    devMake("UICorner", {Parent = moduleIdInput, CornerRadius = UDim.new(0, 6)})
    devMake("UIPadding", {Parent = moduleIdInput, PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)})

    local moduleNameInput = devMake("TextBox", {
        Parent = moduleBar,
        Position = UDim2.fromOffset(161, 5),
        Size = UDim2.fromOffset(236, 28),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = tostring(game.Name or "Development Module"),
        PlaceholderText = "Module Name",
        TextColor3 = Color3.fromRGB(226, 226, 234),
        PlaceholderColor3 = Color3.fromRGB(106, 106, 120),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    devMake("UICorner", {Parent = moduleNameInput, CornerRadius = UDim.new(0, 6)})
    devMake("UIPadding", {Parent = moduleNameInput, PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)})

    local registerButton = devMake("TextButton", {
        Parent = moduleBar,
        Position = UDim2.fromOffset(404, 5),
        Size = UDim2.fromOffset(105, 28),
        BackgroundColor3 = Color3.fromRGB(66, 15, 111),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "Register Draft",
        TextColor3 = Color3.fromRGB(238, 226, 250),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = registerButton, CornerRadius = UDim.new(0, 6)})
    registerButton.MouseButton1Click:Connect(function() self:RegisterCurrentGameDraft() end)

    local removeButton = devMake("TextButton", {
        Parent = moduleBar,
        Position = UDim2.fromOffset(516, 5),
        Size = UDim2.fromOffset(92, 28),
        BackgroundColor3 = Color3.fromRGB(43, 31, 42),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "Remove Module",
        TextColor3 = Color3.fromRGB(225, 201, 213),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = removeButton, CornerRadius = UDim.new(0, 6)})
    removeButton.MouseButton1Click:Connect(function() self:RemoveCurrentGameModule() end)

    local resetBaseButton = devMake("TextButton", {
        Parent = moduleBar,
        Position = UDim2.fromOffset(615, 5),
        Size = UDim2.fromOffset(86, 28),
        BackgroundColor3 = Color3.fromRGB(31, 31, 40),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "Reset Base",
        TextColor3 = Color3.fromRGB(224, 224, 232),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = resetBaseButton, CornerRadius = UDim.new(0, 6)})
    resetBaseButton.MouseButton1Click:Connect(function()
        local workspace = self:_loadWorkspace()
        self:_syncEditorToWorkspace()
        local main
        for _, item in ipairs(workspace.Tabs) do
            if item.Name:lower() == "main.lua" then main = item break end
        end
        if not main then
            main = {Name = "main.lua", Code = devDefaultSource()}
            table.insert(workspace.Tabs, 1, main)
        else
            main.Code = devDefaultSource()
        end
        workspace.Active = "main.lua"
        self.PageIndex = 1
        self:_renderTabs()
        self:_loadEditorPage(1)
        self:_saveWorkspace(true)
        self:_appendOutput("Restored the Vitality Development Module Base in main.lua.", "success")
    end)

    local moduleStateLabel = devMake("TextLabel", {
        Parent = moduleBar,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(135, 28),
        BackgroundTransparency = 1,
        Text = "NOT REGISTERED",
        TextColor3 = Color3.fromRGB(214, 174, 87),
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local tabStrip = devMake("ScrollingFrame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 100),
        Size = UDim2.new(1, -24, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.fromOffset(0, 0),
    })
    local tabLayout = devMake("UIListLayout", {
        Parent = tabStrip,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })

    local editorScroll = devMake("ScrollingFrame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 140),
        Size = UDim2.new(1, -24, 0, 256),
        BackgroundColor3 = Color3.fromRGB(11, 11, 15),
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(94, 49, 130),
    })
    devMake("UICorner", {Parent = editorScroll, CornerRadius = UDim.new(0, 9)})
    devMake("UIStroke", {Parent = editorScroll, Color = Color3.fromRGB(54, 54, 66), Transparency = 0.35, Thickness = 1})

    local editor = devMake("TextBox", {
        Parent = editorScroll,
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 1, -24),
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.None,
        RichText = false,
        Text = "",
        PlaceholderText = "-- paged editor: full source is stored outside this TextBox",
        TextColor3 = Color3.fromRGB(224, 224, 234),
        PlaceholderColor3 = Color3.fromRGB(102, 102, 116),
        CursorPosition = -1,
        Font = Enum.Font.Code,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    local pageBar = devMake("Frame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 404),
        Size = UDim2.new(1, -24, 0, 32),
        BackgroundTransparency = 1,
    })

    local prevPage = devMake("TextButton", {
        Parent = pageBar,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(78, 30),
        BackgroundColor3 = Color3.fromRGB(31, 31, 40),
        BorderSizePixel = 0,
        Text = "< Previous",
        TextColor3 = Color3.fromRGB(220, 220, 230),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = prevPage, CornerRadius = UDim.new(0, 6)})
    prevPage.MouseButton1Click:Connect(function() self:_changeEditorPage(-1) end)

    local pageLabel = devMake("TextLabel", {
        Parent = pageBar,
        Position = UDim2.fromOffset(86, 0),
        Size = UDim2.fromOffset(300, 30),
        BackgroundTransparency = 1,
        Text = "Page 1 / 1",
        TextColor3 = Color3.fromRGB(165, 145, 181),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local nextPage = devMake("TextButton", {
        Parent = pageBar,
        Position = UDim2.fromOffset(394, 0),
        Size = UDim2.fromOffset(70, 30),
        BackgroundColor3 = Color3.fromRGB(31, 31, 40),
        BorderSizePixel = 0,
        Text = "Next >",
        TextColor3 = Color3.fromRGB(220, 220, 230),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = nextPage, CornerRadius = UDim.new(0, 6)})
    nextPage.MouseButton1Click:Connect(function() self:_changeEditorPage(1) end)

    local jumpInput = devMake("TextBox", {
        Parent = pageBar,
        Position = UDim2.fromOffset(475, 0),
        Size = UDim2.fromOffset(110, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = "Jump line...",
        TextColor3 = Color3.fromRGB(224, 224, 232),
        PlaceholderColor3 = Color3.fromRGB(105, 105, 119),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = jumpInput, CornerRadius = UDim.new(0, 6)})

    local jumpButton = devMake("TextButton", {
        Parent = pageBar,
        Position = UDim2.fromOffset(592, 0),
        Size = UDim2.fromOffset(68, 30),
        BackgroundColor3 = Color3.fromRGB(48, 24, 66),
        BorderSizePixel = 0,
        Text = "Jump",
        TextColor3 = Color3.fromRGB(229, 212, 240),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = jumpButton, CornerRadius = UDim.new(0, 6)})
    jumpButton.MouseButton1Click:Connect(function() self:_jumpToLine(jumpInput.Text) end)

    local importBar = devMake("Frame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 442),
        Size = UDim2.new(1, -24, 0, 34),
        BackgroundTransparency = 1,
    })

    local importPath = devMake("TextBox", {
        Parent = importBar,
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.new(1, -250, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = DEV_IMPORT_FOLDER .. "/script.lua",
        PlaceholderText = "Local .lua file path",
        TextColor3 = Color3.fromRGB(205, 205, 217),
        PlaceholderColor3 = Color3.fromRGB(105, 105, 119),
        Font = Enum.Font.Code,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    devMake("UICorner", {Parent = importPath, CornerRadius = UDim.new(0, 6)})
    devMake("UIPadding", {Parent = importPath, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})

    local pasteFull = devMake("TextButton", {
        Parent = importBar,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -112, 0, 1),
        Size = UDim2.fromOffset(126, 30),
        BackgroundColor3 = Color3.fromRGB(61, 19, 98),
        BorderSizePixel = 0,
        Text = "Paste Full Script",
        TextColor3 = Color3.fromRGB(235, 218, 247),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = pasteFull, CornerRadius = UDim.new(0, 6)})
    pasteFull.MouseButton1Click:Connect(function() self:PasteFullScript() end)

    local importButton = devMake("TextButton", {
        Parent = importBar,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 1),
        Size = UDim2.fromOffset(104, 30),
        BackgroundColor3 = Color3.fromRGB(31, 31, 40),
        BorderSizePixel = 0,
        Text = "Import File",
        TextColor3 = Color3.fromRGB(224, 224, 232),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = importButton, CornerRadius = UDim.new(0, 6)})
    importButton.MouseButton1Click:Connect(function() self:ImportFile(importPath.Text) end)

    local actionBar = devMake("Frame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 482),
        Size = UDim2.new(1, -24, 0, 38),
        BackgroundTransparency = 1,
    })
    local actionLayout = devMake("UIListLayout", {
        Parent = actionBar,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })

    local function actionButton(label, callback, width)
        local button = devMake("TextButton", {
            Parent = actionBar,
            Size = UDim2.fromOffset(width or 104, 32),
            BackgroundColor3 = Color3.fromRGB(31, 31, 40),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = label,
            TextColor3 = Color3.fromRGB(224, 224, 232),
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
        })
        devMake("UICorner", {Parent = button, CornerRadius = UDim.new(0, 7)})
        button.MouseButton1Click:Connect(callback)
        return button
    end

    actionButton("Run Tab", function() self:RunActive(self.Window) end, 80)
    actionButton("Load Module", function() self:LoadModule(self.Window, false) end, 96)
    actionButton("Reload Module", function() self:LoadModule(self.Window, true) end, 104)
    actionButton("Save", function() self:_saveWorkspace(false) end, 62)
    actionButton("Delete Tab", function() self:_deleteActiveTab() end, 86)
    actionButton("Close Preview", function()
        if not self:_destroyRuntime("manual close") then
            self:_appendOutput("No Development Preview is currently loaded.", "warn")
        else
            self:_appendOutput("Development Preview closed. Your local workspace/source was kept.", "success")
        end
    end, 100)

    local output = devMake("TextLabel", {
        Parent = root,
        Position = UDim2.fromOffset(12, 528),
        Size = UDim2.new(1, -24, 0, 76),
        BackgroundColor3 = Color3.fromRGB(11, 11, 15),
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = Color3.fromRGB(170, 170, 185),
        Font = Enum.Font.Code,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    devMake("UICorner", {Parent = output, CornerRadius = UDim.new(0, 8)})
    devMake("UIPadding", {
        Parent = output,
        PaddingLeft = UDim.new(0, 9),
        PaddingRight = UDim.new(0, 9),
        PaddingTop = UDim.new(0, 7),
        PaddingBottom = UDim.new(0, 7),
    })

    local logBar = devMake("Frame", {
        Parent = root,
        Position = UDim2.fromOffset(12, 610),
        Size = UDim2.new(1, -24, 0, 34),
        BackgroundTransparency = 1,
    })

    local copyLogs = devMake("TextButton", {
        Parent = logBar,
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.fromOffset(90, 30),
        BackgroundColor3 = Color3.fromRGB(31, 31, 40),
        BorderSizePixel = 0,
        Text = "Copy Logs",
        TextColor3 = Color3.fromRGB(224, 224, 232),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = copyLogs, CornerRadius = UDim.new(0, 6)})
    copyLogs.MouseButton1Click:Connect(function() self:CopyLogs() end)

    local copyError = devMake("TextButton", {
        Parent = logBar,
        Position = UDim2.fromOffset(98, 1),
        Size = UDim2.fromOffset(108, 30),
        BackgroundColor3 = Color3.fromRGB(31, 31, 40),
        BorderSizePixel = 0,
        Text = "Copy Last Error",
        TextColor3 = Color3.fromRGB(224, 224, 232),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = copyError, CornerRadius = UDim.new(0, 6)})
    copyError.MouseButton1Click:Connect(function() self:CopyLastError() end)

    local clearLogs = devMake("TextButton", {
        Parent = logBar,
        Position = UDim2.fromOffset(214, 1),
        Size = UDim2.fromOffset(82, 30),
        BackgroundColor3 = Color3.fromRGB(43, 31, 42),
        BorderSizePixel = 0,
        Text = "Clear Logs",
        TextColor3 = Color3.fromRGB(225, 201, 213),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
    })
    devMake("UICorner", {Parent = clearLogs, CornerRadius = UDim.new(0, 6)})
    clearLogs.MouseButton1Click:Connect(function() self:ClearLogs() end)

    local statusLabel = devMake("TextLabel", {
        Parent = top,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -52, 0.5, 0),
        Size = UDim2.fromOffset(300, 22),
        BackgroundTransparency = 1,
        Text = "GameId " .. tostring(game.GameId) .. "  •  paged editor",
        TextColor3 = Color3.fromRGB(137, 92, 168),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    self.Gui = gui
    self.Root = root
    self.Editor = editor
    self.EditorScroll = editorScroll
    self.TabStrip = tabStrip
    self.TabLayout = tabLayout
    self.StatusLabel = statusLabel
    self.OutputLabel = output
    self.ModuleIdInput = moduleIdInput
    self.ModuleNameInput = moduleNameInput
    self.ModuleStateLabel = moduleStateLabel
    self.PageLabel = pageLabel
    self.JumpLineInput = jumpInput
    self.ImportPathInput = importPath

    self:_loadWorkspace()
    self:_renderTabs()
    self:_loadEditorPage(1)

    editor:GetPropertyChangedSignal("Text"):Connect(function()
        if self._suppressEditorChange then return end
        self._pageDirty = true
        self:_refreshEditorCanvas()
        self:_scheduleSave()
    end)
    editor.FocusLost:Connect(function() self:_saveWorkspace(true) end)
    editorScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_refreshEditorCanvas() end)

    local moduleId, moduleState = devCurrentModule()
    self:_refreshModuleControls()
    self:_appendOutput("Workspace: GameId " .. tostring(game.GameId) .. " / " .. tostring(moduleId), "info")
    self:_appendOutput("Paged editor active: max " .. DEV_EDITOR_PAGE_MAX_LINES .. " lines / " .. DEV_EDITOR_PAGE_MAX_CHARS .. " chars per visible page.", "info")
    if type(moduleState) == "table" and tostring(moduleState.url or "") == "" then
        self:_appendOutput("Cloudflare module is registered as a local development draft.", "info")
    elseif not devPersistenceAvailable() then
        self:_appendOutput("File APIs unavailable; changes will not persist after this session.", "warn")
    end

    return gui
end

function DevWorkspace:Open(window)
    self.Window = window or self.Window or VitalityLive.Window
    if not self.Window then return false end
    self:_buildGui(self.Window)
    if self.Root then
        self.Root.Visible = true
    end
    if self.Editor then
        task.defer(function()
            if self.Editor and self.Editor.Parent then self.Editor:CaptureFocus() end
        end)
    end
    return true
end

function DevWorkspace:Destroy()
    self:_syncEditorToWorkspace()
    self:_saveWorkspace(true)
    self:_destroyRuntime("window cleanup")
    self:_destroyAllScratchRuntimes("workspace cleanup")
    if self.Gui and self.Gui.Parent then pcall(function() self.Gui:Destroy() end) end
    self.Gui, self.Root, self.Editor, self.EditorScroll, self.TabStrip, self.TabLayout = nil, nil, nil, nil, nil, nil
    self.ModuleIdInput, self.ModuleNameInput, self.ModuleStateLabel = nil, nil, nil
    self.OutputLabel, self.StatusLabel = nil, nil
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

    -- Owner-only developer utilities. The command parser accepts both `;` and
    -- `/` prefixes, so `/gameid` and `;gameid` resolve to the same command.
    window:RegisterCommand({
        Name = "gameid",
        Aliases = {"universeid", "gid"},
        Description = "Copy the current Roblox universe GameId.",
        Usage = "gameid",
        Category = "Developer",
        Callback = function()
            notifyCopiedDeveloperValue(window, "GameId", "GameId", game.GameId)
        end,
    })

    window:RegisterCommand({
        Name = "placeid",
        Aliases = {"pid"},
        Description = "Copy the current Roblox PlaceId.",
        Usage = "placeid",
        Category = "Developer",
        Callback = function()
            notifyCopiedDeveloperValue(window, "PlaceId", "PlaceId", game.PlaceId)
        end,
    })

    window:RegisterCommand({
        Name = "jobid",
        Aliases = {"serverid", "copyserver"},
        Description = "Copy the current Roblox server JobId.",
        Usage = "jobid",
        Category = "Developer",
        Callback = function()
            notifyCopiedDeveloperValue(window, "JobId", "JobId", game.JobId ~= "" and game.JobId or "studio/local")
        end,
    })

    window:RegisterCommand({
        Name = "gameinfo",
        Aliases = {"devinfo"},
        Description = "Show useful identifiers and the current Vitality module for this game.",
        Usage = "gameinfo",
        Category = "Developer",
        Callback = function()
            local moduleId, moduleState = currentLiveModuleForDeveloper()
            local registered = type(moduleState) == "table"
            local content = table.concat({
                "Game: " .. tostring(game.Name),
                "GameId: " .. tostring(game.GameId),
                "PlaceId: " .. tostring(game.PlaceId),
                "JobId: " .. tostring(game.JobId ~= "" and game.JobId or "studio/local"),
                "Module: " .. tostring(moduleId),
                "Registered: " .. (registered and "Yes" or "No"),
            }, "\n")
            window:Notify({Title = "Game information", Content = content, Type = "Info", Duration = 8})
        end,
    })

    window:RegisterCommand({
        Name = "moduleinfo",
        Aliases = {"currentmodule"},
        Description = "Show Cloudflare metadata for the module registered to the current game.",
        Usage = "moduleinfo",
        Category = "Developer",
        Callback = function()
            local moduleId, moduleState = currentLiveModuleForDeveloper()
            if type(moduleState) ~= "table" then
                return window:Notify({
                    Title = "Module information",
                    Content = "No live module is registered for GameId " .. tostring(game.GameId) .. ".",
                    Type = "Info",
                    Duration = 6,
                })
            end

            local content = table.concat({
                tostring(moduleState.name or moduleId) .. " (" .. tostring(moduleId) .. ")",
                "GameId: " .. tostring(moduleState.gameId or game.GameId),
                "Status: " .. liveStatusLabel(moduleState.status),
                "Version: " .. tostring(moduleState.version or "unknown"),
                "Enabled: " .. tostring(moduleState.enabled ~= false),
                "URL: " .. (tostring(moduleState.url or "") ~= "" and tostring(moduleState.url) or "Not published"),
            }, "\n")
            window:Notify({Title = "Module information", Content = content, Type = "Info", Duration = 9})
        end,
    })

    window:RegisterCommand({
        Name = "modules",
        Aliases = {"listmodules"},
        Description = "List modules currently present in the live Cloudflare registry.",
        Usage = "modules",
        Category = "Developer",
        Callback = function()
            local modules = VitalityLive.State and VitalityLive.State.modules
            if type(modules) ~= "table" then
                return window:Notify({Title = "Live modules", Content = "Live module state has not loaded yet.", Type = "Warning", Duration = 5})
            end

            local rows = {}
            for moduleId, moduleState in pairs(modules) do
                if type(moduleState) == "table" then
                    table.insert(rows, tostring(moduleId) .. " - " .. tostring(moduleState.name or moduleId) .. " [" .. liveStatusLabel(moduleState.status) .. "]")
                end
            end
            table.sort(rows, function(a, b) return a:lower() < b:lower() end)
            local content = #rows > 0 and table.concat(rows, "\n") or "No modules are currently registered."
            if #content > 1400 then content = content:sub(1, 1390) .. "\n..." end
            window:Notify({Title = "Live modules (" .. tostring(#rows) .. ")", Content = content, Type = "Info", Duration = 10})
        end,
    })

    window:RegisterCommand({
        Name = "clients",
        Aliases = {"liveclients"},
        Description = "Show the most recent connected-client count reported by Vitality Live.",
        Usage = "clients",
        Category = "Developer",
        Callback = function()
            window:Notify({
                Title = "Vitality Live clients",
                Content = "Connected clients: " .. tostring(VitalityLive.ConnectedClients or "unknown"),
                Type = "Info",
                Duration = 5,
            })
        end,
    })

    window:RegisterCommand({
        Name = "refreshlive",
        Aliases = {"refreshstate", "synclive"},
        Description = "Immediately refresh module metadata from Cloudflare.",
        Usage = "refreshlive",
        Category = "Developer",
        Callback = function()
            local ok, response, err = liveRequest("GET", "/state")
            if not ok or type(response) ~= "table" or type(response.state) ~= "table" then
                return window:Notify({
                    Title = "Live refresh failed",
                    Content = commandFailureText(response, err),
                    Type = "Error",
                    Duration = 5,
                })
            end

            VitalityLive.ConnectedClients = tonumber(response.connectedClients) or VitalityLive.ConnectedClients
            applyLiveState(response.state, VitalityLive.Transport)
            window:Notify({Title = "Vitality Live", Content = "Live module state refreshed.", Type = "Success", Duration = 4})
        end,
    })

    window:RegisterCommand({
        Name = "executor",
        Aliases = {"devexecutor", "workspace"},
        Description = "Open the per-game editor used to build isolated Vitality preview modules.",
        Usage = "executor",
        Category = "Developer",
        Callback = function()
            if not DevWorkspace:Open(window) then
                window:Notify({Title = "Developer workspace", Content = "The Vitality window is not ready.", Type = "Error", Duration = 4})
            end
        end,
    })

    window:RegisterCommand({
        Name = "loadmodule",
        Aliases = {"devload"},
        Description = "Load main.lua into a separate Vitality development preview window.",
        Usage = "loadmodule",
        Category = "Developer",
        Callback = function()
            DevWorkspace:LoadModule(window, false)
        end,
    })

    window:RegisterCommand({
        Name = "reloadmodule",
        Aliases = {"devreload"},
        Description = "Destroy the isolated preview and rebuild it from the latest main.lua.",
        Usage = "reloadmodule",
        Category = "Developer",
        Callback = function()
            DevWorkspace:LoadModule(window, true)
        end,
    })

    window:RegisterCommand({
        Name = "unloadmodule",
        Aliases = {"devunload"},
        Description = "Close only the isolated Development Preview. Local editor files stay saved.",
        Usage = "unloadmodule",
        Category = "Developer",
        Callback = function()
            if DevWorkspace:_destroyRuntime("manual unload") then
                window:Notify({Title = "Development preview", Content = "Isolated development preview unloaded.", Type = "Success", Duration = 4})
            else
                window:Notify({Title = "Development preview", Content = "No isolated development preview is running.", Type = "Info", Duration = 4})
            end
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
                title = "Vitality Broadcast", duration = 10, priority = "normal",
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
        Autocomplete = moduleArgumentAutocomplete,
        Callback = function(args)
            if #args < 2 then return window:Notify({Title = "Message game", Content = "Usage: messagegame <module> <message>", Type = "Warning", Duration = 4}) end
            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            if not liveModuleExists(moduleId) then return window:Notify({Title = "Message game", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
            local ok, result, err = liveOwnerRequest("POST", "/owner/broadcast", {
                message = table.concat(args, " "), audience = "game:" .. moduleId, style = "owner",
                title = liveModuleDisplayName(moduleId) .. " Broadcast", duration = 10, priority = "normal",
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
                title = "Owner Broadcast", duration = 10, priority = "normal",
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
                title = "Vitality Message", duration = 10, priority = "normal",
            })
            window:Notify({Title = ok and "User message sent" or "Message failed", Content = ok and ("Delivered to " .. tostring(result and result.delivered or 0) .. " client(s).") or commandFailureText(result, err), Type = ok and "Success" or "Error", Duration = 5})
        end,
    })

    -- Owners receive an extended status command. Calling it without arguments
    -- preserves the library's original read-only status behavior.
    window:RegisterCommand({
        Name = "status",
        Aliases = {"setstatus"},
        Description = "Show the current status, or update a module with a required status reason.",
        Usage = "status <module> <functional/testing/limited/broken/maintenance/updating> <reason>",
        Category = "Owner",
        Autocomplete = statusArgumentAutocomplete,
        Callback = function(args)
            if #args == 0 then
                local status = window.ScriptStatus or {}
                local label = status.Label or status.State or "Unknown"
                return window:Notify({Title = "Module status", Content = tostring(label), Type = "Info", Duration = 4})
            end
            if #args < 3 then
                return window:Notify({
                    Title = "Status",
                    Content = "Usage: status <module> <state> <reason>",
                    Type = "Warning",
                    Duration = 5,
                })
            end

            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            local state = tostring(table.remove(args, 1)):lower()
            local reason = table.concat(args, " "):gsub("^%s+", ""):gsub("%s+$", "")
            if not liveModuleExists(moduleId) then return window:Notify({Title = "Status", Content = "Unknown module: " .. moduleId, Type = "Error", Duration = 4}) end
            if not VALID_LIVE_STATUSES[state] then return window:Notify({Title = "Status", Content = "Unknown state: " .. state, Type = "Error", Duration = 4}) end
            if reason == "" then return window:Notify({Title = "Status", Content = "A reason is required for status changes.", Type = "Warning", Duration = 5}) end

            local payload = {status = state, reason = reason}
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
        Autocomplete = moduleArgumentAutocomplete,
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

    window:RegisterCommand({Name = "enable", Description = "Enable a live module.", Usage = "enable <module>", Category = "Owner", Autocomplete = moduleArgumentAutocomplete, Callback = function(args) setEnabled(args, true) end})
    window:RegisterCommand({Name = "disable", Description = "Disable a live module.", Usage = "disable <module>", Category = "Owner", Autocomplete = moduleArgumentAutocomplete, Callback = function(args) setEnabled(args, false) end})

    window:RegisterCommand({
        Name = "moduleversion",
        Aliases = {"setversion"},
        Description = "Update a module's live version metadata.",
        Usage = "moduleversion <module> <version>",
        Category = "Owner",
        Autocomplete = moduleArgumentAutocomplete,
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
        Usage = 'addmodule <id> <gameId> "<name>" [url|local] [status] [version]',
        Category = "Owner",
        Autocomplete = addModuleAutocomplete,
        Callback = function(args)
            if #args < 3 then
                return window:Notify({
                    Title = "Add module",
                    Content = 'Usage: addmodule <id> <gameId> "<name>" [url|local] [status] [version]',
                    Type = "Warning",
                    Duration = 6,
                })
            end

            local moduleId = normalizeLiveModuleId(table.remove(args, 1))
            local gameId = tonumber(table.remove(args, 1))
            local name = tostring(table.remove(args, 1) or "")
            local urlValue = tostring(table.remove(args, 1) or "local")
            local loweredUrlValue = urlValue:lower()
            local url = (loweredUrlValue == "local"
                or loweredUrlValue == "draft"
                or loweredUrlValue == "-"
                or loweredUrlValue == "none")
                and ""
                or urlValue
            local status = tostring(table.remove(args, 1) or "testing"):lower()
            local version = tostring(table.remove(args, 1) or "0.1.0-dev")

            if moduleId == "" then
                return window:Notify({Title = "Add module", Content = "Module id is required.", Type = "Error", Duration = 4})
            end
            if liveModuleExists(moduleId) then
                return window:Notify({Title = "Add module", Content = "Module already exists: " .. moduleId, Type = "Error", Duration = 4})
            end
            if not gameId or gameId <= 0 or gameId % 1 ~= 0 then
                return window:Notify({Title = "Add module", Content = "gameId must be a valid Roblox universe ID.", Type = "Error", Duration = 5})
            end
            if url ~= "" and not url:match("^https?://") then
                return window:Notify({Title = "Add module", Content = "Module URL must begin with http:// or https://, or use 'local' for a development draft.", Type = "Error", Duration = 5})
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
                    and (url == ""
                        and (name .. " (" .. moduleId .. ") is registered as a development draft. Join that game and use /executor then /loadmodule.")
                        or (name .. " (" .. moduleId .. ") is now registered. Re-execute in that game to load it."))
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
        Autocomplete = removeModuleAutocomplete,
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

            if type(window.AddCleanup) == "function" then
                window:AddCleanup(function()
                    DevWorkspace:Destroy()
                end)
            end

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
