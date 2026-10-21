--[[
	Main.server.luau  —  le point de départ du SERVEUR
	==================================================
	Ce script se lance tout seul quand le serveur démarre.
	Pour l'instant (étape 1), il vérifie juste que tout est bien branché.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

-- On crée tous les RemoteEvents / RemoteFunctions
Remotes.init()

print("✅ [Grow a Giant] Serveur démarré !")
print("   Nombre d'aliments dans la boutique :", #Config.Foods)
print("   Nombre de skins :", #Config.Skins)
