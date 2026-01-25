const puppeteer = require('puppeteer-core');

async function simpleChatTest() {
  console.log('Connecting...');
  const browser = await puppeteer.connect({ browserURL: 'http://localhost:9222', defaultViewport: null });
  const pages = await browser.pages();
  const page = pages.find(p => p.url().includes('localhost:5173'));

  // Click X button by coordinates (top-right of sidebar header)
  console.log('Clicking X button at coordinates...');
  await page.mouse.click(340, 25);
  await new Promise(r => setTimeout(r, 500));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/ss1.png' });

  // Check if sidebar closed
  const check1 = await page.evaluate(() => {
    const projectsText = document.body.innerText.includes('Projects\nSearch');
    return { sidebarVisible: projectsText };
  });
  console.log('After X click:', check1);

  // If still open, reload the page
  if (check1.sidebarVisible) {
    console.log('Reloading page to reset state...');
    await page.reload({ waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 2000));
  }

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/ss2.png' });

  // Now interact with the chat - click on textarea area
  console.log('Clicking on chat area...');
  await page.mouse.click(400, 420);
  await new Promise(r => setTimeout(r, 300));

  console.log('Typing test message...');
  await page.keyboard.type('Hello! Testing chat scroll behavior.', { delay: 20 });

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/ss3.png' });

  // Press Enter to send
  console.log('Sending message...');
  await page.keyboard.press('Enter');

  // Wait for AI response
  console.log('Waiting for response...');
  await new Promise(r => setTimeout(r, 6000));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/ss4.png' });

  // Check scroll position
  const scrollInfo = await page.evaluate(() => {
    let chatContainer = null;
    document.querySelectorAll('div').forEach(div => {
      if (div.scrollHeight > div.clientHeight + 100 && div.clientHeight > 150) {
        chatContainer = div;
      }
    });

    if (chatContainer) {
      return {
        found: true,
        scrollHeight: chatContainer.scrollHeight,
        clientHeight: chatContainer.clientHeight,
        scrollTop: chatContainer.scrollTop,
        gapToBottom: chatContainer.scrollHeight - chatContainer.clientHeight - chatContainer.scrollTop,
        isAtBottom: (chatContainer.scrollHeight - chatContainer.clientHeight - chatContainer.scrollTop) < 30
      };
    }
    return { found: false };
  });

  console.log('\n=== SCROLL CHECK ===');
  if (scrollInfo.found) {
    console.log(`Height: ${scrollInfo.scrollHeight}px, View: ${scrollInfo.clientHeight}px`);
    console.log(`ScrollTop: ${scrollInfo.scrollTop}px, Gap to bottom: ${scrollInfo.gapToBottom}px`);
    console.log(`IS AT BOTTOM: ${scrollInfo.isAtBottom ? 'YES ✓' : 'NO ✗'}`);
  } else {
    console.log('No scrollable chat container found');
  }

  console.log('\nDone!');
}

simpleChatTest().catch(e => console.error('Error:', e.message));
