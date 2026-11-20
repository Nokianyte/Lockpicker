## Context

Lockpicker uses a Godot 2D game and a single-threaded Compatibility web export. The current design follows the updated reference with a pointed polygon fixed at screen center, surrounded by shrinking hexagonal layers.

## Decisions

### Center piece and contact
Each wheel notch changes the center piece's target heading by 60 degrees. A 160 ms smoothstep animation uses the current heading as its starting point, so rapid scroll events accumulate and direction reversals remain continuous. The visible tip and gameplay share the same heading.

Ring and gap angles are fixed in world space. For the innermost ring, calculate where its outline intersects the ray toward the tip and include the wall stroke. Sweep the shrinking radius and animated tip through each physics tick to find first contact. Classify the gap at that time, reserving a small margin for the endpoints. A clear emits fragments and removes the ring immediately. A miss freezes the run.

### Inward movement and replenishment
All layers shrink at a score-dependent rate. One wheel click multiplies the rate for the current inner layer until contact. The boost ends when that layer reaches the tip or when play pauses. A bounded spawn radius and minimum spacing keep the outer layers separated at both normal and boosted rates. The active layer can clear before an outer slot is ready to refill.

### Browser controls and presentation
Use the existing browser shell to suppress page scrolling and autoscroll. A middle-button press starts, restarts, or resumes from the respective screen. A fresh press during play enables the boost. Use a highlight on the aligned tip and an accent on the active layer while boosted. A constant view scale keeps the center polygon the same size during each run.

### GitHub delivery
Keep the pinned engine, matching export templates, and Pages workflow. Verify the changed controls with the deterministic suite and a served browser build before checking the published game.
