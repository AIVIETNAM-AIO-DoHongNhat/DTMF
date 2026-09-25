% =========================================================
% dtmf_report.cls  --  v2
% Lớp tài liệu cho Báo cáo kỹ thuật
% Bài tập lớn Xử lý tín hiệu số — Chủ đề 4 (DTMF)
%
% Thiết kế theo thể thức báo cáo khoa học Việt Nam:
%   A4 · lề trái 3cm / phải 2cm / trên dưới 2,5cm
%   Times New Roman 13pt · giãn dòng 1,5 · thụt đầu dòng 1,27cm
%   Tiêu đề đen, không tô màu — màu chỉ dùng cho liên kết, mã nguồn, đường kẻ
%
% Chạy được với cả pdfLaTeX (babel + vntex) lẫn XeLaTeX/LuaLaTeX (fontspec).
% =========================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{dtmf_report}[2026/09/13 v2 Bao cao ky thuat DTMF]

\newif\ifdtmfwinfont \dtmfwinfontfalse
\DeclareOption{winfont}{\dtmfwinfonttrue}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[12pt,a4paper,oneside]{article}

\RequirePackage{iftex}

% =========================================================
% I. FONT & NGÔN NGỮ  (tự nhận diện engine)
% =========================================================
\ifPDFTeX
  % --- pdfLaTeX: dùng babel tiếng Việt + font kiểu Times ---
  \PassOptionsToPackage{vietnamese.licr}{babel}
  \RequirePackage[vietnamese=nohyphenation]{hyphsubst}
  \RequirePackage[vietnamese]{babel}
  \RequirePackage[T5,T1]{fontenc}
  \RequirePackage[utf8]{inputenc}
  \RequirePackage{mathptmx}          % Times cho cả văn bản lẫn công thức
  \RequirePackage[scaled=.92]{helvet}
  \RequirePackage{courier}
\else
  % --- XeLaTeX / LuaLaTeX: fontspec ---
  % Chữ Times: kiểu chữ phổ biến nhất của bài báo khoa học (IEEE, Elsevier,
  % Springer) và là chuẩn trình bày văn bản học thuật tiếng Việt.
  % Mặc định dùng bộ TeX Gyre (Termes, Heros, Cursor): nhân bản tương thích
  % thước đo với Times New Roman, Arial, Courier New, và ĐI KÈM bản phân phối
  % TeX nên chạy như nhau trên Windows, Linux lẫn Overleaf mà không cần cài
  % font. Bản trước dùng Liberation, vốn là font hệ điều hành Linux, nên máy
  % Windows biên dịch báo lỗi "font not found".
  % Muốn dùng đúng font Microsoft đã cài trên máy:
  %     \documentclass[winfont]{dtmf_report}
  \RequirePackage{mathptmx}   % công thức theo kiểu Times, khớp với thân chữ
  \RequirePackage{fontspec}
  \RequirePackage{polyglossia}
  \setmainlanguage{vietnamese}
  \ifdtmfwinfont
    \setmainfont{Times New Roman}
    \setsansfont{Arial}[Scale=0.92]
    \setmonofont{Consolas}[Scale=0.88]
  \else
    \setmainfont{TeX Gyre Termes}
    \setsansfont{TeX Gyre Heros}[Scale=0.92]
    \setmonofont{TeX Gyre Cursor}[Scale=0.92]
  \fi
\fi

% =========================================================
% II. GÓI CƠ BẢN
% =========================================================
\RequirePackage[table,dvipsnames]{xcolor}
\RequirePackage{amsmath,amssymb}
\RequirePackage{mathtools}
\RequirePackage{graphicx}
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{tabularx}
\RequirePackage{longtable}
\RequirePackage{multirow}
\RequirePackage{makecell}
\RequirePackage{caption}
\RequirePackage{subcaption}
\RequirePackage{float}
\RequirePackage[inline,shortlabels]{enumitem}
\RequirePackage{setspace}
\RequirePackage{ragged2e}
\RequirePackage{titlesec}
\RequirePackage{tocloft}
\RequirePackage{fancyhdr}
\RequirePackage{xurl}
\RequirePackage{microtype}   % chỉnh vi mô chữ — cực quan trọng với chữ căn đều
\IfFileExists{dirtree.sty}{\RequirePackage{dirtree}%
  % Tên thư mục dùng chữ đơn cách, lời chú thích dùng chữ thân nghiêng
  % (chữ đơn cách không có dấu tiếng Việt đẹp và làm giãn dòng).
  \renewcommand*{\DTstyle}{\ttfamily\small}%
  \renewcommand*{\DTstylecomment}{\rmfamily\itshape\small}}{%
  % Máy thiếu gói dirtree -> dùng bản thay thế đơn giản để vẫn biên dịch được
  \newcommand{\dirtree}[1]{\begin{quote}\ttfamily\small
    \textit{[Cần gói dirtree để vẽ cây thư mục]}\end{quote}}}

