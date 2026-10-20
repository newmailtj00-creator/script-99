--[[
    40/80 :: 99 Nights Engine  v5  (Rayfield UI)
    =====================================================
    Tab 1  Accelerator  — auto กดเครื่องข้ามคืน
    Tab 2  Raid         — บุก stronghold ฆ่า cultist เก็บ gem
    Tab 3  Chop         — ตัดต้นไม้ทุกต้น
    Tab 4  Scan         — ดึงของจริงในเกมมาให้เลือก
]]

print("[40/80] start")

if getgenv().FN4080_Unload then
    pcall(getgenv().FN4080_Unload)
    getgenv().FN4080_Unload = nil
    print("[40/80] old ui unloaded")
end

local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

local okUI, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not okUI or type(Rayfield) ~= "table" then
    warn("[40/80] Rayfield load failed: " .. tostring(Rayfield))
    game.StarterGui:SetCore("SendNotification", {
        Title = "40/80",
        Text = "UI library load failed — check internet",
        Duration = 10,
    })
    return
end
print("[40/80] Rayfield loaded")

local Window = Rayfield:CreateWindow({
    Name = "40/80 | 99 Nights",
    LoadingTitle = "40/80",
    LoadingSubtitle = "engine",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})
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
local function char() return LP.Character end
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
    Rayfield:Notify({
        Title = "40/80",
        Content = text,
        Duration = dur or 4,
    })
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
            if p:GetFullName() == CFG.accPrompt then target = p; break end
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
            clickGuiButton({ "skip", "accelerat", "activate", "confirm", "yes", "use", "night" })
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
                r.CFrame = CFrame.lookAt(r.Position, Vector3.new(pos.X, r.Position.Y, pos.Z))
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
            if pos and (pos - r.Position).Magnitude > 12 then walkTo(pos) end
            pcall(fireproximityprompt, target)
        end
    end
end)

-- =====================================================
-- UI
-- =====================================================
local TabAcc  = Window:CreateTab("Accelerator", 4483362458)
local TabRaid = Window:CreateTab("Raid", 4483362458)
local TabChop = Window:CreateTab("Chop", 4483362458)
local TabScan = Window:CreateTab("Scan", 4483362458)
print("[40/80] tabs created")

-- ── Accelerator ──────────────────────────────────────
TabAcc:CreateSection("Skip Night")

TabAcc:CreateToggle({
    Name = "Auto Skip Night",
    CurrentValue = false,
    Flag = "accOn",
    Callback = function(v) CFG.accOn = v end,
})

TabAcc:CreateDropdown({
    Name = "Accelerator Prompt",
    Options = { "(press Scan first)" },
    CurrentOption = { "(press Scan first)" },
    MultipleOptions = false,
    Flag = "accPrompt",
    Callback = function(v)
        if type(v) == "table" then v = v[1] end
        CFG.accPrompt = v
    end,
})

TabAcc:CreateToggle({
    Name = "Auto Confirm Menu",
    CurrentValue = true,
    Flag = "accConfirm",
    Callback = function(v) CFG.accConfirm = v end,
})

TabAcc:CreateToggle({
    Name = "Only At Night",
    CurrentValue = true,
    Flag = "accNight",
    Callback = function(v) CFG.accOnlyNight = v end,
})

TabAcc:CreateSlider({
    Name = "Loop Delay",
    Range = { 0.3, 5 },
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "accDelay",
    Callback = function(v) CFG.accDelay = v end,
})

