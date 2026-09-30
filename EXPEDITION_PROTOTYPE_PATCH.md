# SpaceMECHA Single-Deck Expedition Prototype

This prototype changes the default run from a timed multi-deck survivor loop into one procedural deck expedition.

## Flow
1. Deploy into one generated deck.
2. Explore the ship. The minimap reveals nearby walkable cells and entered rooms.
3. Secure four marked rooms by remaining inside each for 1.5 seconds:
   - ARMORY: evolves the primary ability (or improves primary cooling if capped).
   - REPAIR BAY: adds 25 max hull and repairs the chassis.
   - DATA CACHE: grants enough salvage to trigger a normal level-up choice.
   - REACTOR: unlocks/evolves the secondary system (or improves secondary cooling if capped).
4. Once all four are secured, locate the HIVE.
5. Entering the HIVE spawns the Broodmother at the room center.
6. Defeating the Broodmother unlocks EXTRACTION.
7. Reach the extraction room to complete the expedition.

## Structural changes
- `expedition_mode` is enabled by default on `test_world.gd`.
- The automatic four-minute deck transfer and 20-minute automatic victory are disabled while expedition mode is active.
- Time still advances for combat escalation, salvage progression, OMEGA timing and enemy composition.
- The old survivor loop remains in the scripts and can be restored by disabling `expedition_mode`.
- The timed Broodmother director is disabled during expedition mode; the boss is objective-controlled instead.
- Special rooms are selected from generated rooms each deck. The Hive is placed far from deployment, while Extraction is selected far from the Hive to create an escape traversal.

## New file
- `Scripts/expedition_minimap.gd`

## Primary modified files
- `Scripts/test_world.gd`
- `Scripts/procedural_deck.gd`
- `Scripts/enemy_manager.gd`
