# Kế hoạch hoàn thành dự án DTMF (tự làm, 1–2 tuần)

> Tài liệu theo dõi tiến độ. Tick trực tiếp vào các ô `- [ ]` khi làm xong từng việc.

## Bối cảnh

Hoạt động nhóm 18 người không hiệu quả. Kết quả kiểm tra toàn bộ repo `D:\PROJECT\DMTF`:

- **14/15 hàm MATLAB là stub** — gọi vào là `error(...:notImplemented)`. Chỉ `src/gen/dtmf_table.m` chạy được.
- **Chưa có GUI**. `app/DTMFApp.mlapp` không tồn tại, trong khi đề bài tính **70% điểm GHP cho demo giao diện**.
- **`data/` rỗng** — không có `coeffs.mat`, không có `.wav`, `results/figures/` trống.
- Điểm sáng: phần **đặc tả đã xong rất kỹ**. Mỗi stub đã có sẵn khối help tiếng Việt đầy đủ, khối `arguments`, và các bước `TODO(C):` đánh số. `CONTRACTS.md` đã chốt toàn bộ tham số. **Việc còn lại là điền thân hàm, không phải thiết kế lại.**
- Điểm sáng thứ hai: `docs/study/DTMF_LyThuyet.m` (1098 dòng) chứa **bản cài đặt tham chiếu chạy được** của 5 thuật toán cốt lõi — nhưng file này **chưa được git theo dõi**, mất máy là mất sạch.

Mục tiêu: tự viết code (có hướng dẫn từng bước), hoàn thành `src/` + tests + GUI + hình vẽ kết quả trong 1–2 tuần. **Viết báo cáo LaTeX nằm ngoài phạm vi**, nhưng hình ở Buổi 10 chính là đầu vào cho báo cáo.

---

## 3 phát hiện làm thay đổi kế hoạch (đã kiểm chứng bằng `matlab -batch`)

### P1 — Đã cài Signal Processing Toolbox · Communications Toolbox thì KHÔNG

Tình trạng hiện tại (đo bằng `matlab -batch`):

```
PROD: MATLAB                     26.1
PROD: Signal Processing Toolbox  26.1      ← đã cài
goertzel  exist=2   hamming   exist=2   spectrogram    exist=2
tukeywin  exist=2   freqz     exist=2   zplane         exist=2   filterDesigner exist=2
awgn      exist=0   ← thuộc Communications Toolbox, CHƯA cài
```

**Nguyên tắc phân chia: tự viết cái được chấm, dùng thư viện cái không được chấm.**

| Hạng mục | Cách làm | Vì sao |
|---|---|---|
| `goertzel_power` | ✍️ **Tự viết** | Đề bài Chủ đề 4 yêu cầu *cài đặt* Goertzel bằng IIR bậc 2. Gọi `goertzel()` là làm hỏng chính đề bài |
| Ngân hàng bộ lọc (`boLoc`) | ✍️ **Tự viết** | Đề bài yêu cầu thiết kế 8 bộ lọc hẹp Q cao. Công thức cộng hưởng cho phép *dẫn giải* được `r = 0.99` trong báo cáo |
| Luật quyết định, debounce, metrics | ✍️ **Tự viết** | Không có hàm dựng sẵn, và đây là phần lõi của bài |
| `hamming`, `tukeywin` | 📦 Dùng toolbox | Cửa sổ là chi tiết phụ trợ, không phải nội dung được chấm |
| `spectrogram` | 📦 Dùng toolbox | Chỉ để **hiển thị**; `ui_plot_spec.m` TODO đã kê sẵn dùng nó |
| `freqz`, `zplane` | 📦 Dùng toolbox | Chỉ để **kiểm chứng và vẽ**, không nằm trong luồng giải mã |
| `awgn` | ✍️ **Tự tính** | Chưa cài Communications Toolbox — mà công thức tay còn tốt hơn: kiểm soát SNR chính xác và tái lập được |

**Lợi ích lớn nhất của việc đã cài:** `tests/test_goertzel.m:23` gọi `goertzel()` — trước đây sẽ FAIL vô điều kiện, **giờ chạy thật và trở thành phép đối chứng độc lập** cho bản Goertzel bạn tự viết. Không cần sửa test nữa.

`docs/study/DTMF_LyThuyet.m` vẫn là nguồn chép cho `goertzelPower` (L1020), `boLoc` (L1039), `levenshtein` (L1049). Hai hàm `hammingTay` (L1014) và `dapUngTanSo` (L1032) giờ có thể thay bằng `hamming`/`freqz` của toolbox.

> Nếu sau này cần `awgn` thật: cài thêm **Communications Toolbox** qua Add-Ons. Kế hoạch không phụ thuộc vào nó.

### P2 — Giao diện chạy được headless

`uifigure('Visible','off')` + `uiaxes` + `exportgraphics` → OK. Toàn bộ tầng UI **dựng, chạy, test tự động và chụp hình** được bằng `matlab -batch`, không cần người bấm chuột. Đây là chìa khóa giải bài toán `.mlapp` (Buổi 9) và sinh hình báo cáo (Buổi 10).

### P3 — `src/gen/dtmf_table.m` đang bị sửa hỏng (chưa commit)

`git diff` cho thấy lần reformat gần nhất **xóa mất khối `Tham khảo:` và dòng `See also`** — vi phạm chính `CONTRACTS.md` §"Quy ước chú thích" mục 6–7, làm hỏng `lookfor`/`help`. Xử lý: revert ở Buổi 0.

---

## Chốt 3 điểm đặc tả còn treo

Ba điểm này đang chặn `dtmf_decide`, mà `dtmf_decide` chặn cả 3 bộ giải mã. **Nút thắt của toàn dự án.**

### (a) `energyRatio` — bộ giải mã tự chuẩn hóa `E`, KHÔNG đổi chữ ký hàm

Vấn đề: luật "Σ8 bin ≥ 70% năng lượng khung" cần năng lượng toàn khung, nhưng `dtmf_decide(E, opt)` chỉ nhận `E (8,:)`.

**Chốt:** mỗi bộ giải mã chia `E` cho năng lượng khung trước khi gọi `dtmf_decide`, khi đó `sum(E(1:7))` **chính là** tỉ lệ năng lượng:

