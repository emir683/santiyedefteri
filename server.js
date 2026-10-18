const express = require('express');
const multer = require('multer');
const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const compression = require('compression');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(compression({ threshold: 1024 }));

const UPLOAD_DIR = path.join(__dirname, 'uploads');
const PUBLIC_DIR = path.join(__dirname, 'public');

// V1 Motoru (Mevcut, dokunulmaz SVG+DXF hattı)
const PYTHON_SCRIPT_PATH = fs.existsSync(path.join(__dirname, 'generate_full_cad_webgl.py'))
  ? path.join(__dirname, 'generate_full_cad_webgl.py')
  : '/home/ubuntu/cad-service/generate_full_cad_webgl.py';

// V2 Motoru (Yeni, DXF-Öncelikli saf CAD hattı)
const PYTHON_SCRIPT_PATH_V2 = fs.existsSync(path.join(__dirname, 'generate_full_cad_webgl_v2.py'))
  ? path.join(__dirname, 'generate_full_cad_webgl_v2.py')
  : '/home/ubuntu/cad-service/generate_full_cad_webgl_v2.py';

if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(PUBLIC_DIR)) fs.mkdirSync(PUBLIC_DIR, { recursive: true });

// Korunan hazır örnek proje ID'leri (Temizlik sırasında asla silinmez)
const PROTECTED_FILE_IDS = new Set([
  'bc00f9c7-d593-49d7-9f4e-ceefb57f27b8',
  '5d6e89b2-bdac-4ff9-8e7c-c129c1fc68e2',
  'a6003203-6143-414a-bc21-5929f5e8c61e',
  '87b6f0bc-dc50-4fbc-959b-e1302122afd0'
]);

function cleanupOldUploads(maxAgeMs = 7 * 24 * 60 * 60 * 1000) {
  try {
    const now = Date.now();
    const files = fs.readdirSync(UPLOAD_DIR);
    for (const file of files) {
      const isProtected = Array.from(PROTECTED_FILE_IDS).some(id => file.startsWith(id));
      if (isProtected) continue;
      const fullPath = path.join(UPLOAD_DIR, file);
      const stat = fs.statSync(fullPath);
      if (now - stat.mtimeMs > maxAgeMs) {
        fs.unlinkSync(fullPath);
      }
    }
  } catch (err) {
    console.warn('[CLEANUP NOTE]', err.message);
  }
}
setInterval(() => cleanupOldUploads(), 6 * 60 * 60 * 1000);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase() || '.dwg';
    cb(null, uuidv4() + ext);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 250 * 1024 * 1024 }
});

// ----------------- V1 İŞ KUYRUĞU (MEVCUT DOKUNULMAZ MOTOR) -----------------
const activeCadJobs = new Map();

function getOrCreateCadData(fileId, svgPath, jsonTarget) {
  if (activeCadJobs.has(fileId)) {
    return activeCadJobs.get(fileId);
  }
  const job = new Promise((resolve, reject) => {
    console.log(`[CAD ENGINE V1] Yüksek hızlı vektör çizim paketi üretiliyor: ${fileId}...`);
    execFile(
      'python3',
      [PYTHON_SCRIPT_PATH, svgPath, jsonTarget],
      { maxBuffer: 64 * 1024 * 1024, timeout: 180000 },
      (err) => {
        activeCadJobs.delete(fileId);
        if (err) {
          console.error(`[CAD ENGINE V1 ERROR] ${fileId}:`, err);
          return reject(err);
        }
        console.log(`[CAD ENGINE V1 SUCCESS] ${fileId}`);
        resolve();
      }
    );
  });
  activeCadJobs.set(fileId, job);
  return job;
}

// ----------------- V2 İŞ KUYRUĞU (YENİ DXF-ÖNCELİKLİ HAT) -----------------
const activeCadJobsV2 = new Map();

async function triggerFcmPushNotification({ fcmToken, projectName, webglUrl, fileId }) {
  if (!fcmToken) return;
  try {
    const cloudFunctionUrl = 'https://europe-west1-santiye-yonetim-app.cloudfunctions.net/notifyCadReady';
    console.log(`[FCM PUSH TRIGGER] Bildirim iletiliyor: ${fileId} (${projectName}) -> ${fcmToken.substring(0, 15)}...`);
    const res = await fetch(cloudFunctionUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fcmToken,
        projectName,
        webglUrl,
        fileId,
      }),
    });
    if (res.ok) {
      console.log(`[FCM PUSH TRIGGER SUCCESS] ${fileId} için uzaktan push bildirimi başarıyla iletildi!`);
    } else {
      const errText = await res.text();
      console.warn(`[FCM PUSH TRIGGER WARNING] HTTP ${res.status}: ${errText}`);
    }
  } catch (err) {
    console.warn(`[FCM PUSH TRIGGER ERROR] ${err.message}`);
  }
}

