# SpaceMECHA Deck Transition + Palette Pass

This patch replaces the instant deck snap with a short cinematic transfer:

- Gameplay/enemies freeze during transfer.
- Camera pushes in to 1.22x.
- Player uses a pixel dissolve/phase shader to teleport out.
- The procedural deck regenerates while the transfer overlay masks the camera relocation.
- Player reconstructs with a reverse dissolve plus a slight vertical reanimation stretch.
- Camera eases back to normal and gameplay resumes.
- HUD dims during the transfer and the banner reports the incoming deck palette.

## Deck palette shader

The procedural floor and wall sprites now share a hard palette-remap canvas shader. Colors are sampled from the supplied SpaceMECHA palette references rather than introducing unrelated hues.

Deck sequence for a standard 20-minute run:

1. STEEL
2. INDUSTRIAL
3. CRYO
4. VOID
5. MONO

The palette cycles if more decks are ever added. Saturated authored signal pixels (hazards/lights/wall accents) are remapped to the active palette accent so warning/light details remain readable.

## Files changed

- `Scripts/test_world.gd`
- `Scripts/mecha_controller.gd`
- `Scripts/procedural_deck.gd`

No sprite assets were resampled or recolored destructively; the deck color treatment is shader-driven.
