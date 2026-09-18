--[[
    Universal Aimbot v2.1 (Fluent UI)
    GitHub: https://github.com/elvinsz/simple-universal-aimbot
]]

if getgenv().UniversalAimbotLoaded then
    print("⚠️ Universal Aimbot уже загружен!")
    return
end
getgenv().UniversalAimbotLoaded = true

-- Загрузка Fluent UI
print("🔄 Загрузка Fluent UI...")
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

if not Fluent then
    warn("❌ Fluent UI не загружен!")
    getgenv().UniversalAimbotLoaded = false
    return
end
print("✅ Fluent UI загружен!")

-- Сервисы
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LocalizationService = game:GetService("LocalizationService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--> [< ПАПКИ КОНФИГОВ >] <--

local CONFIG_FOLDER = "UniversalAimbot"
local CONFIGS_FOLDER = "UniversalAimbot/Configs"
local AUTOEXEC_FILE = "UniversalAimbot/autoexec.json"

local function ensureFolders()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
        if not isfolder(CONFIGS_FOLDER) then makefolder(CONFIGS_FOLDER) end
    end)
end

ensureFolders()

--> [< НАСТРОЙКИ >] <--

local settings = {
    fov = 300,
    smoothing = 0.15,
    prediction = 0.065,
    wallCheck = false,
    stickyAim = false,
    teamCheck = false,
    healthCheck = false,
    minHealth = 0,
    aimPart = "Auto",
    aimMode = "Hold",
    key = "BackSlash",
    showFovCircle = true,
    maxDistance = 5000,
    prioritizeClose = true,
    rainbowFov = false,
    fovColor = Color3.fromRGB(255, 0, 0),
    targetedColor = Color3.fromRGB(0, 255, 0),
    xray = false,
    fullBright = false,
    nightVision = false,
    noShadows = false,
    noBloom = false,
    noSunRays = false,
    rainbowLighting = false,
    noFog = false
}

local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows
}

local aimbotEnabled = false
local aiming = false
local currentTarget = nil
local lastTargetUpdate = 0
local targetUpdateInterval = 0.05

local ALL_BODY_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot"
}

local hue = 0
local rainbowSpeed = 0.005
local lightingHue = 0

local fovCircle
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.Radius = settings.fov
    fovCircle.Filled = false
    fovCircle.Color = settings.fovColor
    fovCircle.Transparency = 1
    fovCircle.Visible = false
end)

--> [< ПИНГ И РЕГИОН >] <--

local function getPlayerPing()
    local success, ping = pcall(function()
        return LocalPlayer:GetNetworkPing()
    end)
    if success and ping then
        return math.floor(ping * 1000)
    end
    return 0
end

local function getServerRegion()
    local success, region = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer)
    end)
    if success and region then
        return tostring(region)
    end
    return "Unknown"
end

--> [< СИСТЕМА КОНФИГОВ >] <--

local function collectSettings()
    return {
        fov = settings.fov,
        smoothing = settings.smoothing,
        prediction = settings.prediction,
        wallCheck = settings.wallCheck,
        stickyAim = settings.stickyAim,
        teamCheck = settings.teamCheck,
        healthCheck = settings.healthCheck,
        minHealth = settings.minHealth,
        aimPart = settings.aimPart,
        aimMode = settings.aimMode,
        key = settings.key,
        showFovCircle = settings.showFovCircle,
        maxDistance = settings.maxDistance,
        prioritizeClose = settings.prioritizeClose,
        rainbowFov = settings.rainbowFov,
        fovColor = {R = settings.fovColor.R, G = settings.fovColor.G, B = settings.fovColor.B},
        targetedColor = {R = settings.targetedColor.R, G = settings.targetedColor.G, B = settings.targetedColor.B},
        xray = settings.xray,
        fullBright = settings.fullBright,
        nightVision = settings.nightVision,
        noShadows = settings.noShadows,
        noBloom = settings.noBloom,
        noSunRays = settings.noSunRays,
        rainbowLighting = settings.rainbowLighting,
        noFog = settings.noFog
    }
end

