--[[
	UIController.client.luau  —  le chef de l'interface (côté CLIENT)
	=================================================================
	Ce LocalScript :
	  1. crée le HUD et les notifications ;
	  2. demande au serveur l'état du joueur (pièces, taille...) ;
	  3. écoute les mises à jour du serveur et rafraîchit l'affichage ;
	  4. envoie les DEMANDES du joueur au serveur (par exemple « nourrir »).

	Le ScreenGui a ResetOnSpawn = false (voir init.meta.json) : l'interface
	n'est créée qu'une fois, même si le personnage réapparaît.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local screenGui = script.Parent :: ScreenGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Notifications = require(script.Parent.Notifications)
local HUD = require(script.Parent.HUD)

----------------------------------------------------------------------
-- Création de l'interface
----------------------------------------------------------------------
Notifications.init(screenGui)

local feedRequest = Remotes.event("FeedRequest")
local hud = HUD.create(screenGui, function()
	-- On DEMANDE au serveur de nourrir le monstre. C'est lui qui décide.
	feedRequest:FireServer()
end)

----------------------------------------------------------------------
-- Mises à jour envoyées par le serveur
----------------------------------------------------------------------
local function onStateUpdate(state)
	if not state then
		return
	end
	hud.update(state)
end

Remotes.event("StateUpdate").OnClientEvent:Connect(onStateUpdate)
Remotes.event("Notify").OnClientEvent:Connect(function(message: string, style: string?)
	Notifications.show(message, style)
end)

-- Au démarrage, on demande l'état complet (le serveur attend que les données soient chargées)
onStateUpdate(Remotes.func("GetState"):InvokeServer())

print("✅ [Grow a Giant] Interface prête")
