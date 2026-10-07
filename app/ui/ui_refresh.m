function ui_refresh(app)
%UI_REFRESH Vẽ lại toàn bộ giao diện sau khi S đổi
% Vẽ sáu trục của ba bước xử lý, hiện chuỗi phím đọc được, dồn mọi lỗi vào nhật ký
%   UI_REFRESH(APP) đọc APP.S rồi cập nhật sáu trục, LblDecoded và TxtLog. Đây
%   là hàm DUY NHẤT được gọi sau mỗi lần S đổi.
%
%   Sáu trục xếp theo ba bước, mỗi bước một cặp miền thời gian | miền tần số:
%       ① AxWaveX, AxPsdX   tín hiệu gốc S.x
%       ② AxWave,  AxPsd    tín hiệu sau kênh nhiễu S.y, phổ chồng phổ của S.x
%       ③ AxMap,   AxBars   năng lượng 8 bin theo khung, và khung quyết định
%
%   Các bước hoạt động:
%       1. Điền giá trị mặc định cho những trường S còn thiếu. Giao diện lúc
%          mới mở chưa chạy dtmf_run lần nào nên chưa có .info, .iSel, .thr.
%       2. Gọi sáu hàm vẽ, MỖI hàm một try/catch riêng: một trục hỏng không
%          được kéo theo các trục khác.
%       3. Trang trí, rồi ĐỒNG BỘ THANG: hai dạng sóng cùng thang biên độ, hai
%          phổ cùng thang dB, ba trục thời gian cùng XLim - để mắt so được x[n]
%          với y[n] và mỗi khung với đúng đoạn sóng của nó.
%       4. LblDecoded hiện S.keysHat.
%       5. Nối mọi thông báo lỗi gom được vào cuối TxtLog.
%
%   Hàm này KHÔNG bao giờ ném lỗi và KHÔNG giải mã gì - mọi con số quyết định
%   phải do dtmf_run dọn sẵn, xem CONTRACTS §6(h). Nó chỉ đụng chín thành
%   phần: sáu trục kể trên, LblDecoded, TxtLog và S.
%
%   Input:
%       app: đối tượng giao diện (DTMFApp), hoặc bất cứ thứ gì có chín thành
%            phần kể trên - đó là toàn bộ hợp đồng mà hàm này cần.
%
%   Example:
%       app.S = dtmf_run(app.S);
%       ui_refresh(app)

S = app.S;

% Bước 1. Giao diện lúc mới mở chưa gọi dtmf_run lần nào.
macDinh = struct('x',         zeros(1, 0), ...
                 'y',         zeros(1, 0), ...
                 'fs',        8000, ...
                 'meta',      [], ...
                 'keysHat',   blanks(0), ...
                 'info',      struct('E', zeros(8, 0)), ...
                 'iSel',      0, ...
                 'thr',       0, ...
                 'lastError', blanks(0));
ten = fieldnames(macDinh);
for i = 1:numel(ten)
    if ~isfield(S, ten{i})
        S.(ten{i}) = macDinh.(ten{i});
    end
end

loi = {};
if ~isempty(S.lastError)
    loi{end+1} = S.lastError;
end

% Bước 2. Sáu lời gọi độc lập nhau. Gộp chung một try/catch thì một lỗi ở trục
% thanh làm mất luôn dạng sóng và phổ - mất gần hết màn hình chỉ vì hỏng một ô.
loi = veAnToan(loi, @() ui_plot_wave(app.AxWaveX, S.x, S.fs, S.meta));
loi = veAnToan(loi, @() ui_plot_psd(app.AxPsdX, S.x, S.fs));
loi = veAnToan(loi, @() ui_plot_wave(app.AxWave, S.y, S.fs, S.meta));
loi = veAnToan(loi, @() ui_plot_psd(app.AxPsd, S.y, S.fs, S.x));

% iSel = 0 nghĩa là chưa giải mã hoặc vừa xóa kết quả. S.info khi đó có thể
% còn là của lần giải mã TRƯỚC (xoaKetQua của DTMFApp chỉ đặt iSel = 0), nên
% bản đồ và trục thanh chỉ được vẽ khi iSel trỏ vào một khung có thật.
coKhung = S.iSel >= 1 && S.iSel <= size(S.info.E, 2);
info = [];
E = [];
if coKhung
    info = S.info;
    E = S.info.E(:, S.iSel);
