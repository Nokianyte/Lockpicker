## Purpose

Provide an endless arcade challenge in which a player aligns shrinking polygon gaps and launches a dot through them using only the mouse wheel.

## ADDED Requirements

### Requirement: Nested shrinking arena
The game SHALL display a dot inside multiple nested polygon walls with visible gaps. All remaining walls SHALL continuously shrink during active play, including launch, bounce, and breaking animations.

#### Scenario: Time passes without input
- **WHEN** the player waits during a run
- **THEN** the remaining walls move inward and reduce the available escape time

### Requirement: Wheel rotation and launch
Scrolling in opposite directions SHALL rotate the innermost remaining polygon in opposite directions without rotating the outer walls. Pressing the middle mouse button SHALL launch the ready dot along its visibly indicated outward path. Holding the button SHALL NOT repeatedly launch, and additional presses during a launch or bounce SHALL NOT queue attempts.

#### Scenario: Align and launch
- **WHEN** the player scrolls while the dot is ready and then presses the wheel
- **THEN** the nearest polygon rotates and the dot launches along the indicated path

#### Scenario: Repeated input during an attempt
- **WHEN** the player presses or holds the wheel during an unresolved attempt
- **THEN** no additional launch is started or queued

### Requirement: Successful crossing
The game SHALL count a crossing only when the entire dot passes through the gap without touching solid wall. It SHALL award exactly one point, briefly break or fade that wall, remove it, and make the next wall the rotation target. A single launch SHALL clear at most one wall.

#### Scenario: Dot fits through the gap
- **WHEN** the dot fully crosses the aligned opening
- **THEN** the crossed wall breaks and disappears, the score increases by one, and the next wall becomes the target

#### Scenario: Gap edge contact
- **WHEN** the dot's edge hits a solid endpoint of the opening
- **THEN** the attempt is treated as a wall hit instead of a successful crossing

### Requirement: Failed attempts cost time
A launch into solid wall SHALL visibly bounce the dot back to its launch position without clearing the wall or awarding points. The player SHALL regain launch control after the bounce, unless crushed first.

#### Scenario: Misaligned launch
- **WHEN** the launched dot strikes solid wall while there is still room to return
- **THEN** it bounces back while the walls keep shrinking and the run continues with the same score

### Requirement: Crushing ends the run
A shrinking wall reaching the resting dot or overtaking it during recovery SHALL end the run. An ordinary outbound launch impact SHALL instead use the bounce behavior. Game over SHALL stop gameplay and show the final layers-cleared score.

#### Scenario: Waiting too long
- **WHEN** an inward-moving wall reaches the dot before it escapes
- **THEN** the run ends and displays its final score

#### Scenario: Crushed during bounce
- **WHEN** a shrinking wall overtakes the returning dot
- **THEN** the run ends instead of granting immunity until the bounce finishes

### Requirement: Endless progression and restart
The game SHALL replenish outer walls for endless play, gradually increase shrink speed with layers cleared, and retain traversable gaps and room for the next attempt. Pressing the wheel from the start or game-over screen SHALL start a fresh run at zero score and initial difficulty without also launching the dot.

#### Scenario: Continued successful play
- **WHEN** the player clears successive walls
- **THEN** new outer walls maintain the challenge and shrink speed increases within the configured playable limits

#### Scenario: Restart
- **WHEN** the player presses the wheel after game over
- **THEN** a fresh arena appears with zero score, reset difficulty, and a ready dot
