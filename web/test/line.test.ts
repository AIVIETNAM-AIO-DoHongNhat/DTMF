import { describe, expect, it } from 'vitest';
import { synthesize } from '../src/audio/dtmf';
import { Resampler, lineUrl, toInt16 } from '../src/line/line';
import { LINE_FS, parseToPhone } from '../src/line/protocol';

/** sin tần số f, lấy mẫu fs, n mẫu. */
function sine(f: number, fs: number, n: number): Float32Array {
  return Float32Array.from({ length: n }, (_, i) => Math.sin((2 * Math.PI * f * i) / fs));
}

/** Đổi cả tín hiệu x thành từng khối dài `block` qua cùng một Resampler. */
function resampleInBlocks(x: Float32Array, fsIn: number, block: number): Float32Array {
  const r = new Resampler(fsIn);
  const parts: Float32Array[] = [];
  for (let i = 0; i < x.length; i += block) parts.push(r.push(x.subarray(i, i + block)));
  const out = new Float32Array(parts.reduce((a, p) => a + p.length, 0));
  let k = 0;
  for (const p of parts) {
    out.set(p, k);
    k += p.length;
  }
  return out;
}

describe('đường dây: đổi tần số lấy mẫu', () => {
  for (const fsIn of [48000, 44100]) {
    it(`${fsIn} Hz -> 8000 Hz giữ đúng tone 1477 Hz, sai số trong cận nội suy tuyến tính`, () => {
      const y = resampleInBlocks(sine(1477, fsIn, fsIn), fsIn, 1024);
      // Một giây vào -> 8000 mẫu ra, lệch tối đa một mẫu ở mép.
      expect(Math.abs(y.length - LINE_FS)).toBeLessThanOrEqual(1);
      const ref = sine(1477, LINE_FS, y.length);
      let err = 0;
      for (let i = 0; i < y.length; i++) err = Math.max(err, Math.abs(y[i] - ref[i]));
      // Cận sai số của nội suy tuyến tính cho sin biên độ 1: (2πf/fs)²/8.
      expect(err).toBeLessThan(((2 * Math.PI * 1477) / fsIn) ** 2 / 8);
    });
  }

  it('chia khối kiểu gì cũng cho cùng kết quả', () => {
    const x = synthesize(['5', '9'], { fs: 48000 });
    const a = resampleInBlocks(x, 48000, 128);
    const b = resampleInBlocks(x, 48000, 1000);
    const c = resampleInBlocks(x, 48000, x.length);
    expect(a.length).toBe(c.length);
    expect(b.length).toBe(c.length);
    for (let i = 0; i < c.length; i++) {
      expect(a[i]).toBeCloseTo(c[i], 6);
      expect(b[i]).toBeCloseTo(c[i], 6);
    }
  });

  // Dốc 5 ms của synthesize rời rạc theo từng tần số lấy mẫu, nên mép tone
  // ở 48 kHz và ở 8 kHz lệch nhau tới một mẫu 8 kHz của dốc: 0.8/40 = 0.02.
  it('48 kHz -> 8 kHz khớp tổng hợp trực tiếp ở 8 kHz', () => {
    const y = resampleInBlocks(synthesize(['1', '#'], { fs: 48000 }), 48000, 1024);
    const ref = synthesize(['1', '#'], { fs: LINE_FS });
    expect(y.length).toBe(ref.length);
    let err = 0;
    for (let i = 0; i < ref.length; i++) err = Math.max(err, Math.abs(y[i] - ref[i]));
    expect(err).toBeLessThan(0.025);
  });
});

describe('đường dây: định dạng', () => {
  it('int16 cắt phần vượt biên và làm tròn', () => {
    expect(Array.from(toInt16(Float32Array.from([0, 1, -1, 2, -2, 0.5])))).toEqual([
      0, 32767, -32767, 32767, -32767, 16384,
    ]);
  });

  it('địa chỉ WebSocket theo máy chủ của trang, không có khi mở tệp offline', () => {
    expect(lineUrl({ protocol: 'http:', host: 'localhost:5173' })).toBe('ws://localhost:5173/line');
    expect(lineUrl({ protocol: 'https:', host: 'a.b' })).toBe('wss://a.b/line');
    expect(lineUrl({ protocol: 'file:', host: '' })).toBeNull();
  });

  it('đọc tin tổng đài, bỏ tin hỏng', () => {
    expect(parseToPhone('{"t":"key","k":"5"}')).toEqual({ t: 'key', k: '5' });
    expect(parseToPhone('{"t":"answer"}')).toEqual({ t: 'answer' });
    expect(parseToPhone('{"t":"line","matlab":true,"method":"Goertzel"}')).toEqual({
      t: 'line',
      matlab: true,
      method: 'Goertzel',
    });
    expect(parseToPhone('{"t":"line"}')).toEqual({ t: 'line', matlab: false });
    expect(parseToPhone('{"t":"line","matlab":true,"app":"forensic"}')).toEqual({
      t: 'line',
      matlab: true,
      app: 'forensic',
    });
    expect(parseToPhone('{"t":"key","k":"55"}')).toBeNull();
    expect(parseToPhone('{"t":"lạ"}')).toBeNull();
    expect(parseToPhone('không phải json')).toBeNull();
  });

  it('đọc kết luận của MATLAB, cả khi jsonencode gói một bộ giải mã thành đối tượng', () => {
    const ba = '{"t":"verdict","keys":"0912","methods":[{"name":"Goertzel","keys":"0912","ms":3.2},' +
      '{"name":"FFT","keys":"091","ms":5},{"name":"Ngân hàng bộ lọc","keys":"0912","ms":11}]}';
    const m = parseToPhone(ba);
    expect(m).toEqual({
      t: 'verdict',
      keys: '0912',
      methods: [
        { name: 'Goertzel', keys: '0912', ms: 3.2 },
        { name: 'FFT', keys: '091', ms: 5 },
        { name: 'Ngân hàng bộ lọc', keys: '0912', ms: 11 },
      ],
    });
    expect(parseToPhone('{"t":"verdict","keys":"","methods":{"name":"FFT","keys":"","ms":1}}')).toEqual({
      t: 'verdict',
      keys: '',
      methods: [{ name: 'FFT', keys: '', ms: 1 }],
    });
    expect(parseToPhone('{"t":"verdict","methods":[]}')).toBeNull();
  });
});
