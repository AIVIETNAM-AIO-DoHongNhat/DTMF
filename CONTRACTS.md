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
  %                 ĐÃ CHUẨN HÓA theo năng lượng khung - xem "Năm quyết định chốt" (a)
  % info.rowIdx   : 1 x nFrame
  % info.colIdx   : 1 x nFrame
  % info.conf     : 1 x nFrame
  % info.tFrame   : 1 x nFrame - TÂM khung, xem "Năm quyết định chốt" (e)
  % info.reject   : cellstr - 'twist' | 'level' | 'harmonic' | 'none'

%% Đánh giá
m = dtmf_metrics(keysTrue, keysHat)  % .acc .editDist .confusion (12x12)
```

## Luật cứng

- **Mọi giá trị rỗng trong dự án là `1×0`, KHÔNG phải `0×0`.** Đã kiểm: `dtmf_segment` trả
  `1×0`, mọi trường của `info` trả `1×0`, và `dtmf_generate('')` trả `meta.keys` cỡ `1×0` vì
  khối `arguments keys (1,:) char` tự ép `''` thành `1×0`. Hai cỡ này **không** bằng nhau với
  `strcmp` lẫn `isequal`, nên một hàm trả `''` (0×0) sẽ làm ca round-trip chuỗi rỗng báo sai
  dù giải mã đúng. Trong test, kiểm rỗng bằng `verifyEmpty` + `verifyClass`, đừng
  `verifyEqual(x, '')`.
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
  4. **`Các bước hoạt động:`** - tiêu đề viết đúng như vậy, không thêm bớt chữ nào, đặt
     **ngay sau cú pháp, trước `Input:`**: người đọc cần hiểu hàm làm gì trước khi tra tên
     từng tham số. Bên dưới là danh sách **đánh số** theo đúng thứ tự các khối trong thân
     hàm, mỗi bước một đến hai dòng; công thức viết theo cú pháp MATLAB (`10*log10(...)`),
     nêu rõ chỉ số tính từ 0 hay 1. Hàm chỉ có một công thức thì vẫn giữ tiêu đề, bên dưới
     là các bước của chính công thức đó. Câu dẫn hoặc ghi chú đi kèm đặt ở dòng **trên**
     tiêu đề hoặc **dưới** danh sách, không nhét vào dòng tiêu đề.
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

## Năm quyết định chốt bổ sung

Năm điểm dưới đây trước kia còn treo. Ba điểm đầu chặn `dtmf_decide`, điểm (d) chặn
`dtmf_segment`, điểm (e) chặn cả ba bộ giải mã. Nay chốt như sau.

### (a) Chuẩn hóa `E` - bộ giải mã tự làm, KHÔNG đổi chữ ký hàm

Luật "Σ8 bin ≥ 70% năng lượng khung" cần năng lượng toàn khung, trong khi
`dtmf_decide(E, opt)` chỉ nhận `E (8,:)`. Giải pháp: **mỗi bộ giải mã chia `E` cho năng
lượng khung trước khi gọi `dtmf_decide`**, khi đó `sum(E(1:7))` CHÍNH LÀ tỉ lệ năng lượng.

```matlab
% Goertzel (không cửa sổ)
E = E_raw / (frameN * sum(frame.^2) / 2);
% FFT (có Hamming) - phải BÙ ĐỘ LỢI COHERENT của cửa sổ, xem ghi chú bên dưới
cg = sum(w)^2 / (frameN * sum(w.^2));           % Hamming(256) -> 0,7317
E  = E_raw / (frameN * sum((w.*frame).^2) / 2 * cg);
% Ngân hàng bộ lọc (miền thời gian)
E = E_raw / sum(frame.^2);
```

Nhờ vậy `E` là đại lượng không thứ nguyên, **so sánh được giữa ba phương pháp**, và đường
ngưỡng `thr` duy nhất trong `ui_plot_bars` mới có nghĩa trên cả ba. Đây cũng là cổng chặn
mức tuyệt đối duy nhất: bốn điều kiện còn lại đều là tỉ số nên bất biến theo thang đo,
một khung toàn nhiễu vẫn qua hết; sau chuẩn hóa nó chỉ đạt ≈ 0,07 nên bị loại đúng.

**Vì sao nhánh FFT cần `cg`** (sửa ngày 21/09/2026, sau khi đo bằng `matlab -batch`): nhân
cửa sổ làm tụt biên độ vạch phổ nhiều hơn làm tụt năng lượng khung, nên tỉ lệ đo được bị
kéo xuống một hằng số. Với một tone thuần đúng tâm bin, `sum(E(1:7))` không thể vượt quá
`cg = (Σw)²/(N·Σw²)`; Hamming cho `cg = 0,7317`, tức **trần lý thuyết chỉ hơn ngưỡng 0,70
đúng 0,03**, và một khung DTMF thật đo được **0,6298 - nằm DƯỚI ngưỡng**. Hệ quả nếu bỏ
`cg`: `dtmf_decode_fft` loại 100% số khung, trả về chuỗi rỗng ở mọi mức SNR.

Đo trên chuỗi 41 phím (đi hết 41 cách căn lề khung), `frameN=256, hop=128`:

| Chuẩn hóa | Giải mã đúng | Khung bị loại giữa tone | `rho` nhỏ nhất của khung được nhận |
|---|:--:|:--:|:--:|
| không có `cg` | 0/41 | 180 | (không khung nào được nhận) |
| **có `cg`** | **41/41** | **0** | **0,7079** |

Con số cuối là điều đáng nhớ: Goertzel đo được 0,7080 trên cùng chuỗi. Hai phương pháp rơi
đúng cùng một thang - đó chính là điều mục (a) hứa hẹn, và công thức thiếu `cg` phá hỏng
chính lời hứa đó. Kiểm tra tính nhất quán: thay `w = ones(1,frameN)` thì `cg = 1` và công
thức FFT thu về đúng công thức Goertzel.

LƯU Ý - vách độ chính xác theo SNR. Ngưỡng 0,70 tạo một vách, nhưng **không nằm ở 8 dB và
không dốc đứng** như bản đặc tả đầu tiên ghi. Đo ngày 21/09/2026, nhiễu `awgn`, 20 chuỗi
12 phím mỗi mức, `rng(2026)`:

| SNR [dB] | 30 | 20 | 15 | 12 | 10 | 8 | 6 | 4 | 0 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| acc | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | **1,00** | 0,85 | 0,40 | 0,00 |

Tại đúng 8 dB độ chính xác vẫn tuyệt đối; vách nằm quanh **6 dB** và **dốc dần** chứ không
phải "mọi khung bị loại". Đây là kết quả có chủ đích (chống talk-off), không phải lỗi, và
lời khuyên demo ở SNR ≥ 10 dB vẫn còn dư 2 dB. `scripts/run_bench.m` quét thêm
`energyRatio` ∈ {0,70 · 0,40 · 0}.

Số tham chiếu cùng lần đo: khung **toàn nhiễu trắng** cho `sum(E(1:7))` trung bình **0,0685**,
lớn nhất **0,2423** trên 2000 khung - vẫn còn xa ngưỡng 0,70, đúng như đoạn trên khẳng định.

Bảng trên đã đo lại bằng chính `dtmf_decode_goertzel` sau khi cài đặt xong, kết quả **trùng
khít** bản mẫu ở mọi mức SNR. `run_bench` ở Buổi 10 (3 phương pháp × nhiều loại nhiễu, số
lần thử lớn hơn) mới là số cuối cùng đi vào báo cáo.

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
   rho  = min(1, sum(E(1:7)))                        (đã chuẩn hóa theo (a))
   dRow = 10*log10(rowPeak/rowPeak2)
   dCol = 10*log10(colPeak/colPeak2)
```

