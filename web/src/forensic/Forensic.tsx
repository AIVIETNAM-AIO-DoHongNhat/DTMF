// Màn giám định: thầy nhập một số điện thoại bí mật và chọn một hiện trường,
// trang dựng một đoạn ghi âm có người bấm số đó giữa tiếng ồn, rồi phát ra loa
// và gửi đúng các mẫu đó sang MATLAB (DTMFForensic). MATLAB chỉ nhận âm thanh.
// Nó đọc dần từng chữ số, kết luận khi hết đoạn ghi âm, và chỉ SAU đó trang
// mới cho công bố số thật để đối chiếu.
//
// Máy của thầy mở trang này qua mạng LAN (npm run dev:lan trên máy trình
// chiếu, rồi mở http://<địa chỉ máy đó>:5173/#giam-dinh), nên đường dây đi:
// trang (máy thầy) --WebSocket--> cầu nối (máy trình chiếu) --TCP--> MATLAB.

import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { isKey, parseKeys } from '../audio/dtmf';
import { LINE_FS, type LineStatus, type MethodResult, type SwitchMsg } from '../line/protocol';
import { LineClient, REPLACED, lineUrl, type LineHandlers } from '../line/line';
import { ModeSwitch } from '../components/ModeSwitch';
import { Stage } from '../components/Stage';
import { align, summary, type Cell } from './align';
import { Recording } from './Recording';
import { PRESETS, buildScene, randomPhone, type Preset, type Rhythm, type Scene } from './scene';

const IS_ARTIFACT = import.meta.env.MODE === 'artifact';

/** Độ dài số bí mật cho phép [phím]. */
const MIN_KEYS = 3;
const MAX_KEYS = 20;
/** Chờ kết luận của MATLAB tối đa bao lâu sau khi gửi xong [ms]. */
const VERDICT_TIMEOUT_MS = 8000;
/** Mỗi lần gửi bao nhiêu mili giây âm thanh lên đường dây. */
const TICK_MS = 40;

type Phase = 'soan' | 'gui' | 'cho' | 'kl' | 'cb';

/** Trạng thái đường dây như trang thấy. */
type Wire =
  | { k: 'offline' } // mở tệp offline / bản Artifact: không có cầu nối
  | { k: 'dang-noi' }
  | { k: 'khong-cau-noi' }
  | { k: 'nhuong' } // trang khác (điện thoại) vừa chiếm đường dây
  | { k: 'noi'; st: LineStatus };

/** Đường dây giữ suốt lúc mở trang, tự nối lại khi cầu nối khởi động lại. */
function useWire(onMsg: (m: SwitchMsg) => void) {
  const line = useMemo(() => new LineClient(), []);
  const [wire, setWire] = useState<Wire>(() => (IS_ARTIFACT || !lineUrl() ? { k: 'offline' } : { k: 'dang-noi' }));
  const msg = useRef(onMsg);
  msg.current = onMsg;
  const timer = useRef(0);
  const alive = useRef(true);
  // Mỗi lần nối một số thứ tự: kết quả của lần cũ (React StrictMode mở trang
  // hai lần) không được đặt trạng thái hay hẹn nối lại, kẻo đóng nhầm đường dây tốt.
  const gen = useRef(0);

  const connect = useCallback(() => {
    const url = IS_ARTIFACT ? null : lineUrl();
    if (!url) return;
    clearTimeout(timer.current);
    const me = ++gen.current;
    const retry = () => {
      if (alive.current && me === gen.current) timer.current = window.setTimeout(connect, 2000);
    };
    const h: LineHandlers = {
      onMsg: (m) => msg.current(m),
      onStatus: (st) => setWire({ k: 'noi', st }),
      onClose: (code) => {
        if (me !== gen.current) return;
        if (code === REPLACED) {
          setWire({ k: 'nhuong' });
          return;
        }
        setWire({ k: 'khong-cau-noi' });
        retry();
      },
    };
    void line.open(url, h).then((st) => {
      if (!alive.current || me !== gen.current) return;
      if (st) setWire({ k: 'noi', st });
      else {
        setWire({ k: 'khong-cau-noi' });
        retry();
      }
    });
  }, [line]);

  useEffect(() => {
    alive.current = true;
    connect();
    return () => {
      alive.current = false;
      clearTimeout(timer.current);
      line.close();
    };
  }, [connect, line]);

  return { line, wire, reconnect: connect };
}

