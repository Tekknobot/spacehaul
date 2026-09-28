# SPACEHAUL targeting + HUD patch

## Arc targeting
The three cursor-fired primary abilities that use curved world-space trajectories now soft-lock to the nearest living enemy close to the aim point, as long as that enemy is inside the weapon's range:

- M3 COMET MORTAR
- R3 HUNTER MISSILES
- S2 GRAVITY WELL

A small 1px-core / 2px-bloom lock reticle confirms acquisition. The projectile continues tracking that enemy while it is in flight, then triggers the existing explosion impact at the final position. If no enemy is close enough to the cursor, the ability still lands on the exact selected ground point.

R3 was renamed for readability:
- SWARM RACK -> HUNTER MISSILES
- FLAK DOME -> MISSILE HALO

## HUD
The old title, subtitle, controls panel, left debug panel, and bottom ability-status strip are permanently hidden.

TAB toggles a compact top stat row. It starts hidden and contains only:
- chassis
- hull
- level
- salvage
- run time
- deck
- current enemy count

Hull changes from green to amber to red as damage increases. Other fields use restrained chassis/salvage/time/deck/enemy accent colors.

The temporary secondary unlock message is now generic: `SECONDARY ONLINE   RMB`.
