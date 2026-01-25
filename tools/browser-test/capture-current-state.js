const puppeteer = require('puppeteer-core');

async function captureState() {
  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Wait for loading to complete
  await new Promise(r => setTimeout(r, 2000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-current.png', fullPage: true });

  const state = await page.evaluate(() => {
    return {
      url: window.location.href,
      title: document.title,
      headers: Array.from(document.querySelectorAll('h1, h2, h3')).map(h => h.textContent.trim()).slice(0, 5),
      hasChat: !!document.querySelector('[class*="chat"], [class*="message"], textarea'),
      buttons: Array.from(document.querySelectorAll('button')).map(b => b.textContent.trim()).filter(t => t).slice(0, 10)
    };
  });

  console.log('Current state:');
  console.log('  URL:', state.url);
  console.log('  Title:', state.title);
  console.log('  Headers:', state.headers);
  console.log('  Has chat elements:', state.hasChat);
  console.log('  Buttons:', state.buttons);
  console.log('\nScreenshot saved: screenshot-current.png');
}

captureState().catch(err => console.error('Error:', err.message));