function startV2Conversion(fileId, inputPath, dxfPath, svgPath, jsonTarget, pdfPath, meta = {}) {
  if (activeCadJobsV2.has(fileId)) {
    return activeCadJobsV2.get(fileId);
  }

  const job = (async () => {
    console.log(`[CAD ENGINE V2 START] ${fileId} dönüşümü başlatıldı...`);
    const isDwg = inputPath.toLowerCase().endsWith('.dwg');
    if (isDwg) {
      if (!fs.existsSync(dxfPath) || fs.statSync(dxfPath).size < 100) {
        console.log(`[CAD ENGINE V2] dwg2dxf çalıştırılıyor: ${fileId}...`);
        await runDwgToDxf(inputPath, dxfPath);
      }
    } else if (inputPath.toLowerCase().endsWith('.dxf')) {
      if (inputPath !== dxfPath && !fs.existsSync(dxfPath)) {
        fs.copyFileSync(inputPath, dxfPath);
      }
    }

    console.log(`[CAD ENGINE V2] Python V2 DXF-Öncelikli Binary üretiliyor: ${fileId}...`);
    await new Promise((resolve, reject) => {
      execFile(
        'python3',
        [PYTHON_SCRIPT_PATH_V2, svgPath, jsonTarget],
        { maxBuffer: 128 * 1024 * 1024, timeout: 600000 },
        (err) => {
          if (err) {
            console.error(`[CAD ENGINE V2 ERROR] ${fileId}:`, err);
            return reject(err);
          }
          console.log(`[CAD ENGINE V2 SUCCESS] ${fileId} başarıyla tamamlandı!`);
          resolve();
        }
      );
    });

    // Kullanıcı uygulamayı tamamen kapatmış olsa bile uzaktan FCM push bildirimi gönder
    if (meta && meta.fcmToken) {
      triggerFcmPushNotification({
        fcmToken: meta.fcmToken,
        projectName: meta.projName,
        webglUrl: meta.webglUrl,
        fileId: fileId,
      });
    }

    // Arka planda SVG ve PDF fallback üretimi
    if (isDwg) {
      runDwgToSvg(inputPath, svgPath).then(() => {
        smartFixSvg(svgPath);
        if (fs.existsSync(svgPath) && fs.statSync(svgPath).size > 50) {
          execFile('rsvg-convert', ['-f', 'pdf', '-o', pdfPath, svgPath], () => {});
        }
      }).catch(() => {});
    }
  })();

  activeCadJobsV2.set(fileId, job);
  job.finally(() => {
    activeCadJobsV2.delete(fileId);
  });
  return job;
}

app.get('/api/cad-status/:fileId', (req, res) => {
  const { fileId } = req.params;
  if (!/^[a-zA-Z0-9_\-]+$/.test(fileId)) {
    return res.status(400).json({ error: 'Geçersiz dosya kimliği' });
  }
  const binGz = path.join(UPLOAD_DIR, `${fileId}_cad_vertices.bin.gz`);
  const bin = path.join(UPLOAD_DIR, `${fileId}_cad_vertices.bin`);
  const metaGz = path.join(UPLOAD_DIR, `${fileId}_cad_meta.json.gz`);
  const meta = path.join(UPLOAD_DIR, `${fileId}_cad_meta.json`);
  const jsonGz = path.join(UPLOAD_DIR, `${fileId}_cad_data.json.gz`);
  const json = path.join(UPLOAD_DIR, `${fileId}_cad_data.json`);

  const ready = (fs.existsSync(binGz) || fs.existsSync(bin)) && (fs.existsSync(metaGz) || fs.existsSync(meta));
  const converting = activeCadJobs.has(fileId) || activeCadJobsV2.has(fileId);

  res.json({
    fileId,
    ready,
    converting
  });
});

