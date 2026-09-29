SPACEMECHA LAST PALETTE PASS

This pass changes the procedural floor renderer so palette shaders are applied to real Sprite2D tile nodes at runtime instead of relying on a material attached to ProceduralDeck custom draw calls.

Runtime behavior
- P still performs the full deck transfer and cycles through all five deck palettes.
- Deck 1 uses the authored original colors.
- Decks 2 through 5 create a fresh ShaderMaterial and bind it directly to every floor and wall Sprite2D after regeneration.
- The palette shader preserves source luminance while changing the color family.
- A mild root modulation is also used as a renderer-safe fallback so a palette change is still visually obvious without crushing brightness.
- Spawn pad and hazard outlines use the active deck accent color.
- Decorative slash characters were removed from the deck transition banner.

Palette order
1 STEEL
2 INDUSTRIAL
3 CRYO
4 VOID
5 MONO
