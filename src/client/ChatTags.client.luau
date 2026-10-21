--[[
	ChatTags.client.luau  —  le tag [VIP] doré dans le chat
	=======================================================
	Le serveur met l'attribut « IsVIP » sur les joueurs qui ont le gamepass VIP.
	Quand un message arrive dans le chat, on regarde si son auteur est VIP :
	si oui, on ajoute « [VIP] » en doré devant son nom.

	(Fonctionne avec le nouveau chat de Roblox : TextChatService.)
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")

	local source = message.TextSource
	if source then
		local author = Players:GetPlayerByUserId(source.UserId)
		if author and author:GetAttribute("IsVIP") then
			-- Les balises <font> permettent de colorer le texte (RichText)
			properties.PrefixText = "<font color='#FFC828'>[VIP]</font> " .. message.PrefixText
		end
	end

	return properties
end