function WireChip({ wire, onReconnect }: { wire: Wire; onReconnect: () => void }) {
  let cls = '';
  let text: ReactNode;
  switch (wire.k) {
    case 'offline':
      text = 'Không có đường dây · chỉ phát ra loa';
      break;
    case 'dang-noi':
      text = 'Đang tìm cầu nối…';
      break;
    case 'khong-cau-noi':
      text = 'Chưa thấy cầu nối · chạy npm run dev:lan';
      cls = 'warn';
      break;
    case 'nhuong':
      return (
        <span className="fx-chip warn">
          <i />
          Trang khác đang dùng đường dây
          <button type="button" className="fx-link" onClick={onReconnect}>
            nối lại
          </button>
        </span>
      );
    case 'noi': {
      const { matlab, app, method } = wire.st;
      if (!matlab) {
        text = 'Cầu nối sẵn sàng · MATLAB chưa nối';
        cls = 'warn';
      } else if (app !== 'forensic') {
        text = 'MATLAB đang mở tổng đài · cần mở DTMFForensic';
        cls = 'warn';
      } else {
        text = `MATLAB đang nghe${method ? ` · ${method}` : ''}`;
        cls = 'on';
      }
    }
  }
  return (
    <span className={`fx-chip ${cls}`}>
      <i />
      {text}
    </span>
  );
}

function Digits({ cells, row }: { cells: Cell[]; row: 'that' | 'doc' }) {
  return (
    <span className="fx-digits">
      {cells.map((c, i) => (
        <span key={i} className={`d ${c.op}`}>
          {(row === 'that' ? c.that : c.doc) || '·'}
        </span>
      ))}
    </span>
  );
}

const newSeed = () => Math.floor(Math.random() * 2 ** 31);

const RHYTHM_TEN: Record<Rhythm, string> = { may: 'Máy quay số', nguoi: 'Người bấm', voi: 'Bấm vội' };

/** Ba thông số của một mức, như "Người bấm · giọng nói −20 dB · SNR 20 dB". */
function presetParams(p: Preset): string {
  return [
    RHYTHM_TEN[p.rhythm],
    p.background === 'none' ? 'không giọng nói' : `giọng nói −${Math.abs(p.bgDb)} dB`,
    p.snrDb === null ? 'không nhiễu' : `SNR ${p.snrDb} dB`,
  ].join(' · ');
}

