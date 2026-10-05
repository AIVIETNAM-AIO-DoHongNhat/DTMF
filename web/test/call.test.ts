import { describe, expect, it } from 'vitest';
import { KEYS } from '../src/audio/dtmf';
import { reportMs, transmit, type ChannelParams, type PhoneParams } from '../src/dsp/channel';
import { debounce } from '../src/dsp/debounce';
import { MENU, ivrKeys, ivrStart, ivrStep, type NodeId } from '../src/ivr/ivr';

describe('tổng đài', () => {
  it('bắt đầu ở lời chào', () => {
    const st = ivrStart();
    expect(st.nut).toBe('goc');
    expect(st.loi).toContain('Bấm 1');
    expect(st.lichSu).toEqual([]);
  });

  it('đi xuống rồi quay lại, ghi lịch sử từng bước', () => {
    let st = ivrKeys(ivrStart(), '1').st;
    expect(st.nut).toBe('dao_tao');
    st = ivrKeys(st, '1').st;
    expect(st.nut).toBe('lich_thi');
    st = ivrKeys(st, '**').st;
    expect(st.nut).toBe('goc');
    expect(st.lichSu).toHaveLength(4);
    expect(st.lichSu[0]).toContain('Phòng Đào tạo');
  });

  it('phím lạ giữ nguyên nút và nhắc lại menu', () => {
    const { st, phanHoi } = ivrStep(ivrStart(), '9');
    expect(st.nut).toBe('goc');
    expect(phanHoi).toContain('không hợp lệ');
    expect(phanHoi).toContain('Bấm 1');
    expect(st.lichSu).toEqual([]);
  });

  it('tra cứu trả lời đúng mã vừa nhập, cùng mã cùng điểm', () => {
    const a = ivrKeys(ivrStart(), '220201234#');
    expect(a.st.nut).toBe('tra_diem_kq');
    expect(a.phanHoi).toContain('20201234');
    expect(a.phanHoi).toContain('dữ liệu mẫu');
    expect(a.st.lichSu.at(-1)).toContain('20201234#');
    expect(ivrKeys(a.st, '220201234#').phanHoi).toBe(a.phanHoi);
    expect(ivrKeys(a.st, '298765432#').phanHoi).not.toBe(a.phanHoi);
  });

  it('điểm mẫu tính như traLoiDiem: 2 + mod(37·Σ, 200)/100', () => {
    // Σ(20201234) = 14 -> 2 + mod(518, 200)/100 = 3.18
    expect(ivrKeys(ivrStart(), '220201234#').phanHoi).toContain('3.18/4');
  });

  it('mã thiếu hoặc thừa chữ số bị từ chối, bộ đệm xóa', () => {
    let r = ivrKeys(ivrStart(), '2123#');
    expect(r.st.nut).toBe('tra_diem');
    expect(r.phanHoi).toContain('8 chữ số');
    expect(r.st.dem).toBe('');
    r = ivrKeys(r.st, '123456789');
    expect(r.phanHoi).toContain('nhập lại');
    expect(r.st.dem).toBe('');
  });

  it('* hủy nhập và về menu chính', () => {
    const { st } = ivrKeys(ivrStart(), '2123*');
    expect(st.nut).toBe('goc');
    expect(st.dem).toBe('');
  });

  it('mọi nút đích đều tồn tại', () => {
    for (const nut of Object.values(MENU)) {
      const dich: NodeId[] = nut.kieu === 'menu' ? nut.phim.map(([, d]) => d) : [nut.ve, nut.sau];
      for (const d of dich) expect(MENU[d]).toBeDefined();
    }
  });
});

describe('gộp khung - khớp dtmf_debounce.m', () => {
  it('ví dụ trong help: [5 5 5 - 5 5 5] cho 55', () => {
    expect(debounce(['5', '5', '5', null, '5', '5', '5']).keys).toBe('55');
  });

  it('dải một khung không sinh ký tự', () => {
    const r = debounce([null, '1', null, '2', '2']);
    expect(r.keys).toBe('2');
    expect(r.runs.map((x) => x.kept)).toEqual([false, true]);
  });
});

describe('đường truyền', () => {
  const phone: PhoneParams = { volume: 0.8, rowBoostDb: 0, toneMs: 100 };
  const sach: ChannelParams = { distanceCm: 10, roomSnrDb: null, speakerLossDb: 0 };

  it('kênh sạch: mười hai phím đều tới nơi đúng một ký tự', () => {
    for (const key of KEYS) expect(transmit(key, phone, sach, 37, 1).decoded).toBe(key);
  });

  it('báo phím sau 45-75 ms, trước khi tone 100 ms tắt, ở mọi độ lệch lưới khung', () => {
    // Đo được 47.3-72.8 ms cho phím 5; CONTRACTS §7.9 ghi 49-74 ms với đoạn 50 mẫu.
    // Sớm nhất dưới 51.25 ms (= 2 khung) vì khung dính vài chục mẫu lặng đầu vẫn được nhận.
    const t = Array.from({ length: 205 }, (_, a) => reportMs(transmit('5', phone, sach, a, 1))!);
    expect(Math.min(...t)).toBeGreaterThan(45);
    expect(Math.max(...t)).toBeLessThan(75);
  });

  it('âm tới micro sau d / 343 m/s', () => {
    expect(transmit('5', phone, { ...sach, distanceCm: 34.3 }, 0, 1).delayMs).toBeCloseTo(1, 9);
  });

  it('loa nhỏ yếu nhóm hàng 12 dB thì trượt twist; bù loa 10 dB cứu lại', () => {
    const loa = { ...sach, speakerLossDb: 12 };
    const hong = transmit('5', phone, loa, 0, 1);
    expect(hong.decoded).toBe('');
    expect(hong.frames.some((f) => f.decision.reject === 'twist')).toBe(true);
    expect(transmit('5', { ...phone, rowBoostDb: 10 }, loa, 0, 1).decoded).toBe('5');
  });

  it('cùng tiếng ồn, đứng xa làm SNR tụt 20·log10(d/10) dB', () => {
    const gan = transmit('5', phone, { ...sach, roomSnrDb: 20 }, 0, 1);
    const xa = transmit('5', phone, { ...sach, roomSnrDb: 20, distanceCm: 100 }, 0, 1);
    expect(gan.snrDb).toBeCloseTo(20, 6);
    expect(gan.snrDb - xa.snrDb).toBeCloseTo(20, 6);
    expect(gan.decoded).toBe('5');
    expect(xa.decoded).toBe('');
  });
});
