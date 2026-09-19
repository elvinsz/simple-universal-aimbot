--[[
    Universal Shindo Cheat v11.0
    ✅ Второй аимбот на клавишу "1" (целится выше головы)
    ✅ ESP упрощён: HP зелёным, MD фиолетовым, Dodge text ON/КД
    ✅ Защита от повторного запуска с уведомлением
    ✅ Убран кейбинд с ESP (только тоггл)
]]

-- ✅ Защита от повторного запуска с уведомлением
if getgenv().UniversalShindoLoaded then
    pcall(function()
        local FluentCheck = getgenv().Fluent
        if FluentCheck and FluentCheck.Notify then
            FluentCheck:Notify({
                Title = "⚠️ Уже загружено",
                Content = "Universal Shindo v11.0 уже запущен!",
                Duration = 3
            })
        else
            print("⚠️ Universal Shindo v11.0 уже загружен!")
        end
    end)
    return
end
getgenv().UniversalShindoLoaded = true

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

if not Fluent then return end
getgenv().Fluent = Fluent

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
local Mouse = LocalPlayer:GetMouse()

local shindoEvent
pcall(function() shindoEvent = LocalPlayer:WaitForChild("startevent", 8) end)

--> [< НАСТРОЙКИ >] <--

local settings = {
    -- Aimbot 1 (основной)
    fov = 300,
    smoothing = 0.15,
    prediction = 0.065,
    wallCheck = false,
    teamCheck = false,
    aimPart = "Auto",
    aimMode = "Hold",
    aimKey = Enum.KeyCode.BackSlash,
    ListeningForAimBind = false,
    showFovCircle = true,
    maxDistance = 0,
    prioritizeClose = true,
    mode360 = false,
    fovColor = Color3.fromRGB(255, 0, 0),
    targetedColor = Color3.fromRGB(0, 255, 0),
    rainbowFov = false,
    
    -- ✅ Aimbot 2 (Headshot — выше головы)
    aim2Fov = 300,
    aim2Smoothing = 0.15,
    aim2Prediction = 0.065,
    aim2WallCheck = false,
    aim2TeamCheck = false,
    aim2Mode = "Hold",
    aim2Key = Enum.KeyCode.One,  -- клавиша "1" по умолчанию
    aim2ListeningForBind = false,
    aim2ShowFovCircle = true,
    aim2MaxDistance = 0,
    aim2PrioritizeClose = true,
    aim2Mode360 = false,
    aim2HeightOffset = 3,  -- ✅ Высота над головой
    aim2FovColor = Color3.fromRGB(255, 165, 0),
    aim2TargetedColor = Color3.fromRGB(255, 255, 0),
    aim2RainbowFov = false,
    
    -- Visual
    xray = false, fullBright = false, nightVision = false,
    noShadows = false, noBloom = false, noSunRays = false,
    rainbowLighting = false, noFog = false
}

local silentAim = {
    Enabled = false,
    MasterEnabled = false,
    Mode = "Hold",
    HoldKey = Enum.KeyCode.BackSlash,
    ListeningForBind = false,
    Prediction = 0.187,
    FOV = 500,
    TargetPart = "HumanoidRootPart",
    ShowFovCircle = true,
    MaxDistance = 0,
    PrioritizeClose = true,
    Mode360 = false,
    FovColor = Color3.fromRGB(100, 200, 255),
    CachedTarget = nil,
    CachedCFrame = nil,
    Logging = false
}

local markerClick = {
    Enabled = false,
    ModifierKey = Enum.KeyCode.Backquote,
    ListeningForBind = false,
    Debug = false,
    HeightOffset = 3
}

-- ✅ Упрощённый ESP
local ESP = {
    Enabled   = false,
    Visible   = false,
    Range     = math.huge,
    UpdateRate = 0.2,
    Font      = Enum.Font.GothamBold,
    Size      = 1.0,
    ShowName  = true,
    ShowHP    = true,
    ShowMD    = true,
    ShowDodge = true,
    NameColor = Color3.fromRGB(255, 255, 255),
    HPColor   = Color3.fromRGB(0, 255, 0),      -- ✅ Зелёный
    MDColor   = Color3.fromRGB(200, 100, 255),  -- ✅ Фиолетовый
    DodgeOnColor = Color3.fromRGB(0, 255, 0),   -- ✅ Зелёный для ON
    DodgeCDColor = Color3.fromRGB(255, 60, 60), -- ✅ Красный для КД
    Whitelist = {},
}

local colors = {
    RainbowSkin = false, RainbowHair = false,
    SkinSpeed = 0.5, HairSpeed = 0.5,
    Invert = true
}
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

local fovCircle, fovCircle2, silentFovCircle
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.Radius = settings.fov
    fovCircle.Filled = false
    fovCircle.Color = settings.fovColor
    fovCircle.Transparency = 1
    fovCircle.Visible = false
end)

pcall(function()
    fovCircle2 = Drawing.new("Circle")
    fovCircle2.Thickness = 2
    fovCircle2.Radius = settings.aim2Fov
    fovCircle2.Filled = false
    fovCircle2.Color = settings.aim2FovColor
    fovCircle2.Transparency = 1
    fovCircle2.Visible = false
end)