export function Forensic() {
  // ---------------------------------------------------------------- hồ sơ
  const [secret, setSecret] = useState('');
  const [show, setShow] = useState(false);
  /** Chỉ số trong PRESETS, 0 là dễ nhất; mặc định Quán cà phê. */
  const [level, setLevel] = useState(1);
  const [seed, setSeed] = useState(newSeed);

  const parsed = parseKeys(secret);
  const keys = parsed.keys;
  const valid = parsed.invalid.length === 0 && keys.length >= MIN_KEYS && keys.length <= MAX_KEYS;
  const secretStr = keys.join('');
  const preset = PRESETS[level];

  const scene = useMemo<Scene | null>(
    () => (valid ? buildScene({ keys, ...preset, seed }) : null),
    // keys là mảng mới mỗi lần vẽ; secretStr mang đúng nội dung của nó.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [valid, secretStr, preset, seed],
  );

  // ------------------------------------------------------------- vụ việc
  const [phase, setPhase] = useState<Phase>('soan');
  const [caseNo, setCaseNo] = useState(0);
  const [pos, setPos] = useState<number | null>(null);
  const [heard, setHeard] = useState('');
  const [verdict, setVerdict] = useState<{ keys: string; methods: MethodResult[] } | null>(null);
  const [late, setLate] = useState(false);
  const [sent, setSent] = useState<Scene | null>(null);
  const phaseRef = useRef(phase);
  phaseRef.current = phase;

  const onMsg = useCallback((m: SwitchMsg) => {
    const ph = phaseRef.current;
    if (m.t === 'key' && (ph === 'gui' || ph === 'cho') && isKey(m.k)) setHeard((h) => h + m.k);
    else if (m.t === 'verdict' && (ph === 'gui' || ph === 'cho')) {
      setVerdict({ keys: m.keys, methods: m.methods });
      setPhase('kl');
    }
  }, []);
  const { line, wire, reconnect } = useWire(onMsg);
  const matlab = wire.k === 'noi' && wire.st.matlab && wire.st.app === 'forensic';

  const ctxRef = useRef<AudioContext | null>(null);
  const play = useRef<{ timer: number; src: AudioBufferSourceNode } | null>(null);
  const lateTimer = useRef(0);

  const stopPlay = useCallback(() => {
    if (!play.current) return;
    clearInterval(play.current.timer);
    try {
      play.current.src.stop();
    } catch {
      // đã dừng
    }
    play.current = null;
    setPos(null);
  }, []);

  useEffect(
    () => () => {
      stopPlay();
      clearTimeout(lateTimer.current);
      void ctxRef.current?.close();
    },
    [stopPlay],
  );

  const waitVerdict = () => {
    setPhase('cho');
    lateTimer.current = window.setTimeout(() => setLate(true), VERDICT_TIMEOUT_MS);
  };

  /**
   * Phát đoạn ghi âm ra loa theo đồng hồ của AudioContext; mỗi TICK_MS gửi
   * phần mẫu vừa phát qua đường dây, nên MATLAB nhận âm thanh cùng nhịp với loa.
   */
  const send = async () => {
    if (!scene) return;
    stopPlay();
    const id = caseNo + 1;
    setCaseNo(id);
    setHeard('');
    setVerdict(null);
    setLate(false);
    clearTimeout(lateTimer.current);
    setSent(scene);
    setPhase('gui');
    line.send({ t: 'case', id, sec: Math.round(scene.sec * 100) / 100 });

    const ctx = (ctxRef.current ??= new AudioContext());
    await ctx.resume();
    const n = scene.x.length;
    const t0 = ctx.currentTime + 0.15;
    const buf = ctx.createBuffer(1, n, scene.fs);
    buf.copyToChannel(scene.x, 0);
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.connect(ctx.destination);
    src.start(t0);

    let da = 0;
    const timer = window.setInterval(() => {
      const toi = Math.min(n, Math.max(0, Math.floor((ctx.currentTime - t0) * LINE_FS)));
      if (toi > da) line.sendPcm(scene.x.subarray(da, toi));
      da = Math.max(da, toi);
      setPos(da / n);
      if (da >= n) {
        clearInterval(timer);
        play.current = null;
        setPos(null);
        line.send({ t: 'end' });
        if (phaseRef.current === 'gui') waitVerdict();
      }
    }, TICK_MS);
    play.current = { timer, src };
  };

  /** Dừng giữa chừng: MATLAB kết luận trên phần đã nghe. */
  const stop = () => {
    stopPlay();
    line.send({ t: 'end' });
    waitVerdict();
  };

  const reveal = () => {
    if (!sent) return;
    clearTimeout(lateTimer.current);
    line.send({
      t: 'reveal',
      keys: sent.presses.map((p) => p.key).join(''),
      marks: sent.presses.flatMap((p) => [Math.round(p.start * 1000) / 1000, Math.round(p.end * 1000) / 1000]),
    });
    setPhase('cb');
  };

  const newCase = () => {
    stopPlay();
    clearTimeout(lateTimer.current);
    setPhase('soan');
    setSent(null);
    setHeard('');
    setVerdict(null);
    setLate(false);
    setSecret('');
    setShow(false);
    setSeed(newSeed());
  };

  // ------------------------------------------------------------- hiển thị
  const busy = phase === 'gui' || phase === 'cho';
  const locked = phase !== 'soan';
  const truth = sent ? sent.presses.map((p) => p.key).join('') : '';
  const cmp = phase === 'cb' && verdict ? align(truth, verdict.keys) : null;
  const ops = cmp ? cmp.cells.filter((c) => c.op !== 'thua').map((c) => c.op) : null;
  const shown = locked ? sent : scene;

  return (
    <Stage>
      <div className="split fx">
        <aside className="side-phone fx-side" aria-label="Hồ sơ vụ việc">
          <div className="side-top">
            <span className="brand">
              <span className="brand-mark" aria-hidden="true">
                <i />
                <i />
              </span>
              DTMF
            </span>
            <WireChip wire={wire} onReconnect={reconnect} />
          </div>

          <section className="fx-sec">
            <h2>
              <span className="num">1</span>Số bí mật
            </h2>
            <div className="fx-secret">
              <input
                className="input"
                type={show ? 'text' : 'password'}
                inputMode="numeric"
                autoComplete="off"
                spellCheck={false}
                placeholder="0912 345 678"
                value={secret}
                disabled={locked}
                onChange={(e) => setSecret(e.target.value)}
                aria-label="Số bí mật"
              />
              <button type="button" className="btn" onClick={() => setShow((v) => !v)} disabled={locked}>
                {show ? 'Ẩn' : 'Hiện'}
              </button>
              <button
                type="button"
                className="btn"
                disabled={locked}
                onClick={() => {
                  setSecret(randomPhone());
                  setShow(false);
                }}
              >
                Ngẫu nhiên
              </button>
            </div>
            {secret && !valid && (
              <p className="field-note fx-err">
                {parsed.invalid.length > 0
                  ? 'Chỉ dùng chữ số 0-9, * và #.'
                  : `Cần ${MIN_KEYS}-${MAX_KEYS} phím, đang có ${keys.length}.`}
              </p>
            )}
          </section>

          <section className="fx-sec">
            <h2>
              <span className="num">2</span>Độ khó
            </h2>
            <div className={locked ? 'fx-level off' : 'fx-level'}>
              <div className="fx-track">
                <span className="fx-ticks" aria-hidden="true">
                  {PRESETS.map((p, i) => (
                    <i key={p.id} className={i <= level ? 'd' : ''} />
                  ))}
                </span>
                <input
                  type="range"
                  min={0}
                  max={PRESETS.length - 1}
                  step={1}
                  value={level}
                  disabled={locked}
                  style={{ '--p': `${(level / (PRESETS.length - 1)) * 100}%` } as CSSProperties}
                  onChange={(e) => {
                    setLevel(Number(e.target.value));
                    setSeed(newSeed());
                  }}
                  aria-label="Độ khó"
                  aria-valuetext={`${preset.ten}, mức ${level + 1} trên ${PRESETS.length}`}
                />
              </div>
              <div className="fx-ends" aria-hidden="true">
                <span>Dễ</span>
                <span>Rất khó</span>
              </div>
            </div>
            <div className="fx-level-info">
              <b>{preset.ten}</b>
              <span>{presetParams(preset)}</span>
              <span className="fx-ket">{preset.ket}</span>
            </div>
          </section>

          <div className="fx-go-wrap">
            {phase === 'gui' ? (
              <button type="button" className="btn fx-go" onClick={stop}>
                Dừng
              </button>
            ) : (
              <button type="button" className="btn primary fx-go" disabled={!scene || locked} onClick={() => void send()}>
                {matlab ? 'Gửi cho MATLAB' : 'Phát ra loa'}
              </button>
            )}
          </div>
        </aside>

        <main className="side-content fx-main">
          <header className="intro">
            <div>
              <p className="eyebrow">Xử lý tín hiệu số · Chủ đề 4</p>
              <h1>Giám định đoạn ghi âm</h1>
              <p className="lede">Nhập một số bí mật. MATLAB chỉ nghe đoạn ghi âm và phải tự tìm lại số đó.</p>
            </div>
            <ModeSwitch current="forensic" />
          </header>

          <section className="fx-sec">
            <h2>
              <span className="num">3</span>Đoạn ghi âm
              <span className="aside">{shown ? `${shown.sec.toFixed(1).replace('.', ',')} s` : ''}</span>
            </h2>
            <Recording scene={shown} pos={pos} ops={ops} height={230} />
          </section>

          <section className="fx-sec fx-grow">
            <h2>
              <span className="num">4</span>Kết luận
            </h2>

            {phase === 'soan' && (
              <p className="fx-hint">
                {matlab
                  ? 'Số MATLAB nghe được sẽ hiện ở đây và trên màn chiếu.'
                  : 'Mở DTMFForensic trong MATLAB trên máy trình chiếu để nó nghe đường dây.'}
              </p>
            )}

            {phase !== 'soan' && (
              <div className="fx-heard">
                <span className="fx-lab">{phase === 'gui' ? 'MATLAB đang nghe' : 'MATLAB đã nghe được'}</span>
                <span className="fx-big">{heard || (matlab ? '…' : '—')}</span>
              </div>
            )}

            {phase === 'cho' && (
              <p className="fx-hint">{late ? 'MATLAB chưa trả lời. Xem cửa sổ DTMFForensic.' : 'Chờ MATLAB kết luận…'}</p>
            )}

            {verdict && (
              <table className="fx-table">
                <thead>
                  <tr>
                    <th>Bộ giải mã</th>
                    <th>Số đọc được</th>
                    <th className="r">Thời gian</th>
                  </tr>
                </thead>
                <tbody>
                  {verdict.methods.map((m) => (
                    <tr key={m.name}>
                      <td>{m.name}</td>
                      <td className="mono">{m.keys || '—'}</td>
                      <td className="r mono">{m.ms.toFixed(1).replace('.', ',')} ms</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {cmp && (
              <div className="fx-cmp">
                <div>
                  <span className="fx-lab">Số thật</span>
                  <Digits cells={cmp.cells} row="that" />
                </div>
                <div>
                  <span className="fx-lab">MATLAB</span>
                  <Digits cells={cmp.cells} row="doc" />
                </div>
                <p className={summary(cmp.cells).ok ? 'fx-ok' : 'fx-bad'}>MATLAB {summary(cmp.cells).text}.</p>
              </div>
            )}

            <div className="fx-actions">
              {(phase === 'kl' || (phase === 'cho' && late)) && (
                <button type="button" className="btn primary" onClick={reveal}>
                  Công bố số thật
                </button>
              )}
              {locked && !busy && (
                <button type="button" className="btn" onClick={newCase}>
                  Vụ mới
                </button>
              )}
            </div>
          </section>
        </main>
      </div>
    </Stage>
  );
}
