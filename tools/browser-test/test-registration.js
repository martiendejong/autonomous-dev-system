const puppeteer = require('puppeteer-core');

async function testRegistration() {
  console.log('Connecting to Brave browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  // Get the Brand2Boost page
  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  if (!page) {
    console.log('Opening Brand2Boost...');
    page = await browser.newPage();
  }

  // Go to homepage first
  console.log('Navigating to homepage...');
  await page.goto('https://localhost:5173', { waitUntil: 'networkidle2' });
  await new Promise(r => setTimeout(r, 1000));

  console.log('Current URL:', page.url());

  // Click the Login button in the header
  console.log('Clicking Login button...');
  try {
    // Use evaluate to find and click the login button
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll('button, a'));
      const loginBtn = buttons.find(b => b.textContent.trim() === 'Login');
      if (loginBtn) loginBtn.click();
    });
    await new Promise(r => setTimeout(r, 2000));
  } catch (e) {
    console.log('Could not click login button:', e.message);
  }

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-login-page.png' });
  console.log('Screenshot saved: screenshot-login-page.png');
  console.log('Current URL after login click:', page.url());

  // Now look for "Sign up" or "Create account" link to go to registration
  console.log('Looking for Sign up link...');
  const pageContent = await page.content();

  // Check for sign up elements
  const hasSignUp = pageContent.toLowerCase().includes('sign up') ||
                    pageContent.toLowerCase().includes('create account') ||
                    pageContent.toLowerCase().includes('register');
  console.log('Page has registration option:', hasSignUp);

  // Try to click Sign up link
  try {
    const signUpLink = await page.evaluate(() => {
      const links = Array.from(document.querySelectorAll('a, button, span'));
      const signUp = links.find(el =>
        el.textContent.toLowerCase().includes('sign up') ||
        el.textContent.toLowerCase().includes('create account')
      );
      if (signUp) {
        signUp.click();
        return true;
      }
      return false;
    });

    if (signUpLink) {
      console.log('Clicked sign up link');
      await new Promise(r => setTimeout(r, 1500));
    }
  } catch (e) {
    console.log('Could not find/click sign up link:', e.message);
  }

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-register-page.png' });
  console.log('Screenshot saved: screenshot-register-page.png');

  // Get form elements
  const formElements = await page.evaluate(() => {
    const inputs = document.querySelectorAll('input');
    const buttons = document.querySelectorAll('button');
    return {
      inputs: Array.from(inputs).map(i => ({
        type: i.type,
        placeholder: i.placeholder,
        name: i.name,
        id: i.id
      })),
      buttons: Array.from(buttons).map(b => b.textContent.trim().substring(0, 50)),
      h1: Array.from(document.querySelectorAll('h1, h2')).map(h => h.textContent.trim())
    };
  });

  console.log('\nPage headers:', formElements.h1);
  console.log('Form inputs:', JSON.stringify(formElements.inputs, null, 2));
  console.log('Buttons:', formElements.buttons.filter(b => b.length > 0));

  console.log('\nTest complete! Check the screenshots.');
}

testRegistration().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