% =========================================================
% III. KHỔ TRANG
% Lề theo quy định trình bày báo cáo khoa học: trái 3cm (chừa đóng gáy),
% phải 2cm, trên và dưới 2cm.
% =========================================================
\RequirePackage[a4paper,
  left=3cm, right=2cm, top=2cm, bottom=2cm,
  footskip=1.1cm, headsep=0.6cm]{geometry}

% =========================================================
% IV. THÂN CHỮ
% Theo thiết lập đoạn văn chuẩn của Word: căn đều hai bên, lề trong/ngoài
% 0cm, thụt dòng đầu 1,27cm, khoảng trước/sau đoạn 0pt, giãn dòng 1,5 lines.
%
% "1,5 lines" của Word là 1,5 lần dòng đơn, mà dòng đơn của Times New Roman
% cao 1,15 lần cỡ chữ. Vì vậy mỗi cỡ chữ đặt khoảng dòng đơn = 1,15 x cỡ chữ,
% rồi phần thân giãn 1,5 lần (13pt -> 22,4pt). setspace tự trả về dòng đơn
% trong bảng, hình, chú thích và chú thích chân trang.
% =========================================================
\renewcommand{\normalsize}{\fontsize{13}{14.95}\selectfont}
\renewcommand{\small}{\fontsize{12}{13.8}\selectfont}
\renewcommand{\footnotesize}{\fontsize{11}{12.65}\selectfont}
\renewcommand{\scriptsize}{\fontsize{10}{11.5}\selectfont}
\renewcommand{\large}{\fontsize{14}{16.1}\selectfont}
\renewcommand{\Large}{\fontsize{16}{18.4}\selectfont}
\renewcommand{\LARGE}{\fontsize{18}{20.7}\selectfont}
\normalsize
\setstretch{1.5}

% Danh sách theo cùng quy tắc đoạn văn: ký hiệu đầu dòng thụt 1,27cm như
% dòng đầu đoạn, dòng tràn quay về lề trái, không chèn khoảng trống.
\setlist{leftmargin=0pt, labelindent=1.27cm, itemindent=*, labelsep=0.5em,
         align=left, listparindent=1.27cm,
         topsep=0pt, partopsep=0pt, itemsep=0pt, parsep=0pt}
% Ký hiệu đầu dòng theo thể thức văn bản tiếng Việt: cấp 1 dùng "-", cấp 2 "+".
\setlist[itemize,1]{label=-}
\setlist[itemize,2]{label=+}

\setlength{\parindent}{1.27cm}
\setlength{\parskip}{0pt}
\setlength{\emergencystretch}{3em}   % tiếng Việt không ngắt từ -> cần nới cứu
\tolerance=2000
\hbadness=2000                        % bớt cảnh báo underfull vô hại
\widowpenalty=10000                   % cấm dòng lạc đầu trang
\clubpenalty=10000                    % cấm dòng lạc cuối trang
\raggedbottom                         % không kéo giãn khoảng trắng dọc trang

% =========================================================
% V. BẢNG MÀU
% Nguyên tắc: chữ đen tuyền để in rõ. Màu CHỈ dùng cho liên kết,
% mã nguồn, đường kẻ mảnh và viền hộp — không tô màu tiêu đề.
% =========================================================
\definecolor{dtmfBlue}{RGB}{21,78,115}
\definecolor{dtmfAmber}{RGB}{160,82,24}
\definecolor{dtmfRule}{RGB}{170,182,190}
\definecolor{dtmfBoxBg}{RGB}{243,247,250}
\definecolor{dtmfGray}{RGB}{95,105,112}
\definecolor{codeBg}{RGB}{250,250,251}
\definecolor{codeComment}{RGB}{38,115,66}
\definecolor{codeKey}{RGB}{20,72,150}
\definecolor{codeStr}{RGB}{158,52,36}
\definecolor{codeNum}{RGB}{140,148,155}

