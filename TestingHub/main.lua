local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

local settings = {
    Enabled = false,
    Method = "BodyVelocity",
    Distance = 5,
    Speed = 16,
    RotationSpeed = 2,
    Mode = "Nearest",
    TargetLetter = ""
}

local strafeLoop = nil
local isStrafing = false
local noclipConnections = {}
local isInjected = true
local screenGui = nil

local function getStrafeTarget()
    if settings.Mode == "Nearest" then
        local nearest, minDist = nil, math.huge
        local character = player.Character
        if not character then return nil end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return nil end

        for _, plr in pairs(players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (rootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = plr
                end
            end
        end
        return nearest
    else
        if settings.TargetLetter == "" then return nil end
        for _, plr in pairs(players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local name = string.lower(plr.Name)
                if string.sub(name, 1, 1) == settings.TargetLetter then
                    return plr
                end
            end
        end
        return nil
    end
end

local function setupNoclip(state)
    for _, conn in pairs(noclipConnections) do
        conn:Disconnect()
    end
    noclipConnections = {}

    if not state then
        if player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        return
    end

    local function setCollision(part)
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    if player.Character then
        for _, part in pairs(player.Character:GetDescendants()) do
            setCollision(part)
        end
        local conn = player.Character.DescendantAdded:Connect(setCollision)
        table.insert(noclipConnections, conn)
    end

    local charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        for _, part in pairs(char:GetDescendants()) do
            setCollision(part)
        end
        local conn = char.DescendantAdded:Connect(setCollision)
        table.insert(noclipConnections, conn)
    end)
    table.insert(noclipConnections, charConn)
end

local function startStrafe()
    if isStrafing then return end
    isStrafing = true

    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    if settings.Method == "WalkSpeed" then
        humanoid.WalkSpeed = settings.Speed
    end

    setupNoclip(true)

    local angle = 0
    local bodyVelocity = nil
    if settings.Method == "BodyVelocity" then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(1e4, 1e4, 1e4)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
    end

    strafeLoop = runService.Heartbeat:Connect(function()
        if not settings.Enabled then
            stopStrafe()
            return
        end

        local target = getStrafeTarget()
        if target and target.Character then
            local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local dist = settings.Distance
                local speed = settings.RotationSpeed
                angle = angle + speed * runService.Heartbeat:Wait()
                local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                local targetPos = targetRoot.Position + offset

                if settings.Method == "WalkSpeed" then
                    humanoid:MoveTo(targetPos)
                elseif settings.Method == "BodyVelocity" and bodyVelocity then
                    local direction = (targetPos - rootPart.Position).Unit
                    bodyVelocity.Velocity = direction * settings.Speed
                end

                local lookAt = targetRoot.Position - rootPart.Position
                lookAt = Vector3.new(lookAt.X, 0, lookAt.Z)
                if lookAt.Magnitude > 0.5 then
                    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookAt)
                end
            end
        end
    end)
end

local function stopStrafe()
    isStrafing = false
    if strafeLoop then
        strafeLoop:Disconnect()
        strafeLoop = nil
    end
    setupNoclip(false)
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
        end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local bv = rootPart:FindFirstChildOfClass("BodyVelocity")
            if bv then bv:Destroy() end
        end
    end
end

local function unInject()
    if not isInjected then return end
    isInjected = false
    stopStrafe()
    setupNoclip(false)
    for _, conn in pairs(noclipConnections) do
        conn:Disconnect()
    end
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
    print("Target Strafe выгружен.")
end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "StrafeGUI"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 360)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -180)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Visible = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local blur = Instance.new("BlurEffect")
blur.Size = 12
blur.Parent = mainFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 10, 1, 10)
shadow.Position = UDim2.new(0, -5, 0, -5)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.8
shadow.BorderSizePixel = 0
shadow.ZIndex = 0
shadow.Parent = mainFrame
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 14)
shadowCorner.Parent = shadow

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Text = "Target Strafe"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local unInjectBtn = Instance.new("TextButton")
unInjectBtn.Size = UDim2.new(0, 25, 0, 25)
unInjectBtn.Position = UDim2.new(1, -30, 0, 5)
unInjectBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
unInjectBtn.BorderSizePixel = 0
unInjectBtn.Text = ""
unInjectBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
unInjectBtn.TextScaled = true
unInjectBtn.Font = Enum.Font.SourceSansBold
unInjectBtn.Parent = mainFrame
local unInjectCorner = Instance.new("UICorner")
unInjectCorner.CornerRadius = UDim.new(1, 0)
unInjectCorner.Parent = unInjectBtn
unInjectBtn.MouseButton1Click:Connect(function()
    unInject()
end)