local function applySettings(data)
    if not data then return false end
    
    settings.fov = data.fov or settings.fov
    settings.smoothing = data.smoothing or settings.smoothing
    settings.prediction = data.prediction or settings.prediction
    settings.wallCheck = data.wallCheck ~= nil and data.wallCheck or settings.wallCheck
    settings.stickyAim = data.stickyAim ~= nil and data.stickyAim or settings.stickyAim
    settings.teamCheck = data.teamCheck ~= nil and data.teamCheck or settings.teamCheck
    settings.healthCheck = data.healthCheck ~= nil and data.healthCheck or settings.healthCheck
    settings.minHealth = data.minHealth or settings.minHealth
    settings.aimPart = data.aimPart or settings.aimPart
    settings.aimMode = data.aimMode or settings.aimMode
    settings.key = data.key or settings.key
    settings.showFovCircle = data.showFovCircle ~= nil and data.showFovCircle or settings.showFovCircle
    settings.maxDistance = data.maxDistance or settings.maxDistance
    settings.prioritizeClose = data.prioritizeClose ~= nil and data.prioritizeClose or settings.prioritizeClose
    settings.rainbowFov = data.rainbowFov ~= nil and data.rainbowFov or settings.rainbowFov
    
    if data.fovColor then
        settings.fovColor = Color3.new(data.fovColor.R, data.fovColor.G, data.fovColor.B)
        if fovCircle and not settings.rainbowFov then
            fovCircle.Color = settings.fovColor
        end
    end
    
    if data.targetedColor then
        settings.targetedColor = Color3.new(data.targetedColor.R, data.targetedColor.G, data.targetedColor.B)
    end
    
    if fovCircle then fovCircle.Radius = settings.fov end
    
    setXRay(data.xray or false)
    setFullBright(data.fullBright or false)
    setNightVision(data.nightVision or false)
    setNoShadows(data.noShadows or false)
    setNoBloom(data.noBloom or false)
    setNoSunRays(data.noSunRays or false)
    setRainbowLighting(data.rainbowLighting or false)
    setNoFog(data.noFog or false)
    
    return true
end

local function saveConfig(name)
    if not name or name == "" then
        Fluent:Notify({Title = "❌ Ошибка", Content = "Введите название", Duration = 3})
        return false
    end
    
    name = tostring(name):gsub("[^%w_%-%. ]", "")
    if name == "" then
        Fluent:Notify({Title = "❌ Ошибка", Content = "Недопустимое название", Duration = 3})
        return false
    end
    
    local success, result = pcall(function()
        ensureFolders()
        local data = collectSettings()
        local json = HttpService:JSONEncode(data)
        local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
        writefile(path, json)
        return path
    end)
    
    if success then
        Fluent:Notify({Title = "💾 Сохранён", Content = name .. ".json", Duration = 3})
        print("✅ Сохранён: " .. result)
        return true
    else
        Fluent:Notify({Title = "❌ Ошибка", Content = tostring(result), Duration = 4})
        return false
    end
end

local function loadConfig(name)
    if not name or name == "" or name == "Нет конфигов" then
        Fluent:Notify({Title = "❌ Ошибка", Content = "Выберите конфиг", Duration = 3})
        return false
    end
    
    local success, result = pcall(function()
        local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
        if not isfile(path) then error("Файл не найден") end
        local json = readfile(path)
        local data = HttpService:JSONDecode(json)
        applySettings(data)
        return name
    end)
    
    if success then
        Fluent:Notify({Title = "📂 Загружено", Content = "Конфиг: " .. result, Duration = 3})
        print("✅ Загружен: " .. result)
        return true
    else
        Fluent:Notify({Title = "❌ Ошибка", Content = tostring(result), Duration = 4})
        return false
    end
end

local function deleteConfig(name)
    if not name or name == "" or name == "Нет конфигов" then return false end
    
    local success = pcall(function()
        local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
        if isfile(path) then delfile(path) end
    end)
    
    if success then
        Fluent:Notify({Title = "🗑️ Удалён", Content = name, Duration = 2})
        return true
    end
    return false
end

local function getConfigList()
    local configs = {}
    pcall(function()
        ensureFolders()
        local files = listfiles(CONFIGS_FOLDER)
        for _, file in ipairs(files) do
            local name = file:match("([^/\\]+)%.json$")
            if name and name ~= "" then
                table.insert(configs, name)
            end
        end
    end)
    if #configs == 0 then table.insert(configs, "Нет конфигов") end
    return configs
