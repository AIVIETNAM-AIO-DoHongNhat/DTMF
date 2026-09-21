# Hợp đồng hàm - DTMF Project

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
  % info.E        : 8 x nFrame  - công suất tại 7 tần số chuẩn + 1 hài bậc 2,
  %                 ĐÃ CHUẨN HÓA theo năng lượng khung - xem "Bốn quyết định chốt" (a)
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
- Được phép gọi `figure/plot/sound` chỉ trong ba script sau:
  `scripts/dev_harness.m`, `scripts/run_bench.m`, `scripts/make_figures.m`.

## Luật dùng toolbox

**Tự cài đặt phần được chấm, dùng thư viện cho phần phụ trợ.**

| Hạng mục | Cách làm | Lý do |
|---|---|---|
| `goertzel_power` (IIR bậc 2) | **TỰ VIẾT** | Đề tài yêu cầu *cài đặt* Goertzel, không phải *sử dụng* |
| Ngân hàng bộ lọc cộng hưởng | **TỰ VIẾT** | Công thức cho phép dẫn giải `r = 0.99` và `BW ≈ 25.5 Hz` |
| Luật quyết định, debounce, metrics | **TỰ VIẾT** | Không có hàm dựng sẵn; là phần lõi của bài |
| Cộng nhiễu theo SNR | **TỰ VIẾT** | Chưa cài Communications Toolbox; công thức tay chính xác hơn `awgn` |
| `hamming`, `tukeywin` | Dùng toolbox | Cửa sổ là chi tiết phụ trợ |
| `spectrogram` | Dùng toolbox | Chỉ để hiển thị trong `app/ui/ui_plot_spec.m` |
| `freqz`, `zplane` | Dùng toolbox | Chỉ để kiểm chứng và vẽ, không nằm trong luồng giải mã |

- **`goertzel` của Signal Processing Toolbox chỉ được xuất hiện trong `tests/test_goertzel.m`**
  với vai trò phép đối chứng độc lập cho `goertzel_power`. Gọi nó trong `src/` là vi phạm.
- **`filterDesigner` không dùng để sinh hệ số nộp bài.** Hệ số của nó là dãy số không giải
  thích được; `design_bpf_bank` phải dựng bộ lọc bằng công thức cộng hưởng.
- Yêu cầu môi trường: MATLAB + Signal Processing Toolbox. **Không** phụ thuộc
  Communications Toolbox, Image Processing Toolbox hay bất kỳ toolbox nào khác.

## Quy ước chú thích (comment)

- Viết tiếng Việt có dấu, file `.m` lưu dạng UTF-8 (không BOM).
  `.gitattributes` đã đặt `working-tree-encoding=UTF-8` nên git sẽ báo lỗi ngay lúc commit
  nếu file bị ghi nhầm bằng ANSI hoặc UTF-16.
- Mỗi hàm có khối help ngay dưới dòng `function`, theo thứ tự dưới đây.
  **Mẫu chuẩn: `src/gen/dtmf_generate.m` và `src/decode/goertzel_power.m`** - viết hàm mới
  thì mở một trong hai file đó ra chép bố cục, đừng tự nghĩ lại.
  1. **Dòng H1**: `%TEN_HAM Mô tả một dòng` (tên hàm viết HOA, dùng cho `lookfor`; **không
     có dấu chấm cuối**).
  2. **Một dòng đời thường** ngay dưới H1, lùi 1 dấu cách: hàm này làm gì, nói như với người
     chưa học DSP. Đây là dòng người đọc báo cáo đọc trước tiên.
  3. Cú pháp gọi `[OUT] = TEN_HAM(IN)` + mô tả ngắn. Có tham số tên–giá trị thì thêm một câu
     trỏ xuống danh sách bên dưới.
  4. **Cách hoạt động** - công thức viết theo cú pháp MATLAB (`10*log10(...)`), nêu rõ chỉ số
     tính từ 0 hay 1. Đặt **ngay sau cú pháp, trước `Input:`**: người đọc cần hiểu hàm làm
     gì trước khi tra tên từng tham số. Không cần tiêu đề `Cơ sở lý thuyết:`.
  5. `Input:` / `Tham số tên–giá trị (mặc định trong ngoặc):` / `Output:` - tiêu đề mục viết
     tiếng Anh, **nội dung viết tiếng Việt**. Mỗi mục viết `tên: kích thước kiểu, mô tả`, ghi
     **kích thước** (`1×N`), **kiểu** (`double`, `char`…) và **đơn vị trong ngoặc vuông**
     (`[Hz]`, `[s]`, `[dB]`, `[mẫu]`). Dùng dấu **hai chấm** sau tên, không dùng gạch ngang.
  6. `Example:` - đoạn chạy được; kết quả mong đợi ghi ở **comment cuối dòng** (`% 64`), không
     tách thành dòng riêng. Đây là mục CUỐI của help.
