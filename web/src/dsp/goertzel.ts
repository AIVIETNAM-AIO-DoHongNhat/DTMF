// Goertzel và phép đo một khung, chép đúng từng bước của src/decode/
// goertzel_power.m và dtmf_decode_goertzel.m. Chỉ dùng để MINH HỌA trên tín
// hiệu tổng hợp ngay trong trang; trang không giải mã âm thanh thu từ micro.

import { COL_HZ, ROW_HZ } from '../audio/dtmf';

/** Tần số lấy mẫu của bộ giải mã MATLAB [Hz]. */
export const FS = 8000;
/** Độ dài khung của nhánh Goertzel [mẫu]: 25.6 ms ở 8 kHz. */
export const GOERTZEL_N = 205;
/** Dung sai tần số của ITU-T Q.24 [%]. */
export const Q24_TOL_PCT = 1.5;

/** Bảy tần số chuẩn theo đúng thứ tự của E(1:7): bốn hàng rồi ba cột. */
export const STD_HZ: readonly number[] = [...ROW_HZ, ...COL_HZ];

/** Bin DFT gần f nhất: k = round(N f / fs). */
export function binIndex(f: number, N = GOERTZEL_N, fs = FS): number {
  return Math.round((N * f) / fs);
}

/** P = |X[k]|^2 bằng bộ lọc IIR bậc 2 - goertzel_power.m. */
export function goertzelPower(x: ArrayLike<number>, k: number, N: number): number {
  if (x.length < N) throw new Error(`x chỉ có ${x.length} mẫu, cần ít nhất N = ${N}.`);
  const c = 2 * Math.cos((2 * Math.PI * k) / N);
  let s1 = 0;
  let s2 = 0;
  for (let n = 0; n < N; n++) {
    const s = x[n] + c * s1 - s2;
    s2 = s1;
    s1 = s;
  }
  return s1 * s1 + s2 * s2 - c * s1 * s2;
}

export interface GoertzelTrace {
  /** s[n]·sin ω: dao động bên trong bộ cộng hưởng, cùng thang với |X|. */
  osc: Float32Array;
  /** |X_n[k]|: biên độ DFT của n+1 mẫu đầu, chính là bao của osc. */
  mag: Float32Array;
}

/**
 * Trạng thái của bộ cộng hưởng Goertzel sau từng mẫu. s[n] tự phình theo
 * 1/sin ω nên không so được giữa hai bin; nhân sin ω đưa mọi bin về cùng thang
 * với |X[k]|. Tại n = N-1, mag^2 đúng bằng goertzelPower.
 */
export function goertzelTrace(x: ArrayLike<number>, k: number, N: number): GoertzelTrace {
  const w = (2 * Math.PI * k) / N;
  const c = 2 * Math.cos(w);
  const sw = Math.sin(w);
  const osc = new Float32Array(N);
  const mag = new Float32Array(N);
  let s1 = 0;
  let s2 = 0;
  for (let n = 0; n < N; n++) {
    const s = x[n] + c * s1 - s2;
    s2 = s1;
    s1 = s;
    osc[n] = s1 * sw;
    mag[n] = Math.sqrt(Math.max(0, s1 * s1 + s2 * s2 - c * s1 * s2));
  }
  return { osc, mag };
}

export interface FrameEnergies {
  /** 8 công suất đã chuẩn hóa: 4 hàng, 3 cột, hài bậc 2. */
  E: number[];
  /** Chỉ số bin của 7 tần số chuẩn. */
  k: number[];
  /** Bin hài bậc 2, bám theo đỉnh của chính khung này. */
  kHarm: number;
  /** Mẫu số chuẩn hóa N·Σx²/2. */
  en: number;
}

/**
 * Bước 2 của dtmf_decode_goertzel cho MỘT khung: 7 bin chuẩn, bin hài gấp
 * đôi bin đỉnh, rồi chia cho năng lượng khung để Σ E(1:7) thành tỉ lệ.
 */
export function frameEnergies(frame: ArrayLike<number>, N = GOERTZEL_N, fs = FS): FrameEnergies {
  const k = STD_HZ.map((f) => binIndex(f, N, fs));
  const P = k.map((kk) => goertzelPower(frame, kk, N));

  // max() của MATLAB trả vị trí đầu tiên khi bằng nhau - reduce giữ đúng thế.
  const d = P.reduce((best, p, i) => (p > P[best] ? i : best), 0);
  const kHarm = Math.min(2 * k[d], Math.floor(N / 2));
  P.push(goertzelPower(frame, kHarm, N));

  let sum = 0;
  for (let n = 0; n < N; n++) sum += frame[n] * frame[n];
  const en = (N * sum) / 2;
  const E = en > 0 ? P.map((p) => p / en) : P.map(() => 0);
  return { E, k, kHarm, en };
}

export interface BinFit {
  f: number;
  k: number;
  /** Tần số tâm của bin k [Hz]. */
  fk: number;
  /** (fk - f)/f [%], có dấu. */
  devPct: number;
}

/** Bin gần nhất của từng tần số chuẩn và độ lệch của nó, với khung N mẫu. */
export function binFits(N: number, fs = FS): BinFit[] {
  return STD_HZ.map((f) => {
    const k = binIndex(f, N, fs);
    const fk = (k * fs) / N;
    return { f, k, fk, devPct: ((fk - f) / f) * 100 };
  });
}

/** Độ lệch lớn nhất (trị tuyệt đối) trên bảy tần số [%]. */
export function maxDeviationPct(N: number, fs = FS): number {
  return Math.max(...binFits(N, fs).map((b) => Math.abs(b.devPct)));
}
