# Hợp đồng hàm - DTMF Project

Bản tham chiếu nhanh, offline (không cần mở lại kế hoạch). **Không tự đổi chữ ký hàm** - nếu cần đổi, báo tổ M trước.

## Chữ ký hàm bắt buộc

```matlab
%% Phát
[x, t, meta] = dtmf_generate(keys, opt)
y            = dtmf_addnoise(x, opt)

%% Tiền xử lý
seg = dtmf_segment(y, opt)

%% Ba bộ giải mã - CÙNG MỘT CHỮ KÝ
[keys, info] = dtmf_decode_fft(y, opt)
[keys, info] = dtmf_decode_goertzel(y, opt)
[keys, info] = dtmf_decode_filterbank(y, opt)
  % info.E        : 8 x nFrame  - công suất tại 7 tần số chuẩn + 1 hài bậc 2
  % info.rowIdx   : 1 x nFrame
  % info.colIdx   : 1 x nFrame
  % info.conf     : 1 x nFrame
  % info.tFrame   : 1 x nFrame
  % info.reject   : cellstr - 'twist' | 'level' | 'harmonic' | 'none'

%% Đánh giá
m = dtmf_metrics(keysTrue, keysHat)  % .acc .editDist .confusion (12x12)
```

## Luật cứng

- Hàm trong `src/` **không được** gọi `figure`, `plot`, `disp`, `sound`, `input`.
  Vẽ và phát âm thanh chỉ xảy ra trong `app/ui/*.m`.
- `app/dtmf_run.m` là lớp trung gian DUY NHẤT giữa UI và `src/`.
- Chỉ `scripts/dev_harness.m` được phép gọi `figure/plot/sound` để bạn tự test tay.

## Quy ước chú thích (comment)

- Viết tiếng Việt có dấu, file `.m` lưu dạng UTF-8 (không BOM).
- Mỗi hàm có khối help ngay dưới dòng `function`, theo thứ tự:
  1. **Dòng H1**: `%TEN_HAM Mô tả một dòng.` (tên hàm viết HOA, dùng cho `lookfor`).
  2. Cú pháp gọi + mô tả ngắn.
  3. `Đầu vào:` / `Tham số tên–giá trị (mặc định trong ngoặc):` / `Đầu ra:` - mỗi mục ghi **kích thước** (`1×N`), **kiểu** (`double`, `char`…) và **đơn vị trong ngoặc vuông** (`[Hz]`, `[s]`, `[dB]`, `[mẫu]`).
  4. `Cơ sở lý thuyết:` - công thức viết theo cú pháp MATLAB (`10*log10(...)`), nêu rõ chỉ số tính từ 0 hay 1.
  5. `Ví dụ:` - đoạn chạy được, ghi kết quả mong đợi.
  6. `Tham khảo:` - đánh số `[1]`, `[2]` theo kiểu IEEE; tài liệu nội bộ ghi "Gói đặc tả #n (tổ …)".
  7. `See also ...` - giữ nguyên tiếng Anh vì MATLAB dựa vào cụm này để tạo liên kết.
- Số thập phân trong comment dùng dấu chấm (`0.99`) để khớp cú pháp MATLAB.
- Nhãn công việc: `TODO(C):` (việc của coder), `LƯU Ý:` (ràng buộc bắt buộc).
- Không sửa các pragma `%#ok<...>` và định danh lỗi `'ham:loi'` (phải là ASCII).

## Thông số chốt sẵn

| Tham số | Giá trị |
|---|---|
| f_s | 8000 Hz |
| Tone / nghỉ | 100 ms / 50 ms |
| Khung Goertzel | N = 205 → Δf ≈ 39,02 Hz |
| Bin k (hàng) | 697→18, 770→20, 852→22, 941→24 |
| Bin k (cột) | 1209→31, 1336→34, 1477→38 |
| Khung FFT đối chứng | 256 điểm, Hamming, hop 128 |
| Dung sai tần số | nhận ≤ ±1,5% · từ chối ≥ ±3,5% |
| Twist | thuận ≤ 4 dB · nghịch ≤ 8 dB |
| Ngưỡng quyết định | đỉnh ≥ 6 dB so với bin nhì cùng nhóm; Σ8 bin ≥ 70% năng lượng khung |
| Cộng hưởng filter bank | r = 0,99 → BW ≈ 25 Hz |

## Ví dụ kiểm chứng Goertzel (đã tính sẵn)

```
N = 16, k = 3, x[n] = cos(2π·3n/16)
→ P = 64,000000   (đối chiếu lý thuyết: X[3] = N/2 = 8 ⇒ |X[3]|² = 64)
Sai lệch cho phép: < 1e-9  - xem tests/test_goertzel.m
```

## Cấu trúc thư mục

```
DMTF/
├─ src/
│  ├─ gen/      dtmf_table.m  dtmf_generate.m  dtmf_addnoise.m      (Coder + S1)
│  ├─ decode/   dtmf_decode_fft.m                                    (Coder + S2/R1)
│  │            goertzel_power.m  dtmf_decode_goertzel.m             (Coder + S2/R2)
│  │            design_bpf_bank.m dtmf_decode_filterbank.m           (Coder + S3/R3)
│  └─ util/     dtmf_segment.m  dtmf_decide.m  dtmf_metrics.m        (Coder)
├─ app/         dtmf_run.m  DTMFApp.mlapp (chưa tạo - của U1)
│  └─ ui/       ui_plot_wave.m ui_plot_spec.m ui_plot_bars.m ui_refresh.m
├─ tests/       test_generate.m test_goertzel.m run_all_tests.m
├─ scripts/     dev_harness.m   (script thử tay, không thuộc src/app/)
├─ data/        wav/  mat/      (S1 bỏ dataset, S3 bỏ coeffs.mat vào đây)
├─ results/     figures/
└─ docs/        report/  slides/  (không đặt code ở đây - Prism ở web riêng)
```
