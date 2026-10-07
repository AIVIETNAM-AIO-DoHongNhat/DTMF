function V = ui_live_draw(V, L, nho)
%UI_LIVE_DRAW Vẽ một khung hình của màn tổng đài DTMFLive từ trạng thái giải mã luồng
% Bốn trục và một bàn phím sáng đèn, vẽ lại nhiều lần mỗi giây trong lúc nghe
%   V = UI_LIVE_DRAW(V, L, NHO) vẽ lên năm trục trong V:
%       V.axWave  dạng sóng winSec giây cuối; mép phải là "bây giờ" (t = 0)
%       V.axZoom  32 ms cuối, phóng to để thấy tổng hai sóng sin
%       V.axMap   năng lượng 8 bin theo khung, cùng trục thời gian với axWave
%       V.axBars  8 bin của khung mới nhất kèm phán quyết của dtmf_decide
%       V.axPad   bàn phím 4×3 (ui_pad): tần số hàng, cột sáng theo năng
%                 lượng tone đó, phím sáng màu nhấn khi khung được nhận ra
%                 đúng phím đó. Không bắt buộc: thiếu thì bỏ qua bàn phím.
%   V.tuyetDoi = true (màn giám định DTMFForensic) đổi trục thời gian thành
%   0..winSec tính từ mẫu đầu của L.y, để cả đoạn ghi âm nằm yên trên trục
%   và lớn dần từ trái sang phải thay vì trôi về bên trái.
%
%   Kiểu trình bày theo hình pgfplots trong một bài LaTeX: khung kín, tick
%   hướng vào trong, không lưới, số và ký hiệu đặt bằng bộ diễn dịch latex
%   (phông Computer Modern như công thức của báo cáo). Chữ tiếng Việt không
%   qua latex được - bộ diễn dịch của MATLAB không có dấu tiếng Việt - nên
%   dùng phông chữ thân bài của báo cáo, M.tex.font.
%
%   Các bước hoạt động:
%       1. Lần gọi đầu (V chưa có trường h) dựng mọi đối tượng đồ họa MỘT lần.
%       2. Mọi lần gọi chỉ đổi dữ liệu của đối tượng đã có (XData, CData,
%          FaceVertexCData, String), không cla, không vẽ lại từ đầu: ui_refresh
%          của DTMFApp tốn ~0,4 s một lần vì vẽ lại cả sáu trục, ở đây phải
%          dưới CHU_KY_VE của DTMFLive.
%       3. Dạng sóng thu gọn thành đường bao min/max theo nhóm 40 mẫu (5 ms):
%          vẽ thẳng 24 000 điểm mười lần mỗi giây làm giao diện ì.
%       4. Thang biên độ tăng ngay khi tín hiệu to lên nhưng giảm từ từ, rồi
%          làm tròn lên theo bậc 1/4 quãng tám: trục không giật theo từng phím.
%       5. Giới hạn trục và chữ chỉ được gán khi giá trị THẬT SỰ đổi (datKhac).
%          Gán lại cùng một XLim vẫn bắt uiaxes cập nhật thanh công cụ và
%          tương tác - đo 06/10/2026, đó là phần đắt nhất của mỗi khung hình.
%
%   Hàm này KHÔNG quyết định gì - luật CONTRACTS §2 và §6(h). rowIdx, colIdx,
%   reject của từng khung do dtmf_decide ghi sẵn trong L.info; gom các khung
%   liền nhau cùng phím chỉ để đặt nhãn, như ui_plot_map. Độ sáng bàn phím là
%   E đã chuẩn hóa chia cho 0,45 - mức của một bin được chọn khi tone sạch -
%   tức chỉ là cách tô màu, không phải ngưỡng.
%
%   Input:
%       V: struct năm trục kể trên; trường .h và .A do hàm này quản lý, nên
%          luôn gán lại V bằng giá trị trả về.
%       L: trạng thái của dtmf_listen, hoặc [] khi chưa nghe gì.
%       nho: struct .key (char, phím vừa báo; rỗng nếu chưa có) và .tuoi
%            (giây kể từ lúc báo). Ô của phím đó sáng rồi mờ dần trong MO giây.
%            Hai trường tùy chọn, chỉ dùng khi V.tuyetDoi:
%            .khung: chỉ số khung trong L.info để xem kỹ thay cho khung mới
%                    nhất (tám thanh, trục phóng to, vạch đứt trên bản đồ).
%            .that: struct .t0, .t1 (1×K, giây, cùng trục với L.y), .k (char
%                   1×K) và .dung (logical 1×K) - số thật và lúc bấm từng
%                   phím, vẽ thành làn trên cùng của bản đồ, xanh nếu bộ giải
%                   mã đọc đúng phím đó, đỏ nếu không.
%
%   Example:
%       f = uifigure; g = uigridlayout(f, [1 5]);
%       V = struct('axWave', uiaxes(g), 'axZoom', uiaxes(g), 'axMap', uiaxes(g), ...
%                  'axBars', uiaxes(g), 'axPad', uiaxes(g));
%       L = dtmf_listen(struct('fs', 8000, 'method', 'goertzel'), dtmf_generate('5'));
%       V = ui_live_draw(V, L, struct('key', '5', 'tuoi', 0));

