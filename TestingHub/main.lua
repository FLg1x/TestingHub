local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

-- tuff

local settings = {
    AimbotEnabled = false,
    SilentAim = false,
    VisibleCheck = false,
    FOVRadius = 120,
    Smoothness = 5,
    ESPEnabled = false,
    ESPBoxes = false,
    ESPHealth = false,
    ESPNames = false,
    ESPDistance = false,
    ESPTracers = false,
    ESPMaxDistance = 200,
    StrafeEnabled = false,
    StrafeDistance = 5,
    StrafeSpeed = 16,
    StrafeRotation = 2,
    StrafeMode = "Nearest",
    StrafeTarget = ""
}

local espObjects = {}
local aimbotTarget = nil
local strafeLoop = nil
local isStrafing = false

local function isVisible(targetPart)
    if not targetPart then return false end
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    local result = workspace:Raycast(origin, direction * 500, raycastParams)
    if result then
        local hit = result.Instance
        if hit:IsDescendantOf(targetPart.Parent) then
            return true
        end
    end
    return false
end

local function getScreenPosition(targetPart)
    if not targetPart then return nil end
    local screenPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

local function getClosestPlayer()
    local character = player.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local closest, closestDist = nil, math.huge
    local mousePos = Vector2.new(mouse.X, mouse.Y)

    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local screenPos = getScreenPosition(targetRoot)
                if screenPos then
                    local dist = (mousePos - screenPos).Magnitude
                    if dist < settings.FOVRadius and dist < closestDist then
                        closestDist = dist
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function updateAimbot()
    if not settings.AimbotEnabled then
        aimbotTarget = nil
        return
    end

    local target = getClosestPlayer()
    if target then
        aimbotTarget = target
        local targetPart = target.Character:FindFirstChild("Head")
        if targetPart and (not settings.VisibleCheck or isVisible(targetPart)) then
            local screenPos = getScreenPosition(targetPart)
            if screenPos then
                local mousePos = Vector2.new(mouse.X, mouse.Y)
                local newPos = mousePos:Lerp(screenPos, settings.Smoothness / 10)
                mousemoverel(newPos.X - mouse.X, newPos.Y - mouse.Y)
            end
        end
    else
        aimbotTarget = nil
    end
end

local function createESP(plr)
    if not plr or not plr.Character then return end
    if espObjects[plr] then return end

    local character = plr.Character
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Parent = character

    espObjects[plr] = highlight
end

local function removeESP(plr)
    if espObjects[plr] then
        espObjects[plr]:Destroy()
        espObjects[plr] = nil
    end
end

local function updateESP()
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= player then
            if settings.ESPEnabled then
                createESP(plr)
            else
                removeESP(plr)
            end
        end
    end
end

local function getStrafeTarget()
    if settings.StrafeMode == "Nearest" then
        local nearest, minDist = nil, math.huge
        local character = player.Character
        if not character then return nil end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return nil end

        for _, plr in pairs(game.Players:GetPlayers()) do
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
        if settings.StrafeTarget == "" then return nil end
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local name = string.lower(plr.Name)
                if string.sub(name, 1, 1) == settings.StrafeTarget then
                    return plr
                end
            end
        end
        return nil
    end
end

local function startStrafe()
    if isStrafing then return end
    isStrafing = true

    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    humanoid.WalkSpeed = settings.StrafeSpeed

    strafeLoop = runService.Heartbeat:Connect(function()
        if not settings.StrafeEnabled then
            stopStrafe()
            return
        end

        local target = getStrafeTarget()
        if target and target.Character then
            local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local direction = (rootPart.Position - targetRoot.Position).Unit
                local cross = Vector3.new(-direction.Z, 0, direction.X)
                local targetPos = targetRoot.Position + (direction * settings.StrafeDistance) + (cross * 3 * math.sin(os.clock() * settings.StrafeRotation))
                targetPos = targetRoot.Position + (targetPos - targetRoot.Position).Unit * settings.StrafeDistance

                local moveDirection = (targetPos - rootPart.Position).Unit
                humanoid:MoveTo(rootPart.Position + moveDirection * 10)

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
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FokiHubGUI"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 450, 0, 550)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -275)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local shadowFrame = Instance.new("Frame")
shadowFrame.Size = UDim2.new(1, 12, 1, 12)
shadowFrame.Position = UDim2.new(0, -6, 0, -6)
shadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadowFrame.BackgroundTransparency = 0.6
shadowFrame.BorderSizePixel = 0
shadowFrame.ZIndex = 0
shadowFrame.Parent = mainFrame

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 12)
shadowCorner.Parent = shadowFrame

mainFrame.ZIndex = 1

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 45)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 2
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FOKI HUB 3.9"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.PlayfairDisplay
title.FontStyle = Enum.FontStyle.Italic
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.PlayfairDisplay
closeBtn.FontStyle = Enum.FontStyle.Italic
closeBtn.ZIndex = 3
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 45)
tabContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
tabContainer.BorderSizePixel = 0
tabContainer.ZIndex = 2
tabContainer.Parent = mainFrame

