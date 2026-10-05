import { PAUSE_MS, TONE_MS, parseKeys, scheduleSequence, sequenceDuration, type DtmfKey } from '../audio/dtmf';
import { useWidth } from '../hooks';
import { Icon, V } from './ui';

interface Props {
  value: string;
  onChange: (v: string) => void;
  onPlay: () => void;
  onStop: () => void;
  playing: boolean;
  /** Vị trí phím đang kêu trong chuỗi, -1 khi không phát. */
  current: number;
  /** Có nút Tải WAV không (bản Artifact thì không: trình xem chặn tải tệp). */
  onDownload?: () => void;
}

/**
 * Phát cả chuỗi phím theo đúng nhịp của dtmf_generate.m. Bên dưới là sơ đồ
 * thời gian của chuỗi: mỗi tone một khối trên trục t, phím đang kêu tô đậm.
 */
export function SequencePlayer({ value, onChange, onPlay, onStop, playing, current, onDownload }: Props) {
  const { keys, invalid } = parseKeys(value);
  const dur = sequenceDuration(keys);

  return (
    <>
      <h2 className="panel-title">
        Phát chuỗi
        <span className="aside">
          tone {TONE_MS} ms, nghỉ {PAUSE_MS} ms
        </span>
      </h2>
      <form
        className="seq-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (playing) onStop();
          else onPlay();
        }}
      >
        <label className="sr-only" htmlFor="seq-input">
          Chuỗi phím
        </label>
        <input
          id="seq-input"
          className="input"
          inputMode="tel"
          autoComplete="off"
          spellCheck={false}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="0912345"
        />
        <button type="submit" className="btn primary" disabled={!playing && keys.length === 0}>
          <Icon name={playing ? 'stop' : 'play'} size={14} />
          {playing ? 'Dừng' : 'Phát'}
        </button>
      </form>

      {invalid.length > 0 && (
        <p className="error">Bỏ qua {invalid.map((c) => `"${c}"`).join(', ')} vì chỉ phát được 0–9, * và #.</p>
      )}

      {keys.length > 0 && <SeqTimeline keys={keys} current={current} />}

      <div className="seq-foot">
        <span className="meta">
          {keys.length} phím, tổng <V v="T" /> = {dur.toFixed(2)} s
        </span>
        {onDownload && (
          <button type="button" className="btn" onClick={onDownload} disabled={keys.length === 0}>
            <Icon name="download" size={14} />
            Tải WAV 8 kHz
          </button>
        )}
      </div>
    </>
  );
}

/** Sơ đồ thời gian: khối tone đóng khung trên trục t (s), vạch chia hướng vào trong. */
function SeqTimeline({ keys, current }: { keys: DtmfKey[]; current: number }) {
  const [ref, w] = useWidth<HTMLDivElement>();
  const plan = scheduleSequence(keys);
  const total = sequenceDuration(keys);
  const H = 74;
  const top = 2;
  const bh = 26;
  const axisY = top + bh + 8;
  const pw = Math.max(1, w - 2);
  const xOf = (t: number) => 1 + (t / total) * pw;
  const step = [0.05, 0.1, 0.2, 0.25, 0.5, 1, 2].find((s) => (s / total) * pw >= 44) ?? 2;
  const ticks: number[] = [];
  for (let t = 0; t <= total + 1e-9; t += step) ticks.push(+t.toFixed(3));

  return (
    <div ref={ref} className="seq-tl">
      {w > 0 && (
        <svg className="svg-chart fig" width={w} height={H} role="img" aria-label={`Sơ đồ thời gian của chuỗi ${keys.join('')}`}>
          {plan.map((p, i) => {
            const x0 = xOf(p.start);
            const bw = xOf(p.end) - x0;
            const on = i === current;
            return (
              <g key={i}>
                <rect
                  x={x0 + 0.5}
                  y={top + 0.5}
                  width={Math.max(1, bw - 1)}
                  height={bh}
                  fill={on ? 'var(--ink)' : 'var(--surface)'}
                  className="frame"
                />
                {bw >= 12 && (
                  <text x={x0 + bw / 2} y={top + bh / 2 + 5} textAnchor="middle" className={on ? 'on-ink' : 'ink'}>
                    {p.key}
                  </text>
                )}
              </g>
            );
          })}
          <line x1={1} x2={1 + pw} y1={axisY + 0.5} y2={axisY + 0.5} className="tick" />
          {ticks.map((t) => (
            <g key={t}>
              <path d={`M${xOf(t)},${axisY}v-4`} className="tick" />
              <text x={xOf(t)} y={axisY + 14} textAnchor={t === 0 ? 'start' : 'middle'}>
                {t}
              </text>
            </g>
          ))}
          <text x={1 + pw} y={H - 2} textAnchor="end" className="axis-label">
            <tspan className="var">t</tspan> (s)
          </text>
        </svg>
      )}
    </div>
  );
}
