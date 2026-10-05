import { describe, expect, it } from 'vitest';
import { COL_HZ, KEYS, ROW_HZ, keyInfo, synthesize, toneLevels } from '../src/audio/dtmf';
import { amplitudeAt, amplitudeSpectrum } from '../src/dsp/spectrum';

const FS = 8000;

describe('Phổ biên độ của một tone', () => {
  it('sin biên độ 0.3 tại 1000 Hz cho đỉnh 0.3', () => {
    const x = Float32Array.from({ length: 800 }, (_, n) => 0.3 * Math.sin((2 * Math.PI * 1000 * n) / FS));
    expect(amplitudeAt(x, FS, 1000)).toBeCloseTo(0.3, 3);
  });

  it('mỗi phím có đúng hai đỉnh, đọc ra biên độ hai tone', () => {
    const lv = toneLevels(0.8, 0);
    for (const k of KEYS) {
      const { rowHz, colHz } = keyInfo(k);
      const x = synthesize([k], { fs: FS, volume: 0.8 });
      expect(amplitudeAt(x, FS, rowHz)).toBeCloseTo(lv.row, 2);
      expect(amplitudeAt(x, FS, colHz)).toBeCloseTo(lv.col, 2);
      // Các tần số DTMF khác gần như không có gì.
      for (const f of [...ROW_HZ, ...COL_HZ]) {
        if (f !== rowHz && f !== colHz) expect(amplitudeAt(x, FS, f)).toBeLessThan(0.01);
      }
    }
  });

  it('bù loa 6 dB làm đỉnh hàng cao gấp đôi đỉnh cột', () => {
    const x = synthesize(['5'], { fs: FS, volume: 0.8, rowBoostDb: 6 });
    const r = amplitudeAt(x, FS, 770) / amplitudeAt(x, FS, 1336);
    expect(r).toBeCloseTo(Math.pow(10, 6 / 20), 2);
  });

  it('lưới tần số đều, đỉnh lớn nhất rơi đúng chỗ', () => {
    const x = synthesize(['#'], { fs: FS, volume: 0.8, rowBoostDb: 3 });
    const s = amplitudeSpectrum(x, FS, 2000, 1);
    expect(s.f.length).toBe(2001);
    let best = 0;
    s.A.forEach((a, i) => {
      if (a > s.A[best]) best = i;
    });
    expect(s.f[best]).toBe(941);
  });
});
