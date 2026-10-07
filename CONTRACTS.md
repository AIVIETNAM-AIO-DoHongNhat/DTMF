# Hợp đồng hàm - DTMF Project

Mọi mục là ràng buộc bắt buộc, trừ §7 là số liệu đo (lý do của các luật).

## 1. Chữ ký hàm

```matlab
%% Phát
T            = dtmf_table()               % hằng số: .rowHz 1×4, .colHz 1×3, .keys 4×3
[x, t, meta] = dtmf_generate(keys, opt)
y            = dtmf_addnoise(x, opt)      % 'type': 'awgn' | 'hum50' | 'speech'

%% Khung, quyết định, gộp phím
seg  = dtmf_segment(y, opt)                            % mốc thời gian §6(d)
[rowIdx, colIdx, conf, reject] = dtmf_decide(E, opt)   % E 8×nFrame đã chuẩn hóa §6(a)
keys = dtmf_debounce(rowIdx, colIdx, opt)              % minRun = 2, §6(f)

%% Lõi tự viết
P    = goertzel_power(x, k, N)
bank = design_bpf_bank(opt)   % 1×14 struct .f .b .a (1×7 nếu withHarm = false), §6(b)

%% Ba bộ giải mã - cùng một chữ ký
[keys, info] = dtmf_decode_fft(y, opt)
[keys, info] = dtmf_decode_goertzel(y, opt)
[keys, info] = dtmf_decode_filterbank(y, opt)
  % info.E              8×nFrame  7 tần số chuẩn + hài bậc 2, đã chuẩn hóa §6(a)
  % info.rowIdx, colIdx 1×nFrame
  % info.conf           1×nFrame  §6(c)
  % info.tFrame         1×nFrame  tâm khung §6(e)
  % info.reject         cellstr   'twist' | 'level' | 'harmonic' | 'none'

%% Đánh giá
m = dtmf_metrics(keysTrue, keysHat)   % .acc .editDist .confusion 12×12 .align 2×n, §6(g)

%% Lớp trung gian
S = dtmf_run(S)             % giải mã khối
L = dtmf_listen(L, chunk)   % giải mã luồng (micro, đường dây)
J = dtmf_judge(that, doc)   % đối chiếu số thật với số đọc được (màn giám định)
```

## 2. Luật cứng

- Mọi giá trị rỗng là `1×0`, không phải `''` (`0×0`) vì `strcmp`/`isequal` phân biệt hai cỡ.
  Test kiểm rỗng bằng `verifyEmpty` + `verifyClass`, không dùng `verifyEqual(x, '')`.
- `src/` không gọi `figure`, `plot`, `disp`, `sound`, `input`.
- Trong tầng ứng dụng, chỉ `app/dtmf_run.m` (khối), `app/dtmf_listen.m` (luồng) và
  `app/dtmf_judge.m` (đối chiếu) được gọi `src/decode/*` và `src/util/*`. `dtmf_listen` dùng lại
  bộ giải mã khối và `dtmf_debounce`,
  không có vòng đo hay vòng gộp riêng (§7.9).
- `app/ui/*.m` chỉ vẽ cái có sẵn trong `S` (§6(h)). Ngoại lệ duy nhất là `dtmf_table()`, vì đó
  là hằng số và chép tay 7 tần số sớm muộn sẽ lệch.
- `tests/` và `scripts/` được gọi thẳng `src/` (`run_bench` cần `dtmf_decide` với ngưỡng khác
  mặc định).
- `app/DTMFLine.m` chỉ đổi byte thành mẫu như `audiorecorder`; âm thanh vẫn đi qua `dtmf_listen`.
- Màn giám định không bao giờ nhận đáp án trước khi kết luận: trang chỉ gửi `reveal` sau khi nhận
  `verdict`, và `DTMFForensic` nhận `reveal` lúc còn nghe thì kết luận trước rồi mới đối chiếu.
- Chỉ `app/ui/*.m` và các script `dev_harness`, `run_bench`, `make_figures`, `make_cover` được
  vẽ hay phát âm thanh. `dtmf_run` thì không.
- Định danh lỗi dạng `'ham:loi'`, ASCII.
- Khối `arguments` là mặt hợp đồng: không thêm validator, cần chặn thì chặn trong thân hàm.
- Không sửa pragma `%#ok<...>` sẵn có, không thêm pragma mới - sửa nguyên nhân.

