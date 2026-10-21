--[[
	StorePanel.luau  —  la fenêtre « Boutique Robux » 💎
	====================================================
	  - Gamepass VIP et Auto-nourrisseur turbo (« Possédé ✔ » si tu les as) ;
	  - packs de pièces (le nombre de pièces grandit avec tes revenus).

	Le client ouvre seulement la fenêtre d'achat officielle de Roblox.
	C'est le SERVEUR (MonetizationService) qui donne les récompenses,
	une fois que Roblox a confirmé le paiement.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)

local UIKit = require(script.Parent.Parent.UIKit)
local RobuxPrices = require(script.Parent.Parent.RobuxPrices)
local PanelBase = require(script.Parent.PanelBase)

local StorePanel = {}

local PASS_ORDER = { "VIP", "TurboFeeder" }

function StorePanel.create(screenGui: ScreenGui)
	local panel = PanelBase.new(screenGui, {
		Name = "BoutiqueRobux",
		Title = "Boutique Robux",
		Icon = "💎",
		Color = UIKit.Colors.Store,
	})

	local player = Players.LocalPlayer
	local passRows = {}
	local passPrices = {}
	local ownedPasses = {}
	local packRows = {}
	local order = 0

	-- Les gamepass
	for _, passName in PASS_ORDER do
		local pass = Config.Monetization.GamePasses[passName]
		order += 1
		local row = PanelBase.createRow(panel.Content, order, function()
			if not ownedPasses[passName] then -- déjà possédé : rien à acheter
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
		row.Icon.Text = pass.Icon
		row.Title.Text = pass.Name
		row.Subtitle.Text = pass.Description
		row.Subtitle.TextWrapped = true
		passRows[passName] = row
		passPrices[passName] = pass.RobuxPrice
		RobuxPrices.get(pass.Id, Enum.InfoType.GamePass, pass.RobuxPrice, function(price)
			passPrices[passName] = price
		end)
	end

	-- Les packs de pièces
	for _, pack in Config.Monetization.CoinPacks do
		order += 1
		local row = PanelBase.createRow(panel.Content, order, function()
			MarketplaceService:PromptProductPurchase(player, pack.Id)
		end)
		row.Icon.Text = pack.Icon
		row.Title.Text = pack.Name
		UIKit.setButtonColor(row.Button, UIKit.Colors.Store)
		RobuxPrices.get(pack.Id, Enum.InfoType.Product, pack.RobuxPrice, function(price)
			row.Button.Text = "R$ " .. price
		end)
		packRows[pack.Id] = row
	end

	function panel.update(state)
		for _, passName in PASS_ORDER do
			local row = passRows[passName]
			ownedPasses[passName] = state.Passes[passName]
			if state.Passes[passName] then
				row.Button.Text = "Possédé ✔"
				UIKit.setButtonColor(row.Button, UIKit.Colors.Coins)
			else
				row.Button.Text = "R$ " .. passPrices[passName]
				UIKit.setButtonColor(row.Button, UIKit.Colors.Store)
			end
		end
		for _, pack in Config.Monetization.CoinPacks do
			local coins = Formulas.coinPackAmount(pack, state.IncomePerSecond)
			packRows[pack.Id].Subtitle.Text = "+" .. Format.number(coins) .. " pièces 💰"
		end
	end

	return panel
end

return StorePanel
