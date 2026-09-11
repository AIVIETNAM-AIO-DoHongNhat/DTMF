function ui_plot_spec(ax, y, fs)
%UI_PLOT_SPEC Vẽ phổ đồ (spectrogram, STFT) của tín hiệu.
%   UI_PLOT_SPEC(AX, Y, FS) vẽ phổ đồ của Y lên trục AX, với tham số STFT
%   khớp khung FFT đối chứng (Hamming 256 mẫu, chồng lấp 128, NFFT 256).
%
%   Đầu vào:
%       ax - uiaxes đích (AxSpec trong DTMFApp.mlapp).
%       y  - 1×N double, tín hiệu cần vẽ.
%       fs - tần số lấy mẫu [Hz].
%
%   See also ui_refresh, spectrogram, dtmf_decode_fft.

% TODO(C):
%   spectrogram() khi không có đầu ra sẽ vẽ vào trục hiện hành (gca), không
%   nhận trực tiếp uiaxes; vì vậy nên lấy đầu ra rồi tự vẽ lên ax:
%       [s, f, tt] = spectrogram(y, hamming(256), 128, 256, fs);
%       imagesc(ax, tt, f, 10*log10(abs(s).^2)); axis(ax, 'xy');
%   Giới hạn trục y tới ~1700 Hz (bao trọn 1477 Hz kèm lề). Nếu cần quan
%   sát hài bậc 2 của nhóm cột (2418–2954 Hz) thì mở rộng tới ~3000 Hz.
%   Đánh dấu 7 tần số chuẩn bằng các đường nét chấm: yline(ax, f, ':').

error('ui_plot_spec:notImplemented', 'TODO: cai dat ui_plot_spec.');

end
