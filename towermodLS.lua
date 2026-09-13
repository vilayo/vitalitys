-- vitality's hub / The Tower module LS
-- Live Service module version: 1.9.14-LS
--
-- IMPORTANT:
-- This file intentionally does NOT load the library, create a Window,
-- run KeyAuth, or register games. The main loader owns all of that.

return function(context)
    local NovaField = assert(context.Library or context.NovaField, "Vitality library missing from module context")
    local Window = assert(context.Window, "Vitality window missing from module context")
    local Theme = NovaField.Theme

    -- Same-window duplicate-load guard.
    -- This prevents a second loader pass from rebuilding an interface that is
    -- already complete and then surfacing a misleading "Load Error" tab.
    if type(rawget(_G, "__VITALITY_TOWER_MODULE_BUILD_STATE")) == "table"
        and rawget(_G, "__VITALITY_TOWER_MODULE_BUILD_STATE").Window == Window
        and rawget(_G, "__VITALITY_TOWER_MODULE_BUILD_STATE").Ready == true then

        return true
    end

    local liveServiceState = {
        Window = Window,
        Ready = false,
        Alive = true,
        ModuleStatus = type(context.Status) == "table" and context.Status or nil,
        StatusManifest = type(context.StatusManifest) == "table" and context.StatusManifest or nil,
        StatusInfo = nil,
        StatusDisconnect = nil,
        Owner = type(context.Owner) == "table" and context.Owner or nil,
    }

    rawset(_G, "__VITALITY_TOWER_MODULE_BUILD_STATE", liveServiceState)

    local function receiveModuleStatus(entry, manifest, info)
        if not liveServiceState.Alive then return end
        liveServiceState.ModuleStatus = type(entry) == "table" and entry or nil
        liveServiceState.StatusManifest = type(manifest) == "table" and manifest or liveServiceState.StatusManifest
        liveServiceState.StatusInfo = type(info) == "table" and info or nil
    end

    if type(context.SubscribeStatus) == "function" then
        local ok, disconnect = pcall(context.SubscribeStatus, receiveModuleStatus, true)
        if ok and type(disconnect) == "function" then
            liveServiceState.StatusDisconnect = disconnect
        end
    end

    function liveServiceState:GetModuleStatus()
        return self.ModuleStatus, self.StatusInfo
    end

    Window:AddCleanup(function()
        liveServiceState.Alive = false
        if type(liveServiceState.StatusDisconnect) == "function" then
            pcall(liveServiceState.StatusDisconnect)
            liveServiceState.StatusDisconnect = nil
        end
    end)

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")

    -- Clear visual leftovers from an older Tower-module execution. The hub itself
    -- owns the actual interface, so the old Arrayfield ScreenGui cleanup is no longer needed.
    pcall(function()
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if tostring(obj.Name):match("^TheTower_") then
                obj:Destroy()
            end
        end
    end)

    -- Re-execution safety for the cursor override / hotkey used later in this module.
    pcall(function() RunService:UnbindFromRenderStep("TheTower_CursorUnlock") end)
    pcall(function() RunService:UnbindFromRenderStep("Vitality_Tower_AFKVisualBlock") end)
    pcall(function()
        if _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION then
            _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION:Disconnect()
            _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION = nil
        end
    end)

    -- Re-execution safety for the native sniper silent-aim hooks.
    -- Restore original ProjectileData.NewProjectile methods before installing
    -- a new copy, so repeated execution never stacks wrappers.
    pcall(function()
        local oldState = rawget(_G, "__VITALITY_TOWER_SILENT_AIM")
        if type(oldState) == "table" and type(oldState.Restore) == "function" then
            oldState.Restore()
        end
        rawset(_G, "__VITALITY_TOWER_SILENT_AIM", nil)
    end)

    -- Re-execution safety for sniper recoil / camera-effect overrides.
    -- Keep all locals inside this closure so the Tower module's outer scope
    -- does not grow.
    pcall(function()
        local oldState = rawget(_G, "__VITALITY_TOWER_SNIPER_EFFECTS")
        if type(oldState) == "table" and type(oldState.RestoreAll) == "function" then
            oldState.RestoreAll()
        end
        rawset(_G, "__VITALITY_TOWER_SNIPER_EFFECTS", nil)
    end)

    -- Re-execution safety for the native movement wrappers.
    -- Keep this nested: the Tower source is already near a practical
    -- Luau outer-scope local/register boundary.
    pcall(function()
        local oldState = rawget(_G, "__VITALITY_TOWER_MOVEMENT")
        if type(oldState) == "table" and type(oldState.Restore) == "function" then
            oldState.Restore()
        end
        rawset(_G, "__VITALITY_TOWER_MOVEMENT", nil)
    end)

    -- ============================================================
    -- VITALITY HUB NAVIGATION
    -- The original game logic is preserved, but the old standalone UI
    -- shell has been replaced by the window supplied by vitality's hub.
    -- ============================================================

    local MainTab = Window:CreateTab("Main", "main")
    MainTab._VitalityCharacterTab = Window:CreateTab("Character", "character")
    local TeleportsTab = Window:CreateTab("Teleports", "teleports")
    local ItemVisualsTab = Window:CreateTab("Item ESP", "items")
    local PlayerVisualsTab = Window:CreateTab("Player ESP", "esp")
    local PlayerToolsTab = Window:CreateTab("Players", "players")


    -- Small adapter that keeps the original feature code readable while routing
    -- every control through vitality's hub. Flags are generated automatically so
    -- supported toggles/dropdowns can participate in the hub configuration file.
    local function makeTowerFlag(sectionName, controlName)
        local token = tostring(sectionName or "Section") .. "_" .. tostring(controlName or "Control")
        token = token:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        return "Tower_" .. token
    end

    local function MakeSector(tab, section)
        local sector = {
            _Tab = tab,
            _Section = section,
        }

        function sector:AddButton(buttonName, callback)
            return tab:CreateButton({
                Name = buttonName,
                SectionParent = section,
                Callback = callback,
            })
        end

        function sector:AddToggle(toggleName, default, callback)
            return tab:CreateToggle({
                Name = toggleName,
                CurrentValue = default,
                Flag = makeTowerFlag(section.Name, toggleName),
                SectionParent = section,
                Callback = callback,
            })
        end

        function sector:AddDropdown(dropdownName, options, current, multi, callback)
            return tab:CreateDropdown({
                Name = dropdownName,
                Options = options or {},
                CurrentOption = multi and (type(current) == "table" and current or {}) or current,
                MultiSelection = multi or false,
                Flag = makeTowerFlag(section.Name, dropdownName),
                SectionParent = section,
                Callback = callback,
            })
        end

        return sector
    end

    local function CreateCategorySector(tab, sectionName, side, description)
        local section = tab:CreateSection({
            Name = sectionName,
            Side = side,
            Description = description,
        })
        return MakeSector(tab, section)
    end

    -- MAIN + CHARACTER TAB ORGANIZATION
    --
    -- Character:
    --   LEFT  = player stats
    --   RIGHT = local character controls
    --
    -- Main:
    --   LEFT  = Team Healer
    --   RIGHT = extraction + loot/key/safe automation
    local statsSection = CreateCategorySector(MainTab._VitalityCharacterTab, "Stats", "Left")
    local extractSection = CreateCategorySector(MainTab, "Extract", "Right")
    local characterSection = CreateCategorySector(MainTab._VitalityCharacterTab, "Character", "Right")

    local safeAutomationSection = CreateCategorySector(MainTab, "Safes", "Right")
    local advancedSafeAutomationSection = CreateCategorySector(MainTab, "Advanced Safes", "Right")
    local airdropAutomationSection = CreateCategorySector(MainTab, "Airdrops", "Right")

    -- ============================================================
    -- CHARACTER / LIVE PLAYER STATS
    -- ============================================================
    -- These values were identified in Players.LocalPlayer:
    --   CrateBriefCase, CrateDiamond, CrateMetal, CrateTitanium, CrateWooden
    --   KeyAdvancedSafe, KeyAirdrop, KeySafe, and XP.
    -- The card is a normal child of the vitality section body, so it remains
    -- centered inside the Main tab rather than living in a dropdown.
    local StatsLocalPlayer = game:GetService("Players").LocalPlayer

    local CaseDefinitions = {
        {ValueName = "CrateBriefCase", Label = "Brief", RemoteName = "BriefCase"},
        {ValueName = "CrateDiamond", Label = "Diamond", RemoteName = "DiamondCase"}, -- inferred from CrateDiamond
        {ValueName = "CrateMetal", Label = "Metal", RemoteName = "MetalCase"},
        {ValueName = "CrateTitanium", Label = "Titanium", RemoteName = "TitaniumCase"},
        {ValueName = "CrateWooden", Label = "Wooden", RemoteName = "WoodenCrate"}
    }

    local KeyValueDefinitions = {
        {ValueName = "KeySafe", Label = "Safe"},
        {ValueName = "KeyAdvancedSafe", Label = "Advanced"},
        {ValueName = "KeyAirdrop", Label = "Airdrop"}
    }

    local function readLocalPlayerNumber(valueName)
        if not StatsLocalPlayer then return 0, nil end

        local valueObject = StatsLocalPlayer:FindFirstChild(valueName)
            or StatsLocalPlayer:FindFirstChild(valueName, true)

        if valueObject then
            local ok, value = pcall(function()
                return valueObject.Value
            end)
            if ok then
                local numberValue = tonumber(value)
                if numberValue then
                    return numberValue, valueObject
                end
            end
        end

        local okAttribute, attribute = pcall(function()
            return StatsLocalPlayer:GetAttribute(valueName)
        end)
        if okAttribute then
            local numberValue = tonumber(attribute)
            if numberValue then
                return numberValue, nil
            end
        end

        return 0, valueObject
    end

    local function readXPValue()
        for _, candidate in ipairs({"XP", "Xp", "Experience", "PlayerXP"}) do
            local value, object = readLocalPlayerNumber(candidate)
            if object or value ~= 0 then
                return value
            end
        end
        return 0
    end

    local function roundedCount(value)
        return math.max(0, math.floor((tonumber(value) or 0) + 0.0001))
    end

    local function formatStatNumber(value)
        local number = roundedCount(value)
        local formatted = tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return formatted:gsub("^,", "")
    end

    local StatsHolder = statsSection._Section and statsSection._Section.Body
    local StatsCard
    local StatsAvatar
    local StatsNameLabel
    local StatsTextLabel

    if StatsHolder then
        StatsCard = Instance.new("Frame")
        StatsCard.Name = "TheTower_PlayerStatsCard"
        StatsCard.LayoutOrder = -100
        StatsCard.Size = UDim2.new(1, 0, 0, 286)
        StatsCard.BackgroundColor3 = Theme.Surface2
        StatsCard.BackgroundTransparency = 0.12
        StatsCard.BorderSizePixel = 0
        StatsCard.ClipsDescendants = false
        StatsCard.Parent = StatsHolder

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = StatsCard

        StatsNameLabel = Instance.new("TextLabel")
        StatsNameLabel.Name = "PlayerName"
        StatsNameLabel.AnchorPoint = Vector2.new(0.5, 0)
        StatsNameLabel.Position = UDim2.new(0.5, 0, 0, 10)
        StatsNameLabel.Size = UDim2.new(1, -20, 0, 27)
        StatsNameLabel.BackgroundTransparency = 1
        StatsNameLabel.Text = StatsLocalPlayer and StatsLocalPlayer.Name or "Player"
        StatsNameLabel.TextColor3 = Theme.Text
        StatsNameLabel.Font = Enum.Font.GothamBold
        StatsNameLabel.TextSize = 20
        StatsNameLabel.TextXAlignment = Enum.TextXAlignment.Center
        StatsNameLabel.Parent = StatsCard

        StatsAvatar = Instance.new("ImageLabel")
        StatsAvatar.Name = "Avatar"
        StatsAvatar.AnchorPoint = Vector2.new(0.5, 0)
        StatsAvatar.Position = UDim2.new(0.5, 0, 0, 43)
        StatsAvatar.Size = UDim2.fromOffset(92, 92)
        StatsAvatar.BackgroundColor3 = Theme.Background
        StatsAvatar.BorderSizePixel = 0
        StatsAvatar.ScaleType = Enum.ScaleType.Crop
        StatsAvatar.Parent = StatsCard

        local avatarCorner = Instance.new("UICorner")
        avatarCorner.CornerRadius = UDim.new(1, 0)
        avatarCorner.Parent = StatsAvatar

        StatsTextLabel = Instance.new("TextLabel")
        StatsTextLabel.Name = "LiveStats"
        StatsTextLabel.AnchorPoint = Vector2.new(0.5, 0)
        StatsTextLabel.Position = UDim2.new(0.5, 0, 0, 145)
        StatsTextLabel.Size = UDim2.new(1, -24, 0, 128)
        StatsTextLabel.BackgroundTransparency = 1
        StatsTextLabel.Text = "Loading stats..."
        StatsTextLabel.TextColor3 = Theme.Text
        StatsTextLabel.Font = Enum.Font.Gotham
        StatsTextLabel.TextSize = 15
        StatsTextLabel.TextWrapped = true
        StatsTextLabel.TextXAlignment = Enum.TextXAlignment.Center
        StatsTextLabel.TextYAlignment = Enum.TextYAlignment.Top
        StatsTextLabel.Parent = StatsCard

        if Window._registerThemeRenderer then
            Window:_registerThemeRenderer(function()
                if StatsCard and StatsCard.Parent then StatsCard.BackgroundColor3 = Theme.Surface2 end
                if StatsAvatar and StatsAvatar.Parent then StatsAvatar.BackgroundColor3 = Theme.Background end
                if StatsNameLabel and StatsNameLabel.Parent then StatsNameLabel.TextColor3 = Theme.Text end
                if StatsTextLabel and StatsTextLabel.Parent then StatsTextLabel.TextColor3 = Theme.Text end
            end)
        end
    end

    local function refreshPlayerStatsCard()
        if not StatsLocalPlayer or not StatsTextLabel or not StatsTextLabel.Parent then
            return
        end

        local caseCounts = {}
        local totalCases = 0

        for _, definition in ipairs(CaseDefinitions) do
            local count = roundedCount((readLocalPlayerNumber(definition.ValueName)))
            caseCounts[definition.ValueName] = count
            totalCases = totalCases + count
        end

        local keyCounts = {}
        local totalKeys = 0
        for _, definition in ipairs(KeyValueDefinitions) do
            local count = roundedCount((readLocalPlayerNumber(definition.ValueName)))
            keyCounts[definition.ValueName] = count
            totalKeys = totalKeys + count
        end

        local xp = readXPValue()

        StatsNameLabel.Text = StatsLocalPlayer.Name
        StatsTextLabel.Text = string.format(
            "Cases: %s total\nBrief: %s   Diamond: %s   Metal: %s\nTitanium: %s   Wooden: %s\n\nKeys: %s total   Safe: %s   Advanced: %s   Airdrop: %s\nXP: %s",
            formatStatNumber(totalCases),
            formatStatNumber(caseCounts.CrateBriefCase),
            formatStatNumber(caseCounts.CrateDiamond),
            formatStatNumber(caseCounts.CrateMetal),
            formatStatNumber(caseCounts.CrateTitanium),
            formatStatNumber(caseCounts.CrateWooden),
            formatStatNumber(totalKeys),
            formatStatNumber(keyCounts.KeySafe),
            formatStatNumber(keyCounts.KeyAdvancedSafe),
            formatStatNumber(keyCounts.KeyAirdrop),
            formatStatNumber(xp)
        )
    end

    -- Roblox supplies the authenticated player's own headshot, so this does not need
    -- any hard-coded asset or username.
    task.spawn(function()
        if not StatsLocalPlayer or not StatsAvatar or not StatsAvatar.Parent then return end

        local ok, image = pcall(function()
            return game:GetService("Players"):GetUserThumbnailAsync(
                StatsLocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)

        if ok and image and StatsAvatar and StatsAvatar.Parent then
            StatsAvatar.Image = image
        end
    end)

    -- Keep the displayed values live even if the game replaces one of the NumberValues.
    task.spawn(function()
        while task.wait(0.35) do
            if not StatsCard or not StatsCard.Parent then
                break
            end
            refreshPlayerStatsCard()
        end
    end)

    task.defer(refreshPlayerStatsCard)

    local CaseOpenRunning = false

    local function notifyMain(message)
        pcall(function()
            Window:Notify({
                Title = "THE TOWER",
                Content = message,
                Duration = 7
            })
        end)
    end

    -- ============================================================
    -- CASE RESULT / CARD DETAILS
    -- ============================================================
    -- Cobalt shows OpenCrate returning TWO values:
    --   1) rewards, e.g. {{Id = 52, Type = "Card"}}
    --   2) per-reward values, e.g. {0.00875}
    -- The reward itself does not contain the card's gameplay stats, so we display the
    -- guaranteed Id/Type/chance and opportunistically look for richer card metadata
    -- already loaded in client-side Lua tables. If the game keeps those stats only on
    -- the server, the notification safely falls back to Card #<Id> + reported chance.
    local CardMetadataCache = {}

    local CardDetailFields = {
        "DisplayName", "Name", "Title", "Rarity", "Tier", "Level",
        "Description", "Stat", "Effect", "Damage", "Health", "Speed",
        "Amount", "Value", "Modifier", "Multiplier", "Duration", "Cooldown"
    }

    local function tableLooksLikeCardMetadata(tbl, cardId)
        if type(tbl) ~= "table" then return false end

        local ok, matches = pcall(function()
            local candidateId = rawget(tbl, "Id")
                or rawget(tbl, "ID")
                or rawget(tbl, "CardId")
                or rawget(tbl, "CardID")

            if tonumber(candidateId) ~= tonumber(cardId) then
                return false
            end

            local candidateType = rawget(tbl, "Type")
            if candidateType ~= nil and string.lower(tostring(candidateType)) ~= "card" then
                return false
            end

            -- Avoid treating the tiny OpenCrate reward table itself as metadata.
            for _, field in ipairs(CardDetailFields) do
                if rawget(tbl, field) ~= nil then
                    return true
                end
            end

            return false
        end)

        return ok and matches == true
    end

    local function findCardMetadata(cardId)
        if CardMetadataCache[cardId] ~= nil then
            return CardMetadataCache[cardId] or nil
        end

        local found = nil

        if type(getgc) == "function" then
            local ok, objects = pcall(function()
                return getgc(true)
            end)

            if ok and type(objects) == "table" then
                for _, candidate in ipairs(objects) do
                    if type(candidate) == "table" then
                        if tableLooksLikeCardMetadata(candidate, cardId) then
                            found = candidate
                            break
                        end

                        -- Common layouts are Cards[id] or Cards[tostring(id)].
                        local directNumeric = nil
                        local directString = nil
                        pcall(function()
                            directNumeric = rawget(candidate, cardId)
                            directString = rawget(candidate, tostring(cardId))
                        end)

                        if tableLooksLikeCardMetadata(directNumeric, cardId) then
                            found = directNumeric
                            break
                        elseif tableLooksLikeCardMetadata(directString, cardId) then
                            found = directString
                            break
                        end

                        -- One shallow scan catches arrays/dictionaries of card records
                        -- without recursively walking enormous or cyclic game tables.
                        local scanned = 0
                        local okPairs = pcall(function()
                            for _, nested in pairs(candidate) do
                                scanned = scanned + 1
                                if scanned > 250 then break end
                                if tableLooksLikeCardMetadata(nested, cardId) then
                                    found = nested
                                    break
                                end
                            end
                        end)

                        if okPairs and found then
                            break
                        end
                    end
                end
            end
        end

        CardMetadataCache[cardId] = found or false
        return found
    end

    local function formatCardMetadata(metadata)
        if type(metadata) ~= "table" then return nil end

        local pieces = {}
        local seen = {}

        for _, field in ipairs(CardDetailFields) do
            local value = nil
            pcall(function()
                value = rawget(metadata, field)
            end)

            if value ~= nil and (type(value) == "string" or type(value) == "number" or type(value) == "boolean") then
                local rendered = tostring(value)
                local token = field .. "=" .. rendered
                if not seen[token] then
                    seen[token] = true
                    table.insert(pieces, field .. ": " .. rendered)
                end
            end

            if #pieces >= 5 then
                break
            end
        end

        return #pieces > 0 and table.concat(pieces, " | ") or nil
    end

    local function formatCaseReward(reward, reportedValue)
        if type(reward) ~= "table" then
            return "Unknown reward"
        end

        local rewardType = tostring(reward.Type or "Reward")
        local rewardId = reward.Id or reward.ID or reward.CardId or reward.CardID
        local base

        if string.lower(rewardType) == "card" and rewardId ~= nil then
            base = string.format("Card #%s", tostring(rewardId))
            local metadata = findCardMetadata(rewardId)
            local details = formatCardMetadata(metadata)
            if details then
                base = base .. " | " .. details
            end
        elseif rewardId ~= nil then
            base = string.format("%s #%s", rewardType, tostring(rewardId))
        else
            base = rewardType
        end

        local probability = tonumber(reportedValue)
        if probability then
            base = base .. string.format(" | Reported chance: %.4f%%", probability * 100)
        end

        return base
    end

    local function formatCaseOpenResult(caseLabel, rewards, reportedValues)
        if type(rewards) ~= "table" then
            return caseLabel .. " opened."
        end

        local lines = {}
        for index, reward in ipairs(rewards) do
            local reported = type(reportedValues) == "table" and reportedValues[index] or nil
            table.insert(lines, formatCaseReward(reward, reported))
        end

        if #lines == 0 then
            return caseLabel .. " opened (no reward details returned)."
        end

        return caseLabel .. " opened:\n" .. table.concat(lines, "\n")
    end

    statsSection:AddButton("Open All Available Cases", function()
        if CaseOpenRunning then
            notifyMain("Cases are already being opened.")
            return
        end

        CaseOpenRunning = true

        task.spawn(function()
            local opened = 0
            local failures = 0

            local cratesFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Crates")
            local openRemote = cratesFolder and cratesFolder:FindFirstChild("OpenCrate")

            if not openRemote or not openRemote:IsA("RemoteFunction") then
                CaseOpenRunning = false
                notifyMain("Crates.OpenCrate was not found.")
                return
            end

            -- Snapshot the owned quantities so delayed replicated values cannot make
            -- this loop run forever. Each request still uses the captured quantity 1.
            for _, definition in ipairs(CaseDefinitions) do
                local owned = roundedCount((readLocalPlayerNumber(definition.ValueName)))

                for _ = 1, owned do
                    -- Preserve BOTH returned values from OpenCrate. Cobalt showed the
                    -- second table alongside the rewards table.
                    local ok, rewards, reportedValues = pcall(function()
                        return openRemote:InvokeServer(definition.RemoteName, 1)
                    end)

                    if not ok or rewards == false then
                        failures = failures + 1
                        break
                    end

                    opened = opened + 1
                    refreshPlayerStatsCard()

                    -- One concise notification per opened case, including card Id and
                    -- reported chance. Richer card stats are included if found client-side.
                    notifyMain(formatCaseOpenResult(definition.Label .. " Case", rewards, reportedValues))
                    task.wait(0.15)
                end
            end

            CaseOpenRunning = false
            refreshPlayerStatsCard()

            if opened > 0 then
                notifyMain(string.format(
                    "Finished opening cases! Opened %d%s.",
                    opened,
                    failures > 0 and " (one or more case types were rejected)" or ""
                ))
            else
                notifyMain("No available cases were opened.")
            end
        end)
    end)

    -- ============================================================
    -- PLAYERACTION INTERACTION PROMPT
    -- ============================================================
    -- The visible F prompt was located at:
    -- Players.LocalPlayer.PlayerGui.PlayerAction.Info.Input
    -- We use its real GUI visibility as a synchronization signal before invoking the
    -- pickup/unlock remote. We never force this GUI visible; the game itself must show it.
    local function getPlayerActionInteractionGui()
        if not StatsLocalPlayer then return nil, nil, nil end

        local playerGui = StatsLocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return nil, nil, nil end

        local playerAction = playerGui:FindFirstChild("PlayerAction")
            or playerGui:FindFirstChild("PlayerAction", true)

        local info = playerAction and (
            playerAction:FindFirstChild("Info")
            or playerAction:FindFirstChild("Info", true)
        ) or nil

        local input = info and (
            info:FindFirstChild("Input")
            or info:FindFirstChild("Input", true)
        ) or nil

        return playerAction, info, input
    end

    local function guiHierarchyIsVisible(guiObject)
        if not guiObject then return false end

        local current = guiObject
        while current do
            if current:IsA("GuiObject") and current.Visible == false then
                return false
            end

            if current:IsA("LayerCollector") and current.Enabled == false then
                return false
            end

            current = current.Parent
            if current == game then break end
        end

        return true
    end

    local function interactionPromptIsVisible()
        local _, info, input = getPlayerActionInteractionGui()

        if not info or not info:IsA("GuiObject") or not guiHierarchyIsVisible(info) then
            return false
        end

        if input and input:IsA("GuiObject") then
            if not guiHierarchyIsVisible(input) then
                return false
            end

            -- In the discovered hierarchy Input appears to be the actual text control.
            -- If it is textual, an empty value is treated as "no active prompt".
            if input:IsA("TextLabel") or input:IsA("TextButton") or input:IsA("TextBox") then
                local text = tostring(input.Text or "")
                if text:gsub("%s+", "") == "" then
                    return false
                end
            end
        end

        return true
    end

    -- Exact remote captured with Cobalt. Kept isolated in Character so it does not
    -- interfere with any of the teleport/ESP systems.
    characterSection._Tab:CreateLabel(
        "CHARACTER",
        characterSection._Section
    )

    characterSection:AddButton("Kill Player", function()
        pcall(function()
            local playerTeleport = game:GetService("ReplicatedStorage"):FindFirstChild("PlayerTeleport")
            local killRemote = playerTeleport and playerTeleport:FindFirstChild("Kill")
            if killRemote and killRemote:IsA("RemoteEvent") then
                killRemote:FireServer()
            end
        end)
    end)

    -- ============================================================
    -- GAME-NATIVE ANTI-AFK
    -- ============================================================
    -- TPS does NOT use Roblox's normal Player.Idled event. It watches the
    -- character origin and, after ~20 seconds without moving >2.5 studs, shows
    -- the AFK overlay for ~5 seconds and calls PlayerTeleport:KillKick().
    --
    -- Do not fake movement here: that would fight our teleport/freeze automation.
    -- Instead we wrap the game's own cached PlayerTeleport module and suppress
    -- ONLY the KillKick call that happens while the game's AFK visual state is
    -- visibly active. Match-timer / normal KillKick calls still pass through.
    local AntiAfkEnabled = false
    local AntiAfkPending = false
    local AntiAfkSuppressedCount = 0
    local AntiAfkStateKey = "__VITALITY_TOWER_ANTIAFK_STATE"

    -- Track the game's AFK condition ourselves so we can completely hide the
    -- AFK visuals without losing the signal used to distinguish AFK KillKick
    -- from the legitimate match-timer KillKick.
    local AntiAfkOrigin = nil
    local AntiAfkLastMovementAt = os.clock()
    local AntiAfkVisualRenderName = "Vitality_Tower_AFKVisualBlock"

    local function findAfkMain()
        local localPlayer = game:GetService("Players").LocalPlayer
        local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return nil
        end

        return playerGui:FindFirstChild("AFK_Main", true)
    end

    local function isNativeAfkVisualActive()
        local lighting = game:GetService("Lighting")
        local correction = lighting:FindFirstChild("AFK_ColorCorrection")

        -- START_AFK animates Saturation to -1. The normal match timer does not.
        if correction then
            local ok, saturation = pcall(function()
                return correction.Saturation
            end)

            if ok and tonumber(saturation) and saturation <= -0.45 then
                return true
            end
        end

        local afkMain = findAfkMain()
        if afkMain then
            local okTransparency, transparency = pcall(function()
                return afkMain.GroupTransparency
            end)

            if okTransparency and tonumber(transparency) and transparency <= 0.35 then
                return true
            end

            -- Fallback for executors/game versions where the container's
            -- GroupTransparency property is not readable.
            local afkText = afkMain:FindFirstChild("AFK", true)
            if afkText and (afkText:IsA("TextLabel") or afkText:IsA("TextButton")) then
                local text = tostring(afkText.Text or "")
                if text:lower():find("afk in", 1, true) then
                    return true
                end
            end
        end

        return false
    end

    local function clearNativeAfkVisuals()
        local afkMain = findAfkMain()
        if afkMain then
            pcall(function()
                afkMain.GroupTransparency = 1
            end)

            -- Also hide descendants directly in case a future game update stops
            -- respecting GroupTransparency on the cloned AFK container.
            for _, descendant in ipairs(afkMain:GetDescendants()) do
                pcall(function()
                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                        descendant.TextTransparency = 1
                        descendant.TextStrokeTransparency = 1
                    elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
                        descendant.ImageTransparency = 1
                    elseif descendant:IsA("Frame") then
                        descendant.BackgroundTransparency = 1
                    end
                end)
            end
        end

        local correction = game:GetService("Lighting"):FindFirstChild("AFK_ColorCorrection")
        if correction then
            pcall(function()
                correction.Saturation = 0
                correction.Enabled = false
            end)
        end
    end

    local function resetAntiAfkMovementTracker()
        AntiAfkOrigin = nil
        AntiAfkLastMovementAt = os.clock()
        AntiAfkPending = false
    end

    local function updateAntiAfkMovementTracker()
        if not AntiAfkEnabled then
            resetAntiAfkMovementTracker()
            return
        end

        local localPlayer = game:GetService("Players").LocalPlayer
        local character = localPlayer and localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and (
            character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("UpperTorso")
        )

        local collecting = false
        pcall(function()
            collecting = require(game:GetService("ReplicatedStorage").InteractionFlare).IsCollecting == true
        end)

        -- These mirror the important gates in TPS.GetTransform:
        -- no active Game, collecting, PlatformStand, or no usable character means
        -- the game's AFK countdown should not be considered active.
        if not workspace:FindFirstChild("Game")
            or not humanoid
            or not root
            or humanoid.PlatformStand
            or collecting then

            resetAntiAfkMovementTracker()
            return
        end

        local position = root.Position

        if not AntiAfkOrigin then
            AntiAfkOrigin = position
            AntiAfkLastMovementAt = os.clock()
            AntiAfkPending = false
            return
        end

        if (position - AntiAfkOrigin).Magnitude > 2.5 then
            AntiAfkOrigin = position
            AntiAfkLastMovementAt = os.clock()
            AntiAfkPending = false
            return
        end

        -- TPS starts START_AFK after 20 seconds at essentially the same origin.
        if os.clock() - AntiAfkLastMovementAt >= 19.75 then
            AntiAfkPending = true
        end
    end

    local function setAntiAfkVisualBlockEnabled(enabled)
        local runService = game:GetService("RunService")
        pcall(function()
            runService:UnbindFromRenderStep(AntiAfkVisualRenderName)
        end)

        if not enabled then
            return
        end

        -- Run after the game's normal render callbacks and continuously erase the
        -- visual state. START_AFK may keep trying to animate it; the player never
        -- sees the grayscale/filter/countdown while Anti-AFK is enabled.
        runService:BindToRenderStep(
            AntiAfkVisualRenderName,
            Enum.RenderPriority.Last.Value + 50,
            function()
                updateAntiAfkMovementTracker()
                clearNativeAfkVisuals()
            end
        )

        clearNativeAfkVisuals()
    end

    local function installNativeAntiAfk()
        -- Re-execution cleanup: unwrap the previous Vitality wrapper first so
        -- we never stack wrappers around PlayerTeleport.KillKick.
        local previousState = rawget(_G, AntiAfkStateKey)
        if type(previousState) == "table" and type(previousState.Restore) == "function" then
            pcall(previousState.Restore)
        end

        local replicatedStorage = game:GetService("ReplicatedStorage")
        local playerTeleportModuleScript = replicatedStorage:FindFirstChild("PlayerTeleport")
        if not playerTeleportModuleScript or not playerTeleportModuleScript:IsA("ModuleScript") then
            return false
        end

        local okRequire, playerTeleport = pcall(require, playerTeleportModuleScript)
        if not okRequire or type(playerTeleport) ~= "table" then
            return false
        end

        local originalKillKick = playerTeleport.KillKick
        if type(originalKillKick) ~= "function" then
            return false
        end

        local wrapper
        wrapper = function(self, ...)
            -- This is deliberately narrow. KillKick is also used when the actual
            -- match timer expires, so we only suppress it when TPS's AFK state is
            -- visibly active.
            if AntiAfkEnabled then
                updateAntiAfkMovementTracker()

                -- AntiAfkPending is derived from the SAME ~20 second / 2.5 stud
                -- stationary condition used by TPS, so the visual state can remain
                -- completely disabled and we can still distinguish the AFK call.
                if AntiAfkPending then
                    AntiAfkSuppressedCount = AntiAfkSuppressedCount + 1
                    clearNativeAfkVisuals()
                    return nil
                end
            end

            return originalKillKick(self, ...)
        end

        playerTeleport.KillKick = wrapper

        local state = {
            Module = playerTeleport,
            Wrapper = wrapper,
            Original = originalKillKick,
        }

        state.Restore = function()
            if state.Module and state.Module.KillKick == state.Wrapper then
                state.Module.KillKick = state.Original
            end
        end

        rawset(_G, AntiAfkStateKey, state)
        return true
    end

    local AntiAfkInstalled = installNativeAntiAfk()

    characterSection:AddToggle("Anti-AFK", false, function(value)
        AntiAfkEnabled = value == true

        if AntiAfkEnabled and not AntiAfkInstalled then
            AntiAfkInstalled = installNativeAntiAfk()
        end

        if not AntiAfkEnabled then
            setAntiAfkVisualBlockEnabled(false)
            resetAntiAfkMovementTracker()

            -- Return the game's color correction object to an ordinary neutral
            -- state. We do not force-enable the AFK effect while Anti-AFK is off.
            local correction = game:GetService("Lighting"):FindFirstChild("AFK_ColorCorrection")
            if correction then
                pcall(function()
                    correction.Saturation = 0
                end)
            end
            return
        end

        -- Completely suppress the AFK countdown/gray-screen presentation.
        resetAntiAfkMovementTracker()
        setAntiAfkVisualBlockEnabled(true)

        -- If Anti-AFK was switched on while the game's countdown was already
        -- visible, remove it immediately.
        if isNativeAfkVisualActive() then
            clearNativeAfkVisuals()
        end
    end)


    -- ============================================================
    -- CHARACTER / NATIVE MOVEMENT
    -- ============================================================
    -- Entirely nested on purpose. The controls are rendered inside the existing
    -- Character section so Main stays visually grouped without introducing another
    -- long-lived outer-scope section local.
    pcall(function()
        local MOVEMENT_STATE_KEY = "__VITALITY_TOWER_MOVEMENT"

        characterSection._Tab:CreateLabel(
            "MOVEMENT",
            characterSection._Section
        )

        local localPlayer = Players.LocalPlayer
        local playerScripts = localPlayer:WaitForChild("PlayerScripts")
        local movementFolder = playerScripts:FindFirstChild("Movement")
        local controllerModule =
            movementFolder and movementFolder:FindFirstChild("CharacterController")

        if not controllerModule or not controllerModule:IsA("ModuleScript") then
            characterSection._Tab:CreateLabel(
                "Native movement controls unavailable: CharacterController was not found.",
                characterSection._Section
            )
            return
        end

        local okController, controller = pcall(require, controllerModule)
        if not okController or type(controller) ~= "table" then
            characterSection._Tab:CreateLabel(
                "Native movement controls unavailable: CharacterController could not be loaded.",
                characterSection._Section
            )
            return
        end

        if type(controller.Move) ~= "function"
            or type(controller.Jump) ~= "function" then

            characterSection._Tab:CreateLabel(
                "Native movement controls unavailable: Move/Jump methods are missing.",
                characterSection._Section
            )
            return
        end

        local state = {
            SpeedEnabled = false,
            SpeedMultiplier = 1.50,

            JumpEnabled = false,
            JumpMultiplier = 1.50,

            Controller = controller,
            OriginalMove = controller.Move,
            OriginalJump = controller.Jump,

            MoveWrapper = nil,
            JumpWrapper = nil,
        }

        local function getCharacter()
            local character = nil

            pcall(function()
                character = controller:GetCharacter()
            end)

            return character or localPlayer.Character
        end

        local function getRoot()
            local character = getCharacter()

            return character and (
                character:FindFirstChild("HumanoidRootPart")
                or character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("Torso")
            )
        end

        local function getHumanoid()
            local character = getCharacter()
            return character and character:FindFirstChildOfClass("Humanoid")
        end

        state.MoveWrapper = function(self, movementVector, deltaTime)
            if not state.SpeedEnabled
                or typeof(movementVector) ~= "Vector3" then

                return state.OriginalMove(
                    self,
                    movementVector,
                    deltaTime
                )
            end

            return state.OriginalMove(
                self,
                movementVector * state.SpeedMultiplier,
                deltaTime
            )
        end

        state.JumpWrapper = function(self, ...)
            local result = state.OriginalJump(self, ...)

            if state.JumpEnabled
                and state.JumpMultiplier > 1.001 then

                local root = getRoot()
                local humanoid = getHumanoid()

                if root
                    and root:IsA("BasePart")
                    and humanoid then

                    local nativeImpulse =
                        math.max(
                            35,
                            math.clamp(
                                humanoid.WalkSpeed / 25,
                                0,
                                1.05
                            ) * 50
                        ) * 12

                    local extraMultiplier =
                        state.JumpMultiplier - 1

                    pcall(function()
                        root:ApplyImpulse(
                            Vector3.new(0, 1, 0)
                            * nativeImpulse
                            * extraMultiplier
                        )
                    end)
                end
            end

            return result
        end

        controller.Move = state.MoveWrapper
        controller.Jump = state.JumpWrapper

        state.Restore = function()
            state.SpeedEnabled = false
            state.JumpEnabled = false

            pcall(function()
                if state.Controller
                    and state.Controller.Move == state.MoveWrapper then

                    state.Controller.Move = state.OriginalMove
                end
            end)

            pcall(function()
                if state.Controller
                    and state.Controller.Jump == state.JumpWrapper then

                    state.Controller.Jump = state.OriginalJump
                end
            end)
        end

        rawset(_G, MOVEMENT_STATE_KEY, state)

        characterSection._Tab:CreateSlider({
            Name = "Movement Speed Multiplier",
            Flag = "Tower_Movement_SpeedMultiplier",
            Info = "Scales the game's native CharacterController movement request.",
            Range = {1.00, 3.00},
            Increment = 0.05,
            Suffix = "x",
            CurrentValue = 1.50,
            SectionParent = characterSection._Section,
            Callback = function(value)
                state.SpeedMultiplier =
                    math.clamp(
                        tonumber(value) or 1.50,
                        1.00,
                        3.00
                    )
            end
        })

        characterSection:AddToggle(
            "Enable Movement Speed",
            false,
            function(value)
                state.SpeedEnabled = value == true
            end
        )

        characterSection._Tab:CreateSlider({
            Name = "Jump Multiplier",
            Flag = "Tower_Movement_JumpMultiplier",
            Info = "Adds extra impulse after the game's normal CharacterController jump.",
            Range = {1.00, 2.50},
            Increment = 0.05,
            Suffix = "x",
            CurrentValue = 1.50,
            SectionParent = characterSection._Section,
            Callback = function(value)
                state.JumpMultiplier =
                    math.clamp(
                        tonumber(value) or 1.50,
                        1.00,
                        2.50
                    )
            end
        })

        characterSection:AddToggle(
            "Enable Jump Multiplier",
            false,
            function(value)
                state.JumpEnabled = value == true
            end
        )

        characterSection._Tab:CreateLabel(
            "Toggle OFF restores native behavior immediately; slider values stay saved.",
            characterSection._Section
        )
    end)

    -- ============================================================
    -- MAIN / TEAM HEALER
    -- ============================================================
    -- Keep this feature inside a nested closure so the already-large Tower
    -- module does not gain another large set of outer-scope locals.
    --
    -- Uses the game's native GameHealth:Heal(player, bodyPart) client path.
    -- The standalone test established the same-team/body-part logic; this hub
    -- version adds configuration-aware Auto Heal and immediate stop behavior.
    pcall(function()
        local teamHealerSection =
            CreateCategorySector(
                MainTab,
                "Team Healer",
                "Left",
                "only works if you're alive"
            )

        local TEAM_HEALER_STATE_KEY = "__VITALITY_TOWER_TEAM_HEALER"

        -- Re-execution cleanup: kill an older auto-heal loop before installing
        -- this copy so multiple executions can never stack heal workers.
        pcall(function()
            local oldState = rawget(_G, TEAM_HEALER_STATE_KEY)
            if type(oldState) == "table" and type(oldState.Stop) == "function" then
                oldState.Stop()
            end
            rawset(_G, TEAM_HEALER_STATE_KEY, nil)
        end)

        local localPlayer = Players.LocalPlayer
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local gameHealthModule = replicatedStorage:FindFirstChild("GameHealth")

        if not gameHealthModule or not gameHealthModule:IsA("ModuleScript") then
            MainTab:CreateLabel(
                "Team Healer unavailable: GameHealth was not found.",
                teamHealerSection._Section
            )
            return
        end

        local okGameHealth, gameHealth = pcall(require, gameHealthModule)
        if not okGameHealth or type(gameHealth) ~= "table" then
            MainTab:CreateLabel(
                "Team Healer unavailable: GameHealth could not be loaded.",
                teamHealerSection._Section
            )
            return
        end

        local bodyPartNames = {
            "Head",
            "Torso",
            "Left Arm",
            "Right Arm",
            "Left Leg",
            "Right Leg",
        }

        local state = {
            Enabled = false,
            RunId = 0,
            Busy = false,

            -- Prevent duplicate notification spam when HealthChanged replication
            -- trails slightly behind a successful heal request.
            LastHealNotification = setmetatable({}, {__mode = "k"}),
        }

        local function notify(message)
            pcall(function()
                Window:Notify({
                    Title = "TEAM HEALER",
                    Content = tostring(message),
                    Duration = 4,
                })
            end)
        end

        local function notifyHealedPlayer(player, healedEntries)
            if not player or type(healedEntries) ~= "table" or #healedEntries == 0 then
                return
            end

            local detailParts = {}
            local signatureParts = {}

            for _, entry in ipairs(healedEntries) do
                local damagedPercent = math.clamp(
                    math.floor(((1 - (entry.Health or 1)) * 100) + 0.5),
                    0,
                    100
                )

                table.insert(
                    detailParts,
                    string.format(
                        "%s %d%% damaged",
                        tostring(entry.Name),
                        damagedPercent
                    )
                )

                table.insert(
                    signatureParts,
                    tostring(entry.Name) .. ":" .. tostring(damagedPercent)
                )
            end

            local signature = table.concat(signatureParts, "|")
            local previous = state.LastHealNotification[player]
            local now = os.clock()

            -- If the local health mirror has not caught up yet, the same heal can
            -- appear injured again on the next 0.25s pass. Suppress an identical
            -- notification briefly without blocking genuinely new damage.
            if previous
                and previous.Signature == signature
                and now - previous.Time < 0.85 then

                return
            end

            state.LastHealNotification[player] = {
                Signature = signature,
                Time = now,
            }

            pcall(function()
                Window:Notify({
                    Title = "HEALED â€¢ " .. tostring(player.Name),
                    Content = table.concat(detailParts, "  â€¢  "),
                    Duration = 4.5,
                })
            end)
        end

        local function sameTeam(player)
            return player
                and player ~= localPlayer
                and localPlayer.Team ~= nil
                and player.Team == localPlayer.Team
        end

        local function getAliveCharacter(player)
            local character = player and player.Character
            if not character then
                return nil
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                return nil
            end

            return character
        end

        local function getHealthState(player)
            local ok, health = pcall(function()
                return gameHealth:GetHealth(player)
            end)

            if ok and type(health) == "table" then
                return health
            end

            return nil
        end

        local function getNormalizedPartHealth(healthState, partName)
            if type(healthState) ~= "table" then
                return nil
            end

            local value = tonumber(healthState[partName])
            if not value then
                return nil
            end

            return math.clamp(value, 0, 1)
        end

        local function getBodyPart(character, partName)
            if not character then
                return nil
            end

            local part = character:FindFirstChild(partName, true)
            if part and part:IsA("BasePart") then
                return part
            end

            return nil
        end

        local function healAllInjuredTeammates(runId, detailedNotifications)
            if state.Busy then
                return 0, 0
            end

            state.Busy = true

            local healedPlayers = 0
            local healedParts = 0

            for _, player in ipairs(Players:GetPlayers()) do
                -- Auto-heal OFF increments RunId. Abort the current pass as soon as
                -- that happens instead of finishing the rest of the teammate list.
                if runId and (not state.Enabled or runId ~= state.RunId) then
                    break
                end

                if sameTeam(player) then
                    local character = getAliveCharacter(player)
                    local healthState = character and getHealthState(player) or nil
                    local healedEntries = {}

                    if character and healthState then
                        for _, partName in ipairs(bodyPartNames) do
                            if runId and (not state.Enabled or runId ~= state.RunId) then
                                break
                            end

                            local normalized =
                                getNormalizedPartHealth(healthState, partName)

                            if normalized ~= nil and normalized < 0.999 then
                                local bodyPart = getBodyPart(character, partName)

                                if bodyPart then
                                    local ok = pcall(function()
                                        gameHealth:Heal(player, bodyPart)
                                    end)

                                    if ok then
                                        healedParts = healedParts + 1

                                        table.insert(healedEntries, {
                                            Name = partName,
                                            Health = normalized,
                                        })

                                        -- Give HealthChanged a moment to replicate so
                                        -- Auto Heal does not spam the same limb repeatedly.
                                        task.wait(0.04)
                                    end
                                end
                            end
                        end
                    end

                    if #healedEntries > 0 then
                        healedPlayers = healedPlayers + 1

                        if detailedNotifications ~= false then
                            notifyHealedPlayer(player, healedEntries)
                        end
                    end
                end
            end

            state.Busy = false
            return healedPlayers, healedParts
        end

        local function stopAutoHeal()
            state.Enabled = false
            state.RunId = state.RunId + 1
        end

        local function startAutoHeal()
            if state.Enabled then
                return
            end

            state.Enabled = true
            state.RunId = state.RunId + 1
            local runId = state.RunId

            task.spawn(function()
                while state.Enabled and runId == state.RunId do
                    healAllInjuredTeammates(runId, true)

                    if not state.Enabled or runId ~= state.RunId then
                        break
                    end

                    task.wait(0.25)
                end
            end)
        end

        state.Stop = stopAutoHeal
        rawset(_G, TEAM_HEALER_STATE_KEY, state)

        teamHealerSection:AddButton("Heal All Injured Teammates", function()
            task.spawn(function()
                local playersHealed, partsHealed =
                    healAllInjuredTeammates(nil, true)

                if partsHealed > 0 then
                    notify(
                        string.format(
                            "Heal pass complete: %d body part%s across %d teammate%s.",
                            partsHealed,
                            partsHealed == 1 and "" or "s",
                            playersHealed,
                            playersHealed == 1 and "" or "s"
                        )
                    )
                else
                    notify("No injured teammates were found.")
                end
            end)
        end)

        MainTab:CreateToggle({
            Name = "Auto Heal Teammates",
            CurrentValue = false,
            Flag = makeTowerFlag("Character", "Auto Heal Teammates"),
            SectionParent = teamHealerSection._Section,
            Callback = function(value)
                if value == true then
                    startAutoHeal()
                    notify("Auto Heal enabled.")
                else
                    -- This invalidates the active RunId as well as setting Enabled=false,
                    -- so toggling OFF stops both the recurring worker and any in-progress
                    -- auto-heal pass at its next body-part boundary.
                    stopAutoHeal()
                    notify("Auto Heal disabled.")
                end
            end,
        })

        MainTab:CreateLabel(
            "Uses the game's native teammate healing path. Heal notifications show each teammate, injured limb, and approximate damage percentage.",
            teamHealerSection._Section
        )
    end)


    -- ============================================================
    -- CHARACTER / SMART DESYNC
    -- ============================================================
    -- Keep the complete feature inside a nested closure so the very large
    -- Tower module does not gain additional outer-scope locals/registers.
    -- The implementation is the confirmed loot-aware Smart Desync v5 flow.
    pcall(function()
        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local CollectionService = game:GetService("CollectionService")
        local UserInputService = game:GetService("UserInputService")
        local ContextActionService = game:GetService("ContextActionService")
        local VirtualInputManager = game:GetService("VirtualInputManager")

        local LocalPlayer = Players.LocalPlayer

        local STATE_KEY =
            "__VITALITY_TOWER_SMART_DESYNC"

        local BURIAL_DEPTH = 35
        local GROUND_PROBE_UP = 8
        local GROUND_PROBE_DOWN = 500

        local SYNC_SETTLE_TIME = 0.30
        local SIMPLE_LOOT_SETTLE_TIME = 0.70
        local FLARE_SPAWN_TIMEOUT = 4.0
        local LOOT_SESSION_TIMEOUT = 10.0
        local POST_LOOT_SETTLE_TIME = 0.45
        local QE_ACTION_SETTLE_TIME = 0.42

        local INPUT_ACTION_NAME =
            "VitalitySmartDesync_FQE"

        -- ============================================================
        -- RE-EXECUTION CLEANUP
        -- ============================================================

        pcall(function()
            local old = rawget(_G, STATE_KEY)

            if type(old) == "table"
                and type(old.HardRestore) == "function" then

                old.HardRestore()
            end
        end)

        local State = {
            Connections = {},

            Enabled = false,
            Syncing = false,
            ReplayingInput = false,
            Busy = false,
            LootSessionActive = false,

            Character = nil,
            Humanoid = nil,
            Root = nil,

            LastSurfacePivot = nil,
            GroundPosition = nil,
            DesiredServerRootPosition = nil,
            DesiredOffset = nil,

            LocalWeldRemovals = 0,
            ReturnConnection = nil,

            LastAction = "none",
            ActionCount = 0,
            RewardsTaken = 0,

            SeenFlares = setmetatable({}, {
                __mode = "k"
            }),
        }

        rawset(_G, STATE_KEY, State)

        local function log(...)
            print(
                "[Vitality Tower Smart Desync]",
                ...
            )
        end

        local function warnLog(...)
            warn(
                "[Vitality Tower Smart Desync]",
                ...
            )
        end

        local function track(connection)
            if connection then
                table.insert(
                    State.Connections,
                    connection
                )
            end

            return connection
        end

        local function disconnect(connection)
            if connection then
                pcall(function()
                    connection:Disconnect()
                end)
            end
        end

        -- ============================================================
        -- THE TOWER REMOTES / MODULES
        -- ============================================================

        local CustomCharacterStates =
            ReplicatedStorage:WaitForChild(
                "CustomCharacterStates"
            )

        local ConnectedRemote =
            CustomCharacterStates:WaitForChild(
                "Connected"
            )

        local DisconnectRemote =
            CustomCharacterStates:WaitForChild(
                "Disconnect"
            )

        local CollectablesModule =
            require(
                ReplicatedStorage:WaitForChild(
                    "Collectables"
                )
            )

        local CollectablesFolder =
            ReplicatedStorage:WaitForChild(
                "Collectables"
            )

        local PickupCallback =
            CollectablesFolder:WaitForChild(
                "PickupCallback"
            )

        local InteractionFlareFolder =
            ReplicatedStorage:WaitForChild(
                "InteractionFlare"
            )

        local RewardsRemote =
            InteractionFlareFolder:WaitForChild(
                "Rewards"
            )

        local RequestTakeRemote =
            InteractionFlareFolder:WaitForChild(
                "RequestTake"
            )

        -- Loot classes already identified in our earlier Tower work.
        local LOOT_NAMES = {
            SafeKey = true,
            KeyUnlockable = true,

            AdvancedSafeKey = true,
            AirdropKey = true,

            CacheLow = true,
            CacheMedium = true,
            CacheLarge = true,

            SafeUnlockable = true,
            AdvancedSafeUnlockable = true,
            AirdropUnlockable = true,
        }

        local FLARE_LOOT_NAMES = {
            SafeUnlockable = true,
            AdvancedSafeUnlockable = true,
            AirdropUnlockable = true,
        }

        -- ============================================================
        -- CHARACTER HELPERS
        -- ============================================================

        local function getCharacter()
            local character =
                LocalPlayer.Character

            if not character then
                return nil
            end

            local humanoid =
                character:FindFirstChildOfClass(
                    "Humanoid"
                )

            local root =
                character:FindFirstChild(
                    "HumanoidRootPart"
                )

            if not humanoid
                or humanoid.Health <= 0
                or not root
                or not root:IsA("BasePart") then

                return nil
            end

            State.Character = character
            State.Humanoid = humanoid
            State.Root = root

            return character, humanoid, root
        end

        local function isServerStateWeld(instance)
            return instance
                and instance:IsA("Weld")
                and instance.Name
                    == "ServerStateWeld"
        end

        local function worldPosition(object)
            if not object then
                return nil
            end

            if object:IsA("BasePart") then
                return object.Position
            end

            if object:IsA("Model") then
                local ok, pivot =
                    pcall(function()
                        return object:GetPivot()
                    end)

                if ok and pivot then
                    return pivot.Position
                end
            end

            local part =
                object:FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )

            return part
                and part.Position
                or nil
        end

        local function distanceFromRoot(object)
            local root = State.Root
            local position =
                worldPosition(object)

            if not root
                or not position then

                return math.huge
            end

            return (
                root.Position
                - position
            ).Magnitude
        end

        -- ============================================================
        -- GROUND / BURIAL
        -- ============================================================

        local function findGroundBelow(
            character,
            root
        )
            local params =
                RaycastParams.new()

            params.FilterType =
                Enum.RaycastFilterType.Exclude

            params.FilterDescendantsInstances = {
                character,
            }

            params.IgnoreWater = false

            return workspace:Raycast(
                root.Position
                    + Vector3.new(
                        0,
                        GROUND_PROBE_UP,
                        0
                    ),

                Vector3.new(
                    0,
                    -(
                        GROUND_PROBE_UP
                        + GROUND_PROBE_DOWN
                    ),
                    0
                ),

                params
            )
        end

        local function calculateUndergroundOffset(
            character,
            root
        )
            local result =
                findGroundBelow(
                    character,
                    root
                )

            local groundPosition =
                result
                and result.Position
                or nil

            local desiredPosition

            if groundPosition then
                desiredPosition =
                    Vector3.new(
                        root.Position.X,
                        groundPosition.Y
                            - BURIAL_DEPTH,
                        root.Position.Z
                    )
            else
                desiredPosition =
                    root.Position
                    - Vector3.new(
                        0,
                        BURIAL_DEPTH + 10,
                        0
                    )

                warnLog(
                    "No ground found; using fallback."
                )
            end

            local localDelta =
                root.CFrame:VectorToObjectSpace(
                    desiredPosition
                        - root.Position
                )

            return
                CFrame.new(localDelta),
                groundPosition,
                desiredPosition
        end

        -- ============================================================
        -- LOCAL SERVER-WELD SUPPRESSION
        -- ============================================================

        local function removeLocalServerStateWeld(
            instance
        )
            if not State.Enabled
                or State.Syncing
                or not isServerStateWeld(instance) then

                return false
            end

            if not State.Character
                or not instance:IsDescendantOf(
                    State.Character
                ) then

                return false
            end

            local ok =
                pcall(function()
                    instance:Destroy()
                end)

            if ok then
                State.LocalWeldRemovals += 1
            end

            return ok
        end

        local function scanAndRemoveLocalWelds()
            if not State.Character then
                return
            end

            for _, descendant in ipairs(
                State.Character:GetDescendants()
            ) do
                if isServerStateWeld(
                    descendant
                ) then

                    removeLocalServerStateWeld(
                        descendant
                    )
                end
            end
        end

        -- ============================================================
        -- SHORT LOCAL POSITION HOLD
        -- ============================================================

        local function stopReturnWindow()
            disconnect(
                State.ReturnConnection
            )

            State.ReturnConnection = nil
        end

        local function runReturnWindow(
            pivot,
            seconds
        )
            stopReturnWindow()

            local character =
                State.Character

            if not character
                or not pivot then

                return
            end

            local deadline =
                os.clock()
                + (seconds or 0.65)

            State.ReturnConnection =
                RunService.RenderStepped:Connect(
                    function()
                        if not State.Enabled
                            or State.Syncing
                            or not character.Parent then

                            stopReturnWindow()
                            return
                        end

                        if os.clock()
                            >= deadline then

                            stopReturnWindow()
                            return
                        end

                        pcall(function()
                            character:PivotTo(
                                pivot
                            )
                        end)
                    end
                )
        end

        -- ============================================================
        -- BURY / SYNC
        -- ============================================================

        local function buryAtCurrentPosition()
            if not State.Enabled then
                return false
            end

            local character,
                humanoid,
                root =
                getCharacter()

            if not character then
                return false
            end

            local surfacePivot =
                character:GetPivot()

            local offset,
                groundPosition,
                desiredPosition =
                calculateUndergroundOffset(
                    character,
                    root
                )

            State.LastSurfacePivot =
                surfacePivot

            State.GroundPosition =
                groundPosition

            State.DesiredServerRootPosition =
                desiredPosition

            State.DesiredOffset =
                offset

            State.Syncing = false

            pcall(function()
                ConnectedRemote:FireServer(
                    root,
                    offset
                )
            end)

            task.spawn(function()
                local deadline =
                    os.clock() + 1.0

                repeat
                    if not State.Enabled
                        or State.Syncing then

                        return
                    end

                    scanAndRemoveLocalWelds()
                    task.wait()
                until os.clock() >= deadline
            end)

            task.wait(0.20)

            scanAndRemoveLocalWelds()

            runReturnWindow(
                surfacePivot,
                0.65
            )

            return true
        end

        local function wakeAtCurrentPosition()
            if not State.Enabled then
                return false
            end

            local character,
                humanoid =
                getCharacter()

            if not character then
                return false
            end

            stopReturnWindow()

            State.Syncing = true

            local currentPivot =
                character:GetPivot()

            pcall(function()
                DisconnectRemote:FireServer()
            end)

            pcall(function()
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true

                character:PivotTo(
                    currentPivot
                )
            end)

            task.wait(
                SYNC_SETTLE_TIME
            )

            pcall(function()
                character:PivotTo(
                    currentPivot
                )
            end)

            return true
        end

        -- ============================================================
        -- LOOT CONTEXT
        -- ============================================================

        local function nearestLootCollectable()
            local best = nil
            local bestDistance = math.huge

            local ok, collectables =
                pcall(function()
                    return CollectablesModule:
                        GetCollectables()
                end)

            if not ok
                or type(collectables)
                    ~= "table" then

                return nil
            end

            for object, description in pairs(
                collectables
            ) do
                if object
                    and object.Parent
                    and object:IsDescendantOf(
                        workspace
                    )
                    and LOOT_NAMES[
                        object.Name
                    ] then

                    local distance =
                        distanceFromRoot(
                            object
                        )

                    if distance <= 20
                        and distance
                            < bestDistance then

                        best = object
                        bestDistance =
                            distance
                    end
                end
            end

            return best, bestDistance
        end

        local function snapshotNearbyFlares()
            local snapshot = {}

            for _, flare in ipairs(
                CollectionService:GetTagged(
                    "InteractionFlare"
                )
            ) do
                if flare:IsA("BasePart")
                    and flare:IsDescendantOf(
                        workspace
                    ) then

                    snapshot[flare] = true
                end
            end

            return snapshot
        end

        local function bufferLength(value)
            if value == nil then
                return nil
            end

            local count = nil

            pcall(function()
                count =
                    buffer.len(value)
            end)

            return count
        end

        local function flareValidAndNear(flare)
            return flare
                and flare.Parent
                and flare:IsA("BasePart")
                and flare:IsDescendantOf(
                    workspace
                )
                and distanceFromRoot(flare)
                    <= 13
        end

        local function findRelevantFlare(
            beforeFlares,
            timeout
        )
            local deadline =
                os.clock()
                + (timeout
                    or FLARE_SPAWN_TIMEOUT)

            repeat
                if not State.Enabled
                    or not State.Syncing then

                    return nil
                end

                local newBest = nil
                local newDistance =
                    math.huge

                local oldBest = nil
                local oldDistance =
                    math.huge

                for _, flare in ipairs(
                    CollectionService:GetTagged(
                        "InteractionFlare"
                    )
                ) do
                    if flareValidAndNear(
                        flare
                    ) then

                        local distance =
                            distanceFromRoot(
                                flare
                            )

                        local isNew =
                            not beforeFlares
                            or not beforeFlares[
                                flare
                            ]

                        if isNew then
                            if distance
                                < newDistance then

                                newBest = flare
                                newDistance =
                                    distance
                            end
                        elseif distance
                            < oldDistance then

                            oldBest = flare
                            oldDistance =
                                distance
                        end
                    end
                end

                if newBest then
                    return newBest
                end

                if oldBest then
                    return oldBest
                end

                task.wait(0.05)
            until os.clock() >= deadline

            return nil
        end

        local function drainFlare(flare)
            if not flareValidAndNear(
                flare
            ) then

                return false
            end

            State.LootSessionActive =
                true

            State.SeenFlares[flare] =
                true

            local okRewards,
                rewardsBuffer =
                pcall(function()
                    return RewardsRemote:
                        InvokeServer(flare)
                end)

            if not okRewards
                or rewardsBuffer == false then

                State.LootSessionActive =
                    false

                return false
            end

            local initialCount =
                bufferLength(
                    rewardsBuffer
                )

            if initialCount ~= nil then
                log(
                    "Reward flare ready |",
                    initialCount,
                    "reward(s)"
                )
            else
                log("Reward flare ready.")
            end

            local deadline =
                os.clock()
                + LOOT_SESSION_TIMEOUT

            local tookAny = false

            repeat
                if not State.Enabled
                    or not State.Syncing then

                    State.LootSessionActive =
                        false

                    return false
                end

                if not flare.Parent then
                    State.LootSessionActive =
                        false

                    return tookAny
                end

                -- Do not re-bury simply because the user drifted slightly out of range
                -- during the reward sequence. Stay synced and allow them to step back.
                if distanceFromRoot(flare)
                    > 13 then

                    task.wait(0.05)
                    continue
                end

                local okTake,
                    remaining =
                    pcall(function()
                        return RequestTakeRemote:
                            InvokeServer(flare)
                    end)

                if okTake
                    and remaining ~= false
                    and remaining ~= nil then

                    tookAny = true
                    State.RewardsTaken += 1

                    local remainingCount =
                        bufferLength(
                            remaining
                        )

                    if remainingCount ~= nil then
                        log(
                            "Reward taken | remaining:",
                            remainingCount
                        )

                        if remainingCount == 0 then
                            task.wait(
                                POST_LOOT_SETTLE_TIME
                            )

                            State.LootSessionActive =
                                false

                            return true
                        end
                    else
                        task.wait(
                            POST_LOOT_SETTLE_TIME
                        )

                        State.LootSessionActive =
                            false

                        return true
                    end
                elseif okTake
                    and remaining == nil then

                    task.wait(0.05)

                    if not flare.Parent then
                        State.LootSessionActive =
                            false

                        return tookAny
                    end
                else
                    task.wait(0.08)
                end

                task.wait()
            until os.clock() >= deadline

            State.LootSessionActive =
                false

            return tookAny
        end

        local function finishFInteraction(
            targetBeforeF,
            beforeFlares
        )
            State.LootSessionActive =
                true

            local expectsFlare =
                targetBeforeF
                and FLARE_LOOT_NAMES[
                    targetBeforeF.Name
                ] == true

            if expectsFlare then
                log(
                    "Waiting for",
                    targetBeforeF.Name,
                    "loot..."
                )

                local flare =
                    findRelevantFlare(
                        beforeFlares,
                        FLARE_SPAWN_TIMEOUT
                    )

                if flare then
                    local drained =
                        drainFlare(flare)

                    if drained then
                        log(
                            "All flare loot taken."
                        )
                    else
                        warnLog(
                            "Flare loot did not report full completion."
                        )
                    end
                else
                    warnLog(
                        "No reward flare appeared before timeout."
                    )
                end
            else
                -- Keys / caches / ordinary F interaction:
                -- stay synchronized through native PickupCallback bookkeeping.
                task.wait(
                    SIMPLE_LOOT_SETTLE_TIME
                )

                -- If that interaction created a flare anyway, finish it before re-bury.
                local flare =
                    findRelevantFlare(
                        beforeFlares,
                        0.20
                    )

                if flare then
                    drainFlare(flare)
                end
            end

            State.LootSessionActive =
                false
        end

        -- ============================================================
        -- NATIVE KEY REPLAY
        -- ============================================================

        local function replayKey(
            keyCode,
            holdTime
        )
            State.ReplayingInput =
                true

            task.wait(0.025)

            local ok, err =
                pcall(function()
                    VirtualInputManager:
                        SendKeyEvent(
                            true,
                            keyCode,
                            false,
                            game
                        )

                    task.wait(
                        holdTime
                        or 0.075
                    )

                    VirtualInputManager:
                        SendKeyEvent(
                            false,
                            keyCode,
                            false,
                            game
                        )
                end)

            task.wait(0.025)

            State.ReplayingInput =
                false

            if not ok then
                warnLog(
                    "Key replay failed:",
                    keyCode.Name,
                    err
                )
            end
        end

        -- ============================================================
        -- SMART ACTION
        -- ============================================================

        local function performSmartAction(
            keyCode
        )
            if not State.Enabled then
                replayKey(keyCode)
                return
            end

            if State.Busy then
                warnLog(
                    "Ignored overlapping action:",
                    keyCode.Name
                )

                return
            end

            State.Busy = true

            task.spawn(function()
                local targetBeforeF = nil
                local beforeFlares = nil

                if keyCode
                    == Enum.KeyCode.F then

                    targetBeforeF =
                        nearestLootCollectable()

                    beforeFlares =
                        snapshotNearbyFlares()
                end

                if not wakeAtCurrentPosition() then
                    State.Syncing = false
                    State.Busy = false
                    return
                end

                State.LastAction =
                    keyCode.Name

                State.ActionCount += 1

                log(
                    "Synced for",
                    keyCode.Name,
                    "| action #",
                    State.ActionCount
                )

                replayKey(
                    keyCode,
                    keyCode
                        == Enum.KeyCode.F
                        and 0.09
                        or 0.065
                )

                if keyCode
                    == Enum.KeyCode.F then

                    finishFInteraction(
                        targetBeforeF,
                        beforeFlares
                    )
                else
                    task.wait(
                        QE_ACTION_SETTLE_TIME
                    )
                end

                -- ONLY now can protection return.
                State.Syncing = false

                if State.Enabled then
                    buryAtCurrentPosition()
                end

                State.Busy = false

                log(
                    keyCode.Name,
                    "complete; protection restored."
                )
            end)
        end

        -- ============================================================
        -- HIGH-PRIORITY F / Q / E INPUT
        -- ============================================================

        local function protectedInputAction(
            actionName,
            inputState,
            inputObject
        )
            if not State.Enabled then
                return
                    Enum.ContextActionResult.Pass
            end

            -- Our synthetic replay must reach the game's own handlers.
            if State.ReplayingInput then
                return
                    Enum.ContextActionResult.Pass
            end

            local keyCode =
                inputObject.KeyCode

            -- While a loot session is already fully synced, ordinary F presses are
            -- allowed straight through. This means if the game presents another loot
            -- step/UI while we're waiting, the user can keep taking it naturally.
            if State.LootSessionActive
                and State.Syncing
                and keyCode
                    == Enum.KeyCode.F then

                return
                    Enum.ContextActionResult.Pass
            end

            if keyCode
                    ~= Enum.KeyCode.F
                and keyCode
                    ~= Enum.KeyCode.Q
                and keyCode
                    ~= Enum.KeyCode.E then

                return
                    Enum.ContextActionResult.Pass
            end

            if inputState
                == Enum.UserInputState.Begin then

                performSmartAction(
                    keyCode
                )
            end

            -- Physical F/Q/E is blocked. The game only receives our replay after sync.
            return
                Enum.ContextActionResult.Sink
        end

        local function bindProtectedInputs()
            pcall(function()
                ContextActionService:
                    UnbindAction(
                        INPUT_ACTION_NAME
                    )
            end)

            ContextActionService:
                BindActionAtPriority(
                    INPUT_ACTION_NAME,
                    protectedInputAction,
                    false,
                    10000,
                    Enum.KeyCode.F,
                    Enum.KeyCode.Q,
                    Enum.KeyCode.E
                )
        end

        local function unbindProtectedInputs()
            pcall(function()
                ContextActionService:
                    UnbindAction(
                        INPUT_ACTION_NAME
                    )
            end)
        end

        -- ============================================================
        -- BACKGROUND FLARE COMPLETION
        -- ============================================================
        -- Covers a reward flare created through another loot path while protection is
        -- active. If we are currently buried and a new nearby flare appears, wake,
        -- drain the complete reward buffer, then re-bury.

        local function handleExternalFlare(flare)
            if not State.Enabled
                or State.Busy
                or State.Syncing
                or State.SeenFlares[flare] then

                return
            end

            task.delay(0.05, function()
                if not State.Enabled
                    or State.Busy
                    or State.Syncing
                    or State.SeenFlares[flare]
                    or not flareValidAndNear(
                        flare
                    ) then

                    return
                end

                State.Busy = true

                task.spawn(function()
                    if wakeAtCurrentPosition() then
                        State.LootSessionActive =
                            true

                        drainFlare(flare)

                        State.LootSessionActive =
                            false

                        State.Syncing = false

                        if State.Enabled then
                            buryAtCurrentPosition()
                        end
                    end

                    State.Busy = false
                end)
            end)
        end

        -- ============================================================
        -- ENABLE / RESTORE
        -- ============================================================

        local function enableProtection()
            if State.Enabled then
                return
            end

            if not getCharacter() then
                warnLog(
                    "Living character unavailable."
                )

                return
            end

            State.Enabled = true
            State.Syncing = false
            State.ReplayingInput = false
            State.Busy = false
            State.LootSessionActive = false

            State.LocalWeldRemovals = 0
            State.LastAction = "none"
            State.ActionCount = 0
            State.RewardsTaken = 0

            bindProtectedInputs()

            task.spawn(
                buryAtCurrentPosition
            )

            log(
                "Protection ON.",
                "Loot-aware F/Q/E enabled."
            )
        end

        local function fullRestore()
            stopReturnWindow()
            unbindProtectedInputs()

            State.Busy = false
            State.LootSessionActive = false
            State.Syncing = true

            pcall(function()
                DisconnectRemote:FireServer()
            end)

            task.wait(0.18)

            local _,
                humanoid =
                getCharacter()

            if humanoid then
                pcall(function()
                    humanoid.PlatformStand =
                        false

                    humanoid.AutoRotate =
                        true
                end)
            end

            State.Enabled = false
            State.Syncing = false
            State.ReplayingInput = false

            log(
                "Protection OFF / restored."
            )
        end

        local function toggleProtection()
            if State.Enabled then
                task.spawn(
                    fullRestore
                )
            else
                enableProtection()
            end
        end

        -- ============================================================
        -- DIAGNOSTICS
        -- ============================================================

        local function printDiagnostics()
            local character,
                humanoid,
                root =
                getCharacter()

            print(
                "===================================================="
            )

            print(
                "[Vitality Tower Smart Desync]"
            )

            print(
                "Enabled:",
                State.Enabled
            )

            print(
                "Syncing:",
                State.Syncing
            )

            print(
                "Busy:",
                State.Busy
            )

            print(
                "LootSessionActive:",
                State.LootSessionActive
            )

            print(
                "LastAction:",
                State.LastAction
            )

            print(
                "ActionCount:",
                State.ActionCount
            )

            print(
                "RewardsTaken:",
                State.RewardsTaken
            )

            print(
                "Local weld removals:",
                State.LocalWeldRemovals
            )

            print(
                "PickupCallback:",
                PickupCallback:GetFullName()
            )

            print(
                "RewardsRemote:",
                RewardsRemote:GetFullName()
            )

            print(
                "RequestTakeRemote:",
                RequestTakeRemote:GetFullName()
            )

            if character then
                print(
                    "Local root:",
                    root.Position
                )

                print(
                    "PlatformStand:",
                    humanoid.PlatformStand
                )

                if State.DesiredServerRootPosition then
                    print(
                        "Intended buried body:",
                        State.DesiredServerRootPosition
                    )

                    print(
                        "Current separation:",
                        (
                            root.Position
                            - State.DesiredServerRootPosition
                        ).Magnitude
                    )
                end
            end

            print(
                "===================================================="
            )
        end

        -- ============================================================
        -- LIVE WELD / FLARE WATCHERS
        -- ============================================================

        track(
            workspace.DescendantAdded:
                Connect(function(instance)
                    if not State.Enabled
                        or State.Syncing
                        or not isServerStateWeld(
                            instance
                        ) then

                        return
                    end

                    task.defer(function()
                        if State.Enabled
                            and not State.Syncing then

                            removeLocalServerStateWeld(
                                instance
                            )
                        end
                    end)
                end)
        )

        track(
            CollectionService:
                GetInstanceAddedSignal(
                    "InteractionFlare"
                ):
                Connect(function(flare)
                    handleExternalFlare(
                        flare
                    )
                end)
        )

        -- ============================================================
        -- RESPAWN SAFETY
        -- ============================================================

        track(
            LocalPlayer.CharacterAdded:
                Connect(function()
                    local shouldResume =
                        State.Enabled == true

                    stopReturnWindow()
                    unbindProtectedInputs()

                    State.Syncing = false
                    State.ReplayingInput = false
                    State.Busy = false
                    State.LootSessionActive = false

                    State.Character = nil
                    State.Humanoid = nil
                    State.Root = nil

                    State.LastSurfacePivot = nil
                    State.GroundPosition = nil
                    State.DesiredServerRootPosition = nil
                    State.DesiredOffset = nil

                    if shouldResume then
                        task.delay(1, function()
                            if rawget(_G, STATE_KEY) ~= State
                                or not State.Enabled then

                                return
                            end

                            if getCharacter() then
                                bindProtectedInputs()
                                task.spawn(
                                    buryAtCurrentPosition
                                )
                            end
                        end)
                    end
                end)
        )

        -- ============================================================
        -- HARD RESTORE / UNLOAD
        -- ============================================================

        function State.HardRestore()
            pcall(
                fullRestore
            )

            stopReturnWindow()
            unbindProtectedInputs()

            for _, connection in ipairs(
                State.Connections
            ) do
                disconnect(connection)
            end

            table.clear(
                State.Connections
            )

            if rawget(_G, STATE_KEY)
                == State then

                rawset(
                    _G,
                    STATE_KEY,
                    nil
                )
            end

            log(
                "Restored and unloaded."
            )
        end


        -- ============================================================
        -- VITALITY HUB TOGGLE
        -- ============================================================

        State.Restore = fullRestore
        State.SetEnabled = function(value)
            if value == true then
                enableProtection()
            else
                fullRestore()
            end
        end

        characterSection:AddToggle("Smart Desync", false, function(value)
            State.SetEnabled(value == true)
        end)
    end)


    -- ============================================================
    -- SNIPER / NATIVE SILENT AIM
    -- ============================================================
    -- This uses the SAME native projectile path that succeeded in the isolated
    -- test: ProjectileData.<ammo>:NewProjectile(). We do not fabricate
    -- EndProjectile and we do not create a second projectile.
    --
    -- Instead, when the game creates the local shooter's legitimate sniper
    -- projectile, the wrapper substitutes an origin immediately outside the
    -- selected target hitbox and a direction through its center. The game's own:
    --
    --   NewProjectile -> HandleClient -> CreateProjectile -> raycast
    --                 -> HandleCollision -> EndProjectile
    --
    -- pipeline remains responsible for the projectile ID, collision, and damage.
    --
    -- IMPORTANT: Keep this whole feature inside a nested closure. The Tower
    -- module is already very large and adding many outer-scope locals previously
    -- caused versions to stop compiling/executing.
    pcall(function()
        local sniperTab = Window:CreateTab("Sniper", "sniper")
        local silentAimSection = CreateCategorySector(sniperTab, "Silent Aim")

        local localPlayer = Players.LocalPlayer
        local replicatedStorage = game:GetService("ReplicatedStorage")

        local projectileDataModule = replicatedStorage:FindFirstChild("ProjectileData")
        if not projectileDataModule or not projectileDataModule:IsA("ModuleScript") then
            sniperTab:CreateLabel(
                "Silent Aim unavailable: ProjectileData was not found.",
                silentAimSection._Section
            )
            return
        end

        local okProjectileData, projectileData = pcall(require, projectileDataModule)
        if not okProjectileData or type(projectileData) ~= "table" then
            sniperTab:CreateLabel(
                "Silent Aim unavailable: ProjectileData could not be loaded.",
                silentAimSection._Section
            )
            return
        end

        local state = {
            Enabled = false,
            FovRadius = 175,
            TeamCheck = true,
            VisibilityCheck = false,
            TargetMode = "Torso",
            ShowFov = false,
            FovGui = nil,
            FovCircle = nil,
            Hooks = {},
        }

        local stateKey = "__VITALITY_TOWER_SILENT_AIM"

        -- These are the sniper ammunition projectile definitions found in
        -- ReplicatedStorage.ProjectileData. Grenade/flare/pistol definitions are
        -- intentionally excluded so Silent Aim cannot redirect unrelated weapons.
        local sniperProjectileNames = {
            "Standard",
            "Antimaterial",
            "Antimaterial_slow",
            "Antipersonal",
            "Swift",
            "Nato",
            "Winchester",
            "Supressed",
            "Longrifle",
            "XSS",
            "Creedmoor",
            "ACP",
            "MG61",
            "B60",
            "Dev",
            "SHOTGUN",
        }

        local function getPreferredTargetPart(character)
            if not character then
                return nil
            end

            if state.TargetMode == "Head" then
                return character:FindFirstChild("Head")
                    or character:FindFirstChild("UpperTorso")
                    or character:FindFirstChild("Torso")
                    or character:FindFirstChild("HumanoidRootPart")
            elseif state.TargetMode == "Root" then
                return character:FindFirstChild("HumanoidRootPart")
                    or character:FindFirstChild("UpperTorso")
                    or character:FindFirstChild("Torso")
                    or character:FindFirstChild("Head")
            end

            -- "Torso" is the reliability-first default that worked in the
            -- successful isolated native-projectile test.
            return character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("Torso")
                or character:FindFirstChild("HumanoidRootPart")
                or character:FindFirstChild("Head")
        end

        local function characterIsAlive(character)
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            return humanoid ~= nil and humanoid.Health > 0
        end

        local function isCharacterVisible(character, targetPart)
            local camera = workspace.CurrentCamera
            if not camera or not character or not character.Parent then
                return false
            end

            targetPart = targetPart or getPreferredTargetPart(character)
            if not targetPart or not targetPart:IsA("BasePart") then
                return false
            end

            local origin = camera.CFrame.Position
            local direction = targetPart.Position - origin

            if direction.Magnitude <= 0.001 then
                return true
            end

            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude

            local localCharacter = localPlayer.Character
            if localCharacter then
                params.FilterDescendantsInstances = {localCharacter}
            else
                params.FilterDescendantsInstances = {}
            end

            params.IgnoreWater = false

            local result = workspace:Raycast(
                origin,
                direction,
                params
            )

            if not result then
                return true
            end

            return result.Instance ~= nil
                and result.Instance:IsDescendantOf(character)
        end

        state.IsCharacterVisible = isCharacterVisible

        local function getClosestFovTarget()
            local camera = workspace.CurrentCamera
            if not camera then
                return nil
            end

            local viewport = camera.ViewportSize
            local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
            local bestTarget = nil
            local bestDistance = state.FovRadius

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    local sameTeam =
                        localPlayer.Team ~= nil
                        and player.Team ~= nil
                        and player.Team == localPlayer.Team

                    if not state.TeamCheck or not sameTeam then
                        local character = player.Character
                        local targetPart = getPreferredTargetPart(character)

                        if targetPart and targetPart:IsA("BasePart") and characterIsAlive(character) then
                            local screenPoint, onScreen =
                                camera:WorldToViewportPoint(targetPart.Position)

                            if onScreen and screenPoint.Z > 0 then
                                local screenDistance = (
                                    Vector2.new(screenPoint.X, screenPoint.Y) - center
                                ).Magnitude

                                local visible =
                                    not state.VisibilityCheck
                                    or isCharacterVisible(
                                        character,
                                        targetPart
                                    )

                                if visible
                                    and screenDistance <= bestDistance then

                                    bestDistance = screenDistance
                                    bestTarget = {
                                        Player = player,
                                        Character = character,
                                        Part = targetPart,
                                        ScreenDistance = screenDistance,
                                    }
                                end
                            end
                        end
                    end
                end
            end

            return bestTarget
        end

        -- Distance from the center of an oriented Roblox box to its surface in
        -- the supplied WORLD-space direction. This is the exact geometry approach
        -- used by the successful native-projectile test.
        local function distanceToBoxSurface(part, worldDirection)
            local localDirection = part.CFrame:VectorToObjectSpace(worldDirection)
            if localDirection.Magnitude <= 0.0001 then
                return nil
            end

            localDirection = localDirection.Unit

            local half = part.Size * 0.5
            local best = math.huge

            if math.abs(localDirection.X) > 0.0001 then
                best = math.min(best, half.X / math.abs(localDirection.X))
            end

            if math.abs(localDirection.Y) > 0.0001 then
                best = math.min(best, half.Y / math.abs(localDirection.Y))
            end

            if math.abs(localDirection.Z) > 0.0001 then
                best = math.min(best, half.Z / math.abs(localDirection.Z))
            end

            return best ~= math.huge and best or nil
        end

        local function buildSilentAimShot(targetPart)
            local camera = workspace.CurrentCamera
            if not camera or not targetPart then
                return nil, nil
            end

            local toTarget = targetPart.Position - camera.CFrame.Position
            if toTarget.Magnitude <= 0.001 then
                return nil, nil
            end

            local direction = toTarget.Unit
            local surfaceDistance = distanceToBoxSurface(targetPart, -direction)
            if not surfaceDistance then
                return nil, nil
            end

            -- The v3 test succeeded with a projectile starting 0.20 studs outside
            -- the near-facing hitbox surface and traveling through the center.
            local origin =
                targetPart.Position
                - direction * (surfaceDistance + 0.20)

            return origin, direction
        end

        local function shouldRedirect(owner)
            if state.Enabled ~= true then
                return false
            end

            -- Projectile.NewProjectile defaults nil owner to LocalPlayer, so nil
            -- is a legitimate local-shot call pattern.
            local effectiveOwner = owner or localPlayer
            if effectiveOwner ~= localPlayer then
                return false
            end

            -- Keep this isolated to actual Sniper gameplay.
            if localPlayer.Team and localPlayer.Team.Name ~= "Sniper" then
                return false
            end

            return true
        end

        -- Restore any wrappers from an earlier copy before installing ours.
        pcall(function()
            local previous = rawget(_G, stateKey)
            if type(previous) == "table" and type(previous.Restore) == "function" then
                previous.Restore()
            end
        end)

        for _, projectileName in ipairs(sniperProjectileNames) do
            local projectileDefinition = projectileData[projectileName]

            if type(projectileDefinition) == "table"
                and type(projectileDefinition.NewProjectile) == "function" then

                local originalNewProjectile = projectileDefinition.NewProjectile
                local wrapper

                wrapper = function(self, originalOrigin, originalDirection, owner)
                    if shouldRedirect(owner) then
                        local target = getClosestFovTarget()

                        if target and target.Part and target.Part.Parent then
                            local silentOrigin, silentDirection =
                                buildSilentAimShot(target.Part)

                            if silentOrigin and silentDirection then
                                return originalNewProjectile(
                                    self,
                                    silentOrigin,
                                    silentDirection,
                                    owner
                                )
                            end
                        end
                    end

                    -- No target in FOV, disabled, or any targeting failure:
                    -- preserve the game's completely normal projectile.
                    return originalNewProjectile(
                        self,
                        originalOrigin,
                        originalDirection,
                        owner
                    )
                end

                projectileDefinition.NewProjectile = wrapper

                table.insert(state.Hooks, {
                    Definition = projectileDefinition,
                    Original = originalNewProjectile,
                    Wrapper = wrapper,
                })
            end
        end

        local function destroyFovCircle()
            if state.FovGui then
                pcall(function()
                    state.FovGui:Destroy()
                end)
            end

            state.FovGui = nil
            state.FovCircle = nil
        end

        local function updateFovCircle()
            if not state.ShowFov then
                if state.FovCircle then
                    state.FovCircle.Visible = false
                end
                return
            end

            if not state.FovGui or not state.FovGui.Parent then
                local gui = Instance.new("ScreenGui")
                gui.Name = "TheTower_SilentAimFOV"
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.DisplayOrder = 250
                gui.Parent = CoreGui

                local circle = Instance.new("Frame")
                circle.Name = "Circle"
                circle.AnchorPoint = Vector2.new(0.5, 0.5)
                circle.Position = UDim2.fromScale(0.5, 0.5)
                circle.BackgroundTransparency = 1
                circle.BorderSizePixel = 0
                circle.Parent = gui

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(1, 0)
                corner.Parent = circle

                local stroke = Instance.new("UIStroke")
                stroke.Name = "Stroke"
                stroke.Thickness = 1.5
                stroke.Transparency = 0.15
                stroke.Color = Theme and Theme.Text or Color3.new(1, 1, 1)
                stroke.Parent = circle

                state.FovGui = gui
                state.FovCircle = circle
            end

            if state.FovCircle then
                local diameter = math.max(2, state.FovRadius * 2)
                state.FovCircle.Size = UDim2.fromOffset(diameter, diameter)
                state.FovCircle.Position = UDim2.fromScale(0.5, 0.5)
                state.FovCircle.Visible = true
            end
        end

        state.Restore = function()
            state.Enabled = false
            state.VisibilityCheck = false
            state.ShowFov = false
            destroyFovCircle()

            for _, hook in ipairs(state.Hooks) do
                pcall(function()
                    if hook.Definition
                        and hook.Definition.NewProjectile == hook.Wrapper then

                        hook.Definition.NewProjectile = hook.Original
                    end
                end)
            end
        end

        rawset(_G, stateKey, state)

        silentAimSection:AddToggle("Silent Aim", false, function(value)
            state.Enabled = value == true
        end)

        sniperTab:CreateSlider({
            Name = "FOV Radius",
            Flag = "Tower_SilentAim_FOV",
            Info = "Screen-space targeting radius around the center of your scope.",
            Range = {25, 500},
            Increment = 5,
            Suffix = " px",
            CurrentValue = 175,
            SectionParent = silentAimSection._Section,
            Callback = function(value)
                state.FovRadius = math.clamp(tonumber(value) or 175, 25, 500)
                updateFovCircle()
            end
        })

        silentAimSection:AddToggle("Show FOV Circle", false, function(value)
            state.ShowFov = value == true
            updateFovCircle()
        end)

        silentAimSection:AddDropdown(
            "Target Part",
            {"Torso", "Head", "Root"},
            "Torso",
            false,
            function(value)
                if type(value) == "table" then
                    value = value[1]
                end

                value = tostring(value or "Torso")
                if value == "Head" or value == "Root" then
                    state.TargetMode = value
                else
                    state.TargetMode = "Torso"
                end
            end
        )

        silentAimSection:AddToggle("Team Check", true, function(value)
            state.TeamCheck = value == true
        end)

        silentAimSection:AddToggle("Visibility Check", false, function(value)
            state.VisibilityCheck = value == true
        end)

        sniperTab:CreateLabel(
            "Uses the game's native projectile simulation. If no valid player is inside the FOV, the shot remains completely normal.",
            silentAimSection._Section
        )

        -- ========================================================
        -- SNIPER / CAMERA EFFECTS
        -- ========================================================
        -- Built only from the game modules already supplied:
        --
        --   SniperInstance.apply_recoil:
        --       RECOIL_BOOST / HEAVY_RECOIL_BOOST
        --       Turret.SniperRecoilMultiplier
        --       DOF_BOOST
        --
        --   TPS:
        --       GameHealth.OnConcussion
        --       Projectile.Supressed
        --
        --   GameHealth:
        --       AddClientConfusion / GetClientConfusion
        --
        -- Keep this feature in another nested closure so none of its working
        -- locals add pressure to TheTowerModule or the existing silent-aim
        -- closure.
        pcall(function()
            local cameraEffectsSection =
                CreateCategorySector(
                    sniperTab,
                    "Camera Effects"
                )

            local EFFECT_STATE_KEY =
                "__VITALITY_TOWER_SNIPER_EFFECTS"

            -- Restore an older copy if this nested block is rebuilt by itself.
            pcall(function()
                local previous =
                    rawget(
                        _G,
                        EFFECT_STATE_KEY
                    )

                if type(previous) == "table"
                    and type(previous.RestoreAll)
                        == "function" then

                    previous.RestoreAll()
                end
            end)

            local effectState = {
                AntiRecoil = false,
                NoRecoilBlur = false,
                NoConfusion = false,

                DisabledConnections = {
                    Concussion = {},
                    Suppression = {},
                },

                DescriptionOriginals =
                    setmetatable(
                        {},
                        {__mode = "k"}
                    ),

                PatchRunId = 0,

                Ammunitions = nil,
                Turret = nil,
                GameHealth = nil,
                Projectile = nil,

                OriginalRecoilMultiplier = nil,
                RecoilMultiplierWasNil = false,

                OriginalAddClientConfusion = nil,
                ConfusionWrapper = nil,
            }

            rawset(
                _G,
                EFFECT_STATE_KEY,
                effectState
            )

            local function notifyEffect(
                message,
                kind
            )
                pcall(function()
                    Window:Notify({
                        Title =
                            kind == "failed"
                            and "Sniper â€¢ Failed"
                            or "Sniper",
                        Content =
                            tostring(message),
                        Duration = 4,
                        Type = kind,
                    })
                end)
            end

            local function tryRequire(
                object
            )
                if not object
                    or not object:IsA(
                        "ModuleScript"
                    ) then

                    return nil
                end

                local ok, result =
                    pcall(
                        require,
                        object
                    )

                if ok then
                    return result
                end

                return nil
            end

            effectState.Ammunitions =
                tryRequire(
                    replicatedStorage:
                        FindFirstChild(
                            "Ammunitions"
                        )
                )

            effectState.Turret =
                tryRequire(
                    replicatedStorage:
                        FindFirstChild(
                            "Turret"
                        )
                )

            effectState.GameHealth =
                tryRequire(
                    replicatedStorage:
                        FindFirstChild(
                            "GameHealth"
                        )
                )

            effectState.Projectile =
                tryRequire(
                    replicatedStorage:
                        FindFirstChild(
                            "Projectile"
                        )
                )

            -- ----------------------------------------------------
            -- RECOIL DESCRIPTION PATCHING
            -- ----------------------------------------------------
            -- SniperInstance stores the ammunition description table in v2 and
            -- reads these fields every time apply_recoil runs. Remember each
            -- table's real values once, then derive the live patched values
            -- from the current toggle state.
            local function rememberDescription(
                description
            )
                if type(description)
                    ~= "table" then

                    return nil
                end

                local record =
                    effectState
                        .DescriptionOriginals[
                            description
                        ]

                if record then
                    return record
                end

                record = {
                    Recoil = {
                        WasNil =
                            description
                                .RECOIL_BOOST
                                == nil,
                        Value =
                            description
                                .RECOIL_BOOST,
                    },

                    Heavy = {
                        WasNil =
                            description
                                .HEAVY_RECOIL_BOOST
                                == nil,
                        Value =
                            description
                                .HEAVY_RECOIL_BOOST,
                    },

                    Dof = {
                        WasNil =
                            description
                                .DOF_BOOST
                                == nil,
                        Value =
                            description
                                .DOF_BOOST,
                    },
                }

                effectState
                    .DescriptionOriginals[
                        description
                    ] =
                    record

                return record
            end

            local function restoreField(
                object,
                key,
                saved
            )
                if not object
                    or type(saved)
                        ~= "table" then

                    return
                end

                if saved.WasNil then
                    object[key] = nil
                else
                    object[key] =
                        saved.Value
                end
            end

            local function applyDescriptionState(
                description
            )
                local saved =
                    rememberDescription(
                        description
                    )

                if not saved then
                    return false
                end

                -- Always begin from the game's real values so turning one
                -- effect off cannot leave another stale patch behind.
                restoreField(
                    description,
                    "RECOIL_BOOST",
                    saved.Recoil
                )

                restoreField(
                    description,
                    "HEAVY_RECOIL_BOOST",
                    saved.Heavy
                )

                restoreField(
                    description,
                    "DOF_BOOST",
                    saved.Dof
                )

                if effectState.AntiRecoil then
                    description.RECOIL_BOOST =
                        0

                    description
                        .HEAVY_RECOIL_BOOST =
                        0
                end

                if effectState.NoRecoilBlur then
                    description.DOF_BOOST =
                        0
                end

                return true
            end

            local function getCurrentDescription()
                local ammunitions =
                    effectState.Ammunitions

                local turret =
                    effectState.Turret

                if type(ammunitions)
                        ~= "table"
                    or type(
                        ammunitions.Get
                    ) ~= "function"
                    or type(turret)
                        ~= "table" then

                    return nil
                end

                local okAmmo,
                    ammoObject =
                    pcall(
                        ammunitions.Get,
                        ammunitions,
                        turret.AmmunitionId
                            or 1
                    )

                if not okAmmo
                    or type(ammoObject)
                        ~= "table"
                    or type(
                        ammoObject
                            .GetDescription
                    ) ~= "function" then

                    return nil
                end

                local okDescription,
                    description =
                    pcall(
                        ammoObject
                            .GetDescription,
                        ammoObject
                    )

                if okDescription
                    and type(description)
                        == "table" then

                    return description
                end

                return nil
            end

            local function applyCurrentRecoilState()
                local description =
                    getCurrentDescription()

                if description then
                    applyDescriptionState(
                        description
                    )
                end

                local turret =
                    effectState.Turret

                if type(turret)
                    == "table" then

                    if effectState
                        .OriginalRecoilMultiplier
                        == nil
                        and not effectState
                            .RecoilMultiplierWasNil then

                        if turret
                            .SniperRecoilMultiplier
                            == nil then

                            effectState
                                .RecoilMultiplierWasNil =
                                true
                        else
                            effectState
                                .OriginalRecoilMultiplier =
                                turret
                                    .SniperRecoilMultiplier
                        end
                    end

                    if effectState.AntiRecoil then
                        -- SniperInstance calculates:
                        --
                        -- math.map(multiplier, 1, 2, 1, 0.3)
                        --
                        -- 17/7 maps to zero. That makes every recoil spring
                        -- multiplied by v22 receive zero while keeping the
                        -- game's normal OnSniperFire callback, bolt sounds,
                        -- bolt animation, and projectile logic intact.
                        turret.SniperRecoilMultiplier =
                            17 / 7
                    else
                        if effectState
                            .RecoilMultiplierWasNil then

                            turret
                                .SniperRecoilMultiplier =
                                nil
                        elseif effectState
                            .OriginalRecoilMultiplier
                            ~= nil then

                            turret
                                .SniperRecoilMultiplier =
                                effectState
                                    .OriginalRecoilMultiplier
                        end
                    end
                end
            end

            local function restoreDescriptions()
                for description,
                    saved in pairs(
                        effectState
                            .DescriptionOriginals
                    ) do

                    if type(description)
                        == "table" then

                        restoreField(
                            description,
                            "RECOIL_BOOST",
                            saved.Recoil
                        )

                        restoreField(
                            description,
                            "HEAVY_RECOIL_BOOST",
                            saved.Heavy
                        )

                        restoreField(
                            description,
                            "DOF_BOOST",
                            saved.Dof
                        )
                    end
                end

                local turret =
                    effectState.Turret

                if type(turret)
                    == "table" then

                    if effectState
                        .RecoilMultiplierWasNil then

                        turret.SniperRecoilMultiplier =
                            nil

                    elseif effectState
                        .OriginalRecoilMultiplier
                        ~= nil then

                        turret.SniperRecoilMultiplier =
                            effectState
                                .OriginalRecoilMultiplier
                    end
                end
            end

            local function restartPatchWorker()
                effectState.PatchRunId += 1

                local runId =
                    effectState.PatchRunId

                if not effectState.AntiRecoil
                    and not effectState
                        .NoRecoilBlur then

                    applyCurrentRecoilState()
                    return
                end

                task.spawn(function()
                    while rawget(
                            _G,
                            EFFECT_STATE_KEY
                        ) == effectState
                        and effectState
                            .PatchRunId
                            == runId
                        and (
                            effectState
                                .AntiRecoil
                            or effectState
                                .NoRecoilBlur
                        ) do

                        pcall(
                            applyCurrentRecoilState
                        )

                        task.wait(0.15)
                    end
                end)
            end

            -- ----------------------------------------------------
            -- CAMERA-SIGNAL SUPPRESSION
            -- ----------------------------------------------------
            local function looksLikeTowerCamera(
                connection
            )
                local fn = nil

                pcall(function()
                    fn =
                        connection.Function
                end)

                if type(fn)
                    ~= "function" then

                    -- Some executor builds do not expose the callback
                    -- function. These two signals were camera-effect
                    -- connections in the supplied TPS source, so use the
                    -- signal itself as the fallback discriminator.
                    return true
                end

                local source = nil

                pcall(function()
                    if debug
                        and debug.info then

                        source =
                            debug.info(
                                fn,
                                "s"
                            )
                    end
                end)

                if source
                    and tostring(source)
                        ~= "" then

                    local lowered =
                        tostring(source):
                            lower()

                    return
                        lowered:find(
                            "tps",
                            1,
                            true
                        ) ~= nil
                        or lowered:find(
                            "customcameramodes",
                            1,
                            true
                        ) ~= nil
                        or lowered:find(
                            "leglo",
                            1,
                            true
                        ) ~= nil
                end

                return true
            end

            local function disableSignalConnections(
                signal,
                bucketName
            )
                if type(getconnections)
                    ~= "function" then

                    notifyEffect(
                        "This executor does not expose getconnections, so this camera-effect toggle is unavailable.",
                        "failed"
                    )

                    return false
                end

                if not signal then
                    return false
                end

                local bucket =
                    effectState
                        .DisabledConnections[
                            bucketName
                        ]

                if not bucket then
                    return false
                end

                if #bucket > 0 then
                    return true
                end

                local okConnections,
                    connections =
                    pcall(
                        getconnections,
                        signal
                    )

                if not okConnections
                    or type(connections)
                        ~= "table" then

                    return false
                end

                for _, connection
                    in ipairs(connections) do

                    if looksLikeTowerCamera(
                        connection
                    ) then

                        local disabled =
                            false

                        pcall(function()
                            if type(
                                connection.Disable
                            ) == "function" then

                                connection:
                                    Disable()

                                disabled =
                                    true
                            end
                        end)

                        if disabled then
                            table.insert(
                                bucket,
                                connection
                            )
                        end
                    end
                end

                return #bucket > 0
            end

            local function restoreSignalConnections(
                bucketName
            )
                local bucket =
                    effectState
                        .DisabledConnections[
                            bucketName
                        ]

                if not bucket then
                    return
                end

                for _, connection
                    in ipairs(bucket) do

                    pcall(function()
                        if type(
                            connection.Enable
                        ) == "function" then

                            connection:
                                Enable()
                        end
                    end)
                end

                table.clear(bucket)
            end

            -- ----------------------------------------------------
            -- CLIENT CONFUSION
            -- ----------------------------------------------------
            local function setNoConfusion(
                enabled
            )
                effectState.NoConfusion =
                    enabled == true

                local gameHealth =
                    effectState.GameHealth

                if type(gameHealth)
                    ~= "table" then

                    if enabled then
                        notifyEffect(
                            "GameHealth was not available.",
                            "failed"
                        )
                    end

                    return
                end

                if type(
                    effectState
                        .OriginalAddClientConfusion
                ) ~= "function" then

                    local original =
                        gameHealth
                            .AddClientConfusion

                    if type(original)
                        ~= "function" then

                        if enabled then
                            notifyEffect(
                                "GameHealth.AddClientConfusion was not available.",
                                "failed"
                            )
                        end

                        return
                    end

                    effectState
                        .OriginalAddClientConfusion =
                        original

                    effectState.ConfusionWrapper =
                        function(
                            self,
                            amount,
                            ...
                        )
                            if effectState
                                .NoConfusion
                                and (
                                    tonumber(
                                        amount
                                    ) or 0
                                ) > 0 then

                                return nil
                            end

                            return effectState
                                .OriginalAddClientConfusion(
                                    self,
                                    amount,
                                    ...
                                )
                        end
                end

                if enabled then
                    -- Existing confusion is clamped in [0,1]. Sending -1
                    -- through the original method clears any amount already
                    -- accumulated before the toggle was enabled.
                    pcall(
                        effectState
                            .OriginalAddClientConfusion,
                        gameHealth,
                        -1
                    )

                    gameHealth
                        .AddClientConfusion =
                        effectState
                            .ConfusionWrapper
                else
                    if gameHealth
                        .AddClientConfusion
                        == effectState
                            .ConfusionWrapper then

                        gameHealth
                            .AddClientConfusion =
                            effectState
                                .OriginalAddClientConfusion
                    end
                end
            end

            -- ----------------------------------------------------
            -- FULL RESTORE
            -- ----------------------------------------------------
            function effectState.RestoreAll()
                effectState.AntiRecoil =
                    false

                effectState.NoRecoilBlur =
                    false

                effectState.PatchRunId += 1

                pcall(
                    restoreDescriptions
                )

                pcall(
                    restoreSignalConnections,
                    "Concussion"
                )

                pcall(
                    restoreSignalConnections,
                    "Suppression"
                )

                pcall(
                    setNoConfusion,
                    false
                )
            end

            -- ----------------------------------------------------
            -- UI
            -- ----------------------------------------------------
            local antiRecoilToggle =
                cameraEffectsSection:AddToggle(
                    "Anti Sniper Recoil",
                    false,
                    function(value)
                        effectState.AntiRecoil =
                            value == true

                        pcall(
                            applyCurrentRecoilState
                        )

                        restartPatchWorker()
                    end
                )

            local noRecoilBlurToggle =
                cameraEffectsSection:AddToggle(
                    "No Recoil Blur",
                    false,
                    function(value)
                        effectState.NoRecoilBlur =
                            value == true

                        pcall(
                            applyCurrentRecoilState
                        )

                        restartPatchWorker()
                    end
                )

            local noConcussionToggle =
                cameraEffectsSection:AddToggle(
                    "No Concussion Shake",
                    false,
                    function(value)
                        if value == true then
                            local signal =
                                effectState
                                    .GameHealth
                                and effectState
                                    .GameHealth
                                    .OnConcussion

                            local ok =
                                disableSignalConnections(
                                    signal,
                                    "Concussion"
                                )

                            if not ok then
                                notifyEffect(
                                    "Could not suppress the concussion camera connection.",
                                    "failed"
                                )
                            end
                        else
                            restoreSignalConnections(
                                "Concussion"
                            )
                        end
                    end
                )

            local noSuppressionToggle =
                cameraEffectsSection:AddToggle(
                    "No Suppression Shake",
                    false,
                    function(value)
                        if value == true then
                            local signal =
                                effectState
                                    .Projectile
                                and effectState
                                    .Projectile
                                    .Supressed

                            local ok =
                                disableSignalConnections(
                                    signal,
                                    "Suppression"
                                )

                            if not ok then
                                notifyEffect(
                                    "Could not suppress the suppression camera connection.",
                                    "failed"
                                )
                            end
                        else
                            restoreSignalConnections(
                                "Suppression"
                            )
                        end
                    end
                )

            local noConfusionToggle =
                cameraEffectsSection:AddToggle(
                    "No Confusion",
                    false,
                    function(value)
                        setNoConfusion(
                            value == true
                        )
                    end
                )

            cameraEffectsSection:AddButton(
                "Restore Camera Effects",
                function()
                    effectState.RestoreAll()

                    pcall(function()
                        antiRecoilToggle:Set(
                            false,
                            false
                        )
                    end)

                    pcall(function()
                        noRecoilBlurToggle:Set(
                            false,
                            false
                        )
                    end)

                    pcall(function()
                        noConcussionToggle:Set(
                            false,
                            false
                        )
                    end)

                    pcall(function()
                        noSuppressionToggle:Set(
                            false,
                            false
                        )
                    end)

                    pcall(function()
                        noConfusionToggle:Set(
                            false,
                            false
                        )
                    end)

                    notifyEffect(
                        "Sniper recoil, blur, concussion, suppression, and confusion effects restored."
                    )
                end
            )

            sniperTab:CreateLabel(
                "Anti Recoil keeps the native firing/projectile path intact. Concussion, suppression, and confusion controls affect only the local client effects identified in the supplied game modules.",
                cameraEffectsSection._Section
            )
        end)
    end)

    -- ============================================================
    -- PERSONALIZATION
    -- ============================================================
    -- Ported from the unsupported-game fallback interface.
    --
    -- IMPORTANT: keep the entire tab inside a nested closure. The Tower module is
    -- already large and has previously hit Luau outer-scope local/register limits.
    -- These controls use their original fallback flags so configuration saving and
    -- the final Window:LoadConfiguration(true) pass continue to work normally.
    pcall(function()
        local Personalization = Window:CreateTab("Personalization", "palette")

        -- Keep the page registered so the topbar palette button can open it,
        -- but remove Personalization from the left tab list.
        if Personalization.NavButton then
            Personalization.NavButton.Visible = false
        end

        -- APPEARANCE -----------------------------------------------------------
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
            Callback = function(option)
                print("Theme:", option)
            end,
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
            Callback = function(color)
                print("Accent:", color)
            end,
        })

        AppearanceSection:CreateButtonPicker({
            Name = "Button color",
            Info = "Change action buttons independently from the accent.",
            Color = NovaField.Theme.Button,
            Flag = "ButtonColor",
            Callback = function(color)
                print("Button color:", color)
            end,
        })

        local AppearanceInfo = Personalization:CreateSection({
            Name = "Color roles",
            Description = "Accent and action-button colors are separate.",
            Side = "Left",
        })

        AppearanceInfo:CreateParagraph({
            Title = "Accent color",
            Content = "Tabs, toggles, sliders, focus borders, selection checks, and accent outlines use the global accent.",
        })

        AppearanceInfo:CreateParagraph({
            Title = "Button color",
            Content = "Action buttons use the theme's separate Button color and no longer change when the accent changes.",
        })

        -- WINDOW BORDER --------------------------------------------------------
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

        local FollowAccent
        FollowAccent = BorderSection:CreateToggle({
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
            CurrentValue = 8,
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

        -- Apply saved/current values immediately, matching the fallback module.
        Window:SetBorderStrokeEnabled(BorderEnabled:Get())
        Window:SetBorderStrokeThickness(BorderThickness:Get())
        Window:SetBorderStrokeTransparency(BorderTransparency:Get() / 100)

        if FollowAccent:Get() then
            Window:SetBorderStrokeUseAccent(true)
        else
            Window:SetBorderStrokeColor(BorderColor:Get())
        end

        -- HUB SETTINGS ---------------------------------------------------------
        local HubSection = Personalization:CreateSection({
            Name = "vitality's hub",
            Description = "Shortcuts, motion, and hub controls.",
            Side = "Right",
        })

        HubSection:CreateKeybind({
            Name = "Toggle hub",
            Info = "Choose the shortcut used to open or close the hub.",
            CurrentKeybind = Window:GetToggleKey(),
            Flag = "InterfaceKeybind",
            Behavior = "ToggleInterface",
            Callback = function(keyName)
                print("Hub shortcut changed to:", keyName)
            end,
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
                    Duration = 4,
                })
            end,
        })

        -- AUDIO ----------------------------------------------------------------
        local AudioSection = Personalization:CreateSection({
            Name = "Audio",
            Description = "Gentle feedback sounds with one master level.",
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
            Info = "Play a short, low-volume notification sound.",
            Interact = "Preview",
            Callback = function()
                Window:Notify({
                    Title = "Sound preview",
                    Content = "Sound feedback is working.",
                    Duration = 2.5,
                })
            end,
        })
    end)


    -- Manual/object-by-object teleport controls remain on the Teleports tab.
    local runnerSection = CreateCategorySector(TeleportsTab, "Loot Teleports")

    -- One compact loot selector replaces the old wall of dropdowns.

    local function isGreenFlare(obj)

        if not obj or obj.Name ~= "Flare" then return false end

        local function colorIsGreen(color)

            return color.G > color.R * 1.25
                and color.G > color.B * 1.25
                and color.G >= 0.45

        end

        local function sequenceHasGreen(sequence)

            for _, keypoint in ipairs(sequence.Keypoints) do

                if colorIsGreen(keypoint.Value) then

                    return true

                end

            end

            return false

        end

        local function objectLooksGreen(item)

            if item:IsA("BasePart") then

                return colorIsGreen(item.Color)

            elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then

                return colorIsGreen(item.Color)

            elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then

                return sequenceHasGreen(item.Color)

            elseif item:IsA("Color3Value") then

                return colorIsGreen(item.Value)

            end

            return false

        end

        if objectLooksGreen(obj) then

            return true

        end

        for _, descendant in ipairs(obj:GetDescendants()) do

            if objectLooksGreen(descendant) then

                return true

            end

        end

        return false

    end

    local TeleportTargets = {

        ["Keys"] = {

            Names = {"SafeKey", "KeyUnlockable"},

            Inner = "Plane_Plane",

            Color = Color3.fromRGB(0, 180, 255)

        },

        ["Safes"] = {

            Names = {"SafeUnlockable"},

            Inner = "Cube",

            Color = Color3.fromRGB(255, 100, 100)

        },

        ["Advanced Safes"] = {

            Names = {"AdvancedSafeUnlockable"},

            Inner = "Door",

            Color = Color3.fromRGB(255, 50, 200)

        },

        ["Advanced Safe Keys"] = {

            Names = {"AdvancedSafeKey"},

            Inner = "Plane",

            Color = Color3.fromRGB(200, 100, 255)

        },

        ["Airdrop Keys"] = {

            Names = {"AirdropKey"},

            Inner = "Plane.001_Plane.001",

            Color = Color3.fromRGB(0, 255, 255)

        },

        ["Airdrops"] = {

            Names = {"AirdropUnlockable"},

            Inner = nil,

            Color = Color3.fromRGB(255, 215, 0)

        },

        ["Flares"] = {

            Names = {"Flare"},

            Inner = nil,

            Color = Color3.fromRGB(0, 255, 0)

        }

    }

    local TeleportTypeNames = {}

    for name in pairs(TeleportTargets) do

        table.insert(TeleportTypeNames, name)

    end

    table.sort(TeleportTypeNames)

    local selectedTeleportType = TeleportTypeNames[1]

    local selectedTeleportTarget = nil

    local targetOptions = {}

    local targetObjects = {}

    local targetDropdown

    local function getTeleportCFrame(obj, innerName)

        if not obj then return nil end

        if innerName then

            local inner = obj:FindFirstChild(innerName, true)

            if inner and inner:IsA("BasePart") then

                return inner.CFrame

            end

        end

        if obj:IsA("BasePart") then

            return obj.CFrame

        end

        if obj:IsA("Model") then

            return obj:GetPivot()

        end

        local part = obj:FindFirstChildWhichIsA("BasePart", true)

        return part and part.CFrame or nil

    end

    -- ============================================================
    -- TELEPORT INDEX + MOVEMENT STABILIZATION
    -- ============================================================
    -- Every teleportable object receives a stable number inside its own category.
    -- Item ESP uses the same number, so dropdown #2 is visibly ESP #2 in the world.
    local TeleportNumberByObject = {}
    local TeleportTypeByObject = {}

    local function teleportEntryPosition(obj, innerName)

        local cf = getTeleportCFrame(obj, innerName)
        return cf and cf.Position or Vector3.zero

    end

    local function rebuildTeleportNumberMap()

        local numberMap = {}
        local typeMap = {}
        local targetsByType = {}
        local nameToTypes = {}

        for _, typeName in ipairs(TeleportTypeNames) do

            targetsByType[typeName] = {}

            local settings = TeleportTargets[typeName]
            for _, targetName in ipairs(settings.Names) do
                nameToTypes[targetName] = nameToTypes[targetName] or {}
                table.insert(nameToTypes[targetName], typeName)
            end

        end

        -- Scan workspace once, then place each matching object into its category.
        for _, obj in ipairs(workspace:GetDescendants()) do

            local matchingTypes = nameToTypes[obj.Name]

            if matchingTypes and (obj:IsA("Model") or obj:IsA("BasePart")) then

                for _, typeName in ipairs(matchingTypes) do

                    local settings = TeleportTargets[typeName]

                    if not settings.Predicate or settings.Predicate(obj) then

                        table.insert(targetsByType[typeName], {
                            Path = obj:GetFullName(),
                            Object = obj,
                            Position = teleportEntryPosition(obj, settings.Inner)
                        })

                    end

                end

            end

        end

        for _, typeName in ipairs(TeleportTypeNames) do

            local found = targetsByType[typeName]

            table.sort(found, function(a, b)

                if a.Path ~= b.Path then
                    return a.Path < b.Path
                end

                if a.Position.X ~= b.Position.X then
                    return a.Position.X < b.Position.X
                end

                if a.Position.Y ~= b.Position.Y then
                    return a.Position.Y < b.Position.Y
                end

                return a.Position.Z < b.Position.Z

            end)

            for index, entry in ipairs(found) do
                numberMap[entry.Object] = index
                typeMap[entry.Object] = typeName
            end

        end

        TeleportNumberByObject = numberMap
        TeleportTypeByObject = typeMap

        return targetsByType

    end

    local MovementReleaseKeys = {
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right
    }

    local function releaseMovementInput()

        pcall(function()

            local VirtualInputManager = game:GetService("VirtualInputManager")

            for _, keyCode in ipairs(MovementReleaseKeys) do
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end

        end)

    end

    local function clearCharacterMomentum(character)

        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            pcall(function()
                humanoid:Move(Vector3.zero, false)
            end)
        end

        for _, part in ipairs(character:GetDescendants()) do

            if part:IsA("BasePart") then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end)
            end

        end

    end

    local function stabilizedTeleport(character, destinationCFrame)

        if not character or not destinationCFrame then
            return false
        end

        releaseMovementInput()
        clearCharacterMomentum(character)

        local moved = pcall(function()
            character:PivotTo(destinationCFrame)
        end)

        if not moved then
            return false
        end

        clearCharacterMomentum(character)

        task.spawn(function()

            for _ = 1, 5 do
                game:GetService("RunService").Heartbeat:Wait()

                if not character.Parent then
                    break
                end

                releaseMovementInput()
                clearCharacterMomentum(character)
            end

        end)

        return true

    end

    -- ============================================================
    -- MAIN TAB AUTOMATION
    -- ============================================================
    -- Each automation button prefers one key and one matching unlockable:
    -- key -> safe/drop -> key -> safe/drop. Spare keys are still collected when no
    -- unlockables remain. Targets already processed by this
    -- script, removed from Workspace, or clearly marked opened/collected are skipped.
    --
    -- The character is positioned on the ground in front of each target and rotated to
    -- face it. Several clear front-hemisphere positions are tried when geometry blocks
    -- the interaction face. PickupCallback returning true is the only success condition
    -- that advances the loop. Reward-stage confirmation does not gate progression.
    -- ============================================================

    local AutomationProcessedTargets = setmetatable({}, {__mode = "k"})
    local AutomationRunning = false
    local ActiveAutomationFreezeState = nil
    local ActiveAutomationRunId = 0

    -- ============================================================
    -- AIRDROP LANDING SAFETY
    -- ============================================================
    -- AirdropUnlockable can exist in Workspace while it is still high in the air.
    -- Teleporting to it at that point is unsafe: when the freeze ends the character
    -- can fall / retain bad physics and die. We only allow an airdrop teleport once
    -- the bottom of the airdrop is close to a real surface AND its vertical motion
    -- is calm for a short continuous window.
    local function getAirdropBounds(obj)
        if not obj or not obj.Parent then
            return nil, nil
        end

        if obj:IsA("Model") then
            local ok, cf, size = pcall(function()
                local boxCF, boxSize = obj:GetBoundingBox()
                return boxCF, boxSize
            end)

            if ok and cf and size then
                return cf, size
            end
        elseif obj:IsA("BasePart") then
            return obj.CFrame, obj.Size
        end

        local part = obj:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.CFrame, part.Size
        end

        return nil, nil
    end

    local function getAirdropReferencePart(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        end
        return obj:FindFirstChildWhichIsA("BasePart", true)
    end

    local function isAirdropSafelyLanded(obj)
        local boundsCF, boundsSize = getAirdropBounds(obj)
        if not boundsCF or not boundsSize then
            return false, math.huge
        end

        local bottomY = boundsCF.Position.Y - (boundsSize.Y * 0.5)
        local origin = Vector3.new(
            boundsCF.Position.X,
            bottomY + 1.5,
            boundsCF.Position.Z
        )

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude

        local character = game:GetService("Players").LocalPlayer.Character
        local excluded = {obj}
        if character then
            table.insert(excluded, character)
        end

        params.FilterDescendantsInstances = excluded
        params.IgnoreWater = false

        -- We only care whether a surface is reasonably close beneath the drop.
        -- A high airborne drop will either have no hit in this range or a very
        -- large gap. A landed / nearly-landed drop should be within ~8 studs.
        local hit = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
        if not hit then
            return false, math.huge
        end

        local groundGap = math.max(0, bottomY - hit.Position.Y)
        if groundGap > 8 then
            return false, groundGap
        end

        -- A physics-driven drop can be close to the floor while still falling fast.
        -- Do not teleport until its vertical movement has settled.
        local referencePart = getAirdropReferencePart(obj)
        if referencePart then
            local verticalSpeed = math.abs(referencePart.AssemblyLinearVelocity.Y)
            if verticalSpeed > 12 then
                return false, groundGap
            end
        end

        return true, groundGap
    end

    local function waitForAirdropLanded(obj, runId, timeout)
        local deadline = os.clock() + (timeout or 45)
        local stableSince = nil

        repeat
            if runId and runId ~= ActiveAutomationRunId then
                return false
            end

            if not obj or not obj.Parent then
                return false
            end

            local landed = isAirdropSafelyLanded(obj)

            if landed then
                if not stableSince then
                    stableSince = os.clock()
                elseif os.clock() - stableSince >= 0.35 then
                    return true
                end
            else
                stableSince = nil
            end

            task.wait(0.10)
        until os.clock() >= deadline

        return false
    end

    local AutomationGroups = {
        Safes = {
            KeyType = "Keys",
            UnlockType = "Safes",
            KeyValueName = "KeySafe",
            KeyLabel = "Key",
            UnlockLabel = "Safe",
            DoneMessage = "Done grabbing and unlocking safes!"
        },
        AdvancedSafes = {
            KeyType = "Advanced Safe Keys",
            UnlockType = "Advanced Safes",
            KeyValueName = "KeyAdvancedSafe",
            KeyLabel = "Advanced Key",
            UnlockLabel = "Advanced Safe",
            DoneMessage = "Done grabbing and unlocking advanced safes!"
        },
        Airdrops = {
            KeyType = "Airdrop Keys",
            UnlockType = "Airdrops",
            KeyValueName = "KeyAirdrop",
            KeyLabel = "Airdrop Key",
            UnlockLabel = "Airdrop",
            DoneMessage = "Done grabbing and unlocking airdrops!"
        }
    }

    local FinishedStateNames = {
        "Opened",
        "Open",
        "Unlocked",
        "Collected",
        "Taken",
        "Claimed",
        "Used",
        "PickedUp",
        "Consumed",
        "Activated"
    }

    local function hasFinishedState(obj)

        if not obj then return true end

        local function check(container)

            if not container then return false end

            for _, stateName in ipairs(FinishedStateNames) do

                local ok, value = pcall(function()
                    return container:GetAttribute(stateName)
                end)

                if ok and value == true then
                    return true
                end

                local stateValue = container:FindFirstChild(stateName)

                if stateValue and stateValue:IsA("BoolValue") and stateValue.Value == true then
                    return true
                end

            end

            return false

        end

        if check(obj) then
            return true
        end

        local model = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")

        if model and model ~= obj and check(model) then
            return true
        end

        -- If this target still contains proximity prompts but every one of them
        -- is disabled, it is generally no longer interactable.
        local prompts = {}

        for _, descendant in ipairs(obj:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") then
                table.insert(prompts, descendant)
            end
        end

        if #prompts > 0 then

            for _, prompt in ipairs(prompts) do
                if prompt.Enabled then
                    return false
                end
            end

            return true

        end

        return false

    end

    local function isAutomationTargetAvailable(obj)

        if not obj or AutomationProcessedTargets[obj] then
            return false
        end

        if not obj.Parent then
            return false
        end

        local inWorkspace = false

        pcall(function()
            inWorkspace = obj:IsDescendantOf(workspace)
        end)

        if not inWorkspace then
            return false
        end

        if hasFinishedState(obj) then
            return false
        end

        return true

    end

    local function getAvailableAutomationEntries(typeName, targetsByType)

        local available = {}
        local source = targetsByType and targetsByType[typeName] or nil

        if not source then
            local rebuilt = rebuildTeleportNumberMap()
            source = rebuilt[typeName] or {}
        end

        for _, entry in ipairs(source) do

            if isAutomationTargetAvailable(entry.Object) then
                table.insert(available, entry)
            end

        end

        return available

    end

    local function formatCount(count, singular, plural)

        return string.format("%d %s", count, count == 1 and singular or plural)

    end

    local SafeCountLabel = MainTab:CreateLabel("Scanning for safes and keys...", safeAutomationSection._Section)
    local AdvancedSafeCountLabel = MainTab:CreateLabel("Scanning for advanced safes and keys...", advancedSafeAutomationSection._Section)
    local AirdropCountLabel = MainTab:CreateLabel("Scanning for airdrops and keys...", airdropAutomationSection._Section)

    local function refreshAutomationStatus()

        local targetsByType = rebuildTeleportNumberMap()

        local regularKeys = getAvailableAutomationEntries("Keys", targetsByType)
        local regularSafes = getAvailableAutomationEntries("Safes", targetsByType)

        local advancedKeys = getAvailableAutomationEntries("Advanced Safe Keys", targetsByType)
        local advancedSafes = getAvailableAutomationEntries("Advanced Safes", targetsByType)

        local airdropKeys = getAvailableAutomationEntries("Airdrop Keys", targetsByType)
        local airdrops = getAvailableAutomationEntries("Airdrops", targetsByType)

        pcall(function()
            SafeCountLabel:Set(
                string.format(
                    "%s, %s",
                    formatCount(#regularSafes, "Safe", "Safes"),
                    formatCount(#regularKeys, "Key", "Keys")
                )
            )
        end)

        pcall(function()
            AdvancedSafeCountLabel:Set(
                string.format(
                    "%s, %s",
                    formatCount(#advancedSafes, "Advanced Safe", "Advanced Safes"),
                    formatCount(#advancedKeys, "Advanced Key", "Advanced Keys")
                )
            )
        end)

        pcall(function()
            AirdropCountLabel:Set(
                string.format(
                    "%s, %s",
                    formatCount(#airdrops, "Airdrop", "Airdrops"),
                    formatCount(#airdropKeys, "Airdrop Key", "Airdrop Keys")
                )
            )
        end)

        return {
            RegularKeys = regularKeys,
            RegularSafes = regularSafes,
            AdvancedKeys = advancedKeys,
            AdvancedSafes = advancedSafes,
            AirdropKeys = airdropKeys,
            Airdrops = airdrops
        }

    end

    local function notifyAutomation(message)

        pcall(function()
            Window:Notify({
                Title = "THE TOWER",
                Content = message,
                Duration = 6
            })
        end)

    end

    local InteractionKeyCode = Enum.KeyCode.F
    local InteractionVirtualKey = 0x46 -- F
    -- Near-touching interaction placement.
    -- The player's BODY surface is kept this far from the target surface; the
    -- HumanoidRootPart itself is still offset enough to avoid spawning inside it.
    local InteractionSurfaceGap = 0.55

    -- ============================================================
    -- EXACT REMOTE INTERACTION
    -- ============================================================
    -- Cobalt captures establish three distinct pieces of the safe flow:
    --   1) Keys call Collectables.PickupCallback with the SafeKey instance AFTER
    --      the client has moved it out of Workspace (Cobalt therefore sees GetNil()).
    --   2) SafeUnlockable itself calls the same PickupCallback while still in Workspace.
    --   3) After the safe opens, a Flare is spawned and InteractionFlare.Rewards /
    --      InteractionFlare.RequestTake are called with that Flare, not the safe.
    --
    -- This reproduces that order instead of sending RequestTake to SafeUnlockable.
    -- The existing front-facing F interaction remains a fallback only if a captured
    -- remote call errors or explicitly returns false.
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local function getRemoteFunction(folderName, remoteName)
        local folder = ReplicatedStorage:FindFirstChild(folderName)
        if not folder then return nil end
        local remote = folder:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteFunction") then
            return remote
        end
        return nil
    end

    local function getCollectablePickupRemote()
        return getRemoteFunction("Collectables", "PickupCallback")
    end

    local function getInteractionRewardsRemote()
        return getRemoteFunction("InteractionFlare", "Rewards")
    end

    local function getInteractionTakeRemote()
        return getRemoteFunction("InteractionFlare", "RequestTake")
    end

    local function targetLooksConsumed(obj)
        if not obj or not obj.Parent then
            return true
        end

        local inWorkspace = false
        pcall(function()
            inWorkspace = obj:IsDescendantOf(workspace)
        end)

        if not inWorkspace then
            return true
        end

        return hasFinishedState(obj)
    end

    local function waitForTargetStateChange(obj, timeout)
        local deadline = os.clock() + (timeout or 0.65)

        repeat
            if targetLooksConsumed(obj) then
                return true
            end
            task.wait(0.05)
        until os.clock() >= deadline

        return targetLooksConsumed(obj)
    end

    local function invokeRemoteFunction(remote, obj)
        if not remote or not obj then
            return false, nil
        end

        local ok, result = pcall(function()
            return remote:InvokeServer(obj)
        end)

        -- Many Roblox RemoteFunctions legitimately return nil on success. Only an
        -- actual Lua error or an explicit false is treated as a remote failure.
        return ok and result ~= false, result
    end

    local function isKeyAutomationType(typeName)
        return typeName == "Keys"
            or typeName == "Advanced Safe Keys"
            or typeName == "Airdrop Keys"
    end

    local function isUnlockableAutomationType(typeName)
        return typeName == "Safes"
            or typeName == "Advanced Safes"
            or typeName == "Airdrops"
    end

    -- The GetNil(...) in Cobalt's SafeKey capture is most likely the state of the
    -- key AFTER the game's own RequestPickupCollectable function has already done
    -- its local bookkeeping. Instead of forcibly nil-parenting the key ourselves,
    -- first try to call that exact local client function. This preserves whatever
    -- debounce/state changes the game expects before PickupCallback:InvokeServer().
    local CachedRequestPickupCollectable = nil

    local function findRequestPickupCollectable()
        if CachedRequestPickupCollectable then
            return CachedRequestPickupCollectable
        end

        if type(getgc) ~= "function" then
            return nil
        end

        local ok, gcObjects = pcall(function()
            return getgc(true)
        end)

        if not ok or type(gcObjects) ~= "table" then
            return nil
        end

        for _, candidate in ipairs(gcObjects) do
            if type(candidate) == "function" then
                local functionName = nil
                local sourceName = nil

                pcall(function()
                    if debug and debug.info then
                        functionName = debug.info(candidate, "n")
                        sourceName = debug.info(candidate, "s")
                    elseif debug and debug.getinfo then
                        local info = debug.getinfo(candidate)
                        functionName = info and info.name or nil
                        sourceName = info and info.source or nil
                    end
                end)

                local matchesName = functionName == "RequestPickupCollectable"
                local matchesSource = type(sourceName) == "string"
                    and string.find(sourceName, "Collectables", 1, true) ~= nil

                if matchesName and (matchesSource or sourceName == nil) then
                    CachedRequestPickupCollectable = candidate
                    return candidate
                end
            end
        end

        -- Some executors strip function names. As a fallback, identify the closure
        -- from the constants visible in the Cobalt dump.
        if debug and debug.getconstants then
            for _, candidate in ipairs(gcObjects) do
                if type(candidate) == "function" then
                    local okConstants, constants = pcall(debug.getconstants, candidate)
                    if okConstants and type(constants) == "table" then
                        local hasPickupCallback = false
                        local hasTriedPickup = false
                        for _, constant in pairs(constants) do
                            if constant == "PickupCallback" then hasPickupCallback = true end
                            if constant == "tried pickup" then hasTriedPickup = true end
                        end
                        if hasPickupCallback and hasTriedPickup then
                            CachedRequestPickupCollectable = candidate
                            return candidate
                        end
                    end
                end
            end
        end

        return nil
    end

    local function invokeClientCollectableFlow(obj)
        local fn = findRequestPickupCollectable()
        if not fn or not obj then
            return false
        end

        local ok = pcall(function()
            fn(obj)
        end)

        return ok
    end

    local function invokeDirectPickupRemote(obj)
        local remote = getCollectablePickupRemote()
        local ok, result = invokeRemoteFunction(remote, obj)
        return ok, result
    end

    -- SafeUnlockable was captured while parented directly under Workspace. When
    -- the client helper cannot be located, invoke PickupCallback with that exact
    -- world instance as the direct fallback. Keep the RemoteFunction's exact return
    -- value because Cobalt shows that true/false is meaningful for this game.
    local function invokeCapturedUnlockable(obj)
        return invokeDirectPickupRemote(obj)
    end

    local function objectWorldPosition(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj.Position end
        if obj:IsA("Model") then
            local ok, pivot = pcall(function() return obj:GetPivot() end)
            if ok then return pivot.Position end
        end
        local part = obj:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end

    local function snapshotInteractionFlares()
        local set = setmetatable({}, {__mode = "k"})
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Flare" and (obj:IsA("Model") or obj:IsA("BasePart")) then
                set[obj] = true
            end
        end
        return set
    end

    -- Safes appear to turn into/spawn a Flare for the reward/take phase. Prefer a
    -- newly-created Flare near the safe's previous position so unrelated world
    -- flares (including Extract) are not accidentally claimed.
    local function waitForSafeInteractionFlare(beforeFlares, nearPosition, timeout)
        local deadline = os.clock() + (timeout or 1.25)
        local best = nil
        local bestDistance = math.huge

        repeat
            best = nil
            bestDistance = math.huge

            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "Flare" and (obj:IsA("Model") or obj:IsA("BasePart")) then
                    local pos = objectWorldPosition(obj)
                    if pos then
                        local distance = nearPosition and (pos - nearPosition).Magnitude or 0
                        local isNew = not beforeFlares or not beforeFlares[obj]

                        -- New nearby flares win. Existing nearby flares are accepted
                        -- only as a fallback because some builds may reuse an object.
                        local score = distance + (isNew and 0 or 1000)
                        if distance <= 35 and score < bestDistance then
                            best = obj
                            bestDistance = score
                        end
                    end
                end
            end

            if best and (not beforeFlares or not beforeFlares[best]) then
                return best
            end

            task.wait(0.05)
        until os.clock() >= deadline

        -- Fall back to the closest nearby flare if no clearly-new one appeared.
        if best and bestDistance < 1035 then
            return best
        end

        return nil
    end

    local function processOpenedSafeFlare(flare, runId)
        if not flare then
            return false
        end

        local rewards = getInteractionRewardsRemote()
        local take = getInteractionTakeRemote()

        if not rewards or not take then
            return false
        end

        -- Cobalt shows InteractionFlare.Rewards and InteractionFlare.RequestTake
        -- returning non-boolean values (buffer-like results), so `result == true`
        -- is NOT a valid success test here. A successful InvokeServer call that
        -- does not explicitly return false is treated as the server accepting
        -- that stage.
        --
        -- Stage 1: ask the flare for/spawn its rewards.
        local rewardsReady = false
        local rewardsDeadline = os.clock() + 3

        repeat
            if runId and runId ~= ActiveAutomationRunId then
                return false
            end

            if not flare.Parent then
                return false
            end

            local accepted = invokeRemoteFunction(rewards, flare)
            if accepted then
                rewardsReady = true
                break
            end

            task.wait(0.08)
        until os.clock() >= rewardsDeadline

        if not rewardsReady then
            return false
        end

        task.wait(0.10)

        -- Stage 2: RequestTake is the actual reward-pickup request from the
        -- Cobalt captures. Cobalt shows it returning a buffer-like value, not a
        -- boolean. More importantly, the reward Flare does NOT have to disappear
        -- or receive one of our generic "finished" markers after a successful take.
        --
        -- The previous version incorrectly required that visual/state transition,
        -- which is why the reward could visibly be collected while Vitality still
        -- reported that the interaction did not complete.
        local takeDeadline = os.clock() + 4

        repeat
            if runId and runId ~= ActiveAutomationRunId then
                return false
            end

            -- If the game happened to remove/finish the flare before our call,
            -- that is already enough evidence that the reward stage completed.
            if targetLooksConsumed(flare) then
                return true
            end

            local accepted = invokeRemoteFunction(take, flare)

            if accepted then
                -- A successful RequestTake invocation is the authoritative completion
                -- signal for this stage. Keep the character frozen for a short settle
                -- window so the server/client can apply the reward and clear any stale
                -- movement before we teleport to the next safe.
                local settleDeadline = os.clock() + 0.40

                repeat
                    if runId and runId ~= ActiveAutomationRunId then
                        return false
                    end

                    -- If the flare *does* disappear, we can finish slightly earlier.
                    if targetLooksConsumed(flare) then
                        return true
                    end

                    task.wait(0.05)
                until os.clock() >= settleDeadline

                -- Do not require the flare itself to vanish. The Cobalt capture shows
                -- RequestTake as the pickup action, so a non-error/non-false return from
                -- that RemoteFunction is enough to advance.
                return true
            end

            -- Only retry RequestTake when the call errored or explicitly returned false.
            task.wait(0.08)
        until os.clock() >= takeDeadline

        return targetLooksConsumed(flare)
    end

    local function releaseInteractionKey()

        pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(
                false,
                InteractionKeyCode,
                false,
                game
            )
        end)

        -- Executor fallback for environments where VirtualInputManager is blocked.
        pcall(function()
            if keyrelease then
                keyrelease(InteractionVirtualKey)
            end
        end)

    end

    local function setInteractionKeyHeld(state)

        local sent = false

        pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(
                state,
                InteractionKeyCode,
                false,
                game
            )
            sent = true
        end)

        if sent then
            return true
        end

        pcall(function()
            if state and keypress then
                keypress(InteractionVirtualKey)
                sent = true
            elseif not state and keyrelease then
                keyrelease(InteractionVirtualKey)
                sent = true
            end
        end)

        return sent

    end

    local function freezeCharacterForInteraction(character)

        if not character then return nil end

        local root = character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")

        if not root or not root:IsA("BasePart") then
            return nil
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")

        local state = {
            Character = character,
            Root = root,
            RootWasAnchored = root.Anchored,
            Humanoid = humanoid,
            AutoRotate = humanoid and humanoid.AutoRotate or nil
        }

        releaseMovementInput()
        clearCharacterMomentum(character)

        pcall(function()
            if humanoid then
                humanoid:Move(Vector3.zero, false)
                humanoid.AutoRotate = false
            end

            root.Anchored = true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        ActiveAutomationFreezeState = state

        return state

    end

    local function unfreezeCharacterAfterInteraction(state)

        if not state then return end

        local character = state.Character
        local root = state.Root
        local humanoid = state.Humanoid

        releaseInteractionKey()

        pcall(function()
            if root and root.Parent then
                root.Anchored = state.RootWasAnchored == true
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end

            if humanoid and humanoid.Parent and state.AutoRotate ~= nil then
                humanoid.AutoRotate = state.AutoRotate
                humanoid:Move(Vector3.zero, false)
            end
        end)

        if character and character.Parent then
            clearCharacterMomentum(character)
        end

        if ActiveAutomationFreezeState == state then
            ActiveAutomationFreezeState = nil
        end

    end

    -- Short post-teleport stabilization used by MANUAL key/safe teleports.
    -- This intentionally does not touch ActiveAutomationFreezeState so it cannot
    -- interfere with the longer automation reward freeze.
    local function brieflyFreezeAfterManualTeleport(character, duration)
        if not character then return end

        local root = character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")

        if not root or not root:IsA("BasePart") then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local wasAnchored = root.Anchored
        local oldAutoRotate = humanoid and humanoid.AutoRotate or nil
        local freezeDuration = math.max(tonumber(duration) or 0.28, 0)

        releaseMovementInput()
        clearCharacterMomentum(character)

        pcall(function()
            if humanoid then
                humanoid:Move(Vector3.zero, false)
                humanoid.AutoRotate = false
            end

            root.Anchored = true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        task.delay(freezeDuration, function()
            if not character or not character.Parent then
                return
            end

            releaseMovementInput()
            clearCharacterMomentum(character)

            pcall(function()
                if root and root.Parent then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    root.Anchored = wasAnchored
                end

                if humanoid and humanoid.Parent and oldAutoRotate ~= nil then
                    humanoid.AutoRotate = oldAutoRotate
                    humanoid:Move(Vector3.zero, false)
                end
            end)

            -- One extra heartbeat of zero momentum prevents the game/controller
            -- from immediately re-applying stale movement after unanchoring.
            task.spawn(function()
                game:GetService("RunService").Heartbeat:Wait()
                if character and character.Parent then
                    releaseMovementInput()
                    clearCharacterMomentum(character)
                end
            end)
        end)
    end

    local ActiveAutomationAimPosition = nil
    local AutomationCameraBindName = "TheTower_AutomationCameraAim"
    local AutomationCameraLockEnabled = false

    -- Clean up an aim lock left behind by an earlier execution.
    pcall(function()
        game:GetService("RunService"):UnbindFromRenderStep(AutomationCameraBindName)
    end)

    local function aimCameraAt(position)

        if not position then return end

        local camera = workspace.CurrentCamera
        if not camera then return end

        pcall(function()
            local cameraPosition = camera.CFrame.Position
            local toTarget = position - cameraPosition

            if toTarget.Magnitude > 0.05 then
                -- LookAt makes the camera's exact center ray point at the interaction
                -- point instead of merely rotating the character toward it.
                camera.CFrame = CFrame.lookAt(cameraPosition, position, Vector3.yAxis)
                camera.Focus = CFrame.new(position)
            end
        end)

    end

    local function stopAutomationCameraLock()
        AutomationCameraLockEnabled = false
        pcall(function()
            game:GetService("RunService"):UnbindFromRenderStep(AutomationCameraBindName)
        end)
    end

    local function startAutomationCameraLock(position)
        ActiveAutomationAimPosition = position
        stopAutomationCameraLock()
        AutomationCameraLockEnabled = true

        aimCameraAt(position)

        -- Run after the game's camera controller. This keeps the center of the
        -- screen pinned directly onto the key/safe/airdrop while we interact.
        pcall(function()
            game:GetService("RunService"):BindToRenderStep(
                AutomationCameraBindName,
                Enum.RenderPriority.Camera.Value + 10,
                function()
                    if AutomationCameraLockEnabled and ActiveAutomationAimPosition then
                        aimCameraAt(ActiveAutomationAimPosition)
                    end
                end
            )
        end)
    end

    local function waitForInteractionPromptVisible(runId, timeout)
        local deadline = os.clock() + (timeout or 1.5)

        repeat
            if runId ~= ActiveAutomationRunId then
                return false
            end

            if interactionPromptIsVisible() then
                return true
            end

            -- Keep the exact screen center pinned to the target while waiting for
            -- PlayerAction.Info/Input to become visible.
            if ActiveAutomationAimPosition then
                aimCameraAt(ActiveAutomationAimPosition)
            end

            game:GetService("RunService").RenderStepped:Wait()
        until os.clock() >= deadline

        return interactionPromptIsVisible()
    end

    local function getInteractionReferencePart(obj, innerName)

        if not obj then return nil end

        if innerName then
            local inner = obj:FindFirstChild(innerName, true)
            if inner and inner:IsA("BasePart") then
                return inner
            end
        end

        if obj:IsA("BasePart") then
            return obj
        end

        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        end

        return obj:FindFirstChildWhichIsA("BasePart", true)

    end

    local function projectedHalfExtent(cf, size, direction)

        if not cf or not size or not direction or direction.Magnitude < 0.001 then
            return 0
        end

        local unit = direction.Unit

        return math.abs(unit:Dot(cf.RightVector)) * (size.X * 0.5)
            + math.abs(unit:Dot(cf.UpVector)) * (size.Y * 0.5)
            + math.abs(unit:Dot(cf.LookVector)) * (size.Z * 0.5)

    end

    -- Find the walkable floor for an interaction target WITHOUT starting the
    -- ray above the whole structure. A tall tower/roof above an underground safe can
    -- otherwise become the first downward ray hit and make us teleport onto the roof.
    local function getTargetLevelGroundY(character, obj, root, x, z, targetY)
        if not character or not root then
            return targetY
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {character, obj}
        params.IgnoreWater = true

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local hipHeight = humanoid and humanoid.HipHeight or 2
        local rootHalfHeight = root.Size.Y * 0.5
        local rootLift = hipHeight + rootHalfHeight

        -- Primary probe begins only slightly above the interaction point. This is the
        -- critical fix for safes underneath towers, platforms, roofs, etc.
        local probeOffsets = {0.75, 1.75, 3.25}

        for _, offset in ipairs(probeOffsets) do
            local originY = targetY + offset
            local hit = workspace:Raycast(
                Vector3.new(x, originY, z),
                Vector3.new(0, -60, 0),
                params
            )

            if hit then
                -- A legitimate floor should be at or below roughly the target's own
                -- interaction height. Ignore an upper deck/roof that somehow intersects
                -- one of the higher probes.
                if hit.Position.Y <= targetY + 0.85 then
                    local rootY = hit.Position.Y + rootLift

                    -- The player's root can naturally sit a few studs above the target
                    -- because of HipHeight, but it should never be a tower-level jump.
                    if rootY <= targetY + 5.0 then
                        return rootY
                    end
                end
            end
        end

        -- Last-resort low probe. Starting essentially at target level means any roof
        -- above the safe is impossible to select.
        local lowHit = workspace:Raycast(
            Vector3.new(x, targetY + 0.25, z),
            Vector3.new(0, -60, 0),
            params
        )

        if lowHit and lowHit.Position.Y <= targetY + 0.85 then
            return lowHit.Position.Y + rootLift
        end

        -- If there is genuinely no floor under the candidate, stay near the target's
        -- level rather than inheriting a previous high/root position.
        return targetY
    end

    local function getInteractionApproachCFrame(character, obj, targetCFrame, innerName)

        if not character or not obj or not targetCFrame then
            return nil, nil
        end

        local root = character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")

        if not root or not root:IsA("BasePart") then
            return nil, nil
        end

        local referencePart = getInteractionReferencePart(obj, innerName)
        local targetPosition = targetCFrame.Position
        local facingCFrame = targetCFrame

        -- For keys/safes with a known inner interaction part, use that exact part as
        -- the interaction face rather than the model pivot.
        if referencePart then
            targetPosition = referencePart.Position
            facingCFrame = referencePart.CFrame
        end

        -- Roblox's forward face follows LookVector. Place the player on that side,
        -- then rotate the character back toward the object.
        local facing = Vector3.new(
            facingCFrame.LookVector.X,
            0,
            facingCFrame.LookVector.Z
        )

        if facing.Magnitude < 0.05 then
            local fromTargetToPlayer = Vector3.new(
                root.Position.X - targetPosition.X,
                0,
                root.Position.Z - targetPosition.Z
            )

            facing = fromTargetToPlayer.Magnitude > 0.05
                and fromTargetToPlayer.Unit
                or Vector3.new(0, 0, -1)
        else
            facing = facing.Unit
        end

        -- Put the avatar almost flush with the FRONT SURFACE, not merely close to
        -- the object's center. This keeps a small clear gap between the avatar body
        -- and the interaction surface while avoiding overlap/clipping.
        local targetHalfDepth = 0

        if referencePart then
            targetHalfDepth = projectedHalfExtent(
                referencePart.CFrame,
                referencePart.Size,
                facing
            )
        elseif obj:IsA("Model") then
            local ok, boxCF, boxSize = pcall(function()
                local cf, size = obj:GetBoundingBox()
                return cf, size
            end)

            if ok and boxCF and boxSize then
                targetPosition = boxCF.Position
                targetHalfDepth = projectedHalfExtent(boxCF, boxSize, facing)
            end
        end

        -- Once the character is facing the object, its Z dimension is its depth
        -- toward the interaction surface.
        local playerHalfDepth = math.max(root.Size.Z * 0.5, 0.45)
        local centerOffset = targetHalfDepth + playerHalfDepth + InteractionSurfaceGap

        local approachXZ = targetPosition + facing * centerOffset

        -- Resolve ground from the SAFE/KEY'S vertical level instead of from high above
        -- the map. This prevents an overhead tower roof from being mistaken for ground.
        local approachY = getTargetLevelGroundY(
            character,
            obj,
            root,
            approachXZ.X,
            approachXZ.Z,
            targetPosition.Y
        )

        local approachPosition = Vector3.new(
            approachXZ.X,
            approachY,
            approachXZ.Z
        )

        -- Keep the avatar upright and point its yaw exactly at the interaction face.
        local flatLookTarget = Vector3.new(
            targetPosition.X,
            approachPosition.Y,
            targetPosition.Z
        )

        if (flatLookTarget - approachPosition).Magnitude < 0.05 then
            flatLookTarget = approachPosition - facing
        end

        return CFrame.lookAt(approachPosition, flatLookTarget), targetPosition

    end

    -- ============================================================
    -- CLEAR FRONT-OF-TARGET APPROACH SEARCH
    -- ============================================================
    -- PickupCallback's true/false return is now the ONLY authority for advancing to
    -- the next automation target. To improve the chance of a true response, try several
    -- ground-level positions across the target's FRONT hemisphere and prefer positions
    -- whose head-to-target ray is unobstructed by unrelated geometry.
    local function rotateFlatDirection(direction, degrees)
        local flat = Vector3.new(direction.X, 0, direction.Z)
        if flat.Magnitude < 0.001 then
            flat = Vector3.new(0, 0, -1)
        else
            flat = flat.Unit
        end

        local radians = math.rad(degrees)
        local c = math.cos(radians)
        local s = math.sin(radians)

        return Vector3.new(
            flat.X * c - flat.Z * s,
            0,
            flat.X * s + flat.Z * c
        ).Unit
    end

    local function targetContainsHit(target, hitInstance)
        if not target or not hitInstance then return false end
        if hitInstance == target then return true end

        local inside = false
        pcall(function()
            inside = hitInstance:IsDescendantOf(target)
        end)
        return inside
    end

    local function getGroundedCandidateY(character, obj, root, x, z, targetY)
        return getTargetLevelGroundY(character, obj, root, x, z, targetY)
    end

    local function candidateHasClearLine(character, obj, approachPosition, targetPosition, root)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {character}
        params.IgnoreWater = true

        -- Approximate the player's eye/head point. This is better than testing from the
        -- feet and catches shelves/walls sitting directly between the prompt and player.
        local eyeHeight = math.max(1.5, root.Size.Y * 0.65)
        local origin = approachPosition + Vector3.new(0, eyeHeight, 0)
        local direction = targetPosition - origin

        if direction.Magnitude < 0.05 then
            return true
        end

        local hit = workspace:Raycast(origin, direction, params)
        if not hit then
            return true
        end

        return targetContainsHit(obj, hit.Instance)
    end

    local function getInteractionApproachCandidates(character, obj, targetCFrame, innerName)
        local root = character and (
            character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
        )

        if not root or not root:IsA("BasePart") or not obj or not targetCFrame then
            return {}
        end

        local referencePart = getInteractionReferencePart(obj, innerName)
        local targetPosition = referencePart and referencePart.Position or targetCFrame.Position
        local facingCFrame = referencePart and referencePart.CFrame or targetCFrame

        local baseFront = Vector3.new(
            facingCFrame.LookVector.X,
            0,
            facingCFrame.LookVector.Z
        )

        if baseFront.Magnitude < 0.05 then
            baseFront = Vector3.new(0, 0, -1)
        else
            baseFront = baseFront.Unit
        end

        -- Angles stay on the FRONT half of the object. If something blocks the exact
        -- prompt face, the script can slide around the obstruction without teleporting
        -- above the item or immediately jumping to an unrelated target.
        local angles = {0, 12, -12, 25, -25, 40, -40, 55, -55, 70, -70}
        local surfaceGaps = {0.55, 1.15, 2.0}
        local clearCandidates = {}
        local blockedCandidates = {}
        local playerHalfDepth = math.max(root.Size.Z * 0.5, 0.45)

        for _, gap in ipairs(surfaceGaps) do
            for _, angle in ipairs(angles) do
                local direction = rotateFlatDirection(baseFront, angle)
                local targetHalfDepth = 0

                if referencePart then
                    targetHalfDepth = projectedHalfExtent(referencePart.CFrame, referencePart.Size, direction)
                elseif obj:IsA("Model") then
                    local okBox, boxCF, boxSize = pcall(function()
                        local cf, size = obj:GetBoundingBox()
                        return cf, size
                    end)
                    if okBox and boxCF and boxSize then
                        targetHalfDepth = projectedHalfExtent(boxCF, boxSize, direction)
                    end
                end

                local centerOffset = targetHalfDepth + playerHalfDepth + gap
                local x = targetPosition.X + direction.X * centerOffset
                local z = targetPosition.Z + direction.Z * centerOffset
                local y = getGroundedCandidateY(character, obj, root, x, z, targetPosition.Y)

                -- Never allow an approach position that looks like an upper floor/roof.
                -- A normal avatar root may be a few studs above the interaction point,
                -- but anything beyond this is almost certainly the wrong vertical layer.
                if y <= targetPosition.Y + 5.0 then
                    local approachPosition = Vector3.new(x, y, z)

                    local flatLookTarget = Vector3.new(targetPosition.X, y, targetPosition.Z)
                if (flatLookTarget - approachPosition).Magnitude < 0.05 then
                    flatLookTarget = approachPosition - direction
                end

                local candidate = {
                    CFrame = CFrame.lookAt(approachPosition, flatLookTarget),
                    AimPosition = targetPosition,
                    Clear = candidateHasClearLine(character, obj, approachPosition, targetPosition, root),
                    Angle = angle,
                    Gap = gap
                }

                    if candidate.Clear then
                        table.insert(clearCandidates, candidate)
                    else
                        table.insert(blockedCandidates, candidate)
                    end
                end
            end
        end

        -- Always exhaust clear front positions first. Blocked positions are retained as
        -- a last resort because the ray test may disagree with the game's own prompt test.
        for _, candidate in ipairs(blockedCandidates) do
            table.insert(clearCandidates, candidate)
        end

        return clearCandidates
    end

    local function aimCameraOnceAt(position)
        if not position then return end
        -- No persistent BindToRenderStep camera lock. We only center the camera at the
        -- moment of an interaction attempt, then immediately give control back.
        aimCameraAt(position)
    end

    local function holdFForThreeSeconds(runId)

        if runId ~= ActiveAutomationRunId then
            return false
        end

        -- Aim before pressing F so the interaction prompt has a frame to appear.
        aimCameraAt(ActiveAutomationAimPosition)
        game:GetService("RunService").RenderStepped:Wait()
        aimCameraAt(ActiveAutomationAimPosition)

        setInteractionKeyHeld(true)

        local started = os.clock()

        while os.clock() - started < 3 do

            if runId ~= ActiveAutomationRunId then
                releaseInteractionKey()
                return false
            end

            -- Keep both the character and camera aimed at the interaction while frozen.
            if ActiveAutomationFreezeState
                and ActiveAutomationFreezeState.Character
                and ActiveAutomationFreezeState.Character.Parent then

                releaseMovementInput()
                clearCharacterMomentum(ActiveAutomationFreezeState.Character)
                aimCameraAt(ActiveAutomationAimPosition)

            end

            task.wait(0.05)

        end

        releaseInteractionKey()

        return true

    end

    local function processAutomationEntry(entry, typeName, runId)

        if not entry or not entry.Object or runId ~= ActiveAutomationRunId then
            return false
        end

        local obj = entry.Object
        if not isAutomationTargetAvailable(obj) then
            return false
        end

        local settings = TeleportTargets[typeName]
        if not settings then
            return false
        end

        -- Airdrops are registered in Workspace before they necessarily reach the
        -- ground. Never teleport to an airborne AirdropUnlockable.
        if typeName == "Airdrops" then
            local landed = isAirdropSafelyLanded(obj)

            if not landed then
                notifyAutomation("Airdrop is still airborne. Waiting for it to land...")

                landed = waitForAirdropLanded(obj, runId, 45)
                if not landed then
                    notifyAutomation("Airdrop did not reach a safe landing position. Teleport cancelled.")
                    return false
                end
            end
        end

        -- Re-read the CFrame AFTER the landing wait because the airdrop may have
        -- moved a large distance while descending.
        local destination = getTeleportCFrame(obj, settings.Inner)
        if not destination then
            return false
        end

        local localPlayer = game:GetService("Players").LocalPlayer
        local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
        if not character or runId ~= ActiveAutomationRunId then
            return false
        end

        -- Build several FRONT-hemisphere, floor-level candidate positions. Clear LOS
        -- candidates come first so walls/crates/props in front of the prompt are avoided.
        local candidates = getInteractionApproachCandidates(character, obj, destination, settings.Inner)
        if #candidates == 0 then
            local fallbackCFrame, fallbackAim = getInteractionApproachCFrame(character, obj, destination, settings.Inner)
            if fallbackCFrame then
                candidates = {{CFrame = fallbackCFrame, AimPosition = fallbackAim, Clear = true}}
            end
        end

        -- IMPORTANT: no camera lock and no "F held means success" shortcut. The script
        -- does not advance to the next key/safe/airdrop until PickupCallback itself
        -- returns true for THIS object.
        for _, candidate in ipairs(candidates) do
            if runId ~= ActiveAutomationRunId or not isAutomationTargetAvailable(obj) then
                return false
            end

            if stabilizedTeleport(character, candidate.CFrame) then
                local freezeState = freezeCharacterForInteraction(character)
                if freezeState then
                    ActiveAutomationAimPosition = candidate.AimPosition

                    -- Rotate/position first, then center the camera ONCE. We explicitly do
                    -- not BindToRenderStep, so normal camera control is not continuously locked.
                    aimCameraOnceAt(candidate.AimPosition)
                    game:GetService("RunService").RenderStepped:Wait()
                    aimCameraOnceAt(candidate.AimPosition)
                    task.wait(0.08)

                    local remoteCalled = false
                    local remoteResult = nil

                    -- For safes / advanced safes / airdrops, capture the flare set and
                    -- world position BEFORE opening the unlockable. The object may be
                    -- destroyed/replaced immediately after PickupCallback succeeds.
                    local flaresBefore = nil
                    local unlockPosition = nil

                    if isUnlockableAutomationType(typeName) then
                        flaresBefore = snapshotInteractionFlares()
                        unlockPosition = objectWorldPosition(obj)
                    end

                    if isKeyAutomationType(typeName) then
                        remoteCalled, remoteResult = invokeDirectPickupRemote(obj)
                    elseif isUnlockableAutomationType(typeName) then
                        remoteCalled, remoteResult = invokeCapturedUnlockable(obj)
                    end

                    local accepted = remoteCalled and remoteResult == true

                    ActiveAutomationAimPosition = nil

                    if accepted then
                        if isUnlockableAutomationType(typeName) then
                            -- IMPORTANT: keep the character anchored after the safe/drop
                            -- has been validated as opened. The game tends to leave stale
                            -- movement velocity around this transition, which can cause
                            -- uncontrolled drifting while the reward Flare is being claimed.
                            --
                            -- We therefore KEEP freezeState active through:
                            --   opened safe -> reward Flare -> Rewards -> RequestTake
                            -- and only unfreeze after reward pickup is confirmed.
                            releaseMovementInput()
                            clearCharacterMomentum(character)

                            local rewardFlare = waitForSafeInteractionFlare(
                                flaresBefore,
                                unlockPosition,
                                2.5
                            )

                            if not rewardFlare then
                                unfreezeCharacterAfterInteraction(freezeState)
                                return false
                            end

                            local rewardsTaken = processOpenedSafeFlare(rewardFlare, runId)

                            -- Whether the reward phase succeeded or timed out, always restore
                            -- control before returning from this target.
                            unfreezeCharacterAfterInteraction(freezeState)

                            if not rewardsTaken then
                                return false
                            end
                        else
                            -- Keys only need the short interaction freeze; they have no
                            -- InteractionFlare reward stage.
                            unfreezeCharacterAfterInteraction(freezeState)
                        end

                        AutomationProcessedTargets[obj] = true

                        game:GetService("RunService").Heartbeat:Wait()
                        return true
                    end

                    -- The server rejected the pickup/open request. Restore control and
                    -- stay on the SAME target rather than teleporting onward.
                    unfreezeCharacterAfterInteraction(freezeState)
                    task.wait(0.06)
                end
            end
        end

        ActiveAutomationAimPosition = nil
        return false

    end

    local function runAutomationGroup(group)

        do
            local smartDesyncState =
                rawget(_G, "__VITALITY_TOWER_SMART_DESYNC")

            if type(smartDesyncState) == "table"
                and smartDesyncState.Enabled == true then

                pcall(function()
                    Window:Notify({
                        Title = "SMART DESYNC",
                        Content = "Turn Smart Desync off in order to use this function.",
                        Duration = 6,
                        Success = false,
                    })
                end)

                return
            end
        end

        if AutomationRunning then
            notifyAutomation("Another grab/unlock run is already in progress.")
            return
        end

        AutomationRunning = true
        ActiveAutomationRunId = ActiveAutomationRunId + 1

        local runId = ActiveAutomationRunId
        local completedAtLeastOnePair = false
        local completedAtLeastOneKey = false
        local pendingCollectedKey = false
        local stoppedForMissingKey = false
        local rejectedTargetLabel = nil

        -- Key replication in The Tower can lag behind PickupCallback / safe usage.
        -- Track our own confirmed pickups and spends alongside the replicated
        -- LocalPlayer key NumberValue so automation never depends on one source alone.
        local lastReplicatedKeyCount = roundedCount(readLocalPlayerNumber(group.KeyValueName))
        local pendingPickupCredits = 0
        local pendingSpendDebits = 0

        local function refreshEffectiveKeyCount()
            local replicatedCount = roundedCount(readLocalPlayerNumber(group.KeyValueName))
            local replicatedChange = replicatedCount - lastReplicatedKeyCount

            -- Positive replication changes acknowledge locally-confirmed pickups.
            if replicatedChange > 0 and pendingPickupCredits > 0 then
                pendingPickupCredits = math.max(0, pendingPickupCredits - replicatedChange)
            end

            -- Negative replication changes acknowledge locally-confirmed key spends.
            if replicatedChange < 0 and pendingSpendDebits > 0 then
                pendingSpendDebits = math.max(0, pendingSpendDebits - (-replicatedChange))
            end

            lastReplicatedKeyCount = replicatedCount

            -- Effective balance = what Roblox currently reports, plus successful
            -- pickups that have not replicated yet, minus successful unlocks that
            -- have not replicated yet.
            local effectiveCount = math.max(
                0,
                replicatedCount + pendingPickupCredits - pendingSpendDebits
            )

            pendingCollectedKey = effectiveCount >= 1
            return effectiveCount, replicatedCount
        end

        local function recordConfirmedKeyPickup()
            pendingPickupCredits = pendingPickupCredits + 1
            return refreshEffectiveKeyCount()
        end

        local function recordConfirmedKeySpend()
            pendingSpendDebits = pendingSpendDebits + 1
            return refreshEffectiveKeyCount()
        end

        task.spawn(function()

            local ok, err = xpcall(function()

                while runId == ActiveAutomationRunId do
                    local targetsByType = rebuildTeleportNumberMap()
                    local keys = getAvailableAutomationEntries(group.KeyType, targetsByType)
                    local unlockables = getAvailableAutomationEntries(group.UnlockType, targetsByType)

                    -- Use BOTH sources:
                    --   1) replicated inventory count
                    --   2) successful pickups/spends confirmed by this automation run
                    local effectiveKeyCount = refreshEffectiveKeyCount()

                    if #keys == 0 and #unlockables == 0 then
                        break
                    end

                    -- If a matching key is already in inventory and an unlockable exists,
                    -- skip collecting another loose key and use the inventory key first.
                    -- Loose keys are still collected when there is no unlockable left.
                    if #keys > 0 and (#unlockables == 0 or not pendingCollectedKey) then
                        local keyEntry = keys[1]
                        local keyCompleted = processAutomationEntry(keyEntry, group.KeyType, runId)

                        if runId ~= ActiveAutomationRunId then
                            break
                        end

                        if not keyCompleted then
                            -- PickupCallback never returned true from any clear front position.
                            -- Stop on this object; NEVER skip it and teleport to another key.
                            rejectedTargetLabel = group.KeyLabel
                            break
                        end

                        completedAtLeastOneKey = true

                        -- PickupCallback already returned true, so immediately credit this
                        -- key locally. We no longer block on the replicated NumberValue.
                        -- If replication catches up later, refreshEffectiveKeyCount()
                        -- reconciles the local credit automatically.
                        recordConfirmedKeyPickup()

                        -- Tiny settle only for movement/network ordering; this is NOT an
                        -- inventory-validation gate.
                        task.wait(0.08)

                    end

                    targetsByType = rebuildTeleportNumberMap()
                    unlockables = getAvailableAutomationEntries(group.UnlockType, targetsByType)

                    if #unlockables > 0 then
                        -- Reconcile immediately before the safe/drop. A key is considered
                        -- available if EITHER Roblox reports it in inventory OR we have a
                        -- successful PickupCallback credit that has not been spent yet.
                        effectiveKeyCount = refreshEffectiveKeyCount()

                        local remainingKeys = getAvailableAutomationEntries(group.KeyType, targetsByType)
                        if effectiveKeyCount < 1 and #remainingKeys == 0 then
                            stoppedForMissingKey = true
                            break
                        end

                        if effectiveKeyCount < 1 then
                            continue
                        end

                        local unlockEntry = unlockables[1]
                        local unlockCompleted = processAutomationEntry(unlockEntry, group.UnlockType, runId)

                        if runId ~= ActiveAutomationRunId then
                            break
                        end

                        if not unlockCompleted then
                            -- Same rule for safes/advanced safes/airdrops: no true callback,
                            -- no next teleport.
                            rejectedTargetLabel = group.UnlockLabel
                            break
                        end

                        completedAtLeastOnePair = true

                        -- The unlock/reward sequence completed, so account for one key
                        -- immediately even if the replicated inventory has not decremented yet.
                        recordConfirmedKeySpend()
                    end
                end

            end, function(errorMessage)
                return tostring(errorMessage)
            end)

            -- Compatibility cleanup. Persistent camera locking is no longer used, but
            -- unbinding an old execution is harmless and prevents stale locks on re-run.
            stopAutomationCameraLock()
            ActiveAutomationAimPosition = nil
            releaseInteractionKey()

            if ActiveAutomationFreezeState then
                unfreezeCharacterAfterInteraction(ActiveAutomationFreezeState)
            end

            local character = game:GetService("Players").LocalPlayer.Character
            if character then
                releaseMovementInput()
                clearCharacterMomentum(character)
            end

            AutomationRunning = false

            if not ok then
                notifyAutomation("Automation stopped: " .. tostring(err))
                return
            end

            if runId ~= ActiveAutomationRunId then
                return
            end

            if rejectedTargetLabel then
                notifyAutomation(
                    rejectedTargetLabel
                    .. " interaction did not complete. Stayed on that target because the pickup/reward sequence was not confirmed."
                )
                return
            end

            if stoppedForMissingKey then
                notifyAutomation("No unused keys were found for the remaining " .. group.UnlockLabel .. "s.")
                return
            end

            if completedAtLeastOnePair or completedAtLeastOneKey then
                notifyAutomation(group.DoneMessage)
            else
                notifyAutomation("No unused " .. group.KeyLabel .. "s or unopened " .. group.UnlockLabel .. "s were found.")
            end

        end)

    end

    safeAutomationSection:AddButton("Grab Keys + Unlock Safes", function()
        runAutomationGroup(AutomationGroups.Safes)
    end)

    advancedSafeAutomationSection:AddButton("Grab Keys + Unlock Advanced Safes", function()
        runAutomationGroup(AutomationGroups.AdvancedSafes)
    end)

    airdropAutomationSection:AddButton("Grab Keys + Unlock Airdrops", function()
        runAutomationGroup(AutomationGroups.Airdrops)
    end)

    -- Automation target counts scan once when the script starts, then one final
    -- startup rescan 10 seconds later. After that, they only rescan manually
    -- through the RESCAN TARGETS button.
    task.defer(refreshAutomationStatus)
    task.delay(10, refreshAutomationStatus)

    -- Find the green end flare. This stays separate from the normal flare target list.
    local function findExtractFlare()

        local matches = {}

        for _, obj in ipairs(workspace:GetDescendants()) do

            if obj.Name == "Flare"
                and (obj:IsA("Model") or obj:IsA("BasePart"))
                and isGreenFlare(obj) then

                table.insert(matches, obj)

            end

        end

        table.sort(matches, function(a, b)

            return a:GetFullName() < b:GetFullName()

        end)

        return matches[1]

    end

    local ExtractVisualsEnabled = false
    local ExtractVisualData = nil
    local ExtractVisualButton = nil

    local function clearExtractVisuals()

        if ExtractVisualData then

            if ExtractVisualData.Gui then
                pcall(function() ExtractVisualData.Gui:Destroy() end)
            end

            if ExtractVisualData.Highlight then
                pcall(function() ExtractVisualData.Highlight:Destroy() end)
            end

        end

        ExtractVisualData = nil

    end

    local function createExtractVisuals()

        local flare = findExtractFlare()

        if not flare then
            clearExtractVisuals()
            return nil
        end

        if ExtractVisualData
            and ExtractVisualData.Flare == flare
            and ExtractVisualData.Gui
            and ExtractVisualData.Gui.Parent
            and ExtractVisualData.Highlight
            and ExtractVisualData.Highlight.Parent then

            return flare

        end

        clearExtractVisuals()

        local part

        if flare:IsA("BasePart") then
            part = flare
        else
            part = flare.PrimaryPart or flare:FindFirstChildWhichIsA("BasePart", true)
        end

        if not part then
            return flare
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "TheTower_ExtractChams"
        highlight.Adornee = flare
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(0, 255, 0)
        highlight.FillTransparency = 0.45
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Parent = game:GetService("CoreGui")

        local gui = Instance.new("BillboardGui")
        gui.Name = "TheTower_ExtractESP"
        gui.Adornee = part
        gui.Size = UDim2.fromOffset(220, 50)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        gui.AlwaysOnTop = true
        gui.Parent = game:GetService("CoreGui")

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = "Extract"
        label.TextColor3 = Color3.fromRGB(0, 255, 0)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.GothamBold
        label.TextSize = 18
        label.Parent = gui

        ExtractVisualData = {
            Flare = flare,
            Part = part,
            Gui = gui,
            Label = label,
            Highlight = highlight
        }

        return flare

    end

    -- Standalone extract teleport. This does not depend on the target dropdown.
    extractSection:AddButton("Extract", function()

        local flare = findExtractFlare()
        if not flare then return end

        local cf = getTeleportCFrame(flare, nil)
        local char = game.Players.LocalPlayer.Character

        if not cf or not char then return end

        local moved = stabilizedTeleport(char, cf + Vector3.new(0, 5, 0))

        -- Extract gets a longer post-teleport stabilization than normal manual
        -- key/safe teleports. Hold the character still for one second so stale
        -- movement/input cannot make the player drift away from the extract point.
        if moved then
            brieflyFreezeAfterManualTeleport(char, 1.0)
        end

    end)

    -- Standalone Extract ESP + chams button. Press once to enable, again to disable.
    ExtractVisualButton = MainTab:CreateButton({

        Name = "Extract ESP + Chams",
        Interact = "OFF",
        SectionParent = extractSection._Section,

        Callback = function()

            ExtractVisualsEnabled = not ExtractVisualsEnabled

            if ExtractVisualsEnabled then
                createExtractVisuals()
            else
                clearExtractVisuals()
            end

            pcall(function()
                ExtractVisualButton:Set(nil, ExtractVisualsEnabled and "ON" or "OFF")
            end)

        end

    })

    local function scanTeleportTargets()

        local previousTarget = selectedTeleportTarget
        local allTargets = rebuildTeleportNumberMap()
        local found = allTargets[selectedTeleportType] or {}

        targetOptions, targetObjects = {}, {}

        for index, entry in ipairs(found) do

            table.insert(targetOptions, string.format("#%d - %s", index, entry.Path))
            table.insert(targetObjects, entry.Object)

        end

        -- Preserve the selected world object across automatic rescans.
        selectedTeleportTarget = nil

        if previousTarget then

            for _, obj in ipairs(targetObjects) do
                if obj == previousTarget then
                    selectedTeleportTarget = previousTarget
                    break
                end
            end

        end

        if not selectedTeleportTarget then
            selectedTeleportTarget = targetObjects[1]
        end

    end

    -- vitality's hub dropdowns support Refresh(), so target options are updated
    -- in-place without destroying/recreating controls or disturbing section layout.
    local targetDropdownSignature = nil

    local function getTargetSignature()

        return table.concat(targetOptions, "\31")

    end

    local function handleTargetChoice(choice)

        if type(choice) == "table" then choice = choice[1] end

        for i, path in ipairs(targetOptions) do

            if path == choice then

                selectedTeleportTarget = targetObjects[i]

                local settings = TeleportTargets[selectedTeleportType]

                local old = runnerSection

                if settings and selectedTeleportTarget then

    -- Highlight is created on the selected object and cleaned

    -- when another target is selected.

                    if old._Highlight and old._Highlight.Parent then

                        old._Highlight:Destroy()

                    end

                    local adorn = selectedTeleportTarget

                    if adorn:IsA("Model") or adorn:IsA("BasePart") then

                        local hl = Instance.new("Highlight")

                        hl.Name = "TheTower_SelectedTeleport"

                        hl.Adornee = adorn

                        hl.FillColor = settings.Color

                        hl.FillTransparency = 0.55

                        hl.OutlineColor = Color3.fromRGB(255,255,255)

                        hl.Parent = game:GetService("CoreGui")

                        old._Highlight = hl

                    end

                end

                break

            end

        end

    end

    local function rebuildTargetDropdown(force)
        local signature = getTargetSignature()

        if targetDropdown and not force and signature == targetDropdownSignature then
            return
        end

        local currentOption = targetOptions[1] or "No targets"
        if selectedTeleportTarget then
            for index, obj in ipairs(targetObjects) do
                if obj == selectedTeleportTarget then
                    currentOption = targetOptions[index] or currentOption
                    break
                end
            end
        end

        if not targetDropdown then
            targetDropdown = runnerSection:AddDropdown(
                "Select Target",
                targetOptions,
                currentOption,
                false,
                handleTargetChoice
            )
        else
            -- vitality's hub supports in-place option refresh, so the control keeps
            -- its original layout position instead of being destroyed/recreated.
            targetDropdown:Refresh(targetOptions, true)
            targetDropdown:Set(currentOption, false)
        end

        targetDropdownSignature = signature
    end

    local function refreshTargetDropdown(force)

        scanTeleportTargets()

        rebuildTargetDropdown(force == true)

    end

    runnerSection:AddDropdown("Teleport Type", TeleportTypeNames, TeleportTypeNames[1], false, function(choice)

        if type(choice) == "table" then choice = choice[1] end

        if TeleportTargets[choice] then

            selectedTeleportType = choice

            -- Force a rebuild because the available targets belong to a new type.
            refreshTargetDropdown(true)

        end

    end)

    scanTeleportTargets()

    rebuildTargetDropdown(true)

    runnerSection:AddButton("TELEPORT TO TARGET", function()

        local target = selectedTeleportTarget

        local settings = TeleportTargets[selectedTeleportType]

        if not target or not settings then return end

        -- Manual airdrop teleports get the same landing protection as
        -- automation. Do not send the player hundreds of studs into the air.
        if selectedTeleportType == "Airdrops" then
            local landed = waitForAirdropLanded(target, nil, 1.25)

            if not landed then
                notifyAutomation("That airdrop is still airborne. Wait for it to land before teleporting.")
                return
            end
        end

        -- Read the destination only after the landing check because the target can
        -- move substantially while descending.
        local cf = getTeleportCFrame(target, settings.Inner)

        local char = game.Players.LocalPlayer.Character

        if not cf or not char then return end

        local moved = stabilizedTeleport(char, cf + Vector3.new(0, 5, 0))

        -- Manual key/safe/airdrop teleports get a very short anchor after arrival.
        -- This kills residual velocity without making the manual teleport feel sticky.
        if moved
            and (
                isKeyAutomationType(selectedTeleportType)
                or isUnlockableAutomationType(selectedTeleportType)
            ) then

            brieflyFreezeAfterManualTeleport(char, 0.28)
        end

    end)

    runnerSection:AddButton("RESCAN TARGETS", function()
        refreshTargetDropdown()
        refreshAutomationStatus()
    end)

    -- Stability patch: permanent 10-second target polling removed.
    -- Existing startup scan, Workspace add/remove events, manual rescan,
    -- and the single delayed startup refresh remain unchanged.

    runnerSection:AddButton("CLEAR TARGET HIGHLIGHT", function()

        if runnerSection._Highlight and runnerSection._Highlight.Parent then

            runnerSection._Highlight:Destroy()

        end

        runnerSection._Highlight = nil

    end)


    -- ============================================================

    -- ITEM / OBJECT ESP

    -- ============================================================

    -- Floating labels above important world objects.

    -- Each object type has its own toggle and the text scales with distance.

    local ItemESPEnabled = false

    local ItemESPShowDistance = true

    local ItemESPMaxDistance = 500

    local ItemESPMinTextSize = 10

    local ItemESPMaxTextSize = 24

    local ItemESPHeight = 3

    local ItemESPStroke = true

    local ItemESPCache = {}

    -- Independent item chams. These do NOT depend on Item ESP being enabled.

    local ItemChamsEnabled = false

    local ItemChamsFillTransparency = 0.45

    local ItemChamsOutlineTransparency = 0

    local ItemChamsFillColor = Color3.fromRGB(0, 170, 255)

    local ItemChamsOutlineColor = Color3.fromRGB(255, 255, 255)

    local ItemChamsCache = {}

    local ItemESPObjects = {

        SafeKey = "Key",

        KeyUnlockable = "Key",

        AdvancedSafeKey = "Advanced Key",

        AirdropKey = "Airdrop Key",

        SafeUnlockable = "Safe",

        AdvancedSafeUnlockable = "Advanced Safe",

        AirdropUnlockable = "Airdrop",

        Flare = "Flare",

        EffectDropServer = "Effect Drop",

        SmokeVolume = "Smoke",

        SmokeGrenadeMesh = "Smoke",

        Glare = "Glare"

    }

    -- Individual switches. Keys/safes/etc. are grouped by display name.

    local ItemESPTypeEnabled = {

        ["Key"] = true,

        ["Advanced Key"] = true,

        ["Airdrop Key"] = true,

        ["Safe"] = true,

        ["Advanced Safe"] = true,

        ["Airdrop"] = true,

        ["Flare"] = true,

        ["Effect Drop"] = true,

        ["Smoke"] = true,

        ["Glare"] = true

    }

    local function getItemESPDisplayName(obj)

        local displayName = ItemESPObjects[obj.Name]

        local teleportNumber = TeleportNumberByObject[obj]

        if displayName == "Flare" and isGreenFlare(obj) then
            if teleportNumber then
                return string.format("Extract #%d", teleportNumber)
            end
            return "Extract"
        end

        if displayName and teleportNumber then
            return string.format("%s #%d", displayName, teleportNumber)
        end

        return displayName

    end

    local function getESPPart(obj)

        if obj:IsA("BasePart") then

            return obj

        end

        if obj:IsA("Model") then

            if obj.PrimaryPart then

                return obj.PrimaryPart

            end

            return obj:FindFirstChildWhichIsA("BasePart", true)

        end

        return nil

    end

    local function destroyItemChams(obj)

        local highlight = ItemChamsCache[obj]

        if highlight then

            pcall(function()

                highlight:Destroy()

            end)

        end

        ItemChamsCache[obj] = nil

    end

    local function createItemChams(obj)

        local displayName = ItemESPObjects[obj.Name]

        if not ItemChamsEnabled or not displayName or not ItemESPTypeEnabled[displayName] then

            return

        end

        if ItemChamsCache[obj] and ItemChamsCache[obj].Parent then

            return

        end

        local adornee = obj

        if not obj:IsA("Model") and not obj:IsA("BasePart") then

            adornee = obj:FindFirstAncestorOfClass("Model") or getESPPart(obj)

        end

        if not adornee or (not adornee:IsA("Model") and not adornee:IsA("BasePart")) then

            return

        end

        local highlight = Instance.new("Highlight")

        highlight.Name = "TheTower_ItemChams"

        highlight.Adornee = adornee

        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

        highlight.FillColor = ItemChamsFillColor

        highlight.FillTransparency = ItemChamsFillTransparency

        highlight.OutlineColor = ItemChamsOutlineColor

        highlight.OutlineTransparency = ItemChamsOutlineTransparency

        highlight.Parent = game:GetService("CoreGui")

        ItemChamsCache[obj] = highlight

    end

    local function scanItemChams()

        if not ItemChamsEnabled then

            return

        end

        for obj, highlight in pairs(ItemChamsCache) do

            if not obj.Parent or not highlight or not highlight.Parent then

                destroyItemChams(obj)

            end

        end

        for _, obj in ipairs(workspace:GetDescendants()) do

            if ItemESPObjects[obj.Name] then

                local displayName = ItemESPObjects[obj.Name]

                if ItemESPTypeEnabled[displayName] then

                    createItemChams(obj)

                end

            end

        end

    end

    local function updateItemChams()

        for _, highlight in pairs(ItemChamsCache) do

            if highlight and highlight.Parent then

                highlight.FillColor = ItemChamsFillColor

                highlight.FillTransparency = ItemChamsFillTransparency

                highlight.OutlineColor = ItemChamsOutlineColor

                highlight.OutlineTransparency = ItemChamsOutlineTransparency

            end

        end

    end

    local function destroyItemESP(obj)

        local data = ItemESPCache[obj]

        if data and data.Gui then

            data.Gui:Destroy()

        end

        ItemESPCache[obj] = nil

    end

    local function createItemESP(obj)

        local filterName = ItemESPObjects[obj.Name]
        local displayName = getItemESPDisplayName(obj)

        if not ItemESPEnabled or not filterName or not displayName or not ItemESPTypeEnabled[filterName] then

            return

        end

        if ItemESPCache[obj] then

            return

        end

        local part = getESPPart(obj)

        if not part then

            return

        end

        local gui = Instance.new("BillboardGui")

        gui.Name = "TheTower_ItemESP"

        gui.Adornee = part

        gui.Size = UDim2.fromOffset(220, 50)

        gui.StudsOffset = Vector3.new(0, ItemESPHeight, 0)

        gui.AlwaysOnTop = true

        gui.MaxDistance = ItemESPMaxDistance

        gui.Parent = game:GetService("CoreGui")

        local label = Instance.new("TextLabel")

        label.Name = "Label"

        label.Size = UDim2.fromScale(1, 1)

        label.BackgroundTransparency = 1

        label.Text = displayName

        label.TextColor3 = Color3.fromRGB(255, 255, 255)

        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

        label.TextStrokeTransparency = ItemESPStroke and 0 or 1

        label.Font = Enum.Font.GothamBold

        label.TextScaled = false

        label.Parent = gui

        ItemESPCache[obj] = {

            Gui = gui,

            Label = label,

            Part = part

        }

    end

    local function scanItemESP()

        if not ItemESPEnabled then

            return

        end

        for obj, data in pairs(ItemESPCache) do

            if not obj.Parent or not data.Gui or not data.Gui.Parent then

                destroyItemESP(obj)

            end

        end

        for _, obj in ipairs(workspace:GetDescendants()) do

            if ItemESPObjects[obj.Name] then

                local displayName = ItemESPObjects[obj.Name]

                if ItemESPTypeEnabled[displayName] then

                    createItemESP(obj)

                end

            end

        end

    end

    local function setItemTypeEnabled(displayName, enabled)

        ItemESPTypeEnabled[displayName] = enabled

        for obj, _ in pairs(ItemESPCache) do

            if ItemESPObjects[obj.Name] == displayName then

                destroyItemESP(obj)

            end

        end

        for obj, _ in pairs(ItemChamsCache) do

            if ItemESPObjects[obj.Name] == displayName then

                destroyItemChams(obj)

            end

        end

        if enabled and ItemESPEnabled then

            scanItemESP()

        end

    end

    local function clearItemESP()

        for obj, data in pairs(ItemESPCache) do

            if data.Gui then

                data.Gui:Destroy()

            end

            ItemESPCache[obj] = nil

        end

    end

    local itemEspSection = CreateCategorySector(ItemVisualsTab, "Core Item Visuals")

    local itemTypesSection = CreateCategorySector(ItemVisualsTab, "Item Filters")

    local itemEspSettingsSection = CreateCategorySector(ItemVisualsTab, "ESP Settings")

    local itemChamsSection = CreateCategorySector(ItemVisualsTab, "Chams Settings")

    itemEspSection:AddToggle("Item ESP", false, function(state)

        ItemESPEnabled = state

        if state then

            scanItemESP()

        else

            clearItemESP()

        end

    end)

    itemEspSection:AddToggle("Item Chams", false, function(state)

        ItemChamsEnabled = state

        if state then

            scanItemChams()

        else

            for obj, _ in pairs(ItemChamsCache) do

                destroyItemChams(obj)

            end

        end

    end)

    itemEspSettingsSection:AddToggle("Show Distance", true, function(state)

        ItemESPShowDistance = state

    end)

    -- Individual ESP toggles

    itemTypesSection:AddToggle("Keys", true, function(state)

        setItemTypeEnabled("Key", state)

    end)

    itemTypesSection:AddToggle("Advanced Keys", true, function(state)

        setItemTypeEnabled("Advanced Key", state)

    end)

    itemTypesSection:AddToggle("Airdrop Keys", true, function(state)

        setItemTypeEnabled("Airdrop Key", state)

    end)

    itemTypesSection:AddToggle("Safes", true, function(state)

        setItemTypeEnabled("Safe", state)

    end)

    itemTypesSection:AddToggle("Advanced Safes", true, function(state)

        setItemTypeEnabled("Advanced Safe", state)

    end)

    itemTypesSection:AddToggle("Airdrops", true, function(state)

        setItemTypeEnabled("Airdrop", state)

    end)

    itemTypesSection:AddToggle("Flares", true, function(state)

        setItemTypeEnabled("Flare", state)

    end)

    itemTypesSection:AddToggle("Effect Drops", true, function(state)

        setItemTypeEnabled("Effect Drop", state)

    end)

    itemTypesSection:AddToggle("Smoke", true, function(state)

        setItemTypeEnabled("Smoke", state)

    end)

    itemTypesSection:AddToggle("Glare", true, function(state)

        setItemTypeEnabled("Glare", state)

    end)

    ItemVisualsTab:CreateSlider({

        Name = "ESP Max Distance",

        Flag = "Tower_ItemESP_MaxDistance",

        Info = "Maximum distance at which item labels are visible.",

        Range = {50, 2000},

        Increment = 25,

        Suffix = " studs",

        CurrentValue = 500,

        SectionParent = itemEspSettingsSection._Section,

        Callback = function(value)

            ItemESPMaxDistance = value

            for _, data in pairs(ItemESPCache) do

                if data.Gui then

                    data.Gui.MaxDistance = value

                end

            end

        end

    })

    ItemVisualsTab:CreateSlider({

        Name = "ESP Min Text Size",

        Flag = "Tower_ItemESP_MinTextSize",

        Info = "Smallest text size at long range.",

        Range = {6, 20},

        Increment = 1,

        Suffix = " px",

        CurrentValue = 10,

        SectionParent = itemEspSettingsSection._Section,

        Callback = function(value)

            ItemESPMinTextSize = value

        end

    })

    ItemVisualsTab:CreateSlider({

        Name = "ESP Max Text Size",

        Flag = "Tower_ItemESP_MaxTextSize",

        Info = "Largest text size when close to an item.",

        Range = {12, 40},

        Increment = 1,

        Suffix = " px",

        CurrentValue = 24,

        SectionParent = itemEspSettingsSection._Section,

        Callback = function(value)

            ItemESPMaxTextSize = value

        end

    })

    ItemVisualsTab:CreateSlider({

        Name = "ESP Height",

        Flag = "Tower_ItemESP_Height",

        Info = "Vertical offset above each item.",

        Range = {1, 10},

        Increment = 0.5,

        Suffix = " studs",

        CurrentValue = 3,

        SectionParent = itemEspSettingsSection._Section,

        Callback = function(value)

            ItemESPHeight = value

            for _, data in pairs(ItemESPCache) do

                if data.Gui then

                    data.Gui.StudsOffset = Vector3.new(0, value, 0)

                end

            end

        end

    })

    ItemVisualsTab:CreateToggle({

        Name = "Text Outline",

        Flag = "Tower_ItemESP_TextOutline",

        Info = "Adds a black outline around ESP text.",

        CurrentValue = true,

        SectionParent = itemEspSettingsSection._Section,

        Callback = function(state)

            ItemESPStroke = state

            for _, data in pairs(ItemESPCache) do

                if data.Label then

                    data.Label.TextStrokeTransparency = state and 0 or 1

                end

            end

        end

    })

    ItemVisualsTab:CreateColorPicker({

        Name = "Chams Fill Color",

        Flag = "Tower_ItemChams_FillColor",

        Color = ItemChamsFillColor,

        SectionParent = itemChamsSection._Section,

        Callback = function(color)

            ItemChamsFillColor = color

            updateItemChams()

        end

    })

    ItemVisualsTab:CreateSlider({

        Name = "Chams Fill Transparency",

        Flag = "Tower_ItemChams_FillTransparency",

        Info = "Controls how see-through the item chams are.",

        Range = {0, 1},

        Increment = 0.05,

        Suffix = "",

        CurrentValue = 0.45,

        SectionParent = itemChamsSection._Section,

        Callback = function(value)

            ItemChamsFillTransparency = value

            updateItemChams()

        end

    })

    ItemVisualsTab:CreateColorPicker({

        Name = "Chams Outline Color",

        Flag = "Tower_ItemChams_OutlineColor",

        Color = ItemChamsOutlineColor,

        SectionParent = itemChamsSection._Section,

        Callback = function(color)

            ItemChamsOutlineColor = color

            updateItemChams()

        end

    })

    ItemVisualsTab:CreateSlider({

        Name = "Chams Outline Transparency",

        Flag = "Tower_ItemChams_OutlineTransparency",

        Info = "Controls how visible the chams outline is.",

        Range = {0, 1},

        Increment = 0.05,

        Suffix = "",

        CurrentValue = 0,

        SectionParent = itemChamsSection._Section,

        Callback = function(value)

            ItemChamsOutlineTransparency = value

            updateItemChams()

        end

    })

    ItemVisualsTab:CreateButton({

        Name = "Rescan Items",

        Info = "Find newly spawned keys, safes, airdrops and other objects.",

        SectionParent = itemEspSection._Section,

        Callback = function()

            if ItemESPEnabled then

                scanItemESP()

            end

        end

    })

    Window:TrackConnection(game:GetService("RunService").RenderStepped:Connect(function()

        if not ItemESPEnabled then

            return

        end

        local character = game.Players.LocalPlayer.Character

        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not root then

            return

        end

        for obj, data in pairs(ItemESPCache) do

            if not obj.Parent or not data.Part or not data.Part.Parent then

                destroyItemESP(obj)

            elseif not ItemESPTypeEnabled[ItemESPObjects[obj.Name]] then

                destroyItemESP(obj)

            else

                local distance = (root.Position - data.Part.Position).Magnitude

                if distance > ItemESPMaxDistance then

                    data.Gui.Enabled = false

                else

                    data.Gui.Enabled = true

                    local alpha = 1 - math.clamp(distance / ItemESPMaxDistance, 0, 1)

                    local size = ItemESPMinTextSize

                        + (ItemESPMaxTextSize - ItemESPMinTextSize) * alpha

                    data.Label.TextSize = math.floor(size + 0.5)

                    if ItemESPShowDistance then

                        data.Label.Text = string.format(

                            "%s [%.0f studs]",

                            getItemESPDisplayName(obj),

                            distance

                        )

                    else

                        data.Label.Text = getItemESPDisplayName(obj)

                    end

                end

            end

        end

    end))

    local function isTeleportableObject(obj)

        if not obj or (not obj:IsA("Model") and not obj:IsA("BasePart")) then
            return false
        end

        for _, settings in pairs(TeleportTargets) do
            for _, targetName in ipairs(settings.Names) do
                if obj.Name == targetName then
                    return true
                end
            end
        end

        return false

    end

    Window:TrackConnection(workspace.DescendantAdded:Connect(function(obj)

        if isTeleportableObject(obj) then
            task.delay(0.2, function()
                refreshTargetDropdown()
            end)
        end

        if ItemESPObjects[obj.Name] then

            task.defer(function()

                if ItemESPEnabled then

                    createItemESP(obj)

                end

                if ItemChamsEnabled then

                    createItemChams(obj)

                end

                if ExtractVisualsEnabled and obj.Name == "Flare" then

                    task.wait(0.15)
                    createExtractVisuals()

                end

            end)

        elseif ExtractVisualsEnabled then

            task.defer(function()
                task.wait(0.15)
                createExtractVisuals()
            end)

        end

    end))

    Window:TrackConnection(workspace.DescendantRemoving:Connect(function(obj)

        if isTeleportableObject(obj) then
            task.defer(function()
                refreshTargetDropdown()
            end)
        end

        if ExtractVisualData and (obj == ExtractVisualData.Flare or obj == ExtractVisualData.Part) then

            clearExtractVisuals()

        end

        if ItemESPCache[obj] then

            destroyItemESP(obj)

        end

        if ItemChamsCache[obj] then

            destroyItemChams(obj)

        end

    end))

    -- ============================================================
    -- PLAYER ESP
    -- Compiler-safe refactor: keep Player ESP state/functions inside ONE table.
    -- This avoids adding a large number of top-level locals to an already-large
    -- script, which can prevent Luau from compiling the chunk at all.
    -- ============================================================

    local PlayerESP = {
        NameEnabled = false,
        NameCache = {},
        NameConnections = {},
        NameTextColor = Color3.fromRGB(255, 255, 255),
        NameOutlineColor = Color3.fromRGB(0, 0, 0),
        NameOutlineEnabled = true,
        NameTextSize = 16,
        NameHeight = 3,
        NameFont = Enum.Font.GothamBold,
        NameTextMode = "Username",

        -- Custom colors are opt-in. Each color picker has a matching toggle
        -- directly beneath it; unchecked always restores the original ESP color.
        ColorOverrides = {},
        DefaultColors = {
            NameText = Color3.fromRGB(255, 255, 255),
            NameOutline = Color3.fromRGB(0, 0, 0),
            HealthBarLow = Color3.fromRGB(255, 0, 0),
            HealthBarHigh = Color3.fromRGB(0, 255, 0),
            HealthBarBackground = Color3.fromRGB(0, 0, 0),
            ChamsHigh = Color3.fromRGB(0, 255, 0),
            ChamsMid = Color3.fromRGB(255, 255, 0),
            ChamsLow = Color3.fromRGB(255, 0, 0),
            ChamsVisible = Color3.fromRGB(0, 255, 0),
            ChamsNotVisible = Color3.fromRGB(255, 0, 0),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            Skeleton = Color3.fromRGB(255, 255, 255)
        },

        HealthBarEnabled = false,
        HealthBarCache = {},
        HealthBarConnections = {},
        HealthBarLowColor = Color3.fromRGB(255, 0, 0),
        HealthBarHighColor = Color3.fromRGB(0, 255, 0),
        HealthBarBackgroundColor = Color3.fromRGB(0, 0, 0),
        HealthBarPosition = "Above Player",

        DistanceEnabled = false,
        DistanceCache = {},

        -- Drawing-based screen-space ESP. Everything lives in the PlayerESP table
        -- so this does not add more top-level locals to the already-large chunk.
        DrawingSupported = type(Drawing) == "table" and type(Drawing.new) == "function",
        SkeletonEnabled = false,
        SkeletonCache = {},
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        BoundingBoxEnabled = false,
        BoundingBoxCache = {},
        BoundingBoxColor = Color3.fromRGB(255, 255, 255),

        SkeletonBonesR15 = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"}
        },

        SkeletonBonesR6 = {
            {"Head", "Torso"},
            {"Torso", "Left Arm"},
            {"Torso", "Right Arm"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"}
        },

        ChamsEnabled = false,
        ChamsHighlights = {},
        ChamsHighColor = Color3.fromRGB(0, 255, 0),
        ChamsMidColor = Color3.fromRGB(255, 255, 0),
        ChamsLowColor = Color3.fromRGB(255, 0, 0),
        ChamsVisibleColor = Color3.fromRGB(0, 255, 0),
        ChamsNotVisibleColor = Color3.fromRGB(255, 0, 0),
        ChamsOutlineColor = Color3.fromRGB(255, 255, 255),

        Fonts = {
            ["Gotham Bold"] = Enum.Font.GothamBold,
            ["Gotham"] = Enum.Font.Gotham,
            ["Source Sans Bold"] = Enum.Font.SourceSansBold,
            ["Code"] = Enum.Font.Code
        }
    }

    PlayerESP.ControlsSection = CreateCategorySector(PlayerVisualsTab, "ESP Controls")
    PlayerESP.TextSection = CreateCategorySector(PlayerVisualsTab, "Name ESP Text")
    PlayerESP.ColorSection = CreateCategorySector(PlayerVisualsTab, "ESP Colors")

    function PlayerESP:GetDropdownValue(value)
        if type(value) == "table" then
            return value[1]
        end
        return value
    end

    function PlayerESP:SelectionHas(selection, wanted)
        if type(selection) ~= "table" then
            return selection == wanted
        end

        for _, value in pairs(selection) do
            if value == wanted then
                return true
            end
        end

        return false
    end

    function PlayerESP:GetActiveColor(overrideName, customColor, defaultColor)
        if self.ColorOverrides[overrideName] == true then
            return customColor
        end
        return defaultColor
    end

    function PlayerESP:GetNameText(plr)
        if not plr then
            return "Player"
        end

        if self.NameTextMode == "Display Name" then
            return plr.DisplayName
        end

        if self.NameTextMode == "Display + Username" and plr.DisplayName ~= plr.Name then
            return plr.DisplayName .. " (@" .. plr.Name .. ")"
        end

        return plr.Name
    end

    function PlayerESP:ApplyNameCustomization(plr, billboard)
        if not billboard or not billboard.Parent then
            return
        end

        billboard.StudsOffset = Vector3.new(0, self.NameHeight, 0)

        local label = billboard:FindFirstChild("NameLabel")
        if not label or not label:IsA("TextLabel") then
            return
        end

        label.Text = self:GetNameText(plr)
        label.TextColor3 = self:GetActiveColor("Name Text", self.NameTextColor, self.DefaultColors.NameText)
        label.TextStrokeTransparency = self.NameOutlineEnabled and 0 or 1
        label.TextStrokeColor3 = self:GetActiveColor("Name Outline", self.NameOutlineColor, self.DefaultColors.NameOutline)
        label.Font = self.NameFont
        label.TextSize = self.NameTextSize
    end

    function PlayerESP:RefreshNameAppearance()
        for plr, billboard in pairs(self.NameCache) do
            if billboard and billboard.Parent then
                self:ApplyNameCustomization(plr, billboard)
            end
        end
    end

    function PlayerESP:DisconnectNameConnections()
        for _, connection in ipairs(self.NameConnections) do
            connection:Disconnect()
        end
        self.NameConnections = {}
    end

    function PlayerESP:CreateName(plr)
        if not self.NameEnabled or plr == game.Players.LocalPlayer or not plr.Character then
            return
        end

        local head = plr.Character:FindFirstChild("Head")
        if not head then
            return
        end

        local existing = self.NameCache[plr]
        if existing and existing.Parent then
            if existing.Adornee == head then
                self:ApplyNameCustomization(plr, existing)
                return
            end
            existing:Destroy()
        end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "TheTower_NameESP"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 260, 0, 50)
        billboard.StudsOffset = Vector3.new(0, self.NameHeight, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = game.CoreGui

        local label = Instance.new("TextLabel")
        label.Name = "NameLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Parent = billboard

        self.NameCache[plr] = billboard
        self:ApplyNameCustomization(plr, billboard)
    end

    function PlayerESP:SetNameEnabled(state)
        self.NameEnabled = state == true
        self:DisconnectNameConnections()

        if not self.NameEnabled then
            for _, billboard in pairs(self.NameCache) do
                if billboard then
                    billboard:Destroy()
                end
            end
            self.NameCache = {}
            return
        end

        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Character then
                self:CreateName(plr)
            end

            table.insert(self.NameConnections, plr.CharacterAdded:Connect(function()
                if self.NameEnabled then
                    self:CreateName(plr)
                end
            end))
        end

        table.insert(self.NameConnections, game.Players.PlayerAdded:Connect(function(plr)
            table.insert(self.NameConnections, plr.CharacterAdded:Connect(function()
                if self.NameEnabled then
                    self:CreateName(plr)
                end
            end))

            if plr.Character then
                task.defer(function()
                    if self.NameEnabled then
                        self:CreateName(plr)
                    end
                end)
            end
        end))

        table.insert(self.NameConnections, game.Players.PlayerRemoving:Connect(function(plr)
            local billboard = self.NameCache[plr]
            if billboard then
                billboard:Destroy()
            end
            self.NameCache[plr] = nil
        end))
    end

    function PlayerESP:DisconnectHealthConnections()
        for _, connection in ipairs(self.HealthBarConnections) do
            connection:Disconnect()
        end
        self.HealthBarConnections = {}
    end

    function PlayerESP:ApplyHealthBarLayout(data)
        if not data or not data.Gui or not data.Gui.Parent then
            return
        end

        local character = data.Player and data.Player.Character
        local head = character and character:FindFirstChild("Head")
        local root = character and (
            character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
        )

        if self.HealthBarPosition == "Left of Player" and root and head then
            -- Match the vertical bar to the character's actual on-screen body height.
            -- The bottom point is derived from Humanoid.HipHeight and the top point
            -- is the top of the Head. Because both are projected through the camera,
            -- the bar naturally shrinks/grows with distance just like the character.
            local camera = workspace.CurrentCamera
            local humanoid = data.Humanoid

            if camera and humanoid then
                local topWorld = head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)
                local bottomWorld = Vector3.new(
                    root.Position.X,
                    root.Position.Y - (humanoid.HipHeight + root.Size.Y * 0.5),
                    root.Position.Z
                )

                local topScreen = camera:WorldToViewportPoint(topWorld)
                local bottomScreen = camera:WorldToViewportPoint(bottomWorld)

                if topScreen.Z > 0 and bottomScreen.Z > 0 then
                    local projectedHeight = math.clamp(math.abs(bottomScreen.Y - topScreen.Y), 10, 500)
                    local barWidth = math.clamp(projectedHeight * 0.04, 2, 7)
                    local centerWorld = (topWorld + bottomWorld) * 0.5

                    -- Keep the bar on the player's screen-left side regardless of
                    -- which way the character itself is facing.
                    local torso = character:FindFirstChild("UpperTorso")
                        or character:FindFirstChild("Torso")
                        or root
                    local halfBodyWidth = math.max(torso.Size.X, root.Size.X, head.Size.X) * 0.5
                    local worldOffset = (centerWorld - root.Position)
                        - camera.CFrame.RightVector * (halfBodyWidth + 0.35)

                    data.Gui.Adornee = root
                    data.Gui.Size = UDim2.fromOffset(math.ceil(barWidth + 4), math.ceil(projectedHeight))
                    data.Gui.StudsOffset = Vector3.zero
                    data.Gui.ExtentsOffsetWorldSpace = Vector3.zero

                    pcall(function()
                        data.Gui.StudsOffsetWorldSpace = worldOffset
                    end)

                    data.Back.Size = UDim2.new(0, barWidth, 1, 0)
                    data.Back.Position = UDim2.new(0.5, -barWidth * 0.5, 0, 0)

                    data.Fill.AnchorPoint = Vector2.new(0, 1)
                    data.Fill.Position = UDim2.new(0, 0, 1, 0)
                    return
                end
            end

            -- Safe fallback if the camera/character cannot be projected this frame.
            data.Gui.Adornee = root
            data.Gui.Size = UDim2.fromOffset(8, 80)
            data.Gui.StudsOffset = Vector3.new(-2.35, 0, 0)
            data.Gui.ExtentsOffsetWorldSpace = Vector3.zero
            pcall(function()
                data.Gui.StudsOffsetWorldSpace = Vector3.zero
            end)

            data.Back.Size = UDim2.new(0, 4, 1, 0)
            data.Back.Position = UDim2.new(0.5, -2, 0, 0)

            data.Fill.AnchorPoint = Vector2.new(0, 1)
            data.Fill.Position = UDim2.new(0, 0, 1, 0)
        else
            -- Preserve the original horizontal health bar above the head.
            data.Gui.Adornee = head or root
            data.Gui.Size = UDim2.new(4, 0, 0.8, 0)
            data.Gui.StudsOffset = Vector3.zero
            data.Gui.ExtentsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
            pcall(function()
                data.Gui.StudsOffsetWorldSpace = Vector3.zero
            end)

            data.Back.Size = UDim2.new(0.9, 0, 0.35, 0)
            data.Back.Position = UDim2.new(0.05, 0, 0.4, 0)

            data.Fill.AnchorPoint = Vector2.new(0, 0)
            data.Fill.Position = UDim2.new(0, 0, 0, 0)
        end
    end

    function PlayerESP:SetHealthBarPosition(position)
        if position ~= "Above Player" and position ~= "Left of Player" then
            return
        end

        self.HealthBarPosition = position

        for _, data in pairs(self.HealthBarCache) do
            self:ApplyHealthBarLayout(data)
        end

        self:UpdateHealthBars()
    end

    function PlayerESP:CreateHealthBar(plr)
        if not self.HealthBarEnabled or plr == game.Players.LocalPlayer or not plr.Character then
            return
        end

        local head = plr.Character:FindFirstChild("Head")
        local humanoid = plr.Character:FindFirstChild("Humanoid")
        if not head or not humanoid then
            return
        end

        local existing = self.HealthBarCache[plr]
        if existing and existing.Gui and existing.Gui.Parent then
            if existing.Humanoid == humanoid and existing.Character == plr.Character then
                self:ApplyHealthBarLayout(existing)
                return
            end
            existing.Gui:Destroy()
        end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "HealthBar_ESP"
        billboard.Adornee = head
        billboard.Size = UDim2.new(4, 0, 0.8, 0)
        billboard.AlwaysOnTop = true
        billboard.ExtentsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
        billboard.Parent = game.CoreGui

        local back = Instance.new("Frame")
        back.Size = UDim2.new(0.9, 0, 0.35, 0)
        back.Position = UDim2.new(0.05, 0, 0.4, 0)
        back.BackgroundColor3 = self:GetActiveColor(
            "Health Bar Background",
            self.HealthBarBackgroundColor,
            self.DefaultColors.HealthBarBackground
        )
        back.BorderSizePixel = 0
        back.Parent = billboard

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(1, 0, 1, 0)
        fill.BackgroundColor3 = self:GetActiveColor(
            "Health Bar High",
            self.HealthBarHighColor,
            self.DefaultColors.HealthBarHigh
        )
        fill.BorderSizePixel = 0
        fill.Parent = back

        self.HealthBarCache[plr] = {
            Gui = billboard,
            Back = back,
            Fill = fill,
            Humanoid = humanoid,
            Player = plr,
            Character = plr.Character
        }

        self:ApplyHealthBarLayout(self.HealthBarCache[plr])
    end

    function PlayerESP:UpdateHealthBars()
        for plr, data in pairs(self.HealthBarCache) do
            if not plr.Character or not data.Humanoid or data.Humanoid.Health <= 0 then
                if data.Gui then
                    data.Gui:Destroy()
                end
                self.HealthBarCache[plr] = nil
            else
                self:ApplyHealthBarLayout(data)

                local maxHealth = math.max(data.Humanoid.MaxHealth, 1)
                local percent = math.clamp(data.Humanoid.Health / maxHealth, 0, 1)

                if self.HealthBarPosition == "Left of Player" then
                    data.Fill.Size = UDim2.new(1, 0, percent, 0)
                else
                    data.Fill.Size = UDim2.new(percent, 0, 1, 0)
                end

                local lowColor = self:GetActiveColor(
                    "Health Bar Low",
                    self.HealthBarLowColor,
                    self.DefaultColors.HealthBarLow
                )
                local highColor = self:GetActiveColor(
                    "Health Bar High",
                    self.HealthBarHighColor,
                    self.DefaultColors.HealthBarHigh
                )

                data.Fill.BackgroundColor3 = lowColor:Lerp(highColor, percent)
                data.Back.BackgroundColor3 = self:GetActiveColor(
                    "Health Bar Background",
                    self.HealthBarBackgroundColor,
                    self.DefaultColors.HealthBarBackground
                )
            end
        end
    end

    function PlayerESP:SetHealthBarEnabled(state)
        self.HealthBarEnabled = state == true
        self:DisconnectHealthConnections()

        if not self.HealthBarEnabled then
            for _, data in pairs(self.HealthBarCache) do
                if data.Gui then
                    data.Gui:Destroy()
                end
            end
            self.HealthBarCache = {}
            return
        end

        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Character then
                self:CreateHealthBar(plr)
            end

            table.insert(self.HealthBarConnections, plr.CharacterAdded:Connect(function()
                if self.HealthBarEnabled then
                    self:CreateHealthBar(plr)
                end
            end))
        end

        table.insert(self.HealthBarConnections, game.Players.PlayerAdded:Connect(function(plr)
            table.insert(self.HealthBarConnections, plr.CharacterAdded:Connect(function()
                if self.HealthBarEnabled then
                    self:CreateHealthBar(plr)
                end
            end))

            if plr.Character then
                task.defer(function()
                    if self.HealthBarEnabled then
                        self:CreateHealthBar(plr)
                    end
                end)
            end
        end))

        table.insert(self.HealthBarConnections, game.Players.PlayerRemoving:Connect(function(plr)
            local data = self.HealthBarCache[plr]
            if data and data.Gui then
                data.Gui:Destroy()
            end
            self.HealthBarCache[plr] = nil
        end))
    end

    function PlayerESP:RemoveDistance(plr)
        local data = self.DistanceCache[plr]
        if data and data.Gui then
            pcall(function()
                data.Gui:Destroy()
            end)
        end
        self.DistanceCache[plr] = nil
    end

    function PlayerESP:RemoveAllDistances()
        for plr in pairs(self.DistanceCache) do
            self:RemoveDistance(plr)
        end
    end

    function PlayerESP:CreateDistance(plr)
        if not self.DistanceEnabled or not plr or plr == game.Players.LocalPlayer or not plr.Character then
            return nil
        end

        local head = plr.Character:FindFirstChild("Head")
        if not head then
            return nil
        end

        local existing = self.DistanceCache[plr]
        if existing and existing.Gui and existing.Gui.Parent and existing.Gui.Adornee == head then
            return existing
        end

        self:RemoveDistance(plr)

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "TheTower_DistanceESP"
        billboard.Adornee = head
        billboard.Size = UDim2.fromOffset(180, 28)
        billboard.StudsOffset = Vector3.new(0, 2.35, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = game.CoreGui

        local label = Instance.new("TextLabel")
        label.Name = "DistanceLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.Text = "0 studs"
        label.Parent = billboard

        local data = {
            Gui = billboard,
            Label = label,
            Character = plr.Character
        }
        self.DistanceCache[plr] = data
        return data
    end

    function PlayerESP:UpdateDistances()
        if not self.DistanceEnabled then
            return
        end

        local localPlayer = game.Players.LocalPlayer
        local localCharacter = localPlayer and localPlayer.Character
        local localRoot = localCharacter and (
            localCharacter:FindFirstChild("HumanoidRootPart")
            or localCharacter:FindFirstChild("UpperTorso")
            or localCharacter:FindFirstChild("Torso")
        )

        if not localRoot then
            return
        end

        for _, plr in ipairs(game.Players:GetPlayers()) do
            if plr ~= localPlayer then
                local character = plr.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local targetRoot = character and (
                    character:FindFirstChild("HumanoidRootPart")
                    or character:FindFirstChild("UpperTorso")
                    or character:FindFirstChild("Torso")
                )

                if character and humanoid and humanoid.Health > 0 and targetRoot then
                    local data = self.DistanceCache[plr]
                    if not data or not data.Gui or not data.Gui.Parent or data.Character ~= character then
                        data = self:CreateDistance(plr)
                    end

                    if data and data.Label then
                        local studs = math.floor((localRoot.Position - targetRoot.Position).Magnitude + 0.5)
                        data.Label.Text = tostring(studs) .. " studs"
                    end
                else
                    self:RemoveDistance(plr)
                end
            end
        end

        for plr in pairs(self.DistanceCache) do
            if not plr or not plr.Parent or plr == localPlayer then
                self:RemoveDistance(plr)
            end
        end
    end

    function PlayerESP:SetDistanceEnabled(state)
        self.DistanceEnabled = state == true

        if self.DistanceEnabled then
            self:UpdateDistances()
        else
            self:RemoveAllDistances()
        end
    end

    function PlayerESP:NewDrawing(kind)
        if not self.DrawingSupported then
            return nil
        end

        local ok, drawing = pcall(function()
            return Drawing.new(kind)
        end)

        if not ok or not drawing then
            self.DrawingSupported = false
            return nil
        end

        pcall(function()
            drawing.Visible = false
        end)

        return drawing
    end

    function PlayerESP:RemoveDrawing(drawing)
        if not drawing then
            return
        end

        pcall(function()
            drawing.Visible = false
            drawing:Remove()
        end)
    end

    function PlayerESP:RemoveBoundingBox(plr)
        local square = self.BoundingBoxCache[plr]
        if square then
            self:RemoveDrawing(square)
        end
        self.BoundingBoxCache[plr] = nil
    end

    function PlayerESP:RemoveAllBoundingBoxes()
        for plr in pairs(self.BoundingBoxCache) do
            self:RemoveBoundingBox(plr)
        end
    end

    function PlayerESP:RemoveSkeleton(plr)
        local data = self.SkeletonCache[plr]
        if data and data.Lines then
            for _, line in ipairs(data.Lines) do
                self:RemoveDrawing(line)
            end
        end
        self.SkeletonCache[plr] = nil
    end

    function PlayerESP:RemoveAllSkeletons()
        for plr in pairs(self.SkeletonCache) do
            self:RemoveSkeleton(plr)
        end
    end

    function PlayerESP:GetCharacterScreenBounds(character)
        local camera = workspace.CurrentCamera
        if not camera or not character or not character.Parent then
            return nil
        end

        local ok, boxCFrame, boxSize = pcall(function()
            local cf, size = character:GetBoundingBox()
            return cf, size
        end)

        if not ok or not boxCFrame or not boxSize then
            return nil
        end

        local halfX = boxSize.X * 0.5
        local halfY = boxSize.Y * 0.5
        local halfZ = boxSize.Z * 0.5
        local minX = math.huge
        local minY = math.huge
        local maxX = -math.huge
        local maxY = -math.huge
        local anyInFront = false

        for x = -1, 1, 2 do
            for y = -1, 1, 2 do
                for z = -1, 1, 2 do
                    local worldPoint = boxCFrame:PointToWorldSpace(
                        Vector3.new(halfX * x, halfY * y, halfZ * z)
                    )
                    local screenPoint = camera:WorldToViewportPoint(worldPoint)

                    if screenPoint.Z > 0 then
                        anyInFront = true
                        minX = math.min(minX, screenPoint.X)
                        minY = math.min(minY, screenPoint.Y)
                        maxX = math.max(maxX, screenPoint.X)
                        maxY = math.max(maxY, screenPoint.Y)
                    end
                end
            end
        end

        if not anyInFront or minX == math.huge then
            return nil
        end

        return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
    end

    function PlayerESP:UpdateBoundingBox(plr)
        if not self.BoundingBoxEnabled then
            self:RemoveBoundingBox(plr)
            return
        end

        local character = plr and plr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if not character or not humanoid or humanoid.Health <= 0 then
            self:RemoveBoundingBox(plr)
            return
        end

        local position, size = self:GetCharacterScreenBounds(character)
        local square = self.BoundingBoxCache[plr]

        if not square then
            square = self:NewDrawing("Square")
            if not square then
                return
            end

            pcall(function()
                square.Filled = false
                square.Thickness = 1.5
                square.Transparency = 1
            end)

            self.BoundingBoxCache[plr] = square
        end

        if not position or not size or size.X <= 1 or size.Y <= 1 then
            pcall(function()
                square.Visible = false
            end)
            return
        end

        pcall(function()
            square.Position = position
            square.Size = size
            square.Color = self.BoundingBoxColor
            square.Visible = true
        end)
    end

    function PlayerESP:GetSkeletonBones(character)
        if character and character:FindFirstChild("UpperTorso") then
            return self.SkeletonBonesR15
        end
        return self.SkeletonBonesR6
    end

    function PlayerESP:EnsureSkeleton(plr, character)
        local bones = self:GetSkeletonBones(character)
        local data = self.SkeletonCache[plr]

        if data and (data.Character ~= character or #data.Lines ~= #bones) then
            self:RemoveSkeleton(plr)
            data = nil
        end

        if data then
            return data, bones
        end

        data = {
            Character = character,
            Lines = {}
        }

        for _ = 1, #bones do
            local line = self:NewDrawing("Line")
            if not line then
                for _, createdLine in ipairs(data.Lines) do
                    self:RemoveDrawing(createdLine)
                end
                return nil, bones
            end

            pcall(function()
                line.Thickness = 1.5
                line.Transparency = 1
                line.Visible = false
            end)

            table.insert(data.Lines, line)
        end

        self.SkeletonCache[plr] = data
        return data, bones
    end

    function PlayerESP:UpdateSkeleton(plr)
        if not self.SkeletonEnabled then
            self:RemoveSkeleton(plr)
            return
        end

        local character = plr and plr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local camera = workspace.CurrentCamera

        if not character or not humanoid or humanoid.Health <= 0 or not camera then
            self:RemoveSkeleton(plr)
            return
        end

        local data, bones = self:EnsureSkeleton(plr, character)
        if not data then
            return
        end

        for index, bone in ipairs(bones) do
            local line = data.Lines[index]
            local firstPart = character:FindFirstChild(bone[1])
            local secondPart = character:FindFirstChild(bone[2])

            if firstPart and firstPart:IsA("BasePart") and secondPart and secondPart:IsA("BasePart") then
                local firstPoint = camera:WorldToViewportPoint(firstPart.Position)
                local secondPoint = camera:WorldToViewportPoint(secondPart.Position)

                if firstPoint.Z > 0 and secondPoint.Z > 0 then
                    pcall(function()
                        line.From = Vector2.new(firstPoint.X, firstPoint.Y)
                        line.To = Vector2.new(secondPoint.X, secondPoint.Y)
                        line.Color = self:GetActiveColor("Skeleton", self.SkeletonColor, self.DefaultColors.Skeleton)
                        line.Visible = true
                    end)
                else
                    pcall(function()
                        line.Visible = false
                    end)
                end
            else
                pcall(function()
                    line.Visible = false
                end)
            end
        end
    end

    function PlayerESP:UpdateDrawingESP()
        if not self.DrawingSupported then
            return
        end

        for _, plr in ipairs(game.Players:GetPlayers()) do
            if plr ~= game.Players.LocalPlayer then
                if self.BoundingBoxEnabled then
                    self:UpdateBoundingBox(plr)
                end

                if self.SkeletonEnabled then
                    self:UpdateSkeleton(plr)
                end
            end
        end

        for plr in pairs(self.BoundingBoxCache) do
            if not plr or not plr.Parent or not self.BoundingBoxEnabled then
                self:RemoveBoundingBox(plr)
            end
        end

        for plr in pairs(self.SkeletonCache) do
            if not plr or not plr.Parent or not self.SkeletonEnabled then
                self:RemoveSkeleton(plr)
            end
        end
    end

    function PlayerESP:SetBoundingBoxEnabled(state)
        self.BoundingBoxEnabled = state == true

        if not self.BoundingBoxEnabled then
            self:RemoveAllBoundingBoxes()
        end
    end

    function PlayerESP:SetSkeletonEnabled(state)
        self.SkeletonEnabled = state == true

        if not self.SkeletonEnabled then
            self:RemoveAllSkeletons()
        end
    end

    function PlayerESP:ApplyHealthChams()
        if not self.ChamsEnabled then
            return
        end

        local silentAimState =
            rawget(
                _G,
                "__VITALITY_TOWER_SILENT_AIM"
            )

        local visibilityColorsActive =
            type(silentAimState) == "table"
            and silentAimState.VisibilityCheck == true
            and type(silentAimState.IsCharacterVisible) == "function"

        for _, obj in pairs(workspace:GetChildren()) do
            local player =
                obj:IsA("Model")
                and game.Players:GetPlayerFromCharacter(obj)
                or nil

            if player
                and obj ~= game.Players.LocalPlayer.Character then

                local humanoid =
                    obj:FindFirstChild("Humanoid")

                if humanoid
                    and humanoid.Health > 0 then

                    local fillColor = nil

                    if visibilityColorsActive then
                        local okVisible, visible =
                            pcall(
                                silentAimState.IsCharacterVisible,
                                obj
                            )

                        if okVisible then
                            if visible then
                                fillColor =
                                    self:GetActiveColor(
                                        "Chams Visible",
                                        self.ChamsVisibleColor,
                                        self.DefaultColors.ChamsVisible
                                    )
                            else
                                fillColor =
                                    self:GetActiveColor(
                                        "Chams Not Visible",
                                        self.ChamsNotVisibleColor,
                                        self.DefaultColors.ChamsNotVisible
                                    )
                            end
                        end
                    end

                    if not fillColor then
                        local maxHealth =
                            math.max(
                                humanoid.MaxHealth,
                                1
                            )

                        local percent =
                            humanoid.Health
                            / maxHealth

                        local highColor =
                            self:GetActiveColor(
                                "Chams High",
                                self.ChamsHighColor,
                                self.DefaultColors.ChamsHigh
                            )

                        local midColor =
                            self:GetActiveColor(
                                "Chams Mid",
                                self.ChamsMidColor,
                                self.DefaultColors.ChamsMid
                            )

                        local lowColor =
                            self:GetActiveColor(
                                "Chams Low",
                                self.ChamsLowColor,
                                self.DefaultColors.ChamsLow
                            )

                        fillColor =
                            percent >= 0.8
                            and highColor
                            or percent >= 0.6
                            and midColor
                            or lowColor
                    end

                    for _, part in pairs(
                        obj:GetChildren()
                    ) do
                        if part:IsA("BasePart") then
                            local highlight =
                                self.ChamsHighlights[
                                    part
                                ]

                            if not highlight
                                or not highlight.Parent then

                                highlight =
                                    Instance.new(
                                        "Highlight"
                                    )

                                highlight.Name =
                                    "TheTower_HealthChams"

                                highlight.FillTransparency =
                                    0.5

                                highlight.OutlineTransparency =
                                    0

                                highlight.Parent =
                                    part

                                self.ChamsHighlights[
                                    part
                                ] =
                                    highlight
                            end

                            highlight.FillColor =
                                fillColor

                            highlight.OutlineColor =
                                self:GetActiveColor(
                                    "Chams Outline",
                                    self.ChamsOutlineColor,
                                    self.DefaultColors.ChamsOutline
                                )
                        end
                    end
                end
            end
        end

        for part, highlight in pairs(
            self.ChamsHighlights
        ) do
            if not part
                or not part.Parent
                or not highlight
                or not highlight.Parent then

                if highlight then
                    pcall(function()
                        highlight:Destroy()
                    end)
                end

                self.ChamsHighlights[
                    part
                ] =
                    nil
            end
        end
    end

    function PlayerESP:RemoveChams()
        for _, highlight in pairs(self.ChamsHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        self.ChamsHighlights = {}
    end

    function PlayerESP:SetChamsEnabled(state)
        self.ChamsEnabled = state == true
        if self.ChamsEnabled then
            self:ApplyHealthChams()
        else
            self:RemoveChams()
        end
    end

    -- vitality's hub multi-selection dropdown. Multi-select callbacks receive tables.
    PlayerVisualsTab:CreateDropdown({
        Name = "ESP Features",
        Flag = "Tower_PlayerESP_Features",
        Info = "Choose which player ESP features are active.",
        Options = {"Name ESP", "Distance ESP", "Health Bar ESP", "Health Chams", "Skeleton ESP", "Bounding Box ESP"},
        CurrentOption = {},
        MultiSelection = true,
        SectionParent = PlayerESP.ControlsSection._Section,
        Callback = function(selection)
            PlayerESP:SetNameEnabled(PlayerESP:SelectionHas(selection, "Name ESP"))
            PlayerESP:SetDistanceEnabled(PlayerESP:SelectionHas(selection, "Distance ESP"))
            PlayerESP:SetHealthBarEnabled(PlayerESP:SelectionHas(selection, "Health Bar ESP"))
            PlayerESP:SetChamsEnabled(PlayerESP:SelectionHas(selection, "Health Chams"))
            PlayerESP:SetSkeletonEnabled(PlayerESP:SelectionHas(selection, "Skeleton ESP"))
            PlayerESP:SetBoundingBoxEnabled(PlayerESP:SelectionHas(selection, "Bounding Box ESP"))
        end
    })

    PlayerVisualsTab:CreateDropdown({
        Name = "Health Bar Position",
        Flag = "Tower_PlayerESP_HealthBarPosition",
        Info = "Keep the original health bar above the player or move it vertically to the player's left.",
        Options = {"Above Player", "Left of Player"},
        CurrentOption = "Above Player",
        MultiSelection = false,
        SectionParent = PlayerESP.ControlsSection._Section,
        Callback = function(value)
            local selected = PlayerESP:GetDropdownValue(value)
            if selected then
                PlayerESP:SetHealthBarPosition(selected)
            end
        end
    })

    PlayerVisualsTab:CreateDropdown({
        Name = "Name Format",
        Flag = "Tower_PlayerESP_NameFormat",
        Info = "Choose what the player label displays.",
        Options = {"Username", "Display Name", "Display + Username"},
        CurrentOption = "Username",
        MultiSelection = false,
        SectionParent = PlayerESP.TextSection._Section,
        Callback = function(value)
            local selected = PlayerESP:GetDropdownValue(value)
            if selected then
                PlayerESP.NameTextMode = selected
                PlayerESP:RefreshNameAppearance()
            end
        end
    })

    PlayerVisualsTab:CreateDropdown({
        Name = "Text Font",
        Flag = "Tower_PlayerESP_Font",
        Info = "Choose the font used by Name ESP.",
        Options = {"Gotham Bold", "Gotham", "Source Sans Bold", "Code"},
        CurrentOption = "Gotham Bold",
        MultiSelection = false,
        SectionParent = PlayerESP.TextSection._Section,
        Callback = function(value)
            local selected = PlayerESP:GetDropdownValue(value)
            if selected and PlayerESP.Fonts[selected] then
                PlayerESP.NameFont = PlayerESP.Fonts[selected]
                PlayerESP:RefreshNameAppearance()
            end
        end
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Text Size",
        Flag = "Tower_PlayerESP_TextSize",
        Info = "Changes the Name ESP text size.",
        Range = {10, 32},
        Increment = 1,
        Suffix = " px",
        CurrentValue = 16,
        SectionParent = PlayerESP.TextSection._Section,
        Callback = function(value)
            PlayerESP.NameTextSize = value
            PlayerESP:RefreshNameAppearance()
        end
    })

    PlayerVisualsTab:CreateSlider({
        Name = "Text Height",
        Flag = "Tower_PlayerESP_TextHeight",
        Info = "Changes how high the name appears above the player.",
        Range = {1, 8},
        Increment = 0.25,
        Suffix = " studs",
        CurrentValue = 3,
        SectionParent = PlayerESP.TextSection._Section,
        Callback = function(value)
            PlayerESP.NameHeight = value
            PlayerESP:RefreshNameAppearance()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Text Outline",
        Flag = "Tower_PlayerESP_TextOutline",
        Info = "Turns the Name ESP text outline on or off.",
        CurrentValue = true,
        SectionParent = PlayerESP.TextSection._Section,
        Callback = function(state)
            PlayerESP.NameOutlineEnabled = state
            PlayerESP:RefreshNameAppearance()
        end
    })

    -- Each picker is immediately followed by its own vitality toggle.
    -- OFF = original ESP color. ON = use the color currently selected above it.
    PlayerVisualsTab:CreateColorPicker({
        Name = "Name Text Color",
        Flag = "Tower_PlayerESP_NameTextColor",
        Info = "Choose a custom Name ESP text color.",
        Color = PlayerESP.NameTextColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.NameTextColor = color
            PlayerESP:RefreshNameAppearance()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Name Text Color",
        Flag = "Tower_PlayerESP_UseNameTextColor",
        Info = "Checked = use the custom color above. Unchecked = original white.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Name Text"] = state == true
            PlayerESP:RefreshNameAppearance()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Name Outline Color",
        Flag = "Tower_PlayerESP_NameOutlineColor",
        Info = "Choose a custom Name ESP outline color.",
        Color = PlayerESP.NameOutlineColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.NameOutlineColor = color
            PlayerESP:RefreshNameAppearance()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Name Outline Color",
        Flag = "Tower_PlayerESP_UseNameOutlineColor",
        Info = "Checked = use the custom color above. Unchecked = original black.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Name Outline"] = state == true
            PlayerESP:RefreshNameAppearance()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Health Bar Low Color",
        Flag = "Tower_PlayerESP_HealthLowColor",
        Info = "Choose the custom low-health end of the health gradient.",
        Color = PlayerESP.HealthBarLowColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.HealthBarLowColor = color
            PlayerESP:UpdateHealthBars()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Health Bar Low Color",
        Flag = "Tower_PlayerESP_UseHealthLowColor",
        Info = "Checked = use the custom color above. Unchecked = original red.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Health Bar Low"] = state == true
            PlayerESP:UpdateHealthBars()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Health Bar High Color",
        Flag = "Tower_PlayerESP_HealthHighColor",
        Info = "Choose the custom high-health end of the health gradient.",
        Color = PlayerESP.HealthBarHighColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.HealthBarHighColor = color
            PlayerESP:UpdateHealthBars()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Health Bar High Color",
        Flag = "Tower_PlayerESP_UseHealthHighColor",
        Info = "Checked = use the custom color above. Unchecked = original green.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Health Bar High"] = state == true
            PlayerESP:UpdateHealthBars()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Health Bar Background",
        Flag = "Tower_PlayerESP_HealthBackground",
        Info = "Choose a custom health-bar background color.",
        Color = PlayerESP.HealthBarBackgroundColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.HealthBarBackgroundColor = color
            PlayerESP:UpdateHealthBars()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Health Bar Background",
        Flag = "Tower_PlayerESP_UseHealthBackground",
        Info = "Checked = use the custom color above. Unchecked = original black.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Health Bar Background"] = state == true
            PlayerESP:UpdateHealthBars()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Skeleton Color",
        Flag = "Tower_PlayerESP_SkeletonColor",
        Info = "Choose a custom Skeleton ESP color.",
        Color = PlayerESP.SkeletonColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.SkeletonColor = color
            if PlayerESP.SkeletonEnabled then
                PlayerESP:UpdateDrawingESP()
            end
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Skeleton Color",
        Flag = "Tower_PlayerESP_UseSkeletonColor",
        Info = "Checked = use the custom color above. Unchecked = original white.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Skeleton"] = state == true
            if PlayerESP.SkeletonEnabled then
                PlayerESP:UpdateDrawingESP()
            end
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Chams High Health",
        Flag = "Tower_PlayerESP_ChamsHigh",
        Info = "Choose a custom high-health chams color.",
        Color = PlayerESP.ChamsHighColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.ChamsHighColor = color
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Chams High Color",
        Flag = "Tower_PlayerESP_UseChamsHigh",
        Info = "Checked = use the custom color above. Unchecked = original green.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Chams High"] = state == true
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Chams Mid Health",
        Flag = "Tower_PlayerESP_ChamsMid",
        Info = "Choose a custom mid-health chams color.",
        Color = PlayerESP.ChamsMidColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.ChamsMidColor = color
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Chams Mid Color",
        Flag = "Tower_PlayerESP_UseChamsMid",
        Info = "Checked = use the custom color above. Unchecked = original yellow.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Chams Mid"] = state == true
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Chams Low Health",
        Flag = "Tower_PlayerESP_ChamsLow",
        Info = "Choose a custom low-health chams color.",
        Color = PlayerESP.ChamsLowColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.ChamsLowColor = color
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Chams Low Color",
        Flag = "Tower_PlayerESP_UseChamsLow",
        Info = "Checked = use the custom color above. Unchecked = original red.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Chams Low"] = state == true
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Visible Chams Color",
        Flag = "Tower_PlayerESP_ChamsVisible",
        Info = "Color used when Silent Aim Visibility Check confirms direct line of sight.",
        Color = PlayerESP.ChamsVisibleColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.ChamsVisibleColor = color
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Visible Chams Color",
        Flag = "Tower_PlayerESP_UseChamsVisible",
        Info = "Checked = use the custom visible color above. Unchecked = green.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Chams Visible"] = state == true
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Not Visible Chams Color",
        Flag = "Tower_PlayerESP_ChamsNotVisible",
        Info = "Color used when Silent Aim Visibility Check finds an obstruction.",
        Color = PlayerESP.ChamsNotVisibleColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.ChamsNotVisibleColor = color
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Not Visible Chams Color",
        Flag = "Tower_PlayerESP_UseChamsNotVisible",
        Info = "Checked = use the custom obstructed color above. Unchecked = red.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Chams Not Visible"] = state == true
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateColorPicker({
        Name = "Chams Outline",
        Flag = "Tower_PlayerESP_ChamsOutline",
        Info = "Choose a custom chams outline color.",
        Color = PlayerESP.ChamsOutlineColor,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(color)
            PlayerESP.ChamsOutlineColor = color
            PlayerESP:ApplyHealthChams()
        end
    })

    PlayerVisualsTab:CreateToggle({
        Name = "Use Chams Outline Color",
        Flag = "Tower_PlayerESP_UseChamsOutline",
        Info = "Checked = use the custom color above. Unchecked = original white.",
        CurrentValue = false,
        SectionParent = PlayerESP.ColorSection._Section,
        Callback = function(state)
            PlayerESP.ColorOverrides["Chams Outline"] = state == true
            PlayerESP:ApplyHealthChams()
        end
    })

    Window:TrackConnection(game:GetService("RunService").Heartbeat:Connect(function()
        if PlayerESP.DistanceEnabled then
            PlayerESP:UpdateDistances()
        end

        if PlayerESP.HealthBarEnabled then
            PlayerESP:UpdateHealthBars()
        end

        if PlayerESP.ChamsEnabled then
            PlayerESP:ApplyHealthChams()
        end
    end))

    Window:TrackConnection(game:GetService("RunService").RenderStepped:Connect(function()
        if PlayerESP.SkeletonEnabled or PlayerESP.BoundingBoxEnabled then
            PlayerESP:UpdateDrawingESP()
        end
    end))

    -- ============================================================
    -- CURSOR LOCK / UNLOCK
    -- Keeps the mouse free while enabled, even if the camera/game
    -- tries to recapture it on the next frame. Disabling restores
    -- the mouse state that was active before unlocking.
    -- ============================================================

    -- Isolated function scope: keeps cursor feature locals out of the very large
    -- Tower module root function so Luau stays safely below the 200-local register limit.
    ;(function()
        local cursorSection = CreateCategorySector(PlayerToolsTab, "Cursor")
        local RunService = game:GetService("RunService")
        local CursorRenderStepName = "TheTower_CursorUnlock"
        local CursorUnlockEnabled = false
        local PreviousMouseBehavior = UserInputService.MouseBehavior
        local PreviousMouseIconEnabled = UserInputService.MouseIconEnabled

        -- Clean up a cursor override left behind by an earlier execution.
        pcall(function()
            RunService:UnbindFromRenderStep(CursorRenderStepName)
        end)

        local function forceCursorUnlocked()
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        end

        local function setCursorUnlocked(state)
            CursorUnlockEnabled = state

            -- Always clear the previous binding before changing state so
            -- re-executing the script never stacks multiple cursor loops.
            pcall(function()
                RunService:UnbindFromRenderStep(CursorRenderStepName)
            end)

            if state then
                PreviousMouseBehavior = UserInputService.MouseBehavior
                PreviousMouseIconEnabled = UserInputService.MouseIconEnabled

                forceCursorUnlocked()

                -- Run immediately after the camera so camera scripts cannot
                -- permanently pull the cursor back into the center.
                pcall(function()
                    RunService:BindToRenderStep(
                        CursorRenderStepName,
                        Enum.RenderPriority.Camera.Value + 1,
                        function()
                            if CursorUnlockEnabled then
                                forceCursorUnlocked()
                            end
                        end
                    )
                end)
            else
                pcall(function()
                    UserInputService.MouseBehavior = PreviousMouseBehavior
                    UserInputService.MouseIconEnabled = PreviousMouseIconEnabled
                end)
            end
        end

        -- Keep the vitality toggle synchronized with the T hotkey.
        cursorSection.CursorToggle = PlayerToolsTab:CreateToggle({
            Name = "Unlock Cursor",
            Flag = "Tower_UnlockCursor",
            CurrentValue = false,
            SectionParent = cursorSection._Section,
            Callback = function(state)
                setCursorUnlocked(state)
            end,
        })

        -- Keep a small visible hotkey note beneath the cursor toggle.
        PlayerToolsTab:CreateLabel("Hotkey: T â€” Unlock / Lock Cursor", cursorSection._Section)

        -- Re-execution safety: disconnect the previous T listener created by an older run.
        pcall(function()
            if _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION then
                _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION:Disconnect()
            end
        end)

        _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION = Window:TrackConnection(UserInputService.InputBegan:Connect(function(input)
            -- Do not fire while the player is typing into chat or another TextBox.
            if UserInputService:GetFocusedTextBox() then return end

            if input.KeyCode == Enum.KeyCode.T then
                cursorSection.CursorToggle:Set(not CursorUnlockEnabled)
            end
        end))


        Window:AddCleanup(function()
            pcall(function()
                setCursorUnlocked(false)
                RunService:UnbindFromRenderStep(CursorRenderStepName)
            end)

            pcall(function()
                if _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION then
                    _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION:Disconnect()
                    _G.__THE_TOWER_CURSOR_KEYBIND_CONNECTION = nil
                end
            end)
        end)
    end)()

    -- Isolated function scope: player teleport helpers are short-lived setup locals
    -- and do not need to occupy registers for the remainder of the module.
    ;(function()
        local playerTpSection = CreateCategorySector(PlayerToolsTab, "Player Teleport")

        local selectedPlayer = nil

        local playerDropdown

        local function getPlayerCharacterPart(plr)

            if not plr then

                return nil

            end

            local character = plr.Character

            if not character or not character.Parent then

                return nil

            end

        -- HumanoidRootPart is the most reliable target. Fall back to Head.

            return character:FindFirstChild("HumanoidRootPart")

                or character:FindFirstChild("UpperTorso")

                or character:FindFirstChild("Torso")

                or character:FindFirstChild("Head")

        end

        local function getPlayerList()

            local list = {}

            for _, plr in ipairs(game.Players:GetPlayers()) do

                if plr ~= game.Players.LocalPlayer then

                    table.insert(list, plr.Name)

                end

            end

            table.sort(list)

            return list

        end

        local function resolveSelectedPlayer()

            if not selectedPlayer then

                return nil

            end

        -- Store the actual Player object instead of relying on a workspace model name.

            if selectedPlayer.Parent == game.Players then

                return selectedPlayer

            end

            return game.Players:FindFirstChild(tostring(selectedPlayer))

        end

        local function refreshPlayers()

            local list = getPlayerList()

            if not playerDropdown then

                playerDropdown = playerTpSection:AddDropdown(

                    "Select Player",

                    list,

                    list[1] or "No players",

                    false,

                    function(choice)

                        local name = choice

        -- Dropdown callbacks can be normalized from a string or one-item table.

                        if type(choice) == "table" then

                            name = choice[1]

                        end

                        selectedPlayer = game.Players:FindFirstChild(tostring(name))

                    end

                )

            else

        -- Refresh the player list in place while preserving a valid selection.

                pcall(function()

                    playerDropdown:Refresh(list, true)

                end)

            end

        -- Keep selection valid after players join/leave.

            local resolved = resolveSelectedPlayer()

            if not resolved or resolved == game.Players.LocalPlayer then

                selectedPlayer = game.Players:FindFirstChild(list[1])

            end

        end

        playerTpSection:AddButton("Teleport To Player", function()

            local targetPlayer = resolveSelectedPlayer()

            if not targetPlayer or targetPlayer == game.Players.LocalPlayer then

                return

            end

            local targetPart = getPlayerCharacterPart(targetPlayer)

            if not targetPart then

                return

            end

            local localPlayer = game.Players.LocalPlayer

            local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

            local root = character:FindFirstChild("HumanoidRootPart")

            if not root then

                return

            end

        -- Use the same stabilized move used by world-object teleports so custom
        -- movement controllers do not leave the local character drifting afterward.

            stabilizedTeleport(character, targetPart.CFrame + Vector3.new(0, 3, 0))

        end)

        refreshPlayers()

        Window:TrackConnection(game.Players.PlayerAdded:Connect(function()

            task.defer(refreshPlayers)

        end))

        Window:TrackConnection(game.Players.PlayerRemoving:Connect(function(plr)

            if selectedPlayer == plr then

                selectedPlayer = nil

            end

            task.defer(refreshPlayers)

        end))

        -- Stability patch: permanent 2-second player polling removed.
        -- PlayerAdded / PlayerRemoving already refresh the dropdown.
    end)()

    -- ============================================================
    -- WINDOW HARD-CLOSE CLEANUP
    -- ============================================================
    Window:AddCleanup(function()
        pcall(function()
            ActiveAutomationRunId =
                ActiveAutomationRunId + 1

            AutomationRunning = false
            ActiveAutomationAimPosition = nil
            stopAutomationCameraLock()

            if ActiveAutomationFreezeState then
                unfreezeCharacterAfterInteraction(
                    ActiveAutomationFreezeState
                )
                ActiveAutomationFreezeState = nil
            end
        end)

        pcall(function()
            ExtractVisualsEnabled = false
            clearExtractVisuals()
        end)

        pcall(function()
            ItemESPEnabled = false
            clearItemESP()
        end)

        pcall(function()
            ItemChamsEnabled = false

            for obj in pairs(
                ItemChamsCache
            ) do
                destroyItemChams(obj)
            end
        end)

        pcall(function()
            PlayerESP:SetNameEnabled(false)
            PlayerESP:SetHealthBarEnabled(false)
            PlayerESP:SetDistanceEnabled(false)
            PlayerESP:SetChamsEnabled(false)
            PlayerESP:SetSkeletonEnabled(false)
            PlayerESP:SetBoundingBoxEnabled(false)
        end)

        pcall(function()
            AntiAfkEnabled = false
            setAntiAfkVisualBlockEnabled(false)
            resetAntiAfkMovementTracker()

            local state =
                rawget(
                    _G,
                    AntiAfkStateKey
                )

            if type(state) == "table"
                and type(state.Restore)
                    == "function" then

                state.Restore()
            end

            rawset(
                _G,
                AntiAfkStateKey,
                nil
            )
        end)

        pcall(function()
            local state =
                rawget(
                    _G,
                    "__VITALITY_TOWER_MOVEMENT"
                )

            if type(state) == "table"
                and type(state.Restore)
                    == "function" then

                state.Restore()
            end

            rawset(
                _G,
                "__VITALITY_TOWER_MOVEMENT",
                nil
            )
        end)

        pcall(function()
            local state =
                rawget(
                    _G,
                    "__VITALITY_TOWER_TEAM_HEALER"
                )

            if type(state) == "table"
                and type(state.Stop)
                    == "function" then

                state.Stop()
            end

            rawset(
                _G,
                "__VITALITY_TOWER_TEAM_HEALER",
                nil
            )
        end)

        pcall(function()
            local state =
                rawget(
                    _G,
                    "__VITALITY_TOWER_SMART_DESYNC"
                )

            if type(state) == "table"
                and type(state.HardRestore)
                    == "function" then

                state.HardRestore()
            end

            rawset(
                _G,
                "__VITALITY_TOWER_SMART_DESYNC",
                nil
            )
        end)

        pcall(function()
            local state =
                rawget(
                    _G,
                    "__VITALITY_TOWER_SILENT_AIM"
                )

            if type(state) == "table"
                and type(state.Restore)
                    == "function" then

                state.Restore()
            end

            rawset(
                _G,
                "__VITALITY_TOWER_SILENT_AIM",
                nil
            )
        end)

        pcall(function()
            local state =
                rawget(
                    _G,
                    "__VITALITY_TOWER_SNIPER_EFFECTS"
                )

            if type(state) == "table"
                and type(state.RestoreAll)
                    == "function" then

                state.RestoreAll()
            end

            rawset(
                _G,
                "__VITALITY_TOWER_SNIPER_EFFECTS",
                nil
            )
        end)

        pcall(function()
            local buildState =
                rawget(
                    _G,
                    "__VITALITY_TOWER_MODULE_BUILD_STATE"
                )

            if type(buildState) == "table"
                and buildState.Window == Window then

                rawset(
                    _G,
                    "__VITALITY_TOWER_MODULE_BUILD_STATE",
                    nil
                )
            end
        end)
    end)

    -- ============================================================
    -- SAVED CONFIGURATION -> LIVE FEATURE STATE
    -- ============================================================
    -- The library loads saved flag VALUES before this game module builds its
    -- controls. That correctly restores the visual state of toggles/sliders/
    -- dropdowns, but the initial _saved(...) lookup intentionally does not fire
    -- each control's Callback. The result is a control that LOOKS enabled after
    -- re-execution while its backing feature state is still at its script default.
    --
    -- By this point every Tower control and feature callback has been created, so
    -- perform one final configuration pass with callbacks enabled. This makes a
    -- saved ON toggle actually start its feature automatically, and also reapplies
    -- saved slider/dropdown values to their backing state without requiring the
    -- user to toggle anything off/on manually.
    --
    -- Deferred by one scheduler step to avoid running callbacks re-entrantly while
    -- the game module itself is still returning to the library's game loader.
    task.defer(function()
        task.wait()

        pcall(function()
            if Window and type(Window.LoadConfiguration) == "function" then
                Window:LoadConfiguration(true)
            end
        end)
    end)

    -- Mark this exact interface build as complete only after every Tower
    -- control/feature has been constructed successfully.
    pcall(function()
        local buildState = rawget(_G, "__VITALITY_TOWER_MODULE_BUILD_STATE")
        if type(buildState) == "table" and buildState.Window == Window then
            buildState.Ready = true
        end
    end)

    return true
end
