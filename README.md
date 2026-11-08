# NOVA
A private, two-seat platform duel for Roblox desktop. Map 1 is the only arena.

## Architecture decision
NOVA draws native ScreenGui rectangles on a fixed 16:9 stage. A server-owned fixed-step simulation operates in tile units with separate collision masks for bodies and projectiles. This preserves the reference's flat silhouettes, avoids perspective and 3D physics ownership differences, and lets the same collision code run in isolated tests. Roblox characters are disabled. The client sends input edges and displays authoritative snapshots.

## Map reconstruction
The first screenshot (214811) contains 38 columns and 29 rows starting at image pixel (20,9), on a 32-pixel pitch. Coordinates start at the upper left, increase right and down, and mirror across x=19. The two centers start at (6.5,27.5) and (31.5,27.5). Purple bodies occupy the entire outlined tile. The upper rings have different masks on their inner and outer uprights. The original black interior, outline contours, central bridge and staircase floor are built from editable tiles. Yellow and muted green corner squares are visual markers. The colored spawn caps are interpreted as health bars. Two additional low mint strips near the spawns identify the actual launch triggers, which pass bullets and activate once per contact. Side margins contain the duel HUD.

## Match rules
A/D move, W jumps from a surface, S increases airborne downward acceleration. Each left mouse press launches one shot at the opponent's authoritative center when the request arrives. Direction is frozen for the flight. The server accepts increasing integer shot IDs for the current round only. Impacts in the same simulation step are applied together; simultaneous lethal impacts draw. Both players must vote for a rematch. Leave exits the session. A combat disconnect gives the remaining player a win, and they may choose to wait for a new opponent. New arrivals cannot enter an active duel.

## Developer controls
Studio-only diagnostics and automated tests are gated by RunService:IsStudio(). Balance defaults are in ReplicatedStorage/NOVA/Config. The map and tile catalog are adjacent modules. Production has no configuration remote.