MO = 0.8;          % ô phím vừa báo mờ hẳn sau chừng này giây [s]
SANG = 0.45;       % E của một bin được chọn khi tone sạch - ui_plot_map
NHOM = 40;         % số mẫu mỗi điểm của đường bao (5 ms ở 8 kHz)
NZOOM = 256;       % số mẫu của trục phóng to (32 ms ở 8 kHz)

M = ui_theme();
T = dtmf_table();

% Bước 1.
if ~isfield(V, 'h') || ~isvalid(V.h.env)
    V.h = dung(V, M, T);
    V.A = 0.05;
end
h = V.h;
tuyet = isfield(V, 'tuyetDoi') && isequal(V.tuyetDoi, true);

if nargin < 3 || isempty(nho)
    nho = struct('key', blanks(0), 'tuoi', Inf);
end
if ~isfield(nho, 'khung')
    nho.khung = 0;
end
if ~isfield(nho, 'that')
    nho.that = [];
end

% Trạng thái rỗng: chưa nghe gì thì vẽ như một luồng chưa có mẫu nào.
y = zeros(1, 0);
fs = 8000;
winSec = 3;
info = struct('E', zeros(8, 0), 'rowIdx', zeros(1, 0), 'colIdx', zeros(1, 0), ...
              'conf', zeros(1, 0), 'tFrame', zeros(1, 0), 'reject', {cell(1, 0)});
if isstruct(L) && isfield(L, 'y') && isfield(L, 'info')
    y = L.y;
    fs = L.fs;
    winSec = L.winSec;
    info = L.info;
end
n = numel(y);
tNay = n / fs;

% Bước 3. Đường bao: cột cuối của Y là 5 ms mới nhất, canh vào mép phải.
% Trục tuyệt đối thì ngược lại: cột đầu là 5 ms đầu tiên, canh vào t = 0.
m = floor(n / NHOM);
if m >= 1
    if tuyet
        Y = reshape(y(1:m*NHOM), NHOM, m);
        t = ((1:m) - 0.5) * NHOM / fs;
    else
        Y = reshape(y(end-m*NHOM+1:end), NHOM, m);
        t = ((1:m) - m - 0.5) * NHOM / fs;
    end
    tren = max(Y, [], 1);
    duoi = min(Y, [], 1);
    set(h.env, 'XData', [t, fliplr(t)], 'YData', [tren, fliplr(duoi)]);
    aMoi = 1.15 * max(abs([tren, duoi]));
else
    set(h.env, 'XData', NaN, 'YData', NaN);
    aMoi = 0;
end

% Bước 4. Tick ±A thụt vào trong khung 12 % để nhãn không chạm mép khung.
if aMoi > V.A
    V.A = aMoi;
else
    V.A = max(0.05, 0.92 * V.A + 0.08 * aMoi);
end
A = 0.05 * 2 ^ (ceil(4 * log2(V.A / 0.05)) / 4);
datTrucThoiGian(V.axWave, winSec, tuyet);
datKhac(V.axWave, 'YLim', [-1.12 1.12] * A);
datTick(V.axWave, 'Y', [-A 0 A], {sprintf('$-%.2g$', A); '$0$'; sprintf('$%.2g$', A)});

% Bản đồ 8 bin: tFrame tính từ mẫu đầu của y; trục tương đối thì dời về
% "trước bây giờ".
E  = info.E;
nf = size(E, 2);
tf = info.tFrame;
if ~tuyet
    tf = tf - tNay;
