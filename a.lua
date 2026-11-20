local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- 1. Dọn dẹp toàn bộ kết nối & GUI cũ nếu chạy lại script
if _G.HitboxAddedConn then _G.HitboxAddedConn:Disconnect() _G.HitboxAddedConn = nil end
if _G.HitboxKeybind then _G.HitboxKeybind:Disconnect() _G.HitboxKeybind = nil end
if _G.HitboxGui then _G.HitboxGui:Destroy() _G.HitboxGui = nil end
if _G.AutoInteractLoop then _G.AutoInteractLoop = false end

-- Trạng thái mặc định: TẮT toàn bộ khi khởi động
local isHitboxEnabled = false
local isEspHighlightEnabled = false
local isEspNameEnabled = false
local isEspHealthEnabled = false
local isInteractEnabled = false

local currentSizeValue = 22
local currentInteractDelay = 0.25 -- Thời gian chờ mặc định (giây)
local HITBOX_SIZE = Vector3.new(currentSizeValue, currentSizeValue, currentSizeValue)

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
mainFrame.Size = UDim2.new(0, 260, 0, 180)
mainFrame.Position = UDim2.new(1, -275, 0.5, -90)
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
	btn.Size = hasInputRight and UDim2.new(1, -74, 0, 32) or UDim2.new(1, -16, 0, 32)
	btn.Position = UDim2.new(0, 8, 0, posY)
	btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50) -- Mặc định đỏ (TẮT)
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

-- Hàm hỗ trợ tạo nút nhỏ cho hàng ESP 3 cột
local function createMiniToggleButton(name, text, posX, widthScale, posY)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(widthScale, -6, 0, 32)
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
	box.Size = UDim2.new(0, 52, 0, 32)
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

-- Hàng 1: Hitbox NPC + Ô nhập kích thước bên phải
local hitboxBtn = createToggleButton("HitboxBtn", "Hitbox NPC: TẮT [Num 0]", 8, true)
local sizeInput = createRightInput(currentSizeValue, 8, "Size")

-- Hàng 2: ESP Highlight (Full chiều ngang)
local espHighlightBtn = createToggleButton("EspHighlightBtn", "ESP Viền (Highlight): TẮT", 46, false)

-- Hàng 3: ESP Tên & ESP Thanh Máu (Chia 2 cột ngang nhau)
local espNameBtn = createMiniToggleButton("EspNameBtn", "ESP Tên: TẮT", 0.015, 0.485, 84)
local espHealthBtn = createMiniToggleButton("EspHealthBtn", "ESP Máu: TẮT", 0.50, 0.485, 84)

-- Hàng 4: Tự động tương tác + Ô nhập giây bên phải
local interactBtn = createToggleButton("InteractBtn", "Tự động tương tác: TẮT", 122, true)
local delayInput = createRightInput(currentInteractDelay, 122, "Giây")

-- Dòng ghi chú phím tắt ẩn GUI ở đáy khung
local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 0, 16)
hintLabel.Position = UDim2.new(0, 8, 1, -20)
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

-- Hàm kiểm tra NPC hợp lệ
local function isValidNPC(model)
	if not model or not model:IsA("Model") then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if Players:GetPlayerFromCharacter(model) then return false end

	local targetPart = getTargetPart(model)
	if not targetPart then return false end

	return true
end

-- ================= CHỨC NĂNG 1: HITBOX =================
local function applyHitbox(model, enable)
	local targetPart = getTargetPart(model)
	if not targetPart then return end

	if enable then
		if not isValidNPC(model) then return end

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

