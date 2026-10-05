// Tổng đài tự động của điện thoại mô phỏng: cây menu và cách xử lý từng phím.
// Kết quả tra cứu là dữ liệu mẫu tính từ chính dãy số, không lấy từ hệ thống
// thật nào.

export type NodeId =
  | 'goc'
  | 'dao_tao'
  | 'lich_thi'
  | 'dang_ky'
  | 'tra_diem'
  | 'tra_diem_kq'
  | 'hoc_phi'
  | 'tu_van';

interface MenuNode {
  ten: string;
  loi: string;
  kieu: 'menu';
  phim: [string, NodeId][];
}

interface InputNode {
  ten: string;
  loi: string;
  kieu: 'nhap';
  soChuSo: number;
  ve: NodeId;
  sau: NodeId;
  traLoi: (so: string) => string;
}

export type IvrNode = MenuNode | InputNode;

/** Câu trả lời mẫu: điểm suy ra từ chính các chữ số, cùng mã luôn cùng điểm. */
function traLoiDiem(so: string): string {
  const tong = [...so].reduce((a, c) => a + Number(c), 0);
  const diem = 2 + ((tong * 37) % 200) / 100;
  return `Mã sinh viên ${so}: điểm trung bình tích lũy ${diem.toFixed(2)}/4 (dữ liệu mẫu).`;
}

export const MENU: Record<NodeId, IvrNode> = {
  goc: {
    ten: 'Menu chính',
    loi:
      'Xin chào, đây là tổng đài tự động. Bấm 1 gặp Phòng Đào tạo, bấm 2 tra cứu điểm, ' +
      'bấm 3 nghe thông tin học phí, bấm 0 gặp tư vấn viên, bấm * để nghe lại.',
    kieu: 'menu',
    phim: [
      ['1', 'dao_tao'],
      ['2', 'tra_diem'],
      ['3', 'hoc_phi'],
      ['0', 'tu_van'],
      ['*', 'goc'],
    ],
  },
  dao_tao: {
    ten: 'Phòng Đào tạo',
    loi: 'Phòng Đào tạo. Bấm 1 nghe lịch thi, bấm 2 nghe hướng dẫn đăng ký học phần, bấm * để quay lại.',
    kieu: 'menu',
    phim: [
      ['1', 'lich_thi'],
      ['2', 'dang_ky'],
      ['*', 'goc'],
    ],
  },
  lich_thi: {
    ten: 'Lịch thi',
    loi: 'Lịch thi học kỳ được công bố trên cổng thông tin sinh viên trước ngày thi ba tuần. Bấm * để quay lại.',
    kieu: 'menu',
    phim: [['*', 'dao_tao']],
  },
  dang_ky: {
    ten: 'Đăng ký học phần',
    loi: 'Đăng ký học phần mở theo lịch của từng khóa, thao tác trên cổng thông tin sinh viên. Bấm * để quay lại.',
    kieu: 'menu',
    phim: [['*', 'dao_tao']],
  },
  tra_diem: {
    ten: 'Tra cứu điểm',
    loi: 'Nhập mã sinh viên gồm 8 chữ số, kết thúc bằng phím #. Bấm * để hủy.',
    kieu: 'nhap',
    soChuSo: 8,
    ve: 'goc',
    sau: 'tra_diem_kq',
    traLoi: traLoiDiem,
  },
  tra_diem_kq: {
    ten: 'Kết quả tra cứu',
    loi: 'Bấm 2 để tra mã khác, bấm * để về menu chính.',
    kieu: 'menu',
    phim: [
      ['2', 'tra_diem'],
      ['*', 'goc'],
    ],
  },
  hoc_phi: {
    ten: 'Học phí',
    loi: 'Học phí học kỳ tính theo số tín chỉ đã đăng ký; hạn nộp ghi trên cổng thông tin sinh viên. Bấm * để quay lại.',
    kieu: 'menu',
    phim: [['*', 'goc']],
  },
  tu_van: {
    ten: 'Tư vấn viên',
    loi: 'Đang chuyển máy tới tư vấn viên, xin giữ máy. Bấm * để quay lại.',
    kieu: 'menu',
    phim: [['*', 'goc']],
  },
};

export interface IvrState {
  nut: NodeId;
  /** Các chữ số đang nhập. */
  dem: string;
  /** Lời nhắc đang hiện. */
  loi: string;
  /** Các bước đã đi, cũ trước mới sau: "phím  →  tên nút". */
  lichSu: string[];
}

/** Trạng thái đầu: nút gốc, lời chào. */
export function ivrStart(): IvrState {
  return { nut: 'goc', dem: '', loi: MENU.goc.loi, lichSu: [] };
}

function sangNut(st: IvrState, dich: NodeId, phim: string): IvrState {
  return { nut: dich, dem: '', loi: MENU[dich].loi, lichSu: [...st.lichSu, `${phim}  →  ${MENU[dich].ten}`] };
}

/** Một phím vào, trạng thái mới và câu phản hồi ra. */
export function ivrStep(st: IvrState, phim: string): { st: IvrState; phanHoi: string } {
  const nut = MENU[st.nut];

  if (nut.kieu === 'menu') {
    const hit = nut.phim.find(([p]) => p === phim);
    if (!hit) {
      const phanHoi = `Phím ${phim} không hợp lệ. ${nut.loi}`;
      return { st: { ...st, loi: phanHoi }, phanHoi };
    }
    const moi = sangNut(st, hit[1], phim);
    return { st: moi, phanHoi: moi.loi };
  }

  let phanHoi: string;
  let moi: IvrState = st;
  let conNhap = true;
  if ('0123456789'.includes(phim)) {
    const dem = st.dem + phim;
    if (dem.length > nut.soChuSo) {
      moi = { ...st, dem: '' };
      phanHoi = `Mã chỉ gồm ${nut.soChuSo} chữ số, mời nhập lại từ đầu.`;
    } else {
      moi = { ...st, dem };
      phanHoi = `Đã nhập ${dem.length}/${nut.soChuSo} chữ số.`;
    }
  } else if (phim === '#') {
    if (st.dem.length === nut.soChuSo) {
      const ketQua = nut.traLoi(st.dem);
      moi = sangNut(st, nut.sau, `${st.dem}#`);
      moi = { ...moi, loi: `${ketQua} ${moi.loi}` };
      phanHoi = moi.loi;
      conNhap = false;
    } else {
      phanHoi = `Mã phải đủ ${nut.soChuSo} chữ số, mới có ${st.dem.length}. Mời nhập lại từ đầu.`;
      moi = { ...st, dem: '' };
    }
  } else if (phim === '*') {
    moi = sangNut(st, nut.ve, phim);
    phanHoi = moi.loi;
    conNhap = false;
  } else {
    phanHoi = `Phím ${phim} không hợp lệ khi đang nhập mã.`;
  }

  if (conNhap) moi = { ...moi, loi: `${phanHoi} ${nut.loi}` };
  return { st: moi, phanHoi };
}

/** Gọi lặp ivrStep cho từng ký tự của một chuỗi. */
export function ivrKeys(st: IvrState, keys: string): { st: IvrState; phanHoi: string } {
  let r = { st, phanHoi: '' };
  for (const ch of keys) r = ivrStep(r.st, ch);
  return r;
}
