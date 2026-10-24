// Takes the Play Store screenshots from a web build of lib/shots.dart.
//
//   flutter build web --release -t lib/shots.dart -o build/shots
//   npx http-server build/shots -p 8793 -c-1 --silent
//   node tool/store_shots.js 8793 [device ...]
//
// ONLY=03 retakes just the shots whose name starts with "03".
// EXPLORE="level=7&skin=slime" PORT... takes one phone shot per second of
// skip (2..40) into store/explore/ to find good moments for a new shot.
//
// Needs `playwright` resolvable from where it's run (not a project
// dependency — install it in a scratch folder and run from there).
// Viewports are logical points × device pixel density, so the UI is the
// size it is on the real device.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const WEB = path.join(ROOT, 'build', 'shots');
const OUT = path.join(ROOT, 'store');

const DEVICES = {
  phone: { w: 360, h: 720, scale: 3 }, // 1080 x 2160
  'tablet-7in': { w: 600, h: 960, scale: 2 }, // 1200 x 1920
  'tablet-10in': { w: 800, h: 1280, scale: 2 }, // 1600 x 2560
};

// name, query, ms to let the scene settle before the shutter. Google Play
// takes at most 8 per device type.
const SHOTS = [
  ['01-run-and-grow', 's=play&level=7&skin=slime&trail=rainbow&skip=9', 120],
  ['02-sliding-saws', 's=play&level=9&skin=ball&trail=sparkle&skip=3&focus=sweep', 120],
  ['03-changing-gates', 's=play&level=8&skin=candy&trail=rainbow&skip=3&focus=cycling', 120],
  ['04-holes', 's=play&level=10&skin=cube&trail=fire&skip=3&focus=hole', 120],
  ['05-break-the-walls', 's=play&level=7&skin=slime&trail=rainbow&skip=27', 60],
  ['06-bonus-stairs', 's=play&level=7&skin=slime&trail=rainbow&skip=33', 60],
  ['07-shop', 's=shop&skin=slime&trail=rainbow', 600],
  ['08-menu', 's=menu', 1500],
];

async function routeCanvasKit(page) {
  // The bootstrap fetches CanvasKit from gstatic; serve the bundled copy.
  await page.route('https://www.gstatic.com/flutter-canvaskit/**', async (route) => {
    const rest = new URL(route.request().url()).pathname.split('/').filter(Boolean).slice(2).join('/');
    const local = path.join(WEB, 'canvaskit', rest);
    if (!fs.existsSync(local)) return route.continue();
    const type = local.endsWith('.wasm') ? 'application/wasm' : 'application/javascript';
    await route.fulfill({ status: 200, contentType: type, body: fs.readFileSync(local) });
  });
}

async function shoot(browser, port, device, query, settleMs, file) {
  const d = DEVICES[device];
  const page = await browser.newPage({ viewport: { width: d.w, height: d.h }, deviceScaleFactor: d.scale });
  page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
  // lib/shots.dart prints SHOT_READY once the scene is staged
  // (fast-forward done).
  const ready = page.waitForEvent('console', { predicate: (m) => m.text() === 'SHOT_READY', timeout: 120000 });
  await routeCanvasKit(page);
  await page.goto(`http://127.0.0.1:${port}/?${query}`, { waitUntil: 'networkidle', timeout: 60000 });
  await ready;
  await page.waitForTimeout(300 + settleMs);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await page.screenshot({ path: file });
  await page.close();
}

(async () => {
  const port = process.argv[2] || '8793';
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  if (process.env.EXPLORE) {
    const step = Number(process.env.STEP || 2);
    for (let s = Number(process.env.FROM || 2); s <= Number(process.env.TO || 40); s += step) {
      const file = path.join(OUT, 'explore', `${String(s).padStart(2, '0')}.png`);
      await shoot(browser, port, 'phone', `${process.env.EXPLORE}&skip=${s}`, 150, file);
      console.log(file);
    }
  } else {
    const devices = process.argv.slice(3).length ? process.argv.slice(3) : Object.keys(DEVICES);
    for (const device of devices) {
      for (const [name, query, settle] of SHOTS) {
        if (process.env.ONLY && !name.startsWith(process.env.ONLY)) continue;
        const file = path.join(OUT, device, `${name}.png`);
        await shoot(browser, port, device, query, settle, file);
        console.log(file);
      }
    }
  }
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
