-- vitality's hub / Apocalypse Rising 2 LS
-- Live Service module version: 1.02-LS
--
-- Converted from the supplied apocv1.02 script.
-- The old external UI and its separate settings layer are intentionally
-- removed. Vitality owns the interface, configuration, cleanup, and lifecycle.

return function(context)
    local NovaField = assert(
        context.Library or context.NovaField,
        "Vitality library missing from module context"
    )

    local Window = assert(
        context.Window,
        "Vitality window missing from module context"
    )

    -- Same-window duplicate guard, matching the Tower module pattern.
    local oldBuild = rawget(
        _G,
        "__VITALITY_APOC2_MODULE_BUILD_STATE"
    )

    if type(oldBuild) == "table"
        and oldBuild.Window == Window
        and oldBuild.Ready == true then
        return true
    end

    if type(oldBuild) == "table"
        and type(oldBuild.Restore) == "function" then
        pcall(oldBuild.Restore)
    end

    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")

    local localPlayer = Players.LocalPlayer
    local camera = workspace.CurrentCamera

    local DIST_DOT = 1000
    local DIST_MAX = 5000

    local espEnabled = true
    local chamsEnabled = true
    local boxEnabled = true
    local linesEnabled = true
    local showDistance = true
    local showWeapon = true
    local showName = true
    local showHealth = true
    local squadHighlight = true
    local visibleCheckChams = true
    local visibleCheckBox = true
    local optimisedESP = true
    local fullbrightEnabled = false

    local espData = {}
    local drawBoxes = {}
    local drawLines = {}
    local visCache = {}
    local visFrame = 0

    local charactersFolder =
        workspace:FindFirstChild("Characters")

    -- Capture the actual environment before Fullbright changes anything.
    local originalBrightness = Lighting.Brightness
    local originalClockTime = Lighting.ClockTime
    local originalFogEnd = Lighting.FogEnd
    local originalAmbient = Lighting.Ambient
    local originalOutdoorAmbient = Lighting.OutdoorAmbient

    local state = {
        Window = Window,
        Ready = false,
        Alive = true,
        Connections = {},
        ModuleStatus = type(context.Status) == "table" and context.Status or nil,
        StatusManifest = type(context.StatusManifest) == "table" and context.StatusManifest or nil,
        StatusInfo = nil,
        StatusDisconnect = nil,
        Owner = type(context.Owner) == "table" and context.Owner or nil,
    }

    rawset(
        _G,
        "__VITALITY_APOC2_MODULE_BUILD_STATE",
        state
    )

    local function receiveModuleStatus(entry, manifest, info)
        if not state.Alive then return end
        state.ModuleStatus = type(entry) == "table" and entry or nil
        state.StatusManifest = type(manifest) == "table" and manifest or state.StatusManifest
        state.StatusInfo = type(info) == "table" and info or nil
    end

    if type(context.SubscribeStatus) == "function" then
        local ok, disconnect = pcall(context.SubscribeStatus, receiveModuleStatus, true)
        if ok and type(disconnect) == "function" then
            state.StatusDisconnect = disconnect
        end
    end

    function state:GetModuleStatus()
        return self.ModuleStatus, self.StatusInfo
    end

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

local function getSquadMembers()

    local members = {}

    local playerList = localPlayer.PlayerGui:FindFirstChild("PlayerList", true)

    if not playerList then return members end

    local squadList = playerList:FindFirstChild("SquadList", true)

    if not squadList then return members end

    for _, obj in ipairs(squadList:GetDescendants()) do

        if obj:IsA("TextLabel") and obj.Name == "NameLabel" and obj.Text ~= "" then

            members[obj.Text] = true

        end

    end

    return members

end

local function isVisible(character)

    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not rootPart then return false end

    local origin = camera.CFrame.Position

    local direction = rootPart.Position - origin

    local rayParams = RaycastParams.new()

    local filter = {character}

    if localPlayer.Character then table.insert(filter, localPlayer.Character) end

    if charactersFolder then

        for _, char in ipairs(charactersFolder:GetChildren()) do

            table.insert(filter, char)

        end

    end

    rayParams.FilterDescendantsInstances = filter

    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(origin, direction, rayParams)

    return result == nil

end

local function getEquipped(character)

    local equipped = character:FindFirstChild("Equipped")

    if equipped then

        for _, obj in ipairs(equipped:GetChildren()) do

            if obj:IsA("Model") then return obj.Name end

        end

    end

    local tool = character:FindFirstChildWhichIsA("Tool")

    if tool then return tool.Name end

    return "No Weapon"

end

local function createDrawBox()

    local box = {}

    for i = 1, 4 do

        local line = Drawing.new("Line")

        line.Thickness = 2

        line.Transparency = 1

        line.Visible = false

        box[i] = line

    end

    return box

end

