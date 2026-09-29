# SPACEMECHA Gameplay Feel Pass

Implemented from the September 29 gameplay review:

- Player retains 78% movement speed while firing instead of being rooted.
- Space / Gamepad A BOOST: 0.20s burst, 1.35s cooldown, brief damage immunity.
- Boost uses cyan sprite shader energy, pixel afterimages and restrained camera kick.
- Player hit response now includes a sprite hit shader, short camera shake and full-screen edge-damage shader.
- Compact HULL / level / salvage / timer / deck / hostile HUD is always visible.
- Secondary comes online at 60 seconds.
- Opening enemy target ramp is now 5 / 8 / 12 / 16 / 21 / 27 through the first four minutes.
- Damaged normal enemies briefly show health bars; elites keep a larger health bar visible.
- Ranged enemies now telegraph shots; shock enemies show an expanding warning ring before discharge; charger telegraph remains intact.
- Added compact synthesized-style WAV SFX for primary, secondary, boost, hurt, enemy hit/death/shot, salvage, level-up and low-hull warning.
- Electrical deck hazards now damage enemies as well as the player.
- Game-over / extraction summary now shows survival time, kills, level, deck, chassis and persistent personal-best survival time.

Primary tuning points are exposed in `Scripts/mecha_controller.gd`:
`attack_move_multiplier`, `boost_speed`, `boost_duration`, and `boost_cooldown`.
