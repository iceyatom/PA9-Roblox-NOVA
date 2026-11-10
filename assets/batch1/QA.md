# NOVA Items Batch 1

The collection contains 25 matching sets across skins, bullets, tracers, player-card backgrounds and shot accents. The 125 stable item IDs and the separate `crate_batch1` container follow the supplied catalog. Open **Inventory** in the lobby to browse the pieces, including locked items. Use the server-only `GrantInventory` Studio fixture to try them without earning them. Normal Studio inventory lasts for the current session.

## Art and audio

- `source/NOVA Batch 1.blend` contains isolated set collections, named meshes, cel materials and a 512-pixel orthographic camera. The camera starts on Mint Circuit Shell. The collections include square body overlays, shells, projectiles, trails, player cards and speakers.
- `source/illustrate.py` and `source/card_scenes.py` define the original geometry. Python rasterizes the same layers used by the Blender scene, with supersampling and transparent padding. `exports/` contains individual runtime-ready PNGs. `delivery/` contains the shared Roblox atlases and shot bank. Texture offsets are resolved from stable set indices.
- `masters/` contains 25 original mono, 44.1 kHz WAVs. `source/synthesize.py` defines their oscillator, noise and envelope patches. The game selects a bounded region of a single uploaded sound bank. The accents span 0.13–0.35 seconds. The measured peak is at most 0.72 full scale. The eight-voice limiter steals the oldest accent first.
- `manifest.json` records Roblox IDs, upload operations, moderation, dimensions, pivots and earlier background revisions. `anchors.png` and `collection.png` are local review sheets.

## Verification

| Check | Observed result |
| --- | --- |
| Local Luau suite | 102 passed. Includes all 10,000 rarity draws, 125 reachable category/set combinations, every duplicate payout, expired request rejection and a seeded million-roll smoke check. |
| Studio unit suite | 109 passed. Includes existing progression, legacy inventory, match and practice coverage, committed-write/acknowledgment loss, lease reload, and overlapping inventory mutations against isolated stores. |
| Real two-client Studio session | The winner earned one chest in round one and a second in a normal rematch. The losing player earned zero. Save for later preserved the first chest. Open now returned to the lobby, consumed one chest, persisted one session receipt and showed the reduced-motion reward. A playing-phase disconnect produced a victory with zero chests. |
| Existing multiplayer regression | Four Studio clients ran two isolated live lobbies. The existing inventory, legacy cosmetics, crate retry, rebinding, hit, rematch and disconnect assertions passed. |
| Asset delivery | A real Roblox client loaded all 23 approved images/atlases and the complete approved audio bank, including the final background and body designs. |
| Full-motion reveal | Opened the chest through its inventory detail control. The reel and stamp settled on the server receipt’s Orbital Deck artwork and displayed its 25-Shard duplicate payout. |
| Artwork | Verified 125 different 512 × 512 RGBA thumbnails, clear alpha bounds, 25 widescreen card exports and 25 tracer sheets. Reviewed the icons on dark backgrounds at 32, 48, 64 and larger preview sizes. |
| Practice | Two consecutive 30-second practice sessions each accepted 30 shots. The local client loaded the equipped Crimson Singularity body, bullet and animated trail, selected the Horizon Pulse region beginning at 24 s in the audio bank, and finished with the same chest quantity and Shards. |
| Desktop Studio stress | Windows PC, Intel Core i7-13700KF and GeForce RTX 4070. A 60-second, 1886 × 1113 Studio viewport run simulated 200 simultaneous Cosmic projectiles across 20 round resets. All 200 cores remained present, peak pooled trails were 128 and teardown left zero active trails. The first run measured 0.58 ms renderer p95 and 17.84 ms total-frame p95. After switching quality based on two-second frame windows and capping Reduced Effects at 64 active trails, the final run measured 0.38 ms renderer p95 and 17.85 ms total-frame p95. Total frame time remained above the proposed 16.7 ms desktop target. |
| Headless automation stress | The Studio test client reported a 1 × 1 viewport. The 60-second fixture passed core-count, pool and reset checks. Its frame timings are unsuitable for device acceptance. |

The multiplayer test runs from Studio Edit with `game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(1,"NOVA/batch1")`. The synthetic rendering fixture uses the same entry point with `"NOVA/batch-stress"`.

## Outstanding acceptance checks

Physical mobile and console runs, hardware controller/touch navigation, the exact 1920 × 1080 desktop target, comparative texture-memory measurements, and controlled published-server persistence/reconnect tests remain open. Studio uses session storage. A crash before a successful inventory write can lose an uncommitted win. Successful openings and win receipts share their inventory write, and the UI reports an award only after acknowledgment.

The connected place was edited in Studio. This delivery does not publish a place version.
