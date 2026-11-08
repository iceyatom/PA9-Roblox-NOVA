# NOVA v1 acceptance record

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
