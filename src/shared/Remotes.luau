--[[
	Remotes.luau
	============
	Les RemoteEvents / RemoteFunctions sont les « téléphones » entre le client
	(l'ordinateur du joueur) et le serveur (Roblox).

	- Le CLIENT envoie des DEMANDES : « je voudrais acheter une pizza ».
	- Le SERVEUR vérifie (assez de pièces ? valeur valide ?) puis décide.
	- Le SERVEUR envoie des INFOS : « tu as maintenant 120 pièces ».

	Ce module crée tous les remotes (côté serveur) dans un dossier
	ReplicatedStorage.Remotes, et permet au client de les retrouver.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- Liste de TOUS les RemoteEvents du jeu
local EVENT_NAMES = {
	-- Client → Serveur (demandes)
	"FeedRequest", -- « nourris mon monstre » (bouton Nourrir)
	"BuyFood", -- (idAliment)
	"BuyUpgrade", -- (idAmélioration)
	"RequestRebirth", -- « je veux renaître »
	"BuySkin", -- (idSkin) achat en pièces
	"EquipSkin", -- (idSkin)

	-- Serveur → Client (informations)
	"StateUpdate", -- (état complet du joueur)
	"Notify", -- (texte, style) : petite notification à l'écran
	"FeedEffect", -- (monstre, quantité, type) : effets quand un monstre mange
	"CandyRainEvent", -- (phase, secondes) : annonce / début / fin de la pluie de bonbons
}

-- Liste de TOUTES les RemoteFunctions (le client pose une question et attend la réponse)
local FUNCTION_NAMES = {
	"GetState", -- le client demande son état au démarrage
}

local FOLDER_NAME = "Remotes"

-- À appeler UNE fois par le serveur au démarrage : crée tous les remotes.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() doit être appelé par le serveur")

	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	for _, name in FUNCTION_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(folder, "Remotes.init() n'a pas encore été appelé")
		return folder
	end
	-- Côté client : on attend que le serveur ait créé le dossier
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

-- Récupère un RemoteEvent par son nom. Exemple : Remotes.event("BuyFood")
function Remotes.event(name: string): RemoteEvent
	assert(table.find(EVENT_NAMES, name), "RemoteEvent inconnu : " .. name)
	local remote = getFolder():WaitForChild(name)
	return remote :: RemoteEvent
end

-- Récupère une RemoteFunction par son nom. Exemple : Remotes.func("GetState")
function Remotes.func(name: string): RemoteFunction
	assert(table.find(FUNCTION_NAMES, name), "RemoteFunction inconnue : " .. name)
	local remote = getFolder():WaitForChild(name)
	return remote :: RemoteFunction
end

return Remotes
