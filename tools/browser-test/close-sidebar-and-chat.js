const puppeteer = require('puppeteer-core');

async function closeSidebarAndChat() {
  console.log('Connecting to browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Click the X button in the sidebar header - it's the button with × text
  console.log('Looking for X close button...');

  const closeResult = await page.evaluate(() => {
    // Find the X button - it's in the Projects header
    const buttons = document.querySelectorAll('button');
    for (const btn of buttons) {
      // Check if button has X icon (SVG with path forming X)
      const svg = btn.querySelector('svg');
      if (svg) {
        const paths = svg.querySelectorAll('path, line');
        // X icon usually has 2 lines crossing
        if (paths.length === 2 || svg.innerHTML.toLowerCase().includes('x')) {
          const rect = btn.getBoundingClientRect();
          if (rect.top < 80) { // In header area
            btn.click();
            return `Clicked X at (${rect.left}, ${rect.top})`;
          }
        }
      }
    }

    // Alternative: click outside the sidebar (right side of screen)
    const event = new MouseEvent('click', {
      bubbles: true,
      cancelable: true,
      clientX: 600, // Right side
      clientY: 300
    });
    document.elementFromPoint(600, 300)?.dispatchEvent(event);
    return 'Clicked outside sidebar';
  });

  console.log('Close result:', closeResult);
  await new Promise(r => setTimeout(r, 800));

  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-closed.png' });

  // Check if sidebar is closed
  const sidebarOpen = await page.evaluate(() => {
    const sidebar = document.querySelector('[class*="sidebar"], [class*="drawer"]');
    const projectsHeader = Array.from(document.querySelectorAll('h1, h2, div')).find(
      el => el.textContent?.trim() === 'Projects'
    );
    return {
      hasSidebar: !!sidebar,
      hasProjectsHeader: !!projectsHeader,
      projectsVisible: projectsHeader?.getBoundingClientRect().width > 0
    };
  });

  console.log('Sidebar state:', sidebarOpen);

  // If sidebar still open, try pressing Escape
  if (sidebarOpen.projectsVisible) {
    console.log('Pressing Escape to close sidebar...');
    await page.keyboard.press('Escape');
    await new Promise(r => setTimeout(r, 500));
    await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-escape.png' });
  }

  // Now type in the chat
  console.log('\nLooking for chat textarea...');
  const textarea = await page.$('textarea');

  if (textarea) {
    console.log('Found textarea, clicking...');
    await textarea.click();
    await new Promise(r => setTimeout(r, 300));

    console.log('Typing message...');
    await page.keyboard.type('Test message for scroll behavior', { delay: 30 });

    await new Promise(r => setTimeout(r, 300));
    await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-message-typed.png' });

    // Send the message
    console.log('Pressing Enter to send...');
    await page.keyboard.press('Enter');

    console.log('Waiting for AI response...');
    await new Promise(r => setTimeout(r, 8000));

    await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-after-response.png' });

    // Check scroll state
    const scrollState = await page.evaluate(() => {
      const allDivs = document.querySelectorAll('div');
      const scrollable = [];

      allDivs.forEach(div => {
        const overflow = getComputedStyle(div).overflowY;
        if ((overflow === 'auto' || overflow === 'scroll') && div.scrollHeight > div.clientHeight) {
          scrollable.push({
            class: (div.className || '').substring(0, 40),
            scrollHeight: div.scrollHeight,
            clientHeight: div.clientHeight,
            scrollTop: div.scrollTop,
            scrollBottom: div.scrollHeight - div.clientHeight - div.scrollTop,
            isAtBottom: div.scrollHeight - div.clientHeight - div.scrollTop < 20
          });
        }
      });

      return scrollable;
    });

    console.log('\n=== SCROLL STATE ===');
    scrollState.forEach(s => {
      console.log(`[${s.class}]`);
      console.log(`  height: ${s.scrollHeight}px, view: ${s.clientHeight}px`);
      console.log(`  scrollTop: ${s.scrollTop}, gap to bottom: ${s.scrollBottom}px`);
      console.log(`  AT BOTTOM: ${s.isAtBottom ? 'YES ✓' : 'NO ✗'}`);
    });
  } else {
    console.log('No textarea found - sidebar may be blocking');
  }

  console.log('\nDone!');
}

closeSidebarAndChat().catch(err => console.error('Error:', err.message));
