--[[
    Universal Aimbot v2.0
    GitHub: https://github.com/ВАШ_ЮЗЕРНЕЙМ/universal-aimbot
    Описание: Универсальный аимбот с ESP, визуальными эффектами, системой конфигов и server hop
]]

-- Проверка на повторную загрузку
if getgenv().UniversalAimbotLoaded then
    print("⚠️ Universal Aimbot уже загружен!")
    return
end
getgenv().UniversalAimbotLoaded = true

-- Загрузка Rayfield
local Rayfield
local success, err = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    success, err = pcall(function()
        Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua'))()
    end)
end

if not success or not Rayfield then
    getgenv().UniversalAimbotLoaded = false
    error("❌ Не удалось загрузить Rayfield!")
end

-- Сервисы
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local plr = players.LocalPlayer
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local mouse = plr:GetMouse()
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

--> [< ПАПКИ КОНФИГОВ >] <--

local CONFIG_FOLDER = "UniversalAimbot"
local CONFIGS_FOLDER = "UniversalAimbot/Configs"
local AUTOEXEC_FILE = "UniversalAimbot/autoexec.json"

local function ensureFolders()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        if not isfolder(CONFIGS_FOLDER) then
            makefolder(CONFIGS_FOLDER)
        end
    end)
end

ensureFolders()

--> [< НАСТРОЙКИ >] <--

local settings = {
    -- Aimbot
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
    
    -- Visual
    xray = false,
    fullBright = false,
    nightVision = false,
    noShadows = false,
    noBloom = false,
    noSunRays = false,
    rainbowLighting = false,
    noFog = false
}

-- Оригинальные значения Lighting
local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows
}

-- Переменные
local aimbotEnabled = false
local aiming = false
local currentTarget = nil
local menuVisible = true
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

-- FOV круг
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

--> [< ВИЗУАЛЬНЫЕ ФУНКЦИИ >] <--

local function setXRay(enabled)
    settings.xray = enabled
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
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
            if effect:IsA("BloomEffect") then
                effect.Enabled = not enabled
            end
        end
    end)
end

local function setNoSunRays(enabled)
    settings.noSunRays = enabled
    pcall(function()
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("SunRaysEffect") then
                effect.Enabled = not enabled
            end
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
    
    if fovCircle then
        fovCircle.Radius = settings.fov
    end
    
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
        Rayfield:Notify({Title = "❌ Ошибка", Content = "Введите название конфига", Duration = 3})
        return false
    end
    
    name = tostring(name):gsub("[^%w_%-%. ]", "")
    if name == "" then
        Rayfield:Notify({Title = "❌ Ошибка", Content = "Недопустимое название", Duration = 3})
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
        Rayfield:Notify({Title = "💾 Конфиг сохранён", Content = name .. ".json", Duration = 3})
        print("✅ Сохранён: " .. result)
        return true
    else
        Rayfield:Notify({Title = "❌ Ошибка", Content = tostring(result), Duration = 4})
        return false
    end
end

local function loadConfig(name)
    if not name or name == "" or name == "Нет конфигов" then
        Rayfield:Notify({Title = "❌ Ошибка", Content = "Выберите конфиг", Duration = 3})
        return false
    end
    
    local success, result = pcall(function()
        local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
        if not isfile(path) then
            error("Файл не найден")
        end
        
        local json = readfile(path)
        local data = HttpService:JSONDecode(json)
        applySettings(data)
        return name
    end)
    
    if success then
        Rayfield:Notify({Title = "📂 Загружено", Content = "Конфиг: " .. result, Duration = 3})
        print("✅ Загружен: " .. result)
        return true
    else
        Rayfield:Notify({Title = "❌ Ошибка", Content = tostring(result), Duration = 4})
        return false
    end
end

local function deleteConfig(name)
    if not name or name == "" or name == "Нет конфигов" then return false end
    
    local success = pcall(function()
        local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
        if isfile(path) then
            delfile(path)
        end
    end)
    
    if success then
        Rayfield:Notify({Title = "🗑️ Удалён", Content = name, Duration = 2})
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
            if name then
                table.insert(configs, name)
            end
        end
    end)
    if #configs == 0 then
        table.insert(configs, "Нет конфигов")
    end
    return configs
