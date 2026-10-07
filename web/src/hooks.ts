import { useLayoutEffect, useRef, useState } from 'react';

// Hai hook đo đều đo lần đầu trong useLayoutEffect, tức là trước khi trình
// duyệt vẽ: khung hình đầu tiên đã có biểu đồ đúng cỡ. Đo trong useEffect thì
// mỗi lần đổi màn có một khung hình trống rồi biểu đồ mới bật ra, đẩy phần
// bên dưới nhảy theo.

/** Bề rộng hiện tại của một phần tử [px CSS], cho các biểu đồ SVG. */
export function useWidth<T extends HTMLElement>(): [React.RefObject<T | null>, number] {
  const ref = useRef<T | null>(null);
  const [w, setW] = useState(0);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const read = () => setW(el.clientWidth);
    read();
    const ro = new ResizeObserver(read);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, w];
}

/** Bề rộng và chiều cao hiện tại của một phần tử [px CSS], cho hình SVG lấp đầy khung chứa. */
export function useSize<T extends HTMLElement>(): [React.RefObject<T | null>, { w: number; h: number }] {
  const ref = useRef<T | null>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const read = () => {
      const w = el.clientWidth;
      const h = el.clientHeight;
      setSize((s) => (s.w === w && s.h === h ? s : { w, h }));
    };
    read();
    const ro = new ResizeObserver(read);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, size];
}
