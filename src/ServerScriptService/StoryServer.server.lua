--[[
	StoryServer  (Script dans ServerScriptService)

	Gère tout ce qui doit être sécurisé côté serveur :
	- les dialogues des PNJ (Workspace > NPCs)
	- les quêtes et les récompenses
	- les zones (Workspace > Zones)
	- les objets à ramasser (Workspace > Collectibles)
	- la sauvegarde des joueurs (DataStore)

	L'histoire elle-même se modifie dans ServerStorage > StoryConfig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ServerStorage:WaitForChild("StoryConfig"))

-- Remotes (communication serveur <-> client) -----------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "StoryRemotes"

local function newRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local dialogueEvent = newRemote("Dialogue")
local questEvent = newRemote("Quests")
local notifyEvent = newRemote("Notify")
local zoneEvent = newRemote("Zone")

remotes.Parent = ReplicatedStorage

-- Données des joueurs -----------------------------------------------------------

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local sessions = {} -- [player] = { data, loaded, canSave, dialogue, zone, readyCache }
local npcModels = {} -- [idPNJ] = modèle dans Workspace

local function defaultData()
	return {
		coins = Config.StartingCoins,
		quests = {}, -- [idQuete] = { status = "active" | "done" }
		inventory = {}, -- [objet] = quantité
		zones = {}, -- [zone] = true
	}
end

local function loadData(player)
	local ok, result = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if not ok then
		warn("[Story] Impossible de charger les données de " .. player.Name .. " : " .. tostring(result))
		warn("[Story] Dans Studio : Accueil > Paramètres du jeu > Sécurité > active « Enable Studio Access to API Services ».")
		-- On ne sauvegardera pas ce joueur pour ne pas écraser sa vraie sauvegarde.
		return defaultData(), false
	end

	local data = result or defaultData()
	for key, value in pairs(defaultData()) do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data, true
end

local function saveData(player, session)
	if not session.loaded or not session.canSave then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, session.data)
	end)
	if not ok then
		warn("[Story] Échec de la sauvegarde de " .. player.Name .. " : " .. tostring(err))
	end
end

-- Outils ---------------------------------------------------------------------------

local function formatText(text, player)
	return (string.gsub(text or "", "{player}", function()
		return player.DisplayName
	end))
end

local function notify(player, message)
	notifyEvent:FireClient(player, message)
end

local function updateCoinsDisplay(player, session)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild(Config.CurrencyName)
	if coinsValue then
		coinsValue.Value = session.data.coins
	end
end

local function addCoins(player, session, amount)
	session.data.coins += amount
	updateCoinsDisplay(player, session)
end

local function itemLabel(itemName, amount)
	local def = Config.Items[itemName] or {}
	if amount > 1 then
		return def.plural or def.displayName or itemName
	end
	return def.displayName or itemName
end

-- Quêtes ----------------------------------------------------------------------------

local function isObjectiveMet(session, questDef)
	local objective = questDef.objective or { type = "talk" }
	if objective.type == "collect" then
		return (session.data.inventory[objective.item] or 0) >= (objective.amount or 1)
	elseif objective.type == "visit" then
		return session.data.zones[objective.zone] == true
	end
	-- "talk" : la quête se termine directement dans un dialogue
	return true
end

local function questStatus(session, questId)
	local quest = session.data.quests[questId]
	local def = Config.Quests[questId]
	if not quest or not def then
		return "none"
	elseif quest.status == "done" then
		return "done"
	elseif isObjectiveMet(session, def) then
		return "ready"
	end
	return "active"
end

local function progressText(session, def, ready)
	local objective = def.objective or { type = "talk" }
	if objective.type == "talk" then
		return def.readyHint or def.description or ""
	elseif ready then
		return def.readyHint or "Objectif terminé ! Retourne voir le PNJ."
	elseif objective.type == "collect" then
		local amount = objective.amount or 1
		local have = math.min(session.data.inventory[objective.item] or 0, amount)
		return string.format("%s : %d/%d", itemLabel(objective.item, amount), have, amount)
	elseif objective.type == "visit" then
		local zone = Config.Zones[objective.zone]
		return "Explorer : " .. ((zone and zone.title) or objective.zone)
	end
	return def.description or ""
end

