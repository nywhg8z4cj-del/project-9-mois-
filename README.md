# 👾 Grow a Giant

Un jeu Roblox fun, coloré et un peu absurde : chaque joueur nourrit son petit monstre
pour le faire grandir. Plus il est gros, plus il rapporte de pièces.
Le but : avoir **le plus gros monstre du serveur** ! (Aucune violence, juste beaucoup de nourriture.)

Le code est écrit en **Luau** et synchronisé avec Roblox Studio grâce à **Rojo**.
Tous les scripts sont commentés en français.

---

## 📁 Organisation du projet

```
default.project.json   ← dit à Rojo où mettre chaque dossier dans Roblox Studio
rokit.toml             ← la version de Rojo à installer
src/
  shared/   → ReplicatedStorage.Shared     (modules lus par le serveur ET le client)
    Config.luau      ← ⭐ TOUS les réglages du jeu (prix, gains, durées...)
    Formulas.luau    ← toutes les formules de calcul (revenus, prix...)
    Format.luau      ← affichage joli des nombres (1500 → "1.5K")
    Remotes.luau     ← crée/retrouve les RemoteEvents et RemoteFunctions
    Types.luau       ← description des données (typage Luau)
  server/   → ServerScriptService.Server   (scripts SERVEUR : c'est lui qui décide)
    Main.server.luau ← le point de départ du serveur
    Services/        ← un module par fonctionnalité (parcelles, monstre, boutique...)
  client/   → StarterPlayerScripts.Client  (scripts CLIENT : effets visuels)
  gui/      → StarterGui                   (l'interface à l'écran)
```

Le nom du fichier indique le type de script créé dans Studio :

