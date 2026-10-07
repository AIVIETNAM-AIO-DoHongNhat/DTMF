import { StrictMode, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { FORENSIC_HASH } from './components/ModeSwitch';
import { Forensic } from './forensic/Forensic';
import './styles.css';

/** Hai màn trên cùng một trang, chọn theo phần # của địa chỉ. */
function Root() {
  const [hash, setHash] = useState(location.hash);
  useEffect(() => {
    // Màn hẹp cuộn dọc: sang màn kia thì về đầu trang.
    const on = () => {
      setHash(location.hash);
      scrollTo(0, 0);
    };
    window.addEventListener('hashchange', on);
    return () => window.removeEventListener('hashchange', on);
  }, []);
  return hash === FORENSIC_HASH ? <Forensic /> : <App />;
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
);
