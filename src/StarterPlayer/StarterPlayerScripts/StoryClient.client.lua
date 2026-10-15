--[[
	StoryClient  (LocalScript dans StarterPlayer > StarterPlayerScripts)

	Crée l'interface du joueur (aucune GUI à construire à la main) :
	- la boîte de dialogue avec les choix
	- la liste des quêtes en cours
	- le titre de la zone quand on y entre
	- les petites notifications
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("StoryRemotes")
local dialogueEvent = remotes:WaitForChild("Dialogue")
local questEvent = remotes:WaitForChild("Quests")
local notifyEvent = remotes:WaitForChild("Notify")
local zoneEvent = remotes:WaitForChild("Zone")

local COLORS = {
	panel = Color3.fromRGB(22, 24, 34),
	button = Color3.fromRGB(45, 49, 66),
	buttonHover = Color3.fromRGB(70, 76, 100),
	accent = Color3.fromRGB(255, 200, 90),
	text = Color3.fromRGB(240, 240, 245),
	ready = Color3.fromRGB(120, 230, 140),
}
local TYPING_SPEED = 45 -- lettres par seconde

-- Petit outil pour créer des objets d'interface rapidement
local function create(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function padding(vertical, horizontal)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
	})
end

local function listLayout(spacing, horizontalAlignment)
	return create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, spacing),
		HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left,
	})
end

local gui = create("ScreenGui", {
	Name = "StoryGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Boîte de dialogue ------------------------------------------------------------------

local dialogueFrame = create("Frame", {
	Name = "Dialogue",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Visible = false,
	Parent = gui,
}, {
	corner(12),
	padding(12, 16),
	listLayout(8),
	create("UIStroke", { Color = COLORS.accent, Thickness = 2, Transparency = 0.3 }),
	create("UISizeConstraint", { MaxSize = Vector2.new(720, math.huge) }),
})

local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Parent = dialogueFrame,
})

local nameLabel = create("TextLabel", {
	Size = UDim2.new(1, -32, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = COLORS.accent,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = header,
})

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(24, 24),
	BackgroundColor3 = COLORS.button,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = COLORS.text,
	Text = "X",
	Parent = header,
}, { corner(6) })

local bodyLabel = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 18,
	TextColor3 = COLORS.text,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
	LayoutOrder = 2,
	Parent = dialogueFrame,
})

local choicesFrame = create("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 3,
	Parent = dialogueFrame,
}, { listLayout(6) })

local typingToken = 0

local function typeText(text)
	typingToken += 1
	local token = typingToken
	bodyLabel.Text = text
	bodyLabel.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(text) or #text
		for i = 1, total do
			if token ~= typingToken then
				return
			end
			bodyLabel.MaxVisibleGraphemes = i
			task.wait(1 / TYPING_SPEED)
		end
		bodyLabel.MaxVisibleGraphemes = -1
	end)
end

local function clearChoices()
	for _, child in ipairs(choicesFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function closeDialogue()
	typingToken += 1
	dialogueFrame.Visible = false
	clearChoices()
end

local function choose(index)
	clearChoices() -- évite les doubles clics en attendant la réponse du serveur
	dialogueEvent:FireServer(index)
end

local function showDialogue(data)
	if not data then
		closeDialogue()
		return
	end

	nameLabel.Text = data.name
	typeText(data.text)
	clearChoices()

	for index, label in ipairs(data.choices) do
		local button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = COLORS.button,
			AutoButtonColor = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 17,
			TextColor3 = COLORS.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%d. %s", index, label),
			LayoutOrder = index,
			Parent = choicesFrame,
		}, { corner(8), padding(0, 12) })

		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = COLORS.buttonHover
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = COLORS.button
		end)
		button.Activated:Connect(function()
			choose(index)
		end)
	end

	dialogueFrame.Visible = true
end

closeButton.Activated:Connect(function()
	closeDialogue()
	dialogueEvent:FireServer(0)
end)

dialogueEvent.OnClientEvent:Connect(showDialogue)

-- Liste des quêtes ---------------------------------------------------------------------

local questFrame = create("Frame", {
	Name = "Quests",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0.25, 0),
	Size = UDim2.fromOffset(250, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.25,
	Visible = false,
	Parent = gui,
}, {
	corner(10),
	padding(10, 12),
	listLayout(8),
	create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Quêtes",
		LayoutOrder = 0,
	}),
})

local function textLine(text, font, size, color, order)
	return create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		LayoutOrder = order,
	})
end

questEvent.OnClientEvent:Connect(function(quests)
	for _, child in ipairs(questFrame:GetChildren()) do
		if child.Name == "Quest" then
			child:Destroy()
		end
	end

	for index, quest in ipairs(quests) do
		create("Frame", {
			Name = "Quest",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = questFrame,
		}, {
			listLayout(2),
			textLine(quest.title, Enum.Font.GothamBold, 15, COLORS.text, 1),
			textLine(
				(quest.ready and "✓ " or "• ") .. quest.progress,
				Enum.Font.Gotham,
				14,
				quest.ready and COLORS.ready or COLORS.text,
				2
			),
		})
	end

	questFrame.Visible = #quests > 0
end)

-- Notifications --------------------------------------------------------------------------

local toastHolder = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.9, 0, 0, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, { listLayout(6, Enum.HorizontalAlignment.Center) })

local toastCount = 0

notifyEvent.OnClientEvent:Connect(function(message)
	toastCount += 1
	local toast = create("TextLabel", {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = COLORS.text,
		Text = message,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, { corner(8), padding(8, 14) })

	task.delay(3, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
		toast:Destroy()
	end)
end)

-- Titre de zone ----------------------------------------------------------------------------

local zoneTitle = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.18, 0),
	Size = UDim2.new(0.9, 0, 0, 50),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 42,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Text = "",
	Parent = gui,
})

local zoneSubtitle = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.18, 54),
	Size = UDim2.new(0.9, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	TextSize = 20,
	TextColor3 = COLORS.accent,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Text = "",
	Parent = gui,
})

local zoneToken = 0

local function fadeZone(visible)
	local info = TweenInfo.new(0.6)
	local goal = {
		TextTransparency = visible and 0 or 1,
		TextStrokeTransparency = visible and 0.5 or 1,
	}
	TweenService:Create(zoneTitle, info, goal):Play()
	TweenService:Create(zoneSubtitle, info, goal):Play()
end

zoneEvent.OnClientEvent:Connect(function(title, subtitle)
	zoneToken += 1
	local token = zoneToken
	zoneTitle.Text = title
	zoneSubtitle.Text = subtitle or ""
	fadeZone(true)
	task.delay(3, function()
		if token == zoneToken then
			fadeZone(false)
		end
	end)
end)
