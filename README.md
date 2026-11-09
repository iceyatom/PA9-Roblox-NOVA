# NOVA
A Roblox 1v1 game with automatic two-player lobbies. Each server can host multiple independent duels across five maps.

Players spawn as normal Roblox characters in a dark 3D lobby (`Workspace.NOVALobby`). Walking onto the purple queue pad removes the character and enters matchmaking. Queued players join the oldest lobby waiting for an opponent. A third player starts another lobby, a fourth joins them, and so on up to the Roblox server player limit. Each lobby owns its map selection, countdown, movement, health, shots, results and rematch votes. The HUD shows the assigned lobby number. Completed duels keep their seats for rematch decisions. After a combat disconnect, the survivor sees Victory and can choose Find new rival to wait for another opponent. Empty lobbies are removed. Waiting players from separate lobbies pair automatically when a seat opens.

Clients send their assigned lobby ID and round with each gameplay intention. The server checks both against the sender's actual membership. Snapshots and Studio tuning events reach only the members of that lobby. Leave queue (while waiting) and Lobby (after a result) respawn the player in the 3D lobby.

## Architecture decision
NOVA draws native ScreenGui rectangles on a fixed 16:9 stage. A server-owned fixed-step simulation operates in tile units with separate collision masks for bodies and projectiles. This preserves the reference's flat silhouettes, avoids perspective and 3D physics ownership differences, and lets the same collision code run in isolated tests. Roblox characters exist only in the 3D lobby; queued and dueling players have none. The client sends input edges and displays authoritative snapshots.

## Map reconstruction
The first screenshot (214811) contains 38 columns and 29 rows starting at image pixel (20,9), on a 32-pixel pitch. Coordinates start at the upper left, increase right and down, and mirror across x=19. The two centers start at (6.5,27.5) and (31.5,27.5). Purple bodies occupy the entire outlined tile. The upper rings have different masks on their inner and outer uprights. The original black interior, outline contours, central bridge and staircase floor are built from editable tiles. Yellow and muted green corner squares are visual markers. The colored spawn caps are interpreted as health bars. Two additional low mint strips near the spawns identify the actual launch triggers, which pass bullets and activate once per contact. Side margins contain the duel HUD.

## Map rotation

The selection reel plays the supplied `CSGO Case Click.mp3` whenever a card center crosses the selection pins. Its imported Roblox audio is `rbxassetid://92334355914521` (NOVA Map Cycle Click); the ID and playback volume are in `src/client/MapRoller.luau`. Audio is preloaded on each client, overlapping clicks keep their sample tails, and playback stops when the reel closes. Click spacing follows the reel's slowdown and no skipped clicks are replayed in a burst after a delayed frame.

The rotation includes Split Circuit (01), Crossfire (02), Skyline (03), Hourglass (04), and Nexus (05). The four new layouts trace screenshots 214830, 214842, 214905, and 214925 on a 40 × 30 grid. Crossfire and Nexus retain the small asymmetries in their references. Purple tiles block players and shots; dark blue tiles block players; light blue tiles block shots; green tiles are launch triggers.

When two queued players pair, the server chooses a map and both clients see a horizontal reel cycle through map previews, slow down, and land on that map. The selection lasts eight seconds, with the original fast-to-slow easing stretched evenly across twice its previous duration. After the reveal, the three-second countdown begins. Movement and firing unlock together. Both rematch votes start a new shuffle, excluding the previous map when another map is available. Each lobby selects independently. Valid maps saved by the editor enter the rotation on the next Play session. Invalid maps are skipped with a Studio warning.

## High Score Practice

The mint beacon to the right of the main queue enters a private 2D firing lane. The player and auto-aimed target stay stationary. After an animated 3–2–1 / GO countdown, press your configured Fire binding (or the on-screen Fire button) once per shot for 30 seconds. Holding a binding does not repeat shots. The server counts accepted shots during the time window; movement, client score submissions, stale run IDs and duplicate shot IDs cannot change a score. A 50-shots-per-second ceiling bounds abusive remote traffic above normal human tapping speed.

Results show the run total and personal best, with Try again and Back to lobby buttons. The Lobby button can also abandon an unfinished attempt; abandoned attempts do not submit scores. Each player has an independent practice session and cannot queue for a duel at the same time.

