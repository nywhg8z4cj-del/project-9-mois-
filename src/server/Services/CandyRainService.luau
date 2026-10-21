--[[
	CandyRainService.luau  —  l'événement « Pluie de bonbons » 🍬
	============================================================
	Toutes les 10 minutes (Config.CandyRain.Interval) :
	  1. une annonce s'affiche chez tout le monde 10 secondes avant ;
	  2. pendant 30 secondes, des bonbons tombent du ciel sur la place centrale ;
	  3. toucher un bonbon le ramasse et fait grandir ton monstre !

	Anti-triche : c'est le SERVEUR qui crée les bonbons et qui détecte le
	contact (Touched). Il vérifie aussi que le joueur est vraiment à côté.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonsterService = require(script.Parent.MonsterService)
local Notifier = require(script.Parent.Notifier)

local CandyRainService = {}

local random = Random.new()
local candyFolder: Folder

-- Le joueur ramasse un bonbon
local function onCandyTouched(candy: BasePart, hit: BasePart)
	if candy:GetAttribute("Collected") then
		return -- déjà ramassé par quelqu'un d'autre
	end

	-- Qui a touché ? (hit peut être une jambe, un bras, un accessoire...)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or not PlayerDataService.isLoaded(player) then
		return
	end

	-- Anti-triche : le personnage doit être tout près du bonbon
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart or (rootPart.Position - candy.Position).Magnitude > 15 then
		return
	end

	candy:SetAttribute("Collected", true)
	candy:Destroy()

	local data = PlayerDataService.getData(player)
	if data then
		local gain = Formulas.candySizeGain(data.Size)
		MonsterService.addSize(player, gain, "candy", "🍬")
		Remotes.event("CandyRainEvent"):FireClient(player, "collected", gain)
	end
end

-- Fait tomber UN bonbon à un endroit au hasard au-dessus de la place
local function spawnCandy()
	local cfg = Config.CandyRain
	local radius = Config.World.PlazaRadius - 4
	-- math.sqrt donne une répartition bien uniforme dans le cercle
	local distance = radius * math.sqrt(random:NextNumber())
	local angle = random:NextNumber(0, math.pi * 2)

	local candy = Instance.new("Part")
	candy.Name = "Bonbon"
	candy.Shape = Enum.PartType.Ball
	candy.Size = Vector3.one * 1.8
	candy.Color = cfg.Colors[random:NextInteger(1, #cfg.Colors)]
	candy.Material = Enum.Material.Neon
	candy.Position = Vector3.new(math.cos(angle) * distance, cfg.SpawnHeight, math.sin(angle) * distance)
	candy.Anchored = false
	candy.CanCollide = true
	candy.Parent = candyFolder

	-- Le serveur s'occupe lui-même de la chute (personne ne peut tricher dessus)
	pcall(function()
		candy:SetNetworkOwner(nil)
	end)

	candy.Touched:Connect(function(hit)
		onCandyTouched(candy, hit)
	end)

	-- Le bonbon disparaît tout seul au bout de quelques secondes
	Debris:AddItem(candy, cfg.CandyLifetime)
end

-- Un événement complet : annonce → pluie → fin
local function runEvent()
	local cfg = Config.CandyRain
	local candyEvent = Remotes.event("CandyRainEvent")

	-- 1. L'annonce
	candyEvent:FireAllClients("announce", cfg.AnnounceBefore)
	Notifier.sendAll(`🍬 Pluie de bonbons dans {cfg.AnnounceBefore} secondes ! Cours sur la place centrale !`, "event")
	task.wait(cfg.AnnounceBefore)

	-- 2. La pluie
	candyEvent:FireAllClients("start", cfg.Duration)
	print("[Pluie de bonbons] C'est parti !")
	local endTime = os.clock() + cfg.Duration
	while os.clock() < endTime do
		spawnCandy()
		task.wait(cfg.SpawnInterval)
	end

	-- 3. La fin
	candyEvent:FireAllClients("end", 0)
	Notifier.sendAll("🍬 La pluie de bonbons est terminée. Rendez-vous dans 10 minutes !", "info")
end

function CandyRainService.start()
	candyFolder = Instance.new("Folder")
	candyFolder.Name = "Bonbons"
	candyFolder.Parent = workspace

	task.spawn(function()
		local cfg = Config.CandyRain
		-- Dans Studio, la première pluie arrive vite pour pouvoir tester
		local firstDelay = if RunService:IsStudio() then cfg.StudioFirstEventDelay else cfg.FirstEventDelay
		task.wait(math.max(0, firstDelay - cfg.AnnounceBefore))

		while true do
			if #Players:GetPlayers() > 0 then
				runEvent()
			end
			-- Prochaine pluie : « Interval » secondes après le début de celle-ci
			task.wait(math.max(1, cfg.Interval - cfg.Duration - cfg.AnnounceBefore))
		end
	end)
end

return CandyRainService
