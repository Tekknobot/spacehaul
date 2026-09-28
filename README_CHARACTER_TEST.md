SPACEHAUL ISOMETRIC CHARACTER TEST

Godot 4.6.2

The procedural test level now renders as an isometric station landscape with raised isometric wall blocks. Wall collision follows diamond footprints and wall draw order changes with player depth so the character can pass visually in front of and behind walls.

CONTROLS

WASD or left stick move
Shift or LB run
Space or A dash
Right mouse or LT aim
Left mouse or RT shoot
E or X interact
F or Y tool
Q or B pickup
H or R3 hurt test
K or Start death test
R or Back respawn
G or RB generate a new procedural deck

AIM AND SHOOT

Aim plays through its eight frames once and freezes on frame eight while aim remains held. Firing plays the shoot animation and produces a crisp non antialiased pixel beam from the center of the character toward the mouse target. With a gamepad the right stick sets the beam direction. The beam stops at wall collision.

ART NOTE

The supplied character art can remain in place for testing. When new isometric or top down character animations are ready they can replace the existing sprite sheets without changing the controller as long as each sheet remains eight frames at 32 by 32 pixels per frame.


DECK UPDATE

U toggles the full UI on and off.
Procedural rooms are at least 4 by 4 cells and connecting halls are at least 4 cells wide.
The generator now builds mixed room sizes broad lanes extra connections and service bays.
Walls use a cool teal slate tint to contrast with the orange and white player sprite.

PATCH NOTES

Wall overlap now sorts isometric walls from their floor cell depth and the player from the bottom of the collision footprint. This removes the coarse depth tie that could place a wall over the player when the player is clearly standing in front.

Shooting no longer uses a laser line. Each LEFT MOUSE click or gamepad shoot press creates one generated pixel projectile aimed toward the mouse cursor or right stick direction. Projectiles travel through the world and stop on wall collision.

Aim still plays once and holds on its final eighth frame while aim remains pressed.
