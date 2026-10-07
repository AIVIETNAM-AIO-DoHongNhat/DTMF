function h = ui_pad(varargin)
%UI_PAD Bàn phím DTMF phẳng kiểu điện thoại: phím xám bo góc, một màu nhấn cho phím đang sáng
% Dùng chung cho DTMFApp (bàn phím bấm được) và DTMFLive (bàn phím sáng đèn)
%   H = UI_PAD(AX, COCAU) dựng bàn phím lên uiaxes AX một lần và trả về các
%   đối tượng đồ họa: 12 phím bo góc tách rời, cột tần số hàng bên trái,
%   hàng tần số cột bên trên, chữ 'Hz' ở góc. COCAU = true chừa một dòng dưới
%   bàn phím cho H.cau (DTMFLive ghi cặp tần số vào đó).
%   UI_PAD(H, G, A, B) tô bàn phím: G (1×12, theo thứ tự 1 2 3 ... * 0 #) là
%   mức sáng của phím, A (1×4) của tone hàng, B (1×3) của tone cột, mỗi mức
%   trong [0, 1]. Phím pha từ xám nhạt sang màu nhấn (chàm); tần số pha từ
%   nền trắng sang viên thuốc chàm rất nhạt, chữ chuyển sang màu nhấn.
%   UI_PAD(H, 'co') đặt lại bố cục và cỡ chữ theo kích thước hiện tại của
%   panel chứa AX - gọi trong SizeChangedFcn của panel đó.
%
%   Phong cách: phẳng, không viền, không bóng, chữ không chân (M.font). Chỉ
%   MỘT màu nhấn như phần còn lại của giao diện (ui_theme); cặp cam/xanh của
%   nhóm hàng/cột để dành cho các hình, không dùng trên bàn phím.
%
%   Các bước hoạt động:
%       1. Tọa độ dữ liệu giữ cố định: tâm phím hàng r, cột c nằm ở (c, r),
%          bước phím là 1 theo cả hai chiều. Bấm chuột chỉ cần làm tròn
%          IntersectionPoint là ra hàng, cột (DTMFApp.AxKeypadClicked).
%       2. Bố cục tính bằng pixel rồi đổi sang tọa độ đó: phím được rộng hơn
%          cao (tới 1,6 lần) để lấp ô hẹp mà dài của DTMFApp, bo góc và khe
%          giữa các phím giữ đúng số pixel ở mọi cỡ cửa sổ. Trục không giữ tỉ
%          lệ 1:1 mà kéo XLim, YLim cho khớp bố cục.
%       3. Phím là MỘT patch 12 mặt, nhãn tần số là MỘT patch 7 mặt: tô cả
%          bàn phím chỉ bằng hai lần gán FaceVertexCData.
%       4. Chữ cỡ theo pixel, không bắt chuột: bấm vào chữ số vẫn rơi xuống
%          phím bên dưới (H.pad).
%       5. Lúc tô, màu chữ chỉ được gán khi thật sự đổi - bàn phím của
%          DTMFLive được tô lại mười lần mỗi giây.
%
%   Input:
%       AX: uiaxes trống, nằm một mình trong một uipanel. COCAU: logical,
%       mặc định false.
%       H, G, A, B: xem trên.
%
%   Output:
%       H: struct .pad (patch 12 phím, để gắn ButtonDownFcn), .nhan (patch
%          nền 7 tần số), .chu (19 text: 12 phím, 4 tần số hàng, 3 tần số
%          cột), .chuHz, .cau, .ax.
%
%   Example:
%       f = uifigure; p = uipanel(f, 'Position', [20 20 300 220]);
%       h = ui_pad(uiaxes(p), false);
%       ui_pad(h, [zeros(1, 7) 1 zeros(1, 4)], [0 0 1 0], [0 1 0]);   % phím 8

if isstruct(varargin{1}) && nargin == 2
    co(varargin{1});
    h = varargin{1};
elseif isstruct(varargin{1})
    to(varargin{:});
    h = varargin{1};
else
    h = dung(varargin{:});
end
end

function h = dung(ax, coCau)
if nargin < 2
    coCau = false;
end
M = ui_theme();
T = dtmf_table();
K = mau(M);

cla(ax);
hold(ax, 'on');
khong = {'HitTest', 'off', 'PickableParts', 'none'};

% Bước 3. Phím vẽ trước, nhãn tần số sau; cả hai phẳng, không viền.
[v, f] = oBo(zeros(12, 4), 0, 0);
h.pad = patch(ax, 'Vertices', v, 'Faces', f, ...
    'FaceVertexCData', repmat(K.phim, 12, 1), 'FaceColor', 'flat', 'EdgeColor', 'none');
[v, f] = oBo(zeros(7, 4), 0, 0);
h.nhan = patch(ax, 'Vertices', v, 'Faces', f, ...
    'FaceVertexCData', repmat(M.the, 7, 1), 'FaceColor', 'flat', 'EdgeColor', 'none', khong{:});

% Bước 4.
chu = {'FontName', K.font, 'Interpreter', 'none', 'FontUnits', 'pixels', ...
       'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', khong{:}};
h.chu = gobjects(1, 19);
k = 0;
for r = 1:4
    for c = 1:3
        k = k + 1;
        h.chu(k) = text(ax, c, r, kyHien(T.keys(r, c)), 'Color', M.muc, chu{:});
    end
end
for r = 1:4
    k = k + 1;
    h.chu(k) = text(ax, 0, r, sprintf('%d', T.rowHz(r)), 'Color', K.nhanChu, chu{:});
end
for c = 1:3
    k = k + 1;
    h.chu(k) = text(ax, c, 0, sprintf('%d', T.colHz(c)), 'Color', K.nhanChu, chu{:});
end
h.chuHz = text(ax, 0, 0, 'Hz', 'Color', M.chuMo, chu{:});
h.cau = text(ax, 2, 5, '', 'Color', M.nhan, chu{:});
hold(ax, 'off');

ax.YDir = 'reverse';
ax.Color = 'none';
ax.Visible = 'off';
ax.Toolbar.Visible = 'off';
ax.Clipping = 'off';
disableDefaultInteractivity(ax);

h.ax = ax;
h.coCau = coCau;
h.mauChu  = [repmat(M.muc, 12, 1); repmat(K.nhanChu, 7, 1)];
h.mauSang = [repmat(M.the, 12, 1); repmat(M.nhan, 7, 1)];
co(h);
end

function co(h)
%CO Bước 1 và 2: bố cục theo kích thước pixel hiện tại của panel chứa trục.
ax = h.ax;
q = getpixelposition(ax.Parent);
W = max(q(3), 40);
H = max(q(4), 40);
ax.Units = 'pixels';
ax.InnerPosition = [0 0 W H];

% Bước phím dọc py lấy từ chiều cao: 4 hàng phím + hàng nhãn cột (0,6 py)
% + dòng chú thích (0,62 py) nếu có. Cột nhãn hàng rộng 0,95 py. Phím rộng
% hơn cao nhưng không quá 1,6 lần.
cau = 0.62 * h.coCau;
py = min(H / (4 + 0.6 + cau), W / (3 + 0.95));
px = min((W - 0.95 * py) / 3, 1.6 * py);
hr = 0.6 * py;
hc = 0.95 * py;
khe = max(5, round(0.13 * py));          % khe giữa hai phím [px]
bo  = min(12, 0.28 * (py - khe));        % bán kính bo góc [px]

% Khối bàn phím canh giữa panel; (xL, yT) là góc trên trái của khối.
rong = hc + 3 * px;
cao  = hr + 4 * py + cau * py;
xL = (W - rong) / 2;
yT = (H - cao) / 2;
ax.XLim = ([0 W] - xL - hc) / px + 0.5;
ax.YLim = ([0 H] - yT - hr) / py + 0.5;

sx = 1 / px;  sy = 1 / py;               % 1 pixel tính theo đơn vị dữ liệu
xN = 0.5 - hc / 2 * sx;                  % tâm cột nhãn hàng
yN = 0.5 - hr / 2 * sy;                  % tâm hàng nhãn cột

% Phím: hình chữ nhật [trái phải trên dưới] quanh tâm (c, r).
[cc, rr] = meshgrid(1:3, 1:4);
cc = reshape(cc', [], 1);
rr = reshape(rr', [], 1);
nx = (1 - khe * sx) / 2;
ny = (1 - khe * sy) / 2;
[v, ~] = oBo([cc - nx, cc + nx, rr - ny, rr + ny], bo * sx, bo * sy);
set(h.pad, 'Vertices', v);

% Nhãn tần số: viên thuốc thấp quanh chữ, thẳng hàng với phím; chỉ hiện
% (nền chàm rất nhạt) khi tone đó đang kêu.
mx = (hc - khe) / 2 * sx;
my = (hr - khe) / 2 * sy;
dx = 0.5 * (px - khe) / 2 * sx;          % nửa rộng viên thuốc của tần số cột
dy = 0.42 * (py - khe) / 2 * sy;         % nửa cao viên thuốc của tần số hàng
o = [repmat([xN - mx, xN + mx], 4, 1), (1:4)' - dy, (1:4)' + dy
     (1:3)' - dx, (1:3)' + dx, repmat([yN - my, yN + my], 3, 1)];
rv = min([mx / sx, dy / sy, my / sy, dx / sx]);     % bo tròn hẳn hai đầu [px]
[v, ~] = oBo(o, rv * sx, rv * sy);
set(h.nhan, 'Vertices', v);

% Chữ: chữ số theo chiều cao phím, tần số theo chiều cao hàng nhãn.
coSo = min(0.46 * (py - khe), 0.36 * (px - khe));
coHz = min(0.5 * (hr - khe) + 2, 0.3 * (hc - khe) + 2);
for k = 1:12
    h.chu(k).FontSize = max(coSo, 4);
end
h.chu(10).FontSize = max(1.5 * coSo, 4);         % dấu sao mượn phông khác, nhỏ hơn chữ số
for k = 13:16
    h.chu(k).Position(1) = xN;
    h.chu(k).FontSize = max(coHz, 4);
end
for k = 17:19
    h.chu(k).Position(2) = yN;
    h.chu(k).FontSize = max(coHz, 4);
end
set(h.chuHz, 'Position', [xN yN 0], 'FontSize', max(0.85 * coHz, 4));
set(h.cau, 'Position', [(xN - mx + 3 + nx) / 2, 4.5 + cau / 2 + 0.04, 0], ...
    'FontSize', max(coHz + 2, 4));
end

function to(h, g, a, b)
M = ui_theme();
K = mau(M);
g = max(0, min(1, g(:)));
ab = max(0, min(1, [a(:); b(:)]));
set(h.pad, 'FaceVertexCData', tron(K.phim, M.nhan, g));
set(h.nhan, 'FaceVertexCData', tron(M.the, M.nhanNhat, ab));
% Bước 5.
muc = [g; ab];
for k = 1:numel(h.chu)
    mauK = h.mauChu(k, :);
    if muc(k) > 0.5
        mauK = h.mauSang(k, :);
    end
    if ~isequal(h.chu(k).Color, mauK)
        h.chu(k).Color = mauK;
    end
end
end

function K = mau(M)
%MAU Màu và phông riêng của bàn phím, lấy từ ui_theme: phím xám rất nhạt
% trên nền trắng, nhãn tần số xám; chỉ MỘT màu nhấn (chàm) cho phím đang
% sáng và hai tần số của nó.
K.phim    = M.phimPhu;
K.nhanChu = M.chuPhu;
K.font    = M.font;
end

function [v, f] = oBo(o, rx, ry)
%OBO Vertices và Faces của các hình chữ nhật bo góc; mỗi hàng của O là
% [trái phải trên dưới], RX, RY là bán kính bo theo hai trục (đơn vị dữ
% liệu). Mỗi góc 7 điểm, nên mọi mặt cùng 28 đỉnh.
n = size(o, 1);
t = linspace(0, pi / 2, 7)';
cx = [o(:, 2) - rx, o(:, 2) - rx, o(:, 1) + rx, o(:, 1) + rx];  % phải-trên, phải-dưới, trái-dưới, trái-trên
cy = [o(:, 3) + ry, o(:, 4) - ry, o(:, 4) - ry, o(:, 3) + ry];
gx = [ sin(t),  cos(t), -sin(t), -cos(t)];
gy = [-cos(t),  sin(t),  cos(t), -sin(t)];
v = zeros(28 * n, 2);
for i = 1:n
    X = cx(i, :) + rx * gx;
    Y = cy(i, :) + ry * gy;
    v(28 * (i - 1) + (1:28), :) = [X(:), Y(:)];
end
f = reshape(1:28 * n, 28, n)';
end

function s = kyHien(k)
%KYHIEN Ký tự hiện trên phím: dấu sao ASCII nằm cao như chỉ số trên, thay
% bằng dấu sao toán U+2217 nằm giữa dòng như chữ số.
s = k;
if k == '*'
    s = char(8727);
end
end

function C = tron(nen, mau, muc)
%TRON Pha màu: muc = 0 ra màu nền, muc = 1 ra màu đầy; mỗi phần tử muc một hàng.
muc = max(0, min(1, muc(:)));
C = (1 - muc) .* nen + muc .* mau;
end
