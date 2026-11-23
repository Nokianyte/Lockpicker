# Lockpicker

Lockpicker opens directly to **Charts**, where you can create, edit, or play a chart for your own music.

Open **Settings** to adjust the master volume. The setting is saved locally when you close the dialog.

## Make a song chart

Choose **New chart** and import an MP3 or WAV file. Set the BPM and first-beat offset against the waveform, then choose a grid subdivision. Left-click a lane to place a note, Shift + left-click to place a spike, and right-click a marker to delete it. Drag a marker to move it. Use the wheel to scroll the timeline and Ctrl + wheel to zoom.

To share a saved chart, choose **Export** in the Charts library. The `.lockchart` package includes the original audio. Choose **Import chart** on the same screen to add the package as a separate chart.

Choose **Left slider** (red) or **Right slider** (blue) from the placement menu below the grid, then click a lane to place it. Each slider rotates the center and target 60° on its beat, even if you miss it. Aim at the target circle and press the matching arrow to score the hit. The wheel still turns the incoming ring, and the arrows also turn it outside slider hit windows. The timeline’s **Target** row shows which way the center faces relative to the six chart lanes. Click the row to seek and see the exact direction at the playhead.

In **Info / Settings**, set **Start offset** and **End offset** to skip seconds from either end of the song. The grid stays aligned to the original recording, with trimmed sections shaded on the timeline.

Use **+ Zone** to add a zone at the playhead. New zones copy the settings from the closest earlier zone. Click a zone’s diamond to open its settings or drag the diamond to move the start. Each zone applies through the next marker or the end of the chart. **Spawn distance** sets the starting radius, up to 3,000 units for entrances from offscreen. **Start speed** and **End speed** set each polygon’s approach speeds in units per second. The **Rotation offset** winds back to the charted direction with the same speed change. Polygons still arrive on beat.

**Center rotation speed** turns the center polygon, target circle, and incoming polygons together in degrees per second. Positive values turn clockwise and negative values turn counterclockwise. The arena keeps its current angle when a zone changes the speed. Incoming polygons apply their own rotation offset on top.

**Polygon start color** and **Polygon end color** tint incoming polygons as they travel. The color follows distance traveled, so it changes faster as the polygon speeds up. **Background color** changes the arena at the zone marker. Right-click any color swatch to restore its default.

Use **Playtest** for the full chart or **Playtest from cursor** to start near the playhead. Use the mouse wheel or Left / Right Arrow to turn the innermost ring toward the target circle, then tap **Z** or **X** on the beat. Spikes are spiky circles and cost the same energy as a missed note if they line up with the target on their beat. Saved charts and their audio files stay in local game or browser storage.

The center polygon and target circle have black outlines at rest on light backgrounds and light outlines on dark backgrounds. Both tint yellow for **Perfect** (within 35 ms), green for **Good** (within 70 ms), and red for a miss or spike hit. A miss or spike hit also flashes the screen edges red. **OK** hits within the 100 ms window count without a color flash.

Losing window focus pauses playback. Press **Z** or **X** to resume a paused run.

## Run locally

Install the standard (GDScript) Godot **4.7.2** editor. Import `project.godot`, then press F5 to run the main scene. Or, with the executable on PATH:

```sh
godot --path .
```

## Checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_rhythm.gd
```

The chart suite covers startup, editing, song playback, timing judgments, sliders, and zones.

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

- `scripts/app.gd` opens the chart library and manages navigation and Settings.
- `scripts/chart_editor.gd` and `scripts/chart_library.gd` handle chart editing and storage.
- `scripts/song_session.gd` and `scripts/song_arena.gd` handle chart judgments and gameplay rendering.
- `scripts/wall_geometry.gd` and `scripts/tuning.gd` define polygon geometry and gameplay constants.
- `openspec/` records requirements and design decisions.
