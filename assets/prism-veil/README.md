# Prism Veil

Original 2D cosmetic pack made in Blender from the supplied pearlescent rifle reference. The palette follows its pearl white, icy cyan, orchid/pink, mint edge light and small warm-gold accents. The weapon itself is not reproduced.

- `Prism Veil.blend`: editable orthographic scenes for Skin, Bullet, Tracer, Background and Pack Preview. Original pre-existing Blender scenes were preserved. Frame 1–48 is a two-second loop at 24 FPS.
- `exports/Prism Veil.gif`: animated pack presentation.
- `exports/pack-preview.png`: still presentation.
- `exports/skin-atlas.png`: 16 distinct Blender-rendered 256px skin frames in a 1024px 4×4 atlas; runtime 8 FPS for a two-second loop.
- `exports/bullet.png`: 256px circular pearl pulse, transparent outside the circle.
- `exports/background.png`: 1024×512 prismatic sky.
- `exports/tracer.png`: review/thumbnail only. This is **not** the runtime trail.
- `source/build_blender.py`: original mesh, material and keyframe authoring code. `source/render.py`: Blender render runner.

The bullet’s highlight turns while its outline remains circular. The square skin silhouette stays fixed. Its glass quadrants translate inside the body, the central four-facet reactor rotates, and small shards orbit internally. The background adds slow glass drift and a spectral sweep. The bullet remains circular.

## Live tracer

`src/shared/PrismVisuals.luau` builds three moving ribbons from native UI geometry, layered glow, travelling glass shards and drifting sparks. It continuously computes positions/angles during flight; no tracer images or animation sheets are sampled. Each projectile gets a different phase. Reduced Effects and high simultaneous trail counts use a smaller object set. Hidden/clipped previews skip updates, pooled trails clear prior effect children, and destroyed roots unregister their animation.

The same renderer is wired into arena shots, practice, item previews, the editor and backgrounds. Skin and background animation use the same theme in every view. Combat statistics are unchanged.

## Integration status

The three creator-owned texture uploads completed and passed moderation. `PrismAssets.luau` contains the approved IDs; all four items are enabled in the catalog. The source is synchronized to the connected Studio place, and the installed Item Editor supports the animated pack. Publishing the place remains a separate action.

| Texture | Approved image ID |
| --- | --- |
| Animated skin atlas | `126807824700501` |
| Circular bullet | `108373091188666` |
| Prismatic sky | `93677618801522` |

Stable item IDs:

| Type | ID | Name |
| --- | --- | --- |
| Skin | `skin_prism_veil` | Prism Veil |
| Bullet | `bullet_prism_pearl` | Prism Pearl |
| Tracer | `tracer_prism_flow` | Prism Flow |
| Background | `card_prismatic_sky` | Prismatic Sky |

They are Legendary cosmetics and can be added to any crate through the Item Editor. This pack is not automatically inserted into existing loot pools. Publishing a place is a separate step.

## Verified

- Blender `.blend` saved, five component/presentation scenes, 48-frame animated review rendered.
- All 16 skin frames have different pixel data and retain the same outer square bounds.
- Live Studio Edit-mode tracer preview moved its shards and ribbons over time, with 169 native descendants in the full effect (including corner/facet helpers).
- All three textures passed moderation and loaded in real Studio views. The skin’s atlas crop advanced over time in both the editor and inventory; the background’s live crystal positions changed.
- A real practice Fire-button press increased the server score and produced moving native ribbons/shards. The trail Image property stayed empty. An isolated arena renderer verified the circular bullet texture, rotation and pooled-trail reuse.
- A real server-selected crate reward displayed the animated skin through the normal reel/lift/stamp flow. The temporary Studio-only crate pool used for that check was restored.
- Existing Luau logic suite: 114 passed. Test grants were Studio-session-only; no live profiles were changed. Physical-device performance and a production-server check remain separate acceptance work.
