--[[
	Config.luau  —  LE fichier de réglages du jeu « Grow a Giant »
	================================================================

	Tous les chiffres du jeu sont ici : prix, gains, multiplicateurs, durées...
	Tu veux que le jeu soit plus facile ? Plus dur ? Change les valeurs ICI,
	tu n'as pas besoin de toucher aux autres scripts.

	Ce module est dans ReplicatedStorage : le serveur ET le client le lisent.
	(Le client s'en sert seulement pour AFFICHER les prix. C'est toujours le
	serveur qui vérifie et qui décide.)

	Petit rappel : après avoir modifié une valeur, relance le test (Play) dans Studio.
]]

local Config = {}

----------------------------------------------------------------------
-- 🛠️ TESTS DANS STUDIO
----------------------------------------------------------------------
Config.Debug = {
	-- Pièces données au départ quand tu testes DANS STUDIO (pratique pour
	-- tester la boutique). Mets 0 pour jouer « normalement ».
	-- N'a AUCUN effet dans le vrai jeu publié.
	StudioStartingCoins = 0,

	-- Affiche plus de messages dans la fenêtre Output.
	Verbose = true,
}

----------------------------------------------------------------------
-- 💾 SAUVEGARDE (DataStore)
----------------------------------------------------------------------
Config.DataStore = {
	-- Nom de la « boîte » où sont rangées les sauvegardes.
	-- ⚠️ Si tu changes ce nom, tous les joueurs repartent de zéro !
	Name = "GrowAGiant_Joueurs_v1",

	-- Nom du classement global (OrderedDataStore).
	LeaderboardName = "GrowAGiant_Classement_v1",

	AutoSaveInterval = 120, -- secondes entre deux sauvegardes automatiques (2 minutes)
	MaxRetries = 5, -- nombre d'essais si Roblox n'arrive pas à charger/sauvegarder
	RetryDelay = 2, -- secondes d'attente entre deux essais
}

----------------------------------------------------------------------
-- 🗺️ LA CARTE
----------------------------------------------------------------------
Config.World = {
	PlotCount = 6, -- nombre de parcelles (= nombre max de joueurs par serveur)
	PlotDistance = 120, -- distance entre le centre de la place et le centre d'une parcelle
	PlotSize = 64, -- largeur d'une parcelle (en studs)
	PlazaRadius = 46, -- rayon de la place centrale
}

----------------------------------------------------------------------
-- 👾 LE MONSTRE
----------------------------------------------------------------------
Config.Monster = {
	StartSize = 1, -- taille de départ (et après une renaissance)

	ClickCooldown = 0.15, -- secondes minimum entre deux clics (anti-spam)
	BaseSizePerClick = 1, -- taille gagnée par clic, sans amélioration
	ClickDistance = 80, -- distance max (studs) pour pouvoir cliquer sur son monstre

	-- Taille VISUELLE (en studs) : diamètre = BaseDiameter + GrowthPerSqrtSize × √(Taille - 1)
	-- La racine carrée (√) fait grandir vite au début, puis plus lentement.
	BaseDiameter = 4,
	GrowthPerSqrtSize = 0.6,
	MaxDiameter = 36, -- le monstre ne dépasse jamais ce diamètre (mais la valeur Taille, elle, continue !)

	GrowTweenTime = 0.35, -- durée de l'animation quand il grandit (secondes)
	BounceScale = 1.12, -- « rebond » quand il mange (1.12 = +12 %)
	BounceTime = 0.1, -- durée d'une moitié de rebond (secondes)
}

----------------------------------------------------------------------
-- 🔊 SONS
----------------------------------------------------------------------
-- Ce sont des sons fournis avec Roblox Studio. Pour en mettre d'autres :
-- Studio > Toolbox > Audio, choisis un son, clic droit > « Copy Asset ID »,
-- puis écris-le ici sous la forme "rbxassetid://123456789".
Config.Sounds = {
	Bite = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.8, Pitch = 0.6 }, -- bouchée
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Pitch = 1.2 }, -- bouton de l'interface
	Success = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1 }, -- achat réussi
	Error = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 0.5 }, -- pas assez de pièces
	Candy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 1.6 }, -- bonbon ramassé
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1 }, -- renaissance
}

