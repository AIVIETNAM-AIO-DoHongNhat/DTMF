# Quy ước tên component - DTMFApp

> Giao diện là `app/DTMFApp.m` dạng `classdef`, **không** phải `.mlapp` — xem `CONTRACTS.md` §8.

> Sáu trục `AxWaveX`, `AxPsdX`, `AxWave`, `AxPsd`, `AxMap`, `AxBars` cùng `TxtLog`, `LblDecoded` bị `app/ui/ui_refresh.m` gọi thẳng - **không đổi tên**.

## 1. Cách đặt tên

`<Tiền tố><Ý nghĩa>` - tiền tố theo bảng dưới, phần sau viết PascalCase: `BtnDecode`, `DdMethod`, `SldSNR`.

- Tên biến thuần **ASCII**; tiếng Việt có dấu chỉ nằm ở `Text` / `Items` / `Title`.
- Viết tắt giữ nguyên chữ hoa: `SldSNR`, không phải `SldSnr`.
- Cấm để tên mặc định của App Designer (`Button2`, `UIAxes3`, `Slider`).

| Tiền tố | Loại | Tiền tố | Loại |
|---|---|---|---|
| `Btn` | Button | `Ef` | EditField |
| `Ax` | UIAxes | `Sp` | Spinner |
| `Dd` | DropDown | `Cb` | CheckBox |
| `Sld` | Slider | `Lbl` | Label (hiển thị kết quả) |
| `Txt` | TextArea | `Pnl` | Panel |
| `Lnk` | Hyperlink | | |

Label chú thích tĩnh (kiểu "SNR") không cần đặt tên.

## 2. Bố cục và danh sách component

Ba thẻ bước xếp dọc theo đúng đường tín hiệu đi. Mỗi thẻ gồm cột điều khiển bên trái và hai trục bên phải - miền thời gian rồi miền tần số - của **đúng** tín hiệu ở bước đó:

| Thẻ | Điều khiển | Trục thời gian | Trục tần số |
|---|---|---|---|
| Bước 1 · Tín hiệu gốc x[n] | `PnlKeypad` (tổng hợp) **hoặc** `PnlMic` (micro), chồng lên nhau ở cùng một ô lưới | `AxWaveX` | `AxPsdX` |
| Bước 2 · Kênh nhiễu y[n] = x[n] + v[n] | `DdNoise`, `SldSNR` + `LblSNR`, `BtnNoise`, `BtnPlay` | `AxWave` | `AxPsd` |
| Bước 3 · Giải mã | `DdMethod`, `BtnDecode`, `LblSent`, `LblDecoded` | `AxMap` | `AxBars` |

Trên cùng là dòng tiêu đề với hai nút nguồn `BtnSrcGen` / `BtnSrcMic`; dưới cùng là thanh trạng thái `LblStatus` + `TxtLog`.

Ba thẻ dùng chung một cách chia cột, nên `AxWaveX`, `AxWave`, `AxMap` thẳng mép nhau và cùng `XLim`: một thời điểm ở hàng trên nằm đúng trên thời điểm đó ở hàng dưới.

Phong cách trang LaTeX (`M.tex` trong `ui_theme`): nền giấy trắng, chữ Times New Roman như báo cáo, đường kẻ đậm dưới tiêu đề, ba bước là ba mục đánh số như `\section` ngăn bằng vạch mảnh. Số mục tô màu nhấn khi bước đó đã có kết quả. Trục kiểu pgfplots (khung kín, tick vào trong, không lưới, số và nhãn trục qua bộ diễn dịch `latex`), tiêu đề trục đánh số "Hình k:". Chú thích dài nằm trong `Tooltip`.

Luật bước tiếp theo (`buocTiep`, `capNhatNut`): nút của bước cần bấm **tiếp theo** nền gần đen chữ trắng đậm, và vạch 2 px kiểu changebar ở mép trái mục của bước đó tô màu nhấn; nút khác nền trắng; nút chưa dùng được bị khóa. Nguồn tổng hợp:

- chưa có x, hoặc chuỗi phím đã sửa sau lần tạo → `BtnGen`
- có x, chưa cộng nhiễu → `BtnNoise`
- có y, chưa giải mã → `BtnDecode`
- đã giải mã → không nút nào

Test đọc dấu hiệu này qua `FontWeight`.

