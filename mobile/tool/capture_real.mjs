// Chụp ảnh THẬT từ app SmartFarm Mobile (Flutter web) đang chạy với backend thật, theo từng bước, có khoanh số bước.
//   1) backend: localhost:5144 (đã nạp seed-demo.sql); build: flutter build web --release --dart-define=API_BASE_URL=http://localhost:5144
//   2) node mobile/tool/capture_real.mjs mobile/tool/flows.mjs   (mặc định ghi vào docs/huong-dan-nguoi-dung/real)
// Mỗi bước trong flow: { file, do: [...hành động], mark: ['chữ hiển thị', ...] }  (xem flows.mjs)
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(here, '..', 'build', 'web');
const outDir = process.env.OUT_DIR ? path.resolve(process.env.OUT_DIR) : path.resolve(here, '..', '..', 'docs', 'huong-dan-nguoi-dung', 'real');
mkdirSync(outDir, { recursive: true });
const flowFile = path.resolve(process.argv[2] ?? path.join(here, 'flows.mjs'));
const only = process.argv[3]; // tên luồng cần chạy (tuỳ chọn)
const { flows } = await import(pathToFileURL(flowFile).href);

const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css' };
const server = createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const f = path.join(webRoot, p);
  if (!existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': mime[path.extname(f)] ?? 'application/octet-stream' });
  res.end(readFileSync(f));
}).listen(5173);

const browserPath = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Google/Chrome/Application/chrome.exe'].find(existsSync);
const port = 9333 + Math.floor(Math.random() * 300);
const profile = path.join(tmpdir(), 'sf_real_' + Date.now());
const proc = spawn(browserPath, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--hide-scrollbars', '--no-first-run', '--disable-gpu', '--force-color-profile=srgb', 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let wsUrl;
for (let i = 0; i < 60 && !wsUrl; i++) {
  try { wsUrl = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page')?.webSocketDebuggerUrl; } catch {}
  if (!wsUrl) await sleep(500);
}
const ws = new WebSocket(wsUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pend = new Map();
const net = new Map();
ws.onmessage = (m) => { const d = JSON.parse(m.data);
  if (d.method === 'Network.requestWillBeSent') net.set(d.params.requestId, { url: d.params.request.url, t0: d.params.timestamp, m: d.params.request.method });
  if (d.method === 'Network.loadingFinished' && net.get(d.params.requestId)) { const r = net.get(d.params.requestId); r.ms = Math.round((d.params.timestamp - r.t0) * 1000); r.bytes = d.params.encodedDataLength; }
 if (d.id && pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); } };
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pend.set(i, (d) => (d.error ? rej(new Error(method + ': ' + d.error.message)) : res(d.result))); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async (expr) => (await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result.value;

await send('Page.enable');
await send('Network.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 430, height: 932, deviceScaleFactor: 3, mobile: false });

// Tìm phần tử ngữ nghĩa (Flutter semantics) có nhãn chứa `text` (không phân biệt hoa thường), lấy khung theo px CSS.
const FIND = (text, nth = 0) => `(() => {
  const t = ${JSON.stringify(text)}.toLowerCase();
  const els = [...document.querySelectorAll('flt-semantics')].filter(e => (e.getAttribute('aria-label') || e.innerText || '').toLowerCase().includes(t) && e.getBoundingClientRect().width > 0);
  els.sort((a, b) => { const A = a.getBoundingClientRect(), B = b.getBoundingClientRect(); return A.width * A.height - B.width * B.height; });
  const e = els[${nth}]; if (!e) return null; const r = e.getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height };
})()`;
const rectOf = async (text, nth = 0) => { for (let i = 0; i < 20; i++) { const r = await ev(FIND(text, nth)); if (r) return r; await sleep(400); } throw new Error('Không thấy phần tử: ' + text); };
const click = async (x, y) => { for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 }); };
const clickText = async (text, nth = 0) => { const r = await rectOf(text, nth); await click(r.x + r.w / 2, r.y + r.h / 2); await sleep(900); };
const K = 430 / 1188; // toạ độ viết theo ảnh xem 1188px
const labels = async () => ev(`[...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label')||'').replace(/\\n/g,' | ')).filter(Boolean).slice(0,80)`);

async function overlay(boxes) {
  await ev(`(() => { document.getElementById('__ov')?.remove(); const o = document.createElement('div'); o.id='__ov'; o.style.cssText='position:fixed;inset:0;z-index:99999;pointer-events:none'; ${JSON.stringify(boxes)}.forEach((b,i)=>{ const d=document.createElement('div'); d.style.cssText='position:absolute;border:3px solid #eb1e1e;border-radius:12px;left:'+(b.x-3)+'px;top:'+(b.y-3)+'px;width:'+(b.w+6)+'px;height:'+(b.h+6)+'px'; const n=document.createElement('div'); n.textContent=String(i+1); n.style.cssText='position:absolute;left:-12px;top:-14px;width:26px;height:26px;border-radius:50%;background:#eb1e1e;color:#fff;font:700 15px Segoe UI,Arial;display:flex;align-items:center;justify-content:center'; d.appendChild(n); o.appendChild(d); }); document.body.appendChild(o); })()`);
}
const clearOverlay = () => ev(`document.getElementById('__ov')?.remove()`);

async function shot(file, marks = []) {
  const boxes = [];
  for (const m of marks) boxes.push(typeof m === 'string' ? await rectOf(m) : (Array.isArray(m) && m.length === 4) ? { x: m[0] * K, y: m[1] * K, w: m[2] * K, h: m[3] * K } : Array.isArray(m) ? await rectOf(m[0], m[1]) : m);
  await sleep(600);
  await overlay(boxes);
  const r = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(path.join(outDir, file), Buffer.from(r.data, 'base64'));
  await clearOverlay();
  console.log('  ảnh:', file, boxes.length ? `(${boxes.length} khung)` : '');
}

async function act(a) {
  if (a.click) await clickText(a.click, a.nth ?? 0);
  else if (a.v) { await click(a.v[0] * K, a.v[1] * K); if (a.text) { await sleep(400); await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'a', code: 'KeyA', modifiers: 2, commands: ['selectAll'] }); await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'a', code: 'KeyA', modifiers: 2 }); await send('Input.insertText', { text: a.text }); } await sleep(a.text ? 300 : 1200); }
  else if (a.at) { await click(a.at[0], a.at[1]); await sleep(900); }
  else if (a.type) { await clickText(a.into); await send('Input.insertText', { text: a.type }); await sleep(300); }
  else if (a.back) { await ev('history.back()'); await sleep(1500); }
  else if (a.reload) { await openApp(); }
  else if (a.wait) await sleep(a.wait);
  else if (a.dump) console.log('  nhãn:', JSON.stringify(await labels()));
  else if (a.scroll) { await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 215, y: 500, deltaX: 0, deltaY: a.scroll }); await sleep(800); }
  else if (a.fn) await a.fn({ ev, send, sleep, clickText, rectOf, click });
}

