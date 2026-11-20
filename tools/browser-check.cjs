// Optional local test runner: npm install --prefix .tools playwright
process.env.PLAYWRIGHT_BROWSERS_PATH ||= require('node:path').resolve('.tools/browsers');
const { chromium, firefox } = require('../.tools/node_modules/playwright');
const fs = require('node:fs');
(async () => {
  const target = process.argv[2] || 'http://127.0.0.1:8060';
  const engine = process.argv[3] || 'edge';
  const browser = engine === 'firefox'
    ? await firefox.launch({ headless: true })
    : await chromium.launch({ channel: engine === 'edge' ? 'msedge' : undefined, executablePath: engine === 'chrome' ? require('node:path').resolve('.tools/chrome/chrome-win64/chrome.exe') : undefined, headless: true });
  const page = await browser.newPage({ viewport: { width: 1100, height: 800 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(target);
  await page.locator('#status').waitFor({ state: 'hidden', timeout: 30000 });
  await page.waitForTimeout(500);
  fs.mkdirSync('test-results', { recursive: true });
  await page.screenshot({ path: `test-results/${engine}-title.png` });
  await page.mouse.click(550, 450, { button: 'middle' });
  await page.waitForTimeout(150);
  // Deliberate miss: the first gap starts one side away from the launch path.
  await page.mouse.click(550, 450, { button: 'middle' });
  await page.waitForTimeout(1400);
  async function verifyCentered(label) {
    const shot = await page.screenshot({ path: `test-results/${engine}-${label}-center.png` });
    const dot = await page.evaluate(async (base64) => {
      const picture = new Image(); picture.src = 'data:image/png;base64,' + base64;
      await picture.decode();
      const canvas = document.createElement('canvas'); canvas.width = picture.width; canvas.height = picture.height;
      const ctx = canvas.getContext('2d'); ctx.drawImage(picture, 0, 0);
      const cx = canvas.width / 2, cy = canvas.height / 2;
      const pixels = ctx.getImageData(cx - 12, cy - 12, 24, 24).data;
      let count = 0, x = 0, y = 0;
      for (let i = 0; i < pixels.length; i += 4) {
        if (pixels[i] > 220 && pixels[i + 1] > 230 && pixels[i + 2] > 220) {
          count++; x += (i / 4) % 24 - 11.5; y += Math.floor(i / 4 / 24) - 11.5;
        }
      }
      return { count, x: x / count, y: y / count };
    }, shot.toString('base64'));
    if (dot.count < 20 || Math.abs(dot.x) > 2 || Math.abs(dot.y) > 2) throw new Error(`${label}: dot not centered: ${JSON.stringify(dot)}`);
    return dot;
  }
  const bounceCenter = await verifyCentered('bounce');
  // One notch advances one full side, undoing the first wall's 60-degree offset.
  await page.mouse.wheel(0, -120);
  await page.waitForTimeout(100);
  await page.screenshot({ path: `test-results/${engine}-aim.png` });
  await page.mouse.click(550, 450, { button: 'middle' });
  await page.waitForTimeout(1100);
  await page.screenshot({ path: `test-results/${engine}-clear.png` });
  const dashCenter = await verifyCentered('dash');
  await page.mouse.click(550, 450, { button: 'middle' });
  await page.waitForTimeout(70);
  await page.screenshot({ path: `test-results/${engine}-attempt.png` });
  await page.waitForTimeout(13000);
  await page.screenshot({ path: `test-results/${engine}-over.png` });
  await page.mouse.click(550, 450, { button: 'middle' });
  await page.waitForTimeout(100);
  await page.setViewportSize({ width: 760, height: 600 });
  await page.screenshot({ path: `test-results/${engine}-restart-resize.png` });
  // A real browser blur event exercises the engine's focus-loss notification.
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await page.waitForTimeout(200);
  await page.screenshot({ path: `test-results/${engine}-pause.png` });
  await page.mouse.click(380, 300, { button: 'middle' });
  await page.waitForTimeout(200);
  await page.screenshot({ path: `test-results/${engine}-resume.png` });
  const scroll = await page.evaluate(() => ({ x: scrollX, y: scrollY }));
  console.log(JSON.stringify({ engine, target, errors, scroll, bounceCenter, dashCenter }, null, 2));
  await browser.close();
  if (errors.length || scroll.x || scroll.y) process.exitCode = 1;
})().catch(e => { console.error(e); process.exit(1); });
