// Hành trình của MỘT lần bấm phím: điện thoại phát, âm đi qua không khí tới
// micro, tổng đài lấy mẫu 8 kHz, chia khung 205 mẫu, đo Goertzel, áp luật
// quyết định rồi gộp khung - đúng chuỗi bước của dtmf_decode_goertzel và
// dtmf_listen. Đây là mô phỏng để minh họa; khi trình diễn thật, MATLAB nghe
// âm thanh của trang qua micro.

import { keyInfo, toneLevels, RAMP_MS, type DtmfKey } from '../audio/dtmf';
import { decide, type Decision } from './decide';
import { debounce, type Run } from './debounce';
import { FS, GOERTZEL_N, frameEnergies } from './goertzel';
import { randn } from './noise';

/** Tốc độ âm thanh trong không khí [cm/s]. */
export const SOUND_CM_S = 34300;
/** Khoảng cách tham chiếu: tại đây suy hao truyền là 0 dB [cm]. */
export const REF_CM = 10;
/** Âm lượng tham chiếu của thang tiếng ồn: SNR đặt ra đúng ở mức này. */
const REF_VOLUME = 0.8;
/** Lặng sau tone, như khoảng nghỉ của dtmf_generate [ms]. */
const TAIL_MS = 50;

export interface PhoneParams {
  volume: number;
  rowBoostDb: number;
  /** Thời lượng tone [ms]: nhấn giữ lâu thì tone dài hơn. */
  toneMs: number;
}

export interface ChannelParams {
  distanceCm: number;
  /** SNR ở 10 cm với âm lượng 80%, loa phẳng [dB]; null là phòng không có tiếng ồn. */
  roomSnrDb: number | null;
  /** Loa nhỏ làm nhóm hàng yếu đi chừng này [dB]. */
  speakerLossDb: number;
}

export interface FrameResult {
  /** Mẫu đầu và mẫu sau-cuối của khung trong y. */
  i0: number;
  i1: number;
  E: number[];
  decision: Decision;
}

export interface Transmission {
  key: DtmfKey;
  rowHz: number;
  colHz: number;
  /** Biên độ hai tone ở loa (sau bù loa). */
  txRow: number;
  txCol: number;
  /** Thời lượng tone [s]. */
  toneS: number;
  /** Nhiễu cộng vào y (null khi không có nhiễu) và độ lệch chuẩn của nó. */
  noise: Float32Array | null;
  noiseRms: number;
  /** Tín hiệu loa phát, trên cùng trục mẫu với y. */
  x: Float32Array;
  /** Tín hiệu micro thu: trễ, suy hao, lệch twist, cộng nhiễu. */
  y: Float32Array;
  /** Mẫu (thực) tone bắt đầu ở loa và tới micro. */
  onset: number;
  arrive: number;
  toneLen: number;
  delayMs: number;
  /** Suy hao theo khoảng cách [dB], âm là yếu đi. */
  pathDb: number;
  /** SNR trên đoạn tone tại micro [dB]; Infinity khi không có nhiễu. */
  snrDb: number;
  /** Twist tại micro, cột so với hàng [dB] - cùng dấu với dtmf_decide. */
  twistDb: number;
  /** Biên độ hai tone tại micro. */
  aRow: number;
  aCol: number;
  frames: FrameResult[];
  runs: Run[];
  /** Chuỗi phím tổng đài đọc được (thường là 0 hoặc 1 ký tự). */
  decoded: string;
  /** Khung mà tại đó phím đầu tiên được báo, -1 nếu không báo. */
  reportFrame: number;
}

/** Đổi chỉ số mẫu trên trục chung sang mili giây kể từ lúc bấm phím. */
export function sampleToMs(tx: Transmission, n: number): number {
  return ((n - tx.onset) / FS) * 1000;
}

/** Thời điểm tổng đài báo phím [ms sau lúc bấm], null nếu không nghe ra. */
export function reportMs(tx: Transmission): number | null {
  return tx.reportFrame < 0 ? null : sampleToMs(tx, tx.frames[tx.reportFrame].i1);
}

/** Hệ số dốc lên/xuống ở hai đầu tone, t tính bằng giây kể từ đầu tone. */
function rampAt(t: number, T: number): number {
  const r = RAMP_MS / 1000;
  if (t < 0 || t > T) return 0;
  return Math.min(1, t / r, (T - t) / r);
}

export interface ToneParts {
  row: number;
  col: number;
}

/** Hai thành phần sóng liên tục ở loa, tại tMs mili giây sau lúc bấm. */
export function speakerAt(tx: Transmission, tMs: number): ToneParts {
  const t = tMs / 1000;
  const g = rampAt(t, tx.toneS);
  return {
    row: g * tx.txRow * Math.sin(2 * Math.PI * tx.rowHz * t),
    col: g * tx.txCol * Math.sin(2 * Math.PI * tx.colHz * t),
  };
}

/** Hai thành phần sóng (chưa có nhiễu) tới micro, tại tMs sau lúc bấm. */
export function micAt(tx: Transmission, tMs: number): ToneParts {
  const t = (tMs - tx.delayMs) / 1000;
  const g = rampAt(t, tx.toneS);
  return {
    row: g * tx.aRow * Math.sin(2 * Math.PI * tx.rowHz * t),
    col: g * tx.aCol * Math.sin(2 * Math.PI * tx.colHz * t),
  };
}

