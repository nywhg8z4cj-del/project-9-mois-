--[[
	RebirthService.luau  —  la renaissance (Rebirth) du monstre
	===========================================================
	Quand le monstre est assez grand (Formulas.rebirthRequirement), le joueur
	peut le faire renaître :
	  - taille remise à Config.Monster.StartSize (1) et pièces à 0 ;
	  - +1 renaissance = multiplicateur de revenus permanent plus grand ;
	  - un nouveau skin peut être débloqué (Config.Skins avec Unlock.Type = "Rebirth"),
	    et il est mis automatiquement au monstre.
	Les améliorations sont gardées (sauf si Config.Rebirth.ResetUpgrades = true).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonsterService = require(script.Parent.MonsterService)
local SkinService = require(script.Parent.SkinService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Notifier = require(script.Parent.Notifier)

local RebirthService = {}

local function onRebirthRequest(player: Player)
	local data = PlayerDataService.getData(player)
	if not data then
		return
	end

	-- Vérification : le monstre est-il assez grand ?
	local required = Formulas.rebirthRequirement(data.Rebirths)
	if data.Size < required then
		Notifier.send(player, `Il faut une taille de {Format.number(required)} pour renaître (encore {Format.number(required - data.Size)}) !`, "error")
		return
	end

	-- La renaissance !
	data.Rebirths += 1
	data.Coins = 0
	if Config.Rebirth.ResetUpgrades then
		for upgradeId in data.Upgrades do
			data.Upgrades[upgradeId] = 0
		end
	end
	MonsterService.setSize(player, Config.Monster.StartSize)

	-- Un skin se débloque-t-il avec ce nombre de renaissances ?
	local newSkin = nil
	for _, skin in Config.Skins do
		if skin.Unlock.Type == "Rebirth" and skin.Unlock.Rebirths == data.Rebirths then
			newSkin = skin
			data.OwnedSkins[skin.Id] = true
		end
	end
	if newSkin then
		SkinService.equip(player, newSkin.Id) -- nouveau look automatiquement !
		-- Petit délai pour que le nouveau monstre soit arrivé chez les clients
		task.delay(0.4, function()
			local model = MonsterService.getMonster(player)
			if model then
				Remotes.event("FeedEffect"):FireAllClients(model, 0, "reset")
			end
		end)
	end
	PlayerDataService.markDirty(player)

	local multiplier = Format.multiplier(Formulas.rebirthMultiplier(data.Rebirths))
	Notifier.send(player, `🔄 RENAISSANCE n°{data.Rebirths} ! Revenus des renaissances : {multiplier}`, "rebirth")
	if newSkin then
		Notifier.send(player, `🎨 Nouveau skin débloqué : {newSkin.Name} !`, "reward")
	end
	print(`[Renaissance] {player.Name} → renaissance n°{data.Rebirths}`)
end

function RebirthService.start()
	-- 1 seconde minimum entre deux demandes
	RemoteGuard.connect("RequestRebirth", 1, onRebirthRequest)
end

return RebirthService
