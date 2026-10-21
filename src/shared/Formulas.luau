--[[
	Formulas.luau
	=============
	Toutes les FORMULES du jeu (calculs) sont ici, au même endroit.
	Elles utilisent les chiffres de Config.

	Le serveur s'en sert pour décider, le client pour afficher les mêmes
	nombres. Comme c'est le même code, les deux sont toujours d'accord.
]]

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type PlayerData = Types.PlayerData
type Passes = Types.Passes

local Formulas = {}

----------------------------------------------------------------------
-- Recherche dans les listes de Config
----------------------------------------------------------------------

-- Cherche un élément par son Id dans une liste (ex: un aliment dans Config.Foods)
local function findById(list: { any }, id: any): any?
	for _, item in list do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Formulas.getFood(id: string)
	return findById(Config.Foods, id)
end

function Formulas.getUpgrade(id: string)
	return findById(Config.Upgrades, id)
end

function Formulas.getSkin(id: string)
	return findById(Config.Skins, id)
end

function Formulas.getCoinPack(productId: number)
	return findById(Config.Monetization.CoinPacks, productId)
end

-- Niveau actuel d'une amélioration (0 si jamais achetée)
function Formulas.getUpgradeLevel(data: PlayerData, upgradeId: string): number
	return data.Upgrades[upgradeId] or 0
end

----------------------------------------------------------------------
-- Clics et taille
----------------------------------------------------------------------

-- Taille gagnée à chaque clic (et à chaque repas de l'auto-nourrisseur)
function Formulas.sizePerClick(data: PlayerData): number
	local spoon = Formulas.getUpgrade("BigSpoon")
	local level = Formulas.getUpgradeLevel(data, "BigSpoon")
	return Config.Monster.BaseSizePerClick + level * spoon.SizePerLevel
end

-- Taille gagnée en ramassant un bonbon
function Formulas.candySizeGain(currentSize: number): number
	local cfg = Config.CandyRain
	return cfg.SizePerCandy + math.floor(currentSize * cfg.SizePercentPerCandy)
end

-- Diamètre du monstre (en studs) selon sa Taille, avec un maximum
function Formulas.visualDiameter(size: number): number
	local cfg = Config.Monster
	local diameter = cfg.BaseDiameter + cfg.GrowthPerSqrtSize * math.sqrt(math.max(size - 1, 0))
	return math.min(diameter, cfg.MaxDiameter)
end

-- « Échelle » du monstre : 1 = taille de départ, 2 = deux fois plus grand...
function Formulas.visualScale(size: number): number
	return Formulas.visualDiameter(size) / Config.Monster.BaseDiameter
end

----------------------------------------------------------------------
-- Revenus
----------------------------------------------------------------------

-- Multiplicateur donné par les renaissances (1 renaissance = x1.5 par défaut)
function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.IncomeBonusPerRebirth
end

-- Tous les multiplicateurs de revenus multipliés ensemble
function Formulas.incomeMultiplier(data: PlayerData, passes: Passes): number
	local multiplier = 1

	-- Estomac élastique : x1.5 par niveau
	local stomach = Formulas.getUpgrade("ElasticStomach")
	local stomachLevel = Formulas.getUpgradeLevel(data, "ElasticStomach")
	multiplier *= stomach.IncomeMultiplierPerLevel ^ stomachLevel

	-- Renaissances
	multiplier *= Formulas.rebirthMultiplier(data.Rebirths)

	-- Gamepass VIP
	if passes.VIP then
		multiplier *= Config.Monetization.VIPCoinMultiplier
	end

	return multiplier
end

-- Pièces gagnées chaque seconde (arrondi vers le bas, minimum 1)
function Formulas.incomePerSecond(data: PlayerData, passes: Passes): number
	local cfg = Config.Income
	local base = cfg.BaseCoinsPerSecond + data.Size * cfg.CoinsPerSize
	return math.max(1, math.floor(base * Formulas.incomeMultiplier(data, passes)))
end

----------------------------------------------------------------------
-- Améliorations
----------------------------------------------------------------------

-- Prix du PROCHAIN niveau d'une amélioration (nil si niveau maximum atteint)
function Formulas.upgradeCost(upgradeId: string, currentLevel: number): number?
	local upgrade = Formulas.getUpgrade(upgradeId)
	if not upgrade or currentLevel >= upgrade.MaxLevel then
		return nil
	end
	return math.floor(upgrade.BaseCost * upgrade.CostMultiplier ^ currentLevel)
end

-- Secondes entre deux repas automatiques (nil = pas d'auto-nourrisseur)
function Formulas.autoFeedInterval(data: PlayerData, passes: Passes): number?
	local feeder = Formulas.getUpgrade("AutoFeeder")
	local level = Formulas.getUpgradeLevel(data, "AutoFeeder")

	-- Le gamepass turbo active l'auto-nourrisseur même sans l'amélioration
	if level == 0 and passes.TurboFeeder then
		level = 1
	end
	if level == 0 then
		return nil
	end

	local interval = feeder.IntervalsByLevel[math.min(level, #feeder.IntervalsByLevel)]
	if passes.TurboFeeder then
		interval /= Config.Monetization.TurboFeederSpeedMultiplier
	end
	return interval
end

----------------------------------------------------------------------
-- Renaissance
----------------------------------------------------------------------

-- Taille nécessaire pour la prochaine renaissance
function Formulas.rebirthRequirement(rebirths: number): number
	local cfg = Config.Rebirth
	return math.floor(cfg.BaseRequiredSize * cfg.RequiredSizeGrowth ^ rebirths)
end

----------------------------------------------------------------------
-- Skins
----------------------------------------------------------------------

-- Est-ce que le joueur possède ce skin ?
function Formulas.ownsSkin(skin, data: PlayerData, passes: Passes): boolean
	local unlockType = skin.Unlock.Type
	if unlockType == "Default" then
		return true
	elseif unlockType == "Rebirth" then
		return data.Rebirths >= skin.Unlock.Rebirths
	elseif unlockType == "VIP" then
		return passes.VIP
	else
		-- "Coins" ou "Robux" : il faut l'avoir acheté
		return data.OwnedSkins[skin.Id] == true
	end
end

----------------------------------------------------------------------
-- Récompense quotidienne et packs de pièces
----------------------------------------------------------------------

function Formulas.dailyReward(streak: number, incomePerSecond: number): number
	local cfg = Config.DailyReward
	local days = math.clamp(streak, 1, cfg.MaxStreakDays)
	local fixed = cfg.BaseCoins + cfg.BonusPerStreakDay * (days - 1)
	local fromIncome = incomePerSecond * cfg.SecondsOfIncomePerStreakDay * days
	return math.floor(fixed + fromIncome)
end

function Formulas.coinPackAmount(pack, incomePerSecond: number): number
	return math.floor(math.max(pack.MinimumCoins, incomePerSecond * pack.MinutesOfIncome * 60))
end

return Formulas