**Bàn phím** - thứ người dùng thấy và bấm là `AxKeypad`, một bàn phím phẳng vẽ bằng `app/ui/ui_pad.m` (dùng chung với `DTMFLive`): bấm một phím thì `AxKeypadClicked` gọi `Btn1Pushed` với đúng nút bên dưới, phím đó và hai tần số của nó sáng lên trong 0,25 s. 12 nút vẫn tồn tại (ẩn) để giữ tên và đường đi của callback:

| | 1209 | 1336 | 1477 |
|---|:---:|:---:|:---:|
| **697** | `Btn1` | `Btn2` | `Btn3` |
| **770** | `Btn4` | `Btn5` | `Btn6` |
| **852** | `Btn7` | `Btn8` | `Btn9` |
| **941** | `BtnStar` | `Btn0` | `BtnHash` |

`*` và `#` không hợp lệ trong tên biến MATLAB nên viết chữ; `Text` của nút vẫn là `*` và `#`.

**Trục vẽ:**

| Tên | Hàm vẽ | Nội dung |
|---|---|---|
| `AxWaveX` | `ui_plot_wave` | Dạng sóng x[n] + vùng tone + nhãn phím |
| `AxPsdX` | `ui_plot_psd` | Phổ công suất Welch của x[n] (Hamming 256, chồng 128), 0-2000 Hz |
| `AxWave` | `ui_plot_wave` | Dạng sóng y[n], cùng thang biên độ với `AxWaveX` |
| `AxPsd` | `ui_plot_psd` | Phổ của y[n], nét xám là phổ x[n]; cùng thang dB với `AxPsdX` |
| `AxMap` | `ui_plot_map` | Năng lượng 8 bin `info.E` theo khung, chấm hai bin được chọn, nhãn phím mỗi dải, đường đứt tại khung `iSel` |
| `AxBars` | `ui_plot_bars` | 8 thanh công suất của khung `iSel` + ngưỡng hài |

**Điều khiển:**

| Tên | Loại | Ghi chú |
|---|---|---|
| `EfKeys` | EditField | Chuỗi phím cần tạo |
| `BtnClear` | Button | Xóa trắng `EfKeys`, không đụng tín hiệu đang có |
| `BtnGen` | Button | "Tạo tín hiệu": dựng x[n] và `meta` từ `EfKeys`; xóa y và kết quả cũ |
| `BtnPlayX` | Button | "Nghe" ở bước 1: phát x[n], chưa có nhiễu |
| `BtnOpen` | Button | "Mở tệp âm thanh…" ở bước 1: chọn tệp, nạp làm x[n] qua `napTep` / `dtmf_readaudio` |
| `DdNoise` | DropDown | `ItemsData = {'awgn','hum50'}` → `Value` khớp sẵn `S.noise` |
| `SldSNR` | Slider | `Limits = [-5 30]`, đơn vị dB, áp dụng ở `ValueChanged` (thả chuột) |
| `BtnNoise` | Button | "Cộng nhiễu": y[n] = x[n] + v[n] qua `dtmf_addnoise` |
| `BtnPlay` | Button | "Nghe" ở bước 2: phát `S.y` qua `app/ui/ui_play.m` - tín hiệu **đã cộng nhiễu**, hoặc bản ghi micro, tức đúng cái bộ giải mã nghe |
| `DdMethod` | DropDown | `ItemsData = {'fft','goertzel','filterbank'}` → `Value` khớp sẵn `S.method` |
| `BtnDecode` | Button | "Giải mã": `dtmf_run` trên `S.y` |
| `BtnSrcGen` / `BtnSrcMic` | Button | Chọn nguồn; dùng chung callback `BtnSrcPushed`. Đổi nguồn thì xóa kết quả của nguồn cũ, giữ `EfKeys` |
| `BtnListen` | Button | "Giải mã trực tiếp", trong `PnlMic`. Bấm: nghe micro liên tục, mỗi 50 ms đưa phần mẫu mới qua `app/dtmf_listen.m`, phím hiện ngay khi nhận ra. Bấm lần nữa: dừng |
| `BtnRecord` | Button | "Ghi âm rồi giải mã", trong `PnlMic`. Bấm: ghi âm micro (tối đa 20 s). Bấm lần nữa: dừng, lấy bản ghi làm `S.y` rồi giải mã qua `dtmf_run` |

