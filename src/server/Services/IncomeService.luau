--[[
	IncomeService.luau  —  les revenus automatiques et l'auto-nourrisseur
	=====================================================================
	Deux boucles tournent en permanence :
	  1. Toutes les secondes : chaque joueur gagne des pièces selon la taille
	     de son monstre (formule dans Formulas.incomePerSecond / Config.Income).
	  2. L'auto-nourrisseur : si le joueur l'a acheté (ou a le gamepass turbo),
	     son monstre mange tout seul toutes les X secondes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonsterService = require(script.Parent.MonsterService)

local IncomeService = {}

local nextAutoFeed: { [Player]: number } = {}

local function giveIncome()
	local interval = Config.Income.TickInterval
	for _, player in PlayerDataService.getLoadedPlayers() do
		local data = PlayerDataService.getData(player)
		if data then
			local passes = PlayerDataService.getPasses(player)
			PlayerDataService.addCoins(player, Formulas.incomePerSecond(data, passes) * interval)
		end
	end
end

local function runAutoFeeders()
	local now = os.clock()
	for _, player in PlayerDataService.getLoadedPlayers() do
		local data = PlayerDataService.getData(player)
		if data then
			local interval = Formulas.autoFeedInterval(data, PlayerDataService.getPasses(player))
			if not interval then
				nextAutoFeed[player] = nil -- pas d'auto-nourrisseur
			elseif not nextAutoFeed[player] then
				nextAutoFeed[player] = now + interval -- on vient de l'acheter : on lance le chrono
			elseif now >= nextAutoFeed[player] then
				MonsterService.addSize(player, Formulas.sizePerClick(data), "auto")
				nextAutoFeed[player] = now + interval
			end
		end
	end
end

function IncomeService.start()
	-- Boucle 1 : les revenus
	task.spawn(function()
		while true do
			task.wait(Config.Income.TickInterval)
			giveIncome()
		end
	end)

	-- Boucle 2 : l'auto-nourrisseur (on vérifie 10 fois par seconde)
	task.spawn(function()
		while true do
			task.wait(0.1)
			runAutoFeeders()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextAutoFeed[player] = nil
	end)
end

return IncomeService