end

--> [< AUTOEXEC >] <--

local function saveAutoExec(configName, autoLoad)
    pcall(function()
        ensureFolders()
        local data = {
            lastConfig = configName or "",
            autoLoad = autoLoad or false
        }
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
    error("Script closed")
end

local function toggleMenu()
    menuVisible = not menuVisible
    if menuVisible then Window:Show() else Window:Hide() end
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
    
    local cameraPos = camera.CFrame.Position
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
    if not player.Team or not plr.Team then return false end
    return player.Team == plr.Team
end

local function isVisible(targetCharacter)
    if not settings.wallCheck then return true end
    local targetPart = getBestAimPart(targetCharacter)
    if not targetPart then return false end
    
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * 500
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {plr.Character, targetCharacter}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = workspace:Raycast(origin, direction, params)
    return not result or result.Instance:IsDescendantOf(targetCharacter)
end

local function getTarget()
    local bestTarget, bestScore = nil, math.huge
    local cameraPos = camera.CFrame.Position
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    
    for _, player in ipairs(players:GetPlayers()) do
        if player == plr then continue end
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
        
        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
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
    local currentCFrame = camera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
    local lerpFactor = math.clamp(1 - settings.smoothing, 0.05, 1)
    camera.CFrame = currentCFrame:Lerp(targetCFrame, lerpFactor)
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
    Rayfield:Notify({Title = "🔄 Server Hop", Content = "Поиск сервера...", Duration = 3})
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
            TeleportService:TeleportToPlaceInstance(game.PlaceId, available[math.random(1, #available)], plr)
        else
            Rayfield:Notify({Title = "❌", Content = "Нет серверов", Duration = 3})
        end
    end)
end

local function rejoinServer()
    Rayfield:Notify({Title = "🔁 Rejoin", Content = "Переподключение...", Duration = 3})
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, plr)
    end)
end

local function forceReconnect()
    Rayfield:Notify({Title = "⚡ Force Reconnect", Content = "Переподключение...", Duration = 3})
    pcall(function()
        for i = 1, 3 do
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, plr)
            end)
            if ok then return end
            task.wait(1)
        end
        TeleportService:Teleport(game.PlaceId, plr)
    end)
end

local function rejoinGame()
    Rayfield:Notify({Title = "🎮 Rejoin Game", Content = "Переподключение...", Duration = 3})
    pcall(function()
        TeleportService:Teleport(game.PlaceId, plr)
    end)
end

--> [< GUI >] <--

local Window = Rayfield:CreateWindow({
    Name = "▶ Universal Aimbot ◀",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Agreed 🥵",
    ConfigurationSaving = {Enabled = false},
})

Window.OnClose = function() closeScript() end

local AimbotTab = Window:CreateTab("Aimbot 🎯")
local VisualTab = Window:CreateTab("Visual 👁️")
local ConfigTab = Window:CreateTab("Config ⚙️")
local ServerTab = Window:CreateTab("Server 🌐")

--> [< ВКЛАДКА AIMBOT >] <--

AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Callback = function(Value)
        aimbotEnabled = Value
        if fovCircle then
            fovCircle.Visible = settings.showFovCircle and Value
        end
        if not Value then
            aiming = false
            currentTarget = nil
        end
    end
})

AimbotTab:CreateButton({Name = "👁️ Hide Menu", Callback = function() toggleMenu() end})
AimbotTab:CreateButton({Name = "🔴 Close Script", Callback = function() closeScript() end})

