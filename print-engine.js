'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { execFile } = require('child_process');
const { pathToFileURL } = require('url');

const appDir = __dirname;
const dataRoot = path.join(process.env.ProgramData || os.tmpdir(), 'SmartEZ', 'SEZ Print Service', 'jobs');
const MAX_HTML_BYTES = 10 * 1024 * 1024;
const JOB_TIMEOUT_MS = 120000;
let queue = Promise.resolve();

function normalizeFormat(value) {
  const v = String(value || '').toLowerCase().replace(/\s+/g, '');
  if (['80mm', '80', 'thermal', 'termica', 'cupom'].includes(v)) return '80mm';
  return 'a4';
}

function safeBaseUrl(value) {
  try {
    const u = new URL(String(value || 'https://smartez.com.br/erp/'));
    if (u.protocol !== 'https:' || !['smartez.com.br', 'www.smartez.com.br'].includes(u.hostname)) {
      return 'https://smartez.com.br/erp/';
    }
    return u.href;
  } catch (_) {
    return 'https://smartez.com.br/erp/';
  }
}

function prepareHtml(input, format, baseUrl) {
  if (typeof input !== 'string' || !input.trim()) throw new Error('O documento HTML está vazio.');
  if (Buffer.byteLength(input, 'utf8') > MAX_HTML_BYTES) throw new Error('O documento excede o limite de 10 MB.');

  let html = input
    .replace(/<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, '')
    .replace(/<iframe\b[^>]*>[\s\S]*?<\/iframe\s*>/gi, '')
    .replace(/<object\b[^>]*>[\s\S]*?<\/object\s*>/gi, '')
    .replace(/<embed\b[^>]*\/?>/gi, '')
    .replace(/<base\b[^>]*>/gi, '')
    .replace(/\s+on[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/(href|src)\s*=\s*(["'])\s*javascript:[\s\S]*?\2/gi, '$1="#"')
    .replace(/<meta\b[^>]*http-equiv\s*=\s*(["']?)refresh\1[^>]*>/gi, '')
    .replace(/<meta\b[^>]*http-equiv\s*=\s*(["']?)content-security-policy\1[^>]*>/gi, '');

  if (!/<html\b/i.test(html)) {
    const doctype = /<!doctype\s+html[^>]*>/i.exec(html)?.[0] || '<!doctype html>';
    html = html.replace(/<!doctype\s+html[^>]*>/i, '');
    html = doctype + '<html lang="pt-BR"><head><meta charset="utf-8"></head><body>' + html + '</body></html>';
  } else if (!/<head\b/i.test(html)) {
    html = html.replace(/<html\b[^>]*>/i, function (m) {
      return m + '<head><meta charset="utf-8"></head>';
    });
  }

  const base = '<base href="' + safeBaseUrl(baseUrl).replace(/&/g, '&amp;').replace(/"/g, '&quot;') + '">';
  html = html.replace(/<head\b[^>]*>/i, function (m) { return m + base; });

  const f = normalizeFormat(format);
  let paperScript;
  if (f === '80mm') {
    paperScript = '<script>(function(){function apply(){try{' +
      'var d=document.documentElement,b=document.body;' +
      'var px=Math.max(d.scrollHeight||0,d.offsetHeight||0,b?(b.scrollHeight||0):0,b?(b.offsetHeight||0):0,b?Math.ceil(b.getBoundingClientRect().height):0);' +
      'var mm=Math.max(70,Math.min(2500,Math.ceil(px*25.4/96)+8));' +
      'var s=document.createElement("style");' +
      's.textContent="@media print{@page{size:80mm "+mm+"mm;margin:2mm}html,body{width:76mm!important;max-width:76mm!important;min-width:0!important;overflow:visible!important}body{box-sizing:border-box!important}}*{-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important}";' +
      'document.head.appendChild(s);document.documentElement.setAttribute("data-sez-print-ready","1");' +
      '}catch(e){}}' +
      'if(document.readyState==="complete")setTimeout(apply,200);else window.addEventListener("load",function(){setTimeout(apply,250)},{once:true});' +
      '})();</script>';
  } else {
    paperScript = '<script>(function(){function apply(){try{' +
      'var css=Array.from(document.querySelectorAll("style")).map(function(s){return s.textContent||"";}).join("\\n");' +
      'if(!/@page(?:\\s+[\\w:-]+)?\\s*\\{[^}]*\\bsize\\s*:/i.test(css)){' +
      'var p=document.createElement("style");p.textContent="@media print{@page{size:A4}}";document.head.appendChild(p);}' +
      'var s=document.createElement("style");s.textContent="@media print{*{-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important}html,body{max-width:100%!important;overflow:visible!important}}";document.head.appendChild(s);' +
      'document.documentElement.setAttribute("data-sez-print-ready","1");' +
      '}catch(e){}}' +
      'if(document.readyState==="complete")setTimeout(apply,100);else window.addEventListener("load",function(){setTimeout(apply,100)},{once:true});' +
      '})();</script>';
  }

  html = html.replace(/<\/head\s*>/i, paperScript + '</head>');
  if (!/<!doctype\s+html/i.test(html)) html = '<!doctype html>' + html;
  return html;
}

function run(file, args, timeout) {
  return new Promise(function (resolve, reject) {
    execFile(file, args, {
      windowsHide: true,
      timeout: timeout || JOB_TIMEOUT_MS,
      maxBuffer: 8 * 1024 * 1024
    }, function (error, stdout, stderr) {
      if (error) {
        const code = typeof error.code === 'number' ? error.code : null;
        const messages = {
          2: 'Não foi possível abrir o PDF gerado.',
          3: 'O documento não permite impressão.',
          4: 'A impressora selecionada não foi encontrada.',
          5: 'O driver ou dispositivo de impressão apresentou falha.',
          6: 'A impressão foi bloqueada por uma política do Windows.'
        };
        const detail = messages[code] || String(stderr || stdout || error.message || 'Falha no processo externo').trim();
        return reject(new Error(detail));
      }
      resolve({
        stdout: String(stdout || '').trim(),
        stderr: String(stderr || '').trim()
      });
    });
  });
}

function findEdge() {
  if (process.env.SEZPS_EDGE_PATH && fs.existsSync(process.env.SEZPS_EDGE_PATH)) return process.env.SEZPS_EDGE_PATH;
  const roots = [
    process.env.ProgramFiles,
    process.env['ProgramFiles(x86)'],
    process.env.ProgramW6432,
    process.env.LOCALAPPDATA
  ].filter(Boolean);
  const files = [];
  roots.forEach(function (root) {
    files.push(path.join(root, 'Microsoft', 'Edge', 'Application', 'msedge.exe'));
    files.push(path.join(root, 'Google', 'Chrome', 'Application', 'chrome.exe'));
  });
  return files.find(function (file) { return fs.existsSync(file); }) || null;
}

function findSumatra() {
  if (process.env.SEZPS_SUMATRA_PATH && fs.existsSync(process.env.SEZPS_SUMATRA_PATH)) return process.env.SEZPS_SUMATRA_PATH;
  const files = [
    path.join(appDir, 'tools', 'SumatraPDF.exe'),
    path.join(appDir, 'SumatraPDF.exe')
  ];
  return files.find(function (file) { return fs.existsSync(file); }) || null;
}

async function verifyPrinter(name) {
  const escaped = String(name).replace(/'/g, "''");
  const script = "$p=Get-Printer -Name '" + escaped + "' -ErrorAction SilentlyContinue; if($p){'OK'}else{'MISSING'}";
  const output = await run(
    process.env.SEZPS_POWERSHELL || 'powershell.exe',
    ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
    20000
  );
  if (output.stdout !== 'OK') throw new Error('A impressora "' + name + '" não está instalada neste Windows.');
}

async function printHtmlNow(data) {
  const format = normalizeFormat(data.format);
  const printer = String(data.printer || '').trim();
  if (!printer) throw new Error('Selecione a impressora ' + format.toUpperCase() + ' nas configurações do ERP.');
  await verifyPrinter(printer);

  const edge = findEdge();
  if (!edge) throw new Error('Microsoft Edge ou Google Chrome não foi localizado neste Windows.');
  const sumatra = findSumatra();
  if (!sumatra) throw new Error('SumatraPDF não está instalado. Execute novamente o instalador SEZ Print Service.');

  fs.mkdirSync(dataRoot, { recursive: true });
  const jobId = crypto.randomUUID();
  const dir = path.join(dataRoot, jobId);
  fs.mkdirSync(dir, { recursive: true });
  const htmlFile = path.join(dir, 'document.html');
  const pdfFile = path.join(dir, 'document.pdf');
  const profile = path.join(dir, 'edge-profile');
  fs.mkdirSync(profile, { recursive: true });

  try {
    fs.writeFileSync(htmlFile, prepareHtml(data.html, format, data.baseUrl), 'utf8');
    const args = [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--disable-sync',
      '--disable-background-networking',
      '--allow-file-access-from-files',
      '--no-pdf-header-footer',
      '--run-all-compositor-stages-before-draw',
      '--virtual-time-budget=3500',
      '--user-data-dir=' + profile,
      '--print-to-pdf=' + pdfFile,
      pathToFileURL(htmlFile).href
    ];
    await run(edge, args, 90000);
    if (!fs.existsSync(pdfFile) || fs.statSync(pdfFile).size < 100) {
      throw new Error('O navegador não conseguiu gerar o PDF. Verifique o Edge/Chrome instalado.');
    }

    const settings = 'paper=auto,fit';
    await run(sumatra, ['-print-to', printer, '-print-settings', settings, '-silent', pdfFile], JOB_TIMEOUT_MS);

    return {
      ok: true,
      jobId: jobId,
      printer: printer,
      format: format,
      pdfBytes: fs.statSync(pdfFile).size,
      message: 'Documento enviado à fila de impressão do Windows.',
      note: 'A confirmação indica envio ao spooler, não confirma a saída física do papel.'
    };
  } finally {
    try { fs.rmSync(dir, { recursive: true, force: true, maxRetries: 3, retryDelay: 250 }); } catch (_) { }
  }
}

function printHtml(data) {
  const job = queue.then(function () { return printHtmlNow(data); });
  queue = job.catch(function () { });
  return job;
}

function testHtml(format) {
  const f = normalizeFormat(format);
  return '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Teste SEZ Print</title>' +
    '<style>body{font-family:Arial;text-align:center;padding:12px}h2{font-size:19px}</style></head>' +
    '<body><h2>SEZ PRINT SERVICE</h2><h3>Teste ' + f.toUpperCase() + '</h3>' +
    '<p>' + new Date().toLocaleString('pt-BR') + '</p><p>Impressão automática sem diálogo</p></body></html>';
}

module.exports = {
  normalizeFormat: normalizeFormat,
  safeBaseUrl: safeBaseUrl,
  prepareHtml: prepareHtml,
  printHtml: printHtml,
  testHtml: testHtml
};
