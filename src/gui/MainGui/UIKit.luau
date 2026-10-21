--[[
	UIKit.luau  —  la « boîte à outils » de l'interface
	===================================================
	Des petites fonctions pour créer des éléments d'interface jolis et
	cohérents sans répéter le même code partout :
	  UIKit.create(...)     crée n'importe quel élément avec ses propriétés
	  UIKit.label(...)      un texte
	  UIKit.button(...)     un bouton coloré avec animation quand on appuie
	  UIKit.corner(...)     des coins arrondis
	  UIKit.stroke(...)     un contour
	  UIKit.addResponsiveScale(...)  adapte la taille à l'écran (mobile / PC)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

-- Les couleurs du jeu (change-les ici pour changer tout le style !)
UIKit.Colors = {
	Text = Color3.fromRGB(255, 255, 255),
	TextDark = Color3.fromRGB(60, 40, 80),
	Outline = Color3.fromRGB(50, 30, 70),
	Panel = Color3.fromRGB(255, 248, 235),
	PanelHeader = Color3.fromRGB(255, 120, 180),
	Row = Color3.fromRGB(255, 255, 255),
	Coins = Color3.fromRGB(255, 200, 40),
	Size = Color3.fromRGB(110, 210, 90),
	Rebirth = Color3.fromRGB(170, 110, 255),
	Shop = Color3.fromRGB(255, 140, 60),
	Upgrades = Color3.fromRGB(70, 170, 255),
	Skins = Color3.fromRGB(255, 110, 190),
	Store = Color3.fromRGB(40, 200, 170),
	Feed = Color3.fromRGB(255, 90, 110),
	Success = Color3.fromRGB(80, 200, 100),
	Error = Color3.fromRGB(235, 80, 80),
	Disabled = Color3.fromRGB(170, 170, 180),
}

----------------------------------------------------------------------
-- Création d'éléments
----------------------------------------------------------------------

-- Crée un élément : UIKit.create("Frame", { Size = ..., Parent = ... })
function UIKit.create(className: string, properties: { [string]: any }?): any
	local instance = Instance.new(className)
	local parent = nil
	for name, value in pairs(properties or {}) do
		if name == "Parent" then
			parent = value
		else
			(instance :: any)[name] = value
		end
	end
	instance.Parent = parent -- le Parent en dernier, c'est plus rapide
	return instance
end

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return UIKit.create("UIStroke", {
		Color = color or UIKit.Colors.Outline,
		Thickness = thickness or 3,
		-- Sur un texte : contour des lettres. Sur un cadre ou un bouton : contour du bord.
		ApplyStrokeMode = if parent:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, pixels: number): UIPadding
	local p = UDim.new(0, pixels)
	return UIKit.create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p, Parent = parent })
end

-- Un dégradé du haut (clair) vers le bas (la couleur)
function UIKit.gradient(parent: Instance, color: Color3): UIGradient
	return UIKit.create("UIGradient", {
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color),
		Rotation = 90,
		Parent = parent,
	})
end

-- Un texte avec contour (lisible sur tous les fonds)
function UIKit.label(properties: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
	}
	for name, value in properties do
		defaults[name] = value
	end
	local outline = defaults.Outline
	defaults.Outline = nil
	local label = UIKit.create("TextLabel", defaults)
	if outline ~= false then
		UIKit.stroke(label, UIKit.Colors.Outline, 2)
	end
	return label
end

----------------------------------------------------------------------
-- Sons de l'interface
----------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}

-- Joue un son de Config.Sounds (« Click », « Success », « Error »...)
function UIKit.playSound(name: string)
	local settings = Config.Sounds[name]
	if not settings then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = settings.Id
		sound.Volume = settings.Volume
		sound.PlaybackSpeed = settings.Pitch
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

----------------------------------------------------------------------
-- Boutons
----------------------------------------------------------------------

-- Crée un bouton coloré. onClick est appelé quand on clique (ou touche sur mobile).
function UIKit.button(properties: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = properties.Color or UIKit.Colors.Success
	properties.Color = nil

	local defaults = {
		BackgroundColor3 = Color3.new(1, 1, 1), -- la couleur vient du dégradé
		AutoButtonColor = false,
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		TextStrokeTransparency = 0.3, -- contour des lettres du bouton
		TextStrokeColor3 = UIKit.Colors.Outline,
	}
	for name, value in properties do
		defaults[name] = value
	end
	local button = UIKit.create("TextButton", defaults)
	UIKit.corner(button, 12)
	UIKit.stroke(button, UIKit.Colors.Outline, 3)
	local gradient = UIKit.gradient(button, color)
	gradient.Name = "Couleur"
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 34, Parent = button })

	-- Petite animation : le bouton rétrécit quand on appuie dessus
	local pressScale = UIKit.create("UIScale", { Name = "Appui", Parent = button })
	local fast = TweenInfo.new(0.08)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(pressScale, fast, { Scale = 0.92 }):Play()
	end)
	local function release()
		TweenService:Create(pressScale, fast, { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)

	if onClick then
		button.Activated:Connect(function()
			UIKit.playSound("Click")
			onClick()
		end)
	end
	return button
end

-- Change la couleur d'un bouton créé avec UIKit.button
function UIKit.setButtonColor(button: GuiObject, color: Color3)
	local gradient = button:FindFirstChild("Couleur")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
	end
end

----------------------------------------------------------------------
-- Adaptation à la taille de l'écran (mobile, tablette, PC)
----------------------------------------------------------------------
-- L'interface est dessinée pour un écran d'environ 1100 × 650 pixels.
-- Un UIScale agrandit ou rétrécit chaque bloc selon l'écran réel.
local responsiveScales: { UIScale } = {}

local function computeScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	local scale = math.min(viewport.X / 1100, viewport.Y / 650)
	return math.clamp(scale, 0.5, 1.3)
end

local function refreshScales()
	local scale = computeScale()
	for _, uiScale in responsiveScales do
		uiScale.Scale = scale
	end
end

-- Ajoute un UIScale automatique à un bloc de l'interface
function UIKit.addResponsiveScale(guiObject: GuiObject)
	local uiScale = UIKit.create("UIScale", { Name = "AdaptationEcran", Parent = guiObject })
	uiScale.Scale = computeScale()
	table.insert(responsiveScales, uiScale)
	return uiScale
end

local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
	end
	refreshScales()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

return UIKit