pcall(function()
    silentFovCircle = Drawing.new("Circle")
    silentFovCircle.Thickness = 2
    silentFovCircle.Radius = silentAim.FOV
    silentFovCircle.Filled = false
    silentFovCircle.Color = silentAim.FovColor
    silentFovCircle.Transparency = 1
    silentFovCircle.Visible = false
end)

--> [< ПИНГ >] <--

local function getPlayerPing()
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    return ok and ping and math.floor(ping * 1000) or 0
end

local function getServerRegion()
    local ok, region = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(Players:GetPlayers()[1] or LocalPlayer)
    end)
    return ok and region and tostring(region) or "Unknown"
end

--> [< ВИЗУАЛЬНЫЕ >] <--

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
        elseif nv then nv.Enabled = false end
    end)
end

local function setNoShadows(v) settings.noShadows = v; Lighting.GlobalShadows = not v end

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

--> [< УПРОЩЁННЫЙ ESP v11 >] <--

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

-- ✅ Проверка Taijutsu Body Dodge
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
                    if cd > 0 then
                        return {ready = false, cd = math.floor(cd)}
                    else
                        return {ready = true, cd = 0}
                    end
                else
                    return {ready = true, cd = 0}
                end
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
    t.Size = size
    t.Position = pos
    t.BackgroundTransparency = 1
    t.TextColor3 = color
    t.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    t.TextStrokeTransparency = 0.3
    t.Font = ESP.Font
    t.TextSize = textSize or 16
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.TextScaled = false
    t.Parent = parent
    return t
end

local function createPlayerESP(p, char)
    if p == LocalPlayer then return end
    if not isWhitelisted(p) then return end
    if espData[p] and espData[p].gui and espData[p].gui.Parent then return end
    
    local head = char:FindFirstChild("Head") or getRoot(char)
    local hum = getHumanoid(char)
    if not head or not hum then return end
    
    -- ✅ Простой BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "SimpleESP"
    gui.Size = UDim2.new(0, 200, 0, 90)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.Adornee = head
    gui.MaxDistance = ESP.Range
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local holder = Instance.new("Frame", gui)
    holder.Size = UDim2.fromScale(1, 1)
    holder.BackgroundTransparency = 1
    
    local scale = Instance.new("UIScale", holder)
    scale.Scale = ESP.Size
    
    -- Имя
    local nameLabel = makeLabel(holder, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), ESP.NameColor, 16)
    nameLabel.Text = p.Name
    
    -- HP (зелёный)
    local hpLabel = makeLabel(holder, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 22), ESP.HPColor, 16)
    hpLabel.Text = "HP: 0"
    
    -- MD (фиолетовый)
    local mdLabel = makeLabel(holder, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 42), ESP.MDColor, 16)
    mdLabel.Text = "MD: 0"
    
    -- Dodge (ON/КД)
    local dodgeLabel = makeLabel(holder, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 62), ESP.DodgeOnColor, 16)
    dodgeLabel.Text = "DODGE: --"
    
    espData[p] = {
        gui = gui, char = char, head = head, hum = hum,
        nameLabel = nameLabel,
        hpLabel = hpLabel,
        mdLabel = mdLabel,
        dodgeLabel = dodgeLabel,
        hp = -1, md = -1, dodgeState = -1,
    }
end

local function updateESP()
    if not ESP.Enabled or not ESP.Visible then return end
    for p, d in pairs(espData) do
        if not p.Parent or not d.char or not d.char.Parent then
            clearPlayer(p); continue
        end
        if not isWhitelisted(p) then
            if d.gui then d.gui.Enabled = false end
            continue
        end
        
        -- Обновляем head если нужно
        if not d.head or not d.head.Parent then
            d.head = d.char:FindFirstChild("Head") or getRoot(d.char)
            if d.gui then d.gui.Adornee = d.head end
        end
        if not d.hum or not d.hum.Parent then d.hum = getHumanoid(d.char) end
        if not d.gui or not d.head or not d.hum or d.hum.Health <= 0 then
            if d.gui then d.gui.Enabled = false end
            continue
        end
        
        d.gui.Enabled = true
        d.gui.Adornee = d.head
        
        -- ✅ Имя
        if ESP.ShowName then
            d.nameLabel.Visible = true
            d.nameLabel.Text = p.Name
        else
            d.nameLabel.Visible = false
        end
        
        -- ✅ HP зелёным
        local hp = math.floor(d.hum.Health)
        if d.hp ~= hp then
            d.hp = hp
            d.hpLabel.Text = "HP: " .. short(hp)
        end
        d.hpLabel.Visible = ESP.ShowHP
        d.hpLabel.TextColor3 = ESP.HPColor
        
        -- ✅ MD фиолетовым
        local md = math.floor(getModeValue(p))
        if d.md ~= md then
            d.md = md
            d.mdLabel.Text = "MD: " .. md
        end
        d.mdLabel.Visible = ESP.ShowMD
        d.mdLabel.TextColor3 = ESP.MDColor
        
        -- ✅ Dodge: ON зелёным / КД красным
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
            else
                d.dodgeLabel.Visible = false
            end
        else
            d.dodgeLabel.Visible = false
        end
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
    if espConns[p] then
        for _, c in ipairs(espConns[p]) do pcall(function() c:Disconnect() end) end
    end
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

