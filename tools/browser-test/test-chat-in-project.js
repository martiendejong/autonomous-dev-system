const puppeteer = require('puppeteer-core');

async function testChatInProject() {
  console.log('Connecting to browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Click on one of the existing projects (sidebar menu)
  console.log('Opening sidebar menu...');
  await page.evaluate(() => {
    // Look for hamburger menu or sidebar toggle
    const menuBtn = document.querySelector('[class*="menu"], button svg, .hamburger');
    if (menuBtn) menuBtn.click();
  });
  await new Promise(r => setTimeout(r, 1000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-menu-open.png' });

  // Look for projects list
  const projectsList = await page.evaluate(() => {
    const buttons = Array.from(document.querySelectorAll('button, a, div[role="button"]'));
    return buttons.map(b => b.textContent?.trim()).filter(t => t && t.length < 50).slice(0, 15);
  });
  console.log('Available buttons/links:', projectsList);

  // Click on "yo" project (it has chat history based on earlier API response)
  console.log('\nClicking on "yo" project...');
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button, a, div[role="button"]'));
    const projectBtn = btns.find(b => b.textContent?.trim() === 'yo');
    if (projectBtn) {
      console.log('Found yo project button');
      projectBtn.click();
    }
  });
  await new Promise(r => setTimeout(r, 2000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-project-yo.png' });

  // Check for chat messages
  const chatState = await page.evaluate(() => {
    const messages = document.querySelectorAll('[class*="message"], [class*="chat-item"], [class*="bubble"]');
    const scrollContainers = document.querySelectorAll('[class*="scroll"], [class*="overflow"]');

    const scrollInfo = [];
    scrollContainers.forEach((container, i) => {
      if (container.scrollHeight > 100) {
        scrollInfo.push({
          index: i,
          class: container.className?.substring(0, 60),
          scrollHeight: container.scrollHeight,
          clientHeight: container.clientHeight,
          scrollTop: container.scrollTop,
          atBottom: Math.abs((container.scrollTop + container.clientHeight) - container.scrollHeight) < 10
        });
      }
    });

    return {
      url: window.location.href,
      messageCount: messages.length,
      scrollContainers: scrollInfo
    };
  });

  console.log('\nChat state:');
  console.log('  URL:', chatState.url);
  console.log('  Message elements found:', chatState.messageCount);
  console.log('  Scroll containers:', chatState.scrollContainers.length);
  chatState.scrollContainers.forEach(s => {
    console.log(`    [${s.index}] ${s.class}`);
    console.log(`        scrollHeight=${s.scrollHeight} clientHeight=${s.clientHeight} scrollTop=${s.scrollTop}`);
    console.log(`        atBottom=${s.atBottom}`);
  });

  // Try to find and test the chat input
  console.log('\nLooking for chat input...');
  const hasTextarea = await page.evaluate(() => {
    return !!document.querySelector('textarea, input[type="text"][class*="chat"]');
  });
  console.log('  Has chat input:', hasTextarea);

  console.log('\nDone!');
}

testChatInProject().catch(err => console.error('Error:', err.message));
