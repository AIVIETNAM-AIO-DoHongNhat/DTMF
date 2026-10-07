/// <reference types="node" />
// Cầu nối đường dây: chạy bên trong máy chủ Vite (npm run dev, npm run preview).
//
// Trình duyệt không mở được cổng TCP, còn MATLAB gốc không có máy chủ TCP
// (tcpserver thuộc Instrument Control Toolbox) mà chỉ có tcpclient. Nên cầu nối
// đứng giữa: nhận WebSocket của trang ở LINE_PATH, mở cổng MATLAB_PORT trên
// 127.0.0.1 cho tcpclient của MATLAB, rồi chép tin hai chiều. Cầu nối KHÔNG xử
// lý âm thanh, chỉ đổi khung nhị phân thành base64 để MATLAB đọc từng dòng JSON.
// Giao thức: src/line/protocol.ts.

import net from 'node:net';
import type { IncomingMessage, Server } from 'node:http';
import type { Duplex } from 'node:stream';
import type { Plugin, PreviewServer, ViteDevServer } from 'vite';
import { WebSocket, WebSocketServer, type RawData } from 'ws';
import { LINE_PATH, MATLAB_PORT, PHONE_TYPES, type LineStatus } from '../src/line/protocol.ts';

/** Lời ghi nhật ký cho từng tin chữ của điện thoại. */
const LOI: Record<(typeof PHONE_TYPES)[number], string> = {
  call: 'gọi',
  hangup: 'gác máy',
  case: 'bắt đầu đoạn ghi âm',
  end: 'hết đoạn ghi âm',
  reveal: 'công bố đáp án',
};

type Log = (msg: string) => void;

/** Plugin Vite gắn cầu nối vào máy chủ dev và máy chủ preview. */
export function dtmfLine(port = MATLAB_PORT): Plugin {
  const gan = (server: ViteDevServer | PreviewServer) => {
    const httpServer = server.httpServer as Server | null;
    // Vitest dựng máy chủ Vite ở chế độ middleware, không có httpServer.
    if (!httpServer || process.env.VITEST) return;
    const cau = new Bridge(httpServer, port, (m) => server.config.logger.info(m, { timestamp: true }));
    httpServer.on('close', () => cau.close());

    // Điện thoại hỏi trạng thái trước khi gọi mà không phải mở WebSocket - mở
    // WebSocket là chiếm dây. Nhờ vậy MATLAB đang chạy màn giám định thì cuộc
    // gọi đi trong trang, không cắt vụ đang nghe (App.tsx, probeLine).
    server.middlewares.use(`${LINE_PATH}/status`, (_req, res) => {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Cache-Control', 'no-store');
      res.end(JSON.stringify(cau.status()));
    });
  };
  return {
    name: 'dtmf-line',
    configureServer: gan,
    configurePreviewServer: gan,
  };
}

class Bridge {
  private wss = new WebSocketServer({ noServer: true });
  private tcp: net.Server;
  private matlab: net.Socket | null = null;
  private method: string | undefined;
  private app: string | undefined;
  private phone: WebSocket | null = null;
  private ping: ReturnType<typeof setInterval>;
  private closed = false;

  constructor(
    http: Server,
    port: number,
    private log: Log,
  ) {
    // Chỉ nhận đúng LINE_PATH; các lời nâng cấp khác (HMR của Vite) để nguyên.
    http.on('upgrade', (req: IncomingMessage, sock: Duplex, head: Buffer) => {
      if (new URL(req.url ?? '/', 'http://x').pathname !== LINE_PATH) return;
      this.wss.handleUpgrade(req, sock, head, (ws) => this.onPhone(ws));
    });

    // Vite khởi động lại khi cấu hình đổi: cầu nối cũ có thể còn giữ cổng
    // thêm một nhịp, nên cổng bận thì thử lại trong khoảng 5 s.
    this.tcp = net.createServer((s) => this.onMatlab(s));
    let thu = 0;
    const nghe = () => this.tcp.listen(port, '127.0.0.1');
    this.tcp.on('listening', () => log(`[đường dây] chờ MATLAB ở 127.0.0.1:${port}, điện thoại ở ${LINE_PATH}`));
    this.tcp.on('error', (e: NodeJS.ErrnoException) => {
      if (e.code === 'EADDRINUSE' && !this.closed && ++thu <= 20) {
        setTimeout(() => !this.closed && nghe(), 250);
        return;
      }
      log(`[đường dây] không mở được cổng ${port} cho MATLAB: ${e.message}`);
    });
    nghe();

    this.ping = setInterval(() => this.toMatlab({ t: 'ping' }), 1000);
  }

