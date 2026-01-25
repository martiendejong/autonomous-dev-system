#!/usr/bin/env node
/**
 * Manual OAuth Authentication for Google Drive
 *
 * This script provides a manual OAuth flow where you:
 * 1. Copy a URL to your browser
 * 2. Authorize the app
 * 3. Paste the authorization code back
 */

import { google } from "googleapis";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import readline from "readline";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const SCOPES = [
  "https://www.googleapis.com/auth/drive.file",
  "https://www.googleapis.com/auth/drive"
];

const CREDENTIALS_PATH = path.join(__dirname, "credentials.json");
const OAUTH_KEYS_PATH = path.join(__dirname, "oauth-keys.json");

async function main() {
  if (!fs.existsSync(OAUTH_KEYS_PATH)) {
    console.error(`OAuth keys not found at: ${OAUTH_KEYS_PATH}`);
    process.exit(1);
  }

  const keys = JSON.parse(fs.readFileSync(OAUTH_KEYS_PATH, "utf-8"));
  const { client_id, client_secret, redirect_uris } = keys.installed;

  const oauth2Client = new google.auth.OAuth2(
    client_id,
    client_secret,
    "urn:ietf:wg:oauth:2.0:oob"  // Out-of-band flow
  );

  const authUrl = oauth2Client.generateAuthUrl({
    access_type: "offline",
    scope: SCOPES,
    prompt: "consent"
  });

  console.log("\n===========================================");
  console.log("GOOGLE DRIVE AUTHENTICATION");
  console.log("===========================================\n");
  console.log("1. Open this URL in your browser:\n");
  console.log(authUrl);
  console.log("\n2. Authorize the app and copy the authorization code");
  console.log("3. Paste the code below:\n");

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question("Enter authorization code: ", async (code) => {
    rl.close();

    try {
      const { tokens } = await oauth2Client.getToken(code.trim());
      fs.writeFileSync(CREDENTIALS_PATH, JSON.stringify(tokens, null, 2));
      console.log(`\nCredentials saved to: ${CREDENTIALS_PATH}`);
      console.log("You can now use the upload tool!");
    } catch (err) {
      console.error("\nError getting tokens:", err.message);
      process.exit(1);
    }
  });
}

main().catch(console.error);