Thuộc [0, 1], bằng 0 khi khung bị loại, giảm đơn điệu theo SNR.
`ui_refresh` chọn khung hiển thị bằng `[~, iSel] = max(info.conf)`.

LƯU Ý về `min(1, ...)` bọc ngoài `rho`: `dtmf_decide` không kiểm tra được caller đã chuẩn
hóa `E` theo (a) hay chưa. Thiếu cái chặn này, một `E` thô (tổng hàng chục) cho `conf` hàng
chục - phá vỡ lời hứa `conf ∈ [0, 1]` ghi trong help và làm `ui_plot_bars` vẽ sai thang.
Với `E` đã chuẩn hóa đúng thì `sum(E(1:7)) <= 1` nên `min` không đổi kết quả; nó chỉ là
tuyến phòng vệ, không phải một luật mới.

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

### (e) Mốc thời gian của `info.tFrame` - TÂM khung

```
info.tFrame(i) = (seg(i).tStart + seg(i).tEnd) / 2 = seg(i).tStart + frameN/(2*fs)
```

**Cả ba bộ giải mã lấy giống nhau, không có ngoại lệ.**

Phân vai rõ ràng giữa hai loại mốc: `seg.tStart` / `seg.tEnd` là **ranh giới** khung, dùng để
vẽ vạch phân khung trong `ui_plot_wave`; `info.tFrame` là **một mốc đại diện** cho phép đo của
khung, dùng làm trục hoành cho các đường theo khung (`conf`, `E`, nhãn `reject`).

Vì sao lấy tâm chứ không lấy `tStart`: một khung đo năng lượng trên **toàn bộ** chiều dài của
nó, nên thông tin nó mang nằm ở giữa, không nằm ở mép trái. Ba bộ giải mã dùng khung dài khác
nhau (Goertzel 205, FFT 256), nên quy ước `tStart` sẽ đẩy đường FFT lệch trái so với đường
Goertzel đúng `(256-205)/(2*fs) = 3,1875 ms` - **25,5 mẫu**, thấy rõ trên biểu đồ chồng ba
phương pháp ở Buổi 10. Lấy tâm thì độ lệch giả tạo này biến mất.

Điều kiện "`tFrame` tăng ngặt" trong `test_decode_goertzel` vẫn đúng: tâm khung là hàm bậc
nhất tăng của chỉ số mẫu đầu.

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