## 3. Luật dùng toolbox

Tự viết phần được chấm, dùng thư viện cho phần phụ trợ. Chỉ MATLAB + Signal Processing Toolbox.

| Tự viết | Dùng toolbox |
|---|---|
| `goertzel_power`, ngân hàng bộ lọc cộng hưởng, luật quyết định, debounce, metrics, cộng nhiễu theo SNR | `hamming`, `tukeywin`; `spectrogram`, `pwelch`, `freqz`, `zplane` chỉ để vẽ và kiểm chứng, ngoài luồng giải mã |

- `goertzel` của toolbox chỉ xuất hiện trong `tests/test_goertzel.m` để đối chứng.
- Không dùng `filterDesigner`; `design_bpf_bank` dựng bằng công thức cộng hưởng.
- Micro mở bằng `audiorecorder`, không dùng `audioDeviceReader` (Audio Toolbox).

## 4. Quy ước help và comment

File `.m` lưu UTF-8 không BOM (`.gitattributes` chặn ANSI/UTF-16), comment tiếng Việt có dấu,
số thập phân dùng dấu chấm, nhãn `TODO(C):`, `LƯU Ý:`.

Khối help nằm ngay dưới `function`, kết thúc ngay trên `arguments`, không dòng `%` trống. Thứ tự
(mẫu `dtmf_generate.m`, `goertzel_power.m`):

1. H1 `%TEN_HAM Mô tả một dòng` - tên viết HOA, không dấu chấm cuối.
2. Một dòng đời thường, lùi 1 dấu cách, cho người chưa học DSP.
3. Cú pháp `[OUT] = TEN_HAM(IN)`.
4. `Các bước hoạt động:` - danh sách đánh số theo thứ tự các khối trong thân hàm, mỗi bước 1-2
   dòng, công thức viết cú pháp MATLAB.
5. `Input:` / `Tham số tên–giá trị (mặc định trong ngoặc):` / `Output:` - dạng
   `tên: kích thước kiểu, mô tả [đơn vị]`.
6. `Example:` - chạy được, kết quả ở comment cuối dòng. Là mục cuối.

Không đặt `See also` (đã có §8) và `Tham khảo:` (đã có `report/template/references.bib`).

## 5. Thông số chốt sẵn

| Tham số | Giá trị |
|---|---|
| f_s | 8000 Hz |
| Tone / nghỉ | 100 ms / 50 ms (800 / 400 mẫu) |
| Khung Goertzel | N = 205, hop 205 → Δf ≈ 39,02 Hz; bin 18 20 22 24 / 31 34 38 |
| Khung FFT | N = 256, hop 128, Hamming → Δf = 31,25 Hz; bin 22 25 27 30 / 39 43 47 |
| Dung sai tần số | chuẩn: nhận ≤ ±1,5% · từ chối ≥ ±3,5%. Đo được: chỉ nhận chắc ≤ ±0,5%, từ chối ±3,5% đạt (§7.12) |
| Twist | thuận ≤ 4 dB · nghịch ≤ 8 dB |
| Ngưỡng quyết định | đỉnh ≥ 6 dB so với bin nhì cùng nhóm; Σ7 bin ≥ 70% năng lượng khung |
| Ngân hàng bộ lọc | r = 0,99 → BW ≈ 25 Hz |

## 6. Quyết định chốt bổ sung

### (a) Chuẩn hóa `E`

Mỗi bộ giải mã chia `E` cho năng lượng khung trước khi gọi `dtmf_decide`, để `sum(E(1:7))` chính
là tỉ lệ năng lượng.

```matlab
E = E_raw / (frameN * sum(frame.^2) / 2);                % Goertzel
cg = sum(w)^2 / (frameN * sum(w.^2));                    % FFT: bù cửa sổ, Hamming(256) -> 0,7317
E  = E_raw / (frameN * sum((w.*frame).^2) / 2 * cg);
E = E_raw / sum(frame.^2);                               % ngân hàng bộ lọc (miền thời gian)
```

`E` không thứ nguyên, so được giữa ba phương pháp, và là cổng chặn mức tuyệt đối duy nhất. Thiếu
`cg` thì nhánh FFT loại mọi khung (§7.1). Riêng ngân hàng bộ lọc, `rho` có thể vượt 1 (§7.6).

