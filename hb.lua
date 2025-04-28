local proximityRange = 15
local detectionRadius = 15
local localPlayer = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local isCurrentlyBlocking = false
local lastBlockTime = 0
local blockCooldown = 0.3
local lastAnimationTime = 0
local animationSpamThreshold = 0.7
local currentTarget = nil
local autoRotationEnabled = true
-- Added toggle for Auto Block
local autoBlockEnabled = true
-- Keybind for toggling Auto Block
local autoBlockKeybind = Enum.KeyCode.X -- Default keybind
-- Keybind for toggling auto-rotation
local autoRotationKeybind = Enum.KeyCode.R -- Default keybind

-- UI Theme Colors
local THEME = {
    BACKGROUND = Color3.fromRGB(20, 20, 30),
    BACKGROUND_TRANSLUCENT = Color3.fromRGB(20, 20, 30),
    TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
    TEXT_SECONDARY = Color3.fromRGB(180, 180, 200),
    ACCENT_PRIMARY = Color3.fromRGB(50, 120, 255),
    ACCENT_SECONDARY = Color3.fromRGB(100, 80, 200),
    DANGER = Color3.fromRGB(255, 70, 70),
    SUCCESS = Color3.fromRGB(70, 200, 120),
    WARNING = Color3.fromRGB(255, 180, 30),
    NEUTRAL = Color3.fromRGB(100, 100, 120)
}

local animationBlacklist = {
    "Hurt1",
    "Hurt2",
    "Hurt3",
    "Hurt4",
    "Hurt"
}

local animationIdBlacklist = {
    "rbxassetid://13076773226", 
    "13076773226",
    "rbxassetid://15270388721", 
    "15270388721",
    "rbxassetid://13076726811", 
    "13076726811",
    "rbxassetid://180435571", 
    "180435571",
    "rbxassetid://15270390518", 
    "15270390518",
    "rbxassetid://15270391503", 
    "15270391503",
    "rbxassetid://15270302190",
    "15270302190"
}

local debugMode = false
local showAllAnimations = false
local function debugPrint(...)
    if debugMode then
    end
end

local function safely(func)
    return function(...)
        if type(func) ~= "function" then
            return false
        end
        local success, result = pcall(func, ...)
        return success, result
    end
end

-- UI Creation Functions
local function createUICorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function createUIStroke(parent, thickness, color)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Color = color or THEME.ACCENT_PRIMARY
    stroke.Transparency = 0.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function createShadow(parent)
    local shadow = Instance.new("ImageLabel")
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.ZIndex = parent.ZIndex - 1
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Parent = parent
    return shadow
end

-- Create detection mark using a part with a special orientation for a proper circle
local detectionMark = Instance.new("Part")
detectionMark.Size = Vector3.new(0.1, detectionRadius * 2, detectionRadius * 2) 
detectionMark.Anchored = true
detectionMark.CanCollide = false
detectionMark.Transparency = 0.5
detectionMark.BrickColor = BrickColor.new("Lime green")
detectionMark.Shape = Enum.PartType.Cylinder
detectionMark.Material = Enum.Material.Neon
-- Properly orient the cylinder to be flat on the ground
local position = character.HumanoidRootPart.Position - Vector3.new(0, 2.95, 0)
-- The correct rotation to make a cylinder lay flat on the ground
detectionMark.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
detectionMark.Parent = workspace

-- Add an outer ring with proper orientation
local outerRing = Instance.new("Part")
outerRing.Size = Vector3.new(0.1, detectionRadius * 2 + 0.2, detectionRadius * 2 + 0.2)
outerRing.Anchored = true
outerRing.CanCollide = false
outerRing.Transparency = 0.4
outerRing.BrickColor = BrickColor.new("Electric blue")
outerRing.Shape = Enum.PartType.Cylinder
outerRing.Material = Enum.Material.Neon
-- Same correct rotation to make a cylinder lay flat
outerRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
outerRing.Parent = workspace

-- Create Main UI
local screenGui = localPlayer.PlayerGui:FindFirstChild("AutoBlockGui") or Instance.new("ScreenGui")
screenGui.Name = "AutoBlockGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer.PlayerGui

-- Create main container frame
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, 300, 0, 420) -- Increased height for new controls
mainContainer.Position = UDim2.new(1, -320, 0.5, -210) -- Adjusted position for new height
mainContainer.BackgroundColor3 = THEME.BACKGROUND
mainContainer.BackgroundTransparency = 0.3
mainContainer.BorderSizePixel = 0
mainContainer.ZIndex = 10
mainContainer.Parent = screenGui
createUICorner(mainContainer, 12)
createUIStroke(mainContainer, 1, THEME.ACCENT_PRIMARY)
createShadow(mainContainer)

-- Create title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = THEME.ACCENT_PRIMARY
titleBar.BackgroundTransparency = 0.6
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 11
titleBar.Parent = mainContainer
createUICorner(titleBar, 12)

-- Create title text
local titleText = Instance.new("TextLabel")
titleText.Name = "Title"
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "AUTO-BLOCK SYSTEM"
titleText.TextColor3 = THEME.TEXT_PRIMARY
titleText.TextSize = 18
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.ZIndex = 12
titleText.Parent = titleBar

-- Create minimize button
local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -35, 0, 5)
minimizeButton.BackgroundColor3 = THEME.BACKGROUND
minimizeButton.BackgroundTransparency = 0.5
minimizeButton.Text = "−"
minimizeButton.TextColor3 = THEME.TEXT_PRIMARY
minimizeButton.TextSize = 20
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.ZIndex = 12
minimizeButton.Parent = titleBar
createUICorner(minimizeButton, 6)

-- Help button (moved position to avoid conflict)
local helpButton = Instance.new("TextButton")
helpButton.Name = "HelpButton"
helpButton.Size = UDim2.new(0, 30, 0, 30)
helpButton.Position = UDim2.new(1, -70, 0, 5) -- Moved to the left of minimize button
helpButton.BackgroundColor3 = THEME.NEUTRAL
helpButton.BackgroundTransparency = 0.5
helpButton.Text = "?"
helpButton.TextColor3 = THEME.TEXT_PRIMARY
helpButton.TextSize = 18
helpButton.Font = Enum.Font.GothamBold
helpButton.ZIndex = 12
helpButton.Parent = titleBar
createUICorner(helpButton, 15)

-- Create content container
local contentContainer = Instance.new("Frame")
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, -20, 1, -50)
contentContainer.Position = UDim2.new(0, 10, 0, 45)
contentContainer.BackgroundTransparency = 1
contentContainer.ZIndex = 11
contentContainer.Parent = mainContainer

-- Status display section
local statusSection = Instance.new("Frame")
statusSection.Name = "StatusSection"
statusSection.Size = UDim2.new(1, 0, 0, 100)
statusSection.BackgroundTransparency = 1
statusSection.ZIndex = 12
statusSection.Parent = contentContainer

