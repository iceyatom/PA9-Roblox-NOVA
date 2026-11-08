# Progression menu sprites

Five original transparent PNGs created individually with the built-in image_gen tool to match NOVA's prestige art: dark outlines, large glossy facets, saturated jewel colors, and chunky cartoon silhouettes.

- `menu-progress.png`: cyan XP crystal, ascending violet bars, golden arrow.
- `menu-prestiges.png`: violet collection book and golden star medallion.
- `menu-requirements.png`: golden key over a sapphire checklist.
- `menu-locked.png`: silver closed padlock.
- `menu-unlocked.png`: mint checkmark on a gold-rimmed emerald shield.

`prompts.json` preserves the exact final generation prompts. `manifest.json` records Roblox upload operations, image IDs, creator ownership, and Approved moderation for all five. `contact-sheet.png` is a review preview; the original transparent PNGs are used individually at runtime.

`src/shared/ProgressionArt.luau` maps the approved images to the menu. The first three sprites appear beside tab and section headings. The lock and shield badge indicate rank/requirement states. No image text or baked-in level numbers are used.