The wall beside the beacon shows the global top 10, one best completed score per player, in descending order. Published servers use `NOVA_HighScorePractice_v1`, an OrderedDataStore, with atomic maximum updates so lower scores or concurrent servers cannot overwrite a personal best. Rankings refresh every 60 seconds and local completions appear immediately. Temporary save failures retry and are disclosed on the results screen and board. Studio uses session-only scores and never changes the live leaderboard. Cross-server persistence must be checked in a published server; enabling Studio API access is unnecessary for practice previews.

## Duel rules
A/D move, Space jumps from a surface, and gravity brings the player down. Each left mouse press launches one shot at the opponent's authoritative center when the request arrives. Direction is frozen for the flight. The server accepts increasing integer shot IDs for the current round only. Impacts in the same simulation step are applied together; simultaneous lethal impacts draw. Both players must vote for a rematch. Lobby returns the player to the 3D lobby. A combat disconnect gives the remaining player a win, and they may choose to wait for a new opponent. New arrivals cannot enter an active duel.

## Levels and prestige

Players start at level 1 and reach level 55 before choosing a prestige. Click the compact top-left level card to open progression, then use the **Requirements** tab to unlock the next prestige. The first click explains the reset; **Confirm Prestige** performs it. Each of the ten prestiges resets level to 1 and current XP to zero. After reaching Prestige 10 level 55, **Become Prestige Master** keeps level 55 and unlocks levels 56–1,000. Prestige Master level 1,000 is the final cap. Prestige is available only in the 3D lobby, outside matchmaking and practice.

After the server confirms a prestige, the new icon appears in grayscale, grows and lifts while changing to full color, then stamps down with a short squash and rebound. Golden radial rays counter-rotate behind it, with a soft aura, an expanding impact ring, and sparks. The reveal displays the new prestige and item name, then returns to Progress automatically or through Continue / controller Back. Closing progression or entering a challenge cancels the effect and releases its resources. Failed requests do not animate. Grayscale image passes preserve the original artwork's exact alpha and geometry; assets and upload records are in `assets/ranks/reveal/`.

A completed duel gives its winner **300 total XP** and its loser **100 XP**. Draws give both players 100 XP. A combat disconnect gives the survivor 300 XP; the departing player receives none. Queueing, map selection, countdowns, abandoned duels, and High Score Practice do not award XP. Each round finishes and awards rewards once, including rematches. The match result shows the earned XP.

Results animate an itemized XP recap: **Duel completed +100 XP**, plus **Victory bonus +200 XP** for a win. Each row pops in and counts up, followed by its contribution filling the progression bar. Every crossed threshold gets a level-up pulse before the bar continues toward the next level. The recap finishes at the server's exact final level and XP, with a total and levels gained. At level 55 or Master 1,000 it shows the cap instead of a nonexistent next level. Rematch votes do not replay the recap; a new round gets a fresh recap. Rematch and Lobby stay available during the animation.

`XPRewards` creates server receipts with the pre-award rank, item list, total, and final rank. `XPRecap` renders them without awarding XP or changing saved progression. Future XP-granting activities can use the same receipt format. Practice continues to grant no XP.

`src/shared/Progression.luau` owns the tunable rewards and XP curve: the step from level 1 to 2 costs 100 XP, then each step costs 25 more. Master levels keep the level-55 cost of 1,450 XP per level. Excess XP is discarded at level 55 until prestige is chosen, and at the final cap. Lifetime XP survives prestige.

The compact lobby card contains only the rank icon, numeric level, and XP bar. Clicking anywhere on it opens a three-tab progression panel. **Progress** shows the current rank, XP toward the next level, and lifetime XP. **Prestiges** shows all twelve icons in a scrollable collection with Current, Unlocked, Next, Ready, or Locked states. Selecting any card opens its **Requirements**, including the previous prestige's level-55 prerequisite, reset behavior, and progress toward eligibility. The server remains authoritative for prestige actions. Load errors and prestige responses appear below the Requirements action when relevant; XP-per-win advertising is absent from this UI. The enlarged panel scales up to 130% while fitting within the viewport, with no subtitle, completed-prestige statistic, or status/control-help footer.

The progression panel and Settings close each other when opened. Character movement is blocked while progression is open, including clients without a legacy PlayerModule. Entering a queue or practice closes it and releases movement. Controller Y / Triangle opens progression, LB / RB switches tabs, and B closes it. The close button and Escape also dismiss it; Escape can open Roblox's system menu. A confirmation is cleared when closing the panel or changing tabs/targets.

Nameplates above lobby characters show their display name and rank; the Roblox player list also shows Level and Prestige. Both duel seats show an avatar headshot and full rank from matchmaking through the result screen. Thumbnail loading happens independently of gameplay and is cached per user.

