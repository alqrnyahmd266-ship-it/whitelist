--[[
    SimpleHub
    discord: S / 5edf

    R  = تشغيل/إيقاف الطيران
    M  = فتح/قفل القائمة
    -  = بطاقة اللاعب
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local carsFolder = workspace:WaitForChild("PlayersCars")
local playerGui = player:WaitForChild("PlayerGui")

-- لو السكربت اشتغل قبل، نظّف النسخة القديمة (حتى النسخ القديمة قبل SimpleHub)
for _, key in ipairs({"SimpleHubCleanup", "CarBoostCleanup"}) do
    if _G[key] then
        pcall(_G[key])
        _G[key] = nil
    end
end
for _, n in ipairs({"SimpleHub", "SimpleHubESP", "SimpleHubWaypoints", "CarBoostGui", "DhabESP"}) do
    local old = playerGui:FindFirstChild(n)
    if old then old:Destroy() end
end

local alive = true
local conns = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(conns, c)
    return c
end
local refreshAction = nil -- يتعرّف تحت (نظام الاختصارات)

---------------------------------------------------------------------
-- الشكل
---------------------------------------------------------------------
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local C = {
    bg       = rgb(13, 13, 15),
    surface  = rgb(20, 20, 23),
    raised   = rgb(28, 28, 32),
    hover    = rgb(36, 36, 41),
    border   = rgb(40, 40, 46),
    text     = rgb(236, 236, 240),
    muted    = rgb(138, 138, 148),
    faint    = rgb(90, 90, 100),
    accent   = rgb(60, 150, 255),
    accentHi = rgb(90, 168, 255),
    green    = rgb(64, 200, 120),
    amber    = rgb(240, 180, 70),
    red      = rgb(235, 90, 90),
    white    = Color3.new(1, 1, 1),
}
local ESP_COLOR = C.accent -- أزرق

local FONT = "rbxasset://fonts/families/BuilderSans.json"
local MONO = "rbxasset://fonts/families/RobotoMono.json"
local REG, MED, SEMI, BOLD = Enum.FontWeight.Regular, Enum.FontWeight.Medium, Enum.FontWeight.SemiBold, Enum.FontWeight.Bold
local function face(weight, path) return Font.new(path or FONT, weight or REG) end

local function new(class, props)
    local o = Instance.new(class)
    local parent = props.Parent
    props.Parent = nil
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = o}) end
local function stroke(o, col, t)
    return new("UIStroke", {Color = col or C.border, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o})
end
local function pad(o, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = o,
    })
end
local function box(parent, props)
    props.BorderSizePixel = 0
    props.BackgroundColor3 = props.BackgroundColor3 or C.surface
    props.Parent = parent
    return new("Frame", props)
end
local function text(parent, str, size, color, weight, props)
    props = props or {}
    props.BackgroundTransparency = 1
    props.Text = str
    props.TextSize = size
    props.TextColor3 = color or C.text
    props.FontFace = props.FontFace or face(weight)
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.Parent = parent
    return new("TextLabel", props)
end
local function tween(o, t, goal, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end
local function isPress(i)
    return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1
end
local function pressScale(o)
    local sc = new("UIScale", {Parent = o})
    o.InputBegan:Connect(function(i) if isPress(i) then tween(sc, 0.08, {Scale = 0.95}) end end)
    o.InputEnded:Connect(function(i) if isPress(i) then tween(sc, 0.2, {Scale = 1}, Enum.EasingStyle.Back) end end)
end
local function hex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- أيقونات مرسومة (بدل الرموز اللي تطلع مربعات)
local function iconBars(parent, color)
    for i = -1, 1 do
        local b = box(parent, {Size = UDim2.fromOffset(16, 2), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, i * 5), BackgroundColor3 = color or C.text})
        corner(b, 1)
    end
end
local function iconCross(parent, color, size)
    for _, r in ipairs({45, -45}) do
        local b = box(parent, {Size = UDim2.fromOffset(size or 12, 2), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5), Rotation = r, BackgroundColor3 = color or C.muted})
        corner(b, 1)
    end
end
local function iconChevronUp(parent, color, y)
    for _, s in ipairs({-1, 1}) do
        local b = box(parent, {Size = UDim2.fromOffset(14, 3), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, s * 4.5, 0.5, y or -4), Rotation = s * 45, BackgroundColor3 = color or C.text})
        corner(b, 2)
    end
end

---------------------------------------------------------------------
-- الشاشة
---------------------------------------------------------------------
local gui = new("ScreenGui", {
    Name = "SimpleHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000, Parent = playerGui,
})

local lineLayer = box(gui, {Name = "Tracers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0})

local avatarImage = ""
local avatarTargets = {}
task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    if ok and img then
        avatarImage = img
        for _, t in ipairs(avatarTargets) do t.Image = img end
    end
end)

-- العلامة فوق يسار
local watermark = box(gui, {
    Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
    Position = UDim2.fromOffset(16, 62), BackgroundColor3 = C.bg, BackgroundTransparency = 0.06,
})
corner(watermark, 8)
stroke(watermark)
pad(watermark, 12, 12)
text(watermark, string.format('SimpleHub  <font color="%s">|</font>  <font color="%s">discord  S / 5edf</font>', hex(C.faint), hex(C.muted)),
    13, C.text, SEMI, {RichText = true, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30)})

---------------------------------------------------------------------
-- بطاقة اللاعب
---------------------------------------------------------------------
local CARD_OPEN, CARD_CLOSED = UDim2.fromOffset(16, 100), UDim2.fromOffset(-290, 100)
local card = box(gui, {Size = UDim2.fromOffset(250, 74), Position = CARD_CLOSED, BackgroundColor3 = C.bg, Visible = false})
corner(card, 10)
stroke(card)

local cardAvatar = new("ImageLabel", {Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.raised, Image = avatarImage, Parent = card})
corner(cardAvatar, 23)
table.insert(avatarTargets, cardAvatar)

text(card, player.DisplayName, 14, C.text, SEMI, {Position = UDim2.fromOffset(72, 13), Size = UDim2.fromOffset(165, 18), TextTruncate = Enum.TextTruncate.AtEnd})
text(card, "@" .. player.Name, 12, C.muted, REG, {Position = UDim2.fromOffset(72, 30), Size = UDim2.fromOffset(165, 14), TextTruncate = Enum.TextTruncate.AtEnd})
local cardStats = text(card, "", 11, C.muted, MED, {RichText = true, Position = UDim2.fromOffset(72, 48), Size = UDim2.fromOffset(165, 14)})

local function getPing()
    local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and v then return math.floor(v + 0.5) end
    return math.floor(player:GetNetworkPing() * 2000 + 0.5)
end

local cardOpen, cardTween = false, nil
local function setCard(open)
    cardOpen = open
    if cardTween then cardTween:Cancel() end
    if open then
        card.Visible = true
        card.Position = CARD_CLOSED
        cardTween = tween(card, 0.4, {Position = CARD_OPEN})
    else
        cardTween = tween(card, 0.25, {Position = CARD_CLOSED})
        local my = cardTween
        my.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed and not cardOpen then card.Visible = false end
        end)
    end
end

local frames, acc = 0, 0
bind(RunService.RenderStepped, function(dt)
    frames += 1
    acc += dt
    if acc >= 0.5 then
        if cardOpen then
            local fps = math.floor(frames / acc + 0.5)
            local ping = getPing()
            local pc = ping < 80 and C.green or (ping < 150 and C.amber or C.red)
            local fc = fps >= 50 and C.green or (fps >= 30 and C.amber or C.red)
            cardStats.Text = string.format('PING <font color="%s">%dms</font>    FPS <font color="%s">%d</font>', hex(pc), ping, hex(fc), fps)
        end
        frames, acc = 0, 0
    end
end)

---------------------------------------------------------------------
-- الأزرار الجانبية (يمين فوق)
---------------------------------------------------------------------
local dock = box(gui, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 64),
    Size = UDim2.fromOffset(44, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = dock})

local function dockButton(order)
    local b = new("TextButton", {Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.bg, BackgroundTransparency = 0.04,
        AutoButtonColor = false, Text = "", LayoutOrder = order, Parent = dock})
    corner(b, 10)
    local s = stroke(b)
    pressScale(b)
    return b, s
end

local flyBtn, flyStroke = dockButton(1)
text(flyBtn, "FLY", 12, C.text, BOLD, {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
local flyDot = box(flyBtn, {Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), BackgroundColor3 = C.red})
corner(flyDot, 3)

local meBtn = dockButton(2)
local meImg = new("ImageLabel", {Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6),
    BackgroundColor3 = C.raised, Image = avatarImage, Parent = meBtn})
corner(meImg, 16)
table.insert(avatarTargets, meImg)

local menuBtn = dockButton(3)
iconBars(menuBtn, C.text)

---------------------------------------------------------------------
-- طيران السيارة
---------------------------------------------------------------------
local SPEED = 250
local running = false
local mobileForward = false
local loopConn = nil
local created = {}
local wheelWelds = {}
local settleTime = {}
local wasGrounded = {}
local travelling = false -- وقت التلبورت بالطيران نوقف لوب الطيران

local function getRoot(car)
    return car.PrimaryPart or car:FindFirstChild("Engine") or car:FindFirstChildOfClass("BasePart")
end

local function updateFlyUI()
    flyDot.BackgroundColor3 = running and C.green or C.red
    flyStroke.Color = running and C.accent or C.border
    if refreshAction then refreshAction("fly") end
end

local function stopFly()
    running = false
    mobileForward = false
    if refreshAction then refreshAction("forward") end
    if loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end
    for inst in pairs(created) do
        if inst and inst.Parent then inst:Destroy() end
    end
    table.clear(created)
    table.clear(wheelWelds)
    table.clear(settleTime)

    for _, car in ipairs(carsFolder:GetChildren()) do
        for _, d in ipairs(car:GetDescendants()) do
            if d.Name == "CustomSpeedPusher" or d.Name == "CustomStabilizer" or d.Name == "CustomWheelLock" then
                d:Destroy()
            end
        end
        local root = getRoot(car)
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    updateFlyUI()
end

local function getEffects(root)
    local pusher = root:FindFirstChild("CustomSpeedPusher")
    if not pusher then
        pusher = Instance.new("BodyVelocity")
        pusher.Name = "CustomSpeedPusher"
        pusher.MaxForce = Vector3.zero
        pusher.Parent = root
        created[pusher] = true
    end
    local gyro = root:FindFirstChild("CustomStabilizer")
    if not gyro then
        gyro = Instance.new("BodyGyro")
        gyro.Name = "CustomStabilizer"
        gyro.MaxTorque = Vector3.zero
        gyro.P = 3000
        gyro.D = 600
        gyro.Parent = root
        created[gyro] = true
    end
    return pusher, gyro
end

local GYRO_TORQUE = Vector3.new(400000, 400000, 400000)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function lockWheels(car, root)
    if wheelWelds[car] then return end
    local list = {}
    local rootAsm = root.AssemblyRootPart
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p ~= root and not p.Anchored and p.AssemblyRootPart ~= rootAsm then
            local w = Instance.new("WeldConstraint")
            w.Name = "CustomWheelLock"
            w.Part0 = root
            w.Part1 = p
            w.Parent = root
            created[w] = true
            table.insert(list, w)
        end
    end
    wheelWelds[car] = list
end

local function unlockWheels(car)
    local list = wheelWelds[car]
    if not list then return end
    for _, w in ipairs(list) do
        created[w] = nil
        if w.Parent then w:Destroy() end
    end
    wheelWelds[car] = nil
end

local function startFly()
    table.clear(wasGrounded)
    running = true
    updateFlyUI()

    loopConn = RunService.Heartbeat:Connect(function(dt)
        if not running or travelling then return end
        local char = player.Character
        if not (char and char:FindFirstChildOfClass("Humanoid")) then return end

        local look = Camera.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        local goingForward = UserInputService:IsKeyDown(Enum.KeyCode.W) or mobileForward

        for _, car in ipairs(carsFolder:GetChildren()) do
            local root = getRoot(car)
            if root then
                local pusher, gyro = getEffects(root)

                rayParams.FilterDescendantsInstances = {car, char}
                local hit = workspace:Raycast(root.Position, Vector3.new(0, -(root.Size.Y / 2 + 6), 0), rayParams)
                local grounded = hit ~= nil

                if flatLook.Magnitude > 0.01 then
                    gyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
                end

                if goingForward then
                    local dir = look
                    if grounded and look.Y < 0 and flatLook.Magnitude > 0.01 then
                        dir = flatLook.Unit
                    end
                    gyro.MaxTorque = GYRO_TORQUE
                    pusher.MaxForce = Vector3.new(900000, 900000, 900000)
                    pusher.Velocity = dir * SPEED + Vector3.new(0, 2, 0)
                else
                    pusher.MaxForce = Vector3.zero
                    pusher.Velocity = Vector3.zero
                    if grounded then
                        gyro.MaxTorque = Vector3.zero
                        if not wasGrounded[car] then
                            root.AssemblyAngularVelocity = Vector3.zero
                            local v = root.AssemblyLinearVelocity
                            root.AssemblyLinearVelocity = Vector3.new(v.X * 0.5, math.max(v.Y, -10), v.Z * 0.5)
                        end
                    else
                        gyro.MaxTorque = GYRO_TORQUE
                    end
                end

                if goingForward or not grounded then
                    lockWheels(car, root)
                    settleTime[car] = 0
                else
                    settleTime[car] = (settleTime[car] or 0) + dt
                    local vy = math.abs(root.AssemblyLinearVelocity.Y)
                    if wheelWelds[car] and settleTime[car] > 0.4 and vy < 3 then
                        unlockWheels(car)
                    end
                end
                wasGrounded[car] = grounded
            end
        end
    end)
end

local function toggleFly()
    if running then stopFly() else startFly() end
end

---------------------------------------------------------------------
-- الحماية من الإرجاع + التلبورت
---------------------------------------------------------------------
local guardOn = false
local lastPivot = setmetatable({}, {__mode = "k"})
local prevMover = nil
local allowUntil = 0
local tpHold = nil

-- يرجع الشي اللي تتحرك فيه: سيارتك لو راكب، أو شخصيتك
local function getMover()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if seat then
        local m = seat
        while m.Parent and m.Parent ~= workspace and m.Parent ~= carsFolder do
            m = m.Parent
        end
        if m:IsA("Model") and m ~= char then return m end
    end
    if char:FindFirstChild("HumanoidRootPart") then return char end
    return nil
end

local function zeroVelocity(model)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function moverSpeed(model)
    local root = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true))
    return root and root.AssemblyLinearVelocity.Magnitude or 0
end

-- نحفظ مكان كل قطعة بالسيارة وهي سليمة، عشان زر Fix car يرجع الكفرات
local carSnap = setmetatable({}, {__mode = "k"})
local function snapshotCar(car)
    local root = getRoot(car)
    if not root then return end
    local t = {}
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p ~= root then t[p] = root.CFrame:ToObjectSpace(p.CFrame) end
    end
    carSnap[car] = t
end

