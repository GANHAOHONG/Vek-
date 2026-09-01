const puppeteer = require('puppeteer-core');

async function render() {
  const browser = await puppeteer.launch({
    executablePath: '/usr/local/bin/google-chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 2600, deviceScaleFactor: 2 });
  await page.goto('file:///workspace/preview.html', { waitUntil: 'networkidle0' });

  const el1 = await page.$('#demo1');
  if (el1) await el1.screenshot({ path: '/workspace/solution1_dashboard.png' });

  const el2 = await page.$('#demo2');
  if (el2) await el2.screenshot({ path: '/workspace/solution2_stepped.png' });

  const el3 = await page.$('#demo3');
  if (el3) await el3.screenshot({ path: '/workspace/solution3_minimal.png' });

  await browser.close();
  console.log('All 3 solutions captured successfully!');
}

render().catch(console.error);
