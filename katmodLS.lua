-- vitality's hub / KAT / 1.0.0-LS
-- Module contract matches mm2modLS.lua. Requires the supplied libraryLS.lua.
-- Aim selection adapted from ENI's uploaded KAT Silent Aim standalone 1.0.2.
-- Retains its broad >=100-stud ray matching; knife compatibility needs live testing.
-- Uses Vitality flags/configuration and cleanup; creates no standalone GUI.

return function(context)
    assert(type(context) == "table", "KAT requires a module context")
    local Library = assert(context.Library or context.NovaField, "Vitality library missing")
    local Window = assert(context.Window, "Vitality window missing")
    local KEY = "__VITALITY_KAT_MODULE_BUILD_STATE"
    local ROUTER_KEY = "__VITALITY_KAT_LS_ROUTER_V1"
    local previous = rawget(_G, KEY)
    if type(previous) == "table" and previous.Window == Window
        and previous.Ready and previous.Alive then return true end
    if type(previous) == "table" and type(previous.Restore) == "function" then
        pcall(previous.Restore)
    end

    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local Input = game:GetService("UserInputService")
    local LocalPlayer = assert(Players.LocalPlayer, "KAT requires a Roblox client")
    local Mouse = LocalPlayer:GetMouse()
    local state = {
        Window = Window, Alive = true, Ready = false, Enabled = false,
        Radius = 175, WholeScreen = true, HitPart = "Head", WallCheck = true,
        Matched = 0, Redirected = 0, NoTarget = 0, Errors = 0,
        Connections = {},
    }
    local router = rawget(_G, ROUTER_KEY)
    if type(router) ~= "table" then
        router = { Installed = false }
        rawset(_G, ROUTER_KEY, router)
    end
    local controls = {}
    local function restore()
        if not state.Alive then return end
        state.Alive, state.Ready, state.Enabled = false, false, false
        if router.Owner == state then router.Owner = nil end
        for _, connection in ipairs(state.Connections) do connection:Disconnect() end
        state.Connections = {}
        state.SelectRay = nil
        if rawget(_G, KEY) == state then rawset(_G, KEY, nil) end
    end
    state.Restore = restore
    rawset(_G, KEY, state)
    Window:AddCleanup(restore)

    local function selectRay(ray, ignoreList, ignoreWater)
        local camera, character = Workspace.CurrentCamera, LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not state.Alive or not state.Enabled or not camera
            or not humanoid or humanoid.Health <= 0 then return nil end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        for _, object in ipairs(ignoreList) do
            if typeof(object) == "Instance" then table.insert(ignore, object) end
        end
        table.insert(ignore, character)
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = ignoreWater == true
        local best = state.WholeScreen and math.huge or state.Radius * state.Radius
        local bestPos, bestName
        local magnitude = ray.Direction.Magnitude
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local model = player.Character
                local hum = model and model:FindFirstChildOfClass("Humanoid")
                local part = model and model:FindFirstChild(state.HitPart)
                if not part and model and state.HitPart == "Torso" then
                    part = model:FindFirstChild("UpperTorso")
                end
                if hum and hum.Health > 0 and part and part:IsA("BasePart")
                    and not model:FindFirstChildOfClass("ForceField") then
                    local position = part.Position
                    local point, onScreen = camera:WorldToScreenPoint(position)
                    if onScreen and point.Z > 0 then
                        local dx, dy = point.X - Mouse.X, point.Y - Mouse.Y
                        local distance = dx * dx + dy * dy
                        local direction = position - ray.Origin
                        local length = direction.Magnitude
                        if distance <= best and length > 0.001 and length <= magnitude then
                            local visible = not state.WallCheck
                            if state.WallCheck then
                                local hit = Workspace:Raycast(ray.Origin, direction, params)
                                visible = hit and hit.Instance and hit.Instance:IsDescendantOf(model)
                            end
                            if visible then best, bestPos, bestName = distance, position, player.Name end
                        end
                    end
                end
            end
        end
        state.LastTarget = bestName
        if bestPos then return Ray.new(ray.Origin, (bestPos - ray.Origin).Unit * magnitude) end
        return nil
    end
    state.SelectRay = selectRay

    local function installHook()
        if router.Installed then
            router.Owner = state -- Reattach after every off/on and module reload.
            return true
        end
        if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function"
            or type(setnamecallmethod) ~= "function" then
            state.LastError = "Requires hookmetamethod, getnamecallmethod and setnamecallmethod"
            return false
        end
        -- Capture stable primitives. The persistent dispatcher reads the current owner's selector.
        local getMethod, setMethod = getnamecallmethod, setnamecallmethod
        local getCaller = getcallingscript
        local original
        local function dispatch(self, ...)
            local method = getMethod()
            local owner = router.Owner
            if not owner or not owner.Alive or not owner.Enabled or self ~= Workspace
                or (method ~= "FindPartOnRayWithIgnoreList"
                    and method ~= "findPartOnRayWithIgnoreList") then
                return original(self, ...)
            end
            local args = table.pack(...)
            local replacement
            -- Protect ALL inspection/selection work, keeping original arguments on failure.
            local ok, failure = pcall(function()
                local ray, ignore = args[1], args[2]
                if typeof(ray) ~= "Ray" or type(ignore) ~= "table" then return end
                local magnitude = ray.Direction.Magnitude
                if magnitude ~= magnitude or magnitude == math.huge or magnitude < 100 then return end
                owner.LastRayMag = magnitude
                owner.Matched = owner.Matched + 1
                owner.LastCaller = "unavailable"
                if type(getCaller) == "function" then
                    local callerOk, caller = pcall(getCaller)
                    if callerOk and typeof(caller) == "Instance" then owner.LastCaller = caller.Name end
                end
                replacement = owner.SelectRay(ray, ignore, args[4])
                if typeof(replacement) == "Ray" then
                    owner.Redirected = owner.Redirected + 1
                else
                    owner.NoTarget = owner.NoTarget + 1
                end
            end)
            if ok and typeof(replacement) == "Ray" then args[1] = replacement end
            if not ok then
                owner.Errors = owner.Errors + 1
                owner.LastError = tostring(failure)
            end
            -- Nested Roblox calls above change the active method. Restore before forwarding.
            setMethod(method)
            return original(self, table.unpack(args, 1, args.n))
        end
        local ok, result = pcall(function()
            local callback = type(newcclosure) == "function" and newcclosure(dispatch) or dispatch
            return hookmetamethod(game, "__namecall", callback)
        end)
        if not ok or type(result) ~= "function" then
            state.LastError = "Hook installation failed: " .. tostring(result)
            return false
        end
        original = result
        router.Installed, router.Owner = true, state
        state.LastError = nil
        return true
    end

    local function setEnabled(value)
        if not state.Alive then return end
        state.Enabled = value == true and installHook() == true
        if not state.Enabled and router.Owner == state then router.Owner = nil end
        if controls.Enabled and controls.Enabled:Get() ~= state.Enabled then
            controls.Enabled:Set(state.Enabled, false)
        end
        if value == true and not state.Enabled then
            Window:Notify({Title = "KAT", Content = state.LastError or "Silent aim unavailable", Duration = 5})
        end
    end

    local ok, failure = pcall(function()
        local tab = Window:CreateTab("KAT", "crosshair")
        local aim = tab:CreateSection({Name = "Silent aim", Side = "Left"})
        controls.Enabled = aim:CreateToggle({
            Name = "Silent aim", Flag = "KAT_SilentAim", CurrentValue = false, Callback = setEnabled,
        })
        controls.Key = aim:CreateKeybind({
            Name = "Toggle silent aim", Flag = "KAT_AimKey", CurrentKeybind = "LeftAlt",
            PressedCallback = function(key)
                if not state.Alive or Window._capturingKeybind or Input:GetFocusedTextBox() then return end
                if key == Window:GetToggleKey() then return end
                controls.Enabled:Set(not state.Enabled, true)
            end,
        })
        controls.WholeScreen = aim:CreateToggle({
            Name = "Whole screen", Flag = "KAT_WholeScreen", CurrentValue = true,
            Callback = function(value) if state.Alive then state.WholeScreen = value == true end end,
        })
        controls.Radius = aim:CreateSlider({
            Name = "Radius", Info = "Used when Whole screen is off", Flag = "KAT_Radius",
            Range = {25, 500}, Increment = 1, CurrentValue = 175, Suffix = " px",
            Callback = function(value)
                if state.Alive then state.Radius = math.clamp(tonumber(value) or 175, 25, 500) end
            end,
        })
        controls.Part = aim:CreateDropdown({
            Name = "Target part", Flag = "KAT_TargetPart", Options = {"Head", "Torso"}, CurrentOption = "Head",
            Callback = function(value)
                if state.Alive then state.HitPart = value == "Torso" and "Torso" or "Head" end
            end,
        })
        controls.Wall = aim:CreateToggle({
            Name = "Wall check", Flag = "KAT_WallCheck", CurrentValue = true,
            Callback = function(value) if state.Alive then state.WallCheck = value == true end end,
        })
        local diagnostics = tab:CreateSection({Name = "Diagnostics", Side = "Right"})
        local readout = diagnostics:CreateParagraph({Title = "Silent aim status", Content = "Off"})
        local function report()
            return ("%s | Matched %d | Redirected %d | No target %d | Errors %d\nTarget: %s\nCaller: %s | Ray: %s\nLast error: %s")
                :format(state.Enabled and "On" or "Off", state.Matched, state.Redirected, state.NoTarget,
                    state.Errors, tostring(state.LastTarget or "None"), tostring(state.LastCaller or "None"),
                    tostring(state.LastRayMag or "None"), tostring(state.LastError or "None"))
        end
        diagnostics:CreateButton({Name = "Print diagnostics", Callback = function()
            if state.Alive then print("[Vitality KAT LS] " .. report()) end
        end})
        diagnostics:CreateButton({Name = "Reset diagnostics", Callback = function()
            if not state.Alive then return end
            state.Matched, state.Redirected, state.NoTarget, state.Errors = 0, 0, 0, 0
            state.LastTarget, state.LastCaller, state.LastRayMag, state.LastError = nil, nil, nil, nil
        end})
        diagnostics:CreateParagraph({Title = "Controls", Content =
            "Left Alt toggles aim by default. The hub keeps its existing window key. Choose different keys for the two actions.\nWhole screen targets the nearest eligible player to your cursor. Turn it off to use the radius setting."})
        local elapsed = 0
        table.insert(state.Connections, RunService.Heartbeat:Connect(function(dt)
            if not state.Alive then return end
            elapsed = elapsed + dt
            if elapsed >= 1 then elapsed = 0; readout:Set({Content = report()}) end
        end))
        -- Constructors restore saved values but do not invoke their callbacks.
        state.WholeScreen = controls.WholeScreen:Get() == true
        state.Radius = math.clamp(tonumber(controls.Radius:Get()) or 175, 25, 500)
        state.HitPart = controls.Part:Get() == "Torso" and "Torso" or "Head"
        state.WallCheck = controls.Wall:Get() == true
        setEnabled(controls.Enabled:Get())
    end)
    if not ok then restore(); error("KAT module initialization failed: " .. tostring(failure), 0) end
    state.Ready = true
    Window:Notify({Title = "KAT", Content = "KAT controls loaded. Left Alt toggles silent aim by default.", Duration = 3})
    return true
end
