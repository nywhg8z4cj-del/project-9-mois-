--[[
	Hello.client.luau  —  script de test de l'étape 1 (sera remplacé plus tard)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

print("✅ [Grow a Giant] Client démarré ! Premier aliment de la boutique :", Config.Foods[1].Name)
