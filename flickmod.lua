-- vitality's hub / Flick module
-- Production module for the Vitality main loader.
-- Module version: 2.9.0
--
-- IMPORTANT:
-- This file intentionally does NOT load the library, create a Window,
-- run KeyAuth, or register games. The main loader owns all of that.

return function(context)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")

    local LocalPlayer = Players.LocalPlayer
    local Window = context and context.Window
    local NovaField = context and (context.Library or context.NovaField)

    if not Window or not NovaField then
        error("Flick module requires context.Window and context.Library/context.NovaField")
    end

    local BUILD_KEY = "__VITALITY_FLICK_MODULE_BUILD_STATE"
    local previous = rawget(_G, BUILD_KEY)

    -- Same-window duplicate guard, matching the other production modules.
    if type(previous) == "table"
        and previous.Window == Window
        and previous.Ready == true then

        return true
    end

    if type(previous) == "table" and type(previous.Cleanup) == "function" then
        pcall(previous.Cleanup)
    end

    local state = {
        Window = Window,
        Ready = false,
        Alive = true,
        Connections = {},
        Cache = {},

        Features = {
            Name = false,
            Distance = false,
            HealthBar = false,
            Chams = false,
            Skeleton = false,
            Box = false,
        },

        ESPEnabled = true,
        ESPVisibleCheck = false,

        Awareness = {
            Enabled = false,
            RequireLineOfSight = true,
            ViewConeDegrees = 120,
            MaxDistance = 1500,
            IndicatorRadius = 175,
            IndicatorColor = Color3.fromRGB(255, 20, 45),
            MaxIndicators = 6,
            ScanInterval = 0.06,
            LastScan = 0,
            Indicators = {},
        },

        TeamCheck = false,
        MaxDistance = 1500,
        NameFormat = "Username",

        ChamsColor = Color3.fromRGB(255, 70, 70),

        ESPVisibilityColors = true,
        ESPVisibleColor = Color3.fromRGB(80, 255, 120),
        ESPOccludedColor = Color3.fromRGB(255, 205, 70),

        CursorUnlock = {
            Enabled = false,
            RenderStepName = "Vitality_Flick_UnlockCursor",
            Controller = nil,
            ControllerWasEnabled = nil,
        },
        TextFont = Enum.Font.GothamBold,
        BaseTextSize = 16,
        MinTextSize = 10,
        MaxTextSize = 24,
        DistanceScaling = true,
        TextHeight = 3,
        TextOutline = true,
        HealthBarPosition = "Left of Player",

        ChamsFillTransparency = 0.50,
        ChamsOutlineTransparency = 0,

        ColorOverrides = {},
        Colors = {
            NameText = Color3.fromRGB(255,255,255),
            NameOutline = Color3.fromRGB(0,0,0),
            DistanceText = Color3.fromRGB(220,220,220),
            HealthLow = Color3.fromRGB(255,70,70),
            HealthMid = Color3.fromRGB(255,210,70),
            HealthHigh = Color3.fromRGB(80,255,120),
            HealthBackground = Color3.fromRGB(20,20,20),
            ChamsLow = Color3.fromRGB(255,70,70),
            ChamsMid = Color3.fromRGB(255,210,70),
            ChamsHigh = Color3.fromRGB(80,255,120),
            ChamsOutline = Color3.fromRGB(255,255,255),
            Skeleton = Color3.fromRGB(255,255,255),
            Box = Color3.fromRGB(255,255,255),
        },
        Defaults = {},

        Combat = {
            SilentAimEnabled = false,
            UseFOV = true,
            ShowFOVCircle = true,
            FOVRadius = 175,
            VisibleCheck = false,
            TargetPart = "Head",

            -- Triggerbot uses the same player/team/range rules as the combat system,
            -- but only fires when the crosshair (or its small radius) actually raycasts
            -- into another player's live character model.
            TriggerbotEnabled = false,
            TriggerbotRadius = 8,
            TriggerbotDelay = 0.02,
            TriggerbotCooldown = 0.10,
            TriggerbotScanInterval = 0.02,
            TriggerbotLastScan = 0,
            TriggerbotLastShot = 0,
            TriggerbotPending = false,
            TriggerbotGeneration = 0,

            -- Camera aimbot. This is intentionally separate from Silent Aim:
            -- it rotates the real client camera instead of rewriting bullet data.
            -- By default it only engages while RMB is held.
            AimbotEnabled = false,
            AimbotAlwaysActive = false,
            AimbotSmoothing = 14,
            AimbotStickyTarget = true,
            AimbotUsePrediction = false,
            AimbotTarget = nil,

            PredictionEnabled = true,
            PredictionLead = 0.03,
            VelocityCap = 110,

            FOVGui = nil,
            FOVFrame = nil,
            UpdateFOVCircle = nil,

            BulletHandler = nil,
            OriginalBulletFire = nil,
            WrappedBulletFire = nil,
            BulletPatchInstalled = false,
        },

        GunMods = {
            InstantReload = false,
            NoSpread = false,
            NoRecoil = false,
            FullAuto = false,
            RapidFire = false,
            RapidFireMultiplier = 1.05,
            RapidFireFloorRatio = 0.90,
            NoGravity = false,
            BulletForceEnabled = false,
            BulletForceMultiplier = 1.0,

            Configs = setmetatable({}, {__mode = "k"}),
            ConfigOriginals = setmetatable({}, {__mode = "k"}),
            ToolOriginals = setmetatable({}, {__mode = "k"}),
            LastConfigCount = 0,
            RefreshGeneration = 0,
        },

        MeleeMods = {
            NoSwingRecoil = false,
            FastSwing = false,
            SwingSpeed = 1.0,
            InstantEquip = false,
            SpeedBoostOverride = false,
            SpeedBoost = 4,

            Configs = setmetatable({}, {__mode = "k"}),
            ConfigOriginals = setmetatable({}, {__mode = "k"}),
            ToolOriginals = setmetatable({}, {__mode = "k"}),
            LastConfigCount = 0,
        },


        InPlay = {
            Players = {},
            Event = nil,
            Paragraph = nil,
            LastRefresh = 0,
            Dirty = true,
        },
    }

    for k, v in pairs(state.Colors) do
        state.Defaults[k] = v
    end

    _G[BUILD_KEY] = state

    local function track(connection)
        if connection then
            table.insert(state.Connections, connection)
        end
        return connection
    end

    local function selectionHas(selection, wanted)
        if type(selection) == "string" then
            return selection == wanted
        end
        if type(selection) ~= "table" then
            return false
        end
        for k, v in pairs(selection) do
            if v == wanted or (k == wanted and v == true) then
                return true
            end
        end
        return false
    end

    local function dropdownValue(value)
        if type(value) == "string" then return value end
        if type(value) == "table" then return value[1] end
        return nil
    end

    local OverrideMap = {
        ["Name Text"] = "NameText",
        ["Name Outline"] = "NameOutline",
        ["Distance Text"] = "DistanceText",
        ["Health Low"] = "HealthLow",
        ["Health Mid"] = "HealthMid",
        ["Health High"] = "HealthHigh",
        ["Health Background"] = "HealthBackground",
        ["Chams Low"] = "ChamsLow",
        ["Chams Mid"] = "ChamsMid",
        ["Chams High"] = "ChamsHigh",
        ["Chams Outline"] = "ChamsOutline",
        ["Skeleton"] = "Skeleton",
        ["Bounding Box"] = "Box",
    }

    local function activeColor(displayName)
        local key = OverrideMap[displayName] or displayName
        if selectionHas(state.ColorOverrides, displayName) then
            return state.Colors[key]
        end
        return state.Defaults[key] or state.Colors[key] or Color3.new(1,1,1)
    end

    local function getRoot(player)
        local character = player and player.Character
        return character and (
            character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
        ) or nil
    end

    local function getHumanoid(player)
        local character = player and player.Character
        return character and character:FindFirstChildOfClass("Humanoid") or nil
    end

    local function getWorkspacePlayerModel(
        player
    )
        if not player then
            return nil
        end

        local model =
            workspace:
                FindFirstChild(
                    player.Name
                )

        if model
            and model:IsA(
                "Model"
            ) then

            return model
        end

        return player.Character
    end

    local function readValueObjectNumber(
        object
    )
        if not object then
            return nil
        end

        local ok,
            value =
                pcall(function()
                    return object.Value
                end)

        if ok then
            return tonumber(
                value
            )
        end

        return nil
    end

    local function getPlayerHealthState(
        player
    )
        local model =
            getWorkspacePlayerModel(
                player
            )

        local healthObject =
            model
            and model:
                FindFirstChild(
                    "Health"
                )

        local current =
            readValueObjectNumber(
                healthObject
            )

        local humanoid =
            getHumanoid(
                player
            )

        if current == nil
            and humanoid then

            current =
                humanoid.Health
        end

        local maximum =
            nil

        if healthObject then
            local ok,
                attribute =
                    pcall(
                        healthObject.GetAttribute,
                        healthObject,
                        "MaxHealth"
                    )

            if ok then
                maximum =
                    tonumber(
                        attribute
                    )
            end
        end

        if not maximum
            and model then

            maximum =
                readValueObjectNumber(
                    model:
                        FindFirstChild(
                            "MaxHealth"
                        )
                )
        end

        if not maximum
            and humanoid then

            maximum =
                tonumber(
                    humanoid.MaxHealth
                )
        end

        maximum =
            tonumber(
                maximum
            )
            or 100

        current =
            tonumber(
                current
            )
            or maximum

        if maximum <= 0 then
            maximum =
                100
        end

        return current,
            maximum,
            healthObject,
            model
    end

    local function hasESPLineOfSight(
        player,
        targetModel
    )
        local camera =
            workspace.CurrentCamera

        if not camera
            or not targetModel then

            return false
        end

        local targetPart =
            targetModel:
                FindFirstChild(
                    "Head"
                )
            or targetModel:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or targetModel:
                FindFirstChild(
                    "UpperTorso"
                )
            or targetModel:
                FindFirstChild(
                    "Torso"
                )

        if not targetPart
            or not targetPart:IsA(
                "BasePart"
            ) then

            return false
        end

        local origin =
            camera.CFrame.Position

        local delta =
            targetPart.Position
            - origin

        if delta.Magnitude
            <= 0.01 then

            return true
        end

        local params =
            RaycastParams.new()

        params.FilterType =
            Enum.RaycastFilterType.Exclude

        params.FilterDescendantsInstances = {
            LocalPlayer.Character,
        }

        params.IgnoreWater =
            true

        local result =
            workspace:
                Raycast(
                    origin,
                    delta,
                    params
                )

        if not result then
            return true
        end

        return result.Instance
            and result.Instance:
                IsDescendantOf(
                    targetModel
                )
    end

    local function getESPStatusColor(
        player,
        character
    )
        local visible =
            hasESPLineOfSight(
                player,
                character
            )

        return visible,
            (
                visible
                and state.ESPVisibleColor
                or state.ESPOccludedColor
            )
    end

    -- ============================================================
    -- SILENT AIM / SHOT ROUTING
    -- ============================================================

    local function getCombatPart(
        player
    )
        local character =
            player
            and player.Character

        if not character then
            return nil
        end

        local preferred =
            state.Combat.TargetPart

        if preferred == "HumanoidRootPart" then
            return character:
                FindFirstChild(
                    "HumanoidRootPart"
                )
                or character:
                    FindFirstChild(
                        "UpperTorso"
                    )
                or character:
                    FindFirstChild(
                        "Torso"
                    )
                or character:
                    FindFirstChild(
                        "Head"
                    )
        end

        return character:
            FindFirstChild(
                "Head"
            )
            or character:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or character:
                FindFirstChild(
                    "UpperTorso"
                )
            or character:
                FindFirstChild(
                    "Torso"
                )
    end

    local function isCombatTarget(
        player
    )
        if not player
            or player == LocalPlayer then

            return false
        end

        if state.TeamCheck
            and LocalPlayer.Team
            and player.Team
                == LocalPlayer.Team then

            return false
        end

        local humanoid =
            getHumanoid(
                player
            )

        local part =
            getCombatPart(
                player
            )

        return humanoid ~= nil
            and humanoid.Health > 0
            and part ~= nil
    end

    local function shouldCenterFOV()
        return UserInputService.MouseBehavior
                == Enum.MouseBehavior.LockCenter
            or LocalPlayer.CameraMode
                == Enum.CameraMode.LockFirstPerson
    end

    local function getFOVPoint()
        local camera =
            workspace.CurrentCamera

        if not camera then
            return nil
        end

        if shouldCenterFOV() then
            return camera.ViewportSize
                / 2
        end

        local ok,
            mouse =
                pcall(
                    UserInputService.GetMouseLocation,
                    UserInputService
                )

        if ok and mouse then
            return Vector2.new(
                mouse.X,
                mouse.Y
            )
        end

        return camera.ViewportSize
            / 2
    end

    local function isVisible(
        origin,
        targetPart,
        targetCharacter
    )
        if not state.Combat.VisibleCheck then
            return true
        end

        if typeof(origin)
                ~= "Vector3"
            or not targetPart
            or not targetCharacter then

            return false
        end

        local params =
            RaycastParams.new()

        params.FilterType =
            Enum.RaycastFilterType.Exclude

        params.FilterDescendantsInstances = {
            LocalPlayer.Character,
        }

        params.IgnoreWater =
            true

        local delta =
            targetPart.Position
            - origin

        local result =
            workspace:Raycast(
                origin,
                delta,
                params
            )

        if not result then
            return true
        end

        return result.Instance
            and result.Instance:
                IsDescendantOf(
                    targetCharacter
                )
    end

    local FLICK_PROJECTILE_FORCE_SCALE =
        20.224489795918366

    local function getPredictedPosition(
        targetPart,
        origin,
        force,
        gravity
    )
        if not targetPart then
            return nil
        end

        local targetPosition =
            targetPart.Position

        if not state.Combat.PredictionEnabled
            or typeof(origin)
                ~= "Vector3" then

            return targetPosition
        end

        local targetVelocity =
            targetPart.AssemblyLinearVelocity

        if typeof(targetVelocity)
            ~= "Vector3" then

            targetVelocity =
                Vector3.zero
        end

        local cap =
            math.max(
                10,
                tonumber(
                    state.Combat.VelocityCap
                )
                or 110
            )

        if targetVelocity.Magnitude > cap
            and targetVelocity.Magnitude > 0 then

            targetVelocity =
                targetVelocity.Unit
                * cap
        end

        local projectileForce =
            tonumber(force)
            or 130

        local projectileSpeed =
            math.max(
                1,
                projectileForce
                    * FLICK_PROJECTILE_FORCE_SCALE
            )

        local extraLead =
            math.max(
                0,
                tonumber(
                    state.Combat.PredictionLead
                )
                or 0.03
            )

        local gravityValue =
            tonumber(gravity)
            or 0

        local acceleration =
            Vector3.new(
                0,
                -gravityValue
                    * workspace.Gravity,
                0
            )

        local predicted =
            targetPosition

        -- A few cheap fixed-point iterations are enough because Flick's
        -- projectiles are fast (Force * 20.2244897959 studs/sec).
        for _ = 1, 3 do
            local travelTime =
                (
                    predicted
                    - origin
                ).Magnitude
                / projectileSpeed

            travelTime =
                math.clamp(
                    travelTime
                        + extraLead,
                    0,
                    1.25
                )

            -- Target movement + gravity compensation.
            predicted =
                targetPosition
                + targetVelocity
                    * travelTime
                - acceleration
                    * (
                        0.5
                        * travelTime
                        * travelTime
                    )
        end

        return predicted
    end

    local function getBestSilentAimTarget(
        origin
    )
        local camera =
            workspace.CurrentCamera

        if not camera then
            return nil,
                nil
        end

        local reference =
            getFOVPoint()

        if not reference then
            return nil,
                nil
        end

        local bestPlayer =
            nil

        local bestPart =
            nil

        local bestScreenDistance =
            math.huge

        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            if isCombatTarget(
                player
            ) then

                local part =
                    getCombatPart(
                        player
                    )

                local viewport,
                    visible =
                        camera:
                            WorldToViewportPoint(
                                part.Position
                            )

                if visible
                    and viewport.Z > 0 then

                    local screenDistance =
                        (
                            Vector2.new(
                                viewport.X,
                                viewport.Y
                            )
                            - reference
                        ).Magnitude

                    local passesFOV =
                        not state.Combat.UseFOV
                        or screenDistance
                            <= state.Combat.FOVRadius

                    if passesFOV
                        and screenDistance
                            < bestScreenDistance
                        and isVisible(
                            typeof(origin)
                                == "Vector3"
                                and origin
                                or (
                                    camera.CFrame.Position
                                ),
                            part,
                            player.Character
                        ) then

                        bestPlayer =
                            player

                        bestPart =
                            part

                        bestScreenDistance =
                            screenDistance
                    end
                end
            end
        end

        return bestPlayer,
            bestPart
    end

    -- ============================================================
    -- CAMERA AIMBOT
    -- ============================================================

    local function isAimbotActivationHeld()
        if state.Combat.AimbotAlwaysActive then
            return true
        end

        local ok, held = pcall(
            UserInputService.IsMouseButtonPressed,
            UserInputService,
            Enum.UserInputType.MouseButton2
        )

        return ok and held == true
    end

    local function getEquippedGunBallistics()
        local character = LocalPlayer.Character
        local tool = character
            and character:FindFirstChildOfClass("Tool")

        if not tool then
            return 130, 0
        end

        local force = tonumber(
            tool:GetAttribute("BulletForce")
        ) or 130

        local gravity = tonumber(
            tool:GetAttribute("Gravity")
        ) or 0

        return force, gravity
    end

    local function aimbotTargetStillValid(player, origin)
        if not player or not isCombatTarget(player) then
            return nil
        end

        -- Aimbot also respects the script's global combat/ESP distance cap.
        local localRoot = getRoot(LocalPlayer)
        local targetRoot = getRoot(player)

        if localRoot and targetRoot then
            local distance = (
                localRoot.Position - targetRoot.Position
            ).Magnitude

            if distance > (tonumber(state.MaxDistance) or 1500) then
                return nil
            end
        end

        local camera = workspace.CurrentCamera
        local part = getCombatPart(player)
        local reference = getFOVPoint()

        if not camera or not part or not reference then
            return nil
        end

        local viewport, onScreen = camera:WorldToViewportPoint(
            part.Position
        )

        if not onScreen or viewport.Z <= 0 then
            return nil
        end

        if state.Combat.UseFOV then
            local screenDistance = (
                Vector2.new(viewport.X, viewport.Y) - reference
            ).Magnitude

            -- Give a sticky target a small retention margin so tiny camera
            -- movements do not make the aimbot bounce between nearby players.
            local retentionRadius = math.max(
                1,
                (tonumber(state.Combat.FOVRadius) or 175) * 1.15
            )

            if screenDistance > retentionRadius then
                return nil
            end
        end

        if not isVisible(
            origin,
            part,
            player.Character
        ) then
            return nil
        end

        return part
    end

    local function getAimbotTarget(origin)
        if state.Combat.AimbotStickyTarget then
            local stickyPart = aimbotTargetStillValid(
                state.Combat.AimbotTarget,
                origin
            )

            if stickyPart then
                return state.Combat.AimbotTarget, stickyPart
            end
        end

        state.Combat.AimbotTarget = nil

        local camera = workspace.CurrentCamera
        local reference = getFOVPoint()
        local localRoot = getRoot(LocalPlayer)

        if not camera or not reference then
            return nil, nil
        end

        local bestPlayer = nil
        local bestPart = nil
        local bestScreenDistance = math.huge
        local maxDistance = tonumber(state.MaxDistance) or 1500

        for _, player in ipairs(Players:GetPlayers()) do
            if isCombatTarget(player) then
                local part = getCombatPart(player)
                local targetRoot = getRoot(player)
                local inRange = true

                if localRoot and targetRoot then
                    inRange = (
                        localRoot.Position - targetRoot.Position
                    ).Magnitude <= maxDistance
                end

                if inRange and part then
                    local viewport, onScreen =
                        camera:WorldToViewportPoint(part.Position)

                    if onScreen and viewport.Z > 0 then
                        local screenDistance = (
                            Vector2.new(viewport.X, viewport.Y)
                            - reference
                        ).Magnitude

                        local passesFOV =
                            not state.Combat.UseFOV
                            or screenDistance
                                <= (tonumber(state.Combat.FOVRadius) or 175)

                        if passesFOV
                            and screenDistance < bestScreenDistance
                            and isVisible(
                                origin,
                                part,
                                player.Character
                            ) then

                            bestPlayer = player
                            bestPart = part
                            bestScreenDistance = screenDistance
                        end
                    end
                end
            end
        end

        if bestPlayer then
            state.Combat.AimbotTarget = bestPlayer
        end

        return bestPlayer, bestPart
    end

    local function updateAimbot(deltaTime)
        if not state.Alive
            or not state.Combat.AimbotEnabled then

            state.Combat.AimbotTarget = nil
            return
        end

        if state.CursorUnlock.Enabled
            or UserInputService:GetFocusedTextBox()
            or not isAimbotActivationHeld() then

            state.Combat.AimbotTarget = nil
            return
        end

        local camera = workspace.CurrentCamera
        if not camera then
            state.Combat.AimbotTarget = nil
            return
        end

        local origin = camera.CFrame.Position
        local _, part = getAimbotTarget(origin)

        if not part then
            return
        end

        local aimPosition = part.Position

        if state.Combat.AimbotUsePrediction then
            local force, gravity = getEquippedGunBallistics()
            local predicted = getPredictedPosition(
                part,
                origin,
                force,
                gravity
            )

            if typeof(predicted) == "Vector3" then
                aimPosition = predicted
            end
        end

        local delta = aimPosition - origin
        if delta.Magnitude <= 0.001 then
            return
        end

        local desired = CFrame.lookAt(
            origin,
            aimPosition,
            camera.CFrame.UpVector
        )

        -- Exponential smoothing is frame-rate independent. Higher values feel
        -- faster/snappier while still avoiding a single-frame camera snap.
        local speed = math.clamp(
            tonumber(state.Combat.AimbotSmoothing) or 14,
            1,
            40
        )

        local dt = math.clamp(
            tonumber(deltaTime) or (1 / 60),
            1 / 240,
            0.10
        )

        local alpha = 1 - math.exp(-speed * dt)
        camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    end

    local function resolveShotTarget(
        origin,
        force,
        gravity
    )
        local player,
            part =
                getBestSilentAimTarget(
                    origin
                )

        if not player
            or not part then

            return nil
        end

        local predicted =
            getPredictedPosition(
                part,
                origin,
                force,
                gravity
            )

        if typeof(predicted)
            ~= "Vector3" then

            return nil
        end

        return {
            Player = player,
            Part = part,
            Position = predicted,
        }
    end

    local BULLET_PATCH_KEY =
        "__VITALITY_FLICK_BULLETHANDLER_PATCH"

    local function installSilentAimRouter()
        local gunModules =
            ReplicatedStorage:
                WaitForChild(
                    "ModuleScripts"
                ):
                WaitForChild(
                    "GunModules"
                )

        local bulletModule =
            gunModules:
                WaitForChild(
                    "BulletHandler"
                )

        local ok,
            BulletHandler =
                pcall(
                    require,
                    bulletModule
                )

        if not ok
            or type(BulletHandler)
                ~= "table"
            or type(BulletHandler.Fire)
                ~= "function" then

            warn(
                "[VitalityHub][Flick] BulletHandler.Fire was unavailable."
            )

            return false
        end

        local existing =
            rawget(
                _G,
                BULLET_PATCH_KEY
            )

        -- If a previous Vitality instance left a wrapper installed, reuse the
        -- original function stored in its patch record rather than stacking.
        local originalFire =
            type(existing)
                == "table"
            and existing.BulletHandler
                == BulletHandler
            and type(
                existing.OriginalFire
            ) == "function"
            and existing.OriginalFire
            or BulletHandler.Fire

        if type(existing)
                == "table"
            and existing.BulletHandler
                == BulletHandler
            and BulletHandler.Fire
                == existing.Wrapper then

            BulletHandler.Fire =
                originalFire
        end

        local patch = {
            BulletHandler = BulletHandler,
            OriginalFire = originalFire,
            Wrapper = nil,
            State = state,
        }

        local function wrappedFire(
            payload,
            ...
        )
            if state.Alive
                and state.Combat.SilentAimEnabled
                and type(payload)
                    == "table"
                and typeof(payload.Origin)
                    == "Vector3"
                and typeof(payload.Direction)
                    == "Vector3" then

                local target =
                    resolveShotTarget(
                        payload.Origin,
                        payload.Force,
                        payload.Gravity
                    )

                if target then
                    local delta =
                        target.Position
                        - payload.Origin

                    if delta.Magnitude
                        > 0.001 then

                        -- Copy the payload so other client systems do not see
                        -- us mutating the GunFramework's original t5 table.
                        local rewritten = {}

                        for key,
                            value in pairs(
                                payload
                            ) do

                            rewritten[
                                key
                            ] =
                                value
                        end

                        -- This is the source-level aim value Flick itself feeds
                        -- into BulletHandler. Everything after this point
                        -- (ProjectileRender / CheckShot / ProjectileFinished)
                        -- remains the game's original flow.
                        rewritten.Direction =
                            delta.Unit

                        payload =
                            rewritten
                    end
                end
            end

            return originalFire(
                payload,
                ...
            )
        end

        patch.Wrapper =
            wrappedFire

        _G[
            BULLET_PATCH_KEY
        ] =
            patch

        BulletHandler.Fire =
            wrappedFire

        state.Combat.BulletHandler =
            BulletHandler

        state.Combat.OriginalBulletFire =
            originalFire

        state.Combat.WrappedBulletFire =
            wrappedFire

        state.Combat.BulletPatchInstalled =
            true

        return true
    end

    -- ============================================================
    -- GUN MODS — LIVE GUNFRAMEWORK CONFIG TABLE
    -- ============================================================

    local function getFunctionUpvalues(
        fn
    )
        if type(fn)
            ~= "function" then

            return {}
        end

        if type(getupvalues)
            == "function" then

            local ok,
                values =
                    pcall(
                        getupvalues,
                        fn
                    )

            if ok
                and type(values)
                    == "table" then

                return values
            end
        end

        if debug
            and type(debug.getupvalues)
                == "function" then

            local ok,
                values =
                    pcall(
                        debug.getupvalues,
                        fn
                    )

            if ok
                and type(values)
                    == "table" then

                return values
            end
        end

        local values = {}

        if debug
            and type(debug.getupvalue)
                == "function" then

            for index = 1, 80 do
                local packed = {
                    pcall(
                        debug.getupvalue,
                        fn,
                        index
                    )
                }

                if not packed[1] then
                    break
                end

                local first =
                    packed[2]

                local second =
                    packed[3]

                -- Executors differ: some return value only, some name,value.
                local value =
                    second ~= nil
                    and second
                    or first

                if value == nil then
                    break
                end

                values[
                    index
                ] =
                    value
            end
        end

        return values
    end

    local function isGunConfigTable(
        value
    )
        return type(value)
                == "table"
            and rawget(
                value,
                "reloadTime"
            ) ~= nil
            and rawget(
                value,
                "FireRate"
            ) ~= nil
            and rawget(
                value,
                "spread"
            ) ~= nil
            and rawget(
                value,
                "Recoil"
            ) ~= nil
            and rawget(
                value,
                "BulletForce"
            ) ~= nil
            and rawget(
                value,
                "isAuto"
            ) ~= nil
    end

    local function scanForGunConfigs(
        value,
        results,
        visited,
        depth
    )
        if depth > 6 then
            return
        end

        local valueType =
            type(value)

        if valueType ~= "table"
            and valueType ~= "function" then

            return
        end

        if visited[
            value
        ] then

            return
        end

        visited[
            value
        ] =
            true

        if valueType
            == "table" then

            if isGunConfigTable(
                value
            ) then

                results[
                    value
                ] =
                    true
            end

            local checked =
                0

            for key,
                child in pairs(
                    value
                ) do

                checked +=
                    1

                if checked > 100 then
                    break
                end

                local childType =
                    type(child)

                if childType == "table"
                    or childType == "function" then

                    scanForGunConfigs(
                        child,
                        results,
                        visited,
                        depth + 1
                    )
                end

                local keyType =
                    type(key)

                if keyType == "table"
                    or keyType == "function" then

                    scanForGunConfigs(
                        key,
                        results,
                        visited,
                        depth + 1
                    )
                end
            end

            return
        end

        for _,
            upvalue in pairs(
                getFunctionUpvalues(
                    value
                )
            ) do

            scanForGunConfigs(
                upvalue,
                results,
                visited,
                depth + 1
            )
        end
    end

    local GunConfigFields = {
        "reloadTime",
        "spread",
        "Recoil",
        "isAuto",
        "FireRate",
        "Gravity",
        "BulletForce",
    }

    local function saveConfigOriginals(
        config
    )
        if state.GunMods.ConfigOriginals[
            config
        ] then

            return state.GunMods.ConfigOriginals[
                config
            ]
        end

        local originals = {}

        for _,
            key in ipairs(
                GunConfigFields
            ) do

            originals[
                key
            ] =
                rawget(
                    config,
                    key
                )
        end

        state.GunMods.ConfigOriginals[
            config
        ] =
            originals

        return originals
    end

    local function getSafeRapidFireRate(
        originalRate
    )
        local baseRate =
            math.max(
                tonumber(originalRate)
                    or 0.1,
                0.01
            )

        local multiplier =
            math.clamp(
                tonumber(
                    state.GunMods.RapidFireMultiplier
                )
                    or 1.05,
                1,
                1.10
            )

        local requestedRate =
            baseRate
            / multiplier

        local safeFloor =
            baseRate
            * math.clamp(
                tonumber(
                    state.GunMods.RapidFireFloorRatio
                )
                    or 0.90,
                0.90,
                1
            )

        return math.max(
            requestedRate,
            safeFloor
        )
    end

    local function applyModsToConfig(
        config
    )
        if not isGunConfigTable(
            config
        ) then

            return
        end

        local original =
            saveConfigOriginals(
                config
            )

        -- This is the correct reload-timer bypass for Flick:
        -- the normal ReloadWeapon handler still decides WHEN to reload;
        -- only its two reloadTime/2 waits become effectively zero.
        config.reloadTime =
            state.GunMods.InstantReload
            and 0
            or original.reloadTime

        config.spread =
            state.GunMods.NoSpread
            and 0
            or original.spread

        config.Recoil =
            state.GunMods.NoRecoil
            and Vector3.zero
            or original.Recoil

        config.isAuto =
            state.GunMods.FullAuto
            and true
            or original.isAuto

        config.FireRate =
            state.GunMods.RapidFire
            and getSafeRapidFireRate(
                original.FireRate
            )
            or original.FireRate

        config.Gravity =
            state.GunMods.NoGravity
            and 0
            or original.Gravity

        if state.GunMods.BulletForceEnabled then
            local baseForce =
                tonumber(
                    original.BulletForce
                )
                or tonumber(
                    config.BulletForce
                )
                or 110

            config.BulletForce =
                baseForce
                * math.clamp(
                    tonumber(
                        state.GunMods.BulletForceMultiplier
                    )
                    or 1,
                    0.25,
                    4
                )
        else
            config.BulletForce =
                original.BulletForce
        end
    end

    local function isLikelyGunTool(
        object
    )
        return object
            and object:IsA(
                "Tool"
            )
            and (
                object:GetAttribute(
                    "BulletForce"
                ) ~= nil
                or object:GetAttribute(
                    "FireRate"
                ) ~= nil
                or object:GetAttribute(
                    "Ammo"
                ) ~= nil
                or object:
                    FindFirstChild(
                        "BodyAttach"
                    )
                    ~= nil
            )
    end

    local function saveToolOriginals(
        tool
    )
        local saved =
            state.GunMods.ToolOriginals[
                tool
            ]

        if saved then
            return saved
        end

        saved = {}

        for _,
            key in ipairs(
                GunConfigFields
            ) do

            saved[
                key
            ] = {
                HadValue =
                    tool:GetAttribute(
                        key
                    ) ~= nil,
                Value =
                    tool:GetAttribute(
                        key
                    ),
            }
        end

        state.GunMods.ToolOriginals[
            tool
        ] =
            saved

        return saved
    end

    local function setToolAttributeFromOriginal(
        tool,
        key,
        newValue,
        enabled
    )
        local saved =
            saveToolOriginals(
                tool
            )

        local entry =
            saved[
                key
            ]

        if enabled then
            pcall(
                tool.SetAttribute,
                tool,
                key,
                newValue
            )

            return
        end

        if entry
            and entry.HadValue then

            pcall(
                tool.SetAttribute,
                tool,
                key,
                entry.Value
            )
        else
            pcall(
                tool.SetAttribute,
                tool,
                key,
                nil
            )
        end
    end

    local function applyModsToToolAttributes(
        tool
    )
        if not isLikelyGunTool(
            tool
        ) then

            return
        end

        local originals =
            saveToolOriginals(
                tool
            )

        setToolAttributeFromOriginal(
            tool,
            "reloadTime",
            0,
            state.GunMods.InstantReload
        )

        setToolAttributeFromOriginal(
            tool,
            "spread",
            0,
            state.GunMods.NoSpread
        )

        setToolAttributeFromOriginal(
            tool,
            "Recoil",
            Vector3.zero,
            state.GunMods.NoRecoil
        )

        setToolAttributeFromOriginal(
            tool,
            "isAuto",
            true,
            state.GunMods.FullAuto
        )

        -- Safe Rapid Fire only changes the private live GunFramework
        -- config table. The Tool's FireRate Attribute remains original.

        setToolAttributeFromOriginal(
            tool,
            "Gravity",
            0,
            state.GunMods.NoGravity
        )

        local forceEntry =
            originals.BulletForce

        local baseForce =
            forceEntry
            and forceEntry.HadValue
            and tonumber(
                forceEntry.Value
            )
            or tonumber(
                tool:GetAttribute(
                    "BulletForce"
                )
            )
            or 110

        setToolAttributeFromOriginal(
            tool,
            "BulletForce",
            baseForce
                * math.clamp(
                    tonumber(
                        state.GunMods.BulletForceMultiplier
                    )
                    or 1,
                    0.25,
                    4
                ),
            state.GunMods.BulletForceEnabled
        )
    end

    local function applyModsToCurrentTools()
        local backpack =
            LocalPlayer:
                FindFirstChildOfClass(
                    "Backpack"
                )
            or LocalPlayer:
                FindFirstChild(
                    "Backpack"
                )

        local character =
            LocalPlayer.Character

        if backpack then
            for _,
                object in ipairs(
                    backpack:GetChildren()
                ) do

                applyModsToToolAttributes(
                    object
                )
            end
        end

        if character then
            for _,
                object in ipairs(
                    character:GetChildren()
                ) do

                applyModsToToolAttributes(
                    object
                )
            end
        end
    end

    local function getReloadSignal()
        local manager =
            ReplicatedStorage:
                FindFirstChild(
                    "SignalManager"
                )

        local events =
            manager
            and manager:
                FindFirstChild(
                    "SignalEvents"
                )

        local signal =
            events
            and events:
                FindFirstChild(
                    "ReloadWeapon"
                )

        return signal
            and signal.Event
            or nil
    end

    local function refreshGunConfigs()
        applyModsToCurrentTools()

        if type(getconnections)
            ~= "function" then

            state.GunMods.LastConfigCount =
                0

            return 0
        end

        local reloadEvent =
            getReloadSignal()

        if not reloadEvent then
            state.GunMods.LastConfigCount =
                0

            return 0
        end

        local ok,
            connections =
                pcall(
                    getconnections,
                    reloadEvent
                )

        if not ok
            or type(connections)
                ~= "table" then

            state.GunMods.LastConfigCount =
                0

            return 0
        end

        local found = {}

        for _,
            connection in ipairs(
                connections
            ) do

            local fn =
                connection
                and connection.Function
                or nil

            if type(fn)
                == "function" then

                scanForGunConfigs(
                    fn,
                    found,
                    {},
                    0
                )
            end
        end

        local count =
            0

        for config in pairs(
            found
        ) do
            count +=
                1

            state.GunMods.Configs[
                config
            ] =
                true

            applyModsToConfig(
                config
            )
        end

        -- Re-apply to configs we already discovered too.
        for config in pairs(
            state.GunMods.Configs
        ) do
            if isGunConfigTable(
                config
            ) then

                applyModsToConfig(
                    config
                )
            else
                state.GunMods.Configs[
                    config
                ] =
                    nil
            end
        end

        state.GunMods.LastConfigCount =
            count

        return count
    end

    local function scheduleGunConfigRefresh(
        delayTime
    )
        state.GunMods.RefreshGeneration +=
            1

        local generation =
            state.GunMods.RefreshGeneration

        task.delay(
            tonumber(delayTime)
                or 0.15,
            function()
                if not state.Alive
                    or generation
                        ~= state.GunMods.RefreshGeneration then

                    return
                end

                refreshGunConfigs()
            end
        )
    end

    local function restoreAllGunMods()
        for config,
            original in pairs(
                state.GunMods.ConfigOriginals
            ) do

            if type(config)
                    == "table"
                and type(original)
                    == "table" then

                for key,
                    value in pairs(
                        original
                    ) do

                    config[
                        key
                    ] =
                        value
                end
            end
        end

        for tool,
            saved in pairs(
                state.GunMods.ToolOriginals
            ) do

            if tool
                and tool.Parent
                and type(saved)
                    == "table" then

                for key,
                    entry in pairs(
                        saved
                    ) do

                    if entry.HadValue then
                        pcall(
                            tool.SetAttribute,
                            tool,
                            key,
                            entry.Value
                        )
                    else
                        pcall(
                            tool.SetAttribute,
                            tool,
                            key,
                            nil
                        )
                    end
                end
            end
        end
    end

    -- ============================================================
    -- KNIFE / MELEE MODS
    -- ============================================================

    local MeleeFields = {
        "SwingRate",
        "EquipTime",
        "SwingRecoil",
        "SpeedBoost",
    }

    local function isMeleeConfig(value)
        return type(value) == "table"
            and rawget(value, "SwingRate") ~= nil
            and rawget(value, "EquipTime") ~= nil
            and rawget(value, "SwingRecoil") ~= nil
            and rawget(value, "SpeedBoost") ~= nil
    end

    local function scanMelee(value, found, visited, depth)
        if depth > 6 then return end
        local kind = type(value)
        if kind ~= "table" and kind ~= "function" then return end
        if visited[value] then return end
        visited[value] = true

        if kind == "table" then
            if isMeleeConfig(value) then found[value] = true end
            local n = 0
            for k, v in pairs(value) do
                n += 1
                if n > 100 then break end
                if type(v) == "table" or type(v) == "function" then
                    scanMelee(v, found, visited, depth + 1)
                end
                if type(k) == "table" or type(k) == "function" then
                    scanMelee(k, found, visited, depth + 1)
                end
            end
            return
        end

        for _, up in pairs(getFunctionUpvalues(value)) do
            scanMelee(up, found, visited, depth + 1)
        end
    end

    local function meleeOriginals(config)
        local saved = state.MeleeMods.ConfigOriginals[config]
        if saved then return saved end
        saved = {}
        for _, key in ipairs(MeleeFields) do
            saved[key] = rawget(config, key)
        end
        state.MeleeMods.ConfigOriginals[config] = saved
        return saved
    end

    local function applyMeleeConfig(config)
        if not isMeleeConfig(config) then return end
        local original = meleeOriginals(config)

        config.SwingRecoil =
            state.MeleeMods.NoSwingRecoil and Vector3.zero
            or original.SwingRecoil

        local baseSwing = tonumber(original.SwingRate) or 0.4
        config.SwingRate =
            state.MeleeMods.FastSwing
            and math.max(0.05, baseSwing / math.clamp(state.MeleeMods.SwingSpeed, 1, 2))
            or original.SwingRate

        config.EquipTime =
            state.MeleeMods.InstantEquip and 0
            or original.EquipTime

        config.SpeedBoost =
            state.MeleeMods.SpeedBoostOverride
            and math.clamp(state.MeleeMods.SpeedBoost, 0, 20)
            or original.SpeedBoost
    end

    local function isMeleeTool(tool)
        return tool and tool:IsA("Tool") and (
            tool:GetAttribute("SwingRate") ~= nil
            or tool:GetAttribute("EquipTime") ~= nil
            or tool:GetAttribute("SwingRecoil") ~= nil
            or tool:GetAttribute("SpeedBoost") ~= nil
        )
    end

    local function saveMeleeTool(tool)
        local saved = state.MeleeMods.ToolOriginals[tool]
        if saved then return saved end
        saved = {}
        for _, key in ipairs(MeleeFields) do
            local v = tool:GetAttribute(key)
            saved[key] = {Had = v ~= nil, Value = v}
        end
        state.MeleeMods.ToolOriginals[tool] = saved
        return saved
    end

    local function setMeleeAttr(tool, key, value, enabled)
        local saved = saveMeleeTool(tool)[key]
        if enabled then
            pcall(tool.SetAttribute, tool, key, value)
        elseif saved and saved.Had then
            pcall(tool.SetAttribute, tool, key, saved.Value)
        else
            pcall(tool.SetAttribute, tool, key, nil)
        end
    end

    local function applyMeleeTool(tool)
        if not isMeleeTool(tool) then return end
        local saved = saveMeleeTool(tool)

        setMeleeAttr(tool, "SwingRecoil", Vector3.zero, state.MeleeMods.NoSwingRecoil)

        local swing = tonumber(saved.SwingRate and saved.SwingRate.Value)
            or tonumber(tool:GetAttribute("SwingRate")) or 0.4
        setMeleeAttr(
            tool, "SwingRate",
            math.max(0.05, swing / math.clamp(state.MeleeMods.SwingSpeed, 1, 2)),
            state.MeleeMods.FastSwing
        )

        setMeleeAttr(tool, "EquipTime", 0, state.MeleeMods.InstantEquip)

        setMeleeAttr(
            tool, "SpeedBoost",
            math.clamp(state.MeleeMods.SpeedBoost, 0, 20),
            state.MeleeMods.SpeedBoostOverride
        )
    end

    local function refreshMeleeConfigs()
        if type(getconnections) ~= "function" then return 0 end
        local found = {}

        local function inspect(tool)
            if not isMeleeTool(tool) then return end
            applyMeleeTool(tool)

            for _, signal in ipairs({tool.Equipped, tool.Unequipped}) do
                local ok, connections = pcall(getconnections, signal)
                if ok and type(connections) == "table" then
                    for _, connection in ipairs(connections) do
                        if connection and type(connection.Function) == "function" then
                            scanMelee(connection.Function, found, {}, 0)
                        end
                    end
                end
            end
        end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do inspect(tool) end
        end
        if LocalPlayer.Character then
            for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do inspect(tool) end
        end

        local count = 0
        for config in pairs(found) do
            count += 1
            state.MeleeMods.Configs[config] = true
            applyMeleeConfig(config)
        end
        for config in pairs(state.MeleeMods.Configs) do
            if isMeleeConfig(config) then
                applyMeleeConfig(config)
            else
                state.MeleeMods.Configs[config] = nil
            end
        end

        state.MeleeMods.LastConfigCount = count
        return count
    end

    local function restoreMeleeMods()
        for config, original in pairs(state.MeleeMods.ConfigOriginals) do
            if type(config) == "table" and type(original) == "table" then
                for key, value in pairs(original) do config[key] = value end
            end
        end

        for tool, saved in pairs(state.MeleeMods.ToolOriginals) do
            if tool and tool.Parent then
                for key, entry in pairs(saved) do
                    if entry.Had then
                        pcall(tool.SetAttribute, tool, key, entry.Value)
                    else
                        pcall(tool.SetAttribute, tool, key, nil)
                    end
                end
            end
        end
    end

    local function createFOVCircle()
        if state.Combat.FOVGui
            and state.Combat.FOVGui.Parent then

            return
        end

        local parent =
            CoreGui

        if type(gethui)
            == "function" then

            local ok,
                hui =
                    pcall(
                        gethui
                    )

            if ok and hui then
                parent =
                    hui
            end
        end

        local gui =
            Instance.new(
                "ScreenGui"
            )

        gui.Name =
            "Flick_SilentAim_FOV"

        gui.ResetOnSpawn =
            false

        gui.IgnoreGuiInset =
            true

        gui.DisplayOrder =
            999998

        gui.ZIndexBehavior =
            Enum.ZIndexBehavior.Sibling

        local frame =
            Instance.new(
                "Frame"
            )

        frame.Name =
            "Circle"

        frame.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )

        frame.BackgroundTransparency =
            1

        frame.BorderSizePixel =
            0

        frame.Parent =
            gui

        local corner =
            Instance.new(
                "UICorner"
            )

        corner.CornerRadius =
            UDim.new(
                1,
                0
            )

        corner.Parent =
            frame

        local stroke =
            Instance.new(
                "UIStroke"
            )

        stroke.Thickness =
            1.5

        stroke.Transparency =
            0.12

        stroke.Color =
            Color3.fromRGB(
                235,
                235,
                235
            )

        stroke.Parent =
            frame

        gui.Parent =
            parent

        state.Combat.FOVGui =
            gui

        state.Combat.FOVFrame =
            frame
    end

    local function updateFOVCircle()
        if not state.Alive then
            return
        end

        if not state.Combat.ShowFOVCircle then
            if state.Combat.FOVFrame then
                state.Combat.FOVFrame.Visible =
                    false
            end

            return
        end

        createFOVCircle()

        local frame =
            state.Combat.FOVFrame

        local point =
            getFOVPoint()

        if not frame
            or not point then

            return
        end

        local radius =
            math.max(
                1,
                tonumber(
                    state.Combat.FOVRadius
                )
                or 175
            )

        frame.Size =
            UDim2.fromOffset(
                radius * 2,
                radius * 2
            )

        frame.Position =
            UDim2.fromOffset(
                point.X,
                point.Y
            )

        frame.Visible =
            true
    end

    state.Combat.UpdateFOVCircle =
        updateFOVCircle

    installSilentAimRouter()

    local function getDistance(player)
        local a = getRoot(LocalPlayer)
        local b = getRoot(player)
        if not a or not b then return nil end
        return (a.Position - b.Position).Magnitude
    end

    local function shouldShow(player)
        if not player or player == LocalPlayer then return false end
        if state.TeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            return false
        end
        local root = getRoot(player)
        local humanoid = getHumanoid(player)
        local currentHealth =
            getPlayerHealthState(
                player
            )

        if not root
            or not humanoid
            or (
                tonumber(
                    currentHealth
                )
                or 0
            ) <= 0 then

            return false
        end

        local distance = getDistance(player)
        return not distance or distance <= state.MaxDistance
    end

    local function getName(player)
        if state.NameFormat == "Display Name" then
            return player.DisplayName
        elseif state.NameFormat == "Display + Username" and player.DisplayName ~= player.Name then
            return player.DisplayName .. " (@" .. player.Name .. ")"
        end
        return player.Name
    end

    local function scaledTextSize(distance)
        if not state.DistanceScaling or not distance then
            return state.BaseTextSize
        end
        local alpha = math.clamp(distance / math.max(state.MaxDistance, 1), 0, 1)
        return math.floor(state.MaxTextSize + (state.MinTextSize - state.MaxTextSize) * alpha + 0.5)
    end

    local function healthColor(prefix, ratio)
        ratio = math.clamp(ratio or 0, 0, 1)
        if ratio >= 0.66 then
            return activeColor(prefix .. " High")
        elseif ratio >= 0.33 then
            return activeColor(prefix .. " Mid")
        end
        return activeColor(prefix .. " Low")
    end

    local function project(position)
        local camera = workspace.CurrentCamera
        if not camera then return nil, false end
        local p, visible = camera:WorldToViewportPoint(position)
        return Vector2.new(p.X, p.Y), visible and p.Z > 0
    end

    local function screenBounds(character)
        if not character then return nil end
        local ok, cf, size = pcall(character.GetBoundingBox, character)
        if not ok then return nil end

        local half = size / 2
        local corners = {
            Vector3.new(-half.X,-half.Y,-half.Z), Vector3.new(-half.X,-half.Y,half.Z),
            Vector3.new(-half.X,half.Y,-half.Z), Vector3.new(-half.X,half.Y,half.Z),
            Vector3.new(half.X,-half.Y,-half.Z), Vector3.new(half.X,-half.Y,half.Z),
            Vector3.new(half.X,half.Y,-half.Z), Vector3.new(half.X,half.Y,half.Z),
        }

        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local seen = false

        for _, offset in ipairs(corners) do
            local point, visible = project(cf:PointToWorldSpace(offset))
            if point then
                minX = math.min(minX, point.X)
                minY = math.min(minY, point.Y)
                maxX = math.max(maxX, point.X)
                maxY = math.max(maxY, point.Y)
                seen = seen or visible
            end
        end

        if not seen then return nil end
        return {Left=minX, Top=minY, Right=maxX, Bottom=maxY, Width=maxX-minX, Height=maxY-minY}
    end

    -- ============================================================
    -- TRIGGERBOT
    -- ============================================================

    local function getTriggerbotRayTarget(screenPoint)
        local camera = workspace.CurrentCamera
        if not camera or typeof(screenPoint) ~= "Vector2" then
            return nil, nil
        end

        local ray = camera:ViewportPointToRay(
            screenPoint.X,
            screenPoint.Y
        )

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude

        local excluded = {}
        if LocalPlayer.Character then
            excluded[#excluded + 1] = LocalPlayer.Character
        end

        local localWorldModel =
            getWorkspacePlayerModel(LocalPlayer)

        if localWorldModel
            and localWorldModel ~= LocalPlayer.Character then

            excluded[#excluded + 1] = localWorldModel
        end

        params.FilterDescendantsInstances = excluded
        params.IgnoreWater = true

        local maxRayDistance = math.max(
            tonumber(state.MaxDistance) or 1500,
            250
        ) + 100

        local result = workspace:Raycast(
            ray.Origin,
            ray.Direction * maxRayDistance,
            params
        )

        if not result or not result.Instance then
            return nil, nil
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and shouldShow(player) then
                local character =
                    getWorkspacePlayerModel(player)
                    or player.Character

                if character
                    and result.Instance:IsDescendantOf(character) then

                    return player, result.Instance
                end
            end
        end

        return nil, nil
    end

    local function getTriggerbotTarget()
        local reference = getFOVPoint()
        if not reference then
            return nil, nil
        end

        local radius = math.clamp(
            tonumber(state.Combat.TriggerbotRadius) or 0,
            0,
            40
        )

        -- Center is always checked first. The surrounding samples make the
        -- trigger radius forgiving without turning it into a separate aimbot.
        local offsets = {
            Vector2.zero,
        }

        if radius > 0 then
            local diagonal = radius * 0.70710678
            offsets[#offsets + 1] = Vector2.new(radius, 0)
            offsets[#offsets + 1] = Vector2.new(-radius, 0)
            offsets[#offsets + 1] = Vector2.new(0, radius)
            offsets[#offsets + 1] = Vector2.new(0, -radius)
            offsets[#offsets + 1] = Vector2.new(diagonal, diagonal)
            offsets[#offsets + 1] = Vector2.new(-diagonal, diagonal)
            offsets[#offsets + 1] = Vector2.new(diagonal, -diagonal)
            offsets[#offsets + 1] = Vector2.new(-diagonal, -diagonal)
        end

        for _, offset in ipairs(offsets) do
            local player, hitPart = getTriggerbotRayTarget(
                reference + offset
            )

            if player then
                return player, hitPart
            end
        end

        return nil, nil
    end

    local function getExecutorMouseFunction(name)
        local value = nil

        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" then
                value = rawget(env, name)
            end
        end

        if type(value) ~= "function" and type(getfenv) == "function" then
            local ok, env = pcall(getfenv, 0)
            if ok and type(env) == "table" then
                value = rawget(env, name)
            end
        end

        return type(value) == "function" and value or nil
    end

    local function fireTriggerbotShot()
        -- Prefer a real left-click path so Flick's own gun framework still
        -- handles ammo, fire rate, animations, CheckShot, and networking.
        local click = getExecutorMouseFunction("mouse1click")
        if click then
            local ok = pcall(click)
            if ok then
                return true
            end
        end

        local press = getExecutorMouseFunction("mouse1press")
        local release = getExecutorMouseFunction("mouse1release")

        if press and release then
            local pressed = pcall(press)
            if pressed then
                task.wait(0.01)
                pcall(release)
                return true
            end
        end

        -- Fallback for executors that do not expose mouse1* helpers.
        local character = LocalPlayer.Character
        local tool = character
            and character:FindFirstChildOfClass("Tool")

        if tool then
            local ok = pcall(function()
                tool:Activate()
            end)

            if ok then
                return true
            end
        end

        -- Last fallback: attempt Roblox's virtual mouse input service.
        local okService, virtualInput = pcall(
            game.GetService,
            game,
            "VirtualInputManager"
        )

        local point = getFOVPoint()
        if okService and virtualInput and point then
            local ok = pcall(function()
                virtualInput:SendMouseButtonEvent(
                    point.X,
                    point.Y,
                    0,
                    true,
                    game,
                    0
                )

                virtualInput:SendMouseButtonEvent(
                    point.X,
                    point.Y,
                    0,
                    false,
                    game,
                    0
                )
            end)

            if ok then
                return true
            end
        end

        return false
    end

    local function updateTriggerbot()
        if not state.Alive
            or not state.Combat.TriggerbotEnabled then

            return
        end

        if UserInputService:GetFocusedTextBox()
            or state.CursorUnlock.Enabled then

            -- Avoid synthetic clicks while the hub cursor is intentionally
            -- unlocked for menu interaction.
            return
        end

        local now = os.clock()
        local scanInterval = math.max(
            0.01,
            tonumber(state.Combat.TriggerbotScanInterval) or 0.02
        )

        if now - state.Combat.TriggerbotLastScan < scanInterval then
            return
        end

        state.Combat.TriggerbotLastScan = now

        if state.Combat.TriggerbotPending then
            return
        end

        local cooldown = math.max(
            0.03,
            tonumber(state.Combat.TriggerbotCooldown) or 0.10
        )

        if now - state.Combat.TriggerbotLastShot < cooldown then
            return
        end

        local player = getTriggerbotTarget()
        if not player then
            return
        end

        state.Combat.TriggerbotPending = true
        state.Combat.TriggerbotGeneration += 1

        local generation = state.Combat.TriggerbotGeneration
        local fireDelay = math.clamp(
            tonumber(state.Combat.TriggerbotDelay) or 0,
            0,
            0.50
        )

        task.delay(fireDelay, function()
            if not state.Alive
                or not state.Combat.TriggerbotEnabled
                or generation ~= state.Combat.TriggerbotGeneration then

                if generation == state.Combat.TriggerbotGeneration then
                    state.Combat.TriggerbotPending = false
                end
                return
            end

            -- Re-confirm that a valid target is still beneath the trigger area
            -- after the configured delay. This prevents stale delayed shots.
            local currentTarget = getTriggerbotTarget()

            if currentTarget then
                if fireTriggerbotShot() then
                    state.Combat.TriggerbotLastShot = os.clock()
                end
            end

            if generation == state.Combat.TriggerbotGeneration then
                state.Combat.TriggerbotPending = false
            end
        end)
    end

    -- Screen-space overlay for box/skeleton/health-bar.
    local overlay = Instance.new("ScreenGui")
    overlay.Name = "Flick_PlayerESP_Overlay"
    overlay.ResetOnSpawn = false
    overlay.IgnoreGuiInset = true
    overlay.DisplayOrder = 999990

    local overlayParent = CoreGui
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then overlayParent = hui end
    end
    overlay.Parent = overlayParent

    local function newLine(name)
        local frame = Instance.new("Frame")
        frame.Name = name
        frame.BorderSizePixel = 0
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Visible = false
        frame.ZIndex = 20
        frame.Parent = overlay
        return frame
    end

    local function setLine(frame, a, b, thickness, color)
        local delta = b - a
        local length = delta.Magnitude
        if length < 0.1 then
            frame.Visible = false
            return
        end
        frame.Visible = true
        frame.Position = UDim2.fromOffset((a.X+b.X)/2, (a.Y+b.Y)/2)
        frame.Size = UDim2.fromOffset(length, thickness)
        frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
        frame.BackgroundColor3 = color
    end

    -- ============================================================
    -- THREAT AWARENESS
    -- ============================================================
    --
    -- Roblox does not replicate other players' exact camera CFrame.
    -- We therefore use their replicated Head / HumanoidRootPart facing as
    -- an approximation for "I am inside their screen / they are looking at me."
    --
    -- A threat is considered active when:
    --   1) the player is alive
    --   2) the local player is inside their configured forward view cone
    --   3) optional LOS from their head/root reaches the local character
    --
    -- The UI indicator is intentionally screen-space and directional.

    local function hideThreatIndicators()
        for _,
            indicator in ipairs(
                state.Awareness.Indicators
            ) do

            indicator.Visible =
                false
        end
    end

    local function ensureThreatIndicator(
        index
    )
        local indicator =
            state.Awareness.Indicators[
                index
            ]

        if indicator
            and indicator.Parent
            and indicator:IsA("Frame")
            and indicator:FindFirstChild("Core")
            and indicator:FindFirstChild("GlowMid")
            and indicator:FindFirstChild("GlowOuter") then

            return indicator
        end

        if indicator then
            pcall(function()
                indicator:Destroy()
            end)
        end

        -- The threat marker uses three stacked arrow glyphs. The two larger,
        -- translucent copies create a bright neon-red halo while the center
        -- glyph stays sharp enough to read instantly as a direction pointer.
        indicator =
            Instance.new(
                "Frame"
            )

        indicator.Name =
            "Flick_ThreatIndicator_"
            .. tostring(
                index
            )

        indicator.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )

        indicator.Size =
            UDim2.fromOffset(
                92,
                92
            )

        indicator.BackgroundTransparency =
            1

        indicator.BorderSizePixel =
            0

        indicator.ZIndex =
            100

        indicator.Visible =
            false

        local function makePointerLayer(
            name,
            zIndex
        )
            local layer =
                Instance.new(
                    "TextLabel"
                )

            layer.Name =
                name

            layer.AnchorPoint =
                Vector2.new(
                    0.5,
                    0.5
                )

            layer.Position =
                UDim2.fromScale(
                    0.5,
                    0.5
                )

            layer.Size =
                UDim2.fromScale(
                    1,
                    1
                )

            layer.BackgroundTransparency =
                1

            layer.BorderSizePixel =
                0

            layer.Text =
                "▲"

            layer.Font =
                Enum.Font.GothamBlack

            layer.TextColor3 =
                state.Awareness.IndicatorColor

            layer.TextStrokeColor3 =
                Color3.fromRGB(
                    255,
                    0,
                    30
                )

            layer.ZIndex =
                zIndex

            layer.Parent =
                indicator

            return layer
        end

        local glowOuter =
            makePointerLayer(
                "GlowOuter",
                100
            )

        glowOuter.TextSize =
            72

        glowOuter.TextTransparency =
            0.82

        glowOuter.TextStrokeTransparency =
            0.68

        local glowMid =
            makePointerLayer(
                "GlowMid",
                101
            )

        glowMid.TextSize =
            62

        glowMid.TextTransparency =
            0.55

        glowMid.TextStrokeTransparency =
            0.42

        local core =
            makePointerLayer(
                "Core",
                102
            )

        core.TextSize =
            50

        core.TextTransparency =
            0

        core.TextStrokeColor3 =
            Color3.fromRGB(
                70,
                0,
                8
            )

        core.TextStrokeTransparency =
            0.02

        indicator.Parent =
            overlay

        state.Awareness.Indicators[
            index
        ] =
            indicator

        return indicator
    end

    local function getAwarenessPart(
        character
    )
        if not character then
            return nil
        end

        return character:
            FindFirstChild(
                "Head"
            )
            or character:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or character:
                FindFirstChild(
                    "UpperTorso"
                )
            or character:
                FindFirstChild(
                    "Torso"
                )
    end

    local function threatHasLineOfSight(
        threatCharacter,
        threatOrigin,
        localCharacter,
        localTarget
    )
        if not state.Awareness.RequireLineOfSight then
            return true
        end

        if not threatCharacter
            or not localCharacter
            or typeof(
                threatOrigin
            ) ~= "Vector3"
            or not localTarget then

            return false
        end

        local delta =
            localTarget.Position
            - threatOrigin

        if delta.Magnitude
            <= 0.01 then

            return true
        end

        local params =
            RaycastParams.new()

        params.FilterType =
            Enum.RaycastFilterType.Exclude

        params.FilterDescendantsInstances = {
            threatCharacter,
        }

        params.IgnoreWater =
            true

        local hit =
            workspace:
                Raycast(
                    threatOrigin,
                    delta,
                    params
                )

        if not hit then
            return true
        end

        return hit.Instance
            and hit.Instance:
                IsDescendantOf(
                    localCharacter
                )
    end

    local function isThreatLookingAtLocal(
        player,
        localCharacter,
        localTarget
    )
        if not player
            or player == LocalPlayer
            or not localCharacter
            or not localTarget then

            return false,
                nil,
                nil
        end

        if state.TeamCheck
            and LocalPlayer.Team
            and player.Team
                == LocalPlayer.Team then

            return false,
                nil,
                nil
        end

        local character =
            getWorkspacePlayerModel(
                player
            )
            or player.Character

        if not character then
            return false,
                nil,
                nil
        end

        local humanoid =
            character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        if humanoid
            and humanoid.Health <= 0 then

            return false,
                nil,
                nil
        end

        local facingPart =
            getAwarenessPart(
                character
            )

        if not facingPart
            or not facingPart:IsA(
                "BasePart"
            ) then

            return false,
                nil,
                nil
        end

        local origin =
            facingPart.Position

        local toLocal =
            localTarget.Position
            - origin

        local distance =
            toLocal.Magnitude

        if distance <= 0.01
            or distance
                > math.max(
                    1,
                    tonumber(
                        state.Awareness.MaxDistance
                    )
                    or 1500
                ) then

            return false,
                nil,
                nil
        end

        local direction =
            toLocal.Unit

        local facing =
            facingPart.CFrame.LookVector

        -- Full cone angle is exposed in UI. Convert to half-angle here.
        local halfAngle =
            math.rad(
                math.clamp(
                    tonumber(
                        state.Awareness.ViewConeDegrees
                    )
                    or 120,
                    20,
                    179
                )
                * 0.5
            )

        local requiredDot =
            math.cos(
                halfAngle
            )

        local facingDot =
            facing:Dot(
                direction
            )

        if facingDot
            < requiredDot then

            return false,
                nil,
                nil
        end

        if not threatHasLineOfSight(
            character,
            origin,
            localCharacter,
            localTarget
        ) then

            return false,
                nil,
                nil
        end

        return true,
            facingPart,
            distance
    end

    local function positionThreatIndicator(
        indicator,
        worldPosition,
        index,
        timeNow
    )
        local camera =
            workspace.CurrentCamera

        if not camera
            or not indicator
            or typeof(
                worldPosition
            ) ~= "Vector3" then

            if indicator then
                indicator.Visible =
                    false
            end

            return
        end

        local viewport =
            camera.ViewportSize

        local center =
            viewport
            * 0.5

        local worldDelta =
            worldPosition
            - camera.CFrame.Position

        if worldDelta.Magnitude
            <= 0.01 then

            indicator.Visible =
                false

            return
        end

        local direction =
            worldDelta.Unit

        -- Horizontal/right component + front/back component.
        -- Ahead -> top, behind -> bottom.
        local screenDirection =
            Vector2.new(
                camera.CFrame.RightVector:
                    Dot(
                        direction
                    ),
                -camera.CFrame.LookVector:
                    Dot(
                        direction
                    )
            )

        if screenDirection.Magnitude
            <= 0.001 then

            screenDirection =
                Vector2.new(
                    0,
                    -1
                )
        else
            screenDirection =
                screenDirection.Unit
        end

        local edgeRadius =
            math.clamp(
                tonumber(
                    state.Awareness.IndicatorRadius
                )
                or 175,
                60,
                math.max(
                    60,
                    math.min(
                        viewport.X,
                        viewport.Y
                    )
                    * 0.46
                )
            )

        local position =
            center
            + screenDirection
                * edgeRadius

        -- Extra padding accounts for the larger neon halo.
        local edgePadding =
            46

        position =
            Vector2.new(
                math.clamp(
                    position.X,
                    edgePadding,
                    viewport.X
                        - edgePadding
                ),
                math.clamp(
                    position.Y,
                    edgePadding,
                    viewport.Y
                        - edgePadding
                )
            )

        local angle =
            math.deg(
                math.atan2(
                    screenDirection.Y,
                    screenDirection.X
                )
            )
            + 90

        -- Stronger pulse than the previous marker. The core stays crisp while
        -- the two glow layers expand and brighten like a neon warning light.
        local pulse =
            (
                math.sin(
                    timeNow
                        * 9
                        + index
                )
                + 1
            )
            * 0.5

        local core =
            indicator:FindFirstChild(
                "Core"
            )

        local glowMid =
            indicator:FindFirstChild(
                "GlowMid"
            )

        local glowOuter =
            indicator:FindFirstChild(
                "GlowOuter"
            )

        local coreSize =
            48
            + pulse
                * 12

        indicator.Position =
            UDim2.fromOffset(
                position.X,
                position.Y
            )

        indicator.Rotation =
            angle

        if core then
            core.TextSize =
                coreSize

            core.TextTransparency =
                0.02
                + (
                    1 - pulse
                )
                    * 0.08

            core.TextStrokeTransparency =
                0.01
                + (
                    1 - pulse
                )
                    * 0.08

            core.TextColor3 =
                state.Awareness.IndicatorColor
        end

        if glowMid then
            glowMid.TextSize =
                coreSize
                + 14

            glowMid.TextTransparency =
                0.42
                + (
                    1 - pulse
                )
                    * 0.18

            glowMid.TextStrokeTransparency =
                0.32
                + (
                    1 - pulse
                )
                    * 0.18

            glowMid.TextColor3 =
                state.Awareness.IndicatorColor
        end

        if glowOuter then
            glowOuter.TextSize =
                coreSize
                + 28

            glowOuter.TextTransparency =
                0.68
                + (
                    1 - pulse
                )
                    * 0.15

            glowOuter.TextStrokeTransparency =
                0.55
                + (
                    1 - pulse
                )
                    * 0.18

            glowOuter.TextColor3 =
                state.Awareness.IndicatorColor
        end

        indicator.Visible =
            true
    end

    local function updateThreatAwareness()
        if not state.Alive
            or not state.ESPEnabled
            or not state.Awareness.Enabled then

            hideThreatIndicators()
            return
        end

        local timeNow =
            os.clock()

        if timeNow
            - state.Awareness.LastScan
            < math.max(
                0.03,
                tonumber(
                    state.Awareness.ScanInterval
                )
                or 0.06
            ) then

            return
        end

        state.Awareness.LastScan =
            timeNow

        local localCharacter =
            LocalPlayer.Character

        local localTarget =
            getAwarenessPart(
                localCharacter
            )

        if not localCharacter
            or not localTarget
            or not localTarget:IsA(
                "BasePart"
            ) then

            hideThreatIndicators()
            return
        end

        local threats = {}

        for _,
            player in ipairs(
                Players:GetPlayers()
            ) do

            if player ~= LocalPlayer then
                local active,
                    facingPart,
                    distance =
                        isThreatLookingAtLocal(
                            player,
                            localCharacter,
                            localTarget
                        )

                if active
                    and facingPart then

                    table.insert(
                        threats,
                        {
                            Player = player,
                            Part = facingPart,
                            Distance =
                                distance
                                or math.huge,
                        }
                    )
                end
            end
        end

        table.sort(
            threats,
            function(a, b)
                return a.Distance
                    < b.Distance
            end
        )

        local maxIndicators =
            math.clamp(
                math.floor(
                    tonumber(
                        state.Awareness.MaxIndicators
                    )
                    or 6
                ),
                1,
                12
            )

        local shown =
            math.min(
                #threats,
                maxIndicators
            )

        for index = 1,
            shown do

            local threat =
                threats[
                    index
                ]

            local indicator =
                ensureThreatIndicator(
                    index
                )

            positionThreatIndicator(
                indicator,
                threat.Part.Position,
                index,
                timeNow
            )
        end

        for index = shown + 1,
            #state.Awareness.Indicators do

            state.Awareness.Indicators[
                index
            ].Visible =
                false
        end
    end

    local SkeletonPairs = {
        {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
        -- R6 fallbacks
        {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"}, {"Torso","Left Leg"}, {"Torso","Right Leg"},
    }

    -- ============================================================
    -- PLAYER-IN-PLAY / PERSISTENT HIGHLIGHTS
    -- ============================================================

    local function getPersistentGuiParent()
        if type(gethui)
            == "function" then

            local ok,
                hui =
                    pcall(
                        gethui
                    )

            if ok and hui then
                return hui
            end
        end

        return CoreGui
    end

    local function isPlayerInPlay(
        player
    )
        if not player
            or player == LocalPlayer then

            return false
        end

        -- Flick commonly keeps the active world model directly under workspace
        -- using the player's username. Prefer it when present.
        local character =
            workspace:
                FindFirstChild(
                    player.Name
                )
            or player.Character

        if not character
            or not character:IsA(
                "Model"
            ) then

            return false
        end

        local root =
            character:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or character:
                FindFirstChild(
                    "UpperTorso"
                )
            or character:
                FindFirstChild(
                    "Torso"
                )

        if not root
            or not root:IsA(
                "BasePart"
            ) then

            return false
        end

        local healthObject =
            character:
                FindFirstChild(
                    "Health"
                )

        if healthObject then
            local ok,
                health =
                    pcall(function()
                        return tonumber(
                            healthObject.Value
                        )
                    end)

            if ok
                and health ~= nil then

                return health > 0
            end
        end

        local humanoid =
            character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        return humanoid == nil
            or humanoid.Health > 0
    end

    local function ensurePersistentHighlight(
        player,
        data,
        character
    )
        if not character then
            return nil
        end

        local highlight =
            data.Highlight

        if not highlight
            or not highlight.Parent then

            highlight =
                Instance.new(
                    "Highlight"
                )

            highlight.Name =
                "Flick_PlayerChams"

            highlight.DepthMode =
                Enum.HighlightDepthMode.AlwaysOnTop

            -- Parent outside the character so character cleanup / descendant
            -- refreshes do not delete the ESP object.
            highlight.Parent =
                getPersistentGuiParent()

            data.Highlight =
                highlight
        end

        highlight.Adornee =
            character

        -- Always-on-top chams are intentionally visible through walls.
        -- Re-apply this every refresh in case another client system changes it.
        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.FillColor =
            state.ChamsColor

        highlight.OutlineColor =
            activeColor(
                "Chams Outline"
            )

        highlight.FillTransparency =
            state.ChamsFillTransparency

        highlight.OutlineTransparency =
            state.ChamsOutlineTransparency

        return highlight
    end

    local function refreshPersistentHighlights()
        if not state.ESPEnabled
            or not state.Features.Chams then

            for _,
                data in pairs(
                    state.Cache
                ) do

                if data.Highlight then
                    data.Highlight.Enabled =
                        false
                end
            end

            return
        end

        for _,
            player in ipairs(
                Players:GetPlayers()
            ) do

            if player ~= LocalPlayer then
                local data =
                    ensurePlayer(
                        player
                    )

                local character =
                    workspace:
                        FindFirstChild(
                            player.Name
                        )
                    or player.Character

                local highlight =
                    character
                    and ensurePersistentHighlight(
                        player,
                        data,
                        character
                    )
                    or data.Highlight

                if highlight then
                    local _,
                        statusColor =
                            character
                            and getESPStatusColor(
                                player,
                                character
                            )
                            or false,
                                state.ChamsColor

                    highlight.DepthMode =
                        Enum.HighlightDepthMode.AlwaysOnTop

                    highlight.Enabled =
                        character ~= nil
                        and isPlayerInPlay(
                            player
                        )

                    highlight.FillColor =
                        state.ESPVisibilityColors
                        and statusColor
                        or state.ChamsColor
                end
            end
        end
    end

    local function refreshInPlayRoster()
        local roster = {}
        local names = {}

        for _,
            player in ipairs(
                Players:GetPlayers()
            ) do

            if isPlayerInPlay(
                player
            ) then

                roster[
                    player
                ] =
                    true

                table.insert(
                    names,
                    player.DisplayName
                        ~= player.Name
                        and (
                            player.DisplayName
                            .. " (@"
                            .. player.Name
                            .. ")"
                        )
                        or player.Name
                )
            end
        end

        table.sort(
            names,
            function(a, b)
                return string.lower(a)
                    < string.lower(b)
            end
        )

        state.InPlay.Players =
            roster

        state.InPlay.LastRefresh =
            os.clock()

        state.InPlay.Dirty =
            false

        local paragraph =
            state.InPlay.Paragraph

        if paragraph
            and type(paragraph.Set)
                == "function" then

            local content =
                #names > 0
                and table.concat(
                    names,
                    "\n"
                )
                or "No other players currently detected in play."

            pcall(
                paragraph.Set,
                paragraph,
                {
                    Title =
                        "Players In Play ("
                        .. tostring(
                            #names
                        )
                        .. ")",
                    Content =
                        content,
                }
            )
        end

        refreshPersistentHighlights()

        return roster
    end

    local function markInPlayDirty()
        state.InPlay.Dirty =
            true

        task.defer(function()
            if state.Alive
                and state.InPlay.Dirty then

                refreshInPlayRoster()
            end
        end)
    end

    local function destroyPlayer(player)
        local data = state.Cache[player]
        if not data then return end
        for _, object in pairs(data) do
            if typeof(object) == "Instance" then
                pcall(function() object:Destroy() end)
            elseif type(object) == "table" then
                for _, child in pairs(object) do
                    if typeof(child) == "Instance" then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
        state.Cache[player] = nil
    end

    local function ensurePlayer(player)
        local data = state.Cache[player]
        if data then return data end

        data = {
            Billboard = nil,
            NameLabel = nil,
            DistanceLabel = nil,
            Highlight = nil,
            Box = {newLine("BoxTop"), newLine("BoxBottom"), newLine("BoxLeft"), newLine("BoxRight")},
            Skeleton = {},
            HealthBG = newLine("HealthBG"),
            Health = newLine("Health"),
        }
        for i = 1, #SkeletonPairs do
            data.Skeleton[i] = newLine("Skeleton" .. i)
        end
        state.Cache[player] = data
        return data
    end

    local function ensureBillboard(player, data)
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local root = getRoot(player)
        local adornee = head or root
        if not adornee then return nil end

        if data.Billboard and data.Billboard.Parent and data.Billboard.Adornee == adornee then
            return data.Billboard
        end

        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end

        local gui = Instance.new("BillboardGui")
        gui.Name = "Flick_PlayerESP_Text"
        gui.Adornee = adornee
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.Size = UDim2.fromOffset(360, 70)
        gui.Parent = adornee

        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.Size = UDim2.new(1,0,0.5,0)
        name.TextXAlignment = Enum.TextXAlignment.Center
        name.Parent = gui

        local distance = Instance.new("TextLabel")
        distance.BackgroundTransparency = 1
        distance.Position = UDim2.fromScale(0,0.5)
        distance.Size = UDim2.new(1,0,0.5,0)
        distance.TextXAlignment = Enum.TextXAlignment.Center
        distance.Parent = gui

        data.Billboard = gui
        data.NameLabel = name
        data.DistanceLabel = distance
        return gui
    end

    local function hideScreen(data)
        for _, line in ipairs(data.Box) do line.Visible = false end
        for _, line in ipairs(data.Skeleton) do line.Visible = false end
        data.HealthBG.Visible = false
        data.Health.Visible = false
    end

    local function updatePlayer(player)
        local data = ensurePlayer(player)

        if not state.ESPEnabled then
            hideScreen(
                data
            )

            if data.Billboard then
                data.Billboard.Enabled =
                    false
            end

            if data.Highlight then
                data.Highlight.Enabled =
                    false
            end

            return
        end

        if not shouldShow(player) then
            hideScreen(data)

            if data.Billboard then
                data.Billboard.Enabled =
                    false
            end

            if state.Features.Chams then
                local character =
                    workspace:
                        FindFirstChild(
                            player.Name
                        )
                    or player.Character

                local highlight =
                    character
                    and ensurePersistentHighlight(
                        player,
                        data,
                        character
                    )
                    or data.Highlight

                if highlight then
                    local _,
                        statusColor =
                            character
                            and getESPStatusColor(
                                player,
                                character
                            )
                            or false,
                                state.ChamsColor

                    highlight.DepthMode =
                        Enum.HighlightDepthMode.AlwaysOnTop

                    highlight.Enabled =
                        character ~= nil
                        and isPlayerInPlay(
                            player
                        )

                    highlight.FillColor =
                        state.ESPVisibilityColors
                        and statusColor
                        or state.ChamsColor
                end
            elseif data.Highlight then
                data.Highlight.Enabled =
                    false
            end

            return
        end

        local character =
            getWorkspacePlayerModel(
                player
            )
            or player.Character

        local humanoid =
            getHumanoid(
                player
            )

        local currentHealth,
            maxHealth =
                getPlayerHealthState(
                    player
                )

        local distance =
            getDistance(
                player
            )

        local bounds =
            screenBounds(
                character
            )

        local espVisible,
            espStatusColor =
                getESPStatusColor(
                    player,
                    character
                )

        local statusColor =
            state.ESPVisibilityColors
            and espStatusColor
            or nil

        -- Visibility Check hides normal ESP overlays behind geometry.
        -- Highlight Chams are intentionally excluded so they remain
        -- visible through walls.
        local hideOccludedESP =
            state.ESPVisibleCheck
            and not espVisible

        -- Name + distance text
        local billboard = ensureBillboard(player, data)
        if billboard then
            billboard.Enabled =
                not hideOccludedESP
                and (
                    state.Features.Name
                    or state.Features.Distance
                )
            billboard.MaxDistance = state.MaxDistance
            billboard.StudsOffsetWorldSpace = Vector3.new(0, state.TextHeight, 0)

            local size = scaledTextSize(distance)
            data.NameLabel.Visible =
                state.Features.Name
                and not hideOccludedESP
            data.NameLabel.Text = getName(player)
            data.NameLabel.Font = state.TextFont
            data.NameLabel.TextSize = size
            data.NameLabel.TextColor3 =
                statusColor
                or activeColor(
                    "Name Text"
                )
            data.NameLabel.TextStrokeColor3 = activeColor("Name Outline")
            data.NameLabel.TextStrokeTransparency = state.TextOutline and 0 or 1

            data.DistanceLabel.Visible =
                state.Features.Distance
                and not hideOccludedESP
            data.DistanceLabel.Text = distance and string.format("[%d studs]", math.floor(distance + 0.5)) or ""
            data.DistanceLabel.Font = state.TextFont
            data.DistanceLabel.TextSize = math.max(state.MinTextSize, size - 2)
            data.DistanceLabel.TextColor3 =
                statusColor
                or activeColor(
                    "Distance Text"
                )
            data.DistanceLabel.TextStrokeColor3 = activeColor("Name Outline")
            data.DistanceLabel.TextStrokeTransparency = state.TextOutline and 0 or 1
        end

        -- Plain player Highlight chams; no health dependency.
        if state.Features.Chams and character then
            local highlight =
                ensurePersistentHighlight(
                    player,
                    data,
                    character
                )

            if highlight then
                highlight.DepthMode =
                    Enum.HighlightDepthMode.AlwaysOnTop

                highlight.Enabled =
                    isPlayerInPlay(
                        player
                    )

                highlight.FillColor =
                    statusColor
                    or state.ChamsColor
            end
        elseif data.Highlight then
            data.Highlight.Enabled = false
        end

        -- 2D bounding box
        if state.Features.Box
            and bounds
            and not hideOccludedESP then
            local c =
                statusColor
                or activeColor(
                    "Bounding Box"
                )
            local tl = Vector2.new(bounds.Left, bounds.Top)
            local tr = Vector2.new(bounds.Right, bounds.Top)
            local bl = Vector2.new(bounds.Left, bounds.Bottom)
            local br = Vector2.new(bounds.Right, bounds.Bottom)
            setLine(data.Box[1], tl, tr, 1.5, c)
            setLine(data.Box[2], bl, br, 1.5, c)
            setLine(data.Box[3], tl, bl, 1.5, c)
            setLine(data.Box[4], tr, br, 1.5, c)
        else
            for _, line in ipairs(data.Box) do line.Visible = false end
        end

        -- Skeleton
        if state.Features.Skeleton
            and character
            and not hideOccludedESP then
            local c =
                statusColor
                or activeColor(
                    "Skeleton"
                )
            for i, pair in ipairs(SkeletonPairs) do
                local aPart = character:FindFirstChild(pair[1])
                local bPart = character:FindFirstChild(pair[2])
                local line = data.Skeleton[i]
                if aPart and bPart and aPart:IsA("BasePart") and bPart:IsA("BasePart") then
                    local a, av = project(aPart.Position)
                    local b, bv = project(bPart.Position)
                    if a and b and (av or bv) then
                        setLine(line, a, b, 1.5, c)
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, line in ipairs(data.Skeleton) do line.Visible = false end
        end

        -- Health bar uses the same workspace.<Username>.Health source.
        if state.Features.HealthBar
            and not hideOccludedESP
            and bounds
            and currentHealth
            and maxHealth then

            local ratio =
                maxHealth > 0
                and math.clamp(
                    currentHealth
                        / maxHealth,
                    0,
                    1
                )
                or 0

            local color =
                healthColor(
                    "Health",
                    ratio
                )

            local bg =
                activeColor(
                    "Health Background"
                )

            if state.HealthBarPosition == "Above Player" then
                local y = bounds.Top - 7
                local a = Vector2.new(bounds.Left, y)
                local b = Vector2.new(bounds.Right, y)
                local fillB = Vector2.new(bounds.Left + bounds.Width * ratio, y)
                setLine(data.HealthBG, a, b, 4, bg)
                setLine(data.Health, a, fillB, 3, color)
            else
                local x = bounds.Left - 7
                local top = Vector2.new(x, bounds.Top)
                local bottom = Vector2.new(x, bounds.Bottom)
                local fillTop = Vector2.new(x, bounds.Bottom - bounds.Height * ratio)
                setLine(data.HealthBG, top, bottom, 4, bg)
                setLine(data.Health, fillTop, bottom, 3, color)
            end
        else
            data.HealthBG.Visible = false
            data.Health.Visible = false
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then ensurePlayer(player) end
    end

    track(Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then ensurePlayer(player) end
    end))

    track(
        Players.PlayerRemoving:
            Connect(function(
                player
            )
                destroyPlayer(
                    player
                )

                state.InPlay.Players[
                    player
                ] =
                    nil

                markInPlayDirty()
            end)
    )

    track(
        Players.PlayerAdded:
            Connect(function(
                player
            )
                track(
                    player.CharacterAdded:
                        Connect(function()
                            markInPlayDirty()
                        end)
                )

                markInPlayDirty()
            end)
    )

    for _,
        player in ipairs(
            Players:GetPlayers()
        ) do

        if player ~= LocalPlayer then
            track(
                player.CharacterAdded:
                    Connect(function()
                        markInPlayDirty()
                    end)
            )
        end
    end

    local signalManager =
        ReplicatedStorage:
            FindFirstChild(
                "SignalManager"
            )

    local signalEvents =
        signalManager
        and signalManager:
            FindFirstChild(
                "SignalEvents"
            )

    local playerInPlaySignal =
        signalEvents
        and signalEvents:
            FindFirstChild(
                "PlayerInPlay"
            )

    if playerInPlaySignal
        and playerInPlaySignal:IsA(
            "BindableEvent"
        ) then

        state.InPlay.Event =
            playerInPlaySignal

        track(
            playerInPlaySignal.Event:
                Connect(function()
                    -- No player argument is emitted in the capture, so treat
                    -- this as a lifecycle invalidation signal and rebuild the
                    -- roster from live Player/workspace state.
                    markInPlayDirty()
                end)
        )
    end

    refreshInPlayRoster()

    -- One render connection handles all screen-space Player ESP.
    track(RunService.RenderStepped:Connect(function(deltaTime)
        if not state.Alive then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                updatePlayer(player)
            end
        end

        if state.InPlay.Dirty
            or os.clock()
                - state.InPlay.LastRefresh
                >= 1.0 then

            refreshInPlayRoster()
        end

        updateThreatAwareness()
        updateAimbot(deltaTime)
        updateTriggerbot()

        if type(
            state.Combat.UpdateFOVCircle
        ) == "function" then

            state.Combat.UpdateFOVCircle()
        end
    end))

    -- ============================================================
    -- CURSOR / MOUSE-LOCK CONTROL
    -- ============================================================

    local function getLiveMouseLockController()
        local playerScripts =
            LocalPlayer:
                FindFirstChild(
                    "PlayerScripts"
                )

        local playerModuleScript =
            playerScripts
            and playerScripts:
                FindFirstChild(
                    "PlayerModule"
                )

        if not playerModuleScript then
            return nil
        end

        local ok,
            playerModule =
                pcall(
                    require,
                    playerModuleScript
                )

        if not ok
            or type(playerModule)
                ~= "table" then

            return nil
        end

        local cameras =
            nil

        if type(
            playerModule.GetCameras
        ) == "function" then

            local cameraOk,
                value =
                    pcall(
                        playerModule.GetCameras,
                        playerModule
                    )

            if cameraOk then
                cameras =
                    value
            end
        end

        cameras =
            cameras
            or rawget(
                playerModule,
                "cameras"
            )

        if type(cameras)
            ~= "table" then

            return nil
        end

        local controller =
            rawget(
                cameras,
                "activeMouseLockController"
            )
            or rawget(
                cameras,
                "mouseLockController"
            )

        if not controller
            and type(
                cameras.GetMouseLockController
            ) == "function" then

            local controllerOk,
                value =
                    pcall(
                        cameras.GetMouseLockController,
                        cameras
                    )

            if controllerOk then
                controller =
                    value
            end
        end

        return controller
    end

    local function setCursorUnlocked(
        enabled
    )
        enabled =
            enabled == true

        state.CursorUnlock.Enabled =
            enabled

        pcall(
            RunService.UnbindFromRenderStep,
            RunService,
            state.CursorUnlock.RenderStepName
        )

        if enabled then
            local controller =
                getLiveMouseLockController()

            state.CursorUnlock.Controller =
                controller

            if controller then
                state.CursorUnlock.ControllerWasEnabled =
                    controller.enabled == true

                if type(
                    controller.EnableMouseLock
                ) == "function" then

                    pcall(
                        controller.EnableMouseLock,
                        controller,
                        false
                    )
                end
            end

            pcall(function()
                UserInputService.MouseBehavior =
                    Enum.MouseBehavior.Default

                UserInputService.MouseIconEnabled =
                    true
            end)

            -- PlayerModule may set LockCenter again during the camera step.
            -- Run immediately after Camera so the cursor remains free.
            RunService:
                BindToRenderStep(
                    state.CursorUnlock.RenderStepName,
                    Enum.RenderPriority.Camera.Value
                        + 5,
                    function()
                        if not state.Alive
                            or not state.CursorUnlock.Enabled then

                            return
                        end

                        UserInputService.MouseBehavior =
                            Enum.MouseBehavior.Default

                        UserInputService.MouseIconEnabled =
                            true
                    end
                )
        else
            local controller =
                state.CursorUnlock.Controller

            if controller
                and state.CursorUnlock.ControllerWasEnabled
                and type(
                    controller.EnableMouseLock
                ) == "function" then

                pcall(
                    controller.EnableMouseLock,
                    controller,
                    true
                )
            end

            state.CursorUnlock.Controller =
                nil

            state.CursorUnlock.ControllerWasEnabled =
                nil

            pcall(function()
                UserInputService.MouseBehavior =
                    Enum.MouseBehavior.Default

                UserInputService.MouseIconEnabled =
                    true
            end)
        end
    end

    -- ============================================================
    -- UI — same overall organization/customization pattern as Tower
    -- ============================================================

    local function bindGunRefreshContainer(
        container
    )
        if not container then
            return
        end

        track(
            container.ChildAdded:
                Connect(function(
                    object
                )
                    if object:IsA(
                        "Tool"
                    ) then

                        scheduleGunConfigRefresh(
                            0.20
                        )

                        task.delay(
                            0.22,
                            function()
                                if state.Alive then
                                    refreshMeleeConfigs()
                                end
                            end
                        )
                    end
                end)
        )
    end

    bindGunRefreshContainer(
        LocalPlayer:
            FindFirstChild(
                "Backpack"
            )
    )

    bindGunRefreshContainer(
        LocalPlayer.Character
    )

    track(
        LocalPlayer.CharacterAdded:
            Connect(function(
                character
            )
                bindGunRefreshContainer(
                    character
                )

                scheduleGunConfigRefresh(
                    0.35
                )

            end)
    )

    local MainTab = Window:CreateTab("Main", "house")
    local PlayerVisualsTab = Window:CreateTab("Player ESP", "eye")
    local CombatTab = Window:CreateTab("Combat", "target")
    local KnifeTab = Window:CreateTab("Knife", "sword")

    local MainSection = MainTab:CreateSection({
        Name = "Flick",
        Description = "Flick combat, player ESP, threat awareness, gun mods, and knife controls.",
        Side = "Left",
    })

    MainSection:CreateStatus({
        Name = "Module",
        CurrentValue = "Flick Combat Suite v2.9.0",
    })

    local ControlsSection =
        MainTab:CreateSection({
            Name = "Controls",
            Description = "PlayerModule / mouse-lock controls.",
            Side = "Right",
        })

    local UnlockCursorToggle

    UnlockCursorToggle =
        MainTab:CreateToggle({
            Name = "Unlock Cursor",
            Flag = "Flick_UnlockCursor",
            Info = "Disables the live MouseLockController while enabled and forces MouseBehavior back to Default after the camera step. Press T to toggle.",
            CurrentValue = false,
            SectionParent = ControlsSection._Section,
            Callback = function(value)
                setCursorUnlocked(
                    value == true
                )
            end,
        })

    MainTab:CreateParagraph({
        Title = "Unlock Hotkey",
        Content = "Press T to toggle Unlock Cursor. Text-box input is ignored.",
        SectionParent = ControlsSection._Section,
    })

    track(
        UserInputService.InputBegan:
            Connect(function(
                input,
                gameProcessed
            )
                if gameProcessed
                    or UserInputService:
                        GetFocusedTextBox() then

                    return
                end

                if input.KeyCode
                    ~= Enum.KeyCode.T then

                    return
                end

                local nextValue =
                    not state.CursorUnlock.Enabled

                if UnlockCursorToggle
                    and type(
                        UnlockCursorToggle.Set
                    ) == "function" then

                    UnlockCursorToggle:Set(
                        nextValue,
                        true
                    )
                else
                    setCursorUnlocked(
                        nextValue
                    )
                end
            end)
    )

    local SilentAimSection =
        CombatTab:CreateSection({
            Name = "Silent Aim",
            Description = "Redirect Flick's real outgoing bullet/check-shot data toward the best target while preserving normal fire.",
            Side = "Left",
        })

    SilentAimSection:CreateToggle({
        Name = "Silent Aim",
        Flag = "Flick_SilentAim",
        Info = "Does not auto-fire. Rewrites BulletHandler payload.Direction before Flick performs its normal network/raycast flow. No namecall/remote interception.",
        CurrentValue = false,
        Callback = function(value)
            state.Combat.SilentAimEnabled =
                value == true

            if state.Combat.SilentAimEnabled
                and not state.Combat.BulletPatchInstalled then

                installSilentAimRouter()
            end
        end,
    })

    SilentAimSection:CreateDropdown({
        Name = "Target Part",
        Flag = "Flick_SilentAim_TargetPart",
        Options = {
            "Head",
            "HumanoidRootPart",
        },
        CurrentOption = "Head",
        MultiSelection = false,
        Callback = function(value)
            local selected =
                dropdownValue(
                    value
                )

            if selected then
                state.Combat.TargetPart =
                    selected
            end
        end,
    })

    SilentAimSection:CreateToggle({
        Name = "FOV Check",
        Flag = "Flick_SilentAim_UseFOV",
        CurrentValue = true,
        Callback = function(value)
            state.Combat.UseFOV =
                value == true
        end,
    })

    SilentAimSection:CreateToggle({
        Name = "Show FOV Circle",
        Flag = "Flick_SilentAim_ShowFOV",
        CurrentValue = true,
        Callback = function(value)
            state.Combat.ShowFOVCircle =
                value == true

            updateFOVCircle()
        end,
    })

    SilentAimSection:CreateSlider({
        Name = "FOV Radius",
        Flag = "Flick_SilentAim_FOV",
        Range = {25, 600},
        Increment = 5,
        Suffix = " px",
        CurrentValue = 175,
        Callback = function(value)
            state.Combat.FOVRadius =
                tonumber(value)
                or 175
        end,
    })

    SilentAimSection:CreateToggle({
        Name = "Visible Check",
        Flag = "Flick_SilentAim_Visible",
        Info = "Require an unobstructed ray from the shot/camera origin to the target.",
        CurrentValue = false,
        Callback = function(value)
            state.Combat.VisibleCheck =
                value == true
        end,
    })

    local TriggerbotSection =
        CombatTab:CreateSection({
            Name = "Triggerbot",
            Description = "Automatically clicks only while the crosshair is actually over a valid enemy character. Uses the normal gun/input path; Silent Aim is optional.",
            Side = "Left",
        })

    TriggerbotSection:CreateToggle({
        Name = "Triggerbot",
        Flag = "Flick_Triggerbot_Enabled",
        Info = "Fires when the center crosshair/aim point raycasts into a valid enemy. Team Check and Max Distance are inherited from Player ESP/combat filtering.",
        CurrentValue = false,
        Callback = function(value)
            state.Combat.TriggerbotEnabled =
                value == true

            state.Combat.TriggerbotGeneration += 1
            state.Combat.TriggerbotPending = false
            state.Combat.TriggerbotLastScan = 0
        end,
    })

    TriggerbotSection:CreateSlider({
        Name = "Trigger Radius",
        Flag = "Flick_Triggerbot_Radius",
        Info = "Adds a small screen-space tolerance around the crosshair. 0 px is an exact center ray.",
        Range = {0, 30},
        Increment = 1,
        Suffix = " px",
        CurrentValue = 8,
        Callback = function(value)
            state.Combat.TriggerbotRadius =
                tonumber(value)
                or 8
        end,
    })

    TriggerbotSection:CreateSlider({
        Name = "Fire Delay",
        Flag = "Flick_Triggerbot_Delay",
        Info = "Delay between acquiring the target and clicking. The target is checked again before the shot.",
        Range = {0, 0.25},
        Increment = 0.01,
        Suffix = " s",
        CurrentValue = 0.02,
        Callback = function(value)
            state.Combat.TriggerbotDelay =
                tonumber(value)
                or 0.02
        end,
    })

    TriggerbotSection:CreateSlider({
        Name = "Shot Cooldown",
        Flag = "Flick_Triggerbot_Cooldown",
        Info = "Minimum time between automatic trigger clicks. The game's own fire-rate/ammo logic still applies.",
        Range = {0.03, 0.50},
        Increment = 0.01,
        Suffix = " s",
        CurrentValue = 0.10,
        Callback = function(value)
            state.Combat.TriggerbotCooldown =
                tonumber(value)
                or 0.10
        end,
    })

    TriggerbotSection:CreateParagraph({
        Title = "Trigger Method",
        Content = "Checks the real camera/cursor ray against live player character parts. It will not deliberately trigger through walls because the world ray must hit the player first.",
    })

    local AimbotSection =
        CombatTab:CreateSection({
            Name = "Aimbot",
            Description = "Smoothly rotates the real camera toward the best valid target. Uses the same target part, FOV, visibility, team, and max-distance rules as the combat system.",
            Side = "Right",
        })

    AimbotSection:CreateToggle({
        Name = "Aimbot",
        Flag = "Flick_Aimbot_Enabled",
        Info = "Camera-based aim assist. By default it only engages while Right Mouse Button is held; it does not require Silent Aim.",
        CurrentValue = false,
        Callback = function(value)
            state.Combat.AimbotEnabled =
                value == true

            if not state.Combat.AimbotEnabled then
                state.Combat.AimbotTarget = nil
            end
        end,
    })

    AimbotSection:CreateToggle({
        Name = "Always Active",
        Flag = "Flick_Aimbot_Always",
        Info = "When disabled, hold Right Mouse Button to engage the aimbot. When enabled, it aims whenever a valid target is available.",
        CurrentValue = false,
        Callback = function(value)
            state.Combat.AimbotAlwaysActive =
                value == true

            if not state.Combat.AimbotAlwaysActive then
                state.Combat.AimbotTarget = nil
            end
        end,
    })

    AimbotSection:CreateSlider({
        Name = "Aim Speed",
        Flag = "Flick_Aimbot_Speed",
        Info = "Higher values pull the camera onto the target faster. Lower values look smoother and more gradual.",
        Range = {1, 40},
        Increment = 1,
        Suffix = "x",
        CurrentValue = 14,
        Callback = function(value)
            state.Combat.AimbotSmoothing =
                tonumber(value)
                or 14
        end,
    })

    AimbotSection:CreateToggle({
        Name = "Sticky Target",
        Flag = "Flick_Aimbot_Sticky",
        Info = "Keeps the current valid target with a small FOV retention margin instead of constantly switching to whichever player is one pixel closer.",
        CurrentValue = true,
        Callback = function(value)
            state.Combat.AimbotStickyTarget =
                value == true

            if not state.Combat.AimbotStickyTarget then
                state.Combat.AimbotTarget = nil
            end
        end,
    })

    AimbotSection:CreateToggle({
        Name = "Use Prediction",
        Flag = "Flick_Aimbot_Prediction",
        Info = "Leads the camera using the equipped gun's BulletForce/Gravity and the shared Movement Prediction settings below.",
        CurrentValue = false,
        Callback = function(value)
            state.Combat.AimbotUsePrediction =
                value == true
        end,
    })

    AimbotSection:CreateParagraph({
        Title = "Activation / Shared Filters",
        Content = "Default activation is hold RMB. Target Part, FOV Check/Radius, Visible Check, Team Check, Max Distance, and Movement Prediction are shared with the existing combat controls so Aimbot, Triggerbot, and Silent Aim stay consistent.",
    })

    local PredictionSection =
        CombatTab:CreateSection({
            Name = "Prediction",
            Description = "Prediction uses Flick's real BulletHandler input and Projectile.Cast ballistic speed formula.",
            Side = "Right",
        })

    PredictionSection:CreateToggle({
        Name = "Movement Prediction",
        Flag = "Flick_SilentAim_Prediction",
        CurrentValue = true,
        Callback = function(value)
            state.Combat.PredictionEnabled =
                value == true
        end,
    })

    PredictionSection:CreateSlider({
        Name = "Extra Prediction Lead",
        Flag = "Flick_SilentAim_Lead",
        Range = {0, 0.20},
        Increment = 0.01,
        Suffix = "s",
        CurrentValue = 0.03,
        Callback = function(value)
            state.Combat.PredictionLead =
                tonumber(value)
                or 0.03
        end,
    })

    PredictionSection:CreateParagraph({
        Title = "Ballistics",
        Content = "Uses Flick's real projectile formula: speed = BulletForce × 20.2244897959. Force 130 is approximately 2629 studs/s before gravity.",
    })

    local GunModsSection =
        CombatTab:CreateSection({
            Name = "Gun Mods",
            Description = "Edits Flick's live GunFramework config table. Rapid Fire is rate-limited to reduce server-side Suspicious Activity triggers.",
            Side = "Right",
        })

    GunModsSection:CreateToggle({
        Name = "Instant Reload",
        Flag = "Flick_GunMods_InstantReload",
        Info = "Sets the live GunFramework reloadTime to 0. Normal reload input still controls when reload happens; only the timer is removed.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.InstantReload =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateToggle({
        Name = "No Spread",
        Flag = "Flick_GunMods_NoSpread",
        Info = "Sets the live spread value to 0 before Flick builds projectile Direction.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.NoSpread =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateToggle({
        Name = "No Recoil",
        Flag = "Flick_GunMods_NoRecoil",
        Info = "Sets Flick's live Recoil vector to Vector3.zero.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.NoRecoil =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateToggle({
        Name = "Force Full Auto",
        Flag = "Flick_GunMods_FullAuto",
        Info = "Sets the live isAuto field true so holding fire can continue the firing state machine.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.FullAuto =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateToggle({
        Name = "Safe Rapid Fire",
        Flag = "Flick_GunMods_SafeRapidFire",
        Info = "Speeds the weapon up only relative to its ORIGINAL FireRate. Avoids the extreme 0.04s cadence that triggered Suspicious Activity.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.RapidFire =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateSlider({
        Name = "Rapid Fire Multiplier",
        Flag = "Flick_GunMods_RapidFireMultiplier",
        Info = "Conservative speed-up. v1.6 hard-caps the effective cadence to no more than 10% faster than the weapon's original FireRate.",
        Range = {1.00, 1.10},
        Increment = 0.01,
        Suffix = "x",
        CurrentValue = 1.05,
        Callback = function(value)
            state.GunMods.RapidFireMultiplier =
                math.clamp(
                    tonumber(value)
                        or 1.05,
                    1,
                    1.10
                )

            if state.GunMods.RapidFire then
                refreshGunConfigs()
            end
        end,
    })

    GunModsSection:CreateParagraph({
        Title = "Rapid Fire Safety",
        Content = "Flick sends CheckFire once per real shot using tick(). The supplied GunFramework has no local Suspicious Activity/Kick path, so this is most likely server-side rate validation. v1.6 leaves CheckFire untouched and only applies a small relative speed increase.",
    })

    GunModsSection:CreateToggle({
        Name = "No Bullet Gravity",
        Flag = "Flick_GunMods_NoGravity",
        Info = "Sets the live projectile Gravity field to 0.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.NoGravity =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateToggle({
        Name = "Bullet Force Override",
        Flag = "Flick_GunMods_BulletForceEnabled",
        Info = "Multiplies Flick's BulletForce. Higher force means higher projectile speed; server checks may reject extreme values.",
        CurrentValue = false,
        Callback = function(value)
            state.GunMods.BulletForceEnabled =
                value == true

            refreshGunConfigs()
        end,
    })

    GunModsSection:CreateSlider({
        Name = "Bullet Force Multiplier",
        Flag = "Flick_GunMods_BulletForceMultiplier",
        Range = {0.5, 3},
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = 1,
        Callback = function(value)
            state.GunMods.BulletForceMultiplier =
                tonumber(value)
                or 1

            if state.GunMods.BulletForceEnabled then
                refreshGunConfigs()
            end
        end,
    })

    GunModsSection:CreateButton({
        Name = "Show Fire Rate",
        Interact = "Inspect",
        Callback = function()
            refreshGunConfigs()

            local foundBase =
                nil

            local foundEffective =
                nil

            for config,
                original in pairs(
                    state.GunMods.ConfigOriginals
                ) do

                if isGunConfigTable(config)
                    and type(original)
                        == "table" then

                    foundBase =
                        tonumber(
                            original.FireRate
                        )

                    foundEffective =
                        tonumber(
                            config.FireRate
                        )

                    if foundBase then
                        break
                    end
                end
            end

            if foundBase then
                Window:Notify({
                    Title = "Flick Fire Rate",
                    Content = string.format(
                        "Original: %.3fs | Effective: %.3fs | Speed: %.2fx",
                        foundBase,
                        foundEffective
                            or foundBase,
                        foundBase
                            / math.max(
                                foundEffective
                                    or foundBase,
                                0.001
                            )
                    ),
                    Duration = 4,
                })
            else
                Window:Notify({
                    Title = "Flick Fire Rate",
                    Content = "No live gun config found. Equip a weapon and press Refresh Gun Config.",
                    Duration = 3,
                })
            end
        end,
    })

    GunModsSection:CreateButton({
        Name = "Refresh Gun Config",
        Interact = "Scan",
        Callback = function()
            local count =
                refreshGunConfigs()

            Window:Notify({
                Title = "Flick Gun Mods",
                Content =
                    count > 0
                    and (
                        "Found and updated "
                        .. tostring(
                            count
                        )
                        .. " live gun config"
                        .. (
                            count == 1
                            and "."
                            or "s."
                        )
                    )
                    or "No live equipped GunFramework config was found. Equip a gun and try again.",
                Duration = 3,
            })
        end,
    })

    local KnifeSection = KnifeTab:CreateSection({
        Name = "Knife Mods",
        Description = "Live MeleeFramework values from the equipped knife.",
        Side = "Left",
    })

    KnifeSection:CreateToggle({
        Name = "No Swing Recoil", Flag = "Flick_Knife_NoSwingRecoil",
        CurrentValue = false,
        Callback = function(v)
            state.MeleeMods.NoSwingRecoil = v == true
            refreshMeleeConfigs()
        end,
    })

    KnifeSection:CreateToggle({
        Name = "Fast Swing", Flag = "Flick_Knife_FastSwing",
        CurrentValue = false,
        Callback = function(v)
            state.MeleeMods.FastSwing = v == true
            refreshMeleeConfigs()
        end,
    })

    KnifeSection:CreateSlider({
        Name = "Swing Speed", Flag = "Flick_Knife_SwingSpeed",
        Range = {1,2}, Increment = 0.05, Suffix = "x", CurrentValue = 1,
        Callback = function(v)
            state.MeleeMods.SwingSpeed = tonumber(v) or 1
            if state.MeleeMods.FastSwing then refreshMeleeConfigs() end
        end,
    })

    KnifeSection:CreateToggle({
        Name = "Instant Equip", Flag = "Flick_Knife_InstantEquip",
        CurrentValue = false,
        Callback = function(v)
            state.MeleeMods.InstantEquip = v == true
            refreshMeleeConfigs()
        end,
    })

    local KnifeUtility =
        KnifeTab:CreateSection({
            Name = "Knife Utility",
            Description = "Non-reach melee framework controls.",
            Side = "Right",
        })

    KnifeUtility:CreateToggle({
        Name = "Speed Boost Override",
        Flag = "Flick_Knife_SpeedBoostOverride",
        CurrentValue = false,
        Callback = function(v)
            state.MeleeMods.SpeedBoostOverride =
                v == true

            refreshMeleeConfigs()
        end,
    })

    KnifeUtility:CreateSlider({
        Name = "Knife Speed Boost",
        Flag = "Flick_Knife_SpeedBoost",
        Range = {0,20},
        Increment = 1,
        CurrentValue = 4,
        Callback = function(v)
            state.MeleeMods.SpeedBoost =
                tonumber(v)
                or 4

            if state.MeleeMods.SpeedBoostOverride then
                refreshMeleeConfigs()
            end
        end,
    })

    KnifeUtility:CreateButton({
        Name = "Refresh Knife Config",
        Interact = "Scan",
        Callback = function()
            local count =
                refreshMeleeConfigs()

            Window:Notify({
                Title = "Flick Knife Mods",
                Content = count > 0
                    and (
                        "Found "
                        .. tostring(count)
                        .. " live melee config"
                        .. (
                            count == 1
                            and "."
                            or "s."
                        )
                    )
                    or "No live melee config found. Equip the knife and try again.",
                Duration = 3,
            })
        end,
    })

    -- ============================================================
    -- PLAYER ESP UI — ORGANIZED
    -- ============================================================

    -- TOP / LEFT: master switch + individual feature selection.
    local ESPFeatures =
        PlayerVisualsTab:CreateSection({
            Name = "ESP Features",
            Description = "Master ESP switch and individual player overlays.",
            Side = "Left",
        })

    PlayerVisualsTab:CreateToggle({
        Name = "ESP Enabled",
        Flag = "Flick_PlayerESP_Enabled_v281",
        Info = "Master switch for all player ESP.",
        CurrentValue = true,
        SectionParent = ESPFeatures._Section,
        Callback = function(value)
            state.ESPEnabled =
                value == true
        end,
    })

    PlayerVisualsTab:CreateDropdown({
        Name = "ESP Features",
        Flag = "Flick_PlayerESP_Features",
        Info = "Choose which overlays are active while ESP is enabled.",
        Options = {
            "Name ESP",
            "Distance ESP",
            "Highlight Chams",
            "Health Bar ESP",
            "Skeleton ESP",
            "Bounding Box ESP",
        },
        CurrentOption = {},
        MultiSelection = true,
        SectionParent = ESPFeatures._Section,
        Callback = function(selection)
            state.Features.Name =
                selectionHas(
                    selection,
                    "Name ESP"
                )

            state.Features.Distance =
                selectionHas(
                    selection,
                    "Distance ESP"
                )

            state.Features.HealthBar =
                selectionHas(
                    selection,
                    "Health Bar ESP"
                )

            state.Features.Chams =
                selectionHas(
                    selection,
                    "Highlight Chams"
                )

            state.Features.Skeleton =
                selectionHas(
                    selection,
                    "Skeleton ESP"
                )

            state.Features.Box =
                selectionHas(
                    selection,
                    "Bounding Box ESP"
                )
        end,
    })

    -- TOP / RIGHT: filtering and range behavior.
    local ESPFilters =
        PlayerVisualsTab:CreateSection({
            Name = "ESP Filters",
            Description = "Visibility, team, distance, and health-bar filtering.",
            Side = "Right",
        })

    PlayerVisualsTab:CreateToggle({
        Name = "Visibility Check",
        Flag = "Flick_PlayerESP_VisibleCheck_v281",
        Info = "When enabled, text, boxes, skeletons, and health bars only render with direct line of sight. Highlight Chams remain visible through walls.",
        CurrentValue = false,
        SectionParent = ESPFilters._Section,
        Callback = function(value)
            state.ESPVisibleCheck =
                value == true
        end,
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Team Check",
        Flag = "Flick_PlayerESP_TeamCheck",
        CurrentValue = false,
        SectionParent = ESPFilters._Section,
        Callback = function(value)
            state.TeamCheck =
                value == true
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "ESP Max Distance",
        Flag = "Flick_PlayerESP_MaxDistance",
        Range = {50, 3000},
        Increment = 25,
        Suffix = " studs",
        CurrentValue = 1500,
        SectionParent = ESPFilters._Section,
        Callback = function(value)
            state.MaxDistance =
                tonumber(value)
                or 1500
        end,
    })

    PlayerVisualsTab:CreateDropdown({
        Name = "Health Bar Position",
        Flag = "Flick_PlayerESP_HealthBarPosition",
        Options = {
            "Above Player",
            "Left of Player",
        },
        CurrentOption = "Left of Player",
        MultiSelection = false,
        SectionParent = ESPFilters._Section,
        Callback = function(value)
            local selected =
                dropdownValue(
                    value
                )

            if selected then
                state.HealthBarPosition =
                    selected
            end
        end,
    })

    -- RIGHT: directional awareness when another player's facing/LOS
    -- suggests the local player is inside their view.
    local Awareness =
        PlayerVisualsTab:CreateSection({
            Name = "Threat Awareness",
            Description = "Directional warning when another player's replicated facing suggests they can see you.",
            Side = "Right",
        })

    PlayerVisualsTab:CreateToggle({
        Name = "Threat Awareness",
        Flag = "Flick_PlayerESP_ThreatAwareness_v282",
        Info = "Shows a pulsing red edge arrow toward players who appear to be looking at you. Uses character/head facing because other players' exact camera CFrame is not replicated.",
        CurrentValue = false,
        SectionParent = Awareness._Section,
        Callback = function(value)
            state.Awareness.Enabled =
                value == true

            if not state.Awareness.Enabled then
                hideThreatIndicators()
            end
        end,
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Require Threat LOS",
        Flag = "Flick_PlayerESP_ThreatLOS_v282",
        Info = "Require a clear ray from the other player's head/root to your character before showing the warning.",
        CurrentValue = true,
        SectionParent = Awareness._Section,
        Callback = function(value)
            state.Awareness.RequireLineOfSight =
                value == true
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Threat View Cone",
        Flag = "Flick_PlayerESP_ThreatCone_v282",
        Info = "Approximate full field of view used to decide whether their character is facing you.",
        Range = {60, 170},
        Increment = 5,
        Suffix = "°",
        CurrentValue = 120,
        SectionParent = Awareness._Section,
        Callback = function(value)
            state.Awareness.ViewConeDegrees =
                tonumber(value)
                or 120
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Threat Max Distance",
        Flag = "Flick_PlayerESP_ThreatDistance_v282",
        Range = {100, 3000},
        Increment = 50,
        Suffix = " studs",
        CurrentValue = 1500,
        SectionParent = Awareness._Section,
        Callback = function(value)
            state.Awareness.MaxDistance =
                tonumber(value)
                or 1500
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Threat Indicator Distance",
        Flag = "Flick_PlayerESP_ThreatIndicatorRadius_v284",
        Info = "Distance of the warning arrow from the screen center. 175 px roughly matches the default FOV-circle radius.",
        Range = {60, 500},
        Increment = 5,
        Suffix = " px",
        CurrentValue = 175,
        SectionParent = Awareness._Section,
        Callback = function(value)
            state.Awareness.IndicatorRadius =
                tonumber(value)
                or 175
        end,
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Threat Indicator Color",
        Flag = "Flick_PlayerESP_ThreatColor_v282",
        Color = state.Awareness.IndicatorColor,
        SectionParent = Awareness._Section,
        Callback = function(color)
            state.Awareness.IndicatorColor =
                color
        end,
    })

    PlayerVisualsTab:CreateParagraph({
        Title = "Awareness Method",
        Content = "The warning is an estimate: Flick does not expose another player's exact camera orientation to your client. The script uses their replicated Head/Root facing + optional line of sight.",
        SectionParent = Awareness._Section,
    })

    -- LEFT: text appearance.
    local Text =
        PlayerVisualsTab:CreateSection({
            Name = "Text",
            Description = "Name and distance text appearance.",
            Side = "Left",
        })

    PlayerVisualsTab:CreateDropdown({
        Name = "Name Format",
        Flag = "Flick_PlayerESP_NameFormat",
        Options = {
            "Username",
            "Display Name",
            "Display + Username",
        },
        CurrentOption = "Username",
        MultiSelection = false,
        SectionParent = Text._Section,
        Callback = function(value)
            local selected =
                dropdownValue(
                    value
                )

            if selected then
                state.NameFormat =
                    selected
            end
        end,
    })

    local Fonts = {
        ["Gotham Bold"] = Enum.Font.GothamBold,
        ["Gotham"] = Enum.Font.Gotham,
        ["Source Sans Bold"] = Enum.Font.SourceSansBold,
        ["Code"] = Enum.Font.Code,
    }

    PlayerVisualsTab:CreateDropdown({
        Name = "Text Font",
        Flag = "Flick_PlayerESP_Font",
        Options = {
            "Gotham Bold",
            "Gotham",
            "Source Sans Bold",
            "Code",
        },
        CurrentOption = "Gotham Bold",
        MultiSelection = false,
        SectionParent = Text._Section,
        Callback = function(value)
            local selected =
                dropdownValue(
                    value
                )

            if selected
                and Fonts[
                    selected
                ] then

                state.TextFont =
                    Fonts[
                        selected
                    ]
            end
        end,
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Distance Text Scaling",
        Flag = "Flick_PlayerESP_DistanceScaling",
        CurrentValue = true,
        SectionParent = Text._Section,
        Callback = function(value)
            state.DistanceScaling =
                value == true
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Base Text Size",
        Flag = "Flick_PlayerESP_TextSize",
        Range = {10, 32},
        Increment = 1,
        Suffix = " px",
        CurrentValue = 16,
        SectionParent = Text._Section,
        Callback = function(value)
            state.BaseTextSize =
                tonumber(value)
                or 16
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Min Text Size",
        Flag = "Flick_PlayerESP_MinTextSize",
        Range = {6, 20},
        Increment = 1,
        Suffix = " px",
        CurrentValue = 10,
        SectionParent = Text._Section,
        Callback = function(value)
            state.MinTextSize =
                tonumber(value)
                or 10
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Max Text Size",
        Flag = "Flick_PlayerESP_MaxTextSize",
        Range = {12, 40},
        Increment = 1,
        Suffix = " px",
        CurrentValue = 24,
        SectionParent = Text._Section,
        Callback = function(value)
            state.MaxTextSize =
                tonumber(value)
                or 24
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Text Height",
        Flag = "Flick_PlayerESP_TextHeight",
        Range = {1, 8},
        Increment = 0.25,
        Suffix = " studs",
        CurrentValue = 3,
        SectionParent = Text._Section,
        Callback = function(value)
            state.TextHeight =
                tonumber(value)
                or 3
        end,
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Text Outline",
        Flag = "Flick_PlayerESP_TextOutline",
        CurrentValue = true,
        SectionParent = Text._Section,
        Callback = function(value)
            state.TextOutline =
                value == true
        end,
    })

    -- RIGHT: through-wall Highlight chams.
    local Chams =
        PlayerVisualsTab:CreateSection({
            Name = "Highlight Chams",
            Description = "Always-on-top Highlights. These remain visible through walls.",
            Side = "Right",
        })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Chams Color",
        Flag = "Flick_PlayerESP_ChamsColor",
        Color = state.ChamsColor,
        SectionParent = Chams._Section,
        Callback = function(color)
            state.ChamsColor =
                color
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Chams Fill Transparency",
        Flag = "Flick_PlayerESP_ChamsFillTransparency",
        Range = {0, 1},
        Increment = 0.05,
        CurrentValue = 0.50,
        SectionParent = Chams._Section,
        Callback = function(value)
            state.ChamsFillTransparency =
                tonumber(value)
                or 0.50
        end,
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Chams Outline Transparency",
        Flag = "Flick_PlayerESP_ChamsOutlineTransparency",
        Range = {0, 1},
        Increment = 0.05,
        CurrentValue = 0,
        SectionParent = Chams._Section,
        Callback = function(value)
            state.ChamsOutlineTransparency =
                tonumber(value)
                or 0
        end,
    })

    -- LEFT: color behavior and overrides.
    local Colors =
        PlayerVisualsTab:CreateSection({
            Name = "Colors",
            Description = "Visibility colors and optional per-feature overrides.",
            Side = "Left",
        })

    PlayerVisualsTab:CreateToggle({
        Name = "Visibility Colors",
        Flag = "Flick_PlayerESP_VisibilityColors",
        Info = "GREEN when visible and YELLOW when occluded. Highlight Chams can still be seen through walls.",
        CurrentValue = true,
        SectionParent = Colors._Section,
        Callback = function(value)
            state.ESPVisibilityColors =
                value == true
        end,
    })

    PlayerVisualsTab:CreateParagraph({
        Title = "Visibility Legend",
        Content = "GREEN = visible\nYELLOW = occluded",
        SectionParent = Colors._Section,
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Visible Color",
        Flag = "Flick_PlayerESP_VisibleColor",
        Color = state.ESPVisibleColor,
        SectionParent = Colors._Section,
        Callback = function(color)
            state.ESPVisibleColor =
                color
        end,
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Occluded Color",
        Flag = "Flick_PlayerESP_OccludedColor",
        Color = state.ESPOccludedColor,
        SectionParent = Colors._Section,
        Callback = function(color)
            state.ESPOccludedColor =
                color
        end,
    })

    PlayerVisualsTab:CreateDropdown({
        Name = "Custom Color Overrides",
        Flag = "Flick_PlayerESP_ColorOverrides",
        Info = "Check a color to use its picker. Uncheck it to restore the default palette.",
        Options = {
            "Name Text",
            "Name Outline",
            "Distance Text",
            "Health Low",
            "Health Mid",
            "Health High",
            "Health Background",
            "Chams Low",
            "Chams Mid",
            "Chams High",
            "Chams Outline",
            "Skeleton",
            "Bounding Box",
        },
        CurrentOption = {},
        MultiSelection = true,
        SectionParent = Colors._Section,
        Callback = function(value)
            state.ColorOverrides =
                type(value) == "table"
                and value
                or {}
        end,
    })

    local function picker(
        name,
        flag,
        key,
        parent
    )
        PlayerVisualsTab:CreateColorPicker({
            Name = name,
            Flag = flag,
            Color = state.Colors[key],
            SectionParent =
                (parent or Colors)._Section,
            Callback = function(color)
                state.Colors[key] =
                    color
            end,
        })
    end

    picker(
        "Name Text Color",
        "Flick_PlayerESP_NameTextColor",
        "NameText"
    )

    picker(
        "Name Outline Color",
        "Flick_PlayerESP_NameOutlineColor",
        "NameOutline"
    )

    picker(
        "Distance Text Color",
        "Flick_PlayerESP_DistanceTextColor",
        "DistanceText"
    )

    picker(
        "Health Low Color",
        "Flick_PlayerESP_HealthLowColor",
        "HealthLow"
    )

    picker(
        "Health Mid Color",
        "Flick_PlayerESP_HealthMidColor",
        "HealthMid"
    )

    picker(
        "Health High Color",
        "Flick_PlayerESP_HealthHighColor",
        "HealthHigh"
    )

    picker(
        "Health Background Color",
        "Flick_PlayerESP_HealthBackgroundColor",
        "HealthBackground"
    )

    picker(
        "Skeleton Color",
        "Flick_PlayerESP_SkeletonColor",
        "Skeleton"
    )

    picker(
        "Bounding Box Color",
        "Flick_PlayerESP_BoxColor",
        "Box"
    )

    picker(
        "Chams Low Color",
        "Flick_PlayerESP_ChamsLowColor",
        "ChamsLow",
        Chams
    )

    picker(
        "Chams Mid Color",
        "Flick_PlayerESP_ChamsMidColor",
        "ChamsMid",
        Chams
    )

    picker(
        "Chams High Color",
        "Flick_PlayerESP_ChamsHighColor",
        "ChamsHigh",
        Chams
    )

    picker(
        "Chams Outline Color",
        "Flick_PlayerESP_ChamsOutlineColor",
        "ChamsOutline",
        Chams
    )

    -- BOTTOM: roster / diagnostics.
    local InPlaySection =
        PlayerVisualsTab:CreateSection({
            Name = "Players In Play",
            Description = "Live roster rebuilt from Player/workspace state.",
            Side = "Right",
        })

    state.InPlay.Paragraph =
        PlayerVisualsTab:CreateParagraph({
            Title = "Players In Play (0)",
            Content = "Waiting for player state...",
            SectionParent = InPlaySection._Section,
        })

    PlayerVisualsTab:CreateButton({
        Name = "Refresh In-Play Roster",
        Interact = "Refresh",
        SectionParent = InPlaySection._Section,
        Callback = function()
            refreshInPlayRoster()
        end,
    })

    -- ============================================================
    -- CLEANUP / CONFIG RESTORE
    -- ============================================================

    refreshInPlayRoster()

    local function cleanup()
        if not state.Alive then return end

        state.Ready = false

        -- Restore the normal PlayerModule mouse-lock path before shutdown.
        setCursorUnlocked(
            false
        )

        state.Alive = false

        state.Combat.TriggerbotEnabled = false
        state.Combat.TriggerbotGeneration += 1
        state.Combat.TriggerbotPending = false

        state.Combat.AimbotEnabled = false
        state.Combat.AimbotTarget = nil

        for _, connection in ipairs(state.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(state.Connections)

        for player in pairs(state.Cache) do
            destroyPlayer(player)
        end

        pcall(function() overlay:Destroy() end)
        table.clear(
            state.Awareness.Indicators
        )

        if state.Combat.FOVGui then
            pcall(function()
                state.Combat.FOVGui:
                    Destroy()
            end)

            state.Combat.FOVGui =
                nil

            state.Combat.FOVFrame =
                nil
        end

        restoreAllGunMods()
        restoreMeleeMods()

        local BulletHandler =
            state.Combat.BulletHandler

        if type(BulletHandler)
                == "table"
            and state.Combat.WrappedBulletFire
            and BulletHandler.Fire
                == state.Combat.WrappedBulletFire
            and type(
                state.Combat.OriginalBulletFire
            ) == "function" then

            BulletHandler.Fire =
                state.Combat.OriginalBulletFire
        end

        state.Combat.BulletPatchInstalled =
            false

        if rawget(_G, BUILD_KEY) == state then
            _G[BUILD_KEY] = nil
        end
    end

    state.Cleanup = cleanup

    if type(Window.AddCleanup) == "function" then
        Window:AddCleanup(cleanup)
    end

    -- Same important pattern as Tower: load saved configuration only after
    -- every control/flag exists, and re-fire callbacks so live state matches it.
    task.defer(function()
        if state.Alive and type(Window.LoadConfiguration) == "function" then
            pcall(Window.LoadConfiguration, Window, true)

            task.delay(
                0.25,
                function()
                    if state.Alive then
                        refreshGunConfigs()
                        refreshMeleeConfigs()
                    end
                end
            )
        end
    end)

    state.Ready = true
    return true
end