--> [< KUNAI MARKER >] <--

local savedEnemyPos = nil
local DEBUG_DEEP = false

local function getPriorityEnemy()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local myPos = myRoot.Position
    
    local best = nil
    local bestScore = math.huge
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
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
        if head then
            aimPos = head.Position + Vector3.new(0, markerClick.HeightOffset, 0)
        elseif root then
            aimPos = root.Position + Vector3.new(0, markerClick.HeightOffset + 2, 0)
        else
            continue
        end
        
        local worldDist = (root and root.Position or aimPos - myPos).Magnitude
        local sp, onScreen = Camera:WorldToViewportPoint(aimPos)
        local screenDist = onScreen and (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude or 9999
        local score = screenDist + (worldDist * 0.1)
        
        if score < bestScore then
            bestScore = score
            best = aimPos
        end
    end
    return best
end

local function deepLog(t, prefix, depth)
    depth = depth or 0; prefix = prefix or ""
    if depth > 4 then return end
    if type(t) == "table" then
        for k, v in pairs(t) do
            local vt = typeof(v)
            if vt == "Vector3" or vt == "CFrame" then
                print(prefix .. "[" .. tostring(k) .. "] = " .. vt .. " " .. tostring(v))
            elseif type(v) == "table" then
                print(prefix .. "[" .. tostring(k) .. "] = table:")
                deepLog(v, prefix .. "  ", depth + 1)
            else
                print(prefix .. "[" .. tostring(k) .. "] = " .. vt .. " " .. tostring(v))
            end
        end
    end
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

local function isModifierHeld()
    if not markerClick.Enabled then return false end
    return UserInputService:IsKeyDown(markerClick.ModifierKey)
end

local kunaiHook = false
local oldKunaiNamecall = nil
local kunaiMetaT = nil

local function enableKunaiHook()
    if kunaiHook then return end
    local ok, err = pcall(function()
        kunaiMetaT = getrawmetatable(game)
        oldKunaiNamecall = kunaiMetaT.__namecall
        setreadonly(kunaiMetaT, false)
        kunaiMetaT.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            local nameLower = string.lower(tostring(self.Name))
            
            local isMarkerEvent = nameLower:find("marker", 1, true) 
                or nameLower:find("kunai", 1, true) 
                or nameLower:find("namikaze", 1, true)
            local isTeleportEvent = nameLower:find("teleport", 1, true)
            
            if method == "FireServer" and (isMarkerEvent or isTeleportEvent) then
                if markerClick.Debug then
                    print("[HOOK] " .. tostring(self.Name) .. " | args: " .. #args)
                    for i, a in ipairs(args) do
                        print("  [" .. i .. "] = " .. typeof(a) .. " " .. tostring(a))
                        if type(a) == "table" then deepLog(a, "     ", 0) end
                    end
                end
                
                if isModifierHeld() then
                    local enemyPos = getPriorityEnemy()
                    if enemyPos then
                        savedEnemyPos = enemyPos
                        for i = 1, #args do
                            if typeof(args[i]) == "Vector3" then
                                args[i] = enemyPos
                            elseif typeof(args[i]) == "CFrame" then
                                args[i] = CFrame.new(enemyPos)
                            elseif type(args[i]) == "table" then
                                args[i] = replaceVectorInTable(args[i], enemyPos, 0)
                            end
                        end
                        if markerClick.Debug then
                            print("[HOOK] ✅ Подменён " .. tostring(self.Name) .. " → " .. tostring(enemyPos))
                        end
                        return oldKunaiNamecall(self, table.unpack(args))
                    end
                end
            end
            return oldKunaiNamecall(self, ...)
        end)
        setreadonly(kunaiMetaT, true)
        kunaiHook = true
        print("✅ Kunai Hook установлен")
    end)
    if not ok then warn("❌ Kunai Hook: " .. tostring(err)) end
end

local function disableKunaiHook()
    if kunaiMetaT and oldKunaiNamecall then
        pcall(function()
            setreadonly(kunaiMetaT, false)
            kunaiMetaT.__namecall = oldKunaiNamecall
            setreadonly(kunaiMetaT, true)
        end)
    end
    kunaiHook = false
end

--> [< SILENT AIM >] <--

local silentHook = false
local oldNamecall = nil
local metaT = nil

RunService.Heartbeat:Connect(function()
    if silentAim.MasterEnabled and silentAim.Mode == "Hold" then
        silentAim.Enabled = UserInputService:IsKeyDown(silentAim.HoldKey)
    end
    if not silentAim.Enabled then
        silentAim.CachedTarget = nil
        silentAim.CachedCFrame = nil
        return
    end
    
    local best = nil
    local bestScore = math.huge
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
        if silentAim.MaxDistance and silentAim.MaxDistance > 0 and enemyRoot then
            if (enemyRoot.Position - originPos).Magnitude > silentAim.MaxDistance then continue end
        end
        
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
            if silentAim.Logging and method == "FireServer" and self.Name == "update" then
                print("[SILENT-LOG] update: args[1]=" .. tostring(args[1]))
            end
            if method == "FireServer" and self.Name == "update" then
                if args[1] == "fixmouse" and silentAim.Enabled and silentAim.CachedCFrame then
                    args[2] = silentAim.CachedCFrame
                    return oldNamecall(self, table.unpack(args))
                end
            end
            return oldNamecall(self, ...)
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

--> [< COLOR CHANGER >] <--

local function prepareColor(r, g, b)
    r = math.clamp(math.floor(r), 1, 254)
    g = math.clamp(math.floor(g), 1, 254)
    b = math.clamp(math.floor(b), 1, 254)
    if colors.Invert then
        r = 255 - r; g = 255 - g; b = 255 - b
    end
    return string.format("%d,%d,%d", r, g, b)
end

local function setSkinColor(r, g, b)
    if not shindoEvent then return end
    task.spawn(function()
        local char = LocalPlayer.Character
        if char then
            char:WaitForChild("Humanoid", 5)
            char:WaitForChild("Head", 5)
        end
        task.wait(0.3)
        local str = prepareColor(r, g, b)
        for i = 1, 3 do
            local ok = pcall(function() shindoEvent:FireServer("skin", str) end)
            if ok then break end
            task.wait(0.2)
        end
    end)
end

local function setHairColor(r, g, b)
    if not shindoEvent then return end
    task.spawn(function()
        local char = LocalPlayer.Character
        if char then
            char:WaitForChild("Humanoid", 5)
            char:WaitForChild("Head", 5)
        end
        task.wait(0.3)
        local str = prepareColor(r, g, b)
        for i = 1, 3 do
            local ok = pcall(function() shindoEvent:FireServer("haircolor", str) end)
            if ok then break end
            task.wait(0.2)
        end
    end)
end

--> [< АИМБОТЫ >] <--

local function getBestAimPart(char, customPart)
    if not char then return nil end
    if customPart and customPart ~= "Auto" then
        local p = char:FindFirstChild(customPart)
        if p and p:IsA("BasePart") then return p end
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

local function isSameTeam(p, check)
    if not check then return false end
    if not p.Team or not LocalPlayer.Team then return false end
    return p.Team == LocalPlayer.Team
end

local function isVisible(char, check)
    if not check then return true end
    local part = getBestAimPart(char, "Auto")
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin).unit * 500
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, char}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local res = Workspace:Raycast(origin, dir, params)
    return not res or res.Instance:IsDescendantOf(char)