Twelve original cartoon icons identify Prestige 0, Prestiges 1–10, and Prestige Master. The icons appear in the lobby card, overhead nameplates, duel player panels, and animated XP recap, with rank and level text retained. The set progresses from a basic bronze chevron through jeweled weapons to an infernal crown, void phoenix, celestial dragon, and the winged cosmic Master crest. Sources, prompts, a contact sheet, and Roblox asset provenance are in `assets/ranks/`; selection and asset IDs live in `src/shared/RankIcons.luau`. Images load only as their ranks are displayed.

Five additional original sprites identify the Progress, Prestiges, and Requirements headers and locked/unlocked states. Their transparent PNGs, exact generation prompts, and approved Roblox upload IDs are in `assets/ranks/menu/`; runtime IDs are in `ProgressionArt`. `ProgressionInfo` derives the collection states and prerequisites from the existing progression rules.

Published servers store profiles in `NOVA_Progression_v1` using atomic updates, a per-server session token, and a 180-second lease renewed every 30 seconds. Failed loads never replace a saved profile with defaults; the progression panel reports the failure, retries, and challenges wait until the profile is available. Failed saves retry, retain pending progression in memory, and report the delayed save. Profiles save on prestige, periodically, on departure, and during shutdown. An expired lease stops progression changes until renewal succeeds. Studio uses session-only progression without reading or changing live profiles.

## Inventory

The **Inventory** button sits directly beneath the Level card in the main lobby. Xbox **X / PlayStation Square** also opens it; LB/RB changes categories, B closes the reveal or menu, and Escape dismisses it. Inventory, progression, and Settings close one another. Inventory blocks lobby movement and closes when entering a queue or practice. Desktop uses tabs, an item grid, and a preview/details panel; narrow screens use a stacked, vertically scrollable layout with readable controls. Selecting a card scrolls to its preview on narrow screens.

Categories are **Skins, Bullet Skins, Tracers, Backgrounds, Sound Effects, and Crates**. Search, rarity filters, favorites-only filtering, and Equipped/Rarity/Name sorting operate on owned items. One cosmetic per category can be equipped; unequipping returns to its always-owned default. Backgrounds customize the duel player card. Skin colors, bullet colors, projectile tails, and shot sounds apply in real gameplay, including practice. These are development cosmetics; final collectible skin artwork is intentionally deferred. Defaults preserve NOVA's original appearance and silent shot sound.

Players receive no sample collectibles or crates automatically. From the **server Command Bar during Studio Play**, grant a sample bundle:

```lua
game.ServerScriptService.NOVA.GrantInventory:Invoke(game.Players:GetPlayers()[1], "samples")
```

The bundle grants all ten sample cosmetics and ten test crates. For just five crates, use `:Invoke(player, "crate_dev", 5)`. Individual stable IDs are in `src/shared/InventoryCatalog.luau`; for example `skin_mint` or `card_nebula`. This tool is a server-only BindableFunction, accessible to trusted developer server code; it has no client remote, chat command, or public admin UI. In a published server, trusted server-side invocation changes that player's saved inventory. Studio grants are session-only.

Opening a **NOVA Test Crate** consumes one crate and grants one server-selected cosmetic. A scrolling reel slows onto that exact reward. Duplicates become **Shards**, a placeholder currency with no spending or purchase system. Crate details disclose rarity odds. The temporary drop table and duplicate values live in `InventoryCatalog`; rewards do not affect combat statistics. The server checks ownership, lobby membership, profile readiness, request rate, and the opening cooldown. A bounded history of request receipts makes connection retries idempotent, including after a profile reload; the animation never grants rewards.

Published servers use `NOVA_Inventory_v1` with atomic UpdateAsync writes and a per-server 180-second lease, renewed every 30 seconds. Ownership, equipment, favorites, quantities, Shards, and recent crate receipts are saved. Invalid or failed loads never overwrite a profile with defaults; errors are shown and retried. Expired leases block mutations, and delayed saves retain pending changes for retries. Studio uses session data without accessing live profiles. Cross-session persistence needs verification in a published server; Studio API access is unnecessary for these previews.

The six original transparent category/launcher sprites were made with the NOVA UI Sprites skill and built-in image generation. Sources, exact prompts, asset IDs, moderation results, and a dark-background review sheet are under `assets/inventory/`; runtime IDs are in `InventoryArt`. Crate animation uses native UI transforms and TweenService.

