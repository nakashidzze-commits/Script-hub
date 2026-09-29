-- BLIZZARD MM2 - SIMPLE PC DIAGNOSTIC
-- Run separately. Do NOT replace AutoTrader.lua or Notifier.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove previous diagnostic GUI
local old = playerGui:FindFirstChild("realwalkerSimplePCDiag")
if old then old:Destroy() end

-- BASIC PLAYERGUI FIRST - deliberately no gethui/CoreGui
local gui = Instance.new("ScreenGui")
gui.Name = "realwalkerSimplePCDiag"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(520, 360)
frame.Position = UDim2.new(0.5, -260, 0.5, -180)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 36)
title.Position = UDim2.fromOffset(10, 6)
title.BackgroundTransparency = 1
title.Text = "BLIZZARD PC DIAGNOSTIC"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 24)
status.Position = UDim2.fromOffset(10, 42)
status.BackgroundTransparency = 1
status.Text = "DIAGNOSTIC STARTED"
status.TextColor3 = Color3.fromRGB(120, 230, 150)
status.Font = Enum.Font.GothamBold
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -120)
scroll.Position = UDim2.fromOffset(10, 70)
scroll.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = frame

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -12, 0, 0)
logLabel.Position = UDim2.fromOffset(6, 6)
logLabel.AutomaticSize = Enum.AutomaticSize.Y
logLabel.BackgroundTransparency = 1
logLabel.Text = ""
logLabel.TextColor3 = Color3.new(1,1,1)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextWrapped = true
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Parent = scroll

local logs = {}

local function log(message)
	table.insert(logs, tostring(message))
	logLabel.Text = table.concat(logs, "\n")
end

local copy = Instance.new("TextButton")
copy.Size = UDim2.fromOffset(150, 32)
copy.Position = UDim2.new(0, 10, 1, -40)
copy.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
copy.BorderSizePixel = 0
copy.Text = "COPY LOGS"
copy.TextColor3 = Color3.new(1,1,1)
copy.Font = Enum.Font.GothamBold
copy.TextSize = 12
copy.Parent = frame
Instance.new("UICorner", copy).CornerRadius = UDim.new(0, 7)

copy.MouseButton1Click:Connect(function()
	local value = table.concat(logs, "\n")
	local ok = false
	if type(setclipboard) == "function" then
		ok = pcall(setclipboard, value)
	elseif type(toclipboard) == "function" then
		ok = pcall(toclipboard, value)
	end
	status.Text = ok and "LOGS COPIED" or "COPY UNAVAILABLE - SCREENSHOT LOGS"
end)

-- Simple drag
do
	local dragging = false
	local startMouse
	local startPos

	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			startMouse = input.Position
			startPos = frame.Position
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - startMouse
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

log("PASS 1: Script executed")
log("PASS 2: PlayerGui GUI created")
log("Platform: " .. tostring(UIS:GetPlatform()))
log("Player: " .. player.Name)

