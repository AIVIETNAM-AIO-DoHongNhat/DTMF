// Chuyện của một phím bấm, ba hình như trong một bài báo: (a) phím chọn một
// hàng và một cột của bảng tần số, (b) hai sóng sin và tổng của chúng theo
// thời gian, (c) phổ biên độ có đúng hai đỉnh. Giải mã là việc của MATLAB.

import { useMemo, useState, type ReactNode } from 'react';
import { COL_HZ, KEYS, ROW_HZ, synthesize, type KeyInfo, type ToneLevels } from '../audio/dtmf';
import { amplitudeAt, amplitudeSpectrum } from '../dsp/spectrum';
import { useSize, useWidth } from '../hooks';
import { V } from './ui';

const FS = 8000;

interface Props {
  info: KeyInfo;
  levels: ToneLevels;
  volume: number;
  boostDb: number;
  toneMs: number;
}

/** Biến có chỉ số dưới trong SVG, kiểu LaTeX: x_R, f_C... */
function SubVar({ v, s, after = '' }: { v: string; s: string; after?: string }) {
  return (
    <>
      <tspan className="var">{v}</tspan>
      <tspan className="sub" dy={3}>
        {s}
      </tspan>
      <tspan dy={-3}>{after || '​'}</tspan>
    </>
  );
}

export function Story({ info, levels, volume, boostDb, toneMs }: Props) {
  const x = useMemo(
    () => synthesize([info.key], { fs: FS, volume, rowBoostDb: boostDb, toneMs, pauseMs: 0 }),
    [info.key, volume, boostDb, toneMs],
  );
  const spec = useMemo(() => amplitudeSpectrum(x, FS, F_MAX, 4), [x]);
  const peakR = useMemo(() => amplitudeAt(x, FS, info.rowHz), [x, info.rowHz]);
  const peakC = useMemo(() => amplitudeAt(x, FS, info.colHz), [x, info.colHz]);
  const same = levels.row.toFixed(2) === levels.col.toFixed(2);

  return (
    <div className="story">
      <section className="panel st" aria-labelledby="hinh-a">
        <header className="st-head">
          <h2 id="hinh-a">
            <span className="fig-tag">(a)</span> Phím chọn hai tần số
          </h2>
        </header>
        <KeyMatrix info={info} />
        <div className="formula" aria-label="Công thức tín hiệu">
          <p>
            <V v="x" />(<V v="t" />) = <V v="A" s="R" /> sin(2π<V v="f" s="R" />
            <V v="t" />) + <V v="A" s="C" /> sin(2π<V v="f" s="C" />
            <V v="t" />)
          </p>
          <p>
            <V v="f" s="R" /> = {info.rowHz} Hz, <V v="f" s="C" /> = {info.colHz} Hz
          </p>
          <p>
            {same ? (
              <>
                <V v="A" s="R" /> = <V v="A" s="C" /> = {levels.row.toFixed(2)}
              </>
            ) : (
              <>
                <V v="A" s="R" /> = {levels.row.toFixed(2)}, <V v="A" s="C" /> = {levels.col.toFixed(2)}
              </>
            )}
          </p>
        </div>
      </section>

      <section className="panel st" aria-labelledby="hinh-b">
        <header className="st-head">
          <h2 id="hinh-b">
            <span className="fig-tag">(b)</span> Miền thời gian: hai sóng sin và tổng
          </h2>
          <span className="st-meta">8 ms giữa tone, chưa có nhiễu</span>
        </header>
        <Waves info={info} lv={levels} />
      </section>

      <section className="panel st st-spec" aria-labelledby="hinh-c">
        <header className="st-head">
          <h2 id="hinh-c">
            <span className="fig-tag">(c)</span> Miền tần số: phổ biên độ có đúng hai đỉnh
          </h2>
          <span className="st-meta">
            cửa sổ Hamming, <V v="N" /> = {x.length}, <V v="f" s="s" /> = {FS / 1000} kHz
          </span>
        </header>
        <SpectrumViz f={spec.f} A={spec.A} info={info} peakR={peakR} peakC={peakC} />
      </section>
    </div>
  );
}

/* ------------------------------------------------------- bảng phím - tần số */