-- Block status indicator
local blockStatusContainer = Instance.new("Frame")
blockStatusContainer.Name = "BlockStatusContainer"
blockStatusContainer.Size = UDim2.new(1, 0, 0, 40)
blockStatusContainer.BackgroundColor3 = THEME.BACKGROUND
blockStatusContainer.BackgroundTransparency = 0.5
blockStatusContainer.ZIndex = 13
blockStatusContainer.Parent = statusSection
createUICorner(blockStatusContainer, 8)
createUIStroke(blockStatusContainer, 1, THEME.NEUTRAL)

local blockStatusIcon = Instance.new("Frame")
blockStatusIcon.Name = "StatusIcon"
blockStatusIcon.Size = UDim2.new(0, 16, 0, 16)
blockStatusIcon.Position = UDim2.new(0, 12, 0.5, -8)
blockStatusIcon.BackgroundColor3 = THEME.NEUTRAL
blockStatusIcon.BorderSizePixel = 0
blockStatusIcon.ZIndex = 14
blockStatusIcon.Parent = blockStatusContainer
createUICorner(blockStatusIcon, 8)

local blockIndicator = Instance.new("TextLabel")
blockIndicator.Name = "BlockStatus"
blockIndicator.Size = UDim2.new(1, -140, 1, 0)
blockIndicator.Position = UDim2.new(0, 40, 0, 0)
blockIndicator.BackgroundTransparency = 1
blockIndicator.TextColor3 = THEME.TEXT_PRIMARY
blockIndicator.TextSize = 16
blockIndicator.Font = Enum.Font.GothamSemibold
blockIndicator.Text = "AUTO-BLOCK: READY"
blockIndicator.TextXAlignment = Enum.TextXAlignment.Left
blockIndicator.ZIndex = 14
blockIndicator.Parent = blockStatusContainer

-- Toggle switch for Auto Block
local toggleSwitch = Instance.new("TextButton")
toggleSwitch.Name = "ToggleSwitch"
toggleSwitch.Size = UDim2.new(0, 45, 0, 24)
toggleSwitch.Position = UDim2.new(1, -55, 0.5, -12)
toggleSwitch.BackgroundColor3 = THEME.SUCCESS -- Green for ON
toggleSwitch.BorderSizePixel = 0
toggleSwitch.Text = ""
toggleSwitch.ZIndex = 14
toggleSwitch.Parent = blockStatusContainer
createUICorner(toggleSwitch, 12)

local toggleIndicator = Instance.new("Frame")
toggleIndicator.Name = "ToggleIndicator"
toggleIndicator.Size = UDim2.new(0, 18, 0, 18)
toggleIndicator.Position = UDim2.new(1, -21, 0.5, -9)
toggleIndicator.BackgroundColor3 = THEME.TEXT_PRIMARY
toggleIndicator.BorderSizePixel = 0
toggleIndicator.ZIndex = 15
toggleIndicator.Parent = toggleSwitch
createUICorner(toggleIndicator, 9)

-- Target status indicator
local targetStatusContainer = Instance.new("Frame")
targetStatusContainer.Name = "TargetStatusContainer"
targetStatusContainer.Size = UDim2.new(1, 0, 0, 40)
targetStatusContainer.Position = UDim2.new(0, 0, 0, 50)
targetStatusContainer.BackgroundColor3 = THEME.BACKGROUND
targetStatusContainer.BackgroundTransparency = 0.5
targetStatusContainer.ZIndex = 13
targetStatusContainer.Parent = statusSection
createUICorner(targetStatusContainer, 8)
createUIStroke(targetStatusContainer, 1, THEME.NEUTRAL)

local targetIcon = Instance.new("Frame")
targetIcon.Name = "TargetIcon"
targetIcon.Size = UDim2.new(0, 16, 0, 16)
targetIcon.Position = UDim2.new(0, 12, 0.5, -8)
targetIcon.BackgroundColor3 = THEME.WARNING
targetIcon.BorderSizePixel = 0
targetIcon.ZIndex = 14
targetIcon.Parent = targetStatusContainer
createUICorner(targetIcon, 8)

local targetIndicator = Instance.new("TextLabel")
targetIndicator.Name = "TargetStatus"
targetIndicator.Size = UDim2.new(1, -45, 1, 0)
targetIndicator.Position = UDim2.new(0, 40, 0, 0)
targetIndicator.BackgroundTransparency = 1
targetIndicator.TextColor3 = THEME.WARNING
targetIndicator.TextSize = 16
targetIndicator.Font = Enum.Font.GothamSemibold
targetIndicator.Text = "NO TARGET"
targetIndicator.TextXAlignment = Enum.TextXAlignment.Left
targetIndicator.ZIndex = 14
targetIndicator.Parent = targetStatusContainer

-- New section for settings
local settingsSection = Instance.new("Frame")
settingsSection.Name = "SettingsSection"
settingsSection.Size = UDim2.new(1, 0, 0, 80)
settingsSection.Position = UDim2.new(0, 0, 0, 110)
settingsSection.BackgroundTransparency = 1
settingsSection.ZIndex = 12
settingsSection.Parent = contentContainer

local settingsHeader = Instance.new("TextLabel")
settingsHeader.Name = "SettingsHeader"
settingsHeader.Size = UDim2.new(1, 0, 0, 25)
settingsHeader.BackgroundTransparency = 1
settingsHeader.TextColor3 = THEME.TEXT_SECONDARY
settingsHeader.TextSize = 14
settingsHeader.Font = Enum.Font.GothamMedium
settingsHeader.Text = "SETTINGS"
settingsHeader.TextXAlignment = Enum.TextXAlignment.Left
settingsHeader.ZIndex = 13
settingsHeader.Parent = settingsSection

-- Radius slider
local radiusContainer = Instance.new("Frame")
radiusContainer.Name = "RadiusContainer"
radiusContainer.Size = UDim2.new(1, 0, 0, 25)
radiusContainer.Position = UDim2.new(0, 0, 0, 25)
radiusContainer.BackgroundTransparency = 1
radiusContainer.ZIndex = 13
radiusContainer.Parent = settingsSection

local radiusLabel = Instance.new("TextLabel")
radiusLabel.Name = "RadiusLabel"
radiusLabel.Size = UDim2.new(0, 120, 1, 0)
radiusLabel.BackgroundTransparency = 1
radiusLabel.TextColor3 = THEME.TEXT_SECONDARY
radiusLabel.TextSize = 14
radiusLabel.Font = Enum.Font.Gotham
radiusLabel.Text = "Detection Radius:"
radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
radiusLabel.ZIndex = 14
radiusLabel.Parent = radiusContainer