local function sendQuests(player, session)
	local list = {}
	for questId, quest in pairs(session.data.quests) do
		local def = Config.Quests[questId]
		if def and quest.status == "active" then
			local ready = isObjectiveMet(session, def)
			table.insert(list, {
				title = def.title or questId,
				progress = progressText(session, def, ready),
				ready = ready,
				order = def.order or 0,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	questEvent:FireClient(player, list)
end

-- Vérifie si un objectif vient d'être rempli et prévient le joueur.
local function checkObjectives(player, session, silent)
	for questId, quest in pairs(session.data.quests) do
		local def = Config.Quests[questId]
		if def and quest.status == "active" then
			local ready = isObjectiveMet(session, def)
			local objectiveType = (def.objective or {}).type or "talk"
			if ready and not session.readyCache[questId] and not silent and objectiveType ~= "talk" then
				notify(player, "Objectif terminé : " .. (def.title or questId))
			end
			session.readyCache[questId] = ready
		end
	end
	sendQuests(player, session)
end

local function startQuest(player, session, questId)
	local def = Config.Quests[questId]
	if not def then
		warn("[Story] Quête inconnue : " .. tostring(questId))
		return false
	end
	if session.data.quests[questId] then
		return false -- déjà commencée ou terminée
	end
	session.data.quests[questId] = { status = "active" }
	notify(player, "Nouvelle quête : " .. (def.title or questId))
	checkObjectives(player, session)
	return true
end

local function completeQuest(player, session, questId)
	local def = Config.Quests[questId]
	if not def or questStatus(session, questId) ~= "ready" then
		return false
	end

	local objective = def.objective or {}
	if objective.type == "collect" and objective.consume ~= false then
		local inventory = session.data.inventory
		inventory[objective.item] = math.max((inventory[objective.item] or 0) - (objective.amount or 1), 0)
	end

	session.data.quests[questId].status = "done"
	session.readyCache[questId] = nil

	local reward = def.reward or {}
	local message = "Quête terminée : " .. (def.title or questId)
	if reward.coins and reward.coins > 0 then
		addCoins(player, session, reward.coins)
		message ..= string.format(" (+%d %s)", reward.coins, Config.CurrencyName)
	end
	for itemName, amount in pairs(reward.items or {}) do
		session.data.inventory[itemName] = (session.data.inventory[itemName] or 0) + amount
	end
	notify(player, message)

	if def.nextQuest then
		startQuest(player, session, def.nextQuest)
	end
	checkObjectives(player, session)
	return true
end

-- Ce que les fonctions "start" et "condition" du StoryConfig peuvent lire.
local function makeState(session)
	return {
		quest = function(questId)
			return questStatus(session, questId)
		end,
		item = function(itemName)
			return session.data.inventory[itemName] or 0
		end,
		coins = function()
			return session.data.coins
		end,
		visited = function(zoneName)
			return session.data.zones[zoneName] == true
		end,
	}
end

-- Dialogues -------------------------------------------------------------------------

local function endDialogue(player, session)
	if session.dialogue then
		session.dialogue = nil
		dialogueEvent:FireClient(player, nil)
	end
end

local function showNode(player, session, npcId, nodeId)
	local npcDef = Config.NPCs[npcId]
	local node = npcDef and npcDef.nodes[nodeId]
	if not node then
		warn(string.format("[Story] Noeud de dialogue introuvable : %s.%s", tostring(npcId), tostring(nodeId)))
		endDialogue(player, session)
		return
	end

	local state = makeState(session)
	local visibleChoices = {}
	local labels = {}
	for _, choice in ipairs(node.choices or {}) do
		if not choice.condition or choice.condition(state) then
			table.insert(visibleChoices, choice)
			table.insert(labels, formatText(choice.text, player))
		end
	end
	if #visibleChoices == 0 then
		visibleChoices = { { text = "Au revoir" } }
		labels = { "Au revoir" }
	end

	session.dialogue = { npc = npcId, choices = visibleChoices }
	dialogueEvent:FireClient(player, {
		name = npcDef.displayName or npcId,
		text = formatText(node.text, player),
		choices = labels,
	})
end

local function startDialogue(player, npcId)
	local session = sessions[player]
	local npcDef = Config.NPCs[npcId]
	if not session or not session.loaded or not npcDef then
		return
	end
	local nodeId = "start"
	if npcDef.start then
		nodeId = npcDef.start(makeState(session))
	end
	showNode(player, session, npcId, nodeId)
end

local function getRootPart(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isNearNpc(player, npcId)
	local model = npcModels[npcId]
	local root = getRootPart(player)
	if not model or not model.Parent or not root then
		return false
	end
	return (model:GetPivot().Position - root.Position).Magnitude <= Config.MaxTalkDistance
end

dialogueEvent.OnServerEvent:Connect(function(player, choiceIndex)
	local session = sessions[player]
	if not session or not session.dialogue then
		return
	end
	-- 0 (ou n'importe quoi d'invalide) = le joueur ferme le dialogue
	if type(choiceIndex) ~= "number" or choiceIndex == 0 then
		endDialogue(player, session)
		return
	end

	local dialogue = session.dialogue
	local choice = dialogue.choices[choiceIndex]
	if not choice or not isNearNpc(player, dialogue.npc) then
		endDialogue(player, session)
		return
	end

	local action = choice.action
	if action then
		if action.startQuest then
			startQuest(player, session, action.startQuest)
		end
		if action.completeQuest and not completeQuest(player, session, action.completeQuest) then
			notify(player, "Tu n'as pas encore terminé cet objectif.")
			endDialogue(player, session)
			return
		end
		if action.giveCoins then
			addCoins(player, session, action.giveCoins)
		end
	end

	if choice.next then
		showNode(player, session, dialogue.npc, choice.next)
	else
		endDialogue(player, session)
	end
end)

-- PNJ (Workspace > NPCs) ------------------------------------------------------------------

local function findMainPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	return instance.PrimaryPart
		or instance:FindFirstChild("HumanoidRootPart")
		or instance:FindFirstChild("Head")
		or instance:FindFirstChildWhichIsA("BasePart", true)
end

local function setupNpc(model)
	local npcId = model.Name
	local npcDef = Config.NPCs[npcId]
	if not npcDef then
		warn("[Story] Aucun dialogue dans StoryConfig pour le PNJ « " .. npcId .. " »")
		return
	end
	local part = findMainPart(model)
	if not part then
		warn("[Story] Le PNJ « " .. npcId .. " » n'a aucune Part")
		return
	end

	npcModels[npcId] = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Parler"
	prompt.ObjectText = npcDef.displayName or npcId
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.TalkDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		startDialogue(player, npcId)
	end)
end

-- Objets à ramasser (Workspace > Collectibles) ------------------------------------------

local function setVisible(instance, visible)
	local parts = instance:GetDescendants()
	table.insert(parts, instance)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			if part:GetAttribute("StoryTransparency") == nil then
				part:SetAttribute("StoryTransparency", part.Transparency)
			end
			part.Transparency = visible and part:GetAttribute("StoryTransparency") or 1
		end
	end
end

local function setupCollectible(instance)
	local itemName = instance:GetAttribute("Item") or instance.Name
	local def = Config.Items[itemName]
	if not def then
		warn("[Story] Objet inconnu dans StoryConfig.Items : « " .. itemName .. " »")
		return
	end
	local part = findMainPart(instance)
	if not part then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Ramasser"
	prompt.ObjectText = def.displayName or itemName
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		local session = sessions[player]
		if not session or not session.loaded or not prompt.Enabled then
			return
		end

		if def.requiresQuest then
			local status = questStatus(session, def.requiresQuest)
			if status == "ready" then
				notify(player, "Tu en as déjà assez !")
				return
			elseif status ~= "active" then
				notify(player, "Tu n'en as pas besoin pour l'instant.")
				return
			end
		end

		prompt.Enabled = false
		setVisible(instance, false)

		local inventory = session.data.inventory
		inventory[itemName] = (inventory[itemName] or 0) + 1
		notify(player, "+1 " .. (def.displayName or itemName))
		checkObjectives(player, session)

		task.delay(def.respawnTime or 30, function()
			setVisible(instance, true)
			prompt.Enabled = true
		end)
	end)
end

-- Zones (Workspace > Zones) ------------------------------------------------------------------

local function isInsidePart(part, position)
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function enterZone(player, session, zoneName)
	local def = Config.Zones[zoneName] or {}
	zoneEvent:FireClient(player, def.title or zoneName, def.subtitle)
	if not session.data.zones[zoneName] then
		session.data.zones[zoneName] = true
		checkObjectives(player, session)
	end
end

local function updatePlayers()
	local zonesFolder = workspace:FindFirstChild("Zones")
	for player, session in pairs(sessions) do
		local root = getRootPart(player)
		if session.loaded and root then
			if zonesFolder then
				local currentZone = nil
				for _, part in ipairs(zonesFolder:GetChildren()) do
					if part:IsA("BasePart") and isInsidePart(part, root.Position) then
						currentZone = part.Name
						break
					end
				end
				if currentZone ~= session.zone then
					session.zone = currentZone
					if currentZone then
						enterZone(player, session, currentZone)
					end
				end
			end

			-- Ferme le dialogue si le joueur s'éloigne du PNJ
			if session.dialogue and not isNearNpc(player, session.dialogue.npc) then
				endDialogue(player, session)
			end
		end
	end
end

-- Connexion / déconnexion des joueurs -------------------------------------------------

local function onPlayerAdded(player)
	if sessions[player] then
		return
	end
	local session = { loaded = false, readyCache = {} }
	sessions[player] = session

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = Config.CurrencyName
	coinsValue.Parent = leaderstats
	leaderstats.Parent = player

	local data, canSave = loadData(player)
	if sessions[player] ~= session then
		return -- le joueur est parti pendant le chargement
	end
	session.data = data
	session.canSave = canSave
	session.loaded = true

	updateCoinsDisplay(player, session)
	checkObjectives(player, session, true)
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		saveData(player, session)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	local pending = 0
	for player, session in pairs(sessions) do
		pending += 1
		task.spawn(function()
			saveData(player, session)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)

-- Mise en place du monde -----------------------------------------------------------------

local function watchFolder(folderName, setup)
	local folder = workspace:WaitForChild(folderName, 5)
	if not folder then
		warn("[Story] Dossier Workspace > " .. folderName .. " introuvable (ignoré)")
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		setup(child)
	end
	folder.ChildAdded:Connect(setup)
end

task.spawn(watchFolder, "NPCs", setupNpc)
task.spawn(watchFolder, "Collectibles", setupCollectible)

task.spawn(function()
	while true do
		task.wait(0.5)
		updatePlayers()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player, session in pairs(sessions) do
			task.spawn(saveData, player, session)
		end
	end
end)