## Developer controls
Studio-only diagnostics and automated tests are gated by RunService:IsStudio(). Balance defaults are in ReplicatedStorage/NOVA/Config. The map and tile catalog are adjacent modules. Production has no configuration remote.

During Studio Play, switch the Command Bar to **Server** and use `game.ServerScriptService.NOVA.TestXP:Invoke(game.Players:GetPlayers()[1], "cap")` to fill the first player's current rank to level 55, or Master to level 1,000. Replace `"cap"` with a whole XP amount such as `5000` to grant exactly that amount. The returned table reports the new rank and eligibility, and the UI updates immediately. Use the normal Requirements tab to confirm a prestige, then run `"cap"` again to test the next one. This server-only BindableFunction is created only in Studio, has no client remote, uses session progression, and disappears when Play stops.

Press **F4** in a Studio client. **Show masks** displays tile and player bounds, spawn crosses and one-step projectile traces. Click the parameter name to cycle through five settings, then use **+ / −** to adjust the running server. **Set duel lane** moves both players onto an unobstructed platform in the current map during combat for repeatable shooting tests. The panel records phase changes, tuning and hits. Runtime adjustments last for the current server. Edit the Config source to change future sessions.

## Open and play

Open `build/NOVA.rbxlx` in Studio. For a fresh checkout, run `python tools/build.py` at the repository root to generate that file using Python 3 and its standard library. In Studio, select **Server & Clients**, choose **2 clients**, and start the session. Solo Play intentionally opens a one-player lobby. Use keyboard and mouse or a connected gamepad. Tilt the left stick sideways past its dead zone to move at full speed. Releasing or reversing horizontal input stops or reverses movement on the next simulation tick, including in midair. Press Xbox A or PlayStation Cross (×) to jump. Pull RT/R2 once per shot.

Player positions display directly from server updates at 60 Hz. Jumps immediately apply their configured upward impulse and then follow gravity. Network travel time still affects when an input reaches the authoritative simulation.

Hold Space or Xbox A / PlayStation Cross (×) to jump again automatically whenever the player lands on a solid surface. Release to finish the current arc and stop jumping. A short tap performs one jump. Opening the Roblox menu, losing focus or disconnecting the controller clears held input.

## Control settings

Click **Settings** in the top-right corner of the main lobby, or press **View / Touchpad** on a controller while in the lobby. Settings are hidden and unavailable in the 2D duel and practice screens, including queues and results. F2 has no settings shortcut. The menu has separate **Keyboard + mouse** and **Console controller** tabs for Move, Jump, and Fire. Click a binding and press its replacement. PC movement has separate left and right keys. Console movement accepts the left stick, right stick, or D-pad. Jump and Fire accept keyboard/mouse inputs on PC and controller buttons on console.

Bindings apply immediately. Duplicate assignments are rejected. Escape closes settings; View cancels a binding on a controller. Controller navigation, Done, and Reset defaults work from either tab. Opening settings releases held movement and jump. Entering a challenge closes the menu. Done closes the menu and saves both sets of bindings. Defaults are A/D, Space, left mouse, left stick, A/Cross, and RT/R2.

Published servers load and save preferences per player in `NOVA_ControlPreferences_v1`. Studio uses session preferences without reading or writing live player data. If profile storage is unavailable, bindings still work for the current session and the menu reports that status. Bindings survive rematches and character respawns.

## Level editor

`plugin/NOVALevelEditor.lua` is a Studio plugin for painting duel maps. Install it by copying the file into Studio's local plugins folder, then restart Studio:

```bash
cp plugin/NOVALevelEditor.lua "$LOCALAPPDATA/Roblox/Plugins/"
```

Open it with **Plugins → NOVA → Level Editor**. Pick a map in the sidebar or click **New map**. Select a tile, then left-drag on the grid to paint and right-drag to erase. **Mirror** paints both halves and places the second spawn opposite the first. **Check map** runs the same compiler the game uses. **Save** writes a ModuleScript to `ReplicatedStorage.NOVA.Maps`. **Set active map** chooses the map shown while waiting for a rival; live duels use the map rotation. Without an active map the waiting screen shows Split Circuit.

Maps saved in Studio are part of the place, not this repository. To copy one into `src/shared/maps/`, start the local bridge at the repository root and keep it open:

```bash
python tools/map_bridge.py
```

Then open the map in the editor, Save it, and click **Export to repo**. The first export asks you to allow the plugin to reach `127.0.0.1`; choose Allow. The bridge listens only on this PC, accepts only map data modules, and writes `src/shared/maps/<MapName>.luau`. Run `python tools/build.py` afterwards to include the map in the generated place.

