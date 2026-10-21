--[[
	DailyRewardService.luau  —  le cadeau de connexion quotidienne
	==============================================================
	À la première connexion de chaque jour, le joueur reçoit des pièces.
	S'il se connecte plusieurs jours D'AFFILÉE, sa « série » augmente et
	le cadeau grossit (jusqu'à Config.DailyReward.MaxStreakDays jours).
	S'il rate un jour, la série repart à 1.

	Les jours sont comptés en heure universelle (UTC) avec os.time() :
	os.time() = nombre de secondes depuis le 1er janvier 1970.
	En divisant par 86 400 (secondes dans une journée), on obtient le numéro du jour.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Notifier = require(script.Parent.Notifier)

local DailyRewardService = {}

local SECONDS_PER_DAY = 86_400

local function getToday(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- Envoie une notification après quelques secondes (le temps que l'interface soit prête)
local function notifyLater(player: Player, delaySeconds: number, message: string, style: string)
	task.delay(delaySeconds, function()
		if player.Parent then -- le joueur est toujours là ?
			Notifier.send(player, message, style)
		end
	end)
end

local function checkDailyReward(player: Player, data)
	local today = getToday()
	local daily = data.Daily

	if daily.LastDay == today then
		-- Déjà récupéré aujourd'hui
		notifyLater(player, 4, `🎁 Reviens demain pour ton prochain cadeau ! (série : {daily.Streak} j)`, "info")
		return
	end

	-- Hier ? La série continue. Sinon, elle repart à 1.
	if daily.LastDay == today - 1 then
		daily.Streak += 1
	else
		daily.Streak = 1
	end
	daily.LastDay = today

	local income = Formulas.incomePerSecond(data, PlayerDataService.getPasses(player))
	local coins = Formulas.dailyReward(daily.Streak, income)
	PlayerDataService.addCoins(player, coins)

	local streakText = if daily.Streak > 1 then ` 🔥 Série de {daily.Streak} jours !` else ""
	notifyLater(player, 3, `🎁 Cadeau du jour : +{Format.number(coins)} pièces !{streakText}`, "reward")
	if daily.Streak < Config.DailyReward.MaxStreakDays then
		notifyLater(player, 6, "Reviens demain pour un cadeau encore plus gros ! 😄", "info")
	end
end

function DailyRewardService.start()
	PlayerDataService.onDataLoaded(checkDailyReward)
end

return DailyRewardService
