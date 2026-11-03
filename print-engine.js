'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { execFile } = require('child_process');
const { pathToFileURL } = require('url');
const appDir = __dirname;
const dataRoot = path.join(process.env.ProgramData || os.tmpdir(), 'SmartEZ', 'SEZ Print Service', 'jobs');
let queue = Promise.resolve();
function normalizeFormat(value) {
  const v = String(value || '').toLowerCase().replace(/\s+/g, '');
  if (['80mm', '80', 'thermal', 'termica', 'cupom'].includes(v)) return '80mm';
  if (['58mm', '58'].includes(v)) return '58mm';
  return 'a4';
}
function safeBaseUrl(value) {
  try {
    const u = new URL(String(value || 'https://smartez.com.br/'));
    if (!['https:', 'http:'].includes(u.protocol) || !['smartez.com.br', 'www.smartez.com.br', 'localhost', '127.0.0.1'].includes(u.hostname)) return 'https://smartez.com.br/';
    return u.href;
  } catch (_) { return 'https://smartez.com.br/'; }
}
function prepareHtml(input, format, baseUrl) {
  if (typeof input !== 'string' || !input.trim()) throw new Error('O documento HTML está vazio.');
  let html = input;
  html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, '')
    .replace(/<iframe\b[^>]*>[\s\S]*?<\/iframe\s*>/gi, '')
    .replace(/<object\b[^>]*>[\s\S]*?<\/object\s*>/gi, '')
    .replace(/<embed\b[^>]*\/?>/gi, '')
    .replace(/\s+on[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/(href|src)\s*=\s*(["'])\s*javascript:[\s\S]*?\2/gi, '$1="#"')
    .replace(/<meta\b[^>]*http-equiv\s*=\s*(["']?)refresh\1[^>]*>/gi, '');
  if (!/<html\b/i.test(html)) {
    const doctype = /<!doctype\s+html[^>]*>/i.exec(html)?.[0] || '<!doctype html>';
    html = html.replace(/<!doctype\s+html[^>]*>/i, '');
    html = doctype + '<html><head><meta charset="utf-8"></head><body>' + html + '</body></html>';
  } else if (!/<head\b/i.test(html)) {
    html = html.replace(/<html\b[^>]*>/i, function (m) { return m + '<head><meta charset="utf-8"></head>'; });
  }
  const base = '<base href="' + safeBaseUrl(baseUrl).replace(/&/g, '&amp;').replace(/"/g, '&quot;') + '">';
  html = html.replace(/<head\b[^>]*>/i, function (m) { return m + base; });
  const f = normalizeFormat(format);
  const paper = f === 'a4'
    ? '@page{size:A4 portrait;margin:8mm;}html,body{max-width:100%!important;}'
    : '@page{size:' + f + ' auto;margin:2mm;}html,body{width:' + f + '!important;max-width:' + f + '!important;min-width:0!important;}body{box-sizing:border-box!important;}';
  const style = '<style id="sez-print-service-paper">' + paper + '@media print{*{-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important;}html,body{overflow:visible!important;}}</style>';
  html = /<\/head\s*>/i.test(html)
    ? html.replace(/<\/head\s*>/i, style + '</head>')
    : html.replace(/<body\b/i, style + '<body');
  if (!/<!doctype\s+html/i.test(html)) html = '<!doctype html>' + html;
  return html;
}
function run(file, args, timeout) {
  return new Promise(function (resolve, reject) {
    execFile(file, args, { windowsHide: true, timeout: timeout || 90000, maxBuffer: 8 * 1024 * 1024 }, function (error, stdout, stderr) {
      if (error) return reject(new Error(String(stderr || stdout || error.message).trim()));
      resolve({ stdout: String(stdout || '').trim(), stderr: String(stderr || '').trim() });
    });
  });
}
function findEdge() {
  const roots = [process.env.ProgramFiles, process.env['ProgramFiles(x86)'], process.env.ProgramW6432].filter(Boolean);
  const files = roots.map(function (root) { return path.join(root, 'Microsoft', 'Edge', 'Application', 'msedge.exe'); });
  files.push(path.join(process.env.LOCALAPPDATA || '', 'Microsoft', 'Edge', 'Application', 'msedge.exe'));
  return files.find(function (file) { return file && fs.existsSync(file); });
}
async function verifyPrinter(name) {
  const escaped = String(name).replace(/'/g, "''");
  const script = "$p=Get-Printer -Name '" + escaped + "' -ErrorAction SilentlyContinue; if($p){'OK'}else{'MISSING'}";
  const output = await run('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script], 20000);
  if (output.stdout !== 'OK') throw new Error('A impressora "' + name + '" não está instalada neste Windows.');
}
async function printHtmlNow(data) {
  const format = normalizeFormat(data.format);
  const printer = String(data.printer || '').trim();
  if (!printer) throw new Error('Selecione a impressora ' + format.toUpperCase() + ' nas configurações do ERP.');
  await verifyPrinter(printer);
  const edge = findEdge();
  if (!edge) throw new Error('Microsoft Edge não foi localizado neste Windows.');
  const sumatra = path.join(appDir, 'tools', 'SumatraPDF.exe');
  if (!fs.existsSync(sumatra)) throw new Error('SumatraPDF não está instalado. Execute novamente o instalador SEZ Print Service.');
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
      '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
      '--disable-extensions', '--disable-sync', '--disable-background-networking',
      '--no-pdf-header-footer', '--run-all-compositor-stages-before-draw', '--virtual-time-budget=1500',
      '--user-data-dir=' + profile, '--print-to-pdf=' + pdfFile, pathToFileURL(htmlFile).href
    ];
    await run(edge, args, 90000);
    if (!fs.existsSync(pdfFile) || fs.statSync(pdfFile).size < 512) throw new Error('O Edge não conseguiu gerar o PDF do documento.');
    const settings = format === 'a4' ? 'paper=A4,fit' : 'paper=auto,noscale';
    await run(sumatra, ['-print-to', printer, '-print-settings', settings, '-silent', pdfFile], 90000);
    return { ok: true, jobId: jobId, printer: printer, format: format, message: 'Documento enviado à fila de impressão do Windows.' };
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
  return '<!doctype html><html><head><meta charset="utf-8"><title>Teste SEZ Print</title></head>' +
    '<body style="font-family:Arial;text-align:center;padding:12px"><h2>SEZ PRINT SERVICE</h2><h3>Teste ' + f.toUpperCase() + '</h3>' +
    '<p>' + new Date().toLocaleString('pt-BR') + '</p><p>Impressão automática sem diálogo</p></body></html>';
}
module.exports = { normalizeFormat, safeBaseUrl, prepareHtml, printHtml, testHtml };
