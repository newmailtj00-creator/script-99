--[[
    40/80 :: Loader
    Dispatch ตาม PlaceId
]]

if getgenv().FN4080 then
    warn("[40/80] loader already running")
    return
end
getgenv().FN4080 = true

local BASE = "https://raw.githubusercontent.com/newmailtj00-creator/script-99/main/"

local MAP = {
    [79546208627805]  = BASE .. "lobby.lua",
    [126509999114328] = BASE .. "game.lua",
}

local url = MAP[game.PlaceId]

if not url then
    warn("[40/80] unsupported place: " .. tostring(game.PlaceId))
    game.StarterGui:SetCore("SendNotification", {
        Title = "40/80",
        Text = "PlaceId " .. tostring(game.PlaceId) .. " not supported",
        Duration = 8,
    })
    return
end

local ok, err = pcall(function()
    loadstring(game:HttpGet(url))()
end)

if not ok then
    warn("[40/80] load failed: " .. tostring(err))
end
