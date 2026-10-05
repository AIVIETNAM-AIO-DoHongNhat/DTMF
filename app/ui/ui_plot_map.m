function ui_plot_map(ax, info, iSel)
%UI_PLOT_MAP Vẽ năng lượng 8 bin của mọi khung thành một bản đồ thời gian-tần số
% Cho thấy bộ giải mã tìm phím thế nào: khung nào được nhận, nhận ra hàng và cột nào
%   UI_PLOT_MAP(AX, INFO, ISEL) vẽ INFO.E (8×nFrame) thành ảnh: trục ngang là
%   tâm khung INFO.tFrame [s], trục dọc là 8 bin theo đúng thứ tự của E - bốn
%   tần số hàng, ba tần số cột, hài bậc 2. Khung được nhận có hai chấm trên
%   đúng hai bin mà dtmf_decide chọn; mỗi dải khung nhận liên tiếp cùng một
%   phím được ghi nhãn ở làn phía trên. Khung ISEL, khung đang vẽ ở trục thanh,
%   được đánh dấu bằng một đường đứt dọc.
%
%   Các bước hoạt động:
%       1. INFO rỗng: xóa trục rồi thoát. E không đủ 8 hàng là gọi sai.
%       2. imagesc(t, 1:8, E) rồi axis xy để bin 697 Hz nằm dưới cùng. Thang
%          màu CỐ ĐỊNH [0 0.5]: một cặp tone sạch cho mỗi bin chọn chừng 0.45,
%          nên cố định thang thì hai lần giải mã ở hai mức SNR so được với nhau;
%          thang tự động sẽ kéo nền nhiễu đậm lên khi tone yếu đi.
%       3. Vạch ngăn nhóm hàng / nhóm cột / hài; chấm hai bin của khung nhận.
%       4. Gom khung nhận liên tiếp cùng phím thành dải - đúng cách dtmf_debounce
%          gom: khung loại có rowIdx = 0 và cắt dải. Dải chỉ một khung ghi màu
%          xám vì dtmf_debounce bỏ dải ngắn hơn minRun = 2 (CONTRACTS §6(f)).
%       5. Đường đứt tại tFrame(iSel).
%
%   Hàm này KHÔNG quyết định gì: rowIdx, colIdx do dtmf_decide ghi sẵn, tên
%   phím tra từ dtmf_table - luật §2 cho phép app/ui đọc hằng số.
%
%   Input:
%       ax: uiaxes đích (AxMap trong DTMFApp).
%       info: struct số liệu theo khung của bộ giải mã (.E .rowIdx .colIdx
%             .tFrame), hoặc [] để xóa trục.
%       iSel: 1×1 double, khung đang chọn; 0 thì không đánh dấu khung nào.
%
%   Example:
%       [~, info] = dtmf_decode_goertzel(dtmf_generate('59'));
%       ui_plot_map(uiaxes(uifigure), info, 3)

if nargin < 3
    iSel = 0;
end

% Bước 1.
if isempty(info) || ~isstruct(info) || ~isfield(info, 'E') || isempty(info.E)
    cla(ax);
    title(ax, 'Chưa có khung nào');
    return
end

E = info.E;
if size(E, 1) ~= 8
    error('ui_plot_map:badSize', ...
        'E có %d hàng; bản đồ này vẽ đúng 8 bin (7 tần số chuẩn + 1 hài bậc 2).', ...
        size(E, 1));
end

n = size(E, 2);
t = info.tFrame(:)';
r = info.rowIdx(:)';
c = info.colIdx(:)';

M = ui_theme();
T = dtmf_table();
lab = [arrayfun(@(v) sprintf('%d', v), [T.rowHz T.colHz], 'UniformOutput', false), {'2f'}];

% Bước 2.
cla(ax);
hold(ax, 'on');
imagesc(ax, t, 1:8, E);
axis(ax, 'xy');
colormap(ax, M.cmap);
ax.CLim = [0 0.5];

% Bước 3.
yline(ax, 4.5, '-', 'Color', M.chuMo, 'Alpha', 0.5);
yline(ax, 7.5, '-', 'Color', M.chuMo, 'Alpha', 0.5);

nhan = r >= 1 & c >= 1;
if any(nhan)
    plot(ax, [t(nhan) t(nhan)], [r(nhan) 4 + c(nhan)], 'o', ...
        'MarkerSize', 3.5, 'MarkerFaceColor', [1 1 1], ...
        'MarkerEdgeColor', M.muc, 'LineWidth', 0.6);
end

% Bước 4. k = số thứ tự phím 1..12, 0 ở khung loại.
k = (r - 1) * 3 + c;
k(~nhan) = 0;
i = 1;
while i <= n
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
    text(ax, (t(i) + t(j)) / 2, 9.1, T.keys(r(i), c(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 10, 'Color', mau);
    i = j + 1;
end

% Bước 5.
if iSel >= 1 && iSel <= n
    xline(ax, t(iSel), '--', 'Color', M.muc, 'LineWidth', 0.8, 'Alpha', 0.7);
end

hold(ax, 'off');

yticks(ax, 1:8);
yticklabels(ax, lab);
ylim(ax, [0.5 9.7]);
if n > 1
    xlim(ax, [t(1) t(end)] + (t(2) - t(1)) / 2 * [-1 1]);
end
xlabel(ax, 'Thời gian [s]');
ylabel(ax, 'Bin [Hz]');
title(ax, sprintf('Năng lượng chuẩn hóa E_j của %d khung, thang màu 0 - 0.5', n));

end
