// Lõi âm thanh DTMF - TypeScript thuần, không React.
//
// Hai đường ra cùng MỘT định nghĩa tín hiệu:
//   - DtmfPlayer phát ra loa bằng Web Audio (hai OscillatorNode sin).
//   - synthesize tính từng mẫu bằng công thức, dùng cho tệp WAV và cho test.
// Tần số, thời lượng tone/nghỉ, dốc biên độ, tỉ lệ hai nhóm đều lấy từ các
// hằng số và hàm dưới đây, nên hai đường không lệch nhau.

/** Tần số nhóm hàng [Hz], ITU-T Q.23 - khớp src/gen/dtmf_table.m. */
export const ROW_HZ = [697, 770, 852, 941] as const;
/** Tần số nhóm cột [Hz]. Bỏ cột 1633 Hz (phím A-D): đề tài chỉ dùng 12 phím. */
export const COL_HZ = [1209, 1336, 1477] as const;

/** 12 phím theo thứ tự hàng: hàng r, cột c ở vị trí 3*r + c. */
export const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'] as const;
export type DtmfKey = (typeof KEYS)[number];

/** Mặc định của dtmf_generate.m: tone 100 ms, nghỉ 50 ms. */
export const TONE_MS = 100;
export const PAUSE_MS = 50;

/** Dốc lên/xuống ở hai đầu mỗi tone [ms]. Cắt cụt biên độ sinh tiếng click
 *  băng rộng, đẩy năng lượng ra ngoài bảy bin và làm khung trượt luật
 *  energyRatio của dtmf_decide. */
export const RAMP_MS = 5;

export interface KeyInfo {
  key: DtmfKey;
  row: number;
  col: number;
  rowHz: number;
  colHz: number;
}

export function isKey(ch: string): ch is DtmfKey {
  return (KEYS as readonly string[]).includes(ch);
}

/** Hàng, cột và cặp tần số của một phím. */
export function keyInfo(key: DtmfKey): KeyInfo {
  const i = KEYS.indexOf(key);
  const row = Math.floor(i / 3);
  const col = i % 3;
  return { key, row, col, rowHz: ROW_HZ[row], colHz: COL_HZ[col] };
}

/** Chuỗi gõ vào -> danh sách phím hợp lệ, kèm các ký tự bị bỏ. */
export function parseKeys(text: string): { keys: DtmfKey[]; invalid: string[] } {
  const keys: DtmfKey[] = [];
  const invalid: string[] = [];
  for (const ch of text.replace(/\s+/g, '')) {
    if (isKey(ch)) keys.push(ch);
    else invalid.push(ch);
  }
  return { keys, invalid };
}

export interface ToneLevels {
  /** Biên độ tone hàng. */
  row: number;
  /** Biên độ tone cột. */
  col: number;
}

/**
 * Biên độ hai tone khi tổng đỉnh bằng `volume` và nhóm hàng được nâng
 * `rowBoostDb` dB so với nhóm cột.
 *
 * Bù loa: loa nhỏ làm 697-941 Hz yếu hơn nhóm cột nhiều dB (đo ở CONTRACTS
 * §7.9: 14-21 dB với loa laptop), nên tín hiệu tới micro lệch twist và
 * dtmf_decide loại khung (thuận tối đa 4 dB, nghịch tối đa 8 dB). Nâng nhóm
 * hàng trước khi phát là bù lại đúng chỗ đó. Tổng hai biên độ giữ bằng
 * `volume` để đỉnh tín hiệu không vượt 1, không méo.
 */
export function toneLevels(volume: number, rowBoostDb: number): ToneLevels {
  const ratio = Math.pow(10, rowBoostDb / 20); // row / col
  const col = volume / (1 + ratio);
  return { row: col * ratio, col };
}

export interface ScheduledTone {
  key: DtmfKey;
  /** Thời điểm bắt đầu [s], tính từ đầu chuỗi. */
  start: number;
  /** Thời điểm kết thúc [s]. */
  end: number;
}

