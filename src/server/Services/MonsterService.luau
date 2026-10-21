--[[
	MonsterService.luau  —  le monstre de chaque joueur (côté SERVEUR)
	==================================================================
	- Crée le monstre du joueur sur sa parcelle.
	- Gère le clic sur le monstre (ou le bouton « Nourrir ») avec un cooldown.
	- Fait grandir le monstre : c'est la SEULE fonction qui change la Taille
	  (addSize), comme ça tout reste cohérent.
	- Prévient tous les clients pour les effets (son, particules, rebond).

	Le serveur change seulement l'attribut « Size » du modèle.
	Le client (MonsterAnimator) voit ce changement et anime l'agrandissement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local MonsterBuilder = require(script.Parent.MonsterBuilder)
local RemoteGuard = require(script.Parent.RemoteGuard)

local MonsterService = {}

local monsters: { [Player]: Model } = {}
local lastFeedTime: { [Player]: number } = {}
local monstersFolder: Folder

-- Renvoie le modèle du monstre d'un joueur
function MonsterService.getMonster(player: Player): Model?
	return monsters[player]
end

-- Met à jour le texte « 📏 Taille » au-dessus du monstre
local function updateSizeLabel(model: Model, size: number)
	local body = model:FindFirstChild("Corps")
	local billboard = body and body:FindFirstChild("InfoMonstre")
	local label = billboard and billboard:FindFirstChild("Taille")
	if label then
		(label :: TextLabel).Text = "📏 " .. Format.number(size)
	end
end

-- Met à jour le nom au-dessus du monstre (avec une couronne 👑 pour les VIP)
function MonsterService.refreshNameLabel(player: Player)
	local model = monsters[player]
	local body = model and model:FindFirstChild("Corps")
	local billboard = body and body:FindFirstChild("InfoMonstre")
	local label = billboard and billboard:FindFirstChild("Nom") :: TextLabel?
	if label then
		local crown = if PlayerDataService.getPasses(player).VIP then "👑 " else ""
		label.Text = crown .. "Monstre de " .. player.DisplayName
	end
end

-- Crée (ou recrée) le monstre du joueur, avec son skin actuel
function MonsterService.spawnMonster(player: Player)
	local data = PlayerDataService.getData(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end

	-- S'il avait déjà un monstre (changement de skin), on l'enlève
	if monsters[player] then
		monsters[player]:Destroy()
	end

	local skin = Formulas.getSkin(data.EquippedSkin) or Formulas.getSkin("Classic")
	local model = MonsterBuilder.build(skin, plot.MonsterPivot, player)
	model:SetAttribute("Size", data.Size)
	updateSizeLabel(model, data.Size)

	-- Quand on clique sur le monstre
	local clickDetector = model:FindFirstChildOfClass("ClickDetector")
	if clickDetector then
		clickDetector.MouseClick:Connect(function(clicker: Player)
			-- On ne peut nourrir QUE son propre monstre
			if clicker == player then
				MonsterService.tryClickFeed(player)
			end
		end)
	end

	model.Parent = monstersFolder
	monsters[player] = model
	MonsterService.refreshNameLabel(player)
end

-- Fait grandir le monstre de « amount ».
-- kind = "click", "auto", "food", "candy" (pour choisir les effets côté client)
-- icon = un émoji à afficher (par exemple celui de l'aliment mangé)
function MonsterService.addSize(player: Player, amount: number, kind: string, icon: string?)
	local data = PlayerDataService.getData(player)
	if not data or amount <= 0 then
		return
	end

	data.Size += math.floor(amount)
	data.BestSize = math.max(data.BestSize, data.Size)
	PlayerDataService.markDirty(player)

	local model = monsters[player]
	if model then
		model:SetAttribute("Size", data.Size) -- le client va animer l'agrandissement
		updateSizeLabel(model, data.Size)
		Remotes.event("FeedEffect"):FireAllClients(model, math.floor(amount), kind, icon)
	end
end

-- Remet le monstre à une taille précise (utilisé par la renaissance)
function MonsterService.setSize(player: Player, newSize: number)
	local data = PlayerDataService.getData(player)
	if not data then
		return
	end
	data.Size = newSize
	PlayerDataService.markDirty(player)

	local model = monsters[player]
	if model then
		model:SetAttribute("Size", newSize)
		updateSizeLabel(model, newSize)
		Remotes.event("FeedEffect"):FireAllClients(model, 0, "reset")
	end
end

-- Un clic (sur le monstre ou sur le bouton Nourrir) : on vérifie le cooldown
function MonsterService.tryClickFeed(player: Player)
	local data = PlayerDataService.getData(player)
	if not data or not monsters[player] then
		return
	end

	local now = os.clock()
	if lastFeedTime[player] and now - lastFeedTime[player] < Config.Monster.ClickCooldown then
		return -- trop rapide : on ignore (anti-spam / anti-autoclicker)
	end
	lastFeedTime[player] = now

	MonsterService.addSize(player, Formulas.sizePerClick(data), "click")
end

local function removeMonster(player: Player)
	if monsters[player] then
		monsters[player]:Destroy()
		monsters[player] = nil
	end
	lastFeedTime[player] = nil
end

function MonsterService.start()
	monstersFolder = Instance.new("Folder")
	monstersFolder.Name = "Monstres"
	monstersFolder.Parent = workspace

	-- ⚠️ PlotService.start() doit être appelé AVANT, pour que la parcelle existe
	PlayerDataService.onDataLoaded(function(player)
		MonsterService.spawnMonster(player)
	end)
	PlayerDataService.onPlayerRemoving(removeMonster)
	Players.PlayerRemoving:Connect(removeMonster)

	-- Le bouton « Nourrir » de l'interface (le cooldown est vérifié dans tryClickFeed)
	RemoteGuard.connect("FeedRequest", 0, function(player)
		MonsterService.tryClickFeed(player)
	end)
end

return MonsterService
