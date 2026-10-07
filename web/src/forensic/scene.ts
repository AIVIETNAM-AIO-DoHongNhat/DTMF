// Đoạn ghi âm hiện trường cho màn giám định: một người bấm một số điện thoại
// trong lúc xung quanh có người nói chuyện và tiếng xè xè của đường truyền.
//
// Mọi thứ tính thẳng ở SCENE_FS = 8000 Hz, đúng tần số của bộ giải mã MATLAB:
// mẫu trang phát ra loa và mẫu gửi qua đường dây là một. Đáp án (số bí mật và
// lúc bấm từng phím) chỉ nằm trong `presses`, trang giữ lại tới lúc công bố.
//
// Tiếng nói là giọng TỔNG HỢP: chuỗi âm tiết nguyên âm có formant và thanh
// điệu, xen phụ âm xát. Nó có đủ thứ làm khó bộ giải mã - nhiều hài của f0
// rơi vào dải 697-1477 Hz, năng lượng dồn ở nhóm hàng - mà không cần tệp thu
// âm nào.

import { RAMP_MS, keyInfo, type DtmfKey } from '../audio/dtmf';
import { mulberry32, randn } from '../dsp/noise';

export const SCENE_FS = 8000;

/** Biên độ mỗi tone khi bấm [-]: hai tone cộng lại đỉnh 0.7, chừa chỗ cho âm nền. */
const TONE_AMP = 0.35;
/** Đỉnh lớn nhất của đoạn ghi âm sau khi trộn: chừa biên để int16 không cắt. */
const PEAK = 0.95;

export type Rhythm = 'may' | 'nguoi' | 'voi';
export type Background = 'none' | 'voice';

export interface RhythmSpec {
  /** Thời lượng tone và khoảng nghỉ [ms], rút đều trong [min, max]. */
  tone: [number, number];
  gap: [number, number];
  /** Nghỉ thêm giữa hai nhóm số kiểu 0912 345 678 [ms]; null là không ngắt nhóm. */
  group: [number, number] | null;
  /** Lệch mức và lệch twist giữa các lần bấm, ±dB. */
  jitterDb: number;
}

export const RHYTHMS: Record<Rhythm, RhythmSpec> = {
  /** Máy quay số: đều 100 ms tone, 50 ms nghỉ, như dtmf_generate. */
  may: {
    tone: [100, 100],
    gap: [50, 50],
    group: null,
    jitterDb: 0,
  },
  /** Người bấm tay, đọc số theo nhóm 4-3-3. */
  nguoi: {
    tone: [90, 220],
    gap: [140, 420],
    group: [350, 750],
    jitterDb: 1.5,
  },
  /** Bấm vội liên tục. Tone ngắn hơn ~77 ms có thể không đủ hai khung trọn - CONTRACTS §7.11. */
  voi: {
    tone: [65, 110],
    gap: [45, 80],
    group: null,
    jitterDb: 1.5,
  },
};

export interface SceneOptions {
  keys: readonly DtmfKey[];
  rhythm: Rhythm;
  background: Background;
  /** Mức âm nền so với tiếng bấm [dB]: RMS âm nền lúc đang nói chia RMS tone. */
  bgDb: number;
  /** SNR của nhiễu trắng, tính trên đoạn có tiếng bấm [dB]; null là không nhiễu. */
  snrDb: number | null;
  seed: number;
}

/** Một lần bấm: phím và lúc tone bắt đầu, kết thúc [s], tính từ đầu đoạn ghi âm. */
export interface Press {
  key: DtmfKey;
  start: number;
  end: number;
}

export interface Scene {
  x: Float32Array<ArrayBuffer>;
  fs: number;
  presses: Press[];
  sec: number;
}

const uni = (rand: () => number, [a, b]: [number, number]) => a + (b - a) * rand();

/**
 * Lịch bấm: một đoạn mở đầu (người nói "alo" trước khi bấm), các phím theo
 * nhịp đã chọn, rồi một đoạn kết. Số dài 8 phím trở lên ngắt nhóm sau phím
 * thứ 4 và thứ 7, như người đọc số điện thoại 0912 345 678.
 */
export function planPresses(keys: readonly DtmfKey[], rhythm: Rhythm, rand: () => number): { presses: Press[]; sec: number } {
  const r = RHYTHMS[rhythm];
  let t = rhythm === 'may' ? 0.8 : uni(rand, [1.0, 1.6]);
  const presses: Press[] = [];
  keys.forEach((key, i) => {
    if (i > 0) {
      t += uni(rand, r.gap) / 1000;
      if (r.group && keys.length >= 8 && (i === 4 || i === 7)) t += uni(rand, r.group) / 1000;
    }
    const d = uni(rand, r.tone) / 1000;
    presses.push({ key, start: t, end: t + d });
    t += d;
  });
  return { presses, sec: t + 0.8 };
}

