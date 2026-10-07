import { useEffect, useState, type ReactNode } from 'react';
import { KEYS, type DtmfKey, type KeyInfo } from '../audio/dtmf';
import { TEN_NUT, type IvrState } from '../ivr/ivr';
// Bản build gom mọi thứ vào một tệp HTML, nên ảnh này cũng được nhúng thẳng vào đó.
import logo from '../../images/Logo_hoc_vien_ANND.png';

export type CallState = 'idle' | 'ringing' | 'connected';

/**
 * Cuộc gọi hiện tại đi qua đâu.
 *   dialing: đang hỏi cầu nối; matlab: tổng đài là MATLAB, đọc lại phím
 *   MATLAB đọc được; local: tổng đài chạy trong trang (why: không có cầu nối,
 *   MATLAB chưa nối, hay MATLAB không nhấc máy); lost: mất MATLAB giữa chừng.
 */
export interface Link {
  mode: 'off' | 'dialing' | 'matlab' | 'local' | 'lost';
  method?: string;
  why?: 'bridge' | 'matlab' | 'answer';
}

/** Phím MATLAB vừa đọc được; n tăng mỗi lần để huy hiệu nháy lại cả khi trùng phím. */
export interface Heard {
  key: string;
  n: number;
}

interface Props {
  call: CallState;
  connectedAt: number;
  ivr: IvrState;
  /** Các phím đã bấm trong cuộc gọi, hiện thay tên khi mở bàn phím. */
  typed: string;
  active: KeyInfo | null;
  link: Link;
  heard: Heard | null;
  onCall: () => void;
  onHangup: () => void;
  onPress: (k: DtmfKey) => void;
  onRelease: (k: DtmfKey) => void;
}

const NAME = 'Học viện An ninh nhân dân';
/** Số giả cho đề tài: cuộc gọi chỉ đi tới tổng đài mô phỏng, không ra ngoài. */
const NUMBER = '0123 456 789';
/** Ghi chú như người dùng tự lưu trong danh bạ. */
const NOTE = 'Tổng đài thử nghiệm: bấm phím bất kỳ, tổng đài đọc lại phím vừa nhận.';
/** Ống nghe: nút gọi, ô điện thoại, và (xoay 135°) nút kết thúc. */
const PHONE_PATH =
  'M6.6 10.8a15.1 15.1 0 0 0 6.6 6.6l2.2-2.2a1 1 0 0 1 1-.25 11.4 11.4 0 0 0 3.6.57 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1c0 1.25.2 2.45.57 3.57a1 1 0 0 1-.25 1z';
/** Chữ dưới mỗi số, như bàn phím điện thoại thật. */
const LETTERS: Record<DtmfKey, string> = {
  '1': '',
  '2': 'ABC',
  '3': 'DEF',
  '4': 'GHI',
  '5': 'JKL',
  '6': 'MNO',
  '7': 'PQRS',
  '8': 'TUV',
  '9': 'WXYZ',
  '*': '',
  '0': '+',
  '#': '',
};

function useTicker(on: boolean, ms: number): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!on) return;
    setNow(Date.now());
    const id = window.setInterval(() => setNow(Date.now()), ms);
    return () => clearInterval(id);
  }, [on, ms]);
  return now;
}

const mmss = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};

/**
 * Điện thoại gọi tổng đài, theo đúng màn hình cuộc gọi của iPhone ở Dark Mode:
 * thẻ danh bạ trước khi gọi, rồi màn gọi với sáu nút tròn, bàn phím mở bằng nút
 * "bàn phím". Lời nhắc của tổng đài hiện như phụ đề trực tiếp, chờ thu âm.
 */
export function Phone(p: Props) {
  const clock = useTicker(true, 15000);
  const t = new Date(clock);
  const time = `${t.getHours()}:${String(t.getMinutes()).padStart(2, '0')}`;

  return (
    <div className="phone">
      <div className="screen">
        <div className="island" aria-hidden="true" />
        <StatusBar time={time} />
        {p.call === 'idle' ? <ContactCard onCall={p.onCall} /> : <CallScreen {...p} />}
        <div className="home-bar" aria-hidden="true" />
      </div>
    </div>
  );
}

