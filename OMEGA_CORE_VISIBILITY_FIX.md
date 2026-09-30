# Omega Core visibility / pickup behavior fix

- Omega Cores are now fixed world drops and never magnetize toward M1 ATLAS.
- The pickup remains at the elite/boss death location until physically collected.
- Increased vertical beacon height and brightness for dense combat readability.
- Added a persistent isometric ground beacon around the exact pickup location.
- Added a small repeating phase-particle flare while the Core is waiting.
- Increased the hard-pixel Core silhouette so it cannot be confused with salvage.
- Changed the Tier III HUD state from `OMEGA READY` to `OMEGA SEEK`.
  `OMEGA SEEK` means Plasma Cleaver III can accept an Omega Core; it does NOT mean a Core already dropped.
- `OMEGA HELD` still means the Core has actually been collected and stored.

Omega Cores are still intentionally cleared during a procedural deck transfer because the old deck is destroyed/regenerated.
