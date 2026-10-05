// Mã hóa mẫu tín hiệu thành tệp WAV PCM 16 bit đơn kênh.
// MATLAB đọc lại bằng audioread rồi đưa thẳng vào dtmf_decode_*.

/** Mẫu trong [-1, 1] -> ArrayBuffer của một tệp WAV hoàn chỉnh. */
export function encodeWav(x: Float32Array, fs: number): ArrayBuffer {
  const bytesPerSample = 2;
  const dataBytes = x.length * bytesPerSample;
  const buf = new ArrayBuffer(44 + dataBytes);
  const v = new DataView(buf);

  const ascii = (off: number, s: string) => {
    for (let i = 0; i < s.length; i++) v.setUint8(off + i, s.charCodeAt(i));
  };

  ascii(0, 'RIFF');
  v.setUint32(4, 36 + dataBytes, true);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  v.setUint32(16, 16, true); // cỡ khối fmt
  v.setUint16(20, 1, true); // PCM
  v.setUint16(22, 1, true); // đơn kênh
  v.setUint32(24, fs, true);
  v.setUint32(28, fs * bytesPerSample, true); // byte mỗi giây
  v.setUint16(32, bytesPerSample, true); // byte mỗi khung mẫu
  v.setUint16(34, 16, true); // bit mỗi mẫu
  ascii(36, 'data');
  v.setUint32(40, dataBytes, true);

  for (let i = 0; i < x.length; i++) {
    // Cắt ở ±1 rồi đổi sang số nguyên 16 bit có dấu.
    const s = Math.max(-1, Math.min(1, x[i]));
    v.setInt16(44 + i * bytesPerSample, Math.round(s < 0 ? s * 0x8000 : s * 0x7fff), true);
  }
  return buf;
}
