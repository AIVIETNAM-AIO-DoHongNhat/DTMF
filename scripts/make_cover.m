%% make_cover.m
% MAKE_COVER Dựng hình minh hoạ trang bìa vào results/figures/bia_minh_hoa.*
%
% Hình gồm năm khung, đọc từ trái sang phải, trên xuống dưới:
%   (a) phổ đồ STFT của chuỗi "0912345" có nhiễu AWGN, SNR 20 dB (hàng trên);
%   (b) bàn phím 4x3 với cặp tần số (hàng, cột) của phím "5";
%   (c)-(e) cùng một khung của phím "5" đo bằng ba phương pháp của đề tài.
% Mọi đường cong đều tính bằng chính các hàm trong src/ (dtmf_generate,
% dtmf_addnoise, goertzel_power, design_bpf_bank), không vẽ tay.
%
% Màu phương pháp giữ đúng quy ước của make_figures (Okabe-Ito): FFT xanh
% dương, Goertzel cam đất, ngân hàng bộ lọc xanh lục lam. Phím và cặp tần số
% đang xét tô màu xanh đậm trung tính để không trùng với màu của phương pháp.
%
% Cách dùng:  cd <repo>; addpath('scripts'); make_cover; publish_figures

clear;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));

outDir = fullfile(root, 'results', 'figures');
if ~isfolder(outDir)
    mkdir(outDir);
end

%% Tham số và màu
fs   = 8000;
T    = dtmf_table();
fStd = [T.rowHz T.colHz];
fOn  = [770 1336];                          % cặp tần số của phím "5"
xLim = [560 1640];                          % dải tần hiển thị ở (b)-(e)

C = struct( ...
    'fft',  [  0 114 178]/255, ...          % Okabe-Ito xanh dương
    'goer', [213  94   0]/255, ...          % Okabe-Ito cam đất
    'bank', [  0 158 115]/255, ...          % Okabe-Ito xanh lục lam
    'nhan', [0.12 0.23 0.37], ...           % xanh đậm: phím và cặp tần số đang xét
    'chu',  [0.15 0.15 0.18], ...           % chữ chính
    'phu',  [0.42 0.44 0.48], ...           % chữ phụ, trục
    'luoi', [0.80 0.81 0.83]);              % đường tham chiếu
font = 'Times New Roman';

%% Dữ liệu
rng(2026);
[x, ~, meta] = dtmf_generate('0912345', 'fs', fs);
y  = dtmf_addnoise(x, 'snrDb', 20, 'type', 'awgn', 'fs', fs);
x5 = dtmf_generate('5', 'fs', fs);          % 800 mẫu, dùng cho (c)-(e)

%% Mặt vẽ
fig = figure('Visible', 'off', 'Position', [100 100 780 470]);
theme(fig, 'light');                        % theme trước, Color sau (xem make_figures)
set(fig, 'Color', 'w', 'DefaultAxesFontName', font, 'DefaultTextFontName', font, ...
    'DefaultAxesFontSize', 8, 'DefaultTextFontSize', 8);
tl = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