local tabs = {"Aimbot", "Visuals", "Movement"}
local tabButtons = {}
local tabFrames = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, -2, 1, -4)
    btn.Position = UDim2.new((i - 1) / #tabs, 1, 0, 2)
    btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(70, 70, 200) or Color3.fromRGB(45, 45, 65)
    btn.BorderSizePixel = 0
    btn.Text = tabName
    btn.TextColor3 = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    btn.TextScaled = true
    btn.Font = Enum.Font.PlayfairDisplay
    btn.FontStyle = Enum.FontStyle.Italic
    btn.ZIndex = 3
    btn.Parent = tabContainer

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    tabButtons[i] = btn

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 1, -60)
    frame.Position = UDim2.new(0, 10, 0, 90)
    frame.BackgroundTransparency = 1
    frame.Visible = (i == 1)
    frame.ZIndex = 2
    frame.Parent = mainFrame
    tabFrames[i] = frame

    btn.MouseButton1Click:Connect(function()
        for j, f in ipairs(tabFrames) do
            f.Visible = (j == i)
        end
        for j, b in ipairs(tabButtons) do
            b.BackgroundColor3 = (j == i) and Color3.fromRGB(70, 70, 200) or Color3.fromRGB(45, 45, 65)
            b.TextColor3 = (j == i) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
        end
    end)
end

local function createToggle(parent, yPos, labelText, settingKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.ZIndex = 3
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.PlayfairDisplay
    label.FontStyle = Enum.FontStyle.Italic
    label.TextSize = 15
    label.ZIndex = 4
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 22)
    btn.Position = UDim2.new(0.85, 0, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    btn.BorderSizePixel = 0
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextScaled = true
    btn.Font = Enum.Font.PlayfairDisplay
    btn.FontStyle = Enum.FontStyle.Italic
    btn.ZIndex = 4
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        settings[settingKey] = not settings[settingKey]
        btn.BackgroundColor3 = settings[settingKey] and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(60, 60, 80)
        btn.Text = settings[settingKey] and "ON" or "OFF"
        if settingKey == "StrafeEnabled" then
            if settings.StrafeEnabled then
                startStrafe()
            else
                stopStrafe()
            end
        end
    end)

    return btn
end

local function createSlider(parent, yPos, labelText, minVal, maxVal, settingKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.Position = UDim2.new(0, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.ZIndex = 3
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0.5, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.PlayfairDisplay
    label.FontStyle = Enum.FontStyle.Italic
    label.TextSize = 14
    label.ZIndex = 4
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(settings[settingKey])
    valueLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Font = Enum.Font.PlayfairDisplay
    valueLabel.FontStyle = Enum.FontStyle.Italic
    valueLabel.TextSize = 14
    valueLabel.ZIndex = 4
    valueLabel.Parent = frame

    local slider = Instance.new("TextBox")
    slider.Size = UDim2.new(0.8, 0, 0.4, 0)
    slider.Position = UDim2.new(0.1, 0, 0.5, 0)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    slider.BorderSizePixel = 0
    slider.Text = tostring(settings[settingKey])
    slider.TextColor3 = Color3.fromRGB(255, 255, 255)
    slider.Font = Enum.Font.PlayfairDisplay
    slider.FontStyle = Enum.FontStyle.Italic
    slider.TextSize = 14
    slider.ClearTextOnFocus = false
    slider.ZIndex = 4
    slider.Parent = frame

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = slider

    slider.FocusLost:Connect(function()
        local num = tonumber(slider.Text)
        if num then
            num = math.clamp(num, minVal, maxVal)
            settings[settingKey] = num
            valueLabel.Text = tostring(num)
            slider.Text = tostring(num)
            if settingKey == "StrafeDistance" or settingKey == "StrafeSpeed" or settingKey == "StrafeRotation" then
                if settings.StrafeEnabled then
                    stopStrafe()
                    task.wait(0.1)
                    startStrafe()
                end
            end
        else
            slider.Text = tostring(settings[settingKey])
        end
    end)

    return slider
end

local aimbotFrame = tabFrames[1]

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 220)
scrollingFrame.ScrollBarThickness = 5
scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 100)
scrollingFrame.ZIndex = 3
scrollingFrame.Parent = aimbotFrame

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 0, 220)
content.BackgroundTransparency = 1
content.ZIndex = 3
content.Parent = scrollingFrame

createToggle(content, 5, "Enable Aimbot", "AimbotEnabled")
createToggle(content, 40, "Silent Aim", "SilentAim")
createToggle(content, 75, "Visible Check", "VisibleCheck")
createSlider(content, 115, "FOV Radius", 0, 360, "FOVRadius")
createSlider(content, 160, "Smoothness", 1, 20, "Smoothness")

local visualsFrame = tabFrames[2]

