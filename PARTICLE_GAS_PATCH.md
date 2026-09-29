# Special Ability Particle Gas Patch

- Added a compact hazard-style gas envelope to every particle drawn by `ability_particle_emitter.gd`.
- Gas remains attached to each moving pixel and trails it by roughly 1-2 world pixels.
- Cloud size is scaled by particle profile: sparks/electric stay tight; exhaust, ember, solar, and gravity are slightly fuller.
- Gas uses the ability's own hue at restrained hazard-cloud alpha instead of copying the hazard tile's red color.
- Manual floating spark pixels spawned by `_spark_pixels()` now opt into the same gas treatment through `special_projectile.gd`.
- Static dotted traces and normal projectile cores remain unchanged.
