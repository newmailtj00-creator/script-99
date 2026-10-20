--[[
    40/80 :: 99 Nights Engine  v3
    =====================================================
    Fluent API (Groupbox) — แก้ปัญหา tab ว่าง
    =====================================================
    Tab 1  Accelerator  — auto กดเครื่องข้ามคืน
    Tab 2  Raid         — บุก stronghold ฆ่า cultist เก็บ gem
    Tab 3  Chop         — ตัดต้นไม้ทุกต้น
    Tab 4  Scan         — ดึงของจริงในเกมมาให้เลือก
]]

-- reload ได้ไม่จำกัด: ปิดหน้าต่างเก่าก่อน ถ้ามี
if getgenv().FN4080_Window then
    pcall(function()
        getgenv().FN4080_Window:Destroy()
    end)
    getgenv().FN4080_Window = nil
    print("[40/80] old window destroyed")
end

print("[40/80] building UI...")

local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

local okFluent, Fluent = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not okFluent or type(Fluent) ~= "table" then
    warn("[40/80] Fluent load failed: " .. tostring(Fluent))
    game.StarterGui:SetCore("SendNotification", {
        Title = "40/80",
        Text = "Fluent load failed — check internet",
        Duration = 10,
    })
    return
end
print("[40/80] Fluent loaded")

