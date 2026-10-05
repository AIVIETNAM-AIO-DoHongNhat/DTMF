// Phổ biên độ của một tone DTMF, để trang vẽ "phím thành phổ". Cửa sổ Hamming,
// chuẩn hóa 2|X(f)| / Σw nên đỉnh của một sóng sin đọc ra đúng biên độ của nó.
// Mỗi tần số tính bằng một vòng Goertzel, không cần FFT.

export interface Spectrum {
  /** Lưới tần số [Hz]. */
  f: Float64Array;
  /** Biên độ tại từng tần số. */
  A: Float64Array;
}

function windowed(x: Float32Array): { wx: Float64Array; sumW: number } {
  const N = x.length;
  const wx = new Float64Array(N);
  let sumW = 0;
  for (let n = 0; n < N; n++) {
    const w = N > 1 ? 0.54 - 0.46 * Math.cos((2 * Math.PI * n) / (N - 1)) : 1;
    wx[n] = w * x[n];
    sumW += w;
  }
  return { wx, sumW };
}

function amp(wx: Float64Array, sumW: number, f: number, fs: number): number {
  const coeff = 2 * Math.cos((2 * Math.PI * f) / fs);
  let s1 = 0;
  let s2 = 0;
  for (let n = 0; n < wx.length; n++) {
    const s = wx[n] + coeff * s1 - s2;
    s2 = s1;
    s1 = s;
  }
  const p = s1 * s1 + s2 * s2 - coeff * s1 * s2;
  return (2 * Math.sqrt(Math.max(0, p))) / sumW;
}

/** Biên độ tại đúng một tần số f [Hz]. */
export function amplitudeAt(x: Float32Array, fs: number, f: number): number {
  const { wx, sumW } = windowed(x);
  return amp(wx, sumW, f, fs);
}

/** Phổ biên độ trên lưới 0, df, 2df, ... tới fMax [Hz]. */
export function amplitudeSpectrum(x: Float32Array, fs: number, fMax: number, df: number): Spectrum {
  const { wx, sumW } = windowed(x);
  const K = Math.floor(fMax / df) + 1;
  const f = new Float64Array(K);
  const A = new Float64Array(K);
  for (let k = 0; k < K; k++) {
    f[k] = k * df;
    A[k] = amp(wx, sumW, f[k], fs);
  }
  return { f, A };
}
