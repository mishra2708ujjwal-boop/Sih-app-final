// Renders overview.html -> "APP OVERVIEW.pdf" (project root) using the
// system-installed Chrome/Edge via puppeteer-core (no bundled Chromium).
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const candidates = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
];
const exe = candidates.find((p) => fs.existsSync(p));
if (!exe) {
  console.error('No Chromium-based browser found.');
  process.exit(1);
}
console.log('Using browser: ' + exe);

(async () => {
  const htmlPath = path.resolve(__dirname, 'overview.html');
  const outPath = path.resolve(__dirname, '..', 'APP OVERVIEW.pdf');
  const fileUrl = 'file:///' + htmlPath.replace(/\\/g, '/');

  const browser = await puppeteer.launch({
    executablePath: exe,
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--font-render-hinting=none'],
  });
  const page = await browser.newPage();
  await page.goto(fileUrl, { waitUntil: 'networkidle0', timeout: 60000 });
  // Give the layout engine a beat to settle SVG/text metrics.
  await new Promise((r) => setTimeout(r, 400));

  const footer = `
    <div style="font-size:7.5px;width:100%;padding:0 15mm;color:#8a978f;
                font-family:'Segoe UI',Arial,sans-serif;display:flex;
                justify-content:space-between;align-items:center;
                border-top:0.4px solid #d9e2dc;padding-top:3px;">
      <span style="letter-spacing:.05em;text-transform:uppercase;">PRANA &middot; App Overview &amp; Judge Prep</span>
      <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
    </div>`;
  const header = `<div style="height:0;"></div>`;

  await page.pdf({
    path: outPath,
    format: 'A4',
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: header,
    footerTemplate: footer,
    margin: { top: '11mm', bottom: '16mm', left: '0mm', right: '0mm' },
  });
  await browser.close();
  console.log('WROTE ' + outPath);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
