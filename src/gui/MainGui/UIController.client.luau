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

local UIKit = require(script.Parent.UIKit)
local Notifications = require(script.Parent.Notifications)
local HUD = require(script.Parent.HUD)
local Panels = script.Parent:WaitForChild("Panels")

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
-- Les fenêtres (panneaux) et leurs boutons dans le menu de gauche
----------------------------------------------------------------------
local panels = {}
local lastState = nil

-- Ouvre une fenêtre (et ferme les autres). Si elle est déjà ouverte, on la ferme.
local function togglePanel(name: string)
	for panelName, panel in panels do
		if panelName == name and not panel.isOpen() then
			panel.open()
		else
			panel.close()
		end
	end
end

-- Crée une fenêtre à partir de son module, et ajoute son bouton au menu
local function addPanel(name: string, moduleName: string, icon: string, text: string, color: Color3)
	local panel = require(Panels:WaitForChild(moduleName)).create(screenGui)
	panels[name] = panel
	hud.addMenuButton(name, icon, text, color, function()
		togglePanel(name)
	end)
	if lastState then
		panel.update(lastState)
	end
end

addPanel("Shop", "ShopPanel", "🍔", "Boutique", UIKit.Colors.Shop)
addPanel("Upgrades", "UpgradesPanel", "⚡", "Améliorer", UIKit.Colors.Upgrades)
addPanel("Rebirth", "RebirthPanel", "🔄", "Renaître", UIKit.Colors.Rebirth)
addPanel("Skins", "SkinsPanel", "🎨", "Skins", UIKit.Colors.Skins)

----------------------------------------------------------------------
-- Mises à jour envoyées par le serveur
----------------------------------------------------------------------
local function onStateUpdate(state)
	if not state then
		return
	end
	lastState = state
	hud.update(state)
	for _, panel in panels do
		panel.update(state)
	end
	-- Pastille « ! » sur le bouton Renaître quand c'est possible
	hud.setBadge("Rebirth", state.Size >= state.RebirthRequirement)
end

Remotes.event("StateUpdate").OnClientEvent:Connect(onStateUpdate)
Remotes.event("Notify").OnClientEvent:Connect(function(message: string, style: string?)
	Notifications.show(message, style)
end)

-- Au démarrage, on demande l'état complet (le serveur attend que les données soient chargées)
onStateUpdate(Remotes.func("GetState"):InvokeServer())

print("✅ [Grow a Giant] Interface prête")
