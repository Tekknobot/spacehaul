# Enemy Attack VFX Pass

Godot 4.6.2 hostile attack presentation now uses the same pixel-VFX language as the player abilities.

- Added a shared `enemy_attack_vfx.gd` helper for hard 1 px cores, 2 px additive bloom, isometric ground rings, telegraph lines, muzzle flashes, slashes, bursts, and impact pulses.
- Reused `ability_particle_emitter.gd` for hostile trails and bursts so enemy effects inherit the existing translucent gas envelope rather than introducing a separate particle style.
- Added `bio` and `venom` particle profiles for organic attacks.
- Melee enemies now produce palette-specific pixel slashes and localized impact bursts. Heavy melee types get a stronger isometric impact ring.
- Beetle charge now has a readable additive lane telegraph, a spark/gas launch burst and wake, and can correctly land one hit during the charge itself.
- Ranged beetles/spiders now fire layered hostile pixels with biological/venom/ember gas trails, muzzle bursts, and impact pulses.
- Shock enemies now use 2:1 isometric warning/attack rings, radial spokes, and electric pixel bursts.
- Broodmother egg-lay, spit volley, contact hit, phase pulse, and death presentation were brought into the same VFX system.
- Eggs now leave a short biological pixel/gas trail while being laid, burst on landing, warn shortly before hatching, and burst again on hatch/destruction.
- Hostile projectile trail rates are intentionally lower than player ability bursts to keep dense waves readable and browser-friendly.
