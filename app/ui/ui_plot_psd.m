function ui_plot_psd(ax, y, fs, yRef)
%UI_PLOT_PSD Vẽ phổ công suất ước lượng Welch, tùy chọn chồng phổ của tín hiệu gốc
% Cho thấy tín hiệu chứa những tần số nào và nhiễu nâng nền phổ lên tới đâu
%   UI_PLOT_PSD(AX, Y, FS) vẽ phổ công suất một phía của Y [dB/Hz] trong dải
%   0-2000 Hz, kèm bảy đường tần số chuẩn và hai dải tô nền nhóm hàng, nhóm cột.
%   UI_PLOT_PSD(AX, Y, FS, YREF) vẽ thêm phổ của YREF bằng nét xám mảnh, nằm
%   dưới nét chính. DTMFApp truyền Y = y[n] và YREF = x[n]: khoảng cách giữa
%   hai nét chính là phần nền nhiễu mà kênh vừa cộng vào.
%
%   Các bước hoạt động:
%       1. Y rỗng hoặc ngắn hơn một cửa sổ 256 mẫu: xóa trục, ghi lý do, thoát.
%       2. pwelch với cửa sổ Hamming 256, chồng lấp 128, NFFT 256 - cùng cách
%          chia khung với dtmf_decode_fft. Độ phân giải 31.25 Hz nên đỉnh tone
%          nhô khỏi nền nhiễu cỡ đúng như trong một khung giải mã, không vọt
%          lên như phổ của cả tín hiệu dài 8000 mẫu.
%       3. + eps trước log10: x[n] có khoảng lặng bằng đúng 0.
%       4. Trục y lấy đỉnh cao nhất của cả hai nét làm mốc, xuống 70 dB - đủ
%          thấy nền nhiễu ở SNR 30 dB mà đỉnh tone không bị ép dẹt.
%
%   Nhãn nhóm hàng / nhóm cột đặt theo tọa độ chuẩn hóa của trục và dải tô
%   nền cao vượt hẳn khung nhìn, nên ui_refresh đổi YLim để hai trục phổ cùng
%   thang mà không phải sửa lại hai thứ đó.
%
%   Input:
%       ax: uiaxes đích (AxPsdX hoặc AxPsd trong DTMFApp).
%       y: 1×N double, tín hiệu cần vẽ phổ.
%       fs: 1×1 double, tần số lấy mẫu [Hz].
%       yRef: 1×N double, tín hiệu gốc để so; bỏ trống hoặc rỗng thì không vẽ.
%
%   Example:
%       x = dtmf_generate('59');
%       ui_plot_psd(uiaxes(uifigure), dtmf_addnoise(x, 'snrDb', 10), 8000, x)

if nargin < 4
    yRef = [];
end

% Hai con số này là hợp đồng với dtmf_decode_fft, giống ui_plot_spec.
frameN = 256;
hop    = 128;

if isempty(y)
    cla(ax);
    title(ax, 'Chưa có tín hiệu');
    return
end

if numel(y) < frameN
    cla(ax);
    title(ax, sprintf('Tín hiệu ngắn hơn %d mẫu, chưa đủ một cửa sổ để ước lượng phổ', frameN));
    return
end

M = ui_theme();
T = dtmf_table();

% Bước 2 và 3.
[P, f] = pwelch(y(:), hamming(frameN), frameN - hop, frameN, fs);
PdB = 10 * log10(P + eps);

coRef = numel(yRef) >= frameN;
if coRef
    Pr   = pwelch(yRef(:), hamming(frameN), frameN - hop, frameN, fs);
    PrdB = 10 * log10(Pr + eps);
end

% Bước 4. Đỉnh chỉ tính trong dải đang nhìn.
fMax = min(2000, fs / 2);
trong = f <= fMax;
dinh = max(PdB(trong));
if coRef
    dinh = max(dinh, max(PrdB(trong)));
end
if ~isfinite(dinh)
    dinh = 0;
end
yl = [dinh - 70, dinh + 12];

cla(ax);
hold(ax, 'on');

% Dải tô nền hai nhóm, rộng thêm 20 Hz mỗi bên cho đỉnh không chạm mép. Cao
% từ -1000 tới +1000 dB để không bao giờ hở khi trục y đổi thang.
nhom = {T.rowHz, T.colHz};
ten  = {'nhóm hàng', 'nhóm cột'};
for k = 1:2
    a = min(nhom{k}) - 20;
    b = max(nhom{k}) + 20;
    patch(ax, [a b b a], [-1000 -1000 1000 1000], M.nhanNhat, ...
        'EdgeColor', 'none', 'HitTest', 'off');
    text(ax, (a + b) / 2 / fMax, 0.96, ten{k}, 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'FontSize', 8, 'Color', M.chuPhu);
end

for f0 = [T.rowHz T.colHz]
    xline(ax, f0, ':', 'Color', M.chuMo, 'Alpha', 0.6);
end

% Không vẽ chú giải: nó đè lên nét phổ ở đúng góc trên phải, nơi nhóm cột
% nằm. Nét xám mảnh là tín hiệu gốc - DTMFApp ghi điều đó ngay trên tiêu đề.
if coRef
    plot(ax, f, PrdB, 'Color', M.chuMo, 'LineWidth', 0.8);
end
plot(ax, f, PdB, 'Color', M.nhan, 'LineWidth', 1.1);

hold(ax, 'off');

xlim(ax, [0 fMax]);
ylim(ax, yl);
xlabel(ax, 'Tần số [Hz]');
ylabel(ax, 'PSD [dB/Hz]');
title(ax, sprintf('Phổ công suất Welch, Hamming %d mẫu, chồng lấp %d mẫu', ...
    frameN, frameN - hop));

end
