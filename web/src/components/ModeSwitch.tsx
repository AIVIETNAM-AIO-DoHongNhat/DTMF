// Công tắc đổi giữa hai màn của trang: điện thoại minh họa và giám định ghi âm.

/** Địa chỉ của màn giám định: http://<máy>:5173/#giam-dinh. */
export const FORENSIC_HASH = '#giam-dinh';

type Mode = 'phone' | 'forensic';

const MODES: { id: Mode; href: string; label: string }[] = [
  { id: 'phone', href: '#', label: 'Điện thoại' },
  { id: 'forensic', href: FORENSIC_HASH, label: 'Giám định' },
];

/** Mỗi nấc là một liên kết đổi phần # của địa chỉ, nên nút Back của trình duyệt cũng quay về được. */
export function ModeSwitch({ current }: { current: Mode }) {
  return (
    <nav className="mode" aria-label="Chọn màn">
      {MODES.map((m) => (
        <a key={m.id} href={m.href} aria-current={m.id === current ? 'page' : undefined}>
          {m.label}
        </a>
      ))}
    </nav>
  );
}
