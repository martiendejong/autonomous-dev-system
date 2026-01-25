const puppeteer = require('puppeteer-core');

async function testSubmitRegistration() {
  console.log('Connecting to Brave browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Fill in the registration form
  console.log('Filling registration form...');

  // Generate unique test email
  const testEmail = `test-${Date.now()}@example.com`;
  const testPassword = 'TestPassword123!';

  await page.evaluate((email, password) => {
    const inputs = document.querySelectorAll('input');
    const inputArray = Array.from(inputs);

    // Find form inputs by placeholder or type
    const nameInput = inputArray.find(i => i.placeholder === 'John Doe' || i.type === 'text');
    const emailInput = inputArray.find(i => i.placeholder === 'you@example.com' || i.type === 'email');
    const passwordInputs = inputArray.filter(i => i.type === 'password');

    if (nameInput) {
      nameInput.value = 'Test User Frank';
      nameInput.dispatchEvent(new Event('input', { bubbles: true }));
    }

    if (emailInput) {
      emailInput.value = email;
      emailInput.dispatchEvent(new Event('input', { bubbles: true }));
    }

    if (passwordInputs[0]) {
      passwordInputs[0].value = password;
      passwordInputs[0].dispatchEvent(new Event('input', { bubbles: true }));
    }

    if (passwordInputs[1]) {
      passwordInputs[1].value = password;
      passwordInputs[1].dispatchEvent(new Event('input', { bubbles: true }));
    }
  }, testEmail, testPassword);

  await new Promise(r => setTimeout(r, 500));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-filled-form.png' });
  console.log('Screenshot saved: screenshot-filled-form.png');
  console.log(`Test email: ${testEmail}`);

  // Click Create Account button
  console.log('Clicking Create Account...');

  // Listen for network requests to capture the API call
  const requests = [];
  page.on('request', request => {
    if (request.url().includes('register') || request.url().includes('auth')) {
      requests.push({
        url: request.url(),
        method: request.method(),
        postData: request.postData()
      });
    }
  });

  page.on('response', async response => {
    if (response.url().includes('register') || response.url().includes('auth')) {
      try {
        const text = await response.text();
        console.log(`API Response [${response.status()}]: ${text.substring(0, 200)}`);
      } catch (e) {}
    }
  });

  await page.evaluate(() => {
    const buttons = Array.from(document.querySelectorAll('button'));
    const createBtn = buttons.find(b =>
      b.textContent.trim().toLowerCase().includes('create account') ||
      b.textContent.trim().toLowerCase().includes('registreren')
    );
    if (createBtn) {
      createBtn.click();
    }
  });

  // Wait for response
  await new Promise(r => setTimeout(r, 3000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-submit.png' });
  console.log('Screenshot saved: screenshot-after-submit.png');

  // Check for error messages or success
  const result = await page.evaluate(() => {
    const errorDiv = document.querySelector('.text-red-500, .text-red-700, [class*="error"]');
    const successMsg = document.querySelector('[class*="success"], [class*="green"]');
    const alertMsg = document.querySelector('[role="alert"]');

    return {
      error: errorDiv?.textContent || null,
      success: successMsg?.textContent || null,
      alert: alertMsg?.textContent || null,
      currentUrl: window.location.href
    };
  });

  console.log('\nResult:');
  console.log('  Current URL:', result.currentUrl);
  if (result.error) console.log('  Error:', result.error);
  if (result.success) console.log('  Success:', result.success);
  if (result.alert) console.log('  Alert:', result.alert);

  console.log('\nAPI Requests captured:', requests.length);
  requests.forEach(r => console.log(`  ${r.method} ${r.url}`));

  console.log('\nTest complete!');
}

testSubmitRegistration().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
