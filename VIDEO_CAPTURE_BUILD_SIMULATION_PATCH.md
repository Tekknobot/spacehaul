# Video Capture Build Simulation Patch

Video capture mode now reconstructs a plausible build for the requested start time instead of perfectly alternating LMB/RMB upgrades and then applying the same generic stat order to every chassis.

## Ability progression

The capture state spends its simulated salvage level-up budget on chassis ability tiers first. The default progression intentionally lets LMB lead RMB because primary is available from the opening seconds while secondary does not unlock until 01:00.

- Primary Tier I: 01:00+
- Primary Tier II: 02:00+
- Secondary Tier I: 03:00+
- Primary Tier III: 04:00+
- Secondary Tier II: 05:00+
- Secondary Tier III: 07:00+

By 07:00 or later, both normal ability trees are guaranteed Tier III before any generic stat choices consume the remaining simulated upgrade budget.

## Remaining upgrades

Every remaining historical level-up choice is still spent. Each chassis now has a deterministic but different generic upgrade plan using the real existing upgrades: primary/secondary cooling, impact radius, hull, servo speed and salvage magnet. This keeps captures repeatable while avoiding ten identical showcase builds.

## Omega showcase

Late-run capture mode can optionally include a Legendary Omega mutation. Inspector settings on TestWorld:

- `video_capture_include_omega` (default true)
- `video_capture_omega_choice` (0, 1 or 2)
- `video_capture_omega_minute` (default 8.0)

Disable `video_capture_include_omega` when you specifically want footage of the normal Tier III signature ability.
