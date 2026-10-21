--[[
	PlotService.luau  —  donne une parcelle à chaque joueur
	=======================================================
	- Quand un joueur arrive (et que ses données sont chargées), il reçoit
	  la première parcelle libre.
	- Son nom s'affiche au-dessus du panneau de la parcelle.
	- À chaque apparition, son personnage est téléporté sur sa parcelle.
	- Quand il part, la parcelle redevient libre.

	⚠️ Il y a 6 parcelles : règle le nombre max de joueurs du serveur à 6
	(voir la liste de publication dans le README).
]]

local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Notifier = require(script.Parent.Notifier)

type PlotInfo = WorldBuilder.PlotInfo

local PlotService = {}

local ownerByIndex: { [number]: Player } = {} -- parcelle n° → joueur
local plotByPlayer: { [Player]: PlotInfo } = {} -- joueur → parcelle
local characterConnections: { [Player]: RBXScriptConnection } = {}

-- Renvoie la parcelle d'un joueur (ou nil s'il n'en a pas)
function PlotService.getPlot(player: Player): PlotInfo?
	return plotByPlayer[player]
end

-- Téléporte le personnage du joueur sur sa parcelle
function PlotService.teleportHome(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if not plot or not character then
		return
	end
	-- On attend que le personnage soit complètement prêt
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if rootPart then
		task.wait(0.1)
		character:PivotTo(plot.SpawnCFrame)
	end
end

local function assignPlot(player: Player)
	if plotByPlayer[player] then
		return -- il a déjà une parcelle
	end

	-- On cherche la première parcelle libre
	for _, plot in WorldBuilder.Plots do
		if not ownerByIndex[plot.Index] then
			ownerByIndex[plot.Index] = player
			plotByPlayer[player] = plot
			player:SetAttribute("PlotIndex", plot.Index)
			plot.NameLabel.Text = "🏡 Parcelle de " .. player.DisplayName
			PlayerDataService.markDirty(player)

			-- À chaque (ré)apparition, on le ramène chez lui
			characterConnections[player] = player.CharacterAdded:Connect(function()
				PlotService.teleportHome(player)
			end)
			task.spawn(PlotService.teleportHome, player) -- s'il est déjà apparu

			print(`[Parcelles] {player.Name} reçoit la parcelle {plot.Index}`)
			return
		end
	end

	-- Aucune parcelle libre (le serveur a plus de joueurs que de parcelles)
	warn(`[Parcelles] Plus de parcelle libre pour {player.Name} !`)
	Notifier.send(player, "Toutes les parcelles sont prises, désolé ! 😢", "error")
end

local function releasePlot(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	ownerByIndex[plot.Index] = nil
	plotByPlayer[player] = nil
	plot.NameLabel.Text = "🏡 Parcelle libre"

	if characterConnections[player] then
		characterConnections[player]:Disconnect()
		characterConnections[player] = nil
	end
end

function PlotService.start()
	PlayerDataService.onDataLoaded(assignPlot)
	PlayerDataService.onPlayerRemoving(releasePlot)
	-- Sécurité : si le joueur part avant d'avoir été chargé
	Players.PlayerRemoving:Connect(releasePlot)
end

return PlotService
