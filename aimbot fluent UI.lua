--[[
    Universal Aimbot + Shindo Life Cheat v4.0
    Функции: Aimbot, Silent Aim, ESP (с CHI/STAM), Colors, Visual, Server
]]

if getgenv().UniversalShindoLoaded then
    print("⚠️ Уже загружен!")
    return
end
getgenv().UniversalShindoLoaded = true

-- Загрузка Fluent UI + Addons
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

if not Fluent then
    warn("❌ Fluent UI не загружен!")
    getgenv().UniversalShindoLoaded = false
    return
end

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

-- Событие Shindo Life
local shindoEvent
pcall(function()
    shindoEvent = LocalPlayer:WaitForChild("startevent", 8)
end)

--> [< НАСТРОЙКИ >] <--

local settings = {
    -- Aimbot
    fov = 300,
    smoothing = 0.15,
    prediction = 0.065,
    wallCheck = false,
    stickyAim = false,
    teamCheck = false,
    minHealth = 0,
    aimPart = "Auto",
    aimMode = "Hold",
    key = "BackSlash",
    showFovCircle = true,
    maxDistance = 5000,
    prioritizeClose = true,
    fovColor = Color3.fromRGB(255, 0, 0),
    targetedColor = Color3.fromRGB(0, 255, 0),
    rainbowFov = false,
    
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

-- Silent Aim
local silentAim = {
    Enabled = false,
    FOV = 150,
    Prediction = 0.15,
    HitChance = 100,
    TeamCheck = false,
    Target = nil,
    CFrame = nil
}

-- ESP
local esp = {
    Enabled = false,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    ShowChi = true,
    ShowStamina = true,
    TextColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    DistanceColor = Color3.fromRGB(255, 255, 0),
    ChiColor = Color3.fromRGB(100, 150, 255),
    StamColor = Color3.fromRGB(255, 200, 50),
    TextSize = 14,
    UpdateRate = 0.1,
    Objects = {},
    LastUpdate = 0
}

-- Colors
local colors = {
    RainbowSkin = false,
    RainbowHair = false,
    SkinSpeed = 0.5,
    HairSpeed = 0.5
}
local skinTimer, hairTimer = 0, 0

local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows
}

local aimbotEnabled, aiming, currentTarget = false, false, nil
local lastTargetUpdate = 0
local targetUpdateInterval = 0.05
local hue = 0
local rainbowSpeed = 0.005
local lightingHue = 0

local ALL_BODY_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot"
}

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

--> [< ПИНГ И РЕГИОН >] <--

local function getPlayerPing()
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    return ok and ping and math.floor(ping * 1000) or 0
end

local function getServerRegion()
    local ok, region = pcall(function()
        local first = Players:GetPlayers()[1] or LocalPlayer
        return LocalizationService:GetCountryRegionForPlayerAsync(first)
    end)
    return ok and region and tostring(region) or "Unknown"
end

--> [< ВИЗУАЛЬНЫЕ ФУНКЦИИ >] <--

local function setXRay(v)
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

local function setFullBright(v)
    settings.fullBright = v
    if v then
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

local function setNightVision(v)
    settings.nightVision = v
    pcall(function()
        local nv = Lighting:FindFirstChild("NVEffect")
        if v then
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
        elseif nv then
            nv.Enabled = false
        end
    end)
end

local function setNoShadows(v)
    settings.noShadows = v
    Lighting.GlobalShadows = not v
end

local function setNoBloom(v)
    settings.noBloom = v
    pcall(function()
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") then e.Enabled = not v end
        end
    end)
end

local function setNoSunRays(v)
    settings.noSunRays = v
    pcall(function()
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("SunRaysEffect") then e.Enabled = not v end
        end
    end)
end

local function setRainbowLighting(v)
    settings.rainbowLighting = v
    if not v then
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    end
end

local function setNoFog(v)
    settings.noFog = v
    if v then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
    end
end

--> [< SILENT AIM (ИСПРАВЛЕН) >] <--

local silentHook = false
local oldNamecall = nil
local metaT = nil

local function findSilentTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local bestPart, bestDist = nil, silentAim.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if silentAim.TeamCheck and p.Team == LocalPlayer.Team then continue end
        
        local char = p.Character
        if not char then continue end
        
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not head or not hum or hum.Health <= 0 then continue end
        
        local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then continue end
        
        local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
        if d < bestDist then
            bestPart = head
            bestDist = d
        end
    end
    return bestPart
