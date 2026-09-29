--============================================================
-- realwalker v1.85.4 - Teleport.lua
-- Round, player, murderer, sheriff, map, and lobby teleports.
--============================================================

local MM2 =
	getgenv
	and getgenv().REALWALKER_STATE
	or _G.REALWALKER_STATE

assert(
	MM2
	and MM2.UI
	and MM2.UI.TeleportPage,
	"Load Shared.lua + UI.lua first"
)

local S = MM2.Services
local Players = S.Players
local LocalPlayer = MM2.LocalPlayer
local UI = MM2.UI

local SelectedPlayerName = nil

--============================================================
-- EXACT LOBBY POSITION
--
-- Captured manually with realwalker Lobby Diagnostic.
--============================================================

local LOBBY_CFRAME =
	CFrame.new(
		13.497,
		504.818,
		-9.978,

		-0.996942,
		0.000000,
		-0.078148,

		0.000000,
		1.000000,
		0.000000,

		0.078148,
		0.000000,
		-0.996942
	)

--============================================================
-- HELPERS
--============================================================

local function GetAliveCharacter(player)

	if not player then
		return nil
	end

	local char =
		player.Character

	if not char then
		return nil
	end

	local humanoid =
		char:FindFirstChildOfClass(
			"Humanoid"
		)

	local hrp =
		char:FindFirstChild(
			"HumanoidRootPart"
		)

	if not humanoid
		or humanoid.Health <= 0
		or not hrp
	then
		return nil
	end

	return char,humanoid,hrp
end

local function GetLocalTeleportCharacter()

	local char,humanoid,hrp =
		MM2.GetLocalCharacter()

	if not char
		or not humanoid
		or humanoid.Health <= 0
		or not hrp
	then

		MM2.Notify(
			"Your character is not ready.",
			2.5,
			"triangle-alert",
			"Teleport"
		)

		return nil
	end

	return char,humanoid,hrp
end

local function TeleportLocalToCFrame(
	targetCFrame
)

	local char,humanoid,hrp =
		GetLocalTeleportCharacter()

	if not char then
		return false
	end

	if typeof(targetCFrame)
		~= "CFrame"
	then
		return false
	end

	-- Remove previous movement before teleporting.
	hrp.AssemblyLinearVelocity =
		Vector3.zero

	hrp.AssemblyAngularVelocity =
		Vector3.zero

	char:PivotTo(
		targetCFrame
	)

	-- Clear movement again after Roblox updates the character.
	task.defer(function()

		if hrp
			and hrp.Parent
		then

			hrp.AssemblyLinearVelocity =
				Vector3.zero

			hrp.AssemblyAngularVelocity =
				Vector3.zero
		end
	end)

	return true
end

local function TeleportNearHRP(
	targetHRP,
	mode
)

	if not targetHRP
		or not targetHRP.Parent
	then
		return false
	end

	local targetCFrame

	if mode == "behind" then

		-- Roblox character forward is local -Z.
		-- Positive Z places us behind the target.
		targetCFrame =
			targetHRP.CFrame
			* CFrame.new(
				0,
				0,
				4.5
			)

	elseif mode == "side" then

		targetCFrame =
			targetHRP.CFrame
			* CFrame.new(
				4.5,
				0,
				1.5
			)

	else

		targetCFrame =
			targetHRP.CFrame
			* CFrame.new(
				0,
				0,
				4.5
			)
	end

	return TeleportLocalToCFrame(
		targetCFrame
	)
end

local function RefreshServerRoles()

	pcall(function()

		MM2.UpdateServerRoles()

	end)
end

--============================================================
-- MURDERER
--============================================================

local function GetMurdererPlayer()

	RefreshServerRoles()

	local murdererName =
		MM2.State.ServerMurder

	if not murdererName then
		return nil
	end

	local murderer =
		Players:FindFirstChild(
			murdererName
		)

	if not murderer
		or murderer == LocalPlayer
	then
		return nil
	end

	local _,humanoid,hrp =
		GetAliveCharacter(
			murderer
		)

	if not humanoid
		or not hrp
	then
		return nil
	end

	if MM2.GetPlayerRole(
		murderer
	) ~= "Murderer"
	then
		return nil
	end

	return murderer,hrp
