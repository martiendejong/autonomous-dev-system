const puppeteer = require('puppeteer-core');

async function testChatScroll() {
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

  // Navigate to homepage and login
  console.log('Navigating to homepage...');
  await page.goto('https://localhost:5173', { waitUntil: 'networkidle2' });
  await new Promise(r => setTimeout(r, 1000));

  // Click Login button
  console.log('Opening login form...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button, a'));
    const loginBtn = btns.find(b => b.textContent.trim() === 'Login');
    if (loginBtn) loginBtn.click();
  });
  await new Promise(r => setTimeout(r, 1500));

  // Fill login credentials
  console.log('Logging in as pietjepuk...');
  await page.evaluate(() => {
    function setNativeValue(element, value) {
      const lastValue = element.value;
      element.value = value;
      const event = new Event('input', { bubbles: true });
      const tracker = element._valueTracker;
      if (tracker) tracker.setValue(lastValue);
      element.dispatchEvent(event);
    }

    const inputs = document.querySelectorAll('input');
    const emailInput = Array.from(inputs).find(i => i.type === 'email' || i.type === 'text');
    const passwordInput = Array.from(inputs).find(i => i.type === 'password');

    if (emailInput) setNativeValue(emailInput, 'pietjepuk');
    if (passwordInput) setNativeValue(passwordInput, '4#2WsXdF6YhNmKi*');
  });

  await new Promise(r => setTimeout(r, 500));

  // Click login/submit button
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const submitBtn = btns.find(b =>
      b.textContent.toLowerCase().includes('inloggen') ||
      b.textContent.toLowerCase().includes('login') ||
      b.textContent.toLowerCase().includes('sign in')
    );
    if (submitBtn) submitBtn.click();
  });

  console.log('Waiting for login...');
  await new Promise(r => setTimeout(r, 3000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-login.png' });
  console.log('Screenshot saved: screenshot-after-login.png');

  // Check current URL and page state
  const loginResult = await page.evaluate(() => {
    return {
      url: window.location.href,
      hasChat: !!document.querySelector('[class*="chat"], [class*="message"]'),
      headers: Array.from(document.querySelectorAll('h1, h2')).map(h => h.textContent.trim())
    };
  });

  console.log('After login:');
  console.log('  URL:', loginResult.url);
  console.log('  Has chat UI:', loginResult.hasChat);
  console.log('  Headers:', loginResult.headers);

  // Look for chat or conversation interface
  if (loginResult.url.includes('dashboard') || loginResult.url.includes('chat') || loginResult.hasChat) {
    console.log('\n=== Testing Chat Scroll Behavior ===');

    // Find chat container and test scroll
    const chatInfo = await page.evaluate(() => {
      // Look for scrollable chat container
      const chatContainers = document.querySelectorAll('[class*="chat"], [class*="message"], [class*="scroll"]');
      const results = [];

      chatContainers.forEach((container, i) => {
        results.push({
          index: i,
          className: container.className,
          scrollHeight: container.scrollHeight,
          clientHeight: container.clientHeight,
          scrollTop: container.scrollTop,
          isScrollable: container.scrollHeight > container.clientHeight
        });
      });

      return results;
    });

    console.log('Chat containers found:', chatInfo.length);
    chatInfo.forEach(c => {
      console.log(`  [${c.index}] ${c.className.substring(0, 50)}`);
      console.log(`      scrollHeight: ${c.scrollHeight}, clientHeight: ${c.clientHeight}, scrollTop: ${c.scrollTop}`);
      console.log(`      isScrollable: ${c.isScrollable}`);
    });
  }

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-dashboard.png' });
  console.log('Screenshot saved: screenshot-dashboard.png');

  console.log('\nTest complete!');
}

testChatScroll().catch(err => {
  console.error('Error:', err.message);
});
