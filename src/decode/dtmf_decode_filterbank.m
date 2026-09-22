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

bank = design_bpf_bank('fs', opt.fs);

% Hàm này đánh chỉ số bộ hài bằng 7+d nên cần đúng 14 bộ. Thiếu chốt thì một
% ngân hàng 7 bộ cho lỗi "index exceeds" ở giữa vòng lặp, khó lần ra nguồn.
%
% Kiểm thử đột biến cho thấy bỏ chốt này KHÔNG làm test nào đỏ, vì lời gọi trên
% luôn dùng withHarm mặc định = true nên bank luôn có 14 phần tử. Đây là chốt
% phòng vệ cho tương lai (ai đó đổi mặc định của design_bpf_bank), không phải
% mã chết - đừng xóa.
if numel(bank) ~= 14
    error('dtmf_decode_filterbank:bankSize', ...
        'design_bpf_bank trả %d bộ lọc; nhánh này cần đúng 14 (7 chuẩn + 7 hài).', ...
        numel(bank));
end

% Lọc TOÀN BỘ tín hiệu một lần, trước khi chia khung. Lọc riêng từng khung làm
% trạng thái bộ lọc reset ở mỗi biên: đo được khung 2 mất 56.9% và khung 3 mất
% 61.1% năng lượng, đủ để mọi khung trượt ngưỡng 0.70 và hàm trả về rỗng.
yj = zeros(numel(bank), numel(y));
for j = 1:numel(bank)
    yj(j, :) = filter(bank(j).b, bank(j).a, y);
end

seg = dtmf_segment(y, 'fs', opt.fs, 'frameN', opt.frameN, 'hop', opt.hop);
n   = numel(seg);

% Cấp phát đúng cỡ hợp đồng. n = 0 rơi luôn vào đây: zeros(8,0) là 8×0 và
% cell(1,0) là 1×0, không cần nhánh if riêng. Phải bọc {cell(1,n)} vì struct()
% coi cell là danh sách giá trị, không bọc sẽ ra mảng struct 1×n.
info = struct('E',      zeros(8, n), ...
              'rowIdx', zeros(1, n), ...
              'colIdx', zeros(1, n), ...
              'conf',   zeros(1, n), ...
              'tFrame', zeros(1, n), ...
              'reject', {cell(1, n)});

for i = 1:n
    i1 = seg(i).idx(1);
    i2 = seg(i).idx(2);

    P = zeros(8, 1);
    P(1:7) = sum(yj(1:7, i1:i2).^2, 2);

    % Bộ hài bám theo đỉnh của CHÍNH khung này - quyết định (b). Bộ hài của bin
    % d nằm ở chỉ số 7+d, theo đúng thứ tự design_bpf_bank xếp ra.
    [~, d] = max(P(1:7));
    P(8) = sum(yj(7+d, i1:i2).^2);

    % Chuẩn hóa theo quyết định (a): mẫu số là năng lượng khung ĐẦU VÀO, không
    % có thừa số N/2 vì đầu ra bộ lọc là tín hiệu miền thời gian chứ không phải
    % vạch phổ. Khung im lặng có en = 0: để nguyên E = 0, dtmf_decide trả
    % 'level'; chia thẳng sẽ cho 0/0 = NaN và khung rác lọt qua với nhãn 'none'.
    en = sum(y(i1:i2).^2);
    if en > 0
        info.E(:, i) = P / en;
    end

    [info.rowIdx(i), info.colIdx(i), info.conf(i), info.reject{i}] = ...
        dtmf_decide(info.E(:, i));

    info.tFrame(i) = (seg(i).tStart + seg(i).tEnd) / 2;   % TÂM khung, (e)
end

% Debounce dùng chung cho cả ba bộ giải mã - quyết định (f). Nhánh này PHỤ
% THUỘC luật "dải >= 2 khung": dư âm bộ lọc trong khoảng lặng sinh ra dải dài
% đúng một khung, và luật đó là thứ duy nhất loại nó.
keys = dtmf_debounce(info.rowIdx, info.colIdx);

end
