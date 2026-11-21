## Context

Lockpicker's current Godot run model generates gaps, adjusts approach speed after each clear, and resolves contact through the arcade simulation. Song play needs fixed arrival times and a separate hit action. The existing renderer, six snapped directions, turn animation, and gap geometry provide the basis for both song play and the editor preview. The desktop web target is a single-threaded Godot export.

## Goals / Non-Goals

### Goals

- Use the same chart and timing rules for preview, playtest, and song play.
- Keep a saved draft and its imported audio available locally across sessions.
- Allow the author to rearrange the top bar and the Info / Settings panel without changing chart data or editing commands.

### Non-Goals

- Multi-tempo maps, online chart sharing, and a hosted song catalog are outside this change's scope.

## Decisions

### Store events in beats and drive playback from audio

Store the chart name, audio reference, BPM, first-beat offset, and a list of events containing type, beat position, and direction. Convert event beats to song time using the first-beat offset plus beat position multiplied by 60 divided by BPM. The grid and event positions therefore move together when the author changes the timing settings. The waveform and the playhead use song time directly. Use fractional beat positions so finer snap subdivisions can be added without changing the file format.

Use the audio playback position to drive event approach, preview, and judging. Native builds use the Godot mixer clock with output latency compensation. Browser exports schedule audio through Web Audio and use its output clock. Establish a fresh clock reference on each seek or resume. The endless mode continues to use the arcade simulation. In song mode, radii follow scheduled arrival times, so a hit, miss, or spike cannot accelerate the rest of the pattern. Keep the note available through its late window and allow an early hit to clear it immediately. A spike at the same beat remains visible until its own check, even if a note has cleared early.

### Judge turns and hits at their actual times

Default the left-hand hit action to Space and use the existing wheel turn on the right. Each fresh keypress evaluates the nearest unresolved note whose timing window contains the press, with the earlier note taking precedence on a tie. Judge the animated tip angle at that timestamp. An invalid press leaves the note eligible until its window closes. Check the animated tip angle at the charted beat for each spike and record each outcome once. A simultaneous spike and note in different directions require independent checks.

Share one tuning definition for the timing window, energy restored on success, and energy lost on either a miss or spike hit. Keep a combo and energy counter in the song session. Pause audio and judgment together on loss of focus and resume with a fresh player action.

### Keep the timeline and preview independent of the surrounding layout

Start from the author's sketch. Put the arena preview beside Info / Settings above the full-width grid, and keep the transport, song time, BPM, subdivision, and cursor playtest action close to the grid. The top bar and Info / Settings are provisional. Route their commands and values through the editor state so their position, order, and grouping can change independently. Keep selection feedback to the highlighted marker and its position on the grid.

Seek by clicking the ruler. Use the specified mouse shortcuts in the grid, treating a drag from an existing marker as a move. For the initial editor, placing an event in an occupied lane and beat preserves the existing marker. Record event edits as undoable commands. Draw circles for notes and triangles for spikes. Decode the song into a cached amplitude envelope and draw one low-contrast waveform behind all lanes. Include its visibility toggle in Info / Settings. Reuse the same projection for waveform, cursor, and event positions when scrolling or zooming.

### Run playtests from a draft snapshot

Start whole-song playtest at song time zero. For a cursor playtest, start audio from a short lead-in before the selected time, clamped to the start of the song. Show approaching events during the lead-in and judge events scheduled at or after the selected chart position using their usual timing windows. Reuse the same gameplay and timing rules for a saved chart and a playtest. Return to the same cursor and draft when the author leaves the session.

### Save chart and song as one local draft

Copy imported song data into local game storage and reference it from a versioned chart record. Keep the previous saved chart usable until its replacement has been written successfully. Verify storage and file selection in the desktop web export early, then use the same draft-opening flow in native and browser builds.

## Risks / Trade-offs

- Audio latency and seek behavior can differ between native and web exports. Measure the visual arrival and press judgment against a short reference track, including after seek and focus pause.
- Waveform generation can interrupt editing on the single-threaded browser target. Build the envelope outside rendering and reuse it across redraws. Render the grid immediately and add the waveform when it is ready.
- Very close notes can have overlapping timing windows. Resolve each press once with the same deterministic rule in playtest and song play.

## Migration Plan

Ship the chart library as an additional game entry and verify both song play and the existing arcade entry in the native build and served browser export. Version new chart records from their first save.

## Open Questions

- Final placement of controls in the top bar and Info / Settings.
- Timing-window size, energy values, and lead-in length to tune with the first authored song.
