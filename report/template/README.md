# Template báo cáo kỹ thuật — Dự án DTMF (v2)

Phỏng theo cấu trúc template báo cáo khoa học AIO, **bỏ logo**, thiết kế lại toàn bộ bố cục theo thể thức báo cáo khoa học tiếng Việt.

Kèm sẵn `main_mau.pdf` — bản biên dịch thử 22 trang để xem trước khi bắt tay viết.

## Các file

| File | Nội dung | Ai được sửa |
|---|---|---|
| `main.tex` | Khung đề cương chi tiết: Mở đầu, Chương I–V, Tài liệu tham khảo, 3 phụ lục | Người viết chương của mình |
| `dtmf_report.cls` | Lớp tài liệu: khổ trang, font, đánh số, bảng màu, hộp mã nguồn | **Chỉ Lâm** — khoá sau 16/09 |
| `references.bib` | Tài liệu tham khảo | Lâm + người trích dẫn |
| `tvietlistings.sty` | Hỗ trợ tiếng Việt trong khối mã | Không sửa |
| `Figures/` | Toàn bộ hình | Khương quản lý |

## Biên dịch

```bash
xelatex main      # hoặc pdflatex main
biber   main
xelatex main
xelatex main
```

Gọn hơn: `latexmk -xelatex main.tex`

Class tự nhận diện engine — chạy được cả **pdfLaTeX** (babel + vntex) lẫn **XeLaTeX/LuaLaTeX** (fontspec). Trên Overleaf chọn compiler nào cũng được.

Máy Windows có sẵn font Microsoft thì gọi `\documentclass[winfont]{dtmf_report}` để dùng Times New Roman / Arial / Consolas thật. Mặc định dùng bộ **Liberation** — tương thích metric 100% với Times New Roman, có sẵn trên Linux và Overleaf, nên bản in ra giống hệt.

---

# THÔNG SỐ THIẾT KẾ

## Khổ trang

| Thông số | Giá trị |
|---|---|
| Khổ giấy | A4 (210 × 297 mm) |
| Lề trái | 3 cm (chừa chỗ đóng gáy) |
| Lề phải | 2 cm |
| Lề trên / dưới | 2,5 cm |
| Bề rộng cột chữ | 16 cm |
| Số trang | Giữa chân trang, cỡ 12 pt |

Không dùng đầu trang — trang sạch, đúng kiểu báo cáo khoa học.

## Thang cỡ chữ

Cơ sở 13 pt, giãn dòng 1,5 (leading 19,5 pt).

| Thành phần | Cỡ / Leading | Kiểu | Căn |
|---|---|---|---|
| Tên chương | 16 / 22 pt | Đậm, IN HOA | Giữa |
| Số chương (I., II.) | 14 / 18 pt | Đậm | Giữa, dòng riêng |
| Tiêu đề mục (1.1) | 14 / 20 pt | Đậm | Trái |
| Tiêu đề mục con (1.1.1) | 13 / 19 pt | Đậm nghiêng | Trái |
| Thân chữ | 13 / 19,5 pt | Thường | Đều hai bên |
| Chú thích hình, bảng | 12 / 18 pt | Nhãn đậm | Giữa |
| Nội dung bảng | 12 / 18 pt | Thường | Tuỳ cột |
| Mã nguồn | 10 / 13 pt | Đơn cách | Trái |
| Số dòng mã | 8,5 pt | Đơn cách | Phải |
| Cước chú | 11 / 16 pt | Thường | Đều |

**Thụt đầu dòng 1,27 cm, không giãn cách giữa các đoạn** — đúng quy ước văn bản học thuật tiếng Việt. Đoạn đầu tiên ngay sau tiêu đề cũng thụt vào cho đều (gói `indentfirst`).

## Màu

Nguyên tắc: **chữ đen tuyền để in rõ.** Màu chỉ dùng cho liên kết, mã nguồn, đường kẻ mảnh và viền hộp — **không tô màu tiêu đề**. Tiêu đề màu làm báo cáo trông như slide, không như tài liệu kỹ thuật.

| Tên màu | Mã RGB | Dùng ở đâu |
|---|---|---|
| Đen | `0,0,0` | Toàn bộ chữ và tiêu đề |
| `dtmfBlue` | `21,78,115` | Đường kẻ trang bìa, viền hộp, liên kết |
| `dtmfAmber` | `160,82,24` | Hộp cảnh báo |
| `dtmfRule` | `170,182,190` | Đường kẻ mảnh dưới tên chương |
| `dtmfGray` | `95,105,112` | Viền hộp kết quả chạy |
| `dtmfBoxBg` | `243,247,250` | Nền hộp ghi chú |

Mã nguồn: từ khoá `20,72,150` · chú thích `38,115,66` · chuỗi `158,52,36` · số dòng `140,148,155`.

## Đánh số

