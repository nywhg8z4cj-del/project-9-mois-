--[[
	Types.luau
	==========
	Ici on décrit la « forme » des données du jeu (le typage de Luau).
	Ça ne fait rien pendant le jeu, mais ça aide Studio à repérer les fautes
	de frappe (par exemple écrire data.Coin au lieu de data.Coins).
]]

-- Les données SAUVEGARDÉES d'un joueur (dans le DataStore)
export type PlayerData = {
	Coins: number, -- pièces
	Size: number, -- taille actuelle du monstre
	BestSize: number, -- plus grande taille jamais atteinte (pour le classement)
	Rebirths: number, -- nombre de renaissances
	Upgrades: { [string]: number }, -- niveau de chaque amélioration (ex: Upgrades.BigSpoon = 3)
	OwnedSkins: { [string]: boolean }, -- skins possédés (ex: OwnedSkins.Mint = true)
	EquippedSkin: string, -- skin porté en ce moment
	Daily: {
		LastDay: number, -- numéro du dernier jour où le cadeau a été pris
		Streak: number, -- nombre de jours d'affilée
	},
	PurchaseHistory: { string }, -- derniers achats Robux déjà donnés (anti-doublon)
}

-- Les gamepass du joueur (vérifiés à chaque connexion, PAS sauvegardés)
export type Passes = {
	VIP: boolean,
	TurboFeeder: boolean,
}

-- Ce que le serveur envoie au client pour mettre à jour l'interface
export type ClientState = {
	Coins: number,
	Size: number,
	BestSize: number,
	Rebirths: number,
	Upgrades: { [string]: number },
	OwnedSkins: { [string]: boolean },
	EquippedSkin: string,
	DailyStreak: number,
	Passes: Passes,
	-- Valeurs calculées par le serveur (pour l'affichage)
	IncomePerSecond: number,
	IncomeMultiplier: number,
	SizePerClick: number,
	AutoFeedInterval: number, -- 0 = pas d'auto-nourrisseur
	RebirthRequirement: number,
	RebirthMultiplier: number,
	PlotIndex: number,
}

return {}
