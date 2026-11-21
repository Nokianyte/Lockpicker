# Lockpicker

The rhythm prototype opens by default. Choose **Charts** to make or play a song chart, or **Arcade** to switch to the endless mode.

Scroll one notch or press the Left or Right Arrow to turn the innermost ring 60°. Line up its circle with the fixed red circle, then tap Z or X when both hexagons overlap on the beat.

- **Z** and **X** are interchangeable. Either key starts the two-beat count-in, judges a tap during play, and resumes or replays from the corresponding screen. Each tap needs a fresh press.
- **Perfect** (within 45 ms) earns 100 points. **Good** (within 100 ms) earns 50 points. Both require alignment.
- A missed ring or an off-beat tap breaks the combo. The rest of the chart continues on schedule.
- The prototype uses an eight-bar chart and an audible 100 BPM metronome. Watch the opening marker pulse as its ring reaches the tip.
- Turn spike rings away from the red circle. A spike touching the circle ends the run. Safely passing a spike preserves your combo.
- Losing window focus pauses the chart.

## Make a song chart

Open **Charts → New chart** and import an MP3 or WAV file. Set the BPM and first-beat offset against the waveform, then choose a grid subdivision. Left-click a lane to place a note, Shift + left-click to place a spike, and right-click a marker to delete it. Drag a marker to move it. Use the wheel to scroll the timeline and Ctrl + wheel to zoom.

Choose **Left slider** or **Right slider** from the placement menu below the grid, then click a lane to place it. Each slider rotates the center and target 60° on its beat, even if you miss it. Aim at the red circle and press the matching arrow to score the hit. The wheel still turns the incoming ring, and the arrows also turn it outside slider hit windows. Preview and cursor playtests use the same scheduled turns.

In **Info / Settings**, set **Start offset** and **End offset** to skip seconds from either end of the song. The grid stays aligned to the original recording, with trimmed sections shaded on the timeline.

Use **+ Zone** to add a zone at the playhead. Click its diamond to open its settings or drag the diamond to move the start. Each zone applies through the next marker or the end of the chart. **Spawn distance** sets the starting radius, up to 3,000 units for entrances from offscreen. **Start speed** and **End speed** set each polygon’s approach speeds in units per second. The **Rotation offset** winds back to the charted direction with the same speed change. Polygons still arrive on beat.

**Center rotation speed** turns the center polygon, red target, and incoming polygons together in degrees per second. Positive values turn clockwise and negative values turn counterclockwise. The arena keeps its current angle when a zone changes the speed. Incoming polygons apply their own rotation offset on top.

Use **Playtest** for the full chart or **Playtest from cursor** to start near the playhead. Use the mouse wheel or Left / Right Arrow to turn the innermost ring toward the red circle, then tap **Z** or **X** on the beat. Spikes are spiky circles and cost the same energy as a missed note when their center is inside the red circle on their beat. Saved charts and their audio files stay in local game or browser storage.

## Run locally

Install the standard (GDScript) Godot **4.7.2** editor. Import `project.godot`, then press F5 to run the main scene. Or, with the executable on PATH:

```sh
godot --path .
```

## Checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_game.gd
godot --headless --path . --script tests/test_rhythm.gd
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
- `scripts/palette.gd`: shared colors for gameplay and the chart editor.
- `scripts/tuning.gd`: gameplay constants.
- `openspec/`: requirements, design decisions, and implementation checklist.