end

-- Обновляем цель и CFrame
RunService.Heartbeat:Connect(function()
    if not silentAim.Enabled then
        silentAim.Target = nil
        silentAim.CFrame = nil
        return
    end
    
    silentAim.Target = findSilentTarget()
    if silentAim.Target and silentAim.Target.Parent then
        -- ✅ ИСПРАВЛЕНО: CFrame смотрит НА цель ИЗ камеры
        local targetPos = silentAim.Target.Position + (silentAim.Target.Velocity * silentAim.Prediction)
        local camPos = Camera.CFrame.Position
        
        -- CFrame, позиционированный на камере, но направленный на цель
        local direction = (targetPos - camPos)
        if direction.Magnitude > 0.1 then
            silentAim.CFrame = CFrame.new(camPos, camPos + direction.Unit)
        end
    end
end)

local function enableSilentHook()
    if silentHook then return end
    local ok, err = pcall(function()
        metaT = getrawmetatable(game)
        oldNamecall = metaT.__namecall
        setreadonly(metaT, false)
        
        metaT.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Перехватываем "update" FireServer с fixmouse
            if method == "FireServer" and self.Name == "update" then
                if args[1] == "fixmouse" and silentAim.Enabled and silentAim.CFrame then
                    if math.random(1, 100) <= silentAim.HitChance then
                        args[2] = silentAim.CFrame
                    end
                end
            end
            
            return oldNamecall(self, unpack(args))
        end)
        
        setreadonly(metaT, true)
        silentHook = true
        print("✅ Silent Aim хук установлен")
    end)
    if not ok then warn("❌ Silent Aim: " .. tostring(err)) end
end

local function disableSilentHook()
    if metaT and oldNamecall then
        pcall(function()
            setreadonly(metaT, false)
            metaT.__namecall = oldNamecall
            setreadonly(metaT, true)
        end)
    end
    silentHook = false
end

--> [< ESP С CHI/STAM >] <--

-- Получение значений CHI и Stamina из игры
local function getPlayerStats(player)
    local chi, stam, maxChi, maxStam = 0, 0, 0, 0
    
    -- Пробуем разные пути
    pcall(function()
        local statz = player:FindFirstChild("statz")
        if statz then
            local chiV = statz:FindFirstChild("chakra") or statz:FindFirstChild("chi")
            if chiV then chi = math.floor(chiV.Value or 0) end
            
            local stamV = statz:FindFirstChild("stamina")
            if stamV then stam = math.floor(stamV.Value or 0) end
            
            local maxChiV = statz:FindFirstChild("maxchakra") or statz:FindFirstChild("maxchi")
            if maxChiV then maxChi = math.floor(maxChiV.Value or 0) end
            
            local maxStamV = statz:FindFirstChild("maxstamina")
            if maxStamV then maxStam = math.floor(maxStamV.Value or 0) end
        end
    end)
    
    -- Альтернативный путь - через персонажа
    if chi == 0 then
        pcall(function()
            local char = player.Character
            if char then
                local chiV = char:FindFirstChild("chakra") or char:FindFirstChild("chi")
                if chiV then chi = math.floor(chiV.Value or 0) end
                
                local stamV = char:FindFirstChild("stamina")
                if stamV then stam = math.floor(stamV.Value or 0) end
            end
        end)
    end
    
    return chi, stam, maxChi, maxStam
end

