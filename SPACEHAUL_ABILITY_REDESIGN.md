# SPACEHAUL Ability Redesign

This pass removes the inherited ZombieMECHA specials and gives every chassis a SPACEHAUL-specific primary and secondary ability.

## Pixel VFX rule
All generated core effects are 1x1 world pixels. Additive bloom is limited to 2x2 around that pixel or a 2-pixel-wide glow line behind a 1-pixel core line. Positions are rounded to whole world pixels. The project uses nearest texture filtering and canvas-item stretch, so these generated pixels scale with the native mecha sprite pixels under camera/window scaling. The authored explosion animation remains at native 1:1 scale; larger impacts are communicated with generated pixel radius and extra impacts rather than fractional scaling.

Every impact still uses the existing 14-frame explosion animation plus the generated additive pixel burst.

## Chassis abilities and upgrades

### M1
Primary: PLASMA CLEAVER - short forward crescent that slices a wide crowd lane.
1. Wider Edge: more arc teeth and width.
2. Twin Edge: adds a second outer cleave.
3. Return Cut: adds a fast back-swing cleave.
Secondary: REPULSOR BURST - 360-degree radial shove with spoke impacts.
1. More spokes and range.
2. Adds a second pulse ring.
3. Adds a third overshock ring.

### M2
Primary: VECTOR HARPOONS - narrow fan of glowing tether bolts that damage along their full paths and pop on impact.
1. Five tethers.
2. Seven tethers.
3. More range and impact coverage.
Secondary: ANCHOR BLOOM - collapsing rings pull enemies inward, then release them in an explosive pulse.
1. Larger pull field.
2. Extra collapse step.
3. Larger final release.

### M3
Primary: COMET MORTAR - high arcing shell followed by radial shrapnel impacts.
1. Two extra shrapnel lines.
2. Four extra shrapnel lines.
3. Delayed second core detonation.
Secondary: ORBITAL RAIN - ring of sky strikes centered around the player for emergency clearance.
1. Four extra strikes.
2. Eight extra strikes.
3. Twelve extra strikes and more radius.

### R1
Primary: PRISM LANCE - several parallel precision beams with small terminal detonations.
1. One extra lance.
2. Two extra lances.
3. Endpoint refraction cross-bursts.
Secondary: HALO SWEEP - radial beam halo around the chassis.
1. More spokes.
2. Adds a second rotated sweep.
3. More range and spokes.

### R2
Primary: BREACH CANNON - a heavy piercing line, large terminal impact, and rearward metal-like splinters.
1. More splinters.
2. Larger impact and reach.
3. Maximum splinter count.
Secondary: COUNTERSHOCK - heavy radial cannon blasts from the player.
1. Six directions.
2. Eight directions.
3. Ten directions and more range.

### R3
Primary: HUNTER MISSILES - compact arcing missile cluster around the aimed zone.
1. Four missiles.
2. Five missiles.
3. Six missiles and more reach.
Secondary: MISSILE HALO - arcing missiles launch from the player and detonate around a protective ring.
1. More flak missiles.
2. More flak missiles and radius.
3. Maximum dome density and radius.

### R4
Primary: ARC CASCADE - real enemy-to-enemy chaining lightning; if no target is found it discharges toward aim.
1. More chain hops.
2. More chain hops and jump range.
3. Maximum hop count and arc reach.
Secondary: EMP CROWN - jagged expanding EMP rings around the player.
1. Adds a wave.
2. Adds another wave.
3. Maximum ring density and coverage.

### S1
Primary: PHOTON RAKE - parallel hot beams that rake a corridor and explode at their endpoints.
1. More beams.
2. More beams.
3. Maximum beam count and reach.
Secondary: SOLAR FLARE - full radial laser flare with terminal explosions.
1. More radial beams.
2. More radial beams.
3. Maximum beam count and range.

### S2
Primary: GRAVITY WELL - arcing gravity seed, collapsing pixel rings, inward pull, then impact detonation.
1. Larger gravity field.
2. Extra collapse step.
3. Second implosion pulse.
Secondary: MASS EJECTION - pulls the nearby swarm inward before violently ejecting it away from the player.
1. Larger field.
2. Larger impact field.
3. Maximum crowd-clear radius.

### S3
Primary: PHASE NEEDLES - fan of dotted phase traces that pass through a lane and detonate at range.
1. Seven shards.
2. Nine shards.
3. Eleven shards with wider coverage.
Secondary: PHASE BLOOM - repeated phase rings, pixel afterimages, and perimeter impact explosions around the player.
1. Second wave.
2. Third wave.
3. Fourth wave with maximum density.

## Upgrade model
Each primary and secondary has three chassis-specific evolution tiers. They are added directly to the salvage level-up pool alongside cooldown, impact radius, hull, servo, repair, and salvage magnet upgrades. The primary evolution is available immediately; the secondary evolution enters the pool only after the secondary system unlocks.


## ARC TARGETING UPDATE
M3 COMET MORTAR, R3 HUNTER MISSILES, and S2 GRAVITY WELL now soft-lock the nearest living enemy close to the cursor and within weapon range. Their 1px arcing projectiles track that target during flight, then use the existing explosion impact. If no enemy is near the cursor, they still fire at the exact ground point selected by the player.
