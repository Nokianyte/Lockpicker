## 1. Project and export foundation

- [x] 1.1 Select and document a stable Godot 4 version with matching web templates; verify Compatibility rendering and single-threaded web export locally.
- [x] 1.2 Create the Godot 2D project, main scene, shared tuning configuration, and Git ignore rules for caches and generated builds.

## 2. Arena and controls

- [x] 2.1 Generate nested hexagonal walls with explicit gaps and shared drawing/collision geometry; validate gap width and wall spacing.
- [x] 2.2 Add the dot, visible upward launch guide, and wheel rotation of only the nearest wall while ready.
- [x] 2.3 Implement continuous wall shrinking and the ready/launching/bouncing/game-over state transitions with one action per middle-button press.

## 3. Escape and survival

- [x] 3.1 Implement swept dot movement against moving wall segments and gap endpoints; distinguish full successful crossings from solid impacts.
- [x] 3.2 Implement bounce return with shrinking pressure retained, no score change, and crushing checks during recovery.
- [x] 3.3 Remove a crossed wall from collision, award exactly one point, and play a brief break/disappear effect independently of simulation.
- [x] 3.4 Add safe landing after each crossing, smooth camera following, and selection of the next rotation target.
- [x] 3.5 Replenish outer walls for endless play with seeded generation, bounded shrink-speed progression, and validated landing clearance.

## 4. Player presentation and browser behavior

- [x] 4.1 Add control instructions, layers-cleared HUD, final score, and middle-button start/restart that resets the entire run without also launching.
- [x] 4.2 Add responsive presentation and focus-loss pause with explicit middle-button resume and stale-input clearing.
- [x] 4.3 Configure the web shell to suppress page scrolling and middle-button autoscroll over the game canvas.

## 5. Verification and tuning

- [x] 5.1 Add meaningful deterministic checks for clear versus edge collision, bounce versus crush, one-score-per-wall, repeated press handling, and restart reset.
- [x] 5.2 Check collision behavior at varied frame rates and late launches; run extended seeded progression checks for nesting, traversable gaps, and safe landing spacing.
- [ ] 5.3 Playtest a served web export in Chrome, Edge, and Firefox, covering physical wheel controls, resizing, focus pause, contact, breaking, game over, and restart. Record results.
- [x] 5.4 Tune wheel sensitivity, shrink progression, bounce duration, and camera framing for readable, responsive play.

## 6. GitHub publication

- [x] 6.1 Inspect remote/account context and resolve repository owner, name, and visibility with the user if not already established; verify Pages availability.
- [x] 6.2 Add a reproducible GitHub Actions export-and-Pages deployment workflow using the pinned engine and matching templates.
- [x] 6.3 Document local run/export steps, controls, tested browser and engine versions, and deployment setup; publish source to the selected GitHub repository.
- [x] 6.4 Deploy to Pages, verify assets load under the final repository URL, complete a hosted play-and-restart smoke test, and record the playable link in the README.

## 7. Playtest refinements

- [x] 7.1 Animate whole-side turns with consistent collision geometry and preserve rapid wheel inputs.
- [x] 7.2 Smoothly recenter the dot on screen after dashes and bounces without teleporting its gameplay position.
- [x] 7.3 Verify turning, buffered launch, and screen centering; publish the updated browser build.

## 8. Center polygon refinement

- [x] 8.1 Replace the moving dot with a fixed center polygon that turns smoothly in whole-side steps.
- [x] 8.2 Resolve gap or solid contact at the tip and accelerate only the innermost layer while the wheel is held.
- [x] 8.3 Verify the new controls and contact behavior in the browser and publish the update.
