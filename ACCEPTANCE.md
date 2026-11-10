# NOVA v1 acceptance record

## Crate reel audio and immediate item reveal — November 8, 2026

Map and crate reels now share `ReelAudio`, reusing the approved map-cycle sound `92334355914521` at volume 0.5 with 24 overlapping voices. A real crate opening produced 32 Sound.Played events; intervals slowed from approximately 0.032–0.050 seconds to 1.97 seconds. All 24 voices loaded and playback loudness reached approximately 45.15. Cancelling during a spin removed the reveal and stopped every voice; a cooldown rejection produced no animation. An isolated run of the production map `tick()` method, with stand-in visual cards, still produced 21 clicks and stopped all voices on hide. This was an audio/motion check, not another multiplayer match.

After landing, the awarded category sprite uses the prestige lift/grow/stamp trajectory, squash/rebound, counter-rotating golden rays, soft aura, expanding rings, sparks and a brief flash. Approved full-color inventory sprites are reused. Continue becomes available after the two-second item animation. Closing, leaving the lobby or resizing cancels render connections and sound; presentation does not grant a second reward.

The received sprite's ImageLabel is prepared during the reel. Landing starts motion immediately, with no image-loading gate. In a real Studio crate opening, the visible loaded item appeared 0.0333 seconds after the reel landed and reached the settled phase. The Studio console contained no runtime errors. A separate iPhone 17 Pro landscape preview using an existing authoritative receipt reached settled with readable reward/detail text and a visible Continue button; the simulator was reset afterwards. Short viewports use a compact reveal layout. The changed modules compile, the local place was rebuilt, and sources were synced to Studio. No place was published.

## Inventory visual polish — November 8, 2026

The Inventory launcher now matches the Level card's 220 × 72 logical pixels, 56-pixel sprite slot, and 26-pixel Gotham Black text. A running Studio client confirmed both actual launcher heights were 72 pixels and the Inventory label fit. The inventory window now uses the progression panel's 12-pixel outer corner radius and up-to-130% desktop scale. Its cards, detail panel, search field and controls have rounded corners. Buttons use shaded faces, four-pixel bottom shadows, and hover/controller emphasis; tabs, filters, item names, rarity labels and body copy have larger text.

Desktop and iPhone 17 Pro portrait inspection found no truncated visible labels. Crate details and action text fit; a real crate opening reached Ember Core, displayed its duplicate conversion into 60 Shards, and showed the rounded Continue button and its shadow correctly. The changed modules compiled and the place was rebuilt. The Studio console contained no runtime errors. Existing approved NOVA sprites were reused. The device simulator was reset to the default viewport; no place was published.

## Inventory — November 8, 2026

All **98 local logic checks passed**, including 13 new inventory/leased-storage cases. Coverage includes ownership enforcement, equip/unequip defaults, favorites, crate quantities, every weighted reward boundary, duplicate-to-Shards conversion, idempotent request replay after serialization, bounded receipt history, invalid input/profile rejection, session conflicts, stale-server save rejection, and save failures/retries. Every Luau source/test compiled with the official compiler, and `build/NOVA.rbxlx` was regenerated.

All **13 inventory cases also passed in the actual Studio server**. A solo Studio client opened Inventory through its launcher, equipped Mint Circuit, saved a favorite, and opened a test crate through the UI. The server consumed exactly one crate; the scrolling reel landed on the authoritative Arcade Click reward and displayed its duplicate conversion into 25 Shards. All six uploaded NOVA sprites were Approved and observed with `ImageLabel.IsLoaded=true`. The six 1254 × 1254 transparent sources passed the sprite validator and were reviewed together at 128 and 48 pixels on NOVA's dark UI.

The updated real multiplayer acceptance run returned **passed=true** with four concurrent clients and a fifth replacement. It verified inventory launcher clicks, UI equipment/favorites, server-only sample grants, rejection of client grants, duplicate currency, and idempotent crate retries. Both duel clients rendered the equipped skin and player-card background, then the gold bullet, cyan tracer, and equipped shot sound from real authoritative projectiles. Inventory was hidden outside the lobby and an equipment request during a duel was rejected. The existing movement, health, separate lobbies, rematch, queue return, and disconnect checks passed; 16 projectile samples matched between clients.

The test setup hides Roblox's Core player list so it cannot cover Settings in small Studio client windows. The queue fixture now accepts the Selecting phase, matching the existing eight-second map reel. These are acceptance-harness corrections.

