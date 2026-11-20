## Purpose

Provide an endless arcade challenge in which a player aligns the sharp tip of a centered polygon with gaps in shrinking walls using only the mouse wheel.

## ADDED Requirements

### Requirement: Fixed center and shrinking layers
The game SHALL display a pointed polygon centered in multiple nested hexagonal layers, each with a visible gap. The center polygon SHALL stay at the viewport center, and the layers SHALL retain their orientation as they shrink.

#### Scenario: No input
- **WHEN** the player waits during an active run
- **THEN** the layers move inward until the inner layer reaches the tip

### Requirement: Whole-side turns
Each scroll-wheel notch SHALL smoothly rotate the center polygon by one side (60 degrees). Opposite scroll directions SHALL rotate it in opposite directions. Generated gaps SHALL align with reachable orientations.

#### Scenario: Turn toward the next gap
- **WHEN** the player scrolls during play
- **THEN** the pointed polygon turns in place and each layer keeps its existing orientation

### Requirement: Wheel click accelerates the inner layer
During play, one middle-button press SHALL accelerate the innermost layer until it contacts the tip while the outer layers continue shrinking at normal speed. Releasing the button SHALL leave the boost active until contact.

#### Scenario: Aligned speed boost
- **WHEN** the player clicks the wheel with the tip aligned
- **THEN** the approaching layer reaches the tip sooner
- **AND** the next innermost layer moves at its normal speed until another click

### Requirement: Tip contact decides the outcome
When the innermost layer reaches the sharp tip, its gap MUST be aligned with the tip to score. A successful contact SHALL break and remove the layer, add one point, and expose the next layer. Contact with a solid edge SHALL end the run and show the final score.

#### Scenario: Gap meets the tip
- **WHEN** the shrinking layer reaches the aligned tip
- **THEN** it breaks and adds one point even if the player has not pressed the wheel

#### Scenario: Edge meets the tip
- **WHEN** the layer reaches the tip while the tip is aimed at the solid wall or a gap edge
- **THEN** the run ends without awarding a point for that layer

### Requirement: Endless progression and restart
The game SHALL replenish outer layers and shorten the normal aiming window as score increases, down to a playable minimum. An early drop SHALL still leave the next layer's aiming window intact. Clicking the wheel from the start or game-over screen SHALL start a fresh run at zero score and initial difficulty. Starting, restarting, and resuming SHALL require a fresh press to activate the boost.

#### Scenario: Restart
- **WHEN** the player presses the wheel after game over
- **THEN** the layers reset and the tip points up at the start of a fresh run
