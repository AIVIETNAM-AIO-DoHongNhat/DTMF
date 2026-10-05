/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

// Gom JS và CSS vào MỘT tệp HTML: mở offline trên điện thoại được, và phát
// hành thành Artifact được (Artifact chỉ nhận script nội tuyến).
// Chế độ 'artifact' ẩn nút Tải WAV vì trình xem Artifact chặn mọi lượt tải.
export default defineConfig({
  plugins: [react(), viteSingleFile()],
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
});
