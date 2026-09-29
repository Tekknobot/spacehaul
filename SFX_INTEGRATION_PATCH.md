# SpaceMECHA SFX integration patch

- Added `Audio/SFX/explosion_8bit.wav` to the shared SFX registry as `explosion`.
- Every `SpacehaulSpecialExplosion` now triggers the explosion sound automatically.
- Explosion playback uses one shared voice with a 95 ms coalescing window. Multiple simultaneous explosion VFX do not stack multiple copies of the WAV and therefore do not increase the sample volume.
- Explosion pitch varies subtly by visual blast radius without changing gain.
- Primary and secondary weapon SFX now trigger on the actual attack fire frame, synchronized with ability creation.
- Spider burst follow-up projectiles now trigger `enemy_shot.wav`.
- Shock pulses now trigger a lower-pitched `enemy_shot.wav` discharge.
- Lethal enemy hits now play `enemy_die.wav` instead of layering `enemy_hit.wav` and `enemy_die.wav` on the same frame.
- Existing boost, player hurt, salvage, level/secondary-online, low-hull warning, normal enemy shot, enemy hit, and enemy death triggers remain connected.
