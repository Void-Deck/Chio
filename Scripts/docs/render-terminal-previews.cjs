#!/usr/bin/env node
// Render actual terminal initial-frame casts with the repository's pinned player.
// Playwright is an external tooling prerequisite, never a Chio package dependency.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const args = process.argv.slice(2);
let moduleName = 'playwright';
if (args[0] === '--playwright') {
  if (!args[1]) throw new Error('--playwright requires an installed module directory');
  moduleName = path.resolve(args[1]);
  args.splice(0, 2);
}
const checkOnly = args.length === 1 && args[0] === '--check';
if (!checkOnly && (args.length === 0 || args.some(arg => arg.startsWith('--')))) {
  throw new Error('Usage: node render-terminal-previews.cjs [--playwright MODULE] --check | CAST-initial.cast ...');
}

async function main() {
  let chromium;
  try {
    ({ chromium } = require(moduleName));
  } catch (error) {
    throw new Error('Playwright is required. Supply --playwright with an installed module directory.', { cause: error });
  }
  const vendor = path.join(root, 'Docs/Site/vendor/asciinema-player');
  const css = fs.readFileSync(path.join(vendor, 'asciinema-player.css'), 'utf8');
  const script = path.join(vendor, 'asciinema-player.min.js');
  fs.accessSync(script, fs.constants.R_OK);
  const captures = checkOnly ? [] : args.map(argument => {
    const file = fs.realpathSync(argument);
    const relative = path.relative(root, file);
    const insideCheckout = !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative);
    if ((insideCheckout && !relative.startsWith('.build' + path.sep)) || !file.endsWith('-initial.cast')) {
      throw new Error('Initial-frame casts must be outside the checkout or beneath its ignored .build directory.');
    }
    const text = fs.readFileSync(file, 'utf8');
    const header = JSON.parse(text.split('\n')[0]);
    if (header.version !== 2 || !Number.isInteger(header.width) || !Number.isInteger(header.height)
        || header.width < 1 || header.width > 300 || header.height < 1 || header.height > 200) {
      throw new Error(`Unsupported terminal allocation: ${file}`);
    }
    const output = file.slice(0, -'-initial.cast'.length) + '.png';
    if (fs.existsSync(output)) throw new Error(`Refusing to replace an existing preview: ${output}`);
    return { file, text, header, output };
  });
  const browser = await chromium.launch({ headless: true, timeout: 10000 });
  activeBrowser = browser;
  try {
    if (checkOnly) {
      console.log('PASS: vendored player, Playwright and Chromium are available');
      return;
    }
    for (const { file, text, header, output } of captures) {
      const page = await browser.newPage({
        viewport: { width: Math.max(1600, header.width * 20), height: Math.max(1800, header.height * 30) },
        deviceScaleFactor: 1,
      });
      try {
        page.setDefaultTimeout(10000);
        const errors = [];
        page.on('pageerror', error => errors.push(error.message));
        await page.setContent('<!doctype html><html><head><meta charset="utf-8"></head><body><div id="player"></div></body></html>');
        await page.addStyleTag({ content: css + '\nhtml,body{margin:0;padding:0;background:#000}#player{display:inline-block}div.ap-wrapper{justify-content:flex-start}div.ap-wrapper div.ap-player,div.ap-term{border:0;border-radius:0}' });
        await page.addScriptTag({ path: script });
        await page.evaluate(({ data, cols, rows }) => {
          const player = AsciinemaPlayer.create(data, document.querySelector('#player'), {
            cols, rows, fit: 'none', controls: false, autoplay: true,
            terminalFontSize: '20px', terminalLineHeight: 1.2, cursorMode: 'steady', keystrokeOverlay: false,
          });
          player.addEventListener('ended', () => { document.body.dataset.ready = 'true'; });
          player.addEventListener('error', () => { document.body.dataset.ready = 'error'; });
        }, { data: 'data:application/x-asciicast;base64,' + Buffer.from(text).toString('base64'), cols: header.width, rows: header.height });
        await page.waitForFunction(() => document.body.dataset.ready, null, { timeout: 20000 });
        if (await page.locator('body').getAttribute('data-ready') !== 'true' || errors.length) {
          throw new Error(`Player failed for ${file}: ${errors.join(', ')}`);
        }
        await page.evaluate(() => document.fonts.ready);
        const terminal = page.locator('.ap-term');
        const rendered = await terminal.innerText();
        if (!rendered.includes('chio') || /runtime warning|collection\.unboundedRealization|error:/i.test(rendered)) {
          throw new Error(`Initial frame is missing Chio content or contains diagnostics: ${file}`);
        }
        await terminal.screenshot({ path: output, animations: 'disabled' });
        console.log(`CAPTURE: ${path.basename(output)} (${header.width} × ${header.height})`);
      } finally {
        await page.close();
      }
    }
  } finally {
    await browser.close();
    activeBrowser = null;
  }
}

// Bound the complete renderer lifetime even if the browser stops responding.
let activeBrowser = null;
const deadline = setTimeout(() => {
  console.error('Preview rendering exceeded 150 seconds');
  setTimeout(() => process.exit(1), 5000);
  Promise.resolve(activeBrowser?.close()).finally(() => process.exit(1));
}, 150000);
main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => clearTimeout(deadline));