- **Không đặt `See also` trong help.** Liên kết giữa các hàm đã có ở sơ đồ phụ thuộc trong tài
  liệu này; giữ thêm một bản trong help thì đổi tên hàm là phải sửa hai nơi.
- **Không đặt mục `Tham khảo:` trong help.** Trích dẫn đầy đủ nằm ở
  `report/template/references.bib`; trong help chỉ trỏ ngắn khi thật cần ("xem CONTRACTS.md",
  "Gói đặc tả #4"). Lý do: help mà chép lại thư mục thì sớm muộn hai bên lệch nhau, mà bản đi
  vào báo cáo là bản trong `.bib`.
- Help kết thúc ngay trên dòng `arguments`, **không** chèn dòng `%` trống ngăn cách.
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

## Bốn quyết định chốt bổ sung

Bốn điểm dưới đây trước kia còn treo. Ba điểm đầu chặn `dtmf_decide`, điểm (d) chặn
`dtmf_segment`. Nay chốt như sau.

### (a) Chuẩn hóa `E` - bộ giải mã tự làm, KHÔNG đổi chữ ký hàm

Luật "Σ8 bin ≥ 70% năng lượng khung" cần năng lượng toàn khung, trong khi
`dtmf_decide(E, opt)` chỉ nhận `E (8,:)`. Giải pháp: **mỗi bộ giải mã chia `E` cho năng
lượng khung trước khi gọi `dtmf_decide`**, khi đó `sum(E(1:7))` CHÍNH LÀ tỉ lệ năng lượng.

```matlab
% Goertzel (không cửa sổ)
E = E_raw / (frameN * sum(frame.^2) / 2);
% FFT (có Hamming) - chia cho năng lượng ĐÃ nhân cửa sổ
E = E_raw / (frameN * sum((w.*frame).^2) / 2);
% Ngân hàng bộ lọc (miền thời gian)
E = E_raw / sum(frame.^2);
```

Nhờ vậy `E` là đại lượng không thứ nguyên, **so sánh được giữa ba phương pháp**, và đường
ngưỡng `thr` duy nhất trong `ui_plot_bars` mới có nghĩa trên cả ba. Đây cũng là cổng chặn
mức tuyệt đối duy nhất: bốn điều kiện còn lại đều là tỉ số nên bất biến theo thang đo,
một khung toàn nhiễu vẫn qua hết; sau chuẩn hóa nó chỉ đạt ≈ 0,07 nên bị loại đúng.

LƯU Ý: với ngưỡng 0,70 đã chốt, cách này tạo một vách chính xác ở SNR ≈ 8 dB - dưới mức
đó mọi khung bị loại với `reject = 'level'`. Đây là kết quả có chủ đích (chống talk-off),
không phải lỗi. `scripts/run_bench.m` quét thêm `energyRatio` ∈ {0,70 · 0,40 · 0}.

### (b) Bin hài bậc 2 - thích nghi theo từng khung

```
k_peak = argmax E(j), j = 1..7          % bin chuẩn mạnh nhất, KHÔNG phải 1633 Hz
k_harm = min(2*k_peak, floor(frameN/2)) % N = 205 → ≤ 102 ; N = 256 → ≤ 128
E(8)   = công suất tại bin k_harm
Điều kiện 5: E(8) <= 0.5*min(rowPeak, colPeak), ngược lại reject = 'harmonic'
```

`floor(N/2)` thực tế không bao giờ cắt (xấu nhất `2*38 = 76 <= 102`), chỉ là chốt phòng vệ.