local function fixCar(car)
    car = car or getMover()
    if not car or car == player.Character then return false end
    local root = getRoot(car)
    if not root then return false end
    for _, d in ipairs(car:GetDescendants()) do
        if d.Name == "CustomSpeedPusher" or d.Name == "CustomStabilizer" or d.Name == "CustomWheelLock" then
            created[d] = nil
            d:Destroy()
        end
    end
    wheelWelds[car] = nil
    local snap = carSnap[car]
    if snap then
        for part, off in pairs(snap) do
            if part.Parent and not part.Anchored then part.CFrame = root.CFrame * off end
        end
    end
    -- نعدّلها واقفة ونرفعها شوي
    local _, yaw = root.CFrame:ToOrientation()
    local target = CFrame.new(root.Position + Vector3.new(0, 3, 0)) * CFrame.fromOrientation(0, yaw, 0)
    car:PivotTo(target * root.CFrame:Inverse() * car:GetPivot())
    zeroVelocity(car)
    lastPivot[car] = car:GetPivot()
    allowUntil = os.clock() + 1
    return true
end

local revertTimes = {}
local guardPausedUntil = 0

bind(RunService.Heartbeat, function(dt)
    local mover = getMover()
    if not mover then prevMover = nil return end

    -- صورة للسيارة وهي واقفة وسليمة
    if mover ~= player.Character and not carSnap[mover] and not running and not travelling and moverSpeed(mover) < 3 then
        snapshotCar(mover)
    end
    local now = os.clock()
    local cur = mover:GetPivot()

    -- مسك مكان التلبورت شوي عشان السيرفر ما يرجعك
    if tpHold and tpHold.model == mover and now < tpHold.untilT then
        if (cur.Position - tpHold.cf.Position).Magnitude > 8 then
            mover:PivotTo(tpHold.cf)
            zeroVelocity(mover)
        end
        lastPivot[mover] = mover:GetPivot()
        prevMover = mover
        allowUntil = now + 0.2
        return
    end

    -- لو تبدّل الشي اللي تتحرك فيه (ركبت/نزلت) نبدأ من جديد
    if mover ~= prevMover then
        lastPivot[mover] = cur
        prevMover = mover
        return
    end

    local last = lastPivot[mover]
    if guardOn and last and now > allowUntil and now > guardPausedUntil then
        local limit = math.max(40, moverSpeed(mover) * dt * 4 + 15)
        if (cur.Position - last.Position).Magnitude > limit then
            -- لو السيرفر يتهاوش معنا كثير نوقف شوي بدل ما تتكسر السيارة
            table.insert(revertTimes, now)
            while revertTimes[1] and now - revertTimes[1] > 4 do table.remove(revertTimes, 1) end
            if #revertTimes >= 3 then
                guardPausedUntil = now + 5
                table.clear(revertTimes)
                lastPivot[mover] = cur
                print("[SimpleHub] anti rollback paused 5s (server keeps pulling)")
                return
            end

            local isCar = mover ~= player.Character
            local root = isCar and getRoot(mover)
            if root then lockWheels(mover, root) end -- نثبت الكفرات قبل النقل عشان ما تطير
            mover:PivotTo(last)
            zeroVelocity(mover)
            if root then
                task.delay(0.6, function()
                    if not running and not travelling and mover.Parent then
                        unlockWheels(mover)
                        zeroVelocity(mover)
                    end
                end)
            end
            return
        end
    end
    lastPivot[mover] = cur
end)

local tp = {
    physics = true, speed = 200, status = "Idle", token = nil,
    step = 150,      -- كم يمشي قبل ما يوقف
    pause = 1.2,     -- كم يوقف بين كل خطوة (عشان السيرفر يسجل مكانك)
    height = 25,     -- ارتفاع الطيران فوق الأرض
    learn = true,    -- لو السيرفر رجعك يصغّر الخطوة من نفسه
    onLearn = nil,
}

-- البوابات: لو الطريق يمر فوقها، السكربت ينزل ويمشي من خلالها على الأرض بدل ما يطير فوقها
local GATES = {Vector3.new(297.7, 3.0, -5.6)}
local GATE_RADIUS = 120 -- لو الطريق يمر بهالمسافة من البوابة يمشي من خلالها
local GATE_APPROACH = 35 -- كم يبعد قبل/بعد البوابة

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- أقرب مسافة (أفقية) بين البوابة والطريق، ووين تقع على الطريق (0 = البداية، 1 = النهاية)
local function gateOnPath(a, b, g)
    local ab = flat(b - a)
    local len2 = ab:Dot(ab)
    if len2 < 1e-6 then return math.huge, 0 end
    local t = flat(g - a):Dot(ab) / len2
    local tc = math.clamp(t, 0, 1)
    local closest = flat(a) + ab * tc
    return (closest - flat(g)).Magnitude, t
end

-- يقسم الرحلة لمراحل: طيران عالي عادي، ومراحل على الأرض من خلال البوابات
local function buildRoute(start, target)
    local hits = {}
    for _, g in ipairs(GATES) do
        local d, t = gateOnPath(start, target, g)
        if d < GATE_RADIUS and t > 0.02 and t < 0.98 then
            table.insert(hits, {g = g, t = t})
        end
    end
    table.sort(hits, function(x, y) return x.t < y.t end)

    local legs = {}
    local dirAll = flat(target - start)
    dirAll = dirAll.Magnitude > 0.01 and dirAll.Unit or Vector3.new(0, 0, 1)
    for _, h in ipairs(hits) do
        local g = h.g
        table.insert(legs, {pos = g - dirAll * GATE_APPROACH, low = false, gate = true}) -- يوصل قبل البوابة وينزل
        table.insert(legs, {pos = g, low = true, gate = true})                             -- يمشي للبوابة على الأرض
        table.insert(legs, {pos = g + dirAll * GATE_APPROACH, low = true, gate = true})    -- يطلع من الجهة الثانية
    end
    table.insert(legs, {pos = target, low = false})
    return legs
end

-- طيران للمكان بالفيزياء (نفس طريقة طيران السيارة اللي السيرفر يقبلها)
local function physicsTravel(mover, finalTarget, token, lift)
    local isChar = mover == player.Character
    local root = isChar and mover:FindFirstChild("HumanoidRootPart") or getRoot(mover)
    if not root then return end

    local pusher, gyro
    if isChar then
        pusher = Instance.new("BodyVelocity")
        pusher.Name = "SimpleHubTravel"
        pusher.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        pusher.Velocity = Vector3.zero
        pusher.Parent = root
        created[pusher] = true
    else
        pusher, gyro = getEffects(root)
        lockWheels(mover, root)
        local look = flat(root.CFrame.LookVector)
        if look.Magnitude > 0.01 then gyro.CFrame = CFrame.lookAt(root.Position, root.Position + look) end
    end

    travelling = true
    local legs = buildRoute(root.Position, finalTarget)
    local gateCount = 0
    for _, leg in ipairs(legs) do
        if leg.gate and leg.low then gateCount += 1 end
    end

    for li, leg in ipairs(legs) do
        if not (alive and tp.token == token) then break end
        local target = leg.pos + Vector3.new(0, lift, 0)
        -- المراحل الأرضية تمشي على ارتفاع البوابة، والعالية تطلع فوق
        local cruiseY = leg.low and target.Y or (math.max(root.Position.Y, target.Y) + tp.height)
        local phase = leg.low and 3 or 1
        local stuckT, lastPos = 0, root.Position
        local walked = 0          -- كم مشى من آخر وقفة
        local sinceSafe = 0       -- كم مشى من آخر مكان ثابت ما رجعه منه السيرفر

        local function hold(seconds)
            pusher.Velocity = Vector3.zero
            local t0 = os.clock()
            local anchor = root.Position
            while alive and tp.token == token and os.clock() - t0 < seconds do
                RunService.Heartbeat:Wait()
                if (root.Position - anchor).Magnitude > 25 then return false end -- رجعه وهو واقف
                lastPivot[mover] = mover:GetPivot()
                allowUntil = os.clock() + 0.3
            end
            return true
        end

        local function onPulledBack()
            if tp.learn then
                tp.step = math.max(20, math.floor(sinceSafe * 0.6 / 10) * 10)
                tp.speed = math.max(60, math.floor(tp.speed * 0.85 / 5) * 5)
                if tp.onLearn then tp.onLearn() end
            end
            tp.status = string.format("Pulled back  ·  step %d, speed %d", tp.step, tp.speed)
            print("[SimpleHub] " .. tp.status)
            walked, sinceSafe = 0, 0
            if not leg.low then phase = 1 end
            hold(1)
            lastPos = root.Position
        end

        while alive and tp.token == token do
            local dt = RunService.Heartbeat:Wait()
            if getMover() ~= mover or not root.Parent then
                tp.token = nil
                break
            end
            local pos = root.Position
            local moved = (pos - lastPos).Magnitude

            -- السيرفر رجعنا؟ (قفزة كبيرة فجأة)
            local expected = pusher.Velocity.Magnitude * dt
            if moved > math.max(25, expected * 3) then
                onPulledBack()
                pos = root.Position
                moved = 0
            else
                walked += moved
                sinceSafe += moved
            end

            -- كل خطوة نوقف شوي عشان السيرفر يسجل مكانك
            if walked >= tp.step then
                tp.status = "Waiting for server..."
                if hold(tp.pause) then
                    sinceSafe = 0
                else
                    onPulledBack()
                end
                walked = 0
                pos = root.Position
                lastPos = pos
            end

            local goal

            if phase == 1 then
                goal = Vector3.new(pos.X, cruiseY, pos.Z)
                if math.abs(pos.Y - cruiseY) < 4 then phase = 2 end
            end
            if phase == 2 then
                goal = Vector3.new(target.X, cruiseY, target.Z)
                if (flat(pos) - flat(target)).Magnitude < 6 then phase = 3 end
            end
            if phase == 3 then
                goal = target
                if (pos - target).Magnitude < 4 then break end
            end

            local d = goal - pos
            local maxSpd = leg.low and math.min(tp.speed, 60) or tp.speed -- من البوابة يمشي بشويش
            local spd = math.min(maxSpd, d.Magnitude * 3 + 15)
            pusher.MaxForce = Vector3.new(900000, 900000, 900000)
            pusher.Velocity = d.Magnitude > 0.1 and d.Unit * spd or Vector3.zero
            if gyro then
                gyro.MaxTorque = GYRO_TORQUE
                local f = flat(d)
                if f.Magnitude > 1 then gyro.CFrame = CFrame.lookAt(pos, pos + f) end
            end

            -- لو علق: في الطيران العالي يرفع أكثر، وعلى الأرض يرفع شوي
            if moved < maxSpd * dt * 0.1 then
                stuckT += dt
                if stuckT > 1.5 then
                    if leg.low then
                        target += Vector3.new(0, 3, 0)
                    else
                        cruiseY += 30
                        phase = 1
                    end
                    stuckT = 0
                end
            else
                stuckT = 0
            end
            lastPos = pos

            lastPivot[mover] = mover:GetPivot()
            allowUntil = os.clock() + 0.3
            local left = (flat(pos) - flat(finalTarget)).Magnitude
            local label
            if leg.gate then
                label = "Through gate"
            else
                label = phase == 1 and "Climbing" or phase == 2 and "Flying" or "Landing"
            end
            tp.status = string.format("%s  ·  %dm left", label, math.floor(left))
        end
    end

    pusher.Velocity = Vector3.zero
    pusher.MaxForce = Vector3.zero
    if isChar then
        created[pusher] = nil
        pusher:Destroy()
    else
        if gyro and not running then gyro.MaxTorque = Vector3.zero end
        if not running then unlockWheels(mover) end
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    travelling = false
end

local function teleportTo(pos)
    local mover = getMover()
    if not mover then return false end
    local lift = (mover == player.Character) and 3 or 4
    local token = {}
    tp.token = token

    if tp.physics then
        task.spawn(function()
            physicsTravel(mover, pos, token, lift)
            if tp.token == token then
                tp.status = "Arrived"
                tp.token = nil
            end
        end)
        return true
    end

    local target = pos + Vector3.new(0, lift, 0)
    local pivot = mover:GetPivot()
    local cf = CFrame.new(target) * (pivot - pivot.Position)
    mover:PivotTo(cf)
    zeroVelocity(mover)
    lastPivot[mover] = cf
    tpHold = {model = mover, cf = cf, untilT = os.clock() + 3}
    tp.status = "Arrived"
    tp.token = nil
    return true
end

---------------------------------------------------------------------
-- الشوب: أوامر السيرفر وقراءة القيم
---------------------------------------------------------------------
local Request = nil
task.spawn(function()
    Request = ReplicatedStorage:WaitForChild("Dhab"):WaitForChild("Request")
end)

local ITEMS = {
    {id = "WaterJug", name = "Water Jug", sub = "جالون موية"},
    {id = "Antidote", name = "Antidote",  sub = "ترياق سم"},
    {id = "Kabsa",    name = "Kabsa",     sub = "كبسة"},
}
local LOW_PERCENT = 10

local function numVal(d)
    return d:IsA("NumberValue") or d:IsA("IntValue")
end

local function nameMatches(name, keys)
    local n = string.lower(name)
    if n:find("max", 1, true) or n:find("jug", 1, true) then return false end
    for _, k in ipairs(keys) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function findStat(keys)
    local char = player.Character
    for _, holder in ipairs({player, char}) do
        if holder then
            for k, v in pairs(holder:GetAttributes()) do
                if type(v) == "number" and nameMatches(k, keys) then
                    return function()
                        return holder:GetAttribute(k), holder:GetAttribute("Max" .. k) or holder:GetAttribute(k .. "Max")
                    end
                end
            end
        end
    end
    for _, holder in ipairs({char, player}) do
        if holder then
            for _, d in ipairs(holder:GetDescendants()) do
                if numVal(d) and not d:IsDescendantOf(playerGui) and nameMatches(d.Name, keys) then
                    return function()
                        if not d.Parent then return nil end
                        local maxObj = d.Parent:FindFirstChild("Max" .. d.Name) or d.Parent:FindFirstChild(d.Name .. "Max")
                        return d.Value, (maxObj and numVal(maxObj) and maxObj.Value) or d:GetAttribute("Max")
                    end
                end
            end
        end
    end
    return nil
end

local HUNGER_KEYS = {"hunger", "satiety", "fullness", "food", "شبع", "جوع"}
local THIRST_KEYS = {"thirst", "hydration", "water", "drink", "عطش", "موي", "ماء"}

local function getPercent(keys)
    local getter = findStat(keys)
    if not getter then return nil end
    local cur, max = getter()
    if type(cur) ~= "number" then return nil end
    max = (type(max) == "number" and max > 0) and max or 100
    if cur > max then max = cur end
    return math.clamp(cur / max * 100, 0, 100)
end

local MONEY_NAMES = {"money", "cash", "coins", "coin", "gold", "balance", "riyal", "sar", "فلوس", "ريال"}
local function getMoney()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, d in ipairs(ls:GetChildren()) do
            if numVal(d) and nameMatches(d.Name, MONEY_NAMES) then return d.Value end
        end
    end
    for k, v in pairs(player:GetAttributes()) do
        if type(v) == "number" and nameMatches(k, MONEY_NAMES) then return v end
    end
    return nil
end

local function getItemCount(id)
    local v = player:GetAttribute(id)
    if type(v) == "number" then return v end
    for _, d in ipairs(player:GetDescendants()) do
        if d.Name == id and numVal(d) and not d:IsDescendantOf(playerGui) then return d.Value end
    end
    return nil
