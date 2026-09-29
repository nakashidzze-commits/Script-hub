--============================================================
-- realwalker v1.85.4 - Shared.lua
-- Shared services/state/helpers/role cache.
--
-- Match ESP reliability fix:
-- - CharacterAdded no longer instantly marks a player eliminated.
-- - Dead/Killed server data is the primary elimination source.
-- - A recent respawn is only treated as eliminated when the
--   server snapshot is missing/invalid for that player.
-- - Stale-role suppression only activates during a respawn
--   burst when live-round evidence is gone.
--============================================================

local PreviousMM2 =
	getgenv
	and getgenv().REALWALKER_STATE
	or _G.REALWALKER_STATE

if PreviousMM2 then
	PreviousMM2.Running = false

	if PreviousMM2.Connections then
		for _,connection in ipairs(PreviousMM2.Connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	if PreviousMM2.Functions then
		if PreviousMM2.Functions.ClearPlayerESP then
			pcall(PreviousMM2.Functions.ClearPlayerESP)
		end
		if PreviousMM2.Functions.ClearGunESP then
			pcall(PreviousMM2.Functions.ClearGunESP)
		end
		if PreviousMM2.Functions.ClearTracers then
			pcall(PreviousMM2.Functions.ClearTracers)
		end
		if PreviousMM2.Functions.ClearCoinESP then
			pcall(PreviousMM2.Functions.ClearCoinESP)
		end
	end

	if PreviousMM2.UI and PreviousMM2.UI.TracerGui then
		pcall(function()
			PreviousMM2.UI.TracerGui:Destroy()
		end)
	end

	task.wait()
end

local MM2 = {}

if getgenv then
	getgenv().REALWALKER_STATE = MM2
else
	_G.REALWALKER_STATE = MM2
end

MM2.Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	UserInputService = game:GetService("UserInputService"),
	StarterGui = game:GetService("StarterGui"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	TweenService = game:GetService("TweenService"),
	CoreGui = game:GetService("CoreGui"),
}

local S = MM2.Services

MM2.LocalPlayer = S.Players.LocalPlayer
MM2.PlayerGui = MM2.LocalPlayer:WaitForChild("PlayerGui")
MM2.Camera = workspace.CurrentCamera
MM2.Running = true
MM2.Connections = {}

function MM2.Track(connection)
	table.insert(MM2.Connections, connection)
	return connection
end

MM2.Flags = {
	Theme = "realwalker Mono",
	AntiFling = true,

	MatchESP = false,
	GunESP = true,
	TriggerBot = false,
	AimLock = false,
	AutoGrab = false,
	AutoFarm = false,
	ShowShootButton = false,
	Legit = false,
	HideShootButton = false,

	Fly = false,
	Noclip = false,
	InfiniteJump = false,

	MurdererTracer = false,
	SheriffTracer = false,
	HeroTracer = false,
	InnocentTracer = false,
}

MM2.Config = {
	MAX_ESP_DISTANCE = 2000,
	ROLE_CLEAR_GRACE = 1.0,
	RESPAWN_TRACK_WINDOW = 1.25,

	KnifeNames = {
		Knife = true,
		CrateKnife = true
	},

	GunNames = {
		Gun = true,
		Revolver = true
	},
}

MM2.State = {
	OriginalSheriff = nil,
	OriginalSheriffUserId = nil,

	GunDroppedThisRound = false,
	CountdownWasActive = false,

	SelectedFlingTarget = nil,
	Is_Picking_Up = false,

	ServerRolesCache = {},

	ServerMurder = nil,
	ServerSheriff = nil,
	ServerHero = nil,

	RoleRoundActive = false,
	RoleRoundSignature = nil,
	RoleRolesMissingSince = nil,

	RoleBootstrapSeen = false,
	RoleInactiveSignature = nil,

	SuppressStaleRoles = false,
	StaleSpecialSignature = nil,

	RecentRespawns = {},
	PlayerOutOfRound = {},

	GetPlayerDataRemote =
		S.ReplicatedStorage:FindFirstChild(
			"GetPlayerData",
			true
		),
}

MM2.PlayerSettings = {
	FlySpeed = 55,
	WalkSpeed = 16,
	JumpPower = 50
}

MM2.UI = MM2.UI or {}
MM2.Functions = MM2.Functions or {}

function MM2.Notify(message, duration, icon, title)
	local UI = MM2.UI

	if UI and UI.WindUI and UI.WindUI.Notify then
		local success = pcall(function()
			UI.WindUI:Notify({
				Title = tostring(title or "realwalker"),
				Content = tostring(message or ""),
				Duration = tonumber(duration) or 2.5,
				Icon = icon or "check",
			})
		end)

		if success then
			return true
		end
	end

	pcall(function()
		S.StarterGui:SetCore(
			"SendNotification",
			{
				Title = tostring(title or "realwalker"),
				Text = tostring(message or ""),
				Duration = tonumber(duration) or 2.5
			}
		)
	end)

	return false
end

function MM2.HasTool(container, allowedNames)
	if not container then
		return false
	end

	for _,obj in ipairs(container:GetChildren()) do
		if obj:IsA("Tool") and allowedNames[obj.Name] then
			return true
		end
	end

	return false
end

function MM2.HasGunAnywhere()
	local char = MM2.LocalPlayer.Character
	local bp = MM2.LocalPlayer:FindFirstChild("Backpack")

	return
		(
			char
			and (
				char:FindFirstChild("Gun")
				or char:FindFirstChild("Revolver")
			)
		)
		or
		(
			bp
			and (
				bp:FindFirstChild("Gun")
				or bp:FindFirstChild("Revolver")
			)
		)
end

--============================================================
-- LEGIT / SHOOT BUTTON VISIBILITY
--
-- The shoot button stays Visible/Active so it can still receive
-- mouse/touch input, but its visual descendants are made fully
-- transparent while Legit is enabled.
--============================================================

local ShootButtonVisualState = {}

local function IsShootButton(obj)
	if not obj or not obj:IsA("GuiButton") then
		return false
	end

	local name = string.lower(tostring(obj.Name or ""))
	local text = obj:IsA("TextButton") and string.lower(tostring(obj.Text or "")) or ""

	return name == "shoot"
		or name == "shootbutton"
		or name == "shoot button"
		or text == "shoot"
end

local function HideShootButtonVisuals(button)
	if not button or not button.Parent then
		return false
	end

	if not ShootButtonVisualState[button] then
		local state = {
			BackgroundTransparency = button.BackgroundTransparency,
			AutoButtonColor = button.AutoButtonColor,
			Descendants = {},
		}

		if button:IsA("TextButton") then
			state.TextTransparency = button.TextTransparency
		end
		if button:IsA("ImageButton") then
			state.ImageTransparency = button.ImageTransparency
		end

		for _,obj in ipairs(button:GetDescendants()) do
			local entry = {}
			if obj:IsA("GuiObject") then
				entry.BackgroundTransparency = obj.BackgroundTransparency
			end
			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				entry.TextTransparency = obj.TextTransparency
			end
			if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				entry.ImageTransparency = obj.ImageTransparency
			end
			if obj:IsA("UIStroke") then
				entry.Transparency = obj.Transparency
			end
			if next(entry) then
				state.Descendants[obj] = entry
			end
		end

		ShootButtonVisualState[button] = state
	end

	button.Visible = true
	button.Active = true
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false

	if button:IsA("TextButton") then
		button.TextTransparency = 1
	end
	if button:IsA("ImageButton") then
		button.ImageTransparency = 1
	end

	for obj in pairs(ShootButtonVisualState[button].Descendants) do
		if obj and obj.Parent then
			if obj:IsA("GuiObject") then obj.BackgroundTransparency = 1 end
			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then obj.TextTransparency = 1 end
			if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then obj.ImageTransparency = 1 end
			if obj:IsA("UIStroke") then obj.Transparency = 1 end
		end
	end

	return true
end

local function RestoreShootButtonVisuals(button)
	local state = ShootButtonVisualState[button]
	if not state or not button or not button.Parent then
		return
	end

	button.BackgroundTransparency = state.BackgroundTransparency
	button.AutoButtonColor = state.AutoButtonColor
	if button:IsA("TextButton") and state.TextTransparency ~= nil then
		button.TextTransparency = state.TextTransparency
	end
	if button:IsA("ImageButton") and state.ImageTransparency ~= nil then
		button.ImageTransparency = state.ImageTransparency
	end

	for obj,entry in pairs(state.Descendants) do
		if obj and obj.Parent then
			if obj:IsA("GuiObject") and entry.BackgroundTransparency ~= nil then obj.BackgroundTransparency = entry.BackgroundTransparency end
			if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and entry.TextTransparency ~= nil then obj.TextTransparency = entry.TextTransparency end
			if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and entry.ImageTransparency ~= nil then obj.ImageTransparency = entry.ImageTransparency end
			if obj:IsA("UIStroke") and entry.Transparency ~= nil then obj.Transparency = entry.Transparency end
		end
	end
end

function MM2.Functions.SetShootButtonHidden(hidden)
	MM2.Flags.HideShootButton = hidden == true

	local found = false
	local containers = {
		MM2.PlayerGui,
		S.CoreGui,
	}

	for _,container in ipairs(containers) do
		if container then
			for _,obj in ipairs(container:GetDescendants()) do
				if IsShootButton(obj) then
					found = true
					if hidden then
						HideShootButtonVisuals(obj)
					else
						RestoreShootButtonVisuals(obj)
					end
				end
			end
		end
	end

	return found
end

task.spawn(function()
	while MM2.Running do
		if MM2.Flags.Legit then
			MM2.Functions.SetShootButtonHidden(true)
		elseif MM2.Flags.HideShootButton then
			MM2.Functions.SetShootButtonHidden(false)
		end
		task.wait(0.25)
	end
end

function MM2.IsActuallyVisible(guiObject)
	local current = guiObject

	while current and current ~= MM2.PlayerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end

		if current:IsA("LayerCollector") and not current.Enabled then
			return false
		end

		current = current.Parent
	end

	return true
end

function MM2.GetLocalCharacter()
	local char = MM2.LocalPlayer.Character
	if not char then
		return nil
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp then
		return nil
	end

	return char, humanoid, hrp
end

function MM2.BuildSpecialSignature(cache)
	local result = {}

	for playerName,role in pairs(cache) do
		if role == "Murderer"
			or role == "Sheriff"
			or role == "Hero"
		then
			table.insert(result, playerName .. "=" .. role)
		end
	end

	table.sort(result)
	return table.concat(result, "|")
end

local function BeginRoleRound(
	newCache,
	newMurder,
	newSheriff,
	newHero
)
	local State = MM2.State

	State.RoleRoundActive = true
	State.RoleRolesMissingSince = nil
	State.RoleRoundSignature = MM2.BuildSpecialSignature(newCache)

	State.PlayerOutOfRound = {}
	State.RecentRespawns = {}

	State.SuppressStaleRoles = false
	State.StaleSpecialSignature = nil

	State.ServerRolesCache = newCache
	State.ServerMurder = newMurder
	State.ServerSheriff = newSheriff
	State.ServerHero = newHero
end

local function EndRoleRound()
	local State = MM2.State

	State.RoleRoundActive = false
	State.RoleRoundSignature = nil
	State.RoleRolesMissingSince = nil

	State.ServerRolesCache = {}
	State.ServerMurder = nil
	State.ServerSheriff = nil
	State.ServerHero = nil

	State.RecentRespawns = {}
	State.PlayerOutOfRound = {}

	State.SuppressStaleRoles = false
	State.StaleSpecialSignature = nil

	State.RoleInactiveSignature = ""
end

MM2.Functions.BeginRoleRound = BeginRoleRound
MM2.Functions.EndRoleRound = EndRoleRound

local function HasLiveRoundEvidence()
	if workspace:FindFirstChild("CoinContainer", true) then
		return true
	end

	if workspace:FindFirstChild("GunDrop", true) then
		return true
	end

	for _,player in ipairs(S.Players:GetPlayers()) do
		local char = player.Character

		if char then
			for _,obj in ipairs(char:GetChildren()) do
				if obj:IsA("Tool")
					and (
						MM2.Config.KnifeNames[obj.Name]
						or MM2.Config.GunNames[obj.Name]
					)
				then
					return true
				end
			end
		end
	end

	return false
end

local function BuildStartupPlayerOutOfRound(rawRoles)
	local result = {}

	for _,player in ipairs(S.Players:GetPlayers()) do
		if player ~= MM2.LocalPlayer then
			local data = rawRoles[player.Name]

			if type(data) ~= "table"
				or data.Dead == true
				or data.Killed == true
			then
				result[player.Name] = true
			end
		end
	end

	return result
end

local function HasLiveMurderer(rawRoles, murdererName)
	if not murdererName then
		return false
	end

	local data = rawRoles[murdererName]

	if type(data) ~= "table" then
		return false
	end

	if data.Role ~= "Murderer" then
		return false
	end

	if data.Dead == true or data.Killed == true then
		return false
	end

	return true
end

local function SyncPlayerOutOfRound(rawRoles)
	local State = MM2.State

	if State.RoleRoundActive ~= true then
		return
	end

	local now = os.clock()

	for _,player in ipairs(S.Players:GetPlayers()) do
		if player ~= MM2.LocalPlayer then
			local name = player.Name
			local data = rawRoles[name]

			if type(data) == "table" then
				if data.Dead == true or data.Killed == true then
					State.PlayerOutOfRound[name] = true

				elseif data.Role ~= nil then
					State.PlayerOutOfRound[name] = nil
					State.RecentRespawns[name] = nil
				end

			elseif State.RecentRespawns[name] then
				-- A reset followed by disappearance from the role
				-- snapshot is strong evidence they left the round.
				State.PlayerOutOfRound[name] = true
			end
		end
	end

	for name,timestamp in pairs(State.RecentRespawns) do
		if now - timestamp > MM2.Config.RESPAWN_TRACK_WINDOW then
			State.RecentRespawns[name] = nil
		end
	end
end

function MM2.UpdateServerRoles()
	local State = MM2.State

	if not State.GetPlayerDataRemote
		or not State.GetPlayerDataRemote.Parent
	then
		State.GetPlayerDataRemote =
			S.ReplicatedStorage:FindFirstChild(
				"GetPlayerData",
				true
			)
	end

	if not State.GetPlayerDataRemote
		or not State.GetPlayerDataRemote:IsA("RemoteFunction")
	then
		return
	end

	local success,rawRoles = pcall(function()
		return State.GetPlayerDataRemote:InvokeServer()
	end)

	if not success or type(rawRoles) ~= "table" then
		return
	end

	local newCache = {}
	local newMurder = nil
	local newSheriff = nil
	local newHero = nil

	for playerName,data in pairs(rawRoles) do
		if type(playerName) == "string"
			and type(data) == "table"
			and data.Role
		then
			newCache[playerName] = data.Role

			if data.Role == "Murderer" then
				newMurder = playerName
			elseif data.Role == "Sheriff" then
				newSheriff = playerName
			elseif data.Role == "Hero" then
				newHero = playerName
			end
		end
	end

	local sig = MM2.BuildSpecialSignature(newCache)

	if not State.RoleRoundActive then
		local hasAssignedPair =
			newMurder ~= nil
			and newSheriff ~= nil

		local hasLiveMurderer =
			HasLiveMurderer(
				rawRoles,
				newMurder
			)

		if not State.RoleBootstrapSeen then
			State.RoleBootstrapSeen = true
			State.RoleInactiveSignature = sig

			if hasLiveMurderer and HasLiveRoundEvidence() then
				local startupOutOfRound =
					BuildStartupPlayerOutOfRound(rawRoles)

				BeginRoleRound(
					newCache,
					newMurder,
					newSheriff,
					newHero
				)

				State.PlayerOutOfRound =
					startupOutOfRound

				return
			end

			State.ServerRolesCache = newCache
			State.ServerMurder = newMurder
			State.ServerSheriff = newSheriff
			State.ServerHero = newHero

			return
		end

		if hasAssignedPair then
			local assignmentChanged =
				sig ~= State.RoleInactiveSignature

			local alreadyRunning =
				HasLiveRoundEvidence()

			if assignmentChanged or alreadyRunning then
				BeginRoleRound(
					newCache,
					newMurder,
					newSheriff,
					newHero
				)

				SyncPlayerOutOfRound(rawRoles)
				return
			end
		end

		State.RoleInactiveSignature = sig
	end

	if State.RoleRoundActive then
		SyncPlayerOutOfRound(rawRoles)

		local hasSpecialRole =
			newMurder ~= nil
			or newSheriff ~= nil
			or newHero ~= nil

		if hasSpecialRole then
			State.RoleRolesMissingSince = nil

			State.ServerRolesCache = newCache
			State.ServerMurder = newMurder
			State.ServerSheriff = newSheriff
			State.ServerHero = newHero
			State.RoleRoundSignature = sig

		else
			if not State.RoleRolesMissingSince then
				State.RoleRolesMissingSince = os.clock()

			elseif os.clock()
				- State.RoleRolesMissingSince
				>= MM2.Config.ROLE_CLEAR_GRACE
			then
				EndRoleRound()
			end
		end

		return
	end

	State.RoleRolesMissingSince = nil

	State.ServerRolesCache = newCache
	State.ServerMurder = newMurder
	State.ServerSheriff = newSheriff
	State.ServerHero = newHero

	if State.SuppressStaleRoles
		and State.StaleSpecialSignature ~= nil
		and sig ~= State.StaleSpecialSignature
	then
		State.SuppressStaleRoles = false
		State.StaleSpecialSignature = nil
		State.RecentRespawns = {}
		State.PlayerOutOfRound = {}
	end
end

function MM2.RegisterCharacterReset(player)
	local State = MM2.State
	local now = os.clock()

	-- CharacterAdded is only a reset signal now.
	-- It does NOT immediately remove Match ESP.
	State.RecentRespawns[player.Name] = now

	for name,timestamp in pairs(State.RecentRespawns) do
		if now - timestamp > MM2.Config.RESPAWN_TRACK_WINDOW then
			State.RecentRespawns[name] = nil
		end
	end

	local count = 0
	for _ in pairs(State.RecentRespawns) do
		count += 1
	end

	local required =
		math.clamp(
			math.floor(
				#S.Players:GetPlayers()
				* 0.35
			),
			2,
			3
		)

	-- Prevent a mid-round respawn burst from blanking every role.
	-- Global stale suppression is only allowed once the world no
	-- longer contains live-round evidence.
	if count >= required
		and not State.SuppressStaleRoles
		and not HasLiveRoundEvidence()
	then
		State.StaleSpecialSignature =
			MM2.BuildSpecialSignature(
				State.ServerRolesCache
			)

		State.SuppressStaleRoles = true
	end
end

function MM2.WatchPlayer(player)
	MM2.Track(
		player.CharacterAdded:Connect(
			function()
				MM2.RegisterCharacterReset(player)
			end
		)
	)
end

for _,player in ipairs(S.Players:GetPlayers()) do
	MM2.WatchPlayer(player)
end

MM2.Track(
	S.Players.PlayerAdded:Connect(
		MM2.WatchPlayer
	)
)

function MM2.IsCountdownActive()
	for _,obj in ipairs(MM2.PlayerGui:GetDescendants()) do
		if obj:IsA("TextLabel")
			or obj:IsA("TextButton")
		then
			local text =
				string.lower(
					obj.Text
					or ""
				)

			if string.find(
				text,
				"game starts in",
				1,
				true
			)
				and MM2.IsActuallyVisible(obj)
			then
				return true
			end
		end
	end

	return false
end

function MM2.UpdateRoundReset()
	local active = MM2.IsCountdownActive()

	if active
		and not MM2.State.CountdownWasActive
	then
		MM2.State.OriginalSheriff = nil
		MM2.State.OriginalSheriffUserId = nil
		MM2.State.GunDroppedThisRound = false
	end

	MM2.State.CountdownWasActive = active
end

function MM2.GetPlayerRole(player)
	if not player
		or player == MM2.LocalPlayer
	then
		return "None"
	end

	local char = player.Character

	if not char then
		return "None"
	end

	local humanoid =
		char:FindFirstChildOfClass("Humanoid")

	local head =
		char:FindFirstChild("Head")

	if not humanoid
		or humanoid.Health <= 0
		or not head
	then
		return "None"
	end

	if MM2.State.SuppressStaleRoles then
		return "None"
	end

	if MM2.State.PlayerOutOfRound[player.Name] then
		return "None"
	end

	local role =
		MM2.State.ServerRolesCache[player.Name]

	if role == "Murderer"
		or role == "Sheriff"
		or role == "Hero"
		or role == "Innocent"
	then
		return role
	end

	if MM2.State.RoleRoundActive == true then
		return "None"
	end

	return "Innocent"
end

function MM2.GetRoleColor(role)
	if role == "Murderer" then
		return Color3.fromRGB(255,72,72)

	elseif role == "Sheriff" then
		return Color3.fromRGB(79,142,255)

	elseif role == "Hero" then
		return Color3.fromRGB(255,208,84)

	elseif role == "Innocent" then
		return Color3.fromRGB(84,224,128)
	end

	return Color3.fromRGB(255,255,255)
end

function MM2.GetSpectatedPlayer()
	local camera = workspace.CurrentCamera

	if not camera then
		return nil
	end

	local subject = camera.CameraSubject

	if not subject then
		return nil
	end

	if subject:IsA("Humanoid") then
		local p =
			S.Players:GetPlayerFromCharacter(
				subject.Parent
			)

		if p and p ~= MM2.LocalPlayer then
			return p
		end

	elseif subject:IsA("BasePart") then
		local char =
			subject:FindFirstAncestorOfClass(
				"Model"
			)

		local p =
			char
			and S.Players:GetPlayerFromCharacter(
				char
			)

		if p and p ~= MM2.LocalPlayer then
			return p
		end
	end

	return nil
end

function MM2.GetReferencePosition()
	local camera = workspace.CurrentCamera
	local spectated = MM2.GetSpectatedPlayer()

	if spectated then
		local hrp =
			spectated.Character
			and spectated.Character:FindFirstChild(
				"HumanoidRootPart"
			)

		if hrp then
			return hrp.Position
		end
	end

	local char = MM2.LocalPlayer.Character

	local humanoid =
		char
		and char:FindFirstChildOfClass(
			"Humanoid"
		)

	local hrp =
		char
		and char:FindFirstChild(
			"HumanoidRootPart"
		)

	if humanoid
		and humanoid.Health > 0
		and hrp
	then
		return hrp.Position
	end

	return
		camera
		and camera.CFrame.Position
		or nil
end

function MM2.IsPositionWithinESPDistance(position)
	local reference =
		position
		and MM2.GetReferencePosition()

	return
		reference
		and (
			reference - position
		).Magnitude
			< MM2.Config.MAX_ESP_DISTANCE
		or false
end

function MM2.IsWithinESPDistance(player)
	local hrp =
		player.Character
		and player.Character:FindFirstChild(
			"HumanoidRootPart"
		)

	return
		hrp
		and MM2.IsPositionWithinESPDistance(
			hrp.Position
		)
		or false
end

return MM2
