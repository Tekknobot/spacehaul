SPACEHAUL MECHA PROTOTYPE

Godot 4.6.2

This build integrates all ten mecha sprite sets in Sprites Mechas.

M1
M2
M3
R1
R2
R3
R4
S1
S2
S3

Each mecha uses the same reusable controller. The controller automatically loads its idle move or walk and attack frames even when the frame counts differ between sprite sets.

At game start one mecha is chosen randomly for player control. All other mechas use a small local patrol AI around their current position. When a controlled mecha is released it remembers that location as its new AI home position.

TAB switches control to the next closest mecha that has not been visited in the current switch chain. After every mecha has been visited the chain resets. This prevents TAB from bouncing between the same two nearby mechas.

CONTROLS

WASD or left stick moves
SHIFT or left shoulder runs
LEFT MOUSE or right trigger attacks
TAB or Y switches mecha
G or right shoulder generates a new deck
U toggles the UI

The attack animation fires the existing generated projectile around the middle frame of the attack sequence. This is intentionally generic so unique mecha abilities can replace it later.
