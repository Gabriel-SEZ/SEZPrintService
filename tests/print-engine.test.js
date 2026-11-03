'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const engine = require('../print-engine');

test('normaliza somente A4 e 80mm', () => {
  assert.equal(engine.normalizeFormat('80 mm'), '80mm');
  assert.equal(engine.normalizeFormat('cupom'), '80mm');
  assert.equal(engine.normalizeFormat('a4'), 'a4');
  assert.equal(engine.normalizeFormat('58mm'), 'a4');
});

test('restringe a URL base ao domínio Smart EZ por HTTPS', () => {
  assert.equal(engine.safeBaseUrl('https://smartez.com.br/erp/os.html'), 'https://smartez.com.br/erp/os.html');
  assert.equal(engine.safeBaseUrl('http://smartez.com.br/'), 'https://smartez.com.br/erp/');
  assert.equal(engine.safeBaseUrl('https://example.com/'), 'https://smartez.com.br/erp/');
});

test('prepara documento A4 sem remover o conteúdo visual', () => {
  const html = engine.prepareHtml('<!doctype html><html><head></head><body><h1>Ordem de Serviço</h1></body></html>', 'a4', 'https://smartez.com.br/erp/');
  assert.match(html, /Ordem de Serviço/);
  assert.match(html, /@page\{size:A4\}/);
  assert.match(html, /<base href="https:\/\/smartez\.com\.br\/erp\/">/);
});

test('prepara 80mm com altura dinâmica e largura térmica', () => {
  const html = engine.prepareHtml('<html><head></head><body><p>Recibo</p></body></html>', '80mm', 'https://smartez.com.br/erp/');
  assert.match(html, /size:80mm "\+mm\+"mm/);
  assert.match(html, /width:76mm!important/);
  assert.match(html, /Math\.min\(2500/);
});

test('remove scripts e atributos de evento do HTML recebido', () => {
  const html = engine.prepareHtml('<html><head></head><body onload="steal()"><script>steal()</script><img src="x" onerror="steal()"><a href="javascript:steal()">x</a></body></html>', 'a4');
  assert.doesNotMatch(html, /steal\(\)/);
  assert.doesNotMatch(html, /onload=/i);
  assert.doesNotMatch(html, /onerror=/i);
  assert.doesNotMatch(html, /href="javascript:/i);
  assert.match(html, /data-sez-print-ready/);
});

test('gera documento de teste sem depender do ERP', () => {
  assert.match(engine.testHtml('80mm'), /Teste 80MM/);
});
