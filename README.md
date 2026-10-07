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

DTMFApp          % giao diện ba bước: Tạo tín hiệu x[n] -> Cộng nhiễu y[n] -> Giải mã,
                 % mỗi bước kèm dạng sóng và phổ; nguồn Micro thì bước 1 là thu âm.
                 % Bước 1 còn nút "Mở tệp âm thanh…": tệp wav/flac/mp3 bất kỳ thành x[n].
run_all_tests    % 249 ca
```

Sinh lại số liệu và các hình số liệu cho báo cáo (khoảng một phút):

```matlab
addpath('scripts');
run_bench        % -> results/bench.mat, không vẽ gì
make_figures     % -> results/figures/H*.png (300 dpi) + H*.pdf (vector)
publish_figures  % -> report/template/Figures/, chép một chiều
```

`results/` không nằm trong git vì dựng lại được; bản đi vào git là bản đã công bố ở
`report/template/Figures/`. Ảnh chụp màn hình (H3_3, H3_4, H3_5), sơ đồ `SD_*` (draw.io) và ảnh bìa
(`scripts/make_cover.m`) làm riêng, không nằm trong `make_figures`.

## Trình diễn chính: giám định đoạn ghi âm

Thầy nhập một **số điện thoại bí mật** trên trang web. Trang dựng một đoạn ghi âm có người bấm số
đó giữa tiếng ồn, phát ra loa và gửi đúng các mẫu đó sang MATLAB. MATLAB chỉ nhận âm thanh. Nó đọc
dần từng chữ số, kết luận khi hết đoạn ghi âm, và chỉ sau đó trang mới cho công bố số thật để đối
chiếu. Không ai biết trước đáp án, nên khán giả thấy rõ MATLAB phải nghe mới ra số.

```
máy của thầy                          máy trình chiếu
trang #giam-dinh --WebSocket qua LAN--> cầu nối (npm run dev:lan) --TCP 127.0.0.1:8765--> DTMFForensic
                 <------------------------- key, verdict ------------------------------
```

- **Trang** (`web/src/forensic/`) chỉ cần nhập số bí mật và kéo thanh *Độ khó* qua bốn mức dựng
  sẵn. Mỗi mức đặt sẵn nhịp bấm, tiếng người nói (giọng tổng hợp có thanh điệu) và nhiễu đường
  truyền, dưới thanh ghi rõ ba thông số đó. *Phòng yên tĩnh* và *Quán cà phê* gần như luôn đọc đúng,
  *Ngoài đường* đúng khoảng một nửa, *Cực khó* hiếm khi đúng (CONTRACTS §7.11).
- **MATLAB** (`DTMFForensic`) là màn chiếu. Bên trái là số đọc được, bảng ba bộ giải mã kèm thời gian
  xử lý, rồi phần đối chiếu tô xanh, đỏ từng chữ số. Bên phải là cả đoạn ghi âm và bản đồ 8 bin,
  trên bản đồ có hai làn *k̂* (số đọc được) và *k* (số thật) để thấy chữ số nào sai, sai ở đâu.

1. Máy trình chiếu: `cd web`, `npm run dev:lan`. Lần đầu Windows hỏi tường lửa cho Node.js thì cho
   phép mạng *Private*. Vite in ra địa chỉ *Network*, ví dụ `http://192.168.1.20:5173/`.
2. Máy trình chiếu, trong MATLAB: `dtmf_setup` rồi `DTMFForensic`. Dòng *● Đã nối* hiện màu xanh.
3. Máy của thầy (cùng mạng Wi-Fi): mở `http://<địa chỉ Network>:5173/#giam-dinh`, hoặc mở trang
   chính rồi bấm *Giám định* ở công tắc góc phải trên. Huy hiệu trên cùng báo *MATLAB đang nghe*.
4. Thầy nhập số (hoặc bấm *Ngẫu nhiên*), chọn độ khó, bấm **Gửi cho MATLAB**. Hết đoạn ghi âm,
   bấm **Công bố số thật**.

