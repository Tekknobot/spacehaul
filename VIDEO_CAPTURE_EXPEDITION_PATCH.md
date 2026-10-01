# Video Capture Expedition Patch

Video Capture mode is now Expedition-native.

## New Expedition capture controls on TestWorld

- `video_capture_expedition_deck` - selects Deck 1-5 directly. Expedition capture no longer guesses the deck from the old four-minute survival timer.
- `video_capture_expedition_phase` - `EXPLORE`, `OBJECTIVE`, `BOSS`, or `EXTRACTION`.
- `video_capture_expedition_completed_objectives` - for `OBJECTIVE`, stages 0-3 systems as already secured and places the mecha in the next system room.

`video_capture_start_minutes` is still used to simulate the strength of the build and enemy pressure. This keeps the useful late-run showcase build without pretending Expedition progress is time-gated.

## Phase behavior

- `EXPLORE`: fresh selected deck at its normal spawn.
- `OBJECTIVE`: completed objective state is restored, the corresponding rooms are revealed on the map, and the mecha is placed at the next unsecured objective so the real hold-to-secure / beam-up effect starts immediately.
- `BOSS`: all four systems are staged as secured and the mecha starts in the Hive; the normal Expedition logic spawns the deck's Broodmother variant on the first live frame.
- `EXTRACTION`: all systems and the boss are staged complete and the mecha starts in the evac room; the normal deck-transfer flow fires on the first live frame.

## Consistency fixes

- OMEGA state is capped to Expedition progression: one possible Core per Deck 1-3, with the current deck's Core only counted when at least one objective is already secured. A staged current-deck Core is also marked consumed so the director cannot spawn a duplicate carrier immediately.
- Capture setup banners are cleared after staging so recording opens on a clean gameplay frame.
- Enemy population is reset before the staged location goes live, so fresh pressure is generated around the actual capture room.
- The showroom status line now identifies the selected capture deck and phase.

Legacy non-Expedition video capture retains its original time-based deck behavior.