/** Lịch phát một chuỗi: mỗi phím một tone, giữa hai phím một khoảng nghỉ. */
export function scheduleSequence(
  keys: readonly DtmfKey[],
  toneMs = TONE_MS,
  pauseMs = PAUSE_MS,
): ScheduledTone[] {
  const step = (toneMs + pauseMs) / 1000;
  return keys.map((key, i) => ({
    key,
    start: i * step,
    end: i * step + toneMs / 1000,
  }));
}

/** Tổng thời lượng của lịch phát [s]: không có khoảng nghỉ sau phím cuối. */
export function sequenceDuration(keys: readonly DtmfKey[], toneMs = TONE_MS, pauseMs = PAUSE_MS): number {
  return keys.length === 0 ? 0 : (keys.length * toneMs + (keys.length - 1) * pauseMs) / 1000;
}

/** Hệ số dốc tại mẫu n của một tone dài nTone mẫu: 0 -> 1 trong nRamp mẫu đầu,
 *  1 -> 0 trong nRamp mẫu cuối. */
function ramp(n: number, nTone: number, nRamp: number): number {
  if (nRamp <= 0) return 1;
  if (n < nRamp) return n / nRamp;
  if (n >= nTone - nRamp) return (nTone - 1 - n) / nRamp;
  return 1;
}

export interface SynthOptions {
  fs?: number;
  volume?: number;
  rowBoostDb?: number;
  toneMs?: number;
  pauseMs?: number;
}

/**
 * Tổng hợp chuỗi phím thành mẫu tín hiệu, cùng công thức với DtmfPlayer:
 *   x[n] = a_R sin(2π f_R n / fs) + a_C sin(2π f_C n / fs), nhân dốc hai đầu.
 * Độ dài đúng như dtmf_generate.m: K tone + (K-1) khoảng nghỉ.
 */
export function synthesize(keys: readonly DtmfKey[], opt: SynthOptions = {}): Float32Array {
  const fs = opt.fs ?? 8000;
  const toneMs = opt.toneMs ?? TONE_MS;
  const pauseMs = opt.pauseMs ?? PAUSE_MS;
  const lv = toneLevels(opt.volume ?? 0.8, opt.rowBoostDb ?? 0);

  const nTone = Math.round((toneMs / 1000) * fs);
  const nPause = Math.round((pauseMs / 1000) * fs);
  const nRamp = Math.round((RAMP_MS / 1000) * fs);
  const total = keys.length === 0 ? 0 : keys.length * nTone + (keys.length - 1) * nPause;
  const x = new Float32Array(total);

  keys.forEach((key, i) => {
    const { rowHz, colHz } = keyInfo(key);
    const off = i * (nTone + nPause);
    for (let n = 0; n < nTone; n++) {
      const t = n / fs;
      x[off + n] =
        ramp(n, nTone, nRamp) *
        (lv.row * Math.sin(2 * Math.PI * rowHz * t) + lv.col * Math.sin(2 * Math.PI * colHz * t));
    }
  });
  return x;
}

export interface PlayOptions {
  volume: number;
  rowBoostDb: number;
}

/** Số mẫu mỗi khối trích gửi về luồng chính: 1024 mẫu = 21 ms ở 48 kHz. */
const TAP_BLOCK = 1024;

/**
 * Worklet trích mẫu: gom từng khối 128 mẫu thành TAP_BLOCK mẫu rồi gửi về.
 * Lúc không phím nào kêu, đầu vào không có kênh nào - vẫn gửi mẫu 0, để bên
 * nhận thấy khoảng lặng thật giữa hai phím.
 */
const TAP_SRC = `
class DtmfTap extends AudioWorkletProcessor {
  constructor() { super(); this.buf = new Float32Array(${TAP_BLOCK}); this.n = 0; }
  process(inputs) {
    const ch = inputs[0] && inputs[0][0];
    const len = ch ? ch.length : 128;
    for (let i = 0; i < len; i++) {
      this.buf[this.n++] = ch ? ch[i] : 0;
      if (this.n === this.buf.length) {
        this.port.postMessage(this.buf, [this.buf.buffer]);
        this.buf = new Float32Array(${TAP_BLOCK});
        this.n = 0;
      }
    }
    return true;
  }
}
registerProcessor('dtmf-tap', DtmfTap);
`;

