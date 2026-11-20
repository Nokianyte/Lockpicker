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
    async function waitForGame() {
      await page.locator('#canvas, #game').first().waitFor({ state: 'attached', timeout: 90000 });
      const screen = await page.locator('#game').count() ? page.frameLocator('#game') : page;
      const canvas = screen.locator('#canvas');
      await canvas.waitFor({ state: 'visible', timeout: 90000 });
      const notice = screen.locator('#status-notice');
      await Promise.race([
        screen.locator('#status').waitFor({ state: 'detached', timeout: 90000 }),
        notice.waitFor({ state: 'visible', timeout: 90000 }).then(async () => {
          throw new Error(await notice.innerText());
        }),
      ]);
      await canvas.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      return canvas;
    }
    // A cold hosted load has to fetch the full Godot WebAssembly runtime.
    await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 90000 });
    const canvas = await waitForGame();
    if (await page.locator('#game').count()) {
      assert.match(await page.locator('#game').getAttribute('src'), /^\.\/releases\/[a-f0-9]{40}\/index\.html$/);
    }
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
    await save('aligned-tip');
    assert.notDeepEqual(await core(), beforeTurn, 'scroll should rotate the central polygon');
    await page.mouse.click(550, 400, clearInput);
    await page.waitForTimeout(250);
    const afterClear = await score();
    assert.notDeepEqual(afterClear, zero, 'one click should drop the aligned layer within 250 ms');
    await save('layer-cleared');
    await canvas.evaluate(element => element.ownerDocument.defaultView.dispatchEvent(new Event('blur')));
    await page.waitForTimeout(150);
    await save('paused-refinement');
    await page.mouse.click(550, 400, clearInput);
    await page.waitForTimeout(200);
    assert.deepEqual(await score(), afterClear, 'resume should preserve the score');

    await page.reload({ waitUntil: 'domcontentloaded', timeout: 90000 });
    await waitForGame();
    await page.mouse.click(550, 400, clearInput);
    await page.mouse.click(550, 400, clearInput);
    await page.waitForTimeout(250);
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
    console.log(`${engine}: rotation, single-click boost, clear, miss, restart, resize and pause/resume passed at ${target}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
