local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Cleanup
if _G.HitboxAddedConn then _G.HitboxAddedConn:Disconnect() _G.HitboxAddedConn=nil end
if _G.HitboxKeybind then _G.HitboxKeybind:Disconnect() _G.HitboxKeybind=nil end
if _G.TargetConn then _G.TargetConn:Disconnect() _G.TargetConn=nil end
if _G.HitboxGUI then _G.HitboxGUI:Destroy() _G.HitboxGUI=nil end

for _,obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("BillboardGui") and
       (obj.Name=="CustomNPCHealthESP" or obj.Name=="NPCTargetMarker") then
        obj:Destroy()
    end
end

-- Config
_G.MenuConfig = {
    HitboxEnabled = false,
    HitboxSize = 22,
    HitboxTransparency = 0.92,
    HealthESPEnabled = false,
    TargetEnabled = false,
    TargetMaxDistance = 1000
}

local originalData = setmetatable({}, {__mode="k"})
local currentTarget

-- ==========================================
-- NPC
-- ==========================================

local function isValidNPC(model)
    if not model or not model:IsA("Model") then return false end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local head = model:FindFirstChild("Head")

    if not humanoid or not head then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if humanoid.Health <= 0 then return false end

    return true
end

-- ==========================================
-- HITBOX
-- ==========================================

local function applyHitbox(model, enable)
    local head = model:FindFirstChild("Head")
    if not head then return end

    if enable then
        if not isValidNPC(model) then return end

        if not originalData[head] then
            originalData[head] = {
                Size = head.Size,
                Material = head.Material,
                BrickColor = head.BrickColor,
                Transparency = head.Transparency
            }
        end

        local s = _G.MenuConfig.HitboxSize

        head.Size = Vector3.new(s,s,s)
        head.Transparency = _G.MenuConfig.HitboxTransparency
        head.Material = Enum.Material.Neon
        head.BrickColor = BrickColor.new("Really blue")
        head.CanCollide = false
        head.Massless = true
    else
        local saved = originalData[head]

        if saved then
            head.Size = saved.Size
            head.Material = saved.Material
            head.BrickColor = saved.BrickColor
            head.Transparency = saved.Transparency
            originalData[head] = nil
        end
    end
end

_G.UpdateHitbox = function()
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent then
            applyHitbox(obj.Parent,_G.MenuConfig.HitboxEnabled)
        end
    end
end

-- ==========================================
-- HEALTH ESP
-- ==========================================

local function applyHealthESP(model,enable)
    local head = model:FindFirstChild("Head")
    local humanoid = model:FindFirstChildOfClass("Humanoid")

    if not head or not humanoid then return end

    local existingGui = head:FindFirstChild("CustomNPCHealthESP")

    if enable then
        if not isValidNPC(model) or existingGui then return end

        local bGui = Instance.new("BillboardGui")
        bGui.Name = "CustomNPCHealthESP"
        bGui.Adornee = head
        bGui.Size = UDim2.new(0,90,0,26)

        -- Đẩy lên cao hơn để tránh thanh máu mặc định
        bGui.StudsOffset = Vector3.new(0,4.5,0)

        bGui.AlwaysOnTop = true
        bGui.MaxDistance = math.huge
        bGui.Parent = head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1,0,0.5,0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = model.Name
        nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
        nameLabel.TextStrokeTransparency = 0.3
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.Parent = bGui

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1,0,0.45,0)
        barBg.Position = UDim2.new(0,0,0.55,0)
        barBg.BackgroundColor3 = Color3.fromRGB(35,35,40)
        barBg.BorderSizePixel = 1
        barBg.BorderColor3 = Color3.fromRGB(0,0,0)
        barBg.Parent = bGui

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(1,0,1,0)
        barFill.BackgroundColor3 = Color3.fromRGB(46,204,113)
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg

        local hpText = Instance.new("TextLabel")
        hpText.Size = UDim2.new(1,0,1,0)
        hpText.BackgroundTransparency = 1
        hpText.TextColor3 = Color3.fromRGB(255,255,255)
        hpText.TextStrokeTransparency = 0.4
        hpText.Font = Enum.Font.GothamBold
        hpText.TextSize = 10
        hpText.ZIndex = 2
        hpText.Parent = barBg

        local function updateBar()
            if not bGui.Parent then return end

            local hp = math.max(0,math.floor(humanoid.Health))
            local maxHp = math.max(1,math.floor(humanoid.MaxHealth))
            local ratio = math.clamp(hp/maxHp,0,1)

            barFill.Size = UDim2.new(ratio,0,1,0)
            hpText.Text = hp.." / "..maxHp

            if ratio > 0.5 then
                barFill.BackgroundColor3 = Color3.fromRGB(46,204,113)
            elseif ratio > 0.25 then
                barFill.BackgroundColor3 = Color3.fromRGB(241,196,15)
            else
                barFill.BackgroundColor3 = Color3.fromRGB(231,76,60)
            end
        end

        updateBar()

        local healthConn = humanoid.HealthChanged:Connect(updateBar)

        humanoid.Died:Once(function()
            if healthConn then healthConn:Disconnect() end
            if bGui then bGui:Destroy() end
        end)

    elseif existingGui then
        existingGui:Destroy()
    end