### (b) Bin hài bậc 2 - thích nghi theo từng khung

```
k_peak = argmax E(1:7)                    % bin chuẩn mạnh nhất
k_harm = min(2*k_peak, floor(frameN/2))   % floor chỉ là chốt phòng vệ
Điều kiện 5: E(8) <= 0.5*min(rowPeak, colPeak), ngược lại reject = 'harmonic'
```

Vì vậy `design_bpf_bank` trả 1×14 (7 bộ chuẩn + 7 bộ tần số gấp đôi), và
`dtmf_decode_filterbank` gán `E(8,i) = E_harm(argmax E(1:7,i), i)`.

`data/mat/coeffs.mat` không được âm thầm ghi đè công thức:

- Sinh bằng `scripts/make_coeffs.m` từ `design_bpf_bank`, lưu kèm `fs`, `r`, `withHarm`. Không commit.
- Khi nạp, lệch một trường siêu dữ liệu thì bỏ file và dựng lại bằng công thức.
- Test ép cả hai nhánh bằng `'coeffs'` tường minh, không phụ thuộc máy có sẵn file.

### (c) Công thức `info.conf`

```
conf = 0                                            nếu reject ~= 'none'
conf = rho * min(1, min(dRow, dCol) / (2*peakDb))   nếu reject == 'none'
   rho = min(1, sum(E(1:7))),  dRow = 10*log10(rowPeak/rowPeak2),  dCol tương tự
```

Thuộc [0, 1], bằng 0 khi và chỉ khi khung bị loại. `min(1, ·)` quanh `rho` chỉ phòng khi caller
quên chuẩn hóa `E`.

### (d) Mốc thời gian của `dtmf_segment`

```
tStart = (idx(1) - 1)/fs,   tEnd = idx(2)/fs     % tEnd - tStart = frameN/fs
```

Cùng quy ước thời lượng với `dtmf_generate`. Khi `hop = frameN` thì `seg(i).tEnd == seg(i+1).tStart`.

### (e) `info.tFrame` là tâm khung

```
info.tFrame(i) = (seg(i).tStart + seg(i).tEnd) / 2
```

Cả ba bộ giải mã như nhau. `seg.tStart`/`tEnd` là ranh giới khung, `tFrame` là mốc đại diện cho
`conf`, `E`, `reject`. Lấy tâm để đường FFT (N = 256) không lệch 3,19 ms so với Goertzel (N = 205).

### (f) Debounce dùng chung, dải dài ≥ 2 khung

Cả ba bộ giải mã gọi `dtmf_debounce`, không bộ nào tự viết vòng gộp. Khung liên tiếp cùng phím
gộp thành dải, khung bị loại (`rowIdx = 0`) cắt dải, dải dài `>= minRun` khung mới sinh một ký tự.

`minRun = 2` là ràng buộc vật lý: phím 100 ms dài 3,9 khung nên dải một khung không thể là phím
thật. `minRun = 1` làm ngân hàng bộ lọc nhân đôi phím lặp (§7.5).

### (g) `dtmf_metrics` - `acc` suy từ `editDist`

```matlab
acc = 1 - editDist / max(numel(keysTrue), numel(keysHat));   % hai chuỗi rỗng -> 1
```

Không đếm ô khớp lúc truy vết, vì số đó phụ thuộc thứ tự ưu tiên truy vết (§7.8) và làm `acc`
mâu thuẫn với `editDist` cùng dòng. Đánh đổi: `trace(confusion)` có thể lớn hơn `acc*max(K,L)`.

- Truy vết ưu tiên CHÉO > XÓA > CHÈN.
- `confusion` chỉ ghi bước chéo; chèn và xóa không có ô.
- Thứ tự phím `'147*2580369#'` - duyệt `dtmf_table().keys` theo cột. Duyệt theo hàng ra ma trận
  chuyển vị mà hình vẫn trông hợp lý.
- Ký tự ngoài 12 phím là lỗi `dtmf_metrics:badKey`.
- `align` (2×n char, `'-'` là ô trống) ghi đúng đường truy vết đó. `web/src/forensic/align.ts` dùng
  cùng phép Levenshtein và cùng thứ tự ưu tiên, nên trang và `DTMFForensic` tô chữ số giống nhau.