local function createToggle(yPos, labelText, settingKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 28)
    frame.Position = UDim2.new(0, 10, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = mainFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSansItalic
    label.TextSize = 14
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 22)
    btn.Position = UDim2.new(0.75, 0, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.BorderSizePixel = 0
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextScaled = true
    btn.Font = Enum.Font.SourceSansItalic
    btn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        settings[settingKey] = not settings[settingKey]
        btn.BackgroundColor3 = settings[settingKey] and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(60, 60, 60)
        btn.TextColor3 = settings[settingKey] and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
        btn.Text = settings[settingKey] and "ON" or "OFF"
        if settingKey == "Enabled" then
            if settings.Enabled then
                startStrafe()
            else
                stopStrafe()
            end
        end
    end)
end

local function createDropdown(yPos, labelText, options, settingKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 28)
    frame.Position = UDim2.new(0, 10, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = mainFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSansItalic
    label.TextSize = 14
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.35, 0, 1, -4)
    btn.Position = UDim2.new(0.65, 0, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.Text = tostring(settings[settingKey])
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Font = Enum.Font.SourceSansItalic
    btn.Parent = frame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local currentIndex = 1
    for i, opt in ipairs(options) do
        if opt == settings[settingKey] then
            currentIndex = i
            break
        end
    end
    btn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex % #options + 1
        settings[settingKey] = options[currentIndex]
        btn.Text = tostring(options[currentIndex])
        if settings.Enabled then
            stopStrafe()
            task.wait(0.1)
            startStrafe()
        end
    end)
end

local function createSlider(yPos, labelText, settingKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 36)
    frame.Position = UDim2.new(0, 10, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = mainFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 0.5, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.SourceSansItalic
    label.TextSize = 13
    label.Parent = frame

    local slider = Instance.new("TextBox")
    slider.Size = UDim2.new(0.8, 0, 0.4, 0)
    slider.Position = UDim2.new(0.1, 0, 0.5, 0)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    slider.BorderSizePixel = 0
    slider.Text = tostring(settings[settingKey])
    slider.TextColor3 = Color3.fromRGB(255, 255, 255)
    slider.Font = Enum.Font.SourceSansItalic
    slider.TextSize = 13
    slider.ClearTextOnFocus = false
    slider.Parent = frame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = slider

    slider.FocusLost:Connect(function()
        local num = tonumber(slider.Text)
        if num then
            settings[settingKey] = num
            slider.Text = tostring(num)
            if settings.Enabled then
                stopStrafe()
                task.wait(0.1)
                startStrafe()
            end
        else
            slider.Text = tostring(settings[settingKey])
        end
    end)
end

local y = 40
createToggle(y, "Enable", "Enabled"); y = y + 35
createDropdown(y, "Method", {"WalkSpeed", "BodyVelocity"}, "Method"); y = y + 35
createSlider(y, "Distance", "Distance"); y = y + 45
createSlider(y, "Speed", "Speed"); y = y + 45
createSlider(y, "Rotation Speed", "RotationSpeed"); y = y + 45

local modeFrame = Instance.new("Frame")
modeFrame.Size = UDim2.new(1, -20, 0, 30)
modeFrame.Position = UDim2.new(0, 10, 0, y)
modeFrame.BackgroundTransparency = 1
modeFrame.Parent = mainFrame

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(0.6, 0, 1, 0)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Mode: Nearest"
modeLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Font = Enum.Font.SourceSansItalic
modeLabel.TextSize = 14
modeLabel.Parent = modeFrame

local modeBtn = Instance.new("TextButton")
modeBtn.Size = UDim2.new(0.3, 0, 1, -4)
modeBtn.Position = UDim2.new(0.7, 0, 0, 2)
modeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
modeBtn.BorderSizePixel = 0
modeBtn.Text = "Nearest"
modeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
modeBtn.TextScaled = true
modeBtn.Font = Enum.Font.SourceSansItalic
modeBtn.Parent = modeFrame
local modeCorner = Instance.new("UICorner")
modeCorner.CornerRadius = UDim.new(0, 4)
modeCorner.Parent = modeBtn
modeBtn.MouseButton1Click:Connect(function()
    if settings.Mode == "Nearest" then
        settings.Mode = "Target"
        modeBtn.Text = "Target"
        modeLabel.Text = "Mode: Target (enter letter)"
    else
        settings.Mode = "Nearest"
        modeBtn.Text = "Nearest"
        modeLabel.Text = "Mode: Nearest"
    end
    if settings.Enabled then
        stopStrafe()
        task.wait(0.1)
        startStrafe()
    end
end)
y = y + 35

local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -20, 0, 30)
inputFrame.Position = UDim2.new(0, 10, 0, y)
inputFrame.BackgroundTransparency = 1
inputFrame.Parent = mainFrame