local function createESP(player)
    if player == LocalPlayer or esp.Objects[player] then return end
    if not player.Character then return end
    
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    
    local gui = Instance.new("BillboardGui")
    gui.Name = "ShindoESP"
    gui.Size = UDim2.new(0, 220, 0, 95)
    gui.StudsOffset = Vector3.new(0, 4, 0)
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.Adornee = head
    gui.Parent = player.Character
    
    local nameLabel = Instance.new("TextLabel", gui)
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = esp.TextColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = esp.TextSize
    
    local hpLabel = Instance.new("TextLabel", gui)
    hpLabel.Name = "HP"
    hpLabel.Size = UDim2.new(1, 0, 0, 18)
    hpLabel.Position = UDim2.new(0, 0, 0, 20)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = esp.HealthColor
    hpLabel.TextStrokeTransparency = 0
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.TextSize = esp.TextSize
    
    local chiLabel = Instance.new("TextLabel", gui)
    chiLabel.Name = "CHI"
    chiLabel.Size = UDim2.new(1, 0, 0, 18)
    chiLabel.Position = UDim2.new(0, 0, 0, 38)
    chiLabel.BackgroundTransparency = 1
    chiLabel.TextColor3 = esp.ChiColor
    chiLabel.TextStrokeTransparency = 0
    chiLabel.Font = Enum.Font.GothamBold
    chiLabel.TextSize = esp.TextSize
    
    local stamLabel = Instance.new("TextLabel", gui)
    stamLabel.Name = "STAM"
    stamLabel.Size = UDim2.new(1, 0, 0, 18)
    stamLabel.Position = UDim2.new(0, 0, 0, 56)
    stamLabel.BackgroundTransparency = 1
    stamLabel.TextColor3 = esp.StamColor
    stamLabel.TextStrokeTransparency = 0
    stamLabel.Font = Enum.Font.GothamBold
    stamLabel.TextSize = esp.TextSize
    
    local distLabel = Instance.new("TextLabel", gui)
    distLabel.Name = "DIST"
    distLabel.Size = UDim2.new(1, 0, 0, 18)
    distLabel.Position = UDim2.new(0, 0, 0, 74)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = esp.DistanceColor
    distLabel.TextStrokeTransparency = 0
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = esp.TextSize
    
    esp.Objects[player] = {
        gui = gui,
        name = nameLabel,
        hp = hpLabel,
        chi = chiLabel,
        stam = stamLabel,
        dist = distLabel,
        char = player.Character
    }
end

local function removeESP(player)
    local o = esp.Objects[player]
    if o and o.gui then o.gui:Destroy() end
    esp.Objects[player] = nil
end

local function updateESP()
    for player, obj in pairs(esp.Objects) do
        if not player.Parent or not player.Character then
            removeESP(player)
            continue
        end
        
        if obj.char ~= player.Character then
            removeESP(player)
            if esp.Enabled then createESP(player) end
            continue
        end
        
        local head = player.Character:FindFirstChild("Head")
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        
        if not head or not hum or hum.Health <= 0 then
            if obj.gui then obj.gui.Enabled = false end
            continue
        end
        
        if obj.gui then
            obj.gui.Enabled = true
            obj.gui.Adornee = head
        end
        
        obj.name.Visible = esp.ShowName
        obj.name.TextColor3 = esp.TextColor
        obj.name.TextSize = esp.TextSize
        
        obj.hp.Visible = esp.ShowHealth
        obj.hp.TextColor3 = esp.HealthColor
        obj.hp.TextSize = esp.TextSize
        obj.hp.Text = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
        
        -- CHI и STAM
        local chi, stam = getPlayerStats(player)
        obj.chi.Visible = esp.ShowChi
        obj.chi.TextColor3 = esp.ChiColor
        obj.chi.TextSize = esp.TextSize
        obj.chi.Text = "CHI: " .. chi
        
        obj.stam.Visible = esp.ShowStamina
        obj.stam.TextColor3 = esp.StamColor
        obj.stam.TextSize = esp.TextSize
        obj.stam.Text = "STAM: " .. stam
        
        obj.dist.Visible = esp.ShowDistance
        obj.dist.TextColor3 = esp.DistanceColor
        obj.dist.TextSize = esp.TextSize
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            obj.dist.Text = string.format("[%d m]", math.floor((head.Position - myRoot.Position).Magnitude))
        end
    end
end

--> [< COLOR CHANGER (ИСПРАВЛЕН) >] <--

-- ✅ ИСПРАВЛЕНО: ждём прогрузки персонажа перед отправкой
local function setSkinColor(r, g, b)
    if not shindoEvent then return end
    task.spawn(function()
        -- Ждём прогрузки персонажа
        if LocalPlayer.Character then
            LocalPlayer.Character:WaitForChild("Humanoid", 5)
        end
        task.wait(0.15)
        
        local colorString = string.format("%d,%d,%d", 255 - r, 255 - g, 255 - b)
        pcall(function()
            shindoEvent:FireServer("skin", colorString)
        end)
    end)
end

local function setHairColor(r, g, b)
    if not shindoEvent then return end
    task.spawn(function()
        if LocalPlayer.Character then
            LocalPlayer.Character:WaitForChild("Humanoid", 5)
        end
        task.wait(0.15)
        
        local colorString = string.format("%d,%d,%d", 255 - r, 255 - g, 255 - b)
        pcall(function()
            shindoEvent:FireServer("haircolor", colorString)
        end)
    end)
