// Mảnh giao diện dùng chung: icon, thanh trượt.

import type { CSSProperties, ReactNode } from 'react';

type IconName = 'play' | 'stop' | 'download' | 'x';

const PATHS: Record<IconName, ReactNode> = {
  play: <path d="M5 3.5v9l7.5-4.5z" fill="currentColor" stroke="none" />,
  stop: <rect x="4" y="4" width="8" height="8" rx="1.2" fill="currentColor" stroke="none" />,
  download: <path d="M8 2.5v8m0 0L4.8 7.3M8 10.5l3.2-3.2M3 13.5h10" />,
  x: <path d="M4.5 4.5l7 7m0-7l-7 7" />,
};

export function Icon({ name, size = 16 }: { name: IconName; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[name]}
    </svg>
  );
}

/** Biến toán học in nghiêng, có thể kèm chỉ số dưới: <V v="A" s="R" /> là A_R. */
export function V({ v, s }: { v: string; s?: string }) {
  return (
    <>
      <i className="var">{v}</i>
      {s && <sub>{s}</sub>}
    </>
  );
}

interface SliderProps {
  id: string;
  label: ReactNode;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (v: number) => void;
  display: ReactNode;
  note?: ReactNode;
}

/** Thanh trượt có nhãn, giá trị và phần đã kéo tô mực. */
export function Slider({ id, label, value, min, max, step, onChange, display, note }: SliderProps) {
  const p = ((value - min) / (max - min)) * 100;
  return (
    <div className="field">
      <div className="field-head">
        <label htmlFor={id}>{label}</label>
        <output htmlFor={id}>{display}</output>
      </div>
      <input
        id={id}
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        style={{ '--p': `${p}%` } as CSSProperties}
        onChange={(e) => onChange(Number(e.target.value))}
      />
      {note && <p className="field-note">{note}</p>}
    </div>
  );
}
