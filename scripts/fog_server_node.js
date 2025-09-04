#!/usr/bin/env node
/**
 * Fog of War Tile Server (Node + Firebase Admin)
 *
 * - Uses serviceAccountKey.json for Firebase Admin auth
 * - Reads fogLevel from Firestore at visits_tiles/{userId}/visited/{tileId}
 * - Serves PNG tiles at /tiles/:userId/:z/:x/:y.png
 *
 * Start:
 *   node scripts/fog_server_node.js
 *
 * Example:
 *   http://localhost:8080/tiles/USER_ID/15/26910/12667.png
 */

const http = require('http');
const url = require('url');
const admin = require('firebase-admin');
const { PNG } = require('pngjs');

// ---- Init Firebase Admin ----
try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || 'ppamproto-439623',
  });
  console.log('✅ Firebase Admin 초기화 성공');
} catch (e) {
  console.error('❌ Firebase Admin 초기화 실패:', e.message);
  console.error('   scripts/serviceAccountKey.json 파일을 확인하세요.');
  process.exit(1);
}

const db = admin.firestore();

// ---- Helpers ----
function createFilledPng(width, height, r, g, b, a) {
  const png = new PNG({ width, height });
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (width * y + x) << 2;
      png.data[idx] = r;
      png.data[idx + 1] = g;
      png.data[idx + 2] = b;
      png.data[idx + 3] = a; // 0-255
    }
  }
  return PNG.sync.write(png);
}

const TILE_SIZE = 256;
const PNG_CACHE = {
  transparent: createFilledPng(TILE_SIZE, TILE_SIZE, 0, 0, 0, 0),
  gray: createFilledPng(TILE_SIZE, TILE_SIZE, 128, 128, 128, 80),
  black: createFilledPng(TILE_SIZE, TILE_SIZE, 0, 0, 0, 255),
};

async function getFogLevel(userId, z, x, y) {
  try {
    const tileId = `${z}_${x}_${y}`;
    const docRef = db
      .collection('visits_tiles')
      .doc(userId)
      .collection('visited')
      .doc(tileId);
    const doc = await docRef.get();
    if (doc.exists) {
      const data = doc.data() || {};
      const level = Number(data.fogLevel);
      if (level === 1 || level === 2) return level;
      return 3;
    }
    return 3;
  } catch (e) {
    console.error('❌ Firestore 조회 오류:', e.message);
    return 3;
  }
}

function getTileBufferByFogLevel(level) {
  if (level === 1) return PNG_CACHE.transparent; // clear
  if (level === 2) return PNG_CACHE.gray;        // gray
  return PNG_CACHE.black;                        // dark
}

// ---- HTTP Server ----
const server = http.createServer(async (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  const parsed = url.parse(req.url, true);
  const match = parsed.pathname.match(/^\/tiles\/([^/]+)\/(\d+)\/(\d+)\/(\d+)\.png$/);

  if (match) {
    const [, userId, zStr, xStr, yStr] = match;
    const z = parseInt(zStr, 10);
    const x = parseInt(xStr, 10);
    const y = parseInt(yStr, 10);
    console.log(`🎯 타일 요청: user=${userId}, z=${z}, x=${x}, y=${y}`);

    try {
      const fogLevel = await getFogLevel(userId, z, x, y);
      const buf = getTileBufferByFogLevel(fogLevel);
      res.writeHead(200, {
        'Content-Type': 'image/png',
        'Cache-Control': 'no-cache',
      });
      return res.end(buf);
    } catch (e) {
      console.error('❌ 타일 처리 오류:', e.message);
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      return res.end('Internal Server Error');
    }
  }

  if (parsed.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok', service: 'fog-tile-server-node' }));
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;
server.listen(PORT, () => {
  console.log(`✅ Node 타일 서버 실행 중: http://localhost:${PORT}`);
  console.log('📡 예시: /tiles/USER/15/26910/12667.png');
});


