# Hợp đồng hàm - DTMF Project

Tài liệu quy định. Mọi mục đều là ràng buộc bắt buộc, trừ §7 là số liệu đo.

## 1. Chữ ký hàm

```matlab
%% Phát
[x, t, meta] = dtmf_generate(keys, opt)
y            = dtmf_addnoise(x, opt)

%% Tiền xử lý / hậu xử lý
seg  = dtmf_segment(y, opt)
keys = dtmf_debounce(rowIdx, colIdx, opt)   % opt: minRun; xem §6(f)

%% Ngân hàng bộ lọc (chỉ nhánh filterbank dùng)
bank = design_bpf_bank(opt)   % opt: fs, coeffs, r, withHarm
  % bank : 1 x 14 struct (1 x 7 nếu withHarm = false), xem §6(b)
  %        .f tần số trung tâm [Hz] · .b tử số · .a mẫu số

%% Ba bộ giải mã - CÙNG MỘT CHỮ KÝ
[keys, info] = dtmf_decode_fft(y, opt)
[keys, info] = dtmf_decode_goertzel(y, opt)
[keys, info] = dtmf_decode_filterbank(y, opt)
  % info.E      : 8 x nFrame - công suất 7 tần số chuẩn + 1 hài bậc 2,
  %               ĐÃ CHUẨN HÓA theo năng lượng khung, xem §6(a)
  % info.rowIdx : 1 x nFrame
  % info.colIdx : 1 x nFrame
  % info.conf   : 1 x nFrame
  % info.tFrame : 1 x nFrame - TÂM khung, xem §6(e)
  % info.reject : cellstr - 'twist' | 'level' | 'harmonic' | 'none'

%% Đánh giá
m = dtmf_metrics(keysTrue, keysHat)  % .acc .editDist .confusion (12x12)
```

## 2. Luật cứng

- **Mọi giá trị rỗng là `1×0`, không phải `0×0`.** `strcmp` và `isequal` phân biệt hai cỡ
  này, nên hàm trả `''` (`0×0`) làm ca round-trip chuỗi rỗng báo sai dù giải mã đúng. Trong
  test kiểm rỗng bằng `verifyEmpty` + `verifyClass`, không dùng `verifyEqual(x, '')`.
- Hàm trong `src/` **không được** gọi `figure`, `plot`, `disp`, `sound`, `input`.
- `app/dtmf_run.m` là lớp trung gian **duy nhất** giữa UI và `src/`.
- Chỉ ba script được phép vẽ và phát âm thanh: `scripts/dev_harness.m`,
  `scripts/run_bench.m`, `scripts/make_figures.m`.
- Định danh lỗi dạng `'ham:loi'`, **ASCII**.
- Khối `arguments` là mặt hợp đồng: không thêm validator. Cần chặn gì thì chặn trong thân hàm.
- Không sửa pragma `%#ok<...>` sẵn có, và **không thêm pragma mới** - loại bỏ nguyên nhân
  thay vì tắt cảnh báo.

## 3. Luật dùng toolbox

**Tự cài đặt phần được chấm, dùng thư viện cho phần phụ trợ.**

| Hạng mục | Cách làm | Lý do |
|---|---|---|
| `goertzel_power` (IIR bậc 2) | **TỰ VIẾT** | Đề tài yêu cầu *cài đặt* Goertzel, không phải *sử dụng* |
| Ngân hàng bộ lọc cộng hưởng | **TỰ VIẾT** | Công thức cho phép dẫn giải `r = 0.99`, `BW ≈ 25.5 Hz` |
| Luật quyết định, debounce, metrics | **TỰ VIẾT** | Không có hàm dựng sẵn; là phần lõi của bài |
| Cộng nhiễu theo SNR | **TỰ VIẾT** | Chưa cài Communications Toolbox; công thức tay chính xác hơn `awgn` |
| `hamming`, `tukeywin` | Dùng toolbox | Cửa sổ là chi tiết phụ trợ |
| `spectrogram` | Dùng toolbox | Chỉ hiển thị trong `app/ui/ui_plot_spec.m` |
| `freqz`, `zplane` | Dùng toolbox | Chỉ kiểm chứng và vẽ, không nằm trong luồng giải mã |

