if _G.__BRIDGE_ESP then return end
_G.__BRIDGE_ESP = true

loadstring(game:HttpGet("https://raw.githubusercontent.com/sharedechoes/Matcha-Luas/refs/heads/main/homesick.lua"))()
local homesick = _G.homesick or shared.homesick
homesick.changelogEnabled = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local BRIDGE_PARTS = { "SaintsRightArm", "SaintsRightLeg", "SaintsRibcage", "SaintsLeftArm", "SaintsLeftLeg", "SaintsHeart" }

local S = {
    esp_on = true, esp_box = true, esp_boxcol = Color3.fromRGB(255, 255, 255),
    esp_name = true, esp_hp = true, esp_hptxt = false, esp_dist = false,
    esp_tracer = false, esp_traccol = Color3.fromRGB(255, 255, 255),
    esp_maxdist = 8000, esp_teamcheck = true,
    ls_streak = true, ls_age = true, ls_stand = true, ls_vampire = true,
    silent_gun_on = false, silent_stand_on = false,
    aim_bone = "Head", aim_fov = 180, aim_smooth = 6, aim_teamcheck = true,
    wep_norecoil = false, wep_nospread = false,
    brg_on = true, brg_col = Color3.fromRGB(255, 214, 0), brg_fill = 0.6,
    brg_name = true, brg_dist = true,
    crp_on = true, crp_col = Color3.fromRGB(255, 0, 0),
    crp_marker = true, crp_owner = true, crp_dist = true,
    qte_on = false, qte_mash = true, qte_react = true,
    fish_on = false,
    wmark_on = true,
}
for _, pn in ipairs(BRIDGE_PARTS) do S["brg_" .. pn] = true end

local function g(key, default)
    local v = S[key]
    return v ~= nil and v or default
end

-- drawing pool
local pool = {}
local lastPC = 0
local function plrId(plr)
    local t = type(plr)
    if t == "number" then return plr end
    if t == "string" then return plr end
    local id = plr.UserId
    if id then return id end
    id = plr.Name
    if id then return id end
    return tostring(plr)
end

local function getD(plr, key, kind)
    local id = plrId(plr)
    if not pool[id] then pool[id] = {} end
    if not pool[id][key] then pool[id][key] = Drawing.new(kind) end
    return pool[id][key]
end

local function wipePool()
    for _, t in pairs(pool) do
        for _, d in pairs(t) do d.Visible = false end
    end
end

local function hidePlr(plr)
    local t = pool[plrId(plr)]
    if t then for _, d in pairs(t) do d.Visible = false end end
end

local function cleanPlr(plr)
    local id = plrId(plr)
    local t = pool[id]
    if t then
        for _, d in pairs(t) do pcall(d.Remove, d) end
        pool[id] = nil
    end
end

pcall(function() Players.PlayerRemoving:Connect(cleanPlr) end)

-- bridge pool
local bPool = {}

-- corpse data
local corpsePart = nil
local corpseOwner = nil
local crFill, crOutline, crMarker, crOwnerT, crDistT

local remotes = RS:FindFirstChild("Remotes")
local ce = remotes and remotes:FindFirstChild("CorpseSpawnedEvent")
if ce then
    pcall(function()
        ce["OnClientEvent"]:Connect(function(...)
            local a = { ... }
            corpsePart = a[1]
            corpseOwner = a[2] or "Unknown"
            if corpsePart then
                local ok, r = pcall(function() return corpsePart:IsA("BasePart") end)
                if not ok or not r then corpsePart = nil
                elseif not bPool[corpsePart] then
                    bPool[corpsePart] = {}
                end
            end
        end)
    end)
end

-- auto QTE
task.spawn(function()
    task.wait(1)
    local ok, wr = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Wrapper"))
    if not ok then return end
    local ok2, qe = pcall(wr, RS:WaitForChild("QTEEvent"))
    if not ok2 then return end
    pcall(function()
        qe.OnClientEvent:Connect(function(act)
            if not g("qte_on") then return end
            if act == "StartMashing" and g("qte_mash") then
                task.wait(0.05)
                qe:FireServer("MashingSuccess")
            elseif act == "StartReaction" and g("qte_react") then
                task.wait(0.35)
                qe:FireServer("Success")
            end
        end)
    end)
end)