end

-- ✅ Aimbot 1 (основной)
local function getTarget()
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
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
        if settings.wallCheck and not isVisible(char, true) then continue end
        
        local enemyRoot = char:FindFirstChild("HumanoidRootPart")
        if settings.maxDistance and settings.maxDistance > 0 and enemyRoot then
            if (enemyRoot.Position - originPos).Magnitude > settings.maxDistance then continue end
        end
        
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

-- ✅ Aimbot 2 (Headshot — целится выше головы)
local function getTarget2()
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
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
        
        -- ✅ Целимся ВЫШЕ ГОЛОВЫ
        local aimPos = head.Position + Vector3.new(0, settings.aim2HeightOffset, 0)
        
        if settings.aim2WallCheck and not isVisible(char, true) then continue end
        
        local enemyRoot = char:FindFirstChild("HumanoidRootPart")
        if settings.aim2MaxDistance and settings.aim2MaxDistance > 0 and enemyRoot then
            if (enemyRoot.Position - originPos).Magnitude > settings.aim2MaxDistance then continue end
        end
        
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
    local tgt = CFrame.new(cur.Position, pos)
    Camera.CFrame = cur:Lerp(tgt, math.clamp(1 - settings.smoothing, 0.05, 1))
end

local function aimAtTarget2(p)
    if not p or not p.Character then return end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end
    local rp = p.Character:FindFirstChild("HumanoidRootPart")
    
    -- ✅ Целимся выше головы
    local aimPos = head.Position + Vector3.new(0, settings.aim2HeightOffset, 0)
    local pos = aimPos + (rp and rp.Velocity * settings.aim2Prediction or Vector3.new())
    
    local cur = Camera.CFrame
    local tgt = CFrame.new(cur.Position, pos)
    Camera.CFrame = cur:Lerp(tgt, math.clamp(1 - settings.aim2Smoothing, 0.05, 1))
end

--> [< SERVER >] <--

local function serverHop()
    Fluent:Notify({Title = "🔄 Server Hop", Content = "Поиск...", Duration = 3})
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local servers = HttpService:JSONDecode(game:HttpGet(url))
        local avail = {}
        for _, s in ipairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(avail, s.id)
            end
        end
        if #avail > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, avail[math.random(1, #avail)], LocalPlayer)
        else
            Fluent:Notify({Title = "❌", Content = "Нет других серверов", Duration = 3})
        end
    end)
end

