// Đổi bản build một tệp (dist-artifact/index.html) thành trang Artifact.
//
// Artifact tự bọc trang trong <!doctype html><html><head>…<body>, nên tệp phát
// hành chỉ được chứa NỘI DUNG: <title>, <link> phông, <style>, thân trang và
// <script>. Script ở đây bóc phần vỏ đó ra, giữ nguyên mọi thứ bên trong.
// Script module nội tuyến tự chạy sau khi trang phân tích xong, nên đặt nó
// trước hay sau #root đều được.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const goc = join(dirname(fileURLToPath(import.meta.url)), '..');
const vao = join(goc, 'dist-artifact', 'index.html');
const ra = join(goc, 'dist-artifact', 'ban-phim-dtmf.html');

const html = readFileSync(vao, 'utf8');

const head = html.match(/<head[^>]*>([\s\S]*?)<\/head>/i)?.[1];
const body = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i)?.[1];
if (head === undefined || body === undefined) {
  throw new Error(`Không tìm thấy <head> hoặc <body> trong ${vao}`);
}

// Bỏ hai thẻ meta: vỏ của Artifact đã có charset và viewport.
const headGiu = head.replace(/<meta\b[^>]*>\s*/gi, '');

writeFileSync(ra, `${headGiu.trim()}\n${body.trim()}\n`, 'utf8');
console.log(`Đã ghi ${ra} (${(Buffer.byteLength(headGiu + body) / 1024).toFixed(0)} KB)`);