/** Cộng các tone DTMF của lịch bấm vào x, có dốc 5 ms hai đầu như DtmfPlayer. */
function addTones(x: Float32Array, presses: readonly Press[], jitterDb: number, rand: () => number): void {
  const fs = SCENE_FS;
  const nRamp = Math.round((RAMP_MS / 1000) * fs);
  for (const p of presses) {
    const { rowHz, colHz } = keyInfo(p.key);
    // Mỗi lần bấm to nhỏ khác nhau một chút, và hai tone lệch nhau một chút
    // (twist), như bàn phím thật - vẫn trong giới hạn 4/8 dB của dtmf_decide.
    const g = Math.pow(10, ((2 * rand() - 1) * jitterDb) / 20);
    const tw = Math.pow(10, ((2 * rand() - 1) * jitterDb) / 40);
    const aR = TONE_AMP * g / tw;
    const aC = TONE_AMP * g * tw;
    const n0 = Math.round(p.start * fs);
    const nT = Math.round((p.end - p.start) * fs);
    for (let n = 0; n < nT && n0 + n < x.length; n++) {
      const t = n / fs;
      const ramp = Math.min(1, n / nRamp, (nT - 1 - n) / nRamp);
      x[n0 + n] += ramp * (aR * Math.sin(2 * Math.PI * rowHz * t) + aC * Math.sin(2 * Math.PI * colHz * t));
    }
  }
}

/* ------------------------------------------------------------- giọng tổng hợp */

/** Formant F1-F3 [Hz] của vài nguyên âm tiếng Việt, giọng nam. */
const VOWELS: [number, number, number][] = [
  [750, 1250, 2550], // a
  [550, 1850, 2500], // e
  [300, 2250, 2900], // i
  [500, 900, 2400], // o
  [320, 800, 2300], // u
  [550, 1350, 2450], // ơ
  [350, 1350, 2350], // ư
];
const BANDWIDTH = [80, 100, 140];

/**
 * Sáu thanh điệu, rút gọn thành đường f0 theo tỉ lệ trên một âm tiết (u từ
 * 0 tới 1): ngang, huyền, sắc, hỏi, ngã, nặng.
 */
const TONES: ((u: number) => number)[] = [
  () => 1,
  (u) => 0.95 - 0.12 * u,
  (u) => 1 + 0.22 * u,
  (u) => 0.95 - 0.25 * Math.sin(Math.PI * u),
  (u) => 1 + 0.25 * u * u - 0.1 * Math.sin(2 * Math.PI * u),
  (u) => 0.9 - 0.2 * u,
];

/** |H(f)| của ba formant mắc nối tiếp, mỗi cái một bộ cộng hưởng bậc hai, độ lợi 1 ở 0 Hz. */
function formantGain(f: number, F: readonly number[]): number {
  let g = 1;
  for (let i = 0; i < 3; i++) {
    const a = F[i] * F[i] - f * f;
    const b = BANDWIDTH[i] * f;
    g *= (F[i] * F[i]) / Math.sqrt(a * a + b * b);
  }
  return g;
}

interface Syllable {
  n0: number;
  n1: number;
  F: [number, number, number];
  Fprev: [number, number, number];
  tone: (u: number) => number;
  /** f0 gốc của âm tiết, đã tính độ hạ giọng dần về cuối câu [Hz]. */
  f0: number;
  /** Phụ âm xát đứng trước nguyên âm [mẫu], 0 nếu không có. */
  fric: number;
}

/**
 * Giọng tổng hợp dài n mẫu, chuẩn hóa để RMS trên các đoạn đang nói bằng 1.
 * Câu nói 1,2-3 s xen khoảng lặng 0,25-0,7 s; mỗi câu là chuỗi âm tiết
 * 120-260 ms. Nguyên âm dựng bằng tổng các hài của f0, biên độ mỗi hài là
 * độ nghiêng 1/k nhân |H| của ba formant. Hài tính bằng truy hồi
 * sin(kφ) = 2cosφ·sin((k-1)φ) - sin((k-2)φ), một sin và một cos mỗi mẫu.
 */