end
r  = info.rowIdx;
c  = info.colIdx;

% Khung được xem kỹ: khung mới nhất, hoặc khung NHO.KHUNG khi người gọi chọn.
k = nf;
if tuyet && nho.khung >= 1 && nho.khung <= nf
    k = nho.khung;
end
chon = k >= 1 && k < nf;

% Trục phóng to: 32 ms cuối, hoặc 32 ms quanh tâm khung được chọn.
if chon
    c0 = round(info.tFrame(k) * fs);
    i0 = max(1, c0 - NZOOM/2 + 1);
    i1 = min(n, i0 + NZOOM - 1);
    set(h.zoom, 'XData', ((i0:i1) - c0) / fs * 1000, 'YData', y(i0:i1));
    datKhac(V.axZoom, 'XLim', [-16 16]);
    datTick(V.axZoom, 'X', [-10 0 10], {'$-10$'; '$0$'; '$10$'});
else
    nz = min(n, NZOOM);
    set(h.zoom, 'XData', ((1:nz) - nz) / fs * 1000, 'YData', y(end-nz+1:end));
    datKhac(V.axZoom, 'XLim', [-32 0]);
    datTick(V.axZoom, 'X', [-30 -20 -10 0], {'$-30$'; '$-20$'; '$-10$'; '$0$'});
end
datKhac(V.axZoom, 'YLim', [-1.12 1.12] * A);
datTick(V.axZoom, 'Y', [-A 0 A], {});

if nf >= 1
    set(h.img, 'XData', [tf(1) tf(end)], 'YData', [1 8], 'CData', E, 'Visible', 'on');
else
    set(h.img, 'Visible', 'off');
end
if chon
    set(h.chon, 'XData', [tf(k) tf(k)], 'YData', [0.5 8.5]);
else
    set(h.chon, 'XData', NaN, 'YData', NaN);
end
datTrucThoiGian(V.axMap, winSec, tuyet);
datNhanDai(h.nhanDai, tf, r, c, T, M);
coThat = tuyet && isstruct(nho.that) && isfield(nho.that, 'k') && ~isempty(nho.that.k);
if coThat
    datKhac(V.axMap, 'YLim', [0.5 10.9]);
    datTick(V.axMap, 'Y', [1:8 9.1 10.3], [h.lab(:); {'$\hat{k}$'; '$k$'}]);
    datThat(h, nho.that, M);
else
    datKhac(V.axMap, 'YLim', [0.5 9.7]);
    datTick(V.axMap, 'Y', 1:8, h.lab(:));
    datThat(h, [], M);
end

% Khung được xem kỹ: tám thanh và bàn phím.
e = zeros(1, 8);
rM = 0;
cM = 0;
lyDo = blanks(0);
if k >= 1
    e   = E(:, k)';
    rM  = r(k);
    cM  = c(k);
    lyDo = info.reject{k};
end

mauThanh = [repmat(tron(M.the, M.hang, 0.3), 4, 1); ...
            repmat(tron(M.the, M.cot, 0.3), 3, 1); M.xamCot];
if rM >= 1 && cM >= 1
    mauThanh(rM, :)     = M.hang;
    mauThanh(4 + cM, :) = M.cot;
end
set(h.bar, 'YData', e, 'CData', mauThanh);
datKhac(V.axBars, 'YLim', [0 1.25 * max(0.6, ceil(5 * max(e)) / 5)]);
[cauQ, nhanQ] = phanQuyet(rM, cM, lyDo, nf, T);
mauQ = M.chuPhu;
if nhanQ
    mauQ = M.dung;
end
datKhac(h.quyet, 'String', cauQ);
datKhac(h.quyet, 'Color', mauQ);

% Bàn phím. Mức sáng nhãn hàng/cột = năng lượng tone đó; ô phím chỉ sáng nửa
% chừng theo min(hàng, cột) cho tới khi dtmf_decide nhận đúng phím đó.
if ~isfield(h, 'ban')
    return