local scrollingFrame2 = Instance.new("ScrollingFrame")
scrollingFrame2.Size = UDim2.new(1, 0, 1, 0)
scrollingFrame2.BackgroundTransparency = 1
scrollingFrame2.CanvasSize = UDim2.new(0, 0, 0, 280)
scrollingFrame2.ScrollBarThickness = 5
scrollingFrame2.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 100)
scrollingFrame2.ZIndex = 3
scrollingFrame2.Parent = visualsFrame

local content2 = Instance.new("Frame")
content2.Size = UDim2.new(1, 0, 0, 280)
content2.BackgroundTransparency = 1
content2.ZIndex = 3
content2.Parent = scrollingFrame2

createToggle(content2, 5, "Enable ESP", "ESPEnabled")
createToggle(content2, 40, "Boxes", "ESPBoxes")
createToggle(content2, 75, "Health Bar", "ESPHealth")
createToggle(content2, 110, "Name Tags", "ESPNames")
createToggle(content2, 145, "Distance", "ESPDistance")
createToggle(content2, 180, "Tracers", "ESPTracers")
createSlider(content2, 220, "Max Distance", 50, 500, "ESPMaxDistance")

local movementFrame = tabFrames[3]

local scrollingFrame3 = Instance.new("ScrollingFrame")
scrollingFrame3.Size = UDim2.new(1, 0, 1, 0)
scrollingFrame3.BackgroundTransparency = 1
scrollingFrame3.CanvasSize = UDim2.new(0, 0, 0, 280)
scrollingFrame3.ScrollBarThickness = 5
scrollingFrame3.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 100)
scrollingFrame3.ZIndex = 3
scrollingFrame3.Parent = movementFrame

local content3 = Instance.new("Frame")
content3.Size = UDim2.new(1, 0, 0, 280)
content3.BackgroundTransparency = 1
content3.ZIndex = 3
content3.Parent = scrollingFrame3

createToggle(content3, 5, "Enable Target Strafe", "StrafeEnabled")
createSlider(content3, 45, "Distance", 1, 20, "StrafeDistance")
createSlider(content3, 90, "Speed", 10, 40, "StrafeSpeed")
createSlider(content3, 135, "Rotation Speed", 1, 5, "StrafeRotation")

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(0.6, 0, 0, 25)
modeLabel.Position = UDim2.new(0, 0, 0, 180)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Mode: Nearest"
modeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Font = Enum.Font.PlayfairDisplay
modeLabel.FontStyle = Enum.FontStyle.Italic
modeLabel.TextSize = 14
modeLabel.ZIndex = 4
modeLabel.Parent = content3

local modeBtn = Instance.new("TextButton")
modeBtn.Size = UDim2.new(0.25, 0, 0, 25)
modeBtn.Position = UDim2.new(0.7, 0, 0, 180)
modeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 200)
modeBtn.BorderSizePixel = 0
modeBtn.Text = "Nearest"
modeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
modeBtn.TextScaled = true
modeBtn.Font = Enum.Font.PlayfairDisplay
modeBtn.FontStyle = Enum.FontStyle.Italic
modeBtn.ZIndex = 4
modeBtn.Parent = content3

local modeCorner = Instance.new("UICorner")
modeCorner.CornerRadius = UDim.new(0, 4)
modeCorner.Parent = modeBtn

modeBtn.MouseButton1Click:Connect(function()
    if settings.StrafeMode == "Nearest" then
        settings.StrafeMode = "Target"
        modeBtn.Text = "Target"
        modeLabel.Text = "Mode: Target (enter letter)"
    else
        settings.StrafeMode = "Nearest"
        modeBtn.Text = "Nearest"
        modeLabel.Text = "Mode: Nearest"
    end
    if settings.StrafeEnabled then
        stopStrafe()
        task.wait(0.1)
        startStrafe()
    end
end)

local targetInput = Instance.new("TextBox")
targetInput.Size = UDim2.new(0.5, 0, 0, 25)
targetInput.Position = UDim2.new(0.25, 0, 0, 215)
targetInput.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
targetInput.BorderSizePixel = 0
targetInput.PlaceholderText = "First letter of name..."
targetInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
targetInput.Text = ""
targetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
targetInput.Font = Enum.Font.PlayfairDisplay
targetInput.FontStyle = Enum.FontStyle.Italic
targetInput.TextSize = 14
targetInput.ClearTextOnFocus = true
targetInput.ZIndex = 4
targetInput.Parent = content3

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 4)
inputCorner.Parent = targetInput

targetInput:GetPropertyChangedSignal("Text"):Connect(function()
    if #targetInput.Text > 0 then
        settings.StrafeTarget = string.sub(targetInput.Text, 1, 1):lower()
    else
        settings.StrafeTarget = ""
    end
    if settings.StrafeEnabled then
        stopStrafe()
        task.wait(0.1)
        startStrafe()
    end
end)

-- tuff

runService.Heartbeat:Connect(function()
    updateAimbot()
    updateESP()
end)

userInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            mainFrame.Position = UDim2.new(0.5, -225, 0.5, -275)
        end
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if settings.StrafeEnabled then
        startStrafe()
    end
end)
