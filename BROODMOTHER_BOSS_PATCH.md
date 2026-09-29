# Broodmother Boss Integration

- First boss encounter begins at 08:10, just after the 08:00 deck transfer.
- Uses the authored 64x64 Broodmother idle, walk and attack sheets (8 frames each).
- Uses the authored 32x32 egg sheet (16 frames).
- Eggs visibly wobble in place, can be targeted by all normal enemy-damage systems, and hatch into existing organic enemies.
- Natural hatching and egg destruction deliberately use the same authored hatch/break animation.
- The Broodmother has three health phases. Lower health increases egg pressure, hatch speed, movement and projectile volleys.
- Normal procedural spawning pauses while the boss is alive; the remaining escort is trimmed to 10 and new adds come from eggs.
- The boss encounter delays a later deck transfer if somehow still active, preventing procedural regeneration from skipping the fight.
- Boss death destroys remaining eggs, grants a large salvage pickup, plays a dissolve/death sequence, and resumes the normal director after a short grace period.
- For quick testing, enable Video Capture Mode and set its start time to 8.0 minutes; the boss arrives about 10 seconds later.