Vì `E(8)` phụ thuộc từng khung nên ngân hàng bộ lọc cố định 8 bộ không làm được.
Do đó `design_bpf_bank` nhận thêm tham số `'withHarm' (1,1) logical = true` và trả về
**1×14**: 7 bộ cộng hưởng chuẩn + 7 bộ tại tần số gấp đôi. `dtmf_decode_filterbank` lọc
qua cả 14, mỗi khung lấy `d = argmax E(1:7)` rồi gán `E(8,i) = E_harm(d,i)`.

### (c) Công thức `info.conf`

```
conf = 0                                             nếu reject ~= 'none'
conf = rho * min(1, min(dRow, dCol) / (2*peakDb))    nếu reject == 'none'
   rho  = sum(E(1:7))                                (đã chuẩn hóa theo (a))
   dRow = 10*log10(rowPeak/rowPeak2)
   dCol = 10*log10(colPeak/colPeak2)
```

Thuộc [0, 1], bằng 0 khi khung bị loại, giảm đơn điệu theo SNR.
`ui_refresh` chọn khung hiển thị bằng `[~, iSel] = max(info.conf)`.

### (d) Mốc thời gian của `dtmf_segment` - quy ước THỜI LƯỢNG

Help của `dtmf_segment` chỉ mô tả `.tEnd` bằng lời ("thời điểm kết thúc khung"), không có
công thức, nên hai cách hiểu đều hợp lý. Chốt:

```
tStart = (idx(1) - 1)/fs        % mốc thời gian của mẫu đầu, t = 0 tại y(1)
tEnd   =  idx(2)     /fs        % = tStart + frameN/fs
```

Hệ quả `tEnd - tStart = frameN/fs` (25,625 ms với `frameN = 205`) **đúng bằng thời lượng
khung** - cùng quy ước với `dtmf_generate`, nơi `meta.offsets - meta.onsets` bằng đúng
`toneMs` chứ không thiếu 1 mẫu.

Khi `hop = frameN` thì `seg(i).tEnd == seg(i+1).tStart` khít tuyệt đối, không có khe hở
1 mẫu - `ui_plot_wave` vẽ ranh giới khung không phải xử lý ngoại lệ.

Còn treo (sẽ chốt ở Buổi 4, khi viết bộ giải mã đầu tiên): `info.tFrame` hiện chỉ được mô tả
là "thời điểm của khung [s]" - lấy `seg.tStart` hay tâm khung `(tStart+tEnd)/2` đều thỏa điều
kiện "tăng ngặt" trong `test_decode_goertzel`. Chốt gì cũng được, miễn CẢ BA bộ giải mã lấy
giống nhau, nếu không biểu đồ chồng ba phương pháp sẽ lệch trục thời gian.

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
│  ├─ gen/      dtmf_table.m  dtmf_generate.m  dtmf_addnoise.m
│  ├─ decode/   dtmf_decode_fft.m
│  │            goertzel_power.m  dtmf_decode_goertzel.m
│  │            design_bpf_bank.m dtmf_decode_filterbank.m
│  └─ util/     dtmf_segment.m  dtmf_decide.m  dtmf_metrics.m
├─ app/         dtmf_run.m   DTMFApp.m  (classdef dựng uifigure - xem ghi chú dưới)
│  └─ ui/       ui_plot_wave.m ui_plot_spec.m ui_plot_bars.m ui_refresh.m ui_play.m
├─ tests/       test_generate.m test_goertzel.m run_all_tests.m  (+ các test bổ sung)
├─ scripts/     dev_harness.m  make_coeffs.m  run_bench.m  make_figures.m
├─ data/        wav/  mat/      (coeffs.mat sinh bằng scripts/make_coeffs.m)
├─ results/     figures/  bench.mat
└─ docs/        report/  slides/  study/KE_HOACH.md
```

**Về giao diện:** dùng `app/DTMFApp.m` dạng `classdef ... < handle` tự dựng `uifigure`,
KHÔNG dùng `.mlapp`. Lý do: `.mlapp` là file ZIP nhị phân, không diff/merge được và không
thể test tự động. `ui_refresh.m` chỉ đụng tới `app.AxWave`, `app.AxSpec`, `app.AxBars`,
`app.TxtLog`, `app.LblDecoded`, `app.S` nên một `classdef` có đúng các property đó thỏa
mãn hợp đồng y hệt class do App Designer sinh ra, mà lại kiểm được bằng `run_all_tests`.
Tên component vẫn tuân thủ `docs/ui_naming.md`.
