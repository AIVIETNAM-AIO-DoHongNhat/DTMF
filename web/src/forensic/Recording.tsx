// Dạng sóng của đoạn ghi âm, vẽ như một hình trong bài LaTeX: khung kín, vạch
// chia hướng vào trong, trục thời gian có đơn vị. Trước khi công bố chỉ thấy
// các cụm tiếng bấm, không thấy phím nào; công bố rồi thì mỗi lần bấm được
// khoanh lại, ghi số thật, tô xanh nếu MATLAB đọc đúng và đỏ nếu sai.

import { useWidth } from '../hooks';
import type { Op } from './align';
import type { Scene } from './scene';

const PAD = { l: 14, r: 14, t: 26, b: 34 };

interface Props {
  scene: Scene | null;
  /** Vị trí đang phát, 0..1; null khi không phát. */
  pos: number | null;
  /** Kết quả từng lần bấm theo thứ tự; có thì vẽ đáp án. */
  ops: Op[] | null;
  /** Chiều cao hình [px CSS]. */
  height?: number;
}

export function Recording({ scene, pos, ops, height: H = 168 }: Props) {
  const [ref, w] = useWidth<HTMLDivElement>();
  const iw = Math.max(1, w - PAD.l - PAD.r);
  const ih = H - PAD.t - PAD.b;
  const mid = PAD.t + ih / 2;

  let env = '';
  let ticks: number[] = [];
  let A = 1;
  if (scene && w > 0) {
    const x = scene.x;
    const cols = Math.floor(iw);
    const lo = new Float32Array(cols);
    const hi = new Float32Array(cols);
    for (let c = 0; c < cols; c++) {
      const a = Math.floor((c / cols) * x.length);
      const b = Math.max(a + 1, Math.floor(((c + 1) / cols) * x.length));
      let mn = 0;
      let mx = 0;
      for (let i = a; i < b; i++) {
        if (x[i] < mn) mn = x[i];
        if (x[i] > mx) mx = x[i];
      }
      lo[c] = mn;
      hi[c] = mx;
    }
    A = Math.max(0.05, ...Array.from(hi), ...Array.from(lo, (v) => -v)) * 1.08;
    const y = (v: number) => mid - (v / A) * (ih / 2);
    const top = Array.from(hi, (v, c) => `${(PAD.l + c + 0.5).toFixed(1)},${y(v).toFixed(1)}`);
    const bot = Array.from(lo, (v, c) => `${(PAD.l + c + 0.5).toFixed(1)},${y(v).toFixed(1)}`).reverse();
    env = `M${top.join('L')}L${bot.join('L')}Z`;
    const step = scene.sec > 14 ? 2 : 1;
    for (let t = 0; t <= scene.sec; t += step) ticks.push(t);
  } else {
    ticks = [];
  }
  const xOf = (t: number) => PAD.l + (scene ? (t / scene.sec) * iw : 0);

  return (
    <div className="fx-rec" ref={ref}>
      {w > 0 && (
        <svg width={w} height={H} role="img" aria-label="Dạng sóng của đoạn ghi âm">
          {scene && ops &&
            scene.presses.map((p, i) => {
              const op = ops[i];
              const cls = op === 'dung' ? 'ok' : 'bad';
              return (
                <g key={i} className={`fx-press ${cls}`}>
                  <rect x={xOf(p.start)} y={PAD.t} width={Math.max(2, xOf(p.end) - xOf(p.start))} height={ih} />
                  <text x={(xOf(p.start) + xOf(p.end)) / 2} y={PAD.t - 8} textAnchor="middle">
                    {p.key}
                  </text>
                </g>
              );
            })}
          {env && <path className="fx-env" d={env} />}
          <line className="fx-zero" x1={PAD.l} x2={PAD.l + iw} y1={mid} y2={mid} />
          <rect className="fx-frame" x={PAD.l} y={PAD.t} width={iw} height={ih} />
          {ticks.map((t) => (
            <g key={t}>
              <line className="fx-tick" x1={xOf(t)} x2={xOf(t)} y1={PAD.t + ih} y2={PAD.t + ih - 5} />
              <text className="fx-ticklab" x={xOf(t)} y={PAD.t + ih + 15} textAnchor="middle">
                {t}
              </text>
            </g>
          ))}
          <text className="fx-axlab" x={PAD.l + iw / 2} y={H - 3} textAnchor="middle">
            <tspan className="var">t</tspan> (s)
          </text>
          {pos !== null && scene && (
            <line className="fx-head" x1={PAD.l + pos * iw} x2={PAD.l + pos * iw} y1={PAD.t - 4} y2={PAD.t + ih + 4} />
          )}
          {!scene && (
            <text className="fx-empty" x={w / 2} y={mid + 4} textAnchor="middle">
              Nhập số bí mật để dựng đoạn ghi âm
            </text>
          )}
        </svg>
      )}
    </div>
  );
}
