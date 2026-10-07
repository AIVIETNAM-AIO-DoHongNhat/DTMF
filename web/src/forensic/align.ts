// Căn chỉnh số thật với số MATLAB đọc được để tô từng chữ số - cùng phép
// Levenshtein và cùng thứ tự ưu tiên CHÉO > XÓA > CHÈN như src/util/dtmf_metrics.m,
// nên trang và màn MATLAB tô giống hệt nhau.

export type Op = 'dung' | 'nham' | 'sot' | 'thua';

export interface Cell {
  /** Chữ số thật, '' khi MATLAB đọc thừa. */
  that: string;
  /** Chữ số MATLAB đọc, '' khi bỏ sót. */
  doc: string;
  op: Op;
}

export function align(that: string, doc: string): { cells: Cell[]; editDist: number } {
  const K = that.length;
  const L = doc.length;
  const D: number[][] = Array.from({ length: K + 1 }, (_, i) => Array.from({ length: L + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0)));
  for (let i = 1; i <= K; i++) {
    for (let j = 1; j <= L; j++) {
      D[i][j] = Math.min(D[i - 1][j] + 1, D[i][j - 1] + 1, D[i - 1][j - 1] + (that[i - 1] === doc[j - 1] ? 0 : 1));
    }
  }
  const cells: Cell[] = [];
  let i = K;
  let j = L;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && D[i][j] === D[i - 1][j - 1] + (that[i - 1] === doc[j - 1] ? 0 : 1)) {
      cells.push({ that: that[i - 1], doc: doc[j - 1], op: that[i - 1] === doc[j - 1] ? 'dung' : 'nham' });
      i--;
      j--;
    } else if (i > 0 && D[i][j] === D[i - 1][j] + 1) {
      cells.push({ that: that[i - 1], doc: '', op: 'sot' });
      i--;
    } else {
      cells.push({ that: '', doc: doc[j - 1], op: 'thua' });
      j--;
    }
  }
  return { cells: cells.reverse(), editDist: D[K][L] };
}

/** Một câu tóm tắt: "khớp cả 10 chữ số" hoặc "lệch 2: 1 nhầm, 1 sót". */
export function summary(cells: readonly Cell[]): { ok: boolean; text: string } {
  const n = (op: Op) => cells.filter((c) => c.op === op).length;
  const sai = [
    [n('nham'), 'nhầm'],
    [n('sot'), 'sót'],
    [n('thua'), 'thừa'],
  ].filter(([c]) => (c as number) > 0);
  if (sai.length === 0) return { ok: true, text: `khớp cả ${n('dung')} chữ số` };
  const tong = sai.reduce((a, [c]) => a + (c as number), 0);
  return { ok: false, text: `lệch ${tong}: ${sai.map(([c, t]) => `${c} ${t}`).join(', ')}` };
}
