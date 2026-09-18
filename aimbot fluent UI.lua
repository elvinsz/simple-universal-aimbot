--[[
    Shindo Life Cheat v1.0 (Fluent UI)
    Функции: Silent Aim, ESP, Color Changer
    Для игры Shindo Life
]]

if getgenv().ShindoCheatLoaded then
    print("⚠️ Shindo Cheat уже загружен!")
    return
end
getgenv().ShindoCheatLoaded = true

-- Загрузка Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

if not Fluent then
    warn("❌ Fluent UI не загружен!")
    getgenv().ShindoCheatLoaded = false
    return
end

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Ожидание event
local event
pcall(function()
    event = LocalPlayer:WaitForChild("startevent", 10)
end)

if not event then
    warn("❌ Не удалось найти 'startevent'. Убедитесь, что вы в игре Shindo Life.")
end

--> [< ПЕРЕМЕННЫЕ >] <--

-- Silent Aim
local silentAimEnabled = false
local silentAimFOV = 150
local silentAimPrediction = 0.15
local silentAimTarget = nil
local silentAimCFrame = nil
local silentAimHitChance = 100
local silentAimTeamCheck = false

-- ESP
local espEnabled = false
local espSettings = {
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    ShowBox = false,
    TextColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    DistanceColor = Color3.fromRGB(255, 255, 0),
    BoxColor = Color3.fromRGB(255, 0, 0),
    TextSize = 14,
    UpdateRate = 0.1
}
local espObjects = {}
local espLastUpdate = 0

-- Color Changer
local colorSettings = {
    RainbowSkin = false,
    RainbowHair = false,
    SkinSpeed = 0.5,
    HairSpeed = 0.5,
    RainbowUpdateRate = 0.1
}
local skinTimer = 0
local hairTimer = 0

--> [< SILENT AIM >] <--

local function getSilentAimTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local bestPart, bestDist = nil, silentAimFOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if silentAimTeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local char = player.Character
        if not char then continue end
        
        local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not part or not humanoid or humanoid.Health <= 0 then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
        if dist < bestDist then
            bestPart = part
            bestDist = dist
        end
    end
    
    return bestPart
end

-- Обновление цели каждый кадр
RunService.Heartbeat:Connect(function()
    if not silentAimEnabled then
        silentAimTarget = nil
        silentAimCFrame = nil
        return
    end
    
    silentAimTarget = getSilentAimTarget()
    if silentAimTarget then
        local targetPos = silentAimTarget.Position + (silentAimTarget.Velocity * silentAimPrediction)
        silentAimCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    else
        silentAimCFrame = nil
    end
end)

-- Установка хука на FireServer
local silentAimHookActive = false
local originalNamecall = nil
local metaTable = nil

local function enableSilentAimHook()
    if silentAimHookActive then return end
    
    local success, err = pcall(function()
        metaTable = getrawmetatable(game)
        originalNamecall = metaTable.__namecall
        setreadonly(metaTable, false)
        
        metaTable.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Перехватываем FireServer для события "update" с "fixmouse"
            if method == "FireServer" and self.Name == "update" and args[1] == "fixmouse" then
                if silentAimEnabled and silentAimCFrame then
                    if math.random(1, 100) <= silentAimHitChance then
                        args[2] = silentAimCFrame
                    end
                end
            end
            
            return originalNamecall(self, unpack(args))
        end)
        
        setreadonly(metaTable, true)
        silentAimHookActive = true
        print("✅ Silent Aim хук установлен")
    end)
    
    if not success then
        warn("❌ Silent Aim не поддерживается: " .. tostring(err))
    end
end

local function disableSilentAimHook()
    if metaTable and originalNamecall then
        pcall(function()
            setreadonly(metaTable, false)
            metaTable.__namecall = originalNamecall
            setreadonly(metaTable, true)
        end)
    end
    silentAimHookActive = false
    print("✅ Silent Aim хук снят")
end

--> [< ESP >] <--