local function rejoinServer()
    Fluent:Notify({Title = "🔁 Rejoin", Content = "Переподключение...", Duration = 3})
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end

local function forceReconnect()
    Fluent:Notify({Title = "⚡ Force Reconnect", Content = "Принудительное...", Duration = 3})
    task.spawn(function()
        for i = 1, 3 do
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
            if ok then return end
            task.wait(1)
        end
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)
end

--> [< GUI >] <--

local Window = Fluent:CreateWindow({
    Title = "Universal Shindo v11.0",
    SubTitle = "2 Aimbots • Simplified ESP",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Aimbot = Window:AddTab({ Title = "Aimbot 🎯", Icon = "crosshair" }),
    Aimbot2 = Window:AddTab({ Title = "Aimbot 2 🎯", Icon = "target" }),
    Silent = Window:AddTab({ Title = "Silent Aim 🎭", Icon = "eye-off" }),
    ESP = Window:AddTab({ Title = "ESP 👁️", Icon = "eye" }),
    Colors = Window:AddTab({ Title = "Colors 🎨", Icon = "palette" }),
    Visual = Window:AddTab({ Title = "Visual ✨", Icon = "sun" }),
    Server = Window:AddTab({ Title = "Server 🌐", Icon = "globe" }),
    UI = Window:AddTab({ Title = "UI Settings", Icon = "settings" })
}

local Options = Fluent.Options

--> [< ВКЛАДКА AIMBOT 1 >] <--

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

Tabs.Aimbot:AddToggle("RainbowFov", {Title = "Rainbow FOV", Default = false}):OnChanged(function(v)
    settings.rainbowFov = v
end)

Tabs.Aimbot:AddDropdown("AimPart", {Title = "Aim Part",
    Values = {"Auto", "Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    Default = 1}):OnChanged(function(v) settings.aimPart = v end)

Tabs.Aimbot:AddDropdown("AimMode", {Title = "Aim Mode",
    Values = {"Hold (зажать)", "Toggle (переключить)"},
    Default = 1}):OnChanged(function(v)
    settings.aimMode = (v == "Hold (зажать)") and "Hold" or "Toggle"
end)

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

Tabs.Aimbot:AddSlider("MaxDist", {Title = "Max Distance", Description = "0 = без ограничений", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v)
    settings.maxDistance = v
end)

Tabs.Aimbot:AddToggle("PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v)
    settings.prioritizeClose = v
end)

Tabs.Aimbot:AddToggle("Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
    settings.mode360 = v
    if v and fovCircle then fovCircle.Visible = false end
end)

Tabs.Aimbot:AddSlider("Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v)
    settings.smoothing = v / 100
end)

Tabs.Aimbot:AddSlider("Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v)
    settings.prediction = v / 100
end)

Tabs.Aimbot:AddToggle("WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.wallCheck = v end)
Tabs.Aimbot:AddToggle("TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.teamCheck = v end)

--> [< ВКЛАДКА AIMBOT 2 (HEADSHOT) >] <--

Tabs.Aimbot2:AddParagraph({
    Title = "🎯 Aimbot 2 — Headshot",
    Content = "Целится ВЫШЕ головы. По умолчанию на клавише [1]"
})

Tabs.Aimbot2:AddToggle("Aim2On", {Title = "Enable Aimbot 2", Default = false}):OnChanged(function(v)
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

Tabs.Aimbot2:AddToggle("Aim2RainbowFov", {Title = "Rainbow FOV", Default = false}):OnChanged(function(v)
    settings.aim2RainbowFov = v
end)

Tabs.Aimbot2:AddDropdown("Aim2Mode", {Title = "Aim Mode",
    Values = {"Hold (зажать)", "Toggle (переключить)"},
    Default = 1}):OnChanged(function(v)
    settings.aim2Mode = (v == "Hold (зажать)") and "Hold" or "Toggle"
end)

local aim2BindButton
aim2BindButton = Tabs.Aimbot2:AddButton({
    Title = "🎹 BIND: " .. settings.aim2Key.Name,
    Description = "Нажмите для смены клавиши (по умолчанию 1)",
    Callback = function()
        settings.aim2ListeningForBind = true
        pcall(function() aim2BindButton:SetTitle("🎹 Нажмите клавишу...") end)
    end
})

-- ✅ Высота над головой
Tabs.Aimbot2:AddSlider("Aim2Height", {
    Title = "📏 Height Above Head (studs)",
    Description = "На сколько studs выше головы целиться",
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 0
}):OnChanged(function(v)
    settings.aim2HeightOffset = v
end)

Tabs.Aimbot2:AddSlider("Aim2FOV", {Title = "FOV Size", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
    settings.aim2Fov = v; if fovCircle2 then fovCircle2.Radius = v end
end)

Tabs.Aimbot2:AddSlider("Aim2MaxDist", {Title = "Max Distance", Description = "0 = без ограничений", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v)
    settings.aim2MaxDistance = v
end)

Tabs.Aimbot2:AddToggle("Aim2PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v)
    settings.aim2PrioritizeClose = v
end)

Tabs.Aimbot2:AddToggle("Aim2Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
    settings.aim2Mode360 = v
    if v and fovCircle2 then fovCircle2.Visible = false end
end)

Tabs.Aimbot2:AddSlider("Aim2Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v)
    settings.aim2Smoothing = v / 100
end)

Tabs.Aimbot2:AddSlider("Aim2Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v)
    settings.aim2Prediction = v / 100
end)

Tabs.Aimbot2:AddToggle("Aim2WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.aim2WallCheck = v end)
Tabs.Aimbot2:AddToggle("Aim2TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.aim2TeamCheck = v end)

--> [< KUNAI MARKER (в Aimbot2) >] <--

local markerSection = Tabs.Aimbot2:AddSection("Kunai Marker")

markerSection:AddToggle("MarkerClick", {
    Title = "🌀 Enable Marker Hack",
    Default = false
}):OnChanged(function(v)
    markerClick.Enabled = v
    if v then
        enableKunaiHook()
        Fluent:Notify({Title = "🌀 Marker ВКЛ", Content = "Зажми " .. markerClick.ModifierKey.Name, Duration = 3})
    else
        disableKunaiHook()
    end
end)

local markerBindBtn
markerBindBtn = markerSection:AddButton({
    Title = "🎹 Modifier: " .. markerClick.ModifierKey.Name,
    Callback = function()
        markerClick.ListeningForBind = true
        pcall(function() markerBindBtn:SetTitle("🎹 Нажмите...") end)
    end
})

markerSection:AddSlider("MarkerH", {
    Title = "📏 Marker Height",
    Default = 3, Min = 0, Max = 20, Rounding = 0
}):OnChanged(function(v) markerClick.HeightOffset = v end)

markerSection:AddToggle("MarkerDebug", {Title = "🔍 Debug", Default = false}):OnChanged(function(v) markerClick.Debug = v end)

--> [< SILENT AIM TAB >] <--

Tabs.Silent:AddToggle("SilentMaster", {Title = "Enable Silent Aim", Default = false}):OnChanged(function(v)
    silentAim.MasterEnabled = v
    if v then enableSilentHook() else disableSilentHook() end
end)

Tabs.Silent:AddDropdown("SilentMode", {
    Title = "Режим",
    Values = {"Hold", "Toggle"},
    Default = 1
}):OnChanged(function(v) silentAim.Mode = v end)

local silentBindButton
silentBindButton = Tabs.Silent:AddButton({
    Title = "🎹 BIND: " .. silentAim.HoldKey.Name,
    Callback = function()
        silentAim.ListeningForBind = true
        pcall(function() silentBindButton:SetTitle("🎹 Нажмите...") end)
    end
})

Tabs.Silent:AddSlider("SilentFOV", {Title = "FOV Radius", Default = 500, Min = 50, Max = 2000, Rounding = 0}):OnChanged(function(v)
    silentAim.FOV = v
    if silentFovCircle then silentFovCircle.Radius = v end
end)

Tabs.Silent:AddSlider("SilentPred", {Title = "Prediction", Default = 19, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v)
    silentAim.Prediction = v / 100
end)

Tabs.Silent:AddSlider("SilentMaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v)
    silentAim.MaxDistance = v
end)

Tabs.Silent:AddToggle("SilentPriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v)
    silentAim.PrioritizeClose = v
end)

Tabs.Silent:AddToggle("SilentMode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
    silentAim.Mode360 = v
end)

Tabs.Silent:AddButton({
    Title = "🔄 Переустановить хук",
    Callback = function()
        disableSilentHook(); task.wait(0.3)
        if silentAim.MasterEnabled then enableSilentHook() end
    end
})

--> [< ESP TAB (упрощённый, без кейбинда) >] <--

Tabs.ESP:AddToggle("ESPOn", {
    Title = "Enable ESP",
    Description = "Показывает HP (зелёный), MD (фиолетовый), Dodge (ON/КД)",
    Default = false
}):OnChanged(function(v)
    ESP.Enabled = v
    ESP.Visible = v
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
Tabs.ESP:AddToggle("EspHP", {Title = "Show HP (green)", Default = true}):OnChanged(function(v) ESP.ShowHP = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspMD", {Title = "Show MD (purple)", Default = true}):OnChanged(function(v) ESP.ShowMD = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspDodge", {Title = "Show Body Dodge (ON/КД)", Default = true}):OnChanged(function(v) ESP.ShowDodge = v; rebuildESP() end)

Tabs.ESP:AddSlider("EspSize", {Title = "ESP Size", Default = 100, Min = 30, Max = 300, Rounding = 0}):OnChanged(function(v)
    ESP.Size = v / 100
    for _, d in pairs(espData) do
        if d.gui then
            local s = d.gui:FindFirstChild("Frame") and d.gui.Frame:FindFirstChildOfClass("UIScale")
            if s then s.Scale = ESP.Size end
        end
    end
end)

Tabs.ESP:AddSlider("EspRate", {Title = "Update Rate (ms)", Default = 200, Min = 50, Max = 2000, Rounding = 50}):OnChanged(function(v)
    ESP.UpdateRate = v / 1000
end)

Tabs.ESP:AddColorpicker("EspNameC", {Title = "Name Color", Default = Color3.fromRGB(255, 255, 255)}):OnChanged(function(c) ESP.NameColor = c end)
Tabs.ESP:AddColorpicker("EspHPC", {Title = "HP Color", Default = Color3.fromRGB(0, 255, 0)}):OnChanged(function(c) ESP.HPColor = c end)
Tabs.ESP:AddColorpicker("EspMDC", {Title = "MD Color", Default = Color3.fromRGB(200, 100, 255)}):OnChanged(function(c) ESP.MDColor = c end)
Tabs.ESP:AddColorpicker("EspDodgeOnC", {Title = "Dodge ON Color", Default = Color3.fromRGB(0, 255, 0)}):OnChanged(function(c) ESP.DodgeOnColor = c end)
Tabs.ESP:AddColorpicker("EspDodgeCDC", {Title = "Dodge КД Color", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) ESP.DodgeCDColor = c end)

local espWhitelistSection = Tabs.ESP:AddSection("Player Whitelist (пусто = все)")

Tabs.ESP:AddButton({
    Title = "🔄 Обновить список игроков",
    Callback = function()
        local playerList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(playerList, p) end
        end
        if #playerList == 0 then
            Fluent:Notify({Title = "ℹ️", Content = "Нет игроков", Duration = 3})
            return
        end
        for _, p in ipairs(playerList) do
            local isWL = ESP.Whitelist[p.Name] == true
            espWhitelistSection:AddButton({
                Title = (isWL and "✓ " or "  ") .. p.Name,
                Callback = function()
                    if ESP.Whitelist[p.Name] then
                        ESP.Whitelist[p.Name] = nil
                    else
                        ESP.Whitelist[p.Name] = true
                    end
                    rebuildESP()
                end
            })
        end
    end
})

--> [< COLORS TAB >] <--

Tabs.Colors:AddToggle("InvertColors", {Title = "Инвертировать цвет", Default = true}):OnChanged(function(v) colors.Invert = v end)
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
        Title = preset.name .. " СКИН",
        Callback = function()
            setSkinColor(preset.r, preset.g, preset.b)
            Fluent:Notify({Title = "🎨 Скин", Content = preset.name, Duration = 2})
        end
    })
end

Tabs.Colors:AddColorpicker("CustomSkin", {Title = "Кастомный скин", Default = Color3.fromRGB(255, 0, 0)})
Tabs.Colors:AddButton({
    Title = "✅ Применить кастомный скин",
    Callback = function()
        local c = Options.CustomSkin.Value
        if c then setSkinColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)) end
    end
})

for _, preset in ipairs(colorPresets) do
    Tabs.Colors:AddButton({
        Title = preset.name .. " ВОЛОСЫ",
        Callback = function()
            setHairColor(preset.r, preset.g, preset.b)
            Fluent:Notify({Title = "🎨 Волосы", Content = preset.name, Duration = 2})
        end
    })
end

Tabs.Colors:AddColorpicker("CustomHair", {Title = "Кастомные волосы", Default = Color3.fromRGB(255, 0, 0)})
Tabs.Colors:AddButton({
    Title = "✅ Применить кастомные волосы",
    Callback = function()
        local c = Options.CustomHair.Value
        if c then setHairColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)) end
    end
})

--> [< VISUAL TAB >] <--

Tabs.Visual:AddToggle("XRay", {Title = "X-Ray", Default = false}):OnChanged(function(v) setXRay(v) end)
Tabs.Visual:AddToggle("FB", {Title = "Full Bright", Default = false}):OnChanged(function(v) setFullBright(v) end)
Tabs.Visual:AddToggle("NV", {Title = "Night Vision", Default = false}):OnChanged(function(v) setNightVision(v) end)
Tabs.Visual:AddToggle("NoSh", {Title = "No Shadows", Default = false}):OnChanged(function(v) setNoShadows(v) end)
Tabs.Visual:AddToggle("NoBl", {Title = "No Bloom", Default = false}):OnChanged(function(v) setNoBloom(v) end)
Tabs.Visual:AddToggle("NoSR", {Title = "No Sun Rays", Default = false}):OnChanged(function(v) setNoSunRays(v) end)
Tabs.Visual:AddToggle("RainL", {Title = "Rainbow Lighting", Default = false}):OnChanged(function(v) setRainbowLighting(v) end)
Tabs.Visual:AddToggle("NoFog", {Title = "No Fog", Default = false}):OnChanged(function(v) setNoFog(v) end)

--> [< SERVER TAB >] <--

Tabs.Server:AddButton({Title = "🔄 Server Hop", Callback = function() serverHop() end})
Tabs.Server:AddButton({Title = "🔁 Rejoin Server", Callback = function() rejoinServer() end})
Tabs.Server:AddButton({Title = "⚡ Force Reconnect", Callback = function() forceReconnect() end})

local pingPara = Tabs.Server:AddParagraph({Title = "📶 Пинг", Content = "..."})
local regPara = Tabs.Server:AddParagraph({Title = "🌍 Регион", Content = "..."})

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

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    -- Marker bind
    if markerClick.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            markerClick.ModifierKey = input.KeyCode
            markerClick.ListeningForBind = false
            pcall(function() markerBindBtn:SetTitle("🎹 Modifier: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    -- Silent bind
    if silentAim.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            silentAim.HoldKey = input.KeyCode
            silentAim.ListeningForBind = false
            pcall(function() silentBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    -- Aimbot 1 bind
    if settings.ListeningForAimBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aimKey = input.KeyCode
            settings.ListeningForAimBind = false
            pcall(function() aimBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    -- ✅ Aimbot 2 bind
    if settings.aim2ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aim2Key = input.KeyCode
            settings.aim2ListeningForBind = false
            pcall(function() aim2BindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    -- Silent toggle
    if silentAim.MasterEnabled and silentAim.Mode == "Toggle" then
        if input.KeyCode == silentAim.HoldKey then
            silentAim.Enabled = not silentAim.Enabled
        end
    end
    
    -- ✅ Aimbot 1
    if aimbotEnabled and input.KeyCode == settings.aimKey then
        if settings.aimMode == "Hold" then
            aiming = true
        else
            aiming = not aiming
            if not aiming then currentTarget = nil end
        end
    end
    
    -- ✅ Aimbot 2 (клавиша "1")
    if aim2Enabled and input.KeyCode == settings.aim2Key then
        if settings.aim2Mode == "Hold" then
            aim2ing = true
        else
            aim2ing = not aim2ing
            if not aim2ing then aim2Target = nil end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    
    if aimbotEnabled and settings.aimMode == "Hold" and input.KeyCode == settings.aimKey then
        aiming = false
        currentTarget = nil
    end
    
    -- ✅ Aimbot 2
    if aim2Enabled and settings.aim2Mode == "Hold" and input.KeyCode == settings.aim2Key then
        aim2ing = false
        aim2Target = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if settings.rainbowLighting then
        lightingHue = (lightingHue + 0.005) % 1
        local c = Color3.fromHSV(lightingHue, 1, 1)
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    end
    
    -- Aimbot 1 FOV
    if aimbotEnabled and fovCircle and settings.showFovCircle and not settings.mode360 then
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
    
    -- ✅ Aimbot 2 FOV
    if aim2Enabled and fovCircle2 and settings.aim2ShowFovCircle and not settings.aim2Mode360 then
        fovCircle2.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        fovCircle2.Visible = true
        if settings.aim2RainbowFov then
            hue = (hue + rainbowSpeed) % 1
            fovCircle2.Color = Color3.fromHSV(hue, 1, 1)
        elseif aim2ing and aim2Target then
            fovCircle2.Color = settings.aim2TargetedColor
        else
            fovCircle2.Color = settings.aim2FovColor
        end
    elseif fovCircle2 then
        fovCircle2.Visible = false
    end
    
    -- Silent FOV
    if silentAim.MasterEnabled and silentFovCircle and silentAim.ShowFovCircle and not silentAim.Mode360 then
        silentFovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        silentFovCircle.Radius = silentAim.FOV
        silentFovCircle.Color = silentAim.FovColor
        silentFovCircle.Visible = silentAim.Enabled
    elseif silentFovCircle then
        silentFovCircle.Visible = false
    end
    
    -- Aimbot 1
    if aiming then
        local t = tick()
        if t - lastTargetUpdate > 0.05 then
            lastTargetUpdate = t
            currentTarget = getTarget()
        end
        if currentTarget then aimAtTarget(currentTarget) end
    else
        currentTarget = nil
    end
    
    -- ✅ Aimbot 2
    if aim2ing then
        local t = tick()
        if t - lastTarget2Update > 0.05 then
            lastTarget2Update = t
            aim2Target = getTarget2()
        end
        if aim2Target then aimAtTarget2(aim2Target) end
    else
        aim2Target = nil
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if colors.RainbowSkin and shindoEvent then
        skinTimer = skinTimer + dt
        if skinTimer >= 0.1 then
            skinTimer = 0
            local h = (tick() * colors.SkinSpeed) % 1
            local c = Color3.fromHSV(h, 1, 1)
            local str = prepareColor(c.R*255, c.G*255, c.B*255)
            pcall(function() shindoEvent:FireServer("skin", str) end)
        end
    end
    
    if colors.RainbowHair and shindoEvent then
        hairTimer = hairTimer + dt
        if hairTimer >= 0.1 then
            hairTimer = 0
            local h = (tick() * colors.HairSpeed) % 1
            local c = Color3.fromHSV(h, 1, 1)
            local str = prepareColor(c.R*255, c.G*255, c.B*255)
            pcall(function() shindoEvent:FireServer("haircolor", str) end)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if ESP.Enabled then rebuildESP() end
end)

--> [< UI SETTINGS >] <--

pcall(function()
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

print("====================================")
print("✅ Universal Shindo v11.0 загружен!")
print("🎯 Aimbot 2: клавиша [1], целится ВЫШЕ ГОЛОВЫ")
print("👁️ ESP: HP зелёный, MD фиолетовый, Dodge ON/КД")
print("📌 RightControl - скрыть меню")
print("====================================")
