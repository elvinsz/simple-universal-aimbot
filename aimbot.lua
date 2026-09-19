--[[
    Flumium Client v1.4
    ✅ Базовая версия: Universal Shindo v10.1 (исправная)
    ✅ Добавлены новые функции из Flumium Client v1.4
    ✅ Aimbot 2 (клавиша [1]), Performance, Server Tools
    ✅ Убран кейбинд с ESP
    ✅ Название в меню: Flumium Client v1.4 2 Aimbots • ESP • Server Tools • Performance
]]

-- ============================================================
-- DIAGNOSTICS
-- ============================================================
local function __dbg(msg) print("[Flumium] " .. tostring(msg)) end
__dbg("start | PlaceId=" .. tostring(game.PlaceId) .. " | JobId=" .. tostring(game.JobId))

-- ============================================================
-- SESSION TOKEN + INIT GUARD
-- ============================================================
local __SESSION = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
getgenv().Flumium_SessionToken = __SESSION
__dbg("session = " .. __SESSION)

local function __isCurrentSession()
    return getgenv().Flumium_SessionToken == __SESSION
end

local __lastInit = getgenv().Flumium_LastInitTime or 0
local __now = os.clock()
if __now - __lastInit < 1.5 then
    warn("[Flumium] двойной запуск за <1.5с — пропускаем (init guard)")
    return
end
getgenv().Flumium_LastInitTime = __now

-- ============================================================
-- UNLOAD PREVIOUS INSTANCE (JobId-aware)
-- ============================================================
local __prevJobId = getgenv().Flumium_LastJobId
local __currJobId = game.JobId
local __sameServer = (__prevJobId ~= nil
                    and __prevJobId == __currJobId
                    and __currJobId ~= "")

if __sameServer then
    __dbg("same server — unloading previous instance")
    if type(getgenv().Flumium_Unload) == "function" then
        pcall(getgenv().Flumium_Unload)
        __dbg("previous cleanup OK")
    end
else
    __dbg("new server / first run — skipping cleanup")
end

if getgenv().Flumium_TeleportFailedConn then
    pcall(function() getgenv().Flumium_TeleportFailedConn:Disconnect() end)
    getgenv().Flumium_TeleportFailedConn = nil
end

getgenv().Flumium_LoopsRunning = false

getgenv().Flumium_Unload = nil
getgenv().Flumium_LastJobId = __currJobId
getgenv().Fluent = nil
getgenv().SaveManager = nil
getgenv().InterfaceManager = nil
if _G then
    _G.Fluent = nil
    _G.SaveManager = nil
    _G.InterfaceManager = nil
end

if __sameServer then
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local Players = game:GetService("Players")
        local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
        for _, parent in ipairs({CoreGui, pg}) do
            if parent then
                for _, name in ipairs({"Fluent", "FluentUI", "FluentGui", "Flumium"}) do
                    local obj = parent:FindFirstChild(name)
                    if obj then obj:Destroy() end
                end
            end
        end
    end)

    for _, key in ipairs({"Flumium_Drawing_Fov1", "Flumium_Drawing_Fov2", "Flumium_Drawing_FovS"}) do
        local d = getgenv()[key]
        if d then pcall(function() d:Remove() end) end
        getgenv()[key] = nil
    end

    pcall(function()
        if type(setfpscap) == "function" then setfpscap(60) end
    end)
end

-- ============================================================
-- SAFE RE-EXECUTE TRACKER
-- ============================================================
local __CLEANUP = { conns = {}, hooks = {}, insts = {}, fns = {}, done = false }
local function __regConn(c)  table.insert(__CLEANUP.conns, c);  return c end
local function __regHook(fn) table.insert(__CLEANUP.hooks, fn) end
local function __regInst(i)  table.insert(__CLEANUP.insts, i);  return i end
local function __regFn(fn)   table.insert(__CLEANUP.fns, fn)   end

local function __runCleanup()
    if __CLEANUP.done then return end
    __CLEANUP.done = true
    for _, c in ipairs(__CLEANUP.conns) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(__CLEANUP.fns) do pcall(fn) end
    for _, fn in ipairs(__CLEANUP.hooks) do pcall(fn) end
    for _, i in ipairs(__CLEANUP.insts) do pcall(function() i:Destroy() end) end
    __CLEANUP.conns, __CLEANUP.fns, __CLEANUP.hooks, __CLEANUP.insts = {}, {}, {}, {}
end

getgenv().Flumium_Unload = __runCleanup

-- ============================================================
-- LOAD UI LIBRARY
-- ============================================================
local FLUENT_URL    = "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
local FLUENT_CACHE  = "Flumium_Fluent.lua"
local SAVEMGR_URL   = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
local IFACEMGR_URL  = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"

local FluentSource = nil

if type(readfile) == "function" and type(isfile) == "function" then
    local ok, exists = pcall(isfile, FLUENT_CACHE)
    if ok and exists then
        local ok2, content = pcall(readfile, FLUENT_CACHE)
        if ok2 and type(content) == "string" and #content > 1000 then
            FluentSource = content
            __dbg("Fluent from cache (" .. #content .. " bytes)")
        end
    end
end

if not FluentSource then
    __dbg("downloading Fluent...")
    local ok, result = pcall(function()
        return game:HttpGet(FLUENT_URL, true)
    end)
    if ok and type(result) == "string" and #result > 1000 then
        FluentSource = result
        __dbg("Fluent downloaded (" .. #result .. " bytes)")
        if type(writefile) == "function" then
            pcall(function() writefile(FLUENT_CACHE, result) end)
        end
    else
        __dbg("Fluent download FAILED: " .. tostring(result))
    end
end

if not FluentSource then
    warn("[Flumium] ❌ Не удалось загрузить Fluent. Проверь доступ к github.com.")
    warn("[Flumium]     Можно скачать main.lua вручную → " .. FLUENT_CACHE)
    return
end

local FluentFn, compileErr = loadstring(FluentSource)
if type(FluentFn) ~= "function" then
    warn("[Flumium] ❌ Fluent compile error: " .. tostring(compileErr))
    return
end

local Fluent = FluentFn()
if type(Fluent) ~= "table" then
    warn("[Flumium] ❌ Fluent() вернул " .. type(Fluent))
    return
end

__dbg("Fluent OK")

local SaveManager = nil
local InterfaceManager = nil

pcall(function()
    local src = game:HttpGet(SAVEMGR_URL, true)
    if type(src) == "string" and #src > 100 then
        SaveManager = loadstring(src)()
    end
end)

pcall(function()
    local src = game:HttpGet(IFACEMGR_URL, true)
    if type(src) == "string" and #src > 100 then
        InterfaceManager = loadstring(src)()
    end
end)

if not SaveManager then __dbg("SaveManager — не загружен") end
if not InterfaceManager then __dbg("InterfaceManager — не загружен") end

-- ============================================================
-- SERVICES
-- ============================================================
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

-- ============================================================
-- HISTORY STORAGE
-- ============================================================
local HISTORY_FILE = "FlumiumJobHistory.json"
local HISTORY_MAX = 10

local function hasFs()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function loadHistory()
    if not hasFs() then return {} end
    local ok, exists = pcall(isfile, HISTORY_FILE)
    if not ok or not exists then return {} end
    local ok2, content = pcall(readfile, HISTORY_FILE)
    if not ok2 or type(content) ~= "string" or content == "" then return {} end
    local ok3, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok3 or type(data) ~= "table" then return {} end
    return data
end

local function saveHistory(list)
    if not hasFs() then return end
    pcall(function() writefile(HISTORY_FILE, HttpService:JSONEncode(list)) end)
end

local function pushHistory(jobId)
    if not jobId or jobId == "" then return loadHistory() end
    local list = loadHistory()
    for i = #list, 1, -1 do
        if list[i].id == jobId then table.remove(list, i) end
    end
    table.insert(list, 1, { id = jobId, place = game.PlaceId, players = #Players:GetPlayers(), time = os.time() })
    while #list > HISTORY_MAX do table.remove(list) end
    saveHistory(list)
    return list
end

local function fmtTime(t)
    if not t then return "--:--" end
    local ok, d = pcall(os.date, "*t", t)
    if not ok or not d then return "--:--" end
    return string.format("%02d:%02d", d.hour, d.min)
end

-- ============================================================
-- TELEPORT
-- ============================================================
local __teleportBusy = false

local function teleportToJob(targetId, labelText)
    if __teleportBusy then
        Fluent:Notify({Title = "⏳", Content = "Телепорт уже в процессе...", Duration = 2})
        return
    end
    if not targetId or targetId == "" then
        Fluent:Notify({Title = "❌", Content = "Пустой Job ID", Duration = 3})
        return
    end
    if targetId == game.JobId then
        Fluent:Notify({Title = "ℹ️", Content = "Ты уже на этом сервере", Duration = 3})
        return
    end

    __teleportBusy = true
    pushHistory(game.JobId)

    Fluent:Notify({
        Title = "➡️ " .. (labelText or "JOIN"),
        Content = targetId:sub(1, 8) .. "...",
        Duration = 2
    })

    task.spawn(function()
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, LocalPlayer)
        end)
        if not ok then
            pcall(function()
                local opts = Instance.new("TeleportOptions")
                opts.ServerInstanceId = targetId
                TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer}, opts)
            end)
        end
        task.wait(3)
        __teleportBusy = false
    end)
