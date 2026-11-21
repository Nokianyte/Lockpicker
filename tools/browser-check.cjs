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
    const score = () => page.screenshot({ clip: { x: 920, y: 18, width: 120, height: 25 } });
    const center = () => page.screenshot({ clip: { x: 365, y: 265, width: 370, height: 270 } });
    await canvas.click();
    const zero = await score();

    const started = Date.now();
    const waitUntil = elapsed => page.waitForTimeout(Math.max(0, elapsed - (Date.now() - started)));
    await page.keyboard.press('z');
    await page.keyboard.down('ArrowRight');
    await page.keyboard.down('ArrowRight');
    await page.keyboard.up('ArrowRight');
    await waitUntil(1200);
    await page.keyboard.down('z');
    await waitUntil(1340);
    const afterZ = await score();
    assert.notDeepEqual(afterZ, zero, 'one Right Arrow turn should align the ring even after a repeated keydown');
    await save('rhythm-hit');

    await page.keyboard.press('ArrowLeft');
    await waitUntil(2400);
    await page.keyboard.down('x');
    await page.keyboard.up('z');
    await waitUntil(2540);
    const afterX = await score();
    assert.notDeepEqual(afterX, afterZ, 'Left Arrow should align the second ring and X should score while Z is held');

    await page.mouse.wheel(0, -120);
    await waitUntil(3600);
    await page.keyboard.down('x');
    await waitUntil(3750);
    assert.deepEqual(await score(), afterX, 'a repeated keydown should not score');
    await page.keyboard.up('x');
    await save('rhythm-miss');

    await canvas.evaluate(element => element.ownerDocument.defaultView.dispatchEvent(new Event('blur')));
    await page.waitForTimeout(100);
    const paused = await center();
    await page.waitForTimeout(200);
    assert.deepEqual(await center(), paused, 'pause should freeze the chart');
    await save('rhythm-paused');
    await page.keyboard.press('z');
    await page.waitForTimeout(200);
    assert.notDeepEqual(await center(), paused, 'Z should resume the chart');
    assert.deepEqual(await score(), afterX, 'resume should preserve the score');

    await page.waitForTimeout(850);
    const crashed = await center();
    await page.waitForTimeout(200);
    assert.deepEqual(await center(), crashed, 'the first unavoided spike should freeze the run');
    await save('rhythm-spike-hit');
    await page.keyboard.press('x');
    await page.waitForTimeout(150);
    assert.deepEqual(await score(), zero, 'X should start a fresh chart after a spike hit');

    await page.setViewportSize({ width: 760, height: 600 });
    await save('rhythm-resize');
    assert.deepEqual(await page.evaluate(() => [scrollX, scrollY]), [0, 0]);
    assert.deepEqual(errors, []);
    console.log(`${engine}: arrow and wheel turns, timed Z and X hits, key-repeat suppression, pause, resume, spike crash, retry and resize passed at ${target}`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