function StatusBar({ time }: { time: string }) {
  return (
    <div className="statusbar" aria-hidden="true">
      <span>{time}</span>
      <span className="sb-icons">
        <svg width="18" height="12" viewBox="0 0 18 12">
          {[0, 1, 2, 3].map((i) => (
            <rect key={i} x={i * 4.8} y={9 - i * 3} width="3.2" height={3 + i * 3} rx="1" fill="currentColor" />
          ))}
        </svg>
        <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor">
          <path d="M8 2.6c2.3 0 4.4.9 6 2.4l1.2-1.3A10.2 10.2 0 0 0 8 .8 10.2 10.2 0 0 0 .8 3.7L2 5c1.6-1.5 3.7-2.4 6-2.4z" />
          <path d="M8 6.2c1.3 0 2.5.5 3.4 1.3l1.2-1.3A6.7 6.7 0 0 0 8 4.4c-1.8 0-3.4.7-4.6 1.8l1.2 1.3c.9-.8 2.1-1.3 3.4-1.3z" />
          <path d="M8 9.6 10.2 8a3.2 3.2 0 0 0-4.4 0z" />
        </svg>
        <svg width="27" height="13" viewBox="0 0 27 13">
          <rect x="0.5" y="0.5" width="23" height="12" rx="3.8" fill="none" stroke="currentColor" opacity="0.4" />
          <rect x="2" y="2" width="17" height="9" rx="2.4" fill="currentColor" />
          <path d="M25 4.5v4a2.2 2.2 0 0 0 0-4z" fill="currentColor" opacity="0.4" />
        </svg>
      </span>
    </div>
  );
}

/* ------------------------------------------------------------ thẻ danh bạ */

function ContactCard({ onCall }: { onCall: () => void }) {
  return (
    <div className="contact">
      {/* Như iOS 26: nút quay lại là một viên kính tròn chỉ có mũi tên, dính trên đầu khi cuộn. */}
      <div className="ct-nav" aria-hidden="true">
        <span className="glass ct-back">
          <svg width="12" height="20" viewBox="0 0 12 20" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
            <path d="M9.5 2.5 2.5 10l7 7.5" />
          </svg>
        </span>
        <span className="glass ct-edit">Sửa</span>
      </div>
      <img className="ct-avatar" src={logo} alt="" aria-hidden="true" />
      <h2 className="ct-name">{NAME}</h2>
      <p className="ct-sub">Tổng đài thử nghiệm DTMF</p>
      <div className="ct-actions">
        <CtAction label="nhắn tin" disabled>
          <path d="M12 4C6.5 4 2 7.6 2 12c0 2.4 1.3 4.6 3.5 6.1L4.6 21l3.6-1.8c1.2.4 2.5.6 3.8.6 5.5 0 10-3.6 10-8S17.5 4 12 4z" />
        </CtAction>
        <CtAction label="gọi" onClick={onCall}>
          <path d={PHONE_PATH} />
        </CtAction>
        <CtAction label="video" disabled>
          <path d="M3 7.5A1.5 1.5 0 0 1 4.5 6h10A1.5 1.5 0 0 1 16 7.5v9a1.5 1.5 0 0 1-1.5 1.5h-10A1.5 1.5 0 0 1 3 16.5zM17 10l4-2.5v9L17 14z" />
        </CtAction>
        <CtAction label="mail" disabled>
          <path d="M3 6.5A1.5 1.5 0 0 1 4.5 5h15A1.5 1.5 0 0 1 21 6.5v11a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5zm1.8.3 7.2 5.6 7.2-5.6z" />
        </CtAction>
      </div>
      {/* Phần dưới như thẻ danh bạ iOS: mỗi nhóm một khối mờ bo tròn. */}
      <button type="button" className="ct-card ct-phone" onClick={onCall} aria-label={`Gọi ${NAME}, ${NUMBER}`}>
        <span className="ct-label">điện thoại</span>
        <span className="ct-value">{NUMBER}</span>
        <svg className="ct-phone-ic" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path d={PHONE_PATH} />
        </svg>
      </button>
      <div className="ct-card ct-note">
        <span className="ct-label">Ghi chú</span>
        <span className="ct-value">{NOTE}</span>
      </div>
      {/* Các dòng còn lại chỉ để thẻ trông như danh bạ thật, không bấm được. */}
      <div className="ct-card ct-list" aria-hidden="true">
        <span>Chia sẻ liên hệ</span>
        <span>Thêm vào Mục ưa thích</span>
      </div>
      <div className="ct-card ct-list" aria-hidden="true">
        <span>Thêm vào Liên hệ khẩn cấp</span>
      </div>
      <div className="ct-card ct-list" aria-hidden="true">
        <span>Chặn liên hệ</span>
      </div>
      <p className="ct-foot">Số mô phỏng cho đề tài, không gọi ra ngoài.</p>
    </div>
  );
}

