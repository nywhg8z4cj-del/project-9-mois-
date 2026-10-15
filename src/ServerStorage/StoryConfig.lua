--[[
	StoryConfig  (ModuleScript dans ServerStorage)

	C'est ICI que tu écris ton histoire : les PNJ, leurs dialogues, les quêtes,
	les zones et les objets à ramasser. Les autres scripts lisent ce fichier,
	tu n'as normalement pas besoin d'y toucher.

	Dans les textes, {player} est remplacé par le nom du joueur.

	Dans les fonctions "start" et "condition", la variable s te permet de
	connaître la progression du joueur :
		s.quest("idQuete")   -> "none" | "active" | "ready" | "done"
		                        ("ready" = objectif rempli, il reste à rendre la quête)
		s.item("Fleur")      -> nombre d'objets "Fleur" dans l'inventaire
		s.coins()            -> nombre de pièces
		s.visited("Foret")   -> true si le joueur est déjà entré dans la zone
]]

local Config = {}

-- Réglages généraux ----------------------------------------------------------

Config.DataStoreName = "StoryData_v1" -- change le nom pour remettre toutes les sauvegardes à zéro
Config.CurrencyName = "Pièces"        -- nom affiché dans le classement (leaderstats)
Config.StartingCoins = 0
Config.TalkDistance = 10              -- distance (en studs) pour parler à un PNJ
Config.MaxTalkDistance = 20           -- au-delà, le dialogue se ferme tout seul
Config.AutosaveInterval = 120         -- sauvegarde automatique (en secondes)

-- Quêtes -----------------------------------------------------------------------
--[[
	objective.type :
		"talk"    -> se termine en parlant à un PNJ (via completeQuest dans un dialogue)
		"collect" -> ramasser "amount" objets "item"
		"visit"   -> entrer dans la zone "zone"
	reward : { coins = 50, items = { Cle = 1 } }   (tout est facultatif)
	nextQuest : quête lancée automatiquement quand celle-ci est terminée
	order : ordre d'affichage dans la liste des quêtes
]]

Config.Quests = {
	bienvenue = {
		order = 1,
		title = "Bienvenue au village",
		description = "Va saluer Léa, la fleuriste.",
		objective = { type = "talk" },
		reward = { coins = 10 },
	},

	fleurs = {
		order = 2,
		title = "Un bouquet pour Léa",
		description = "Cueille 3 fleurs autour du village.",
		objective = { type = "collect", item = "Fleur", amount = 3 },
		readyHint = "Rapporte les fleurs à Léa.",
		reward = { coins = 50 },
	},

	foret = {
		order = 3,
		title = "La forêt mystérieuse",
		description = "Explore la forêt pour Bruno, le garde.",
		objective = { type = "visit", zone = "Foret" },
		readyHint = "Retourne voir Bruno pour lui raconter.",
		reward = { coins = 75 },
	},
}

-- Objets à ramasser --------------------------------------------------------------
-- Le nom doit être celui de la Part (ou du Model) dans Workspace > Collectibles.

Config.Items = {
	Fleur = {
		displayName = "Fleur",
		plural = "Fleurs",
		requiresQuest = "fleurs", -- ne peut être ramassé que pendant cette quête (facultatif)
		respawnTime = 15,         -- réapparaît après X secondes
	},
}

-- Zones ------------------------------------------------------------------------------
-- Le nom doit être celui de la Part dans Workspace > Zones.

Config.Zones = {
	Village = { title = "Village d'Aube", subtitle = "Un endroit paisible..." },
	Foret = { title = "Forêt Sombre", subtitle = "On raconte que personne n'en revient." },
}