local radiusSlider = Instance.new("Frame")
radiusSlider.Name = "RadiusSlider"
radiusSlider.Size = UDim2.new(0, 120, 0, 6)
radiusSlider.Position = UDim2.new(0, 125, 0.5, -3)
radiusSlider.BackgroundColor3 = THEME.NEUTRAL
radiusSlider.BorderSizePixel = 0
radiusSlider.ZIndex = 14
radiusSlider.Parent = radiusContainer
createUICorner(radiusSlider, 3)

local radiusHandle = Instance.new("TextButton")
radiusHandle.Name = "RadiusHandle"
radiusHandle.Size = UDim2.new(0, 16, 0, 16)
radiusHandle.Position = UDim2.new(0.5, -8, 0.5, -8)
radiusHandle.BackgroundColor3 = THEME.ACCENT_PRIMARY
radiusHandle.BorderSizePixel = 0
radiusHandle.Text = ""
radiusHandle.ZIndex = 15
radiusHandle.Parent = radiusSlider
createUICorner(radiusHandle, 8)

local radiusValue = Instance.new("TextLabel")
radiusValue.Name = "RadiusValue"
radiusValue.Size = UDim2.new(0, 40, 1, 0)
radiusValue.Position = UDim2.new(1, -40, 0, 0)
radiusValue.BackgroundTransparency = 1
radiusValue.TextColor3 = THEME.TEXT_PRIMARY
radiusValue.TextSize = 14
radiusValue.Font = Enum.Font.GothamSemibold
radiusValue.Text = "15"
radiusValue.TextXAlignment = Enum.TextXAlignment.Right
radiusValue.ZIndex = 14
radiusValue.Parent = radiusContainer

-- Keybind buttons
local keybindContainer = Instance.new("Frame")
keybindContainer.Name = "KeybindContainer"
keybindContainer.Size = UDim2.new(1, 0, 0, 25)
keybindContainer.Position = UDim2.new(0, 0, 0, 55)
keybindContainer.BackgroundTransparency = 1
keybindContainer.ZIndex = 13
keybindContainer.Parent = settingsSection

-- Auto Block keybind button
local blockKeybindButton = Instance.new("TextButton")
blockKeybindButton.Name = "BlockKeybindButton"
blockKeybindButton.Size = UDim2.new(0.48, 0, 1, 0)
blockKeybindButton.Position = UDim2.new(0, 0, 0, 0)
blockKeybindButton.BackgroundColor3 = THEME.BACKGROUND
blockKeybindButton.BackgroundTransparency = 0.5
blockKeybindButton.Text = "Toggle Block: [X]"
blockKeybindButton.TextColor3 = THEME.TEXT_PRIMARY
blockKeybindButton.TextSize = 14
blockKeybindButton.Font = Enum.Font.Gotham
blockKeybindButton.ZIndex = 14
blockKeybindButton.Parent = keybindContainer
createUICorner(blockKeybindButton, 6)
createUIStroke(blockKeybindButton, 1, THEME.NEUTRAL)

-- Auto Rotation keybind button
local rotationKeybindButton = Instance.new("TextButton")
rotationKeybindButton.Name = "RotationKeybindButton"
rotationKeybindButton.Size = UDim2.new(0.48, 0, 1, 0)
rotationKeybindButton.Position = UDim2.new(0.52, 0, 0, 0)
rotationKeybindButton.BackgroundColor3 = THEME.BACKGROUND
rotationKeybindButton.BackgroundTransparency = 0.5
rotationKeybindButton.Text = "Toggle Rotation: [R]"
rotationKeybindButton.TextColor3 = THEME.TEXT_PRIMARY
rotationKeybindButton.TextSize = 14
rotationKeybindButton.Font = Enum.Font.Gotham
rotationKeybindButton.ZIndex = 14
rotationKeybindButton.Parent = keybindContainer
createUICorner(rotationKeybindButton, 6)
createUIStroke(rotationKeybindButton, 1, THEME.NEUTRAL)

-- Animation tracking section (moved down to make room for settings)
local animSection = Instance.new("Frame")
animSection.Name = "AnimationSection"
animSection.Size = UDim2.new(1, 0, 0, 150)
animSection.Position = UDim2.new(0, 0, 0, 200) -- Moved down
animSection.BackgroundTransparency = 1
animSection.ZIndex = 12
animSection.Parent = contentContainer

local animHeader = Instance.new("TextLabel")
animHeader.Name = "AnimHeader"
animHeader.Size = UDim2.new(1, 0, 0, 25)
animHeader.BackgroundTransparency = 1
animHeader.TextColor3 = THEME.TEXT_SECONDARY
animHeader.TextSize = 14
animHeader.Font = Enum.Font.GothamMedium
animHeader.Text = "RECENT ANIMATIONS"
animHeader.TextXAlignment = Enum.TextXAlignment.Left
animHeader.ZIndex = 13
animHeader.Parent = animSection

local animContainer = Instance.new("Frame")
animContainer.Name = "AnimContainer"
animContainer.Size = UDim2.new(1, 0, 0, 125)
animContainer.Position = UDim2.new(0, 0, 0, 25)
animContainer.BackgroundColor3 = THEME.BACKGROUND
animContainer.BackgroundTransparency = 0.5
animContainer.ZIndex = 13
animContainer.Parent = animSection
createUICorner(animContainer, 8)
createUIStroke(animContainer, 1, THEME.NEUTRAL)

local animScrollFrame = Instance.new("ScrollingFrame")
animScrollFrame.Name = "AnimScroll"
animScrollFrame.Size = UDim2.new(1, -15, 1, -10)
animScrollFrame.Position = UDim2.new(0, 5, 0, 5)
animScrollFrame.BackgroundTransparency = 1
animScrollFrame.ScrollBarThickness = 6
animScrollFrame.ScrollBarImageColor3 = THEME.ACCENT_PRIMARY
animScrollFrame.BorderSizePixel = 0
animScrollFrame.ZIndex = 14
animScrollFrame.Parent = animContainer

local animTracker = Instance.new("TextLabel")
animTracker.Name = "AnimTracker"
animTracker.Size = UDim2.new(1, -10, 0, 115)
animTracker.BackgroundTransparency = 1
animTracker.TextColor3 = THEME.TEXT_SECONDARY
animTracker.TextSize = 14
animTracker.Font = Enum.Font.Gotham
animTracker.Text = "No animations tracked yet."
animTracker.TextXAlignment = Enum.TextXAlignment.Left
animTracker.TextYAlignment = Enum.TextYAlignment.Top
animTracker.TextWrapped = true
animTracker.ZIndex = 15
animTracker.Parent = animScrollFrame

-- Control buttons section
local controlsSection = Instance.new("Frame")
controlsSection.Name = "ControlsSection"
controlsSection.Size = UDim2.new(1, 0, 0, 40)
controlsSection.Position = UDim2.new(0, 0, 1, -40)
controlsSection.BackgroundTransparency = 1
controlsSection.ZIndex = 12
controlsSection.Parent = contentContainer

