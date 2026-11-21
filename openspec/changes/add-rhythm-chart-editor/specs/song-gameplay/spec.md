## Purpose

Play authored Lockpicker charts in sync with a song using separate turn and hit inputs.

## ADDED Requirements

### Requirement: Song-synchronized layers and turn controls

In song play, each charted note and spike SHALL approach the fixed center on the song timeline and reach it at its charted beat. Each scroll notch or fresh Left or Right Arrow press SHALL turn the innermost pending layer by one 60-degree step. Events on the same beat SHALL share that layer's rotation. The center marker SHALL stay at the top, and each outer layer SHALL keep its charted direction until it becomes the innermost layer. Turning, hitting, or missing one event SHALL preserve the scheduled arrival of later events.

#### Scenario: Turn the innermost layer
- **WHEN** the player scrolls or presses Left or Right Arrow
- **THEN** only the innermost layer and its markers rotate
- **AND** when the layer resolves, the next layer starts in its charted orientation

#### Scenario: Keep the beat after an early hit
- **WHEN** the player hits a note at the early edge of its timing window
- **THEN** the next note still arrives at its own charted beat

### Requirement: Hit notes with a separate key

A note SHALL count as a hit when the player makes a fresh Z or X press within the timing window while the note is aligned with the fixed center marker. Each press SHALL score at most one note. A note SHALL become a miss when its hit window closes without a valid press. The game SHALL give visible feedback for successful hits and misses.

#### Scenario: Play repeated directions
- **WHEN** two consecutive notes use the same gap direction and the player stays aligned
- **THEN** each note still requires its own timed press

#### Scenario: Press with the wrong aim
- **WHEN** the player presses within a note's timing window while its marker is away from the fixed center marker
- **THEN** the press does not score that note

### Requirement: Spikes punish aim at their arrival

A spike SHALL be judged against the fixed marker at its charted beat, independently of the hit key. If the spike lines up with the marker when it arrives, the game SHALL register a spike hit. Notes and spikes in different directions on the same beat SHALL both resolve under their own rules.

#### Scenario: Stay aimed at a spike without pressing
- **WHEN** a spike reaches the fixed marker while lined up with it and the hit key is idle
- **THEN** the game registers a spike hit

#### Scenario: Leave a spike direction before its beat
- **WHEN** the player turns a spike clear of the fixed marker before it arrives
- **THEN** the spike passes without penalty

### Requirement: Energy and combo penalties

A successful note SHALL increase the combo and restore energy up to its maximum. A missed note and a spike hit SHALL each break the combo and remove the same amount of energy. The song SHALL continue while energy remains, fail when energy reaches zero, and report completion if playback reaches the end with energy remaining.

#### Scenario: Compare a missed note and a spike hit
- **WHEN** a missed note and a spike hit are evaluated from the same starting energy and combo in separate runs
- **THEN** both leave the same amount of energy and reset the combo
- **AND** either run continues if its energy remains above zero