end

local function looksFailed(res)
    if res == false then return true end
    if type(res) == "table" and (res.success == false or res.Success == false or res.ok == false or res.Ok == false) then
        return true
    end
    if type(res) == "string" then
        local s = string.lower(res)
        for _, w in ipairs({"full", "max", "limit", "enough", "fail", "error", "ممتل", "فلوس", "ما تقدر", "لا يمكن"}) do
            if s:find(w, 1, true) then return true end
        end
    end
    return false
end

local function useFood(id)
    if not Request then return false end
    local ok, res = pcall(function() return Request:InvokeServer("UseFood", {["id"] = id}) end)
    return ok and not looksFailed(res)
end

local printedReply = {}
local function buyFood(id)
    if not Request then return false end
    local moneyBefore, countBefore = getMoney(), getItemCount(id)
    local ok, res = pcall(function() return Request:InvokeServer("BuyFood", {["id"] = id}) end)
    if not printedReply[id] then
        printedReply[id] = true
        print("[SimpleHub] رد السيرفر على شراء " .. id .. ":", ok, res)
    end
    if not ok or looksFailed(res) then return false end
    if moneyBefore or countBefore then
        task.wait(0.3)
        local moneyAfter, countAfter = getMoney(), getItemCount(id)
        local paid = moneyBefore and moneyAfter and moneyAfter < moneyBefore
        local gained = countBefore and countAfter and countAfter > countBefore
        if not (paid or gained) then return false end
    end
    return true
end

---------------------------------------------------------------------
-- النافذة
---------------------------------------------------------------------
local WIN_W, WIN_H, SIDE_W = 480, 310, 140

local win = box(gui, {Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = C.bg, Visible = false, ZIndex = 5, Active = true})
corner(win, 12)
stroke(win)
local winScale = new("UIScale", {Parent = win})

-- الشريط الجانبي
local side = box(win, {Size = UDim2.new(0, SIDE_W, 1, 0), BackgroundColor3 = C.surface})
corner(side, 12)
box(side, {Size = UDim2.new(0, 12, 1, 0), Position = UDim2.new(1, -12, 0, 0), BackgroundColor3 = C.surface})
box(win, {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(SIDE_W, 0), BackgroundColor3 = C.border})

local brandZone = box(side, {Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Active = true})
text(brandZone, "SimpleHub", 17, C.text, BOLD, {Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(120, 20)})
text(brandZone, "v1.0  ·  Dhab", 11, C.faint, MED, {Position = UDim2.fromOffset(16, 34), Size = UDim2.fromOffset(120, 14)})

local sideFoot = box(side, {Size = UDim2.new(1, -32, 0, 24), Position = UDim2.new(0, 16, 1, -36), BackgroundTransparency = 1})
local footImg = new("ImageLabel", {Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(0, 2),
    BackgroundColor3 = C.raised, Image = avatarImage, Parent = sideFoot})
corner(footImg, 10)
table.insert(avatarTargets, footImg)
text(sideFoot, player.DisplayName, 12, C.muted, MED, {Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd})

-- المحتوى
local content = box(win, {Position = UDim2.fromOffset(SIDE_W + 1, 0), Size = UDim2.new(1, -SIDE_W - 1, 1, 0), BackgroundTransparency = 1})
local headZone = box(content, {Size = UDim2.new(1, -52, 0, 58), BackgroundTransparency = 1, Active = true})
local pageTitle = text(headZone, "", 16, C.text, SEMI, {Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -20, 0, 20)})
local pageSub = text(headZone, "", 12, C.muted, REG, {Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -20, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd})

local closeBtn = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 14), Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = C.raised, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = content})
corner(closeBtn, 7)
iconCross(closeBtn, C.muted, 12)
closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.12, {BackgroundTransparency = 0}) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.12, {BackgroundTransparency = 1}) end)

-- السحب
local function makeDraggable(zone)
    local dragging, startInput, startPos = false, nil, nil
    zone.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, startInput, startPos = true, i.Position, win.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    bind(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
makeDraggable(brandZone)
makeDraggable(headZone)

-- التنقل
local NAV = {
    {title = "Shop",     sub = "Keep your food and water up"},
    {title = "Teleport", sub = "Jump to any car and get in"},
    {title = "ESP",      sub = "Every dhab in the desert, live"},
    {title = "Aim",      sub = "Lock on and shoot the dhab you zoom on"},
    {title = "Car",      sub = "Flight and rollback protection"},
    {title = "Controls", sub = "Keybinds and on-screen buttons"},
}
local navItems, pages = {}, {}

for i, n in ipairs(NAV) do
    local b = new("TextButton", {Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 62 + (i - 1) * 34),
        BackgroundColor3 = C.raised, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = side})
    corner(b, 7)
    local bar = box(b, {Size = UDim2.fromOffset(2, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = C.accent, Visible = false})
    corner(bar, 1)
    local l = text(b, n.title, 13, C.muted, MED, {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0)})
    navItems[i] = {btn = b, bar = bar, label = l}

    local p = new("ScrollingFrame", {Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.border,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content})
    pad(p, 20, 20, 0, 18)
    new("UIListLayout", {Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p})
    pages[i] = p
end

local currentPage = 1
local function selectPage(idx)
    currentPage = idx
    for j, item in ipairs(navItems) do
        local on = j == idx
        pages[j].Visible = on
        item.bar.Visible = on
        tween(item.btn, 0.15, {BackgroundTransparency = on and 0 or 1})
        item.label.TextColor3 = on and C.text or C.muted
    end
    pageTitle.Text = NAV[idx].title
    pageSub.Text = NAV[idx].sub
end
for i, item in ipairs(navItems) do
    item.btn.Activated:Connect(function() selectPage(i) end)
    item.btn.MouseEnter:Connect(function() if currentPage ~= i then item.label.TextColor3 = C.text end end)
    item.btn.MouseLeave:Connect(function() if currentPage ~= i then item.label.TextColor3 = C.muted end end)
end

---------------------------------------------------------------------
-- مكونات الصفحات
---------------------------------------------------------------------
local function group(page, order, title)
    local wrap = box(page, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order})
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap})
    if title then
        text(wrap, string.upper(title), 10, C.faint, SEMI, {Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0})
    end
    local list = box(wrap, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.surface, LayoutOrder = 1})
    corner(list, 8)
    stroke(list)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})
    return {list = list, count = 0}
end

local function divider(parent)
    box(parent, {Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 0), BackgroundColor3 = C.border})
end

local function row(g, title, desc)
    g.count += 1
    local r = box(g.list, {Size = UDim2.new(1, 0, 0, desc and 50 or 42), BackgroundTransparency = 1, LayoutOrder = g.count})
    if g.count > 1 then divider(r) end

    local right = box(r, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1})
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right})

    local tl = text(r, title, 13, C.text, MED, {
        Position = UDim2.fromOffset(12, desc and 9 or 0),
        Size = UDim2.new(1, -170, 0, desc and 16 or 42), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local dl
    if desc then
        dl = text(r, desc, 11, C.muted, REG, {Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -170, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd})
    end
    return r, right, tl, dl
end

local function toggle(parent, onChange, order)
    local t = new("TextButton", {Size = UDim2.fromOffset(34, 20), BackgroundColor3 = C.raised, AutoButtonColor = false,
        Text = "", LayoutOrder = order or 10, Parent = parent})
    corner(t, 10)
    local s = stroke(t)
    local knob = box(t, {Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = C.muted})
    corner(knob, 7)
    local state = false
    local function set(v, silent)
        state = v and true or false
        tween(knob, 0.18, {Position = UDim2.fromOffset(state and 17 or 3, 3), BackgroundColor3 = state and C.white or C.muted})
        tween(t, 0.18, {BackgroundColor3 = state and C.accent or C.raised})
        tween(s, 0.18, {Color = state and C.accent or C.border})
        if onChange and not silent then onChange(state) end
    end
    t.Activated:Connect(function() set(not state) end)
    return set, function() return state end
end

local function button(parent, label, width, primary, order)
    local base = primary and C.accent or C.raised
    local b = new("TextButton", {Size = UDim2.fromOffset(width or 60, 26), BackgroundColor3 = base, AutoButtonColor = false,
        Text = label, TextSize = 12, TextColor3 = primary and C.white or C.text, FontFace = face(SEMI),
        LayoutOrder = order or 1, Parent = parent})
    corner(b, 6)
    b:SetAttribute("Primary", primary and true or false)
    if not primary then stroke(b) end
    b.MouseEnter:Connect(function() tween(b, 0.12, {BackgroundColor3 = primary and C.accentHi or C.hover}) end)
    b.MouseLeave:Connect(function() tween(b, 0.12, {BackgroundColor3 = base}) end)
    pressScale(b)
    return b
end

local function feedback(b, label, ok, msgOk, msgFail)
    local primary = b:GetAttribute("Primary")
    b.Text = ok and (msgOk or "Done") or (msgFail or "Failed")
    if not primary then b.TextColor3 = ok and C.green or C.red end
    task.delay(0.9, function()
        if b.Parent then
            b.Text = label
            if not primary then b.TextColor3 = C.text end
        end
    end)
end

local function smallLabel(parent, str, order)
    return text(parent, str, 11, C.muted, MED, {Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order})
end

local function meter(parent)
    local track = box(parent, {Size = UDim2.fromOffset(84, 4), BackgroundColor3 = C.raised, LayoutOrder = 1})
    corner(track, 2)
    local fill = box(track, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green})
    corner(fill, 2)
    local pct = text(parent, "--", 12, C.muted, SEMI, {Size = UDim2.fromOffset(36, 16), TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = 2})
    return function(p)
        if not p then
            pct.Text = "n/a"
            fill.Size = UDim2.fromScale(0, 1)
            return
        end
        pct.Text = math.floor(p) .. "%"
        pct.TextColor3 = p < LOW_PERCENT and C.red or C.muted
        local col = p < LOW_PERCENT and C.red or (p < 35 and C.amber or C.green)
        tween(fill, 0.4, {Size = UDim2.fromScale(p / 100, 1), BackgroundColor3 = col})
    end
end

local function outputRow(g, placeholder)
    g.count += 1
    local r = box(g.list, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = g.count})
    if g.count > 1 then divider(r) end
    local out = text(r, placeholder, 11, C.muted, REG, {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, FontFace = face(REG, MONO),
    })
    pad(out, 12, 12, 10, 10)
    return out
end

local shopPage, tpPage, espPage, aimPage, carPage, controlsPage = pages[1], pages[2], pages[3], pages[4], pages[5], pages[6]

---------------------------------------------------------------------
-- الاختصارات + أزرار الشاشة (تنحفظ لو المنفذ يدعم writefile)
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local SAVE_FILE = "SimpleHub_settings.json"
local saved = {keys = {}, float = {}, calib = {}, state = {}}
pcall(function()
    if isfile and readfile and isfile(SAVE_FILE) then
        local d = HttpService:JSONDecode(readfile(SAVE_FILE))
        if type(d) == "table" then
            if type(d.keys) == "table" then saved.keys = d.keys end
            if type(d.float) == "table" then saved.float = d.float end
            if type(d.calib) == "table" then saved.calib = d.calib end
            if type(d.gates) == "table" then saved.gates = d.gates end
            if type(d.tp) == "table" then saved.tp = d.tp end
            if type(d.state) == "table" then saved.state = d.state end
            if type(d.waypoints) == "table" then saved.waypoints = d.waypoints end
            if type(d.wpTrash) == "table" then saved.wpTrash = d.wpTrash end
            if type(d.rar) == "table" then saved.rar = d.rar end
        end
    end
end)
local function saveSettings()
    pcall(function()
        if writefile then writefile(SAVE_FILE, HttpService:JSONEncode(saved)) end
    end)
end

-- كل الإعدادات تنحفظ وترجع لما تطلع وتدخل
local function getState(k, default)
    local v = saved.state[k]
    if v == nil then return default end
    return v
end
local function setState(k, v)
    saved.state[k] = v
    saveSettings()
end

local function encodeBind(b)
    if not b then return "none" end
    if b.EnumType == Enum.KeyCode then return "K:" .. b.Name end
    return "M:" .. b.Name
end
local function decodeBind(s)
    if type(s) ~= "string" or s == "none" then return nil end
    local kind, name = s:match("^(%a):(.+)$")
    local ok, v = pcall(function()
        if kind == "K" then return Enum.KeyCode[name] end
        return Enum.UserInputType[name]
    end)
    return ok and v or nil
end
local SHORT_KEYS = {
    LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
    LeftAlt = "LAlt", RightAlt = "RAlt", Minus = "-", KeypadMinus = "-", Equals = "=", Backquote = "`",
    MouseButton2 = "MB2", MouseButton3 = "MB3",
}
local function bindName(b)
    if not b then return "None" end
    return SHORT_KEYS[b.Name] or b.Name
end

local actions, actionOrder = {}, {}
local editMode = false

local function defineAction(id, opts)
    local a = {
        id = id, title = opts.title, short = opts.short, run = opts.run, get = opts.get,
        toggles = {}, keyBtns = {}, floatable = opts.floatable ~= false, persist = opts.persist == true,
    }
    if saved.keys[id] ~= nil then a.key = decodeBind(saved.keys[id]) else a.key = opts.key end
    local f = saved.float[id]
    if type(f) == "table" and f.show ~= nil then a.showFloat = f.show == true else a.showFloat = opts.float == true end
    actions[id] = a
    table.insert(actionOrder, id)
    return a
end

refreshAction = function(id)
    local a = actions[id]
    if not a then return end
    local st = a.get and a.get() or false
    for _, set in ipairs(a.toggles) do set(st, true) end
    if a.floatBtn then
        a.floatStroke.Color = editMode and C.amber or (st and C.accent or C.border)
        a.floatLabel.TextColor3 = st and C.accent or C.text
    end
end

local function runAction(id)
    local a = actions[id]
    if a and a.run then a.run() end
    if a and a.persist then setState("act." .. id, a.get() and true or false) end
    refreshAction(id)
end

local listening = nil
local function setBind(id, key)
    local a = actions[id]
    a.key = key
    saved.keys[id] = encodeBind(key)
    saveSettings()
    for _, kb in ipairs(a.keyBtns) do kb.Text = bindName(key) end
end

-- زر الاختصار: اضغطه بعدين اضغط أي زر بالكيبورد (Backspace يمسحه)
local function keyButton(parent, id, order)
    local a = actions[id]
    local b = button(parent, bindName(a.key), 52, false, order or 0)
    b.TextSize = 11
    table.insert(a.keyBtns, b)
    b.Activated:Connect(function()
        if listening then listening.btn.Text = bindName(actions[listening.id].key) end
        listening = {id = id, btn = b}
        b.Text = "..."
    end)
    return b
end

bind(UserInputService.InputBegan, function(input, gp)
    if listening then
        local t = input.UserInputType
        local key
        if t == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
                key = false
            else
                key = input.KeyCode
            end
        elseif t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 then
            key = t
        else
            return
        end
        local l = listening
        listening = nil
        if key then
            for oid, oa in pairs(actions) do
                if oid ~= l.id and oa.key == key then setBind(oid, nil) end
            end
        end
        setBind(l.id, key or nil)
        return
    end
    if gp then return end
    for _, id in ipairs(actionOrder) do
        local k = actions[id].key
        if k and (input.KeyCode == k or input.UserInputType == k) then runAction(id) end
    end
end)