AimbotTab:CreateDropdown({
    Name = "Activation Key",
    Options = {"BackSlash (\\)", "LeftControl", "RightControl", "LeftShift", "RightShift", "F", "Q", "E", "R", "T"},
    CurrentOption = "BackSlash (\\)",
    Flag = "ActKey",
    Callback = function(Option)
        if not Option then return end
        if type(Option) == "table" then Option = Option[1] end
        Option = tostring(Option)
        
        if Option == "BackSlash (\\)" then settings.key = "BackSlash"
        elseif Option == "LeftControl" then settings.key = "LeftControl"
        elseif Option == "RightControl" then settings.key = "RightControl"
        elseif Option == "LeftShift" then settings.key = "LeftShift"
        elseif Option == "RightShift" then settings.key = "RightShift"
        elseif Option == "F" then settings.key = "F"
        elseif Option == "Q" then settings.key = "Q"
        elseif Option == "E" then settings.key = "E"
        elseif Option == "R" then settings.key = "R"
        elseif Option == "T" then settings.key = "T"
        end
    end
})

AimbotTab:CreateDropdown({
    Name = "Aim Part",
    Options = {
        "Auto (Best Available)", "Head", "HumanoidRootPart", "UpperTorso",
        "Torso", "LowerTorso", "LeftUpperArm", "RightUpperArm",
        "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg",
        "LeftLowerLeg", "RightLowerLeg", "LeftHand", "RightHand",
        "LeftFoot", "RightFoot"
    },
    CurrentOption = "Auto (Best Available)",
    Flag = "AimPart",
    Callback = function(Option)
        if not Option then return end
        if type(Option) == "table" then Option = Option[1] or "Auto (Best Available)" end
        Option = tostring(Option):gsub("^%s*(.-)%s*$", "%1")
        
        if Option == "Auto (Best Available)" then
            settings.aimPart = "Auto"
        else
            settings.aimPart = Option
        end
    end
})

AimbotTab:CreateToggle({Name = "Toggle Mode", CurrentValue = false, Callback = function(Value) settings.aimMode = Value and "Toggle" or "Hold" end})
AimbotTab:CreateSlider({Name = "FOV Size", Range = {0, 800}, Increment = 1, CurrentValue = 300, Callback = function(Value) settings.fov = Value; if fovCircle then fovCircle.Radius = Value end end})
AimbotTab:CreateSlider({Name = "Max Distance", Range = {0, 5000}, Increment = 10, CurrentValue = 5000, Callback = function(Value) settings.maxDistance = Value end})
AimbotTab:CreateToggle({Name = "Prioritize Close", CurrentValue = true, Callback = function(Value) settings.prioritizeClose = Value end})
AimbotTab:CreateSlider({Name = "Smoothing", Range = {0, 100}, Increment = 1, CurrentValue = 15, Callback = function(Value) settings.smoothing = Value / 100 end})
AimbotTab:CreateSlider({Name = "Prediction", Range = {0, 30}, Increment = 1, CurrentValue = 6, Callback = function(Value) settings.prediction = Value / 100 end})
AimbotTab:CreateToggle({Name = "Wall Check", CurrentValue = false, Callback = function(Value) settings.wallCheck = Value end})
AimbotTab:CreateToggle({Name = "Sticky Aim", CurrentValue = false, Callback = function(Value) settings.stickyAim = Value end})
AimbotTab:CreateToggle({Name = "Team Check", CurrentValue = false, Callback = function(Value) settings.teamCheck = Value end})
AimbotTab:CreateToggle({Name = "Health Check", CurrentValue = false, Callback = function(Value) settings.healthCheck = Value end})
AimbotTab:CreateSlider({Name = "Min Health", Range = {0, 100}, Increment = 1, CurrentValue = 0, Callback = function(Value) settings.minHealth = Value end})

--> [< ВКЛАДКА VISUAL >] <--