end

--> [< АИМБОТ ФУНКЦИИ >] <--

local function closeScript()
    pcall(function()
        if fovCircle then fovCircle.Visible = false; fovCircle:Remove() end
        if Window then Window:Destroy() end
        disableSilentHook()
    end)
    getgenv().UniversalShindoLoaded = false
end

local function getBestAimPart(char)
    if not char then return nil end
    if settings.aimPart ~= "Auto" then
        local p = char:FindFirstChild(settings.aimPart)
        if p and p:IsA("BasePart") then return p end
        if settings.aimPart == "Torso" then
            local ut = char:FindFirstChild("UpperTorso") or char:FindFirstChild("LowerTorso")
            if ut and ut:IsA("BasePart") then return ut end
        end
    end
    local camPos = Camera.CFrame.Position
    local best, bestD = nil, math.huge
    for _, n in ipairs(ALL_BODY_PARTS) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            local d = (p.Position - camPos).Magnitude
            if d < bestD then bestD = d; best = p end
        end
    end
    return best
end

local function isSameTeam(p)
    if not settings.teamCheck then return false end
    if not p.Team or not LocalPlayer.Team then return false end
    return p.Team == LocalPlayer.Team
end

local function isVisible(char)
    if not settings.wallCheck then return true end
    local part = getBestAimPart(char)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin).unit * 500
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, char}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local res = Workspace:Raycast(origin, dir, params)
    return not res or res.Instance:IsDescendantOf(char)
end

local function getTarget()
    local bestT, bestS = nil, math.huge
    local camPos = Camera.CFrame.Position
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or isSameTeam(p) then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        
        local tp = getBestAimPart(char)
        if not tp or not isVisible(char) then continue end
        
        if settings.maxDistance > 0 then
            local rp = char:FindFirstChild("HumanoidRootPart")
            if rp and (rp.Position - camPos).Magnitude > settings.maxDistance then continue end
        end
        
        local sp, onScreen = Camera:WorldToViewportPoint(tp.Position)
        if not onScreen then continue end
        
        local cd = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if cd > settings.fov then continue end
        
        local dist = (tp.Position - camPos).Magnitude
        local score = settings.prioritizeClose and (dist * 0.7 + cd * 0.3) or (cd * 0.7 + dist * 0.3)
        
        if score < bestS then bestS = score; bestT = p end
    end
    return bestT
end

local function aimAtTarget(p)
    if not p or not p.Character then return end
    local tp = getBestAimPart(p.Character)
    if not tp then return end
    local rp = p.Character:FindFirstChild("HumanoidRootPart")
    local pos = tp.Position + (rp and rp.Velocity * settings.prediction or Vector3.new())
    local cur = Camera.CFrame
    local tgt = CFrame.new(cur.Position, pos)
    Camera.CFrame = cur:Lerp(tgt, math.clamp(1 - settings.smoothing, 0.05, 1))
end

--> [< SERVER ФУНКЦИИ >] <--

local function serverHop()
    Fluent:Notify({Title = "🔄 Server Hop", Content = "Поиск сервера...", Duration = 3})
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = game:HttpGet(url)
        local servers = HttpService:JSONDecode(res)
        local avail = {}
        for _, s in ipairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(avail, s.id)
            end
        end
        if #avail > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, avail[math.random(1, #avail)], LocalPlayer)
        else
            Fluent:Notify({Title = "❌", Content = "Нет серверов", Duration = 3})
        end
    end)
end

local function rejoinServer()
    Fluent:Notify({Title = "🔁 Rejoin", Content = "Переподключение...", Duration = 3})
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

local function rejoinGame()
    Fluent:Notify({Title = "🎮 Rejoin", Content = "Переподключение...", Duration = 3})
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

--> [< GUI >] <--

local Window = Fluent:CreateWindow({
    Title = "Universal Shindo Cheat",
    SubTitle = "Aimbot • Silent Aim • ESP • Colors • Server",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 500),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Aimbot = Window:AddTab({ Title = "Aimbot 🎯", Icon = "crosshair" }),
    Silent = Window:AddTab({ Title = "Silent Aim 🎭", Icon = "eye-off" }),
    ESP = Window:AddTab({ Title = "ESP 👁️", Icon = "eye" }),
    Colors = Window:AddTab({ Title = "Colors 🎨", Icon = "palette" }),
    Visual = Window:AddTab({ Title = "Visual ✨", Icon = "sun" }),
    Server = Window:AddTab({ Title = "Server 🌐", Icon = "globe" }),
    UI = Window:AddTab({ Title = "UI Settings", Icon = "settings" })
}

