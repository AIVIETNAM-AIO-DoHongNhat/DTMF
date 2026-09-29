# Quy ước tên component - DTMFApp

> Giao diện là `app/DTMFApp.m` dạng `classdef`, **không** phải `.mlapp` — xem `CONTRACTS.md` §8.

> `AxWave`, `AxSpec`, `AxBars`, `TxtLog`, `LblDecoded` đã bị `app/ui/ui_refresh.m` gọi thẳng - **không đổi tên**.

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

Label chú thích tĩnh (kiểu "SNR (dB)") không cần đặt tên.

## 2. Danh sách component

**Bố cục cột trái** - ba thẻ đánh số theo thứ tự thao tác:

| Thẻ | Nội dung |
|---|---|
| 01 Thiết lập | Nguồn: `BtnSrcGen` / `BtnSrcMic` (hai nút dạng tab) · Bộ giải mã: `DdMethod` (dùng chung cho hai nguồn) |
| 02 | `PnlKeypad` (nguồn tổng hợp) **hoặc** `PnlMic` (nguồn micro) - chồng lên nhau ở cùng một ô lưới, chỉ thẻ của nguồn đang chọn được hiện |
| 03 Kết quả | `LblSent` + `BtnPlay`, `LblDecoded`, `LblStatus` |

Luật màu nút (`capNhatNut`): nút của bước cần bấm **tiếp theo** nền màu nhấn chữ đậm, nút khác nền trắng; nút chưa dùng được bị khóa. Nguồn tổng hợp: chưa có tín hiệu hoặc chuỗi phím đã sửa sau lần phát → `BtnGen`; đã phát chưa giải mã → `BtnDecode`; đã giải mã → không nút nào. Test đọc dấu hiệu này qua `FontWeight`.

**Bàn phím** - 12 nút trong `PnlKeypad`:

| | 1209 | 1336 | 1477 |
|---|:---:|:---:|:---:|
| **697** | `Btn1` | `Btn2` | `Btn3` |
| **770** | `Btn4` | `Btn5` | `Btn6` |
| **852** | `Btn7` | `Btn8` | `Btn9` |
| **941** | `BtnStar` | `Btn0` | `BtnHash` |

`*` và `#` không hợp lệ trong tên biến MATLAB nên viết chữ; `Text` của nút vẫn là `*` và `#`.

**Trục vẽ:**

| Tên | Nội dung |
|---|---|
| `AxWave` | Dạng sóng + vùng tone |
| `AxSpec` | Phổ đồ STFT |
| `AxBars` | 8 thanh công suất + ngưỡng |

**Điều khiển:**

| Tên | Loại | Ghi chú |
|---|---|---|
| `DdMethod` | DropDown | `ItemsData = {'fft','goertzel','filterbank'}` → `Value` khớp sẵn `S.method` |
| `SldSNR` | Slider | `Limits = [-5 30]`, đơn vị dB, dùng `ValueChanged` (không dùng `ValueChanging`) |
| `EfKeys` | EditField | Chuỗi phím cần phát |
| `BtnClear` | Button | Xóa trắng `EfKeys`, không đụng tín hiệu đang có |
| `BtnSrcGen` / `BtnSrcMic` | Button | Chọn nguồn; dùng chung callback `BtnSrcPushed`. Đổi nguồn thì xóa kết quả của nguồn cũ, giữ `EfKeys` |
| `BtnGen` / `BtnDecode` | Button | "① Phát tín hiệu" / "② Giải mã", trong `PnlKeypad` |
| `BtnPlay` | Button | "▶ Nghe", trong thẻ Kết quả cạnh `LblSent`: phát `S.y` qua `app/ui/ui_play.m` - tín hiệu **đã cộng nhiễu**, hoặc bản ghi micro, tức đúng cái bộ giải mã nghe |
| `BtnListen` | Button | "Giải mã trực tiếp", trong `PnlMic`. Bấm: nghe micro liên tục, mỗi 50 ms đưa phần mẫu mới qua `app/dtmf_listen.m`, phím hiện ngay khi nhận ra. Bấm lần nữa: dừng |
| `BtnRecord` | Button | "Ghi âm rồi giải mã", trong `PnlMic`. Bấm: ghi âm micro (tối đa 20 s). Bấm lần nữa: dừng, lấy bản ghi làm `S.y` rồi giải mã qua `dtmf_run` |

Đang dùng micro thì hai nút nguồn, `BtnPlay` và nút micro còn lại bị khóa; nút micro đang chạy đổi chữ thành "■ Dừng…" và nền màu nhấn.
Chạy ẩn (`DTMFApp('off')`) thì **không** mở micro: test đưa âm thanh vào qua hai method công khai `nhanMauMic(chunk)` và `napBanGhi(y)`.