- **`goertzel` của Signal Processing Toolbox chỉ được xuất hiện trong `tests/test_goertzel.m`**
  với vai trò phép đối chứng độc lập. Gọi nó trong `src/` là vi phạm.
- **`filterDesigner` không dùng để sinh hệ số nộp bài.** `design_bpf_bank` phải dựng bộ lọc
  bằng công thức cộng hưởng.
- Môi trường: MATLAB + Signal Processing Toolbox. Không phụ thuộc toolbox nào khác.

## 4. Quy ước help và comment

File `.m` lưu UTF-8 không BOM, comment tiếng Việt có dấu. `.gitattributes` đặt
`working-tree-encoding=UTF-8` nên git báo lỗi lúc commit nếu file bị ghi nhầm ANSI/UTF-16.
Số thập phân trong comment dùng dấu chấm. Nhãn công việc: `TODO(C):`, `LƯU Ý:`.

Khối help nằm ngay dưới dòng `function`, kết thúc ngay trên dòng `arguments`, không có dòng
`%` trống ngăn cách. Thứ tự bắt buộc (mẫu: `dtmf_generate.m`, `goertzel_power.m`):

1. **H1**: `%TEN_HAM Mô tả một dòng` - tên hàm viết HOA, không dấu chấm cuối.
2. **Một dòng đời thường** ngay dưới H1, lùi 1 dấu cách: hàm làm gì, nói như với người chưa
   học DSP.
3. **Cú pháp gọi** `[OUT] = TEN_HAM(IN)` kèm mô tả ngắn.
4. **`Các bước hoạt động:`** - tiêu đề viết đúng như vậy, đặt sau cú pháp và **trước**
   `Input:`; bên dưới là danh sách **đánh số** theo đúng thứ tự các khối trong thân hàm, mỗi
   bước 1-2 dòng, công thức viết cú pháp MATLAB. Ghi chú đặt **trên** tiêu đề hoặc **dưới**
   danh sách, không nhét vào dòng tiêu đề.
5. **`Input:` / `Tham số tên–giá trị (mặc định trong ngoặc):` / `Output:`** - tiêu đề tiếng
   Anh, nội dung tiếng Việt, dạng `tên: kích thước kiểu, mô tả`, kèm đơn vị trong ngoặc vuông
   (`[Hz]`, `[s]`, `[dB]`, `[mẫu]`).
6. **`Example:`** - đoạn chạy được, kết quả ghi ở comment cuối dòng (`% 64`). Là mục cuối.

**Không đặt `See also`** (sơ đồ phụ thuộc đã có ở §8) và **không đặt `Tham khảo:`** (trích dẫn
nằm ở `report/template/references.bib`) - giữ hai bản thì sớm muộn lệch nhau.

## 5. Thông số chốt sẵn

| Tham số | Giá trị |
|---|---|
| f_s | 8000 Hz |
| Tone / nghỉ | 100 ms / 50 ms (800 / 400 mẫu) |
| Khung Goertzel | N = 205, hop 205 → Δf ≈ 39,02 Hz |
| Bin k (hàng) | 697→18, 770→20, 852→22, 941→24 |
| Bin k (cột) | 1209→31, 1336→34, 1477→38 |
| Khung FFT đối chứng | N = 256, hop 128, Hamming → Δf = 31,25 Hz |
| Bin k FFT | 22, 25, 27, 30, 39, 43, 47 |
| Dung sai tần số | nhận ≤ ±1,5% · từ chối ≥ ±3,5% |
| Twist | thuận ≤ 4 dB · nghịch ≤ 8 dB |
| Ngưỡng quyết định | đỉnh ≥ 6 dB so với bin nhì **cùng nhóm**; Σ7 bin ≥ 70% năng lượng khung |
| Cộng hưởng filter bank | r = 0,99 → BW ≈ 25 Hz |

## 6. Sáu quyết định chốt bổ sung

