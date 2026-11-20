# Lockpicker

A mouse-wheel arcade game built in **Godot 4.7.2**. Rotate the shrinking polygon, line up its opening, and launch the dot before the walls close in.

**[Play in your browser](https://nokianyte.github.io/Lockpicker/)** · [Source on GitHub](https://github.com/Nokianyte/Lockpicker)

## Controls

- **Scroll:** rotate the nearest polygon by one full side (60°) per notch.
- Turns animate smoothly; clicking during a turn launches as soon as it finishes. The dot smoothly returns to screen center after each dash or bounce.
- **Press the scroll wheel:** start, launch, resume, or restart.
- A missed launch bounces back and costs time. A successful escape breaks the wall and earns one point.
- The game pauses when focus is lost. Press the wheel to resume.

Endless layers become faster as the score increases. The best score lasts for the current session. Desktop mouse play is required; touch controls are not included.

## Run locally

Install the standard (GDScript) Godot **4.7.2** editor. Import `project.godot`, then press F5 to run the main scene. Or, with the executable on PATH:

```sh
godot --path .
```

## Checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_game.gd
```

The deterministic suite covers full and edge crossings, tunneling, bounce/crush behavior, input-state transitions, pause/restart, frame-rate variation, and 100 consecutive seeded escapes.

## Browser export

Install the matching **4.7.2** export templates through Godot's export-template manager. The `Web` preset uses Compatibility rendering and disables threads, so it can run on static hosting without cross-origin isolation headers.

Create `build/web` and an empty `build/.gdignore`, then run:

```sh
godot --headless --path . --export-release Web build/web/index.html
node tools/serve.mjs
```

Open `http://127.0.0.1:8060`. Serve the exported files over HTTP; do not open `index.html` directly from disk. Node.js is only needed for this optional local server, not to play the game.

## Publication

The GitHub Actions workflow tests, exports, and deploys pushes to `main`. Enable **Settings → Pages → Source → GitHub Actions** for the repository. It downloads the pinned engine and matching templates from the official release and verifies their published SHA-512 checksums. Generated builds and editor caches are excluded from Git.

See [verification notes](docs/verification.md) for the tested build and browser coverage.

## Project layout

- `scripts/run_model.gd`: gameplay state and simulation.
- `scripts/wall_geometry.gd`: polygon outline and swept collision.
- `scripts/main.gd`: rendering, HUD, input, and visual feedback.
- `scripts/tuning.gd`: gameplay constants.
- `openspec/`: requirements, design decisions, and implementation checklist.
