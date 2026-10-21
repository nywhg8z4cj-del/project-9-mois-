--[[
	Notifier.luau  —  envoie des notifications à l'écran des joueurs
	================================================================
	Exemple : Notifier.send(player, "Achat réussi !", "success")

	Styles possibles (couleurs différentes côté client) :
	  "info", "success", "error", "event", "reward", "candy", "rebirth"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local Notifier = {}

-- Notification pour UN joueur
function Notifier.send(player: Player, message: string, style: string?)
	Remotes.event("Notify"):FireClient(player, message, style or "info")
end

-- Notification pour TOUS les joueurs du serveur
function Notifier.sendAll(message: string, style: string?)
	Remotes.event("Notify"):FireAllClients(message, style or "info")
end

return Notifier
