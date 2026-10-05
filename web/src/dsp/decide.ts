// Luật quyết định của src/util/dtmf_decide.m, chép từng điều kiện và đúng thứ
// tự xét. Ngoài phán quyết, hàm trả thêm số đo của cả năm cửa để giao diện vẽ
// được vì sao một khung được nhận hay bị loại.

import { KEYS, type DtmfKey } from '../audio/dtmf';

export type Reject = 'none' | 'level' | 'twist' | 'harmonic';

export interface Thresholds {
  /** Đỉnh phải nổi hơn đỉnh nhì cùng nhóm ít nhất chừng này [dB]. */
  peakDb: number;
  /** Tỉ lệ năng lượng tối thiểu của 7 bin chuẩn. */
  energyRatio: number;
  /** Twist thuận tối đa, cột mạnh hơn hàng [dB]. */
  twistFwdDb: number;
  /** Twist nghịch tối đa, hàng mạnh hơn cột [dB]. */
  twistBwdDb: number;
}

export const DEFAULT_THR: Thresholds = { peakDb: 6, energyRatio: 0.7, twistFwdDb: 4, twistBwdDb: 8 };

export type GateId = 'row' | 'col' | 'twist' | 'energy' | 'harm';

export interface Gate {
  id: GateId;
  /** Số đo của cửa này. */
  value: number;
  /** true đạt, false trượt, null không xét vì một cửa trước đã trượt. */
  pass: boolean | null;
  /** Nhãn loại nếu trượt ở cửa này. */
  reject: Exclude<Reject, 'none'>;
}

export interface Decision {
  key: DtmfKey | null;
  /** Hàng 0..3 và cột 0..2 của hai đỉnh (kể cả khi khung bị loại). */
  rowArg: number;
  colArg: number;
  conf: number;
  reject: Reject;
  /** Khung không có năng lượng: bị loại trước cả năm cửa. */
  silent: boolean;
  rowPeak: number;
  colPeak: number;
  gates: Gate[];
}

/** E (8 giá trị) -> phím, hoặc lý do loại, theo đúng dtmf_decide.m. */
export function decide(E: readonly number[], thr: Thresholds = DEFAULT_THR): Decision {
  if (E.length !== 8) throw new Error(`E phải có 8 phần tử, nhận ${E.length}.`);

  const rowE = E.slice(0, 4);
  const colE = E.slice(4, 7);
  const argMax = (v: number[]) => v.reduce((b, x, i) => (x > v[b] ? i : b), 0);
  const rowArg = argMax(rowE);
  const colArg = argMax(colE);
  const rowPeak = rowE[rowArg];
  const colPeak = colE[colArg];

  const silent = !E.every(Number.isFinite) || E.some((e) => e < 0) || Math.max(...E) <= 0;

  // Đỉnh nhì phải lấy CÙNG NHÓM. x/0 cho Infinity: đạt, như MATLAB.
  const second = (v: number[]) => [...v].sort((a, b) => b - a)[1];
  const dRow = 10 * Math.log10(rowPeak / second(rowE));
  const dCol = 10 * Math.log10(colPeak / second(colE));
  const twist = 10 * Math.log10(colPeak / rowPeak);
  const rho = E.slice(0, 7).reduce((a, b) => a + b, 0);
  const harm = E[7] / Math.min(rowPeak, colPeak);

  // Viết ở dạng khẳng định như bản MATLAB: NaN làm điều kiện sai, tức trượt.
  const tests: [GateId, number, boolean, Gate['reject']][] = [
    ['row', dRow, dRow >= thr.peakDb, 'level'],
    ['col', dCol, dCol >= thr.peakDb, 'level'],
    ['twist', twist, twist >= -thr.twistBwdDb && twist <= thr.twistFwdDb, 'twist'],
    ['energy', rho, rho >= thr.energyRatio, 'level'],
    ['harm', harm, E[7] <= 0.5 * Math.min(rowPeak, colPeak), 'harmonic'],
  ];

  let failed = silent;
  let reject: Reject = silent ? 'level' : 'none';
  const gates = tests.map(([id, value, ok, rej]): Gate => {
    if (failed) return { id, value, pass: null, reject: rej };
    if (!ok) {
      failed = true;
      reject = rej;
    }
    return { id, value, pass: ok, reject: rej };
  });

  const accepted = reject === 'none';
  const conf = accepted ? Math.min(1, rho) * Math.min(1, Math.min(dRow, dCol) / (2 * thr.peakDb)) : 0;
  return {
    key: accepted ? KEYS[rowArg * 3 + colArg] : null,
    rowArg,
    colArg,
    conf,
    reject,
    silent,
    rowPeak,
    colPeak,
    gates,
  };
}
