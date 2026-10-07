// Tổng đài thử nghiệm của điện thoại mô phỏng: chào một lần, rồi đọc lại từng
// phím nhận được. Không có menu, phím nào kể cả * và # cũng chỉ được đọc lại.
// Lời thoại khớp kịch bản thu âm docs/kich_ban_thu_am_tong_dai.docx.

import type { DtmfKey } from '../audio/dtmf';

export type NodeId = 'chao' | 'doc';

/** Lời chào, phát một lần khi cuộc gọi vừa kết nối. */
export const LOI_CHAO =
  'Học viện An ninh nhân dân xin chào. Đây là tổng đài thử nghiệm giải mã tín hiệu DTMF. ' +
  'Mời bạn bấm một phím bất kỳ, tổng đài sẽ đọc lại phím vừa nhận được.';

/** Cách đọc tên từng phím. */
export const TEN_PHIM: Record<DtmfKey, string> = {
  '0': 'không',
  '1': 'một',
  '2': 'hai',
  '3': 'ba',
  '4': 'bốn',
  '5': 'năm',
  '6': 'sáu',
  '7': 'bảy',
  '8': 'tám',
  '9': 'chín',
  '*': 'sao',
  '#': 'thăng',
};

/** Tên tệp thu âm sẽ dùng cho lời chào và câu đọc lại phím. */
export const WAV_CHAO = '01_chao.wav';
export const WAV_NHAN_PHIM = '02_nhan_phim.wav';
export function wavPhim(k: DtmfKey): string {
  return `phim_${k === '*' ? 'sao' : k === '#' ? 'thang' : k}.wav`;
}

/** Tên hiện trên tiêu đề phụ đề. */
export const TEN_NUT: Record<NodeId, string> = { chao: 'Lời chào', doc: 'Đọc lại phím' };

export interface IvrState {
  nut: NodeId;
  /** Các phím đã nhận, theo thứ tự. */
  dem: string;
  /** Lời đang hiện ở phụ đề. */
  loi: string;
  /** Các bước đã đi, cũ trước mới sau: "phím  →  tên phím". */
  lichSu: string[];
}

/** Trạng thái đầu: lời chào. */
export function ivrStart(): IvrState {
  return { nut: 'chao', dem: '', loi: LOI_CHAO, lichSu: [] };
}

/** Một phím vào, trạng thái mới và câu phản hồi ra. */
export function ivrStep(st: IvrState, phim: DtmfKey): { st: IvrState; phanHoi: string } {
  const ten = TEN_PHIM[phim];
  const phanHoi = `Tổng đài nhận được phím ${ten}.`;
  return {
    st: { nut: 'doc', dem: st.dem + phim, loi: phanHoi, lichSu: [...st.lichSu, `${phim}  →  ${ten}`] },
    phanHoi,
  };
}

/** Gọi lặp ivrStep cho từng ký tự của một chuỗi phím. */
export function ivrKeys(st: IvrState, keys: string): { st: IvrState; phanHoi: string } {
  let r = { st, phanHoi: '' };
  for (const ch of keys) r = ivrStep(r.st, ch as DtmfKey);
  return r;
}