-- auto fish
local fishState = "idle"
local SFX = RS:FindFirstChild("SFX")
local fishBite = SFX and SFX:FindFirstChild("FishBite")
local fishCatch = SFX and SFX:FindFirstChild("FishCatch")
local fishEsc = SFX and SFX:FindFirstChild("FishEscape")

local function click()
    local ok = pcall(mouse1click)
    if not ok then
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

local function equipRod()
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return false end
    local rod = bp:FindFirstChild("FishingRod")
    if rod and rod:IsA("Tool") then
        local char = LP.Character
        if char then rod.Parent = char; return true end
    end
    return false
end

local function listen(sound, cb)
    if not sound then return end
    local ok, sig = pcall(function() return sound:GetPropertyChangedSignal("Playing") end)
    if ok then
        pcall(function() sig:Connect(function() if sound.Playing then pcall(cb) end end) end)
    else
        spawn(function()
            local last = false
            while true do
                local now = sound.Playing
                if now and not last then pcall(cb) end
                last = now
                task.wait(0.05)
            end
        end)
    end
end

listen(fishBite, function()
    if not g("fish_on") then return end
    click()
    fishState = "hooked"
end)
listen(fishCatch, function()
    if not g("fish_on") then return end
    task.wait(0.8)
    fishState = "idle"
end)
listen(fishEsc, function()
    if not g("fish_on") then return end
    task.wait(0.8)
    fishState = "idle"
end)

spawn(function()
    while true do
        if g("fish_on") and fishState == "idle" then
            local bp = LP:FindFirstChild("Backpack")
            local rod = bp and bp:FindFirstChild("FishingRod")
            if rod then
                equipRod()
                task.wait(0.15)
                click()
                fishState = "waiting"
            end
        end
        task.wait(1)
    end
end)

local function isPart(v)
    local ok, r = pcall(function() return v:IsA("BasePart") end)
    return ok and r
end
-- part discovery: scan Workspace only (dead parts tracked via remote event)
spawn(function()
    while true do
        for _, name in ipairs(BRIDGE_PARTS) do
            local item = workspace:FindFirstChild(name, true)
            if item and isPart(item) and not bPool[item] then
                bPool[item] = {}
            end
        end
        task.wait(2)
    end
end)

-- watermark + FOV
local startTime = os.clock()
local function runtimeStr()
    local t = os.clock() - startTime
    local m = math.floor(t / 60)
    local s = math.floor(t % 60)
    return string.format("%02d:%02d", m, s)
end
local wm = Drawing.new("Text")
wm.Size = 13
wm.Outline = true
wm.Color = Color3.fromRGB(180, 100, 255)
wm.Position = Vector2.new(10, 10)

local fovCircle = Drawing.new("Circle")
fovCircle.ZIndex = 5
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Visible = false