end
loi = veAnToan(loi, @() ui_plot_map(app.AxMap, info, S.iSel));
loi = veAnToan(loi, @() ui_plot_bars(app.AxBars, E, S.thr));

% Bước 3. Trang trí SAU khi vẽ, không phải lúc dựng trục: bar() và imagesc()
% ở chế độ NextPlot = 'replace' đặt lại mọi thuộc tính trục mỗi lần vẽ. Làm
% ở đây chứ không trong ui_plot_wave / ui_plot_bars, vì hai hàm đó còn vẽ hình
% cho báo cáo với màu riêng.
M = ui_theme();
loi = veAnToan(loi, @() trangTriTruc(app.AxWaveX, M, '$x[n]$'));
loi = veAnToan(loi, @() trangTriTruc(app.AxPsdX, M, ''));
loi = veAnToan(loi, @() trangTriTruc(app.AxWave, M, '$y[n]$'));
loi = veAnToan(loi, @() trangTriTruc(app.AxPsd, M, ''));
loi = veAnToan(loi, @() trangTriTruc(app.AxMap, M, ''));
loi = veAnToan(loi, @() trangTriTruc(app.AxBars, M, ''));

loi = veAnToan(loi, @() dongBoSong([app.AxWaveX, app.AxWave]));
loi = veAnToan(loi, @() toSong(app.AxWaveX, M));
loi = veAnToan(loi, @() toSong(app.AxWave, M));
loi = veAnToan(loi, @() dongBoPho([app.AxPsdX, app.AxPsd]));
loi = veAnToan(loi, @() canThoiGian(app.AxMap, app.AxWave, S));
loi = veAnToan(loi, @() toThanh(app.AxBars, S, M));

% Bước 4. Màu chữ cho biết ngay đọc đúng hay sai mà không cần so từng ký tự:
% xanh là khớp chuỗi đã phát, đỏ là lệch. Không có meta (chưa phát, hoặc tín
% hiệu micro) thì không có gì để so, giữ màu chữ thường.
try
    app.LblDecoded.Text = S.keysHat;

    mau = M.muc;
    if ~isempty(S.keysHat) && isstruct(S.meta) && isfield(S.meta, 'keys')
        if isequal(S.keysHat, S.meta.keys)
            mau = M.dung;
        else
            mau = M.sai;
        end
    end
    app.LblDecoded.FontColor = mau;
catch ME
    loi{end+1} = ME.message;
end

% Bước 5. Nối vào CUỐI nhật ký cũ, không ghi đè: người dùng cần thấy cả chuỗi
% sự kiện chứ không chỉ lỗi gần nhất.
if ~isempty(loi)
    try
        cu = app.TxtLog.Value;
        if ~iscell(cu)
            cu = cellstr(cu);
        end

        % uitextarea mới dựng có Value = {''} chứ không phải {}. Không bỏ nó
        % thì nhật ký vĩnh viễn mở đầu bằng một dòng trắng.
        if isscalar(cu) && isempty(char(cu{1}))
            cu = {};
        end

        app.TxtLog.Value = [cu(:); loi(:)];
    catch
        % Ghi nhật ký hỏng thì cũng không được làm sập phần vẽ đã xong.
    end
end

end

function trangTriTruc(ax, M, nhanY)
%TRANGTRITRUC Trục kiểu hình pgfplots trong một bài LaTeX: khung kín, tick
% vào trong, không lưới, số trên trục và nhãn trục đặt bằng bộ diễn dịch
% latex (Computer Modern, như công thức của báo cáo). Không đổi dữ liệu nào.
% Nhãn trục tiếng Việt của ui_plot_* đổi thành ký hiệu ($t$ (s), $f$ (Hz),
% $E_j$) - bộ diễn dịch latex của MATLAB không có dấu tiếng Việt, nên nhãn
% nào không có trong bảng dưới thì giữ nguyên chữ. nhanY: nhãn trục tung
% riêng cho trục này ('$x[n]$' cho dạng sóng gốc), rỗng thì tra bảng.
% Trục chưa có gì để vẽ thì ẩn luôn thước đo và khung: một khung 0..1 trống
% trơn với đủ vạch chia trông như hình hỏng, chỉ dòng tiêu đề là đủ.
coNoiDung = ~isempty(ax.Children);