-- Function to create a button
local function createButton(name, text, position, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.48, 0, 1, 0)
    button.Position = position
    button.BackgroundColor3 = color
    button.BackgroundTransparency = 0.2
    button.Text = text
    button.TextColor3 = THEME.TEXT_PRIMARY
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.ZIndex = 13
    button.Parent = controlsSection
    createUICorner(button, 8)
    createShadow(button)
    return button
end

local toggleButton = createButton(
    "ToggleDebug", 
    "Show Animations", 
    UDim2.new(0, 0, 0, 0), 
    THEME.ACCENT_SECONDARY
)

local saveButton = createButton(
    "SaveBlacklist", 
    "Blacklist Selected", 
    UDim2.new(0.52, 0, 0, 0), 
    THEME.ACCENT_PRIMARY
)

-- Create bottom info bar
local infoBar = Instance.new("TextLabel")
infoBar.Name = "InfoBar"
infoBar.Size = UDim2.new(1, 0, 0, 20)
infoBar.Position = UDim2.new(0, 0, 1, -20)
infoBar.BackgroundColor3 = THEME.BACKGROUND
infoBar.BackgroundTransparency = 0.4
infoBar.BorderSizePixel = 0
infoBar.Text = string.format("Press [%s] to toggle auto-block | [%s] for auto-rotation", 
    string.char(autoBlockKeybind.Value), string.char(autoRotationKeybind.Value))
infoBar.TextColor3 = THEME.TEXT_SECONDARY
infoBar.TextSize = 12
infoBar.Font = Enum.Font.Gotham
infoBar.ZIndex = 11
infoBar.Parent = mainContainer
createUICorner(infoBar, 6)

-- Minimized mode elements
local minimizedFrame = Instance.new("Frame")
minimizedFrame.Name = "MinimizedFrame"
minimizedFrame.Size = UDim2.new(0, 180, 0, 40)
minimizedFrame.Position = UDim2.new(1, -190, 0.3, 0)
minimizedFrame.BackgroundColor3 = THEME.BACKGROUND
minimizedFrame.BackgroundTransparency = 0.3
minimizedFrame.BorderSizePixel = 0
minimizedFrame.ZIndex = 10
minimizedFrame.Visible = false
minimizedFrame.Parent = screenGui
createUICorner(minimizedFrame, 12)
createUIStroke(minimizedFrame, 1, THEME.ACCENT_PRIMARY)
createShadow(minimizedFrame)

local miniBlockStatus = Instance.new("TextLabel")
miniBlockStatus.Name = "MiniBlockStatus"
miniBlockStatus.Size = UDim2.new(1, -40, 1, 0)
miniBlockStatus.Position = UDim2.new(0, 10, 0, 0)
miniBlockStatus.BackgroundTransparency = 1
miniBlockStatus.TextColor3 = THEME.TEXT_PRIMARY
miniBlockStatus.TextSize = 14
miniBlockStatus.Font = Enum.Font.GothamSemibold
miniBlockStatus.Text = "AUTO-BLOCK: READY"
miniBlockStatus.TextXAlignment = Enum.TextXAlignment.Left
miniBlockStatus.ZIndex = 11
miniBlockStatus.Parent = minimizedFrame

local expandButton = Instance.new("TextButton")
expandButton.Name = "ExpandButton"
expandButton.Size = UDim2.new(0, 30, 0, 30)
expandButton.Position = UDim2.new(1, -35, 0, 5)
expandButton.BackgroundColor3 = THEME.ACCENT_PRIMARY
expandButton.BackgroundTransparency = 0.5
expandButton.Text = "+"
expandButton.TextColor3 = THEME.TEXT_PRIMARY
expandButton.TextSize = 18
expandButton.Font = Enum.Font.GothamBold
expandButton.ZIndex = 11
expandButton.Parent = minimizedFrame
createUICorner(expandButton, 6)

-- Function to toggle minimized state
local isMinimized = false
local function toggleMinimized()
    isMinimized = not isMinimized
    mainContainer.Visible = not isMinimized
    minimizedFrame.Visible = isMinimized
end

minimizeButton.MouseButton1Click:Connect(toggleMinimized)
expandButton.MouseButton1Click:Connect(toggleMinimized)

-- Make frames draggable
local function makeDraggable(frame)
    local dragging = false
    local dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
    end
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

makeDraggable(mainContainer)
makeDraggable(minimizedFrame)

local recentAnimations = {}
local maxRecentAnimations = 10

local function trackAnimation(player, animName, animId)
    table.insert(recentAnimations, 1, {
        player = player and player.Name or "unknown",
        name = animName,
        id = animId,
        time = tick()
    })
    if #recentAnimations > maxRecentAnimations then
        table.remove(recentAnimations)
    end
    local displayText = ""
    for i, anim in ipairs(recentAnimations) do
        local timeAgo = string.format("%.1fs", tick() - anim.time)
        displayText = displayText .. string.format("%d. [%s] %s\n   %s (%s ago)\n", 
            i, anim.name, anim.player, anim.id, timeAgo)
    end
    animTracker.Text = displayText ~= "" and displayText or "No animations tracked yet."
end

local function isInShiftLock()
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local subject = camera.CameraSubject
    if not subject then return false end
    if camera.CameraType == Enum.CameraType.Custom then
        if subject:IsA("Humanoid") and subject.Parent == localPlayer.Character then
            local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local cameraDist = (camera.CFrame.Position - hrp.Position).Magnitude
                return cameraDist > 3 and cameraDist < 15
            end
        end
    end
    return false
end

local function lookAtTarget(target)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") or
       not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    local targetPos = target.Character.HumanoidRootPart.Position
    local playerPos = localPlayer.Character.HumanoidRootPart.Position
    local lookVector = (targetPos - playerPos).unit
    if lookVector.Magnitude < 0.001 then
        return false
    end
    local newCFrame = CFrame.new(playerPos, playerPos + Vector3.new(lookVector.X, 0, lookVector.Z))
    localPlayer.Character.HumanoidRootPart.CFrame = newCFrame
    if isInShiftLock() then
        local targetHead = target.Character:FindFirstChild("Head")
        if targetHead then
            local headPos = targetHead.Position
            local camera = workspace.CurrentCamera
            if camera then
                local currentCamPos = camera.CFrame.Position
                camera.CFrame = CFrame.new(currentCamPos, headPos)
            end
        end
    end
    return true
end

local function releaseCameraControl()
end

