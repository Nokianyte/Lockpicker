## Why

Lockpicker is a browser arcade game about aligning a sharp, rotating center piece with gaps in shrinking polygon walls.

## What Changes

- Display a pointed polygon at the center of nested walls with visible gaps.
- Scroll to turn the center piece one side per notch, and hold the wheel to accelerate the inner layer.
- Break the inner layer when its gap reaches the tip. End the run on solid contact.
- Provide endless play, layers-cleared scoring, gradual increases in shrink speed, and quick restart.
- Use simple geometric visuals inspired by the supplied sketch, with brief breaking feedback.
- Build the game in Godot, publish source to GitHub, and deliver a playable browser build through GitHub Pages.

## Capabilities

### New Capabilities
- `arcade-gameplay`: Center polygon rotation, shrinking walls, hold to accelerate, contact outcomes, scoring, and restart.
- `browser-delivery`: Browser input and presentation, reproducible Godot web export, GitHub source publication, and playable hosting.

### Modified Capabilities
None; this is a new project with no existing capability specs.

## Impact

Adds a Godot project, procedural 2D gameplay, a small HUD, web export configuration, publishing workflow, and setup/play documentation. Requires a pinned Godot version with matching web export templates and a GitHub repository with Pages configured. No backend, accounts, multiplayer, mobile controls, or online leaderboard are in scope. Repository owner/name and visibility will be resolved during implementation before creating a remote repository.