Desktop and iPhone 17 Pro landscape/portrait layouts were visually checked in Studio. The game permits Sensor orientation. Narrow screens use readable wrapped tabs, a stacked grid/details layout, and vertical scrolling; preview/actions remained reachable. The simulator was reset to the default viewport. These are emulator/layout checks, not physical phone or console tests.

Injected controller inputs opened Inventory with X, switched to Bullet Skins with RB, and closed it with B. Closing removed the movement action binding and restored Settings. The equipped built-in sound loaded successfully with a 0.845-second duration. The final Studio console contained no runtime errors.

Studio uses session inventory and does not access live inventory profiles. Published-server cross-session persistence remains unverified. No place was published.

## Map-selection click audio — November 8, 2026

Imported the supplied `CSGO Case Click.mp3` as the owning user's audio asset `92334355914521`; Roblox moderation returned **Approved**. The Studio client loaded the 0.705-second asset successfully. Render-driven reel checks produced **21 Sound.Played events**, with initial intervals of approximately 0.034–0.050 seconds and final intervals of approximately 1.55–1.57 seconds. The final check used 24 voices to preserve overlapping sample tails and measured nonzero playback loudness (peak approximately 45.15). Hiding the reel stopped every voice, and no console audio errors occurred. A separate timing sweep verified one trigger per crossed card center and silence after hiding. The game itself was not published.

## Practice squares and lobby settings — November 8, 2026

The practice actors now use equal 36 × 36 solid blue/red squares with no barrel, bullseye or colored pedestal. Settings is labeled **Settings**, with no F2 shortcut. The menu and launcher are available only in the main 3D lobby; controller View is also gated to the lobby. Starting a challenge closes an open menu, saves controls and hides the entire settings GUI. Returning to the lobby restores the button.

All **62 automated checks passed**. A Studio playtest verified the plain square sizes/colors, the exact launcher label, no reaction to F2, mouse opening in the lobby, automatic closure on practice entry, and button restoration after leaving practice. The updated multiplayer acceptance run returned **passed = true**, verifying lobby-only settings, mouse rebinding, saves, hidden settings during duels, and the existing duel/rematch/disconnect flows; 16 projectile samples matched between clients.

## High Score Practice — November 8, 2026

All **62 automated checks passed**, including three new practice timing/input/isolation cases and two leaderboard cases. The checks cover the exact 3-second countdown and 30-second scoring window, late/pre-countdown shots, malformed and replayed sequences, foreign run IDs, excessive request bursts, independent players, abandoned attempts, retry invalidation, ten unique descending rankings, and atomic maximum saves against a fake store. No live player data was used.

A solo Studio playtest entered the mint beacon from a normal lobby character and switched to the stationary 2D range. A held mouse button counted once; five further clicks yielded six shots. Movement and jump input left both actor positions unchanged. Results arrived at the authoritative deadline with six shots, personal best six, and a session-only save message. The wall board displayed the same player and score. Try again started a fresh countdown with zero shots and kept the personal best. A stale previous-run fire request was rejected, the on-screen Fire button counted one shot, and abandoning that retry restored the character, lobby HUD and custom camera without replacing the best. The same player subsequently entered and left the ordinary duel queue successfully.

The existing real multiplayer acceptance test also returned **passed = true** with four concurrent clients and a fifth replacement. Movement, held jump, rebindable controls, isolated duels, health, results, map rotation, rematch, lobby return and disconnect recovery passed; 15 projectile samples matched between clients.

The practice screen, animated countdown, beacon placement and wall leaderboard were visually inspected in Studio. Studio deliberately uses session rankings. Production cross-server persistence is implemented with an OrderedDataStore but has **not been verified in a published server**. The place was not published as part of this change.

## Rebindable controls update

All **57 simulation checks passed**. Preference checks cover serialized keyboard/mouse and controller bindings, device independence, duplicate inputs, D-pad movement conflicts, reserved menu controls and malformed data.

The multiplayer acceptance run returned **passed = true** with four concurrent players and a fifth replacement player. Inside a live duel, settings released held movement, rebound all PC controls, rejected a duplicate, delivered the replacement jump key to the authoritative server, saved the preferences for the session and restored defaults. The rest of the movement, shooting, rematch and disconnect checks passed.

Client checks also passed for shared keyboard/controller jump holds, distinct trigger presses, reconfigured sticks and D-pad, controller binding capture, explicit menu selection paths, mouse binding release, and preventing a settings-button click from firing a shot. Both settings tabs were visually checked in Studio. Controller checks injected controller input into the same handlers; a physical console and production profile storage were not tested. Studio deliberately uses session-only preferences.

