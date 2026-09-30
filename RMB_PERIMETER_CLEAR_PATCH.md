# RMB Perimeter Clear Patch

All RMB / secondary abilities now keep their existing damage, VFX, pull, bombardment, web, EMP, or explosion behavior and finish with a universal crowd-control clear.

- Surviving mobile enemies inside the RMB's authored outer radius are pushed toward that radius' perimeter.
- The push is collision-aware because normal enemies and the Broodmother move through their CharacterBody2D movement path rather than being teleported.
- Enemies close to the player travel farther; enemies already near the perimeter move only a small amount.
- Normal enemies receive a brief recovery window after the displacement so they cannot instantly erase the breathing room.
- The Broodmother can also be displaced to the perimeter, at a slightly slower motion rate.
- Broodmother eggs remain stationary and are not moved by the perimeter clear.
- The perimeter clear adds no extra hidden damage; existing RMB damage logic is preserved.
- The outer clear radius scales with each mecha's existing secondary upgrade tier and largest finishing wave.
