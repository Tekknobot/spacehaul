# Controller Spawn + Isometric Aim Pointer Patch

- Controller deploy remains **START**; A is gameplay dash only.
- Mouse click, keyboard Enter and controller START now enter one deferred deploy request path.
- Gameplay remains paused while the procedural deck and selected mecha are rebuilt.
- The new active mecha is snapped again to `ProceduralDeck.spawn_position` after one process-frame boundary, then gameplay is unpaused. This prevents controller input-dispatch timing from changing the initial player state or position.
- The aim marker is now a compact faceted isometric spear/chevron. Its parent polygon still rotates from the exact live attack vector, and a lower facet/ridge provide isometric depth without changing aim precision.
