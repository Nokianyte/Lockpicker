## Why

Lockpicker turns a simple mouse-wheel interaction into a tense browser arcade game: align a gap and escape before shrinking polygon walls crush the dot. This change establishes the first playable Godot version and a shareable GitHub-hosted browser build.

## What Changes

- Display a dot inside multiple nested polygon walls, each with a gap.
- Scroll to rotate the innermost remaining polygon; press the scroll wheel to launch the dot outward.
- Break and remove a wall after a successful crossing. Bounce back after striking solid wall, losing time while the layers continue shrinking.
- End the run when a shrinking wall crushes the dot.
- Provide endless play, layers-cleared scoring, gradual increases in shrink speed, and quick restart.
- Use simple geometric visuals inspired by the supplied sketch, with brief breaking feedback.
- Build the game in Godot, publish source to GitHub, and deliver a playable browser build through GitHub Pages.

## Capabilities

### New Capabilities
- `arcade-gameplay`: Wheel controls, shrinking polygon walls, dot movement, crossing, bounce, crushing, scoring, and restart.
- `browser-delivery`: Browser input and presentation, reproducible Godot web export, GitHub source publication, and playable hosting.

### Modified Capabilities
None; this is a new project with no existing capability specs.

## Impact

Adds a Godot project, procedural 2D gameplay, a small HUD, web export configuration, publishing workflow, and setup/play documentation. Requires a pinned Godot version with matching web export templates and a GitHub repository with Pages configured. No backend, accounts, multiplayer, mobile controls, or online leaderboard are in scope. Repository owner/name and visibility will be resolved during implementation before creating a remote repository.
