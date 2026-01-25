# Browser Test Tools

Puppeteer-based browser automation scripts for testing Brand2Boost and other web applications.

## Prerequisites

1. **Node.js** with puppeteer-core installed:
   ```bash
   npm install puppeteer-core
   ```

2. **Browser with remote debugging enabled:**
   ```powershell
   # Start Brave with debugging
   & "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe" --remote-debugging-port=9222
   ```

## Available Scripts

| Script | Purpose |
|--------|---------|
| `test-registration.js` | Navigate to registration page |
| `test-register-form.js` | Inspect registration form elements |
| `test-submit-registration-v3.js` | Fill and submit registration (React-compatible) |
| `test-login-submit.js` | Test login flow |
| `test-chat-scroll.js` | Test chat scroll behavior |
| `capture-current-state.js` | Screenshot current browser state |
| `simple-chat-test.js` | Basic chat interaction test |

## Usage

```bash
cd C:\scripts\tools\browser-test
node test-submit-registration-v3.js
```

## Test Results Location

All screenshots and test artifacts should be saved to:
```
C:\testresults\<application>\<test-name-YYYY-MM-DD>\
```

Example:
```
C:\testresults\brand2boost\frank-tasks-verification-2026-01-14\
├── TEST_SUMMARY.md
├── screenshot-filled-v3.png
├── screenshot-result-v3.png
└── ...
```

## Key Techniques

### React Form Input (Critical!)
React apps require special handling - see `C:\scripts\_machine\best-practices\browser-testing.md`

```javascript
// This WON'T work with React:
input.value = 'test';

// This WILL work:
function setNativeValue(el, val) {
  const last = el.value;
  el.value = val;
  const tracker = el._valueTracker;
  if (tracker) tracker.setValue(last);
  el.dispatchEvent(new Event('input', { bubbles: true }));
}
```

### API Monitoring
Add request/response listeners before actions to capture API calls.

### Click by Coordinates
When overlays or complex UI blocks elements, use `page.mouse.click(x, y)`.

## Test Credentials (Brand2Boost Dev)

| User | Password | Role |
|------|----------|------|
| wreckingball | Th1s1sSp4rt4! | ADMIN |
| pietjepuk | 4#2WsXdF6YhNmKi* | ADMIN |

## Related Documentation

- Best Practices: `C:\scripts\_machine\best-practices\browser-testing.md`
- Test Results: `C:\testresults\`
- Reflection Log: `C:\scripts\_machine\reflection.log.md`
