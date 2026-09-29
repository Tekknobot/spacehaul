# Game Over / Main Menu Flow Patch

- Player death now opens the existing run-summary panel instead of jumping directly to chassis selection.
- The run freezes while the summary is displayed.
- Summary shows time survived, kills, level, deck, chassis, and best time.
- Added a focused `MAIN MENU` button using the existing Mago UI fonts and dark cyan styling.
- `MAIN MENU` returns to the mecha-selection/title screen; a new run starts only after choosing a chassis.
- Extraction completion uses the same deliberate summary -> menu flow.
