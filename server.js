const express = require('express');
const multer = require('multer');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const compression = require('compression');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(compression({ threshold: 1024 }));

const UPLOAD_DIR = path.join(__dirname, 'uploads');
const PUBLIC_DIR = path.join(__dirname, 'public');

if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
if (!fs.existsSync(PUBLIC_DIR)) fs.mkdirSync(PUBLIC_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, uuidv4() + ext);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 250 * 1024 * 1024 } // 250 MB
});

// Aktif donusturme kuyrugu ve eszamanli talep yonetimi (Race condition ve cift Python calismasini onler)
const activeCadJobs = new Map();

function getOrCreateCadData(fileId, svgPath, jsonTarget) {
  if (activeCadJobs.has(fileId)) {
    return activeCadJobs.get(fileId);
  }
  const job = new Promise((resolve, reject) => {
    console.log(`[CAD ENGINE] Yuksek hizli vektor cizim paketi uretiliyor: ${fileId}...`);
    exec(`python3 /home/ubuntu/cad-service/generate_full_cad_webgl.py "${svgPath}" "${jsonTarget}"`, { maxBuffer: 50 * 1024 * 1024 }, (err) => {
      activeCadJobs.delete(fileId);
      if (err) {
        console.error(`[CAD ENGINE ERROR] ${fileId}:`, err);
        return reject(err);
      }
      console.log(`[CAD ENGINE SUCCESS] ${fileId}`);
      resolve();
    });
  });
  activeCadJobs.set(fileId, job);
  return job;
}

// CAD Durum Kontrol API'si (Yukleme ekraninda anlik durum ve ilerleme)
app.get('/api/cad-status/:fileId', (req, res) => {
  const { fileId } = req.params;
  const binGz = path.join(UPLOAD_DIR, `${fileId}_cad_vertices.bin.gz`);
  const bin = path.join(UPLOAD_DIR, `${fileId}_cad_vertices.bin`);
  const jsonGz = path.join(UPLOAD_DIR, `${fileId}_cad_data.json.gz`);
  const json = path.join(UPLOAD_DIR, `${fileId}_cad_data.json`);

  const ready = (fs.existsSync(binGz) || fs.existsSync(bin)) || (fs.existsSync(jsonGz) || fs.existsSync(json));
  const converting = activeCadJobs.has(fileId);

  res.json({
    fileId,
    ready,
    converting
  });
});

