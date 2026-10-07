import { describe, expect, it } from 'vitest';
import { parseKeys, type DtmfKey } from '../src/audio/dtmf';
import { debounce } from '../src/dsp/debounce';
import { decide } from '../src/dsp/decide';
import { GOERTZEL_N, frameEnergies } from '../src/dsp/goertzel';
import { mulberry32 } from '../src/dsp/noise';
import { PRESETS, RHYTHMS, SCENE_FS, buildScene, planPresses, randomPhone, synthVoice } from '../src/forensic/scene';

/** Giải mã như dtmf_decode_goertzel: trừ trung bình, khung 205 không chồng, quyết định, gộp. */
function decode(x: Float32Array): string {
  let mean = 0;
  for (let i = 0; i < x.length; i++) mean += x[i];
  mean /= x.length;
  const keys: (DtmfKey | null)[] = [];
  const frame = new Float32Array(GOERTZEL_N);
  for (let i0 = 0; i0 + GOERTZEL_N <= x.length; i0 += GOERTZEL_N) {
    for (let n = 0; n < GOERTZEL_N; n++) frame[n] = x[i0 + n] - mean;
    keys.push(decide(frameEnergies(frame).E).key);
  }
  return debounce(keys).keys;
}

const keysOf = (s: string) => parseKeys(s).keys;

describe('đoạn ghi âm hiện trường: lịch bấm', () => {
  for (const r of ['may', 'nguoi', 'voi'] as const) {
    it(`nhịp ${r}: tone và khoảng nghỉ nằm đúng khoảng đã khai`, () => {
      const spec = RHYTHMS[r];
      const { presses, sec } = planPresses(keysOf('0912345678'), r, mulberry32(7));
      expect(presses.map((p) => p.key).join('')).toBe('0912345678');
      presses.forEach((p, i) => {
        const tone = (p.end - p.start) * 1000;
        expect(tone).toBeGreaterThanOrEqual(spec.tone[0] - 1e-9);
        expect(tone).toBeLessThanOrEqual(spec.tone[1] + 1e-9);
        if (i === 0) return;
        const gap = (p.start - presses[i - 1].end) * 1000;
        const extra = spec.group && (i === 4 || i === 7) ? spec.group[1] : 0;
        expect(gap).toBeGreaterThanOrEqual(spec.gap[0] - 1e-9);
        expect(gap).toBeLessThanOrEqual(spec.gap[1] + extra + 1e-9);
      });
      expect(sec).toBeGreaterThan(presses[presses.length - 1].end);
    });
  }

  it('cùng seed cho đúng cùng mẫu, khác seed thì khác', () => {
    const opt = { keys: keysOf('0912345678'), rhythm: 'nguoi', background: 'voice', bgDb: -6, snrDb: 20 } as const;
    const a = buildScene({ ...opt, seed: 11 });
    const b = buildScene({ ...opt, seed: 11 });
    const c = buildScene({ ...opt, seed: 12 });
    expect(Array.from(a.x)).toEqual(Array.from(b.x));
    expect(a.x.length === c.x.length && a.x.every((v, i) => v === c.x[i])).toBe(false);
  });
});

describe('đoạn ghi âm hiện trường: mức âm', () => {
  it('SNR đo trên đoạn có tone đúng như đặt', () => {
    const base = { keys: keysOf('0912345678'), rhythm: 'nguoi', background: 'none', bgDb: 0, seed: 3 } as const;
    const sach = buildScene({ ...base, snrDb: null });
    const on = buildScene({ ...base, snrDb: 20 });
    let pT = 0;
    let mT = 0;
    for (const p of sach.presses) {
      for (let i = Math.round(p.start * SCENE_FS); i < Math.round(p.end * SCENE_FS); i++) {
        pT += sach.x[i] ** 2;
        mT++;
      }
    }
    let pV = 0;
    for (let i = 0; i < on.x.length; i++) pV += (on.x[i] - sach.x[i]) ** 2;
    const snr = 10 * Math.log10(pT / mT / (pV / on.x.length));
    expect(Math.abs(snr - 20)).toBeLessThan(0.3);
  });

  it('giọng tổng hợp có RMS 1 trên đoạn đang nói, có khoảng lặng giữa các câu', () => {
    const y = synthVoice(8 * SCENE_FS, mulberry32(5));
    let p = 0;
    let m = 0;
    let lang = 0;
    for (let i = 0; i < y.length; i++) {
      if (y[i] !== 0) {
        p += y[i] ** 2;
        m++;
      } else lang++;
    }
    expect(Math.abs(Math.sqrt(p / m) - 1)).toBeLessThan(0.05);
    expect(lang / y.length).toBeGreaterThan(0.05);
  });

  it('không bao giờ vượt biên int16', () => {
    for (const pr of PRESETS) {
      const s = buildScene({ keys: keysOf('0912345678'), ...pr, seed: 9 });
      expect(Math.max(...s.x.map(Math.abs))).toBeLessThanOrEqual(0.95 + 1e-6);
    }
  });

  it('số ngẫu nhiên là số di động 10 chữ số, bắt đầu bằng 0', () => {
    const rand = mulberry32(1);
    for (let i = 0; i < 50; i++) expect(randomPhone(rand)).toMatch(/^0\d{9}$/);
  });
});

describe('đoạn ghi âm hiện trường: bốn mức độ khó dựng sẵn', () => {
  // Thứ tự dễ -> khó phải giữ (thanh Độ khó đi theo thứ tự PRESETS): hai mức đầu là để thấy MATLAB đọc đúng,
  // hai cái sau là để thấy nó bắt đầu sai. Đổi giọng tổng hợp hay luật quyết
  // định mà lệch khoảng thì chỉnh lại mức trong PRESETS.
  const KHOANG: Record<string, [number, number]> = {
    yen: [60, 60],
    quan: [57, 60],
    duong: [18, 50],
    kho: [0, 25],
  };
  for (const pr of PRESETS) {
    it(`${pr.ten}: đọc đúng cả số trong khoảng mong đợi`, () => {
      const rand = mulberry32(99);
      let dung = 0;
      for (let s = 0; s < 60; s++) {
        const so = randomPhone(rand);
        if (decode(buildScene({ keys: keysOf(so), ...pr, seed: 500 + s }).x) === so) dung++;
      }
      expect(dung).toBeGreaterThanOrEqual(KHOANG[pr.id][0]);
      expect(dung).toBeLessThanOrEqual(KHOANG[pr.id][1]);
    });
  }

  it('giọng tổng hợp đứng một mình không bị đọc thành phím nào (talk-off)', () => {
    // 10 giọng × 30 s = 5 phút nói liên tục, 0 phím.
    for (let s = 0; s < 10; s++) expect(decode(synthVoice(30 * SCENE_FS, mulberry32(s)))).toBe('');
  });
});
