--[[
    Universal Shindo Cheat v10.1
    ESP исправлен: привязка к Head, StudsOffset 2.5
    Kunai Hook: ловит все события (marker, kunai, namikaze, teleport)
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local shindoEvent
pcall(function() shindoEvent = LocalPlayer:WaitForChild("startevent", 8) end)

--> [< НАСТРОЙКИ >] <--

local settings = {
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

local ESP = {
    Enabled     = false,
    Visible     = false,
    Range       = math.huge,
    UpdateRate  = 1,
    Font        = Enum.Font.GothamBlack,
    Size        = 0.70,
    Width       = 1.60,
    Height      = 1.10,
    ShowName    = true,
    ShowHPBar   = true,
    ShowMeter   = true,
    ShowMD      = true,
    ShowHPText  = true,
    ShowDodge   = true,
    Keybind     = Enum.KeyCode.One,
    Whitelist   = {},
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

local silentFovCircle
pcall(function()
    silentFovCircle = Drawing.new("Circle")
    silentFovCircle.Thickness = 2
    silentFovCircle.Radius = silentAim.FOV
    silentFovCircle.Filled = false
    silentFovCircle.Color = silentAim.FovColor
    silentFovCircle.Transparency = 1
    silentFovCircle.Visible = false
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

local function searchStatInAttributes(root, exactNames, excludeKeywords)
    if not root then return nil end
    local found = nil
    pcall(function()
        for _, attr in ipairs(root:GetAttributes()) do
            local lower = string.lower(attr)
            local matches = false
            for _, en in ipairs(exactNames) do
                if lower == en or lower == "cur" .. en or lower == "current" .. en then
                    matches = true; break
                end
            end
            local excluded = false
            if matches then
                for _, ex in ipairs(excludeKeywords or {}) do
                    if lower:find(ex, 1, true) then excluded = true; break end
                end
            end
            if matches and not excluded then
                local v = root:GetAttribute(attr)
                if type(v) == "number" and v > 0 then
                    found = math.floor(v)
                    return
                end
            end
        end
    end)
    return found
end

local function searchStatInRoot(root, exactNames, excludeKeywords)
    if not root then return nil end
    local best = nil
    local bestScore = -1
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") then
            local lower = string.lower(obj.Name)
            local score = 0
            for _, en in ipairs(exactNames) do
                if lower == en then score = 100; break end
            end
            if score == 0 then
                for _, en in ipairs(exactNames) do
                    if lower == "cur" .. en or lower == "current" .. en then score = 90; break end
                end
            end
            if score == 0 then
                for _, en in ipairs(exactNames) do
                    if lower == en .. "value" or lower == "value" .. en then score = 80; break end
                end
            end
            local excluded = false
            if score > 0 then
                for _, ex in ipairs(excludeKeywords or {}) do
                    if lower:find(ex, 1, true) then excluded = true; break end
                end
            end
            if score > 0 and not excluded and score > bestScore then
                local ok, v = pcall(function() return tonumber(obj.Value) end)
                if ok and v then
                    bestScore = score
                    best = math.floor(v)
                end
            end
        end
    end
    return best
end

local function getPlayerChiStam(player)
    local chiNames = {"chakra", "chi"}
    local stamNames = {"stamina", "stam"}
    local exclude = {"max", "lvl", "level", "total", "exp", "rate", "regen", "cap", "limit", "booster", "cost", "drain"}
    
    local chi = searchStatInAttributes(player, chiNames, exclude)
    local stam = searchStatInAttributes(player, stamNames, exclude)
    
    if not chi then chi = searchStatInRoot(player, chiNames, exclude) end
    if not stam then stam = searchStatInRoot(player, stamNames, exclude) end
    
    if not chi and player.Character then
        chi = searchStatInAttributes(player.Character, chiNames, exclude)
            or searchStatInRoot(player.Character, chiNames, exclude)
    end
    if not stam and player.Character then
        stam = searchStatInAttributes(player.Character, stamNames, exclude)
            or searchStatInRoot(player.Character, stamNames, exclude)
    end
    
    if not chi then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then chi = searchStatInAttributes(pg, chiNames, exclude) or searchStatInRoot(pg, chiNames, exclude) end
    end
    if not stam then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then stam = searchStatInAttributes(pg, stamNames, exclude) or searchStatInRoot(pg, stamNames, exclude) end
    end
    
    return chi or 0, stam or 0
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

--> [< ESP (karmazynhub версия, исправлен) >] <--

local espData, espConns, espAcc = {}, {}, 0
local espIconCache = {}

local DODGE_NAMES = {
    taijutsudodge = true, blazedodge = true, rotationdodge = true,
    autododge = true, findcounterautododge = true, satoriren2 = true,
    spaceillusion = true, spaceillusionazure = true, spaceillusionrose = true,
    azim1 = true, shindai1 = true, flickercounter = true, intangible = true,
    riser1 = true, vine2 = true, raidensaberu3 = true, raidengold3 = true,
    borugai3skin = true,
}

local ESP_COLORS = {
    White = Color3.fromRGB(255,255,255), Black = Color3.fromRGB(0,0,0),
    Green = Color3.fromRGB(0,255,35), Yellow = Color3.fromRGB(255,242,0),
    Orange = Color3.fromRGB(255,145,0), Red = Color3.fromRGB(255,45,25),
    DarkRed = Color3.fromRGB(110,6,6), Purple = Color3.fromRGB(205,0,255),
    PurpleDark = Color3.fromRGB(95,0,170), PurpleBright = Color3.fromRGB(220,35,255),
    BarBg = Color3.fromRGB(5,7,9),
}

local BASE_WIDTH, BASE_NAME_H, BASE_BAR_H, BASE_BOX_H, GAP = 192, 23, 9, 19, 5
local DODGE_ICON_SIZE = 48

local function getRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
end
local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function lerp(a,b,t) t=math.clamp(t,0,1); return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t) end
local function hpColor(frac)
    frac = math.clamp(frac,0,1)
    if frac >= 0.66 then return lerp(ESP_COLORS.Yellow, ESP_COLORS.Green, (frac-0.66)/0.34)
    elseif frac >= 0.33 then return lerp(ESP_COLORS.Orange, ESP_COLORS.Yellow, (frac-0.33)/0.33)
    elseif frac >= 0.12 then return lerp(ESP_COLORS.Red, ESP_COLORS.Orange, (frac-0.12)/0.21) end
    return lerp(ESP_COLORS.DarkRed, ESP_COLORS.Red, frac/0.12)
end
local function mdPurple(md)
    md = tonumber(md) or 0
    if md <= 1200 then return lerp(ESP_COLORS.PurpleDark, ESP_COLORS.Purple, math.clamp(md/1200,0,1))
    elseif md <= 10000 then return lerp(ESP_COLORS.PurpleBright, ESP_COLORS.White, math.clamp((md-1200)/8800,0,1)) end
    return ESP_COLORS.White
end
local function short(v)
    v = math.floor(tonumber(v) or 0)
    if v >= 1e6 then return math.floor(v/1e6).."M" end
    if v >= 1e3 then return math.floor(v/1e3).."K" end
    return tostring(v)
end
local function distText(v)
    v = math.floor(tonumber(v) or 0)
    if v >= 1000 then
        local km = v/1000
        return (km == math.floor(km) and math.floor(km) or string.format("%.1f",km)) .. "KM"
    end
    return v.."M"
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
                if mode:IsA("IntValue") then return mode.Value
                elseif mode:IsA("NumberValue") then return mode.Value
                elseif mode:IsA("StringValue") then return tonumber(mode.Value) or 0
                else
                    local success, val = pcall(function() return mode.Value end)
                    if success and val ~= nil then return tonumber(val) or 0 end
                end
            end
        end
    end
    return 0
end

local function imageOf(inst)
    if not inst then return "" end
    if (inst:IsA("ImageButton") or inst:IsA("ImageLabel")) and inst.Image ~= "" then return inst.Image end
    if (inst:IsA("Decal") or inst:IsA("Texture")) and inst.Texture ~= "" then return inst.Texture end
    if inst:IsA("ValueBase") then local v = tostring(inst.Value); if v ~= "" then return v end end
    return ""
end
local function deepImage(root, name)
    if not root then return "" end
    for _, d in ipairs(root:GetDescendants()) do
        if string.lower(d.Name) == name then
            local img = imageOf(d)
            if img ~= "" then return img end
            for _, c in ipairs(d:GetDescendants()) do
                local cn = string.lower(c.Name)
                if cn == "img" or cn == "icon" then local i = imageOf(c); if i ~= "" then return i end end
            end
            for _, c in ipairs(d:GetDescendants()) do local i = imageOf(c); if i ~= "" then return i end end
        end
    end
    return ""
end
local function getJutsuIcon(name)
    if espIconCache[name] ~= nil then return espIconCache[name] end
    local img = ""
    pcall(function()
        local menu = ReplicatedStorage.Main.ingame.Menu
        local jt = menu and menu:FindFirstChild("JutsuTab")
        if jt then img = deepImage(jt, name) end
        if img == "" and menu then img = deepImage(menu, name) end
    end)
    if img == "" then pcall(function() img = deepImage(ReplicatedStorage:FindFirstChild("alljutsu"), name) end) end
    if img == "" then pcall(function() img = deepImage(ReplicatedStorage, name) end) end
    if img:match("^%d+$") then img = "rbxassetid://" .. img end
    espIconCache[name] = img
    return img
end

local function scanDodges(p)
    local res = {}
    local keys = p:FindFirstChild("statz") and p.statz:FindFirstChild("keys")
    if not keys then return res end
    for _, slot in ipairs(keys:GetChildren()) do
        if slot:IsA("ValueBase") then
            local nm = string.lower(tostring(slot.Value))
            if DODGE_NAMES[nm] then res[nm] = slot:FindFirstChild("cooldown") or false end
        end
    end
    return res
end

local function createIconRow(holder, name, size)
    local f = Instance.new("Frame")
    f.Name = "J_"..name; f.Size = UDim2.new(0,size,0,size)
    f.BackgroundTransparency = 1; f.Parent = holder
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"; icon.Size = UDim2.fromScale(1,1); icon.BackgroundTransparency = 1
    icon.Image = getJutsuIcon(name); icon.Parent = f
    local cd = Instance.new("TextLabel")
    cd.Name = "CD"; cd.Size = UDim2.fromScale(0.6,0.6); cd.Position = UDim2.fromScale(0.2,0.2)
    cd.BackgroundTransparency = 1; cd.Font = Enum.Font.GothamBlack; cd.TextScaled = true
    cd.TextColor3 = Color3.fromRGB(255,80,80); cd.TextStrokeColor3 = ESP_COLORS.Black
    cd.TextStrokeTransparency = 0.3; cd.Text = ""; cd.ZIndex = 2; cd.Parent = f
    return { frame=f, icon=icon, cd=cd }
end

local function makeText(parent, size, pos, textSize)
    local t = Instance.new("TextLabel")
    t.Size = size; t.Position = pos; t.BackgroundTransparency = 1
    t.TextColor3 = ESP_COLORS.White; t.TextStrokeColor3 = ESP_COLORS.Black
    t.TextStrokeTransparency = 0.58; t.Font = ESP.Font
    t.TextSize = textSize or 14; t.TextXAlignment = Enum.TextXAlignment.Center
    t.TextYAlignment = Enum.TextYAlignment.Center; t.TextTruncate = Enum.TextTruncate.AtEnd
    t.Parent = parent
    return t
end
local function outlineBox(parent, x, y, w, h, text, strokeColor)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0,w,0,h); box.Position = UDim2.new(0,x,0,y)
    box.BackgroundTransparency = 1; box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,5)
    local stroke = Instance.new("UIStroke")
    stroke.Color = strokeColor or ESP_COLORS.White; stroke.Transparency = 0.28; stroke.Thickness = 1; stroke.Parent = box
    local label = makeText(box, UDim2.fromScale(1,1), UDim2.fromScale(0,0), math.max(12, math.floor(h*0.90)))
    label.Text = string.upper(text); label.TextStrokeTransparency = 0.62
    return box, label, stroke
end

local function espShouldShow(p, d)
    if not ESP.Enabled or not ESP.Visible then return false end
    if not d or not d.root or not d.root.Parent then return false end
    if not isWhitelisted(p) then return false end
    return true
end
local function clearPlayer(p)
    local d = espData[p]
    if d and d.gui then pcall(function() d.gui:Destroy() end) end
    espData[p] = nil
end

local function getLayout()
    local w = math.floor(BASE_WIDTH * ESP.Width)
    local nameH = math.max(12, math.floor(BASE_NAME_H * ESP.Height))
    local barH  = math.max(5,  math.floor(BASE_BAR_H  * ESP.Height))
    local boxH  = math.max(13, math.floor(BASE_BOX_H  * ESP.Height))
    local y = 0
    local nameY = y
    if ESP.ShowName then y += nameH + math.floor(5 * ESP.Height) end
    local barY = y
    if ESP.ShowHPBar then y += barH + math.floor(7 * ESP.Height) end
    local statsY = y
    local statCount = 0
    if ESP.ShowMeter then statCount += 1 end
    if ESP.ShowMD then statCount += 1 end
    if ESP.ShowHPText then statCount += 1 end
    if statCount > 0 then y += boxH + 4 end
    return w, nameH, barH, boxH, nameY, barY, statsY, math.max(18,y), statCount
end

local function createPlayerESP(p, char)
    if p == LocalPlayer then return end
    if not isWhitelisted(p) then return end
    if espData[p] and espData[p].gui and espData[p].gui.Parent then return end

    local root = getRoot(char)
    local hum  = getHumanoid(char)
    local t0 = os.clock()
    while char and char.Parent and (not root or not hum) and os.clock()-t0 < 6 do
        task.wait(0.05); root = getRoot(char); hum = getHumanoid(char)
    end
    if not char or not char.Parent or not root or not hum then return end

    local w, nameH, barH, boxH, nameY, barY, statsY, totalH, statCount = getLayout()

    -- ✅ ИСПРАВЛЕНО: привязка к Head
    local head = char:FindFirstChild("Head") or root
    local gui = Instance.new("BillboardGui")
    gui.Name = "karmazynESP"; gui.Size = UDim2.new(0,w,0,totalH)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.MaxDistance = ESP.Range
    gui.Adornee = head
    gui.Enabled = espShouldShow(p, {root=root})
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromScale(1,1); holder.BackgroundTransparency = 1; holder.Parent = gui
    local scale = Instance.new("UIScale"); scale.Scale = ESP.Size; scale.Parent = holder

    local nameLabel
    if ESP.ShowName then
        local nameBox = Instance.new("Frame")
        nameBox.Size = UDim2.new(1,0,0,nameH); nameBox.Position = UDim2.new(0,0,0,nameY)
        nameBox.BackgroundTransparency = 1; nameBox.Parent = holder
        Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0,5)
        local ns = Instance.new("UIStroke"); ns.Color = ESP_COLORS.White; ns.Transparency = 0.35; ns.Thickness = 1; ns.Parent = nameBox
        nameLabel = makeText(nameBox, UDim2.fromScale(1,1), UDim2.fromScale(0,0), math.max(14, math.floor(nameH*0.92)))
        nameLabel.Text = string.upper(p.Name)
    end

    local hpBar
    if ESP.ShowHPBar then
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1,0,0,barH); barBg.Position = UDim2.new(0,0,0,barY)
        barBg.BackgroundColor3 = ESP_COLORS.BarBg; barBg.BorderSizePixel = 0; barBg.ClipsDescendants = true; barBg.Parent = holder
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1,0)
        local bs = Instance.new("UIStroke"); bs.Color = ESP_COLORS.White; bs.Transparency = 0.45; bs.Thickness = 1; bs.Parent = barBg
        hpBar = Instance.new("Frame")
        hpBar.Size = UDim2.fromScale(1,1); hpBar.BackgroundColor3 = ESP_COLORS.Green; hpBar.BorderSizePixel = 0; hpBar.Parent = barBg
        Instance.new("UICorner", hpBar).CornerRadius = UDim.new(1,0)
    end

    local distLabel, mdLabel, mdStroke, mdBox, hpLabel
    if statCount > 0 then
        local statW = math.floor((w - GAP*(statCount-1)) / statCount)
        local x = 0
        if ESP.ShowMeter then local _,label = outlineBox(holder, x, statsY, statW, boxH, "...M", ESP_COLORS.White); distLabel = label; x += statW + GAP end
        if ESP.ShowMD then
            local box,label,stroke = outlineBox(holder, x, statsY, statW, boxH, "MD ...", ESP_COLORS.White)
            box.BackgroundColor3 = ESP_COLORS.Purple; box.BackgroundTransparency = 0.48
            mdLabel = label; mdStroke = stroke; mdBox = box; x += statW + GAP
        end
        if ESP.ShowHPText then local _,label = outlineBox(holder, x, statsY, statW, boxH, "HP ...", ESP_COLORS.White); hpLabel = label end
    end

    local dodgeHolder, dodgeRows
    if ESP.ShowDodge then
        dodgeHolder = Instance.new("Frame")
        dodgeHolder.Name = "DodgeHolder"; dodgeHolder.Size = UDim2.new(0, DODGE_ICON_SIZE, 1, 0)
        -- ✅ ИСПРАВЛЕНО: привязка к правому краю, не зависит от w
        dodgeHolder.Position = UDim2.new(1, 6, 0, 0)
        dodgeHolder.BackgroundTransparency = 1; dodgeHolder.Parent = holder
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,3); ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.HorizontalAlignment = Enum.HorizontalAlignment.Left; ll.VerticalAlignment = Enum.VerticalAlignment.Center; ll.Parent = dodgeHolder
        dodgeRows = {}
    end

    espData[p] = {
        gui=gui, char=char, root=root, hum=hum, head=head,
        hpBar=hpBar, hpLabel=hpLabel, distLabel=distLabel,
        mdLabel=mdLabel, mdStroke=mdStroke, mdBox=mdBox, nameLabel=nameLabel,
        dodgeHolder=dodgeHolder, dodgeRows=dodgeRows,
        hp=-1, maxHp=-1, md=-1, dist=-1,
    }