## Map rotation update — November 8, 2026

All **54 simulation checks passed**. The four reference maps compile at 40 × 30 tiles with the traced spawns and collision masks. Rotation tests cover skipping the previous map, locking input during selection, countdown timing, mutual rematch votes, stale round rejection, cancellation on departure, and independent lobbies.

The real multiplayer acceptance run returned **passed = true**. Both clients received the same selected map, then rematched to a different map through the UI buttons. Four concurrent clients occupied two separate duels; a fifth replacement client joined later. Movement, repeated jump input, shooting, health, results, queue departure and disconnect recovery passed. There were 18 matching projectile samples across the dueling clients. The horizontal reel was inspected in Studio.

## Held jump update

All **50 simulation checks passed**. The new checks cover repeated jumps while held, stopping after release, short taps, and rejection of invalid held-state values. Client input checks cover Space and controller A/Cross together, releasing one while the other stays held, cancellation, clearing held input and distinct trigger presses.

The four-client acceptance run also passed. A real Studio client held Space across multiple landings and then released it. The player jumped repeatedly and settled after release. The same run completed both duels, a rematch, Leave and disconnect recovery while the second lobby stayed isolated.

## Movement response update

The simulation suite passed **48 of 48** checks. The new regression verifies full-speed movement on the first input step, immediate stop and reversal on ground and in air, and the full initial jump impulse. Client checks verified that partial stick deflection outside the dead zone produces full speed, release produces zero movement, and player positions render at the newest snapshot without positional blending. Server snapshots now run at 60 Hz.

## Multiple lobby update

The current simulation suite passed **47 of 47** checks. Added cases cover seven players pairing into independent duels, an odd player waiting, duplicate ready requests, rejection of requests carrying another lobby ID, independent rematch rounds, automatic pairing of waiting survivors and removal of empty lobbies.

The extended live Studio test passed with four clients in two simultaneous lobbies and a fifth replacement client joining later. Both lobbies exchanged movement and shots. The second lobby retained its health, round and Playing phase while the first lobby completed two duels, rematched, used Leave, accepted a replacement, and handled an active disconnect. Each pair received only its own roster and projectile state. The connected place reported a 60-player server limit, permitting up to 30 simultaneous duels. This is functional testing with four concurrent clients, not a 60-client load test.

Tested November 7, 2026 in Roblox Studio through MCP on the development PC. The automated suite returned **43 passed, 0 failed**. The extended StudioTestService run returned **passed = true**. The real local clients used generated keyboard and mouse events and the same input, rendering, UI buttons and RemoteEvents as normal desktop players.

| Case | Observed result |
| --- | --- |
| AT-01 | Compared the Studio capture with 214811.png. The ring masks, stepped side walls, bridge, low stairs, borders and spawns match the traced 38 × 29 grid. The two mint floor pads are deliberate additions. Owner visual signoff is open. |
| AT-02 | Requested 1280 × 720, 1920 × 1080 and 1024 × 768 in Studio's device simulator. Measured viewport sizes were 1279 × 720, 1919 × 1079 and 1023 × 768. The arena stayed on screen at 38:29 in each case. Restored the default device. |
| AT-03 | Both clients moved using keyboard events. The movement suite checked launch from ground, refusal of a second airborne jump, airborne fast-fall acceleration and grounded reset. |
| AT-04 to AT-06 | Swept players and shots against purple, dark blue and light blue from all four directions. Body and shot masks matched the catalog. |
| AT-07 | A green pad applied one upward impulse. Held contact did not retrigger. Exit and re-entry reapplied it. |
| AT-08 | Opposing players stopped at one body width, stayed inside the edges, and a missed shot disappeared at the boundary. |
| AT-09 | A held mouse button delivered one hit. Additional clicks each fired; 64 distinct same-step IDs were accepted and all repeated IDs rejected in the isolated test. |
| AT-10 and AT-11 | Shot started at shooter center and kept its speed and heading after the target moved. Opposing shots passed each other. Both clients reported identical coordinates for the same projectile on eight server ticks in the extended run. |
| AT-12 and AT-13 | Both clients showed 1 HP after nine shots and the correct final result after ten. Rapid hits applied independently. Duplicate IDs and owner damage tests passed. |
| AT-14 | Four-direction sweeps crossing both an entire tile and target within one step hit the first applicable obstacle. |
| AT-15 | Blue alone saw Waiting. After red joined, both clients observed Countdown, full HP and the mirror-paired spawns. The timing test checked the 179th and 180th simulation steps. |
| AT-16 | Blue won round one. Red won round two. Each client showed the corresponding Victory or Defeat screen. The suite also verified a same-step lethal draw and rejection of late shots. |
| AT-17 | Blue's first vote left Results in place and showed Accept rematch to red. The second button click started round two with restored health, spawns and countdown. |
| AT-18 | Red used Leave after the second round and blue returned to Waiting. A replacement client joined and then disconnected during active combat. Blue received Victory and used Return to lobby. Countdown disconnect was checked separately. |
| AT-19 | Invalid action names, invalid numeric values, malformed movement and duplicate/stale-round shots were rejected by the isolated tests. A live client sent unauthorized state updates and an invalid shot; the opposing player remained at full health. |
| AT-20 | Opened F4 in Studio, clicked Show masks and verified that the collision overlay became visible. The live Studio lane preset placed both combatants for shot testing. The server and client runtime diagnostics gates were inspected in source. |
| AT-21 | Initialized an independent Git repository, deployed its sources to the open place via MCP, and generated the standalone place with the same source mapping. Build and sync commands are in README.md. |
| AT-22 | A server and two real Studio clients completed two full duels, a two-vote rematch and a Leave. A replacement connection completed the active-disconnect case. The driver returned success. Public-internet latency and two independently operated Roblox accounts were outside this local run. |