local frame = 0
-- render function
local function render()
    local LP = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    if not LP or not Camera then return end

    local plrList = Players:GetPlayers()
    local pCount = #plrList
    if pCount ~= lastPC then wipePool(); lastPC = pCount end

    local espOn = g("esp_on")

    wm.Visible = g("wmark_on")
    if g("wmark_on") then
        wm.Text = "INCURSION : Bridger Western  |  " .. runtimeStr() .. "  |  " .. pCount .. " players"
    end

    local silentOn = g("silent_gun_on") or g("silent_stand_on")
    fovCircle.Visible = silentOn
    if silentOn then
        local vs = Camera.ViewportSize
        fovCircle.Position = Vector2.new(vs.X / 2, vs.Y / 2)
        fovCircle.Radius = g("aim_fov")
    end

    -- Silent aim — move mouse to nearest target within FOV
    if silentOn then
        local vs = Camera.ViewportSize
        local center = Vector2.new(vs.X / 2, vs.Y / 2)
        local fov = g("aim_fov")
        local teamCheck = g("aim_teamcheck")
        local hitbox = g("aim_bone")
        local bestDist = math.huge
        local bestSp = nil
        for _, plr in ipairs(plrList) do
            if plr == LP then continue end
            local char = plr.Character
            if not char then continue end
            if teamCheck and plr.Team and LP.Team and plr.Team == LP.Team then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local part
            if hitbox == "Head" then
                part = char:FindFirstChild("Head")
            else
                part = char:FindFirstChild("HumanoidRootPart")
            end
            if not part then continue end
            local aimPos = hitbox == "Head" and part.Position + Vector3.new(0, 0.5, 0) or part.Position
            local sp, vis = WorldToScreen(aimPos)
            if not vis or not sp then continue end
            local dx = sp.X - center.X
            local dy = sp.Y - center.Y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < bestDist and d <= fov then
                bestDist = d
                bestSp = sp
            end
        end
        if bestSp then
            local smooth = g("aim_smooth")
            if smooth and smooth > 0 then
                local uis = game:GetService("UserInputService")
                local ok, cur = pcall(function() return uis:GetMouseLocation() end)
                if ok then
                    local step = math.min(1, 1 / (smooth * 1.5))
                    mousemoveabs(cur.X + (bestSp.X - cur.X) * step, cur.Y + (bestSp.Y - cur.Y) * step)
                else
                    mousemoveabs(bestSp.X, bestSp.Y)
                end
            else
                mousemoveabs(bestSp.X, bestSp.Y)
            end
        end
    end

    if not espOn then
        for plr, _ in pairs(pool) do hidePlr(plr) end
        return
    end

    local lChar = LP.Character
    local lRoot = lChar and lChar:FindFirstChild("HumanoidRootPart")
    local mPos = lRoot and lRoot.Position or Vector3.new()

    -- PLAYER ESP
    local vs = Camera.ViewportSize
    for i, plr in ipairs(plrList) do
        if plr == LP then hidePlr(plr) else
            if g("esp_teamcheck") and plr.Team and LP.Team and plr.Team == LP.Team then
                hidePlr(plr); continue
            end
            local char = plr.Character
            if not char then hidePlr(plr); continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then hidePlr(plr); continue end
            local dist = (root.Position - mPos).Magnitude
            if dist > g("esp_maxdist") then hidePlr(plr); continue end
            local head = char:FindFirstChild("Head")
            if not head then hidePlr(plr); continue end
            local headTop = head.Position + Vector3.new(0, head.Size.Y / 2, 0)
            local hp, hVis = WorldToScreen(headTop)
            if not hVis then hidePlr(plr); continue end

            local pid = plr.UserId or plr.Name
            local eH = math.min(3200 / math.max(dist, 1), 200)
            local eW = eH * 0.55
            local y1 = hp.Y
            local y2 = hp.Y + eH
            local x1 = hp.X
            local bx = x1 - eW / 2
            local cx = math.max(bx, 0); local cy = math.max(y1, 0)
            local cw = math.min(eW, vs.X - cx); local ch = math.min(eH, vs.Y - cy)

            if g("esp_box") then
                local box = getD(plr, "box", "Square")
                box.Visible = true; box.Position = Vector2.new(cx, cy); box.Size = Vector2.new(cw, ch)
                box.Color = g("esp_boxcol"); box.Filled = false; box.Thickness = 1
            else local b = pool[pid] and pool[pid].box; if b then b.Visible = false end end

            if g("esp_name") then
                local nameT = getD(plr, "name", "Text"); nameT.Visible = true
                nameT.Text = plr.Name; nameT.Position = Vector2.new(x1, y1 - 18); nameT.Size = 13
                nameT.Color = g("esp_boxcol"); nameT.Center = true; nameT.Outline = true
            else local n = pool[pid] and pool[pid].name; if n then n.Visible = false end end

            if g("esp_hp") then
                local hpBg = getD(plr, "hpBg", "Square"); local hpFill = getD(plr, "hpFill", "Square")
                hpBg.Visible = true; hpFill.Visible = true
                local pct = math.max(0, math.min(1, hum.Health / hum.MaxHealth))
                local hc = Color3.fromRGB((1 - pct) * 255, pct * 255, 0)
                hpBg.Position = Vector2.new(bx - 2, y2 + 2); hpBg.Size = Vector2.new(eW + 4, 3)
                hpBg.Color = Color3.fromRGB(30, 30, 30); hpBg.Filled = true; hpBg.Thickness = 0
                hpFill.Position = Vector2.new(bx - 2, y2 + 2); hpFill.Size = Vector2.new((eW + 4) * pct, 3)
                hpFill.Color = hc; hpFill.Filled = true; hpFill.Thickness = 0
            else
                local b = pool[pid] and pool[pid].hpBg; if b then b.Visible = false end
                local f = pool[pid] and pool[pid].hpFill; if f then f.Visible = false end
            end

            if g("esp_hptxt") then
                local hpTx = getD(plr, "hpTx", "Text"); hpTx.Visible = true
                hpTx.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                hpTx.Position = Vector2.new(x1, y2 + 8); hpTx.Size = 11
                hpTx.Color = Color3.fromRGB(57, 255, 20); hpTx.Center = true; hpTx.Outline = true
            else local h = pool[pid] and pool[pid].hpTx; if h then h.Visible = false end end

            if g("esp_dist") then
                local distT = getD(plr, "dist", "Text"); distT.Visible = true
                local dy = g("esp_hptxt") and y2 + 22 or y2 + 8
                distT.Text = math.floor(dist) .. "m"; distT.Position = Vector2.new(x1, dy); distT.Size = 11
                distT.Color = Color3.fromRGB(200, 200, 200); distT.Center = true; distT.Outline = true
            else local d = pool[pid] and pool[pid].dist; if d then d.Visible = false end end

            if g("esp_tracer") then
                local tracer = getD(plr, "tracer", "Line"); tracer.Visible = true
                tracer.From = Vector2.new(x1, y2); tracer.To = vs / 2
                tracer.Color = g("esp_traccol"); tracer.Thickness = 1
            else local t = pool[pid] and pool[pid].tracer; if t then t.Visible = false end end

            -- cached leaderstats/attributes/vampire (every 5 frames)
            if not pcache then pcache = {} end
            if not pcache[pid] then pcache[pid] = {} end
            local pc = pcache[pid]
            if frame % 5 == 0 then
                local lt = plr:FindFirstChild("leaderstats")
                local streakObj = lt and lt:FindFirstChild("STREAK")
                local ageObj = lt and lt:FindFirstChild("Age")
                pc.streakVal = streakObj and streakObj.Value or nil
                pc.ageVal = ageObj and ageObj.Value or nil
                pc.standAttr = plr:GetAttribute("EquippedStand")
                pc.hasVF = false
                if g("ls_vampire") then
                    for _, tl in ipairs(char:GetChildren()) do
                        if tl:IsA("Tool") and string.find(string.lower(tl.Name), "vampire") then pc.hasVF = true; break end
                    end
                    if not pc.hasVF then
                        local bp2 = plr:FindFirstChild("Backpack")
                        if bp2 then
                            for _, tl in ipairs(bp2:GetChildren()) do
                                if tl:IsA("Tool") and string.find(string.lower(tl.Name), "vampire") then pc.hasVF = true; break end
                            end
                        end
                    end
                end
            end

            local statLines = {}
            if g("ls_streak") and pc.streakVal ~= nil then table.insert(statLines, "S:" .. tostring(pc.streakVal)) end
            if g("ls_age") and pc.ageVal ~= nil then table.insert(statLines, "A:" .. tostring(pc.ageVal)) end
            if g("ls_stand") and pc.standAttr and pc.standAttr ~= "" then table.insert(statLines, tostring(pc.standAttr)) end
            if pc.hasVF then table.insert(statLines, "VAMPIRE") end

            local statY = g("esp_name") and (y1 - 31) or (y1 - 13)
            for i2, line in ipairs(statLines) do
                local st = getD(plr, "stat_" .. i2, "Text"); st.Visible = true
                st.Text = line; st.Position = Vector2.new(x1, statY - (i2 - 1) * 13); st.Size = 11
                st.Color = pc.hasVF and line == "VAMPIRE" and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 0)
                st.Center = true; st.Outline = true
            end
            for i2 = #statLines + 1, 5 do
                local st = pool[pid] and pool[pid]["stat_" .. i2]
                if st then st.Visible = false end
            end
        end
    end

    -- cleanup stale pool + pcache entries (every 30 frames)
    -- (frame incremented in RenderStepped callback)
    if frame % 30 == 0 then
        for id, _ in pairs(pool) do
            local found
            for _, p in ipairs(plrList) do
                if p.UserId == id or p.Name == id then found = true; break end
            end
            if not found then
                local t = pool[id]
                if t then
                    for _, d in pairs(t) do pcall(d.Remove, d) end
                    pool[id] = nil
                end
                if pcache then pcache[id] = nil end
            end
        end
    end

    -- BRIDGE CHAMS
    for part, t in pairs(bPool) do
        if not part or not part.Parent then
            if t then for _, d in pairs(t) do pcall(d.Remove, d) end end
            bPool[part] = nil
        elseif g("brg_on") then
            local partTog = g("brg_" .. part.Name)
            if not partTog then
                if t then for _, d in pairs(t) do d.Visible = false end end
            else
                local d = (part.Position - mPos).Magnitude
                local pp = part.Position
                if not t._c then t._c = {} end
                local c = t._c
                if not c.pos or (c.pos - pp).Magnitude > 0.5 then
                    c.sp, c.vis = WorldToScreen(pp)
                    c.pos = pp
                end
                local sp, vis = c.sp, c.vis
                if vis then
                    local sz = part.Size
                    local scale = 80 / math.max(d, 1)
                    local w = math.max(sz.X * scale, 6)
                    local h = math.max(sz.Y * scale, 6)
                    local mnX, mnY = sp.X - w / 2, sp.Y - h / 2
                    local mxX, mxY = sp.X + w / 2, sp.Y + h / 2
                    if not t.fill then t.fill = Drawing.new("Square") end
                    if not t.outline then t.outline = Drawing.new("Square") end
                    if not t.name then
                        t.name = Drawing.new("Text")
                        t.name.Center = true
                        t.name.Outline = true
                    end
                    if not t.dist then
                        t.dist = Drawing.new("Text")
                        t.dist.Center = true
                        t.dist.Outline = true
                    end
                    t.fill.Size = Vector2.new(w, h)
                    t.fill.Position = Vector2.new(mnX, mnY)
                    t.fill.Color = g("brg_col")
                    t.fill.Filled = true
                    t.fill.Thickness = 0
                    t.fill.Transparency = 1 - g("brg_fill")
                    t.fill.Visible = true
                    t.outline.Size = Vector2.new(w, h)
                    t.outline.Position = Vector2.new(mnX, mnY)
                    t.outline.Color = g("brg_col")
                    t.outline.Filled = false
                    t.outline.Thickness = 1.5
                    t.outline.Visible = true
                    t.name.Text = part.Name
                    t.name.Position = Vector2.new(mnX + w / 2, mnY - 16)
                    t.name.Size = 12
                    t.name.Color = g("brg_col")
                    t.name.Visible = g("brg_name")
                    t.dist.Text = math.floor(d) .. "m"
                    t.dist.Position = Vector2.new(mnX + w / 2, mxY + 2)
                    t.dist.Size = 11
                    t.dist.Color = Color3.fromRGB(200, 200, 200)
                    t.dist.Visible = g("brg_dist")
                elseif t then
                    for _, d in pairs(t) do d.Visible = false end
                end
            end
        elseif t then
            for _, d in pairs(t) do d.Visible = false end
        end
    end

    -- CORPSE TRACKER (distance-based sizing, no 8-corner)
    if g("crp_on") and corpsePart and corpsePart.Parent then
        if not crFill then
            crFill = Drawing.new("Square")
            crOutline = Drawing.new("Square")
            crMarker = Drawing.new("Circle")
            crMarker.NumSides = 32
            crMarker.Radius = 40
            crOwnerT = Drawing.new("Text")
            crOwnerT.Center = true
            crOwnerT.Outline = true
            crDistT = Drawing.new("Text")
            crDistT.Center = true
            crDistT.Outline = true
        end
        local sp, vis = WorldToScreen(corpsePart.Position)
        local d = (corpsePart.Position - mPos).Magnitude
        if vis then
            local sz = corpsePart.Size
            local scale = 80 / math.max(d, 1)
            local w = math.max(sz.X * scale, 8)
            local h = math.max(sz.Y * scale, 8)
            local mnX, mnY = sp.X - w / 2, sp.Y - h / 2
            local mxX, mxY = sp.X + w / 2, sp.Y + h / 2
            crFill.Size = Vector2.new(w, h); crFill.Position = Vector2.new(mnX, mnY)
            crFill.Color = g("crp_col"); crFill.Filled = true; crFill.Thickness = 0
            crFill.Transparency = 0.5; crFill.Visible = g("crp_marker")
            crOutline.Size = Vector2.new(w, h); crOutline.Position = Vector2.new(mnX, mnY)
            crOutline.Color = Color3.fromRGB(255, 255, 255); crOutline.Filled = false
            crOutline.Thickness = 2; crOutline.Visible = g("crp_marker")
            crMarker.Position = Vector2.new(sp.X, sp.Y); crMarker.Color = g("crp_col")
            crMarker.Filled = true; crMarker.Thickness = 0; crMarker.Visible = g("crp_marker")
            crOwnerT.Text = "☠ " .. tostring(corpseOwner)
            crOwnerT.Position = Vector2.new(mnX + w / 2, mnY - 18)
            crOwnerT.Size = 13; crOwnerT.Color = g("crp_col"); crOwnerT.Visible = g("crp_owner")
            crDistT.Text = math.floor(d) .. "m"
            crDistT.Position = Vector2.new(mnX + w / 2, mxY + 2)
            crDistT.Size = 11; crDistT.Color = Color3.fromRGB(200, 200, 200); crDistT.Visible = g("crp_dist")
        elseif crFill then
            crFill.Visible = false; crOutline.Visible = false
            crMarker.Visible = false; crOwnerT.Visible = false; crDistT.Visible = false
        end
    elseif crFill then
        crFill.Visible = false; crOutline.Visible = false
        crMarker.Visible = false; crOwnerT.Visible = false; crDistT.Visible = false
    end