local function activateBlocking(playerToFace)
    -- Don't activate if auto block is disabled
    if not autoBlockEnabled then
        return
    end
    
    local currentTime = tick()
    lastAnimationTime = currentTime
    if isCurrentlyBlocking then
        if playerToFace and playerToFace ~= currentTarget and autoRotationEnabled then
            currentTarget = playerToFace
            targetIndicator.Text = "FACING: " .. playerToFace.Name
            safely(lookAtTarget)(playerToFace)
        end
        return
    end
    if (currentTime - lastBlockTime) < blockCooldown then
        return
    end
    isCurrentlyBlocking = true
    lastBlockTime = currentTime
    if playerToFace then
        currentTarget = playerToFace
        targetIndicator.Text = "FACING: " .. playerToFace.Name
        targetIcon.BackgroundColor3 = THEME.DANGER
        targetIndicator.TextColor3 = THEME.DANGER
        if autoRotationEnabled then
            safely(lookAtTarget)(playerToFace)
        end
    end
    safely(function()
        local args = {
            [1] = "Blocking",
            [2] = true
        }
        game:GetService("Players").LocalPlayer.Character.Main.RemoteEvent:FireServer(unpack(args))
    end)()
    spawn(function()
        while isCurrentlyBlocking and currentTarget and autoRotationEnabled do
            if currentTarget and currentTarget.Character then
                safely(lookAtTarget)(currentTarget)
            end
            wait(0.03)
        end
    end)
end

local function shouldContinueBlocking()
    local currentTime = tick()
    local timeSinceLastAnimation = currentTime - lastAnimationTime
    if timeSinceLastAnimation < animationSpamThreshold then
        return true
    end
    return false
end

local function deactivateBlocking()
    if shouldContinueBlocking() then
        return
    end
    if not isCurrentlyBlocking then
        return
    end
    isCurrentlyBlocking = false
    if autoRotationEnabled then
        currentTarget = nil
        targetIndicator.Text = "NO TARGET"
        targetIcon.BackgroundColor3 = THEME.WARNING
        targetIndicator.TextColor3 = THEME.WARNING
    end
    safely(function()
        local args = {
            [1] = "DestroyBlock"
        }
        game:GetService("Players").LocalPlayer.Character.Main.RemoteEvent:FireServer(unpack(args))
    end)()
end

local function isBlacklistedAnimationId(animId)
    if not animId or animId == "" then 
        return false 
    end
    local normalizedId = tostring(animId):gsub("rbxassetid://", ""):gsub("%s+", "")
    for _, blacklistedId in ipairs(animationIdBlacklist) do
        local normalizedBlacklistedId = tostring(blacklistedId):gsub("rbxassetid://", ""):gsub("%s+", "")
        if normalizedId == normalizedBlacklistedId then
            return true
        end
    end
    return false
end

local function nameMatchesPattern(animName, pattern)
    if not animName or not pattern then return false end
    if not pattern:find("[%*%?]") then
        return animName == pattern
    end
    local luaPattern = pattern:gsub("%*", ".*"):gsub("%?", ".")
    return animName:match("^" .. luaPattern .. "$") ~= nil
end

local function isBlacklistedAnimation(animName)
    if not animName then return false end
    for _, blacklistedPattern in ipairs(animationBlacklist) do
        if nameMatchesPattern(animName, blacklistedPattern) then
            return true
        end
    end
    return false
end

local function getAllAnimationsFromPaths()
    local animationsTable = {}
    local animPaths = {
        game:GetService("ReplicatedStorage"):FindFirstChild("AnimationsCopy"),
        game:GetService("ReplicatedStorage"):FindFirstChild("Anims")
    }
    local foundAnimations = false
    local function gatherAnimations(folder)
        if not folder then 
            return 
        end
        for _, item in pairs(folder:GetChildren()) do
            if item:IsA("Animation") then
                if not isBlacklistedAnimation(item.Name) then
                    table.insert(animationsTable, {
                        id = item.AnimationId,
                        name = item.Name,
                        path = item:GetFullName()
                    })
                    foundAnimations = true
                end
            elseif item:IsA("Folder") or item:IsA("Model") then
                gatherAnimations(item)
            end
        end
    end
    for _, path in ipairs(animPaths) do
        gatherAnimations(path)
    end
    return animationsTable
end

local function isPlayerInRange(player, radius)
    local success, result = safely(function()
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or
           not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return false
        end
        local targetPosition = player.Character.HumanoidRootPart.Position
        local playerPosition = localPlayer.Character.HumanoidRootPart.Position
        local distance = (playerPosition - targetPosition).Magnitude
        return distance <= radius
    end)()
    return success and result or false
end

local function isPlayerInsideMark()
    local position = detectionMark.Position
    local radius = detectionRadius
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = player.Character.HumanoidRootPart.Position
            local distance = (position - targetPosition).magnitude
            if distance <= radius then
                return true, player
            end
        end
    end
    return false, nil
end

local allAnimations
safely(function()
    allAnimations = getAllAnimationsFromPaths()
end)()

if not allAnimations or #allAnimations == 0 then
    allAnimations = {}
end

local allAnimationIds = {}
for _, anim in ipairs(allAnimations) do
    table.insert(allAnimationIds, anim.id)
end

local function detectAttackAnimations()
    local success, err = safely(function()
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= localPlayer and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.AnimationPlayed:Connect(function(animTrack)
                        safely(function()
                            local animName = "unnamed"
                            local animId = "no-id"
                            if animTrack.Animation then
                                animName = animTrack.Animation.Name or "unnamed"
                                animId = animTrack.Animation.AnimationId or "no-id"
                                if showAllAnimations then
                                    trackAnimation(player, animName, animId)
                                end
                            end
                            if not isPlayerInRange(player, detectionRadius) then
                                return
                            end
                            if animTrack.Animation then
								if isBlacklistedAnimation(animName) or isBlacklistedAnimationId(animId) then
                                    return
                                end
                                local isTargetAnimation = false
                                if #allAnimationIds == 0 then
                                    isTargetAnimation = true
                                else
                                    for _, storedAnimId in ipairs(allAnimationIds) do
                                        if animTrack.Animation.AnimationId == storedAnimId then
                                            isTargetAnimation = true
                                            break
                                        end
                                    end
                                end
                                if isTargetAnimation then
                                    activateBlocking(player)
                                    spawn(function()
                                        local animLength = (animTrack.Length and animTrack.Length > 0) and animTrack.Length or 1
                                        local waitTime = animLength * 0.9
                                        wait(waitTime)
                                        deactivateBlocking()
                                    end)
                                end
                            end
                        end)()
                    end)
                end
            end
        end
    end)()
end

detectAttackAnimations()