function CtAction({
  label,
  disabled,
  onClick,
  children,
}: {
  label: string;
  disabled?: boolean;
  onClick?: () => void;
  children: ReactNode;
}) {
  return (
    <button type="button" className="glass ct-act" disabled={disabled} onClick={onClick} aria-label={label === 'gọi' ? `Gọi ${NAME}` : label}>
      <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        {children}
      </svg>
      <span>{label}</span>
    </button>
  );
}

/* ------------------------------------------------------------- màn gọi */

function CallScreen(p: Props) {
  const [pad, setPad] = useState(false);
  const [mute, setMute] = useState(false);
  const [speaker, setSpeaker] = useState(false);
  const connected = p.call === 'connected';
  const now = useTicker(connected, 500);

  return (
    <div className={`call ${pad ? 'with-pad' : ''}`}>
      <header className="call-top" aria-live="polite">
        {pad && p.typed ? (
          <p className="typed">{p.typed.length > 13 ? `…${p.typed.slice(-12)}` : p.typed}</p>
        ) : (
          <>
            <h2 className="call-name">{NAME}</h2>
            <p className="call-status">{connected ? mmss(now - p.connectedAt) : ringingText(p.link)}</p>
          </>
        )}
      </header>

      {connected && (
        <div className="glass caption" aria-live="polite">
          <p className="cap-head">
            <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
              <rect x="1" y="6" width="2" height="4" rx="1" />
              <rect x="5" y="3" width="2" height="10" rx="1" />
              <rect x="9" y="5" width="2" height="6" rx="1" />
              <rect x="13" y="7" width="2" height="2" rx="1" />
            </svg>
            <span className="cap-title">Phụ đề trực tiếp · {TEN_NUT[p.ivr.nut]}</span>
            <LineChip link={p.link} heard={p.heard} />
          </p>
          <p className="cap-text" key={p.ivr.loi}>
            {p.ivr.loi}
          </p>
        </div>
      )}

      {pad ? (
        <div className="pad" role="group" aria-label="Bàn phím">
          {KEYS.map((k) => (
            <PadKey key={k} k={k} on={p.active?.key === k} onPress={p.onPress} onRelease={p.onRelease} />
          ))}
        </div>
      ) : (
        <div className="call-grid">
          <CallBtn label="tắt tiếng" on={mute} onClick={() => setMute((v) => !v)}>
            <rect x="9" y="2.5" width="6" height="11" rx="3" />
            <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
              <path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M4 3.5l16 17" />
            </g>
          </CallBtn>
          <CallBtn label="bàn phím" onClick={() => setPad(true)}>
            {[0, 1, 2].flatMap((r) =>
              [0, 1, 2].map((c) => <circle key={`${r}${c}`} cx={6 + c * 6} cy={6 + r * 6} r="2.1" />),
            )}
          </CallBtn>
          <CallBtn label="loa ngoài" on={speaker} onClick={() => setSpeaker((v) => !v)}>
            <path d="M3 9h3.5L11 5v14l-4.5-4H3z" />
            <path d="M14.5 9a4 4 0 0 1 0 6M17 6.5a7.5 7.5 0 0 1 0 11" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </CallBtn>
          <CallBtn label="thêm cuộc gọi" disabled>
            <path d="M11 4h2v7h7v2h-7v7h-2v-7H4v-2h7z" />
          </CallBtn>
          <CallBtn label="FaceTime" disabled>
            <path d="M3 7.5A1.5 1.5 0 0 1 4.5 6h10A1.5 1.5 0 0 1 16 7.5v9a1.5 1.5 0 0 1-1.5 1.5h-10A1.5 1.5 0 0 1 3 16.5zM17 10l4-2.5v9L17 14z" />
          </CallBtn>
          <CallBtn label="danh bạ" disabled>
            <circle cx="12" cy="9.5" r="3.2" />
            <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
              <circle cx="12" cy="12" r="9.2" />
              <path d="M6.6 18c1.2-2.1 3.1-3.2 5.4-3.2s4.2 1.1 5.4 3.2" />
            </g>
          </CallBtn>
        </div>
      )}

      <div className="call-bottom">
        <span />
        <button type="button" className="glass end-btn" aria-label="Kết thúc cuộc gọi" onClick={p.onHangup}>
          <svg width="34" height="34" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" style={{ transform: 'rotate(135deg)' }}>
            <path d={PHONE_PATH} />
          </svg>
        </button>
        {pad ? (
          <button type="button" className="hide-btn" onClick={() => setPad(false)}>
            Ẩn
          </button>
        ) : (
          <span />
        )}
      </div>
    </div>
  );
}

