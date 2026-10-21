--[[
	ShopService.luau  —  boutique de nourriture et améliorations (côté SERVEUR)
	==========================================================================
	Le client envoie seulement « je veux acheter l'aliment X » ou
	« je veux l'amélioration Y ». Ici, le serveur VÉRIFIE tout :
	  - l'aliment / l'amélioration existe vraiment dans Config ?
	  - le joueur a assez de pièces ?
	  - l'amélioration n'est pas déjà au niveau maximum ?
	Puis il fait l'achat et prévient le joueur avec une notification.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonsterService = require(script.Parent.MonsterService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Notifier = require(script.Parent.Notifier)

local ShopService = {}

-- Message « pas assez de pièces » avec ce qu'il manque
local function notEnoughCoins(player: Player, price: number)
	local data = PlayerDataService.getData(player)
	local missing = if data then price - data.Coins else price
	Notifier.send(player, `Pas assez de pièces ! Il t'en manque {Format.number(missing)} 💰`, "error")
end

local function buyFood(player: Player, foodId: any)
	-- 1. La valeur envoyée par le client est-elle valide ?
	if not RemoteGuard.isString(foodId) then
		return
	end
	local food = Formulas.getFood(foodId)
	if not food then
		return -- aliment inconnu : un tricheur ? on ignore
	end

	-- 2. Assez de pièces ? (trySpend retire les pièces seulement si c'est possible)
	if not PlayerDataService.trySpend(player, food.Price) then
		notEnoughCoins(player, food.Price)
		return
	end

	-- 3. Miam !
	MonsterService.addSize(player, food.SizeGain, "food", food.Icon)
	Notifier.send(player, `{food.Icon} Miam, {food.Name} ! +{Format.number(food.SizeGain)} taille`, "success")
end

local function buyUpgrade(player: Player, upgradeId: any)
	if not RemoteGuard.isString(upgradeId) then
		return
	end
	local upgrade = Formulas.getUpgrade(upgradeId)
	local data = PlayerDataService.getData(player)
	if not upgrade or not data then
		return
	end

	local level = Formulas.getUpgradeLevel(data, upgrade.Id)
	local cost = Formulas.upgradeCost(upgrade.Id, level)
	if not cost then
		Notifier.send(player, `{upgrade.Icon} {upgrade.Name} est déjà au niveau maximum !`, "info")
		return
	end
	if not PlayerDataService.trySpend(player, cost) then
		notEnoughCoins(player, cost)
		return
	end

	data.Upgrades[upgrade.Id] = level + 1
	PlayerDataService.markDirty(player)
	Notifier.send(player, `{upgrade.Icon} {upgrade.Name} niveau {level + 1} !`, "success")
end

function ShopService.start()
	-- 0.2 s minimum entre deux achats (anti-spam)
	RemoteGuard.connect("BuyFood", 0.2, buyFood)
	RemoteGuard.connect("BuyUpgrade", 0.2, buyUpgrade)
end

return ShopService