end

-- render loop
RunService.RenderStepped:Connect(function()
    frame = frame + 1
    local ok, err = pcall(render)
    if not ok then warn("[Bridge ESP] " .. tostring(err)) end
end)

-- ========== HOMESICK UI ==========
local window = homesick.createWindow("INCURSION : BridgerWestern", 420, 420)
window:setBadge("v2")
window:autoloadConfig("bridge_esp")
window:autoloadTheme("theme")

-- TAB: Player
local tabPlayer = window:addTab("Player")
local peSec = tabPlayer:addSection("Player ESP", "Left")
peSec:addToggle("esp_on", "Enabled", true, function(v) S.esp_on = v end)
peSec:addToggle("esp_box", "Box", true, function(v) S.esp_box = v end):addColorpicker("Box Color", Color3.fromRGB(255, 255, 255), true, function(col) S.esp_boxcol = col end)
peSec:addToggle("esp_name", "Name", true, function(v) S.esp_name = v end)
peSec:addToggle("esp_hp", "Health Bar", true, function(v) S.esp_hp = v end)
peSec:addToggle("esp_hptxt", "Health Text", false, function(v) S.esp_hptxt = v end)
peSec:addToggle("esp_dist", "Distance", false, function(v) S.esp_dist = v end)
peSec:addToggle("esp_tracer", "Tracers", false, function(v) S.esp_tracer = v end):addColorpicker("Tracer Color", Color3.fromRGB(255, 255, 255), true, function(col) S.esp_traccol = col end)
peSec:addSlider("esp_maxdist", "Max Dist", 100, 20000, 8000, function(v) S.esp_maxdist = v end)
peSec:addToggle("esp_teamcheck", "Team Check", true, function(v) S.esp_teamcheck = v end)

