const puppeteer = require('puppeteer-core');

async function enterExistingProject() {
  console.log('Connecting...');
  const browser = await puppeteer.connect({ browserURL: 'http://localhost:9222', defaultViewport: null });
  const pages = await browser.pages();
  const page = pages.find(p => p.url().includes('localhost:5173'));

  // Monitor API calls
  page.on('response', async res => {
    if (res.url().includes('/api/')) {
      const url = res.url().split('/api/')[1];
      console.log(`<< [${res.status()}] /api/${url}`);
    }
  });

  // Open hamburger menu
  console.log('Opening menu...');
  await page.mouse.click(155, 32);
  await new Promise(r => setTimeout(r, 1000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/proj1.png' });

  // Click on "a business to help people become rich" project (first project, likely has history)
  console.log('Clicking on first project...');
  await page.mouse.click(180, 155);  // Click on the project card
  await new Promise(r => setTimeout(r, 3000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/proj2.png' });

  // Check current state
  const state = await page.evaluate(() => {
    return {
      url: window.location.href,
      hasMessages: document.querySelectorAll('[class*="message"]').length,
      pageText: document.body.innerText.substring(0, 300)
    };
  });

  console.log('\nState after clicking project:');
  console.log('  URL:', state.url);
  console.log('  Message elements:', state.hasMessages);
  console.log('  Page text preview:', state.pageText.replace(/\n/g, ' ').substring(0, 150));

  // Wait a bit more for any loading
  await new Promise(r => setTimeout(r, 2000));
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/proj3.png' });

  console.log('\nDone!');
}

enterExistingProject().catch(e => console.error('Error:', e.message));
