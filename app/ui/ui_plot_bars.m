function ui_plot_bars(ax, E, thr)
%UI_PLOT_BARS Vẽ 8 thanh công suất và đường ngưỡng quyết định.
%   UI_PLOT_BARS(AX, E, THR) vẽ biểu đồ cột công suất của khung đang chọn
%   lên trục AX, kèm đường ngưỡng nằm ngang THR.
%
%   Đầu vào:
%       ax  - uiaxes đích (AxBars trong DTMFApp.mlapp).
%       E   - 8×1 hoặc 1×8 double, công suất khung đang chọn tại 7 tần số
%             chuẩn và hài bậc 2 (cùng thứ tự với info.E).
%       thr - double vô hướng, ngưỡng quyết định (cùng đơn vị với E), vẽ
%             bằng đường nét đứt nằm ngang.
%
%   Ghi chú:
%       Đây là hình quan trọng nhất của buổi demo - cho thấy đúng cơ chế
%       quyết định: 1 đỉnh nhóm hàng + 1 đỉnh nhóm cột, các thanh còn lại
%       nằm dưới ngưỡng.
%
%   See also ui_refresh, dtmf_decide.

% TODO(C):
%   labels = {'697','770','852','941','1209','1336','1477','2f'};  % '2f': hài bậc 2
%   bar(ax, categorical(labels), E);
%   yline(ax, thr, 'r--');

error('ui_plot_bars:notImplemented', 'TODO: cai dat ui_plot_bars.');

end
