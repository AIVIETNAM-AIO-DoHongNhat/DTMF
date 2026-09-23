function ui_plot_bars(ax, E, thr)
%UI_PLOT_BARS Vẽ 8 thanh công suất của khung đang chọn kèm đường ngưỡng
% Nhìn một cái là thấy vì sao khung này được nhận hay bị loại
%   UI_PLOT_BARS(AX, E, THR) vẽ 8 giá trị của E thành 8 cột trên trục AX, kèm
%   một đường nằm ngang tại THR. Cột vượt ngưỡng được tô khác màu.
%
%   Các bước hoạt động:
%       1. E rỗng nghĩa là không có khung nào để vẽ: xóa trục rồi thoát.
%          E khác rỗng mà không đủ 8 phần tử là gọi sai, chốt lại ngay.
%       2. categorical(lab, lab) - tham số thứ HAI ghim thứ tự hạng mục.
%       3. bar(ax, ...) với FaceColor 'flat', tô riêng các cột vượt ngưỡng.
%       4. yline(ax, thr, 'r--') vẽ ngưỡng; giới hạn trục y chừa 15% lề trên.
%
%   Ngưỡng THR do dtmf_run tính, bằng 0.5*min(đỉnh hàng, đỉnh cột) - đó là luật
%   thứ 5 của dtmf_decide (hài bậc 2), luật DUY NHẤT trong năm luật vẽ được
%   thành một đường nằm ngang trong đơn vị của E. Bốn luật còn lại so sánh các
%   cột VỚI NHAU nên không có đường nào để vẽ.
%
%   Input:
%       ax: uiaxes đích (AxBars trong DTMFApp).
%       E: 8×1 hoặc 1×8 double, công suất đã chuẩn hóa của khung đang chọn,
%          cùng thứ tự với info.E; rỗng thì trục được xóa trắng.
%       thr: 1×1 double, ngưỡng quyết định [cùng đơn vị với E].
%
%   Example:
%       [~, info] = dtmf_decode_goertzel(dtmf_generate('5'));
%       ui_plot_bars(uiaxes(uifigure), info.E(:,2), 0.196)

% Nhãn lấy thẳng từ bảng tần số, không chép tay: luật §2 cho phép app/ui gọi
% dtmf_table vì đó là hằng số chứ không phải phép tính. '2f' là hài bậc 2.
T   = dtmf_table();
lab = [arrayfun(@(v) sprintf('%d', v), [T.rowHz T.colHz], 'UniformOutput', false), {'2f'}];

if isempty(E)
    cla(ax);
    title(ax, 'Không có khung nào được chọn');
    return
end

% Chốt trước khi vẽ. Thiếu nó, bar() ném 'X must be same length as Y' - một
% thông báo không chỉ ra được là lỗi của ai, trong khi ui_refresh chỉ ghi
% nguyên văn thông báo đó vào nhật ký cho người dùng đọc.
if numel(E) ~= 8
    error('ui_plot_bars:badSize', ...
        'E có %d phần tử; hình này vẽ đúng 8 (7 bin chuẩn + 1 hài bậc 2).', ...
        numel(E));
end

E = E(:)';

% ⚠️ categorical(lab) TỰ SẮP XẾP hạng mục theo thứ tự chữ cái: kết quả là
% 1209 1336 1477 2f 697 770 852 941. Hình vẫn có 8 cột, vẫn có nhãn tần số,
% vẫn có hai cột cao - chỉ là mỗi cột đứng dưới SAI NHÃN, và không có một chữ
% cảnh báo nào. Tham số thứ hai là thứ ghim đúng thứ tự của info.E.
cats = categorical(lab, lab);

b = bar(ax, cats, E);
b.FaceColor = 'flat';

% Cột vượt ngưỡng tô cam, còn lại xám: hai cột cam chính là hàng và cột mà
% dtmf_decide chọn, nên hình tự giải thích được quyết định.
b.CData = repmat([0.70 0.70 0.74], numel(E), 1);
b.CData(E > thr, :) = repmat([0.90 0.45 0.13], nnz(E > thr), 1);

yline(ax, thr, 'r--', 'ngưỡng', ...
    'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'bottom');

xlabel(ax, 'Tần số [Hz]');
ylabel(ax, 'Năng lượng đã chuẩn hóa');
title(ax, sprintf('Công suất theo bin - ngưỡng %.3f', thr));

% max(...) có thể bằng 0 khi khung im lặng; ylim([0 0]) là lỗi.
yTop = max([E, thr]);
if yTop <= 0
    yTop = 1;
end
ylim(ax, [0 yTop * 1.15]);

end
