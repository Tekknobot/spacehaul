# Controller / Keyboard Input Patch

Target: Godot 4.6.2

## Fixed

- Fixed controller deployment carrying the same A press into gameplay as BOOST.
- Fresh deploys and paused UI confirmations now wait for held movement / combat inputs to return to neutral before player control resumes.
- Mecha deployment is applied in world space after parenting, making spawn placement robust against manager transforms.
- Controller attacks no longer fall back to a stale mouse position when the right stick is centered; the last valid right-stick aim is retained for controller-triggered combat.
- Released stale GUI focus when returning to the chassis showroom so gamepad A consistently reaches DEPLOY.

## Input parity

- Keyboard/mouse and gamepad can be swapped at runtime.
- UI prompts update from the device that was actually used most recently.
- Upgrade and Omega menus support controller focus navigation and A confirmation.
- Expedition map: TAB on keyboard, Back/View on gamepad.
- Omega primary cycling: mouse wheel on keyboard/mouse, X/Y on gamepad.

## Current core gamepad layout

- Left Stick / D-pad: move / menu selection
- Right Stick: aim
- RT: primary
- LT: secondary
- A: boost / menu confirm / deploy
- LB: run
- X / Y: previous / next Omega primary mode
- Back/View: expedition map
