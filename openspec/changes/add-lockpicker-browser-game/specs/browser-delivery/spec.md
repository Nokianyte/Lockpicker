## Purpose

Make Lockpicker playable from a shared browser URL and make its source and build instructions available through GitHub.

## ADDED Requirements

### Requirement: Desktop browser play
The delivered game SHALL run from a browser URL without a local installation on desktop Chrome, Edge, and Firefox. It SHALL show the wheel controls before play and keep the arena, score, and game-over information readable when the window is resized.

#### Scenario: First visit
- **WHEN** a player opens the published URL in a supported browser
- **THEN** the game loads and explains how to rotate the center polygon and hold the wheel to speed up the inner layer

#### Scenario: Resize
- **WHEN** the player resizes the browser window
- **THEN** the arena maintains its proportions and essential controls and score remain visible

### Requirement: Browser input ownership
Wheel input over the active game SHALL control the game without page scrolling or middle-button autoscroll. Losing focus SHALL pause gameplay and cancel any active speed boost. Returning SHALL require an explicit middle-button resume action, followed by a fresh press to boost.

#### Scenario: Wheel interaction
- **WHEN** a player scrolls or middle-clicks over the active game
- **THEN** the intended game action occurs without browser scrolling or autoscroll

#### Scenario: Focus loss
- **WHEN** the player switches away and later returns
- **THEN** the game remains paused until explicitly resumed, with no hidden loss of escape time

### Requirement: Source and playable publication
The project SHALL publish its Godot source and build instructions to the selected GitHub repository and provide a working GitHub Pages game URL. Documentation SHALL identify the tested engine version, local run and web export steps, controls, and playable URL. Build automation SHALL use matching pinned engine and export-template versions.

#### Scenario: Reproduce the game
- **WHEN** a developer follows the documented setup and export instructions from the repository
- **THEN** they can run the project and produce the browser build

#### Scenario: Published deployment
- **WHEN** a successful release is deployed to GitHub Pages
- **THEN** its URL loads all game assets, including when hosted under a repository subpath, and supports a complete play-and-restart cycle
