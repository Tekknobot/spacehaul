# Isometric Vector Aim Indicator Patch

## Purpose
Replaces the previous flat rotated aim arrow with a procedural vector indicator that changes geometry with aim direction.

## Implementation
- Uses the project existing `SpacehaulIsoVfx` 2:1 ground projection (`64x32` deck perspective).
- The indicator node itself does not rotate.
- Forward, perpendicular, arrowhead, shaft, and depth points are regenerated every physics frame from the exact attack aim vector.
- `Line2D` renders a crisp vector outline, center spine, and lower depth edge.
- `Polygon2D` supplies restrained translucent top and lower faces so the direction reads as an isometric object rather than HUD art.
- North/south aim is foreshortened by the deck projection; east/west aim stretches across the floor plane; diagonals shear naturally between those extremes.
- The lower face changes depth and lateral offset as the aim sweeps toward/away/across the camera, preventing a flat rotating-sprite appearance.

## Controls
No control mappings changed in this patch. Controller START deployment and the prior unified deferred spawn path remain intact.