## Server step profile

On this machine, 90 samples of one fixed step with 120 simultaneous shots yielded a median of 0.450 ms, p95 of 0.504 ms and maximum of 1.854 ms. The development target was p95 below 12 ms.

## Implementation notes

The server samples both authoritative centers on receipt of a fire request. Internet latency can change what the shooter sees relative to the sampled positions. The first iteration uses interpolated snapshots without client prediction or rewind. All four active tile behaviors are editable. The two colored corner markers remain decorative pending owner review.

## Leveling system — local verification, November 8, 2026

- Official Luau 0.746: all 52 source/test scripts compiled successfully.
- `python tools/check_logic.py --luau <luau.exe>`: **74 passed, 0 failed**, including 17 new progression, persistence, and reward cases. Coverage includes all ten prestige resets, Master entry and level 1,000, XP overflow, invalid profiles, profile session conflicts, expired leases, save retries, rematch rewards, draws, and disconnect outcomes.
- `python tools/build.py`: regenerated `build/NOVA.rbxlx` with the new modules and tests.
- No Roblox Studio instance was connected during this change. Engine/UI verification and published-server persistence remain pending. Local fake-store checks do not establish live DataStore behavior.

Subsequent Studio verification: the open NOVA place (102464433517469) was missing all new progression modules. Synced the 13 changed/new scripts and tests into its Edit data model, then started Play. The client reported `ProgressionReady=true`, Level 1, and an enabled `NOVAProgression` panel. A screenshot confirmed the XP card and the character's Level 1 nameplate. All 13 progression/storage cases and 4 match reward cases passed in the actual Studio server. Published-server saving and a two-client portrait/XP playtest remain pending. The local place was updated without publishing.

Manual checks in Studio (two clients):

1. Confirm both players start at Level 1, can see each other's lobby nameplates, and see their own XP card. Queue together and check headshots and ranks on both duel seats, including during map selection.
2. Complete a duel: the winner should receive 300 XP and the loser 100 XP exactly once. Rematch and verify another award. Disconnect during combat and confirm only the survivor receives 300 XP. Leave before combat and confirm no XP.
3. Run `require(game.ServerStorage.NOVAUnitTest.RunUnitTest)("Progression")` and `require(game.ServerStorage.NOVAUnitTest.RunUnitTest)("MatchRewards")` in the Studio server Command Bar for rank, save, and reward boundary coverage.
4. At level 55, check the two-click lobby prestige flow, cancellation by entering a challenge, ten resets, and Prestige Master entry at level 55. Test keyboard, touch, and controller selection, and check the lobby card on a narrow viewport.
5. In a private published test server, earn XP, leave, and rejoin to verify the saved rank and XP. Confirm delayed saves/loads are disclosed, temporary failures recover, and overlapping sessions cannot overwrite each other. Studio intentionally does not access these profiles.

## Animated XP recap — November 8, 2026

