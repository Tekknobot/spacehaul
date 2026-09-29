# FloorTiles integration

The procedural deck now uses the dedicated environment folders:

- `Sprites/Tiles/FloorTiles/floor_base_01.png` through `floor_base_16.png`
- `Sprites/Tiles/WallTiles/wall_1.png` and `wall_2.png`

The legacy floor assets directly under `Sprites/Tiles/` are no longer referenced by `procedural_deck.gd`.

Hazards are no longer represented by a dedicated hazard floor texture. A hazard cell keeps its randomly selected FloorTiles texture and receives a runtime overlay consisting of a faint filled diamond, outline, and cross marker. Hazard collision/damage behavior is unchanged.

The existing runtime deck palette shader and P-key deck cycling remain in place and apply to the new floor and wall sprites.
