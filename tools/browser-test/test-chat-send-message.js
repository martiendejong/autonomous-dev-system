const puppeteer = require('puppeteer-core');

async function testChatSendMessage() {
  console.log('Connecting to browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Close the sidebar by clicking the X button
  console.log('Closing sidebar...');
  await page.evaluate(() => {
    const closeBtn = document.querySelector('button svg, [class*="close"]');
    const buttons = document.querySelectorAll('button');
    for (const btn of buttons) {
      if (btn.textContent?.includes('×') || btn.querySelector('svg[class*="x"]') || btn.innerHTML.includes('X')) {
        const rect = btn.getBoundingClientRect();
        if (rect.width < 50) { // Small button likely close
          btn.click();
          return 'clicked close';
        }
      }
    }
    // Try clicking outside sidebar
    document.body.click();
    return 'clicked body';
  });

  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-sidebar-closed.png' });

  // Monitor API responses
  page.on('response', async res => {
    if (res.url().includes('/api/chat')) {
      try {
        const body = await res.text();
        console.log(`<< [${res.status()}] ${res.url().split('/').pop()}`);
        if (body.length < 500) console.log(`   ${body}`);
      } catch(e) {}
    }
  });

  // Type in the chat textarea
  console.log('\nTyping test message...');
  const textarea = await page.$('textarea');
  if (textarea) {
    await textarea.click();
    await textarea.type('Hello, this is a test message to check chat scrolling behavior!');
    await new Promise(r => setTimeout(r, 500));
    await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-typed.png' });

    // Find and click send button (or press Enter)
    console.log('Sending message...');
    await page.evaluate(() => {
      // Look for send button (usually has arrow or send icon)
      const buttons = document.querySelectorAll('button');
      for (const btn of buttons) {
        if (btn.querySelector('svg') && btn.closest('form, [class*="input"], [class*="chat"]')) {
          const rect = btn.getBoundingClientRect();
          // Send button is usually near textarea
          if (rect.right > 400 && rect.width < 80) {
            btn.click();
            return 'clicked send';
          }
        }
      }
      return 'no send button found';
    });

    // Alternative: press Enter to send
    await page.keyboard.press('Enter');

    console.log('Waiting for response...');
    await new Promise(r => setTimeout(r, 5000));

    await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-send.png' });

    // Check scroll position after receiving response
    const scrollState = await page.evaluate(() => {
      const containers = document.querySelectorAll('div');
      const scrollable = [];

      containers.forEach(div => {
        if (div.scrollHeight > div.clientHeight + 50 && div.clientHeight > 100) {
          const distanceFromBottom = div.scrollHeight - div.clientHeight - div.scrollTop;
          scrollable.push({
            class: (div.className || '').substring(0, 50),
            scrollHeight: div.scrollHeight,
            clientHeight: div.clientHeight,
            scrollTop: div.scrollTop,
            distanceFromBottom: distanceFromBottom,
            isAtBottom: distanceFromBottom < 30
          });
        }
      });

      return {
        url: window.location.href,
        scrollableContainers: scrollable
      };
    });

    console.log('\n=== SCROLL STATE AFTER MESSAGE ===');
    console.log('URL:', scrollState.url);
    console.log('Scrollable containers:', scrollState.scrollableContainers.length);
    scrollState.scrollableContainers.forEach(s => {
      console.log(`\n  [${s.class}]`);
      console.log(`    scrollHeight: ${s.scrollHeight}, clientHeight: ${s.clientHeight}`);
      console.log(`    scrollTop: ${s.scrollTop}, distanceFromBottom: ${s.distanceFromBottom}`);
      console.log(`    IS AT BOTTOM: ${s.isAtBottom} ${s.isAtBottom ? '✓' : '✗'}`);
    });
  } else {
    console.log('No textarea found!');
  }

  console.log('\nDone!');
}

testChatSendMessage().catch(err => console.error('Error:', err.message));
