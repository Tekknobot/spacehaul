# Isometric Special Ability VFX Patch

This pass refactors all current LMB/RMB special-ability visuals around one shared 64x32 (2:1) ground projection.

## What changed
- Added `Scripts/isometric_vfx.gd` as the shared projection helper.
- All generated ground rings now use a 2:1 isometric footprint instead of screen-space circles.
- Radial spokes, perimeter impacts, spark blooms, EMP crowns, orbital strike layouts, missile halos, and gravity/phase fields follow the same ground projection.
- Directional fans and parallel-beam spacing are rotated in ground space rather than flat screen space.
- Radial effects now receive the mecha's true deck-contact origin separately from its elevated weapon/muzzle origin.
- Arcing projectiles retain their elevated trajectory and now cast a small moving diamond shadow across the deck.
- Ground rings use deck Y-depth so foreground geometry can naturally cross in front of them.
- Ability particle bursts/trails and the previously added particle gas follow the isometric spread basis.
- Procedural explosion pixels use an isometric ground footprint with a small vertical lift for volume.
- Radial hit tests are filtered against the same projected footprint so the visible field and gameplay field remain aligned.

## Ability coverage
M1 Plasma Cleaver / Repulsor Burst
M2 Vector Harpoons / Anchor Bloom
M3 Comet Mortar / Orbital Rain
R1 Prism Lance / Halo Sweep
R2 Breach Cannon / Countershock
R3 Hunter Missiles / Missile Halo
R4 Arc Cascade / EMP Crown
S1 Photon Rake / Solar Flare
S2 Gravity Well / Mass Ejection
S3 Phase Needles / Phase Bloom