local function updateDrawBox(box, x, y, w, h, color)

    box[1].From = Vector2.new(x, y)

    box[1].To   = Vector2.new(x + w, y)

    box[2].From = Vector2.new(x, y + h)

    box[2].To   = Vector2.new(x + w, y + h)

    box[3].From = Vector2.new(x, y)

    box[3].To   = Vector2.new(x, y + h)

    box[4].From = Vector2.new(x + w, y)

    box[4].To   = Vector2.new(x + w, y + h)

    for i = 1, 4 do

        box[i].Color = color

        box[i].Visible = true

    end

end

local function hideDrawBox(box)

    for i = 1, 4 do

        box[i].Visible = false

    end

end

local function createDrawLine()

    local line = Drawing.new("Line")

    line.Thickness = 1

    line.Transparency = 1

    line.Visible = false

    return line

end

local function createDrawText(color)

    local text = Drawing.new("Text")

    text.Center = true

    text.Outline = true

    text.Transparency = 1

    text.Size = 12

    text.Color = color

    text.Text = ""

    text.Visible = false

    return text

end

local function hideDrawText(data)

    if not data then return end

    if data.drawName then data.drawName.Visible = false end

    if data.drawHealth then data.drawHealth.Visible = false end

    if data.drawDistance then data.drawDistance.Visible = false end

    if data.drawWeapon then data.drawWeapon.Visible = false end

end

local function getBoxBounds(character)

    local root = character:FindFirstChild("HumanoidRootPart")

    if not root then return nil end

    local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))

    local bot = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

    if top.Z < 0 or bot.Z < 0 then return nil end

    local h = math.abs(top.Y - bot.Y)

    local w = h * 0.6

    local x = top.X - w / 2

    local y = math.min(top.Y, bot.Y)

    return x, y, w, h

end

local function removeESP(player)

    if espData[player] then

        if espData[player].highlight then espData[player].highlight:Destroy() end

        if espData[player].billboardBottom then espData[player].billboardBottom:Destroy() end

        if espData[player].billboardName then espData[player].billboardName:Destroy() end

        if espData[player].billboardHealth then espData[player].billboardHealth:Destroy() end

        if espData[player].billboardDot then espData[player].billboardDot:Destroy() end

        if espData[player].drawName then espData[player].drawName:Remove() end

        if espData[player].drawHealth then espData[player].drawHealth:Remove() end

        if espData[player].drawDistance then espData[player].drawDistance:Remove() end

        if espData[player].drawWeapon then espData[player].drawWeapon:Remove() end

        espData[player] = nil

    end

    if drawBoxes[player] then

        for _, line in ipairs(drawBoxes[player]) do line:Remove() end

        drawBoxes[player] = nil

    end

    if drawLines[player] then

        drawLines[player]:Remove()

        drawLines[player] = nil

    end

    visCache[player] = nil

end

