/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { dtmfLine } from './server/line.ts';

// Gom JS và CSS vào MỘT tệp HTML: mở offline trên điện thoại được, và phát
// hành thành Artifact được (Artifact chỉ nhận script nội tuyến).
// Chế độ 'artifact' ẩn nút Tải WAV vì trình xem Artifact chặn mọi lượt tải.
// dtmfLine: cầu nối đường dây sang MATLAB, chỉ sống trong npm run dev / preview.
export default defineConfig({
  plugins: [react(), viteSingleFile(), dtmfLine()],
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
});
