function [keys, info] = dtmf_decode_filterbank(y, opt)
%DTMF_DECODE_FILTERBANK Giải mã DTMF bằng ngân hàng bộ lọc IIR song song
% Cho tín hiệu chạy qua 14 bộ lọc hẹp rồi xem bộ nào kêu to nhất
%   [KEYS, INFO] = DTMF_DECODE_FILTERBANK(Y) giải mã Y với tham số mặc định.
%   Ba bộ giải mã dùng chung chữ ký này (xem CONTRACTS.md).
%
%   Các bước hoạt động:
%       1. design_bpf_bank dựng 14 bộ lọc: 7 tần số chuẩn + 7 tần số hài.
%       2. filter() chạy TOÀN BỘ Y qua từng bộ đúng MỘT lần. Lọc riêng từng
%          khung sẽ reset trạng thái ở mỗi biên và quá độ ăn mất phần lớn năng
%          lượng từ khung thứ hai trở đi. Dùng filter chứ không filtfilt:
%          filtfilt lọc hai chiều nên triệt tiêu quá độ một cách giả tạo.
%       3. dtmf_segment chia lưới khung; năng lượng khung i của bộ j là
%          sum(y_j(idx).^2). Bộ hài bám theo đỉnh của CHÍNH khung đó:
%          d = argmax E(1:7), rồi E(8,i) = E_harm(d,i) - xem CONTRACTS §6(b).
%       4. Chia cho sum(frame.^2) để sum(E(1:7)) thành TỈ LỆ năng lượng, cùng
%          thang với hai bộ giải mã kia - xem CONTRACTS §6(a).
%       5. dtmf_decide phán quyết từng khung, rồi dtmf_debounce gộp các khung
%          liên tiếp cùng phím thành MỘT ký tự. Nhánh này PHỤ THUỘC luật
%          "dải >= 2 khung": dư âm bộ lọc trong khoảng lặng sinh ra dải dài
%          đúng một khung và luật đó là thứ loại nó - xem CONTRACTS §6(f).
%
%   Input:
%       y: 1×N double, tín hiệu cần giải mã.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs': tần số lấy mẫu [Hz] (8000).
%       'frameN': độ dài khung tính năng lượng đầu ra [mẫu] (205).
%       'hop': bước nhảy giữa hai khung [mẫu] (205).
%
%   Output:
%       keys: char 1×K, dãy phím đọc được; 1×0 nếu không nhận được khung nào.
%       info: số liệu theo khung, mọi trường dài nFrame - .E 8×nFrame (đã
%             chuẩn hóa), .rowIdx .colIdx .conf .tFrame 1×nFrame, .reject cell
%             1×nFrame. .tFrame là TÂM khung [s].
%
%   Example:
%       dtmf_decode_filterbank(dtmf_generate('0912345'))   % '0912345'
arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 205
    opt.hop (1,1) double = 205
end

% TODO(C):
%   1. bank = design_bpf_bank('fs', opt.fs);
%   2. Lọc toàn bộ y qua cả 14 bộ: yj(j,:) = filter(bank(j).b, bank(j).a, y).
%   3. seg = dtmf_segment(y, ...); mỗi khung tính sum(yj(j,idx).^2) cho 7 bộ
%      chuẩn, chọn d = argmax rồi lấy E(8) từ bộ hài thứ d.
%   4. Chuẩn hóa E/sum(frame.^2), gọi dtmf_decide, điền info.
%   5. keys = dtmf_debounce(info.rowIdx, info.colIdx);

keys = ''; %#ok<NASGU>
info = struct('E', [], 'rowIdx', [], 'colIdx', [], 'conf', [], 'tFrame', [], 'reject', {{}}); %#ok<NASGU>
error('dtmf_decode_filterbank:notImplemented', 'TODO: cai dat dtmf_decode_filterbank.');

end
