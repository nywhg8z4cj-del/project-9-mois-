--[[
	MonetizationService.luau  —  les achats en Robux (côté SERVEUR)
	===============================================================
	⚠️ Les IDs sont dans Config.Monetization (et Config.Skins pour les skins Robux).
	   Ce sont des EXEMPLES : remplace-les par les tiens (explications dans Config).

	1. GAMEPASS (achetés une seule fois, pour toujours) :
	   - « VIP » : pièces x2, skin Doré, tag [VIP] dans le chat ;
	   - « Auto-nourrisseur turbo ».
	   On vérifie à chaque connexion avec UserOwnsGamePassAsync, et on écoute
	   PromptGamePassPurchaseFinished pour un achat pendant la partie.

	2. DEVELOPER PRODUCTS (achetables plusieurs fois) :
	   - les packs de pièces ;
	   - les skins Robux.
	   Roblox appelle MarketplaceService.ProcessReceipt pour chaque achat.
	   Règles pour que ce soit FIABLE :
	     - on note l'identifiant de l'achat (PurchaseId) pour ne JAMAIS le donner 2 fois ;
	     - on sauvegarde AVANT de répondre « PurchaseGranted » ;
	     - en cas de problème, on répond « NotProcessedYet » : Roblox réessaiera
	       plus tard (par exemple à la prochaine connexion du joueur).
	   ⚠️ ProcessReceipt ne doit être défini qu'à UN SEUL endroit dans tout le jeu (ici).

	Pas d'objets aléatoires payants : on sait toujours exactement ce qu'on achète.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonsterService = require(script.Parent.MonsterService)
local SkinService = require(script.Parent.SkinService)
local Notifier = require(script.Parent.Notifier)

local MonetizationService = {}

----------------------------------------------------------------------
-- 1. Gamepass
----------------------------------------------------------------------

-- Retrouve le nom du gamepass (« VIP », « TurboFeeder ») à partir de son ID
local function getPassName(passId: number): string?
	for name, pass in Config.Monetization.GamePasses do
		if pass.Id == passId then
			return name
		end
	end
	return nil
end

-- Applique les effets visibles des gamepass (tag VIP, couronne sur le nom du monstre)
local function applyPassEffects(player: Player)
	local passes = PlayerDataService.getPasses(player)
	player:SetAttribute("IsVIP", passes.VIP) -- lu par ChatTags.client.luau pour le tag [VIP]
	MonsterService.refreshNameLabel(player)
end

-- À la connexion : quels gamepass le joueur possède-t-il ?
local function checkPasses(player: Player)
	local allChecked = true
	for name, pass in Config.Monetization.GamePasses do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
		end)
		if ok then
			PlayerDataService.setPass(player, name, owns)
		else
			allChecked = false
			warn(`[Robux] Impossible de vérifier le gamepass {name} pour {player.Name} : {owns}`)
		end
	end
	applyPassEffects(player)
	-- Skin VIP porté sans être VIP ? On remet le Classique.
	-- (seulement si Roblox a bien répondu, pour ne pas enlever le skin d'un vrai VIP par erreur)
	if allChecked then
		SkinService.validateEquipped(player)
	end
end

-- Un gamepass vient d'être acheté pendant la partie
local function onGamePassPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	local name = getPassName(passId)
	if not name or not PlayerDataService.isLoaded(player) then
		return
	end

	PlayerDataService.setPass(player, name, true)
	applyPassEffects(player)

	if name == "VIP" then
		SkinService.equip(player, "Golden") -- on lui met tout de suite son skin doré
		Notifier.send(player, "👑 Merci ! Tu es VIP : pièces x2, skin Doré et tag [VIP] !", "reward")
	elseif name == "TurboFeeder" then
		Notifier.send(player, "🚀 Merci ! L'auto-nourrisseur turbo est activé !", "reward")
	end
	print(`[Robux] {player.Name} a acheté le gamepass {name}`)
end

----------------------------------------------------------------------
-- 2. Developer Products (ProcessReceipt)
----------------------------------------------------------------------

-- Trouve quoi donner pour un ProductId. Renvoie une fonction (ou nil si inconnu).
local function getProductHandler(productId: number): ((Player) -> ())?
	-- Un pack de pièces ?
	local pack = Formulas.getCoinPack(productId)
	if pack then
		return function(player: Player)
			local data = PlayerDataService.getData(player)
			local income = Formulas.incomePerSecond(data, PlayerDataService.getPasses(player))
			local coins = Formulas.coinPackAmount(pack, income)
			PlayerDataService.addCoins(player, coins)
			Notifier.send(player, `{pack.Icon} Merci ! +{Format.number(coins)} pièces !`, "reward")
		end
	end

	-- Un skin Robux ?
	for _, skin in Config.Skins do
		if skin.Unlock.Type == "Robux" and skin.Unlock.ProductId == productId then
			return function(player: Player)
				SkinService.grantSkin(player, skin.Id)
			end
		end
	end

	return nil
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Le joueur n'est plus là : Roblox réessaiera à sa prochaine connexion
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = PlayerDataService.waitForData(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Déjà donné ? (Roblox peut appeler ProcessReceipt plusieurs fois pour le même achat)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if table.find(data.PurchaseHistory, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local handler = getProductHandler(receiptInfo.ProductId)
	if not handler then
		warn(`[Robux] Produit inconnu : {receiptInfo.ProductId} (vérifie les IDs dans Config)`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- On donne l'objet
	local ok, err = pcall(handler, player)
	if not ok then
		warn("[Robux] Erreur en donnant l'achat :", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- On note l'achat (on garde seulement les plus récents)
	table.insert(data.PurchaseHistory, purchaseId)
	while #data.PurchaseHistory > Config.Monetization.PurchaseHistorySize do
		table.remove(data.PurchaseHistory, 1)
	end
	PlayerDataService.markDirty(player)

	-- On sauvegarde AVANT de confirmer à Roblox
	if not PlayerDataService.saveNow(player, "achat Robux") then
		-- L'achat est noté dans PurchaseHistory : il ne sera pas donné deux fois
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print(`[Robux] {player.Name} a acheté le produit {receiptInfo.ProductId}`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	PlayerDataService.onDataLoaded(checkPasses)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchaseFinished)
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
