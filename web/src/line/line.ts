// Đường dây từ điện thoại (trang này) tới tổng đài MATLAB.
//
// Trang trích đúng tín hiệu nó đang phát ra loa (DtmfPlayer.tap), hạ tần số lấy
// mẫu về LINE_FS = 8000 Hz, đổi sang int16 rồi gửi qua WebSocket tới cầu nối
// trong máy chủ Vite (server/line.ts), cầu nối chép sang MATLAB. Trang KHÔNG
// giải mã: phím mà tổng đài đọc lại là phím MATLAB nghe được rồi báo ngược về.

import type { DtmfPlayer } from '../audio/dtmf';
import {
  LINE_FS,
  LINE_PATH,
  parseToPhone,
  type LineStatus,
  type PhoneMsg,
  type SwitchMsg,
} from './protocol';

/**
 * Đổi tần số lấy mẫu bằng nội suy tuyến tính, giữ trạng thái qua các khối nên
 * nối nhiều khối liền nhau cho đúng như đổi một lần cả tín hiệu.
 *
 * Không lọc chống chồng phổ: mọi thứ trang phát (tone DTMF, hồi âm chuông
 * 425 Hz) nằm dưới 1.5 kHz, xa tần số Nyquist 4 kHz của đường dây. Sai số
 * nội suy tối đa (2πf/fs)²/8 biên độ: 0.47% với tone 1477 Hz lấy từ 48 kHz.
 */
export class Resampler {
  private readonly step: number;
  /** Vị trí của mẫu ra kế tiếp, tính theo chỉ số mẫu vào của khối sắp tới; -1 là mẫu cuối khối trước. */
  private pos = 0;
  private last = 0;

  constructor(fsIn: number, fsOut = LINE_FS) {
    this.step = fsIn / fsOut;
  }

  push(x: Float32Array): Float32Array {
    const n = x.length;
    if (n === 0) return new Float32Array(0);
    const out = new Float32Array(Math.ceil((n - this.pos) / this.step) + 1);
    let k = 0;
    let p = this.pos;
    while (p <= n - 1) {
      const i = Math.floor(p);
      const f = p - i;
      const a = i < 0 ? this.last : x[i];
      const b = i + 1 < n ? x[i + 1] : a;
      out[k++] = a + f * (b - a);
      p += this.step;
    }
    this.pos = p - n;
    this.last = x[n - 1];
    return out.subarray(0, k);
  }
}

/** [-1, 1] -> int16, cắt phần vượt biên. */
export function toInt16(x: Float32Array): Int16Array {
  const y = new Int16Array(x.length);
  for (let i = 0; i < x.length; i++) {
    const v = Math.max(-1, Math.min(1, x[i]));
    y[i] = Math.round(v * 32767);
  }
  return y;
}

/**
 * Địa chỉ WebSocket của đường dây, hoặc null khi trang không chạy trên máy chủ
 * Vite (mở tệp offline, bản Artifact) - khi đó không có cầu nối nào để gọi.
 */
export function lineUrl(loc: Pick<Location, 'protocol' | 'host'> = location): string | null {
  if (loc.protocol !== 'http:' && loc.protocol !== 'https:') return null;
  return `${loc.protocol === 'https:' ? 'wss' : 'ws'}://${loc.host}${LINE_PATH}`;
}

/** Hỏi cầu nối MATLAB có đang nối không, không mở cuộc gọi. null: không có cầu nối. */
export async function probeLine(signal?: AbortSignal): Promise<LineStatus | null> {
  if (!lineUrl()) return null;
  try {
    const r = await fetch(`${LINE_PATH}/status`, { cache: 'no-store', signal });
    if (!r.ok) return null;
    const m = parseToPhone(await r.text());
    return m?.t === 'line' ? m : null;
  } catch {
    return null;
  }
}

export interface LineHandlers {
  /** Tin của tổng đài: nhấc máy, phím đã đọc được, gác máy. */
  onMsg: (m: SwitchMsg) => void;
  /** Cầu nối báo MATLAB vừa nối hoặc vừa ngắt, sau lần báo đầu tiên. */
  onStatus: (s: LineStatus) => void;
  /** Đường dây đứt khi đang dùng: máy chủ Vite tắt, hoặc code = REPLACED khi trang khác chiếm dây. */
  onClose: (code?: number) => void;
}

/** Mã đóng WebSocket khi cầu nối nhường đường dây cho một trang mới - server/line.ts. */
export const REPLACED = 4000;

export class LineClient {
  private ws: WebSocket | null = null;
  private untap: (() => void) | null = null;

  /**
   * Mở đường dây. Trả về lần báo trạng thái đầu tiên của cầu nối, hoặc null
   * nếu trong `timeoutMs` không có cầu nối nào trả lời.
   */
  open(url: string, h: LineHandlers, timeoutMs = 1500): Promise<LineStatus | null> {
    this.close();
    return new Promise((resolve) => {
      let first = true;
      const done = (v: LineStatus | null) => {
        if (!first) return;
        first = false;
        clearTimeout(timer);
        resolve(v);
      };
      let ws: WebSocket;
      try {
        ws = new WebSocket(url);
      } catch {
        resolve(null);
        return;
      }
      ws.binaryType = 'arraybuffer';
      this.ws = ws;

      // Chỉ đóng đúng WebSocket của lần mở này, không đóng nhầm lần mở sau.
      const timer = setTimeout(() => {
        done(null);
        if (this.ws === ws) this.close();
      }, timeoutMs);

      ws.onmessage = (e) => {
        if (typeof e.data !== 'string') return;
        const m = parseToPhone(e.data);
        if (!m) return;
        if (m.t === 'line') {
          if (first) done(m);
          else h.onStatus(m);
          return;
        }
        h.onMsg(m);
      };
      ws.onerror = () => done(null);
      ws.onclose = (e) => {
        const dangDung = this.ws === ws;
        if (dangDung) {
          this.stopAudio();
          this.ws = null;
        }
        if (first) done(null);
        else if (dangDung) h.onClose(e.code);
      };
    });
  }

  send(m: PhoneMsg): void {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(m));
  }

  /** Gửi một đoạn mẫu đã ở LINE_FS (đoạn ghi âm của màn giám định), không qua loa. */
  sendPcm(x: Float32Array): void {
    if (this.ws?.readyState === WebSocket.OPEN && x.length > 0) this.ws.send(toInt16(x).buffer);
  }

  /** Đường dây đang mở. */
  get isOpen(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  /** Bắt đầu gửi tiếng của trang lên đường dây: cả tone lẫn khoảng lặng. */
  async startAudio(player: DtmfPlayer): Promise<void> {
    this.stopAudio();
    const ws = this.ws;
    if (!ws) return;
    const res = new Resampler(player.sampleRate);
    const untap = await player.tap((block) => {
      if (ws.readyState !== WebSocket.OPEN) return;
      const y = toInt16(res.push(block));
      if (y.length > 0) ws.send(y.buffer);
    });
    // Đã gác máy trong lúc chờ nạp worklet.
    if (this.ws !== ws) untap();
    else this.untap = untap;
  }

  private stopAudio(): void {
    this.untap?.();
    this.untap = null;
  }

  close(): void {
    this.stopAudio();
    const ws = this.ws;
    this.ws = null;
    if (ws && ws.readyState <= WebSocket.OPEN) ws.close();
  }
}
