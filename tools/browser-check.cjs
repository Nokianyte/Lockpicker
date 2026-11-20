// Optional local test runner: npm install --prefix .tools playwright
process.env.PLAYWRIGHT_BROWSERS_PATH ||= require('node:path').resolve('.tools/browsers');
const { chromium, firefox } = require('../.tools/node_modules/playwright');
const fs = require('node:fs');
const assert = require('node:assert/strict');

(async () => {
  const target = process.argv[2] || 'http://127.0.0.1:8060';
  const engine = process.argv[3] || 'edge';
  const browser = engine === 'firefox'
    ? await firefox.launch({ headless: true })
    : await chromium.launch({
      channel: engine === 'edge' ? 'msedge' : undefined,
      executablePath: engine === 'chrome' ? require('node:path').resolve('.tools/chrome/chrome-win64/chrome.exe') : undefined,
      headless: true,
    });
  try {
    const page = await browser.newPage({ viewport: { width: 1100, height: 800 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    // A cold hosted load has to fetch the full Godot WebAssembly runtime.
    await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.locator('#status').waitFor({ state: 'hidden', timeout: 90000 });
    fs.mkdirSync('test-results', { recursive: true });
    const save = label => page.screenshot({ path: `test-results/${engine}-${label}.png` });
    const score = () => page.screenshot({ clip: { x: 915, y: 50, width: 50, height: 30 } });
    const core = () => page.screenshot({ clip: { x: 528, y: 329, width: 44, height: 143 } });
    const clearInput = { button: 'middle' };
    await page.mouse.click(550, 400, clearInput);
    await page.waitForTimeout(200);
    const zero = await score();
    const beforeTurn = await core();
    await page.mouse.wheel(0, 120);
    await page.waitForTimeout(240);
    assert.notDeepEqual(await core(), beforeTurn, 'scroll should rotate the central polygon');
    await save('aligned-tip');
    await page.mouse.down(clearInput);
    await page.waitForTimeout(1800);
    await page.mouse.up(clearInput);
    const afterClear = await score();
    assert.notDeepEqual(afterClear, zero, 'aligned layer should clear during boost');
    await save('layer-cleared');
    await page.evaluate(() => window.dispatchEvent(new Event('blur')));
    await page.waitForTimeout(150);
    await save('paused-refinement');
    await page.mouse.click(550, 400, clearInput);
    await page.waitForTimeout(200);
    assert.deepEqual(await score(), afterClear, 'resume should preserve the score');

    await page.reload({ waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.locator('#status').waitFor({ state: 'hidden', timeout: 90000 });
    await page.mouse.click(550, 400, clearInput);
    await page.mouse.down(clearInput);
    await page.waitForTimeout(2000);
    await page.mouse.up(clearInput);
    assert.deepEqual(await score(), zero, 'misaligned contact should not score');
    const gameOver = await core();
    await save('missed-gap');
    await page.mouse.click(550, 400, clearInput);
    await page.waitForTimeout(150);
    assert.notDeepEqual(await core(), gameOver, 'middle click should restart after a miss');
    await page.setViewportSize({ width: 760, height: 600 });
    await save('refinement-resize');
    assert.deepEqual(await page.evaluate(() => [scrollX, scrollY]), [0, 0]);
    assert.deepEqual(errors, []);
    console.log(`${engine}: rotation, hold-to-boost clear, miss, restart, resize and pause/resume passed at ${target}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
