# SPACEHAUL enemy population patch

Sprites/Enemies contains ten authored 256x32 strips. Each strip is treated as eight 32x32 animation frames and is used at native resolution with nearest filtering.

## Population
- 60 hostiles are distributed across non-hazard walkable deck cells on each generated deck.
- Enemies stay at least 7 cells from the central spawn area.
- Regenerating the deck destroys the old population and creates a new deterministic population for the new deck seed.
- The HUD reports the current hostile count.

## Archetypes
- alien_1: stalker / melee hunter
- beetle_1: armored charger with a one-pixel charge telegraph
- beetle_2: ranged acid spitter
- bug_1: fast skirmisher
- bug_2: very fast hunter
- bug_3: short-range radial shocker
- bug_4: slow high-health brute
- spider_1: swarm runner
- spider_2: ranged hunter
- spider_3: ranged sentinel that fires a two-shot burst

All enemies use the deck's generated walkability through a shared AStarGrid2D path grid, so they can move around rooms and corridors instead of only steering in a straight line.

## Damage / death
Player special-ability radius queries now include hostile collision layer 2. Enemies expose `take_projectile_hit()` so existing ability impacts damage them without replacing the existing VFX.

Hurt reactions include knockback, a one-pixel positional jolt, and a short HDR color flash. On death, collision shuts off and the current 32x32 frame dissolves with a true texture-pixel threshold shader. Small hard-edged death pixels peel away during the dissolve.