### (a) Chuẩn hóa `E` - bộ giải mã tự làm, không đổi chữ ký hàm

Luật "Σ7 bin ≥ 70% năng lượng khung" cần năng lượng toàn khung, trong khi `dtmf_decide` chỉ
nhận `E (8,:)`. Do đó **mỗi bộ giải mã chia `E` cho năng lượng khung trước khi gọi
`dtmf_decide`**; khi đó `sum(E(1:7))` chính là tỉ lệ năng lượng.

```matlab
% Goertzel (không cửa sổ)
E = E_raw / (frameN * sum(frame.^2) / 2);
% FFT (Hamming) - phải bù độ lợi coherent của cửa sổ
cg = sum(w)^2 / (frameN * sum(w.^2));            % Hamming(256) -> 0,7317
E  = E_raw / (frameN * sum((w.*frame).^2) / 2 * cg);
% Ngân hàng bộ lọc (miền thời gian)
E = E_raw / sum(frame.^2);
```

Hệ quả: `E` không thứ nguyên và **so sánh được giữa ba phương pháp**, nên đường ngưỡng `thr`
duy nhất trong `ui_plot_bars` có nghĩa trên cả ba. Đây cũng là cổng chặn mức tuyệt đối duy
nhất - bốn điều kiện còn lại đều là tỉ số nên bất biến theo thang đo.

Cửa sổ làm tụt biên độ vạch phổ nhiều hơn làm tụt năng lượng khung, nên với tone thuần đúng
tâm bin `sum(E(1:7))` không vượt quá `cg = (Σw)²/(N·Σw²)`; thiếu `cg` thì nhánh FFT loại 100%
số khung ở mọi mức SNR (§7.1). Kiểm tra nhất quán: `w = ones(1,frameN)` cho `cg = 1` và công
thức FFT thu về đúng công thức Goertzel.

⚠️ Nhánh ngân hàng bộ lọc (Buổi 6) **chưa được đo**, mới chỉ dẫn giải trên giấy. Phải đo
theo tiêu chí §7.1 trước khi tin.

### (b) Bin hài bậc 2 - thích nghi theo từng khung

```
k_peak = argmax E(j), j = 1..7            % bin chuẩn mạnh nhất, KHÔNG phải 1633 Hz
k_harm = min(2*k_peak, floor(frameN/2))   % N = 205 -> <= 102 ; N = 256 -> <= 128
E(8)   = công suất tại bin k_harm
Điều kiện 5: E(8) <= 0.5*min(rowPeak, colPeak), ngược lại reject = 'harmonic'
```

`floor(N/2)` không bao giờ cắt trong thực tế (xấu nhất `2*47 = 94 <= 128`), chỉ là chốt
phòng vệ.

Vì `E(8)` phụ thuộc từng khung nên ngân hàng cố định 8 bộ không làm được. `design_bpf_bank`
nhận thêm `'withHarm' (1,1) logical = true` và trả **1×14**: 7 bộ cộng hưởng chuẩn + 7 bộ
tại tần số gấp đôi. `dtmf_decode_filterbank` lọc qua cả 14, mỗi khung lấy `d = argmax E(1:7)`
rồi gán `E(8,i) = E_harm(d,i)`.

**`data/mat/coeffs.mat` không được phép âm thầm ghi đè công thức.** Nhánh `isfile(opt.coeffs)`
đứng trước nhánh dựng bằng công thức, nên một file cũ sẽ làm mọi thay đổi `r` hay công thức
mất tác dụng mà không có dấu hiệu nào. Luật:

- File do **`scripts/make_coeffs.m`** sinh ra từ chính `design_bpf_bank`, **không** do
  `filterDesigner` (§3). File phải lưu kèm siêu dữ liệu `fs`, `r`, `withHarm`.
- Khi nạp, `design_bpf_bank` **đối chiếu siêu dữ liệu với tham số đang yêu cầu**; lệch một
  trường thì bỏ qua file và dựng lại bằng công thức.