**Delete map** removes the open map from Studio and deletes `src/shared/maps/<MapName>.luau`. Click it twice within five seconds to confirm. The bridge must be running; the repo file is deleted first, so a failed request leaves both copies in place. Studio's Undo restores the Studio copy only; restore a committed repo copy with `git checkout -- src/shared/maps/<MapName>.luau`. If the map was active, the game returns to Split Circuit. Split Circuit cannot be deleted.

## Source-to-Studio mapping

| Repository directory | Studio parent | Responsibility |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.NOVA` | Config, TileCatalog, Map1, ControlBindings, Progression, ProgressionInfo, ProgressionArt, PrestigeRevealArt, XPRewards, RankIcons, InventoryCatalog, Inventory and InventoryArt |
| `src/shared/maps` | `ReplicatedStorage.NOVA.Maps` | Map data modules for all five arenas |
| `src/server` | `ServerScriptService.NOVA` | Server, LobbyWorld, Lobbies, Match, Movement, Combat, Practice, PracticeWorld, PracticeLeaderboard, ControlPreferences, ProgressionService, ProgressionStore, InventoryService, InventoryStore and StudioTest |
| `src/client` | `StarterPlayer.StarterPlayerScripts.NOVA` | Client, Hud, LobbyHud, PracticeHud, ProgressionHud, ProgressionMenu, PrestigeReveal, XPRecap, RankIcon, Portrait, Widgets, Arena, Input, ControlSettings, SettingsMenu, InventoryMenu, InventoryPreview, InventoryStyle, CrateReveal and Diagnostics |
| `tests/unit`, `tests/cases` | `ServerStorage.NOVAUnitTest`, its `Cases` folder | Runner, fixtures, performance profile and acceptance cases |
| `tests/integration` | `ServerStorage.NOVATesting` | Multiplayer session driver and per-client input probe |

LobbyWorld builds `Workspace.NOVALobby` and the night lighting at server start unless the place already contains a NOVALobby, so a hand-edited lobby in Studio is kept. The build maps `.server.luau` to Script, `.client.luau` to LocalScript and other `.luau` files to ModuleScript. At runtime the server creates State and Input under ReplicatedStorage.NOVA. Each client creates PlayerGui.NOVA. Only a named Studio integration run clones the input probe into test clients.

## Reproduce the MCP deployment

1. Open a baseplate or the generated place. In the Roblox MCP connection, run `list_roblox_studios`, select the intended ID, and check `get_studio_state` for Edit mode.
2. Run `python -X utf8 tools/build.py --sync --service ReplicatedStorage` in this repository. Pass its complete stdout as the `code` argument to the Studio MCP `execute_luau` tool using that ID and the Edit data model.
3. Repeat for `ServerScriptService`, `StarterPlayer` and `ServerStorage`. Each batch checks object class and the NOVAOwned attribute before updating existing objects. Name conflicts stop the batch. The sync uses ScriptEditorService so changes are visible in the editor. Source control is authoritative for NOVA-owned scripts.
4. Run the checks below. For a new online experience use Studio **File → Publish**, select the personal creator and keep the new experience private. For subsequent updates, confirm the intended place and use Publish on that connected place. Only players with access to the private experience can join online. [Roblox publishing guide](https://create.roblox.com/docs/production/publishing/publish-games-and-places)

## Run the acceptance checks

For local logic checks without Studio, install the official [Luau CLI](https://github.com/luau-lang/luau/releases) and run `python tools/check_logic.py --luau <path-to-luau>`. This runs the progression, profile storage, match rewards, match, lobby, movement, combat, practice, and map rotation cases with a minimal module/Vector2 environment. It does not emulate Roblox UI, networking, or real DataStores.

In a running Studio **server** data model, execute each line separately.

```lua
return require(game.ServerStorage.NOVAUnitTest.RunUnitTest)()
return require(game.ServerStorage.NOVAUnitTest.Profile)()
```

For the end-to-end test, stop Play and use the following in the Studio **Edit** data model. This test starts a real local server, adds a second Roblox client, drives keyboard and mouse input, and ends its own session. The result contains a pass flag and an observation log.

```lua
return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1,"NOVA/acceptance")
```

The performance gate is a p95 server simulation step below 12 ms over 90 samples with 120 simultaneous projectiles on Map 1. The sample measures simulation CPU time and excludes rendering and transport. See [the acceptance record](ACCEPTANCE.md) for the observed results.