-- PNJ et dialogues -------------------------------------------------------------------
--[[
	Le nom (ex : Elias) doit être celui du modèle dans Workspace > NPCs.

	start(s)  : renvoie le nom du premier noeud de dialogue à afficher.
	nodes     : les répliques. Chaque noeud a un "text" et des "choices".
	Un choix peut avoir :
		next      = "noeud"                   -> réplique suivante (sinon le dialogue se ferme)
		action    = { startQuest = "id" }     -> démarre une quête
		action    = { completeQuest = "id" }  -> termine une quête (si l'objectif est rempli)
		action    = { giveCoins = 10 }        -> donne des pièces
		condition = function(s) ... end       -> le choix n'apparaît que si la fonction renvoie true
	Un noeud sans choix affiche simplement un bouton "Au revoir".
]]

Config.NPCs = {
	Elias = {
		displayName = "Maître Elias",
		start = function(s)
			if s.quest("bienvenue") == "none" then
				return "intro"
			elseif s.quest("foret") == "done" then
				return "fin"
			end
			return "conseil"
		end,
		nodes = {
			intro = {
				text = "Ah, {player} ! Te voilà enfin. Bienvenue au village d'Aube.",
				choices = {
					{ text = "Merci ! Où suis-je ?", next = "explication" },
					{ text = "Je reviendrai plus tard." },
				},
			},
			explication = {
				text = "Un village bien calme... mais il se passe des choses étranges dans la forêt. Commence par aller saluer Léa, notre fleuriste.",
				choices = {
					{ text = "J'y vais !", next = "aurevoir", action = { startQuest = "bienvenue" } },
				},
			},
			aurevoir = { text = "Bonne route, {player}." },
			conseil = { text = "As-tu parlé à tout le monde ? Bruno, le garde, cherche quelqu'un de courageux." },
			fin = {
				text = "Tu es revenu de la forêt ? Tu es un vrai héros, {player} !",
				choices = {
					{ text = "Et maintenant ?", next = "suite" },
				},
			},
			suite = { text = "La suite de l'aventure reste à écrire... (Fin de la démo)" },
		},
	},

	Lea = {
		displayName = "Léa la fleuriste",
		start = function(s)
			local bienvenue = s.quest("bienvenue")
			local fleurs = s.quest("fleurs")
			if bienvenue == "none" then
				return "inconnu"
			elseif bienvenue ~= "done" then
				return "salut"
			elseif fleurs == "none" then
				return "demande"
			elseif fleurs == "active" then
				return "attente"
			elseif fleurs == "ready" then
				return "merci"
			end
			return "contente"
		end,
		nodes = {
			inconnu = { text = "Bonjour ! Tu devrais d'abord aller voir Maître Elias." },
			salut = {
				text = "Oh, bonjour ! C'est Elias qui t'envoie ? Ravie de te rencontrer, {player} !",
				choices = {
					{ text = "Enchanté !", next = "demande", action = { completeQuest = "bienvenue" } },
				},
			},
			demande = {
				text = "Dis... pourrais-tu me cueillir 3 fleurs ? Elles poussent autour du village.",
				choices = {
					{ text = "Bien sûr !", next = "ok", action = { startQuest = "fleurs" } },
					{ text = "Pas maintenant." },
				},
			},
			ok = { text = "Merci beaucoup ! Reviens me voir quand tu les auras." },
			attente = { text = "Tu as trouvé les fleurs ? Il m'en faut 3." },
			merci = {
				text = "Elles sont magnifiques ! Tiens, voilà pour ta peine.",
				choices = {
					{ text = "Avec plaisir !", next = "apres", action = { completeQuest = "fleurs" } },
				},
			},
			apres = { text = "Au fait, Bruno le garde cherche de l'aide. Va le voir à l'entrée du village !" },
			contente = { text = "Mes bouquets se vendent très bien grâce à toi !" },
		},
	},

	Bruno = {
		displayName = "Bruno le garde",
		start = function(s)
			local foret = s.quest("foret")
			if foret == "none" then
				if s.quest("fleurs") ~= "done" then
					return "occupe"
				end
				return "mission"
			elseif foret == "active" then
				return "attente"
			elseif foret == "ready" then
				return "retour"
			end
			return "respect"
		end,
		nodes = {
			occupe = { text = "Circule, je surveille l'entrée du village." },
			mission = {
				text = "Léa m'a parlé de toi. J'ai entendu des bruits bizarres dans la forêt... Tu irais jeter un oeil ?",
				choices = {
					{ text = "Je n'ai peur de rien !", next = "courage", action = { startQuest = "foret" } },
					{ text = "Euh... non merci." },
				},
			},
			courage = { text = "Sois prudent, {player}. La forêt est au bout du chemin." },
			attente = { text = "Alors, cette forêt ? Tu n'y es pas encore allé ?" },
			retour = {
				text = "Tu es revenu ! Qu'as-tu vu là-bas ?",
				choices = {
					{ text = "Rien de dangereux... pour l'instant.", next = "recompense", action = { completeQuest = "foret" } },
				},
			},
			recompense = { text = "Merci ! Va raconter ça à Maître Elias." },
			respect = { text = "Salut, l'aventurier !" },
		},
	},
}

return Config
