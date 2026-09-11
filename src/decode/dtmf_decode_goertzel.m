function [keys, info] = dtmf_decode_goertzel(y, opt)
%DTMF_DECODE_GOERTZEL Giải mã DTMF bằng thuật toán Goertzel.
%   [KEYS, INFO] = DTMF_DECODE_GOERTZEL(Y) giải mã tín hiệu Y với các
%   tham số mặc định.
%
%   [KEYS, INFO] = DTMF_DECODE_GOERTZEL(Y, Name, Value) thay đổi tham số
%   qua các cặp tên–giá trị. Chữ ký hàm GIỐNG HỆT dtmf_decode_fft và
%   dtmf_decode_filterbank (xem CONTRACTS.md).
%
%   Đầu vào:
%       y - 1×N double, tín hiệu cần giải mã.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs'     - tần số lấy mẫu [Hz] (8000).
%       'frameN' - độ dài khung [mẫu] (205); độ phân giải tần số
%                  Δf = fs/N = 8000/205 ≈ 39.02 Hz (xem kế hoạch, mục 05).
%       'hop'    - bước nhảy giữa hai khung liên tiếp [mẫu] (205).
%
%   Đầu ra:
%       Giống hệt dtmf_decode_fft: keys và info.E / .rowIdx / .colIdx /
%       .conf / .tFrame / .reject.
%
%   Bảng chỉ số bin chuẩn, k = round(N*f/fs) với N = 205, fs = 8000 Hz:
%       Nhóm hàng:  697 -> 18   770 -> 20   852 -> 22   941 -> 24
%       Nhóm cột:  1209 -> 31  1336 -> 34  1477 -> 38
%
%   Tham khảo:
%       [1] G. Goertzel, "An algorithm for the evaluation of finite
%           trigonometric series," Amer. Math. Monthly, vol. 65, no. 1,
%           pp. 34–35, 1958.
%       [2] Gói đặc tả #4 (tổ S2 + R2).
%
%   LƯU Ý: không gọi figure/plot/disp/sound trong hàm này.
%
%   See also goertzel_power, dtmf_segment, dtmf_decide, dtmf_decode_fft.

arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 205
    opt.hop (1,1) double = 205
end

% TODO(C):
%   1. seg = dtmf_segment(y, 'fs',opt.fs, 'frameN',opt.frameN, 'hop',opt.hop);
%   2. k = round(opt.frameN * [697 770 852 941 1209 1336 1477] / opt.fs);
%      thêm 1 bin hài bậc 2 (bin 2k của tần số mạnh nhất, hoặc một ước
%      lượng đơn giản tương đương).
%   3. Với mỗi khung i và mỗi tần số j:
%      E(j,i) = goertzel_power(frame, k(j), opt.frameN)   (công suất |X[k]|^2).
%   4. [rowIdx, colIdx, conf, reject] = dtmf_decide(E(:,i));
%   5. Chống dội (debounce): gộp các khung liên tiếp cùng phím thành một
%      ký tự. Điền info và trả keys.

keys = ''; %#ok<NASGU>
info = struct('E', [], 'rowIdx', [], 'colIdx', [], 'conf', [], 'tFrame', [], 'reject', {{}}); %#ok<NASGU>
error('dtmf_decode_goertzel:notImplemented', 'TODO: cai dat dtmf_decode_goertzel (xem Goi dac ta #4).');

end