end

-- ============================================================
-- CONFIG
-- ============================================================
local settings = {
    fov = 300, smoothing = 0.15, prediction = 0.065,
    wallCheck = false, teamCheck = false, aimPart = "Auto", aimMode = "Hold",
    aimKey = Enum.KeyCode.BackSlash, ListeningForAimBind = false,
    showFovCircle = true, maxDistance = 0, prioritizeClose = true, mode360 = false,
    fovColor = Color3.fromRGB(255, 0, 0), targetedColor = Color3.fromRGB(0, 255, 0),
    rainbowFov = false,

    aim2Fov = 300, aim2Smoothing = 0.15, aim2Prediction = 0.065,
    aim2WallCheck = false, aim2TeamCheck = false, aim2Mode = "Hold",
    aim2Key = Enum.KeyCode.One, aim2ListeningForBind = false,
    aim2ShowFovCircle = true, aim2MaxDistance = 0, aim2PrioritizeClose = true,
    aim2Mode360 = false, aim2HeightOffset = 3,
    aim2FovColor = Color3.fromRGB(255, 165, 0), aim2TargetedColor = Color3.fromRGB(255, 255, 0),
    aim2RainbowFov = false,

    xray = false, fullBright = false, nightVision = false,
    noShadows = false, noBloom = false, noSunRays = false,
    rainbowLighting = false, noFog = false
}

local silentAim = {
    Enabled = false, MasterEnabled = false, Mode = "Hold",
    HoldKey = Enum.KeyCode.BackSlash, ListeningForBind = false,
    Prediction = 0.187, FOV = 500, TargetPart = "HumanoidRootPart",
    ShowFovCircle = true, MaxDistance = 0, PrioritizeClose = true, Mode360 = false,
    FovColor = Color3.fromRGB(100, 200, 255), CachedTarget = nil, CachedCFrame = nil,
    Logging = false
}

local markerClick = {
    Enabled = false, ModifierKey = Enum.KeyCode.Backquote,
    ListeningForBind = false, Debug = false, HeightOffset = 3
}

local ESP = {
    Enabled = false, Visible = false, Range = math.huge, UpdateRate = 1,
    Font = Enum.Font.GothamBlack, Size = 0.70, Width = 1.60, Height = 1.10,
    ShowName = true, ShowHPBar = true, ShowMeter = true, ShowMD = true,
    ShowHPText = true, ShowDodge = true, Whitelist = {},
}

local colors = { RainbowSkin = false, RainbowHair = false, SkinSpeed = 0.5, HairSpeed = 0.5, Invert = true }
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

local __serverHopBusy = false

local ALL_BODY_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot"
}

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

pcall(function()
    getgenv().Flumium_Drawing_Fov1 = fovCircle
    getgenv().Flumium_Drawing_Fov2 = fovCircle2
    getgenv().Flumium_Drawing_FovS = silentFovCircle
end)

-- ============================================================
-- PING / REGION via IP
-- ============================================================
local function getPlayerPing()
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    return ok and ping and math.floor(ping * 1000) or 0
end

local IP_SERVICES = {
    { url = "https://api4.my-ip.io/ip.json",     parser = function(data) return data.ip end,     raw = "ip" },
    { url = "https://api.ipify.org?format=json", parser = function(data) return data.ip end,     raw = "ip" },
    { url = "https://ipinfo.io/json",            parser = function(data) return data.ip end,     raw = "ip" },
    { url = "https://api.ip.sb/jsonip",          parser = function(data) return data.ip end,     raw = "ip" },
}

local function fetchServerIP()
    for i, svc in ipairs(IP_SERVICES) do
        local ok, resp = pcall(function()
            return game:HttpGet(svc.url, true)
        end)
        if ok and type(resp) == "string" and #resp > 0 then
            local ok2, data = pcall(function() return HttpService:JSONDecode(resp) end)
            if ok2 and type(data) == "table" and data[svc.raw] then
                local ip = tostring(data[svc.raw])
                if ip:match("^%d+%.%d+%.%d+%.%d+$") then
                    __dbg("server IP via " .. svc.url .. " → " .. ip)
                    return ip
                end
            end
            local ip = resp:match("(%d+%.%d+%.%d+%.%d+)")
            if ip then
                __dbg("server IP via " .. svc.url .. " (raw) → " .. ip)
                return ip
            end
        end
    end
    __dbg("server IP: все сервисы упали")
    return nil
end

local function geolocateIP(ip)
    if not ip or ip == "" then return nil end
    local url = "http://ip-api.com/json/" .. ip
             .. "?fields=status,country,countryCode,region,regionName,city,isp,org,as,lat,lon,timezone,query"
    local ok, resp = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok or type(resp) ~= "string" or resp == "" then
        return { status = "fail", err = "geolocation http failed", query = ip }
    end
    local ok2, data = pcall(function() return HttpService:JSONDecode(resp) end)
    if not ok2 or type(data) ~= "table" then
        return { status = "fail", err = "geolocation parse failed", query = ip }
    end
    if data.status ~= "success" then
        return { status = "fail", err = tostring(data.message or "ip-api returned fail"), query = ip }
    end
    return data
end

local __serverLocCache = nil
local function getServerLocation(force)
    if __serverLocCache and not force then return __serverLocCache end

    local ip = fetchServerIP()
    if not ip then
        local result = { status = "fail", err = "no server IP" }
        __serverLocCache = result
        return result
    end

    local data = geolocateIP(ip)
    if not data then
        local result = { status = "fail", err = "geolocation returned nil", query = ip }
        __serverLocCache = result
        return result
    end

    __serverLocCache = data
    return data
end

local function getClientCountry()
    local ok, code = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer)
    end)
    if ok and code and code ~= "" then return tostring(code) end
    return "??"
end

local function haversine(lat1, lon1, lat2, lon2)
    local R = 6371
    local dLat = math.rad(lat2 - lat1)
    local dLon = math.rad(lon2 - lon1)
    local a = math.sin(dLat/2)^2 + math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) * math.sin(dLon/2)^2
    return math.floor(R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a)))
end