TabAcc:CreateButton({
    Name = "Fire Prompt Once",
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

TabAcc:CreateButton({
    Name = "Check Time",
    Callback = function()
        local ct = game:GetService("Lighting").ClockTime
        notify(("ClockTime %.1f — %s"):format(ct, isNight() and "NIGHT" or "DAY"))
    end,
})

-- ── Raid ─────────────────────────────────────────────
TabRaid:CreateSection("Cultist")

TabRaid:CreateToggle({
    Name = "Auto Raid",
    CurrentValue = false,
    Flag = "raidOn",
    Callback = function(v) CFG.raidOn = v end,
})

TabRaid:CreateSlider({
    Name = "Search Radius",
    Range = { 20, 400 },
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 120,
    Flag = "raidRadius",
    Callback = function(v) CFG.raidRadius = v end,
})

TabRaid:CreateSlider({
    Name = "Attack Delay",
    Range = { 0.05, 1.5 },
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.25,
    Flag = "raidDelay",
    Callback = function(v) CFG.raidDelay = v end,
})

TabRaid:CreateInput({
    Name = "Name Filter",
    CurrentValue = "cultist",
    PlaceholderText = "cultist,wolf",
    RemoveTextAfterFocusLost = false,
    Callback = function(t)
        local list = {}
        for s in tostring(t):gmatch("[^,]+") do
            local s2 = s:match("^%s*(.-)%s*$"):lower()
            if #s2 > 0 then list[#list + 1] = s2 end
        end
        CFG.raidNames = (#list > 0) and list or { "cultist" }
    end,
})

TabRaid:CreateButton({
    Name = "Scan Cultists",
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

TabRaid:CreateButton({
    Name = "List All Humanoids",
    Callback = function()
        local seen, list = {}, {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent then
                local n = d.Parent.Name
                if not seen[n] then seen[n] = true; list[#list + 1] = n end
            end
        end
        print("========== HUMANOIDS ==========")
        print(table.concat(list, "\n"))
        notify(("names: %d (see console)"):format(#list), 6)
    end,
})

-- ── Chop ─────────────────────────────────────────────
TabChop:CreateSection("Trees")

TabChop:CreateToggle({
    Name = "Auto Chop",
    CurrentValue = false,
    Flag = "chopOn",
    Callback = function(v) CFG.chopOn = v end,
})

TabChop:CreateSlider({
    Name = "Search Radius",
    Range = { 5, 250 },
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 45,
    Flag = "chopRadius",
    Callback = function(v) CFG.chopRadius = v end,
})

TabChop:CreateSlider({
    Name = "Delay",
    Range = { 0.05, 1.5 },
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.2,
    Flag = "chopDelay",
    Callback = function(v) CFG.chopDelay = v end,
})

TabChop:CreateToggle({
    Name = "Any Prompt",
    CurrentValue = true,
    Flag = "chopAll",
    Callback = function(v) CFG.chopAll = v end,
})

-- ── Scan ─────────────────────────────────────────────
TabScan:CreateSection("Prompts")

TabScan:CreateButton({
    Name = "Scan Prompts",
    Callback = function()
        local list = {}
        for _, p in ipairs(allPrompts()) do list[#list + 1] = promptLabel(p) end
        table.sort(list)
        if #list == 0 then list = { "(none)" } end
        print("========== PROMPTS ==========")
        print(table.concat(list, "\n"))
        notify(("prompts: %d (see console)"):format(#list), 6)
    end,
})

TabScan:CreateButton({
    Name = "Dump Prompts to File",
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

TabScan:CreateSection("Debug")

TabScan:CreateButton({
    Name = "Dump GUI Buttons",
    Callback = function()
        local pg = LP:FindFirstChild("PlayerGui")
        local out = {}
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    out[#out + 1] = ("%s | %s | visible=%s"):format(
                        d.ClassName, d:GetFullName(), tostring(d.Visible))
                end
            end
        end
        local s = table.concat(out, "\n")
        print("========== GUI BUTTONS ==========")
        print(s)
        if writefile then pcall(writefile, "4080_gui.txt", s) end
        notify(("gui buttons: %d"):format(#out), 5)
    end,
})

TabScan:CreateButton({
    Name = "Dump Remotes (30s)",
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

getgenv().FN4080_Unload = function()
    pcall(function() Window:Destroy() end)
end

print("[40/80] ready")
notify("loaded — Scan ก่อน แล้วค่อยเปิด toggle", 6)