----------------------------------------------------------------------
-- 💰 REVENUS AUTOMATIQUES
----------------------------------------------------------------------
-- Pièces par seconde = (BaseCoinsPerSecond + Taille × CoinsPerSize) × multiplicateurs
-- Multiplicateurs : Estomac élastique, renaissances, VIP.
Config.Income = {
	TickInterval = 1, -- toutes les combien de secondes on donne les pièces
	BaseCoinsPerSecond = 1,
	CoinsPerSize = 0.5,
}

----------------------------------------------------------------------
-- 🍔 BOUTIQUE DE NOURRITURE  (du moins cher au plus cher)
----------------------------------------------------------------------
-- Id        : nom « technique » (ne pas mettre d'espace ni d'accent)
-- Name      : nom affiché
-- Icon      : émoji affiché dans la boutique
-- Price     : prix en pièces
-- SizeGain  : taille gagnée en le mangeant
Config.Foods = {
	{ Id = "Apple", Name = "Pomme", Icon = "🍎", Price = 50, SizeGain = 5 },
	{ Id = "Burger", Name = "Burger", Icon = "🍔", Price = 300, SizeGain = 25 },
	{ Id = "Pizza", Name = "Pizza", Icon = "🍕", Price = 1_500, SizeGain = 100 },
	{ Id = "GiantCake", Name = "Gâteau géant", Icon = "🎂", Price = 8_000, SizeGain = 450 },
	{ Id = "SugarMeteor", Name = "Météorite en sucre", Icon = "☄️", Price = 50_000, SizeGain = 2_500 },
	{ Id = "JellyPlanet", Name = "Planète en gelée", Icon = "🪐", Price = 300_000, SizeGain = 12_000 },
}

----------------------------------------------------------------------
-- ⚡ AMÉLIORATIONS PERMANENTES
----------------------------------------------------------------------
-- Prix du prochain niveau = BaseCost × CostMultiplier ^ (niveau actuel)
-- Exemple Grosse cuillère : 100, puis 155, puis 240, puis 372...
Config.Upgrades = {
	{
		Id = "BigSpoon",
		Name = "Grosse cuillère",
		Icon = "🥄",
		Description = "+1 taille par clic à chaque niveau",
		MaxLevel = 30,
		BaseCost = 100,
		CostMultiplier = 1.55,
		SizePerLevel = 1, -- taille en plus par clic, par niveau
	},
	{
		Id = "ElasticStomach",
		Name = "Estomac élastique",
		Icon = "🎈",
		Description = "Revenus x1.5 à chaque niveau",
		MaxLevel = 5,
		BaseCost = 2_000,
		CostMultiplier = 8,
		IncomeMultiplierPerLevel = 1.5, -- niveau 2 = x1.5 × x1.5 = x2.25
	},
	{
		Id = "AutoFeeder",
		Name = "Auto-nourrisseur",
		Icon = "🤖",
		Description = "Nourrit ton monstre tout seul (comme un clic)",
		MaxLevel = 5,
		BaseCost = 1_500,
		CostMultiplier = 4,
		-- Secondes entre deux repas automatiques, pour le niveau 1, 2, 3, 4, 5
		IntervalsByLevel = { 5, 4, 3, 2, 1 },
	},
}

----------------------------------------------------------------------
-- 🔄 RENAISSANCE (Rebirth)
----------------------------------------------------------------------
-- Taille requise = BaseRequiredSize × RequiredSizeGrowth ^ (nombre de renaissances)
-- Exemple : 1 000, puis 3 000, puis 9 000...
Config.Rebirth = {
	BaseRequiredSize = 1_000,
	RequiredSizeGrowth = 3,
	-- Multiplicateur de revenus = 1 + Renaissances × IncomeBonusPerRebirth
	-- Exemple : 1 renaissance = x1.5, 2 renaissances = x2, 3 = x2.5...
	IncomeBonusPerRebirth = 0.5,
	-- true = les améliorations sont remises à zéro à chaque renaissance
	ResetUpgrades = false,
}

