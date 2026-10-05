import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  DtmfPlayer,
  isKey,
  keyInfo,
  parseKeys,
  sequenceDuration,
  synthesize,
  toneLevels,
  type DtmfKey,
  type KeyInfo,
} from './audio/dtmf';
import { encodeWav } from './audio/wav';
import { ivrStart, ivrStep, type IvrState } from './ivr/ivr';
import { Phone, type CallState } from './components/Phone';
import { SequencePlayer } from './components/SequencePlayer';
import { Settings } from './components/Settings';
import { Stage } from './components/Stage';
import { Story } from './components/Story';
import { Icon } from './components/ui';

/** Bản phát hành Artifact: trình xem chặn tải tệp, nên ẩn nút Tải WAV. */
const IS_ARTIFACT = import.meta.env.MODE === 'artifact';

/** Tone trên hình dài bằng thời gian nhấn giữ, kẹp trong khoảng này [ms]. */
const MIN_TONE_MS = 100;
const MAX_TONE_MS = 400;
/** Đổ chuông bao lâu trước khi tổng đài nhấc máy [ms]. */
const RING_MS = 1500;

/** Phím đang vẽ ở bên phải, với độ dài tone của lần bấm đó. */
interface Shown {
  key: DtmfKey;
  toneMs: number;
}

