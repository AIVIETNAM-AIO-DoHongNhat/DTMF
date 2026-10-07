import { describe, expect, it } from 'vitest';
import { KEYS } from '../src/audio/dtmf';
import { reportMs, transmit, type ChannelParams, type PhoneParams } from '../src/dsp/channel';
import { debounce } from '../src/dsp/debounce';
import { LOI_CHAO, TEN_PHIM, WAV_CHAO, WAV_NHAN_PHIM, ivrKeys, ivrStart, ivrStep, wavPhim } from '../src/ivr/ivr';

describe('tổng đài', () => {
  it('bắt đầu ở lời chào, chưa nhận phím nào', () => {
    const st = ivrStart();
    expect(st.nut).toBe('chao');
    expect(st.loi).toBe(LOI_CHAO);
    expect(st.loi).toContain('Mời bạn bấm một phím bất kỳ');
    expect(st.dem).toBe('');
    expect(st.lichSu).toEqual([]);
  });

  it('đọc lại đúng tên từng phím, kể cả * và #', () => {
    for (const k of KEYS) {
      const { st, phanHoi } = ivrStep(ivrStart(), k);
      expect(phanHoi).toBe(`Tổng đài nhận được phím ${TEN_PHIM[k]}.`);
      expect(st.loi).toBe(phanHoi);
      expect(st.nut).toBe('doc');
    }
    expect(ivrStep(ivrStart(), '*').phanHoi).toContain('sao');
    expect(ivrStep(ivrStart(), '#').phanHoi).toContain('thăng');
  });

  it('không có menu: phím nào cũng chỉ được đọc lại, lời mới thay lời cũ', () => {
    const { st } = ivrKeys(ivrStart(), '1*#0');
    expect(st.dem).toBe('1*#0');
    expect(st.loi).toBe('Tổng đài nhận được phím không.');
    expect(st.lichSu).toEqual(['1  →  một', '*  →  sao', '#  →  thăng', '0  →  không']);
  });

  it('tên tệp thu âm khớp kịch bản', () => {
    expect(WAV_CHAO).toBe('01_chao.wav');
    expect(WAV_NHAN_PHIM).toBe('02_nhan_phim.wav');
    expect(KEYS.map(wavPhim)).toEqual([
      'phim_1.wav', 'phim_2.wav', 'phim_3.wav', 'phim_4.wav', 'phim_5.wav', 'phim_6.wav',
      'phim_7.wav', 'phim_8.wav', 'phim_9.wav', 'phim_sao.wav', 'phim_0.wav', 'phim_thang.wav',
    ]);
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
