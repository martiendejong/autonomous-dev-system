#!/usr/bin/env node
/**
 * OAuth Authentication using localhost redirect
 */

import { google } from "googleapis";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { exec } from "child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const SCOPES = [
  "https://www.googleapis.com/auth/drive.file",
  "https://www.googleapis.com/auth/drive"
];

const CREDENTIALS_PATH = path.join(__dirname, "credentials.json");
const OAUTH_KEYS_PATH = path.join(__dirname, "oauth-keys.json");
const PORT = 3000;

async function main() {
  if (!fs.existsSync(OAUTH_KEYS_PATH)) {
    console.error(`OAuth keys not found at: ${OAUTH_KEYS_PATH}`);
    process.exit(1);
  }

  const keys = JSON.parse(fs.readFileSync(OAUTH_KEYS_PATH, "utf-8"));
  const { client_id, client_secret } = keys.installed;

  const oauth2Client = new google.auth.OAuth2(
    client_id,
    client_secret,
    `http://localhost:${PORT}`
  );

  const authUrl = oauth2Client.generateAuthUrl({
    access_type: "offline",
    scope: SCOPES,
    prompt: "consent"
  });

  console.log("\n===========================================");
  console.log("GOOGLE DRIVE AUTHENTICATION");
  console.log("===========================================\n");
  console.log(`Starting local server on port ${PORT}...`);
  console.log("\nOpening browser for authentication...\n");

  // Create a simple HTTP server to receive the callback
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    const code = url.searchParams.get("code");
    const error = url.searchParams.get("error");

    if (error) {
      res.writeHead(400, { "Content-Type": "text/html" });
      res.end(`<h1>Error</h1><p>${error}</p><p>You can close this window.</p>`);
      server.close();
      process.exit(1);
    }

    if (code) {
      try {
        const { tokens } = await oauth2Client.getToken(code);
        fs.writeFileSync(CREDENTIALS_PATH, JSON.stringify(tokens, null, 2));

        res.writeHead(200, { "Content-Type": "text/html" });
        res.end(`
          <html>
            <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
              <h1 style="color: green;">Success!</h1>
              <p>Google Drive authentication complete.</p>
              <p>You can close this window and return to the terminal.</p>
            </body>
          </html>
        `);

        console.log(`\nCredentials saved to: ${CREDENTIALS_PATH}`);
        console.log("Authentication successful! You can now use the upload tool.");

        server.close();
        process.exit(0);
      } catch (err) {
        res.writeHead(500, { "Content-Type": "text/html" });
        res.end(`<h1>Error</h1><p>${err.message}</p>`);
        console.error("Error:", err.message);
        server.close();
        process.exit(1);
      }
    } else {
      res.writeHead(200, { "Content-Type": "text/html" });
      res.end("<p>Waiting for authorization...</p>");
    }
  });

  server.listen(PORT, () => {
    console.log(`Server listening on http://localhost:${PORT}`);
    console.log("\nIf browser doesn't open automatically, visit:\n");
    console.log(authUrl);
    console.log("\n");

    // Try to open browser
    const openCommand = process.platform === "win32"
      ? `start "" "${authUrl}"`
      : process.platform === "darwin"
        ? `open "${authUrl}"`
        : `xdg-open "${authUrl}"`;

    exec(openCommand, (err) => {
      if (err) {
        console.log("Could not open browser automatically.");
        console.log("Please open the URL above manually.");
      }
    });
  });

  // Timeout after 5 minutes
  setTimeout(() => {
    console.log("\nTimeout: No authorization received within 5 minutes.");
    server.close();
    process.exit(1);
  }, 5 * 60 * 1000);
}

main().catch(console.error);