-- ================= CHỨC NĂNG 2: ESP ĐỘC LẬP (VIỀN / TÊN / MÁU) =================
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
	if not anyEspActive or not isValidNPC(model) then
		clearESP(model)
		return
	end

	local targetPart = getTargetPart(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not targetPart or not humanoid then
		clearESP(model)
		return
	end

	local data = espObjects[model]
	if not data then
		data = {}
		espObjects[model] = data

		data.diedConn = humanoid.Died:Once(function()
			clearESP(model)
		end)
	end

	-- 1. Xử lý Highlight (Viền sáng)
	if isEspHighlightEnabled then
		if not data.highlight then
			local hl = Instance.new("Highlight")
			hl.Name = "NPC_ESP_Highlight"
			hl.FillColor = Color3.fromRGB(255, 60, 60)
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.65
			hl.OutlineTransparency = 0.2
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = model
			data.highlight = hl
		end
	else
		if data.highlight then
			data.highlight:Destroy()
			data.highlight = nil
		end
	end

	-- 2. Xử lý BillboardGui (Tên & Thanh Máu)
	if isEspNameEnabled or isEspHealthEnabled then
		if not data.billboard then
			local bb = Instance.new("BillboardGui")
			bb.Name = "NPC_ESP_Tag"
			bb.Adornee = targetPart
			bb.Size = UDim2.new(0, 140, 0, 38)
			bb.StudsOffset = Vector3.new(0, 2.8, 0)
			bb.AlwaysOnTop = true
			bb.Parent = targetPart

			-- Nhãn Tên
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Name = "NameLabel"
			nameLbl.Size = UDim2.new(1, 0, 0, 18)
			nameLbl.Position = UDim2.new(0, 0, 0, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.TextColor3 = Color3.fromRGB(255, 235, 110)
nameLbl.TextStrokeTransparency = 0.3
nameLbl.Font = Enum.Font.GothamBold
nameLbl.TextSize = 12
nameLbl.Text = model.Name
nameLbl.Parent = bb
-- Khung nền thanh máu
local hpBg = Instance.new("Frame")
hpBg.Name = "HealthBg"
hpBg.Size = UDim2.new(0.85, 0, 0, 10)
hpBg.Position = UDim2.new(0.075, 0, 0, 20)
hpBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
hpBg.BorderSizePixel = 0
hpBg.Parent = bb
local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 4)
bgCorner.Parent = hpBg
-- Thanh máu chạy
local hpFill = Instance.new("Frame")
hpFill.Name = "HealthFill"
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(45, 210, 90)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBg
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 4)
fillCorner.Parent = hpFill
-- Số HP đè lên thanh máu
local hpText = Instance.new("TextLabel")
hpText.Name = "HealthText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.TextStrokeTransparency = 0.4
hpText.Font = Enum.Font.GothamBold
hpText.TextSize = 9
hpText.Parent = hpBg
local function refreshHealth()
local maxHp = math.max(humanoid.MaxHealth, 1)
local curHp = math.clamp(humanoid.Health, 0, maxHp)
local ratio = curHp / maxHp
hpFill.Size = UDim2.new(ratio, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.85, 0.9)
hpText.Text = string.format("%d / %d", math.floor(curHp), math.floor(maxHp))
end
refreshHealth()
data.conn = humanoid.HealthChanged:Connect(function(hp)
if hp <= 0 then
clearESP(model)
else
refreshHealth()
end
end)
data.billboard = bb
data.nameLbl = nameLbl
data.hpBg = hpBg
end
-- Cập nhật hiển thị từng thành phần bên trong Billboard
data.nameLbl.Visible = isEspNameEnabled
data.hpBg.Visible = isEspHealthEnabled
data.hpBg.Position = isEspNameEnabled and UDim2.new(0.075, 0, 0, 20) or UDim2.new(0.075, 0, 0, 10)
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
local function toggleInteract(state)
interactBtn.Text = state and "Tự động tương tác: BẬT" or "Tự động tương tác: TẮT"
interactBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
end
-- ================= SỰ KIỆN NÚT BẤM & PHÍM TẮT =================
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
toggleInteract(isInteractEnabled)
end)
sizeInput.FocusLost:Connect(function()
local num = tonumber(sizeInput.Text)
if num and num > 0 then
currentSizeValue = num
HITBOX_SIZE = Vector3.new(num, num, num)
sizeInput.Text = tostring(num)
if isHitboxEnabled then
toggleHitboxAll(true)
end
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
-- 2. Lắng nghe NPC mới xuất hiện trong workspace
_G.HitboxAddedConn = workspace.DescendantAdded:Connect(function(descendant)
local anyEspActive = isEspHighlightEnabled or isEspNameEnabled or isEspHealthEnabled
if not isHitboxEnabled and not anyEspActive then return end
if descendant:IsA("Humanoid") then
local npcModel = descendant.Parent
if not npcModel then return end
task.wait(0.2)
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