**Đổi tham số của một bước đã làm** thì chạy lại bước đó và mọi bước đã làm sau nó; bước chưa làm thì chỉ ghi nhận tham số:

- `SldSNR`, `DdNoise` đổi khi đã có y → cộng lại nhiễu vào **cùng** x; nếu đã giải mã thì giải mã lại.
- `DdMethod` đổi khi đã giải mã → giải mã lại ngay.

**Nguồn micro:** bước 1 là thu âm (`PnlMic`); bản ghi chính là y[n], vẽ ở hàng bước 2; hàng bước 1 trống vì không có x[n]. Bước 2 khóa hẳn (`DdNoise`, `SldSNR`, `BtnNoise`) vì bản ghi đã mang nhiễu thật. Đang dùng micro thì hai nút nguồn, hai nút Nghe và nút micro còn lại bị khóa; nút micro đang chạy đổi chữ thành "Dừng…" và nền màu nhấn.
Chạy ẩn (`DTMFApp('off')`) thì **không** mở micro: test đưa âm thanh vào qua hai method công khai `nhanMauMic(chunk)` và `napBanGhi(y)`.

**Hiển thị:**

| Tên | Loại | Nội dung |
|---|---|---|
| `LblSent` | Label | Chuỗi đã phát (`S.meta.keys`), đặt ngay trên `LblDecoded` để so từng cột ký tự; do `capNhatKetQua` ghi |
| `LblDecoded` | Label | Chuỗi phím giải mã (`S.keysHat`); `ui_refresh` tô xanh khi khớp `S.meta.keys`, đỏ khi lệch |
| `LblStatus` | Label | Thanh trạng thái: bước cần làm tiếp, hoặc khớp k/k phím / lệch kèm bộ giải mã, loại nhiễu, SNR; do `capNhatKetQua` ghi |
| `LblSNR` | Label | Giá trị SNR đang chọn, cập nhật ngay trong lúc kéo (`SldSNRValueChanging`) |
| `TxtLog` | TextArea | Nhật ký lỗi; `Editable = 'off'`, `Value` là cell |

## 3. Callback

Giữ nguyên tên App Designer tự sinh: `BtnGenPushed`, `BtnNoisePushed`, `BtnDecodePushed`, `BtnPlayXPushed`, `BtnPlayPushed`,
`DdNoiseValueChanged`, `DdMethodValueChanged`, `SldSNRValueChanged`, `BtnRecordPushed`, `BtnListenPushed`, `BtnSrcPushed`,
`BtnClearPushed`, `AxKeypadClicked`, `BtnOpenPushed`, `EfKeysValueChanging`.
`BtnOpenPushed` chỉ mở hộp chọn tệp rồi gọi method public `napTep(app, duongDan)`; test gọi thẳng
`napTep` vì chạy ẩn thì không mở được hộp chọn tệp.
`EfKeysValueChanging` chỉ tô lại nút (gõ chuỗi mới thì bước tiếp theo lại là Tạo tín hiệu); lúc nó chạy `EfKeys.Value`
**chưa** đổi, nên chuỗi đang gõ lấy từ `event.Value`.
`SldSNRValueChanging` chỉ cập nhật `LblSNR`, **không** cộng nhiễu - việc đó chỉ xảy ra lúc thả chuột.
Cả 12 nút bàn phím dùng **chung một callback** `Btn1Pushed`, lấy ký tự từ `event.Source.Text`.

Chữ ký là `(app, event)` — **hai tham số**, y như App Designer sinh ra, để sau này dán nguyên thân
callback sang `.mlapp` mà không phải sửa dòng nào. `DTMFApp.m` nối dây bằng
`'ButtonPushedFcn', @(src, evt) app.Btn1Pushed(evt)`; gọi từ test là `app.BtnGenPushed([])`.

Mọi callback để **`public`** (App Designer mặc định `private`): MATLAB không có API công khai nào
để "bấm" một `uibutton` bằng code, nên `tests/test_app_smoke.m` phải gọi thẳng chúng.

