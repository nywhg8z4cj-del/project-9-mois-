--[[
	LeaderboardService.luau  —  le panneau « Top 10 » sur la place centrale 🏆
	=========================================================================
	Classement GLOBAL (tous les serveurs du jeu) du record de taille (BestSize),
	grâce à un OrderedDataStore : un DataStore spécial qui sait trier les valeurs.

	Toutes les 60 secondes (Config.Leaderboard.UpdateInterval) :
	  1. on envoie le record de chaque joueur du serveur ;
	  2. on récupère le top 10 trié du plus grand au plus petit ;
	  3. on affiche les noms et les tailles sur le panneau (SurfaceGui).

	Si les DataStores ne marchent pas (Studio sans accès aux API), le panneau
	affiche quand même le classement des joueurs de CE serveur.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local LeaderboardService = {}

type Entry = { UserId: number, Value: number }
type Row = { Rank: TextLabel, Name: TextLabel, Value: TextLabel }

local rows: { Row } = {}
local subtitleLabel: TextLabel
local nameCache: { [number]: string } = {}

local MEDALS = { "🥇", "🥈", "🥉" }
local FONT = Enum.Font.FredokaOne

----------------------------------------------------------------------
-- Construction du panneau
----------------------------------------------------------------------
local function makeLabel(parent: Instance, properties: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	for name, value in properties do
		(label :: any)[name] = value
	end
	label.Parent = parent
	return label
end

local function buildBoard()
	local cfg = Config.World
	-- Entre la parcelle 1 et la parcelle 2, au bord de la place, tourné vers le centre
	local angle = math.rad(180 / cfg.PlotCount)
	local base = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (cfg.PlazaRadius - 8)

	local model = Instance.new("Model")
	model.Name = "PanneauClassement"

	local facing = CFrame.lookAt(base, Vector3.new(0, 0, 0))
	for _, side in { -1, 1 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(1.2, 8, 1.2)
		post.CFrame = facing * CFrame.new(7 * side, 4.5, 0.3)
		post.Color = Color3.fromRGB(140, 90, 60)
		post.Material = Enum.Material.Wood
		post.Parent = model
	end

	local board = Instance.new("Part")
	board.Name = "Panneau"
	board.Anchored = true
	board.Size = Vector3.new(18, 22, 1)
	board.CFrame = facing * CFrame.new(0, 8 + 11, 0)
	board.Color = Color3.fromRGB(110, 60, 160)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = model

	-- Le SurfaceGui : une interface collée sur la face avant de la Part
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front -- la face qui regarde le centre de la place
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = board

	makeLabel(surface, {
		Size = UDim2.new(1, -40, 0.1, 0),
		Position = UDim2.new(0, 20, 0.02, 0),
		Text = "🏆 PLUS GROS MONSTRES 🏆",
		TextColor3 = Color3.fromRGB(255, 220, 80),
	})
	subtitleLabel = makeLabel(surface, {
		Size = UDim2.new(1, -40, 0.05, 0),
		Position = UDim2.new(0, 20, 0.12, 0),
		Text = "Record de taille — chargement...",
		TextColor3 = Color3.fromRGB(220, 200, 255),
	})

	local count = Config.Leaderboard.Count
	local rowHeight = 0.8 / count
	for i = 1, count do
		local y = 0.18 + (i - 1) * rowHeight
		local background = Instance.new("Frame")
		background.Position = UDim2.new(0, 20, y, 0)
		background.Size = UDim2.new(1, -40, rowHeight * 0.9, 0)
		background.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(130, 80, 185) else Color3.fromRGB(150, 100, 205)
		background.Parent = surface
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = background

		table.insert(rows, {
			Rank = makeLabel(background, {
				Size = UDim2.fromScale(0.14, 0.8),
				Position = UDim2.fromScale(0.02, 0.1),
				Text = MEDALS[i] or ("#" .. i),
			}),
			Name = makeLabel(background, {
				Size = UDim2.fromScale(0.56, 0.7),
				Position = UDim2.fromScale(0.17, 0.15),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "---",
			}),
			Value = makeLabel(background, {
				Size = UDim2.fromScale(0.25, 0.7),
				Position = UDim2.fromScale(0.73, 0.15),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(255, 230, 90),
				Text = "",
			}),
		})
	end

	model.Parent = WorldBuilder.Map or workspace
end

----------------------------------------------------------------------
-- Données du classement
----------------------------------------------------------------------
local orderedStore: OrderedDataStore? = nil

local function getStore(): OrderedDataStore?
	if not orderedStore then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.DataStore.LeaderboardName)
		end)
		if ok then
			orderedStore = result
		end
	end
	return orderedStore
end

-- Trouve le pseudo d'un joueur à partir de son numéro (UserId), avec une mémoire
local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Joueur " .. userId
end

-- Classement des joueurs présents sur CE serveur (solution de secours)
local function getLocalTop(): { Entry }
	local entries = {}
	for _, player in PlayerDataService.getLoadedPlayers() do
		local data = PlayerDataService.getData(player)
		if data then
			table.insert(entries, { UserId = player.UserId, Value = data.BestSize })
		end
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	return entries
end

-- Envoie les records puis récupère le top global. Renvoie nil en cas d'échec.
local function getGlobalTop(): { Entry }?
	local store = getStore()
	if not store then
		return nil
	end

	-- 1. Envoi des records des joueurs du serveur
	for _, player in PlayerDataService.getLoadedPlayers() do
		local data = PlayerDataService.getData(player)
		if data then
			pcall(function()
				-- L'OrderedDataStore n'accepte que des nombres entiers
				store:SetAsync(tostring(player.UserId), math.floor(data.BestSize))
			end)
		end
	end

	-- 2. Lecture du top (false = du plus grand au plus petit)
	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, Config.Leaderboard.Count)
		return pages:GetCurrentPage()
	end)
	if not ok then
		return nil
	end

	local entries = {}
	for _, item in result do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { UserId = userId, Value = item.value })
		end
	end
	return entries
end

local function refresh()
	local entries = getGlobalTop()
	if entries then
		subtitleLabel.Text = "Record de taille — tous les serveurs"
	else
		entries = getLocalTop()
		subtitleLabel.Text = "Record de taille — ce serveur"
	end

	for i, row in rows do
		local entry = entries[i]
		if entry then
			row.Name.Text = getName(entry.UserId)
			row.Value.Text = "📏 " .. Format.number(entry.Value)
		else
			row.Name.Text = "---"
			row.Value.Text = ""
		end
	end
end

function LeaderboardService.start()
	buildBoard()
	task.spawn(function()
		task.wait(5) -- on laisse le temps aux premiers joueurs d'être chargés
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[Classement] Erreur :", err)
			end
			task.wait(Config.Leaderboard.UpdateInterval)
		end
	end)
end

return LeaderboardService
