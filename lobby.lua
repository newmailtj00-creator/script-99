--[[
    40/80 :: Lobby
    PlaceId 79546208627805
    ------------------------------------------------
    Remote ที่ใช้ (ยืนยันจาก source ของ lobby):
      ReplicatedStorage.RemoteEvents
        ├─ UpdateEquipped   -> FireServer("None")
        └─ TeleportEvent    -> FireServer("Add", slot)
                            -> FireServer("Chosen", nil, 1,
                               {Hardcore="On", Biome="Jungle"})
    Teleporter1..3 -> BillboardHolder.BillboardGui.Players.Text = "0/5"
]]

if getgenv().FN4080_LOBBY then
    warn("[40/80] lobby already running")
    return
end
getgenv().FN4080_LOBBY = true

local RS = game:GetService("ReplicatedStorage")

local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title    = "40/80",
    SubTitle = "Lobby",
    TabWidth = 150,
    Size     = UDim2.fromOffset(520, 420),
    Acrylic  = true,
    Theme    = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Tabs = {
    Queue = Window:AddTab({ Title = "Queue",    Icon = "log-in" }),
    Set   = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}
local Options = Fluent.Options

local CFG = {
    auto    = false,
    unequip = true,
    biome   = "Jungle",
    hardcore = "On",
    delay   = 0.6,
    target  = "0/5",
}

-- =====================================================
-- remotes
-- =====================================================
local function remotes()
    return RS:FindFirstChild("RemoteEvents")
end

local function doUnequip()
    local R = remotes()
    local r = R and R:FindFirstChild("UpdateEquipped")
    if not r then return false end
    return pcall(function() r:FireServer("None") end)
end

local function findSlot()
    for i = 3, 1, -1 do
        local tp     = workspace:FindFirstChild("Teleporter" .. i)
        local holder = tp and tp:FindFirstChild("BillboardHolder")
        local gui    = holder and holder:FindFirstChild("BillboardGui")
        local label  = gui and gui:FindFirstChild("Players")
        if label and label.Text == CFG.target then
            return i
        end
    end
    return nil
end

local function join(slot)
    local R = remotes()
    local r = R and R:FindFirstChild("TeleportEvent")
    if not r then return false end

    r:FireServer("Add", slot)
    task.wait(0.5)
    r:FireServer("Chosen", nil, 1, {
        Hardcore = CFG.hardcore,
        Biome    = CFG.biome,
    })
    return true
end

local function notify(text, dur)
    Fluent:Notify({ Title = "40/80", Content = text, Duration = dur or 4 })
end

-- =====================================================
-- loop
-- =====================================================
task.spawn(function()
    local fired = false
    while task.wait(CFG.delay) do
        if not CFG.auto then
            fired = false
            continue
        end
        if fired then continue end

        local slot = findSlot()
        if slot then
            if CFG.unequip then doUnequip() end
            join(slot)
            fired = true
            notify("joined slot " .. slot)
        end
    end
end)

-- =====================================================
-- UI
-- =====================================================
Tabs.Queue:AddToggle("AutoQueue", {
    Title = "Auto Queue",
    Description = "หา server ที่ " .. CFG.target .. " แล้วเข้าเอง",
    Default = false,
    Callback = function(v) CFG.auto = v end,
})

Tabs.Queue:AddButton({
    Title = "Join Now",
    Callback = function()
        local slot = findSlot()
        if not slot then return notify("ไม่มีช่องว่าง") end
        if CFG.unequip then doUnequip() end
        join(slot)
        notify("joined slot " .. slot)
    end,
})

Tabs.Queue:AddDropdown("Biome", {
    Title = "Biome",
    Values = { "Jungle", "Snow", "Volcanic", "Normal" },
    Default = "Jungle",
    Callback = function(v) CFG.biome = v end,
})

Tabs.Queue:AddDropdown("Hardcore", {
    Title = "Hardcore",
    Values = { "On", "Off" },
    Default = "On",
    Callback = function(v) CFG.hardcore = v end,
})

Tabs.Set:AddSlider("Delay", {
    Title = "Loop Delay (s)",
    Default = 0.6, Min = 0.2, Max = 3, Rounding = 1,
    Callback = function(v) CFG.delay = v end,
})

Tabs.Set:AddToggle("Unequip", {
    Title = "Unequip Class",
    Default = true,
    Callback = function(v) CFG.unequip = v end,
})

Tabs.Set:AddButton({
    Title = "Status",
    Callback = function()
        local t = {}
        for i = 1, 3 do
            local tp = workspace:FindFirstChild("Teleporter" .. i)
            local h  = tp and tp:FindFirstChild("BillboardHolder")
            local g  = h and h:FindFirstChild("BillboardGui")
            local l  = g and g:FindFirstChild("Players")
            t[#t + 1] = ("T%d=%s"):format(i, l and l.Text or "?")
        end
        notify(table.concat(t, "  "), 6)
    end,
})

Window:SelectTab(1)
notify("Lobby loaded", 4)
