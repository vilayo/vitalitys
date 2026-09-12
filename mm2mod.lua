-- vitality's hub / Murder Mystery 2
-- Module version: 4.4
-- Predictive moving-target follow layered onto IY-inspired targeted fling physics.

return function(context)
    local NovaField = assert(
        context.Library or context.NovaField,
        "Vitality library missing from module context"
    )

    local Window = assert(
        context.Window,
        "Vitality window missing from module context"
    )

    local oldState = rawget(
        _G,
        "__VITALITY_MM2_MODULE_BUILD_STATE"
    )

    if type(oldState) == "table"
        and oldState.Window == Window
        and oldState.Ready == true then

        return true
    end

    if type(oldState) == "table"
        and type(oldState.Restore) == "function" then

        pcall(oldState.Restore)
    end

    local Players =
        game:GetService("Players")

    local ReplicatedStorage =
        game:GetService("ReplicatedStorage")

    local UserInputService =
        game:GetService("UserInputService")

    local RunService =
        game:GetService("RunService")

    local LocalPlayer =
        Players.LocalPlayer

    local state = {
        Window = Window,
        Ready = false,
        Alive = true,
        Connections = {},
        RoleByUserId = {},
        RoleByName = {},

        -- Secondary role source inferred from actual replicated weapon objects.
        -- This is intentionally separate from PlayerDataChanged so we can tell
        -- whether a role came from server data or visible tools.
        ToolRoleByUserId = {},
        ToolRoleByName = {},
        ToolEvidence = {},
        ToolRefreshPending = setmetatable({}, {__mode = "k"}),

        ESPObjects = {},
        PlayerBindings = {},
        LastPayloadAt = nil,

        Combat = {
            SilentAimEnabled = false,
            SilentAimGun = nil,
            SilentAimGunConnection = nil,
            LastSilentAimShotAt = 0,
            UseFOV = false,
            FOVRadius = 175,
            ShowFOVCircle = false,
            FOVCircleGui = nil,
            FOVCircleFrame = nil,
            FOVRenderConnection = nil,
            FOVLastX = nil,
            FOVLastY = nil,
            FOVLastRadius = nil,
            VisibleCheck = false,

            PredictionBase = 0.09,
            PredictionMax = 0.17,
            PredictionVelocityCap = 110,

            AutoShootEnabled = false,
            ShootBusy = false,
            LastAutoShootAt = 0,
            AutoShootCooldown = 0.75,

            KillAllBusy = false,
            AutoKillSheriffEnabled = false,
            LastAutoKillSheriffAt = 0,
            AutoKillSheriffCooldown = 0.85,
            MaybeAutoKillSheriff = nil,
            UIControls = {},

            KillConfirmedAt = {},
            KillConfirmMessage = {},

            KnownShootRemotes = setmetatable({}, {__mode = "k"}),
        },

        Misc = {
            TargetText = "",
            TargetPlayer = nil,

            FlingBusy = false,
            FlingStrength = 99999,
            FlingDuration = 0.90,
            FlingPredictionEnabled = true,
            FlingPredictionLead = 0.09,
            FlingPredictionVelocityCap = 110,
            ReturnAfterFling = true,

            OrbitEnabled = false,
            OrbitRadius = 8,
            OrbitSpeed = 120,
            OrbitAngle = 0,
            OrbitConnection = nil,

            SpectateEnabled = false,
            FollowEnabled = false,
            CopyMovementEnabled = false,

            AntiFlingEnabled = false,
            LastSafeCFrame = nil,

            SpinEnabled = false,
            SpinSpeed = 360,
            SpinAttachment = nil,
            SpinAngularVelocity = nil,

            AutoGrabEnabled = false,
            AutoGrabMethod = "WalkTo",
            AutoGrabSpeed = 28,
            NearestCoinFirst = true,
            PauseWhileDead = true,
            PauseNearMurderer = true,
            MurdererSafetyRadius = 55,
            ReturnWhenDone = true,
            AutoGrabStartCFrame = nil,
            AutoGrabWorkerRunning = false,
            AutoGrabGeneration = 0,
            ReturnedForRound = false,

            CoinESPEnabled = false,
            CoinChamsEnabled = false,
            CoinBoxEnabled = false,
            CoinDistanceEnabled = true,
            Coins = setmetatable({}, {__mode = "k"}),
            CoinESPObjects = setmetatable({}, {__mode = "k"}),
            CoinFailedUntil = setmetatable({}, {__mode = "k"}),
            CoinRegistrationPending = setmetatable({}, {__mode = "k"}),

            RoundCollected = 0,
            RoundLimit = 40,
            CoinBalance = nil,
            SessionCollected = 0,
            SessionStartedAt = os.clock(),

            CoinStatsVisible = false,
            CoinStatsGui = nil,
            CoinStatsFrame = nil,
            CoinStatsLabels = {},

            OnWorkspaceDescendantAdded = nil,
            Tick = nil,
            Cleanup = nil,
        },

        Gun = {
            CurrentCarrierUserId = nil,
            CurrentCarrierName = nil,
            CurrentCarrierRole = nil,

            LastCarrierUserId = nil,
            LastCarrierName = nil,
            LastCarrierRole = nil,
            LastCarrierCFrame = nil,
            LastCarrierSampleAt = nil,

            WaitingForDrop = false,
            DroppedInstance = nil,
            DroppedDetectedAt = nil,

            DropGeneration = 0,

            -- Connections/visuals owned by the current physical GunDrop.
            DropConnections = {},
            DropHighlight = nil,
            DropBillboard = nil,
            DropLabel = nil,
            LastDropRemovedAt = nil,

            AutoTeleportGeneration = 0,
            AutoTeleportCompletedGeneration = 0,
        },
    }

    rawset(
        _G,
        "__VITALITY_MM2_MODULE_BUILD_STATE",
        state
    )

    local function trackConnection(connection)
        if not connection then
            return connection
        end

        table.insert(
            state.Connections,
            connection
        )

        Window:TrackConnection(connection)
        return connection
    end

    local roleESPEnabled = true
    local chamsEnabled = true
    local labelsEnabled = true
    local playerDistanceEnabled = true
    local showMurderer = true
    local showSheriff = true
    local showInnocents = true
    local showDead = false

    -- Dropped-gun visuals/actions are driven directly by the exact physical
    -- workspace GunDrop. PlayerDataChanged is still used for role/death/carrier
    -- information, but Gun Chams/ESP no longer wait for that event.
    local autoTeleportOnCarrierDeath = false
    local gunChamsEnabled = true
    local gunESPEnabled = true
    local notifyGunDrop = true
    local gunPositionSampleInterval = 0.25

    -- Automatic tool-role inference remains internal; no extra UI/debug option.

    local updateRoundInfo = function()
        -- Replaced after the Roles tab is constructed.
    end

    local roleColors = {
        Murderer = Color3.fromRGB(255, 65, 65),
        Sheriff = Color3.fromRGB(60, 155, 255),
        Hero = Color3.fromRGB(255, 205, 70),
        Innocent = Color3.fromRGB(80, 235, 120),
        Dead = Color3.fromRGB(145, 145, 145),
        Unknown = Color3.fromRGB(215, 215, 215),
    }

    local function normalizeRole(role)
        role = tostring(role or "")

        if role == "Murderer" then
            return "Murderer"
        elseif role == "Sheriff" then
            return "Sheriff"
        elseif role == "Hero" then
            return "Hero"
        elseif role == "Innocent" then
            return "Innocent"
        end

        return role ~= "" and role or "Unknown"
    end

    local function getServerRoleRecord(player)
        if not player then
            return nil
        end

        return state.RoleByUserId[player.UserId]
            or state.RoleByName[player.Name]
    end

    local function getToolRoleRecord(player)
        if not player then
            return nil
        end

        return state.ToolRoleByUserId[player.UserId]
            or state.ToolRoleByName[player.Name]
    end

    local function getRoleRecord(player)
        if not player then
            return nil
        end

        local serverRecord =
            getServerRoleRecord(player)

        local toolRecord =
            getToolRoleRecord(player)

        if not toolRecord then
            return serverRecord
        end

        -- A visible role weapon is strong evidence for a special role. Preserve
        -- server death state and other useful fields when they are available.
        local merged = {}

        if type(serverRecord) == "table" then
            for key, value in pairs(serverRecord) do
                merged[key] = value
            end
        end

        for key, value in pairs(toolRecord) do
            merged[key] = value
        end

        merged.UserId =
            player.UserId

        merged.Name =
            player.Name

        merged.RoleSource =
            "Tool"

        if type(serverRecord) == "table" then
            if serverRecord.Dead ~= nil then
                merged.Dead =
                    serverRecord.Dead
            end

            if serverRecord.Killed ~= nil then
                merged.Killed =
                    serverRecord.Killed
            end
        end

        return merged
    end

    local function shouldShowRecord(record)
        if type(record) ~= "table" then
            return false
        end

        local role =
            normalizeRole(record.Role)

        local dead =
            record.Dead == true
            or record.Killed == true

        if dead and not showDead then
            return false
        end

        if role == "Murderer" then
            return showMurderer
        elseif role == "Sheriff"
            or role == "Hero" then

            return showSheriff
        elseif role == "Innocent" then
            return showInnocents
        end

        return false
    end

    local function colorForRecord(record)
        if type(record) ~= "table" then
            return roleColors.Unknown
        end

        local dead =
            record.Dead == true
            or record.Killed == true

        if dead then
            return roleColors.Dead
        end

        local role =
            normalizeRole(record.Role)

        return roleColors[role]
            or roleColors.Unknown
    end

    local function roleTextForRecord(record)
        if type(record) ~= "table" then
            return "UNKNOWN"
        end

        local role =
            normalizeRole(record.Role)

        local dead =
            record.Dead == true
            or record.Killed == true

        if dead then
            return "DEAD • " .. string.upper(role)
        end

        return string.upper(role)
    end

    local function destroyESP(player)
        local objects =
            state.ESPObjects[player]

        if not objects then
            return
        end

        if objects.Highlight then
            pcall(function()
                objects.Highlight:Destroy()
            end)
        end

        if objects.Billboard then
            pcall(function()
                objects.Billboard:Destroy()
            end)
        end

        state.ESPObjects[player] = nil
    end

    local function ensureESP(player)
        if player == LocalPlayer then
            return nil
        end

        local character =
            player.Character

        if not character
            or not character.Parent then

            return nil
        end

        local root =
            character:FindFirstChild(
                "HumanoidRootPart"
            )
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("UpperTorso")

        if not root then
            return nil
        end

        local objects =
            state.ESPObjects[player]

        if objects
            and objects.Character == character
            and objects.Highlight
            and objects.Highlight.Parent
            and objects.Billboard
            and objects.Billboard.Parent then

            return objects
        end

        destroyESP(player)

        local highlight =
            Instance.new("Highlight")

        highlight.Name =
            "Vitality_MM2_RoleHighlight"

        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.FillTransparency = 0.54
        highlight.OutlineTransparency = 0
        highlight.Adornee = character
        highlight.Parent = character

        local billboard =
            Instance.new("BillboardGui")

        billboard.Name =
            "Vitality_MM2_RoleLabel"

        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.Size =
            UDim2.fromOffset(
                240,
                52
            )

        billboard.StudsOffsetWorldSpace =
            Vector3.new(
                0,
                3.85,
                0
            )

        billboard.Adornee = root
        billboard.Parent = root

        local label =
            Instance.new("TextLabel")

        label.Name = "RoleText"
        label.BackgroundTransparency = 1
        label.Size =
            UDim2.new(
                1,
                0,
                0,
                22
            )
        label.Position =
            UDim2.fromOffset(
                0,
                1
            )
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 13
        label.TextStrokeTransparency = 0.2
        label.TextWrapped = false
        label.Text = ""
        label.Parent = billboard

        local distanceLabel =
            Instance.new("TextLabel")

        distanceLabel.Name =
            "DistanceText"

        distanceLabel.BackgroundTransparency = 1
        distanceLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                18
            )
        distanceLabel.Position =
            UDim2.fromOffset(
                0,
                28
            )
        distanceLabel.Font =
            Enum.Font.GothamMedium
        distanceLabel.TextSize = 11
        distanceLabel.TextStrokeTransparency = 0.25
        distanceLabel.TextWrapped = false
        distanceLabel.Text = ""
        distanceLabel.Parent = billboard

        objects = {
            Character = character,
            Root = root,
            Highlight = highlight,
            Billboard = billboard,
            Label = label,
            DistanceLabel = distanceLabel,
        }

        state.ESPObjects[player] =
            objects

        return objects
    end

    local function applyPlayerESP(player)
        if player == LocalPlayer then
            return
        end

        local record =
            getRoleRecord(player)

        local show =
            roleESPEnabled
            and shouldShowRecord(record)

        -- Unknown/filtered players do not need fresh GUI instances. Existing
        -- instances are simply disabled until they are needed again.
        if not show then
            local existing =
                state.ESPObjects[player]

            if existing then
                existing.Highlight.Enabled = false
                existing.Billboard.Enabled = false
            end

            return
        end

        local objects =
            ensureESP(player)

        if not objects then
            return
        end

        objects.Highlight.Enabled =
            chamsEnabled

        objects.Billboard.Enabled =
            labelsEnabled
            or playerDistanceEnabled

        objects.Label.Visible =
            labelsEnabled

        if objects.DistanceLabel then
            objects.DistanceLabel.Visible =
                playerDistanceEnabled
        end

        local color =
            colorForRecord(record)

        objects.Highlight.FillColor =
            color

        objects.Highlight.OutlineColor =
            color

        objects.Label.TextColor3 =
            color

        if objects.DistanceLabel then
            objects.DistanceLabel.TextColor3 =
                color
        end

        objects.Label.Text =
            player.Name
            .. "   •   "
            .. roleTextForRecord(record)
    end

    local function updatePlayerDistanceLabels()
        if not playerDistanceEnabled then
            return
        end

        local localRoot =
            LocalPlayer.Character
            and (
                LocalPlayer.Character:
                    FindFirstChild(
                        "HumanoidRootPart"
                    )
                or LocalPlayer.Character:
                    FindFirstChild(
                        "UpperTorso"
                    )
                or LocalPlayer.Character:
                    FindFirstChild(
                        "Torso"
                    )
            )

        if not localRoot then
            return
        end

        for player, objects in pairs(
            state.ESPObjects
        ) do
            if player
                and player ~= LocalPlayer
                and objects
                and objects.Root
                and objects.Root.Parent
                and objects.DistanceLabel
                and objects.DistanceLabel.Parent then

                local distance =
                    (
                        localRoot.Position
                        - objects.Root.Position
                    ).Magnitude

                local nextText =
                    string.format(
                        "[%d studs]",
                        math.floor(
                            distance + 0.5
                        )
                    )

                if objects.DistanceLabel.Text
                    ~= nextText then

                    objects.DistanceLabel.Text =
                        nextText
                end
            end
        end
    end

    local function refreshAllESP()
        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            applyPlayerESP(player)
        end
    end

    -- ============================================================
    -- LIVE ROLE INFERENCE FROM ACTUAL WEAPON TOOLS
    -- ============================================================

    local function isRoleWeaponObject(object)
        if not object then
            return nil
        end

        local name =
            string.lower(
                tostring(
                    object.Name
                )
            )

        -- MM2's live role weapons are normally direct Character/Backpack
        -- objects named Knife and Gun. Restricting this to exact names avoids
        -- confusing cosmetic inventory names/toys with role weapons.
        if name ~= "knife"
            and name ~= "gun" then

            return nil
        end

        if object:IsA("Tool") then
            return name == "knife"
                and "Murderer"
                or "Gun"
        end

        -- Some executor/decompiler views can surface these as Models while the
        -- live hierarchy is changing. Accept a model only if it looks weapon-like.
        if object:IsA("Model")
            and object:FindFirstChild(
                "Handle",
                true
            ) then

            return name == "knife"
                and "Murderer"
                or "Gun"
        end

        return nil
    end

    local function findRoleWeapon(
        container
    )
        if not container then
            return nil, nil
        end

        local knife =
            container:FindFirstChild(
                "Knife"
            )

        if knife
            and isRoleWeaponObject(
                knife
            ) == "Murderer" then

            return "Murderer",
                knife
        end

        local gun =
            container:FindFirstChild(
                "Gun"
            )

        if gun
            and isRoleWeaponObject(
                gun
            ) == "Gun" then

            return "Gun",
                gun
        end

        return nil, nil
    end

    local function determineGunToolRole(
        player
    )
        local server =
            getServerRoleRecord(
                player
            )

        if type(server) == "table" then
            local serverRole =
                normalizeRole(
                    server.Role
                )

            if serverRole == "Hero"
                or serverRole == "Sheriff" then

                return serverRole
            end
        end

        -- If a physical gun was dropped and a player now owns a Gun tool,
        -- they are the best Hero candidate even before the next remote update.
        local recentDropPickup =
            state.Gun.LastDropRemovedAt
            and (
                os.clock()
                - state.Gun.LastDropRemovedAt
            ) <= 2.0

        local physicalDrop =
            state.Gun.DroppedInstance

        local hasPhysicalDrop =
            physicalDrop ~= nil
            and physicalDrop.Parent ~= nil
            and physicalDrop.Name == "GunDrop"

        if state.Gun.WaitingForDrop
            or hasPhysicalDrop
            or recentDropPickup then

            return "Hero"
        end

        return "Sheriff"
    end

    local function setToolRole(
        player,
        role,
        weaponObject
    )
        if not player then
            return
        end

        local old =
            state.ToolRoleByUserId[
                player.UserId
            ]

        if role == nil then
            state.ToolRoleByUserId[
                player.UserId
            ] = nil

            state.ToolRoleByName[
                player.Name
            ] = nil

            state.ToolEvidence[
                player.UserId
            ] = nil

            if old then
                applyPlayerESP(
                    player
                )

                updateRoundInfo()
            end

            return
        end

        local normalized =
            normalizeRole(role)

        local unchanged =
            type(old) == "table"
            and old.Role == normalized
            and state.ToolEvidence[
                player.UserId
            ] == weaponObject

        if unchanged then
            return
        end

        local record = {
            UserId = player.UserId,
            Name = player.Name,
            Role = normalized,
            Dead = false,
            Killed = false,
            RoleSource = "Tool",
            ToolName =
                weaponObject
                and weaponObject.Name
                or nil,
            ToolClass =
                weaponObject
                and weaponObject.ClassName
                or nil,
        }

        state.ToolRoleByUserId[
            player.UserId
        ] = record

        state.ToolRoleByName[
            player.Name
        ] = record

        state.ToolEvidence[
            player.UserId
        ] = weaponObject

        applyPlayerESP(
            player
        )

        updateRoundInfo()
    end

    local function refreshToolRole(
        player
    )
        if not state.Alive
            or not player
            or player == LocalPlayer
            then

            return
        end

        local characterRole,
            characterWeapon =
                findRoleWeapon(
                    player.Character
                )

        local backpack =
            player:FindFirstChild(
                "Backpack"
            )

        local backpackRole,
            backpackWeapon =
                findRoleWeapon(
                    backpack
                )

        -- Knife always wins over Gun if both appear transiently.
        if characterRole == "Murderer"
            or backpackRole == "Murderer" then

            setToolRole(
                player,
                "Murderer",
                characterRole == "Murderer"
                    and characterWeapon
                    or backpackWeapon
            )

            return
        end

        local gunObject =
            characterRole == "Gun"
            and characterWeapon
            or backpackRole == "Gun"
                and backpackWeapon
                or nil

        if gunObject then
            setToolRole(
                player,
                determineGunToolRole(
                    player
                ),
                gunObject
            )

            return
        end

        setToolRole(
            player,
            nil,
            nil
        )
    end

    local function scheduleToolRoleRefresh(
        player
    )
        if not state.Alive
            or not player
            or player == LocalPlayer then

            return
        end

        if state.ToolRefreshPending[
            player
        ] then

            return
        end

        state.ToolRefreshPending[
            player
        ] = true

        task.delay(
            0.03,
            function()
                state.ToolRefreshPending[
                    player
                ] = nil

                if state.Alive
                    and player.Parent == Players then

                    refreshToolRole(
                        player
                    )
                end
            end
        )
    end

    local function disconnectBinding(
        binding,
        key
    )
        local connection =
            binding[key]

        if connection then
            pcall(function()
                connection:Disconnect()
            end)

            binding[key] = nil
        end
    end

    local function bindCharacterToolSignals(
        player,
        character,
        binding
    )
        disconnectBinding(
            binding,
            "CharacterToolAdded"
        )

        disconnectBinding(
            binding,
            "CharacterToolRemoved"
        )

        if not character then
            return
        end

        binding.CharacterToolAdded =
            trackConnection(
                character.ChildAdded:Connect(
                    function(object)
                        if isRoleWeaponObject(
                            object
                        ) then

                            scheduleToolRoleRefresh(
                                player
                            )
                        end
                    end
                )
            )

        binding.CharacterToolRemoved =
            trackConnection(
                character.ChildRemoved:Connect(
                    function(object)
                        if isRoleWeaponObject(
                            object
                        ) then

                            scheduleToolRoleRefresh(
                                player
                            )
                        end
                    end
                )
            )
    end

    local function bindBackpackToolSignals(
        player,
        binding
    )
        disconnectBinding(
            binding,
            "BackpackToolAdded"
        )

        disconnectBinding(
            binding,
            "BackpackToolRemoved"
        )

        local backpack =
            player:FindFirstChild(
                "Backpack"
            )

        if not backpack then
            return
        end

        binding.BackpackToolAdded =
            trackConnection(
                backpack.ChildAdded:Connect(
                    function(object)
                        if isRoleWeaponObject(
                            object
                        ) then

                            scheduleToolRoleRefresh(
                                player
                            )
                        end
                    end
                )
            )

        binding.BackpackToolRemoved =
            trackConnection(
                backpack.ChildRemoved:Connect(
                    function(object)
                        if isRoleWeaponObject(
                            object
                        ) then

                            scheduleToolRoleRefresh(
                                player
                            )
                        end
                    end
                )
            )
    end

    local function bindPlayer(player)
        if player == LocalPlayer then
            return
        end

        if state.PlayerBindings[player] then
            return
        end

        local bindings = {}
        state.PlayerBindings[player] = bindings

        bindCharacterToolSignals(
            player,
            player.Character,
            bindings
        )

        bindBackpackToolSignals(
            player,
            bindings
        )

        bindings.CharacterAdded =
            trackConnection(
                player.CharacterAdded:Connect(
                    function(character)
                        bindCharacterToolSignals(
                            player,
                            character,
                            bindings
                        )

                        task.defer(function()
                            if state.Alive then
                                scheduleToolRoleRefresh(
                                    player
                                )

                                applyPlayerESP(
                                    player
                                )
                            end
                        end)
                    end
                )
            )

        bindings.CharacterRemoving =
            trackConnection(
                player.CharacterRemoving:Connect(
                    function()
                        destroyESP(player)

                        -- Character weapon may simply be moving back to Backpack,
                        -- so defer one refresh instead of immediately clearing.
                        task.defer(function()
                            if state.Alive then
                                scheduleToolRoleRefresh(
                                    player
                                )
                            end
                        end)
                    end
                )
            )

        local childAdded =
            player.ChildAdded:Connect(
                function(child)
                    if child.Name == "Backpack" then
                        bindBackpackToolSignals(
                            player,
                            bindings
                        )

                        scheduleToolRoleRefresh(
                            player
                        )
                    end
                end
            )

        bindings.PlayerChildAdded =
            trackConnection(
                childAdded
            )

        refreshToolRole(player)
        applyPlayerESP(player)
    end

    local function unbindPlayer(player)
        destroyESP(player)
        state.PlayerBindings[player] = nil

        state.RoleByUserId[
            player.UserId
        ] = nil

        state.RoleByName[
            player.Name
        ] = nil

        state.ToolRoleByUserId[
            player.UserId
        ] = nil

        state.ToolRoleByName[
            player.Name
        ] = nil

        state.ToolEvidence[
            player.UserId
        ] = nil
    end


    -- ============================================================
    -- SHERIFF / HERO GUN TRACKING
    -- ============================================================

    local function isDeadRecord(record)
        return type(record) == "table"
            and (
                record.Dead == true
                or record.Killed == true
            )
    end

    local function isGunCarrierRole(role)
        role = normalizeRole(role)

        return role == "Sheriff"
            or role == "Hero"
    end

    local function getPlayerByRecord(name, record)
        if type(record) ~= "table" then
            return nil
        end

        local userId =
            tonumber(record.UserId)

        if userId then
            local player =
                Players:GetPlayerByUserId(
                    userId
                )

            if player then
                return player
            end
        end

        if name then
            return Players:FindFirstChild(
                tostring(name)
            )
        end

        return nil
    end

    local function getCharacterRoot(player)
        local character =
            player
            and player.Character

        if not character then
            return nil
        end

        return character:FindFirstChild(
            "HumanoidRootPart"
        )
            or character:FindFirstChild(
                "UpperTorso"
            )
            or character:FindFirstChild(
                "Torso"
            )
    end

    local function sampleCarrierPosition(userId, name, role)
        local player =
            userId
            and Players:GetPlayerByUserId(
                tonumber(userId) or -1
            )
            or nil

        if not player and name then
            player =
                Players:FindFirstChild(
                    tostring(name)
                )
        end

        local root =
            getCharacterRoot(player)

        if not root then
            return false
        end

        state.Gun.LastCarrierUserId =
            player.UserId

        state.Gun.LastCarrierName =
            player.Name

        state.Gun.LastCarrierRole =
            normalizeRole(role)

        state.Gun.LastCarrierCFrame =
            root.CFrame

        state.Gun.LastCarrierSampleAt =
            os.clock()

        return true
    end

    local function sampleCurrentCarrierPosition()
        if not state.Gun.CurrentCarrierUserId then
            return false
        end

        return sampleCarrierPosition(
            state.Gun.CurrentCarrierUserId,
            state.Gun.CurrentCarrierName,
            state.Gun.CurrentCarrierRole
        )
    end

    local function getObjectWorldPosition(object)
        if not object
            or not object.Parent then
            return nil
        end

        if object:IsA("BasePart") then
            return object.Position
        end

        if object:IsA("Model") then
            local ok, pivot =
                pcall(
                    object.GetPivot,
                    object
                )

            if ok and pivot then
                return pivot.Position
            end
        end

        if object:IsA("Tool") then
            local handle =
                object:FindFirstChild(
                    "Handle"
                )

            if handle
                and handle:IsA("BasePart") then
                return handle.Position
            end
        end

        local part =
            object:FindFirstChildWhichIsA(
                "BasePart",
                true
            )

        return part and part.Position or nil
    end

    local function destroyGunHighlight()
        local highlight =
            state.Gun.DropHighlight

        if highlight then
            pcall(function()
                highlight:Destroy()
            end)

            state.Gun.DropHighlight = nil
        end
    end

    local function destroyGunESP()
        local billboard =
            state.Gun.DropBillboard

        if billboard then
            pcall(function()
                billboard:Destroy()
            end)
        end

        state.Gun.DropBillboard = nil
        state.Gun.DropLabel = nil
    end

    local function getLocalRoot()
        local character =
            LocalPlayer.Character

        if not character then
            return nil
        end

        return character:FindFirstChild(
            "HumanoidRootPart"
        )
            or character:FindFirstChild(
                "UpperTorso"
            )
            or character:FindFirstChild(
                "Torso"
            )
    end

    local function updateGunESP()
        if not gunESPEnabled then
            return
        end

        local gunDrop =
            state.Gun.DroppedInstance

        local label =
            state.Gun.DropLabel

        -- Do a direct physical check here. `isExactGunDrop` is declared later
        -- in this module, so relying on it here previously caused this function
        -- to return before the distance could replace "[? studs]".
        if not gunDrop
            or not gunDrop:IsA("BasePart")
            or gunDrop.Name ~= "GunDrop"
            or not gunDrop:IsDescendantOf(
                workspace
            )
            or not label
            or not label.Parent then

            return
        end

        local localPosition = nil

        local root =
            getLocalRoot()

        if root then
            localPosition =
                root.Position
        else
            local character =
                LocalPlayer.Character

            if character then
                local ok, pivot =
                    pcall(
                        character.GetPivot,
                        character
                    )

                if ok
                    and typeof(pivot) == "CFrame" then

                    localPosition =
                        pivot.Position
                end
            end
        end

        if not localPosition then
            -- Never leave a stale question mark on-screen.
            if label.Text
                ~= "Gun Dropped" then

                label.Text =
                    "Gun Dropped"
            end

            return
        end

        local distance =
            (
                localPosition
                - gunDrop.Position
            ).Magnitude

        local nextText =
            string.format(
                "Gun Dropped [%d studs]",
                math.floor(
                    distance + 0.5
                )
            )

        if label.Text ~= nextText then
            label.Text = nextText
        end
    end

    local function applyGunESP()
        destroyGunESP()

        local gunDrop =
            state.Gun.DroppedInstance

        if not gunESPEnabled
            or not gunDrop
            or not gunDrop.Parent
            or gunDrop.Name ~= "GunDrop" then

            return
        end

        local billboard =
            Instance.new("BillboardGui")

        billboard.Name =
            "Vitality_MM2_GunDropESP"

        billboard.Adornee =
            gunDrop

        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0

        billboard.Size =
            UDim2.fromOffset(
                190,
                30
            )

        billboard.StudsOffsetWorldSpace =
            Vector3.new(
                0,
                2.1,
                0
            )

        billboard.Parent =
            gunDrop

        local label =
            Instance.new("TextLabel")

        label.Name = "GunDropText"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)

        label.Font =
            Enum.Font.GothamSemibold

        label.TextSize = 14
        label.TextStrokeTransparency = 0.20

        label.TextColor3 =
            Color3.fromRGB(
                255,
                225,
                90
            )

        label.Text = "Gun Dropped"
        label.Parent = billboard

        state.Gun.DropBillboard =
            billboard

        state.Gun.DropLabel =
            label

        updateGunESP()
    end

    local function clearDropConnections()
        for _, connection in ipairs(
            state.Gun.DropConnections
        ) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        state.Gun.DropConnections = {}
        destroyGunHighlight()
        destroyGunESP()
    end

    local function isExactGunDrop(object)
        return object ~= nil
            and object:IsA("BasePart")
            and object.Name == "GunDrop"
            and object:IsDescendantOf(
                workspace
            )
    end

    local function applyGunChams()
        destroyGunHighlight()

        local gunDrop =
            state.Gun.DroppedInstance

        if not gunChamsEnabled
            or not isExactGunDrop(
                gunDrop
            ) then

            return
        end

        local highlight =
            Instance.new("Highlight")

        highlight.Name =
            "Vitality_MM2_GunDropHighlight"

        highlight.Adornee =
            gunDrop

        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.FillColor =
            Color3.fromRGB(
                255,
                210,
                70
            )

        highlight.OutlineColor =
            Color3.fromRGB(
                255,
                245,
                180
            )

        highlight.FillTransparency = 0.30
        highlight.OutlineTransparency = 0
        highlight.Parent = gunDrop

        state.Gun.DropHighlight =
            highlight
    end

    local function onGunDropRemoved(
        gunDrop
    )
        if state.Gun.DroppedInstance
            ~= gunDrop then

            return
        end

        state.Gun.DroppedInstance =
            nil

        state.Gun.LastDropRemovedAt =
            os.clock()

        clearDropConnections()

        -- The physical pickup disappearing is enough to re-check role tools.
        -- This lets an actual Gun tool reveal the new Sheriff/Hero carrier even
        -- before the next PlayerDataChanged snapshot arrives.
        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            if player ~= LocalPlayer then
                refreshToolRole(
                    player
                )
            end
        end
    end

    local function setExactGunDrop(
        gunDrop
    )
        if not isExactGunDrop(
            gunDrop
        ) then

            return false
        end

        if state.Gun.DroppedInstance
            == gunDrop then

            applyGunChams()
            applyGunESP()
            return true
        end

        clearDropConnections()

        state.Gun.DroppedInstance =
            gunDrop

        state.Gun.DroppedDetectedAt =
            os.clock()

        state.Gun.WaitingForDrop =
            true

        local ancestryConnection =
            gunDrop.AncestryChanged:Connect(
                function()
                    if not state.Alive then
                        return
                    end

                    if not gunDrop:IsDescendantOf(
                        workspace
                    ) then

                        onGunDropRemoved(
                            gunDrop
                        )
                    end
                end
            )

        local destroyingConnection =
            gunDrop.Destroying:Connect(
                function()
                    if state.Alive then
                        onGunDropRemoved(
                            gunDrop
                        )
                    end
                end
            )

        table.insert(
            state.Gun.DropConnections,
            ancestryConnection
        )

        table.insert(
            state.Gun.DropConnections,
            destroyingConnection
        )

        applyGunChams()
        applyGunESP()

        if notifyGunDrop then
            Window:Notify({
                Title = "Gun dropped",
                Content = "The dropped gun was detected.",
                Duration = 4,
            })
        end

        return true
    end

    local function findExistingGunDrop()
        local object =
            workspace:FindFirstChild(
                "GunDrop",
                true
            )

        if isExactGunDrop(
            object
        ) then

            return object
        end

        return nil
    end

    local function scanForDroppedGunOnce(
        generation
    )
        if not state.Alive
            or not state.Gun.WaitingForDrop
            or generation
                ~= state.Gun.DropGeneration then

            return false
        end

        local existing =
            findExistingGunDrop()

        if existing then
            return setExactGunDrop(
                existing
            )
        end

        return false
    end

    local function autoTeleportToConfirmedDrop(
        deathGeneration
    )
        if not autoTeleportOnCarrierDeath
            or not state.Alive
            or not state.Gun.WaitingForDrop
            or deathGeneration
                ~= state.Gun.DropGeneration then

            return false
        end

        state.Gun.AutoTeleportGeneration =
            deathGeneration

        -- The exact GunDrop normally appears almost immediately after the
        -- server confirms the Sheriff/Hero as dead. This search is bounded.
        local deadline =
            os.clock() + 2.0

        repeat
            if not state.Alive
                or deathGeneration
                    ~= state.Gun.DropGeneration
                or not state.Gun.WaitingForDrop then

                return false
            end

            local gunDrop =
                state.Gun.DroppedInstance

            if not isExactGunDrop(
                gunDrop
            ) then
                gunDrop =
                    findExistingGunDrop()

                if gunDrop then
                    setExactGunDrop(
                        gunDrop
                    )
                end
            end

            if isExactGunDrop(
                gunDrop
            ) then

                if state.Gun.AutoTeleportCompletedGeneration
                    == deathGeneration then

                    return true
                end

                local character =
                    LocalPlayer.Character

                local root =
                    character
                    and (
                        character:FindFirstChild(
                            "HumanoidRootPart"
                        )
                        or character:FindFirstChild(
                            "UpperTorso"
                        )
                        or character:FindFirstChild(
                            "Torso"
                        )
                    )

                if not character
                    or not root then

                    return false
                end

                local originalCFrame =
                    root.CFrame

                local moved =
                    pcall(function()
                        character:PivotTo(
                            CFrame.new(
                                gunDrop.Position
                                + Vector3.new(
                                    0,
                                    2.25,
                                    0
                                )
                            )
                        )
                    end)

                if not moved then
                    return false
                end

                state.Gun.AutoTeleportCompletedGeneration =
                    deathGeneration

                -- Stay on the pickup for only a short bounded window. Return
                -- immediately if the GunDrop disappears, otherwise return at
                -- the timeout so Auto-teleport never strands the player.
                local pickupDeadline =
                    os.clock() + 0.45

                repeat
                    if not state.Alive then
                        break
                    end

                    if not isExactGunDrop(
                        gunDrop
                    ) then
                        break
                    end

                    task.wait(0.03)
                until os.clock()
                    >= pickupDeadline

                if state.Alive
                    and LocalPlayer.Character
                        == character then

                    pcall(function()
                        character:PivotTo(
                            originalCFrame
                        )
                    end)
                end

                Window:Notify({
                    Title = "Dropped Gun",
                    Content = "Auto-picked up GunDrop and returned.",
                    Duration = 3,
                })

                return true
            end

            task.wait(0.05)
        until os.clock() >= deadline

        return false
    end

    local function getGunTargetPosition()
        local dropped =
            state.Gun.DroppedInstance

        if dropped
            and dropped.Parent then

            local position =
                getObjectWorldPosition(
                    dropped
                )

            if position then
                return position, "dropped gun"
            end
        end

        local last =
            state.Gun.LastCarrierCFrame

        if last then
            return last.Position, "last known carrier position"
        end

        return nil, nil
    end

    local function teleportToGun()
        if not isExactGunDrop(
            state.Gun.DroppedInstance
        ) then

            local existing =
                findExistingGunDrop()

            if existing then
                setExactGunDrop(
                    existing
                )
            end
        end

        local position, source =
            getGunTargetPosition()

        if not position then
            Window:Notify({
                Title = "Teleport to Gun",
                Content = "No live GunDrop or cached gun position is available.",
                Duration = 4,
                Type = "failed",
            })

            return false
        end

        local character =
            LocalPlayer.Character

        if not character then
            return false
        end

        local ok =
            pcall(function()
                character:PivotTo(
                    CFrame.new(
                        position
                        + Vector3.new(
                            0,
                            3,
                            0
                        )
                    )
                )
            end)

        if ok then
            Window:Notify({
                Title = "Teleport to Gun",
                Content = "Teleported to "
                    .. tostring(source)
                    .. ".",
                Duration = 3,
            })
        end

        return ok
    end

    local function roleStateSignature(record)
        if type(record) ~= "table" then
            return "nil"
        end

        return table.concat({
            tostring(
                tonumber(record.UserId)
                or ""
            ),
            normalizeRole(record.Role),
            isDeadRecord(record)
                and "dead"
                or "alive",
        }, "|")
    end

    local function registerGunPickup(
        player,
        role
    )
        if not player then
            return
        end

        state.Gun.WaitingForDrop = false

        -- The physical GunDrop is authoritative for drop visuals. Do not clear
        -- it from a role update until Roblox actually removes/reparents it.
        if not isExactGunDrop(
            state.Gun.DroppedInstance
        ) then

            clearDropConnections()

            state.Gun.DroppedInstance =
                nil
        end

        state.Gun.CurrentCarrierUserId =
            player.UserId

        state.Gun.CurrentCarrierName =
            player.Name

        state.Gun.CurrentCarrierRole =
            normalizeRole(role)

        sampleCurrentCarrierPosition()
    end

    local function handleCarrierDeath(
        player,
        record
    )
        if not player then
            return
        end

        -- One final local position sample, but this function itself is only
        -- reached after server role data says Dead/Killed.
        sampleCarrierPosition(
            player.UserId,
            player.Name,
            record and record.Role
        )

        state.Gun.LastCarrierUserId =
            player.UserId

        state.Gun.LastCarrierName =
            player.Name

        state.Gun.LastCarrierRole =
            normalizeRole(
                record and record.Role
            )

        state.Gun.CurrentCarrierUserId =
            nil
        state.Gun.CurrentCarrierName =
            nil
        state.Gun.CurrentCarrierRole =
            nil

        state.Gun.WaitingForDrop = true
        state.Gun.DroppedInstance = nil
        state.Gun.DroppedDetectedAt = nil
        state.Gun.DropGeneration += 1
        state.Gun.AutoTeleportGeneration =
            state.Gun.DropGeneration

        local generation =
            state.Gun.DropGeneration

        warn(
            "[VitalityHub/MM2] Server confirmed "
                .. tostring(
                    state.Gun.LastCarrierRole
                )
                .. " death:",
            player.Name,
            state.Gun.LastCarrierCFrame
                and tostring(
                    state.Gun.LastCarrierCFrame.Position
                )
                or "no cached position"
        )

        if notifyGunDrop then
            Window:Notify({
                Title = "Sheriff/Hero down",
                Content = player.Name
                    .. " died. Gun position cached.",
                Duration = 4,
            })
        end



        -- Role death still triggers a bounded confirmation scan for the
        -- auto-teleport flow, but Chams/ESP/Notify no longer depend on this.
        -- The Workspace listener detects the physical GunDrop independently.
        task.delay(
            0.05,
            function()
                if state.Alive
                    and generation
                        == state.Gun.DropGeneration then

                    scanForDroppedGunOnce(
                        generation
                    )
                end
            end
        )

        -- If enabled, wait briefly for the real GunDrop to replicate and then
        -- teleport to GunDrop.Position. We never auto-teleport to the corpse's
        -- cached position.
        if autoTeleportOnCarrierDeath then
            task.spawn(function()
                autoTeleportToConfirmedDrop(
                    generation
                )
            end)
        end
    end

    local function processRoleTransition(
        name,
        oldRecord,
        newRecord
    )
        if type(newRecord) ~= "table" then
            return
        end

        local player =
            getPlayerByRecord(
                name,
                newRecord
            )

        local oldRole =
            normalizeRole(
                oldRecord
                and oldRecord.Role
            )

        local newRole =
            normalizeRole(
                newRecord.Role
            )

        local wasDead =
            isDeadRecord(
                oldRecord
            )

        local isDead =
            isDeadRecord(
                newRecord
            )

        if oldRecord
            and isGunCarrierRole(
                oldRole
            )
            and not wasDead
            and isDead then

            handleCarrierDeath(
                player,
                newRecord
            )

            return
        end

        if isGunCarrierRole(newRole)
            and not isDead
            and player then

            local becameHero =
                newRole == "Hero"
                and (
                    not oldRecord
                    or oldRole ~= "Hero"
                    or wasDead
                )

            local changedCarrier =
                state.Gun.CurrentCarrierUserId
                ~= player.UserId
                or state.Gun.CurrentCarrierRole
                    ~= newRole

            if becameHero
                and state.Gun.WaitingForDrop then

                registerGunPickup(
                    player,
                    newRole
                )

            elseif changedCarrier then
                state.Gun.CurrentCarrierUserId =
                    player.UserId

                state.Gun.CurrentCarrierName =
                    player.Name

                state.Gun.CurrentCarrierRole =
                    newRole

                if newRole == "Sheriff" then
                    state.Gun.WaitingForDrop = false

                    if not isExactGunDrop(
                        state.Gun.DroppedInstance
                    ) then

                        state.Gun.DroppedInstance = nil
                    end
                end

                sampleCurrentCarrierPosition()
            end
        end
    end


    -- ============================================================
    -- COMBAT
    -- ============================================================

    local function getEffectiveRole(
        player
    )
        local record =
            getRoleRecord(
                player
            )

        return record
            and normalizeRole(
                record.Role
            )
            or "Unknown"
    end

    local function isAliveCombatTarget(
        player
    )
        if not player
            or player == LocalPlayer then

            return false
        end

        local record =
            getRoleRecord(
                player
            )

        if type(record) == "table"
            and (
                record.Dead == true
                or record.Killed == true
            ) then

            return false
        end

        local character =
            player.Character

        if not character then
            return false
        end

        local humanoid =
            character:FindFirstChildOfClass(
                "Humanoid"
            )

        if humanoid
            and humanoid.Health <= 0 then

            return false
        end

        return getCharacterRoot(
            player
        ) ~= nil
    end

    local function getMurdererPlayer()
        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            if player ~= LocalPlayer
                and isAliveCombatTarget(
                    player
                )
                and getEffectiveRole(
                    player
                ) == "Murderer" then

                return player
            end
        end

        return nil
    end

    local function getMurdererRawAimPart()
        local murderer =
            getMurdererPlayer()

        if not murderer
            or not murderer.Character then

            return nil, nil
        end

        local part =
            murderer.Character:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or murderer.Character:
                FindFirstChild(
                    "UpperTorso"
                )
            or murderer.Character:
                FindFirstChild(
                    "Torso"
                )
            or murderer.Character:
                FindFirstChild(
                    "Head"
                )

        return part, murderer
    end

    local passesSilentAimFilters

    local function getPredictedAimPosition(
        targetPart,
        originPosition
    )
        if not targetPart
            or not targetPart.Parent then

            return nil
        end

        local position =
            targetPart.Position

        local velocity =
            targetPart.AssemblyLinearVelocity

        if typeof(velocity) ~= "Vector3" then
            velocity =
                Vector3.zero
        end

        local speed =
            velocity.Magnitude

        local velocityCap =
            state.Combat.PredictionVelocityCap

        if speed > velocityCap
            and speed > 0 then

            velocity =
                velocity.Unit
                * velocityCap
        end

        local distance = 0

        if typeof(originPosition) == "Vector3" then
            distance =
                (
                    position
                    - originPosition
                ).Magnitude
        end

        -- MM2's gun behaves like an immediate server raycast, so this is
        -- latency/movement compensation rather than projectile travel-time
        -- simulation. Distance adds only a small extra lead.
        local predictionTime =
            state.Combat.PredictionBase
            + math.clamp(
                distance / 10000,
                0,
                state.Combat.PredictionMax
                    - state.Combat.PredictionBase
            )

        return position
            + velocity * predictionTime
    end

    local function getPredictedMurdererAim(
        originPosition,
        applyFilters
    )
        local targetPart,
            murderer =
                getMurdererRawAimPart()

        if not targetPart
            or not murderer then

            return nil, nil, nil
        end

        if applyFilters
            and not passesSilentAimFilters(
                targetPart,
                murderer
            ) then

            return nil, nil, nil
        end

        local predicted =
            getPredictedAimPosition(
                targetPart,
                originPosition
            )

        return predicted,
            targetPart,
            murderer
    end

    local function shouldCenterFOV()
        -- Only center the FOV when Roblox is actually treating gameplay aim
        -- as camera-locked. In normal/free third-person, ALWAYS use the mouse.
        if UserInputService.MouseBehavior
            == Enum.MouseBehavior.LockCenter then

            return true
        end

        if LocalPlayer.CameraMode
            == Enum.CameraMode.LockFirstPerson then

            return true
        end

        return false
    end

    local function getFOVReferencePoint()
        local camera =
            workspace.CurrentCamera

        if not camera then
            return nil
        end

        if shouldCenterFOV() then
            return camera.ViewportSize / 2
        end

        -- Free third-person cursor: FOV is centered exactly on the mouse.
        local ok, mouseLocation =
            pcall(
                UserInputService.GetMouseLocation,
                UserInputService
            )

        if ok and mouseLocation then
            return Vector2.new(
                mouseLocation.X,
                mouseLocation.Y
            )
        end

        return camera.ViewportSize / 2
    end

    local function isPartWithinFOV(
        targetPart
    )
        if not state.Combat.UseFOV then
            return true
        end

        local camera =
            workspace.CurrentCamera

        if not camera
            or not targetPart then

            return false
        end

        local screenPoint,
            onScreen =
                camera:
                    WorldToViewportPoint(
                        targetPart.Position
                    )

        if not onScreen
            or screenPoint.Z <= 0 then

            return false
        end

        local referencePoint =
            getFOVReferencePoint()

        if not referencePoint then
            return false
        end

        local targetPoint =
            Vector2.new(
                screenPoint.X,
                screenPoint.Y
            )

        return (
            targetPoint
            - referencePoint
        ).Magnitude
            <= state.Combat.FOVRadius
    end

    local function isVisibleFrom(
        origin,
        targetPart,
        targetCharacter
    )
        if not state.Combat.VisibleCheck then
            return true
        end

        if not origin
            or not targetPart
            or not targetCharacter then

            return false
        end

        local direction =
            targetPart.Position
            - origin

        if direction.Magnitude <= 0.05 then
            return true
        end

        local params =
            RaycastParams.new()

        params.FilterType =
            Enum.RaycastFilterType.Exclude

        params.IgnoreWater =
            true

        local ignore = {}

        if LocalPlayer.Character then
            table.insert(
                ignore,
                LocalPlayer.Character
            )
        end

        params.FilterDescendantsInstances =
            ignore

        local result =
            workspace:Raycast(
                origin,
                direction,
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

    passesSilentAimFilters =
        function(
            targetPart,
            murderer
        )
        if not targetPart
            or not murderer
            or not murderer.Character then

            return false
        end

        if not isPartWithinFOV(
            targetPart
        ) then

            return false
        end

        if state.Combat.VisibleCheck then
            local camera =
                workspace.CurrentCamera

            local origin =
                camera
                and camera.CFrame.Position
                or nil

            if not isVisibleFrom(
                origin,
                targetPart,
                murderer.Character
            ) then

                return false
            end
        end

        return true
    end

    local function getMurdererAimPart()
        local targetPart,
            murderer =
                getMurdererRawAimPart()

        if not passesSilentAimFilters(
            targetPart,
            murderer
        ) then

            return nil
        end

        return targetPart
    end

    local function getLocalGun()
        local character =
            LocalPlayer.Character

        local backpack =
            LocalPlayer:FindFirstChild(
                "Backpack"
            )

        return (
            character
            and character:FindFirstChild(
                "Gun"
            )
        )
            or (
                backpack
                and backpack:FindFirstChild(
                    "Gun"
                )
            )
    end

    local function cacheGunShootRemote(
        gun
    )
        if not gun then
            return nil
        end

        local shoot =
            gun:FindFirstChild(
                "Shoot"
            )

        if shoot
            and shoot:IsA(
                "RemoteEvent"
            ) then

            state.Combat.KnownShootRemotes[
                shoot
            ] = true

            return shoot
        end

        return nil
    end

    local function seedKnownShootRemote()
        local gun =
            getLocalGun()

        local shoot =
            cacheGunShootRemote(
                gun
            )

        if shoot then
            return shoot
        end

        -- Some captures show Shoot becoming nil-parented while still being the
        -- live RemoteEvent. Do a one-shot fallback search only when enabling
        -- Silent Aim; never scan getnilinstances on every shot.
        if type(getnilinstances)
            == "function" then

            local ok, nils =
                pcall(
                    getnilinstances
                )

            if ok
                and type(nils) == "table" then

                for _, object in ipairs(
                    nils
                ) do
                    if object.Name == "Shoot"
                        and object:IsA(
                            "RemoteEvent"
                        ) then

                        state.Combat.KnownShootRemotes[
                            object
                        ] = true
                    end
                end
            end
        end

        return nil
    end

    local function isLocalGunShootRemote(
        remote
    )
        if not remote
            or typeof(remote) ~= "Instance"
            or not remote:IsA(
                "RemoteEvent"
            )
            or remote.Name ~= "Shoot" then

            return false
        end

        if state.Combat.KnownShootRemotes[
            remote
        ] then

            return true
        end

        local gun =
            getLocalGun()

        if not gun then
            return false
        end

        local liveShoot =
            cacheGunShootRemote(
                gun
            )

        if liveShoot == remote
            or remote.Parent == gun then

            state.Combat.KnownShootRemotes[
                remote
            ] = true

            return true
        end

        -- Cobalt showed the same MM2 Shoot RemoteEvent becoming nil-parented.
        -- If the player still owns the live Gun, accept a RemoteEvent named
        -- Shoot here; the hook additionally requires the confirmed
        -- FireServer(CFrame, CFrame) signature before altering anything.
        if remote.Parent == nil then
            state.Combat.KnownShootRemotes[
                remote
            ] = true

            return true
        end

        return false
    end

    local function getKnownShootRemote()
        local gun =
            getLocalGun()

        local live =
            cacheGunShootRemote(
                gun
            )

        if live then
            return live
        end

        for remote in pairs(
            state.Combat.KnownShootRemotes
        ) do
            if remote
                and typeof(remote) == "Instance"
                and remote:IsA(
                    "RemoteEvent"
                )
                and remote.Name == "Shoot" then

                return remote
            end
        end

        seedKnownShootRemote()

        for remote in pairs(
            state.Combat.KnownShootRemotes
        ) do
            if remote
                and typeof(remote) == "Instance"
                and remote:IsA(
                    "RemoteEvent"
                )
                and remote.Name == "Shoot" then

                return remote
            end
        end

        return nil
    end

    local function equipLocalGun()
        local gun =
            getLocalGun()

        if not gun then
            return nil
        end

        local character =
            LocalPlayer.Character

        if character
            and gun.Parent ~= character then

            local humanoid =
                character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            if humanoid then
                pcall(
                    humanoid.EquipTool,
                    humanoid,
                    gun
                )

                task.wait(0.01)

                gun =
                    getLocalGun()
                    or gun
            end
        end

        cacheGunShootRemote(
            gun
        )

        return gun
    end

    local function getGunShotOrigin(
        gun
    )
        if gun then
            local handle =
                gun:FindFirstChild(
                    "Handle"
                )

            if handle
                and handle:IsA(
                    "BasePart"
                ) then

                return handle.CFrame
            end
        end

        local root =
            getCharacterRoot(
                LocalPlayer
            )

        return root
            and root.CFrame
            or nil
    end

    local function buildPredictedMurdererShot(
        gun,
        applyFilters
    )
        if not gun then
            return nil, nil, nil, nil
        end

        local originCFrame =
            getGunShotOrigin(
                gun
            )

        if typeof(originCFrame)
            ~= "CFrame" then

            return nil, nil, nil, nil
        end

        -- ONE shared origin + prediction path for Silent Aim and Shoot Murderer.
        local predictedPosition,
            targetPart,
            murderer =
                getPredictedMurdererAim(
                    originCFrame.Position,
                    applyFilters == true
                )

        if typeof(predictedPosition)
            ~= "Vector3"
            or not targetPart
            or not murderer then

            return nil, nil, nil, nil
        end

        return originCFrame,
            CFrame.new(
                predictedPosition
            ),
            targetPart,
            murderer
    end

    local function getShootTeleportCFrame(
        targetPart,
        murderer
    )
        local root =
            murderer
            and getCharacterRoot(
                murderer
            )

        if not root
            or not targetPart then

            return nil
        end

        local targetPosition =
            targetPart.Position

        local offsetDirection =
            -root.CFrame.LookVector

        local position =
            targetPosition
            + offsetDirection * 2.25
            + Vector3.new(
                0,
                0.65,
                0
            )

        return CFrame.lookAt(
            position,
            targetPosition
        )
    end

    local function faceCombatTarget(
        character,
        targetPart
    )
        if not character
            or not targetPart then

            return false
        end

        local root =
            getCharacterRoot(
                LocalPlayer
            )

        if not root then
            return false
        end

        local rootPosition =
            root.Position

        local targetPosition =
            targetPart.Position

        local flatTarget =
            Vector3.new(
                targetPosition.X,
                rootPosition.Y,
                targetPosition.Z
            )

        if (
            flatTarget
            - rootPosition
        ).Magnitude <= 0.05 then

            return true
        end

        return pcall(function()
            character:PivotTo(
                CFrame.lookAt(
                    rootPosition,
                    flatTarget
                )
            )
        end)
    end

    local function shootMurderer(
        notifyResult,
        returnCFrameOverride,
        forcedShootRemote
    )
        if state.Combat.ShootBusy then
            return false
        end

        state.Combat.ShootBusy =
            true

        local targetPart,
            murderer =
                getMurdererRawAimPart()

        if not targetPart
            or not murderer then

            state.Combat.ShootBusy =
                false

            if notifyResult then
                Window:Notify({
                    Title = "Shoot Murderer",
                    Content = "No living Murderer was detected.",
                    Duration = 3,
                    Type = "failed",
                })
            end

            return false
        end

        local character =
            LocalPlayer.Character

        local localRoot =
            getCharacterRoot(
                LocalPlayer
            )

        local gun =
            equipLocalGun()

        local shootRemote =
            forcedShootRemote
            or cacheGunShootRemote(
                gun
            )
            or getKnownShootRemote()

        if not character
            or not localRoot
            or not gun
            or not shootRemote then

            state.Combat.ShootBusy =
                false

            if notifyResult then
                Window:Notify({
                    Title = "Shoot Murderer",
                    Content = "A usable local Gun/Shoot remote was not found.",
                    Duration = 4,
                    Type = "failed",
                })
            end

            return false
        end

        local originalCFrame =
            typeof(returnCFrameOverride) == "CFrame"
            and returnCFrameOverride
            or localRoot.CFrame

        local teleportCFrame =
            getShootTeleportCFrame(
                targetPart,
                murderer
            )

        if not teleportCFrame then
            state.Combat.ShootBusy =
                false
            return false
        end

        local moved =
            pcall(function()
                character:PivotTo(
                    teleportCFrame
                )
            end)

        if not moved then
            state.Combat.ShootBusy =
                false
            return false
        end

        -- Silent Aim works best because prediction happens immediately before
        -- the remote call. Keep only a tiny replication settle after teleport.
        task.wait(0.035)

        gun =
            getLocalGun()
            or gun

        if not forcedShootRemote then
            shootRemote =
                cacheGunShootRemote(
                    gun
                )
                or shootRemote
        end

        -- EXACT SAME live Gun.Handle + movement prediction builder as Silent Aim.
        local originCFrame,
            aimCFrame,
            liveTarget,
            liveMurderer =
                buildPredictedMurdererShot(
                    gun,
                    false
                )

        if liveTarget
            and liveMurderer then

            targetPart =
                liveTarget

            murderer =
                liveMurderer
        end

        local canShoot =
            typeof(originCFrame) == "CFrame"
            and typeof(aimCFrame) == "CFrame"
            and targetPart ~= nil
            and murderer ~= nil
            and murderer.Character ~= nil

        if canShoot
            and state.Combat.VisibleCheck then

            canShoot =
                isVisibleFrom(
                    originCFrame.Position,
                    targetPart,
                    murderer.Character
                )
        end

        local fired = false

        if canShoot then
            fired =
                pcall(function()
                    shootRemote:FireServer(
                        originCFrame,
                        aimCFrame
                    )
                end)
        end

        -- Short processing window, then restore the exact cached position.
        task.wait(0.08)

        if state.Alive
            and LocalPlayer.Character == character then

            pcall(function()
                character:PivotTo(
                    originalCFrame
                )
            end)
        end

        state.Combat.ShootBusy =
            false

        if notifyResult then
            Window:Notify({
                Title = "Shoot Murderer",
                Content = fired
                    and (
                        "Fired predicted shot at "
                        .. murderer.Name
                        .. "."
                    )
                    or (
                        state.Combat.VisibleCheck
                        and "Shot blocked by visibility check."
                        or "The gun could not be fired."
                    ),
                Duration = 3,
                Type = fired
                    and nil
                    or "failed",
            })
        end

        return fired
    end

    local function pickupDroppedGunAndShootMurderer()
        if state.Combat.ShootBusy then
            return false
        end

        local existingGun =
            getLocalGun()

        if existingGun then
            return shootMurderer(
                true
            )
        end

        local gunDrop =
            state.Gun.DroppedInstance

        if not isExactGunDrop(
            gunDrop
        ) then

            gunDrop =
                findExistingGunDrop()

            if gunDrop then
                setExactGunDrop(
                    gunDrop
                )
            end
        end

        if not isExactGunDrop(
            gunDrop
        ) then

            Window:Notify({
                Title = "Shoot Murderer",
                Content = "You do not have the Gun and no dropped GunDrop was found.",
                Duration = 4,
                Type = "failed",
            })

            return false
        end

        local character =
            LocalPlayer.Character

        local root =
            getCharacterRoot(
                LocalPlayer
            )

        if not character
            or not root then

            return false
        end

        local originalCFrame =
            root.CFrame

        local moved =
            pcall(function()
                character:PivotTo(
                    CFrame.new(
                        gunDrop.Position
                        + Vector3.new(
                            0,
                            2.0,
                            0
                        )
                    )
                )
            end)

        if not moved then
            return false
        end

        -- Wait only long enough for the pickup to replicate into Backpack /
        -- Character. If it fails, return immediately to the cached position.
        local pickupDeadline =
            os.clock() + 0.55

        local pickedGun = nil

        repeat
            pickedGun =
                getLocalGun()

            if pickedGun then
                break
            end

            task.wait(0.025)
        until os.clock()
            >= pickupDeadline

        if not pickedGun then
            if state.Alive
                and LocalPlayer.Character
                    == character then

                pcall(function()
                    character:PivotTo(
                        originalCFrame
                    )
                end)
            end

            Window:Notify({
                Title = "Shoot Murderer",
                Content = "GunDrop was found, but the Gun was not picked up in time.",
                Duration = 4,
                Type = "failed",
            })

            return false
        end

        -- Let the newly-picked-up Gun settle in Backpack/Character before
        -- teleporting again for the shot.
        task.wait(0.10)

        -- shootMurderer explicitly aims at the detected living Murderer and
        -- restores to the position from BEFORE we went to GunDrop.
        return shootMurderer(
            true,
            originalCFrame
        )
    end

    local function disconnectSilentAimGun()
        local connection =
            state.Combat.SilentAimGunConnection

        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end

        state.Combat.SilentAimGunConnection = nil
        state.Combat.SilentAimGun = nil
    end

    local function fireSilentAimAssist(
        gun
    )
        if not state.Alive
            or not state.Combat.SilentAimEnabled
            or not gun
            or gun ~= getLocalGun() then

            return false
        end

        local now =
            os.clock()

        if now
            - state.Combat.LastSilentAimShotAt
            < 0.04 then

            return false
        end

        state.Combat.LastSilentAimShotAt =
            now

        local shootRemote =
            cacheGunShootRemote(
                gun
            )
            or getKnownShootRemote()

        if not shootRemote then
            return false
        end

        -- EXACT SAME builder used by Shoot Murderer.
        local originCFrame,
            aimCFrame =
                buildPredictedMurdererShot(
                    gun,
                    true
                )

        if typeof(originCFrame)
                ~= "CFrame"
            or typeof(aimCFrame)
                ~= "CFrame" then

            return false
        end

        local ok =
            pcall(function()
                shootRemote:FireServer(
                    originCFrame,
                    aimCFrame
                )
            end)

        return ok
    end

    local function bindSilentAimGun(
        gun
    )
        if state.Combat.SilentAimGun == gun
            and state.Combat.SilentAimGunConnection then

            return true
        end

        disconnectSilentAimGun()

        if not gun
            or not gun:IsA("Tool") then

            return false
        end

        state.Combat.SilentAimGun =
            gun

        state.Combat.SilentAimGunConnection =
            gun.Activated:Connect(
                function()
                    if not state.Alive
                        or not state.Combat.SilentAimEnabled then

                        return
                    end

                    -- No task.wait, teleport, camera change, or mouse change.
                    -- Calculate and fire the assisted endpoint immediately when
                    -- the user actually activates/fires the Gun.
                    fireSilentAimAssist(
                        gun
                    )
                end
            )

        return true
    end

    local function ensureSilentAimGunBinding()
        if not state.Combat.SilentAimEnabled then
            disconnectSilentAimGun()
            return
        end

        local gun =
            getLocalGun()

        if gun then
            bindSilentAimGun(
                gun
            )
        else
            disconnectSilentAimGun()
        end
    end

    local function maybeAutoShootMurderer()
        if not state.Combat.AutoShootEnabled
            or state.Combat.ShootBusy
            or not state.Alive then

            return
        end

        local now =
            os.clock()

        if now
            - state.Combat.LastAutoShootAt
            < state.Combat.AutoShootCooldown then

            return
        end

        if not getLocalGun() then
            return
        end

        local targetPart,
            murderer =
                getMurdererRawAimPart()

        if not targetPart
            or not murderer then

            return
        end

        state.Combat.LastAutoShootAt =
            now

        task.spawn(function()
            shootMurderer(
                false
            )
        end)
    end

    local function isLocalMurderer()
        if getEffectiveRole(
            LocalPlayer
        ) == "Murderer" then

            return true
        end

        -- Fallback to the actual live Knife object if the server role table has
        -- not arrived yet. Cosmetic inventory strings are never used here.
        local character =
            LocalPlayer.Character

        local backpack =
            LocalPlayer:FindFirstChild(
                "Backpack"
            )

        local knife =
            (
                character
                and character:FindFirstChild(
                    "Knife"
                )
            )
            or (
                backpack
                and backpack:FindFirstChild(
                    "Knife"
                )
            )

        return knife ~= nil
            and (
                knife:IsA("Tool")
                or knife:IsA("Model")
            )
    end

    local function notifyNotMurderer()
        Window:Notify({
            Title = "Not Murderer",
            Content = "This action is only available while you are the Murderer.",
            Duration = 3,
            Type = "failed",
        })
    end

    local function getLivingSheriffOrHero()
        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            if player ~= LocalPlayer
                and isAliveCombatTarget(
                    player
                ) then

                local role =
                    getEffectiveRole(
                        player
                    )

                if role == "Sheriff"
                    or role == "Hero" then

                    return player
                end
            end
        end

        return nil
    end

    local function getLocalKnife()
        local character =
            LocalPlayer.Character

        local backpack =
            LocalPlayer:FindFirstChild(
                "Backpack"
            )

        return (
            character
            and character:FindFirstChild(
                "Knife"
            )
        )
            or (
                backpack
                and backpack:FindFirstChild(
                    "Knife"
                )
            )
    end

    local function getKnifeStabRemote(
        knife
    )
        if not knife then
            return nil
        end

        local events =
            knife:FindFirstChild(
                "Events"
            )

        local remote =
            events
            and events:FindFirstChild(
                "KnifeStabbed"
            )

        if remote
            and remote:IsA(
                "RemoteEvent"
            ) then

            return remote
        end

        return nil
    end

    local function equipLocalKnife()
        local knife =
            getLocalKnife()

        if not knife then
            return nil
        end

        local character =
            LocalPlayer.Character

        if character
            and knife.Parent ~= character then

            local humanoid =
                character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            if humanoid then
                pcall(
                    humanoid.EquipTool,
                    humanoid,
                    knife
                )

                task.wait(0.05)
            end
        end

        return getLocalKnife()
    end

    local function swingLocalKnife(
        knife
    )
        if not knife
            or not knife:IsA("Tool") then

            return false
        end

        local character =
            LocalPlayer.Character

        if not character then
            return false
        end

        if knife.Parent ~= character then
            local humanoid =
                character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            if humanoid then
                pcall(
                    humanoid.EquipTool,
                    humanoid,
                    knife
                )

                task.wait(0.025)
            end
        end

        if knife.Parent ~= character then
            return false
        end

        -- Use the Tool's real activation path. This is what produces the
        -- normal knife swing/animation rather than only firing KnifeStabbed.
        local ok =
            pcall(function()
                knife:Activate()
            end)

        return ok
    end

    local function stabCombatTarget(
        knife,
        remote,
        targetPlayer
    )
        local localRoot =
            getCharacterRoot(
                LocalPlayer
            )

        local targetRoot =
            getCharacterRoot(
                targetPlayer
            )

        if not localRoot
            or not targetRoot
            or not remote then

            return false
        end

        local character =
            LocalPlayer.Character

        local handle =
            knife
            and knife:FindFirstChild(
                "Handle"
            )

        if not character then
            return false
        end

        -- Move very close/overlapping instead of immediately hopping past the
        -- target. KnifeStabbed has no target argument, so proximity/touch is
        -- still what lets MM2 validate WHICH player was stabbed.
        local targetPosition =
            targetRoot.Position

        local destination =
            CFrame.lookAt(
                targetPosition
                    + Vector3.new(
                        0,
                        0,
                        0.55
                    ),
                targetPosition
            )

        local moved =
            pcall(function()
                character:PivotTo(
                    destination
                )
            end)

        if not moved then
            return false
        end

        -- Give the server a small moment to observe the close position.
        task.wait(0.055)

        -- Actually activate/swing the knife first so MM2 runs the normal
        -- Tool activation/animation path. Then fire the captured KnifeStabbed
        -- remote while the swing is active, before producing touch contact.
        local swung =
            swingLocalKnife(
                knife
            )

        task.wait(
            swung
            and 0.035
            or 0.015
        )

        local fired =
            pcall(function()
                remote:FireServer()
            end)

        if not fired then
            return false
        end

        task.wait(0.02)

        if type(firetouchinterest)
                == "function"
            and handle
            and handle:IsA(
                "BasePart"
            ) then

            local touchParts = {
                targetRoot,
            }

            local targetCharacter =
                targetPlayer.Character

            if targetCharacter then
                local torso =
                    targetCharacter:
                        FindFirstChild(
                            "UpperTorso"
                        )
                    or targetCharacter:
                        FindFirstChild(
                            "Torso"
                        )

                local head =
                    targetCharacter:
                        FindFirstChild(
                            "Head"
                        )

                if torso
                    and torso:IsA(
                        "BasePart"
                    ) then

                    table.insert(
                        touchParts,
                        torso
                    )
                end

                if head
                    and head:IsA(
                        "BasePart"
                    ) then

                    table.insert(
                        touchParts,
                        head
                    )
                end
            end

            for _, part in ipairs(
                touchParts
            ) do
                pcall(
                    firetouchinterest,
                    handle,
                    part,
                    0
                )
            end

            task.wait(0.045)

            for _, part in ipairs(
                touchParts
            ) do
                pcall(
                    firetouchinterest,
                    handle,
                    part,
                    1
                )
            end
        else
            -- Without firetouchinterest, remain overlapped briefly so normal
            -- replicated touch handling still has a chance to validate.
            task.wait(0.06)
        end

        -- Let the real swing/contact finish before KillEvent polling advances.
        task.wait(0.045)

        return true
    end

    local function killEventConfirmedTarget(
        targetPlayer,
        since
    )
        if not targetPlayer then
            return false
        end

        local confirmedAt =
            state.Combat.KillConfirmedAt[
                targetPlayer.Name
            ]

        if confirmedAt
            and confirmedAt >= since then

            return true
        end

        -- PlayerDataChanged remains a second authoritative signal.
        local record =
            getRoleRecord(
                targetPlayer
            )

        if type(record) == "table"
            and (
                record.Dead == true
                or record.Killed == true
            ) then

            return true
        end

        local character =
            targetPlayer.Character

        local humanoid =
            character
            and character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        if humanoid
            and humanoid.Health <= 0 then

            return true
        end

        return false
    end

    local function waitForKillConfirmation(
        targetPlayer,
        since,
        timeout
    )
        local deadline =
            os.clock()
            + (
                tonumber(timeout)
                or 0.75
            )

        repeat
            if not state.Alive then
                return false
            end

            if killEventConfirmedTarget(
                targetPlayer,
                since
            ) then

                return true
            end

            task.wait(0.025)
        until os.clock() >= deadline

        return killEventConfirmedTarget(
            targetPlayer,
            since
        )
    end

    local function stabAndConfirmTarget(
        knife,
        remote,
        targetPlayer,
        maxAttempts
    )
        maxAttempts =
            math.max(
                1,
                tonumber(maxAttempts)
                or 3
            )

        if killEventConfirmedTarget(
            targetPlayer,
            0
        )
            or not isAliveCombatTarget(
                targetPlayer
            ) then

            return true, 0
        end

        for attempt = 1, maxAttempts do
            if not state.Alive
                or not isAliveCombatTarget(
                    targetPlayer
                ) then

                return true, attempt - 1
            end

            local startedAt =
                os.clock()

            local fired =
                stabCombatTarget(
                    knife,
                    remote,
                    targetPlayer
                )

            if fired
                and waitForKillConfirmation(
                    targetPlayer,
                    startedAt,
                    0.70
                ) then

                return true, attempt
            end

            -- Re-acquire/teleport on the next attempt because the target may
            -- have moved while the server was deciding the prior stab.
            task.wait(0.04)
        end

        return killEventConfirmedTarget(
            targetPlayer,
            0
        ), maxAttempts
    end

    local function killEveryoneAsMurderer()
        if not isLocalMurderer() then
            notifyNotMurderer()
            return
        end

        if state.Combat.KillAllBusy then
            return
        end

        state.Combat.KillAllBusy =
            true

        local character =
            LocalPlayer.Character

        local localRoot =
            getCharacterRoot(
                LocalPlayer
            )

        if not character
            or not localRoot then

            state.Combat.KillAllBusy =
                false

            return
        end

        local knife =
            equipLocalKnife()

        local remote =
            getKnifeStabRemote(
                knife
            )

        if not knife
            or not remote then

            Window:Notify({
                Title = "Kill Everyone",
                Content = "A live Knife/KnifeStabbed remote was not found.",
                Duration = 4,
                Type = "failed",
            })

            state.Combat.KillAllBusy =
                false

            return
        end

        local origin =
            localRoot.CFrame

        local targets = {}

        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            if player ~= LocalPlayer
                and isAliveCombatTarget(
                    player
                )
                and getEffectiveRole(
                    player
                ) ~= "Murderer" then

                table.insert(
                    targets,
                    player
                )
            end
        end

        if #targets == 0 then
            Window:Notify({
                Title = "Kill Everyone",
                Content = "No living targets were found.",
                Duration = 3,
            })

            state.Combat.KillAllBusy =
                false

            return
        end

        task.spawn(function()
            local confirmedKills = 0
            local failedTargets = 0

            for _, player in ipairs(
                targets
            ) do
                if not state.Alive then
                    break
                end

                if isAliveCombatTarget(
                    player
                ) then

                    local confirmed =
                        stabAndConfirmTarget(
                            knife,
                            remote,
                            player,
                            3
                        )

                    if confirmed then
                        confirmedKills += 1
                    else
                        failedTargets += 1
                    end
                else
                    -- Already dead by the time we reached them.
                    confirmedKills += 1
                end
            end

            if state.Alive
                and LocalPlayer.Character
                    == character then

                pcall(function()
                    character:PivotTo(
                        origin
                    )
                end)
            end

            state.Combat.KillAllBusy =
                false

            Window:Notify({
                Title = "Kill Everyone",
                Content =
                    "Confirmed "
                    .. tostring(
                        confirmedKills
                    )
                    .. "/"
                    .. tostring(
                        #targets
                    )
                    .. " kills"
                    .. (
                        failedTargets > 0
                        and (
                            " • "
                            .. tostring(
                                failedTargets
                            )
                            .. " unconfirmed"
                        )
                        or ""
                    )
                    .. ".",
                Duration = 4,
                Type =
                    failedTargets > 0
                    and "failed"
                    or nil,
            })
        end)
    end

    local function killSheriffAsMurderer(
        notifyResult
    )
        notifyResult =
            notifyResult ~= false

        if not isLocalMurderer() then
            if notifyResult then
                notifyNotMurderer()
            end

            return false
        end

        if state.Combat.KillAllBusy then
            return
        end

        local target =
            getLivingSheriffOrHero()

        if not target then
            if notifyResult then
                Window:Notify({
                    Title = "Kill Sheriff",
                    Content = "No living Sheriff or Hero was detected.",
                    Duration = 3,
                    Type = "failed",
                })
            end

            return false
        end

        local character =
            LocalPlayer.Character

        local localRoot =
            getCharacterRoot(
                LocalPlayer
            )

        if not character
            or not localRoot then

            return false
        end

        local knife =
            equipLocalKnife()

        local remote =
            getKnifeStabRemote(
                knife
            )

        if not knife
            or not remote then

            if notifyResult then
                Window:Notify({
                    Title = "Kill Sheriff",
                    Content = "A live Knife/KnifeStabbed remote was not found.",
                    Duration = 4,
                    Type = "failed",
                })
            end

            return false
        end

        local originalCFrame =
            localRoot.CFrame

        state.Combat.KillAllBusy =
            true

        task.spawn(function()
            local confirmed =
                stabAndConfirmTarget(
                    knife,
                    remote,
                    target,
                    3
                )

            if state.Alive
                and LocalPlayer.Character
                    == character then

                pcall(function()
                    LocalPlayer.Character:
                        PivotTo(
                            originalCFrame
                        )
                end)
            end

            state.Combat.KillAllBusy =
                false

            if notifyResult then
                Window:Notify({
                    Title = "Kill Sheriff",
                    Content = confirmed
                        and (
                            "Confirmed kill on "
                            .. target.Name
                            .. "."
                        )
                        or (
                            "Sheriff/Hero kill was not confirmed after retries."
                        ),
                    Duration = 3,
                    Type = confirmed
                        and nil
                        or "failed",
                })
            end
        end)

        return true
    end

    local RolesTab =
        Window:CreateTab(
            "Roles",
            "players"
        )

    local GunTab =
        Window:CreateTab(
            "Gun",
            "info"
        )

    local CombatTab =
        Window:CreateTab(
            "Combat",
            "target"
        )

    local MiscTab =
        Window:CreateTab(
            "Misc",
            "sparkles"
        )

    local Personalization =
        Window:CreateTab(
            "Personalization",
            "palette"
        )

    if Personalization.NavButton then
        Personalization.NavButton.Visible = false
    end


    xpcall(function()
        local TweenService =
            game:GetService(
                "TweenService"
            )

        local PathfindingService =
            game:GetService(
                "PathfindingService"
            )

        local camera =
            workspace.CurrentCamera

        local function notify(
            title,
            content,
            failed
        )
            Window:Notify({
                Title = title,
                Content = content,
                Duration = 3,
                Type = failed
                    and "failed"
                    or nil,
            })
        end

        local function getLocalHumanoid()
            local character =
                LocalPlayer.Character

            return character
                and character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )
                or nil
        end

        local function normalizeTargetText(
            value
        )
            return string.lower(
                tostring(
                    value
                    or ""
                )
            )
        end

        local function findBestTargetMatch(
            rawQuery
        )
            local query =
                normalizeTargetText(
                    rawQuery
                )

            if query == "" then
                local selected =
                    state.Misc.TargetPlayer

                if selected
                    and selected.Parent == Players
                    and selected ~= LocalPlayer then

                    return selected,
                        selected.Name,
                        nil
                end

                return nil, nil, nil
            end

            local matches = {}

            local function consider(
                player,
                text,
                score,
                canAutocomplete
            )
                table.insert(
                    matches,
                    {
                        Player = player,
                        Text = text,
                        Score = score,
                        CanAutocomplete =
                            canAutocomplete,
                    }
                )
            end

            for _, player in ipairs(
                Players:GetPlayers()
            ) do
                if player ~= LocalPlayer then
                    local username =
                        tostring(
                            player.Name
                        )

                    local displayName =
                        tostring(
                            player.DisplayName
                            or ""
                        )

                    local lowerUsername =
                        string.lower(
                            username
                        )

                    local lowerDisplay =
                        string.lower(
                            displayName
                        )

                    if lowerUsername
                        == query then

                        consider(
                            player,
                            username,
                            1,
                            false
                        )

                    elseif lowerDisplay
                        == query then

                        consider(
                            player,
                            displayName,
                            2,
                            false
                        )

                    elseif string.sub(
                        lowerUsername,
                        1,
                        #query
                    ) == query then

                        consider(
                            player,
                            username,
                            3,
                            true
                        )

                    elseif displayName ~= ""
                        and string.sub(
                            lowerDisplay,
                            1,
                            #query
                        ) == query then

                        consider(
                            player,
                            displayName,
                            4,
                            true
                        )

                    elseif string.find(
                        lowerUsername,
                        query,
                        1,
                        true
                    ) then

                        consider(
                            player,
                            username,
                            5,
                            false
                        )

                    elseif displayName ~= ""
                        and string.find(
                            lowerDisplay,
                            query,
                            1,
                            true
                        ) then

                        consider(
                            player,
                            displayName,
                            6,
                            false
                        )
                    end
                end
            end

            table.sort(
                matches,
                function(a, b)
                    if a.Score ~= b.Score then
                        return a.Score
                            < b.Score
                    end

                    if #a.Text ~= #b.Text then
                        return #a.Text
                            < #b.Text
                    end

                    return string.lower(
                        a.Player.Name
                    )
                        < string.lower(
                            b.Player.Name
                        )
                end
            )

            local best =
                matches[1]

            if not best then
                return nil, nil, nil
            end

            return best.Player,
                best.Text,
                best.CanAutocomplete
        end

        local function resolveTargetPlayer(
            query
        )
            local search =
                query

            if search == nil then
                search =
                    state.Misc.TargetText
            end

            local player =
                findBestTargetMatch(
                    search
                )

            if player then
                state.Misc.TargetPlayer =
                    player
            end

            return player
        end

        local function getRolePlayer(
            wantedRole
        )
            for _, player in ipairs(
                Players:GetPlayers()
            ) do
                if player ~= LocalPlayer
                    and isAliveCombatTarget(
                        player
                    )
                    and getEffectiveRole(
                        player
                    ) == wantedRole then

                    return player
                end
            end

            return nil
        end

        local function getSheriffOrHero()
            return getLivingSheriffOrHero()
        end

        local function isFlingablePlayer(
            player
        )
            if not player
                or player == LocalPlayer
                or player.Parent ~= Players then

                return false
            end

            local character =
                player.Character

            local root =
                getCharacterRoot(
                    player
                )

            if not character
                or not root
                or not root:IsA(
                    "BasePart"
                ) then

                return false
            end

            local humanoid =
                character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            if humanoid
                and humanoid.Health <= 0 then

                return false
            end

            return true
        end

        local function getTargetHitboxPosition(
            player
        )
            if not isFlingablePlayer(
                player
            ) then

                return nil, nil
            end

            local root =
                getCharacterRoot(
                    player
                )

            -- HumanoidRootPart is already centered at the correct character
            -- height for both R6/R15. UpperTorso/Torso are fallback hitboxes.
            return root.Position,
                root
        end

        local function teleportToPlayer(
            player,
            title
        )
            if not isFlingablePlayer(
                player
            ) then

                notify(
                    title or "Teleport",
                    "No matching living player with a usable hitbox was found.",
                    true
                )

                return false
            end

            local targetRoot =
                getCharacterRoot(
                    player
                )

            local character =
                LocalPlayer.Character

            local localRoot =
                getCharacterRoot(
                    LocalPlayer
                )

            if not targetRoot
                or not character
                or not localRoot then

                return false
            end

            -- Preserve OUR current facing/orientation. Only position changes.
            local currentRotation =
                localRoot.CFrame.Rotation

            local destination =
                targetRoot.Position
                - targetRoot.CFrame.LookVector
                    * 3

            local ok =
                pcall(function()
                    character:PivotTo(
                        CFrame.new(
                            destination
                        )
                        * currentRotation
                    )
                end)

            if ok then
                notify(
                    title or "Teleport",
                    "Teleported to "
                    .. player.Name
                    .. " without changing your facing direction."
                )
            end

            return ok
        end

        local function stopOrbit()
            local connection =
                state.Misc.OrbitConnection

            if connection then
                pcall(function()
                    connection:Disconnect()
                end)
            end

            state.Misc.OrbitConnection =
                nil

            state.Misc.OrbitAngle =
                0
        end

        local function startOrbit()
            stopOrbit()

            if not state.Misc.OrbitEnabled then
                return
            end

            state.Misc.OrbitConnection =
                RunService.Heartbeat:Connect(
                    function(dt)
                        if not state.Alive
                            or not state.Misc.OrbitEnabled then

                            return
                        end

                        local target =
                            resolveTargetPlayer()

                        local targetRoot =
                            getCharacterRoot(
                                target
                            )

                        local character =
                            LocalPlayer.Character

                        if not targetRoot
                            or not character then

                            return
                        end

                        state.Misc.OrbitAngle +=
                            math.rad(
                                state.Misc.OrbitSpeed
                            )
                            * dt

                        local radius =
                            state.Misc.OrbitRadius

                        local center =
                            targetRoot.Position

                        local position =
                            center
                            + Vector3.new(
                                math.cos(
                                    state.Misc.OrbitAngle
                                )
                                    * radius,
                                1.5,
                                math.sin(
                                    state.Misc.OrbitAngle
                                )
                                    * radius
                            )

                        pcall(function()
                            character:PivotTo(
                                CFrame.lookAt(
                                    position,
                                    center
                                )
                            )
                        end)
                    end
                )
        end

        local function restoreCamera()
            camera =
                workspace.CurrentCamera

            local humanoid =
                getLocalHumanoid()

            if camera
                and humanoid then

                pcall(function()
                    camera.CameraSubject =
                        humanoid
                end)
            end
        end

        local function applySpectate()
            camera =
                workspace.CurrentCamera

            if not state.Misc.SpectateEnabled then
                restoreCamera()
                return
            end

            local target =
                resolveTargetPlayer()

            local humanoid =
                target
                and target.Character
                and target.Character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            if camera
                and humanoid then

                pcall(function()
                    camera.CameraSubject =
                        humanoid
                end)
            end
        end

        local function destroySpin()
            local angular =
                state.Misc.SpinAngularVelocity

            local attachment =
                state.Misc.SpinAttachment

            if angular then
                pcall(function()
                    angular:Destroy()
                end)
            end

            if attachment then
                pcall(function()
                    attachment:Destroy()
                end)
            end

            state.Misc.SpinAngularVelocity =
                nil

            state.Misc.SpinAttachment =
                nil
        end

        local function applySpin()
            destroySpin()

            if not state.Misc.SpinEnabled then
                return
            end

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            if not root then
                return
            end

            local attachment =
                Instance.new(
                    "Attachment"
                )

            attachment.Name =
                "Vitality_MM2_SpinAttachment"

            attachment.Parent =
                root

            local angular =
                Instance.new(
                    "AngularVelocity"
                )

            angular.Name =
                "Vitality_MM2_Spin"

            angular.Attachment0 =
                attachment

            angular.RelativeTo =
                Enum.ActuatorRelativeTo.World

            angular.MaxTorque =
                math.huge

            angular.AngularVelocity =
                Vector3.new(
                    0,
                    math.rad(
                        state.Misc.SpinSpeed
                    ),
                    0
                )

            angular.Parent =
                root

            state.Misc.SpinAttachment =
                attachment

            state.Misc.SpinAngularVelocity =
                angular
        end

        local function updateSpinSpeed()
            local angular =
                state.Misc.SpinAngularVelocity

            if angular
                and angular.Parent then

                angular.AngularVelocity =
                    Vector3.new(
                        0,
                        math.rad(
                            state.Misc.SpinSpeed
                        ),
                        0
                    )
            end
        end

        local function flingPlayer(
            target
        )
            if state.Misc.FlingBusy
                or not isFlingablePlayer(
                    target
                ) then

                return false
            end

            local character =
                LocalPlayer.Character

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            local targetPosition,
                targetRoot =
                    getTargetHitboxPosition(
                        target
                    )

            if not character
                or not root
                or not targetRoot
                or not targetPosition then

                return false
            end

            state.Misc.FlingBusy =
                true

            local origin =
                character:GetPivot()

            local humanoid =
                character:
                    FindFirstChildOfClass(
                        "Humanoid"
                    )

            local oldAutoRotate =
                humanoid
                and humanoid.AutoRotate

            if humanoid then
                humanoid.AutoRotate =
                    false

                humanoid.Sit =
                    false

                humanoid.Jump =
                    false
            end

            local strength =
                math.clamp(
                    tonumber(
                        state.Misc.FlingStrength
                    )
                    or 99999,
                    5000,
                    150000
                )

            local duration =
                math.clamp(
                    tonumber(
                        state.Misc.FlingDuration
                    )
                    or 0.90,
                    0.30,
                    3
                )

            -- ============================================================
            -- Infinite-Yield-inspired physics setup.
            --
            -- IY's effective fling makes every character BasePart physically
            -- heavy, enables noclip, installs BodyAngularVelocity with enormous
            -- Y torque/P, then pulses 99999 -> 0 repeatedly.
            --
            -- We preserve/restore every touched property because this is a
            -- short targeted fling rather than a persistent command.
            -- ============================================================

            local savedParts = {}

            for _, object in ipairs(
                character:GetDescendants()
            ) do
                if object:IsA(
                    "BasePart"
                ) then

                    savedParts[
                        object
                    ] = {
                        CustomPhysicalProperties =
                            object.CustomPhysicalProperties,
                        CanCollide =
                            object.CanCollide,
                        Massless =
                            object.Massless,
                    }

                    pcall(function()
                        object.CustomPhysicalProperties =
                            PhysicalProperties.new(
                                100,
                                0.3,
                                0.5
                            )

                        -- IY enables noclip before spinning. This prevents us
                        -- from snagging map geometry while overlapping/tracking
                        -- the target.
                        object.CanCollide =
                            false
                    end)
                end
            end

            -- IY sets direct character BaseParts massless and clears velocity.
            for _, object in ipairs(
                character:GetChildren()
            ) do
                if object:IsA(
                    "BasePart"
                ) then

                    pcall(function()
                        object.Massless =
                            true

                        object.AssemblyLinearVelocity =
                            Vector3.zero
                    end)
                end
            end

            local bambam =
                Instance.new(
                    "BodyAngularVelocity"
                )

            bambam.Name =
                "Vitality_MM2_IYFling"

            bambam.AngularVelocity =
                Vector3.new(
                    0,
                    strength,
                    0
                )

            bambam.MaxTorque =
                Vector3.new(
                    0,
                    math.huge,
                    0
                )

            bambam.P =
                math.huge

            bambam.Parent =
                root

            -- The exact center alone can occasionally produce very little
            -- separation impulse. Sweep across center/edges/corners while
            -- remaining within/at the target root footprint. Y never changes.
            local xRadius =
                math.max(
                    0.38,
                    math.min(
                        0.82,
                        targetRoot.Size.X
                            * 0.42
                    )
                )

            local zRadius =
                math.max(
                    0.28,
                    math.min(
                        0.68,
                        targetRoot.Size.Z
                            * 0.42
                    )
                )

            local contactOffsets = {
                Vector2.new(
                    0,
                    0
                ),
                Vector2.new(
                    xRadius,
                    0
                ),
                Vector2.new(
                    -xRadius,
                    0
                ),
                Vector2.new(
                    0,
                    zRadius
                ),
                Vector2.new(
                    0,
                    -zRadius
                ),
                Vector2.new(
                    xRadius,
                    zRadius
                ),
                Vector2.new(
                    -xRadius,
                    zRadius
                ),
                Vector2.new(
                    xRadius,
                    -zRadius
                ),
                Vector2.new(
                    -xRadius,
                    -zRadius
                ),
            }

            local index =
                1

            -- Blend replicated velocity with observed root-position movement.
            -- This lets us lead runners instead of always chasing their last
            -- replicated position.
            local lastObservedPosition =
                targetPosition

            local lastObservedAt =
                os.clock()

            local smoothedHorizontalVelocity =
                Vector3.zero

            local startedAt =
                os.clock()

            local deadline =
                startedAt
                + duration

            -- Initial exact overlap. Adding a translation to the existing
            -- pivot keeps our current orientation intact.
            pcall(function()
                local currentPivot =
                    character:GetPivot()

                character:PivotTo(
                    currentPivot
                    + (
                        targetPosition
                        - currentPivot.Position
                    )
                )
            end)

            repeat
                if not state.Alive
                    or not isFlingablePlayer(
                        target
                    ) then

                    break
                end

                targetPosition,
                    targetRoot =
                        getTargetHitboxPosition(
                            target
                        )

                if not targetPosition
                    or not targetRoot then

                    break
                end

                local heartbeatDt =
                    RunService.Heartbeat:
                        Wait()

                local now =
                    os.clock()

                local observedDt =
                    math.max(
                        now
                        - lastObservedAt,
                        1 / 240
                    )

                local observedVelocity =
                    (
                        targetPosition
                        - lastObservedPosition
                    )
                    / observedDt

                local assemblyVelocity =
                    targetRoot.AssemblyLinearVelocity

                if typeof(assemblyVelocity)
                    ~= "Vector3" then

                    assemblyVelocity =
                        Vector3.zero
                end

                -- Horizontal prediction only. Current target Y remains exact.
                observedVelocity =
                    Vector3.new(
                        observedVelocity.X,
                        0,
                        observedVelocity.Z
                    )

                assemblyVelocity =
                    Vector3.new(
                        assemblyVelocity.X,
                        0,
                        assemblyVelocity.Z
                    )

                local rawVelocity =
                    observedVelocity
                        * 0.55
                    + assemblyVelocity
                        * 0.45

                local velocityCap =
                    math.max(
                        20,
                        tonumber(
                            state.Misc.FlingPredictionVelocityCap
                        )
                        or 110
                    )

                local rawSpeed =
                    rawVelocity.Magnitude

                if rawSpeed > velocityCap
                    and rawSpeed > 0 then

                    rawVelocity =
                        rawVelocity.Unit
                        * velocityCap
                end

                local observedDisplacement =
                    (
                        targetPosition
                        - lastObservedPosition
                    ).Magnitude

                if observedDisplacement > 18 then
                    -- Teleport / replication correction: do not extrapolate it.
                    rawVelocity =
                        Vector3.zero

                    smoothedHorizontalVelocity =
                        Vector3.zero
                else
                    local alpha =
                        math.clamp(
                            (
                                tonumber(
                                    heartbeatDt
                                )
                                or 1 / 60
                            )
                            * 14,
                            0.12,
                            0.72
                        )

                    smoothedHorizontalVelocity =
                        smoothedHorizontalVelocity:Lerp(
                            rawVelocity,
                            alpha
                        )
                end

                lastObservedPosition =
                    targetPosition

                lastObservedAt =
                    now

                local predictedCenter =
                    targetPosition

                if state.Misc.FlingPredictionEnabled then
                    local horizontalSpeed =
                        smoothedHorizontalVelocity.Magnitude

                    -- Slow/stationary targets remain almost perfectly centered.
                    local movementScale =
                        math.clamp(
                            horizontalSpeed
                                / 16,
                            0,
                            1
                        )

                    local leadTime =
                        math.clamp(
                            tonumber(
                                state.Misc.FlingPredictionLead
                            )
                            or 0.09,
                            0,
                            0.22
                        )

                    local lead =
                        smoothedHorizontalVelocity
                        * leadTime
                        * movementScale

                    predictedCenter =
                        Vector3.new(
                            targetPosition.X
                                + lead.X,
                            targetPosition.Y,
                            targetPosition.Z
                                + lead.Z
                        )
                end

                local offset =
                    contactOffsets[
                        index
                    ]

                index += 1

                if index
                    > #contactOffsets then

                    index =
                        1
                end

                local right =
                    targetRoot.CFrame.RightVector

                local look =
                    targetRoot.CFrame.LookVector

                local contactPosition =
                    Vector3.new(
                        predictedCenter.X,
                        targetPosition.Y,
                        predictedCenter.Z
                    )
                    + Vector3.new(
                        right.X,
                        0,
                        right.Z
                    )
                        * offset.X
                    + Vector3.new(
                        look.X,
                        0,
                        look.Z
                    )
                        * offset.Y

                -- Absolutely lock vertical alignment to CURRENT target-root Y.
                -- Prediction only leads X/Z.
                contactPosition =
                    Vector3.new(
                        contactPosition.X,
                        targetPosition.Y,
                        contactPosition.Z
                    )

                pcall(function()
                    -- TRANSLATION ONLY. Do not write a replacement rotation
                    -- every frame; that would fight BodyAngularVelocity and
                    -- substantially weaken the fling.
                    local currentPivot =
                        character:GetPivot()

                    character:PivotTo(
                        currentPivot
                        + (
                            contactPosition
                            - currentPivot.Position
                        )
                    )
                end)

                -- Reproduce IY's 0.20 sec high-spin / 0.10 sec zero-spin pulse.
                local cycle =
                    (
                        os.clock()
                        - startedAt
                    ) % 0.30

                if cycle < 0.20 then
                    bambam.AngularVelocity =
                        Vector3.new(
                            0,
                            strength,
                            0
                        )
                else
                    bambam.AngularVelocity =
                        Vector3.zero
                end

                if humanoid
                    and humanoid.Parent then

                    humanoid.Sit =
                        false

                    humanoid.Jump =
                        false
                end
            until os.clock()
                >= deadline

            pcall(function()
                bambam:Destroy()
            end)

            -- Restore every physical property we changed.
            for object, saved in pairs(
                savedParts
            ) do
                if object
                    and object.Parent then

                    pcall(function()
                        object.CustomPhysicalProperties =
                            saved.CustomPhysicalProperties

                        object.CanCollide =
                            saved.CanCollide

                        object.Massless =
                            saved.Massless

                        object.AssemblyLinearVelocity =
                            Vector3.zero

                        object.AssemblyAngularVelocity =
                            Vector3.zero
                    end)
                end
            end

            if humanoid
                and humanoid.Parent then

                humanoid.AutoRotate =
                    oldAutoRotate

                humanoid.Sit =
                    false

                humanoid.Jump =
                    false
            end

            if state.Alive
                and LocalPlayer.Character
                    == character then

                if state.Misc.ReturnAfterFling then
                    pcall(function()
                        character:PivotTo(
                            origin
                        )
                    end)
                else
                    -- Stay where the fling ended, but preserve whichever
                    -- orientation Roblox currently has after spin decay.
                    local finalPivot =
                        character:GetPivot()

                    pcall(function()
                        character:PivotTo(
                            finalPivot
                        )
                    end)
                end
            end

            state.Misc.FlingBusy =
                false

            return true
        end

        local function flingMany(
            players
        )
            if state.Misc.FlingBusy then
                return
            end

            task.spawn(function()
                for _, player in ipairs(
                    players
                ) do
                    if not state.Alive then
                        break
                    end

                    if isFlingablePlayer(
                        player
                    ) then

                        flingPlayer(
                            player
                        )

                        task.wait(0.05)
                    end
                end
            end)
        end

        -- ====================================================
        -- COIN DETECTION
        -- Exact hierarchy observed:
        -- workspace.<Map>.CoinContainer.Coin_Server.CoinVisual.MainCoin
        -- ====================================================

        local function getCoinContainer()
            for _, child in ipairs(
                workspace:GetChildren()
            ) do
                local container =
                    child:FindFirstChild(
                        "CoinContainer"
                    )

                if container then
                    return container
                end
            end

            return workspace:
                FindFirstChild(
                    "CoinContainer",
                    true
                )
        end

        local function getCoinServer(
            object
        )
            if not object then
                return nil
            end

            if object.Name
                == "Coin_Server" then

                return object
            end

            return object:
                FindFirstAncestor(
                    "Coin_Server"
                )
        end

        local function getCoinVisual(
            coinServer
        )
            if not coinServer
                or not coinServer.Parent then

                return nil
            end

            return coinServer:
                FindFirstChild(
                    "CoinVisual"
                )
        end

        local function getCoinPart(
            coinServer
        )
            local visual =
                getCoinVisual(
                    coinServer
                )

            if not visual then
                return nil
            end

            -- Exact object observed in Explorer:
            -- Coin_Server > CoinVisual > MainCoin
            local mainCoin =
                visual:
                    FindFirstChild(
                        "MainCoin",
                        true
                    )

            if mainCoin
                and mainCoin:IsA(
                    "BasePart"
                ) then

                return mainCoin
            end

            -- Fallback for variants where the visible mesh has a different
            -- name but remains under CoinVisual.
            local mesh =
                visual:
                    FindFirstChildWhichIsA(
                        "MeshPart",
                        true
                    )

            if mesh then
                return mesh
            end

            local basePart =
                visual:
                    FindFirstChildWhichIsA(
                        "BasePart",
                        true
                    )

            return basePart
        end

        local function getCoinChamTarget(
            coinServer,
            part
        )
            local visual =
                getCoinVisual(
                    coinServer
                )

            -- Prefer the actual rendered mesh. In your observed hierarchy,
            -- MainCoin is the object we want highlighted rather than the
            -- entire Coin_Server model.
            if part
                and part:IsA(
                    "MeshPart"
                ) then

                return part
            end

            if visual then
                local mesh =
                    visual:
                        FindFirstChildWhichIsA(
                            "MeshPart",
                            true
                        )

                if mesh then
                    return mesh
                end
            end

            if part
                and part:IsA(
                    "BasePart"
                ) then

                return part
            end

            -- Highlight accepts a Model/BasePart adornee. If CoinVisual is a
            -- model, use it as the final visual-level fallback.
            if visual
                and (
                    visual:IsA(
                        "Model"
                    )
                    or visual:IsA(
                        "BasePart"
                    )
                ) then

                return visual
            end

            return nil
        end

        local function coinVisualsEnabled()
            return state.Misc.CoinESPEnabled
                or state.Misc.CoinChamsEnabled
                or state.Misc.CoinBoxEnabled
        end

        local function destroyNamedCoinArtifact(
            object,
            mode
        )
            if not object then
                return
            end

            local name =
                object.Name

            local isESP =
                name
                == "Vitality_MM2_CoinESP"

            local isChams =
                name
                == "Vitality_MM2_CoinHighlight"

            local isBox =
                name
                == "Vitality_MM2_CoinBox"

            local isVitalityArtifact =
                isESP
                or isChams
                or isBox

            local shouldDestroy =
                isVitalityArtifact
                and (
                    mode == "all"
                    or (
                        mode == "esp"
                        and isESP
                    )
                    or (
                        mode == "chams"
                        and isChams
                    )
                    or (
                        mode == "box"
                        and isBox
                    )
                )

            if shouldDestroy then
                pcall(function()
                    object:Destroy()
                end)
            end
        end

        local function purgeCoinArtifacts(
            mode
        )
            mode =
                mode
                or "all"

            -- First remove every tracked object.
            for _, entry in pairs(
                state.Misc.CoinESPObjects
            ) do
                if type(entry)
                    == "table" then

                    if mode == "all"
                        or mode == "chams" then

                        if entry.Highlight then
                            pcall(function()
                                entry.Highlight:
                                    Destroy()
                            end)
                        end

                        entry.Highlight =
                            nil
                    end

                    if mode == "all"
                        or mode == "box" then

                        if entry.Box then
                            pcall(function()
                                entry.Box:
                                    Destroy()
                            end)
                        end

                        entry.Box =
                            nil
                    end

                    if mode == "all"
                        or mode == "esp" then

                        if entry.Billboard then
                            pcall(function()
                                entry.Billboard:
                                    Destroy()
                            end)
                        end

                        entry.Billboard =
                            nil

                        entry.Label =
                            nil
                    end
                end
            end

            -- Also sweep ONLY CoinContainer, never all Workspace. This removes
            -- stale/orphaned Vitality visuals from previous toggles/rebuilds.
            local container =
                getCoinContainer()

            if container then
                for _, descendant in ipairs(
                    container:GetDescendants()
                ) do
                    destroyNamedCoinArtifact(
                        descendant,
                        mode
                    )
                end
            end

            if mode == "all" then
                state.Misc.CoinESPObjects =
                    setmetatable(
                        {},
                        {__mode = "k"}
                    )
            end
        end

        local function destroyCoinESP(
            coinServer
        )
            local entry =
                state.Misc.CoinESPObjects[
                    coinServer
                ]

            if not entry then
                return
            end

            for _, key in ipairs({
                "Highlight",
                "Box",
                "Billboard",
            }) do
                local object =
                    entry[key]

                if object then
                    pcall(function()
                        object:Destroy()
                    end)
                end
            end

            state.Misc.CoinESPObjects[
                coinServer
            ] = nil
        end

        local function destroyAllCoinESP()
            purgeCoinArtifacts(
                "all"
            )
        end

        local function ensureCoinESP(
            coinServer,
            part
        )
            if not coinVisualsEnabled()
                or not coinServer
                or not part
                or not part.Parent then

                destroyCoinESP(
                    coinServer
                )

                return nil
            end

            local entry =
                state.Misc.CoinESPObjects[
                    coinServer
                ]

            if not entry
                or entry.Part ~= part then

                destroyCoinESP(
                    coinServer
                )

                entry = {
                    Part = part,
                    Highlight = nil,
                    HighlightTarget = nil,
                    Box = nil,
                    Billboard = nil,
                    Label = nil,
                }

                state.Misc.CoinESPObjects[
                    coinServer
                ] = entry
            end

            -- CHAMS: prefer the actual MainCoin mesh; CoinVisual is only a
            -- fallback if no usable mesh/basepart is present.
            local chamTarget =
                getCoinChamTarget(
                    coinServer,
                    part
                )

            if state.Misc.CoinChamsEnabled
                and chamTarget then

                local needsHighlight =
                    not entry.Highlight
                    or not entry.Highlight.Parent
                    or entry.HighlightTarget
                        ~= chamTarget

                if needsHighlight then
                    if entry.Highlight then
                        pcall(function()
                            entry.Highlight:
                                Destroy()
                        end)
                    end

                    local highlight =
                        Instance.new(
                            "Highlight"
                        )

                    highlight.Name =
                        "Vitality_MM2_CoinHighlight"

                    highlight.Adornee =
                        chamTarget

                    highlight.DepthMode =
                        Enum.HighlightDepthMode.AlwaysOnTop

                    highlight.FillColor =
                        Color3.fromRGB(
                            255,
                            215,
                            70
                        )

                    highlight.OutlineColor =
                        Color3.fromRGB(
                            255,
                            245,
                            180
                        )

                    highlight.FillTransparency =
                        0.45

                    highlight.OutlineTransparency =
                        0.04

                    -- Parent it to Coin_Server so removal follows the coin.
                    highlight.Parent =
                        coinServer

                    entry.Highlight =
                        highlight

                    entry.HighlightTarget =
                        chamTarget
                end
            else
                if entry.Highlight then
                    pcall(function()
                        entry.Highlight:
                            Destroy()
                    end)
                end

                entry.Highlight =
                    nil

                entry.HighlightTarget =
                    nil
            end

            -- BOX ESP stays on the exact physical MainCoin/mesh.
            if state.Misc.CoinBoxEnabled then
                if not entry.Box
                    or not entry.Box.Parent
                    or entry.Box.Adornee
                        ~= part then

                    if entry.Box then
                        pcall(function()
                            entry.Box:Destroy()
                        end)
                    end

                    local box =
                        Instance.new(
                            "BoxHandleAdornment"
                        )

                    box.Name =
                        "Vitality_MM2_CoinBox"

                    box.Adornee =
                        part

                    box.AlwaysOnTop =
                        true

                    box.ZIndex =
                        5

                    box.Size =
                        part.Size
                        + Vector3.new(
                            0.35,
                            0.35,
                            0.35
                        )

                    box.Color3 =
                        Color3.fromRGB(
                            255,
                            225,
                            90
                        )

                    box.Transparency =
                        0.78

                    box.Parent =
                        part

                    entry.Box =
                        box
                end
            else
                if entry.Box then
                    pcall(function()
                        entry.Box:
                            Destroy()
                    end)
                end

                entry.Box =
                    nil
            end

            -- TEXT / DISTANCE ESP
            if state.Misc.CoinESPEnabled then
                if not entry.Billboard
                    or not entry.Billboard.Parent
                    or entry.Billboard.Adornee
                        ~= part then

                    if entry.Billboard then
                        pcall(function()
                            entry.Billboard:
                                Destroy()
                        end)
                    end

                    local billboard =
                        Instance.new(
                            "BillboardGui"
                        )

                    billboard.Name =
                        "Vitality_MM2_CoinESP"

                    billboard.Adornee =
                        part

                    billboard.AlwaysOnTop =
                        true

                    billboard.LightInfluence =
                        0

                    billboard.Size =
                        UDim2.fromOffset(
                            145,
                            25
                        )

                    billboard.StudsOffsetWorldSpace =
                        Vector3.new(
                            0,
                            1.7,
                            0
                        )

                    billboard.Parent =
                        part

                    local label =
                        Instance.new(
                            "TextLabel"
                        )

                    label.BackgroundTransparency =
                        1

                    label.Size =
                        UDim2.fromScale(
                            1,
                            1
                        )

                    label.Font =
                        Enum.Font.GothamSemibold

                    label.TextSize =
                        13

                    label.TextStrokeTransparency =
                        0.22

                    label.TextColor3 =
                        Color3.fromRGB(
                            255,
                            225,
                            90
                        )

                    label.Text =
                        "Coin"

                    label.Parent =
                        billboard

                    entry.Billboard =
                        billboard

                    entry.Label =
                        label
                end
            else
                if entry.Billboard then
                    pcall(function()
                        entry.Billboard:
                            Destroy()
                    end)
                end

                entry.Billboard =
                    nil

                entry.Label =
                    nil
            end

            return entry
        end

        local function registerCoin(
            object
        )
            local coinServer =
                getCoinServer(
                    object
                )

            if not coinServer
                or not coinServer:
                    IsDescendantOf(
                        workspace
                    ) then

                return nil
            end

            local part =
                getCoinPart(
                    coinServer
                )

            if not part then
                return nil
            end

            state.Misc.Coins[
                coinServer
            ] = part

            if coinVisualsEnabled() then
                ensureCoinESP(
                    coinServer,
                    part
                )
            end

            return coinServer,
                part
        end

        local function scheduleCoinRegistration(
            object
        )
            if not object then
                return
            end

            local coinServer =
                getCoinServer(
                    object
                )

            if not coinServer
                and object.Name
                    == "Coin_Server" then

                coinServer =
                    object
            end

            if not coinServer then
                return
            end

            if state.Misc.CoinRegistrationPending[
                coinServer
            ] then

                return
            end

            state.Misc.CoinRegistrationPending[
                coinServer
            ] = true

            task.spawn(function()
                local deadline =
                    os.clock()
                    + 0.75

                repeat
                    if not state.Alive
                        or not coinServer.Parent
                        or not coinServer:
                            IsDescendantOf(
                                workspace
                            ) then

                        break
                    end

                    local registered =
                        registerCoin(
                            coinServer
                        )

                    if registered then
                        break
                    end

                    -- Coin_Server often replicates before CoinVisual/MainCoin.
                    task.wait(0.03)
                until os.clock()
                    >= deadline

                state.Misc.CoinRegistrationPending[
                    coinServer
                ] = nil
            end)
        end

        local function scanCoins()
            local container =
                getCoinContainer()

            if not container then
                return
            end

            -- Coin_Server is observed as a direct child of CoinContainer, but
            -- use descendants too so a map variant cannot hide new coins from
            -- registration. This scan is scoped to CoinContainer only.
            for _, object in ipairs(
                container:GetDescendants()
            ) do
                if object.Name
                    == "Coin_Server" then

                    scheduleCoinRegistration(
                        object
                    )
                end
            end

            for _, child in ipairs(
                container:GetChildren()
            ) do
                if child.Name
                    == "Coin_Server" then

                    scheduleCoinRegistration(
                        child
                    )
                end
            end
        end

        local function reconcileCoinVisuals()
            if not state.Misc.CoinESPEnabled then
                purgeCoinArtifacts(
                    "esp"
                )
            end

            if not state.Misc.CoinChamsEnabled then
                purgeCoinArtifacts(
                    "chams"
                )
            end

            if not state.Misc.CoinBoxEnabled then
                purgeCoinArtifacts(
                    "box"
                )
            end

            if not coinVisualsEnabled() then
                destroyAllCoinESP()
                return
            end

            scanCoins()

            -- Reconcile everything already known immediately.
            for coinServer, part in pairs(
                state.Misc.Coins
            ) do
                if coinServer
                    and coinServer.Parent
                    and part
                    and part.Parent then

                    ensureCoinESP(
                        coinServer,
                        part
                    )
                end
            end
        end

        local function pruneCoins()
            local stale = {}

            for coinServer, part in pairs(
                state.Misc.Coins
            ) do
                if not coinServer
                    or not coinServer.Parent
                    or not part
                    or not part.Parent
                    or not coinServer:
                        IsDescendantOf(
                            workspace
                        ) then

                    table.insert(
                        stale,
                        coinServer
                    )
                end
            end

            for _, coinServer in ipairs(
                stale
            ) do
                state.Misc.Coins[
                    coinServer
                ] = nil

                state.Misc.CoinFailedUntil[
                    coinServer
                ] = nil

                destroyCoinESP(
                    coinServer
                )
            end
        end

        local function getCoinList()
            pruneCoins()

            local list = {}

            local now =
                os.clock()

            for coinServer, part in pairs(
                state.Misc.Coins
            ) do
                local failedUntil =
                    state.Misc.CoinFailedUntil[
                        coinServer
                    ]

                if part
                    and part.Parent
                    and (
                        not failedUntil
                        or now >= failedUntil
                    ) then

                    table.insert(
                        list,
                        {
                            Server = coinServer,
                            Part = part,
                        }
                    )
                end
            end

            return list
        end

        local function chooseCoin()
            local list =
                getCoinList()

            if #list == 0 then
                scanCoins()

                list =
                    getCoinList()
            end

            if #list == 0 then
                return nil,
                    nil
            end

            if not state.Misc.NearestCoinFirst then
                return list[1].Server,
                    list[1].Part
            end

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            if not root then
                return list[1].Server,
                    list[1].Part
            end

            local best = nil
            local bestDistance =
                math.huge

            for _, item in ipairs(
                list
            ) do
                local distance =
                    (
                        root.Position
                        - item.Part.Position
                    ).Magnitude

                if distance
                    < bestDistance then

                    best =
                        item

                    bestDistance =
                        distance
                end
            end

            return best
                and best.Server
                or nil,
                best
                and best.Part
                or nil
        end

        local function updateCoinESP()
            if not coinVisualsEnabled() then
                return
            end

            pruneCoins()

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            for coinServer, part in pairs(
                state.Misc.Coins
            ) do
                local entry =
                    ensureCoinESP(
                        coinServer,
                        part
                    )

                if entry
                    and entry.Label then

                    local nextText =
                        "Coin"

                    if state.Misc.CoinDistanceEnabled
                        and root then

                        local distance =
                            (
                                root.Position
                                - part.Position
                            ).Magnitude

                        nextText =
                            string.format(
                                "Coin [%d studs]",
                                math.floor(
                                    distance
                                    + 0.5
                                )
                            )
                    end

                    if entry.Label.Text
                        ~= nextText then

                        entry.Label.Text =
                            nextText
                    end
                end
            end
        end

        local CoinStatsToggle = nil

        local function getCoinStatsParent()
            if type(gethui)
                == "function" then

                local ok, result =
                    pcall(
                        gethui
                    )

                if ok
                    and result then

                    return result
                end
            end

            local ok, coreGui =
                pcall(
                    game.GetService,
                    game,
                    "CoreGui"
                )

            if ok
                and coreGui then

                return coreGui
            end

            return LocalPlayer:
                FindFirstChildOfClass(
                    "PlayerGui"
                )
        end

        local function destroyCoinStatsPopout()
            local gui =
                state.Misc.CoinStatsGui

            if gui then
                pcall(function()
                    gui:Destroy()
                end)
            end

            state.Misc.CoinStatsGui =
                nil

            state.Misc.CoinStatsFrame =
                nil

            state.Misc.CoinStatsLabels =
                {}
        end

        local function createCoinStatsPopout()
            local existing =
                state.Misc.CoinStatsGui

            if existing
                and existing.Parent then

                return existing
            end

            local parent =
                getCoinStatsParent()

            if not parent then
                return nil
            end

            local gui =
                Instance.new(
                    "ScreenGui"
                )

            gui.Name =
                "Vitality_MM2_CoinStats"

            gui.ResetOnSpawn =
                false

            gui.IgnoreGuiInset =
                true

            gui.DisplayOrder =
                999997

            gui.ZIndexBehavior =
                Enum.ZIndexBehavior.Sibling

            local frame =
                Instance.new(
                    "Frame"
                )

            frame.Name =
                "Window"

            frame.AnchorPoint =
                Vector2.new(
                    1,
                    0
                )

            frame.Position =
                UDim2.new(
                    1,
                    -24,
                    0,
                    76
                )

            frame.Size =
                UDim2.fromOffset(
                    250,
                    176
                )

            frame.BackgroundColor3 =
                Color3.fromRGB(
                    19,
                    19,
                    25
                )

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
                    0,
                    8
                )

            corner.Parent =
                frame

            local stroke =
                Instance.new(
                    "UIStroke"
                )

            stroke.Color =
                Color3.fromRGB(
                    55,
                    55,
                    67
                )

            stroke.Thickness =
                1

            stroke.Transparency =
                0.08

            stroke.Parent =
                frame

            local header =
                Instance.new(
                    "Frame"
                )

            header.Name =
                "Header"

            header.BackgroundTransparency =
                1

            header.Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    38
                )

            header.Active =
                true

            header.Parent =
                frame

            local title =
                Instance.new(
                    "TextLabel"
                )

            title.BackgroundTransparency =
                1

            title.Position =
                UDim2.fromOffset(
                    14,
                    0
                )

            title.Size =
                UDim2.new(
                    1,
                    -54,
                    1,
                    0
                )

            title.Font =
                Enum.Font.GothamSemibold

            title.Text =
                "MM2 Coin Stats"

            title.TextColor3 =
                Color3.fromRGB(
                    238,
                    238,
                    244
                )

            title.TextSize =
                13

            title.TextXAlignment =
                Enum.TextXAlignment.Left

            title.Parent =
                header

            local close =
                Instance.new(
                    "TextButton"
                )

            close.Name =
                "Close"

            close.AnchorPoint =
                Vector2.new(
                    1,
                    0.5
                )

            close.Position =
                UDim2.new(
                    1,
                    -8,
                    0.5,
                    0
                )

            close.Size =
                UDim2.fromOffset(
                    28,
                    28
                )

            close.BackgroundColor3 =
                Color3.fromRGB(
                    31,
                    31,
                    40
                )

            close.BorderSizePixel =
                0

            close.Font =
                Enum.Font.GothamBold

            close.Text =
                "×"

            close.TextColor3 =
                Color3.fromRGB(
                    205,
                    205,
                    215
                )

            close.TextSize =
                15

            close.Parent =
                header

            local closeCorner =
                Instance.new(
                    "UICorner"
                )

            closeCorner.CornerRadius =
                UDim.new(
                    0,
                    6
                )

            closeCorner.Parent =
                close

            local divider =
                Instance.new(
                    "Frame"
                )

            divider.BackgroundColor3 =
                Color3.fromRGB(
                    48,
                    48,
                    59
                )

            divider.BorderSizePixel =
                0

            divider.Position =
                UDim2.fromOffset(
                    12,
                    38
                )

            divider.Size =
                UDim2.new(
                    1,
                    -24,
                    0,
                    1
                )

            divider.Parent =
                frame

            local labels = {}

            local function makeRow(
                key,
                name,
                y
            )
                local nameLabel =
                    Instance.new(
                        "TextLabel"
                    )

                nameLabel.BackgroundTransparency =
                    1

                nameLabel.Position =
                    UDim2.fromOffset(
                        14,
                        y
                    )

                nameLabel.Size =
                    UDim2.fromOffset(
                        120,
                        24
                    )

                nameLabel.Font =
                    Enum.Font.Gotham

                nameLabel.Text =
                    name

                nameLabel.TextColor3 =
                    Color3.fromRGB(
                        168,
                        168,
                        181
                    )

                nameLabel.TextSize =
                    11

                nameLabel.TextXAlignment =
                    Enum.TextXAlignment.Left

                nameLabel.Parent =
                    frame

                local valueLabel =
                    Instance.new(
                        "TextLabel"
                    )

                valueLabel.BackgroundTransparency =
                    1

                valueLabel.AnchorPoint =
                    Vector2.new(
                        1,
                        0
                    )

                valueLabel.Position =
                    UDim2.new(
                        1,
                        -14,
                        0,
                        y
                    )

                valueLabel.Size =
                    UDim2.fromOffset(
                        102,
                        24
                    )

                valueLabel.Font =
                    Enum.Font.GothamSemibold

                valueLabel.Text =
                    "--"

                valueLabel.TextColor3 =
                    Color3.fromRGB(
                        238,
                        238,
                        244
                    )

                valueLabel.TextSize =
                    12

                valueLabel.TextXAlignment =
                    Enum.TextXAlignment.Right

                valueLabel.Parent =
                    frame

                labels[key] =
                    valueLabel
            end

            makeRow(
                "Round",
                "Round Coins",
                48
            )

            makeRow(
                "Balance",
                "Coin Balance",
                78
            )

            makeRow(
                "Session",
                "Session Coins",
                108
            )

            makeRow(
                "Rate",
                "Coins / Minute",
                138
            )

            local dragging =
                false

            local dragStart =
                nil

            local startPosition =
                nil

            trackConnection(
                header.InputBegan:Connect(
                    function(input)
                        if input.UserInputType
                                == Enum.UserInputType.MouseButton1
                            or input.UserInputType
                                == Enum.UserInputType.Touch then

                            dragging =
                                true

                            dragStart =
                                input.Position

                            startPosition =
                                frame.Position
                        end
                    end
                )
            )

            trackConnection(
                UserInputService.InputChanged:
                    Connect(
                        function(input)
                            if not dragging
                                or not frame.Parent then

                                return
                            end

                            if input.UserInputType
                                    ~= Enum.UserInputType.MouseMovement
                                and input.UserInputType
                                    ~= Enum.UserInputType.Touch then

                                return
                            end

                            local delta =
                                input.Position
                                - dragStart

                            frame.Position =
                                UDim2.new(
                                    startPosition.X.Scale,
                                    startPosition.X.Offset
                                        + delta.X,
                                    startPosition.Y.Scale,
                                    startPosition.Y.Offset
                                        + delta.Y
                                )
                        end
                    )
            )

            trackConnection(
                UserInputService.InputEnded:
                    Connect(
                        function(input)
                            if input.UserInputType
                                    == Enum.UserInputType.MouseButton1
                                or input.UserInputType
                                    == Enum.UserInputType.Touch then

                                dragging =
                                    false
                            end
                        end
                    )
            )

            trackConnection(
                close.MouseButton1Click:
                    Connect(
                        function()
                            state.Misc.CoinStatsVisible =
                                false

                            frame.Visible =
                                false

                            if CoinStatsToggle then
                                CoinStatsToggle:Set(
                                    false,
                                    false
                                )
                            end
                        end
                    )
            )

            gui.Parent =
                parent

            state.Misc.CoinStatsGui =
                gui

            state.Misc.CoinStatsFrame =
                frame

            state.Misc.CoinStatsLabels =
                labels

            return gui
        end

        local function applyCoinStatsPopout()
            local gui =
                createCoinStatsPopout()

            local frame =
                state.Misc.CoinStatsFrame

            if gui
                and frame then

                frame.Visible =
                    state.Misc.CoinStatsVisible
            end
        end

        local function updateCoinStats()
            local labels =
                state.Misc.CoinStatsLabels

            if type(labels)
                ~= "table" then

                return
            end

            local roundText =
                tostring(
                    math.max(
                        0,
                        math.floor(
                            state.Misc.RoundCollected
                            + 0.5
                        )
                    )
                )
                .. " / "
                .. tostring(
                    math.max(
                        0,
                        math.floor(
                            state.Misc.RoundLimit
                            + 0.5
                        )
                    )
                )

            local balanceText =
                state.Misc.CoinBalance
                and string.format(
                    "%d",
                    math.floor(
                        state.Misc.CoinBalance
                        + 0.5
                    )
                )
                or "Waiting..."

            local sessionText =
                tostring(
                    math.floor(
                        state.Misc.SessionCollected
                        + 0.5
                    )
                )

            local elapsed =
                math.max(
                    1,
                    os.clock()
                    - state.Misc.SessionStartedAt
                )

            local perMinute =
                state.Misc.SessionCollected
                / elapsed
                * 60

            local rateText =
                string.format(
                    "%.1f/min",
                    perMinute
                )

            local values = {
                Round = roundText,
                Balance = balanceText,
                Session = sessionText,
                Rate = rateText,
            }

            for key, value in pairs(
                values
            ) do
                local label =
                    labels[key]

                if label
                    and label.Parent
                    and label.Text ~= value then

                    label.Text =
                        value
                end
            end
        end

        local function isLocalDead()
            local humanoid =
                getLocalHumanoid()

            return not humanoid
                or humanoid.Health <= 0
        end

        local function murdererTooClose()
            if not state.Misc.PauseNearMurderer then
                return false
            end

            local murderer =
                getMurdererPlayer()

            local murdererRoot =
                getCharacterRoot(
                    murderer
                )

            local localRoot =
                getCharacterRoot(
                    LocalPlayer
                )

            if not murdererRoot
                or not localRoot then

                return false
            end

            return (
                murdererRoot.Position
                - localRoot.Position
            ).Magnitude
                <= state.Misc.MurdererSafetyRadius
        end

        local function shouldPauseCoinFarm()
            if state.Misc.PauseWhileDead
                and isLocalDead() then

                return true
            end

            if murdererTooClose() then
                return true
            end

            return false
        end

        local function touchCoin(
            part
        )
            if not part
                or not part.Parent then

                return false
            end

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            if not root then
                return false
            end

            if type(firetouchinterest)
                    == "function" then

                pcall(
                    firetouchinterest,
                    root,
                    part,
                    0
                )

                task.wait(0.025)

                pcall(
                    firetouchinterest,
                    root,
                    part,
                    1
                )
            end

            return true
        end

        local function makePath(
            startPosition,
            destination
        )
            local path =
                PathfindingService:
                    CreatePath({
                        AgentRadius = 2,
                        AgentHeight = 5,
                        AgentCanJump = true,
                        AgentCanClimb = true,
                        WaypointSpacing = 6,
                    })

            local ok =
                pcall(function()
                    path:ComputeAsync(
                        startPosition,
                        destination
                    )
                end)

            if not ok
                or path.Status
                    ~= Enum.PathStatus.Success then

                return nil
            end

            return path:
                GetWaypoints()
        end

        local function waitForWalkPoint(
            position,
            timeout
        )
            local deadline =
                os.clock()
                + timeout

            repeat
                if not state.Alive
                    or not state.Misc.AutoGrabEnabled
                    or shouldPauseCoinFarm() then

                    return false
                end

                local root =
                    getCharacterRoot(
                        LocalPlayer
                    )

                if not root then
                    return false
                end

                if (
                    root.Position
                    - position
                ).Magnitude <= 2.8 then

                    return true
                end

                task.wait(0.04)
            until os.clock()
                >= deadline

            return false
        end

        local function pathfindWalkTo(
            part
        )
            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            local humanoid =
                getLocalHumanoid()

            if not root
                or not humanoid
                or not part
                or not part.Parent then

                return false
            end

            local speed =
                math.clamp(
                    state.Misc.AutoGrabSpeed,
                    8,
                    80
                )

            humanoid.WalkSpeed =
                speed

            local waypoints =
                makePath(
                    root.Position,
                    part.Position
                )

            if not waypoints then
                waypoints = {
                    {
                        Position =
                            part.Position,
                        Action =
                            Enum.PathWaypointAction.Walk,
                    },
                }
            end

            for _, waypoint in ipairs(
                waypoints
            ) do
                if not state.Misc.AutoGrabEnabled
                    or not part.Parent
                    or shouldPauseCoinFarm() then

                    return false
                end

                if waypoint.Action
                    == Enum.PathWaypointAction.Jump then

                    humanoid.Jump =
                        true
                end

                humanoid:MoveTo(
                    waypoint.Position
                )

                local rootNow =
                    getCharacterRoot(
                        LocalPlayer
                    )

                local distance =
                    rootNow
                    and (
                        rootNow.Position
                        - waypoint.Position
                    ).Magnitude
                    or 0

                local timeout =
                    math.clamp(
                        distance
                        / math.max(
                            speed,
                            1
                        )
                        * 2.1
                        + 0.35,
                        0.5,
                        4
                    )

                if not waitForWalkPoint(
                    waypoint.Position,
                    timeout
                ) then

                    return false
                end
            end

            return true
        end

        local function pathfindTweenTo(
            part
        )
            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            if not root
                or not part
                or not part.Parent then

                return false
            end

            local speed =
                math.clamp(
                    state.Misc.AutoGrabSpeed,
                    8,
                    120
                )

            local waypoints =
                makePath(
                    root.Position,
                    part.Position
                )

            if not waypoints then
                waypoints = {
                    {
                        Position =
                            part.Position,
                        Action =
                            Enum.PathWaypointAction.Walk,
                    },
                }
            end

            for _, waypoint in ipairs(
                waypoints
            ) do
                if not state.Misc.AutoGrabEnabled
                    or not part.Parent
                    or shouldPauseCoinFarm() then

                    return false
                end

                root =
                    getCharacterRoot(
                        LocalPlayer
                    )

                if not root then
                    return false
                end

                local distance =
                    (
                        root.Position
                        - waypoint.Position
                    ).Magnitude

                local duration =
                    math.max(
                        0.025,
                        distance
                        / math.max(
                            speed,
                            1
                        )
                    )

                local tween =
                    TweenService:Create(
                        root,
                        TweenInfo.new(
                            duration,
                            Enum.EasingStyle.Linear,
                            Enum.EasingDirection.Out
                        ),
                        {
                            CFrame =
                                CFrame.new(
                                    waypoint.Position
                                )
                        }
                    )

                tween:Play()

                local deadline =
                    os.clock()
                    + duration
                    + 0.35

                repeat
                    if not state.Alive
                        or not state.Misc.AutoGrabEnabled
                        or not part.Parent
                        or shouldPauseCoinFarm() then

                        pcall(function()
                            tween:Cancel()
                        end)

                        return false
                    end

                    task.wait(0.025)
                until tween.PlaybackState
                        ~= Enum.PlaybackState.Playing
                    or os.clock()
                        >= deadline
            end

            return true
        end

        local function teleportToCoin(
            part
        )
            local character =
                LocalPlayer.Character

            if not character
                or not part
                or not part.Parent then

                return false
            end

            return pcall(function()
                character:PivotTo(
                    CFrame.new(
                        part.Position
                        + Vector3.new(
                            0,
                            1.5,
                            0
                        )
                    )
                )
            end)
        end

        local function moveToCoin(
            part
        )
            local method =
                state.Misc.AutoGrabMethod

            local moved = false

            if method == "WalkTo" then
                moved =
                    pathfindWalkTo(
                        part
                    )

            elseif method == "TweenTo" then
                moved =
                    pathfindTweenTo(
                        part
                    )

            else
                moved =
                    teleportToCoin(
                        part
                    )
            end

            if moved
                and part
                and part.Parent then

                local root =
                    getCharacterRoot(
                        LocalPlayer
                    )

                if root
                    and (
                        root.Position
                        - part.Position
                    ).Magnitude > 4.5
                    and method ~= "TeleportTo" then

                    -- Final short correction only after pathfinding succeeded.
                    pcall(function()
                        LocalPlayer.Character:
                            PivotTo(
                                CFrame.new(
                                    part.Position
                                    + Vector3.new(
                                        0,
                                        1.1,
                                        0
                                    )
                                )
                            )
                    end)
                end

                touchCoin(
                    part
                )

                task.wait(0.06)
            end

            return moved
        end

        local function returnAutoGrabOrigin()
            local origin =
                state.Misc.AutoGrabStartCFrame

            local character =
                LocalPlayer.Character

            if not state.Misc.ReturnWhenDone
                or state.Misc.ReturnedForRound
                or typeof(origin)
                    ~= "CFrame"
                or not character then

                return
            end

            state.Misc.ReturnedForRound =
                true

            pcall(function()
                character:PivotTo(
                    origin
                )
            end)
        end

        local function runCoinFarm()
            if state.Misc.AutoGrabWorkerRunning then
                return
            end

            state.Misc.AutoGrabWorkerRunning =
                true

            state.Misc.AutoGrabGeneration +=
                1

            local generation =
                state.Misc.AutoGrabGeneration

            task.spawn(function()
                while state.Alive
                    and state.Misc.AutoGrabEnabled
                    and generation
                        == state.Misc.AutoGrabGeneration do

                    if shouldPauseCoinFarm() then
                        task.wait(0.15)
                        continue
                    end

                    local root =
                        getCharacterRoot(
                            LocalPlayer
                        )

                    if root
                        and typeof(
                            state.Misc.AutoGrabStartCFrame
                        ) ~= "CFrame" then

                        state.Misc.AutoGrabStartCFrame =
                            root.CFrame
                    end

                    local coinServer,
                        part =
                            chooseCoin()

                    if not coinServer
                        or not part then

                        if state.Misc.RoundLimit > 0
                            and state.Misc.RoundCollected
                                >= state.Misc.RoundLimit then

                            returnAutoGrabOrigin()
                        end

                        task.wait(0.12)
                        continue
                    end

                    local moved =
                        moveToCoin(
                            part
                        )

                    if not moved
                        and coinServer then

                        state.Misc.CoinFailedUntil[
                            coinServer
                        ] =
                            os.clock()
                            + 0.8
                    end

                    task.wait(0.035)
                end

                state.Misc.AutoGrabWorkerRunning =
                    false
            end)
        end

        local function startAutoGrab()
            if not state.Misc.AutoGrabEnabled then
                return
            end

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            if root then
                state.Misc.AutoGrabStartCFrame =
                    root.CFrame
            end

            state.Misc.ReturnedForRound =
                false

            scanCoins()
            runCoinFarm()
        end

        local function stopAutoGrab()
            state.Misc.AutoGrabGeneration +=
                1

            state.Misc.AutoGrabWorkerRunning =
                false

            local humanoid =
                getLocalHumanoid()

            if humanoid then
                humanoid.WalkSpeed =
                    16
            end
        end

        local function connectIncomingEvent(
            eventObject,
            callback
        )
            if not eventObject
                or type(callback)
                    ~= "function" then

                return nil
            end

            if eventObject:IsA(
                "RemoteEvent"
            ) then

                return trackConnection(
                    eventObject.OnClientEvent:
                        Connect(
                            callback
                        )
                )
            end

            if eventObject:IsA(
                "BindableEvent"
            ) then

                return trackConnection(
                    eventObject.Event:
                        Connect(
                            callback
                        )
                )
            end

            return nil
        end

        local function locatePath(
            root,
            names
        )
            local current =
                root

            for _, name in ipairs(
                names
            ) do
                current =
                    current
                    and current:
                        FindFirstChild(
                            name
                        )

                if not current then
                    return nil
                end
            end

            return current
        end

        local function bindCoinRemotes()
            local coinCollected =
                locatePath(
                    ReplicatedStorage,
                    {
                        "Remotes",
                        "Gameplay",
                        "CoinCollected",
                    }
                )

            local coinsStarted =
                locatePath(
                    ReplicatedStorage,
                    {
                        "Remotes",
                        "Gameplay",
                        "CoinsStarted",
                    }
                )

            local inventoryChanged =
                locatePath(
                    ReplicatedStorage,
                    {
                        "Remotes",
                        "Inventory",
                        "InventoryDataChanged",
                    }
                )

            local changeInventoryItem =
                locatePath(
                    ReplicatedStorage,
                    {
                        "Remotes",
                        "Inventory",
                        "ChangeInventoryItem",
                    }
                )

            local updateDataClient =
                ReplicatedStorage:
                    FindFirstChild(
                        "UpdateDataClient"
                    )

            connectIncomingEvent(
                coinCollected,
                function(
                    coinType,
                    collected,
                    limit,
                    metadata
                )
                    if tostring(
                        coinType
                    ) ~= "Coin" then

                        return
                    end

                    local newCollected =
                        tonumber(
                            collected
                        )

                    local newLimit =
                        tonumber(
                            limit
                        )

                    if newCollected then
                        state.Misc.RoundCollected =
                            newCollected
                    end

                    if newLimit then
                        state.Misc.RoundLimit =
                            newLimit
                    end

                    local value =
                        type(metadata)
                            == "table"
                        and tonumber(
                            metadata.Value
                        )
                        or nil

                    state.Misc.SessionCollected +=
                        value
                        or 1

                    updateCoinStats()

                    if state.Misc.RoundLimit > 0
                        and state.Misc.RoundCollected
                            >= state.Misc.RoundLimit then

                        returnAutoGrabOrigin()
                    end
                end
            )

            connectIncomingEvent(
                coinsStarted,
                function(payload)
                    local coin =
                        type(payload)
                            == "table"
                        and payload.Coin
                        or nil

                    if type(coin)
                        == "table" then

                        state.Misc.RoundCollected =
                            tonumber(
                                coin.CollectedAmount
                            )
                            or 0

                        state.Misc.RoundLimit =
                            tonumber(
                                coin.CollectionLimit
                            )
                            or 40
                    else
                        state.Misc.RoundCollected =
                            0
                    end

                    state.Misc.ReturnedForRound =
                        false

                    if state.Misc.AutoGrabEnabled then
                        local root =
                            getCharacterRoot(
                                LocalPlayer
                            )

                        if root then
                            state.Misc.AutoGrabStartCFrame =
                                root.CFrame
                        end

                        runCoinFarm()
                    end

                    updateCoinStats()
                end
            )

            local function inventoryHandler(
                category,
                item,
                value
            )
                if tostring(category)
                        == "Materials"
                    and tostring(item)
                        == "Coins" then

                    local numeric =
                        tonumber(
                            value
                        )

                    if numeric then
                        state.Misc.CoinBalance =
                            numeric

                        updateCoinStats()
                    end
                end
            end

            connectIncomingEvent(
                inventoryChanged,
                inventoryHandler
            )

            connectIncomingEvent(
                changeInventoryItem,
                inventoryHandler
            )

            connectIncomingEvent(
                updateDataClient,
                function(...)
                    local args = {...}
                    local data = nil

                    for _, value in ipairs(
                        args
                    ) do
                        if type(value)
                                == "table"
                            and type(
                                value.Materials
                            ) == "table" then

                            data = value
                            break
                        end
                    end

                    local balance =
                        data
                        and data.Materials
                        and data.Materials.Owned
                        and tonumber(
                            data.Materials.Owned.Coins
                        )
                        or nil

                    if balance then
                        state.Misc.CoinBalance =
                            balance

                        updateCoinStats()
                    end
                end
            )
        end

        local function tickMisc()
            if not state.Alive then
                return
            end

            pruneCoins()

            if coinVisualsEnabled() then
                updateCoinESP()
            end

            updateCoinStats()

            -- Anti-fling: save calm positions and snap back if velocity spikes.
            if state.Misc.AntiFlingEnabled
                and not state.Misc.FlingBusy then

                local root =
                    getCharacterRoot(
                        LocalPlayer
                    )

                local character =
                    LocalPlayer.Character

                if root
                    and character then

                    local linear =
                        root.AssemblyLinearVelocity.Magnitude

                    local angular =
                        root.AssemblyAngularVelocity.Magnitude

                    if linear > 125
                        or angular > 90 then

                        pcall(function()
                            root.AssemblyLinearVelocity =
                                Vector3.zero

                            root.AssemblyAngularVelocity =
                                Vector3.zero

                            if typeof(
                                state.Misc.LastSafeCFrame
                            ) == "CFrame" then

                                character:PivotTo(
                                    state.Misc.LastSafeCFrame
                                )
                            end
                        end)
                    elseif linear < 45
                        and angular < 25 then

                        state.Misc.LastSafeCFrame =
                            root.CFrame
                    end
                end
            end

            if state.Misc.FollowEnabled
                and not state.Misc.OrbitEnabled then

                local target =
                    resolveTargetPlayer()

                local targetRoot =
                    getCharacterRoot(
                        target
                    )

                local humanoid =
                    getLocalHumanoid()

                if targetRoot
                    and humanoid then

                    humanoid:MoveTo(
                        targetRoot.Position
                    )
                end
            end

            if state.Misc.CopyMovementEnabled
                and not state.Misc.OrbitEnabled then

                local target =
                    resolveTargetPlayer()

                local targetHumanoid =
                    target
                    and target.Character
                    and target.Character:
                        FindFirstChildOfClass(
                            "Humanoid"
                        )

                local localHumanoid =
                    getLocalHumanoid()

                if targetHumanoid
                    and localHumanoid then

                    localHumanoid:Move(
                        targetHumanoid.MoveDirection,
                        false
                    )

                    if targetHumanoid.Jump then
                        localHumanoid.Jump =
                            true
                    end
                end
            end

            if state.Misc.SpectateEnabled then
                applySpectate()
            end

            if state.Misc.SpinEnabled
                and (
                    not state.Misc.SpinAngularVelocity
                    or not state.Misc.SpinAngularVelocity.Parent
                ) then

                applySpin()
            end
        end

        state.Misc.OnWorkspaceDescendantAdded =
            function(object)
                if not object then
                    return
                end

                if object.Name
                        == "Coin_Server"
                    or object.Name
                        == "CoinVisual"
                    or object.Name
                        == "MainCoin"
                    or (
                        object:IsA(
                            "MeshPart"
                        )
                        and object:
                            FindFirstAncestor(
                                "Coin_Server"
                            )
                    ) then

                    scheduleCoinRegistration(
                        object
                    )

                elseif object.Name
                    == "CoinContainer" then

                    task.defer(function()
                        if state.Alive then
                            scanCoins()
                        end
                    end)
                end
            end

        state.Misc.Tick =
            tickMisc

        -- ====================================================
        -- MISC UI
        -- ====================================================

        local FunSection =
            MiscTab:CreateSection({
                Name = "Target Tools",
                Description = "One username/display-name target for fling, teleport, spectate, orbit, follow, and copy movement.",
                Side = "Left",
            })

        local TargetMatchStatus =
            FunSection:CreateStatus({
                Name = "Selected Target",
                Info = "Username/display-name autocomplete result.",
                CurrentValue = "None",
            })

        local TargetInput

        TargetInput =
            FunSection:CreateInput({
                Name = "Target",
                Info = "Type any part of a username/display name. The best match becomes the shared target for every Target Tool; Enter flings immediately and clears the box.",
                PlaceholderText = "gr → graciepoo2",
                CurrentValue = "",
                CharacterLimit = 32,
                OnEnter = true,
                RemoveTextAfterFocusLost = true,
                Callback = function(value)
                    local typed =
                        tostring(
                            value
                            or ""
                        )

                    state.Misc.TargetText =
                        typed

                    local target =
                        resolveTargetPlayer(
                            typed
                        )

                    if not target then
                        notify(
                            "Fling Target",
                            "No username/display-name match was found.",
                            true
                        )
                    else
                        state.Misc.TargetPlayer =
                            target

                        TargetMatchStatus:Set(
                            target.DisplayName
                            .. " (@"
                            .. target.Name
                            .. ")"
                        )

                        task.spawn(function()
                            flingPlayer(
                                target
                            )
                        end)
                    end

                    -- Keep the resolved Player selected, but clear the text box
                    -- immediately so another name can be typed right away.
                    state.Misc.TargetText =
                        ""

                    task.defer(function()
                        if TargetInput then
                            TargetInput:Set(
                                "",
                                false
                            )
                        end
                    end)
                end,
            })

        local targetTextBox =
            TargetInput
            and TargetInput.Instance
            and TargetInput.Instance:
                FindFirstChildWhichIsA(
                    "TextBox",
                    true
                )

        if targetTextBox then
            local suppressAutocomplete =
                false

            trackConnection(
                targetTextBox:
                    GetPropertyChangedSignal(
                        "Text"
                    ):Connect(function()
                        if suppressAutocomplete then
                            return
                        end

                        local typed =
                            tostring(
                                targetTextBox.Text
                                or ""
                            )

                        state.Misc.TargetText =
                            typed

                        if typed == "" then
                            local selected =
                                state.Misc.TargetPlayer

                            if selected
                                and selected.Parent
                                    == Players then

                                TargetMatchStatus:Set(
                                    selected.DisplayName
                                    .. " (@"
                                    .. selected.Name
                                    .. ")"
                                )
                            else
                                TargetMatchStatus:Set(
                                    "None"
                                )
                            end

                            return
                        end

                        local target,
                            completion,
                            canAutocomplete =
                                findBestTargetMatch(
                                    typed
                                )

                        if not target then
                            TargetMatchStatus:Set(
                                "No match"
                            )

                            return
                        end

                        state.Misc.TargetPlayer =
                            target

                        TargetMatchStatus:Set(
                            target.DisplayName
                            .. " (@"
                            .. target.Name
                            .. ")"
                        )

                        -- True inline autocomplete for unique/best prefixes.
                        -- The remaining suffix is selected, so continuing to
                        -- type naturally replaces the suggestion.
                        local lowerTyped =
                            string.lower(
                                typed
                            )

                        local lowerCompletion =
                            string.lower(
                                tostring(
                                    completion
                                    or ""
                                )
                            )

                        if canAutocomplete
                            and #typed >= 2
                            and #lowerCompletion
                                > #lowerTyped
                            and string.sub(
                                lowerCompletion,
                                1,
                                #lowerTyped
                            ) == lowerTyped
                            and targetTextBox:
                                IsFocused() then

                            suppressAutocomplete =
                                true

                            targetTextBox.Text =
                                completion

                            pcall(function()
                                targetTextBox.SelectionStart =
                                    #typed
                                    + 1

                                targetTextBox.CursorPosition =
                                    #completion
                                    + 1
                            end)

                            suppressAutocomplete =
                                false
                        end
                    end)
            )
        end

        FunSection:CreateButton({
            Name = "Fling Selected",
            Info = "IY-inspired targeted fling with predictive X/Z follow. It leads moving players while keeping your Y aligned to their current hitbox height.",
            Interact = "Fling",
            Callback = function()
                local target =
                    resolveTargetPlayer()

                if not isFlingablePlayer(
                    target
                ) then

                    notify(
                        "Fling Selected",
                        "No usable target is selected.",
                        true
                    )

                    return
                end

                task.spawn(function()
                    flingPlayer(
                        target
                    )
                end)
            end,
        })

        FunSection:CreateButton({
            Name = "Teleport Selected",
            Info = "Teleport near the selected target without changing your facing orientation.",
            Interact = "Teleport",
            Callback = function()
                teleportToPlayer(
                    resolveTargetPlayer(),
                    "Teleport Target"
                )
            end,
        })

        FunSection:CreateToggle({
            Name = "Spectate Selected",
            Info = "Spectate the same selected username/display-name target.",
            CurrentValue = false,
            Flag = "MM2_SpectateTarget",
            Callback = function(value)
                state.Misc.SpectateEnabled =
                    value == true

                applySpectate()
            end,
        })

        FunSection:CreateToggle({
            Name = "Orbit Selected",
            Info = "Orbit the same selected target smoothly.",
            CurrentValue = false,
            Flag = "MM2_OrbitTarget",
            Callback = function(value)
                state.Misc.OrbitEnabled =
                    value == true

                if state.Misc.OrbitEnabled then
                    startOrbit()
                else
                    stopOrbit()
                end
            end,
        })

        FunSection:CreateToggle({
            Name = "Follow Selected",
            Info = "Continuously MoveTo the same selected target.",
            CurrentValue = false,
            Flag = "MM2_FollowTarget",
            Callback = function(value)
                state.Misc.FollowEnabled =
                    value == true
            end,
        })

        FunSection:CreateToggle({
            Name = "Copy Selected Movement",
            Info = "Copy the selected target's movement direction and jumps.",
            CurrentValue = false,
            Flag = "MM2_CopyMovement",
            Callback = function(value)
                state.Misc.CopyMovementEnabled =
                    value == true
            end,
        })

        FunSection:CreateSlider({
            Name = "Fling Strength",
            Info = "IY-inspired spin strength. Uses BodyAngularVelocity, heavy physical properties, noclip-style overlap, and 0.20s/0.10s spin pulsing.",
            Range = {5000, 150000},
            Increment = 5000,
            CurrentValue = 99999,
            Suffix = "",
            Flag = "MM2_FlingStrength",
            Callback = function(value)
                state.Misc.FlingStrength =
                    tonumber(value)
                    or 99999
            end,
        })

        FunSection:CreateSlider({
            Name = "Fling Duration",
            Range = {0.30, 2.5},
            Increment = 0.05,
            CurrentValue = 0.90,
            Suffix = "s",
            Flag = "MM2_FlingDuration",
            Callback = function(value)
                state.Misc.FlingDuration =
                    tonumber(value)
                    or 0.90
            end,
        })

        FunSection:CreateToggle({
            Name = "Fling Prediction",
            Info = "Lead moving targets using smoothed horizontal velocity while keeping your Y aligned to their current hitbox height.",
            CurrentValue = true,
            Flag = "MM2_FlingPrediction",
            Callback = function(value)
                state.Misc.FlingPredictionEnabled =
                    value == true
            end,
        })

        FunSection:CreateSlider({
            Name = "Prediction Lead",
            Info = "How far ahead of a moving target the fling contact follows. Slow/stationary targets automatically use little to no lead.",
            Range = {0, 0.22},
            Increment = 0.01,
            CurrentValue = 0.09,
            Suffix = "s",
            Flag = "MM2_FlingPredictionLead",
            Callback = function(value)
                state.Misc.FlingPredictionLead =
                    tonumber(value)
                    or 0.09
            end,
        })

        FunSection:CreateToggle({
            Name = "Return After Fling",
            Info = "Return to your original position after each fling.",
            CurrentValue = true,
            Flag = "MM2_ReturnAfterFling",
            Callback = function(value)
                state.Misc.ReturnAfterFling =
                    value == true
            end,
        })

        FunSection:CreateButton({
            Name = "Fling Sheriff / Hero",
            Interact = "Fling",
            Callback = function()
                local target =
                    getSheriffOrHero()

                if not target then
                    notify(
                        "Fling Sheriff",
                        "No living Sheriff/Hero was found.",
                        true
                    )

                    return
                end

                task.spawn(function()
                    flingPlayer(
                        target
                    )
                end)
            end,
        })

        FunSection:CreateButton({
            Name = "Fling Murderer",
            Interact = "Fling",
            Callback = function()
                local target =
                    getMurdererPlayer()

                if not target then
                    notify(
                        "Fling Murderer",
                        "No living Murderer was found.",
                        true
                    )

                    return
                end

                task.spawn(function()
                    flingPlayer(
                        target
                    )
                end)
            end,
        })

        FunSection:CreateButton({
            Name = "Fling All",
            Interact = "Fling",
            Callback = function()
                local targets = {}

                for _, player in ipairs(
                    Players:GetPlayers()
                ) do
                    if isFlingablePlayer(
                        player
                    ) then

                        table.insert(
                            targets,
                            player
                        )
                    end
                end

                flingMany(
                    targets
                )
            end,
        })

        local PlayerToolsSection =
            MiscTab:CreateSection({
                Name = "Role / Physics",
                Description = "Role shortcuts plus local physics/protection tools.",
                Side = "Left",
            })

        PlayerToolsSection:CreateButton({
            Name = "Teleport to Sheriff / Hero",
            Interact = "Teleport",
            Callback = function()
                teleportToPlayer(
                    getSheriffOrHero(),
                    "Teleport Sheriff"
                )
            end,
        })

        PlayerToolsSection:CreateButton({
            Name = "Teleport to Murderer",
            Interact = "Teleport",
            Callback = function()
                teleportToPlayer(
                    getMurdererPlayer(),
                    "Teleport Murderer"
                )
            end,
        })

        PlayerToolsSection:CreateButton({
            Name = "Teleport to Hero",
            Interact = "Teleport",
            Callback = function()
                teleportToPlayer(
                    getRolePlayer(
                        "Hero"
                    ),
                    "Teleport Hero"
                )
            end,
        })

        PlayerToolsSection:CreateToggle({
            Name = "Anti-Fling",
            Info = "Zero extreme local velocities and return to the last calm position.",
            CurrentValue = false,
            Flag = "MM2_AntiFling",
            Callback = function(value)
                state.Misc.AntiFlingEnabled =
                    value == true

                local root =
                    getCharacterRoot(
                        LocalPlayer
                    )

                state.Misc.LastSafeCFrame =
                    root
                    and root.CFrame
                    or nil
            end,
        })

        PlayerToolsSection:CreateToggle({
            Name = "Spin",
            CurrentValue = false,
            Flag = "MM2_Spin",
            Callback = function(value)
                state.Misc.SpinEnabled =
                    value == true

                applySpin()
            end,
        })

        PlayerToolsSection:CreateSlider({
            Name = "Spin Speed",
            Range = {45, 1440},
            Increment = 45,
            CurrentValue = 360,
            Suffix = "°/s",
            Flag = "MM2_SpinSpeed",
            Callback = function(value)
                state.Misc.SpinSpeed =
                    tonumber(value)
                    or 360

                updateSpinSpeed()
            end,
        })

        local CoinsSection =
            MiscTab:CreateSection({
                Name = "Coins / Farming",
                Description = "Physical Coin_Server farming with pathfinding.",
                Side = "Right",
            })

        CoinsSection:CreateToggle({
            Name = "Auto Grab Coins",
            Info = "Farm workspace.<Map>.CoinContainer.Coin_Server.CoinVisual.MainCoin.",
            CurrentValue = false,
            Flag = "MM2_AutoGrabCoins",
            Callback = function(value)
                state.Misc.AutoGrabEnabled =
                    value == true

                if state.Misc.AutoGrabEnabled then
                    startAutoGrab()
                else
                    stopAutoGrab()
                end
            end,
        })

        CoinsSection:CreateDropdown({
            Name = "Method",
            Info = "WalkTo and TweenTo both pathfind around the map.",
            Options = {
                "WalkTo",
                "TweenTo",
                "TeleportTo",
            },
            CurrentOption = "WalkTo",
            Flag = "MM2_CoinMethod",
            Callback = function(value)
                state.Misc.AutoGrabMethod =
                    tostring(
                        value
                        or "WalkTo"
                    )
            end,
        })

        CoinsSection:CreateSlider({
            Name = "Speed",
            Info = "WalkSpeed for WalkTo; studs/sec for TweenTo.",
            Range = {8, 80},
            Increment = 1,
            CurrentValue = 28,
            Suffix = "",
            Flag = "MM2_CoinSpeed",
            Callback = function(value)
                state.Misc.AutoGrabSpeed =
                    tonumber(value)
                    or 28
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Nearest Coin First",
            CurrentValue = true,
            Flag = "MM2_NearestCoin",
            Callback = function(value)
                state.Misc.NearestCoinFirst =
                    value == true
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Pause While Dead",
            CurrentValue = true,
            Flag = "MM2_CoinPauseDead",
            Callback = function(value)
                state.Misc.PauseWhileDead =
                    value == true
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Pause Near Murderer",
            Info = "Pause farming whenever the detected Murderer enters the safety radius.",
            CurrentValue = true,
            Flag = "MM2_CoinPauseMurderer",
            Callback = function(value)
                state.Misc.PauseNearMurderer =
                    value == true
            end,
        })

        CoinsSection:CreateSlider({
            Name = "Murderer Safety Radius",
            Range = {10, 150},
            Increment = 5,
            CurrentValue = 55,
            Suffix = " studs",
            Flag = "MM2_CoinSafetyRadius",
            Callback = function(value)
                state.Misc.MurdererSafetyRadius =
                    tonumber(value)
                    or 55
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Return When Round Coins Finish",
            Info = "Return to the position where Auto Grab started when the round counter reaches its natural limit.",
            CurrentValue = true,
            Flag = "MM2_CoinReturnDone",
            Callback = function(value)
                state.Misc.ReturnWhenDone =
                    value == true
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Coin ESP",
            Info = "Event-driven floating Coin label/distance. Toggling off forcibly removes all existing labels; new physical coins are added automatically.",
            CurrentValue = false,
            Flag = "MM2_CoinESP",
            Callback = function(value)
                state.Misc.CoinESPEnabled =
                    value == true

                reconcileCoinVisuals()
                updateCoinESP()
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Coin Chams",
            Info = "Highlight the actual MainCoin mesh through walls when possible; fall back to CoinVisual only when needed.",
            CurrentValue = false,
            Flag = "MM2_CoinChams",
            Callback = function(value)
                state.Misc.CoinChamsEnabled =
                    value == true

                reconcileCoinVisuals()
                updateCoinESP()
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Coin Box ESP",
            Info = "Draw an always-on-top 3D box around the exact physical MainCoin mesh/part.",
            CurrentValue = false,
            Flag = "MM2_CoinBoxESP",
            Callback = function(value)
                state.Misc.CoinBoxEnabled =
                    value == true

                reconcileCoinVisuals()
                updateCoinESP()
            end,
        })

        CoinsSection:CreateToggle({
            Name = "Coin Distance ESP",
            Info = "Append live distance in studs to each Coin ESP label.",
            CurrentValue = true,
            Flag = "MM2_CoinDistanceESP",
            Callback = function(value)
                state.Misc.CoinDistanceEnabled =
                    value == true

                if state.Misc.CoinESPEnabled then
                    updateCoinESP()
                end
            end,
        })

        local CoinStatsSection =
            MiscTab:CreateSection({
                Name = "Coin Stats",
                Description = "Toggle a draggable live coin-stat pop-out.",
                Side = "Right",
            })

        CoinStatsToggle =
            CoinStatsSection:CreateToggle({
                Name = "Coin Stats Popout",
                Info = "Show or hide a draggable stats window. The × button also closes it.",
                CurrentValue = false,
                Flag = "MM2_CoinStatsPopout",
                Callback = function(value)
                    state.Misc.CoinStatsVisible =
                        value == true

                    applyCoinStatsPopout()
                    updateCoinStats()
                end,
            })

        -- Bind/rematerialize the optional coin subsystem defensively.
        -- A map-specific replication quirk should never cause the entire MM2
        -- interface to be reported as a load failure after it already built.
        xpcall(
            function()
                bindCoinRemotes()
                scanCoins()
                reconcileCoinVisuals()
                updateCoinStats()
            end,
            function(errorMessage)
                warn(
                    "[VitalityHub][MM2][Coins] Non-fatal initialization error: "
                    .. tostring(
                        errorMessage
                    )
                )

                return errorMessage
            end
        )

        state.Misc.Cleanup =
            function()
                state.Misc.AutoGrabEnabled =
                    false

                state.Misc.AutoGrabGeneration +=
                    1

                stopOrbit()
                destroySpin()
                destroyAllCoinESP()

                state.Misc.CoinRegistrationPending =
                    setmetatable(
                        {},
                        {__mode = "k"}
                    )

                destroyCoinStatsPopout()
                restoreCamera()

                state.Misc.SpectateEnabled =
                    false

                state.Misc.FollowEnabled =
                    false

                state.Misc.CopyMovementEnabled =
                    false

                state.Misc.TargetText =
                    ""

                state.Misc.TargetPlayer =
                    nil

                state.Misc.Tick =
                    nil

                state.Misc.OnWorkspaceDescendantAdded =
                    nil

                local humanoid =
                    getLocalHumanoid()

                if humanoid then
                    humanoid.WalkSpeed =
                        16
                end
            end
    end, function(errorMessage)
        warn(
            "[VitalityHub][MM2][Misc] Non-fatal subsystem error: "
            .. tostring(
                errorMessage
            )
        )

        return errorMessage
    end)

    local RoleESPSection =
        RolesTab:CreateSection({
            Name = "Role ESP",
            Description = "Color players by the live MM2 role table.",
            Side = "Left",
        })

    local MasterToggle =
        RoleESPSection:CreateToggle({
            Name = "Role ESP",
            Info = "Master switch for role-based player ESP.",
            CurrentValue = true,
            Flag = "MM2_RoleESP",
            Callback = function(value)
                roleESPEnabled =
                    value == true

                refreshAllESP()
            end,
        })

    local ChamsToggle =
        RoleESPSection:CreateToggle({
            Name = "Role Chams",
            Info = "Highlight tracked roles through walls.",
            CurrentValue = true,
            Flag = "MM2_RoleChams",
            Callback = function(value)
                chamsEnabled =
                    value == true

                refreshAllESP()
            end,
        })

    local LabelsToggle =
        RoleESPSection:CreateToggle({
            Name = "Role Labels",
            Info = "Show player name and detected role above the character.",
            CurrentValue = true,
            Flag = "MM2_RoleLabels",
            Callback = function(value)
                labelsEnabled =
                    value == true

                refreshAllESP()
            end,
        })

    local PlayerDistanceToggle =
        RoleESPSection:CreateToggle({
            Name = "Player Distance",
            Info = "Show a separate spaced distance line beneath the player's name/role.",
            CurrentValue = true,
            Flag = "MM2_PlayerDistance",
            Callback = function(value)
                playerDistanceEnabled =
                    value == true

                refreshAllESP()
                updatePlayerDistanceLabels()
            end,
        })

    local FiltersSection =
        RolesTab:CreateSection({
            Name = "Role Filters",
            Description = "Choose which MM2 roles are revealed.",
            Side = "Right",
        })

    local MurdererToggle =
        FiltersSection:CreateToggle({
            Name = "Show Murderer",
            Info = "Display the player whose role is Murderer.",
            CurrentValue = true,
            Flag = "MM2_ShowMurderer",
            Callback = function(value)
                showMurderer =
                    value == true

                refreshAllESP()
            end,
        })

    local SheriffToggle =
        FiltersSection:CreateToggle({
            Name = "Show Sheriff / Hero",
            Info = "Display the current Sheriff or Hero.",
            CurrentValue = true,
            Flag = "MM2_ShowSheriff",
            Callback = function(value)
                showSheriff =
                    value == true

                refreshAllESP()
            end,
        })

    local InnocentToggle =
        FiltersSection:CreateToggle({
            Name = "Show Innocents",
            Info = "Display players whose role is Innocent.",
            CurrentValue = true,
            Flag = "MM2_ShowInnocents",
            Callback = function(value)
                showInnocents =
                    value == true

                refreshAllESP()
            end,
        })

    local DeadToggle =
        FiltersSection:CreateToggle({
            Name = "Show Dead Players",
            Info = "Keep dead/killed players visible in gray.",
            CurrentValue = false,
            Flag = "MM2_ShowDead",
            Callback = function(value)
                showDead =
                    value == true

                refreshAllESP()
            end,
        })

    local ColorsSection =
        RolesTab:CreateSection({
            Name = "Role Colors",
            Description = "Customize each role's ESP color.",
            Side = "Left",
        })

    ColorsSection:CreateColorPicker({
        Name = "Murderer Color",
        Color = roleColors.Murderer,
        Flag = "MM2_MurdererColor",
        Callback = function(color)
            roleColors.Murderer = color
            refreshAllESP()
        end,
    })

    ColorsSection:CreateColorPicker({
        Name = "Sheriff Color",
        Color = roleColors.Sheriff,
        Flag = "MM2_SheriffColor",
        Callback = function(color)
            roleColors.Sheriff = color
            refreshAllESP()
        end,
    })

    ColorsSection:CreateColorPicker({
        Name = "Hero Color",
        Color = roleColors.Hero,
        Flag = "MM2_HeroColor",
        Callback = function(color)
            roleColors.Hero = color
            refreshAllESP()
        end,
    })

    ColorsSection:CreateColorPicker({
        Name = "Innocent Color",
        Color = roleColors.Innocent,
        Flag = "MM2_InnocentColor",
        Callback = function(color)
            roleColors.Innocent = color
            refreshAllESP()
        end,
    })

    local RoundSection =
        RolesTab:CreateSection({
            Name = "Round Information",
            Description = "Live role information received from PlayerDataChanged.",
            Side = "Right",
        })

    local MurdererInfo =
        RoundSection:CreateParagraph({
            Title = "Murderer",
            Content = "Waiting for role data...",
        })

    local SheriffInfo =
        RoundSection:CreateParagraph({
            Title = "Sheriff / Hero",
            Content = "Waiting for role data...",
        })

    local RoundInfo =
        RoundSection:CreateParagraph({
            Title = "Round",
            Content = "No PlayerDataChanged snapshot received yet.",
        })

    updateRoundInfo = function()
        local murderers = {}
        local sheriffs = {}
        local heroes = {}
        local innocentAlive = 0
        local deadCount = 0
        local recordCount = 0
        local toolDetected = 0

        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            local record =
                getRoleRecord(
                    player
                )

            if type(record) == "table" then
                recordCount += 1

                if record.RoleSource == "Tool" then
                    toolDetected += 1
                end

                local role =
                    normalizeRole(
                        record.Role
                    )

                local dead =
                    record.Dead == true
                    or record.Killed == true

                if dead then
                    deadCount += 1

                elseif role == "Murderer" then
                    table.insert(
                        murderers,
                        player.Name
                    )

                elseif role == "Sheriff" then
                    table.insert(
                        sheriffs,
                        player.Name
                    )

                elseif role == "Hero" then
                    table.insert(
                        heroes,
                        player.Name
                    )

                elseif role == "Innocent" then
                    innocentAlive += 1
                end
            end
        end

        table.sort(murderers)
        table.sort(sheriffs)
        table.sort(heroes)

        MurdererInfo:Set({
            Content =
                #murderers > 0
                and table.concat(
                    murderers,
                    ", "
                )
                or "None detected",
        })

        local sheriffText = {}

        if #sheriffs > 0 then
            table.insert(
                sheriffText,
                "Sheriff: "
                    .. table.concat(
                        sheriffs,
                        ", "
                    )
            )
        end

        if #heroes > 0 then
            table.insert(
                sheriffText,
                "Hero: "
                    .. table.concat(
                        heroes,
                        ", "
                    )
            )
        end

        SheriffInfo:Set({
            Content =
                #sheriffText > 0
                and table.concat(
                    sheriffText,
                    "  |  "
                )
                or "None detected",
        })

        local receivedText =
            state.LastPayloadAt
            and "Server role snapshot received"
            or "No server role snapshot yet"

        RoundInfo:Set({
            Content =
                receivedText
                .. " • "
                .. tostring(recordCount)
                .. " effective roles • "
                .. tostring(toolDetected)
                .. " tool-derived • "
                .. tostring(innocentAlive)
                .. " living innocents • "
                .. tostring(deadCount)
                .. " dead",
        })
    end

    local function copyRoleRecord(name, record)
        if type(record) ~= "table" then
            return nil
        end

        if record.Role == nil
            and tonumber(record.UserId) == nil then

            return nil
        end

        local copy = {}

        for key, value in pairs(record) do
            copy[key] = value
        end

        copy.Name =
            tostring(
                name
                or copy.Name
                or ""
            )

        return copy
    end

    local function refreshChangedPlayers(
        changedUserIds,
        changedNames
    )
        for _, player in ipairs(
            Players:GetPlayers()
        ) do
            if player ~= LocalPlayer
                and (
                    changedUserIds[
                        player.UserId
                    ]
                    or changedNames[
                        player.Name
                    ]
                ) then

                applyPlayerESP(
                    player
                )
            end
        end
    end

    local function ingestRolePayload(...)
        local first, second = ...

        local changedUserIds = {}
        local changedNames = {}
        local roleStateChanged = false
        local accepted = false

        if type(first) == "table" then
            local oldByUserId =
                state.RoleByUserId

            local newByUserId = {}
            local newByName = {}

            for name, record in pairs(first) do
                local copy =
                    copyRoleRecord(
                        name,
                        record
                    )

                if copy then
                    accepted = true

                    local userId =
                        tonumber(
                            copy.UserId
                        )

                    if copy.Name ~= "" then
                        newByName[
                            copy.Name
                        ] = copy
                    end

                    if userId then
                        newByUserId[
                            userId
                        ] = copy
                    end
                end
            end

            -- Only role/death transitions matter to ESP/gun state. Coin, XP,
            -- cosmetic, and other noisy changes do not trigger full redraws.
            for userId, newRecord in pairs(
                newByUserId
            ) do
                local oldRecord =
                    oldByUserId[
                        userId
                    ]

                if roleStateSignature(
                    oldRecord
                ) ~= roleStateSignature(
                    newRecord
                ) then

                    roleStateChanged = true

                    changedUserIds[
                        userId
                    ] = true

                    if newRecord.Name then
                        changedNames[
                            tostring(
                                newRecord.Name
                            )
                        ] = true
                    end

                    processRoleTransition(
                        newRecord.Name,
                        oldRecord,
                        newRecord
                    )
                end
            end

            for userId, oldRecord in pairs(
                oldByUserId
            ) do
                if not newByUserId[
                    userId
                ] then

                    roleStateChanged = true

                    changedUserIds[
                        userId
                    ] = true

                    if oldRecord.Name then
                        changedNames[
                            tostring(
                                oldRecord.Name
                            )
                        ] = true
                    end
                end
            end

            state.RoleByUserId =
                newByUserId

            state.RoleByName =
                newByName

        elseif type(first) == "string"
            and type(second) == "table" then

            local copy =
                copyRoleRecord(
                    first,
                    second
                )

            if copy then
                accepted = true

                local userId =
                    tonumber(
                        copy.UserId
                    )

                local oldRecord =
                    (userId
                        and state.RoleByUserId[
                            userId
                        ])
                    or state.RoleByName[
                        first
                    ]

                if roleStateSignature(
                    oldRecord
                ) ~= roleStateSignature(
                    copy
                ) then

                    roleStateChanged = true

                    if userId then
                        changedUserIds[
                            userId
                        ] = true
                    end

                    changedNames[
                        tostring(first)
                    ] = true

                    processRoleTransition(
                        first,
                        oldRecord,
                        copy
                    )
                end

                state.RoleByName[
                    tostring(first)
                ] = copy

                if userId then
                    state.RoleByUserId[
                        userId
                    ] = copy
                end
            end
        end

        if not accepted then
            return
        end

        state.LastPayloadAt =
            os.clock()

        if roleStateChanged then
            refreshChangedPlayers(
                changedUserIds,
                changedNames
            )

            updateRoundInfo()

            for _, player in ipairs(
                Players:GetPlayers()
            ) do
                if player ~= LocalPlayer
                    and (
                        changedUserIds[player.UserId]
                        or changedNames[player.Name]
                    ) then

                    refreshToolRole(
                        player
                    )
                end
            end

        elseif not state.Ready then
            refreshAllESP()
            updateRoundInfo()
        end
    end

    local function locateKillEventRemote()
        local remotes =
            ReplicatedStorage:
                FindFirstChild(
                    "Remotes"
                )

        local gameplay =
            remotes
            and remotes:
                FindFirstChild(
                    "Gameplay"
                )

        local killEvent =
            gameplay
            and gameplay:
                FindFirstChild(
                    "KillEvent"
                )

        if killEvent
            and killEvent:IsA(
                "RemoteEvent"
            ) then

            return killEvent
        end

        return nil
    end

    local function locateRoleRemote()
        local remotes =
            ReplicatedStorage:
                FindFirstChild(
                    "Remotes"
                )
            or ReplicatedStorage:
                WaitForChild(
                    "Remotes",
                    10
                )

        if not remotes then
            return nil
        end

        local gameplay =
            remotes:
                FindFirstChild(
                    "Gameplay"
                )
            or remotes:
                WaitForChild(
                    "Gameplay",
                    10
                )

        if not gameplay then
            return nil
        end

        return gameplay:
            FindFirstChild(
                "PlayerDataChanged"
            )
            or gameplay:
                WaitForChild(
                    "PlayerDataChanged",
                    10
                )
    end

    for _, player in ipairs(
        Players:GetPlayers()
    ) do
        bindPlayer(player)
    end

    trackConnection(
        Players.PlayerAdded:Connect(
            function(player)
                bindPlayer(player)
            end
        )
    )

    trackConnection(
        Players.PlayerRemoving:Connect(
            function(player)
                unbindPlayer(player)
                updateRoundInfo()
            end
        )
    )

    -- One permanent listener for the exact physical dropped sheriff gun.
    -- This is intentionally independent of PlayerDataChanged / WaitingForDrop.
    trackConnection(
        workspace.DescendantAdded:Connect(
            function(object)
                if not state.Alive then
                    return
                end

                if isExactGunDrop(
                    object
                ) then

                    setExactGunDrop(
                        object
                    )
                end

                local miscHandler =
                    state.Misc
                    and state.Misc.OnWorkspaceDescendantAdded

                if type(miscHandler)
                    == "function" then

                    pcall(
                        miscHandler,
                        object
                    )
                end
            end
        )
    )

    -- Catch a GunDrop that already existed before the module finished loading.
    task.defer(function()
        if not state.Alive then
            return
        end

        local existing =
            findExistingGunDrop()

        if existing then
            setExactGunDrop(
                existing
            )
        end
    end)

    -- The only recurring MM2 worker: 4 Hz lightweight sampling/label refresh.
    -- Death detection itself is never polled; PlayerDataChanged is authoritative.
    -- FOV visual position is updated by a temporary RenderStepped
    -- connection only while "Show FOV Circle" is enabled.

    task.spawn(function()
        while state.Alive do
            if state.Gun.CurrentCarrierUserId then
                sampleCurrentCarrierPosition()
            end

            if state.Gun.DropBillboard then
                updateGunESP()
            end

            if playerDistanceEnabled then
                updatePlayerDistanceLabels()
            end

            if state.Combat.SilentAimEnabled then
                ensureSilentAimGunBinding()
            end

            local miscTick =
                state.Misc
                and state.Misc.Tick

            if type(miscTick)
                == "function" then

                pcall(
                    miscTick
                )
            end

            maybeAutoShootMurderer()

            local autoKillSheriff =
                state.Combat.MaybeAutoKillSheriff

            if type(autoKillSheriff)
                == "function" then

                pcall(
                    autoKillSheriff
                )
            end

            task.wait(
                gunPositionSampleInterval
            )
        end
    end)

    -- Cache the current local Gun.Shoot RemoteEvent as the gun moves between
    -- Backpack and Character. These are event-driven and do not add polling.
    trackConnection(
        LocalPlayer.CharacterAdded:Connect(
            function(character)
                task.defer(function()
                    if not state.Alive then
                        return
                    end

                    local gun =
                        character:FindFirstChild(
                            "Gun"
                        )

                    cacheGunShootRemote(
                        gun
                    )

                    if state.Combat.SilentAimEnabled then
                        ensureSilentAimGunBinding()
                    end
                end)
            end
        )
    )

    trackConnection(
        LocalPlayer.ChildAdded:Connect(
            function(child)
                if child.Name == "Backpack" then
                    task.defer(function()
                        if not state.Alive then
                            return
                        end

                        local gun =
                            child:FindFirstChild(
                                "Gun"
                            )

                        cacheGunShootRemote(
                            gun
                        )
                    end)
                end
            end
        )
    )

    local KillEventRemote =
        locateKillEventRemote()

    if KillEventRemote then
        trackConnection(
            KillEventRemote.OnClientEvent:Connect(
                function(
                    victimName,
                    _color,
                    _unused,
                    killMessage
                )
                    if not state.Alive
                        or type(victimName)
                            ~= "string" then

                        return
                    end

                    state.Combat.KillConfirmedAt[
                        victimName
                    ] = os.clock()

                    state.Combat.KillConfirmMessage[
                        victimName
                    ] =
                        tostring(
                            killMessage
                            or ""
                        )
                end
            )
        )
    end

    local RoleRemote =
        locateRoleRemote()

    if RoleRemote
        and RoleRemote:IsA(
            "RemoteEvent"
        ) then

        trackConnection(
            RoleRemote.OnClientEvent:Connect(
                ingestRolePayload
            )
        )

        RoundInfo:Set({
            Content = "Connected to PlayerDataChanged • waiting for the next role snapshot.",
        })
    else
        RoundInfo:Set({
            Content = "PlayerDataChanged RemoteEvent was not found.",
        })

        Window:Notify({
            Title = "MM2 Role ESP",
            Content = "PlayerDataChanged could not be found.",
            Duration = 5,
            Type = "failed",
        })
    end

    local function destroyFOVCircle()
        local renderConnection =
            state.Combat.FOVRenderConnection

        if renderConnection then
            pcall(function()
                renderConnection:Disconnect()
            end)
        end

        state.Combat.FOVRenderConnection = nil

        local gui =
            state.Combat.FOVCircleGui

        if gui then
            pcall(function()
                gui:Destroy()
            end)
        end

        state.Combat.FOVCircleGui = nil
        state.Combat.FOVCircleFrame = nil
        state.Combat.FOVLastX = nil
        state.Combat.FOVLastY = nil
        state.Combat.FOVLastRadius = nil
    end

    local function getFOVCircleParent()
        if type(gethui) == "function" then
            local ok, result =
                pcall(
                    gethui
                )

            if ok and result then
                return result
            end
        end

        local ok, coreGui =
            pcall(
                game.GetService,
                game,
                "CoreGui"
            )

        if ok and coreGui then
            return coreGui
        end

        return LocalPlayer:
            FindFirstChildOfClass(
                "PlayerGui"
            )
    end

    local function updateFOVCircle()
        local frame =
            state.Combat.FOVCircleFrame

        if not frame
            or not frame.Parent then

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

        if state.Combat.FOVLastRadius
            ~= radius then

            frame.Size =
                UDim2.fromOffset(
                    radius * 2,
                    radius * 2
                )

            state.Combat.FOVLastRadius =
                radius
        end

        local referencePoint =
            getFOVReferencePoint()

        if referencePoint then
            local x =
                math.floor(
                    referencePoint.X + 0.5
                )

            local y =
                math.floor(
                    referencePoint.Y + 0.5
                )

            if state.Combat.FOVLastX ~= x
                or state.Combat.FOVLastY ~= y then

                frame.Position =
                    UDim2.fromOffset(
                        x,
                        y
                    )

                state.Combat.FOVLastX = x
                state.Combat.FOVLastY = y
            end
        end

        if frame.Visible
            ~= state.Combat.ShowFOVCircle then

            frame.Visible =
                state.Combat.ShowFOVCircle
        end
    end

    local function startFOVRenderTracking()
        local existing =
            state.Combat.FOVRenderConnection

        if existing then
            return
        end

        state.Combat.FOVRenderConnection =
            RunService.RenderStepped:Connect(
                function()
                    if not state.Alive
                        or not state.Combat.ShowFOVCircle then

                        return
                    end

                    -- This is intentionally frame-based instead of relying on
                    -- GUI/InputChanged events. That way opening/minimizing the
                    -- hub cannot strand the circle at the last UI cursor spot.
                    updateFOVCircle()
                end
            )
    end

    local function applyFOVCircle()
        if not state.Combat.ShowFOVCircle then
            destroyFOVCircle()
            return
        end

        local existing =
            state.Combat.FOVCircleFrame

        if existing
            and existing.Parent then

            updateFOVCircle()
            startFOVRenderTracking()
            return
        end

        destroyFOVCircle()

        local parent =
            getFOVCircleParent()

        if not parent then
            return
        end

        local gui =
            Instance.new(
                "ScreenGui"
            )

        gui.Name =
            "Vitality_MM2_FOVCircle"

        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        -- Keep the FOV visual below Vitality's interactive window so it
        -- never looks attached to / on top of the menu.
        gui.DisplayOrder = 1
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

        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0

        -- Pure visual: never capture mouse, keyboard, selection, or GUI focus.
        frame.Active = false
        frame.Selectable = false

        pcall(function()
            frame.Interactable = false
        end)

        frame.ZIndex = 1
        frame.Parent = gui

        local corner =
            Instance.new(
                "UICorner"
            )

        corner.CornerRadius =
            UDim.new(
                1,
                0
            )

        corner.Parent = frame

        local stroke =
            Instance.new(
                "UIStroke"
            )

        stroke.Name =
            "Outline"

        stroke.ApplyStrokeMode =
            Enum.ApplyStrokeMode.Border

        stroke.Thickness = 1.5
        stroke.Transparency = 0.12

        stroke.Color =
            Color3.fromRGB(
                235,
                235,
                235
            )

        stroke.Parent = frame

        gui.Parent = parent

        state.Combat.FOVCircleGui =
            gui

        state.Combat.FOVCircleFrame =
            frame

        updateFOVCircle()
        startFOVRenderTracking()
    end

    -- ============================================================
    -- COMBAT UI
    -- ============================================================

    (function()
        -- ============================================================
        -- SHARED SHERIFF TARGET SHOOTING
        -- ============================================================

        local function isShootablePlayer(
            player
        )
            if not player
                or player == LocalPlayer
                or player.Parent ~= Players then

                return false
            end

            return isAliveCombatTarget(
                player
            )
                and getCharacterRoot(
                    player
                ) ~= nil
        end

        local function getShootTargetPart(
            player
        )
            if not isShootablePlayer(
                player
            ) then

                return nil
            end

            local character =
                player.Character

            return character
                and (
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
                )
                or nil
        end

        local function normalizeTargetText(
            value
        )
            return string.lower(
                tostring(
                    value
                    or ""
                )
            )
        end

        local function findShootTarget(
            rawQuery
        )
            local query =
                normalizeTargetText(
                    rawQuery
                )

            local candidates = {}

            for _, player in ipairs(
                Players:GetPlayers()
            ) do
                if isShootablePlayer(
                    player
                ) then

                    table.insert(
                        candidates,
                        player
                    )
                end
            end

            if #candidates == 0 then
                return nil
            end

            if query == ""
                or query == "random"
                or query == "rand" then

                return candidates[
                    math.random(
                        1,
                        #candidates
                    )
                ]
            end

            local best = nil
            local bestScore =
                math.huge

            local bestLength =
                math.huge

            for _, player in ipairs(
                candidates
            ) do
                local username =
                    string.lower(
                        player.Name
                    )

                local display =
                    string.lower(
                        player.DisplayName
                        or ""
                    )

                local score = nil

                if username == query then
                    score = 1
                elseif display == query then
                    score = 2
                elseif string.sub(
                    username,
                    1,
                    #query
                ) == query then
                    score = 3
                elseif string.sub(
                    display,
                    1,
                    #query
                ) == query then
                    score = 4
                elseif string.find(
                    username,
                    query,
                    1,
                    true
                ) then
                    score = 5
                elseif string.find(
                    display,
                    query,
                    1,
                    true
                ) then
                    score = 6
                end

                if score then
                    local length =
                        #player.Name

                    if score < bestScore
                        or (
                            score == bestScore
                            and length < bestLength
                        ) then

                        best =
                            player

                        bestScore =
                            score

                        bestLength =
                            length
                    end
                end
            end

            return best
        end

        local function shootSpecificPlayer(
            player,
            notifyResult,
            returnCFrameOverride
        )
            if state.Combat.ShootBusy then
                return false
            end

            if not isShootablePlayer(
                player
            ) then

                if notifyResult then
                    Window:Notify({
                        Title = "Shoot Player",
                        Content = "No living matching player was found.",
                        Duration = 3,
                        Type = "failed",
                    })
                end

                return false
            end

            state.Combat.ShootBusy =
                true

            local character =
                LocalPlayer.Character

            local localRoot =
                getCharacterRoot(
                    LocalPlayer
                )

            local targetPart =
                getShootTargetPart(
                    player
                )

            local gun =
                equipLocalGun()

            local shootRemote =
                cacheGunShootRemote(
                    gun
                )
                or getKnownShootRemote()

            if not character
                or not localRoot
                or not targetPart
                or not gun
                or not shootRemote then

                state.Combat.ShootBusy =
                    false

                if notifyResult then
                    Window:Notify({
                        Title = "Shoot Player",
                        Content = "A usable local Gun/Shoot remote or target was not found.",
                        Duration = 4,
                        Type = "failed",
                    })
                end

                return false
            end

            local originalCFrame =
                typeof(returnCFrameOverride)
                    == "CFrame"
                and returnCFrameOverride
                or localRoot.CFrame

            -- Same close-teleport geometry Shoot Murderer uses.
            local teleportCFrame =
                getShootTeleportCFrame(
                    targetPart,
                    player
                )

            if not teleportCFrame then
                state.Combat.ShootBusy =
                    false
                return false
            end

            local moved =
                pcall(function()
                    character:PivotTo(
                        teleportCFrame
                    )
                end)

            if not moved then
                state.Combat.ShootBusy =
                    false
                return false
            end

            task.wait(0.035)

            gun =
                getLocalGun()
                or gun

            shootRemote =
                cacheGunShootRemote(
                    gun
                )
                or shootRemote

            -- Re-acquire the player's CURRENT hitbox after teleport, then use
            -- the SAME getPredictedAimPosition movement/latency prediction
            -- that Shoot Murderer ultimately uses.
            targetPart =
                getShootTargetPart(
                    player
                )

            local originCFrame =
                getGunShotOrigin(
                    gun
                )

            local predictedPosition =
                typeof(originCFrame)
                    == "CFrame"
                and targetPart
                and getPredictedAimPosition(
                    targetPart,
                    originCFrame.Position
                )
                or nil

            local aimCFrame =
                typeof(predictedPosition)
                    == "Vector3"
                and CFrame.new(
                    predictedPosition
                )
                or nil

            local canShoot =
                typeof(originCFrame)
                    == "CFrame"
                and typeof(aimCFrame)
                    == "CFrame"
                and targetPart ~= nil
                and player.Character ~= nil

            if canShoot
                and state.Combat.VisibleCheck then

                canShoot =
                    isVisibleFrom(
                        originCFrame.Position,
                        targetPart,
                        player.Character
                    )
            end

            local fired = false

            if canShoot then
                fired =
                    pcall(function()
                        shootRemote:FireServer(
                            originCFrame,
                            aimCFrame
                        )
                    end)
            end

            task.wait(0.08)

            if state.Alive
                and LocalPlayer.Character
                    == character then

                pcall(function()
                    character:PivotTo(
                        originalCFrame
                    )
                end)
            end

            state.Combat.ShootBusy =
                false

            if notifyResult then
                Window:Notify({
                    Title = "Shoot Player",
                    Content = fired
                        and (
                            "Fired predicted shot at "
                            .. player.Name
                            .. "."
                        )
                        or (
                            state.Combat.VisibleCheck
                            and "Shot blocked by visibility check."
                            or "The gun could not be fired."
                        ),
                    Duration = 3,
                    Type = fired
                        and nil
                        or "failed",
                })
            end

            return fired
        end

        local function pickupGunAndShootPlayer(
            player
        )
            if state.Combat.ShootBusy then
                return false
            end

            if not isShootablePlayer(
                player
            ) then

                Window:Notify({
                    Title = "Shoot Player",
                    Content = "No living matching player was found.",
                    Duration = 3,
                    Type = "failed",
                })

                return false
            end

            if getLocalGun() then
                return shootSpecificPlayer(
                    player,
                    true
                )
            end

            local gunDrop =
                state.Gun.DroppedInstance

            if not isExactGunDrop(
                gunDrop
            ) then

                gunDrop =
                    findExistingGunDrop()

                if gunDrop then
                    setExactGunDrop(
                        gunDrop
                    )
                end
            end

            if not isExactGunDrop(
                gunDrop
            ) then

                Window:Notify({
                    Title = "Shoot Player",
                    Content = "You do not have the Gun and no dropped GunDrop was found.",
                    Duration = 4,
                    Type = "failed",
                })

                return false
            end

            local character =
                LocalPlayer.Character

            local root =
                getCharacterRoot(
                    LocalPlayer
                )

            if not character
                or not root then

                return false
            end

            local originalCFrame =
                root.CFrame

            local moved =
                pcall(function()
                    character:PivotTo(
                        CFrame.new(
                            gunDrop.Position
                            + Vector3.new(
                                0,
                                2,
                                0
                            )
                        )
                    )
                end)

            if not moved then
                return false
            end

            local deadline =
                os.clock()
                + 0.55

            local gun = nil

            repeat
                gun =
                    getLocalGun()

                if gun then
                    break
                end

                task.wait(0.025)
            until os.clock()
                >= deadline

            if not gun then
                if state.Alive
                    and LocalPlayer.Character
                        == character then

                    pcall(function()
                        character:PivotTo(
                            originalCFrame
                        )
                    end)
                end

                Window:Notify({
                    Title = "Shoot Player",
                    Content = "GunDrop was found, but the Gun was not picked up in time.",
                    Duration = 4,
                    Type = "failed",
                })

                return false
            end

            task.wait(0.10)

            return shootSpecificPlayer(
                player,
                true,
                originalCFrame
            )
        end

        -- ============================================================
        -- SHERIFF - LEFT / ABOVE MURDERER
        -- ============================================================

        local SheriffSection =
            CombatTab:CreateSection({
                Name = "Sheriff",
                Description = "Direct gun actions.",
                Side = "Left",
            })

        local AutoShootToggle =
            SheriffSection:CreateToggle({
                Name = "Auto Shoot Murderer",
                Info = "When you have the Gun, teleport close and fire the same predicted Gun.Handle shot used by Shoot Murderer.",
                CurrentValue = false,
                Flag = "MM2_AutoShootMurderer",
                Callback = function(value)
                    state.Combat.AutoShootEnabled =
                        value == true

                    if state.Combat.AutoShootEnabled then
                        seedKnownShootRemote()
                        state.Combat.LastAutoShootAt =
                            0
                    end
                end,
            })

        SheriffSection:CreateButton({
            Name = "Shoot Murderer",
            Info = "Acquire the Gun if needed, teleport close, use the shared movement prediction, fire, then return.",
            Interact = "Shoot",
            Callback = function()
                task.spawn(function()
                    pickupDroppedGunAndShootMurderer()
                end)
            end,
        })

        local ShootTargetStatus =
            SheriffSection:CreateStatus({
                Name = "Shoot Target",
                Info = "Type any username/display-name fragment, or type random.",
                CurrentValue = "None",
            })

        local ShootPlayerInput

        ShootPlayerInput =
            SheriffSection:CreateInput({
                Name = "Shoot Player",
                Info = "Partial username/display name supported. Type random to choose any living non-local player. Press Enter to shoot.",
                PlaceholderText = "username / display / random",
                CurrentValue = "",
                CharacterLimit = 32,
                OnEnter = true,
                RemoveTextAfterFocusLost = true,
                Callback = function(value)
                    local query =
                        tostring(
                            value
                            or ""
                        )

                    local target =
                        findShootTarget(
                            query
                        )

                    if target then
                        ShootTargetStatus:Set(
                            target.DisplayName
                            .. " (@"
                            .. target.Name
                            .. ")"
                        )

                        task.spawn(function()
                            pickupGunAndShootPlayer(
                                target
                            )
                        end)
                    else
                        ShootTargetStatus:Set(
                            "No match"
                        )

                        Window:Notify({
                            Title = "Shoot Player",
                            Content = "No living matching player was found.",
                            Duration = 3,
                            Type = "failed",
                        })
                    end

                    task.defer(function()
                        if ShootPlayerInput then
                            ShootPlayerInput:Set(
                                "",
                                false
                            )
                        end
                    end)
                end,
            })

        SheriffSection:CreateButton({
            Name = "Shoot Random Player",
            Info = "Pick any living non-local player and fire the same predicted shot used by Shoot Player.",
            Interact = "Shoot",
            Callback = function()
                local target =
                    findShootTarget(
                        "random"
                    )

                if not target then
                    Window:Notify({
                        Title = "Shoot Random",
                        Content = "No living player was available.",
                        Duration = 3,
                        Type = "failed",
                    })

                    return
                end

                ShootTargetStatus:Set(
                    target.DisplayName
                    .. " (@"
                    .. target.Name
                    .. ")"
                )

                task.spawn(function()
                    pickupGunAndShootPlayer(
                        target
                    )
                end)
            end,
        })

        -- ============================================================
        -- MURDERER - LEFT / BELOW SHERIFF
        -- ============================================================

        local MurdererSection =
            CombatTab:CreateSection({
                Name = "Murderer",
                Description = "Knife actions.",
                Side = "Left",
            })

        MurdererSection:CreateToggle({
            Name = "Auto Kill Sheriff",
            Info = "While you are Murderer, automatically find the living Sheriff/Hero and use the confirmed knife-kill flow.",
            CurrentValue = false,
            Flag = "MM2_AutoKillSheriff",
            Callback = function(value)
                state.Combat.AutoKillSheriffEnabled =
                    value == true

                state.Combat.LastAutoKillSheriffAt =
                    0
            end,
        })

        MurdererSection:CreateButton({
            Name = "Kill Everyone",
            Info = "Teleport, activate/swing the Knife, stab each target, and wait for KillEvent/death confirmation before moving on.",
            Interact = "Kill",
            Callback = function()
                killEveryoneAsMurderer()
            end,
        })

        MurdererSection:CreateButton({
            Name = "Kill Sheriff",
            Info = "Teleport, swing the Knife on the Sheriff/Hero, and retry until the kill is confirmed.",
            Interact = "Kill",
            Callback = function()
                killSheriffAsMurderer(
                    true
                )
            end,
        })

        state.Combat.MaybeAutoKillSheriff =
            function()
                if not state.Alive
                    or not state.Combat.AutoKillSheriffEnabled
                    or state.Combat.KillAllBusy
                    or not isLocalMurderer() then

                    return
                end

                local target =
                    getLivingSheriffOrHero()

                if not target then
                    return
                end

                local now =
                    os.clock()

                if now
                    - state.Combat.LastAutoKillSheriffAt
                    < state.Combat.AutoKillSheriffCooldown then

                    return
                end

                if not getLocalKnife() then
                    return
                end

                state.Combat.LastAutoKillSheriffAt =
                    now

                task.spawn(function()
                    killSheriffAsMurderer(
                        false
                    )
                end)
            end

        -- ============================================================
        -- AIM ASSISTANCE - RIGHT
        -- ============================================================

        local AimSection =
            CombatTab:CreateSection({
                Name = "Aim Assistance",
                Description = "Silent Aim and target filtering.",
                Side = "Right",
            })

        local SilentAimToggle =
            AimSection:CreateToggle({
                Name = "Silent Aim",
                Info = "Your normal gun shot is never intercepted. On activation, add one predicted Gun.Handle shot toward the Murderer.",
                CurrentValue = false,
                Flag = "MM2_SilentAim",
                Callback = function(value)
                    state.Combat.SilentAimEnabled =
                        value == true

                    if state.Combat.SilentAimEnabled then
                        seedKnownShootRemote()
                        ensureSilentAimGunBinding()
                    else
                        disconnectSilentAimGun()
                    end
                end,
            })

        local UseFOVToggle =
            AimSection:CreateToggle({
                Name = "FOV Check",
                Info = "Only assist Silent Aim when the Murderer is inside the configured screen-space FOV.",
                CurrentValue = false,
                Flag = "MM2_SilentAimUseFOV",
                Callback = function(value)
                    state.Combat.UseFOV =
                        value == true
                end,
            })

        local ShowFOVCircleToggle =
            AimSection:CreateToggle({
                Name = "Show FOV Circle",
                Info = "Free third-person follows the mouse every frame; locked camera stays centered.",
                CurrentValue = false,
                Flag = "MM2_ShowFOVCircle",
                Callback = function(value)
                    state.Combat.ShowFOVCircle =
                        value == true

                    applyFOVCircle()
                end,
            })

        local FOVSlider =
            AimSection:CreateSlider({
                Name = "FOV Radius",
                Range = {25, 600},
                Increment = 5,
                CurrentValue = 175,
                Suffix = "px",
                Flag = "MM2_SilentAimFOV",
                Callback = function(value)
                    state.Combat.FOVRadius =
                        tonumber(value)
                        or 175

                    updateFOVCircle()
                end,
            })

        local VisibleCheckToggle =
            AimSection:CreateToggle({
                Name = "Visible Check",
                Info = "Silent Aim and direct predicted shooting require an unobstructed target.",
                CurrentValue = false,
                Flag = "MM2_SilentAimVisible",
                Callback = function(value)
                    state.Combat.VisibleCheck =
                        value == true
                end,
            })

        -- These controls live inside this nested scope. Keep explicit references
        -- so the post-build synchronization below never falls through to nil
        -- globals and triggers module_loader_failed after the UI already built.
        state.Combat.UIControls = {
            SilentAimToggle = SilentAimToggle,
            UseFOVToggle = UseFOVToggle,
            FOVSlider = FOVSlider,
            ShowFOVCircleToggle = ShowFOVCircleToggle,
            VisibleCheckToggle = VisibleCheckToggle,
            AutoShootToggle = AutoShootToggle,
        }
    end)()

    -- ============================================================
    -- GUN
    -- ============================================================

    local GunSection =
        GunTab:CreateSection({
            Name = "Dropped Gun",
            Description = "Exact MM2 GunDrop tracking.",
            Side = "Left",
        })

    local AutoTeleportToggle =
        GunSection:CreateToggle({
            Name = "Auto-teleport to Dropped Gun",
            Info = "Wait for PlayerDataChanged to confirm Sheriff/Hero death, then find the exact GunDrop and teleport to it.",
            CurrentValue = false,
            Flag = "MM2_AutoTeleportGun",
            Callback = function(value)
                autoTeleportOnCarrierDeath =
                    value == true

                if autoTeleportOnCarrierDeath
                    and state.Gun.WaitingForDrop
                    and state.Gun.DropGeneration > 0
                    and state.Gun.AutoTeleportCompletedGeneration
                        ~= state.Gun.DropGeneration then

                    local generation =
                        state.Gun.DropGeneration

                    task.spawn(function()
                        autoTeleportToConfirmedDrop(
                            generation
                        )
                    end)
                end
            end,
        })

    local GunChamsToggle =
        GunSection:CreateToggle({
            Name = "Gun Chams",
            Info = "Highlight the exact physical workspace GunDrop through walls immediately when it exists; no role/death event required.",
            CurrentValue = true,
            Flag = "MM2_GunChams",
            Callback = function(value)
                gunChamsEnabled =
                    value == true

                if gunChamsEnabled
                    and not isExactGunDrop(
                        state.Gun.DroppedInstance
                    ) then

                    local existing =
                        findExistingGunDrop()

                    if existing then
                        setExactGunDrop(
                            existing
                        )
                    end
                end

                applyGunChams()
            end,
        })

    local GunESPToggle =
        GunSection:CreateToggle({
            Name = "Gun ESP",
            Info = "Show Gun Dropped [N studs] above the exact physical GunDrop immediately when it exists.",
            CurrentValue = true,
            Flag = "MM2_GunESP",
            Callback = function(value)
                gunESPEnabled =
                    value == true

                if gunESPEnabled
                    and not isExactGunDrop(
                        state.Gun.DroppedInstance
                    ) then

                    local existing =
                        findExistingGunDrop()

                    if existing then
                        setExactGunDrop(
                            existing
                        )
                    end
                end

                applyGunESP()
            end,
        })

    GunSection:CreateButton({
        Name = "Teleport to Dropped Gun",
        Info = "Find and teleport to the live physical GunDrop directly; otherwise fall back to the last cached carrier position.",
        Interact = "Teleport",
        Callback = function()
            teleportToGun()
        end,
    })

    local DropNotifyToggle =
        GunSection:CreateToggle({
            Name = "Notify on Gun Drop",
            Info = "Notify whenever the exact physical GunDrop instance appears in Workspace.",
            CurrentValue = true,
            Flag = "MM2_NotifyGunDrop",
            Callback = function(value)
                notifyGunDrop =
                    value == true
            end,
        })

    -- ============================================================
    -- PERSONALIZATION
    -- ============================================================

    local AppearanceSection =
        Personalization:CreateSection({
            Name = "Appearance",
            Description = "Theme and interface accent controls.",
            Side = "Left",
        })

    AppearanceSection:CreateThemeDropdown({
        Name = "Theme",
        Info = "Switch the hub palette.",
        CurrentOption = Window:GetTheme(),
        Flag = "Theme",
    })

    local FontPreset =
        AppearanceSection:CreateDropdown({
            Name = "Interface font",
            Info = "Choose the font used throughout vitality's hub.",
            Options = Window:GetFontOptions(),
            CurrentOption = Window:GetFontPreset(),
            Flag = "InterfaceFont",
            Callback = function(option)
                Window:SetFontPreset(option)
            end,
        })

    Window:SetFontPreset(
        FontPreset:Get()
    )

    AppearanceSection:CreateAccentPicker({
        Name = "Accent color",
        Info = "Change every interface accent globally.",
        Color = NovaField.Theme.Accent,
        Flag = "AccentColor",
    })

    AppearanceSection:CreateButtonPicker({
        Name = "Button color",
        Info = "Change action buttons independently from the accent.",
        Color = NovaField.Theme.Button,
        Flag = "ButtonColor",
    })

    local BorderSection =
        Personalization:CreateSection({
            Name = "Window Border",
            Description = "Control the outer window stroke.",
            Side = "Right",
        })

    local BorderEnabled =
        BorderSection:CreateToggle({
            Name = "Border stroke",
            CurrentValue = true,
            Flag = "BorderStrokeEnabled",
            Callback = function(value)
                Window:SetBorderStrokeEnabled(
                    value
                )
            end,
        })

    local FollowAccent =
        BorderSection:CreateToggle({
            Name = "Follow accent",
            CurrentValue = true,
            Flag = "BorderFollowsAccent",
            Callback = function(value)
                Window:SetBorderStrokeUseAccent(
                    value
                )
            end,
        })

    local BorderThickness =
        BorderSection:CreateSlider({
            Name = "Border thickness",
            Range = {0.5, 6},
            Increment = 0.5,
            CurrentValue = 1,
            Suffix = "px",
            Flag = "BorderThickness",
            Callback = function(value)
                Window:SetBorderStrokeThickness(
                    value
                )
            end,
        })

    local BorderTransparency =
        BorderSection:CreateSlider({
            Name = "Border transparency",
            Range = {0, 100},
            Increment = 1,
            CurrentValue = 18,
            Suffix = "%",
            Flag = "BorderTransparency",
            Callback = function(value)
                Window:SetBorderStrokeTransparency(
                    value / 100
                )
            end,
        })

    local BorderColor =
        BorderSection:CreateColorPicker({
            Name = "Border color",
            Color = NovaField.Theme.Border,
            Flag = "BorderColor",
            Callback = function(color)
                Window:SetBorderStrokeColor(
                    color
                )

                FollowAccent:Set(
                    false,
                    false
                )
            end,
        })

    Window:SetBorderStrokeEnabled(
        BorderEnabled:Get()
    )

    Window:SetBorderStrokeThickness(
        BorderThickness:Get()
    )

    Window:SetBorderStrokeTransparency(
        BorderTransparency:Get()
        / 100
    )

    if FollowAccent:Get() then
        Window:SetBorderStrokeUseAccent(
            true
        )
    else
        Window:SetBorderStrokeColor(
            BorderColor:Get()
        )
    end

    local HubSection =
        Personalization:CreateSection({
            Name = "vitality's hub",
            Description = "Shortcuts, motion, and hub controls.",
            Side = "Left",
        })

    HubSection:CreateKeybind({
        Name = "Toggle hub",
        CurrentKeybind =
            Window:GetToggleKey(),
        Flag = "InterfaceKeybind",
        Behavior = "ToggleInterface",
    })

    local AnimationsToggle =
        HubSection:CreateToggle({
            Name = "Hub animations",
            CurrentValue =
                Window:GetAnimationsEnabled(),
            Flag = "InterfaceAnimations",
            Callback = function(value)
                Window:SetAnimationsEnabled(
                    value
                )
            end,
        })

    local AnimationSpeed =
        HubSection:CreateSlider({
            Name = "Animation speed",
            Range = {0.5, 2},
            Increment = 0.05,
            CurrentValue =
                Window:GetMotionSpeed(),
            Suffix = "x",
            Flag = "AnimationSpeed",
            Callback = function(value)
                Window:SetMotionSpeed(
                    value
                )
            end,
        })

    Window:SetAnimationsEnabled(
        AnimationsToggle:Get()
    )

    Window:SetMotionSpeed(
        AnimationSpeed:Get()
    )

    HubSection:CreateButton({
        Name = "Save configuration",
        Interact = "Save",
        Callback = function()
            Window:SaveConfiguration()

            Window:Notify({
                Title = "Settings saved",
                Content = "Your preferences are up to date.",
                Duration = 3,
            })
        end,
    })

    -- Synchronize backing state with values restored by Vitality.
    roleESPEnabled = MasterToggle:Get()
    chamsEnabled = ChamsToggle:Get()
    labelsEnabled = LabelsToggle:Get()
    playerDistanceEnabled =
        PlayerDistanceToggle:Get()
    showMurderer = MurdererToggle:Get()
    showSheriff = SheriffToggle:Get()
    showInnocents = InnocentToggle:Get()
    showDead = DeadToggle:Get()

    autoTeleportOnCarrierDeath =
        AutoTeleportToggle:Get()

    gunChamsEnabled =
        GunChamsToggle:Get()

    gunESPEnabled =
        GunESPToggle:Get()

    notifyGunDrop =
        DropNotifyToggle:Get()

    local CombatControls =
        state.Combat.UIControls
        or {}

    local control =
        CombatControls.SilentAimToggle

    if control then
        state.Combat.SilentAimEnabled =
            control:Get()
    end

    control =
        CombatControls.UseFOVToggle

    if control then
        state.Combat.UseFOV =
            control:Get()
    end

    control =
        CombatControls.FOVSlider

    if control then
        state.Combat.FOVRadius =
            control:Get()
    end

    control =
        CombatControls.ShowFOVCircleToggle

    if control then
        state.Combat.ShowFOVCircle =
            control:Get()
    end

    control =
        CombatControls.VisibleCheckToggle

    if control then
        state.Combat.VisibleCheck =
            control:Get()
    end

    control =
        CombatControls.AutoShootToggle

    if control then
        state.Combat.AutoShootEnabled =
            control:Get()
    end

    if state.Combat.SilentAimEnabled
        or state.Combat.AutoShootEnabled then

        seedKnownShootRemote()
    end

    if state.Combat.SilentAimEnabled then
        ensureSilentAimGunBinding()
    end

    applyFOVCircle()
    applyGunChams()
    applyGunESP()

    refreshAllESP()
    updateRoundInfo()

    local function restore()
        if not state.Alive then
            return
        end

        state.Alive = false
        state.Ready = false

        for _, connection in ipairs(
            state.Connections
        ) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        state.Connections = {}

        local playersToClear = {}

        for player in pairs(
            state.ESPObjects
        ) do
            table.insert(
                playersToClear,
                player
            )
        end

        for _, player in ipairs(
            playersToClear
        ) do
            destroyESP(player)
        end

        state.RoleByUserId = {}
        state.RoleByName = {}
        state.PlayerBindings = {}

        state.Gun.CurrentCarrierUserId = nil
        state.Gun.CurrentCarrierName = nil
        state.Gun.CurrentCarrierRole = nil
        state.Gun.LastCarrierCFrame = nil
        state.Gun.WaitingForDrop = false
        state.Gun.DroppedInstance = nil
        state.Gun.DropGeneration += 1
        state.Gun.AutoTeleportGeneration =
            state.Gun.DropGeneration
        state.Gun.AutoTeleportCompletedGeneration = 0

        clearDropConnections()

        state.ToolRoleByUserId = {}
        state.ToolRoleByName = {}
        state.ToolEvidence = {}
        state.ToolRefreshPending =
            setmetatable(
                {},
                {__mode = "k"}
            )

        state.Combat.SilentAimEnabled =
            false

        disconnectSilentAimGun()

        state.Combat.ShowFOVCircle =
            false

        destroyFOVCircle()

        state.Combat.AutoShootEnabled =
            false

        state.Combat.ShootBusy =
            false

        state.Combat.KillAllBusy =
            false

        state.Combat.AutoKillSheriffEnabled =
            false

        state.Combat.MaybeAutoKillSheriff =
            nil

        state.Combat.UIControls = {}

        state.Combat.KillConfirmedAt = {}
        state.Combat.KillConfirmMessage = {}

        if state.Misc
            and type(
                state.Misc.Cleanup
            ) == "function" then

            pcall(
                state.Misc.Cleanup
            )
        end

        local current =
            rawget(
                _G,
                "__VITALITY_MM2_MODULE_BUILD_STATE"
            )

        if current == state then
            rawset(
                _G,
                "__VITALITY_MM2_MODULE_BUILD_STATE",
                nil
            )
        end
    end

    state.Restore = restore
    Window:AddCleanup(restore)

    task.defer(function()
        task.wait()

        if state.Alive
            and type(
                Window.LoadConfiguration
            ) == "function" then

            pcall(function()
                Window:LoadConfiguration(true)
            end)
        end
    end)

    state.Ready = true

    Window:Notify({
        Title = "Murder Mystery 2",
        Content = "MM2 combat + predictive IY-inspired moving-target fling loaded.",
        Duration = 3,
    })

    return true
end
