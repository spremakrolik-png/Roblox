--!strict
-- VIP in the chat: a gold "[VIP]" tag and a gold name. Ownership comes from the "Pass_VIP" player
-- attribute the server sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local VipController = {}

function VipController.start()
	local color = Monetization.VipColor:ToHex()
	local attribute = Monetization.attribute("VIP")
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local speaker = if source then Players:GetPlayerByUserId(source.UserId) else nil
		if speaker and speaker:GetAttribute(attribute) == true then
			properties.PrefixText =
				`<font color="#{color}">{Monetization.VipTag}</font> <font color="#{color}">{message.PrefixText}</font>`
		end
		return properties
	end
end

return VipController
