--[[
	MonsterBuilder.luau  —  fabrique le modèle 3D d'un monstre
	==========================================================
	Le monstre est fait de Parts simples :
	  - un corps rond (Ball), deux pieds, deux yeux (blanc + pupille), une bouche ;
	  - un accessoire selon le skin (antennes, cornes, couronne, halo, chapeau...).

	Toutes les positions sont données pour un monstre de TAILLE 1 (échelle 1),
	par rapport au point au sol sous le monstre (le « pivot »).
	Dans ce repère : Y = vers le haut, -Z = devant (là où il regarde).

	Pour que le client puisse agrandir le monstre en douceur, on note sur
	chaque Part sa taille et sa position d'origine (attributs BaseSize et
	BaseOffset). Le client multiplie simplement ces valeurs par l'échelle.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local MonsterBuilder = {}

MonsterBuilder.TAG = "GrowMonster" -- étiquette (tag) que le client recherche

local STAND_UP = CFrame.Angles(0, 0, math.rad(90)) -- met un cylindre debout

-- Crée une Part du monstre. « offset » = position par rapport au pivot (échelle 1)
local function addPart(model: Model, pivot: CFrame, name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = pivot * offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Les valeurs « d'origine » pour l'agrandissement côté client
	part:SetAttribute("BaseSize", size)
	part:SetAttribute("BaseOffset", offset)
	part.Parent = model
	return part
end

----------------------------------------------------------------------
-- Les accessoires (un par skin)
----------------------------------------------------------------------
local ACCESSORIES = {}

ACCESSORIES.Antennes = function(model: Model, pivot: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		local tilt = math.rad(90 - 15 * side) -- penchées vers l'extérieur
		addPart(model, pivot, "Antenne", Enum.PartType.Cylinder, Vector3.new(1.6, 0.15, 0.15), CFrame.new(0.6 * side, 4.45, 0) * CFrame.Angles(0, 0, tilt), Color3.fromRGB(60, 60, 60))
		addPart(model, pivot, "BouleAntenne", Enum.PartType.Ball, Vector3.one * 0.55, CFrame.new(0.81 * side, 5.22, 0), color, Enum.Material.Neon)
	end
end

ACCESSORIES.Cornes = function(model: Model, pivot: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		local tilt = math.rad(90 - 30 * side)
		addPart(model, pivot, "Corne", Enum.PartType.Cylinder, Vector3.new(0.9, 0.45, 0.45), CFrame.new(0.95 * side, 3.95, -0.3) * CFrame.Angles(0, 0, tilt), color)
		addPart(model, pivot, "BoutCorne", Enum.PartType.Ball, Vector3.one * 0.45, CFrame.new(1.2 * side, 4.35, -0.3), color)
	end
end

ACCESSORIES.Couronne = function(model: Model, pivot: CFrame, color: Color3)
	addPart(model, pivot, "Couronne", Enum.PartType.Cylinder, Vector3.new(0.6, 2.2, 2.2), CFrame.new(0, 4, 0) * STAND_UP, color, Enum.Material.Foil)
	for i = 1, 5 do
		local angle = math.rad(i * 72)
		addPart(model, pivot, "Pointe", Enum.PartType.Ball, Vector3.one * 0.45, CFrame.new(math.cos(angle) * 0.95, 4.4, math.sin(angle) * 0.95), Color3.fromRGB(255, 90, 140), Enum.Material.Neon)
	end
end

ACCESSORIES.Halo = function(model: Model, pivot: CFrame, color: Color3)
	-- Un anneau fait de 12 petites perles lumineuses
	for i = 1, 12 do
		local angle = math.rad(i * 30)
		addPart(model, pivot, "Halo", Enum.PartType.Ball, Vector3.one * 0.4, CFrame.new(math.cos(angle) * 1.2, 5, math.sin(angle) * 1.2), color, Enum.Material.Neon)
	end
end

ACCESSORIES.Chapeau = function(model: Model, pivot: CFrame, color: Color3)
	addPart(model, pivot, "Bord", Enum.PartType.Cylinder, Vector3.new(0.2, 2.8, 2.8), CFrame.new(0, 3.85, 0) * STAND_UP, color)
	addPart(model, pivot, "Haut", Enum.PartType.Cylinder, Vector3.new(1.6, 1.8, 1.8), CFrame.new(0, 4.7, 0) * STAND_UP, color)
	addPart(model, pivot, "Ruban", Enum.PartType.Cylinder, Vector3.new(0.3, 1.85, 1.85), CFrame.new(0, 4.1, 0) * STAND_UP, Color3.fromRGB(255, 80, 120))
end

ACCESSORIES.Licorne = function(model: Model, pivot: CFrame, color: Color3)
	-- Une corne faite de 3 cylindres de plus en plus fins, penchée vers l'avant
	local direction = CFrame.new(0, 3.75, -1.1) * CFrame.Angles(math.rad(-30), 0, 0)
	local widths = { 0.7, 0.5, 0.3 }
	for i, width in widths do
		addPart(model, pivot, "Corne" .. i, Enum.PartType.Cylinder, Vector3.new(0.55, width, width), direction * CFrame.new(0, (i - 1) * 0.5, 0) * STAND_UP, color, Enum.Material.Neon)
	end
end

----------------------------------------------------------------------
-- Construction du monstre complet
----------------------------------------------------------------------
-- skin   : un skin de Config.Skins
-- pivot  : position au sol (CFrame) où poser le monstre
-- owner  : le joueur propriétaire
function MonsterBuilder.build(skin, pivot: CFrame, owner: Player): Model
	local model = Instance.new("Model")
	model.Name = "Monstre_" .. owner.Name

	local bodyColor: Color3 = skin.BodyColor
	local darker = bodyColor:Lerp(Color3.new(0, 0, 0), 0.2)
	local white = Color3.fromRGB(255, 255, 255)
	local black = Color3.fromRGB(25, 25, 35)

	-- Le corps : une boule de 4 studs, posée au sol (centre à 2 studs de haut)
	local body = addPart(model, pivot, "Corps", Enum.PartType.Ball, Vector3.one * 4, CFrame.new(0, 2, 0), bodyColor, skin.Material)
	body.CanCollide = true -- on ne peut pas traverser le monstre

	-- Les pieds
	for _, side in { -1, 1 } do
		addPart(model, pivot, "Pied", Enum.PartType.Ball, Vector3.one * 1.4, CFrame.new(1.1 * side, 0.6, -0.5), darker, skin.Material)
	end

	-- Les yeux (un blanc + une pupille noire devant)
	for _, side in { -1, 1 } do
		addPart(model, pivot, "Oeil", Enum.PartType.Ball, Vector3.one * 1.2, CFrame.new(0.75 * side, 2.75, -1.45), white)
		addPart(model, pivot, "Pupille", Enum.PartType.Ball, Vector3.one * 0.55, CFrame.new(0.75 * side, 2.8, -1.95), black)
	end

	-- La bouche et la langue
	addPart(model, pivot, "Bouche", Enum.PartType.Block, Vector3.new(1.4, 0.35, 0.4), CFrame.new(0, 1.55, -1.85), Color3.fromRGB(90, 20, 40))
	addPart(model, pivot, "Langue", Enum.PartType.Block, Vector3.new(0.6, 0.15, 0.3), CFrame.new(0, 1.42, -1.95), Color3.fromRGB(255, 120, 150))

	-- L'accessoire du skin
	local makeAccessory = ACCESSORIES[skin.Accessory]
	if makeAccessory then
		makeAccessory(model, pivot, skin.AccessoryColor)
	end

	-- Clic sur le monstre (fonctionne aussi au doigt sur mobile)
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = Config.Monster.ClickDistance
	clickDetector.Parent = model

	-- Le son de bouchée (joué par le client)
	local sound = Instance.new("Sound")
	sound.Name = "Bouchee"
	sound.SoundId = Config.Sounds.Bite.Id
	sound.Volume = Config.Sounds.Bite.Volume
	sound.PlaybackSpeed = Config.Sounds.Bite.Pitch
	sound.RollOffMaxDistance = 120
	sound.Parent = body

	-- Les particules (des petites miettes colorées), déclenchées par le client
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Miettes"
	particles.Enabled = false -- on les lance « à la main » avec :Emit()
	particles.Shape = Enum.ParticleEmitterShape.Sphere
	particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	particles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	particles.Speed = NumberRange.new(6, 12)
	particles.Lifetime = NumberRange.new(0.5, 0.9)
	particles.Acceleration = Vector3.new(0, -25, 0)
	particles.Size = NumberSequence.new(0.6, 0)
	particles.LightEmission = 0.5
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 220, 255)),
	})
	particles.Parent = body

	-- Le texte au-dessus du monstre (nom + taille)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InfoMonstre"
	billboard.Size = UDim2.fromOffset(240, 70)
	-- ExtentsOffset : 1.8 × la demi-hauteur du corps au-dessus de son centre.
	-- Comme c'est relatif à la taille du corps, le texte monte quand le monstre grandit !
	billboard.ExtentsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
	billboard.MaxDistance = 250
	billboard.LightInfluence = 0
	billboard.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Nom"
	nameLabel.Size = UDim2.fromScale(1, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = white
	nameLabel.Text = "Monstre de " .. owner.DisplayName
	nameLabel.Parent = billboard

	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Name = "Taille"
	sizeLabel.Position = UDim2.fromScale(0, 0.4)
	sizeLabel.Size = UDim2.fromScale(1, 0.6)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Font = Enum.Font.FredokaOne
	sizeLabel.TextScaled = true
	sizeLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
	sizeLabel.Text = "📏 1"
	sizeLabel.Parent = billboard

	for _, label in { nameLabel, sizeLabel } do
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = black
		stroke.Parent = label
	end

	-- Infos pour le client
	model.WorldPivot = pivot
	model:SetAttribute("GroundPivot", pivot)
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("Size", 1)
	-- « Atomic » : avec le StreamingEnabled, le modèle arrive en entier chez
	-- le client (sinon il pourrait manquer des morceaux).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, MonsterBuilder.TAG)

	return model
end

return MonsterBuilder
