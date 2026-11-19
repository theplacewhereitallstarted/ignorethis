local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

-- Cleanup
for _, c in {
	_G.HitboxAddedConn,
	_G.HitboxKeybind,
	_G.NPCTargetRenderConn,
	_G.NPCTargetDiedConn
} do
	if c then c:Disconnect() end
end

if _G.HitboxGUI then
	_G.HitboxGUI:Destroy()
end

for _, v in workspace:GetDescendants() do
	if v:IsA("BillboardGui") and
		(v.Name == "CustomNPCHealthESP" or v.Name == "NPCTargetMarker") then
		v:Destroy()
	end
end

-- Config
_G.MenuConfig = {
	HitboxEnabled = false,
	HitboxSize = 22,
	HitboxTransparency = 0.92,

	HealthESPEnabled = false,

	NPCTargetEnabled = false,
	NPCTargetMaxDistance = 1000,
	NPCTargetHold = true
}

local original = setmetatable({}, {__mode = "k"})
local target

-- NPC check
local function validNPC(m)
	if not m or not m:IsA("Model") then return false end

	local hum = m:FindFirstChildOfClass("Humanoid")
	local head = m:FindFirstChild("Head")

	return hum and head
		and not Players:GetPlayerFromCharacter(m)
		and hum.Health > 0
end

-- Hitbox
local function hitbox(m, on)
	local head = m:FindFirstChild("Head")
	if not head then return end

	if on then
		if not validNPC(m) then return end

		if not original[head] then
			original[head] = {
				Size = head.Size,
				Material = head.Material,
				Color = head.BrickColor,
				Transparency = head.Transparency
			}
		end

		local s = _G.MenuConfig.HitboxSize

		head.Size = Vector3.new(s, s, s)
		head.Transparency = _G.MenuConfig.HitboxTransparency
		head.Material = Enum.Material.Neon
		head.BrickColor = BrickColor.new("Really blue")
		head.CanCollide = false
		head.Massless = true
	else
		local d = original[head]

		if d then
			head.Size = d.Size
			head.Material = d.Material
			head.BrickColor = d.Color
			head.Transparency = d.Transparency
			original[head] = nil
		end
	end
end

_G.UpdateHitbox = function()
	for _, v in workspace:GetDescendants() do
		if v:IsA("Humanoid") and v.Parent then
			hitbox(v.Parent, _G.MenuConfig.HitboxEnabled)
		end
	end
end

-- Health ESP
local function healthESP(m, on)
	local head = m:FindFirstChild("Head")
	local hum = m:FindFirstChildOfClass("Humanoid")

	if not head or not hum then return end

	local old = head:FindFirstChild("CustomNPCHealthESP")

	if not on then
		if old then old:Destroy() end
		return
	end

	if not validNPC(m) or old then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "CustomNPCHealthESP"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(90, 26)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = math.huge
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, .5, 0)
	name.BackgroundTransparency = 1
	name.Text = m.Name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = .3
	name.Font = Enum.Font.GothamBold
	name.TextSize = 11
	name.Parent = gui

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, .45, 0)
	bg.Position = UDim2.new(0, 0, .55, 0)
	bg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	bg.BorderSizePixel = 1
	bg.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local hp = Instance.new("TextLabel")
	hp.Size = UDim2.fromScale(1, 1)
	hp.BackgroundTransparency = 1
	hp.TextColor3 = Color3.new(1, 1, 1)
	hp.TextStrokeTransparency = .4
	hp.Font = Enum.Font.GothamBold
	hp.TextSize = 10
	hp.ZIndex = 2
	hp.Parent = bg

	local function update()
		if not gui.Parent then return end

		local cur = math.max(0, math.floor(hum.Health))
		local max = math.max(1, math.floor(hum.MaxHealth))
		local ratio = math.clamp(cur / max, 0, 1)

		fill.Size = UDim2.fromScale(ratio, 1)
		hp.Text = cur .. " / " .. max

		if ratio > .5 then
			fill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
		elseif ratio > .25 then
			fill.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
		else
			fill.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
		end
	end

	update()

	local conn = hum.HealthChanged:Connect(update)

	hum.Died:Once(function()
		conn:Disconnect()
		if gui then gui:Destroy() end
	end)