/** Nhiễu tại tMs sau lúc bấm, nội suy tuyến tính giữa hai mẫu 8 kHz. */
export function noiseAt(tx: Transmission, tMs: number): number {
  if (!tx.noise) return 0;
  const p = tx.onset + (tMs / 1000) * FS;
  const i = Math.floor(p);
  if (i < 0 || i + 1 >= tx.noise.length) return 0;
  return tx.noise[i] + (p - i) * (tx.noise[i + 1] - tx.noise[i]);
}

/** Khung có tâm gần tâm tone nhất: khung đại diện khi cần giải thích một lần bấm. */
export function centerFrame(tx: Transmission): number {
  const mid = tx.arrive + tx.toneLen / 2;
  let best = 0;
  tx.frames.forEach((f, i) => {
    if (Math.abs((f.i0 + f.i1) / 2 - mid) < Math.abs((tx.frames[best].i0 + tx.frames[best].i1) / 2 - mid)) best = i;
  });
  return best;
}

/** Lúc tổng đài xử lý xong khung cuối [ms sau lúc bấm]: hết hành trình. */
export function journeyEndMs(tx: Transmission): number {
  return sampleToMs(tx, tx.frames[tx.frames.length - 1].i1);
}

/**
 * Mô phỏng một lần bấm. `align` là độ lệch của lúc bấm so với lưới khung của
 * tổng đài [mẫu, 0..204]: lưới chạy liên tục nên phím rơi vào chỗ nào là
 * ngẫu nhiên, và chính nó làm độ trễ báo phím dao động.
 */
export function transmit(
  key: DtmfKey,
  phone: PhoneParams,
  ch: ChannelParams,
  align: number,
  seed: number,
): Transmission {
  const { rowHz, colHz } = keyInfo(key);
  const lv = toneLevels(phone.volume, phone.rowBoostDb);
  const T = phone.toneMs / 1000;

  const delay = ch.distanceCm / SOUND_CM_S; // [s]
  const gPath = REF_CM / Math.max(1, ch.distanceCm);
  const gRow = Math.pow(10, -ch.speakerLossDb / 20);
  const aRow = lv.row * gRow * gPath;
  const aCol = lv.col * gPath;

  // Một khung lặng trọn vẹn đứng trước, để khung đầu tiên không cắt ngang tone.
  const onset = GOERTZEL_N + align;
  const arrive = onset + delay * FS;
  const toneLen = Math.round(T * FS);
  const need = Math.ceil(arrive) + toneLen + Math.round((TAIL_MS / 1000) * FS);
  const len = Math.ceil(need / GOERTZEL_N) * GOERTZEL_N; // số khung nguyên

  const x = new Float32Array(len);
  const y = new Float32Array(len);
  const tone = (t: number, ar: number, ac: number) =>
    rampAt(t, T) * (ar * Math.sin(2 * Math.PI * rowHz * t) + ac * Math.sin(2 * Math.PI * colHz * t));
  for (let n = 0; n < len; n++) {
    x[n] = tone((n - onset) / FS, lv.row, lv.col);
    y[n] = tone((n - arrive) / FS, aRow, aCol);
  }

  // Tiếng ồn phòng có mức cố định: đứng xa hay vặn nhỏ âm lượng thì SNR tụt.
  const aRef = REF_VOLUME / 2; // mỗi tone một nửa khi không bù loa
  const pRef = aRef * aRef;    // (aRef² + aRef²) / 2
  const pTone = (aRow * aRow + aCol * aCol) / 2;
  let snrDb = Infinity;
  let noise: Float32Array | null = null;
  let sigma = 0;
  if (ch.roomSnrDb !== null) {
    sigma = Math.sqrt(pRef / Math.pow(10, ch.roomSnrDb / 10));
    noise = randn(len, seed);
    for (let n = 0; n < len; n++) {
      noise[n] *= sigma;
      y[n] += noise[n];
    }
    snrDb = 10 * Math.log10(pTone / (sigma * sigma));
  }

  const frames: FrameResult[] = [];
  for (let i0 = 0; i0 + GOERTZEL_N <= len; i0 += GOERTZEL_N) {
    const fe = frameEnergies(y.subarray(i0, i0 + GOERTZEL_N));
    frames.push({ i0, i1: i0 + GOERTZEL_N, E: fe.E, decision: decide(fe.E) });
  }

  const { keys, runs } = debounce(frames.map((f) => f.decision.key));
  const firstKept = runs.find((r) => r.kept);

  return {
    key,
    rowHz,
    colHz,
    txRow: lv.row,
    txCol: lv.col,
    toneS: T,
    noise,
    noiseRms: sigma,
    x,
    y,
    onset,
    arrive,
    toneLen,
    delayMs: delay * 1000,
    pathDb: 20 * Math.log10(gPath),
    snrDb,
    twistDb: 20 * Math.log10(aCol / aRow),
    aRow,
    aCol,
    frames,
    runs,
    decoded: keys,
    // Bộ giải mã luồng báo ngay khi dải đủ minRun = 2 khung (CONTRACTS §7.9).
    reportFrame: firstKept ? firstKept.first + 1 : -1,
  };
}
