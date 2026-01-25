const puppeteer = require('puppeteer-core');

async function enterProjectChat() {
  console.log('Connecting to browser...');

  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null
  });

  const pages = await browser.pages();
  let page = pages.find(p => p.url().includes('localhost:5173'));

  // Monitor API calls
  page.on('request', req => {
    if (req.url().includes('/api/chat') || req.url().includes('/api/project')) {
      console.log(`>> ${req.method()} ${req.url()}`);
    }
  });
  page.on('response', async res => {
    if (res.url().includes('/api/chat') || res.url().includes('/api/project')) {
      console.log(`<< [${res.status()}] ${res.url()}`);
    }
  });

  // Click on "a business to help people become rich" project (likely has more chat history)
  console.log('Clicking on project "a business to help people become rich"...');

  await page.evaluate(() => {
    const items = document.querySelectorAll('button, div, span');
    for (const item of items) {
      if (item.textContent?.trim() === 'a business to help people become rich') {
        item.click();
        return true;
      }
    }
    return false;
  });

  await new Promise(r => setTimeout(r, 3000));
  await page.screenshot({ path: 'C:/scripts/tools/browser-test/screenshot-in-project.png' });

  // Check current state
  const state = await page.evaluate(() => {
    // Look for chat messages
    const allDivs = document.querySelectorAll('div');
    const messageContainers = [];

    allDivs.forEach(div => {
      const classList = div.className || '';
      if (classList.includes('message') || classList.includes('chat') || classList.includes('bubble')) {
        messageContainers.push({
          class: classList.substring(0, 60),
          text: div.textContent?.substring(0, 100)
        });
      }
    });

    // Find scroll containers
    const scrollable = [];
    allDivs.forEach(div => {
      if (div.scrollHeight > div.clientHeight && div.clientHeight > 100) {
        scrollable.push({
          class: (div.className || '').substring(0, 60),
          scrollHeight: div.scrollHeight,
          clientHeight: div.clientHeight,
          scrollTop: div.scrollTop,
          isScrolledToBottom: Math.abs(div.scrollHeight - div.clientHeight - div.scrollTop) < 20
        });
      }
    });

    return {
      url: window.location.href,
      messageContainers: messageContainers.slice(0, 5),
      scrollableAreas: scrollable.slice(0, 5),
      hasTextarea: !!document.querySelector('textarea'),
      pageText: document.body.textContent?.substring(0, 500)
    };
  });

  console.log('\nProject state:');
  console.log('  URL:', state.url);
  console.log('  Has textarea:', state.hasTextarea);
  console.log('  Message containers:', state.messageContainers.length);
  state.messageContainers.forEach(m => console.log(`    - [${m.class}] ${m.text?.substring(0, 50)}`));
  console.log('  Scrollable areas:', state.scrollableAreas.length);
  state.scrollableAreas.forEach(s => {
    console.log(`    - [${s.class}]`);
    console.log(`      scrollHeight=${s.scrollHeight}, clientHeight=${s.clientHeight}, scrollTop=${s.scrollTop}`);
    console.log(`      isScrolledToBottom=${s.isScrolledToBottom}`);
  });

  console.log('\nDone!');
}

enterProjectChat().catch(err => console.error('Error:', err.message));
