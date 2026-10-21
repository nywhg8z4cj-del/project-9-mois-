--[[
	PlayerDataService.luau  —  les données de chaque joueur (côté SERVEUR)
	=====================================================================
	C'est ici que sont gardées les pièces, la taille, les améliorations...
	de chaque joueur pendant qu'il joue.

	Les autres scripts ne modifient JAMAIS les données « à la main » sans
	passer par ce module (ou en appelant markDirty ensuite), pour que :
	  - le leaderstats (tableau des scores en haut à droite) soit à jour ;
	  - l'interface du joueur reçoive les nouvelles valeurs.

	💾 SAUVEGARDE (DataStoreService) :
	  - chargement quand le joueur arrive (avec plusieurs essais si Roblox ne répond pas) ;
	  - sauvegarde quand il part, toutes les 2 minutes, et quand le serveur s'arrête (BindToClose).
	  - Si le chargement échoue vraiment, le joueur est renvoyé (Kick) : c'est mieux
	    que de le laisser jouer avec des données vides qui écraseraient sa sauvegarde !

	⚠️ Dans Studio : active « Enable Studio Access to API Services »
	   (Home > Game Settings > Security), sinon le jeu tourne SANS sauvegarde.

	(Pour un très gros jeu, on utiliserait aussi un « verrou de session »,
	par exemple avec le module ProfileStore. Ici on garde ça simple.)
]]

local DataStoreService = game:GetService("DataStoreService")
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
	CanSave: boolean, -- false = mode Studio sans accès aux DataStores
	Leaving: boolean, -- true = le joueur est en train de partir
	FinalSaveStarted: boolean, -- true = la dernière sauvegarde est lancée
	Saving: boolean, -- true = une sauvegarde est en cours
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
-- 💾 DataStore : chargement et sauvegarde
----------------------------------------------------------------------
local dataStore: DataStore? = nil
local activeSaves = 0 -- nombre de sauvegardes en cours (pour BindToClose)

local function getStore(): DataStore?
	if not dataStore then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStore.Name)
		end)
		if ok then
			dataStore = result
		else
			warn("[Sauvegarde] Impossible d'ouvrir le DataStore :", result)
		end
	end
	return dataStore
end

-- La « clé » = le nom de la case où est rangée la sauvegarde d'un joueur
local function keyFor(player: Player): string
	return "Joueur_" .. player.UserId
end

-- Vrai si l'erreur veut dire « les DataStores sont désactivés dans Studio »
local function isStudioAccessError(message: string): boolean
	local lower = string.lower(message)
	return string.find(lower, "studio", 1, true) ~= nil or string.find(lower, "publish", 1, true) ~= nil
end

-- Essaie « action » plusieurs fois (Roblox peut parfois ne pas répondre).
-- Renvoie : réussi (true/false), résultat ou message d'erreur
local function withRetries(description: string, action: () -> any): (boolean, any)
	local cfg = Config.DataStore
	local lastError = nil
	for attempt = 1, cfg.MaxRetries do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		warn(`[Sauvegarde] {description} : essai {attempt}/{cfg.MaxRetries} raté → {lastError}`)
		if isStudioAccessError(lastError) then
			break -- inutile de réessayer, l'accès est désactivé
		end
		task.wait(cfg.RetryDelay * attempt) -- on attend un peu plus à chaque fois
	end
	return false, lastError
end

