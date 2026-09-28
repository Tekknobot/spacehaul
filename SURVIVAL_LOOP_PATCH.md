# SPACEHAUL Survival Loop Prototype

This build pivots the procedural deck toward a 20-minute survival run.

- One randomly chosen mecha is spawned per run. The other nine are not present on the deck.
- The chosen mecha is preserved across automatic deck transitions.
- Standard HUD starts hidden. Press U to toggle it.
- Hold LMB / RT for the primary ability. Primary fire uses per-mecha cooldowns.
- Secondary abilities begin locked and come online at 01:30 for mechas that have one. RMB / LT triggers them.
- Mechas now have HULL, damage invulnerability, knockback, death, and a pixel dissolve.
- Enemy spawning is continuous instead of placing a fixed population at generation time.
- The first seconds are quiet, early waves are simple melee enemies, and ranged/charger/shock enemies are introduced later.
- Active enemy caps, spawn batches, spawn speed, enemy health, enemy speed, and elites escalate with run time.
- Enemies spawn on valid walkable cells away from the player and path through the procedural deck.
- Enemies drop glowing SALVAGE pixels. Nearby salvage magnetizes to the player.
- SALVAGE levels the run and opens a three-choice upgrade panel.
- Current upgrades: primary cooling, secondary cooling, impact radius, hull plating, movement speed, field repair, salvage magnet range.
- The run automatically generates a fresh procedural deck every four minutes and repairs 10 HULL during the transition.
- The target run length is 20 minutes. Spawning stops on extraction completion or player death.
- Press G after death/completion to generate a new deck and begin a new run with a new random mecha.

Enemy art still uses the corrected left-facing default: moving right mirrors the authored sprites.
