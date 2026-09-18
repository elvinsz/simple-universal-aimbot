--[[
    Universal Shindo Cheat v6.1
    Исправлено: Silent Aim Hold с назначаемой клавишей, Colors, CHI/STAM
]]

if getgenv().UniversalShindoLoaded then return end
getgenv().UniversalShindoLoaded = true

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

if not Fluent then return end

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
    fov = 300, smoothing = 0.15, prediction = 0.065,
    wallCheck = false, stickyAim = false, teamCheck = false,
    minHealth = 0, aimPart = "Auto", aimMode = "Hold", key = "BackSlash",
    showFovCircle = true, maxDistance = 5000, prioritizeClose = true,
    fovColor = Color3.fromRGB(255, 0, 0), targetedColor = Color3.fromRGB(0, 255, 0),
    rainbowFov = false,
    xray = false, fullBright = false, nightVision = false,
    noShadows = false, noBloom = false, noSunRays = false,
    rainbowLighting = false, noFog = false
}

-- Silent Aim
local silentAim = {
    Enabled = false,
    MasterEnabled = false,
    Mode = "Hold",
    HoldKey = Enum.KeyCode.E,
    ListeningForBind = false,
    Prediction = 0.187,
    FOV = 500,
    TargetPart = "HumanoidRootPart",
    CachedTarget = nil,
    CachedCFrame = nil,
    Logging = false
}

-- ESP
local esp = {
    Enabled = false,
    ShowName = true, ShowHealth = true, ShowDistance = true,
    ShowChi = true, ShowStamina = true,
    TextColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    DistanceColor = Color3.fromRGB(255, 255, 0),
    ChiColor = Color3.fromRGB(100, 150, 255),
    StamColor = Color3.fromRGB(255, 200, 50),
    TextSize = 14, UpdateRate = 0.1,
    Objects = {}, LastUpdate = 0
}

-- Colors
local colors = {
    RainbowSkin = false, RainbowHair = false,
    SkinSpeed = 0.5, HairSpeed = 0.5,
    Invert = true,
    Clamp = true
}
local skinTimer, hairTimer = 0, 0

local originalLighting = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows
}

local aimbotEnabled, aiming, currentTarget = false, false, nil
local lastTargetUpdate = 0
local hue, lightingHue = 0, 0
local rainbowSpeed = 0.005

local ALL_BODY_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot"
}

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
        return LocalizationService:GetCountryRegionForPlayerAsync(Players:GetPlayers()[1] or LocalPlayer)
    end)
    return ok and region and tostring(region) or "Unknown"
end

--> [< CHI/STAM >] <--

local function getPlayerChiStam(player)
    local chi, stam = 0, 0
    
    local statz = player:FindFirstChild("statz")
    if statz then
        local chiObj = statz:FindFirstChild("chakra") 
            or statz:FindFirstChild("chi")
            or statz:FindFirstChild("curchakra")
        
        if chiObj and (chiObj:IsA("NumberValue") or chiObj:IsA("IntValue")) then
            chi = math.floor(chiObj.Value)
        end
        
        local stamObj = statz:FindFirstChild("stamina")
            or statz:FindFirstChild("stam")
            or statz:FindFirstChild("curstamina")
        
        if stamObj and (stamObj:IsA("NumberValue") or stamObj:IsA("IntValue")) then
            stam = math.floor(stamObj.Value)
        end
    end
    
    if chi == 0 and stam == 0 then
        local char = player.Character
        if char then
            local chiObj = char:FindFirstChild("chakra") or char:FindFirstChild("chi")
            if chiObj and (chiObj:IsA("NumberValue") or chiObj:IsA("IntValue")) then
                chi = math.floor(chiObj.Value)
            end
            local stamObj = char:FindFirstChild("stamina") or char:FindFirstChild("stam")
            if stamObj and (stamObj:IsA("NumberValue") or stamObj:IsA("IntValue")) then
                stam = math.floor(stamObj.Value)
            end
        end
    end
    
    return chi, stam
end