export function App() {
  const player = useMemo(() => new DtmfPlayer(), []);
  const [volume, setVolume] = useState(0.8);
  const [boostDb, setBoostDb] = useState(0);
  const [active, setActive] = useState<KeyInfo | null>(null);

  const [call, setCall] = useState<CallState>('idle');
  const [connectedAt, setConnectedAt] = useState(0);
  const [ivr, setIvr] = useState<IvrState>(ivrStart);
  const [typed, setTyped] = useState('');
  const [tools, setTools] = useState(false);
  const [shown, setShown] = useState<Shown>({ key: '5', toneMs: MIN_TONE_MS });

  const [seq, setSeq] = useState('0912345');
  const [seqIdx, setSeqIdx] = useState(-1);
  const [seqPlaying, setSeqPlaying] = useState(false);
  const timers = useRef<number[]>([]);
  const ringTimer = useRef(0);

  // Mọi thứ mà bộ nghe bàn phím và các hẹn giờ cần đọc đi qua ref, để chúng
  // không giữ giá trị cũ.
  const live = useRef({ volume, boostDb, call, ivr });
  live.current = { volume, boostDb, call, ivr };
  const holding = useRef<{ key: DtmfKey; t0: number } | null>(null);

  /** Một tone đã phát xong: trong cuộc gọi, menu trên điện thoại đi theo phím đó. */
  const toIvr = useCallback((key: DtmfKey) => {
    if (live.current.call !== 'connected') return;
    const st = ivrStep(live.current.ivr, key).st;
    live.current.ivr = st;
    setIvr(st);
  }, []);

  /** Bắt đầu vẽ một phím mới ở bên phải. */
  const showKey = (key: DtmfKey) => setShown({ key, toneMs: MIN_TONE_MS });

  const stopSeq = useCallback(() => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
    player.stopSequence();
    setSeqIdx(-1);
    setSeqPlaying(false);
  }, [player]);

  /** Trong cuộc gọi, phím vừa bấm hiện lên đầu màn hình như điện thoại thật. */
  const typeKey = (key: DtmfKey) => {
    if (live.current.call !== 'idle') setTyped((s) => s + key);
  };

  const onPress = useCallback(
    (key: DtmfKey) => {
      stopSeq();
      player.startKey(key, { volume: live.current.volume, rowBoostDb: live.current.boostDb });
      holding.current = { key, t0: performance.now() };
      setActive(keyInfo(key));
      typeKey(key);
      showKey(key);
    },
    [player, stopSeq],
  );

  const onRelease = useCallback(
    (key: DtmfKey) => {
      player.stopKey(key);
      setActive((a) => (a?.key === key ? null : a));
      const h = holding.current;
      if (!h || h.key !== key) return;
      holding.current = null;
      const held = Math.round(Math.min(MAX_TONE_MS, Math.max(MIN_TONE_MS, performance.now() - h.t0)));
      setShown((s) => (s.key === key ? { ...s, toneMs: held } : s));
      toIvr(key);
    },
    [player, toIvr],
  );

  const onCall = () => {
    player.ensure();
    setTyped('');
    setCall('ringing');
    player.ring(1);
    ringTimer.current = window.setTimeout(() => {
      const s = ivrStart();
      live.current.ivr = s;
      setIvr(s);
      setCall('connected');
      setConnectedAt(Date.now());
    }, RING_MS);
  };

  const onHangup = () => {
    clearTimeout(ringTimer.current);
    stopSeq();
    setTyped('');
    setCall('idle');
    setIvr(ivrStart());
  };

  const playSeq = () => {
    const { keys } = parseKeys(seq);
    if (keys.length === 0) return;
    stopSeq();
    const { startPerf, plan } = player.playSequence(keys, { volume, rowBoostDb: boostDb });
    setSeqPlaying(true);

    // Âm thanh đã hẹn giờ chính xác trên đồng hồ của AudioContext; setTimeout
    // ở đây chỉ để tô sáng và để tổng đài nhận từng phím khi tone của nó tắt.
    const base = startPerf - performance.now();
    plan.forEach((p, i) => {
      timers.current.push(
        window.setTimeout(() => {
          setActive(keyInfo(p.key));
          setSeqIdx(i);
          typeKey(p.key);
          showKey(p.key);
        }, base + p.start * 1000),
        window.setTimeout(() => {
          setActive(null);
          toIvr(p.key);
        }, base + p.end * 1000),
      );
    });
    timers.current.push(
      window.setTimeout(() => {
        setSeqIdx(-1);
        setSeqPlaying(false);
      }, base + sequenceDuration(keys) * 1000 + 30),
    );
  };

  const taiWav = () => {
    const { keys } = parseKeys(seq);
    const fs = 8000;
    const x = synthesize(keys, { fs, volume, rowBoostDb: boostDb });
    const blob = new Blob([encodeWav(x, fs)], { type: 'audio/wav' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `dtmf_${keys.join('').replace(/\*/g, 's').replace(/#/g, 'h')}.wav`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  };

  // Bàn phím máy tính: 0-9, * và # như bấm trên điện thoại. Bỏ qua khi đang gõ
  // trong ô nhập, và bỏ qua lặp phím do giữ lâu.
  useEffect(() => {
    const trongO = (e: KeyboardEvent) =>
      e.target instanceof Element && e.target.closest('input, textarea') !== null;
    const down = (e: KeyboardEvent) => {
      if (e.repeat || trongO(e) || !isKey(e.key)) return;
      onPress(e.key);
    };
    const up = (e: KeyboardEvent) => {
      if (isKey(e.key)) onRelease(e.key);
    };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup', up);
    return () => {
      window.removeEventListener('keydown', down);
      window.removeEventListener('keyup', up);
    };
  }, [onPress, onRelease]);

  useEffect(() => {
    if (!tools) return;
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setTools(false);
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [tools]);

  useEffect(
    () => () => {
      stopSeq();
      clearTimeout(ringTimer.current);
    },
    [stopSeq],
  );

  return (
    <Stage>
      <div className="split">
        <aside className="side-phone" aria-label="Điện thoại">
          <div className="side-top">
            <span className="brand">
              <span className="brand-mark" aria-hidden="true">
                <i />
                <i />
              </span>
              DTMF
            </span>
            <span className="mono muted">ITU-T Q.23 · 8 kHz</span>
          </div>
          <div className="phone-wrap">
            <Phone
              call={call}
              connectedAt={connectedAt}
              ivr={ivr}
              typed={typed}
              active={active}
              onCall={onCall}
              onHangup={onHangup}
              onPress={onPress}
              onRelease={onRelease}
            />
          </div>
        </aside>

        <main className="side-content">
          <header className="intro">
            <div>
              <p className="eyebrow">Xử lý tín hiệu số · Chủ đề 4</p>
              <h1>Tín hiệu DTMF trong miền thời gian và miền tần số</h1>
              <p className="lede">Mỗi phím là tổng của hai sóng sin, nên phổ của nó có đúng hai đỉnh.</p>
            </div>
            <button type="button" className="btn" aria-haspopup="dialog" onClick={() => setTools(true)}>
              Công cụ cho MATLAB
            </button>
          </header>

          <Story
            info={keyInfo(shown.key)}
            levels={toneLevels(volume, boostDb)}
            volume={volume}
            boostDb={boostDb}
            toneMs={shown.toneMs}
          />

        </main>
      </div>

      {tools && (
        <>
          <div className="drawer-bg" onClick={() => setTools(false)} />
          <div className="drawer" role="dialog" aria-modal="true" aria-labelledby="cong-cu-h">
            <header className="drawer-head">
              <div>
                <h2 id="cong-cu-h">Công cụ cho MATLAB</h2>
                <p>
                  Khi trình diễn thật, MATLAB nghe tiếng của trang qua micro ở chế độ Giải mã trực tiếp của DTMFApp. Số gọi
                  là mô phỏng, điểm tra cứu là dữ liệu mẫu.
                </p>
              </div>
              <button type="button" className="icon-btn" aria-label="Đóng" onClick={() => setTools(false)}>
                <Icon name="x" />
              </button>
            </header>
            <section>
              <SequencePlayer
                value={seq}
                onChange={setSeq}
                onPlay={playSeq}
                onStop={stopSeq}
                playing={seqPlaying}
                current={seqIdx}
                onDownload={IS_ARTIFACT ? undefined : taiWav}
              />
            </section>
            <section>
              <Settings volume={volume} boostDb={boostDb} onVolume={setVolume} onBoost={setBoostDb} />
            </section>
          </div>
        </>
      )}
    </Stage>
  );
}