-- أزرار على الشاشة (للجوال) تقدر تسحبها لأي مكان
local function floatDefaultPos(i)
    local vp = Camera.ViewportSize
    local col, r = math.floor((i - 1) / 4), (i - 1) % 4
    return Vector2.new(vp.X - 110 - col * 66, vp.Y * 0.3 + r * 66)
end
local function floatSlot(id)
    local n = 0
    for _, oid in ipairs(actionOrder) do
        if actions[oid].floatable then
            n += 1
            if oid == id then return n end
        end
    end
    return 1
end

local function createFloat(a, index)
    if a.floatBtn then return end
    local f = saved.float[a.id]
    local pos = (type(f) == "table" and f.x and f.y) and Vector2.new(f.x, f.y) or floatDefaultPos(index)
    local b = new("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y),
        Size = UDim2.fromOffset(58, 58), BackgroundColor3 = C.bg, BackgroundTransparency = 0.04,
        AutoButtonColor = false, Text = "", ZIndex = 3, Parent = gui})
    corner(b, 14)
    a.floatStroke = stroke(b, C.border, 1.5)
    a.floatLabel = text(b, a.short, 12, C.text, BOLD, {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
    a.floatBtn = b

    local sc = new("UIScale", {Parent = b})
    local dragging, startIn, startPos = false, nil, nil
    b.InputBegan:Connect(function(i)
        if not isPress(i) then return end
        tween(sc, 0.08, {Scale = 0.93})
        if editMode then
            dragging, startIn, startPos = true, i.Position, Vector2.new(b.Position.X.Offset, b.Position.Y.Offset)
        end
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then
                tween(sc, 0.2, {Scale = 1}, Enum.EasingStyle.Back)
                if dragging then
                    dragging = false
                    local cur = type(saved.float[a.id]) == "table" and saved.float[a.id] or {}
                    cur.show = true
                    cur.x, cur.y = b.Position.X.Offset, b.Position.Y.Offset
                    saved.float[a.id] = cur
                    saveSettings()
                end
            end
        end)
    end)
    a.floatConn = bind(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startIn
            b.Position = UDim2.fromOffset(startPos.X + d.X, startPos.Y + d.Y)
        end
    end)
    b.Activated:Connect(function()
        if not editMode then runAction(a.id) end
    end)
    refreshAction(a.id)
end

local function destroyFloat(a)
    if a.floatConn then a.floatConn:Disconnect() a.floatConn = nil end
    if a.floatBtn then a.floatBtn:Destroy() a.floatBtn = nil end
end

local function setFloat(id, show)
    local a = actions[id]
    a.showFloat = show
    local cur = type(saved.float[id]) == "table" and saved.float[id] or {}
    cur.show = show
    saved.float[id] = cur
    saveSettings()
    if show then createFloat(a, floatSlot(id)) else destroyFloat(a) end
end

-- سطر فيه: اسم الخيار + زر الاختصار + السويتش
local function actionRow(g, id, desc)
    local a = actions[id]
    local _, right, _, dl = row(g, a.title, desc)
    keyButton(right, id, 1)
    local set = toggle(right, function(v)
        if v ~= (a.get() and true or false) then runAction(id) else refreshAction(id) end
    end, 2)
    table.insert(a.toggles, set)
    set(a.get() and true or false, true)
    return right, dl
end

local function stepper(right, fmt, get, set, step, minV, maxV)
    local minus = button(right, "-", 28, false, 1)
    local lbl = text(right, fmt(get()), 13, C.text, SEMI, {Size = UDim2.fromOffset(48, 26), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2})
    local plus = button(right, "+", 28, false, 3)
    local function change(d)
        local v = math.clamp(math.floor((get() + d) / step + 0.5) * step, minV, maxV)
        set(v)
        lbl.Text = fmt(v)
    end
    minus.Activated:Connect(function() change(-step) end)
    plus.Activated:Connect(function() change(step) end)
    return function() lbl.Text = fmt(get()) end
end


---------------------------------------------------------------------
-- صفحة Shop
---------------------------------------------------------------------
local autoBuy = {}
local setAutoBuyUI = {}

local function runAutoBuy(id)
    task.spawn(function()
        local fails = 0
        while alive and autoBuy[id] do
            if buyFood(id) then
                fails = 0
            else
                fails += 1
                if fails >= 3 then
                    autoBuy[id] = false
                    setAutoBuyUI[id](false, true)
                    print("[SimpleHub] " .. id .. ": وقف الاوتو شراء (فلّ أو خلصت الفلوس)")
                    break
                end
            end
            task.wait(0.4)
        end
    end)
end

do
local gStatus = group(shopPage, 2, "Status")
local _, foodRight = row(gStatus, "Food", "الشبع")
local setFood = meter(foodRight)
local _, waterRight = row(gStatus, "Water", "العطش")
local setWater = meter(waterRight)

local gAuto = group(shopPage, 3, "Auto use")
local _, eatRight = row(gAuto, "Auto eat", "Eats Kabsa when food drops under 10%")
local setAutoEat, getAutoEat = toggle(eatRight, function(v) setState("autoEat", v) end)
setAutoEat(getState("autoEat", false), true)
local _, drinkRight = row(gAuto, "Auto drink", "Drinks a Water Jug when thirst drops under 10%")
local setAutoDrink, getAutoDrink = toggle(drinkRight, function(v) setState("autoDrink", v) end)
setAutoDrink(getState("autoDrink", false), true)

local gDebug = group(shopPage, 4, "Debug")
local _, dbgRight = row(gDebug, "Print stats", "Lists every number value in the F9 console")
local printBtn = button(dbgRight, "Print", 56)
printBtn.Activated:Connect(function()
    print("========== [SimpleHub] stats ==========")
    for _, holder in ipairs({player, player.Character}) do
        if holder then
            for k, v in pairs(holder:GetAttributes()) do
                if type(v) == "number" then print("Attribute", holder.Name .. "." .. k, "=", v) end
            end
            for _, d in ipairs(holder:GetDescendants()) do
                if numVal(d) and not d:IsDescendantOf(playerGui) then print("Value", d:GetFullName(), "=", d.Value) end
            end
        end
    end
    print("=======================================")
    feedback(printBtn, "Print", true, "Sent")
end)

task.spawn(function()
    local nextEat, nextDrink = 0, 0
    while alive do
        local food = getPercent(HUNGER_KEYS)
        local water = getPercent(THIRST_KEYS)
        setFood(food)
        setWater(water)
        local now = os.clock()
        if getAutoEat() and food and food < LOW_PERCENT and now >= nextEat then
            useFood("Kabsa")
            nextEat = now + 3
        end
        if getAutoDrink() and water and water < LOW_PERCENT and now >= nextDrink then
            useFood("WaterJug")
            nextDrink = now + 3
        end
        task.wait(1)
    end
end)

end
---------------------------------------------------------------------
-- صفحة Teleport
---------------------------------------------------------------------
do
-- صفحة Teleport: كل السيارات اللي بالماب، تضغط Go ينقلك عندها ويركبك فيها
local carsStatus = "Pick a car"

-- صاحب السيارة (يدور في الـ Attributes والـ Values ومجلد Cars عند كل لاعب)
local function findOwner(car)
    for _, k in ipairs({"Owner", "OwnerName", "Player", "PlayerName", "owner", "OwnerId", "UserId"}) do
        local v = car:GetAttribute(k)
        if type(v) == "string" and v ~= "" then return v end
        if type(v) == "number" then
            local p = Players:GetPlayerByUserId(v)
            if p then return p.Name end
        end
    end
    for _, k in ipairs({"Owner", "Player", "OwnerName", "OwnerId"}) do
        local o = car:FindFirstChild(k)
        if o then
            if o:IsA("ObjectValue") and o.Value then return o.Value.Name end
            if o:IsA("StringValue") and o.Value ~= "" then return o.Value end
            if o:IsA("IntValue") or o:IsA("NumberValue") then
                local p = Players:GetPlayerByUserId(o.Value)
                if p then return p.Name end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if car.Name:find(p.Name, 1, true) or car.Name:find(tostring(p.UserId), 1, true) then return p.Name end
        local cars = p:FindFirstChild("Cars")
        if cars then
            for _, c in ipairs(cars:GetDescendants()) do
                if c:IsA("ObjectValue") and c.Value == car then return p.Name end
            end
        end
    end
    local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
    if seat and seat.Occupant then
        local p = Players:GetPlayerFromCharacter(seat.Occupant.Parent)
        if p then return p.Name end
    end
    return nil
end

local function carName(car)
    for _, k in ipairs({"CarName", "DisplayName", "VehicleName", "Model", "Vehicle", "Type", "Name"}) do
        local v = car:GetAttribute(k)
        if type(v) == "string" and v ~= "" then return v end
    end
    for _, k in ipairs({"CarName", "DisplayName", "VehicleName", "Model"}) do
        local o = car:FindFirstChild(k)
        if o and o:IsA("StringValue") and o.Value ~= "" then return o.Value end
    end
    return car.Name
end

local function findSeat(car)
    local backup
    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("VehicleSeat") and not d.Occupant then return d end
        if d:IsA("Seat") and not d.Occupant and not backup then backup = d end
    end
    return backup
end

local ENTER_WORDS = {"enter", "drive", "ride", "sit", "get in", "seat", "اركب", "ركوب", "قيادة", "سوق", "دخول", "اجلس"}
local function isEnterPrompt(pp, seat)
    if seat and (pp.Parent == seat or pp:IsDescendantOf(seat)) then return true end
    local t = string.lower(pp.ActionText .. " " .. pp.ObjectText)
    for _, w in ipairs(ENTER_WORDS) do
        if t:find(w, 1, true) then return true end
    end
    return false
end

local function pressPrompt(pp)
    if fireproximityprompt then
        pcall(fireproximityprompt, pp)
    else
        task.spawn(function()
            pcall(function()
                pp:InputHoldBegin()
                task.wait(pp.HoldDuration + 0.05)
                pp:InputHoldEnd()
            end)
        end)
    end
end

local busy = false
-- ينقلك عند السيارة ويحاول يركبك فيها على طول
local function getInCar(car)
    if busy then return end
    busy = true
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then
        carsStatus = "No character"
        busy = false
        return
    end

    -- لو راكب سيارة ثانية ننزل منها أول
    if hum.SeatPart then
        hum.Sit = false
        hum.Jump = true
        task.wait(0.3)
    end

    local t0 = os.clock()
    while alive and car.Parent and os.clock() - t0 < 5 do
        local seat = findSeat(car)
        if not seat then
            carsStatus = "No free seat"
            busy = false
            return
        end
        carsStatus = "Getting in..."
        hrp.AssemblyLinearVelocity = Vector3.zero
        char:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))

        for _, pp in ipairs(car:GetDescendants()) do
            if pp:IsA("ProximityPrompt") and pp.Enabled and isEnterPrompt(pp, seat) then pressPrompt(pp) end
        end

        task.wait(0.25)
        if hum.SeatPart and hum.SeatPart:IsDescendantOf(car) then
            carsStatus = "In " .. carName(car)
            busy = false
            return
        end
    end
    carsStatus = "Couldn't get in"
    busy = false
end

local gStatusCars = group(tpPage, 1, nil)
local _, _, _, carsDesc = row(gStatusCars, "Status", carsStatus)

local listWrapCars = box(tpPage, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, LayoutOrder = 2})
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = listWrapCars})

local carGroup = nil
local carRows = {}   -- [car] = desc label
local lastKey = ""

