--[[
	PanelBase.luau  —  le modèle commun de toutes les fenêtres (Boutique, Skins...)
	==============================================================================
	PanelBase.new(...) crée une fenêtre avec :
	  - un bandeau de titre coloré et un bouton ✕ pour fermer ;
	  - une zone qui défile (ScrollingFrame) pour le contenu.
	PanelBase.createRow(...) crée une ligne « icône + titre + détail + bouton ».

	Toutes les fenêtres se ressemblent donc, et c'est plus simple à modifier.
]]

local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.Parent.UIKit)

local PanelBase = {}

export type Panel = {
	Frame: Frame,
	Content: ScrollingFrame,
	isOpen: () -> boolean,
	open: () -> (),
	close: () -> (),
	update: (state: any) -> (),
}

-- options = { Name, Title, Icon, Color, Grid (true = grille de cartes au lieu d'une liste) }
function PanelBase.new(screenGui: ScreenGui, options): Panel
	-- Un objet ne peut avoir qu'UN SEUL UIScale. On utilise donc 2 cadres :
	--   « holder » (invisible) : adapte la taille à l'écran ;
	--   « frame » (la fenêtre) : fait l'animation « pop » à l'ouverture.
	local holder = UIKit.create("Frame", {
		Name = options.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(660, 450),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	})
	UIKit.addResponsiveScale(holder)

	local frame = UIKit.create("Frame", {
		Name = "Fenetre",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Colors.Panel,
		ZIndex = 10,
		Parent = holder,
	})
	UIKit.corner(frame, 22)
	UIKit.stroke(frame, UIKit.Colors.Outline, 4)
	local popScale = UIKit.create("UIScale", { Name = "Apparition", Parent = frame })

	-- Le bandeau de titre
	local header = UIKit.create("Frame", {
		Name = "Titre",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 11,
		Parent = frame,
	})
	UIKit.corner(header, 22)
	UIKit.gradient(header, options.Color)
	UIKit.label({
		Size = UDim2.new(1, -140, 0, 46),
		Position = UDim2.fromOffset(20, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = options.Icon .. "  " .. options.Title,
		ZIndex = 12,
		Parent = header,
	})

	-- La zone de contenu qui défile
	local content = UIKit.create("ScrollingFrame", {
		Name = "Contenu",
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 1, -90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = options.Color,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, -- la zone s'agrandit toute seule
		ZIndex = 11,
		Parent = frame,
	})
	UIKit.create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 14),
		Parent = content,
	})
	if options.Grid then
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 186),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = content,
		})
	else
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = content,
		})
	end

	local panel = {} :: Panel
	panel.Frame = holder
	panel.Content = content

	function panel.isOpen()
		return holder.Visible
	end

	function panel.open()
		holder.Visible = true
		-- Petite animation « pop » à l'ouverture
		popScale.Scale = 0.85
		TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	function panel.close()
		holder.Visible = false
	end

	function panel.update(_state) end -- chaque fenêtre remplace cette fonction

	-- Le bouton ✕
	UIKit.button({
		Name = "Fermer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.fromOffset(46, 46),
		Text = "✕",
		Color = UIKit.Colors.Error,
		ZIndex = 12,
		Parent = header,
	}, panel.close)

	return panel
end

export type Row = {
	Frame: Frame,
	Icon: TextLabel,
	Title: TextLabel,
	Subtitle: TextLabel,
	Button: TextButton,
}

-- Une ligne de liste : [icône] Titre / détail ............ [Bouton]
function PanelBase.createRow(parent: Instance, order: number, onClick: () -> ()): Row
	local frame = UIKit.create("Frame", {
		Name = "Ligne" .. order,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = UIKit.Colors.Row,
		LayoutOrder = order,
		ZIndex = 12,
		Parent = parent,
	})
	UIKit.corner(frame, 16)
	UIKit.stroke(frame, Color3.fromRGB(230, 210, 230), 2)

	local icon = UIKit.label({
		Name = "Icone",
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(10, 10),
		Text = "",
		Outline = false,
		ZIndex = 13,
		Parent = frame,
	})
	local title = UIKit.label({
		Name = "Titre",
		Size = UDim2.new(1, -270, 0, 36),
		Position = UDim2.fromOffset(84, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UIKit.Colors.TextDark,
		Outline = false,
		Text = "",
		ZIndex = 13,
		Parent = frame,
	})
	local subtitle = UIKit.label({
		Name = "Detail",
		Size = UDim2.new(1, -270, 0, 26),
		Position = UDim2.fromOffset(84, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(130, 110, 140),
		Outline = false,
		Text = "",
		ZIndex = 13,
		Parent = frame,
	})
	local button = UIKit.button({
		Name = "Bouton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(170, 58),
		Text = "",
		ZIndex = 13,
		Parent = frame,
	}, onClick)

	return {
		Frame = frame,
		Icon = icon,
		Title = title,
		Subtitle = subtitle,
		Button = button,
	}
end

return PanelBase
