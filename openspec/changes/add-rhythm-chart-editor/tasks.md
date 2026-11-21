## 1. Chart data and audio

- [x] 1.1 Define the versioned chart format, six-direction mapping, beat-to-song-time conversion, and checks for invalid timing and event data.
- [x] 1.2 Add local song import and durable draft storage. Verify an imported audio file and its chart survive a restart in the native build and a reload in a served web export.
- [x] 1.3 Add song transport with playback, pause, and seeking. Verify the clock with a reference track before and after seeking and resuming.

## 2. Song play

- [x] 2.1 Add song-driven layer approach and render notes and spikes with the shared arena. Verify one event's outcome leaves later arrival times intact.
- [x] 2.2 Wire wheel turns and the independent keyboard hit action. Implement note timing and aim checks, plus spike aim checks at the charted beat.
- [x] 2.3 Add hit and miss feedback, combo, and energy. Verify equal penalties for a miss and a spike hit, energy recovery from hits, song completion, and failure at zero energy.

## 3. In-game chart editor

- [x] 3.1 Add the Charts entry and editor screen. Build the first layout from the sketch and connect the provisional top bar and Info / Settings to shared editor state.
- [x] 3.2 Build the six-lane timeline, playhead, BPM and offset controls, subdivision picker, scroll and zoom, and scrubbed arena preview.
- [x] 3.3 Add left-click note placement, Shift + left-click spike placement, right-click deletion, marker dragging, and undo. Verify note and spike markers in different lanes at the same beat stay independently editable.
- [x] 3.4 Generate and cache the song waveform. Render it behind the grid, add its visibility toggle, and verify alignment and marker readability when seeking, scrolling, and zooming.
- [x] 3.5 Connect save, reopen, and saved-chart play. Verify a failed import or save leaves the last saved draft usable.

## 4. Playtest and verify

- [x] 4.1 Run the current draft through song gameplay from the start or from the cursor with a lead-in. Verify unsaved edits are heard and seen in playtest and the editor restores the cursor on exit.
- [x] 4.2 Check note and spike timing at hit-window boundaries, repeated directions, overlapping windows, simultaneous events, and focus loss. Tune the timing window, energy, and lead-in against a short authored phrase.
- [x] 4.3 Exercise import, chart editing, playtest, save, and reopen in the native and served desktop web builds. Run the arcade regression suite and check that its entry still plays with the original wheel controls.
