local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
-- 1. Dọn dẹp kết nối & GUI cũ
for _, connName in ipairs({"HitboxAddedConn", "HitboxRemovedConn", "HitboxKeybind", "CharAddedConn", "FullbrightConn"}) do
if _G[connName] then _G[connName]:Disconnect() _G[connName] = nil end
end
if _G.HitboxGui then _G.HitboxGui:Destroy() _G.HitboxGui = nil end
if _G.AutoInteractLoop then _G.AutoInteractLoop = false end
-- Trạng thái & Cấu hình
local state = {
npcHitbox = false, plrHitbox = false,
espHighlight = false, espName = false, espHealth = false,
interact = false, ws = false, jp = false, fullbright = false
}
local config = {
npcSize = 22, npcTrans = 0.92,
plrSize = 15, plrTrans = 0.85,
interactDelay = 0.25, ws = 32, jp = 80
}
local keybinds = {}
local waitingForKey = nil
local keybindButtons = {}
local blacklistTerms = {}
local isHitboxCardExpanded = true
-- Bộ nhớ đệm (Cache)
local trackedModels = {}
local trackedPrompts = {}
local originalData = setmetatable({}, { __mode = "k" })
local espObjects = setmetatable({}, { __mode = "k" })
local origLighting = {
Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient
}
-- ================= HÀM DỰNG UI RÚT GỌN =================
local function make(className, props, parent)
local inst = Instance.new(className)
for k, v in pairs(props) do inst[k] = v end
if parent then inst.Parent = parent end
return inst
end
local screenGui = make("ScreenGui", { Name = "ModularCombatGUI", ResetOnSpawn = false })
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
_G.HitboxGui = screenGui
local mainFrame = make("Frame", {
Size = UDim2.new(0, 285, 0, 390), Position = UDim2.new(1, -300, 0.5, -195),
BackgroundColor3 = Color3.fromRGB(22, 22, 27), BorderSizePixel = 0, Active = true, Draggable = true
}, screenGui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, mainFrame)
-- Thanh Tab
local tabBar = make("Frame", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, 8), BackgroundColor3 = Color3.fromRGB(16, 16, 20), BorderSizePixel = 0 }, mainFrame)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, tabBar)
local mainTabBtn = make("TextButton", { Size = UDim2.new(0.5, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2), BackgroundColor3 = Color3.fromRGB(45, 45, 55), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, Text = "Chức năng" }, tabBar)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, mainTabBtn)
local keyTabBtn = make("TextButton", { Size = UDim2.new(0.5, -4, 1, -4), Position = UDim2.new(0.5, 2, 0, 2), BackgroundColor3 = Color3.fromRGB(25, 25, 32), TextColor3 = Color3.fromRGB(160, 160, 175), Font = Enum.Font.GothamBold, TextSize = 12, Text = "Keybinds" }, tabBar)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, keyTabBtn)
local mainPage = make("Frame", { Size = UDim2.new(1, -16, 1, -64), Position = UDim2.new(0, 8, 0, 42), BackgroundTransparency = 1 }, mainFrame)
local mainLayout = make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, mainPage)
local keyPage = make("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -64), Position = UDim2.new(0, 8, 0, 42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false }, mainFrame)
make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, keyPage)
make("TextLabel", { Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 1, -20), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(140, 140, 155), Font = Enum.Font.Gotham, TextSize = 10, Text = "Nhấn [Right Ctrl] để Ẩn / Hiện bảng điều khiển" }, mainFrame)
local function updateMainFrameHeight()
mainFrame.Size = mainPage.Visible and UDim2.new(0, 285, 0, mainLayout.AbsoluteContentSize.Y + 68) or UDim2.new(0, 285, 0, 360)
end
mainLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateMainFrameHeight)
local function switchTab(isMain)
mainPage.Visible = isMain
keyPage.Visible = not isMain
mainTabBtn.BackgroundColor3 = isMain and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(25, 25, 32)
mainTabBtn.TextColor3 = isMain and Color3.new(1, 1, 1) or Color3.fromRGB(160, 160, 175)
keyTabBtn.BackgroundColor3 = not isMain and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(25, 25, 32)
keyTabBtn.TextColor3 = not isMain and Color3.new(1, 1, 1) or Color3.fromRGB(160, 160, 175)
updateMainFrameHeight()
end
mainTabBtn.MouseButton1Click:Connect(function() switchTab(true) end)
keyTabBtn.MouseButton1Click:Connect(function() switchTab(false) end)
-- Thẻ phụ Hitbox
local hitboxCard = make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 126), BackgroundColor3 = Color3.fromRGB(30, 30, 37), BorderSizePixel = 0, ClipsDescendants = true }, mainPage)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, hitboxCard)
local cardHeader = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(38, 38, 47), BorderSizePixel = 0 }, hitboxCard)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, cardHeader)
make("TextLabel", { Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(220, 220, 235), Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Text = "Cấu hình Hitbox (NPCs & Players)" }, cardHeader)
local minMaxBtn = make("TextButton", { Size = UDim2.new(0, 22, 0, 20), Position = UDim2.new(1, -25, 0, 3), BackgroundColor3 = Color3.fromRGB(55, 55, 68), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13, Text = "-" }, cardHeader)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, minMaxBtn)
minMaxBtn.MouseButton1Click:Connect(function()
isHitboxCardExpanded = not isHitboxCardExpanded
hitboxCard.Size = isHitboxCardExpanded and UDim2.new(1, 0, 0, 126) or UDim2.new(1, 0, 0, 26)
minMaxBtn.Text = isHitboxCardExpanded and "-" or "+"
updateMainFrameHeight()
end)
local filterInput = make("TextBox", { Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 6, 0, 30), BackgroundColor3 = Color3.fromRGB(20, 20, 25), TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(130, 130, 145), PlaceholderText = "Lọc bỏ tên (VD: shop, quest, guard)...", Text = "", Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false }, hitboxCard)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, filterInput)
local function createHitboxSubRow(labelPrefix, defSize, defTrans, posY)
local row = make("Frame", { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.new(0, 6, 0, posY), BackgroundTransparency = 1 }, hitboxCard)
local btn = make("TextButton", { Size = UDim2.new(1, -98, 1, 0), BackgroundColor3 = Color3.fromRGB(180, 50, 50), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, Text = labelPrefix .. ": TẮT" }, row)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, btn)
local sBox = make("TextBox", { Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, -92, 0, 0), BackgroundColor3 = Color3.fromRGB(42, 42, 52), TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "Size", Text = tostring(defSize), Font = Enum.Font.GothamBold, TextSize = 11, ClearTextOnFocus = false }, row)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, sBox)
local tBox = make("TextBox", { Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, -44, 0, 0), BackgroundColor3 = Color3.fromRGB(42, 42, 52), TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "Trans", Text = tostring(defTrans), Font = Enum.Font.GothamBold, TextSize = 11, ClearTextOnFocus = false }, row)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, tBox)
return btn, sBox, tBox
end
local npcHbBtn, npcSizeInput, npcTransInput = createHitboxSubRow("Hitbox NPCs", config.npcSize, config.npcTrans, 60)
local plrHbBtn, plrSizeInput, plrTransInput = createHitboxSubRow("Hitbox Players", config.plrSize, config.plrTrans, 92)
local function createStandardRow(order, text, hasInput, defVal, placeholder)
local row = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, mainPage)
local btn = make("TextButton", { Size = hasInput and UDim2.new(1, -58, 1, 0) or UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(180, 50, 50), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 12, Text = text }, row)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
local box = nil
if hasInput then
box = make("TextBox", { Size = UDim2.new(0, 52, 1, 0), Position = UDim2.new(1, -52, 0, 0), BackgroundColor3 = Color3.fromRGB(38, 38, 46), TextColor3 = Color3.new(1, 1, 1), PlaceholderText = placeholder, Text = tostring(defVal), Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false }, row)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
end
return btn, box
end
local espHighlightBtn = createStandardRow(2, "ESP Viền (Highlight): TẮT", false)
local espSplitRow = make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, mainPage)
local espNameBtn = make("TextButton", { Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = Color3.fromRGB(180, 50, 50), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, Text = "ESP Tên: TẮT" }, espSplitRow)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, espNameBtn)
local espHealthBtn = make("TextButton", { Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0), BackgroundColor3 = Color3.fromRGB(180, 50, 50), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, Text = "ESP Máu: TẮT" }, espSplitRow)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, espHealthBtn)
local interactBtn, delayInput = createStandardRow(4, "Tự động tương tác: TẮT", true, config.interactDelay, "Giây")
local wsBtn, wsInput = createStandardRow(5, "Tốc độ chạy (WS): TẮT", true, config.ws, "WS")
local jpBtn, jpInput = createStandardRow(6, "Lực nhảy (JP): TẮT", true, config.jp, "JP")
local fbBtn = createStandardRow(7, "Sáng bản đồ (Fullbright): TẮT", false)
-- Tab Keybinds
local keybindDefs = {
{ id = "npcHitbox", label = "Hitbox NPCs" }, { id = "plrHitbox", label = "Hitbox Players" },
{ id = "espHighlight", label = "ESP Viền (Highlight)" }, { id = "espName", label = "ESP Tên" },
{ id = "espHealth", label = "ESP Máu" }, { id = "interact", label = "Tự động tương tác" },
{ id = "ws", label = "Tốc độ chạy (WS)" }, { id = "jp", label = "Lực nhảy (JP)" },
{ id = "fullbright", label = "Sáng bản đồ" }
}
for idx, item in ipairs(keybindDefs) do
local row = make("Frame", { LayoutOrder = idx, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(30, 30, 37), BorderSizePixel = 0 }, keyPage)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
make("TextLabel", { Size = UDim2.new(0.58, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(220, 220, 230), Font = Enum.Font.GothamSemibold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Text = item.label }, row)
local kBtn = make("TextButton", { Size = UDim2.new(0.42, -6, 0, 22), Position = UDim2.new(0.58, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(45, 45, 56), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, Text = "Chưa gán" }, row)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, kBtn)
keybindButtons[item.id] = kBtn
kBtn.MouseButton1Click:Connect(function()
waitingForKey = item.id
kBtn.Text = "Nhấn phím..."
kBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 30)
end)
end
-- ================= LOGIC XỬ LÝ TỐI ƯU =================
local function levenshtein(s, t)
local m, n = #s, #t
if m == 0 then return n elseif n == 0 then return m end
local prev, curr = {}, {}
for j = 0, n do prev[j] = j end
for i = 1, m do
curr = table.create(n, 0)
curr[0] = i
for j = 1, n do
local cost = (s:sub(i, i) == t:sub(j, j)) and 0 or 1
curr[j] = math.min(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
end
prev = curr
end
return prev[n]
end
local function isBlacklisted(name)
if #blacklistTerms == 0 then return false end
local lowerName = string.lower(name)
for _, term in ipairs(blacklistTerms) do
if string.find(lowerName, term, 1, true) then return true end
if #term >= 3 then
local maxDist = math.max(1, math.floor(#term * 0.25))
if levenshtein(lowerName, term) <= maxDist then return true end
for w in string.gmatch(lowerName, "%w+") do
if levenshtein(w, term) <= maxDist then return true end
end
end
end
return false
end
local function getTargetPart(model)
local part = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
if part and part:IsA("BasePart") then return part end
local bestPart, maxVol = nil, 0
for _, child in ipairs(model:GetDescendants()) do
if child:IsA("BasePart") then
local vol = child.Size.X * child.Size.Y * child.Size.Z
if vol > maxVol then maxVol, bestPart = vol, child end
end
end
return bestPart
end
local function isPlayerCompanion(model)
local allPlayers = Players:GetPlayers()
local lowerName = string.lower(model.Name)
for _, plr in ipairs(allPlayers) do
if plr.Character and model:IsDescendantOf(plr.Character) then return true end
if string.find(lowerName, string.lower(plr.Name), 1, true) then return true end
end
for _, key in ipairs({"Owner", "Creator", "Master", "Summoner", "Player", "OwnedBy"}) do
local valObj = model:FindFirstChild(key, true)
if valObj then
if valObj:IsA("ObjectValue") and valObj.Value and valObj.Value:IsA("Player") then return true end
if valObj:IsA("StringValue") or valObj:IsA("IntValue") or valObj:IsA("NumberValue") then
for _, plr in ipairs(allPlayers) do
if valObj.Value == plr.Name or valObj.Value == plr.DisplayName or valObj.Value == plr.UserId then return true end
end
end
end
end
for attrName, attrVal in pairs(model:GetAttributes()) do
local lAttr = string.lower(attrName)
if (string.find(lAttr, "owner") or string.find(lAttr, "creator") or string.find(lAttr, "summon") or string.find(lAttr, "master")) and attrVal ~= nil and attrVal ~= "" and attrVal ~= 0 then
return true
end
for _, plr in ipairs(allPlayers) do
if attrVal == plr.Name or attrVal == plr.UserId then return true end
end
end
if LocalPlayer.Team then
local tVal = model:FindFirstChild("Team") or model:FindFirstChild("TeamColor")
if tVal and ((tVal:IsA("ObjectValue") and tVal.Value == LocalPlayer.Team) or (tVal:IsA("BrickColorValue") and tVal.Value == LocalPlayer.TeamColor) or (tVal:IsA("StringValue") and tVal.Value == LocalPlayer.Team.Name)) then
return true
end
end
return false
end
-- ================= HITBOX & ESP =================
local function restoreHitboxPart(part)
local saved = originalData[part]
if saved then
part.Size, part.Material, part.BrickColor = saved.Size, saved.Material, saved.BrickColor
part.Transparency, part.CanCollide, part.Massless = saved.Transparency, saved.CanCollide, saved.Massless
originalData[part] = nil
end
end
local function applyHitbox(model)
if not model or not model.Parent or model == LocalPlayer.Character then return end
local hum = model:FindFirstChildOfClass("Humanoid")
local part = getTargetPart(model)
if not part then return end
if not hum or hum.Health <= 0 then restoreHitboxPart(part) return end
local plr = Players:GetPlayerFromCharacter(model)
local apply, size, trans, color = false, nil, 0, nil
if plr then
local sameTeam = LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team
if state.plrHitbox and not sameTeam and not isBlacklisted(plr.Name) and not isBlacklisted(plr.DisplayName) then
apply, size, trans, color = true, Vector3.new(config.plrSize, config.plrSize, config.plrSize), config.plrTrans, BrickColor.new("Bright red")
end
elseif state.npcHitbox and not isPlayerCompanion(model) and not isBlacklisted(model.Name) then
apply, size, trans, color = true, Vector3.new(config.npcSize, config.npcSize, config.npcSize), config.npcTrans, BrickColor.new("Really blue")
end
if apply then
if not originalData[part] then
originalData[part] = { Size = part.Size, Material = part.Material, BrickColor = part.BrickColor, Transparency = part.Transparency, CanCollide = part.CanCollide, Massless = part.Massless }
hum.Died:Once(function() restoreHitboxPart(part) end)
end
part.Size, part.Material, part.BrickColor, part.Transparency, part.CanCollide, part.Massless = size, Enum.Material.Neon, color, trans, false, true
else
restoreHitboxPart(part)
end
end
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
local anyEsp = state.espHighlight or state.espName or state.espHealth
if not anyEsp or not model or not model.Parent then clearESP(model) return end
local hum = model:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health <= 0 or Players:GetPlayerFromCharacter(model) then clearESP(model) return end
local feetPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("LowerTorso") or model:FindFirstChild("Torso") or getTargetPart(model)
if not feetPart then clearESP(model) return end
local isAlly = isPlayerCompanion(model)
local data = espObjects[model] or {}
if not espObjects[model] then
espObjects[model] = data
data.diedConn = hum.Died:Once(function() clearESP(model) end)
end
if state.espHighlight then
if not data.highlight then
data.highlight = make("Highlight", {
Name = "NPC_ESP_HL",
FillTransparency = 1,
OutlineTransparency = 0,
DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
}, model)
end
data.highlight.OutlineColor = isAlly and Color3.fromRGB(40, 180, 255) or Color3.fromRGB(255, 60, 60)
elseif data.highlight then
data.highlight:Destroy()
data.highlight = nil
end
if state.espName or state.espHealth then
if not data.billboard then
data.billboard = make("BillboardGui", { Name = "NPC_ESP_Tag", Adornee = feetPart, Size = UDim2.new(0, 220, 0, 24), StudsOffset = Vector3.new(0, -3.2, 0), AlwaysOnTop = true }, feetPart)
data.infoLbl = make("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextStrokeTransparency = 0.25, TextStrokeColor3 = Color3.new(0, 0, 0), Font = Enum.Font.GothamBold, TextSize = 12 }, data.billboard)
data.conn = hum.HealthChanged:Connect(function(hp)
if hp <= 0 then clearESP(model) else updateESP(model) end
end)
end
data.infoLbl.TextColor3 = isAlly and Color3.fromRGB(255, 190, 45) or Color3.new(1, 1, 1)
local parts = {}
if state.espName then table.insert(parts, model.Name) end
if state.espHealth then table.insert(parts, string.format("%d/%d HP", math.floor(math.max(hum.Health, 0)), math.floor(math.max(hum.MaxHealth, 1)))) end
data.infoLbl.Text = table.concat(parts, " | ")
else
if data.conn then data.conn:Disconnect() data.conn = nil end
if data.billboard then data.billboard:Destroy() data.billboard = nil end
end
end
local function refreshCachedModels(doHitbox, doEsp)
for model in pairs(trackedModels) do
if model and model.Parent then
if doHitbox then applyHitbox(model) end
if doEsp then updateESP(model) end
else
trackedModels[model] = nil
end
end
end
-- ================= QUẢN LÝ BỘ NHỚ ĐỆM & TƯƠNG TÁC =================
local function registerObject(obj)
if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
local model = obj.Parent
trackedModels[model] = true
if state.npcHitbox or state.plrHitbox or state.espHighlight or state.espName or state.espHealth then
task.delay(0.35, function()
if model and model.Parent then
if state.npcHitbox or state.plrHitbox then applyHitbox(model) end
if state.espHighlight or state.espName or state.espHealth then updateESP(model) end
end
end)
end
elseif obj:IsA("ProximityPrompt") then
trackedPrompts[obj] = true
end
end
for _, obj in ipairs(workspace:GetDescendants()) do registerObject(obj) end
_G.HitboxAddedConn = workspace.DescendantAdded:Connect(registerObject)
_G.HitboxRemovedConn = workspace.DescendantRemoving:Connect(function(obj)
if obj:IsA("Model") then trackedModels[obj] = nil clearESP(obj)
elseif obj:IsA("ProximityPrompt") then trackedPrompts[obj] = nil end
end)
_G.AutoInteractLoop = true
task.spawn(function()
while _G.AutoInteractLoop do
if state.interact then
local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if root then
for prompt in pairs(trackedPrompts) do
if prompt and prompt.Parent and prompt.Enabled then
local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
if part and (part.Position - root.Position).Magnitude <= (prompt.MaxActivationDistance + 5) then
if fireproximityprompt then fireproximityprompt(prompt)
else prompt:InputHoldBegin() task.wait(prompt.HoldDuration) prompt:InputHoldEnd() end
end
elseif not prompt or not prompt.Parent then
trackedPrompts[prompt] = nil
end
end
end
task.wait(config.interactDelay)
else
task.wait(0.25)
end
end
end)
-- ================= DI CHUYỂN & ÁNH SÁNG =================
local function applyMovementStats()
local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
if not hum then return end
hum.WalkSpeed = state.ws and config.ws or 16
if state.jp then hum.UseJumpPower = true hum.JumpPower = config.jp else hum.JumpPower = 50 end
end
_G.CharAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
local hum = char:WaitForChild("Humanoid", 5)
if hum then task.wait(0.1) applyMovementStats() end
end)
local function applyFullbright()
if _G.FullbrightConn then _G.FullbrightConn:Disconnect() _G.FullbrightConn = nil end
if state.fullbright then
local function setBright()
Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows = 2, 14, 100000, false
Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178), Color3.fromRGB(178, 178, 178)
end
setBright()
_G.FullbrightConn = Lighting.LightingChanged:Connect(setBright)
else
for k, v in pairs(origLighting) do Lighting[k] = v end
end
end
-- ================= SỰ KIỆN TƯƠNG TÁC UI =================
local function setBtnStyle(btn, active, label)
btn.Text = label .. (active and ": BẬT" or ": TẮT")
btn.BackgroundColor3 = active and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(180, 50, 50)
end
local actions = {
npcHitbox = function() state.npcHitbox = not state.npcHitbox setBtnStyle(npcHbBtn, state.npcHitbox, "Hitbox NPCs") refreshCachedModels(true, false) end,
plrHitbox = function() state.plrHitbox = not state.plrHitbox setBtnStyle(plrHbBtn, state.plrHitbox, "Hitbox Players") refreshCachedModels(true, false) end,
espHighlight = function() state.espHighlight = not state.espHighlight setBtnStyle(espHighlightBtn, state.espHighlight, "ESP Viền (Highlight)") refreshCachedModels(false, true) end,
espName = function() state.espName = not state.espName setBtnStyle(espNameBtn, state.espName, "ESP Tên") refreshCachedModels(false, true) end,
espHealth = function() state.espHealth = not state.espHealth setBtnStyle(espHealthBtn, state.espHealth, "ESP Máu") refreshCachedModels(false, true) end,
interact = function() state.interact = not state.interact setBtnStyle(interactBtn, state.interact, "Tự động tương tác") end,
ws = function() state.ws = not state.ws setBtnStyle(wsBtn, state.ws, "Tốc độ chạy (WS)") applyMovementStats() end,
jp = function() state.jp = not state.jp setBtnStyle(jpBtn, state.jp, "Lực nhảy (JP)") applyMovementStats() end,
fullbright = function() state.fullbright = not state.fullbright setBtnStyle(fbBtn, state.fullbright, "Sáng bản đồ (Fullbright)") applyFullbright() end
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
local function bindNumBox(box, cfgKey, minVal, maxVal, callback)
box.FocusLost:Connect(function()
local num = tonumber(box.Text)
if num and (not minVal or num >= minVal) and (not maxVal or num <= maxVal) then
config[cfgKey] = num
box.Text = tostring(num)
if callback then callback() end
else
box.Text = tostring(config[cfgKey])
end
end)
end
bindNumBox(npcSizeInput, "npcSize", 0.1, nil, function() if state.npcHitbox then refreshCachedModels(true, false) end end)
bindNumBox(npcTransInput, "npcTrans", 0, 1, function() if state.npcHitbox then refreshCachedModels(true, false) end end)
bindNumBox(plrSizeInput, "plrSize", 0.1, nil, function() if state.plrHitbox then refreshCachedModels(true, false) end end)
bindNumBox(plrTransInput, "plrTrans", 0, 1, function() if state.plrHitbox then refreshCachedModels(true, false) end end)
bindNumBox(delayInput, "interactDelay", 0.05, 60, nil)
bindNumBox(wsInput, "ws", 0.1, nil, function() if state.ws then applyMovementStats() end end)
bindNumBox(jpInput, "jp", 0.1, nil, function() if state.jp then applyMovementStats() end end)
filterInput.FocusLost:Connect(function()
blacklistTerms = {}
for part in string.gmatch(filterInput.Text, "([^,]+)") do
local trimmed = string.gsub(part, "^%s+", "")
trimmed = string.gsub(trimmed, "%s+$", "")
if trimmed ~= "" then table.insert(blacklistTerms, string.lower(trimmed)) end
end
refreshCachedModels(true, false)
end)
_G.HitboxKeybind = UserInputService.InputBegan:Connect(function(input, gameProcessed)
if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
if waitingForKey then
local id, btn = waitingForKey, keybindButtons[waitingForKey]
waitingForKey = nil
if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
keybinds[id] = nil
if btn then btn.Text, btn.BackgroundColor3 = "Chưa gán", Color3.fromRGB(45, 45, 56) end
else
keybinds[id] = input.KeyCode
if btn then btn.Text, btn.BackgroundColor3 = input.KeyCode.Name, Color3.fromRGB(0, 130, 190) end
end
return
end
if input.KeyCode == Enum.KeyCode.RightControl then mainFrame.Visible = not mainFrame.Visible return end
if gameProcessed then return end
for id, boundKey in pairs(keybinds) do
if boundKey and input.KeyCode == boundKey and actions[id] then actionsid end
end
end)
