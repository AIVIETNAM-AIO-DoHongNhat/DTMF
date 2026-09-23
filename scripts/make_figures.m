%% make_figures.m
% MAKE_FIGURES Dựng toàn bộ hình MATLAB của báo cáo vào results/figures/
%
% Nạp results/bench.mat (do scripts/run_bench.m sinh) rồi vẽ 9 hình. Script này
% KHÔNG tính lại bất cứ số liệu thực nghiệm nào - chạy lại nó sau khi sửa màu
% một cái hình không được làm đổi một con số nào trong báo cáo.
%
% Hai hình gắn với giao diện (H2_1, H2_4) KHÔNG vẽ lại bằng tay mà giao cho
% chính app/ui/ui_plot_spec và app/ui/ui_plot_bars, trên uiaxes thật trong một
% uifigure ẩn. Nhờ vậy hình in ra báo cáo đúng là hình người chấm nhìn thấy khi
% bấm nút, chứ không phải một bản vẽ song song sớm muộn lệch đi.
%
% ⚠️ THEME SÁNG PHẢI ÉP CỨNG. Từ R2025a, figure và uifigure bám theme của hệ
% điều hành: máy đang để Windows ở chế độ tối thì mọi hình xuất ra có nền ĐEN -
% đo được 23/09/2026, và 'Color', 'w' một mình KHÔNG cứu được vì nền trục, màu
% chữ và màu lưới đều do theme quyết định. Mỗi mặt vẽ ở đây gọi theme(fig,
% 'light') hoặc dựng uifigure với 'Theme', 'light'.
%
% Mỗi hình ghi ra HAI bản cùng tên: .png 300 dpi để dán vào slide và Word, .pdf
% vector để LaTeX dùng. Xem xuatHaiDinhDang ở cuối file.
%
% Tên file dùng GẠCH DƯỚI (H2_1.png) chứ không dùng dấu chấm (H2.1.png): LaTeX
% cắt phần mở rộng ở dấu chấm ĐẦU TIÊN, nên \includegraphics{Figures/H2.1} đi
% tìm một file tên "H2" có đuôi ".1". Mã hình trong báo cáo vẫn là H2.1.
%
% Cách dùng:  cd <repo>; addpath('scripts'); run_bench; make_figures

clear;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(genpath(fullfile(root, 'app')));

benchFile = fullfile(root, 'results', 'bench.mat');
if ~isfile(benchFile)
    error('make_figures:noBench', ...
        'Khong thay %s. Chay run_bench truoc.', benchFile);
end
L = load(benchFile, 'B');
B = L.B;

outDir = fullfile(root, 'results', 'figures');
if ~isfolder(outDir)
    mkdir(outDir);
end

% Bảng màu Okabe-Ito - bảng tiêu chuẩn cho hình khoa học. Tám màu phân biệt
% được với cả ba dạng mù màu phổ biến, và độ sáng của chúng khác nhau nên hình
% vẫn đọc được khi báo cáo bị in đen trắng. Luật đi kèm: không bao giờ lấy đỏ
% và xanh lá làm hai đường đối lập nhau.
OI = struct( ...
    'xanh',     [  0 114 178]/255, ...   % xanh dương
    'camDam',   [213  94   0]/255, ...   % cam đất
    'lucLam',   [  0 158 115]/255, ...   % xanh lục lam
    'cam',      [230 159   0]/255, ...   % cam sáng
    'xanhNhat', [ 86 180 233]/255, ...   % xanh trời
    'tim',      [204 121 167]/255, ...   % tím hồng
    'xam',      [0.45 0.45 0.48]);

fs     = B.meta.fs;
T      = dtmf_table();
mauPp  = [OI.xanh; OI.camDam; OI.lucLam];            % fft | goertzel | filterbank
tenDep = {'FFT', 'Goertzel', 'Ngân hàng bộ lọc'};
iAwgn  = find(strcmp(B.noises, 'awgn'), 1);
iEnChot = find(B.energyRatios == 0.70, 1);           % ngưỡng đang dùng thật

fprintf('Ve hinh vao %s\n', outDir);

