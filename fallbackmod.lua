-- vitality's hub / unsupported-game fallback module
-- Generic component showcase used when no dedicated game module is registered.
-- Designed for Vitality Hub V2.7.2+

return function(context)
    local NovaField = assert(context.Library or context.NovaField, "Vitality library missing from fallback context")
    local Window = assert(context.Window, "Vitality window missing from fallback context")

    local General = Window:CreateTab("General", "home")

    local Inputs = Window:CreateTab("Inputs", "keyboard")

    local Appearance = Window:CreateTab("Appearance", "palette")

    local Settings = Window:CreateTab("Settings", "settings")


    -- FALLBACK / UNSUPPORTED-GAME NOTICE ----------------------------------------
    -- This module is intentionally loaded only when no dedicated game module matches.
    Window:SetScriptStatus("yellow", "Game not supported")

    local UnsupportedInfo = General:CreateSection({
        Name = "Game not supported",
        Description = "No dedicated vitality module is registered for this experience yet.",
        Side = "Right",
        Icon = "info",
    })

    UnsupportedInfo:CreateParagraph({
        Title = "Fallback interface",
        Content = "You are viewing vitality's generic component/test interface. "
            .. "GameId: " .. tostring(context.GameId or game.GameId)
            .. "  •  PlaceId: " .. tostring(context.PlaceId or game.PlaceId),
    })

    -- BASIC CONTROLS ------------------------------------------------------------

    local Basic = General:CreateSection({

        Name = "Basic Controls",

        Description = "Core controls and quick actions.",

        Side = "Left",

    })

    Basic:CreateButton({

        Name = "Run action",

        Info = "Execute the selected task.",

        Interact = "Run",

        Callback = function()

    -- This now obeys the Notifications toggle automatically.

            Window:Notify({

                Title = "Action complete",

                Content = "The selected task was executed.",

            })

        end,

    })

    Basic:CreateToggle({

        Name = "Notifications",

        Info = "Show in-game notifications.",

        CurrentValue = true,

        Flag = "Notifications",

        Behavior = "Notifications",

        Callback = function(value)

            print("Notifications:", value)

        end,

    })

    Basic:CreateToggle({

        Name = "Sound",

        Info = "Play interface sounds.",

        CurrentValue = true,

        Flag = "Sound",

        Behavior = "Sounds",

        Callback = function(value)

            print("Sound:", value)

        end,

    })

    Basic:CreateSlider({

        Name = "Intensity",

        Info = "Adjust the effect intensity.",

        Range = {0, 100},

        Increment = 1,

        Suffix = "%",

        CurrentValue = 40,

        Flag = "Intensity",

        Callback = function(value)

            print("Intensity:", value)

        end,

    })

    Basic:CreateInput({

        Name = "Amount",

        Info = "Enter a numeric value.",

        PlaceholderText = "Enter a number",

        NumbersOnly = true,

        RemoveTextAfterFocusLost = false,

        Flag = "Amount",

        Callback = function(text)

            print("Amount:", text)

        end,

    })

    Basic:CreateInput({

        Name = "Display name",

        Info = "Shown to other players.",

        PlaceholderText = "Player",

        CurrentValue = "Player",

        CharacterLimit = 15,

        RemoveTextAfterFocusLost = false,

        Flag = "DisplayName",

        Callback = function(text)

            print("Display name:", text)

        end,

    })

    -- SELECTION & MORE ----------------------------------------------------------

    local Selection = General:CreateSection({

        Name = "Selection & More",

        Description = "Additional input types and information.",

        Side = "Right",

    })

    Selection:CreateDropdown({

        Name = "Modules",

        Info = "Select multiple modules.",

        Options = {"Module A", "Module B", "Module C"},

        CurrentOption = {"Module A", "Module C"},

        MultiSelection = true,

        Flag = "Modules",

        Callback = function(options)

            print("Modules selected:", table.concat(options, ", "))

        end,

    })

    Selection:CreateStatus({

        Name = "Status",

        Info = "Current interface state.",

        CurrentValue = "Ready",

    })

    local Information = General:CreateSection({

        Name = "Information",

        TitleOnly = true,

        Icon = "info",

        Side = "Right",

    })

    Information:CreateParagraph({

        Title = "About this hub",

        Content = "A compact control surface with persistent settings.",

    })

    -- INPUTS / CONTROL STATES ---------------------------------------------------

    local ControlStates = Inputs:CreateSection({

        Name = "Control States",

        Description = "Lock, disable, hide, set, and read controls.",

        Side = "Left",

    })

    local DemoButton = ControlStates:CreateButton({

        Name = "Button",

        Info = "Default button state.",

        Interact = "Default",

        Callback = function()

            print("Pressed")

        end,

    })

    local DemoToggle = ControlStates:CreateToggle({

        Name = "Toggle",

        Info = "A lockable toggle.",

        CurrentValue = true,

        Flag = "DemoToggle",

    })

    local DemoSlider = ControlStates:CreateSlider({

        Name = "Slider",

        Info = "A lockable slider.",

        Range = {0, 100},

        CurrentValue = 50,

        Suffix = "%",

        Flag = "DemoSlider",

    })

    ControlStates:CreateButton({

        Name = "Toggle lock",

        Info = "Lock or unlock the controls above.",

        Interact = "Lock",

        Callback = function()

            local shouldLock = not DemoToggle:IsLocked()

            for _, control in ipairs({DemoButton, DemoToggle, DemoSlider}) do

                if shouldLock then

                    control:Lock("Locked by settings")

                else

                    control:Unlock()

                end

            end

        end,

    })

    -- APPEARANCE ---------------------------------------------------------------

    -- Theme and accent now live in one place only.

    local AppearanceSection = Appearance:CreateSection({

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

    local BorderSection = Appearance:CreateSection({

        Name = "Window Border",

        Description = "Control the rounded outer window stroke.",

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

    -- Apply saved values immediately; callbacks are reserved for user interaction.

    Window:SetBorderStrokeEnabled(BorderEnabled:Get())

    Window:SetBorderStrokeThickness(BorderThickness:Get())

    Window:SetBorderStrokeTransparency(BorderTransparency:Get() / 100)

    if FollowAccent:Get() then

        Window:SetBorderStrokeUseAccent(true)

    else

        Window:SetBorderStrokeColor(BorderColor:Get())

    end

    local AppearanceInfo = Appearance:CreateSection({

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

    -- SETTINGS -----------------------------------------------------------------

    local SettingsSection = Settings:CreateSection({

        Name = "vitality's hub",

        Description = "Shortcuts, motion, and hub controls.",

        Side = "Left",

    })

    SettingsSection:CreateKeybind({

        Name = "Toggle hub",

        Info = "Choose the shortcut used to open or close the hub.",

        CurrentKeybind = Window:GetToggleKey(),

        Flag = "InterfaceKeybind",

        Behavior = "ToggleInterface",

        Callback = function(keyName)

            print("Hub shortcut changed to:", keyName)

        end,

    })

    local AnimationsToggle = SettingsSection:CreateToggle({

        Name = "Hub animations",

        Info = "Animate tabs, popups, controls, and notifications.",

        CurrentValue = Window:GetAnimationsEnabled(),

        Flag = "InterfaceAnimations",

        Callback = function(enabled)

            Window:SetAnimationsEnabled(enabled)

        end,

    })

    local AnimationSpeed = SettingsSection:CreateSlider({

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

    SettingsSection:CreateButton({

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

    local AudioSection = Settings:CreateSection({

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

    local FeatureGuide = Settings:CreateSection({

        Name = "Feature API",

        Description = "Runtime controls and status tools.",

        Side = "Right",

    })

    FeatureGuide:CreateParagraph({

        Title = "State-first controls",

        Content = "Use Get, Set, Lock, Unlock, SetVisible, flags, and dropdown Refresh/Add/Remove when building features.",

    })

    FeatureGuide:CreateDropdown({

        Name = "Runtime status preview",

        Info = "Preview the top-bar script-health indicator.",

        Options = {"Not working", "Partially working", "Fully working"},

        CurrentOption = "Fully working",

        Callback = function(value)

            local levels = {

                ["Not working"] = "red",

                ["Partially working"] = "yellow",

                ["Fully working"] = "green",

            }

            Window:SetScriptStatus(levels[value], value)

        end,

    })

    -- The fallback should always remain visibly unsupported even though the
    -- generic controls themselves are fully functional.
    Window:SetScriptStatus("yellow", "Game not supported")

    return true
end