end

_G.UpdateHealthESP = function()
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent then
            applyHealthESP(
                obj.Parent,
                _G.MenuConfig.HealthESPEnabled
            )
        end
    end
end

-- ==========================================
-- NPC TARGET
-- ==========================================

local function removeTargetMarker()
    if currentTarget then
        local head = currentTarget:FindFirstChild("Head")

        if head then
            local marker = head:FindFirstChild("NPCTargetMarker")
            if marker then
                marker:Destroy()
            end
        end
    end
end

local function clearTarget()
    removeTargetMarker()
    currentTarget = nil
end

local function addTargetMarker(model)
    local head = model:FindFirstChild("Head")
    if not head then return end

    if head:FindFirstChild("NPCTargetMarker") then return end

    local gui = Instance.new("BillboardGui")
    gui.Name = "NPCTargetMarker"
    gui.Adornee = head
    gui.Size = UDim2.new(0,80,0,22)
    gui.StudsOffset = Vector3.new(0,3.5,0)
    gui.AlwaysOnTop = true
    gui.Parent = head

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1,1)
    text.BackgroundTransparency = 1
    text.Text = "TARGET"
    text.TextColor3 = Color3.fromRGB(255,80,80)
    text.TextStrokeTransparency = 0.2
    text.Font = Enum.Font.GothamBold
    text.TextSize = 12
    text.Parent = gui
end

local function isTargetVisible(model)
    if not isValidNPC(model) then return false end

    local head = model:FindFirstChild("Head")
    local camera = workspace.CurrentCamera

    if not head or not camera then return false end

    local pos,onScreen = camera:WorldToViewportPoint(head.Position)

    if not onScreen or pos.Z <= 0 then
        return false
    end

    local distance =
        (head.Position-camera.CFrame.Position).Magnitude

    return distance <= _G.MenuConfig.TargetMaxDistance
end

local function findTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local viewport = camera.ViewportSize
    local center = Vector2.new(
        viewport.X/2,
        viewport.Y/2
    )

    local best
    local bestDistance = math.huge

    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent then
            local model = obj.Parent

            if isValidNPC(model) then
                local head = model:FindFirstChild("Head")

                if head then
                    local pos,onScreen =
                        camera:WorldToViewportPoint(head.Position)

                    if onScreen and pos.Z > 0 then
                        local worldDistance =
                            (head.Position-camera.CFrame.Position).Magnitude

                        if worldDistance <=
                           _G.MenuConfig.TargetMaxDistance then

                            local screenDistance =
                                (Vector2.new(pos.X,pos.Y)-center).Magnitude

                            if screenDistance < bestDistance then
                                best = model
                                bestDistance = screenDistance
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

