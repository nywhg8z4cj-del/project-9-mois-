--[[
	HUD.luau  —  l'affichage permanent à l'écran
	============================================
	  - en haut : compteur de pièces (+ revenus par seconde), taille, multiplicateur ;
	  - à gauche : les boutons du menu (Boutique, Améliorations, Renaissance, Skins...) ;
	  - en bas : le gros bouton « NOURRIR » (pratique sur mobile, ou touche F sur PC).

	Le HUD n'invente aucun chiffre : il affiche ce que le serveur envoie (state).
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

local HUD = {}

-- Crée une « pastille » d'information (icône + grand texte + petit texte)
local function createPill(parent: Instance, name: string, width: number, color: Color3, icon: string, order: number)
	local pill = UIKit.create("Frame", {
		Name = name,
		Size = UDim2.fromOffset(width, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.corner(pill, 18)
	UIKit.stroke(pill, UIKit.Colors.Outline, 3)
	UIKit.gradient(pill, color)

	UIKit.label({
		Name = "Icone",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(8, 7),
		Text = icon,
		Outline = false,
		Parent = pill,
	})
	local main = UIKit.label({
		Name = "Valeur",
		Size = UDim2.new(1, -70, 0, 36),
		Position = UDim2.fromOffset(62, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = pill,
	})
	local sub = UIKit.label({
		Name = "Detail",
		Size = UDim2.new(1, -70, 0, 20),
		Position = UDim2.fromOffset(62, 39),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = pill,
	})
	return pill, main, sub
end

function HUD.create(screenGui: ScreenGui, onFeed: () -> ())
	local hud = {}

	------------------------------------------------------------------
	-- En haut : pièces, taille, multiplicateur
	------------------------------------------------------------------
	local topBar = UIKit.create("Frame", {
		Name = "BarreDuHaut",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(620, 70),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	UIKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = topBar,
	})
	UIKit.addResponsiveScale(topBar)

	local coinsPill, coinsText, incomeText = createPill(topBar, "Pieces", 240, UIKit.Colors.Coins, "💰", 1)
	local sizePill, sizeText, bestText = createPill(topBar, "Taille", 220, UIKit.Colors.Size, "📏", 2)
	local _, multiplierText, rebirthText = createPill(topBar, "Multiplicateur", 140, UIKit.Colors.Rebirth, "🔄", 3)
	hud.CoinsPill = coinsPill
	hud.SizePill = sizePill

	------------------------------------------------------------------
	-- À gauche : le menu (les boutons sont ajoutés par les panneaux)
	------------------------------------------------------------------
	local menu = UIKit.create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(86, 470),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	UIKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = menu,
	})
	UIKit.addResponsiveScale(menu)

	local menuButtons: { [string]: TextButton } = {}
	local menuCount = 0

	-- Ajoute un bouton au menu. Renvoie le bouton.
	function hud.addMenuButton(name: string, icon: string, text: string, color: Color3, onClick: () -> ()): TextButton
		menuCount += 1
		local button = UIKit.button({
			Name = name,
			Size = UDim2.fromOffset(86, 82),
			Text = "",
			Color = color,
			LayoutOrder = menuCount,
			Parent = menu,
		}, onClick)
		UIKit.label({
			Name = "Icone",
			Size = UDim2.new(1, 0, 0.6, 0),
			Position = UDim2.fromScale(0, 0.05),
			Text = icon,
			Outline = false,
			Parent = button,
		})
		UIKit.label({
			Name = "Texte",
			Size = UDim2.new(1, -6, 0.3, 0),
			Position = UDim2.new(0, 3, 0.65, 0),
			Text = text,
			Parent = button,
		})
		-- Une pastille rouge « ! » pour attirer l'attention (cachée par défaut)
		local badge = UIKit.create("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = UIKit.Colors.Error,
			Visible = false,
			ZIndex = 5,
			Parent = button,
		})
		UIKit.corner(badge, 13)
		UIKit.stroke(badge, Color3.new(1, 1, 1), 2)
		UIKit.label({ Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 6, Parent = badge })

		menuButtons[name] = button
		return button
	end

	-- Affiche ou cache la pastille « ! » d'un bouton du menu
	function hud.setBadge(name: string, visible: boolean)
		local button = menuButtons[name]
		local badge = button and button:FindFirstChild("Badge")
		if badge then
			(badge :: Frame).Visible = visible
		end
	end

	------------------------------------------------------------------
	-- En bas : le bouton « NOURRIR »
	------------------------------------------------------------------
	local feedButton = UIKit.button({
		Name = "BoutonNourrir",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(240, 76),
		Text = "",
		Color = UIKit.Colors.Feed,
		Parent = screenGui,
	}, onFeed)
	UIKit.addResponsiveScale(feedButton)
	UIKit.label({
		Size = UDim2.new(1, -16, 0.6, 0),
		Position = UDim2.fromOffset(8, 4),
		Text = "🍴 NOURRIR",
		Parent = feedButton,
	})
	local perClickText = UIKit.label({
		Size = UDim2.new(1, -16, 0.3, 0),
		Position = UDim2.new(0, 8, 0.63, 0),
		Text = "+1 par clic",
		Parent = feedButton,
	})
	hud.FeedButton = feedButton

	-- Sur PC : la touche F nourrit aussi le monstre
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
			onFeed()
		end
	end)

	------------------------------------------------------------------
	-- Mise à jour avec les infos du serveur
	------------------------------------------------------------------
	function hud.update(state)
		coinsText.Text = Format.number(state.Coins)
		incomeText.Text = "+" .. Format.number(state.IncomePerSecond) .. " / s"
		sizeText.Text = Format.number(state.Size)
		bestText.Text = "Record : " .. Format.number(state.BestSize)
		multiplierText.Text = Format.multiplier(state.IncomeMultiplier)
		rebirthText.Text = state.Rebirths .. " renaiss."
		perClickText.Text = "+" .. Format.number(state.SizePerClick) .. " par clic (F)"
	end

	return hud
end

return HUD