Không có mạng thì mở trang ngay trên máy trình chiếu (`http://localhost:5173/#giam-dinh`). Nguồn
**Micro** của `DTMFForensic` cho MATLAB tự nghe bằng micro: tiếng loa của trang (tin bắt đầu, kết
thúc, đáp án vẫn đi qua đường dây), hoặc một điện thoại thật mà thầy bấm số. Khi đó dùng nút *Bắt
đầu nghe*, *Kết luận* và ô *Số thật* trên màn MATLAB.

## Trình diễn phụ: gọi từ trang web, MATLAB làm tổng đài

Thư mục `web/` là **chiếc điện thoại** trong buổi trình diễn. Bên trái là màn hình cuộc gọi kiểu
iPhone tới tổng đài Học viện An ninh nhân dân (số mô phỏng): gọi từ thẻ danh bạ, đọc lời chào và câu
"Tổng đài nhận được phím ..." ở ô phụ đề trực tiếp (giọng đọc sẽ thu âm sau, kịch bản ở
`docs/kich_ban_thu_am_tong_dai.docx`), mở bàn phím để bấm; mỗi phím phát đúng cặp tone ITU-T
Q.23 (dốc 5 ms hai đầu) ra loa. Bên phải là **tín hiệu của phím vừa bấm trong miền thời gian và
miền tần số**, vẽ như ba hình của một bài báo: (a) bảng tần số chọn một hàng và một cột, (b) hai
sóng sin và tổng x(t), (c) phổ biên độ (cửa sổ Hamming) có đúng hai đỉnh tại hai tần số đó. Phần nội
dung dùng font STIX Two, kiểu chữ của LaTeX.

`DTMFLive` là **tổng đài** ở đầu kia. Bấm gọi trên trang thì MATLAB đổ chuông, 1,5 s sau tự nhấc
máy, rồi đọc từng phím bằng chính `dtmf_listen` và hiện ngay: bàn phím sáng phím vừa nghe (kèm
tần số hàng và cột của nó), dãy số đã đọc, dạng sóng 3 s gần nhất, 32 ms
cuối, bản đồ 8 bin theo khung, và 8 thanh của khung mới nhất kèm lý do nhận hay loại. MATLAB gửi
phím đọc được về điện thoại, và tổng đài trên trang **chỉ đọc lại phím MATLAB nghe được**: bấm
mà MATLAB không nghe ra thì tổng đài im lặng. Trang không giải mã gì.

```
trang web --WebSocket /line--> cầu nối (trong npm run dev) --TCP 127.0.0.1:8765--> DTMFLine --> dtmf_listen --> DTMFLive
          <------------------------------ answer, key, hangup ------------------------------
```

Trang gửi đúng các mẫu nó phát ra loa, hạ về 8 kHz, chứ không gửi tên phím. Đường dây thay cho vòng
loa → micro vì trên cùng một laptop vòng đó không đáng tin (CONTRACTS §7.9). Cầu nối nằm trong máy
chủ Vite vì trình duyệt không mở được cổng TCP, còn MATLAB gốc chỉ có `tcpclient` (`tcpserver` thuộc
Instrument Control Toolbox).

1. `cd web`, `npm run dev`, mở http://localhost:5173.
2. Trong MATLAB: `dtmf_setup` rồi `DTMFLive`. Thẻ bên trái báo *● Đã nối*; trên trang, chip ở ô phụ
   đề ghi *MATLAB* khi gọi đi qua đường dây.
3. Bấm gọi, mở bàn phím, bấm số bằng chuột hoặc bằng phím 0-9, `*`, `#` của máy tính.

Mở MATLAB trước `npm run dev` thì bấm **Nối đường dây**. Không có MATLAB, trang vẫn gọi được và tổng
đài chạy ngay trong trang; huy hiệu ở ô phụ đề ghi *trong trang* thay cho *MATLAB*. Nguồn **Micro**
của `DTMFLive` (hoặc chế độ Giải mã trực tiếp của `DTMFApp`) dùng khi bấm số trên một điện thoại
thật đặt cách micro 5-10 cm; MATLAB báo `twist` thì tăng *Bù loa nhóm hàng* trên trang.

