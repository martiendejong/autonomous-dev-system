const puppeteer = require('puppeteer-core');

async function testLogin() {
  console.log('Connecting to Brave browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Set up request monitoring
  page.on('request', req => {
    if (req.url().includes('/api/')) {
      console.log(`>> ${req.method()} ${req.url()}`);
      if (req.postData()) console.log(`   Body: ${req.postData()}`);
    }
  });
  page.on('response', async res => {
    if (res.url().includes('/api/')) {
      let body = '';
      try { body = await res.text(); } catch(e) {}
      console.log(`<< [${res.status()}] ${res.url()}`);
      if (body) console.log(`   Response: ${body.substring(0, 300)}`);
    }
  });

  // Click the Inloggen button (form should already be filled from previous test)
  console.log('Clicking Inloggen button...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const loginBtn = btns.find(b => b.textContent.toLowerCase().includes('inloggen'));
    if (loginBtn) loginBtn.click();
  });

  await new Promise(r => setTimeout(r, 3000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-login-result.png' });

  // Check for errors
  const result = await page.evaluate(() => {
    const errors = document.querySelectorAll('.text-red-500, .text-red-600, [class*="error"]');
    return {
      url: window.location.href,
      errors: Array.from(errors).map(e => e.textContent.trim()).filter(t => t),
      pageTitle: document.title
    };
  });

  console.log('\nResult:');
  console.log('  URL:', result.url);
  console.log('  Title:', result.pageTitle);
  if (result.errors.length) console.log('  Errors:', result.errors);

  console.log('\nDone!');
}

testLogin().catch(err => console.error('Error:', err.message));