function ringingText(link: Link): string {
  if (link.mode === 'dialing') return 'đang nối tổng đài…';
  if (link.mode === 'matlab') return 'MATLAB đang đổ chuông…';
  return 'đang gọi…';
}

/** Huy hiệu ở góc ô phụ đề: cuộc gọi đi qua đâu, và phím MATLAB vừa nghe ra. */
function LineChip({ link, heard }: { link: Link; heard: Heard | null }) {
  if (link.mode === 'matlab') {
    const tip = `Tổng đài MATLAB${link.method ? ` · ${link.method}` : ''}: tổng đài đọc lại phím MATLAB nghe được`;
    return heard ? (
      <span className="line-chip on flash" key={heard.n} title={tip}>
        MATLAB nghe <b>{heard.key}</b>
      </span>
    ) : (
      <span className="line-chip on" title={tip}>
        <span className="dot" aria-hidden="true" />
        MATLAB
      </span>
    );
  }
  if (link.mode === 'lost') {
    return (
      <span className="line-chip lost" title="Mất đường dây tới MATLAB, tổng đài trong trang làm tiếp">
        <span className="dot" aria-hidden="true" />
        mất MATLAB
      </span>
    );
  }
  if (link.mode === 'local') {
    const tip =
      link.why === 'matlab'
        ? 'MATLAB chưa nối đường dây'
        : link.why === 'answer'
          ? 'MATLAB không nhấc máy'
          : 'Trang không chạy trên máy chủ có cầu nối';
    return (
      <span className="line-chip" title={`${tip}: tổng đài chạy trong trang`}>
        <span className="dot" aria-hidden="true" />
        trong trang
      </span>
    );
  }
  return null;
}

function CallBtn({
  label,
  on = false,
  disabled = false,
  onClick,
  children,
}: {
  label: string;
  on?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      className={`cbtn ${on ? 'on' : ''}`}
      disabled={disabled}
      aria-pressed={onClick && label !== 'bàn phím' ? on : undefined}
      onClick={onClick}
    >
      <span className="glass cbtn-circle">
        <svg width="30" height="30" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          {children}
        </svg>
      </span>
      <span className="cbtn-label">{label}</span>
    </button>
  );
}

function PadKey({
  k,
  on,
  onPress,
  onRelease,
}: {
  k: DtmfKey;
  on: boolean;
  onPress: (k: DtmfKey) => void;
  onRelease: (k: DtmfKey) => void;
}) {
  const up = () => onRelease(k);
  return (
    <button
      type="button"
      className={`glass pkey ${on ? 'on' : ''} ${k === '*' || k === '#' ? 'sym' : ''}`}
      aria-label={`Phím ${k}`}
      onPointerDown={(e) => {
        // Giữ con trỏ trên nút: kéo ngón tay ra ngoài vẫn nhận được pointerup.
        e.currentTarget.setPointerCapture(e.pointerId);
        onPress(k);
      }}
      onPointerUp={up}
      onPointerCancel={up}
      onLostPointerCapture={up}
      onContextMenu={(e) => e.preventDefault()}
    >
      <span className="pk-d">{k}</span>
      {LETTERS[k] && <span className="pk-l">{LETTERS[k]}</span>}
    </button>
  );
}
