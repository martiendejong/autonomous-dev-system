#!/usr/bin/env node
/**
 * Create Social Media Integration Tracker spreadsheet in Google Drive
 *
 * Usage: node create-social-media-tracker.js
 *
 * Requires: npm install googleapis
 */

const { google } = require('googleapis');
const fs = require('fs');
const path = require('path');
const http = require('http');
const url = require('url');
const { exec } = require('child_process');

const OAUTH_PATH = 'C:\\scripts\\_machine\\gcp-oauth.keys.json';
const CREDS_PATH = 'C:\\scripts\\_machine\\gdrive-sheets-credentials.json';
const SCOPES = [
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/spreadsheets'
];

async function getAuthClient() {
  const oauthKeys = JSON.parse(fs.readFileSync(OAUTH_PATH, 'utf8'));
  const { client_id, client_secret, redirect_uris } = oauthKeys.installed;

  const oauth2Client = new google.auth.OAuth2(
    client_id,
    client_secret,
    'http://localhost:3000/callback'
  );

  // Check for existing credentials
  if (fs.existsSync(CREDS_PATH)) {
    const creds = JSON.parse(fs.readFileSync(CREDS_PATH, 'utf8'));
    oauth2Client.setCredentials(creds);

    // Check if token needs refresh
    if (creds.expiry_date && creds.expiry_date < Date.now()) {
      console.log('Refreshing access token...');
      const { credentials } = await oauth2Client.refreshAccessToken();
      fs.writeFileSync(CREDS_PATH, JSON.stringify(credentials, null, 2));
      oauth2Client.setCredentials(credentials);
    }
    return oauth2Client;
  }

  // Need to authenticate
  console.log('No credentials found. Starting OAuth flow...');
  const authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
  });

  console.log('Opening browser for authentication...');
  console.log('If browser does not open, visit:', authUrl);

  // Start local server to receive callback
  return new Promise((resolve, reject) => {
    const server = http.createServer(async (req, res) => {
      const parsedUrl = url.parse(req.url, true);
      if (parsedUrl.pathname === '/callback') {
        const code = parsedUrl.query.code;
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end('<h1>Authentication successful!</h1><p>You can close this window.</p>');
        server.close();

        try {
          const { tokens } = await oauth2Client.getToken(code);
          oauth2Client.setCredentials(tokens);
          fs.writeFileSync(CREDS_PATH, JSON.stringify(tokens, null, 2));
          console.log('Credentials saved to', CREDS_PATH);
          resolve(oauth2Client);
        } catch (err) {
          reject(err);
        }
      }
    });

    server.listen(3000, () => {
      console.log('Listening on http://localhost:3000 for OAuth callback...');
      // Open browser on Windows
      exec(`start "" "${authUrl}"`, (err) => {
        if (err) console.log('Could not open browser automatically. Please open the URL manually.');
      });
    });
  });
}

async function findOrCreateFolder(drive, parentFolderId, folderName) {
  // Search for existing folder
  const searchRes = await drive.files.list({
    q: `name='${folderName}' and '${parentFolderId}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false`,
    fields: 'files(id, name)',
  });

  if (searchRes.data.files.length > 0) {
    console.log(`Found existing folder: ${folderName}`);
    return searchRes.data.files[0].id;
  }

  // Create new folder
  const folderMetadata = {
    name: folderName,
    mimeType: 'application/vnd.google-apps.folder',
    parents: [parentFolderId],
  };
  const folder = await drive.files.create({
    resource: folderMetadata,
    fields: 'id',
  });
  console.log(`Created folder: ${folderName}`);
  return folder.data.id;
}

async function findBrand2BoostFolder(drive) {
  const res = await drive.files.list({
    q: "name='brand2boost' and mimeType='application/vnd.google-apps.folder' and trashed=false",
    fields: 'files(id, name)',
  });

  if (res.data.files.length === 0) {
    throw new Error('brand2boost folder not found in Google Drive');
  }
  return res.data.files[0].id;
}

