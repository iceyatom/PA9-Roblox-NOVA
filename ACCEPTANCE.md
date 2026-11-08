# NOVA v1 acceptance record

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
