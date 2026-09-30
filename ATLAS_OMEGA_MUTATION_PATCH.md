# M1 ATLAS OMEGA MUTATION PROTOTYPE

This build adds the first Legendary Mutation vertical slice for SpaceMECHA.

## Acquisition loop
- Elite enemies become eligible to drop an Omega Core from roughly 4:30 onward.
- A dropped core is intentionally unmistakable: magenta/white procedural core, vertical loot beam, orbiting line fragments, additive bloom and phase-pixel burst.
- The player can carry one Omega Core.
- ATLAS must have PLASMA CLEAVER at Tier III before mutation can occur.
- If the core is collected early it is stored, and the Legendary menu opens as soon as Plasma Cleaver reaches Tier III.
- The HUD reports OMEGA -- / OMEGA READY / OMEGA CORE / the active Legendary name.
- The Broodmother can also satisfy a due Omega drop window.

## M1 ATLAS Legendary Evolutions
1. OMEGA EDGE — Three colossal long-range cleaves tear through a forward fan, followed by an Omega detonation.
2. ATLAS CROWN — Six Plasma Cleavers erupt around the chassis in a 360-degree crown with a final radial hit.
3. WORLD BREAKER — One oversized forward cleave opens a walking chain of reactor detonations through the horde.

These are replacements for Plasma Cleaver's normal Tier III firing behavior after mutation. They are deliberately rule-changing rather than percentage upgrades.

## Extension points
- `MechaController.legendary_mutation` owns the selected mutation.
- `SpacehaulSpecialAbility.setup()` receives the mutation ID, so future chassis can branch without rewriting the acquisition system.
- `test_world.gd` owns one-core storage and the dedicated Legendary chooser.
- `enemy_manager.gd` owns core pacing/drop windows.
- `omega_core_pickup.gd` is fully procedural and does not require new sprite assets.

Prototype tuning lives in EnemyManager Inspector under **Omega Core** (`first_omega_core_time`, `omega_core_interval`).