- Official Luau CLI: **81 logic cases passed**, including seven new itemized-reward/animation-plan cases. All **55 Luau scripts compiled**. Rebuilt `build/NOVA.rbxlx`.
- Synced the eight changed/new runtime and test scripts to the local NOVA place. In the actual Studio server, all seven XPRewards cases and four MatchRewards cases passed.
- A Studio-only preview sent receipts through the real State snapshot handler. Visually verified the item rows, counting total, progression bar, rank, level gains, and result buttons. A level-1 victory ended at Level 3, 75/150 XP, with a half-full bar and +300 XP total. Confirmed the buttons are below the progress text and remain available.
- Re-sent the same result with a rematch vote: the completed animation did not replay and the rematch button updated normally. A new-round preview reaching Prestige 5 level 55 stopped with a full bar and the prestige-available message.
- Previews did not change the player's profile. Restored the lobby, confirmed Level 1 / 0 XP, and left Play running. No publishing was performed. A complete two-player duel with the new animation remains a manual gameplay check; the Studio checks used isolated result snapshots.

## Prestige artwork — November 8, 2026

- Generated twelve separate transparent PNGs with the built-in image generator, reviewing basic, mid-tier, and Master anchors before the intermediate groups. Checked the complete set at large and 48-pixel sizes. Sources, exact prompts, provenance, and the contact sheet are saved in `assets/ranks/`.
- Uploaded all twelve as Image assets owned by NOVA's creator (432115180), with every upload reporting Approved moderation. The runtime catalog records the resulting IDs.
- All **57 Luau scripts compiled** and all **81 local logic cases passed**. Rebuilt `build/NOVA.rbxlx` and synced the five changed/new shared/client modules into the open NOVA place.
- In a Studio client, rendered all twelve at 108 and 42 pixels and verified every ImageLabel reported `IsLoaded=true`. Screenshot review confirmed their shared cartoon style and readable silhouettes.
- Verified the Bronze Chevron in the lobby card and centered overhead nameplate. A client-only Master layout preview confirmed the Cosmic Star in both locations and the full Master level-1,000 text fitting the lobby card.
- An isolated result snapshot verified the Cosmic Star on the player's duel panel and XP recap, the Infernal Crown on the rival's panel, and correct completion of the Master level-1,000 recap. All three images loaded and all rank labels fit. Studio output showed no script errors.
- Removed the temporary gallery, restored original client attributes, and returned to the lobby. Confirmed both server and client remained Level 1, Prestige 0; previews did not award progression. Play is running for review. The local place was updated without publishing it.

## Compact level card and progression menu — November 8, 2026

- The 220 × 72 launcher has one image, one numeric level label, and an XP track/fill. Inspected its descendants in Studio: `LevelNumber` was the only TextLabel. XP reward-rate hints, prestige buttons, detailed rank text, and save status were removed from the launcher.
- Generated and uploaded five matching transparent header/status sprites; all reported Approved moderation and loaded in Studio. Sources, prompts, and asset IDs are preserved under `assets/ranks/menu/`.
- All **85 local logic checks passed**, including four new prerequisite/eligibility cases covering all ten prestiges and Master. All four ProgressionInfo cases also passed on the Studio server.
- Exercised the real UI with virtual mouse input: opened the card, switched all three tabs, scrolled the twelve-card collection to Master, inspected its Prestige 10 level-55 requirement, returned to the next available prestige, and closed/reopened. Screenshot review confirmed the header art, rank icons, eligibility messages, and page layouts.
- Checked Settings/progression mutual exclusion, controller RB tab switching, B closing, Y opening, and Escape dismissal. Escape also opened Roblox's own system menu, which is platform behavior.
- Confirmed movement remained zero while holding W with progression open, including a client without a PlayerModule. Closing removed the movement action. Entering an actual empty queue automatically hid the progression GUI and released movement blocking; left that queue through the normal validated input remote and restored the lobby.
- A client-only level-55 preview exercised two-click confirmation and its reset on close. Confirming sent the normal prestige request, which the server correctly rejected because its actual profile was Level 1. Restored all client attributes and confirmed the server remained Level 1, Prestige 0. A missing-level/loading preview also rendered safely with the action disabled.
- The updated local place is running in the lobby for review. No place publishing or live profile changes were performed. Touch gestures and a physical controller were not tested; controller checks used virtual key input.

### Progression panel cleanup and enlargement

Applied the marked-up screenshot: removed the subtitle, completed-prestige statistic, and entire status/control-help footer. Expanded lifetime XP across the available content width. Action responses and load errors remain inline beneath the Requirements action when relevant. The window now scales up to 130%, with a 940 × 550 logical layout that fits inside the viewport. Studio reported a 1222 × 715 displayed panel; screenshot review confirmed all marked areas were absent, the larger text and art fit, and the panel remained centered. The changed script compiled, the standalone place was rebuilt, and Studio output showed no game script errors. Left the enlarged panel open in the local Play session for review; no publishing was performed.