game.Players.PlayerAdded:Connect(safely(function(player)
    player.CharacterAdded:Connect(safely(function(char)
        local humanoid = char:WaitForChild("Humanoid", 5)
        if not humanoid then
            return
        end
        humanoid.AnimationPlayed:Connect(safely(function(animTrack)
            local animName = "unnamed"
            local animId = "no-id"
            if animTrack.Animation then
                animName = animTrack.Animation.Name or "unnamed"
                animId = animTrack.Animation.AnimationId or "no-id"
                if showAllAnimations then
                    trackAnimation(player, animName, animId)
                end
            end
            if not isPlayerInRange(player, detectionRadius) then
                return
            end
            if animTrack.Animation then
                if isBlacklistedAnimation(animName) or isBlacklistedAnimationId(animId) then
                    return
                end
                local isTargetAnimation = false
                if #allAnimationIds == 0 then
                    isTargetAnimation = true
                else
                    for _, storedAnimId in ipairs(allAnimationIds) do
                        if animTrack.Animation.AnimationId == storedAnimId then
                            isTargetAnimation = true
                            break
                        end
                    end
                end
                if isTargetAnimation then
                    activateBlocking(player)
                    spawn(function()
                        local animLength = (animTrack.Length and animTrack.Length > 0) and animTrack.Length or 1
                        local waitTime = animLength * 0.9
                        wait(waitTime)
                        deactivateBlocking()
                    end)
                end
            end
        end))
    end))
end))

localPlayer.CharacterAdded:Connect(safely(function(newCharacter)
    character = newCharacter
    local hrp = newCharacter:WaitForChild("HumanoidRootPart", 5)
    if not hrp then
        return
    end
    isCurrentlyBlocking = false
    currentTarget = nil
    targetIndicator.Text = "NO TARGET"
    targetIcon.BackgroundColor3 = THEME.WARNING
    targetIndicator.TextColor3 = THEME.WARNING
    releaseCameraControl()
    detectionMark.Position = hrp.Position - Vector3.new(0, 2.95, 0)
    detectAttackAnimations()
end))

-- Function to toggle Auto Block
local function toggleAutoBlock()
    autoBlockEnabled = not autoBlockEnabled
    
    -- Update toggle switch appearance
    if autoBlockEnabled then
        toggleSwitch.BackgroundColor3 = THEME.SUCCESS
        toggleIndicator.Position = UDim2.new(1, -21, 0.5, -9)
    else
        toggleSwitch.BackgroundColor3 = THEME.NEUTRAL
        toggleIndicator.Position = UDim2.new(0, 3, 0.5, -9)
    end
    
    -- Update indicators
    if autoBlockEnabled then
        blockIndicator.Text = "AUTO-BLOCK: READY"
        miniBlockStatus.Text = "READY"
    else
        blockIndicator.Text = "AUTO-BLOCK: OFF"
        miniBlockStatus.Text = "OFF"
        -- If currently blocking, cancel it
        if isCurrentlyBlocking then
            deactivateBlocking()
        end
    end
    
    -- Create notification
    local notification = Instance.new("Frame")
    notification.Name = "BlockToggleNotification"
    notification.Size = UDim2.new(0, 250, 0, 40)
    notification.Position = UDim2.new(0.5, -125, 0.7, 0)
    notification.BackgroundColor3 = autoBlockEnabled and THEME.SUCCESS or THEME.NEUTRAL
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    notification.ZIndex = 100
    notification.Parent = screenGui
    createUICorner(notification, 8)
    createShadow(notification)
    
    local notificationText = Instance.new("TextLabel")
    notificationText.Size = UDim2.new(1, -10, 1, 0)
    notificationText.Position = UDim2.new(0, 5, 0, 0)
    notificationText.BackgroundTransparency = 1
    notificationText.TextColor3 = THEME.TEXT_PRIMARY
    notificationText.TextSize = 14
    notificationText.Font = Enum.Font.GothamBold
    notificationText.Text = "Auto-Block: " .. (autoBlockEnabled and "ENABLED" or "DISABLED")
    notificationText.ZIndex = 101
    notificationText.Parent = notification
    
    spawn(function()
        wait(2)
        for i = 1, 10 do
            notification.BackgroundTransparency = 0.2 + (i * 0.08)
            notificationText.TextTransparency = i * 0.1
            wait(0.05)
        end
        notification:Destroy()
    end)
end

-- Connect toggle switch to toggle function
toggleSwitch.MouseButton1Click:Connect(toggleAutoBlock)

-- Function to update the detection radius
local function updateRadius(newRadius)
    detectionRadius = math.clamp(newRadius, 5, 30)
    radiusValue.Text = tostring(detectionRadius)
    
    -- Update the detection mark size
    detectionMark.Size = Vector3.new(0.1, detectionRadius * 2, detectionRadius * 2)
    outerRing.Size = Vector3.new(0.1, detectionRadius * 2 + 0.2, detectionRadius * 2 + 0.2)
    
    -- Update slider position
    local sliderPosition = (detectionRadius - 5) / 25
    radiusHandle.Position = UDim2.new(sliderPosition, -8, 0.5, -8)
end

-- Make the radius slider draggable
local isDraggingRadius = false
radiusHandle.MouseButton1Down:Connect(function()
    isDraggingRadius = true
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDraggingRadius = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if isDraggingRadius and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouse = game:GetService("Players").LocalPlayer:GetMouse()
        local sliderPosition = radiusSlider.AbsolutePosition
        local sliderSize = radiusSlider.AbsoluteSize
        local relativeX = mouse.X - sliderPosition.X
        local sliderRatio = math.clamp(relativeX / sliderSize.X, 0, 1)
        local newRadius = math.floor(5 + (sliderRatio * 25))
        updateRadius(newRadius)
    end
end)

-- Also allow clicking directly on the slider
radiusSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = game:GetService("Players").LocalPlayer:GetMouse()
        local sliderPosition = radiusSlider.AbsolutePosition
        local sliderSize = radiusSlider.AbsoluteSize
        local relativeX = mouse.X - sliderPosition.X
        local sliderRatio = math.clamp(relativeX / sliderSize.X, 0, 1)
        local newRadius = math.floor(5 + (sliderRatio * 25))
        updateRadius(newRadius)
    end
end)

-- Function to wait for a keybind and set it
local function waitForKeybind(target)
    local notification = Instance.new("Frame")
    notification.Name = "KeybindNotification"
    notification.Size = UDim2.new(0, 250, 0, 40)
    notification.Position = UDim2.new(0.5, -125, 0.4, 0)
    notification.BackgroundColor3 = THEME.WARNING
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    notification.ZIndex = 100
    notification.Parent = screenGui
    createUICorner(notification, 8)
    createShadow(notification)
    
    local notificationText = Instance.new("TextLabel")
    notificationText.Size = UDim2.new(1, -10, 1, 0)
    notificationText.Position = UDim2.new(0, 5, 0, 0)
    notificationText.BackgroundTransparency = 1
    notificationText.TextColor3 = THEME.TEXT_PRIMARY
    notificationText.TextSize = 14
    notificationText.Font = Enum.Font.GothamBold
    notificationText.Text = "Press any key to set new keybind..."
    notificationText.ZIndex = 101
    notificationText.Parent = notification
    
    local keybindConnection
    keybindConnection = game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if target == "block" then
                autoBlockKeybind = input.KeyCode
                blockKeybindButton.Text = "Toggle Block: [" .. string.char(input.KeyCode.Value) .. "]"
            elseif target == "rotation" then
                autoRotationKeybind = input.KeyCode
                rotationKeybindButton.Text = "Toggle Rotation: [" .. string.char(input.KeyCode.Value) .. "]"
            end
            
            -- Update info bar
            infoBar.Text = string.format("Press [%s] to toggle auto-block | [%s] for auto-rotation", 
                string.char(autoBlockKeybind.Value), string.char(autoRotationKeybind.Value))
            
            notification:Destroy()
            keybindConnection:Disconnect()
        end
    end)
    
    -- Cancel if they click elsewhere
    spawn(function()
        wait(5)
        if notification.Parent then
            notification:Destroy()
            if keybindConnection then
                keybindConnection:Disconnect()
            end
        end
    end)
