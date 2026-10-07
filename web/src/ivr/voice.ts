// Giọng của tổng đài: phát các câu đã thu âm theo kịch bản
// docs/kich_ban_thu_am_tong_dai.docx.
//
// Tiếng nối THẲNG ra loa (ctx.destination), không qua nút `out` của DtmfPlayer:
// lời tổng đài là chiều tổng đài -> điện thoại, nên không được lọt vào đường dây
// sang MATLAB (DtmfPlayer.tap đọc `out`) và không được hiện trên hình phổ của
// phím (analyser cũng nằm sau `out`).
//
// Tệp gốc: 24 kHz stereo, bị phần mềm thu chặt cụt về 0 ngay sau chữ cuối (nghe
// thành tiếng "khực"). Đã gộp một kênh, giãn mượt cho nền ồn chìm xuống, cắt
// lặng, kết thúc bằng dốc cosin 60-100 ms đặt TRƯỚC chỗ bị chặt, cân về RMS
// -14 dBFS (ngang tiếng phím) rồi ghi WAV PCM 16 kHz (~500 KB cả bộ). Không nén
// AAC/MP3: trình duyệt thiếu bộ giải mã (Chromium thuần, Windows bản N) sẽ im
// lặng mà không báo gì, còn WAV thì trình duyệt nào cũng giải mã được.
// Tên tệp khớp WAV_CHAO, WAV_NHAN_PHIM, wavPhim trong ivr.ts.

import chao from './voice/01_chao.wav';
import nhanPhim from './voice/02_nhan_phim.wav';
import p0 from './voice/phim_0.wav';
import p1 from './voice/phim_1.wav';
import p2 from './voice/phim_2.wav';
import p3 from './voice/phim_3.wav';
import p4 from './voice/phim_4.wav';
import p5 from './voice/phim_5.wav';
import p6 from './voice/phim_6.wav';
import p7 from './voice/phim_7.wav';
import p8 from './voice/phim_8.wav';
import p9 from './voice/phim_9.wav';
import pSao from './voice/phim_sao.wav';
import pThang from './voice/phim_thang.wav';
import type { DtmfKey } from '../audio/dtmf';
import { WAV_CHAO, WAV_NHAN_PHIM, wavPhim } from './ivr';

/** Tên tệp trong kịch bản -> địa chỉ tệp trong bản build. */
const URLS: Record<string, string> = {
  [WAV_CHAO]: chao,
  [WAV_NHAN_PHIM]: nhanPhim,
  [wavPhim('0')]: p0,
  [wavPhim('1')]: p1,
  [wavPhim('2')]: p2,
  [wavPhim('3')]: p3,
  [wavPhim('4')]: p4,
  [wavPhim('5')]: p5,
  [wavPhim('6')]: p6,
  [wavPhim('7')]: p7,
  [wavPhim('8')]: p8,
  [wavPhim('9')]: p9,
  [wavPhim('*')]: pSao,
  [wavPhim('#')]: pThang,
};

/** Nghỉ giữa "Tổng đài nhận được phím" và tên phím [s]. */
const GAP_S = 0.04;

export class VoicePlayer {
  /** Bản giải mã của từng tệp; AudioBuffer dùng lại được qua nhiều AudioContext. */
  private buffers = new Map<string, Promise<AudioBuffer | null>>();
  private playing: { src: AudioBufferSourceNode; gain: GainNode }[] = [];
  /** Tăng mỗi lần nói hoặc dừng: câu đang chờ giải mã mà đã bị thay thì bỏ. */
  private turn = 0;

  /** getCtx: AudioContext đang dùng cho tiếng phím (DtmfPlayer.ensure). */
  constructor(private getCtx: () => AudioContext) {}

  private load(name: string): Promise<AudioBuffer | null> {
    let p = this.buffers.get(name);
    if (!p) {
      const url = URLS[name];
      p = url
        ? fetch(url)
            .then((r) => r.arrayBuffer())
            .then((b) => this.getCtx().decodeAudioData(b))
            .catch((e: unknown) => {
              // Không ném: thiếu một câu thì tổng đài vẫn chạy, chỉ im câu đó.
              console.warn(`[tổng đài] không phát được ${name}:`, e);
              this.buffers.delete(name);
              return null;
            })
        : Promise.resolve(null);
      this.buffers.set(name, p);
    }
    return p;
  }

  /** Giải mã sẵn mọi câu, để câu đầu tiên không trễ. */
  preload(): void {
    for (const name of Object.keys(URLS)) void this.load(name);
  }

  /** Dừng câu đang nói (tổng đài ngắt lời khi người gọi bấm phím). */
  stop(): void {
    this.turn++;
    for (const { src, gain } of this.playing) {
      try {
        const now = src.context.currentTime;
        gain.gain.cancelScheduledValues(now);
        gain.gain.setValueAtTime(gain.gain.value, now);
        gain.gain.linearRampToValueAtTime(0, now + 0.02);
        src.stop(now + 0.03);
      } catch {
        // đã dừng sẵn, hoặc AudioContext đã đóng
      }
    }
    this.playing = [];
  }

  /** Nói lần lượt các tệp, thay câu đang nói. volume: 0..1. */
  async say(names: string[], volume: number): Promise<void> {
    this.stop();
    const me = this.turn;
    const bufs = await Promise.all(names.map((n) => this.load(n)));
    if (me !== this.turn) return;
    const ctx = this.getCtx();
    if (ctx.state === 'suspended') await ctx.resume().catch(() => {});
    if (me !== this.turn) return;
    let t = ctx.currentTime + 0.02;
    for (const b of bufs) {
      if (!b) continue;
      const src = ctx.createBufferSource();
      const gain = ctx.createGain();
      src.buffer = b;
      gain.gain.value = volume;
      src.connect(gain).connect(ctx.destination);
      src.start(t);
      const item = { src, gain };
      src.onended = () => {
        this.playing = this.playing.filter((x) => x !== item);
      };
      this.playing.push(item);
      t += b.duration + GAP_S;
    }
  }

  /** Lời chào khi tổng đài nhấc máy. */
  greet(volume: number): Promise<void> {
    return this.say([WAV_CHAO], volume);
  }

  /** "Tổng đài nhận được phím ..." */
  readBack(key: DtmfKey, volume: number): Promise<void> {
    return this.say([WAV_NHAN_PHIM, wavPhim(key)], volume);
  }
}
