#!/usr/bin/env node
/**
 * Google Drive Upload Tool
 *
 * Usage:
 *   node upload.js auth                    - Authenticate and save credentials
 *   node upload.js upload <file> [folder]  - Upload file to folder (or root)
 *   node upload.js list [folder]           - List files in folder
 *   node upload.js find <name>             - Find folder by name
 *
 * Environment variables:
 *   GDRIVE_CREDENTIALS_PATH - Path to saved credentials
 *   GDRIVE_OAUTH_PATH       - Path to OAuth client keys
 */

import { authenticate } from "@google-cloud/local-auth";
import { google } from "googleapis";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const SCOPES = [
  "https://www.googleapis.com/auth/drive.file",  // Create/edit files created by app
  "https://www.googleapis.com/auth/drive"        // Full access for listing/finding
];

const CREDENTIALS_PATH = process.env.GDRIVE_CREDENTIALS_PATH ||
  path.join(__dirname, "credentials.json");

const OAUTH_KEYS_PATH = process.env.GDRIVE_OAUTH_PATH ||
  path.join(__dirname, "oauth-keys.json");

const drive = google.drive("v3");

async function authenticateAndSave() {
  console.log("Starting OAuth authentication flow...");
  console.log(`OAuth keys path: ${OAUTH_KEYS_PATH}`);

  if (!fs.existsSync(OAUTH_KEYS_PATH)) {
    console.error(`\nERROR: OAuth keys not found at ${OAUTH_KEYS_PATH}`);
    console.error("\nTo create OAuth keys:");
    console.error("1. Go to https://console.cloud.google.com/apis/credentials");
    console.error("2. Create an OAuth 2.0 Client ID (Desktop application)");
    console.error("3. Download the JSON and save it as oauth-keys.json");
    process.exit(1);
  }

  const auth = await authenticate({
    keyfilePath: OAUTH_KEYS_PATH,
    scopes: SCOPES,
  });

  fs.writeFileSync(CREDENTIALS_PATH, JSON.stringify(auth.credentials, null, 2));
  console.log(`\nCredentials saved to: ${CREDENTIALS_PATH}`);
  console.log("You can now use the upload command.");
}

async function loadCredentials() {
  if (!fs.existsSync(CREDENTIALS_PATH)) {
    console.error("No credentials found. Run 'node upload.js auth' first.");
    process.exit(1);
  }

  const credentials = JSON.parse(fs.readFileSync(CREDENTIALS_PATH, "utf-8"));
  const auth = new google.auth.OAuth2();
  auth.setCredentials(credentials);
  google.options({ auth });

  return auth;
}

async function findFolder(name) {
  await loadCredentials();

  const res = await drive.files.list({
    q: `name='${name}' and mimeType='application/vnd.google-apps.folder' and trashed=false`,
    fields: "files(id, name, parents)",
    spaces: "drive",
  });

  if (res.data.files.length === 0) {
    console.log(`No folder found with name: ${name}`);
    return null;
  }

  console.log("Found folders:");
  res.data.files.forEach(f => {
    console.log(`  - ${f.name} (ID: ${f.id})`);
  });

  return res.data.files;
}

async function createFolder(name, parentId = null) {
  await loadCredentials();

  const fileMetadata = {
    name: name,
    mimeType: "application/vnd.google-apps.folder",
  };

  if (parentId) {
    fileMetadata.parents = [parentId];
  }

  // Check if folder already exists
  const existingQuery = parentId
    ? `name='${name}' and '${parentId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`
    : `name='${name}' and 'root' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`;

  const existing = await drive.files.list({
    q: existingQuery,
    fields: "files(id, name)",
  });

  if (existing.data.files.length > 0) {
    console.log(`Folder '${name}' already exists (ID: ${existing.data.files[0].id})`);
    return existing.data.files[0];
  }

  const res = await drive.files.create({
    requestBody: fileMetadata,
    fields: "id, name",
  });

  console.log(`Created folder: ${res.data.name} (ID: ${res.data.id})`);
  return res.data;
}