end

-- Connect keybind buttons
blockKeybindButton.MouseButton1Click:Connect(function()
    waitForKeybind("block")
end)

rotationKeybindButton.MouseButton1Click:Connect(function()
    waitForKeybind("rotation")
end)

toggleButton.MouseButton1Click:Connect(function()
    showAllAnimations = not showAllAnimations
    animTracker.Text = showAllAnimations and "Tracking animations..." or "Animation tracking disabled."
    toggleButton.BackgroundColor3 = showAllAnimations and THEME.SUCCESS or THEME.ACCENT_SECONDARY
    toggleButton.Text = showAllAnimations and "Hide Animations" or "Show Animations"
end)

saveButton.MouseButton1Click:Connect(function()
    if #recentAnimations > 0 then
        local selectedAnim = recentAnimations[1]
        table.insert(animationBlacklist, selectedAnim.name)
        table.insert(animationIdBlacklist, selectedAnim.id)
        
        -- Create notification
        local notification = Instance.new("Frame")
        notification.Name = "Notification"
        notification.Size = UDim2.new(0, 250, 0, 40)
        notification.Position = UDim2.new(0.5, -125, 0.8, 0)
        notification.BackgroundColor3 = THEME.SUCCESS
        notification.BackgroundTransparency = 0.2
        notification.BorderSizePixel = 0
        notification.ZIndex = 100
        notification.Parent = screenGui
        createUICorner(notification, 8)
        createShadow(notification)
        
        local notifText = Instance.new("TextLabel")
        notifText.Size = UDim2.new(1, -10, 1, 0)
        notifText.Position = UDim2.new(0, 5, 0, 0)
        notifText.BackgroundTransparency = 1
        notifText.TextColor3 = THEME.TEXT_PRIMARY
        notifText.TextSize = 14
        notifText.Font = Enum.Font.GothamBold
        notifText.Text = "Animation blacklisted successfully!"
        notifText.ZIndex = 101
        notifText.Parent = notification
        
        spawn(function()
            wait(2)
            for i = 1, 10 do
                notification.BackgroundTransparency = 0.2 + (i * 0.08)
                notifText.TextTransparency = i * 0.1
                wait(0.05)
            end
            notification:Destroy()
        end)
    end
end)

-- Update UI and game state
spawn(safely(function()
    while true do
        wait(0.1)
		safely(function()
			if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local position = localPlayer.Character.HumanoidRootPart.Position - Vector3.new(0, 2.95, 0)
				detectionMark.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
				outerRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
			end
		end)()
        safely(function()
            if isCurrentlyBlocking and not shouldContinueBlocking() then
                deactivateBlocking()
            end
            if isCurrentlyBlocking and currentTarget and currentTarget.Character and autoRotationEnabled then
                safely(function()
                    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        return
                    end
                    if not currentTarget.Character or not currentTarget.Character:FindFirstChild("HumanoidRootPart") then
                        return
                    end
                    local targetPos = currentTarget.Character.HumanoidRootPart.Position
                    local playerPos = localPlayer.Character.HumanoidRootPart.Position
                    localPlayer.Character.HumanoidRootPart.CFrame = CFrame.lookAt(
                        playerPos, 
                        Vector3.new(targetPos.X, playerPos.Y, targetPos.Z)
                    )
                end)()
            end
        end)()
    end
end))

-- Update block status indicator
spawn(safely(function()
    while true do
        wait(0.1)
        if not autoBlockEnabled then
            blockIndicator.Text = "AUTO-BLOCK: OFF"
            miniBlockStatus.Text = "OFF"
            blockStatusIcon.BackgroundColor3 = THEME.NEUTRAL
            createUIStroke(blockStatusContainer, 1, THEME.NEUTRAL)
        elseif isCurrentlyBlocking then
            local timeLeft = math.max(0, animationSpamThreshold - (tick() - lastAnimationTime))
            local formattedTime = string.format("%.1f", timeLeft)
            
            if shouldContinueBlocking() then
                blockIndicator.Text = "AUTO-BLOCK: ACTIVE (" .. formattedTime .. "s)"
                miniBlockStatus.Text = "ACTIVE (" .. formattedTime .. "s)"
                blockStatusIcon.BackgroundColor3 = THEME.SUCCESS
                createUIStroke(blockStatusContainer, 1, THEME.SUCCESS)
            else
                blockIndicator.Text = "AUTO-BLOCK: ENDING..."
                miniBlockStatus.Text = "ENDING..."
                blockStatusIcon.BackgroundColor3 = THEME.WARNING
                createUIStroke(blockStatusContainer, 1, THEME.WARNING)
            end
        else
            blockIndicator.Text = "AUTO-BLOCK: READY"
            miniBlockStatus.Text = "READY"
            blockStatusIcon.BackgroundColor3 = THEME.NEUTRAL
            createUIStroke(blockStatusContainer, 1, THEME.NEUTRAL)
        end
    end
end))

