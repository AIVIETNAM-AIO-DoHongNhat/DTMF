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

Label chú thích tĩnh (kiểu "SNR") không cần đặt tên.

## 2. Bố cục và danh sách component

Ba thẻ bước xếp dọc theo đúng đường tín hiệu đi. Mỗi thẻ gồm cột điều khiển bên trái và hai trục bên phải - miền thời gian rồi miền tần số - của **đúng** tín hiệu ở bước đó:

| Thẻ | Điều khiển | Trục thời gian | Trục tần số |
|---|---|---|---|
| Bước 1 · Tín hiệu gốc x[n] | `PnlKeypad` (tổng hợp) **hoặc** `PnlMic` (micro), chồng lên nhau ở cùng một ô lưới | `AxWaveX` | `AxPsdX` |
| Bước 2 · Kênh nhiễu y[n] = x[n] + w[n] | `DdNoise`, `SldSNR` + `LblSNR`, `BtnNoise`, `BtnPlay` | `AxWave` | `AxPsd` |
| Bước 3 · Giải mã | `DdMethod`, `BtnDecode`, `LblSent`, `LblDecoded` | `AxMap` | `AxBars` |

Trên cùng là dòng tiêu đề với hai nút nguồn `BtnSrcGen` / `BtnSrcMic`; dưới cùng là thanh trạng thái `LblStatus` + `TxtLog`.

Ba thẻ dùng chung một cách chia cột, nên `AxWaveX`, `AxWave`, `AxMap` thẳng mép nhau và cùng `XLim`: một thời điểm ở hàng trên nằm đúng trên thời điểm đó ở hàng dưới.

Phong cách tối giản: thẻ trắng không viền trên nền xám nhạt, không số khoanh tròn, chú thích dài nằm trong `Tooltip`. Mỗi thẻ có nhãn chữ nhỏ "BƯỚC k" ở góc, tô màu nhấn khi bước đó đã có kết quả.

Luật bước tiếp theo (`buocTiep`, `capNhatNut`): nút của bước cần bấm **tiếp theo** nền màu nhấn chữ đậm, và vạch 3 px ở mép trái thẻ của bước đó cũng tô màu nhấn; nút khác nền trắng; nút chưa dùng được bị khóa. Nguồn tổng hợp:

- chưa có x, hoặc chuỗi phím đã sửa sau lần tạo → `BtnGen`
- có x, chưa cộng nhiễu → `BtnNoise`
- có y, chưa giải mã → `BtnDecode`
- đã giải mã → không nút nào

Test đọc dấu hiệu này qua `FontWeight`.

**Bàn phím** - 12 nút trong `PnlKeypad`:

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
| `DdNoise` | DropDown | `ItemsData = {'awgn','hum50'}` → `Value` khớp sẵn `S.noise` |
| `SldSNR` | Slider | `Limits = [-5 30]`, đơn vị dB, áp dụng ở `ValueChanged` (thả chuột) |
| `BtnNoise` | Button | "Cộng nhiễu": y[n] = x[n] + w[n] qua `dtmf_addnoise` |
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
`EfKeysValueChanging`.
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