/** Nạp worklet từ một Blob: bản build một tệp không có tệp .js riêng để trỏ tới. */
async function loadTapWorklet(ctx: AudioContext): Promise<void> {
  const url = URL.createObjectURL(new Blob([TAP_SRC], { type: 'text/javascript' }));
  try {
    await ctx.audioWorklet.addModule(url);
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** Một tone đang kêu: hai oscillator và gain riêng của nó. */
interface Voice {
  oscs: OscillatorNode[];
  gain: GainNode;
  startedAt: number;
}

/**
 * Phát DTMF ra loa bằng Web Audio. AudioContext chỉ được dựng ở lần bấm đầu
 * (trình duyệt chỉ cho phát tiếng sau một thao tác của người dùng).
 * Mọi tone đi qua `analyser` để phần vẽ phổ đọc được.
 */
export class DtmfPlayer {
  private ctx: AudioContext | null = null;
  private out: GainNode | null = null;
  private voices = new Map<string, Voice>();
  private seqVoices: Voice[] = [];
  private tapReady: Promise<void> | null = null;
  analyser: AnalyserNode | null = null;

  /** Dựng AudioContext nếu chưa có, đánh thức nếu đang bị treo. */
  ensure(): AudioContext {
    if (!this.ctx) {
      const ctx = new AudioContext({ latencyHint: 'interactive' });
      const out = ctx.createGain();
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 4096;
      analyser.smoothingTimeConstant = 0.55;
      analyser.minDecibels = -110;
      analyser.maxDecibels = -10;
      out.connect(analyser);
      analyser.connect(ctx.destination);
      this.ctx = ctx;
      this.out = out;
      this.analyser = analyser;
    }
    if (this.ctx.state === 'suspended') void this.ctx.resume();
    return this.ctx;
  }

  get sampleRate(): number {
    return this.ctx?.sampleRate ?? 48000;
  }

  /** Đóng AudioContext khi trang rời đi; gọi lại ensure() sẽ dựng cái mới. */
  close(): void {
    const ctx = this.ctx;
    this.ctx = null;
    this.out = null;
    this.analyser = null;
    this.voices.clear();
    this.seqVoices = [];
    this.tapReady = null;
    void ctx?.close().catch(() => {});
  }

  /** Tạo một tone bắt đầu tại `t0` (giây theo đồng hồ AudioContext). */
  private voice(key: DtmfKey, t0: number, opt: PlayOptions): Voice {
    const ctx = this.ensure();
    const { rowHz, colHz } = keyInfo(key);
    const lv = toneLevels(opt.volume, opt.rowBoostDb);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0, t0);
    gain.gain.linearRampToValueAtTime(1, t0 + RAMP_MS / 1000);
    gain.connect(this.out!);

    const oscs = [
      [rowHz, lv.row],
      [colHz, lv.col],
    ].map(([f, a]) => {
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = f;
      const g = ctx.createGain();
      g.gain.value = a;
      osc.connect(g).connect(gain);
      osc.start(t0);
      return osc;
    });
    return { oscs, gain, startedAt: t0 };
  }

  /** Tắt một tone tại `t1`, có dốc xuống. */
  private release(v: Voice, t1: number): void {
    const r = RAMP_MS / 1000;
    v.gain.gain.setValueAtTime(1, t1);
    v.gain.gain.linearRampToValueAtTime(0, t1 + r);
    v.oscs.forEach((o) => o.stop(t1 + r + 0.005));
  }

  /** Nhấn giữ một phím: phát cho tới khi gọi stopKey. */
  startKey(key: DtmfKey, opt: PlayOptions): void {
    const ctx = this.ensure();
    this.stopKey(key);
    this.voices.set(key, this.voice(key, ctx.currentTime, opt));
  }

  /** Thả phím. Tone kêu ít nhất TONE_MS để bộ giải mã đủ hai khung. */
  stopKey(key: DtmfKey): void {
    const v = this.voices.get(key);
    if (!v || !this.ctx) return;
    this.voices.delete(key);
    const t1 = Math.max(this.ctx.currentTime, v.startedAt + TONE_MS / 1000 - RAMP_MS / 1000);
    this.release(v, t1);
  }

  /**
   * Phát cả chuỗi theo lịch scheduleSequence, hẹn giờ bằng đồng hồ âm thanh
   * nên khoảng 100/50 ms chính xác tới từng mẫu. Trả về thời điểm bắt đầu
   * theo performance.now() [ms] để phần vẽ bám theo.
   */
  playSequence(keys: readonly DtmfKey[], opt: PlayOptions): { startPerf: number; plan: ScheduledTone[] } {
    const ctx = this.ensure();
    this.stopSequence();
    const lead = 0.06;
    const t0 = ctx.currentTime + lead;
    const plan = scheduleSequence(keys);
    for (const p of plan) {
      const v = this.voice(p.key, t0 + p.start, opt);
      this.release(v, t0 + p.end - RAMP_MS / 1000);
      this.seqVoices.push(v);
    }
    return { startPerf: performance.now() + lead * 1000, plan };
  }

  /**
   * Hồi âm chuông khi đang gọi: một tone sin đơn 425 Hz. Một tone đơn không
   * bao giờ qua được luật hai nhóm của dtmf_decide, nên MATLAB nghe thấy
   * cũng không nhận nhầm thành phím.
   */
  ring(durationS = 1, hz = 425, level = 0.25): void {
    const ctx = this.ensure();
    const t0 = ctx.currentTime + 0.02;
    const r = 0.02;
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0, t0);
    gain.gain.linearRampToValueAtTime(level, t0 + r);
    gain.gain.setValueAtTime(level, t0 + durationS - r);
    gain.gain.linearRampToValueAtTime(0, t0 + durationS);
    gain.connect(this.out!);
    const osc = ctx.createOscillator();
    osc.frequency.value = hz;
    osc.connect(gain);
    osc.start(t0);
    osc.stop(t0 + durationS + 0.01);
  }

  /**
   * Trích tín hiệu đang phát ra loa, từng khối mẫu ở tần số của AudioContext,
   * kể cả khoảng lặng giữa hai phím. Dùng cho đường dây sang MATLAB. Trả về
   * hàm gỡ bỏ.
   *
   * AudioWorklet chỉ có trong ngữ cảnh an toàn (https, localhost); điện thoại
   * mở trang qua địa chỉ LAN http thì rơi về ScriptProcessorNode.
   */
  async tap(onBlock: (x: Float32Array) => void): Promise<() => void> {
    const ctx = this.ensure();
    const out = this.out!;
    let node: AudioNode;
    if (ctx.audioWorklet) {
      if (!this.tapReady) this.tapReady = loadTapWorklet(ctx);
      await this.tapReady;
      const w = new AudioWorkletNode(ctx, 'dtmf-tap', { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1] });
      w.port.onmessage = (e: MessageEvent<Float32Array>) => onBlock(e.data);
      node = w;
    } else {
      const sp = ctx.createScriptProcessor(1024, 1, 1);
      sp.onaudioprocess = (e) => onBlock(new Float32Array(e.inputBuffer.getChannelData(0)));
      node = sp;
    }
    // Nút trích phải nối tới loa thì mới được chạy; nó chỉ xuất mẫu 0.
    out.connect(node);
    node.connect(ctx.destination);
    return () => {
      try {
        out.disconnect(node);
      } catch {
        // đã gỡ sẵn
      }
      node.disconnect();
      if (node instanceof AudioWorkletNode) node.port.onmessage = null;
      else (node as ScriptProcessorNode).onaudioprocess = null;
    };
  }

  /** Dừng chuỗi đang phát. */
  stopSequence(): void {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    for (const v of this.seqVoices) {
      v.gain.gain.cancelScheduledValues(now);
      v.gain.gain.setValueAtTime(0, now);
      v.oscs.forEach((o) => {
        try {
          o.stop(now + 0.01);
        } catch {
          // đã dừng sẵn
        }
      });
    }
    this.seqVoices = [];
  }
}
