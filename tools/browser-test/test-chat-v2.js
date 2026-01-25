const puppeteer = require('puppeteer-core');

async function testChat() {
  console.log('Connecting to browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // First check what's on screen
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-start.png' });

  // Click the hamburger menu (3 lines icon)
  console.log('Looking for hamburger menu...');
  await page.evaluate(() => {
    // The menu button usually has 3 horizontal lines
    const buttons = document.querySelectorAll('button');
    for (const btn of buttons) {
      // Check if button contains a hamburger icon (svg or spans)
      if (btn.querySelector('svg') || btn.innerHTML.includes('menu')) {
        const rect = btn.getBoundingClientRect();
        // Hamburger is usually in top-left, small button
        if (rect.left < 200 && rect.top < 100 && rect.width < 60) {
          btn.click();
          console.log('Clicked hamburger');
          return true;
        }
      }
    }
    return false;
  });

  await new Promise(r => setTimeout(r, 1000));
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-menu.png' });

  // Look for project list in sidebar
  const elements = await page.evaluate(() => {
    const all = document.querySelectorAll('button, a, [role="button"], li');
    return Array.from(all).map(el => ({
      tag: el.tagName,
      text: el.textContent?.trim().substring(0, 40),
      rect: el.getBoundingClientRect()
    })).filter(e => e.text && e.rect.width > 0).slice(0, 20);
  });

  console.log('\nClickable elements:');
  elements.forEach(e => console.log(`  [${e.tag}] "${e.text}" at (${Math.round(e.rect.left)}, ${Math.round(e.rect.top)})`));

  // Click on a project (one with chat history - try "yo" or others)
  console.log('\nLooking for project to click...');
  const clicked = await page.evaluate(() => {
    const items = document.querySelectorAll('button, a, [role="button"], li, div');
    for (const item of items) {
      const text = item.textContent?.trim();
      if (text === 'yo' || text === 'test' || text === 'a shop') {
        item.click();
        return `Clicked: ${text}`;
      }
    }
    return 'No project found';
  });
  console.log(clicked);

  await new Promise(r => setTimeout(r, 2000));
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-project.png' });

  // Check URL and page state
  const state = await page.evaluate(() => ({
    url: window.location.href,
    title: document.title,
    hasMessages: document.querySelectorAll('[class*="message"]').length > 0,
    hasTextarea: !!document.querySelector('textarea')
  }));

  console.log('\nPage state:');
  console.log('  URL:', state.url);
  console.log('  Has messages:', state.hasMessages);
  console.log('  Has textarea:', state.hasTextarea);

  console.log('\nDone!');
}

testChat().catch(err => console.error('Error:', err.message));
