# Hệ thống phát và giải mã tín hiệu DTMF

> Đề tài Chủ đề 4 · Xử lý tín hiệu số · MATLAB

DTMF (*Dual-Tone Multi-Frequency*, ITU-T Q.23) mã hóa mỗi phím điện thoại bằng tổng hai
sóng sin: một tần số nhóm hàng và một tần số nhóm cột. Dự án gồm một bộ phát tín hiệu và
**ba bộ giải mã** — FFT, thuật toán Goertzel, ngân hàng bộ lọc IIR — dùng chung một cách
chia khung và một luật quyết định, nhờ vậy so sánh được công bằng khi SNR giảm dần. Kết quả
trình bày qua giao diện `app/DTMFApp.m`.

|         | 1209 | 1336 | 1477 |
|---------|:----:|:----:|:----:|
| **697** |  1   |  2   |  3   |
| **770** |  4   |  5   |  6   |
| **852** |  7   |  8   |  9   |
| **941** |  \*  |  0   |  #   |

## Ba bộ giải mã

Tần số lấy mẫu 8000 Hz, tone 100 ms, nghỉ 50 ms.

| | Nguyên lý | Khung | Δf | Phép nhân / giây âm thanh |
|---|---|---|:--:|:--:|
| FFT | Phổ công suất, cửa sổ Hamming | N = 256, hop 128 | 31.25 Hz | 273 000 |
| Goertzel | IIR bậc 2, tính riêng 8 bin | N = 205, hop 205 | 39.02 Hz | **65 000** |
| Ngân hàng bộ lọc | 14 bộ cộng hưởng bậc 2 song song | N = 205, hop 205 | BW ≈ 25.5 Hz | 672 000 |

Goertzel chọn N = 205 để bin gần nhất lệch khỏi mọi tần số chuẩn không quá 1.4%, nằm trong
dung sai ±1.5% của ITU-T Q.24.

Cả ba đi qua **cùng bốn bước**, chỉ khác nhau ở bước đo phổ:

```
dtmf_generate → dtmf_addnoise → dtmf_segment → [FFT | Goertzel | ngân hàng bộ lọc]
                                             → dtmf_decide → dtmf_debounce → dtmf_metrics
```

`dtmf_decide` (năm điều kiện: đỉnh nổi ≥ 6 dB so với bin nhì cùng nhóm, twist trong giới hạn,
bảy bin giữ ≥ 70% năng lượng khung, hài bậc 2 đủ nhỏ) và `dtmf_debounce` là hàm **dùng
chung**, không bộ giải mã nào tự viết lại. Nhờ vậy khác biệt giữa ba phương pháp nằm đúng ở
chỗ đề tài muốn so sánh.

## Kết quả

Độ chính xác trung bình, nhiễu AWGN, 20 chuỗi 12 phím mỗi mức, `rng(2026)` cố định:

| SNR [dB] | 0 | 2.5 | 5 | ≥ 7.5 |
|---|:--:|:--:|:--:|:--:|
| FFT | 0.00 | 0.16 | 0.93 | 1.00 |
| Goertzel | 0.00 | 0.35 | 0.93 | 1.00 |
| Ngân hàng bộ lọc | 0.01 | **0.96** | 1.00 | 1.00 |

Ngân hàng bộ lọc bền hơn hẳn — ngược với trực giác "FFT mạnh nhất" — vì 14 bộ cộng hưởng
băng hẹp loại nhiễu ngoài băng **trước** khi đo năng lượng, trong khi FFT và Goertzel lấy
năng lượng khung thô làm mẫu số. Với nhiễu ù 50 Hz nó đạt 1.00 ngay từ 2.5 dB trong khi FFT
còn 0.00.

Goertzel cần ít phép nhân nhất, chỉ bằng 1/4 FFT, nhưng **không** chạy nhanh nhất: nó là
vòng lặp MATLAB thông dịch còn `fft` và `filter` là mã biên dịch.