-- Ajoute dans « saved » les valeurs du modèle « template » qui manquent.
-- Utile quand tu ajoutes une nouvelle amélioration au jeu : les anciens
-- joueurs la reçoivent automatiquement au niveau 0.
local function reconcile(saved: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if saved[key] == nil then
			saved[key] = value
		elseif type(value) == "table" and type(saved[key]) == "table" then
			reconcile(saved[key], value)
		end
	end
end

-- Charge les données d'un joueur. Renvoie : données (ou nil), sauvegarde possible ?
local function loadData(player: Player): (PlayerData?, boolean)
	local store = getStore()
	local ok, result = false, "DataStore indisponible"
	if store then
		ok, result = withRetries("Chargement de " .. player.Name, function()
			return store:GetAsync(keyFor(player))
		end)
	end

	if ok then
		if result == nil then
			print(`[Sauvegarde] Nouveau joueur : {player.Name} 👋`)
			return newData(), true
		end
		reconcile(result, newData())
		print(`[Sauvegarde] Données de {player.Name} chargées ✔`)
		return result, true
	end

	-- Échec : dans Studio, on joue quand même mais sans sauvegarde
	if RunService:IsStudio() then
		warn("⚠️ [Sauvegarde] DataStores inaccessibles : le jeu tourne SANS sauvegarde.")
		warn("   → Active « Enable Studio Access to API Services » dans Home > Game Settings > Security.")
		return newData(), false
	end
	return nil, false
end

-- Sauvegarde les données d'un joueur. Renvoie true si c'est réussi.
local function saveProfile(player: Player, profile: Profile, reason: string): boolean
	if not profile.CanSave then
		return true -- mode Studio sans sauvegarde : rien à faire
	end
	local store = getStore()
	if not store then
		return false
	end

	-- Une seule sauvegarde à la fois par joueur
	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true
	activeSaves += 1

	local ok, err = withRetries(`Sauvegarde de {player.Name} ({reason})`, function()
		-- UpdateAsync est plus sûr que SetAsync : Roblox gère mieux les conflits
		return store:UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)

	activeSaves -= 1
	profile.Saving = false

	if ok then
		if Config.Debug.Verbose then
			print(`[Sauvegarde] {player.Name} sauvegardé ✔ ({reason})`)
		end
	else
		warn(`[Sauvegarde] ÉCHEC pour {player.Name} ({reason}) : {err}`)
	end
	return ok
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
	local profile = profiles[player]
	return profile ~= nil and not profile.Leaving
end

-- Liste des joueurs dont les données sont chargées
function PlayerDataService.getLoadedPlayers(): { Player }
	local list = {}
	for player, profile in profiles do
		if not profile.Leaving then
			table.insert(list, player)
		end
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

-- Sauvegarde tout de suite (utilisé après un achat en Robux). Renvoie true si réussi.
function PlayerDataService.saveNow(player: Player, reason: string?): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return saveProfile(player, profile, reason or "immédiate")
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
	local data, canSave = loadData(player)

	-- Le joueur est parti pendant le chargement : on arrête là
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("Impossible de charger ta sauvegarde 😢 Réessaie dans quelques minutes !")
		return
	end

	profiles[player] = {
		Data = data,
		Passes = { VIP = false, TurboFeeder = false },
		Dirty = true,
		CanSave = canSave,
		Leaving = false,
		FinalSaveStarted = false,
		Saving = false,
	}
	createLeaderstats(player)
	updateLeaderstats(player, data)

	-- On prévient tous les services intéressés
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Leaving = true

	for _, callback in removingCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn("[PlayerData] Erreur pendant le départ de", player.Name, err)
		end
	end

	-- Dernière sauvegarde (sauf si BindToClose l'a déjà lancée)
	if not profile.FinalSaveStarted then
		profile.FinalSaveStarted = true
		saveProfile(player, profile, "départ")
	end
	profiles[player] = nil
end

-- Quand le serveur s'arrête (mise à jour, dernier joueur parti...) : on sauvegarde tout le monde.
-- Roblox nous laisse environ 30 secondes.
local function onServerClose()
	for player, profile in profiles do
		if not profile.FinalSaveStarted then
			profile.FinalSaveStarted = true
			task.spawn(saveProfile, player, profile, "fermeture du serveur")
		end
	end
	-- On attend que toutes les sauvegardes soient finies (25 s maximum)
	local deadline = os.clock() + 25
	task.wait(0.1)
	while activeSaves > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
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

	game:BindToClose(onServerClose)

	-- Sauvegarde automatique toutes les 2 minutes (Config.DataStore.AutoSaveInterval)
	task.spawn(function()
		while true do
			task.wait(Config.DataStore.AutoSaveInterval)
			-- (on fait une copie de la liste, car des joueurs peuvent arriver ou partir pendant la boucle)
			for _, player in PlayerDataService.getLoadedPlayers() do
				local profile = profiles[player]
				if profile and not profile.Leaving then
					task.spawn(saveProfile, player, profile, "automatique")
					task.wait(0.5) -- on étale un peu les sauvegardes
				end
			end
		end
	end)

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