- Test phải ép **cả hai nhánh** bằng cách truyền `'coeffs'` tường minh (một đường dẫn không
  tồn tại để ép nhánh công thức, đường dẫn thật để ép nhánh nạp). Không được để kết quả test
  phụ thuộc việc máy đó có sẵn file hay không.

### (c) Công thức `info.conf`

```
conf = 0                                            nếu reject ~= 'none'
conf = rho * min(1, min(dRow, dCol) / (2*peakDb))   nếu reject == 'none'
   rho  = min(1, sum(E(1:7)))                       (đã chuẩn hóa theo (a))
   dRow = 10*log10(rowPeak/rowPeak2)
   dCol = 10*log10(colPeak/colPeak2)
```

Thuộc [0, 1], bằng 0 khi và chỉ khi khung bị loại, giảm đơn điệu theo SNR. `ui_refresh` chọn
khung hiển thị bằng `[~, iSel] = max(info.conf)`.

`min(1, ·)` bọc ngoài `rho` là tuyến phòng vệ, không phải luật mới: `dtmf_decide` không kiểm
được caller đã chuẩn hóa `E` hay chưa, và `E` thô sẽ cho `conf` hàng chục. Với `E` chuẩn hóa
đúng thì `sum(E(1:7)) <= 1` nên `min` không đổi kết quả.

### (d) Mốc thời gian của `dtmf_segment` - quy ước THỜI LƯỢNG

```
tStart = (idx(1) - 1)/fs        % mốc của mẫu đầu, t = 0 tại y(1)
tEnd   =  idx(2)     /fs        % = tStart + frameN/fs
```

`tEnd - tStart = frameN/fs` đúng bằng thời lượng khung (25,625 ms với `frameN = 205`), cùng
quy ước với `dtmf_generate` nơi `meta.offsets - meta.onsets` bằng đúng `toneMs`. Khi
`hop = frameN` thì `seg(i).tEnd == seg(i+1).tStart` khít tuyệt đối.

### (e) Mốc thời gian của `info.tFrame` - TÂM khung

```
info.tFrame(i) = (seg(i).tStart + seg(i).tEnd) / 2 = seg(i).tStart + frameN/(2*fs)
```

**Cả ba bộ giải mã lấy giống nhau, không có ngoại lệ.**

Phân vai: `seg.tStart` / `seg.tEnd` là **ranh giới** khung (vẽ vạch phân khung trong
`ui_plot_wave`); `info.tFrame` là **mốc đại diện** cho phép đo của khung (trục hoành cho
`conf`, `E`, `reject`).

Lấy tâm vì khung đo năng lượng trên toàn bộ chiều dài của nó. Ba bộ dùng khung dài khác nhau
(205 / 256), nên quy ước `tStart` đẩy đường FFT lệch trái so với Goertzel đúng
`(256-205)/(2*fs) = 3,1875 ms` (25,5 mẫu) trên biểu đồ chồng ở Buổi 10. Tâm khung vẫn là hàm
bậc nhất tăng của chỉ số mẫu đầu nên điều kiện "`tFrame` tăng ngặt" trong test vẫn đúng.

### (f) Debounce - hàm dùng chung, dải phải dài >= 2 khung

```matlab
keys = dtmf_debounce(info.rowIdx, info.colIdx);   % minRun = 2
```

**Cả ba bộ giải mã gọi `src/util/dtmf_debounce.m`; không bộ nào được tự viết vòng gộp.**
Ba bản sao sẽ trôi khỏi nhau mà test tương đương liên phương pháp không bắt được, vì nó so
hai bộ giải mã với nhau chứ không so với luật.

Luật: các khung liên tiếp cùng chỉ số phím `(rowIdx-1)*3+colIdx` gộp thành một **dải**; khung
bị loại (`rowIdx = 0`) **cắt** dải; dải dài `>= minRun` khung mới sinh một ký tự.

`minRun = 2` là ràng buộc vật lý, không phải hằng số tinh chỉnh: một phím kéo 100 ms = **3,9
khung** ở `frameN = 205`, nên dải dài đúng **một** khung không thể là phím thật. Số liệu ở
§7.5; ở đó cũng cho thấy `minRun = 1` làm nhánh ngân hàng bộ lọc **nhân đôi phím lặp** ở
29/42 cách căn lề.