end

_G.UpdateHealthESP = function()
	for _, v in workspace:GetDescendants() do
		if v:IsA("Humanoid") and v.Parent then
			healthESP(v.Parent, _G.MenuConfig.HealthESPEnabled)
		end
	end
end

-- Target
local function removeMarker(m)
	local h = m and m:FindFirstChild("Head")
	if not h then return end

	local x = h:FindFirstChild("NPCTargetMarker")
	if x then x:Destroy() end
end

local function clearTarget()
	removeMarker(target)
	target = nil

	if _G.NPCTargetDiedConn then
		_G.NPCTargetDiedConn:Disconnect()
		_G.NPCTargetDiedConn = nil
	end
end

local function screenPos(head)
	local p, visible = Cam:WorldToViewportPoint(head.Position)

	if not visible or p.Z <= 0 then
		return
	end

	return Vector2.new(p.X, p.Y)
end

local function inRange(head)
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")

	if not root then return false end

	return (head.Position - root.Position).Magnitude
		<= _G.MenuConfig.NPCTargetMaxDistance
end

local function addMarker(m)
	local head = m:FindFirstChild("Head")
	if not head then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NPCTargetMarker"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(55, 55)
	gui.AlwaysOnTop = true
	gui.Parent = head

	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundTransparency = 1
	circle.BorderSizePixel = 2
	circle.BorderColor3 = Color3.fromRGB(255, 170, 0)
	circle.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 18)
	text.Position = UDim2.new(0, 0, 1, 2)
	text.BackgroundTransparency = 1
	text.Text = "TARGET"
	text.TextColor3 = Color3.fromRGB(255, 170, 0)
	text.TextStrokeTransparency = .25
	text.Font = Enum.Font.GothamBold
	text.TextSize = 10
	text.Parent = gui
end

local function findTarget()
	local center = Cam.ViewportSize / 2
	local best, bestDist = nil, math.huge

	for _, v in workspace:GetDescendants() do
		if v:IsA("Humanoid") and v.Parent then
			local m = v.Parent

			if validNPC(m) then
				local h = m:FindFirstChild("Head")

				if h and inRange(h) then
					local p = screenPos(h)

					if p then
						local d = (p - center).Magnitude

						if d < bestDist then
							bestDist = d
							best = m
						end
					end
				end
			end
		end
	end

	return best
end

local function targetValid()
	if not target or not validNPC(target) then
		return false
	end

	local h = target:FindFirstChild("Head")

	return h
		and inRange(h)
		and screenPos(h) ~= nil
end

local function updateTarget()
	if not _G.MenuConfig.NPCTargetEnabled then
		if target then clearTarget() end
		return
	end

	if _G.MenuConfig.NPCTargetHold and targetValid() then
		return
	end

	clearTarget()

	local newTarget = findTarget()
	if not newTarget then return end

	target = newTarget
	addMarker(target)

	local hum = target:FindFirstChildOfClass("Humanoid")

	if hum then
		_G.NPCTargetDiedConn =
			hum.Died:Once(clearTarget)
	end
end

_G.NPCTargetRenderConn =
	RunService.RenderStepped:Connect(updateTarget)

-- New NPCs
_G.HitboxAddedConn =
	workspace.DescendantAdded:Connect(function(v)
		if not v:IsA("Humanoid") then return end

		local m = v.Parent
		if not m then return end

		local head = m:WaitForChild("Head", 3)
		if not head then return end

		if _G.MenuConfig.HitboxEnabled then
			hitbox(m, true)
		end

		if _G.MenuConfig.HealthESPEnabled then
			healthESP(m, true)
		end

		v.Died:Once(function()
			hitbox(m, false)
			healthESP(m, false)

			if target == m then
				clearTarget()
			end
		end)
	end)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ControlPanelGUI"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")
_G.HitboxGUI = gui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(230, 285)
main.Position = UDim2.fromOffset(20, 20)
main.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
title.Text = "  Control Menu [RCtrl]"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local min = Instance.new("TextButton")
min.Size = UDim2.fromOffset(24, 22)
min.Position = UDim2.new(1, -27, 0, 3)
min.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
min.Text = "-"
min.TextColor3 = Color3.new(1, 1, 1)
min.Font = Enum.Font.GothamBold
min.TextSize = 16
min.Parent = title