local function debugScanPlayer()
    print("===== SCAN LOCAL PLAYER =====")
    local statz = LocalPlayer:FindFirstChild("statz")
    if statz then
        print("--- statz ---")
        for _, obj in ipairs(statz:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                print(string.format("  [%s] = %s", obj:GetFullName(), tostring(obj.Value)))
            end
        end
    else
        print("❌ statz не найден!")
    end
    
    local char = LocalPlayer.Character
    if char then
        print("--- character ---")
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                local val = tostring(obj.Value)
                if #val < 15 then
                    print(string.format("  [%s] = %s", obj:GetFullName(), val))
                end
            end
        end
    end
    print("=============================")
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

--> [< SILENT AIM >] <--

local silentHook = false
local oldNamecall = nil
local metaT = nil

RunService.Heartbeat:Connect(function()
    if silentAim.MasterEnabled and silentAim.Mode == "Hold" then
        local pressed = UserInputService:IsKeyDown(silentAim.HoldKey)
        silentAim.Enabled = pressed
    end
    
    if not silentAim.Enabled then
        silentAim.CachedTarget = nil
        silentAim.CachedCFrame = nil
        return
    end
    
    local best = nil
    local dist = silentAim.FOV
    local cam = Workspace.CurrentCamera
    local MousePos = cam.ViewportSize / 2

    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        if not char then continue end
        local part = char:FindFirstChild(silentAim.TargetPart)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health <= 0 then continue end
        if not part.Parent then continue end

        local pos, vis = cam:WorldToViewportPoint(part.Position)
        if not vis then continue end

        local d = (Vector2.new(pos.X, pos.Y) - MousePos).Magnitude
        if d < dist then
            best = part
            dist = d
        end
    end

    silentAim.CachedTarget = best
    if silentAim.CachedTarget and silentAim.CachedTarget.Parent then
        local targetPos = silentAim.CachedTarget.Position + (silentAim.CachedTarget.Velocity * silentAim.Prediction)
        local camPos = cam.CFrame.Position
        silentAim.CachedCFrame = CFrame.new(targetPos, targetPos + (targetPos - camPos).Unit)
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
                print("[SILENT-LOG] update: args[1]=" .. tostring(args[1]) .. 
                      " args[2]=" .. (typeof(args[2]) == "CFrame" and "CFrame" or tostring(args[2])))
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

--> [< ESP >] <--

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

    local function mkLabel(name, pos)
        local l = Instance.new("TextLabel", gui)
        l.Name = name
        l.Size = UDim2.new(1, 0, 0, 18)
        l.Position = UDim2.new(0, 0, 0, pos)
        l.BackgroundTransparency = 1
        l.TextStrokeTransparency = 0
        l.Font = Enum.Font.GothamBold
        l.TextSize = esp.TextSize
        return l
    end

    esp.Objects[player] = {
        gui = gui,
        name = mkLabel("Name", 0),
        hp = mkLabel("HP", 20),
        chi = mkLabel("CHI", 38),
        stam = mkLabel("STAM", 56),
        dist = mkLabel("DIST", 74),
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
            removeESP(player); continue
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
        obj.name.Text = player.Name
        
        obj.hp.Visible = esp.ShowHealth
        obj.hp.TextColor3 = esp.HealthColor
        obj.hp.TextSize = esp.TextSize
        obj.hp.Text = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
        
        local chi, stam = getPlayerChiStam(player)
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

--> [< COLOR CHANGER >] <--

local function prepareColor(r, g, b)
    r = math.clamp(math.floor(r), 1, 254)
    g = math.clamp(math.floor(g), 1, 254)
    b = math.clamp(math.floor(b), 1, 254)
    
    if colors.Invert then
        r = 255 - r
        g = 255 - g
        b = 255 - b
    end
    
    return string.format("%d,%d,%d", r, g, b)
end

local function setSkinColor(r, g, b)
    if not shindoEvent then
        Fluent:Notify({Title = "❌", Content = "startevent не найден", Duration = 3})
        return
    end
    task.spawn(function()
        local char = LocalPlayer.Character
        if char then
            char:WaitForChild("Humanoid", 5)
            char:WaitForChild("Head", 5)
        end
        task.wait(0.3)
        
        local str = prepareColor(r, g, b)
        print("[COLOR] Skin: " .. str .. " (in=" .. tostring(colors.Invert) .. ")")
        
        for i = 1, 3 do
            local ok = pcall(function()
                shindoEvent:FireServer("skin", str)
            end)
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
        print("[COLOR] Hair: " .. str)
        
        for i = 1, 3 do
            local ok = pcall(function()
                shindoEvent:FireServer("haircolor", str)
            end)
            if ok then break end
            task.wait(0.2)
        end
    end)
end

--> [< АИМБОТ >] <--

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
        end
    end)
end

local function rejoinServer()
    Fluent:Notify({Title = "🔁 Rejoin", Content = "Переподключение...", Duration = 3})
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end

--> [< GUI >] <--

local Window = Fluent:CreateWindow({
    Title = "Universal Shindo v6.1",
    SubTitle = "Silent Aim Bind • Colors • CHI/STAM",
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

--> [< AIMBOT TAB >] <--

Tabs.Aimbot:AddToggle("AimOn", {Title = "Enable Aimbot", Default = false}):OnChanged(function(v)
    aimbotEnabled = v
    if fovCircle then fovCircle.Visible = settings.showFovCircle and v end
    if not v then aiming = false; currentTarget = nil end
end)

Tabs.Aimbot:AddButton({Title = "👁️ Hide Menu", Callback = function() Window:Toggle() end})
Tabs.Aimbot:AddButton({Title = "🔴 Close Script", Callback = function() closeScript() end})

Tabs.Aimbot:AddDropdown("AimPart", {Title = "Aim Part",
    Values = {"Auto", "Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    Default = 1}):OnChanged(function(v) settings.aimPart = v end)

Tabs.Aimbot:AddSlider("FOV", {Title = "FOV Size", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
    settings.fov = v; if fovCircle then fovCircle.Radius = v end
end)

Tabs.Aimbot:AddSlider("Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v)
    settings.smoothing = v / 100
end)

Tabs.Aimbot:AddSlider("Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v)
    settings.prediction = v / 100
end)

Tabs.Aimbot:AddToggle("WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.wallCheck = v end)

--> [< SILENT AIM TAB >] <--

Tabs.Silent:AddParagraph({
    Title = "🎭 Silent Aim",
    Content = "Назначьте клавишу и удерживайте её для активации (Hold) или переключения (Toggle)."
})

Tabs.Silent:AddToggle("SilentMaster", {
    Title = "Enable Silent Aim",
    Description = "Главный выключатель",
    Default = false
}):OnChanged(function(v)
    silentAim.MasterEnabled = v
    if v then enableSilentHook() else disableSilentHook() end
    Fluent:Notify({
        Title = v and "🎭 Silent Aim ВКЛ" or "🎭 Silent Aim ВЫКЛ",
        Content = v and ("Режим: " .. silentAim.Mode) or "Хук снят",
        Duration = 2
    })
end)

Tabs.Silent:AddDropdown("SilentMode", {
    Title = "Режим",
    Values = {"Hold", "Toggle"},
    Default = 1
}):OnChanged(function(v)
    silentAim.Mode = v
    Fluent:Notify({Title = "🎭 Режим: " .. v, Content = "Silent Aim режим изменён", Duration = 2})
end)

-- ✅ КНОПКА НАЗНАЧЕНИЯ КЛАВИШИ
local silentBindButton
silentBindButton = Tabs.Silent:AddButton({
    Title = "🎹 BIND: E",
    Description = "Нажмите, потом нажмите любую клавишу",
    Callback = function()
        silentAim.ListeningForBind = true
        pcall(function()
            silentBindButton:SetTitle("🎹 Нажмите клавишу...")
        end)
        Fluent:Notify({
            Title = "🎹 Назначение клавиши",
            Content = "Нажмите любую клавишу...",
            Duration = 3
        })
    end
})

Tabs.Silent:AddDropdown("SilentPart", {Title = "Target Part",
    Values = {"HumanoidRootPart", "Head", "UpperTorso", "Torso"},
    Default = 1}):OnChanged(function(v) silentAim.TargetPart = v end)

Tabs.Silent:AddSlider("SilentPred", {Title = "Prediction", Default = 19, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v)
    silentAim.Prediction = v / 100
end)

Tabs.Silent:AddSlider("SilentFOV", {Title = "FOV Radius", Default = 500, Min = 50, Max = 2000, Rounding = 0}):OnChanged(function(v)
    silentAim.FOV = v
end)

Tabs.Silent:AddToggle("SilentLog", {Title = "Log FireServer (debug)", Default = false}):OnChanged(function(v)
    silentAim.Logging = v
end)

Tabs.Silent:AddButton({
    Title = "🔄 Переустановить хук",
    Callback = function()
        disableSilentHook(); task.wait(0.3)
        if silentAim.MasterEnabled then enableSilentHook() end
        Fluent:Notify({Title = "🔄", Content = "Хук переустановлен", Duration = 2})
    end
})

--> [< ESP TAB >] <--

Tabs.ESP:AddToggle("ESPOn", {Title = "Enable ESP", Default = false}):OnChanged(function(v)
    esp.Enabled = v
    if v then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then createESP(p) end
        end
    else
        for p in pairs(esp.Objects) do removeESP(p) end
    end
end)

Tabs.ESP:AddToggle("EspName", {Title = "Show Name", Default = true}):OnChanged(function(v) esp.ShowName = v end)
Tabs.ESP:AddToggle("EspHP", {Title = "Show Health", Default = true}):OnChanged(function(v) esp.ShowHealth = v end)
Tabs.ESP:AddToggle("EspChi", {Title = "Show CHI", Default = true}):OnChanged(function(v) esp.ShowChi = v end)
Tabs.ESP:AddToggle("EspStam", {Title = "Show STAMINA", Default = true}):OnChanged(function(v) esp.ShowStamina = v end)
Tabs.ESP:AddToggle("EspDist", {Title = "Show Distance", Default = true}):OnChanged(function(v) esp.ShowDistance = v end)
Tabs.ESP:AddSlider("EspSize", {Title = "Text Size", Default = 14, Min = 8, Max = 24, Rounding = 0}):OnChanged(function(v) esp.TextSize = v end)

Tabs.ESP:AddButton({
    Title = "🔍 Скан моих значений (debug)",
    Description = "Покажет все Value объекты в консоли (F9)",
    Callback = function()
        debugScanPlayer()
        Fluent:Notify({Title = "🔍", Content = "Смотри F9 в консоли", Duration = 4})
    end
})

--> [< COLORS TAB >] <--

Tabs.Colors:AddParagraph({
    Title = "🎨 Colors",
    Content = "Формат: clamp(1-254) + опциональная инверсия (как в вирусе)."
})

Tabs.Colors:AddToggle("InvertColors", {
    Title = "Инвертировать цвет",
    Description = "Как в оригинальном вирусе",
    Default = true
}):OnChanged(function(v)
    colors.Invert = v
    Fluent:Notify({Title = "🎨", Content = "Инверсия: " .. (v and "ВКЛ" or "ВЫКЛ"), Duration = 2})
end)

Tabs.Colors:AddToggle("ClampColors", {
    Title = "Ограничить 1-254",
    Default = true
}):OnChanged(function(v) colors.Clamp = v end)

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

Tabs.Colors:AddColorpicker("CustomSkin", {Title = "Кастомный цвет скина", Default = Color3.fromRGB(255, 0, 0)})
Tabs.Colors:AddButton({
    Title = "✅ Применить кастомный скин",
    Callback = function()
        local c = Options.CustomSkin.Value
        if c then
            setSkinColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
            Fluent:Notify({Title = "🎨", Content = "Скин применён", Duration = 2})
        end
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

Tabs.Colors:AddColorpicker("CustomHair", {Title = "Кастомный цвет волос", Default = Color3.fromRGB(255, 0, 0)})
Tabs.Colors:AddButton({
    Title = "✅ Применить кастомные волосы",
    Callback = function()
        local c = Options.CustomHair.Value
        if c then
            setHairColor(math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
            Fluent:Notify({Title = "🎨", Content = "Волосы применены", Duration = 2})
        end
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
    
    -- ✅ ОБРАБОТКА НАЗНАЧЕНИЯ КЛАВИШИ
    if silentAim.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            silentAim.HoldKey = input.KeyCode
            silentAim.ListeningForBind = false
            
            pcall(function()
                silentBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name)
            end)
            
            Fluent:Notify({
                Title = "✅ Клавиша назначена",
                Content = "Silent Aim активируется на: " .. input.KeyCode.Name,
                Duration = 3
            })
        end
        return
    end
    
    -- Обработка Toggle режима Silent Aim
    if silentAim.MasterEnabled and silentAim.Mode == "Toggle" then
        if input.KeyCode == silentAim.HoldKey then
            silentAim.Enabled = not silentAim.Enabled
            Fluent:Notify({
                Title = silentAim.Enabled and "🎭 Silent Aim АКТИВЕН" or "🎭 Silent Aim ВЫКЛ",
                Content = "Toggle",
                Duration = 1
            })
        end
    end
    
    -- Aimbot
    if not aimbotEnabled then return end
    local k = settings.key == "BackSlash" and Enum.KeyCode.BackSlash or Enum[settings.key]
    if k and input.KeyCode == k then
        if settings.aimMode == "Hold" then aiming = true
        else aiming = not aiming; if not aiming then currentTarget = nil end end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp or not aimbotEnabled or settings.aimMode ~= "Hold" then return end
    local k = settings.key == "BackSlash" and Enum.KeyCode.BackSlash or Enum[settings.key]
    if k and input.KeyCode == k then aiming = false; currentTarget = nil end
end)

RunService.RenderStepped:Connect(function()
    if settings.rainbowLighting then
        lightingHue = (lightingHue + 0.005) % 1
        local c = Color3.fromHSV(lightingHue, 1, 1)
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    end
    
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
end)

RunService.Heartbeat:Connect(function(dt)
    if esp.Enabled then
        esp.LastUpdate = esp.LastUpdate + dt
        if esp.LastUpdate >= esp.UpdateRate then
            esp.LastUpdate = 0
            updateESP()
        end
    end
    
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
print("✅ Universal Shindo v6.1 загружен!")
print("🎭 Silent Aim: назначаемая клавиша через кнопку BIND")
print("🎨 Colors: clamp(1-254) + инверсия")
print("👁️ ESP: CHI/STAM")
print("📌 RightControl - скрыть меню")
print("====================================")