ax.FontName   = M.tex.font;
ax.FontSize   = 11;
ax.TickLabelInterpreter = 'latex';
ax.XColor     = M.muc;
ax.YColor     = M.muc;
ax.LineWidth  = 0.6;
ax.Box        = matlab.lang.OnOffSwitchState(coNoiDung);
ax.TickDir    = 'in';
ax.TickLength = [0.01 0.01];

ax.TitleFontSizeMultiplier  = 1.15;
ax.TitleFontWeight          = 'normal';
ax.TitleHorizontalAlignment = 'left';
ax.Title.Color = M.muc;

ax.XAxis.Visible = coNoiDung;
ax.YAxis.Visible = coNoiDung;
ax.XGrid = 'off';
ax.YGrid = 'off';

if ~coNoiDung
    ax.Title.Color = M.chuMo;
    return
end

bang = {'Thời gian [s]',           '$t$ (s)'
        'Tần số [Hz]',             '$f$ (Hz)'
        'Bin [Hz]',                '$f$ (Hz)'
        'PSD [dB/Hz]',             'PSD (dB/Hz)'
        'Năng lượng đã chuẩn hóa', '$E_j$'};
doiNhan(ax.XLabel, bang, '');
doiNhan(ax.YLabel, bang, nhanY);
set(findobj(ax, 'Type', 'text'), 'FontName', M.tex.font);
end

function doiNhan(nhan, bang, rieng)
%DOINHAN Đổi một nhãn trục sang ký hiệu latex theo BANG, hoặc thành RIENG.
moi = rieng;
if isempty(moi)
    k = find(strcmp(bang(:, 1), char(nhan.String)), 1);
    if isempty(k)
        return
    end
    moi = bang{k, 2};
end
set(nhan, 'String', moi, 'Interpreter', 'latex', 'FontSize', 13);
end

function dongBoSong(axs)
%DONGBOSONG Đưa hai dạng sóng x[n] và y[n] về CÙNG thang biên độ.
% Mỗi trục ui_plot_wave tự chọn thang theo biên độ của chính nó, nên ở SNR
% thấp y[n] trông "to bằng" x[n] dù nhiễu đã gấp ba tín hiệu. Lấy thang lớn
% hơn cho cả hai, và kéo vùng tô nền theo, để toSong suy lại đúng biên độ.
coSong = arrayfun(@(a) ~isempty(findobj(a, 'Type', 'line')), axs);
axs = axs(coSong);
if numel(axs) < 2
    return
end
yMax = max(arrayfun(@(a) a.YLim(2), axs));
for ax = axs
    ax.YLim = [-yMax yMax];
    for pa = findobj(ax, 'Type', 'patch')'
        v = pa.YData;
        v(v == max(v)) = yMax;
        v(v == min(v)) = -yMax;
        pa.YData = v;
    end
end
end

function toSong(ax, M)
%TOSONG Tô lại dạng sóng và dành riêng một "làn" phía trên cho nhãn phím.
% ui_plot_wave đặt nhãn phím ở 0.92 biên độ, tức ĐÈ lên đỉnh sóng. Ở đây nới
% trần trục lên 1.55 biên độ và dời nhãn vào khoảng trống đó; vùng tô nền
% kéo cao theo để nhãn vẫn nằm trong vùng của nó. Vạch chia trục y chỉ giữ
% trong dải biên độ thật - vạch nằm trong làn nhãn không đo gì cả.
ln = findobj(ax, 'Type', 'line');
if isempty(ln)
    return
end
set(ln, 'Color', M.nhan, 'LineWidth', 0.6);

% ui_plot_wave đặt ylim = 1.1*a*[-1 1] - suy ngược ra a, không đo lại tín hiệu.
yl  = ax.YLim;
a   = yl(2) / 1.1;
top = 1.55 * a;
ax.YLim = [yl(1), top];

for pa = findobj(ax, 'Type', 'patch')'
    v = pa.YData;
    v(v == max(v)) = top;
    set(pa, 'YData', v, 'FaceColor', M.nhan, 'FaceAlpha', 0.06);
