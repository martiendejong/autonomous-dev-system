import express from "express";
import { chromium } from "playwright";

const app = express();
app.use(express.json());

(async () => {
  const browser = await chromium.launch({
    headless: false
  });

  const context = await browser.newContext();
  const page = await context.newPage();

  app.post("/cmd", async (req, res) => {
    try {
      const { action, url, selector, text, script, path } = req.body;

      if (action === "goto") {
        await page.goto(url);
        return res.json({ ok: true });
      }

      if (action === "click") {
        await page.click(selector);
        return res.json({ ok: true });
      }

      if (action === "screenshot") {
        const screenshotPath = path || "screenshot.png";
        await page.screenshot({ path: screenshotPath, fullPage: true });
        return res.json({ ok: true, path: screenshotPath });
      }

      if (action === "eval") {
        const result = await page.evaluate(script);
        return res.json({ ok: true, result });
      }

      if (action === "getText") {
        const element = await page.locator(selector);
        const text = await element.textContent();
        return res.json({ ok: true, text });
      }

      if (action === "getHTML") {
        const html = selector
          ? await page.locator(selector).innerHTML()
          : await page.content();
        return res.json({ ok: true, html });
      }

      if (action === "type") {
        await page.fill(selector, text);
        return res.json({ ok: true });
      }

      if (action === "waitFor") {
        await page.waitForSelector(selector, { timeout: 10000 });
        return res.json({ ok: true });
      }

      if (action === "getUrl") {
        return res.json({ ok: true, url: page.url() });
      }

      if (action === "getTitle") {
        const title = await page.title();
        return res.json({ ok: true, title });
      }

      res.status(400).json({ error: "Unknown action" });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  app.listen(3333, () =>
    console.log("Playwright agent running on http://localhost:3333")
  );
})();