/** Bảng kẻ kiểu booktabs: hàng và cột đang chọn tô xám nhạt, phím ở giao đóng khung. */
function KeyMatrix({ info }: { info: KeyInfo }) {
  return (
    <table className="km" aria-label={`Phím ${info.key}: hàng ${info.rowHz} Hz, cột ${info.colHz} Hz`}>
      <thead>
        <tr>
          <th />
          <th colSpan={3} className="km-group">
            <V v="f" s="C" /> (Hz)
          </th>
        </tr>
        <tr className="km-mid">
          <th className="km-rowh">
            <V v="f" s="R" /> (Hz)
          </th>
          {COL_HZ.map((f, c) => (
            <th key={f} scope="col" className={c === info.col ? 'on' : undefined}>
              {f}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {ROW_HZ.map((f, r) => (
          <tr key={f}>
            <th scope="row" className={r === info.row ? 'on' : undefined}>
              {f}
            </th>
            {COL_HZ.map((_, c) => {
              const k = KEYS[r * 3 + c];
              const cls = k === info.key ? 'hit' : r === info.row || c === info.col ? 'cross' : undefined;
              return (
                <td key={k} className={cls}>
                  {k}
                </td>
              );
            })}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

/* --------------------------------------------------- hình (b): miền thời gian */

const T0 = 20; // ms tính từ đầu tone: đã qua dốc 5 ms, sóng ổn định
const T1 = 28;

/** Ba đồ thị con chung trục t, khung đủ bốn cạnh, vạch chia hướng vào trong. */
function Waves({ info, lv }: { info: KeyInfo; lv: ToneLevels }) {
  const [ref, w] = useWidth<HTMLDivElement>();
  const H = 262;
  const L = 74;
  const R = 6;
  const top = 4;
  const bottom = 36;
  const gap = 12;
  const ph = (H - top - bottom - 2 * gap) / 3;
  const pw = Math.max(1, w - L - R);
  const xOf = (t: number) => L + ((t - T0) / (T1 - T0)) * pw;

  // Chừa khoảng trên đỉnh cho chú thích; vạch có số ở ±lim/2 để nhãn hai đồ thị con không chạm nhau.
  const lim = Math.max(0.2, Math.ceil(((lv.row + lv.col) * 1.25) / 0.2) * 0.2);
  const sR = (t: number) => lv.row * Math.sin((2 * Math.PI * info.rowHz * t) / 1000);
  const sC = (t: number) => lv.col * Math.sin((2 * Math.PI * info.colHz * t) / 1000);

  const plots: { fn: (t: number) => number; color: string; label: ReactNode; note: ReactNode }[] = [
    {
      fn: sR,
      color: 'var(--row)',
      label: <SubVar v="x" s="R" after="(" />,
      note: <SubVar v="f" s="R" after={` = ${info.rowHz} Hz`} />,
    },
    {
      fn: sC,
      color: 'var(--col)',
      label: <SubVar v="x" s="C" after="(" />,
      note: <SubVar v="f" s="C" after={` = ${info.colHz} Hz`} />,
    },
    {
      fn: (t) => sR(t) + sC(t),
      color: 'var(--ink)',
      label: (
        <>
          <tspan className="var">x</tspan>(
        </>
      ),
      note: (
        <>
          <tspan className="var">x</tspan> = <SubVar v="x" s="R" after=" + " />
          <SubVar v="x" s="C" />
        </>
      ),
    },
  ];
  const ticks = Array.from({ length: T1 - T0 + 1 }, (_, i) => T0 + i);
  const n = Math.max(60, Math.round(pw / 1.2));

  return (
    <div ref={ref}>
      {w > 0 && (
        <svg
          className="svg-chart fig"
          width={w}
          height={H}
          role="img"
          aria-label={`Sóng ${info.rowHz} Hz, sóng ${info.colHz} Hz và tổng của chúng, 20 đến 28 ms`}
        >
          {plots.map((p, i) => {
            const y0 = top + i * (ph + gap);
            const mid = y0 + ph / 2;
            const yOf = (v: number) => mid - (v / lim) * (ph / 2);
            let d = '';
            for (let j = 0; j <= n; j++) {
              const t = T0 + (j / n) * (T1 - T0);
              d += `${j ? 'L' : 'M'}${xOf(t).toFixed(1)},${yOf(p.fn(t)).toFixed(1)}`;
            }
            const last = i === plots.length - 1;
            return (
              <g key={i}>
                <line x1={L} x2={L + pw} y1={mid} y2={mid} className="zero" />
                <path d={d} fill="none" stroke={p.color} strokeWidth={1.25} strokeLinejoin="round" />
                <rect x={L + 0.5} y={y0 + 0.5} width={pw - 1} height={ph - 1} className="frame" />
                {ticks.map((t) => (
                  <path key={t} d={`M${xOf(t)},${y0 + ph}v-4M${xOf(t)},${y0}v4`} className="tick" />
                ))}
                {[-lim / 2, 0, lim / 2].map((v) => (
                  <g key={v}>
                    <path d={`M${L},${yOf(v)}h4M${L + pw},${yOf(v)}h-4`} className="tick" />
                    <text x={L - 5} y={yOf(v) + 3.5} textAnchor="end">
                      {v === 0 ? '0' : `${v < 0 ? '−' : ''}${Math.abs(v).toFixed(1)}`}
                    </text>
                  </g>
                ))}
                <text x={0} y={mid + 4} className="axis-label">
                  {p.label}
                  <tspan className="var">t</tspan>)
                </text>
                <text x={L + pw - 6} y={y0 + 13} textAnchor="end" className="note halo">
                  {p.note}
                </text>
                {last &&
                  ticks.map((t) => (
                    <text key={t} x={xOf(t)} y={y0 + ph + 14} textAnchor="middle">
                      {t}
                    </text>
                  ))}
              </g>
            );
          })}
          <text x={L + pw / 2} y={H - 3} textAnchor="middle" className="axis-label">
            <tspan className="var">t</tspan> (ms)
          </text>
        </svg>
      )}
    </div>
  );
}

/* --------------------------------------------------- hình (c): miền tần số */

const F_MAX = 2000;

function SpectrumViz({
  f,
  A,
  info,
  peakR,
  peakC,
}: {
  f: Float64Array;
  A: Float64Array;
  info: KeyInfo;
  peakR: number;
  peakC: number;
}) {
  const [ref, { w, h }] = useSize<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const L = 62;
  const R = 8;
  const T = 46;
  const B = 42;
  const pw = Math.max(1, w - L - R);
  const ph = Math.max(1, h - T - B);
  const xOf = (fr: number) => L + (fr / F_MAX) * pw;

  const top = Math.max(peakR, peakC, 1e-3) * 1.2;
  const step = top > 0.6 ? 0.2 : 0.1;
  const yMax = Math.max(step, Math.ceil(top / step) * step);
  const yOf = (a: number) => T + ph - (Math.min(a, yMax) / yMax) * ph;
  const yTicks = Array.from({ length: Math.round(yMax / step) + 1 }, (_, i) => +(i * step).toFixed(2));
  const fStep = pw >= 640 ? 250 : 500;
  const fTicks = Array.from({ length: F_MAX / fStep + 1 }, (_, i) => i * fStep);
  const df = f[1] - f[0];
  // Hình hẹp thì nhãn của bảy tần số dính vào nhau: chỉ giữ hai tần số của phím.
  const roomy = (73 / F_MAX) * pw >= 24;

  let line = '';
  for (let i = 0; i < f.length; i++) line += `${i ? 'L' : 'M'}${xOf(f[i]).toFixed(1)},${yOf(A[i]).toFixed(1)}`;

  const groups: [string, number, number][] = [
    ['nhóm hàng', ROW_HZ[0], ROW_HZ[3]],
    ['nhóm cột', COL_HZ[0], COL_HZ[2]],
  ];
  const peaks: [number, number, string, string][] = [
    [info.rowHz, peakR, 'var(--row)', 'R'],
    [info.colHz, peakC, 'var(--col)', 'C'],
  ];

  return (
    <div ref={ref} className="spec-box">
      {w > 0 && h > 0 && (
        <svg
          className="svg-chart fig"
          width={w}
          height={h}
          role="img"
          aria-label={`Phổ biên độ của phím ${info.key}: đỉnh ${peakR.toFixed(2)} tại ${info.rowHz} Hz, đỉnh ${peakC.toFixed(2)} tại ${info.colHz} Hz`}
          onPointerMove={(e) => {
            const r = e.currentTarget.getBoundingClientRect();
            const xx = ((e.clientX - r.left) / r.width) * w;
            const fr = ((xx - L) / pw) * F_MAX;
            setHover(fr < 0 || fr > F_MAX ? null : Math.round(fr / df));
          }}
          onPointerLeave={() => setHover(null)}
        >
          {/* lưới chấm ở vạch chính */}
          {fTicks.slice(1, -1).map((fr) => (
            <line key={fr} x1={xOf(fr)} x2={xOf(fr)} y1={T} y2={T + ph} className="grid" />
          ))}
          {yTicks.slice(1, -1).map((a) => (
            <line key={a} x1={L} x2={L + pw} y1={yOf(a)} y2={yOf(a)} className="grid" />
          ))}

          {/* bảy tần số DTMF và hai nhóm, ghi phía trên khung */}
          {[...ROW_HZ, ...COL_HZ].map((fr) => {
            const on = fr === info.rowHz || fr === info.colHz;
            return (
              <g key={fr}>
                <line x1={xOf(fr)} x2={xOf(fr)} y1={T} y2={T + ph} className={on ? 'mark on' : 'mark'} />
                {(on || roomy) && (
                  <text x={xOf(fr)} y={T - 6} textAnchor="middle" className={on ? 'ink strong' : undefined}>
                    {fr}
                  </text>
                )}
              </g>
            );
          })}
          {groups.map(([name, a, b]) => (
            <g key={name}>
              <path d={`M${xOf(a) - 6},${T - 20}v-4H${xOf(b) + 6}v4`} className="brace" />
              <text x={(xOf(a) + xOf(b)) / 2} y={T - 28} textAnchor="middle" className="note">
                {name}
              </text>
            </g>
          ))}

          <path d={line} fill="none" stroke="var(--ink)" strokeWidth={1.25} strokeLinejoin="round" />

          {peaks.map(([fr, a, color, s]) => (
            <g key={fr}>
              <circle cx={xOf(fr)} cy={yOf(a)} r={3.5} fill="var(--surface)" stroke={color} strokeWidth={1.5} />
              <text x={xOf(fr) + 9} y={yOf(a) + 1} className="note halo">
                <SubVar v="A" s={s} after={` = ${a.toFixed(2)}`} />
              </text>
              <text x={xOf(fr) + 9} y={yOf(a) + 15} className="note halo">
                <SubVar v="f" s={s} after={` = ${fr} Hz`} />
              </text>
            </g>
          ))}

          {/* khung và vạch chia hướng vào trong, đủ bốn cạnh */}
          <rect x={L + 0.5} y={T + 0.5} width={pw - 1} height={ph - 1} className="frame" />
          {fTicks.map((fr) => (
            <g key={fr}>
              <path d={`M${xOf(fr)},${T + ph}v-5M${xOf(fr)},${T}v5`} className="tick" />
              <text x={xOf(fr)} y={T + ph + 15} textAnchor="middle">
                {fr}
              </text>
            </g>
          ))}
          {yTicks.map((a) => (
            <g key={a}>
              <path d={`M${L},${yOf(a)}h5M${L + pw},${yOf(a)}h-5`} className="tick" />
              <text x={L - 6} y={yOf(a) + 3.5} textAnchor="end">
                {a === 0 ? '0' : a.toFixed(1)}
              </text>
            </g>
          ))}
          <text x={L + pw / 2} y={T + ph + 34} textAnchor="middle" className="axis-label">
            Tần số <tspan className="var">f</tspan> (Hz)
          </text>
          <text
            x={0}
            y={0}
            transform={`translate(${14},${T + ph / 2}) rotate(-90)`}
            textAnchor="middle"
            className="axis-label"
          >
            Biên độ <tspan className="var">A</tspan>
          </text>

          {hover !== null && hover < A.length && (
            <line x1={xOf(f[hover])} x2={xOf(f[hover])} y1={T} y2={T + ph} className="cursor" />
          )}
        </svg>
      )}
      {hover !== null && hover < A.length && (
        <div className="chart-tip" style={{ left: xOf(f[hover]), top: yOf(A[hover]) }}>
          <i className="var">f</i> = {f[hover].toFixed(0)} Hz, <i className="var">A</i> = {A[hover].toFixed(3)}
        </div>
      )}
    </div>
  );
}