### (h) Tầng UI không tính toán

`app/dtmf_run.m` dọn sẵn mọi con số cho UI:

```matlab
S.iSel = argmax(info.conf);                         % 0 nếu không có khung nào
S.thr  = 0.5 * min(max(E(1:4)), max(E(5:7)));       % E = info.E(:, S.iSel)
[S.keysHat, S.info] = dtmf_decode_xxx(S.y - mean(S.y), 'fs', S.fs);
```

- `thr` là điều kiện 5 (hài bậc 2), điều kiện duy nhất vẽ được thành đường ngang trên `E`.
- `nFrame = 0` cho `iSel = 0`, `thr = 0`; `ui_plot_bars` khi đó xóa trục.
- Trừ trung bình trước khi giải mã (§7.7) nhưng không ghi đè `S.y`, để hình vẽ đúng cái người
  dùng nghe.
- `S.lastError` rỗng là `blanks(0)`.

## 7. Số liệu đã đo

### 7.1 Hệ số bù cửa sổ nhánh FFT

21/09/2026, 41 phím, 256/128. Thiếu `cg`, trần lý thuyết của `sum(E(1:7))` là 0,7317 và đo được
0,6298 < 0,70 nên 0/41 phím đúng. Có `cg` thì 41/41, `rho` nhỏ nhất 0,7079 (Goertzel 0,7080).

### 7.2 Độ chính xác theo SNR

Nhiễu AWGN, `rng(2026)`. Goertzel 20 chuỗi 12 phím, FFT `'0912345'` × 5 lần mỗi mức.

| SNR [dB] | 30 | 20 | 15 | 12 | 10 | 8 | 6 | 4 | 0 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Goertzel | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 0,85 | 0,40 | 0,00 |
| FFT | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 0,60 | 0,00 | - |

Số của buổi đo đầu, trước khi chốt `minRun = 2` (§7.5) và đổi số lần chạy; không so trực tiếp với bảng
README. Số chính thức lấy từ `scripts/run_bench.m` (`results/bench.mat`, 20 chuỗi 12 phím, 15 mức SNR).
Vách nằm quanh 6 dB và dốc dần; demo ở SNR ≥ 10 dB. Khung toàn nhiễu cho `sum(E(1:7))` trung
bình 0,0685, lớn nhất 0,2423 trên 2000 khung. Số cuối cùng của báo cáo lấy từ `scripts/run_bench.m`.

### 7.3 Số cách căn lề khung

Mỗi phím chiếm 1200 mẫu nên có `hop/gcd(mod(1200,hop), hop)` cách căn lề: Goertzel (hop 205)
có 41, quét bằng chuỗi 41 phím; FFT (hop 128) có 8, quét bằng chuỗi 16 phím. Test khẳng định
`gcd` ngay trong ca test để đổi `toneMs`, `pauseMs`, `hop` thì lỗi lộ ra.

### 7.4 Giá trị kiểm chứng Goertzel

`N = 16, k = 3, x[n] = cos(2π·3n/16)` cho `P = 64` (`|X[3]|² = (N/2)²`), sai lệch < 1e-9.

### 7.5 Debounce `minRun = 2`

22/09/2026. Với `minRun = 1`, ngân hàng bộ lọc còn dư âm trong khoảng lặng (`rho = 2,297`, khung
được nhận) rồi quá độ ở đầu tone kế (`rho = 0,439`, khung bị loại), sinh dải một khung thừa.

| Cấu hình | `"1"×L + "99"`, L = 0..41 | 30 chuỗi 41 phím |
|---|:--:|:--:|
| filterbank 205/205, `minRun = 1` | hỏng 29/42 | hỏng 30/30 |
| filterbank 256/128, `minRun = 1` | hỏng 0/42 | hỏng 22/30 |
| filterbank 205/205, `minRun = 2` | 0/42 | 0/30 |
| Goertzel / FFT, `minRun = 1` | 0/42 | 0/30 |

Đổi lưới khung không sửa được. `minRun = 2` không tốn gì ở SNR ≥ 10 dB; dưới vách thì lợi hại đan
xen (6 dB: Goertzel 0,862 → 0,754, FFT 0,585 → 0,862). Phím thật ngắn nhất dài 3 khung tới 8 dB.