local COUNTRY_COORDS = {
    US = {38, -97}, CA = {60, -95}, MX = {23, -102},
    GB = {54, -2}, DE = {51, 10}, FR = {46, 2}, NL = {52, 5},
    PL = {52, 20}, ES = {40, -4}, IT = {42, 12}, SE = {60, 15},
    NO = {62, 10}, FI = {64, 26}, RU = {60, 100}, UA = {49, 32},
    TR = {39, 35}, JP = {36, 138}, KR = {36, 128}, CN = {35, 105},
    SG = {1, 103}, IN = {20, 77}, AU = {-25, 134}, BR = {-10, -55},
    AR = {-34, -64}, ZA = {-29, 24}, AE = {24, 54}, SA = {24, 45},
    ID = {-5, 120}, TH = {15, 100}, VN = {14, 108}, PH = {13, 122},
    MY = {4, 102}, HK = {22, 114}, TW = {24, 121}, NZ = {-41, 174},
}

local function getClientCoords()
    local cc = getClientCountry()
    if cc and COUNTRY_COORDS[cc] then
        return COUNTRY_COORDS[cc][1], COUNTRY_COORDS[cc][2], cc
    end
    return nil, nil, cc
end

-- ============================================================
-- VISUAL FUNCTIONS
-- ============================================================
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

local function setNightVision(v)
    settings.nightVision = v
    pcall(function()
        local nv = Lighting:FindFirstChild("NVEffect")
        if v then
            if not nv then
                nv = Instance.new("ColorCorrectionEffect")
                nv.Name = "NVEffect"; nv.Brightness = 0.3; nv.Contrast = 0.5
                nv.Saturation = -0.5; nv.TintColor = Color3.fromRGB(0,255,0)
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
        Lighting.FogEnd = 100000; Lighting.FogStart = 100000
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
    end
end

-- ============================================================
-- LOW DETAIL MODE + FPS UNLOCKER
-- ============================================================
local lowDetailState = {
    Enabled = false,
    RemoveTextures = true, RemoveDecals = true, RemoveParticles = true,
    RemoveShadows = true, PlasticMaterial = true,
    DisablePostFX = true, FogDistance = true, WaterOptimize = true,
    FpsUnlocked = false, FpsCap = 240,
    ModifiedParts = {}, ModifiedDecals = {}, ModifiedTextures = {}, ModifiedParticles = {},
    DescConn = nil,
}

local function applyLowDetailToObject(obj)
    if not lowDetailState.Enabled then return end
    pcall(function()
        if obj:IsA("BasePart") then
            if lowDetailState.PlasticMaterial and obj.Material ~= Enum.Material.Plastic then
                table.insert(lowDetailState.ModifiedParts, {obj = obj, prop = "Material", value = obj.Material})
                obj.Material = Enum.Material.Plastic
            end
            if lowDetailState.RemoveShadows and obj.CastShadow then
                table.insert(lowDetailState.ModifiedParts, {obj = obj, prop = "CastShadow", value = true})
                obj.CastShadow = false
            end
        elseif obj:IsA("Decal") and lowDetailState.RemoveDecals then
            table.insert(lowDetailState.ModifiedDecals, {obj = obj, value = obj.Transparency})
            obj.Transparency = 1
        elseif obj:IsA("Texture") and lowDetailState.RemoveTextures then
            table.insert(lowDetailState.ModifiedTextures, {obj = obj, value = obj.Transparency})
            obj.Transparency = 1
        elseif (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Beam")) and lowDetailState.RemoveParticles then
            table.insert(lowDetailState.ModifiedParticles, {obj = obj, value = obj.Enabled})
            obj.Enabled = false
        end
    end)
end

local function applyLowDetailAll()
    if not lowDetailState.Enabled then return end
    task.spawn(function()
        local count = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            applyLowDetailToObject(obj)
            count += 1
            if count % 500 == 0 then task.wait() end
        end
    end)
    pcall(function()
        if lowDetailState.DisablePostFX then
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = false end
            end
        end
        if lowDetailState.FogDistance then
            Lighting.FogEnd = 1e9; Lighting.FogStart = 0
        end
        Lighting.GlobalShadows = false
    end)
    pcall(function()
        if lowDetailState.WaterOptimize then
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 1
            end
        end
    end)
end

local function restoreLowDetail()
    for _, entry in ipairs(lowDetailState.ModifiedParts) do
        pcall(function() if entry.obj and entry.obj.Parent then entry.obj[entry.prop] = entry.value end end)
    end
    for _, entry in ipairs(lowDetailState.ModifiedDecals) do
        pcall(function() if entry.obj and entry.obj.Parent then entry.obj.Transparency = entry.value end end)
    end
    for _, entry in ipairs(lowDetailState.ModifiedTextures) do
        pcall(function() if entry.obj and entry.obj.Parent then entry.obj.Transparency = entry.value end end)
    end
    for _, entry in ipairs(lowDetailState.ModifiedParticles) do
        pcall(function() if entry.obj and entry.obj.Parent then entry.obj.Enabled = entry.value end end)
    end
    lowDetailState.ModifiedParts = {}
    lowDetailState.ModifiedDecals = {}
    lowDetailState.ModifiedTextures = {}
    lowDetailState.ModifiedParticles = {}
    pcall(function()
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then e.Enabled = true end
        end
    end)
    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0.15
            terrain.WaterWaveSpeed = 10
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0.2
        end
    end)
end

local function fastDeactivateLowDetail()
    if lowDetailState.Enabled then
        lowDetailState.Enabled = false
        if lowDetailState.DescConn then
            pcall(function() lowDetailState.DescConn:Disconnect() end)
            lowDetailState.DescConn = nil
        end
        pcall(function()
            Lighting.FogEnd = originalLighting.FogEnd
            Lighting.FogStart = originalLighting.FogStart
            Lighting.GlobalShadows = originalLighting.GlobalShadows
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") then e.Enabled = true end
            end
        end)
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0.15
                terrain.WaterWaveSpeed = 10
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0.2
            end
        end)
        lowDetailState.ModifiedParts = {}
        lowDetailState.ModifiedDecals = {}
        lowDetailState.ModifiedTextures = {}
        lowDetailState.ModifiedParticles = {}
    end
    if lowDetailState.FpsUnlocked then
        lowDetailState.FpsUnlocked = false
        if type(setfpscap) == "function" then pcall(function() setfpscap(60) end) end
    end
end

local function startLowDetailWatcher()
    if lowDetailState.DescConn then return end
    lowDetailState.DescConn = __regConn(Workspace.DescendantAdded:Connect(function(obj)
        if lowDetailState.Enabled then
            task.defer(function() applyLowDetailToObject(obj) end)
        end
    end))
end

local function stopLowDetailWatcher()
    if lowDetailState.DescConn then
        pcall(function() lowDetailState.DescConn:Disconnect() end)
        lowDetailState.DescConn = nil
    end
end

local function setLowDetail(enabled)
    lowDetailState.Enabled = enabled
    if enabled then
        applyLowDetailAll()
        startLowDetailWatcher()
    else
        stopLowDetailWatcher()
        restoreLowDetail()
    end
end

local function setFpsCap(cap)
    if type(setfpscap) == "function" then
        pcall(function() setfpscap(cap) end)
        return true
    end
    local ok = pcall(function() settings().Rendering.FramerateCap = cap end)
    return ok
end

local function unlockFps(cap)
    if lowDetailState.FpsUnlocked then return end
    lowDetailState.FpsUnlocked = true
    lowDetailState.FpsCap = cap
    setFpsCap(cap)
end

local function relockFps()
    if not lowDetailState.FpsUnlocked then return end
    lowDetailState.FpsUnlocked = false
    setFpsCap(60)
end