## 7. Số liệu đã đo

### 7.1 Hệ số bù cửa sổ của nhánh FFT

Đo 21/09/2026, chuỗi 41 phím, `frameN = 256, hop = 128`. Trần lý thuyết của `sum(E(1:7))`
khi thiếu `cg` là 0,7317; khung DTMF thật đo được **0,6298**, tức dưới ngưỡng 0,70.

| Chuẩn hóa | Giải mã đúng | Khung bị loại giữa tone | `rho` nhỏ nhất của khung được nhận |
|---|:--:|:--:|:--:|
| không có `cg` | 0/41 | 180 | (không khung nào được nhận) |
| **có `cg`** | **41/41** | **0** | **0,7079** |

Goertzel đo được **0,7080** trên cùng chuỗi. Hai phương pháp rơi đúng cùng một thang - đây là
tiêu chí nghiệm thu cho nhánh ngân hàng bộ lọc ở Buổi 6.

### 7.2 Độ chính xác theo SNR

Nhiễu `awgn`, `rng(2026)`. Goertzel: 20 chuỗi 12 phím mỗi mức (21/09/2026). FFT: `'0912345'`,
5 lần thử mỗi mức (22/09/2026).

| SNR [dB] | 30 | 20 | 15 | 12 | 10 | 8 | 6 | 4 | 0 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Goertzel | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | **1,00** | 0,85 | 0,40 | 0,00 |
| FFT | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | **1,00** | 0,60 | 0,00 | - |

Vách nằm quanh **6 dB** và **dốc dần**, không phải ở 8 dB và dốc đứng như bản đặc tả đầu tiên
ghi. Hai nhánh trùng nhau tới 8 dB, chỉ khác độ dốc ở đáy vách. Đây là kết quả có chủ đích của
ngưỡng 0,70 (chống talk-off); demo ở SNR ≥ 10 dB còn dư 2 dB.

Cùng lần đo, khung **toàn nhiễu trắng** cho `sum(E(1:7))` trung bình **0,0685**, lớn nhất
**0,2423** trên 2000 khung - còn xa ngưỡng 0,70.

Số cuối cùng đi vào báo cáo là của `scripts/run_bench.m` ở Buổi 10 (3 phương pháp × nhiều loại
nhiễu, số lần thử lớn hơn, quét thêm `energyRatio` ∈ {0,70 · 0,40 · 0}).

### 7.3 Số cách căn lề khung - phụ thuộc `hop`, không chép giữa hai nhánh

Mỗi phím chiếm `(toneMs+pauseMs)·fs/1000 = 1200` mẫu, khung nhảy từng `hop`, nên độ lệch
tương đối của phím thứ *i* là `mod((i-1)·1200, hop)`, chạy hết `hop/gcd(mod(1200,hop), hop)`
giá trị rồi lặp.

| Nhánh | `hop` | `mod(1200,hop)` | `gcd` | Số cách căn lề | Chuỗi quét cạn |
|---|:--:|:--:|:--:|:--:|---|
| Goertzel | 205 | 175 | 5 | **41** | 41 phím |
| FFT | 128 | 48 | 16 | **8** | 16 phím (phủ hai lượt) |

Cả hai test quét cạn khẳng định `gcd` ngay trong ca test, để việc đổi `toneMs`, `pauseMs` hay
`hop` làm lập luận vỡ ra thấy được thay vì âm thầm tụt xuống thành phép thử vài ca.

### 7.4 Giá trị kiểm chứng Goertzel

```
N = 16, k = 3, x[n] = cos(2π·3n/16)
=> P = 64,000000      (lý thuyết: X[3] = N/2 = 8 => |X[3]|² = 64)
Sai lệch cho phép < 1e-9 - xem tests/test_goertzel.m
```

### 7.5 Luật debounce `minRun = 2` - vì sao cần, và giá bao nhiêu

