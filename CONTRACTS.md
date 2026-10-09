# Hợp đồng hàm

Mục 1 đến 6 và mục 8 là luật bắt buộc. Mục 7 là số liệu đo, giải thích vì sao có các luật đó.
Mã nguồn trích dẫn số mục (§2, §6(h), §7.13…), nên khi sửa phải giữ nguyên số mục.

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

%% Ba bộ giải mã, cùng một chữ ký
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
S = dtmf_run(S)                    % giải mã khối
L = dtmf_listen(L, chunk)          % giải mã luồng (micro, đường dây)
J = dtmf_judge(that, doc)          % đối chiếu số thật với số đọc được (màn giám định)
[x, info] = dtmf_readaudio(file)   % tệp âm thanh -> 1×N một kênh ở 8 kHz
```

## 2. Luật cứng

- Mọi giá trị rỗng là `1×0`, không phải `''` (`0×0`), vì `strcmp` và `isequal` phân biệt hai cỡ này.
  Test kiểm rỗng bằng `verifyEmpty` cùng `verifyClass`, không dùng `verifyEqual(x, '')`.
- `src/` không gọi `figure`, `plot`, `disp`, `sound`, `input`.
- Chỉ `app/ui/*.m` và các script `dev_harness`, `run_bench`, `make_figures`, `make_cover` được vẽ
  hay phát âm thanh.
- Trong `app/`, chỉ ba lớp trung gian `dtmf_run` (khối), `dtmf_listen` (luồng) và `dtmf_judge`
  (đối chiếu) được gọi `src/decode/` và `src/util/`. `dtmf_listen` dùng lại bộ giải mã khối và
  `dtmf_debounce`, không có vòng đo hay vòng gộp riêng (§7.9).
- `tests/` và `scripts/` được gọi thẳng `src/`.
- `app/ui/*.m` chỉ vẽ cái có sẵn trong `S` (§6(h)). Ngoại lệ duy nhất là hằng số `dtmf_table()`.
- `DTMFLine` chỉ đổi byte thành mẫu, giống `audiorecorder`. Âm thanh vẫn đi qua `dtmf_listen`.
- `dtmf_readaudio` đọc tệp, gộp kênh và đổi tần số lấy mẫu bằng `resample`. `DTMFApp` không tự
  xử lý mẫu của tệp.
- Màn giám định không nhận đáp án trước khi kết luận. Trang chỉ gửi `reveal` sau khi nhận
  `verdict`. Nếu `reveal` đến khi còn đang nghe, `DTMFForensic` kết luận trước rồi mới đối chiếu.
- Định danh lỗi có dạng `'ham:loi'`, chỉ dùng ASCII.
- Khối `arguments` là mặt hợp đồng. Không thêm validator, cần chặn thì chặn trong thân hàm.
- Không sửa pragma `%#ok<...>` sẵn có, không thêm pragma mới. Sửa nguyên nhân gây cảnh báo.

## 3. Luật dùng toolbox

Tự viết phần được chấm, dùng thư viện cho phần phụ trợ. Chỉ dùng MATLAB và Signal Processing Toolbox.

- Tự viết `goertzel_power`, ngân hàng bộ lọc cộng hưởng, luật quyết định, debounce, metrics và
  cộng nhiễu theo SNR.
- Dùng `hamming`, `tukeywin` của toolbox. `spectrogram`, `pwelch`, `freqz`, `zplane` chỉ dùng để vẽ
  và kiểm chứng, không nằm trong luồng giải mã.
- `goertzel` của toolbox chỉ có trong `tests/test_goertzel.m` để đối chứng.
- `design_bpf_bank` dựng bằng công thức cộng hưởng, không dùng `filterDesigner`.
- Micro mở bằng `audiorecorder`, không dùng `audioDeviceReader` của Audio Toolbox.

## 4. Quy ước help và comment

File `.m` lưu UTF-8 không BOM. Comment viết tiếng Việt có dấu, số thập phân dùng dấu chấm, nhãn
dùng `TODO(C):` và `LƯU Ý:`.

Khối help nằm ngay dưới `function`, kết thúc ngay trên `arguments`, không có dòng `%` trống. Mẫu
là `dtmf_generate.m` và `goertzel_power.m`. Thứ tự các phần như sau.

1. Dòng H1 `%TEN_HAM Mô tả một dòng`, tên viết hoa, không có dấu chấm cuối.
2. Một dòng đời thường, lùi một dấu cách, cho người chưa học DSP.
3. Cú pháp `[OUT] = TEN_HAM(IN)`.
4. `Các bước hoạt động:` đánh số theo thứ tự các khối trong thân hàm, mỗi bước 1-2 dòng, công
   thức viết bằng cú pháp MATLAB.
5. `Input:`, `Tham số tên–giá trị (mặc định trong ngoặc):`, `Output:`, mỗi dòng có dạng
   `tên: kích thước kiểu, mô tả [đơn vị]`.
6. `Example:` chạy được, kết quả ghi ở comment cuối dòng. Đây là phần cuối cùng.

Không đặt `See also` (đã có §8) và `Tham khảo:` (đã có `report/template/references.bib`).

## 5. Thông số chốt sẵn

| Tham số | Giá trị |
|---|---|
| f_s | 8000 Hz |
| Tone / nghỉ | 100 ms / 50 ms (800 / 400 mẫu) |
| Khung Goertzel | N = 205, hop 205, Δf ≈ 39,02 Hz, bin 18 20 22 24 / 31 34 38 |
| Khung FFT | N = 256, hop 128, Hamming, Δf = 31,25 Hz, bin 22 25 27 30 / 39 43 47 |
| Dung sai tần số | Chuẩn yêu cầu nhận ≤ ±1,5% và từ chối ≥ ±3,5%. Kết quả đo ở §7.12 |
| Twist | Thuận ≤ 4 dB, nghịch ≤ 8 dB |
| Ngưỡng quyết định | Đỉnh ≥ 6 dB so với bin nhì cùng nhóm, Σ7 bin ≥ 70% năng lượng khung |
| Ngân hàng bộ lọc | r = 0,99, BW ≈ 25 Hz |

## 6. Quyết định chốt bổ sung

### (a) Chuẩn hóa `E`

Mỗi bộ giải mã chia `E` cho năng lượng khung trước khi gọi `dtmf_decide`. Nhờ vậy `sum(E(1:7))`
chính là tỉ lệ năng lượng tại bảy tần số chuẩn.

```matlab
E = E_raw / (frameN * sum(frame.^2) / 2);                % Goertzel
cg = sum(w)^2 / (frameN * sum(w.^2));                    % FFT: bù cửa sổ, Hamming(256) -> 0,7317
E  = E_raw / (frameN * sum((w.*frame).^2) / 2 * cg);
E = E_raw / sum(frame.^2);                               % ngân hàng bộ lọc (miền thời gian)
```

`E` không có thứ nguyên, so được giữa ba phương pháp, và là cổng chặn mức tuyệt đối duy nhất.
Thiếu `cg` thì nhánh FFT loại mọi khung (§7.1). Với ngân hàng bộ lọc, `rho` có thể vượt 1 (§7.6).

### (b) Bin hài bậc 2 thích nghi theo từng khung

```
k_peak = argmax E(1:7)                    % bin chuẩn mạnh nhất
k_harm = min(2*k_peak, floor(frameN/2))   % floor chỉ để phòng vệ
Điều kiện 5: E(8) <= 0.5*min(rowPeak, colPeak), ngược lại reject = 'harmonic'
```

Vì vậy `design_bpf_bank` trả 1×14 (7 bộ chuẩn và 7 bộ tần số gấp đôi), và
`dtmf_decode_filterbank` gán `E(8,i) = E_harm(argmax E(1:7,i), i)`.

`data/mat/coeffs.mat` sinh bằng `scripts/make_coeffs.m`, lưu kèm `fs`, `r`, `withHarm` và không
commit. Khi nạp, nếu lệch một trường thì bỏ file và dựng lại bằng công thức, để hệ số cũ không âm
thầm thay công thức mới. Test truyền `'coeffs'` tường minh để chạy cả hai nhánh.

### (c) Công thức `info.conf`

```
conf = 0                                            nếu reject ~= 'none'
conf = rho * min(1, min(dRow, dCol) / (2*peakDb))   nếu reject == 'none'
   rho = min(1, sum(E(1:7))),  dRow = 10*log10(rowPeak/rowPeak2),  dCol tương tự
```

`conf` thuộc [0, 1] và bằng 0 khi và chỉ khi khung bị loại. `min(1, ·)` quanh `rho` chỉ để phòng
khi nơi gọi quên chuẩn hóa `E`.

### (d) Mốc thời gian của `dtmf_segment`

```
tStart = (idx(1) - 1)/fs,   tEnd = idx(2)/fs     % tEnd - tStart = frameN/fs
```

Cùng quy ước thời lượng với `dtmf_generate`. Khi `hop = frameN` thì `seg(i).tEnd == seg(i+1).tStart`.

### (e) `info.tFrame` là tâm khung

```
info.tFrame(i) = (seg(i).tStart + seg(i).tEnd) / 2
```

Cả ba bộ giải mã dùng chung quy ước này. Lấy tâm khung để đường của FFT (N = 256) không lệch
3,19 ms so với Goertzel (N = 205).

### (f) Debounce dùng chung, dải dài ≥ 2 khung

Cả ba bộ giải mã gọi `dtmf_debounce`, không bộ nào tự viết vòng gộp. Các khung liên tiếp cùng phím
gộp thành một dải, khung bị loại (`rowIdx = 0`) cắt dải. Dải dài từ `minRun` khung trở lên mới
sinh một ký tự.

`minRun = 2` vì phím 100 ms dài 3,9 khung, nên dải chỉ một khung không thể là phím thật. Với
`minRun = 1`, ngân hàng bộ lọc nhân đôi phím lặp (§7.5).

### (g) `dtmf_metrics` tính `acc` từ `editDist`

```matlab
acc = 1 - editDist / max(numel(keysTrue), numel(keysHat));   % hai chuỗi rỗng -> 1
```

Không đếm ô khớp lúc truy vết, vì số đó phụ thuộc thứ tự ưu tiên truy vết (§7.8) và làm `acc`
mâu thuẫn với `editDist`. Hệ quả là `trace(confusion)` có thể lớn hơn `acc*max(K,L)`.

- Truy vết ưu tiên chéo, rồi xóa, rồi chèn.
- `confusion` chỉ ghi bước chéo. Chèn và xóa không có ô.
- Thứ tự phím là `'147*2580369#'`, duyệt `dtmf_table().keys` theo cột. Duyệt theo hàng sẽ ra ma
  trận chuyển vị mà hình vẫn trông hợp lý.
- Ký tự ngoài 12 phím gây lỗi `dtmf_metrics:badKey`.
- `align` (2×n char, `'-'` là ô trống) ghi đúng đường truy vết đó. `web/src/forensic/align.ts`
  dùng cùng thuật toán và cùng thứ tự ưu tiên, nên trang và `DTMFForensic` tô chữ số giống nhau.

### (h) Tầng UI không tính toán

`app/dtmf_run.m` tính sẵn mọi con số cho UI.

```matlab
S.iSel = argmax(info.conf);                         % 0 nếu không có khung nào
S.thr  = 0.5 * min(max(E(1:4)), max(E(5:7)));       % E = info.E(:, S.iSel)
[S.keysHat, S.info] = dtmf_decode_xxx(S.y - mean(S.y), 'fs', S.fs);
```

- `thr` là điều kiện 5 (hài bậc 2), điều kiện duy nhất vẽ được thành đường ngang trên `E`.
- Khi `nFrame = 0` thì `iSel = 0`, `thr = 0`, và `ui_plot_bars` xóa trục.
- Trừ trung bình trước khi giải mã (§7.7) nhưng không ghi đè `S.y`, để hình vẽ đúng cái người
  dùng nghe.
- `S.lastError` rỗng là `blanks(0)`.

## 7. Số liệu đã đo

### 7.1 Hệ số bù cửa sổ nhánh FFT

21/09/2026, 41 phím, khung 256/128. Thiếu `cg`, `sum(E(1:7))` trên khung DTMF thật lớn nhất chỉ
0,6929, dưới ngưỡng 0,70, nên 0/41 phím đúng. Có `cg` thì 41/41 phím đúng.

### 7.2 Độ chính xác theo SNR

Đo sơ bộ với nhiễu AWGN, `rng(2026)`, trước khi chốt `minRun = 2`. Độ chính xác giữ 1,00 tới
8 dB rồi giảm dần, Goertzel còn 0,85 ở 6 dB và 0,40 ở 4 dB. Vì vậy demo chạy ở SNR ≥ 10 dB. Khung
chỉ có nhiễu cho `sum(E(1:7))` lớn nhất 0,2423 trên 2000 khung. Số chính thức của báo cáo lấy từ
`scripts/run_bench.m`.

### 7.3 Số cách căn lề khung

Mỗi phím chiếm 1200 mẫu nên có `hop/gcd(mod(1200,hop), hop)` cách căn lề. Goertzel (hop 205) có
41 cách, test bằng chuỗi 41 phím. FFT (hop 128) có 8 cách, test bằng chuỗi 16 phím. Test kiểm tra
lại `gcd`, nên khi đổi `toneMs`, `pauseMs` hay `hop` thì lỗi lộ ra ngay.

### 7.4 Giá trị kiểm chứng Goertzel

`N = 16, k = 3, x[n] = cos(2π·3n/16)` cho `P = 64` (`|X[3]|² = (N/2)²`), sai lệch < 1e-9.

### 7.5 Debounce `minRun = 2`

22/09/2026. Với `minRun = 1`, dao động dư của ngân hàng bộ lọc trong khoảng lặng sinh thêm một dải
một khung. Kết quả là phím lặp bị nhân đôi ở 29/42 cách căn lề và 30/30 chuỗi 41 phím bị hỏng. Đổi
khung sang 256/128 vẫn hỏng 22/30. `minRun = 2` sửa hết (0/42, 0/30) và không làm giảm độ chính xác
ở SNR ≥ 10 dB. Goertzel và FFT không bị lỗi này.

### 7.6 Nhánh ngân hàng bộ lọc

22/09/2026, `r = 0,99`, khung 205/205.

- Thiết kế đúng công thức. `abs(|H(f0)|-1)` = 2,2e-16, BW −3 dB đo được 25,59 Hz so với lý thuyết
  `(1-r)·fs/π` = 25,46 Hz.
- Quá độ kéo dài `5τ` = 62,2 ms, khoảng 2,4 khung đầu mỗi tone. Do đó phải lọc cả tín hiệu một lần
  rồi mới chia khung.
- `rho` vượt 1 (tới 3,08) vì dao động dư trong khoảng lặng. Với tone đúng tần số thì vô hại, vì dao
  động dư lặp lại đúng phím vừa bấm (0/180 ca sai). Không viết test cận trên của `rho` cho nhánh
  này. Với tone lệch tần hoặc tiếng nói tắt hẳn thì dao động dư sinh phím giả (§7.13).
- Chịu nhiễu tốt nhất. Ngân hàng bộ lọc giữ 1,00 tới 4 dB, còn Goertzel và FFT bắt đầu sai từ
  6 dB. Lý do là 14 bộ cộng hưởng hẹp đã loại nhiễu ngoài băng trước khi đo.

### 7.7 Thành phần một chiều làm hỏng cả ba bộ giải mã

22/09/2026, `'0912345'`, biên độ đỉnh 0,5. Từ DC 0,20 trở lên, cả ba bộ giải mã trả chuỗi rỗng.
DC làm `sum(frame.^2)` tăng lên (gấp 1,65 lần ở DC 0,20) nên mọi khung bị loại vì `'level'`.
Micro thường có DC, nên `dtmf_run` trừ trung bình trước khi giải mã. Bộ giải mã giữ nguyên.

### 7.8 Hai công thức `acc`

23/09/2026. Vét cạn mọi cặp chuỗi dài 0..4 trên 3 ký tự, 978/14641 cặp (6,7%) cho `1 - editDist/max`
khác `nMatch/max`. Trên dữ liệu thật chỉ lệch 2/168 ca, tối đa 0,083. Cặp ngắn nhất phân biệt thứ
tự truy vết là `'12'`/`'3'`, nhờ ca này mà kiểm thử đột biến `dtmf_metrics` bắt được 9/9 lỗi.

### 7.9 Giải mã luồng (`dtmf_listen`)

29/09/2026. Mỗi lần gọi ghép H mẫu lịch sử với các khung mới, trừ trung bình, giải mã, rồi bỏ các
khung lịch sử. `H = hop*ceil(0.1*fs/hop)` (820 hoặc 896 mẫu), đủ dài cho quá độ của bộ cộng hưởng.

- Giải mã luồng cho cùng kết quả với giải mã khối ở 96/96 ca, với tín hiệu chặt thành đoạn ngẫu
  nhiên 1..1500 mẫu.
- Phím hiện ra 40-90 ms sau đầu tone, và 44-134 ms khi tính cả chu kỳ đọc micro 50 ms. FFT nhanh
  nhất, ngân hàng bộ lọc chậm nhất.
- Vòng loa laptop sang micro laptop không đáng tin. Hàng 697/770 Hz yếu hơn cột 14-21 dB nên bị
  loại vì twist. Demo bằng điện thoại thật hoặc đường dây §7.10.

### 7.10 Đường dây trang web → MATLAB

06/10/2026. Trang gửi chính các mẫu nó phát ra loa. Giao thức ở `web/src/line/protocol.ts`.

```
trang (worklet, nội suy về 8 kHz, int16) --WebSocket /line--> web/server/line.ts
  --TCP 127.0.0.1:8765, mỗi dòng một JSON, âm thanh base64--> DTMFLine --> dtmf_listen --> DTMFLive
```

- Cần cầu nối vì trình duyệt không mở được TCP, còn `tcpserver` cần Instrument Control Toolbox.
- `tcpclient` vào cổng chưa mở mất khoảng 3,4 s, nên `DTMFLive` chỉ tự nối lúc mở, sau đó nối bằng nút.
- `tcpclient` không báo khi đầu kia đóng, nên cầu nối gửi `ping` mỗi giây. Im 3,5 s là coi như đứt.
- Thử trọn đường với `'0912345*#'` cho 9/9 phím, phím về điện thoại khoảng 0,24 s sau đầu tone.

### 7.11 Màn giám định ghi âm (`DTMFForensic`)

07/10/2026. Trang dựng đoạn ghi âm 8 kHz (`web/src/forensic/scene.ts`), phát ra loa và gửi đúng các
mẫu đó sang MATLAB.

```
trang #giam-dinh --case, pcm..., end--> cầu nối --> DTMFLine --> dtmf_listen (đọc dần)
                                                             --> dtmf_run × 3 (kết luận) --> verdict
                 --reveal (chỉ sau verdict)-->                   --> dtmf_judge × 3 (đối chiếu)
```

Tỉ lệ đọc đúng cả số 10 chữ số trên 60 số ngẫu nhiên, đo bằng bản Goertzel của trang.

| Mức độ khó | Nhịp | Giọng nói | SNR | Đúng |
|---|:--:|:--:|:--:|:--:|
| Phòng yên tĩnh | người bấm | không | không nhiễu | 60/60 |
| Quán cà phê | người bấm | −20 dB | 20 dB | 60/60 |
| Ngoài đường | người bấm | −14 dB | 12 dB | 35/60 |
| Cực khó | bấm vội | −10 dB | 8 dB | 10/60 |

- SNR ở đây đo trên các đoạn có tone, nên cao hơn SNR của §7.2 khoảng 1,8 dB.
- Giọng nói gây lỗi bằng cách làm một khung giữa tone bị loại, khiến một lần bấm thành hai chữ số.
  Mười giọng tổng hợp, mỗi giọng 30 s đứng riêng, cho 0 phím.
- Tone ngắn hơn khoảng 77 ms có thể không đủ hai khung trọn, nên không đọc được. Bộ giải mã vì vậy
  chưa đạt mức 40 ms của Q.24, và nhịp *bấm vội* dùng tone 65-110 ms.
- MATLAB cho cùng kết quả với bản TypeScript đến từng chữ số.

### 7.12 Dung sai tần số

07/10/2026. Mười hai phím, tone 100 ms, không nhiễu, cả hai tone lệch cùng một tỉ lệ. Mỗi ô là số
phím (trên 12) được nhận đúng.

| Lệch | −3,5% | −1,5% | −1% | −0,5% | 0 | +0,5% | +1% | +1,5% | +3,5% |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| FFT | 0 | 3 | 9 | 10 | 12 | 12 | 8 | 4 | 0 |
| Goertzel | 0 | 1 | 6 | 11 | 12 | 12 | 8 | 6 | 0 |
| Ngân hàng bộ lọc | 0 | 0 | 0 | 12 | 12 | 12 | 0 | 0 | 0 |

Yêu cầu từ chối ±3,5% đạt khi thử từng phím riêng lẻ. Trong chuỗi có khoảng nghỉ, ngân hàng bộ
lọc vẫn nhận nhầm do dao động dư (§7.13). Yêu cầu nhận ±1,5% của ITU-T Q.24 *không* đạt, vì khung
lệch tần tụt dưới ngưỡng `rho ≥ 0,70`. Ngân hàng bộ lọc chỉ nhận chắc tới ±0,5% vì băng thông
khoảng 25 Hz hẹp hơn độ lệch 1,5% ở 1477 Hz (22 Hz). Độ lệch ≤ 1,4% giữa bin gần nhất và tần số
chuẩn không phải dung sai mà bộ giải mã chấp nhận.

### 7.13 Bộ dữ liệu `data/wav`

08/10/2026. `scripts/make_dataset.m` sinh 139 tệp kèm nhãn `data/wav/manifest.csv`.
`tests/test_dataset.m` giải mã từng tệp qua `dtmf_readaudio` rồi `dtmf_run`.

- Cột `kyVong` nhận một trong ba giá trị. `dung` là cả ba phải đọc đúng từng phím, `rong` là cả ba
  phải im lặng, `thong_ke` chỉ dùng để đo.
- Cột `ngoaiLe` ghi bộ giải mã đang sai kỳ vọng. Test báo đỏ khi ngoại lệ không còn đúng.
- Sinh lại ra đúng từng byte. Bộ dữ liệu không có WAV float vì khối PEAK chứa dấu thời gian.

Mọi tệp `dung` đều được cả ba đọc đúng. Dưới vách SNR, độ chính xác trung bình như sau.

| Điều kiện | FFT | Goertzel | Ngân hàng bộ lọc |
|---|:--:|:--:|:--:|
| AWGN 6 dB | 1,00 | 0,95 | 1,00 |
| AWGN 4 dB | 0,60 | 0,77 | 1,00 |
| AWGN 2 dB | 0,02 | 0,17 | 0,77 |
| AWGN 0 dB | 0,00 | 0,00 | 0,05 |
| Điện lưới 50 Hz 5 dB | 0,83 | 0,90 | 1,00 |
| Điện lưới 50 Hz 2,5 dB | 0,00 | 0,06 | 1,00 |
| Tiếng nói 5 dB | 0,83 | 0,71 | 1,00 |
| Hiện trường *Ngoài đường* | 0,98 | 1,00 | 0,98 |
| Hiện trường *Cực khó* | 0,78 | 0,70 | 0,90 |

Ngân hàng bộ lọc sinh phím giả khi âm thanh tắt đột ngột. Khung ngay sau đó có năng lượng gần 0
trong khi bộ cộng hưởng vẫn còn dao động, nên `rho` vọt lên và khung được nhận. FFT và Goertzel
không có trạng thái nên không bị.

- Giọng tổng đài thật 18 s cho một phím `9` giả ngay sau khi câu chào tắt hẳn về 0. Cộng nền ồn
  từ −70 dBFS là hết lỗi.
- Tone lệch ±3,5% cho phím giả trong khoảng nghỉ (9 phím ở −3,5%, 2 phím ở +3,5% trên 41 cách căn
  lề). Nền ồn −50 dBFS không chữa được.
- Không sửa thuật toán, vì sẽ làm lệch số bench của báo cáo.

## 8. Cấu trúc thư mục

```
DMTF/
├─ src/gen/      dtmf_table  dtmf_generate  dtmf_addnoise
├─ src/decode/   goertzel_power  design_bpf_bank
│                dtmf_decode_fft  dtmf_decode_goertzel  dtmf_decode_filterbank
├─ src/util/     dtmf_segment  dtmf_decide  dtmf_debounce  dtmf_metrics
├─ app/          dtmf_run  dtmf_listen  dtmf_judge  dtmf_readaudio
│                DTMFApp  DTMFForensic  DTMFLive  DTMFLine
│  └─ ui/        ui_refresh  ui_plot_{wave,psd,map,bars,spec}  ui_live_draw  ui_pad
│                ui_theme  ui_play  ui_mic
├─ tests/        run_all_tests  test_*.m
├─ scripts/      dev_harness  make_coeffs  make_dataset  run_bench  make_figures  make_cover  publish_figures
├─ data/         wav/ (bộ dữ liệu, §7.13)  mat/ (coeffs.mat sinh tại chỗ, §6(b))
├─ results/      figures/  bench.mat (sinh lại được, không commit)
├─ report/       template/ (LaTeX, Figures/ do publish_figures chép sang)
├─ slides/  docs/
└─ web/          điện thoại minh họa (React + Vite), chỉ phát, không giải mã
                 src/forensic/ là màn giám định (§7.11), server/line.ts là cầu nối (§7.10)
```

`DTMFApp` là `classdef ... < handle` tự dựng `uifigure`, không dùng `.mlapp` vì file đó là nhị
phân, không diff và không test được. `ui_refresh` chỉ dùng chín thành phần `AxWaveX`, `AxPsdX`,
`AxWave`, `AxPsd`, `AxMap`, `AxBars`, `TxtLog`, `LblDecoded`, `S`. Đối tượng nào có đủ chín thành
phần đó đều thỏa hợp đồng. Tên component theo `docs/ui_naming.md`.