### 7.6 Nhánh ngân hàng bộ lọc

22/09/2026, `r = 0,99`, 205/205.

- Thiết kế: `abs(|H(f0)|-1)` = 2,2e-16 (ngưỡng test 1e-10), sai số bán kính cực 3,3e-16 (1e-12),
  BW −3 dB = 25,59 Hz so với lý thuyết `(1-r)·fs/π` = 25,46 Hz.
- Quá độ: `τ = 12,44 ms`, `5τ = 62,2 ms` ≈ 2,4 khung đầu mỗi tone. Lọc riêng từng khung mất 57-61%
  năng lượng từ khung 2, nên phải lọc cả tín hiệu một lần rồi mới chia khung.
- `rho` vượt 1 vì dư âm ở khoảng lặng: tới 3,08, và 6,65e7 sau khi trừ trung bình. Vô hại, quét
  60 chuỗi × 3 phương pháp cho 0/180 ca sai cả khi sạch lẫn DC 0,2 + nhiễu 15 dB. Không viết test
  cận trên của `rho` cho nhánh này.
- Chịu nhiễu (10 chuỗi 12 phím × 5 lần, `rng(2026)`):

| SNR [dB] | 20 | 15 | 10 | 8 | 6 | 4 | 2 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Ngân hàng bộ lọc | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 0,04 |
| Goertzel | 1,00 | 1,00 | 1,00 | 1,00 | 0,74 | 0,02 | 0,00 |
| FFT | 1,00 | 1,00 | 1,00 | 1,00 | 0,86 | 0,00 | 0,00 |

Ngân hàng bộ lọc bền nhất vì 14 bộ cộng hưởng hẹp loại nhiễu ngoài băng trước khi đo, còn Goertzel
và FFT lấy năng lượng khung thô làm mẫu số.

### 7.7 Thành phần một chiều làm hỏng cả ba bộ giải mã

22/09/2026, `'0912345'`, biên độ đỉnh 0,5.

| DC | 0 | 0,05 | 0,10 | 0,20 | 0,30 | 0,50 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Ba bộ giải mã | đúng | đúng | Goertzel mất 1 phím | rỗng | rỗng | rỗng |

DC làm `sum(frame.^2)` phình (×1,65 ở DC 0,20) nên mọi khung thành `'level'`. Đúng theo luật (a),
nhưng micro thường có DC, nên `dtmf_run` trừ trung bình (đã kiểm ở DC 0,2 · 0,5 · 1,0). Bộ giải mã
giữ nguyên.

### 7.8 Hai công thức `acc`

23/09/2026. Vét cạn chuỗi dài 0..4 trên 3 ký tự: 978/14641 cặp (6,7%) cho `1 - editDist/max` khác
`nMatch/max`, đúng các cặp mà đường truy vết có cả chèn lẫn xóa; `nMatch` chênh tới 2 ký tự khi đổi
thứ tự ưu tiên. Trên dữ liệu thật chỉ lệch 2/168 ca, tối đa 0,083, đều ở 4 dB.

Cặp ngắn nhất phân biệt thứ tự truy vết là `'12'`/`'3'`: luật CHÉO trước ghi `'2'→'3'`, ô `(5,9)`.
Kiểm thử đột biến `dtmf_metrics` 9/9 đỏ, nhờ có ca này.

### 7.9 Giải mã luồng (`dtmf_listen`)

29/09/2026. Mỗi lần gọi ghép H mẫu lịch sử với các khung mới, trừ trung bình, chạy
`dtmf_decode_<method>`, rồi bỏ các khung lịch sử. `H = hop*ceil(0.1*fs/hop)` (820 / 896 mẫu), đủ
cho quá độ `5τ` của bộ cộng hưởng. Phím được báo ngay khi dải đủ `minRun`.

- Luồng = khối: chặt tín hiệu thành đoạn ngẫu nhiên 1..1500 mẫu, 3 phương pháp × 4 mức SNR ×
  8 chuỗi, 0/96 ca lệch so với giải mã khối.
- Độ trễ báo phím, tính từ đầu tone:

| Đoạn | FFT | Goertzel | Ngân hàng bộ lọc |
|---|:--:|:--:|:--:|
| 50 mẫu (độ trễ thuật toán) | 40-61 ms | 49-74 ms | 65-90 ms |
| 400 mẫu (chu kỳ 50 ms của app) | 44-93 ms | 68-117 ms | 84-134 ms |