VisualTab:CreateToggle({Name = "X-Ray", CurrentValue = false, Callback = function(Value) setXRay(Value) end})
VisualTab:CreateToggle({Name = "Full Bright", CurrentValue = false, Callback = function(Value) setFullBright(Value) end})
VisualTab:CreateToggle({Name = "Night Vision", CurrentValue = false, Callback = function(Value) setNightVision(Value) end})
VisualTab:CreateToggle({Name = "No Shadows", CurrentValue = false, Callback = function(Value) setNoShadows(Value) end})
VisualTab:CreateToggle({Name = "No Bloom", CurrentValue = false, Callback = function(Value) setNoBloom(Value) end})
VisualTab:CreateToggle({Name = "No Sun Rays", CurrentValue = false, Callback = function(Value) setNoSunRays(Value) end})
VisualTab:CreateToggle({Name = "Rainbow Lighting", CurrentValue = false, Callback = function(Value) setRainbowLighting(Value) end})
VisualTab:CreateToggle({Name = "No Fog", CurrentValue = false, Callback = function(Value) setNoFog(Value) end})

VisualTab:CreateButton({
    Name = "🔄 Reset Visual Effects",
    Callback = function()
        setXRay(false)
        setFullBright(false)
        setNightVision(false)
        setNoShadows(false)
        setNoBloom(false)
        setNoSunRays(false)
        setRainbowLighting(false)
        setNoFog(false)
        Rayfield:Notify({Title = "🔄 Reset", Content = "Эффекты сброшены", Duration = 2})
    end
})

VisualTab:CreateToggle({Name = "Show FOV Circle", CurrentValue = true, Callback = function(Value)
    settings.showFovCircle = Value
    if fovCircle then fovCircle.Visible = Value and aimbotEnabled end
end})

VisualTab:CreateColorPicker({Name = "FOV Color", Color = settings.fovColor, Callback = function(Color)
    settings.fovColor = Color
    if fovCircle and not settings.rainbowFov then fovCircle.Color = Color end
end})

VisualTab:CreateColorPicker({Name = "Targeted Color", Color = settings.targetedColor, Callback = function(Color) settings.targetedColor = Color end})
VisualTab:CreateToggle({Name = "Rainbow FOV", CurrentValue = false, Callback = function(Value) settings.rainbowFov = Value end})

--> [< ВКЛАДКА CONFIG >] <--

local configNameInput = ConfigTab:CreateInput({
    Name = "Название конфига",
    CurrentValue = "my_config",
    PlaceholderText = "Введите название...",
    RemoveTextAfterFocusLost = false,
    Flag = "ConfigName"
})

local configDropdown
configDropdown = ConfigTab:CreateDropdown({
    Name = "Выбрать конфиг",
    Options = getConfigList(),
    CurrentOption = "Нет конфигов",
    Flag = "ConfigSelect",
    Callback = function(Option)
        if type(Option) == "table" then Option = Option[1] end
    end
})