| Đối tượng | Cách đánh | Ví dụ |
|---|---|---|
| Chương | La Mã | `I.`, `II.`, `III.` |
| Mục | Ả Rập theo chương | `1.1`, `2.3` |
| Mục con | Ba cấp | `2.2.4` |
| Hình | Theo chương, chú thích **dưới** | `Hình 2.1.` |
| Bảng | Theo chương, chú thích **trên** | `Bảng 3.2.` |
| Công thức | Theo chương, căn phải | `(2.5)` |
| Hình/bảng phụ lục | Tiền tố riêng | `PL1.1`, `PL3.1` |
| Trang phần đầu | La Mã thường | i, ii, iii |
| Trang nội dung | Ả Rập, bắt đầu từ 1 | 1, 2, 3 |

## Bảng biểu

Dùng `booktabs` — chỉ kẻ ngang, **không kẻ dọc**. Giãn dòng trong ô 1,3; khoảng cách cột 8 pt; đường kẻ đầu/cuối 0,9 pt, đường giữa 0,5 pt. Ô tiêu đề cột dùng `\thd{...}`.

## Xử lý chữ căn đều

Ba thiết lập giải quyết vấn đề đặc thù của tiếng Việt — **không ngắt từ giữa dòng**, nên chữ căn đều rất dễ bị giãn thưa hoặc tràn lề:

- `microtype` — nhô ký tự ra ngoài lề và co giãn font ở mức vi mô
- `emergencystretch = 3em` — cho phép nới thêm khi không còn cách nào khác
- `tolerance = 2000` — nới ngưỡng chấp nhận khoảng trắng

Bản mẫu 22 trang biên dịch ra **0 lỗi, chỉ 1 dòng tràn lề 1,2 pt** (mắt thường không thấy).

Ngoài ra `widowpenalty` và `clubpenalty` đặt 10000 — cấm tuyệt đối dòng lạc đầu và cuối trang.

---

# CÁCH DÙNG

## Mục không đánh số

```latex
\unsection{MỞ ĐẦU}              % trình bày như tên chương, vẫn vào mục lục
\unsubsection{1. Đặt vấn đề}
```

## Chèn hình

Đặt file vào `Figures/`, tên đúng mã hình (`H2.4.pdf`):

```latex
\begin{figure}[H]
  \centering
  \includegraphics[width=0.8\linewidth]{Figures/H2.4.pdf}
  \caption{Sơ đồ khối bộ lọc Goertzel bậc hai}
  \label{fig:goertzel-block}
\end{figure}
```

Tham chiếu bằng `Hình~\ref{fig:goertzel-block}`. **Mọi hình bắt buộc phải được tham chiếu ít nhất một lần** — đây là một mục trong checklist nghiệm thu.

Chỗ chưa có hình để tạm `\chohinh{mô tả}` — vẽ ô xám giữ chỗ. **Xoá hết trước khi nộp.**

## Các hộp có sẵn

```latex
\begin{matlabbox}[Tên hàm]      % mã MATLAB, tô màu cú pháp, đánh số dòng
\begin{outputbox}[Kết quả chạy] % kết quả Command Window
\begin{notebox}[Ghi chú]        % hộp xanh
\begin{warnbox}[Lưu ý]          % hộp cam
\begin{summarybox}              % hộp tóm tắt cuối mục
```

## Ký hiệu toán dùng chung

Khai báo ở mục XVI của `.cls`. Cả nhóm gõ lệnh, **không ai tự viết ký hiệu riêng**:

| Lệnh | Ý nghĩa |
|---|---|
| `\fs` | tần số lấy mẫu |
| `\dfres` | độ phân giải tần số |
| `\Xk` | hệ số DFT |
| `\Htf` | hàm truyền H(z) |
| `\Hfreq` | đáp ứng tần số |
| `\wzero` | tần số cộng hưởng |
| `\Qfac` | hệ số phẩm chất |
| `\SNRdB` | SNR theo dB |
| `\dB` | đơn vị dB |

Cần thêm ký hiệu mới thì **báo Lâm thêm vào `.cls`**.

---

# LƯU Ý KHI CÀI

Class tự lùi về phương án dự phòng nếu máy thiếu gói, nên vẫn biên dịch được:

- Thiếu `biblatex` → tự bỏ qua danh mục tài liệu, báo một dòng trong PDF
- Thiếu `dirtree` → thay cây thư mục bằng một dòng ghi chú
- Thiếu Times New Roman → dùng Liberation Serif (cùng metric)

Chỉ có gói tiếng Việt là bắt buộc. Nếu compile bằng **pdfLaTeX** mà báo thiếu `vietnamese.ldf`, cài **vntex** (TeX Live: `tlmgr install vntex`; MiKTeX tự hỏi và cài). Dùng **XeLaTeX** thì không cần vntex.