----------------------------------------------------------------------
-- 🎨 SKINS (apparences du monstre)
----------------------------------------------------------------------
-- Unlock.Type peut être :
--   "Default" : gratuit, tout le monde l'a
--   "Rebirth" : débloqué automatiquement après X renaissances  (Rebirths = X)
--   "Coins"   : s'achète avec des pièces                          (Price = prix)
--   "Robux"   : s'achète en Robux (Developer Product)              (ProductId = ID, RobuxPrice = prix affiché)
--   "VIP"     : réservé aux joueurs qui ont le gamepass VIP
--
-- Accessory : "Aucun", "Antennes", "Cornes", "Couronne", "Halo", "Chapeau", "Licorne"
-- Material  : la matière du corps (Enum.Material.xxx)
Config.Skins = {
	{
		Id = "Classic",
		Name = "Classique",
		BodyColor = Color3.fromRGB(120, 220, 90),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Aucun",
		AccessoryColor = Color3.fromRGB(255, 255, 255),
		Unlock = { Type = "Default" },
	},
	{
		Id = "Candy",
		Name = "Bonbon rose",
		BodyColor = Color3.fromRGB(255, 130, 200),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Antennes",
		AccessoryColor = Color3.fromRGB(255, 240, 120),
		Unlock = { Type = "Rebirth", Rebirths = 1 },
	},
	{
		Id = "Ocean",
		Name = "Océan",
		BodyColor = Color3.fromRGB(70, 160, 255),
		Material = Enum.Material.Glass,
		Accessory = "Cornes",
		AccessoryColor = Color3.fromRGB(255, 255, 255),
		Unlock = { Type = "Rebirth", Rebirths = 2 },
	},
	{
		Id = "Lava",
		Name = "Lave tiède",
		BodyColor = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.CrackedLava,
		Accessory = "Chapeau",
		AccessoryColor = Color3.fromRGB(60, 40, 40),
		Unlock = { Type = "Rebirth", Rebirths = 3 },
	},
	{
		Id = "Galaxy",
		Name = "Galaxie",
		BodyColor = Color3.fromRGB(90, 50, 170),
		Material = Enum.Material.Neon,
		Accessory = "Halo",
		AccessoryColor = Color3.fromRGB(255, 230, 120),
		Unlock = { Type = "Rebirth", Rebirths = 5 },
	},
	{
		Id = "Mint",
		Name = "Menthe glacée",
		BodyColor = Color3.fromRGB(150, 255, 210),
		Material = Enum.Material.Ice,
		Accessory = "Antennes",
		AccessoryColor = Color3.fromRGB(80, 200, 160),
		Unlock = { Type = "Coins", Price = 25_000 },
	},
	{
		Id = "Pumpkin",
		Name = "Citrouille",
		BodyColor = Color3.fromRGB(255, 150, 30),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Chapeau",
		AccessoryColor = Color3.fromRGB(40, 120, 40),
		Unlock = { Type = "Coins", Price = 250_000 },
	},
	{
		Id = "Unicorn",
		Name = "Licorne",
		BodyColor = Color3.fromRGB(250, 245, 255),
		Material = Enum.Material.SmoothPlastic,
		Accessory = "Licorne",
		AccessoryColor = Color3.fromRGB(255, 200, 90),
		-- ⚠️ ProductId d'EXEMPLE : remplace-le (voir la section Monétisation plus bas)
		Unlock = { Type = "Robux", ProductId = 1111111104, RobuxPrice = 49 },
	},
	{
		Id = "Robot",
		Name = "Robot rigolo",
		BodyColor = Color3.fromRGB(170, 180, 195),
		Material = Enum.Material.DiamondPlate,
		Accessory = "Antennes",
		AccessoryColor = Color3.fromRGB(255, 80, 80),
		-- ⚠️ ProductId d'EXEMPLE : remplace-le
		Unlock = { Type = "Robux", ProductId = 1111111105, RobuxPrice = 49 },
	},
	{
		Id = "Golden",
		Name = "Doré (VIP)",
		BodyColor = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Accessory = "Couronne",
		AccessoryColor = Color3.fromRGB(255, 240, 150),
		Unlock = { Type = "VIP" },
	},
}

----------------------------------------------------------------------
-- 🎁 RÉCOMPENSE QUOTIDIENNE
----------------------------------------------------------------------
-- Pièces = (BaseCoins + BonusPerStreakDay × (série - 1)) + revenus/s × SecondsOfIncomePerStreakDay × série
-- La série (« streak ») augmente si tu te connectes des jours d'affilée,
-- et retombe à 1 si tu rates un jour.
Config.DailyReward = {
	BaseCoins = 200,
	BonusPerStreakDay = 100,
	SecondsOfIncomePerStreakDay = 30, -- pour que le cadeau reste intéressant plus tard dans le jeu
	MaxStreakDays = 7, -- après 7 jours, le bonus n'augmente plus
}