local Options = Fluent.Options

--> [< ВКЛАДКА AIMBOT >] <--

Tabs.Aimbot:AddToggle("AimEnabled", {
    Title = "Enable Aimbot",
    Default = false
}):OnChanged(function(v)
    aimbotEnabled = v
    if fovCircle then fovCircle.Visible = settings.showFovCircle and v end
    if not v then aiming = false; currentTarget = nil end
end)

Tabs.Aimbot:AddButton({Title = "👁️ Hide Menu", Callback = function() Window:Toggle() end})
Tabs.Aimbot:AddButton({Title = "🔴 Close Script", Callback = function() closeScript() end})

Tabs.Aimbot:AddDropdown("ActKey", {
    Title = "Activation Key",
    Values = {"BackSlash (\\)", "LeftControl", "RightControl", "F", "Q", "E", "R", "T"},
    Default = 1,
    Multi = false
}):OnChanged(function(v)
    if v == "BackSlash (\\)" then settings.key = "BackSlash"
    else settings.key = v end
end)

Tabs.Aimbot:AddDropdown("AimPart", {
    Title = "Aim Part",
    Values = {"Auto", "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso"},
    Default = 1
}):OnChanged(function(v) settings.aimPart = v end)

Tabs.Aimbot:AddToggle("ToggleMode", {Title = "Toggle Mode", Default = false}):OnChanged(function(v)
    settings.aimMode = v and "Toggle" or "Hold"
end)

