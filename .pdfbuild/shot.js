// Screenshot key elements of overview.html (print media) to eyeball design.
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
const exe = ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'].find(fs.existsSync);

(async () => {
  const htmlPath = path.resolve(__dirname, 'overview.html');
  const fileUrl = 'file:///' + htmlPath.replace(/\\/g, '/');
  const browser = await puppeteer.launch({ executablePath: exe, headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--font-render-hinting=none'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 820, height: 1160, deviceScaleFactor: 1.4 });
  await page.emulateMediaType('screen');
  await page.goto(fileUrl, { waitUntil: 'networkidle0', timeout: 60000 });
  await new Promise((r) => setTimeout(r, 400));

  const targets = [
    ['arch', '#s3'],
    ['flow', '#s4'],
    ['er', '#s8'],
    ['ml', '#s9'],
    ['deploy', '#s17'],
    ['dataflow', '#s22'],
  ];
  for (const [name, sel] of targets) {
    const el = await page.$(sel);
    if (!el) { console.log('MISS ' + name); continue; }
    await el.screenshot({ path: path.resolve(__dirname, 'shot_' + name + '.png') });
    console.log('OK ' + name);
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