local function createESP(player)
    if player == LocalPlayer then return end
    if espObjects[player] then return end
    if not player.Character then return end
    
    local head = player.Character:FindFirstChild("Head")
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not head and not root then return end
    
    -- Основной BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "ShindoESP"
    gui.Size = UDim2.new(0, 200, 0, 60)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.Adornee = head or root
    gui.Parent = player.Character
    
    -- Имя игрока
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.33, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = espSettings.TextColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = espSettings.TextSize
    nameLabel.TextScaled = false
    nameLabel.Parent = gui
    
    -- Здоровье
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HpLabel"
    hpLabel.Size = UDim2.new(1, 0, 0.33, 0)
    hpLabel.Position = UDim2.new(0, 0, 0.33, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = espSettings.HealthColor
    hpLabel.TextStrokeTransparency = 0
    hpLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.TextSize = espSettings.TextSize
    hpLabel.TextScaled = false
    hpLabel.Parent = gui
    
    -- Дистанция
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, 0, 0.33, 0)
    distLabel.Position = UDim2.new(0, 0, 0.66, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = espSettings.DistanceColor
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = espSettings.TextSize
    distLabel.TextScaled = false
    distLabel.Parent = gui
    
    espObjects[player] = {
        gui = gui,
        nameLabel = nameLabel,
        hpLabel = hpLabel,
        distLabel = distLabel,
        character = player.Character
    }
end

local function removeESP(player)
    local obj = espObjects[player]
    if obj and obj.gui then
        obj.gui:Destroy()
    end
    espObjects[player] = nil
end

local function updateESP()
    for player, obj in pairs(espObjects) do
        if not player.Parent or not player.Character then
            removeESP(player)
            continue
        end
        
        -- Обновляем Adornee если персонаж переродился
        if obj.character ~= player.Character then
            removeESP(player)
            if espEnabled then createESP(player) end
            continue
        end
        
        local head = player.Character:FindFirstChild("Head")
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        
        if not head or not humanoid or humanoid.Health <= 0 then
            if obj.gui then obj.gui.Enabled = false end
            continue
        end
        
        if obj.gui then
            obj.gui.Enabled = espEnabled
            obj.gui.Adornee = head
        end
        
        -- Обновляем имя
        if obj.nameLabel then
            obj.nameLabel.Visible = espSettings.ShowName
            obj.nameLabel.TextColor3 = espSettings.TextColor
        end
        
        -- Обновляем здоровье
        if obj.hpLabel then
            obj.hpLabel.Visible = espSettings.ShowHealth
            obj.hpLabel.TextColor3 = espSettings.HealthColor
            obj.hpLabel.Text = string.format("HP: %d / %d", 
                math.floor(humanoid.Health), 
                math.floor(humanoid.MaxHealth))
        end
        
        -- Обновляем дистанцию
        if obj.distLabel then
            obj.distLabel.Visible = espSettings.ShowDistance
            obj.distLabel.TextColor3 = espSettings.DistanceColor
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local dist = (head.Position - myRoot.Position).Magnitude
                obj.distLabel.Text = string.format("[%d m]", math.floor(dist))
            end
        end
    end
end

-- Отслеживание игроков
Players.PlayerAdded:Connect(function(player)
    if espEnabled then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if espEnabled then createESP(player) end
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

--> [< COLOR CHANGER >] <--

local function setSkinColor(r, g, b)
    if not event then return end
    -- В Shindo Life цвета инвертированы: 255 - значение
    local colorString = string.format("%d,%d,%d", 255 - r, 255 - g, 255 - b)
    pcall(function()
        event:FireServer("skin", colorString)
    end)
end

local function setHairColor(r, g, b)
    if not event then return end
    local colorString = string.format("%d,%d,%d", 255 - r, 255 - g, 255 - b)
    pcall(function()
        event:FireServer("haircolor", colorString)
    end)
end

--> [< GUI (FLUENT) >] <--

local Window = Fluent:CreateWindow({
    Title = "Shindo Life Cheat",
    SubTitle = "Silent Aim • ESP • Color Changer",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    SilentAim = Window:AddTab({ Title = "Silent Aim 🎯", Icon = "crosshair" }),
    ESP = Window:AddTab({ Title = "ESP 👁️", Icon = "eye" }),
    Colors = Window:AddTab({ Title = "Colors 🎨", Icon = "palette" }),
    UI = Window:AddTab({ Title = "UI Settings", Icon = "settings" })
}

local Options = Fluent.Options

--> [< ВКЛАДКА SILENT AIM >] <--

Tabs.SilentAim:AddParagraph({
    Title = "🎯 Silent Aim",
    Content = "Тихая подмена направления атаки через хук FireServer. Работает только в Shindo Life."
})

Tabs.SilentAim:AddToggle("SilentAimEnabled", {
    Title = "Enable Silent Aim",
    Description = "Включить Silent Aim",
    Default = false
}):OnChanged(function(Value)
    silentAimEnabled = Value
    if Value then
        enableSilentAimHook()
    else
        disableSilentAimHook()
    end
    Fluent:Notify({
        Title = Value and "🎯 Silent Aim ВКЛ" or "🎯 Silent Aim ВЫКЛ",
        Content = Value and "Активирован" or "Деактивирован",
        Duration = 2
    })
end)

Tabs.SilentAim:AddSlider("SilentAimFOV", {
    Title = "FOV Radius",
    Description = "Радиус поиска цели (пиксели)",
    Default = 150,
    Min = 10,
    Max = 800,
    Rounding = 0
}):OnChanged(function(Value)
    silentAimFOV = Value
end)

Tabs.SilentAim:AddSlider("SilentAimPrediction", {
    Title = "Prediction",
    Description = "Предсказание движения цели",
    Default = 15,
    Min = 0,
    Max = 50,
    Rounding = 0
}):OnChanged(function(Value)
    silentAimPrediction = Value / 100
end)

Tabs.SilentAim:AddSlider("SilentAimHitChance", {
    Title = "Hit Chance",
    Description = "Шанс срабатывания (%)",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 0
}):OnChanged(function(Value)
    silentAimHitChance = Value
end)

Tabs.SilentAim:AddToggle("SilentAimTeamCheck", {
    Title = "Team Check",
    Description = "Не атаковать союзников",
    Default = false
}):OnChanged(function(Value)
    silentAimTeamCheck = Value
end)

Tabs.SilentAim:AddButton({
    Title = "🔄 Сбросить хук",
    Description = "Переустановить хук (если не работает)",
    Callback = function()
        disableSilentAimHook()
        task.wait(0.3)
        if silentAimEnabled then
            enableSilentAimHook()
        end
        Fluent:Notify({
            Title = "🔄 Хук обновлён",
            Content = "Silent Aim переустановлен",
            Duration = 2
        })
    end
})

--> [< ВКЛАДКА ESP >] <--

Tabs.ESP:AddParagraph({
    Title = "👁️ ESP",
    Content = "Подсветка игроков через стены с информацией о здоровье, дистанции и имени."
})

Tabs.ESP:AddToggle("ESPEnabled", {
    Title = "Enable ESP",
    Description = "Включить ESP",
    Default = false
}):OnChanged(function(Value)
    espEnabled = Value
    if Value then
        -- Создаём ESP для всех игроков
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                createESP(player)
            end
        end
        Fluent:Notify({
            Title = "👁️ ESP ВКЛ",
            Content = "Активирован",
            Duration = 2
        })
    else
        -- Удаляем все ESP
        for player in pairs(espObjects) do
            removeESP(player)
        end
        Fluent:Notify({
            Title = "👁️ ESP ВЫКЛ",
            Content = "Деактивирован",
            Duration = 2
        })
    end
end)

Tabs.ESP:AddToggle("ESPShowName", {
    Title = "Show Name",
    Description = "Показывать имя игрока",
    Default = true
}):OnChanged(function(Value)
    espSettings.ShowName = Value
end)

Tabs.ESP:AddToggle("ESPShowHealth", {
    Title = "Show Health",
    Description = "Показывать здоровье",
    Default = true
}):OnChanged(function(Value)
    espSettings.ShowHealth = Value
end)

Tabs.ESP:AddToggle("ESPShowDistance", {
    Title = "Show Distance",
    Description = "Показывать дистанцию",
    Default = true
}):OnChanged(function(Value)
    espSettings.ShowDistance = Value
end)

Tabs.ESP:AddSlider("ESPTextSize", {
    Title = "Text Size",
    Description = "Размер текста",
    Default = 14,
    Min = 8,
    Max = 24,
    Rounding = 0
}):OnChanged(function(Value)
    espSettings.TextSize = Value
    -- Обновляем размеры
    for _, obj in pairs(espObjects) do
        if obj.nameLabel then obj.nameLabel.TextSize = Value end
        if obj.hpLabel then obj.hpLabel.TextSize = Value end
        if obj.distLabel then obj.distLabel.TextSize = Value end
    end
end)

Tabs.ESP:AddColorpicker("ESPTextColor", {
    Title = "Text Color",
    Description = "Цвет имени",
    Default = Color3.fromRGB(255, 255, 255)
}):OnChanged(function(Color)
    espSettings.TextColor = Color
end)

Tabs.ESP:AddColorpicker("ESPHealthColor", {
    Title = "Health Color",
    Description = "Цвет здоровья",
    Default = Color3.fromRGB(0, 255, 0)
}):OnChanged(function(Color)
    espSettings.HealthColor = Color
end)

Tabs.ESP:AddColorpicker("ESPDistanceColor", {
    Title = "Distance Color",
    Description = "Цвет дистанции",
    Default = Color3.fromRGB(255, 255, 0)
}):OnChanged(function(Color)
    espSettings.DistanceColor = Color
end)

--> [< ВКЛАДКА COLORS >] <--

Tabs.Colors:AddParagraph({
    Title = "🎨 Color Changer",
    Content = "Изменение цвета скина и волос. Работает через FireServer события."
})

Tabs.Colors:AddToggle("RainbowSkin", {
    Title = "Rainbow Skin",
    Description = "Радужный цвет скина",
    Default = false
}):OnChanged(function(Value)
    colorSettings.RainbowSkin = Value
end)

Tabs.Colors:AddToggle("RainbowHair", {
    Title = "Rainbow Hair",
    Description = "Радужный цвет волос",
    Default = false
}):OnChanged(function(Value)
    colorSettings.RainbowHair = Value
end)

Tabs.Colors:AddSlider("SkinSpeed", {
    Title = "Skin Rainbow Speed",
    Description = "Скорость смены цвета скина",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0
}):OnChanged(function(Value)
    colorSettings.SkinSpeed = Value / 10
end)

Tabs.Colors:AddSlider("HairSpeed", {
    Title = "Hair Rainbow Speed",
    Description = "Скорость смены цвета волос",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0
}):OnChanged(function(Value)
    colorSettings.HairSpeed = Value / 10
end)

Tabs.Colors:AddButton({
    Title = "🔴 Красный скин",
    Callback = function()
        setSkinColor(255, 0, 0)
        Fluent:Notify({Title = "🎨 Скин", Content = "Установлен красный", Duration = 2})
    end
})

Tabs.Colors:AddButton({
    Title = "🟢 Зелёный скин",
    Callback = function()
        setSkinColor(0, 255, 0)
        Fluent:Notify({Title = "🎨 Скин", Content = "Установлен зелёный", Duration = 2})
    end
})

Tabs.Colors:AddButton({
    Title = "🔵 Синий скин",
    Callback = function()
        setSkinColor(0, 0, 255)
        Fluent:Notify({Title = "🎨 Скин", Content = "Установлен синий", Duration = 2})
    end
})

Tabs.Colors:AddButton({
    Title = "🟣 Фиолетовый скин",
    Callback = function()
        setSkinColor(128, 0, 255)
        Fluent:Notify({Title = "🎨 Скин", Content = "Установлен фиолетовый", Duration = 2})
    end
})

Tabs.Colors:AddButton({
    Title = "⚫ Чёрный скин",
    Callback = function()
        setSkinColor(0, 0, 0)
        Fluent:Notify({Title = "🎨 Скин", Content = "Установлен чёрный", Duration = 2})
    end
})

Tabs.Colors:AddButton({
    Title = "⚪ Белый скин",
    Callback = function()
        setSkinColor(255, 255, 255)
        Fluent:Notify({Title = "🎨 Скин", Content = "Установлен белый", Duration = 2})
    end
})

Tabs.Colors:AddColorpicker("CustomSkinColor", {
    Title = "Кастомный цвет скина",
    Description = "Выберите свой цвет",
    Default = Color3.fromRGB(255, 0, 0)
})

Tabs.Colors:AddButton({
    Title = "✅ Применить кастомный цвет",
    Callback = function()
        local color = Options.CustomSkinColor.Value
        if color then
            setSkinColor(
                math.floor(color.R * 255),
                math.floor(color.G * 255),
                math.floor(color.B * 255)
            )
            Fluent:Notify({Title = "🎨 Скин", Content = "Применён кастомный цвет", Duration = 2})
        end
    end
})

--> [< ОСНОВНОЙ ЦИКЛ >] <--

-- Обновление ESP
RunService.Heartbeat:Connect(function(dt)
    -- ESP Update
    if espEnabled then
        espLastUpdate = espLastUpdate + dt
        if espLastUpdate >= espSettings.UpdateRate then
            espLastUpdate = 0
            updateESP()
        end
    end
    
    -- Rainbow Skin
    if colorSettings.RainbowSkin and event then
        skinTimer = skinTimer + dt
        if skinTimer >= colorSettings.RainbowUpdateRate then
            skinTimer = 0
            local hue = (tick() * colorSettings.SkinSpeed) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            setSkinColor(
                math.floor(color.R * 255),
                math.floor(color.G * 255),
                math.floor(color.B * 255)
            )
        end
    end
    
    -- Rainbow Hair
    if colorSettings.RainbowHair and event then
        hairTimer = hairTimer + dt
        if hairTimer >= colorSettings.RainbowUpdateRate then
            hairTimer = 0
            local hue = (tick() * colorSettings.HairSpeed) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            setHairColor(
                math.floor(color.R * 255),
                math.floor(color.G * 255),
                math.floor(color.B * 255)
            )
        end
    end
end)

--> [< АВТООБНОВЛЕНИЕ ESP ПРИ РЕСПАВНЕ >] <--

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if espEnabled then
        for player in pairs(espObjects) do
            removeESP(player)
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                createESP(player)
            end
        end
    end
end)

--> [< ИНФО >] <--

Fluent:Notify({
    Title = "✅ Shindo Life Cheat загружен!",
    Content = "Вкладки: Silent Aim, ESP, Colors",
    Duration = 5
})

print("====================================")
print("✅ Shindo Life Cheat загружен!")
print("📌 RightControl - скрыть/показать меню")
print("🎯 Silent Aim: хук FireServer (fixmouse)")
print("👁️ ESP: BillboardGui")
print("🎨 Colors: skin/haircolor события")
print("====================================")
