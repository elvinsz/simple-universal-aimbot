--[[
    Flunium Client v2.0
    ✅ Aimbot 2 → Kunai Mark Aimbot (Kunai Marker удалён)
    ✅ Silent Aim Kunai Mark — Head + HeightOffset через fixmouse
    ✅ Max Distance: 0 или 5000 = без лимита
    ✅ FOV Circle toggle в каждом аиме
    ✅ Visual вкладка → Performance, отдельная удалена
    ✅ Performance оптимизирован (DescendantAdded вместо Heartbeat)
    ✅ Keybinds сохранение
]]

local function Flunium_Boot()

    local existingFluent = getgenv().FluniumFluent
    local existingLoaded = getgenv().FluniumLoaded

    if existingLoaded and existingFluent then
        local alive = false
        pcall(function()
            if existingFluent.Window or (existingFluent.Windows and #existingFluent.Windows > 0) then
                local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
                if pg then
                    for _, child in ipairs(pg:GetChildren()) do
                        if child.Name == "Fluent" or child:FindFirstChild("Fluent") then
                            alive = true
                            break
                        end
                    end
                end
            end
        end)
        if alive then
            pcall(function()
                existingFluent:Notify({Title = "⚠️ Уже загружено", Content = "Flunium Client v2.0 уже запущен!", Duration = 3})
            end)
            return
        else
            warn("⚠️ Flunium: найден мёртвый state, перезагрузка...")
            getgenv().FluniumLoaded = nil
            getgenv().FluniumFluent = nil
        end
    end

    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, child in ipairs(pg:GetChildren()) do
                if child.Name == "Fluent" or child.Name:find("Fluent") then child:Destroy() end
            end
        end
    end)

    local Fluent
    local fluentUrl = "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
    local fluentCache = "FluniumFluent.lua"

    local ok, err = pcall(function()
        if isfile and isfile(fluentCache) then
            local cached = readfile(fluentCache)
            if cached and #cached > 1000 then
                Fluent = loadstring(cached)()
                return
            end
        end
        local src = game:HttpGet(fluentUrl)
        if writefile then pcall(function() writefile(fluentCache, src) end) end
        Fluent = loadstring(src)()
    end)

    if not ok or not Fluent then
        warn("❌ Flunium: не удалось загрузить Fluent — " .. tostring(err))
        getgenv().FluniumLoaded = nil
        getgenv().FluniumFluent = nil
        return
    end

    getgenv().FluniumFluent = Fluent

    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local LocalizationService = game:GetService("LocalizationService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera

    local shindoEvent
    pcall(function() shindoEvent = LocalPlayer:WaitForChild("startevent", 8) end)

    -- ══════════ CONFIG ══════════
    local settings = {
        fov = 300, smoothing = 0.15, prediction = 0.065,
        wallCheck = false, teamCheck = false,
        aimPart = "HumanoidRootPart", aimMode = "Hold",
        aimKey = Enum.KeyCode.BackSlash, ListeningForAimBind = false,
        showFovCircle = true, maxDistance = 0, prioritizeClose = true,
        mode360 = false,
        fovColor = Color3.fromRGB(255, 0, 0),
        targetedColor = Color3.fromRGB(0, 255, 0),
        rainbowFov = false,
        -- Kunai Mark Aimbot (бывший Aimbot 2)
        aim2Fov = 300, aim2Smoothing = 0.15, aim2Prediction = 0.065,
        aim2WallCheck = false, aim2TeamCheck = false,
        aim2Mode = "Hold", aim2Key = Enum.KeyCode.One,
        aim2ListeningForBind = false, aim2ShowFovCircle = true,
        aim2MaxDistance = 0, aim2PrioritizeClose = true, aim2Mode360 = false,
        aim2HeightOffset = 16,
        aim2FovColor = Color3.fromRGB(255, 165, 0),
        aim2TargetedColor = Color3.fromRGB(255, 255, 0),
        aim2RainbowFov = false,
        -- Visual (перенесено)
        xray = false, fullBright = false, nightVision = false,
        noShadows = false, noBloom = false, noSunRays = false,
        rainbowLighting = false, noFog = false
    }

    local silentAim = {
        Enabled = false, MasterEnabled = false, Mode = "Hold",
        HoldKey = Enum.KeyCode.BackSlash, ListeningForBind = false,
        Prediction = 0.187, FOV = 500, TargetPart = "HumanoidRootPart",
        ShowFovCircle = true, MaxDistance = 0, PrioritizeClose = true,
        Mode360 = false, FovColor = Color3.fromRGB(100, 200, 255),
        CachedTarget = nil, CachedCFrame = nil, Logging = false
    }

    -- Silent Aim Kunai Mark
    local silentKunai = {
        Enabled = false, MasterEnabled = false, Mode = "Hold",
        HoldKey = Enum.KeyCode.Two, ListeningForBind = false,
        Prediction = 0.187, FOV = 500,
        ShowFovCircle = true, MaxDistance = 0, PrioritizeClose = true,
        Mode360 = false, FovColor = Color3.fromRGB(255, 0, 255),
        HeightOffset = 16,
        CachedTarget = nil, CachedCFrame = nil
    }

    local ESP = {
        Enabled = false, Visible = false, Range = math.huge,
        UpdateRate = 0.2, Font = Enum.Font.GothamBold, Size = 1.0,
        ShowName = true, ShowHP = true, ShowMD = true, ShowDodge = true,
        NameColor = Color3.fromRGB(255, 255, 255),
        HPColor = Color3.fromRGB(0, 255, 0),
        MDColor = Color3.fromRGB(200, 100, 255),
        DodgeOnColor = Color3.fromRGB(0, 255, 0),
        DodgeCDColor = Color3.fromRGB(255, 60, 60),
        Whitelist = {},
    }

    local perf = {
        lowDetail = false, removeTextures = false, removeDecals = false,
        removeParticles = false, removeShadows = false, forcePlastic = false,
        disablePostFx = false, extendFog = false, optimizeWater = false,
        removeLights = false, removeBeams = false, removeHighlights = false,
        hideAccessories = false, removeCharFx = false,
        blockNewEffects = false,
        fpsUnlock = false, fpsCap = 999,
        cachedProps = {},
        cachedFog = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart},
        cachedLight = {},
    }

    local colors = {RainbowSkin = false, RainbowHair = false, SkinSpeed = 0.5, HairSpeed = 0.5, Invert = true}
    local skinTimer, hairTimer = 0, 0

    local originalLighting = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows
    }

    local aimbotEnabled, aiming, currentTarget = false, false, nil
    local aim2Enabled, aim2ing, aim2Target = false, false, nil
    local lastTargetUpdate, lastTarget2Update = 0, 0
    local hue, lightingHue = 0, 0
    local rainbowSpeed = 0.005

    local ALL_BODY_PARTS = {
        "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
        "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
        "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
        "LeftHand", "RightHand", "LeftFoot", "RightFoot"
    }

    -- FOV circles
    local fovCircle, fovCircle2, silentFovCircle, silentKunaiFovCircle
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2; fovCircle.Radius = settings.fov
        fovCircle.Filled = false; fovCircle.Color = settings.fovColor
        fovCircle.Transparency = 1; fovCircle.Visible = false
    end)
    pcall(function()
        fovCircle2 = Drawing.new("Circle")
        fovCircle2.Thickness = 2; fovCircle2.Radius = settings.aim2Fov
        fovCircle2.Filled = false; fovCircle2.Color = settings.aim2FovColor
        fovCircle2.Transparency = 1; fovCircle2.Visible = false
    end)
    pcall(function()
        silentFovCircle = Drawing.new("Circle")
        silentFovCircle.Thickness = 2; silentFovCircle.Radius = silentAim.FOV
        silentFovCircle.Filled = false; silentFovCircle.Color = silentAim.FovColor
        silentFovCircle.Transparency = 1; silentFovCircle.Visible = false
    end)
    pcall(function()
        silentKunaiFovCircle = Drawing.new("Circle")
        silentKunaiFovCircle.Thickness = 2; silentKunaiFovCircle.Radius = silentKunai.FOV
        silentKunaiFovCircle.Filled = false; silentKunaiFovCircle.Color = silentKunai.FovColor
        silentKunaiFovCircle.Transparency = 1; silentKunaiFovCircle.Visible = false
    end)

    -- ══════════ MAX DISTANCE HELPER ══════════
    local function checkMaxDistance(dist, maxDist)
        if not maxDist or maxDist <= 0 or maxDist >= 5000 then return true end
        return dist <= maxDist
    end

    -- ══════════ PERFORMANCE ══════════
    local perfConnections = {}

    local function disconnectPerfConns()
        for _, c in ipairs(perfConnections) do pcall(function() c:Disconnect() end) end
        perfConnections = {}
    end

    local function applyRemoveParticles(v)
        perf.removeParticles = v
        if v then
            local function handleParticle(obj)
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    if not obj:GetAttribute("FluniumTimeScale") then
                        obj:SetAttribute("FluniumTimeScale", obj.TimeScale)
                    end
                    obj.TimeScale = 0
                    pcall(function() obj:Clear() end)
                end
            end
            for _, obj in ipairs(Workspace:GetDescendants()) do handleParticle(obj) end
            table.insert(perfConnections, Workspace.DescendantAdded:Connect(handleParticle))
        else
            disconnectPerfConns()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    local ts = obj:GetAttribute("FluniumTimeScale")
                    if ts ~= nil then
                        obj.TimeScale = ts
                        obj:SetAttribute("FluniumTimeScale", nil)
                    end
                end
            end
        end
    end

    local function killCharFx(char)
        pcall(function()
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    pcall(function() obj:Clear() end)
                    pcall(function() obj.Enabled = false end)
                elseif obj:IsA("Beam") or obj:IsA("Trail") then
                    pcall(function() obj.Enabled = false end)
                elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                    pcall(function() obj.Enabled = false end)
                elseif obj:IsA("Highlight") then
                    pcall(function() obj.Enabled = false end)
                end
            end
        end)
    end

    local function applyRemoveCharFx(v)
        perf.removeCharFx = v
        if v then
            for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char then killCharFx(char) end
            end
            table.insert(perfConnections, Workspace.DescendantAdded:Connect(function(obj)
                if not perf.removeCharFx then return end
                local char = obj:FindFirstAncestorOfClass("Model")
                if char and Players:GetPlayerFromCharacter(char) then
                    killCharFx(char)
                end
            end))
        else
            disconnectPerfConns()
        end
    end

    local function applyLowDetail(v)
        perf.lowDetail = v
        if v then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if not perf.cachedProps[obj] then
                        perf.cachedProps[obj] = {Material = obj.Material, Reflectance = obj.Reflectance}
                    end
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
            table.insert(perfConnections, Workspace.DescendantAdded:Connect(function(obj)
                if not perf.lowDetail then return end
                if obj:IsA("BasePart") then
                    if not perf.cachedProps[obj] then
                        perf.cachedProps[obj] = {Material = obj.Material, Reflectance = obj.Reflectance}
                    end
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end))
        else
            disconnectPerfConns()
            for obj, data in pairs(perf.cachedProps) do
                if obj and obj.Parent and obj:IsA("BasePart") then
                    pcall(function()
                        obj.Material = data.Material
                        obj.Reflectance = data.Reflectance
                    end)
                end
            end
            perf.cachedProps = {}
        end
    end

    local function applyForcePlastic(v)
        perf.forcePlastic = v
        if v then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if not perf.cachedProps[obj] then
                        perf.cachedProps[obj] = {Material = obj.Material, Reflectance = obj.Reflectance}
                    end
                    obj.Material = Enum.Material.Plastic
                    obj.Reflectance = 0
                end
            end
        else
            for obj, data in pairs(perf.cachedProps) do
                if obj and obj.Parent and obj:IsA("BasePart") then
                    pcall(function()
                        obj.Material = data.Material
                        obj.Reflectance = data.Reflectance
                    end)
                end
            end
            perf.cachedProps = {}
        end
    end

    local function applyRemoveTextures(v)
        perf.removeTextures = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = v and 1 or 0 end
            end
        end)
    end

    local function applyRemoveDecals(v)
        perf.removeDecals = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Decal") then obj.Transparency = v and 1 or 0 end
            end
        end)
    end

    local function applyRemoveShadows(v)
        perf.removeShadows = v
        Lighting.GlobalShadows = not v
    end

    local function applyDisablePostFx(v)
        perf.disablePostFx = v
        pcall(function()
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") or e:IsA("BloomEffect") or e:IsA("BlurEffect")
                   or e:IsA("ColorCorrectionEffect") or e:IsA("SunRaysEffect")
                   or e:IsA("DepthOfFieldEffect") then
                    e.Enabled = not v
                end
            end
        end)
    end

    local function applyExtendFog(v)
        perf.extendFog = v
        if v then Lighting.FogEnd = 100000; Lighting.FogStart = 100000
        else Lighting.FogEnd = perf.cachedFog.FogEnd; Lighting.FogStart = perf.cachedFog.FogStart end
    end

    local function applyOptimizeWater(v)
        perf.optimizeWater = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Terrain") then
                    obj.WaterWaveSize = v and 0 or obj.WaterWaveSize
                    obj.WaterReflectance = v and 0 or obj.WaterReflectance
                    obj.WaterTransparency = v and 1 or obj.WaterTransparency
                end
            end
        end)
    end

    local function applyRemoveLights(v)
        perf.removeLights = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                    if not perf.cachedLight[obj] then
                        perf.cachedLight[obj] = {Enabled = obj.Enabled, Range = obj.Range, Brightness = obj.Brightness}
                    end
                    obj.Enabled = not v
                    if v then
                        obj.Range = 0
                        obj.Brightness = 0
                    else
                        local c = perf.cachedLight[obj]
                        if c then obj.Range = c.Range; obj.Brightness = c.Brightness end
                    end
                end
            end
        end)
    end

    local function applyRemoveBeams(v)
        perf.removeBeams = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Beam") or obj:IsA("Trail") then
                    obj.Enabled = not v
                end
            end
        end)
    end

    local function applyRemoveHighlights(v)
        perf.removeHighlights = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Highlight") or obj:IsA("SelectionBox")
                   or obj:IsA("BoxHandleAdornment") or obj:IsA("SelectionSphere") then
                    obj.Enabled = not v
                end
            end
        end)
    end

    local function applyHideAccessories(v)
        perf.hideAccessories = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Accessory") or obj:IsA("Hat") then
                    local handle = obj:FindFirstChild("Handle")
                    if handle then
                        handle.Transparency = v and 1 or 0
                        handle.LocalTransparencyModifier = v and 1 or 0
                    end
                end
            end
        end)
    end

    local function applyFpsUnlock(v)
        perf.fpsUnlock = v
        if v then
            pcall(function() setfpscap(perf.fpsCap) end)
            Fluent:Notify({Title = "⚡ FPS Unlock", Content = "Cap: " .. tostring(perf.fpsCap), Duration = 3})
        else
            pcall(function() setfpscap(60) end)
        end
    end

    -- ══════════ VISUAL (перенесено в Performance) ══════════
    local function applyXRay(v)
        settings.xray = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if v then
                        if not obj:GetAttribute("OT") then obj:SetAttribute("OT", obj.Transparency) end
                        obj.LocalTransparencyModifier = 0.5
                    else
                        local o = obj:GetAttribute("OT")
                        if o then obj.LocalTransparencyModifier = o end
                    end
                end
            end
        end)
    end

    local function applyFullBright(v)
        settings.fullBright = v
        if v then
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 3; Lighting.ClockTime = 12
        else
            Lighting.Ambient = originalLighting.Ambient
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
            Lighting.Brightness = originalLighting.Brightness
            Lighting.ClockTime = originalLighting.ClockTime
        end
    end

    local function applyNightVision(v)
        settings.nightVision = v
        pcall(function()
            local nv = Lighting:FindFirstChild("NVEffect")
            if v then
                if not nv then
                    nv = Instance.new("ColorCorrectionEffect")
                    nv.Name = "NVEffect"; nv.Brightness = 0.3; nv.Contrast = 0.5
                    nv.Saturation = -0.5; nv.TintColor = Color3.fromRGB(0, 255, 0)
                    nv.Parent = Lighting
                end
                nv.Enabled = true
            elseif nv then nv.Enabled = false end
        end)
    end

    local function applyNoShadows(v) Lighting.GlobalShadows = not v end

    local function applyNoBloom(v)
        pcall(function()
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("BloomEffect") then e.Enabled = not v end
            end
        end)
    end

    local function applyNoSunRays(v)
        pcall(function()
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("SunRaysEffect") then e.Enabled = not v end
            end
        end)
    end

    local function applyNoFog(v)
        if v then
            Lighting.FogEnd = 100000; Lighting.FogStart = 100000
        else
            Lighting.FogEnd = originalLighting.FogEnd
            Lighting.FogStart = originalLighting.FogStart
        end
    end

    -- ══════════ ESP ══════════
    local espData, espConns, espAcc = {}, {}, 0
    local function getRoot(char)
        return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    end
    local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") end
    local function short(v)
        v = math.floor(tonumber(v) or 0)
        if v >= 1e6 then return string.format("%.1fM", v/1e6) end
        if v >= 1e3 then return string.format("%.1fK", v/1e3) end
        return tostring(v)
    end
    local function isWhitelisted(p)
        local hasAny = false
        for _ in pairs(ESP.Whitelist) do hasAny = true; break end
        if not hasAny then return true end
        return ESP.Whitelist[p.Name] == true
    end
    local function getModeValue(p)
        local char = workspace:FindFirstChild(p.Name)
        if char then
            local combat = char:FindFirstChild("combat")
            if combat then
                local mode = combat:FindFirstChild("mode")
                if mode then
                    if mode:IsA("IntValue") or mode:IsA("NumberValue") then return mode.Value
                    elseif mode:IsA("StringValue") then return tonumber(mode.Value) or 0 end
                end
            end
        end
        return 0
    end
    local function getTaijutsuDodgeInfo(p)
        local keys = p:FindFirstChild("statz") and p.statz:FindFirstChild("keys")
        if not keys then return nil end
        for _, slot in ipairs(keys:GetChildren()) do
            if slot:IsA("ValueBase") then
                local nm = string.lower(tostring(slot.Value))
                if nm == "taijutsudodge" then
                    local cdObj = slot:FindFirstChild("cooldown")
                    if cdObj then
                        local cd = tonumber(cdObj.Value) or 0
                        if cd > 0 then return {ready = false, cd = math.floor(cd)}
                        else return {ready = true, cd = 0} end
                    else return {ready = true, cd = 0} end
                end
            end
        end
        return nil
    end
    local function clearPlayer(p)
        local d = espData[p]
        if d and d.gui then pcall(function() d.gui:Destroy() end) end
        espData[p] = nil
    end
    local function makeLabel(parent, size, pos, color, textSize)
        local t = Instance.new("TextLabel")
        t.Size = size; t.Position = pos; t.BackgroundTransparency = 1
        t.TextColor3 = color; t.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        t.TextStrokeTransparency = 0.3; t.Font = ESP.Font
        t.TextSize = textSize or 16
        t.TextXAlignment = Enum.TextXAlignment.Center
        t.TextYAlignment = Enum.TextYAlignment.Center
        t.Parent = parent
        return t
    end
    local function createPlayerESP(p, char)
        if p == LocalPlayer or not isWhitelisted(p) then return end
        if espData[p] and espData[p].gui and espData[p].gui.Parent then return end

        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or getRoot(char)
        local hum = getHumanoid(char)
        if not root or not hum then return end

        local gui = Instance.new("BillboardGui")
        gui.Name = "SimpleESP"
        gui.Size = UDim2.new(0, 200, 0, 90)
        gui.StudsOffset = Vector3.new(0, 4, 0)
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.ResetOnSpawn = false
        gui.Adornee = root
        gui.MaxDistance = ESP.Range
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

        local holder = Instance.new("Frame", gui)
        holder.Size = UDim2.fromScale(1, 1); holder.BackgroundTransparency = 1
        Instance.new("UIScale", holder).Scale = ESP.Size

        local nameLabel = makeLabel(holder, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), ESP.NameColor, 16)
        nameLabel.Text = p.Name
        local hpLabel = makeLabel(holder, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 22), ESP.HPColor, 16)
        local mdLabel = makeLabel(holder, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 42), ESP.MDColor, 16)
        local dodgeLabel = makeLabel(holder, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 62), ESP.DodgeOnColor, 16)

        espData[p] = {gui=gui, char=char, root=root, hum=hum, nameLabel=nameLabel,
            hpLabel=hpLabel, mdLabel=mdLabel, dodgeLabel=dodgeLabel, hp=-1, md=-1, dodgeState=-1}
    end
    local function updateESP()
        if not ESP.Enabled or not ESP.Visible then return end
        for p, d in pairs(espData) do
            if not p.Parent or not d.char or not d.char.Parent then clearPlayer(p); continue end
            if not isWhitelisted(p) then if d.gui then d.gui.Enabled = false end; continue end
            if not d.root or not d.root.Parent then
                d.root = d.char:FindFirstChild("HumanoidRootPart") or d.char:FindFirstChild("Head")
                if d.gui then d.gui.Adornee = d.root end
            end
            if not d.hum or not d.hum.Parent then d.hum = getHumanoid(d.char) end
            if not d.gui or not d.root or not d.hum or d.hum.Health <= 0 then
                if d.gui then d.gui.Enabled = false end; continue
            end
            d.gui.Enabled = true; d.gui.Adornee = d.root
            if ESP.ShowName then d.nameLabel.Visible = true; d.nameLabel.Text = p.Name else d.nameLabel.Visible = false end
            local hp = math.floor(d.hum.Health)
            if d.hp ~= hp then d.hp = hp; d.hpLabel.Text = "HP: " .. short(hp) end
            d.hpLabel.Visible = ESP.ShowHP; d.hpLabel.TextColor3 = ESP.HPColor
            local md = math.floor(getModeValue(p))
            if d.md ~= md then d.md = md; d.mdLabel.Text = "MD: " .. md end
            d.mdLabel.Visible = ESP.ShowMD; d.mdLabel.TextColor3 = ESP.MDColor
            if ESP.ShowDodge then
                local dodgeInfo = getTaijutsuDodgeInfo(p)
                if dodgeInfo then
                    if dodgeInfo.ready then
                        if d.dodgeState ~= 1 then
                            d.dodgeState = 1
                            d.dodgeLabel.Text = "BODY DODGE: ON"
                            d.dodgeLabel.TextColor3 = ESP.DodgeOnColor
                        end
                    else
                        if d.dodgeState ~= dodgeInfo.cd then
                            d.dodgeState = dodgeInfo.cd
                            d.dodgeLabel.Text = "BODY DODGE: " .. dodgeInfo.cd
                            d.dodgeLabel.TextColor3 = ESP.DodgeCDColor
                        end
                    end
                    d.dodgeLabel.Visible = true
                else d.dodgeLabel.Visible = false end
            else d.dodgeLabel.Visible = false end
        end
    end
    local function rebuildESP()
        for p in pairs(espData) do clearPlayer(p) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and isWhitelisted(p) then
                task.spawn(createPlayerESP, p, p.Character)
            end
        end
    end
    local function espWatch(p)
        if p == LocalPlayer then return end
        if espConns[p] then for _, c in ipairs(espConns[p]) do pcall(function() c:Disconnect() end) end end
        espConns[p] = {}
        table.insert(espConns[p], p.CharacterAdded:Connect(function(char)
            if ESP.Enabled and ESP.Visible and isWhitelisted(p) then
                task.defer(function() createPlayerESP(p, char) end)
            end
        end))
        table.insert(espConns[p], p.CharacterRemoving:Connect(function() clearPlayer(p) end))
        if p.Character and ESP.Enabled and ESP.Visible and isWhitelisted(p) then
            task.defer(function() createPlayerESP(p, p.Character) end)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do espWatch(p) end
    Players.PlayerAdded:Connect(espWatch)
    Players.PlayerRemoving:Connect(function(p) clearPlayer(p) end)
    RunService.Heartbeat:Connect(function(dt)
        if not ESP.Enabled or not ESP.Visible then return end
        espAcc += dt
        if espAcc >= ESP.UpdateRate then espAcc = 0; updateESP() end
    end)

    -- ══════════ UNIFIED HOOK ══════════
    local savedEnemyPos = nil
    local function getPriorityEnemy()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local myPos = myRoot.Position
        local best, bestScore = nil, math.huge
        local mousePos = UserInputService:GetMouseLocation()
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if settings.teamCheck and p.Team == LocalPlayer.Team then continue end
            local char = p.Character
            if not char then continue end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local aimPos
            if head then aimPos = head.Position + Vector3.new(0, 0, 0)
            elseif root then aimPos = root.Position + Vector3.new(0, 2, 0)
            else continue end
            local worldDist = (root and root.Position or aimPos - myPos).Magnitude
            local sp, onScreen = Camera:WorldToViewportPoint(aimPos)
            local screenDist = onScreen and (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude or 9999
            local score = screenDist + (worldDist * 0.1)
            if score < bestScore then bestScore = score; best = aimPos end
        end
        return best
    end
    local function replaceVectorInTable(t, newPos, depth)
        depth = depth or 0
        if depth > 4 then return t end
        if typeof(t) == "Vector3" then return newPos
        elseif typeof(t) == "CFrame" then return CFrame.new(newPos)
        elseif type(t) == "table" then
            for k, v in pairs(t) do
                if typeof(v) == "Vector3" then t[k] = newPos
                elseif typeof(v) == "CFrame" then t[k] = CFrame.new(newPos)
                elseif type(v) == "table" then t[k] = replaceVectorInTable(v, newPos, depth + 1) end
            end
        end
        return t
    end

    local unifiedHook = false
    local oldNamecall = nil
    local oldNewIndex = nil
    local metaT = nil

    local function enableUnifiedHook()
        if unifiedHook then return end
        local ok, err = pcall(function()
            metaT = getrawmetatable(game)
            oldNamecall = metaT.__namecall
            oldNewIndex = metaT.__newindex
            setreadonly(metaT, false)

            metaT.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                if method == "FireServer" and self.Name == "update" then
                    if args[1] == "fixmouse" then
                        -- silent aim kunai mark: Head + HeightOffset
                        if silentKunai.Enabled and silentKunai.CachedCFrame then
                            args[2] = silentKunai.CachedCFrame
                        -- обычный silent aim
                        elseif silentAim.Enabled and silentAim.CachedCFrame then
                            args[2] = silentAim.CachedCFrame
                        end
                    end
                end

                return oldNamecall(self, table.unpack(args))
            end)

            metaT.__newindex = newcclosure(function(self, key, value)
                if perf.blockNewEffects and (key == "Enabled" or key == "Brightness" or key == "Range") then
                    local ok2, cls = pcall(function() return self.ClassName end)
                    if ok2 and cls then
                        if cls == "ParticleEmitter" or cls == "Beam" or cls == "Trail"
                           or cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
                            if value == true then return end
                        end
                    end
                end
                return oldNewIndex(self, key, value)
            end)

            setreadonly(metaT, true)
            unifiedHook = true
            print("✅ Unified Hook установлен")
        end)
        if not ok then warn("❌ Unified Hook: " .. tostring(err)) end
    end

    local function disableUnifiedHook()
        if metaT and oldNamecall then
            pcall(function()
                setreadonly(metaT, false)
                metaT.__namecall = oldNamecall
                if oldNewIndex then metaT.__newindex = oldNewIndex end
                setreadonly(metaT, true)
            end)
        end
        unifiedHook = false
    end

    -- ══════════ SILENT AIM + SILENT KUNAI ══════════
    RunService.Heartbeat:Connect(function()
        if silentAim.MasterEnabled and silentAim.Mode == "Hold" then
            silentAim.Enabled = UserInputService:IsKeyDown(silentAim.HoldKey)
        end
        if silentKunai.MasterEnabled and silentKunai.Mode == "Hold" then
            silentKunai.Enabled = UserInputService:IsKeyDown(silentKunai.HoldKey)
        end

        -- SILENT AIM (обычный)
        if silentAim.Enabled then
            local best, bestScore = nil, math.huge
            local cam = Workspace.CurrentCamera
            local MousePos = cam.ViewportSize / 2
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local originPos = myRoot and myRoot.Position or cam.CFrame.Position
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                local char = p.Character
                if not char then continue end
                local part = char:FindFirstChild(silentAim.TargetPart)
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not part or not hum or hum.Health <= 0 then continue end
                local enemyRoot = char:FindFirstChild("HumanoidRootPart")
                if enemyRoot and not checkMaxDistance((enemyRoot.Position - originPos).Magnitude, silentAim.MaxDistance) then continue end
                if silentAim.Mode360 then
                    local worldDist = (part.Position - originPos).Magnitude
                    if worldDist < bestScore then bestScore = worldDist; best = part end
                else
                    local pos, vis = cam:WorldToViewportPoint(part.Position)
                    if not vis then continue end
                    local screenDist = (Vector2.new(pos.X, pos.Y) - MousePos).Magnitude
                    if screenDist > silentAim.FOV then continue end
                    local worldDist = (part.Position - originPos).Magnitude
                    local score = silentAim.PrioritizeClose and worldDist or screenDist
                    if score < bestScore then bestScore = score; best = part end
                end
            end
            silentAim.CachedTarget = best
            if silentAim.CachedTarget and silentAim.CachedTarget.Parent then
                local targetPos = silentAim.CachedTarget.Position + (silentAim.CachedTarget.Velocity * silentAim.Prediction)
                local camPos2 = cam.CFrame.Position
                silentAim.CachedCFrame = CFrame.new(targetPos, targetPos + (targetPos - camPos2).Unit)
            end
        else
            silentAim.CachedTarget = nil; silentAim.CachedCFrame = nil
        end

        -- SILENT AIM KUNAI MARK (Head + HeightOffset)
        if silentKunai.Enabled then
            local best, bestScore = nil, math.huge
            local cam = Workspace.CurrentCamera
            local MousePos = cam.ViewportSize / 2
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local originPos = myRoot and myRoot.Position or cam.CFrame.Position
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                local char = p.Character
                if not char then continue end
                local head = char:FindFirstChild("Head")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not head or not hum or hum.Health <= 0 then continue end
                local aimPos = head.Position + Vector3.new(0, silentKunai.HeightOffset, 0)
                local enemyRoot = char:FindFirstChild("HumanoidRootPart")
                if enemyRoot and not checkMaxDistance((enemyRoot.Position - originPos).Magnitude, silentKunai.MaxDistance) then continue end
                if silentKunai.Mode360 then
                    local worldDist = (aimPos - originPos).Magnitude
                    if worldDist < bestScore then bestScore = worldDist; best = {head = head, pos = aimPos} end
                else
                    local pos, vis = cam:WorldToViewportPoint(aimPos)
                    if not vis then continue end
                    local screenDist = (Vector2.new(pos.X, pos.Y) - MousePos).Magnitude
                    if screenDist > silentKunai.FOV then continue end
                    local worldDist = (aimPos - originPos).Magnitude
                    local score = silentKunai.PrioritizeClose and worldDist or screenDist
                    if score < bestScore then bestScore = score; best = {head = head, pos = aimPos} end
                end
            end
            silentKunai.CachedTarget = best
            if silentKunai.CachedTarget then
                local basePos = silentKunai.CachedTarget.pos
                local targetPos = basePos + (silentKunai.CachedTarget.head.Velocity * silentKunai.Prediction)
                local camPos2 = cam.CFrame.Position
                silentKunai.CachedCFrame = CFrame.new(targetPos, targetPos + (targetPos - camPos2).Unit)
            end
        else
            silentKunai.CachedTarget = nil; silentKunai.CachedCFrame = nil
        end
    end)

    -- ══════════ AIMBOTS ══════════
    local function getBestAimPart(char, customPart)
        if not char then return nil end
        if customPart and customPart ~= "Auto" then
            local p = char:FindFirstChild(customPart)
            if p and p:IsA("BasePart") then return p end
        end
        local priority = {"HumanoidRootPart", "Head", "UpperTorso", "Torso"}
        for _, n in ipairs(priority) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then return p end
        end
        return nil
    end
    local function isSameTeam(p, check)
        if not check then return false end
        if not p.Team or not LocalPlayer.Team then return false end
        return p.Team == LocalPlayer.Team
    end

    local function getTarget()
        local mousePos = UserInputService:GetMouseLocation()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local originPos = myRoot.Position
        local bestT, bestS = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer or isSameTeam(p, settings.teamCheck) then continue end
            local char = p.Character
            if not char then continue end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local tp = getBestAimPart(char, settings.aimPart)
            if not tp then continue end
            local enemyRoot = char:FindFirstChild("HumanoidRootPart")
            if enemyRoot and not checkMaxDistance((enemyRoot.Position - originPos).Magnitude, settings.maxDistance) then continue end
            local worldDist = (tp.Position - originPos).Magnitude
            if settings.mode360 then
                if worldDist < bestS then bestS = worldDist; bestT = p end
            else
                local sp, onScreen = Camera:WorldToViewportPoint(tp.Position)
                if not onScreen then continue end
                local cd = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                if cd > settings.fov then continue end
                local score = settings.prioritizeClose and worldDist or cd
                if score < bestS then bestS = score; bestT = p end
            end
        end
        return bestT
    end

    local function getTarget2()
        local mousePos = UserInputService:GetMouseLocation()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local originPos = myRoot.Position
        local bestT, bestS = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer or isSameTeam(p, settings.aim2TeamCheck) then continue end
            local char = p.Character
            if not char then continue end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local head = char:FindFirstChild("Head")
            if not head then continue end
            local aimPos = head.Position + Vector3.new(0, settings.aim2HeightOffset, 0)
            local enemyRoot = char:FindFirstChild("HumanoidRootPart")
            if enemyRoot and not checkMaxDistance((enemyRoot.Position - originPos).Magnitude, settings.aim2MaxDistance) then continue end
            local worldDist = (aimPos - originPos).Magnitude
            if settings.aim2Mode360 then
                if worldDist < bestS then bestS = worldDist; bestT = p end
            else
                local sp, onScreen = Camera:WorldToViewportPoint(aimPos)
                if not onScreen then continue end
                local cd = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                if cd > settings.aim2Fov then continue end
                local score = settings.aim2PrioritizeClose and worldDist or cd
                if score < bestS then bestS = score; bestT = p end
            end
        end
        return bestT
    end

    local function aimAtTarget(p)
        if not p or not p.Character then return end
        local tp = getBestAimPart(p.Character, settings.aimPart)
        if not tp then return end
        local rp = p.Character:FindFirstChild("HumanoidRootPart")
        local pos = tp.Position + (rp and rp.Velocity * settings.prediction or Vector3.new())
        local cur = Camera.CFrame
        Camera.CFrame = cur:Lerp(CFrame.new(cur.Position, pos), math.clamp(1 - settings.smoothing, 0.05, 1))
    end

    local function aimAtTarget2(p)
        if not p or not p.Character then return end
        local head = p.Character:FindFirstChild("Head")
        if not head then return end
        local rp = p.Character:FindFirstChild("HumanoidRootPart")
        local aimPos = head.Position + Vector3.new(0, settings.aim2HeightOffset, 0)
        local pos = aimPos + (rp and rp.Velocity * settings.aim2Prediction or Vector3.new())
        local cur = Camera.CFrame
        Camera.CFrame = cur:Lerp(CFrame.new(cur.Position, pos), math.clamp(1 - settings.aim2Smoothing, 0.05, 1))
    end

    -- ══════════ SERVER ══════════
    local lastJobHistory = {}
    local historyFile = "FluniumHistory.json"
    local function loadHistory()
        pcall(function()
            if isfile and isfile(historyFile) then
                local data = HttpService:JSONDecode(readfile(historyFile))
                if type(data) == "table" then lastJobHistory = data end
            end
        end)
    end
    local function saveHistory()
        pcall(function()
            if writefile then writefile(historyFile, HttpService:JSONEncode(lastJobHistory)) end
        end)
    end
    loadHistory()

    local function serverHop()
        Fluent:Notify({Title = "🔄 Server Hop", Content = "Поиск...", Duration = 3})
        pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            local servers = HttpService:JSONDecode(game:HttpGet(url))
            local avail = {}
            for _, s in ipairs(servers.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(avail, s.id) end
            end
            if #avail > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, avail[math.random(1, #avail)], LocalPlayer)
            else
                Fluent:Notify({Title = "❌", Content = "Нет других серверов", Duration = 3})
            end
        end)
    end

    local function rejoinServer()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end

    -- ══════════ GUI ══════════
    local Window = Fluent:CreateWindow({
        Title = "Flunium Client v2.0",
        SubTitle = "2 Aimbots • Silent Kunai • ESP • Server • Performance",
        TabWidth = 160,
        Size = UDim2.fromOffset(600, 520),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })

    local Tabs = {
        Aimbot = Window:AddTab({ Title = "Aimbot 🎯", Icon = "crosshair" }),
        Aimbot2 = Window:AddTab({ Title = "Kunai Mark 🎯", Icon = "target" }),
        Silent = Window:AddTab({ Title = "Silent Aim 🎭", Icon = "eye-off" }),
        SilentKunai = Window:AddTab({ Title = "Silent Kunai 🌀", Icon = "zap" }),
        ESP = Window:AddTab({ Title = "ESP 👁️", Icon = "eye" }),
        Performance = Window:AddTab({ Title = "Performance ⚡", Icon = "zap" }),
        Colors = Window:AddTab({ Title = "Colors 🎨", Icon = "palette" }),
        Server = Window:AddTab({ Title = "Server 🌐", Icon = "globe" }),
        UI = Window:AddTab({ Title = "UI Settings", Icon = "settings" })
    }

    local Options = Fluent.Options

    -- ══════════ AIMBOT 1 ══════════
    Tabs.Aimbot:AddToggle("AimOn", {Title = "Enable Aimbot", Default = false}):OnChanged(function(v)
        aimbotEnabled = v
        if fovCircle then fovCircle.Visible = settings.showFovCircle and v and not settings.mode360 end
        if not v then aiming = false; currentTarget = nil end
    end)
    Tabs.Aimbot:AddToggle("ShowFOV", {Title = "Show FOV Circle", Default = true}):OnChanged(function(v)
        settings.showFovCircle = v
        if fovCircle then fovCircle.Visible = v and aimbotEnabled and not settings.mode360 end
    end)
    Tabs.Aimbot:AddColorpicker("FovColor", {Title = "FOV Color", Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(c)
        settings.fovColor = c
        if fovCircle and not settings.rainbowFov then fovCircle.Color = c end
    end)
    Tabs.Aimbot:AddToggle("RainbowFov", {Title = "Rainbow FOV", Default = false}):OnChanged(function(v) settings.rainbowFov = v end)
    Tabs.Aimbot:AddDropdown("AimPart", {Title = "Aim Part",
        Values = {"HumanoidRootPart", "Head", "UpperTorso", "Torso", "Auto"}, Default = 1
    }):OnChanged(function(v) settings.aimPart = v end)
    Tabs.Aimbot:AddDropdown("AimMode", {Title = "Aim Mode",
        Values = {"Hold (зажать)", "Toggle (переключить)"}, Default = 1
    }):OnChanged(function(v) settings.aimMode = (v == "Hold (зажать)") and "Hold" or "Toggle" end)
    local aimBindButton
    aimBindButton = Tabs.Aimbot:AddButton({
        Title = "🎹 BIND: " .. settings.aimKey.Name,
        Callback = function()
            settings.ListeningForAimBind = true
            pcall(function() aimBindButton:SetTitle("🎹 Нажмите клавишу...") end)
        end
    })
    Tabs.Aimbot:AddSlider("FOV", {Title = "FOV Size", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
        settings.fov = v; if fovCircle then fovCircle.Radius = v end
    end)
    Tabs.Aimbot:AddSlider("MaxDist", {Title = "Max Distance (0/5000 = без лимита)", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v)
        settings.maxDistance = v
    end)
    Tabs.Aimbot:AddToggle("PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) settings.prioritizeClose = v end)
    Tabs.Aimbot:AddToggle("Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
        settings.mode360 = v
        if v and fovCircle then fovCircle.Visible = false end
    end)
    Tabs.Aimbot:AddSlider("Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) settings.smoothing = v / 100 end)
    Tabs.Aimbot:AddSlider("Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v) settings.prediction = v / 100 end)
    Tabs.Aimbot:AddToggle("WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.wallCheck = v end)
    Tabs.Aimbot:AddToggle("TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.teamCheck = v end)

    -- ══════════ KUNAI MARK AIMBOT (бывш. Aimbot 2) ══════════
    Tabs.Aimbot2:AddParagraph({Title = "🎯 Kunai Mark Aimbot", Content = "Целится ВЫШЕ головы (Height Offset). Клавиша по умолчанию [1]."})
    Tabs.Aimbot2:AddToggle("Aim2On", {Title = "Enable Kunai Mark Aimbot", Default = false}):OnChanged(function(v)
        aim2Enabled = v
        if fovCircle2 then fovCircle2.Visible = settings.aim2ShowFovCircle and v and not settings.aim2Mode360 end
        if not v then aim2ing = false; aim2Target = nil end
    end)
    Tabs.Aimbot2:AddToggle("Aim2ShowFOV", {Title = "Show FOV Circle", Default = true}):OnChanged(function(v)
        settings.aim2ShowFovCircle = v
        if fovCircle2 then fovCircle2.Visible = v and aim2Enabled and not settings.aim2Mode360 end
    end)
    Tabs.Aimbot2:AddColorpicker("Aim2FovColor", {Title = "FOV Color", Default = Color3.fromRGB(255, 165, 0)}):OnChanged(function(c)
        settings.aim2FovColor = c
        if fovCircle2 and not settings.aim2RainbowFov then fovCircle2.Color = c end
    end)
    Tabs.Aimbot2:AddToggle("Aim2RainbowFov", {Title = "Rainbow FOV", Default = false}):OnChanged(function(v) settings.aim2RainbowFov = v end)
    Tabs.Aimbot2:AddDropdown("Aim2Mode", {Title = "Aim Mode",
        Values = {"Hold (зажать)", "Toggle (переключить)"}, Default = 1
    }):OnChanged(function(v) settings.aim2Mode = (v == "Hold (зажать)") and "Hold" or "Toggle" end)
    local aim2BindButton
    aim2BindButton = Tabs.Aimbot2:AddButton({
        Title = "🎹 BIND: " .. settings.aim2Key.Name,
        Description = "Клавиша аимбота (по умолчанию 1)",
        Callback = function()
            settings.aim2ListeningForBind = true
            pcall(function() aim2BindButton:SetTitle("🎹 Нажмите клавишу...") end)
        end
    })
    Tabs.Aimbot2:AddSlider("Aim2Height", {Title = "📏 Height Above Head (studs)",
        Description = "На сколько studs выше головы целиться",
        Default = 16, Min = 0, Max = 50, Rounding = 0
    }):OnChanged(function(v) settings.aim2HeightOffset = v end)
    Tabs.Aimbot2:AddSlider("Aim2FOV", {Title = "FOV Size", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
        settings.aim2Fov = v; if fovCircle2 then fovCircle2.Radius = v end
    end)
    Tabs.Aimbot2:AddSlider("Aim2MaxDist", {Title = "Max Distance (0/5000 = без лимита)", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v)
        settings.aim2MaxDistance = v
    end)
    Tabs.Aimbot2:AddToggle("Aim2PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) settings.aim2PrioritizeClose = v end)
    Tabs.Aimbot2:AddToggle("Aim2Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
        settings.aim2Mode360 = v
        if v and fovCircle2 then fovCircle2.Visible = false end
    end)
    Tabs.Aimbot2:AddSlider("Aim2Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) settings.aim2Smoothing = v / 100 end)
    Tabs.Aimbot2:AddSlider("Aim2Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v) settings.aim2Prediction = v / 100 end)
    Tabs.Aimbot2:AddToggle("Aim2WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.aim2WallCheck = v end)
    Tabs.Aimbot2:AddToggle("Aim2TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.aim2TeamCheck = v end)

    -- ══════════ SILENT AIM ══════════
    Tabs.Silent:AddToggle("SilentMaster", {Title = "Enable Silent Aim", Default = false}):OnChanged(function(v)
        silentAim.MasterEnabled = v
        if v then enableUnifiedHook() else
            if not (silentKunai.MasterEnabled or perf.blockNewEffects) then disableUnifiedHook() end
        end
    end)
    Tabs.Silent:AddToggle("SilentShowFOV", {Title = "Show FOV Circle", Default = true}):OnChanged(function(v)
        silentAim.ShowFovCircle = v
    end)
    Tabs.Silent:AddDropdown("SilentMode", {Title = "Режим", Values = {"Hold", "Toggle"}, Default = 1}):OnChanged(function(v)
        silentAim.Mode = v
    end)
    local silentBindButton
    silentBindButton = Tabs.Silent:AddButton({
        Title = "🎹 BIND: " .. silentAim.HoldKey.Name,
        Callback = function()
            silentAim.ListeningForBind = true
            pcall(function() silentBindButton:SetTitle("🎹 Нажмите...") end)
        end
    })
    Tabs.Silent:AddSlider("SilentFOV", {Title = "FOV Radius", Default = 500, Min = 50, Max = 2000, Rounding = 0}):OnChanged(function(v)
        silentAim.FOV = v; if silentFovCircle then silentFovCircle.Radius = v end
    end)
    Tabs.Silent:AddSlider("SilentPred", {Title = "Prediction", Default = 19, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v) silentAim.Prediction = v / 100 end)
    Tabs.Silent:AddSlider("SilentMaxDist", {Title = "Max Distance (0/5000 = без лимита)", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v) silentAim.MaxDistance = v end)
    Tabs.Silent:AddToggle("SilentPriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) silentAim.PrioritizeClose = v end)
    Tabs.Silent:AddToggle("SilentMode360", {Title = "360° Mode", Default = false}):OnChanged(function(v) silentAim.Mode360 = v end)
    Tabs.Silent:AddButton({
        Title = "🔄 Переустановить хук",
        Callback = function()
            disableUnifiedHook(); task.wait(0.3)
            if silentAim.MasterEnabled or silentKunai.MasterEnabled or perf.blockNewEffects then enableUnifiedHook() end
        end
    })

    -- ══════════ SILENT AIM KUNAI MARK ══════════
    Tabs.SilentKunai:AddParagraph({Title = "🌀 Silent Aim Kunai Mark", Content = "Подменяет fixmouse на Head + Height Offset. Клавиша по умолчанию [2]."})
    Tabs.SilentKunai:AddToggle("SilentKunaiMaster", {Title = "Enable Silent Aim Kunai Mark", Default = false}):OnChanged(function(v)
        silentKunai.MasterEnabled = v
        if v then enableUnifiedHook() else
            if not (silentAim.MasterEnabled or perf.blockNewEffects) then disableUnifiedHook() end
        end
    end)
    Tabs.SilentKunai:AddToggle("SilentKunaiShowFOV", {Title = "Show FOV Circle", Default = true}):OnChanged(function(v) silentKunai.ShowFovCircle = v end)
    Tabs.SilentKunai:AddDropdown("SilentKunaiMode", {Title = "Режим", Values = {"Hold", "Toggle"}, Default = 1}):OnChanged(function(v) silentKunai.Mode = v end)
    local silentKunaiBindButton
    silentKunaiBindButton = Tabs.SilentKunai:AddButton({
        Title = "🎹 BIND: " .. silentKunai.HoldKey.Name,
        Callback = function()
            silentKunai.ListeningForBind = true
            pcall(function() silentKunaiBindButton:SetTitle("🎹 Нажмите...") end)
        end
    })
    Tabs.SilentKunai:AddSlider("SilentKunaiHeight", {Title = "📏 Height Offset (studs)", Default = 16, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v) silentKunai.HeightOffset = v end)
    Tabs.SilentKunai:AddSlider("SilentKunaiFOV", {Title = "FOV Radius", Default = 500, Min = 50, Max = 2000, Rounding = 0}):OnChanged(function(v)
        silentKunai.FOV = v; if silentKunaiFovCircle then silentKunaiFovCircle.Radius = v end
    end)
    Tabs.SilentKunai:AddSlider("SilentKunaiPred", {Title = "Prediction", Default = 19, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v) silentKunai.Prediction = v / 100 end)
    Tabs.SilentKunai:AddSlider("SilentKunaiMaxDist", {Title = "Max Distance (0/5000 = без лимита)", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v) silentKunai.MaxDistance = v end)
    Tabs.SilentKunai:AddToggle("SilentKunaiPriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) silentKunai.PrioritizeClose = v end)
    Tabs.SilentKunai:AddToggle("SilentKunaiMode360", {Title = "360° Mode", Default = false}):OnChanged(function(v) silentKunai.Mode360 = v end)

    -- ══════════ ESP ══════════
    Tabs.ESP:AddToggle("ESPOn", {Title = "Enable ESP", Default = false}):OnChanged(function(v)
        ESP.Enabled = v; ESP.Visible = v
        if v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then espWatch(p) end
            end
            rebuildESP()
        else
            for p in pairs(espData) do clearPlayer(p) end
        end
    end)
    Tabs.ESP:AddToggle("EspName", {Title = "Show Name", Default = true}):OnChanged(function(v) ESP.ShowName = v; rebuildESP() end)
    Tabs.ESP:AddToggle("EspHP", {Title = "Show HP", Default = true}):OnChanged(function(v) ESP.ShowHP = v; rebuildESP() end)
    Tabs.ESP:AddToggle("EspMD", {Title = "Show MD", Default = true}):OnChanged(function(v) ESP.ShowMD = v; rebuildESP() end)
    Tabs.ESP:AddToggle("EspDodge", {Title = "Show Body Dodge", Default = true}):OnChanged(function(v) ESP.ShowDodge = v; rebuildESP() end)
    Tabs.ESP:AddSlider("EspSize", {Title = "ESP Size", Default = 100, Min = 30, Max = 300, Rounding = 0}):OnChanged(function(v)
        ESP.Size = v / 100
        for _, d in pairs(espData) do
            if d.gui then
                local s = d.gui:FindFirstChild("Frame") and d.gui.Frame:FindFirstChildOfClass("UIScale")
                if s then s.Scale = ESP.Size end
            end
        end
    end)
    Tabs.ESP:AddColorpicker("EspNameC", {Title = "Name Color", Default = Color3.fromRGB(255, 255, 255)}):OnChanged(function(c) ESP.NameColor = c end)
    Tabs.ESP:AddColorpicker("EspHPC", {Title = "HP Color", Default = Color3.fromRGB(0, 255, 0)}):OnChanged(function(c) ESP.HPColor = c end)
    Tabs.ESP:AddColorpicker("EspMDC", {Title = "MD Color", Default = Color3.fromRGB(200, 100, 255)}):OnChanged(function(c) ESP.MDColor = c end)

    -- ══════════ PERFORMANCE (включая бывшие Visual) ══════════
    Tabs.Performance:AddSection("Performance Tools")
    Tabs.Performance:AddToggle("LowDetail", {Title = "Low Detail Mode", Default = false}):OnChanged(applyLowDetail)
    Tabs.Performance:AddToggle("RemoveTextures", {Title = "Remove Textures", Default = false}):OnChanged(applyRemoveTextures)
    Tabs.Performance:AddToggle("RemoveDecals", {Title = "Remove Decals", Default = false}):OnChanged(applyRemoveDecals)
    Tabs.Performance:AddToggle("RemoveParticles", {Title = "Remove Particles", Default = false}):OnChanged(applyRemoveParticles)
    Tabs.Performance:AddToggle("RemoveShadows", {Title = "Remove Shadows", Default = false}):OnChanged(applyRemoveShadows)
    Tabs.Performance:AddToggle("ForcePlastic", {Title = "Force Plastic Material", Default = false}):OnChanged(applyForcePlastic)
    Tabs.Performance:AddToggle("DisablePost", {Title = "Disable Post-Processing", Default = false}):OnChanged(applyDisablePostFx)
    Tabs.Performance:AddToggle("ExtendFog", {Title = "Extend Fog Distance", Default = false}):OnChanged(applyExtendFog)
    Tabs.Performance:AddToggle("OptimizeWater", {Title = "Optimize Water", Default = false}):OnChanged(applyOptimizeWater)
    Tabs.Performance:AddToggle("RemoveLights", {Title = "Remove Lights", Default = false}):OnChanged(applyRemoveLights)
    Tabs.Performance:AddToggle("RemoveBeams", {Title = "Remove Beams & Trails", Default = false}):OnChanged(applyRemoveBeams)
    Tabs.Performance:AddToggle("RemoveHighlights", {Title = "Remove Highlights", Default = false}):OnChanged(applyRemoveHighlights)
    Tabs.Performance:AddToggle("HideAccessories", {Title = "Hide Accessories", Default = false}):OnChanged(applyHideAccessories)
    Tabs.Performance:AddToggle("RemoveCharFx", {Title = "Remove Character Effects", Default = false}):OnChanged(applyRemoveCharFx)

    Tabs.Performance:AddSection("Visual (перенесено)")
    Tabs.Performance:AddToggle("XRay", {Title = "X-Ray", Default = false}):OnChanged(applyXRay)
    Tabs.Performance:AddToggle("FB", {Title = "Full Bright", Default = false}):OnChanged(applyFullBright)
    Tabs.Performance:AddToggle("NV", {Title = "Night Vision", Default = false}):OnChanged(applyNightVision)
    Tabs.Performance:AddToggle("NoSh", {Title = "No Shadows", Default = false}):OnChanged(applyNoShadows)
    Tabs.Performance:AddToggle("NoBl", {Title = "No Bloom", Default = false}):OnChanged(applyNoBloom)
    Tabs.Performance:AddToggle("NoSR", {Title = "No Sun Rays", Default = false}):OnChanged(applyNoSunRays)
    Tabs.Performance:AddToggle("NoFog", {Title = "No Fog", Default = false}):OnChanged(applyNoFog)

    Tabs.Performance:AddSection("FPS Unlocker")
    Tabs.Performance:AddToggle("FpsUnlock", {Title = "🔓 Unlock FPS Cap", Default = false}):OnChanged(applyFpsUnlock)
    Tabs.Performance:AddSlider("FpsCap", {Title = "FPS Cap", Default = 999, Min = 30, Max = 999, Rounding = 0}):OnChanged(function(v)
        perf.fpsCap = v
        if perf.fpsUnlock then pcall(function() setfpscap(v) end) end
    end)

    -- ══════════ COLORS ══════════
    Tabs.Colors:AddToggle("RainbowSkin", {Title = "Rainbow Skin", Default = false}):OnChanged(function(v) colors.RainbowSkin = v end)
    Tabs.Colors:AddToggle("RainbowHair", {Title = "Rainbow Hair", Default = false}):OnChanged(function(v) colors.RainbowHair = v end)
    Tabs.Colors:AddSlider("SkinSpd", {Title = "Skin Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v) colors.SkinSpeed = v / 10 end)
    Tabs.Colors:AddSlider("HairSpd", {Title = "Hair Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v) colors.HairSpeed = v / 10 end)

    local colorPresets = {
        {name = "🔴 Красный", r = 255, g = 0, b = 0},
        {name = "🟢 Зелёный", r = 0, g = 255, b = 0},
        {name = "🔵 Синий", r = 0, g = 0, b = 255},
        {name = "🟣 Фиолетовый", r = 128, g = 0, b = 255},
        {name = "🟡 Жёлтый", r = 255, g = 255, b = 0},
        {name = "⚫ Чёрный", r = 1, g = 1, b = 1},
        {name = "⚪ Белый", r = 254, g = 254, b = 254},
        {name = "🟠 Оранжевый", r = 255, g = 128, b = 0},
        {name = "💗 Розовый", r = 255, g = 105, b = 180},
        {name = "🩵 Cyan", r = 0, g = 255, b = 255}
    }
    for _, preset in ipairs(colorPresets) do
        Tabs.Colors:AddButton({
            Title = preset.name .. " ВОЛОСЫ",
            Callback = function()
                if shindoEvent then
                    local str = string.format("%d,%d,%d", preset.r, preset.g, preset.b)
                    pcall(function() shindoEvent:FireServer("haircolor", str) end)
                end
            end
        })
    end
    for _, preset in ipairs(colorPresets) do
        Tabs.Colors:AddButton({
            Title = preset.name .. " СКИН",
            Callback = function()
                if shindoEvent then
                    local str = string.format("%d,%d,%d", preset.r, preset.g, preset.b)
                    pcall(function() shindoEvent:FireServer("skin", str) end)
                end
            end
        })
    end

    -- ══════════ SERVER ══════════
    Tabs.Server:AddButton({Title = "🔄 Server Hop", Callback = serverHop})
    Tabs.Server:AddButton({Title = "🔁 ReJoin Server", Callback = rejoinServer})

    -- ══════════ INPUT ══════════
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if silentKunai.ListeningForBind and input.UserInputType == Enum.UserInputType.Keyboard then
            silentKunai.HoldKey = input.KeyCode
            silentKunai.ListeningForBind = false
            pcall(function() silentKunaiBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
            return
        end
        if silentAim.ListeningForBind and input.UserInputType == Enum.UserInputType.Keyboard then
            silentAim.HoldKey = input.KeyCode
            silentAim.ListeningForBind = false
            pcall(function() silentBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
            return
        end
        if settings.ListeningForAimBind and input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aimKey = input.KeyCode
            settings.ListeningForAimBind = false
            pcall(function() aimBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
            return
        end
        if settings.aim2ListeningForBind and input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aim2Key = input.KeyCode
            settings.aim2ListeningForBind = false
            pcall(function() aim2BindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
            return
        end
        if silentAim.MasterEnabled and silentAim.Mode == "Toggle" and input.KeyCode == silentAim.HoldKey then
            silentAim.Enabled = not silentAim.Enabled
        end
        if silentKunai.MasterEnabled and silentKunai.Mode == "Toggle" and input.KeyCode == silentKunai.HoldKey then
            silentKunai.Enabled = not silentKunai.Enabled
        end
        if aimbotEnabled and input.KeyCode == settings.aimKey then
            if settings.aimMode == "Hold" then aiming = true
            else aiming = not aiming; if not aiming then currentTarget = nil end end
        end
        if aim2Enabled and input.KeyCode == settings.aim2Key then
            if settings.aim2Mode == "Hold" then aim2ing = true
            else aim2ing = not aim2ing; if not aim2ing then aim2Target = nil end end
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gp)
        if gp then return end
        if aimbotEnabled and settings.aimMode == "Hold" and input.KeyCode == settings.aimKey then
            aiming = false; currentTarget = nil
        end
        if aim2Enabled and settings.aim2Mode == "Hold" and input.KeyCode == settings.aim2Key then
            aim2ing = false; aim2Target = nil
        end
    end)

    -- ══════════ RENDER ══════════
    RunService.RenderStepped:Connect(function()
        if aimbotEnabled and settings.aimMode == "Hold" then
            aiming = UserInputService:IsKeyDown(settings.aimKey)
        end
        if aim2Enabled and settings.aim2Mode == "Hold" then
            aim2ing = UserInputService:IsKeyDown(settings.aim2Key)
        end
        local mpos = UserInputService:GetMouseLocation()
        if aimbotEnabled and fovCircle and settings.showFovCircle and not settings.mode360 then
            fovCircle.Position = Vector2.new(mpos.X, mpos.Y + 50)
            fovCircle.Visible = true
            if settings.rainbowFov then
                hue = (hue + rainbowSpeed) % 1
                fovCircle.Color = Color3.fromHSV(hue, 1, 1)
            elseif aiming and currentTarget then
                fovCircle.Color = settings.targetedColor
            else
                fovCircle.Color = settings.fovColor
            end
        elseif fovCircle then fovCircle.Visible = false end

        if aim2Enabled and fovCircle2 and settings.aim2ShowFovCircle and not settings.aim2Mode360 then
            fovCircle2.Position = Vector2.new(mpos.X, mpos.Y + 50)
            fovCircle2.Visible = true
            if settings.aim2RainbowFov then
                hue = (hue + rainbowSpeed) % 1
                fovCircle2.Color = Color3.fromHSV(hue, 1, 1)
            elseif aim2ing and aim2Target then
                fovCircle2.Color = settings.aim2TargetedColor
            else
                fovCircle2.Color = settings.aim2FovColor
            end
        elseif fovCircle2 then fovCircle2.Visible = false end

        if silentAim.MasterEnabled and silentFovCircle and silentAim.ShowFovCircle and not silentAim.Mode360 then
            silentFovCircle.Position = Vector2.new(mpos.X, mpos.Y + 50)
            silentFovCircle.Radius = silentAim.FOV
            silentFovCircle.Color = silentAim.FovColor
            silentFovCircle.Visible = silentAim.Enabled
        elseif silentFovCircle then silentFovCircle.Visible = false end

        if silentKunai.MasterEnabled and silentKunaiFovCircle and silentKunai.ShowFovCircle and not silentKunai.Mode360 then
            silentKunaiFovCircle.Position = Vector2.new(mpos.X, mpos.Y + 50)
            silentKunaiFovCircle.Radius = silentKunai.FOV
            silentKunaiFovCircle.Color = silentKunai.FovColor
            silentKunaiFovCircle.Visible = silentKunai.Enabled
        elseif silentKunaiFovCircle then silentKunaiFovCircle.Visible = false end

        if aiming then
            local t = tick()
            if t - lastTargetUpdate > 0.01 then
                lastTargetUpdate = t
                currentTarget = getTarget()
            end
            if currentTarget then aimAtTarget(currentTarget) end
        else currentTarget = nil end

        if aim2ing then
            local t = tick()
            if t - lastTarget2Update > 0.01 then
                lastTarget2Update = t
                aim2Target = getTarget2()
            end
            if aim2Target then aimAtTarget2(aim2Target) end
        else aim2Target = nil end
    end)

    RunService.Heartbeat:Connect(function(dt)
        if colors.RainbowSkin and shindoEvent then
            skinTimer = skinTimer + dt
            if skinTimer >= 0.1 then
                skinTimer = 0
                local h = (tick() * colors.SkinSpeed) % 1
                local c = Color3.fromHSV(h, 1, 1)
                local str = string.format("%d,%d,%d", c.R*255, c.G*255, c.B*255)
                pcall(function() shindoEvent:FireServer("skin", str) end)
            end
        end
        if colors.RainbowHair and shindoEvent then
            hairTimer = hairTimer + dt
            if hairTimer >= 0.1 then
                hairTimer = 0
                local h = (tick() * colors.HairSpeed) % 1
                local c = Color3.fromHSV(h, 1, 1)
                local str = string.format("%d,%d,%d", c.R*255, c.G*255, c.B*255)
                pcall(function() shindoEvent:FireServer("haircolor", str) end)
            end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if ESP.Enabled then rebuildESP() end
    end)

    pcall(function()
        SaveManager:SetLibrary(Fluent)
        InterfaceManager:SetLibrary(Fluent)
        SaveManager:IgnoreThemeSettings()
        InterfaceManager:SetFolder("FluniumClient")
        SaveManager:SetFolder("FluniumClient/Configs")
        InterfaceManager:BuildInterfaceSection(Tabs.UI)
        SaveManager:BuildConfigSection(Tabs.UI)
        SaveManager:LoadAutoloadConfig()
    end)

    print("====================================")
    print("✅ Flunium Client v2.0 загружен!")
    print("🎯 Aimbot + Kunai Mark Aimbot")
    print("🎭 Silent Aim + Silent Aim Kunai Mark")
    print("⚡ Performance оптимизирован")
    print("📌 RightControl — скрыть меню")
    print("====================================")

    getgenv().FluniumLoaded = true
end

Flunium_Boot()