_G.UpdateTarget = function()
    if not _G.MenuConfig.TargetEnabled then
        clearTarget()
        return
    end

    if currentTarget and isTargetVisible(currentTarget) then
        addTargetMarker(currentTarget)
        return
    end

    clearTarget()

    local newTarget = findTarget()

    if newTarget then
        currentTarget = newTarget
        addTargetMarker(currentTarget)
    end
end

-- ==========================================
-- NPC MỚI
-- ==========================================

_G.HitboxAddedConn =
workspace.DescendantAdded:Connect(function(descendant)

    if not descendant:IsA("Humanoid") then return end

    local npcModel = descendant.Parent
    if not npcModel then return end

    local head = npcModel:WaitForChild("Head",3)
    if not head then return end

    if _G.MenuConfig.HitboxEnabled then
        applyHitbox(npcModel,true)
    end

    if _G.MenuConfig.HealthESPEnabled then
        applyHealthESP(npcModel,true)
    end

    descendant.Died:Once(function()
        applyHitbox(npcModel,false)
        applyHealthESP(npcModel,false)

        if currentTarget == npcModel then
            clearTarget()
        end
    end)
end)

-- ==========================================
-- GUI
-- ==========================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ControlPanelGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
_G.HitboxGUI = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0,230,0,215)
MainFrame.Position = UDim2.new(0,20,0,20)
MainFrame.BackgroundColor3 = Color3.fromRGB(30,30,35)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0,8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,0,0,28)
Title.BackgroundColor3 = Color3.fromRGB(45,45,55)
Title.Text = "  Control Menu [RCtrl: Ẩn]"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0,8)
TitleCorner.Parent = Title

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0,24,0,22)
MinimizeBtn.Position = UDim2.new(1,-27,0,3)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(70,70,85)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.Parent = Title

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0,5)
MinCorner.Parent = MinimizeBtn

local isMinimized = false

MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized

    MainFrame.Size =
        isMinimized
        and UDim2.new(0,230,0,28)
        or UDim2.new(0,230,0,215)

    MinimizeBtn.Text =
        isMinimized and "+" or "-"
end)

local ScrollContainer = Instance.new("ScrollingFrame")
ScrollContainer.Size = UDim2.new(1,-10,1,-36)
ScrollContainer.Position = UDim2.new(0,5,0,32)
ScrollContainer.BackgroundTransparency = 1
ScrollContainer.BorderSizePixel = 0
ScrollContainer.ScrollBarThickness = 4
ScrollContainer.ScrollBarImageColor3 =
    Color3.fromRGB(100,100,120)
ScrollContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollContainer.CanvasSize = UDim2.new(0,0,0,0)
ScrollContainer.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0,6)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ScrollContainer

-- ==========================================
-- GUI HELPERS
-- ==========================================

local function addSectionTitle(text)
    local Sec = Instance.new("TextLabel")

    Sec.Size = UDim2.new(1,-6,0,20)
    Sec.BackgroundTransparency = 1
    Sec.Text = "--- "..text.." ---"
    Sec.TextColor3 = Color3.fromRGB(150,180,255)
    Sec.Font = Enum.Font.GothamBold
    Sec.TextSize = 11
    Sec.Parent = ScrollContainer
end

local function addToggle(text,defaultState,callback)
    local state = defaultState

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1,-6,0,28)
    Btn.BackgroundColor3 =
        state
        and Color3.fromRGB(46,204,113)
        or Color3.fromRGB(231,76,60)

    Btn.Text =
        text..(state and ": BẬT" or ": TẮT")

    Btn.TextColor3 = Color3.fromRGB(255,255,255)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.Parent = ScrollContainer

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0,6)
    Corner.Parent = Btn

    local function updateVisual(newState)
        state = newState

        Btn.BackgroundColor3 =
            state
            and Color3.fromRGB(46,204,113)
            or Color3.fromRGB(231,76,60)

        Btn.Text =
            text..(state and ": BẬT" or ": TẮT")
    end

    Btn.MouseButton1Click:Connect(function()
        updateVisual(not state)
        callback(state)
    end)

    return updateVisual
end

