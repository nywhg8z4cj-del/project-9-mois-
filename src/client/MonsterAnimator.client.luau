--[[
	MonsterAnimator.client.luau  —  anime les monstres (côté CLIENT)
	================================================================
	Le serveur dit seulement « ce monstre a maintenant la taille 120 »
	(attribut Size). Ce script, sur l'ordinateur de chaque joueur :
	  - fait GRANDIR le monstre en douceur avec TweenService ;
	  - le garde posé au sol (on agrandit tout depuis le point au sol) ;
	  - joue les effets quand il mange : rebond, particules, son, « +1 » flottant ;
	  - le fait « respirer » doucement, et l'entoure d'un contour quand ta souris
	    passe sur TON monstre.

	Pourquoi côté client ? Une animation faite par le serveur saccade
	(elle doit voyager sur Internet). Faite ici, elle est parfaitement fluide.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local MONSTER_TAG = "GrowMonster" -- le même que MonsterBuilder.TAG

-- Infos gardées pour chaque monstre animé
type PartInfo = { Part: BasePart, BaseSize: Vector3, BaseOffset: CFrame }
type MonsterState = {
	Model: Model,
	Pivot: CFrame,
	Parts: { PartInfo },
	Scale: NumberValue, -- l'échelle « grandir » (animée)
	Bounce: NumberValue, -- l'échelle « rebond » (animée)
	Phase: number, -- décalage de la respiration (pour que les monstres ne respirent pas tous en même temps)
	GrowTween: Tween?,
	BounceTween: Tween?,
}

local states: { [Model]: MonsterState } = {}

local BREATH_AMOUNT = 0.025 -- le monstre gonfle de 2,5 % en respirant
local BREATH_SPEED = 2.5

-- Applique l'échelle actuelle à toutes les Parts du monstre
local function applyScale(state: MonsterState)
	local breath = 1 + BREATH_AMOUNT * math.sin(os.clock() * BREATH_SPEED + state.Phase)
	local scale = state.Scale.Value * state.Bounce.Value * breath
	for _, info in state.Parts do
		info.Part.Size = info.BaseSize * scale
		-- On écarte chaque Part du point au sol proportionnellement à l'échelle :
		-- comme ça, le monstre grandit vers le haut et reste posé par terre.
		local offset = CFrame.new(info.BaseOffset.Position * scale) * info.BaseOffset.Rotation
		info.Part.CFrame = state.Pivot * offset
	end
end

-- Adapte la taille des particules à la taille du monstre
local function updateParticles(state: MonsterState)
	local body = state.Model:FindFirstChild("Corps")
	local particles = body and body:FindFirstChild("Miettes") :: ParticleEmitter?
	if particles then
		particles.Size = NumberSequence.new(0.6 * math.sqrt(state.Scale.Value), 0)
	end
end

-- Anime l'échelle vers la taille actuelle (attribut Size)
local function growToCurrentSize(state: MonsterState, instant: boolean)
	local size = state.Model:GetAttribute("Size") :: number?
	local target = Formulas.visualScale(size or 1)
	if state.GrowTween then
		state.GrowTween:Cancel()
	end
	if instant then
		state.Scale.Value = target
	else
		local info = TweenInfo.new(Config.Monster.GrowTweenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tween = TweenService:Create(state.Scale, info, { Value = target })
		state.GrowTween = tween
		tween:Play()
	end
	updateParticles(state)
end

-- Un nouveau monstre apparaît (ou arrive grâce au streaming)
local function setupMonster(model: Model)
	if states[model] then
		return
	end
	local pivot = model:GetAttribute("GroundPivot")
	if typeof(pivot) ~= "CFrame" then
		return
	end

	-- On récupère toutes les Parts qui ont une taille d'origine
	local parts: { PartInfo } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local baseSize = descendant:GetAttribute("BaseSize")
			local baseOffset = descendant:GetAttribute("BaseOffset")
			if typeof(baseSize) == "Vector3" and typeof(baseOffset) == "CFrame" then
				table.insert(parts, { Part = descendant, BaseSize = baseSize, BaseOffset = baseOffset })
			end
		end
	end

	local state: MonsterState = {
		Model = model,
		Pivot = pivot,
		Parts = parts,
		Scale = Instance.new("NumberValue"),
		Bounce = Instance.new("NumberValue"),
		Phase = math.random() * math.pi * 2,
	}
	state.Bounce.Value = 1
	states[model] = state

	-- Première fois : on met directement la bonne taille (sans animation)
	growToCurrentSize(state, true)
	applyScale(state)

	-- Ensuite : à chaque changement de taille, on anime
	model:GetAttributeChangedSignal("Size"):Connect(function()
		growToCurrentSize(state, false)
	end)

	-- Contour lumineux quand la souris passe sur SON propre monstre
	local clickDetector = model:FindFirstChildOfClass("ClickDetector")
	if clickDetector and model:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.Enabled = false
		highlight.Parent = model
		clickDetector.MouseHoverEnter:Connect(function()
			highlight.Enabled = true
		end)
		clickDetector.MouseHoverLeave:Connect(function()
			highlight.Enabled = false
		end)
	end
end

local function cleanupMonster(model: Model)
	local state = states[model]
	if state then
		state.Scale:Destroy()
		state.Bounce:Destroy()
		states[model] = nil
	end
end

----------------------------------------------------------------------
-- Effets quand un monstre mange
----------------------------------------------------------------------

-- Petit « rebond » : le monstre gonfle puis revient à la normale
local function bounce(state: MonsterState, strength: number)
	if state.BounceTween then
		state.BounceTween:Cancel()
	end
	state.Bounce.Value = 1
	-- reverses = true : l'animation fait l'aller puis le retour
	local info = TweenInfo.new(Config.Monster.BounceTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = TweenService:Create(state.Bounce, info, { Value = 1 + (Config.Monster.BounceScale - 1) * strength })
	state.BounceTween = tween
	tween:Play()
end

-- Un texte « +5 » qui s'envole au-dessus du monstre
local function floatingText(body: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.ExtentsOffsetWorldSpace = Vector3.new(math.random(-6, 6) / 10, 1, 0)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.MaxDistance = 150
	billboard.LightInfluence = 0
	billboard.Adornee = body
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(0.9, function()
		billboard:Destroy()
	end)
end

-- Réglages des effets selon le type de repas
local EFFECTS = {
	click = { Particles = 8, Bounce = 1, Color = Color3.fromRGB(255, 255, 255) },
	auto = { Particles = 4, Bounce = 0.6, Color = Color3.fromRGB(180, 230, 255) },
	food = { Particles = 30, Bounce = 1.8, Color = Color3.fromRGB(255, 220, 90) },
	candy = { Particles = 10, Bounce = 1.2, Color = Color3.fromRGB(255, 130, 220) },
	reset = { Particles = 80, Bounce = 2.5, Color = Color3.fromRGB(200, 150, 255) },
}

local function onFeedEffect(model: Model?, amount: number, kind: string, icon: string?)
	-- Le monstre peut être « nil » s'il est trop loin (streaming) : rien à faire
	if not model then
		return
	end
	local state = states[model]
	local body = model:FindFirstChild("Corps") :: BasePart?
	if not state or not body then
		return
	end

	local effect = EFFECTS[kind] or EFFECTS.click
	bounce(state, effect.Bounce)

	local particles = body:FindFirstChild("Miettes") :: ParticleEmitter?
	if particles then
		particles:Emit(effect.Particles)
	end

	local sound = body:FindFirstChild("Bouchee") :: Sound?
	if sound and kind ~= "reset" then
		sound:Play()
	end

	if amount > 0 then
		local prefix = if icon then icon .. " " else ""
		floatingText(body, prefix .. "+" .. Format.number(amount), effect.Color)
	elseif kind == "reset" then
		floatingText(body, "✨ RENAISSANCE ✨", effect.Color)
	end
end

----------------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------------
CollectionService:GetInstanceAddedSignal(MONSTER_TAG):Connect(function(instance)
	if instance:IsA("Model") then
		-- task.defer : on attend la fin de l'image pour que tout le modèle soit arrivé
		task.defer(setupMonster, instance)
	end
end)
CollectionService:GetInstanceRemovedSignal(MONSTER_TAG):Connect(function(instance)
	if instance:IsA("Model") then
		cleanupMonster(instance)
	end
end)
for _, instance in CollectionService:GetTagged(MONSTER_TAG) do
	if instance:IsA("Model") then
		task.defer(setupMonster, instance)
	end
end

Remotes.event("FeedEffect").OnClientEvent:Connect(onFeedEffect)

-- À chaque image : on redessine les monstres (respiration + animations en cours)
RunService.Heartbeat:Connect(function()
	for _, state in states do
		applyScale(state)
	end
end)