end

local function saveAutoExec(configName, autoLoad)
    pcall(function()
        ensureFolders()
        local data = {lastConfig = configName or "", autoLoad = autoLoad or false}
        writefile(AUTOEXEC_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadAutoExec()
    local data = {lastConfig = "", autoLoad = false}
    pcall(function()
        if isfile(AUTOEXEC_FILE) then
            local json = readfile(AUTOEXEC_FILE)
            data = HttpService:JSONDecode(json)
        end
    end)
    return data
end

--> [< ВИЗУАЛЬНЫЕ ФУНКЦИИ >] <--

local function setXRay(enabled)
    settings.xray = enabled
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if enabled then
                    if not obj:GetAttribute("OrigTransparency") then
                        obj:SetAttribute("OrigTransparency", obj.Transparency)
                    end
                    obj.LocalTransparencyModifier = 0.5
                else
                    local orig = obj:GetAttribute("OrigTransparency")
                    if orig then obj.LocalTransparencyModifier = orig end
                end
            end
        end
    end)
end

local function setFullBright(enabled)
    settings.fullBright = enabled
    if enabled then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
    end
end

local function setNightVision(enabled)
    settings.nightVision = enabled
    pcall(function()
        if enabled then
            local nv = Lighting:FindFirstChild("NVEffect")
            if not nv then
                nv = Instance.new("ColorCorrectionEffect")
                nv.Name = "NVEffect"
                nv.Brightness = 0.3
                nv.Contrast = 0.5
                nv.Saturation = -0.5
                nv.TintColor = Color3.fromRGB(0, 255, 0)
                nv.Parent = Lighting
            end
            nv.Enabled = true
        else
            local nv = Lighting:FindFirstChild("NVEffect")
            if nv then nv.Enabled = false end
        end
    end)
end

local function setNoShadows(enabled)
    settings.noShadows = enabled
    Lighting.GlobalShadows = not enabled
end

local function setNoBloom(enabled)
    settings.noBloom = enabled
    pcall(function()
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("BloomEffect") then effect.Enabled = not enabled end
        end
    end)
end

local function setNoSunRays(enabled)
    settings.noSunRays = enabled
    pcall(function()
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("SunRaysEffect") then effect.Enabled = not enabled end
        end
    end)
end

local function setRainbowLighting(enabled)
    settings.rainbowLighting = enabled
    if not enabled then
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    end
end

local function setNoFog(enabled)
    settings.noFog = enabled
    if enabled then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
    end
end

--> [< ФУНКЦИИ АИМБОТА >] <--

local function closeScript()
    pcall(function()
        if fovCircle then
            fovCircle.Visible = false
            fovCircle:Remove()
        end
    end)
    pcall(function()
        if Window then Window:Destroy() end
    end)
    getgenv().UniversalAimbotLoaded = false
    print("✅ Скрипт закрыт")
end

local function getBestAimPart(character)
    if not character then return nil end
    
    if settings.aimPart and settings.aimPart ~= "Auto" then
        local part = character:FindFirstChild(settings.aimPart)
        if part and part:IsA("BasePart") then return part end
        
        if settings.aimPart == "Torso" then
            local ut = character:FindFirstChild("UpperTorso")
            if ut and ut:IsA("BasePart") then return ut end
            local lt = character:FindFirstChild("LowerTorso")
            if lt and lt:IsA("BasePart") then return lt end
        end
        
        local fallbacks = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}
        for _, name in ipairs(fallbacks) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then return part end
        end
        return nil
    end
    
    local cameraPos = Camera.CFrame.Position
    local bestPart, bestDistance = nil, math.huge
    
    for _, partName in ipairs(ALL_BODY_PARTS) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local dist = (part.Position - cameraPos).Magnitude
            if dist < bestDistance then
                bestDistance = dist
                bestPart = part
            end
        end
    end
    
    if not bestPart then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
                local dist = (child.Position - cameraPos).Magnitude
                if dist < bestDistance then
                    bestDistance = dist
                    bestPart = child
                end
            end
        end
    end
    
    return bestPart
end