local targetInput = Instance.new("TextBox")
targetInput.Size = UDim2.new(0.6, 0, 1, 0)
targetInput.Position = UDim2.new(0.2, 0, 0, 0)
targetInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
targetInput.BorderSizePixel = 0
targetInput.PlaceholderText = "First letter..."
targetInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
targetInput.Text = ""
targetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
targetInput.Font = Enum.Font.SourceSansItalic
targetInput.TextSize = 14
targetInput.ClearTextOnFocus = true
targetInput.Parent = inputFrame
local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 4)
inputCorner.Parent = targetInput
targetInput:GetPropertyChangedSignal("Text"):Connect(function()
    if #targetInput.Text > 0 then
        settings.TargetLetter = string.sub(targetInput.Text, 1, 1):lower()
    else
        settings.TargetLetter = ""
    end
    if settings.Enabled then
        stopStrafe()
        task.wait(0.1)
        startStrafe()
    end
end)

y = y + 35
mainFrame.Size = UDim2.new(0, 300, 0, y + 10)

local particles = Instance.new("Frame")
particles.Size = UDim2.new(1, 0, 1, 0)
particles.BackgroundTransparency = 1
particles.Parent = mainFrame

for i = 1, 20 do
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 2, 0, 2)
    dot.Position = UDim2.new(math.random(), 0, math.random(), 0)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BackgroundTransparency = 0.7
    dot.BorderSizePixel = 0
    dot.Parent = particles
    local cornerDot = Instance.new("UICorner")
    cornerDot.CornerRadius = UDim.new(1, 0)
    cornerDot.Parent = dot

    game:GetService("RunService").Heartbeat:Connect(function()
        local pos = dot.Position
        local x = pos.X.Scale + 0.001 * math.sin(os.clock() + i)
        local y = pos.Y.Scale + 0.001 * math.cos(os.clock() + i * 1.3)
        dot.Position = UDim2.new(x % 1, 0, y % 1, 0)
    end)
end

userInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightAlt and isInjected then
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            mainFrame.Position = UDim2.new(0.5, -150, 0.5, -(mainFrame.Size.Y.Offset / 2))
        end
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if settings.Enabled and isInjected then
        startStrafe()
    end
end)

player:GetPropertyChangedSignal("Character"):Connect(function()
    if not player.Character and isInjected then
        stopStrafe()
    end
end)
