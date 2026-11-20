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
local state = {
npcHitbox = false,
plrHitbox = false,
espHighlight = false,
espName = false,
espHealth = false,
interact = false,
ws = false,
jp = false,
fullbright = false
}
-- Thông số cấu hình mặc định
local config = {
npcSize = 22,
npcTrans = 0.92,
plrSize = 15,
plrTrans = 0.85,
interactDelay = 0.25,
ws = 32,
jp = 80
}
-- Bảng lưu Keybind (Mặc định trống hoàn toàn theo yêu cầu)
local keybinds = {
npcHitbox = nil,
plrHitbox = nil,
espHighlight = nil,
espName = nil,
espHealth = nil,
interact = nil,
ws = nil,
jp = nil,
fullbright = nil
}
local waitingForKey = nil
local keybindButtons = {}
local blacklistTerms = {}
local isHitboxCardExpanded = true
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
-- ================= TẠO GUI HỆ THỐNG TAB =================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModularCombatGUI"
screenGui.ResetOnSpawn = false
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
_G.HitboxGui = screenGui
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 285, 0, 415)
mainFrame.Position = UDim2.new(1, -300, 0.5, -207)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame
-- Thanh chuyển Tab trên cùng
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 28)
tabBar.Position = UDim2.new(0, 8, 0, 8)
tabBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame
local tabBarCorner = Instance.new("UICorner")
tabBarCorner.CornerRadius = UDim.new(0, 6)
tabBarCorner.Parent = tabBar
local function createTabBtn(text, posX)
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0.5, -4, 1, -4)
btn.Position = UDim2.new(posX, 2, 0, 2)
btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 12
btn.Text = text
btn.Parent = tabBar
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 5)
corner.Parent = btn
return btn
end
local mainTabBtn = createTabBtn("Chức năng", 0)
local keyTabBtn = createTabBtn("Keybinds", 0.5)
keyTabBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
keyTabBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
-- Container cho 2 Tab
local mainPage = Instance.new("Frame")
mainPage.Size = UDim2.new(1, -16, 1, -64)
mainPage.Position = UDim2.new(0, 8, 0, 42)
mainPage.BackgroundTransparency = 1
mainPage.Parent = mainFrame
local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 6)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = mainPage
local keyPage = Instance.new("ScrollingFrame")
keyPage.Size = UDim2.new(1, -16, 1, -64)
keyPage.Position = UDim2.new(0, 8, 0, 42)
keyPage.BackgroundTransparency = 1
keyPage.BorderSizePixel = 0
keyPage.ScrollBarThickness = 3
keyPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
keyPage.CanvasSize = UDim2.new(0, 0, 0, 0)
keyPage.Visible = false
keyPage.Parent = mainFrame
local keyLayout = Instance.new("UIListLayout")
keyLayout.Padding = UDim.new(0, 5)
keyLayout.SortOrder = Enum.SortOrder.LayoutOrder
keyLayout.Parent = keyPage
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
-- Hàm điều chỉnh chiều cao khung tự động khi thu gọn/mở rộng thẻ phụ
local function updateMainFrameHeight()
if mainPage.Visible then
local contentHeight = mainLayout.AbsoluteContentSize.Y
mainFrame.Size = UDim2.new(0, 285, 0, contentHeight + 68)
else
mainFrame.Size = UDim2.new(0, 285, 0, 360)
end
end
mainLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateMainFrameHeight)
-- Chuyển đổi Tab
mainTabBtn.MouseButton1Click:Connect(function()
mainPage.Visible = true
keyPage.Visible = false
mainTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
mainTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
keyTabBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
keyTabBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
updateMainFrameHeight()
end)
keyTabBtn.MouseButton1Click:Connect(function()
mainPage.Visible = false
keyPage.Visible = true
keyTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
keyTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mainTabBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
mainTabBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
updateMainFrameHeight()
end)
-- ================= THẺ PHỤ HITBOX (MAXIMIZE / MINIMIZE) =================
local hitboxCard = Instance.new("Frame")
hitboxCard.Name = "HitboxCard"
hitboxCard.LayoutOrder = 1
hitboxCard.Size = UDim2.new(1, 0, 0, 126)
hitboxCard.BackgroundColor3 = Color3.fromRGB(30, 30, 37)
hitboxCard.BorderSizePixel = 0
hitboxCard.ClipsDescendants = true
hitboxCard.Parent = mainPage
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 6)
cardCorner.Parent = hitboxCard
-- Tiêu đề thẻ phụ + Nút Thu gọn/Mở rộng
local cardHeader = Instance.new("Frame")
cardHeader.Size = UDim2.new(1, 0, 0, 26)
cardHeader.BackgroundColor3 = Color3.fromRGB(38, 38, 47)
cardHeader.BorderSizePixel = 0
cardHeader.Parent = hitboxCard
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 6)
headerCorner.Parent = cardHeader
local cardTitle = Instance.new("TextLabel")
cardTitle.Size = UDim2.new(1, -34, 1, 0)
cardTitle.Position = UDim2.new(0, 8, 0, 0)
cardTitle.BackgroundTransparency = 1
cardTitle.TextColor3 = Color3.fromRGB(220, 220, 235)
cardTitle.Font = Enum.Font.GothamBold
cardTitle.TextSize = 11
cardTitle.TextXAlignment = Enum.TextXAlignment.Left
cardTitle.Text = "Cấu hình Hitbox (NPCs & Players)"
cardTitle.Parent = cardHeader
local minMaxBtn = Instance.new("TextButton")
minMaxBtn.Size = UDim2.new(0, 22, 0, 20)
minMaxBtn.Position = UDim2.new(1, -25, 0, 3)
minMaxBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
minMaxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minMaxBtn.Font = Enum.Font.GothamBold
minMaxBtn.TextSize = 13
minMaxBtn.Text = "-"
minMaxBtn.Parent = cardHeader
local mmCorner = Instance.new("UICorner")
mmCorner.CornerRadius = UDim.new(0, 4)
mmCorner.Parent = minMaxBtn
minMaxBtn.MouseButton1Click:Connect(function()
isHitboxCardExpanded = not isHitboxCardExpanded
hitboxCard.Size = isHitboxCardExpanded and UDim2.new(1, 0, 0, 126) or UDim2.new(1, 0, 0, 26)
minMaxBtn.Text = isHitboxCardExpanded and "-" or "+"
updateMainFrameHeight()
end)
-- Ô nhập lọc bỏ (Blacklist) cách nhau bằng dấu phẩy
local filterInput = Instance.new("TextBox")
filterInput.Size = UDim2.new(1, -12, 0, 24)
filterInput.Position = UDim2.new(0, 6, 0, 30)
filterInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
filterInput.TextColor3 = Color3.fromRGB(255, 255, 255)
filterInput.PlaceholderColor3 = Color3.fromRGB(130, 130, 145)
filterInput.PlaceholderText = "Lọc bỏ tên (VD: shop, quest, guard)..."
filterInput.Text = ""
filterInput.Font = Enum.Font.Gotham
filterInput.TextSize = 11
filterInput.ClearTextOnFocus = false
filterInput.Parent = hitboxCard
local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 5)
fCorner.Parent = filterInput
-- Hàm tạo hàng Hitbox (Nút Toggle + Ô Size + Ô Transparency)
local function createHitboxSubRow(labelPrefix, defaultSize, defaultTrans, posY)
local row = Instance.new("Frame")
row.Size = UDim2.new(1, -12, 0, 28)
row.Position = UDim2.new(0, 6, 0, posY)
row.BackgroundTransparency = 1
row.Parent = hitboxCard
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -98, 1, 0)
btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 11
btn.Text = labelPrefix .. ": TẮT"
btn.Parent = row
local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(0, 5)
bCorner.Parent = btn
local sizeBox = Instance.new("TextBox")
sizeBox.Size = UDim2.new(0, 44, 1, 0)
sizeBox.Position = UDim2.new(1, -92, 0, 0)
sizeBox.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
sizeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeBox.PlaceholderText = "Size"
sizeBox.Text = tostring(defaultSize)
sizeBox.Font = Enum.Font.GothamBold
sizeBox.TextSize = 11
sizeBox.ClearTextOnFocus = false
sizeBox.Parent = row
local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 5)
sCorner.Parent = sizeBox
local transBox = Instance.new("TextBox")
transBox.Size = UDim2.new(0, 44, 1, 0)
transBox.Position = UDim2.new(1, -44, 0, 0)
transBox.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
transBox.TextColor3 = Color3.fromRGB(255, 255, 255)
transBox.PlaceholderText = "Trans"
transBox.Text = tostring(defaultTrans)
transBox.Font = Enum.Font.GothamBold
transBox.TextSize = 11
transBox.ClearTextOnFocus = false
transBox.Parent = row
local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 5)
tCorner.Parent = transBox
return btn, sizeBox, transBox
end
local npcHbBtn, npcSizeInput, npcTransInput = createHitboxSubRow("Hitbox NPCs", config.npcSize, config.npcTrans, 60)
local plrHbBtn, plrSizeInput, plrTransInput = createHitboxSubRow("Hitbox Players", config.plrSize, config.plrTrans, 92)
-- ================= CÁC HÀNG CHỨC NĂNG KHÁC TRÊN TAB CHÍNH =================
local function createStandardRow(order, text, hasInput, defaultVal, placeholder)
local row = Instance.new("Frame")
row.LayoutOrder = order
row.Size = UDim2.new(1, 0, 0, 30)
row.BackgroundTransparency = 1
row.Parent = mainPage
local btn = Instance.new("TextButton")
btn.Size = hasInput and UDim2.new(1, -58, 1, 0) or UDim2.new(1, 0, 1, 0)
btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 12
btn.Text = text
btn.Parent = row
local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(0, 6)
bCorner.Parent = btn
local box = nil
if hasInput then
box = Instance.new("TextBox")
box.Size = UDim2.new(0, 52, 1, 0)
box.Position = UDim2.new(1, -52, 0, 0)
box.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
box.TextColor3 = Color3.fromRGB(255, 255, 255)
box.PlaceholderText = placeholder
box.Text = tostring(defaultVal)
box.Font = Enum.Font.GothamBold
box.TextSize = 12
box.ClearTextOnFocus = false
box.Parent = row
local iCorner = Instance.new("UICorner")
iCorner.CornerRadius = UDim.new(0, 6)
iCorner.Parent = box
end
return btn, box
end
local espHighlightBtn = createStandardRow(2, "ESP Viền (Highlight): TẮT", false)
-- Hàng 3: ESP Tên & ESP Máu chia đôi
local espSplitRow = Instance.new("Frame")
espSplitRow.LayoutOrder = 3
espSplitRow.Size = UDim2.new(1, 0, 0, 30)
espSplitRow.BackgroundTransparency = 1
espSplitRow.Parent = mainPage
local espNameBtn = Instance.new("TextButton")
espNameBtn.Size = UDim2.new(0.5, -3, 1, 0)
espNameBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
espNameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
espNameBtn.Font = Enum.Font.GothamBold
espNameBtn.TextSize = 11
espNameBtn.Text = "ESP Tên: TẮT"
espNameBtn.Parent = espSplitRow
Instance.new("UICorner", espNameBtn).CornerRadius = UDim.new(0, 6)
local espHealthBtn = Instance.new("TextButton")
espHealthBtn.Size = UDim2.new(0.5, -3, 1, 0)
espHealthBtn.Position = UDim2.new(0.5, 3, 0, 0)
espHealthBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
espHealthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
espHealthBtn.Font = Enum.Font.GothamBold
espHealthBtn.TextSize = 11
espHealthBtn.Text = "ESP Máu: TẮT"
espHealthBtn.Parent = espSplitRow
Instance.new("UICorner", espHealthBtn).CornerRadius = UDim.new(0, 6)
local interactBtn, delayInput = createStandardRow(4, "Tự động tương tác: TẮT", true, config.interactDelay, "Giây")
local wsBtn, wsInput = createStandardRow(5, "Tốc độ chạy (WS): TẮT", true, config.ws, "WS")
local jpBtn, jpInput = createStandardRow(6, "Lực nhảy (JP): TẮT", true, config.jp, "JP")
local fbBtn = createStandardRow(7, "Sáng bản đồ (Fullbright): TẮT", false)
-- ================= TẠO CÁC HÀNG GÁN PHÍM TRONG TAB KEYBINDS =================
local keybindDefs = {
{ id = "npcHitbox", label = "Hitbox NPCs" },
{ id = "plrHitbox", label = "Hitbox Players" },
{ id = "espHighlight", label = "ESP Viền (Highlight)" },
{ id = "espName", label = "ESP Tên" },
{ id = "espHealth", label = "ESP Máu" },
{ id = "interact", label = "Tự động tương tác" },
{ id = "ws", label = "Tốc độ chạy (WS)" },
{ id = "jp", label = "Lực nhảy (JP)" },
{ id = "fullbright", label = "Sáng bản đồ" }
}
for idx, item in ipairs(keybindDefs) do
local row = Instance.new("Frame")
row.LayoutOrder = idx
row.Size = UDim2.new(1, 0, 0, 28)
row.BackgroundColor3 = Color3.fromRGB(30, 30, 37)
row.BorderSizePixel = 0
row.Parent = keyPage
Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(0.58, -8, 1, 0)
lbl.Position = UDim2.new(0, 8, 0, 0)
lbl.BackgroundTransparency = 1
lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
lbl.Font = Enum.Font.GothamSemibold
lbl.TextSize = 11
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = item.label
lbl.Parent = row
local kBtn = Instance.new("TextButton")
kBtn.Size = UDim2.new(0.42, -6, 0, 22)
kBtn.Position = UDim2.new(0.58, 0, 0, 3)
kBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
kBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
kBtn.Font = Enum.Font.GothamBold
kBtn.TextSize = 11
kBtn.Text = "Chưa gán"
kBtn.Parent = row
Instance.new("UICorner", kBtn).CornerRadius = UDim.new(0, 4)
keybindButtons[item.id] = kBtn
kBtn.MouseButton1Click:Connect(function()
waitingForKey = item.id
kBtn.Text = "Nhấn phím..."
kBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 30)
end)
end
-- ================= HÀM LỌC GẦN ĐÚNG & PHÂN LOẠI MỤC TIÊU =================
-- Tính khoảng cách Levenshtein để nhận diện tên gần giống (hỗ trợ gõ sai 1-2 ký tự)
local function levenshtein(s, t)
local m, n = #s, #t
if m == 0 then return n end
if n == 0 then return m end
local d = {}
for i = 0, m do d[i] = {[0] = i} end
for j = 0, n do d[0][j] = j end
for i = 1, m do
for j = 1, n do
local cost = (s:sub(i, i) == t:sub(j, j)) and 0 or 1
d[i][j] = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
end
end
return d[m][n]
end
-- Kiểm tra xem tên mục tiêu có khớp gần đúng với danh sách lọc bỏ (Blacklist) không
local function isBlacklisted(name)
if #blacklistTerms == 0 then return false end
local lowerName = string.lower(name)
local words = {}
for w in string.gmatch(lowerName, "%w+") do
table.insert(words, w)
end
for _, term in ipairs(blacklistTerms) do
-- 1. Khớp chuỗi con trực tiếp (VD: nhập "zom" sẽ khớp "Zombie", "Zombified")
if string.find(lowerName, term, 1, true) then
return true
end
-- 2. Khớp gần giống theo từng từ hoặc toàn bộ tên (VD: nhập "zombe" khớp "Zombie")
local maxDist = math.max(1, math.floor(#term * 0.25))
if #term >= 3 then
if levenshtein(lowerName, term) <= maxDist then
return true
end
for _, w in ipairs(words) do
if levenshtein(w, term) <= maxDist then
return true
end
end
end
end
return false
end
local function parseBlacklistInput(rawText)
blacklistTerms = {}
for part in string.gmatch(rawText, "([^,]+)") do
local trimmed = part:match("^%s*(.-)%s*$")
if trimmed and trimmed ~= "" then
table.insert(blacklistTerms, string.lower(trimmed))
end
end
end
-- Tìm bộ phận mục tiêu thông minh (Hỗ trợ cả quái thường, Player & Custom Mesh)
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
local function getFeetPart(model)
return model:FindFirstChild("HumanoidRootPart")
or model:FindFirstChild("LowerTorso")
or model:FindFirstChild("Torso")
or getTargetPart(model)
end
-- Nhận diện đệ tử / đồng đội / vật triệu hồi đi kèm người chơi
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
-- ================= CHỨC NĂNG 1: HITBOX TÁCH BIỆT NPC & PLAYER =================
local function restoreHitboxPart(targetPart)
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
local function applyHitbox(model)
if not model or not model:IsA("Model") or model == LocalPlayer.Character then return end
local humanoid = model:FindFirstChildOfClass("Humanoid")
local targetPart = getTargetPart(model)
if not targetPart then return end
if not humanoid or humanoid.Health <= 0 then
restoreHitboxPart(targetPart)
return
end
local plr = Players:GetPlayerFromCharacter(model)
local shouldApply = false
local targetSize = Vector3.new(22, 22, 22)
local targetTrans = 0.92
local targetColor = BrickColor.new("Really blue")
if plr then
-- Nhánh xử lý cho Players (loại trừ đồng đội cùng Team và kiểm tra Blacklist)
local isSameTeam = (LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team)
if state.plrHitbox and not isSameTeam and not isBlacklisted(plr.Name) and not isBlacklisted(plr.DisplayName) then
shouldApply = true
targetSize = Vector3.new(config.plrSize, config.plrSize, config.plrSize)
targetTrans = config.plrTrans
targetColor = BrickColor.new("Bright red")
end
else
-- Nhánh xử lý cho NPCs (loại trừ đệ tử triệu hồi và kiểm tra Blacklist)
if state.npcHitbox and not isPlayerCompanion(model) and not isBlacklisted(model.Name) then
shouldApply = true
targetSize = Vector3.new(config.npcSize, config.npcSize, config.npcSize)
targetTrans = config.npcTrans
targetColor = BrickColor.new("Really blue")
end
end
if shouldApply then
if not originalData[targetPart] then
originalData[targetPart] = {
Size = targetPart.Size,
Material = targetPart.Material,
BrickColor = targetPart.BrickColor,
Transparency = targetPart.Transparency,
CanCollide = targetPart.CanCollide,
Massless = targetPart.Massless
}
humanoid.Died:Once(function()
restoreHitboxPart(targetPart)
end)
end
targetPart.Size = targetSize
targetPart.Material = Enum.Material.Neon
targetPart.BrickColor = targetColor
targetPart.Transparency = targetTrans
targetPart.CanCollide = false
targetPart.Massless = true
else
restoreHitboxPart(targetPart)
end
end
local function refreshAllHitboxes()
for _, obj in ipairs(workspace:GetDescendants()) do
if obj:IsA("Humanoid") and obj.Parent then
applyHitbox(obj.Parent)
end
end
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
local anyEspActive = state.espHighlight or state.espName or state.espHealth
if not anyEspActive or not model or not model:IsA("Model") then
clearESP(model)
return
end
local humanoid = model:FindFirstChildOfClass("Humanoid")
if not humanoid or humanoid.Health <= 0 or Players:GetPlayerFromCharacter(model) then
clearESP(model)
return
end
local feetPart = getFeetPart(model)
if not feetPart then
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
if state.espHighlight then
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
if state.espName or state.espHealth then
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
if state.espName then
table.insert(parts, model.Name)
end
if state.espHealth then
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
if state.interact then
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
task.wait(config.interactDelay)
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
hum.WalkSpeed = state.ws and config.ws or 16
if state.jp then
hum.UseJumpPower = true
hum.JumpPower = config.jp
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
local function applyFullbright()
if _G.FullbrightConn then
_G.FullbrightConn:Disconnect()
_G.FullbrightConn = nil
end
if state.fullbright then
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
end
-- ================= HÀM KÍCH HOẠT TẬP TRUNG (DÙNG CHUNG CHO CLICK & KEYBIND) =================
local function setBtnStyle(btn, active, label)
btn.Text = label .. (active and ": BẬT" or ": TẮT")
btn.BackgroundColor3 = active and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
end
local actions = {
npcHitbox = function()
state.npcHitbox = not state.npcHitbox
setBtnStyle(npcHbBtn, state.npcHitbox, "Hitbox NPCs")
refreshAllHitboxes()
end,
plrHitbox = function()
state.plrHitbox = not state.plrHitbox
setBtnStyle(plrHbBtn, state.plrHitbox, "Hitbox Players")
refreshAllHitboxes()
end,
espHighlight = function()
state.espHighlight = not state.espHighlight
setBtnStyle(espHighlightBtn, state.espHighlight, "ESP Viền (Highlight)")
refreshAllESP()
end,
espName = function()
state.espName = not state.espName
setBtnStyle(espNameBtn, state.espName, "ESP Tên")
refreshAllESP()
end,
espHealth = function()
state.espHealth = not state.espHealth
setBtnStyle(espHealthBtn, state.espHealth, "ESP Máu")
refreshAllESP()
end,
interact = function()
state.interact = not state.interact
setBtnStyle(interactBtn, state.interact, "Tự động tương tác")
end,
ws = function()
state.ws = not state.ws
setBtnStyle(wsBtn, state.ws, "Tốc độ chạy (WS)")
applyMovementStats()
end,
jp = function()
state.jp = not state.jp
setBtnStyle(jpBtn, state.jp, "Lực nhảy (JP)")
applyMovementStats()
end,
fullbright = function()
state.fullbright = not state.fullbright
setBtnStyle(fbBtn, state.fullbright, "Sáng bản đồ (Fullbright)")
applyFullbright()
end
}
npcHbBtn.MouseButton1Click:Connect(actions.npcHitbox)
plrHbBtn.MouseButton1Click:Connect(actions.plrHitbox)
espHighlightBtn.MouseButton1Click:Connect(actions.espHighlight)
espNameBtn.MouseButton1Click:Connect(actions.espName)
espHealthBtn.MouseButton1Click:Connect(actions.espHealth)
interactBtn.MouseButton1Click:Connect(actions.interact)
wsBtn.MouseButton1Click:Connect(actions.ws)
jpBtn.MouseButton1Click:Connect(actions.jp)
fbBtn.MouseButton1Click:Connect(actions.fullbright)
-- ================= SỰ KIỆN CÁC Ô NHẬP LIỆU =================
filterInput.FocusLost:Connect(function()
parseBlacklistInput(filterInput.Text)
refreshAllHitboxes()
end)
npcSizeInput.FocusLost:Connect(function()
local num = tonumber(npcSizeInput.Text)
if num and num > 0 then
config.npcSize = num
npcSizeInput.Text = tostring(num)
if state.npcHitbox then refreshAllHitboxes() end
else
npcSizeInput.Text = tostring(config.npcSize)
end
end)
npcTransInput.FocusLost:Connect(function()
local num = tonumber(npcTransInput.Text)
if num and num >= 0 and num <= 1 then
config.npcTrans = num
npcTransInput.Text = tostring(num)
if state.npcHitbox then refreshAllHitboxes() end
else
npcTransInput.Text = tostring(config.npcTrans)
end
end)
plrSizeInput.FocusLost:Connect(function()
local num = tonumber(plrSizeInput.Text)
if num and num > 0 then
config.plrSize = num
plrSizeInput.Text = tostring(num)
if state.plrHitbox then refreshAllHitboxes() end
else
plrSizeInput.Text = tostring(config.plrSize)
end
end)
plrTransInput.FocusLost:Connect(function()
local num = tonumber(plrTransInput.Text)
if num and num >= 0 and num <= 1 then
config.plrTrans = num
plrTransInput.Text = tostring(num)
if state.plrHitbox then refreshAllHitboxes() end
else
plrTransInput.Text = tostring(config.plrTrans)
end
end)
delayInput.FocusLost:Connect(function()
local num = tonumber(delayInput.Text)
if num and num >= 0.05 then
config.interactDelay = math.clamp(num, 0.05, 60)
delayInput.Text = tostring(config.interactDelay)
else
delayInput.Text = tostring(config.interactDelay)
end
end)
wsInput.FocusLost:Connect(function()
local num = tonumber(wsInput.Text)
if num and num > 0 then
config.ws = num
wsInput.Text = tostring(num)
if state.ws then applyMovementStats() end
else
wsInput.Text = tostring(config.ws)
end
end)
jpInput.FocusLost:Connect(function()
local num = tonumber(jpInput.Text)
if num and num > 0 then
config.jp = num
jpInput.Text = tostring(num)
if state.jp then applyMovementStats() end
else
jpInput.Text = tostring(config.jp)
end
end)
-- 2. Lắng nghe nhân vật / NPC mới xuất hiện trong workspace
_G.HitboxAddedConn = workspace.DescendantAdded:Connect(function(descendant)
local anyActive = state.npcHitbox or state.plrHitbox or state.espHighlight or state.espName or state.espHealth
if not anyActive then return end
if descendant:IsA("Humanoid") then
local model = descendant.Parent
if not model then return end
task.wait(0.35)
local targetPart = getTargetPart(model)
if not targetPart then
model.ChildAdded:Wait()
targetPart = getTargetPart(model)
end
if targetPart then
if state.npcHitbox or state.plrHitbox then applyHitbox(model) end
if state.espHighlight or state.espName or state.espHealth then updateESP(model) end
end
end
end)
-- 3. Lắng nghe bàn phím (Gán Keybind tùy chỉnh + Kích hoạt chức năng + Right Ctrl)
_G.HitboxKeybind = UserInputService.InputBegan:Connect(function(input, gameProcessed)
if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
-- Xử lý khi đang chờ gán phím mới trong Tab Keybinds
if waitingForKey then
local targetId = waitingForKey
waitingForKey = nil
local btn = keybindButtons[targetId]
if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
keybinds[targetId] = nil
if btn then
btn.Text = "Chưa gán"
btn.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
end
else
keybinds[targetId] = input.KeyCode
if btn then
btn.Text = input.KeyCode.Name
btn.BackgroundColor3 = Color3.fromRGB(0, 130, 190)
end
end
return
end
-- Ẩn / Hiện bảng điều khiển bằng Right Ctrl
if input.KeyCode == Enum.KeyCode.RightControl then
mainFrame.Visible = not mainFrame.Visible
return
end
if gameProcessed then return end
-- Kiểm tra xem phím vừa bấm có khớp với Keybind nào đã gán không
for id, boundKey in pairs(keybinds) do
if boundKey and input.KeyCode == boundKey and actions[id] then
actionsid
end
end
end)
