function [keys, info] = dtmf_decode_filterbank(y, opt)
%DTMF_DECODE_FILTERBANK Giải mã DTMF bằng ngân hàng 8 bộ lọc IIR song song.
%   [KEYS, INFO] = DTMF_DECODE_FILTERBANK(Y) giải mã tín hiệu Y với các
%   tham số mặc định.
%
%   [KEYS, INFO] = DTMF_DECODE_FILTERBANK(Y, Name, Value) thay đổi tham số
%   qua các cặp tên–giá trị. Chữ ký hàm GIỐNG HỆT dtmf_decode_fft và
%   dtmf_decode_goertzel (xem CONTRACTS.md).
%
%   Đầu vào:
%       y - 1×N double, tín hiệu cần giải mã.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs'     - tần số lấy mẫu [Hz] (8000).
%       'frameN' - độ dài khung dùng để tính năng lượng đầu ra [mẫu] (205).
%       'hop'    - bước nhảy giữa hai khung liên tiếp [mẫu] (205).
%
%   Đầu ra:
%       Giống hệt dtmf_decode_fft: keys và info.E / .rowIdx / .colIdx /
%       .conf / .tFrame / .reject.
%
%   Cơ sở lý thuyết:
%       Năng lượng đầu ra của bộ lọc j trong khung i:
%           E(j,i) = sum_{n thuộc khung i} y_j[n]^2,
%       với y_j[n] là đầu ra của bộ lọc thông dải thứ j khi đầu vào là y.
%
%   Tham khảo:
%       [1] Epic E4 (design_bpf_bank + Gói đặc tả #5).
%
%   LƯU Ý: không gọi figure/plot/disp/sound trong hàm này.
%
%   See also design_bpf_bank, dtmf_segment, dtmf_decide, dtmf_decode_fft.

arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 205
    opt.hop (1,1) double = 205
end

% TODO(C):
%   1. bank = design_bpf_bank('fs', opt.fs);
%   2. Lọc toàn bộ y qua cả 8 bộ lọc: y_j = filter(bank(j).b, bank(j).a, y)
%      -> 8 tín hiệu đầu ra. Lọc một lần trên toàn tín hiệu (không lọc
%      riêng từng khung) để trạng thái bộ lọc liên tục, tránh quá độ tại
%      biên khung.
%   3. seg = dtmf_segment(y, ...); với mỗi khung, tính năng lượng
%      sum(y_j(idx).^2) cho từng bộ lọc -> E(:,i).
%   4. [rowIdx, colIdx, conf, reject] = dtmf_decide(E(:,i)); chống dội
%      (debounce); điền info.

keys = ''; %#ok<NASGU>
info = struct('E', [], 'rowIdx', [], 'colIdx', [], 'conf', [], 'tFrame', [], 'reject', {{}}); %#ok<NASGU>
error('dtmf_decode_filterbank:notImplemented', 'TODO: cai dat dtmf_decode_filterbank.');

end