try
    vePhoDo(nexttile(tl, 1, [1 4]), y, meta, fs, fStd, xLim, C);
    veBanPhim(nexttile(tl, 5), T, fOn, C);
    veFft(nexttile(tl, 6), x5, fs, fStd, fOn, xLim, C);
    veGoertzel(nexttile(tl, 7), x5, fs, fStd, fOn, xLim, C);
    veNganHang(nexttile(tl, 8), fs, fStd, fOn, xLim, C);

    ten = fullfile(outDir, 'bia_minh_hoa');
    exportgraphics(fig, [ten '.png'], 'Resolution', 300, 'BackgroundColor', 'white');
    exportgraphics(fig, [ten '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'white');
catch ME
    delete(fig);
    rethrow(ME);
end
delete(fig);
fprintf('Da ghi %s.png va .pdf\n', ten);


%% ===================== Hàm phụ =====================

function veBanPhim(ax, T, fOn, C)
%VEBANPHIM Bàn phím 4x3; hàng/cột của phím đang xét nối với nhãn tần số
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [-1.45 3.05]);
ylim(ax, [-0.1 5.0]);
[rOn, cOn] = find(T.keys == '5');

for r = 1:4
    for c = 1:3
        on = (r == rOn && c == cOn);
        mau = [1 1 1];
        if on
            mau = C.nhan;
        end
        rectangle(ax, 'Position', [c-0.95, 4-r+0.05, 0.9, 0.9], 'Curvature', 0.18, ...
            'FaceColor', mau, 'EdgeColor', C.nhan, 'LineWidth', 1.2);
        mauChu = C.nhan;
        if on
            mauChu = [1 1 1];
        end
        text(ax, c-0.5, 4-r+0.5, T.keys(r, c), 'HorizontalAlignment', 'center', ...
            'FontSize', 13, 'FontWeight', 'bold', 'Color', mauChu);
    end
end

for r = 1:4
    on = T.rowHz(r) == fOn(1);
    text(ax, -0.15, 4-r+0.5, sprintf('%d', T.rowHz(r)), ...
        'HorizontalAlignment', 'right', 'FontSize', 8, ...
        'FontWeight', ifelse(on, 'bold', 'normal'), 'Color', ifelse(on, C.nhan, C.phu));
end
for c = 1:3
    on = T.colHz(c) == fOn(2);
    text(ax, c-0.5, 4.3, sprintf('%d', T.colHz(c)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, ...
        'FontWeight', ifelse(on, 'bold', 'normal'), 'Color', ifelse(on, C.nhan, C.phu));
end
text(ax, 1.5, 4.8, 'Nhóm cao, cột (Hz)', 'HorizontalAlignment', 'center', ...
    'FontSize', 7.5, 'FontAngle', 'italic', 'Color', C.phu);
text(ax, -1.2, 2.0, 'Nhóm thấp, hàng (Hz)', 'HorizontalAlignment', 'center', ...
    'Rotation', 90, 'FontSize', 7.5, 'FontAngle', 'italic', 'Color', C.phu);
title(ax, '(b) Phím “5” = 770 Hz + 1336 Hz', 'FontWeight', 'normal', 'Color', C.chu);
end


function vePhoDo(ax, y, meta, fs, fStd, xLim, C)
%VEPHODO Phổ đồ STFT của cả chuỗi, thang xám-xanh một sắc độ
[S, F, Tt] = spectrogram(y, hamming(256), 232, 2048, fs);
P = 10*log10(abs(S).^2 + eps);
P = P - max(P(:));
imagesc(ax, Tt, F, P);
axis(ax, 'xy');
hold(ax, 'on');
clim(ax, [-40 0]);                          % nền nhiễu (khoảng -45 dB) gần như trắng

% Thang tuần tự MỘT sắc độ: trắng -> xanh đậm (không cầu vồng)
n = 256;
t = linspace(0, 1, n)';
colormap(ax, (1 - t).*[1 1 1] + t.*C.nhan);

for f = fStd
    yline(ax, f, ':', 'Color', C.phu, 'LineWidth', 0.8, 'Alpha', 0.7);
end
% Nhãn phím đặt trên từng âm
for i = 1:numel(meta.keys)
    tc = (meta.onsets(i) + meta.offsets(i))/2;
    text(ax, tc, xLim(2) - 45, meta.keys(i), 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', C.nhan);
end
ylim(ax, xLim);
yticks(ax, fStd);
xlabel(ax, 'Thời gian (s)');
ylabel(ax, 'Tần số (Hz)');
kieuTruc(ax, C);
xtickCoPhay(ax);
cb = colorbar(ax);
cb.Label.String = 'Công suất (dB)';
cb.Color = C.phu;
cb.Ticks = -40:10:0;
title(ax, '(a) Phổ đồ STFT của chuỗi “0912345”, nhiễu AWGN, SNR = 20 dB', ...
    'FontWeight', 'normal', 'Color', C.chu);
end


function veFft(ax, x5, fs, fStd, fOn, xLim, C)
%VEFFT Phổ biên độ của một khung 256 mẫu, cửa sổ Hamming
N = 256;
khung = x5(273:272+N);                      % nằm giữa âm 800 mẫu
X = abs(fft(khung(:) .* hamming(N), 8192));
f = (0:numel(X)-1)' * fs / numel(X);
XdB = 20*log10(X / max(X) + 1e-6);
hold(ax, 'on');
veMoc(ax, fStd, fOn, C);
area(ax, f, XdB, -70, 'FaceColor', C.fft, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
plot(ax, f, XdB, 'Color', C.fft, 'LineWidth', 1.4);
xlim(ax, xLim);
xticks(ax, 600:400:1600);
ylim(ax, [-70 5]);
ylabel(ax, 'Biên độ (dB)');
xlabel(ax, 'Tần số (Hz)');
kieuTruc(ax, C);
title(ax, '(c) FFT, Hamming, N = 256', 'FontWeight', 'normal', 'Color', C.chu);
end


function veGoertzel(ax, x5, fs, fStd, fOn, xLim, C)
%VEGOERTZEL Công suất chuẩn hoá E_j tại 7 bin, tính bằng goertzel_power
N = 205;
khung = x5(206:205+N);                      % khung thứ hai, nằm trọn trong âm
k = round(N * fStd / fs);
E = zeros(size(fStd));
for j = 1:numel(fStd)
    E(j) = goertzel_power(khung, k(j), N);
end
E = E / (N * sum(khung.^2) / 2);            % chuẩn hoá như bộ giải mã
hold(ax, 'on');
veMoc(ax, fStd, fOn, C);
stem(ax, k * fs / N, E, 'filled', 'Color', C.goer, 'MarkerFaceColor', C.goer, ...
    'MarkerSize', 4.5, 'LineWidth', 1.3);
xlim(ax, xLim);
xticks(ax, 600:400:1600);
ylim(ax, [0 0.6]);
yticks(ax, 0:0.2:0.6);
ylabel(ax, 'E_j');
xlabel(ax, 'Tần số (Hz)');
kieuTruc(ax, C);
ytickCoPhay(ax);
title(ax, '(d) Goertzel, N = 205', 'FontWeight', 'normal', 'Color', C.chu);
end


function veNganHang(ax, fs, fStd, fOn, xLim, C)
%VENGANHANG Đáp ứng biên độ của 7 bộ cộng hưởng chuẩn, r = 0,99
bank = design_bpf_bank('fs', fs, 'coeffs', '', 'withHarm', false);
mo = 0.55*[1 1 1] + 0.45*C.bank;            % bộ không kích hoạt: nhạt hơn
hold(ax, 'on');
veMoc(ax, fStd, fOn, C);
for j = 1:numel(bank)
    [H, f] = freqz(bank(j).b, bank(j).a, 8192, fs);
    on = any(bank(j).f == fOn);
    plot(ax, f, 20*log10(abs(H)), 'Color', ifelse(on, C.bank, mo), ...
        'LineWidth', ifelse(on, 1.8, 1.0));
end
xlim(ax, xLim);
xticks(ax, 600:400:1600);
ylim(ax, [-40 3]);
yticks(ax, -40:10:0);
ylabel(ax, '|H| (dB)');
xlabel(ax, 'Tần số (Hz)');
kieuTruc(ax, C);
title(ax, '(e) Ngân hàng bộ lọc, r = 0,99', 'FontWeight', 'normal', 'Color', C.chu);
end


function veMoc(ax, fStd, fOn, C)
%VEMOC Đường dóng tại 7 tần số chuẩn; cặp tần số đang xét đậm hơn
for f = fStd
    if any(f == fOn)
        xline(ax, f, '-', 'Color', C.nhan, 'LineWidth', 0.9, 'Alpha', 0.6);
    else
        xline(ax, f, ':', 'Color', C.luoi, 'LineWidth', 0.9);
    end
end
end


function kieuTruc(ax, C)
%KIEUTRUC Trục nhẹ: không khung trên/phải, lưới ngang mờ
box(ax, 'off');
ax.XColor = C.phu;
ax.YColor = C.phu;
ax.TickDir = 'out';
ax.LineWidth = 0.8;
ax.YGrid = 'on';
ax.GridColor = C.luoi;
ax.GridAlpha = 0.6;
ax.Layer = 'top';
end


function xtickCoPhay(ax)
%XTICKCOPHAY Dấu thập phân kiểu Việt Nam trên trục x
ax.XTickLabel = strrep(compose('%g', ax.XTick), '.', ',');
end


function ytickCoPhay(ax)
%YTICKCOPHAY Dấu thập phân kiểu Việt Nam trên trục y
ax.YTickLabel = strrep(compose('%g', ax.YTick), '.', ',');
end


function v = ifelse(dk, a, b)
%IFELSE Chọn a nếu dk đúng, ngược lại chọn b
if dk
    v = a;
else
    v = b;
end
end