-- Handle user input
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == autoRotationKeybind and not gameProcessed then
        autoRotationEnabled = not autoRotationEnabled
        
        if not autoRotationEnabled then
            currentTarget = nil
            targetIndicator.Text = "AUTO-ROTATION: OFF"
            targetIcon.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            targetIndicator.TextColor3 = Color3.fromRGB(170, 170, 170)
            createUIStroke(targetStatusContainer, 1, Color3.fromRGB(100, 100, 100))
        else
            targetIndicator.Text = "NO TARGET"
            targetIcon.BackgroundColor3 = THEME.WARNING
            targetIndicator.TextColor3 = THEME.WARNING
            createUIStroke(targetStatusContainer, 1, THEME.NEUTRAL)
        end
        
        -- Create rotation toggle notification
        local rotationNotif = Instance.new("Frame")
        rotationNotif.Name = "RotationNotification"
        rotationNotif.Size = UDim2.new(0, 250, 0, 40)
        rotationNotif.Position = UDim2.new(0.5, -125, 0.7, 0)
        rotationNotif.BackgroundColor3 = autoRotationEnabled and THEME.SUCCESS or THEME.NEUTRAL
        rotationNotif.BackgroundTransparency = 0.2
        rotationNotif.BorderSizePixel = 0
        rotationNotif.ZIndex = 100
        rotationNotif.Parent = screenGui
        createUICorner(rotationNotif, 8)
        createShadow(rotationNotif)
        
        local rotationText = Instance.new("TextLabel")
        rotationText.Size = UDim2.new(1, -10, 1, 0)
        rotationText.Position = UDim2.new(0, 5, 0, 0)
        rotationText.BackgroundTransparency = 1
        rotationText.TextColor3 = THEME.TEXT_PRIMARY
        rotationText.TextSize = 14
        rotationText.Font = Enum.Font.GothamBold
        rotationText.Text = "Auto-rotation: " .. (autoRotationEnabled and "ENABLED" or "DISABLED")
        rotationText.ZIndex = 101
        rotationText.Parent = rotationNotif
        
        spawn(function()
            wait(2)
            for i = 1, 10 do
                rotationNotif.BackgroundTransparency = 0.2 + (i * 0.08)
                rotationText.TextTransparency = i * 0.1
                wait(0.05)
            end
            rotationNotif:Destroy()
        end)
    elseif input.KeyCode == autoBlockKeybind and not gameProcessed then
        toggleAutoBlock()
    end
end)

-- Help panel
local helpPanel = Instance.new("Frame")
helpPanel.Name = "HelpPanel"
helpPanel.Size = UDim2.new(0, 300, 0, 300)
helpPanel.Position = UDim2.new(0.5, -150, 0.5, -150)
helpPanel.BackgroundColor3 = THEME.BACKGROUND
helpPanel.BackgroundTransparency = 0.1
helpPanel.BorderSizePixel = 0
helpPanel.ZIndex = 50
helpPanel.Visible = false
helpPanel.Parent = screenGui
createUICorner(helpPanel, 12)
createUIStroke(helpPanel, 2, THEME.ACCENT_PRIMARY)
createShadow(helpPanel)

local helpTitle = Instance.new("TextLabel")
helpTitle.Name = "HelpTitle"
helpTitle.Size = UDim2.new(1, -20, 0, 40)
helpTitle.Position = UDim2.new(0, 10, 0, 10)
helpTitle.BackgroundTransparency = 1
helpTitle.TextColor3 = THEME.ACCENT_PRIMARY
helpTitle.TextSize = 22
helpTitle.Font = Enum.Font.GothamBold
helpTitle.Text = "Auto-Block Help"
helpTitle.TextXAlignment = Enum.TextXAlignment.Left
helpTitle.ZIndex = 51
helpTitle.Parent = helpPanel

local helpContent = Instance.new("TextLabel")
helpContent.Name = "HelpContent"
helpContent.Size = UDim2.new(1, -20, 1, -60)
helpContent.Position = UDim2.new(0, 10, 0, 50)
helpContent.BackgroundTransparency = 1
helpContent.TextColor3 = THEME.TEXT_SECONDARY
helpContent.TextSize = 14
helpContent.Font = Enum.Font.Gotham
helpContent.Text = [[
• Toggle auto-block on/off with the switch or keybind.

• Adjust detection radius with the slider (5-30).

• Change keybinds by clicking on the keybind buttons.

• Press your auto-rotation keybind (default R) to toggle 
  auto-rotation towards enemies.

• Enable "Show Animations" to track all animations 
  played by nearby players.

• Use "Blacklist Selected" to ignore specific animations.

• The green circle shows your current detection radius.

• For best results, use with shift-lock camera mode.
]]
helpContent.TextWrapped = true
helpContent.TextXAlignment = Enum.TextXAlignment.Left
helpContent.TextYAlignment = Enum.TextYAlignment.Top
helpContent.ZIndex = 51
helpContent.Parent = helpPanel

local closeHelpButton = Instance.new("TextButton")
closeHelpButton.Name = "CloseHelpButton"
closeHelpButton.Size = UDim2.new(0, 30, 0, 30)
closeHelpButton.Position = UDim2.new(1, -40, 0, 10)
closeHelpButton.BackgroundColor3 = THEME.DANGER
closeHelpButton.BackgroundTransparency = 0.3
closeHelpButton.Text = "X"
closeHelpButton.TextColor3 = THEME.TEXT_PRIMARY
closeHelpButton.TextSize = 18
closeHelpButton.Font = Enum.Font.GothamBold
closeHelpButton.ZIndex = 51
closeHelpButton.Parent = helpPanel
createUICorner(closeHelpButton, 15)

helpButton.MouseButton1Click:Connect(function()
    helpPanel.Visible = true
end)

closeHelpButton.MouseButton1Click:Connect(function()
    helpPanel.Visible = false
end)

-- Create a simple pulse effect
spawn(function()
    while true do
        for i = 0, 1, 0.1 do
            detectionMark.Transparency = 0.5 + (i * 0.25)
            wait(0.03)
        end
        for i = 0, 1, 0.1 do
            detectionMark.Transparency = 0.75 - (i * 0.25)
            wait(0.03)
        end
    end
end)

-- Display welcome message
local welcomeNotif = Instance.new("Frame")
welcomeNotif.Name = "WelcomeNotification"
welcomeNotif.Size = UDim2.new(0, 300, 0, 60)
welcomeNotif.Position = UDim2.new(0.5, -150, 0.3, 0)
welcomeNotif.BackgroundColor3 = THEME.ACCENT_PRIMARY
welcomeNotif.BackgroundTransparency = 0.2
welcomeNotif.BorderSizePixel = 0
welcomeNotif.ZIndex = 100
welcomeNotif.Parent = screenGui
createUICorner(welcomeNotif, 10)
createShadow(welcomeNotif)

local welcomeText = Instance.new("TextLabel")
welcomeText.Size = UDim2.new(1, -20, 1, 0)
welcomeText.Position = UDim2.new(0, 10, 0, 0)
welcomeText.BackgroundTransparency = 1
welcomeText.TextColor3 = THEME.TEXT_PRIMARY
welcomeText.TextSize = 16
welcomeText.Font = Enum.Font.GothamBold
welcomeText.Text = "⚔️ Improved Auto-Block System ⚔️\nPress ? for help | Toggle with " .. string.char(autoBlockKeybind.Value)
welcomeText.TextWrapped = true
welcomeText.ZIndex = 101
welcomeText.Parent = welcomeNotif

spawn(function()
    wait(4)
    for i = 1, 10 do
        welcomeNotif.BackgroundTransparency = 0.2 + (i * 0.08)
        welcomeText.TextTransparency = i * 0.1
        wait(0.05)
    end
    welcomeNotif:Destroy()
end)