local minimized = false

min.MouseButton1Click:Connect(function()
	minimized = not minimized
	main.Size = minimized
		and UDim2.fromOffset(230, 28)
		or UDim2.fromOffset(230, 285)
	min.Text = minimized and "+" or "-"
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -10, 1, -36)
scroll.Position = UDim2.fromOffset(5, 32)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = scroll

local function section(t)
	local x = Instance.new("TextLabel")
	x.Size = UDim2.new(1, -6, 0, 20)
	x.BackgroundTransparency = 1
	x.Text = "-- " .. t .. " --"
	x.TextColor3 = Color3.fromRGB(150, 180, 255)
	x.Font = Enum.Font.GothamBold
	x.TextSize = 11
	x.Parent = scroll
end

local function toggle(text, default, callback)
	local state = default

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -6, 0, 28)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = scroll

	local function update(v)
		state = v
		b.BackgroundColor3 =
			v and Color3.fromRGB(46, 204, 113)
			or Color3.fromRGB(231, 76, 60)
		b.Text = text .. (v and ": ON" or ": OFF")
	end

	update(state)

	b.MouseButton1Click:Connect(function()
		update(not state)
		callback(state)
	end)

	return update
end

local function input(label, value, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 26)
	row.BackgroundTransparency = 1
	row.Parent = scroll

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(.6, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Text = " " .. label
	l.TextColor3 = Color3.fromRGB(220, 220, 220)
	l.Font = Enum.Font.Gotham
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(.38, 0, 1, 0)
	box.Position = UDim2.new(.62, 0, 0, 0)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	box.Text = tostring(value)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.Font = Enum.Font.GothamBold
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.Parent = row

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)

		if n then
			callback(n)
			box.Text = tostring(n)
		else
			box.Text = tostring(value)
		end
	end)
end

-- Settings
section("HITBOX")

local hitboxBtn = toggle(
	"Hitbox [Numpad 0]",
	_G.MenuConfig.HitboxEnabled,
	function(v)
		_G.MenuConfig.HitboxEnabled = v
		_G.UpdateHitbox()
	end
)

input("Size:", _G.MenuConfig.HitboxSize, function(v)
	_G.MenuConfig.HitboxSize = math.max(1, v)

	if _G.MenuConfig.HitboxEnabled then
		_G.UpdateHitbox()
	end
end)

input("Transparency:", _G.MenuConfig.HitboxTransparency, function(v)
	_G.MenuConfig.HitboxTransparency = math.clamp(v, 0, 1)

	if _G.MenuConfig.HitboxEnabled then
		_G.UpdateHitbox()
	end
end)

section("ESP")

toggle(
	"NPC Health",
	_G.MenuConfig.HealthESPEnabled,
	function(v)
		_G.MenuConfig.HealthESPEnabled = v
		_G.UpdateHealthESP()
	end
)

section("TARGET")

local targetBtn = toggle(
	"NPC Head Target [T]",
	_G.MenuConfig.NPCTargetEnabled,
	function(v)
		_G.MenuConfig.NPCTargetEnabled = v

		if not v then
			clearTarget()
		end
	end
)

input(
	"Max Distance:",
	_G.MenuConfig.NPCTargetMaxDistance,
	function(v)
		_G.MenuConfig.NPCTargetMaxDistance =
			math.max(1, v)
	end
)

-- Hotkeys
_G.HitboxKeybind =
	UIS.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.KeyCode == Enum.KeyCode.KeypadZero then
			_G.MenuConfig.HitboxEnabled =
				not _G.MenuConfig.HitboxEnabled

			hitboxBtn(_G.MenuConfig.HitboxEnabled)
			_G.UpdateHitbox()

		elseif input.KeyCode == Enum.KeyCode.T then
			_G.MenuConfig.NPCTargetEnabled =
				not _G.MenuConfig.NPCTargetEnabled

			targetBtn(_G.MenuConfig.NPCTargetEnabled)

			if not _G.MenuConfig.NPCTargetEnabled then
				clearTarget()
			end

		elseif input.KeyCode == Enum.KeyCode.RightControl then
			main.Visible = not main.Visible
		end
	end)

-- All features start OFF.
```