**Hiển thị:**

| Tên | Loại | Nội dung |
|---|---|---|
| `LblSent` | Label | Chuỗi đã phát (`S.meta.keys`), đặt ngay trên `LblDecoded` để so từng cột ký tự; do `capNhatKetQua` ghi |
| `LblDecoded` | Label | Chuỗi phím giải mã (`S.keysHat`); `ui_refresh` tô xanh khi khớp `S.meta.keys`, đỏ khi lệch |
| `LblStatus` | Label | Một dòng trạng thái: chưa có tín hiệu / chưa giải mã / khớp k/k phím / lệch, kèm bộ giải mã và SNR; do `capNhatKetQua` ghi |
| `LblSNR` | Label | Giá trị SNR đang chọn, cập nhật ngay trong lúc kéo (`SldSNRValueChanging`) |
| `TxtLog` | TextArea | Nhật ký + lỗi; `Editable = 'off'`, `Value` là cell |

## 3. Callback

Giữ nguyên tên App Designer tự sinh: `BtnDecodePushed`, `DdMethodValueChanged`, `SldSNRValueChanged`,
`BtnRecordPushed`, `BtnListenPushed`, `BtnSrcPushed`, `EfKeysValueChanging`.
`EfKeysValueChanging` chỉ tô lại nút (gõ chuỗi mới thì bước tiếp theo lại là ①); lúc nó chạy `EfKeys.Value`
**chưa** đổi, nên chuỗi đang gõ lấy từ `event.Value`.
`SldSNRValueChanging` chỉ cập nhật `LblSNR`, **không** giải mã - giải mã lại chỉ xảy ra lúc thả chuột.
Cả 12 nút bàn phím dùng **chung một callback** `Btn1Pushed`, lấy ký tự từ `event.Source.Text`.

Chữ ký là `(app, event)` — **hai tham số**, y như App Designer sinh ra, để sau này dán nguyên thân
callback sang `.mlapp` mà không phải sửa dòng nào. `DTMFApp.m` nối dây bằng
`'ButtonPushedFcn', @(src, evt) app.Btn1Pushed(evt)`; gọi từ test là `app.BtnGenPushed([])`.

Mười hai callback để **`public`** (App Designer mặc định `private`): MATLAB không có API công khai nào
để "bấm" một `uibutton` bằng code, nên `tests/test_app_smoke.m` phải gọi thẳng chúng.

Mỗi callback tối đa ~3 dòng: đọc UI vào `app.S` → `dtmf_run` → `ui_refresh`. Không tính toán DSP trong callback.
Phần việc dài hơn nằm ở các method `private` của `DTMFApp`: `docUI` (chiều UI → `S` duy nhất),
`sinhTinHieu`, `congNhieu`, `xoaKetQua`, `giaiMa`, `phat`/`phatPhim`, `ghiNhatKy`.

Callback gọi `veLai(app)` thay vì gọi thẳng `ui_refresh(app)`: `veLai` = `ui_refresh` + `capNhatKetQua` + `capNhatNut`.
`LblSent` và `LblStatus` **không** nằm trong hợp đồng sáu thành phần của `ui_refresh` (CONTRACTS §8),
nên `test_ui_smoke` vẫn dựng app giả đúng sáu thứ như cũ.

```matlab
function Btn1Pushed(app, event)
    app.EfKeys.Value = [app.EfKeys.Value, event.Source.Text];
end

function BtnDecodePushed(app, event)
    app.S.method = app.DdMethod.Value;
    app.S = dtmf_run(app.S);
    ui_refresh(app);
end
```

## 4. Màu và phông chữ

Mọi màu, phông và thang màu phổ đồ của giao diện nằm ở **một** chỗ: `app/ui/ui_theme.m`.
`DTMFApp` dùng nó khi dựng component; `ui_refresh` dùng nó để tô lại ba trục **sau** khi `ui_plot_*` vẽ xong.
`ui_plot_*` giữ màu riêng (cam) vì còn vẽ hình cho báo cáo và `test_ui_smoke` ghim màu đó - đừng sửa màu trong `ui_plot_*` để đổi giao diện.

## 5. Struct `app.S`

Một property `S` duy nhất, không rải biến rời rạc. Tên trường theo `CONTRACTS.md`:

`S.keys` · `S.x` · `S.y` · `S.fs` · `S.meta` · `S.snrDb` · `S.method` · `S.keysHat` · `S.info` · `S.thr` · `S.iSel` · `S.lastError`
