// Đo thời gian từ lúc mở trang tới lúc app Flutter web vẽ khung đầu tiên + tổng dữ liệu tải. node bench_startup.mjs <url> [số lần]
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
const url = process.argv[2], runs = +(process.argv[3] ?? 3);
const exe = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].find(existsSync);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
for (let n = 0; n < runs; n++) {
  const port = 9700 + n + Math.floor(Math.random() * 200);
  const proc = spawn(exe, ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${path.join(tmpdir(), 'bench_' + Date.now() + n)}`, '--no-first-run', '--disable-gpu', 'about:blank'], { stdio: 'ignore' });
  let ws;
  for (let i = 0; i < 60 && !ws; i++) { try { ws = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page')?.webSocketDebuggerUrl; } catch {} if (!ws) await sleep(300); }
  const sock = new WebSocket(ws); await new Promise((r) => (sock.onopen = r));
  let id = 0; const pend = new Map(); let bytes = 0, reqs = 0;
  sock.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && pend.has(d.id)) { pend.get(d.id)(d.result); pend.delete(d.id); } if (d.method === 'Network.loadingFinished') { bytes += d.params.encodedDataLength; reqs++; } };
  const send = (method, params = {}) => new Promise((res) => { const i = ++id; pend.set(i, res); sock.send(JSON.stringify({ id: i, method, params })); });
  await send('Network.enable'); await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 430, height: 932, deviceScaleFactor: 1, mobile: false });
  const t0 = Date.now();
  await send('Page.navigate', { url });
  let ms = -1;
  for (let i = 0; i < 600; i++) { const r = await send('Runtime.evaluate', { expression: `!!document.querySelector('flt-semantics-placeholder') || !!document.querySelector('flt-glass-pane')` , returnByValue: true }); if (r.result?.value) { ms = Date.now() - t0; break; } await sleep(100); }
  await sleep(1500);
  results.push({ ms, mb: +(bytes / 1048576).toFixed(1), reqs });
  proc.kill(); await sleep(500);
}
console.log(url, JSON.stringify(results));
