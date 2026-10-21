--[[
	Notifications.luau  —  les petits messages qui apparaissent à l'écran
	=====================================================================
	Exemple : Notifications.show("Achat réussi !", "success")
	Le message apparaît en haut de l'écran, puis disparaît tout seul.
]]

local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local Notifications = {}

local MAX_VISIBLE = 4 -- au-delà, les plus vieilles disparaissent

-- Couleur et son de chaque style
local STYLES = {
	info = { Color = Color3.fromRGB(70, 150, 255), Sound = nil },
	success = { Color = Color3.fromRGB(70, 195, 95), Sound = "Success" },
	error = { Color = Color3.fromRGB(230, 75, 75), Sound = "Error" },
	event = { Color = Color3.fromRGB(190, 90, 255), Sound = "Success" },
	reward = { Color = Color3.fromRGB(255, 170, 30), Sound = "Success" },
	candy = { Color = Color3.fromRGB(255, 100, 190), Sound = "Candy" },
	rebirth = { Color = Color3.fromRGB(150, 90, 255), Sound = "Rebirth" },
}

local container: Frame
local counter = 0

function Notifications.init(screenGui: ScreenGui)
	container = UIKit.create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(460, 260),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = screenGui,
	})
	UIKit.create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = container,
	})
	UIKit.addResponsiveScale(container)
end

local function removeToast(toast: CanvasGroup)
	if toast:GetAttribute("Removing") then
		return
	end
	toast:SetAttribute("Removing", true)
	local tween = TweenService:Create(toast, TweenInfo.new(0.25), { GroupTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		toast:Destroy()
	end)
end

-- Affiche une notification. style = "info", "success", "error", "event", "reward", "candy" ou "rebirth"
function Notifications.show(message: string, style: string?, duration: number?)
	if not container then
		return
	end
	local settings = STYLES[style or "info"] or STYLES.info
	counter += 1

	-- Un CanvasGroup permet de faire disparaître tout le bloc d'un coup (GroupTransparency)
	local toast = UIKit.create("CanvasGroup", {
		Name = "Toast",
		Size = UDim2.fromOffset(440, 46),
		BackgroundColor3 = settings.Color,
		GroupTransparency = 1,
		LayoutOrder = counter,
		Parent = container,
	})
	UIKit.corner(toast, 14)
	UIKit.label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = message,
		Parent = toast,
	})

	if settings.Sound then
		UIKit.playSound(settings.Sound)
	end

	-- Apparition en fondu
	TweenService:Create(toast, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()

	-- Trop de notifications ? On enlève les plus anciennes
	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("CanvasGroup") and not child:GetAttribute("Removing") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - MAX_VISIBLE do
		removeToast(toasts[i])
	end

	task.delay(duration or 3, removeToast, toast)
end

return Notifications