end

local function updateDodge(p, d)
    if not d.dodgeHolder then return end
    local active = scanDodges(p)
    for nm, cdVal in pairs(active) do
        local row = d.dodgeRows[nm]
        if not row then row = createIconRow(d.dodgeHolder, nm, DODGE_ICON_SIZE); d.dodgeRows[nm] = row end
        row.frame.Visible = true
        local rem = (cdVal and tonumber(cdVal.Value)) or 0
        if rem > 0 then row.cd.Text = tostring(rem); row.icon.ImageTransparency = 0.6
        else row.cd.Text = ""; row.icon.ImageTransparency = 0 end
    end
    for nm, row in pairs(d.dodgeRows) do if not active[nm] then row.frame.Visible = false end end
end

local function rebuildESP()
    for p in pairs(espData) do clearPlayer(p) end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and isWhitelisted(p) then task.spawn(createPlayerESP, p, p.Character) end
    end
end

local function updateESP()
    if not ESP.Enabled or not ESP.Visible then return end
    local myRoot = LocalPlayer.Character and getRoot(LocalPlayer.Character)
    for p,d in pairs(espData) do
        if not p.Parent or not d.char or not d.char.Parent then clearPlayer(p); continue end
        if not isWhitelisted(p) then
            if d.gui then d.gui.Enabled = false end
            continue
        end
        -- ✅ Обновляем Head если персонаж изменился
        if not d.head or not d.head.Parent then 
            d.head = d.char:FindFirstChild("Head") or getRoot(d.char)
            if d.gui then d.gui.Adornee = d.head end
        end
        if not d.root or not d.root.Parent then d.root = getRoot(d.char) end
        if not d.hum or not d.hum.Parent then d.hum = getHumanoid(d.char) end
        if not d.gui or not d.root or not d.hum or d.hum.Health <= 0 then
            if d.gui then d.gui.Enabled = false end; continue
        end
        local show = espShouldShow(p, d)
        if d.gui.Enabled ~= show then d.gui.Enabled = show end
        if not show then continue end

        local hp = math.floor(d.hum.Health)
        local maxHp = math.max(1, math.floor(d.hum.MaxHealth))
        local md = getModeValue(p)
        local dist = myRoot and math.floor((d.root.Position - myRoot.Position).Magnitude) or 0
        local bucket = math.floor(dist/25)*25
        local frac = math.clamp(hp/maxHp, 0, 1)

        if d.hp ~= hp or d.maxHp ~= maxHp then
            d.hp = hp; d.maxHp = maxHp
            if d.hpBar then d.hpBar.Size = UDim2.new(frac,0,1,0); d.hpBar.BackgroundColor3 = hpColor(frac) end
            if d.hpLabel then d.hpLabel.Text = string.upper("HP "..short(hp)) end
        end
        if d.md ~= md then
            d.md = md
            if d.mdLabel then d.mdLabel.Text = string.upper("MD "..tostring(md)) end
            local c = mdPurple(md)
            if d.mdBox then d.mdBox.BackgroundColor3 = c; d.mdBox.BackgroundTransparency = 0.45 end
        end
        if d.dist ~= bucket then
            d.dist = bucket
            if d.distLabel then d.distLabel.Text = string.upper(distText(bucket)) end
        end
        if d.dodgeHolder then updateDodge(p, d) end
    end