task.spawn(function()
	task.wait(0.5)

	-- HTTP function availability only; DOES NOT send a request.
	local httpNames = {}

	if type(request) == "function" then
		table.insert(httpNames, "request")
	end

	if type(http_request) == "function" then
		table.insert(httpNames, "http_request")
	end

	pcall(function()
		if syn and type(syn.request) == "function" then
			table.insert(httpNames, "syn.request")
		end
	end)

	if #httpNames > 0 then
		log("PASS 3: HTTP function found: " .. table.concat(httpNames, ", "))
	else
		log("FAIL 3: NO supported HTTP request function found")
	end

	log("TEST 4: Looking for ReplicatedStorage.Modules...")
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	if not modules then
		modules = ReplicatedStorage:WaitForChild("Modules", 5)
	end

	if not modules then
		log("STOP: Modules folder not found")
		status.Text = "STOPPED AT MODULES"
		return
	end
	log("PASS 4: Modules folder found")

	log("TEST 5: Looking for InventoryModule...")
	local moduleObject = modules:FindFirstChild("InventoryModule")
	if not moduleObject then
		moduleObject = modules:WaitForChild("InventoryModule", 5)
	end

	if not moduleObject then
		log("STOP: InventoryModule not found")
		status.Text = "STOPPED AT INVENTORYMODULE"
		return
	end
	log("PASS 5: InventoryModule found (" .. moduleObject.ClassName .. ")")

	log("TEST 6: require(InventoryModule) starting...")

	local finished = false
	local requireOK = false
	local result

	task.spawn(function()
		requireOK, result = pcall(require, moduleObject)
		finished = true
	end)

	for second = 1, 5 do
		task.wait(1)
		if finished then break end
		log("require still waiting... " .. second .. "s")
	end

	if not finished then
		log("FAIL 6: require did not return within 5 seconds")
		status.Text = "STOPPED: REQUIRE STUCK"
		return
	end

	if not requireOK then
		log("FAIL 6: require error: " .. tostring(result))
		status.Text = "STOPPED: REQUIRE ERROR"
		return
	end

	log("PASS 6: InventoryModule loaded")

	local inventory = result.MyInventory
	log("TEST 7: MyInventory type = " .. typeof(inventory))

	if type(inventory) ~= "table" then
		log("FAIL 7: MyInventory is not a table")
		status.Text = "STOPPED AT MYINVENTORY"
		return
	end

	local data = inventory.Data
	log("TEST 8: Data type = " .. typeof(data))

	if type(data) ~= "table" then
		log("FAIL 8: Data is not a table")
		status.Text = "STOPPED AT DATA"
		return
	end

	local weapons = data.Weapons
	log("TEST 9: Weapons type = " .. typeof(weapons))

	if type(weapons) ~= "table" then
		log("FAIL 9: Weapons is not a table")
		status.Text = "STOPPED AT WEAPONS"
		return
	end

	log("PASS 9: Weapons table accessible")

	-- Search keys/fields for Snowflake without modifying anything.
	local visited = {}
	local matches = 0

	local function walk(tbl, depth, path)
		if type(tbl) ~= "table" or visited[tbl] or depth > 12 then
			return
		end
		visited[tbl] = true

		for key, value in pairs(tbl) do
			local keyText = string.lower(tostring(key))

			if string.find(keyText, "snowflake", 1, true) then
				matches += 1
				log("SNOWFLAKE KEY: " .. path .. "/" .. tostring(key))
			end

			if type(value) == "table" then
				local name = value.ItemName or value.DisplayName or value.Name or value.name
				local id = value.DataID or value.ItemID or value.ID or value.Id or value.id
				local combined = string.lower(tostring(name) .. " " .. tostring(id))

				if string.find(combined, "snowflake", 1, true) then
					matches += 1
					log("SNOWFLAKE ENTRY FOUND")
					log("Name = " .. tostring(name))
					log("DataID = " .. tostring(id or key))
					log("Rarity = " .. tostring(value.Rarity or value.rarity or value.Tier))
					log("Type = " .. tostring(value.ItemType or value.WeaponType or value.Type or value.type))
					log("Amount = " .. tostring(value.Amount or value.amount or value.Count or value.Quantity))
				end

				walk(value, depth + 1, path .. "/" .. tostring(key))
			end
		end
	end

	log("TEST 10: Searching raw Weapons table for Snowflake...")
	local scanOK, scanError = pcall(function()
		walk(weapons, 0, "Weapons")
	end)

	if not scanOK then
		log("FAIL 10: Snowflake scan error: " .. tostring(scanError))
		status.Text = "COMPLETE WITH SCAN ERROR"
		return
	end

	log("PASS 10: Raw scan finished. Snowflake matches = " .. tostring(matches))
	log("DIAGNOSTIC COMPLETE")
	status.Text = "COMPLETE - COPY LOGS"
end)
