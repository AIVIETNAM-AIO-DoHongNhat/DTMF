function [keys, info] = dtmf_decode_fft(y, opt)
%DTMF_DECODE_FFT Giải mã DTMF bằng biến đổi Fourier nhanh (FFT).
%   [KEYS, INFO] = DTMF_DECODE_FFT(Y) giải mã tín hiệu Y với các tham số
%   mặc định.
%
%   [KEYS, INFO] = DTMF_DECODE_FFT(Y, Name, Value) thay đổi tham số qua
%   các cặp tên–giá trị. Chữ ký hàm GIỐNG HỆT dtmf_decode_goertzel và
%   dtmf_decode_filterbank (xem CONTRACTS.md).
%
%   Đầu vào:
%       y - 1×N double, tín hiệu cần giải mã.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs'     - tần số lấy mẫu [Hz] (8000).
%       'frameN' - độ dài khung = số điểm FFT [mẫu] (256), cửa sổ Hamming;
%                  độ phân giải tần số Δf = fs/N = 8000/256 = 31.25 Hz.
%       'hop'    - bước nhảy giữa hai khung liên tiếp [mẫu] (128),
%                  tức chồng lấp 50%.
%
%   Đầu ra:
%       keys - char 1×K, chuỗi phím giải mã được, theo thứ tự thời gian.
%       info - struct thông tin theo từng khung:
%           .E      - 8×nFrame double, công suất tại 7 tần số chuẩn
%                     [697 770 852 941 1209 1336 1477] Hz + 1 hài bậc 2.
%           .rowIdx - 1×nFrame, chỉ số hàng 1..4 (0: không quyết định).
%           .colIdx - 1×nFrame, chỉ số cột 1..3 (0: không quyết định).
%           .conf   - 1×nFrame, độ tin cậy thuộc [0, 1].
%           .tFrame - 1×nFrame, thời điểm của khung [s].
%           .reject - cellstr 1×nFrame, lý do loại:
%                     'none' | 'twist' | 'level' | 'harmonic'.
%
%   Cửa sổ Hamming (n = 0..N-1):
%       w[n] = 0.54 - 0.46*cos(2*pi*n/(N-1)).
%
%   Tham khảo:
%       [1] F. J. Harris, "On the use of windows for harmonic analysis
%           with the discrete Fourier transform," Proc. IEEE, vol. 66,
%           no. 1, pp. 51–83, 1978.
%       [2] Gói đặc tả #2 (tổ S2 + R1).
%
%   LƯU Ý: không gọi figure/plot/disp/sound trong hàm này.
%
%   See also dtmf_decode_goertzel, dtmf_decode_filterbank, dtmf_segment,
%   dtmf_decide.

arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 256
    opt.hop (1,1) double = 128
end

% TODO(C):
%   1. seg = dtmf_segment(y, 'fs',opt.fs, 'frameN',opt.frameN, 'hop',opt.hop);
%   2. Với mỗi khung: nhân cửa sổ Hamming, X = fft(win.*frame, frameN);
%      lấy công suất |X|^2 tại 8 bin gần nhất với 7 tần số chuẩn và
%      1 bin hài bậc 2. Dùng |X|^2 (không phải |X|) để cùng thang đo
%      công suất với goertzel_power - dtmf_decide giả định E là công suất.
%   3. [rowIdx, colIdx, conf, reject] = dtmf_decide(E(:,i));
%   4. Chống dội (debounce): gộp các khung liên tiếp cùng phím thành một
%      ký tự.
%   5. Điền info và trả keys.

keys = ''; %#ok<NASGU>
info = struct('E', [], 'rowIdx', [], 'colIdx', [], 'conf', [], 'tFrame', [], 'reject', {{}}); %#ok<NASGU>
error('dtmf_decode_fft:notImplemented', 'TODO: cai dat dtmf_decode_fft (xem Goi dac ta #2).');

end