Đo 22/09/2026. Với `minRun = 1`, nhánh ngân hàng bộ lọc **chèn thêm** một ký tự vào chỗ có
phím lặp, do hai hiệu ứng riêng lẻ vô hại cộng lại: bộ lọc còn **dư âm** trong khoảng lặng
làm một khung gần-như-im-lặng vẫn được nhận (`rho = 2,297`), rồi **quá độ** ở đầu tone kế
tiếp làm khung ngay sau đó bị loại (`rho = 0,439`). Khung dư âm thành một dải cô lập dài
đúng một khung, sinh ra một ký tự thừa.

| Cấu hình | ca `"1"×L + "99"`, L=0..41 | 30 chuỗi ngẫu nhiên 41 phím |
|---|:--:|:--:|
| filterbank 205/205, `minRun = 1` | hỏng 29/42 | hỏng 30/30 |
| filterbank 256/128, `minRun = 1` | hỏng 0/42 | hỏng **22/30** |
| **filterbank 205/205, `minRun = 2`** | **0/42** | **0/30** |
| Goertzel / FFT, `minRun = 1` | 0/42 | 0/30 |

Đổi lưới khung **không** phải cách sửa: nó chỉ dời lỗi ra khỏi phép thử hẹp.

Giá của `minRun = 2`, đo trên 13 chuỗi × 5 lần mỗi mức:

| SNR [dB] | 20 | 15 | 12 | 10 | 8 | 6 | 4 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Goertzel `minRun=1` | 1,000 | 1,000 | 1,000 | 1,000 | 1,000 | 0,862 | 0,215 |
| Goertzel `minRun=2` | 1,000 | 1,000 | 1,000 | 1,000 | 1,000 | 0,754 | 0,092 |
| FFT `minRun=1` | 1,000 | 1,000 | 1,000 | 1,000 | 1,000 | 0,585 | 0,000 |
| FFT `minRun=2` | 1,000 | 1,000 | 1,000 | 1,000 | 1,000 | 0,862 | 0,000 |

**Miễn phí trong toàn bộ vùng làm việc đã công bố (SNR ≥ 10 dB).** Dưới vách thì lợi hại đan
nhau chứ không một chiều. Biên an toàn: dải ngắn nhất của một phím thật đo được là **3 khung**
ở mọi mức tới 8 dB, chỉ tụt xuống 1 khung tại 6 dB. Tín hiệu một phím cũng an toàn - `'5'`
cho 3 khung ở Goertzel và 5 khung ở FFT.

## 8. Cấu trúc thư mục

```
DMTF/
├─ src/
│  ├─ gen/      dtmf_table.m  dtmf_generate.m  dtmf_addnoise.m
│  ├─ decode/   dtmf_decode_fft.m
│  │            goertzel_power.m  dtmf_decode_goertzel.m
│  │            design_bpf_bank.m dtmf_decode_filterbank.m
│  └─ util/     dtmf_segment.m  dtmf_decide.m  dtmf_debounce.m  dtmf_metrics.m
├─ app/         dtmf_run.m   DTMFApp.m
│  └─ ui/       ui_plot_wave.m ui_plot_spec.m ui_plot_bars.m ui_refresh.m ui_play.m
├─ tests/       test_generate.m test_goertzel.m run_all_tests.m  (+ các test bổ sung)
├─ scripts/     dev_harness.m  make_coeffs.m  run_bench.m  make_figures.m
├─ data/        wav/  mat/      (coeffs.mat sinh bằng scripts/make_coeffs.m)
├─ results/     figures/  bench.mat
└─ docs/        report/  slides/  study/KE_HOACH.md
```

**Giao diện:** `app/DTMFApp.m` dạng `classdef ... < handle` tự dựng `uifigure`, **không** dùng
`.mlapp` (file ZIP nhị phân, không diff/merge và không test tự động được). `ui_refresh.m` chỉ
đụng `app.AxWave`, `app.AxSpec`, `app.AxBars`, `app.TxtLog`, `app.LblDecoded`, `app.S`, nên một
`classdef` có đúng các property đó thỏa mãn hợp đồng y hệt class do App Designer sinh ra. Tên
component tuân thủ `docs/ui_naming.md`.
