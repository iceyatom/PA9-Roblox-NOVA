# NOVA
A private, two-seat platform duel for Roblox desktop. Map 1 is the only arena.

## Architecture decision
NOVA draws native ScreenGui rectangles on a fixed 16:9 stage. A server-owned fixed-step simulation operates in tile units with separate collision masks for bodies and projectiles. This preserves the reference's flat silhouettes, avoids perspective and 3D physics ownership differences, and lets the same collision code run in isolated tests. Roblox characters are disabled. The client sends input edges and displays authoritative snapshots.

## Map reconstruction
The first screenshot (214811) contains 38 columns and 29 rows starting at image pixel (20,9), on a 32-pixel pitch. Coordinates start at the upper left, increase right and down, and mirror across x=19. The two centers start at (6.5,27.5) and (31.5,27.5). Purple bodies occupy the entire outlined tile. The upper rings have different masks on their inner and outer uprights. The original black interior, outline contours, central bridge and staircase floor are built from editable tiles. Yellow and muted green corner squares are visual markers. The colored spawn caps are interpreted as health bars. Two additional low mint strips near the spawns identify the actual launch triggers, which pass bullets and activate once per contact. Side margins contain the duel HUD.

## Match rules
A/D move, Space jumps from a surface, and gravity brings the player down. Each left mouse press launches one shot at the opponent's authoritative center when the request arrives. Direction is frozen for the flight. The server accepts increasing integer shot IDs for the current round only. Impacts in the same simulation step are applied together; simultaneous lethal impacts draw. Both players must vote for a rematch. Leave exits the session. A combat disconnect gives the remaining player a win, and they may choose to wait for a new opponent. New arrivals cannot enter an active duel.

## Developer controls
Studio-only diagnostics and automated tests are gated by RunService:IsStudio(). Balance defaults are in ReplicatedStorage/NOVA/Config. The map and tile catalog are adjacent modules. Production has no configuration remote.

Press **F4** in a Studio client. **Show masks** displays tile and player bounds, spawn crosses and one-step projectile traces. Click the parameter name to cycle through five settings, then use **+ / −** to adjust the running server. **Set duel lane** moves both players onto the central platform during combat for repeatable shooting tests. The panel records phase changes, tuning and hits. Runtime adjustments last for the current server. Edit the Config source to change future sessions.

## Open and play

Open `build/NOVA.rbxlx` in Studio. For a fresh checkout, run `python tools/build.py` at the repository root to generate that file using Python 3 and its standard library. In Studio, select **Server & Clients**, choose **2 clients**, and start the session. Solo Play intentionally opens a one-player lobby. Use keyboard and mouse or a connected gamepad. Tilt the left stick sideways to move at variable speed. Press Xbox A or PlayStation Cross (×) to jump. Pull RT/R2 once per shot.

## Source-to-Studio mapping

| Repository directory | Studio parent | Responsibility |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.NOVA` | Config, TileCatalog and Map1 |
| `src/server` | `ServerScriptService.NOVA` | Server, Match, Movement, Combat and StudioTest |
| `src/client` | `StarterPlayer.StarterPlayerScripts.NOVA` | Client, Hud, Widgets, Arena, Input and Diagnostics |
| `tests/unit`, `tests/cases` | `ServerStorage.NOVAUnitTest`, its `Cases` folder | Runner, fixtures, performance profile and acceptance cases |
| `tests/integration` | `ServerStorage.NOVATesting` | Multiplayer session driver and per-client input probe |

The build maps `.server.luau` to Script, `.client.luau` to LocalScript and other `.luau` files to ModuleScript. At runtime the server creates State and Input under ReplicatedStorage.NOVA. Each client creates PlayerGui.NOVA. Only a named Studio integration run clones the input probe into test clients.

## Reproduce the MCP deployment

1. Open a baseplate or the generated place. In the Roblox MCP connection, run `list_roblox_studios`, select the intended ID, and check `get_studio_state` for Edit mode.
2. Run `python tools/build.py --sync --service ReplicatedStorage` in this repository. Pass its complete stdout as the `code` argument to the Studio MCP `execute_luau` tool using that ID and the Edit data model.
3. Repeat for `ServerScriptService`, `StarterPlayer` and `ServerStorage`. Each batch checks object class and the NOVAOwned attribute before updating existing objects. Name conflicts stop the batch. The sync uses ScriptEditorService so changes are visible in the editor. Source control is authoritative for NOVA-owned scripts.
4. Run the checks below. For a new online experience use Studio **File → Publish**, select the personal creator and keep the new experience private. For subsequent updates, confirm the intended place and use Publish on that connected place. Only players with access to the private experience can join online. [Roblox publishing guide](https://create.roblox.com/docs/production/publishing/publish-games-and-places)

## Run the acceptance checks

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