```
Goertzel (không cửa sổ):  E = E_raw / (frameN * sum(frame.^2) / 2)
FFT (có Hamming):         E = E_raw / (frameN * sum((w.*frame).^2) / 2)   ← năng lượng ĐÃ nhân cửa sổ
Filter bank (miền t/g):   E = E_raw / sum(frame.^2)
```

Vì sao chọn cách này thay vì thêm tham số `'frameEnergy'`:
1. **Không sửa hợp đồng.** `CONTRACTS.md` dòng 25 và khối `arguments E (8,:) double` giữ nguyên từng ký tự.
2. `E` thành đại lượng **không thứ nguyên, so sánh được giữa 3 phương pháp** — nhờ đó đường ngưỡng `thr` duy nhất trong `ui_plot_bars` mới có nghĩa trên cả 3 (nếu không là 3 thang đo khác nhau).
3. Đây là **cổng chặn mức tuyệt đối duy nhất**. Bốn điều kiện còn lại đều là tỉ số nên bất biến thang đo — khung toàn nhiễu vẫn qua hết. Chuẩn hóa xong, khung nhiễu thuần chỉ đạt ≈ 0.07 → bị loại đúng.
4. Ví dụ trong help (`dtmf_decide.m:45`) vẫn cho `r=2, c=2, 'none'` → không phải viết lại help.

**Cái giá, nói thẳng:** với ngưỡng 0.70 đã chốt, cách này tạo **vách chính xác ở SNR ≈ 8 dB** — dưới mức đó mọi khung bị loại với `reject='level'`. Hai cách xử lý, đều rẻ:
- Đây là **kết quả để báo cáo, không phải lỗi**. Histogram lý do loại khung ở 5 dB vs 15 dB là hình đẹp + đoạn phân tích tốt.
- Khi demo, **kéo thanh SNR ở vùng ≥ 10 dB**. `run_bench` quét thêm `energyRatio ∈ {0.70, 0.40, 0}` để vẽ cả hai đường.

### (b) Hài bậc 2 — lấy nguyên định nghĩa trong file study

`docs/goertzel.md` được nhắc tới nhưng **không tồn tại** và sẽ không tìm lại được. Nguồn còn sống duy nhất là `DTMF_LyThuyet.m` §8.4 (L713–727) và §13:

```
k_peak = argmax E(j),  j = 1..7          % bin chuẩn mạnh nhất — KHÔNG phải 1633 Hz
k_harm = min(2*k_peak, floor(frameN/2))  % N=205 → ≤102 ; N=256 → ≤128
E(8)   = công suất tại bin k_harm        % thay đổi theo từng khung
Điều kiện 5:  E(8) <= 0.5*min(rowPeak, colPeak)   ngược lại reject = 'harmonic'
```

Ghi vào help: `floor(N/2)` thực tế **không bao giờ cắt** (xấu nhất `2*38=76 ≤ 102`), chỉ là chốt phòng vệ — nói rõ kẻo người đọc tưởng nó có tác dụng.

**Điểm vướng thật ở filter bank:** `E(8)` phụ thuộc từng khung nên bank 8 bộ lọc cố định không làm được. Chốt: `design_bpf_bank` thêm `'withHarm' (1,1) logical = true`, trả về **1×14** — 7 bộ cộng hưởng chuẩn + 7 bộ tại tần số gấp đôi. `dtmf_decode_filterbank` lọc qua cả 14 (14×205 phép nhân/khung, không đáng kể), mỗi khung lấy `d = argmax E(1:7)` rồi gán `E(8,i) = E_harm(d,i)`. Nhờ vậy `E(8)` của filter bank **cùng ngữ nghĩa** với hai phương pháp kia.

### (c) `info.conf` — hợp đồng bắt buộc có, chưa ai định nghĩa công thức

```
conf = 0                                             nếu reject ~= 'none'
conf = rho * min(1, min(dRow, dCol) / (2*peakDb))    nếu reject == 'none'
   rho  = sum(E(1:7))                    (đã chuẩn hóa theo (a))
   dRow = 10*log10(rowPeak/rowPeak2)
   dCol = 10*log10(colPeak/colPeak2)
```

Nằm trong `[0,1]`, bằng 0 khi bị loại, giảm đơn điệu theo SNR. Nhờ đó `ui_refresh` chọn khung hiển thị bằng `[~, iSel] = max(info.conf)` — tự nhiên và giải thích được khi vấn đáp.

---

## Cách làm việc mỗi buổi

1. **Nghe giảng** — thuật toán, công thức, và cái bẫy cụ thể sẽ gặp. Đối chiếu dòng tương ứng trong `DTMF_LyThuyet.m`.
2. **Tự viết** thân hàm. Help + `arguments` đã có sẵn → **giữ nguyên, chỉ điền phần dưới `TODO(C):`**.
3. **Review** — chỉ lỗi và giải thích *tại sao* sai, không sửa hộ.
4. **Chạy test.** Xanh mới sang buổi sau.

Lệnh dùng suốt dự án:
```bash
MLB='C:\Program Files\MATLAB\R2026a\bin\matlab.exe'
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```

---

# BẢNG THEO DÕI TỔNG

| Buổi | Nội dung | Giờ | Phụ thuộc | Kết quả kiểm chứng | Trạng thái |
|:--:|---|:--:|:--:|---|:--:|
| 0 | Dọn dẹp + chốt đặc tả | 0.75 | — | `help dtmf_table` có `See also` | ☐ |
| 1 | `dtmf_generate` + `dtmf_addnoise` | 2.0 | 0 | `test_table` + `test_generate` xanh | ☐ |
| 2 | `dtmf_segment` + `goertzel_power` | 1.5 | 0 | Goertzel `P = 64.000000` | ☐ |
| 3 | ⚠️ **`dtmf_decide`** — NÚT THẮT | 2.0 | 2 | `test_decide` xanh (9 ca) | ☐ |
| 4 | `dtmf_decode_goertzel` | 2.0 | 1,3 | 🎉 giải mã `'0912345'` đúng | ☐ |
| 5 | `dtmf_decode_fft` | 1.5 | 4 | FFT ≡ Goertzel trên tín hiệu sạch | ☐ |
| 6 | `design_bpf_bank` + `filterbank` | 2.5 | 4 | `coeffs.mat` sinh ra, 3 phương pháp khớp | ☐ |
| 7 | `dtmf_metrics` | 1.0 | 4 | `acc == 1` cả 3 phương pháp | ☐ |
| 8 | `dtmf_run` + 3 hàm `ui_plot_*` | 2.0 | 7 | `test_ui_smoke` xanh, headless | ☐ |
| 9 | 🖥️ **Giao diện `DTMFApp`** | 3.0 | 8 | App giải mã đúng, có tiếng | ☐ |
| 10 | Thực nghiệm + 8 hình | 2.0 | 9 | ≥ 8 file trong `results/figures/` | ☐ |

