-- vitality's hub / KAT / 1.2.0-LS
-- KAT-specific module:
--   Silent Aim
--   RMB-hold Aimbot
--   Revolver + Knife Triggerbot
--   Revolver Auto Reload
--   Knife Auto Charge / Auto Throw
--   KAT LOS ESP
--
-- Requires Vitality library/window context.

return function(context)

    assert(
        type(context) == "table",
        "KAT requires a module context"
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


    --====================================================
    -- KEYS
    --====================================================

    local KEY =
        "__VITALITY_KAT_MODULE_BUILD_STATE"

    local ROUTER_KEY =
        "__VITALITY_KAT_LS_COMBAT_ROUTER_V2"


    --====================================================
    -- PREVIOUS INSTANCE
    --====================================================

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


    --====================================================
    -- SERVICES
    --====================================================

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
            "KAT requires a Roblox client"
        )


    local Mouse =
        LocalPlayer:GetMouse()


    --====================================================
    -- ESP PARENT
    --====================================================

    local EspParent =
        CoreGui


    if type(gethui) == "function" then

        local ok,
            result =
            pcall(
                gethui
            )


        if ok and result then
            EspParent = result
        end
    end


    --====================================================
    -- STATE
    --====================================================

    local state = {

        Window = Window,

        Alive = true,

        Ready = false,


        Connections = {},

        PlayerConnections = {},


        --==============================================
        -- SILENT AIM
        --==============================================

        SilentAimEnabled = false,

        SilentAimWholeScreen = true,

        SilentAimRadius = 175,

        SilentAimTargetMode = "Head",

        SilentAimHitChance = 100,

        WallCheck = true,


        --==============================================
        -- AIMBOT
        --==============================================

        AimbotEnabled = false,

        AimbotFOV = 300,

        AimbotSmoothness = 0.28,


        --==============================================
        -- TRIGGERBOT
        --==============================================

        TriggerbotEnabled = false,

        TriggerTargetMode = "Head",


        --==============================================
        -- WEAPON STATE
        --==============================================

        Weapon = nil,

        WeaponType = "None",

        WeaponEpoch = 0,

        WeaponChangedAt = 0,


        --==============================================
        -- REVOLVER
        --==============================================

        RevolverBusy = false,

        RevolverPrimed = false,

        RevolverAmmo = nil,

        RevolverReserve = nil,

        RevolverReloading = false,

        LastReloadAttempt = 0,

        LastRevolverShot = 0,

        LastWeaponFired = 0,

        WeaponEventConnection = nil,


        --==============================================
        -- KNIFE
        --==============================================

        KnifeCharging = false,

        KnifeInputHeld = false,

        KnifeReleaseBusy = false,

        KnifeChargeStarted = 0,

        LastKnifeStartCharge = 0,

        LastKnifeChargeRelease = 0,

        NextKnifeChargeAttempt = 0,


        --==============================================
        -- ESP
        --==============================================

        ESPEnabled = false,

        ESPNames = true,

        ESPDistance = true,

        ESPHealth = true,

        ESPAttachments = {},


        --==============================================
        -- TARGET / DEATH
        --==============================================

        DeadTargets = {},

        LastTarget = nil,


        --==============================================
        -- DIAGNOSTICS
        --==============================================

        Matched = 0,

        Redirected = 0,

        MissedChance = 0,

        Errors = 0,

        LastError = nil,
    }


    --====================================================
    -- CONFIG CONSTANTS
    --====================================================

    local Config = {

        MinimumRayLength = 100,


        RevolverCooldown = 0.12,

        RevolverPressTime = 0.012,

        RevolverEquipSettle = 0.15,

        RevolverReloadRetry = 0.35,

        RevolverReloadTimeout = 2.75,

        RevolverReloadKeyHold = 0.035,


        KnifeMinimumCharge = 0.70,

        KnifeEquipSettle = 0.15,

        KnifeRearmDelay = 0.12,

        KnifeRetryDelay = 0.15,


        DeadTargetBlockTime = 2.5,


        ESPLOSRange = 2500,

        ESPLOSInterval = 0.10,


        ESPRedFill =
            Color3.fromRGB(
                240,
                60,
                80
            ),

        ESPRedOutline =
            Color3.fromRGB(
                255,
                140,
                150
            ),


        ESPGreenFill =
            Color3.fromRGB(
                70,
                230,
                110
            ),

        ESPGreenOutline =
            Color3.fromRGB(
                160,
                255,
                180
            ),


        ESPSelfFill =
            Color3.fromRGB(
                120,
                200,
                255
            ),

        ESPSelfOutline =
            Color3.fromRGB(
                180,
                230,
                255
            ),


        ESPFillAlpha = 0.35,

        ESPOutlineAlpha = 0.90,
    }


    local controls = {}


    --====================================================
    -- HELPERS
    --====================================================

    local function normalizeMode(value)

        if value == "Torso" then
            return "Torso"
        end


        if value == "Random" then
            return "Random"
        end


        return "Head"
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


    local function characterAlive(character)

        if not character
            or not character.Parent then

            return false
        end


        local humanoid =
            getHumanoid(
                character
            )


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


    --====================================================
    -- DEAD TARGET CACHE
    --====================================================

    local function markDead(player)

        if not player then
            return
        end


        state.DeadTargets[player] =

            os.clock()
            + Config.DeadTargetBlockTime


        if state.LastTarget
            == player then

            state.LastTarget = nil
        end
    end


    local function clearDead(player)

        if player then
            state.DeadTargets[player] = nil
        end
    end


    local function cachedDead(player)

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


        if cachedDead(player) then
            return false
        end


        local character =
            player.Character


        if not characterAlive(
            character
        ) then

            markDead(
                player
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


    --====================================================
    -- TARGET PART VARIATION
    --====================================================

    local function getHead(character)

        if not character then
            return nil
        end


        local head =
            character:
            FindFirstChild(
                "Head"
            )


        if head
            and head:IsA(
                "BasePart"
            ) then

            return head
        end


        return nil
    end


    local function getTorso(character)

        if not character then
            return nil
        end


        local torso =

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


        if torso
            and torso:IsA(
                "BasePart"
            ) then

            return torso
        end


        return nil
    end


    local function chooseVariation(
        mode
    )

        mode =
            normalizeMode(
                mode
            )


        if mode == "Random" then

            return

                math.random(
                    1,
                    2
                ) == 1

                and "Head"

                or "Torso"
        end


        return mode
    end


    local function getVariationPart(
        character,
        mode,
        forcedMode
    )

        local resolved =

            forcedMode

            or chooseVariation(
                mode
            )


        if resolved == "Torso" then

            return

                getTorso(
                    character
                )

                or getHead(
                    character
                ),

                "Torso"
        end


        return

            getHead(
                character
            )

            or getTorso(
                character
            ),

            "Head"
    end


    --====================================================
    -- WALL CHECK
    --====================================================

    local function visible(
        origin,
        part,
        additionalIgnore
    )

        if not state.WallCheck then
            return true
        end


        if not part then
            return false
        end


        local params =
            RaycastParams.new()


        params.FilterType =
            Enum.RaycastFilterType.Exclude


        params.IgnoreWater =
            true


        local exclusions = {}


        if type(additionalIgnore)
            == "table" then


            for _, object
                in ipairs(
                    additionalIgnore
                ) do


                if typeof(object)
                    == "Instance" then


                    table.insert(
                        exclusions,
                        object
                    )
                end
            end
        end


        if LocalPlayer.Character then

            table.insert(
                exclusions,
                LocalPlayer.Character
            )
        end


        params.FilterDescendantsInstances =
            exclusions


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


    --====================================================
    -- CLOSEST TARGET
    --====================================================

    local function getClosestTarget(
        radius,
        targetMode
    )

        local camera =
            Workspace.CurrentCamera


        if not camera then
            return nil
        end


        local mousePosition =
            Input:GetMouseLocation()


        local bestPlayer =
            nil


        local bestPart =
            nil


        local bestDistance =

            radius

            and radius * radius

            or math.huge


        for _, player
            in ipairs(
                Players:GetPlayers()
            ) do


            if validPlayer(
                player
            ) then


                local part =

                    getVariationPart(

                        player.Character,

                        targetMode
                        or "Head"

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
                            - mousePosition.X


                        local dy =
                            point.Y
                            - mousePosition.Y


                        local distance =
                            dx * dx
                            + dy * dy


                        if distance
                            < bestDistance

                            and visible(

                                camera.CFrame.Position,

                                part

                            ) then


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


    --====================================================
    -- RAW PLAYER UNDER CURSOR
    --====================================================

    local function getRawPlayerUnderCursor()

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


            if object:IsA(
                "Model"
            ) then


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


                    if validPlayer(
                        player
                    ) then


                        return player,
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


    --====================================================
    -- TRIGGERBOT TARGET VARIATION
    --====================================================

    local function getTriggerTarget(
        forcedMode
    )

        local player,
            target =

            getRawPlayerUnderCursor()


        if not player
            or not target then

            return nil
        end


        local part,
            resolved =

            getVariationPart(

                player.Character,

                state.TriggerTargetMode,

                forcedMode

            )


        if not part then
            return nil
        end


        ------------------------------------------------
        -- Head mode:
        -- cursor must physically be touching Head.
        --
        -- Torso mode:
        -- cursor must physically be touching Torso.
        --
        -- Random:
        -- randomly resolves to one of those per trigger
        -- acquisition and stays fixed for verification.
        ------------------------------------------------

        if target ~= part

            and not target:
                IsDescendantOf(
                    part
                ) then


            return nil
        end


        return player,
            target,
            resolved
    end


    --====================================================
    -- PLAYER TRACKING
    --====================================================

    local function disconnectPlayer(
        player
    )

        local connections =
            state.PlayerConnections[
                player
            ]


        if not connections then
            return
        end


        for _, connection
            in ipairs(
                connections
            ) do


            pcall(function()

                connection:
                    Disconnect()

            end)

        end


        state.PlayerConnections[
            player
        ] = nil
    end


    --====================================================
    -- ESP
    --====================================================

    local function formatDistance(
        studs
    )

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


    local function healthColour(
        fraction
    )

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


    local function getEspAnchor(
        character
    )

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


    local function espLineOfSight(
        fromPart,
        toPart,
        ignoreList
    )

        if not fromPart
            or not toPart then

            return false
        end


        local direction =
            toPart.Position
            - fromPart.Position


        local distance =
            direction.Magnitude


        if distance <= 0.001 then
            return true
        end


        if distance
            > Config.ESPLOSRange then

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


        local result =
            Workspace:Raycast(

                fromPart.Position,

                direction,

                params

            )


        if not result then
            return true
        end


        local hit =
            result.Instance


        return

            hit

            and (

                hit == toPart

                or hit:
                    IsDescendantOf(
                        toPart.Parent
                    )

            )
    end


    local function applyEspColour(
        attachment,
        isSelf,
        canSeeMe
    )

        if not attachment
            or not attachment.Highlight then

            return
        end


        if isSelf then

            attachment.Highlight.FillColor =
                Config.ESPSelfFill


            attachment.Highlight.OutlineColor =
                Config.ESPSelfOutline


            return
        end


        if canSeeMe then

            attachment.Highlight.FillColor =
                Config.ESPGreenFill


            attachment.Highlight.OutlineColor =
                Config.ESPGreenOutline

        else

            attachment.Highlight.FillColor =
                Config.ESPRedFill


            attachment.Highlight.OutlineColor =
                Config.ESPRedOutline

        end
    end


    local function applyEspVisibility(
        attachment
    )

        if not attachment then
            return
        end


        if attachment.Highlight then

            attachment.Highlight.Enabled =
                state.ESPEnabled

        end


        if attachment.Billboard then

            attachment.Billboard.Enabled =
                state.ESPEnabled

        end


        if attachment.NameLabel then

            attachment.NameLabel.Visible =
                state.ESPNames

        end


        if attachment.DistanceLabel then

            attachment.DistanceLabel.Visible =
                state.ESPDistance

        end


        if attachment.HealthLabel then

            attachment.HealthLabel.Visible =
                state.ESPHealth

        end
    end


    local function removeEsp(
        player
    )

        local attachment =
            state.ESPAttachments[
                player
            ]


        if not attachment then
            return
        end


        if attachment.Highlight then

            pcall(function()

                attachment.Highlight:
                    Destroy()

            end)

        end


        if attachment.Billboard then

            pcall(function()

                attachment.Billboard:
                    Destroy()

            end)

        end


        state.ESPAttachments[
            player
        ] = nil
    end


    local function createEspBillboard(
        character,
        playerName
    )

        local anchor =
            getEspAnchor(
                character
            )


        if not anchor then
            return nil
        end


        local billboard =
            Instance.new(
                "BillboardGui"
            )


        billboard.Name =
            "Vitality_KAT_ESP_Label"


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


        local nameLabel =
            Instance.new(
                "TextLabel"
            )


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


        local distanceLabel =
            Instance.new(
                "TextLabel"
            )


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


        local healthLabel =
            Instance.new(
                "TextLabel"
            )


        healthLabel.BackgroundTransparency =
            1


        healthLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                36
            )


        healthLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                14
            )


        healthLabel.Font =
            Enum.Font.Gotham


        healthLabel.TextSize =
            11


        healthLabel.TextColor3 =
            Color3.fromRGB(
                180,
                255,
                200
            )


        healthLabel.TextStrokeTransparency =
            0


        healthLabel.TextStrokeColor3 =
            Color3.new(
                0,
                0,
                0
            )


        healthLabel.Text =
            "—"


        healthLabel.Parent =
            billboard


        billboard.Parent =
            EspParent


        return

            billboard,

            nameLabel,

            distanceLabel,

            healthLabel
    end


    local function attachEsp(
        player,
        character
    )

        removeEsp(
            player
        )


        if not character then
            return
        end


        local anchor =
            getEspAnchor(
                character
            )


        if not anchor then
            return
        end


        local isSelf =
            player == LocalPlayer


        local highlight =
            Instance.new(
                "Highlight"
            )


        highlight.Name =
            "Vitality_KAT_ESP"


        highlight.Adornee =
            character


        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop


        highlight.FillTransparency =
            1
            - Config.ESPFillAlpha


        highlight.OutlineTransparency =
            1
            - Config.ESPOutlineAlpha


        highlight.Parent =
            EspParent


        local billboard,
            nameLabel,
            distanceLabel,
            healthLabel =

            createEspBillboard(

                character,

                player.Name

            )


        local attachment = {

            Highlight =
                highlight,

            Billboard =
                billboard,

            NameLabel =
                nameLabel,

            DistanceLabel =
                distanceLabel,

            HealthLabel =
                healthLabel,

            Character =
                character,

            IsSelf =
                isSelf,

            CanSeeMe =
                false,

            LastLOS =
                0,
        }


        state.ESPAttachments[
            player
        ] = attachment


        applyEspColour(
            attachment,
            isSelf,
            false
        )


        applyEspVisibility(
            attachment
        )
    end


    --====================================================
    -- PLAYER LIFE CYCLE
    --====================================================

    local function watchCharacter(
        player,
        character
    )

        clearDead(
            player
        )


        attachEsp(
            player,
            character
        )


        state.PlayerConnections[player] =
            state.PlayerConnections[player]
            or {}


        local humanoid =

            character:
            WaitForChild(
                "Humanoid",
                8
            )


        if not humanoid then
            return
        end


        table.insert(

            state.PlayerConnections[player],

            humanoid.Died:
            Connect(function()

                markDead(
                    player
                )

            end)

        )


        table.insert(

            state.PlayerConnections[player],

            humanoid.HealthChanged:
            Connect(function(
                health
            )


                if health <= 0 then

                    markDead(
                        player
                    )

                end

            end)

        )
    end


    local function watchPlayer(
        player
    )

        disconnectPlayer(
            player
        )


        state.PlayerConnections[player] =
            {}


        table.insert(

            state.PlayerConnections[player],

            player.CharacterAdded:
            Connect(function(
                character
            )


                clearDead(
                    player
                )


                task.spawn(
                    watchCharacter,
                    player,
                    character
                )

            end)

        )


        table.insert(

            state.PlayerConnections[player],

            player.CharacterRemoving:
            Connect(function()


                if player ~= LocalPlayer then

                    markDead(
                        player
                    )

                end


                removeEsp(
                    player
                )

            end)

        )


        if player.Character then

            task.spawn(

                watchCharacter,

                player,

                player.Character

            )

        end
    end


    for _, player
        in ipairs(
            Players:GetPlayers()
        ) do


        watchPlayer(
            player
        )

    end


    table.insert(

        state.Connections,

        Players.PlayerAdded:
        Connect(
            watchPlayer
        )

    )


    table.insert(

        state.Connections,

        Players.PlayerRemoving:
        Connect(function(
            player
        )


            disconnectPlayer(
                player
            )


            removeEsp(
                player
            )


            state.DeadTargets[
                player
            ] = nil

        end)

    )


    --====================================================
    -- ESP UPDATE LOOP
    --====================================================

    local espAccumulator =
        0


    table.insert(

        state.Connections,

        RunService.Heartbeat:
        Connect(function(dt)


            if not state.Alive then
                return
            end


            espAccumulator += dt


            if espAccumulator
                < 1 / 15 then

                return
            end


            espAccumulator =
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

                    removeEsp(
                        player
                    )

                    continue
                end


                local character =
                    player.Character


                if not character
                    or not character.Parent then


                    removeEsp(
                        player
                    )


                    continue
                end


                if attachment.Character
                    ~= character then


                    attachEsp(
                        player,
                        character
                    )


                    continue
                end


                applyEspVisibility(
                    attachment
                )


                if attachment.Highlight

                    and attachment.Highlight.Adornee
                        ~= character then


                    attachment.Highlight.Adornee =
                        character
                end


                ------------------------------------------------
                -- LOS
                ------------------------------------------------

                if not attachment.IsSelf

                    and (

                        now
                        - attachment.LastLOS

                    ) >= Config.ESPLOSInterval then


                    attachment.LastLOS =
                        now


                    local theirHead =
                        character:
                        FindFirstChild(
                            "Head"
                        )


                    local canSee =
                        false


                    if theirHead
                        and myHead
                        and myRoot then


                        canSee =

                            espLineOfSight(

                                theirHead,

                                myHead,

                                {
                                    character,
                                    myCharacter,
                                }

                            )

                    end


                    if canSee
                        ~= attachment.CanSeeMe then


                        attachment.CanSeeMe =
                            canSee


                        applyEspColour(

                            attachment,

                            false,

                            canSee

                        )

                    end
                end


                ------------------------------------------------
                -- DISTANCE
                ------------------------------------------------

                if state.ESPDistance
                    and attachment.DistanceLabel then


                    local anchor =
                        getEspAnchor(
                            character
                        )


                    if anchor
                        and myRoot then


                        attachment.DistanceLabel.Text =

                            formatDistance(

                                (
                                    anchor.Position
                                    - myRoot.Position
                                ).Magnitude

                            )

                    end
                end


                ------------------------------------------------
                -- HEALTH
                ------------------------------------------------

                if state.ESPHealth
                    and attachment.HealthLabel then


                    local humanoid =
                        getHumanoid(
                            character
                        )


                    if humanoid then


                        local maximum =
                            math.max(
                                humanoid.MaxHealth,
                                1
                            )


                        local percent =

                            humanoid.Health
                            / maximum


                        attachment.HealthLabel.Text =

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


                        attachment.HealthLabel.TextColor3 =

                            healthColour(
                                percent
                            )
                    end
                end
            end

        end)

    )


    --====================================================
    -- WEAPON CLASSIFICATION
    --====================================================

    local function classifyWeapon(
        object
    )

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


        local recognized = {}

        local otherTool =
            nil


        for _, object
            in ipairs(
                character:GetChildren()
            ) do


            local weaponType =
                classifyWeapon(
                    object
                )


            if weaponType == "Knife"
                or weaponType == "Revolver" then


                table.insert(

                    recognized,

                    {
                        Object =
                            object,

                        Type =
                            weaponType,
                    }

                )


            elseif object:IsA(
                "Tool"
            ) then


                otherTool =
                    otherTool
                    or object
            end
        end


        ------------------------------------------------
        -- One recognized weapon
        ------------------------------------------------

        if #recognized == 1 then

            return

                recognized[1].Object,

                recognized[1].Type
        end


        ------------------------------------------------
        -- Both briefly present during switch.
        --
        -- Neither combat path is allowed.
        ------------------------------------------------

        if #recognized > 1 then

            return nil,
                "Transition"
        end


        if otherTool then

            return otherTool,
                "Other"
        end


        return nil,
            "None"
    end


    --====================================================
    -- WEAPON EVENT LISTENER
    --====================================================

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


        local clientEvent =
            weapon:
            FindFirstChild(
                "ClientEvent"
            )


        if not clientEvent then

            clientEvent =

                weapon:
                WaitForChild(
                    "ClientEvent",
                    2
                )
        end


        if not clientEvent

            or not clientEvent:
                IsA(
                    "RemoteEvent"
                ) then


            return
        end


        state.WeaponEventConnection =

            clientEvent.OnClientEvent:
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


        ------------------------------------------------
        -- We are CERTAIN Revolver is equipped now.
        --
        -- Safe place to clear stale knife mouse state.
        ------------------------------------------------

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


        ------------------------------------------------
        -- INVALIDATE every async task from old weapon.
        ------------------------------------------------

        state.WeaponEpoch += 1


        local epoch =
            state.WeaponEpoch


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


        ------------------------------------------------
        -- KNIFE
        ------------------------------------------------

        if weaponType == "Knife" then


            resetKnifeState()


            state.NextKnifeChargeAttempt =

                os.clock()
                + Config.KnifeEquipSettle


            return
        end


        ------------------------------------------------
        -- REVOLVER
        ------------------------------------------------

        if weaponType == "Revolver" then


            resetRevolverState()


            task.spawn(

                primeRevolver,

                weapon,

                epoch

            )


            return
        end


        ------------------------------------------------
        -- NONE / OTHER / TRANSITION
        ------------------------------------------------

        resetKnifeState()

        resetRevolverState()
    end


    --====================================================
    -- SILENT AIM
    --====================================================

    local function selectSilentRay(
        ray,
        ignoreList
    )

        if not state.SilentAimEnabled then
            return nil
        end


        if typeof(ray) ~= "Ray" then
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


        ------------------------------------------------
        -- HIT CHANCE
        ------------------------------------------------

        local chance =
            math.clamp(

                tonumber(
                    state.SilentAimHitChance
                ) or 100,

                0,

                100

            )


        if chance <= 0 then

            state.MissedChance += 1

            return nil
        end


        if chance < 100

            and math.random(
                1,
                100
            ) > chance then


            state.MissedChance += 1

            return nil
        end


        local camera =
            Workspace.CurrentCamera


        if not camera then
            return nil
        end


        local bestDistance =

            state.SilentAimWholeScreen

            and math.huge

            or (

                state.SilentAimRadius
                * state.SilentAimRadius

            )


        local bestPart =
            nil


        state.Matched += 1


        for _, player
            in ipairs(
                Players:GetPlayers()
            ) do


            if validPlayer(
                player
            ) then


                local part =

                    getVariationPart(

                        player.Character,

                        state.SilentAimTargetMode

                    )


                if part then


                    local direction =
                        part.Position
                        - ray.Origin


                    local length =
                        direction.Magnitude


                    if length > 0.001

                        and length
                            <= magnitude then


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
                                - Mouse.X


                            local dy =
                                point.Y
                                - Mouse.Y


                            local distance =
                                dx * dx
                                + dy * dy


                            if distance
                                < bestDistance

                                and visible(

                                    ray.Origin,

                                    part,

                                    ignoreList

                                ) then


                                bestDistance =
                                    distance


                                bestPart =
                                    part


                                state.LastTarget =
                                    player.Name

                            end
                        end
                    end
                end
            end
        end


        if not bestPart then
            return nil
        end


        local direction =
            bestPart.Position
            - ray.Origin


        if direction.Magnitude
            <= 0.001 then

            return nil
        end


        state.Redirected += 1


        return Ray.new(

            ray.Origin,

            direction.Unit
            * magnitude

        )
    end


    --====================================================
    -- PERSISTENT NAMECALL ROUTER
    --====================================================

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

            Original = nil,
        }


        rawset(
            _G,
            ROUTER_KEY,
            router
        )
    end


    local function handleNamecall(
        selfObject,
        method,
        args
    )

        ------------------------------------------------
        -- OBSERVE KNIFE / REVOLVER OUTGOING EVENTS
        ------------------------------------------------

        if method == "FireServer"

            and typeof(selfObject)
                == "Instance"

            and selfObject.Name
                == "ClientEvent" then


            local weapon =
                selfObject.Parent


            local command =
                args[1]


            ------------------------------------------------
            -- KNIFE
            ------------------------------------------------

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


            ------------------------------------------------
            -- REVOLVER
            ------------------------------------------------

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

                    and type(
                        args[2]
                    ) == "table" then


                    local reloadState =
                        args[2][1]


                    if reloadState
                        == "Start" then


                        state.RevolverReloading =
                            true
                    end
                end
            end
        end


        ------------------------------------------------
        -- SILENT AIM
        ------------------------------------------------

        if state.SilentAimEnabled

            and selfObject
                == Workspace

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

                    selectSilentRay(

                        ray,

                        ignore

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
                    tostring(
                        failure
                    )

            end


            ------------------------------------------------
            -- Raycasts inside selection can change active
            -- namecall method. Restore it before forwarding.
            ------------------------------------------------

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

                "KAT hook installation failed: "
                .. tostring(
                    result
                )


            return false
        end


        original =
            result


        router.Original =
            result


        router.Installed =
            true


        router.Owner =
            state


        state.LastError =
            nil


        return true
    end


    --====================================================
    -- KNIFE
    --====================================================

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


            ------------------------------------------------
            -- Weapon switched.
            --
            -- Never release the OLD knife input into the
            -- NEW revolver.
            ------------------------------------------------

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


        ------------------------------------------------
        -- Same Knife still equipped:
        -- safe to release failed charge.
        ------------------------------------------------

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


        ------------------------------------------------
        -- Fallback reset in case ChargeRelease isn't
        -- observed by the router.
        ------------------------------------------------

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


    --====================================================
    -- REVOLVER RELOAD
    --====================================================

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


        ------------------------------------------------
        -- Only release if SAME Revolver is still active.
        ------------------------------------------------

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


    --====================================================
    -- FEATURE ENABLE CALLBACKS
    --====================================================

    local function setSilentAimEnabled(
        value
    )

        if not state.Alive then
            return
        end


        if value == true then


            if installRouter() then

                state.SilentAimEnabled =
                    true

            else

                state.SilentAimEnabled =
                    false


                Window:Notify({

                    Title = "KAT",

                    Content =
                        state.LastError
                        or "Silent aim unavailable",

                    Duration = 5,

                })
            end

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
    end


    local function setTriggerbotEnabled(
        value
    )

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
                        or "Triggerbot hook unavailable",

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


            ------------------------------------------------
            -- Disable Knife cleanly ONLY if Knife remains
            -- equipped.
            ------------------------------------------------

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


            ------------------------------------------------
            -- Disable gun input ONLY if Revolver remains
            -- equipped.
            ------------------------------------------------

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


    --====================================================
    -- COMBAT UPDATE LOOP
    --====================================================

    table.insert(

        state.Connections,

        RunService.RenderStepped:
        Connect(function()


            if not state.Alive then
                return
            end


            updateEquippedWeapon()


            --================================================
            -- TRIGGERBOT
            --================================================

            if state.TriggerbotEnabled

                and not Input:
                    GetFocusedTextBox() then


                --============================================
                -- KNIFE
                --============================================

                if state.WeaponType
                    == "Knife" then


                    ------------------------------------------------
                    -- Knife may automatically charge even when
                    -- no target is currently visible.
                    ------------------------------------------------

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


                    if knifeReady() then


                        local player,
                            _,
                            resolvedMode =

                            getTriggerTarget()


                        if player

                            and validPlayer(
                                player
                            ) then


                            ------------------------------------------------
                            -- Verify SAME target-part variation before
                            -- releasing knife.
                            ------------------------------------------------

                            local verify =

                                getTriggerTarget(
                                    resolvedMode
                                )


                            if verify
                                == player then


                                state.LastTarget =
                                    player.Name


                                throwKnife()

                            end
                        end
                    end


                --============================================
                -- REVOLVER
                --============================================

                elseif state.WeaponType
                    == "Revolver" then


                    ------------------------------------------------
                    -- Absolutely invalidate stale knife state.
                    ------------------------------------------------

                    state.KnifeCharging =
                        false


                    state.KnifeInputHeld =
                        false


                    state.KnifeReleaseBusy =
                        false


                    if state.RevolverPrimed

                        and state.Weapon

                        and state.Weapon.Parent
                            == LocalPlayer.Character

                        and classifyWeapon(
                            state.Weapon
                        ) == "Revolver" then


                        ------------------------------------------------
                        -- AUTO RELOAD
                        ------------------------------------------------

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


                        elseif not state.RevolverReloading

                            and not state.RevolverBusy then


                            local player,
                                _,
                                resolvedMode =

                                getTriggerTarget()


                            if player

                                and validPlayer(
                                    player
                                ) then


                                local now =
                                    os.clock()


                                if now
                                    - state.LastRevolverShot

                                    >= Config.RevolverCooldown then


                                    local verify =

                                        getTriggerTarget(
                                            resolvedMode
                                        )


                                    if verify
                                        == player then


                                        state.LastRevolverShot =
                                            now


                                        state.LastTarget =
                                            player.Name


                                        state.RevolverBusy =
                                            true


                                        local epoch =
                                            state.WeaponEpoch


                                        local weapon =
                                            state.Weapon


                                        task.spawn(function()


                                            if state.WeaponEpoch
                                                ~= epoch

                                                or state.WeaponType
                                                    ~= "Revolver"

                                                or state.Weapon
                                                    ~= weapon then


                                                return
                                            end


                                            if state.RevolverAmmo
                                                ~= nil

                                                and state.RevolverAmmo
                                                    <= 0 then


                                                state.RevolverBusy =
                                                    false


                                                if not state.RevolverReloading then

                                                    reloadRevolver()

                                                end


                                                return
                                            end


                                            local finalPlayer =

                                                getTriggerTarget(
                                                    resolvedMode
                                                )


                                            if state.TriggerbotEnabled

                                                and finalPlayer
                                                    == player

                                                and validPlayer(
                                                    player
                                                ) then


                                                fireRevolver()

                                            end


                                            if state.WeaponEpoch
                                                == epoch

                                                and state.WeaponType
                                                    == "Revolver"

                                                and state.Weapon
                                                    == weapon then


                                                state.RevolverBusy =
                                                    false


                                                if state.RevolverAmmo
                                                    ~= nil

                                                    and state.RevolverAmmo
                                                        <= 0

                                                    and not state.RevolverReloading

                                                    and (

                                                        state.RevolverReserve
                                                            == nil

                                                        or state.RevolverReserve
                                                            > 0

                                                    ) then


                                                    task.spawn(
                                                        reloadRevolver
                                                    )
                                                end
                                            end

                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end


            --================================================
            -- AIMBOT
            --
            -- Toggle = arms the feature.
            -- Right Mouse Button MUST be held to aim.
            --================================================

            if state.AimbotEnabled

                and not Input:
                    GetFocusedTextBox()

                and Input:
                    IsMouseButtonPressed(
                        Enum.UserInputType.MouseButton2
                    ) then


                local camera =
                    Workspace.CurrentCamera


                if camera then


                    local player,
                        part =

                        getClosestTarget(

                            state.AimbotFOV,

                            "Head"

                        )


                    if player
                        and part

                        and validPlayer(
                            player
                        ) then


                        state.LastTarget =
                            player.Name


                        local point =

                            camera:
                            WorldToViewportPoint(
                                part.Position
                            )


                        local mousePosition =
                            Input:
                            GetMouseLocation()


                        local dx =
                            point.X
                            - mousePosition.X


                        local dy =
                            point.Y
                            - mousePosition.Y


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
                end
            end

        end)

    )


    --====================================================
    -- CLEANUP
    --====================================================

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


        ------------------------------------------------
        -- SAFE KNIFE RELEASE
        ------------------------------------------------

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


        ------------------------------------------------
        -- SAFE REVOLVER RELEASE
        ------------------------------------------------

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


        ------------------------------------------------
        -- ROUTER
        ------------------------------------------------

        if router.Owner
            == state then


            router.Owner =
                nil
        end


        ------------------------------------------------
        -- CONNECTIONS
        ------------------------------------------------

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


            disconnectPlayer(
                player
            )

        end


        state.PlayerConnections =
            {}


        ------------------------------------------------
        -- ESP
        ------------------------------------------------

        local playersToRemove =
            {}


        for player
            in pairs(
                state.ESPAttachments
            ) do


            table.insert(
                playersToRemove,
                player
            )
        end


        for _, player
            in ipairs(
                playersToRemove
            ) do


            removeEsp(
                player
            )
        end


        state.ESPAttachments =
            {}


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


    --====================================================
    -- UI
    --====================================================

    local ok,
        failure =

        pcall(function()


            local tab =
                Window:
                CreateTab(
                    "KAT",
                    "kat"
                )


            --================================================
            -- SILENT AIM
            --================================================

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

                                state.SilentAimTargetMode =

                                    normalizeMode(
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

                                        tonumber(
                                            value
                                        ) or 100,

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
                        "KAT_WholeScreen",

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


            controls.Radius =

                silent:
                CreateSlider({

                    Name =
                        "Radius",

                    Info =
                        "Used when Whole Screen is disabled",

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

                                        tonumber(
                                            value
                                        ) or 175,

                                        25,

                                        500

                                    )
                            end

                        end,

                })


            controls.WallCheck =

                silent:
                CreateToggle({

                    Name =
                        "Wall Check",

                    Flag =
                        "KAT_WallCheck",

                    CurrentValue =
                        true,

                    Callback =
                        function(value)


                            if state.Alive then

                                state.WallCheck =
                                    value == true

                            end

                        end,

                })


            --================================================
            -- TRIGGERBOT
            --================================================

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

                                state.TriggerTargetMode =

                                    normalizeMode(
                                        value
                                    )
                            end

                        end,

                })


            trigger:
            CreateParagraph({

                Title =
                    "Weapon Handling",

                Content =
                    "Revolver fires automatically when your cursor is over the selected body region and reloads at 0 ammo.\nKnife automatically charges while equipped, throws when the selected region is detected, then immediately begins charging the next throw.",

            })


            --================================================
            -- AIMBOT
            --================================================

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
                    "Activation",

                Content =
                    "Aimbot only engages while Right Mouse Button is held. Enabling the toggle only arms the feature.",

            })


            controls.AimbotFOV =

                aimbot:
                CreateSlider({

                    Name =
                        "Aimbot FOV",

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

                                        tonumber(
                                            value
                                        ) or 300,

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
                        "Aimbot Smoothness",

                    Flag =
                        "KAT_AimbotSmooth",

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

                                        tonumber(
                                            value
                                        ) or 0.28,

                                        0.05,

                                        1

                                    )
                            end

                        end,

                })


            --================================================
            -- ESP
            --================================================

            local esp =

                tab:
                CreateSection({

                    Name =
                        "ESP",

                    Icon =
                        "esp",

                    Side =
                        "Right",

                })


            controls.ESP =

                esp:
                CreateToggle({

                    Name =
                        "Player ESP",

                    Flag =
                        "KAT_ESP",

                    CurrentValue =
                        false,

                    Callback =
                        function(value)


                            state.ESPEnabled =
                                value == true


                            for _,
                                attachment

                                in pairs(
                                    state.ESPAttachments
                                ) do


                                applyEspVisibility(
                                    attachment
                                )
                            end

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


                            state.ESPNames =
                                value == true


                            for _,
                                attachment

                                in pairs(
                                    state.ESPAttachments
                                ) do


                                applyEspVisibility(
                                    attachment
                                )
                            end

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


                            state.ESPDistance =
                                value == true


                            for _,
                                attachment

                                in pairs(
                                    state.ESPAttachments
                                ) do


                                applyEspVisibility(
                                    attachment
                                )
                            end

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


                            state.ESPHealth =
                                value == true


                            for _,
                                attachment

                                in pairs(
                                    state.ESPAttachments
                                ) do


                                applyEspVisibility(
                                    attachment
                                )
                            end

                        end,

                })


            esp:
            CreateParagraph({

                Title =
                    "Threat Colour",

                Content =
                    "Red = no clear line of sight to you.\nGreen = that player currently has a clear world-geometry line of sight to your head.",

            })


            --================================================
            -- STATUS
            --================================================

            local diagnostics =

                tab:
                CreateSection({

                    Name =
                        "KAT Status",

                    Icon =
                        "terminal",

                    Side =
                        "Right",

                })


            local readout =

                diagnostics:
                CreateParagraph({

                    Title =
                        "Live Status",

                    Content =
                        "Initializing...",

                })


            local function statusText()

                local weapon =
                    state.WeaponType


                local weaponInfo =
                    weapon


                if weapon == "Revolver" then


                    weaponInfo =

                        string.format(

                            "Revolver | Ammo %s / %s%s",

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


                elseif weapon == "Knife" then


                    weaponInfo =

                        string.format(

                            "Knife | %s | %.2fs",

                            state.KnifeCharging
                                and "Charging"
                                or "Ready",

                            state.KnifeCharging

                                and math.max(

                                    0,

                                    os.clock()
                                    - state.KnifeChargeStarted

                                )

                                or 0

                        )
                end


                return string.format(

                    "Weapon: %s\nSilent Aim: %s | %s | %d%%\nTriggerbot: %s | %s\nAimbot: %s | Hold RMB\nESP: %s\nMatched: %d | Redirected: %d | Chance Misses: %d | Errors: %d\nLast Target: %s\nLast Error: %s",

                    weaponInfo,

                    state.SilentAimEnabled
                        and "On"
                        or "Off",

                    state.SilentAimTargetMode,

                    state.SilentAimHitChance,

                    state.TriggerbotEnabled
                        and "On"
                        or "Off",

                    state.TriggerTargetMode,

                    state.AimbotEnabled
                        and "Armed"
                        or "Off",

                    state.ESPEnabled
                        and "On"
                        or "Off",

                    state.Matched,

                    state.Redirected,

                    state.MissedChance,

                    state.Errors,

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
                                .. statusText()
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


                        if not state.Alive then
                            return
                        end


                        state.Matched =
                            0


                        state.Redirected =
                            0


                        state.MissedChance =
                            0


                        state.Errors =
                            0


                        state.LastError =
                            nil


                        state.LastTarget =
                            nil

                    end,

            })


            local statusAccumulator =
                0


            table.insert(

                state.Connections,

                RunService.Heartbeat:
                Connect(function(dt)


                    if not state.Alive then
                        return
                    end


                    statusAccumulator += dt


                    if statusAccumulator >= 0.5 then


                        statusAccumulator =
                            0


                        readout:Set({

                            Content =
                                statusText(),

                        })
                    end

                end)

            )


            --================================================
            -- APPLY SAVED VALUES
            --
            -- Vitality constructors restore saved values but
            -- don't necessarily invoke callbacks.
            --================================================

            state.SilentAimWholeScreen =
                controls.WholeScreen:Get()
                == true


            state.SilentAimRadius =

                math.clamp(

                    tonumber(
                        controls.Radius:Get()
                    ) or 175,

                    25,

                    500

                )


            state.SilentAimTargetMode =

                normalizeMode(
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


            state.WallCheck =
                controls.WallCheck:Get()
                == true


            state.TriggerTargetMode =

                normalizeMode(
                    controls.TriggerTarget:Get()
                )


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


            state.ESPEnabled =
                controls.ESP:Get()
                == true


            state.ESPNames =
                controls.ESPNames:Get()
                == true


            state.ESPDistance =
                controls.ESPDistance:Get()
                == true


            state.ESPHealth =
                controls.ESPHealth:Get()
                == true


            for _,
                attachment

                in pairs(
                    state.ESPAttachments
                ) do


                applyEspVisibility(
                    attachment
                )
            end


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
            .. tostring(
                failure
            ),

            0

        )
    end


    --====================================================
    -- INITIAL WEAPON SCAN
    --====================================================

    updateEquippedWeapon()


    state.Ready =
        true


    Window:Notify({

        Title =
            "KAT",

        Content =
            "KAT module loaded. Aimbot is hold-RMB only. Knife and Revolver trigger paths are isolated.",

        Duration =
            4,

    })


    return true
end