export function synthVoice(n: number, rand: () => number): Float32Array {
  const fs = SCENE_FS;
  const female = rand() < 0.5;
  const base = female ? 205 : 118;
  const scale = female ? 1.15 : 1;

  // Bước 1: xếp câu và âm tiết.
  const syl: Syllable[] = [];
  let t = Math.round(uni(rand, [0.05, 0.3]) * fs);
  let prev = VOWELS[0];
  while (t < n) {
    const end = Math.min(n, t + Math.round(uni(rand, [1.2, 3.0]) * fs));
    const t0 = t;
    while (t < end) {
      const len = Math.round(uni(rand, [0.12, 0.26]) * fs);
      const F = VOWELS[Math.floor(rand() * VOWELS.length)].map((f) => f * scale) as [number, number, number];
      const decl = 1 - 0.15 * ((t - t0) / Math.max(1, end - t0));
      const fric = rand() < 0.4 ? Math.round(uni(rand, [0.04, 0.09]) * fs) : 0;
      syl.push({
        n0: t,
        n1: Math.min(end, t + len),
        F,
        Fprev: prev,
        tone: TONES[Math.floor(rand() * TONES.length)],
        f0: base * decl * uni(rand, [0.92, 1.08]),
        fric,
      });
      prev = F;
      t += len + (rand() < 0.25 ? Math.round(uni(rand, [0.03, 0.08]) * fs) : 0);
    }
    t = end + Math.round(uni(rand, [0.25, 0.7]) * fs);
  }

  // Bước 2: tổng hợp từng âm tiết.
  const y = new Float32Array(n);
  const active = new Uint8Array(n);
  const hiss = randn(n, Math.floor(rand() * 2 ** 31));
  const BLOCK = 80; // 10 ms: biên độ các hài cập nhật theo khối
  for (const s of syl) {
    const len = s.n1 - s.n0;
    const nFric = Math.min(s.fric, Math.floor(len / 3));
    const atk = Math.round(0.025 * fs);
    const rel = Math.round(0.045 * fs);
    let phi = 0;
    let amps: number[] = [];
    let K = 0;
    let prevNoise = 0;
    for (let i = 0; i < len; i++) {
      const n0 = s.n0 + i;
      active[n0] = 1;

      // Phụ âm xát: nhiễu trắng qua sai phân bậc nhất (nghiêng lên tần số cao).
      if (i < nFric) {
        const w = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / nFric);
        const v = hiss[n0] - prevNoise;
        prevNoise = hiss[n0];
        y[n0] += 0.12 * w * v;
        continue;
      }
      const j = i - nFric;
      const lenV = len - nFric;
      const u = j / Math.max(1, lenV - 1);
      const f0 = s.f0 * s.tone(u) * (1 + 0.01 * Math.sin(2 * Math.PI * 5.3 * (n0 / fs)));

      if (j % BLOCK === 0) {
        // Formant trượt từ nguyên âm trước sang nguyên âm này trong 50 ms đầu.
        const m = Math.min(1, j / (0.05 * fs));
        const F = s.F.map((f, q) => s.Fprev[q] + m * (f - s.Fprev[q]));
        K = Math.max(1, Math.floor(3600 / f0));
        amps = [];
        for (let k = 1; k <= K; k++) amps.push(formantGain(k * f0, F) / k);
      }

      phi += (2 * Math.PI * f0) / fs;
      if (phi > 2 * Math.PI) phi -= 2 * Math.PI;
      const c2 = 2 * Math.cos(phi);
      let s2 = 0;
      let s1 = Math.sin(phi);
      let acc = amps[0] * s1;
      for (let k = 2; k <= K; k++) {
        const sk = c2 * s1 - s2;
        s2 = s1;
        s1 = sk;
        acc += amps[k - 1] * sk;
      }
      const env = Math.min(1, j / atk, (lenV - 1 - j) / rel);
      y[n0] += 0.02 * Math.max(0, env) * acc;
    }
  }

  // Bước 3: RMS trên đoạn đang nói bằng 1.
  let p = 0;
  let m = 0;
  for (let i = 0; i < n; i++) {
    if (active[i]) {
      p += y[i] * y[i];
      m++;
    }
  }
  const g = m > 0 && p > 0 ? 1 / Math.sqrt(p / m) : 0;
  for (let i = 0; i < n; i++) y[i] *= g;
  return y;
}