-- ============================================================
-- ESP (Universal Shindo version, keybind removed)
-- ============================================================
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
    table.insert(espConns[p], __regConn(p.CharacterAdded:Connect(function(char)
        if ESP.Enabled and ESP.Visible and isWhitelisted(p) then
            task.defer(function() createPlayerESP(p, char) end)
        end
    end)))
    table.insert(espConns[p], __regConn(p.CharacterRemoving:Connect(function() clearPlayer(p) end)))
    if p.Character and ESP.Enabled and ESP.Visible and isWhitelisted(p) then
        task.defer(function() createPlayerESP(p, p.Character) end)
    end
end

for _,p in ipairs(Players:GetPlayers()) do espWatch(p) end
__regConn(Players.PlayerAdded:Connect(espWatch))
__regConn(Players.PlayerRemoving:Connect(function(p) clearPlayer(p) end))
__regConn(RunService.Heartbeat:Connect(function(dt)
    if not ESP.Enabled or not ESP.Visible then return end
    espAcc += dt
    if espAcc >= ESP.UpdateRate then espAcc = 0; updateESP() end
end))

-- ============================================================
-- KUNAI MARKER HACK
-- ============================================================
local savedEnemyPos = nil

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

-- ============================================================
-- SILENT AIM
-- ============================================================
local silentHook = false
local oldNamecall = nil
local metaT = nil

__regConn(RunService.Heartbeat:Connect(function()
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
end))

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

-- ============================================================
-- COLOR CHANGER
-- ============================================================
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

-- ============================================================
-- AIMBOTS
-- ============================================================
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
    local aimPos = head.Position + Vector3.new(0, settings.aim2HeightOffset, 0)
    local pos = aimPos + (rp and rp.Velocity * settings.aim2Prediction or Vector3.new())
    local cur = Camera.CFrame
    local tgt = CFrame.new(cur.Position, pos)
    Camera.CFrame = cur:Lerp(tgt, math.clamp(1 - settings.aim2Smoothing, 0.05, 1))
end

