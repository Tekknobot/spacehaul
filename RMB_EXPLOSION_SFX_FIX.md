# SpaceMECHA RMB explosion SFX fix

- Audited all ten secondary / RMB abilities against `SpacehaulSpecialExplosion` playback.
- Kept dense decorative explosion carpets mostly silent so a radial barrage does not stack dozens of identical samples.
- Added an opt-in audio flag to `_ability_impact_fx()` for representative detonation beats.
- HALO SWEEP now plays one controlled explosion voice per propagating annular ring.
- ANCHOR BLOOM release waves now play one perimeter detonation voice per release.
- COUNTERSHOCK Tier III perimeter finisher now has an audible detonation beat.
- FLAK DOME Tier III perimeter finisher now has an audible detonation beat; dive impacts remain audible through `_explode()`.
- SOLAR FLARE corona waves now gain a delayed representative explosion voice after the ignition sound, avoiding the shared 95 ms retrigger guard.
- MASS EJECTION release waves now play one perimeter detonation voice per ejection.
- REPULSOR BURST, ORBITAL RAIN, EMP CROWN and PHASE BLOOM already used audible `_explode()` paths and were preserved.
- The existing shared 95 ms explosion retrigger protection remains intact.