% =========================================================
% VI. TIÊU ĐỀ
% Cấp 1 (Chương): 16pt đậm, IN HOA, căn giữa ("CHƯƠNG 1. CƠ SỞ LÝ THUYẾT"),
%                 bắt đầu trang mới. Mục không đánh số (Mở đầu, Danh mục,
%                 Tài liệu tham khảo) và Phụ lục dùng cùng kiểu.
% Cấp 2 (Mục)   : 13pt đậm, thụt 1,27cm, đánh số 1.1.
% Cấp 3 (Mục con): 13pt đậm nghiêng, thụt 1,27cm, đánh số 1.1.1.
% Tất cả màu đen. Chương đánh số Ả Rập để khớp với mục, hình, bảng và công
% thức (1.1, Hình 1.1, Bảng 1.1, (1.1)); \ref{} tới chương in ra "Chương 4".
% =========================================================
\newcommand{\dtmfchaptername}{CHƯƠNG}
\renewcommand{\thesection}{\arabic{section}}
\renewcommand{\thesubsection}{\thesection.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\thesubsection.\arabic{subsubsection}}

\newcommand{\dtmfheadingfont}{\normalfont\fontsize{16}{22}\bfseries}

\titleformat{\section}
  {\dtmfheadingfont\filcenter}
  {\dtmfchaptername~\thesection.}
  {0.5em}
  {\MakeUppercase}

% Mục và mục con cùng cỡ chữ thân (13pt), phân biệt bằng kiểu chữ
\titleformat{\subsection}
  {\normalfont\normalsize\bfseries}
  {\thesubsection}{0.6em}{}

\titleformat{\subsubsection}
  {\normalfont\normalsize\bfseries\itshape}
  {\thesubsubsection}{0.6em}{}

\titlespacing{\section}      {0pt}{0pt}{22pt}
% Tiêu đề mục (1.1) và mục con (1.1.1) thụt vào 1,27cm như dòng đầu đoạn
\titlespacing{\subsection}   {1.27cm}{18pt plus 3pt minus 2pt}{9pt}
\titlespacing{\subsubsection}{1.27cm}{13pt plus 2pt minus 1pt}{6pt}

% Đoạn đầu tiên ngay sau tiêu đề cũng thụt vào cho đều
\RequirePackage{indentfirst}

% =========================================================
% VII. HÌNH, BẢNG, CÔNG THỨC
% Đánh số theo chương: Hình 2.1 · Bảng 3.2 · công thức (2.5)
% =========================================================
\counterwithin{figure}{section}
\counterwithin{table}{section}
\counterwithin{equation}{section}
\renewcommand{\thefigure}{\arabic{section}.\arabic{figure}}
\renewcommand{\thetable}{\arabic{section}.\arabic{table}}
\renewcommand{\theequation}{\arabic{section}.\arabic{equation}}

\captionsetup{
  font={small},
  labelfont=bf,
  labelsep=period,
  justification=centering,
  singlelinecheck=true,
  skip=8pt
}
\captionsetup[figure]{name=Hình, position=below}
\captionsetup[table]{name=Bảng, position=above}

% Bảng dùng dòng đơn (1,15 x cỡ chữ), nên đệm hàng lớn hơn để hàng thoáng
\renewcommand{\arraystretch}{1.6}
\setlength{\tabcolsep}{8pt}
\setlength{\aboverulesep}{0.5ex}
\setlength{\belowrulesep}{0.6ex}
\setlength{\heavyrulewidth}{0.9pt}
\setlength{\lightrulewidth}{0.5pt}

\setlength{\abovedisplayskip}{11pt plus 2pt minus 2pt}
\setlength{\belowdisplayskip}{11pt plus 2pt minus 2pt}
\setlength{\abovedisplayshortskip}{6pt plus 2pt}
\setlength{\belowdisplayshortskip}{8pt plus 2pt minus 2pt}

\setlength{\textfloatsep}{16pt plus 3pt minus 3pt}
\setlength{\intextsep}{14pt plus 3pt minus 3pt}