local function isSameTeam(player)
    if not settings.teamCheck then return false end
    if not player.Team or not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function isVisible(targetCharacter)
    if not settings.wallCheck then return true end
    local targetPart = getBestAimPart(targetCharacter)
    if not targetPart then return false end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * 500
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = Workspace:Raycast(origin, direction, params)
    return not result or result.Instance:IsDescendantOf(targetCharacter)
end

local function getTarget()
    local bestTarget, bestScore = nil, math.huge
    local cameraPos = Camera.CFrame.Position
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if isSameTeam(player) then continue end
        
        local character = player.Character
        if not character then continue end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if settings.healthCheck and humanoid.Health < settings.minHealth then continue end
        
        local targetPart = getBestAimPart(character)
        if not targetPart then continue end
        
        if settings.maxDistance > 0 then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart and (rootPart.Position - cameraPos).Magnitude > settings.maxDistance then
                continue
            end
        end
        
        if not isVisible(character) then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        local cursorDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if cursorDist > settings.fov then continue end
        
        local distance = (targetPart.Position - cameraPos).Magnitude
        local score = settings.prioritizeClose
            and ((distance * 0.7) + (cursorDist * 0.3))
            or ((cursorDist * 0.7) + (distance * 0.3))
        
        if score < bestScore then
            bestScore = score
            bestTarget = player
        end
    end
    
    return bestTarget
end

local function getPredictedPosition(player)
    if not player or not player.Character then return nil end
    local targetPart = getBestAimPart(player.Character)
    if not targetPart then return nil end
    
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return targetPart.Position end
    
    return targetPart.Position + (rootPart.Velocity * settings.prediction)
end

local function smoothAim(targetPosition)
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
    local lerpFactor = math.clamp(1 - settings.smoothing, 0.05, 1)
    Camera.CFrame = currentCFrame:Lerp(targetCFrame, lerpFactor)
end

local function aimAtTarget(player)
    if not player or not player.Character then return end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    local targetPos = getPredictedPosition(player)
    if targetPos then smoothAim(targetPos) end
end

--> [< СЕРВЕР ФУНКЦИИ >] <--

local function serverHop()
    Fluent:Notify({Title = "🔄 Server Hop", Content = "Поиск сервера...", Duration = 3})
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = game:HttpGet(url)
        local servers = HttpService:JSONDecode(response)
        local available = {}
        
        for _, s in ipairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(available, s.id)
            end
        end
        
        if #available > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, available[math.random(1, #available)], LocalPlayer)
        else
            Fluent:Notify({Title = "❌ Ошибка", Content = "Нет серверов", Duration = 3})
        end
    end)
end

local function rejoinServer()
    Fluent:Notify({Title = "🔁 Rejoin", Content = "Переподключение...", Duration = 3})
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