Tabs.Aimbot:AddSlider("FOV", {Title = "FOV Size", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
    settings.fov = v; if fovCircle then fovCircle.Radius = v end
end)

Tabs.Aimbot:AddSlider("MaxDist", {Title = "Max Distance", Default = 5000, Min = 0, Max = 5000, Rounding = 0}):OnChanged(function(v)
    settings.maxDistance = v
end)

Tabs.Aimbot:AddToggle("PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v)
    settings.prioritizeClose = v
end)

Tabs.Aimbot:AddSlider("Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v)
    settings.smoothing = v / 100
end)

Tabs.Aimbot:AddSlider("Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v)
    settings.prediction = v / 100
end)

Tabs.Aimbot:AddToggle("WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.wallCheck = v end)
Tabs.Aimbot:AddToggle("Sticky", {Title = "Sticky Aim", Default = false}):OnChanged(function(v) settings.stickyAim = v end)
Tabs.Aimbot:AddToggle("TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.teamCheck = v end)

--> [< ВКЛАДКА SILENT AIM >] <--

Tabs.Silent:AddParagraph({
    Title = "🎭 Silent Aim",
    Content = "Тихая подмена направления атаки. Работает через хук FireServer(update, fixmouse)."
})

Tabs.Silent:AddToggle("SilentOn", {
    Title = "Enable Silent Aim",
    Default = false
}):OnChanged(function(v)
    silentAim.Enabled = v
    if v then enableSilentHook() else disableSilentHook() end
    Fluent:Notify({
        Title = v and "🎭 Silent Aim ВКЛ" or "🎭 Silent Aim ВЫКЛ",
        Content = v and "Активирован" or "Деактивирован",
        Duration = 2
    })
end)

Tabs.Silent:AddSlider("SilentFOV", {Title = "FOV Radius", Default = 150, Min = 10, Max = 800, Rounding = 0}):OnChanged(function(v)
    silentAim.FOV = v
end)

Tabs.Silent:AddSlider("SilentPred", {Title = "Prediction", Default = 15, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v)
    silentAim.Prediction = v / 100
end)

Tabs.Silent:AddSlider("SilentHit", {Title = "Hit Chance %", Default = 100, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v)
    silentAim.HitChance = v
end)

Tabs.Silent:AddToggle("SilentTeam", {Title = "Team Check", Default = false}):OnChanged(function(v)
    silentAim.TeamCheck = v
end)

Tabs.Silent:AddButton({
    Title = "🔄 Переустановить хук",
    Callback = function()
        disableSilentHook()
        task.wait(0.3)
        if silentAim.Enabled then enableSilentHook() end
        Fluent:Notify({Title = "🔄", Content = "Хук переустановлен", Duration = 2})
    end
})

--> [< ВКЛАДКА ESP >] <--

Tabs.ESP:AddToggle("ESPOn", {
    Title = "Enable ESP",
    Default = false
}):OnChanged(function(v)
    esp.Enabled = v
    if v then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then createESP(p) end
        end
        Fluent:Notify({Title = "👁️ ESP ВКЛ", Content = "Активирован", Duration = 2})
    else
        for p in pairs(esp.Objects) do removeESP(p) end
        Fluent:Notify({Title = "👁️ ESP ВЫКЛ", Content = "Деактивирован", Duration = 2})
    end
end)

Tabs.ESP:AddToggle("EspName", {Title = "Show Name", Default = true}):OnChanged(function(v) esp.ShowName = v end)
Tabs.ESP:AddToggle("EspHP", {Title = "Show Health", Default = true}):OnChanged(function(v) esp.ShowHealth = v end)
Tabs.ESP:AddToggle("EspChi", {Title = "Show CHI", Default = true}):OnChanged(function(v) esp.ShowChi = v end)
Tabs.ESP:AddToggle("EspStam", {Title = "Show STAMINA", Default = true}):OnChanged(function(v) esp.ShowStamina = v end)
Tabs.ESP:AddToggle("EspDist", {Title = "Show Distance", Default = true}):OnChanged(function(v) esp.ShowDistance = v end)

Tabs.ESP:AddSlider("EspSize", {Title = "Text Size", Default = 14, Min = 8, Max = 24, Rounding = 0}):OnChanged(function(v)
    esp.TextSize = v
end)

Tabs.ESP:AddColorpicker("EspTextC", {Title = "Name Color", Default = Color3.fromRGB(255, 255, 255)}):OnChanged(function(c) esp.TextColor = c end)
Tabs.ESP:AddColorpicker("EspHpC", {Title = "HP Color", Default = Color3.fromRGB(0, 255, 0)}):OnChanged(function(c) esp.HealthColor = c end)
Tabs.ESP:AddColorpicker("EspChiC", {Title = "CHI Color", Default = Color3.fromRGB(100, 150, 255)}):OnChanged(function(c) esp.ChiColor = c end)
Tabs.ESP:AddColorpicker("EspStamC", {Title = "STAM Color", Default = Color3.fromRGB(255, 200, 50)}):OnChanged(function(c) esp.StamColor = c end)
Tabs.ESP:AddColorpicker("EspDistC", {Title = "Distance Color", Default = Color3.fromRGB(255, 255, 0)}):OnChanged(function(c) esp.DistanceColor = c end)

--> [< ВКЛАДКА COLORS >] <--

Tabs.Colors:AddParagraph({
    Title = "🎨 Color Changer",
    Content = "Изменение цвета скина и волос. Ждёт прогрузки персонажа перед отправкой."
})

Tabs.Colors:AddToggle("RainbowSkin", {Title = "Rainbow Skin", Default = false}):OnChanged(function(v)
    colors.RainbowSkin = v
end)

Tabs.Colors:AddToggle("RainbowHair", {Title = "Rainbow Hair", Default = false}):OnChanged(function(v)
    colors.RainbowHair = v
end)

Tabs.Colors:AddSlider("SkinSpd", {Title = "Skin Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v)
    colors.SkinSpeed = v / 10
end)

Tabs.Colors:AddSlider("HairSpd", {Title = "Hair Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v)
    colors.HairSpeed = v / 10
end)

Tabs.Colors:AddButton({
    Title = "🔴 Красный скин",
    Callback = function()
        setSkinColor(255, 0, 0)
        Fluent:Notify({Title = "🎨", Content = "Красный скин", Duration = 2})
    end
})

Tabs.Colors:AddButton({
    Title = "🟢 Зелёный скин",
    Callback = function() setSkinColor(0, 255, 0); Fluent:Notify({Title = "🎨", Content = "Зелёный скин", Duration = 2}) end
})

Tabs.Colors:AddButton({
    Title = "🔵 Синий скин",
    Callback = function() setSkinColor(0, 0, 255); Fluent:Notify({Title = "🎨", Content = "Синий скин", Duration = 2}) end
})

Tabs.Colors:AddButton({
    Title = "🟣 Фиолетовый скин",
    Callback = function() setSkinColor(128, 0, 255); Fluent:Notify({Title = "🎨", Content = "Фиолетовый скин", Duration = 2}) end
})

Tabs.Colors:AddButton({
    Title = "⚫ Чёрный скин",
    Callback = function() setSkinColor(0, 0, 0); Fluent:Notify({Title = "🎨", Content = "Чёрный скин", Duration = 2}) end
})

Tabs.Colors:AddButton({
    Title = "⚪ Белый скин",
    Callback = function() setSkinColor(255, 255, 255); Fluent:Notify({Title = "🎨", Content = "Белый скин", Duration = 2}) end
})

Tabs.Colors:AddColorpicker("CustomColor", {Title = "Кастомный цвет", Default = Color3.fromRGB(255, 0, 0)})

Tabs.Colors:AddButton({
    Title = "✅ Применить кастомный",
    Callback = function()
        local c = Options.CustomColor.Value
        if c then
            setSkinColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
            Fluent:Notify({Title = "🎨", Content = "Кастомный цвет применён", Duration = 2})
        end
    end
})

Tabs.Colors:AddColorpicker("CustomHair", {Title = "Кастомный цвет волос", Default = Color3.fromRGB(255, 0, 0)})

Tabs.Colors:AddButton({
    Title = "✅ Применить цвет волос",
    Callback = function()
        local c = Options.CustomHair.Value
        if c then
            setHairColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
            Fluent:Notify({Title = "🎨", Content = "Цвет волос применён", Duration = 2})
        end
    end
})

--> [< ВКЛАДКА VISUAL >] <--

Tabs.Visual:AddToggle("XRay", {Title = "X-Ray", Default = false}):OnChanged(function(v) setXRay(v) end)
Tabs.Visual:AddToggle("FullBright", {Title = "Full Bright", Default = false}):OnChanged(function(v) setFullBright(v) end)
Tabs.Visual:AddToggle("NV", {Title = "Night Vision", Default = false}):OnChanged(function(v) setNightVision(v) end)
Tabs.Visual:AddToggle("NoShadow", {Title = "No Shadows", Default = false}):OnChanged(function(v) setNoShadows(v) end)
Tabs.Visual:AddToggle("NoBloom", {Title = "No Bloom", Default = false}):OnChanged(function(v) setNoBloom(v) end)
Tabs.Visual:AddToggle("NoSun", {Title = "No Sun Rays", Default = false}):OnChanged(function(v) setNoSunRays(v) end)
Tabs.Visual:AddToggle("RainLight", {Title = "Rainbow Lighting", Default = false}):OnChanged(function(v) setRainbowLighting(v) end)
Tabs.Visual:AddToggle("NoFog", {Title = "No Fog", Default = false}):OnChanged(function(v) setNoFog(v) end)

Tabs.Visual:AddButton({
    Title = "🔄 Reset Visual",
    Callback = function()
        setXRay(false); setFullBright(false); setNightVision(false)
        setNoShadows(false); setNoBloom(false); setNoSunRays(false)
        setRainbowLighting(false); setNoFog(false)
        Fluent:Notify({Title = "🔄", Content = "Эффекты сброшены", Duration = 2})
    end
})

Tabs.Visual:AddToggle("ShowFOV", {Title = "Show FOV Circle", Default = true}):OnChanged(function(v)
    settings.showFovCircle = v
    if fovCircle then fovCircle.Visible = v and aimbotEnabled end
end)

Tabs.Visual:AddColorpicker("FovColor", {Title = "FOV Color", Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(c)
    settings.fovColor = c
    if fovCircle and not settings.rainbowFov then fovCircle.Color = c end
end)

Tabs.Visual:AddToggle("RainFOV", {Title = "Rainbow FOV", Default = false}):OnChanged(function(v)
    settings.rainbowFov = v
end)

--> [< ВКЛАДКА SERVER >] <--

Tabs.Server:AddButton({Title = "🔄 Server Hop", Callback = function() serverHop() end})
Tabs.Server:AddButton({Title = "🔁 Rejoin Server", Callback = function() rejoinServer() end})
Tabs.Server:AddButton({Title = "🎮 Rejoin Game", Callback = function() rejoinGame() end})

local pingPara = Tabs.Server:AddParagraph({Title = "📶 Пинг", Content = "Загрузка..."})
local regPara = Tabs.Server:AddParagraph({Title = "🌍 Регион", Content = "Определение..."})

task.spawn(function()
    task.wait(1)
    while task.wait(1) do
        local p = getPlayerPing()
        local c = p < 100 and "🟢" or (p < 200 and "🟡" or "🔴")
        pcall(function() pingPara:SetDesc(c .. " " .. p .. " ms") end)
    end
end)

task.spawn(function()
    task.wait(2)
    while task.wait(15) do
        pcall(function() regPara:SetDesc("🌍 " .. getServerRegion()) end)
    end
end)

--> [< ГЛАВНЫЙ ЦИКЛ >] <--

local function getKeyCode(name)
    local map = {
        BackSlash = Enum.KeyCode.BackSlash,
        LeftControl = Enum.KeyCode.LeftControl,
        RightControl = Enum.KeyCode.RightControl,
        LeftShift = Enum.KeyCode.LeftShift,
        RightShift = Enum.KeyCode.RightShift,
        F = Enum.KeyCode.F, Q = Enum.KeyCode.Q, E = Enum.KeyCode.E,
        R = Enum.KeyCode.R, T = Enum.KeyCode.T
    }
    return map[name]
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not aimbotEnabled then return end
    local k = getKeyCode(settings.key)
    if k and input.KeyCode == k then
        if settings.aimMode == "Hold" then
            aiming = true
        else
            aiming = not aiming
            if not aiming then currentTarget = nil end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp or not aimbotEnabled then return end
    local k = getKeyCode(settings.key)
    if k and input.KeyCode == k and settings.aimMode == "Hold" then
        aiming = false; currentTarget = nil
    end
end)

-- Цикл обновления
RunService.RenderStepped:Connect(function()
    -- Rainbow Lighting
    if settings.rainbowLighting then
        lightingHue = (lightingHue + 0.005) % 1
        local c = Color3.fromHSV(lightingHue, 1, 1)
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    end
    
    -- FOV Circle
    if aimbotEnabled and fovCircle and settings.showFovCircle then
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
    
    -- Aimbot
    if aiming then
        local t = tick()
        if settings.stickyAim and currentTarget then
            local ch = currentTarget.Character
            if ch then
                local tp = getBestAimPart(ch)
                if tp then
                    local sp = Camera:WorldToViewportPoint(tp.Position)
                    local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                    if d > settings.fov * 1.5 then currentTarget = nil end
                end
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

-- ESP Update
RunService.Heartbeat:Connect(function(dt)
    if esp.Enabled then
        esp.LastUpdate = esp.LastUpdate + dt
        if esp.LastUpdate >= esp.UpdateRate then
            esp.LastUpdate = 0
            updateESP()
        end
    end
    
    -- Rainbow colors
    if colors.RainbowSkin and shindoEvent then
        skinTimer = skinTimer + dt
        if skinTimer >= 0.1 then
            skinTimer = 0
            local h = (tick() * colors.SkinSpeed) % 1
            local c = Color3.fromHSV(h, 1, 1)
            setSkinColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
        end
    end
    
    if colors.RainbowHair and shindoEvent then
        hairTimer = hairTimer + dt
        if hairTimer >= 0.1 then
            hairTimer = 0
            local h = (tick() * colors.HairSpeed) % 1
            local c = Color3.fromHSV(h, 1, 1)
            setHairColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
        end
    end
end)

-- Player events
Players.PlayerAdded:Connect(function(p)
    if esp.Enabled then
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if esp.Enabled then createESP(p) end
        end)
    end
end)

Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if esp.Enabled then
        for p in pairs(esp.Objects) do removeESP(p) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then createESP(p) end
        end
    end
end)

--> [< UI SETTINGS >] <--

local saveOk, saveErr = pcall(function()
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("UniversalShindo")
    SaveManager:SetFolder("UniversalShindo/Configs")
    InterfaceManager:BuildInterfaceSection(Tabs.UI)
    SaveManager:BuildConfigSection(Tabs.UI)
    SaveManager:LoadAutoloadConfig()
end)

if not saveOk then
    warn("⚠️ UI Settings не загружен: " .. tostring(saveErr))
    Tabs.UI:AddParagraph({
        Title = "⚠️ Ошибка",
        Content = "SaveManager не загрузился: " .. tostring(saveErr):sub(1, 100)
    })
end

print("====================================")
print("✅ Universal Shindo Cheat v4.0 загружен!")
print("🎯 Aimbot: " .. (aimbotEnabled and "ON" or "OFF"))
print("🎭 Silent Aim: хук FireServer (fixmouse)")
print("👁️ ESP: с CHI и STAMINA")
print("🎨 Colors: skin/haircolor")
print("🌐 Server: Hop/Rejoin")
print("📌 RightControl - скрыть меню")
print("====================================")
