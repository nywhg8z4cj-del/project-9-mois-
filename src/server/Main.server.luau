--[[
	Main.server.luau  —  le point de départ du SERVEUR
	==================================================
	Ce script se lance tout seul quand le serveur démarre. Il :
	  1. crée les RemoteEvents (Remotes.init) ;
	  2. construit la carte (WorldBuilder) ;
	  3. démarre chaque « service » (un module = une fonctionnalité du jeu).

	⚠️ L'ORDRE compte : par exemple les parcelles doivent être prêtes
	avant de poser les monstres dessus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Services = script.Parent:WaitForChild("Services")

-- 1. Les « téléphones » client ↔ serveur
Remotes.init()

-- 2. La carte
require(Services.WorldBuilder).build()

-- 3. Les services, dans l'ordre
local SERVICE_ORDER = {
	"PlotService", -- les parcelles (avant les monstres !)
	"MonsterService", -- les monstres
	"IncomeService", -- les revenus et l'auto-nourrisseur
	"ShopService", -- la boutique de nourriture et les améliorations
	"SkinService", -- les skins
	"RebirthService", -- la renaissance
	"DailyRewardService", -- le cadeau quotidien
	"CandyRainService", -- la pluie de bonbons
	"LeaderboardService", -- le panneau du top 10
	"MonetizationService", -- les gamepass et achats Robux
	"PlayerDataService", -- en DERNIER : il charge les joueurs et prévient les autres services
}

for _, serviceName in SERVICE_ORDER do
	local service = require(Services:WaitForChild(serviceName))
	service.start()
	print("   ✔ " .. serviceName .. " démarré")
end

print("✅ [Grow a Giant] Serveur prêt !")
