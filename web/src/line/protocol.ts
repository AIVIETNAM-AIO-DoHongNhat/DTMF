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
//
// Tệp này không phụ thuộc DOM hay Node: cả trang lẫn cầu nối cùng nhập nó.

/** Đường dẫn WebSocket của đường dây trên máy chủ Vite. */
export const LINE_PATH = '/line';
/** Cổng TCP mà MATLAB nối vào, chỉ nghe trên 127.0.0.1. */
export const MATLAB_PORT = 8765;
/** Tần số lấy mẫu trên đường dây [Hz] - khớp fs = 8000 của bộ giải mã MATLAB. */
export const LINE_FS = 8000;

/** Điện thoại gửi tổng đài. */
export type PhoneMsg = { t: 'call' } | { t: 'hangup' };

/** Tổng đài (MATLAB) gửi điện thoại, qua cầu nối. */
export type SwitchMsg =
  | { t: 'answer' }
  | { t: 'key'; k: string }
  | { t: 'hangup' };

/** Cầu nối báo điện thoại: MATLAB có đang nối vào đường dây không. */
export type LineStatus = { t: 'line'; matlab: boolean; method?: string };

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
    case 'line':
      return {
        t: 'line',
        matlab: o.matlab === true,
        ...(typeof o.method === 'string' ? { method: o.method } : {}),
      };
    default:
      return null;
  }
}
