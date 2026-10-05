import { describe, expect, it } from 'vitest';
import {
  COL_HZ,
  KEYS,
  PAUSE_MS,
  ROW_HZ,
  TONE_MS,
  keyInfo,
  parseKeys,
  scheduleSequence,
  sequenceDuration,
  synthesize,
  toneLevels,
} from '../src/audio/dtmf';
import { encodeWav } from '../src/audio/wav';

/** Công suất của x tại tần số f, tính bằng một phép DFT tại đúng một tần số. */
function congSuat(x: Float32Array, f: number, fs: number): number {
  let re = 0;
  let im = 0;
  for (let n = 0; n < x.length; n++) {
    re += x[n] * Math.cos((2 * Math.PI * f * n) / fs);
    im -= x[n] * Math.sin((2 * Math.PI * f * n) / fs);
  }
  return (re * re + im * im) / (x.length * x.length);
}

describe('bảng tần số', () => {
  it('khớp ITU-T Q.23 và src/gen/dtmf_table.m', () => {
    expect([...ROW_HZ]).toEqual([697, 770, 852, 941]);
    expect([...COL_HZ]).toEqual([1209, 1336, 1477]);
    expect(KEYS.join('')).toBe('123456789*0#');
  });

  it('mỗi phím là giao của một hàng và một cột', () => {
    expect(keyInfo('1')).toMatchObject({ rowHz: 697, colHz: 1209 });
    expect(keyInfo('5')).toMatchObject({ rowHz: 770, colHz: 1336 });
    expect(keyInfo('*')).toMatchObject({ rowHz: 941, colHz: 1209 });
    expect(keyInfo('#')).toMatchObject({ rowHz: 941, colHz: 1477 });
  });

  it('bỏ ký tự lạ và khoảng trắng, báo lại ký tự lạ', () => {
    expect(parseKeys('09 12a#')).toEqual({ keys: ['0', '9', '1', '2', '#'], invalid: ['a'] });
  });
});

describe('lịch phát và tổng hợp', () => {
  it('tone 100 ms, nghỉ 50 ms như dtmf_generate.m', () => {
    expect(TONE_MS).toBe(100);
    expect(PAUSE_MS).toBe(50);
    const plan = scheduleSequence(['1', '2', '3']);
    expect(plan.map((p) => p.start)).toEqual([0, 0.15, 0.3]);
    expect(plan.map((p) => +(p.end - p.start).toFixed(6))).toEqual([0.1, 0.1, 0.1]);
    expect(sequenceDuration(['1', '2', '3'])).toBeCloseTo(0.4, 12);
  });

  it('độ dài mẫu bằng dtmf_generate: K tone + (K-1) nghỉ', () => {
    const x = synthesize(['0', '9', '1', '2', '3', '4', '5'], { fs: 8000 });
    expect(x.length).toBe(7 * 800 + 6 * 400);
  });

  it('năng lượng nằm đúng ở cặp tần số của phím, không ở năm tần số kia', () => {
    const fs = 8000;
    for (const key of ['1', '5', '9', '#'] as const) {
      const x = synthesize([key], { fs });
      const { rowHz, colHz } = keyInfo(key);
      const p = (f: number) => congSuat(x, f, fs);
      const khac = [...ROW_HZ, ...COL_HZ].filter((f) => f !== rowHz && f !== colHz);
      const nenMax = Math.max(...khac.map(p));
      expect(p(rowHz)).toBeGreaterThan(100 * nenMax);
      expect(p(colHz)).toBeGreaterThan(100 * nenMax);
    }
  });

  it('bù loa nâng nhóm hàng đúng số dB, tổng biên độ không đổi', () => {
    const lv = toneLevels(0.8, 6);
    expect(lv.row + lv.col).toBeCloseTo(0.8, 12);
    expect(20 * Math.log10(lv.row / lv.col)).toBeCloseTo(6, 9);

    const x = synthesize(['5'], { fs: 8000, rowBoostDb: 6 });
    const dB = 10 * Math.log10(congSuat(x, 770, 8000) / congSuat(x, 1336, 8000));
    expect(dB).toBeCloseTo(6, 1);
  });

  it('đỉnh không vượt 1 và hai đầu tone có dốc, không nhảy bậc', () => {
    const x = synthesize(['3', '3'], { fs: 8000, volume: 1 });
    expect(Math.max(...x.map(Math.abs))).toBeLessThanOrEqual(1);
    expect(x[0]).toBe(0);
    expect(Math.abs(x[799])).toBeLessThan(1e-6);
    expect([...x.slice(800, 1200)].every((v) => v === 0)).toBe(true);
  });
});

describe('WAV', () => {
  it('header PCM 16 bit đơn kênh đúng cỡ', () => {
    const x = synthesize(['5'], { fs: 8000 });
    const v = new DataView(encodeWav(x, 8000));
    const chu = (o: number) => String.fromCharCode(...[0, 1, 2, 3].map((i) => v.getUint8(o + i)));
    expect(chu(0)).toBe('RIFF');
    expect(chu(8)).toBe('WAVE');
    expect(chu(12)).toBe('fmt ');
    expect(v.getUint16(20, true)).toBe(1);
    expect(v.getUint16(22, true)).toBe(1);
    expect(v.getUint32(24, true)).toBe(8000);
    expect(v.getUint16(34, true)).toBe(16);
    expect(chu(36)).toBe('data');
    expect(v.getUint32(40, true)).toBe(x.length * 2);
    expect(v.byteLength).toBe(44 + x.length * 2);
  });
});
