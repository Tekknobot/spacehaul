# SPACEHAUL special ability port

The ten mechas now use mechanics/visual patterns ported from the supplied reference scripts.

Controls:
- LMB / RT: primary special
- RMB / LT: secondary special directly, where the reference mech has one

Mapping:
- M1: Sunder / Slam
- M2: Pounce
- M3: Artillery Strike / Laser Sweep
- S1: Laser Grid / Overcharge
- S2: Quake
- S3: Nova / Web
- R1: Ninefold Volley
- R2: Cannon
- R3: Barrage / Railgun
- R4: Malfunction / Storm

The port preserves the important presentation language from the references: Line2D beams, staggered impacts, parabolic artillery/missile arcs, sky strikes, grid detonations, ripple/starburst patterns, web tethers, cone beams, explosive splash patterns, and spiral/ring sequencing. The visuals are rebuilt procedurally for SPACEHAUL's continuous-world movement and pixel aesthetic.


Impact VFX:
- Every special impact now layers the 14-frame `Sprites/VFX/Explosion/explosion1.png` through `explosion14.png` animation over the existing procedural additive explosion, damage radius, line effects, trails, and arc mechanics.
