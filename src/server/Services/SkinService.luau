--[[
	SkinService.luau  —  les apparences du monstre (côté SERVEUR)
	=============================================================
	- EquipSkin : le joueur demande à porter un skin → on vérifie qu'il le possède.
	- BuySkin   : le joueur achète un skin en pièces → on vérifie le prix.
	- grantSkin : donne un skin (utilisé pour les achats Robux, étape 7).

	Changer de skin = on reconstruit le monstre avec les nouvelles couleurs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonsterService = require(script.Parent.MonsterService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Notifier = require(script.Parent.Notifier)

local SkinService = {}

-- Est-ce que le joueur possède ce skin ?
function SkinService.ownsSkin(player: Player, skinId: string): boolean
	local data = PlayerDataService.getData(player)
	local skin = Formulas.getSkin(skinId)
	if not data or not skin then
		return false
	end
	return Formulas.ownsSkin(skin, data, PlayerDataService.getPasses(player))
end

-- Met un skin au monstre (sans vérification : à appeler après avoir vérifié !)
local function equip(player: Player, skinId: string)
	local data = PlayerDataService.getData(player)
	if not data or data.EquippedSkin == skinId then
		return
	end
	data.EquippedSkin = skinId
	PlayerDataService.markDirty(player)
	MonsterService.spawnMonster(player) -- on reconstruit le monstre avec le nouveau skin
end
SkinService.equip = equip

-- Donne un skin au joueur et le lui met (achat Robux par exemple)
function SkinService.grantSkin(player: Player, skinId: string)
	local data = PlayerDataService.getData(player)
	local skin = Formulas.getSkin(skinId)
	if not data or not skin then
		return
	end
	data.OwnedSkins[skinId] = true
	equip(player, skinId)
	Notifier.send(player, `🎨 Nouveau skin : {skin.Name} !`, "reward")
end

-- Si le joueur porte un skin qu'il ne possède plus (ex : skin VIP), on remet le Classique
function SkinService.validateEquipped(player: Player)
	local data = PlayerDataService.getData(player)
	if data and not SkinService.ownsSkin(player, data.EquippedSkin) then
		equip(player, "Classic")
	end
end

local function onEquipRequest(player: Player, skinId: any)
	if not RemoteGuard.isString(skinId) or not Formulas.getSkin(skinId) then
		return
	end
	if not SkinService.ownsSkin(player, skinId) then
		Notifier.send(player, "Tu ne possèdes pas encore ce skin !", "error")
		return
	end
	equip(player, skinId)
	Notifier.send(player, `🎨 Skin équipé : {Formulas.getSkin(skinId).Name}`, "success")
end

local function onBuyRequest(player: Player, skinId: any)
	if not RemoteGuard.isString(skinId) then
		return
	end
	local skin = Formulas.getSkin(skinId)
	local data = PlayerDataService.getData(player)
	-- Seuls les skins « Coins » s'achètent avec des pièces
	if not skin or not data or skin.Unlock.Type ~= "Coins" then
		return
	end
	if data.OwnedSkins[skin.Id] then
		Notifier.send(player, "Tu as déjà ce skin !", "info")
		return
	end
	if not PlayerDataService.trySpend(player, skin.Unlock.Price) then
		local missing = skin.Unlock.Price - data.Coins
		Notifier.send(player, `Pas assez de pièces ! Il t'en manque {Format.number(missing)} 💰`, "error")
		return
	end
	data.OwnedSkins[skin.Id] = true
	equip(player, skin.Id)
	Notifier.send(player, `🎨 Skin acheté : {skin.Name} !`, "success")
end

function SkinService.start()
	RemoteGuard.connect("EquipSkin", 0.5, onEquipRequest)
	RemoteGuard.connect("BuySkin", 0.5, onBuyRequest)
end

return SkinService