Mỗi callback tối đa ~3 dòng: đọc UI vào `app.S` → bước tính toán → `veLai`. Không tính toán DSP trong callback.
Phần việc dài hơn nằm ở các method `private` của `DTMFApp`: `docUI` (chiều UI → `S` duy nhất),
`taoTinHieu` (bước 1), `congNhieu` (bước 2), `giaiMa` (bước 3, gọi `dtmf_run`), `doiKenh`, `xoaKetQua`,
`phat`/`phatPhim`, `ghiNhatKy`.

Callback gọi `veLai(app)` thay vì gọi thẳng `ui_refresh(app)`:
`veLai` = `ui_refresh` + `datTieuDe` + `capNhatKetQua` + `capNhatNut`.
Tiêu đề trục theo bước, `LblSent`, `LblStatus` và dòng thông tin mỗi thẻ phụ thuộc trạng thái của app (nguồn,
bước đã làm) nên **không** nằm trong hợp đồng của `ui_refresh` (CONTRACTS §8).

```matlab
function BtnNoisePushed(app, event)
    docUI(app);
    congNhieu(app);
    veLai(app);
end
```

## 4. Màu và phông chữ

Mọi màu, phông và thang màu của giao diện nằm ở **một** chỗ: `app/ui/ui_theme.m`.
`DTMFApp` dùng nó khi dựng component; `ui_refresh` dùng nó để tô lại các trục **sau** khi `ui_plot_*` vẽ xong.
`ui_plot_wave` và `ui_plot_bars` giữ màu riêng (cam) vì còn vẽ hình cho báo cáo và `test_ui_smoke` ghim màu đó - đừng sửa màu trong hai hàm đó để đổi giao diện.
`ui_plot_psd` và `ui_plot_map` chỉ phục vụ giao diện nên lấy màu thẳng từ `ui_theme`.

## 5. Struct `app.S`

Một property `S` duy nhất, không rải biến rời rạc. Tên trường theo `CONTRACTS.md`:

`S.keys` · `S.x` · `S.y` · `S.fs` · `S.meta` · `S.noise` · `S.snrDb` · `S.method` · `S.keysHat` · `S.info` · `S.thr` · `S.iSel` · `S.lastError`

## 6. Màn tổng đài `DTMFLive`

`app/DTMFLive.m` là cửa sổ thứ hai, dùng khi trình diễn trực tiếp với trang web điện thoại (README, CONTRACTS §7.10). Cùng cách đặt tên với `DTMFApp`; trạng thái nằm ở `L` (của `dtmf_listen`) chứ không ở `S`, vì màn này chỉ nghe, không tạo tín hiệu.

| Tên | Loại | Nội dung |
|---|---|---|
| `BtnSrcLine` / `BtnSrcMic` | Button | Chọn nguồn đường dây hoặc micro; chung callback `BtnSrcPushed`. Rời đường dây là ngắt hẳn |
| `DdMethod` | DropDown | `ItemsData = {'goertzel','fft','filterbank'}`; đổi giữa chừng thì giữ phím đã đọc |
| `BtnRun` | Button | Đường dây: "Nối đường dây" / "Ngắt đường dây". Micro: "Bật micro" / "Tắt micro" |
| `LblLine` | Label | Trạng thái đường dây hoặc micro |
| `LblCall` | Label | Trạng thái cuộc gọi; chữ nhấp nháy lúc đổ chuông |
| `LblClock` | Label | Đồng hồ cuộc gọi, hoặc thời lượng và số phím khi đã gác máy |
| `LblHint` | Label | Một dòng gợi ý việc cần làm tiếp theo trạng thái cuộc gọi |
| `AxPad` | UIAxes | Bàn phím 4×3 sáng đèn, vẽ bởi `ui_live_draw` |
| `LblNumber` | Label | Dãy số MATLAB đọc được trong cuộc gọi này (16 phím cuối) |
| `LnkClear` | Hyperlink | Xóa dãy số và nhật ký, không đụng cuộc gọi |
| `LblLog` | Label | Nhật ký phím và sự kiện dạng bảng (nhãn HTML), 6 dòng mới nhất ở trên |
| `BtnHangup` | Button | MATLAB gác máy; chỉ bật khi đang đổ chuông hoặc đang nghe máy |
| `AxWave` / `AxZoom` | UIAxes | Hình 1 dạng sóng 3 s gần nhất / Hình 2 32 ms cuối; chú thích dưới hình là nhãn riêng |
| `AxMap` / `AxBars` | UIAxes | Năng lượng 8 bin theo khung / 8 bin của khung mới nhất kèm phán quyết |
| `LblStatus` | Label | Bộ giải mã, số giây đã nghe, số khung |