**Tổng ≈ 20.25 giờ.** Đường găng: `0 → 1 → 2 → 3 → 4 → {5,6} → 7 → 8 → 9 → 10`.

Gợi ý chia 12 ngày: ngày 1 (Buổi 0+1) · ngày 2 (2) · ngày 3 (3) · ngày 4 (4) · ngày 5 (5) · ngày 6–7 (6) · ngày 8 (7) · ngày 9 (8) · ngày 10–11 (9) · ngày 12 (10).

---

# CHI TIẾT TỪNG BUỔI

## ☐ Buổi 0 — Dọn dẹp + chốt đặc tả · 45 phút · chưa viết code

| | |
|---|---|
| **Mục tiêu** | Repo sạch, đặc tả hết treo, tài liệu khớp thực tế |
| **File sửa** | `src/gen/dtmf_table.m` (revert) · `CONTRACTS.md` · `README.md` · `.gitattributes` |
| **Nhánh** | Làm thẳng trên `main` (một mình code, không cần `dev`) |
| **Phụ thuộc** | — |

**Việc cần làm**
- [ ] `git add docs/study/ && git commit` — **làm trước mọi việc khác.** `DTMF_LyThuyet.m` và file kế hoạch này đang untracked
- [ ] `git checkout -- src/gen/dtmf_table.m` — phục hồi khối help bị xóa (P3)
- [ ] `CONTRACTS.md`: ghi 3 quyết định (a)(b)(c)
- [ ] `CONTRACTS.md`: ghi nguyên tắc **"tự viết cái được chấm, dùng thư viện cái không được chấm"** kèm bảng phân chia ở P1
- [ ] `CONTRACTS.md`: mở rộng danh sách được phép vẽ → thêm `scripts/make_figures.m`, `scripts/run_bench.m`
- [ ] `README.md` dòng 64–66: ghi rõ **cần Signal Processing Toolbox**; **không** cần Communications Toolbox (tự tính nhiễu)
- [ ] `README.md` dòng 88: bỏ quy định làm trên nhánh `dev` — làm một mình nên code thẳng trên `main`
- [ ] `.gitattributes`: thêm `*.m text working-tree-encoding=UTF-8` — hiện **chưa có luật `text` nào**, đây là lý do `git diff` cảnh báo LF→CRLF và là rủi ro hỏng dấu tiếng Việt
- [ ] Chạy thử `latexmk -xelatex main.tex` **một lần** (MiKTeX đã có) để không bị tải package 20 phút đúng hôm nộp

> `tests/test_goertzel.m` **giữ nguyên, không sửa gì** — đã cài toolbox nên `test_matchesBuiltinGoertzel` chạy thật và làm phép đối chứng cho bản tự viết ở Buổi 2.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); T=dtmf_table(); assert(isequal(T.map('5'),[2 2])); assert(contains(help('dtmf_table'),'See also')); disp('BUOI 0 OK')"
git log --oneline -1 -- docs/study/DTMF_LyThuyet.m
```
- [ ] Lệnh in `BUOI 0 OK`
- [ ] `DTMF_LyThuyet.m` đã có trong git

---

## ☐ Buổi 1 — `dtmf_generate` + `dtmf_addnoise` · 2 giờ

| | |
|---|---|
| **Mục tiêu** | Sinh được tín hiệu DTMF và cộng nhiễu đúng SNR |
| **File sửa** | `src/gen/dtmf_generate.m` · `src/gen/dtmf_addnoise.m` · `tests/test_generate.m` |
| **File thêm** | `tests/test_table.m` |
| **Phụ thuộc** | Buổi 0 |

**Việc cần làm**
- [ ] `dtmf_generate`: tra `dtmf_table()` lấy `fRow/fCol` cho từng ký tự
- [ ] `dtmf_generate`: cửa sổ côn dùng `tukeywin(nTone, 0.05)` (toolbox đã cài) — chống tiếng "click" ở biên tone
- [ ] `dtmf_generate`: chèn lặng `pauseMs` **giữa** các tone, không chèn trước tone đầu
- [ ] `dtmf_generate`: chuẩn hóa **sau cùng** `x = x/max(abs(x)) * opt.ampl`
- [ ] `dtmf_generate`: ghi `meta.onsets/offsets/fRow/fCol`
- [ ] `dtmf_addnoise`: **`awgn` không có** (Communications Toolbox chưa cài) — dùng công thức đã có sẵn trong help dòng 25–26: `v = v0 * sqrt(Px/(mean(v0.^2)*10^(snrDb/10)))`
- [ ] `dtmf_addnoise`: 3 nhánh `v0` = `randn` / `sin(2*pi*50*t)` / mẫu tiếng nói
- [ ] `dtmf_addnoise`: nhánh `'speech'` chưa có file → ném `error('dtmf_addnoise:missingSpeech', ...)`
- [ ] `tests/test_table.m`: khẳng định bảng bin `round(205*F/8000) == [18 20 22 24 31 34 38]` và `round(256*F/8000) == [22 25 27 30 39 43 47]`, sai lệch lớn nhất 1.36% < 1.5%
- [ ] `tests/test_generate.m`: thêm `numel(x) == K*nTone + (K-1)*nPause`; `meta.onsets(1)==0`; `offsets-onsets == 0.100`; `max(abs(x)) == ampl`; SNR của `hum50` trong ±0.5 dB

**Bẫy**
- `g = 10^(twistDb/20)` là hệ số **biên độ**, chỉ áp cho tone **cột** — đừng để lọt sang hàng.
- Chuẩn hóa trước khi ghép các đoạn sẽ làm sai `ampl` tổng.
- Nhánh `'speech'` **tuyệt đối không âm thầm fallback sang AWGN** — sai số liệu báo cáo mà không ai biết.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```
- [ ] `test_table` (5 ca) xanh
- [ ] `test_generate` (7 ca) xanh
- [ ] `test_goertzel` (2 ca) xanh — ca đối chứng với `goertzel()` của toolbox giờ chạy thật

