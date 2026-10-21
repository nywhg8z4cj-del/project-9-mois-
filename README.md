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
