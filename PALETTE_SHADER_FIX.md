# SpaceMECHA palette shader visibility fix

- Moved the deck grade into `Shaders/deck_palette.gdshader` so it is visible/editable as a normal Godot shader resource.
- Removed the hard luminance-band replacement that was crushing imported texture colors toward black.
- Deck 1 now uses the authored tile colors exactly (`grade_strength = 0.0`).
- Decks 2+ preserve each source pixel's brightness/value while transferring the selected deck palette hue/saturation.
- Colored hazard/light/signal pixels retain their original brightness while changing to the active deck accent.
- Near-black outline pixels remain unchanged so pixel-art structure stays crisp.