- Mỗi lần gọi tốn 2-4 ms. `ui_refresh` với 3 s tín hiệu tốn 0,4-0,5 s nên `DTMFApp` chỉ vẽ lại
  mỗi giây, nhãn phím thì đổi ngay.
- Vòng loa laptop → micro laptop không đáng tin: hàng 697/770 Hz yếu hơn cột 14-21 dB (trượt
  twist), có lần không thu được gì (`rho` lớn nhất 0,19). Demo bằng điện thoại thật hoặc đường dây
  §7.10.

### 7.10 Đường dây trang web → MATLAB

06/10/2026. Trang gửi chính các mẫu nó phát ra loa:

```
trang (worklet, nội suy về 8 kHz, int16) --WebSocket /line--> web/server/line.ts
  --TCP 127.0.0.1:8765, mỗi dòng một JSON, âm thanh base64--> DTMFLine --> dtmf_listen --> DTMFLive
```

Giao thức ở `web/src/line/protocol.ts`.

- Nội suy tuyến tính sai số ≤ `(2πf/fs)²/8`, tức 0,47% với 1477 Hz từ 48 kHz.
- Cần cầu nối vì trình duyệt không mở được TCP và `tcpserver` cần Instrument Control Toolbox.
- `tcpclient` vào cổng chưa mở mất ~3,4 s, nên `DTMFLive` chỉ tự nối lúc mở, sau đó nối bằng nút.
- `tcpclient` không báo khi đầu kia đóng, nên cầu nối `ping` mỗi giây và im 3,5 s là đứt.
- Thử trọn đường: `'0912345*#'` cho 9/9 phím, phím về điện thoại ~0,24 s sau đầu tone.
- `ui_live_draw` dựng đồ họa một lần và chỉ gán `XLim`/`YLim`/chữ khi giá trị đổi: tick trung vị
  49 ms (lớn nhất 138 ms), so với 73 ms nếu gán lại mọi thứ.

### 7.11 Màn giám định ghi âm (`DTMFForensic`)

07/10/2026. Trang dựng đoạn ghi âm ở 8 kHz (`web/src/forensic/scene.ts`), phát ra loa và gửi đúng
các mẫu đó theo nhịp 40 ms của đồng hồ âm thanh:

```
trang #giam-dinh --case, pcm..., end--> cầu nối --> DTMFLine --> dtmf_listen (đọc dần)
                                                             --> dtmf_run × 3 (kết luận) --> verdict
                 --reveal (chỉ sau verdict)-->                   --> dtmf_judge × 3 (đối chiếu)
```

- Mức âm nền và SNR so với tiếng bấm đo trên các đoạn CÓ tone. Cùng một mức nhiễu, SNR này cao hơn
  SNR của §7.2 (trung bình cả chuỗi 100/50 ms) 1,8 dB.
- Tỉ lệ đọc đúng cả số 10 chữ số, 60 số ngẫu nhiên, bản Goertzel của trang:

| Mức độ khó | Nhịp | Giọng nói | SNR | Đúng |
|---|:--:|:--:|:--:|:--:|
| Phòng yên tĩnh | người bấm | không | không nhiễu | 60/60 |
| Quán cà phê | người bấm | −20 dB | 20 dB | 60/60 |
| Ngoài đường | người bấm | −14 dB | 12 dB | 35/60 |
| Cực khó | bấm vội | −10 dB | 8 dB | 10/60 |

- Giọng nói làm hỏng bằng cách khiến MỘT khung giữa tone bị loại (`level`). `dtmf_debounce` cắt
  dải ở đó nên một lần bấm thành hai chữ số. Không có lần nào giọng nói bị đọc thành phím: 10 giọng
  tổng hợp × 30 s đứng một mình cho 0 phím.
- Tone 45-70 ms đọc được 0/40 số kể cả không nhiễu. `minRun = 2` cần hai khung 25,6 ms nằm trọn
  trong tone, lệch lưới xấu nhất thì tone phải dài khoảng 77 ms, nên bộ giải mã chưa đạt mức 40 ms
  của Q.24. Nhịp *bấm vội* vì vậy dùng tone 65-110 ms (60/60 khi không nhiễu).