local function addInput(labelText,defaultValue,callback)
    local Row = Instance.new("Frame")

    Row.Size = UDim2.new(1,-6,0,26)
    Row.BackgroundTransparency = 1
    Row.Parent = ScrollContainer

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6,0,1,0)
    Label.BackgroundTransparency = 1
    Label.Text = " "..labelText
    Label.TextColor3 = Color3.fromRGB(220,220,220)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0.38,0,1,0)
    Box.Position = UDim2.new(0.62,0,0,0)
    Box.BackgroundColor3 = Color3.fromRGB(50,50,60)
    Box.Text = tostring(defaultValue)
    Box.TextColor3 = Color3.fromRGB(255,255,255)
    Box.Font = Enum.Font.GothamBold
    Box.TextSize = 12
    Box.ClearTextOnFocus = false
    Box.Parent = Row

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0,4)
    Corner.Parent = Box

    Box.FocusLost:Connect(function()
        local num = tonumber(Box.Text)

        if num then
            callback(num)
            Box.Text = tostring(num)
        else
            Box.Text = tostring(defaultValue)
        end
    end)
end

-- ==========================================
-- GẮN CHỨC NĂNG
-- ==========================================

addSectionTitle("CÀI ĐẶT HITBOX")

local setHitboxBtnVisual =
addToggle(
    "Hitbox (Numpad 0)",
    _G.MenuConfig.HitboxEnabled,
    function(state)
        _G.MenuConfig.HitboxEnabled = state
        _G.UpdateHitbox()
    end
)

addInput(
    "Kích thước (Size):",
    _G.MenuConfig.HitboxSize,
    function(val)
        _G.MenuConfig.HitboxSize = math.max(1,val)
        _G.UpdateHitbox()
    end
)

addInput(
    "Độ mờ (0 - 1):",
    _G.MenuConfig.HitboxTransparency,
    function(val)
        _G.MenuConfig.HitboxTransparency =
            math.clamp(val,0,1)

        _G.UpdateHitbox()
    end
)

addSectionTitle("HIỂN THỊ (ESP)")

addToggle(
    "Thanh máu NPC",
    _G.MenuConfig.HealthESPEnabled,
    function(state)
        _G.MenuConfig.HealthESPEnabled = state
        _G.UpdateHealthESP()
    end
)

addSectionTitle("NPC TARGET")

addToggle(
    "NPC Head Target (T)",
    _G.MenuConfig.TargetEnabled,
    function(state)
        _G.MenuConfig.TargetEnabled = state

        if not state then
            clearTarget()
        else
            _G.UpdateTarget()
        end
    end
)

addInput(
    "Khoảng cách Target:",
    _G.MenuConfig.TargetMaxDistance,
    function(val)
        _G.MenuConfig.TargetMaxDistance =
            math.max(1,val)

        _G.UpdateTarget()
    end
)

-- ==========================================
-- HOTKEY
-- ==========================================

_G.HitboxKeybind =
UserInputService.InputBegan:Connect(function(input,gameProcessed)

    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.KeypadZero then

        _G.MenuConfig.HitboxEnabled =
            not _G.MenuConfig.HitboxEnabled

        setHitboxBtnVisual(
            _G.MenuConfig.HitboxEnabled
        )

        _G.UpdateHitbox()

    elseif input.KeyCode == Enum.KeyCode.T then

        _G.MenuConfig.TargetEnabled =
            not _G.MenuConfig.TargetEnabled

        if not _G.MenuConfig.TargetEnabled then
            clearTarget()
        else
            _G.UpdateTarget()
        end

    elseif input.KeyCode == Enum.KeyCode.RightControl then

        MainFrame.Visible =
            not MainFrame.Visible

    end
end)

-- ==========================================
-- TARGET UPDATE
-- ==========================================

_G.TargetConn =
RunService.RenderStepped:Connect(function()

    if _G.MenuConfig.TargetEnabled then
        _G.UpdateTarget()
    elseif currentTarget then
        clearTarget()
    end

end)

-- Initial state
_G.UpdateHitbox()
_G.UpdateHealthESP()
_G.UpdateTarget()