  close(): void {
    this.closed = true;
    clearInterval(this.ping);
    this.matlab?.destroy();
    this.phone?.close();
    this.tcp.close();
    this.wss.close();
  }

  status(): LineStatus {
    return {
      t: 'line',
      matlab: this.matlab !== null,
      ...(this.method ? { method: this.method } : {}),
      ...(this.app ? { app: this.app } : {}),
    };
  }

  /* ------------------------------------------------------------- MATLAB */

  private onMatlab(s: net.Socket): void {
    // MATLAB mới thay MATLAB cũ: mở lại DTMFLive không phải đợi hết hạn.
    this.matlab?.destroy();
    this.matlab = s;
    this.method = undefined;
    this.app = undefined;
    s.setNoDelay(true);
    s.setEncoding('utf8');
    this.log('[đường dây] MATLAB đã nối');
    this.toPhone(this.status());

    let du = '';
    s.on('data', (chunk: string) => {
      du += chunk;
      let i: number;
      while ((i = du.indexOf('\n')) >= 0) {
        const dong = du.slice(0, i).trim();
        du = du.slice(i + 1);
        if (dong) this.fromMatlab(dong);
      }
    });
    const mat = () => {
      if (this.matlab !== s) return;
      this.matlab = null;
      this.method = undefined;
      this.app = undefined;
      this.log('[đường dây] MATLAB đã ngắt');
      this.toPhone(this.status());
    };
    s.on('close', mat);
    s.on('error', mat);
  }

  private fromMatlab(dong: string): void {
    let m: { t?: unknown; method?: unknown; app?: unknown };
    try {
      m = JSON.parse(dong);
    } catch {
      return;
    }
    if (m.t === 'hello') {
      this.method = typeof m.method === 'string' ? m.method : undefined;
      this.app = typeof m.app === 'string' ? m.app : undefined;
      this.toPhone(this.status());
      return;
    }
    // answer, key, hangup, verdict: chuyển nguyên văn sang điện thoại.
    this.phone?.readyState === WebSocket.OPEN && this.phone.send(dong);
  }

  private toMatlab(m: object): void {
    if (this.matlab && !this.matlab.destroyed) this.matlab.write(`${JSON.stringify(m)}\n`);
  }

  /* ---------------------------------------------------------- điện thoại */

  private onPhone(ws: WebSocket): void {
    // Một đường dây, một cuộc gọi: máy mới (vd. tải lại trang) thay máy cũ.
    if (this.phone) {
      this.toMatlab({ t: 'hangup' });
      this.phone.close(4000, 'replaced');
    }
    this.phone = ws;
    ws.send(JSON.stringify(this.status()));

    ws.on('message', (data: RawData, isBinary: boolean) => {
      if (this.phone !== ws) return;
      if (isBinary) {
        const b = Array.isArray(data) ? Buffer.concat(data) : Buffer.from(data as ArrayBuffer);
        this.toMatlab({ t: 'pcm', d: b.toString('base64') });
        return;
      }
      try {
        const m = JSON.parse(data.toString()) as { t?: unknown };
        const t = PHONE_TYPES.find((k) => k === m.t);
        if (t) {
          this.log(`[đường dây] điện thoại: ${LOI[t]}`);
          // case, reveal mang số liệu: chuyển nguyên đối tượng, không chỉ t.
          this.toMatlab(m);
        }
      } catch {
        // khung chữ hỏng: bỏ qua
      }
    });
    ws.on('close', () => {
      if (this.phone !== ws) return;
      this.phone = null;
      this.toMatlab({ t: 'hangup' });
    });
  }

  private toPhone(m: object): void {
    if (this.phone?.readyState === WebSocket.OPEN) this.phone.send(JSON.stringify(m));
  }
}