end

local function TeleportBehindMurderer()

	local murderer,hrp =
		GetMurdererPlayer()

	if not murderer
		or not hrp
	then

		MM2.Notify(
			"No active Murderer found.",
			2.5,
			"triangle-alert",
			"Teleport"
		)

		return false
	end

	if TeleportNearHRP(
		hrp,
		"behind"
	) then

		MM2.Notify(
			"Teleported behind "
				.. murderer.DisplayName
				.. ".",
			2.0,
			"navigation",
			"Teleport"
		)

		return true
	end

	return false
end

--============================================================
-- SHERIFF
--============================================================

local function GetSheriffPlayer()

	RefreshServerRoles()

	local sheriffName =
		MM2.State.ServerSheriff

	if not sheriffName then
		return nil
	end

	local sheriff =
		Players:FindFirstChild(
			sheriffName
		)

	if not sheriff
		or sheriff == LocalPlayer
	then
		return nil
	end

	local _,humanoid,hrp =
		GetAliveCharacter(
			sheriff
		)

	if not humanoid
		or not hrp
	then
		return nil
	end

	if MM2.GetPlayerRole(
		sheriff
	) ~= "Sheriff"
	then
		return nil
	end

	return sheriff,hrp
end

local function TeleportBehindSheriff()

	local sheriff,hrp =
		GetSheriffPlayer()

	if not sheriff
		or not hrp
	then

		MM2.Notify(
			"No active Sheriff found.",
			2.5,
			"triangle-alert",
			"Teleport"
		)

		return false
	end

	if TeleportNearHRP(
		hrp,
		"behind"
	) then

		MM2.Notify(
			"Teleported behind "
				.. sheriff.DisplayName
				.. ".",
			2.0,
			"navigation",
			"Teleport"
		)

		return true
	end

	return false
end

--============================================================
-- ACTIVE MAP
--============================================================

local function FindMapAnchorPlayer()

	RefreshServerRoles()

	local fallbackMurderer = nil

	for _,player in ipairs(
		Players:GetPlayers()
	) do

		if player ~= LocalPlayer then

			local role =
				MM2.GetPlayerRole(
					player
				)

			local _,humanoid,hrp =
				GetAliveCharacter(
					player
				)

			if humanoid
				and hrp
				and role ~= "None"
			then

				-- Prefer a non-Murderer player so Teleport
				-- to Map does not normally place the user
				-- beside the Murderer.
				if role ~= "Murderer" then

					return player,hrp
				end

				fallbackMurderer = {
					Player = player,
					HRP = hrp,
				}
			end
		end
	end

	if fallbackMurderer then

		return
			fallbackMurderer.Player,
			fallbackMurderer.HRP
	end

	return nil
end

local function TeleportToMap()

	local player,hrp =
		FindMapAnchorPlayer()

	if not player
		or not hrp
	then

		MM2.Notify(
			"No active round player found.",
			2.5,
			"triangle-alert",
			"Teleport"
		)

		return false
	end

	if TeleportNearHRP(
		hrp,
		"side"
	) then

		MM2.Notify(
			"Teleported to the active map.",
			2.0,
			"map",
			"Teleport"
		)

		return true
	end

	return false
end

--============================================================
-- LOBBY
--
-- Uses the exact manually captured lobby CFrame.
-- No player scanning or lobby-name guessing.
--============================================================

local function TeleportToLobby()

	if TeleportLocalToCFrame(
		LOBBY_CFRAME
	) then

		MM2.Notify(
			"Teleported to lobby.",
			2.0,
			"house",
			"Teleport"
		)

		return true
	end

	return false
end

--============================================================
-- PLAYER TARGETS
--============================================================

