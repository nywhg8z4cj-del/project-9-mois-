--[[
	WorldBuilder.luau  —  construit la carte du jeu automatiquement
	===============================================================
	Au lieu de construire la carte à la main dans Studio, ce script crée
	tout avec des Parts quand le serveur démarre :
	  - le sol (herbe) ;
	  - la place centrale (ronde) avec le point d'apparition ;
	  - 6 parcelles autour de la place, chacune avec un panneau ;
	  - des chemins, des sucettes géantes et des arbres pour décorer.

	Les positions dépendent de Config.World (nombre de parcelles, taille...).

	Astuce : clique sur Play, puis regarde le dossier Workspace > Map
	pour voir tout ce qui a été créé.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

-- Les infos d'une parcelle, utilisées par PlotService et MonsterService
export type PlotInfo = {
	Index: number,
	Model: Model,
	MonsterPivot: CFrame, -- là où le monstre est posé (au sol, tourné vers la place)
	SpawnCFrame: CFrame, -- là où le joueur apparaît sur sa parcelle
	NameLabel: TextLabel, -- le texte « Parcelle de ... » au-dessus du panneau
}

local WorldBuilder = {}
WorldBuilder.Plots = {} :: { PlotInfo }
WorldBuilder.Map = nil :: Folder?

-- Couleurs pastel des 6 parcelles
local PLOT_COLORS = {
	Color3.fromRGB(255, 179, 186),
	Color3.fromRGB(255, 223, 186),
	Color3.fromRGB(255, 255, 186),
	Color3.fromRGB(186, 255, 201),
	Color3.fromRGB(186, 225, 255),
	Color3.fromRGB(220, 190, 255),
}

----------------------------------------------------------------------
-- Petit outil : crée une Part ancrée avec des propriétés
----------------------------------------------------------------------
local function makePart(properties: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	local parent = properties.Parent
	for name, value in properties do
		if name ~= "Parent" then
			(part :: any)[name] = value
		end
	end
	part.Parent = parent -- on met le Parent en dernier (c'est plus rapide)
	return part
end

-- Les cylindres Roblox sont couchés (axe X). Cette rotation les met debout.
local STAND_UP = CFrame.Angles(0, 0, math.rad(90))

----------------------------------------------------------------------
-- Décorations
----------------------------------------------------------------------
local function makeLollipop(position: Vector3, color: Color3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Sucette"
	makePart({
		Name = "Baton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * STAND_UP,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = model,
	})
	makePart({
		Name = "Bonbon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 9, 9),
		-- tourné vers le centre de la place pour qu'on voie le rond
		CFrame = CFrame.lookAt(position + Vector3.new(0, 16, 0), Vector3.new(0, 16, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	model.Parent = parent
end

local function makeTree(position: Vector3, scale: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Arbre"
	makePart({
		Name = "Tronc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8 * scale, 2 * scale, 2 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * STAND_UP,
		Color = Color3.fromRGB(140, 90, 60),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	makePart({
		Name = "Feuillage",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 9 * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 10 * scale, 0)),
		Color = Color3.fromRGB(90, 200, 110),
		Material = Enum.Material.Grass,
		Parent = model,
	})
	model.Parent = parent
end

----------------------------------------------------------------------
-- Une parcelle
----------------------------------------------------------------------
local function buildPlot(index: number, parent: Instance): PlotInfo
	local cfg = Config.World
	local half = cfg.PlotSize / 2

	-- On répartit les parcelles en cercle (360° / nombre de parcelles)
	local angle = math.rad((index - 1) * 360 / cfg.PlotCount)
	local center = Vector3.new(math.cos(angle) * cfg.PlotDistance, 0, math.sin(angle) * cfg.PlotDistance)
	-- « facing » : au centre de la parcelle, tourné vers la place centrale.
	-- Dans ce repère : -Z = vers la place (devant), +Z = vers l'arrière.
	local facing = CFrame.lookAt(center, Vector3.zero)

	local model = Instance.new("Model")
	model.Name = "Parcelle" .. index

	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]

	makePart({
		Name = "Bordure",
		Size = Vector3.new(cfg.PlotSize + 3, 0.8, cfg.PlotSize + 3),
		CFrame = facing + Vector3.new(0, 0.4, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.25), -- un peu plus foncé
		Parent = model,
	})
	makePart({
		Name = "Sol",
		Size = Vector3.new(cfg.PlotSize, 1, cfg.PlotSize),
		CFrame = facing + Vector3.new(0, 0.5, 0), -- le dessus est à la hauteur 1
		Color = color,
		Parent = model,
	})

	-- Le panneau, à l'avant-droite de la parcelle
	local signBase = facing * CFrame.new(12, 1, -(half - 3))
	makePart({
		Name = "PoteauPanneau",
		Size = Vector3.new(1, 7, 1),
		CFrame = signBase * CFrame.new(0, 3.5, 0),
		Color = Color3.fromRGB(140, 90, 60),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local board = makePart({
		Name = "Panneau",
		Size = Vector3.new(12, 4, 0.6),
		CFrame = signBase * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Parent = model,
	})

	-- Le BillboardGui : un texte qui flotte et regarde toujours la caméra
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NomParcelle"
	billboard.Size = UDim2.new(16, 0, 3, 0) -- en studs : grossit/rétrécit avec la distance
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 300
	billboard.LightInfluence = 0
	billboard.Parent = board

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Text = "🏡 Parcelle libre"
	nameLabel.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.5)
	stroke.Parent = nameLabel

	model.Parent = parent

	return {
		Index = index,
		Model = model,
		-- Le monstre est posé sur le sol (hauteur 1), un peu vers l'arrière
		MonsterPivot = facing * CFrame.new(0, 1, 8),
		-- Le joueur apparaît vers l'avant, tourné vers son monstre
		SpawnCFrame = facing * CFrame.new(0, 4, -(half - 8)) * CFrame.Angles(0, math.pi, 0),
		NameLabel = nameLabel,
	}
end

----------------------------------------------------------------------
-- Lumière et couleurs (effets « post-traitement » dans Lighting)
----------------------------------------------------------------------
local function setLightingEffect(className: string, name: string, properties: { [string]: any })
	local old = Lighting:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local effect = Instance.new(className)
	effect.Name = name
	for property, value in properties do
		(effect :: any)[property] = value
	end
	effect.Parent = Lighting
end

local function setupLighting()
	-- Une belle journée ensoleillée
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 170)

	-- Une légère brume colorée au loin
	setLightingEffect("Atmosphere", "GrowAtmosphere", {
		Density = 0.28,
		Haze = 1.2,
		Color = Color3.fromRGB(255, 220, 240),
		Decay = Color3.fromRGB(150, 180, 255),
	})
	-- Des couleurs un peu plus vives (jeu « bonbon »)
	setLightingEffect("ColorCorrectionEffect", "GrowCouleurs", {
		Saturation = 0.15,
		Contrast = 0.05,
		Brightness = 0.02,
	})
	-- Les matières « Neon » brillent joliment
	setLightingEffect("BloomEffect", "GrowBrillance", {
		Intensity = 0.6,
		Size = 24,
		Threshold = 1.6,
	})
	setLightingEffect("SunRaysEffect", "GrowRayons", {
		Intensity = 0.05,
		Spread = 0.6,
	})
end

----------------------------------------------------------------------
-- Construction de toute la carte
----------------------------------------------------------------------
function WorldBuilder.build()
	local cfg = Config.World

	-- On enlève la Baseplate et le SpawnLocation du modèle « Baseplate » de Studio
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old and old:IsA("BasePart") then
			old:Destroy()
		end
	end
	-- Si une ancienne carte existe déjà, on la remplace
	local oldMap = workspace:FindFirstChild("Map")
	if oldMap then
		oldMap:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	WorldBuilder.Map = map

	-- Le sol : une grande plaque d'herbe dont le dessus est à la hauteur 0
	makePart({
		Name = "Herbe",
		Size = Vector3.new(800, 2, 800),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(120, 205, 100),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	-- La place centrale (un cylindre debout, le dessus à la hauteur 0.5)
	makePart({
		Name = "BordPlace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, cfg.PlazaRadius * 2 + 4, cfg.PlazaRadius * 2 + 4),
		CFrame = CFrame.new(0, 0, 0) * STAND_UP,
		Color = Color3.fromRGB(255, 140, 200),
		Parent = map,
	})
	makePart({
		Name = "Place",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, cfg.PlazaRadius * 2, cfg.PlazaRadius * 2),
		CFrame = CFrame.new(0, 0, 0) * STAND_UP,
		Color = Color3.fromRGB(255, 245, 225),
		Material = Enum.Material.Pebble,
		Parent = map,
	})

	-- Le point d'apparition au centre de la place
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Apparition"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, 0.7, 0)
	spawn.Color = Color3.fromRGB(255, 200, 80)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0 -- pas de bouclier ForceField (pas de combat dans ce jeu !)
	spawn.Neutral = true
	spawn.Parent = map

	-- Les parcelles et les chemins
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Parcelles"
	plotsFolder.Parent = map

	table.clear(WorldBuilder.Plots)
	for index = 1, cfg.PlotCount do
		table.insert(WorldBuilder.Plots, buildPlot(index, plotsFolder))

		-- Chemin entre la place et la parcelle
		local angle = math.rad((index - 1) * 360 / cfg.PlotCount)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local startDistance = cfg.PlazaRadius - 2
		local endDistance = cfg.PlotDistance - cfg.PlotSize / 2 + 1
		local middle = direction * (startDistance + endDistance) / 2 + Vector3.new(0, 0.15, 0)
		makePart({
			Name = "Chemin" .. index,
			Size = Vector3.new(10, 0.3, endDistance - startDistance),
			CFrame = CFrame.lookAt(middle, middle + direction),
			Color = Color3.fromRGB(240, 220, 170),
			Parent = map,
		})
	end

	-- Décorations : des sucettes géantes entre les chemins
	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = map
	for index = 1, cfg.PlotCount do
		-- index 1 est laissé libre pour le panneau du classement (LeaderboardService)
		if index > 1 then
			local angle = math.rad((index - 0.5) * 360 / cfg.PlotCount)
			local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (cfg.PlazaRadius + 6)
			makeLollipop(position, PLOT_COLORS[index], decorations)
		end
	end

	-- Décorations : des arbres tout autour (Random.new(42) = toujours les mêmes positions)
	local random = Random.new(42)
	for _ = 1, 30 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(cfg.PlotDistance + cfg.PlotSize * 0.8, 360)
		makeTree(Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance), random:NextNumber(0.8, 1.6), decorations)
	end

	map.Parent = workspace
	setupLighting()
end

return WorldBuilder
