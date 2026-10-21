--[[
	EventBanner.luau  —  la bannière de la « Pluie de bonbons »
	===========================================================
	Le serveur envoie des messages CandyRainEvent :
	  "announce", 10   → « Pluie de bonbons dans 10 s ! » (avec compte à rebours)
	  "start", 30      → « PLUIE DE BONBONS ! 30 s » (avec compte à rebours)
	  "end"            → la bannière disparaît
	  "collected", 7   → petit message « 🍬 +7 taille »
]]

local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)
local Notifications = require(script.Parent.Notifications)

local EventBanner = {}

local banner: Frame
local bannerText: TextLabel
local pulseTween: Tween
local currentToken = 0 -- change à chaque nouveau message, pour arrêter l'ancien compte à rebours

function EventBanner.init(screenGui: ScreenGui)
	banner = UIKit.create("Frame", {
		Name = "BanniereEvenement",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112), -- juste au-dessus du bouton NOURRIR
		Size = UDim2.fromOffset(560, 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 40,
		Parent = screenGui,
	})
	UIKit.corner(banner, 20)
	UIKit.stroke(banner, UIKit.Colors.Outline, 4)
	UIKit.create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
		}),
		Parent = banner,
	})
	UIKit.addResponsiveScale(banner)

	bannerText = UIKit.label({
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		Text = "",
		ZIndex = 41,
		Parent = banner,
	})

	-- La bannière « bat » doucement pour attirer l'œil
	local pulse = UIKit.create("UIScale", { Name = "Battement", Parent = banner })
	pulseTween = TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 })
end

-- Affiche la bannière avec un compte à rebours. makeText(secondes) donne le texte.
local function showCountdown(seconds: number, makeText: (number) -> string)
	currentToken += 1
	local myToken = currentToken
	local endTime = os.clock() + seconds

	banner.Visible = true
	pulseTween:Play()

	task.spawn(function()
		-- Tant que personne n'a envoyé un nouveau message...
		while myToken == currentToken do
			local remaining = math.max(0, math.ceil(endTime - os.clock()))
			bannerText.Text = makeText(remaining)
			if remaining <= 0 then
				break
			end
			task.wait(0.2)
		end
	end)
end

local function hide()
	currentToken += 1
	banner.Visible = false
	pulseTween:Cancel()
end

function EventBanner.handle(phase: string, value: number?)
	if not banner then
		return
	end
	if phase == "announce" then
		showCountdown(value or 10, function(s)
			return `🍬 Pluie de bonbons dans {s} s ! Va sur la place centrale !`
		end)
	elseif phase == "start" then
		Notifications.show("🍬 C'EST PARTI ! Ramasse un maximum de bonbons !", "candy")
		showCountdown(value or 30, function(s)
			return `🍬 PLUIE DE BONBONS ! Encore {s} s 🍬`
		end)
	elseif phase == "end" then
		hide()
	elseif phase == "collected" then
		Notifications.show(`🍬 Bonbon ! +{value or 0} taille`, "candy", 1.5)
	end
end

return EventBanner