local function forceReconnect()
    Fluent:Notify({Title = "⚡ Force Reconnect", Content = "Переподключение...", Duration = 3})
    pcall(function()
        for i = 1, 3 do
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
            if ok then return end
            task.wait(1)
        end
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function rejoinGame()
    Fluent:Notify({Title = "🎮 Rejoin Game", Content = "Переподключение...", Duration = 3})
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

--> [< GUI >] <--

local Window = Fluent:CreateWindow({
    Title = "Universal Aimbot",
    SubTitle = "by Agreed 🥵",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Aimbot = Window:AddTab({ Title = "Aimbot 🎯", Icon = "crosshair" }),
    Visual = Window:AddTab({ Title = "Visual 👁️", Icon = "eye" }),
    Config = Window:AddTab({ Title = "Config ⚙️", Icon = "settings" }),
    Server = Window:AddTab({ Title = "Server 🌐", Icon = "globe" })
}

local Options = Fluent.Options

--> [< ВКЛАДКА AIMBOT >] <--

Tabs.Aimbot:AddToggle("AimbotEnabled", {
    Title = "Enable Aimbot",
    Description = "Включить аимбот",
    Default = false
}):OnChanged(function(Value)
    aimbotEnabled = Value
    if fovCircle then fovCircle.Visible = settings.showFovCircle and Value end
    if not Value then
        aiming = false
        currentTarget = nil
    end
end)

Tabs.Aimbot:AddButton({
    Title = "👁️ Hide Menu",
    Callback = function() Window:Toggle() end
})

Tabs.Aimbot:AddButton({
    Title = "🔴 Close Script",
    Callback = function() closeScript() end
})

Tabs.Aimbot:AddDropdown("ActivationKey", {
    Title = "Activation Key",
    Values = {"BackSlash (\\)", "LeftControl", "RightControl", "LeftShift", "RightShift", "F", "Q", "E", "R", "T"},
    Default = 1,
    Multi = false
}):OnChanged(function(Value)
    if Value == "BackSlash (\\)" then settings.key = "BackSlash"
    elseif Value == "LeftControl" then settings.key = "LeftControl"
    elseif Value == "RightControl" then settings.key = "RightControl"
    elseif Value == "LeftShift" then settings.key = "LeftShift"
    elseif Value == "RightShift" then settings.key = "RightShift"
    elseif Value == "F" then settings.key = "F"
    elseif Value == "Q" then settings.key = "Q"
    elseif Value == "E" then settings.key = "E"
    elseif Value == "R" then settings.key = "R"
    elseif Value == "T" then settings.key = "T"
    end
end)

Tabs.Aimbot:AddDropdown("AimPart", {
    Title = "Aim Part",
    Values = {
        "Auto (Best Available)", "Head", "HumanoidRootPart", "UpperTorso",
        "Torso", "LowerTorso", "LeftUpperArm", "RightUpperArm",
        "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg",
        "LeftLowerLeg", "RightLowerLeg", "LeftHand", "RightHand",
        "LeftFoot", "RightFoot"
    },
    Default = 1,
    Multi = false
}):OnChanged(function(Value)
    if Value == "Auto (Best Available)" then
        settings.aimPart = "Auto"
    else
        settings.aimPart = Value
    end
end)

Tabs.Aimbot:AddToggle("ToggleMode", {
    Title = "Toggle Mode",
    Default = false
}):OnChanged(function(Value) settings.aimMode = Value and "Toggle" or "Hold" end)

Tabs.Aimbot:AddSlider("FOVSize", {
    Title = "FOV Size",
    Default = 300,
    Min = 0,
    Max = 800,
    Rounding = 0
}):OnChanged(function(Value)
    settings.fov = Value
    if fovCircle then fovCircle.Radius = Value end
end)

Tabs.Aimbot:AddSlider("MaxDistance", {
    Title = "Max Distance",
    Default = 5000,
    Min = 0,
    Max = 5000,
    Rounding = 0
}):OnChanged(function(Value) settings.maxDistance = Value end)

Tabs.Aimbot:AddToggle("PrioritizeClose", {
    Title = "Prioritize Close Targets",
    Default = true
}):OnChanged(function(Value) settings.prioritizeClose = Value end)

Tabs.Aimbot:AddSlider("Smoothing", {
    Title = "Smoothing",
    Default = 15,
    Min = 0,
    Max = 100,
    Rounding = 0
}):OnChanged(function(Value) settings.smoothing = Value / 100 end)

Tabs.Aimbot:AddSlider("Prediction", {
    Title = "Prediction",
    Default = 6,
    Min = 0,
    Max = 30,
    Rounding = 0
}):OnChanged(function(Value) settings.prediction = Value / 100 end)

Tabs.Aimbot:AddToggle("WallCheck", {
    Title = "Wall Check",
    Default = false
}):OnChanged(function(Value) settings.wallCheck = Value end)

Tabs.Aimbot:AddToggle("StickyAim", {
    Title = "Sticky Aim",
    Default = false
}):OnChanged(function(Value) settings.stickyAim = Value end)

Tabs.Aimbot:AddToggle("TeamCheck", {
    Title = "Team Check",
    Default = false
}):OnChanged(function(Value) settings.teamCheck = Value end)

Tabs.Aimbot:AddToggle("HealthCheck", {
    Title = "Health Check",
    Default = false
}):OnChanged(function(Value) settings.healthCheck = Value end)

Tabs.Aimbot:AddSlider("MinHealth", {
    Title = "Min Health",
    Default = 0,
    Min = 0,
    Max = 100,
    Rounding = 0
}):OnChanged(function(Value) settings.minHealth = Value end)

--> [< ВКЛАДКА VISUAL >] <--

local VisualSection = Tabs.Visual:AddSection("World Visuals")

VisualSection:AddToggle("XRay", {Title = "X-Ray", Default = false}):OnChanged(function(Value) setXRay(Value) end)
VisualSection:AddToggle("FullBright", {Title = "Full Bright", Default = false}):OnChanged(function(Value) setFullBright(Value) end)
VisualSection:AddToggle("NightVision", {Title = "Night Vision", Default = false}):OnChanged(function(Value) setNightVision(Value) end)
VisualSection:AddToggle("NoShadows", {Title = "No Shadows", Default = false}):OnChanged(function(Value) setNoShadows(Value) end)
VisualSection:AddToggle("NoBloom", {Title = "No Bloom", Default = false}):OnChanged(function(Value) setNoBloom(Value) end)
VisualSection:AddToggle("NoSunRays", {Title = "No Sun Rays", Default = false}):OnChanged(function(Value) setNoSunRays(Value) end)
VisualSection:AddToggle("RainbowLighting", {Title = "Rainbow Lighting", Default = false}):OnChanged(function(Value) setRainbowLighting(Value) end)
VisualSection:AddToggle("NoFog", {Title = "No Fog", Default = false}):OnChanged(function(Value) setNoFog(Value) end)

VisualSection:AddButton({
    Title = "🔄 Reset Visual Effects",
    Callback = function()
        setXRay(false); setFullBright(false); setNightVision(false)
        setNoShadows(false); setNoBloom(false); setNoSunRays(false)
        setRainbowLighting(false); setNoFog(false)
        Fluent:Notify({Title = "🔄 Reset", Content = "Эффекты сброшены", Duration = 2})
    end
})

local FOVSection = Tabs.Visual:AddSection("FOV Circle")

FOVSection:AddToggle("ShowFOVCircle", {
    Title = "Show FOV Circle",
    Default = true
}):OnChanged(function(Value)
    settings.showFovCircle = Value
    if fovCircle then fovCircle.Visible = Value and aimbotEnabled end
end)

FOVSection:AddColorpicker("FOVColor", {
    Title = "FOV Color",
    Default = Color3.fromRGB(255, 0, 0)
}):OnChanged(function(Color)
    settings.fovColor = Color
    if fovCircle and not settings.rainbowFov then fovCircle.Color = Color end
end)

FOVSection:AddColorpicker("TargetedColor", {
    Title = "Targeted Color",
    Default = Color3.fromRGB(0, 255, 0)
}):OnChanged(function(Color) settings.targetedColor = Color end)

FOVSection:AddToggle("RainbowFOV", {
    Title = "Rainbow FOV",
    Default = false
}):OnChanged(function(Value) settings.rainbowFov = Value end)

--> [< ВКЛАДКА CONFIG (КАСТОМНАЯ) >] <--

local ConfigSection = Tabs.Config:AddSection("Configuration")

local configNameValue = "my_config"

ConfigSection:AddInput("ConfigName", {
    Title = "Название конфига",
    Description = "Введите название для сохранения",
    Default = "my_config",
    Placeholder = "my_config",
    Numeric = false,
    Finished = false,
    Callback = function(Value)
        configNameValue = Value
    end
})

local configList = getConfigList()

local configDropdown = ConfigSection:AddDropdown("ConfigSelect", {
    Title = "Выбрать конфиг",
    Values = configList,
    Default = 1,
    Multi = false
})

configDropdown:OnChanged(function(Value) end)

ConfigSection:AddButton({
    Title = "🔄 Обновить список",
    Callback = function()
        local list = getConfigList()
        configDropdown:SetValues(list)
        Fluent:Notify({Title = "🔄 Обновлено", Content = "Найдено: " .. tostring(#list), Duration = 2})
    end
})

ConfigSection:AddButton({
    Title = "💾 Сохранить конфиг",
    Callback = function()
        local name = configNameValue
        if not name or name == "" then
            name = "config_" .. os.time()
        end
        
        if saveConfig(name) then
            task.wait(0.3)
            configDropdown:SetValues(getConfigList())
        end
    end
})

ConfigSection:AddButton({
    Title = "📂 Загрузить выбранный",
    Callback = function()
        if configDropdown.Value then
            loadConfig(configDropdown.Value)
        end
    end
})

ConfigSection:AddButton({
    Title = "🗑️ Удалить выбранный",
    Callback = function()
        local sel = configDropdown.Value
        if sel and sel ~= "Нет конфигов" then
            if deleteConfig(sel) then
                task.wait(0.3)
                configDropdown:SetValues(getConfigList())
            end
        else
            Fluent:Notify({Title = "❌", Content = "Нечего удалять", Duration = 2})
        end
    end
})

ConfigSection:AddButton({
    Title = "📁 Где хранятся конфиги?",
    Callback = function()
        Fluent:Notify({Title = "📁 Папка", Content = "workspace/" .. CONFIGS_FOLDER, Duration = 6})
    end
})

local AutoExecSection = Tabs.Config:AddSection("Auto-Load")

local autoExecData = loadAutoExec()

local autoLoadToggle = AutoExecSection:AddToggle("AutoLoadToggle", {
    Title = "🚀 Auto-Load при запуске",
    Description = "Автоматически загружать конфиг при старте",
    Default = autoExecData.autoLoad or false
})

autoLoadToggle:OnChanged(function(Value)
    local currentConfig = configDropdown.Value or ""
    if currentConfig == "Нет конфигов" then currentConfig = "" end
    saveAutoExec(currentConfig, Value)
    Fluent:Notify({
        Title = Value and "✅ Включено" or "❌ Выключено",
        Content = "Auto-Load: " .. tostring(Value),
        Duration = 2
    })
end)

AutoExecSection:AddButton({
    Title = "📌 Сделать конфигом по умолчанию",
    Callback = function()
        local sel = configDropdown.Value
        if sel and sel ~= "Нет конфигов" then
            saveAutoExec(sel, autoLoadToggle.Value or false)
            Fluent:Notify({Title = "📌 Установлено", Content = sel .. " будет загружаться при старте", Duration = 3})
        else
            Fluent:Notify({Title = "❌", Content = "Выберите конфиг", Duration = 2})
        end
    end
})

--> [< ВКЛАДКА SERVER >] <--

local ServerSection = Tabs.Server:AddSection("Server Actions")

ServerSection:AddButton({
    Title = "🔄 Server Hop",
    Description = "Перейти на случайный сервер",
    Callback = function() serverHop() end
})

ServerSection:AddButton({
    Title = "🔁 Rejoin Server",
    Description = "Переподключиться к текущему серверу",
    Callback = function() rejoinServer() end
})

ServerSection:AddButton({
    Title = "⚡ Force Reconnect",
    Description = "Принудительное переподключение",
    Callback = function() forceReconnect() end
})

ServerSection:AddButton({
    Title = "🎮 Rejoin Game",
    Description = "Переподключиться к игре",
    Callback = function() rejoinGame() end
})

local InfoSection = Tabs.Server:AddSection("Server Info")

-- Пинг
local pingParagraph = InfoSection:AddParagraph({
    Title = "📶 Пинг",
    Content = "Загрузка..."
})

-- Регион
local regionParagraph = InfoSection:AddParagraph({
    Title = "🌍 Регион",
    Content = "Определение..."
})

-- Поток обновления
task.spawn(function()
    task.wait(1)
    
    while task.wait(0.5) do
        local ping = getPlayerPing()
        local color = "🟢"
        if ping > 100 then color = "🟡" end
        if ping > 200 then color = "🔴" end
        
        pcall(function()
            pingParagraph:SetDesc(string.format("%s %d ms", color, ping))
        end)
    end
end)

task.spawn(function()
    task.wait(2)
    
    while task.wait(5) do
        local region = getServerRegion()
        pcall(function()
            regionParagraph:SetDesc("🌍 " .. region)
        end)
    end
end)

InfoSection:AddButton({
    Title = "📋 Информация о сервере",
    Callback = function()
        Fluent:Notify({
            Title = "📊 Сервер",
            Content = "Place ID: " .. game.PlaceId .. 
                      "\nJob ID: " .. string.sub(game.JobId, 1, 20) .. "..." ..
                      "\nИгроков: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers ..
                      "\nПинг: " .. getPlayerPing() .. " ms" ..
                      "\nРегион: " .. getServerRegion(),
            Duration = 8
        })
    end
})

InfoSection:AddButton({
    Title = "📋 Скопировать Job ID",
    Callback = function()
        setclipboard(game.JobId)
        Fluent:Notify({Title = "✅", Content = "Job ID скопирован", Duration = 2})
    end
})

InfoSection:AddButton({
    Title = "👥 Список игроков",
    Callback = function()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(list, p.Name) end
        end
        
        local text = #list > 0 and table.concat(list, ", ") or "Нет игроков"
        if #text > 200 then text = string.sub(text, 1, 200) .. "..." end
        
        Fluent:Notify({Title = "👥 Игроки (" .. #list .. ")", Content = text, Duration = 8})
    end
})

--> [< ОБРАБОТКА КЛАВИШ >] <--

local function getKeyCode(keyName)
    local map = {
        BackSlash = Enum.KeyCode.BackSlash,
        LeftControl = Enum.KeyCode.LeftControl,
        RightControl = Enum.KeyCode.RightControl,
        LeftShift = Enum.KeyCode.LeftShift,
        RightShift = Enum.KeyCode.RightShift,
        F = Enum.KeyCode.F, Q = Enum.KeyCode.Q, E = Enum.KeyCode.E,
        R = Enum.KeyCode.R, T = Enum.KeyCode.T
    }
    return map[keyName]
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not aimbotEnabled then return end
    
    local keyEnum = getKeyCode(settings.key)
    if keyEnum and input.KeyCode == keyEnum then
        if settings.aimMode == "Hold" then
            aiming = true
        elseif settings.aimMode == "Toggle" then
            aiming = not aiming
            if not aiming then currentTarget = nil end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or not aimbotEnabled then return end
    local keyEnum = getKeyCode(settings.key)
    if keyEnum and input.KeyCode == keyEnum and settings.aimMode == "Hold" then
        aiming = false
        currentTarget = nil
    end
end)

--> [< ГЛАВНЫЙ ЦИКЛ >] <--

RunService.RenderStepped:Connect(function()
    if settings.rainbowLighting then
        lightingHue = (lightingHue + 0.005) % 1
        local c = Color3.fromHSV(lightingHue, 1, 1)
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    end
    
    if not aimbotEnabled then
        if fovCircle then fovCircle.Visible = false end
        return
    end
    
    if fovCircle and settings.showFovCircle then
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        fovCircle.Visible = true
        
        if settings.rainbowFov then
            hue = (hue + rainbowSpeed) % 1
            fovCircle.Color = Color3.fromHSV(hue, 1, 1)
        elseif aiming and currentTarget then
            fovCircle.Color = settings.targetedColor
        else
            fovCircle.Color = settings.fovColor
        end
    elseif fovCircle then
        fovCircle.Visible = false
    end
    
    if aiming then
        local t = tick()
        
        if settings.stickyAim and currentTarget then
            local character = currentTarget.Character
            if character then
                local targetPart = getBestAimPart(character)
                if targetPart then
                    local sp = Camera:WorldToViewportPoint(targetPart.Position)
                    local dist = (Vector2.new(sp.X, sp.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                    if dist > settings.fov * 1.5 or not isVisible(character) then
                        currentTarget = nil
                    end
                else
                    currentTarget = nil
                end
            else
                currentTarget = nil
            end
        end
        
        if (not settings.stickyAim or not currentTarget) and (t - lastTargetUpdate > targetUpdateInterval) then
            lastTargetUpdate = t
            currentTarget = getTarget()
        end
        
        if currentTarget then aimAtTarget(currentTarget) end
    else
        currentTarget = nil
    end
end)

--> [< АВТОЗАГРУЗКА >] <--

if autoExecData and autoExecData.autoLoad and autoExecData.lastConfig and autoExecData.lastConfig ~= "" then
    task.wait(0.5)
    local ok = loadConfig(autoExecData.lastConfig)
    if ok then
        print("🚀 Auto-Load: " .. autoExecData.lastConfig)
    end
end

--> [< ОТКРЫТИЕ SERVER TAB >] <--

task.spawn(function()
    task.wait(0.8)
    pcall(function()
        Window:SelectTab(Tabs.Server)
    end)
end)

print("====================================")
print("✅ Universal Aimbot (Fluent) загружен!")
print("📁 Конфиги: workspace/" .. CONFIGS_FOLDER)
print("📶 Пинг через Player:GetNetworkPing()")
print("🌍 Регион через LocalizationService")
print("📌 RightControl - скрыть меню")
print("📌 \\ - активация аимбота")
print("====================================")
