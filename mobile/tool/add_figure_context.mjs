// Chèn khối "Ngữ cảnh hình" dưới từng ảnh của docs/huong-dan-nguoi-dung/HUONG_DAN_SU_DUNG_MOBILE.md và sinh bảng "Danh mục hình" cho báo cáo.
//   node mobile/tool/add_figure_context.mjs
// Dữ liệu: mobile/tool/figure_context.json. Chạy lại nhiều lần không bị trùng (các khối được đánh dấu bằng comment).
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const mdPath = path.resolve(here, '..', '..', 'docs', 'huong-dan-nguoi-dung', 'HUONG_DAN_SU_DUNG_MOBILE.md');
const figs = JSON.parse(readFileSync(path.join(here, 'figure_context.json'), 'utf8'));

let md = readFileSync(mdPath, 'utf8');
// Gỡ các khối cũ để chạy lại không trùng
md = md.replace(/\n?<!-- ctx:start [^>]*-->[\s\S]*?<!-- ctx:end -->\n?/g, '');
md = md.replace(/\n*---\n+<!-- catalog:start -->[\s\S]*<!-- catalog:end -->\n*/g, '\n');

// Thứ tự hình theo thứ tự ảnh xuất hiện trong tài liệu
const order = [...md.matchAll(/!\[[^\]]*\]\(img\/([A-Za-z0-9_]+\.png)\)/g)].map((m) => m[1]);
const num = new Map(order.map((f, i) => [f, i + 1]));
const missing = figs.filter((f) => !num.has(f.file)).map((f) => f.file);
if (missing.length) throw new Error('Ảnh không có trong tài liệu: ' + missing.join(', '));
const noCtx = order.filter((f) => !figs.some((x) => x.file === f));
if (noCtx.length) throw new Error('Thiếu ngữ cảnh cho: ' + noCtx.join(', '));

for (const f of figs) {
  const n = num.get(f.file);
  const imgLine = new RegExp('(!\\[[^\\]]*\\]\\(img/' + f.file.replace('.', '\\.') + '\\)\\n)');
  const block =
    `\n<!-- ctx:start ${f.file} -->\n` +
    `> **Hình ${n}. ${f.title}**  \n` +
    `> **Luồng:** ${f.flow} · **Loại:** ${f.type} · **Vai trò:** ${f.role}  \n` +
    `> **Đường vào:** ${f.entry}  \n` +
    `> **Điều kiện / dữ liệu:** ${f.precondition}  \n` +
    `> **Kết quả mong đợi:** ${f.result}  \n` +
    `> **Các khung đỏ:** ${f.marks}\n` +
    `<!-- ctx:end -->\n`;
  if (!imgLine.test(md)) throw new Error('Không tìm thấy dòng ảnh: ' + f.file);
  md = md.replace(imgLine, '$1' + block);
}

// Bảng danh mục hình (đặt trước mục "Ghi chú về ảnh")
const rows = order.map((file) => {
  const f = figs.find((x) => x.file === file);
  const n = num.get(file);
  return `| Hình ${n} | \`${file}\` | ${f.flow} | ${f.type} | ${f.role} | ${f.caption} |`;
});
const catalog =
  `\n<!-- catalog:start -->\n## Phụ lục: Danh mục hình (dùng cho báo cáo)\n\n` +
  `Mỗi hình dùng chú thích ở cột cuối làm caption trong báo cáo; ngữ cảnh đầy đủ (đường vào, điều kiện, kết quả) nằm trong khối trích dẫn dưới từng hình ở các mục trên.\n\n` +
  `| Hình | Tệp ảnh | Luồng | Loại | Vai trò | Chú thích (caption) |\n|---|---|---|---|---|---|\n` +
  rows.join('\n') +
  `\n<!-- catalog:end -->\n`;
md = md.trimEnd() + '\n\n---\n' + catalog;

writeFileSync(mdPath, md);
console.log(`Đã chèn ngữ cảnh cho ${figs.length} hình và bảng danh mục.`);
