import { describe, expect, it } from 'vitest';
import { align, summary } from '../src/forensic/align';

const ops = (a: string, b: string) => align(a, b).cells.map((c) => c.op);

describe('đối chiếu số thật với số MATLAB đọc', () => {
  it('khớp hết', () => {
    expect(ops('0912', '0912')).toEqual(['dung', 'dung', 'dung', 'dung']);
    expect(summary(align('0912', '0912').cells)).toEqual({ ok: true, text: 'khớp cả 4 chữ số' });
  });

  it('một chữ số thừa, như ví dụ của dtmf_metrics', () => {
    const r = align('123', '1283');
    expect(r.editDist).toBe(1);
    expect(r.cells.map((c) => c.op)).toEqual(['dung', 'dung', 'thua', 'dung']);
  });

  it('tone bị cắt đôi: một lần bấm đọc thành hai chữ số', () => {
    // Truy vết từ cuối, chéo trước: chữ 9 SAU được ghép với số thật, chữ 9 trước là thừa.
    expect(ops('0912', '09912')).toEqual(['dung', 'thua', 'dung', 'dung', 'dung']);
    expect(summary(align('0912', '09912').cells).text).toBe('lệch 1: 1 thừa');
  });

  it('ưu tiên CHÉO trước như dtmf_metrics: 12 với 3 ghi 2 -> 3, sót 1', () => {
    const r = align('12', '3');
    expect(r.cells).toEqual([
      { that: '1', doc: '', op: 'sot' },
      { that: '2', doc: '3', op: 'nham' },
    ]);
  });

  it('MATLAB không đọc được gì', () => {
    expect(ops('59', '')).toEqual(['sot', 'sot']);
    expect(summary(align('59', '').cells).text).toBe('lệch 2: 2 sót');
  });
});