ConfigTab:CreateButton({
    Name = "🔄 Обновить список",
    Callback = function()
        local list = getConfigList()
        configDropdown:Refresh(list, list[1])
        Rayfield:Notify({Title = "🔄", Content = "Найдено: " .. tostring(#list), Duration = 2})
    end
})

ConfigTab:CreateButton({
    Name = "💾 Сохранить конфиг",
    Callback = function()
        local name = configNameInput.Value
        if not name or name == "" then
            name = "config_" .. os.time()
        end
        
        if saveConfig(name) then
            task.wait(0.3)
            local list = getConfigList()
            configDropdown:Refresh(list, list[1])
        end
    end
})

ConfigTab:CreateButton({
    Name = "📂 Загрузить выбранный",
    Callback = function()
        local sel = configDropdown.Value
        if type(sel) == "table" then sel = sel[1] end
        loadConfig(sel)
    end
})

ConfigTab:CreateButton({
    Name = "🗑️ Удалить выбранный",
    Callback = function()
        local sel = configDropdown.Value
        if type(sel) == "table" then sel = sel[1] end
        
        if sel == "Нет конфигов" then
            Rayfield:Notify({Title = "❌", Content = "Нечего удалять", Duration = 2})
            return
        end
        
        if deleteConfig(sel) then
            task.wait(0.3)
            local list = getConfigList()
            configDropdown:Refresh(list, list[1])
        end
    end
})

local autoExecData = loadAutoExec()

local autoLoadToggle = ConfigTab:CreateToggle({
    Name = "🚀 Auto-Load при запуске",
    CurrentValue = autoExecData.autoLoad or false,
    Flag = "AutoLoadToggle",
    Callback = function(Value)
        local currentConfig = configDropdown.Value
        if type(currentConfig) == "table" then currentConfig = currentConfig[1] end
        saveAutoExec(currentConfig, Value)
        Rayfield:Notify({
            Title = Value and "✅ Включено" or "❌ Выключено",
            Content = "Auto-Load: " .. tostring(Value),
            Duration = 2
        })
    end
})

ConfigTab:CreateButton({
    Name = "📌 Сделать конфигом по умолчанию",
    Callback = function()
        local sel = configDropdown.Value
        if type(sel) == "table" then sel = sel[1] end
        
        if sel == "Нет конфигов" then
            Rayfield:Notify({Title = "❌", Content = "Выберите конфиг", Duration = 2})
            return
        end
        
        saveAutoExec(sel, autoLoadToggle.Value)
        Rayfield:Notify({
            Title = "📌 Установлено",
            Content = sel .. " будет загружаться при старте",
            Duration = 3
        })
    end
})

ConfigTab:CreateButton({
    Name = "📁 Где хранятся конфиги?",
    Callback = function()
        Rayfield:Notify({
            Title = "📁 Папка конфигов",
            Content = "workspace/" .. CONFIGS_FOLDER,
            Duration = 6
        })
        print("📁 Конфиги: workspace/" .. CONFIGS_FOLDER)
    end
})

--> [< ВКЛАДКА SERVER >] <--

ServerTab:CreateButton({Name = "🔄 Server Hop", Callback = function() serverHop() end})
ServerTab:CreateButton({Name = "🔁 Rejoin Server", Callback = function() rejoinServer() end})
ServerTab:CreateButton({Name = "⚡ Force Reconnect", Callback = function() forceReconnect() end})
ServerTab:CreateButton({Name = "🎮 Rejoin Game", Callback = function() rejoinGame() end})

ServerTab:CreateButton({
    Name = "📋 Информация о сервере",
    Callback = function()
        Rayfield:Notify({
            Title = "📊 Сервер",
            Content = "Place ID: " .. game.PlaceId .. "\nJob ID: " .. string.sub(game.JobId, 1, 20) .. "...\nИгроков: " .. #players:GetPlayers() .. "/" .. players.MaxPlayers,
            Duration = 8
        })
    end
})

ServerTab:CreateButton({
    Name = "📋 Скопировать Job ID",
    Callback = function()
        setclipboard(game.JobId)
        Rayfield:Notify({Title = "✅", Content = "Job ID скопирован", Duration = 2})
    end
})

ServerTab:CreateButton({
    Name = "👥 Список игроков",
    Callback = function()
        local list = {}
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= plr then table.insert(list, p.Name) end
        end
        
        local text = #list > 0 and table.concat(list, ", ") or "Нет игроков"
        if #text > 200 then text = string.sub(text, 1, 200) .. "..." end
        
        Rayfield:Notify({Title = "👥 Игроки (" .. #list .. ")", Content = text, Duration = 8})
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
    if input.KeyCode == Enum.KeyCode.RightControl then toggleMenu() end
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
        fovCircle.Position = Vector2.new(mouse.X, mouse.Y + 50)
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
                    local sp = camera:WorldToViewportPoint(targetPart.Position)
                    local dist = (Vector2.new(sp.X, sp.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
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

print("====================================")
print("✅ Universal Aimbot загружен!")
print("📁 Конфиги: workspace/" .. CONFIGS_FOLDER)
print("📌 RightControl - скрыть меню")
print("📌 \\ - активация аимбота")
print("====================================")A
