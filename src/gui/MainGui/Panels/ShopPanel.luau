--[[
	ShopPanel.luau  —  la fenêtre « Boutique de nourriture »
	========================================================
	Une ligne par aliment de Config.Foods. Le bouton affiche le prix :
	  - vert si tu as assez de pièces ;
	  - gris sinon.
	Cliquer envoie une DEMANDE d'achat au serveur (BuyFood), qui vérifie tout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UIKit)
local PanelBase = require(script.Parent.PanelBase)

local ShopPanel = {}

function ShopPanel.create(screenGui: ScreenGui)
	local panel = PanelBase.new(screenGui, {
		Name = "Boutique",
		Title = "Boutique de nourriture",
		Icon = "🍔",
		Color = UIKit.Colors.Shop,
	})

	local buyFood = Remotes.event("BuyFood")
	local rows = {}

	for order, food in Config.Foods do
		local row = PanelBase.createRow(panel.Content, order, function()
			buyFood:FireServer(food.Id) -- on demande, le serveur décide
		end)
		row.Icon.Text = food.Icon
		row.Title.Text = food.Name
		row.Subtitle.Text = "+" .. Format.number(food.SizeGain) .. " taille"
		row.Button.Text = Format.number(food.Price) .. " 💰"
		rows[food.Id] = row
	end

	function panel.update(state)
		for _, food in Config.Foods do
			local canBuy = state.Coins >= food.Price
			UIKit.setButtonColor(rows[food.Id].Button, if canBuy then UIKit.Colors.Success else UIKit.Colors.Disabled)
		end
	end

	return panel
end

return ShopPanel
