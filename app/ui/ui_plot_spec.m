function ui_plot_spec(ax, y, fs)
%UI_PLOT_SPEC Vẽ phổ đồ STFT, đúng tham số mà bộ giải mã FFT đang nhìn
% Cho thấy tại mỗi thời điểm tín hiệu chứa những tần số nào, đậm nhạt theo độ mạnh
%   UI_PLOT_SPEC(AX, Y, FS) vẽ phổ đồ của Y lên trục AX bằng cửa sổ Hamming 256
%   mẫu, chồng lấp 128, NFFT 256 - KHỚP ĐÚNG dtmf_decode_fft.
%
%   Các bước hoạt động:
%       1. Y ngắn hơn một cửa sổ (256 mẫu) thì spectrogram không chạy được:
%          xóa trục, ghi lý do rồi thoát.
%       2. spectrogram(...) rồi tự vẽ bằng imagesc. Gọi spectrogram KHÔNG lấy
%          đầu ra sẽ vẽ vào trục hiện hành (gca), không vào uiaxes.
%       3. axis xy - imagesc mặc định lật trục y, để nguyên thì tần số cao nằm
%          dưới đáy và hình đọc ngược.
%       4. Kẻ 7 đường tần số chuẩn lấy từ dtmf_table, giới hạn y là [0 3000].
%
%   Vì sao [0 3000] Hz: dải đó bao trọn cả 1477 Hz lẫn hài bậc 2 của nhóm cột
%   (2418–2954 Hz), tức đúng dải mà thanh thứ 8 của ui_plot_bars đang đo.
%
%   Tham số cửa sổ phải khớp dtmf_decode_fft. Lệch một tham số thì hình phổ
%   không còn là cái bộ giải mã nhìn thấy, và mọi giải thích dựa trên nó đều sai.
%
%   Input:
%       ax: uiaxes đích (AxSpec trong DTMFApp).
%       y: 1×N double, tín hiệu cần vẽ.
%       fs: 1×1 double, tần số lấy mẫu [Hz].
%
%   Example:
%       ui_plot_spec(uiaxes(uifigure), dtmf_generate('59'), 8000)

% Ba con số này là hợp đồng với dtmf_decode_fft, không phải tham số tự do.
frameN = 256;
hop    = 128;

if numel(y) < frameN
    cla(ax);
    title(ax, sprintf('Tín hiệu ngắn hơn %d mẫu, chưa đủ một cửa sổ để vẽ phổ đồ', frameN));
    return
end

[s, f, tt] = spectrogram(y, hamming(frameN), frameN - hop, frameN, fs);

% + eps chặn log10(0) = -Inf ở các ô im lặng. Thiếu nó, imagesc nhận -Inf và
% thang màu bị kéo giãn đến mức toàn hình thành một màu.
P = 10 * log10(abs(s).^2 + eps);

imagesc(ax, tt, f, P);

% imagesc mặc định lật trục y (YDir = 'reverse'). Để nguyên thì 0 Hz nằm trên
% đỉnh, hình đọc ngược mà nhìn vẫn "có vẻ đúng".
axis(ax, 'xy');

% Bảy tần số chuẩn lấy thẳng từ bảng, không chép tay - luật §2 cho phép
% app/ui gọi dtmf_table vì đó là hằng số chứ không phải phép tính.
T = dtmf_table();
for f0 = [T.rowHz T.colHz]
    yline(ax, f0, ':', 'Color', [1 1 1], 'Alpha', 0.55);
end

xlabel(ax, 'Thời gian [s]');
ylabel(ax, 'Tần số [Hz]');
% Ba con số trong tiêu đề lấy từ chính biến đang dùng, không gõ tay: tiêu đề
% ghi sai tham số còn tệ hơn không ghi, vì người đọc lấy nó làm căn cứ.
title(ax, sprintf('Phổ đồ STFT, cửa sổ Hamming %d mẫu, chồng lấp %d mẫu, thang [dB]', ...
    frameN, frameN - hop));
ylim(ax, [0 3000]);

end
