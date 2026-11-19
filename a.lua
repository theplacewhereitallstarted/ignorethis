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
local isEspEnabled = false
local isInteractEnabled = false

local currentSizeValue = 22
local currentInteractDelay = 0.25 -- Thời gian chờ mặc định (giây)
local HEAD_SIZE = Vector3.new(currentSizeValue, currentSizeValue, currentSizeValue)

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
mainFrame.Size = UDim2.new(0, 260, 0, 142)
mainFrame.Position = UDim2.new(1, -275, 0.5, -71)
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

-- Hàng 1: Hitbox NPC + Ô nhập kích thước đầu bên phải
local hitboxBtn = createToggleButton("HitboxBtn", "Hitbox NPC: TẮT [Num 0]", 8, true)
local sizeInput = createRightInput(currentSizeValue, 8, "Size")

-- Hàng 2: ESP NPC
local espBtn = createToggleButton("EspBtn", "ESP NPC: TẮT", 46, false)

-- Hàng 3: Tự động tương tác + Ô nhập giây bên phải
local interactBtn = createToggleButton("InteractBtn", "Tự động tương tác: TẮT", 84, true)
local delayInput = createRightInput(currentInteractDelay, 84, "Giây")

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

-- Hàm kiểm tra NPC hợp lệ
local function isValidNPC(model)
	if not model or not model:IsA("Model") then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	if not humanoid or not head or not head:IsA("BasePart") then return false end
	if Players:GetPlayerFromCharacter(model) then return false end
	if humanoid.Health <= 0 then return false end
	return true
end

-- ================= CHỨC NĂNG 1: HITBOX =================
local function applyHitbox(model, enable)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end

	if enable then
		if not isValidNPC(model) then return end

		if not originalData[head] then
			originalData[head] = {
				Size = head.Size,
				Material = head.Material,
				BrickColor = head.BrickColor,
				Transparency = head.Transparency,
				CanCollide = head.CanCollide,
				Massless = head.Massless
			}

			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Once(function()
					applyHitbox(model, false)
				end)
			end
		end

		if head.Size ~= HEAD_SIZE then
			head.Size = HEAD_SIZE
			head.Material = Enum.Material.Neon
			head.BrickColor = BrickColor.new("Really blue")
			head.Transparency = 0.92
			head.CanCollide = false
			head.Massless = true
		end
	else
		local saved = originalData[head]
		if saved then
			head.Size = saved.Size
			head.Material = saved.Material
			head.BrickColor = saved.BrickColor
			head.Transparency = saved.Transparency
			head.CanCollide = saved.CanCollide
			head.Massless = saved.Massless
			originalData[head] = nil
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

-- ================= CHỨC NĂNG 2: ESP NPC =================
local function applyESP(model, enable)
	if enable then
		if not isValidNPC(model) then return end
		if espObjects[model] then return end

		local head = model:FindFirstChild("Head")
		local humanoid = model:FindFirstChildOfClass("Humanoid")

		-- Tạo viền sáng xuyên tường (Highlight)
		local highlight = Instance.new("Highlight")
		highlight.Name = "NPC_ESP_Highlight"
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.65
		highlight.OutlineTransparency = 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = model

		-- Tạo bảng tên & máu trên đầu
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NPC_ESP_Tag"
		billboard.Adornee = head
		billboard.Size = UDim2.new(0, 160, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
		textLabel.TextStrokeTransparency = 0.3
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextSize = 12
		textLabel.Text = string.format("%s [%d HP]", model.Name, math.floor(humanoid.Health))
		textLabel.Parent = billboard

		local hpConn = humanoid.HealthChanged:Connect(function(hp)
			if hp <= 0 then
				applyESP(model, false)
			else
				textLabel.Text = string.format("%s [%d HP]", model.Name, math.floor(hp))
			end
		end)

		espObjects[model] = { highlight = highlight, billboard = billboard, conn = hpConn }
	else
		local data = espObjects[model]
		if data then
			if data.conn then data.conn:Disconnect() end
			if data.highlight then data.highlight:Destroy() end
			if data.billboard then data.billboard:Destroy() end
			espObjects[model] = nil
		end
	end
end

local function toggleEspAll(state)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj.Parent then
			applyESP(obj.Parent, state)
		end
	end
	espBtn.Text = state and "ESP NPC: BẬT" or "ESP NPC: TẮT"
	espBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
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

espBtn.MouseButton1Click:Connect(function()
	isEspEnabled = not isEspEnabled
	toggleEspAll(isEspEnabled)
end)

interactBtn.MouseButton1Click:Connect(function()
	isInteractEnabled = not isInteractEnabled
	toggleInteract(isInteractEnabled)
end)

sizeInput.FocusLost:Connect(function()
Hãy thận trọng khi sử dụng mã.
local num = tonumber(sizeInput.Text)
if num and num > 0 then
-- Đã loại bỏ giới hạn con số tối đa
currentSizeValue = num
HEAD_SIZE = Vector3.new(num, num, num)
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
if not isHitboxEnabled and not isEspEnabled then return end
if descendant:IsA("Humanoid") then
local npcModel = descendant.Parent
if not npcModel then return end
local head = npcModel:WaitForChild("Head", 3)
if head then
if isHitboxEnabled then applyHitbox(npcModel, true) end
if isEspEnabled then applyESP(npcModel, true) end
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
