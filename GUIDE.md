# Guide d'installation dans Roblox Studio

Ce jeu d'histoire / roleplay contient :

- des **PNJ qui parlent** avec des choix de réponses
- des **quêtes** (parler à quelqu'un, ramasser des objets, explorer une zone)
- des **zones** dont le nom s'affiche quand on y entre
- des **objets à ramasser** qui réapparaissent
- une **monnaie** (Pièces) affichée dans le classement
- la **sauvegarde** automatique de la progression

Toute l'interface (boîte de dialogue, liste des quêtes, notifications) est créée par le code : tu n'as aucune GUI à dessiner.

---

## 1. Copier les 3 scripts

Ouvre la fenêtre **Explorer** (onglet *Affichage* > *Explorer*).

| Fichier du dépôt | Où le mettre dans Studio | Type d'objet | Nom exact |
|---|---|---|---|
| `src/ServerStorage/StoryConfig.lua` | **ServerStorage** | ModuleScript | `StoryConfig` |
| `src/ServerScriptService/StoryServer.server.lua` | **ServerScriptService** | Script | `StoryServer` |
| `src/StarterPlayer/StarterPlayerScripts/StoryClient.client.lua` | **StarterPlayer > StarterPlayerScripts** | LocalScript | `StoryClient` |

Pour chacun : clic droit sur le dossier > **Insert Object** > choisis le type, renomme-le, ouvre-le, efface le code par défaut et colle le contenu du fichier.

> ⚠️ Le type compte : `StoryConfig` doit être un **ModuleScript**, `StoryClient` un **LocalScript**.

## 2. Créer les dossiers dans Workspace

Dans **Workspace**, crée 3 dossiers (clic droit > Insert Object > **Folder**) :

- `NPCs`
- `Zones`
- `Collectibles`

## 3. Ajouter les PNJ

1. Onglet **Avatar** > **Rig Builder** > choisis un personnage (R15 par exemple).
2. Renomme le modèle avec le nom du PNJ dans `StoryConfig` : `Elias`, `Lea` ou `Bruno`.
3. Glisse-le dans le dossier `Workspace > NPCs`.
4. Sélectionne sa partie **HumanoidRootPart** et coche **Anchored** (sinon il peut tomber).

Quand tu lances le jeu, un bouton **« Parler [E] »** apparaît près du PNJ.

## 4. Créer les zones

1. Insère une **Part** et agrandis-la pour couvrir toute la zone (le village, la forêt…).
2. Renomme-la `Village` ou `Foret` (sans accent, comme dans `StoryConfig`).
3. Propriétés : **Anchored** ✅, **CanCollide** ❌, **Transparency** = `1`.
4. Glisse-la dans `Workspace > Zones`.

## 5. Placer les objets à ramasser

1. Insère une petite **Part** (ou un modèle de fleur de la Toolbox).
2. Renomme-la `Fleur` et coche **Anchored**.
3. Glisse-la dans `Workspace > Collectibles`.
4. Places-en au moins 3 (la quête en demande 3).

## 6. Activer la sauvegarde

La sauvegarde utilise les DataStores de Roblox :

1. Publie le jeu (*Fichier* > *Publier sur Roblox*).
2. *Accueil* > **Paramètres du jeu** > **Sécurité** > active **Enable Studio Access to API Services**.

Sans ça, le jeu marche quand même, mais rien n'est sauvegardé (un message l'indique dans la fenêtre *Output*).

## 7. Tester

Clique sur **Play**. L'histoire de démo :

1. Parle à **Elias** → il t'envoie voir Léa.
2. Parle à **Léa** → elle te demande 3 fleurs.
3. Ramasse 3 **Fleurs**, puis retourne voir Léa → +50 Pièces.
4. Parle à **Bruno** → il t'envoie dans la **Forêt**.
5. Entre dans la zone Foret, retourne voir Bruno → +75 Pièces.
6. Retourne voir Elias pour la fin de la démo.

Si quelque chose ne marche pas, regarde la fenêtre **Output** : les messages `[Story]` disent ce qui manque (PNJ sans dialogue, dossier introuvable, etc.).

---

## Écrire ta propre histoire

Tout se passe dans **`StoryConfig`**. Tu n'as pas besoin de toucher aux deux autres scripts.

### Ajouter un PNJ

```lua
Config.NPCs.Marchand = {
	displayName = "Le marchand",
	start = function(s)
		return "bonjour"
	end,
	nodes = {
		bonjour = {
			text = "Bienvenue dans ma boutique, {player} !",
			choices = {
				{ text = "Je peux avoir un cadeau ?", next = "cadeau", action = { giveCoins = 5 } },
				{ text = "Au revoir." },
			},
		},
		cadeau = { text = "Tiens, 5 pièces. Ne le dis à personne !" },
	},
}
```

Puis mets un modèle nommé `Marchand` dans `Workspace > NPCs`.

### Ajouter une quête

```lua
Config.Quests.tresor = {
	order = 4,
	title = "Le trésor caché",
	description = "Trouve la grotte secrète.",
	objective = { type = "visit", zone = "Grotte" },
	readyHint = "Retourne voir le marchand.",
	reward = { coins = 100 },
}
```

Types d'objectifs : `"talk"` (se termine dans un dialogue), `"collect"` (ramasser des objets), `"visit"` (entrer dans une zone).

### Utiliser la progression dans un dialogue

Dans `start` et dans `condition`, la variable `s` permet de tester où en est le joueur :

| Code | Renvoie |
|---|---|
| `s.quest("fleurs")` | `"none"`, `"active"`, `"ready"` (objectif rempli) ou `"done"` |
| `s.item("Fleur")` | le nombre de fleurs dans l'inventaire |
| `s.coins()` | le nombre de pièces |
| `s.visited("Foret")` | `true` si le joueur est déjà allé dans la forêt |

Exemple de choix visible seulement si le joueur est riche :

```lua
{ text = "Acheter l'épée (100 pièces)", condition = function(s) return s.coins() >= 100 end, next = "achat" },
```