local function addESP(player)

    if player == localPlayer then return end

    local function setupESP(character)

        removeESP(player)

        local humanoid = character:WaitForChild("Humanoid", 5)

        local rootPart = character:WaitForChild("HumanoidRootPart", 5)

        if not humanoid or not rootPart then return end

        local highlight = Instance.new("Highlight")

        highlight.FillTransparency = 0.4

        highlight.OutlineTransparency = 0

        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

        highlight.FillColor = Color3.fromRGB(220, 40, 40)

        highlight.OutlineColor = Color3.fromRGB(255, 60, 60)

        highlight.Adornee = character

        highlight.Parent = character

        local billboardBottom = Instance.new("BillboardGui")

        billboardBottom.AlwaysOnTop = true

        billboardBottom.StudsOffsetWorldSpace = Vector3.new(0, -7.5, 0)

        billboardBottom.Size = UDim2.new(0, 100, 0, 30)

        billboardBottom.Adornee = rootPart

        billboardBottom.Parent = rootPart

        billboardBottom.Enabled = false

        local labelDist = Instance.new("TextLabel")

        labelDist.Size = UDim2.new(1, 0, 0.5, 0)

        labelDist.BackgroundTransparency = 1

        labelDist.TextColor3 = Color3.fromRGB(220, 220, 220)

        labelDist.TextStrokeTransparency = 0.3

        labelDist.Font = Enum.Font.GothamMedium

        labelDist.TextSize = 9

        labelDist.Text = "0m"

        labelDist.Parent = billboardBottom

        local labelItem = Instance.new("TextLabel")

        labelItem.Size = UDim2.new(1, 0, 0.5, 0)

        labelItem.Position = UDim2.new(0, 0, 0.5, 0)

        labelItem.BackgroundTransparency = 1

        labelItem.TextColor3 = Color3.fromRGB(255, 200, 60)

        labelItem.TextStrokeTransparency = 0.3

        labelItem.Font = Enum.Font.GothamMedium

        labelItem.TextSize = 9

        labelItem.Text = "No Weapon"

        labelItem.Parent = billboardBottom

        -- Name sits above the character/chams in regular (non-dot) ESP mode.
        local billboardName = Instance.new("BillboardGui")

        billboardName.AlwaysOnTop = true

        billboardName.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)

        billboardName.Size = UDim2.new(0, 120, 0, 14)

        billboardName.Adornee = rootPart

        billboardName.Parent = rootPart

        billboardName.Enabled = false

        local labelNameMain = Instance.new("TextLabel")

        labelNameMain.Size = UDim2.new(1, 0, 1, 0)

        labelNameMain.BackgroundTransparency = 1

        labelNameMain.TextColor3 = Color3.fromRGB(235, 235, 235)

        labelNameMain.TextStrokeTransparency = 0.3

        labelNameMain.Font = Enum.Font.GothamMedium

        labelNameMain.TextSize = 10

        labelNameMain.Text = player.Name

        labelNameMain.Parent = billboardName

        -- Health sits below the character/chams, separate from the name.
        local billboardHealth = Instance.new("BillboardGui")

        billboardHealth.AlwaysOnTop = true

        billboardHealth.StudsOffsetWorldSpace = Vector3.new(0, -4.25, 0)

        billboardHealth.Size = UDim2.new(0, 120, 0, 14)

        billboardHealth.Adornee = rootPart

        billboardHealth.Parent = rootPart

        billboardHealth.Enabled = false

        local labelHealthMain = Instance.new("TextLabel")

        labelHealthMain.Size = UDim2.new(1, 0, 1, 0)

        labelHealthMain.BackgroundTransparency = 1

        labelHealthMain.TextColor3 = Color3.fromRGB(0, 255, 100)

        labelHealthMain.TextStrokeTransparency = 0.3

        labelHealthMain.Font = Enum.Font.GothamMedium

        labelHealthMain.TextSize = 9

        labelHealthMain.Text = "100 / 100 HP"

        labelHealthMain.Parent = billboardHealth

        local billboardDot = Instance.new("BillboardGui")

        billboardDot.AlwaysOnTop = true

        billboardDot.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)

        billboardDot.Size = UDim2.new(0, 12, 0, 12)

        billboardDot.Adornee = rootPart

        billboardDot.Parent = rootPart

        billboardDot.Enabled = false

        local labelDistDot = Instance.new("TextLabel")

        labelDistDot.Size = UDim2.new(1, 0, 0, 10)

        labelDistDot.BackgroundTransparency = 1

        labelDistDot.TextColor3 = Color3.fromRGB(180, 180, 180)

        labelDistDot.TextStrokeTransparency = 0.4

        labelDistDot.Font = Enum.Font.Gotham

        labelDistDot.TextSize = 8

        labelDistDot.Text = "0m"

        labelDistDot.Visible = false

        labelDistDot.Parent = billboardDot

        local dot = Instance.new("Frame")

        dot.Size = UDim2.new(0, 6, 0, 6)

        dot.Position = UDim2.new(0.5, -3, 0.5, -3)

        dot.BackgroundColor3 = Color3.fromRGB(0, 210, 80)

        dot.BorderSizePixel = 0

        dot.Parent = billboardDot

        local dotCorner = Instance.new("UICorner")

        dotCorner.CornerRadius = UDim.new(1, 0)

        dotCorner.Parent = dot

        local labelName = Instance.new("TextLabel")

        labelName.Size = UDim2.new(1, 0, 0, 10)

        labelName.Position = UDim2.new(0, 0, 0, 23)

        labelName.BackgroundTransparency = 1

        labelName.TextColor3 = Color3.fromRGB(220, 220, 220)

        labelName.TextStrokeTransparency = 0.4

        labelName.Font = Enum.Font.Gotham

        labelName.TextSize = 8

        labelName.Text = player.Name

        labelName.Visible = false

        labelName.Parent = billboardDot

        local labelHealthDot = Instance.new("TextLabel")

        labelHealthDot.Size = UDim2.new(1, 0, 0, 10)

        labelHealthDot.Position = UDim2.new(0, 0, 0, 34)

        labelHealthDot.BackgroundTransparency = 1

        labelHealthDot.TextColor3 = Color3.fromRGB(0, 255, 100)

        labelHealthDot.TextStrokeTransparency = 0.4

        labelHealthDot.Font = Enum.Font.Gotham

        labelHealthDot.TextSize = 8

        labelHealthDot.Text = "100 HP"

        labelHealthDot.Visible = false

        labelHealthDot.Parent = billboardDot

        local labelTeam = Instance.new("TextLabel")

        labelTeam.Size = UDim2.new(1, 0, 0, 10)

        labelTeam.Position = UDim2.new(0, 0, 0, 45)

        labelTeam.BackgroundTransparency = 1

        labelTeam.TextColor3 = Color3.fromRGB(50, 150, 255)

        labelTeam.TextStrokeTransparency = 0.4

        labelTeam.Font = Enum.Font.Gotham

        labelTeam.TextSize = 8

        labelTeam.Text = "[team]"

        labelTeam.Visible = false

        labelTeam.Parent = billboardDot

        drawBoxes[player] = createDrawBox()

        drawLines[player] = createDrawLine()

        local drawName = createDrawText(Color3.fromRGB(235, 235, 235))

        local drawHealth = createDrawText(Color3.fromRGB(0, 255, 100))

        local drawDistance = createDrawText(Color3.fromRGB(220, 220, 220))

        local drawWeapon = createDrawText(Color3.fromRGB(255, 200, 60))

        espData[player] = {

            highlight = highlight,

            billboardBottom = billboardBottom,

            billboardName = billboardName,

            billboardHealth = billboardHealth,

            billboardDot = billboardDot,

            dot = dot,

            labelDist = labelDist,

            labelItem = labelItem,

            labelNameMain = labelNameMain,

            labelHealthMain = labelHealthMain,

            labelDistDot = labelDistDot,

            labelNameDot = labelName,

            labelHealthDot = labelHealthDot,

            labelTeam = labelTeam,

            drawName = drawName,

            drawHealth = drawHealth,

            drawDistance = drawDistance,

            drawWeapon = drawWeapon,

            rootPart = rootPart,

            humanoid = humanoid,

            character = character,

        }

        trackConnection(humanoid.Died:Connect(function() removeESP(player) end))

    end

    local character = player.Character

    if not character and charactersFolder then

        character = charactersFolder:FindFirstChild(player.Name)

    end

    if character then setupESP(character) end

    trackConnection(player.CharacterAdded:Connect(function(c) setupESP(c) end))

    if charactersFolder then

        charactersFolder.ChildAdded:Connect(function(child)

            if child.Name == player.Name then setupESP(child) end

        end)

    end

