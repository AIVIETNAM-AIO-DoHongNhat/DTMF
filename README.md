# Hệ thống phát và giải mã tín hiệu DTMF

> Đề tài Chủ đề 4 - Xử lý tín hiệu số · MATLAB

## Tóm tắt

DTMF (*Dual-Tone Multi-Frequency*, ITU-T Q.23) mã hóa mỗi phím điện thoại bằng tổng hai sóng sin: một tần số thuộc nhóm thấp (hàng) và một tần số thuộc nhóm cao (cột). Dự án xây dựng một bộ phát tín hiệu DTMF và **ba bộ giải mã**: FFT, thuật toán Goertzel và ngân hàng bộ lọc IIR. Cả ba bộ giải mã dùng chung một cách chia khung và một luật quyết định, nhờ vậy có thể so sánh công bằng độ chính xác của chúng khi SNR giảm dần. Kết quả được trình bày qua giao diện MATLAB App Designer.


## Cơ sở lý thuyết

**Bảng tần số** (Hz):

|         | 1209 | 1336 | 1477 |
|---------|:----:|:----:|:----:|
| **697** |  1   |  2   |  3   |
| **770** |  4   |  5   |  6   |
| **852** |  7   |  8   |  9   |
| **941** |  \*  |  0   |  #   |

**Mô hình tín hiệu** của một phím ở hàng $r$, cột $c$:

$$x(t) = \sin(2\pi f_r t) + g\,\sin(2\pi f_c t), \qquad g = 10^{\,\text{twist}_{\text{dB}}/20}$$

**Ba phương pháp giải mã** (tần số lấy mẫu $f_s = 8000$ Hz):

| Phương pháp | Nguyên lý | Tham số | Độ phân giải $\Delta f$ | Chi phí mỗi khung |
|---|---|---|---|---|
| FFT | Phổ công suất $\lvert X[k]\rvert^2$, cửa sổ Hamming | $N = 256$, hop 128 | 31.25 Hz | $O(N\log N)$ |
| Goertzel | Bộ lọc IIR bậc 2, tính riêng từng bin | $N = 205$, 8 bin | 39.02 Hz | $O(KN)$, $K = 8$ |
| Ngân hàng bộ lọc | 8 bộ cộng hưởng bậc 2 chạy song song | $r = 0.99$ | BW ≈ 25 Hz | $O(KN)$ |

Với Goertzel, chọn $N = 205$ để bin gần nhất lệch khỏi mọi tần số chuẩn không quá 1.4%, tức nằm trong dung sai nhận ±1.5% của ITU-T Q.24.

**Luật quyết định** (dùng chung cho cả ba bộ giải mã, cài trong `dtmf_decide`): một khung được chấp nhận khi thỏa đồng thời các điều kiện sau.
- Đỉnh của mỗi nhóm cao hơn đỉnh thứ nhì trong cùng nhóm ít nhất 6 dB.
- Twist nằm trong giới hạn: thuận ≤ 4 dB, nghịch ≤ 8 dB.
- Tổng công suất 8 bin chiếm ít nhất 70% năng lượng khung.
- Hài bậc 2 đủ nhỏ, để phân biệt tone với tiếng nói.

## Luồng xử lý

```
dtmf_generate → dtmf_addnoise → dtmf_segment → ┬ dtmf_decode_fft        ┬ → dtmf_decide → dtmf_metrics
                                               ├ dtmf_decode_goertzel   ┤
                                               └ dtmf_decode_filterbank ┘
```

## Cấu trúc thư mục

```
src/gen/      Phát tín hiệu: dtmf_table, dtmf_generate, dtmf_addnoise
src/decode/   Giải mã: FFT, Goertzel, ngân hàng bộ lọc
src/util/     Chia khung, luật quyết định, đánh giá
app/          dtmf_run (lớp trung gian) + app/ui/ (các hàm vẽ)
tests/        Unit test (matlab.unittest)
scripts/      dev_harness.m - kịch bản thử tay
data/         wav/, mat/ (tập dữ liệu, hệ số bộ lọc)
docs/         Báo cáo, slide, tài liệu tham khảo
```

## Yêu cầu

- MATLAB **R2021b** trở lên.
- Signal Processing Toolbox (`goertzel`, `hamming`, `spectrogram`).
- Communications Toolbox - *tùy chọn*, chỉ cần khi dùng `awgn`.

## Sử dụng

```matlab
addpath(genpath('src'));
[x, t, meta]    = dtmf_generate('0912345');          % fs = 8000 Hz, tone 100 ms / nghỉ 50 ms
y               = dtmf_addnoise(x, 'snrDb', 15);     % AWGN, SNR = 15 dB
[keysHat, info] = dtmf_decode_goertzel(y);
m               = dtmf_metrics(meta.keys, keysHat);  % m.acc, m.editDist, m.confusion
```

Chạy toàn bộ test:

```matlab
run_all_tests
```

## Quy ước

- Chữ ký hàm, thông số đã chốt và quy ước chú thích xem trong [CONTRACTS.md](CONTRACTS.md).
- Hàm trong `src/` **không** được gọi `figure`, `plot`, `disp`, `sound`, `input`. Việc vẽ và phát âm thanh chỉ nằm trong `app/ui/` hoặc `scripts/dev_harness.m`.
- Làm việc trên nhánh `dev`; chỉ merge khi `run_all_tests` pass hết.
