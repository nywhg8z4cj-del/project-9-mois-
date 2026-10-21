--[[
	PlayerDataService.luau  —  les données de chaque joueur (côté SERVEUR)
	=====================================================================
	C'est ici que sont gardées les pièces, la taille, les améliorations...
	de chaque joueur pendant qu'il joue.

	Les autres scripts ne modifient JAMAIS les données « à la main » sans
	passer par ce module (ou en appelant markDirty ensuite), pour que :
	  - le leaderstats (tableau des scores en haut à droite) soit à jour ;
	  - l'interface du joueur reçoive les nouvelles valeurs.

	⚠️ Étape 2 : les données sont seulement gardées en mémoire.
	   (La sauvegarde DataStore arrive à l'étape 3.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData
type Passes = Types.Passes
type ClientState = Types.ClientState

-- Un « profil » = les données d'un joueur + quelques infos utiles
type Profile = {
	Data: PlayerData,
	Passes: Passes,
	Dirty: boolean, -- true = quelque chose a changé, il faut prévenir le client
}

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}
local removingCallbacks: { (Player) -> () } = {}

----------------------------------------------------------------------
-- Données de départ d'un nouveau joueur
----------------------------------------------------------------------
local function newData(): PlayerData
	local upgrades = {}
	for _, upgrade in Config.Upgrades do
		upgrades[upgrade.Id] = 0
	end

	local data: PlayerData = {
		Coins = 0,
		Size = Config.Monster.StartSize,
		BestSize = Config.Monster.StartSize,
		Rebirths = 0,
		Upgrades = upgrades,
		OwnedSkins = { Classic = true },
		EquippedSkin = "Classic",
		Daily = { LastDay = 0, Streak = 0 },
		PurchaseHistory = {},
	}

	-- Pièces bonus pour tester dans Studio (voir Config.Debug)
	if RunService:IsStudio() then
		data.Coins = Config.Debug.StudioStartingCoins
	end
	return data
end

----------------------------------------------------------------------
-- Leaderstats (le tableau des scores en haut à droite de l'écran)
----------------------------------------------------------------------
local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats" -- ⚠️ ce nom exact est obligatoire pour Roblox

	local coins = Instance.new("IntValue")
	coins.Name = "Pièces"
	coins.Parent = leaderstats

	local size = Instance.new("IntValue")
	size.Name = "Taille"
	size.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Renaissances"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local coins = leaderstats:FindFirstChild("Pièces") :: IntValue
	local size = leaderstats:FindFirstChild("Taille") :: IntValue
	local rebirths = leaderstats:FindFirstChild("Renaissances") :: IntValue
	coins.Value = math.floor(data.Coins)
	size.Value = math.floor(data.Size)
	rebirths.Value = data.Rebirths
end

----------------------------------------------------------------------
-- Fonctions utilisées par les autres scripts
----------------------------------------------------------------------

-- Renvoie les données du joueur (ou nil si elles ne sont pas encore chargées)
function PlayerDataService.getData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Renvoie les gamepass du joueur
function PlayerDataService.getPasses(player: Player): Passes
	local profile = profiles[player]
	return if profile then profile.Passes else { VIP = false, TurboFeeder = false }
end

function PlayerDataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Liste des joueurs dont les données sont chargées
function PlayerDataService.getLoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

-- Attend que les données soient chargées (maximum « timeout » secondes)
function PlayerDataService.waitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerDataService.getData(player)
end

-- « Quelque chose a changé » : le client et le leaderstats seront mis à jour
function PlayerDataService.markDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

-- Donne des pièces
function PlayerDataService.addCoins(player: Player, amount: number)
	local data = PlayerDataService.getData(player)
	if data and amount > 0 then
		data.Coins += math.floor(amount)
		PlayerDataService.markDirty(player)
	end
end

-- Essaie de dépenser des pièces. Renvoie true si c'est fait, false si pas assez.
function PlayerDataService.trySpend(player: Player, amount: number): boolean
	local data = PlayerDataService.getData(player)
	if not data or amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	PlayerDataService.markDirty(player)
	return true
end

-- Change un gamepass (VIP, TurboFeeder)
function PlayerDataService.setPass(player: Player, passName: string, owned: boolean)
	local profile = profiles[player]
	if profile then
		(profile.Passes :: any)[passName] = owned
		PlayerDataService.markDirty(player)
	end
end

-- Appelle « callback(player, data) » quand les données d'un joueur sont prêtes.
-- (Les services s'en servent pour créer la parcelle, le monstre...)
function PlayerDataService.onDataLoaded(callback: (Player, PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
	-- Pour les joueurs déjà chargés :
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

-- Appelle « callback(player) » quand un joueur quitte (AVANT la sauvegarde)
function PlayerDataService.onPlayerRemoving(callback: (Player) -> ())
	table.insert(removingCallbacks, callback)
end

-- Construit le « résumé » envoyé au client pour l'interface
function PlayerDataService.buildState(player: Player): ClientState?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data, passes = profile.Data, profile.Passes
	return {
		Coins = data.Coins,
		Size = data.Size,
		BestSize = data.BestSize,
		Rebirths = data.Rebirths,
		Upgrades = table.clone(data.Upgrades),
		OwnedSkins = table.clone(data.OwnedSkins),
		EquippedSkin = data.EquippedSkin,
		DailyStreak = data.Daily.Streak,
		Passes = table.clone(passes),
		IncomePerSecond = Formulas.incomePerSecond(data, passes),
		IncomeMultiplier = Formulas.incomeMultiplier(data, passes),
		SizePerClick = Formulas.sizePerClick(data),
		AutoFeedInterval = Formulas.autoFeedInterval(data, passes) or 0,
		RebirthRequirement = Formulas.rebirthRequirement(data.Rebirths),
		RebirthMultiplier = Formulas.rebirthMultiplier(data.Rebirths),
		PlotIndex = player:GetAttribute("PlotIndex") or 0,
	}
end

----------------------------------------------------------------------
-- Arrivée et départ des joueurs
----------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data = newData()

	profiles[player] = {
		Data = data,
		Passes = { VIP = false, TurboFeeder = false },
		Dirty = true,
	}
	createLeaderstats(player)
	updateLeaderstats(player, data)

	-- On prévient tous les services intéressés
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	if not profiles[player] then
		return
	end
	for _, callback in removingCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn("[PlayerData] Erreur pendant le départ de", player.Name, err)
		end
	end
	profiles[player] = nil
end

function PlayerDataService.start()
	-- Le client demande son état au démarrage de l'interface
	Remotes.func("GetState").OnServerInvoke = function(player: Player)
		PlayerDataService.waitForData(player, 30)
		return PlayerDataService.buildState(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Les joueurs déjà là (ça arrive dans Studio quand le script démarre un peu tard)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- 10 fois par seconde : on envoie les changements aux clients
	local stateEvent = Remotes.event("StateUpdate")
	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, profile in profiles do
				if profile.Dirty then
					profile.Dirty = false
					updateLeaderstats(player, profile.Data)
					stateEvent:FireClient(player, PlayerDataService.buildState(player))
				end
			end
		end
	end)
end

return PlayerDataService
