--[[
	SkinsPanel.luau  —  la fenêtre « Skins »
	========================================
	Une carte par skin de Config.Skins avec un mini-monstre de la bonne couleur.
	Le bouton change selon la situation :
	  « Équipé ✔ »         c'est le skin que tu portes
	  « Équiper »          tu l'as, clique pour le mettre
	  « 🔒 Renaiss. 2 »    il se débloque à la 2e renaissance
	  « 25K 💰 »           il s'achète avec des pièces
	  « R$ 49 »            il s'achète en Robux
	  « 👑 VIP »           réservé au gamepass VIP
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UIKit)
local Notifications = require(script.Parent.Parent.Notifications)
local RobuxPrices = require(script.Parent.Parent.RobuxPrices)
local PanelBase = require(script.Parent.PanelBase)

local SkinsPanel = {}

-- Dessine un petit monstre (rond + 2 yeux) de la couleur du skin
local function createPreview(parent: Instance, skin)
	local body = UIKit.create("Frame", {
		Name = "Apercu",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = skin.BodyColor,
		ZIndex = 13,
		Parent = parent,
	})
	UIKit.corner(body, 42)
	UIKit.stroke(body, UIKit.Colors.Outline, 3)
	UIKit.create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = body }) -- toujours bien rond
	for _, x in { 0.32, 0.68 } do
		local eye = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.38),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 14,
			Parent = body,
		})
		UIKit.corner(eye, 12)
		local pupil = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.fromOffset(11, 11),
			BackgroundColor3 = Color3.fromRGB(25, 25, 35),
			ZIndex = 15,
			Parent = eye,
		})
		UIKit.corner(pupil, 6)
	end
	local mouth = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(30, 8),
		BackgroundColor3 = Color3.fromRGB(90, 20, 40),
		ZIndex = 14,
		Parent = body,
	})
	UIKit.corner(mouth, 4)
end

function SkinsPanel.create(screenGui: ScreenGui)
	local panel = PanelBase.new(screenGui, {
		Name = "Skins",
		Title = "Skins de monstre",
		Icon = "🎨",
		Color = UIKit.Colors.Skins,
		Grid = true,
	})

	local equipSkin = Remotes.event("EquipSkin")
	local buySkin = Remotes.event("BuySkin")
	local player = Players.LocalPlayer
	local lastState = nil
	local buttons: { [string]: TextButton } = {}
	local robuxPrices: { [string]: number } = {}

	-- Que se passe-t-il quand on clique sur le bouton d'un skin ?
	local function onSkinClicked(skin)
		if not lastState then
			return
		end
		local owned = Formulas.ownsSkin(skin, lastState, lastState.Passes)
		local unlock = skin.Unlock
		if owned then
			equipSkin:FireServer(skin.Id)
		elseif unlock.Type == "Coins" then
			buySkin:FireServer(skin.Id)
		elseif unlock.Type == "Robux" then
			-- Fenêtre d'achat Roblox. Le serveur donnera le skin (ProcessReceipt).
			MarketplaceService:PromptProductPurchase(player, unlock.ProductId)
		elseif unlock.Type == "VIP" then
			MarketplaceService:PromptGamePassPurchase(player, Config.Monetization.GamePasses.VIP.Id)
		elseif unlock.Type == "Rebirth" then
			Notifications.show(`🔒 Ce skin se débloque à la renaissance n°{unlock.Rebirths} !`, "info")
		end
	end

	for order, skin in Config.Skins do
		if skin.Unlock.Type == "Robux" then
			robuxPrices[skin.Id] = skin.Unlock.RobuxPrice
			RobuxPrices.get(skin.Unlock.ProductId, Enum.InfoType.Product, skin.Unlock.RobuxPrice, function(price)
				robuxPrices[skin.Id] = price
			end)
		end

		local card = UIKit.create("Frame", {
			Name = skin.Id,
			BackgroundColor3 = UIKit.Colors.Row,
			LayoutOrder = order,
			ZIndex = 12,
			Parent = panel.Content,
		})
		UIKit.corner(card, 16)
		UIKit.stroke(card, Color3.fromRGB(230, 210, 230), 2)
		createPreview(card, skin)

		UIKit.label({
			Position = UDim2.fromOffset(6, 100),
			Size = UDim2.new(1, -12, 0, 28),
			Text = skin.Name,
			TextColor3 = UIKit.Colors.TextDark,
			Outline = false,
			ZIndex = 13,
			Parent = card,
		})
		buttons[skin.Id] = UIKit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 44),
			Text = "",
			ZIndex = 13,
			Parent = card,
		}, function()
			onSkinClicked(skin)
		end)
	end

	function panel.update(state)
		lastState = state
		for _, skin in Config.Skins do
			local button = buttons[skin.Id]
			local unlock = skin.Unlock
			local owned = Formulas.ownsSkin(skin, state, state.Passes)

			local text, color
			if state.EquippedSkin == skin.Id then
				text, color = "Équipé ✔", UIKit.Colors.Coins
			elseif owned then
				text, color = "Équiper", UIKit.Colors.Success
			elseif unlock.Type == "Rebirth" then
				text, color = `🔒 Renaiss. {unlock.Rebirths}`, UIKit.Colors.Disabled
			elseif unlock.Type == "Coins" then
				text = Format.number(unlock.Price) .. " 💰"
				color = if state.Coins >= unlock.Price then UIKit.Colors.Success else UIKit.Colors.Disabled
			elseif unlock.Type == "Robux" then
				text, color = `R$ {robuxPrices[skin.Id]}`, UIKit.Colors.Store
			else
				text, color = "👑 VIP", UIKit.Colors.Coins
			end
			button.Text = text
			UIKit.setButtonColor(button, color)
		end
	end

	return panel
end

return SkinsPanel
