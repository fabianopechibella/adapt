// Servidor local usado só para validar a própria suíte (npm run test:selftest).
// As páginas em fixtures/ têm defeitos propositais para provar que os testes os detectam.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'fixtures');
const port = Number(process.env.PORT || 4173);
http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const file = path.join(root, url.pathname === '/' ? 'index.html' : url.pathname.replace(/\/$/, '') + (path.extname(url.pathname) ? '' : '.html'));
  if (!file.startsWith(root) || !fs.existsSync(file)) {
    res.writeHead(404, { 'content-type': 'text/html; charset=utf-8' });
    return res.end('<!doctype html><html lang="pt-BR"><title>404</title><h1>Página não encontrada</h1></html>');
  }
  res.writeHead(200, { 'content-type': file.endsWith('.html') ? 'text/html; charset=utf-8' : 'text/plain', 'x-content-type-options': 'nosniff' });
  fs.createReadStream(file).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`fixture em http://127.0.0.1:${port}`));