---

## ☐ Buổi 2 — `dtmf_segment` + `goertzel_power` · 1.5 giờ

| | |
|---|---|
| **Mục tiêu** | Chia khung đúng công thức + lõi Goertzel khớp giá trị chuẩn |
| **File sửa** | `src/util/dtmf_segment.m` · `src/decode/goertzel_power.m` |
| **File thêm** | `tests/test_segment.m` |
| **Phụ thuộc** | Buổi 0 |

**Việc cần làm**
- [ ] `goertzel_power`: chép nguyên `DTMF_LyThuyet.m` L1020–1030
- [ ] `goertzel_power`: thêm chốt `x = x(1:N);` theo help ("chỉ dùng N mẫu đầu")
- [ ] `dtmf_segment`: `nFrame = floor((numel(y)-frameN)/hop)+1`
- [ ] `dtmf_segment`: **không zero-pad**, bỏ đuôi thừa
- [ ] `dtmf_segment`: `numel(y) < frameN` → struct rỗng `1×0`, **không ném lỗi**
- [ ] `tests/test_segment.m`: `nFrame` cho `(1000,205,205)→3`, `(1000,256,128)→6`, `(100,205,205)→0`; `seg(1).idx == [1 205]`; `seg(end).idx(2) <= numel(y)`; `tStart == (idx(1)-1)/fs`

**Bẫy**
- ⚠️ **Tuyệt đối không gọi `goertzel()` của toolbox trong `goertzel_power`.** Đề bài yêu cầu *cài đặt* thuật toán bằng IIR bậc 2; gọi hàm dựng sẵn là làm hỏng chính nội dung được chấm. `goertzel()` chỉ xuất hiện trong `tests/test_goertzel.m` với vai trò **phép đối chứng độc lập**.
- **`s1 = s2 = 0` mỗi lần gọi `goertzel_power`.** Study §8.3 đo được sai số phân kỳ tuyến tính nếu quên reset.
- Bản chép từ study **trùng khớp listing trong `report/template/main.tex` Phụ lục 1** — giữ giống nhau thì sau đỡ phải sửa báo cáo.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); n=0:15; P=goertzel_power(cos(2*pi*3*n/16),3,16); fprintf('P=%.9f\n',P); assert(abs(P-64)<1e-9); disp('GOERTZEL OK')"
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```
- [ ] In ra `P=64.000000000`
- [ ] `test_segment` xanh

---

## ☐ Buổi 3 — `dtmf_decide` · 2 giờ · ⚠️ NÚT THẮT

| | |
|---|---|
| **Mục tiêu** | Luật quyết định dùng chung cho cả 3 bộ giải mã |
| **File sửa** | `src/util/dtmf_decide.m` |
| **File thêm** | `tests/test_decide.m` |
| **Phụ thuộc** | Buổi 2 |
| **Vì sao là nút thắt** | Cả 3 bộ giải mã và mọi test end-to-end đều nằm sau nó |

**Năm điều kiện — đúng thứ tự `DTMF_LyThuyet.m` L1077–1086, dừng ngay ở cái đầu tiên trượt**

| # | Điều kiện | Nhãn khi trượt |
|:--:|---|---|
| 1 | `10*log10(rowPeak/rowPeak2) >= peakDb` | `'level'` |
| 2 | `10*log10(colPeak/colPeak2) >= peakDb` | `'level'` |
| 3 | `10*log10(colPeak/rowPeak) ∈ [-twistBwdDb, twistFwdDb]` | `'twist'` |
| 4 | `sum(E(1:7)) >= energyRatio` ← quyết định (a) | `'level'` |
| 5 | `E(8) <= 0.5*min(rowPeak,colPeak)` ← quyết định (b) | `'harmonic'` |

**Việc cần làm**
- [ ] **Chốt chặn trước mọi `log10`**: `if ~all(isfinite(E)) || max(E) <= 0` → trả `0, 0, 0, 'level'`
- [ ] Cài 5 điều kiện theo đúng thứ tự bảng trên
- [ ] Cài `conf` theo công thức (c)
- [ ] `tests/test_decide.m` — 9 ca:
  - [ ] nhận: `[1 8 1 1 1 9 1 0.1]'` → `r=2, c=2, 'none'`, `conf>0`
  - [ ] level: `[5 5.5 1 1 1 9 1 0.1]'` → `'level'`, `r=c=0`, `conf==0`
  - [ ] twist thuận: `[1 8 1 1 1 90 1 0.1]'` → `'twist'`
  - [ ] twist nghịch: hàng mạnh gấp 10 lần cột → `'twist'`
  - [ ] harmonic: `[1 8 1 1 1 9 1 5]'` → `'harmonic'`
  - [ ] energy: `E` chuẩn hóa có `sum(E(1:7)) = 0.5` → `'level'`
  - [ ] suy biến: `zeros(8,1)`, `NaN`, `Inf` → không lỗi, không `NaN`, `reject ~= 'none'`
  - [ ] `0 <= conf <= 1` trên 1000 `E` ngẫu nhiên; `conf == 0` ⟺ bị loại
  - [ ] bất biến thang đo: `dtmf_decide(E)` và `dtmf_decide(1e6*E)` cho cùng `rowIdx/colIdx`