end
for tx = findobj(ax, 'Type', 'text')'
    tx.Position(2) = 1.32 * a;
    set(tx, 'Color', M.nhan, 'FontName', M.tex.font, 'FontSize', 12, ...
        'FontWeight', 'bold', 'VerticalAlignment', 'middle');
end

tk = ax.YTick;
ax.YTick = tk(abs(tk) <= 1.1 * a);
end

function dongBoPho(axs)
%DONGBOPHO Đưa hai trục phổ về CÙNG thang dB: nền nhiễu của y[n] mới so được
% bằng mắt với nền của x[n] ở hàng trên. Dải tô nền và nhãn nhóm của
% ui_plot_psd không phụ thuộc YLim nên chỉ cần đổi YLim.
coPho = arrayfun(@(a) ~isempty(findobj(a, 'Type', 'line')), axs);
axs = axs(coPho);
if numel(axs) < 2
    return
end
lim = cell2mat(arrayfun(@(a) a.YLim, axs(:), 'UniformOutput', false));
yl = [min(lim(:, 1)), max(lim(:, 2))];
set(axs, 'YLim', yl);
end

function canThoiGian(axMap, axWave, S)
%CANTHOIGIAN Cho bản đồ khung cùng trục thời gian với dạng sóng y[n] ngay trên.
% imagesc bó trục x theo TÂM khung đầu và cuối, còn dạng sóng chạy [0, thời
% lượng] - hai trục chồng nhau mà lệch thời gian.
if isempty(findobj(axMap, 'Type', 'image')) || isempty(S.y)
    return
end
axMap.XLim = axWave.XLim;
end

function toThanh(ax, S, M)
%TOTHANH Tô lại tám thanh và ghi phụ đề: khung nào, ở đâu, đọc ra phím gì.
% Phụ đề luôn được ghi - kể cả chuỗi rỗng - vì cla KHÔNG xóa phụ đề: bỏ qua
% thì phụ đề của lần giải mã trước còn treo trên một trục đã trắng.
txt = '';
if S.iSel >= 1 && isfield(S.info, 'tFrame') && S.iSel <= numel(S.info.tFrame)
    txt = sprintf('Khung %d/%d, tâm t = %.3f s', ...
        S.iSel, numel(S.info.tFrame), S.info.tFrame(S.iSel));

    % Hàng/cột lấy từ info; tra bảng phím là tra hằng số, không phải phép tính.
    T = dtmf_table();
    r = S.info.rowIdx(S.iSel);
    c = S.info.colIdx(S.iSel);
    if r >= 1 && r <= 4 && c >= 1 && c <= 3
        txt = sprintf('%s     %d Hz + %d Hz  →  phím %s', ...
            txt, T.rowHz(r), T.colHz(c), T.keys(r, c));
    end
end
subtitle(ax, txt, 'Color', M.chuPhu, 'FontSize', 11, 'FontName', M.tex.font);

b = findobj(ax, 'Type', 'bar');
if isempty(b)
    return
end

% Cột nào ui_plot_bars đã tô cam (vượt ngưỡng) thì đổi sang màu nhấn, còn lại
% xám nhạt. Đọc lại màu nó đã tô chứ KHÔNG so E với ngưỡng lần nữa: tầng này
% không quyết định cột nào nổi, chỉ đổi cách tô.
noi = ismember(b.CData, [0.90 0.45 0.13], 'rows');
C = repmat(M.xamCot, size(b.CData, 1), 1);
C(noi, :) = repmat(M.nhan, nnz(noi), 1);
set(b, 'CData', C, 'EdgeColor', 'none', 'BarWidth', 0.5);

% Nhãn "ngưỡng hài" sang mép PHẢI: bên trái là nhóm hàng 697-941 Hz, luôn có
% một cột cao đè lên nhãn; bên phải là cột '2f', gần như luôn thấp.
set(findobj(ax, 'Type', 'constantline'), ...
    'Color', M.sai, 'LineWidth', 0.8, 'Alpha', 0.8, ...
    'LabelHorizontalAlignment', 'right', 'FontSize', 11, 'FontName', M.tex.font);
end

function loi = veAnToan(loi, fn)
%VEANTOAN Gọi một hàm vẽ, nuốt lỗi và gom thông báo lại.
try
    fn();
catch ME
    loi{end+1} = ME.message;
end
end
