const puppeteer = require('puppeteer-core');

async function testRegisterForm() {
  console.log('Connecting to Brave browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  if (!page) {
    page = await browser.newPage();
    await page.goto('https://localhost:5173', { waitUntil: 'networkidle2' });
  }

  // Click Registreren link/button
  console.log('Clicking Registreren...');
  await page.evaluate(() => {
    const elements = Array.from(document.querySelectorAll('button, a, span'));
    const regBtn = elements.find(el =>
      el.textContent.trim().toLowerCase() === 'registreren' ||
      el.textContent.trim().toLowerCase() === 'sign up' ||
      el.textContent.trim().toLowerCase() === 'create account'
    );
    if (regBtn) {
      console.log('Found register button:', regBtn.textContent);
      regBtn.click();
    }
  });

  await new Promise(r => setTimeout(r, 2000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-register-form.png', fullPage: false });
  console.log('Screenshot saved: screenshot-register-form.png');

  // Get the form details
  const formDetails = await page.evaluate(() => {
    const inputs = document.querySelectorAll('input');
    const buttons = document.querySelectorAll('button');
    const headers = document.querySelectorAll('h1, h2, h3');

    return {
      headers: Array.from(headers).map(h => h.textContent.trim()),
      inputs: Array.from(inputs).map(i => ({
        type: i.type,
        placeholder: i.placeholder,
        label: i.previousElementSibling?.textContent || i.closest('label')?.textContent || ''
      })),
      buttons: Array.from(buttons).map(b => b.textContent.trim()).filter(t => t.length > 0)
    };
  });

  console.log('\nHeaders:', formDetails.headers);
  console.log('\nForm inputs:');
  formDetails.inputs.forEach(i => {
    console.log(`  - [${i.type}] ${i.placeholder || i.label}`);
  });
  console.log('\nButtons:', formDetails.buttons);

  console.log('\nTest complete!');
}

testRegisterForm().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