local function GetPlayerNames()

	local values = {}

	for _,player in ipairs(
		Players:GetPlayers()
	) do

		if player ~= LocalPlayer then

			table.insert(
				values,
				player.Name
			)
		end
	end

	table.sort(
		values,
		function(a,b)

			return string.lower(a)
				< string.lower(b)
		end
	)

	return values
end

local function GetSelectedPlayer()

	if not SelectedPlayerName then
		return nil
	end

	local player =
		Players:FindFirstChild(
			SelectedPlayerName
		)

	if player == LocalPlayer then
		return nil
	end

	return player
end

local function TeleportToSelectedPlayer(
	behind
)

	local player =
		GetSelectedPlayer()

	if not player then

		MM2.Notify(
			"Select a player first.",
			2.5,
			"user-x",
			"Teleport"
		)

		return false
	end

	local _,humanoid,hrp =
		GetAliveCharacter(
			player
		)

	if not humanoid
		or not hrp
	then

		MM2.Notify(
			"That player is not currently available.",
			2.5,
			"user-x",
			"Teleport"
		)

		return false
	end

	local ok =
		TeleportNearHRP(
			hrp,
			behind
				and "behind"
				or "side"
		)

	if ok then

		MM2.Notify(
			behind
				and (
					"Teleported behind "
					.. player.DisplayName
					.. "."
				)
				or (
					"Teleported to "
					.. player.DisplayName
					.. "."
				),
			2.0,
			"navigation",
			"Teleport"
		)
	end

	return ok
end

--============================================================
-- EXPOSE FUNCTIONS
--============================================================

MM2.Functions.TeleportBehindMurderer =
	TeleportBehindMurderer

MM2.Functions.TeleportBehindSheriff =
	TeleportBehindSheriff

MM2.Functions.TeleportToMap =
	TeleportToMap

MM2.Functions.TeleportToLobby =
	TeleportToLobby

MM2.Functions.TeleportToSelectedPlayer =
	TeleportToSelectedPlayer

--============================================================
-- UI - ROUND
--============================================================

UI.AddSection(
	UI.TeleportPage,
	"Round",
	"Quick teleports for the active round"
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Teleport Behind Murderer",
	"Teleport a few studs behind the current Murderer",
	TeleportBehindMurderer,
	"skull",
	"danger"
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Teleport Behind Sheriff",
	"Teleport a few studs behind the current Sheriff",
	TeleportBehindSheriff,
	"shield",
	"blue"
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Teleport to Map",
	"Teleport near an alive player in the active round",
	TeleportToMap,
	"map"
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Teleport to Lobby / Intermission",
	"Teleport to the exact saved lobby position",
	TeleportToLobby,
	"house"
)

--============================================================
-- UI - PLAYERS
--============================================================

UI.AddSection(
	UI.TeleportPage,
	"Players",
	"Teleport to a specific player"
)

local playerNames =
	GetPlayerNames()

local PlayerDropdown = UI.CreateDropdown(
	UI.TeleportPage,
	"Player",
	"Choose a player",
	playerNames,
	nil,
	function(value)

		if type(value) == "table" then

			value =
				value.Value
				or value.Title
				or value.Name
				or value[1]
		end

		if value ~= nil then

			SelectedPlayerName =
				tostring(
					value
				)
		end
	end
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Teleport to Player",
	"Teleport next to the selected player",
	function()

		TeleportToSelectedPlayer(
			false
		)
	end,
	"user-round"
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Teleport Behind Player",
	"Teleport a few studs behind the selected player",
	function()

		TeleportToSelectedPlayer(
			true
		)
	end,
	"navigation"
)

UI.CreateActionFeature(
	UI.TeleportPage,
	"Refresh Player List",
	"Refreshes the selectable player list",
	function()
		local names = GetPlayerNames()
		if PlayerDropdown then
			pcall(function()
				PlayerDropdown:Refresh(names)
			end)
		end
		MM2.Notify("Player list refreshed.", 1.5, "refresh-cw", "Player List")
	end,
	"refresh-cw"
)

--============================================================
-- COMPLETE
--============================================================

print(
	"[realwalker Teleport] v1.85.4 loaded"
)

return MM2