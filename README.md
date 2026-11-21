# Lockpicker rhythm prototype

Scroll one notch to turn the innermost ring 60°. Line up its circle with the fixed red circle, then tap Z or X when both hexagons overlap on the beat.

- **Z** and **X** are interchangeable. Either key starts the two-beat count-in, judges a tap during play, and resumes or replays from the corresponding screen. Each tap needs a fresh press.
- **Perfect** (within 45 ms) earns 100 points. **Good** (within 100 ms) earns 50 points. Both require alignment.
- A missed ring or an off-beat tap breaks the combo. The rest of the chart continues on schedule.
- The prototype uses an eight-bar chart and an audible 100 BPM metronome. Watch the opening marker pulse as its ring reaches the tip.
- Turn spike rings away from the red circle. A spike touching the circle ends the run. Safely passing a spike preserves your combo.
- Losing window focus pauses the chart.

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

The deterministic suite covers rhythm tap windows, alignment, misses, pause, replay, and a full combo on the prototype chart. It also exercises the original arcade model.

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

- `scripts/rhythm_run.gd`: chart, ring motion, and tap judgment.
- `scripts/rhythm.gd`: rhythm scene, input, rendering, and metronome.
- `scripts/run_model.gd`: original arcade simulation.
- `scripts/wall_geometry.gd`: polygon outline and swept collision.
- `scripts/main.gd`: original arcade scene controller.
- `scripts/tuning.gd`: gameplay constants.
- `openspec/`: requirements, design decisions, and implementation checklist.