-- ============================================================
-- SERVER FUNCTIONS
-- ============================================================
local function serverHop()
    if __serverHopBusy then
        Fluent:Notify({Title = "⏳", Content = "Уже ищу сервер...", Duration = 2})
        return
    end
    __serverHopBusy = true

    Fluent:Notify({Title = "🔄 Server Hop", Content = "Поиск сервера...", Duration = 2})
    task.spawn(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, response = pcall(function() return game:HttpGet(url, true) end)
        if not ok or type(response) ~= "string" then
            Fluent:Notify({Title = "❌", Content = "Не удалось получить список серверов", Duration = 4})
            __serverHopBusy = false
            return
        end
        local ok2, data = pcall(function() return HttpService:JSONDecode(response) end)
        if not ok2 or type(data) ~= "table" or type(data.data) ~= "table" then
            Fluent:Notify({Title = "❌", Content = "Ошибка парсинга", Duration = 4})
            __serverHopBusy = false
            return
        end

        local avail = {}
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(avail, s.id)
            end
        end

        if #avail == 0 then
            Fluent:Notify({Title = "❌", Content = "Нет доступных серверов", Duration = 4})
            __serverHopBusy = false
            return
        end

        local targetId = avail[math.random(1, #avail)]
        teleportToJob(targetId, "Server Hop")
        task.wait(3)
        __serverHopBusy = false
    end)
end

local function rejoinServer()
    Fluent:Notify({Title = "🔁 Rejoin", Content = "Переподключение...", Duration = 2})
    pushHistory(game.JobId)
    task.spawn(function()
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
        if not ok then
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
    end)
end

local function forceReconnect()
    Fluent:Notify({Title = "⚡ Force Reconnect", Content = "Принудительное...", Duration = 2})
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

-- ============================================================
-- GUI
-- ============================================================
local Window = Fluent:CreateWindow({
    Title = "Flumium Client v1.4 2 Aimbots • ESP • Server Tools • Performance",
    SubTitle = "2 Aimbots • ESP • Server Tools • Performance",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

pcall(function()
    Window:ModifyTheme({
        {"Window", "Background",        Color3.fromRGB(38, 23, 43)},
        {"Window", "Outline",           Color3.fromRGB(74, 47, 80)},
        {"Window", "Title",             Color3.fromRGB(252, 232, 245)},
        {"Window", "SubTitle",          Color3.fromRGB(200, 165, 215)},
        {"Element", "Background",       Color3.fromRGB(48, 30, 53)},
        {"Element", "Background Secondary", Color3.fromRGB(58, 38, 68)},
        {"Element", "Text",             Color3.fromRGB(252, 240, 255)},
        {"Element", "SubText",          Color3.fromRGB(200, 165, 215)},
        {"Element", "Placeholder",      Color3.fromRGB(150, 120, 170)},
        {"Element", "Border",           Color3.fromRGB(74, 47, 80)},
        {"Outline", "Color",            Color3.fromRGB(74, 47, 80)},
        {"Accent", "Background",        Color3.fromRGB(236, 116, 178)},
        {"Accent", "Text",              Color3.fromRGB(255, 255, 255)},
        {"Accent", "Border",            Color3.fromRGB(236, 116, 178)},
        {"Tabs", "Tab",                 Color3.fromRGB(48, 30, 53)},
        {"Tabs", "Tab Text",            Color3.fromRGB(200, 165, 215)},
        {"Tabs", "Tab Selected",        Color3.fromRGB(236, 116, 178)},
        {"Tabs", "Tab Selected Text",   Color3.fromRGB(255, 255, 255)},
    })
end)

local Tabs = {
    Aimbot      = Window:AddTab({ Title = "Aimbot 🎯",      Icon = "crosshair" }),
    Aimbot2     = Window:AddTab({ Title = "Aimbot 2 🎯",    Icon = "target" }),
    Silent      = Window:AddTab({ Title = "Silent Aim 🎭",  Icon = "eye-off" }),
    ESP         = Window:AddTab({ Title = "ESP 👁️",         Icon = "eye" }),
    Performance = Window:AddTab({ Title = "Performance ⚡",  Icon = "zap" }),
    Colors      = Window:AddTab({ Title = "Colors 🎨",      Icon = "palette" }),
    Visual      = Window:AddTab({ Title = "Visual ✨",      Icon = "sun" }),
    Server      = Window:AddTab({ Title = "Server 🌐",      Icon = "globe" }),
    UI          = Window:AddTab({ Title = "UI Settings",    Icon = "settings" })
}
local Options = Fluent.Options

-- ============================================================
-- AIMBOT 1 TAB
-- ============================================================
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
    Values = {"Auto", "Head", "HumanoidRootPart", "UpperTorso", "Torso"}, Default = 1
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
Tabs.Aimbot:AddSlider("MaxDist", {Title = "Max Distance", Description = "0 = без ограничений", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v) settings.maxDistance = v end)
Tabs.Aimbot:AddToggle("PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) settings.prioritizeClose = v end)
Tabs.Aimbot:AddToggle("Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
    settings.mode360 = v
    if v and fovCircle then fovCircle.Visible = false end
end)
Tabs.Aimbot:AddSlider("Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) settings.smoothing = v / 100 end)
Tabs.Aimbot:AddSlider("Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v) settings.prediction = v / 100 end)
Tabs.Aimbot:AddToggle("WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.wallCheck = v end)
Tabs.Aimbot:AddToggle("TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.teamCheck = v end)

-- ============================================================
-- AIMBOT 2 TAB
-- ============================================================
Tabs.Aimbot2:AddParagraph({ Title = "🎯 Aimbot 2 — Headshot", Content = "Целится ВЫШЕ головы. По умолчанию на клавише [1]" })
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
Tabs.Aimbot2:AddToggle("Aim2RainbowFov", {Title = "Rainbow FOV", Default = false}):OnChanged(function(v) settings.aim2RainbowFov = v end)
Tabs.Aimbot2:AddDropdown("Aim2Mode", {Title = "Aim Mode",
    Values = {"Hold (зажать)", "Toggle (переключить)"}, Default = 1
}):OnChanged(function(v) settings.aim2Mode = (v == "Hold (зажать)") and "Hold" or "Toggle" end)
local aim2BindButton
aim2BindButton = Tabs.Aimbot2:AddButton({
    Title = "🎹 BIND: " .. settings.aim2Key.Name,
    Description = "Нажмите для смены клавиши (по умолчанию 1)",
    Callback = function()
        settings.aim2ListeningForBind = true
        pcall(function() aim2BindButton:SetTitle("🎹 Нажмите клавишу...") end)
    end
})
Tabs.Aimbot2:AddSlider("Aim2Height", {
    Title = "📏 Height Above Head (studs)",
    Description = "На сколько studs выше головы целиться",
    Default = 3, Min = 0, Max = 20, Rounding = 0
}):OnChanged(function(v) settings.aim2HeightOffset = v end)
Tabs.Aimbot2:AddSlider("Aim2FOV", {Title = "FOV Size", Default = 300, Min = 0, Max = 800, Rounding = 0}):OnChanged(function(v)
    settings.aim2Fov = v; if fovCircle2 then fovCircle2.Radius = v end
end)
Tabs.Aimbot2:AddSlider("Aim2MaxDist", {Title = "Max Distance", Description = "0 = без ограничений", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v) settings.aim2MaxDistance = v end)
Tabs.Aimbot2:AddToggle("Aim2PriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) settings.aim2PrioritizeClose = v end)
Tabs.Aimbot2:AddToggle("Aim2Mode360", {Title = "360° Mode", Default = false}):OnChanged(function(v)
    settings.aim2Mode360 = v
    if v and fovCircle2 then fovCircle2.Visible = false end
end)
Tabs.Aimbot2:AddSlider("Aim2Smooth", {Title = "Smoothing", Default = 15, Min = 0, Max = 100, Rounding = 0}):OnChanged(function(v) settings.aim2Smoothing = v / 100 end)
Tabs.Aimbot2:AddSlider("Aim2Pred", {Title = "Prediction", Default = 6, Min = 0, Max = 30, Rounding = 0}):OnChanged(function(v) settings.aim2Prediction = v / 100 end)
Tabs.Aimbot2:AddToggle("Aim2WallCheck", {Title = "Wall Check", Default = false}):OnChanged(function(v) settings.aim2WallCheck = v end)
Tabs.Aimbot2:AddToggle("Aim2TeamCheck", {Title = "Team Check", Default = false}):OnChanged(function(v) settings.aim2TeamCheck = v end)

local markerSection = Tabs.Aimbot2:AddSection("Kunai Marker")
markerSection:AddToggle("MarkerClick", { Title = "🌀 Enable Marker Hack", Default = false }):OnChanged(function(v)
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
markerSection:AddSlider("MarkerH", { Title = "📏 Marker Height", Default = 3, Min = 0, Max = 20, Rounding = 0 }):OnChanged(function(v) markerClick.HeightOffset = v end)
markerSection:AddToggle("MarkerDebug", {Title = "🔍 Debug", Default = false}):OnChanged(function(v) markerClick.Debug = v end)

-- ============================================================
-- SILENT AIM TAB
-- ============================================================
Tabs.Silent:AddToggle("SilentMaster", {Title = "Enable Silent Aim", Default = false}):OnChanged(function(v)
    silentAim.MasterEnabled = v
    if v then enableSilentHook() else disableSilentHook() end
end)
Tabs.Silent:AddDropdown("SilentMode", { Title = "Режим", Values = {"Hold", "Toggle"}, Default = 1 }):OnChanged(function(v) silentAim.Mode = v end)
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
Tabs.Silent:AddSlider("SilentMaxDist", {Title = "Max Distance", Default = 0, Min = 0, Max = 5000, Rounding = 50}):OnChanged(function(v) silentAim.MaxDistance = v end)
Tabs.Silent:AddToggle("SilentPriorClose", {Title = "Prioritize Close", Default = true}):OnChanged(function(v) silentAim.PrioritizeClose = v end)
Tabs.Silent:AddToggle("SilentMode360", {Title = "360° Mode", Default = false}):OnChanged(function(v) silentAim.Mode360 = v end)
Tabs.Silent:AddButton({
    Title = "🔄 Переустановить хук",
    Callback = function() disableSilentHook(); task.wait(0.3); if silentAim.MasterEnabled then enableSilentHook() end end
})

-- ============================================================
-- ESP TAB (KEYBIND REMOVED)
-- ============================================================
Tabs.ESP:AddToggle("ESPOn", {
    Title = "Enable ESP",
    Description = "Показывает HP, MD, Dodge иконки",
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
            if p ~= LocalPlayer then table.insert(playerList, p) end
        end
        if #playerList == 0 then Fluent:Notify({Title = "ℹ️", Content = "Нет игроков", Duration = 3}); return end
        for _, p in ipairs(playerList) do
            local isWL = ESP.Whitelist[p.Name] == true
            espWhitelistSection:AddButton({
                Title = (isWL and "✓ " or "  ") .. p.Name,
                Callback = function()
                    if ESP.Whitelist[p.Name] then ESP.Whitelist[p.Name] = nil
                    else ESP.Whitelist[p.Name] = true end
                    rebuildESP()
                end
            })
        end
    end
})

-- ============================================================
-- PERFORMANCE TAB
-- ============================================================
Tabs.Performance:AddParagraph({
    Title = "⚡ Performance Tools",
    Content = "Low Detail Mode убирает текстуры, тени и частицы. FPS Unlocker снимает лимит кадров."
})

local lowDetailSection = Tabs.Performance:AddSection("Low Detail Mode")
lowDetailSection:AddToggle("LowDetailOn", {
    Title = "🔻 Low Detail Mode",
    Description = "Отключает текстуры, decals, частицы, тени, воду, post-processing",
    Default = false
}):OnChanged(function(v)
    setLowDetail(v)
    if v then Fluent:Notify({Title = "🔻 Low Detail", Content = "Активирован", Duration = 2})
    else Fluent:Notify({Title = "🔺 Low Detail", Content = "Отключён", Duration = 2}) end
end)
lowDetailSection:AddToggle("LDRemoveTextures", { Title = "Remove Textures", Default = true }):OnChanged(function(v)
    lowDetailState.RemoveTextures = v
    if lowDetailState.Enabled then setLowDetail(false); task.wait(0.1); setLowDetail(true) end
end)
lowDetailSection:AddToggle("LDRemoveDecals", { Title = "Remove Decals", Default = true }):OnChanged(function(v)
    lowDetailState.RemoveDecals = v
    if lowDetailState.Enabled then setLowDetail(false); task.wait(0.1); setLowDetail(true) end
end)
lowDetailSection:AddToggle("LDRemoveParticles", { Title = "Remove Particles", Default = true }):OnChanged(function(v)
    lowDetailState.RemoveParticles = v
    if lowDetailState.Enabled then setLowDetail(false); task.wait(0.1); setLowDetail(true) end
end)
lowDetailSection:AddToggle("LDRemoveShadows", { Title = "Remove Shadows", Default = true }):OnChanged(function(v)
    lowDetailState.RemoveShadows = v
    if lowDetailState.Enabled then setLowDetail(false); task.wait(0.1); setLowDetail(true) end
end)
lowDetailSection:AddToggle("LDPlastic", { Title = "Force Plastic Material", Default = true }):OnChanged(function(v)
    lowDetailState.PlasticMaterial = v
    if lowDetailState.Enabled then setLowDetail(false); task.wait(0.1); setLowDetail(true) end
end)
lowDetailSection:AddToggle("LDPostFX", { Title = "Disable Post-Processing", Default = true }):OnChanged(function(v) lowDetailState.DisablePostFX = v end)
lowDetailSection:AddToggle("LDFog", { Title = "Extend Fog Distance", Default = true }):OnChanged(function(v) lowDetailState.FogDistance = v end)
lowDetailSection:AddToggle("LDWater", { Title = "Optimize Water", Default = true }):OnChanged(function(v) lowDetailState.WaterOptimize = v end)

local fpsSection = Tabs.Performance:AddSection("FPS Unlocker")
fpsSection:AddToggle("FPSUnlock", {
    Title = "🚀 Unlock FPS Cap",
    Description = "Снимает стандартный лимит 60 FPS через setfpscap()",
    Default = false
}):OnChanged(function(v)
    if v then
        unlockFps(lowDetailState.FpsCap)
        Fluent:Notify({Title = "🚀 FPS Unlocked", Content = "Cap: " .. lowDetailState.FpsCap, Duration = 3})
    else
        relockFps()
        Fluent:Notify({Title = "🔒 FPS Locked", Content = "Cap: 60", Duration = 2})
    end
end)
fpsSection:AddSlider("FpsCapSlider", {
    Title = "FPS Cap (if unlocked)", Description = "0 = без лимита",
    Default = 240, Min = 0, Max = 999, Rounding = 0
}):OnChanged(function(v)
    lowDetailState.FpsCap = v
    if lowDetailState.FpsUnlocked then setFpsCap(v == 0 and 9999 or v) end
end)
fpsSection:AddButton({
    Title = "🔄 Применить FPS Cap",
    Callback = function()
        local cap = lowDetailState.FpsCap == 0 and 9999 or lowDetailState.FpsCap
        setFpsCap(cap)
        Fluent:Notify({Title = "✅", Content = "FPS Cap = " .. lowDetailState.FpsCap, Duration = 2})
    end
})
local perfStatusPara = Tabs.Performance:AddParagraph({
    Title = "📊 Status", Content = "Low Detail: OFF | FPS: 60 (locked)"
})
__regConn(RunService.Heartbeat:Connect(function()
    local ld = lowDetailState.Enabled and "ON" or "OFF"
    local fps = lowDetailState.FpsUnlocked and tostring(lowDetailState.FpsCap) or "60 (locked)"
    pcall(function() perfStatusPara:SetDesc("Low Detail: " .. ld .. " | FPS: " .. fps) end)
end))

-- ============================================================
-- COLORS TAB
-- ============================================================
Tabs.Colors:AddToggle("InvertColors", {Title = "Инвертировать цвет", Default = true}):OnChanged(function(v) colors.Invert = v end)
Tabs.Colors:AddToggle("RainbowSkin",  {Title = "Rainbow Skin", Default = false}):OnChanged(function(v) colors.RainbowSkin = v end)
Tabs.Colors:AddToggle("RainbowHair",  {Title = "Rainbow Hair", Default = false}):OnChanged(function(v) colors.RainbowHair = v end)
Tabs.Colors:AddSlider("SkinSpd", {Title = "Skin Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v) colors.SkinSpeed = v / 10 end)
Tabs.Colors:AddSlider("HairSpd", {Title = "Hair Speed", Default = 5, Min = 1, Max = 30, Rounding = 0}):OnChanged(function(v) colors.HairSpeed = v / 10 end)

local colorPresets = {
    {name = "🔴 Красный", r = 255, g = 0, b = 0},
    {name = "🟢 Зелёный", r = 0, g = 255, b = 0},
    {name = "🔵 Синий",   r = 0, g = 0, b = 255},
    {name = "🟣 Фиолетовый", r = 128, g = 0, b = 255},
    {name = "🟡 Жёлтый",  r = 255, g = 255, b = 0},
    {name = "⚫ Чёрный",  r = 1, g = 1, b = 1},
    {name = "⚪ Белый",   r = 254, g = 254, b = 254},
    {name = "🟠 Оранжевый", r = 255, g = 128, b = 0},
    {name = "💗 Розовый", r = 255, g = 105, b = 180},
    {name = "🩵 Cyan",    r = 0, g = 255, b = 255}
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

-- ============================================================
-- VISUAL TAB
-- ============================================================
Tabs.Visual:AddToggle("XRay", {Title = "X-Ray", Default = false}):OnChanged(function(v) setXRay(v) end)
Tabs.Visual:AddToggle("FB",   {Title = "Full Bright", Default = false}):OnChanged(function(v) setFullBright(v) end)
Tabs.Visual:AddToggle("NV",   {Title = "Night Vision", Default = false}):OnChanged(function(v) setNightVision(v) end)
Tabs.Visual:AddToggle("NoSh", {Title = "No Shadows", Default = false}):OnChanged(function(v) setNoShadows(v) end)
Tabs.Visual:AddToggle("NoBl", {Title = "No Bloom", Default = false}):OnChanged(function(v) setNoBloom(v) end)
Tabs.Visual:AddToggle("NoSR", {Title = "No Sun Rays", Default = false}):OnChanged(function(v) setNoSunRays(v) end)
Tabs.Visual:AddToggle("RainL",{Title = "Rainbow Lighting", Default = false}):OnChanged(function(v) setRainbowLighting(v) end)
Tabs.Visual:AddToggle("NoFog",{Title = "No Fog", Default = false}):OnChanged(function(v) setNoFog(v) end)

-- ============================================================
-- SERVER TAB
-- ============================================================
local topPingPara = Tabs.Server:AddParagraph({ Title = "📶 Ping / 🌍 Server Region", Content = "Загрузка..." })
local topIpPara = Tabs.Server:AddParagraph({ Title = "🖥️ Server IP / Location (via ip-api)", Content = "Загрузка..." })
local topRegionPara = Tabs.Server:AddParagraph({ Title = "📍 Server Region (detailed)", Content = "Загрузка..." })

task.spawn(function()
    task.wait(0.5)
    local info = getServerLocation()
    local clientCc = getClientCountry()
    local cLat, cLon, cCode = getClientCoords()

    local p = getPlayerPing()
    local dot = p < 100 and "🟢" or (p < 200 and "🟡" or "🔴")
    pcall(function()
        topPingPara:SetDesc(string.format("%s %d ms  |  You: %s", dot, p, clientCc))
    end)

    if info and info.status == "success" then
        local distText = "?"
        if cLat and cLon and info.lat and info.lon then
            distText = haversine(cLat, cLon, info.lat, info.lon) .. " km"
        end
        pcall(function()
            topIpPara:SetDesc(string.format(
                "%s, %s (%s)  |  IP: %s  |  ISP: %s  |  ~%s от тебя",
                info.city or "?", info.country or "?", info.countryCode or "?",
                info.query or "?", info.isp or info.org or "?", distText
            ))
        end)
        pcall(function()
            topRegionPara:SetDesc(string.format(
                "Region: %s | Timezone: %s | Coords: %s, %s | AS: %s",
                info.regionName or info.region or "?",
                info.timezone or "?",
                tostring(info.lat or "?"), tostring(info.lon or "?"),
                tostring(info.as or "?")
            ))
        end)
    else
        pcall(function()
            topIpPara:SetDesc("Не удалось получить IP сервера: " .. tostring(info and info.err or "unknown"))
        end)
        pcall(function()
            topRegionPara:SetDesc("Region: неизвестен")
        end)
    end
end)

Tabs.Server:AddButton({ Title = "🔄 Server Hop", Callback = function() serverHop() end })
Tabs.Server:AddButton({ Title = "🔁 Rejoin Server", Callback = function() rejoinServer() end })
Tabs.Server:AddButton({ Title = "⚡ Force Reconnect", Callback = function() forceReconnect() end })
Tabs.Server:AddButton({
    Title = "📡 Обновить данные о сервере",
    Description = "Перезапрашивает IP и геолокацию сервера",
    Callback = function()
        Fluent:Notify({Title = "📡", Content = "Обновляю...", Duration = 2})
        task.spawn(function()
            local info = getServerLocation(true)
            if info and info.status == "success" then
                local cLat, cLon = getClientCoords()
                local distText = "?"
                if cLat and cLon and info.lat and info.lon then
                    distText = haversine(cLat, cLon, info.lat, info.lon) .. " km"
                end
                pcall(function()
                    topIpPara:SetDesc(string.format(
                        "%s, %s (%s)  |  IP: %s  |  ISP: %s  |  ~%s от тебя",
                        info.city or "?", info.country or "?", info.countryCode or "?",
                        info.query or "?", info.isp or info.org or "?", distText
                    ))
                end)
                pcall(function()
                    topRegionPara:SetDesc(string.format(
                        "Region: %s | Timezone: %s | Coords: %s, %s | AS: %s",
                        info.regionName or info.region or "?",
                        info.timezone or "?",
                        tostring(info.lat or "?"), tostring(info.lon or "?"),
                        tostring(info.as or "?")
                    ))
                end)
                Fluent:Notify({Title = "✅", Content = "Данные обновлены", Duration = 2})
            else
                Fluent:Notify({Title = "❌", Content = "Не удалось: " .. tostring(info and info.err or "?"), Duration = 3})
            end
        end)
    end
})

local jobSection = Tabs.Server:AddSection("Job ID")
local jobPara = jobSection:AddParagraph({
    Title = "📋 Current Job ID",
    Content = game.JobId ~= "" and game.JobId or "(нет — приватный / offline)"
})
jobSection:AddButton({
    Title = "📋 Скопировать текущий Job ID",
    Description = "Кладёт в буфер ID этого сервера (только публичные)",
    Callback = function()
        if game.JobId == "" then Fluent:Notify({Title = "❌", Content = "Job ID недоступен", Duration = 3}); return end
        local ok = pcall(function()
            if type(setclipboard) == "function" then setclipboard(game.JobId)
            elseif type(toclipboard) == "function" then toclipboard(game.JobId)
            else error("no clipboard") end
        end)
        if ok then Fluent:Notify({Title = "📋 Скопировано", Content = game.JobId, Duration = 3})
        else Fluent:Notify({Title = "❌", Content = "Буфер недоступен", Duration = 3}) end
    end
})
jobSection:AddButton({
    Title = "🔄 Обновить Job ID",
    Callback = function()
        pcall(function() jobPara:SetDesc(game.JobId ~= "" and game.JobId or "(нет — приватный / offline)") end)
        Fluent:Notify({Title = "🔄", Content = "Job ID обновлён", Duration = 2})
    end
})
local jobInputBox = jobSection:AddInput("JobIDInput", {
    Title = "🔌 Join by Job ID",
    Description = "Вставь Job ID публичного сервера (сервер должен быть жив)",
    Placeholder = "e.g. a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6",
    Default = ""
})
jobSection:AddButton({
    Title = "➡️ JOIN по Job ID",
    Callback = function()
        local raw = nil
        pcall(function() raw = jobInputBox.Value end)
        raw = tostring(raw or ""):gsub("%s", "")
        if raw == "" then Fluent:Notify({Title = "❌", Content = "Введи Job ID", Duration = 3}); return end
        if not raw:match("^%x+$") or #raw < 8 then
            Fluent:Notify({Title = "❌", Content = "Некорректный Job ID", Duration = 3}); return
        end
        teleportToJob(raw, "JOIN")
    end
})
jobSection:AddButton({
    Title = "📥 Вставить из буфера",
    Callback = function()
        local clip = nil
        pcall(function() if type(getclipboard) == "function" then clip = getclipboard() end end)
        clip = tostring(clip or ""):gsub("%s", "")
        if clip == "" then Fluent:Notify({Title = "❌", Content = "Буфер пуст", Duration = 3}); return end
        pcall(function() jobInputBox:SetValue(clip) end)
        Fluent:Notify({Title = "📥", Content = "Вставлено: " .. clip:sub(1, 12) .. "...", Duration = 2})
    end
})
jobSection:AddButton({
    Title = "⏪ Join Last Server",
    Description = "Вернуться на предыдущий сервер одним кликом",
    Callback = function()
        local list = loadHistory()
        if #list == 0 then Fluent:Notify({Title = "❌", Content = "История пуста", Duration = 3}); return end
        local target = nil
        for _, entry in ipairs(list) do
            if entry.id and entry.id ~= game.JobId then target = entry; break end
        end
        if not target then Fluent:Notify({Title = "ℹ️", Content = "Нет других серверов в истории", Duration = 3}); return end
        teleportToJob(target.id, "LAST SERVER")
    end
})

local historyDisplayMap = {}
local historyDropdown
local function buildHistoryValues()
    historyDisplayMap = {}
    local list = loadHistory()
    local values = {}
    if #list == 0 then values[#values + 1] = "(пусто)"; return values end
    for i, e in ipairs(list) do
        local id = e.id or "?"
        local disp = string.format("🕐 %s  |  %s", fmtTime(e.time), id:sub(1, 12))
        if historyDisplayMap[disp] then disp = disp .. " (" .. i .. ")" end
        values[#values + 1] = disp
        historyDisplayMap[disp] = id
    end
    return values
end
local initialValues = buildHistoryValues()
historyDropdown = jobSection:AddDropdown("JobHistory", {
    Title = "📚 Последние Job ID",
    Description = "Выбери запись — подключение произойдёт автоматически",
    Values = initialValues,
    Default = initialValues[1] or "(пусто)",
    Multi = false,
    Callback = function(selected)
        local id = historyDisplayMap[selected]
        if not id or id == "" then return end
        if id == game.JobId then Fluent:Notify({Title = "ℹ️", Content = "Это текущий сервер", Duration = 3}); return end
        teleportToJob(id, "HISTORY")
    end
})
jobSection:AddButton({
    Title = "♻️ Обновить список истории",
    Callback = function()
        pcall(function() historyDropdown:SetValues(buildHistoryValues()) end)
        Fluent:Notify({Title = "♻️", Content = "История обновлена", Duration = 2})
    end
})
jobSection:AddButton({
    Title = "🗑️ Очистить историю",
    Callback = function()
        if not hasFs() then Fluent:Notify({Title = "❌", Content = "Executor не поддерживает файлы", Duration = 3}); return end
        pcall(function() if isfile(HISTORY_FILE) then delfile(HISTORY_FILE) end end)
        pcall(function() historyDropdown:SetValues({"(пусто)"}) end)
        historyDisplayMap = {}
        Fluent:Notify({Title = "🗑️", Content = "История очищена", Duration = 2})
    end
})

-- ============================================================
-- BACKGROUND LOOPS
-- ============================================================
getgenv().Flumium_LoopsRunning = true

task.spawn(function()
    while getgenv().Flumium_LoopsRunning and __isCurrentSession() do
        task.wait(1.5)
        local p = getPlayerPing()
        local dot = p < 100 and "🟢" or (p < 200 and "🟡" or "🔴")
        local cc = getClientCountry()
        pcall(function() topPingPara:SetDesc(string.format("%s %d ms  |  You: %s", dot, p, cc)) end)
    end
end)

task.spawn(function()
    task.wait(2)
    while getgenv().Flumium_LoopsRunning and __isCurrentSession() do
        task.wait(60)
        __serverLocCache = nil
        local info = getServerLocation(true)
        if info and info.status == "success" then
            local cLat, cLon = getClientCoords()
            local distText = "?"
            if cLat and cLon and info.lat and info.lon then
                distText = haversine(cLat, cLon, info.lat, info.lon) .. " km"
            end
            pcall(function()
                topIpPara:SetDesc(string.format(
                    "%s, %s (%s)  |  IP: %s  |  ISP: %s  |  ~%s от тебя",
                    info.city or "?", info.country or "?", info.countryCode or "?",
                    info.query or "?", info.isp or info.org or "?", distText
                ))
            end)
            pcall(function()
                topRegionPara:SetDesc(string.format(
                    "Region: %s | Timezone: %s | Coords: %s, %s | AS: %s",
                    info.regionName or info.region or "?",
                    info.timezone or "?",
                    tostring(info.lat or "?"), tostring(info.lon or "?"),
                    tostring(info.as or "?")
                ))
            end)
        end
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
__regConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if markerClick.ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            markerClick.ModifierKey = input.KeyCode
            markerClick.ListeningForBind = false
            pcall(function() markerBindBtn:SetTitle("🎹 Modifier: " .. input.KeyCode.Name) end)
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
    if settings.aim2ListeningForBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            settings.aim2Key = input.KeyCode
            settings.aim2ListeningForBind = false
            pcall(function() aim2BindButton:SetTitle("🎹 BIND: " .. input.KeyCode.Name) end)
        end
        return
    end
    if silentAim.MasterEnabled and silentAim.Mode == "Toggle" then
        if input.KeyCode == silentAim.HoldKey then
            silentAim.Enabled = not silentAim.Enabled
        end
    end
    if aimbotEnabled and input.KeyCode == settings.aimKey then
        if settings.aimMode == "Hold" then aiming = true
        else aiming = not aiming; if not aiming then currentTarget = nil end end
    end
    if aim2Enabled and input.KeyCode == settings.aim2Key then
        if settings.aim2Mode == "Hold" then aim2ing = true
        else aim2ing = not aim2ing; if not aim2ing then aim2Target = nil end end
    end
end))

__regConn(UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if aimbotEnabled and settings.aimMode == "Hold" and input.KeyCode == settings.aimKey then
        aiming = false; currentTarget = nil
    end
    if aim2Enabled and settings.aim2Mode == "Hold" and input.KeyCode == settings.aim2Key then
        aim2ing = false; aim2Target = nil
    end
end))

__regConn(RunService.RenderStepped:Connect(function()
    if settings.rainbowLighting then
        lightingHue = (lightingHue + 0.005) % 1
        local c = Color3.fromHSV(lightingHue, 1, 1)
        Lighting.Ambient = c; Lighting.OutdoorAmbient = c
    end
    if aimbotEnabled and fovCircle and settings.showFovCircle and not settings.mode360 then
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        fovCircle.Visible = true
        if settings.rainbowFov then
            hue = (hue + rainbowSpeed) % 1
            fovCircle.Color = Color3.fromHSV(hue, 1, 1)
        elseif aiming and currentTarget then fovCircle.Color = settings.targetedColor
        else fovCircle.Color = settings.fovColor end
    elseif fovCircle then fovCircle.Visible = false end
    if aim2Enabled and fovCircle2 and settings.aim2ShowFovCircle and not settings.aim2Mode360 then
        fovCircle2.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        fovCircle2.Visible = true
        if settings.aim2RainbowFov then
            hue = (hue + rainbowSpeed) % 1
            fovCircle2.Color = Color3.fromHSV(hue, 1, 1)
        elseif aim2ing and aim2Target then fovCircle2.Color = settings.aim2TargetedColor
        else fovCircle2.Color = settings.aim2FovColor end
    elseif fovCircle2 then fovCircle2.Visible = false end
    if silentAim.MasterEnabled and silentFovCircle and silentAim.ShowFovCircle and not silentAim.Mode360 then
        silentFovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 50)
        silentFovCircle.Radius = silentAim.FOV
        silentFovCircle.Color = silentAim.FovColor
        silentFovCircle.Visible = silentAim.Enabled
    elseif silentFovCircle then silentFovCircle.Visible = false end
    if aiming then
        local t = tick()
        if t - lastTargetUpdate > 0.05 then lastTargetUpdate = t; currentTarget = getTarget() end
        if currentTarget then aimAtTarget(currentTarget) end
    else currentTarget = nil end
    if aim2ing then
        local t = tick()
        if t - lastTarget2Update > 0.05 then lastTarget2Update = t; aim2Target = getTarget2() end
        if aim2Target then aimAtTarget2(aim2Target) end
    else aim2Target = nil end
end))

__regConn(RunService.Heartbeat:Connect(function(dt)
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
end))

__regConn(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if ESP.Enabled then rebuildESP() end
    if lowDetailState.Enabled then
        task.wait(1)
        applyLowDetailAll()
    end
end))

-- ============================================================
-- UI SETTINGS
-- ============================================================
pcall(function()
    if SaveManager then
        SaveManager:SetLibrary(Fluent)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({
            "ServerHop", "RejoinServer", "ForceReconnect",
            "RefreshServerInfo",
            "JoinLastServer", "JobIDInput", "JobHistory",
            "CopyCurrentJobID", "RefreshJobID", "PasteFromClipboard",
            "RefreshHistoryList", "ClearHistory",
        })
        SaveManager:SetFolder("Flumium/Configs")
        SaveManager:BuildConfigSection(Tabs.UI)
        SaveManager:LoadAutoloadConfig()
    end
    if InterfaceManager then
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder("Flumium")
        InterfaceManager:BuildInterfaceSection(Tabs.UI)
    end
end)

-- ============================================================
-- UNLOAD HOOKS
-- ============================================================
__regFn(function()
    getgenv().Flumium_LoopsRunning = false
end)

__regFn(function()
    aimbotEnabled = false
    aiming = false
    currentTarget = nil
    aim2Enabled = false
    aim2ing = false
    aim2Target = nil
    silentAim.MasterEnabled = false
    silentAim.Enabled = false
    silentAim.CachedTarget = nil
    silentAim.CachedCFrame = nil
    markerClick.Enabled = false
end)

__regFn(function()
    if type(disableSilentHook) == "function" then pcall(disableSilentHook) end
    if type(disableKunaiHook)  == "function" then pcall(disableKunaiHook)  end
end)

__regFn(function()
    if getgenv().Flumium_TeleportFailedConn then
        pcall(function() getgenv().Flumium_TeleportFailedConn:Disconnect() end)
        getgenv().Flumium_TeleportFailedConn = nil
    end
end)

__regFn(function()
    ESP.Enabled = false
    ESP.Visible = false
    for p in pairs(espData) do clearPlayer(p) end
end)

__regFn(function()
    fastDeactivateLowDetail()
end)

__regFn(function()
    colors.RainbowSkin = false
    colors.RainbowHair = false
end)

__regFn(function()
    pcall(function() Window:Destroy() end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then local f = pg:FindFirstChild("Fluent"); if f then f:Destroy() end end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg then local f = cg:FindFirstChild("Fluent"); if f then f:Destroy() end end
    end)
end)

__regFn(function()
    if fovCircle       then pcall(function() fovCircle:Remove()       end) end
    if fovCircle2      then pcall(function() fovCircle2:Remove()      end) end
    if silentFovCircle then pcall(function() silentFovCircle:Remove() end) end
    getgenv().Flumium_Drawing_Fov1 = nil
    getgenv().Flumium_Drawing_Fov2 = nil
    getgenv().Flumium_Drawing_FovS = nil
end)

print("====================================")
print("✅ Flumium Client v1.4 загружен!")
print("📍 Region detection: IP → ip-api (Method 1)")
print("🚫 Random Server удалён")
print("🔁 Один клик = одна попытка телепорта")
print("🎯 Aimbot 2: клавиша [1], целится ВЫШЕ ГОЛОВЫ")
print("👁️ ESP: HP зелёный, MD фиолетовый, Dodge ON/КД (кейбинд убран)")
print("📌 RightControl - скрыть меню")
print("====================================")
