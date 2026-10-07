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
import { LineClient, lineUrl, probeLine, type LineHandlers } from './line/line';
import { ModeSwitch } from './components/ModeSwitch';
import { Phone, type CallState, type Heard, type Link } from './components/Phone';
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
/** Đổ chuông bao lâu trước khi tổng đài trong trang nhấc máy [ms]. */
const RING_MS = 1500;
/** Chờ MATLAB nhấc máy tối đa bao lâu, quá thì tổng đài trong trang nhấc thay [ms]. */
const ANSWER_TIMEOUT_MS = 5000;

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

  // Đường dây sang tổng đài MATLAB. link: cuộc gọi hiện tại đi qua đâu.
  const line = useMemo(() => new LineClient(), []);
  const [link, setLink] = useState<Link>({ mode: 'off' });
  const [heard, setHeard] = useState<Heard | null>(null);
  const callToken = useRef(0);

  // Mọi thứ mà bộ nghe bàn phím, các hẹn giờ và tin của đường dây cần đọc đi
  // qua ref, để chúng không giữ giá trị cũ.
  const live = useRef({ volume, boostDb, call, ivr, link: link.mode });
  live.current = { volume, boostDb, call, ivr, link: link.mode };
  const holding = useRef<{ key: DtmfKey; t0: number } | null>(null);

  /** Một tone đã phát xong: trong cuộc gọi, tổng đài trên điện thoại đọc lại phím đó. */
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
      // Gọi qua MATLAB thì tổng đài chỉ đọc lại phím MATLAB nghe được, không theo
      // phím vừa bấm: bấm mà MATLAB không nghe ra thì tổng đài im lặng.
      if (live.current.link !== 'matlab') toIvr(key);
    },
    [player, toIvr],
  );

  const setLinkNow = (l: Link) => {
    live.current.link = l.mode;
    setLink(l);
  };

  /** Tổng đài nhấc máy: lời chào, đồng hồ cuộc gọi bắt đầu chạy. */
  const answer = () => {
    clearTimeout(ringTimer.current);
    const s = ivrStart();
    live.current.ivr = s;
    live.current.call = 'connected';
    setIvr(s);
    setCall('connected');
    setConnectedAt(Date.now());
  };

  /** Tổng đài trong trang nhấc máy sau ms, nếu cuộc gọi token vẫn đang đổ chuông. */
  const answerLocal = (token: number, ms: number) => {
    clearTimeout(ringTimer.current);
    ringTimer.current = window.setTimeout(() => {
      if (token === callToken.current && live.current.call === 'ringing') answer();
    }, ms);
  };

  /** Mất MATLAB giữa chừng: tổng đài trong trang làm tiếp, cuộc gọi không rớt. */
  const lineLost = () => {
    if (live.current.link !== 'matlab') return;
    line.close();
    setLinkNow({ mode: 'lost' });
    if (live.current.call === 'ringing') answerLocal(callToken.current, 300);
  };

  const onHangup = (notify = true) => {
    callToken.current++;
    clearTimeout(ringTimer.current);
    stopSeq();
    if (notify) line.send({ t: 'hangup' });
    line.close();
    setLinkNow({ mode: 'off' });
    setHeard(null);
    setTyped('');
    live.current.call = 'idle';
    setCall('idle');
    setIvr(ivrStart());
  };

  // Tin của đường dây tới bất cứ lúc nào; LineClient giữ một bộ xử lý cố định
  // trỏ vào bản mới nhất ở mỗi lần vẽ.
  const onLine = useRef<LineHandlers>({ onMsg: () => {}, onStatus: () => {}, onClose: () => {} });
  onLine.current = {
    onMsg: (m) => {
      if (live.current.link !== 'matlab') return;
      if (m.t === 'answer') {
        if (live.current.call === 'ringing') answer();
      } else if (m.t === 'key') {
        if (live.current.call !== 'connected' || !isKey(m.k)) return;
        toIvr(m.k);
        setHeard((h) => ({ key: m.k, n: (h?.n ?? 0) + 1 }));
      } else if (m.t === 'hangup') {
        onHangup(false);
      }
    },
    onStatus: (s) => {
      if (!s.matlab || s.app === 'forensic') lineLost();
    },
    onClose: lineLost,
  };
  const handlers = useMemo<LineHandlers>(
    () => ({
      onMsg: (m) => onLine.current.onMsg(m),
      onStatus: (s) => onLine.current.onStatus(s),
      onClose: () => onLine.current.onClose(),
    }),
    [],
  );

  const onCall = () => {
    player.ensure();
    setTyped('');
    setHeard(null);
    live.current.call = 'ringing';
    setCall('ringing');
    player.ring(1);
    const token = ++callToken.current;
    const t0 = performance.now();

    const url = IS_ARTIFACT ? null : lineUrl();
    if (!url) {
      setLinkNow({ mode: 'local' });
      answerLocal(token, RING_MS);
      return;
    }

    // Có cầu nối: hỏi MATLAB. MATLAB đang nối thì nó đổ chuông và tự nhấc máy;
    // không có thì tổng đài trong trang nhấc máy như khi không có đường dây.
    // Hỏi trạng thái trước khi mở WebSocket: mở là chiếm dây, nếu MATLAB đang
    // chạy màn giám định thì cuộc gọi sẽ cắt vụ của nó.
    setLinkNow({ mode: 'dialing' });
    void probeLine().then((pre) => {
      if (token !== callToken.current) return;
      if (pre?.matlab && pre.app === 'forensic') {
        setLinkNow({ mode: 'local', why: 'matlab' });
        answerLocal(token, Math.max(0, RING_MS - (performance.now() - t0)));
        return;
      }
      void goiMatlab(url, token, t0);
    });
  };

  const goiMatlab = (url: string, token: number, t0: number) => {
    void line.open(url, handlers).then((st) => {
      if (token !== callToken.current) return;
      if (!st?.matlab || st.app === 'forensic') {
        line.close();
        setLinkNow({ mode: 'local', why: st ? 'matlab' : 'bridge' });
        answerLocal(token, Math.max(0, RING_MS - (performance.now() - t0)));
        return;
      }
      setLinkNow({ mode: 'matlab', method: st.method });
      line.send({ t: 'call' });
      void line.startAudio(player);
      ringTimer.current = window.setTimeout(() => {
        if (token !== callToken.current || live.current.call !== 'ringing') return;
        line.send({ t: 'hangup' });
        line.close();
        setLinkNow({ mode: 'local', why: 'answer' });
        answer();
      }, ANSWER_TIMEOUT_MS);
    });
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
          if (live.current.link !== 'matlab') toIvr(p.key);
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
      line.close();
      player.close();
    },
    [stopSeq, line, player],
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
              link={link}
              heard={heard}
              onCall={onCall}
              onHangup={() => onHangup()}
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
            <div className="intro-acts">
              <ModeSwitch current="phone" />
              <button type="button" className="btn" aria-haspopup="dialog" onClick={() => setTools(true)}>
                Công cụ cho MATLAB
              </button>
            </div>
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
                  Bấm gọi khi DTMFLive đang mở: trang nối đường dây sang tổng đài MATLAB, gửi đúng tiếng nó phát ra loa, và
                  tổng đài đọc lại đúng phím MATLAB nghe được. Không có MATLAB thì tổng đài chạy ngay trong trang. Số gọi là mô
                  phỏng.
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
