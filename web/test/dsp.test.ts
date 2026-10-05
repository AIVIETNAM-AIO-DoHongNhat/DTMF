import { describe, expect, it } from 'vitest';
import { synthesize } from '../src/audio/dtmf';
import { decide } from '../src/dsp/decide';
import {
  GOERTZEL_N,
  binFits,
  binIndex,
  frameEnergies,
  goertzelPower,
  goertzelTrace,
  maxDeviationPct,
} from '../src/dsp/goertzel';
import { addAwgn } from '../src/dsp/noise';

describe('Goertzel - khớp goertzel_power.m', () => {
  it('ví dụ trong help: cos(2π·3n/16), k = 3, N = 16 cho 64', () => {
    const x = Array.from({ length: 16 }, (_, n) => Math.cos((2 * Math.PI * 3 * n) / 16));
    expect(goertzelPower(x, 3, 16)).toBeCloseTo(64, 9);
  });

  it('khung im lặng giữ E = 0, không chia 0', () => {
    expect(frameEnergies(new Float32Array(GOERTZEL_N)).E).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
  });

  it('khung ngắn hơn N là lỗi phía gọi', () => {
    expect(() => goertzelPower([1, 2, 3], 1, 4)).toThrow();
  });

  it('bin của N = 205 khớp dtmf_decode_goertzel', () => {
    expect([697, 770, 852, 941, 1209, 1336, 1477].map((f) => binIndex(f))).toEqual([
      18, 20, 22, 24, 31, 34, 38,
    ]);
  });

  it('bao |X_n| ở mẫu cuối bằng căn của công suất, và bao trùm dao động', () => {
    const x = synthesize(['8'], { fs: 8000 }).subarray(100, 100 + GOERTZEL_N);
    for (const k of [20, 34, 38]) {
      const { osc, mag } = goertzelTrace(x, k, GOERTZEL_N);
      expect(mag[GOERTZEL_N - 1] ** 2).toBeCloseTo(goertzelPower(x, k, GOERTZEL_N), 3);
      for (let n = 0; n < GOERTZEL_N; n++) expect(Math.abs(osc[n])).toBeLessThanOrEqual(mag[n] + 1e-4);
    }
  });
});

describe('lưới bin', () => {
  it('N = 205 lệch lớn nhất 1.36%, trong dung sai 1.5% của Q.24', () => {
    expect(maxDeviationPct(205)).toBeCloseTo(1.362, 3);
    expect(binFits(205).every((b) => Math.abs(b.devPct) < 1.5)).toBe(true);
  });

  it('N = 256 của nhánh FFT cũng lọt dung sai, N = 200 thì không', () => {
    expect(maxDeviationPct(256)).toBeLessThan(1.5);
    expect(maxDeviationPct(200)).toBeGreaterThan(1.5);
  });
});

describe('luật quyết định - khớp dtmf_decide.m', () => {
  it('ví dụ trong help: hàng 2, cột 2, không loại', () => {
    const d = decide([1, 8, 1, 1, 1, 9, 1, 0.1]);
    expect(d.reject).toBe('none');
    expect(d.key).toBe('5');
  });

  it('khung toàn 0 bị loại level trước mọi cửa', () => {
    const d = decide([0, 0, 0, 0, 0, 0, 0, 0]);
    expect(d).toMatchObject({ reject: 'level', silent: true, key: null, conf: 0 });
    expect(d.gates.every((g) => g.pass === null)).toBe(true);
  });

  it('trượt một cửa thì các cửa sau không xét', () => {
    // Cột mạnh hơn hàng 10 dB: qua hai cửa đỉnh, trượt twist.
    const d = decide([0.04, 0, 0, 0, 0, 0.4, 0, 0]);
    expect(d.reject).toBe('twist');
    expect(d.gates.map((g) => g.pass)).toEqual([true, true, false, null, null]);
  });

  it('hài bậc 2 quá nửa đỉnh yếu hơn thì loại harmonic', () => {
    expect(decide([0, 0.4, 0, 0, 0, 0.4, 0, 0.25]).reject).toBe('harmonic');
  });
});

describe('nhiễu', () => {
  it('đạt đúng SNR yêu cầu và tái lập theo hạt giống', () => {
    const x = synthesize(['1', '2', '3'], { fs: 8000 });
    const y = addAwgn(x, 10, 42);
    let px = 0;
    let pv = 0;
    for (let i = 0; i < x.length; i++) {
      px += x[i] ** 2;
      pv += (y[i] - x[i]) ** 2;
    }
    expect(10 * Math.log10(px / pv)).toBeCloseTo(10, 1);
    expect(addAwgn(x, 10, 42)).toEqual(y);
    expect(addAwgn(x, 10, 43)).not.toEqual(y);
  });
});