end

local function espWatch(p)
    if p == LocalPlayer then return end
    if espConns[p] then for _,c in ipairs(espConns[p]) do pcall(function() c:Disconnect() end) end end
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

for _,p in ipairs(Players:GetPlayers()) do espWatch(p) end
Players.PlayerAdded:Connect(espWatch)
Players.PlayerRemoving:Connect(function(p) clearPlayer(p) end)
RunService.Heartbeat:Connect(function(dt)
    if not ESP.Enabled or not ESP.Visible then return end
    espAcc += dt
    if espAcc >= ESP.UpdateRate then espAcc = 0; updateESP() end
end)

--> [< KUNAI MARKER HACK >] <--

local savedEnemyPos = nil
local DEBUG_DEEP = true

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
    depth = depth or 0
    prefix = prefix or ""
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
            
            -- ✅ Ловим ЛЮБОЕ событие со словами marker, kunai, namikaze, teleport
            local isMarkerEvent = nameLower:find("marker", 1, true) 
                or nameLower:find("kunai", 1, true) 
                or nameLower:find("namikaze", 1, true)
            
            local isTeleportEvent = nameLower:find("teleport", 1, true)
            
            if method == "FireServer" and (isMarkerEvent or isTeleportEvent) then
                if markerClick.Debug then
                    print("[HOOK] " .. tostring(self.Name) .. " | args: " .. #args)
                    for i, a in ipairs(args) do
                        print("  [" .. i .. "] = " .. typeof(a) .. " " .. tostring(a))
                        if type(a) == "table" then
                            deepLog(a, "     ", 0)
                        end
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
                    else
                        if markerClick.Debug then
                            print("[HOOK] ⚠️ Враг не найден")
                        end
                    end
                end
            end
            
            return oldKunaiNamecall(self, ...)
        end)
        setreadonly(kunaiMetaT, true)
        kunaiHook = true
        print("✅ Kunai Hook установлен (мульти-событие)")
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
        if not part.Parent then continue end
        
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

