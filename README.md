# Hệ thống phát và giải mã tín hiệu DTMF

Đề tài Chủ đề 4, môn Xử lý tín hiệu số, viết bằng MATLAB.

Mỗi phím điện thoại được mã hóa bằng tổng hai sóng sin, một tần số nhóm hàng và một tần số nhóm cột
(chuẩn ITU-T Q.23). Dự án gồm một bộ phát và ba bộ giải mã là FFT, Goertzel và ngân hàng bộ lọc IIR.
Ba bộ giải mã dùng chung cách chia khung và cùng tiêu chí nhận khung, nên chúng chỉ khác nhau ở bước
đo phổ. Nhờ vậy phép so sánh giữa chúng là công bằng.

|         | 1209 | 1336 | 1477 |
|---------|:----:|:----:|:----:|
| *697*   |  1   |  2   |  3   |
| *770*   |  4   |  5   |  6   |
| *852*   |  7   |  8   |  9   |
| *941*   |  \*  |  0   |  #   |

## Ba bộ giải mã

Tần số lấy mẫu 8000 Hz, mỗi âm dài 100 ms, nghỉ 50 ms.

| | Cách đo phổ | Khung | Phép nhân mỗi giây âm thanh |
|---|---|---|:--:|
| FFT | Phổ công suất, cửa sổ Hamming | N = 256, hop 128 | 273 000 |
| Goertzel | Chỉ tính 8 bin cần dùng | N = 205, hop 205 | 65 000 |
| Ngân hàng bộ lọc | 14 bộ cộng hưởng bậc 2 | N = 205, hop 205 | 672 000 |

```
dtmf_generate → dtmf_addnoise → dtmf_segment → [FFT | Goertzel | ngân hàng bộ lọc]
                                             → dtmf_decide → dtmf_debounce → dtmf_metrics
```

## Kết quả

Độ chính xác trung bình khi cộng nhiễu trắng, 20 chuỗi 12 phím mỗi mức SNR, `rng(2026)`.

| SNR [dB] | 0 | 2.5 | 5 | ≥ 7.5 |
|---|:--:|:--:|:--:|:--:|
| FFT | 0.00 | 0.16 | 0.93 | 1.00 |
| Goertzel | 0.00 | 0.35 | 0.93 | 1.00 |
| Ngân hàng bộ lọc | 0.01 | 0.96 | 1.00 | 1.00 |

Ngân hàng bộ lọc chịu nhiễu tốt nhất vì nó đo đúng tại tần số chuẩn. FFT và Goertzel đo tại tâm bin,
vốn lệch khỏi tần số chuẩn, nên mất một phần năng lượng. Goertzel cần ít phép nhân nhất, bằng một
phần tư FFT.

## Chạy thử

Đặt Current Folder là thư mục gốc repo rồi chạy.

```matlab
dtmf_setup                                        % nạp path, mỗi phiên một lần

[x, ~, meta] = dtmf_generate('0912345');
y            = dtmf_addnoise(x, 'snrDb', 15);
keysHat      = dtmf_decode_goertzel(y);
m            = dtmf_metrics(meta.keys, keysHat);  % m.acc là độ chính xác

DTMFApp          % giao diện tạo tín hiệu, cộng nhiễu, giải mã, mở tệp âm thanh
run_all_tests    % 266 ca
```

Sinh lại số liệu, hình cho báo cáo và bộ dữ liệu.

```matlab
addpath('scripts');
run_bench        % results/bench.mat
make_figures     % results/figures/
publish_figures  % chép hình sang report/template/Figures/
make_dataset     % data/wav/
```

## Bộ dữ liệu

`data/wav/` có 139 tệp âm thanh, đáp án ghi trong `manifest.csv`. Các tệp gồm tín hiệu sạch, nhiễu
trắng, điện lưới 50 Hz, tiếng nói, twist, lệch tần, nhịp bấm khác nhau, nhiều định dạng tệp và các
tệp không có phím nào. `tests/test_dataset.m` giải mã mọi tệp bằng cả ba phương pháp rồi đối chiếu
đáp án. Ngân hàng bộ lọc còn đọc nhầm hai tệp, ghi ở cột `ngoaiLe`.

## Trình diễn với trang web

Trang web trong `web/` gửi mẫu âm thanh sang MATLAB qua một cầu nối chạy cùng Vite
(cổng TCP 127.0.0.1:8765). MATLAB chỉ nhận âm thanh, không nhận tên phím.

*Giám định ghi âm.* Trang dựng một đoạn ghi âm có người bấm một số bí mật giữa tiếng ồn.
`DTMFForensic` đọc ra số, sau đó trang mới công bố số thật để đối chiếu.

1. `cd web`, `npm install`, `npm run dev:lan`.
2. Trong MATLAB chạy `dtmf_setup` rồi `DTMFForensic`.
3. Máy khác cùng mạng mở `http://<địa chỉ Network>:5173/#giam-dinh`, nhập số, bấm *Gửi cho MATLAB*.

*Tổng đài.* Trang là chiếc điện thoại gọi tới tổng đài. `DTMFLive` giải mã từng phím và gửi lại,
tổng đài trên trang chỉ đọc lại phím mà MATLAB nghe được.

1. `cd web`, `npm run dev`, mở http://localhost:5173.
2. Trong MATLAB chạy `dtmf_setup` rồi `DTMFLive`.
3. Bấm gọi, mở bàn phím và bấm số.

Lệnh khác trong `web/` là `npm test` (kiểm thử) và `npm run build` (một tệp HTML chạy offline).

## Cấu trúc

```
src/       phát tín hiệu, ba bộ giải mã, chia khung và đánh giá
app/       DTMFApp, DTMFForensic, DTMFLive và các thành phần giao diện
tests/     unit test (matlab.unittest)
scripts/   sinh số liệu, hình, bộ dữ liệu
data/      bộ dữ liệu wav
web/       trang web (React + Vite)
report/    báo cáo LaTeX
slides/    slide thuyết trình
```

## Yêu cầu

- MATLAB R2025a trở lên và Signal Processing Toolbox. Không cần Communications Toolbox.
- Node.js cho phần `web/`.

## Quy ước

- Goertzel và ngân hàng bộ lọc tự viết. Hàm `goertzel` của toolbox chỉ dùng để đối chứng trong test.
- Hàm trong `src/` không vẽ, không phát âm thanh, không in ra màn hình.
- Giao diện viết bằng `classdef`, không dùng `.mlapp`, để diff được và test được.
- Chỉ commit khi `run_all_tests` pass hết.

Chi tiết chữ ký hàm, thông số và số liệu đo nằm trong [CONTRACTS.md](CONTRACTS.md).
