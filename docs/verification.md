# Verification

## Smooth turns and centering — 2026-11-20

- Turns now ease over 160 ms while preserving one 60-degree side per notch. Collision follows the animated angle; rapid inputs and reversals preserve their requested side count.
- Clicking during a turn buffers one launch until it finishes. Pause clears a buffered launch.
- Camera follow now settles at the exact viewport midpoint after dash and bounce, without changing world-space movement.
- **570 deterministic checks pass**, including angular collision, turn interpolation, pause/buffer behavior, and 40 impact timings. The latter reproduced and fixed false crushing when the wall's remaining movement within an impact tick overlapped the rebounding dot.
- Local Chrome, Edge, and Firefox browser checks pass without script errors. Screenshot-based dot measurements after settling are within one pixel of the center after bounce and at the center after dash.

## Build and simulation — 2026-11-19

- Godot 4.7.2 stable, standard GDScript build; Compatibility renderer.
- Headless project import and startup pass without script errors.
- Single-threaded Web release export succeeds with matching 4.7.2 templates.
- Deterministic suite: **523 checks, 0 failures**. Includes one-side wheel steps in both directions, unchanged outer-wall orientation, 100 consecutive seeded escapes aligned through actual wheel-step calls, nested-wall spacing, late launches, solid and gap-edge impacts, tunneling prevention, bounce/recovery crushing, pause/resume, restart, and 30/60/120/240 FPS runs.
- Long-run testing exposed unbounded arena growth. Uniform coordinate rescaling after each escape fixes it; visual zoom preserves continuity.

## Local browser checks

Automated browser mouse-wheel and middle-button events were exercised in installed Microsoft Edge, portable official Chrome for Testing 158.0.8127.36, and Playwright Firefox 159. All three loaded the game with no JavaScript errors and no page scrolling. Screenshots confirm successful escape and score increase, game over, restart, resized layout, focus pause, and resume. The test runner is `tools/browser-check.cjs`; screenshots are local ignored outputs under `test-results/`.

Browser checks found and fixed missing explicit web focus handling and a missing favicon request. Header/footer backgrounds keep moving walls away from text.

These are automated input checks, not a human test of a physical wheel. Physical-device feel and sensitivity still need user playtesting; implementation task 5.3 remains open for that portion. Browser-level automated checks also do not replace the deterministic collision suite.

User playtesting requested one polygon side per notch instead of fine angular increments. The control now advances 60 degrees per notch, generated gaps use the same six-position grid, and the first wall takes one upward notch to align. Updated physical-device acceptance remains pending.

## Repeat browser checks

Install Playwright into the ignored `.tools` directory and its test browsers, serve the web export using `node tools/serve.mjs`, then run `node tools/browser-check.cjs http://127.0.0.1:8060 edge` (or `firefox`). The Chrome option expects a portable Chrome for Testing at `.tools/chrome/chrome-win64/chrome.exe`. The runner uses isolated temporary browser profiles and does not access personal browser sessions.

## Hosted build

- [Build and deployment run 44532220947](https://github.com/Nokianyte/Lockpicker/actions/runs/44532220947) passed on 2026-11-19, including the Linux import, simulation checks, web export, and Pages deployment.
- [Live game](https://nokianyte.github.io/Lockpicker/) passed the Chrome play/clear/game-over/restart/resize/pause/resume smoke test with no JavaScript errors or page scrolling.
- Hosted assets resolve correctly under `/Lockpicker/`; the final game pack excludes screenshots, tooling, and planning files.