/**
 * Dựng đoạn ghi âm. Cùng seed và cùng tùy chọn thì ra đúng cùng mẫu.
 *
 * Mức âm nền và SNR đều so với tiếng bấm đo trên các đoạn CÓ tone, không phải
 * trung bình cả đoạn: nhịp bấm tay thưa hơn dtmf_generate nhiều, lấy trung
 * bình cả đoạn thì cùng một con số SNR lại là nhiễu to hơn hẳn. Chương 4 lấy
 * trung bình trên chuỗi 100/50 ms, nên SNR ở đây cao hơn số của chương 4
 * 10·log10(3/2) = 1,8 dB với cùng một mức nhiễu.
 */
export function buildScene(opt: SceneOptions): Scene {
  const rand = mulberry32(opt.seed);
  const { presses, sec } = planPresses(opt.keys, opt.rhythm, rand);
  const n = Math.ceil(sec * SCENE_FS);
  const x = new Float32Array(n);
  addTones(x, presses, RHYTHMS[opt.rhythm].jitterDb, rand);

  // Công suất tiếng bấm trên các đoạn có tone.
  let pT = 0;
  let mT = 0;
  for (const p of presses) {
    for (let i = Math.round(p.start * SCENE_FS); i < Math.round(p.end * SCENE_FS) && i < n; i++) {
      pT += x[i] * x[i];
      mT++;
    }
  }
  const toneRms = mT > 0 ? Math.sqrt(pT / mT) : TONE_AMP;

  if (opt.background === 'voice') {
    const bg = synthVoice(n, rand);
    const g = toneRms * Math.pow(10, opt.bgDb / 20);
    for (let i = 0; i < n; i++) x[i] += g * bg[i];
  }

  if (opt.snrDb !== null) {
    const sigma = toneRms / Math.pow(10, opt.snrDb / 20);
    const v = randn(n, Math.floor(rand() * 2 ** 31));
    for (let i = 0; i < n; i++) x[i] += sigma * v[i];
  }

  let peak = 0;
  for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(x[i]));
  if (peak > PEAK) {
    const g = PEAK / peak;
    for (let i = 0; i < n; i++) x[i] *= g;
  }
  return { x, fs: SCENE_FS, presses, sec: n / SCENE_FS };
}

/** Đầu số di động Việt Nam đang dùng, cho nút "Số ngẫu nhiên". */
const PREFIXES = [
  '032', '033', '034', '035', '036', '037', '038', '039', '070', '076', '077', '078', '079', '081', '082', '083',
  '084', '085', '086', '088', '089', '090', '091', '093', '094', '096', '097', '098',
];

/** Một số di động 10 chữ số trông như thật (không tra cứu, không gọi được). */
export function randomPhone(rand: () => number = Math.random): string {
  let s = PREFIXES[Math.floor(rand() * PREFIXES.length)];
  while (s.length < 10) s += String(Math.floor(rand() * 10));
  return s;
}

export interface Preset {
  id: string;
  /** Khung cảnh của mức này, hiện dưới thanh Độ khó. */
  ten: string;
  /** Kết quả thường gặp, theo tỉ lệ đo ở dưới. */
  ket: string;
  rhythm: Rhythm;
  background: Background;
  bgDb: number;
  snrDb: number | null;
}

/**
 * Bốn mức độ khó dựng sẵn, từ dễ tới khó. Tỉ lệ đọc đúng cả số (bản Goertzel
 * của trang, 60 số ngẫu nhiên, đo 07/10/2026): 60/60, 60/60, 35/60, 10/60 -
 * test scene.test.ts ghim các khoảng này. Tiếng nói làm hỏng chủ yếu bằng cách
 * làm MỘT khung giữa tone bị loại: dtmf_debounce cắt dải ở đó nên một lần bấm
 * thành hai chữ số. Không lần nào giọng nói bị đọc thành phím.
 */
export const PRESETS: Preset[] = [
  { id: 'yen', ten: 'Phòng yên tĩnh', ket: 'MATLAB đọc đúng cả số mọi lần', rhythm: 'nguoi', background: 'none', bgDb: -20, snrDb: null },
  { id: 'quan', ten: 'Quán cà phê', ket: 'MATLAB gần như luôn đọc đúng cả số', rhythm: 'nguoi', background: 'voice', bgDb: -20, snrDb: 20 },
  { id: 'duong', ten: 'Ngoài đường', ket: 'MATLAB đọc đúng cả số khoảng một nửa số lần', rhythm: 'nguoi', background: 'voice', bgDb: -14, snrDb: 12 },
  { id: 'kho', ten: 'Cực khó', ket: 'MATLAB hiếm khi đọc đúng cả số', rhythm: 'voi', background: 'voice', bgDb: -10, snrDb: 8 },
];