**Bẫy**
- Study §10.1 cảnh báo: khung toàn 0 cho `NaN`, mọi so sánh thành `false` → **ra đúng kết quả nhưng sai nhãn `reject`**, làm hỏng hình H4.3 ở Buổi 10 mà rất khó phát hiện.
- Ca "bất biến thang đo" không phải để bắt lỗi mà để **ghi lại tính chất**: điều kiện 4 là cái duy nhất phụ thuộc thang đo.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); [r,c,cf,rj]=dtmf_decide([1 8 1 1 1 9 1 0.1]'); fprintf('%d %d %.3f %s\n',r,c,cf,rj)"
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```
- [ ] In ra `2 2 <conf> none`
- [ ] `test_decide` xanh cả 9 ca

---

## ☐ Buổi 4 — `dtmf_decode_goertzel` · 2 giờ · 🎉 pipeline đầu tiên chạy thông

| | |
|---|---|
| **Mục tiêu** | Từ chuỗi phím → tín hiệu → giải mã lại đúng chuỗi ban đầu |
| **File sửa** | `src/decode/dtmf_decode_goertzel.m` |
| **File thêm** | `tests/test_decode_goertzel.m` · `tests/test_pipeline.m` |
| **Phụ thuộc** | Buổi 1, 3 |

**Việc cần làm**
- [ ] Chia khung `frameN=205, hop=205` bằng `dtmf_segment`
- [ ] Mỗi khung: `goertzel_power` tại 7 bin `[18 20 22 24 31 34 38]`
- [ ] Tính bin hài `k_harm = min(2*k_peak, floor(205/2))` → `E(8)`
- [ ] **Chuẩn hóa** `E(:,i) = E_raw / (frameN * sum(frame.^2) / 2)` theo (a); chặn `sum(frame.^2) == 0`
- [ ] Gọi `dtmf_decide` từng khung → `rowIdx/colIdx/conf/reject`
- [ ] **Debounce**: mã hóa run-length `keyIdx(i)` (0 = bị loại), mỗi dải liên tiếp khác 0 sinh **một** ký tự
- [ ] `tests/test_decode_goertzel.m`: sạch `'0912345'` đúng; `size(info.E)==[8 nFrame]`; `reject` là cellstr đủ `nFrame` phần tử; `tFrame` tăng ngặt; `conf ∈ [0,1]`; `zeros(1,4000)` → `''` và toàn `'level'`
- [ ] `tests/test_pipeline.m`: ca **`'12345699'` phải ra đủ 8 ký tự**

**Bẫy**
- Study §11 cảnh báo ở `hop = 205` khoảng lặng sau phím 7 **không có khung nào nằm trọn bên trong** → nguy cơ nuốt phím lặp. Khung xấu nhất ở đó vẫn 97.6% im lặng nên ngưỡng mặc định loại được — **nhưng phải test chứ không được tin**.
- Ca `'12345699'` là **test giá trị nhất cả bộ**; thiếu nó thì lỗi nuốt phím im lặng và phụ thuộc vị trí.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); [x,~,m]=dtmf_generate('0912345'); k=dtmf_decode_goertzel(x); fprintf('true=%s hat=%s\n',m.keys,k); assert(strcmp(k,m.keys)); disp('PIPELINE OK')"
```
- [ ] `true=0912345 hat=0912345`
- [ ] Ca `'12345699'` ra 8 ký tự

---

## ☐ Buổi 5 — `dtmf_decode_fft` · 1.5 giờ

| | |
|---|---|
| **Mục tiêu** | Bộ giải mã đối chứng, cho **cùng kết quả** với Goertzel |
| **File sửa** | `src/decode/dtmf_decode_fft.m` |
| **File thêm** | `tests/test_decode_fft.m` |
| **Phụ thuộc** | Buổi 4 |

**Việc cần làm**
- [ ] Dùng `hamming(256)` của toolbox (cửa sổ không phải nội dung được chấm)
- [ ] `frameN=256, hop=128`, bin `[22 25 27 30 39 43 47]`
- [ ] Dùng `|X[k]|^2` **chứ không phải** `|X[k]|` (TODO dòng 57 đã cảnh báo sẵn)
- [ ] Chuẩn hóa theo năng lượng **đã nhân cửa sổ**: `frameN * sum((w.*frame).^2) / 2`
- [ ] `tests/test_decode_fft.m`: sạch đúng; `info` cùng hợp đồng shape với Goertzel
- [ ] `tests/test_decode_fft.m`: **test tương đương liên phương pháp** — cùng tín hiệu sạch, FFT và Goertzel cho cùng `keysHat`

**Bẫy**
- Chuẩn hóa bằng năng lượng **chưa** nhân cửa sổ sẽ làm sai `energyRatio` do tổn hao coherent của Hamming → vách 8 dB dịch chỗ, 3 phương pháp lệch nhau.
- Test tương đương liên phương pháp mới là thứ **chứng minh** "3 bộ giải mã dùng chung luật quyết định" là thật chứ không phải khẩu hiệu.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```
- [ ] ~30 ca xanh
- [ ] Test FFT ≡ Goertzel xanh

---

## ☐ Buổi 6 — `design_bpf_bank` + `dtmf_decode_filterbank` · 2.5 giờ

| | |
|---|---|
| **Mục tiêu** | Ngân hàng 14 bộ lọc IIR cộng hưởng + bộ giải mã thứ ba |
| **File sửa** | `src/decode/design_bpf_bank.m` · `src/decode/dtmf_decode_filterbank.m` |
| **File thêm** | `scripts/make_coeffs.m` · `tests/test_filterbank.m` |
| **Sinh ra** | `data/mat/coeffs.mat` |
| **Phụ thuộc** | Buổi 4 |

**Việc cần làm**
- [ ] Lấy `boLoc` (study L1039) — **tự viết**, công thức `H(z) = G(1-z^-2)/(1 - 2r·cos(w0)z^-1 + r²z^-2)`
- [ ] Dùng `freqz(b, a, [f0], fs)` của toolbox để chuẩn hóa `G` sao cho `|H(f0)| = 1` (thay `dapUngTanSo` của study)
- [ ] `'withHarm' (1,1) logical = true` → trả `1×14` theo quyết định (b)
- [ ] Nhánh ưu tiên: `isfile(opt.coeffs)` thì nạp; không thì dựng bằng công thức
- [ ] `scripts/make_coeffs.m`: gọi `design_bpf_bank` rồi `save('data/mat/coeffs.mat','bank')`
- [ ] ⚠️ `dtmf_decode_filterbank`: **lọc toàn bộ tín hiệu MỘT LẦN rồi mới chia khung**
- [ ] Mỗi khung: `d = argmax E(1:7)`, gán `E(8,i) = E_harm(d,i)`; chuẩn hóa `E/sum(frame.^2)`
- [ ] `tests/test_filterbank.m`:
  - [ ] `|H(f0)| = 1` sai số `1e-10` cho cả 14 bộ (kiểm bằng `freqz`)
  - [ ] `max(abs(roots(a))) = 0.99` sai số `1e-12` (ổn định BIBO)
  - [ ] băng thông −3 dB lệch < 10% so với `(1-r)*fs/pi ≈ 25.5 Hz`
  - [ ] **test ghim quá độ**: lọc toàn bộ vs lọc từng khung lệch > 20% ở khung 2
  - [ ] `coeffs.mat` round-trip: nạp từ file ≡ dựng bằng công thức
  - [ ] sạch `'0912345'` đúng; khớp cả FFT và Goertzel

**Bẫy**
- **Lọc theo từng khung làm mất ~60% năng lượng từ khung 2 trở đi** (study §9 đo được) → mọi khung bị loại. Đây là cách viết *trực giác* nên rất dễ mắc. Test ghim quá độ tồn tại để sau không ai "tối ưu" ngược lại.
- `r = 0.99` là **cận trên**: 5τ = 62 ms < 100 ms tone. `r = 0.995` cần 124.7 ms → vỡ. Lập luận này viết được thẳng vào báo cáo.
- `filterDesigner` giờ đã có, nhưng **vẫn thiết kế bằng công thức**: hệ số do `filterDesigner` sinh ra là những con số không giải thích được, còn công thức cộng hưởng cho phép *dẫn giải* `r = 0.99` và `BW ≈ 25.5 Hz` trong báo cáo. Có thể mở `filterDesigner` để đối chiếu cho vui.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath('scripts'); make_coeffs; fprintf('coeffs.mat = %d bytes\n', dir('data/mat/coeffs.mat').bytes)"
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```
- [ ] `coeffs.mat` sinh ra, `data/mat/` hết rỗng
- [ ] `test_filterbank` xanh cả 6 nhóm ca

---

## ☐ Buổi 7 — `dtmf_metrics` · 1 giờ

| | |
|---|---|
| **Mục tiêu** | Đo độ chính xác, khoảng cách sửa, ma trận nhầm lẫn |
| **File sửa** | `src/util/dtmf_metrics.m` |
| **File thêm** | `tests/test_metrics.m` |
| **Phụ thuộc** | Buổi 4 |

**Việc cần làm**
- [ ] Lấy `levenshtein` (study L1049) — nó trả về **cả bảng quy hoạch động `D`**, đúng thứ cần để truy vết căn chỉnh khi tính `.acc` (TODO dòng 37 nói đúng điều này)
- [ ] `.acc` = số vị trí khớp / `max(numel(keysTrue), numel(keysHat))` sau khi truy vết `D`
- [ ] `.confusion` 12×12 theo thứ tự phím `'147*2580369#'`
- [ ] `tests/test_metrics.m`: chuỗi giống hệt → `acc==1, editDist==0, trace==numel`; `levenshtein('123','1283')==1` (ví dụ study L937); `keysHat` rỗng → `acc==0, editDist==numel(keysTrue)`; một phép thay → đúng ô `(i,j)`; `size==[12 12]`; khẳng định rõ thứ tự phím

**Bẫy**
- Help dòng 19 quy định duyệt `T.keys` **theo cột**. Sai chỗ này thì hình ma trận nhầm lẫn trong báo cáo bị **chuyển vị** — nhìn vẫn "có vẻ đúng" nên rất khó phát hiện.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); [x,~,m]=dtmf_generate('0912345'); for mm={'fft','goertzel','filterbank'}, f=str2func(['dtmf_decode_' mm{1}]); r=dtmf_metrics(m.keys,f(x)); fprintf('%-11s acc=%.3f\n',mm{1},r.acc); end"
```
- [ ] Cả 3 phương pháp `acc=1.000`

---

## ☐ Buổi 8 — `dtmf_run` + 3 hàm `ui_plot_*` · 2 giờ

| | |
|---|---|
| **Mục tiêu** | Tầng cầu nối UI↔src và 3 hàm vẽ, test được headless |
| **File sửa** | `app/dtmf_run.m` · `app/ui/ui_plot_wave.m` · `ui_plot_spec.m` · `ui_plot_bars.m` · `ui_refresh.m` |
| **File thêm** | `tests/test_run.m` · `tests/test_ui_smoke.m` |
| **Phụ thuộc** | Buổi 7 |

**Việc cần làm**
- [ ] `dtmf_run`: switch theo `S.method`, bọc `try/catch` ghi `S.lastError`
- [ ] `dtmf_run`: nhánh `otherwise` → `S.lastError = sprintf('method không hợp lệ: %s', S.method)`, **không ném lỗi**
- [ ] `dtmf_run`: tính luôn `S.thr` và `S.iSel = argmax(info.conf)` — vì `ui_refresh` đọc hai giá trị này mà **tầng UI không được phép tính toán**
- [ ] `ui_plot_wave`: dạng sóng + vùng tone + nhãn phím; phải chịu được `meta = []`
- [ ] `ui_plot_spec`: theo đúng TODO gốc — `spectrogram(y, hamming(256), 128, 256, fs)` → `imagesc` trên uiaxes → `axis xy` → `ylim [0 3000]`
- [ ] `ui_plot_bars`: `bar(ax, categorical(labels), E)` + `yline(ax, thr, 'r--')`
- [ ] `ui_refresh`: gọi 3 hàm vẽ, set `LblDecoded`, nối lỗi vào `TxtLog`, bọc `try/catch`
- [ ] `tests/test_run.m`: 3 phương pháp đều dispatch được; method sai → `lastError` khác rỗng và **không throw**
- [ ] `tests/test_ui_smoke.m`: `uifigure('Visible','off')` → gọi 3 hàm vẽ → `verifyNotEmpty(ax.Children)`; thêm ca `meta = []`

**Bẫy**
- Tham số `spectrogram` phải **khớp đúng** `dtmf_decode_fft`: cửa sổ Hamming 256, `noverlap = 128` (tức hop = 128). Lệch tham số thì hình phổ không còn là cái bộ giải mã nhìn thấy — khi vấn đáp bị hỏi là không trả lời được.
- `ui_plot_bars` là "hình quan trọng nhất của buổi demo" theo `docs/ui_naming.md` — đầu tư cho đẹp.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"
```
- [ ] Toàn bộ test xanh
- [ ] **Không có cửa sổ figure nào bật lên** (chứng tỏ headless đúng)

