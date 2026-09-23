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
| `BtnGen` / `BtnDecode` / `BtnPlay` | Button | Phát tín hiệu / giải mã / nghe |

**Hiển thị:**

| Tên | Loại | Nội dung |
|---|---|---|
| `LblDecoded` | Label | Chuỗi phím giải mã (`S.keysHat`) |
| `TxtLog` | TextArea | Nhật ký + lỗi; `Editable = 'off'`, `Value` là cell |

## 3. Callback

Giữ nguyên tên App Designer tự sinh: `BtnDecodePushed`, `DdMethodValueChanged`, `SldSNRValueChanged`.
Cả 12 nút bàn phím dùng **chung một callback** `Btn1Pushed`, lấy ký tự từ `event.Source.Text`.

Mỗi callback tối đa ~3 dòng: đọc UI vào `app.S` → `dtmf_run` → `ui_refresh`. Không tính toán DSP trong callback.

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

## 4. Struct `app.S`

Một property `S` duy nhất, không rải biến rời rạc. Tên trường theo `CONTRACTS.md`:

`S.keys` · `S.x` · `S.y` · `S.fs` · `S.meta` · `S.snrDb` · `S.method` · `S.keysHat` · `S.info` · `S.thr` · `S.iSel` · `S.lastError`
