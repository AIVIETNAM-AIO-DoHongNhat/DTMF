import { useEffect, useState, type ReactNode } from 'react';

/** Khung chuẩn của bố cục [px CSS]: trang được thiết kế vừa đúng khung này. */
const REF_W = 1200;
const REF_H = 900;
/** Hẹp hơn mức này thì bỏ khung, trang chảy dọc và cuộn như bình thường. */
const MIN_STAGE_W = 981;

interface Box {
  s: number;
  w: number;
  h: number;
}

function measure(): Box | null {
  const w = window.innerWidth;
  const h = window.innerHeight;
  if (w < MIN_STAGE_W) return null;
  // Lấy hệ số nhỏ hơn để vừa cả hai chiều; chiều còn dư được trải cho bố cục
  // (w / s >= REF_W, h / s >= REF_H), nên khung luôn phủ kín cửa sổ.
  const s = Math.min(h / REF_H, w / REF_W);
  return { s, w: w / s, h: h / s };
}

/**
 * Trên màn rộng, cả trang nằm gọn trong một màn hình ở zoom 100%: bố cục dựng
 * ở khung chuẩn rồi phóng đều bằng transform. Luôn bọc cùng một thẻ div để
 * React không dựng lại cây con (và mất cuộc gọi) khi đổi qua lại hai chế độ.
 */
export function Stage({ children }: { children: ReactNode }) {
  const [box, setBox] = useState<Box | null>(measure);

  useEffect(() => {
    const on = () => setBox(measure());
    window.addEventListener('resize', on);
    return () => window.removeEventListener('resize', on);
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle('staged', box !== null);
  }, [box]);

  return (
    <div
      className={box ? 'stage on' : 'stage'}
      style={box ? { width: box.w, height: box.h, transform: `scale(${box.s})` } : undefined}
    >
      {children}
    </div>
  );
}
