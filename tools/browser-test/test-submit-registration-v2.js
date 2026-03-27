const puppeteer = require('puppeteer-core');

async function testSubmitRegistration() {
  console.log('Connecting to Brave browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  if (!page) {
    console.log('No Brand2Boost page found!');
    return;
  }

  // First make sure we're on the registration form
  // Click Registreren to ensure the registration form is showing
  console.log('Opening registration form...');
  await page.evaluate(() => {
    const elements = Array.from(document.querySelectorAll('button, a, span'));
    const regBtn = elements.find(el =>
      el.textContent.trim().toLowerCase() === 'registreren' ||
      el.textContent.trim().toLowerCase() === 'sign up'
    );
    if (regBtn) regBtn.click();
  });

  await new Promise(r => setTimeout(r, 1500));

  // Generate unique test email
  const testEmail = `test-${Date.now()}@example.com`;
  const testPassword = 'TestPassword123!';
  const testName = 'Test User Frank';

  console.log(`Test credentials: ${testName} / ${testEmail}`);

  // Clear and fill form using Puppeteer's type method (simulates real keyboard input)
  console.log('Filling form fields...');

  // Find all inputs and identify them
  const inputs = await page.$$('input');
  console.log(`Found ${inputs.length} input fields`);

  for (const input of inputs) {
    const inputType = await input.evaluate(el => el.type);
    const placeholder = await input.evaluate(el => el.placeholder);

    if (inputType === 'text' && placeholder === 'John Doe') {
      console.log('Filling Full Name field...');
      await input.click({ clickCount: 3 }); // Select all
      await input.type(testName);
    }
    else if (inputType === 'email' || placeholder === 'you@example.com') {
      console.log('Filling Email field...');
      await input.click({ clickCount: 3 });
      await input.type(testEmail);
    }
    else if (inputType === 'password' && placeholder === '••••••••') {
      const isConfirm = await input.evaluate(el => {
        const label = el.closest('.flex-col')?.querySelector('label, span, div');
        return label?.textContent?.toLowerCase().includes('confirm');
      });
      if (!isConfirm) {
        console.log('Filling Password field...');
        await input.click({ clickCount: 3 });
        await input.type(testPassword);
      }
    }
  }

  // Fill confirm password separately (second password field)
  const passwordInputs = await page.$$('input[type="password"]');
  if (passwordInputs.length >= 2) {
    console.log('Filling Confirm Password field...');
    await passwordInputs[1].click({ clickCount: 3 });
    await passwordInputs[1].type(testPassword);
  }

  await new Promise(r => setTimeout(r, 500));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-filled-form-v2.png' });
  console.log('Screenshot saved: screenshot-filled-form-v2.png');

  // Set up network interception before clicking submit
  const requests = [];
  const responses = [];

  page.on('request', request => {
    if (request.url().includes('register') || request.url().includes('auth') || request.url().includes('account')) {
      requests.push({
        url: request.url(),
        method: request.method(),
        postData: request.postData()
      });
      console.log(`>> API Request: ${request.method()} ${request.url()}`);
    }
  });

  page.on('response', async response => {
    if (response.url().includes('register') || response.url().includes('auth') || response.url().includes('account')) {
      try {
        const status = response.status();
        const text = await response.text();
        responses.push({ status, text: text.substring(0, 500) });
        console.log(`<< API Response [${status}]: ${text.substring(0, 200)}`);
      } catch (e) {}
    }
  });

  // Click Create Account button
  console.log('\nClicking Create Account...');
  await page.evaluate(() => {
    const buttons = Array.from(document.querySelectorAll('button'));
    const createBtn = buttons.find(b =>
      b.textContent.trim().toLowerCase().includes('create account')
    );
    if (createBtn) {
      console.log('Found button:', createBtn.textContent);
      createBtn.click();
    } else {
      console.log('Create Account button not found!');
    }
  });

  // Wait for API response
  await new Promise(r => setTimeout(r, 4000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-submit-v2.png' });
  console.log('Screenshot saved: screenshot-after-submit-v2.png');

  // Check for error or success messages
  const result = await page.evaluate(() => {
    const errorDiv = document.querySelector('.text-red-500, .text-red-700, [class*="error"], [role="alert"]');
    const successMsg = document.querySelector('[class*="success"], [class*="green"]');
    const toastMsg = document.querySelector('[class*="toast"], [class*="notification"]');

    return {
      error: errorDiv?.textContent?.trim() || null,
      success: successMsg?.textContent?.trim() || null,
      toast: toastMsg?.textContent?.trim() || null,
      currentUrl: window.location.href
    };
  });

  console.log('\n=== RESULT ===');
  console.log('Current URL:', result.currentUrl);
  if (result.error) console.log('Error:', result.error);
  if (result.success) console.log('Success:', result.success);
  if (result.toast) console.log('Toast:', result.toast);

  console.log('\nAPI Requests captured:', requests.length);
  requests.forEach(r => {
    console.log(`  ${r.method} ${r.url}`);
    if (r.postData) console.log(`  Body: ${r.postData.substring(0, 200)}`);
  });

  console.log('\nAPI Responses captured:', responses.length);
  responses.forEach(r => {
    console.log(`  Status: ${r.status}`);
    console.log(`  Body: ${r.text}`);
  });

  console.log('\n=== TEST COMPLETE ===');
}

testSubmitRegistration().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
