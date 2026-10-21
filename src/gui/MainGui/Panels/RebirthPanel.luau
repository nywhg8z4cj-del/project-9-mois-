--[[
	RebirthPanel.luau  —  la fenêtre « Renaissance »
	================================================
	Affiche :
	  - une barre de progression (taille actuelle / taille requise) ;
	  - le multiplicateur actuel → le prochain ;
	  - le skin qui sera débloqué (s'il y en a un) ;
	  - le bouton RENAÎTRE. Il faut cliquer 2 fois pour confirmer
	    (pour ne pas renaître par erreur !).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UIKit)
local PanelBase = require(script.Parent.PanelBase)

local RebirthPanel = {}

-- Un texte foncé sur une ligne de la fenêtre
local function addText(parent: Instance, order: number, height: number, text: string)
	return UIKit.label({
		Size = UDim2.new(1, 0, 0, height),
		Text = text,
		TextColor3 = UIKit.Colors.TextDark,
		Outline = false,
		TextWrapped = true,
		LayoutOrder = order,
		ZIndex = 12,
		Parent = parent,
	})
end

-- Le skin débloqué à la renaissance n° « rebirthNumber » (ou nil)
local function skinForRebirth(rebirthNumber: number)
	for _, skin in Config.Skins do
		if skin.Unlock.Type == "Rebirth" and skin.Unlock.Rebirths == rebirthNumber then
			return skin
		end
	end
	return nil
end

function RebirthPanel.create(screenGui: ScreenGui)
	local panel = PanelBase.new(screenGui, {
		Name = "Renaissance",
		Title = "Renaissance",
		Icon = "🔄",
		Color = UIKit.Colors.Rebirth,
	})
	local content = panel.Content

	addText(content, 1, 34, "Fais renaître ton monstre pour gagner PLUS de pièces pour toujours !")

	-- La barre de progression
	local bar = UIKit.create("Frame", {
		Name = "Barre",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(225, 215, 235),
		LayoutOrder = 2,
		ZIndex = 12,
		Parent = content,
	})
	UIKit.corner(bar, 14)
	UIKit.stroke(bar, UIKit.Colors.Outline, 3)
	local fill = UIKit.create("Frame", {
		Name = "Remplissage",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 13,
		Parent = bar,
	})
	UIKit.corner(fill, 14)
	UIKit.gradient(fill, UIKit.Colors.Rebirth)
	local barText = UIKit.label({
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Text = "",
		ZIndex = 14,
		Parent = bar,
	})

	local rewardText = addText(content, 3, 34, "")
	local skinText = addText(content, 4, 30, "")
	local warningText = addText(content, 5, 50, "")
	warningText.TextColor3 = Color3.fromRGB(200, 80, 80)

	-- Le bouton, avec confirmation en 2 clics
	local requestRebirth = Remotes.event("RequestRebirth")
	local confirmUntil = 0
	local canRebirth = false
	local button: TextButton

	local holder = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		ZIndex = 12,
		Parent = content,
	})
	button = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 64),
		Text = "🔄 RENAÎTRE",
		Color = UIKit.Colors.Rebirth,
		ZIndex = 13,
		Parent = holder,
	}, function()
		if not canRebirth then
			requestRebirth:FireServer() -- le serveur expliquera ce qui manque
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			button.Text = "🔄 RENAÎTRE"
			requestRebirth:FireServer() -- confirmé : on demande au serveur
		else
			confirmUntil = os.clock() + 3
			button.Text = "Sûr ? Clique encore !"
			task.delay(3, function()
				if os.clock() >= confirmUntil then
					button.Text = "🔄 RENAÎTRE"
				end
			end)
		end
	end)

	function panel.update(state)
		local required = state.RebirthRequirement
		local progress = math.clamp(state.Size / required, 0, 1)
		canRebirth = state.Size >= required

		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.max(progress, 0.04), 1) }):Play()
		barText.Text = `📏 {Format.number(state.Size)} / {Format.number(required)}`

		local now = Format.multiplier(state.RebirthMultiplier)
		local after = Format.multiplier(Formulas.rebirthMultiplier(state.Rebirths + 1))
		rewardText.Text = `Multiplicateur de renaissance : {now}  →  {after}`

		local nextSkin = skinForRebirth(state.Rebirths + 1)
		skinText.Text = if nextSkin then `🎨 Débloque le skin « {nextSkin.Name} » !` else "🎨 Pas de nouveau skin cette fois-ci"

		local keep = if Config.Rebirth.ResetUpgrades then "Tes skins sont gardés." else "Tes améliorations et tes skins sont gardés."
		warningText.Text = `⚠️ Ton monstre repart à la taille {Config.Monster.StartSize} et tes pièces à 0. {keep}`

		UIKit.setButtonColor(button, if canRebirth then UIKit.Colors.Rebirth else UIKit.Colors.Disabled)
	end

	return panel
end

return RebirthPanel