```bash
cd web
npm install
npm run dev              # trang + cầu nối đường dây sang MATLAB
npm run dev:lan          # như trên, mở cho máy khác trong mạng LAN (màn giám định)
npm test                 # vitest: bảng tần số, WAV, phổ, Goertzel, luật quyết định, gộp khung, tổng đài,
                         #         đường dây, hiện trường giám định, đối chiếu chữ số
npm run build            # dist/index.html - một tệp, mở offline được, có nút Tải WAV 8 kHz, không có đường dây
npm run build:artifact   # dist-artifact/ban-phim-dtmf.html - bản phát hành, không có nút tải
```

Tệp WAV tải từ trang đọc lại được bằng `audioread` và giải mã đúng bằng cả ba phương pháp (đã thử
`0123456789*#`, có và không bù loa 6 dB).

## Cấu trúc

```
src/gen/      dtmf_table, dtmf_generate, dtmf_addnoise
src/decode/   FFT, Goertzel, ngân hàng bộ lọc
src/util/     chia khung, luật quyết định, gộp phím, đánh giá
app/          DTMFApp (giao diện) · DTMFForensic (giám định ghi âm) · DTMFLive (tổng đài trực tiếp)
              · DTMFLine (đầu đường dây)
              · dtmf_run, dtmf_listen, dtmf_judge, dtmf_readaudio (lớp trung gian: khối, luồng,
                đối chiếu, đọc tệp âm thanh)
              · ui/ (dạng sóng, phổ Welch, bản đồ khung, thanh quyết định, màn trực tiếp, phát tiếng, micro)
tests/        unit test (matlab.unittest)
scripts/      dev_harness · make_coeffs · run_bench · make_figures · publish_figures · make_cover
data/         wav/, mat/ — coeffs.mat sinh tại chỗ, không nằm trong git
results/      bench.mat + figures/ — máy sinh ra, không nằm trong git
docs/         đề cương, kịch bản thu âm tổng đài, ghi chú học (study/) — báo cáo ở report/, slide ở slides/
web/          điện thoại gọi tổng đài và minh họa phím thành phổ, trên trình duyệt (React + Vite)
              · src/forensic/: màn giám định (#giam-dinh), dựng đoạn ghi âm hiện trường
              · server/line.ts: cầu nối đường dây sang MATLAB, chạy trong npm run dev
```

## Yêu cầu

- MATLAB **R2025a** trở lên (đang phát triển trên R2026a; `DTMFApp` đặt `Theme` của `uifigure`, hình số liệu dùng `theme`) và **Signal Processing Toolbox**.
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
- Micro mở bằng `audiorecorder` của MATLAB gốc (không cần Audio Toolbox). Chế độ nghe trực
  tiếp đưa từng đoạn 50 ms qua `dtmf_listen`, hàm này gọi lại đúng bộ giải mã khối nên luồng
  và khối cho cùng kết quả (`tests/test_listen.m`); phím hiện ra 40–90 ms sau lúc âm bắt đầu
  (độ trễ thuật toán), 44–134 ms khi tính cả chu kỳ đọc micro 50 ms.
- Làm việc trực tiếp trên nhánh `main`; chỉ commit khi `run_all_tests` pass hết.

## Tài liệu

- [CONTRACTS.md](CONTRACTS.md) — chữ ký hàm, thông số đã chốt, quy ước chú thích, số liệu đo.
- [docs/study/KE_HOACH.md](docs/study/KE_HOACH.md) — kế hoạch triển khai ban đầu (lưu trữ, dừng cập nhật từ 23/09/2026).
- [docs/ui_naming.md](docs/ui_naming.md) — quy ước tên component của giao diện.