%% H2.1 - Phổ đồ STFT của phím "5", do chính ui_plot_spec vẽ
x5 = dtmf_generate('5', 'fs', fs);
xuatTrucUi(fullfile(outDir, 'H2_1'), @(ax) veSpecCoThang(ax, x5, fs), 760, 420);

%% H2.3 - Giản đồ cực-không của 14 bộ cộng hưởng
% 'coeffs', '' ép nhánh CÔNG THỨC: hình trong báo cáo phải là hệ số dẫn giải
% được từ r = 0.99, không phải hệ số của một coeffs.mat cũ nằm sẵn trên máy.
bank = design_bpf_bank('fs', fs, 'coeffs', '');
xuatTruc(fullfile(outDir, 'H2_3'), @(fig) veCucKhong(fig, bank, fs), 620, 580);

%% H2.4 - 8 thanh công suất + ngưỡng, do chính ui_plot_bars vẽ
% Đi qua dtmf_run chứ không tự tính iSel/thr: hai con số đó là của lớp trung
% gian (CONTRACTS §6(h)), chép lại ở đây là dựng bản sao thứ hai của một luật.
S = dtmf_run(struct('y', x5, 'fs', fs, 'method', 'goertzel'));
assert(S.iSel >= 1, 'make_figures:noFrame', ...
    'Khong khung nao duoc nhan tren tin hieu sach cua phim "5".');
xuatTrucUi(fullfile(outDir, 'H2_4'), ...
    @(ax) ui_plot_bars(ax, S.info.E(:, S.iSel), S.thr), 620, 420);

%% H3.3 - Ảnh chụp giao diện
% Cửa sổ phải HIỆN HÌNH. Đo 23/09/2026: exportapp trên một DTMFApp('off') chụp
% đủ cột trái nhưng ba uiaxes ra TRẮNG TRƠN - xem ghi chú cuối Buổi 9 trong
% docs/study/KE_HOACH.md. Chạy trong matlab -batch vẫn mở được cửa sổ thật, nên
% chỉ cần đừng ẩn nó đi. Theme sáng là do DTMFApp tự đặt.
app = DTMFApp('on');
try
    app.EfKeys.Value   = '0912345';
    app.DdMethod.Value = 'goertzel';
    app.BtnGenPushed([]);
    app.BtnDecodePushed([]);

    % drawnow rồi pause rồi drawnow. Đo 23/09/2026: một lần trong nhiều lần
    % chạy, exportapp bắt được cửa sổ khi ba uiaxes CHƯA vẽ xong và cho ra ảnh
    % có đủ cột trái nhưng ba trục trắng trơn. drawnow trả về khi hàng đợi sự
    % kiện rỗng, không phải khi trình duyệt nền đã vẽ xong, nên chỉ một lệnh
    % drawnow là chưa đủ. Không có API công khai nào hỏi "vẽ xong chưa".
    drawnow;
    pause(1);
    drawnow;

    % exportapp không nhận 'Resolution' hay 'ContentType': nó chụp cửa sổ ở
    % đúng độ phân giải màn hình, nên bản PDF của riêng hình này cũng là ảnh
    % chứ không phải nét vector. Ảnh chụp giao diện thì đó là hành vi đúng.
    exportapp(app.UIFigure, fullfile(outDir, 'H3_3.png'));
    exportapp(app.UIFigure, fullfile(outDir, 'H3_3.pdf'));
catch ME
    delete(app);
    rethrow(ME);
end
delete(app);

%% H4.1 - Độ chính xác theo SNR, 3 phương pháp, 2 loại nhiễu
xuatTruc(fullfile(outDir, 'H4_1'), ...
    @(fig) veAccTheoSnr(fig, B, mauPp, tenDep, iEnChot), 900, 380);

%% H4.2 - Ma trận nhầm lẫn tại mức SNR nhiều lỗi nhất
xuatTruc(fullfile(outDir, 'H4_2'), ...
    @(fig) veNhamLan(fig, B, T, OI, iAwgn), 700, 600);

%% H4.3 - Lý do loại khung theo SNR
xuatTruc(fullfile(outDir, 'H4_3'), ...
    @(fig) veLyDoLoai(fig, B, OI, tenDep, iAwgn), 1000, 380);

%% H4.4 - Thời gian chạy đo được so với số phép nhân lý thuyết
xuatTruc(fullfile(outDir, 'H4_4'), ...
    @(fig) veChiPhi(fig, B, OI, tenDep), 660, 440);