app.get('/files/:filename', (req, res, next) => {
  const filename = path.basename(req.params.filename);
  const filePath = path.join(UPLOAD_DIR, filename);
  const gzPath = filePath + '.gz';
  const acceptsGz = req.headers['accept-encoding'] && req.headers['accept-encoding'].includes('gzip');

  const serveFile = () => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    if (acceptsGz && fs.existsSync(gzPath)) {
      if (filename.endsWith('.json')) res.setHeader('Content-Type', 'application/json; charset=utf-8');
      else if (filename.endsWith('.bin')) res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Content-Encoding', 'gzip');
      return res.sendFile(gzPath);
    }
    if (fs.existsSync(filePath)) {
      return res.sendFile(filePath);
    }
    return next();
  };

  if (!fs.existsSync(filePath) && !fs.existsSync(gzPath)) {
    const m = filename.match(/^([a-f0-9\-]+)_cad_(?:data_)?(data\.json|vertices\.bin|triangles\.bin|meta\.json)$/);
    if (m) {
      const fileId = m[1];
      if (activeCadJobsV2.has(fileId)) {
        return res.status(202).json({ converting: true, message: 'CAD projesi çözümleniyor...' });
      }
      const dxfPath = path.join(UPLOAD_DIR, `${fileId}.dxf`);
      const dwgPath = path.join(UPLOAD_DIR, `${fileId}.dwg`);
      const inputSrc = fs.existsSync(dwgPath) ? dwgPath : (fs.existsSync(dxfPath) ? dxfPath : null);
      if (inputSrc) {
        const svgPath = path.join(UPLOAD_DIR, `${fileId}.svg`);
        const jsonTarget = path.join(UPLOAD_DIR, `${fileId}_cad_data.json`);
        const pdfPath = path.join(UPLOAD_DIR, `${fileId}.pdf`);
        startV2Conversion(fileId, inputSrc, dxfPath, svgPath, jsonTarget, pdfPath)
          .catch((err) => console.error(`[ON-DEMAND V2 ERROR] ${fileId}:`, err));
        return res.status(202).json({ converting: true, message: 'Dönüştürme başlatıldı...' });
      }
      const svgPath = path.join(UPLOAD_DIR, `${fileId}.svg`);
      if (fs.existsSync(svgPath)) {
        const jsonTarget = path.join(UPLOAD_DIR, `${fileId}_cad_data.json`);
        getOrCreateCadData(fileId, svgPath, jsonTarget)
          .then(() => serveFile())
          .catch(() => next());
        return;
      }
    }
  }

  if (fs.existsSync(filePath) || fs.existsSync(gzPath)) {
    return serveFile();
  }

  next();
});

app.use('/files', express.static(UPLOAD_DIR, {
  maxAge: 0,
  setHeaders: (res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  }
}));
app.use(express.static(PUBLIC_DIR, {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    }
  }
}));

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    engine: 'Dual Engine: V1 (SVG+DXF) & V2 (Direct DXF-First Zero-Copy)',
    port: PORT
  });
});

