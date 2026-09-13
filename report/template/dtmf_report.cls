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
  % Mặc định dùng bộ Liberation (tương thích metric 100% với Times New Roman
  % / Arial / Courier New, có sẵn trên Linux và Overleaf).
  % Máy Windows có font Microsoft thật thì gọi:
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
    \setmainfont{Liberation Serif}
    \setsansfont{Liberation Sans}[Scale=0.92]
    \setmonofont{Liberation Mono}[Scale=0.88]
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
\IfFileExists{dirtree.sty}{\RequirePackage{dirtree}}{%
  % Máy thiếu gói dirtree -> dùng bản thay thế đơn giản để vẫn biên dịch được
  \newcommand{\dirtree}[1]{\begin{quote}\ttfamily\small
    \textit{[Cần gói dirtree để vẽ cây thư mục]}\end{quote}}}

% =========================================================
% III. KHỔ TRANG
% Lề theo quy định trình bày báo cáo khoa học: trái 3cm (chừa đóng gáy),
% phải 2cm, trên và dưới 2,5cm.
% =========================================================
\RequirePackage[a4paper,
  left=3cm, right=2cm, top=2.5cm, bottom=2.5cm,
  footskip=1.1cm, headsep=0.6cm]{geometry}

% =========================================================
% IV. THÂN CHỮ
% 13pt, giãn dòng 1,5, thụt đầu dòng 1,27cm, không giãn cách đoạn.
% Đây là quy cách chuẩn của báo cáo khoa học tiếng Việt.
% =========================================================
\renewcommand{\normalsize}{\fontsize{13}{19.5}\selectfont}
\renewcommand{\small}{\fontsize{12}{18}\selectfont}
\renewcommand{\footnotesize}{\fontsize{11}{16}\selectfont}
\renewcommand{\scriptsize}{\fontsize{10}{12}\selectfont}
\renewcommand{\large}{\fontsize{14}{21}\selectfont}
\renewcommand{\Large}{\fontsize{16}{22}\selectfont}
\renewcommand{\LARGE}{\fontsize{18}{24}\selectfont}
\normalsize

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
% Cấp 1 (Chương): 16pt đậm, IN HOA, căn giữa, mở đầu trang mới, có kẻ mảnh.
% Cấp 2 (Mục)   : 14pt đậm, căn trái.
% Cấp 3 (Mục con): 13pt đậm nghiêng, căn trái.
% Tất cả màu đen.
% =========================================================
\renewcommand{\thesection}{\Roman{section}.}
\renewcommand{\thesubsection}{\arabic{section}.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\arabic{section}.\arabic{subsection}.\arabic{subsubsection}}

\newcommand{\chapterrule}{%
  \par\vspace{2pt}\noindent
  {\color{dtmfRule}\rule{\linewidth}{0.6pt}}\par}

\titleformat{\section}[display]
  {\centering\normalfont\fontsize{16}{22}\bfseries}
  {\fontsize{14}{18}\bfseries\thesection}
  {6pt}
  {\MakeUppercase}
  [\chapterrule]

\titleformat{\subsection}
  {\normalfont\fontsize{14}{20}\bfseries}
  {\thesubsection}{0.6em}{}

\titleformat{\subsubsection}
  {\normalfont\fontsize{13}{19}\bfseries\itshape}
  {\thesubsubsection}{0.6em}{}

\titlespacing{\section}      {0pt}{0pt}{20pt}
\titlespacing{\subsection}   {0pt}{18pt plus 3pt minus 2pt}{9pt}
\titlespacing{\subsubsection}{0pt}{13pt plus 2pt minus 1pt}{6pt}

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

\renewcommand{\arraystretch}{1.3}
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

% Kiểu ô tiêu đề bảng dùng chung
\newcommand{\thd}[1]{\textbf{#1}}

% =========================================================
% VIII. MỤC LỤC & DANH MỤC
% =========================================================
\renewcommand{\cfttoctitlefont}{\hfill\fontsize{16}{22}\bfseries}
\renewcommand{\cftaftertoctitle}{\hfill}
\renewcommand{\cftloftitlefont}{\hfill\fontsize{16}{22}\bfseries}
\renewcommand{\cftafterloftitle}{\hfill}
\renewcommand{\cftlottitlefont}{\hfill\fontsize{16}{22}\bfseries}
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
\setlength{\cftbeforesecskip}{9pt}
\setlength{\cftbeforesubsecskip}{4pt}
\setlength{\cftsecnumwidth}{2.6em}
\setlength{\cftsubsecnumwidth}{3.0em}
\setlength{\cftsubsubsecnumwidth}{3.8em}
\setlength{\cftsubsecindent}{2.6em}
\setlength{\cftsubsubsecindent}{5.6em}
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
\pagestyle{fancy}
\fancyhf{}
\fancyfoot[C]{\small\thepage}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}

\fancypagestyle{plain}{%
  \fancyhf{}\fancyfoot[C]{\small\thepage}%
  \renewcommand{\headrulewidth}{0pt}}

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
  basicstyle=\ttfamily\fontsize{10}{13}\selectfont,
  commentstyle=\color{codeComment}\itshape,
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

\lstdefinestyle{outputstyle}{
  basicstyle=\ttfamily\fontsize{10}{13}\selectfont,
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
  \begin{center}
    {\fontsize{16}{22}\bfseries\MakeUppercase{#1}}
  \end{center}
  \chapterrule
  \vspace{14pt}
  \addcontentsline{toc}{section}{\MakeUppercase{#1}}}

\newcommand{\unsubsection}[1]{%
  \phantomsection
  \par\vspace{16pt}
  {\noindent\fontsize{14}{20}\bfseries #1\par}
  \vspace{8pt}
  \addcontentsline{toc}{subsection}{#1}}

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
  {\fontsize{18}{25}\selectfont\bfseries\detai\par}
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
  \AtBeginBibliography{\small}
\else
  \newcommand{\addbibresource}[1]{}
  \newcommand{\printbibliography}[1][]{%
    \textit{[Thiếu gói biblatex — danh mục tài liệu tham khảo chưa hiển thị.]}}
\fi

\RequirePackage[toc,page]{appendix}
\renewcommand{\appendixtocname}{PHỤ LỤC}
\renewcommand{\appendixpagename}{PHỤ LỤC}

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
