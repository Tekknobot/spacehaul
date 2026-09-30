# SpaceMECHA Chassis Showroom Patch

## Start selector redesign
- Replaced the 10-button chassis grid with a full-screen single-chassis carousel.
- Center stage uses the real animated MechaController sprite and authored idle/attack frames.
- Left/right arrows and keyboard/gamepad movement cycle the roster with wrapping.
- Neighboring chassis names are shown faintly beside the carousel arrows.
- ENTER / gamepad A / DEPLOY button starts the selected chassis.
- Selected chassis displays its base LMB and RMB names beneath the live preview.

## Live Tier-0 combat demonstration
- The showroom automatically loops: idle -> base LMB -> idle -> base RMB -> idle.
- The preview reuses SpacehaulSpecialAbility itself at Tier 0, so the menu demonstrates the actual attack VFX instead of approximations.
- Added preview_mode to special_ability_effect.gd so menu demonstrations:
  - continue while gameplay is paused,
  - never query/damage gameplay enemies,
  - never attach targeting to leftover enemies,
  - suppress repeated explosion audio,
  - render into an isolated SubViewport.

## Visual presentation
- Dark full-screen showroom presentation using the existing Mago fonts.
- Minimal isometric hangar/grid backdrop behind the centered mecha.
- Current demonstration label identifies LMB/RMB during the cycle.
- Large mouse-friendly carousel arrows and one centered deploy action.
