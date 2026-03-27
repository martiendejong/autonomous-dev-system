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

  // Generate unique test data
  const testEmail = `test-${Date.now()}@example.com`;
  const testPassword = 'TestPassword123!';
  const testName = 'Test User Frank';

  console.log(`Test credentials: ${testName} / ${testEmail}`);

  // First ensure registration form is open
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

  // Fill form using native input simulation (React-compatible)
  console.log('Filling form with React-compatible input simulation...');

  const fillResult = await page.evaluate((name, email, password) => {
    function setNativeValue(element, value) {
      const lastValue = element.value;
      element.value = value;
      const event = new Event('input', { bubbles: true });
      // React 15/16 hack
      const tracker = element._valueTracker;
      if (tracker) {
        tracker.setValue(lastValue);
      }
      element.dispatchEvent(event);
    }

    const inputs = document.querySelectorAll('input');
    const inputArray = Array.from(inputs);

    const results = [];

    // Find and fill name input (text type with John Doe placeholder)
    const nameInput = inputArray.find(i => i.type === 'text' && i.placeholder === 'John Doe');
    if (nameInput) {
      setNativeValue(nameInput, name);
      results.push('Name filled');
    } else {
      results.push('Name input NOT found');
    }

    // Find and fill email input
    const emailInput = inputArray.find(i => i.type === 'email' || i.placeholder === 'you@example.com');
    if (emailInput) {
      setNativeValue(emailInput, email);
      results.push('Email filled');
    } else {
      results.push('Email input NOT found');
    }

    // Find and fill password inputs
    const passwordInputs = inputArray.filter(i => i.type === 'password');
    if (passwordInputs[0]) {
      setNativeValue(passwordInputs[0], password);
      results.push('Password filled');
    }
    if (passwordInputs[1]) {
      setNativeValue(passwordInputs[1], password);
      results.push('Confirm password filled');
    }

    return results;
  }, testName, testEmail, testPassword);

  console.log('Fill results:', fillResult);

  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-filled-v3.png' });
  console.log('Screenshot saved: screenshot-filled-v3.png');

  // Set up request/response logging
  const apiCalls = [];
  page.on('request', req => {
    if (req.url().includes('/api/') || req.url().includes('register') || req.url().includes('account')) {
      apiCalls.push({ type: 'request', method: req.method(), url: req.url(), body: req.postData() });
      console.log(`>> ${req.method()} ${req.url()}`);
    }
  });
  page.on('response', async res => {
    if (res.url().includes('/api/') || res.url().includes('register') || res.url().includes('account')) {
      let body = '';
      try { body = await res.text(); } catch(e) {}
      apiCalls.push({ type: 'response', status: res.status(), url: res.url(), body });
      console.log(`<< [${res.status()}] ${res.url()}`);
    }
  });

  // Click submit
  console.log('\nSubmitting form...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const submitBtn = btns.find(b => b.textContent.toLowerCase().includes('create account'));
    if (submitBtn) {
      submitBtn.click();
      return 'Clicked Create Account';
    }
    return 'Submit button not found';
  });

  // Wait for response
  await new Promise(r => setTimeout(r, 4000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-result-v3.png' });
  console.log('Screenshot saved: screenshot-result-v3.png');

  // Get result
  const result = await page.evaluate(() => {
    const errors = document.querySelectorAll('.text-red-500, .text-red-600, .text-red-700, [class*="error"]');
    const success = document.querySelectorAll('[class*="success"], .text-green-500, .text-green-600');
    const alerts = document.querySelectorAll('[role="alert"]');

    return {
      url: window.location.href,
      errors: Array.from(errors).map(e => e.textContent.trim()).filter(t => t),
      success: Array.from(success).map(s => s.textContent.trim()).filter(t => t),
      alerts: Array.from(alerts).map(a => a.textContent.trim()).filter(t => t)
    };
  });

  console.log('\n=== RESULT ===');
  console.log('URL:', result.url);
  if (result.errors.length) console.log('Errors:', result.errors);
  if (result.success.length) console.log('Success:', result.success);
  if (result.alerts.length) console.log('Alerts:', result.alerts);
  console.log('API calls:', apiCalls.length);
  apiCalls.forEach(c => {
    if (c.type === 'request') console.log(`  >> ${c.method} ${c.url}`);
    else console.log(`  << [${c.status}] ${c.body?.substring(0, 150) || ''}`);
  });

  console.log('\nDone!');
}

testSubmitRegistration().catch(err => {
  console.error('Error:', err.message);
});
