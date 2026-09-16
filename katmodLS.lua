--[[
    vitality's hub / KAT / 1.3.0-LS

    TABS
    ----
    KAT
        Silent Aim
        Aimbot
        Triggerbot
        Diagnostics

    KAT ESP
        Player ESP
        Names
        Distance
        Health
        Threat / LOS indicator


    SILENT AIM
    ----------
    - Toggle
    - Head / Torso / Random
    - Hit chance 0-100%
    - Whole screen / radius
    - Independent wall check


    AIMBOT
    ------
    - Toggle arms the feature
    - ONLY active while holding RMB
    - FOV
    - Smoothness
    - Independent wall check


    TRIGGERBOT
    ----------
    - Restored original player-under-cursor behavior
    - Head / Torso / Random used as target/LOS reference
    - Independent wall check
    - Revolver triggerbot
    - Revolver auto reload
    - Knife auto charge / throw
    - Strict Knife / Revolver isolation


    ESP
    ---
    Ported from working standalone KAT ESP:
    - Highlight
    - Username
    - Distance
    - Health
    - Red default
    - Green when enemy has clear LOS to your head
]]

return function(context)

    assert(type(context) == "table", "KAT requires module context")

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
        "__VITALITY_KAT_MODULE_BUILD_STATE_V13"

    local ROUTER_KEY =
        "__VITALITY_KAT_COMBAT_ROUTER_V13"

    ----------------------------------------------------------------
    -- PREVIOUS MODULE INSTANCE
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

        pcall(previous.Restore)
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
        -- Player lifecycle
        ------------------------------------------------------------

        DeadTargetBlockTime = 2.5,

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
        -- Silent Aim
        ----------------------------------------------------------------

        SilentAimEnabled = false,

        SilentAimWholeScreen = true,
        SilentAimRadius = 175,

        SilentAimTarget = "Head",
        SilentAimHitChance = 100,

        SilentAimWallCheck = true,

        ----------------------------------------------------------------
        -- Aimbot
        ----------------------------------------------------------------

        AimbotEnabled = false,

        AimbotFOV = 300,
        AimbotSmoothness = 0.28,

        AimbotWallCheck = true,

        ----------------------------------------------------------------
        -- Triggerbot
        ----------------------------------------------------------------

        TriggerbotEnabled = false,

        TriggerbotTarget = "Head",

        TriggerbotWallCheck = true,

        ----------------------------------------------------------------
        -- Equipped weapon
        ----------------------------------------------------------------

        Weapon = nil,
        WeaponType = "None",

        WeaponEpoch = 0,
        WeaponChangedAt = 0,

        WeaponEventConnection = nil,

        ----------------------------------------------------------------
        -- Revolver
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
        -- Knife
        ----------------------------------------------------------------

        KnifeCharging = false,
        KnifeInputHeld = false,
        KnifeReleaseBusy = false,

        KnifeChargeStarted = 0,

        LastKnifeStartCharge = 0,
        LastKnifeChargeRelease = 0,

        NextKnifeChargeAttempt = 0,

        ----------------------------------------------------------------
        -- Death / targets
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
        -- Diagnostics
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
    -- HELPERS
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
            character:FindFirstChild("Head")

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
            character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")

        if part
            and part:IsA("BasePart") then

            return part
        end

        return nil
    end

    local function getTargetPart(
        character,
        mode,
        resolvedMode
    )

        local resolved =
            resolvedMode
            or resolveTargetMode(mode)

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
    -- DEAD CACHE
    ----------------------------------------------------------------

    local function markDead(player)

        if not player then
            return
        end

        state.DeadTargets[player] =
            os.clock()
            + Config.DeadTargetBlockTime

        if state.LastTarget == player then
            state.LastTarget = nil
        end
    end

    local function clearDead(player)

        if player then
            state.DeadTargets[player] = nil
        end
    end

    local function temporarilyDead(player)

        local expiry =
            state.DeadTargets[player]

        if not expiry then
            return false
        end

        if os.clock() >= expiry then

            state.DeadTargets[player] = nil

            return false
        end

        return true
    end

    local function validPlayer(player)

        if not player
            or player == LocalPlayer then

            return false
        end

        if temporarilyDead(player) then
            return false
        end

        local character =
            player.Character

        if not alive(character) then

            markDead(player)

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
    -- GENERIC VISIBILITY TEST
    --
    -- IMPORTANT:
    -- each feature decides whether it wants to call this.
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
                in ipairs(extraIgnore) do

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
                part.Position - origin,
                params
            )

        if not result then
            return true
        end

        return result.Instance
            and result.Instance:
                IsDescendantOf(
                    part.Parent
                )
    end

    ----------------------------------------------------------------
    -- PLAYER UNDER CURSOR
    --
    -- RESTORED WORKING TRIGGERBOT DETECTOR.
    --
    -- It accepts ANY body part belonging to a living player.
    ----------------------------------------------------------------

    local function getPlayerUnderCursor()

        local target =
            Mouse.Target

        if not target then
            return nil
        end

        local ragdolls =
            Workspace:
            FindFirstChild(
                "Ragdolls"
            )

        if ragdolls
            and target:
                IsDescendantOf(
                    ragdolls
                ) then

            return nil
        end

        local object =
            target

        while object
            and object ~= Workspace do

            if object:IsA("Model") then

                local player =
                    Players:
                    GetPlayerFromCharacter(
                        object
                    )

                if player then

                    if player.Character
                        ~= object then

                        return nil
                    end

                    if validPlayer(player) then

                        return
                            player,
                            target
                    end

                    return nil
                end
            end

            object =
                object.Parent
        end

        return nil
    end

    ----------------------------------------------------------------
    -- FEATURE-SPECIFIC WALL CHECKS
    ----------------------------------------------------------------

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

    local function passesAimbotWallCheck(
        part
    )

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

    local function passesTriggerWallCheck(
        player,
        resolvedMode
    )

        if not state.TriggerbotWallCheck then
            return true
        end

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return false
        end

        local part =
            getTargetPart(
                player.Character,
                state.TriggerbotTarget,
                resolvedMode
            )

        if not part then
            return false
        end

        return hasVisibility(
            camera.CFrame.Position,
            part
        )
    end

    ----------------------------------------------------------------
    -- CLOSEST AIMBOT TARGET
    ----------------------------------------------------------------

    local function getClosestAimbotTarget()

        local camera =
            Workspace.CurrentCamera

        if not camera then
            return nil
        end

        local cursor =
            Input:GetMouseLocation()

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

                -- Aimbot itself remains head-based.
                local part =
                    getHead(player.Character)
                    or getTorso(player.Character)

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
                            point.X - cursor.X

                        local dy =
                            point.Y - cursor.Y

                        local distance =
                            dx * dx + dy * dy

                        if distance < bestDistance then

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

        return bestPlayer,
            bestPart
    end

    ----------------------------------------------------------------
    -- PLAYER CONNECTION CLEANUP
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
                connection:Disconnect()
            end)
        end

        state.PlayerConnections[player] =
            nil
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- ESP
    ----------------------------------------------------------------
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

        return character:
            FindFirstChild("Head")
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

    ----------------------------------------------------------------
    -- ORIGINAL ESP LOS BEHAVIOR
    ----------------------------------------------------------------

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

    local function removeESPAttachment(
        player
    )

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
    -- ORIGINAL BILLBOARD STRUCTURE
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

        nameLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                0
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
            Color3.fromRGB(
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

        distanceLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                16
            )

        distanceLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                20
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
            Color3.fromRGB(
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

        hpLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                14
            )

        hpLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                36
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
            Color3.fromRGB(
                0,
                0,
                0
            )

        hpLabel.Text =
            "—"

        hpLabel.Parent =
            billboard

        ------------------------------------------------------------
        -- ORIGINAL ESP PARENT
        ------------------------------------------------------------

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
            1 - Config.FillAlpha

        highlight.OutlineTransparency =
            1 - Config.OutlineAlpha

        ------------------------------------------------------------
        -- ORIGINAL ESP PARENT
        ------------------------------------------------------------

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

        ------------------------------------------------------------
        -- Apply current module toggle values
        ------------------------------------------------------------

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
    -- CHARACTER ADDED
    --
    -- RESTORED ORIGINAL WAIT ORDER.
    ----------------------------------------------------------------

    local function onCharacterAdded(
        player,
        character
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

        clearDead(player)

        ------------------------------------------------------------
        -- Death watchers
        ------------------------------------------------------------

        state.PlayerConnections[player] =
            state.PlayerConnections[player]
            or {}

        table.insert(
            state.PlayerConnections[player],

            humanoid.Died:
            Connect(function()

                if player ~= LocalPlayer then
                    markDead(player)
                end

            end)
        )

        table.insert(
            state.PlayerConnections[player],

            humanoid.HealthChanged:
            Connect(function(health)

                if health <= 0
                    and player ~= LocalPlayer then

                    markDead(player)
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
            Connect(function()

                removeESPAttachment(
                    player
                )

                if player ~= LocalPlayer then
                    markDead(player)
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

        removeESPAttachment(
            player
        )

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
    -- ORIGINAL ESP UPDATE LOOP
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

                    removeESPAttachment(
                        player
                    )

                    continue
                end

                local character =
                    player.Character

                if not character
                    or not character.Parent then

                    removeESPAttachment(
                        player
                    )

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

                        local ignore = {
                            character,
                            myCharacter,
                        }

                        local canSee =

                            ESPHasLineOfSight(
                                theirHead,
                                myHead,
                                ignore
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

                    else

                        if attachment.canSeeMe then

                            attachment.canSeeMe =
                                false

                            applyESPColour(
                                attachment,
                                false,
                                false
                            )
                        end
                    end
                end

                --------------------------------------------------------
                -- Distance
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
                -- Health
                --------------------------------------------------------

                if state.ESPShowHealth
                    and attachment.hpLabel then

                    local humanoid =
                        character:
                        FindFirstChildOfClass(
                            "Humanoid"
                        )

                    if humanoid then

                        local maxHP =
                            math.max(
                                humanoid.MaxHealth,
                                1
                            )

                        local fraction =
                            humanoid.Health
                            / maxHP

                        attachment.hpLabel.Text =

                            string.format(
                                "%d / %d",

                                math.floor(
                                    humanoid.Health
                                    + 0.5
                                ),

                                math.floor(
                                    maxHP + 0.5
                                )
                            )

                        attachment.hpLabel.TextColor3 =

                            healthColour(
                                fraction
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
                    otherTool or object
            end
        end

        ------------------------------------------------------------
        -- Exactly one recognized equipped weapon
        ------------------------------------------------------------

        if #recognized == 1 then

            return
                recognized[1].Object,
                recognized[1].Type
        end

        ------------------------------------------------------------
        -- Both can briefly exist during switch.
        --
        -- Run neither combat system.
        ------------------------------------------------------------

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
    -- WEAPON RESET
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
    -- REVOLVER SERVER EVENT TRACKING
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
        -- Only release stale mouse input AFTER gun is confirmed.
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
        -- Invalidates ALL old async weapon tasks.
        ------------------------------------------------------------

        state.WeaponEpoch += 1

        local epoch =
            state.WeaponEpoch

        ------------------------------------------------------------
        -- STATE ONLY during ambiguous switch.
        ------------------------------------------------------------

        if oldType == "Knife" then

            resetKnifeState()

        elseif oldType == "Revolver" then

            resetRevolverState()
        end

        state.Weapon =
            weapon

        state.WeaponType =
            weaponType

        state.WeaponChangedAt =
            os.clock()

        if weaponType == "Knife" then

            resetKnifeState()

            state.NextKnifeChargeAttempt =

                os.clock()
                + Config.KnifeEquipSettle

            return
        end

        if weaponType == "Revolver" then

            resetRevolverState()

            task.spawn(
                primeRevolver,
                weapon,
                epoch
            )

            return
        end

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

        local camera =
            Workspace.CurrentCamera

        local character =
            LocalPlayer.Character

        local humanoid =
            character
            and character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        if not state.Alive
            or not state.SilentAimEnabled
            or not camera
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
        -- ORIGINAL IGNORE BEHAVIOR
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
        -- TARGET SELECTION
        ------------------------------------------------------------

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

                    local position =
                        part.Position

                    local point,
                        onScreen =

                        camera:
                        WorldToScreenPoint(
                            position
                        )

                    if onScreen
                        and point.Z > 0 then

                        local dx =
                            point.X
                            - Mouse.X

                        local dy =
                            point.Y
                            - Mouse.Y

                        local distance =
                            dx * dx
                            + dy * dy

                        local direction =
                            position
                            - ray.Origin

                        local length =
                            direction.Magnitude

                        if distance <= bestDistance
                            and length > 0.001
                            and length <= magnitude then

                            ------------------------------------------------
                            -- SILENT AIM'S OWN WALL CHECK ONLY
                            ------------------------------------------------

                            local visible =
                                passesSilentWallCheck(
                                    ray.Origin,
                                    part,
                                    ignore
                                )

                            if visible then

                                bestDistance =
                                    distance

                                bestPosition =
                                    position

                                bestPlayer =
                                    player
                            end
                        end
                    end
                end
            end
        end

        if bestPlayer then
            state.LastTarget =
                bestPlayer.Name
        end

        if bestPosition then

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

        state.NoTarget += 1

        return nil
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
        -- KNIFE / REVOLVER EVENTS
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
            -- Knife
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
            -- Revolver
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
                        == "table" then

                    if args[2][1]
                        == "Start" then

                        state.RevolverReloading =
                            true
                    end
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
    -- INSTALL ROUTER ONCE
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

            ------------------------------------------------------------
            -- Raycasts performed by selectors can alter namecall method.
            ------------------------------------------------------------

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

            ------------------------------------------------------------
            -- Weapon switched:
            -- DON'T release into the new weapon.
            ------------------------------------------------------------

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

        ------------------------------------------------------------
        -- Only cleanup if the SAME knife is still equipped.
        ------------------------------------------------------------

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

            local success =
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

            if success then
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
    -- FEATURE TOGGLES
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

                Title = "KAT",

                Content =
                    state.LastError
                    or "Silent aim unavailable",

                Duration = 5,
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

                    Title = "KAT",

                    Content =
                        state.LastError
                        or "Triggerbot unavailable",

                    Duration = 5,
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
            -- Cleanly release current knife only if knife still equipped.
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
            -- Cleanly release revolver only if revolver still equipped.
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
    -- MAIN COMBAT LOOP
    ----------------------------------------------------------------
    ----------------------------------------------------------------

    table.insert(
        state.Connections,

        RunService.RenderStepped:
        Connect(function()

            if not state.Alive then
                return
            end

            ------------------------------------------------------------
            -- Always determine weapon first.
            ------------------------------------------------------------

            updateEquippedWeapon()

            ------------------------------------------------------------
            ------------------------------------------------------------
            -- TRIGGERBOT
            ------------------------------------------------------------
            ------------------------------------------------------------

            if state.TriggerbotEnabled
                and not Input:
                    GetFocusedTextBox() then

                --------------------------------------------------------
                -- KNIFE
                --------------------------------------------------------

                if state.WeaponType
                    == "Knife" then

                    ----------------------------------------------------
                    -- Automatically keep knife charged.
                    ----------------------------------------------------

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

                    ----------------------------------------------------
                    -- Throw only when charged and player under cursor.
                    ----------------------------------------------------

                    if knifeReady() then

                        local player =
                            getPlayerUnderCursor()

                        if player
                            and validPlayer(
                                player
                            ) then

                            local resolvedMode =
                                resolveTargetMode(
                                    state.TriggerbotTarget
                                )

                            ------------------------------------------------
                            -- TRIGGERBOT'S OWN WALL CHECK
                            ------------------------------------------------

                            if passesTriggerWallCheck(
                                player,
                                resolvedMode
                            ) then

                                ------------------------------------------------
                                -- Restore original detector:
                                -- verification only checks SAME PLAYER remains
                                -- under cursor.
                                ------------------------------------------------

                                local verify =
                                    getPlayerUnderCursor()

                                if verify == player then

                                    state.LastTarget =
                                        player.Name

                                    throwKnife()
                                end
                            end
                        end
                    end

                    --------------------------------------------------------
                    -- Important:
                    -- do not run revolver code this frame.
                    --------------------------------------------------------

                    return
                end

                --------------------------------------------------------
                -- REVOLVER
                --------------------------------------------------------

                if state.WeaponType
                    == "Revolver" then

                    ----------------------------------------------------
                    -- Knife state cannot leak into gun mode.
                    ----------------------------------------------------

                    state.KnifeCharging =
                        false

                    state.KnifeInputHeld =
                        false

                    state.KnifeReleaseBusy =
                        false

                    ----------------------------------------------------
                    -- Wait for confirmed equipped revolver.
                    ----------------------------------------------------

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

                    ----------------------------------------------------
                    -- EMPTY / AUTO RELOAD
                    ----------------------------------------------------

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

                    ----------------------------------------------------
                    -- ORIGINAL WORKING TRIGGER DETECTION:
                    -- ANY body part underneath real cursor.
                    ----------------------------------------------------

                    local player =
                        getPlayerUnderCursor()

                    if not player then
                        return
                    end

                    if not validPlayer(
                        player
                    ) then

                        return
                    end

                    local resolvedMode =
                        resolveTargetMode(
                            state.TriggerbotTarget
                        )

                    ----------------------------------------------------
                    -- TRIGGERBOT WALL CHECK ONLY
                    ----------------------------------------------------

                    if not passesTriggerWallCheck(
                        player,
                        resolvedMode
                    ) then

                        return
                    end

                    local now =
                        os.clock()

                    if now
                        - state.LastRevolverShot
                        < Config.RevolverCooldown then

                        return
                    end

                    ----------------------------------------------------
                    -- SAME PLAYER verification.
                    --
                    -- Do not require exact Head / Torso Mouse.Target.
                    ----------------------------------------------------

                    if getPlayerUnderCursor()
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

                        ------------------------------------------------
                        -- Empty before task runs.
                        ------------------------------------------------

                        if state.RevolverAmmo ~= nil
                            and state.RevolverAmmo <= 0 then

                            state.RevolverBusy =
                                false

                            if not state.RevolverReloading then

                                reloadRevolver()
                            end

                            return
                        end

                        ------------------------------------------------
                        -- Final working-style validation
                        ------------------------------------------------

                        local finalPlayer =
                            getPlayerUnderCursor()

                        if state.TriggerbotEnabled
                            and finalPlayer == player
                            and validPlayer(player)
                            and passesTriggerWallCheck(
                                player,
                                resolvedMode
                            ) then

                            fireRevolver()
                        end

                        ------------------------------------------------
                        -- Reset same revolver only.
                        ------------------------------------------------

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

                    return
                end
            end

            ------------------------------------------------------------
            ------------------------------------------------------------
            -- AIMBOT
            --
            -- Toggle only ARMS it.
            -- RMB MUST currently be held.
            ------------------------------------------------------------
            ------------------------------------------------------------

            if state.AimbotEnabled

                and not Input:
                    GetFocusedTextBox()

                and Input:
                    IsMouseButtonPressed(
                        Enum.UserInputType.MouseButton2
                    ) then

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

                local point =
                    camera:
                    WorldToViewportPoint(
                        part.Position
                    )

                local cursor =
                    Input:
                    GetMouseLocation()

                local dx =
                    point.X
                    - cursor.X

                local dy =
                    point.Y
                    - cursor.Y

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

                else

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
                end
            end

        end)
    )

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- CLEANUP
    ----------------------------------------------------------------
    ----------------------------------------------------------------

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

        disconnectWeaponEvent()

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
        -- Revolver cleanup
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
        -- Global connections
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

        ------------------------------------------------------------
        -- Per player connections
        ------------------------------------------------------------

        for player
            in pairs(
                state.PlayerConnections
            ) do

            disconnectPlayer(
                player
            )
        end

        state.PlayerConnections =
            {}

        ------------------------------------------------------------
        -- ESP
        ------------------------------------------------------------

        local removePlayers =
            {}

        for player
            in pairs(
                state.ESPAttachments
            ) do

            table.insert(
                removePlayers,
                player
            )
        end

        for _, player
            in ipairs(
                removePlayers
            ) do

            removeESPAttachment(
                player
            )
        end

        state.ESPAttachments =
            {}

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
            -- MAIN GAME TAB
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

            controls.SilentHitChance =

                silent:
                CreateSlider({

                    Name =
                        "Hit Chance",

                    Flag =
                        "KAT_SilentHitChance",

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
                        "Radius",

                    Info =
                        "Used while Whole Screen is disabled",

                    Flag =
                        "KAT_SilentRadius",

                    Range = {
                        25,
                        500,
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
                                        500
                                    )
                            end
                        end,
                })

            controls.SilentWallCheck =

                silent:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Info =
                        "Only affects Silent Aim",

                    Flag =
                        "KAT_SilentWallCheck",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            if state.Alive then

                                state.SilentAimWallCheck =
                                    value == true
                            end
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

            controls.TriggerTarget =

                trigger:
                CreateDropdown({

                    Name =
                        "Target Variation",

                    Info =
                        "Used as trigger LOS/body reference; cursor may touch any player body part.",

                    Flag =
                        "KAT_TriggerTarget",

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

                                state.TriggerbotTarget =
                                    normalizeTarget(
                                        value
                                    )
                            end
                        end,
                })

            controls.TriggerWallCheck =

                trigger:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Info =
                        "Only affects Triggerbot",

                    Flag =
                        "KAT_TriggerWallCheck",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            if state.Alive then

                                state.TriggerbotWallCheck =
                                    value == true
                            end
                        end,
                })

            trigger:
            CreateParagraph({

                Title =
                    "Weapon Automation",

                Content =
                    "Revolver: fires when your cursor is over any living player and automatically reloads.\nKnife: automatically charges, throws when a living player is detected, then begins charging again.",
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

                            if state.Alive then

                                state.AimbotEnabled =
                                    value == true
                            end
                        end,
                })

            aimbot:
            CreateParagraph({

                Title =
                    "Hold Activation",

                Content =
                    "Aimbot is only active while Right Mouse Button is held. The toggle only arms/disarms it.",
            })

            controls.AimbotFOV =

                aimbot:
                CreateSlider({

                    Name =
                        "FOV",

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

            controls.AimbotWallCheck =

                aimbot:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Info =
                        "Only affects Aimbot",

                    Flag =
                        "KAT_AimbotWallCheck",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)

                            if state.Alive then

                                state.AimbotWallCheck =
                                    value == true
                            end
                        end,
                })

            ----------------------------------------------------------------
            -- DIAGNOSTICS
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

                local weaponText =
                    state.WeaponType

                if state.WeaponType
                    == "Revolver" then

                    weaponText =
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

                elseif state.WeaponType
                    == "Knife" then

                    weaponText =
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
                    "Weapon: %s\nSilent Aim: %s | Wall: %s | %s | %d%%\nAimbot: %s | RMB | Wall: %s\nTriggerbot: %s | Wall: %s | %s\nMatched: %d | Redirected: %d | No Target: %d | Chance Miss: %d\nLast Target: %s\nLast Error: %s",

                    weaponText,

                    state.SilentAimEnabled
                        and "On"
                        or "Off",

                    state.SilentAimWallCheck
                        and "On"
                        or "Off",

                    state.SilentAimTarget,

                    state.SilentAimHitChance,

                    state.AimbotEnabled
                        and "Armed"
                        or "Off",

                    state.AimbotWallCheck
                        and "On"
                        or "Off",

                    state.TriggerbotEnabled
                        and "On"
                        or "Off",

                    state.TriggerbotWallCheck
                        and "On"
                        or "Off",

                    state.TriggerbotTarget,

                    state.Matched,

                    state.Redirected,

                    state.NoTarget,

                    state.ChanceMiss,

                    tostring(
                        state.LastTarget
                        or "None"
                    ),

                    tostring(
                        state.LastError
                        or "None"
                    )
                )
            end

            diagnostics:
            CreateButton({

                Name =
                    "Print Diagnostics",

                Callback =
                    function()

                        if state.Alive then

                            print(
                                "[Vitality KAT LS]\n"
                                .. buildStatus()
                            )
                        end
                    end,
            })

            diagnostics:
            CreateButton({

                Name =
                    "Reset Diagnostics",

                Callback =
                    function()

                        state.Matched = 0
                        state.Redirected = 0
                        state.NoTarget = 0
                        state.ChanceMiss = 0
                        state.Errors = 0

                        state.LastTarget = nil
                        state.LastError = nil
                        state.LastRayMag = nil
                    end,
            })

            ----------------------------------------------------------------
            ----------------------------------------------------------------
            -- KAT-SPECIFIC ESP TAB
            ----------------------------------------------------------------
            ----------------------------------------------------------------

            local espTab =
                Window:
                CreateTab(
                    "KAT ESP",
                    "esp"
                )

            local espMain =
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

                espMain:
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

                espMain:
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

                espMain:
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

                espMain:
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

            local espThreat =
                espTab:
                CreateSection({

                    Name =
                        "Threat Indicator",

                    Icon =
                        "esp",

                    Side =
                        "Right",
                })

            espThreat:
            CreateParagraph({

                Title =
                    "Colour Meaning",

                Content =
                    "RED — default / no clear line of sight.\nGREEN — the player currently has a clear geometry line of sight to your head.\nBLUE — your own character.",
            })

            espThreat:
            CreateParagraph({

                Title =
                    "KAT ESP",

                Content =
                    "This tab uses the original KAT-specific Highlight + Billboard ESP implementation rather than the generic hub ESP.",
            })

            ----------------------------------------------------------------
            -- RESTORE SAVED CONFIG
            ----------------------------------------------------------------

            state.SilentAimTarget =
                normalizeTarget(
                    controls.SilentTarget:Get()
                )

            state.SilentAimHitChance =

                math.clamp(
                    tonumber(
                        controls.SilentHitChance:Get()
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
                    500
                )

            state.SilentAimWallCheck =
                controls.SilentWallCheck:Get()
                == true

            ------------------------------------------------------------

            state.TriggerbotTarget =
                normalizeTarget(
                    controls.TriggerTarget:Get()
                )

            state.TriggerbotWallCheck =
                controls.TriggerWallCheck:Get()
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

            state.AimbotSmoothness =

                math.clamp(
                    tonumber(
                        controls.AimbotSmoothness:Get()
                    ) or 0.28,
                    0.05,
                    1
                )

            state.AimbotWallCheck =
                controls.AimbotWallCheck:Get()
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
            -- Feature enable state
            ------------------------------------------------------------

            setSilentAimEnabled(
                controls.SilentAim:Get()
            )

            setTriggerbotEnabled(
                controls.Triggerbot:Get()
            )

            ----------------------------------------------------------------
            -- Status updater
            ----------------------------------------------------------------

            local statusElapsed =
                0

            table.insert(
                state.Connections,

                RunService.Heartbeat:
                Connect(function(dt)

                    if not state.Alive then
                        return
                    end

                    statusElapsed += dt

                    if statusElapsed >= 0.5 then

                        statusElapsed = 0

                        status:Set({
                            Content =
                                buildStatus(),
                        })
                    end

                end)
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
    -- INITIAL WEAPON SCAN
    ----------------------------------------------------------------

    updateEquippedWeapon()

    state.Ready =
        true

    Window:Notify({

        Title =
            "KAT",

        Content =
            "KAT controls loaded. ESP restored to its game-specific tab. Aimbot requires RMB.",

        Duration =
            4,
    })

    return true
end