async function openApp() {
  await send('Page.navigate', { url: 'http://localhost:5173/' });
  await sleep(6000);
  await ev(`document.querySelector('flt-semantics-placeholder')?.click()`);
  await sleep(1500);
}

try {
  let loggedIn = false;
  for (const flow of flows) {
    if (only && flow.name !== only) continue;
    console.log('Luồng', flow.name);
    if (!flow.keepSession) await ev(`localStorage.clear(); sessionStorage.clear()`);
    await openApp();
    for (const s of flow.steps) {
      for (const a of s.do ?? []) await act(a);
      if (s.file) await shot(s.file, s.mark ?? []);
    }
  }
} catch (e) {
  console.error('LỖI:', e.message);
  console.error('Nhãn hiện có:', JSON.stringify(await labels().catch(() => [])));
  const r = await send('Page.captureScreenshot', { format: 'png' }).catch(() => null);
  if (r) writeFileSync(path.join(outDir, '_error.png'), Buffer.from(r.data, 'base64'));
  process.exitCode = 1;
} finally {
  if (process.env.NETLOG) { const rows = [...net.values()].filter((r) => r.url.includes(':5144')); console.log('Số lời gọi API:', rows.length); const by = {}; for (const r of rows) { const k = r.m + ' ' + r.url.replace('http://localhost:5144', '').replace(/[0-9a-f]{8}-[0-9a-f-]{27}/g, '{id}').split('?')[0]; (by[k] ??= []).push(r.ms ?? -1); } for (const [k, v] of Object.entries(by).sort((a, b) => b[1].length - a[1].length)) console.log(String(v.length).padStart(3), 'x', k, '  ms:', v.join(',')); }
  try { proc.kill(); } catch {}
  server.close();
  process.exit(process.exitCode ?? 0);
}