local Window = Fluent:CreateWindow({
    Title    = "40/80",
    SubTitle = "99 Nights",
    TabWidth = 150,
    Size     = UDim2.fromOffset(570, 480),
    Acrylic  = true,
    Theme    = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Tabs = {
    Acc  = Window:AddTab({ Title = "Accelerator", Icon = "clock" }),
    Raid = Window:AddTab({ Title = "Raid",        Icon = "swords" }),
    Chop = Window:AddTab({ Title = "Chop",        Icon = "axe" }),
    Scan = Window:AddTab({ Title = "Scan",        Icon = "radar" }),
}
print("[40/80] tabs created")
local Options = Fluent.Options

getgenv().FN4080_Window = Window
print("[40/80] window created")

-- =====================================================
-- config
-- =====================================================
local CFG = {
    accOn        = false,
    accPrompt    = nil,
    accConfirm   = true,
    accDelay     = 1.5,
    accOnlyNight = true,

    raidOn     = false,
    raidRadius = 120,
    raidDelay  = 0.25,
    raidNames  = { "cultist" },

    chopOn     = false,
    chopRadius = 45,
    chopDelay  = 0.20,
    chopAll    = true,
    chopPrompt = nil,
}

-- =====================================================
-- helpers
-- =====================================================
local function char()
    return LP.Character
end

local function root()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function posOf(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, p = pcall(function() return obj:GetPivot().Position end)
        if ok then return p end
    end
    return nil
end

local function allPrompts()
    local out = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            out[#out + 1] = d
        end
    end
    return out
end

local function promptLabel(p)
    return ("%s  [%s]"):format(p:GetFullName(), tostring(p.ActionText))
end

local function nearestPrompt(filterFn, radius)
    local r = root()
    if not r then return nil end

    local best, bestD
    for _, p in ipairs(allPrompts()) do
        if filterFn(p) then
            local pos = posOf(p.Parent)
            if pos then
                local d = (pos - r.Position).Magnitude
                if d <= radius and (not bestD or d < bestD) then
                    best, bestD = p, d
                end
            end
        end
    end
    return best
end

local function walkTo(pos)
    local h = hum()
    if h then pcall(function() h:MoveTo(pos) end) end
end

local function notify(text, dur)
    Fluent:Notify({ Title = "40/80", Content = text, Duration = dur or 4 })
end

-- =====================================================
-- 1) ACCELERATOR
-- =====================================================
local function clickGuiButton(keywords)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end

    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
            local hay = ((d.Text or "") .. " " .. d.Name):lower()
            for _, k in ipairs(keywords) do
                if hay:find(k, 1, true) then
                    if firesignal then pcall(firesignal, d.MouseButton1Click) end
                    pcall(function() d:Activate() end)
                    return true
                end
            end
        end
    end
    return false
end

local function isNight()
    local ct = game:GetService("Lighting").ClockTime
    return ct < 6 or ct >= 18
end

task.spawn(function()
    while task.wait(CFG.accDelay) do
        if not CFG.accOn or not CFG.accPrompt then continue end
        if CFG.accOnlyNight and not isNight() then continue end

        local r = root()
        if not r then continue end

        local target
        for _, p in ipairs(allPrompts()) do
            if p:GetFullName() == CFG.accPrompt then
                target = p
                break
            end
        end
        if not target then continue end

        local pos = posOf(target.Parent)
        if pos and (pos - r.Position).Magnitude > 12 then
            walkTo(pos)
            continue
        end

        pcall(fireproximityprompt, target)

        if CFG.accConfirm then
            task.wait(0.4)
            clickGuiButton({
                "skip", "accelerat", "activate", "confirm",
                "yes", "use", "night",
            })
        end
    end
end)

-- =====================================================
-- 2) RAID
-- =====================================================
local function isCultist(model)
    if not model then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    local name = model.Name:lower()
    for _, k in ipairs(CFG.raidNames) do
        if name:find(k, 1, true) then return true end
    end
    return false
end

local function nearestCultist(radius)
    local r = root()
    if not r then return nil end

    local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Health > 0 then
            local m = d.Parent
            if isCultist(m) then
                local pos = posOf(m)
                if pos then
                    local dist = (pos - r.Position).Magnitude
                    if dist <= radius and (not bestD or dist < bestD) then
                        best, bestD = m, dist
                    end
                end
            end
        end
    end
    return best, bestD
end

local function equipWeapon()
    local c = char()
    if not c then return nil end

    local eq = c:FindFirstChildOfClass("Tool")
    if eq then return eq end

    local bp = c:FindFirstChild("Backpack")
    if not bp then return nil end

    local tool = bp:FindFirstChildWhichIsA("Tool")
    if tool then
        local h = hum()
        if h then pcall(function() h:EquipTool(tool) end) end
        return tool
    end
    return nil
end

task.spawn(function()
    while task.wait(CFG.raidDelay) do
        if not CFG.raidOn then continue end
        local r = root()
        if not r then continue end

        local target, dist = nearestCultist(CFG.raidRadius)
        if not target then continue end

        local pos = posOf(target)
        if not pos then continue end

        if dist > 9 then
            walkTo(pos)
        else
            pcall(function()
                r.CFrame = CFrame.lookAt(r.Position,
                    Vector3.new(pos.X, r.Position.Y, pos.Z))
            end)
            local w = equipWeapon()
            if w then pcall(function() w:Activate() end) end
        end
    end
end)

-- =====================================================
-- 3) CHOP
-- =====================================================
task.spawn(function()
    while task.wait(CFG.chopDelay) do
        if not CFG.chopOn then continue end
        local r = root()
        if not r then continue end

        local target = nearestPrompt(function(p)
            if CFG.chopAll then return true end
            return CFG.chopPrompt and p:GetFullName() == CFG.chopPrompt
        end, CFG.chopRadius)

        if target then
            local pos = posOf(target.Parent)
            if pos and (pos - r.Position).Magnitude > 12 then
                walkTo(pos)
            end
            pcall(fireproximityprompt, target)
        end
    end
end)

-- =====================================================
-- SCAN helpers
-- =====================================================
local accDrop, chopDrop

local function refreshPromptDrops()
    local list = {}
    for _, p in ipairs(allPrompts()) do
        list[#list + 1] = promptLabel(p)
    end
    table.sort(list)
    if #list == 0 then list = { "(none)" } end

    if accDrop then accDrop:SetValues(list) end
    if chopDrop then chopDrop:SetValues(list) end
    return list
end

local function dumpGui()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return {} end
    local out = {}
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            out[#out + 1] = ("%s | %s | visible=%s"):format(
                d.ClassName, d:GetFullName(), tostring(d.Visible))
        end
    end
    return out
end

-- =====================================================
-- UI — ACCELERATOR
-- =====================================================
do
    local G = Tabs.Acc:AddLeftGroupbox("Skip Night")
    G:AddLabel("1 Cultist Gem = ข้าม 1 คืน (1:30) ไม่มี cooldown")

    G:AddToggle("AccToggle", {
        Title = "Auto Skip Night",
        Default = false,
        Callback = function(v) CFG.accOn = v end,
    })

    accDrop = G:AddDropdown("AccPrompt", {
        Title = "Accelerator Prompt",
        Description = "กด Scan ก่อน แล้วเลือก",
        Values = { "(run Scan)" },
        Default = nil,
        Callback = function(v) CFG.accPrompt = v end,
    })

    G:AddToggle("AccConfirm", {
        Title = "Auto Confirm Menu",
        Default = true,
        Callback = function(v) CFG.accConfirm = v end,
    })

    G:AddToggle("AccNight", {
        Title = "Only At Night",
        Default = true,
        Callback = function(v) CFG.accOnlyNight = v end,
    })

    G:AddSlider("AccDelay", {
        Title = "Loop Delay (s)",
        Default = 1.5, Min = 0.3, Max = 5, Rounding = 1,
        Callback = function(v) CFG.accDelay = v end,
    })

    local G2 = Tabs.Acc:AddRightGroupbox("Test")
    G2:AddButton({
        Title = "Fire Prompt Once",
        Callback = function()
            if not CFG.accPrompt then return notify("ยังไม่ได้เลือก prompt") end
            for _, p in ipairs(allPrompts()) do
                if p:GetFullName() == CFG.accPrompt then
                    pcall(fireproximityprompt, p)
                    return notify("fired: " .. p.Name)
                end
            end
            notify("prompt not found")
        end,
    })
    G2:AddButton({
        Title = "Check Time",
        Callback = function()
            local ct = game:GetService("Lighting").ClockTime
            notify(("ClockTime %.1f — %s"):format(ct, isNight() and "NIGHT" or "DAY"))
        end,
    })
end

-- =====================================================
-- UI — RAID
-- =====================================================
do
    local G = Tabs.Raid:AddLeftGroupbox("Cultist")
    G:AddLabel("Cultist Stronghold = แหล่ง gem ไม่อั้น")

    G:AddToggle("RaidToggle", {
        Title = "Auto Raid",
        Default = false,
        Callback = function(v) CFG.raidOn = v end,
    })

    G:AddSlider("RaidRadius", {
        Title = "Search Radius",
        Default = 120, Min = 20, Max = 400, Rounding = 0,
        Callback = function(v) CFG.raidRadius = v end,
    })

    G:AddSlider("RaidDelay", {
        Title = "Attack Delay (s)",
        Default = 0.25, Min = 0.05, Max = 1.5, Rounding = 2,
        Callback = function(v) CFG.raidDelay = v end,
    })

    G:AddInput("RaidNames", {
        Title = "Name Filter",
        Description = "คั่นด้วย ,",
        Default = "cultist",
        Placeholder = "cultist",
        Callback = function(v)
            local t = {}
            for s in v:gmatch("[^,]+") do
                local s2 = s:match("^%s*(.-)%s*$"):lower()
                if #s2 > 0 then t[#t + 1] = s2 end
            end
            CFG.raidNames = (#t > 0) and t or { "cultist" }
        end,
    })

    local G2 = Tabs.Raid:AddRightGroupbox("Inspect")
    G2:AddButton({
        Title = "Scan Cultists",
        Callback = function()
            local n, names = 0, {}
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("Humanoid") and d.Health > 0 then
                    local m = d.Parent
                    if isCultist(m) then
                        n += 1
                        if n <= 5 then names[#names + 1] = m.Name end
                    end
                end
            end
            notify(("cultists: %d | %s"):format(n, table.concat(names, ", ")), 6)
        end,
    })
    G2:AddButton({
        Title = "List All Humanoids",
        Callback = function()
            local seen, list = {}, {}
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("Humanoid") and d.Parent then
                    local n = d.Parent.Name
                    if not seen[n] then
                        seen[n] = true
                        list[#list + 1] = n
                    end
                end
            end
            print("========== HUMANOIDS ==========")
            print(table.concat(list, "\n"))
            notify(("humanoid names: %d (see console)"):format(#list), 6)
        end,
    })
end

-- =====================================================
-- UI — CHOP
-- =====================================================
do
    local G = Tabs.Chop:AddLeftGroupbox("Trees")

    G:AddToggle("ChopToggle", {
        Title = "Auto Chop",
        Default = false,
        Callback = function(v) CFG.chopOn = v end,
    })

    G:AddSlider("ChopRadius", {
        Title = "Search Radius",
        Default = 45, Min = 5, Max = 250, Rounding = 0,
        Callback = function(v) CFG.chopRadius = v end,
    })

    G:AddSlider("ChopDelay", {
        Title = "Delay (s)",
        Default = 0.2, Min = 0.05, Max = 1.5, Rounding = 2,
        Callback = function(v) CFG.chopDelay = v end,
    })

    G:AddToggle("ChopAll", {
        Title = "Any Prompt",
        Default = true,
        Callback = function(v) CFG.chopAll = v end,
    })

    chopDrop = G:AddDropdown("ChopPrompt", {
        Title = "Specific Prompt",
        Values = { "(run Scan)" },
        Default = nil,
        Callback = function(v) CFG.chopPrompt = v end,
    })
end

-- =====================================================
-- UI — SCAN
-- =====================================================
do
    local G = Tabs.Scan:AddLeftGroupbox("Prompts")
    G:AddButton({
        Title = "Scan Prompts",
        Callback = function()
            local list = refreshPromptDrops()
            notify(("prompts: %d"):format(#list))
        end,
    })
    G:AddButton({
        Title = "Dump Prompts to File",
        Callback = function()
            local lines = {}
            for _, p in ipairs(allPrompts()) do
                local pos = posOf(p.Parent)
                lines[#lines + 1] = ("%s | %s | %s"):format(
                    p:GetFullName(), tostring(p.ActionText),
                    pos and tostring(pos) or "?")
            end
            local s = table.concat(lines, "\n")
            print(s)
            if writefile then pcall(writefile, "4080_prompts.txt", s) end
            notify("saved 4080_prompts.txt")
        end,
    })

    local G2 = Tabs.Scan:AddRightGroupbox("Debug")
    G2:AddButton({
        Title = "Dump GUI Buttons",
        Callback = function()
            local list = dumpGui()
            print("========== GUI BUTTONS ==========")
            print(table.concat(list, "\n"))
            if writefile then pcall(writefile, "4080_gui.txt", table.concat(list, "\n")) end
            notify(("gui buttons: %d"):format(#list), 5)
        end,
    })
    G2:AddButton({
        Title = "Dump Remotes (30s)",
        Callback = function()
            local cap = {}
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    local e = cap[self.Name]
                    if not e then e = { n = 0, a = "" }; cap[self.Name] = e end
                    e.n += 1
                    local args = {...}
                    local t = {}
                    for i = 1, math.min(#args, 4) do t[i] = tostring(args[i]) end
                    e.a = table.concat(t, ", ")
                end
                return old(self, ...)
            end)

            task.delay(30, function()
                local keys = {}
                for k in pairs(cap) do keys[#keys + 1] = k end
                table.sort(keys)

                local lines = {}
                for _, k in ipairs(keys) do
                    lines[#lines + 1] = ("%-24s x%-4d %s"):format(k, cap[k].n, cap[k].a)
                end
                local s = table.concat(lines, "\n")
                print(s)
                if writefile then pcall(writefile, "4080_remotes.txt", s) end
                notify("saved 4080_remotes.txt", 5)
            end)

            notify("capturing 30s — go play", 5)
        end,
    })
end

Window:SelectTab(1)
notify("loaded — Scan ก่อน แล้วค่อยเปิด toggle", 6)