---

## ☐ Buổi 9 — Giao diện `DTMFApp` · 3 giờ · 🖥️

| | |
|---|---|
| **Mục tiêu** | Bàn phím điện thoại, phát tiếng, hiện chuỗi giải mã — 70% điểm GHP |
| **File thêm** | `app/DTMFApp.m` · `app/ui/ui_play.m` · `tests/test_app_smoke.m` |
| **Phụ thuộc** | Buổi 8 |

**Vấn đề `.mlapp`:** đó là file ZIP chứa XML — **không có cách sinh bằng code**, không diff được, không merge được, không test tự động được.

| Phương án | Công | Diff/review | Test `-batch` |
|---|---|---|---|
| A. Vẽ tay trong App Designer | 2–4 h, **cần người ngồi bấm** | ✗ (đã `binary` trong `.gitattributes`) | ✗ |
| **B. `app/DTMFApp.m` dạng `classdef` dựng `uifigure`** | **2–3 h, script hóa được** | **✓ text thuần** | **✓ (P2 đã chứng minh)** |
| C. Làm B trước, A sau như lượt làm đẹp | B + 1.5 h | Một phần | ✓ với B |

**Khuyến nghị: phương án B.** Lý do cụ thể: `ui_refresh.m` **không quan tâm** app tạo bằng cách nào — nó chỉ đụng `app.AxWave`, `app.AxSpec`, `app.AxBars`, `app.TxtLog`, `app.LblDecoded`, `app.S`. Một `classdef DTMFApp < handle` có đúng 5 property đó thỏa mãn `ui_refresh` **y hệt** class do App Designer sinh. Tên "đóng băng" trong `docs/ui_naming.md` vẫn được tôn trọng nguyên vẹn. Và B là phương án **duy nhất** bảo vệ được bằng `run_all_tests`.

