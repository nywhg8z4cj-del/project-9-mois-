--[[
	RobuxPrices.luau  —  récupère le VRAI prix en Robux d'un gamepass ou d'un produit
	=================================================================================
	Les prix se règlent sur le site Roblox (Creator Hub). Ce module demande
	le prix à Roblox pour l'afficher. Si Roblox ne répond pas (par exemple
	avec les IDs d'exemple), on affiche le prix « RobuxPrice » de Config.
]]

local MarketplaceService = game:GetService("MarketplaceService")

local RobuxPrices = {}

local cache: { [string]: number } = {}

-- infoType : Enum.InfoType.GamePass ou Enum.InfoType.Product
-- callback(prix) est appelé avec le prix trouvé (ou le prix de secours)
function RobuxPrices.get(id: number, infoType: Enum.InfoType, fallback: number, callback: (number) -> ())
	local key = infoType.Name .. id
	if cache[key] then
		callback(cache[key])
		return
	end
	callback(fallback) -- en attendant la réponse de Roblox

	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			cache[key] = info.PriceInRobux
			callback(info.PriceInRobux)
		end
	end)
end

return RobuxPrices
