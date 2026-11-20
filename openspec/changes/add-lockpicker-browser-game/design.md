## Context

The workspace contains OpenSpec scaffolding but no game implementation. See proposal.md for motivation and the two capability specs for behavior. The user chose Godot, browser delivery, mouse-wheel rotation, middle-button launch, and a time-costing bounce. The reference sketch establishes nested broken polygon outlines and a small central dot.

## Goals / Non-Goals

**Goals:** Keep the collision model consistent with the visible gaps; separate gameplay timing from decorative animation; make a small reproducible web build; keep tuning values easy to change.

**Non-Goals:** General-purpose rigid-body simulation, authored level tooling, backend services, and a touch-control scheme.

## Decisions

### Godot 2D with procedural geometry
Use GDScript, a 2D scene, and procedurally generated polygon segments with explicit gap endpoints. Start with hexagons matching the sketch. Select and pin a suitable stable Godot 4 release and matching export templates during implementation, then verify its actual web export behavior. Target the Compatibility renderer and a single-threaded web export to keep static hosting simple; confirm support before pinning. Prefer generated lines and particles over imported art so rendering and collision share geometry.

### Explicit gameplay state and swept collision
Use ready, launching, bouncing, and game-over states with a separate paused state. Separate the run controller, wall generation/geometry, dot motion, visual effects, and HUD. Use fixed-step simulation and swept circle-versus-segment checks, accounting for wall motion, rather than endpoint-only checks that can miss collisions at high speed. A full dot crossing the gap clears one wall. An outbound solid impact enters bounce; subsequent wall encroachment can crush the dot. The first collision event in a step determines the outcome, with solid contact taking precedence over a coincident clear.

Disable aiming changes during an unresolved attempt for predictable geometry. Ignore launch presses until ready. Continue shrink simulation during all active attempt and breaking states. Breaking walls immediately leave the collision set and award score once; their visual fragments expire independently.

### Stable outward path and camera
Working presentation assumption: the dot launches upward along a short visible guide, remains at its successful crossing position, and the camera smoothly follows it. Remaining walls keep their shared world center; camera movement never changes collision coordinates. For each attempt, compute the next wall intersection along the upward ray. Stop a successful launch just outside the cleared wall and inside the next. Maintain sufficient wall spacing for this landing and a subsequent attempt. Prefer this over teleporting the dot back to the arena center, which would obscure the physical crossing described by the user.

The camera applies the full dot-position offset around the exact viewport midpoint, with exponential follow and a small settling threshold. This returns the dot to screen center after both dash and bounce; there is no persistent vertical framing offset.

### Endless wall generation and bounded difficulty
Maintain a small queue of nested walls, adding a new outer wall after each clear. Randomize gap orientation, retain gaps wider than the dot, and validate nesting and landing clearance. Increase shrink speed with score up to a tuned maximum. Keep initial radii, spacing, wall width, gap size, wheel sensitivity, launch speed, bounce duration, and difficulty curve as named tuning values. Use seeded generation in checks to reproduce failures. Tune exact values through browser playtesting rather than treating guessed numbers as requirements.

Implementation refinement from the long-run check: uniformly rescale the remaining radii and dot coordinates after each clear so the next wall returns to the initial radius. Preserve the shared center and relative placement, and compensate with a brief visual zoom. This prevents unbounded travel distances and floating-point drift while maintaining a fixed readable dot size and enough clearance for another attempt.

### Input and browser integration
Map each wheel up/down notch to one full polygon side (60 degrees for the hexagons), and middle-button press to state-dependent start, launch, resume, or restart. Generate gaps on the same six-position angular grid relative to the upward launch path so all layers remain solvable. The first wall begins one notch away from alignment. Consume each press once. Use a minimal web shell to suppress default wheel scrolling and middle-button autoscroll over the canvas. Explicitly pause on focus loss, discard stale input, and require middle-button resume. Keep the canvas responsive without changing world-space collision measurements.

### GitHub delivery
Keep source, export preset, and build instructions in Git; exclude editor caches and generated exports. Add a GitHub Actions workflow that uses the pinned engine/templates, exports the web game, and deploys the artifact to Pages. Use relative asset paths and verify the actual repository subpath URL. Repository destination and visibility are deployment inputs to resolve from existing remote/account context or with the user before remote creation. GitHub account authorization and Pages availability must be verified during implementation.

### Smooth turns
Animate each 60-degree input with a 160 ms smoothstep interpolation in the simulation. Rapid wheel events accumulate the requested angle without losing steps; reversals retarget from the current angle. Swept collision includes angular wall motion as well as shrinking and dot movement. A middle-button press during turning buffers a single launch until the rotation finishes; pause clears that buffered launch. Shrinking continues throughout the turn.

## Risks / Trade-offs

- Moving polygon corners and gap edges can produce unfair collisions → share render/collision geometry and check swept edge cases, including rotation and frame-rate variation.
- Rising difficulty can remove any safe landing zone → enforce minimum spacing and gap clearance, cap shrink speed, and test long seeded runs.
- Camera following can hide outer layers → frame the next target with sufficient margin and tune movement through playtesting.
- Wheel sensitivity and middle-button defaults vary across browsers → normalize wheel input and test a physical wheel in all three target browsers.
- Browser export or Pages configuration can fail independently of editor play → test a local served export and the final hosted build.

## Migration Plan

This is a new project; no data migration is needed. Build and verify locally, publish to the selected repository, configure Pages deployment, and smoke-test the hosted URL. If a deployment fails, retain or redeploy the last working artifact and fix the workflow before declaring delivery complete.

## Open Questions

- Which GitHub owner/repository and visibility should be used if no existing remote identifies the destination?
- Exact visual palette, sound polish, and tuning values can be selected during implementation without changing the gameplay contract.
