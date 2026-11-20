local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
-- 1. Dọn dẹp toàn bộ kết nối & GUI cũ nếu chạy lại script
if _G.HitboxAddedConn then _G.HitboxAddedConn:Disconnect() _G.HitboxAddedConn = nil end
if _G.HitboxKeybind then _G.HitboxKeybind:Disconnect() _G.HitboxKeybind = nil end
if _G.HitboxGui then _G.HitboxGui:Destroy() _G.HitboxGui = nil end
if _G.CharAddedConn then _G.CharAddedConn:Disconnect() _G.CharAddedConn = nil end
if _G.FullbrightConn then _G.FullbrightConn:Disconnect() _G.FullbrightConn = nil end
if _G.AutoInteractLoop then _G.AutoInteractLoop = false end
-- Trạng thái mặc định: TẮT toàn bộ khi khởi động
local isHitboxEnabled = false
local isEspHighlightEnabled = false
local isEspNameEnabled = false
local isEspHealthEnabled = false
local isInteractEnabled = false
local isWsEnabled = false
local isJpEnabled = false
local isFullbrightEnabled = false
local targetFilterText = ""
local currentSizeValue = 22
local currentInteractDelay = 0.25
local currentWsValue = 32
local currentJpValue = 80
local HITBOX_SIZE = Vector3.new(currentSizeValue, currentSizeValue, currentSizeValue)
-- Lưu thông số gốc của Lighting để khôi phục khi tắt Fullbright
local origLighting = {
Brightness = Lighting.Brightness,
ClockTime = Lighting.ClockTime,
FogEnd = Lighting.FogEnd,
GlobalShadows = Lighting.GlobalShadows,
Ambient = Lighting.Ambient,
OutdoorAmbient = Lighting.OutdoorAmbient
}
-- Bảng lưu dữ liệu (Weak Table tự động giải phóng RAM)
local originalData = setmetatable({}, { __mode = "k" })
local espObjects = setmetatable({}, { __mode = "k" })
-- ================= TẠO GUI GỌN NHẸ =================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCHitboxCompactGUI"
screenGui.ResetOnSpawn = false
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
_G.HitboxGui = screenGui
-- Khung chính
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 265, 0, 330)
mainFrame.Position = UDim2.new(1, -280, 0.5, -165)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame
-- Hàm hỗ trợ tạo nút bật/tắt
local function createToggleButton(name, text, posY, hasInputRight)
local btn = Instance.new("TextButton")
btn.Name = name
btn.Size = hasInputRight and UDim2.new(1, -74, 0, 30) or UDim2.new(1, -16, 0, 30)
btn.Position = UDim2.new(0, 8, 0, posY)
btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 12
btn.Text = text
btn.Parent = mainFrame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = btn
return btn
end
-- Hàm hỗ trợ tạo nút chia đôi cột
local function createMiniToggleButton(name, text, posX, widthScale, posY)
local btn = Instance.new("TextButton")
btn.Name = name
btn.Size = UDim2.new(widthScale, -6, 0, 30)
btn.Position = UDim2.new(posX, 4, 0, posY)
btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 11
btn.Text = text
btn.Parent = mainFrame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = btn
return btn
end
-- Hàm hỗ trợ tạo ô nhập liệu nằm bên phải nút toggle
local function createRightInput(defaultVal, posY, placeholder)
local box = Instance.new("TextBox")
box.Size = UDim2.new(0, 52, 0, 30)
box.Position = UDim2.new(1, -60, 0, posY)
box.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
box.TextColor3 = Color3.fromRGB(255, 255, 255)
box.PlaceholderText = placeholder
box.Text = tostring(defaultVal)
box.Font = Enum.Font.GothamBold
box.TextSize = 12
box.ClearTextOnFocus = false
box.Parent = mainFrame
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = box
return box
end
-- Hàng 1: Ô lọc tên quái (Chỉ áp dụng cho Hitbox)
local filterInput = Instance.new("TextBox")
filterInput.Name = "FilterInput"
filterInput.Size = UDim2.new(1, -16, 0, 28)
filterInput.Position = UDim2.new(0, 8, 0, 8)
filterInput.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
filterInput.TextColor3 = Color3.fromRGB(255, 255, 255)
filterInput.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
filterInput.PlaceholderText = "Lọc tên Hitbox (Trống = Tất cả)..."
filterInput.Text = ""
filterInput.Font = Enum.Font.GothamSemibold
filterInput.TextSize = 11
filterInput.ClearTextOnFocus = false
filterInput.Parent = mainFrame
local filterCorner = Instance.new("UICorner")
filterCorner.CornerRadius = UDim.new(0, 6)
filterCorner.Parent = filterInput
-- Hàng 2: Hitbox NPC + Ô nhập kích thước
local hitboxBtn = createToggleButton("HitboxBtn", "Hitbox NPC: TẮT [Num 0]", 42, true)
local sizeInput = createRightInput(currentSizeValue, 42, "Size")
-- Hàng 3: ESP Highlight
local espHighlightBtn = createToggleButton("EspHighlightBtn", "ESP Viền (Highlight): TẮT", 78, false)
-- Hàng 4: ESP Tên & ESP Máu (Text dưới chân)
local espNameBtn = createMiniToggleButton("EspNameBtn", "ESP Tên: TẮT", 0.015, 0.485, 114)
local espHealthBtn = createMiniToggleButton("EspHealthBtn", "ESP Máu: TẮT", 0.50, 0.485, 114)
-- Hàng 5: Tự động tương tác + Ô nhập giây
local interactBtn = createToggleButton("InteractBtn", "Tự động tương tác: TẮT", 150, true)
local delayInput = createRightInput(currentInteractDelay, 150, "Giây")
-- Hàng 6: WalkSpeed + Ô nhập tốc độ
local wsBtn = createToggleButton("WsBtn", "Tốc độ chạy (WS): TẮT", 186, true)
local wsInput = createRightInput(currentWsValue, 186, "WS")
-- Hàng 7: JumpPower + Ô nhập lực nhảy
local jpBtn = createToggleButton("JpBtn", "Lực nhảy (JP): TẮT", 222, true)
local jpInput = createRightInput(currentJpValue, 222, "JP")
-- Hàng 8: Fullbright
local fbBtn = createToggleButton("FbBtn", "Sáng bản đồ (Fullbright): TẮT", 258, false)
-- Dòng ghi chú phím tắt ẩn GUI ở đáy khung
local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 0, 16)
hintLabel.Position = UDim2.new(0, 8, 1, -22)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(140, 140, 155)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 10
hintLabel.Text = "Nhấn [Right Ctrl] để Ẩn / Hiện bảng điều khiển"
hintLabel.Parent = mainFrame
-- =======================================================
-- Hàm tìm bộ phận mục tiêu thông minh (Hỗ trợ cả quái thường & Custom Mesh)
local function getTargetPart(model)
if not model or not model:IsA("Model") then return nil end
local head = model:FindFirstChild("Head")
if head and head:IsA("BasePart") then return head end
local root = model:FindFirstChild("HumanoidRootPart")
if root and root:IsA("BasePart") then return root end
if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
return model.PrimaryPart
end
local bestPart = nil
local maxVolume = 0
for _, child in ipairs(model:GetDescendants()) do
if child:IsA("BasePart") then
local vol = child.Size.X * child.Size.Y * child.Size.Z
if vol > maxVolume then
maxVolume = vol
bestPart = child
end
end
end
return bestPart
end
-- Hàm tìm bộ phận dưới chân NPC để gắn ESP Text
local function getFeetPart(model)
return model:FindFirstChild("HumanoidRootPart")
or model:FindFirstChild("LowerTorso")
or model:FindFirstChild("Torso")
or getTargetPart(model)
end
-- Hàm nhận diện đệ tử / đồng đội / vật triệu hồi đi kèm người chơi
local function isPlayerCompanion(model)
local allPlayers = Players:GetPlayers()
for _, plr in ipairs(allPlayers) do
if plr.Character and model:IsDescendantOf(plr.Character) then
return true
end
end
local ownerKeys = { "Owner", "Creator", "Master", "Summoner", "Player", "OwnedBy" }
for _, key in ipairs(ownerKeys) do
local valObj = model:FindFirstChild(key, true)
if valObj then
if valObj:IsA("ObjectValue") and valObj.Value and valObj.Value:IsA("Player") then
return true
elseif valObj:IsA("StringValue") then
for _, plr in ipairs(allPlayers) do
if valObj.Value == plr.Name or valObj.Value == plr.DisplayName then
return true
end
end
elseif valObj:IsA("IntValue") or valObj:IsA("NumberValue") then
for _, plr in ipairs(allPlayers) do
if valObj.Value == plr.UserId then
return true
end
end
end
end
end
for attrName, attrVal in pairs(model:GetAttributes()) do
local lowerName = string.lower(attrName)
if string.find(lowerName, "owner") or string.find(lowerName, "creator") or string.find(lowerName, "summon") or string.find(lowerName, "master") then
if attrVal ~= nil and attrVal ~= "" and attrVal ~= 0 then
return true
end
end
for _, plr in ipairs(allPlayers) do
if attrVal == plr.Name or attrVal == plr.UserId then
return true
end
end
end
local modelNameLower = string.lower(model.Name)
for _, plr in ipairs(allPlayers) do
if string.find(modelNameLower, string.lower(plr.Name), 1, true) then
return true
end
end
if LocalPlayer.Team then
local teamVal = model:FindFirstChild("Team") or model:FindFirstChild("TeamColor")
if teamVal then
if teamVal:IsA("ObjectValue") and teamVal.Value == LocalPlayer.Team then return true end
if teamVal:IsA("BrickColorValue") and teamVal.Value == LocalPlayer.TeamColor then return true end
if teamVal:IsA("StringValue") and teamVal.Value == LocalPlayer.Team.Name then return true end
end
end
return false
end
-- Hàm kiểm tra NPC cơ bản (Dùng chung cho cả ESP và Hitbox)
local function isBaseNPC(model)
if not model or not model:IsA("Model") then return false end
local humanoid = model:FindFirstChildOfClass("Humanoid")
if not humanoid or humanoid.Health <= 0 then return false end
if Players:GetPlayerFromCharacter(model) then return false end
local targetPart = getTargetPart(model)
if not targetPart then return false end
return true
end
-- Hàm kiểm tra NPC hợp lệ cho Hitbox (Loại trừ đồng đội + Áp dụng bộ lọc tên)
local function isValidHitboxTarget(model)
if not isBaseNPC(model) then return false end
if isPlayerCompanion(model) then return false end
if targetFilterText ~= "" then
if not string.find(string.lower(model.Name), targetFilterText, 1, true) then
return false
end
end
return true
end
-- ================= CHỨC NĂNG 1: HITBOX =================
local function applyHitbox(model, enable)
local targetPart = getTargetPart(model)
if not targetPart then return end
if enable then
if not isValidHitboxTarget(model) then
if originalData[targetPart] then
applyHitbox(model, false)
end
return
end
if not originalData[targetPart] then
originalData[targetPart] = {
Size = targetPart.Size,
Material = targetPart.Material,
BrickColor = targetPart.BrickColor,
Transparency = targetPart.Transparency,
CanCollide = targetPart.CanCollide,
Massless = targetPart.Massless
}
local humanoid = model:FindFirstChildOfClass("Humanoid")
if humanoid then
humanoid.Died:Once(function()
applyHitbox(model, false)
end)
end
end
if targetPart.Size ~= HITBOX_SIZE then
targetPart.Size = HITBOX_SIZE
targetPart.Material = Enum.Material.Neon
targetPart.BrickColor = BrickColor.new("Really blue")
targetPart.Transparency = 0.92
targetPart.CanCollide = false
targetPart.Massless = true
end
else
local saved = originalData[targetPart]
if saved then
targetPart.Size = saved.Size
targetPart.Material = saved.Material
targetPart.BrickColor = saved.BrickColor
targetPart.Transparency = saved.Transparency
targetPart.CanCollide = saved.CanCollide
targetPart.Massless = saved.Massless
originalData[targetPart] = nil
end
end
end
local function toggleHitboxAll(state)
for _, obj in ipairs(workspace:GetDescendants()) do
if obj:IsA("Humanoid") and obj.Parent then
applyHitbox(obj.Parent, state)
end
end
hitboxBtn.Text = state and "Hitbox NPC: BẬT [Num 0]" or "Hitbox NPC: TẮT [Num 0]"
hitboxBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
end
-- ================= CHỨC NĂNG 2: ESP TEXT DƯỚI CHÂN & HIGHLIGHT =================
local function clearESP(model)
local data = espObjects[model]
if data then
if data.conn then data.conn:Disconnect() end
if data.diedConn then data.diedConn:Disconnect() end
if data.highlight then data.highlight:Destroy() end
if data.billboard then data.billboard:Destroy() end
espObjects[model] = nil
end
end
local function updateESP(model)
local anyEspActive = isEspHighlightEnabled or isEspNameEnabled or isEspHealthEnabled
if not anyEspActive or not isBaseNPC(model) then
clearESP(model)
return
end
local feetPart = getFeetPart(model)
local humanoid = model:FindFirstChildOfClass("Humanoid")
if not feetPart or not humanoid then
clearESP(model)
return
end
local isAlly = isPlayerCompanion(model)
local hlFillColor = isAlly and Color3.fromRGB(40, 180, 255) or Color3.fromRGB(255, 60, 60)
local textColor = isAlly and Color3.fromRGB(255, 190, 45) or Color3.fromRGB(255, 255, 255)
local data = espObjects[model]
if not data then
data = {}
espObjects[model] = data
data.diedConn = humanoid.Died:Once(function()
clearESP(model)
end)
end
-- 1. Xử lý Highlight (Viền sáng: Xanh cho đồng đội, Đỏ cho địch)
if isEspHighlightEnabled then
if not data.highlight then
local hl = Instance.new("Highlight")
hl.Name = "NPC_ESP_Highlight"
hl.OutlineColor = Color3.fromRGB(255, 255, 255)
hl.FillTransparency = 0.65
hl.OutlineTransparency = 0.2
hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hl.Parent = model
data.highlight = hl
end
data.highlight.FillColor = hlFillColor
else
if data.highlight then
data.highlight:Destroy()
data.highlight = nil
end
end
-- 2. Xử lý Text dưới chân NPC ngăn cách bởi dấu | (Vàng cam cho đồng đội, Trắng cho địch)
if isEspNameEnabled or isEspHealthEnabled then
if not data.billboard then
local bb = Instance.new("BillboardGui")
bb.Name = "NPC_ESP_FeetTag"
bb.Adornee = feetPart
bb.Size = UDim2.new(0, 220, 0, 24)
bb.StudsOffset = Vector3.new(0, -3.2, 0)
bb.AlwaysOnTop = true
bb.Parent = feetPart
local infoLbl = Instance.new("TextLabel")
infoLbl.Name = "InfoLabel"
infoLbl.Size = UDim2.new(1, 0, 1, 0)
infoLbl.BackgroundTransparency = 1
infoLbl.TextStrokeTransparency = 0.25
infoLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
infoLbl.Font = Enum.Font.GothamBold
infoLbl.TextSize = 12
infoLbl.Parent = bb
data.billboard = bb
data.infoLbl = infoLbl
data.conn = humanoid.HealthChanged:Connect(function(hp)
if hp <= 0 then
clearESP(model)
else
updateESP(model)
end
end)
end
data.infoLbl.TextColor3 = textColor
local parts = {}
if isEspNameEnabled then
table.insert(parts, model.Name)
end
if isEspHealthEnabled then
local curHp = math.floor(math.max(humanoid.Health, 0))
local maxHp = math.floor(math.max(humanoid.MaxHealth, 1))
table.insert(parts, string.format("%d/%d HP", curHp, maxHp))
end
data.infoLbl.Text = table.concat(parts, " | ")
else
if data.conn then data.conn:Disconnect() data.conn = nil end
if data.billboard then data.billboard:Destroy() data.billboard = nil end
end
end
local function refreshAllESP()
for _, obj in ipairs(workspace:GetDescendants()) do
if obj:IsA("Humanoid") and obj.Parent then
updateESP(obj.Parent)
end
end
end
-- ================= CHỨC NĂNG 3: TỰ ĐỘNG TƯƠNG TÁC =================
_G.AutoInteractLoop = true
task.spawn(function()
while _G.AutoInteractLoop do
if isInteractEnabled then
local char = LocalPlayer.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
if root then
for _, obj in ipairs(workspace:GetDescendants()) do
if obj:IsA("ProximityPrompt") and obj.Enabled then
local parentPart = obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstChildWhichIsA("BasePart")
if parentPart and (parentPart.Position - root.Position).Magnitude <= (obj.MaxActivationDistance + 5) then
if fireproximityprompt then
fireproximityprompt(obj)
else
obj:InputHoldBegin()
task.wait(obj.HoldDuration)
obj:InputHoldEnd()
end
end
end
end
end
task.wait(currentInteractDelay)
else
task.wait(0.2)
end
end
end)
-- ================= CHỨC NĂNG 4: WALKSPEED & JUMPPOWER =================
local function applyMovementStats()
local char = LocalPlayer.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not hum then return end
if isWsEnabled then
hum.WalkSpeed = currentWsValue
else
hum.WalkSpeed = 16
end
if isJpEnabled then
hum.UseJumpPower = true
hum.JumpPower = currentJpValue
else
hum.JumpPower = 50
end
end
_G.CharAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
local hum = char:WaitForChild("Humanoid", 5)
if hum then
task.wait(0.1)
applyMovementStats()
end
end)
-- ================= CHỨC NĂNG 5: FULLBRIGHT =================
local function toggleFullbright(state)
if _G.FullbrightConn then
_G.FullbrightConn:Disconnect()
_G.FullbrightConn = nil
end
if state then
local function setBright()
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.FogEnd = 100000
Lighting.GlobalShadows = false
Lighting.Ambient = Color3.fromRGB(178, 178, 178)
Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end
setBright()
_G.FullbrightConn = Lighting.LightingChanged:Connect(setBright)
else
Lighting.Brightness = origLighting.Brightness
Lighting.ClockTime = origLighting.ClockTime
Lighting.FogEnd = origLighting.FogEnd
Lighting.GlobalShadows = origLighting.GlobalShadows
Lighting.Ambient = origLighting.Ambient
Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
end
fbBtn.Text = state and "Sáng bản đồ (Fullbright): BẬT" or "Sáng bản đồ (Fullbright): TẮT"
fbBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
end
-- ================= SỰ KIỆN NÚT BẤM & Ô NHẬP LIỆU =================
filterInput.FocusLost:Connect(function()
targetFilterText = string.lower(filterInput.Text:match("^%s*(.-)%s*$") or "")
if isHitboxEnabled then toggleHitboxAll(true) end
end)
hitboxBtn.MouseButton1Click:Connect(function()
isHitboxEnabled = not isHitboxEnabled
toggleHitboxAll(isHitboxEnabled)
end)
espHighlightBtn.MouseButton1Click:Connect(function()
isEspHighlightEnabled = not isEspHighlightEnabled
espHighlightBtn.Text = isEspHighlightEnabled and "ESP Viền (Highlight): BẬT" or "ESP Viền (Highlight): TẮT"
espHighlightBtn.BackgroundColor3 = isEspHighlightEnabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
refreshAllESP()
end)
espNameBtn.MouseButton1Click:Connect(function()
isEspNameEnabled = not isEspNameEnabled
espNameBtn.Text = isEspNameEnabled and "ESP Tên: BẬT" or "ESP Tên: TẮT"
espNameBtn.BackgroundColor3 = isEspNameEnabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
refreshAllESP()
end)
espHealthBtn.MouseButton1Click:Connect(function()
isEspHealthEnabled = not isEspHealthEnabled
espHealthBtn.Text = isEspHealthEnabled and "ESP Máu: BẬT" or "ESP Máu: TẮT"
espHealthBtn.BackgroundColor3 = isEspHealthEnabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
refreshAllESP()
end)
interactBtn.MouseButton1Click:Connect(function()
isInteractEnabled = not isInteractEnabled
interactBtn.Text = isInteractEnabled and "Tự động tương tác: BẬT" or "Tự động tương tác: TẮT"
interactBtn.BackgroundColor3 = isInteractEnabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
end)
wsBtn.MouseButton1Click:Connect(function()
isWsEnabled = not isWsEnabled
wsBtn.Text = isWsEnabled and "Tốc độ chạy (WS): BẬT" or "Tốc độ chạy (WS): TẮT"
wsBtn.BackgroundColor3 = isWsEnabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
applyMovementStats()
end)
jpBtn.MouseButton1Click:Connect(function()
isJpEnabled = not isJpEnabled
jpBtn.Text = isJpEnabled and "Lực nhảy (JP): BẬT" or "Lực nhảy (JP): TẮT"
jpBtn.BackgroundColor3 = isJpEnabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
applyMovementStats()
end)
fbBtn.MouseButton1Click:Connect(function()
isFullbrightEnabled = not isFullbrightEnabled
toggleFullbright(isFullbrightEnabled)
end)
-- Xử lý nhập số cho các ô bên phải
sizeInput.FocusLost:Connect(function()
local num = tonumber(sizeInput.Text)
if num and num > 0 then
currentSizeValue = num
HITBOX_SIZE = Vector3.new(num, num, num)
sizeInput.Text = tostring(num)
if isHitboxEnabled then toggleHitboxAll(true) end
else
sizeInput.Text = tostring(currentSizeValue)
end
end)
delayInput.FocusLost:Connect(function()
local num = tonumber(delayInput.Text)
if num and num >= 0.05 then
num = math.clamp(num, 0.05, 60)
currentInteractDelay = num
delayInput.Text = tostring(num)
else
delayInput.Text = tostring(currentInteractDelay)
end
end)
wsInput.FocusLost:Connect(function()
local num = tonumber(wsInput.Text)
if num and num > 0 then
currentWsValue = num
wsInput.Text = tostring(num)
if isWsEnabled then applyMovementStats() end
else
wsInput.Text = tostring(currentWsValue)
end
end)
jpInput.FocusLost:Connect(function()
local num = tonumber(jpInput.Text)
if num and num > 0 then
currentJpValue = num
jpInput.Text = tostring(num)
if isJpEnabled then applyMovementStats() end
else
jpInput.Text = tostring(currentJpValue)
end
end)
-- 2. Lắng nghe NPC mới xuất hiện trong workspace
_G.HitboxAddedConn = workspace.DescendantAdded:Connect(function(descendant)
local anyEspActive = isEspHighlightEnabled or isEspNameEnabled or isEspHealthEnabled
if not isHitboxEnabled and not anyEspActive then return end
if descendant:IsA("Humanoid") then
local npcModel = descendant.Parent
if not npcModel then return end
task.wait(0.35)
local targetPart = getTargetPart(npcModel)
if not targetPart then
npcModel.ChildAdded:Wait()
targetPart = getTargetPart(npcModel)
end
if targetPart then
if isHitboxEnabled then applyHitbox(npcModel, true) end
if anyEspActive then updateESP(npcModel) end
end
end
end)
-- 3. Gán phím Keypad 0 (Bật/Tắt Hitbox) và Right Ctrl (Ẩn/Hiện GUI)
_G.HitboxKeybind = UserInputService.InputBegan:Connect(function(input, gameProcessed)
if input.KeyCode == Enum.KeyCode.RightControl then
mainFrame.Visible = not mainFrame.Visible
return
end
if gameProcessed then return end
if input.KeyCode == Enum.KeyCode.KeypadZero then
isHitboxEnabled = not isHitboxEnabled
toggleHitboxAll(isHitboxEnabled)
end
end)
