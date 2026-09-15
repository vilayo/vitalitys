local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local Library = {
    Version = "2.13.1-LS",
    Flags = {},
    _openPopup = nil,
    _openPopupOwner = nil,
    _openPopupAnchor = nil,
    _openPopupCloser = nil,
    NotificationsEnabled = true,
    BroadcastsEnabled = true,
}

Library.Themes = {
    Dark = {
        Background = Color3.fromRGB(12, 12, 15),
        Surface = Color3.fromRGB(17, 17, 21),
        Surface2 = Color3.fromRGB(22, 22, 28),
        Surface3 = Color3.fromRGB(29, 29, 36),
        Border = Color3.fromRGB(52, 52, 63),
        BorderSoft = Color3.fromRGB(38, 38, 47),
        Accent = Color3.fromRGB(174, 153, 246),
        AccentDark = Color3.fromRGB(116, 96, 190),
        AccentSoft = Color3.fromRGB(67, 57, 94),
        AccentVisible = Color3.fromRGB(187, 169, 255),
        AccentText = Color3.fromRGB(18, 16, 24),
        SliderKnob = Color3.fromRGB(216, 205, 255),
        Button = Color3.fromRGB(156, 134, 232),
        ButtonHover = Color3.fromRGB(170, 148, 244),
        ButtonText = Color3.fromRGB(18, 16, 24),
        ButtonOutline = Color3.fromRGB(196, 181, 255),
        Text = Color3.fromRGB(239, 239, 243),
        Muted = Color3.fromRGB(174, 174, 186),
        Disabled = Color3.fromRGB(82, 82, 95),
        Success = Color3.fromRGB(111, 220, 166),
        Warning = Color3.fromRGB(244, 169, 69),
        Information = Color3.fromRGB(242, 211, 92),
        Danger = Color3.fromRGB(245, 105, 122),
    },

    Light = {
        Background = Color3.fromRGB(244, 244, 247),
        Surface = Color3.fromRGB(252, 252, 253),
        Surface2 = Color3.fromRGB(239, 239, 243),
        Surface3 = Color3.fromRGB(231, 231, 237),
        Border = Color3.fromRGB(199, 199, 209),
        BorderSoft = Color3.fromRGB(220, 220, 228),
        Accent = Color3.fromRGB(137, 112, 222),
        AccentDark = Color3.fromRGB(105, 83, 184),
        AccentSoft = Color3.fromRGB(226, 219, 249),
        AccentVisible = Color3.fromRGB(128, 103, 214),
        AccentText = Color3.fromRGB(255, 255, 255),
        SliderKnob = Color3.fromRGB(128, 103, 214),
        Button = Color3.fromRGB(128, 103, 214),
        ButtonHover = Color3.fromRGB(114, 90, 198),
        ButtonText = Color3.fromRGB(255, 255, 255),
        ButtonOutline = Color3.fromRGB(96, 74, 173),
        Text = Color3.fromRGB(26, 26, 31),
        Muted = Color3.fromRGB(88, 88, 99),
        Disabled = Color3.fromRGB(155, 155, 167),
        Success = Color3.fromRGB(30, 166, 105),
        Warning = Color3.fromRGB(184, 115, 24),
        Information = Color3.fromRGB(167, 133, 18),
        Danger = Color3.fromRGB(218, 70, 91),
    },
}

local function cloneTheme(theme)
    local copy = {}
    for key, value in pairs(theme) do
        copy[key] = value
    end
    return copy
end

-- Theme is intentionally mutated in place. Existing controls keep referencing
-- this same table, while Window:SetTheme swaps the actual palette values.
Library.Theme = cloneTheme(Library.Themes.Dark)

local Theme = Library.Theme

local THEME_COLOR_PROPERTIES = {
    BackgroundColor3 = true,
    TextColor3 = true,
    PlaceholderColor3 = true,
    ImageColor3 = true,
    Color = true,
    ScrollBarImageColor3 = true,
}

local THEME_ROLE_PRIORITY = {
    "Background", "Surface", "Surface2", "Surface3",
    "Border", "BorderSoft", "Text", "Muted", "Disabled",
    "AccentVisible", "Accent", "AccentDark", "AccentSoft",
    "SliderKnob", "AccentText", "Button", "ButtonHover",
    "ButtonText", "ButtonOutline", "Success", "Danger", "Warning", "Information",
}

local function detectThemeRole(value)
    if typeof(value) ~= "Color3" then return nil end
    for _, role in ipairs(THEME_ROLE_PRIORITY) do
        local themeColor = Theme[role]
        if typeof(themeColor) == "Color3" and value == themeColor then
            return role
        end
    end
    return nil
end

local function setThemeRole(object, property, role)
    if not object or not property then return end
    local attr = "NovaThemeRole_" .. property
    if role then
        object:SetAttribute(attr, role)
        if typeof(Theme[role]) == "Color3" then
            pcall(function() object[property] = Theme[role] end)
        end
    else
        object:SetAttribute(attr, nil)
    end
end

local function themeProperty(object, property, role)
    if not object then return end
    setThemeRole(object, property, role)
end


-- ============================================================
-- TYPOGRAPHY
-- ============================================================
-- Builder Sans is the default because it remains clearer at compact UI sizes.
-- Every text object remembers a weight role so font changes update the live UI.

local function resolveEnumFont(name, fallback)
    local ok, value = pcall(function()
        return Enum.Font[name]
    end)

    if ok and value then
        return value
    end

    return fallback or Enum.Font.Gotham
end

Library.FontPresets = {
    ["Builder Sans"] = {
        Regular = resolveEnumFont("BuilderSans", Enum.Font.Gotham),
        Medium = resolveEnumFont("BuilderSansMedium", Enum.Font.GothamMedium),
        Semibold = resolveEnumFont("BuilderSansMedium", Enum.Font.GothamSemibold),
        Bold = resolveEnumFont("BuilderSansBold", Enum.Font.GothamBold),
    },
    ["Gotham"] = {
        Regular = Enum.Font.Gotham,
        Medium = Enum.Font.GothamMedium,
        Semibold = Enum.Font.GothamSemibold,
        Bold = Enum.Font.GothamBold,
    },
    ["Source Sans"] = {
        Regular = resolveEnumFont("SourceSans", Enum.Font.Gotham),
        Medium = resolveEnumFont("SourceSansSemibold", Enum.Font.GothamMedium),
        Semibold = resolveEnumFont("SourceSansSemibold", Enum.Font.GothamSemibold),
        Bold = resolveEnumFont("SourceSansBold", Enum.Font.GothamBold),
    },
}

Library.DefaultFontPreset = "Builder Sans"

local function fontRoleFromEnum(font)
    local name = tostring(font or ""):lower()

    if name:find("bold", 1, true)
        or name:find("black", 1, true)
        or name:find("heavy", 1, true) then
        return "Bold"
    end

    if name:find("semibold", 1, true) then
        return "Semibold"
    end

    if name:find("medium", 1, true) then
        return "Medium"
    end

    return "Regular"
end

local function normalizeFontPreset(name)
    name = tostring(name or Library.DefaultFontPreset)

    if Library.FontPresets[name] then
        return name
    end

    local lowered = name:lower()

    for presetName in pairs(Library.FontPresets) do
        if presetName:lower() == lowered then
            return presetName
        end
    end

    return Library.DefaultFontPreset
end

local function resolveWindowFont(window, role, fallback)
    local presetName =
        normalizeFontPreset(
            window
            and window.FontPreset
            or Library.DefaultFontPreset
        )

    local preset =
        Library.FontPresets[presetName]
        or Library.FontPresets[Library.DefaultFontPreset]

    return
        (preset and preset[role or "Regular"])
        or (preset and preset.Regular)
        or fallback
        or Enum.Font.Gotham
end

local function create(className, props, children)
    local object = Instance.new(className)

    for key, value in pairs(props or {}) do
        if key == "Font" and typeof(value) == "EnumItem" then
            local fontRole = fontRoleFromEnum(value)
            object.Font = resolveWindowFont(Library._activeWindow, fontRole, value)
            object:SetAttribute("NovaFontRole", fontRole)
        else
            object[key] = value
        end

        if THEME_COLOR_PROPERTIES[key] then
            local role = detectThemeRole(value)
            if role then
                object:SetAttribute("NovaThemeRole_" .. key, role)
            end
        end
    end

    for _, child in ipairs(children or {}) do
        child.Parent = object
    end

    return object
end

-- Vitality uses a consistently rounded visual language. Small radii used for
-- indicator dots/lines are left alone; normal cards, buttons, fields, tabs and
-- popups receive a subtle extra radius automatically.
local function corner(parent, radius)
    local resolved = tonumber(radius) or 6
    if resolved >= 6 and resolved <= 13 then
        resolved = resolved + 2
    end
    return create("UICorner", {CornerRadius = UDim.new(0, resolved), Parent = parent})
end

local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Transparency = transparency or 0,
        Parent = parent,
    })
end

local function padding(parent, l, r, t, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or l or 0),
        PaddingBottom = UDim.new(0, b or t or l or 0),
        Parent = parent,
    })
end

local function tween(object, duration, props, style, direction)
    local info = TweenInfo.new(duration or 0.16, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out)
    local tw = TweenService:Create(object, info, props)
    tw:Play()
    return tw
end

local function bindHover(button, normal, hover)
    local function resolve(value)
        return type(value) == "function" and value() or value
    end
    button.MouseEnter:Connect(function()
        local color = resolve(hover)
        setThemeRole(button, "BackgroundColor3", detectThemeRole(color))
        tween(button, 0.12, {BackgroundColor3 = color})
    end)
    button.MouseLeave:Connect(function()
        local color = resolve(normal)
        setThemeRole(button, "BackgroundColor3", detectThemeRole(color))
        tween(button, 0.12, {BackgroundColor3 = color})
    end)
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[NovaField] Callback error: " .. tostring(err))
    end
end

local function roundTo(value, increment)
    if not increment or increment == 0 then return value end
    return math.floor((value / increment) + 0.5) * increment
end

local function incrementPrecision(increment)
    increment = math.abs(tonumber(increment) or 1)
    if increment == 0 then return 0 end
    local precision = 0
    while precision < 8 and math.abs(increment - math.floor(increment + 0.5)) > 1e-9 do
        increment *= 10
        precision += 1
    end
    return precision
end

local function normalizeSliderValue(value, min, max, increment)
    value = math.clamp(tonumber(value) or min, min, max)
    increment = math.abs(tonumber(increment) or 1)
    if increment > 0 then value = min + roundTo(value - min, increment) end
    value = math.clamp(value, min, max)
    local precision = incrementPrecision(increment)
    local scale = 10 ^ precision
    value = math.floor(value * scale + 0.5) / scale
    if math.abs(value) < 1 / (scale * 2) then value = 0 end
    return value
end

local function formatSliderValue(value, increment)
    local precision = incrementPrecision(increment)
    local formatted = string.format("%." .. tostring(precision) .. "f", value)
    if precision > 0 then
        formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    end
    return formatted
end

local function clamp01(n)
    return math.clamp(n, 0, 1)
end

local function colorToHex(color)
    return string.format("#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function hexToColor(text)
    text = tostring(text or ""):gsub("#", "")
    if #text == 3 then
        text = text:sub(1,1):rep(2) .. text:sub(2,2):rep(2) .. text:sub(3,3):rep(2)
    end
    if #text ~= 6 or not text:match("^[%da-fA-F]+$") then return nil end
    local r = tonumber(text:sub(1,2), 16)
    local g = tonumber(text:sub(3,4), 16)
    local b = tonumber(text:sub(5,6), 16)
    return Color3.fromRGB(r, g, b)
end

local function serialize(value)
    if typeof(value) == "Color3" then
        return {__type = "Color3", r = value.R, g = value.G, b = value.B}
    elseif type(value) == "table" then
        local out = {}
        for k, v in pairs(value) do out[k] = serialize(v) end
        return out
    end
    return value
end

local function deserialize(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.r or 0, value.g or 0, value.b or 0)
    elseif type(value) == "table" then
        local out = {}
        for k, v in pairs(value) do out[k] = deserialize(v) end
        return out
    end
    return value
end

local function resolveGuiParent(screenGui)
    local parent
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then parent = result end
    end
    if not parent then
        parent = CoreGui
    end

    if syn and syn.protect_gui then
        pcall(syn.protect_gui, screenGui)
    end

    local ok = pcall(function() screenGui.Parent = parent end)
    if not ok and LocalPlayer then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function makeText(parent, text, size, color, font, xAlign)
    return create("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or Theme.Text,
        TextSize = size or 14,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = xAlign or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
    })
end

local function linearChannel(value)
    if value <= 0.04045 then return value / 12.92 end
    return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
    return 0.2126 * linearChannel(color.R)
        + 0.7152 * linearChannel(color.G)
        + 0.0722 * linearChannel(color.B)
end

local function contrastRatio(a, b)
    local la, lb = luminance(a), luminance(b)
    local lighter, darker = math.max(la, lb), math.min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
end

local CONTRAST_DARK = Color3.fromRGB(12, 18, 30)
local CONTRAST_LIGHT = Color3.fromRGB(255, 255, 255)

local function contrastText(color)
    if contrastRatio(color, CONTRAST_DARK) >= contrastRatio(color, CONTRAST_LIGHT) then
        return CONTRAST_DARK
    end
    return CONTRAST_LIGHT
end

local function accentVariants(color, palette)
    palette = palette or Theme
    local h, s, v = color:ToHSV()
    local surface = palette.Surface or Theme.Surface
    local text = palette.Text or Theme.Text
    local background = palette.Background or Theme.Background

    local dark = Color3.fromHSV(h, math.clamp(s + 0.08, 0, 1), math.clamp(v * 0.72, 0, 1))
    local visible = color
    if contrastRatio(visible, surface) < 1.65 or contrastRatio(visible, background) < 1.45 then
        if luminance(surface) > 0.5 then
            visible = color:Lerp(CONTRAST_DARK, 0.42)
        else
            visible = color:Lerp(CONTRAST_LIGHT, 0.34)
        end
    end

    local soft = surface:Lerp(color, luminance(surface) > 0.5 and 0.18 or 0.30)
    if contrastRatio(soft, surface) < 1.10 then
        soft = surface:Lerp(text, 0.10)
    end

    local foreground = contrastText(color)
    local knob = contrastRatio(color, surface) < 1.65 and visible or color:Lerp(foreground, 0.18)
    return dark, soft, visible, foreground, knob
end

local function applyAccentPalette(palette, color)
    palette.Accent = color
    palette.AccentDark,
        palette.AccentSoft,
        palette.AccentVisible,
        palette.AccentText,
        palette.SliderKnob = accentVariants(color, palette)
end

local function applyButtonPalette(palette, color)
    local h, sat, val = color:ToHSV()
    palette.Button = color
    palette.ButtonHover = Color3.fromHSV(
        h,
        math.clamp(sat * 0.94 + 0.02, 0, 1),
        luminance(color) > 0.72 and math.clamp(val * 0.90, 0, 1) or math.clamp(val * 1.10, 0, 1)
    )
    palette.ButtonText = contrastText(color)
    palette.ButtonOutline = contrastRatio(color, palette.Surface or Theme.Surface) < 1.65
        and color:Lerp(contrastText(palette.Surface or Theme.Surface), 0.42)
        or color:Lerp(palette.ButtonText, 0.18)
end

local function applyThemeGradient(guiObject, window, kind, tint)
    local gradient = create("UIGradient", {
        Name = "Nova" .. kind .. "Gradient", Parent = guiObject,
    })
    local function refresh()
        if not guiObject.Parent then return end
        local first, last = window:GetGradient(kind)
        local options = window:GetGradientOptions(kind)
        if not options.Enabled then last = first end
        if tint then
            first = Theme.Surface2:Lerp(first, tint)
            last = Theme.Surface:Lerp(last, tint * 0.65)
        end
        setThemeRole(guiObject, "BackgroundColor3", nil)
        guiObject.BackgroundColor3 = Color3.new(1, 1, 1)
        gradient.Color = ColorSequence.new(first, last)
        gradient.Rotation = options.Rotation
    end
    refresh()
    window:_registerThemeRenderer(refresh)
    return gradient, refresh
end

local function applyButtonGradient(button)
    local window = Library._activeWindow
    local originalTransparency = button.BackgroundTransparency
    local face = create("Frame", {
        Name = "NovaButtonSurface", Parent = button,
        Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        ZIndex = button.ZIndex,
    })
    local rounding = button:FindFirstChildOfClass("UICorner")
    corner(face, rounding and rounding.CornerRadius.Offset or 9)
    local gradient = create("UIGradient", {Name = "NovaButtonGradient", Parent = face})
    local label = makeText(button, button.Text, button.TextSize, Theme.ButtonText, button.Font, Enum.TextXAlignment.Center)
    label.Name = "NovaButtonCaption"
    label.Size = UDim2.fromScale(1, 1)
    label.ZIndex = button.ZIndex + 1
    label:SetAttribute("NovaFontRole", button:GetAttribute("NovaFontRole") or "Semibold")
    -- Retain button.Text and TextColor3 for API compatibility; only its visual
    -- caption is separate, so UIGradient cannot multiply the glyph colors.
    button.TextTransparency = 1
    setThemeRole(button, "BackgroundColor3", nil)
    setThemeRole(button, "TextColor3", nil)
    setThemeRole(label, "TextColor3", nil)
    button.BackgroundTransparency = 1
    local hovered, pressed, locked = false, false, false
    local scale = create("UIScale", {Parent = button, Scale = 1})
    local function paint()
        if not button.Parent then return end
        local first, last = window:GetGradient("button")
        local options = window:GetGradientOptions("button")
        if not options.Enabled then last = first end
        if locked then
            first = first:Lerp(Theme.Surface3, 0.76)
            last = last:Lerp(Theme.Surface3, 0.76)
        elseif pressed then
            first, last = first:Lerp(Color3.new(), 0.10), last:Lerp(Color3.new(), 0.10)
        elseif hovered then
            first, last = first:Lerp(CONTRAST_LIGHT, 0.07), last:Lerp(CONTRAST_LIGHT, 0.07)
        end
        face.BackgroundColor3 = Color3.new(1, 1, 1)
        face.BackgroundTransparency = originalTransparency
        gradient.Color = ColorSequence.new(first, last)
        gradient.Rotation = options.Rotation
        -- Choose the foreground with the best worst-case contrast across the
        -- actual gradient, including its middle and interaction state.
        local darkScore, lightScore = math.huge, math.huge
        for i = 0, 16 do
            local sample = first:Lerp(last, i / 16):Lerp(Theme.Surface2, originalTransparency)
            darkScore = math.min(darkScore, contrastRatio(sample, CONTRAST_DARK))
            lightScore = math.min(lightScore, contrastRatio(sample, CONTRAST_LIGHT))
        end
        local foreground = darkScore >= lightScore and CONTRAST_DARK or CONTRAST_LIGHT
        button.TextColor3 = foreground
        label.TextColor3 = foreground
        label.TextTransparency = 0
        -- An outline protects glyph edges for extreme light-to-dark gradients;
        -- the selected gradient values themselves are never rewritten.
        label.TextStrokeColor3 = foreground == CONTRAST_DARK and CONTRAST_LIGHT or CONTRAST_DARK
        label.TextStrokeTransparency = math.max(darkScore, lightScore) < 4.5 and 0.18 or 1
        label.Text, label.Font, label.TextSize = button.Text, button.Font, button.TextSize
        local outline = button:FindFirstChildOfClass("UIStroke")
        if outline then
            outline.Transparency = locked and 0.75 or (hovered and 0.26 or 0.52)
        end
    end
    local function animateFace()
        paint()
        window:_tween(scale, 0.12, {Scale = pressed and not locked and 0.98 or 1})
    end
    button.MouseEnter:Connect(function() hovered = true; animateFace() end)
    button.MouseLeave:Connect(function() hovered = false; pressed = false; animateFace() end)
    button.MouseButton1Down:Connect(function() pressed = not locked; animateFace() end)
    button.MouseButton1Up:Connect(function() pressed = false; animateFace() end)
    button:GetPropertyChangedSignal("Text"):Connect(paint)
    button:GetPropertyChangedSignal("Font"):Connect(paint)
    button:GetPropertyChangedSignal("TextSize"):Connect(paint)
    window:_registerThemeRenderer(paint)
    paint()
    return gradient, function(isLocked)
        locked = isLocked == true
        button.Active = not locked
        animateFace()
    end
end

-- ============================================================
-- DASHBOARD VISUAL SYSTEM
-- ============================================================
-- These values intentionally live in the shared library so every current and
-- future game module inherits the same visual rhythm without changing APIs.
local UIStyle = {
    WindowWidth = 710, WindowHeight = 580, SidebarWidth = 124, TopbarHeight = 60,
    CardRadius = 12, CardGap = 12, CardInset = 16,
    HeaderHeight = 50, HeaderHeightWithSubtitle = 68,
    HeaderIconSize = 32, HeaderIconRadius = 8,
    SectionTitleSize = 14, SectionSubtitleSize = 11,
    LabelSize = 13, InfoSize = 11, FieldTextSize = 12, DescriptionSize = 11,
    RowInset = 16, RowGap = 10, RowMinHeight = 56, StatusRowHeight = 38,
    RowVerticalPadding = 12, ControlHeight = 32,
    ButtonWidth = 112, FieldWidth = 154, ToggleWidth = 48, ToggleHeight = 26,
    DividerInset = 16, SectionGap = 12, ResponsiveBreakpoint = 536,
    MinimumLabelWidth = 148, LoaderWidth = 320, LoaderHeight = 370,
}

local function applySoftSurfaceGradient(guiObject, window, topRole, bottomRole, rotation)
    -- UIGradient colors are multiplied by BackgroundColor3. Use a white base so
    -- the gradient represents the theme colors exactly rather than darkening them.
    setThemeRole(guiObject, "BackgroundColor3", nil)
    guiObject.BackgroundColor3 = Color3.new(1, 1, 1)

    local gradient = create("UIGradient", {
        Name = "NovaSurfaceGradient",
        Rotation = rotation or 118,
        Parent = guiObject,
    })

    local function refresh()
        if not guiObject.Parent then return end
        local isCard = (topRole == "Surface3" and bottomRole == "Surface2")
        local top = (isCard and window and window.SurfaceGradientStart) or Theme[topRole or "Surface3"] or Theme.Surface3
        local bottom = (isCard and window and window.SurfaceGradientEnd) or Theme[bottomRole or "Surface2"] or Theme.Surface2
        if isCard and window then
            local options = window:GetGradientOptions("surface")
            if not options.Enabled then bottom = top end
            gradient.Rotation = options.Rotation
        end
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, top),
            ColorSequenceKeypoint.new(1, bottom),
        })
    end

    refresh()
    if window and type(window._registerThemeRenderer) == "function" then
        window:_registerThemeRenderer(refresh)
    end
    return gradient
end

local function logicalScale(object)
    local scale, current = 1, object
    while current do
        local uiScale = current:FindFirstChildOfClass("UIScale")
        if uiScale then scale = scale * uiScale.Scale end
        current = current.Parent
    end
    return math.max(scale, 0.01)
end

local function textSize(label, width)
    local ok, bounds = pcall(TextService.GetTextSize, TextService,
        label.Text, label.TextSize, label.Font, Vector2.new(math.max(width, 1), 100000))
    if ok then return bounds end
    return Vector2.new(width, math.max(label.TextSize + 4, label.TextBounds.Y))
end

local function setIconColor(icon, color)
    if not icon then return end
    local role = type(color) == "string" and color or detectThemeRole(color)
    local resolved = role and Theme[role] or color
    if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
        setThemeRole(icon, "ImageColor3", role)
        if not role then icon.ImageColor3 = resolved end
        return
    elseif icon:IsA("TextLabel") or icon:IsA("TextButton") then
        setThemeRole(icon, "TextColor3", role)
        if not role then icon.TextColor3 = resolved end
        return
    end
    for _, descendant in ipairs(icon:GetDescendants()) do
        if descendant:GetAttribute("NovaIconPart") then
            if descendant:IsA("Frame") then
                setThemeRole(descendant, "BackgroundColor3", role)
                if not role then descendant.BackgroundColor3 = resolved end
            elseif descendant:IsA("UIStroke") then
                setThemeRole(descendant, "Color", role)
                if not role then descendant.Color = resolved end
            elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
                setThemeRole(descendant, "ImageColor3", role)
                if not role then descendant.ImageColor3 = resolved end
            elseif descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                setThemeRole(descendant, "TextColor3", role)
                if not role then descendant.TextColor3 = resolved end
            end
        end
    end
end

local function iconPart(parent, props)
    props = props or {}
    props.Parent = parent
    props.BorderSizePixel = 0
    props.BackgroundColor3 = props.BackgroundColor3 or Theme.Text
    local part = create("Frame", props)
    part:SetAttribute("NovaIconPart", true)
    return part
end

local function lineIcon(parent, position, size, rotation, color, radius)
    local line = iconPart(parent, {
        Position = position,
        Size = size,
        Rotation = rotation or 0,
        BackgroundColor3 = color or Theme.Text,
    })
    if radius then corner(line, radius) end
    return line
end

local function createVectorIcon(parent, name)
    name = string.lower(tostring(name or "diamond"))
    local holder = create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(22, 22),
    })

    local function outlinedBox(x, y, w, h, radius, thickness)
        local frame = iconPart(holder, {
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(w, h),
            BackgroundTransparency = 1,
        })
        corner(frame, radius or 3)
        local s = stroke(frame, Theme.Text, thickness or 1.5, 0)
        s:SetAttribute("NovaIconPart", true)
        return frame
    end

    local function dot(x, y, size)
        local d = iconPart(holder, {
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(size or 2, size or 2),
            BackgroundColor3 = Theme.Text,
        })
        corner(d, (size or 2) / 2)
        return d
    end

    local function keycap(x, y, w)
        local k = iconPart(holder, {
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(w or 2, 2),
            BackgroundColor3 = Theme.Text,
            BackgroundTransparency = 0.08,
        })
        corner(k, 1)
        return k
    end

    -- Draw a crisp line between two exact points. Using point-to-point geometry
    -- avoids the slightly crooked look that comes from rotating a frame around
    -- an arbitrary top-left position.
    local function segment(x1, y1, x2, y2, thickness, color)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local part = iconPart(holder, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
            Size = UDim2.fromOffset(length, thickness or 1.6),
            Rotation = math.deg(math.atan2(dy, dx)),
            BackgroundColor3 = color or Theme.Text,
        })
        corner(part, math.max(1, (thickness or 1.6) / 2))
        return part
    end

    -- Small path helpers used by the reusable tab-icon set.  The user-supplied
    -- references are normalized into the same 22 x 22 viewbox so every tab has
    -- equal visual weight and remains theme/recolor compatible.
    local function polyline(points, thickness, closed)
        for i = 1, #points - 1 do
            local a, b = points[i], points[i + 1]
            segment(a[1], a[2], b[1], b[2], thickness)
        end
        if closed and #points > 2 then
            local a, b = points[#points], points[1]
            segment(a[1], a[2], b[1], b[2], thickness)
        end
    end

    local function outlinedCircle(cx, cy, diameter, thickness)
        local ring = iconPart(holder, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx, cy),
            Size = UDim2.fromOffset(diameter, diameter),
            BackgroundTransparency = 1,
        })
        corner(ring, diameter / 2)
        local ringStroke = stroke(ring, Theme.Text, thickness or 1.7, 0)
        ringStroke:SetAttribute("NovaIconPart", true)
        return ring
    end

    local function arc(cx, cy, rx, ry, startDegrees, endDegrees, steps, thickness)
        local points = {}
        steps = math.max(2, steps or 8)
        for i = 0, steps do
            local t = math.rad(startDegrees + (endDegrees - startDegrees) * (i / steps))
            table.insert(points, {cx + math.cos(t) * rx, cy + math.sin(t) * ry})
        end
        polyline(points, thickness or 1.7, false)
    end

    if name == "home" or name == "main" then
        -- Reference 4: rounded house outline with a centered arched doorway.
        polyline({
            {2.5, 9.0}, {11.0, 1.8}, {19.5, 9.0},
            {19.5, 17.7}, {18.8, 19.2}, {3.2, 19.2}, {2.5, 17.7},
        }, 1.85, true)
        outlinedBox(8.6, 12.4, 4.8, 6.8, 2.4, 1.75)

    elseif name == "teleports" or name == "teleport" or name == "location" or name == "pin" then
        -- Reference 1: map-pin / teleport marker.
        polyline({
            {11.0, 1.4}, {14.6, 2.2}, {17.4, 4.7}, {18.4, 8.0},
            {17.8, 11.0}, {16.0, 14.0}, {13.8, 16.8}, {11.0, 20.3},
            {8.2, 16.8}, {6.0, 14.0}, {4.2, 11.0}, {3.6, 8.0},
            {4.6, 4.7}, {7.4, 2.2},
        }, 1.85, true)
        outlinedCircle(11.0, 8.0, 5.4, 1.8)

    elseif name == "player_esp" or name == "esp" or name == "eye" then
        -- Reference 2: eye silhouette used by Player ESP.
        polyline({
            {1.7, 11.0}, {4.0, 7.6}, {7.3, 5.3}, {11.0, 4.5},
            {14.7, 5.3}, {18.0, 7.6}, {20.3, 11.0},
            {18.0, 14.4}, {14.7, 16.7}, {11.0, 17.5},
            {7.3, 16.7}, {4.0, 14.4},
        }, 1.8, true)
        outlinedCircle(11.0, 11.0, 6.0, 1.8)

    elseif name == "players" or name == "users" or name == "group" then
        -- Reference 3: two-player / group icon.
        outlinedCircle(7.1, 7.0, 5.8, 1.75)
        outlinedCircle(14.9, 5.2, 5.2, 1.65)
        arc(8.1, 18.4, 5.5, 5.4, 180, 360, 9, 1.85)
        polyline({
            {12.5, 11.9}, {14.0, 11.1}, {15.8, 10.9}, {17.5, 11.5},
            {18.7, 12.8}, {19.2, 14.5}, {19.3, 16.1},
        }, 1.8, false)

    elseif name == "sniper" or name == "scope" or name == "crosshair" then
        -- Reference 5: scope ring with four inward ticks and a bold center cross.
        outlinedCircle(11.0, 11.0, 18.6, 1.85)
        segment(11.0, 1.7, 11.0, 5.0, 2.0)
        segment(11.0, 17.0, 11.0, 20.3, 2.0)
        segment(1.7, 11.0, 5.0, 11.0, 2.0)
        segment(17.0, 11.0, 20.3, 11.0, 2.0)
        segment(8.0, 11.0, 14.0, 11.0, 2.35)
        segment(11.0, 8.0, 11.0, 14.0, 2.35)

    elseif name == "character" or name == "user" or name == "person" then
        -- Reference 6: single-character bust.
        outlinedBox(7.5, 2.2, 7.0, 7.5, 3.0, 1.8)
        arc(11.0, 19.3, 7.2, 6.2, 180, 360, 10, 1.85)

    elseif name == "items" or name == "item" or name == "item_esp" or name == "sparkles" then
        -- Reference 7: large four-point sparkle with two supporting sparkles.
        polyline({
            {9.6, 2.0}, {11.8, 7.2}, {17.3, 9.8}, {12.0, 12.2},
            {9.6, 18.3}, {7.2, 12.2}, {2.0, 9.8}, {7.4, 7.2},
        }, 1.75, true)
        polyline({
            {17.0, 1.9}, {18.0, 4.0}, {20.1, 5.0}, {18.0, 6.0},
            {17.0, 8.1}, {16.0, 6.0}, {13.9, 5.0}, {16.0, 4.0},
        }, 1.45, true)
        polyline({
            {16.7, 13.9}, {17.7, 16.0}, {19.8, 17.0}, {17.7, 18.0},
            {16.7, 20.1}, {15.7, 18.0}, {13.6, 17.0}, {15.7, 16.0},
        }, 1.45, true)

    elseif name == "keyboard" then
        -- Compact keyboard with readable key rows at 20px.
        outlinedBox(1.5, 5.0, 19.0, 12.5, 3.0, 1.5)
        for _, x in ipairs({4.0, 7.1, 10.2, 13.3, 16.4}) do keycap(x, 8.0, 2.0) end
        for _, x in ipairs({4.0, 7.1, 10.2, 13.3, 16.4}) do keycap(x, 11.0, 2.0) end
        keycap(6.0, 14.0, 10.0)

    elseif name == "palette" then
        -- Artist palette based on the supplied reference. The brush makes the
        -- silhouette immediately recognizable instead of reading like a face.
        outlinedBox(2.0, 3.2, 15.4, 15.6, 7.6, 1.55)
        dot(5.6, 7.0, 2.2)
        dot(9.2, 5.6, 2.2)
        dot(5.0, 11.0, 2.2)
        outlinedBox(10.2, 12.0, 4.0, 3.6, 2.0, 1.35)
        segment(12.5, 15.3, 19.6, 4.2, 2.1)
        segment(11.1, 16.9, 13.5, 13.2, 3.5)
        dot(10.0, 17.0, 3.6)

    elseif name == "settings" or name == "gear" then
        -- Keep the existing slider-style settings icon.
        lineIcon(holder, UDim2.fromOffset(3, 5), UDim2.fromOffset(16, 2), 0, Theme.Text, 1)
        lineIcon(holder, UDim2.fromOffset(3, 10), UDim2.fromOffset(16, 2), 0, Theme.Text, 1)
        lineIcon(holder, UDim2.fromOffset(3, 15), UDim2.fromOffset(16, 2), 0, Theme.Text, 1)
        dot(7, 4, 4)
        dot(14, 9, 4)
        dot(9, 14, 4)

    elseif name == "list" then
        for row = 0, 2 do
            dot(3, 5 + row * 6, 3)
            lineIcon(holder, UDim2.fromOffset(8, 6 + row * 6), UDim2.fromOffset(11, 2), 0, Theme.Text, 1)
        end

    elseif name == "key" then
        outlinedBox(2, 3, 9, 9, 5, 1.5)
        lineIcon(holder, UDim2.fromOffset(9, 11), UDim2.fromOffset(11, 2), 35, Theme.Text, 1)
        lineIcon(holder, UDim2.fromOffset(15, 14), UDim2.fromOffset(2, 4), 0, Theme.Text, 1)
        lineIcon(holder, UDim2.fromOffset(18, 12), UDim2.fromOffset(2, 4), 0, Theme.Text, 1)

    elseif name == "info" then
        outlinedBox(2, 2, 18, 18, 9, 1.5)
        dot(10, 5, 2)
        lineIcon(holder, UDim2.fromOffset(10, 9), UDim2.fromOffset(2, 7), 0, Theme.Text, 1)

    elseif name == "bell" then
        outlinedBox(5, 4, 12, 12, 6, 1.5)
        lineIcon(holder, UDim2.fromOffset(3, 15), UDim2.fromOffset(16, 2), 0, Theme.Text, 1)
        dot(9, 18, 4)

    elseif name == "flask" then
        lineIcon(holder, UDim2.fromOffset(8, 3), UDim2.fromOffset(6, 2), 0, Theme.Text, 1)
        lineIcon(holder, UDim2.fromOffset(9, 4), UDim2.fromOffset(2, 7), 0, Theme.Text, 1)
        lineIcon(holder, UDim2.fromOffset(12, 4), UDim2.fromOffset(2, 7), 0, Theme.Text, 1)
        outlinedBox(5, 10, 12, 9, 4, 1.5)
        lineIcon(holder, UDim2.fromOffset(7, 15), UDim2.fromOffset(8, 1), 0, Theme.Text, 1)

    elseif name == "vitality" or name == "pulse" then
        segment(1, 12, 5, 12, 1.7)
        segment(5, 12, 7, 9, 1.7)
        segment(7, 9, 9, 14, 1.7)
        segment(9, 14, 12, 3, 1.7)
        segment(12, 3, 15, 18, 1.7)
        segment(15, 18, 17, 12, 1.7)
        segment(17, 12, 21, 12, 1.7)


    elseif name == "roblox" then
        local outer = iconPart(holder, {
            Position = UDim2.fromOffset(5, 5),
            Size = UDim2.fromOffset(12, 12),
            Rotation = 14,
            BackgroundTransparency = 1,
        })
        local s = stroke(outer, Theme.Text, 1.6, 0)
        s:SetAttribute("NovaIconPart", true)
        local hole = iconPart(outer, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(4, 4),
            BackgroundColor3 = Theme.Text,
        })
        corner(hole, 1)

    else
        local diamond = iconPart(holder, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(9, 9),
            Rotation = 45,
            BackgroundTransparency = 1,
        })
        corner(diamond, 2)
        local s = stroke(diamond, Theme.AccentVisible, 1.5, 0)
        s:SetAttribute("NovaIconPart", true)
    end

    return holder
end

-- Uploaded tab artwork selected for vitality's hub. Keep these keys narrow on
-- purpose: generic library icons such as "home", "user", "info", etc. continue
-- using the built-in vector set and cannot be accidentally replaced by an
-- experience-restricted image asset.
Library.PremiumIconAssets = {
    -- Canonical uploaded tab artwork. These PNGs use white artwork on transparent
    -- backgrounds so ImageColor3 can tint them with the active theme.
    main = "rbxassetid://139225144207307",
    character = "rbxassetid://101442217606874",
    teleports = "rbxassetid://99145282742278",
    items = "rbxassetid://118238817418916",
    esp = "rbxassetid://71791866160683",
    players = "rbxassetid://95631924723817",
    sniper = "rbxassetid://112165756164471",
    owner = "rbxassetid://70677031724113",

    -- Reusable compatibility aliases. Modules can use the short canonical names
    -- above or the descriptive ESP aliases below without hardcoding asset IDs.
    item_esp = "rbxassetid://118238817418916",
    player_esp = "rbxassetid://71791866160683",
}

local function createImageIcon(parent, asset)
    return create("ImageLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(22, 22),
        Image = asset,
        ImageColor3 = Theme.Text,
        ScaleType = Enum.ScaleType.Fit,
    })
end

-- Premium tab assets get a vector fallback underneath them. If Roblox cannot
-- load an uploaded image in the current experience (moderation/permissions),
-- the tab remains usable and displays the matching built-in vector icon instead
-- of becoming blank.
local function createPremiumIcon(parent, name, asset)
    local holder = create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(22, 22),
    })

    -- Keep a native vector underneath as a last-resort fallback, but do not gate
    -- the uploaded image behind ImageLabel.IsLoaded. Some executor environments
    -- report IsLoaded unreliably even while rbxassetid content renders correctly.
    local fallback = createVectorIcon(holder, name)
    fallback.AnchorPoint = Vector2.new(0.5, 0.5)
    fallback.Position = UDim2.fromScale(0.5, 0.5)
    fallback.Size = UDim2.fromOffset(22, 22)
    fallback.Visible = false

    local imageLabel = create("ImageLabel", {
        Parent = holder,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = asset,
        ImageColor3 = Theme.Text,
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = holder.ZIndex + 2,
    })
    imageLabel:SetAttribute("NovaIconPart", true)

    local function useUploadedImage(imageSource)
        if not holder.Parent or not imageLabel.Parent then return end
        if imageSource then imageLabel.Image = imageSource end
        imageLabel.ImageTransparency = 0
        fallback.Visible = false
    end

    local function useVectorFallback()
        if not holder.Parent or not imageLabel.Parent then return end
        imageLabel.ImageTransparency = 1
        fallback.Visible = true
    end

    -- Try to preload the direct asset URI. If Roblox rejects that exact form
    -- (for example when the supplied ID is a decal wrapper rather than the
    -- underlying image), try the asset thumbnail URI before falling back.
    task.spawn(function()
        local directOk = pcall(function()
            ContentProvider:PreloadAsync({imageLabel})
        end)
        if not holder.Parent then return end
        if directOk then
            useUploadedImage()
            return
        end

        local numericId = tostring(asset or ""):match("(%d+)")
        if numericId then
            local thumbnail = "rbxthumb://type=Asset&id=" .. numericId .. "&w=150&h=150"
            imageLabel.Image = thumbnail
            imageLabel.ImageTransparency = 0
            local thumbOk = pcall(function()
                ContentProvider:PreloadAsync({imageLabel})
            end)
            if not holder.Parent then return end
            if thumbOk then
                useUploadedImage(thumbnail)
                return
            end
        end

        useVectorFallback()
    end)

    return holder
end

local function createIcon(parent, image, fallback)
    if image == nil then
        return createVectorIcon(parent, fallback or "diamond")
    end

    if type(image) == "string" then
        local lower = string.lower(image)

        local premiumAsset = Library.PremiumIconAssets[lower]
        if premiumAsset then
            return createPremiumIcon(parent, lower, premiumAsset)
        end

        if lower:match("^rbxassetid://") then
            return createImageIcon(parent, image)
        end

        if tonumber(image) then
            image = tonumber(image)
        elseif lower:match("^[%a_]+$") then
            return createVectorIcon(parent, lower)
        end
    end

    if type(image) == "number" then
        return createImageIcon(parent, "rbxassetid://" .. tostring(image))
    end

    return createVectorIcon(parent, fallback or "diamond")
end

local function createChevron(parent, open)
    local holder = create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(18, 18),
    })
    local left = lineIcon(holder, UDim2.fromOffset(4, 8), UDim2.fromOffset(7, 2), open and -42 or 42, Theme.Text, 1)
    local right = lineIcon(holder, UDim2.fromOffset(9, 8), UDim2.fromOffset(7, 2), open and 42 or -42, Theme.Text, 1)
    local function setOpen(isOpen)
        left.Rotation = isOpen and -42 or 42
        right.Rotation = isOpen and 42 or -42
    end
    return holder, setOpen
end

local function createCheckmark(parent, color, zindex)
    local holder = create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = zindex or 1,
    })
    local a = lineIcon(holder, UDim2.fromScale(0.19, 0.49), UDim2.fromScale(0.38, 0.12), 45, color or Theme.Text, 1)
    a.ZIndex = zindex or 1
    local b = lineIcon(holder, UDim2.fromScale(0.42, 0.41), UDim2.fromScale(0.50, 0.12), -45, color or Theme.Text, 1)
    b.ZIndex = zindex or 1
    return holder
end

local WindowMethods = {}
WindowMethods.__index = WindowMethods

-- ============================================================
-- GLOBAL WINDOW SINGLETON
-- ============================================================
-- Library._activeWindow only protects one loaded copy of the library. Re-running
-- the loadstring produces a fresh Library table, so use an executor-global
-- registry as the authoritative "is Vitality already open?" check.

local VITALITY_SINGLETON_KEY =
    "__VITALITY_HUB_ACTIVE_WINDOW"

local function normalizeWindowRole(value)
    local role = tostring(value or "Main")
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    if role == "" or role:lower() == "main" then
        return "Main"
    end

    return role:gsub("[^%w_%-]", "_")
end

local function vitalitySingletonKey(role)
    role = normalizeWindowRole(role)
    if role == "Main" then
        return VITALITY_SINGLETON_KEY
    end

    return VITALITY_SINGLETON_KEY
        .. "__"
        .. role
end

local function getVitalityGlobalEnvironment()
    local ok, env =
        pcall(function()
            if type(getgenv) == "function" then
                return getgenv()
            end

            return _G
        end)

    if ok and type(env) == "table" then
        return env
    end

    return _G
end

local function getVitalitySingleton(role)
    local env =
        getVitalityGlobalEnvironment()

    local state =
        rawget(
            env,
            vitalitySingletonKey(role)
        )

    if type(state) ~= "table" then
        return nil
    end

    return state
end

local function singletonWindowIsAlive(state)
    if type(state) ~= "table" then
        return false
    end

    local window =
        state.Window

    if type(window) ~= "table"
        or window._destroyed == true then

        return false
    end

    local gui =
        window.Gui
        or state.Gui

    if not gui then
        return false
    end

    local ok, parent =
        pcall(function()
            return gui.Parent
        end)

    return ok and parent ~= nil
end

local function setVitalitySingleton(window, gui, role)
    local env =
        getVitalityGlobalEnvironment()

    role = normalizeWindowRole(
        role
        or (
            type(window) == "table"
            and window._windowRole
        )
        or "Main"
    )

    rawset(
        env,
        vitalitySingletonKey(role),
        {
            Window = window,
            Gui = gui,
            Role = role,
            CreatedAt = os.clock(),
        }
    )
end

local function clearVitalitySingleton(window, role)
    local env =
        getVitalityGlobalEnvironment()

    role = normalizeWindowRole(
        role
        or (
            type(window) == "table"
            and window._windowRole
        )
        or "Main"
    )

    local key =
        vitalitySingletonKey(role)

    local state =
        rawget(
            env,
            key
        )

    -- Never let an old/delayed Destroy() clear a newer active window.
    if type(state) == "table"
        and (
            window == nil
            or state.Window == window
        ) then

        rawset(
            env,
            key,
            nil
        )
    end
end

local TabMethods = {}
TabMethods.__index = TabMethods

local SectionMethods = {}
SectionMethods.__index = SectionMethods

local function pointInside(guiObject, point)
    if not guiObject or not guiObject.Parent or not guiObject.Visible then return false end
    local position, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function Library:_registerPopup(popup, owner, anchor, closer)
    self._openPopup = popup
    self._openPopupOwner = owner
    self._openPopupAnchor = anchor
    self._openPopupCloser = closer
end

function Library:_forgetPopup(popup)
    if self._openPopup ~= popup then return end
    self._openPopup = nil
    self._openPopupOwner = nil
    self._openPopupAnchor = nil
    self._openPopupCloser = nil
end

function Library:_closePopup(immediate)
    local popup = self._openPopup
    local closer = self._openPopupCloser
    self._openPopup = nil
    self._openPopupOwner = nil
    self._openPopupAnchor = nil
    self._openPopupCloser = nil
    if popup then
        if type(closer) == "function" then
            local ok = pcall(closer, immediate == true)
            if ok then return end
        end
        pcall(function() popup:Destroy() end)
    end
end

local function resolveTooltipValue(value)
    if type(value) == "function" then
        local ok, resolved = pcall(value)
        return ok and resolved or nil
    end
    return value
end

function WindowMethods:AttachTooltip(target, content, options)
    if not target or not target:IsA("GuiObject") then return nil end
    options = type(options) == "table" and options or {}
    if target:IsA("GuiButton") then target.Active = true end

    local controller = {Target = target, Popup = nil, Hovered = false, PopupHovered = false, Token = 0}

    local function close(immediate)
        controller.Token = controller.Token + 1
        local popup = controller.Popup
        controller.Popup = nil
        if not popup then return end
        Library:_forgetPopup(popup)
        if immediate then
            popup:Destroy()
            return
        end
        self:_tween(popup, 0.12, {GroupTransparency = 1}, Enum.EasingStyle.Quad)
        task.delay(0.13, function()
            if popup.Parent then popup:Destroy() end
        end)
    end

    local function show()
        if self._destroyed or not self.Gui or not self.Gui.Parent or not target.Parent then return end
        local bodyText = tostring(resolveTooltipValue(content) or "")
        local titleText = tostring(resolveTooltipValue(options.Title) or "Details")
        if bodyText == "" and titleText == "" then return end

        close(true)
        Library:_closePopup(true)

        local width = math.clamp(tonumber(options.Width) or 320, 220, 430)
        local bodyBounds = TextService:GetTextSize(
            bodyText,
            12,
            Enum.Font.Gotham,
            Vector2.new(width - 28, 1000)
        )
        local height = math.clamp(bodyBounds.Y + 58, 78, 260)
        local popup = create("CanvasGroup", {
            Parent = self.Gui,
            Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = Theme.Surface2,
            BorderSizePixel = 0,
            GroupTransparency = 1,
            ZIndex = 900,
        })
        controller.Popup = popup
        corner(popup, 10)
        stroke(popup, Theme.Border, 1, 0.22)
        applySoftSurfaceGradient(popup, self, "Surface3", "Surface2", 110)

        local accent = create("Frame", {
            Parent = popup,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = resolveTooltipValue(options.Color) or Theme.AccentVisible,
            BorderSizePixel = 0,
            ZIndex = 902,
        })
        corner(accent, 2)

        local titleLabel = makeText(popup, titleText, 13, Theme.Text, Enum.Font.GothamSemibold)
        titleLabel.Position = UDim2.fromOffset(14, 10)
        titleLabel.Size = UDim2.new(1, -28, 0, 20)
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = 903

        local bodyLabel = makeText(popup, bodyText, 12, Theme.Muted, Enum.Font.Gotham)
        bodyLabel.Position = UDim2.fromOffset(14, 34)
        bodyLabel.Size = UDim2.new(1, -28, 1, -44)
        bodyLabel.TextWrapped = true
        bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
        bodyLabel.LineHeight = 1.08
        bodyLabel.ZIndex = 903

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local anchorPosition = target.AbsolutePosition
        local anchorSize = target.AbsoluteSize
        local placement = tostring(options.Placement or "vertical"):lower()
        local gap = math.max(6, tonumber(options.Gap) or 10)

        local x, y
        if placement == "side" or placement == "horizontal" then
            local rightX = anchorPosition.X + anchorSize.X + gap
            local leftX = anchorPosition.X - width - gap

            if rightX + width <= viewport.X - 8 then
                x = rightX
            elseif leftX >= 8 then
                x = leftX
            else
                x = math.clamp(
                    anchorPosition.X + (anchorSize.X - width) * 0.5,
                    8,
                    math.max(8, viewport.X - width - 8)
                )
            end

            y = math.clamp(
                anchorPosition.Y + (anchorSize.Y - height) * 0.5,
                8,
                math.max(8, viewport.Y - height - 8)
            )
        else
            x = math.clamp(anchorPosition.X, 8, math.max(8, viewport.X - width - 8))
            local below = anchorPosition.Y + anchorSize.Y + gap
            y = below + height <= viewport.Y - 8
                and below
                or math.max(8, anchorPosition.Y - height - gap)
        end

        popup.Position = UDim2.fromOffset(x, y)

        popup.MouseEnter:Connect(function() controller.PopupHovered = true end)
        popup.MouseLeave:Connect(function()
            controller.PopupHovered = false
            if not controller.Hovered then close(false) end
        end)

        Library:_registerPopup(popup, controller, target, close)
        self:_tween(popup, 0.15, {GroupTransparency = 0}, Enum.EasingStyle.Quint)
    end

    self:_trackConnection(target.MouseEnter:Connect(function()
        controller.Hovered = true
        controller.Token = controller.Token + 1
        local token = controller.Token
        task.delay(math.max(0, tonumber(options.Delay) or 0.16), function()
            if controller.Hovered and controller.Token == token then show() end
        end)
    end))

    self:_trackConnection(target.MouseLeave:Connect(function()
        controller.Hovered = false
        controller.Token = controller.Token + 1
        task.delay(0.08, function()
            if not controller.Hovered and not controller.PopupHovered then close(false) end
        end)
    end))

    self:_trackConnection(target.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then show() end
    end))

    function controller:Show() show() end
    function controller:Hide(immediate) close(immediate == true) end
    function controller:Destroy() close(true) end
    return controller
end

local function attachDataTooltip(window, target, data)
    if type(data) ~= "table" then return nil end
    local content = data.Tooltip or data.Comment or data.HoverText
    if content == nil or tostring(content) == "" then return nil end
    return window:AttachTooltip(target, content, {
        Title = data.TooltipTitle or data.Name or data.Title or "Details",
        Width = data.TooltipWidth,
    })
end

function WindowMethods:_trackConnection(connection)
    if not connection then
        return connection
    end

    if self._destroyed then
        pcall(function()
            connection:Disconnect()
        end)
        return connection
    end

    self._connections = self._connections or {}
    table.insert(self._connections, connection)
    return connection
end

function WindowMethods:TrackConnection(connection)
    return self:_trackConnection(connection)
end

function WindowMethods:AddCleanup(callback)
    if type(callback) ~= "function" then
        return false
    end

    if self._destroyed then
        pcall(callback)
        return false
    end

    self._cleanupCallbacks = self._cleanupCallbacks or {}
    table.insert(self._cleanupCallbacks, callback)
    return true
end

function WindowMethods:_runCleanupCallbacks()
    local callbacks = self._cleanupCallbacks or {}
    self._cleanupCallbacks = {}

    for i = #callbacks, 1, -1 do
        pcall(callbacks[i])
    end
end

function WindowMethods:_motionDuration(base)
    local motion = self.Motion or {}
    if motion.Enabled == false or motion.ReducedMotion == true then return 0 end
    return math.max(0, tonumber(base) or 0) / math.max(tonumber(motion.Speed) or 1, 0.1)
end

function WindowMethods:_tween(object, duration, properties, style, direction)
    local adjusted = self:_motionDuration(duration)
    if adjusted <= 0 then
        for property, value in pairs(properties or {}) do
            pcall(function() object[property] = value end)
        end
        return nil
    end
    return tween(
        object,
        adjusted,
        properties,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
end

local function normalizeKeyName(value, fallback)
    local name
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        name = value.Name
    elseif type(value) == "string" then
        name = value:gsub("^Enum%.KeyCode%.", "")
    end
    if name and Enum.KeyCode[name] and Enum.KeyCode[name] ~= Enum.KeyCode.Unknown then
        return name
    end
    return fallback
end

function WindowMethods:SetAnimationsEnabled(enabled)
    self.Motion.Enabled = enabled ~= false
    return self.Motion.Enabled
end

function WindowMethods:GetAnimationsEnabled()
    return self.Motion.Enabled ~= false
end

function WindowMethods:SetReducedMotion(enabled)
    self.Motion.ReducedMotion = enabled == true
    return self.Motion.ReducedMotion
end

function WindowMethods:SetMotionSpeed(speed)
    self.Motion.Speed = math.clamp(tonumber(speed) or 1, 0.35, 2.5)
    return self.Motion.Speed
end

function WindowMethods:GetMotionSpeed()
    return self.Motion.Speed or 1
end

function WindowMethods:GetFontOptions()
    return {"Builder Sans", "Gotham", "Source Sans"}
end

function WindowMethods:GetFontPreset()
    return normalizeFontPreset(self.FontPreset or Library.DefaultFontPreset)
end

function WindowMethods:SetFontPreset(name)
    self.FontPreset = normalizeFontPreset(name)

    if self.Gui then
        for _, object in ipairs(self.Gui:GetDescendants()) do
            if object:IsA("TextLabel")
                or object:IsA("TextButton")
                or object:IsA("TextBox") then

                local role =
                    object:GetAttribute("NovaFontRole")
                    or "Regular"

                pcall(function()
                    object.Font =
                        resolveWindowFont(
                            self,
                            role,
                            object.Font
                        )
                end)
            end
        end
    end

    self:_saveConfig()
    return self.FontPreset
end

function WindowMethods:SetToggleKey(value)
    -- Some secondary windows (currently DeveloperPreview) intentionally use a
    -- dedicated shortcut that must never inherit or be changed by the main hub.
    if self._fixedToggleKeyName then
        self.ToggleKey = Enum.KeyCode[self._fixedToggleKeyName]
        return self._fixedToggleKeyName
    end

    local name = normalizeKeyName(value, self.ToggleKey and self.ToggleKey.Name or "RightShift")
    self.ToggleKey = Enum.KeyCode[name]
    return name
end

function WindowMethods:GetToggleKey()
    return self.ToggleKey and self.ToggleKey.Name or "RightShift"
end


function WindowMethods:SetNotificationsEnabled(enabled)
    self.NotificationsEnabled = enabled ~= false
    Library.NotificationsEnabled = self.NotificationsEnabled
    if not self.NotificationsEnabled and self.Gui then
        local holder = self.Gui:FindFirstChild("NovaNotifications")
        if holder then holder:Destroy() end
    end
    return self.NotificationsEnabled
end

function WindowMethods:GetNotificationsEnabled()
    return self.NotificationsEnabled ~= false
end

function WindowMethods:SetSoundsEnabled(enabled)
    self.SoundsEnabled = enabled == true
    if self.SoundsEnabled then
        self:_prepareSounds()
    else
        for _, sound in pairs(self._soundObjects or {}) do
            pcall(function() sound:Stop() end)
        end
    end
    return self.SoundsEnabled
end

function WindowMethods:GetSoundsEnabled()
    return self.SoundsEnabled == true
end

function WindowMethods:SetSoundVolume(value)
    self.SoundVolume = math.clamp(tonumber(value) or self.SoundVolume or 0.55, 0, 1)
    if self._soundGroup then self._soundGroup.Volume = self.SoundVolume end
    return self.SoundVolume
end

function WindowMethods:GetSoundVolume()
    return self.SoundVolume or 0.55
end

function WindowMethods:_soundSpec(kind)
    local sounds = self.SoundSettings or {}
    local profiles = type(sounds.Profiles) == "table" and sounds.Profiles or sounds
    local spec = profiles[kind] or profiles.Click or {}
    if type(spec) == "string" then
        return {Id = spec, Volume = 0.18, PlaybackSpeed = 1, Cooldown = 0.035}
    end
    if type(spec) ~= "table" then spec = {} end
    return {
        Id = spec.Id or spec.SoundId or "rbxasset://sounds/button.wav",
        Volume = tonumber(spec.Volume) or 0.18,
        PlaybackSpeed = tonumber(spec.PlaybackSpeed) or 1,
        Cooldown = tonumber(spec.Cooldown) or 0.035,
    }
end

function WindowMethods:_prepareSounds()
    if self._soundsPrepared then return end
    self._soundsPrepared = true
    self._soundObjects = self._soundObjects or {}
    self._lastSoundAt = self._lastSoundAt or {}

    local soundGroup = Instance.new("SoundGroup")
    soundGroup.Name = "NovaField_SoundGroup_" .. tostring(math.random(1000, 9999))
    soundGroup.Volume = self.SoundVolume or 0.55
    soundGroup.Parent = SoundService
    self._soundGroup = soundGroup

    local settings = type(self.SoundSettings) == "table" and self.SoundSettings or {}
    local profiles = type(settings.Profiles) == "table" and settings.Profiles or settings
    for kind, rawSpec in pairs(profiles or {}) do
        if type(rawSpec) == "table" or type(rawSpec) == "string" then
            local spec = self:_soundSpec(kind)
            local sound = Instance.new("Sound")
            sound.Name = "NovaField_" .. tostring(kind)
            sound.SoundId = spec.Id
            sound.Volume = spec.Volume
            sound.PlaybackSpeed = spec.PlaybackSpeed
            sound.SoundGroup = soundGroup
            sound.Parent = SoundService
            self._soundObjects[kind] = sound
        end
    end

    task.spawn(function()
        local assets = {}
        for _, sound in pairs(self._soundObjects) do
            table.insert(assets, sound)
        end
        if #assets > 0 then
            pcall(function() ContentProvider:PreloadAsync(assets) end)
        end
    end)
end

function WindowMethods:_playSound(kind)
    if not self.SoundsEnabled then return false end
    self:_prepareSounds()

    local spec = self:_soundSpec(kind)
    local now = os.clock()
    if now - (self._lastSoundAt[kind] or 0) < spec.Cooldown then return false end
    self._lastSoundAt[kind] = now

    local base = self._soundObjects and (self._soundObjects[kind] or self._soundObjects.Click)
    if not base then
        self._soundsPrepared = false
        self:_prepareSounds()
        base = self._soundObjects and (self._soundObjects[kind] or self._soundObjects.Click)
    end
    if not base then return false end

    local sound = base
    if base.IsPlaying then
        sound = base:Clone()
        sound.Name = base.Name .. "_Overlap"
        sound.Parent = SoundService

        self._transientSounds = self._transientSounds or {}
        table.insert(self._transientSounds, sound)

        Debris:AddItem(sound, math.max(sound.TimeLength + 1, 3))
    else
        pcall(function() sound.TimePosition = 0 end)
    end

    local played = pcall(function()
        SoundService:PlayLocalSound(sound)
    end)
    if not played then
        played = pcall(function() sound:Play() end)
    end
    return played
end

local NotificationTypes = {
    Success = {Role = "Success", Icon = "Check", Sound = "Success"},
    Error = {Role = "Danger", Icon = "X", Sound = "Error"},
    Warning = {Role = "Warning", Icon = "!", Sound = "Warning"},
    Info = {Role = "Information", Icon = "i", Sound = "Info"},
}

local function resolveNotificationType(data)
    local requested = data.Type
    if requested == nil then
        requested = data.Success == true and "Success" or (data.Success == false and "Error" or "Info")
    end
    local aliases = {success="Success", error="Error", failed="Error", failure="Error", danger="Error", warning="Warning", warn="Warning", info="Info", information="Info"}
    local canonical = aliases[tostring(requested):lower()] or "Info"
    return canonical, NotificationTypes[canonical]
end

function Library:Notify(data)
    data = data or {}
    local window = data.Window or self._activeWindow
    if self.NotificationsEnabled == false then
        return false
    end
    if window and not window:GetNotificationsEnabled() then
        return false
    end

    local gui = (window and window.Gui) or self._screenGui
    if not gui then return false end

    local notificationSettings = window and window.NotificationSettings or {}
    local semanticType, semantic = resolveNotificationType(data)
    if window then window:_playSound(data.Sound or semantic.Sound) end

    local holder = gui:FindFirstChild("NovaNotifications")
    if not holder then
        holder = create("Frame", {
            Name = "NovaNotifications",
            Parent = gui,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -14, 1, -14),
            Size = UDim2.fromOffset(286, 360),
            ZIndex = 300,
        })
        create("UIListLayout", {
            Parent = holder,
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 10),
        })
    end

    local upper = notificationSettings.Position == "Top right"
    holder.AnchorPoint = Vector2.new(1, upper and 0 or 1)
    holder.Position = UDim2.new(1, -14, upper and 0 or 1, upper and 14 or -14)
    local camera = workspace.CurrentCamera
    holder.Size = UDim2.new(0, math.min(310, camera and camera.ViewportSize.X - 28 or 310), 1, -28)
    holder:FindFirstChildOfClass("UIListLayout").VerticalAlignment = upper and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
    local card = create("CanvasGroup", {
        Parent = holder,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 0),
        GroupTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 301,
    })
    corner(card, 10)
    applySoftSurfaceGradient(card, window, "Surface3", "Surface2", 100)
    local semanticColor = typeof(data.Color) == "Color3" and data.Color or Theme[semantic.Role]
    local semanticStroke = stroke(card, semanticColor, 1, 0.28)
    if typeof(data.Color) ~= "Color3" then setThemeRole(semanticStroke, "Color", semantic.Role) end
    local cardScale = create("UIScale", {Parent = card, Scale = 0.97})

    local iconText = data.Icon ~= nil and tostring(data.Icon) or (semantic.Icon == "Check" and "" or semantic.Icon)
    local icon = makeText(card, iconText, 14, Theme.Background, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    icon.BackgroundTransparency = 0
    if typeof(data.Color) == "Color3" then icon.BackgroundColor3 = data.Color else setThemeRole(icon, "BackgroundColor3", semantic.Role) end
    icon.Position = UDim2.fromOffset(13, 15)
    icon.Size = UDim2.fromOffset(30, 30)
    icon.ZIndex = 302
    corner(icon, 15)
    if semantic.Icon == "Check" and data.Icon == nil then createCheckmark(icon, Theme.Background, 304) end

    local title = makeText(card, data.Title or "Notification", 14, Theme.Text, Enum.Font.GothamSemibold)
    title.Position = UDim2.fromOffset(54, 10)
    title.Size = UDim2.new(1, -88, 0, 20)
    title.ZIndex = 302

    local body = makeText(card, data.Content or data.Text or "", 11, Theme.Muted, Enum.Font.Gotham)
    body.Position = UDim2.fromOffset(54, 31)
    body.Size = UDim2.new(1, -70, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.None
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.ZIndex = 302

    local close = makeText(card, "X", 13, Theme.Muted, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
    close.Position = UDim2.new(1, -29, 0, 10)
    close.Size = UDim2.fromOffset(22, 22)
    close.ZIndex = 302
    close.Active = true

    local progressTrack = create("Frame", {
        Parent = card,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
        ZIndex = 303,
    })
    local progress = create("Frame", {
        Parent = progressTrack,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = semanticColor,
        BorderSizePixel = 0,
        ZIndex = 304,
    })
    if typeof(data.Color) ~= "Color3" then setThemeRole(progress, "BackgroundColor3", semantic.Role) end

    local dismissing = false
    local function dismiss(immediate)
        if dismissing or not card.Parent then return end
        dismissing = true
        local duration = window and window:_motionDuration(0.24) or 0.24
        if immediate or duration <= 0 then
            card:Destroy()
            return
        end
        if window then
            window:_tween(card, 0.22, {GroupTransparency = 1, Size = UDim2.new(1, 0, 0, 0)})
            window:_tween(cardScale, 0.22, {Scale = 0.97})
        else
            tween(card, 0.22, {GroupTransparency = 1, Size = UDim2.new(1, 0, 0, 0)})
            tween(cardScale, 0.22, {Scale = 0.97})
        end
        task.delay(duration + 0.02, function() if card.Parent then card:Destroy() end end)
    end
    close.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dismiss() end
    end)

    local function layoutNotification()
        local width = holder.Size.X.Offset
        local titleHeight = math.max(20, math.ceil(textSize(title, width - 88).Y) + 2)
        title.TextWrapped = true
        title.Size = UDim2.new(1, -88, 0, titleHeight)
        local bodyY = 10 + titleHeight + 5
        local bodyHeight = math.ceil(textSize(body, width - 70).Y) + 3
        body.Position = UDim2.fromOffset(54, bodyY)
        body.Size = UDim2.new(1, -70, 0, bodyHeight)
        return math.max(72, bodyY + bodyHeight + 16)
    end
    local targetHeight = layoutNotification()
    local restingTransparency = 1 - math.clamp(tonumber(notificationSettings.Opacity) or 100, 25, 100) / 100
    local function resizeNotification()
        if not card.Parent or dismissing then return end
        card.Size = UDim2.new(1, 0, 0, layoutNotification())
    end
    for _, label in ipairs({title, body}) do
        label:GetPropertyChangedSignal("Font"):Connect(resizeNotification)
        label:GetPropertyChangedSignal("Text"):Connect(resizeNotification)
    end
    local resizeConnection = holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeNotification)
    card.Destroying:Connect(function() resizeConnection:Disconnect() end)
    if window then
        window:_tween(card, 0.24, {GroupTransparency = restingTransparency, Size = UDim2.new(1, 0, 0, targetHeight)})
        window:_tween(cardScale, 0.30, {Scale = 1})
    else
        tween(card, 0.24, {GroupTransparency = restingTransparency, Size = UDim2.new(1, 0, 0, targetHeight)})
        tween(cardScale, 0.30, {Scale = 1})
    end
    local lifetime = math.max(tonumber(data.Duration) or tonumber(notificationSettings.Duration) or 4, 0.5)
    local progressTween = TweenService:Create(progress, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 1, 0),
    })
    progressTween:Play()
    task.delay(lifetime, dismiss)
    return true
end

function WindowMethods:Notify(data)
    data = data or {}
    data.Window = self
    return Library:Notify(data)
end

local BroadcastStyles = {
    Owner = {Role = "Accent", Badge = "OWNER", Kicker = "VITALITY BROADCAST", Sound = "Info", DefaultPriority = "normal"},
    Info = {Role = "Information", Badge = "INFO", Kicker = "VITALITY", Sound = "Info", DefaultPriority = "low"},
    Success = {Role = "Success", Badge = "SUCCESS", Kicker = "VITALITY", Sound = "Success", DefaultPriority = "normal"},
    Warning = {Role = "Warning", Badge = "WARNING", Kicker = "VITALITY", Sound = "Warning", DefaultPriority = "high"},
    Error = {Role = "Danger", Badge = "ALERT", Kicker = "VITALITY", Sound = "Error", DefaultPriority = "critical"},
    ModuleAdded = {Role = "Success", Badge = "NEW MODULE", Kicker = "VITALITY LIVE", Sound = "Success", DefaultPriority = "normal"},
    ModuleUpdate = {Role = "Accent", Badge = "UPDATE", Kicker = "VITALITY LIVE", Sound = "Info", DefaultPriority = "high"},
    ModuleRemoved = {Role = "Danger", Badge = "REMOVED", Kicker = "VITALITY LIVE", Sound = "Error", DefaultPriority = "critical"},
}

local BroadcastPriorityWeight = {
    low = 1,
    normal = 2,
    high = 3,
    critical = 4,
}

local function resolveBroadcastStyle(data)
    local requested = tostring(data.Type or data.Style or "Owner")
    local aliases = {
        owner = "Owner",
        broadcast = "Owner",
        info = "Info",
        information = "Info",
        success = "Success",
        warning = "Warning",
        warn = "Warning",
        error = "Error",
        danger = "Error",
        module = "ModuleUpdate",
        moduleadded = "ModuleAdded",
        ["module.added"] = "ModuleAdded",
        moduleupdate = "ModuleUpdate",
        moduleupdated = "ModuleUpdate",
        ["module.updated"] = "ModuleUpdate",
        moduleremoved = "ModuleRemoved",
        ["module.removed"] = "ModuleRemoved",
    }
    local canonical = BroadcastStyles[requested] and requested or aliases[requested:lower()] or "Owner"
    return canonical, BroadcastStyles[canonical]
end

local function normalizeBroadcastPriority(value, fallback)
    local key = tostring(value or fallback or "normal"):lower()
    if BroadcastPriorityWeight[key] == nil then key = "normal" end
    return key, BroadcastPriorityWeight[key]
end

local function shallowCopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

function Library:_broadcastRememberId(id)
    if id == nil or tostring(id) == "" then return true end
    id = tostring(id)
    self._broadcastSeenIds = self._broadcastSeenIds or {}
    self._broadcastSeenOrder = self._broadcastSeenOrder or {}
    if self._broadcastSeenIds[id] then return false end
    self._broadcastSeenIds[id] = true
    table.insert(self._broadcastSeenOrder, id)
    while #self._broadcastSeenOrder > 128 do
        local expired = table.remove(self._broadcastSeenOrder, 1)
        self._broadcastSeenIds[expired] = nil
    end
    return true
end

function Library:_broadcastPushHistory(data)
    self._broadcastHistory = self._broadcastHistory or {}
    local entry = {
        Id = data.Id,
        Type = data.Type or data.Style,
        Title = data.Title,
        Message = data.Message or data.Content or data.Text,
        Module = data.Module,
        Version = data.Version,
        Status = data.Status,
        Priority = data.Priority,
        Timestamp = os.time(),
    }
    table.insert(self._broadcastHistory, 1, entry)
    while #self._broadcastHistory > 20 do table.remove(self._broadcastHistory) end
end

function Library:GetBroadcastHistory()
    local out = {}
    for index, item in ipairs(self._broadcastHistory or {}) do
        out[index] = shallowCopyTable(item)
    end
    return out
end

function Library:_sortBroadcastQueue()
    self._broadcastQueue = self._broadcastQueue or {}
    table.sort(self._broadcastQueue, function(a, b)
        local aw = tonumber(a._PriorityWeight) or 2
        local bw = tonumber(b._PriorityWeight) or 2
        if aw ~= bw then return aw > bw end
        return (tonumber(a._Sequence) or 0) < (tonumber(b._Sequence) or 0)
    end)
end

function Library:_refreshBroadcastQueueCount()
    local active = self._activeBroadcast
    if active and active.UpdateQueueCount then
        pcall(active.UpdateQueueCount, active, #(self._broadcastQueue or {}))
    end
end

function Library:_ensureBroadcastHolder(window, gui)
    local holder = gui:FindFirstChild("VitalityBroadcastLayer")
    if not holder then
        holder = create("Frame", {
            Name = "VitalityBroadcastLayer",
            Parent = gui,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 76),
            Size = UDim2.fromOffset(560, 190),
            ZIndex = 380,
        })
    end

    local camera = workspace.CurrentCamera
    local viewportWidth = camera and camera.ViewportSize.X or 1280
    local targetWidth = math.max(320, math.min(560, viewportWidth - 30))
    holder.Size = UDim2.fromOffset(targetWidth, 190)
    return holder
end

function Library:_renderBroadcast(data)
    local window = data.Window or self._activeWindow
    local gui = (window and window.Gui) or self._screenGui
    if not gui then
        self._activeBroadcast = nil
        task.defer(function() self:_showNextBroadcast() end)
        return false
    end

    local canonical, spec = resolveBroadcastStyle(data)
    local priority, priorityWeight = normalizeBroadcastPriority(data.Priority, spec.DefaultPriority)
    local holder = self:_ensureBroadcastHolder(window, gui)
    local semanticColor = typeof(data.Color) == "Color3" and data.Color or Theme[spec.Role] or Theme.Accent

    local card = create("CanvasGroup", {
        Name = "VitalityBroadcastCard",
        Parent = holder,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 0),
        GroupTransparency = 1,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 381,
    })
    corner(card, 13)
    applySoftSurfaceGradient(card, window, "Surface3", "Surface2", 100)
    local cardStroke = stroke(card, semanticColor, 1, 0.20)
    if typeof(data.Color) ~= "Color3" then setThemeRole(cardStroke, "Color", spec.Role) end
    local scale = create("UIScale", {Parent = card, Scale = 0.985})

    local accent = create("Frame", {
        Parent = card,
        BackgroundColor3 = semanticColor,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, 4, 1, 0),
        ZIndex = 383,
    })
    if typeof(data.Color) ~= "Color3" then setThemeRole(accent, "BackgroundColor3", spec.Role) end

    local kicker = makeText(card, tostring(data.Kicker or spec.Kicker), 10, Theme.Muted, Enum.Font.GothamSemibold)
    kicker.Position = UDim2.fromOffset(18, 13)
    kicker.Size = UDim2.new(1, -170, 0, 16)
    kicker.ZIndex = 383

    local badge = makeText(card, tostring(data.Badge or spec.Badge), 9, semanticColor, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    badge.BackgroundTransparency = 0
    badge.BackgroundColor3 = Theme.Surface3
    badge.Position = UDim2.new(1, -132, 0, 11)
    badge.Size = UDim2.fromOffset(92, 20)
    badge.ZIndex = 383
    corner(badge, 7)
    local badgeStroke = stroke(badge, semanticColor, 1, 0.42)
    if typeof(data.Color) ~= "Color3" then
        setThemeRole(badge, "TextColor3", spec.Role)
        setThemeRole(badgeStroke, "Color", spec.Role)
    end

    local close = makeText(card, "X", 12, Theme.Muted, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
    close.Position = UDim2.new(1, -31, 0, 10)
    close.Size = UDim2.fromOffset(22, 22)
    close.Active = true
    close.ZIndex = 384

    local title = makeText(card, tostring(data.Title or "Vitality Broadcast"), 17, Theme.Text, Enum.Font.GothamSemibold)
    title.Position = UDim2.fromOffset(18, 36)
    title.Size = UDim2.new(1, -52, 0, 23)
    title.TextWrapped = true
    title.ZIndex = 383

    local message = makeText(card, tostring(data.Message or data.Content or data.Text or ""), 12, Theme.Muted, Enum.Font.Gotham)
    message.Position = UDim2.fromOffset(18, 66)
    message.Size = UDim2.new(1, -36, 0, 42)
    message.TextWrapped = true
    message.TextYAlignment = Enum.TextYAlignment.Top
    message.ZIndex = 383

    local detailParts = {}
    if data.Status and tostring(data.Status) ~= "" then table.insert(detailParts, tostring(data.Status)) end
    if data.Version and tostring(data.Version) ~= "" then table.insert(detailParts, tostring(data.Version)) end
    if data.Footer and tostring(data.Footer) ~= "" then table.insert(detailParts, tostring(data.Footer)) end
    local detailText = table.concat(detailParts, "  â€¢  ")
    local details = makeText(card, detailText, 10, Theme.Muted, Enum.Font.GothamMedium)
    details.Position = UDim2.fromOffset(18, 114)
    details.Size = UDim2.new(1, -112, 0, 17)
    details.ZIndex = 383
    details.Visible = detailText ~= ""

    local timerText = makeText(card, "", 10, semanticColor, Enum.Font.GothamSemibold, Enum.TextXAlignment.Right)
    timerText.Position = UDim2.new(1, -88, 0, 114)
    timerText.Size = UDim2.fromOffset(70, 17)
    timerText.ZIndex = 383
    if typeof(data.Color) ~= "Color3" then setThemeRole(timerText, "TextColor3", spec.Role) end

    local queueText = makeText(card, "", 9, Theme.Muted, Enum.Font.Gotham)
    queueText.Position = UDim2.fromOffset(18, 134)
    queueText.Size = UDim2.new(1, -36, 0, 14)
    queueText.ZIndex = 383
    queueText.Visible = false

    local progressTrack = create("Frame", {
        Parent = card,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
        ZIndex = 384,
    })
    local progress = create("Frame", {
        Parent = progressTrack,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = semanticColor,
        BorderSizePixel = 0,
        ZIndex = 385,
    })
    if typeof(data.Color) ~= "Color3" then setThemeRole(progress, "BackgroundColor3", spec.Role) end

    local width = holder.Size.X.Offset
    local titleHeight = math.max(23, math.ceil(textSize(title, width - 52).Y) + 2)
    title.Size = UDim2.new(1, -52, 0, titleHeight)
    local messageY = 36 + titleHeight + 7
    local messageHeight = math.max(34, math.ceil(textSize(message, width - 36).Y) + 4)
    message.Position = UDim2.fromOffset(18, messageY)
    message.Size = UDim2.new(1, -36, 0, messageHeight)
    local detailY = messageY + messageHeight + 8
    details.Position = UDim2.fromOffset(18, detailY)
    timerText.Position = UDim2.new(1, -88, 0, detailY)
    local queueY = detailY + 19
    queueText.Position = UDim2.fromOffset(18, queueY)
    local targetHeight = math.max(128, queueY + 23)
    holder.Size = UDim2.fromOffset(holder.Size.X.Offset, math.max(190, targetHeight))

    local lifetime = math.clamp(tonumber(data._RemainingDuration or data.Duration) or 10, 3, 30)
    local remaining = lifetime
    local hovered = false
    local dismissing = false
    local controller = {
        Data = data,
        Priority = priority,
        PriorityWeight = priorityWeight,
        Remaining = remaining,
    }
    self._activeBroadcast = controller

    function controller:UpdateQueueCount(count)
        if not queueText.Parent then return end
        count = tonumber(count) or 0
        queueText.Visible = count > 0
        queueText.Text = count > 0 and (tostring(count) .. (count == 1 and " more broadcast queued" or " more broadcasts queued")) or ""
    end

    local function releaseController()
        if Library._activeBroadcast == controller then
            Library._activeBroadcast = nil
            task.defer(function() Library:_showNextBroadcast() end)
        end
    end

    card.Destroying:Connect(releaseController)

    local function destroyCard()
        if card.Parent then
            card:Destroy()
        else
            releaseController()
        end
    end

    local function dismiss(immediate, requeue)
        if dismissing then return end
        dismissing = true
        controller.Remaining = math.max(0, remaining)
        if requeue and controller.Remaining > 0.75 then
            local queued = shallowCopyTable(data)
            queued._RemainingDuration = controller.Remaining
            queued._Sequence = nil
            Library._broadcastSequence = (Library._broadcastSequence or 0) + 1
            queued._Sequence = Library._broadcastSequence
            queued._PriorityWeight = priorityWeight
            table.insert(Library._broadcastQueue, queued)
            Library:_sortBroadcastQueue()
        end

        local duration = window and window:_motionDuration(0.20) or 0.20
        if immediate or duration <= 0 then
            destroyCard()
            return
        end
        if window then
            window:_tween(card, 0.18, {GroupTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, -6)})
            window:_tween(scale, 0.18, {Scale = 0.985})
        else
            tween(card, 0.18, {GroupTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, -6)})
            tween(scale, 0.18, {Scale = 0.985})
        end
        task.delay(duration + 0.03, destroyCard)
    end

    function controller:Interrupt()
        dismiss(false, true)
    end

    close.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dismiss(false, false)
        end
    end)
    card.MouseEnter:Connect(function() hovered = true end)
    card.MouseLeave:Connect(function() hovered = false end)

    if window then window:_playSound(data.Sound or spec.Sound) end
    local restingTransparency = math.clamp(tonumber(data.Transparency) or 0, 0, 0.65)
    if window then
        window:_tween(card, 0.24, {GroupTransparency = restingTransparency, Size = UDim2.new(1, 0, 0, targetHeight)})
        window:_tween(scale, 0.28, {Scale = 1})
    else
        tween(card, 0.24, {GroupTransparency = restingTransparency, Size = UDim2.new(1, 0, 0, targetHeight)})
        tween(scale, 0.28, {Scale = 1})
    end

    controller:UpdateQueueCount(#(self._broadcastQueue or {}))
    task.spawn(function()
        local lastSecond = -1
        while card.Parent and not dismissing and remaining > 0 do
            local dt = RunService.Heartbeat:Wait()
            if not hovered then
                remaining = math.max(0, remaining - dt)
                controller.Remaining = remaining
            end
            progress.Size = UDim2.new(math.clamp(remaining / lifetime, 0, 1), 0, 1, 0)
            local second = math.max(0, math.ceil(remaining))
            if second ~= lastSecond then
                lastSecond = second
                timerText.Text = hovered and (tostring(second) .. "s  PAUSED") or (tostring(second) .. "s")
            elseif hovered and not timerText.Text:find("PAUSED", 1, true) then
                timerText.Text = tostring(second) .. "s  PAUSED"
            elseif not hovered and timerText.Text:find("PAUSED", 1, true) then
                timerText.Text = tostring(second) .. "s"
            end
        end
        if card.Parent and not dismissing then dismiss(false, false) end
    end)

    return true
end

function Library:_showNextBroadcast()
    if self._activeBroadcast then
        self:_refreshBroadcastQueueCount()
        return false
    end
    self._broadcastQueue = self._broadcastQueue or {}
    if #self._broadcastQueue == 0 then return false end
    self:_sortBroadcastQueue()
    local data = table.remove(self._broadcastQueue, 1)
    self:_refreshBroadcastQueueCount()
    return self:_renderBroadcast(data)
end

function Library:Broadcast(data)
    data = shallowCopyTable(data or {})
    if self.BroadcastsEnabled == false then return false end
    if not self:_broadcastRememberId(data.Id) then return false end

    local _, spec = resolveBroadcastStyle(data)
    local priority, priorityWeight = normalizeBroadcastPriority(data.Priority, spec.DefaultPriority)
    data.Priority = priority
    data.Duration = math.clamp(tonumber(data.Duration) or 10, 3, 30)
    self._broadcastSequence = (self._broadcastSequence or 0) + 1
    data._Sequence = self._broadcastSequence
    data._PriorityWeight = priorityWeight
    data.Window = data.Window or self._activeWindow

    self:_broadcastPushHistory(data)
    self._broadcastQueue = self._broadcastQueue or {}
    table.insert(self._broadcastQueue, data)
    self:_sortBroadcastQueue()

    local active = self._activeBroadcast
    if active and priorityWeight > (tonumber(active.PriorityWeight) or 0) and active.Interrupt then
        active:Interrupt()
    else
        self:_showNextBroadcast()
    end
    self:_refreshBroadcastQueueCount()
    return true
end

function WindowMethods:Broadcast(data)
    data = data or {}
    data.Window = self
    return Library:Broadcast(data)
end

function WindowMethods:GetBroadcastHistory()
    return Library:GetBroadcastHistory()
end

function WindowMethods:_configPath()
    local config = self.Settings.ConfigurationSaving or {}
    local folder = config.FolderName or "NovaField"
    local fileName = config.FileName or self.Settings.Name or "Config"
    fileName = tostring(fileName):gsub("[^%w%-%_]", "_")
    return folder, folder .. "/" .. fileName .. ".json"
end

-- One stable file for interface appearance, independent of module config names.
function WindowMethods:_sharedAppearancePath()
    return "VitalityHub", "VitalityHub/SharedAppearanceV1.json"
end

function WindowMethods:_readSharedAppearance()
    if type(readfile) ~= "function" then return nil end
    local _, path = self:_sharedAppearancePath()
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" or raw == "" then return nil end
    local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if not decodedOk or type(decoded) ~= "table" or decoded.Version ~= 1
        or type(decoded.Appearance) ~= "table" then return nil end
    return deserialize(decoded.Appearance)
end

function WindowMethods:_saveSharedAppearance()
    if not self._appearanceReady or type(writefile) ~= "function" then return end
    local appearance = self:_appearanceSnapshot()
    -- Notification preferences remain in the module's existing configuration.
    appearance.NotificationSettings = nil
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, {Version = 1, Appearance = serialize(appearance)})
    if not ok or encoded == self._lastSharedAppearanceWrite then return end
    local folder, path = self:_sharedAppearancePath()
    if type(makefolder) == "function" then pcall(makefolder, folder) end
    local written = pcall(writefile, path, encoded)
    if written then self._lastSharedAppearanceWrite = encoded end
end

function WindowMethods:_appearanceFlagValue(flag, fallback)
    if not self._appearanceReady or not flag then return false end
    local aliases = {
        Theme = "ThemeName", InterfaceFont = "FontPreset",
        AccentColor = "CustomAccent", ButtonColor = "CustomButton",
        BorderStrokeEnabled = "Enabled", BorderFollowsAccent = "UseAccent",
        BorderThickness = "Thickness", BorderTransparency = "Transparency", BorderColor = "Color",
    }
    local role = (self._appearanceFlags or {})[flag] or aliases[flag]
    if not role then return false end
    if type(role) == "table" then
        local first, last = self:GetGradient(role.Kind)
        return true, role.Stop == "end" and last or first
    end
    if role == "CustomAccent" then return true, self.CustomAccent or Theme.Accent end
    if role == "CustomButton" then return true, self.CustomButton or Theme.Button end
    if role == "ThemeName" or role == "FontPreset" then return true, self[role] or fallback end
    local value = (self.BorderStrokeSettings or {})[role]
    if role == "Transparency" and value ~= nil then value = value * 100 end
    if role == "Color" and value == nil then value = Theme.Border end
    if value == nil then value = fallback end
    return true, value
end

function WindowMethods:_loadConfig()
    self.ConfigData = {}
    local config = self.Settings.ConfigurationSaving or {}
    if not config.Enabled then return end
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end

    local _, path = self:_configPath()
    local ok, raw = pcall(function()
        if isfile(path) then return readfile(path) end
    end)
    if ok and raw and raw ~= "" then
        local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        if decodeOk and type(decoded) == "table" then
            self.ConfigData = deserialize(decoded)
        end
    end
end

function WindowMethods:_saveConfig()
    self:_saveSharedAppearance()
    local config = self.Settings.ConfigurationSaving or {}
    if not config.Enabled then return end
    if type(writefile) ~= "function" then return end

    local folder, path = self:_configPath()
    if type(makefolder) == "function" and type(isfolder) == "function" then
        pcall(function()
            if not isfolder(folder) then makefolder(folder) end
        end)
    end

    local data = {}
    for flag, value in pairs(self.ConfigData or {}) do data[flag] = serialize(value) end
    data._VitalityAppearanceV1 = serialize(self:_appearanceSnapshot())
    for flag, item in pairs(self.FlagObjects) do
        if item.Get then data[flag] = serialize(item:Get()) end
    end

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then pcall(writefile, path, encoded) end
end

function WindowMethods:_saved(flag, fallback)
    local shared, value = self:_appearanceFlagValue(flag, fallback)
    if shared then return value end
    if flag and self.ConfigData[flag] ~= nil then
        return self.ConfigData[flag]
    end
    return fallback
end

function WindowMethods:_registerFlag(flag, object)
    if not flag or flag == "" then return end
    object.Flag = flag
    self.FlagObjects[flag] = object
    Library.Flags[flag] = object
end

function WindowMethods:GetFlag(flag)
    local object = self.FlagObjects[flag]
    return object and object.Get and object:Get() or nil
end

function WindowMethods:SetFlag(flag, value, fireCallback)
    local object = self.FlagObjects[flag]
    if not object or not object.Set then return false end
    object:Set(value, fireCallback ~= false)
    return true
end

function WindowMethods:SaveConfiguration()
    self:_saveConfig()
    return true
end

function WindowMethods:LoadConfiguration(fireCallbacks)
    self:_loadConfig()
    self:_restoreAppearance()
    self:SetTheme(self.ThemeName)
    self:SetFontPreset(self.FontPreset)
    for flag, value in pairs(self.ConfigData or {}) do
        local object = self.FlagObjects[flag]
        if object and object.Set then object:Set(self:_saved(flag, value), fireCallbacks == true) end
    end
    return true
end

function WindowMethods:_refreshTabStyles()
    if self.PersonalizationButton then
        self.PersonalizationButton.Visible = true
    end

    for _, other in ipairs(self.Tabs) do
        local selected = not self._quickMode and other == self.ActiveTab
        if other.PageClip then
            other.PageClip.Visible = selected
            other.Page.Visible = true
        else
            other.Page.Visible = selected
        end
        other.NavButton.BackgroundTransparency = selected and 0 or 1
        if selected then
            -- Active tab gradients must render on the white multiplication base
            -- established by applyThemeGradient(). Do not recolor that base.
            if other.RefreshNavGradient then
                other.RefreshNavGradient()
            end
        else
            setThemeRole(other.NavButton, "BackgroundColor3", "Surface3")
        end
        if other.NavGradient then other.NavGradient.Enabled = selected end
        setThemeRole(other.NavTitle, "TextColor3", selected and "Text" or "Muted")
        setIconColor(other.NavIcon, selected and Theme.Text or Theme.Muted)
        if other.NavStroke then
            other.NavStroke.Enabled = selected
            setThemeRole(other.NavStroke, "Color", "AccentVisible")
        end
        if other.NavIndicator then
            other.NavIndicator.Visible = selected
            setThemeRole(other.NavIndicator, "BackgroundColor3", "AccentVisible")
        end
    end

    if self._refreshTabDropdownStyles then
        self:_refreshTabDropdownStyles()
    end
end

function WindowMethods:_setActiveTab(tab)
    self:_closeQuickPage()
    if self.ActiveTab == tab then
        self:_refreshTabStyles()
        return
    end
    Library:_closePopup()
    self.ActiveTab = tab
    for _, other in ipairs(self.Tabs) do
        local selected = other == tab
        if other.PageClip then
            other.PageClip.Visible = selected
            other.Page.Visible = true
        else
            other.Page.Visible = selected
        end
        -- Transparency is the only animated property here. Tweening the base
        -- BackgroundColor3 darkens UIGradient on the first click.
        self:_tween(other.NavButton, 0.16, {
            BackgroundTransparency = selected and 0 or 1,
        })
        if selected then
            if other.RefreshNavGradient then
                other.RefreshNavGradient()
            end
        else
            setThemeRole(other.NavButton, "BackgroundColor3", "Surface3")
        end
        if other.NavGradient then other.NavGradient.Enabled = selected end
        setThemeRole(other.NavTitle, "TextColor3", selected and "Text" or "Muted")
        setIconColor(other.NavIcon, selected and Theme.Text or Theme.Muted)
        if other.NavStroke then
            other.NavStroke.Enabled = selected
            setThemeRole(other.NavStroke, "Color", "AccentVisible")
        end
        if other.NavIndicator then
            other.NavIndicator.Visible = selected
            setThemeRole(other.NavIndicator, "BackgroundColor3", "AccentVisible")
        end
        if selected and other.ColumnsHolder then
            -- Never animate the page itself. The content uses regular Frames so
            -- Roblox cannot composite a CanvasGroup beyond the scroll viewport.
            other.Page.Position = UDim2.fromOffset(0, 0)
            other.ColumnsHolder.Position = UDim2.fromOffset(8, 0)
            self:_tween(other.ColumnsHolder, 0.20, {
                Position = UDim2.fromOffset(0, 0),
            })
        end
    end

    if self._refreshTabDropdownStyles then
        self:_refreshTabDropdownStyles()
    end
end

local function replaceThemeColor(object, property, oldTheme, newTheme)
    local ok, current = pcall(function() return object[property] end)
    if not ok or typeof(current) ~= "Color3" then return end

    -- Explicit roles are authoritative. Stateful controls update their role
    -- whenever their visual state changes, so repainting never depends on a
    -- second click or on two palette roles having different RGB values.
    local role = object:GetAttribute("NovaThemeRole_" .. property)
    if role and typeof(newTheme[role]) == "Color3" then
        pcall(function() object[property] = newTheme[role] end)
        return
    end

    -- Untagged colors are deliberate custom colors (for example a swatch,
    -- preview, or custom border). Never reinterpret them because they happen
    -- to equal a theme color.
end

function WindowMethods:_registerThemeRenderer(renderer)
    if type(renderer) ~= "function" then return end
    self._themeRenderers = self._themeRenderers or {}
    table.insert(self._themeRenderers, renderer)
end

function WindowMethods:_applyThemePalette(newPalette, themeName)
    local oldTheme = cloneTheme(Theme)
    for key, value in pairs(newPalette) do
        Theme[key] = value
    end

    if self.Gui then
        for _, object in ipairs(self.Gui:GetDescendants()) do
            if object:IsA("GuiObject") then
                replaceThemeColor(object, "BackgroundColor3", oldTheme, Theme)
            end
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                replaceThemeColor(object, "TextColor3", oldTheme, Theme)
                if object:IsA("TextBox") then
                    replaceThemeColor(object, "PlaceholderColor3", oldTheme, Theme)
                end
            end
            if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                replaceThemeColor(object, "ImageColor3", oldTheme, Theme)
            end
            if object:IsA("UIStroke") then
                replaceThemeColor(object, "Color", oldTheme, Theme)
            end
            if object:IsA("ScrollingFrame") then
                replaceThemeColor(object, "ScrollBarImageColor3", oldTheme, Theme)
            end


        end
    end

    self.ThemeName = themeName or self.ThemeName or "Dark"
    for _, renderer in ipairs(self._themeRenderers or {}) do
        local ok, err = pcall(renderer)
        if not ok then warn("[NovaField] Theme repaint error: " .. tostring(err)) end
    end
    self:_refreshWindowBorder()
    self:_refreshTabStyles()
end

function WindowMethods:SetTheme(themeName)
    local requested = tostring(themeName or "Dark")
    local normalized = requested:lower()
    local key
    if normalized == "light" then
        key = "Light"
    elseif normalized == "system" then
        -- Roblox does not expose a reliable OS light/dark preference to experiences.
        -- Keep "System" as a valid state and currently render it using the dark preset.
        key = "Dark"
    else
        key = "Dark"
        requested = "Dark"
    end

    local palette = cloneTheme(Library.Themes[key])
    -- A user-selected accent is independent from the theme's default accent.
    -- If no custom accent has been chosen, each theme may use its own tuned accent.
    if typeof(self.CustomAccent) == "Color3" then
        applyAccentPalette(palette, self.CustomAccent)
    else
        applyAccentPalette(palette, palette.Accent)
    end
    if typeof(self.CustomButton) == "Color3" then
        applyButtonPalette(palette, self.CustomButton)
    else
        applyButtonPalette(palette, palette.Button)
    end
    self:_applyThemePalette(palette, normalized == "system" and "System" or key)
    if self._accentPicker and not self.CustomAccent and self._accentPicker._Sync then
        self._accentPicker:_Sync(Theme.Accent)
    end
    if self._buttonPicker and not self.CustomButton and self._buttonPicker._Sync then
        self._buttonPicker:_Sync(Theme.Button)
    end
    self:_saveConfig()
    return self.ThemeName
end

function WindowMethods:GetTheme()
    return self.ThemeName or "Dark"
end

function WindowMethods:SetThemeAccent(color)
    if typeof(color) ~= "Color3" then return end
    self.CustomAccent = color
    self.AccentGradientStart = color
    local palette = cloneTheme(Theme)
    applyAccentPalette(palette, color)
    self:_applyThemePalette(palette, self.ThemeName or "Dark")
    if self._accentPicker and self._accentPicker._Sync then
        self._accentPicker:_Sync(color)
    end
    self:_saveConfig()
end

function WindowMethods:ResetThemeAccent()
    self.CustomAccent = nil
    self.AccentGradientStart = nil
    return self:SetTheme(self.ThemeName or "Dark")
end

function WindowMethods:SetButtonColor(color)
    if typeof(color) ~= "Color3" then return end
    self.CustomButton = color
    local palette = cloneTheme(Theme)
    applyButtonPalette(palette, color)
    self:_applyThemePalette(palette, self.ThemeName or "Dark")
    if self._buttonPicker and self._buttonPicker._Sync then
        self._buttonPicker:_Sync(color)
    end
    self:_saveConfig()
end

function WindowMethods:ResetButtonColor()
    self.CustomButton = nil
    return self:SetTheme(self.ThemeName or "Dark")
end

local GRADIENT_NAMES = {accent = "Accent", button = "Button", tab = "Tab", activetab = "Tab", icon = "Icon", surface = "Surface", card = "Surface"}

function WindowMethods:GetGradientOptions(kind)
    local prefix = GRADIENT_NAMES[tostring(kind or "accent"):lower()] or "Accent"
    local options = (self.GradientOptions or {})[prefix] or {}
    if options.FollowAccent and prefix ~= "Accent" and prefix ~= "Surface" then
        local accent = (self.GradientOptions or {}).Accent or {}
        return {Enabled = options.Enabled ~= false and accent.Enabled ~= false, Rotation = tonumber(accent.Rotation) or 0, FollowAccent = true}
    end
    return {
        Enabled = options.Enabled ~= false,
        Rotation = tonumber(options.Rotation) or (prefix == "Surface" and 100 or 0),
        FollowAccent = options.FollowAccent == true,
    }
end

function WindowMethods:GetGradient(kind)
    local prefix = GRADIENT_NAMES[tostring(kind or "accent"):lower()]
    if not prefix then return nil end
    local options = self:GetGradientOptions(kind)
    if options.FollowAccent and prefix ~= "Accent" and prefix ~= "Surface" then
        return self:GetGradient("accent")
    end
    local defaults = {
        Accent = {Theme.Accent, Theme.AccentDark}, Button = {Theme.Button, Theme.ButtonHover},
        Tab = {Theme.Accent, Theme.AccentDark}, Icon = {Theme.Accent, Theme.AccentDark},
        Surface = {Theme.Surface3, Theme.Surface2},
    }
    return self[prefix .. "GradientStart"] or defaults[prefix][1], self[prefix .. "GradientEnd"] or defaults[prefix][2]
end

function WindowMethods:SetGradient(kind, startColor, endColor, rotation)
    local prefix = GRADIENT_NAMES[tostring(kind or ""):lower()]
    if not prefix or typeof(startColor) ~= "Color3" or typeof(endColor) ~= "Color3" then return false end
    self[prefix .. "GradientStart"], self[prefix .. "GradientEnd"] = startColor, endColor
    if rotation ~= nil then
        self.GradientOptions[prefix] = self.GradientOptions[prefix] or {}
        self.GradientOptions[prefix].Rotation = (tonumber(rotation) or 0) % 360
    end
    if prefix == "Accent" then self.CustomAccent = startColor end
    self:SetTheme(self.ThemeName)
    self:_saveConfig()
    return true
end

function WindowMethods:SetGradientOptions(kind, options)
    local prefix = GRADIENT_NAMES[tostring(kind or ""):lower()]
    if not prefix or type(options) ~= "table" then return false end
    self.GradientOptions = self.GradientOptions or {}
    local current = self.GradientOptions[prefix] or {}
    if options.Enabled ~= nil then current.Enabled = options.Enabled == true end
    if options.Rotation ~= nil then current.Rotation = (tonumber(options.Rotation) or 0) % 360 end
    if options.FollowAccent ~= nil then current.FollowAccent = options.FollowAccent == true end
    self.GradientOptions[prefix] = current
    self:_applyThemePalette(cloneTheme(Theme), self.ThemeName)
    self:_saveConfig()
    return true
end

function WindowMethods:ResetGradients()
    for _, prefix in ipairs({"Accent", "Button", "Tab", "Icon", "Surface"}) do
        self[prefix .. "GradientStart"], self[prefix .. "GradientEnd"] = nil, nil
    end
    self.GradientOptions = {Tab = {FollowAccent = true}, Icon = {FollowAccent = true}}
    self:SetTheme(self.ThemeName)
    self:_saveConfig()
end

function WindowMethods:_appearanceSnapshot()
    local result = {}
    for _, key in ipairs({"ThemeName", "FontPreset", "CustomAccent", "CustomButton", "GradientOptions", "BorderStrokeSettings", "NotificationSettings", "BackgroundSettings"}) do
        result[key] = self[key]
    end
    for _, prefix in ipairs({"Accent", "Button", "Tab", "Icon", "Surface"}) do
        result[prefix .. "GradientStart"], result[prefix .. "GradientEnd"] = self[prefix .. "GradientStart"], self[prefix .. "GradientEnd"]
    end
    return result
end

function WindowMethods:_restoreAppearance()
    local legacy = self.ConfigData and self.ConfigData._VitalityAppearanceV1
    local shared = self:_readSharedAppearance()
    local saved = shared or legacy
    if type(saved) ~= "table" then saved = {} end
    -- Absence of an override is meaningful: reset-to-default must persist too.
    if shared then
        self.CustomAccent, self.CustomButton = nil, nil
        for _, prefix in ipairs({"Accent", "Button", "Tab", "Icon", "Surface"}) do
            self[prefix .. "GradientStart"], self[prefix .. "GradientEnd"] = nil, nil
        end
        if type(legacy) == "table" and type(legacy.NotificationSettings) == "table" then
            self.NotificationSettings = legacy.NotificationSettings
        end
    end
    for _, key in ipairs({"ThemeName", "FontPreset"}) do
        if type(saved[key]) == "string" then self[key] = saved[key] end
    end
    for _, key in ipairs({"CustomAccent", "CustomButton"}) do
        if typeof(saved[key]) == "Color3" then self[key] = saved[key] end
    end
    for _, key in ipairs({"GradientOptions", "BorderStrokeSettings", "NotificationSettings", "BackgroundSettings"}) do
        if type(saved[key]) == "table" then self[key] = saved[key] end
    end
    for _, prefix in ipairs({"Accent", "Button", "Tab", "Icon", "Surface"}) do
        for _, stop in ipairs({"Start", "End"}) do
            local key = prefix .. "Gradient" .. stop
            if typeof(saved[key]) == "Color3" then self[key] = saved[key] end
        end
    end
    self._appearanceReady = true
    self._lastSharedAppearanceWrite = nil
    -- First launch migrates the current module's existing appearance.
    self:_saveSharedAppearance()
end

-- The artwork stays inside the content viewport, underneath all tab pages.
function WindowMethods:_refreshBackground()
    local image = self.BackgroundImage
    if not image or not image.Parent then return end
    local options = self.BackgroundSettings or {}
    image.Visible = options.Enabled ~= false
    image.ImageTransparency = 1 - math.clamp(tonumber(options.Opacity) or 55, 0, 100) / 100
    image.ImageColor3 = options.FollowAccent == true and Theme.Accent or Color3.new(1, 1, 1)
end

function WindowMethods:SetBackgroundOptions(options)
    options = type(options) == "table" and options or {}
    self.BackgroundSettings = self.BackgroundSettings or {Enabled = true, Opacity = 55, FollowAccent = false}
    local current = self.BackgroundSettings
    if options.Enabled ~= nil then current.Enabled = options.Enabled ~= false end
    if options.Opacity ~= nil then current.Opacity = math.clamp(tonumber(options.Opacity) or 55, 0, 100) end
    if options.FollowAccent ~= nil then current.FollowAccent = options.FollowAccent == true end
    self:_refreshBackground()
    self:_saveConfig()
end

function WindowMethods:_buildBackgroundSettings(tab)
    if tab._VitalityBackgroundBuilt then return end
    tab._VitalityBackgroundBuilt = true
    local options = self.BackgroundSettings
    local section = tab:CreateSection({Name = "Background", Side = "Right"})
    section:CreateToggle({Name = "Show background", CurrentValue = options.Enabled ~= false,
        Callback = function(value) self:SetBackgroundOptions({Enabled = value}) end})
    section:CreateSlider({Name = "Background opacity", Range = {0, 100}, Increment = 1, Suffix = "%",
        CurrentValue = options.Opacity or 55,
        Callback = function(value) self:SetBackgroundOptions({Opacity = value}) end})
    section:CreateToggle({Name = "Tint with accent", CurrentValue = options.FollowAccent == true,
        Callback = function(value) self:SetBackgroundOptions({FollowAccent = value}) end})
end

function WindowMethods:_refreshWindowBorder()
    local settings = self.BorderStrokeSettings
    local border = self.WindowStroke
    if not settings or not border then return end
    border.Enabled = settings.Enabled ~= false
    border.Thickness = math.clamp(tonumber(settings.Thickness) or 1, 0.5, 6)
    border.Transparency = math.clamp(tonumber(settings.Transparency) or 0.08, 0, 1)
    if settings.UseAccent ~= false then
        setThemeRole(border, "Color", "AccentVisible")
    elseif settings.UseThemeBorder == true then
        setThemeRole(border, "Color", "Border")
    else
        setThemeRole(border, "Color", nil)
        if typeof(settings.Color) == "Color3" then
            border.Color = settings.Color
        else
            setThemeRole(border, "Color", "Border")
        end
    end
end

function WindowMethods:SetBorderStrokeEnabled(enabled)
    self.BorderStrokeSettings.Enabled = enabled ~= false
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
    return self.BorderStrokeSettings.Enabled
end

function WindowMethods:GetBorderStrokeEnabled()
    return self.BorderStrokeSettings.Enabled ~= false
end

function WindowMethods:SetBorderStrokeUseAccent(enabled)
    self.BorderStrokeSettings.UseAccent = enabled ~= false
    if enabled ~= false then self.BorderStrokeSettings.UseThemeBorder = false end
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
    return self.BorderStrokeSettings.UseAccent
end

function WindowMethods:SetBorderStrokeUseTheme(enabled)
    self.BorderStrokeSettings.UseThemeBorder = enabled == true
    if enabled == true then self.BorderStrokeSettings.UseAccent = false end
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
    return self.BorderStrokeSettings.UseThemeBorder
end

function WindowMethods:SetBorderStrokeColor(color)
    if typeof(color) ~= "Color3" then return end
    self.BorderStrokeSettings.Color = color
    self.BorderStrokeSettings.UseAccent = false
    self.BorderStrokeSettings.UseThemeBorder = false
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
end

function WindowMethods:SetBorderStrokeThickness(value)
    self.BorderStrokeSettings.Thickness = math.clamp(tonumber(value) or 1, 0.5, 6)
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
    return self.BorderStrokeSettings.Thickness
end

function WindowMethods:SetBorderStrokeTransparency(value)
    self.BorderStrokeSettings.Transparency = math.clamp(tonumber(value) or 0, 0, 1)
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
    return self.BorderStrokeSettings.Transparency
end

function WindowMethods:SetBorderStroke(options)
    options = type(options) == "table" and options or {}
    if options.Enabled ~= nil then self.BorderStrokeSettings.Enabled = options.Enabled ~= false end
    if options.UseAccent ~= nil then self.BorderStrokeSettings.UseAccent = options.UseAccent ~= false end
    if options.UseThemeBorder ~= nil then self.BorderStrokeSettings.UseThemeBorder = options.UseThemeBorder == true end
    if typeof(options.Color) == "Color3" then
        self.BorderStrokeSettings.Color = options.Color
        if options.UseAccent == nil and options.UseThemeBorder == nil then
            self.BorderStrokeSettings.UseAccent = false
            self.BorderStrokeSettings.UseThemeBorder = false
        end
    end
    if options.Thickness ~= nil then self.BorderStrokeSettings.Thickness = math.clamp(tonumber(options.Thickness) or 1, 0.5, 6) end
    if options.Transparency ~= nil then self.BorderStrokeSettings.Transparency = math.clamp(tonumber(options.Transparency) or 0, 0, 1) end
    if self.BorderStrokeSettings.UseAccent then self.BorderStrokeSettings.UseThemeBorder = false end
    self:_refreshWindowBorder()
    self:_saveSharedAppearance()
end

function WindowMethods:GetBorderStroke()
    local copy = {}
    for key, value in pairs(self.BorderStrokeSettings or {}) do copy[key] = value end
    return copy
end

local SCRIPT_STATUS_STATES = {
    functional = {
        State = "functional",
        Level = "green",
        Role = "Success",
        Label = "Fully Working",
        Color = Color3.fromRGB(66, 232, 138),
        GlowColor = Color3.fromRGB(53, 245, 139),
    },
    testing = {
        State = "testing",
        Level = "yellow",
        Role = "Information",
        Label = "In Testing",
        Color = Color3.fromRGB(255, 216, 74),
        GlowColor = Color3.fromRGB(255, 228, 107),
    },
    limited = {
        State = "limited",
        Level = "yellow",
        Role = "Warning",
        Label = "Limited Functionality",
        Color = Color3.fromRGB(255, 150, 61),
        GlowColor = Color3.fromRGB(255, 170, 85),
    },
    broken = {
        State = "broken",
        Level = "red",
        Role = "Danger",
        Label = "Not Working",
        Color = Color3.fromRGB(255, 77, 94),
        GlowColor = Color3.fromRGB(255, 64, 85),
    },
    maintenance = {
        State = "maintenance",
        Level = "yellow",
        Role = "Text",
        Label = "Maintenance",
        Color = Color3.fromRGB(241, 245, 249),
        GlowColor = Color3.fromRGB(255, 255, 255),
    },
    updating = {
        State = "updating",
        Level = "yellow",
        Role = "Information",
        Label = "Updating",
        Color = Color3.fromRGB(53, 217, 255),
        GlowColor = Color3.fromRGB(68, 229, 255),
    },
}

local SCRIPT_STATUS_ALIASES = {
    green = "functional",
    working = "functional",
    ready = "functional",
    success = "functional",
    yellow = "testing",
    test = "testing",
    orange = "limited",
    partial = "limited",
    degraded = "limited",
    red = "broken",
    error = "broken",
    offline = "broken",
    white = "maintenance",
    blue = "updating",
    cyan = "updating",
    update = "updating",
    loading = "updating",
}

local function cloneValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[cloneValue(key, seen)] = cloneValue(child, seen)
    end
    return copy
end

local function colorFromHex(value, fallback)
    if typeof(value) == "Color3" then return value end
    local hex = tostring(value or ""):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2)
            .. hex:sub(2, 2):rep(2)
            .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 or not hex:match("^[%da-fA-F]+$") then return fallback end
    return Color3.fromRGB(
        tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16),
        tonumber(hex:sub(5, 6), 16)
    )
end

local function canonicalStatusKey(value)
    local key = tostring(value or "testing"):lower()
    key = key:gsub("^%s+", ""):gsub("%s+$", "")
    return SCRIPT_STATUS_STATES[key] and key or SCRIPT_STATUS_ALIASES[key] or "testing"
end

function WindowMethods:_resolveStatusState(value)
    local key = canonicalStatusKey(value)
    local base = SCRIPT_STATUS_STATES[key] or SCRIPT_STATUS_STATES.testing
    local resolved = cloneValue(base)
    local manifest = self.StatusManifest
    local definitions = type(manifest) == "table"
        and (manifest.StatusDefinitions or manifest.statusDefinitions)
        or nil
    local remote = type(definitions) == "table" and definitions[key] or nil

    if type(remote) == "table" then
        resolved.Label = tostring(remote.Label or remote.label or resolved.Label)
        resolved.Color = colorFromHex(remote.Color or remote.color, resolved.Color)
        resolved.GlowColor = colorFromHex(
            remote.GlowColor or remote.glowColor,
            resolved.GlowColor or resolved.Color
        )
        local legacy = tostring(remote.LegacyLevel or remote.legacyLevel or resolved.Level):lower()
        if legacy == "green" or legacy == "yellow" or legacy == "red" then
            resolved.Level = legacy
        end
    end

    resolved.State = key
    return resolved
end

local function formatKeyRemaining(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if days > 0 then
        return string.format("KEY: %dD %dH %dM REMAINING", days, hours, minutes)
    elseif hours > 0 then
        return string.format("KEY: %dH %dM REMAINING", hours, minutes)
    elseif minutes > 0 then
        return string.format("KEY: %dM %02dS REMAINING", minutes, secs)
    end
    return string.format("KEY: %dS REMAINING", secs)
end

function WindowMethods:_refreshStatusChipLayout()
    if not self.StatusLabel or not self.KeyTimeLabel then return end
    local keyVisible = self.KeyTimeLabel.Visible
    self.StatusLabel.Position = UDim2.fromOffset(34, keyVisible and 5 or 0)
    self.StatusLabel.Size = keyVisible and UDim2.new(1, -44, 0, 17) or UDim2.new(1, -44, 1, 0)
    self.KeyTimeLabel.Position = UDim2.fromOffset(34, 23)
    self.KeyTimeLabel.Size = UDim2.new(1, -44, 0, 15)
    local width = math.max(178, textSize(self.StatusLabel, 10000).X + 46)
    if keyVisible then width = math.max(width, textSize(self.KeyTimeLabel, 10000).X + 46) end
    -- Keep the classic compact topbar proportions and protect the title area.
    width = math.clamp(math.ceil(width), 178, 226)
    self.StatusChip.Size = UDim2.fromOffset(width, 42)
    if self.HeaderTitle then self.HeaderTitle.Size = UDim2.new(1, -(width + 192), 1, 0) end
end

function WindowMethods:SetScriptStatus(status, detail)
    if type(status) == "table" then
        -- The topbar should always show the compact status label ("Fully Working",
        -- "In Testing", etc.). Long-form Detail text belongs in the tooltip.
        detail = status.Label or status.label or detail
        status = status.State or status.state or status.Status or status.status or status.Level or status.level
    end
    local state = self:_resolveStatusState(status)
    self.ScriptStatus = {
        State = state.State,
        Level = state.Level,
        Role = state.Role,
        Label = detail or state.Label,
        Color = state.Color,
        GlowColor = state.GlowColor,
    }
    if self.StatusDot then
        setThemeRole(self.StatusDot, "BackgroundColor3", nil)
        self.StatusDot.BackgroundColor3 = state.Color
    end
    if self.StatusGlow then
        setThemeRole(self.StatusGlow, "BackgroundColor3", nil)
        self.StatusGlow.BackgroundColor3 = state.GlowColor or state.Color
    end
    if self.StatusHalo then
        setThemeRole(self.StatusHalo, "BackgroundColor3", nil)
        self.StatusHalo.BackgroundColor3 = state.GlowColor or state.Color
    end
    if self.StatusLabel then self.StatusLabel.Text = self.ScriptStatus.Label end
    self:_refreshStatusChipLayout()
    return self.ScriptStatus.Level
end

function WindowMethods:GetScriptStatus()
    local status = self.ScriptStatus or SCRIPT_STATUS_STATES.testing
    return status.Level, status.Label, status.State
end

local function versionParts(version)
    local out = {}
    for part in tostring(version or "0"):gmatch("%d+") do
        table.insert(out, tonumber(part) or 0)
    end
    return out
end

local function compareVersions(a, b)
    local aa, bb = versionParts(a), versionParts(b)
    local count = math.max(#aa, #bb)
    for i = 1, count do
        local av, bv = aa[i] or 0, bb[i] or 0
        if av < bv then return -1 end
        if av > bv then return 1 end
    end
    return 0
end

local function mapLookup(map, id)
    if type(map) ~= "table" then return nil end
    return map[tostring(id)] or map[tonumber(id)]
end

function WindowMethods:_selectStatusManifestEntry(manifest)
    if type(manifest) ~= "table" then return nil, nil end
    local placeEntry = mapLookup(manifest.Places or manifest.places, game.PlaceId)
    if placeEntry ~= nil then return placeEntry, "place" end
    local gameEntry = mapLookup(manifest.Games or manifest.games, game.GameId)
    if gameEntry ~= nil then return gameEntry, "game" end
    local defaultEntry = manifest.Default or manifest.default
    if defaultEntry ~= nil then return defaultEntry, "default" end
    if manifest.Status or manifest.status or manifest.Level or manifest.level then
        return manifest, "root"
    end
    return nil, nil
end

function WindowMethods:ApplyStatusManifest(manifest, sourceName)
    if type(manifest) == "string" then
        local statusConfig = type(self.Settings.StatusControl) == "table" and self.Settings.StatusControl or {}
        local maximumBytes = math.max(4096, tonumber(statusConfig.MaximumBytes) or 262144)
        if #manifest > maximumBytes then return false, "manifest_too_large" end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, manifest)
        if not ok or type(decoded) ~= "table" then return false, "invalid_json" end
        manifest = decoded
    end
    if type(manifest) ~= "table" then return false, "invalid_manifest" end

    local schemaVersion = tonumber(manifest.SchemaVersion or manifest.schemaVersion or 1)
    if not schemaVersion or schemaVersion < 1 or schemaVersion > 1 then
        return false, "unsupported_schema"
    end

    local games = manifest.Games or manifest.games
    local places = manifest.Places or manifest.places
    if games ~= nil and type(games) ~= "table" then return false, "invalid_games" end
    if places ~= nil and type(places) ~= "table" then return false, "invalid_places" end

    -- Version metadata is independent of game support, so update checks still
    -- work even when this particular game has no status entry yet.
    local libraryInfo = manifest.Library or manifest.library
    if type(libraryInfo) == "table" then
        local latest = libraryInfo.LatestVersion or libraryInfo.latestVersion or libraryInfo.Version or libraryInfo.version
        if latest ~= nil then
            latest = tostring(latest)
            self.LibraryUpdateInfo = {
                CurrentVersion = Library.Version,
                LatestVersion = latest,
                UpdateAvailable = compareVersions(Library.Version, latest) < 0,
                Message = libraryInfo.Message or libraryInfo.message,
                URL = libraryInfo.URL or libraryInfo.url,
                CheckedAt = os.time(),
            }
            local statusConfig = type(self.Settings.StatusControl) == "table" and self.Settings.StatusControl or {}
            if self.LibraryUpdateInfo.UpdateAvailable and statusConfig.NotifyOnUpdate ~= false and not self._updateNoticeSent then
                self._updateNoticeSent = true
                self:Notify({
                    Title = "Hub update available",
                    Content = self.LibraryUpdateInfo.Message or ("Version " .. latest .. " is available."),
                    Duration = 5,
                })
            end
        end
    end

    local entry, scope = self:_selectStatusManifestEntry(manifest)
    if entry == nil then return false, "no_game_match" end

    local status, label
    if type(entry) == "string" then
        status = entry
    elseif type(entry) == "table" then
        status = entry.State or entry.state or entry.Status or entry.status or entry.Level or entry.level
        label = entry.Label or entry.label or entry.Detail or entry.detail
    end
    if status == nil then return false, "missing_status" end

    self.StatusManifest = cloneValue(manifest)
    self.StatusManifestSource = sourceName or "manifest"
    self.CurrentStatusEntry = type(entry) == "table"
        and cloneValue(entry)
        or {State = canonicalStatusKey(entry), Label = label}
    self:SetScriptStatus(self.CurrentStatusEntry, label)
    self.RemoteStatusInfo = {
        Source = sourceName or "manifest",
        Scope = scope,
        GameId = game.GameId,
        PlaceId = game.PlaceId,
        State = self.ScriptStatus.State,
        Status = self.ScriptStatus.Level,
        Label = self.ScriptStatus.Label,
        ModuleId = type(entry) == "table" and (entry.ModuleId or entry.moduleId) or nil,
        Version = type(entry) == "table" and (entry.Version or entry.version) or nil,
        Summary = type(entry) == "table" and (entry.Summary or entry.summary) or nil,
        Detail = type(entry) == "table" and (entry.Detail or entry.detail) or nil,
        Tooltip = type(entry) == "table" and (entry.Tooltip or entry.tooltip) or nil,
        ManifestUpdatedAt = manifest.UpdatedAt or manifest.updatedAt,
        UpdatedAt = os.time(),
    }

    if type(self._refreshOwnerStatusCards) == "function" then
        pcall(function() self:_refreshOwnerStatusCards() end)
    end

    for _, listener in ipairs(self._statusListeners or {}) do
        if listener.Active then
            safeCallback(
                listener.Callback,
                cloneValue(self.CurrentStatusEntry),
                cloneValue(self.StatusManifest),
                self:GetStatusControlInfo()
            )
        end
    end

    return true, scope
end

function WindowMethods:GetStatusManifest()
    return self.StatusManifest and cloneValue(self.StatusManifest) or nil
end

function WindowMethods:GetStatusEntry(gameId, placeId)
    local manifest = self.StatusManifest
    if type(manifest) ~= "table" then return nil, nil end
    local resolvedPlaceId = placeId == nil and game.PlaceId or placeId
    local resolvedGameId = gameId == nil and game.GameId or gameId
    local entry = mapLookup(manifest.Places or manifest.places, resolvedPlaceId)
    local scope = "place"
    if entry == nil then
        entry = mapLookup(manifest.Games or manifest.games, resolvedGameId)
        scope = "game"
    end
    if entry == nil then
        entry = manifest.Default or manifest.default
        scope = "default"
    end
    return entry ~= nil and cloneValue(entry) or nil, entry ~= nil and scope or nil
end

function WindowMethods:SubscribeStatus(callback, fireImmediately)
    assert(type(callback) == "function", "SubscribeStatus callback must be a function")
    local listener = {Callback = callback, Active = true}
    table.insert(self._statusListeners, listener)

    if fireImmediately ~= false and self.CurrentStatusEntry then
        safeCallback(
            callback,
            cloneValue(self.CurrentStatusEntry),
            self:GetStatusManifest(),
            self:GetStatusControlInfo()
        )
    end

    local disconnected = false
    return function()
        if disconnected then return end
        disconnected = true
        listener.Active = false
    end
end

function WindowMethods:GetStatusControlInfo()
    return cloneValue(self.RemoteStatusInfo or {})
end

function WindowMethods:GetLibraryUpdateInfo()
    if not self.LibraryUpdateInfo then return nil end
    local copy = {}
    for key, value in pairs(self.LibraryUpdateInfo) do copy[key] = value end
    return copy
end

function WindowMethods:RefreshStatusControl()
    local config = type(self.Settings.StatusControl) == "table" and self.Settings.StatusControl or {}
    if config.Enabled == false then return false, "disabled" end

    local applied = self.StatusManifest ~= nil
    local localManifest = type(config.LocalManifest) == "table" and config.LocalManifest or nil

    local url = tostring(config.URL or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" then
        if not applied and localManifest then
            local ok = self:ApplyStatusManifest(localManifest, "local")
            return ok == true, ok and "local" or "invalid_local_manifest"
        end
        return applied, applied and self.StatusManifestSource or "no_url"
    end

    local requestUrl = url
    if config.CacheBust ~= false then
        local separator = requestUrl:find("?", 1, true) and "&" or "?"
        requestUrl = requestUrl .. separator .. "vitality_status_poll=" .. tostring(os.time())
    end

    local fetcher = config.Fetcher
    local ok, body
    if type(fetcher) == "function" then
        ok, body = pcall(fetcher, requestUrl, self)
    else
        ok, body = pcall(function() return game:HttpGet(requestUrl, true) end)
    end

    if not ok or body == nil then
        self.RemoteStatusError = tostring(body or "request_failed")
        if not applied and localManifest then
            local localOk = self:ApplyStatusManifest(localManifest, "local")
            applied = localOk == true
        end
        if not applied and type(config.FailureStatus) == "table" then
            self:SetScriptStatus(config.FailureStatus, config.FailureStatus.Label or "Status unavailable")
        end
        return applied, "request_failed"
    end

    local success, reason = self:ApplyStatusManifest(body, "remote")
    if success then
        self.RemoteStatusError = nil
        self.RemoteStatusLastSuccess = os.time()
    elseif not applied and localManifest then
        local localOk = self:ApplyStatusManifest(localManifest, "local")
        applied = localOk == true
    end
    return success or applied, success and reason or (applied and "local_fallback" or reason)
end

function WindowMethods:StartStatusControl()
    local config = type(self.Settings.StatusControl) == "table" and self.Settings.StatusControl or {}
    if config.Enabled == false then return false end
    if self._statusControlRunning then return true end

    self._statusControlRunning = true
    self._statusControlToken = (self._statusControlToken or 0) + 1
    local token = self._statusControlToken
    local interval = math.max(5, tonumber(config.PollInterval) or 5)

    task.spawn(function()
        while self.Gui and self.Gui.Parent and self._statusControlRunning and self._statusControlToken == token do
            self:RefreshStatusControl()
            task.wait(interval)
        end
    end)
    return true
end

function WindowMethods:StopStatusControl()
    self._statusControlRunning = false
    self._statusControlToken = (self._statusControlToken or 0) + 1
end


-- Finalizes access after the key system has accepted the user. GameLoader is
-- intentionally opt-in so existing scripts keep their current behavior.
-- When enabled, the detected game's module is loaded before the main hub is
-- revealed, preventing a generic UI from flashing before the correct module.
function WindowMethods:_completeStartup()
    if self._startupCompletionStarted then return false end
    self._startupCompletionStarted = true

    task.spawn(function()
        local loaderConfig = type(self.Settings.GameLoader) == "table" and self.Settings.GameLoader or nil
        local loaded, reason, detection = true, "disabled", nil

        -- Fetch status before the game module is initialized. This makes the
        -- validated remote entry available through the module context on its
        -- very first line instead of only updating the header afterward.
        self:RefreshStatusControl()

        if self.OwnerInfo and self.OwnerInfo.IsOwner then
            self:BuildOwnerDashboard()
        end

        if loaderConfig and loaderConfig.Enabled ~= false then
            self:SetScriptStatus("yellow", loaderConfig.DetectingLabel or "Detecting game")
            loaded, reason, detection = Library:LoadDetectedGame(self, loaderConfig)
        else
            self:SetScriptStatus("green", "Fully working")
        end

        -- Universal navigation is library-level and therefore exists for every
        -- game/module. It is built after the game module so it never steals that
        -- module's initial active page, then pinned visually under Favorites.
        local universalOk, universalError = pcall(function()
            self:_ensureUniversalTabDropdown()
        end)
        if not universalOk then
            warn("[NovaField] Universal tab dropdown build failed: " .. tostring(universalError))
        end

        -- Settings is a library-level page, so every supported game and the
        -- unsupported fallback receive the exact same pinned Settings tab.
        local settingsOk, settingsError = pcall(function()
            self:_ensureUniversalSettings()
        end)
        if not settingsOk then
            warn("[NovaField] Universal Settings build failed: " .. tostring(settingsError))
        end

        if self.Gui and self.Gui.Parent then
            self:SetVisible(true)
            self:StartStatusControl()
        end

        self._startupReady = true
        self.GameLoadResult = {
            Success = loaded == true,
            Reason = reason,
            Detection = detection,
            CompletedAt = os.time(),
        }
        safeCallback(self.Settings.OnReady, self, loaded, reason, detection)
    end)

    return true
end

function WindowMethods:IsReady()
    return self._startupReady == true
end

function WindowMethods:GetGameLoadResult()
    return self.GameLoadResult
end

function WindowMethods:GetKeyRemaining()
    local expiresAt = self.KeySession and tonumber(self.KeySession.ExpiresAt)
    if not expiresAt then return nil end
    return math.max(0, expiresAt - os.time())
end

function WindowMethods:GetKeySession()
    if not self.KeySession then return nil end
    local copy = {}
    for key, value in pairs(self.KeySession) do copy[key] = value end
    return copy
end

function WindowMethods:SetKeySession(session)
    self._keyCountdownToken = (self._keyCountdownToken or 0) + 1
    local token = self._keyCountdownToken
    self._expiredKickSent = false
    self.KeySession = type(session) == "table" and session or nil

    local permanent = self.KeySession and self.KeySession.Permanent == true
    local lifetimeLike = self.KeySession and self.KeySession.LifetimeLike == true
    local enforceLocalExpiry =
        not self.KeySession
        or self.KeySession.EnforceLocalExpiry ~= false

    local expiresAt =
        (not permanent)
        and self.KeySession
        and tonumber(self.KeySession.ExpiresAt)
        or nil

    if not expiresAt then
        if self.KeyTimeLabel then
            if permanent or lifetimeLike then
                self.KeyTimeLabel.Text = "KEY: LIFETIME"
                self.KeyTimeLabel.Visible = true
                setThemeRole(self.KeyTimeLabel, "TextColor3", "Success")
            else
                self.KeyTimeLabel.Text = ""
                self.KeyTimeLabel.Visible = false
            end
        end
        self:_refreshStatusChipLayout()
        return nil
    end

    local function update()
        local remaining = math.max(0, expiresAt - os.time())
        if self.KeyTimeLabel then
            self.KeyTimeLabel.Visible = true

            if lifetimeLike and remaining > 0 then
                self.KeyTimeLabel.Text = "KEY: LIFETIME"
                setThemeRole(self.KeyTimeLabel, "TextColor3", "Success")
            else
                self.KeyTimeLabel.Text =
                    remaining > 0
                    and formatKeyRemaining(remaining)
                    or (enforceLocalExpiry and "KEY: EXPIRED" or "KEY: RECHECK REQUIRED")

                local role =
                    remaining <= 0
                    and (enforceLocalExpiry and "Danger" or "Warning")
                    or (remaining <= 15 and "Warning" or "Muted")

                setThemeRole(self.KeyTimeLabel, "TextColor3", role)
            end

            self:_refreshStatusChipLayout()
        end

        -- Only a reliable server-derived expiry is allowed to kick locally.
        -- Transient/ambiguous KeyAuth responses never manufacture an expiry.
        if remaining <= 0
            and enforceLocalExpiry
            and not self._expiredKickSent then

            self._expiredKickSent = true
            self:SetScriptStatus("red", "Not working")
            task.defer(function()
                if LocalPlayer then
                    LocalPlayer:Kick("the key has expired!")
                end
            end)
        end

        return remaining
    end

    update()
    task.spawn(function()
        while self.Gui
            and self.Gui.Parent
            and self._keyCountdownToken == token
            and not self._expiredKickSent do

            task.wait(0.25)
            update()
        end
    end)

    return expiresAt
end

function Library:GetActiveWindow()
    local state =
        getVitalitySingleton("Main")

    if singletonWindowIsAlive(state) then
        return state.Window
    end

    -- Clean stale registry entries automatically.
    if state then
        clearVitalitySingleton(nil, "Main")
    end

    return nil
end

function Library:IsWindowOpen()
    return self:GetActiveWindow() ~= nil
end

function WindowMethods:Destroy()
    if self._destroyed then
        return true
    end

    self._destroyed = true
    self._visible = false
    self._minimized = false

    self._visibilityToken = (self._visibilityToken or 0) + 1
    self._keyCountdownToken = (self._keyCountdownToken or 0) + 1
    self._keyRemoteRefreshToken = (self._keyRemoteRefreshToken or 0) + 1
    self._statusControlToken = (self._statusControlToken or 0) + 1
    self._statusControlRunning = false

    Library:_closePopup(true)
    pcall(function() self:CloseCommandBar(true, true) end)

    pcall(function()
        self:StopStatusControl()
    end)

    -- Game-specific modules use this to restore hooks, stop loops, unbind
    -- RenderSteps, restore server state, and remove their external visuals.
    self:_runCleanupCallbacks()

    if self._loadingController then
        pcall(function()
            self._loadingController:Destroy()
        end)
        self._loadingController = nil
    end

    for _, connection in ipairs(self._connections or {}) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self._connections = {}

    for _, sound in pairs(self._soundObjects or {}) do
        pcall(function()
            sound:Stop()
            sound:Destroy()
        end)
    end
    self._soundObjects = {}

    for _, sound in ipairs(self._transientSounds or {}) do
        pcall(function()
            sound:Stop()
            sound:Destroy()
        end)
    end
    self._transientSounds = {}

    if self._soundGroup then
        pcall(function()
            self._soundGroup:Destroy()
        end)
        self._soundGroup = nil
    end

    local gui = self.Gui

    if gui then
        pcall(function()
            gui:Destroy()
        end)
    end

    if Library._activeWindow == self then
        Library._activeWindow = nil
    end

    if Library._screenGui == gui then
        Library._screenGui = nil
    end

    if type(Library._roleWindows) == "table"
        and Library._roleWindows[self._windowRole or "Main"] == self then
        Library._roleWindows[self._windowRole or "Main"] = nil
    end

    clearVitalitySingleton(
        self,
        self._windowRole
    )

    self.Gui = nil
    self.Main = nil
    self.MainSurface = nil
    self.BodyViewport = nil
    self.NavList = nil
    self.Content = nil
    self.ActiveTab = nil
    self.Tabs = {}
    self.FlagObjects = {}
    self._themeRenderers = {}

    return true
end

function WindowMethods:SetVisible(visible, immediate)
    visible = visible ~= false

    if self._destroyed then
        return false
    end

    if not self.Main then
        return visible
    end
    self._visible = visible
    self._visibilityToken = (self._visibilityToken or 0) + 1
    local token = self._visibilityToken
    Library:_closePopup(immediate == true)

    local main = self.Main
    local resting = self._restingPosition or UDim2.fromScale(0.5, 0.5)
    local offset = UDim2.new(resting.X.Scale, resting.X.Offset, resting.Y.Scale, resting.Y.Offset + 10)
    if visible then
        main.Visible = true
        main.Size =
            self._minimized
            and (self._collapsedSize or UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.TopbarHeight))
            or (self._expandedSize or UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.WindowHeight))

        if self.BodyViewport then
            self.BodyViewport.Visible = not self._minimized
        end

        main.Position = offset
        main.GroupTransparency = 1
        self:_tween(main, 0.38, {
            Position = resting,
            GroupTransparency = 0,
        }, Enum.EasingStyle.Quint)
    else
        local duration = immediate and 0 or self:_motionDuration(0.32)
        self:_tween(main, 0.32, {
            Position = offset,
            GroupTransparency = 1,
        }, Enum.EasingStyle.Quint)
        if duration <= 0 then
            main.Visible = false
        else
            task.delay(duration, function()
                if main.Parent and self._visible == false and self._visibilityToken == token then
                    main.Visible = false
                end
            end)
        end
    end
    return visible
end

function WindowMethods:Toggle()
    return self:SetVisible(not self._visible)
end

function WindowMethods:IsMinimized()
    return self._minimized == true
end

function WindowMethods:SetMinimized(minimized, immediate)
    if self._destroyed or not self.Main then
        return false
    end

    minimized = minimized == true
    self._minimized = minimized

    Library:_closePopup(immediate == true)

    local body = self.BodyViewport
    local main = self.Main

    local expanded =
        self._expandedSize
        or UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.WindowHeight)

    local collapsed =
        self._collapsedSize
        or UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.TopbarHeight)

    if self.MinimizeButton then
        self.MinimizeButton.Text =
            minimized
            and "+"
            or "-"
    end

    if minimized then
        if body then
            body.Visible = false
        end

        if immediate then
            main.Size = collapsed
        else
            self:_tween(
                main,
                0.24,
                {Size = collapsed},
                Enum.EasingStyle.Quint
            )
        end
    else
        if body then
            body.Visible = true
        end

        if immediate then
            main.Size = expanded
        else
            self:_tween(
                main,
                0.28,
                {Size = expanded},
                Enum.EasingStyle.Quint
            )
        end
    end

    return minimized
end

function WindowMethods:ToggleMinimized(immediate)
    return self:SetMinimized(
        not self:IsMinimized(),
        immediate
    )
end

function WindowMethods:_refreshHeaderTitle()
    if not self.HeaderTitle then
        return
    end

    local base =
        tostring(
            self.BaseHeaderTitle
            or self.Settings.Name
            or "vitality's hub"
        )

    local gameName =
        tostring(
            self.HeaderGameName
            or self.Settings.GameName
            or ""
        )

    local version =
        tostring(
            self.HeaderGameVersion
            or self.Settings.InterfaceVersion
            or ""
        )

    if gameName ~= "" then
        local suffix = gameName

        if version ~= "" then
            if not version:lower():match("^v") then
                version = "v" .. version
            end

            suffix = suffix .. " " .. version
        end

        self.HeaderTitle.Text =
            base
            .. "  |  "
            .. suffix
    else
        self.HeaderTitle.Text = base
    end
end

function WindowMethods:SetHeaderContext(gameName, version)
    self.HeaderGameName =
        gameName
        and tostring(gameName)
        or nil

    self.HeaderGameVersion =
        version
        and tostring(version)
        or nil

    self:_refreshHeaderTitle()
end

function WindowMethods:_buildPersonalization(tab)
    if tab._premiumPersonalization then return end
    tab._premiumPersonalization = true
    local previousSection = tab._currentSection
    local previousColumn = tab._nextColumn
    -- Existing modules may supply their own Appearance/Window/Controls cards.
    -- Extend their page; only construct the base cards when the page is empty.
    if #tab.Sections == 0 then
        local appearance = tab:CreateSection({Name = "Appearance", Description = "Theme, typography and accent colors.", Icon = "palette", Column = 1})
        appearance:CreateThemeDropdown({Name = "Theme", CurrentOption = self:GetTheme()})
        appearance:CreateDropdown({Name = "Interface font", Options = self:GetFontOptions(), CurrentOption = self:GetFontPreset(), Callback = function(value) self:SetFontPreset(value) end})
        appearance:CreateAccentPicker({Name = "Accent color"})
        appearance:CreateButtonPicker({Name = "Button color"})
        local border = tab:CreateSection({Name = "Window", Description = "Outline and border appearance.", Icon = "settings", Column = 2})
        local settings = self:GetBorderStroke()
        border:CreateToggle({Name = "Border stroke", CurrentValue = settings.Enabled, Callback = function(value) self:SetBorderStrokeEnabled(value); self:_saveConfig() end})
        border:CreateToggle({Name = "Follow accent", CurrentValue = settings.UseAccent, Callback = function(value) self:SetBorderStrokeUseAccent(value); self:_saveConfig() end})
        border:CreateSlider({Name = "Border thickness", Range = {0, 4}, Increment = 0.25, Suffix = "px", CurrentValue = settings.Thickness, Callback = function(value) self:SetBorderStrokeThickness(value); self:_saveConfig() end})
        border:CreateSlider({Name = "Border transparency", Range = {0, 100}, Increment = 1, Suffix = "%", CurrentValue = settings.Transparency * 100, Callback = function(value) self:SetBorderStrokeTransparency(value / 100); self:_saveConfig() end})
        border:CreateColorPicker({Name = "Border color", Color = settings.Color or Theme.Border, Callback = function(value) self:SetBorderStrokeColor(value); self:_saveConfig() end})
        local controls = tab:CreateSection({Name = "Controls", Description = "Interface access and motion.", Icon = "keyboard", Column = 1})
        if self._fixedToggleKeyName then
            controls:CreateParagraph({
                Title = "Toggle interface",
                Content = "Fixed developer preview shortcut: ] (RightBracket). This shortcut is independent from the main Vitality window.",
            })
        else
            controls:CreateKeybind({Name = "Toggle interface", Behavior = "toggleinterface", CurrentKeybind = self:GetToggleKey()})
        end
        controls:CreateToggle({Name = "Animations", CurrentValue = self:GetAnimationsEnabled(), Callback = function(value) self:SetAnimationsEnabled(value) end})
        controls:CreateToggle({Name = "Reduced motion", CurrentValue = self.Motion.ReducedMotion, Callback = function(value) self:SetReducedMotion(value) end})
    end
    for index, spec in ipairs({
        {"accent", "Accent gradient", "Shared by the loader, sliders and enabled toggles."},
        {"button", "Button gradient", "Action button colors with automatic caption contrast."},
        {"tab", "Active tab gradient", "Highlight for the currently selected tab."},
        {"icon", "Icon gradient", "Subtle accent depth behind section icons."},
    }) do
        local kind = spec[1]
        local section = tab:CreateSection({Name = spec[2], Description = spec[3], Icon = "palette", Column = index % 2 == 1 and 1 or 2})
        local options = self:GetGradientOptions(kind)
        section:CreateToggle({Name = "Gradient enabled", CurrentValue = options.Enabled,
            Callback = function(value) self:SetGradientOptions(kind, {Enabled = value}) end})
        local startPicker, endPicker, direction
        local function updateVisibility()
            local follow = self:GetGradientOptions(kind).FollowAccent
            if startPicker then startPicker:SetVisible(not follow) end
            if endPicker then endPicker:SetVisible(not follow) end
            if direction then direction:SetVisible(not follow) end
        end
        if kind ~= "accent" then
            section:CreateToggle({Name = "Follow accent", CurrentValue = options.FollowAccent,
                Callback = function(value) self:SetGradientOptions(kind, {FollowAccent = value}); updateVisibility() end})
        end
        startPicker = section:CreateGradientPicker({Name = "Start color", GradientKind = kind, GradientStop = "Start"})
        endPicker = section:CreateGradientPicker({Name = "End color", GradientKind = kind, GradientStop = "End"})
        direction = section:CreateSlider({Name = "Direction", Range = {0, 360}, Increment = 1, Suffix = "deg", CurrentValue = options.Rotation,
            Callback = function(value) self:SetGradientOptions(kind, {Rotation = value}) end})
        updateVisibility()
    end
    if self.UniversalSettingsTab == nil and tab._VitalityNotificationsMoved ~= true then
        local notifications = tab:CreateSection({Name = "Notifications", Description = "Timing, position and visibility.", Icon = "bell", Column = 2})
        notifications:CreateToggle({Name = "Notifications", Behavior = "notifications", CurrentValue = self:GetNotificationsEnabled()})
        notifications:CreateSlider({Name = "Default duration", Range = {1, 12}, Increment = 0.5, Suffix = "s", CurrentValue = self.NotificationSettings.Duration,
            Callback = function(value) self.NotificationSettings.Duration = value; self:_saveConfig() end})
        notifications:CreateDropdown({Name = "Position", Options = {"Top right", "Bottom right"}, CurrentOption = self.NotificationSettings.Position,
            Callback = function(value) self.NotificationSettings.Position = value; self:_saveConfig() end})
        notifications:CreateSlider({Name = "Opacity", Range = {25, 100}, Increment = 1, Suffix = "%", CurrentValue = self.NotificationSettings.Opacity,
            Callback = function(value) self.NotificationSettings.Opacity = value; self:_saveConfig() end})
    end
    if previousSection then tab._currentSection = previousSection end
    tab._nextColumn = previousColumn
end

function WindowMethods:OpenPersonalization()
    for _, tab in ipairs(self.Tabs or {}) do
        local lowered = tostring(tab.Name or ""):lower()
        if lowered == "personalization" or lowered == "appearance" then
            self:_buildPersonalization(tab)
            self:_setActiveTab(tab)
            return true
        end
    end
    local tab = self:CreateTab("Personalization", "palette")
    tab.NavButton.Visible = false
    self:_buildPersonalization(tab)
    self:_setActiveTab(tab)
    return true
end

-- Universal Settings belongs to the shared library rather than any game module.
-- It is created after the detected module has finished building so game tabs keep
-- their normal initial selection, then its navigation button is pinned directly
-- above the version/footer area with a divider above it.
function WindowMethods:_ensureUniversalSettings()
    if self._destroyed then return nil end

    local settingsTab = self.UniversalSettingsTab

    if not settingsTab then
        for _, existingTab in ipairs(self.Tabs or {}) do
            if tostring(existingTab.Name or ""):lower() == "settings" then
                settingsTab = existingTab
                break
            end
        end
    end

    if not settingsTab then
        -- No icon is supplied intentionally: CreateTab falls back to the built-in
        -- diamond until dedicated Settings artwork is uploaded.
        settingsTab = self:CreateTab("Settings")
    end

    self.UniversalSettingsTab = settingsTab

    -- Any Personalization/Appearance page should leave notifications to this
    -- universal page instead of constructing a duplicate card later.
    for _, existingTab in ipairs(self.Tabs or {}) do
        local lowered = tostring(existingTab.Name or ""):lower()
        if lowered == "personalization" or lowered == "appearance" then
            existingTab._VitalityNotificationsMoved = true
        end
    end

    local settingsButton = settingsTab.NavButton
    local navList = self.NavList
    local navPanel = navList and navList.Parent

    if settingsButton and navList and navPanel then
        -- Space reserved below the scrolling game tabs:
        -- divider -> Settings -> version -> footer.
        navList.Size = UDim2.new(1, -18, 1, -120)

        settingsButton.Parent = navPanel
        settingsButton.Position = UDim2.new(0, 9, 1, -99)
        settingsButton.Size = UDim2.new(1, -18, 0, 40)

        local dividerHolder = self.UniversalSettingsDivider
            or navPanel:FindFirstChild("VitalitySettingsDivider")

        if not dividerHolder then
            dividerHolder = create("Frame", {
                Name = "VitalitySettingsDivider",
                Parent = navPanel,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 9, 1, -113),
                Size = UDim2.new(1, -18, 0, 10),
                ZIndex = 1,
            })

            local dividerLine = create("Frame", {
                Name = "Line",
                Parent = dividerHolder,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, -16, 0, 1),
                BackgroundColor3 = Theme.BorderSoft,
                BackgroundTransparency = 0.22,
                BorderSizePixel = 0,
                ZIndex = 1,
            })
            themeProperty(dividerLine, "BackgroundColor3", "BorderSoft")
        end

        self.UniversalSettingsDivider = dividerHolder
    end

    self:_buildBackgroundSettings(settingsTab)

    if settingsTab._VitalityUniversalSettingsBuilt then
        return settingsTab
    end

    -- A game module may already provide the complete Settings page. Reuse it
    -- verbatim instead of rebuilding or duplicating controls. This keeps legacy
    -- modules fully compatible while the shared library supplies Settings for
    -- every module that does not already define it.
    local existingSettingsSections = {}
    for _, section in ipairs(settingsTab.Sections or {}) do
        existingSettingsSections[tostring(section.Name or ""):lower()] = true
    end

    if existingSettingsSections["vitality's hub"]
        and existingSettingsSections["audio"]
        and existingSettingsSections["notifications"] then

        settingsTab._VitalityUniversalSettingsBuilt = true
        return settingsTab
    end

    settingsTab._VitalityUniversalSettingsBuilt = true

    -- HUB SETTINGS ---------------------------------------------------------
    local hubSection = settingsTab:CreateSection({
        Name = "vitality's hub",
        Description = "Shortcuts, motion, and hub controls.",
        Side = "Left",
    })

    if self._fixedToggleKeyName then
        hubSection:CreateParagraph({
            Title = "Toggle preview",
            Content = "Fixed shortcut: ] (RightBracket). The development preview keybind cannot be changed or synchronized with the main hub.",
        })
    else
        hubSection:CreateKeybind({
            Name = "Toggle hub",
            Info = "Choose the shortcut used to open or close the hub.",
            CurrentKeybind = self:GetToggleKey(),
            Flag = "InterfaceKeybind",
            Behavior = "ToggleInterface",
            Callback = function() end,
        })
    end

    local animationsToggle = hubSection:CreateToggle({
        Name = "Hub animations",
        Info = "Animate tabs, popups, controls, and notifications.",
        CurrentValue = self:GetAnimationsEnabled(),
        Flag = "InterfaceAnimations",
        Callback = function(enabled)
            self:SetAnimationsEnabled(enabled)
        end,
    })

    local animationSpeed = hubSection:CreateSlider({
        Name = "Animation speed",
        Info = "Adjust the pace of interface motion.",
        Range = {0.5, 2},
        Increment = 0.05,
        CurrentValue = self:GetMotionSpeed(),
        Suffix = "x",
        Flag = "AnimationSpeed",
        Callback = function(value)
            self:SetMotionSpeed(value)
        end,
    })

    self:SetAnimationsEnabled(animationsToggle:Get())
    self:SetMotionSpeed(animationSpeed:Get())

    hubSection:CreateButton({
        Name = "Save configuration",
        Info = "Persist all flagged control values.",
        Interact = "Save",
        Callback = function()
            self:SaveConfiguration()
            self:Notify({
                Title = "Settings saved",
                Content = "Your preferences are up to date.",
                Duration = 4,
            })
        end,
    })

    -- AUDIO ----------------------------------------------------------------
    local audioSection = settingsTab:CreateSection({
        Name = "Audio",
        Description = "Gentle feedback sounds with one master level.",
        Side = "Left",
    })

    local soundVolume = audioSection:CreateSlider({
        Name = "Sound volume",
        Info = "Adjust the hub sound level.",
        Range = {0, 100},
        Increment = 1,
        CurrentValue = math.floor(self:GetSoundVolume() * 100 + 0.5),
        Suffix = "%",
        Flag = "SoundVolume",
        Callback = function(value)
            self:SetSoundVolume(value / 100)
        end,
    })

    self:SetSoundVolume(soundVolume:Get() / 100)

    audioSection:CreateButton({
        Name = "Preview feedback",
        Info = "Play a short, low-volume notification sound.",
        Interact = "Preview",
        Callback = function()
            self:Notify({
                Title = "Sound preview",
                Content = "Sound feedback is working.",
                Duration = 2.5,
            })
        end,
    })

    -- NOTIFICATIONS ---------------------------------------------------------
    local notificationsSection = settingsTab:CreateSection({
        Name = "Notifications",
        Description = "Timing, position and visibility.",
        Side = "Right",
    })

    notificationsSection:CreateToggle({
        Name = "Notifications",
        Behavior = "notifications",
        CurrentValue = self:GetNotificationsEnabled(),
        Flag = "NotificationsEnabled",
    })

    notificationsSection:CreateSlider({
        Name = "Default duration",
        Range = {1, 12},
        Increment = 0.5,
        Suffix = "s",
        CurrentValue = self.NotificationSettings.Duration,
        Callback = function(value)
            self.NotificationSettings.Duration = value
            self:_saveConfig()
        end,
    })

    notificationsSection:CreateDropdown({
        Name = "Position",
        Options = {"Top right", "Bottom right"},
        CurrentOption = self.NotificationSettings.Position,
        Callback = function(value)
            self.NotificationSettings.Position = value
            self:_saveConfig()
        end,
    })

    notificationsSection:CreateSlider({
        Name = "Opacity",
        Range = {25, 100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = self.NotificationSettings.Opacity,
        Callback = function(value)
            self.NotificationSettings.Opacity = value
            self:_saveConfig()
        end,
    })

    return settingsTab
end

function WindowMethods:CreateTab(name, image)
    local tab = setmetatable({}, TabMethods)
    tab.Window = self
    tab.Name = name or "Tab"
    tab.Sections = {}
    tab._nextColumn = 1
    tab._currentSection = nil

    local nav = create("TextButton", {
        Parent = self.NavList,
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = (#self.Tabs + 1) * 10,
        Text = "",
        AutoButtonColor = false,
    })
    corner(nav, 9)
    local navGradient, refreshNavGradient = applyThemeGradient(nav, self, "tab", 0.35)
    local navStroke = stroke(nav, Theme.AccentVisible, 1, 0.62)
    navStroke.Enabled = false
    local navIndicator = create("Frame", {
        Parent = nav,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 18),
        BackgroundColor3 = Theme.AccentVisible,
        BorderSizePixel = 0,
        Visible = false,
    })
    corner(navIndicator, 2)

    local icon = createIcon(nav, image, "diamond")
    icon.Position = UDim2.fromOffset(10, 11)
    icon.Size = UDim2.fromOffset(18, 18)

    local title = makeText(nav, tab.Name, 13, Theme.Muted, Enum.Font.GothamMedium)
    title.Position = UDim2.fromOffset(36, 0)
    title.Size = UDim2.new(1, -42, 1, 0)
    title.TextWrapped = false
    title.TextTruncate = Enum.TextTruncate.AtEnd
    local function fitNavigation()
        if not nav.Parent then return end
        local collapsed = self.SidebarCollapsed == true
        local grouped = tab._navDropdown ~= nil

        -- Footer tabs are parented directly to the panel and need both margins.
        -- Dropdown children remain in NavList and use a smaller indented row.
        local inset = grouped and 8 or (nav.Parent == self.NavList and 0 or 18)
        local height = grouped and 36 or 40
        local size = UDim2.new(1, -inset, 0, height)
        if nav.Size ~= size then nav.Size = size end

        title.Visible = not collapsed
        icon.AnchorPoint = Vector2.new(collapsed and 0.5 or 0, 0.5)

        if collapsed then
            icon.Position = UDim2.fromScale(0.5, 0.5)
        elseif grouped then
            icon.Position = UDim2.new(0, 18, 0.5, 0)
            title.Position = UDim2.fromOffset(44, 0)
            title.Size = UDim2.new(1, -50, 1, 0)
        else
            icon.Position = UDim2.new(0, 10, 0.5, 0)
            title.Position = UDim2.fromOffset(36, 0)
            title.Size = UDim2.new(1, -42, 1, 0)
        end
    end
    tab._fitNavigation = fitNavigation
    self:_trackConnection(nav:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitNavigation))
    self:_trackConnection(nav:GetPropertyChangedSignal("Parent"):Connect(fitNavigation))
    task.defer(fitNavigation)

    local pageClip = create("Frame", {
        Parent = self.Content,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 16),
        Size = UDim2.new(1, -32, 1, -32),
        ClipsDescendants = true,
        Visible = false,
    })

    local page = create("ScrollingFrame", {
        Parent = pageClip,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        CanvasPosition = Vector2.new(0, 0),
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Disabled,
        ScrollBarImageTransparency = 0.34,
        ClipsDescendants = true,
        Visible = true,
    })

    local columns = create("Frame", {
        Parent = page,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, 100),
        ClipsDescendants = false,
    })

    local left = create("Frame", {
        Parent = columns,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -8, 0, 100),
        Position = UDim2.fromOffset(0, 0),
    })
    local right = create("Frame", {
        Parent = columns,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -8, 0, 100),
        Position = UDim2.new(0.5, 8, 0, 0),
    })

    local leftLayout = create("UIListLayout", {
        Parent = left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, UIStyle.CardGap),
    })
    local rightLayout = create("UIListLayout", {
        Parent = right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, UIStyle.CardGap),
    })

    local function recalc()
        local scale = logicalScale(page)
        local leftH = leftLayout.AbsoluteContentSize.Y / scale
        local rightH = rightLayout.AbsoluteContentSize.Y / scale
        local available = page.AbsoluteSize.X / logicalScale(page)
        local singleColumn = available > 0 and available < UIStyle.ResponsiveBreakpoint

        if singleColumn then
            local between = (leftH > 0 and rightH > 0) and UIStyle.CardGap or 0
            left.Position = UDim2.fromOffset(0, 0)
            left.Size = UDim2.new(1, -8, 0, leftH)
            right.Position = UDim2.fromOffset(0, leftH + between)
            right.Size = UDim2.new(1, -8, 0, rightH)
            local h = leftH + between + rightH
            columns.Size = UDim2.new(1, -8, 0, h)
            page.CanvasSize = UDim2.new(0, 0, 0, h + 22)
        else
            local h = math.max(leftH, rightH)
            left.Position = UDim2.fromOffset(0, 0)
            left.Size = UDim2.new(0.5, -8, 0, h)
            right.Position = UDim2.new(0.5, 8, 0, 0)
            right.Size = UDim2.new(0.5, -8, 0, h)
            columns.Size = UDim2.new(1, -8, 0, h)
            page.CanvasSize = UDim2.new(0, 0, 0, h + 22)
        end
    end

    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(recalc)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(recalc)
    page:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
    task.defer(recalc)

    tab.NavButton = nav
    tab.NavTitle = title
    tab.NavIcon = icon
    tab.NavGradient = navGradient
    tab.RefreshNavGradient = refreshNavGradient
    tab.NavStroke = navStroke
    tab.NavIndicator = navIndicator
    tab.Page = page
    tab.PageClip = pageClip
    tab.ColumnsHolder = columns
    tab.Columns = {left, right}
    tab.ColumnLayouts = {leftLayout, rightLayout}
    tab._recalc = recalc

    nav.MouseButton1Click:Connect(function()
        local lowered = tostring(tab.Name):lower()
        if lowered == "personalization" or lowered == "appearance" then self:_buildPersonalization(tab) end
        self:_playSound("Click")
        self:_setActiveTab(tab)
    end)

    nav.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then self:_tween(nav, 0.14, {BackgroundTransparency = 0.78}) end
    end)
    nav.MouseLeave:Connect(function()
        self:_tween(nav, 0.14, {BackgroundTransparency = self.ActiveTab == tab and 0 or 1})
    end)
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then self:_setActiveTab(tab) end
    return tab
end

-- ============================================================
-- COLLAPSIBLE TAB DROPDOWNS / TAB GROUPS
-- ============================================================
-- These are organizational containers for the left tab list. Child pages are
-- ordinary Vitality tabs, so existing section/control APIs continue to work.
local TabDropdownMethods = {}
TabDropdownMethods.__index = TabDropdownMethods

function TabDropdownMethods:_refreshVisual()
    if self._destroyed then return end

    local expanded = self.Expanded == true
    if self.Arrow then
        self.Arrow.Text = expanded and "v" or ">"
    end

    for _, tab in ipairs(self.Tabs or {}) do
        if tab and tab.NavButton then
            tab.NavButton.Visible = expanded and tab._dropdownHidden ~= true
            tab._navDropdown = self
            if tab._fitNavigation then tab._fitNavigation() end
        end
    end

    local activeInside = false
    if self.Window and self.Window.ActiveTab then
        for _, tab in ipairs(self.Tabs or {}) do
            if tab == self.Window.ActiveTab then
                activeInside = true
                break
            end
        end
    end

    if self.Header then
        self.Header.BackgroundTransparency = activeInside and 0.72 or (expanded and 0.82 or 1)
    end
    if self.Title then
        setThemeRole(self.Title, "TextColor3", (activeInside or expanded) and "Text" or "Muted")
    end
    if self.Icon then
        setIconColor(self.Icon, (activeInside or expanded) and Theme.Text or Theme.Muted)
    end
    if self.Arrow then
        setThemeRole(self.Arrow, "TextColor3", (activeInside or expanded) and "AccentVisible" or "Muted")
    end
end

function TabDropdownMethods:SetExpanded(value)
    self.Expanded = value == true
    self:_refreshVisual()
    return self.Expanded
end

function TabDropdownMethods:Toggle()
    return self:SetExpanded(not self.Expanded)
end

function TabDropdownMethods:CreateTab(name, image)
    if self._destroyed then return nil end

    local tab = self.Window:CreateTab(name, image)
    tab._navDropdown = self

    table.insert(self.Tabs, tab)

    local index = #self.Tabs
    local baseOrder = tonumber(self.LayoutOrder)
        or ((self.Header and self.Header.LayoutOrder) or 0)

    if tab.NavButton then
        tab.NavButton.LayoutOrder = baseOrder + index
    end

    if tab._fitNavigation then
        tab._fitNavigation()
    end

    self:_refreshVisual()
    return tab
end

TabDropdownMethods.AddTab = TabDropdownMethods.CreateTab

function TabDropdownMethods:Destroy()
    if self._destroyed then return false end
    self._destroyed = true

    local tabs = {}
    for _, tab in ipairs(self.Tabs or {}) do
        table.insert(tabs, tab)
    end
    self.Tabs = {}

    for _, tab in ipairs(tabs) do
        if tab and type(tab.Destroy) == "function" then
            pcall(function() tab:Destroy() end)
        end
    end

    if self.Header then
        pcall(function() self.Header:Destroy() end)
    end

    local window = self.Window
    if window and type(window.TabDropdowns) == "table" then
        for index = #window.TabDropdowns, 1, -1 do
            if window.TabDropdowns[index] == self then
                table.remove(window.TabDropdowns, index)
                break
            end
        end
    end

    return true
end

function WindowMethods:CreateTabDropdown(data, image)
    if type(data) ~= "table" then
        data = {
            Name = tostring(data or "Group"),
            Icon = image,
        }
    end

    self.TabDropdowns = self.TabDropdowns or {}

    local dropdown = setmetatable({
        Window = self,
        Name = tostring(data.Name or data.Title or "Group"),
        Tabs = {},
        Expanded = data.Expanded == true,
        LayoutOrder = tonumber(data.LayoutOrder),
    }, TabDropdownMethods)

    local defaultOrder = ((#self.Tabs + #self.TabDropdowns) + 1) * 10 - 5
    local headerOrder = dropdown.LayoutOrder or defaultOrder
    dropdown.LayoutOrder = headerOrder

    local header = create("TextButton", {
        Parent = self.NavList,
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40),
        LayoutOrder = headerOrder,
        Text = "",
        AutoButtonColor = false,
    })
    corner(header, 10)

    local icon = createIcon(header, data.Icon or "diamond", "diamond")
    icon.Position = UDim2.new(0, 10, 0.5, -9)
    icon.Size = UDim2.fromOffset(18, 18)

    local title = makeText(header, dropdown.Name, 13, Theme.Muted, Enum.Font.GothamSemibold)
    title.Position = UDim2.fromOffset(36, 0)
    title.Size = UDim2.new(1, -64, 1, 0)
    title.TextTruncate = Enum.TextTruncate.AtEnd

    local arrow = makeText(header, dropdown.Expanded and "v" or ">", 14, Theme.Muted, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -8, 0.5, 0)
    arrow.Size = UDim2.fromOffset(20, 24)

    dropdown.Header = header
    dropdown.Icon = icon
    dropdown.Title = title
    dropdown.Arrow = arrow

    local function fitHeader()
        if not header.Parent then return end
        local collapsed = self.SidebarCollapsed == true
        title.Visible = not collapsed
        arrow.Visible = not collapsed
        icon.AnchorPoint = Vector2.new(collapsed and 0.5 or 0, 0.5)
        icon.Position = collapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 10, 0.5, 0)
    end
    dropdown._fitNavigation = fitHeader

    self:_trackConnection(header.MouseButton1Click:Connect(function()
        self:_playSound("Click")
        dropdown:Toggle()
    end))

    self:_trackConnection(header.MouseEnter:Connect(function()
        self:_tween(header, 0.12, {BackgroundTransparency = 0.78})
    end))

    self:_trackConnection(header.MouseLeave:Connect(function()
        dropdown:_refreshVisual()
    end))

    self:_trackConnection(header:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHeader))
    task.defer(fitHeader)

    table.insert(self.TabDropdowns, dropdown)
    dropdown:_refreshVisual()
    return dropdown
end

-- Friendly aliases so modules can use whichever name reads best.
WindowMethods.CreateDropdownTab = WindowMethods.CreateTabDropdown
WindowMethods.CreateTabGroup = WindowMethods.CreateTabDropdown

function WindowMethods:_refreshTabDropdownStyles()
    for _, dropdown in ipairs(self.TabDropdowns or {}) do
        if dropdown and dropdown._destroyed ~= true then
            dropdown:_refreshVisual()
        end
    end
end

-- ============================================================
-- UNIVERSAL FEATURE LAYER
-- ============================================================
-- These controls are library-owned, so every supported module inherits the
-- same Player / Visuals / Utilities pages without duplicating code in each
-- game module. Game-specific implementations may still coexist separately.
local function universalNotify(window, title, content, notificationType)
    if not window or type(window.Notify) ~= "function" then return end
    pcall(function()
        window:Notify({
            Title = tostring(title or "Universal"),
            Content = tostring(content or ""),
            Type = notificationType or "Information",
            Duration = 4,
        })
    end)
end

local function universalCurrentHumanoid()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function buildUniversalPlayerPage(window, tab)
    local section = tab:CreateSection({
        Name = "Movement",
        Description = "Generic movement controls. Game-specific movement systems can still be used separately.",
        Side = "Left",
    })

    local state = {
        SpeedEnabled = false,
        Speed = 16,
        JumpEnabled = false,
        JumpHeight = 7.2,
        Humanoid = nil,
        Originals = setmetatable({}, {__mode = "k"}),
    }
    window._universalMovementState = state

    local function remember(humanoid)
        if not humanoid or state.Originals[humanoid] then return end
        state.Originals[humanoid] = {
            WalkSpeed = humanoid.WalkSpeed,
            JumpHeight = humanoid.JumpHeight,
            JumpPower = humanoid.JumpPower,
            UseJumpPower = humanoid.UseJumpPower,
        }
    end

    local function apply(humanoid)
        humanoid = humanoid or universalCurrentHumanoid()
        if not humanoid then return end
        remember(humanoid)
        state.Humanoid = humanoid

        if state.SpeedEnabled then
            pcall(function() humanoid.WalkSpeed = state.Speed end)
        end

        if state.JumpEnabled then
            pcall(function()
                humanoid.UseJumpPower = false
                humanoid.JumpHeight = state.JumpHeight
            end)
        end
    end

    local function restoreHumanoid(humanoid, restoreSpeed, restoreJump)
        if not humanoid then return end
        local original = state.Originals[humanoid]
        if not original then return end

        if restoreSpeed then
            pcall(function() humanoid.WalkSpeed = original.WalkSpeed end)
        end

        if restoreJump then
            pcall(function()
                humanoid.UseJumpPower = original.UseJumpPower
                humanoid.JumpHeight = original.JumpHeight
                humanoid.JumpPower = original.JumpPower
            end)
        end
    end

    section:CreateSlider({
        Name = "Movement Speed",
        Info = "Sets Humanoid.WalkSpeed while the universal speed override is enabled.",
        Flag = "Universal_MovementSpeed",
        Range = {8, 120},
        Increment = 1,
        Suffix = " studs/s",
        CurrentValue = 16,
        Callback = function(value)
            state.Speed = math.clamp(tonumber(value) or 16, 8, 120)
            if state.SpeedEnabled then apply() end
        end,
    })

    section:CreateToggle({
        Name = "Enable Movement Speed",
        Info = "Continuously reapplies the selected movement speed.",
        Flag = "Universal_MovementSpeedEnabled",
        CurrentValue = false,
        Callback = function(value)
            state.SpeedEnabled = value == true
            local humanoid = universalCurrentHumanoid()
            if state.SpeedEnabled then
                apply(humanoid)
            else
                restoreHumanoid(humanoid or state.Humanoid, true, false)
            end
        end,
    })

    section:CreateSlider({
        Name = "Jump Height",
        Info = "Uses Humanoid.JumpHeight while enabled. Turning it off restores the previous jump mode/value.",
        Flag = "Universal_JumpHeight",
        Range = {2, 50},
        Increment = 0.5,
        Suffix = " studs",
        CurrentValue = 7.2,
        Callback = function(value)
            state.JumpHeight = math.clamp(tonumber(value) or 7.2, 2, 50)
            if state.JumpEnabled then apply() end
        end,
    })

    section:CreateToggle({
        Name = "Enable Jump Height",
        Info = "Applies the selected universal jump height.",
        Flag = "Universal_JumpHeightEnabled",
        CurrentValue = false,
        Callback = function(value)
            state.JumpEnabled = value == true
            local humanoid = universalCurrentHumanoid()
            if state.JumpEnabled then
                apply(humanoid)
            else
                restoreHumanoid(humanoid or state.Humanoid, false, true)
            end
        end,
    })

    section:CreateButton({
        Name = "Reset Movement",
        Callback = function()
            state.SpeedEnabled = false
            state.JumpEnabled = false
            local humanoid = universalCurrentHumanoid() or state.Humanoid
            restoreHumanoid(humanoid, true, true)
            universalNotify(window, "Universal Player", "Movement overrides restored.", "Success")
        end,
    })

    window:TrackConnection(RunService.Heartbeat:Connect(function()
        if state.SpeedEnabled or state.JumpEnabled then
            apply()
        end
    end))

    if Players.LocalPlayer then
        window:TrackConnection(Players.LocalPlayer.CharacterAdded:Connect(function(character)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid then
                task.defer(function()
                    if window._destroyed then return end
                    apply(humanoid)
                end)
            end
        end))
    end

    window:AddCleanup(function()
        state.SpeedEnabled = false
        state.JumpEnabled = false
        for humanoid in pairs(state.Originals) do
            restoreHumanoid(humanoid, true, true)
        end
        window._universalMovementState = nil
    end)
end

local function buildUniversalVisualsPage(window, tab)
    local controls = tab:CreateSection({
        Name = "Player ESP",
        Description = "Universal player ESP migrated from the Tower foundation and extended with tracers.",
        Side = "Left",
    })
    local appearance = tab:CreateSection({
        Name = "ESP Appearance",
        Description = "Shared text, distance and drawing options.",
        Side = "Right",
    })
    local colors = tab:CreateSection({
        Name = "ESP Colors",
        Description = "Universal ESP colors.",
        Side = "Right",
    })

    local ESP = {
        Features = {},
        IgnoreTeammates = false,
        MaxDistance = 5000,
        HealthBarPosition = "Above Player",
        NameMode = "Username",
        TextSize = 16,
        TextHeight = 3,
        NameOutline = true,
        TracerOrigin = "Bottom",
        TracerThickness = 1,

        Colors = {
            Name = Color3.fromRGB(255,255,255),
            Outline = Color3.fromRGB(0,0,0),
            HealthLow = Color3.fromRGB(255,50,50),
            HealthHigh = Color3.fromRGB(75,255,120),
            ChamsHigh = Color3.fromRGB(75,255,120),
            ChamsMid = Color3.fromRGB(255,220,70),
            ChamsLow = Color3.fromRGB(255,70,70),
            ChamsOutline = Color3.fromRGB(255,255,255),
            Skeleton = Color3.fromRGB(255,255,255),
            Box = Color3.fromRGB(255,255,255),
            Tracer = Color3.fromRGB(255,255,255),
        },

        PlayerData = {},
        DrawingSupported = type(Drawing) == "table" and type(Drawing.new) == "function",

        SkeletonR15 = {
            {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
            {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
            {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
            {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
            {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
        },
        SkeletonR6 = {
            {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
        },
    }
    window._universalESP = ESP

    local function feature(name)
        return ESP.Features[name] == true
    end

    local function removeDrawing(object)
        if not object then return end
        pcall(function()
            object.Visible = false
            object:Remove()
        end)
    end

    local function newLine()
        if not ESP.DrawingSupported then return nil end
        local ok, line = pcall(Drawing.new, "Line")
        if not ok then return nil end
        line.Visible = false
        line.Thickness = 1
        line.Transparency = 1
        return line
    end

    local function destroyPlayerData(plr)
        local data = ESP.PlayerData[plr]
        if not data then return end

        for _, object in ipairs({data.Billboard, data.HealthGui, data.Highlight}) do
            if object then pcall(function() object:Destroy() end) end
        end

        for _, line in ipairs(data.SkeletonLines or {}) do removeDrawing(line) end
        for _, line in ipairs(data.BoxLines or {}) do removeDrawing(line) end
        removeDrawing(data.TracerLine)

        ESP.PlayerData[plr] = nil
    end

    local function ensureData(plr)
        if not plr or plr == Players.LocalPlayer then return nil end
        local data = ESP.PlayerData[plr]
        if data then return data end

        data = {
            Player = plr,
            SkeletonLines = {},
            BoxLines = {},
        }
        ESP.PlayerData[plr] = data
        return data
    end

    local function allowed(plr, root)
        if not plr or plr == Players.LocalPlayer or not root then return false end
        if ESP.IgnoreTeammates and Players.LocalPlayer
            and Players.LocalPlayer.Team ~= nil
            and plr.Team == Players.LocalPlayer.Team then
            return false
        end

        local localRoot = Players.LocalPlayer
            and Players.LocalPlayer.Character
            and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        if localRoot and (root.Position - localRoot.Position).Magnitude > ESP.MaxDistance then
            return false
        end

        return true
    end

    local function playerDisplayName(plr)
        if ESP.NameMode == "Display Name" then
            return plr.DisplayName
        elseif ESP.NameMode == "Display + Username" and plr.DisplayName ~= plr.Name then
            return plr.DisplayName .. " (@" .. plr.Name .. ")"
        end
        return plr.Name
    end

    local function ensureBillboard(data, head)
        if data.Billboard and data.Billboard.Parent and data.Billboard.Adornee == head then
            return data.Billboard
        end
        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "VitalityUniversal_PlayerESP"
        billboard.AlwaysOnTop = true
        billboard.Adornee = head
        billboard.Size = UDim2.fromOffset(280, 52)
        billboard.StudsOffset = Vector3.new(0, ESP.TextHeight, 0)
        billboard.Parent = CoreGui

        local name = Instance.new("TextLabel")
        name.Name = "NameLabel"
        name.BackgroundTransparency = 1
        name.Size = UDim2.new(1,0,0,28)
        name.Position = UDim2.fromOffset(0,0)
        name.TextXAlignment = Enum.TextXAlignment.Center
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.Font = Enum.Font.GothamBold
        name.Parent = billboard

        local distance = Instance.new("TextLabel")
        distance.Name = "DistanceLabel"
        distance.BackgroundTransparency = 1
        distance.Size = UDim2.new(1,0,0,20)
        distance.Position = UDim2.fromOffset(0,26)
        distance.TextXAlignment = Enum.TextXAlignment.Center
        distance.TextYAlignment = Enum.TextYAlignment.Center
        distance.Font = Enum.Font.Gotham
        distance.Parent = billboard

        data.Billboard = billboard
        return billboard
    end

    local function ensureHealth(data, root, head)
        local target = ESP.HealthBarPosition == "Left of Player" and root or head
        if data.HealthGui and data.HealthGui.Parent and data.HealthGui.Adornee == target then
            return data.HealthGui
        end
        if data.HealthGui then pcall(function() data.HealthGui:Destroy() end) end

        local gui = Instance.new("BillboardGui")
        gui.Name = "VitalityUniversal_HealthESP"
        gui.AlwaysOnTop = true
        gui.Adornee = target
        gui.Parent = CoreGui

        local back = Instance.new("Frame")
        back.Name = "Back"
        back.BackgroundColor3 = Color3.fromRGB(0,0,0)
        back.BorderSizePixel = 0
        back.Parent = gui

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.BorderSizePixel = 0
        fill.Parent = back

        if ESP.HealthBarPosition == "Left of Player" then
            gui.Size = UDim2.fromOffset(8, 72)
            gui.StudsOffset = Vector3.new(-2.4, 0, 0)
            back.AnchorPoint = Vector2.new(0.5,0)
            back.Position = UDim2.new(0.5,0,0,0)
            back.Size = UDim2.new(0,4,1,0)
            fill.AnchorPoint = Vector2.new(0,1)
            fill.Position = UDim2.new(0,0,1,0)
            fill.Size = UDim2.new(1,0,1,0)
        else
            gui.Size = UDim2.fromOffset(84, 10)
            gui.StudsOffset = Vector3.new(0,2.65,0)
            back.Position = UDim2.new(0,2,0,2)
            back.Size = UDim2.new(1,-4,0,6)
            fill.AnchorPoint = Vector2.new(0,0)
            fill.Position = UDim2.fromOffset(0,0)
            fill.Size = UDim2.fromScale(1,1)
        end

        data.HealthGui = gui
        data.HealthBack = back
        data.HealthFill = fill
        return gui
    end

    local function ensureHighlight(data, character)
        if data.Highlight and data.Highlight.Parent == character then
            return data.Highlight
        end
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end

        local highlight = Instance.new("Highlight")
        highlight.Name = "VitalityUniversal_Chams"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.45
        highlight.OutlineTransparency = 0.05
        highlight.Adornee = character
        highlight.Parent = character
        data.Highlight = highlight
        return highlight
    end

    local function setLine(line, visible, from, to, color, thickness)
        if not line then return end
        line.Visible = visible == true
        if not visible then return end
        line.From = from
        line.To = to
        line.Color = color
        line.Thickness = thickness or 1
        line.Transparency = 1
    end

    local function hideDrawing(data)
        for _, line in ipairs(data.SkeletonLines or {}) do
            if line then line.Visible = false end
        end
        for _, line in ipairs(data.BoxLines or {}) do
            if line then line.Visible = false end
        end
        if data.TracerLine then data.TracerLine.Visible = false end
    end

    local function projectedBounds(character, camera)
        local ok, cframe, size = pcall(character.GetBoundingBox, character)
        if not ok then return nil end

        local half = size * 0.5
        local corners = {
            Vector3.new(-half.X,-half.Y,-half.Z), Vector3.new(-half.X,-half.Y,half.Z),
            Vector3.new(-half.X,half.Y,-half.Z), Vector3.new(-half.X,half.Y,half.Z),
            Vector3.new(half.X,-half.Y,-half.Z), Vector3.new(half.X,-half.Y,half.Z),
            Vector3.new(half.X,half.Y,-half.Z), Vector3.new(half.X,half.Y,half.Z),
        }

        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local any = false

        for _, offset in ipairs(corners) do
            local world = cframe:PointToWorldSpace(offset)
            local point = camera:WorldToViewportPoint(world)
            if point.Z > 0 then
                any = true
                minX = math.min(minX, point.X)
                minY = math.min(minY, point.Y)
                maxX = math.max(maxX, point.X)
                maxY = math.max(maxY, point.Y)
            end
        end

        if not any then return nil end
        return Vector2.new(minX,minY), Vector2.new(maxX,maxY)
    end

    local function updatePlayer(plr, data)
        local character = plr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local head = character and character:FindFirstChild("Head")
        local root = character and (
            character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
        )
        local camera = workspace.CurrentCamera

        if not character or not humanoid or humanoid.Health <= 0 or not head or not root or not camera or not allowed(plr, root) then
            if data.Billboard then data.Billboard.Enabled = false end
            if data.HealthGui then data.HealthGui.Enabled = false end
            if data.Highlight then data.Highlight.Enabled = false end
            hideDrawing(data)
            return
        end

        local localRoot = Players.LocalPlayer
            and Players.LocalPlayer.Character
            and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local distanceStuds = localRoot and math.floor((root.Position - localRoot.Position).Magnitude + 0.5) or 0
        local healthRatio = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0

        if feature("Name ESP") or feature("Distance ESP") then
            local billboard = ensureBillboard(data, head)
            billboard.Enabled = true
            billboard.StudsOffset = Vector3.new(0, ESP.TextHeight, 0)

            local nameLabel = billboard:FindFirstChild("NameLabel")
            local distanceLabel = billboard:FindFirstChild("DistanceLabel")

            if nameLabel then
                nameLabel.Visible = feature("Name ESP")
                nameLabel.Text = playerDisplayName(plr)
                nameLabel.TextColor3 = ESP.Colors.Name
                nameLabel.TextStrokeColor3 = ESP.Colors.Outline
                nameLabel.TextStrokeTransparency = ESP.NameOutline and 0 or 1
                nameLabel.TextSize = ESP.TextSize
            end

            if distanceLabel then
                distanceLabel.Visible = feature("Distance ESP")
                distanceLabel.Text = tostring(distanceStuds) .. " studs"
                distanceLabel.TextColor3 = ESP.Colors.Name
                distanceLabel.TextStrokeColor3 = ESP.Colors.Outline
                distanceLabel.TextStrokeTransparency = ESP.NameOutline and 0 or 1
                distanceLabel.TextSize = math.max(10, ESP.TextSize - 2)
            end
        elseif data.Billboard then
            data.Billboard.Enabled = false
        end

        if feature("Health Bar ESP") then
            ensureHealth(data, root, head)
            if data.HealthGui and data.HealthFill then
                data.HealthGui.Enabled = true
                data.HealthFill.BackgroundColor3 = ESP.Colors.HealthLow:Lerp(ESP.Colors.HealthHigh, healthRatio)
                if ESP.HealthBarPosition == "Left of Player" then
                    data.HealthFill.Size = UDim2.new(1,0,healthRatio,0)
                else
                    data.HealthFill.Size = UDim2.new(healthRatio,0,1,0)
                end
            end
        elseif data.HealthGui then
            data.HealthGui.Enabled = false
        end

        if feature("Health Chams") then
            local highlight = ensureHighlight(data, character)
            highlight.Enabled = true
            highlight.OutlineColor = ESP.Colors.ChamsOutline
            if healthRatio > 0.66 then
                highlight.FillColor = ESP.Colors.ChamsHigh
            elseif healthRatio > 0.33 then
                highlight.FillColor = ESP.Colors.ChamsMid
            else
                highlight.FillColor = ESP.Colors.ChamsLow
            end
        elseif data.Highlight then
            data.Highlight.Enabled = false
        end

        if not ESP.DrawingSupported then
            hideDrawing(data)
            return
        end

        local rootPoint = camera:WorldToViewportPoint(root.Position)
        local rootVisible = rootPoint.Z > 0

        if feature("Skeleton ESP") and rootVisible then
            local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and ESP.SkeletonR6 or ESP.SkeletonR15
            while #data.SkeletonLines < #bones do
                table.insert(data.SkeletonLines, newLine())
            end
            for index, pair in ipairs(bones) do
                local a, b = character:FindFirstChild(pair[1]), character:FindFirstChild(pair[2])
                local line = data.SkeletonLines[index]
                if a and b and line then
                    local p1 = camera:WorldToViewportPoint(a.Position)
                    local p2 = camera:WorldToViewportPoint(b.Position)
                    setLine(
                        line,
                        p1.Z > 0 and p2.Z > 0,
                        Vector2.new(p1.X,p1.Y),
                        Vector2.new(p2.X,p2.Y),
                        ESP.Colors.Skeleton,
                        1
                    )
                elseif line then
                    line.Visible = false
                end
            end
        else
            for _, line in ipairs(data.SkeletonLines) do
                if line then line.Visible = false end
            end
        end

        if feature("Bounding Box ESP") and rootVisible then
            while #data.BoxLines < 4 do table.insert(data.BoxLines, newLine()) end
            local minimum, maximum = projectedBounds(character, camera)
            if minimum and maximum then
                local tl = Vector2.new(minimum.X, minimum.Y)
                local tr = Vector2.new(maximum.X, minimum.Y)
                local br = Vector2.new(maximum.X, maximum.Y)
                local bl = Vector2.new(minimum.X, maximum.Y)
                local points = {{tl,tr},{tr,br},{br,bl},{bl,tl}}
                for index, pair in ipairs(points) do
                    setLine(data.BoxLines[index], true, pair[1], pair[2], ESP.Colors.Box, 1)
                end
            else
                for _, line in ipairs(data.BoxLines) do if line then line.Visible = false end end
            end
        else
            for _, line in ipairs(data.BoxLines) do if line then line.Visible = false end end
        end

        if feature("Tracers") and rootVisible then
            data.TracerLine = data.TracerLine or newLine()
            local viewport = camera.ViewportSize
            local origin
            if ESP.TracerOrigin == "Center" then
                origin = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
            elseif ESP.TracerOrigin == "Mouse" then
                local mouse = UserInputService:GetMouseLocation()
                origin = Vector2.new(mouse.X, mouse.Y)
            else
                origin = Vector2.new(viewport.X * 0.5, viewport.Y - 2)
            end
            setLine(
                data.TracerLine,
                true,
                origin,
                Vector2.new(rootPoint.X, rootPoint.Y),
                ESP.Colors.Tracer,
                ESP.TracerThickness
            )
        elseif data.TracerLine then
            data.TracerLine.Visible = false
        end
    end

    local function refreshAll()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Players.LocalPlayer then
                ensureData(plr)
            end
        end
        for plr in pairs(ESP.PlayerData) do
            if plr.Parent ~= Players then destroyPlayerData(plr) end
        end
    end

    controls:CreateDropdown({
        Name = "ESP Features",
        Info = "Select any combination of universal player ESP features.",
        Flag = "Universal_ESP_Features",
        Options = {
            "Name ESP",
            "Distance ESP",
            "Health Bar ESP",
            "Health Chams",
            "Skeleton ESP",
            "Bounding Box ESP",
            "Tracers",
        },
        CurrentOption = {},
        MultiSelection = true,
        Callback = function(selection)
            local selected = {}
            if type(selection) == "table" then
                for _, value in pairs(selection) do selected[tostring(value)] = true end
            elseif selection then
                selected[tostring(selection)] = true
            end
            ESP.Features = selected
            refreshAll()
        end,
    })

    controls:CreateToggle({
        Name = "Ignore Teammates",
        Info = "Hides ESP for players on your current Roblox team.",
        Flag = "Universal_ESP_IgnoreTeammates",
        CurrentValue = false,
        Callback = function(value) ESP.IgnoreTeammates = value == true end,
    })

    controls:CreateSlider({
        Name = "Maximum Distance",
        Flag = "Universal_ESP_MaxDistance",
        Range = {100, 10000},
        Increment = 100,
        Suffix = " studs",
        CurrentValue = 5000,
        Callback = function(value) ESP.MaxDistance = tonumber(value) or 5000 end,
    })

    controls:CreateDropdown({
        Name = "Health Bar Position",
        Flag = "Universal_ESP_HealthBarPosition",
        Options = {"Above Player", "Left of Player"},
        CurrentOption = "Above Player",
        Callback = function(value)
            if type(value) == "table" then value = value[1] end
            ESP.HealthBarPosition = tostring(value or "Above Player")
            for _, data in pairs(ESP.PlayerData) do
                if data.HealthGui then
                    pcall(function() data.HealthGui:Destroy() end)
                    data.HealthGui = nil
                    data.HealthBack = nil
                    data.HealthFill = nil
                end
            end
        end,
    })

    appearance:CreateDropdown({
        Name = "Name Format",
        Flag = "Universal_ESP_NameFormat",
        Options = {"Username", "Display Name", "Display + Username"},
        CurrentOption = "Username",
        Callback = function(value)
            if type(value) == "table" then value = value[1] end
            ESP.NameMode = tostring(value or "Username")
        end,
    })

    appearance:CreateToggle({
        Name = "Name Outline",
        Flag = "Universal_ESP_NameOutline",
        CurrentValue = true,
        Callback = function(value) ESP.NameOutline = value == true end,
    })

    appearance:CreateSlider({
        Name = "Text Size",
        Flag = "Universal_ESP_TextSize",
        Range = {10, 32},
        Increment = 1,
        Suffix = "px",
        CurrentValue = 16,
        Callback = function(value) ESP.TextSize = tonumber(value) or 16 end,
    })

    appearance:CreateSlider({
        Name = "Text Height",
        Flag = "Universal_ESP_TextHeight",
        Range = {1, 8},
        Increment = 0.25,
        Suffix = " studs",
        CurrentValue = 3,
        Callback = function(value) ESP.TextHeight = tonumber(value) or 3 end,
    })

    appearance:CreateDropdown({
        Name = "Tracer Origin",
        Flag = "Universal_ESP_TracerOrigin",
        Options = {"Bottom", "Center", "Mouse"},
        CurrentOption = "Bottom",
        Callback = function(value)
            if type(value) == "table" then value = value[1] end
            ESP.TracerOrigin = tostring(value or "Bottom")
        end,
    })

    appearance:CreateSlider({
        Name = "Tracer Thickness",
        Flag = "Universal_ESP_TracerThickness",
        Range = {1, 4},
        Increment = 0.5,
        CurrentValue = 1,
        Callback = function(value) ESP.TracerThickness = tonumber(value) or 1 end,
    })

    if not ESP.DrawingSupported then
        appearance:CreateParagraph({
            Title = "Drawing API unavailable",
            Content = "Skeleton, bounding boxes and tracers require an executor with Drawing.new support. Name, distance, health bars and chams still work.",
        })
    end

    local colorDefinitions = {
        {"Name", "Name Text", ESP.Colors.Name},
        {"Outline", "Name Outline", ESP.Colors.Outline},
        {"HealthLow", "Health Low", ESP.Colors.HealthLow},
        {"HealthHigh", "Health High", ESP.Colors.HealthHigh},
        {"ChamsHigh", "Chams High Health", ESP.Colors.ChamsHigh},
        {"ChamsMid", "Chams Mid Health", ESP.Colors.ChamsMid},
        {"ChamsLow", "Chams Low Health", ESP.Colors.ChamsLow},
        {"ChamsOutline", "Chams Outline", ESP.Colors.ChamsOutline},
        {"Skeleton", "Skeleton", ESP.Colors.Skeleton},
        {"Box", "Bounding Box", ESP.Colors.Box},
        {"Tracer", "Tracer", ESP.Colors.Tracer},
    }
    for _, definition in ipairs(colorDefinitions) do
        colors:CreateColorPicker({
            Name = definition[2],
            Flag = "Universal_ESP_Color_" .. definition[1],
            Color = definition[3],
            Callback = function(color)
                ESP.Colors[definition[1]] = color
            end,
        })
    end

    refreshAll()

    window:TrackConnection(Players.PlayerAdded:Connect(function(plr)
        if plr ~= Players.LocalPlayer then ensureData(plr) end
    end))
    window:TrackConnection(Players.PlayerRemoving:Connect(function(plr)
        destroyPlayerData(plr)
    end))
    window:TrackConnection(RunService.RenderStepped:Connect(function()
        for plr, data in pairs(ESP.PlayerData) do
            updatePlayer(plr, data)
        end
    end))

    window:AddCleanup(function()
        for plr in pairs(ESP.PlayerData) do
            destroyPlayerData(plr)
        end
        window._universalESP = nil
    end)
end

local function buildUniversalUtilitiesPage(window, tab)
    local scriptSection = tab:CreateSection({
        Name = "Script Utilities",
        Description = "Common external utility loaders.",
        Side = "Left",
    })
    local sessionSection = tab:CreateSection({
        Name = "Session Utilities",
        Description = "Generic quality-of-life tools shared by every module.",
        Side = "Left",
    })
    local playerSection = tab:CreateSection({
        Name = "Player Utilities",
        Description = "Cursor, shift-lock and player tools moved out of game-specific modules.",
        Side = "Right",
    })
    local teleportSection = tab:CreateSection({
        Name = "Player Teleport",
        Description = "Teleport your local character beside another player.",
        Side = "Right",
    })

    local function runRemoteScript(name, url)
        task.spawn(function()
            local ok, result = pcall(function()
                local source = game:HttpGet(url, true)
                local chunk, compileError = loadstring(source)
                if not chunk then error(compileError or "compile failed") end
                return chunk()
            end)
            if ok then
                universalNotify(window, name, name .. " loaded.", "Success")
            else
                universalNotify(window, name, "Load failed: " .. tostring(result), "Error")
            end
        end)
    end

    scriptSection:CreateButton({
        Name = "Load Infinite Yield",
        Info = "Loads the official EdgeIY Infinite Yield source.",
        Callback = function()
            runRemoteScript(
                "Infinite Yield",
                "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
            )
        end,
    })

    scriptSection:CreateButton({
        Name = "Load Cobalt",
        Info = "Loads the latest Cobalt release from the official GitLab release permalink.",
        Callback = function()
            runRemoteScript(
                "Cobalt",
                "https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau"
            )
        end,
    })

    local antiAfkEnabled = false
    local virtualUser
    pcall(function() virtualUser = game:GetService("VirtualUser") end)

    sessionSection:CreateToggle({
        Name = "Anti-AFK",
        Info = "Generic Roblox Idled anti-AFK. Tower keeps its separate game-specific anti-AFK in Character.",
        Flag = "Universal_AntiAFK",
        CurrentValue = false,
        Callback = function(value)
            antiAfkEnabled = value == true
        end,
    })

    if Players.LocalPlayer then
        window:TrackConnection(Players.LocalPlayer.Idled:Connect(function()
            if not antiAfkEnabled or not virtualUser then return end
            pcall(function()
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.new(0,0))
            end)
        end))
    end

    sessionSection:CreateButton({
        Name = "Rejoin Server",
        Callback = function()
            pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(
                    game.PlaceId,
                    game.JobId,
                    Players.LocalPlayer
                )
            end)
        end,
    })

    sessionSection:CreateButton({
        Name = "Copy Job ID",
        Callback = function()
            local copied = false
            if type(setclipboard) == "function" then
                copied = pcall(setclipboard, tostring(game.JobId))
            elseif type(toclipboard) == "function" then
                copied = pcall(toclipboard, tostring(game.JobId))
            end
            universalNotify(
                window,
                "Job ID",
                copied and "Copied current JobId." or ("JobId: " .. tostring(game.JobId)),
                copied and "Success" or "Information"
            )
        end,
    })

    local cursorState = {
        Enabled = false,
        KeyName = "T",
        PreviousBehavior = UserInputService.MouseBehavior,
        PreviousIcon = UserInputService.MouseIconEnabled,
        RenderName = "VitalityUniversalCursor_" .. HttpService:GenerateGUID(false),
    }

    local function setCursorUnlocked(enabled)
        cursorState.Enabled = enabled == true
        pcall(function() RunService:UnbindFromRenderStep(cursorState.RenderName) end)

        if cursorState.Enabled then
            cursorState.PreviousBehavior = UserInputService.MouseBehavior
            cursorState.PreviousIcon = UserInputService.MouseIconEnabled

            pcall(function()
                RunService:BindToRenderStep(
                    cursorState.RenderName,
                    Enum.RenderPriority.Camera.Value + 1,
                    function()
                        if cursorState.Enabled then
                            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                            UserInputService.MouseIconEnabled = true
                        end
                    end
                )
            end)
        else
            pcall(function()
                UserInputService.MouseBehavior = cursorState.PreviousBehavior
                UserInputService.MouseIconEnabled = cursorState.PreviousIcon
            end)
        end
    end

    local cursorToggle = playerSection:CreateToggle({
        Name = "Unlock Cursor",
        Info = "Keeps the cursor free until toggled off. The hotkey below can be changed.",
        Flag = "Universal_UnlockCursor",
        CurrentValue = false,
        Callback = function(value) setCursorUnlocked(value) end,
    })

    playerSection:CreateKeybind({
        Name = "Unlock Cursor Hotkey",
        Info = "Hotkey used to toggle Unlock Cursor.",
        Flag = "Universal_UnlockCursorHotkey",
        CurrentKeybind = "T",
        Callback = function(keyName)
            cursorState.KeyName = tostring(keyName or "T")
        end,
    })

    local contextActionService = game:GetService("ContextActionService")
    local shiftlockAction = "VitalityUniversalNoShift_" .. HttpService:GenerateGUID(false)
    local noShiftlock = false

    local function applyNoShiftlock(enabled)
        noShiftlock = enabled == true
        pcall(function() contextActionService:UnbindAction(shiftlockAction) end)

        if noShiftlock then
            contextActionService:BindActionAtPriority(
                shiftlockAction,
                function(_, inputState)
                    if inputState == Enum.UserInputState.Begin
                        or inputState == Enum.UserInputState.Change
                        or inputState == Enum.UserInputState.End then
                        return Enum.ContextActionResult.Sink
                    end
                    return Enum.ContextActionResult.Pass
                end,
                false,
                Enum.ContextActionPriority.High.Value + 100,
                Enum.KeyCode.LeftShift,
                Enum.KeyCode.RightShift
            )
        end
    end

    playerSection:CreateToggle({
        Name = "No Shiftlock",
        Info = "Blocks Shift-based shiftlock and releases the mouse from center-lock while enabled.",
        Flag = "Universal_NoShiftlock",
        CurrentValue = false,
        Callback = function(value) applyNoShiftlock(value) end,
    })

    window:TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() or window._capturingKeybind then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode.Name == cursorState.KeyName and cursorToggle and type(cursorToggle.Set) == "function" then
            cursorToggle:Set(not cursorState.Enabled)
        end
    end))

    window:TrackConnection(RunService.RenderStepped:Connect(function()
        if noShiftlock and not cursorState.Enabled then
            pcall(function()
                if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                end
                local humanoid = universalCurrentHumanoid()
                if humanoid then humanoid.AutoRotate = true end
            end)
        end
    end))

    local selectedPlayer
    local playerDropdown

    local function playerNames()
        local names = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Players.LocalPlayer then table.insert(names, plr.Name) end
        end
        table.sort(names)
        if #names == 0 then table.insert(names, "No players") end
        return names
    end

    local function setSelected(value)
        if type(value) == "table" then value = value[1] end
        selectedPlayer = Players:FindFirstChild(tostring(value or ""))
    end

    playerDropdown = teleportSection:CreateDropdown({
        Name = "Select Player",
        Flag = "Universal_PlayerTeleportTarget",
        Options = playerNames(),
        CurrentOption = playerNames()[1],
        Callback = setSelected,
    })
    setSelected(playerDropdown and playerDropdown.Get and playerDropdown:Get() or nil)

    local function refreshPlayers()
        local names = playerNames()
        if playerDropdown and type(playerDropdown.Refresh) == "function" then
            pcall(function() playerDropdown:Refresh(names, true) end)
        end
        if not selectedPlayer or selectedPlayer.Parent ~= Players then
            selectedPlayer = Players:FindFirstChild(names[1])
        end
    end

    teleportSection:CreateButton({
        Name = "Teleport To Player",
        Callback = function()
            local target = selectedPlayer
            local targetRoot = target and target.Character and (
                target.Character:FindFirstChild("HumanoidRootPart")
                or target.Character:FindFirstChild("UpperTorso")
                or target.Character:FindFirstChild("Torso")
            )
            local character = Players.LocalPlayer and Players.LocalPlayer.Character
            if not targetRoot or not character then
                universalNotify(window, "Player Teleport", "Selected player is unavailable.", "Warning")
                return
            end

            pcall(function()
                character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 3))
            end)
        end,
    })

    window:TrackConnection(Players.PlayerAdded:Connect(function() task.defer(refreshPlayers) end))
    window:TrackConnection(Players.PlayerRemoving:Connect(function(plr)
        if selectedPlayer == plr then selectedPlayer = nil end
        task.defer(refreshPlayers)
    end))

    window:AddCleanup(function()
        antiAfkEnabled = false
        setCursorUnlocked(false)
        pcall(function() contextActionService:UnbindAction(shiftlockAction) end)
    end)
end

function WindowMethods:_ensureUniversalTabDropdown()
    if self.UniversalTabDropdown and self.UniversalTabDropdown._destroyed ~= true then
        return self.UniversalTabDropdown
    end

    -- Negative layout order pins Universal above Owner/game module tabs, directly
    -- beneath the fixed Favorites shortcut.
    local universal = self:CreateTabDropdown({
        Name = "Universal",
        Icon = "diamond",
        Expanded = false,
        LayoutOrder = -1000,
    })

    local playerTab = universal:CreateTab("Player", "user")
    buildUniversalPlayerPage(self, playerTab)

    local visualsTab = universal:CreateTab("Visuals", "eye")
    buildUniversalVisualsPage(self, visualsTab)

    local utilitiesTab = universal:CreateTab("Utilities", "settings")
    buildUniversalUtilitiesPage(self, utilitiesTab)

    -- Controls read saved values when they are constructed, but ordinary control
    -- constructors intentionally do not fire callbacks. Re-apply only Universal
    -- flags once so saved ON states actually restore their backing feature state.
    task.defer(function()
        if self._destroyed then return end
        for flag, object in pairs(self.FlagObjects or {}) do
            if tostring(flag):match("^Universal_")
                and type(object) == "table"
                and type(object.Get) == "function"
                and type(object.Set) == "function" then

                pcall(function()
                    object:Set(object:Get(), true)
                end)
            end
        end
    end)

    self.UniversalTabDropdown = universal
    return universal
end


-- Development/hot-reload support: tabs can now be removed cleanly without
-- destroying the main Vitality window. This is also safe for ordinary tabs.
function TabMethods:Destroy()
    if self._destroyed then return false end
    self._destroyed = true

    local window = self.Window
    if window and type(window._controlIndex) == "table" then
        for index = #window._controlIndex, 1, -1 do
            local entry = window._controlIndex[index]
            if entry and entry.Tab == self then
                table.remove(window._controlIndex, index)
            end
        end
    end

    if window and type(window.Tabs) == "table" then
        for index = #window.Tabs, 1, -1 do
            if window.Tabs[index] == self then
                table.remove(window.Tabs, index)
                break
            end
        end
    end

    local dropdown = self._navDropdown
    if dropdown and type(dropdown.Tabs) == "table" then
        for index = #dropdown.Tabs, 1, -1 do
            if dropdown.Tabs[index] == self then
                table.remove(dropdown.Tabs, index)
                break
            end
        end
    end

    if self.PageClip and self.PageClip.Parent then
        pcall(function() self.PageClip:Destroy() end)
    elseif self.Page and self.Page.Parent then
        pcall(function() self.Page:Destroy() end)
    end

    if self.NavButton and self.NavButton.Parent then
        pcall(function() self.NavButton:Destroy() end)
    end

    self.Sections = {}
    self.Page = nil
    self.PageClip = nil
    self.NavButton = nil

    if window and window.ActiveTab == self then
        window.ActiveTab = nil
        local replacement = window.Tabs and window.Tabs[1]
        if replacement then
            window:_setActiveTab(replacement)
        elseif type(window._refreshTabStyles) == "function" then
            window:_refreshTabStyles()
        end
    elseif window and type(window._refreshTabStyles) == "function" then
        window:_refreshTabStyles()
    end

    if dropdown and dropdown._destroyed ~= true then
        dropdown:_refreshVisual()
    end

    return true
end

function WindowMethods:FindTab(name)
    local wanted = tostring(name or ""):lower()
    if wanted == "" then return nil end
    for _, tab in ipairs(self.Tabs or {}) do
        if tostring(tab.Name or ""):lower() == wanted and tab._destroyed ~= true then
            return tab
        end
    end
    return nil
end

function WindowMethods:RemoveTab(tabOrName)
    local tab = tabOrName
    if type(tabOrName) == "string" then
        tab = self:FindTab(tabOrName)
    end
    if type(tab) ~= "table" or type(tab.Destroy) ~= "function" then
        return false
    end
    return tab:Destroy()
end

function TabMethods:CreateSection(name, subtitleOrTitleOnly, column)
    local section = setmetatable({}, SectionMethods)
    section.Tab = self
    section.Locked = false

    local sectionData
    if type(name) == "table" then
        sectionData = name
        section.Name = sectionData.Name or sectionData.Title or "SECTION"
    else
        sectionData = {}
        section.Name = name or "SECTION"
    end

    local titleOnly = sectionData.TitleOnly == true
    local subtitle = sectionData.Description or sectionData.Info
    if type(name) ~= "table" then
        if type(subtitleOrTitleOnly) == "boolean" then
            titleOnly = subtitleOrTitleOnly
        elseif type(subtitleOrTitleOnly) == "string" then
            subtitle = subtitleOrTitleOnly
        end
    end

    local requestedColumn = sectionData.Column or sectionData.Side or column
    local columnIndex
    if type(requestedColumn) == "string" then
        local side = requestedColumn:lower()
        columnIndex = side == "right" and 2 or (side == "left" and 1 or nil)
    else
        columnIndex = tonumber(requestedColumn)
    end

    if columnIndex ~= 1 and columnIndex ~= 2 then
        columnIndex = self._nextColumn
        self._nextColumn = self._nextColumn == 1 and 2 or 1
    end

    local card = create("Frame", {
        Parent = self.Columns[columnIndex],
        BackgroundColor3 = Theme.Surface2,
        Size = UDim2.new(1, 0, 0, 88),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    corner(card, UIStyle.CardRadius)
    stroke(card, Theme.Border, 1, 0.46)
    applySoftSurfaceGradient(card, self.Window, "Surface3", "Surface2", 118)

    local hasIcon = sectionData.Icon ~= nil
    local headerHeight
    if subtitle and tostring(subtitle) ~= "" then
        headerHeight = UIStyle.HeaderHeightWithSubtitle
    else
        subtitle = nil
        headerHeight = UIStyle.HeaderHeight
    end

    local header = create("Frame", {
        Parent = card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, headerHeight),
    })

    local icon
    local iconHolder
    local headingX = UIStyle.CardInset

    if hasIcon then
        iconHolder = create("Frame", {
            Parent = header,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, UIStyle.CardInset, 0.5, -1),
            Size = UDim2.fromOffset(UIStyle.HeaderIconSize, UIStyle.HeaderIconSize),
            BackgroundColor3 = Theme.Surface3,
            BorderSizePixel = 0,
        })
        corner(iconHolder, UIStyle.HeaderIconRadius)
        stroke(iconHolder, Theme.Border, 1, 0.50)
        applyThemeGradient(iconHolder, self.Window, "icon", 0.30)

        icon = createIcon(iconHolder, sectionData.Icon, "info")
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        icon.Size = UDim2.fromOffset(23, 23)
        setIconColor(icon, Theme.AccentVisible)
        headingX = UIStyle.CardInset + UIStyle.HeaderIconSize + 10
    end

    local heading = makeText(header, section.Name, UIStyle.SectionTitleSize, Theme.Text, Enum.Font.GothamSemibold)
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.TextWrapped = true

    if subtitle then
        heading.Position = UDim2.fromOffset(headingX, hasIcon and 17 or 14)
        heading.Size = UDim2.new(1, -(headingX + UIStyle.CardInset), 0, 26)
    else
        heading.AnchorPoint = Vector2.new(0, 0.5)
        heading.Position = UDim2.new(0, headingX, 0.5, -1)
        heading.Size = UDim2.new(1, -(headingX + UIStyle.CardInset), 0, 30)
    end

    local sub
    if subtitle then
        sub = makeText(header, subtitle, UIStyle.SectionSubtitleSize, Theme.Muted, Enum.Font.Gotham)
        sub.Position = UDim2.fromOffset(headingX, hasIcon and 43 or 40)
        sub.Size = UDim2.new(1, -(headingX + UIStyle.CardInset), 0, 28)
        sub.TextWrapped = true
        sub.TextYAlignment = Enum.TextYAlignment.Top
    end

    create("Frame", {
        Parent = header,
        BackgroundColor3 = Theme.BorderSoft,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Position = UDim2.new(0, UIStyle.CardInset, 1, -1),
        Size = UDim2.new(1, -(UIStyle.CardInset * 2), 0, 1),
    })

    local body = create("Frame", {
        Parent = card,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, headerHeight),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    local bodyLayout = create("UIListLayout", {
        Parent = body,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })
    padding(body, 0, 0, 2, 8)

    local headerQueued = false
    local function resizeHeader()
        if headerQueued then return end
        headerQueued = true
        task.defer(function()
            headerQueued = false
            if not card.Parent then return end
            local width = card.AbsoluteSize.X / logicalScale(card) - headingX - UIStyle.CardInset
            if width <= 1 then return end
            local headingHeight = math.ceil(textSize(heading, width).Y) + 2
            local subtitleHeight = sub and math.ceil(textSize(sub, width).Y * 1.08) + 2 or 0
            local textHeight = headingHeight + (sub and (5 + subtitleHeight) or 0)
            headerHeight = math.max(hasIcon and (UIStyle.HeaderIconSize + 28) or UIStyle.HeaderHeight, textHeight + 28)
            header.Size = UDim2.new(1, 0, 0, headerHeight)
            heading.AnchorPoint = Vector2.new(0, 0)
            heading.Position = UDim2.fromOffset(headingX, (headerHeight - textHeight) / 2)
            heading.Size = UDim2.fromOffset(width, headingHeight)
            heading.TextYAlignment = Enum.TextYAlignment.Top
            if sub then
                sub.Position = UDim2.fromOffset(headingX, (headerHeight - textHeight) / 2 + headingHeight + 5)
                sub.Size = UDim2.fromOffset(width, subtitleHeight)
                sub.LineHeight = 1.08
            end
            body.Position = UDim2.fromOffset(0, headerHeight)
        end)
    end
    card:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeHeader)
    heading:GetPropertyChangedSignal("Font"):Connect(resizeHeader)
    heading:GetPropertyChangedSignal("Text"):Connect(resizeHeader)
    if sub then sub:GetPropertyChangedSignal("Font"):Connect(resizeHeader) end
    resizeHeader()
    section.Frame = card
    section.Header = header
    section.Body = body
    section.Layout = bodyLayout
    section.TitleOnly = titleOnly
    section.Column = columnIndex
    section.Description = subtitle
    section.Icon = icon
    section.IconHolder = iconHolder

    bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.defer(function() if self._recalc then self._recalc() end end)
    end)

    table.insert(self.Sections, section)
    self._currentSection = section
    task.defer(function()
        if self._recalc then self._recalc() end
    end)
    return section
end

function TabMethods:_sectionFrom(data)
    if type(data) == "table" and data.SectionParent and getmetatable(data.SectionParent) == SectionMethods then
        return data.SectionParent
    end
    if self._currentSection then return self._currentSection end
    return self:CreateSection("GENERAL", "Common interface elements.", 1)
end

function SectionMethods:_row(height, noDivider)
    self._rowCount = (self._rowCount or 0) + 1
    local requested = tonumber(height)
    local baseHeight = requested or UIStyle.RowMinHeight
    if requested == nil then
        baseHeight = UIStyle.RowMinHeight
    elseif requested > 0 then
        baseHeight = math.max(requested, noDivider and 1 or UIStyle.RowMinHeight)
    else
        baseHeight = 1
    end

    local row = create("Frame", {
        Parent = self.Body,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, baseHeight),
        ClipsDescendants = true,
    })
    row.LayoutOrder = self._rowCount
    row:SetAttribute("NovaRowBaseHeight", baseHeight)

    if not noDivider then
        create("Frame", {
            Parent = row,
            BackgroundColor3 = Theme.BorderSoft,
            BackgroundTransparency = 0.50,
            BorderSizePixel = 0,
            Position = UDim2.new(0, UIStyle.DividerInset, 1, -1),
            Size = UDim2.new(1, -(UIStyle.DividerInset * 2), 0, 1),
        })
    end
    return row
end

local rowLayouts = setmetatable({}, {__mode = "k"})

local function rowText(row, name, info, rightWidth)
    local textArea = create("Frame", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(UIStyle.RowInset, UIStyle.RowVerticalPadding),
        Size = UDim2.new(1, -UIStyle.RowInset * 2, 0, 20),
    })
    local label = makeText(textArea, name or "Control", UIStyle.LabelSize, Theme.Text, Enum.Font.GothamMedium)
    label.TextWrapped, label.TextYAlignment = true, Enum.TextYAlignment.Top
    local description
    if info and tostring(info) ~= "" then
        description = makeText(textArea, tostring(info), UIStyle.InfoSize, Theme.Muted, Enum.Font.Gotham)
        description.TextWrapped, description.TextYAlignment = true, Enum.TextYAlignment.Top
        description.LineHeight = 1.08
    end
    local state = {Width = rightWidth or UIStyle.FieldWidth, TextArea = textArea, Label = label}
    local queued = false
    local function refresh()
        if queued then return end
        queued = true
        task.defer(function()
            queued = false
            if not row.Parent then return end
            local width = row.AbsoluteSize.X / logicalScale(row)
            if width <= 1 then return end
            local available = math.max(1, width - UIStyle.RowInset * 2)
            local control = state.Control
            local options = state.Options or {}
            local desired = options.Width or state.Width
            if options.MeasureText and control then
                desired = math.max(desired, textSize(control, 10000).X + 28)
            end
            local minimum = math.max(UIStyle.MinimumLabelWidth, math.min(textSize(label, 10000).X, 230))
            local stacked = options.Stacked == true or available - desired - UIStyle.RowGap < minimum
            local fieldWidth = math.min(desired, available)
            if stacked and options.Fill ~= false then fieldWidth = available end
            local labelWidth = stacked and available or math.max(1, available - fieldWidth - UIStyle.RowGap)
            local titleWidth = math.max(1, labelWidth - (state.FavoriteSpace or 0))
            local labelHeight = math.max(state.FavoriteSpace and 22 or 0, math.ceil(textSize(label, titleWidth).Y) + 2)
            local infoHeight = description and math.ceil(textSize(description, labelWidth).Y * 1.08) + 2 or 0
            local textHeight = labelHeight + (description and (5 + infoHeight) or 0)
            textArea.Size = UDim2.fromOffset(labelWidth, textHeight)
            label.Size = UDim2.fromOffset(titleWidth, labelHeight)
            if description then
                description.Position = UDim2.fromOffset(0, labelHeight + 5)
                description.Size = UDim2.fromOffset(labelWidth, infoHeight)
            end
            local controlHeight = options.Height or (control and control.Size.Y.Offset) or UIStyle.ControlHeight
            local extra = options.ExtraHeight or 0
            local contentHeight = stacked and (textHeight + UIStyle.RowGap + controlHeight + extra) or math.max(textHeight, controlHeight + extra)
            local height = math.max(row:GetAttribute("NovaRowBaseHeight") or UIStyle.RowMinHeight, contentHeight + UIStyle.RowVerticalPadding * 2)
            row.Size = UDim2.new(1, 0, 0, height)
            textArea.Position = UDim2.fromOffset(UIStyle.RowInset, stacked and UIStyle.RowVerticalPadding or (height - textHeight) / 2)
            if control then
                control.AnchorPoint = Vector2.new(1, 0)
                control.Position = UDim2.new(1, -UIStyle.RowInset, 0, stacked and (UIStyle.RowVerticalPadding + textHeight + UIStyle.RowGap) or (height - controlHeight - extra) / 2)
                control.Size = UDim2.fromOffset(fieldWidth, controlHeight)
            end
        end)
    end
    state.Refresh = refresh
    rowLayouts[row] = state
    row:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
    for _, item in ipairs(description and {label, description} or {label}) do
        for _, property in ipairs({"Text", "Font", "TextSize"}) do item:GetPropertyChangedSignal(property):Connect(refresh) end
    end
    refresh()
    return label, description, textArea
end

local function attachRowControl(row, control, options)
    local state = rowLayouts[row]
    if not state then return end
    state.Control, state.Options = control, options or {}
    if control:IsA("TextButton") or control:IsA("TextBox") then
        control:GetPropertyChangedSignal("Text"):Connect(state.Refresh)
        control:GetPropertyChangedSignal("Font"):Connect(state.Refresh)
    end
    state.Refresh()
end

local function makeLockable(control, setLockedVisual)
    control.Locked = false
    control.Disabled = false
    control.LockReason = "Locked"

    function control:Lock(reason)
        self.Locked = true
        self.LockReason = reason or "Locked"
        if setLockedVisual then setLockedVisual(true, self.LockReason) end
    end

    function control:Unlock()
        self.Locked = false
        self.Disabled = false
        if setLockedVisual then setLockedVisual(false) end
    end

    function control:SetDisabled(disabled, reason)
        self.Disabled = disabled == true
        if self.Disabled then
            self:Lock(reason or "Disabled")
        else
            self:Unlock()
        end
    end

    function control:SetVisible(visible)
        if self.Instance then
            self.Instance.Visible = visible ~= false
        end
    end

    function control:IsLocked()
        return self.Locked == true
    end

    function control:Destroy()
        if self.CancelCapture then pcall(function() self:CancelCapture() end) end
        if self.Close then pcall(function() self:Close(true) end) end
        if self.Instance then self.Instance:Destroy() end
    end
end

-- Search indexes metadata once; favorites borrow the original live rows.
function WindowMethods:_loadFavorites()
    self._controlIndex, self._controlIds, self._favorites = {}, {}, {}
    self._favoritePath = "VitalityHub/Favorites_" .. tostring(game.GameId) .. ".json"
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, self._favoritePath)
    if not ok then return end
    local decodedOk, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if decodedOk and type(data) == "table" then
        for id, selected in pairs(data) do
            if type(id) == "string" and selected == true then self._favorites[id] = true end
        end
    end
end

function WindowMethods:_setFavorite(entry)
    self._favorites[entry.Id] = not self._favorites[entry.Id] or nil
    if entry.PaintStar then entry.PaintStar() end
    if type(writefile) == "function" then
        if type(makefolder) == "function" then pcall(makefolder, "VitalityHub") end
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self._favorites)
        if ok then pcall(writefile, self._favoritePath, encoded) end
    end
    if self._quickMode then self:_renderQuickPage() end
end

function WindowMethods:_indexControl(tab, section, object, data, kind)
    local row = object.Instance
    if not row or object._SearchEntry then return end
    local base = data.Flag and ("flag:" .. tostring(data.Flag))
        or table.concat({tostring(tab.Name), tostring(section.Name), kind, tostring(data.Name or kind)}, "|")
    local ordinal = (self._controlIds[base] or 0) + 1
    self._controlIds[base] = ordinal
    local entry = {Id = base .. "#" .. ordinal, Tab = tab, Section = section, Object = object,
        Name = tostring(data.Name or kind), Kind = kind, Row = row}
    entry.Location = tostring(tab.Name) .. " / " .. tostring(section.Name)
    entry.Search = (entry.Name .. " " .. entry.Location .. " " .. kind .. " " .. tostring(data.Info or "")):lower()
    object._SearchEntry = entry
    table.insert(self._controlIndex, entry)
    local state = rowLayouts[row]
    if state then
        state.FavoriteSpace = 24
        local star = create("TextButton", {Parent = state.TextArea, BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(22, 22),
            Text = "\226\152\134", TextSize = 18, Font = Enum.Font.Gotham, TextColor3 = Theme.Muted,
            AutoButtonColor = false})
        local hovered = false
        local function paint()
            if not star.Parent then return end
            local selected = self._favorites[entry.Id] == true
            star.Text = selected and "\226\152\133" or "\226\152\134"
            star.TextColor3 = selected and Color3.fromRGB(245, 194, 76) or Theme.Muted
            star.Visible = selected or hovered or UserInputService.TouchEnabled
        end
        entry.PaintStar = paint
        state.Label:GetPropertyChangedSignal("Text"):Connect(function()
            entry.Name = state.Label.Text
            entry.Search = (entry.Name .. " " .. entry.Location .. " " .. kind .. " " .. tostring(data.Info or "")):lower()
        end)
        row.MouseEnter:Connect(function() hovered = true; paint() end)
        row.MouseLeave:Connect(function() hovered = false; paint() end)
        star.MouseButton1Click:Connect(function() self:_setFavorite(entry) end)
        self:_registerThemeRenderer(paint)
        state.Refresh()
        paint()
    end
end

function WindowMethods:_searchControls(query)
    local words = {}
    for word in tostring(query or ""):lower():gmatch("%S+") do table.insert(words, word) end
    local matches = {}
    for _, entry in ipairs(self._controlIndex) do
        if entry.Row.Parent and entry.Row.Visible then
            local match = true
            for _, word in ipairs(words) do
                if not entry.Search:find(word, 1, true) then match = false; break end
            end
            if match then table.insert(matches, entry) end
        end
    end
    return matches
end

function WindowMethods:_returnFavoriteRows()
    for _, moved in ipairs(self._borrowedRows or {}) do
        if moved.Row.Parent and moved.Parent.Parent then
            moved.Row.Parent = moved.Parent
            moved.Row.Position = moved.Position
            moved.Row.LayoutOrder = moved.Order
        end
        if moved.Connection then moved.Connection:Disconnect() end
    end
    self._borrowedRows = {}
end

function WindowMethods:_closeQuickPage()
    if not self._quickMode then return end
    self.SidebarSearch:ReleaseFocus()
    Library:_closePopup()
    self:_returnFavoriteRows()
    self._quickMode = nil
    self.QuickPage.Visible = false
end

function WindowMethods:_jumpToControl(entry)
    self:_setActiveTab(entry.Tab)
    task.defer(function()
        if not entry.Row.Parent then return end
        local page = entry.Tab.Page
        local y = (entry.Row.AbsolutePosition.Y - page.AbsolutePosition.Y) / logicalScale(page) + page.CanvasPosition.Y
        page.CanvasPosition = Vector2.new(0, math.max(0, y - 18))
        local highlight = stroke(entry.Row, Theme.AccentVisible, 2, 0)
        self:_tween(highlight, 1, {Transparency = 1})
        task.delay(1.1, function() highlight:Destroy() end)
    end)
end

function WindowMethods:_createFavoriteColumns()
    local holder = create("Frame", {Parent = self.QuickList, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 0), LayoutOrder = 0})
    local columns, layouts = {}, {}
    for index = 1, 2 do
        columns[index] = create("Frame", {Parent = holder, BackgroundTransparency = 1,
            BorderSizePixel = 0, Size = UDim2.new(0.5, -8, 0, 0)})
        layouts[index] = create("UIListLayout", {Parent = columns[index],
            Padding = UDim.new(0, UIStyle.CardGap), SortOrder = Enum.SortOrder.LayoutOrder})
    end
    local function arrange()
        if not holder.Parent then return end
        local scale = logicalScale(holder)
        local width = holder.AbsoluteSize.X / scale
        local leftHeight = layouts[1].AbsoluteContentSize.Y / scale
        local rightHeight = layouts[2].AbsoluteContentSize.Y / scale
        local narrow = width > 0 and width < UIStyle.ResponsiveBreakpoint
        columns[1].Position = UDim2.fromOffset(0, 0)
        if narrow then
            local gap = leftHeight > 0 and rightHeight > 0 and UIStyle.CardGap or 0
            columns[1].Size = UDim2.new(1, 0, 0, leftHeight)
            columns[2].Position = UDim2.fromOffset(0, leftHeight + gap)
            columns[2].Size = UDim2.new(1, 0, 0, rightHeight)
            holder.Size = UDim2.new(1, -6, 0, leftHeight + gap + rightHeight)
        else
            columns[1].Size = UDim2.new(0.5, -8, 0, leftHeight)
            columns[2].Position = UDim2.new(0.5, 8, 0, 0)
            columns[2].Size = UDim2.new(0.5, -8, 0, rightHeight)
            holder.Size = UDim2.new(1, -6, 0, math.max(leftHeight, rightHeight))
        end
    end
    local connections = {
        holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange),
        layouts[1]:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(arrange),
        layouts[2]:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(arrange),
    }
    holder.Destroying:Connect(function()
        for _, connection in ipairs(connections) do connection:Disconnect() end
    end)
    task.defer(arrange)
    return columns
end

function WindowMethods:_renderQuickPage()
    if not self._quickMode or self._destroyed then return end
    Library:_closePopup()
    self:_returnFavoriteRows()
    for _, child in ipairs(self.QuickList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local favoriteMode = self._quickMode == "favorites"
    local favoriteColumns = favoriteMode and self:_createFavoriteColumns() or nil
    self.QuickTitle.Text = favoriteMode and "Favorites" or "Search options"
    local entries = self:_searchControls(favoriteMode and "" or self.SidebarSearch.Text)
    local shown, total = 0, 0
    for _, entry in ipairs(entries) do
        if not favoriteMode or self._favorites[entry.Id] then
            total = total + 1
            if total <= (self._quickLimit or 40) then
                shown = shown + 1
                local cardParent = favoriteColumns and favoriteColumns[(shown - 1) % 2 + 1] or self.QuickList
                local card = create("Frame", {Parent = cardParent, BackgroundColor3 = Theme.Surface2,
                    BorderSizePixel = 0, Size = UDim2.new(1, favoriteMode and 0 or -6, 0, favoriteMode and 100 or 66), LayoutOrder = shown})
                corner(card, 8)
                if favoriteMode then
                    local origin = makeText(card, entry.Location, 10, Theme.Muted, Enum.Font.Gotham)
                    origin.Position = UDim2.fromOffset(14, 7); origin.Size = UDim2.new(1, -28, 0, 18)
                    origin.TextTruncate = Enum.TextTruncate.AtEnd
                    local row = entry.Row
                    local moved = {Row = row, Parent = row.Parent, Position = row.Position, Order = row.LayoutOrder}
                    table.insert(self._borrowedRows, moved)
                    row.Parent = card
                    row.Position = UDim2.fromOffset(0, 28)
                    local function resize() card.Size = UDim2.new(1, 0, 0, row.Size.Y.Offset + 30) end
                    moved.Connection = row:GetPropertyChangedSignal("Size"):Connect(resize)
                    resize()
                else
                    local pick = create("TextButton", {Parent = card, BackgroundTransparency = 1, Text = "",
                        Size = UDim2.new(1, -42, 1, 0), AutoButtonColor = false})
                    local title = makeText(pick, entry.Name, 13, Theme.Text, Enum.Font.GothamMedium)
                    title.Position = UDim2.fromOffset(12, 9); title.Size = UDim2.new(1, -20, 0, 22)
                    title.TextTruncate = Enum.TextTruncate.AtEnd
                    local origin = makeText(pick, entry.Location .. " / " .. entry.Kind, 10, Theme.Muted, Enum.Font.Gotham)
                    origin.Position = UDim2.fromOffset(12, 34); origin.Size = UDim2.new(1, -20, 0, 20)
                    origin.TextTruncate = Enum.TextTruncate.AtEnd
                    pick.MouseButton1Click:Connect(function() self:_jumpToControl(entry) end)
                    local selected = self._favorites[entry.Id]
                    local star = create("TextButton", {Parent = card, BackgroundTransparency = 1,
                        Position = UDim2.new(1, -40, 0, 13), Size = UDim2.fromOffset(32, 36),
                        Text = selected and "\226\152\133" or "\226\152\134", TextSize = 21,
                        TextColor3 = selected and Color3.fromRGB(245, 194, 76) or Theme.Muted, AutoButtonColor = false})
                    star.MouseButton1Click:Connect(function() self:_setFavorite(entry) end)
                end
            end
        end
    end
    if total == 0 then
        local empty = makeText(self.QuickList, favoriteMode and "Star an option or search result to add it here." or "No matching options.", 13, Theme.Muted, Enum.Font.Gotham)
        empty.Size = UDim2.new(1, -20, 0, 64); empty.TextWrapped = true
    elseif total > shown then
        local more = create("TextButton", {Parent = self.QuickList, LayoutOrder = shown + 1,
            Size = UDim2.new(1, -6, 0, 36), BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
            Text = "Show more (" .. tostring(total - shown) .. ")", TextColor3 = Theme.Text, TextSize = 12})
        more.MouseButton1Click:Connect(function() self._quickLimit = (self._quickLimit or 40) + 40; self:_renderQuickPage() end)
    end
end

function WindowMethods:_openQuickPage(mode)
    -- Build the library's lazy appearance controls once so they are searchable too.
    for _, tab in ipairs(self.Tabs) do
        local name = tostring(tab.Name):lower()
        if name == "personalization" or name == "appearance" then self:_buildPersonalization(tab) end
    end
    self._quickMode, self._quickLimit = mode, 40
    self:_refreshTabStyles()
    for _, tab in ipairs(self.Tabs) do
        if tab.PageClip then tab.PageClip.Visible = false else tab.Page.Visible = false end
    end
    self.QuickPage.Visible = true
    self.QuickList.CanvasPosition = Vector2.new(0, 0)
    self:_renderQuickPage()
end

function WindowMethods:_setupQuickNavigation()
    local box = create("Frame", {Parent = self.NavPanel, BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0,
        Position = UDim2.fromOffset(9, 10), Size = UDim2.new(1, -18, 0, 32)})
    corner(box, 7)
    local search = create("TextBox", {Parent = box, BackgroundTransparency = 1, Text = "", PlaceholderText = "Search...",
        ClearTextOnFocus = false, TextColor3 = Theme.Text, PlaceholderColor3 = Theme.Muted, Font = Enum.Font.Gotham,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -14, 1, 0)})
    self.SidebarSearch = search
    local favorite = create("TextButton", {Parent = self.NavPanel, BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0, Text = "", Position = UDim2.fromOffset(9, 48),
        Size = UDim2.new(1, -18, 0, 36), AutoButtonColor = false})
    corner(favorite, 7)
    local favoriteIcon = makeText(favorite, "\226\152\134", 22, Color3.fromRGB(245, 194, 76), Enum.Font.Gotham, Enum.TextXAlignment.Center)
    favoriteIcon.AnchorPoint = Vector2.new(0, 0.5)
    favoriteIcon.Position = UDim2.new(0, 7, 0.5, 0)
    favoriteIcon.Size = UDim2.fromOffset(22, 28)
    local favoriteTitle = makeText(favorite, "Favorites", 12, Theme.Text, Enum.Font.GothamMedium)
    favoriteTitle.Position = UDim2.fromOffset(34, 0)
    favoriteTitle.Size = UDim2.new(1, -39, 1, 0)
    favoriteTitle.TextTruncate = Enum.TextTruncate.AtEnd
    self:AttachTooltip(favorite, "Open your favorite options.", {Title = "Favorites"})
    favorite.MouseButton1Click:Connect(function() search:ReleaseFocus(); self:_openQuickPage("favorites") end)
    local compact = create("TextButton", {Parent = box, BackgroundTransparency = 1, Text = "",
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(28, 30), Visible = false, AutoButtonColor = false})
    local glass = create("Frame", {Parent = compact, BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(11, 11)})
    corner(glass, 20); stroke(glass, Theme.Muted, 1.5, 0)
    create("Frame", {Parent = compact, BackgroundColor3 = Theme.Muted, BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 17), Size = UDim2.fromOffset(7, 2), Rotation = 45})
    compact.MouseButton1Click:Connect(function() self:SetSidebarWidth(UIStyle.SidebarWidth); search:CaptureFocus() end)
    self:_trackConnection(search.Focused:Connect(function() self:_openQuickPage("search") end))
    local revision = 0
    self:_trackConnection(search:GetPropertyChangedSignal("Text"):Connect(function()
        revision = revision + 1
        local current = revision
        task.delay(0.1, function()
            if self._destroyed or current ~= revision or self._quickMode ~= "search" then return end
            self._quickLimit = 40
            self.QuickList.CanvasPosition = Vector2.new(0, 0)
            self:_renderQuickPage()
        end)
    end))
    local function layout()
        local collapsed = self.SidebarCollapsed
        search.Visible, compact.Visible = not collapsed, collapsed
        favorite.Visible = true
        favoriteTitle.Visible = not collapsed
        favoriteIcon.AnchorPoint = Vector2.new(collapsed and 0.5 or 0, 0.5)
        favoriteIcon.Position = collapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 7, 0.5, 0)
        -- Both shortcuts keep a fixed height; resizing never shifts the game tabs.
        self.NavList.Position = UDim2.fromOffset(9, 94)
        local desired = UDim2.new(1, -18, 1, -202)
        if self.NavList.Size ~= desired then self.NavList.Size = desired end
    end
    self._layoutQuickNavigation = layout
    self:_trackConnection(self.NavList:GetPropertyChangedSignal("Size"):Connect(layout))
    layout()
    self.QuickPage = create("Frame", {Parent = self.Content, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 1, -32), Visible = false, ClipsDescendants = true})
    self.QuickTitle = makeText(self.QuickPage, "Search options", 16, Theme.Text, Enum.Font.GothamMedium)
    self.QuickTitle.Size = UDim2.new(1, -48, 0, 30)
    local close = create("TextButton", {Parent = self.QuickPage, BackgroundTransparency = 1, Text = "X",
        TextColor3 = Theme.Muted, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -30, 0, 0)})
    close.MouseButton1Click:Connect(function()
        search:ReleaseFocus()
        self:_closeQuickPage()
        self:_refreshTabStyles()
    end)
    self.QuickList = create("ScrollingFrame", {Parent = self.QuickPage, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Muted})
    create("UIListLayout", {Parent = self.QuickList, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    self:_trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or self._capturingKeybind or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            self:SetVisible(true, true)
            if self.SidebarCollapsed then self:SetSidebarWidth(UIStyle.SidebarWidth) end
            search:CaptureFocus()
        end
    end))
end


function TabMethods:CreateButton(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.RowMinHeight)
    attachDataTooltip(window, row, data)
    local nameLabel = rowText(row, data.Name or "Button", data.Info, UIStyle.ButtonWidth)

    local button = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UIStyle.RowInset, 0.5, 0),
        Size = UDim2.fromOffset(UIStyle.ButtonWidth, UIStyle.ControlHeight),
        BackgroundColor3 = Theme.Button,
        BorderSizePixel = 0,
        Text = data.Interact or "Run",
        TextColor3 = Theme.ButtonText,
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        AutoButtonColor = false,
    })
    attachRowControl(row, button, {Width = UIStyle.ButtonWidth, Fill = false, MeasureText = true})
    corner(button, 9)
    local buttonOutline = stroke(button, Theme.ButtonOutline, 1, 0.58)
    local _, styleButton = applyButtonGradient(button)

    local object = {}
    local function renderButtonState(locked)
        locked = locked == true or object.Locked == true
        button.Active = not locked
        styleButton(locked)
        setThemeRole(buttonOutline, "Color", locked and "Border" or "ButtonOutline")

    end
    makeLockable(object, renderButtonState)
    renderButtonState(false)
    window:_registerThemeRenderer(renderButtonState)

    button.MouseButton1Click:Connect(function()
        if object.Locked then return end
        window:_playSound("Click")


        safeCallback(data.Callback)
    end)

    function object:Set(name, interact)
        if name then data.Name = name; nameLabel.Text = tostring(name) end
        if interact then button.Text = tostring(interact) end
    end
    function object:Get() return nil end
    object.Instance = row
    window:_indexControl(self, section, object, data, "Button")
    return object
end

function TabMethods:CreateToggle(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.RowMinHeight)
    attachDataTooltip(window, row, data)
    rowText(row, data.Name or "Toggle", data.Info, UIStyle.ToggleWidth)

    local behavior = tostring(data.Behavior or data.Name or ""):lower()
    local defaultValue = data.CurrentValue
    if defaultValue == nil and behavior == "notifications" then
        defaultValue = window.NotificationsEnabled
    elseif defaultValue == nil and (behavior == "sound" or behavior == "sounds") then
        defaultValue = window.SoundsEnabled
    end
    local value = window:_saved(data.Flag, defaultValue == true) == true
    local shell = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UIStyle.RowInset, 0.5, 0),
        Size = UDim2.fromOffset(UIStyle.ToggleWidth, UIStyle.ToggleHeight),
        BackgroundColor3 = value and Theme.AccentVisible or Theme.Surface3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    attachRowControl(row, shell, {Width = UIStyle.ToggleWidth, Height = UIStyle.ToggleHeight, Fill = false})
    corner(shell, UIStyle.ToggleHeight / 2)
    local toggleGradient, refreshToggleGradient = applyThemeGradient(shell, window, "accent")
    local toggleStroke = stroke(shell, value and Theme.AccentVisible or Theme.Border, 1, value and 0.16 or 0.42)
    local knob = create("Frame", {
        Parent = shell,
        Size = UDim2.fromOffset(20, 20),
        Position = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = value and Theme.AccentText or Theme.Text,
        BorderSizePixel = 0,
    })
    corner(knob, 10)

    local object = {Value = value}
    local function render(animate)
        local shellRole = object.Value and "AccentVisible" or "Surface3"
        local knobRole = "Text"
        local shellProps = {BackgroundColor3 = Theme.Surface3}
        toggleGradient.Enabled = object.Value
        if object.Value then
            refreshToggleGradient()
            shellProps.BackgroundColor3 = Color3.new(1, 1, 1)
        end
        local knobProps = {Position = object.Value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}
        setThemeRole(shell, "BackgroundColor3", object.Value and nil or "Surface3")
        setThemeRole(knob, "BackgroundColor3", knobRole)
        setThemeRole(toggleStroke, "Color", object.Value and "AccentVisible" or "Border")
        toggleStroke.Transparency = object.Value and 0.16 or 0.42
        if animate then
            window:_tween(shell, 0.16, shellProps)
            window:_tween(knob, 0.16, knobProps)
        else
            for k,v in pairs(shellProps) do shell[k] = v end
            for k,v in pairs(knobProps) do knob[k] = v end
        end
    end

    makeLockable(object, function(locked)
        shell.Active = not locked
        shell.BackgroundTransparency = locked and 0.5 or 0
        knob.BackgroundTransparency = locked and 0.35 or 0
    end)

    function object:Set(newValue, fire)
        object.Value = newValue == true
        render(true)
        if behavior == "notifications" then
            window:SetNotificationsEnabled(object.Value)
        elseif behavior == "sound" or behavior == "sounds" then
            window:SetSoundsEnabled(object.Value)
        end
        if fire ~= false then safeCallback(data.Callback, object.Value) end
        window:_saveConfig()
    end
    function object:Get() return object.Value end

    shell.MouseButton1Click:Connect(function()
        if object.Locked then return end
        local wasSoundEnabled = window.SoundsEnabled
        object:Set(not object.Value, true)
        if behavior == "sound" or behavior == "sounds" then
            if object.Value then window:_playSound("Toggle") end
        elseif wasSoundEnabled or window.SoundsEnabled then
            window:_playSound("Toggle")
        end
    end)

    if behavior == "notifications" then
        window:SetNotificationsEnabled(object.Value)
    elseif behavior == "sound" or behavior == "sounds" then
        window:SetSoundsEnabled(object.Value)
    end

    render(false)
    window:_registerFlag(data.Flag, object)
    window:_registerThemeRenderer(function() render(false) end)
    object.Instance = row
    window:_indexControl(self, section, object, data, "Toggle")
    return object
end

function TabMethods:CreateSlider(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.RowMinHeight)
    attachDataTooltip(window, row, data)
    rowText(row, data.Name or "Slider", data.Info, UIStyle.FieldWidth)

    local min = tonumber(data.Range and data.Range[1]) or 0
    local max = tonumber(data.Range and data.Range[2]) or 100
    local increment = tonumber(data.Increment) or 1
    local saved = tonumber(window:_saved(data.Flag, data.CurrentValue or min)) or min
    local value = normalizeSliderValue(saved, min, max, increment)
    local suffixText = tostring(data.Suffix or "")

    local control = create("Frame", {
        Parent = row,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UIStyle.RowInset, 0.5, 0),
        Size = UDim2.fromOffset(UIStyle.FieldWidth, UIStyle.ControlHeight),
    })

    attachRowControl(row, control, {Width = 190, Height = UIStyle.ControlHeight})
    local suffixWidth = suffixText ~= "" and 44 or 0
    local boxWidth = 54
    local gap = 9

    local track = create("Frame", {
        Parent = control,
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, -3),
        Size = UDim2.new(1, -(boxWidth + suffixWidth + gap + 12), 0, 6),
    })
    corner(track, 3)

    local ratio0 = (value-min) / math.max(max-min, 0.00001)
    local fill = create("Frame", {
        Parent = track,
        BackgroundColor3 = Theme.AccentVisible,
        BorderSizePixel = 0,
        Size = UDim2.new(ratio0, 0, 1, 0),
    })
    corner(fill, 3)
    local _, refreshFillGradient = applyThemeGradient(fill, window, "accent")

    local knob = create("Frame", {
        Parent = track,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(ratio0, 0, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Theme.SliderKnob,
        BorderSizePixel = 0,
    })
    corner(knob, 8)
    local knobStroke = stroke(knob, Theme.AccentVisible, 1, 0.14)
    local knobHalo = create("Frame", {Parent = knob, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = Theme.AccentVisible, BackgroundTransparency = 1, BorderSizePixel = 0})
    corner(knobHalo, 12)

    local box = create("TextBox", {
        Parent = control,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -suffixWidth, 0.5, 0),
        Size = UDim2.fromOffset(boxWidth, UIStyle.ControlHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = formatSliderValue(value, increment),
        TextColor3 = Theme.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
    })
    corner(box, 8)
    stroke(box, Theme.Border, 1, 0.08)

    local suffixLabel
    if suffixText ~= "" then
        suffixLabel = makeText(control, suffixText, 11, Theme.Muted, Enum.Font.Gotham, Enum.TextXAlignment.Right)
        suffixLabel.AnchorPoint = Vector2.new(1, 0.5)
        suffixLabel.Position = UDim2.new(1, 0, 0.5, 0)
        suffixLabel.Size = UDim2.fromOffset(suffixWidth - 8, UIStyle.ControlHeight)
        suffixLabel.TextWrapped = false
    end

    local function sizeSliderZones()
        if not control.Parent then return end
        suffixWidth = suffixLabel and math.max(suffixText == "studs" and 42 or 24, math.ceil(textSize(suffixLabel, 10000).X) + 10) or 0
            local widest = 0
        for _, number in ipairs({min, max, value}) do
            local ok, bounds = pcall(TextService.GetTextSize, TextService, formatSliderValue(number, increment), box.TextSize, box.Font, Vector2.new(10000, 100))
            if ok then widest = math.max(widest, bounds.X) end
        end
        boxWidth = math.max(54, math.ceil(widest) + 20)
        box.Size = UDim2.fromOffset(boxWidth, UIStyle.ControlHeight)
        box.Position = UDim2.new(1, -suffixWidth, 0.5, 0)
        track.Size = UDim2.new(1, -(boxWidth + suffixWidth + gap + 6), 0, 6)
        if suffixLabel then suffixLabel.Size = UDim2.fromOffset(suffixWidth - 8, UIStyle.ControlHeight) end
        local state = rowLayouts[row]
        state.Options.Width = math.max(190, boxWidth + suffixWidth + 90)
        state.Refresh()
    end
    box:GetPropertyChangedSignal("Font"):Connect(sizeSliderZones)
    if suffixLabel then suffixLabel:GetPropertyChangedSignal("Font"):Connect(sizeSliderZones) end
    sizeSliderZones()
    local object = {Value = value}
    local dragging = false

    local function render()
        setThemeRole(track, "BackgroundColor3", "BorderSoft")
        refreshFillGradient()
        setThemeRole(knob, "BackgroundColor3", "SliderKnob")
        setThemeRole(knobStroke, "Color", "AccentVisible")
        local ratio = (object.Value - min) / math.max(max-min, 0.00001)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        box.Text = formatSliderValue(object.Value, increment)
    end

    function object:Set(newValue, fire)
        local parsed = tonumber(newValue)
        if parsed == nil then render() return false end
        newValue = normalizeSliderValue(parsed, min, max, increment)
        object.Value = newValue
        render()
        if fire ~= false then safeCallback(data.Callback, object.Value) end
        window:_saveConfig()
        return true
    end

    function object:Get()
        return object.Value
    end

    local function setFromX(x)
        local ratio = clamp01((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
        object:Set(min + (max-min) * ratio, true)
    end

    local hitTarget = create("TextButton", {Parent = track, BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 28), Text = "", AutoButtonColor = false, ZIndex = 4})
    hitTarget.MouseEnter:Connect(function() if not object.Locked then window:_tween(knobHalo, 0.14, {BackgroundTransparency = 0.86}) end end)
    hitTarget.MouseLeave:Connect(function() if not dragging then window:_tween(knobHalo, 0.14, {BackgroundTransparency = 1}) end end)
    hitTarget.InputBegan:Connect(function(input)
        if object.Locked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            window:_playSound("Click")
            dragging = true
            setFromX(input.Position.X)
        end
    end)

    knob.InputBegan:Connect(function(input)
        if object.Locked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            window:_playSound("Click")
            dragging = true
            setFromX(input.Position.X)
        end
    end)

    window:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end))

    window:_trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            window:_tween(knobHalo, 0.14, {BackgroundTransparency = 1})
        end
    end))

    box.FocusLost:Connect(function()
        if object.Locked then render() return end
        object:Set(box.Text, true)
    end)

    makeLockable(object, function(locked)
        track.BackgroundTransparency = locked and 0.5 or 0
        fill.BackgroundTransparency = locked and 0.5 or 0
        knob.BackgroundTransparency = locked and 0.5 or 0
        box.TextEditable = not locked
        box.BackgroundTransparency = locked and 0.25 or 0
        if suffixLabel then suffixLabel.TextTransparency = locked and 0.4 or 0 end
    end)

    render()
    window:_registerFlag(data.Flag, object)
    window:_registerThemeRenderer(render)
    object.Instance = row
    window:_indexControl(self, section, object, data, "Slider")
    return object
end

function TabMethods:CreateInput(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local hasCounter = tonumber(data.CharacterLimit) ~= nil
    local row = section:_row(hasCounter and 86 or 70)
    attachDataTooltip(window, row, data)
    rowText(row, data.Name or "Input", data.Info, 226)

    local initial = tostring(window:_saved(data.Flag, data.CurrentValue or ""))
    local inputBox = create("TextBox", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UIStyle.RowInset, 0.5, hasCounter and -5 or 0),
        Size = UDim2.fromOffset(210, UIStyle.ControlHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        PlaceholderText = data.PlaceholderText or "Enter a value",
        PlaceholderColor3 = Theme.Muted,
        Text = initial,
        TextColor3 = Theme.Text,
        TextSize = UIStyle.FieldTextSize,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    })
    attachRowControl(row, inputBox, {Width = 210, Stacked = true, ExtraHeight = hasCounter and 18 or 0})
    corner(inputBox, 9)
    local inputStroke = stroke(inputBox, Theme.Border, 1, 0.08)
    padding(inputBox, 11, 11, 0, 0)

    local counter
    if hasCounter then
        counter = makeText(row, "", 10, Theme.Muted, Enum.Font.Gotham, Enum.TextXAlignment.Right)
        counter.AnchorPoint = Vector2.new(1, 1)
        counter.Position = UDim2.new(1, -18, 1, -6)
        counter.Size = UDim2.fromOffset(80, 16)
    end

    local object = {Value = initial, IsOpen = false}
    local suppress = false

    local function refreshCounter()
        if counter then
            counter.Text = tostring(#inputBox.Text) .. " / " .. tostring(data.CharacterLimit)
        end
    end

    inputBox.Focused:Connect(function()
        setThemeRole(inputStroke, "Color", "AccentVisible")
        window:_playSound("Open")
    end)

    inputBox.FocusLost:Connect(function(enterPressed)
        setThemeRole(inputStroke, "Color", "Border")
        if object.Locked then
            inputBox.Text = object.Value
            refreshCounter()
            return
        end
        if data.OnEnter and not enterPressed then return end
        object.Value = inputBox.Text
        safeCallback(data.Callback, object.Value)
        window:_saveConfig()
        if data.RemoveTextAfterFocusLost then
            inputBox.Text = ""
        end
        refreshCounter()
    end)

    inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        if suppress then return end
        local text = inputBox.Text
        if data.NumbersOnly then
            local filtered = text:gsub("[^%d%.%-]", "")
            if filtered ~= text then
                suppress = true
                inputBox.Text = filtered
                suppress = false
                text = filtered
            end
        end
        if data.CharacterLimit and #text > data.CharacterLimit then
            suppress = true
            inputBox.Text = text:sub(1, data.CharacterLimit)
            suppress = false
        end
        refreshCounter()
    end)

    function object:Set(text, fire)
        object.Value = tostring(text or "")
        if data.CharacterLimit and #object.Value > data.CharacterLimit then
            object.Value = object.Value:sub(1, data.CharacterLimit)
        end
        inputBox.Text = object.Value
        refreshCounter()
        if fire ~= false then safeCallback(data.Callback, object.Value) end
        window:_saveConfig()
    end

    function object:Get()
        return object.Value
    end

    makeLockable(object, function(locked)
        inputBox.TextEditable = not locked
        inputBox.BackgroundTransparency = locked and 0.25 or 0
        setThemeRole(inputBox, "TextColor3", locked and "Muted" or "Text")
        if counter then counter.TextTransparency = locked and 0.35 or 0 end
    end)

    refreshCounter()
    window:_registerFlag(data.Flag, object)
    object.Instance = row
    window:_indexControl(self, section, object, data, "Input")
    return object
end

function TabMethods:CreateDropdown(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.RowMinHeight)
    attachDataTooltip(window, row, data)
    rowText(row, data.Name or "Dropdown", data.Info, 216)

    local options = data.Options or {}
    local multi = data.MultiSelection == true

    local autoThemeSelector = data.ThemeSelector == true
    if not autoThemeSelector and not multi and tostring(data.Name or ""):lower() == "theme" then
        local hasDark, hasLight, hasSystem = false, false, false
        for _, option in ipairs(options) do
            local lowered = tostring(option):lower()
            hasDark = hasDark or lowered == "dark"
            hasLight = hasLight or lowered == "light"
            hasSystem = hasSystem or lowered == "system"
        end
        autoThemeSelector = hasDark and hasLight and hasSystem
    end

    local fallback = data.CurrentOption

    if multi and type(fallback) ~= "table" then
        fallback = fallback ~= nil and {fallback} or {}
    elseif not multi and type(fallback) == "table" then
        fallback = fallback[1]
    end

    if autoThemeSelector and data.Flag then
        window._appearanceFlags = window._appearanceFlags or {}
        window._appearanceFlags[data.Flag] = "ThemeName"
    end
    local value = autoThemeSelector and window:GetTheme() or window:_saved(data.Flag, fallback)
    if multi and type(value) ~= "table" then value = {} end
    if not multi and type(value) == "table" then value = value[1] end

    local button = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UIStyle.RowInset, 0.5, 0),
        Size = UDim2.fromOffset(200, UIStyle.ControlHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    attachRowControl(row, button, {Width = 176})
    corner(button, 9)
    local buttonStroke = stroke(button, Theme.Border, 1, 0.24)

    local valueLabel = makeText(button, "", 12, Theme.Text, Enum.Font.Gotham)
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    valueLabel.Position = UDim2.fromOffset(11, 0)
    valueLabel.Size = UDim2.new(1, -42, 1, 0)

    local chevron, setChevron = createChevron(button, false)
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -9, 0.5, 0)
    setIconColor(chevron, Theme.Text)

    local object = {
        Value = value,
        Options = options,
        IsOpen = false,
    }

    local function contains(tbl, item)
        for _, v in ipairs(tbl or {}) do
            if v == item then return true end
        end
        return false
    end

    local function copyArray(tbl)
        local new = {}
        for _, v in ipairs(tbl or {}) do
            table.insert(new, v)
        end
        return new
    end

    local function labelText()
        if multi then
            local count = #object.Value
            if count == 0 then return data.Placeholder or "Select..." end
            return tostring(count) .. " selected"
        end
        return object.Value ~= nil and tostring(object.Value) or (data.Placeholder or "Select...")
    end

    local function render()
        valueLabel.Text = labelText()
    end

    local closePopup

    function object:Set(newValue, fire)
        if multi then
            if type(newValue) ~= "table" then
                newValue = newValue ~= nil and {newValue} or {}
            end
            object.Value = copyArray(newValue)
        else
            if type(newValue) == "table" then newValue = newValue[1] end
            object.Value = newValue
        end

        render()

        if autoThemeSelector and not multi and object.Value ~= nil then
            window:SetTheme(object.Value)
        end

        if fire ~= false then
            safeCallback(data.Callback, object.Value)
        end
        window:_saveConfig()
    end

    function object:Get()
        if multi then return copyArray(object.Value) end
        return object.Value
    end

    function object:Refresh(newOptions, keepValue)
        object.Options = type(newOptions) == "table" and copyArray(newOptions) or {}
        if not keepValue then
            object.Value = multi and {} or nil
        elseif multi then
            local valid = {}
            for _, selected in ipairs(object.Value) do
                if contains(object.Options, selected) then table.insert(valid, selected) end
            end
            object.Value = valid
        elseif not contains(object.Options, object.Value) then
            object.Value = nil
        end
        render()
        if object.IsOpen then
            object:Close(true)
        end
        window:_saveConfig()
        return object:GetOptions()
    end

    object.UpdateOptions = object.Refresh

    makeLockable(object, function(locked)
        button.Active = not locked
        button.BackgroundTransparency = locked and 0.25 or 0
        setThemeRole(valueLabel, "TextColor3", locked and "Muted" or "Text")
        setIconColor(chevron, locked and Theme.Muted or Theme.Text)
        if locked and object.IsOpen then Library:_closePopup() end
    end)

    local function openPopup()
        if object.Locked then return end

        if Library._openPopupOwner and Library._openPopupOwner ~= object then
            Library:_closePopup()
        elseif Library._openPopupOwner == object then
            return
        end

        object.IsOpen = true
        setChevron(true)
        setThemeRole(buttonStroke, "Color", "AccentVisible")
        window:_playSound("Open")

        local gui = window.Gui
        local popupHeight = math.min(#object.Options * 44 + 10, 264)
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local popupX = math.clamp(button.AbsolutePosition.X, 10, math.max(10, viewport.X - button.AbsoluteSize.X - 10))
        local popupY = button.AbsolutePosition.Y + button.AbsoluteSize.Y + 5
        if popupY + popupHeight > viewport.Y - 10 then popupY = button.AbsolutePosition.Y - popupHeight - 5 end
        local popup = create("CanvasGroup", {
            Parent = gui,
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(popupX, math.max(10, popupY)),
            Size = UDim2.fromOffset(button.AbsoluteSize.X, popupHeight),
            GroupTransparency = 0,
            ZIndex = 220,
        })
        corner(popup, 11)
        stroke(popup, Theme.Border, 1, 0.04)
        local closing = false
        closePopup = function(immediate)
            if closing then return end
            closing = true
            object.IsOpen = false
            setChevron(false)
            setThemeRole(buttonStroke, "Color", "Border")
            if not immediate then window:_playSound("Close") end
            if popup.Parent then popup:Destroy() end
        end

        local list = create("ScrollingFrame", {
            Parent = popup,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.new(1, -8, 1, -8),
            CanvasSize = UDim2.fromOffset(0, #object.Options * 44),
            ScrollBarThickness = #object.Options * 44 > popupHeight and 3 or 0,
            ScrollBarImageColor3 = Theme.Disabled,
            ZIndex = 221,
        })
        create("UIListLayout", {
            Parent = list,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local optionRenderers = {}

        for _, option in ipairs(object.Options) do
            local optionButton = create("TextButton", {
                Parent = list,
                BackgroundColor3 = Theme.Surface,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 44),
                Text = "",
                AutoButtonColor = false,
                ZIndex = 222,
            })
            corner(optionButton, 8)

            local mark
            local markStroke
            local check
            if multi then
                mark = create("Frame", {
                    Parent = optionButton,
                    BackgroundColor3 = Theme.Background,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(10, 10),
                    Size = UDim2.fromOffset(20, 20),
                    ZIndex = 223,
                })
                corner(mark, 4)
                markStroke = stroke(mark, Theme.Border, 1, 0)
                check = createCheckmark(mark, Theme.AccentText, 224)
                setIconColor(check, "AccentText")
            end

            local optLabel = makeText(optionButton, tostring(option), 12, Theme.Text, Enum.Font.Gotham)
            optLabel.Position = UDim2.fromOffset(multi and 42 or 12, 0)
            optLabel.Size = UDim2.new(1, -(multi and 48 or 42), 1, 0)
            optLabel.ZIndex = 223

            local singleCheckHolder
            if not multi then
                singleCheckHolder = create("Frame", {
                    Parent = optionButton,
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -9, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    ZIndex = 223,
                })
                createCheckmark(singleCheckHolder, Theme.AccentVisible, 224)
                setIconColor(singleCheckHolder, "AccentVisible")
            end

            local function renderOption()
                local selected = multi and contains(object.Value, option) or object.Value == option
                setThemeRole(optionButton, "BackgroundColor3", selected and "AccentSoft" or "Surface")
                optionButton.BackgroundTransparency = selected and 0.08 or 1

                if multi then
                    setThemeRole(mark, "BackgroundColor3", selected and "AccentVisible" or "Background")
                    setThemeRole(markStroke, "Color", selected and "AccentVisible" or "Border")
                    setIconColor(check, "AccentText")
                    check.Visible = selected
                else
                    singleCheckHolder.Visible = selected
                end
            end

            optionRenderers[#optionRenderers + 1] = renderOption
            renderOption()

            optionButton.MouseEnter:Connect(function()
                local selected = multi and contains(object.Value, option) or object.Value == option
                if not selected then
                    setThemeRole(optionButton, "BackgroundColor3", "Surface2")
                    optionButton.BackgroundTransparency = 0
                end
            end)

            optionButton.MouseLeave:Connect(function()
                renderOption()
            end)

            optionButton.MouseButton1Click:Connect(function()
                window:_playSound("Click")
                if multi then
                    local newValue = copyArray(object.Value)
                    local foundIndex
                    for index, existing in ipairs(newValue) do
                        if existing == option then
                            foundIndex = index
                            break
                        end
                    end

                    if foundIndex then
                        table.remove(newValue, foundIndex)
                    else
                        table.insert(newValue, option)
                    end

                    object:Set(newValue, true)

                    -- Keep multiselect open and repaint every checkbox immediately.
                    for _, repaint in ipairs(optionRenderers) do repaint() end
                else
                    object:Set(option, true)
                    Library:_closePopup()
                end
            end)
        end

        Library:_registerPopup(popup, object, button, closePopup)

        popup.Destroying:Connect(function()
            Library:_forgetPopup(popup)
            object.IsOpen = false
            setChevron(false)
            setThemeRole(buttonStroke, "Color", "Border")
        end)
    end

    button.MouseButton1Click:Connect(function()
        if object.Locked then return end
        if Library._openPopupOwner == object then
            Library:_closePopup()
        else
            Library:_closePopup()
            openPopup()
        end
    end)

    function object:Open()
        if not object.IsOpen then Library:_closePopup(); openPopup() end
    end

    function object:Close(immediate)
        if Library._openPopupOwner == object then Library:_closePopup(immediate == true) end
    end

    function object:IsExpanded()
        return object.IsOpen == true
    end

    function object:GetOptions()
        return copyArray(object.Options)
    end

    function object:Add(option)
        if not contains(object.Options, option) then table.insert(object.Options, option) end
        if object.IsOpen then object:Close(true); object:Open() end
    end

    function object:Remove(option)
        for index, existing in ipairs(object.Options) do
            if existing == option then table.remove(object.Options, index); break end
        end
        if multi then
            local filtered = {}
            for _, selected in ipairs(object.Value) do
                if selected ~= option then table.insert(filtered, selected) end
            end
            object:Set(filtered, false)
        elseif object.Value == option then
            object:Set(nil, false)
        end
        if object.IsOpen then object:Close(true); object:Open() end
    end

    function object:Clear(fire)
        object:Set(multi and {} or nil, fire)
    end

    render()
    if autoThemeSelector and not multi and object.Value then
        window:SetTheme(object.Value)
    end
    window:_registerFlag(data.Flag, object)
    object.Instance = row
    window:_indexControl(self, section, object, data, "Dropdown")
    return object
end

function TabMethods:CreateColorPicker(data)
    data = data or {}
    local window = self.Window
    local autoAccentPicker = data.AccentPicker == true or tostring(data.Name or ""):lower() == "accent color"
    local autoButtonPicker = data.ButtonPicker == true or tostring(data.Name or ""):lower() == "button color"
    local gradientKind = data.GradientKind and tostring(data.GradientKind):lower() or nil
    local gradientStop = data.GradientStop and tostring(data.GradientStop):lower() or nil

    -- The window owns one global accent control. A second request reuses the
    -- existing controller instead of creating two controls that fight each other.
    if autoAccentPicker and window._accentPicker then
        return window._accentPicker
    end
    if autoButtonPicker and window._buttonPicker then
        return window._buttonPicker
    end

    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.RowMinHeight)
    attachDataTooltip(window, row, data)
    rowText(row, data.Name or "Color Picker", data.Info, 216)

    local roleDefault = autoButtonPicker and Theme.Button or Theme.Accent
    if gradientKind then
        local gradientStart, gradientEnd = window:GetGradient(gradientKind)
        if not gradientStart then gradientKind = nil else roleDefault = gradientStop == "end" and gradientEnd or gradientStart end
    end
    if data.Flag and (autoAccentPicker or autoButtonPicker or gradientKind) then
        window._appearanceFlags = window._appearanceFlags or {}
        window._appearanceFlags[data.Flag] = autoAccentPicker and "CustomAccent"
            or autoButtonPicker and "CustomButton" or {Kind = gradientKind, Stop = gradientStop}
    end
    local initial = window:_saved(data.Flag, data.Color or roleDefault)
    if autoAccentPicker then initial = window.CustomAccent or Theme.Accent end
    if autoButtonPicker then initial = window.CustomButton or Theme.Button end
    if gradientKind then initial = roleDefault end
    if typeof(initial) ~= "Color3" then initial = data.Color or roleDefault end

    local button = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UIStyle.RowInset, 0.5, 0),
        Size = UDim2.fromOffset(200, UIStyle.ControlHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    attachRowControl(row, button, {Width = 176})
    corner(button, 9)
    local buttonStroke = stroke(button, Theme.Border, 1, 0.24)

    local swatch = create("Frame", {
        Parent = button,
        BackgroundColor3 = initial,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.fromOffset(24, 20),
    })
    corner(swatch, 4)
    setThemeRole(swatch, "BackgroundColor3", nil)
    local hexLabel = makeText(button, colorToHex(initial), 12, Theme.Text, Enum.Font.Gotham)
    hexLabel.Position = UDim2.fromOffset(43, 0)
    hexLabel.Size = UDim2.new(1, -76, 1, 0)
    local chevron, setChevron = createChevron(button, false)
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -9, 0.5, 0)
    setIconColor(chevron, Theme.Text)

    local object = {Value = initial}

    function object:_Sync(color)
        if typeof(color) ~= "Color3" then return end
        object.Value = color
        setThemeRole(swatch, "BackgroundColor3", nil)
        swatch.BackgroundColor3 = color
        hexLabel.Text = colorToHex(color)
    end

    function object:Set(color, fire)
        if typeof(color) ~= "Color3" then return end
        object:_Sync(color)
        if autoAccentPicker then
            window:SetThemeAccent(color)
        elseif autoButtonPicker then
            window:SetButtonColor(color)
        elseif gradientKind then
            local gradientStart, gradientEnd = window:GetGradient(gradientKind)
            window:SetGradient(gradientKind, gradientStop == "end" and gradientStart or color, gradientStop == "end" and color or gradientEnd)
        end
        if fire ~= false then safeCallback(data.Callback, color) end
        window:_saveConfig()
    end
    function object:Get() return object.Value end

    makeLockable(object, function(locked)
        button.Active = not locked
        button.BackgroundTransparency = locked and 0.25 or 0
        setThemeRole(hexLabel, "TextColor3", locked and "Muted" or "Text")
        if locked and object.IsOpen then Library:_closePopup() end
    end)

    local function openPopup()
        if object.Locked then return end
        if Library._openPopupOwner and Library._openPopupOwner ~= object then
            Library:_closePopup()
        elseif Library._openPopupOwner == object then
            return
        end
        setChevron(true)
        setThemeRole(buttonStroke, "Color", "AccentVisible")
        window:_playSound("Open")

        local popupW, popupH = 360, 282
        local x = button.AbsolutePosition.X + button.AbsoluteSize.X - popupW
        local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y + 6
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
        if y + popupH > viewport.Y - 10 then y = button.AbsolutePosition.Y - popupH - 6 end
        if x < 10 then x = 10 end

        local popup = create("CanvasGroup", {
            Parent = window.Gui,
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(popupW, popupH),
            GroupTransparency = 1,
            ZIndex = 230,
        })
        corner(popup, 12)
        stroke(popup, Theme.Border, 1, 0.06)
        local popupScale = create("UIScale", {Parent = popup, Scale = 0.97})
        local closing = false
        local function closePopup(immediate)
            if closing then return end
            closing = true
            object.IsOpen = false
            setChevron(false)
            setThemeRole(buttonStroke, "Color", "Border")
            if not immediate then window:_playSound("Close") end
            local duration = immediate and 0 or window:_motionDuration(0.16)
            if duration <= 0 then
                if popup.Parent then popup:Destroy() end
                return
            end
            window:_tween(popup, 0.16, {GroupTransparency = 1})
            window:_tween(popupScale, 0.16, {Scale = 0.97})
            task.delay(duration + 0.01, function()
                if popup.Parent then popup:Destroy() end
            end)
        end

        local heading = makeText(popup, "COLOR PICKER", 11, Theme.Text, Enum.Font.GothamBold)
        heading.Position = UDim2.fromOffset(14, 8)
        heading.Size = UDim2.new(1, -28, 0, 24)
        heading.ZIndex = 231
        create("Frame", {
            Parent = popup,
            BackgroundColor3 = Theme.BorderSoft,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(14, 35),
            Size = UDim2.new(1, -28, 0, 1),
            ZIndex = 231,
        })

        local h, s, v = object.Value:ToHSV()
        local sv = create("Frame", {
            Parent = popup,
            Position = UDim2.fromOffset(14, 50),
            Size = UDim2.fromOffset(214, 172),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 231,
        })
        corner(sv, 5)
        setThemeRole(sv, "BackgroundColor3", nil)

        local whiteLayer = create("Frame", {
            Parent = sv,
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1,1),
            ZIndex = 232,
        })
        setThemeRole(whiteLayer, "BackgroundColor3", nil)
        create("UIGradient", {
            Parent = whiteLayer,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)
            }),
        })
        local blackLayer = create("Frame", {
            Parent = sv,
            BackgroundColor3 = Color3.new(0,0,0),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1,1),
            ZIndex = 233,
        })
        setThemeRole(blackLayer, "BackgroundColor3", nil)
        create("UIGradient", {
            Parent = blackLayer,
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)
            }),
        })
        local svCursor = create("Frame", {
            Parent = sv,
            AnchorPoint = Vector2.new(0.5,0.5),
            Position = UDim2.new(s,0,1-v,0),
            Size = UDim2.fromOffset(14,14),
            BackgroundTransparency = 1,
            ZIndex = 236,
        })
        corner(svCursor, 7)
        stroke(svCursor, Theme.Text, 2, 0)

        local hue = create("Frame", {
            Parent = popup,
            Position = UDim2.fromOffset(242, 50),
            Size = UDim2.fromOffset(24, 172),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            ZIndex = 231,
        })
        corner(hue, 4)
        setThemeRole(hue, "BackgroundColor3", nil)
        create("UIGradient", {
            Parent = hue,
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
            }),
        })
        local hueCursor = create("Frame", {
            Parent = hue,
            AnchorPoint = Vector2.new(0.5,0.5),
            Position = UDim2.new(0.5,0,h,0),
            Size = UDim2.new(1, 6, 0, 5),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            ZIndex = 236,
        })
        corner(hueCursor, 2)

        local previewTitle = makeText(popup, "Preview", 10, Theme.Muted, Enum.Font.Gotham)
        previewTitle.Position = UDim2.fromOffset(282, 50)
        previewTitle.Size = UDim2.fromOffset(64, 18)
        previewTitle.ZIndex = 231
        local preview = create("Frame", {
            Parent = popup,
            Position = UDim2.fromOffset(282, 71),
            Size = UDim2.fromOffset(64, 38),
            BackgroundColor3 = object.Value,
            BorderSizePixel = 0,
            ZIndex = 231,
        })
        corner(preview, 5)
        setThemeRole(preview, "BackgroundColor3", nil)

        local function numberBox(labelText, px, py)
            local lbl = makeText(popup, labelText, 10, Theme.Muted, Enum.Font.Gotham)
            lbl.Position = UDim2.fromOffset(px, py)
            lbl.Size = UDim2.fromOffset(30,16)
            lbl.ZIndex = 231
            local box = create("TextBox", {
                Parent = popup,
                Position = UDim2.fromOffset(px, py+18),
                Size = UDim2.fromOffset(64, 30),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Text = "",
                TextColor3 = Theme.Text,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                ClearTextOnFocus = false,
                ZIndex = 231,
            })
            corner(box,4); stroke(box, Theme.Border,1,0.1)
            return box
        end
        local rBox = numberBox("R", 282, 120)
        local gBox = numberBox("G", 282, 171)
        local bBox = numberBox("B", 282, 222)

        local hexBox = create("TextBox", {
            Parent = popup,
            Position = UDim2.fromOffset(14, 234),
            Size = UDim2.fromOffset(252, 34),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            Text = colorToHex(object.Value),
            TextColor3 = Theme.Text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            ZIndex = 231,
        })
        corner(hexBox,4); stroke(hexBox, Theme.Border,1,0.1); padding(hexBox,10,10,0,0)

        local updating = false
        local function updateFields(color)
            updating = true
            preview.BackgroundColor3 = color
            hexBox.Text = colorToHex(color)
            rBox.Text = tostring(math.floor(color.R*255+0.5))
            gBox.Text = tostring(math.floor(color.G*255+0.5))
            bBox.Text = tostring(math.floor(color.B*255+0.5))
            updating = false
        end
        updateFields(object.Value)

        local function commitHSV()
            local color = Color3.fromHSV(h,s,v)
            sv.BackgroundColor3 = Color3.fromHSV(h,1,1)
            svCursor.Position = UDim2.new(s,0,1-v,0)
            hueCursor.Position = UDim2.new(0.5,0,h,0)
            object:Set(color, true)
            updateFields(color)
        end

        local draggingSV, draggingHue = false, false
        local function setSV(pos)
            s = clamp01((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X)
            v = 1 - clamp01((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y)
            commitHSV()
        end
        local function setHue(pos)
            h = clamp01((pos.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y)
            commitHSV()
        end

        sv.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingSV = true; setSV(i.Position) end
        end)
        hue.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingHue = true; setHue(i.Position) end
        end)
        local moveConn = UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                if draggingSV then setSV(i.Position) elseif draggingHue then setHue(i.Position) end
            end
        end)
        local endConn = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingSV=false; draggingHue=false end
        end)
        popup.Destroying:Connect(function()
            Library:_forgetPopup(popup)
            if moveConn then moveConn:Disconnect() end
            if endConn then endConn:Disconnect() end
            object.IsOpen = false
            setChevron(false)
            setThemeRole(buttonStroke, "Color", "Border")
        end)

        hexBox.FocusLost:Connect(function()
            if updating then return end
            local c = hexToColor(hexBox.Text)
            if c then
                h,s,v = c:ToHSV(); commitHSV()
            else
                updateFields(object.Value)
            end
        end)
        local function rgbFocus()
            if updating then return end
            local r = math.clamp(tonumber(rBox.Text) or object.Value.R*255,0,255)
            local g = math.clamp(tonumber(gBox.Text) or object.Value.G*255,0,255)
            local b = math.clamp(tonumber(bBox.Text) or object.Value.B*255,0,255)
            local c = Color3.fromRGB(r,g,b)
            h,s,v = c:ToHSV(); commitHSV()
        end
        rBox.FocusLost:Connect(rgbFocus); gBox.FocusLost:Connect(rgbFocus); bBox.FocusLost:Connect(rgbFocus)

        Library:_registerPopup(popup, object, button, closePopup)
        window:_tween(popup, 0.20, {GroupTransparency = 0})
        window:_tween(popupScale, 0.20, {Scale = 1})
    end

    button.MouseButton1Click:Connect(function()
        if object.Locked then return end
        if Library._openPopupOwner == object then
            Library:_closePopup()
        else
            Library:_closePopup()
            openPopup()
        end
    end)

    function object:Open()
        if not object.IsOpen then Library:_closePopup(); openPopup() end
    end

    function object:Close(immediate)
        if Library._openPopupOwner == object then Library:_closePopup(immediate == true) end
    end

    function object:IsExpanded()
        return object.IsOpen == true
    end

    -- Do not mark the theme's default accent as a user override merely because
    -- an accent picker exists. A saved value or an actual Set() call will apply it.
    if not window._appearanceReady and autoAccentPicker and data.Flag and window.ConfigData[data.Flag] ~= nil then
        window:SetThemeAccent(object.Value)
    elseif not window._appearanceReady and autoButtonPicker and data.Flag and window.ConfigData[data.Flag] ~= nil then
        window:SetButtonColor(object.Value)
    end
    if gradientKind then
        window:_registerThemeRenderer(function()
            if not row.Parent then return end
            local first, last = window:GetGradient(gradientKind)
            object:_Sync(gradientStop == "end" and last or first)
        end)
    end
    if autoAccentPicker then
        window._accentPicker = object
    elseif autoButtonPicker then
        window._buttonPicker = object
    end
    window:_registerFlag(data.Flag, object)
    object.Instance = row
    window:_indexControl(self, section, object, data, "ColorPicker")
    return object
end

function TabMethods:CreateLabel(text, sectionParent)
    local section = sectionParent or self._currentSection or self:CreateSection("INFORMATION", true, 1)
    local row = section:_row(1, true)
    local label = makeText(row, tostring(text or ""), 12, Theme.Muted, Enum.Font.Gotham)
    label.Position = UDim2.fromOffset(UIStyle.CardInset, 11)
    label.Size = UDim2.new(1, -(UIStyle.CardInset * 2), 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.TextWrapped = true
    label.TextYAlignment = Enum.TextYAlignment.Top

    local function refreshHeight()
        task.defer(function()
            if row.Parent and label.Parent then
                row.Size = UDim2.new(1, 0, 0, math.max(30, label.AbsoluteSize.Y + 22))
            end
        end)
    end
    label:GetPropertyChangedSignal("TextBounds"):Connect(refreshHeight)
    label:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshHeight)
    refreshHeight()

    local object = {}
    function object:Set(newText)
        label.Text = tostring(newText or "")
        refreshHeight()
    end
    object.Instance = row
    return object
end

function TabMethods:CreateParagraph(data, sectionParent)
    data = data or {}
    local window = self.Window
    local section = sectionParent or data.SectionParent or self._currentSection or self:CreateSection("INFORMATION", true, 1)
    local row = section:_row(1, true)
    attachDataTooltip(window, row, data)

    local content = create("Frame", {
        Parent = row,
        Position = UDim2.fromOffset(UIStyle.CardInset, 12),
        Size = UDim2.new(1, -(UIStyle.CardInset * 2), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    create("UIListLayout", {
        Parent = content,
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })

    local title = makeText(content, data.Title or "Paragraph", 14, Theme.Text, Enum.Font.GothamSemibold)
    title.Size = UDim2.new(1, 0, 0, 0)
    title.AutomaticSize = Enum.AutomaticSize.Y
    title.TextWrapped = true

    local body = makeText(content, data.Content or "", 12, Theme.Muted, Enum.Font.Gotham)
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top

    local function refreshHeight()
        task.defer(function()
            if row.Parent and content.Parent then
                row.Size = UDim2.new(1, 0, 0, math.max(40, content.AbsoluteSize.Y + 26))
            end
        end)
    end
    content:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshHeight)
    title:GetPropertyChangedSignal("TextBounds"):Connect(refreshHeight)
    body:GetPropertyChangedSignal("TextBounds"):Connect(refreshHeight)
    refreshHeight()

    local object = {}
    function object:Set(newData)
        if type(newData) == "table" then
            if newData.Title ~= nil then title.Text = tostring(newData.Title) end
            if newData.Content ~= nil then body.Text = tostring(newData.Content) end
            refreshHeight()
        end
    end
    object.Instance = row
    return object
end

function TabMethods:CreateKeybind(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.RowMinHeight)
    attachDataTooltip(window, row, data)
    rowText(row, data.Name or "Keybind", data.Info, 216)
    local behavior = tostring(data.Behavior or ""):lower():gsub("[%s_%-]", "")
    if behavior == "" and tostring(data.Name or ""):lower() == "toggle interface" then
        behavior = "toggleinterface"
    end
    local key = normalizeKeyName(
        window:_saved(data.Flag, data.CurrentKeybind or window:GetToggleKey()),
        window:GetToggleKey()
    )

    local button = create("TextButton", {
        Parent = row,
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-UIStyle.RowInset,0.5,0),
        Size = UDim2.fromOffset(200,UIStyle.ControlHeight),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = tostring(key),
        TextColor3 = Theme.Text,
        TextSize = UIStyle.FieldTextSize,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
    })
    attachRowControl(row, button, {Width = 150})
    corner(button,9)
    local buttonStroke = stroke(button,Theme.Border,1,0.24)
    local object = {Value = key, Listening = false}

    local function render()
        button.Text = object.Listening and "Press any key" or object.Value
        setThemeRole(buttonStroke, "Color", object.Listening and "AccentVisible" or "Border")
    end

    function object:Set(newKey, fire)
        local normalized = normalizeKeyName(newKey, nil)
        if not normalized then return false end
        object.Value = normalized
        object.Listening = false
        if window._capturingKeybind == object then window._capturingKeybind = nil end
        if behavior == "toggleinterface" then window:SetToggleKey(normalized) end
        render()
        if fire ~= false then safeCallback(data.Callback, object.Value) end
        window:_saveConfig()
        return true
    end
    function object:Get() return object.Value end

    function object:BeginCapture()
        if object.Locked then return false end
        if window._capturingKeybind and window._capturingKeybind ~= object then
            window._capturingKeybind:CancelCapture()
        end
        Library:_closePopup()
        window._capturingKeybind = object
        object.Listening = true
        render()
        window:_playSound("Open")
        return true
    end

    function object:CancelCapture()
        object.Listening = false
        if window._capturingKeybind == object then window._capturingKeybind = nil end
        render()
    end

    makeLockable(object, function(locked)
        button.Active = not locked
        setThemeRole(button, "TextColor3", locked and "Muted" or "Text")
        if locked and object.Listening then object:CancelCapture() end
    end)
    button.MouseButton1Click:Connect(function()
        if object.Locked then return end
        object:BeginCapture()
    end)

    window:_trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if object.Listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    object:CancelCapture()
                    window:_playSound("Close")
                elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                    object:Set(input.KeyCode, true)
                    window:_playSound("Confirm")
                end
            end
            return
        end
        if processed then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == object.Value then
            if behavior ~= "toggleinterface" then
                safeCallback(data.PressedCallback, object.Value)
            end
        end
    end))
    if behavior == "toggleinterface" then window:SetToggleKey(object.Value) end
    render()
    window:_registerFlag(data.Flag, object)
    object.Instance = row
    window:_indexControl(self, section, object, data, "Keybind")
    return object
end

function TabMethods:CreateStatus(data)
    data = data or {}
    local window = self.Window
    local section = self:_sectionFrom(data)
    local row = section:_row(UIStyle.StatusRowHeight, true)
    attachDataTooltip(window, row, data)
    create("Frame", {
        Parent = row, BackgroundColor3 = Theme.BorderSoft, BackgroundTransparency = 0.22,
        BorderSizePixel = 0, Position = UDim2.new(0, UIStyle.DividerInset, 1, -1),
        Size = UDim2.new(1, -(UIStyle.DividerInset * 2), 0, 1),
    })
    rowText(row, data.Name or "Status", data.Info, 152)

    local valueLabel = makeText(
        row,
        tostring(data.CurrentValue or data.Value or "Ready"),
        13,
        data.Color or Theme.Success,
        Enum.Font.GothamMedium,
        Enum.TextXAlignment.Right
    )
    valueLabel.AnchorPoint = Vector2.new(1, 0.5)
    valueLabel.Position = UDim2.new(1, -UIStyle.RowInset, 0.5, 0)
    valueLabel.Size = UDim2.fromOffset(140, 28)
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    attachRowControl(row, valueLabel, {Width = 140, Height = 28})

    local object = {Value = tostring(data.CurrentValue or data.Value or "Ready")}
    function object:Set(value, color)
        object.Value = tostring(value or "")
        valueLabel.Text = object.Value
        if typeof(color) == "Color3" then
            valueLabel.TextColor3 = color
        end
    end
    function object:Get() return object.Value end
    function object:SetVisible(visible) row.Visible = visible ~= false end
    object.Instance = row
    return object
end

local function statusEntryTitle(entry)
    entry = type(entry) == "table" and entry or {}
    return tostring(entry.Name or entry.name or entry.ModuleId or entry.moduleId or "Module")
end

local function statusEntryState(entry)
    entry = type(entry) == "table" and entry or {}
    return entry.State or entry.state or entry.Status or entry.status or entry.Level or entry.level or "testing"
end

local function statusDetailText(window, entry)
    entry = type(entry) == "table" and entry or {}
    local lines = {}
    local summary = entry.Summary or entry.summary
    local detail = entry.Detail or entry.detail
    local tooltip = entry.Tooltip or entry.tooltip

    -- The status label is already shown in the tooltip title. Avoid repeating it
    -- in the body, and only use the Tooltip field as fallback copy when the
    -- manifest does not provide a summary/detail.
    if summary and tostring(summary) ~= "" then
        table.insert(lines, tostring(summary))
    end
    if detail and tostring(detail) ~= "" and tostring(detail) ~= tostring(summary) then
        table.insert(lines, tostring(detail))
    end
    if #lines == 0 and tooltip and tostring(tooltip) ~= "" then
        table.insert(lines, tostring(tooltip))
    end

    local metadata = {}
    local version = entry.Version or entry.version
    local updatedAt = entry.UpdatedAt or entry.updatedAt
    if version and tostring(version) ~= "" then
        table.insert(metadata, "v" .. tostring(version):gsub("^[vV]", ""))
    end
    if updatedAt and tostring(updatedAt) ~= "" then
        local compactUpdated = tostring(updatedAt)
        compactUpdated = compactUpdated:gsub("T", " "):gsub("%.000Z$", " UTC"):gsub("Z$", " UTC")
        table.insert(metadata, compactUpdated)
    end
    if #metadata > 0 then
        table.insert(lines, table.concat(metadata, "  \194\183  "))
    end

    return table.concat(lines, "\n\n")
end

function SectionMethods:CreateStatusCard(data)
    data = type(data) == "table" and data or {}
    local window = self.Tab.Window
    local row = self:_row(94, true)
    row.ClipsDescendants = false

    local card = create("TextButton", {
        Parent = row,
        Position = UDim2.fromOffset(10, 7),
        Size = UDim2.new(1, -20, 1, -14),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
    })
    corner(card, 10)
    local cardStroke = stroke(card, Theme.Border, 1, 0.34)
    applySoftSurfaceGradient(card, window, "Surface3", "Surface2", 100)

    local glow = create("Frame", {
        Parent = card,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 22, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
    })
    corner(glow, 16)

    local dot = create("Frame", {
        Parent = card,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 22, 0.5, 0),
        Size = UDim2.fromOffset(9, 9),
        BorderSizePixel = 0,
    })
    corner(dot, 6)
    stroke(dot, Theme.Background, 1.5, 0.04)

    local nameLabel = makeText(card, "Module", 13, Theme.Text, Enum.Font.GothamSemibold)
    nameLabel.Position = UDim2.fromOffset(42, 11)
    nameLabel.Size = UDim2.new(1, -146, 0, 19)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextScaled = true
    create("UITextSizeConstraint", {
        Parent = nameLabel,
        MinTextSize = 9,
        MaxTextSize = 13,
    })

    local statusLabel = makeText(card, "In Testing", 11, Theme.Muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
    statusLabel.AnchorPoint = Vector2.new(1, 0)
    statusLabel.Position = UDim2.new(1, -12, 0, 11)
    statusLabel.Size = UDim2.fromOffset(94, 19)
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusLabel.TextScaled = true
    create("UITextSizeConstraint", {
        Parent = statusLabel,
        MinTextSize = 9,
        MaxTextSize = 11,
    })

    local summaryLabel = makeText(card, "Awaiting status information.", 11, Theme.Muted, Enum.Font.Gotham)
    summaryLabel.Position = UDim2.fromOffset(42, 34)
    summaryLabel.Size = UDim2.new(1, -56, 0, 34)
    summaryLabel.TextWrapped = true
    summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
    summaryLabel.LineHeight = 1.06

    local statusHoverTarget = create("TextButton", {
        Parent = card,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 22, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8,
    })

    local object = {Entry = cloneValue(data), Instance = row}
    local function render()
        local entry = object.Entry or {}
        local definition = window:_resolveStatusState(statusEntryState(entry))
        local color = definition.Color
        nameLabel.Text = statusEntryTitle(entry)
        statusLabel.Text = tostring(entry.Label or entry.label or definition.Label)
        statusLabel.TextColor3 = color
        setThemeRole(statusLabel, "TextColor3", nil)
        summaryLabel.Text = tostring(
            entry.Summary or entry.summary or entry.Detail or entry.detail or "No additional status details."
        )
        glow.BackgroundColor3 = definition.GlowColor or color
        dot.BackgroundColor3 = color
        setThemeRole(glow, "BackgroundColor3", nil)
        setThemeRole(dot, "BackgroundColor3", nil)
    end

    window:AttachTooltip(statusHoverTarget, function()
        return statusDetailText(window, object.Entry)
    end, {
        Title = function()
            local entry = object.Entry or {}
            local definition = window:_resolveStatusState(statusEntryState(entry))
            return statusEntryTitle(entry) .. "  \194\183  " .. tostring(entry.Label or entry.label or definition.Label)
        end,
        Color = function()
            return window:_resolveStatusState(statusEntryState(object.Entry)).Color
        end,
        Width = 310,
        Delay = 0.08,
        Placement = "side",
        Gap = 10,
    })

    card.MouseEnter:Connect(function()
        window:_tween(cardStroke, 0.14, {Transparency = 0.08})
        window:_tween(glow, 0.14, {BackgroundTransparency = 0.68})
    end)
    card.MouseLeave:Connect(function()
        window:_tween(cardStroke, 0.14, {Transparency = 0.34})
        window:_tween(glow, 0.14, {BackgroundTransparency = 0.82})
    end)

    function object:SetEntry(entry)
        self.Entry = cloneValue(entry or {})
        render()
    end
    function object:GetEntry() return cloneValue(self.Entry) end
    function object:SetVisible(visible) row.Visible = visible ~= false end
    function object:Destroy() if row.Parent then row:Destroy() end end
    render()
    return object
end

local function addOwnerBackground(window, tab)
    if not tab or not tab.PageClip or tab._ownerBackgroundAdded then return end
    tab._ownerBackgroundAdded = true
    local layer = create("Frame", {
        Parent = tab.PageClip,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        ZIndex = 0,
        ClipsDescendants = true,
    })

    local colors = {
        Theme.AccentVisible,
        Color3.fromRGB(53, 217, 255),
        Theme.Accent,
    }
    local orbs = {}
    for index, color in ipairs(colors) do
        local orb = create("Frame", {
            Parent = layer,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.18 + index * 0.2, 0.2 + index * 0.16),
            Size = UDim2.fromOffset(150 + index * 24, 150 + index * 24),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.94,
            BorderSizePixel = 0,
            ZIndex = 0,
        })
        corner(orb, 999)
        setThemeRole(orb, "BackgroundColor3", nil)
        table.insert(orbs, orb)
    end

    local elapsed = 0
    window:_trackConnection(RunService.Heartbeat:Connect(function(dt)
        if not layer.Parent or not tab.PageClip.Visible then return end
        if window.Motion.Enabled == false or window.Motion.ReducedMotion then return end
        elapsed = elapsed + dt * 0.22
        for index, orb in ipairs(orbs) do
            local phase = elapsed + index * 2.1
            orb.Position = UDim2.fromScale(
                0.50 + math.sin(phase * 0.73) * (0.25 - index * 0.025),
                0.48 + math.cos(phase * 0.91) * (0.22 - index * 0.02)
            )
        end
    end))
    tab.OwnerBackground = layer
end

function WindowMethods:_refreshOwnerStatusCards()
    if not self.OwnerDashboard or not self.OwnerDashboard.StatusSections then return false end
    local manifest = self.StatusManifest
    local games = type(manifest) == "table" and (manifest.Games or manifest.games) or nil
    if type(games) ~= "table" then return false end

    local entries = {}
    for gameId, rawEntry in pairs(games) do
        if type(rawEntry) == "table" then
            local entry = cloneValue(rawEntry)
            entry.GameId = entry.GameId or tonumber(gameId) or tostring(gameId)
            table.insert(entries, entry)
        end
    end
    table.sort(entries, function(a, b)
        return statusEntryTitle(a):lower() < statusEntryTitle(b):lower()
    end)

    local visible = {}
    for index, entry in ipairs(entries) do
        local key = tostring(entry.ModuleId or entry.moduleId or entry.GameId or index)
        visible[key] = true
        local card = self.OwnerDashboard.Cards[key]
        if not card then
            local section = self.OwnerDashboard.StatusSections[((index - 1) % #self.OwnerDashboard.StatusSections) + 1]
            card = section:CreateStatusCard(entry)
            self.OwnerDashboard.Cards[key] = card
        else
            card:SetEntry(entry)
            card:SetVisible(true)
        end
    end

    for key, card in pairs(self.OwnerDashboard.Cards) do
        if not visible[key] then card:SetVisible(false) end
    end

    if self.OwnerDashboard.RefreshLabel then
        local liveInfo = type(self.OwnerLiveServiceInfo) == "table" and self.OwnerLiveServiceInfo or {}
        local sourceName = tostring(self.StatusManifestSource or "")
        local source

        if sourceName == "cloudflare-live" then
            source = "Cloudflare Live"
        elseif sourceName == "remote" then
            source = "statusLS.json fallback"
        elseif sourceName == "local" then
            source = "Local fallback"
        else
            source = sourceName ~= "" and sourceName or "Status source unknown"
        end

        local details = {source, tostring(#entries) .. " modules"}
        if sourceName == "cloudflare-live" then
            local transport = tostring(liveInfo.Transport or "websocket")
            local connected = liveInfo.Connected == true
            table.insert(details, connected and (transport .. " connected") or (transport .. " reconnecting"))
            if tonumber(liveInfo.ConnectedClients) then
                table.insert(details, tostring(math.max(0, math.floor(tonumber(liveInfo.ConnectedClients)))) .. " clients")
            end
        else
            table.insert(details,
                "refreshes every "
                .. tostring(math.max(5, tonumber(self.Settings.StatusControl and self.Settings.StatusControl.PollInterval) or 5))
                .. " seconds"
            )
        end

        self.OwnerDashboard.RefreshLabel:Set(table.concat(details, "  \194\183  "))
    end
    return true
end

function WindowMethods:SetOwnerLiveServiceInfo(info)
    self.OwnerLiveServiceInfo = type(info) == "table" and cloneValue(info) or {}
    if type(self._refreshOwnerStatusCards) == "function" then
        pcall(function() self:_refreshOwnerStatusCards() end)
    end
    return cloneValue(self.OwnerLiveServiceInfo)
end

function WindowMethods:GetOwnerLiveServiceInfo()
    return cloneValue(self.OwnerLiveServiceInfo or {})
end

function WindowMethods:BuildOwnerDashboard()
    if not self.OwnerInfo or self.OwnerInfo.IsOwner ~= true then return false end
    if self.OwnerDashboard and self.OwnerDashboard.Tab then
        self:_refreshOwnerStatusCards()
        return true
    end

    local tab = self:CreateTab("Owner", "owner")

    -- Visually separate private owner controls from game/module navigation.
    -- CreateTab assigns tabs in steps of 10, so this divider sits between the
    -- Owner tab (10) and the first game tab (20) without affecting later tabs.
    if self.NavList and not self.OwnerNavDivider then
        local dividerHolder = create("Frame", {
            Parent = self.NavList,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 12),
            LayoutOrder = (tab.NavButton and tab.NavButton.LayoutOrder or 10) + 5,
        })
        local dividerLine = create("Frame", {
            Parent = dividerHolder,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -16, 0, 1),
            BackgroundColor3 = Theme.BorderSoft,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
        })
        setThemeRole(dividerLine, "BackgroundColor3", "BorderSoft")
        self.OwnerNavDivider = dividerHolder
    end

    addOwnerBackground(self, tab)

    local profile = tab:CreateSection({
        Name = "Owner access",
        Description = "Private hub operations and live deployment health.",
        Icon = "roblox",
        Column = 1,
    })
    local profileRow = profile:_row(112, true)
    profileRow.ClipsDescendants = false

    local avatar = create("ImageLabel", {
        Parent = profileRow,
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(78, 78),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
    })
    corner(avatar, 39)
    stroke(avatar, Theme.AccentVisible, 2, 0.12)

    local greeting = makeText(
        profileRow,
        "Welcome back, " .. tostring(self.OwnerInfo.DisplayName or self.OwnerInfo.Username or "Owner"),
        16,
        Theme.Text,
        Enum.Font.GothamSemibold
    )
    greeting.Position = UDim2.fromOffset(108, 20)
    greeting.Size = UDim2.new(1, -124, 0, 25)
    greeting.TextTruncate = Enum.TextTruncate.AtEnd

    local ownerTag = makeText(profileRow, "VITALITY OWNER", 11, Theme.AccentVisible, Enum.Font.GothamBold)
    ownerTag.Position = UDim2.fromOffset(108, 49)
    ownerTag.Size = UDim2.new(1, -124, 0, 18)

    local username = makeText(
        profileRow,
        "@" .. tostring(self.OwnerInfo.Username or "owner") .. "  \194\183  " .. tostring(self.OwnerInfo.UserId or "unknown"),
        11,
        Theme.Muted,
        Enum.Font.Gotham
    )
    username.Position = UDim2.fromOffset(108, 71)
    username.Size = UDim2.new(1, -124, 0, 18)
    username.TextTruncate = Enum.TextTruncate.AtEnd

    self:AttachTooltip(profileRow,
        "Owner access was matched with the numeric Roblox UserId configured directly in the loader.",
        {Title = "Verified owner interface", Width = 330}
    )

    task.spawn(function()
        local ok, image = pcall(
            Players.GetUserThumbnailAsync,
            Players,
            tonumber(self.OwnerInfo.UserId) or LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size420x420
        )
        if ok and avatar.Parent then avatar.Image = image end
    end)

    local liveLeft = tab:CreateSection({
        Name = "Module status",
        Description = "Hover a card for deployment details.",
        Icon = "pulse",
        Column = 1,
    })
    local liveRight = tab:CreateSection({
        Name = "Module status",
        Description = "Updates are pushed live from the Vitality Cloudflare service.",
        Icon = "pulse",
        Column = 2,
    })
    local delivery = tab:CreateSection({
        Name = "Status delivery",
        Description = "Live service connection and fallback status information.",
        Icon = "info",
        Column = 2,
    })
    local refreshLabel = delivery:CreateLabel("Connecting to Vitality Live...")

    self.OwnerDashboard = {
        Tab = tab,
        Cards = {},
        StatusSections = {liveLeft, liveRight},
        RefreshLabel = refreshLabel,
        Avatar = avatar,
    }
    self:_refreshOwnerStatusCards()
    return true
end

function TabMethods:CreateThemeDropdown(data)
    data = data or {}
    data.Options = data.Options or {"Dark", "Light", "System"}
    data.CurrentOption = data.CurrentOption or self.Window:GetTheme()
    data.ThemeSelector = true
    return self:CreateDropdown(data)
end

function TabMethods:CreateAccentPicker(data)
    data = data or {}
    data.Color = data.Color or Theme.Accent
    data.AccentPicker = true
    return self:CreateColorPicker(data)
end

function TabMethods:CreateButtonPicker(data)
    data = data or {}
    data.Color = data.Color or Theme.Button
    data.ButtonPicker = true
    return self:CreateColorPicker(data)
end

function TabMethods:CreateGradientPicker(data)
    data = data or {}
    data.GradientKind = data.GradientKind or data.Kind or "Button"
    data.GradientStop = data.GradientStop or data.Stop or "Start"
    return self:CreateColorPicker(data)
end

local function sectionElementData(section, data)
    data = data or {}
    data.SectionParent = section
    return data
end

function SectionMethods:CreateButton(data)
    return self.Tab:CreateButton(sectionElementData(self, data))
end

function SectionMethods:CreateToggle(data)
    return self.Tab:CreateToggle(sectionElementData(self, data))
end

function SectionMethods:CreateSlider(data)
    return self.Tab:CreateSlider(sectionElementData(self, data))
end

function SectionMethods:CreateInput(data)
    return self.Tab:CreateInput(sectionElementData(self, data))
end

function SectionMethods:CreateDropdown(data)
    return self.Tab:CreateDropdown(sectionElementData(self, data))
end

function SectionMethods:CreateThemeDropdown(data)
    return self.Tab:CreateThemeDropdown(sectionElementData(self, data))
end

function SectionMethods:CreateColorPicker(data)
    return self.Tab:CreateColorPicker(sectionElementData(self, data))
end

function SectionMethods:CreateAccentPicker(data)
    return self.Tab:CreateAccentPicker(sectionElementData(self, data))
end

function SectionMethods:CreateButtonPicker(data)
    return self.Tab:CreateButtonPicker(sectionElementData(self, data))
end

function SectionMethods:CreateGradientPicker(data)
    return self.Tab:CreateGradientPicker(sectionElementData(self, data))
end

function SectionMethods:CreateKeybind(data)
    return self.Tab:CreateKeybind(sectionElementData(self, data))
end

function SectionMethods:CreateStatus(data)
    return self.Tab:CreateStatus(sectionElementData(self, data))
end

function SectionMethods:CreateLabel(text)
    return self.Tab:CreateLabel(text, self)
end

function SectionMethods:CreateParagraph(data)
    return self.Tab:CreateParagraph(data or {}, self)
end

function SectionMethods:SetVisible(visible)
    self.Frame.Visible = visible ~= false
end

function SectionMethods:Lock(reason)
    self.Locked = true
    self.LockReason = reason or "Locked"
end

function SectionMethods:Unlock()
    self.Locked = false
end

function WindowMethods:ShowLoading(data)
    data = type(data) == "table" and data or {}
    if self._loadingController then self._loadingController:Destroy() end

    local overlay = create("CanvasGroup", {
        Name = "NovaLoading",
        Parent = self.Gui,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.08,
        GroupTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 380,
    })
    local card = create("Frame", {
        Parent = overlay,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 12),
        Size = UDim2.fromOffset(UIStyle.LoaderWidth, UIStyle.LoaderHeight),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 381,
    })
    corner(card, 12)
    stroke(card, Theme.AccentVisible, 1, 0.65)
    applySoftSurfaceGradient(card, self, "Surface2", "Background", 110)

    local headerIcon = createIcon(card, self.BrandIcon or self.Settings.Icon or "vitality", "vitality")
    headerIcon.Position = UDim2.fromOffset(20, 20)
    headerIcon.Size = UDim2.fromOffset(22, 22)
    headerIcon.ZIndex = 383
    setIconColor(headerIcon, Theme.AccentVisible)
    for _, part in ipairs(headerIcon:GetDescendants()) do if part:IsA("GuiObject") then part.ZIndex = 384 end end
    local header = makeText(card, "vitality", 13, Theme.Text, Enum.Font.GothamMedium)
    header.Position = UDim2.fromOffset(54, 17)
    header.Size = UDim2.new(1, -62, 0, 28)
    header.ZIndex = 382
    create("Frame", {
        Parent = card,
        Position = UDim2.fromOffset(20, 58),
        Size = UDim2.new(1, -40, 0, 1),
        BackgroundColor3 = Theme.BorderSoft,
        BorderSizePixel = 0,
        ZIndex = 382,
    })

    local spinner = create("Frame", {
        Parent = card,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 151),
        Size = UDim2.fromOffset(64, 64),
        BackgroundTransparency = 1,
        ZIndex = 382,
    })
    local track = create("Frame", {
        Parent = spinner,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(58, 58),
        BackgroundTransparency = 1,
        ZIndex = 382,
    })
    corner(track, 29)
    stroke(track, Theme.BorderSoft, 1, 0.64)
    for index = 1, 12 do
        local angle = math.rad((index - 1) * 30 - 90)
        local dot = create("Frame", {
            Parent = spinner,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.cos(angle) * 29, 0.5, math.sin(angle) * 29),
            Size = UDim2.fromOffset(5, 5),
            BackgroundColor3 = Theme.AccentVisible,
            BackgroundTransparency = math.clamp((index - 1) / 13, 0.05, 0.82),
            BorderSizePixel = 0,
            ZIndex = 384,
        })
        corner(dot, 4)
        local function repaintDot()
            if not dot.Parent then return end
            local first, last = self:GetGradient("accent")
            if not self:GetGradientOptions("accent").Enabled then last = first end
            setThemeRole(dot, "BackgroundColor3", nil)
            dot.BackgroundColor3 = first:Lerp(last, (index - 1) / 11)
        end
        repaintDot()
        self:_registerThemeRenderer(repaintDot)
        if index == 1 then
            local halo = create("Frame", {Parent = dot, AnchorPoint = Vector2.new(0.5,0.5),
                Position = UDim2.fromScale(0.5,0.5), Size = UDim2.fromOffset(11,11),
                BackgroundColor3 = Theme.AccentVisible, BackgroundTransparency = 0.86,
                BorderSizePixel = 0, ZIndex = 383})
            corner(halo,6)
        end
    end
    local title = makeText(card, data.Title or self.Settings.LoadingTitle or self.Settings.Name or "vitality's hub", 18, Theme.Text, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
    title.Position = UDim2.fromOffset(20, 218)
    title.Size = UDim2.new(1, -40, 0, 26)
    title.ZIndex = 382
    local status = makeText(card, data.Status or self.Settings.LoadingSubtitle or "Loading components...", 11, Theme.Muted, Enum.Font.Gotham, Enum.TextXAlignment.Center)
    status.Position = UDim2.fromOffset(20, 252)
    status.Size = UDim2.new(1, -40, 0, 48)
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.LineHeight = 1.1
    status.ZIndex = 382

    local progressTrack = create("Frame", {
        Parent = card,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 20, 1, -40),
        Size = UDim2.new(1, -72, 0, 6),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        ZIndex = 382,
    })
    corner(progressTrack, 3)
    local progressFill = create("Frame", {
        Parent = progressTrack,
        Size = UDim2.new(math.clamp(tonumber(data.Progress) or 0.08, 0, 1), 0, 1, 0),
        BackgroundColor3 = Theme.AccentVisible,
        BorderSizePixel = 0,
        ZIndex = 383,
    })
    corner(progressFill, 3)
    applyThemeGradient(progressFill, self, "accent")
    local percent = makeText(card, "8%", 11, Theme.Muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
    percent.AnchorPoint = Vector2.new(0, 0.5)
    percent.Position = UDim2.new(1, -50, 1, -43)
    percent.Size = UDim2.fromOffset(34, 24)
    percent.ZIndex = 382

    local cardScale = create("UIScale", {Parent = card, Scale = 1})
    local function fitLoader()
        if not card.Parent then return end
        local statusHeight = math.ceil(textSize(status, UIStyle.LoaderWidth - 40).Y * 1.1) + 4
        local titleHeight = math.ceil(textSize(title, UIStyle.LoaderWidth - 40).Y) + 4
        title.TextWrapped = true
        title.Size = UDim2.new(1,-40,0,math.max(26,titleHeight))
        local statusY = 218 + math.max(26,titleHeight) + 8
        status.Position = UDim2.fromOffset(20,statusY)
        status.Size = UDim2.new(1,-40,0,math.max(48,statusHeight))
        local height = math.max(UIStyle.LoaderHeight,statusY + statusHeight + 82)
        card.Size = UDim2.fromOffset(UIStyle.LoaderWidth,height)
        local camera = workspace.CurrentCamera
        if camera then
            cardScale.Scale = math.min(1, (camera.ViewportSize.X - 32) / UIStyle.LoaderWidth, (camera.ViewportSize.Y - 40) / height)
        end
    end
    status:GetPropertyChangedSignal("Text"):Connect(fitLoader)
    status:GetPropertyChangedSignal("Font"):Connect(fitLoader)
    title:GetPropertyChangedSignal("Font"):Connect(fitLoader)
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitLoader)
    fitLoader()
    local spinnerTween = TweenService:Create(spinner, TweenInfo.new(1.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
    spinnerTween:Play()
    local selfWindow = self
    local controller = {Instance = overlay, Progress = tonumber(data.Progress) or 0.08, _statusToken = 0}

    function controller:SetStatus(text)
        self._statusToken = self._statusToken + 1
        local token = self._statusToken
        selfWindow:_tween(status, 0.10, {TextTransparency = 1}, Enum.EasingStyle.Quad)
        task.delay(selfWindow:_motionDuration(0.10), function()
            if not status.Parent or self._statusToken ~= token then return end
            status.Text = tostring(text or "")
            selfWindow:_tween(status, 0.18, {TextTransparency = 0}, Enum.EasingStyle.Quint)
        end)
    end

    function controller:SetProgress(value, animate)
        self.Progress = math.clamp(tonumber(value) or self.Progress or 0, 0, 1)
        percent.Text = tostring(math.floor(self.Progress * 100 + 0.5)) .. "%"
        local goal = {Size = UDim2.new(self.Progress, 0, 1, 0)}
        if animate == false then
            progressFill.Size = goal.Size
        else
            selfWindow:_tween(progressFill, 0.24, goal, Enum.EasingStyle.Quint)
        end
    end

    -- Advances the loader through a readable stage. The hold is intentional:
    -- without it, several synchronous startup states can be replaced before
    -- Roblox renders even a single frame, making only the final status visible.
    function controller:Step(text, progress, holdSeconds)
        if not overlay.Parent then return false end
        if text ~= nil then self:SetStatus(text) end
        if progress ~= nil then self:SetProgress(progress, true) end

        local hold = math.max(tonumber(holdSeconds) or 0, 0)
        if hold > 0 then
            task.wait(hold)
        else
            -- Yield at least one scheduler step so an immediate caller can still
            -- make the new state visible before replacing it.
            task.wait()
        end
        return overlay.Parent ~= nil
    end

    function controller:Finish(finalStatus, callback)
        if self._finishing then return end
        self._finishing = true
        if finalStatus then self:SetStatus(finalStatus) end
        self:SetProgress(1, true)
        task.delay(selfWindow:_motionDuration(0.38), function()
            if not overlay.Parent then return end
            spinnerTween:Cancel()
            selfWindow:_tween(overlay, 0.34, {GroupTransparency = 1}, Enum.EasingStyle.Quint)
            task.delay(selfWindow:_motionDuration(0.35), function()
                if overlay.Parent then overlay:Destroy() end
                if selfWindow._loadingController == self then selfWindow._loadingController = nil end
                safeCallback(callback)
            end)
        end)
    end

    function controller:Destroy()
        pcall(function() spinnerTween:Cancel() end)
        if overlay.Parent then overlay:Destroy() end
        if selfWindow._loadingController == self then selfWindow._loadingController = nil end
    end

    controller:SetProgress(controller.Progress, false)
    self._loadingController = controller
    self:_tween(overlay, 0.34, {GroupTransparency = 0}, Enum.EasingStyle.Quint)
    self:_tween(card, 0.34, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Quint)
    return controller
end

function WindowMethods:SetLoadingStatus(text)
    if self._loadingController then self._loadingController:SetStatus(text) end
end

function WindowMethods:SetLoadingProgress(value, animate)
    if self._loadingController then self._loadingController:SetProgress(value, animate) end
end

function WindowMethods:FinishLoading(status, callback)
    if self._loadingController then
        self._loadingController:Finish(status, callback)
    else
        safeCallback(callback)
    end
end

local function collectKeyEntries(settings)
    local entries, seen = {}, {}
    local function add(keyValue, specification)
        if keyValue == nil then return end
        local keyText = tostring(keyValue)
        if keyText == "" or seen[keyText] then return end
        specification = type(specification) == "table" and specification or {}
        seen[keyText] = true
        table.insert(entries, {
            Key = keyText,
            Duration = tonumber(specification.Duration or specification.DurationSeconds or specification.Seconds),
            ExpiresAt = tonumber(specification.ExpiresAt or specification.Expiration),
            Label = specification.Label,
        })
    end

    local primary = settings.Key
    if type(primary) == "table" then
        if primary.Key then
            add(primary.Key, primary)
        else
            for _, value in pairs(primary) do
                if type(value) == "table" then add(value.Key or value.Value, value) else add(value) end
            end
        end
    else
        add(primary)
    end

    if type(settings.Keys) == "table" then
        for index, value in pairs(settings.Keys) do
            if type(value) == "table" then
                add(value.Key or value.Value or (type(index) == "string" and index or nil), value)
            elseif type(index) == "string" and type(value) == "number" then
                add(index, {Duration = value})
            else
                add(value)
            end
        end
    end
    return entries
end

local function findKeyEntry(entries, input)
    local candidate = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    for _, entry in ipairs(entries) do
        if entry.Key == candidate then return entry end
    end
end

local function keySessionFor(entry, previous)
    local now = os.time()
    local activatedAt = tonumber(previous and previous.ActivatedAt) or now
    local expiresAt = tonumber(previous and previous.ExpiresAt) or entry.ExpiresAt
    if not expiresAt and entry.Duration and entry.Duration > 0 then
        expiresAt = activatedAt + entry.Duration
    end
    return {
        Version = 1,
        Key = entry.Key,
        Label = entry.Label,
        ActivatedAt = activatedAt,
        ExpiresAt = expiresAt,
    }
end

local function keyStoragePath(settings)
    local folder = tostring(settings.FolderName or "NovaFieldKeys")
    local fileName = tostring(settings.FileName or "NovaKey"):gsub("[^%w%-%_]", "_")
    if type(makefolder) == "function" then
        pcall(function()
            if type(isfolder) ~= "function" or not isfolder(folder) then makefolder(folder) end
        end)
    end
    return folder .. "/" .. fileName .. ".json"
end

local function saveKeySession(path, session)
    if type(writefile) ~= "function" then return false end
    session = type(session) == "table" and session or {}
    if session.Version == nil then session.Version = 2 end
    session.SavedAt = os.time()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, session)
    if not ok then return false end
    return pcall(writefile, path, encoded)
end

local function timedKeyStoragePath(settings)
    local basePath = keyStoragePath(settings)
    return basePath:gsub("%.json$", "") .. "_timed.json"
end

local function isTimedKeyEntry(entry)
    if not entry then return false end
    if tonumber(entry.ExpiresAt) then return true end
    return (tonumber(entry.Duration) or 0) > 0
end

local function clearStoredKey(path)
    if not path then return false end
    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, path)
        if ok and not exists then return true end
    end
    if type(delfile) == "function" then
        local ok = pcall(delfile, path)
        if ok then return true end
    end
    if type(writefile) == "function" then
        return pcall(writefile, path, "")
    end
    return false
end

local function loadTimedKeySessions(path)
    local sessions = {}
    if not path or type(isfile) ~= "function" or type(readfile) ~= "function" then
        return sessions
    end

    local ok, stored = pcall(function()
        if isfile(path) then return readfile(path) end
    end)
    if not ok or not stored or stored == "" then return sessions end

    local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, stored)
    if not decodeOk or type(decoded) ~= "table" then return sessions end

    if decoded.Key then
        sessions[tostring(decoded.Key)] = decoded
        return sessions
    end

    local source = type(decoded.Sessions) == "table" and decoded.Sessions or decoded
    for keyValue, session in pairs(source) do
        if type(session) == "table" then
            local sessionKey = tostring(session.Key or keyValue)
            if sessionKey ~= "" then
                sessions[sessionKey] = session
            end
        end
    end
    return sessions
end

local function saveTimedKeySessions(path, sessions)
    if not path or type(writefile) ~= "function" then return false end
    local payload = {
        Version = 1,
        Sessions = sessions or {},
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
    if not ok then return false end
    return pcall(writefile, path, encoded)
end

function WindowMethods:ForgetSavedKey()
    local settings = type(self.Settings.KeySettings) == "table"
        and self.Settings.KeySettings
        or {}

    self._keyRemoteRefreshToken = (self._keyRemoteRefreshToken or 0) + 1
    self._keyCountdownToken = (self._keyCountdownToken or 0) + 1

    local removedMain = clearStoredKey(keyStoragePath(settings))
    local removedTimed = clearStoredKey(timedKeyStoragePath(settings))

    self.ActiveKey = nil
    self.RemoteKeyInfo = nil
    self.KeySession = nil
    self._expiredKickSent = false

    if self.KeyTimeLabel then
        self.KeyTimeLabel.Text = ""
        self.KeyTimeLabel.Visible = false
        self:_refreshStatusChipLayout()
    end

    return removedMain or removedTimed
end

local function buildKeySystem(window)
    local settings = window.Settings.KeySettings or {}
    if not window.Settings.KeySystem then return true end

    local remoteValidator = settings.RemoteValidator or settings.Validator

    local function trimKey(value)
        return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end

    -- Remote validators let Vitality keep its own key UI while delegating actual
    -- authentication/expiry decisions to a service such as KeyAuth.
    --
    -- Supported callback forms:
    --   return true,  {Message="Logged in", ExpiresAt=..., Permanent=false}
    --   return false, {Message="Invalid license"}
    --   return {Success=true, ...}
    local function validateRemote(candidate, isAuto)
        if type(remoteValidator) ~= "function" then
            return nil, nil
        end

        candidate = trimKey(candidate)
        if candidate == "" then
            return false, {Message = "Enter a key to continue."}
        end

        local ok, first, second = pcall(remoteValidator, candidate, {
            Window = window,
            Settings = settings,
            Auto = isAuto == true,
        })

        if not ok then
            return false, {
                Message = "Authentication service unavailable.",
                Error = tostring(first),
                Provider = settings.Provider or "Remote",
            }
        end

        local success
        local info

        if type(first) == "table" and second == nil then
            info = first
            success = info.Success == true
        else
            success = first == true
            if type(second) == "table" then
                info = second
            else
                info = {
                    Message = second ~= nil and tostring(second) or nil,
                }
            end
        end

        info = type(info) == "table" and info or {}
        info.Success = success
        info.Provider = info.Provider or settings.Provider or "Remote"

        return success, info
    end

    if settings.GrabKeyFromSite and type(settings.Key) == "string" and settings.Key:match("^https?://") then
        local ok, result = pcall(function() return game:HttpGet(settings.Key) end)
        if ok then settings.Key = result:gsub("%s+$","") end
    end

    local entries = collectKeyEntries(settings)
    local saveKey = settings.SaveKey ~= false
    local savedPath = saveKey and keyStoragePath(settings) or nil
    local timedPath = saveKey and timedKeyStoragePath(settings) or nil
    local timedSessions = saveKey and loadTimedKeySessions(timedPath) or {}

    local function remoteSessionFromInfo(candidate, info)
        info = type(info) == "table" and info or {}

        local expiresAt =
            tonumber(
                info.ExpiresAt
                or info.Expiry
                or info.expiry
            )

        local permanent =
            info.Permanent == true
            or (
                info.Permanent == nil
                and not expiresAt
            )

        local lifetimeLike =
            info.LifetimeLike == true
            or permanent

        return {
            Version = 2,
            Key = candidate,
            Remote = true,
            Provider =
                info.Provider
                or settings.Provider
                or "Remote",
            ExpiresAt = permanent and nil or expiresAt,
            Permanent = permanent,
            LifetimeLike = lifetimeLike,
            ExpiryReliable = info.ExpiryReliable ~= false,
            EnforceLocalExpiry = info.ExpiryReliable ~= false,
            Subscription = info.Subscription,
            IdentityVersion = tonumber(info.IdentityVersion or settings.IdentityVersion),
            IdentitySource = info.IdentitySource,
        }
    end

    local function canAutoReuseSession(session)
        if type(session) ~= "table" then return false end

        -- Saved REMOTE keys are never trusted blindly: the startup path below
        -- ALWAYS revalidates the key with the configured remote validator
        -- before unlocking Vitality. Because of that, there is no security or
        -- expiry benefit to forcing the user to type a still-valid key again.
        --
        -- Keep an explicit opt-out for deployments that truly do not want any
        -- remote key persistence.
        if session.Remote == true or session.Provider ~= nil then
            return settings.AutoReuseRemoteKeys ~= false
        end

        if session.Permanent == true then return true end
        if session.LifetimeLike == true and settings.AutoReuseLongTermKeys ~= false then
            return true
        end
        return settings.AutoReuseTemporaryKeys == true
    end

    local function expireRemoteSession(candidate, info, message)
        window._keyRemoteRefreshToken =
            (window._keyRemoteRefreshToken or 0) + 1

        if saveKey then
            clearStoredKey(savedPath)
        end

        window.RemoteKeyInfo = info
        window:SetScriptStatus("red", "Key expired")

        pcall(function()
            window:Notify({
                Title = "License expired",
                Content =
                    message
                    or "Your KeyAuth license is no longer valid.",
                Duration = 5,
                Type = "Error",
            })
        end)

        -- Only confirmed expiration reaches this path. The local countdown then
        -- preserves the existing exact expiry kick behavior.
        window:SetKeySession({
            Version = 2,
            Key = candidate,
            Remote = true,
            Provider =
                (type(info) == "table" and info.Provider)
                or settings.Provider
                or "Remote",
            ExpiresAt = os.time(),
            Permanent = false,
            LifetimeLike = false,
            ExpiryReliable = true,
            EnforceLocalExpiry = true,
            IdentityVersion = tonumber(
                type(info) == "table"
                and info.IdentityVersion
                or settings.IdentityVersion
            ),
        })
    end

    local function rejectRemoteSession(candidate, info, message)
        window._keyRemoteRefreshToken =
            (window._keyRemoteRefreshToken or 0) + 1

        if saveKey then
            clearStoredKey(savedPath)
        end

        window.RemoteKeyInfo = info
        window.ActiveKey = nil
        window:SetKeySession(nil)
        window:SetScriptStatus("red", "License rejected")

        pcall(function()
            window:Notify({
                Title =
                    type(info) == "table"
                    and info.HWIDMismatch == true
                    and "HWID reset required"
                    or "License rejected",
                Content =
                    message
                    or "KeyAuth rejected this license. Re-execute Vitality and enter another key.",
                Duration = 7,
                Type = "Error",
            })
        end)

        -- Stop the protected module without kicking the player. The cleared
        -- local cache means the next loader execution opens the key prompt.
        task.delay(1.25, function()
            if window
                and not window._destroyed
                and type(window.Destroy) == "function" then
                window:Destroy()
            end
        end)
    end

    local function startRemoteRefreshLoop(candidate)
        if type(remoteValidator) ~= "function" then
            return
        end

        candidate = trimKey(candidate)
        if candidate == "" then
            return
        end

        window._keyRemoteRefreshToken =
            (window._keyRemoteRefreshToken or 0) + 1

        local token =
            window._keyRemoteRefreshToken

        local refreshInterval =
            math.max(
                tonumber(
                    settings.RemoteRefreshInterval
                    or settings.RefreshInterval
                ) or 30,
                5
            )

        local graceCount =
            math.max(
                tonumber(settings.RemoteFailureGraceCount) or 3,
                1
            )

        local graceSeconds =
            math.max(
                tonumber(settings.RemoteFailureGraceSeconds) or 120,
                refreshInterval
            )

        task.spawn(function()
            local failureCount = 0
            local firstFailureAt = nil
            local warnedTransient = false

            while window.Gui
                and window.Gui.Parent
                and not window._destroyed
                and window._keyRemoteRefreshToken == token
                and window.ActiveKey == candidate do

                task.wait(refreshInterval)

                if not window.Gui
                    or not window.Gui.Parent
                    or window._destroyed
                    or window._keyRemoteRefreshToken ~= token
                    or window.ActiveKey ~= candidate then

                    break
                end

                local accepted, info =
                    validateRemote(
                        candidate,
                        true
                    )

                if not accepted then
                    info = type(info) == "table" and info or {}
                    local message =
                        info.Message
                        or info.message
                        or "KeyAuth validation failed."

                    if info.Expired == true then
                        expireRemoteSession(
                            candidate,
                            info,
                            "this key has expired and is not usable!"
                        )
                        break
                    end

                    local retryable =
                        info.Retryable == true
                        or info.Transient == true

                    if retryable then
                        failureCount = failureCount + 1
                        firstFailureAt = firstFailureAt or os.time()

                        local elapsed = os.time() - firstFailureAt
                        if not warnedTransient
                            and (
                                failureCount >= graceCount
                                or elapsed >= graceSeconds
                            ) then

                            warnedTransient = true
                            pcall(function()
                                window:Notify({
                                    Title = "KeyAuth temporarily unavailable",
                                    Content = "Your current license was kept active while Vitality retries validation. You will not be kicked for a network/API failure.",
                                    Duration = 6,
                                    Type = "Warning",
                                })
                            end)
                        end
                    else
                        rejectRemoteSession(
                            candidate,
                            info,
                            message
                        )
                        break
                    end
                else
                    failureCount = 0
                    firstFailureAt = nil
                    warnedTransient = false

                    local session =
                        remoteSessionFromInfo(
                            candidate,
                            info
                        )

                    if session.ExpiresAt
                        and session.EnforceLocalExpiry ~= false
                        and session.ExpiresAt <= os.time() then

                        expireRemoteSession(
                            candidate,
                            info,
                            "Your KeyAuth license has expired."
                        )
                        break
                    end

                    -- Replace the cached session only after a successful server
                    -- validation. Temporary network errors never rewrite expiry.
                    window.RemoteKeyInfo = info
                    window:SetKeySession(session)

                    if saveKey then
                        if canAutoReuseSession(session) then
                            saveKeySession(
                                savedPath,
                                session
                            )
                        else
                            clearStoredKey(savedPath)
                        end
                    end
                end
            end
        end)
    end

    -- Saved REMOTE keys are revalidated before reuse. Short-lived temporary
    -- licenses are intentionally not auto-used unless explicitly enabled.
    if type(remoteValidator) == "function"
        and saveKey
        and type(isfile) == "function"
        and type(readfile) == "function"
    then
        local ok, stored = pcall(function()
            if isfile(savedPath) then return readfile(savedPath) end
        end)

        if ok and stored and stored ~= "" then
            local decoded
            local decodeOk, result = pcall(HttpService.JSONDecode, HttpService, stored)
            if decodeOk and type(result) == "table" then
                decoded = result
            else
                decoded = {Key = stored}
            end

            local requiredIdentityVersion = tonumber(settings.IdentityVersion)
            local storedIdentityVersion = tonumber(decoded.IdentityVersion)

            if requiredIdentityVersion
                and storedIdentityVersion ~= requiredIdentityVersion
                and settings.ResetLegacyKeyCache ~= false then

                -- One-time migration path: old sessions were bound with the
                -- previous identity scheme. Forget them locally so a fresh key
                -- can be entered after the server-side HWID reset.
                clearStoredKey(savedPath)
                clearStoredKey(timedPath)
            else
                local candidate = trimKey(decoded.Key or decoded.key)

                if candidate ~= "" then
                    local cachedSession = {
                        Remote = decoded.Remote ~= false,
                        Provider = decoded.Provider or settings.Provider or "Remote",
                        Permanent = decoded.Permanent == true,
                        LifetimeLike = decoded.LifetimeLike == true,
                    }

                    if not canAutoReuseSession(cachedSession) then
                        clearStoredKey(savedPath)
                    else
                        local cachedExpiry =
                            tonumber(
                                decoded.ExpiresAt
                                or decoded.Expiry
                                or decoded.expiry
                            )

                        if cachedExpiry
                            and decoded.ExpiryReliable ~= false
                            and cachedExpiry <= os.time() then

                            clearStoredKey(savedPath)
                        else
                            local accepted, info =
                                validateRemote(candidate, true)

                            if accepted then
                                local session =
                                    remoteSessionFromInfo(
                                        candidate,
                                        info
                                    )

                                if session.ExpiresAt
                                    and session.EnforceLocalExpiry ~= false
                                    and session.ExpiresAt <= os.time() then

                                    clearStoredKey(savedPath)
                                elseif canAutoReuseSession(session) then
                                    window.ActiveKey = candidate
                                    window.RemoteKeyInfo = info
                                    window:SetKeySession(session)

                                    saveKeySession(savedPath, session)
                                    startRemoteRefreshLoop(candidate)
                                    return true
                                else
                                    clearStoredKey(savedPath)
                                end
                            else
                                info = type(info) == "table" and info or {}

                                -- A network/API outage does not destroy a valid
                                -- cached long-term key. We simply show the key
                                -- screen and let the next execution retry.
                                if info.Retryable ~= true
                                    and info.Transient ~= true then

                                    clearStoredKey(savedPath)
                                end
                            end
                        end
                    end
                else
                    clearStoredKey(savedPath)
                end
            end
        end

    elseif saveKey and type(isfile)=="function" and type(readfile)=="function" then
        -- Legacy/local key behavior.
        local ok, stored = pcall(function() if isfile(savedPath) then return readfile(savedPath) end end)
        if ok and stored and stored ~= "" then
            local decoded
            local decodeOk, result = pcall(HttpService.JSONDecode, HttpService, stored)
            if decodeOk and type(result) == "table" then
                decoded = result
            else
                decoded = {Key = stored}
            end
            local entry = findKeyEntry(entries, decoded.Key)
            if entry then
                local session = keySessionFor(entry, decoded)
                if isTimedKeyEntry(entry) or session.ExpiresAt then
                    timedSessions[entry.Key] = session
                    saveTimedKeySessions(timedPath, timedSessions)
                    clearStoredKey(savedPath)
                else
                    window.ActiveKey = entry.Key
                    window:SetKeySession(session)
                    return true
                end
            end
        end
    end

    local overlay = create("CanvasGroup", {
        Parent = window.Gui,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.08,
        GroupTransparency = 1,
        Size = UDim2.fromScale(1,1),
        ZIndex = 400,
    })
    local card = create("CanvasGroup", {
        Parent = overlay,
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = UDim2.fromOffset(382,304),
        BackgroundColor3 = Theme.Surface,
        GroupTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 401,
    })
    corner(card,10); stroke(card,Theme.Border,1,0.34)
    local icon = createIcon(card, "key", "key")
    icon.Position=UDim2.fromOffset(17,14); icon.Size=UDim2.fromOffset(20,20); icon.ZIndex=402
    setIconColor(icon, Theme.AccentVisible)
    local panelTitle=makeText(card,"vitality's hub",10,Theme.Muted,Enum.Font.GothamMedium)
    panelTitle.Position=UDim2.fromOffset(46,9); panelTitle.Size=UDim2.new(1,-62,0,30); panelTitle.ZIndex=402
    create("Frame",{Parent=card,Position=UDim2.fromOffset(16,44),Size=UDim2.new(1,-32,0,1),BackgroundColor3=Theme.BorderSoft,BorderSizePixel=0,ZIndex=402})

    local title=makeText(card,settings.Title or "Access key",16,Theme.Text,Enum.Font.GothamSemibold)
    title.Position=UDim2.fromOffset(22,62); title.Size=UDim2.new(1,-44,0,25); title.ZIndex=402
    local note=makeText(card,settings.Note or settings.Subtitle or "Enter your key to continue.",11,Theme.Muted,Enum.Font.Gotham)
    note.Position=UDim2.fromOffset(22,87); note.Size=UDim2.new(1,-44,0,22); note.TextWrapped=true; note.ZIndex=402

    local box=create("TextBox",{
        Parent=card,Position=UDim2.fromOffset(22,120),Size=UDim2.new(1,-44,0,38),BackgroundColor3=Theme.Background,
        BorderSizePixel=0,PlaceholderText=settings.PlaceholderText or "XXXX-XXXX-XXXX",PlaceholderColor3=Theme.Muted,Text="",TextColor3=Theme.Text,
        TextSize=12,Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=402,TextXAlignment=Enum.TextXAlignment.Left,
    })
    corner(box,7); local bs=stroke(box,Theme.Border,1,0.28); padding(box,11,11,0,0)
    local errorText=makeText(card,"",10,Theme.Danger,Enum.Font.Gotham)
    errorText.Position=UDim2.fromOffset(22,164); errorText.Size=UDim2.new(1,-44,0,22); errorText.ZIndex=402

    local verify=create("TextButton",{
        Parent=card,Position=UDim2.fromOffset(22,194),Size=UDim2.new(1,-44,0,40),BackgroundColor3=Theme.Button,BorderSizePixel=0,
        Text=settings.VerifyText or "Verify",TextColor3=Theme.ButtonText,TextSize=13,Font=Enum.Font.GothamSemibold,AutoButtonColor=false,ZIndex=402,
    })
    corner(verify,7)
    local verifyStroke = stroke(verify, Theme.ButtonOutline, 1, 0.20)
    setThemeRole(verify, "BackgroundColor3", "Button")
    setThemeRole(verify, "TextColor3", "ButtonText")
    setThemeRole(verifyStroke, "Color", "ButtonOutline")
    applyButtonGradient(verify)


    local hint=makeText(card,settings.Footer or "Get a key from your community.",10,Theme.Muted,Enum.Font.Gotham)
    hint.Position=UDim2.fromOffset(22,255); hint.Size=UDim2.new(1,-150,0,24); hint.ZIndex=402
    if settings.GetKeyURL or settings.GetKeyCallback then
        local getKey=makeText(card,"Get key  ->",10,Theme.AccentVisible,Enum.Font.GothamMedium,Enum.TextXAlignment.Right)
        getKey.Position=UDim2.new(1,-128,0,255); getKey.Size=UDim2.fromOffset(106,24); getKey.ZIndex=402; getKey.Active=true
        getKey.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if settings.GetKeyURL and type(setclipboard)=="function" then pcall(setclipboard,settings.GetKeyURL) end
            safeCallback(settings.GetKeyCallback, settings.GetKeyURL)
            window:_playSound("Click")
        end)
    end

    window.Main.Visible = false
    window._visible = false
    window:_tween(overlay, 0.30, {GroupTransparency = 0})
    window:_tween(card, 0.38, {Position = UDim2.fromScale(0.5, 0.5), GroupTransparency = 0})

    local unlocked = false
    local verifying = false

    local function rejectKey(message)
        verifying = false
        verify.Active = true
        verify.Text = settings.VerifyText or "Verify"
        errorText.Text = tostring(message or "X  Invalid key")
        setThemeRole(errorText, "TextColor3", "Danger")
        setThemeRole(bs, "Color", "Danger")
        window:_tween(box,0.06,{Position=UDim2.fromOffset(27,120)},Enum.EasingStyle.Quad)
        task.delay(window:_motionDuration(0.06),function()
            if box.Parent then window:_tween(box,0.12,{Position=UDim2.fromOffset(22,120)},Enum.EasingStyle.Quint) end
        end)
    end

    local function acceptKey(candidate, session, info, shouldSaveForReuse)
        unlocked = true
        verifying = false
        verify.Active = false
        window.ActiveKey = candidate
        window.RemoteKeyInfo = info
        window:SetKeySession(session)

        if session
            and session.Remote == true
            and type(remoteValidator) == "function" then

            startRemoteRefreshLoop(candidate)
        end

        if saveKey then
            if shouldSaveForReuse then
                saveKeySession(savedPath, session)
            else
                -- Explicit no-persistence policy only. Normal remote KeyAuth
                -- sessions are saved and freshly revalidated next execution.
                clearStoredKey(savedPath)
            end
        end

        window:_playSound("Confirm")
        verify.Text = "Correct key"
        setThemeRole(bs, "Color", "Success")

        local acceptedText = "Key accepted"
        if session and (session.Permanent == true or session.LifetimeLike == true) then
            acceptedText = "Key accepted - lifetime"
        elseif session and session.ExpiresAt then
            local remaining = math.max(0, session.ExpiresAt - os.time())
            acceptedText = "Key accepted - " .. formatKeyRemaining(remaining)
        end

        errorText.Text = acceptedText
        setThemeRole(errorText, "TextColor3", "Success")
        window:SetScriptStatus("yellow", "Key accepted")
        window:_tween(card,0.32,{GroupTransparency=1, Position=UDim2.new(0.5,0,0.5,-10)})
        window:_tween(overlay,0.34,{GroupTransparency=1})
        task.delay(window:_motionDuration(0.35),function()
            if overlay then overlay:Destroy() end
            if window.Main then
                window:_completeStartup()
            end
        end)
    end

    local function tryRemoteKey()
        local candidate = trimKey(box.Text)
        if candidate == "" then
            rejectKey("Enter a key to continue.")
            return
        end

        verifying = true
        verify.Active = false
        verify.Text = settings.CheckingText or "Checking..."
        errorText.Text = ""
        setThemeRole(bs, "Color", "AccentVisible")

        task.spawn(function()
            local accepted, info = validateRemote(candidate, false)

            if not box.Parent or unlocked then return end

            if not accepted then
                local message = info and (info.Message or info.message)
                if info and info.Expired == true then
                    message = "this key has expired and is not usable!"
                end
                rejectKey(message or "X  Invalid key")
                window:SetScriptStatus("yellow", "Key rejected")
                return
            end

            local session =
                remoteSessionFromInfo(
                    candidate,
                    info
                )

            if session.ExpiresAt
                and session.EnforceLocalExpiry ~= false
                and session.ExpiresAt <= os.time() then

                rejectKey("this key has expired and is not usable!")
                window:SetScriptStatus("yellow", "Key expired")
                return
            end

            acceptKey(
                candidate,
                session,
                info,
                canAutoReuseSession(session)
            )
        end)
    end

    local function tryLocalKey()
        local entry = findKeyEntry(entries, box.Text)
        if entry then
            local timed = isTimedKeyEntry(entry)
            local previous = timed and timedSessions[entry.Key] or nil
            local session = keySessionFor(entry, previous)

            if session.ExpiresAt and session.ExpiresAt <= os.time() then
                rejectKey("this key has expired and is not usable!")
                window:SetScriptStatus("yellow", "Key expired")
                if saveKey and timed then
                    timedSessions[entry.Key] = session
                    saveTimedKeySessions(timedPath, timedSessions)
                end
                return
            end

            if saveKey then
                if session.ExpiresAt then
                    timedSessions[entry.Key] = session
                    saveTimedKeySessions(timedPath, timedSessions)
                end
            end

            acceptKey(entry.Key, session, nil, not session.ExpiresAt)
        else
            rejectKey("X  Invalid key")
        end
    end

    local function tryKey()
        if unlocked or verifying then return end
        if type(remoteValidator) == "function" then
            tryRemoteKey()
        else
            tryLocalKey()
        end
    end

    verify.MouseButton1Click:Connect(function()
        window:_playSound("Click")
        tryKey()
    end)
    box.FocusLost:Connect(function(enter) if enter then tryKey() end end)
    return unlocked
end

local function startStartupSequence(window)
    window:SetScriptStatus("yellow", "Partially working")
    local loading = window.Settings.LoadingScreen
    if loading == nil then loading = window.Settings.Loading end
    if loading == nil then loading = {} end
    if loading == false then
        local unlocked = buildKeySystem(window)
        if unlocked then window:_completeStartup() end
        return
    end
    if type(loading) ~= "table" then loading = {} end
    if loading.Enabled == false then
        local unlocked = buildKeySystem(window)
        if unlocked then window:_completeStartup() end
        return
    end

    local controller = window:ShowLoading({
        Title = loading.Title or window.Settings.LoadingTitle or window.Settings.Name or "vitality's hub",
        Status = loading.Status or window.Settings.LoadingSubtitle or "Loading components...",
        Icon = loading.Icon or window.Settings.Icon,
        Progress = 0.08,
    })
    local duration = math.max(tonumber(loading.Duration) or 1.15, 0.35)
    task.delay(duration * 0.34, function()
        if controller.Instance.Parent then controller:SetProgress(0.42, true) end
    end)
    task.delay(duration * 0.68, function()
        if controller.Instance.Parent then controller:SetProgress(0.76, true) end
    end)
    task.delay(duration, function()
        if not controller.Instance.Parent then return end
        controller:Finish(loading.CompleteStatus or "Components ready", function()
            local unlocked = buildKeySystem(window)
            if unlocked then window:_completeStartup() end
        end)
    end)
end

--[[
    Two-line bootstrap router scaffold
    ----------------------------------
    V2.7 includes game detection and game-specific module loading. The legacy router is still built
    around the final two-line entry point the project is intended to use:

        local NovaField = loadstring(game:HttpGet("RAW_NOVAFIELD_URL"))()
        key = "your-key"

    Once Router.Enabled is set to true and the Games/Places registry is filled
    inside NovaField, the library defers one task, resolves the current
    experience, reads the global `key`, fetches the matching module internally,
    and passes NovaField + the key into that module.

    This keeps the user-facing script at exactly two lines: the loadstring,
    then the runtime key. The V2.7 loading controller is used by the game loader
    to drive the sequence "Correct Key..." -> "Detecting Game..." ->
    "Module Found!" before revealing the game-specific NovaField interface.
]]

Library.Router = {
    -- Legacy auto-bootstrap remains disabled by default. The preferred V2.7
    -- flow is CreateWindow({GameLoader = {Enabled = true}}) after registering
    -- game/place profiles below.
    Enabled = false,
    Games = {},       -- [game.GameId] = profile/module
    Places = {},      -- [game.PlaceId] = profile/module (takes priority)
    Universal = nil,  -- optional fallback profile/module
    KeyVariable = "key",
    WaitForKeySeconds = 0.35,
    LastDetection = nil,
    LastLoad = nil,
}

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(type(source) == "table" and source or {}) do
        copy[key] = value
    end
    return copy
end

local function normalizeGameProfile(value, defaultName)
    -- A profile may contain metadata plus Module/Source/Loader. For backwards
    -- compatibility a raw URL, source string, function, or Load/Init table can
    -- still be registered directly.
    if type(value) == "table" then
        local looksLikeProfile = value.Module ~= nil
            or value.Source ~= nil
            or value.Loader ~= nil
            or value.Name ~= nil
            or value.Title ~= nil
            or value.Enabled ~= nil
            or value.Status ~= nil
            or value.Label ~= nil

        if looksLikeProfile then
            local profile = shallowCopy(value)
            profile.Module = profile.Module or profile.Source or profile.Loader
            if profile.Module == nil and (type(value.Load) == "function" or type(value.Init) == "function") then
                profile.Module = value
            end
            profile.Name = profile.Name or profile.Title or defaultName
            return profile
        end

        if type(value.Load) == "function" or type(value.Init) == "function" then
            return {Name = defaultName, Module = value}
        end
    end

    return {Name = defaultName, Module = value}
end

local function routeLookup(map, id)
    if type(map) ~= "table" then return nil end
    return map[id] or map[tostring(id)] or map[tonumber(id)]
end

function Library:RegisterGame(gameId, moduleOrProfile, metadata)
    local id = tonumber(gameId) or gameId
    local profile = normalizeGameProfile(moduleOrProfile)
    if type(metadata) == "table" then
        for key, value in pairs(metadata) do profile[key] = value end
    end
    profile.GameId = tonumber(profile.GameId) or tonumber(gameId) or profile.GameId
    self.Router.Games[id] = profile
    return profile
end

function Library:RegisterPlace(placeId, moduleOrProfile, metadata)
    local id = tonumber(placeId) or placeId
    local profile = normalizeGameProfile(moduleOrProfile)
    if type(metadata) == "table" then
        for key, value in pairs(metadata) do profile[key] = value end
    end
    profile.PlaceId = tonumber(profile.PlaceId) or tonumber(placeId) or profile.PlaceId
    self.Router.Places[id] = profile
    return profile
end

function Library:SetUniversalModule(moduleOrProfile)
    self.Router.Universal = normalizeGameProfile(moduleOrProfile, "Universal")
    return self.Router.Universal
end

function Library:DetectGame()
    local rawProfile = routeLookup(self.Router.Places, game.PlaceId)
    local matchType = rawProfile ~= nil and "place" or nil

    if rawProfile == nil then
        rawProfile = routeLookup(self.Router.Games, game.GameId)
        if rawProfile ~= nil then matchType = "game" end
    end

    if rawProfile == nil and self.Router.Universal ~= nil then
        rawProfile = self.Router.Universal
        matchType = "universal"
    end

    if rawProfile == nil then
        local missing = {
            Supported = false,
            Reason = "unsupported_game",
            MatchType = nil,
            GameId = game.GameId,
            PlaceId = game.PlaceId,
            GameName = game.Name,
        }
        self.Router.LastDetection = missing
        return nil, missing
    end

    local profile = normalizeGameProfile(rawProfile, game.Name)
    if profile.Enabled == false then
        local disabled = {
            Supported = false,
            Reason = "game_disabled",
            MatchType = matchType,
            GameId = game.GameId,
            PlaceId = game.PlaceId,
            GameName = game.Name,
            Name = profile.Name or game.Name,
            Profile = profile,
        }
        self.Router.LastDetection = disabled
        return nil, disabled
    end

    local detection = {
        Supported = true,
        Reason = "matched",
        MatchType = matchType,
        GameId = game.GameId,
        PlaceId = game.PlaceId,
        GameName = game.Name,
        Name = profile.Name or profile.Title or game.Name or ("Game " .. tostring(game.GameId)),
        Module = profile.Module,
        Profile = profile,
    }
    self.Router.LastDetection = detection
    return detection, detection
end

function Library:GetDetectedGame()
    local detection = self.Router.LastDetection
    if not detection then return nil end
    return shallowCopy(detection)
end

function Library:ResolveGameModule()
    local detection = self:DetectGame()
    return detection and detection.Module or nil
end

function Library:_readRuntimeKey()
    local keyName = tostring(self.Router.KeyVariable or "key")

    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" and rawget(env, keyName) ~= nil then
            return rawget(env, keyName)
        end
    end

    if type(_G) == "table" and rawget(_G, keyName) ~= nil then
        return rawget(_G, keyName)
    end

    return nil
end

local function resolveModuleValue(source)
    if source == nil then return nil, "missing_module" end
    if type(source) ~= "string" then return source, nil end

    local moduleSource = source
    if source:match("^https?://") then
        local ok, downloaded = pcall(function()
            return game:HttpGet(source, true)
        end)
        if not ok then
            return nil, "download_failed", downloaded
        end
        moduleSource = downloaded
    end

    local compiler = loadstring
    if type(compiler) ~= "function" then
        return nil, "loadstring_unavailable"
    end

    local chunk, compileError = compiler(moduleSource)
    if not chunk then
        return nil, "compile_failed", compileError
    end

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "module_runtime_failed", result
    end
    return result, nil
end

function Library:_runGameModule(moduleResult, context)
    if type(moduleResult) == "function" then
        local ok, result = pcall(moduleResult, context)
        if not ok then return false, "module_loader_failed", result end
        return true, result
    end

    if type(moduleResult) == "table" then
        if type(moduleResult.Load) == "function" then
            local ok, result = pcall(moduleResult.Load, moduleResult, context)
            if not ok then return false, "module_loader_failed", result end
            return true, result
        elseif type(moduleResult.Init) == "function" then
            local ok, result = pcall(moduleResult.Init, moduleResult, context)
            if not ok then return false, "module_loader_failed", result end
            return true, result
        end
    end

    return false, "invalid_module"
end

function Library:LoadDetectedGame(window, options)
    options = type(options) == "table" and options or {}

    -- Startup phases are deliberately paced. DetectGame(), local module builders,
    -- and cached HTTP modules can all complete in the same frame; without a small
    -- dwell time the loader skips visually from Components ready straight to the
    -- final message even though every intermediate state did execute.
    local stageDuration = math.max(tonumber(options.StageDuration) or 0.55, 0)
    local detectingDuration = math.max(tonumber(options.DetectingDuration) or stageDuration, 0)
    local detectedDuration = math.max(tonumber(options.DetectedDuration) or stageDuration, 0)
    local loadingDuration = math.max(tonumber(options.LoadingDuration) or stageDuration, 0)
    local buildingDuration = math.max(tonumber(options.BuildingDuration) or stageDuration, 0)

    local controller
    if window and options.ShowLoading ~= false then
        controller = window:ShowLoading({
            Title = options.LoadingTitle or window.Settings.Name or "vitality's hub",
            Status = options.DetectingText or "Detecting game...",
            Icon = options.Icon or window.Settings.Icon or "vitality",
            Progress = 0.12,
        })
        controller:Step(options.DetectingText or "Detecting game...", 0.16, detectingDuration)
    end

    if window then
        window:SetScriptStatus("yellow", options.DetectingLabel or "Detecting game")
    end

    -- Detection happens after the detecting state has actually been rendered.
    local detection, detectionInfo = self:DetectGame()

    if not detection then
        if window then
            window:SetScriptStatus("yellow", options.UnsupportedLabel or "Unsupported game")
        end
        if controller then
            controller:Step(options.UnsupportedText or "Unsupported game", 0.92, detectedDuration)
        end

        if window then
            window:SetHeaderContext(
                options.UnsupportedGameName or game.Name or "Unsupported game",
                options.UnsupportedVersion or Library.Version
            )
        end

        local statusEntry, statusScope
        if window then
            statusEntry, statusScope = window:GetStatusEntry(game.GameId, game.PlaceId)
        end
        local context = {
            Library = self,
            NovaField = self,
            Window = window,
            Key = self.RuntimeKey or (window and window.ActiveKey) or self:_readRuntimeKey(),
            GameId = game.GameId,
            PlaceId = game.PlaceId,
            Game = game,
            Detection = detectionInfo,
            Status = statusEntry,
            StatusScope = statusScope,
            StatusManifest = window and window:GetStatusManifest() or nil,
            Owner = window and cloneValue(window.OwnerInfo) or nil,
            GetStatus = window and function()
                return window:GetStatusEntry(game.GameId, game.PlaceId)
            end or nil,
            SubscribeStatus = window and function(callback, fireImmediately)
                return window:SubscribeStatus(callback, fireImmediately)
            end or nil,
        }
        safeCallback(options.OnUnsupported, context)

        if controller then
            controller:Finish(options.UnsupportedReadyText or "No game interface available")
        end

        self.Router.LastLoad = {
            Success = false,
            Reason = detectionInfo and detectionInfo.Reason or "unsupported_game",
            Detection = detectionInfo,
            CompletedAt = os.time(),
        }
        return false, self.Router.LastLoad.Reason, detectionInfo
    end

    if controller then
        controller:Step(
            (options.DetectedPrefix or "Detected: ") .. tostring(detection.Name),
            0.38,
            detectedDuration
        )
    end

    if window then
        local profile = detection.Profile or {}
        window:SetHeaderContext(
            detection.Name or profile.Name,
            profile.Version or options.InterfaceVersion or Library.Version
        )
        window:SetScriptStatus("yellow", options.LoadingLabel or ("Loading " .. tostring(detection.Name)))
    end
    if controller then
        controller:Step(
            options.ModuleLoadingText or "Loading game interface...",
            0.61,
            loadingDuration
        )
    end

    local moduleResult, resolveReason, resolveError = resolveModuleValue(detection.Module)
    if not moduleResult then
        if window then window:SetScriptStatus("red", options.ErrorLabel or "Module failed") end
        if controller then controller:Finish(options.LoadFailedText or "Failed to load module") end
        warn("[VitalityHub] Module resolve failed: " .. tostring(resolveError or resolveReason))
        safeCallback(options.OnLoadError, {
            Window = window,
            Detection = detection,
            Reason = resolveReason,
            Error = resolveError,
        })
        self.Router.LastLoad = {
            Success = false,
            Reason = resolveReason,
            Error = resolveError,
            Detection = detection,
            CompletedAt = os.time(),
        }
        return false, resolveReason, detection
    end

    if controller then
        controller:Step(
            options.BuildingText or "Building game interface...",
            0.82,
            buildingDuration
        )
    end

    local runtimeKey = self.RuntimeKey or (window and window.ActiveKey) or self:_readRuntimeKey()
    self.RuntimeKey = runtimeKey
    local statusEntry, statusScope
    if window then
        statusEntry, statusScope = window:GetStatusEntry(game.GameId, game.PlaceId)
    end
    local context = {
        Library = self,
        NovaField = self,
        Window = window,
        Key = runtimeKey,
        GameId = game.GameId,
        PlaceId = game.PlaceId,
        Game = game,
        Detection = detection,
        Profile = detection.Profile,
        MatchType = detection.MatchType,
        Status = statusEntry,
        StatusScope = statusScope,
        StatusManifest = window and window:GetStatusManifest() or nil,
        Owner = window and cloneValue(window.OwnerInfo) or nil,
        GetStatus = window and function()
            return window:GetStatusEntry(game.GameId, game.PlaceId)
        end or nil,
        SubscribeStatus = window and function(callback, fireImmediately)
            return window:SubscribeStatus(callback, fireImmediately)
        end or nil,
    }

    local success, resultOrReason, runError = self:_runGameModule(moduleResult, context)
    if not success then
        if window then window:SetScriptStatus("red", options.ErrorLabel or "Module failed") end
        if controller then controller:Finish(options.LoadFailedText or "Module failed to initialize") end
        warn("[VitalityHub] Game module failed: " .. tostring(runError or resultOrReason))
        safeCallback(options.OnLoadError, {
            Window = window,
            Detection = detection,
            Reason = resultOrReason,
            Error = runError,
        })
        self.Router.LastLoad = {
            Success = false,
            Reason = resultOrReason,
            Error = runError,
            Detection = detection,
            CompletedAt = os.time(),
        }
        return false, resultOrReason, detection
    end

    local profile = detection.Profile or {}
    if window then
        local remoteEntry = window:GetStatusEntry(game.GameId, game.PlaceId)
        if remoteEntry then
            window.CurrentStatusEntry = cloneValue(remoteEntry)
            window:SetScriptStatus(remoteEntry)
        else
            local status = profile.State or profile.Status or profile.Level or options.ReadyStatus or "functional"
            local label = profile.Label or profile.StatusLabel or options.ReadyLabel or "Fully Working"
            window:SetScriptStatus(status, label)
        end
    end
    if controller then
        controller:Finish(options.ReadyText or "Game interface ready")
    end

    self.Router.LastLoad = {
        Success = true,
        Reason = "loaded",
        Detection = detection,
        Result = resultOrReason,
        CompletedAt = os.time(),
    }
    safeCallback(options.OnLoaded, context, resultOrReason)
    return true, "loaded", detection
end

-- Legacy entry point retained for scripts that explicitly call Bootstrap().
-- It now uses the same detector/module executor as the V2.7 GameLoader.
function Library:Bootstrap(runtimeKey, window)
    self.RuntimeKey = runtimeKey ~= nil and runtimeKey or self:_readRuntimeKey()
    return self:LoadDetectedGame(window, {ShowLoading = window ~= nil})
end

local function armRouter()
    task.defer(function()
        if not Library.Router.Enabled then return end

        local keyValue = Library:_readRuntimeKey()
        local timeout = tonumber(Library.Router.WaitForKeySeconds) or 0
        local started = os.clock()

        while keyValue == nil and (os.clock() - started) < timeout do
            task.wait()
            keyValue = Library:_readRuntimeKey()
        end

        Library:Bootstrap(keyValue)
    end)
end


-- ============================================================
-- VITALITY COMMAND BAR / COMMAND REGISTRY
-- ============================================================
-- Commands live on the active window so game modules can register their own
-- developer actions without creating another GUI or another input listener.

local function normalizeCommandKey(value, fallback)
    local name = normalizeKeyName(value, fallback or "Semicolon")
    local ok, enum = pcall(function()
        return Enum.KeyCode[name]
    end)
    if ok and enum then return enum end
    return Enum.KeyCode.Semicolon
end

local function normalizeCommandName(value)
    return tostring(value or "")
        :lower()
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub("^;+", "")
        :gsub("^/+", "")
end

local function splitCommandLine(text)
    text = tostring(text or "")
    local out, current = {}, {}
    local quote, escaped = nil, false

    local function flush()
        if #current == 0 then return end
        table.insert(out, table.concat(current))
        table.clear(current)
    end

    for index = 1, #text do
        local character = text:sub(index, index)
        if escaped then
            table.insert(current, character)
            escaped = false
        elseif character == "\\" then
            escaped = true
        elseif quote then
            if character == quote then
                quote = nil
            else
                table.insert(current, character)
            end
        elseif character == '"' or character == "'" then
            quote = character
        elseif character:match("%s") then
            flush()
        else
            table.insert(current, character)
        end
    end

    if escaped then table.insert(current, "\\") end
    flush()
    return out
end

local function commandAliases(command)
    local aliases = {}
    for _, alias in ipairs(command.Aliases or {}) do
        alias = normalizeCommandName(alias)
        if alias ~= "" then table.insert(aliases, alias) end
    end
    return aliases
end

function WindowMethods:RegisterCommand(data, callback, description)
    if self._destroyed then return nil end

    if type(data) ~= "table" then
        data = {
            Name = data,
            Callback = callback,
            Description = description,
        }
    end

    local name = normalizeCommandName(data.Name or data.Command)
    if name == "" then
        warn("[VitalityHub] RegisterCommand requires a command name.")
        return nil
    end

    self.Commands = self.Commands or {}
    self.CommandOrder = self.CommandOrder or {}

    -- Re-registering the same name intentionally replaces the old definition.
    if self.Commands[name] then
        for index = #self.CommandOrder, 1, -1 do
            if self.CommandOrder[index] == name then
                table.remove(self.CommandOrder, index)
            end
        end
    end

    local aliases = data.Aliases or data.Alias or {}
    if type(aliases) == "string" then aliases = {aliases} end

    local command = {
        Name = name,
        DisplayName = tostring(data.DisplayName or data.Name or name),
        Aliases = aliases,
        Description = tostring(data.Description or data.Info or ""),
        Usage = tostring(data.Usage or data.Syntax or name),
        Category = tostring(data.Category or "General"),
        Hidden = data.Hidden == true,
        Autocomplete = data.Autocomplete or data.Suggestions or data.Completions,
        Callback = data.Callback or callback,
        Window = self,
    }
    command.Aliases = commandAliases(command)

    self.Commands[name] = command
    table.insert(self.CommandOrder, name)

    local object = command
    function object:Destroy()
        if not self.Window or self.Window._destroyed then return false end
        return self.Window:UnregisterCommand(self.Name)
    end

    if self._refreshCommandSuggestions then
        self:_refreshCommandSuggestions()
    end
    return object
end

function WindowMethods:UnregisterCommand(name)
    name = normalizeCommandName(name)
    if not self.Commands or not self.Commands[name] then return false end
    self.Commands[name] = nil
    for index = #self.CommandOrder, 1, -1 do
        if self.CommandOrder[index] == name then
            table.remove(self.CommandOrder, index)
        end
    end
    if self._refreshCommandSuggestions then self:_refreshCommandSuggestions() end
    return true
end

function WindowMethods:GetCommands(includeHidden)
    local commands = {}
    for _, name in ipairs(self.CommandOrder or {}) do
        local command = self.Commands and self.Commands[name]
        if command and (includeHidden == true or not command.Hidden) then
            table.insert(commands, command)
        end
    end
    return commands
end

function WindowMethods:_findCommand(name)
    name = normalizeCommandName(name)
    if name == "" then return nil end
    local direct = self.Commands and self.Commands[name]
    if direct then return direct end
    for _, command in ipairs(self:GetCommands(true)) do
        for _, alias in ipairs(command.Aliases or {}) do
            if alias == name then return command end
        end
    end
    return nil
end

function WindowMethods:GetCommandMatches(query, limit)
    local rawQuery = tostring(query or "")
    local firstToken = splitCommandLine(rawQuery)[1] or ""
    local needle = normalizeCommandName(firstToken)
    local scored = {}

    local function scoreValue(value)
        value = normalizeCommandName(value)
        if needle == "" then return 50 end
        if value == needle then return 0 end
        if value:sub(1, #needle) == needle then return 10 + (#value - #needle) * 0.01 end
        local position = value:find(needle, 1, true)
        if position then return 30 + position end
        return nil
    end

    for order, command in ipairs(self:GetCommands(false)) do
        local score = scoreValue(command.Name)
        for _, alias in ipairs(command.Aliases or {}) do
            local aliasScore = scoreValue(alias)
            if aliasScore and (not score or aliasScore + 1 < score) then
                score = aliasScore + 1
            end
        end
        if score then
            table.insert(scored, {Command = command, Score = score, Order = order})
        end
    end

    table.sort(scored, function(a, b)
        if a.Score == b.Score then
            if a.Order == b.Order then return a.Command.Name < b.Command.Name end
            return a.Order < b.Order
        end
        return a.Score < b.Score
    end)

    local results = {}
    local maximum = math.max(1, tonumber(limit) or 6)
    for index = 1, math.min(maximum, #scored) do
        table.insert(results, scored[index].Command)
    end
    return results
end

local function normalizeSuggestionEntry(value, order)
    if type(value) == "string" or type(value) == "number" then
        local text = tostring(value)
        return {
            Kind = "argument",
            Name = text,
            Insert = text,
            Description = "",
            Meta = "",
            Order = order,
        }
    end

    if type(value) ~= "table" then return nil end

    local insertText = tostring(value.Insert or value.Value or value.Text or value.Name or "")
    if insertText == "" then return nil end

    return {
        Kind = tostring(value.Kind or "argument"),
        Name = tostring(value.Name or value.Label or value.Value or insertText),
        Insert = insertText,
        Description = tostring(value.Description or value.Detail or value.Info or ""),
        Meta = tostring(value.Meta or value.Status or value.Category or ""),
        Aliases = type(value.Aliases) == "table" and value.Aliases or {},
        Order = tonumber(value.Order) or order,
        Raw = value,
    }
end

local function suggestionScore(suggestion, fragment)
    fragment = normalizeCommandName(fragment)
    if fragment == "" then return 50 end

    local candidates = {
        suggestion.Insert,
        suggestion.Name,
        suggestion.Description,
        suggestion.Meta,
    }
    for _, alias in ipairs(suggestion.Aliases or {}) do
        table.insert(candidates, alias)
    end

    local best
    for _, candidate in ipairs(candidates) do
        candidate = normalizeCommandName(candidate)
        local score
        if candidate == fragment then
            score = 0
        elseif candidate:sub(1, #fragment) == fragment then
            score = 10 + (#candidate - #fragment) * 0.01
        else
            local position = candidate:find(fragment, 1, true)
            if position then score = 30 + position end
        end
        if score and (not best or score < best) then best = score end
    end
    return best
end

function WindowMethods:_getCommandArgumentSuggestions(query, limit)
    local raw = tostring(query or "")
    local content = raw
        :gsub("^%s+", "")
        :gsub("^;+", "")
        :gsub("^/+", "")

    -- Argument completion begins only after the command token and at least one
    -- whitespace character. Typing just `status` still behaves like normal
    -- command-name autocomplete; typing `status ` switches to its arguments.
    if content == "" or not content:find("%s") then return nil, nil end

    local pieces = splitCommandLine(content)
    local requested = pieces[1]
    local command = requested and self:_findCommand(requested) or nil
    if not command or command.Autocomplete == nil then return nil, nil end

    local trailingSpace = content:match("%s$") ~= nil
    local argIndex
    local fragment
    local completedArgs = {}

    if trailingSpace then
        argIndex = math.max(1, #pieces)
        fragment = ""
        for index = 2, #pieces do table.insert(completedArgs, pieces[index]) end
    else
        argIndex = math.max(1, #pieces - 1)
        fragment = pieces[#pieces] or ""
        for index = 2, math.max(1, #pieces - 1) do
            if pieces[index] ~= nil then table.insert(completedArgs, pieces[index]) end
        end
    end

    local context = {
        Window = self,
        Library = Library,
        Command = command,
        Raw = raw,
        Args = completedArgs,
        ArgIndex = argIndex,
        Fragment = fragment,
        TrailingSpace = trailingSpace,
    }

    local provider = command.Autocomplete
    local values
    if type(provider) == "function" then
        local ok, result = pcall(provider, context)
        if not ok then
            warn("[VitalityHub] Command autocomplete for '" .. command.Name .. "' failed: " .. tostring(result))
            return {}, context
        end
        values = result
    elseif type(provider) == "table" then
        values = provider
    end

    if type(values) ~= "table" then return {}, context end

    local scored = {}
    for order, value in ipairs(values) do
        local suggestion = normalizeSuggestionEntry(value, order)
        if suggestion then
            local score = suggestionScore(suggestion, fragment)
            if score then
                suggestion.Score = score
                suggestion.Context = context
                table.insert(scored, suggestion)
            end
        end
    end

    table.sort(scored, function(a, b)
        if a.Score == b.Score then
            if a.Order == b.Order then return a.Name:lower() < b.Name:lower() end
            return a.Order < b.Order
        end
        return a.Score < b.Score
    end)

    local results = {}
    local maximum = math.max(1, tonumber(limit) or 6)
    for index = 1, math.min(maximum, #scored) do
        table.insert(results, scored[index])
    end
    return results, context
end

function WindowMethods:GetCommandSuggestions(query, limit)
    local argumentMatches, argumentContext = self:_getCommandArgumentSuggestions(query, limit)
    if argumentMatches ~= nil then
        return argumentMatches, argumentContext
    end

    local commandMatches = self:GetCommandMatches(query, limit)
    local results = {}
    for order, command in ipairs(commandMatches) do
        table.insert(results, {
            Kind = "command",
            Name = command.Name,
            Insert = command.Name,
            Description = command.Description ~= "" and command.Description or ("Usage: " .. command.Usage),
            Meta = command.Category,
            Order = order,
            Command = command,
            Context = {Mode = "command", Command = command},
        })
    end
    return results, {Mode = "command"}
end

function WindowMethods:_completeCommandSuggestion(text, suggestion)
    text = tostring(text or "")
    if type(suggestion) ~= "table" then return text end
    local insertText = tostring(suggestion.Insert or suggestion.Name or "")
    if insertText == "" then return text end

    if suggestion.Kind == "hint" then
        return text
    end

    if suggestion.Kind == "argument" then
        local context = suggestion.Context or {}
        local fragment = tostring(context.Fragment or "")
        if fragment == "" then
            if text ~= "" and not text:match("%s$") then text = text .. " " end
            return text .. insertText .. " "
        end

        local startIndex = text:find("%S+$")
        if startIndex then
            return text:sub(1, startIndex - 1) .. insertText .. " "
        end
        return text .. insertText .. " "
    end

    local leading = text:match("^(%s*[;/]*)") or ""
    local body = text:sub(#leading + 1)
    local startIndex, endIndex = body:find("%S+")
    if not startIndex then return leading .. insertText .. " " end

    local remainder = body:sub(endIndex + 1)
    if remainder == "" then remainder = " " end
    return leading .. insertText .. remainder
end

function WindowMethods:ExecuteCommand(text)
    text = tostring(text or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub("^;+", "")
        :gsub("^/+", "")

    if text == "" then return false, "No command entered." end

    local pieces = splitCommandLine(text)
    local requested = table.remove(pieces, 1)
    local command = self:_findCommand(requested)
    if not command then
        return false, "Unknown command: " .. tostring(requested)
    end
    if type(command.Callback) ~= "function" then
        return false, "Command has no callback: " .. command.Name
    end

    local context = {
        Window = self,
        Library = Library,
        Command = command,
        Raw = text,
        Args = pieces,
    }

    local ok, result = pcall(command.Callback, pieces, context)
    if not ok then
        warn("[VitalityHub] Command '" .. command.Name .. "' failed: " .. tostring(result))
        self:Notify({
            Title = "Command failed",
            Content = command.Name .. ": " .. tostring(result),
            Type = "Error",
            Duration = 4,
        })
        return false, result
    end
    return true, result
end

function WindowMethods:SetCommandBarKey(value)
    self.CommandBarKey = normalizeCommandKey(value, "Semicolon")
    if self.CommandBarKeyLabel then
        local display = self.CommandBarKey.Name == "Semicolon" and ";" or self.CommandBarKey.Name
        self.CommandBarKeyLabel.Text = "[" .. display .. "]"
    end
    return self.CommandBarKey.Name
end

function WindowMethods:GetCommandBarKey()
    return self.CommandBarKey and self.CommandBarKey.Name or "Semicolon"
end

function WindowMethods:IsCommandBarOpen()
    return self._commandBarOpen == true
end

function WindowMethods:OpenCommandBar(seed)
    if self._destroyed or not self.CommandBarRoot or self.CommandBarEnabled == false then return false end
    self._commandBarToken = (self._commandBarToken or 0) + 1
    self._commandBarOpen = true
    self.CommandBarRoot.Visible = true
    self.CommandBarRoot.Position = UDim2.new(0.5, 0, 0, 12)
    self.CommandBarRoot.GroupTransparency = 1
    if self.CommandBarScale then self.CommandBarScale.Scale = 0.985 end
    if seed ~= nil then self.CommandBarInput.Text = tostring(seed) end
    self.CommandBarInput.CursorPosition = #self.CommandBarInput.Text + 1
    self:_refreshCommandSuggestions()
    self:_tween(self.CommandBarRoot, 0.16, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 18)}, Enum.EasingStyle.Quint)
    if self.CommandBarScale then self:_tween(self.CommandBarScale, 0.16, {Scale = 1}, Enum.EasingStyle.Quint) end
    self:_playSound("Open")
    task.defer(function()
        if self._commandBarOpen and self.CommandBarInput and self.CommandBarInput.Parent then
            self.CommandBarInput:CaptureFocus()
        end
    end)
    return true
end

function WindowMethods:CloseCommandBar(immediate, clearInput)
    if not self.CommandBarRoot then return false end
    self._commandBarToken = (self._commandBarToken or 0) + 1
    local token = self._commandBarToken
    self._commandBarOpen = false
    if self.CommandBarInput then
        pcall(function() self.CommandBarInput:ReleaseFocus() end)
        if clearInput ~= false then self.CommandBarInput.Text = "" end
    end
    if immediate then
        self.CommandBarRoot.GroupTransparency = 1
        self.CommandBarRoot.Visible = false
    else
        self:_tween(self.CommandBarRoot, 0.13, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0, 12)}, Enum.EasingStyle.Quint)
        if self.CommandBarScale then self:_tween(self.CommandBarScale, 0.13, {Scale = 0.985}, Enum.EasingStyle.Quint) end
        task.delay(self:_motionDuration(0.14) + 0.01, function()
            if self.CommandBarRoot and self.CommandBarRoot.Parent and self._commandBarToken == token and not self._commandBarOpen then
                self.CommandBarRoot.Visible = false
            end
        end)
    end
    self:_playSound("Close")
    return true
end

function WindowMethods:ToggleCommandBar()
    if self:IsCommandBarOpen() then return self:CloseCommandBar(false) end
    return self:OpenCommandBar()
end

function WindowMethods:_setupCommandBar()
    if self.CommandBarRoot or self.CommandBarEnabled == false or not self.Gui then return end

    local options = type(self.Settings.CommandBar) == "table" and self.Settings.CommandBar or {}
    local maxSuggestions = math.clamp(math.floor(tonumber(options.MaxSuggestions) or 6), 3, 10)
    local width = math.clamp(math.floor(tonumber(options.Width) or 500), 360, 680)
    local rowHeight, rowGap = 46, 4
    local baseInputHeight = 48
    local maxInputHeight = math.clamp(math.floor(tonumber(options.MaxInputHeight) or 108), 72, 156)

    local root = create("CanvasGroup", {
        Name = "VitalityCommandBar",
        Parent = self.Gui,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 18),
        Size = UDim2.fromOffset(width, maxInputHeight + 8 + (maxSuggestions * (rowHeight + rowGap)) + 12),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 600,
    })
    self.CommandBarRoot = root
    self.CommandBarScale = create("UIScale", {Parent = root, Scale = 1})

    local inputShell = create("Frame", {
        Name = "InputShell",
        Parent = root,
        Size = UDim2.new(1, 0, 0, baseInputHeight),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        ZIndex = 601,
    })
    corner(inputShell, 12)
    local inputStroke = stroke(inputShell, Theme.Border, 1, 0.18)
    applySoftSurfaceGradient(inputShell, self, "Surface3", "Surface2", 100)

    local prompt = makeText(inputShell, ">", 17, Theme.AccentVisible, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    prompt.Position = UDim2.fromOffset(12, 0)
    prompt.Size = UDim2.fromOffset(22, baseInputHeight)
    prompt.ZIndex = 603

    local keyLabel = makeText(inputShell, "", 10, Theme.Muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    keyLabel.AnchorPoint = Vector2.new(1, 0.5)
    keyLabel.Position = UDim2.new(1, -12, 0.5, 0)
    keyLabel.Size = UDim2.fromOffset(44, 24)
    keyLabel.ZIndex = 603
    self.CommandBarKeyLabel = keyLabel

    local input = create("TextBox", {
        Name = "CommandInput",
        Parent = inputShell,
        BackgroundTransparency = 1,

        -- Keep command text left-aligned beside the fixed prompt while still
        -- allowing long commands to wrap naturally onto additional lines.
        -- The right-side key indicator keeps its own reserved space.
        Position = UDim2.fromOffset(40, 6),
        Size = UDim2.new(1, -96, 1, -12),

        ClearTextOnFocus = false,
        MultiLine = false, -- Enter still executes; wrapping is visual/automatic.
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        Text = "",
        PlaceholderText = tostring(options.Placeholder or "Type ;command or /command..."),
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 603,
    })
    self.CommandBarInput = input

    local suggestions = create("Frame", {
        Name = "Suggestions",
        Parent = root,
        Position = UDim2.fromOffset(0, baseInputHeight + 8),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 601,
    })
    corner(suggestions, 12)
    stroke(suggestions, Theme.Border, 1, 0.28)
    applySoftSurfaceGradient(suggestions, self, "Surface2", "Surface", 100)
    local list = create("Frame", {
        Parent = suggestions,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -16),
        ZIndex = 602,
    })
    create("UIListLayout", {Parent = list, Padding = UDim.new(0, rowGap), SortOrder = Enum.SortOrder.LayoutOrder})

    self.CommandBarSuggestions = suggestions
    self.CommandBarRows = {}
    self._commandMatches = {}
    self._commandSelection = 1

    -- Keep long commands readable instead of horizontally scrolling out of the
    -- palette. The textbox itself remains single-submit (Enter executes), while
    -- TextWrapped makes long input flow onto additional visual lines.
    local function updateCommandInputHeight()
        if not input or not input.Parent then return end

        -- Match the actual left-aligned textbox width so wrapping and height
        -- measurement agree exactly with what the player sees.
        local availableWidth = math.max(120, width - 96)
        local measuredText = tostring(input.Text or "")
        if measuredText == "" then measuredText = tostring(input.PlaceholderText or "") end

        local measuredHeight = 18
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(
                measuredText,
                input.TextSize,
                input.Font,
                Vector2.new(availableWidth, 1000)
            )
        end)
        if ok and bounds then measuredHeight = bounds.Y end

        local targetHeight = math.clamp(math.ceil(measuredHeight) + 20, baseInputHeight, maxInputHeight)
        inputShell.Size = UDim2.new(1, 0, 0, targetHeight)

        -- The prompt/key decorations stay vertically centered while the input
        -- grows downward for wrapped commands. The textbox uses scale-height,
        -- so each wrapped line remains centered inside the expanded shell.
        prompt.Size = UDim2.fromOffset(22, targetHeight)
        keyLabel.Position = UDim2.new(1, -12, 0, math.floor(targetHeight / 2))
        suggestions.Position = UDim2.fromOffset(0, targetHeight + 8)
    end

    self._updateCommandInputHeight = updateCommandInputHeight
    updateCommandInputHeight()

    local function pointerInsidePalette(pointer)
        if pointInside(inputShell, pointer) then return true end
        if suggestions.Visible and pointInside(suggestions, pointer) then return true end
        return false
    end

    local function applySuggestion(suggestion)
        if not suggestion then return false end
        if tostring(suggestion.Kind or "") == "hint" then
            task.defer(function()
                if self._commandBarOpen and input.Parent then input:CaptureFocus() end
            end)
            return false
        end
        input.Text = self:_completeCommandSuggestion(input.Text, suggestion)
        input.CursorPosition = #input.Text + 1
        self._commandSelection = 1
        self:_refreshCommandSuggestions()
        task.defer(function()
            if self._commandBarOpen and input.Parent then input:CaptureFocus() end
        end)
        return true
    end

    for index = 1, maxSuggestions do
        local row = create("TextButton", {
            Name = "Suggestion" .. index,
            Parent = list,
            Size = UDim2.new(1, 0, 0, rowHeight),
            BackgroundColor3 = Theme.Surface2,
            BackgroundTransparency = 0.32,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Visible = false,
            LayoutOrder = index,
            ZIndex = 603,
        })
        corner(row, 9)
        local rowStroke = stroke(row, Theme.BorderSoft, 1, 0.58)

        local nameLabel = makeText(row, "", 13, Theme.Text, Enum.Font.GothamSemibold)
        nameLabel.Position = UDim2.fromOffset(12, 4)
        nameLabel.Size = UDim2.new(1, -150, 0, 18)
        nameLabel.ZIndex = 604

        local metaLabel = makeText(row, "", 10, Theme.Muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
        metaLabel.AnchorPoint = Vector2.new(1, 0)
        metaLabel.Position = UDim2.new(1, -12, 0, 5)
        metaLabel.Size = UDim2.fromOffset(128, 16)
        metaLabel.TextTruncate = Enum.TextTruncate.AtEnd
        metaLabel.ZIndex = 604

        local descLabel = makeText(row, "", 10, Theme.Muted, Enum.Font.Gotham)
        descLabel.Position = UDim2.fromOffset(12, 24)
        descLabel.Size = UDim2.new(1, -24, 0, 15)
        descLabel.ZIndex = 604
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd

        self.CommandBarRows[index] = {
            Button = row,
            Stroke = rowStroke,
            Name = nameLabel,
            Meta = metaLabel,
            Description = descLabel,
        }

        self:_trackConnection(row.MouseButton1Click:Connect(function()
            local suggestion = self._commandMatches and self._commandMatches[index]
            if not suggestion then return end
            self:_playSound("Hover")
            applySuggestion(suggestion)
        end))
    end

    local function renderRows()
        local matches = self._commandMatches or {}
        if #matches == 0 then
            suggestions.Visible = false
            suggestions.Size = UDim2.new(1, 0, 0, 0)
            for _, rowData in ipairs(self.CommandBarRows) do rowData.Button.Visible = false end
            return
        end

        self._commandSelection = math.clamp(self._commandSelection or 1, 1, #matches)
        local visibleCount = math.min(#matches, maxSuggestions)
        local height = 16 + visibleCount * rowHeight + math.max(0, visibleCount - 1) * rowGap
        suggestions.Size = UDim2.new(1, 0, 0, height)
        suggestions.Visible = true

        for index, rowData in ipairs(self.CommandBarRows) do
            local suggestion = matches[index]
            rowData.Button.Visible = suggestion ~= nil
            if suggestion then
                rowData.Name.Text = tostring(suggestion.Name or suggestion.Insert or "")
                rowData.Description.Text = tostring(suggestion.Description or "")
                rowData.Meta.Text = tostring(suggestion.Meta or "")

                local selected = index == self._commandSelection
                setThemeRole(rowData.Button, "BackgroundColor3", selected and "AccentSoft" or "Surface2")
                rowData.Button.BackgroundTransparency = selected and 0.06 or 0.32
                setThemeRole(rowData.Stroke, "Color", selected and "AccentVisible" or "BorderSoft")
                rowData.Stroke.Transparency = selected and 0.28 or 0.58
                setThemeRole(rowData.Name, "TextColor3", selected and "AccentVisible" or "Text")
                setThemeRole(rowData.Meta, "TextColor3", selected and "AccentVisible" or "Muted")
            end
        end
    end

    function self:_refreshCommandSuggestions()
        if not self.CommandBarInput then return end
        local matches, context = self:GetCommandSuggestions(self.CommandBarInput.Text, maxSuggestions)
        self._commandMatches = matches or {}
        self._commandSuggestionContext = context
        self._commandSelection = math.clamp(self._commandSelection or 1, 1, math.max(#self._commandMatches, 1))
        renderRows()
    end

    self:_registerThemeRenderer(function()
        if inputShell.Parent then
            setThemeRole(inputStroke, "Color", self._commandBarOpen and "AccentVisible" or "Border")
            renderRows()
        end
    end)

    self:_trackConnection(input:GetPropertyChangedSignal("Text"):Connect(function()
        self._commandSelection = 1
        updateCommandInputHeight()
        self:_refreshCommandSuggestions()
    end))

    self:_trackConnection(input.Focused:Connect(function()
        setThemeRole(inputStroke, "Color", "AccentVisible")
        inputStroke.Transparency = 0.10
    end))

    self:_trackConnection(input.FocusLost:Connect(function(enterPressed)
        if not self._commandBarOpen then return end
        if enterPressed then
            local selected = self._commandMatches and self._commandMatches[self._commandSelection or 1]

            -- Discord-style completion: Enter accepts an argument suggestion.
            -- For command names, Enter only completes when the typed name is not
            -- already an exact registered command; otherwise it executes.
            if selected then
                if selected.Kind == "hint" then
                    task.defer(function()
                        if self._commandBarOpen and input.Parent then input:CaptureFocus() end
                    end)
                    return
                elseif selected.Kind == "argument" then
                    applySuggestion(selected)
                    return
                elseif selected.Kind == "command" then
                    local typedName = splitCommandLine(input.Text)[1]
                    local exact = typedName and self:_findCommand(typedName)
                    if not exact then
                        applySuggestion(selected)
                        return
                    end
                end
            end

            local ok, err = self:ExecuteCommand(input.Text)
            if ok then
                self:_playSound("Confirm")
                self:CloseCommandBar(false, true)
            else
                self:Notify({Title = "Command", Content = tostring(err), Type = "Error", Duration = 3})
                task.defer(function()
                    if self._commandBarOpen and input.Parent then input:CaptureFocus() end
                end)
            end
        else
            setThemeRole(inputStroke, "Color", "Border")
            inputStroke.Transparency = 0.18

            -- The CanvasGroup reserves room for the maximum suggestion list, so
            -- using the root rectangle made some invisible space count as inside.
            -- Only the visible input shell and visible suggestion frame now keep
            -- focus. Every other click closes and clears the command palette.
            task.defer(function()
                if not self._commandBarOpen or not root.Parent then return end
                local pointer = UserInputService:GetMouseLocation()
                if not pointerInsidePalette(pointer) then
                    self:CloseCommandBar(false, true)
                end
            end)
        end
    end))

    self:_trackConnection(UserInputService.InputBegan:Connect(function(key, processed)
        if self._destroyed or self._capturingKeybind then return end

        if self._commandBarOpen then
            if key.UserInputType ~= Enum.UserInputType.Keyboard then
                if key.UserInputType == Enum.UserInputType.MouseButton1
                    or key.UserInputType == Enum.UserInputType.MouseButton2
                    or key.UserInputType == Enum.UserInputType.Touch then

                    local pointer = key.Position
                    if not pointerInsidePalette(pointer) then
                        self:CloseCommandBar(false, true)
                    end
                end
                return
            end

            if key.KeyCode == Enum.KeyCode.Escape then
                self:CloseCommandBar(false, true)
            elseif key.KeyCode == Enum.KeyCode.Down then
                local count = #(self._commandMatches or {})
                if count > 0 then
                    self._commandSelection = (self._commandSelection % count) + 1
                    renderRows()
                end
            elseif key.KeyCode == Enum.KeyCode.Up then
                local count = #(self._commandMatches or {})
                if count > 0 then
                    self._commandSelection = ((self._commandSelection - 2) % count) + 1
                    renderRows()
                end
            elseif key.KeyCode == Enum.KeyCode.Tab then
                local selected = self._commandMatches and self._commandMatches[self._commandSelection or 1]
                if selected then applySuggestion(selected) end
            end
            return
        end

        if processed or UserInputService:GetFocusedTextBox() then return end
        if key.UserInputType == Enum.UserInputType.Keyboard and key.KeyCode == self.CommandBarKey then
            self:OpenCommandBar()
        end
    end))

    self:SetCommandBarKey(options.Key or self.Settings.CommandBarKey or "Semicolon")
    self:_refreshCommandSuggestions()
end

local function registerDefaultCommands(window)
    window:RegisterCommand({
        Name = "help",
        Aliases = {"commands", "cmds"},
        Description = "List the commands currently registered with Vitality.",
        Usage = "help",
        Category = "Vitality",
        Callback = function()
            local names = {}
            for _, command in ipairs(window:GetCommands(false)) do
                table.insert(names, command.Name)
            end
            window:Notify({
                Title = "Vitality commands",
                Content = table.concat(names, ", "),
                Type = "Info",
                Duration = 7,
            })
        end,
    })

    window:RegisterCommand({
        Name = "notify",
        Aliases = {"testnotify"},
        Description = "Send a local Vitality test notification.",
        Usage = "notify [message]",
        Category = "Developer",
        Callback = function(args)
            local message = #args > 0 and table.concat(args, " ") or "The command bar is working."
            window:Notify({Title = "Command test", Content = message, Type = "Info", Duration = 4})
        end,
    })

    window:RegisterCommand({
        Name = "hide",
        Aliases = {"hideui"},
        Description = "Hide the main Vitality window without destroying it.",
        Usage = "hide",
        Category = "Interface",
        Callback = function() window:SetVisible(false, false) end,
    })

    window:RegisterCommand({
        Name = "show",
        Aliases = {"showui"},
        Description = "Show the main Vitality window.",
        Usage = "show",
        Category = "Interface",
        Callback = function() window:SetVisible(true, false) end,
    })

    window:RegisterCommand({
        Name = "toggleui",
        Aliases = {"ui", "toggle"},
        Description = "Toggle the main Vitality window.",
        Usage = "toggleui",
        Category = "Interface",
        Callback = function() window:Toggle() end,
    })

    window:RegisterCommand({
        Name = "version",
        Aliases = {"ver"},
        Description = "Show the loaded Vitality library version.",
        Usage = "version",
        Category = "Vitality",
        Callback = function()
            window:Notify({Title = "Vitality", Content = "Library " .. tostring(Library.Version), Type = "Info", Duration = 4})
        end,
    })

    window:RegisterCommand({
        Name = "keyinfo",
        Aliases = {"licenseinfo", "hwidinfo"},
        Description = "Show the current KeyAuth session and local identity source.",
        Usage = "keyinfo",
        Category = "Vitality",
        Callback = function()
            local session = window:GetKeySession() or {}
            local remote = type(window.RemoteKeyInfo) == "table"
                and window.RemoteKeyInfo
                or {}

            local remainingText = "not timed"
            local remaining = window:GetKeyRemaining()
            if session.Permanent == true or session.LifetimeLike == true then
                remainingText = "lifetime / long-term"
            elseif remaining ~= nil then
                remainingText = formatKeyRemaining(remaining)
            end

            window:Notify({
                Title = "License info",
                Content =
                    "Provider: " .. tostring(session.Provider or remote.Provider or "unknown")
                    .. "\nSubscription: " .. tostring(session.Subscription or remote.Subscription or "unknown")
                    .. "\nIdentity: " .. tostring(session.IdentitySource or remote.IdentitySource or "unknown")
                    .. "\nIdentity version: " .. tostring(session.IdentityVersion or remote.IdentityVersion or "legacy")
                    .. "\nRemaining: " .. remainingText,
                Type = "Info",
                Duration = 8,
            })
        end,
    })

    window:RegisterCommand({
        Name = "forgetkey",
        Aliases = {"resetkey", "switchkey"},
        Description = "Forget the locally saved key so a different license can be entered on the next execution.",
        Usage = "forgetkey",
        Category = "Vitality",
        Callback = function()
            local removed = false
            if type(window.ForgetSavedKey) == "function" then
                removed = window:ForgetSavedKey()
            end

            window:Notify({
                Title = "Saved key cleared",
                Content =
                    (removed and "Local KeyAuth cache was cleared. " or "No saved key file was found. ")
                    .. "Close Vitality and re-execute the loader to enter another key. This does not reset the server-side KeyAuth HWID.",
                Type = "Success",
                Duration = 8,
            })
        end,
    })

    window:RegisterCommand({
        Name = "status",
        Description = "Show the current module status reported by the hub.",
        Usage = "status",
        Category = "Vitality",
        Callback = function()
            local status = window.ScriptStatus or {}
            local label = status.Label or status.State or "Unknown"
            window:Notify({Title = "Module status", Content = tostring(label), Type = "Info", Duration = 4})
        end,
    })
end

function Library:RegisterCommand(data, callback, description)
    local window = self:GetActiveWindow()
    if not window then return nil end
    return window:RegisterCommand(data, callback, description)
end

function Library:ExecuteCommand(text)
    local window = self:GetActiveWindow()
    if not window then return false, "No active Vitality window." end
    return window:ExecuteCommand(text)
end

function Library:CreateWindow(settings)
    settings = settings or {}

    local windowRole =
        normalizeWindowRole(
            settings.WindowRole
            or "Main"
        )

    local existingState =
        getVitalitySingleton(
            windowRole
        )

    if singletonWindowIsAlive(
        existingState
    ) then

        local existingWindow =
            existingState.Window

        -- Secondary roles such as DeveloperPreview intentionally coexist with
        -- the main Vitality hub. They use their own singleton and never trigger
        -- the production license re-check / duplicate warning path.
        if windowRole ~= "Main" then
            pcall(function()
                if type(existingWindow.SetVisible) == "function" then
                    existingWindow:SetVisible(true, true)
                end
            end)
            return existingWindow
        end

        local keySettings =
            type(settings.KeySettings) == "table"
            and settings.KeySettings
            or {}

        local freshValidator =
            keySettings.RemoteValidator
            or keySettings.Validator

        local activeKey =
            existingWindow.ActiveKey
            or (
                existingWindow.KeySession
                and existingWindow.KeySession.Key
            )

        local revalidated = nil
        local revalidationInfo = nil
        local revalidationTransient = false

        local requiredIdentityVersion =
            tonumber(keySettings.IdentityVersion)

        local activeIdentityVersion =
            tonumber(
                existingWindow.KeySession
                and existingWindow.KeySession.IdentityVersion
            )

        local identityMigrationRequired =
            requiredIdentityVersion ~= nil
            and activeIdentityVersion ~= requiredIdentityVersion
            and keySettings.ResetLegacyKeyCache ~= false

        if identityMigrationRequired then
            if keySettings.SaveKey ~= false then
                clearStoredKey(
                    keyStoragePath(
                        keySettings
                    )
                )
                clearStoredKey(
                    timedKeyStoragePath(
                        keySettings
                    )
                )
            end

            revalidated = false
            revalidationInfo = {
                Message =
                    "Vitality reset the old local KeyAuth binding for the HWID v2 migration. Enter a license key again.",
                IdentityMigration = true,
            }
        end

        -- Every execution performs a fresh server-side validation when an active
        -- remote key exists. A temporary network/API failure must never destroy
        -- an otherwise healthy running session.
        if not identityMigrationRequired
            and type(freshValidator) == "function"
            and type(activeKey) == "string"
            and activeKey ~= "" then

            local ok, first, second =
                pcall(
                    freshValidator,
                    activeKey,
                    {
                        Window = existingWindow,
                        Settings = keySettings,
                        Auto = true,
                        Reexecute = true,
                    }
                )

            if ok then
                local success
                local info

                if type(first) == "table"
                    and second == nil then

                    info = first
                    success = info.Success == true
                else
                    success = first == true
                    info =
                        type(second) == "table"
                        and second
                        or {
                            Message =
                                second ~= nil
                                and tostring(second)
                                or nil,
                        }
                end

                info =
                    type(info) == "table"
                    and info
                    or {}

                revalidationInfo = info

                if not success
                    and (
                        info.Retryable == true
                        or info.Transient == true
                    ) then

                    -- Keep the current already-validated session alive and let
                    -- its normal refresh loop retry later.
                    revalidated = true
                    revalidationTransient = true
                else
                    revalidated = success
                end

                if success then
                    local expiresAt =
                        tonumber(
                            info.ExpiresAt
                            or info.Expiry
                            or info.expiry
                        )

                    local permanent =
                        info.Permanent == true
                        or (
                            info.Permanent == nil
                            and not expiresAt
                        )

                    local session = {
                        Version = 2,
                        Key = activeKey,
                        Remote = true,
                        Provider =
                            info.Provider
                            or keySettings.Provider
                            or "Remote",
                        ExpiresAt =
                            permanent
                            and nil
                            or expiresAt,
                        Permanent = permanent,
                        LifetimeLike =
                            info.LifetimeLike == true
                            or permanent,
                        ExpiryReliable =
                            info.ExpiryReliable ~= false,
                        EnforceLocalExpiry =
                            info.ExpiryReliable ~= false,
                        Subscription = info.Subscription,
                        IdentityVersion =
                            tonumber(
                                info.IdentityVersion
                                or keySettings.IdentityVersion
                            ),
                        IdentitySource =
                            info.IdentitySource,
                    }

                    if session.ExpiresAt
                        and session.EnforceLocalExpiry ~= false
                        and session.ExpiresAt <= os.time() then

                        revalidated = false
                        info.Expired = true
                        info.Message =
                            info.Message
                            or "this key has expired and is not usable!"
                    else
                        existingWindow.ActiveKey =
                            activeKey

                        existingWindow.RemoteKeyInfo =
                            info

                        existingWindow:SetKeySession(
                            session
                        )

                        -- Give the already-running window the newest validator /
                        -- settings from this execution as well.
                        existingWindow.Settings.KeySettings =
                            keySettings

                        local shouldPersist =
                            session.Permanent == true
                            or (
                                session.LifetimeLike == true
                                and keySettings.AutoReuseLongTermKeys ~= false
                            )
                            or keySettings.AutoReuseTemporaryKeys == true

                        if keySettings.SaveKey ~= false then
                            if shouldPersist then
                                saveKeySession(
                                    keyStoragePath(keySettings),
                                    session
                                )
                            else
                                clearStoredKey(
                                    keyStoragePath(keySettings)
                                )
                            end
                        end
                    end
                end
            else
                revalidated = true
                revalidationTransient = true
                revalidationInfo = {
                    Message =
                        "KeyAuth could not be reached during re-execution. The current validated session was kept active.",
                    Error = tostring(first),
                    Retryable = true,
                    Transient = true,
                }
            end
        end

        if revalidated == false then
            if keySettings.SaveKey ~= false then
                clearStoredKey(
                    keyStoragePath(
                        keySettings
                    )
                )
            end

            pcall(function()
                existingWindow:Notify({
                    Title = "License re-check failed",
                    Content =
                        tostring(
                            revalidationInfo
                            and (
                                revalidationInfo.Message
                                or revalidationInfo.message
                            )
                            or "Please enter a valid key."
                        ),
                    Duration = 4,
                    Type = "Error",
                })
            end)

            -- Hard-destroy runs module cleanup first, so old feature connections
            -- are removed before this execution creates a fresh key screen.
            existingWindow:Destroy()
            existingState = nil
        else
            pcall(function()
                if type(
                    existingWindow.SetVisible
                ) == "function" then

                    existingWindow:
                        SetVisible(
                            true,
                            true
                        )
                end
            end)

            local remainingText = ""

            if revalidationTransient then
                remainingText =
                    " KeyAuth was temporarily unavailable, so the existing validated session was kept."
            elseif existingWindow.KeySession
                and (
                    existingWindow.KeySession.Permanent == true
                    or existingWindow.KeySession.LifetimeLike == true
                ) then

                remainingText =
                    " KeyAuth re-checked: lifetime / long-term license."
            elseif type(
                existingWindow.GetKeyRemaining
            ) == "function" then

                local remaining =
                    existingWindow:GetKeyRemaining()

                if remaining ~= nil then
                    remainingText =
                        " KeyAuth re-checked: "
                        .. formatKeyRemaining(
                            remaining
                        )
                        .. " remaining."
                end
            end

            pcall(function()
                if type(
                    existingWindow.Notify
                ) == "function" then

                    existingWindow:Notify({
                        Title = "Script already running!",
                        Content =
                            "No duplicate was started and no feature connections were re-run."
                            .. remainingText
                            .. " Press X to fully close Vitality before re-executing.",
                        Duration = 6,
                        Type = "warning",
                    })
                end
            end)

            warn(
                "[VitalityHub] Duplicate execution blocked after fresh license re-check; existing feature connections were left untouched."
            )

            return existingWindow
        end
    end

    -- Remove a dead/stale registry before creating the replacement.
    if existingState then
        clearVitalitySingleton(nil, windowRole)
    end

    local window = setmetatable({}, WindowMethods)
    window.Settings = settings
    window._windowRole = windowRole
    window.Tabs = {}
    window.TabDropdowns = {}
    window.FlagObjects = {}
    window.ActiveTab = nil
    window.ConfigData = {}
    window:_loadFavorites()
    window._themeRenderers = {}
    window._connections = {}
    window._cleanupCallbacks = {}
    window._transientSounds = {}
    window._destroyed = false
    window._minimized = false
    window.Commands = {}
    window.CommandOrder = {}
    window._commandBarOpen = false
    window._commandBarToken = 0
    window.CommandBarEnabled = settings.CommandBarEnabled ~= false and not (type(settings.CommandBar) == "table" and settings.CommandBar.Enabled == false)
    window.CommandBarKey = normalizeCommandKey((type(settings.CommandBar) == "table" and settings.CommandBar.Key) or settings.CommandBarKey or "Semicolon", "Semicolon")
    window._keyRemoteRefreshToken = 0
    window.ScriptStatus = {
        State = "testing",
        Level = "yellow",
        Role = "Information",
        Label = "In Testing",
        Color = Color3.fromRGB(255, 216, 74),
        GlowColor = Color3.fromRGB(255, 228, 107),
    }
    window.RemoteStatusInfo = nil
    window.StatusManifest = nil
    window.StatusManifestSource = nil
    window.CurrentStatusEntry = nil
    window._statusListeners = {}
    window.LibraryUpdateInfo = nil
    window.RemoteStatusError = nil
    window._statusControlRunning = false
    window._startupCompletionStarted = false
    window._startupReady = false
    window.GameLoadResult = nil
    local suppliedOwner = type(settings.Owner) == "table" and settings.Owner or {}
    window.OwnerInfo = {
        IsOwner = suppliedOwner.IsOwner == true,
        UserId = tonumber(suppliedOwner.UserId) or (LocalPlayer and LocalPlayer.UserId),
        Username = suppliedOwner.Username or (LocalPlayer and LocalPlayer.Name) or "Owner",
        DisplayName = suppliedOwner.DisplayName or (LocalPlayer and LocalPlayer.DisplayName) or "Owner",
    }
    local motion = type(settings.Motion) == "table" and settings.Motion or {}
    window.Motion = {
        Enabled = motion.Enabled ~= false and settings.AnimationsEnabled ~= false,
        ReducedMotion = motion.ReducedMotion == true,
        Speed = math.clamp(tonumber(motion.Speed or settings.AnimationSpeed) or 1, 0.35, 2.5),
    }
    window.NotificationsEnabled = settings.NotificationsEnabled ~= false
    Library.NotificationsEnabled = window.NotificationsEnabled
    window.SoundsEnabled = settings.SoundsEnabled == true
    window.SoundSettings = settings.Sounds or {
        MasterVolume = 0.55,
        Profiles = {
            Click = {Id = "rbxasset://sounds/button.wav", Volume = 0.15, PlaybackSpeed = 1.16, Cooldown = 0.04},
            Toggle = {Id = "rbxasset://sounds/button.wav", Volume = 0.13, PlaybackSpeed = 1.30, Cooldown = 0.05},
            Open = {Id = "rbxasset://sounds/button.wav", Volume = 0.11, PlaybackSpeed = 1.38, Cooldown = 0.06},
            Close = {Id = "rbxasset://sounds/button.wav", Volume = 0.09, PlaybackSpeed = 0.96, Cooldown = 0.06},
            Confirm = {Id = "rbxasset://sounds/button.wav", Volume = 0.14, PlaybackSpeed = 1.48, Cooldown = 0.05},
            Notification = {Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.14, PlaybackSpeed = 1.08, Cooldown = 0.12},
            Success = {Id = "rbxasset://sounds/button.wav", Volume = 0.10, PlaybackSpeed = 1.34, Cooldown = 0.12},
            Error = {Id = "rbxasset://sounds/button.wav", Volume = 0.09, PlaybackSpeed = 0.82, Cooldown = 0.12},
            Warning = {Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.09, PlaybackSpeed = 0.94, Cooldown = 0.12},
            Info = {Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.08, PlaybackSpeed = 1.08, Cooldown = 0.12},
        },
    }
    local configuredMasterVolume = type(window.SoundSettings) == "table" and window.SoundSettings.MasterVolume or nil
    window.SoundVolume = math.clamp(tonumber(settings.SoundVolume or configuredMasterVolume) or 0.55, 0, 1)

    local requestedFixedToggleKey = settings.FixedToggleKey or settings.LockedToggleKey
    if requestedFixedToggleKey ~= nil then
        window._fixedToggleKeyName = normalizeKeyName(requestedFixedToggleKey, "RightBracket")
    else
        window._fixedToggleKeyName = nil
    end

    window.ToggleKey = Enum.KeyCode.RightShift
    window:SetToggleKey(window._fixedToggleKeyName or settings.ToggleKey or "RightShift")
    window.FontPreset = normalizeFontPreset(settings.Font or settings.FontPreset or Library.DefaultFontPreset)
    window.CustomAccent = typeof(settings.AccentColor) == "Color3" and settings.AccentColor or nil
    window.CustomButton = typeof(settings.ButtonColor) == "Color3" and settings.ButtonColor or nil
    local gradients = type(settings.Gradients) == "table" and settings.Gradients or {}
    window.ButtonGradientStart = typeof(gradients.ButtonStart) == "Color3" and gradients.ButtonStart or nil
    window.ButtonGradientEnd = typeof(gradients.ButtonEnd) == "Color3" and gradients.ButtonEnd or nil
    window.AccentGradientStart = typeof(gradients.AccentStart) == "Color3" and gradients.AccentStart or nil
    window.AccentGradientEnd = typeof(gradients.AccentEnd) == "Color3" and gradients.AccentEnd or nil
    window.SurfaceGradientStart = typeof(gradients.SurfaceStart) == "Color3" and gradients.SurfaceStart or nil
    window.SurfaceGradientEnd = typeof(gradients.SurfaceEnd) == "Color3" and gradients.SurfaceEnd or nil
    window.TabGradientStart = typeof(gradients.TabStart) == "Color3" and gradients.TabStart or nil
    window.TabGradientEnd = typeof(gradients.TabEnd) == "Color3" and gradients.TabEnd or nil
    window.IconGradientStart = typeof(gradients.IconStart) == "Color3" and gradients.IconStart or nil
    window.IconGradientEnd = typeof(gradients.IconEnd) == "Color3" and gradients.IconEnd or nil
    window.GradientOptions = {}
    for _, prefix in ipairs({"Accent", "Button", "Tab", "Icon", "Surface"}) do
        local follow = gradients[prefix .. "FollowAccent"]
        if follow == nil then follow = (prefix == "Tab" or prefix == "Icon") end
        window.GradientOptions[prefix] = {
            Enabled = gradients[prefix .. "Enabled"] ~= false,
            FollowAccent = follow == true,
            Rotation = tonumber(gradients[prefix .. "Rotation"]) or (prefix == "Surface" and 100 or 0),
        }
    end
    window.NotificationSettings = {Duration = 4, Position = "Bottom right", Opacity = 100}

    local suppliedBorder = type(settings.BorderStroke) == "table" and settings.BorderStroke or {}
    local borderUsesAccent = suppliedBorder.UseAccent
    if borderUsesAccent == nil then borderUsesAccent = suppliedBorder.Color == nil end
    window.BorderStrokeSettings = {
        Enabled = suppliedBorder.Enabled ~= false and settings.BorderStrokeEnabled ~= false,
        UseAccent = borderUsesAccent ~= false,
        UseThemeBorder = suppliedBorder.UseThemeBorder == true,
        Color = typeof(suppliedBorder.Color) == "Color3" and suppliedBorder.Color or nil,
        Thickness = tonumber(suppliedBorder.Thickness or settings.BorderStrokeThickness) or 1,
        Transparency = tonumber(suppliedBorder.Transparency or settings.BorderStrokeTransparency) or 0.18,
    }

    window.BackgroundSettings = {Enabled = true, Opacity = 55, FollowAccent = false}
    window:_loadConfig()
    window:_restoreAppearance()
    local requestedTheme = tostring(window.ThemeName or settings.Theme or "Dark")
    local presetKey = requestedTheme:lower() == "light" and "Light" or "Dark"
    local initialPalette = cloneTheme(Library.Themes[presetKey])
    if typeof(window.CustomAccent) == "Color3" then
        applyAccentPalette(initialPalette, window.CustomAccent)
    else
        applyAccentPalette(initialPalette, initialPalette.Accent)
    end
    if typeof(window.CustomButton) == "Color3" then
        applyButtonPalette(initialPalette, window.CustomButton)
    else
        applyButtonPalette(initialPalette, initialPalette.Button)
    end
    for key, value in pairs(initialPalette) do Theme[key] = value end
    window.ThemeName = requestedTheme:lower() == "system" and "System" or presetKey

    local gui = create("ScreenGui", {
        Name = "VitalityHubUI_" .. tostring(math.random(1000,9999)),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 100000,
    })
    resolveGuiParent(gui)

    self._roleWindows =
        type(self._roleWindows) == "table"
        and self._roleWindows
        or {}
    self._roleWindows[windowRole] = window

    if windowRole == "Main" then
        self._screenGui = gui
        self._activeWindow = window
    end

    window.Gui = gui

    setVitalitySingleton(
        window,
        gui,
        windowRole
    )

    local commandBarSettings =
        type(settings.CommandBar) == "table"
        and settings.CommandBar
        or {}

    if commandBarSettings.Enabled ~= false
        and settings.CommandBarEnabled ~= false then
        registerDefaultCommands(window)
        window:_setupCommandBar()
    else
        window.CommandBarEnabled = false
    end

    local main = create("CanvasGroup", {
        Parent = gui,
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5, 0, 0.5, 18),
        Size = UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.WindowHeight),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0,
        GroupTransparency = 1,
        BorderSizePixel = 0,
        -- The root window is a final hard clip. This prevents any CanvasGroup,
        -- section, or animated descendant from ever drawing beyond the window.
        ClipsDescendants = true,
    })
    local mainSurface = create("Frame", {
        Parent = main,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
    })
    corner(main, 18)
    corner(mainSurface, 18)
    applySoftSurfaceGradient(mainSurface, window, "Surface", "Background", 115)
    window.WindowStroke = stroke(main, Theme.AccentVisible, 1, 0.32)
    pcall(function() window.WindowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
    window.AccentStroke = window.WindowStroke
    window.Main = main
    window.MainSurface = mainSurface
    window._expandedSize = UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.WindowHeight)
    window._collapsedSize = UDim2.fromOffset(UIStyle.WindowWidth, UIStyle.TopbarHeight)
    window._restingPosition = UDim2.fromScale(0.5, 0.5)
    window._visible = false
    window:_refreshWindowBorder()

    local topbar = create("Frame", {
        Parent = mainSurface,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,UIStyle.TopbarHeight),
        ZIndex = 100,
    })
    -- Roblox ClipsDescendants clips to a rectangle, not to a UICorner shape.
    -- Round the actual visible edge object so the window's outer top corners
    -- are visibly curved rather than square.
    corner(topbar, 18)
    create("Frame", {Parent=topbar,BackgroundColor3=Theme.BorderSoft,BorderSizePixel=0,Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1)})

    applySoftSurfaceGradient(topbar, window, "Surface2", "Surface", 95)
    local logo=createIcon(topbar, settings.Icon or "vitality", "vitality")
    logo.AnchorPoint=Vector2.new(0,0.5)
    logo.Position=UDim2.new(0,14,0.5,0); logo.Size=UDim2.fromOffset(22,22)
    window.BrandIcon = settings.Icon or "vitality"

    local title=makeText(topbar, settings.Name or "vitality's hub", 16, Theme.Text, Enum.Font.GothamSemibold)
    title.Position=UDim2.fromOffset(41,0); title.Size=UDim2.new(1,-300,1,0)
    title.TextTruncate=Enum.TextTruncate.AtEnd
    window.HeaderTitle=title
    window.BaseHeaderTitle=settings.Name or "vitality's hub"
    window:_refreshHeaderTitle()

    local statusChip=create("Frame",{
        Parent=topbar,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-138,0.5,0),Size=UDim2.fromOffset(194,42),
        BackgroundColor3=Theme.Surface3,BackgroundTransparency=0.04,BorderSizePixel=0,
    })
    corner(statusChip,9); stroke(statusChip,Theme.Border,1,0.42)
    applySoftSurfaceGradient(statusChip, window, "Surface3", "Surface2", 95)
    local statusHalo=create("Frame",{
        Parent=statusChip,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,18,0.5,0),Size=UDim2.fromOffset(22,22),
        BackgroundColor3=Theme.Warning,BackgroundTransparency=0.91,BorderSizePixel=0,
    })
    corner(statusHalo,16)
    local statusGlow=create("Frame",{
        Parent=statusChip,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,18,0.5,0),Size=UDim2.fromOffset(16,16),
        BackgroundColor3=Theme.Warning,BackgroundTransparency=0.72,BorderSizePixel=0,
    })
    corner(statusGlow,9)
    local statusDot=create("Frame",{
        Parent=statusChip,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,18,0.5,0),Size=UDim2.fromOffset(8,8),
        BackgroundColor3=Theme.Warning,BorderSizePixel=0,
    })
    corner(statusDot,5); stroke(statusDot,Theme.Background,1.5,0.02)
    local statusLabel=makeText(statusChip,"Partially working",13,Theme.Text,Enum.Font.GothamSemibold)
    statusLabel.TextTruncate=Enum.TextTruncate.AtEnd
    statusLabel.Position=UDim2.fromOffset(31,0); statusLabel.Size=UDim2.new(1,-40,1,0)
    local keyTimeLabel=makeText(statusChip,"",11,Theme.Text,Enum.Font.GothamMedium)
    keyTimeLabel.TextTruncate=Enum.TextTruncate.AtEnd
    keyTimeLabel.Position=UDim2.fromOffset(31,17); keyTimeLabel.Size=UDim2.new(1,-40,0,13); keyTimeLabel.Visible=false
    local statusHoverTarget=create("TextButton",{
        Parent=statusChip,
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0,18,0.5,0),
        Size=UDim2.fromOffset(32,32),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
    })
    window.StatusChip=statusChip
    window.StatusHalo=statusHalo
    window.StatusGlow=statusGlow
    window.StatusDot=statusDot
    window.StatusLabel=statusLabel
    window.KeyTimeLabel=keyTimeLabel
    window.StatusHoverTarget=statusHoverTarget
    window:SetScriptStatus(window.ScriptStatus.Level,window.ScriptStatus.Label)
    window:AttachTooltip(statusHoverTarget, function()
        local entry = window.CurrentStatusEntry or {
            Name = window.HeaderGameName or window.BaseHeaderTitle or "Current module",
            State = window.ScriptStatus.State,
            Label = window.ScriptStatus.Label,
            Detail = "Status is currently using the loader's local fallback.",
        }
        return statusDetailText(window, entry)
    end, {
        Title = function()
            local entry = window.CurrentStatusEntry or {}
            local definition = window:_resolveStatusState(statusEntryState(entry))
            return statusEntryTitle(entry) .. "  \194\183  " .. tostring(entry.Label or entry.label or definition.Label)
        end,
        Color = function()
            return window.ScriptStatus.Color or Theme.AccentVisible
        end,
        Width = 310,
        Delay = 0.08,
        Placement = "side",
        Gap = 10,
    })
    statusLabel:GetPropertyChangedSignal("Font"):Connect(function() window:_refreshStatusChipLayout() end)
    keyTimeLabel:GetPropertyChangedSignal("Font"):Connect(function() window:_refreshStatusChipLayout() end)
    local pulseTime = 0
    window:_trackConnection(RunService.Heartbeat:Connect(function(dt)
        if not statusHalo.Parent or not main.Visible then return end
        if window.Motion.Enabled == false or window.Motion.ReducedMotion then
            statusHalo.Size = UDim2.fromOffset(22,22)
            statusHalo.BackgroundTransparency = 0.91
            return
        end
        pulseTime = (pulseTime + dt) % 2.1
        local phase = pulseTime / 2.1
        local size = 19 + 9 * phase
        statusHalo.Size = UDim2.fromOffset(size,size)
        statusHalo.BackgroundTransparency = 1 - 0.14 * math.sin(math.pi * phase)
    end))

    -- Permanent Personalization shortcut.
    -- This is intentionally independent of the left navigation; supported and
    -- fallback modules may hide the Personalization tab button while this
    -- topbar shortcut remains visible and fully functional.
    local personalizationButton=create("TextButton",{
        Parent=topbar,
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-94,0.5,0),
        Size=UDim2.fromOffset(32,32),
        BackgroundColor3=Theme.AccentSoft,
        BackgroundTransparency=0,
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
        Visible=true,
        ZIndex=104,
    })
    corner(personalizationButton,8)
    applyThemeGradient(personalizationButton, window, "icon", 0.32)

    local personalizationStroke=stroke(
        personalizationButton,
        Theme.AccentVisible,
        1,
        0.10
    )
    personalizationStroke:SetAttribute(
        "NovaThemeRole_Color",
        "Border"
    )

    local personalizationIcon=createIcon(
        personalizationButton,
        "palette",
        "palette"
    )
    personalizationIcon.AnchorPoint=Vector2.new(0.5,0.5)
    personalizationIcon.Position=UDim2.fromScale(0.5,0.5)
    personalizationIcon.Size=UDim2.fromOffset(18,18)
    personalizationIcon.ZIndex=106
    setIconColor(personalizationIcon, Theme.Text)

    -- IMPORTANT:
    -- ScreenGui uses ZIndexBehavior.Global. Vector icons are composed of child
    -- Frames/UIStrokes, and those children do NOT inherit the holder's ZIndex.
    -- The previous build put the holder above the button but left its drawn
    -- pieces below the button background, making the palette appear missing.
    -- Explicitly raise every drawable child above the button.
    for _, iconDescendant in ipairs(personalizationIcon:GetDescendants()) do
        if iconDescendant:IsA("GuiObject") then
            iconDescendant.ZIndex = 107
        end
    end

    -- Small accent indicator makes the shortcut easy to identify even on dark
    -- themes where Surface3 is close to the topbar color.
    local personalizationAccent=create("Frame",{
        Parent=personalizationButton,
        AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,1,-2),
        Size=UDim2.fromOffset(12,2),
        BackgroundColor3=Theme.AccentVisible,
        BorderSizePixel=0,
        ZIndex=108,
    })
    corner(personalizationAccent,1)

    personalizationButton.MouseEnter:Connect(function()
        window:_tween(personalizationStroke,0.14,{Transparency=0.20})
    end)
    personalizationButton.MouseLeave:Connect(function()
        window:_tween(personalizationStroke,0.14,{Transparency=0.48})
    end)


    window:_trackConnection(personalizationButton.MouseButton1Click:Connect(function()
        window:_playSound("Click")

        if not window:OpenPersonalization() then
            window:Notify({
                Title = "Personalization",
                Content = "The personalization page is not available yet.",
                Duration = 2.5,
                Type = "Error",
            })
        end
    end))

    window.PersonalizationButton=personalizationButton
    window.PersonalizationIcon=personalizationIcon

    local minimize=create("TextButton",{
        Parent=topbar,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-52,0.5,0),Size=UDim2.fromOffset(32,32),
        BackgroundColor3=Theme.Surface3,BorderSizePixel=0,Text="-",TextColor3=Theme.Text,TextSize=16,Font=Enum.Font.Gotham,AutoButtonColor=false,
    }); corner(minimize,6); bindHover(minimize,function() return Theme.Surface3 end,function() return Theme.Border end)
    window.MinimizeButton=minimize
    local close=create("TextButton",{
        Parent=topbar,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(32,32),
        BackgroundColor3=Theme.Surface3,BorderSizePixel=0,Text="X",TextColor3=Theme.Text,TextSize=13,Font=Enum.Font.GothamSemibold,AutoButtonColor=false,
    }); corner(close,6); bindHover(close,function() return Theme.Surface3 end,Color3.fromRGB(86,45,60))

    -- Everything below the header lives inside a dedicated clipped viewport.
    -- This makes header/content overlap structurally impossible, even during
    -- tab animations, scrolling, collapse/expand, or fast window dragging.
    local bodyViewport = create("Frame", {
        Parent = mainSurface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, UIStyle.TopbarHeight),
        Size = UDim2.new(1, 0, 1, -UIStyle.TopbarHeight),
        ClipsDescendants = true,
        ZIndex = 1,
    })
    window.BodyViewport = bodyViewport

    -- Global ZIndexBehavior means every header child needs an explicit layer.
    -- Keep the entire header above page contents as a second line of defense.
    for _, descendant in ipairs(topbar:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            descendant.ZIndex = math.max(descendant.ZIndex, 101)
        end
    end

    logo.ZIndex = 102
    for _, part in ipairs(logo:GetDescendants()) do if part:IsA("GuiObject") then part.ZIndex = 103 end end
    statusChip.ZIndex = 101
    statusHalo.ZIndex, statusGlow.ZIndex, statusDot.ZIndex = 102, 103, 104
    statusLabel.ZIndex, keyTimeLabel.ZIndex = 105, 105
    statusHoverTarget.ZIndex = 106
    -- Re-assert the Personalization shortcut layers after normalizing the
    -- header. This matters because Global ZIndex does not inherit through the
    -- palette vector icon hierarchy.
    if personalizationButton then
        personalizationButton.ZIndex = 104
    end

    if personalizationIcon then
        personalizationIcon.ZIndex = 106

        for _, iconDescendant in ipairs(personalizationIcon:GetDescendants()) do
            if iconDescendant:IsA("GuiObject") then
                iconDescendant.ZIndex = 107
            end
        end
    end

    if personalizationAccent then
        personalizationAccent.ZIndex = 108
    end

    local nav=create("CanvasGroup",{
        Parent=bodyViewport,BackgroundColor3=Theme.Surface,GroupTransparency=0,BorderSizePixel=0,Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,UIStyle.SidebarWidth,1,0),
        ClipsDescendants=true,ZIndex=1,
    })
    corner(nav, 18)

    -- Keep the sidebar's INTERNAL joins square while preserving the true
    -- bottom-left outer corner. These fillers sit inside the rectangular
    -- viewport, so only the intended outside corner stays rounded.
    create("Frame",{
        Name="NavTopSquareFill",Parent=nav,BackgroundColor3=Theme.Surface,
        BorderSizePixel=0,Position=UDim2.fromOffset(0,0),
        Size=UDim2.new(1,0,0,18),ZIndex=1,
    })
    create("Frame",{
        Name="NavBottomRightSquareFill",Parent=nav,BackgroundColor3=Theme.Surface,
        BorderSizePixel=0,AnchorPoint=Vector2.new(1,1),
        Position=UDim2.fromScale(1,1),Size=UDim2.fromOffset(18,18),ZIndex=1,
    })

    create("Frame",{Parent=nav,BackgroundColor3=Theme.BorderSoft,BorderSizePixel=0,Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0)})
    local navList=create("ScrollingFrame",{Parent=nav,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(9,12),Size=UDim2.new(1,-18,1,-82),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2,ScrollBarImageColor3=Theme.Disabled,ScrollingDirection=Enum.ScrollingDirection.Y})
    create("UIListLayout",{Parent=navList,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
    window.NavList=navList

    local version=makeText(nav,"v"..Library.Version,10,Theme.Muted,Enum.Font.Gotham)
    version.Position=UDim2.new(0,16,1,-46); version.Size=UDim2.new(1,-28,0,16)
    local built=makeText(nav,settings.Footer or "vitality",9,Theme.Muted,Enum.Font.Gotham)
    built.Position=UDim2.new(0,16,1,-29); built.Size=UDim2.new(1,-28,0,16)

    local content=create("Frame",{
        Parent=bodyViewport,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(UIStyle.SidebarWidth,0),Size=UDim2.new(1,-UIStyle.SidebarWidth,1,-1),
        -- Use a normal Frame for the content clipping boundary. A CanvasGroup
        -- here can create a separate render layer and allow descendant groups to
        -- appear outside the intended viewport on some Roblox clients.
        ClipsDescendants=true,ZIndex=1,
    })
    window.Content=content
    -- Created before the pages so cards and their controls render above it.
    window.BackgroundImage = create("ImageLabel", {
        Name = "ContentBackground", Parent = content,
        BackgroundTransparency = 1, BorderSizePixel = 0,

        -- Extend the image beyond the top/left clipping edges so those internal
        -- joins remain square. Its right/bottom edges still align exactly with
        -- the window, allowing the bottom-right outside corner to be rounded.
        Position = UDim2.fromOffset(-18, -18),
        Size = UDim2.new(1, 18, 1, 18),

        Image = "rbxassetid://111163405710122", ScaleType = Enum.ScaleType.Crop,
        ImageTransparency = 0.45, Active = false, Selectable = false, ZIndex = 1,
    })
    corner(window.BackgroundImage, 18)
    window:_registerThemeRenderer(function() window:_refreshBackground() end)
    window:_refreshBackground()
    window.NavPanel = nav
    window.SidebarWidth = UIStyle.SidebarWidth
    window.SidebarCollapsed = false

    -- The divider changes only the navigation width; the outer window stays fixed.
    local divider = create("TextButton", {
        Name = "SidebarResizeHandle", Parent = bodyViewport,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, Active = true,
        Position = UDim2.fromOffset(UIStyle.SidebarWidth - 4, 0),
        Size = UDim2.new(0, 8, 1, 0), ZIndex = 20,
    })
    local dividerHighlight = create("Frame", {
        Parent = divider, BackgroundColor3 = Theme.AccentVisible,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(3, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 21,
    })
    themeProperty(dividerHighlight, "BackgroundColor3", "AccentVisible")
    function window:SetSidebarWidth(value)
        local width = math.clamp(math.floor((tonumber(value) or UIStyle.SidebarWidth) + 0.5), 56, 240)
        self.SidebarWidth = width
        self.SidebarCollapsed = width <= 72
        if self._layoutQuickNavigation then self._layoutQuickNavigation() end
        nav.Size = UDim2.new(0, width, 1, 0)
        content.Position = UDim2.fromOffset(width, 0)
        content.Size = UDim2.new(1, -width, 1, -1)
        divider.Position = UDim2.fromOffset(width - 4, 0)
        version.Visible = not self.SidebarCollapsed
        built.Visible = not self.SidebarCollapsed
        for _, tab in ipairs(self.Tabs) do
            if tab._fitNavigation then tab._fitNavigation() end
        end
        for _, dropdown in ipairs(self.TabDropdowns or {}) do
            if dropdown._fitNavigation then dropdown._fitNavigation() end
        end
        return width
    end
    local resizeInput, resizeStartX, resizeStartWidth
    window:_trackConnection(divider.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Library:_closePopup()
        resizeInput, resizeStartX, resizeStartWidth = input, input.Position.X, window.SidebarWidth
        dividerHighlight.BackgroundTransparency = 0
    end))
    window:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not resizeInput then return end
        local mouse = resizeInput.UserInputType == Enum.UserInputType.MouseButton1
        if (mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or input == resizeInput then
            window:SetSidebarWidth(resizeStartWidth + (input.Position.X - resizeStartX) / logicalScale(nav))
        end
    end))
    window:_trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input == resizeInput then
            resizeInput = nil
            dividerHighlight.BackgroundTransparency = 1
        end
    end))
    window:_trackConnection(UserInputService.WindowFocusReleased:Connect(function()
        resizeInput = nil
        dividerHighlight.BackgroundTransparency = 1
    end))
    window:_trackConnection(divider.MouseEnter:Connect(function() dividerHighlight.BackgroundTransparency = 0 end))
    window:_trackConnection(divider.MouseLeave:Connect(function()
        if not resizeInput then dividerHighlight.BackgroundTransparency = 1 end
    end))
    window:_setupQuickNavigation()
    window:SetSidebarWidth(settings.SidebarWidth or UIStyle.SidebarWidth)

    -- Dragging from the header. This never binds Escape, so menu contents remain intact.
    local dragging=false; local dragStart; local startPos
    window:_trackConnection(topbar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            Library:_closePopup()
            dragging=true; dragStart=input.Position; startPos=main.Position
        end
    end))
    window:_trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end))
    window:_trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false
            window._restingPosition = main.Position
        end
    end))

    window:_trackConnection(minimize.MouseButton1Click:Connect(function()
        window:_playSound("Click")
        window:ToggleMinimized(false)
    end))

    window:_trackConnection(close.MouseButton1Click:Connect(function()
        -- X is an immediate hard teardown.
        window:Destroy()
    end))

    window:_trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if window._capturingKeybind or UserInputService:GetFocusedTextBox() then return end
        if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==window.ToggleKey then
            window:Toggle()
        end
    end))

    -- One popup at a time, dismissed consistently by clicks or taps outside it.
    window:_trackConnection(UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local popup, anchor = Library._openPopup, Library._openPopupAnchor
        if popup and not pointInside(popup, input.Position) and not pointInside(anchor, input.Position) then
            Library:_closePopup()
        end
    end))

    -- Responsive scaling: preserve the reference proportions on smaller displays.
    local uiScale=create("UIScale",{Parent=main,Scale=1})
    local function updateScale()
        local cam=workspace.CurrentCamera
        if not cam then return end
        local vp=cam.ViewportSize
        uiScale.Scale=math.clamp(math.min(vp.X/(UIStyle.WindowWidth + 40),vp.Y/(UIStyle.WindowHeight + 60)),0.25,1)
    end
    updateScale()
    if workspace.CurrentCamera then window:_trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)) end

    if window.SoundsEnabled then window:_prepareSounds() end
    main.Visible = false
    task.defer(function() startStartupSequence(window) end)
    return window
end

armRouter()

return Library