local lsSec = tabPlayer:addSection("Leaderstats", "Right")
lsSec:addToggle("ls_streak", "Show STREAK", true, function(v) S.ls_streak = v end)
lsSec:addToggle("ls_age", "Show Age", true, function(v) S.ls_age = v end)
lsSec:addToggle("ls_stand", "EquippedStand", true, function(v) S.ls_stand = v end)
lsSec:addToggle("ls_vampire", "Vampire Fist", true, function(v) S.ls_vampire = v end)

local wmSec = tabPlayer:addSection("Watermark", "Right")
wmSec:addToggle("wmark_on", "Show Watermark", true, function(v) S.wmark_on = v end)

-- TAB: Combat
local tabCombat = window:addTab("Combat")
local gunSec = tabCombat:addSection("Gun Silent Aim", "Left")
local gunTog = gunSec:addToggle("silent_gun_on", "Enabled", false, function(v) S.silent_gun_on = v end)
gunTog:addKeybind(nil, "Hold", true, function() end)

local standSec = tabCombat:addSection("Stand Silent Aim", "Left")
local standTog = standSec:addToggle("silent_stand_on", "Enabled", false, function(v) S.silent_stand_on = v end)
standTog:addKeybind(nil, "Hold", true, function() end)

local aimSec = tabCombat:addSection("Aim Settings", "Right")
aimSec:addDropdown("aim_bone", "Hitbox", {"Head", "Torso", "Nearest"}, {"Head"}, function(v) S.aim_bone = v[1] end)
aimSec:addSlider("aim_fov", "FOV Size", 10, 800, 180, function(v) S.aim_fov = v end)
aimSec:addSlider("aim_smooth", "Smoothing", 0, 20, 6, function(v) S.aim_smooth = v end)
aimSec:addToggle("aim_teamcheck", "Team Check", true, function(v) S.aim_teamcheck = v end)