**Việc cần làm**
- [ ] `classdef DTMFApp < handle`, constructor nhận `visible` (`'off'` cho test)
- [ ] Property: `UIFigure, PnlKeypad, Btn1..Btn9, Btn0, BtnStar, BtnHash, AxWave, AxSpec, AxBars, DdMethod, SldSNR, EfKeys, BtnGen, BtnDecode, BtnPlay, LblDecoded, TxtLog, S`
- [ ] 12 nút keypad dùng **chung một callback** `Btn1Pushed` đọc `event.Source.Text`
- [ ] `DdMethod.ItemsData = {'fft','goertzel','filterbank'}`
- [ ] `SldSNR.Limits = [-5 30]`, dùng `ValueChanged` (**không** `ValueChanging`)
- [ ] `TxtLog.Editable = 'off'`, `Value` kiểu cell
- [ ] Mỗi callback **≤ 3 dòng**: đọc UI → `dtmf_run` → `ui_refresh`
- [ ] `app/ui/ui_play.m` gọi `sound()`, bọc `if usejava('jvm')` để test headless không treo
- [ ] `tests/test_app_smoke.m`: dựng `DTMFApp('off')` → `EfKeys.Value='0912345'` → `BtnGenPushed` → lặp 3 phương pháp → `BtnDecodePushed` → `verifyEqual(app.LblDecoded.Text,'0912345')`, `verifyEmpty(app.S.lastError)`

**Bẫy**
- `CONTRACTS.md` dòng 31 cho phép âm thanh trong `app/ui/*.m` — nên đặt `sound()` trong `ui_play.m` chứ **không viết thẳng trong callback**.
- Không đặt bất kỳ phép tính DSP nào trong callback; sai luật kiến trúc là mất điểm khi chấm code.

**Kiểm chứng**
```bash
# headless
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath(genpath('app')); a=DTMFApp('off'); a.EfKeys.Value='0912345'; a.BtnGenPushed([],[]); a.DdMethod.Value='goertzel'; a.BtnDecodePushed([],[]); fprintf('Decoded=%s err=[%s]\n',a.LblDecoded.Text,a.S.lastError); delete(a.UIFigure)"
# mắt người nhìn — bấm phím, nghe tiếng, kéo SNR
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath(genpath('app')); DTMFApp('on'); uiwait"
```
- [ ] Headless in `Decoded=0912345 err=[]`
- [ ] Mở thật: bấm 12 phím đều kêu; kéo SNR ≥ 10 dB giải mã đúng; đổi 3 phương pháp đều chạy

> Nếu khoa bắt buộc nộp đúng file `.mlapp`: mở App Designer **một lần**, kéo thả component đặt tên theo `docs/ui_naming.md`, dán 6 thân callback từ `DTMFApp.m`. 1.5 h, và làm **sau Buổi 10** — vì ảnh chụp giao diện cho báo cáo lấy từ phương án B bằng `exportgraphics` là đủ.

---

## ☐ Buổi 10 — Thực nghiệm + hình vẽ · 2 giờ

| | |
|---|---|
| **Mục tiêu** | Số liệu so sánh 3 phương pháp + 8 hình cho báo cáo |
| **File thêm** | `scripts/run_bench.m` · `scripts/make_figures.m` · `scripts/publish_figures.m` |
| **Sinh ra** | `results/bench.mat` · `results/figures/*.pdf\|png` |
| **Phụ thuộc** | Buổi 9 |

**Việc cần làm**
- [ ] `run_bench.m`: 3 phương pháp × SNR `-5:2.5:30` × {awgn, hum50} × 20 chuỗi 12 phím, `rng(2026)` cố định
- [ ] `run_bench.m`: gom `acc`, `editDist`, `confusion`, **histogram lý do loại khung**, `tic/toc` mỗi khung
- [ ] `run_bench.m`: quét thêm `energyRatio ∈ {0.70, 0.40, 0}` (xử lý rủi ro R2)
- [ ] `run_bench.m`: **không vẽ gì**, chỉ `save('results/bench.mat','B')` — ước tính 2–4 phút chạy
- [ ] `make_figures.m`: nạp `bench.mat`, dựng `uifigure` ẩn rồi **giao việc vẽ cho chính `app/ui/ui_plot_*`**, sau đó `exportgraphics(..., 'ContentType','vector')`
- [ ] `publish_figures.m`: `copyfile('results/figures/H*.pdf','report/template/Figures/')` — **một chiều, không bao giờ sửa tay bên đích**

**8 hình sinh bằng MATLAB**

