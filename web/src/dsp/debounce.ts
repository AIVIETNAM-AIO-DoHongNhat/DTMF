// Gộp phán quyết từng khung thành phím - src/util/dtmf_debounce.m.
// Khung bị loại cắt dải; dải ngắn hơn minRun khung không sinh ký tự.

import type { DtmfKey } from '../audio/dtmf';

export interface Run {
  key: DtmfKey;
  /** Khung đầu và khung cuối của dải (chỉ số khung, tính cả hai đầu). */
  first: number;
  last: number;
  /** Dải đủ dài để sinh ký tự. */
  kept: boolean;
}

/** `perFrame[i]` là phím khung i nhận được, null nếu khung bị loại. */
export function debounce(perFrame: readonly (DtmfKey | null)[], minRun = 2): { keys: string; runs: Run[] } {
  const runs: Run[] = [];
  let i = 0;
  while (i < perFrame.length) {
    const k = perFrame[i];
    if (k === null) {
      i++;
      continue;
    }
    let j = i;
    while (j + 1 < perFrame.length && perFrame[j + 1] === k) j++;
    runs.push({ key: k, first: i, last: j, kept: j - i + 1 >= minRun });
    i = j + 1;
  }
  return { keys: runs.filter((r) => r.kept).map((r) => r.key).join(''), runs };
}