`CuocGoi` đi `'cho'` → `'chuong'` (tin `call`) → `'noi'` (sau 1,5 s, MATLAB gửi `answer`) → `'xong'` (tin `hangup` hoặc `BtnHangup`); nguồn micro dùng `'tat'` / `'nghe'`. Chạy ẩn (`DTMFLive('off')`) thì không nối mạng, không mở micro, không chạy đồng hồ: test đưa tin vào qua `nhanTin`, gọi `nhip` và `nhacMay`, rồi đọc `app.Line.DaGui`.

Hai màu `M.hang` (cam) và `M.cot` (xanh) của `ui_theme` chỉ dùng ở hình số liệu của hai màn trực tiếp (`DTMFLive`, `DTMFForensic`, qua `ui_live_draw`), đúng cặp màu nhóm hàng / nhóm cột của trang web. Màn này trình bày như một trang LaTeX theo `M.tex`: chữ Times New Roman như `report/template/dtmf_report.cls`, số và ký hiệu trên trục qua bộ diễn dịch `latex` (bộ này không có dấu tiếng Việt, nên chữ tiếng Việt luôn để ở phông thường).

## 7. Màn giám định `DTMFForensic`

`app/DTMFForensic.m` là màn chiếu của buổi trình diễn chính (README, CONTRACTS §7.11): trang web gửi một đoạn ghi âm, MATLAB nghe dần, kết luận khi hết đoạn rồi mới đối chiếu với số thật. Cùng cách đặt tên và cùng `ui_live_draw` với `DTMFLive`; trạng thái đọc nằm ở `L` (của `dtmf_listen`).

| Tên | Loại | Nội dung |
|---|---|---|
| `BtnSrcLine` / `BtnSrcMic` | Button | Nguồn đường dây hoặc micro; chung callback `BtnSrcPushed` |
| `DdMethod` | DropDown | Bộ giải mã dùng cho dãy số đang đọc và cho kết luận chính; bị khóa trong lúc nghe |
| `BtnRun` | Button | Đường dây: "Nối đường dây" / "Ngắt đường dây" (ngắt giữa vụ thì hủy vụ). Micro: "Bắt đầu nghe" / "Kết luận" |
| `LblClock` / `LblCase` / `LblLine` / `LblHint` | Label | Đồng hồ vụ, số vụ kèm câu trạng thái, trạng thái đường dây, dòng gợi ý việc tiếp theo |
| `LblNumber` | Label | Số đọc được tới lúc này, từng chữ số hiện dần |
| `LblMethods` | Label | Bảng ba bộ giải mã: số đọc được và thời gian xử lý cả đoạn |
| `LblMatch` | Label | Hai hàng *thật* và *đọc*, từng chữ số tô xanh nếu đúng, đỏ nếu sai; chưa công bố thì ghi "Chưa công bố số thật" |
| `LblVerdict` | Label | "... khớp cả n chữ số" hoặc "... lệch k: ..." cho bộ giải mã đang chọn |
| `EfTruth` | EditField | Số thật nhập tay khi không có trang web (nguồn micro) |
| `BtnReveal` | Button | Nhãn "Đối chiếu", công bố `EfTruth`; bật khi đang nghe hoặc đã kết luận |
| `AxWave` / `AxZoom` / `AxMap` / `AxBars` | UIAxes | Như `DTMFLive`; `AxMap` thêm hai làn k̂ (số đọc được) và k (số thật) |
| `LblStatus` | Label | Bộ giải mã, số giây đã nghe, số khung |

`Ho` đi `'cho'` → `'nghe'` (tin `case`, hoặc `BtnRun` ở nguồn micro) → `'ketluan'` (tin `end`) → `'doichieu'` (tin `reveal`, hoặc `BtnReveal`). Tin `reveal` đến trước `verdict` thì MATLAB kết luận trước rồi mới đối chiếu, nên đáp án không bao giờ lộ trước kết luận. Mất đường dây hoặc ngắt giữa vụ thì về `'cho'` và báo lỗi ở dòng gợi ý. Callback: `BtnSrcPushed`, `DdMethodValueChanged`, `BtnRunPushed`, `BtnRevealPushed`.

