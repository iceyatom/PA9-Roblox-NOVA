# NOVA inventory sprites

Six original sprites generated with built-in `image_gen`, following the `nova-ui-sprites` skill and its bundled approved `menu-family.png` style reference. These are interface symbols, not final collectible skin artwork.

- `skins.png`: sapphire/violet armored chestpiece.
- `bullets.png`: silver/gold cartridge with cyan inset.
- `tracers.png`: gold shooting star with cyan/violet ribbons.
- `backgrounds.png`: gold-rimmed violet player card.
- `sounds.png`: sapphire speaker with violet sound waves.
- `crates.png`: purple/gold crate, also used by the launcher and reveal header.

Every returned source is 1254 × 1254 RGBA, with genuine transparency. Originals are preserved separately from the review sheet. The skill validator reported no errors for all six runtime PNGs. `review.png` is an opaque contact sheet on NOVA's dark UI at 128 and 48 pixels; it is not a runtime asset. The silhouettes, padding and outline weight were inspected together at those sizes.

`prompts.json` contains the exact per-image prompts and style reference path. `manifest.json` records the creator, completed upload operations, Roblox Image asset IDs, and Approved moderation results. `src/shared/InventoryArt.luau` maps those IDs into the game. All six images were observed with `ImageLabel.IsLoaded == true` in a running Studio client.

Crate motion uses native UI: a horizontal reward strip, a 5.8-second Quint/Out slowdown, and top/bottom mint selection pins. `ReelAudio` plays the same approved click sample as map selection when card centers pass the pins. At landing, `ItemUnlock` animates the received sprite with the prestige lift/grow/stamp motion, squash/rebound, golden aura, counter-rotating rays, impact rings and sparks. The exact received sprite is prepared during the spin; motion starts immediately at landing without a loading pause. Continue appears after the two-second reveal. The result comes exclusively from the server's crate receipt. Closing, changing modes, and changing viewport width cancel the presentation without changing the awarded item. No new bitmap artwork was needed for these effects.