- MATLAB khớp bản TypeScript từng chữ số. Ở một cảnh *Ngoài đường*: Goertzel `09123456788`, FFT
  `099123456788`, ngân hàng bộ lọc `0912345678` (đúng), cùng chiều với §7.6.
- Kết luận chạy mỗi bộ giải mã khối 3 lần trên cả đoạn 7-8 s, lấy lần nhanh nhất: Goertzel 8-16 ms,
  FFT 12-19 ms, ngân hàng bộ lọc 17-20 ms.
- Thử trọn đường (trình duyệt → cầu nối → MATLAB): đoạn 7,8 s nhận xong trong khoảng 8,5 s, đọc đúng
  10/10 chữ số, kết luận về trang ngay khi hết đoạn.

## 8. Cấu trúc thư mục

```
DMTF/
├─ src/gen/      dtmf_table  dtmf_generate  dtmf_addnoise
├─ src/decode/   goertzel_power  design_bpf_bank
│                dtmf_decode_fft  dtmf_decode_goertzel  dtmf_decode_filterbank
├─ src/util/     dtmf_segment  dtmf_decide  dtmf_debounce  dtmf_metrics
├─ app/          dtmf_run  dtmf_listen  dtmf_judge  DTMFApp  DTMFForensic  DTMFLive  DTMFLine
│  └─ ui/        ui_refresh  ui_plot_{wave,psd,map,bars,spec}  ui_live_draw  ui_pad
│                ui_theme  ui_play  ui_mic
├─ tests/        run_all_tests  test_*.m
├─ scripts/      dev_harness  make_coeffs  run_bench  make_figures  make_cover  publish_figures
├─ data/         wav/  mat/ (coeffs.mat sinh tại chỗ, §6(b))
├─ results/      figures/  bench.mat (sinh lại được, không commit)
├─ report/       template/ (LaTeX; Figures/ do publish_figures chép sang)
├─ slides/  docs/ (study/KE_HOACH.md, ui_naming.md)
└─ web/          điện thoại minh họa (React + Vite), chỉ phát, không giải mã. Nối đường dây thì
                 menu đi theo phím MATLAB báo về (§7.10); src/forensic/ là màn giám định
                 (#giam-dinh, §7.11); server/line.ts là cầu nối, chỉ chạy trong npm run dev / preview
```

`DTMFApp` là `classdef ... < handle` tự dựng `uifigure`, không dùng `.mlapp` (nhị phân, không
diff, không test được). `ui_refresh` chỉ đụng chín thành phần `AxWaveX`, `AxPsdX`, `AxWave`,
`AxPsd`, `AxMap`, `AxBars`, `TxtLog`, `LblDecoded`, `S`, nên mọi đối tượng có đủ chín thành phần
đó đều thỏa hợp đồng. Tên component theo `docs/ui_naming.md`. `ui_plot_spec` chỉ vẽ hình H2.1 của
báo cáo.

### 7.12 Dung sai tần số

07/10/2026. Mười hai phím, tone 100 ms, không nhiễu, cả hai tone lệch cùng một tỉ lệ so với tần số
chuẩn; ô là số phím (trên 12) được nhận đúng.

| Lệch | −3,5% | −1,5% | −1% | −0,5% | 0 | +0,5% | +1% | +1,5% | +3,5% |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| FFT | 0 | 3 | 9 | 10 | 12 | 12 | 8 | 4 | 0 |
| Goertzel | 0 | 1 | 6 | 11 | 12 | 12 | 8 | 6 | 0 |
| Ngân hàng bộ lọc | 0 | 0 | 0 | 12 | 12 | 12 | 0 | 0 | 0 |

Yêu cầu *từ chối* ±3,5% đạt ở cả ba. Yêu cầu *nhận* ±1,5% của ITU-T Q.24 **không** đạt: ngưỡng
`rho ≥ 0,70` làm khung lệch tụt dưới ngưỡng, và bộ lọc băng ≈ 25 Hz hẹp hơn 22 Hz (1,5% của 1477 Hz)
nên ngân hàng bộ lọc chỉ nhận chắc tới ±0,5%. Con số "≤ 1,4%" ở README là độ lệch của bin gần nhất
so với tần số chuẩn, không phải dung sai mà bộ giải mã chấp nhận. Chưa có test cho mục này.