%% H4.5 - Quét ngưỡng energyRatio (rủi ro R2)
xuatTruc(fullfile(outDir, 'H4_5'), ...
    @(fig) veQuetNguong(fig, B, OI, tenDep, iAwgn), 1000, 380);

%% Tổng kết
dPng = dir(fullfile(outDir, 'H*.png'));
dPdf = dir(fullfile(outDir, 'H*.pdf'));
fprintf('\nDa sinh %d hinh, moi hinh hai ban:\n', numel(dPng));
for i = 1:numel(dPng)
    [~, ten] = fileparts(dPng(i).name);
    j = find(strcmp({dPdf.name}, [ten '.pdf']), 1);
    fprintf('  %-6s  png %7.1f KB   pdf %7.1f KB\n', ten, ...
        dPng(i).bytes/1024, dPdf(j).bytes/1024);
end

% Hai con số phải bằng nhau. Lệch nghĩa là một lần xuất đã hỏng giữa chừng và
% thư mục đang trộn hình mới với hình của lần chạy trước.
if numel(dPng) ~= numel(dPdf)
    error('make_figures:soLuongLech', ...
        'Co %d file png nhung %d file pdf trong %s.', ...
        numel(dPng), numel(dPdf), outDir);
end


%% ===================== Hàm phụ: hai kiểu mặt vẽ =====================

function xuatTrucUi(ten, veFcn, w, h)
%XUATTRUCUI Vẽ lên một uiaxes trong uifigure ẩn (theme sáng) rồi xuất ra file
%   Dành riêng cho các hình do app/ui/ui_plot_* vẽ: chúng nhận uiaxes, và
%   chỉ trên uiaxes thì hình mới giống hệt cái giao diện hiển thị.
%   Đo 23/09/2026: exportgraphics trên TỪNG uiaxes ẩn ra đủ nội dung, khác với
%   exportapp trên cả uifigure ẩn (ba trục ra trắng).

fig = uifigure('Visible', 'off', 'Theme', 'light', 'Position', [100 100 w h]);

% try/catch chứ không onCleanup: onCleanup cần một biến chỉ để giữ chỗ, mà
% biến đó không ai đọc - đúng thứ mà luật "không thêm pragma" bảo phải khử
% chứ đừng tắt cảnh báo. Một hình vẽ hỏng giữa chừng không được để lại cửa
% sổ ẩn treo trong phiên.
try
    ax = uiaxes(fig, 'Position', [10 10 w-20 h-20], 'FontSize', 10);
    veFcn(ax);
    xuatHaiDinhDang(ax, ten);
catch ME
    delete(fig);
    rethrow(ME);
end
delete(fig);
end


function xuatHaiDinhDang(obj, ten)
%XUATHAIDINHDANG Ghi cùng một hình ra PNG 300 dpi và PDF vector
%   PNG là bản dùng hằng ngày: dán được thẳng vào slide, vào Word, xem được
%   ngay trong trình duyệt ảnh, và không phụ thuộc trình đọc PDF.
%   PDF vector là bản cho LaTeX: phóng to bao nhiêu cũng không vỡ chữ, nên
%   bảng tần số và nhãn trục vẫn sắc khi in.
%   Giữ cả hai vì chúng không thay thế được cho nhau, và chi phí đúng bằng
%   một lời gọi exportgraphics thứ hai.