--> [< АИМБОТ >] <--

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
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local originPos = myRoot.Position
    
    local bestT, bestS = nil, math.huge
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or isSameTeam(p) then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        
        local tp = getBestAimPart(char)
        if not tp then continue end
        if settings.wallCheck and not isVisible(char) then continue end
        
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
    Fluent:Notify({Title = "⚡ Force Reconnect", Content = "Принудительное переподключение...", Duration = 3})
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
    Title = "Universal Shindo v10.1",
    SubTitle = "ESP Fix • Kunai Hook Fix",
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

Tabs.Aimbot:AddToggle("PriorClose", {Title = "Prioritize Close Targets", Default = true}):OnChanged(function(v)
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

local markerSection = Tabs.Aimbot:AddSection("Kunai Marker Hack")

markerSection:AddToggle("MarkerClick", {
    Title = "🌀 Enable Marker Hack",
    Description = "Зажми клавишу + клик → маркер над головой",
    Default = false
}):OnChanged(function(v)
    markerClick.Enabled = v
    if v then
        enableKunaiHook()
        Fluent:Notify({Title = "🌀 Marker ВКЛ", Content = "Зажми " .. markerClick.ModifierKey.Name, Duration = 3})
    else
        disableKunaiHook()
        Fluent:Notify({Title = "🌀 Marker ВЫКЛ", Content = "Деактивировано", Duration = 2})
    end
end)

local markerBindBtn
markerBindBtn = markerSection:AddButton({
    Title = "🎹 Modifier Key: " .. markerClick.ModifierKey.Name,
    Callback = function()
        markerClick.ListeningForBind = true
        pcall(function() markerBindBtn:SetTitle("🎹 Нажмите клавишу...") end)
    end
})

markerSection:AddSlider("MarkerHeight", {
    Title = "📏 Marker Height",
    Description = "Высота над головой (studs)",
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 0
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
        pcall(function() silentBindButton:SetTitle("🎹 Нажмите клавишу...") end)
    end
})

Tabs.Silent:AddDropdown("SilentPart", {Title = "Target Part",
    Values = {"HumanoidRootPart", "Head", "UpperTorso", "Torso"},
    Default = 1}):OnChanged(function(v) silentAim.TargetPart = v end)

Tabs.Silent:AddSlider("SilentFOV", {Title = "FOV Radius", Default = 500, Min = 50, Max = 2000, Rounding = 0}):OnChanged(function(v)
    silentAim.FOV = v
    if silentFovCircle then silentFovCircle.Radius = v end
end)

Tabs.Silent:AddToggle("SilentShowFOV", {Title = "Show Silent FOV Circle", Default = true}):OnChanged(function(v)
    silentAim.ShowFovCircle = v
end)

Tabs.Silent:AddColorpicker("SilentFovColor", {Title = "Silent FOV Color", Default = Color3.fromRGB(100, 200, 255)}):OnChanged(function(c)
    silentAim.FovColor = c
    if silentFovCircle then silentFovCircle.Color = c end
end)

Tabs.Silent:AddSlider("SilentMaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v)
    silentAim.MaxDistance = v
end)

Tabs.Silent:AddToggle("SilentPriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v)
    silentAim.PrioritizeClose = v
end)

Tabs.Silent:AddToggle("SilentMode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
    silentAim.Mode360 = v
    if v and silentFovCircle then silentFovCircle.Visible = false end
end)

Tabs.Silent:AddSlider("SilentPred", {Title = "Prediction", Default = 19, Min = 0, Max = 50, Rounding = 0}):OnChanged(function(v)
    silentAim.Prediction = v / 100
end)

Tabs.Silent:AddToggle("SilentLog", {Title = "Log FireServer (debug)", Default = false}):OnChanged(function(v)
    silentAim.Logging = v
end)

Tabs.Silent:AddButton({
    Title = "🔄 Переустановить хук",
    Callback = function()
        disableSilentHook(); task.wait(0.3)
        if silentAim.MasterEnabled then enableSilentHook() end
    end
})

--> [< ESP TAB >] <--

Tabs.ESP:AddToggle("ESPOn", {
    Title = "Enable ESP",
    Description = "Мастер-включение ESP",
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

local espBindBtn
espBindBtn = Tabs.ESP:AddButton({
    Title = "🎹 ESP Keybind: " .. ESP.Keybind.Name,
    Callback = function()
        ESP.ListeningForBind = true
        pcall(function() espBindBtn:SetTitle("🎹 Нажмите клавишу...") end)
    end
})

Tabs.ESP:AddToggle("EspName", {Title = "Show Name", Default = true}):OnChanged(function(v) ESP.ShowName = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspHPBar", {Title = "Show HP Bar", Default = true}):OnChanged(function(v) ESP.ShowHPBar = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspHPText", {Title = "Show HP Text", Default = true}):OnChanged(function(v) ESP.ShowHPText = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspMeter", {Title = "Show Distance", Default = true}):OnChanged(function(v) ESP.ShowMeter = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspMD", {Title = "Show MD (Mode)", Default = true}):OnChanged(function(v) ESP.ShowMD = v; rebuildESP() end)
Tabs.ESP:AddToggle("EspDodge", {Title = "Show Dodge Icons", Default = true}):OnChanged(function(v) ESP.ShowDodge = v; rebuildESP() end)

Tabs.ESP:AddSlider("EspSize", {Title = "ESP Size", Default = 70, Min = 20, Max = 300, Rounding = 0}):OnChanged(function(v)
    ESP.Size = v / 100; rebuildESP()
end)

Tabs.ESP:AddSlider("EspWidth", {Title = "ESP Width", Default = 160, Min = 40, Max = 400, Rounding = 0}):OnChanged(function(v)
    ESP.Width = v / 100; rebuildESP()
end)

Tabs.ESP:AddSlider("EspHeight", {Title = "ESP Height", Default = 110, Min = 30, Max = 300, Rounding = 0}):OnChanged(function(v)
    ESP.Height = v / 100; rebuildESP()
end)

Tabs.ESP:AddSlider("EspRate", {Title = "Update Rate (ms)", Default = 1000, Min = 100, Max = 2000, Rounding = 50}):OnChanged(function(v)
    ESP.UpdateRate = v / 1000
end)

local espWhitelistSection = Tabs.ESP:AddSection("Player Whitelist (пусто = все)")

Tabs.ESP:AddButton({
    Title = "🔄 Обновить список игроков",
    Callback = function()
        local playerList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(playerList, p)
            end
        end
        
        if #playerList == 0 then
            Fluent:Notify({Title = "ℹ️", Content = "Нет других игроков", Duration = 3})
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
                    Fluent:Notify({
                        Title = "✓",
                        Content = p.Name .. (ESP.Whitelist[p.Name] and " добавлен" or " убран"),
                        Duration = 2
                    })
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

Tabs.Server:AddButton({Title = "🔄 Server Hop", Description = "Переход на другой сервер", Callback = function() serverHop() end})
Tabs.Server:AddButton({Title = "🔁 Rejoin Server", Description = "Переподключение", Callback = function() rejoinServer() end})
Tabs.Server:AddButton({Title = "⚡ Force Reconnect", Description = "Принудительное переподключение", Callback = function() forceReconnect() end})

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
    
    if ESP.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            ESP.Keybind = input.KeyCode
            ESP.ListeningForBind = false
            pcall(function() espBindBtn:SetTitle("🎹 ESP Keybind: " .. input.KeyCode.Name) end)
            Fluent:Notify({Title = "✅ ESP Bind", Content = input.KeyCode.Name, Duration = 3})
        end
        return
    end
    
    if input.KeyCode == ESP.Keybind then
        ESP.Visible = not ESP.Visible
        ESP.Enabled = ESP.Visible
        if ESP.Visible then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then espWatch(p) end
            end
            rebuildESP()
        else
            for p in pairs(espData) do clearPlayer(p) end
        end
        Fluent:Notify({
            Title = ESP.Visible and "👁️ ESP ВКЛ" or "👁️ ESP ВЫКЛ",
            Content = "Keybind: " .. ESP.Keybind.Name,
            Duration = 2
        })
    end
    
    if markerClick.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            markerClick.ModifierKey = input.KeyCode
            markerClick.ListeningForBind = false
            pcall(function() markerBindBtn:SetTitle("🎹 Modifier Key: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    if silentAim.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            silentAim.HoldKey = input.KeyCode
            silentAim.ListeningForBind = false
            pcall(function() silentBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    if settings.ListeningForAimBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aimKey = input.KeyCode
            settings.ListeningForAimBind = false
            pcall(function() aimBindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
        end
        return
    end
    
    if silentAim.MasterEnabled and silentAim.Mode == "Toggle" then
        if input.KeyCode == silentAim.HoldKey then
            silentAim.Enabled = not silentAim.Enabled
        end
    end
    
    if aimbotEnabled and input.KeyCode == settings.aimKey then
        if settings.aimMode == "Hold" then
            aiming = true
        else
            aiming = not aiming
            if not aiming then currentTarget = nil end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if aimbotEnabled and settings.aimMode == "Hold" and input.KeyCode == settings.aimKey then
        aiming = false
        currentTarget = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if settings.rainbowLighting then
        lightingHue = (lightingHue + 0.005) % 1
        local c = Color3.fromHSV(lightingHue, 1, 1)
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    end
    
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
    
    if silentAim.MasterEnabled and silentFovCircle and silentAim.ShowFovCircle and not silentAim.Mode360 then
        silentFovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        silentFovCircle.Radius = silentAim.FOV
        silentFovCircle.Color = silentAim.FovColor
        silentFovCircle.Visible = silentAim.Enabled
    elseif silentFovCircle then
        silentFovCircle.Visible = false
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
print("✅ Universal Shindo v10.1 загружен!")
print("👁️ ESP: привязка к Head, StudsOffset 2.5")
print("🌀 Kunai Hook: мульти-событие (marker/kunai/namikaze)")
print("🎭 Silent Aim: \\ (BackSlash)")
print("🎯 Aimbot: \\ (BackSlash)")
print("📌 RightControl - скрыть меню")
print("====================================")
