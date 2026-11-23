// Optional local test runner: npm install --prefix .tools playwright
process.env.PLAYWRIGHT_BROWSERS_PATH ||= require('node:path').resolve('.tools/browsers');
const { chromium, firefox } = require('../.tools/node_modules/playwright');
const fs = require('node:fs');
const assert = require('node:assert/strict');

function testSong() {
  const rate = 8000;
  const frames = 6 * rate;
  const wav = Buffer.alloc(44 + 2 * frames);
  wav.write('RIFF', 0);
  wav.writeUInt32LE(wav.length - 8, 4);
  wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24);
  wav.writeUInt32LE(2 * rate, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36);
  wav.writeUInt32LE(2 * frames, 40);
  for (let frame = 0; frame < frames; frame++) {
    const beatAge = (frame / rate) % 0.5;
    wav.writeInt16LE(Math.round(Math.sin(frame * Math.PI * 880 / rate) * Math.exp(-35 * beatAge) * 7000), 44 + frame * 2);
  }
  return { name: 'Timing.wav', mimeType: 'audio/wav', buffer: wav };
}

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
    if (engine === 'firefox') {
      await page.addInitScript(() => {
        const click = HTMLInputElement.prototype.click;
        HTMLInputElement.prototype.click = function () {
          if (this.type !== 'file') return click.call(this);
        };
      });
    }
    page.on('filechooser', () => {});
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
      return { canvas, screen };
    }
    // A cold hosted load has to fetch the full Godot WebAssembly runtime.
    await page.goto(target, { waitUntil: 'domcontentloaded', timeout: 90000 });
    const { canvas, screen } = await waitForGame();
    if (await page.locator('#game').count()) {
      assert.match(await page.locator('#game').getAttribute('src'), /^\.\/releases\/[a-f0-9]{40}\/index\.html$/);
    }
    fs.mkdirSync('test-results', { recursive: true });
    const save = label => page.screenshot({ path: `test-results/${engine}-${label}.png` });
    const click = async (x, y) => {
      await page.mouse.click(x, y);
      await page.waitForTimeout(120);
    };
    const hits = () => page.screenshot({ clip: { x: 1005, y: 22, width: 75, height: 38 } });
    await save('charts');
    await click(938, 45);
    await save('settings');
    await click(550, 435);
    await click(1031, 45);
    await click(451, 42);
    await page.keyboard.press('Control+a');
    await page.keyboard.type('Browser chart', { delay: 30 });
    await page.keyboard.press('Enter');
    await click(1004, 150);
    await screen.locator('input[type=file]').setInputFiles(testSong(), { timeout: 8000 });
    await page.waitForTimeout(500);
    await click(235, 480);
    await click(358, 518);
    await click(965, 42);
    await page.waitForTimeout(300);
    await save('chart-editor');

    await click(1040, 42);
    const zero = await hits();
    await canvas.evaluate(element => new Promise((resolve, reject) => {
      const win = element.ownerDocument.defaultView;
      const dispatch = (key, code) => {
        const options = { key, code, bubbles: true, cancelable: true };
        element.dispatchEvent(new win.KeyboardEvent('keydown', options));
        element.dispatchEvent(new win.KeyboardEvent('keyup', options));
      };
      const actions = [[1.23, 'z', 'KeyZ'], [1.85, 'ArrowLeft', 'ArrowLeft'], [2.23, 'x', 'KeyX']];
      const deadline = win.performance.now() + 5000;
      const timer = win.setInterval(() => {
        if (win.performance.now() >= deadline) {
          win.clearInterval(timer);
          reject(new Error('Chart audio did not advance through the test notes.'));
          return;
        }
        const [time, key, code] = actions[0];
        if (win.lockpickerSongAudio.position() < time) return;
        dispatch(key, code);
        actions.shift();
        if (!actions.length) {
          win.clearInterval(timer);
          resolve();
        }
      }, 8);
    }));
    await page.waitForTimeout(100);
    assert.notDeepEqual(await hits(), zero, 'timed inputs should score in a user chart');
    await save('chart-playtest');
    await canvas.evaluate(element => element.ownerDocument.defaultView.dispatchEvent(new Event('blur')));
    await page.waitForTimeout(200);
    const paused = await page.screenshot();
    await page.waitForTimeout(200);
    assert.deepEqual(await page.screenshot(), paused, 'a focus pause should hold the playback screen');
    await page.keyboard.press('z');
    await page.waitForTimeout(200);
    assert.notDeepEqual(await page.screenshot(), paused, 'Z should resume the chart');
    await click(51, 42);
    await click(197, 42);
    await save('saved-charts');

    await page.reload();
    const { canvas: reloadedCanvas } = await waitForGame();
    const savedTitles = await reloadedCanvas.evaluate(element => new Promise((resolve, reject) => {
      const request = element.ownerDocument.defaultView.indexedDB.open('lockpicker-charts', 1);
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const db = request.result;
        const charts = db.transaction('charts').objectStore('charts').getAll();
        charts.onerror = () => reject(charts.error);
        charts.onsuccess = () => resolve(charts.result.map(record => JSON.parse(record).title));
        db.close();
      };
    }));
    assert.deepEqual(savedTitles, ['Browser chart']);
    await click(1036, 162);
    await reloadedCanvas.evaluate(element => new Promise((resolve, reject) => {
      const win = element.ownerDocument.defaultView;
      const deadline = win.performance.now() + 5000;
      const timer = win.setInterval(() => {
        try {
          if (win.lockpickerSongAudio.position() > 0.15) {
            win.clearInterval(timer);
            resolve();
            return;
          }
        } catch {
          // The audio clock is unavailable until the saved song loads.
        }
        if (win.performance.now() >= deadline) {
          win.clearInterval(timer);
          reject(new Error('The saved song did not start from the chart library.'));
        }
      }, 20);
    }));
    await click(51, 42);

    await page.setViewportSize({ width: 760, height: 600 });
    await save('charts-resized');
    assert.deepEqual(await page.evaluate(() => [scrollX, scrollY]), [0, 0]);
    assert.deepEqual(errors, []);
    console.log(`${engine}: chart library, song import, save, timed playtest, focus pause, resume, reload, saved-chart playback and resize passed`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