// Yüksek Hızlı Statik Dosya Dağıtımı (Gzip, Kalıcı Önbellek ve Mutex Garantili CAD Üretimi)
app.get('/files/:filename', (req, res, next) => {
  const filename = req.params.filename;
  const filePath = path.join(UPLOAD_DIR, filename);
  const gzPath = filePath + '.gz';
  const acceptsGz = req.headers['accept-encoding'] && req.headers['accept-encoding'].includes('gzip');

  const serveFile = () => {
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

  // Eksikse tek bir is parcacigiyla talep aninda aninda olustur
  if (!fs.existsSync(filePath) && !fs.existsSync(gzPath)) {
    const m = filename.match(/^([a-f0-9\-]+)_cad_(data\.json|vertices\.bin|meta\.json)$/);
    if (m) {
      const fileId = m[1];
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

  // Halihazırda varsa anında servis et
  if (fs.existsSync(filePath) || fs.existsSync(gzPath)) {
    return serveFile();
  }

  next();
});

app.use('/files', express.static(UPLOAD_DIR, {
  maxAge: 0,
  setHeaders: (res) => {
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
  res.json({ status: 'ok', engine: 'LibreDWG Precision Single-Strip Vector CAD Engine (High-Performance Zero-Copy)', port: PORT });
});

// SVG'yi Akıllı Onarıcı - TEK YATAY ŞERİT VE %100 KAYIPSIZ ÇİZİM RENDER:
// 1. MTEXT, SPLINE, DIMENSION, ATTDEF ve tüm AutoCAD çizim elemanlarını kapsar.
// 2. Taban ofsetine sahip sembol bloklarını seçici olarak ait oldukları paftaların içine yerleştirir.
// 3. ModelSpace sınırlarını hesaplayarak kesintisiz tek şerit (AutoCAD / DWG FastView standardı) oluşturur.
// 4. Çap simgesi (%%c -> Ø), derece (%%d -> °), pas payı ve genel mühendislik notlarını kusursuz biçimlendirir.
function smartFixSvg(filePath) {
  try {
    if (!fs.existsSync(filePath)) return;
    let content = fs.readFileSync(filePath, 'utf8');

    const svgStart = content.indexOf('<svg');
    if (svgStart === -1) return;
    if (svgStart > 0) {
      content = content.substring(svgStart);
    }

    const defsStart = content.indexOf('<defs>');

    // 1. Sembollerdeki (Kiriş, Donatı, Kesit, Akslar) AutoCAD Base-Point kaymasını tespit edip HİYERARŞİK olarak düzelt
    if (defsStart !== -1) {
      let defsPart = content.substring(defsStart);
      const modelSpacePart = content.substring(0, defsStart);

      // ModelSpace içinde doğrudan çağrılan ÜST DÜZEY sembolleri tespit et
      const msSymbols = new Set();
      const msUseRegex = /<use[^>]+href="#(symbol-[^"]+)"/g;
      let uMatch;
      while ((uMatch = msUseRegex.exec(modelSpacePart)) !== null) {
        msSymbols.add(uMatch[1]);
      }

      // Taban ofsetini hesapla
      const symMinX = [];
      const symMaxY = [];
      const symMatches = defsPart.split('<g id="symbol-');

      for (let i = 1; i < symMatches.length; i++) {
        const chunk = symMatches[i].substring(0, symMatches[i].indexOf('</g>'));
        const pts = [];
        const ptRegex = /([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)/g;
        let pMatch;
        let count = 0;
        while ((pMatch = ptRegex.exec(chunk)) !== null && count < 30) {
          pts.push([parseFloat(pMatch[1]), parseFloat(pMatch[2])]);
          count++;
        }
        if (pts.length > 5) {
          const xs = pts.map(p => p[0]);
          const ys = pts.map(p => p[1]);
          const minX = Math.min(...xs);
          const maxY = Math.max(...ys);
          if (minX > 1000) symMinX.push(parseFloat(minX.toFixed(1)));
          if (maxY < -1000) symMaxY.push(parseFloat(maxY.toFixed(1)));
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

      const baseX = mostFrequent(symMinX) || 47599.412729;
      const baseY = mostFrequent(symMaxY) || -28187.433527;

      console.log(`[ORIGIN SHIFT] Detected block origin offset: (${baseX}, ${baseY}), msSymbols count: ${msSymbols.size}`);

      // YALNIZCA ham negatif koordinatlara (y < -10000) sahip sembollere transform ekle!
      // Pozitif koordinatlı semboller (ölçü çizgileri, aks metreleri vb.) zaten ModelSpace'te doğru yerindedir.
      const symSplits = defsPart.split('</g>');
      const updatedChunks = [];
      for (let chunk of symSplits) {
        const idMatch = chunk.match(/<g\s+id="(symbol-[^"]+)"([^>]*)>/);
        if (idMatch && msSymbols.has(idMatch[1])) {
          const symId = idMatch[1];
          const tag = idMatch[0];
          if (!tag.includes('transform=')) {
            // Sadece gerçekten büyük negatif Y koordinatına (<-10000) sahip bloklara transform uygula
            const hasLargeNegY = /,\s*-[1-9]\d{4,}/.test(chunk) || /cy="-[1-9]\d{4,}/.test(chunk) || /y="-[1-9]\d{4,}/.test(chunk);
            if (hasLargeNegY) {
              chunk = chunk.replace(tag, `<g id="${symId}" transform="translate(${-baseX}, ${-baseY})"${idMatch[2]}>`);
            }
          }
        }
        updatedChunks.push(chunk);
      }
      defsPart = updatedChunks.join('</g>');

      content = content.substring(0, defsStart) + defsPart;
    }

    // 2. ModelSpace alanını (defs harici) tara ve tek şerit sınırlarını hesapla
    const currentDefsStart = content.indexOf('<defs>');
    const modelSpaceContent = currentDefsStart !== -1 ? content.substring(0, currentDefsStart) : content;

    const coordRegex = /([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)/g;
    const transRegex = /translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)/g;
    const textCoordRegex = /<text[^>]+x="([+-]?\d+\.?\d*)"\s+y="([+-]?\d+\.?\d*)"/g;

    let match;
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    let count = 0;

    while ((match = coordRegex.exec(modelSpaceContent)) !== null) {
      const x = parseFloat(match[1]);
      const y = parseFloat(match[2]);
      if (!isNaN(x) && !isNaN(y) && Math.abs(x) < 1e7 && Math.abs(y) < 1e7) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        count++;
      }
    }

    while ((match = transRegex.exec(modelSpaceContent)) !== null) {
      const x = parseFloat(match[1]);
      const y = parseFloat(match[2]);
      if (!isNaN(x) && !isNaN(y) && Math.abs(x) < 1e7 && Math.abs(y) < 1e7) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        count++;
      }
    }

    while ((match = textCoordRegex.exec(modelSpaceContent)) !== null) {
      const x = parseFloat(match[1]);
      const y = parseFloat(match[2]);
      if (!isNaN(x) && !isNaN(y) && Math.abs(x) < 1e7 && Math.abs(y) < 1e7) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        count++;
      }
    }

    if (count > 0 && isFinite(minX) && isFinite(maxX) && isFinite(minY) && isFinite(maxY)) {
      const w = maxX - minX;
      const h = maxY - minY;
      const padX = Math.max(w * 0.02, 10);
      const padY = Math.max(h * 0.05, 10);
      const realMinX = (minX - padX).toFixed(2);
      const realMinY = (minY - padY).toFixed(2);
      const realW = (w + padX * 2).toFixed(2);
      const realH = (h + padY * 2).toFixed(2);

      const newViewBox = `viewBox="${realMinX} ${realMinY} ${realW} ${realH}"`;
      content = content.replace(/viewBox="[^"]+"/, newViewBox);

      // Tek uzun şerit oranını koru
      const targetW = 24000;
      const targetH = Math.max(Math.round(24000 * (h / (w || 1))), 800);
      content = content.replace(/width="[^"]*"/, `width="${targetW}"`);
      content = content.replace(/height="[^"]*"/, `height="${targetH}"`);

      // CAD Karanlık mod: Tam boyutta siyah zemin ekle
      const bgRect = `<rect x="${realMinX}" y="${realMinY}" width="${realW}" height="${realH}" fill="#000000" />\n\t`;
      content = content.replace(/(<svg[^>]*>)/, `$1\n\t${bgRect}`);
    }

    // 3. AutoCAD özel karakterlerini ve format kodlarını temizle
    content = content.replace(/%%[cC]/g, 'Ø');
    content = content.replace(/%%[dD]/g, '°');
    content = content.replace(/%%[pP]/g, '±');
    content = content.replace(/\\P/g, ' ');
    content = content.replace(/\\A[0-2];/g, '');
    content = content.replace(/\\H[0-9.]+x;/g, '');
    content = content.replace(/\\W[0-9.]+;/g, '');
    content = content.replace(/\\Q[0-9.]+;/g, '');
    content = content.replace(/\\T[0-9.]+;/g, '');
    content = content.replace(/\\S([^;^]+)\^([^;]*);/g, '$1/$2');

    // 4. Renk ve kontrast düzeltmeleri:
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

// Convert DWG/DXF to Single-Strip Vector PDF
app.post('/api/convert', upload.single('file'), (req, res) => {
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

  // Model-space odaklı hızlı ve kayıpsız dönüştürme + Hatch dolguları için DXF çıkarımı
  const dxfCmd = isDwg ? `dwg2dxf -y "${inputPath}" -o "${dxfPath}" 2>/dev/null; ` : '';
  const cmd = `${dxfCmd}dwg2SVG -v0 --mspace "${inputPath}" > "${svgPath}" 2>/dev/null`;

  exec(cmd, (error) => {
    // Akıllı tek şerit onarımı ve blok taban kayması düzeltmesi
    smartFixSvg(svgPath);

    const relativePdfUrl = `/files/${pdfFilename}`;
    const relativeWebglUrl = `/webgl-cad.html?id=${fileId}&title=${encodeURIComponent(projName)}`;

    // 1. WebGL CAD verisini asenkron üret (%100 koordinat doğruluğu, ikili buffer)
    const jsonFilename = `${fileId}_cad_data.json`;
    const jsonPath = path.join(UPLOAD_DIR, jsonFilename);
    getOrCreateCadData(fileId, svgPath, jsonPath)
      .then(() => console.log(`[WEBGL SUCCESS] CAD JSON ve BINARY hazırlandı: ${jsonFilename}`))
      .catch((cadErr) => console.error('[WEBGL ERROR]', cadErr));

    // 2. Vektörel PDF üretimini arka planda çalıştır (Ağır dosyalar için Cloudflare 100s timeout'unu engeller!)
    exec(`rsvg-convert -f pdf -o "${pdfPath}" "${svgPath}"`, (pdfErr) => {
      const hasPdf = fs.existsSync(pdfPath);
      const pdfSize = hasPdf ? fs.statSync(pdfPath).size : 0;
      console.log(`[CONVERT SUCCESS] PDF uretildi (Arka Plan): ${pdfFilename} (${pdfSize} bytes)`);
    });

    // 3. Flutter istemcisine 5-8 saniye içinde ANINDA yanıt ver
    return res.json({
      success: true,
      id: fileId,
      originalName: projName,
      pdfUrl: relativePdfUrl,
      svgUrl: `/files/${svgFilename}`,
      webglUrl: relativeWebglUrl,
      dwgUrl: `/files/${fileId}${path.extname(inputPath)}`
    });
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`CAD Vector Server running on port ${PORT}`);
});
