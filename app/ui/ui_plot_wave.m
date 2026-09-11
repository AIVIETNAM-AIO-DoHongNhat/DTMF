function ui_plot_wave(ax, y, fs, meta)
%UI_PLOT_WAVE Vẽ dạng sóng, tô vùng tone và gắn nhãn phím.
%   UI_PLOT_WAVE(AX, Y, FS, META) vẽ Y theo thời gian lên trục AX; nếu có
%   META thì tô nền các vùng tone và ghi nhãn phím tương ứng.
%
%   Đầu vào:
%       ax   - uiaxes đích (AxWave trong DTMFApp.mlapp).
%       y    - 1×N double, tín hiệu cần vẽ.
%       fs   - tần số lấy mẫu [Hz].
%       meta - struct từ dtmf_generate (.onsets/.offsets/.keys), hoặc []
%              nếu không có nhãn thời gian.
%
%   Ghi chú:
%       CHỈ được gọi từ tầng UI (app/ui/*.m) - không gọi từ src/.
%
%   See also ui_refresh, dtmf_generate.

% TODO(C):
%   t = (0:numel(y)-1)/fs;
%   plot(ax, t, y);
%   Nếu có meta.onsets: tô nền vùng [onsets(i) offsets(i)] bằng patch(),
%   ghi nhãn meta.keys(i) phía trên mỗi vùng.
%   xlabel/ylabel (có đơn vị), xlim([0 t(end)]).

error('ui_plot_wave:notImplemented', 'TODO: cai dat ui_plot_wave.');

end