## Chạy thử

Đặt Current Folder là thư mục gốc repo, nạp path một lần cho mỗi phiên:

```matlab
dtmf_setup
```

```matlab
[x, t, meta]    = dtmf_generate('0912345');          % tone 100 ms / nghỉ 50 ms
y               = dtmf_addnoise(x, 'snrDb', 15);     % AWGN, SNR = 15 dB
[keysHat, info] = dtmf_decode_goertzel(y);
m               = dtmf_metrics(meta.keys, keysHat);  % m.acc, m.editDist, m.confusion

DTMFApp          % giao diện: bấm phím để nghe, "Phát tín hiệu" -> "Giải mã"
run_all_tests    % 162 ca
```

Sinh lại số liệu và toàn bộ hình cho báo cáo (khoảng một phút):

```matlab
addpath('scripts');
run_bench        % -> results/bench.mat, không vẽ gì
make_figures     % -> results/figures/H*.png (300 dpi) + H*.pdf (vector)
publish_figures  % -> report/template/Figures/, chép một chiều
```

`results/` không nằm trong git vì dựng lại được; bản đi vào git là bản đã công bố ở
`report/template/Figures/`.

## Cấu trúc

```
src/gen/      dtmf_table, dtmf_generate, dtmf_addnoise
src/decode/   FFT, Goertzel, ngân hàng bộ lọc
src/util/     chia khung, luật quyết định, gộp phím, đánh giá
app/          DTMFApp (giao diện) · dtmf_run (lớp trung gian) · ui/ (vẽ, phát tiếng)
tests/        unit test (matlab.unittest)
scripts/      dev_harness · make_coeffs · run_bench · make_figures · publish_figures
data/         wav/, mat/ — coeffs.mat sinh tại chỗ, không nằm trong git
results/      bench.mat + figures/ — máy sinh ra, không nằm trong git
docs/         báo cáo, slide, kế hoạch
```

## Yêu cầu

- MATLAB **R2021b** trở lên (đang phát triển trên R2026a) và **Signal Processing Toolbox**.
- Communications Toolbox **không cần**: `dtmf_addnoise` tự tính nhiễu theo công suất mục
  tiêu thay vì gọi `awgn`, nhờ vậy SNR chính xác và tái lập được với `rng` cố định.

**Nguyên tắc dùng toolbox:** tự cài đặt phần được chấm, dùng thư viện cho phần phụ trợ.
`goertzel_power` và ngân hàng bộ lọc cộng hưởng phải tự viết; `goertzel` của toolbox chỉ
xuất hiện trong `tests/test_goertzel.m` với vai trò phép đối chứng độc lập.

## Ghi chú thiết kế

- Giao diện là `classdef` tự dựng `uifigure`, **không** phải `.mlapp` — file `.mlapp` là ZIP
  nhị phân, không diff, không merge và không chạy được trong `matlab -batch`. Nhờ vậy tầng
  giao diện cũng nằm trong `run_all_tests`: `DTMFApp('off')` dựng cửa sổ ẩn, test gọi thẳng
  callback rồi đọc `app.LblDecoded.Text`.
- Hàm trong `src/` không được gọi `figure`, `plot`, `disp`, `sound`, `input`. Vẽ và phát âm
  thanh chỉ nằm trong `app/ui/*.m` và ba script `dev_harness`, `run_bench`, `make_figures`.
- Làm việc trực tiếp trên nhánh `main`; chỉ commit khi `run_all_tests` pass hết.

## Tài liệu

- [CONTRACTS.md](CONTRACTS.md) — chữ ký hàm, thông số đã chốt, quy ước chú thích, số liệu đo.
- [docs/study/KE_HOACH.md](docs/study/KE_HOACH.md) — kế hoạch triển khai và tiến độ.
- [docs/ui_naming.md](docs/ui_naming.md) — quy ước tên component của giao diện.