function smartFixSvg(filePath) {
  try {
    if (!fs.existsSync(filePath)) return;
    let content = fs.readFileSync(filePath, 'utf8');

    const svgStart = content.indexOf('<svg');
    if (svgStart === -1) return;
    if (svgStart > 0) {
      content = content.substring(svgStart);
    }

    let origBaseX = null;
    let origBaseY = null;
    const origVb = content.match(/viewBox="([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)"/);
    if (origVb && !content.includes('data-dwg-base-x=')) {
      const ox = parseFloat(origVb[1]);
      const oy = parseFloat(origVb[2]);
      const ow = parseFloat(origVb[3]);
      const oh = parseFloat(origVb[4]);
      if (isFinite(ox) && isFinite(oy) && isFinite(ow) && isFinite(oh)) {
        origBaseX = -ox;
        origBaseY = oy + oh;
        content = content.replace('<svg', `<svg data-dwg-base-x="${origBaseX.toFixed(2)}" data-dwg-base-y="${origBaseY.toFixed(2)}"`);
      }
    }

    const defsStart = content.indexOf('<defs>');
    if (defsStart !== -1) {
      let defsPart = content.substring(defsStart);
      const modelSpacePart = content.substring(0, defsStart);

      const msSymbols = new Set();
      const msUseRegex = /<use[^>]+(?:xlink:href|href)="#(symbol-[^"]+)"/g;
      let uMatch;
      while ((uMatch = msUseRegex.exec(modelSpacePart)) !== null) {
        msSymbols.add(uMatch[1]);
      }

      const symMinX = [];
      const symMaxY = [];
      const symMatches = defsPart.split('<g id="symbol-');

      for (let i = 1; i < symMatches.length; i++) {
        const endIdx = symMatches[i].indexOf('</g>');
        if (endIdx === -1) continue;
        const chunk = symMatches[i].substring(0, endIdx);
        const pts = [];
        const ptRegex = /([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)/g;
        let pMatch;
        let count = 0;
        while ((pMatch = ptRegex.exec(chunk)) !== null && count < 30) {
          pts.push([parseFloat(pMatch[1]), parseFloat(pMatch[2])]);
          count++;
        }
        if (pts.length > 4) {
          const xs = pts.map(p => p[0]);
          const ys = pts.map(p => p[1]);
          symMinX.push(parseFloat(Math.min(...xs).toFixed(0)));
          symMaxY.push(parseFloat(Math.max(...ys).toFixed(0)));
        }
      }

      function mostFrequent(arr) {
        if (!arr.length) return null;
        const counts = {};
        let maxCount = 0, best = null;
        for (const v of arr) {
          counts[v] = (counts[v] || 0) + 1;
          if (counts[v] > maxCount) {
            maxCount = counts[v];
            best = v;
          }
        }
        return best;
      }

      const baseX = origBaseX !== null ? origBaseX : mostFrequent(symMinX);
      const baseY = origBaseY !== null ? origBaseY : mostFrequent(symMaxY);

      if (baseX !== null && baseY !== null) {
        console.log(`[ORIGIN SHIFT] Block origin offset: (${baseX}, ${baseY}), msSymbols count: ${msSymbols.size}`);
        const symSplits = defsPart.split('</g>');
        const updatedChunks = [];
        for (let chunk of symSplits) {
          const idMatch = chunk.match(/<g\s+id="(symbol-[^"]+)"([^>]*)>/);
          if (idMatch && msSymbols.has(idMatch[1])) {
            const symId = idMatch[1];
            const tag = idMatch[0];
            if (!tag.includes('transform=')) {
              chunk = chunk.replace(tag, `<g id="${symId}" transform="translate(${-baseX}, ${-baseY})"${idMatch[2]}>`);
            }
          }
          updatedChunks.push(chunk);
        }
        defsPart = updatedChunks.join('</g>');
        content = content.substring(0, defsStart) + defsPart;
      }
    }

    const currentDefsStart = content.indexOf('<defs>');
    const modelSpaceContent = currentDefsStart !== -1 ? content.substring(0, currentDefsStart) : content;

    const coordRegex = /([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)/g;
    const transRegex = /translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)/g;
    const textCoordRegex = /<text[^>]+x="([+-]?\d+\.?\d*)"\s+y="([+-]?\d+\.?\d*)"/g;

    let match;
    const xsAll = [];
    const ysAll = [];

    const scanCoords = (regex) => {
      while ((match = regex.exec(modelSpaceContent)) !== null) {
        const x = parseFloat(match[1]);
        const y = parseFloat(match[2]);
        if (!isNaN(x) && !isNaN(y) && Math.abs(x) < 1e7 && Math.abs(y) < 1e7) {
          xsAll.push(x);
          ysAll.push(y);
        }
      }
    };

    scanCoords(coordRegex);
    scanCoords(transRegex);
    scanCoords(textCoordRegex);

    if (xsAll.length > 2) {
      xsAll.sort((a, b) => a - b);
      ysAll.sort((a, b) => a - b);
      const q01X = xsAll[Math.floor(xsAll.length * 0.05)];
      const q99X = xsAll[Math.floor(xsAll.length * 0.95)];
      const q01Y = ysAll[Math.floor(ysAll.length * 0.05)];
      const q99Y = ysAll[Math.floor(ysAll.length * 0.95)];
      const spanX = Math.max(q99X - q01X, 2000);
      const spanY = Math.max(q99Y - q01Y, 2000);
      const limMinX = q01X - Math.max(spanX * 1.5, 100000);
      const limMaxX = q99X + Math.max(spanX * 1.5, 100000);
      const limMinY = q01Y - Math.max(spanY * 2.0, 80000);
      const limMaxY = q99Y + Math.max(spanY * 2.0, 80000);

      const filtX = xsAll.filter(v => v >= limMinX && v <= limMaxX);
      const filtY = ysAll.filter(v => v >= limMinY && v <= limMaxY);
      const minX = filtX.length ? filtX[0] : xsAll[0];
      const maxX = filtX.length ? filtX[filtX.length - 1] : xsAll[xsAll.length - 1];
      const minY = filtY.length ? filtY[0] : ysAll[0];
      const maxY = filtY.length ? filtY[filtY.length - 1] : ysAll[ysAll.length - 1];

      const w = Math.max(10, maxX - minX);
      const h = Math.max(10, maxY - minY);
      const padX = Math.max(w * 0.02, 10);
      const padY = Math.max(h * 0.05, 10);
      const realMinX = (minX - padX).toFixed(2);
      const realMinY = (minY - padY).toFixed(2);
      const realW = (w + padX * 2).toFixed(2);
      const realH = (h + padY * 2).toFixed(2);

      const newViewBox = `viewBox="${realMinX} ${realMinY} ${realW} ${realH}"`;
      content = content.replace(/viewBox="[^"]+"/, newViewBox);

      const targetW = 24000;
      const targetH = Math.max(Math.round(24000 * (h / (w || 1))), 800);
      content = content.replace(/width="[^"]*"/, `width="${targetW}"`);
      content = content.replace(/height="[^"]*"/, `height="${targetH}"`);

      const bgRect = `<rect x="${realMinX}" y="${realMinY}" width="${realW}" height="${realH}" fill="#000000" />\n\t`;
      content = content.replace(/(<svg[^>]*>)/, `$1\n\t${bgRect}`);
    }

    content = content.replace(/%%[cC]/g, 'Ø');
    content = content.replace(/%%[dD]/g, '°');
    content = content.replace(/%%[pP]/g, '±');
    content = content.replace(/\\P/g, ' ');
    content = content.replace(/\\A[0-2];/g, '');
    content = content.replace(/\\H[0-9.]+x?;/g, '');
    content = content.replace(/\\W[0-9.]+;/g, '');
    content = content.replace(/\\Q[0-9.]+;/g, '');
    content = content.replace(/\\T[0-9.]+;/g, '');
    content = content.replace(/\\[fF][^;]+;/g, '');
    content = content.replace(/\\S([^;^]+)\^([^;]*);/g, '$1/$2');
    content = content.replace(/\\[uU]\+([0-9a-fA-F]{4})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));

    content = content.replace(/fill="black"/g, 'fill="#FFFFFF"');
    content = content.replace(/fill='black'/g, 'fill="#FFFFFF"');
    content = content.replace(/stroke:black/g, 'stroke:#FFFFFF');
    content = content.replace(/stroke-width:0\.1px/g, 'stroke-width:1.5px');
    content = content.replace(/font-family="Courier"/g, 'font-family="Arial, Helvetica, sans-serif"');

    fs.writeFileSync(filePath, content, 'utf8');
  } catch (err) {
    console.error('smartFixSvg error:', err);
  }
}