end

    local squadMembers = {}

    -- Original script refreshed squad names every 2 seconds.
    task.spawn(function()
        while state.Alive do
            squadMembers = getSquadMembers()

            for _ = 1, 20 do
                if not state.Alive then
                    break
                end
                task.wait(0.1)
            end
        end
    end)

local fullbrightConn = nil
local function toggleFullbright(enabled)
    fullbrightEnabled = enabled

    if fullbrightEnabled then
        if fullbrightConn then
            fullbrightConn:Disconnect()
            fullbrightConn = nil
        end

        fullbrightConn = trackConnection(RunService.RenderStepped:Connect(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        end))
    else
        if fullbrightConn then
            fullbrightConn:Disconnect()
            fullbrightConn = nil
        end

        Lighting.Brightness = originalBrightness
        Lighting.ClockTime = originalClockTime
        Lighting.FogEnd = originalFogEnd
        Lighting.Ambient = originalAmbient
        Lighting.OutdoorAmbient = originalOutdoorAmbient
    end
end

    -- ============================================================
    -- VITALITY UI
    -- ============================================================

    local PlayerESPTab = Window:CreateTab(
        "Player ESP",
        "info"
    )

    local MiscTab = Window:CreateTab(
        "Misc",
        "settings"
    )

    -- Keep Personalization available only through the topbar palette button.
    local Personalization = Window:CreateTab(
        "Personalization",
        "palette"
    )

    if Personalization.NavButton then
        Personalization.NavButton.Visible = false
    end

    local ESPSection = PlayerESPTab:CreateSection({
        Name = "ESP",
        Description = "Player outlines, boxes, tracers, and visibility checks.",
        Side = "Left",
    })

    local ESPToggle = ESPSection:CreateToggle({
        Name = "ESP",
        Info = "Master switch for all player ESP rendering.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Master",
        Callback = function(value)
            espEnabled = value == true

            if not espEnabled then
                for _, data in pairs(espData) do
                    data.highlight.Enabled = false
                    data.billboardBottom.Enabled = false
                    data.billboardName.Enabled = false
                    data.billboardHealth.Enabled = false
                    data.billboardDot.Enabled = false
                    hideDrawText(data)
                end

                for _, box in pairs(drawBoxes) do
                    hideDrawBox(box)
                end

                for _, line in pairs(drawLines) do
                    line.Visible = false
                end
            end
        end,
    })

    local ChamsToggle = ESPSection:CreateToggle({
        Name = "Chams",
        Info = "Highlights players through geometry.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Chams",
        Callback = function(value)
            chamsEnabled = value == true

            if not chamsEnabled then
                for _, data in pairs(espData) do
                    data.highlight.Enabled = false
                end
            end
        end,
    })

    local VisibleChamsToggle = ESPSection:CreateToggle({
        Name = "Visible Check (Chams)",
        Info = "Green when directly visible and red when obstructed.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_VisibleChams",
        Callback = function(value)
            visibleCheckChams = value == true
        end,
    })

    local BoxToggle = ESPSection:CreateToggle({
        Name = "Box ESP",
        Info = "Draws a 2D box around nearby players.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Box",
        Callback = function(value)
            boxEnabled = value == true

            if not boxEnabled then
                for _, box in pairs(drawBoxes) do
                    hideDrawBox(box)
                end
            end
        end,
    })

    local VisibleBoxToggle = ESPSection:CreateToggle({
        Name = "Visible Check (Box)",
        Info = "Colors boxes according to line-of-sight visibility.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_VisibleBox",
        Callback = function(value)
            visibleCheckBox = value == true
        end,
    })

    local LinesToggle = ESPSection:CreateToggle({
        Name = "Lines",
        Info = "Draws tracer lines from the bottom-center of the screen.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Lines",
        Callback = function(value)
            linesEnabled = value == true

            if not linesEnabled then
                for _, line in pairs(drawLines) do
                    line.Visible = false
                end
            end
        end,
    })

    local InformationSection = PlayerESPTab:CreateSection({
        Name = "Player Information",
        Description = "Choose which details are rendered around players.",
        Side = "Right",
    })

    local DistanceToggle = InformationSection:CreateToggle({
        Name = "Show Distance",
        Info = "Shows distance to each tracked player.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Distance",
        Callback = function(value)
            showDistance = value == true
        end,
    })

    local WeaponToggle = InformationSection:CreateToggle({
        Name = "Show Weapon",
        Info = "Shows the currently equipped weapon or tool.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Weapon",
        Callback = function(value)
            showWeapon = value == true
        end,
    })

    local NameToggle = InformationSection:CreateToggle({
        Name = "Show Name",
        Info = "Shows each tracked player's username.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Name",
        Callback = function(value)
            showName = value == true
        end,
    })

    local HealthToggle = InformationSection:CreateToggle({
        Name = "Show Health",
        Info = "Shows current and maximum health.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Health",
        Callback = function(value)
            showHealth = value == true
        end,
    })

    local TeamToggle = InformationSection:CreateToggle({
        Name = "Team Check",
        Info = "Highlights squad members with the team color.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_TeamCheck",
        Callback = function(value)
            squadHighlight = value == true
        end,
    })

    local PerformanceSection = PlayerESPTab:CreateSection({
        Name = "Performance",
        Description = "Long-range ESP behavior.",
        Side = "Left",
    })

    local OptimisedToggle = PerformanceSection:CreateToggle({
        Name = "Optimised ESP (dots >1000m)",
        Info = "Uses compact dot ESP for targets at or beyond 1000 studs.",
        CurrentValue = true,
        Flag = "Apoc2_ESP_Optimised",
        Callback = function(value)
            optimisedESP = value == true
        end,
    })

    local LightingSection = MiscTab:CreateSection({
        Name = "Lighting",
        Description = "Local environment visibility.",
        Side = "Left",
    })

    local FullbrightToggle = LightingSection:CreateToggle({
        Name = "Fullbright",
        Info = "Forces bright daytime lighting while enabled.",
        CurrentValue = false,
        Flag = "Apoc2_Fullbright",
        Callback = function(value)
            toggleFullbright(value == true)
        end,
    })

    local InterfaceSection = MiscTab:CreateSection({
        Name = "Interface",
        Description = "Apocalypse Rising 2 interface shortcut.",
        Side = "Right",
    })

    InterfaceSection:CreateKeybind({
        Name = "Toggle GUI",
        Info = "Optional extra shortcut for Vitality.",
        CurrentKeybind = "PageUp",
        Flag = "Apoc2_ToggleGUI",
        PressedCallback = function()
            Window:Toggle()
        end,
    })

    InterfaceSection:CreateParagraph({
        Title = "Global shortcut",
        Content = "RightShift remains Vitality's normal hide/show shortcut unless changed in Personalization.",
    })

    -- ============================================================
    -- PERSONALIZATION
    -- ============================================================

    local AppearanceSection = Personalization:CreateSection({
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

    local FontPreset = AppearanceSection:CreateDropdown({
        Name = "Interface font",
        Info = "Choose the font used throughout vitality's hub.",
        Options = Window:GetFontOptions(),
        CurrentOption = Window:GetFontPreset(),
        Flag = "InterfaceFont",
        Callback = function(option)
            Window:SetFontPreset(option)
        end,
    })

    Window:SetFontPreset(FontPreset:Get())

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

    local BorderSection = Personalization:CreateSection({
        Name = "Window Border",
        Description = "Control the outer window stroke.",
        Side = "Right",
    })

    local BorderEnabled = BorderSection:CreateToggle({
        Name = "Border stroke",
        Info = "Show or hide the outer border.",
        CurrentValue = true,
        Flag = "BorderStrokeEnabled",
        Callback = function(value)
            Window:SetBorderStrokeEnabled(value)
        end,
    })

    local FollowAccent = BorderSection:CreateToggle({
        Name = "Follow accent",
        Info = "Keep the border synchronized with the accent color.",
        CurrentValue = true,
        Flag = "BorderFollowsAccent",
        Callback = function(value)
            Window:SetBorderStrokeUseAccent(value)
        end,
    })

    local BorderThickness = BorderSection:CreateSlider({
        Name = "Border thickness",
        Info = "Adjust the outer stroke width.",
        Range = {0.5, 6},
        Increment = 0.5,
        CurrentValue = 1,
        Suffix = "px",
        Flag = "BorderThickness",
        Callback = function(value)
            Window:SetBorderStrokeThickness(value)
        end,
    })

    local BorderTransparency = BorderSection:CreateSlider({
        Name = "Border transparency",
        Info = "Adjust how strongly the border is shown.",
        Range = {0, 100},
        Increment = 1,
        CurrentValue = 18,
        Suffix = "%",
        Flag = "BorderTransparency",
        Callback = function(value)
            Window:SetBorderStrokeTransparency(value / 100)
        end,
    })

    local BorderColor = BorderSection:CreateColorPicker({
        Name = "Border color",
        Info = "Choose a custom border color instead of the accent.",
        Color = NovaField.Theme.Border,
        Flag = "BorderColor",
        Callback = function(color)
            Window:SetBorderStrokeColor(color)
            FollowAccent:Set(false, false)
        end,
    })

    Window:SetBorderStrokeEnabled(BorderEnabled:Get())
    Window:SetBorderStrokeThickness(BorderThickness:Get())
    Window:SetBorderStrokeTransparency(BorderTransparency:Get() / 100)

    if FollowAccent:Get() then
        Window:SetBorderStrokeUseAccent(true)
    else
        Window:SetBorderStrokeColor(BorderColor:Get())
    end

    local HubSection = Personalization:CreateSection({
        Name = "vitality's hub",
        Description = "Shortcuts, motion, and hub controls.",
        Side = "Left",
    })

    HubSection:CreateKeybind({
        Name = "Toggle hub",
        Info = "Choose the shortcut used to open or close the hub.",
        CurrentKeybind = Window:GetToggleKey(),
        Flag = "InterfaceKeybind",
        Behavior = "ToggleInterface",
    })

    local AnimationsToggle = HubSection:CreateToggle({
        Name = "Hub animations",
        Info = "Animate tabs, popups, controls, and notifications.",
        CurrentValue = Window:GetAnimationsEnabled(),
        Flag = "InterfaceAnimations",
        Callback = function(enabled)
            Window:SetAnimationsEnabled(enabled)
        end,
    })

    local AnimationSpeed = HubSection:CreateSlider({
        Name = "Animation speed",
        Info = "Adjust the pace of interface motion.",
        Range = {0.5, 2},
        Increment = 0.05,
        CurrentValue = Window:GetMotionSpeed(),
        Suffix = "x",
        Flag = "AnimationSpeed",
        Callback = function(value)
            Window:SetMotionSpeed(value)
        end,
    })

    Window:SetAnimationsEnabled(AnimationsToggle:Get())
    Window:SetMotionSpeed(AnimationSpeed:Get())

    HubSection:CreateButton({
        Name = "Save configuration",
        Info = "Persist all flagged control values.",
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

    local AudioSection = Personalization:CreateSection({
        Name = "Audio",
        Description = "Vitality feedback sound controls.",
        Side = "Right",
    })

    local SoundVolume = AudioSection:CreateSlider({
        Name = "Sound volume",
        Info = "Adjust the hub sound level.",
        Range = {0, 100},
        Increment = 1,
        CurrentValue = math.floor(Window:GetSoundVolume() * 100 + 0.5),
        Suffix = "%",
        Flag = "SoundVolume",
        Callback = function(value)
            Window:SetSoundVolume(value / 100)
        end,
    })

    Window:SetSoundVolume(SoundVolume:Get() / 100)

    AudioSection:CreateButton({
        Name = "Preview feedback",
        Info = "Play a short notification sound.",
        Interact = "Preview",
        Callback = function()
            Window:Notify({
                Title = "Sound preview",
                Content = "Sound feedback is working.",
                Duration = 2.5,
            })
        end,
    })

    -- Make the internal state immediately match any values the controls loaded
    -- from Vitality's per-game config file.
    espEnabled = ESPToggle:Get()
    chamsEnabled = ChamsToggle:Get()
    visibleCheckChams = VisibleChamsToggle:Get()
    boxEnabled = BoxToggle:Get()
    visibleCheckBox = VisibleBoxToggle:Get()
    linesEnabled = LinesToggle:Get()
    showDistance = DistanceToggle:Get()
    showWeapon = WeaponToggle:Get()
    showName = NameToggle:Get()
    showHealth = HealthToggle:Get()
    squadHighlight = TeamToggle:Get()
    optimisedESP = OptimisedToggle:Get()
    toggleFullbright(FullbrightToggle:Get())

    -- ============================================================
    -- ORIGINAL AR2 ESP UPDATE LOGIC
    -- ============================================================

trackConnection(RunService.RenderStepped:Connect(function()

    visFrame = visFrame + 1

    local doVis = visFrame % 8 == 0

    local screenSize = camera.ViewportSize

    local localChar = localPlayer.Character

    if not localChar and charactersFolder then

        for _, char in ipairs(charactersFolder:GetChildren()) do

            if char.Name == localPlayer.Name then localChar = char break end

        end

    end

    for player, data in pairs(espData) do

        if not data.character or not data.character.Parent then

            removeESP(player)

            continue

        end

        if not espEnabled then

            data.highlight.Enabled = false

            data.billboardBottom.Enabled = false

            data.billboardName.Enabled = false

            data.billboardHealth.Enabled = false

            data.billboardDot.Enabled = false

            hideDrawText(data)

            if drawBoxes[player] then hideDrawBox(drawBoxes[player]) end

            if drawLines[player] then drawLines[player].Visible = false end

            continue

        end

        if not drawBoxes[player] then drawBoxes[player] = createDrawBox() end

        if not drawLines[player] then drawLines[player] = createDrawLine() end

        local dist = 9999

        if localChar and localChar:FindFirstChild("HumanoidRootPart") then

            dist = math.floor((data.rootPart.Position - localChar.HumanoidRootPart.Position).Magnitude)

        end

        if dist > DIST_MAX then

            data.highlight.Enabled = false

            data.billboardBottom.Enabled = false

            data.billboardName.Enabled = false

            data.billboardHealth.Enabled = false

            data.billboardDot.Enabled = false

            hideDrawText(data)

            if drawBoxes[player] then hideDrawBox(drawBoxes[player]) end

            if drawLines[player] then drawLines[player].Visible = false end

            visCache[player] = nil

            continue

        end

        if doVis then

            visCache[player] = isVisible(data.character)

        end

        local visible = visCache[player]

        if visible == nil then visible = false end

        local isSquadMate = squadHighlight and squadMembers[player.Name] == true

        local dotMode = optimisedESP and dist >= DIST_DOT

        data.highlight.Enabled = chamsEnabled and not dotMode

        -- Text now uses Drawing objects positioned relative to the actual ESP bounds.
        -- This keeps the order and spacing readable even at long range.
        data.billboardBottom.Enabled = false

        data.billboardName.Enabled = false

        data.billboardHealth.Enabled = false

        data.billboardDot.Enabled = optimisedESP and dotMode

        local currentHealth = math.max(data.humanoid.Health, 0)
        local maxHealth = math.max(data.humanoid.MaxHealth, 1)
        local healthRatio = math.clamp(currentHealth / maxHealth, 0, 1)
        local healthColor = Color3.fromRGB(
            math.floor(255 * (1 - healthRatio)),
            math.floor(255 * healthRatio),
            60
        )

        -- Legacy BillboardGui text is kept hidden; screen-space Drawing text below
        -- handles name / health / distance / weapon with consistent pixel spacing.
        data.labelNameMain.Visible = false
        data.labelHealthMain.Visible = false
        data.labelNameDot.Visible = false
        data.labelHealthDot.Visible = false
        data.labelDistDot.Visible = false
        data.labelTeam.Visible = false

        local espColor = isSquadMate and Color3.fromRGB(50, 150, 255)

            or visible and Color3.fromRGB(0, 255, 100)

            or Color3.fromRGB(255, 60, 60)

        local rootScreen, onScreen = camera:WorldToViewportPoint(data.rootPart.Position)

        if linesEnabled and onScreen and rootScreen.Z > 0 then

            drawLines[player].From = Vector2.new(screenSize.X / 2, screenSize.Y)

            drawLines[player].To = Vector2.new(rootScreen.X, rootScreen.Y)

            drawLines[player].Color = espColor

            drawLines[player].Visible = true

        else

            drawLines[player].Visible = false

        end

        local boxX, boxY, boxW, boxH = getBoxBounds(data.character)

        if boxEnabled and not dotMode and boxX then

            local boxColor = isSquadMate and Color3.fromRGB(50, 150, 255)

                or visibleCheckBox and espColor

                or Color3.fromRGB(255, 60, 60)

            updateDrawBox(drawBoxes[player], boxX, boxY, boxW, boxH, boxColor)

        else

            hideDrawBox(drawBoxes[player])

        end

        -- Exact screen-space ordering:
        -- Name -> Health -> Distance -> player ESP/chams/box -> Weapon.
        -- Drawing text is positioned from the projected player bounds so the rows
        -- cannot collapse into each other as world-space BillboardGui offsets do.
        if boxX and onScreen and rootScreen.Z > 0 then

            local rangeAlpha = math.clamp((dist - 100) / math.max(DIST_MAX - 100, 1), 0, 1)
            local textSize = math.clamp(math.floor((14 - (4 * rangeAlpha)) + 0.5), 10, 14)
            local rowSpacing = textSize + 4
            local centerX = boxX + (boxW * 0.5)

            data.drawName.Size = textSize
            data.drawHealth.Size = textSize
            data.drawDistance.Size = textSize
            data.drawWeapon.Size = textSize

            data.drawName.Position = Vector2.new(centerX, boxY - (rowSpacing * 3) - 2)
            data.drawHealth.Position = Vector2.new(centerX, boxY - (rowSpacing * 2) - 2)
            data.drawDistance.Position = Vector2.new(centerX, boxY - rowSpacing - 2)
            data.drawWeapon.Position = Vector2.new(centerX, boxY + boxH + 5)

            data.drawName.Text = player.Name
            data.drawHealth.Text = string.format("%d / %d HP", math.floor(currentHealth + 0.5), math.floor(maxHealth + 0.5))
            data.drawHealth.Color = healthColor
            data.drawDistance.Text = dist .. "m"
            data.drawWeapon.Text = getEquipped(data.character)

            data.drawName.Visible = showName
            data.drawHealth.Visible = showHealth
            data.drawDistance.Visible = showDistance
            data.drawWeapon.Visible = showWeapon

        else

            hideDrawText(data)

        end

        if dotMode then

            -- Optimised mode keeps only the small center dot. All text remains in the
            -- ordered Drawing stack above/below the player, including around 1100 studs.
            data.labelTeam.Visible = false
            data.labelDistDot.Visible = false
            data.labelNameDot.Visible = false
            data.labelHealthDot.Visible = false

            if isSquadMate then

                data.dot.BackgroundColor3 = Color3.fromRGB(50, 150, 255)

            else

                local t2 = math.clamp((dist - 1000) / 4000, 0, 1)

                data.dot.BackgroundColor3 = Color3.fromRGB(math.floor((1-t2)*220), math.floor(t2*210), 0)

            end

        else

            if isSquadMate then

                data.highlight.FillColor = Color3.fromRGB(0, 100, 255)

                data.highlight.OutlineColor = Color3.fromRGB(50, 150, 255)

            elseif visibleCheckChams then

                if visible then

                    data.highlight.FillColor = Color3.fromRGB(0, 210, 80)

                    data.highlight.OutlineColor = Color3.fromRGB(0, 255, 100)

                else

                    data.highlight.FillColor = Color3.fromRGB(220, 40, 40)

                    data.highlight.OutlineColor = Color3.fromRGB(255, 60, 60)

                end

            else

                data.highlight.FillColor = Color3.fromRGB(220, 40, 40)

                data.highlight.OutlineColor = Color3.fromRGB(255, 60, 60)

            end

        end

    end

end))

trackConnection(Players.PlayerAdded:Connect(addESP))

trackConnection(Players.PlayerRemoving:Connect(removeESP))

for _, player in ipairs(Players:GetPlayers()) do

    addESP(player)

end

    -- ============================================================
    -- HARD X / RE-EXECUTION CLEANUP
    -- ============================================================

    local function restore()
        if not state.Alive then
            return
        end

        state.Alive = false
        state.Ready = false

        if type(state.StatusDisconnect) == "function" then
            pcall(state.StatusDisconnect)
            state.StatusDisconnect = nil
        end

        pcall(function()
            toggleFullbright(false)
        end)

        for _, connection in ipairs(state.Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        state.Connections = {}

        local tracked = {}

        for player in pairs(espData) do
            table.insert(tracked, player)
        end

        for _, player in ipairs(tracked) do
            pcall(removeESP, player)
        end

        pcall(function()
            Lighting.Brightness = originalBrightness
            Lighting.ClockTime = originalClockTime
            Lighting.FogEnd = originalFogEnd
            Lighting.Ambient = originalAmbient
            Lighting.OutdoorAmbient = originalOutdoorAmbient
        end)

        local current = rawget(
            _G,
            "__VITALITY_APOC2_MODULE_BUILD_STATE"
        )

        if current == state then
            rawset(
                _G,
                "__VITALITY_APOC2_MODULE_BUILD_STATE",
                nil
            )
        end
    end

    state.Restore = restore
    Window:AddCleanup(restore)

    -- Same final configuration replay used by the Tower module: now that every
    -- control exists, saved values also fire their callbacks.
    task.defer(function()
        task.wait()

        if state.Alive
            and type(Window.LoadConfiguration) == "function" then

            pcall(function()
                Window:LoadConfiguration(true)
            end)
        end
    end)

    state.Ready = true

    Window:Notify({
        Title = "Apocalypse Rising 2",
        Content = "Vitality module loaded.",
        Duration = 3,
    })

    return true
end
