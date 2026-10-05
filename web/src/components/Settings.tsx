import { toneLevels } from '../audio/dtmf';
import { Slider, V } from './ui';

interface Props {
  volume: number;
  boostDb: number;
  onVolume: (v: number) => void;
  onBoost: (v: number) => void;
}

const db = (a: number) => {
  const v = 20 * Math.log10(a);
  return `${v < 0 ? '−' : v > 0 ? '+' : ''}${Math.abs(v).toFixed(1)}`;
};

/** Âm lượng và bù loa nhóm hàng, kèm bảng biên độ hai tone và twist phát ra. */
export function Settings({ volume, boostDb, onVolume, onBoost }: Props) {
  const lv = toneLevels(volume, boostDb);
  const twist = 20 * Math.log10(lv.col / lv.row);

  return (
    <>
      <h2 className="panel-title">
        Loa và âm lượng
        <span className="aside">
          <V v="A" s="R" /> + <V v="A" s="C" /> = {volume.toFixed(2)}
        </span>
      </h2>

      <div className="set-grid">
        <Slider
          id="vol"
          label="Âm lượng"
          value={volume}
          min={0.1}
          max={1}
          step={0.05}
          onChange={onVolume}
          display={`${Math.round(volume * 100)}%`}
        />
        <Slider
          id="boost"
          label="Bù loa nhóm hàng"
          value={boostDb}
          min={0}
          max={15}
          step={1}
          onChange={onBoost}
          display={`+${boostDb} dB`}
        />
      </div>

      <table className="amp-table">
        <thead>
          <tr>
            <th scope="col">Tone</th>
            <th scope="col" className="num">
              Biên độ
            </th>
            <th scope="col" className="num">
              20 log<sub>10</sub> <V v="A" /> (dB)
            </th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <th scope="row">
              <i className="sw row" aria-hidden="true" />
              Nhóm hàng, <V v="A" s="R" />
            </th>
            <td className="num">{lv.row.toFixed(3)}</td>
            <td className="num">{db(lv.row)}</td>
          </tr>
          <tr>
            <th scope="row">
              <i className="sw col" aria-hidden="true" />
              Nhóm cột, <V v="A" s="C" />
            </th>
            <td className="num">{lv.col.toFixed(3)}</td>
            <td className="num">{db(lv.col)}</td>
          </tr>
        </tbody>
      </table>
      <p className="amp-twist">
        Twist phát = 20 log<sub>10</sub>(<V v="A" s="C" /> / <V v="A" s="R" />) = {twist <= -0.05 ? '−' : ''}
        {Math.abs(twist).toFixed(1)} dB, bộ giải mã nhận trong khoảng −8 đến +4 dB.
      </p>

      <details className="tips">
        <summary>Khi MATLAB nghe qua micro</summary>
        <ul>
          <li>
            Loa nhỏ phát 697–941 Hz yếu hơn nhóm cột, mà bộ giải mã chỉ nhận khi cột mạnh hơn hàng không quá 4 dB.
            MATLAB báo <span className="mono">twist</span> thì tăng bù loa từng 2–3 dB.
          </li>
          <li>Đặt loa điện thoại cách micro laptop 5–10 cm.</li>
          <li>iPhone cần tắt chế độ im lặng, nếu không trang sẽ không có tiếng.</li>
          <li>Âm lượng vừa phải. Quá to làm loa méo và sinh hài.</li>
        </ul>
      </details>
    </>
  );
}
