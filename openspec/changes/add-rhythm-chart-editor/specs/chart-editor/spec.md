## Purpose

Let the author create, align, save, and playtest local song charts from inside Lockpicker.

## ADDED Requirements

### Requirement: Open and save local charts

The game SHALL provide an in-game Charts entry where the author can create a named draft, import a local song, save the chart, reopen it, and start song play. Saved charts SHALL retain the song, timing settings, notes, and spikes across game sessions. A failed import or save SHALL report the error and preserve the last saved chart.

#### Scenario: Resume a saved chart
- **WHEN** the author imports a song, sets its timing, places events, saves the chart, and reopens it in a later session
- **THEN** the song and events are available for continued editing and play without another import

### Requirement: Song timeline and arena preview

The editor SHALL display a six-lane timeline, one lane for each gap direction, and an arena preview of incoming notes and spikes at the playhead. The author SHALL be able to seek from the timeline, start and pause song preview, and adjust BPM, first-beat offset, and grid subdivision. The editor SHALL display the current song time and offer actions for saving, returning to Charts, and playing the draft.

#### Scenario: Align the grid to the song
- **WHEN** the author changes BPM or first-beat offset and seeks to a phrase
- **THEN** the beat grid reflects the timing settings and the arena displays the events approaching the selected position

### Requirement: Waveform behind the timeline grid

The editor SHALL derive a waveform from the imported song and display it behind the six lanes. The waveform SHALL share the playhead's song-time axis during scrolling and zooming. Beat lines, notes, spikes, and the playhead SHALL remain distinguishable over the waveform.

#### Scenario: Adjust the beat grid against the waveform
- **WHEN** the author changes the first-beat offset
- **THEN** beat lines and chart events move relative to the waveform while the waveform remains aligned to song time

### Requirement: Place, move, and delete chart events

On the timeline, left-click SHALL place a note, Shift + left-click SHALL place a spike, and right-click on a marker SHALL delete it. Placement SHALL use the clicked direction and the active grid subdivision. Dragging an existing marker SHALL edit its timing or direction. Notes and spikes SHALL have visibly distinct shapes. The author SHALL be able to undo event edits.

#### Scenario: Chart a note and a spike together
- **WHEN** the author left-clicks one lane and Shift + left-clicks a different lane on the same beat
- **THEN** a note and a spike appear independently at that beat
- **AND** right-clicking the spike deletes only the spike

### Requirement: Playtest the current draft

The editor SHALL support playtesting from the beginning and from the current playhead with a short lead-in. It SHALL use the current draft, including unsaved edits, and apply the same note and spike judgment as song play. Exiting playtest SHALL return to the editor with the draft and playhead position available for further editing.

#### Scenario: Test a revised phrase
- **WHEN** the author moves a spike, seeks to the phrase, and selects Playtest from cursor
- **THEN** incoming events are visible during the lead-in and the test uses the edited spike position
- **AND** exiting returns to the selected edit position
