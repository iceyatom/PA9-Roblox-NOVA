# Prestige reveal passes

These eleven grayscale PNGs are animation passes derived from the original Prestige 1–10 and Prestige Master artwork. Each uses ITU-R 601 luminance with the source alpha channel and dimensions retained exactly. Original color PNGs are unchanged. Channel equality and matching alpha were verified for every export, so the paired images align during the UI crossfade.

`manifest.json` records each source, derivative filename, upload operation, approved Roblox image ID, and creator ownership. The runtime map is `src/shared/PrestigeRevealArt.luau`.

`src/client/PrestigeReveal.luau` draws the gold aura, counter-rotating radial rays, impact rings, sparks, shadow, and flash with native UI elements. It layers each grayscale pass with the original full-color icon and animates opacity, scale, position, rotation, and a small impact squash. No generated animation frames or third-party glow textures are required.

ProgressionMenu preloads the selected target's pair. Only a successful server prestige response containing the new rank starts the reveal. Missing image loads have a bounded wait, duplicate rank reveals are ignored, and closing the parent panel or entering a challenge disconnects the animation. Continue or controller Back dismisses it; it also fades out automatically and returns to Progress.
