--[[
    Flunium Client v2.7
    ✅ Marker Tracker: целится в MAIN (точная точка маркера)
    ✅ Kunai Snap: Head+Offset / Marker (точный) / Marker Projectile
    ✅ NPC фильтр: Aim at NPCs
    ✅ ESP / Overlay / Colors / Performance
]]

local function Flunium_Boot()

    if getgenv().FluniumLoaded and getgenv().FluniumFluent then
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        local alive = false
        if pg then
            for _, c in ipairs(pg:GetChildren()) do
                if c.Name:find("Fluent") then alive = true; break end
            end
        end
        if alive then
            pcall(function()
                getgenv().FluniumFluent:Notify({Title = "⚠️ Уже загружено", Content = "Flunium v2.7 уже работает", Duration = 3})
            end)
            return
        end
    end
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, c in ipairs(pg:GetChildren()) do
                if c.Name:find("Fluent") then c:Destroy() end
            end
        end
    end)

    local Fluent
    local ok, err = pcall(function()
        local cache = "FluniumFluent.lua"
        if isfile and isfile(cache) then
            local c = readfile(cache)
            if c and #c > 1000 then Fluent = loadstring(c)(); return end
        end
        local src = game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
        if writefile then pcall(function() writefile(cache, src) end) end
        Fluent = loadstring(src)()
    end)
    if not ok or not Fluent then warn("❌ Fluent: " .. tostring(err)); return end
    getgenv().FluniumFluent = Fluent

    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera

    local shindoEvent
    pcall(function() shindoEvent = LocalPlayer:WaitForChild("startevent", 8) end)
    local fireRemote
    pcall(function() fireRemote = ReplicatedStorage:WaitForChild("fire", 8) end)

    local settings = {
        fov = 300, smoothing = 0.15, prediction = 0.065,
        teamCheck = false, aimAtNPCs = false,
        aimPart = "HumanoidRootPart", aimMode = "Hold",
        aimKey = Enum.KeyCode.BackSlash, listeningAimBind = false,
        showFovCircle = true, maxDistance = 0, prioritizeClose = true,
        mode360 = false,
        fovColor = Color3.fromRGB(255, 0, 0),
        targetedColor = Color3.fromRGB(0, 255, 0),
        aim2Fov = 300, aim2Smoothing = 0.15, aim2Prediction = 0.065,
        aim2TeamCheck = false, aim2AimAtNPCs = false,
        aim2Mode = "Hold", aim2Key = Enum.KeyCode.One,
        aim2ListeningForBind = false, aim2ShowFovCircle = true,
        aim2MaxDistance = 0, aim2PrioritizeClose = true, aim2Mode360 = false,
        aim2HeightOffset = 16,
        aim2FovColor = Color3.fromRGB(255, 165, 0),
        aim2TargetedColor = Color3.fromRGB(255, 255, 0),
        kunaiSnap = false,
        kunaiSnapKey = Enum.KeyCode.Two,
        kunaiSnapHeight = 17,
        kunaiSnapMaxDist = 0,
        kunaiSnapListening = false,
        kunaiSnapDelayMs = 50,
        kunaiSnapClickHoldMs = 60,
        kunaiSnapPostWaitMs = 30,
        kunaiSnapAimMode = "Marker",  -- Head+Offset | Marker | Marker Projectile
        xray = false, fullBright = false, nightVision = false,
        noShadows = false, noBloom = false, noSunRays = false, noFog = false
    }

    local silentAim = {
        Enabled = false, MasterEnabled = false, Mode = "Hold",
        HoldKey = Enum.KeyCode.BackSlash, ListeningForBind = false,
        Prediction = 0.187, FOV = 500, TargetPart = "HumanoidRootPart",
        ShowFovCircle = true, MaxDistance = 0, PrioritizeClose = true,
        Mode360 = false, FovColor = Color3.fromRGB(100, 200, 255),
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
        blockNewEffects = false, fpsUnlock = false, fpsCap = 999,
        cachedProps = {}, cachedLight = {},
        cachedFog = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart},
    }

    local colors = {RainbowSkin = false, RainbowHair = false, SkinSpeed = 0.5, HairSpeed = 0.5}
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

    local kunaiSnapBusy = false

    -- ========== MARKER TRACKER ==========
    -- Храним: targetRoot (HRP) → {projectile = weewoo, main = MAIN Part, time}
    local activeMarkers = {}

    local function extractMarkerData(projectile, targetRoot)
        if not projectile or not targetRoot then return nil end
        -- MAIN — это точка маркера, приваренная к HRP с C0=(0,17,0)
        local main = nil
        local clickpart = projectile:FindFirstChild("clickpart")
        if clickpart then
            main = clickpart:FindFirstChild("MAIN")
        end
        if not main then
            -- fallback: ищем MAIN по всем потомкам
            for _, obj in ipairs(projectile:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "MAIN" then
                    main = obj
                    break
                end
            end
        end
        return {
            projectile = projectile,
            main = main,
            time = tick()
        }
    end

    local function registerMarker(projectile, targetRoot)
        if not targetRoot or not targetRoot.Parent then return end
        local data = extractMarkerData(projectile, targetRoot)
        if data then
            activeMarkers[targetRoot] = data
        end
    end

    local function cleanupMarkers()
        for target, data in pairs(activeMarkers) do
            local alive = target.Parent
                and target.Parent:FindFirstChildOfClass("Humanoid")
                and target.Parent:FindFirstChildOfClass("Humanoid").Health > 0
                and data.projectile
                and data.projectile.Parent
            if not alive then
                activeMarkers[target] = nil
            end
        end
    end

    local function getClosestMarkedTarget()
        cleanupMarkers()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local closest, closestDist = nil, math.huge
        for target, data in pairs(activeMarkers) do
            if target.Parent then
                local dist = (target.Position - myRoot.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = target
                end
            end
        end
        return closest
    end

    local function getMarkerAimPosition(targetRoot)
        local data = activeMarkers[targetRoot]
        if not data then return nil end
        -- MAIN — приоритет
        if data.main and data.main.Parent then
            return data.main.Position
        end
        -- fallback: HRP + (0, 17, 0) (C0 weld'а)
        if targetRoot.Parent then
            return targetRoot.Position + Vector3.new(0, 17, 0)
        end
        return nil
    end

    local function getMarkerProjectilePosition(targetRoot)
        local data = activeMarkers[targetRoot]
        if not data then return nil end
        if data.projectile and data.projectile.Parent then
            return data.projectile.Position
        end
        return nil
    end

    if fireRemote then
        fireRemote.OnClientEvent:Connect(function(...)
            local args = {...}
            if args[3] == "setmarkerftg2" and type(args[2]) == "table" then
                local projectile = args[2][1]
                local targetRoot = args[2][2]
                if typeof(targetRoot) == "Instance" and targetRoot:IsA("BasePart") then
                    local parent = targetRoot.Parent
                    local plr = Players:GetPlayerFromCharacter(parent)
                    local isNpc = (plr == nil) and parent:FindFirstChildOfClass("Humanoid") ~= nil
                    if plr or (isNpc and settings.aimAtNPCs) then
                        registerMarker(projectile, targetRoot)
                    end
                end
            end
        end)
    end

    -- ========== FOV ==========
    local fovCircle, fovCircle2, silentFovCircle
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

    local function isMaxDistOk(dist, maxDist)
        if not maxDist or maxDist <= 0 or maxDist >= 5000 then return true end
        return dist <= maxDist
    end

    local function makeColorString(r, g, b)
        r = math.clamp(tonumber(r) or 0, 0, 255)
        g = math.clamp(tonumber(g) or 0, 0, 255)
        b = math.clamp(tonumber(b) or 0, 0, 255)
        return string.format("%d,%d,%d", 255-r, 255-g, 255-b)
    end
    local function sendSkin(r, g, b)
        if shindoEvent then pcall(function() shindoEvent:FireServer("skin", makeColorString(r, g, b)) end) end
    end
    local function sendHair(r, g, b)
        if shindoEvent then pcall(function() shindoEvent:FireServer("haircolor", makeColorString(r, g, b)) end) end
    end
    local function sendSkinColor(c) sendSkin(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)) end
    local function sendHairColor(c) sendHair(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)) end

    -- ========== PERFORMANCE (сжато) ==========
    local perfConnections = {}
    local function disconnectPerfConns()
        for _, c in ipairs(perfConnections) do pcall(function() c:Disconnect() end) end
        perfConnections = {}
    end

    local function applyRemoveParticles(v)
        perf.removeParticles = v
        if v then
            local function handle(obj)
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    if not obj:GetAttribute("FluniumTS") then obj:SetAttribute("FluniumTS", obj.TimeScale) end
                    obj.TimeScale = 0
                    pcall(function() obj:Clear() end)
                end
            end
            for _, obj in ipairs(Workspace:GetDescendants()) do handle(obj) end
            table.insert(perfConnections, Workspace.DescendantAdded:Connect(handle))
        else
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    local ts = obj:GetAttribute("FluniumTS")
                    if ts ~= nil then obj.TimeScale = ts; obj:SetAttribute("FluniumTS", nil) end
                end
            end
            disconnectPerfConns()
        end
    end

    local function applyRemoveCharFx(v)
        perf.removeCharFx = v
        if v then
            for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char then
                    pcall(function()
                        for _, obj in ipairs(char:GetDescendants()) do
                            if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                                pcall(function() obj:Clear() end); pcall(function() obj.Enabled = false end)
                            elseif obj:IsA("Beam") or obj:IsA("Trail") then
                                pcall(function() obj.Enabled = false end)
                            end
                        end
                    end)
                end
            end
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
    local function applyRemoveShadows(v) perf.removeShadows = v; Lighting.GlobalShadows = not v end
    local function applyDisablePostFx(v)
        perf.disablePostFx = v
        pcall(function()
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = not v end
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
                        perf.cachedLight[obj] = {Enabled = obj.Enabled, Range = obj.Range}
                    end
                    obj.Enabled = not v
                    if v then obj.Range = 0 else
                        local c = perf.cachedLight[obj]
                        if c then obj.Range = c.Range end
                    end
                end
            end
        end)
    end
    local function applyRemoveBeams(v)
        perf.removeBeams = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Beam") or obj:IsA("Trail") then obj.Enabled = not v end
            end
        end)
    end
    local function applyRemoveHighlights(v)
        perf.removeHighlights = v
        pcall(function()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Highlight") or obj:IsA("SelectionBox") then obj.Enabled = not v end
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
        if v then pcall(function() setfpscap(perf.fpsCap) end)
        else pcall(function() setfpscap(60) end) end
    end

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
            Lighting.Ambient = Color3.fromRGB(255,255,255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
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
        if v then Lighting.FogEnd = 100000; Lighting.FogStart = 100000
        else Lighting.FogEnd = originalLighting.FogEnd; Lighting.FogStart = originalLighting.FogStart end
    end

    -- ========== ESP ==========
    local espData, espConns, espAcc = {}, {}, 0
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
                if mode then return tonumber(mode.Value) or 0 end
            end
        end
        return 0
    end
    local function getDodgeInfo(p)
        local keys = p:FindFirstChild("statz") and p.statz:FindFirstChild("keys")
        if not keys then return nil end
        for _, slot in ipairs(keys:GetChildren()) do
            if slot:IsA("ValueBase") then
                local nm = string.lower(tostring(slot.Value))
                if nm == "taijutsudodge" then
                    local cdObj = slot:FindFirstChild("cooldown")
                    if cdObj then
                        local cd = tonumber(cdObj.Value) or 0
                        if cd > 0 then return {ready = false, cd = math.floor(cd)} end
                        return {ready = true, cd = 0}
                    end
                    return {ready = true, cd = 0}
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
        t.Text = ""
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
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        local hum = getHumanoid(char)
        if not root or not hum then return end
        local gui = Instance.new("BillboardGui")
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
        local nameLabel = makeLabel(holder, UDim2.new(1,0,0,20), UDim2.new(0,0,0,0), ESP.NameColor, 16)
        nameLabel.Text = p.Name
        local hpLabel = makeLabel(holder, UDim2.new(1,0,0,18), UDim2.new(0,0,0,22), ESP.HPColor, 16)
        local mdLabel = makeLabel(holder, UDim2.new(1,0,0,18), UDim2.new(0,0,0,42), ESP.MDColor, 16)
        local dodgeLabel = makeLabel(holder, UDim2.new(1,0,0,18), UDim2.new(0,0,0,62), ESP.DodgeOnColor, 16)
        espData[p] = {gui=gui, char=char, root=root, hum=hum, nameLabel=nameLabel,
            hpLabel=hpLabel, mdLabel=mdLabel, dodgeLabel=dodgeLabel, hp=-1, md=-1, dodgeState=-1}
    end
    local function updateESP()
        if not ESP.Enabled or not ESP.Visible then return end
        for p, d in pairs(espData) do
            pcall(function()
                if not p.Parent or not d.char or not d.char.Parent then clearPlayer(p); return end
                if not isWhitelisted(p) then if d.gui then d.gui.Enabled = false end; return end
                if not d.hum or not d.hum.Parent then d.hum = getHumanoid(d.char) end
                if not d.gui or not d.hum or d.hum.Health <= 0 then
                    if d.gui then d.gui.Enabled = false end; return
                end
                d.gui.Enabled = true
                if ESP.ShowName then d.nameLabel.Visible = true; d.nameLabel.Text = p.Name else d.nameLabel.Visible = false end
                local hp = math.floor(d.hum.Health)
                if d.hp ~= hp then d.hp = hp; d.hpLabel.Text = "HP: " .. short(hp) end
                d.hpLabel.Visible = ESP.ShowHP; d.hpLabel.TextColor3 = ESP.HPColor
                local md = math.floor(getModeValue(p))
                if d.md ~= md then d.md = md; d.mdLabel.Text = "MD: " .. md end
                d.mdLabel.Visible = ESP.ShowMD; d.mdLabel.TextColor3 = ESP.MDColor
                if ESP.ShowDodge then
                    local info = getDodgeInfo(p)
                    if info then
                        if info.ready then
                            if d.dodgeState ~= 1 then
                                d.dodgeState = 1
                                d.dodgeLabel.Text = "BODY DODGE: ON"
                                d.dodgeLabel.TextColor3 = ESP.DodgeOnColor
                            end
                        else
                            if d.dodgeState ~= info.cd then
                                d.dodgeState = info.cd
                                d.dodgeLabel.Text = "BODY DODGE: " .. info.cd
                                d.dodgeLabel.TextColor3 = ESP.DodgeCDColor
                            end
                        end
                        d.dodgeLabel.Visible = true
                    else d.dodgeLabel.Visible = false end
                else d.dodgeLabel.Visible = false end
            end)
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

    -- ========== HOOK ==========
    local oldNamecall, oldNewIndex, metaT
    local unifiedHook = false
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
                    if args[1] == "fixmouse" and silentAim.Enabled and silentAim.CachedCFrame then
                        args[2] = silentAim.CachedCFrame
                    end
                end
                return oldNamecall(self, table.unpack(args))
            end)
            metaT.__newindex = newcclosure(function(self, key, value)
                if perf.blockNewEffects and key == "Enabled" then
                    local ok2, cls = pcall(function() return self.ClassName end)
                    if ok2 and cls and (cls == "ParticleEmitter" or cls == "Beam" or cls == "Trail"
                        or cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight") then
                        if value == true then return end
                    end
                end
                return oldNewIndex(self, key, value)
            end)
            setreadonly(metaT, true)
            unifiedHook = true
        end)
        if not ok then warn("Hook error: " .. tostring(err)) end
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

    RunService.Heartbeat:Connect(function()
        if silentAim.MasterEnabled and silentAim.Mode == "Hold" then
            silentAim.Enabled = UserInputService:IsKeyDown(silentAim.HoldKey)
        end
        if not silentAim.Enabled then
            silentAim.CachedTarget = nil; silentAim.CachedCFrame = nil; return
        end
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
            if enemyRoot and not isMaxDistOk((enemyRoot.Position - originPos).Magnitude, silentAim.MaxDistance) then continue end
            if silentAim.Mode360 then
                local wd = (part.Position - originPos).Magnitude
                if wd < bestScore then bestScore = wd; best = part end
            else
                local pos, vis = cam:WorldToViewportPoint(part.Position)
                if not vis then continue end
                local sd = (Vector2.new(pos.X, pos.Y) - MousePos).Magnitude
                if sd > silentAim.FOV then continue end
                local wd = (part.Position - originPos).Magnitude
                local score = silentAim.PrioritizeClose and wd or sd
                if score < bestScore then bestScore = score; best = part end
            end
        end
        silentAim.CachedTarget = best
        if best and best.Parent then
            local tp = best.Position + best.Velocity * silentAim.Prediction
            local cp = cam.CFrame.Position
            silentAim.CachedCFrame = CFrame.new(tp, tp + (tp - cp).Unit)
        end
    end)

    -- ========== AIMBOT HELPERS ==========
    local function getBestAimPart(char, customPart)
        if not char then return nil end
        if customPart and customPart ~= "Auto" then
            local p = char:FindFirstChild(customPart)
            if p and p:IsA("BasePart") then return p end
        end
        for _, n in ipairs({"HumanoidRootPart", "Head", "UpperTorso", "Torso"}) do
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
            local er = char:FindFirstChild("HumanoidRootPart")
            if er and not isMaxDistOk((er.Position - originPos).Magnitude, settings.maxDistance) then continue end
            local wd = (tp.Position - originPos).Magnitude
            if settings.mode360 then
                if wd < bestS then bestS = wd; bestT = p end
            else
                local sp, onScreen = Camera:WorldToViewportPoint(tp.Position)
                if not onScreen then continue end
                local cd = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                if cd > settings.fov then continue end
                local score = settings.prioritizeClose and wd or cd
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
            local er = char:FindFirstChild("HumanoidRootPart")
            if er and not isMaxDistOk((er.Position - originPos).Magnitude, settings.aim2MaxDistance) then continue end
            local wd = (aimPos - originPos).Magnitude
            if settings.aim2Mode360 then
                if wd < bestS then bestS = wd; bestT = p end
            else
                local sp, onScreen = Camera:WorldToViewportPoint(aimPos)
                if not onScreen then continue end
                local cd = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                if cd > settings.aim2Fov then continue end
                local score = settings.aim2PrioritizeClose and wd or cd
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

    -- ========== KUNAI SNAP ==========
    local function getKunaiSnapTarget()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end

        if settings.kunaiSnapAimMode ~= "Head+Offset" then
            local marked = getClosestMarkedTarget()
            if marked and marked.Parent then
                if settings.kunaiSnapAimMode == "Marker" then
                    local pos = getMarkerAimPosition(marked)
                    if pos then return pos end
                elseif settings.kunaiSnapAimMode == "Marker Projectile" then
                    local pos = getMarkerProjectilePosition(marked)
                    if pos then return pos end
                end
            end
        end

        -- fallback: ближайший игрок Head+Offset
        local best, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local char = p.Character
            if not char then continue end
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not head or not hum or hum.Health <= 0 then continue end
            local aimPos = head.Position + Vector3.new(0, settings.kunaiSnapHeight, 0)
            local dist = (aimPos - myRoot.Position).Magnitude
            if not isMaxDistOk(dist, settings.kunaiSnapMaxDist) then continue end
            if dist < bestDist then bestDist = dist; best = aimPos end
        end
        return best
    end

    local function kunaiSnapPerform()
        if kunaiSnapBusy then return end
        local target = getKunaiSnapTarget()
        if not target then
            Fluent:Notify({Title = "🌀 Kunai Snap", Content = "Цель не найдена", Duration = 2})
            return
        end

        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        kunaiSnapBusy = true
        local savedCFrame = Camera.CFrame
        local savedType = Camera.CameraType
        local savedSubject = Camera.CameraSubject

        Camera.CameraType = Enum.CameraType.Scriptable

        local origin = myRoot.Position
        local dir = (target - origin)
        local snapCFrame = CFrame.lookAt(origin, origin + dir.Unit)

        local delayEnd = tick() + (settings.kunaiSnapDelayMs / 1000)
        while tick() < delayEnd do
            Camera.CFrame = snapCFrame
            RunService.RenderStepped:Wait()
        end

        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(settings.kunaiSnapClickHoldMs / 1000)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)

        local postEnd = tick() + (settings.kunaiSnapPostWaitMs / 1000)
        while tick() < postEnd do
            Camera.CFrame = snapCFrame
            RunService.RenderStepped:Wait()
        end

        Camera.CameraType = savedType
        Camera.CameraSubject = savedSubject
        Camera.CFrame = savedCFrame
        kunaiSnapBusy = false
    end

    -- ========== SERVER ==========
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
    local function addJobToHistory(jobId, placeId)
        table.insert(lastJobHistory, 1, {id = jobId, place = placeId, time = os.time()})
        while #lastJobHistory > 10 do table.remove(lastJobHistory) end
        saveHistory()
    end
    loadHistory()

    local function getPlayerPing()
        local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
        return ok and ping and math.floor(ping * 1000) or 0
    end

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
                local newId = avail[math.random(1, #avail)]
                addJobToHistory(newId, game.PlaceId)
                TeleportService:TeleportToPlaceInstance(game.PlaceId, newId, LocalPlayer)
            else
                Fluent:Notify({Title = "❌", Content = "Нет серверов", Duration = 3})
            end
        end)
    end
    local function rejoinServer()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end
    local function forceReconnect()
        task.spawn(function()
            for i = 1, 3 do
                local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
                if ok then return end
                task.wait(1)
            end
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end)
    end
    local function joinByJobId(jobId)
        if not jobId or jobId == "" then return end
        addJobToHistory(jobId, game.PlaceId)
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end)
    end
    local function joinLastServer()
        if #lastJobHistory == 0 then return end
        local last = lastJobHistory[1]
        pcall(function() TeleportService:TeleportToPlaceInstance(last.place or game.PlaceId, last.id, LocalPlayer) end)
    end

    -- ========== GUI ==========
    local Window = Fluent:CreateWindow({
        Title = "Flunium Client v2.7",
        SubTitle = "",
        TabWidth = 160,
        Size = UDim2.fromOffset(620, 540),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })

    local Tabs = {
        Aimbot = Window:AddTab({Title = "Aimbot 🎯", Icon = "crosshair"}),
        Kunai = Window:AddTab({Title = "Kunai Mark 🌀", Icon = "target"}),
        Silent = Window:AddTab({Title = "Silent Aim 🎭", Icon = "eye-off"}),
        ESP = Window:AddTab({Title = "ESP 👁️", Icon = "eye"}),
        Colors = Window:AddTab({Title = "Colors 🎨", Icon = "palette"}),
        Performance = Window:AddTab({Title = "Performance ⚡", Icon = "zap"}),
        Server = Window:AddTab({Title = "Server 🌐", Icon = "globe"}),
        Overlay = Window:AddTab({Title = "Overlay 📊", Icon = "activity"}),
        UI = Window:AddTab({Title = "UI", Icon = "settings"})
    }

    local Options = Fluent.Options

    -- AIMBOT 1
    Tabs.Aimbot:AddToggle("AimOn", {Title = "Enable Aimbot", Default = false}):OnChanged(function(v)
        aimbotEnabled = v
        if fovCircle then fovCircle.Visible = settings.showFovCircle and v and not settings.mode360 end
        if not v then aiming = false; currentTarget = nil end
    end)
    Tabs.Aimbot:AddToggle("ShowFOV", {Title = "Show FOV", Default = true}):OnChanged(function(v)
        settings.showFovCircle = v
        if fovCircle then fovCircle.Visible = v and aimbotEnabled and not settings.mode360 end
    end)
    Tabs.Aimbot:AddColorpicker("FovColor", {Title = "FOV Color", Default = Color3.fromRGB(255,0,0)}):OnChanged(function(c)
        settings.fovColor = c; if fovCircle then fovCircle.Color = c end
    end)
    Tabs.Aimbot:AddDropdown("AimPart", {Title = "Aim Part",
        Values = {"HumanoidRootPart", "Head", "UpperTorso", "Torso"}, Default = 1
    }):OnChanged(function(v) settings.aimPart = v end)
    Tabs.Aimbot:AddDropdown("AimMode", {Title = "Mode",
        Values = {"Hold", "Toggle"}, Default = 1
    }):OnChanged(function(v) settings.aimMode = v end)
    local aimBindButton
    aimBindButton = Tabs.Aimbot:AddButton({
        Title = "Bind: " .. settings.aimKey.Name,
        Callback = function()
            settings.listeningAimBind = true
            pcall(function() aimBindButton:SetTitle("Нажми клавишу...") end)
        end
    })
    Tabs.Aimbot:AddSlider("FOV", {Title = "FOV", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
        settings.fov = v; if fovCircle then fovCircle.Radius = v end
    end)
    Tabs.Aimbot:AddSlider("MaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 100}):OnChanged(function(v) settings.maxDistance = v end)
    Tabs.Aimbot:AddToggle("PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) settings.prioritizeClose = v end)
    Tabs.Aimbot:AddToggle("Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
        settings.mode360 = v
        if v and fovCircle then fovCircle.Visible = false end
    end)
    Tabs.Aimbot:AddSlider("Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) settings.smoothing = v / 100 end)
    Tabs.Aimbot:AddSlider("Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v) settings.prediction = v / 100 end)
    Tabs.Aimbot:AddToggle("AimNPCs", {Title = "Aim at NPCs", Default = false}):OnChanged(function(v) settings.aimAtNPCs = v end)

    -- KUNAI MARK AIMBOT
    Tabs.Kunai:AddToggle("Aim2On", {Title = "Enable Kunai Mark Aimbot", Default = false}):OnChanged(function(v)
        aim2Enabled = v
        if fovCircle2 then fovCircle2.Visible = settings.aim2ShowFovCircle and v and not settings.aim2Mode360 end
        if not v then aim2ing = false; aim2Target = nil end
    end)
    Tabs.Kunai:AddToggle("Aim2ShowFOV", {Title = "Show FOV", Default = true}):OnChanged(function(v)
        settings.aim2ShowFovCircle = v
        if fovCircle2 then fovCircle2.Visible = v and aim2Enabled and not settings.aim2Mode360 end
    end)
    Tabs.Kunai:AddDropdown("Aim2Mode", {Title = "Mode",
        Values = {"Hold", "Toggle"}, Default = 1
    }):OnChanged(function(v) settings.aim2Mode = v end)
    local aim2BindButton
    aim2BindButton = Tabs.Kunai:AddButton({
        Title = "Bind: " .. settings.aim2Key.Name,
        Callback = function()
            settings.aim2ListeningForBind = true
            pcall(function() aim2BindButton:SetTitle("Нажми клавишу...") end)
        end
    })
    Tabs.Kunai:AddSlider("Aim2Height", {Title = "Height Above Head", Default = 17, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v) settings.aim2HeightOffset = v end)
    Tabs.Kunai:AddSlider("Aim2FOV", {Title = "FOV", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
        settings.aim2Fov = v; if fovCircle2 then fovCircle2.Radius = v end
    end)
    Tabs.Kunai:AddSlider("Aim2MaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 100}):OnChanged(function(v) settings.aim2MaxDistance = v end)
    Tabs.Kunai:AddToggle("Aim2PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) settings.aim2PrioritizeClose = v end)
    Tabs.Kunai:AddToggle("Aim2Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
        settings.aim2Mode360 = v
        if v and fovCircle2 then fovCircle2.Visible = false end
    end)
    Tabs.Kunai:AddSlider("Aim2Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) settings.aim2Smoothing = v / 100 end)
    Tabs.Kunai:AddSlider("Aim2Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v) settings.aim2Prediction = v / 100 end)
    Tabs.Kunai:AddToggle("Aim2NPCs", {Title = "Aim at NPCs", Default = false}):OnChanged(function(v) settings.aim2AimAtNPCs = v end)

    -- KUNAI SNAP
    Tabs.Kunai:AddSection("Kunai Mark Snap")
    Tabs.Kunai:AddToggle("KunaiSnapOn", {Title = "Enable Kunai Mark Snap", Default = false}):OnChanged(function(v)
        settings.kunaiSnap = v
    end)
    local kunaiSnapBindBtn
    kunaiSnapBindBtn = Tabs.Kunai:AddButton({
        Title = "Bind: " .. settings.kunaiSnapKey.Name,
        Callback = function()
            settings.kunaiSnapListening = true
            pcall(function() kunaiSnapBindBtn:SetTitle("Нажми клавишу...") end)
        end
    })
    Tabs.Kunai:AddDropdown("KunaiSnapAimMode", {Title = "Aim Mode",
        Values = {"Marker", "Marker Projectile", "Head+Offset"}, Default = 1
    }):OnChanged(function(v) settings.kunaiSnapAimMode = v end)
    Tabs.Kunai:AddSlider("KunaiSnapHeight", {Title = "Height Above Head (fallback)", Default = 17, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v) settings.kunaiSnapHeight = v end)
    Tabs.Kunai:AddSlider("KunaiSnapMaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 100}):OnChanged(function(v) settings.kunaiSnapMaxDist = v end)
    Tabs.Kunai:AddSlider("KunaiSnapDelay", {Title = "Snap Delay (ms)", Default = 50, Min = 10, Max = 300, Rounding = 5}):OnChanged(function(v) settings.kunaiSnapDelayMs = v end)
    Tabs.Kunai:AddSlider("KunaiSnapClickHold", {Title = "Click Hold (ms)", Default = 60, Min = 10, Max = 300, Rounding = 5}):OnChanged(function(v) settings.kunaiSnapClickHoldMs = v end)
    Tabs.Kunai:AddSlider("KunaiSnapPostWait", {Title = "Post-Click Wait (ms)", Default = 30, Min = 0, Max = 200, Rounding = 5}):OnChanged(function(v) settings.kunaiSnapPostWaitMs = v end)

    -- SILENT AIM
    Tabs.Silent:AddToggle("SilentMaster", {Title = "Enable Silent Aim", Default = false}):OnChanged(function(v)
        silentAim.MasterEnabled = v
        if v then enableUnifiedHook() else
            if not perf.blockNewEffects then disableUnifiedHook() end
        end
    end)
    Tabs.Silent:AddToggle("SilentShowFOV", {Title = "Show FOV", Default = true}):OnChanged(function(v) silentAim.ShowFovCircle = v end)
    Tabs.Silent:AddDropdown("SilentMode", {Title = "Mode", Values = {"Hold", "Toggle"}, Default = 1}):OnChanged(function(v) silentAim.Mode = v end)
    local silentBindButton
    silentBindButton = Tabs.Silent:AddButton({
        Title = "Bind: " .. silentAim.HoldKey.Name,
        Callback = function()
            silentAim.ListeningForBind = true
            pcall(function() silentBindButton:SetTitle("Нажми клавишу...") end)
        end
    })
    Tabs.Silent:AddSlider("SilentFOV", {Title = "FOV", Default = 500, Min = 50, Max = 2000, Rounding = 0}):OnChanged(function(v)
        silentAim.FOV = v; if silentFovCircle then silentFovCircle.Radius = v end
    end)
    Tabs.Silent:AddSlider("SilentPred", {Title = "Prediction", Default = 19, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v) silentAim.Prediction = v / 100 end)
    Tabs.Silent:AddSlider("SilentMaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 100}):OnChanged(function(v) silentAim.MaxDistance = v end)
    Tabs.Silent:AddToggle("SilentMode360", {Title = "360° Mode", Default = false}):OnChanged(function(v) silentAim.Mode360 = v end)

    -- ESP
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
    Tabs.ESP:AddToggle("EspName", {Title = "Name", Default = true}):OnChanged(function(v) ESP.ShowName = v; rebuildESP() end)
    Tabs.ESP:AddToggle("EspHP", {Title = "HP", Default = true}):OnChanged(function(v) ESP.ShowHP = v; rebuildESP() end)
    Tabs.ESP:AddToggle("EspMD", {Title = "MD", Default = true}):OnChanged(function(v) ESP.ShowMD = v; rebuildESP() end)
    Tabs.ESP:AddToggle("EspDodge", {Title = "Body Dodge", Default = true}):OnChanged(function(v) ESP.ShowDodge = v; rebuildESP() end)
    Tabs.ESP:AddSlider("EspSize", {Title = "Size", Default = 100, Min = 30, Max = 300, Rounding = 0}):OnChanged(function(v) ESP.Size = v / 100 end)

    -- COLORS
    Tabs.Colors:AddToggle("RainbowSkin", {Title = "Rainbow Skin", Default = false}):OnChanged(function(v) colors.RainbowSkin = v end)
    Tabs.Colors:AddToggle("RainbowHair", {Title = "Rainbow Hair", Default = false}):OnChanged(function(v) colors.RainbowHair = v end)
    Tabs.Colors:AddSlider("SkinSpd", {Title = "Skin Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v) colors.SkinSpeed = v / 10 end)
    Tabs.Colors:AddSlider("HairSpd", {Title = "Hair Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v) colors.HairSpeed = v / 10 end)

    local colorPresets = {
        {name = "🔴 Красный", r=255, g=0, b=0},
        {name = "🟢 Зелёный", r=0, g=255, b=0},
        {name = "🔵 Синий", r=0, g=0, b=255},
        {name = "🟣 Фиолетовый", r=128, g=0, b=255},
        {name = "🟡 Жёлтый", r=255, g=255, b=0},
        {name = "⚫ Чёрный", r=0, g=0, b=0},
        {name = "⚪ Белый", r=255, g=255, b=255},
        {name = "🟠 Оранжевый", r=255, g=165, b=0},
        {name = "💗 Розовый", r=255, g=105, b=180},
        {name = "🩵 Cyan", r=0, g=255, b=255},
    }
    for _, preset in ipairs(colorPresets) do
        Tabs.Colors:AddButton({
            Title = preset.name .. " — Волосы",
            Callback = function() sendHair(preset.r, preset.g, preset.b) end
        })
    end

    Tabs.Colors:AddSection("Кастомный цвет")
    Tabs.Colors:AddInput("CustomHairR", {Title = "Hair R", Default = "255", Numeric = true})
    Tabs.Colors:AddInput("CustomHairG", {Title = "Hair G", Default = "0", Numeric = true})
    Tabs.Colors:AddInput("CustomHairB", {Title = "Hair B", Default = "0", Numeric = true})
    Tabs.Colors:AddButton({
        Title = "Применить кастомные волосы",
        Callback = function()
            sendHair(tonumber(Options.CustomHairR.Value) or 255,
                     tonumber(Options.CustomHairG.Value) or 0,
                     tonumber(Options.CustomHairB.Value) or 0)
        end
    })
    Tabs.Colors:AddInput("CustomSkinR", {Title = "Skin R", Default = "255", Numeric = true})
    Tabs.Colors:AddInput("CustomSkinG", {Title = "Skin G", Default = "0", Numeric = true})
    Tabs.Colors:AddInput("CustomSkinB", {Title = "Skin B", Default = "0", Numeric = true})
    Tabs.Colors:AddButton({
        Title = "Применить кастомный скин",
        Callback = function()
            sendSkin(tonumber(Options.CustomSkinR.Value) or 255,
                     tonumber(Options.CustomSkinG.Value) or 0,
                     tonumber(Options.CustomSkinB.Value) or 0)
        end
    })

    -- PERFORMANCE
    Tabs.Performance:AddSection("Performance")
    Tabs.Performance:AddToggle("LowDetail", {Title = "Low Detail Mode", Default = false}):OnChanged(applyLowDetail)
    Tabs.Performance:AddToggle("RemoveTextures", {Title = "Remove Textures", Default = false}):OnChanged(applyRemoveTextures)
    Tabs.Performance:AddToggle("RemoveDecals", {Title = "Remove Decals", Default = false}):OnChanged(applyRemoveDecals)
    Tabs.Performance:AddToggle("RemoveParticles", {Title = "Remove Particles", Default = false}):OnChanged(applyRemoveParticles)
    Tabs.Performance:AddToggle("RemoveShadows", {Title = "Remove Shadows", Default = false}):OnChanged(applyRemoveShadows)
    Tabs.Performance:AddToggle("ForcePlastic", {Title = "Force Plastic", Default = false}):OnChanged(applyForcePlastic)
    Tabs.Performance:AddToggle("DisablePost", {Title = "Disable Post-FX", Default = false}):OnChanged(applyDisablePostFx)
    Tabs.Performance:AddToggle("ExtendFog", {Title = "Extend Fog", Default = false}):OnChanged(applyExtendFog)
    Tabs.Performance:AddToggle("OptimizeWater", {Title = "Optimize Water", Default = false}):OnChanged(applyOptimizeWater)
    Tabs.Performance:AddToggle("RemoveLights", {Title = "Remove Lights", Default = false}):OnChanged(applyRemoveLights)
    Tabs.Performance:AddToggle("RemoveBeams", {Title = "Remove Beams/Trails", Default = false}):OnChanged(applyRemoveBeams)
    Tabs.Performance:AddToggle("RemoveHighlights", {Title = "Remove Highlights", Default = false}):OnChanged(applyRemoveHighlights)
    Tabs.Performance:AddToggle("HideAccessories", {Title = "Hide Accessories", Default = false}):OnChanged(applyHideAccessories)
    Tabs.Performance:AddToggle("RemoveCharFx", {Title = "Remove Char Effects", Default = false}):OnChanged(applyRemoveCharFx)

    Tabs.Performance:AddSection("Visual")
    Tabs.Performance:AddToggle("XRay", {Title = "X-Ray", Default = false}):OnChanged(applyXRay)
    Tabs.Performance:AddToggle("FB", {Title = "Full Bright", Default = false}):OnChanged(applyFullBright)
    Tabs.Performance:AddToggle("NV", {Title = "Night Vision", Default = false}):OnChanged(applyNightVision)
    Tabs.Performance:AddToggle("NoSh", {Title = "No Shadows", Default = false}):OnChanged(applyNoShadows)
    Tabs.Performance:AddToggle("NoBl", {Title = "No Bloom", Default = false}):OnChanged(applyNoBloom)
    Tabs.Performance:AddToggle("NoSR", {Title = "No Sun Rays", Default = false}):OnChanged(applyNoSunRays)
    Tabs.Performance:AddToggle("NoFog", {Title = "No Fog", Default = false}):OnChanged(applyNoFog)

    Tabs.Performance:AddSection("FPS")
    Tabs.Performance:AddToggle("FpsUnlock", {Title = "Unlock FPS Cap", Default = false}):OnChanged(applyFpsUnlock)
    Tabs.Performance:AddSlider("FpsCap", {Title = "FPS Cap", Default = 999, Min = 30, Max = 999, Rounding = 0}):OnChanged(function(v)
        perf.fpsCap = v
        if perf.fpsUnlock then pcall(function() setfpscap(v) end) end
    end)

    -- SERVER
    local pingPara = Tabs.Server:AddParagraph({Title = "📡 Network", Content = "🟢 ..."})
    Tabs.Server:AddButton({Title = "🔄 Server Hop", Callback = serverHop})
    Tabs.Server:AddButton({Title = "🔁 ReJoin Server", Callback = rejoinServer})
    Tabs.Server:AddButton({Title = "⚡ Force Reconnect", Callback = forceReconnect})

    Tabs.Server:AddSection("🌐 Server Job")
    local jobIdPara = Tabs.Server:AddParagraph({Title = "Current Job ID", Content = tostring(game.JobId)})
    Tabs.Server:AddButton({
        Title = "📄 Скопировать Job ID",
        Callback = function()
            pcall(function() if setclipboard then setclipboard(tostring(game.JobId)) end end)
            Fluent:Notify({Title = "📋", Content = "Скопировано", Duration = 2})
        end
    })
    Tabs.Server:AddButton({
        Title = "🔄 Обновить Job ID",
        Callback = function() pcall(function() jobIdPara:SetDesc(tostring(game.JobId)) end) end
    })
    Tabs.Server:AddInput("JoinJobId", {
        Title = "Join by Job ID",
        Placeholder = "Job ID...",
        Default = ""
    })
    Tabs.Server:AddButton({
        Title = "▶ JOIN по Job ID",
        Callback = function()
            local v = Options.JoinJobId.Value
            if v and v ~= "" then joinByJobId(v) end
        end
    })
    Tabs.Server:AddButton({
        Title = "📥 Вставить из буфера",
        Callback = function()
            pcall(function() if getclipboard then Options.JoinJobId:SetValue(getclipboard()) end end)
        end
    })
    Tabs.Server:AddButton({Title = "↩ Join Last Server", Callback = function() joinLastServer() end})

    local lastList = Tabs.Server:AddDropdown("LastServers", {
        Title = "Последние Job ID",
        Values = {},
        Default = 1
    }):OnChanged(function(v)
        if v and v ~= "" then
            for _, rec in ipairs(lastJobHistory) do
                if rec.id == v then
                    pcall(function() TeleportService:TeleportToPlaceInstance(rec.place or game.PlaceId, rec.id, LocalPlayer) end)
                    break
                end
            end
        end
    end)
    Tabs.Server:AddButton({
        Title = "🔄 Обновить список",
        Callback = function()
            local opts = {}
            for _, rec in ipairs(lastJobHistory) do
                table.insert(opts, rec.id .. " | " .. os.date("%H:%M:%S", rec.time))
            end
            if #opts == 0 then opts = {"— пусто —"} end
            pcall(function() lastList:SetValues(opts) end)
        end
    })
    Tabs.Server:AddButton({
        Title = "🗑 Очистить историю",
        Callback = function()
            lastJobHistory = {}
            saveHistory()
            pcall(function() lastList:SetValues({"— пусто —"}) end)
        end
    })

    task.spawn(function()
        task.wait(1)
        while task.wait(2) do
            local p = getPlayerPing()
            local emoji = p < 100 and "🟢" or (p < 200 and "🟡" or "🔴")
            pcall(function() pingPara:SetDesc(emoji .. " " .. p .. " ms") end)
        end
    end)

    -- OVERLAY
    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "FluniumOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local overlayFrame = Instance.new("Frame", overlayGui)
    overlayFrame.Size = UDim2.new(0, 220, 0, 60)
    overlayFrame.Position = UDim2.new(0, 20, 0, 20)
    overlayFrame.BackgroundTransparency = 1

    local fpsLabel = Instance.new("TextLabel", overlayFrame)
    fpsLabel.Size = UDim2.new(1, 0, 0, 26)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fpsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.TextStrokeTransparency = 0.3
    fpsLabel.Font = Enum.Font.GothamBold
    fpsLabel.TextSize = 18
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    fpsLabel.Text = "FPS: ..."

    local pingLabel = Instance.new("TextLabel", overlayFrame)
    pingLabel.Size = UDim2.new(1, 0, 0, 26)
    pingLabel.Position = UDim2.new(0, 0, 0, 26)
    pingLabel.BackgroundTransparency = 1
    pingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    pingLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    pingLabel.TextStrokeTransparency = 0.3
    pingLabel.Font = Enum.Font.GothamBold
    pingLabel.TextSize = 18
    pingLabel.TextXAlignment = Enum.TextXAlignment.Left
    pingLabel.Text = "PING: ..."

    local overlay = {showFps = true, showPing = true, size = 18}
    local fpsCounter, fpsTimer, currentFps, currentPing = 0, 0, 0, 0

    RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            fpsCounter = fpsCounter + 1
            fpsTimer = fpsTimer + dt
            if fpsTimer >= 1 then
                currentFps = math.floor(fpsCounter / fpsTimer)
                fpsCounter = 0
                fpsTimer = 0
            end
            if overlay.showFps then
                fpsLabel.Visible = true
                fpsLabel.Text = "FPS: " .. currentFps
                fpsLabel.TextSize = overlay.size
            else
                fpsLabel.Visible = false
            end
            if overlay.showPing then
                pingLabel.Visible = true
                local emoji = currentPing < 100 and "🟢" or (currentPing < 200 and "🟡" or "🔴")
                pingLabel.Text = "PING: " .. emoji .. " " .. currentPing .. " ms"
                pingLabel.TextSize = overlay.size
            else
                pingLabel.Visible = false
            end
        end)
    end)

    task.spawn(function()
        while task.wait(1) do
            currentPing = getPlayerPing()
        end
    end)

    Tabs.Overlay:AddToggle("OverlayFPS", {Title = "Show FPS (Shift+F5)", Default = true}):OnChanged(function(v) overlay.showFps = v end)
    Tabs.Overlay:AddToggle("OverlayPing", {Title = "Show Ping (Shift+F3)", Default = true}):OnChanged(function(v) overlay.showPing = v end)
    Tabs.Overlay:AddSlider("OverlaySize", {Title = "Size", Default = 18, Min = 10, Max = 40, Rounding = 0}):OnChanged(function(v) overlay.size = v end)
    Tabs.Overlay:AddDropdown("OverlayPos", {Title = "Position",
        Values = {"TopLeft", "TopRight", "BottomLeft", "BottomRight"}, Default = 1
    }):OnChanged(function(v)
        if v == "TopLeft" then overlayFrame.Position = UDim2.new(0, 20, 0, 20)
        elseif v == "TopRight" then overlayFrame.Position = UDim2.new(1, -240, 0, 20)
        elseif v == "BottomLeft" then overlayFrame.Position = UDim2.new(0, 20, 1, -80)
        elseif v == "BottomRight" then overlayFrame.Position = UDim2.new(1, -240, 1, -80) end
    end)

    -- INPUT
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end

        if input.KeyCode == Enum.KeyCode.F5 and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            overlay.showFps = not overlay.showFps
            return
        end
        if input.KeyCode == Enum.KeyCode.F3 and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            overlay.showPing = not overlay.showPing
            return
        end

        if settings.kunaiSnapListening and input.UserInputType == Enum.UserInputType.Keyboard then
            settings.kunaiSnapKey = input.KeyCode
            settings.kunaiSnapListening = false
            pcall(function() kunaiSnapBindBtn:SetTitle("Bind: " .. input.KeyCode.Name) end)
            return
        end
        if silentAim.ListeningForBind and input.UserInputType == Enum.UserInputType.Keyboard then
            silentAim.HoldKey = input.KeyCode
            silentAim.ListeningForBind = false
            pcall(function() silentBindButton:SetTitle("Bind: " .. input.KeyCode.Name) end)
            return
        end
        if settings.listeningAimBind and input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aimKey = input.KeyCode
            settings.listeningAimBind = false
            pcall(function() aimBindButton:SetTitle("Bind: " .. input.KeyCode.Name) end)
            return
        end
        if settings.aim2ListeningForBind and input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aim2Key = input.KeyCode
            settings.aim2ListeningForBind = false
            pcall(function() aim2BindButton:SetTitle("Bind: " .. input.KeyCode.Name) end)
            return
        end

        if settings.kunaiSnap and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == settings.kunaiSnapKey then
            task.spawn(kunaiSnapPerform)
            return
        end

        if silentAim.MasterEnabled and silentAim.Mode == "Toggle" and input.KeyCode == silentAim.HoldKey then
            silentAim.Enabled = not silentAim.Enabled
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

    -- RENDER
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
            fovCircle.Color = aiming and currentTarget and settings.targetedColor or settings.fovColor
        elseif fovCircle then fovCircle.Visible = false end
        if aim2Enabled and fovCircle2 and settings.aim2ShowFovCircle and not settings.aim2Mode360 then
            fovCircle2.Position = Vector2.new(mpos.X, mpos.Y + 50)
            fovCircle2.Visible = true
            fovCircle2.Color = aim2ing and aim2Target and settings.aim2TargetedColor or settings.aim2FovColor
        elseif fovCircle2 then fovCircle2.Visible = false end
        if silentAim.MasterEnabled and silentFovCircle and silentAim.ShowFovCircle and not silentAim.Mode360 then
            silentFovCircle.Position = Vector2.new(mpos.X, mpos.Y + 50)
            silentFovCircle.Visible = silentAim.Enabled
        elseif silentFovCircle then silentFovCircle.Visible = false end

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
        if colors.RainbowSkin then
            skinTimer = skinTimer + dt
            if skinTimer >= 0.1 then
                skinTimer = 0
                local h = (tick() * colors.SkinSpeed) % 1
                sendSkinColor(Color3.fromHSV(h, 1, 1))
            end
        end
        if colors.RainbowHair then
            hairTimer = hairTimer + dt
            if hairTimer >= 0.1 then
                hairTimer = 0
                local h = (tick() * colors.HairSpeed) % 1
                sendHairColor(Color3.fromHSV(h, 1, 1))
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
    print("✅ Flunium Client v2.7 загружен")
    print("🌀 Marker Tracker: targets MAIN (точная точка маркера)")
    print("🎯 Kunai Snap: Marker / Marker Projectile / Head+Offset")
    print("📌 RightControl — скрыть меню")
    print("====================================")

    getgenv().FluniumLoaded = true
end

Flunium_Boot()