function runDwgToDxf(inputPath, dxfPath) {
  return new Promise((resolve) => {
    execFile('dwg2dxf', ['-y', inputPath, '-o', dxfPath], { timeout: 300000 }, () => resolve());
  });
}

function runDwgToSvg(inputPath, svgPath) {
  return new Promise((resolve) => {
    const outStream = fs.createWriteStream(svgPath);
    const child = execFile('dwg2SVG', ['-v0', '--mspace', inputPath], { maxBuffer: 128 * 1024 * 1024, timeout: 180000 });
    if (child.stdout) child.stdout.pipe(outStream);
    child.on('close', () => {
      outStream.end();
      resolve();
    });
    child.on('error', () => {
      outStream.end();
      resolve();
    });
  });
}

// ----------------- V1 UÇ NOKTASI (MEVCUT DOKUNULMAZ HAT) -----------------
app.post('/api/convert', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Dosya yüklenmedi' });
  }

  const inputPath = req.file.path;
  const fileId = path.parse(req.file.filename).name;
  const projName = req.file.originalname || 'CAD Projesi';

  const svgFilename = `${fileId}.svg`;
  const svgPath = path.join(UPLOAD_DIR, svgFilename);

  const pdfFilename = `${fileId}.pdf`;
  const pdfPath = path.join(UPLOAD_DIR, pdfFilename);

  const isDwg = inputPath.toLowerCase().endsWith('.dwg');
  const dxfFilename = `${fileId}.dxf`;
  const dxfPath = path.join(UPLOAD_DIR, dxfFilename);

  try {
    if (isDwg) {
      await Promise.all([
        runDwgToDxf(inputPath, dxfPath),
        runDwgToSvg(inputPath, svgPath)
      ]);
      smartFixSvg(svgPath);
    } else if (inputPath.toLowerCase().endsWith('.dxf')) {
      if (inputPath !== dxfPath && !fs.existsSync(dxfPath)) {
        fs.copyFileSync(inputPath, dxfPath);
      }
    }

    const relativePdfUrl = `/files/${pdfFilename}`;
    const relativeWebglUrl = `/webgl-cad.html?id=${fileId}&title=${encodeURIComponent(projName)}`;

    const jsonFilename = `${fileId}_cad_data.json`;
    const jsonPath = path.join(UPLOAD_DIR, jsonFilename);
    getOrCreateCadData(fileId, svgPath, jsonPath)
      .then(() => console.log(`[WEBGL V1 SUCCESS] CAD JSON ve BINARY hazırlandı: ${jsonFilename}`))
      .catch((cadErr) => console.error('[WEBGL V1 ERROR]', cadErr));

    if (fs.existsSync(svgPath) && fs.statSync(svgPath).size > 50) {
      execFile('rsvg-convert', ['-f', 'pdf', '-o', pdfPath, svgPath], (pdfErr) => {
        if (!pdfErr && fs.existsSync(pdfPath)) {
          const pdfSize = fs.statSync(pdfPath).size;
          console.log(`[CONVERT SUCCESS] PDF üretildi (Arka Plan): ${pdfFilename} (${pdfSize} bytes)`);
        }
      });
    }

    return res.json({
      success: true,
      id: fileId,
      originalName: projName,
      pdfUrl: relativePdfUrl,
      svgUrl: `/files/${svgFilename}`,
      webglUrl: relativeWebglUrl,
      dwgUrl: `/files/${fileId}${path.extname(inputPath)}`
    });
  } catch (err) {
    console.error('[CONVERT ERROR V1]', err);
    return res.status(500).json({ error: 'Dönüştürme sırasında hata oluştu' });
  }
});

