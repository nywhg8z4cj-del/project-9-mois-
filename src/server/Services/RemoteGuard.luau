--[[
	RemoteGuard.luau  —  le « vigile » des demandes des joueurs
	===========================================================
	Quand un client envoie une demande (RemoteEvent), on ne lui fait PAS
	confiance. Ce module vérifie automatiquement :
	  1. que les données du joueur sont chargées ;
	  2. qu'il n'envoie pas trop de demandes trop vite (cooldown anti-spam) ;
	  3. que si le code plante, ça ne casse pas tout le serveur (pcall).

	Exemple :
	  RemoteGuard.connect("BuyFood", 0.2, function(player, foodId)
	      -- ici, on vérifie foodId puis on fait l'achat
	  end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local RemoteGuard = {}

function RemoteGuard.connect(remoteName: string, cooldown: number, handler: (Player, ...any) -> ())
	local remote = Remotes.event(remoteName)
	local lastCall: { [Player]: number } = {}

	remote.OnServerEvent:Connect(function(player: Player, ...)
		-- 1. Données pas encore prêtes ? On ignore.
		if not PlayerDataService.isLoaded(player) then
			return
		end

		-- 2. Trop rapide ? On ignore.
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < cooldown then
			return
		end
		lastCall[player] = now

		-- 3. On lance le code « protégé » par pcall
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`[RemoteGuard] Erreur dans {remoteName} pour {player.Name} : {err}`)
		end
	end)

	-- On oublie les joueurs qui partent (pour ne pas remplir la mémoire)
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

-- Petits outils de vérification des valeurs envoyées par le client
function RemoteGuard.isString(value: any, maxLength: number?): boolean
	return typeof(value) == "string" and #value <= (maxLength or 50)
end

return RemoteGuard