### Studio XP testing command

Added `ServerScriptService.NOVA.TestXP`, a BindableFunction created only inside the Studio branch of ProgressionService. A numeric argument grants that XP; `"cap"` calculates the remaining XP to the current rank's cap without prestiging. In a fresh Studio server, +300 XP reached Level 3 with 75 XP; `"cap"` then reached Level 55 with zero current XP and prestige eligibility. A repeat cap grant gave zero XP, and a negative grant was rejected without altering lifetime XP. The client HUD updated to 55 with a full bar and the Requirements action enabled for Prestige 1. Confirmed no TestXP object exists in ReplicatedStorage.NOVA. Left the session at Prestige 0, Level 55 with Requirements open for the user's prestige test. The script compiled and the standalone place was rebuilt; no live data access or publishing occurred.

### Prestige unlock reveal

- Exported eleven true-grayscale passes for Prestiges 1–10 and Master. Verified equal RGB channels plus unchanged alpha/dimensions for every PNG. All eleven Roblox image uploads reported Approved; sources and asset provenance are in `assets/ranks/reveal/`.
- All 63 Luau scripts compiled, and all 85 existing logic cases passed. The new server response retains its original text and adds rank data only after an actual successful prestige; the client uses that confirmation to start the effect.
- Exercised real two-click prestige requests in Studio. A client-only fake level-55 attempt was rejected without a reveal. Actual cap grants and confirmations unlocked Prestige 1 and then Prestige 2. Observed loaded grayscale with color fully hidden, colorization, an icon peak width of 401 logical pixels, stamp motion, settled full color, and rotating golden rays. The first reveal auto-dismissed and returned to Progress. Screenshot review covered the Silver Bullet and Emerald Dagger effects.
- A third real unlock tested controller Back dismissal, which returned to Progress. An isolated Master preview verified both Master image passes loaded and displayed the correct crest and title without changing the player's actual rank. Removed the preview and all temporary QA render connections.
- Left the session at Prestige 3, Level 55, with Unlock Prestige 4 ready for the user's next test. No publishing or live profile changes were performed.


## Item retirement and editor selection — November 9, 2026

- The local Luau logic suite passes 114 cases, including six retirement cases for ownership/equipment cleanup, duplicate-value credits, notice acknowledgment, repeated validation, UpdateAsync callback retries, failed loads, rejoining and the wallet cap.
- Studio editor callbacks verified rarity + type filtering (eight Rare skins), selecting across three types/filters, protected defaults, confirmation before bulk deletion, hidden-selection reporting and undoing the batch.
- A Studio Play session granted and equipped a Rare cosmetic, then retired it with an owned Epic cosmetic in a temporary server test. The actual inventory service removed both items, restored the default skin and credited 85 Shards. The client automatically opened a notice listing Mint Circuit +25 and Ember Core +60.
- Clicking the actual Got it button acknowledged the notice through the server. It disappeared, and repeating the acknowledgment retained exactly 85 Shards. Catalog changes used by the smoke test were restored; Play was stopped. No live player profiles were accessed.
- Published-server persistence is supported by the existing leased UpdateAsync path and was checked with retrying/failing store fixtures. A real published login after deployment is still needed to verify the production environment.


## Square skin display — November 10, 2026

- `SkinVisuals` reuses the approved square `body-1` atlas; no new bitmap assets or uploads were needed. All 28 existing skins resolve as squares (25 patterned, 3 solid colors). The former skin category, chestplate thumbnails and locked chestplate asset IDs have no runtime references.
- Studio inventory showed loaded square textures on locked cards. Focused Quantum Circuit artwork and its body preview used identical image IDs, 128px crop sizes and offsets.
- Opened a real server-selected test crate through the inventory controls. The received Quantum Circuit skin completed its normal reel/lift/stamp animation with a loaded square image. A temporary Studio-only crate pool ensured that reward and was restored immediately after the check.
- Equipped Quantum Circuit and entered practice through its normal queue pad. The actual square player body loaded the same atlas crop as the preview and unlock. Play was then stopped; no live player profiles or published content were changed.
- The installed Item Editor showed all 28 square skin cards and a visible loaded body texture. The source artwork generator now exports square bodies for the skin category instead of chestplate geometry. Historical originals remain as upload provenance.
