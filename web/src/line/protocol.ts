// Giao thức của đường dây điện thoại (trang web) <-> tổng đài (MATLAB DTMFLive).
//
// Đường đi:  trang web --WebSocket /line--> cầu nối (Vite) --TCP 127.0.0.1:8765--> MATLAB
//
// Điện thoại -> cầu nối: khung NHỊ PHÂN là mẫu âm thanh PCM int16 little-endian,
// đơn kênh, LINE_FS Hz - đúng những gì trang đang phát ra loa. Khung CHỮ là một
// PhoneMsg dạng JSON.
// Cầu nối -> MATLAB: mỗi dòng một JSON (kết thúc '\n'). Âm thanh đi thành
// {"t":"pcm","d":"<base64>"}; mỗi giây một {"t":"ping"} để MATLAB biết đường dây
// còn sống (tcpclient của MATLAB không báo khi đầu kia đóng).
// MATLAB -> cầu nối -> điện thoại: mỗi dòng một SwitchMsg.
// Riêng {"t":"hello","method":...,"app":...} (MATLAB -> cầu nối) không chuyển đi: cầu nối
// ghi lại bộ giải mã và ứng dụng đang nghe rồi báo điện thoại bằng LineStatus.
//
// Hai kiểu dùng chung một đường dây:
//   tổng đài (DTMFLive):      call -> answer -> (âm thanh, key...) -> hangup
//   giám định (DTMFForensic): case -> (âm thanh, key...) -> end -> verdict -> reveal
// Ở kiểu giám định, đáp án (reveal) chỉ được gửi SAU khi MATLAB đã kết luận.
//
// Tệp này không phụ thuộc DOM hay Node: cả trang lẫn cầu nối cùng nhập nó.

/** Đường dẫn WebSocket của đường dây trên máy chủ Vite. */
export const LINE_PATH = '/line';
/** Cổng TCP mà MATLAB nối vào, chỉ nghe trên 127.0.0.1. */
export const MATLAB_PORT = 8765;
/** Tần số lấy mẫu trên đường dây [Hz] - khớp fs = 8000 của bộ giải mã MATLAB. */
export const LINE_FS = 8000;

/** Điện thoại gửi tổng đài. */
export type PhoneMsg =
  | { t: 'call' }
  | { t: 'hangup' }
  /** Bắt đầu một đoạn ghi âm: số vụ và độ dài [s], để MATLAB đặt cửa sổ vừa đủ. */
  | { t: 'case'; id: number; sec: number }
  /** Đã gửi hết đoạn ghi âm. */
  | { t: 'end' }
  /** Đáp án: số thật và lúc bấm từng phím [s], phẳng thành [đầu1, cuối1, đầu2, ...]. */
  | { t: 'reveal'; keys: string; marks: number[] };

/** Kiểu của các tin chữ mà cầu nối chuyển từ điện thoại sang MATLAB. */
export const PHONE_TYPES = ['call', 'hangup', 'case', 'end', 'reveal'] as const;

/** Kết quả của một bộ giải mã trên cả đoạn ghi âm. */
export interface MethodResult {
  name: string;
  keys: string;
  /** Thời gian xử lý cả đoạn [ms]. */
  ms: number;
}

/** Tổng đài (MATLAB) gửi điện thoại, qua cầu nối. */
export type SwitchMsg =
  | { t: 'answer' }
  | { t: 'key'; k: string }
  | { t: 'hangup' }
  /** Kết luận sau khi nghe hết đoạn ghi âm: số của bộ giải mã đang chọn và cả ba. */
  | { t: 'verdict'; keys: string; methods: MethodResult[] };

/**
 * Cầu nối báo điện thoại: MATLAB có đang nối vào đường dây không, bộ giải mã
 * nào, và ứng dụng nào ('live' là tổng đài, 'forensic' là giám định).
 */
export type LineStatus = { t: 'line'; matlab: boolean; method?: string; app?: string };

export type ToPhone = SwitchMsg | LineStatus;

/** Đọc một khung chữ gửi tới điện thoại; khung lạ trả null thay vì ném lỗi. */
export function parseToPhone(text: string): ToPhone | null {
  let m: unknown;
  try {
    m = JSON.parse(text);
  } catch {
    return null;
  }
  if (typeof m !== 'object' || m === null || !('t' in m)) return null;
  const o = m as Record<string, unknown>;
  switch (o.t) {
    case 'answer':
    case 'hangup':
      return { t: o.t };
    case 'key':
      return typeof o.k === 'string' && o.k.length === 1 ? { t: 'key', k: o.k } : null;
    case 'verdict': {
      if (typeof o.keys !== 'string') return null;
      // jsonencode của MATLAB đổi mảng struct một phần tử thành MỘT đối tượng.
      const ds = Array.isArray(o.methods) ? o.methods : o.methods ? [o.methods] : [];
      const methods: MethodResult[] = [];
      for (const d of ds) {
        if (typeof d !== 'object' || d === null) continue;
        const r = d as Record<string, unknown>;
        if (typeof r.name === 'string' && typeof r.keys === 'string' && typeof r.ms === 'number') {
          methods.push({ name: r.name, keys: r.keys, ms: r.ms });
        }
      }
      return { t: 'verdict', keys: o.keys, methods };
    }
    case 'line':
      return {
        t: 'line',
        matlab: o.matlab === true,
        ...(typeof o.method === 'string' ? { method: o.method } : {}),
        ...(typeof o.app === 'string' ? { app: o.app } : {}),
      };
    default:
      return null;
  }
}