exportgraphics(obj, [ten '.png'], 'Resolution', 300, 'BackgroundColor', 'white');
exportgraphics(obj, [ten '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'white');
end


function xuatTruc(ten, veFcn, w, h)
%XUATTRUC Vẽ lên một figure cổ điển ẩn (theme sáng) rồi xuất cả figure ra file
%   Dành cho các hình thuần số liệu, nơi cần tiledlayout / yyaxis / zplane -
%   những thứ uiaxes không nhận.

fig = figure('Visible', 'off', 'Position', [100 100 w h]);

% Thứ tự BẮT BUỘC: theme trước, Color sau. theme() ghi lại nền figure, nên đặt
% Color trước rồi mới gọi theme là mất trắng.
theme(fig, 'light');
set(fig, 'Color', 'w', 'DefaultAxesFontSize', 10, 'DefaultTextFontSize', 10);

try
    veFcn(fig);
    xuatHaiDinhDang(fig, ten);
catch ME
    delete(fig);
    rethrow(ME);
end
delete(fig);
end


%% ===================== Hàm phụ: từng hình =====================

function veSpecCoThang(ax, y, fs)
%VESPECCOTHANG Gọi ui_plot_spec rồi gắn thêm thanh màu cho bản in

% ui_plot_spec không tự gắn thanh màu, và đó là quyết định đúng cho giao diện:
% trong DTMFApp trục này nằm giữa hai trục khác, thanh màu ăn mất bề ngang mà
% người dùng đang tương tác thì đọc được đậm nhạt là đủ. Trên giấy thì khác:
% tiêu đề ghi đơn vị [dB] mà không có thang số đi kèm là một hình không đọc
% được định lượng. Chỉ thêm ở đây, không sửa ui_plot_spec.
ui_plot_spec(ax, y, fs);

cb = colorbar(ax);
cb.Label.String = 'Công suất [dB]';
end


function veCucKhong(fig, bank, fs)
%VECUCKHONG Vị trí cực và điểm không của cả 14 bộ cộng hưởng trên một vòng tròn

% Gọi zplane MỘT lần với hai ma trận, mỗi cột là một bộ lọc - đó là dạng gọi
% cho phép 14 bộ lên chung một vòng tròn với 14 màu. Gọi 14 lần trong hold on
% cũng ra hình, nhưng mỗi lần lại vẽ đè thêm một vòng tròn đơn vị và một bộ
% trục, và chú giải thì không còn biết đường nào của ai.
Z = zeros(2, numel(bank));
P = zeros(2, numel(bank));
for j = 1:numel(bank)
    Z(:, j) = roots(bank(j).b);
    P(:, j) = roots(bank(j).a);
end

% zplane vẽ vào gca và không nhận tham số trục. set(groot, 'CurrentFigure', ...)
% chỉ định figure hiện hành mà KHÔNG hiện nó lên - figure(fig) thì có, và một
% cửa sổ bật ra giữa matlab -batch là thứ phải tránh.
set(groot, 'CurrentFigure', fig);
zplane(Z, P);
ax = gca;

% ⚠️ KHÔNG gọi axis(ax, 'equal') ở đây. zplane đã tự đặt tỉ lệ trục 1:1, và
% axis equal chồng lên đó thì NỚI giới hạn ra ±350 (đo được) - vòng tròn đơn vị
% teo lại thành một chấm giữa một ô vuông trống, mà không có cảnh báo nào.
xlim(ax, [-1.2 1.2]);
ylim(ax, [-1.2 1.2]);
pbaspect(ax, [1 1 1]);
grid(ax, 'on');

% Băng thông 3 dB của một bộ cộng hưởng hai cực: BW = (1-r)*fs/pi. Ghi nó ra
% thay vì chỉ ghi r, vì r là tham số thiết kế còn BW mới là đại lượng so được
% với dung sai ±1.5% của ITU-T Q.24.
r  = max(abs(P(:)));
bw = (1 - r) * fs / pi;

xlabel(ax, 'Phần thực');
ylabel(ax, 'Phần ảo');
% Phụ đề tách thành hai dòng. Một dòng dài hơn bề ngang figure bị CẮT CỤT ở hai
% mép mà MATLAB không cảnh báo gì, và chữ mất là chữ đầu dòng.
title(ax, sprintf('Vị trí cực và điểm không của %d bộ cộng hưởng', numel(bank)));
subtitle(ax, {sprintf('r = %.2f, băng thông 3 dB ≈ %.1f Hz', r, bw), ...
              sprintf('Cả %d bộ dùng chung hai điểm không tại z = ±1', numel(bank))});
end


function veAccTheoSnr(fig, B, mauPp, tenDep, iEn)
%VEACCTHEOSNR Độ chính xác theo SNR, một khung cho mỗi loại nhiễu
tl = tiledlayout(fig, 1, numel(B.noises), 'TileSpacing', 'compact', 'Padding', 'compact');

for iNoi = 1:numel(B.noises)
    ax = nexttile(tl);
    hold(ax, 'on');

    % Vùng làm việc đã công bố, tô nền TRƯỚC khi vẽ đường. Dải này là lý do
    % bảng rủi ro R2 chấp nhận được cái vách: vách nằm ngoài dải demo chứ không
    % nằm giữa nó.
    yl = [-0.03 1.05];
    patch(ax, [10 max(B.snrDb) max(B.snrDb) 10], [yl(1) yl(1) yl(2) yl(2)], ...
        [0.75 0.88 0.75], 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
    text(ax, 10.6, 0.06, 'dải demo, SNR ≥ 10 dB', 'FontSize', 8, ...
        'Color', [0.25 0.45 0.25]);

    for iMet = 1:numel(B.methods)
        plot(ax, B.snrDb, squeeze(B.accMean(iMet, :, iNoi, iEn)), '-o', ...
            'Color', mauPp(iMet, :), 'MarkerFaceColor', mauPp(iMet, :), ...
            'LineWidth', 1.6, 'MarkerSize', 4.5, 'DisplayName', tenDep{iMet});
    end
    hold(ax, 'off');

    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [min(B.snrDb) max(B.snrDb)]);
    ylim(ax, yl);
    xticks(ax, min(B.snrDb):5:max(B.snrDb));
    xlabel(ax, 'SNR [dB]');
    ylabel(ax, 'Độ chính xác');
    title(ax, sprintf('Nhiễu %s', B.noises{iNoi}));
    if iNoi == 1
        legend(ax, 'Location', 'southeast');
    end
end

title(tl, sprintf('Độ chính xác theo SNR, %d chuỗi %d phím, energyRatio = %.2f', ...
    B.meta.nSeq, B.meta.keysLen, B.energyRatios(iEn)), 'FontWeight', 'bold');
end


function veNhamLan(fig, B, T, OI, iNoi)
%VENHAMLAN Ma trận nhầm lẫn, chọn đúng mức SNR có nhiều lỗi nhất

% Chọn mức SNR để vẽ thay vì ghim sẵn một con số: vách nằm ở đâu là chuyện của
% số liệu, và một mức ghim cứng sẽ cho ma trận toàn đường chéo (SNR cao) hoặc
% toàn số 0 (SNR quá thấp, không khung nào được nhận) sau mỗi lần đổi tham số.
nSub = zeros(1, numel(B.snrDb));
for iSnr = 1:numel(B.snrDb)
    M = sum(B.confusion(:, :, :, iSnr, iNoi), 3);
    nSub(iSnr) = sum(M(:)) - trace(M);
end
[~, iSnr] = max(nSub);
M = sum(B.confusion(:, :, :, iSnr, iNoi), 3);

% Phần lỗi KHÔNG nằm trong ma trận: confusion chỉ ghi các cặp đã căn chỉnh
% (bước chéo), còn chèn và xóa không có ô nào để ghi - CONTRACTS §6(g). Đưa con
% số đó lên hình, nếu không người đọc sẽ kết luận "gần như không có lỗi" từ một
% đường chéo sạch, trong khi lỗi thật là MẤT phím chứ không phải nhầm phím.
tongEdit = sum(B.editDist(:, iSnr, iNoi, 1, :), 'all');
nIndel   = tongEdit - nSub(iSnr);

% Nhãn duyệt theo CỘT của bảng phím, đúng thứ tự mà dtmf_metrics đánh số -
% CONTRACTS §6(g). Duyệt theo hàng cho một hình trông hợp lý y hệt nhưng là
% ma trận chuyển vị.
nhan = T.keys(:)';

ax = axes(fig);
imagesc(ax, M);

% Thang tuần tự trắng -> xanh dương: độ sáng giảm đơn điệu nên thứ tự đọc được
% cả khi in đen trắng, khác hẳn thang cầu vồng.
n  = 256;
cm = [linspace(1, OI.xanh(1), n)', linspace(1, OI.xanh(2), n)', linspace(1, OI.xanh(3), n)'];
colormap(ax, cm);
cb = colorbar(ax);
cb.Label.String = 'Số cặp đã căn chỉnh';

axis(ax, 'equal', 'tight');
set(ax, 'XTick', 1:12, 'XTickLabel', num2cell(nhan), ...
        'YTick', 1:12, 'YTickLabel', num2cell(nhan), ...
        'TickLength', [0 0]);
xlabel(ax, 'Phím giải mã được');
ylabel(ax, 'Phím thật');
title(ax, sprintf('Ma trận nhầm lẫn tại SNR = %g dB, nhiễu %s, gộp 3 phương pháp', ...
    B.snrDb(iSnr), B.noises{iNoi}));
subtitle(ax, {sprintf('Tổng %d phép sửa, trong đó %d lần thay phím nằm trong ma trận', ...
                      tongEdit, nSub(iSnr)), ...
              sprintf('%d lần chèn hoặc xóa không có ô nào để ghi', nIndel)});

vMax = max(M(:));
for i = 1:12
    for j = 1:12
        if M(i, j) > 0
            % Chữ trên nền đậm phải đổi sang trắng, nếu không ô đúng nhất -
            % tức ô đậm nhất - lại là ô duy nhất không đọc được.
            if M(i, j) > 0.55 * vMax
                mauChu = [1 1 1];
            else
                mauChu = [0 0 0];
            end
            text(ax, j, i, sprintf('%d', M(i, j)), 'Color', mauChu, ...
                'HorizontalAlignment', 'center', 'FontSize', 7);
        end
    end
end
end


function veLyDoLoai(fig, B, OI, tenDep, iNoi)
%VELYDOLOAI Tỉ lệ khung theo lý do loại, xếp chồng, một khung mỗi phương pháp
tl = tiledlayout(fig, 1, numel(B.methods), 'TileSpacing', 'compact', 'Padding', 'compact');

% 'none' là khung ĐƯỢC NHẬN chứ không phải một lý do loại - để nó màu xanh lục
% và nằm dưới đáy cột, phần còn lại của cột đọc ngay ra là phần mất.
mauLy = [OI.lucLam; OI.xanhNhat; OI.cam; OI.tim];

for iMet = 1:numel(B.methods)
    ax = nexttile(tl);
    H  = squeeze(B.rejectHist(:, iMet, :, iNoi));       % reason × snr

    % Chuẩn hóa theo cột: số khung mỗi mức SNR khác nhau giữa ba phương pháp
    % (hop 128 so với hop 205), nên vẽ số đếm thô là so ba thước đo khác nhau.
    tong = sum(H, 1);
    tong(tong == 0) = 1;
    P = 100 * H ./ tong;

    b = bar(ax, B.snrDb, P', 'stacked', 'BarWidth', 1, 'EdgeColor', 'none');
    for r = 1:numel(B.reasons)
        b(r).FaceColor   = mauLy(r, :);
        b(r).DisplayName = B.reasons{r};
    end

    xlim(ax, [min(B.snrDb)-1.25 max(B.snrDb)+1.25]);
    ylim(ax, [0 100]);
    xticks(ax, min(B.snrDb):5:max(B.snrDb));
    box(ax, 'on');
    xlabel(ax, 'SNR [dB]');
    if iMet == 1
        ylabel(ax, 'Tỉ lệ khung [%]');
    end
    title(ax, tenDep{iMet});
    if iMet == numel(B.methods)
        legend(ax, 'Location', 'eastoutside');
    end
end

title(tl, sprintf('Kết cục của từng khung theo SNR, nhiễu %s', B.noises{iNoi}), ...
    'FontWeight', 'bold');
subtitle(tl, 'Phần "level" còn lại ở SNR cao là khung khoảng lặng và khung vắt qua biên tone');
end


function veChiPhi(fig, B, OI, tenDep)
%VECHIPHI Thời gian đo được so với số phép nhân lý thuyết
ax   = axes(fig);
cats = categorical(tenDep, tenDep);

yyaxis(ax, 'left');
bar(ax, cats, B.msPerAudioSec, 0.55, 'FaceColor', OI.xanh, 'EdgeColor', 'none');
ylabel(ax, 'Thời gian đo được [ms / giây âm thanh]');
ylim(ax, [0 1.45 * max(B.msPerAudioSec)]);
ax.YAxis(1).Color = OI.xanh;

yyaxis(ax, 'right');

% Chỉ dấu chấm, KHÔNG nối đường. Trục hoành là ba hạng mục rời rạc chứ không
% phải một đại lượng liên tục; nối chúng lại là vẽ ra một xu hướng không tồn
% tại, và người đọc sẽ đọc độ dốc của nó.
plot(ax, cats, B.mulPerAudioSec/1e3, 'o', 'LineStyle', 'none', 'MarkerSize', 8, ...
    'MarkerFaceColor', OI.camDam, 'Color', OI.camDam);
ylabel(ax, 'Phép nhân lý thuyết [nghìn / giây âm thanh]');
ylim(ax, [0 1.45 * max(B.mulPerAudioSec/1e3)]);
ax.YAxis(2).Color = OI.camDam;

% Con số đáng nói nhất của hình này: giá một phép nhân. Goertzel ít phép nhân
% nhất mà KHÔNG nhanh nhất, vì nó là vòng lặp MATLAB thông dịch còn fft và
% filter là mã biên dịch. Không ghi ra thì người đọc kết luận sai rằng hai trục
% lệch nhau là do đo sai.
nsMoiPhep = 1e6 * B.msPerAudioSec ./ B.mulPerAudioSec;
yleTrai   = 0.10 * max(B.msPerAudioSec);
yyaxis(ax, 'left');
for i = 1:numel(tenDep)
    % Đẩy nhãn lên khỏi đỉnh cột một khoảng. Đặt đúng đỉnh cột thì ở nhánh ngân
    % hàng bộ lọc nó rơi trùng dấu chấm của trục phải - hai đại lượng khác nhau
    % tình cờ cùng độ cao.
    text(ax, cats(i), B.msPerAudioSec(i) + yleTrai, ...
        sprintf('%.1f ns mỗi phép nhân', nsMoiPhep(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 9, 'Color', [0.25 0.25 0.25]);
end

grid(ax, 'on');
box(ax, 'on');
title(ax, 'Chi phí tính toán: đo được (cột) và lý thuyết (điểm)');
% Ghi rõ đây là một lần chạy trên một máy. Cột thời gian chênh tới 3 lần giữa
% các lần chạy trên cùng máy này; chỉ tỉ số giữa ba nhánh mới là kết quả.
subtitle(ax, {sprintf('Quy về một giây âm thanh: FFT %.1f khung mỗi giây, hai nhánh kia %.1f', ...
                      B.framesPerSec(1), B.framesPerSec(2)), ...
              'Cột thời gian là một lần chạy trên một máy; chỉ tỉ số giữa ba nhánh mới ổn định'});
end


function veQuetNguong(fig, B, OI, tenDep, iNoi)
%VEQUETNGUONG Độ chính xác theo SNR khi hạ ngưỡng năng lượng - rủi ro R2
tl = tiledlayout(fig, 1, numel(B.methods), 'TileSpacing', 'compact', 'Padding', 'compact');

mauEn = [OI.xanh; OI.cam; OI.tim];

for iMet = 1:numel(B.methods)
    ax = nexttile(tl);
    hold(ax, 'on');
    for iEn = 1:numel(B.energyRatios)
        plot(ax, B.snrDb, squeeze(B.accMean(iMet, :, iNoi, iEn)), '-o', ...
            'Color', mauEn(iEn, :), 'MarkerFaceColor', mauEn(iEn, :), ...
            'LineWidth', 1.6, 'MarkerSize', 4.5, ...
            'DisplayName', sprintf('energyRatio = %.2f', B.energyRatios(iEn)));
    end
    hold(ax, 'off');

    grid(ax, 'on');
    box(ax, 'on');
    xlim(ax, [min(B.snrDb) max(B.snrDb)]);
    ylim(ax, [-0.03 1.05]);
    xticks(ax, min(B.snrDb):5:max(B.snrDb));
    xlabel(ax, 'SNR [dB]');
    if iMet == 1
        ylabel(ax, 'Độ chính xác');
        legend(ax, 'Location', 'southeast');
    end
    title(ax, tenDep{iMet});
end

title(tl, sprintf('Ảnh hưởng của ngưỡng năng lượng, nhiễu %s', B.noises{iNoi}), ...
    'FontWeight', 'bold');
subtitle(tl, 'energyRatio = 0.70 là giá trị đang dùng; đặt bằng 0 là bỏ hẳn điều kiện năng lượng');
end