// ----------------- V2 UÇ NOKTASI (YENİ DXF-ÖNCELİKLİ HAT) -----------------
app.post('/api/convert-v2', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Dosya yüklenmedi' });
  }

  const inputPath = req.file.path;
  const fileId = path.parse(req.file.filename).name;
  const projName = req.body.project_name || req.file.originalname || 'CAD Projesi';
  const fcmToken = req.body.fcm_token || null;

  const svgFilename = `${fileId}.svg`;
  const svgPath = path.join(UPLOAD_DIR, svgFilename);

  const pdfFilename = `${fileId}.pdf`;
  const pdfPath = path.join(UPLOAD_DIR, pdfFilename);

  const dxfFilename = `${fileId}.dxf`;
  const dxfPath = path.join(UPLOAD_DIR, dxfFilename);
  const jsonFilename = `${fileId}_cad_data.json`;
  const jsonPath = path.join(UPLOAD_DIR, jsonFilename);

  try {
    const relativePdfUrl = `/files/${pdfFilename}`;
    // V2 HATTI İÇİN webgl-cad-v2.html KULLANILIR!
    const relativeWebglUrl = `/webgl-cad-v2.html?id=${fileId}&title=${encodeURIComponent(projName)}`;

    // V2 Motorunu arka planda hemen başlat (Asenkron - non-blocking)
    startV2Conversion(fileId, inputPath, dxfPath, svgPath, jsonPath, pdfPath, {
      fcmToken,
      projName,
      webglUrl: relativeWebglUrl,
    }).catch((err) => console.error(`[ASYNC V2 BACKGROUND ERROR] ${fileId}:`, err));

    return res.json({
      success: true,
      id: fileId,
      version: 'v2',
      originalName: projName,
      pdfUrl: relativePdfUrl,
      svgUrl: `/files/${svgFilename}`,
      webglUrl: relativeWebglUrl,
      dwgUrl: `/files/${fileId}${path.extname(inputPath)}`
    });
  } catch (err) {
    console.error('[CONVERT ERROR V2]', err);
    return res.status(500).json({ error: 'Dönüştürme (V2) sırasında hata oluştu: ' + (err.message || err) });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`CAD Vector Server running on port ${PORT} (Dual Engine: V1 + V2)`);
});