| Mã | Nội dung | Nguồn | ☐ |
|---|---|---|:--:|
| H2.1 | Phổ FFT phím "5" + 8 bin | `ui_plot_spec` | ☐ |
| H2.3 | Giản đồ cực–không 8 bộ lọc | `zplane(b, a)` của toolbox | ☐ |
| H2.4 | Biểu đồ 8 cột + ngưỡng | `ui_plot_bars` — *"hình quan trọng nhất buổi demo"* | ☐ |
| H3.3 | Ảnh chụp giao diện | `exportgraphics(app.UIFigure,...)` | ☐ |
| H4.1 | Độ chính xác theo SNR, 3 phương pháp | `bench.mat` | ☐ |
| H4.2 | Heatmap ma trận nhầm lẫn | `bench.mat` | ☐ |
| H4.3 | Histogram lý do loại khung theo SNR | `bench.mat` — vách 8 dB thành **phát hiện** | ☐ |
| H4.4 | Thời gian chạy vs số phép nhân lý thuyết | `bench.mat` + study §8.5 | ☐ |

**4 hình vẽ tay** (TikZ/draw.io, không sinh bằng MATLAB — làm song song bất cứ lúc nào): H1.1 chồng phổ · H2.2 sơ đồ khối Goertzel · H3.1 kiến trúc phần mềm · H3.2 lưu đồ một lần bấm phím.

**Kiểm chứng**
```bash
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath(genpath('app')); addpath('scripts'); run_bench; make_figures; fprintf('%d hinh\n', numel(dir('results/figures/*.pdf'))); assert(numel(dir('results/figures/*.pdf'))>=8)"
```
- [ ] ≥ 8 file trong `results/figures/`
- [ ] H4.1 cho thấy Goertzel ≈ FFT ≈ filterbank ở SNR cao

---

# KIỂM CHỨNG TỔNG THỂ (chạy trước khi nộp)

```bash
MLB='C:\Program Files\MATLAB\R2026a\bin\matlab.exe'

# 1. Toàn bộ test xanh (~60 ca sau Buổi 9)
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath('tests'); run_all_tests"

# 2. Pipeline đầu-cuối, 3 phương pháp, có nhiễu
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); [x,~,m]=dtmf_generate('0912345*#'); y=dtmf_addnoise(x,'snrDb',15); for mm={'fft','goertzel','filterbank'}, f=str2func(['dtmf_decode_' mm{1}]); k=f(y); r=dtmf_metrics(m.keys,k); fprintf('%-11s hat=%-12s acc=%.3f\n',mm{1},k,r.acc); end"

# 3. GUI headless
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath(genpath('app')); a=DTMFApp('off'); a.EfKeys.Value='0912345'; a.BtnGenPushed([],[]); a.BtnDecodePushed([],[]); fprintf('Decoded=%s err=[%s]\n',a.LblDecoded.Text,a.S.lastError); delete(a.UIFigure)"

# 4. Sinh đủ hình
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath(genpath('app')); addpath('scripts'); run_bench; make_figures; assert(numel(dir('results/figures/*.pdf'))>=8)"

# 5. GUI thật — mắt người nhìn
"$MLB" -batch "cd('D:\PROJECT\DMTF'); addpath(genpath('src')); addpath(genpath('app')); DTMFApp('on'); uiwait"
```

---

# BẢNG RỦI RO

| # | Rủi ro | Khả năng | Xử lý | Buổi |
|:--:|---|:--:|---|:--:|
| R1 | Lỡ tay gọi `goertzel()` / `filterDesigner` cho phần lõi vì giờ đã có sẵn → **mất điểm đúng chỗ được chấm nhiều nhất** | Trung bình | Bám bảng phân chia ở P1; `goertzel()` chỉ được xuất hiện trong `tests/test_goertzel.m` | 2, 6 |
| R1b | `awgn` không có (Communications Toolbox chưa cài) | Chắc chắn (đã đo) | Dùng công thức tay trong help `dtmf_addnoise` dòng 25–26 — chính xác và tái lập hơn `awgn` | 1 |
| R2 | Vách chính xác ở SNR ≈ 8 dB do `energyRatio = 0.70` | Cao | Quét `{0.70, 0.40, 0}` trong `run_bench`; trình bày như kết quả có chủ đích (chống talk-off); **demo ở SNR ≥ 10 dB** | 10 |
| R3 | Debounce nuốt phím lặp ở khoảng lặng thứ 7 | Thấp | Ca `'12345699'`. Nếu xảy ra: đổi `hop = 102` — `CONTRACTS.md` khóa `N = 205` nhưng **không khóa hop** | 4 |
| R4 | `.mlapp` không merge/test được | Chắc chắn | Phương án B (`DTMFApp.m`); A chỉ làm sau, một lượt, nếu bắt buộc | 9 |
| R5 | `10*log10(0/0)` → `NaN`, ra đúng kết quả nhưng **sai nhãn `reject`** → hỏng hình H4.3 | Cao nếu không chặn | Chặn `isfinite`/`max(E)<=0` trước mọi `log10` | 3 |
| R6 | Filter bank lọc từng khung → mất 60% năng lượng từ khung 2 | Trung bình (là cách viết trực giác) | Test ghim quá độ | 6 |
| R7 | Hỏng dấu tiếng Việt — PowerShell `>` và `Set-Content` mặc định ANSI/UTF-16 | Trung bình | **Không bao giờ ghi file `.m` bằng redirect shell**; thêm `working-tree-encoding=UTF-8` | 0 |
| R8 | Khối help bị bào mòn (**đã xảy ra** với `dtmf_table.m`) | Cao | Revert; thêm `tests/test_help_blocks.m` duyệt `src/**/*.m` khẳng định mỗi `help` có dòng H1 `%TEN_HAM ` và `See also` — biến quy ước thành thứ máy kiểm được | 0 |

---

# NGOÀI PHẠM VI (ghi lại để không quên)

- **Báo cáo LaTeX**: `report/template/main.tex` còn **28 chỗ `[Nội dung viết tại đây.]`** và 8 `\chohinh{}`. Hình từ Buổi 10 là đầu vào. Bốn đoạn lập luận khó nhất đã có sẵn trong `DTMF_LyThuyet.m` L987–1005 ("Bốn lập luận đáng viết vào báo cáo").
- **Slide + thuyết trình** (30% điểm GHP).
- `report/template/README.md` nhắc tới `main_mau.pdf` (bản mẫu 22 trang) — **file này không có trong repo**, hỏi lại Lâm/Khương nếu cần.