% Nới giới hạn đặt hình/bảng: tham số mặc định của LaTeX hay đẩy một hình
% hoặc bảng lớn ra trang riêng, để lại nhiều khoảng trắng.
\renewcommand{\topfraction}{0.85}
\renewcommand{\bottomfraction}{0.7}
\renewcommand{\textfraction}{0.12}
\renewcommand{\floatpagefraction}{0.75}
\setcounter{topnumber}{3}
\setcounter{bottomnumber}{2}
\setcounter{totalnumber}{4}

% Kiểu ô tiêu đề bảng dùng chung
\newcommand{\thd}[1]{\textbf{#1}}

% =========================================================
% VIII. MỤC LỤC & DANH MỤC
% =========================================================
\renewcommand{\cfttoctitlefont}{\hfill\dtmfheadingfont}
\renewcommand{\cftaftertoctitle}{\hfill}
\renewcommand{\cftloftitlefont}{\hfill\dtmfheadingfont}
\renewcommand{\cftafterloftitle}{\hfill}
\renewcommand{\cftlottitlefont}{\hfill\dtmfheadingfont}
\renewcommand{\cftafterlottitle}{\hfill}
\RequirePackage{etoolbox}
\AfterEndPreamble{%
  \renewcommand{\contentsname}{MỤC LỤC}%
  \renewcommand{\listfigurename}{DANH MỤC HÌNH VẼ}%
  \renewcommand{\listtablename}{DANH MỤC BẢNG BIỂU}%
  \setlength{\parindent}{1.27cm}%   % chốt lại sau khi babel/polyglossia nạp xong
  \setlength{\parskip}{0pt}%
}
\setlength{\cftbeforetoctitleskip}{0pt}
\setlength{\cftaftertoctitleskip}{22pt}
\setlength{\cftbeforeloftitleskip}{0pt}
\setlength{\cftafterloftitleskip}{22pt}
\setlength{\cftbeforelottitleskip}{0pt}
\setlength{\cftafterlottitleskip}{22pt}

\renewcommand{\cftsecfont}{\bfseries}
\renewcommand{\cftsecpagefont}{\bfseries}
\renewcommand{\cftsecleader}{\bfseries\cftdotfill{\cftdotsep}}
% Mục cấp 1 trong mục lục: "CHƯƠNG 1. Tên chương". Tiền tố đọc
% \dtmfchaptername lúc in mục lục, nên phần phụ lục ghi lệnh đổi tên vào
% file .toc (xem \batdauphuluc).
\renewcommand{\cftsecpresnum}{\dtmfchaptername~}
\renewcommand{\cftsecaftersnum}{.}
\setlength{\cftbeforesecskip}{9pt}
\setlength{\cftbeforesubsecskip}{4pt}
\setlength{\cftsecnumwidth}{7.2em}
\setlength{\cftsubsecnumwidth}{3.0em}
\setlength{\cftsubsubsecnumwidth}{3.8em}
\setlength{\cftsubsecindent}{1.5em}
\setlength{\cftsubsubsecindent}{4.5em}
\renewcommand{\cftfigpresnum}{Hình }
\renewcommand{\cfttabpresnum}{Bảng }
\setlength{\cftfignumwidth}{4.6em}
\setlength{\cfttabnumwidth}{4.6em}
\setlength{\cftbeforefigskip}{4pt}
\setlength{\cftbeforetabskip}{4pt}

% =========================================================
% IX. ĐẦU TRANG / CHÂN TRANG
% Số trang đặt giữa chân trang — cách trình bày phổ biến và an toàn nhất
% cho báo cáo khoa học tiếng Việt. Không dùng đầu trang để trang sạch.
% =========================================================
% Cờ in số trang: kiểm tra lúc xuất trang, nên các trang mà LaTeX tự đặt kiểu
% plain (mục lục, danh mục) cũng tuân theo.
\newif\ifdtmfsotrang \dtmfsotrangtrue
\newcommand{\dtmf@chantrang}{\ifdtmfsotrang\small\thepage\fi}

\pagestyle{fancy}
\fancyhf{}
\fancyfoot[C]{\dtmf@chantrang}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}

\fancypagestyle{plain}{%
  \fancyhf{}\fancyfoot[C]{\dtmf@chantrang}%
  \renewcommand{\headrulewidth}{0pt}}

% Chỉ phần thân (Chương 1 đến chương cuối) in số trang, bắt đầu từ 1.
% \tatsotrang: từ trang sau trở đi không in số trang, và các mục tương ứng
%              trong mục lục / danh mục cũng không ghi số trang.
% \batsotrang: bắt đầu đánh số Ả Rập từ 1 và in số trang.
\newcommand{\dtmf@tocpnum}[1]{%
  \addtocontents{toc}{\protect\csname cftpagenumbers#1\endcsname{section}%
    \protect\csname cftpagenumbers#1\endcsname{subsection}%
    \protect\csname cftpagenumbers#1\endcsname{subsubsection}}%
  \addtocontents{lof}{\protect\csname cftpagenumbers#1\endcsname{fig}}%
  \addtocontents{lot}{\protect\csname cftpagenumbers#1\endcsname{tab}}}
\newcommand{\tatsotrang}{%
  \clearpage
  \dtmfsotrangfalse
  \dtmf@tocpnum{off}}
\newcommand{\batsotrang}{%
  \clearpage
  \pagenumbering{arabic}%
  \dtmfsotrangtrue
  \dtmf@tocpnum{on}}

% =========================================================
% X. LIÊN KẾT
% =========================================================
\RequirePackage{hyperref}
\hypersetup{
  colorlinks=true,
  linkcolor=black,
  citecolor=black,
  filecolor=dtmfBlue,
  urlcolor=dtmfBlue,
  pdfborder={0 0 0},
  bookmarksnumbered=true,
  pdftitle={Bao cao ky thuat - He thong phat va giai ma tin hieu DTMF},
  pdfsubject={Bai tap lon Xu ly tin hieu so - Chu de 4}
}

% =========================================================
% XI. MÃ NGUỒN MATLAB
% =========================================================
\RequirePackage{listings}
\IfFileExists{tvietlistings.sty}{\RequirePackage{tvietlistings}}{}
\RequirePackage[most]{tcolorbox}
\tcbuselibrary{listings,skins,breakable}

\lstdefinestyle{matlabstyle}{
  language=Matlab,
  basicstyle=\setstretch{1}\ttfamily\fontsize{10}{13}\selectfont,
  commentstyle=\color{codeComment}\itshape,
  % Comment dòng được dàn như văn bản LaTeX: listings xử lý ký tự Unicode ngoài
  % bảng 8 bit không theo thứ tự (dưới XeLaTeX "kỳ vọng" in thành "ỳk ọvng").
  % Hệ quả: ký tự đặc biệt trong comment phải thoát như trong văn bản (\_, \%).
  texcl=true,
  keywordstyle=\color{codeKey}\bfseries,
  stringstyle=\color{codeStr},
  numbers=left,
  numberstyle=\ttfamily\fontsize{8.5}{11}\selectfont\color{codeNum},
  numbersep=10pt,
  breaklines=true,
  breakatwhitespace=false,
  showstringspaces=false,
  keepspaces=true,
  tabsize=4,
  columns=fullflexible,
  aboveskip=12pt,
  belowskip=12pt,
  frame=none,
  captionpos=b
}
\lstset{style=matlabstyle}

\newtcblisting{matlabbox}[1][]{%
  enhanced, breakable,
  listing engine=listings, listing only,
  colback=codeBg, colframe=dtmfBlue!85,
  coltitle=white, colbacktitle=dtmfBlue!85,
  title={\strut#1}, fonttitle=\bfseries\sffamily\fontsize{10.5}{13}\selectfont,
  left=5pt, right=5pt, top=6pt, bottom=6pt,
  toptitle=2pt, bottomtitle=2pt,
  arc=1.5mm, boxrule=0.6pt,
  listing options={style=matlabstyle, aboveskip=0pt, belowskip=0pt,
                   xleftmargin=1.9em, framexleftmargin=1.9em}
}

% Cây thư mục kiểu lệnh `tree`, lời chú thích viết như comment MATLAB.
% Font đơn cách của báo cáo (TeX Gyre Cursor/Consolas) không có ký tự vẽ khung
% ├ └ │, còn DejaVu Sans Mono (đi kèm bản phân phối TeX) có nét vẽ khung nhưng
% thiếu dấu tiếng Việt. Vì vậy chỉ nét vẽ cây lấy từ DejaVu; tên thư mục và lời
% chú thích vẫn dùng \ttfamily. Mọi tiền tố đều cùng font nên cây vẫn thẳng cột.
% pdfLaTeX không dùng được font Unicode -> lùi về nét ASCII |-- `--.
\ifPDFTeX
  \newcommand{\TRglyph}[1]{#1}
  \newcommand{\TRmid}{|-{}-\ }
  \newcommand{\TRend}{`-{}-\ }
  \newcommand{\TRbar}{|\ \ \ }
\else
  \newfontfamily\TRglyphfont{DejaVuSansMono}[Extension=.ttf, Scale=0.9]
  \newcommand{\TRglyph}[1]{{\TRglyphfont#1}}
  \newcommand{\TRmid}{\TRglyph{├──\ }}
  \newcommand{\TRend}{\TRglyph{└──\ }}
  \newcommand{\TRbar}{\TRglyph{│\ \ \ }}
\fi
\newcommand{\TRc}[1]{{\color{codeComment}\itshape\%\ #1}}
% Nội dung gom vào lrbox rồi đóng khung bằng \tcbox: khung ôm sát nội dung và
% \centering của figure đặt nó giữa trang.
% Dãn dòng đơn và khoảng cách dòng sát chiều cao nét │ để nét dọc liền mạch.
\newsavebox{\dirtreebin}
\newenvironment{dirtreebox}{%
  \begin{lrbox}{\dirtreebin}%
  \setstretch{1}\renewcommand{\arraystretch}{1}%
  \ttfamily\fontsize{10}{11.6}\selectfont
  \begin{tabular}{@{}l@{\hspace{2.5em}}l@{}}}{%
  \end{tabular}\end{lrbox}%
  \tcbox[enhanced, colback=codeBg, colframe=dtmfBlue!85, arc=1.5mm,
    boxrule=0.6pt, left=12pt, right=12pt, top=8pt, bottom=8pt]{%
    \usebox{\dirtreebin}}}

\lstdefinestyle{outputstyle}{
  basicstyle=\setstretch{1}\ttfamily\fontsize{10}{13}\selectfont,
  breaklines=true, keepspaces=true, showstringspaces=false,
  columns=fullflexible, numbers=none
}
\newtcblisting{outputbox}[1][Kết quả chạy]{%
  enhanced, breakable,
  listing engine=listings, listing only,
  colback=white, colframe=dtmfGray,
  coltitle=white, colbacktitle=dtmfGray,
  title={\strut#1}, fonttitle=\bfseries\sffamily\fontsize{10.5}{13}\selectfont,
  left=5pt, right=5pt, top=6pt, bottom=6pt,
  toptitle=2pt, bottomtitle=2pt,
  arc=1.5mm, boxrule=0.5pt,
  listing options={style=outputstyle, aboveskip=0pt, belowskip=0pt}
}

% =========================================================
% XII. HỘP GHI CHÚ
% =========================================================
\newtcolorbox{notebox}[1][Ghi chú]{enhanced, breakable,
  colback=dtmfBoxBg, colframe=dtmfBlue!80,
  fonttitle=\bfseries\sffamily\small, title={\strut#1},
  fontupper=\small,
  boxrule=0.6pt, arc=1.5mm,
  left=6pt, right=6pt, top=5pt, bottom=5pt,
  toptitle=2pt, bottomtitle=2pt,
  before skip=12pt, after skip=12pt}

\newtcolorbox{warnbox}[1][Lưu ý]{enhanced, breakable,
  colback=dtmfAmber!6, colframe=dtmfAmber,
  fonttitle=\bfseries\sffamily\small, title={\strut#1},
  fontupper=\small,
  boxrule=0.6pt, arc=1.5mm,
  left=6pt, right=6pt, top=5pt, bottom=5pt,
  toptitle=2pt, bottomtitle=2pt,
  before skip=12pt, after skip=12pt}

\newtcolorbox{summarybox}{enhanced, breakable,
  colback=dtmfBoxBg, colframe=dtmfRule,
  fontupper=\small,
  boxrule=0.5pt, arc=1.5mm,
  left=8pt, right=8pt, top=6pt, bottom=6pt,
  before skip=12pt, after skip=12pt}

% Ô giữ chỗ cho hình chưa có — xoá hết trước khi nộp
\newcommand{\chohinh}[2][0.72]{%
  \begin{figure}[H]\centering
  \fcolorbox{dtmfRule}{dtmfBoxBg}{%
    \parbox[c][3.4cm][c]{#1\linewidth}{\centering\small\itshape
    \color{dtmfGray}[ chỗ đặt hình: #2 ]}}
  \end{figure}}

% =========================================================
% XIII. MỤC KHÔNG ĐÁNH SỐ
% Dùng cho Mở đầu, Danh mục từ viết tắt, Tài liệu tham khảo.
% Trình bày giống tiêu đề chương nhưng không có số.
% =========================================================
\newcommand{\unsection}[1]{%
  \clearpage
  \phantomsection
  \addcontentsline{toc}{section}{\MakeUppercase{#1}}%
  {\centering\dtmfheadingfont\MakeUppercase{#1}\par}
  \nobreak\vspace{22pt}
  \@afterindenttrue\@afterheading}

% Danh mục hình / bảng: thêm vào mục lục rồi in danh mục
\newcommand{\danhmuchinh}{%
  \clearpage\phantomsection
  \addcontentsline{toc}{section}{\listfigurename}%
  \listoffigures}
\newcommand{\danhmucbang}{%
  \clearpage\phantomsection
  \addcontentsline{toc}{section}{\listtablename}%
  \listoftables}

% Bắt đầu phần phụ lục: mỗi phụ lục trình bày như một chương, nhãn
% "PHỤ LỤC 1.", hình và bảng đánh số riêng PL1.1 để không trùng chương chính.
\newcommand{\batdauphuluc}{%
  \clearpage
  \setcounter{section}{0}%
  \renewcommand{\dtmfchaptername}{PHỤ LỤC}%
  \addtocontents{toc}{\protect\renewcommand{\protect\dtmfchaptername}{PHỤ LỤC}}%
  \addtocontents{lof}{\protect\addtolength{\protect\cftfignumwidth}{1.6em}}%
  \addtocontents{lot}{\protect\addtolength{\protect\cfttabnumwidth}{1.6em}}%
  \renewcommand{\thefigure}{PL\arabic{section}.\arabic{figure}}%
  \renewcommand{\thetable}{PL\arabic{section}.\arabic{table}}%
  \renewcommand{\theequation}{PL\arabic{section}.\arabic{equation}}}

% Mục con của phần không đánh số (Mở đầu): không đưa vào mục lục
\newcommand{\unsubsection}[1]{%
  \par\vspace{16pt}
  {\noindent\hspace*{1.27cm}\normalsize\bfseries #1\par}
  \nobreak\vspace{8pt}}

% Mục lục chỉ liệt kê đến cấp 2 (1.1); mục cấp 3 (1.1.1) vẫn đánh số trong bài
\setcounter{tocdepth}{2}

% =========================================================
% XIV. TRANG BÌA (không dùng logo)
% =========================================================
\newcommand{\truong}{TÊN TRƯỜNG}
\newcommand{\khoa}{TÊN KHOA}
\newcommand{\hocphan}{XỬ LÝ TÍN HIỆU SỐ}
\newcommand{\detai}{Tên đề tài}
\newcommand{\nhom}{Nhóm}
\newcommand{\giangvien}{Tên giảng viên}
\newcommand{\diadiem}{Địa điểm}
\newcommand{\thoigian}{Tháng 10, 2026}
\newcommand{\thanhvienlist}{}

\newcommand{\settruong}[1]{\renewcommand{\truong}{#1}}
\newcommand{\setkhoa}[1]{\renewcommand{\khoa}{#1}}
\newcommand{\sethocphan}[1]{\renewcommand{\hocphan}{#1}}
\newcommand{\setdetai}[1]{\renewcommand{\detai}{#1}}
\newcommand{\setnhom}[1]{\renewcommand{\nhom}{#1}}
\newcommand{\setgiangvien}[1]{\renewcommand{\giangvien}{#1}}
\newcommand{\setdiadiem}[1]{\renewcommand{\diadiem}{#1}}
\newcommand{\setthoigian}[1]{\renewcommand{\thoigian}{#1}}
\newcommand{\setthanhvien}[1]{\renewcommand{\thanhvienlist}{#1}}

\newcommand{\trangbia}{%
  \begin{titlepage}
  \thispagestyle{empty}
  % Khung bìa viền đôi, cách mép giấy tương ứng với lề trang
  \begin{tikzpicture}[remember picture, overlay]
    \draw[line width=1.6pt]
      ([xshift=2.2cm, yshift=-1.3cm]current page.north west) rectangle
      ([xshift=-1.3cm, yshift=1.3cm]current page.south east);
    \draw[line width=0.5pt]
      ([xshift=2.32cm, yshift=-1.42cm]current page.north west) rectangle
      ([xshift=-1.42cm, yshift=1.42cm]current page.south east);
  \end{tikzpicture}%
  \setlength{\parindent}{0pt}
  \centering
  \setstretch{1.1}

  {\fontsize{14}{18}\selectfont\bfseries\MakeUppercase{\truong}\par}
  \vspace{2pt}
  {\fontsize{12.5}{16}\selectfont\MakeUppercase{\khoa}\par}
  \vspace{8pt}
  {\color{dtmfRule}\rule{0.26\linewidth}{0.8pt}}

  \vspace{\stretch{2}}

  {\fontsize{15}{20}\selectfont\bfseries BÁO CÁO BÀI TẬP LỚN\par}
  \vspace{6pt}
  {\fontsize{12.5}{17}\selectfont HỌC PHẦN: \textbf{\MakeUppercase{\hocphan}}\par}

  \vspace{\stretch{1.4}}

  {\color{dtmfBlue}\rule{0.92\linewidth}{1.1pt}}\par
  \vspace{14pt}
  {\fontsize{18}{26}\selectfont\bfseries\MakeUppercase{\detai}\par}
  \vspace{14pt}
  {\color{dtmfBlue}\rule{0.92\linewidth}{1.1pt}}\par

  \vspace{\stretch{1.6}}

  {\fontsize{13}{17}\selectfont\bfseries\MakeUppercase{\nhom}\par}
  \vspace{9pt}
  {\fontsize{11}{14}\selectfont\thanhvienlist\par}

  \vspace{\stretch{1.8}}

  {\fontsize{12.5}{17}\selectfont Giảng viên hướng dẫn:~\textbf{\giangvien}\par}
  \vspace{16pt}
  {\fontsize{12.5}{17}\selectfont\diadiem\ --\ \thoigian\par}
  \vspace{6pt}
  \end{titlepage}
  \clearpage}

% =========================================================
% XV. TÀI LIỆU THAM KHẢO
% Dùng biblatex nếu có; nếu máy thiếu thì tự lùi về thebibliography
% để báo cáo vẫn biên dịch được.
% =========================================================
\newif\ifdtmfbiblatex
\IfFileExists{biblatex.sty}{\dtmfbiblatextrue}{\dtmfbiblatexfalse}
\ifdtmfbiblatex
  \RequirePackage[backend=biber, style=ieee, maxnames=3, minnames=1,
                  uniquelist=false, hyperref=false]{biblatex}
  \DefineBibliographyStrings{english}{andothers={et\addabbrvspace al\adddot}}
  % Căn trái: URL dài không bị kéo giãn thành "https : / / www"
  \AtBeginBibliography{\small\RaggedRight}
\else
  \newcommand{\addbibresource}[1]{}
  \newcommand{\printbibliography}[1][]{%
    \textit{[Thiếu gói biblatex: danh mục tài liệu tham khảo chưa hiển thị.]}}
\fi


% =========================================================
% XVI. KÝ HIỆU TOÁN DÙNG CHUNG
% Khoá tại đây — cả nhóm gõ lệnh, không ai tự viết ký hiệu riêng.
% =========================================================
\DeclareMathOperator*{\argmax}{arg\,max}
\DeclareMathOperator*{\argmin}{arg\,min}
\newcommand{\fs}{f_{s}}
\newcommand{\dB}{\,\mathrm{dB}}
\newcommand{\Xk}{X[k]}
\newcommand{\Htf}{H(z)}
\newcommand{\Hfreq}{H(e^{j\omega})}
\newcommand{\dfres}{\Delta f}
\newcommand{\wzero}{\omega_{0}}
\newcommand{\Qfac}{Q}
\newcommand{\SNRdB}{\mathrm{SNR}_{\mathrm{dB}}}
