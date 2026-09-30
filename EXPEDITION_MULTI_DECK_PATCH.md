# SpaceMECHA Expedition Multi-Deck Pass

## What changed

- Expedition Mode now spans all five authored deck palettes instead of ending after one extraction.
- Extraction on Decks 1-4 transfers the current chassis/build to the next generated deck.
- Extraction on Deck 5 completes the expedition.
- The minimap is hidden by default and toggled with **TAB**. The persistent top HUD remains visible.
- The minimap already auto-fits its drawing to the generated grid dimensions, so the larger decks shrink to fit the same map canvas rather than clipping.

## Expedition deck growth

| Deck | Palette | Grid | Target rooms | Extra links | Hazards |
| --- | --- | --- | --- | --- | --- |
| 1 | STEEL | 45x33 | 13 | 5 | 10 |
| 2 | MOTOR | 51x37 | 15 | 6 | 13 |
| 3 | CRYO | 57x41 | 17 | 7 | 16 |
| 4 | VOID | 63x45 | 19 | 8 | 19 |
| 5 | MONO | 69x49 | 21 | 9 | 22 |

Every deck still contains ARMORY, REPAIR BAY, DATA CACHE, REACTOR, HIVE and EXTRACTION rooms, but their procedural placement is rebuilt on each floor.

## Difficulty

Difficulty now uses both elapsed run time and expedition depth.

- Later decks maintain larger ambient enemy populations even if the player reaches them quickly.
- Swarm event budgets increase by deck depth.
- Standard enemies gain additional health, movement pressure and faster attacks on deeper decks.
- Objective hold time increases slightly each deck.
- Between-deck transfer gives only a modest service repair; the build itself carries forward.

## Temporary boss variants

Until unique bosses are authored, every deck can use the Broodmother as a structural test boss.

- Deck 1: original STEEL Broodmother.
- Deck 2: MOTOR amber/gold shader variant.
- Deck 3: CRYO cyan shader variant.
- Deck 4: VOID violet shader variant.
- Deck 5: MONO pale/red shader variant.

The variants also gain health, movement speed and attack tempo by deck depth. Their health bars match the variant color so the encounter reads differently even before replacement boss art exists.

## Design intent

This pass is meant to answer a structural question, not finish content: does SpaceMECHA become more compelling when one run is a chain of increasingly large procedural expeditions rather than a fixed survival timer? If this five-deck loop plays well, the next useful work is objective variety, room-specific encounters and unique bosses—not an overworld yet.
