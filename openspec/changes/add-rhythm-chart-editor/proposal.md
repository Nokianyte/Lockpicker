## Why

Lockpicker currently generates an endless sequence of layers. An in-game editor will let the author map specific songs, test passages against the actual controls, and revise the chart without leaving the game.

## What Changes

- Add a local chart library and an editor with a six-direction timeline, an arena preview, and the song waveform behind the grid.
- Add song import, BPM and first-beat alignment, grid snapping, direct mouse shortcuts for notes and spikes, and saving and reopening charts.
- Add whole-song and cursor-based playtesting. In song play, the mouse wheel or Left / Right Arrow turns the innermost layer around a fixed center. Z and X handle timed hits. Spikes check alignment on their beat and carry the same penalty as a missed note.
- Use the supplied layout sketch as the first pass. The top bar and Info / Settings panel can be rearranged as the authoring workflow evolves.

## Capabilities

### New Capabilities

- `chart-editor` provides local song-chart authoring, preview, and playtest controls.
- `song-gameplay` provides song-synchronized notes, aiming hazards, scoring feedback, and energy-based failure.

### Modified Capabilities

## Impact

Godot gains an editor scene, local chart and audio storage, and a song mode that shares the arena and turning behavior with the endless game. The existing desktop browser target will need coverage for song import, audio timing, and draft persistence.
