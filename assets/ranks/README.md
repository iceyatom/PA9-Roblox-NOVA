# NOVA prestige artwork

Twelve original transparent PNG icons, generated with the built-in image_gen tool from the cartoon shop UI art direction supplied in the chat. Each was generated separately, starting with Prestige 0, Prestige 5, and Master, then reviewing the intermediate groups and all twelve together at display sizes. The source PNGs retain their original alpha and resolution.

| Rank | Item | File |
| --- | --- | --- |
| 0 | Bronze Chevron | source/prestige-00.png |
| 1 | Silver Bullet | source/prestige-01.png |
| 2 | Emerald Dagger | source/prestige-02.png |
| 3 | Sapphire Shield | source/prestige-03.png |
| 4 | Amethyst Axe | source/prestige-04.png |
| 5 | Ruby Warhammer | source/prestige-05.png |
| 6 | Lightning Trident | source/prestige-06.png |
| 7 | Crystal Scepter | source/prestige-07.png |
| 8 | Infernal Crown | source/prestige-08.png |
| 9 | Void Phoenix | source/prestige-09.png |
| 10 | Celestial Dragon | source/prestige-10.png |
| Master | Cosmic Star | source/prestige-master.png |

`prompts.json` records every final generation prompt, file size, and alpha bounds. `contact-sheet.png` shows all twelve on a dark background, large and at 48 pixels. It is a review artifact, not a runtime sprite atlas.

`manifest.json` records the Roblox image IDs, upload operation IDs, creator, and moderation state observed during upload. All twelve were uploaded as Image assets owned by NOVA's creator, user 432115180, and approved by Roblox.

The runtime catalog is `src/shared/RankIcons.luau`. `src/client/RankIcon.luau` renders the selected image with a transparent background and Fit scaling. The same selection is used by the lobby card, overhead nameplates, duel seats, and XP recap. An icon represents a prestige, while the numeric level remains text. Prestige 10 and Prestige Master have separate icons. Unknown/unloaded progression hides the icon and retains the UI's loading text. Images load on demand rather than preloading every rank on join.

To replace an icon, keep the original, generate a new sibling PNG, upload it to the same creator, verify moderation and in-game loading, then update the catalog and manifest. Rebuild the place and sync the changed catalog/client scripts to the open Studio place. Uploading icons does not publish the place.