local wepSec = tabCombat:addSection("Weapon Mods", "Right")
wepSec:addToggle("wep_norecoil", "No Recoil", false, function(v) S.wep_norecoil = v end)
wepSec:addToggle("wep_nospread", "No Spread", false, function(v) S.wep_nospread = v end)

-- TAB: World
local tabWorld = window:addTab("World")
local brgSec = tabWorld:addSection("Bridge Chams", "Left")
local brgTog = brgSec:addToggle("brg_on", "Bridge Chams", true, function(v) S.brg_on = v end)
brgTog:addColorpicker("Cham Color", Color3.fromRGB(255, 214, 0), true, function(col) S.brg_col = col end)
brgSec:addSlider("brg_fill", "Fill Opacity", 0, 100, 60, function(v) S.brg_fill = v / 100 end)
brgSec:addToggle("brg_name", "Show Part Name", true, function(v) S.brg_name = v end)
brgSec:addToggle("brg_dist", "Show Distance", true, function(v) S.brg_dist = v end)
brgSec:addSeparator()
for _, pn in ipairs(BRIDGE_PARTS) do
    brgSec:addToggle("brg_" .. pn, pn, true, function(v) S["brg_" .. pn] = v end)
end

local crpSec = tabWorld:addSection("Corpse Tracker", "Right")
local crpTog = crpSec:addToggle("crp_on", "Enabled", true, function(v) S.crp_on = v end)
crpTog:addColorpicker("Marker Color", Color3.fromRGB(255, 0, 0), true, function(col) S.crp_col = col end)
crpSec:addToggle("crp_marker", "Show Marker", true, function(v) S.crp_marker = v end)
crpSec:addToggle("crp_owner", "Show Owner", true, function(v) S.crp_owner = v end)
crpSec:addToggle("crp_dist", "Show Distance", true, function(v) S.crp_dist = v end)

-- TAB: Automation
local tabAuto = window:addTab("Auto")
local qteSec = tabAuto:addSection("Auto QTE", "Left")
qteSec:addToggle("qte_on", "Auto QTE", false, function(v) S.qte_on = v end)
qteSec:addToggle("qte_mash", "Auto Mash", true, function(v) S.qte_mash = v end)
qteSec:addToggle("qte_react", "Auto Reaction", true, function(v) S.qte_react = v end)

local fishSec = tabAuto:addSection("Auto Fish", "Right")
fishSec:addToggle("fish_on", "Auto Fish", false, function(v) S.fish_on = v end)

window.visible = true
window:render()

notify("Bridge ESP loaded", "Bridge ESP", 3)