async function createSpreadsheet(sheets, drive, folderId) {
  const spreadsheet = await sheets.spreadsheets.create({
    resource: {
      properties: {
        title: 'Social Media Integration Status',
      },
      sheets: [{
        properties: {
          title: 'Integration Status',
          gridProperties: {
            rowCount: 15,
            columnCount: 5,
          },
        },
      }],
    },
  });

  const spreadsheetId = spreadsheet.data.spreadsheetId;
  console.log('Created spreadsheet:', spreadsheetId);

  // Move to documentation folder
  await drive.files.update({
    fileId: spreadsheetId,
    addParents: folderId,
    fields: 'id, parents',
  });
  console.log('Moved spreadsheet to documentation folder');

  // Add data
  const values = [
    ['Social Network', 'Login Working', 'Import Working', 'Posting Working', 'Remarks'],
    ['Google', 'FALSE', 'FALSE', 'FALSE', ''],
    ['LinkedIn', 'FALSE', 'FALSE', 'FALSE', ''],
    ['Facebook', 'FALSE', 'FALSE', 'FALSE', 'New credentials from Frank'],
    ['Microsoft', 'FALSE', 'FALSE', 'FALSE', 'New platform added'],
    ['Twitter/X', 'FALSE', 'FALSE', 'FALSE', 'New credentials from Frank'],
    ['Pinterest', 'FALSE', 'FALSE', 'FALSE', 'New credentials from Frank'],
    ['Instagram', 'FALSE', 'FALSE', 'FALSE', 'New platform added'],
    ['Reddit', 'FALSE', 'FALSE', 'FALSE', 'No credentials yet'],
    ['Medium', 'FALSE', 'FALSE', 'FALSE', 'No credentials yet'],
    ['Snapchat', 'FALSE', 'FALSE', 'FALSE', 'New credentials from Frank'],
    ['Tumblr', 'FALSE', 'FALSE', 'FALSE', 'New credentials from Frank'],
    ['TikTok', 'FALSE', 'FALSE', 'FALSE', 'New credentials from Frank'],
  ];

  await sheets.spreadsheets.values.update({
    spreadsheetId,
    range: 'Integration Status!A1:E13',
    valueInputOption: 'USER_ENTERED',
    resource: { values },
  });
  console.log('Added data to spreadsheet');

  // Format header row and add checkboxes
  await sheets.spreadsheets.batchUpdate({
    spreadsheetId,
    resource: {
      requests: [
        // Bold header row
        {
          repeatCell: {
            range: { sheetId: 0, startRowIndex: 0, endRowIndex: 1 },
            cell: {
              userEnteredFormat: {
                textFormat: { bold: true },
                backgroundColor: { red: 0.9, green: 0.9, blue: 0.9 },
              },
            },
            fields: 'userEnteredFormat(textFormat,backgroundColor)',
          },
        },
        // Data validation (checkboxes) for columns B, C, D
        {
          setDataValidation: {
            range: { sheetId: 0, startRowIndex: 1, endRowIndex: 13, startColumnIndex: 1, endColumnIndex: 4 },
            rule: {
              condition: { type: 'BOOLEAN' },
              showCustomUi: true,
            },
          },
        },
        // Auto-resize columns
        {
          autoResizeDimensions: {
            dimensions: { sheetId: 0, dimension: 'COLUMNS', startIndex: 0, endIndex: 5 },
          },
        },
      ],
    },
  });
  console.log('Applied formatting');

  return spreadsheetId;
}

async function main() {
  try {
    const auth = await getAuthClient();
    const drive = google.drive({ version: 'v3', auth });
    const sheets = google.sheets({ version: 'v4', auth });

    console.log('\nSearching for brand2boost folder...');
    const brand2boostId = await findBrand2BoostFolder(drive);
    console.log('Found brand2boost folder:', brand2boostId);

    console.log('\nCreating documentation folder...');
    const docFolderId = await findOrCreateFolder(drive, brand2boostId, 'documentation');

    console.log('\nCreating spreadsheet...');
    const spreadsheetId = await createSpreadsheet(sheets, drive, docFolderId);

    console.log('\n✅ Success!');
    console.log('Spreadsheet URL: https://docs.google.com/spreadsheets/d/' + spreadsheetId);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
