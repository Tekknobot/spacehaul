# Video Capture / Showroom Compatibility Patch

The developer video-capture shortcut now works through the current SPACEMECHA chassis showroom instead of bypassing it.

- Enable `video_capture_mode` on the TestWorld root as before.
- The title/showroom still appears, with the configured capture timestamp shown in the status line.
- Cycle to any chassis and deploy it normally.
- Immediately after that selected chassis is spawned, the configured late-run capture state is applied: run clock, deck, simulated upgrades, RMB unlock/tier, optional Omega mutation, hull, and enemy pressure.
- Returning to the main menu and choosing another chassis repeats the same capture staging for that new selection.
- `fixed_starting_mecha` now only decides which chassis is initially highlighted when capture mode is enabled; it no longer prevents selecting another chassis.

Public builds are unchanged when `video_capture_mode` is disabled.