end
a = min(1, e(1:4) / SANG);
b = min(1, e(5:7) / SANG);
g = 0.55 * min(a(:), b(:)');
if rM >= 1 && cM >= 1
    g(rM, cM) = 1;
end
if ~isempty(nho.key) && nho.tuoi < MO
    [rr, cc] = find(T.keys == nho.key, 1);
    if ~isempty(rr)
        g(rr, cc) = max(g(rr, cc), 1 - nho.tuoi / MO);
    end
end

gO = reshape(g', 1, []);            % 12 ô theo thứ tự 1 2 3 4 ... * 0 #
ui_pad(h.ban, gO, a, b);

% Dòng dưới bàn phím: khung đang kêu, hoặc phím vừa báo còn sáng.
cau = blanks(0);
if rM >= 1 && cM >= 1
    cau = sprintf('%d + %d Hz  %s  %s', T.rowHz(rM), T.colHz(cM), char(8594), T.keys(rM, cM));
elseif ~isempty(nho.key) && nho.tuoi < 2
    [rr, cc] = find(T.keys == nho.key, 1);
    if ~isempty(rr)
        cau = sprintf('%d + %d Hz  %s  %s', T.rowHz(rr), T.colHz(cc), char(8594), nho.key);
    end
end
datKhac(h.ban.cau, 'String', cau);

end

function datKhac(obj, ten, giaTri)
%DATKHAC Gán thuộc tính chỉ khi giá trị mới khác giá trị đang có - Bước 5.
if ~isequal(obj.(ten), giaTri)
    obj.(ten) = giaTri;
end
end


% ====================================================================== dựng

function h = dung(V, M, T)
%DUNG Dựng mọi đối tượng đồ họa một lần, kèm trang trí trục.
h = struct();

% Dạng sóng: một patch đường bao, màu nhấn pha nhạt.
ax = V.axWave;
cla(ax);
hold(ax, 'on');
h.env = patch(ax, NaN, NaN, tron(M.the, M.nhan, 0.7), 'EdgeColor', 'none');
hold(ax, 'off');
trangTri(ax, M);
nhanTruc(ax, '$t$ (s)', '$y[n]$');

ax = V.axZoom;
cla(ax);
h.zoom = line(ax, NaN, NaN, 'Color', M.nhan, 'LineWidth', 0.9);
ax.XLim = [-32 0];                  % NZOOM = 256 mẫu ở 8 kHz
ax.XTick = [-30 -20 -10 0];
ax.XTickLabel = {'$-30$'; '$-20$'; '$-10$'; '$0$'};
ax.YTickLabel = {};
trangTri(ax, M);
nhanTruc(ax, '$t$ (ms)', '');

% Bản đồ 8 bin: ảnh, hai vạch đứt ngăn nhóm hàng / nhóm cột / 2f, nhãn phím
% ở làn trên cùng.
ax = V.axMap;
cla(ax);
hold(ax, 'on');
h.img = imagesc(ax, [0 1], [1 8], zeros(8, 2), 'Visible', 'off');
colormap(ax, M.cmap);
ax.CLim = [0 0.5];
ax.YDir = 'normal';
yline(ax, 4.5, '--', 'Color', M.chuMo, 'LineWidth', 0.5);
yline(ax, 7.5, '--', 'Color', M.chuMo, 'LineWidth', 0.5);
% Vạch đứt đánh dấu khung đang được xem kỹ (NHO.KHUNG).
h.chon = line(ax, NaN, NaN, 'LineStyle', '--', 'Color', M.muc, 'LineWidth', 0.9);
% 48 nhãn: một số 20 chữ số trong tiếng ồn còn có thêm vài dải một khung.
h.nhanDai = gobjects(1, 48);
for k = 1:numel(h.nhanDai)
    h.nhanDai(k) = text(ax, NaN, 9.1, '', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', 13, 'Interpreter', 'latex', ...
        'Color', M.nhan);
end
% Làn số thật (NHO.THAT): một vạch dưới mỗi lần bấm và tên phím bên trên.
h.vachDung = line(ax, NaN, NaN, 'Color', M.dung, 'LineWidth', 2.5);
h.vachSai  = line(ax, NaN, NaN, 'Color', M.sai,  'LineWidth', 2.5);
h.that = gobjects(1, 24);
for k = 1:numel(h.that)
    h.that(k) = text(ax, NaN, 10.3, '', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', 14, 'Interpreter', 'latex', ...
        'Color', M.dung);
end
hold(ax, 'off');
lab = [arrayfun(@(v) sprintf('$%d$', v), [T.rowHz T.colHz], 'UniformOutput', false), {'$2f$'}];
h.lab = lab(:);
ax.YTick = 1:8;
ax.YTickLabel = h.lab;
ax.YLim = [0.5 9.7];
trangTri(ax, M);
nhanTruc(ax, '$t$ (s)', '$f$ (Hz)');

% Tám thanh: tô theo nhóm, hai thanh được chọn đậm màu. Phán quyết ghi
% trong khung, góc trên trái, như một nút chú thích của pgfplots.
ax = V.axBars;
cla(ax);
h.bar = bar(ax, 1:8, zeros(1, 8), 0.5, 'FaceColor', 'flat', 'EdgeColor', 'none');
ax.XTick = 1:8;
ax.XTickLabel = lab;
ax.XLim = [0.4 8.6];
ax.YTick = 0:0.2:1;
ax.YTickLabel = {'$0$', '$0.2$', '$0.4$', '$0.6$', '$0.8$', '$1$'};
trangTri(ax, M);
nhanTruc(ax, '$f$ (Hz)', '$E_k$');
h.quyet = text(ax, 0.03, 0.96, '', 'Units', 'normalized', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontName', M.tex.font, 'FontSize', 12, 'FontAngle', 'italic', ...
    'Interpreter', 'none', 'Color', M.chuPhu);

% Bàn phím: dùng chung với DTMFApp - xem ui_pad. Màn giám định không có.
if isfield(V, 'axPad') && ~isempty(V.axPad) && isvalid(V.axPad)
    h.ban = ui_pad(V.axPad, true);
end
end

function trangTri(ax, M)
%TRANGTRI Trục kiểu pgfplots: khung kín, tick vào trong, không lưới, số
% trên trục đặt bằng latex.
ax.FontName   = M.tex.font;
ax.FontSize   = 12;
ax.TickLabelInterpreter = 'latex';
ax.XColor     = M.muc;
ax.YColor     = M.muc;
ax.LineWidth  = 0.6;
ax.Box        = 'on';
ax.TickDir    = 'in';
ax.TickLength = [0.012 0.012];
ax.XGrid = 'off';
ax.YGrid = 'off';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
end

function nhanTruc(ax, nx, ny)
%NHANTRUC Nhãn hai trục, đặt bằng latex.
xlabel(ax, nx, 'Interpreter', 'latex', 'FontSize', 13);
ylabel(ax, ny, 'Interpreter', 'latex', 'FontSize', 13);
end

function s = kyTex(k)
%KYTEX Ký tự phím -> chuỗi latex: # là ký tự đặc biệt, * đặt thành dấu sao toán.
switch k
    case '#'
        s = '\#';
    case '*'
        s = '$\ast$';
    otherwise
        s = k;
end
end

% ====================================================================== cập nhật

function datTrucThoiGian(ax, winSec, tuyet)
%DATTRUCTHOIGIAN Trục hoành "trước hiện tại": tick mỗi giây, t = 0 là bây giờ.
% tuyet = true: trục 0..winSec từ đầu đoạn ghi âm, tick 1 s (2 s khi dài hơn
% 12 s cho nhãn khỏi chen nhau). Chỉ gán khi winSec đổi - Bước 5.
if tuyet
    datKhac(ax, 'XLim', [0 winSec]);
    tick = 0:(1 + (winSec > 12)):floor(winSec);
else
    datKhac(ax, 'XLim', [-winSec 0]);
    tick = -floor(winSec):0;
end
nhan = arrayfun(@(v) sprintf('$%d$', v), tick, 'UniformOutput', false);
datTick(ax, 'X', tick, nhan(:));
end

function datThat(h, that, M)
%DATTHAT Làn số thật trên cùng bản đồ: mỗi lần bấm một vạch ngang từ lúc
% tone bắt đầu tới lúc tắt, tên phím bên trên; xanh nếu bộ giải mã đọc đúng
% phím đó, đỏ nếu không. Đúng/sai do dtmf_judge quyết, hàm này chỉ tô.
xd = [];
xs = [];
n = 0;
if isstruct(that) && isfield(that, 'k')
    n  = min(numel(that.k), numel(h.that));
    t0 = reshape(that.t0(1:n), 1, []);
    t1 = reshape(that.t1(1:n), 1, []);
    ok = reshape(logical(that.dung(1:n)), 1, []);
    % Mỗi cột một đoạn [đầu; cuối; NaN]; trải phẳng thành một đường đứt quãng.
    doan = [t0; t1; NaN(1, n)];
    xd = reshape(doan(:, ok), 1, []);
    xs = reshape(doan(:, ~ok), 1, []);
    for i = 1:n
        mau = M.dung;
        if ~ok(i)
            mau = M.sai;
        end
        datKhac(h.that(i), 'Position', [(t0(i) + t1(i)) / 2, 10.3, 0]);
        datKhac(h.that(i), 'String', kyTex(that.k(i)));
        datKhac(h.that(i), 'Color', mau);
    end
end
for q = n+1:numel(h.that)
    datKhac(h.that(q), 'String', '');
end
vach(h.vachDung, xd);
vach(h.vachSai, xs);
end

function vach(ln, x)
%VACH Các đoạn ngang ở y = 9.75, ngăn nhau bằng NaN; rỗng thì ẩn.
if isempty(x)
    set(ln, 'XData', NaN, 'YData', NaN);
else
    set(ln, 'XData', x, 'YData', 9.75 + 0 * x);
end
end

function datTick(ax, truc, tick, nhan)
%DATTICK Ghim tick và nhãn tick của trục TRUC ('X' hoặc 'Y'). Không dùng
% datKhac cho XTick: nếu tick tự động tình cờ trùng giá trị mới thì datKhac
% bỏ qua, trục vẫn ở chế độ tự động, đổi cỡ cửa sổ là MATLAB sinh tick khác
% và nhãn ghim sẵn lặp vòng. Vẫn chỉ gán khi thật sự cần - Bước 5.
if ax.([truc 'TickMode']) == "auto" || ~isequal(ax.([truc 'Tick']), tick)
    ax.([truc 'Tick']) = tick;
end
datKhac(ax, [truc 'TickLabel'], nhan);
end

function datNhanDai(nhanDai, tf, r, c, T, M)
%DATNHANDAI Ghi tên phím lên làn trên cùng của bản đồ, mỗi dải khung một nhãn.
% Gom khung nhận liên tiếp cùng phím thành dải như ui_plot_map; dải chỉ một
% khung ghi màu xám vì dtmf_debounce bỏ dải ngắn hơn minRun = 2.
k = (r - 1) * 3 + c;
k(~(r >= 1 & c >= 1)) = 0;
n = numel(k);
dung = 0;
i = 1;
while i <= n && dung < numel(nhanDai)
    if k(i) == 0
        i = i + 1;
        continue
    end
    j = i;
    while j < n && k(j + 1) == k(i)
        j = j + 1;
    end
    mau = M.nhan;
    if j == i
        mau = M.chuMo;
    end
    dung = dung + 1;
    datKhac(nhanDai(dung), 'Position', [(tf(i) + tf(j)) / 2, 9.1, 0]);
    datKhac(nhanDai(dung), 'String', kyTex(T.keys(r(i), c(i))));
    datKhac(nhanDai(dung), 'Color', mau);
    i = j + 1;
end
for q = dung+1:numel(nhanDai)
    datKhac(nhanDai(q), 'String', '');
end
end

function [s, nhan] = phanQuyet(r, c, lyDo, nf, T)
%PHANQUYET Một câu nói khung mới nhất được nhận ra phím gì, hay bị loại vì sao.
% Chỉ đọc nhãn dtmf_decide đã gắn, không xét lại điều kiện nào. nhan = true
% khi khung được nhận ra một phím.
nhan = r >= 1 && c >= 1;
if nf == 0
    s = 'chưa có khung nào';
elseif nhan
    s = sprintf('nhận %d + %d Hz → phím %s', T.rowHz(r), T.colHz(c), T.keys(r, c));
else
    switch lyDo
        case 'level'
            % dtmf_decide gom ba ca vào 'level': khung im lặng, đỉnh không trội
            % hơn đỉnh nhì cùng nhóm peakDb, hay 7 bin chuẩn dưới energyRatio.
            s = 'loại: không có cặp tone nào rõ rệt (level)';
        case 'twist'
            s = 'loại: hai tone lệch biên độ quá mức (twist)';
        case 'harmonic'
            s = 'loại: hài bậc 2 quá lớn, giống tiếng nói (harmonic)';
        otherwise
            s = sprintf('loại: %s', lyDo);
    end
end
end

function C = tron(nen, mau, muc)
%TRON Pha màu: muc = 0 ra màu nền, muc = 1 ra màu đầy. muc là vector thì mỗi phần tử một hàng.
muc = max(0, min(1, muc(:)));
C = (1 - muc) .* nen + muc .* mau;
end