| Fichier             | Devient dans Studio |
|---------------------|---------------------|
| `Nom.server.luau`   | `Script` (serveur)  |
| `Nom.client.luau`   | `LocalScript` (client) |
| `Nom.luau`          | `ModuleScript` (module qu'on charge avec `require`) |
| `init.meta.json`    | change le type d'un dossier (ici, en `ScreenGui`) |

### 🛡️ La règle d'or anti-triche

Le **serveur décide de tout** (pièces, taille, achats). Le client (l'ordinateur du joueur)
envoie seulement des **demandes** par RemoteEvent (« je veux acheter une pizza »), et le
serveur **vérifie** chaque demande : valeur valide ? assez de pièces ? pas trop rapide ?
Un tricheur peut modifier son client, mais jamais le serveur.

---

## 🔧 Installer Rojo (une seule fois)

Rojo copie automatiquement les fichiers de ce dossier dans Roblox Studio, en direct.

### 1. Installer un éditeur de code (recommandé)
1. Installe **Visual Studio Code** : <https://code.visualstudio.com>
2. Dans VS Code, onglet *Extensions* (les 4 carrés à gauche), installe :
   - **Luau Language Server** (de JohnnyMorganz) : couleurs, autocomplétion, erreurs.
   - **Rojo** (de evaera) : facultatif, ajoute des boutons pour Rojo.
3. *File > Open Folder* → ouvre le dossier de ce projet.

### 2. Installer Rojo (le programme « CLI »)
Le plus simple est d'utiliser **Rokit**, un installateur d'outils Roblox.

- **Windows** : ouvre *PowerShell* et colle :
  ```powershell
  Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
  ```
- **Mac / Linux** : ouvre le *Terminal* et colle :
  ```bash
  curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
  ```

Ferme puis rouvre le terminal. Ensuite, **dans le dossier du projet** (dans VS Code :
menu *Terminal > New Terminal*), tape :

```bash
rokit install
rojo --version
```

Tu dois voir `Rojo 7.4.4`. 🎉

> Plan B sans Rokit : télécharge le fichier `.zip` pour ton système sur
> <https://github.com/rojo-rbx/rojo/releases/tag/v7.4.4>, extrais `rojo.exe` (ou `rojo`)
> et place-le dans le dossier du projet. Tape alors `./rojo` au lieu de `rojo`.

### 3. Installer le plugin Rojo dans Roblox Studio
Ferme Roblox Studio, puis tape dans le terminal :

```bash
rojo plugin install
```

Rouvre Roblox Studio : un onglet **Rojo** apparaît dans l'onglet *Plugins*.
(Tu peux aussi installer le plugin « Rojo » depuis la Creator Store, mais la version
installée par la commande correspond toujours à ta version de Rojo.)

### 4. Lancer la synchronisation (à chaque séance de travail)
1. Dans Roblox Studio : *New* > modèle **Baseplate**, puis *File > Save to Roblox*
   (ou *Save to File*). Le jeu remplace tout seul la Baseplate par sa propre carte.
2. Dans le terminal, dans le dossier du projet :
   ```bash
   rojo serve
   ```
   Le message `Rojo server listening on port 34872` doit s'afficher. **Laisse ce terminal ouvert.**
3. Dans Studio : onglet *Plugins* > **Rojo** > bouton **Connect**.
4. Ça y est ! Les scripts apparaissent dans *ReplicatedStorage*, *ServerScriptService*,
   *StarterPlayer > StarterPlayerScripts* et *StarterGui*. Chaque fois que tu enregistres
   un fichier dans VS Code, il est mis à jour dans Studio.

> ⚠️ Modifie le code **dans VS Code**, pas dans Studio : Rojo écrase les changements faits
> dans Studio sur les scripts qu'il gère.

### 5. Tester
- Onglet *View* > **Output** pour afficher la fenêtre des messages.
- Bouton **Play** (▶, ou touche F5) pour tester. **Stop** (ou Shift+F5) pour arrêter.

---

## ⚙️ Activer les DataStores dans Studio (sauvegarde + classement)

Sans ça, la sauvegarde ne marche pas dans Studio (le jeu reste jouable, mais rien n'est gardé) :

1. Publie le jeu au moins une fois : *File > Publish to Roblox*.
2. *Home* > **Game Settings** > **Security**.
3. Active **Enable Studio Access to API Services**, puis **Save**.

---

## 🎮 Équilibrer le jeu

Tout se règle dans [`src/shared/Config.luau`](src/shared/Config.luau) :
prix des aliments, gains, coût des améliorations, renaissances, durée de la pluie de
bonbons, récompense quotidienne, IDs Robux... Change un chiffre, enregistre, relance *Play*.

Astuce test : mets `Config.Debug.StudioStartingCoins = 1_000_000` pour tester la boutique
dans Studio sans attendre (aucun effet dans le jeu publié).

---

## 🪜 Les étapes de construction

### Étape 1 — Structure du projet + Rojo + Config ✅
- `default.project.json` relie les dossiers `src/...` aux bons endroits de Studio.
- `Config.luau` contient tous les réglages, `Formulas.luau` tous les calculs.
- `Remotes.luau` crée les « téléphones » entre client et serveur.

**Tester :** lance `rojo serve`, connecte le plugin, clique sur **Play**. Dans *Output*, tu dois voir :
`✅ [Grow a Giant] Serveur démarré !`, `✅ [Grow a Giant] Client démarré !` et
`✅ [Grow a Giant] Interface chargée pour TonPseudo`.

### Étape 2 — Parcelles + monstre + nourrir + revenus ✅
- `WorldBuilder` construit la carte : la place centrale, 6 parcelles en cercle, des chemins, des sucettes et des arbres.
- `PlotService` donne une parcelle libre à chaque joueur, écrit son nom sur le panneau (BillboardGui) et le téléporte chez lui.
- `MonsterBuilder` fabrique le monstre en Parts (corps rond, pieds, yeux, bouche) ; `MonsterService` le pose sur la parcelle.
- Cliquer sur **son** monstre (ou le bouton **NOURRIR**, ou la touche **F**) le fait grandir de +1, avec un cooldown anti-spam vérifié par le serveur.
- `MonsterAnimator` (client) anime l'agrandissement (TweenService), le rebond, les particules, le son et le « +1 » qui s'envole. Le monstre reste posé au sol et s'arrête de grossir visuellement à `Config.Monster.MaxDiameter`.
- `IncomeService` donne des pièces chaque seconde selon la taille. Les pièces et la taille sont dans le leaderstats et en haut de l'écran.

**Tester :** *Play*. Tu apparais sur ta parcelle devant ton monstre. Clique dessus plusieurs fois : il grandit, rebondit et le compteur de taille monte. Regarde les pièces augmenter toutes les secondes (en haut et dans le tableau en haut à droite). Dans *Output* tu dois voir `[Parcelles] TonPseudo reçoit la parcelle 1`.
Pour tester à plusieurs : onglet *Test* > *Clients and Servers* > choisis 2 joueurs > *Start*.

### Étape 3 — Sauvegarde ✅
- `PlayerDataService` charge les données avec `GetAsync` et les sauvegarde avec `UpdateAsync`, toujours dans un `pcall` avec plusieurs essais (`Config.DataStore.MaxRetries`).
- Sauvegarde : quand le joueur quitte, toutes les 2 minutes, et à la fermeture du serveur (`BindToClose`).
- Sont sauvegardés : pièces, taille, record, améliorations, renaissances, skins possédés et équipé, série de connexion, derniers achats Robux.
- Si le chargement échoue dans le vrai jeu, le joueur est renvoyé avec un message (pour ne jamais écraser sa sauvegarde avec des données vides). Dans Studio sans accès aux API, le jeu tourne sans sauvegarde et l'explique dans *Output*.

> ⚠️ **Rappel :** active **Enable Studio Access to API Services** (*Home > Game Settings > Security*) après avoir publié le jeu, sinon rien n'est sauvegardé dans Studio.

**Tester :** *Play*, fais grandir ton monstre, note ta taille et tes pièces, puis *Stop*. Dans *Output* : `[Sauvegarde] TonPseudo sauvegardé ✔`. Relance *Play* : tu retrouves ta taille et tes pièces (`Données de TonPseudo chargées ✔`).

### Étape 4 — Boutique + améliorations ✅
- `ShopService` (serveur) reçoit les demandes `BuyFood` et `BuyUpgrade`, vérifie que l'objet existe, que le joueur a assez de pièces et que le niveau max n'est pas atteint, puis fait l'achat.
- 6 aliments : Pomme, Burger, Pizza, Gâteau géant, Météorite en sucre, Planète en gelée (`Config.Foods`).
- 3 améliorations permanentes (`Config.Upgrades`) : **Grosse cuillère** (+1 taille par clic par niveau), **Estomac élastique** (revenus x1.5 par niveau), **Auto-nourrisseur** (repas automatique toutes les X secondes).
- Interface : `PanelBase` (modèle de fenêtre commun), `ShopPanel` et `UpgradesPanel`. Les boutons sont verts si tu peux payer, gris sinon.

**Tester :** mets `Config.Debug.StudioStartingCoins = 100000`, *Play*, clique sur 🍔 **Boutique** à gauche et achète une Pizza : le monstre grossit d'un coup, une notification verte s'affiche. Ouvre ⚡ **Améliorer**, achète l'Auto-nourrisseur : le monstre mange tout seul toutes les 5 s. Remets `StudioStartingCoins = 0` et essaie d'acheter : notification rouge « Pas assez de pièces ».

### Étape 5 — Renaissance + skins ✅
- `RebirthService` : à partir de la taille requise (`Config.Rebirth`), le joueur peut renaître. Il repart à la taille 1 et 0 pièce, mais gagne +1 renaissance (multiplicateur de revenus permanent) et, selon le nombre de renaissances, un nouveau skin équipé automatiquement.
- `SkinService` : équiper un skin possédé, acheter un skin en pièces. Le serveur vérifie toujours que le joueur possède le skin.
- 10 skins dans `Config.Skins` (couleur, matière, accessoire) : gratuits, débloqués par renaissance, en pièces, en Robux ou VIP.
- Interface : `RebirthPanel` (barre de progression, confirmation en 2 clics) et `SkinsPanel` (cartes avec un mini-monstre). Une pastille rouge **!** apparaît sur 🔄 quand la renaissance est possible.

**Tester :** mets temporairement `Config.Rebirth.BaseRequiredSize = 10`, *Play*, clique 10 fois sur ton monstre, ouvre 🔄 **Renaître** et clique 2 fois sur le bouton : le monstre rétrécit, devient rose avec des antennes (skin « Bonbon rose »), tes pièces repartent à 0 et le multiplicateur passe à x1.5. Ouvre 🎨 **Skins** pour remettre le Classique. N'oublie pas de remettre `BaseRequiredSize = 1_000` ensuite.

### Étape 6 — Récompense quotidienne + pluie de bonbons + classement ✅
- `DailyRewardService` : à la première connexion de la journée (heure UTC), le joueur reçoit des pièces. Une **série** de jours d'affilée augmente le cadeau (jusqu'à 7 jours). Rater un jour remet la série à 1.
- `CandyRainService` : toutes les 10 minutes, annonce 10 s avant, puis 30 s de bonbons qui tombent sur la place. Le serveur crée les bonbons, détecte le contact (`Touched`) et vérifie que le joueur est vraiment à côté. Chaque bonbon donne de la taille.
- `LeaderboardService` : panneau 🏆 sur la place avec le top 10 des records de taille de **tous les serveurs** (OrderedDataStore), mis à jour chaque minute. Sans accès aux API, il montre le top du serveur actuel.
- Interface : `EventBanner` affiche l'annonce et le compte à rebours de la pluie.

**Tester :** *Play*. Une notification dorée « 🎁 Cadeau du jour » apparaît (une seule fois par jour : pour la revoir, utilise un autre compte ou attends demain). Dans Studio, la pluie de bonbons commence après 30 secondes (`StudioFirstEventDelay`) : cours sur la place centrale et touche les bonbons. Le panneau du classement est au bord de la place.
