# Enemy Spawn Director Pass

The previous enemy manager increased active-enemy count over time, but each refill chose enemy types independently and spawned them as effectively random individuals. Batch size rose from 1 to 4, but there were no persistent packs, same-species clusters, approach sectors, or authored swarm events.

This pass changes the 20-minute run into a survivor-style encounter director:

- **Ambient refill now uses same-species packs.** Enemies enter in recognizable groups around one nearby spawn anchor instead of appearing as unrelated random singles.
- **Enemy roles affect pack size.** Fast melee organisms can form larger packs; ranged, shock, charger, and heavy enemies are deliberately kept in smaller squads so their attack telegraphs remain readable.
- **Timed swarm events now run through the whole 20 minutes.** Early swarms come from one approach, mid-run events can pincer from two sectors, and later events can surround from three separated sectors.
- **Swarms are burst-spawned over several beats** instead of appearing all at once. This creates a visible incoming wave while keeping pathfinding and collision load sane.
- **Swarm pressure can temporarily exceed the normal population target** with a controlled headroom cap. When the event finishes, the run naturally falls back to the lower ambient target, creating pressure/cleanup/recovery rhythm.
- **Swarm species are selected from mobile organisms.** Specialist/ranged/heavy enemies continue to enter through normal squads rather than producing unreadable projectile walls.
- **Deck changes cancel an in-progress swarm and create a short reset window.** The next event cannot immediately fire after procedural regeneration.
- **The Broodmother still owns the arena during its encounter.** Global pack/swarm spawning pauses and eggs remain the source of boss adds.
- **Elite timing is preserved**, but elites can now appear as the lead creature in a pack.
- **Inspector tuning controls** were added to `EnemyManager`: `swarm_events_enabled`, `announce_major_swarms`, and `hard_active_enemy_cap`.

## Intended 20-minute pacing

- **0–2 min:** small 2–3 creature packs; first single-front organism swarm.
- **2–4 min:** more frequent packs; first multi-contact pressure begins.
- **4–8 min:** 3–4 creature packs, specialist squads, front/pincer swarms.
- **8–12 min:** Broodmother encounter interrupts the director; after the boss, denser swarm pressure resumes.
- **12–16 min:** larger pincer/surround events and faster recovery of ambient population.
- **16–20 min:** 5–6 creature common packs, 20+ organism swarm budgets, frequent two/three-sector attacks, while still respecting the hard active-enemy cap.

The system is intentionally adaptive rather than a rigid wave table: the target count, current living population, deck transitions, boss state, and event headroom all affect what can actually spawn. This should make each procedural deck feel different without losing the recognizable survivor-game pacing.
