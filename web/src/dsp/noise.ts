// Nhiễu trắng Gauss có hạt giống, chuẩn hóa theo SNR đúng như nhánh 'awgn'
// của src/gen/dtmf_addnoise.m: công suất tín hiệu lấy trung bình trên CẢ
// tín hiệu, kể cả khoảng lặng.

/** Bộ sinh số ngẫu nhiên đều trong [0, 1), tái lập được theo hạt giống. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** n mẫu Gauss chuẩn (Box-Muller). */
export function randn(n: number, seed: number): Float32Array {
  const rand = mulberry32(seed);
  const v = new Float32Array(n);
  for (let i = 0; i < n; i += 2) {
    const u1 = Math.max(rand(), 1e-12);
    const u2 = rand();
    const r = Math.sqrt(-2 * Math.log(u1));
    v[i] = r * Math.cos(2 * Math.PI * u2);
    if (i + 1 < n) v[i + 1] = r * Math.sin(2 * Math.PI * u2);
  }
  return v;
}

const meanSquare = (x: ArrayLike<number>) => {
  let s = 0;
  for (let i = 0; i < x.length; i++) s += x[i] * x[i];
  return x.length ? s / x.length : 0;
};

/** y = x + v, với v là nhiễu Gauss được nhân hệ số để đạt đúng snrDb. */
export function addAwgn(x: Float32Array, snrDb: number, seed: number): Float32Array {
  const v0 = randn(x.length, seed);
  const px = meanSquare(x);
  const pv0 = meanSquare(v0);
  const g = pv0 > 0 ? Math.sqrt(px / (pv0 * Math.pow(10, snrDb / 10))) : 0;
  const y = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) y[i] = x[i] + g * v0[i];
  return y;
}
