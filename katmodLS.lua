--[[
    Vitality's Hub / KAT / 1.4.0-LS

    ============================================================
    KAT
    ============================================================

    SILENT AIM
    - Toggle
    - Head / Torso / Random
    - Hit Chance 0-100%
    - Whole Screen
    - Radius
    - FOV Circle
    - Independent Wall Check

    AIMBOT
    - Toggle arms feature
    - ONLY aims while Right Mouse Button is held
    - Independent RenderStepped loop
    - FOV Circle
    - FOV Radius
    - Smoothness
    - Independent Wall Check

    TRIGGERBOT
    - No target variation
    - Target detection inside configurable FOV/radius
    - FOV Circle
    - Independent Wall Check
    - Revolver trigger
    - Revolver auto reload
    - Knife auto charge / auto throw

    FOV BEHAVIOR
    - First person:
        centered on viewport
    - Third person:
        follows actual mouse

    KAT ESP
    - Own game-specific tab
    - Original KAT Highlight + Billboard implementation
    - Red default
    - Green when player has LOS to you
    - Name
    - Distance
    - Health

    Weapon switching uses WeaponEpoch so old Knife tasks cannot
    execute after Revolver is equipped and vice versa.
]]

return function(context)

    assert(
        type(context) == "table",
        "KAT requires module context"
    )

    local Library =
        assert(
            context.Library or context.NovaField,
            "Vitality library missing"
        )

    local Window =
        assert(
            context.Window,
            "Vitality window missing"
        )

    ----------------------------------------------------------------
    -- KEYS
    ----------------------------------------------------------------

    local KEY =
        "__VITALITY_KAT_MODULE_BUILD_STATE_V14"

    local ROUTER_KEY =
        "__VITALITY_KAT_COMBAT_ROUTER_V14"

    ----------------------------------------------------------------
    -- PREVIOUS MODULE
    ----------------------------------------------------------------

    local previous =
        rawget(_G, KEY)

    if type(previous) == "table"
        and previous.Window == Window
        and previous.Ready
        and previous.Alive then

        return true
    end

    if type(previous) == "table"
        and type(previous.Restore) == "function" then

        pcall(
            previous.Restore
        )
    end

    ----------------------------------------------------------------
    -- SERVICES
    ----------------------------------------------------------------

    local Players =
        game:GetService("Players")

    local Workspace =
        game:GetService("Workspace")

    local RunService =
        game:GetService("RunService")

    local Input =
        game:GetService("UserInputService")

    local CoreGui =
        game:GetService("CoreGui")

    local VirtualInputManager =
        game:GetService("VirtualInputManager")

    local LocalPlayer =
        assert(
            Players.LocalPlayer,
            "KAT requires Roblox client"
        )

    local Mouse =
        LocalPlayer:GetMouse()

    ----------------------------------------------------------------
    -- CONSTANT CONFIG
    ----------------------------------------------------------------

    local Config = {

        MinimumRayLength = 100,

        ------------------------------------------------------------
        -- Revolver
        ------------------------------------------------------------

        RevolverCooldown = 0.12,
        RevolverPressTime = 0.012,

        RevolverEquipSettle = 0.15,

        RevolverReloadRetry = 0.35,
        RevolverReloadTimeout = 2.75,
        RevolverReloadKeyHold = 0.035,

        ------------------------------------------------------------
        -- Knife
        ------------------------------------------------------------

        KnifeMinimumCharge = 0.70,
        KnifeEquipSettle = 0.15,
        KnifeRearmDelay = 0.12,
        KnifeRetryDelay = 0.15,

        ------------------------------------------------------------
        -- ESP
        ------------------------------------------------------------

        ESPLOSRange = 2500,
        ESPLOSInterval = 0.10,

        RedFill =
            Color3.fromRGB(
                240,
                60,
                80
            ),

        RedOutline =
            Color3.fromRGB(
                255,
                140,
                150
            ),

        GreenFill =
            Color3.fromRGB(
                70,
                230,
                110
            ),

        GreenOutline =
            Color3.fromRGB(
                160,
                255,
                180
            ),

        SelfFill =
            Color3.fromRGB(
                120,
                200,
                255
            ),

        SelfOutline =
            Color3.fromRGB(
                180,
                230,
                255
            ),

        FillAlpha = 0.35,
        OutlineAlpha = 0.90,
    }

    ----------------------------------------------------------------
    -- STATE
    ----------------------------------------------------------------

    local state = {

        Window = Window,

        Alive = true,
        Ready = false,

        Connections = {},
        PlayerConnections = {},

        ----------------------------------------------------------------
        -- INPUT
        ----------------------------------------------------------------

        RMBHeld = false,

        ----------------------------------------------------------------
        -- SILENT AIM
        ----------------------------------------------------------------

        SilentAimEnabled = false,

        SilentAimWholeScreen = true,
        SilentAimRadius = 175,

        SilentAimTarget = "Head",
        SilentAimHitChance = 100,

        SilentAimWallCheck = true,

        SilentAimShowFOV = true,

        ----------------------------------------------------------------
        -- AIMBOT
        ----------------------------------------------------------------

        AimbotEnabled = false,

        AimbotFOV = 300,

        AimbotSmoothness = 0.28,

        AimbotWallCheck = true,

        AimbotShowFOV = true,

        ----------------------------------------------------------------
        -- TRIGGERBOT
        ----------------------------------------------------------------

        TriggerbotEnabled = false,

        TriggerbotRadius = 45,

        TriggerbotWallCheck = true,

        TriggerbotShowFOV = true,

        ----------------------------------------------------------------
        -- FOV DRAWING
        ----------------------------------------------------------------

        FOVScreenGui = nil,

        SilentFOVObject = nil,
        AimbotFOVObject = nil,
        TriggerFOVObject = nil,

        ----------------------------------------------------------------
        -- WEAPON
        ----------------------------------------------------------------

        Weapon = nil,
        WeaponType = "None",

        WeaponEpoch = 0,
        WeaponChangedAt = 0,

        WeaponEventConnection = nil,

        ----------------------------------------------------------------
        -- REVOLVER
        ----------------------------------------------------------------

        RevolverBusy = false,
        RevolverPrimed = false,

        RevolverAmmo = nil,
        RevolverReserve = nil,

        RevolverReloading = false,

        LastReloadAttempt = 0,
        LastRevolverShot = 0,
        LastWeaponFired = 0,

        ----------------------------------------------------------------
        -- KNIFE
        ----------------------------------------------------------------

        KnifeCharging = false,
        KnifeInputHeld = false,
        KnifeReleaseBusy = false,

        KnifeChargeStarted = 0,

        LastKnifeStartCharge = 0,
        LastKnifeChargeRelease = 0,

        NextKnifeChargeAttempt = 0,

        ----------------------------------------------------------------
        -- DEAD TARGET CACHE
        --
        -- player -> exact dead Character
        ----------------------------------------------------------------

        DeadTargets = {},

        LastTarget = nil,

        ----------------------------------------------------------------
        -- ESP
        ----------------------------------------------------------------

        ESPEnabled = false,

        ESPShowNames = true,
        ESPShowDistance = true,
        ESPShowHealth = true,

        ESPAttachments = {},

        ----------------------------------------------------------------
        -- DIAGNOSTICS
        ----------------------------------------------------------------

        Matched = 0,
        Redirected = 0,
        NoTarget = 0,
        ChanceMiss = 0,
        Errors = 0,

        LastRayMag = nil,
        LastError = nil,
    }

    local controls = {}

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- INPUT STATE
    --
    -- We deliberately do NOT care whether Roblox says the input
    -- was processed by the GUI.
    --
    -- RMB stays a physical RMB state for Aimbot.
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    table.insert(
        state.Connections,

        Input.InputBegan:
        Connect(function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton2 then

                state.RMBHeld =
                    true
            end
        end)
    )

    table.insert(
        state.Connections,

        Input.InputEnded:
        Connect(function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton2 then

                state.RMBHeld =
                    false
            end
        end)
    )

    ----------------------------------------------------------------
    -- TARGET HELPERS
    ----------------------------------------------------------------

    local function normalizeTarget(value)

        if value == "Torso" then
            return "Torso"
        end

        if value == "Random" then
            return "Random"
        end

        return "Head"
    end

    local function resolveTargetMode(mode)

        mode =
            normalizeTarget(mode)

        if mode == "Random" then

            if math.random(1, 2) == 1 then
                return "Head"
            end

            return "Torso"
        end

        return mode
    end

    local function getHead(character)

        if not character then
            return nil
        end

        local part =
            character:
            FindFirstChild(
                "Head"
            )

        if part
            and part:IsA("BasePart") then

            return part
        end

        return nil
    end

    local function getTorso(character)

        if not character then
            return nil
        end

        local part =
            character:
            FindFirstChild(
                "UpperTorso"
            )

            or character:
            FindFirstChild(
                "Torso"
            )

            or character:
            FindFirstChild(
                "HumanoidRootPart"
            )

        if part
            and part:IsA("BasePart") then

            return part
        end

        return nil
    end

    local function getTargetPart(
        character,
        mode,
        forcedMode
    )

        local resolved =
            forcedMode
            or resolveTargetMode(
                mode
            )

        if resolved == "Torso" then

            return
                getTorso(character)
                or getHead(character),
                "Torso"
        end

        return
            getHead(character)
            or getTorso(character),
            "Head"
    end

    ----------------------------------------------------------------
    -- Triggerbot has NO variation.
    --
    -- Use center mass as the FOV reference because it creates a much
    -- more stable radius than Head while players animate/jump.
    ----------------------------------------------------------------

    local function getTriggerPart(character)

        if not character then
            return nil
        end

        local part =
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

            or character:
            FindFirstChild(
                "Head"
            )

        if part
            and part:IsA("BasePart") then

            return part
        end

        return nil
    end

    local function getHumanoid(character)

        if not character then
            return nil
        end

        return character:
            FindFirstChildOfClass(
                "Humanoid"
            )
    end

    local function alive(character)

        if not character
            or not character.Parent then

            return false
        end

        local humanoid =
            getHumanoid(character)

        if not humanoid then
            return false
        end

        if humanoid.Health <= 0 then
            return false
        end

        if humanoid:GetState()
            == Enum.HumanoidStateType.Dead then

            return false
        end

        return true
    end

    ----------------------------------------------------------------
    -- DEAD CHARACTER CACHE
    ----------------------------------------------------------------

    local function markDead(
        player,
        character
    )

        if not player then
            return
        end

        state.DeadTargets[player] =
            character
            or player.Character

        if state.LastTarget == player then

            state.LastTarget =
                nil
        end
    end

    local function clearDead(player)

        if player then

            state.DeadTargets[player] =
                nil
        end
    end

    local function cachedDead(player)

        local deadCharacter =
            state.DeadTargets[player]

        if not deadCharacter then
            return false
        end

        ------------------------------------------------------------
        -- Still the exact same dead character?
        ------------------------------------------------------------

        if player.Character
            == deadCharacter then

            return true
        end

        ------------------------------------------------------------
        -- Respawned.
        ------------------------------------------------------------

        state.DeadTargets[player] =
            nil

        return false
    end

    local function validPlayer(player)

        if not player
            or player == LocalPlayer then

            return false
        end

        if cachedDead(player) then
            return false
        end

        local character =
            player.Character

        if not alive(character) then

            markDead(
                player,
                character
            )

            return false
        end

        if character:
            FindFirstChildOfClass(
                "ForceField"
            ) then

            return false
        end

        return true
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- CAMERA / FOV ORIGIN
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function isFirstPerson()

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return false
        end

        ------------------------------------------------------------
        -- Explicit Roblox forced first-person mode
        ------------------------------------------------------------

        if LocalPlayer.CameraMode
            == Enum.CameraMode.LockFirstPerson then

            return true
        end

        ------------------------------------------------------------
        -- Camera proximity detection
        ------------------------------------------------------------

        local distance =

            (
                camera.Focus.Position
                - camera.CFrame.Position
            ).Magnitude

        return distance <= 1.25
    end

    ----------------------------------------------------------------
    -- Same coordinate source is used by:
    --
    -- Silent Aim
    -- Aimbot
    -- Triggerbot
    -- FOV circles
    --
    -- FIRST PERSON:
    --      viewport center
    --
    -- THIRD PERSON:
    --      actual mouse position
    ----------------------------------------------------------------

    local function getAimScreenPosition()

        local camera =
            Workspace.CurrentCamera

        if not camera then

            return Vector2.new(
                0,
                0
            )
        end

        if isFirstPerson() then

            return Vector2.new(

                camera.ViewportSize.X / 2,

                camera.ViewportSize.Y / 2

            )
        end

        return Input:
            GetMouseLocation()
    end

    ----------------------------------------------------------------
    -- VISIBILITY / WALL CHECK
    ----------------------------------------------------------------

    local function hasVisibility(
        origin,
        part,
        extraIgnore
    )

        if not part then
            return false
        end

        local params =
            RaycastParams.new()

        params.FilterType =
            Enum.RaycastFilterType.Exclude

        params.IgnoreWater =
            true

        local ignore = {}

        if type(extraIgnore)
            == "table" then

            for _, object
                in ipairs(
                    extraIgnore
                ) do

                if typeof(object)
                    == "Instance" then

                    table.insert(
                        ignore,
                        object
                    )
                end
            end
        end

        if LocalPlayer.Character then

            table.insert(
                ignore,
                LocalPlayer.Character
            )
        end

        params.FilterDescendantsInstances =
            ignore

        local result =
            Workspace:Raycast(

                origin,

                part.Position
                - origin,

                params

            )

        if not result then
            return true
        end

        return
            result.Instance

            and result.Instance:
                IsDescendantOf(
                    part.Parent
                )
    end

    local function passesSilentWallCheck(
        origin,
        part,
        ignore
    )

        if not state.SilentAimWallCheck then
            return true
        end

        return hasVisibility(
            origin,
            part,
            ignore
        )
    end

    local function passesAimbotWallCheck(part)

        if not state.AimbotWallCheck then
            return true
        end

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return false
        end

        return hasVisibility(
            camera.CFrame.Position,
            part
        )
    end

    local function passesTriggerWallCheck(part)

        if not state.TriggerbotWallCheck then
            return true
        end

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return false
        end

        return hasVisibility(
            camera.CFrame.Position,
            part
        )
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- FOV DRAWING SYSTEM
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function ensureFOVFallbackGUI()

        if state.FOVScreenGui
            and state.FOVScreenGui.Parent then

            return state.FOVScreenGui
        end

        local screen =
            Instance.new(
                "ScreenGui"
            )

        screen.Name =
            "Vitality_KAT_FOV"

        screen.IgnoreGuiInset =
            true

        screen.ResetOnSpawn =
            false

        screen.DisplayOrder =
            2147483646

        ------------------------------------------------------------
        -- ScreenGui itself contains no buttons / interactable objects.
        ------------------------------------------------------------

        pcall(function()

            screen.Parent =
                CoreGui

        end)

        if not screen.Parent then

            screen.Parent =
                LocalPlayer:
                WaitForChild(
                    "PlayerGui"
                )
        end

        state.FOVScreenGui =
            screen

        return screen
    end

    ----------------------------------------------------------------
    -- Circle factory
    ----------------------------------------------------------------

    local function createFOVCircle(
        name,
        colour
    )

        ------------------------------------------------------------
        -- Drawing API:
        -- ideal because it does not participate in Roblox GUI input.
        ------------------------------------------------------------

        if type(Drawing)
            == "table"

            and type(Drawing.new)
                == "function" then

            local ok,
                drawing =

                pcall(function()

                    local circle =
                        Drawing.new(
                            "Circle"
                        )

                    circle.Visible =
                        false

                    circle.Radius =
                        100

                    circle.Thickness =
                        1.5

                    circle.NumSides =
                        72

                    circle.Filled =
                        false

                    circle.Transparency =
                        0.9

                    circle.Color =
                        colour

                    return circle
                end)

            if ok
                and drawing then

                return {
                    Type = "Drawing",
                    Object = drawing,
                }
            end
        end

        ------------------------------------------------------------
        -- Non-interactive GUI fallback
        ------------------------------------------------------------

        local screen =
            ensureFOVFallbackGUI()

        local frame =
            Instance.new(
                "Frame"
            )

        frame.Name =
            name

        frame.AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            )

        frame.BackgroundTransparency =
            1

        frame.BorderSizePixel =
            0

        frame.Active =
            false

        frame.Selectable =
            false

        frame.Visible =
            false

        frame.ZIndex =
            100000

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
            0.1

        stroke.Color =
            colour

        stroke.Parent =
            frame

        frame.Parent =
            screen

        return {
            Type = "GUI",
            Object = frame,
        }
    end

    state.SilentFOVObject =
        createFOVCircle(
            "SilentAimFOV",
            Color3.fromRGB(
                170,
                120,
                255
            )
        )

    state.AimbotFOVObject =
        createFOVCircle(
            "AimbotFOV",
            Color3.fromRGB(
                80,
                190,
                255
            )
        )

    state.TriggerFOVObject =
        createFOVCircle(
            "TriggerbotFOV",
            Color3.fromRGB(
                255,
                165,
                75
            )
        )

    local function updateSingleFOV(
        descriptor,
        position,
        radius,
        visible
    )

        if not descriptor
            or not descriptor.Object then

            return
        end

        if descriptor.Type
            == "Drawing" then

            pcall(function()

                descriptor.Object.Position =
                    position

                descriptor.Object.Radius =
                    radius

                descriptor.Object.Visible =
                    visible
            end)

            return
        end

        local frame =
            descriptor.Object

        if not frame.Parent then
            return
        end

        local diameter =
            radius * 2

        frame.Size =
            UDim2.fromOffset(
                diameter,
                diameter
            )

        frame.Position =
            UDim2.fromOffset(
                position.X,
                position.Y
            )

        frame.Visible =
            visible
    end

    ----------------------------------------------------------------
    -- FOV update loop is completely independent of feature loops.
    ----------------------------------------------------------------

    table.insert(
        state.Connections,

        RunService.RenderStepped:
        Connect(function()

            if not state.Alive then
                return
            end

            local origin =
                getAimScreenPosition()

            updateSingleFOV(

                state.SilentFOVObject,

                origin,

                state.SilentAimRadius,

                state.SilentAimEnabled
                    and state.SilentAimShowFOV
            )

            updateSingleFOV(

                state.AimbotFOVObject,

                origin,

                state.AimbotFOV,

                state.AimbotEnabled
                    and state.AimbotShowFOV
            )

            updateSingleFOV(

                state.TriggerFOVObject,

                origin,

                state.TriggerbotRadius,

                state.TriggerbotEnabled
                    and state.TriggerbotShowFOV
            )

        end)
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- AIMBOT TARGET ACQUISITION
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function getClosestAimbotTarget()

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return nil
        end

        local aimOrigin =
            getAimScreenPosition()

        local bestPlayer =
            nil

        local bestPart =
            nil

        local bestDistance =
            state.AimbotFOV
            * state.AimbotFOV

        for _, player
            in ipairs(
                Players:GetPlayers()
            ) do

            if validPlayer(player) then

                local part =
                    getHead(
                        player.Character
                    )

                    or getTorso(
                        player.Character
                    )

                if part
                    and passesAimbotWallCheck(
                        part
                    ) then

                    local point,
                        onScreen =

                        camera:
                        WorldToViewportPoint(
                            part.Position
                        )

                    if onScreen
                        and point.Z > 0 then

                        local dx =
                            point.X
                            - aimOrigin.X

                        local dy =
                            point.Y
                            - aimOrigin.Y

                        local distance =
                            dx * dx
                            + dy * dy

                        if distance
                            <= bestDistance then

                            bestDistance =
                                distance

                            bestPlayer =
                                player

                            bestPart =
                                part
                        end
                    end
                end
            end
        end

        return
            bestPlayer,
            bestPart
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- TRIGGERBOT TARGET ACQUISITION
    --
    -- No target variation.
    --
    -- Finds closest living target whose CENTER MASS is inside the
    -- Triggerbot radius.
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function getClosestTriggerTarget()

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return nil
        end

        local origin =
            getAimScreenPosition()

        local bestPlayer =
            nil

        local bestPart =
            nil

        local bestDistance =
            state.TriggerbotRadius
            * state.TriggerbotRadius

        for _, player
            in ipairs(
                Players:GetPlayers()
            ) do

            if validPlayer(player) then

                local part =
                    getTriggerPart(
                        player.Character
                    )

                if part
                    and passesTriggerWallCheck(
                        part
                    ) then

                    local point,
                        onScreen =

                        camera:
                        WorldToViewportPoint(
                            part.Position
                        )

                    if onScreen
                        and point.Z > 0 then

                        local dx =
                            point.X
                            - origin.X

                        local dy =
                            point.Y
                            - origin.Y

                        local distance =
                            dx * dx
                            + dy * dy

                        if distance
                            <= bestDistance then

                            bestDistance =
                                distance

                            bestPlayer =
                                player

                            bestPart =
                                part
                        end
                    end
                end
            end
        end

        return
            bestPlayer,
            bestPart
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLAYER CONNECTIONS / ESP
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function disconnectPlayer(player)

        local list =
            state.PlayerConnections[player]

        if not list then
            return
        end

        for _, connection
            in ipairs(list) do

            pcall(function()

                connection:
                    Disconnect()
            end)
        end

        state.PlayerConnections[player] =
            nil
    end

    ----------------------------------------------------------------
    -- ESP HELPERS
    ----------------------------------------------------------------

    local function formatDistance(studs)

        if studs < 1000 then

            return string.format(
                "%dm",
                math.floor(
                    studs + 0.5
                )
            )
        end

        return string.format(
            "%.1fkm",
            studs / 1000
        )
    end

    local function healthColour(fraction)

        fraction =
            math.clamp(
                fraction,
                0,
                1
            )

        if fraction > 0.6 then

            return Color3.fromRGB(
                120,
                220,
                160
            )

        elseif fraction > 0.3 then

            return Color3.fromRGB(
                240,
                200,
                100
            )

        else

            return Color3.fromRGB(
                240,
                110,
                130
            )
        end
    end

    local function getESPAnchor(character)

        if not character then
            return nil
        end

        return
            character:
            FindFirstChild(
                "Head"
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
                "HumanoidRootPart"
            )
    end

    local function ESPHasLineOfSight(
        fromPart,
        toPart,
        ignoreList
    )

        if not fromPart
            or not toPart then

            return false
        end

        local params =
            RaycastParams.new()

        params.FilterType =
            Enum.RaycastFilterType.Exclude

        params.IgnoreWater =
            true

        params.FilterDescendantsInstances =
            ignoreList
            or {}

        local origin =
            fromPart.Position

        local direction =
            toPart.Position
            - origin

        local distance =
            direction.Magnitude

        if distance <= 0.001 then
            return true
        end

        if distance
            > Config.ESPLOSRange then

            return false
        end

        local result =
            Workspace:Raycast(
                origin,
                direction,
                params
            )

        if not result then
            return true
        end

        local hit =
            result.Instance

        if hit
            and (
                hit == toPart
                or hit:
                    IsDescendantOf(
                        toPart.Parent
                    )
            ) then

            return true
        end

        return false
    end

    local function applyESPColour(
        attachment,
        isSelf,
        canSeeMe
    )

        local highlight =
            attachment
            and attachment.highlight

        if not highlight then
            return
        end

        if isSelf then

            highlight.FillColor =
                Config.SelfFill

            highlight.OutlineColor =
                Config.SelfOutline

            return
        end

        if canSeeMe then

            highlight.FillColor =
                Config.GreenFill

            highlight.OutlineColor =
                Config.GreenOutline

        else

            highlight.FillColor =
                Config.RedFill

            highlight.OutlineColor =
                Config.RedOutline
        end
    end

    local function removeESPAttachment(player)

        local attachment =
            state.ESPAttachments[player]

        if not attachment then
            return
        end

        if attachment.highlight then

            pcall(function()

                attachment.highlight:
                    Destroy()
            end)
        end

        if attachment.billboard then

            pcall(function()

                attachment.billboard:
                    Destroy()
            end)
        end

        state.ESPAttachments[player] =
            nil
    end

    ----------------------------------------------------------------
    -- ORIGINAL KAT ESP BILLBOARD
    ----------------------------------------------------------------

    local function buildESPBillboard(
        character,
        playerName
    )

        local anchor =
            getESPAnchor(character)

        if not anchor then
            return nil
        end

        local billboard =
            Instance.new(
                "BillboardGui"
            )

        billboard.Name =
            "KAT_ESP_Label"

        billboard.Adornee =
            anchor

        billboard.Size =
            UDim2.fromOffset(
                220,
                56
            )

        billboard.StudsOffsetWorldSpace =
            Vector3.new(
                0,
                2.5,
                0
            )

        billboard.AlwaysOnTop =
            true

        billboard.LightInfluence =
            0

        billboard.MaxDistance =
            5000

        billboard.ResetOnSpawn =
            false

        ------------------------------------------------------------
        -- Name
        ------------------------------------------------------------

        local nameLabel =
            Instance.new(
                "TextLabel"
            )

        nameLabel.Name =
            "Name"

        nameLabel.BackgroundTransparency =
            1

        nameLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                20
            )

        nameLabel.Font =
            Enum.Font.GothamBold

        nameLabel.TextSize =
            15

        nameLabel.TextColor3 =
            Color3.fromRGB(
                245,
                245,
                250
            )

        nameLabel.TextStrokeTransparency =
            0

        nameLabel.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )

        nameLabel.Text =
            playerName
            or ""

        nameLabel.Parent =
            billboard

        ------------------------------------------------------------
        -- Distance
        ------------------------------------------------------------

        local distanceLabel =
            Instance.new(
                "TextLabel"
            )

        distanceLabel.Name =
            "Distance"

        distanceLabel.BackgroundTransparency =
            1

        distanceLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                20
            )

        distanceLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                16
            )

        distanceLabel.Font =
            Enum.Font.Gotham

        distanceLabel.TextSize =
            12

        distanceLabel.TextColor3 =
            Color3.fromRGB(
                190,
                190,
                210
            )

        distanceLabel.TextStrokeTransparency =
            0

        distanceLabel.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )

        distanceLabel.Text =
            "—"

        distanceLabel.Parent =
            billboard

        ------------------------------------------------------------
        -- Health
        ------------------------------------------------------------

        local hpLabel =
            Instance.new(
                "TextLabel"
            )

        hpLabel.Name =
            "Health"

        hpLabel.BackgroundTransparency =
            1

        hpLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                36
            )

        hpLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                14
            )

        hpLabel.Font =
            Enum.Font.Gotham

        hpLabel.TextSize =
            11

        hpLabel.TextColor3 =
            Color3.fromRGB(
                180,
                255,
                200
            )

        hpLabel.TextStrokeTransparency =
            0

        hpLabel.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )

        hpLabel.Text =
            "—"

        hpLabel.Parent =
            billboard

        billboard.Parent =
            CoreGui

        return
            billboard,
            nameLabel,
            distanceLabel,
            hpLabel
    end

    local function addESPAttachment(
        player,
        character
    )

        removeESPAttachment(
            player
        )

        local isSelf =
            player == LocalPlayer

        local highlight =
            Instance.new(
                "Highlight"
            )

        highlight.Name =
            "KAT_ESP_Highlight"

        highlight.Adornee =
            character

        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.FillTransparency =
            1
            - Config.FillAlpha

        highlight.OutlineTransparency =
            1
            - Config.OutlineAlpha

        highlight.Parent =
            CoreGui

        local billboard,
            nameLabel,
            distanceLabel,
            hpLabel =

            buildESPBillboard(
                character,
                player.Name
            )

        local attachment = {

            highlight =
                highlight,

            billboard =
                billboard,

            nameLabel =
                nameLabel,

            distLabel =
                distanceLabel,

            hpLabel =
                hpLabel,

            character =
                character,

            canSeeMe =
                false,

            lastLOSCheck =
                0,

            isSelf =
                isSelf,
        }

        state.ESPAttachments[player] =
            attachment

        applyESPColour(
            attachment,
            isSelf,
            false
        )

        highlight.Enabled =
            state.ESPEnabled

        if billboard then

            billboard.Enabled =
                state.ESPEnabled
        end

        if nameLabel then

            nameLabel.Visible =
                state.ESPShowNames
        end

        if distanceLabel then

            distanceLabel.Visible =
                state.ESPShowDistance
        end

        if hpLabel then

            hpLabel.Visible =
                state.ESPShowHealth
        end
    end

    ----------------------------------------------------------------
    -- CHARACTER LIFECYCLE
    ----------------------------------------------------------------

    local function onCharacterAdded(
        player,
        character
    )

        clearDead(
            player
        )

        local humanoid =
            character:
            WaitForChild(
                "Humanoid",
                5
            )

        if not humanoid then
            return
        end

        local anchor =
            getESPAnchor(character)

        if not anchor then

            anchor =
                character:
                WaitForChild(
                    "HumanoidRootPart",
                    5
                )
        end

        if not anchor then
            return
        end

        addESPAttachment(
            player,
            character
        )

        state.PlayerConnections[player] =
            state.PlayerConnections[player]
            or {}

        table.insert(
            state.PlayerConnections[player],

            humanoid.Died:
            Connect(function()

                if player ~= LocalPlayer then

                    markDead(
                        player,
                        character
                    )
                end

            end)
        )

        table.insert(
            state.PlayerConnections[player],

            humanoid.HealthChanged:
            Connect(function(health)

                if health <= 0
                    and player ~= LocalPlayer then

                    markDead(
                        player,
                        character
                    )
                end

            end)
        )
    end

    local function onPlayerAdded(player)

        disconnectPlayer(player)

        state.PlayerConnections[player] =
            {}

        table.insert(
            state.PlayerConnections[player],

            player.CharacterAdded:
            Connect(function(character)

                clearDead(player)

                task.spawn(
                    onCharacterAdded,
                    player,
                    character
                )

            end)
        )

        table.insert(
            state.PlayerConnections[player],

            player.CharacterRemoving:
            Connect(function(character)

                removeESPAttachment(
                    player
                )

                if player ~= LocalPlayer then

                    markDead(
                        player,
                        character
                    )
                end

            end)
        )

        if player.Character then

            task.spawn(
                onCharacterAdded,
                player,
                player.Character
            )
        end
    end

    local function onPlayerRemoving(player)

        disconnectPlayer(player)

        removeESPAttachment(player)

        state.DeadTargets[player] =
            nil
    end

    for _, player
        in ipairs(
            Players:GetPlayers()
        ) do

        onPlayerAdded(player)
    end

    table.insert(
        state.Connections,

        Players.PlayerAdded:
        Connect(
            onPlayerAdded
        )
    )

    table.insert(
        state.Connections,

        Players.PlayerRemoving:
        Connect(
            onPlayerRemoving
        )
    )

    ----------------------------------------------------------------
    -- ESP VISIBILITY
    ----------------------------------------------------------------

    local function refreshESPVisibility()

        for _, attachment
            in pairs(
                state.ESPAttachments
            ) do

            if attachment.highlight then

                attachment.highlight.Enabled =
                    state.ESPEnabled
            end

            if attachment.billboard then

                attachment.billboard.Enabled =
                    state.ESPEnabled
            end

            if attachment.nameLabel then

                attachment.nameLabel.Visible =
                    state.ESPShowNames
            end

            if attachment.distLabel then

                attachment.distLabel.Visible =
                    state.ESPShowDistance
            end

            if attachment.hpLabel then

                attachment.hpLabel.Visible =
                    state.ESPShowHealth
            end
        end
    end

    ----------------------------------------------------------------
    -- ESP UPDATE
    ----------------------------------------------------------------

    local lastESPUpdate =
        0

    table.insert(
        state.Connections,

        RunService.Heartbeat:
        Connect(function(dt)

            if not state.Alive then
                return
            end

            lastESPUpdate += dt

            if lastESPUpdate
                < 1 / 15 then

                return
            end

            lastESPUpdate =
                0

            local myCharacter =
                LocalPlayer.Character

            local myRoot =
                myCharacter
                and myCharacter:
                    FindFirstChild(
                        "HumanoidRootPart"
                    )

            local myHead =
                myCharacter
                and myCharacter:
                    FindFirstChild(
                        "Head"
                    )

            local now =
                os.clock()

            for player,
                attachment

                in pairs(
                    state.ESPAttachments
                ) do

                if not player.Parent then

                    removeESPAttachment(player)

                    continue
                end

                local character =
                    player.Character

                if not character
                    or not character.Parent then

                    removeESPAttachment(player)

                    continue
                end

                if attachment.character
                    ~= character then

                    task.spawn(
                        onCharacterAdded,
                        player,
                        character
                    )

                    continue
                end

                if attachment.highlight
                    and attachment.highlight.Adornee
                        ~= character then

                    attachment.highlight.Adornee =
                        character
                end

                --------------------------------------------------------
                -- LOS
                --------------------------------------------------------

                if not attachment.isSelf

                    and (
                        now
                        - attachment.lastLOSCheck
                    ) >= Config.ESPLOSInterval then

                    attachment.lastLOSCheck =
                        now

                    local theirHead =
                        character:
                        FindFirstChild(
                            "Head"
                        )

                    if theirHead
                        and myHead
                        and myRoot then

                        local canSee =

                            ESPHasLineOfSight(

                                theirHead,

                                myHead,

                                {
                                    character,
                                    myCharacter,
                                }

                            )

                        if canSee
                            ~= attachment.canSeeMe then

                            attachment.canSeeMe =
                                canSee

                            applyESPColour(

                                attachment,

                                false,

                                canSee

                            )
                        end

                    elseif attachment.canSeeMe then

                        attachment.canSeeMe =
                            false

                        applyESPColour(

                            attachment,

                            false,

                            false

                        )
                    end
                end

                --------------------------------------------------------
                -- DISTANCE
                --------------------------------------------------------

                if state.ESPShowDistance
                    and attachment.distLabel then

                    local part =
                        getESPAnchor(character)

                    if part
                        and myRoot then

                        local distance =

                            (
                                part.Position
                                - myRoot.Position
                            ).Magnitude

                        attachment.distLabel.Text =

                            formatDistance(
                                distance
                            )
                    end
                end

                --------------------------------------------------------
                -- HEALTH
                --------------------------------------------------------

                if state.ESPShowHealth
                    and attachment.hpLabel then

                    local humanoid =
                        getHumanoid(character)

                    if humanoid then

                        local maximum =
                            math.max(
                                humanoid.MaxHealth,
                                1
                            )

                        local percentage =
                            humanoid.Health
                            / maximum

                        attachment.hpLabel.Text =

                            string.format(

                                "%d / %d",

                                math.floor(
                                    humanoid.Health
                                    + 0.5
                                ),

                                math.floor(
                                    maximum
                                    + 0.5
                                )

                            )

                        attachment.hpLabel.TextColor3 =

                            healthColour(
                                percentage
                            )
                    end
                end
            end

        end)
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- WEAPON DETECTION
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function classifyWeapon(object)

        if not object then
            return "None"
        end

        local name =
            string.lower(
                object.Name
            )

        if name == "knife"
            or string.find(
                name,
                "knife",
                1,
                true
            ) then

            return "Knife"
        end

        if name == "revolver"
            or string.find(
                name,
                "revolver",
                1,
                true
            ) then

            return "Revolver"
        end

        return "Other"
    end

    local function scanEquippedWeapon()

        local character =
            LocalPlayer.Character

        if not character then
            return nil, "None"
        end

        local recognized =
            {}

        local otherTool =
            nil

        for _, object
            in ipairs(
                character:GetChildren()
            ) do

            local weaponType =
                classifyWeapon(object)

            if weaponType == "Knife"
                or weaponType == "Revolver" then

                table.insert(
                    recognized,
                    {
                        Object = object,
                        Type = weaponType,
                    }
                )

            elseif object:IsA("Tool") then

                otherTool =
                    otherTool
                    or object
            end
        end

        if #recognized == 1 then

            return
                recognized[1].Object,
                recognized[1].Type
        end

        if #recognized > 1 then

            return nil,
                "Transition"
        end

        if otherTool then
            return otherTool, "Other"
        end

        return nil, "None"
    end

    ----------------------------------------------------------------
    -- WEAPON STATE RESET
    ----------------------------------------------------------------

    local function disconnectWeaponEvent()

        if state.WeaponEventConnection then

            pcall(function()

                state.WeaponEventConnection:
                    Disconnect()
            end)

            state.WeaponEventConnection =
                nil
        end
    end

    local function resetKnifeState()

        state.KnifeCharging =
            false

        state.KnifeInputHeld =
            false

        state.KnifeReleaseBusy =
            false

        state.KnifeChargeStarted =
            0

        state.NextKnifeChargeAttempt =
            0
    end

    local function resetRevolverState()

        state.RevolverBusy =
            false

        state.RevolverPrimed =
            false

        state.RevolverAmmo =
            nil

        state.RevolverReserve =
            nil

        state.RevolverReloading =
            false

        state.LastReloadAttempt =
            0

        state.LastRevolverShot =
            0
    end

    ----------------------------------------------------------------
    -- REVOLVER EVENT TRACKING
    ----------------------------------------------------------------

    local function bindRevolverEvents(
        weapon,
        epoch
    )

        disconnectWeaponEvent()

        if not weapon
            or weapon.Parent
                ~= LocalPlayer.Character then

            return
        end

        local event =
            weapon:
            FindFirstChild(
                "ClientEvent"
            )

        if not event then

            event =
                weapon:
                WaitForChild(
                    "ClientEvent",
                    2
                )
        end

        if not event
            or not event:
                IsA(
                    "RemoteEvent"
                ) then

            return
        end

        state.WeaponEventConnection =

            event.OnClientEvent:
            Connect(function(
                command,
                data
            )

                if state.WeaponEpoch
                    ~= epoch

                    or state.Weapon
                        ~= weapon

                    or state.WeaponType
                        ~= "Revolver" then

                    return
                end

                if command
                    == "ServerAmmoValues"

                    and type(data)
                        == "table" then

                    local loaded =
                        tonumber(
                            data[1]
                        )

                    local reserve =
                        tonumber(
                            data[2]
                        )

                    if loaded ~= nil then

                        state.RevolverAmmo =
                            loaded
                    end

                    if reserve ~= nil then

                        state.RevolverReserve =
                            reserve
                    end

                    if loaded
                        and loaded > 0 then

                        state.RevolverReloading =
                            false

                        state.RevolverBusy =
                            false
                    end
                end
            end)
    end

    ----------------------------------------------------------------
    -- REVOLVER EQUIP SETTLE
    ----------------------------------------------------------------

    local function primeRevolver(
        weapon,
        epoch
    )

        task.wait(
            Config.RevolverEquipSettle
        )

        if state.WeaponEpoch
            ~= epoch

            or state.WeaponType
                ~= "Revolver"

            or state.Weapon
                ~= weapon

            or weapon.Parent
                ~= LocalPlayer.Character then

            return
        end

        ------------------------------------------------------------
        -- Gun is now definitely equipped.
        -- Safe point for stale input cleanup.
        ------------------------------------------------------------

        if type(firesignal)
            == "function" then

            pcall(function()

                firesignal(
                    Mouse.Button1Up
                )

            end)
        end

        if type(mouse1release)
            == "function" then

            pcall(
                mouse1release
            )
        end

        bindRevolverEvents(
            weapon,
            epoch
        )

        state.RevolverPrimed =
            true
    end

    ----------------------------------------------------------------
    -- WEAPON CHANGE
    ----------------------------------------------------------------

    local function updateEquippedWeapon()

        local weapon,
            weaponType =

            scanEquippedWeapon()

        if weapon == state.Weapon
            and weaponType
                == state.WeaponType then

            return
        end

        local oldType =
            state.WeaponType

        disconnectWeaponEvent()

        ------------------------------------------------------------
        -- INVALIDATE ALL OLD ASYNC WEAPON TASKS
        ------------------------------------------------------------

        state.WeaponEpoch += 1

        local epoch =
            state.WeaponEpoch

        if oldType == "Knife" then

            resetKnifeState()

        elseif oldType
            == "Revolver" then

            resetRevolverState()
        end

        state.Weapon =
            weapon

        state.WeaponType =
            weaponType

        state.WeaponChangedAt =
            os.clock()

        ------------------------------------------------------------
        -- KNIFE
        ------------------------------------------------------------

        if weaponType == "Knife" then

            resetKnifeState()

            state.NextKnifeChargeAttempt =

                os.clock()
                + Config.KnifeEquipSettle

            return
        end

        ------------------------------------------------------------
        -- REVOLVER
        ------------------------------------------------------------

        if weaponType
            == "Revolver" then

            resetRevolverState()

            task.spawn(
                primeRevolver,
                weapon,
                epoch
            )

            return
        end

        ------------------------------------------------------------
        -- NONE / TRANSITION / OTHER
        ------------------------------------------------------------

        resetKnifeState()
        resetRevolverState()
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- SILENT AIM
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function selectSilentRay(
        ray,
        ignoreList,
        ignoreWater
    )

        if not state.Alive
            or not state.SilentAimEnabled then

            return nil
        end

        local camera =
            Workspace.CurrentCamera

        local character =
            LocalPlayer.Character

        local humanoid =
            getHumanoid(character)

        if not camera
            or not humanoid
            or humanoid.Health <= 0 then

            return nil
        end

        if typeof(ray) ~= "Ray"
            or type(ignoreList)
                ~= "table" then

            return nil
        end

        local magnitude =
            ray.Direction.Magnitude

        if magnitude ~= magnitude
            or magnitude == math.huge
            or magnitude
                < Config.MinimumRayLength then

            return nil
        end

        state.LastRayMag =
            magnitude

        state.Matched += 1

        ------------------------------------------------------------
        -- HIT CHANCE
        ------------------------------------------------------------

        local chance =
            math.clamp(
                tonumber(
                    state.SilentAimHitChance
                ) or 100,
                0,
                100
            )

        if chance <= 0 then

            state.ChanceMiss += 1

            return nil
        end

        if chance < 100
            and math.random(
                1,
                100
            ) > chance then

            state.ChanceMiss += 1

            return nil
        end

        ------------------------------------------------------------
        -- Ignore list
        ------------------------------------------------------------

        local ignore =
            {}

        for _, object
            in ipairs(
                ignoreList
            ) do

            if typeof(object)
                == "Instance" then

                table.insert(
                    ignore,
                    object
                )
            end
        end

        if character then

            table.insert(
                ignore,
                character
            )
        end

        ------------------------------------------------------------
        -- First-person center / third-person mouse
        ------------------------------------------------------------

        local aimOrigin =
            getAimScreenPosition()

        local bestDistance =

            state.SilentAimWholeScreen

            and math.huge

            or (
                state.SilentAimRadius
                * state.SilentAimRadius
            )

        local bestPosition =
            nil

        local bestPlayer =
            nil

        for _, player
            in ipairs(
                Players:GetPlayers()
            ) do

            if validPlayer(player) then

                local model =
                    player.Character

                local part =
                    getTargetPart(
                        model,
                        state.SilentAimTarget
                    )

                if part then

                    local point,
                        onScreen =

                        camera:
                        WorldToViewportPoint(
                            part.Position
                        )

                    if onScreen
                        and point.Z > 0 then

                        local dx =
                            point.X
                            - aimOrigin.X

                        local dy =
                            point.Y
                            - aimOrigin.Y

                        local screenDistance =
                            dx * dx
                            + dy * dy

                        local direction =
                            part.Position
                            - ray.Origin

                        local worldDistance =
                            direction.Magnitude

                        if screenDistance
                            <= bestDistance

                            and worldDistance
                                > 0.001

                            and worldDistance
                                <= magnitude

                            and passesSilentWallCheck(

                                ray.Origin,

                                part,

                                ignore

                            ) then

                            bestDistance =
                                screenDistance

                            bestPosition =
                                part.Position

                            bestPlayer =
                                player
                        end
                    end
                end
            end
        end

        if not bestPosition then

            state.NoTarget += 1

            return nil
        end

        state.LastTarget =
            bestPlayer.Name

        state.Redirected += 1

        return Ray.new(

            ray.Origin,

            (
                bestPosition
                - ray.Origin
            ).Unit
            * magnitude

        )
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- NAMECALL ROUTER
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local router =
        rawget(
            _G,
            ROUTER_KEY
        )

    if type(router)
        ~= "table" then

        router = {
            Installed = false,
            Owner = nil,
        }

        rawset(
            _G,
            ROUTER_KEY,
            router
        )
    end

    state.SelectRay =
        selectSilentRay

    local function handleNamecall(
        selfObject,
        method,
        args
    )

        ----------------------------------------------------------------
        -- WEAPON EVENTS
        ----------------------------------------------------------------

        if method == "FireServer"

            and typeof(selfObject)
                == "Instance"

            and selfObject.Name
                == "ClientEvent" then

            local weapon =
                selfObject.Parent

            local command =
                args[1]

            ------------------------------------------------------------
            -- Native KAT lethal-damage prediction
            ------------------------------------------------------------

            if command
                == "damageRequest" then

                local packet =
                    args[2]

                local hit =

                    type(packet)
                        == "table"

                    and packet[1]

                if type(hit)
                    == "table" then

                    local character =
                        hit.TargetCharacter

                    local humanoid =
                        hit.TargetHumanoid

                    local damage =
                        tonumber(
                            hit.Damage
                        )

                    if typeof(character)
                        == "Instance"

                        and typeof(humanoid)
                            == "Instance"

                        and damage then

                        local player =
                            Players:
                            GetPlayerFromCharacter(
                                character
                            )

                        if player
                            and humanoid.Health
                                <= damage then

                            markDead(
                                player,
                                character
                            )
                        end
                    end
                end
            end

            ------------------------------------------------------------
            -- KNIFE
            ------------------------------------------------------------

            if state.WeaponType
                == "Knife"

                and weapon
                    == state.Weapon then

                if command
                    == "StartCharge" then

                    state.KnifeCharging =
                        true

                    state.KnifeInputHeld =
                        true

                    state.KnifeChargeStarted =
                        os.clock()

                    state.LastKnifeStartCharge =
                        state.KnifeChargeStarted

                elseif command
                    == "ChargeRelease" then

                    state.KnifeCharging =
                        false

                    state.KnifeInputHeld =
                        false

                    state.KnifeReleaseBusy =
                        false

                    state.LastKnifeChargeRelease =
                        os.clock()

                    state.NextKnifeChargeAttempt =

                        os.clock()
                        + Config.KnifeRearmDelay
                end

            ------------------------------------------------------------
            -- REVOLVER
            ------------------------------------------------------------

            elseif state.WeaponType
                == "Revolver"

                and weapon
                    == state.Weapon then

                if command
                    == "WeaponFired" then

                    state.LastWeaponFired =
                        os.clock()

                elseif command
                    == "ReloadUpdate"

                    and type(args[2])
                        == "table"

                    and args[2][1]
                        == "Start" then

                    state.RevolverReloading =
                        true
                end
            end
        end

        ----------------------------------------------------------------
        -- SILENT AIM
        ----------------------------------------------------------------

        if state.SilentAimEnabled
            and selfObject == Workspace

            and (
                method
                    == "FindPartOnRayWithIgnoreList"

                or method
                    == "findPartOnRayWithIgnoreList"
            ) then

            local ray =
                args[1]

            local ignore =
                args[2]

            if typeof(ray)
                == "Ray"

                and type(ignore)
                    == "table" then

                local replacement =

                    state.SelectRay(
                        ray,
                        ignore,
                        args[4]
                    )

                if typeof(replacement)
                    == "Ray" then

                    args[1] =
                        replacement
                end
            end
        end
    end

    state.HandleNamecall =
        handleNamecall

    ----------------------------------------------------------------
    -- INSTALL ROUTER
    ----------------------------------------------------------------

    local function installRouter()

        if router.Installed then

            router.Owner =
                state

            return true
        end

        if type(hookmetamethod)
            ~= "function"

            or type(getnamecallmethod)
                ~= "function"

            or type(setnamecallmethod)
                ~= "function" then

            state.LastError =

                "Requires hookmetamethod, getnamecallmethod and setnamecallmethod"

            return false
        end

        local getMethod =
            getnamecallmethod

        local setMethod =
            setnamecallmethod

        local original

        local function dispatch(
            selfObject,
            ...
        )

            local method =
                getMethod()

            local owner =
                router.Owner

            if not owner
                or not owner.Alive
                or type(owner.HandleNamecall)
                    ~= "function" then

                return original(
                    selfObject,
                    ...
                )
            end

            local args =
                table.pack(...)

            local ok,
                failure =

                pcall(

                    owner.HandleNamecall,

                    selfObject,

                    method,

                    args

                )

            if not ok then

                owner.Errors += 1

                owner.LastError =
                    tostring(failure)
            end

            setMethod(
                method
            )

            return original(

                selfObject,

                table.unpack(
                    args,
                    1,
                    args.n
                )

            )
        end

        local ok,
            result =

            pcall(function()

                local callback =

                    type(newcclosure)
                        == "function"

                    and newcclosure(
                        dispatch
                    )

                    or dispatch

                return hookmetamethod(

                    game,

                    "__namecall",

                    callback

                )
            end)

        if not ok
            or type(result)
                ~= "function" then

            state.LastError =

                "Hook installation failed: "
                .. tostring(result)

            return false
        end

        original =
            result

        router.Installed =
            true

        router.Owner =
            state

        state.LastError =
            nil

        return true
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- KNIFE
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function startKnifeCharge()

        if not state.TriggerbotEnabled

            or state.WeaponType
                ~= "Knife"

            or not state.Weapon

            or state.Weapon.Parent
                ~= LocalPlayer.Character then

            return false
        end

        if state.KnifeCharging
            or state.KnifeInputHeld
            or state.KnifeReleaseBusy then

            return false
        end

        if type(firesignal)
            ~= "function" then

            return false
        end

        local epoch =
            state.WeaponEpoch

        local before =
            state.LastKnifeStartCharge

        state.KnifeInputHeld =
            true

        local success =
            pcall(function()

                firesignal(
                    Mouse.Button1Down
                )

            end)

        if not success then

            state.KnifeInputHeld =
                false

            return false
        end

        local started =
            os.clock()

        repeat

            if state.WeaponEpoch
                ~= epoch then

                state.KnifeInputHeld =
                    false

                state.KnifeCharging =
                    false

                return false
            end

            if state.LastKnifeStartCharge
                > before then

                return true
            end

            RunService.Heartbeat:
                Wait()

        until os.clock()
            - started
            >= 0.12

        if state.WeaponEpoch
            == epoch

            and state.WeaponType
                == "Knife"

            and state.Weapon

            and state.Weapon.Parent
                == LocalPlayer.Character then

            pcall(function()

                firesignal(
                    Mouse.Button1Up
                )

            end)
        end

        state.KnifeInputHeld =
            false

        state.KnifeCharging =
            false

        return false
    end

    local function knifeReady()

        if state.WeaponType
            ~= "Knife" then

            return false
        end

        if not state.KnifeCharging
            or not state.KnifeInputHeld then

            return false
        end

        return (

            os.clock()
            - state.KnifeChargeStarted

        ) >= Config.KnifeMinimumCharge
    end

    local function throwKnife()

        if state.KnifeReleaseBusy
            or not knifeReady() then

            return false
        end

        if type(firesignal)
            ~= "function" then

            return false
        end

        local epoch =
            state.WeaponEpoch

        local weapon =
            state.Weapon

        if state.WeaponType
            ~= "Knife"

            or not weapon

            or weapon.Parent
                ~= LocalPlayer.Character then

            return false
        end

        state.KnifeReleaseBusy =
            true

        state.KnifeInputHeld =
            false

        local success =
            pcall(function()

                firesignal(
                    Mouse.Button1Up
                )

            end)

        if not success then

            state.KnifeReleaseBusy =
                false

            return false
        end

        task.delay(
            Config.KnifeRearmDelay,

            function()

                if state.WeaponEpoch
                    ~= epoch

                    or state.WeaponType
                        ~= "Knife"

                    or state.Weapon
                        ~= weapon then

                    return
                end

                state.KnifeCharging =
                    false

                state.KnifeInputHeld =
                    false

                state.KnifeReleaseBusy =
                    false

                state.NextKnifeChargeAttempt =

                    os.clock()
                    + 0.02
            end
        )

        return true
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- REVOLVER
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function pressReloadKey()

        if type(keypress)
            == "function"

            and type(keyrelease)
                == "function" then

            local ok =
                pcall(function()

                    keypress(
                        0x52
                    )

                    task.wait(
                        Config.RevolverReloadKeyHold
                    )

                    keyrelease(
                        0x52
                    )
                end)

            if ok then
                return true
            end
        end

        return pcall(function()

            VirtualInputManager:
            SendKeyEvent(

                true,

                Enum.KeyCode.R,

                false,

                game

            )

            task.wait(
                Config.RevolverReloadKeyHold
            )

            VirtualInputManager:
            SendKeyEvent(

                false,

                Enum.KeyCode.R,

                false,

                game

            )

        end)
    end

    local function reloadRevolver()

        if state.WeaponType
            ~= "Revolver"

            or not state.Weapon

            or state.Weapon.Parent
                ~= LocalPlayer.Character then

            return false
        end

        if state.RevolverReloading then
            return false
        end

        if state.RevolverAmmo ~= nil
            and state.RevolverAmmo > 0 then

            return false
        end

        if state.RevolverReserve ~= nil
            and state.RevolverReserve <= 0 then

            return false
        end

        local now =
            os.clock()

        if now
            - state.LastReloadAttempt
            < Config.RevolverReloadRetry then

            return false
        end

        state.LastReloadAttempt =
            now

        state.RevolverReloading =
            true

        state.RevolverBusy =
            false

        local epoch =
            state.WeaponEpoch

        local weapon =
            state.Weapon

        if not pressReloadKey() then

            state.RevolverReloading =
                false

            return false
        end

        task.spawn(function()

            local started =
                os.clock()

            repeat

                if state.WeaponEpoch
                    ~= epoch

                    or state.Weapon
                        ~= weapon

                    or state.WeaponType
                        ~= "Revolver" then

                    return
                end

                if state.RevolverAmmo ~= nil
                    and state.RevolverAmmo > 0 then

                    state.RevolverReloading =
                        false

                    state.RevolverBusy =
                        false

                    return
                end

                RunService.Heartbeat:
                    Wait()

            until os.clock()
                - started
                >= Config.RevolverReloadTimeout

            if state.WeaponEpoch
                == epoch

                and state.Weapon
                    == weapon

                and state.WeaponType
                    == "Revolver" then

                state.RevolverReloading =
                    false

                state.RevolverBusy =
                    false
            end

        end)

        return true
    end

    local function fireRevolver()

        if state.WeaponType
            ~= "Revolver"

            or not state.RevolverPrimed

            or not state.Weapon

            or state.Weapon.Parent
                ~= LocalPlayer.Character then

            return false
        end

        if state.RevolverAmmo ~= nil
            and state.RevolverAmmo <= 0 then

            return false
        end

        if state.RevolverReloading then
            return false
        end

        if type(firesignal)
            ~= "function" then

            return false
        end

        local epoch =
            state.WeaponEpoch

        local weapon =
            state.Weapon

        local success =
            pcall(function()

                firesignal(
                    Mouse.Button1Down
                )

            end)

        if not success then
            return false
        end

        task.wait(
            Config.RevolverPressTime
        )

        ------------------------------------------------------------
        -- Never send gun release into newly-equipped Knife.
        ------------------------------------------------------------

        if state.WeaponEpoch
            == epoch

            and state.WeaponType
                == "Revolver"

            and state.Weapon
                == weapon

            and weapon.Parent
                == LocalPlayer.Character then

            pcall(function()

                firesignal(
                    Mouse.Button1Up
                )

            end)

            if type(mouse1release)
                == "function" then

                pcall(
                    mouse1release
                )
            end
        end

        return true
    end

    ----------------------------------------------------------------
    -- FEATURE ENABLE FUNCTIONS
    ----------------------------------------------------------------

    local function setSilentAimEnabled(value)

        if not state.Alive then
            return
        end

        if value == true then

            state.SilentAimEnabled =

                installRouter()
                == true

        else

            state.SilentAimEnabled =
                false
        end

        if controls.SilentAim
            and controls.SilentAim:Get()
                ~= state.SilentAimEnabled then

            controls.SilentAim:Set(
                state.SilentAimEnabled,
                false
            )
        end

        if value == true
            and not state.SilentAimEnabled then

            Window:Notify({

                Title =
                    "KAT",

                Content =
                    state.LastError
                    or "Silent Aim unavailable",

                Duration =
                    5,
            })
        end
    end

    local function setTriggerbotEnabled(value)

        if not state.Alive then
            return
        end

        if value == true then

            if not installRouter() then

                state.TriggerbotEnabled =
                    false

                Window:Notify({

                    Title =
                        "KAT",

                    Content =
                        state.LastError
                        or "Triggerbot unavailable",

                    Duration =
                        5,
                })

            else

                state.TriggerbotEnabled =
                    true

                if state.WeaponType
                    == "Knife" then

                    state.NextKnifeChargeAttempt =

                        os.clock()
                        + 0.05
                end
            end

        else

            state.TriggerbotEnabled =
                false

            ------------------------------------------------------------
            -- Knife cleanup
            ------------------------------------------------------------

            if state.WeaponType
                == "Knife"

                and state.KnifeInputHeld

                and state.Weapon

                and state.Weapon.Parent
                    == LocalPlayer.Character

                and type(firesignal)
                    == "function" then

                pcall(function()

                    firesignal(
                        Mouse.Button1Up
                    )

                end)
            end

            ------------------------------------------------------------
            -- Gun cleanup
            ------------------------------------------------------------

            if state.WeaponType
                == "Revolver"

                and state.Weapon

                and state.Weapon.Parent
                    == LocalPlayer.Character then

                if type(firesignal)
                    == "function" then

                    pcall(function()

                        firesignal(
                            Mouse.Button1Up
                        )

                    end)
                end

                if type(mouse1release)
                    == "function" then

                    pcall(
                        mouse1release
                    )
                end
            end

            resetKnifeState()

            state.RevolverBusy =
                false
        end

        if controls.Triggerbot
            and controls.Triggerbot:Get()
                ~= state.TriggerbotEnabled then

            controls.Triggerbot:Set(
                state.TriggerbotEnabled,
                false
            )
        end
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- WEAPON UPDATE LOOP
    --
    -- ONLY weapon detection.
    -- Aimbot is NOT in here.
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    table.insert(
        state.Connections,

        RunService.RenderStepped:
        Connect(function()

            if state.Alive then

                updateEquippedWeapon()
            end

        end)
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- TRIGGERBOT LOOP
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    table.insert(
        state.Connections,

        RunService.RenderStepped:
        Connect(function()

            if not state.Alive
                or not state.TriggerbotEnabled then

                return
            end

            local player,
                triggerPart =

                getClosestTriggerTarget()

            ------------------------------------------------------------
            -- KNIFE
            ------------------------------------------------------------

            if state.WeaponType
                == "Knife" then

                --------------------------------------------------------
                -- Always keep Knife charging while Triggerbot is on.
                --------------------------------------------------------

                if not state.KnifeCharging

                    and not state.KnifeInputHeld

                    and not state.KnifeReleaseBusy

                    and os.clock()
                        >= state.NextKnifeChargeAttempt then

                    state.NextKnifeChargeAttempt =

                        os.clock()
                        + Config.KnifeRetryDelay

                    task.spawn(
                        startKnifeCharge
                    )
                end

                --------------------------------------------------------
                -- No target in FOV yet.
                --------------------------------------------------------

                if not player
                    or not triggerPart then

                    return
                end

                if not knifeReady() then
                    return
                end

                if not validPlayer(player) then
                    return
                end

                --------------------------------------------------------
                -- Target must STILL be inside Trigger FOV immediately
                -- before release.
                --------------------------------------------------------

                local verify =
                    getClosestTriggerTarget()

                if verify
                    ~= player then

                    return
                end

                state.LastTarget =
                    player.Name

                throwKnife()

                return
            end

            ------------------------------------------------------------
            -- REVOLVER
            ------------------------------------------------------------

            if state.WeaponType
                ~= "Revolver" then

                return
            end

            ------------------------------------------------------------
            -- Hard-clear Knife state in gun mode.
            ------------------------------------------------------------

            state.KnifeCharging =
                false

            state.KnifeInputHeld =
                false

            state.KnifeReleaseBusy =
                false

            if not state.RevolverPrimed then
                return
            end

            local revolver =
                state.Weapon

            if not revolver

                or revolver.Parent
                    ~= LocalPlayer.Character

                or classifyWeapon(
                    revolver
                ) ~= "Revolver" then

                return
            end

            ------------------------------------------------------------
            -- AUTO RELOAD
            ------------------------------------------------------------

            if state.RevolverAmmo ~= nil
                and state.RevolverAmmo <= 0 then

                if (
                    state.RevolverReserve == nil
                    or state.RevolverReserve > 0
                )

                and not state.RevolverReloading then

                    task.spawn(
                        reloadRevolver
                    )
                end

                return
            end

            if state.RevolverReloading
                or state.RevolverBusy then

                return
            end

            ------------------------------------------------------------
            -- No player inside Triggerbot FOV.
            ------------------------------------------------------------

            if not player
                or not triggerPart then

                return
            end

            if not validPlayer(player) then
                return
            end

            local now =
                os.clock()

            if now
                - state.LastRevolverShot

                < Config.RevolverCooldown then

                return
            end

            ------------------------------------------------------------
            -- Verify target remains inside Triggerbot FOV.
            ------------------------------------------------------------

            local verify =
                getClosestTriggerTarget()

            if verify
                ~= player then

                return
            end

            state.LastRevolverShot =
                now

            state.LastTarget =
                player.Name

            state.RevolverBusy =
                true

            local epoch =
                state.WeaponEpoch

            local currentWeapon =
                state.Weapon

            task.spawn(function()

                if state.WeaponEpoch
                    ~= epoch

                    or state.WeaponType
                        ~= "Revolver"

                    or state.Weapon
                        ~= currentWeapon then

                    return
                end

                --------------------------------------------------------
                -- Became empty before scheduled fire.
                --------------------------------------------------------

                if state.RevolverAmmo ~= nil
                    and state.RevolverAmmo <= 0 then

                    state.RevolverBusy =
                        false

                    if not state.RevolverReloading then

                        reloadRevolver()
                    end

                    return
                end

                local finalPlayer =
                    getClosestTriggerTarget()

                if state.TriggerbotEnabled

                    and finalPlayer
                        == player

                    and validPlayer(
                        player
                    ) then

                    fireRevolver()
                end

                --------------------------------------------------------
                -- Reset this exact Revolver only.
                --------------------------------------------------------

                if state.WeaponEpoch
                    == epoch

                    and state.WeaponType
                        == "Revolver"

                    and state.Weapon
                        == currentWeapon then

                    state.RevolverBusy =
                        false

                    if state.RevolverAmmo ~= nil
                        and state.RevolverAmmo <= 0

                        and not state.RevolverReloading

                        and (
                            state.RevolverReserve == nil
                            or state.RevolverReserve > 0
                        ) then

                        task.spawn(
                            reloadRevolver
                        )
                    end
                end

            end)

        end)
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- AIMBOT LOOP
    --
    -- COMPLETELY SEPARATE FROM TRIGGERBOT.
    --
    -- Triggerbot return statements CANNOT skip this code.
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    table.insert(
        state.Connections,

        RunService.RenderStepped:
        Connect(function()

            if not state.Alive
                or not state.AimbotEnabled then

                return
            end

            ------------------------------------------------------------
            -- Physical RMB only.
            --
            -- GUI processed-state is intentionally ignored.
            ------------------------------------------------------------

            if not state.RMBHeld then
                return
            end

            local camera =
                Workspace.CurrentCamera

            if not camera then
                return
            end

            local player,
                part =

                getClosestAimbotTarget()

            if not player
                or not part

                or not validPlayer(
                    player
                ) then

                return
            end

            state.LastTarget =
                player.Name

            local point,
                onScreen =

                camera:
                WorldToViewportPoint(
                    part.Position
                )

            if not onScreen
                or point.Z <= 0 then

                return
            end

            local aimOrigin =
                getAimScreenPosition()

            local dx =
                point.X
                - aimOrigin.X

            local dy =
                point.Y
                - aimOrigin.Y

            ------------------------------------------------------------
            -- Executor mouse movement
            ------------------------------------------------------------

            if type(mousemoverel)
                == "function" then

                pcall(function()

                    mousemoverel(

                        dx
                        * state.AimbotSmoothness,

                        dy
                        * state.AimbotSmoothness

                    )

                end)

                return
            end

            ------------------------------------------------------------
            -- Camera fallback
            ------------------------------------------------------------

            local desired =

                CFrame.lookAt(

                    camera.CFrame.Position,

                    part.Position

                )

            camera.CFrame =

                camera.CFrame:
                Lerp(

                    desired,

                    state.AimbotSmoothness

                )

        end)
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- CLEANUP
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local function destroyFOVObject(descriptor)

        if not descriptor
            or not descriptor.Object then

            return
        end

        if descriptor.Type
            == "Drawing" then

            pcall(function()

                descriptor.Object:
                    Remove()
            end)

        else

            pcall(function()

                descriptor.Object:
                    Destroy()
            end)
        end
    end

    local function restore()

        if not state.Alive then
            return
        end

        state.Alive =
            false

        state.Ready =
            false

        state.SilentAimEnabled =
            false

        state.AimbotEnabled =
            false

        state.TriggerbotEnabled =
            false

        state.RMBHeld =
            false

        disconnectWeaponEvent()

        ------------------------------------------------------------
        -- Knife
        ------------------------------------------------------------

        if state.WeaponType
            == "Knife"

            and state.KnifeInputHeld

            and state.Weapon

            and state.Weapon.Parent
                == LocalPlayer.Character

            and type(firesignal)
                == "function" then

            pcall(function()

                firesignal(
                    Mouse.Button1Up
                )

            end)
        end

        ------------------------------------------------------------
        -- Revolver
        ------------------------------------------------------------

        if state.WeaponType
            == "Revolver"

            and state.Weapon

            and state.Weapon.Parent
                == LocalPlayer.Character then

            if type(firesignal)
                == "function" then

                pcall(function()

                    firesignal(
                        Mouse.Button1Up
                    )

                end)
            end

            if type(mouse1release)
                == "function" then

                pcall(
                    mouse1release
                )
            end
        end

        ------------------------------------------------------------
        -- Router
        ------------------------------------------------------------

        if router.Owner
            == state then

            router.Owner =
                nil
        end

        ------------------------------------------------------------
        -- Connections
        ------------------------------------------------------------

        for _, connection
            in ipairs(
                state.Connections
            ) do

            pcall(function()

                connection:
                    Disconnect()
            end)
        end

        state.Connections =
            {}

        for player
            in pairs(
                state.PlayerConnections
            ) do

            disconnectPlayer(player)
        end

        state.PlayerConnections =
            {}

        ------------------------------------------------------------
        -- ESP
        ------------------------------------------------------------

        local players =
            {}

        for player
            in pairs(
                state.ESPAttachments
            ) do

            table.insert(
                players,
                player
            )
        end

        for _, player
            in ipairs(players) do

            removeESPAttachment(player)
        end

        state.ESPAttachments =
            {}

        ------------------------------------------------------------
        -- FOV
        ------------------------------------------------------------

        destroyFOVObject(
            state.SilentFOVObject
        )

        destroyFOVObject(
            state.AimbotFOVObject
        )

        destroyFOVObject(
            state.TriggerFOVObject
        )

        state.SilentFOVObject =
            nil

        state.AimbotFOVObject =
            nil

        state.TriggerFOVObject =
            nil

        if state.FOVScreenGui then

            pcall(function()

                state.FOVScreenGui:
                    Destroy()
            end)

            state.FOVScreenGui =
                nil
        end

        state.SelectRay =
            nil

        state.HandleNamecall =
            nil

        if rawget(_G, KEY)
            == state then

            rawset(
                _G,
                KEY,
                nil
            )
        end
    end

    state.Restore =
        restore

    rawset(
        _G,
        KEY,
        state
    )

    Window:AddCleanup(
        restore
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    local ok,
        failure =

        pcall(function()

            ----------------------------------------------------------------
            -- KAT TAB
            ----------------------------------------------------------------

            local tab =
                Window:
                CreateTab(
                    "KAT",
                    "kat"
                )

            ----------------------------------------------------------------
            -- SILENT AIM
            ----------------------------------------------------------------

            local silent =
                tab:
                CreateSection({

                    Name =
                        "Silent Aim",

                    Icon =
                        "crosshair",

                    Side =
                        "Left",
                })

            controls.SilentAim =

                silent:
                CreateToggle({

                    Name =
                        "Silent Aim",

                    Flag =
                        "KAT_SilentAim",

                    CurrentValue =
                        false,

                    Callback =
                        setSilentAimEnabled,
                })

            controls.SilentTarget =

                silent:
                CreateDropdown({

                    Name =
                        "Target Variation",

                    Flag =
                        "KAT_SilentTarget",

                    Options = {
                        "Head",
                        "Torso",
                        "Random",
                    },

                    CurrentOption =
                        "Head",

                    Callback =
                        function(value)

                            if state.Alive then

                                state.SilentAimTarget =
                                    normalizeTarget(
                                        value
                                    )
                            end
                        end,
                })

            controls.SilentChance =

                silent:
                CreateSlider({

                    Name =
                        "Hit Chance",

                    Flag =
                        "KAT_SilentChance",

                    Range = {
                        0,
                        100,
                    },

                    Increment =
                        1,

                    CurrentValue =
                        100,

                    Suffix =
                        "%",

                    Callback =
                        function(value)

                            if state.Alive then

                                state.SilentAimHitChance =

                                    math.clamp(
                                        tonumber(value)
                                            or 100,
                                        0,
                                        100
                                    )
                            end
                        end,
                })

            controls.WholeScreen =

                silent:
                CreateToggle({

                    Name =
                        "Whole Screen",

                    Info =
                        "When enabled, radius no longer limits Silent Aim.",

                    Flag =
                        "KAT_SilentWholeScreen",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            if state.Alive then

                                state.SilentAimWholeScreen =
                                    value == true
                            end
                        end,
                })

            controls.SilentRadius =

                silent:
                CreateSlider({

                    Name =
                        "FOV Radius",

                    Flag =
                        "KAT_SilentRadius",

                    Range = {
                        25,
                        600,
                    },

                    Increment =
                        1,

                    CurrentValue =
                        175,

                    Suffix =
                        " px",

                    Callback =
                        function(value)

                            if state.Alive then

                                state.SilentAimRadius =

                                    math.clamp(
                                        tonumber(value)
                                            or 175,
                                        25,
                                        600
                                    )
                            end
                        end,
                })

            controls.SilentShowFOV =

                silent:
                CreateToggle({

                    Name =
                        "Show FOV Circle",

                    Flag =
                        "KAT_SilentShowFOV",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.SilentAimShowFOV =
                                value == true
                        end,
                })

            controls.SilentWall =

                silent:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Info =
                        "Only affects Silent Aim.",

                    Flag =
                        "KAT_SilentWall",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.SilentAimWallCheck =
                                value == true
                        end,
                })

            ----------------------------------------------------------------
            -- TRIGGERBOT
            ----------------------------------------------------------------

            local trigger =
                tab:
                CreateSection({

                    Name =
                        "Triggerbot",

                    Icon =
                        "cursor",

                    Side =
                        "Left",
                })

            controls.Triggerbot =

                trigger:
                CreateToggle({

                    Name =
                        "Triggerbot",

                    Flag =
                        "KAT_Triggerbot",

                    CurrentValue =
                        false,

                    Callback =
                        setTriggerbotEnabled,
                })

            ------------------------------------------------------------
            -- NO TARGET VARIATION HERE.
            ------------------------------------------------------------

            controls.TriggerRadius =

                trigger:
                CreateSlider({

                    Name =
                        "FOV Radius",

                    Info =
                        "Fires / throws when a living target enters this radius.",

                    Flag =
                        "KAT_TriggerRadius",

                    Range = {
                        5,
                        300,
                    },

                    Increment =
                        1,

                    CurrentValue =
                        45,

                    Suffix =
                        " px",

                    Callback =
                        function(value)

                            if state.Alive then

                                state.TriggerbotRadius =

                                    math.clamp(
                                        tonumber(value)
                                            or 45,
                                        5,
                                        300
                                    )
                            end
                        end,
                })

            controls.TriggerShowFOV =

                trigger:
                CreateToggle({

                    Name =
                        "Show FOV Circle",

                    Flag =
                        "KAT_TriggerShowFOV",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.TriggerbotShowFOV =
                                value == true
                        end,
                })

            controls.TriggerWall =

                trigger:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Info =
                        "Only affects Triggerbot.",

                    Flag =
                        "KAT_TriggerWall",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.TriggerbotWallCheck =
                                value == true
                        end,
                })

            trigger:
            CreateParagraph({

                Title =
                    "Weapon Automation",

                Content =
                    "Revolver: fires when a living target enters the Triggerbot FOV and automatically reloads.\nKnife: remains charged while equipped, throws when a living target enters the FOV, then automatically begins charging again.",
            })

            ----------------------------------------------------------------
            -- AIMBOT
            ----------------------------------------------------------------

            local aimbot =
                tab:
                CreateSection({

                    Name =
                        "Aimbot",

                    Icon =
                        "crosshair",

                    Side =
                        "Right",
                })

            controls.Aimbot =

                aimbot:
                CreateToggle({

                    Name =
                        "Aimbot",

                    Flag =
                        "KAT_Aimbot",

                    CurrentValue =
                        false,

                    Callback =
                        function(value)

                            state.AimbotEnabled =
                                value == true
                        end,
                })

            aimbot:
            CreateParagraph({

                Title =
                    "Activation",

                Content =
                    "The toggle arms Aimbot. Aim movement only occurs while Right Mouse Button is physically held.",
            })

            controls.AimbotFOV =

                aimbot:
                CreateSlider({

                    Name =
                        "FOV Radius",

                    Flag =
                        "KAT_AimbotFOV",

                    Range = {
                        25,
                        600,
                    },

                    Increment =
                        1,

                    CurrentValue =
                        300,

                    Suffix =
                        " px",

                    Callback =
                        function(value)

                            if state.Alive then

                                state.AimbotFOV =

                                    math.clamp(
                                        tonumber(value)
                                            or 300,
                                        25,
                                        600
                                    )
                            end
                        end,
                })

            controls.AimbotShowFOV =

                aimbot:
                CreateToggle({

                    Name =
                        "Show FOV Circle",

                    Flag =
                        "KAT_AimbotShowFOV",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.AimbotShowFOV =
                                value == true
                        end,
                })

            controls.AimbotSmoothness =

                aimbot:
                CreateSlider({

                    Name =
                        "Smoothness",

                    Flag =
                        "KAT_AimbotSmoothness",

                    Range = {
                        0.05,
                        1,
                    },

                    Increment =
                        0.01,

                    CurrentValue =
                        0.28,

                    Callback =
                        function(value)

                            if state.Alive then

                                state.AimbotSmoothness =

                                    math.clamp(
                                        tonumber(value)
                                            or 0.28,
                                        0.05,
                                        1
                                    )
                            end
                        end,
                })

            controls.AimbotWall =

                aimbot:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Info =
                        "Only affects Aimbot.",

                    Flag =
                        "KAT_AimbotWall",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.AimbotWallCheck =
                                value == true
                        end,
                })

            ----------------------------------------------------------------
            -- STATUS
            ----------------------------------------------------------------

            local diagnostics =
                tab:
                CreateSection({

                    Name =
                        "Status",

                    Icon =
                        "terminal",

                    Side =
                        "Right",
                })

            local status =

                diagnostics:
                CreateParagraph({

                    Title =
                        "KAT Status",

                    Content =
                        "Initializing...",
                })

            local function buildStatus()

                local weapon =
                    state.WeaponType

                if weapon
                    == "Revolver" then

                    weapon =
                        string.format(

                            "Revolver | %s / %s%s",

                            tostring(
                                state.RevolverAmmo
                                or "?"
                            ),

                            tostring(
                                state.RevolverReserve
                                or "?"
                            ),

                            state.RevolverReloading
                                and " | Reloading"
                                or ""

                        )

                elseif weapon
                    == "Knife" then

                    weapon =

                        state.KnifeCharging

                        and string.format(

                            "Knife | Charging %.2fs",

                            math.max(
                                0,
                                os.clock()
                                - state.KnifeChargeStarted
                            )

                        )

                        or "Knife | Ready"
                end

                return string.format(

                    "Weapon: %s\nView: %s\nSilent Aim: %s | %s | %d%% | FOV %d | Wall %s\nAimbot: %s | RMB %s | FOV %d | Wall %s\nTriggerbot: %s | FOV %d | Wall %s\nLast Target: %s\nMatched %d | Redirected %d | Chance Miss %d | Errors %d\nLast Error: %s",

                    weapon,

                    isFirstPerson()
                        and "First Person"
                        or "Third Person",

                    state.SilentAimEnabled
                        and "On"
                        or "Off",

                    state.SilentAimTarget,

                    state.SilentAimHitChance,

                    state.SilentAimRadius,

                    state.SilentAimWallCheck
                        and "On"
                        or "Off",

                    state.AimbotEnabled
                        and "Armed"
                        or "Off",

                    state.RMBHeld
                        and "Held"
                        or "Released",

                    state.AimbotFOV,

                    state.AimbotWallCheck
                        and "On"
                        or "Off",

                    state.TriggerbotEnabled
                        and "On"
                        or "Off",

                    state.TriggerbotRadius,

                    state.TriggerbotWallCheck
                        and "On"
                        or "Off",

                    tostring(
                        state.LastTarget
                        or "None"
                    ),

                    state.Matched,

                    state.Redirected,

                    state.ChanceMiss,

                    state.Errors,

                    tostring(
                        state.LastError
                        or "None"
                    )
                )
            end

            local statusTimer =
                0

            table.insert(
                state.Connections,

                RunService.Heartbeat:
                Connect(function(dt)

                    if not state.Alive then
                        return
                    end

                    statusTimer += dt

                    if statusTimer >= 0.5 then

                        statusTimer = 0

                        status:Set({
                            Content =
                                buildStatus(),
                        })
                    end

                end)
            )

            diagnostics:
            CreateButton({

                Name =
                    "Print Diagnostics",

                Callback =
                    function()

                        print(
                            "[Vitality KAT]\n"
                            .. buildStatus()
                        )
                    end,
            })

            ----------------------------------------------------------------
            ----------------------------------------------------------------
            -- KAT ESP TAB
            ----------------------------------------------------------------
            ----------------------------------------------------------------

            local espTab =
                Window:
                CreateTab(
                    "KAT ESP",
                    "esp"
                )

            local esp =
                espTab:
                CreateSection({

                    Name =
                        "Player ESP",

                    Icon =
                        "esp",

                    Side =
                        "Left",
                })

            controls.ESP =

                esp:
                CreateToggle({

                    Name =
                        "Enable ESP",

                    Flag =
                        "KAT_ESP",

                    CurrentValue =
                        false,

                    Callback =
                        function(value)

                            state.ESPEnabled =
                                value == true

                            refreshESPVisibility()
                        end,
                })

            controls.ESPNames =

                esp:
                CreateToggle({

                    Name =
                        "Names",

                    Flag =
                        "KAT_ESPNames",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.ESPShowNames =
                                value == true

                            refreshESPVisibility()
                        end,
                })

            controls.ESPDistance =

                esp:
                CreateToggle({

                    Name =
                        "Distance",

                    Flag =
                        "KAT_ESPDistance",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.ESPShowDistance =
                                value == true

                            refreshESPVisibility()
                        end,
                })

            controls.ESPHealth =

                esp:
                CreateToggle({

                    Name =
                        "Health",

                    Flag =
                        "KAT_ESPHealth",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            state.ESPShowHealth =
                                value == true

                            refreshESPVisibility()
                        end,
                })

            local threat =
                espTab:
                CreateSection({

                    Name =
                        "Threat Indicator",

                    Icon =
                        "esp",

                    Side =
                        "Right",
                })

            threat:
            CreateParagraph({

                Title =
                    "Colours",

                Content =
                    "Red — no clear line of sight to you.\nGreen — player has a clear world-geometry line of sight to your head.\nBlue — your own character.",
            })

            ----------------------------------------------------------------
            -- RESTORE SAVED VALUES
            ----------------------------------------------------------------

            state.SilentAimTarget =
                normalizeTarget(
                    controls.SilentTarget:Get()
                )

            state.SilentAimHitChance =

                math.clamp(
                    tonumber(
                        controls.SilentChance:Get()
                    ) or 100,
                    0,
                    100
                )

            state.SilentAimWholeScreen =
                controls.WholeScreen:Get()
                == true

            state.SilentAimRadius =

                math.clamp(
                    tonumber(
                        controls.SilentRadius:Get()
                    ) or 175,
                    25,
                    600
                )

            state.SilentAimShowFOV =
                controls.SilentShowFOV:Get()
                == true

            state.SilentAimWallCheck =
                controls.SilentWall:Get()
                == true

            ------------------------------------------------------------

            state.TriggerbotRadius =

                math.clamp(
                    tonumber(
                        controls.TriggerRadius:Get()
                    ) or 45,
                    5,
                    300
                )

            state.TriggerbotShowFOV =
                controls.TriggerShowFOV:Get()
                == true

            state.TriggerbotWallCheck =
                controls.TriggerWall:Get()
                == true

            ------------------------------------------------------------

            state.AimbotEnabled =
                controls.Aimbot:Get()
                == true

            state.AimbotFOV =

                math.clamp(
                    tonumber(
                        controls.AimbotFOV:Get()
                    ) or 300,
                    25,
                    600
                )

            state.AimbotShowFOV =
                controls.AimbotShowFOV:Get()
                == true

            state.AimbotSmoothness =

                math.clamp(
                    tonumber(
                        controls.AimbotSmoothness:Get()
                    ) or 0.28,
                    0.05,
                    1
                )

            state.AimbotWallCheck =
                controls.AimbotWall:Get()
                == true

            ------------------------------------------------------------

            state.ESPEnabled =
                controls.ESP:Get()
                == true

            state.ESPShowNames =
                controls.ESPNames:Get()
                == true

            state.ESPShowDistance =
                controls.ESPDistance:Get()
                == true

            state.ESPShowHealth =
                controls.ESPHealth:Get()
                == true

            refreshESPVisibility()

            ------------------------------------------------------------
            -- ENABLE SAVED COMBAT STATES
            ------------------------------------------------------------

            setSilentAimEnabled(
                controls.SilentAim:Get()
            )

            setTriggerbotEnabled(
                controls.Triggerbot:Get()
            )

        end)

    if not ok then

        restore()

        error(
            "KAT module initialization failed: "
            .. tostring(failure),
            0
        )
    end

    ----------------------------------------------------------------
    -- INITIAL WEAPON
    ----------------------------------------------------------------

    updateEquippedWeapon()

    state.Ready =
        true

    Window:Notify({

        Title =
            "KAT",

        Content =
            "KAT module loaded. Aimbot uses independent RMB aiming; all three combat features now have independent FOV and wall checks.",

        Duration =
            4,
    })

    return true
end
