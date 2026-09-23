function ui_plot_wave(ax, y, fs, meta)
%UI_PLOT_WAVE Vẽ dạng sóng, tô nền vùng tone và ghi nhãn phím
% Cho thấy tín hiệu dài bao nhiêu, tiếng nào nằm ở đâu, và phím nào ứng với tiếng đó
%   UI_PLOT_WAVE(AX, Y, FS, META) vẽ Y theo thời gian lên trục AX. Có META thì
%   tô nền từng vùng tone và ghi nhãn phím phía trên; META rỗng thì chỉ vẽ sóng.
%
%   Các bước hoạt động:
%       1. Y rỗng nghĩa là chưa có tín hiệu: xóa trục rồi thoát.
%       2. Chốt biên độ a = max(abs(Y)) TRƯỚC khi vẽ, vì vùng tô nền cần biết
%          chiều cao. Y toàn 0 cho a = 0, khi đó dùng a = 1 để ylim hợp lệ.
%       3. Tô nền các vùng [onsets(i) offsets(i)] rồi mới vẽ đường sóng đè lên,
%          để đường sóng không bị nền che.
%       4. Ghi nhãn phím ở tâm mỗi vùng; đặt trục và giới hạn.
%
%   META phải có đủ ba trường .onsets .offsets .keys thì mới tô nền. Giao diện
%   lúc mới mở, hoặc khi người dùng nạp một file wav lạ, đều không có META -
%   khi đó hàm vẫn phải vẽ được chứ không được ném lỗi.
%
%   Input:
%       ax: uiaxes đích (AxWave trong DTMFApp).
%       y: 1×N double, tín hiệu cần vẽ; rỗng thì trục được xóa trắng.
%       fs: 1×1 double, tần số lấy mẫu [Hz].
%       meta: struct từ dtmf_generate (.onsets .offsets [s], .keys), hoặc []
%             nếu không có nhãn thời gian.
%
%   Example:
%       [x, ~, m] = dtmf_generate('59');
%       ui_plot_wave(uiaxes(uifigure), x, 8000, m)

if isempty(y)
    cla(ax);
    title(ax, 'Chưa có tín hiệu');
    return
end

t = (0:numel(y)-1) / fs;

% Biên độ chốt trước: vùng tô nền phải cao bằng khung nhìn. Tín hiệu toàn 0 cho
% a = 0, mà ylim([0 0]) là lỗi - nên ép về 1.
a = max(abs(y));
if ~isfinite(a) || a == 0
    a = 1;
end
yl = 1.1 * a * [-1 1];

cla(ax);
hold(ax, 'on');

% Tô nền TRƯỚC, vẽ sóng SAU: ngược lại thì nền phủ mất đường sóng.
coMeta = ~isempty(meta) && isstruct(meta) && ...
         all(isfield(meta, {'onsets', 'offsets', 'keys'}));
if coMeta
    % Lấy số vùng theo trường NGẮN NHẤT. Một meta lắp ghép tay có thể lệch độ
    % dài giữa ba trường, và một lỗi "index exceeds" giữa lúc demo thì không
    % đáng để đánh đổi lấy hai dòng này.
    n = min([numel(meta.onsets), numel(meta.offsets), numel(meta.keys)]);
    for i = 1:n
        x1 = meta.onsets(i);
        x2 = meta.offsets(i);
        patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], [0.90 0.45 0.13], ...
            'FaceAlpha', 0.15, 'EdgeColor', 'none');
        text(ax, (x1 + x2)/2, 0.92 * a, meta.keys(i), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
end

plot(ax, t, y, 'Color', [0.10 0.35 0.70]);

hold(ax, 'off');
xlabel(ax, 'Thời gian [s]');
ylabel(ax, 'Biên độ');
title(ax, sprintf('Dạng sóng - %.0f Hz, %.3f s', fs, numel(y)/fs));

% t(end) = 0 khi tín hiệu dài đúng 1 mẫu; xlim phải luôn là khoảng thật sự.
xlim(ax, [0 max(t(end), 1/fs)]);
ylim(ax, yl);

end