local function rebuildCars()
    local list = {}
    for _, car in ipairs(carsFolder:GetChildren()) do
        if car:IsA("Model") then table.insert(list, car) end
    end
    local key = ""
    for _, car in ipairs(list) do key = key .. tostring(car) .. ";" end
    if key == lastKey and carGroup then return end
    lastKey = key

    if carGroup then carGroup.list.Parent:Destroy() end
    table.clear(carRows)
    carGroup = group(listWrapCars, 1, "Cars  (" .. #list .. ")")
    if #list == 0 then
        row(carGroup, "No cars in the map")
        return
    end
    for _, car in ipairs(list) do
        local owner = findOwner(car)
        local _, right, tl, dl = row(carGroup, carName(car), owner or "?")
        if owner == player.Name then tl.Text = carName(car) .. "  (yours)" end
        carRows[car] = {desc = dl, owner = owner}
        local go = button(right, "Go", 48, true, 1)
        go.Activated:Connect(function()
            task.spawn(getInCar, car)
        end)
    end
end

task.spawn(function()
    local t = 0
    while alive do
        if win.Visible and currentPage == 2 then
            if t <= 0 then
                rebuildCars()
                t = 2
            end
            local m = getMover()
            local myPos = m and m:GetPivot().Position
            for car, info in pairs(carRows) do
                if car.Parent then
                    local d = myPos and math.floor((car:GetPivot().Position - myPos).Magnitude) or 0
                    info.desc.Text = (info.owner or "?") .. "  ·  " .. d .. "m"
                end
            end
            carsDesc.Text = carsStatus
        end
        t -= 0.5
        task.wait(0.5)
    end
end)
end
---------------------------------------------------------------------
-- ESP + Aim + حساب الكيلو (داخل دالة عشان حد المتغيرات حق لوا)
---------------------------------------------------------------------
local espExports = {};
(function()
---------------------------------------------------------------------
-- ESP (الضبان في workspace.DhabWild)
---------------------------------------------------------------------
local esp = {on = false, lines = true, boxes = true, labels = true}
local tracked = {}
local dhabFolder = nil

local espFolder = new("Folder", {Name = "SimpleHubESP", Parent = playerGui})

local RAR_KEYS = {"rarity", "rare", "tier", "quality", "grade", "ندر"}
local KG_KEYS = {"weight", "kg", "mass", "wt", "وزن"}

-- ألوان الندرة: T1 رمادي، T2 أخضر، T3 أزرق، T4 بنفسجي، T5 ذهبي، T6 أحمر، T7 وردي
local TIER_COLORS = {
    rgb(175, 175, 185), rgb(80, 210, 120), rgb(60, 150, 255), rgb(170, 100, 255),
    rgb(255, 190, 60), rgb(255, 80, 80), rgb(255, 110, 200),
}
local NAME_COLORS = {
    {"uncommon", rgb(80, 210, 120)}, {"common", rgb(175, 175, 185)}, {"rare", rgb(60, 150, 255)},
    {"epic", rgb(170, 100, 255)}, {"legendary", rgb(255, 190, 60)}, {"mythic", rgb(255, 80, 80)},
    {"secret", rgb(80, 230, 230)},
    {"غير شائع", rgb(80, 210, 120)}, {"عادي", rgb(175, 175, 185)}, {"نادر", rgb(60, 150, 255)},
    {"ملحمي", rgb(170, 100, 255)}, {"أسطوري", rgb(255, 190, 60)}, {"خرافي", rgb(255, 80, 80)},
}
local function nameColor(name)
    local s = string.lower(tostring(name or ""))
    for _, pair in ipairs(NAME_COLORS) do
        if s:find(pair[1], 1, true) then return pair[2] end
    end
    return nil
end

local NAMED_TIERS = {
    {"uncommon", 2}, {"common", 1}, {"rare", 3}, {"epic", 4}, {"legendary", 5},
    {"mythic", 6}, {"secret", 7}, {"غير شائع", 2}, {"عادي", 1}, {"نادر", 3},
    {"ملحمي", 4}, {"أسطوري", 5}, {"خرافي", 6}, {"سري", 7},
}

local function rarityColor(rar)
    local s = string.lower(tostring(rar or ""))
    local n = tonumber(s:match("%d+"))
    if n then return TIER_COLORS[math.clamp(n, 1, #TIER_COLORS)] end
    for _, pair in ipairs(NAMED_TIERS) do
        if s:find(pair[1], 1, true) then return TIER_COLORS[pair[2]] end
    end
    return ESP_COLOR
end

---------------------------------------------------------------------
-- البحث في بيانات اللعبة (ModuleScripts في ReplicatedStorage)
---------------------------------------------------------------------
local gameData = nil
local gameDataLoading = false

local function safeRequire(mod)
    local done, ok, res = false, false, nil
    task.spawn(function()
        ok, res = pcall(require, mod)
        done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < 1 do task.wait() end
    if done and ok then return res end
    return nil
end

local DATA_HINTS = {"dhab", "tier", "rarit", "weight", "animal", "creature", "wild", "spawn", "config", "data", "shared", "info"}

local function loadGameData()
    if gameData or gameDataLoading then return end
    gameDataLoading = true
    local list = {}
    for i, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("ModuleScript") then
            local n = string.lower(d:GetFullName())
            for _, k in ipairs(DATA_HINTS) do
                if n:find(k, 1, true) then
                    local res = safeRequire(d)
                    if type(res) == "table" then table.insert(list, {path = d:GetFullName(), t = res}) end
                    break
                end
            end
        end
        if i % 500 == 0 then task.wait() end
    end
    gameData = list
    gameDataLoading = false
end

local function harvest(v, tier, out)
    for k, x in pairs(v) do
        local lk = string.lower(tostring(k))
        local isWeight = lk:find("weight", 1, true) or lk:find("kg", 1, true) or lk:find("mass", 1, true)
        if type(x) == "string" and not out.name and string.lower(x) ~= string.lower(tier)
            and (lk:find("name", 1, true) or lk:find("rarit", 1, true) or lk:find("display", 1, true) or lk:find("label", 1, true)) then
            out.name = x
        elseif type(x) == "number" and isWeight then
            if lk:find("min", 1, true) then out.minKg = x
            elseif lk:find("max", 1, true) then out.maxKg = x
            else out.kg = x end
        elseif type(x) == "table" and isWeight then
            local a, b = x[1] or x.Min or x.min, x[2] or x.Max or x.max
            if type(a) == "number" and type(b) == "number" then out.minKg, out.maxKg = a, b end
        elseif typeof(x) == "NumberRange" and isWeight then
            out.minKg, out.maxKg = x.Min, x.Max
        elseif typeof(x) == "Color3" and lk:find("colo", 1, true) then
            out.color = x
        end
    end
end

local function scanTable(t, tier, depth, seen, out, path)
    if depth > 6 or seen[t] then return end
    seen[t] = true
    local lt = string.lower(tier)
    for k, v in pairs(t) do
        if type(k) == "string" and string.lower(k) == lt then
            out.source = out.source or path
            if type(v) == "string" then
                out.name = out.name or v
            elseif type(v) == "table" then
                harvest(v, tier, out)
            end
        elseif type(v) == "table" then
            local tv = rawget(v, "Tier") or rawget(v, "tier") or rawget(v, "Rarity") or rawget(v, "rarity")
            if type(tv) == "string" and string.lower(tv) == lt then
                out.source = out.source or path
                harvest(v, tier, out)
            end
            scanTable(v, tier, depth + 1, seen, out, path)
        end
    end
end

local tierCache = {}
local function getTierInfo(tier)
    if not tier then return nil end
    tier = tostring(tier)
    if tierCache[tier] then return tierCache[tier] end
    if not gameData then return nil end
    local out = {}
    for _, entry in ipairs(gameData) do
        pcall(scanTable, entry.t, tier, 0, {}, out, entry.path)
    end
    tierCache[tier] = out
    return out
end

---------------------------------------------------------------------
-- البحث عن بيانات كل ضب (عليه نفسه أو بأي مكان فيه نفس الرقم)
---------------------------------------------------------------------
local function collect(m)
    local found = {}
    local function put(k, v)
        local lk = string.lower(k)
        if found[lk] == nil then found[lk] = v end
    end
    for k, v in pairs(m:GetAttributes()) do put(k, v) end
    local texts = {}
    for _, d in ipairs(m:GetDescendants()) do
        for k, v in pairs(d:GetAttributes()) do put(k, v) end
        if d:IsA("ValueBase") and not d:IsA("ObjectValue") then put(d.Name, d.Value) end
        if d:IsA("TextLabel") and d.Text ~= "" then table.insert(texts, d.Text) end
    end
    return found, texts
end

local function pick(found, keys, allowNumber)
    for _, k in ipairs(keys) do
        for name, v in pairs(found) do
            if not name:find("max", 1, true) and not name:find("min", 1, true) and name:find(k, 1, true) then
                if type(v) == "string" and v ~= "" then return v end
                if allowNumber and type(v) == "number" then return v end
            end
        end
    end
    return nil
end

-- لو الوزن مو على الضب نفسه: ندور في ReplicatedStorage واللاعب على شي اسمه فيه رقم الضب
local idCache = {}
local function searchById(m)
    local id = m.Name:match("_(%x+)$")
    if not id then return nil end
    if idCache[id] ~= nil then return idCache[id] or nil end
    idCache[id] = false
    task.spawn(function()
        local found = {}
        for _, root in ipairs({ReplicatedStorage, player}) do
            for i, d in ipairs(root:GetDescendants()) do
                if d.Name:find(id, 1, true) then
                    for k, v in pairs(d:GetAttributes()) do found[string.lower(k)] = v end
                    if d:IsA("ValueBase") then found[string.lower(d.Name)] = d.Value end
                    for _, c in ipairs(d:GetChildren()) do
                        if c:IsA("ValueBase") and not c:IsA("ObjectValue") then found[string.lower(c.Name)] = c.Value end
                        for k, v in pairs(c:GetAttributes()) do found[string.lower(k)] = v end
                    end
                end
                if i % 2000 == 0 then task.wait() end
            end
        end
        idCache[id] = next(found) and found or false
    end)
    return nil
end

local function fmtKg(x)
    return string.format("%.1f kg", x)
end

local function readDhabInfo(m)
    local found, texts = collect(m)
    local extra = searchById(m)
    if extra then
        for k, v in pairs(extra) do
            if found[k] == nil then found[k] = v end
        end
    end

    local rar = pick(found, RAR_KEYS, true)
    local kg = pick(found, KG_KEYS, true)
    for _, t in ipairs(texts) do
        if not kg and string.lower(t):find("kg", 1, true) then kg = t end
    end

    local info = rar and getTierInfo(rar)
    local rarName = info and info.name
    if not rarName and rar and nameColor(rar) then rarName = tostring(rar) end
    local rarText = rarName and string.upper(rarName) or (rar and tostring(rar) or "?")

    local kgText
    if type(kg) == "number" then
        kgText = fmtKg(kg)
    elseif kg then
        kgText = tostring(kg)
        if not string.lower(kgText):find("kg", 1, true) then kgText = kgText .. " kg" end
    end

    local color = nameColor(rarName) or (info and info.color) or rarityColor(rar)
    return rarText, kgText, color
end

local function modelRoot(m)
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
end

-- طول الضب: أطول بُعد أفقي لجسمه (بدون الـ Hitbox)
local lenCache = setmetatable({}, {__mode = "k"})
local function dhabLength(m)
    if lenCache[m] then return lenCache[m] end
    local root = modelRoot(m)
    if not root then return nil end
    local base = root.CFrame
    local hit = m:FindFirstChild("Hitbox")
    local minV, maxV
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") and not (hit and (p == hit or p:IsDescendantOf(hit))) then
            local cf = base:ToObjectSpace(p.CFrame)
            local h = p.Size / 2
            for _, sx in ipairs({-1, 1}) do
                for _, sy in ipairs({-1, 1}) do
                    for _, sz in ipairs({-1, 1}) do
                        local c = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
                        minV = minV and minV:Min(c) or c
                        maxV = maxV and maxV:Max(c) or c
                    end
                end
            end
        end
    end
    local size
    if minV then
        size = maxV - minV
    else
        local ok, _, s2 = pcall(function() return m:GetBoundingBox() end)
        size = ok and s2 or root.Size
    end
    local len = math.max(size.X, size.Z)
    if len <= 0 then return nil end
    lenCache[m] = len
    return len
end

-- المعادلة: kg = a × L^b (تتعلمها من الضبان اللي تذبحها)
-- قياسات حقيقية: L 8.26 = 87.5 كجم (ضب الخشم) و L 3.63 = 7.4 كجم (ضب جوفي)
-- تطلع تقريباً kg = 0.1553 × L³
local calib = saved.calib
local fit = nil
local function refit()
    local n = #calib
    if n == 0 then
        fit = {a = 0.1553, b = 3, builtin = true} -- من قياساتك: L 8.26 = 87.5 و L 3.63 = 7.4
        return
    end
    if n == 1 then
        local s1 = calib[1]
        fit = {a = s1.kg / s1.l ^ 3, b = 3}
        return
    end
    local sx, sy, sxx, sxy = 0, 0, 0, 0
    for _, smp in ipairs(calib) do
        local x, y = math.log(smp.l), math.log(smp.kg)
        sx += x
        sy += y
        sxx += x * x
        sxy += x * y
    end
    local den = n * sxx - sx * sx
    if math.abs(den) < 1e-9 then
        local sum = 0
        for _, smp in ipairs(calib) do sum += smp.kg / smp.l ^ 3 end
        fit = {a = sum / n, b = 3}
        return
    end
    local b = math.clamp((n * sxy - sx * sy) / den, 0.5, 6)
    fit = {a = math.exp((sy - b * sx) / n), b = b}
end
refit()

local function estimateKg(l)
    if fit and l and l > 0 then return fit.a * l ^ fit.b end
    return nil
end

---------------------------------------------------------------------
-- الندرة: السكربت يتعلمها من صيدك (يقرا الندرة من نافذة "صيدة!")
-- ويربطها بشكل الضب ولون الـ Glow حقه، وبعدها يعرف أي ضب حي بنفس الشكل/اللون
---------------------------------------------------------------------
local RARITY_STYLE = {
    ["عادي"]          = rgb(175, 175, 185),
    ["نادر"]          = rgb(60, 150, 255),
    ["فاخر"]          = rgb(170, 100, 255),
    ["فاخر عملاق"]    = rgb(220, 90, 255),
    ["أسطوري"]        = rgb(255, 190, 60),
    ["أسطوري عملاق"]  = rgb(255, 135, 40),
    ["خرافي"]         = rgb(255, 80, 80),
    ["خرافي عملاق"]   = rgb(255, 40, 130),
}
local RARITY_ORDER = {"عادي", "نادر", "فاخر", "فاخر عملاق", "أسطوري", "أسطوري عملاق", "خرافي", "خرافي عملاق"}
local UNKNOWN_COLOR = rgb(255, 255, 255)

local function normAr(s)
    s = tostring(s or "")
    s = s:gsub("<[^>]->", "")
    s = s:gsub("\217[\139-\146]", "")
    s = s:gsub("\217\128", "")
    s = s:gsub("\216[\162\163\165]", "\216\167")
    s = s:gsub("\216\169", "\217\135")
    s = s:gsub("\217\137", "\217\138")
    s = s:gsub("[!%.،]", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local RARITY_BY_NORM = {}
for _, r in ipairs(RARITY_ORDER) do RARITY_BY_NORM[normAr(r)] = r end

-- بصمة الضب: لون/شكل الـ Glow والجسم والدرع
local function colKey(c)
    return string.format("%d,%d,%d", math.floor(c.R * 255 / 16), math.floor(c.G * 255 / 16), math.floor(c.B * 255 / 16))
end
local function firstPart(x)
    if not x then return nil end
    if x:IsA("BasePart") then return x end
    return x:FindFirstChildWhichIsA("BasePart", true)
end
local function partKey(p)
    if not p then return "-" end
    local s = ""
    if p:IsA("MeshPart") then s = p.MeshId .. "|" .. p.TextureID end
    s = s .. "|" .. colKey(p.Color) .. "|" .. p.Material.Name .. "|" .. math.floor(p.Transparency * 10)
    local sa = p:FindFirstChildOfClass("SurfaceAppearance")
    if sa then s = s .. "|" .. sa.ColorMap end
    return s
end

local function dhabKeys(m)
    local glowKey = "G" .. partKey(firstPart(m:FindFirstChild("Glow")))
    local light = m:FindFirstChildWhichIsA("Light", true)
    if light then glowKey = glowKey .. "|L" .. colKey(light.Color) end
    local hl = m:FindFirstChildWhichIsA("Highlight", true)
    if hl then glowKey = glowKey .. "|H" .. colKey(hl.FillColor) end
    local pe = m:FindFirstChildWhichIsA("ParticleEmitter", true)
    if pe then glowKey = glowKey .. "|P" .. colKey(pe.Color.Keypoints[1].Value) end

    local attrs = {}
    for k, v in pairs(m:GetAttributes()) do
        if type(v) == "string" and not string.lower(k):find("id", 1, true) then table.insert(attrs, k .. "=" .. v) end
    end
    table.sort(attrs)
    local full = glowKey .. "#" .. partKey(firstPart(m:FindFirstChild("Body"))) .. "#"
        .. partKey(firstPart(m:FindFirstChild("Armour"))) .. "#" .. table.concat(attrs, ",")
    return full, glowKey
end

saved.rar = type(saved.rar) == "table" and saved.rar or {}
local learnFull = type(saved.rar.full) == "table" and saved.rar.full or {}
local learnGlow = type(saved.rar.glow) == "table" and saved.rar.glow or {}
saved.rar.full, saved.rar.glow = learnFull, learnGlow

local function learnRarity(full, glow, rarity)
    learnFull[full] = (learnFull[full] == nil or learnFull[full] == rarity) and rarity or "!"
    learnGlow[glow] = (learnGlow[glow] == nil or learnGlow[glow] == rarity) and rarity or "!"
    saveSettings()
    print("[SimpleHub] learned rarity: " .. rarity)
end

local function learnedCount()
    local n = 0
    for _, v in pairs(learnFull) do if v ~= "!" then n += 1 end end
    return n
end

local keyCache = setmetatable({}, {__mode = "k"})
local aimTargetRef = function() return nil end -- يتعرّف في قسم Aim

-- يرجع الندرة أو nil لو ما يعرفها
local function identify(m)
    local keys = keyCache[m]
    if not keys or (os.clock() - keys.t) > 5 then
        local full, glow = dhabKeys(m)
        keys = {full = full, glow = glow, t = os.clock()}
        keyCache[m] = keys
    end
    local r = learnFull[keys.full]
    if r and r ~= "!" then return r end
    r = learnGlow[keys.glow]
    if r and r ~= "!" then return r end
    return nil
end

-- التعلم من نافذة "صيدة!"
local function onScreen(lbl)
    local o = lbl
    while o and o ~= playerGui do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("LayerCollector") and not o.Enabled then return false end
        o = o.Parent
    end
    return lbl.AbsoluteSize.X > 0
end

local function readCatchRarity()
    for _, lbl in ipairs(playerGui:GetDescendants()) do
        if lbl:IsA("TextLabel") and not lbl:IsDescendantOf(gui) and normAr(lbl.Text):find("صيده", 1, true) and onScreen(lbl) then
            -- ندور الندرة جنبه بنفس النافذة
            local box2 = lbl.Parent
            for _ = 1, 4 do
                if not box2 or box2 == playerGui then break end
                for _, d in ipairs(box2:GetDescendants()) do
                    if d:IsA("TextLabel") and d ~= lbl then
                        local r = RARITY_BY_NORM[normAr(d.Text)]
                        if r then return r end
                    end
                end
                box2 = box2.Parent
            end
        end
    end
    return nil
end

local function kgFor(m)
    return estimateKg(dhabLength(m))
end

local function applyVisibility(t)
    t.box.Visible = esp.on and esp.boxes
    t.sel.Visible = esp.on and esp.boxes
    t.bill.Enabled = esp.on and esp.labels
    if not (esp.on and esp.lines) then t.line.Visible = false end
end

local function setEspColor(t, color)
    if t.color == color then return end
    t.color = color
    t.box.Color3 = color
    t.sel.Color3 = color
    t.line.BackgroundColor3 = color
    t.l1.TextColor3 = color
end

local function shadowText(parent, size, color, weight, y, h)
    return text(parent, "", size, color, weight, {
        Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextStrokeTransparency = 0.45, TextStrokeColor3 = Color3.new(0, 0, 0),
    })
end

local function addEsp(m)
    if tracked[m] or not m:IsA("Model") then return end
    local root = modelRoot(m)
    if not root then return end

    local ok, bbCF, bbSize = pcall(function() return m:GetBoundingBox() end)
    if not ok then bbCF, bbSize = root.CFrame, root.Size end

    local boxAd = new("BoxHandleAdornment", {Adornee = root, AlwaysOnTop = true, ZIndex = 5, Color3 = ESP_COLOR,
        Transparency = 0.75, Size = bbSize, CFrame = root.CFrame:ToObjectSpace(bbCF), Parent = espFolder})
    local sel = new("SelectionBox", {Adornee = m, Color3 = ESP_COLOR, LineThickness = 0.03, SurfaceTransparency = 1, Parent = espFolder})

    local bill = new("BillboardGui", {Adornee = root, AlwaysOnTop = true, Size = UDim2.fromOffset(200, 48),
        StudsOffsetWorldSpace = Vector3.new(0, bbSize.Y / 2 + 2.2, 0), MaxDistance = math.huge, LightInfluence = 0, Parent = espFolder})
    local l1 = shadowText(bill, 15, ESP_COLOR, BOLD, 0, 18)           -- الندرة
    local l2 = shadowText(bill, 12, C.white, SEMI, 18, 15)            -- الوزن
    local l3 = shadowText(bill, 11, rgb(185, 185, 195), MED, 33, 14)  -- المسافة

    local line = box(lineLayer, {Size = UDim2.fromOffset(0, 2), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = ESP_COLOR, BackgroundTransparency = 0.1, ZIndex = 0, Visible = false})

    local t = {root = root, box = boxAd, sel = sel, bill = bill, line = line, l1 = l1, l2 = l2, l3 = l3}
    tracked[m] = t
    applyVisibility(t)
end

local function removeEsp(m)
    local t = tracked[m]
    if not t then return end
    for _, k in ipairs({"box", "sel", "bill", "line"}) do
        if t[k] then t[k]:Destroy() end
    end
    tracked[m] = nil
end

local function clearEsp()
    for m in pairs(tracked) do removeEsp(m) end
end

local gVis = group(espPage, 1, "Visuals")
defineAction("esp", {
    title = "ESP", short = "ESP", persist = true,
    run = function()
        esp.on = not esp.on
        if esp.on then task.spawn(loadGameData) else clearEsp() end
    end,
    get = function() return esp.on end,
})
local _, espDesc = actionRow(gVis, "esp", "workspace.DhabWild")
local function visToggle(title, desc, key)
    local _, right = row(gVis, title, desc)
    local set = toggle(right, function(v)
        esp[key] = v
        setState("esp." .. key, v)
        for _, t in pairs(tracked) do applyVisibility(t) end
    end)
    esp[key] = getState("esp." .. key, true)
    set(esp[key], true)
end
visToggle("Lines", "Blue line from you to every dhab", "lines")
visToggle("Boxes", "See-through box around each one", "boxes")
visToggle("Labels", "Weight and distance", "labels")

-- العلامات: تكتب اسم + إحداثيات (مثل: بيت ابو محمد 3425 -536 345) ويطلع لها علامة وخط
do
local WP_COLOR = rgb(255, 190, 60)
local waypoints = {} -- {name, pos, show, att, bill, line, distLbl}
local wpFolder = new("Folder", {Name = "SimpleHubWaypoints", Parent = playerGui})
espExports.wpFolder = wpFolder

local function saveWaypoints()
    local out = {}
    for _, w in ipairs(waypoints) do
        table.insert(out, {name = w.name, x = w.pos.X, y = w.pos.Y, z = w.pos.Z, show = w.show})
    end
    saved.waypoints = out
    saveSettings()
end

local function hideMarker(w)
    for _, k in ipairs({"att", "bill", "line"}) do
        if w[k] then w[k]:Destroy() w[k] = nil end
    end
end

local function showMarker(w)
    if w.att then return end
    w.att = new("Attachment", {WorldPosition = w.pos, Parent = workspace.Terrain})
    w.bill = new("BillboardGui", {Adornee = w.att, AlwaysOnTop = true, Size = UDim2.fromOffset(220, 58),
        SizeOffset = Vector2.new(0, 0.5), MaxDistance = math.huge, LightInfluence = 0, Parent = wpFolder})
    local pin = box(w.bill, {Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
        Rotation = 45, BackgroundColor3 = WP_COLOR})
    corner(pin, 2)
    stroke(pin, Color3.new(0, 0, 0), 1)
    text(w.bill, w.name, 14, WP_COLOR, BOLD, {Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center,
        TextStrokeTransparency = 0.4, TextTruncate = Enum.TextTruncate.AtEnd})
    w.distLbl = text(w.bill, "", 11, rgb(220, 220, 228), MED, {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4})
    w.line = box(lineLayer, {Size = UDim2.fromOffset(0, 2), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = WP_COLOR, BackgroundTransparency = 0.1, ZIndex = 0, Visible = false})
end

-- يفصل الاسم عن آخر 3 أرقام
local function parseWaypoint(str)
    local nums = {}
    for at, n in string.gmatch(str, "()(%-?%d+%.?%d*)") do
        table.insert(nums, {i = at, v = tonumber(n)})
    end
    if #nums < 3 then return nil end
    local x, y, z = nums[#nums - 2], nums[#nums - 1], nums[#nums]
    local name = str:sub(1, x.i - 1):gsub("^[%s,]+", ""):gsub("[%s,:]+$", "")
    if name == "" then name = "Point " .. (#waypoints + 1) end
    return name, Vector3.new(x.v, y.v, z.v)
end

local gWp = group(espPage, 2, "Waypoints")
gWp.count += 1
local inRow = box(gWp.list, {Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = gWp.count})
local function inputBox(props)
    local b = new("TextBox", {BackgroundColor3 = C.bg, Text = "", PlaceholderColor3 = C.faint, TextColor3 = C.text,
        TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = inRow})
    for k, v in pairs(props) do b[k] = v end
    corner(b, 6)
    pad(b, 8, 8)
    local st = stroke(b)
    b.Focused:Connect(function() tween(st, 0.12, {Color = C.accent}) end)
    b.FocusLost:Connect(function() tween(st, 0.12, {Color = C.border}) end)
    return b
end
local nameBox = inputBox({Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 26),
    PlaceholderText = "الاسم  (مثل: بيت ابو محمد)", FontFace = face(REG)})
local coordBoxWp = inputBox({Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -128, 0, 26),
    PlaceholderText = "x  y  z", FontFace = face(REG, MONO)})
local hereBtn = button(inRow, "Here", 50, false)
hereBtn.Position = UDim2.new(1, -112, 0, 44)
local addBtn = button(inRow, "Add", 50, true)
addBtn.Position = UDim2.new(1, -60, 0, 44)

-- قائمة العلامات (تنبني من جديد كل ما تتغير)
-- قيادة تلقائية للعلامة: السيارة تطير فوق الأرض بـ 20 بلوكة وتشوف قدامها
local drive = {
    token = nil, status = "Idle",
    -- ثابتة وما تتغير
    speed = 180,      -- السرعة
    height = 14,      -- كم يطير فوق الأرض
    airTime = 2,      -- كم ثانية يطير
    groundTime = 2,   -- بعدها كم ثانية يمشي على الأرض
    target = nil,     -- العلامة اللي رايح لها
}

local function carBroken(car, root)
    if root.CFrame.UpVector.Y < 0.2 then return true end -- مقلوبة
    local snap = carSnap[car]
    if snap then
        for part, off in pairs(snap) do
            if part.Parent and not part.Anchored then
                if (part.Position - (root.CFrame * off).Position).Magnitude > 6 then return true end -- كفر طاير
            end
        end
    end
    return false
end

local function autoDrive(dest, w)
    local car = getMover()
    if not car or car == player.Character then return false end
    local root = getRoot(car)
    if not root then return false end
    tp.token = nil
    local token = {}
    drive.token = token
    drive.target = w

    task.spawn(function()
        local prevGuard = guardOn
        guardOn = true
        refreshAction("rollback")
        if not carSnap[car] and moverSpeed(car) < 3 then snapshotCar(car) end
        travelling = true

        local pusher, gyro = getEffects(root)
        lockWheels(car, root)

        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local function groundY(x, z)
            rp.FilterDescendantsInstances = {car, player.Character, dhabFolder}
            local r = workspace:Raycast(Vector3.new(x, root.Position.Y + 300, z), Vector3.new(0, -1500, 0), rp)
            return r and r.Position.Y
        end

        local legs = buildRoute(root.Position, dest)
        local lastCheck, lastPos, stuckT, extra = 0, root.Position, 0, 0
        local onGround, modeT = false, 0 -- يتبادل: يطير شوي، وبعدين يمشي على الأرض شوي
        local liftY, liftUntil = nil, 0   -- رفعة مؤقتة لو فيه شي قدامنا

        for li, leg in ipairs(legs) do
            local final = li == #legs
            while alive and drive.token == token do
                local dt = RunService.Heartbeat:Wait()
                if getMover() ~= car or not root.Parent then
                    drive.token = nil
                    drive.status = "Left the car"
                    break
                end
                local pos = root.Position
                local to = flat(leg.pos - pos)
                local distH = to.Magnitude

                -- وصلنا لهالمرحلة؟
                if distH < (leg.low and 5 or 8) then
                    if not final then break end
                    local gy = groundY(leg.pos.X, leg.pos.Z) or leg.pos.Y
                    if pos.Y - gy < 7 then break end
                end

                local dir = distH > 0.1 and to.Unit or Vector3.zero

                -- نشوف الأرض قدامنا ونطير فوق أعلى نقطة
                local look = math.min(distH, math.max(60, drive.speed * 0.8))
                local maxG = nil
                for _, f in ipairs({0, 0.25, 0.5, 0.75, 1}) do
                    local p = pos + dir * look * f
                    local g = groundY(p.X, p.Z)
                    if g and (not maxG or g > maxG) then maxG = g end
                end
                maxG = maxG or leg.pos.Y

                -- تبديل بين الطيران والمشي على الأرض
                modeT += dt
                if onGround and modeT >= drive.groundTime then
                    onGround, modeT = false, 0
                elseif not onGround and modeT >= drive.airTime then
                    onGround, modeT = true, 0
                end
                local groundMode = onGround and not leg.low and not (final and distH < 8) and extra == 0

                if groundMode then
                    -- على الأرض نشوف قدامنا مسافة قصيرة بس
                    local near = nil
                    for _, f in ipairs({0, 0.1, 0.2}) do
                        local p = pos + dir * look * f
                        local g = groundY(p.X, p.Z)
                        if g and (not near or g > near) then near = g end
                    end
                    maxG = near or maxG
                end

                local desiredY
                if groundMode then
                    desiredY = maxG + 3.5                   -- يمشي على الأرض
                elseif leg.low then
                    desiredY = maxG + 4                     -- البوابة: على الأرض
                elseif final and distH < 8 then
                    desiredY = maxG + 3                     -- ننزل عند العلامة
                else
                    desiredY = maxG + drive.height + extra  -- 14 بلوكة فوق الأرض
                end

                -- نشوف قدامنا: لو فيه شي بنصقع فيه نرتفع فوقه شوي وبعدين ننزل
                if dir.Magnitude > 0 then
                    local reach = drive.speed * 0.7 + 20
                    for _, off in ipairs({-1.5, 1.5, 4}) do
                        local from = pos + Vector3.new(0, off, 0)
                        local hit = workspace:Raycast(from, dir * reach, rp)
                        if hit then
                            local ahead = hit.Position + dir * 4
                            local top = groundY(ahead.X, ahead.Z) or (hit.Position.Y + 10)
                            liftY = math.max(liftY or -math.huge, top + 6)
                            liftUntil = os.clock() + 1
                            break
                        end
                    end
                end
                if liftY and os.clock() < liftUntil and not (final and distH < 8) then
                    desiredY = math.max(desiredY, liftY)
                elseif liftY and os.clock() >= liftUntil then
                    liftY = nil
                end

                local hs = leg.low and math.min(drive.speed, 60) or drive.speed
                if distH < 40 then hs = math.min(hs, distH * 2 + 10) end
                local climb = desiredY - pos.Y
                if climb > 25 then hs *= 0.4 end            -- جبل قدامنا: نخفف ونطلع
                local vy = math.clamp(climb * 2, -50, 80)

                pusher.MaxForce = Vector3.new(900000, 900000, 900000)
                pusher.Velocity = dir * hs + Vector3.new(0, vy, 0)
                gyro.MaxTorque = GYRO_TORQUE
                if dir.Magnitude > 0 then gyro.CFrame = CFrame.lookAt(pos, pos + dir) end

                -- علقنا؟ نطلع أعلى
                if (pos - lastPos).Magnitude < hs * dt * 0.15 then
                    stuckT += dt
                    if stuckT > 2 then
                        extra += 15
                        stuckT = 0
                    end
                else
                    stuckT = 0
                end
                lastPos = pos

                -- خربت السيارة؟ نصلحها ونكمل
                if os.clock() - lastCheck > 0.5 then
                    lastCheck = os.clock()
                    if carBroken(car, root) then
                        drive.status = "Fixing car..."
                        fixCar(car)
                        pusher, gyro = getEffects(root)
                        lockWheels(car, root)
                    end
                end

                drive.status = string.format("%s  ·  %dm left", leg.gate and "Through gate" or (groundMode and "On ground" or "Flying"),
                    math.floor(flat(dest - pos).Magnitude))
            end
            if drive.token ~= token then break end
        end

        pusher.Velocity = Vector3.zero
        pusher.MaxForce = Vector3.zero
        if not running then gyro.MaxTorque = Vector3.zero end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if root.Parent and carBroken(car, root) then fixCar(car) end
        travelling = false
        task.delay(0.5, function()
            if not running and not travelling and car.Parent then unlockWheels(car) end
        end)
        guardOn = prevGuard
        refreshAction("rollback")
        if drive.token == token then
            drive.token = nil
            drive.status = "Arrived"
        end
    end)
    return true
end

local refreshDriveButtonsRef = nil
local gDrive = group(espPage, 4, "Auto drive")
local _, dStRight, _, dStDesc = row(gDrive, "Status", "Tap Drive on a waypoint (you need a car)")
local dStop = button(dStRight, "Stop", 52)
dStop.Activated:Connect(function()
    if drive.token then
        drive.token = nil
        drive.status = "Stopped"
    end
    if refreshDriveButtonsRef then refreshDriveButtonsRef() end
end)
local _, _, dInfo = row(gDrive, "Speed 180  ·  14 blocks up  ·  2s air / 2s ground")
dInfo.Size = UDim2.new(1, -24, 0, 42)
dInfo.TextColor3 = C.muted
dInfo.TextSize = 11

-- زر Drive لكل علامة: أزرق = Drive، أحمر = Stop
local driveButtons = {}
local function refreshDriveButtons()
    for w, b in pairs(driveButtons) do
        if b.Parent then
            local on = drive.token ~= nil and drive.target == w
            b.BackgroundColor3 = on and C.red or C.accent
            b.Text = on and "Stop" or "Drive"
        else
            driveButtons[w] = nil
        end
    end
end
refreshDriveButtonsRef = refreshDriveButtons

task.spawn(function()
    while alive do
        refreshDriveButtons()
        if win.Visible and currentPage == 3 then dStDesc.Text = drive.status end
        task.wait(0.2)
    end
end)

espExports.stopDrive = function() drive.token = nil end

local listWrap = box(espPage, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, LayoutOrder = 3})
local listGroup = nil

local rebuild
local showTrashRef = nil
local function wpRow(g, w)
    local _, right, _, dl = row(g, w.name, string.format("%.0f, %.0f, %.0f", w.pos.X, w.pos.Y, w.pos.Z))
    w.descLbl = dl
    local go = new("TextButton", {Size = UDim2.fromOffset(52, 26), BackgroundColor3 = C.accent, AutoButtonColor = false,
        Text = "Drive", TextSize = 12, TextColor3 = C.white, FontFace = face(SEMI), LayoutOrder = 1, Parent = right})
    corner(go, 6)
    pressScale(go)
    driveButtons[w] = go
    go.Activated:Connect(function()
        if drive.token and drive.target == w then
            drive.token = nil
            drive.status = "Stopped"
        elseif not autoDrive(w.pos, w) then
            go.Text = "No car"
            task.delay(0.9, refreshDriveButtons)
            return
        end
        refreshDriveButtons()
    end)
    local del = button(right, "Del", 40, false, 2)
    del.Activated:Connect(function()
        hideMarker(w)
        -- نحفظه بالمحذوفات عشان تقدر ترجعه
        saved.wpTrash = type(saved.wpTrash) == "table" and saved.wpTrash or {}
        table.insert(saved.wpTrash, {name = w.name, x = w.pos.X, y = w.pos.Y, z = w.pos.Z})
        while #saved.wpTrash > 30 do table.remove(saved.wpTrash, 1) end
        table.remove(waypoints, table.find(waypoints, w))
        if showTrashRef then showTrashRef() end
        saveWaypoints()
        rebuild()
    end)
    local set = toggle(right, function(v)
        w.show = v
        if v then showMarker(w) else hideMarker(w) end
        saveWaypoints()
    end, 3)
    set(w.show, true)
end

rebuild = function()
    if listGroup then listGroup.list.Parent:Destroy() end
    listGroup = nil
    if #waypoints == 0 then return end
    listGroup = group(listWrap, 1, nil)
    for _, w in ipairs(waypoints) do wpRow(listGroup, w) end
end
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = listWrap})

local function addWaypoint(name, pos, show)
    local w = {name = name, pos = pos, show = show}
    table.insert(waypoints, w)
    if show then showMarker(w) end
    return w
end

hereBtn.Activated:Connect(function()
    local m = getMover()
    if m then
        local p = m:GetPivot().Position
        coordBoxWp.Text = string.format("%.1f  %.1f  %.1f", p.X, p.Y, p.Z)
    end
end)
addBtn.Activated:Connect(function()
    local nums = {}
    for n in string.gmatch(coordBoxWp.Text, "%-?%d+%.?%d*") do table.insert(nums, tonumber(n)) end
    if #nums < 3 then
        feedback(addBtn, "Add", false, nil, "x y z")
        return
    end
    local name = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "Point " .. (#waypoints + 1) end
    addWaypoint(name, Vector3.new(nums[1], nums[2], nums[3]), true)
    saveWaypoints()
    rebuild()
    nameBox.Text = ""
    coordBoxWp.Text = ""
    feedback(addBtn, "Add", true, "Added")
end)

-- نرجع العلامات المحفوظة
if type(saved.waypoints) == "table" then
    for _, s in ipairs(saved.waypoints) do
        if type(s) == "table" and s.x and s.y and s.z then
            addWaypoint(tostring(s.name or "Point"), Vector3.new(s.x, s.y, s.z), s.show ~= false)
        end
    end
end

-- مواقع الماب بالبوصلة حقت اللعبة
-- معايرة من قياساتك: جنوب 250 + شرق 250 = (472.4, 449.5)  ،  شمال 250 + غرب 250 = (-472.1, -476.0)
-- يعني: شرق = +X ، جنوب = +Z ، وكل متر باللعبة ≈ 1.89 (X) و 1.85 (Z)
local MAP_X0, MAP_Z0 = (472.4 + -472.1) / 2, (449.5 + -476.0) / 2
local MAP_SX, MAP_SZ = (472.4 + 472.1) / 500, (449.5 + 476.0) / 500
local function mapPos(ns, n, ew, e)
    local south = (ns == "S" and 1 or -1) * n
    local east = (ew == "E" and 1 or -1) * e
    return Vector3.new(MAP_X0 + east * MAP_SX, 10, MAP_Z0 + south * MAP_SZ)
end
local MAP_SPOTS = {
    {"المدينة", Vector3.new(-451.8, 2.7, 125.5)},
    {"ديار العماليك", mapPos("N", 12410, "W", 1090)},
    {"حزم الياقوت", mapPos("N", 14450, "E", 5230)},
    {"قارة التبر", mapPos("S", 14400, "E", 5240)},
    {"نقرة الفيروز", mapPos("N", 2650, "W", 15120)},
    {"شعاب التيه", mapPos("N", 11210, "W", 6970)},
    {"خانق العماليق", mapPos("N", 7240, "W", 11130)},
    {"محطة ديار العماليق", mapPos("N", 10880, "W", 8770)},
}
-- نصلح المواقع القديمة الغلط (نفس الاسم) ونضيف الناقص
local byName = {}
for _, w in ipairs(waypoints) do byName[w.name] = w end
for _, spot in ipairs(MAP_SPOTS) do
    local w = byName[spot[1]]
    if w then
        if (w.pos - spot[2]).Magnitude > 1 then
            hideMarker(w)
            w.pos = spot[2]
            if w.show then showMarker(w) end
        end
    else
        addWaypoint(spot[1], spot[2], true)
    end
end
saveWaypoints()

-- ترجيع العلامات المحذوفة
local _, restRight, _, restDesc = row(gWp, "Restore", "Bring back a waypoint you deleted")
local undoWp = button(restRight, "Undo", 52, false, 1)
local allWp = button(restRight, "Map spots", 76, false, 2)
local function trashCount()
    return type(saved.wpTrash) == "table" and #saved.wpTrash or 0
end
local function showTrash()
    local n = trashCount()
    restDesc.Text = n > 0 and (n .. " deleted  ·  last: " .. tostring(saved.wpTrash[n].name)) or "Nothing deleted"
end
showTrash()
undoWp.Activated:Connect(function()
    if trashCount() == 0 then
        feedback(undoWp, "Undo", false, nil, "Empty")
        return
    end
    local t = table.remove(saved.wpTrash)
    addWaypoint(tostring(t.name or "Point"), Vector3.new(t.x, t.y, t.z), true)
    saveWaypoints()
    rebuild()
    showTrash()
    feedback(undoWp, "Undo", true, "Back")
end)
allWp.Activated:Connect(function()
    local have = {}
    for _, w in ipairs(waypoints) do have[w.name] = true end
    local n = 0
    for _, spot in ipairs(MAP_SPOTS) do
        if not have[spot[1]] then
            addWaypoint(spot[1], spot[2], true)
            n += 1
        end
    end
    saveWaypoints()
    rebuild()
    feedback(allWp, "Map spots", n > 0, n > 0 and ("+" .. n) or nil, "All there")
end)
showTrashRef = showTrash
rebuild()

-- المسافة كل شوي
task.spawn(function()
    while alive do
        local m = getMover()
        local myPos = m and m:GetPivot().Position
        for _, w in ipairs(waypoints) do
            if w.distLbl and myPos then
                w.distLbl.Text = math.floor((myPos - w.pos).Magnitude) .. " m"
            end
        end
        task.wait(0.3)
    end
end)

-- الخط منك للعلامة
bind(RunService.RenderStepped, function()
    local vp = Camera.ViewportSize
    local from = Vector2.new(vp.X / 2, vp.Y)
    local m = getMover()
    if m then
        local p = Camera:WorldToViewportPoint(m:GetPivot().Position)
        if p.Z > 0 then from = Vector2.new(p.X, p.Y) end
    end
    for _, w in ipairs(waypoints) do
        if w.line then
            local p = Camera:WorldToViewportPoint(w.pos)
            local to = Vector2.new(p.X, p.Y)
            if p.Z < 0 then
                local c = vp / 2
                local d = c - to
                if d.Magnitude < 1 then d = Vector2.new(0, 1) end
                to = c + d.Unit * vp.Magnitude
            end
            local delta = to - from
            w.line.Size = UDim2.fromOffset(delta.Magnitude, 2)
            w.line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
            w.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
            w.line.Visible = true
        end
    end
end)

espExports.wpCleanup = function()
    for _, w in ipairs(waypoints) do hideMarker(w) end
end
end

do
local gInspect = group(espPage, 5, "Inspect")
local _, inspRight = row(gInspect, "Nearest dhab", "Everything the script found about it")
local inspBtn = button(inspRight, "Inspect", 64)
local inspOut = outputRow(gInspect, "Tap Inspect, then send a screenshot of this box if kg shows as ?")

inspBtn.Activated:Connect(function()
    local folder = workspace:FindFirstChild("DhabWild")
    local mover = getMover()
    if not (folder and mover) then
        inspOut.Text = "DhabWild not found."
        return
    end
    inspBtn.Text = "..."
    loadGameData()
    inspBtn.Text = "Inspect"

    local myPos = mover:GetPivot().Position
    local best, bestD = nil, math.huge
    for _, m in ipairs(folder:GetChildren()) do
        local r = m:IsA("Model") and modelRoot(m)
        if r then
            local d = (r.Position - myPos).Magnitude
            if d < bestD then best, bestD = m, d end
        end
    end
    if not best then
        inspOut.Text = "No dhab nearby."
        return
    end

    local lines = {best.Name .. "  (" .. math.floor(bestD) .. "m)"}
    local function add(s)
        if #lines < 50 then table.insert(lines, s) end
    end

    add("-- on the model")
    for k, v in pairs(best:GetAttributes()) do add("@" .. k .. " = " .. tostring(v)) end
    for _, d in ipairs(best:GetDescendants()) do
        for k, v in pairs(d:GetAttributes()) do add("@" .. d.Name .. "." .. k .. " = " .. tostring(v)) end
        if d:IsA("ValueBase") then add(d.Name .. " = " .. tostring(d.Value)) end
        if d:IsA("TextLabel") and d.Text ~= "" then add(d.Name .. ' "' .. d.Text .. '"') end
    end
    add(string.format("scale = %.2f   length = %.3f", best:GetScale(), dhabLength(best) or 0))
    local rI = identify(best)
    local fk, gk = dhabKeys(best)
    add("rarity = " .. (rI or "?") .. "   (learned " .. learnedCount() .. ")")
    add("glow = " .. gk)
    add("key = " .. fk)

    local extra = searchById(best)
    add("-- same id elsewhere")
    if extra then
        for k, v in pairs(extra) do add(k .. " = " .. tostring(v)) end
    else
        add("(nothing yet)")
    end

    local rar = pick(collect(best), RAR_KEYS, true)
    local info = rar and getTierInfo(rar)
    add("-- game data for " .. tostring(rar))
    add("modules read: " .. (gameData and #gameData or 0))
    if info and next(info) then
        for k, v in pairs(info) do add(k .. " = " .. tostring(v)) end
    else
        add("(no tier table found)")
    end

    inspOut.Text = table.concat(lines, "\n")
    inspOut.TextColor3 = C.text
    print("[SimpleHub] inspect\n" .. inspOut.Text)
end)

end
task.spawn(function()
    dhabFolder = workspace:WaitForChild("DhabWild")
    if not alive then return end
    bind(dhabFolder.ChildAdded, function(m)
        task.wait(0.2)
        if alive and esp.on then addEsp(m) end
    end)
    bind(dhabFolder.ChildRemoved, removeEsp)
end)

task.spawn(function()
    while alive do
        if esp.on and dhabFolder then
            for _, m in ipairs(dhabFolder:GetChildren()) do
                if not tracked[m] then addEsp(m) end
            end
            local mover = getMover()
            local myPos = mover and mover:GetPivot().Position
            local count = 0
            for m, t in pairs(tracked) do
                if m.Parent ~= dhabFolder or not t.root.Parent then
                    removeEsp(m)
                else
                    count += 1
                    setEspColor(t, Color3.new(1, 1, 1))
                    if esp.labels then
                        local kg = kgFor(m)
                        t.l1.Text = kg and string.format("%.1f kg", kg) or "? kg"
                        t.l2.Text = myPos and (math.floor((myPos - t.root.Position).Magnitude) .. " m") or ""
                        t.l3.Text = ""
                    end
                end
            end
            espDesc.Text = count .. " found"
        elseif not esp.on then
            espDesc.Text = "workspace.DhabWild"
        end
        task.wait(0.5)
    end
end)

bind(RunService.RenderStepped, function()
    if not (esp.on and esp.lines) then return end
    local vp = Camera.ViewportSize
    local from = Vector2.new(vp.X / 2, vp.Y)
    local mover = getMover()
    if mover then
        local p = Camera:WorldToViewportPoint(mover:GetPivot().Position)
        if p.Z > 0 then from = Vector2.new(p.X, p.Y) end
    end
    for _, t in pairs(tracked) do
        if t.root.Parent then
            local p = Camera:WorldToViewportPoint(t.root.Position)
            local to = Vector2.new(p.X, p.Y)
            if p.Z < 0 then
                local c = vp / 2
                local d = c - to
                if d.Magnitude < 1 then d = Vector2.new(0, 1) end
                to = c + d.Unit * vp.Magnitude
            end
            local delta = to - from
            t.line.Size = UDim2.fromOffset(delta.Magnitude, 2)
            t.line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
            t.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
            t.line.Visible = true
        else
            t.line.Visible = false
        end
    end
end)

---------------------------------------------------------------------
-- صفحة Aim: تضغط زر LOCK -> الايم يثبت على الضب اللي بنص الشاشة ويطلق عليه
---------------------------------------------------------------------
local Event = nil
task.spawn(function()
    Event = ReplicatedStorage:WaitForChild("Dhab"):WaitForChild("Event")
end)

local aim = {lock = false, showFov = true, shoot = false, rate = 0.4, fov = 160, draw = 0}
local aimTarget = nil
local lastShot = 0
local LOCK_COLOR = rgb(255, 80, 80)

local fovCircle = box(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(aim.fov * 2, aim.fov * 2), BackgroundTransparency = 1, Visible = false, ZIndex = 1})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fovCircle})
local fovStroke = stroke(fovCircle, C.muted, 1.5)
fovStroke.Transparency = 0.3
local lockLbl = text(fovCircle, "", 12, LOCK_COLOR, BOLD, {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(240, 16),
    TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.45,
})

local function aimPart(m)
    local h = m:FindFirstChild("Hitbox")
    if h then
        if h:IsA("BasePart") then return h end
        local p = h:FindFirstChildWhichIsA("BasePart", true)
        if p then return p end
    end
    return modelRoot(m)
end

local function pickTarget()
    if not dhabFolder then return nil end
    local center = Camera.ViewportSize / 2
    local best, bestD = nil, aim.fov
    for _, m in ipairs(dhabFolder:GetChildren()) do
        local p = m:IsA("Model") and aimPart(m)
        if p then
            local sp, onScreen = Camera:WorldToViewportPoint(p.Position)
            if onScreen and sp.Z > 0 then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d < bestD then best, bestD = m, d end
            end
        end
    end
    return best
end

local function shootAt(pos)
    if not Event then return end
    local head = player.Character and player.Character:FindFirstChild("Head")
    local origin = head and head.Position or Camera.CFrame.Position
    local dir = pos - origin
    if dir.Magnitude < 0.01 then return end
    pcall(function()
        Event:FireServer("Fire", {
            ["draw"] = aim.draw,
            ["direction"] = dir.Unit,
            ["origin"] = origin,
        })
    end)
end

pcall(function() RunService:UnbindFromRenderStep("SimpleHubAim") end)
RunService:BindToRenderStep("SimpleHubAim", Enum.RenderPriority.Camera.Value + 1, function()
    if not alive then return end
    fovCircle.Size = UDim2.fromOffset(aim.fov * 2, aim.fov * 2)
    fovCircle.Visible = aim.showFov or aim.lock

    if not aim.lock then
        aimTarget = nil
        fovStroke.Color = C.muted
        lockLbl.Text = ""
        return
    end

    if aimTarget and (aimTarget.Parent ~= dhabFolder or not aimPart(aimTarget)) then
        aimTarget = nil
    end
    if not aimTarget then aimTarget = pickTarget() end
    if not aimTarget then
        fovStroke.Color = C.amber
        lockLbl.TextColor3 = C.amber
        lockLbl.Text = "SEARCHING"
        return
    end

    local pos = aimPart(aimTarget).Position
    fovStroke.Color = LOCK_COLOR
    lockLbl.TextColor3 = LOCK_COLOR
    local t = tracked[aimTarget]
    lockLbl.Text = "LOCKED" .. (t and t.l1.Text ~= "" and ("  ·  " .. t.l1.Text) or "")

    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, pos)

    if aim.shoot and os.clock() - lastShot >= aim.rate then
        lastShot = os.clock()
        shootAt(pos)
    end
end)

defineAction("lock", {
    title = "Aim lock", short = "LOCK", key = Enum.KeyCode.Q, float = true,
    run = function() aim.lock = not aim.lock; aimTarget = nil end,
    get = function() return aim.lock end,
})
defineAction("shoot", {
    title = "Auto shoot", short = "SHOOT", persist = true,
    run = function() aim.shoot = not aim.shoot end,
    get = function() return aim.shoot end,
})

do
for _, k in ipairs({"fov", "rate", "draw"}) do
    aim[k] = getState("aim." .. k, aim[k])
end
local gAim = group(aimPage, 1, "Aim")
actionRow(gAim, "lock", "Locks on the dhab nearest the centre")
local _, fovShowRight = row(gAim, "Show circle", "Always show the targeting circle")
local setShowFov = toggle(fovShowRight, function(v) aim.showFov = v; setState("aim.showFov", v) end)
aim.showFov = getState("aim.showFov", true)
setShowFov(aim.showFov, true)
local _, fovRight = row(gAim, "Circle size", "Targets are picked inside it")
stepper(fovRight, function(v) return tostring(v) end, function() return aim.fov end, function(v) aim.fov = v; setState("aim.fov", v) end, 20, 60, 400)

local gShoot = group(aimPage, 2, "Shooting")
actionRow(gShoot, "shoot", "Keeps firing while locked on")
local _, rateRight = row(gShoot, "Delay", "Seconds between shots")
stepper(rateRight, function(v) return string.format("%.1fs", v) end, function() return aim.rate end, function(v) aim.rate = v; setState("aim.rate", v) end, 0.1, 0.1, 3)
local _, drawRight = row(gShoot, "Draw", "The draw value sent with each shot")
stepper(drawRight, function(v) return string.format("%.2f", v) end, function() return aim.draw end, function(v) aim.draw = v; setState("aim.draw", v) end, 0.25, 0, 1)

aimTargetRef = function() return aimTarget end

-- السيارة تلحق الضب اللي عليه LOCK عشان الطلقة توصل
local follow = {on = getState("aim.follow", true), dist = getState("aim.followDist", 20), active = false, car = nil}

local followRay = RaycastParams.new()
followRay.FilterType = Enum.RaycastFilterType.Exclude

local function stopFollow()
    local car = follow.car
    follow.active = false
    follow.car = nil
    if car and car.Parent then
        local root = getRoot(car)
        if root then
            local pusher = root:FindFirstChild("CustomSpeedPusher")
            local gyro = root:FindFirstChild("CustomStabilizer")
            if pusher then
                pusher.Velocity = Vector3.zero
                pusher.MaxForce = Vector3.zero
            end
            if gyro and not running then gyro.MaxTorque = Vector3.zero end
        end
    end
    travelling = false
    task.delay(0.5, function()
        if car and car.Parent and not running and not travelling then unlockWheels(car) end
    end)
end

bind(RunService.Heartbeat, function()
    local car = getMover()
    local want = alive and follow.on and aim.lock and aimTarget and aimTarget.Parent
        and car and car ~= player.Character and not running
        and (follow.active or not travelling) -- ما نتدخل وقت Drive أو التلبورت
    if not want or (follow.active and follow.car ~= car) then
        if follow.active then stopFollow() end
        return
    end
    local root = getRoot(car)
    local part = aimPart(aimTarget)
    if not (root and part) then return end

    if not follow.active then
        follow.active = true
        follow.car = car
        travelling = true
        lockWheels(car, root)
    end
    local pusher, gyro = getEffects(root)

    local pos = root.Position
    local d = Vector3.new(part.Position.X - pos.X, 0, part.Position.Z - pos.Z)
    local dist = d.Magnitude
    local dir = dist > 0.1 and d.Unit or Vector3.zero
    local spd = 0
    if dist > follow.dist then spd = math.min(120, (dist - follow.dist) * 2 + 10) end

    -- نمشي على الأرض (نشوف الأرض قدامنا شوي)
    followRay.FilterDescendantsInstances = {car, player.Character, dhabFolder}
    local probe = pos + dir * 12
    local hit = workspace:Raycast(Vector3.new(probe.X, pos.Y + 60, probe.Z), Vector3.new(0, -300, 0), followRay)
    local groundY = hit and hit.Position.Y or (pos.Y - 3)
    local vy = math.clamp((groundY + 4 - pos.Y) * 3, -40, 40)

    pusher.MaxForce = Vector3.new(900000, 900000, 900000)
    pusher.Velocity = dir * spd + Vector3.new(0, vy, 0)
    gyro.MaxTorque = GYRO_TORQUE
    if dist > 1 then gyro.CFrame = CFrame.lookAt(pos, pos + dir) end
end)

do
    local gFollow = group(aimPage, 3, "Car")
    local _, fRight = row(gFollow, "Follow target", "While locked, your car chases the dhab")
    local setFollow = toggle(fRight, function(v)
        follow.on = v
        setState("aim.follow", v)
    end)
    setFollow(follow.on, true)
    local _, fdRight = row(gFollow, "Follow distance", "How close the car gets")
    stepper(fdRight, function(v) return tostring(v) end, function() return follow.dist end,
        function(v) follow.dist = v; setState("aim.followDist", v) end, 5, 5, 80)
end

---------------------------------------------------------------------
end
espExports.clear = clearEsp
espExports.folder = espFolder
end)()

---------------------------------------------------------------------
-- صفحة Car
---------------------------------------------------------------------
defineAction("fly", {
    title = "Fly", short = "FLY", key = Enum.KeyCode.R,
    run = toggleFly,
    get = function() return running end,
})
defineAction("forward", {
    title = "Auto forward", short = "FWD",
    run = function() mobileForward = not mobileForward end,
    get = function() return mobileForward end,
})
defineAction("fixcar", {
    title = "Fix car", short = "FIX",
    run = function() fixCar() end,
    get = function() return false end,
})
defineAction("rollback", {
    title = "Anti rollback", short = "ANTI", persist = true,
    run = function()
        guardOn = not guardOn
        table.clear(lastPivot)
        prevMover = nil
    end,
    get = function() return guardOn end,
})

do
SPEED = getState("fly.speed", SPEED)
local gFlight = group(carPage, 1, "Flight")
actionRow(gFlight, "fly", "Hold W to fly where the camera looks")
actionRow(gFlight, "forward", "Keeps flying forward without W")
local _, speedRight = row(gFlight, "Speed", "Studs per second")
stepper(speedRight, function(v) return tostring(v) end, function() return SPEED end, function(v) SPEED = v; setState("fly.speed", v) end, 25, 50, 800)

local gProt = group(carPage, 2, "Protection")
actionRow(gProt, "rollback", "Stops the server pulling you or your car back")
local _, fixRight = row(gProt, "Fix car", "Puts the wheels back and stands it upright")
keyButton(fixRight, "fixcar", 1)
local fixBtn = button(fixRight, "Fix", 44, true, 2)
fixBtn.Activated:Connect(function()
    feedback(fixBtn, "Fix", fixCar(), "Done", "No car")
end)

end
---------------------------------------------------------------------
-- فتح وقفل
---------------------------------------------------------------------
local function fitScale()
    local vp = Camera.ViewportSize
    return math.min(1, (vp.X - 40) / WIN_W, (vp.Y - 40) / WIN_H)
end

local function setWindow(open)
    if open then
        local s = fitScale()
        win.Visible = true
        winScale.Scale = s * 0.96
        tween(winScale, 0.25, {Scale = s})
    else
        win.Visible = false
        if listening then
            listening.btn.Text = bindName(actions[listening.id].key)
            listening = nil
        end
    end
end

defineAction("menu", {
    title = "Menu", short = "MENU", key = Enum.KeyCode.M, floatable = false,
    run = function() setWindow(not win.Visible) end,
    get = function() return win.Visible end,
})
defineAction("profile", {
    title = "Profile card", short = "ME", key = Enum.KeyCode.Minus, floatable = false,
    run = function() setCard(not cardOpen) end,
    get = function() return cardOpen end,
})

---------------------------------------------------------------------
-- صفحة Controls
---------------------------------------------------------------------
do
local gKeys = group(controlsPage, 1, "Keybinds")
for _, id in ipairs(actionOrder) do
    local _, right = row(gKeys, actions[id].title)
    keyButton(right, id, 1)
end
local _, _, keyHint = row(gKeys, "Tap a key, then press any key or MB2.  Backspace clears it.")
keyHint.Size = UDim2.new(1, -24, 0, 42)
keyHint.TextColor3 = C.muted
keyHint.TextSize = 11

local gFloat = group(controlsPage, 2, "On-screen buttons")
for _, id in ipairs(actionOrder) do
    local a = actions[id]
    if a.floatable then
        local _, right = row(gFloat, a.title, a.short)
        local set = toggle(right, function(v) setFloat(id, v) end)
        set(a.showFloat, true)
    end
end

local gLayout = group(controlsPage, 3, "Layout")
local _, moveRight = row(gLayout, "Move buttons", "Drag them anywhere, then turn this off")
toggle(moveRight, function(v)
    editMode = v
    for _, id in ipairs(actionOrder) do refreshAction(id) end
end)
local _, resetRight = row(gLayout, "Reset positions", "Puts every on-screen button back")
local resetBtn = button(resetRight, "Reset", 56)
resetBtn.Activated:Connect(function()
    for _, id in ipairs(actionOrder) do
        local a = actions[id]
        if type(saved.float[id]) == "table" then
            saved.float[id].x, saved.float[id].y = nil, nil
        end
        if a.floatBtn then
            local p = floatDefaultPos(floatSlot(id))
            a.floatBtn.Position = UDim2.fromOffset(p.X, p.Y)
        end
    end
    saveSettings()
    feedback(resetBtn, "Reset", true, "Done")
end)

end
for _, id in ipairs(actionOrder) do
    local a = actions[id]
    if a.floatable and a.showFloat then createFloat(a, floatSlot(id)) end
end

-- نرجع الخيارات اللي كانت شغالة آخر مرة
for _, id in ipairs(actionOrder) do
    local a = actions[id]
    if a.persist and getState("act." .. id, false) and not a.get() then
        a.run()
    end
    refreshAction(id)
end

bind(menuBtn.Activated, function() runAction("menu") end)
bind(closeBtn.Activated, function() setWindow(false) end)
bind(flyBtn.Activated, function() runAction("fly") end)
bind(meBtn.Activated, function() runAction("profile") end)

selectPage(1)
updateFlyUI()
setCard(true)

---------------------------------------------------------------------
-- تنظيف كامل لو شغلت السكربت مرة ثانية
---------------------------------------------------------------------
_G.SimpleHubCleanup = function()
    alive = false
    if espExports.stopDrive then espExports.stopDrive() end
    pcall(function() RunService:UnbindFromRenderStep("SimpleHubAim") end)
    table.clear(autoBuy)
    tp.token = nil
    if espExports.clear then espExports.clear() end
    stopFly()
    for _, c in ipairs(conns) do c:Disconnect() end
    table.clear(conns)
    if espExports.folder then espExports.folder:Destroy() end
    if espExports.wpCleanup then pcall(espExports.wpCleanup) end
    if espExports.wpFolder then espExports.wpFolder:Destroy() end
    if gui then gui:Destroy() end
end
