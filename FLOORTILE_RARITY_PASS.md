# FloorTile rarity pass

The 16 files in `Sprites/Tiles/FloorTiles` are now treated as an authored rarity sequence rather than an evenly randomized set.

Approximate selection weights:

- floor_base_01: 32%
- floor_base_02: 19%
- floor_base_03: 12%
- floor_base_04: 9%
- floor_base_05: 7%
- floor_base_06: 5%
- floor_base_07: 4%
- floor_base_08: 3%
- floor_base_09: 2.5%
- floor_base_10: 2%
- floor_base_11: 1.5%
- floor_base_12: 1%
- floor_base_13: 0.75%
- floor_base_14: 0.5%
- floor_base_15: 0.4%
- floor_base_16: 0.35%

Tiles 09 through 16 are treated as feature panels. If one would normally spawn directly beside another feature panel, the generator has an 88% chance to reroll from the first eight structural tiles. This keeps special machinery, hatches and grilles visually separated and makes the deck read as constructed rather than random tile confetti.

The spawn tile always uses floor_base_01.