----------------------------------------------------------------------
-- 🍬 ÉVÉNEMENT « PLUIE DE BONBONS »
----------------------------------------------------------------------
Config.CandyRain = {
	Interval = 600, -- secondes entre deux pluies (10 minutes)
	FirstEventDelay = 600, -- délai avant la première pluie dans le vrai jeu
	StudioFirstEventDelay = 30, -- dans Studio, la 1re pluie arrive vite pour tester
	AnnounceBefore = 10, -- l'annonce s'affiche X secondes avant
	Duration = 30, -- durée de la pluie (secondes)
	SpawnInterval = 0.15, -- un bonbon toutes les X secondes
	SpawnHeight = 80, -- hauteur d'où tombent les bonbons
	CandyLifetime = 12, -- un bonbon disparaît au bout de X secondes
	-- Taille gagnée par bonbon = SizePerCandy + Taille actuelle × SizePercentPerCandy
	SizePerCandy = 5,
	SizePercentPerCandy = 0.01, -- 0.01 = 1 % de la taille actuelle
	Colors = {
		Color3.fromRGB(255, 90, 160),
		Color3.fromRGB(255, 220, 60),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(140, 255, 120),
		Color3.fromRGB(200, 120, 255),
	},
}

----------------------------------------------------------------------
-- 🏆 CLASSEMENT
----------------------------------------------------------------------
Config.Leaderboard = {
	UpdateInterval = 60, -- secondes entre deux mises à jour du panneau
	Count = 10, -- nombre de joueurs affichés (top 10)
}

----------------------------------------------------------------------
-- 💎 MONÉTISATION (Robux)
----------------------------------------------------------------------
--[[
	⚠️ LES IDs CI-DESSOUS SONT DES EXEMPLES : ils ne marcheront pas tant que tu ne
	les as pas remplacés par les tiens !

	Comment trouver tes vrais IDs :
	1. Publie d'abord ton jeu (File > Publish to Roblox).
	2. Va sur https://create.roblox.com/dashboard/creations et clique sur ton jeu.
	3. Menu de gauche > « Monetization » (Monétisation) :
	   - « Passes »              → crée « VIP » et « Auto-nourrisseur turbo ».
	   - « Developer Products »  → crée les packs de pièces et les skins Robux.
	4. Sur chaque objet créé, clique sur les « ... » > « Copy Asset ID »
	   (ou regarde le nombre dans l'adresse de la page).
	5. Colle ce nombre à la place de l'ID d'exemple ci-dessous (et pour les
	   skins Robux, dans Config.Skins plus haut).

	Les prix en Robux se règlent sur le site, PAS ici. Le champ RobuxPrice ne
	sert qu'à l'affichage si Roblox ne répond pas.
]]
Config.Monetization = {
	GamePasses = {
		VIP = {
			Id = 1111111101, -- ⚠️ ID d'EXEMPLE
			Name = "VIP",
			Icon = "👑",
			Description = "Pièces x2, skin Doré exclusif et tag [VIP] dans le chat !",
			RobuxPrice = 199,
		},
		TurboFeeder = {
			Id = 1111111102, -- ⚠️ ID d'EXEMPLE
			Name = "Auto-nourrisseur turbo",
			Icon = "🚀",
			Description = "L'auto-nourrisseur va 2x plus vite (et s'active même sans l'amélioration).",
			RobuxPrice = 99,
		},
	},

	VIPCoinMultiplier = 2, -- VIP = revenus x2
	TurboFeederSpeedMultiplier = 2, -- turbo = auto-nourrisseur 2x plus rapide

	-- Packs de pièces (Developer Products : on peut les acheter plusieurs fois).
	-- Pièces reçues = le plus grand entre MinimumCoins et (revenus/s × MinutesOfIncome × 60)
	-- Comme ça, un pack reste utile même quand ton monstre est énorme.
	CoinPacks = {
		{ Id = 1111111201, Name = "Petit sac", Icon = "💰", MinutesOfIncome = 10, MinimumCoins = 2_000, RobuxPrice = 25 },
		{ Id = 1111111202, Name = "Gros coffre", Icon = "🧰", MinutesOfIncome = 60, MinimumCoins = 15_000, RobuxPrice = 99 },
		{ Id = 1111111203, Name = "Montagne d'or", Icon = "🏔️", MinutesOfIncome = 300, MinimumCoins = 100_000, RobuxPrice = 349 },
	},

	-- Nombre d'achats Robux mémorisés par joueur (pour ne jamais donner deux fois le même achat)
	PurchaseHistorySize = 50,
}

return Config