async function listFiles(folderId = "root") {
  await loadCredentials();

  const query = folderId === "root"
    ? "'root' in parents and trashed=false"
    : `'${folderId}' in parents and trashed=false`;

  const res = await drive.files.list({
    q: query,
    fields: "files(id, name, mimeType, modifiedTime)",
    orderBy: "name",
    pageSize: 50,
  });

  console.log(`\nFiles in ${folderId}:`);
  res.data.files.forEach(f => {
    const type = f.mimeType === "application/vnd.google-apps.folder" ? "[DIR]" : "[FILE]";
    console.log(`  ${type} ${f.name} (${f.id})`);
  });

  return res.data.files;
}

async function uploadFile(filePath, folderId = null) {
  await loadCredentials();

  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  const fileName = path.basename(filePath);
  const mimeType = getMimeType(fileName);

  console.log(`Uploading: ${fileName}`);
  console.log(`MIME type: ${mimeType}`);
  console.log(`Target folder: ${folderId || "root"}`);

  const fileMetadata = {
    name: fileName,
  };

  if (folderId) {
    fileMetadata.parents = [folderId];
  }

  const media = {
    mimeType: mimeType,
    body: fs.createReadStream(filePath),
  };

  // Check if file already exists in folder
  const existingQuery = folderId
    ? `name='${fileName}' and '${folderId}' in parents and trashed=false`
    : `name='${fileName}' and 'root' in parents and trashed=false`;

  const existing = await drive.files.list({
    q: existingQuery,
    fields: "files(id, name)",
  });

  if (existing.data.files.length > 0) {
    // Update existing file
    const existingId = existing.data.files[0].id;
    console.log(`Updating existing file (ID: ${existingId})...`);

    const res = await drive.files.update({
      fileId: existingId,
      media: media,
      fields: "id, name, webViewLink",
    });

    console.log(`\nFile updated successfully!`);
    console.log(`ID: ${res.data.id}`);
    console.log(`Link: ${res.data.webViewLink}`);
    return res.data;
  } else {
    // Create new file
    const res = await drive.files.create({
      requestBody: fileMetadata,
      media: media,
      fields: "id, name, webViewLink",
    });

    console.log(`\nFile uploaded successfully!`);
    console.log(`ID: ${res.data.id}`);
    console.log(`Link: ${res.data.webViewLink}`);
    return res.data;
  }
}

function getMimeType(filename) {
  const ext = path.extname(filename).toLowerCase();
  const mimeTypes = {
    ".json": "application/json",
    ".xml": "text/xml",
    ".txt": "text/plain",
    ".md": "text/markdown",
    ".html": "text/html",
    ".css": "text/css",
    ".js": "text/javascript",
    ".ts": "text/typescript",
    ".config": "text/xml",
  };
  return mimeTypes[ext] || "application/octet-stream";
}

async function main() {
  const [,, command, ...args] = process.argv;

  switch (command) {
    case "auth":
      await authenticateAndSave();
      break;

    case "upload":
      if (args.length === 0) {
        console.error("Usage: node upload.js upload <file> [folderId]");
        process.exit(1);
      }
      await uploadFile(args[0], args[1] || null);
      break;

    case "list":
      await listFiles(args[0] || "root");
      break;

    case "find":
      if (args.length === 0) {
        console.error("Usage: node upload.js find <folder-name>");
        process.exit(1);
      }
      await findFolder(args[0]);
      break;

    case "mkdir":
      if (args.length === 0) {
        console.error("Usage: node upload.js mkdir <folder-name> [parentId]");
        process.exit(1);
      }
      await createFolder(args[0], args[1] || null);
      break;

    default:
      console.log(`
Google Drive Upload Tool

Usage:
  node upload.js auth                    - Authenticate and save credentials
  node upload.js upload <file> [folder]  - Upload file to folder ID (or root)
  node upload.js list [folder]           - List files in folder ID
  node upload.js find <name>             - Find folder by name

Examples:
  node upload.js auth
  node upload.js find "Configuration"
  node upload.js upload ./appsettings.json 1KkJX7fQeh1-na12yspSFQQAo673VD-dq
      `);
  }
}

main().catch(err => {
  console.error("Error:", err.message);
  process.exit(1);
});
