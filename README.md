# NOVA
A Roblox platform duel with automatic two-player lobbies. Each server can host multiple independent Map 1 duels.

Players spawn as normal Roblox characters in a dark 3D lobby (`Workspace.NOVALobby`). Walking onto the lime queue pad removes the character and enters Map 1 matchmaking. Queued players join the oldest lobby waiting for an opponent. A third player starts another lobby, a fourth joins them, and so on up to the Roblox server player limit. Each lobby owns its countdown, movement, health, shots, results and rematch votes. The HUD shows the assigned lobby number. Completed duels keep their seats for rematch decisions. After a combat disconnect, the survivor sees Victory and can choose Find new rival to wait for another opponent. Empty lobbies are removed. Waiting players from separate lobbies pair automatically when a seat opens.

Clients send their assigned lobby ID and round with each gameplay intention. The server checks both against the sender's actual membership. Snapshots and Studio tuning events reach only the members of that lobby. Leave queue (while waiting) and Lobby (after a result) respawn the player in the 3D lobby.

## Architecture decision
NOVA draws native ScreenGui rectangles on a fixed 16:9 stage. A server-owned fixed-step simulation operates in tile units with separate collision masks for bodies and projectiles. This preserves the reference's flat silhouettes, avoids perspective and 3D physics ownership differences, and lets the same collision code run in isolated tests. Roblox characters exist only in the 3D lobby; queued and dueling players have none. The client sends input edges and displays authoritative snapshots.

## Map reconstruction
The first screenshot (214811) contains 38 columns and 29 rows starting at image pixel (20,9), on a 32-pixel pitch. Coordinates start at the upper left, increase right and down, and mirror across x=19. The two centers start at (6.5,27.5) and (31.5,27.5). Purple bodies occupy the entire outlined tile. The upper rings have different masks on their inner and outer uprights. The original black interior, outline contours, central bridge and staircase floor are built from editable tiles. Yellow and muted green corner squares are visual markers. The colored spawn caps are interpreted as health bars. Two additional low mint strips near the spawns identify the actual launch triggers, which pass bullets and activate once per contact. Side margins contain the duel HUD.

## Match rules
A/D move, Space jumps from a surface, and gravity brings the player down. Each left mouse press launches one shot at the opponent's authoritative center when the request arrives. Direction is frozen for the flight. The server accepts increasing integer shot IDs for the current round only. Impacts in the same simulation step are applied together; simultaneous lethal impacts draw. Both players must vote for a rematch. Lobby returns the player to the 3D lobby. A combat disconnect gives the remaining player a win, and they may choose to wait for a new opponent. New arrivals cannot enter an active duel.

## Developer controls
Studio-only diagnostics and automated tests are gated by RunService:IsStudio(). Balance defaults are in ReplicatedStorage/NOVA/Config. The map and tile catalog are adjacent modules. Production has no configuration remote.

Press **F4** in a Studio client. **Show masks** displays tile and player bounds, spawn crosses and one-step projectile traces. Click the parameter name to cycle through five settings, then use **+ / −** to adjust the running server. **Set duel lane** moves both players onto the central platform during combat for repeatable shooting tests. The panel records phase changes, tuning and hits. Runtime adjustments last for the current server. Edit the Config source to change future sessions.

## Open and play

Open `build/NOVA.rbxlx` in Studio. For a fresh checkout, run `python tools/build.py` at the repository root to generate that file using Python 3 and its standard library. In Studio, select **Server & Clients**, choose **2 clients**, and start the session. Solo Play intentionally opens a one-player lobby. Use keyboard and mouse or a connected gamepad. Tilt the left stick sideways past its dead zone to move at full speed. Releasing or reversing horizontal input stops or reverses movement on the next simulation tick, including in midair. Press Xbox A or PlayStation Cross (×) to jump. Pull RT/R2 once per shot.

Player positions display directly from server updates at 60 Hz. Jumps immediately apply their configured upward impulse and then follow gravity. Network travel time still affects when an input reaches the authoritative simulation.

Hold Space or Xbox A / PlayStation Cross (×) to jump again automatically whenever the player lands on a solid surface. Release to finish the current arc and stop jumping. A short tap performs one jump. Opening the Roblox menu, losing focus or disconnecting the controller clears held input.

## Source-to-Studio mapping

| Repository directory | Studio parent | Responsibility |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.NOVA` | Config, TileCatalog and Map1 |
| `src/server` | `ServerScriptService.NOVA` | Server, LobbyWorld, Lobbies, Match, Movement, Combat and StudioTest |
| `src/client` | `StarterPlayer.StarterPlayerScripts.NOVA` | Client, Hud, LobbyHud, Widgets, Arena, Input and Diagnostics |
| `tests/unit`, `tests/cases` | `ServerStorage.NOVAUnitTest`, its `Cases` folder | Runner, fixtures, performance profile and acceptance cases |
| `tests/integration` | `ServerStorage.NOVATesting` | Multiplayer session driver and per-client input probe |

LobbyWorld builds `Workspace.NOVALobby` and the night lighting at server start unless the place already contains a NOVALobby, so a hand-edited lobby in Studio is kept. The build maps `.server.luau` to Script, `.client.luau` to LocalScript and other `.luau` files to ModuleScript. At runtime the server creates State and Input under ReplicatedStorage.NOVA. Each client creates PlayerGui.NOVA. Only a named Studio integration run clones the input probe into test clients.

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
