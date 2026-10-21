--[[
	UpgradesPanel.luau  —  la fenêtre « Améliorations »
	===================================================
	Une ligne par amélioration de Config.Upgrades, avec :
	  - le niveau actuel (ex : Niv. 3/30) ;
	  - l'effet actuel → l'effet au prochain niveau ;
	  - le prix du prochain niveau (ou « MAX »).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local UIKit = require(script.Parent.Parent.UIKit)
local PanelBase = require(script.Parent.PanelBase)

local UpgradesPanel = {}

-- Décrit l'effet d'une amélioration à un niveau donné (texte court)
local function describeEffect(upgrade, level: number): string
	if upgrade.Id == "BigSpoon" then
		return "+" .. (Config.Monster.BaseSizePerClick + level * upgrade.SizePerLevel) .. "/clic"
	elseif upgrade.Id == "ElasticStomach" then
		return Format.multiplier(upgrade.IncomeMultiplierPerLevel ^ level) .. " revenus"
	elseif upgrade.Id == "AutoFeeder" then
		if level == 0 then
			return "inactif"
		end
		return "toutes les " .. upgrade.IntervalsByLevel[math.min(level, #upgrade.IntervalsByLevel)] .. " s"
	end
	return "niveau " .. level
end

function UpgradesPanel.create(screenGui: ScreenGui)
	local panel = PanelBase.new(screenGui, {
		Name = "Ameliorations",
		Title = "Améliorations",
		Icon = "⚡",
		Color = UIKit.Colors.Upgrades,
	})

	local buyUpgrade = Remotes.event("BuyUpgrade")
	local rows = {}

	for order, upgrade in Config.Upgrades do
		local row = PanelBase.createRow(panel.Content, order, function()
			buyUpgrade:FireServer(upgrade.Id)
		end)
		row.Icon.Text = upgrade.Icon
		rows[upgrade.Id] = row
	end

	function panel.update(state)
		for _, upgrade in Config.Upgrades do
			local row = rows[upgrade.Id]
			local level = state.Upgrades[upgrade.Id] or 0
			local cost = Formulas.upgradeCost(upgrade.Id, level)

			row.Title.Text = `{upgrade.Name}  (Niv. {level}/{upgrade.MaxLevel})`
			if cost then
				row.Subtitle.Text = describeEffect(upgrade, level) .. "  →  " .. describeEffect(upgrade, level + 1)
				row.Button.Text = Format.number(cost) .. " 💰"
				UIKit.setButtonColor(row.Button, if state.Coins >= cost then UIKit.Colors.Success else UIKit.Colors.Disabled)
			else
				row.Subtitle.Text = describeEffect(upgrade, level) .. "  (maximum !)"
				row.Button.Text = "MAX ⭐"
				UIKit.setButtonColor(row.Button, UIKit.Colors.Coins)
			end
		end
	end

	return panel
end

return UpgradesPanel
